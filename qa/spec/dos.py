"""Isolated, bounded DOSBox execution and strict binary observation protocol."""
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time
from contextlib import nullcontext

ROOT = Path(__file__).resolve().parents[2]
PLANE = 80 * 480


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run_process(args, directory, timeout, env=None, keyboard=None):
    """Kill the process group on timeout/interrupt; retain stdout either way."""
    with (directory / 'dosbox.log').open('wb') as log:
        process = subprocess.Popen(args, cwd=directory, env=env, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            if keyboard is None:
                status = process.wait(timeout=timeout)
            else:
                deadline = time.monotonic()+timeout
                while process.poll() is None and time.monotonic() < deadline:
                    keyboard.poll()
                status = process.wait(timeout=max(.01, deadline-time.monotonic()))
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
    assert status == 0, f'DOSBox exited {status}; see {directory}/dosbox.log'


def run_dos(binary, directory, commands, timeout=60, physical_keys=False, settings=''):
    assert not any(p.name.upper() in ('DONE.TXT', 'FAIL.TXT') for p in directory.iterdir()), (
        f'refusing stale guest results in {directory}; use a fresh case directory')
    # Batch commands are explicit. Do not rewrite their redirections.
    lines = ['@echo off']
    for step, command in enumerate(commands):
        expected = 0
        if isinstance(command, tuple):
            command, expected = command
        lines += [f'echo {step}>STEP.TXT', command,
                  f'if errorlevel {expected+1} goto failed']
        if expected:
            lines += [f'if not errorlevel {expected} goto failed']
    lines += ['echo complete>DONE.TXT', 'goto end', ':failed',
              'echo failed>FAIL.TXT', ':end']
    (directory / 'RUN.BAT').write_bytes(('\r\n'.join(lines) + '\r\n').encode('ascii'))
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy')
    config = directory / 'dosbox.conf'
    # A private working directory and config keep the user's DOSBox settings
    # out of the test. Only the common -conf / [autoexec] interface is needed.
    args = [str(binary), '-conf', str(config)]
    (directory / 'invocation.json').write_text(json.dumps(args, indent=2) + '\n')
    (directory / 'emulator.json').write_text(json.dumps({
        'path': str(binary), 'sha256': digest(binary),
    }, indent=2) + '\n')
    from qa.spec.physical_keyboard import PhysicalKeyboard
    with PhysicalKeyboard(directory) if physical_keys else nullcontext() as keyboard:
        config.write_text((ROOT / 'qa/dosbox.conf').read_text() +
                          settings +
                          (keyboard.config if keyboard else '') +
                          '\n[autoexec]\n@echo off\nmount c .\nc:\ncall C:\\RUN.BAT\nexit\n')
        if keyboard:
            env.update(DISPLAY=keyboard.name, SDL_VIDEODRIVER='x11')
        run_process(args, directory, timeout, env, keyboard)
    files = {p.name.upper(): p for p in directory.iterdir()}
    step = files['STEP.TXT'].read_text().strip() if 'STEP.TXT' in files else '?'
    assert 'FAIL.TXT' not in files, f'guest command {step} failed; artifacts: {directory}'
    assert 'DONE.TXT' in files, f'guest never completed; artifacts: {directory}'
    assert files['DONE.TXT'].read_text().strip() == 'complete'
    return files


@dataclass
class Snapshot:
    text: bytes
    cursor: tuple[int, int]
    crtc: bytes
    planes: list[bytes]

    @classmethod
    def read(cls, path):
        raw = path.read_bytes()
        assert raw[:8] == b'HHSNAP1\n', f'unknown snapshot protocol: {path}'
        raw = raw[8:]
        assert len(raw) == 4027 + 4 * PLANE, f'truncated/extra snapshot bytes: {path}'
        return cls(raw[:4000], (raw[4001], raw[4000]), raw[4002:4027],
                   [raw[4027+i*PLANE:4027+(i+1)*PLANE] for i in range(4)])

    def glyph(self, row, col, plane=0):
        return bytes(self.planes[plane][(row*18+y)*80+col] for y in range(18))

    def save_ppm(self, path):
        # Dependency-free diagnostic image; pixels are the raw VGA planes.
        palette = [(0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170),
                   (170, 0, 0), (170, 0, 170), (170, 85, 0), (170, 170, 170),
                   (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255),
                   (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255)]
        pixels = bytearray()
        for index in range(PLANE):
            for bit in range(7, -1, -1):
                color = sum(((p[index] >> bit) & 1) << n for n, p in enumerate(self.planes))
                pixels.extend(palette[color])
        path.write_bytes(b'P6\n640 480\n255\n' + pixels)

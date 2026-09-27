"""Isolated, bounded DOSBox execution and strict binary observation protocol."""
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import signal
import struct
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


def run_dos(binary, directory, commands, timeout=60, physical_keys=False, settings='', screenshots=False,
            desktop_size=(1280,1024)):
    assert not screenshots or physical_keys, 'Screenshots require the physical keyboard handshake'
    assert not any(p.name.upper() in ('DONE.TXT', 'FAIL.TXT') for p in directory.iterdir()), (
        f'refusing stale guest results in {directory}; use a fresh case directory')
    # Batch commands are explicit. Do not rewrite their redirections.
    lines = ['@echo off']
    for step, command in enumerate(commands):
        expected = 0
        if isinstance(command, tuple):
            command, expected = command
        low, high = expected if isinstance(expected, tuple) else (expected, expected)
        assert 0 <= low <= high <= 255
        lines += [f'echo {step}>STEP.TXT', command,
                  f'if errorlevel {high+1} goto failed']
        if low:
            lines += [f'if not errorlevel {low} goto failed']
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
    with PhysicalKeyboard(directory, screenshots, desktop_size) if physical_keys else nullcontext() as keyboard:
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
    width: int = 640
    height: int = 480
    pitch: int = 80
    cell_width: int = 8
    cell_height: int = 18
    origin_x: int = 0
    origin_y: int = 0
    scale: int = 1
    columns: int = 80
    rows: int = 25

    @classmethod
    def read(cls, path):
        raw = path.read_bytes()
        assert raw[:8] in (b'HHSNAP1\n', b'HHSNAP2\n', b'HHSNAP3\n', b'HHSNAP4\n'), f'unknown snapshot protocol: {path}'
        geometry=(640,480,80,8,18,0,0,1,80,25)
        if raw[:8]!=b'HHSNAP1\n':
            assert len(raw)>=18, f'truncated geometry: {path}'
            count=10 if raw[:8]==b'HHSNAP4\n' else 8 if raw[:8]==b'HHSNAP3\n' else 5
            assert len(raw)>=8+count*2
            geometry=struct.unpack_from('<'+str(count)+'H',raw,8)
            if count==5: geometry+= (0,0,1)
            if count<10: geometry+=(80,25)
            width,height,pitch,cw,ch,ox,oy,scale,cols,rows=geometry
            if count==5: assert width==80*cw and height<=1024
            assert 0 < cw <= 32 and 0 < ch <= 64
            assert 1<=cols<=255 and 1<=rows<=255 and cols*rows*2<=32768
            assert 1<=scale<=4 and ox+cols*cw*scale<=width<=4096
            assert oy+rows*ch*scale<=height<=2160
            assert (width+7)//8 <= pitch <= 512
            raw=raw[:8]+raw[8+count*2:]
        raw = raw[8:]
        size=geometry[1]*geometry[2]
        text_bytes=geometry[8]*geometry[9]*2
        start=text_bytes+27
        assert len(raw) == start + 4 * size, f'truncated/extra snapshot bytes: {path}'
        return cls(raw[:text_bytes], (raw[text_bytes+1], raw[text_bytes]), raw[text_bytes+2:start],
                   [raw[start+i*size:start+(i+1)*size] for i in range(4)],*geometry)

    def glyph(self, row, col, plane=0):
        return plane_bits(self.planes[plane],self.pitch,self.origin_x+col*self.cell_width*self.scale,
                          self.origin_y+row*self.cell_height*self.scale,
                          self.cell_width*self.scale,self.cell_height*self.scale)

    def save_ppm(self, path):
        # Dependency-free diagnostic image; pixels are the raw VGA planes.
        palette = [(0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170),
                   (170, 0, 0), (170, 0, 170), (170, 85, 0), (170, 170, 170),
                   (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255),
                   (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255)]
        pixels = bytearray()
        for y in range(self.height):
            for x in range(self.width):
                index,bit=y*self.pitch+x//8,7-x%8
                color = sum(((p[index] >> bit) & 1) << n for n, p in enumerate(self.planes))
                pixels.extend(palette[color])
        path.write_bytes(f'P6\n{self.width} {self.height}\n255\n'.encode()+pixels)


def plane_bits(data,pitch,x,y,width,height):
    """Read actual pixels, including cells that share a framebuffer byte."""
    return tuple(sum(((data[(y+dy)*pitch+(x+dx)//8] >> (7-(x+dx)%8)) & 1)
                     << (width-1-dx) for dx in range(width)) for dy in range(height))

import json
import os
import shutil
import subprocess
import struct

import pytest

from qa.spec.dos import ROOT, Snapshot, digest, run_dos
from qa.spec.machine import FRAME_ALIASES, blank, put

pytestmark = pytest.mark.dos


@pytest.fixture(scope='session')
def guest_build(assembler, source_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp('guest-build')
    env = {k: v for k, v in os.environ.items() if k != 'JWASM'}
    for name in ('VGA', 'READ2', 'READ4', 'READ5', 'CMODE', 'CKBD'):
        result = subprocess.run([assembler, '-q', '-Zm', '-bin', f'-I{source_dir}',
                                 f'-Fo{out}/{name}.COM', str(source_dir / f'{name}.ASM')],
                                env=env, capture_output=True, text=True)
        assert result.returncode == 0 and 'Error A' not in result.stdout + result.stderr, result.stdout + result.stderr
    build = subprocess.run(['bash', 'tools/build-watcom-com.sh',
                            'qa/harness/snapshot.c', str(out / 'SNAPSHOT.COM')],
                           cwd=ROOT, env=env, capture_output=True, text=True)
    assert build.returncode == 0, build.stdout + build.stderr
    return out


@pytest.fixture
def capture(dosbox_binary, guest_build, tmp_path):
    for file in guest_build.glob('*.COM'):
        shutil.copy2(file, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    manifest = {'files': {p.name: digest(p) for p in tmp_path.iterdir()}}
    (tmp_path / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')

    def capture_frames(frames):
        data = b''.join(bytes((mode,)) + bytes(screen) for mode, screen in frames)
        (tmp_path / 'INPUT.BIN').write_bytes(data)
        files = run_dos(dosbox_binary, tmp_path, ['SNAPSHOT font', 'READ2 > READ2.LOG',
                                          'VGA > VGA.LOG', ('CMODE 3 > CMODE.LOG', 3),
                                          'SNAPSHOT api', 'SNAPSHOT > PROBE.LOG'], timeout=30 + 4*len(frames))
        capture_frames.api = files['API.BIN'].read_bytes()
        snapshots = []
        for index in range(len(frames)):
            key = f'SNAP{index:02d}.BIN'
            assert key in files, f'missing {key} in {tmp_path}'
            shot = Snapshot.read(files[key])
            shot.save_ppm(tmp_path / f'frame{index:02d}.ppm')
            snapshots.append(shot)
        font = files['FONT.BIN'].read_bytes()
        assert len(font) == 4096
        return snapshots, font
    return capture_frames


def assert_char(shot, font, row, col, code, attr=7):
    glyph = font[code*16:(code+1)*16]
    # Box/shading chars extend their last two scanlines to the 18-line cell.
    glyph += glyph[-2:] if 0xb0 <= code <= 0xdf else b'\0\0'
    assert_pixels(shot, row, col, glyph, attr)


def assert_pixels(shot, row, col, glyph, attr):
    for plane in range(4):
        fg = 255 if (attr & 15) & (1 << plane) else 0
        bg = 255 if (attr >> 4) & (1 << plane) else 0
        expected = bytes((b & fg) | ((b ^ 255) & bg) for b in glyph)
        actual = shot.glyph(row, col, plane)
        assert actual == expected, f'cell ({row},{col}), plane {plane}: {actual.hex()} != {expected.hex()}'


def assert_hanzi(shot, row, col, text, attr=7):
    raw = text.encode('gb2312')
    font = (ROOT / 'fonts/HZK16').read_bytes()
    for i in range(0, len(raw), 2):
        offset = ((raw[i]-0xa1)*94 + raw[i+1]-0xa1)*32
        glyph = font[offset:offset+32]
        assert_pixels(shot, row, col+i, glyph[::2] + b'\0\0', attr)
        assert_pixels(shot, row, col+i+1, glyph[1::2] + b'\0\0', attr)


def assert_text(screen, observed, frame_cells=()):
    """Only declared frame cells may use the public conversion codes."""
    assert observed[1::2] == screen[1::2], 'attributes changed'
    for cell, (expected, actual) in enumerate(zip(screen[::2], observed[::2])):
        if actual != expected:
            assert divmod(cell, 80) in frame_cells, f'non-frame byte changed at {divmod(cell, 80)}'
            assert actual == FRAME_ALIASES[expected]


def test_vga_mixed_frames_and_real_hanzi(capture):
    screen = blank()
    for row, col, chars in [(0, 0, '┌─┐│└─┘'), (0, 77, '╔═╗║╚═╝'),
                             (22, 0, '╒═╕│╘═╛'), (22, 77, '╓─╖║╙─╜')]:
        for dr, line in enumerate((chars[:3], chars[3]+' '+chars[3], chars[4:])):
            put(screen, row+dr, col, line.encode('cp437'))
    put(screen, 5, 0, '╔═════╗'.encode('cp437'))
    put(screen, 6, 0, b'\xba' + '中文'.encode('gb2312') + b' \xba')
    put(screen, 7, 0, '╚═════╝'.encode('cp437'))
    put(screen, 10, 4, '屯')
    put(screen, 11, 4, b'\xcd' * 40)
    shots, font = capture([(3, screen)])
    shot = shots[0]
    frame_cells = {(row, col) for row in (0, 1, 2, 22, 23, 24)
                   for col in (*range(3), *range(77, 80))}
    frame_cells.update((row, col) for row in (5, 7) for col in range(7))
    frame_cells.update({(6, 0), (6, 6)})
    frame_cells.update((11, col) for col in range(4, 44))
    assert_text(screen, shot.text, frame_cells)
    for row in (0, 1, 2, 22, 23, 24):
        for col in (*range(3), *range(77, 80)):
            assert_char(shot, font, row, col, screen[2*(80*row+col)])
    assert_char(shot, font, 6, 0, 0xba)
    assert_hanzi(shot, 6, 1, '中文')
    assert_hanzi(shot, 10, 4, '屯')
    for col in range(4, 44):
        assert_char(shot, font, 11, col, 0xcd)


def test_vga_incremental_repaint(capture):
    screen = blank()
    put(screen, 2, 4, b'\xe0\xab')
    frames = [(3, screen[:])]
    put(screen, 2, 4, b'\xe1')
    frames.append((3, screen[:]))
    put(screen, 2, 5, b'A')
    frames.append((3, screen[:]))
    shots, font = capture(frames)
    for shot, (_, raw) in zip(shots, frames):
        assert shot.text == raw
    assert_hanzi(shots[0], 2, 4, b'\xe0\xab'.decode('gb2312'))
    assert_hanzi(shots[1], 2, 4, b'\xe1\xab'.decode('gb2312'))
    assert_char(shots[2], font, 2, 4, 0xe1)
    assert_char(shots[2], font, 2, 5, ord('A'))


def test_vga_mode_change_without_text_change(capture):
    screen = blank()
    put(screen, 1, 0, b'\xcd'*6, 0x1e)
    shots, font = capture([(1, screen), (3, screen), (1, screen), (0, screen)])
    for shot in shots:
        assert_text(screen, shot.text, {(1, col) for col in range(6)})
    for index in (0, 2):
        assert_hanzi(shots[index], 1, 0, '屯屯屯', 0x1e)
    for index in (1, 3):
        for col in range(6):
            assert_char(shots[index], font, 1, col, 0xcd, 0x1e)


def test_resident_api_and_teletype_backspace(capture):
    capture([(3, blank())])
    api = capture.api
    assert len(api) == 8052 and api[:8] == b'HHAPI01\n'
    identity, mode, bda, reader, before, after = struct.unpack_from('<6H', api, 8)
    assert (identity, mode & 255, mode >> 8, bda, reader) == (0x56, 3, 80, 3, 0x4a06)
    assert (before, after) == (0x50c, 0x50b)
    assert api[20:4020] == api[4020:8020], 'backspace changed guest text'
    hzk = (ROOT / 'fonts/HZK16').read_bytes()
    offset = ((0xd6-0xa1)*94 + 0xd0-0xa1)*32
    assert api[8020:] == hzk[offset:offset+32]

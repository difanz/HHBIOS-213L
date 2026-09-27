import json
import os
import shutil
import subprocess
import struct

import pytest

from qa.spec.dos import ROOT, Snapshot, digest, run_dos
from qa.spec.machine import FRAME_ALIASES, blank, put
from qa.spec.pixels import colored_rows, native_rows

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
    build = subprocess.run(['bash', 'tools/build-watcom-com.sh',
                            'qa/harness/selectmode.c', str(out / 'SELECTMD.COM')],
                           cwd=ROOT, env=env, capture_output=True, text=True)
    assert build.returncode == 0, build.stdout + build.stderr
    build = subprocess.run(['bash', 'tools/build-vesa.sh', str(out / 'VESA.COM'), str(source_dir)],
                           cwd=ROOT, env=dict(env, JWASM=assembler), capture_output=True, text=True)
    assert build.returncode == 0, build.stdout + build.stderr
    return out


@pytest.fixture(params=['VGA', 'VESA'])
def capture(dosbox_binary, guest_build, tmp_path, request, pytestconfig):
    for file in guest_build.glob('*.COM'):
        shutil.copy2(file, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    shutil.copy2(ROOT / 'fonts/HH20.FNT', tmp_path)
    manifest = {'files': {p.name: digest(p) for p in tmp_path.iterdir()}}
    (tmp_path / 'provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')

    def capture_frames(frames):
        data = b''.join(bytes((mode,)) + bytes(screen) for mode, screen in frames)
        (tmp_path / 'INPUT.BIN').write_bytes(data)
        files = run_dos(dosbox_binary, tmp_path, ['SNAPSHOT font', 'READ2 > READ2.LOG',
                                          request.param+' > DISPLAY.LOG', ('CMODE 3 > CMODE.LOG', 3),
                                          'SNAPSHOT api', 'SNAPSHOT > PROBE.LOG'], timeout=30 + 4*len(frames),
                        settings='\n[dosbox]\nmachine=svga_s3\n' if request.param=='VESA' else '',
                        physical_keys=pytestconfig.getoption('--screenshots'),
                        screenshots=pytestconfig.getoption('--screenshots'))
        capture_frames.api = files['API.BIN'].read_bytes()
        snapshots = []
        for index in range(len(frames)):
            key = f'SNAP{index:02d}.BIN'
            assert key in files, f'missing {key} in {tmp_path}'
            shot = Snapshot.read(files[key])
            shot.save_ppm(tmp_path / f'frame{index:02d}.ppm')
            snapshots.append(shot)
        if pytestconfig.getoption('--screenshots'):
            captures = json.loads(files['SCREENSHOTS.JSON'].read_text())
            assert len(captures) == len(snapshots)
            for index, (image, shot) in enumerate(zip(captures, snapshots)):
                assert (image['width'], image['height']) == (shot.width, shot.height), (
                    'SDL dimensions differ: check video mode, scaling and desktop clipping')
                actual = subprocess.check_output(['convert', str(tmp_path / image['file']),
                                                  '-depth', '8', 'rgb:-'])
                expected = (tmp_path / f'frame{index:02d}.ppm').read_bytes().split(b'\n', 3)[3]
                # SDL 1 may use RGB565 and zero-fill low bits; SDL 2 expands
                # the VGA palette to RGB888. Normalize only those exact
                # palette quantizations, preserving every pixel/color check.
                quantized = {80: 85, 84: 85, 168: 170, 248: 255, 252: 255}
                dac = bytes(quantized.get(value, value) for value in range(256))
                assert actual.translate(dac) == expected.translate(dac), (
                    'SDL scanout differs from the captured VGA planes')
        font = files['FONT.BIN'].read_bytes()
        assert len(font) == 4096
        return snapshots, font
    return capture_frames


def assert_char(shot, font, row, col, code, attr=7):
    if shot.cell_width==10:
        assert_pixels(shot,row,col,native_rows(code),attr)
        return
    glyph = font[code*16:(code+1)*16]
    # Box/shading chars extend their last two scanlines to the 18-line cell.
    glyph += glyph[-2:] if 0xb0 <= code <= 0xdf else b'\0\0'
    assert_pixels(shot, row, col, glyph, attr)


def assert_pixels(shot, row, col, glyph, attr):
    for plane in range(4):
        expected = colored_rows(glyph,shot.cell_width,shot.cell_height,attr,plane)
        actual = shot.glyph(row, col, plane)
        assert actual == expected, f'cell ({row},{col}), plane {plane}: {actual} != {expected}'


def assert_hanzi(shot, row, col, text, attr=7):
    raw = text.encode('gb2312')
    font = (ROOT / 'fonts/HZK16').read_bytes()
    for i in range(0, len(raw), 2):
        if shot.cell_width==10:
            for half in range(2):
                assert_pixels(shot,row,col+i+half,native_rows(raw[i]*256+raw[i+1],half),attr)
            continue
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


def test_full_width_grid_and_symbol_spacing(capture):
    screen=blank()
    for col in range(80):
        put(screen,0,col,bytes([33+col]),((col % 8) << 4) | (7-col % 8))
    samples=['中文测试 800x600', 'αΑ ℃①，Ａ中', '汉字输入，编辑文件']
    for row,line in zip((3,7,24),samples): put(screen,row,1,line.encode('gb2312'),0x1e)
    shots,font=capture([(1,screen)])
    shot=shots[0]
    assert shot.text==screen
    for col in range(80): assert_char(shot,font,0,col,33+col,((col % 8) << 4) | (7-col % 8))
    for row,line in zip((3,7,24),samples):
        col=1
        for char in line:
            encoded=char.encode('gb2312')
            if len(encoded)==2: assert_hanzi(shot,row,col,char,0x1e)
            else: assert_char(shot,font,row,col,encoded[0],0x1e)
            col+=len(encoded)


def test_text_layout_boundaries(capture):
    """Dense mixed text, aligned tables, all colors, and independent row ends."""
    screen = blank()
    put(screen, 0, 0, ('1234567890' * 8).encode(), 0x70)
    put(screen, 1, 2, '中文显示 / HHBIOS 80 x 25 text cells', 0x1f)
    borders = {}
    for row, left, middle, right in [(3, '╔', '╦', '╗'), (5, '╠', '╬', '╣'),
                                    (9, '╚', '╩', '╝')]:
        line = (left + '═'*18 + middle + '═'*35 + right).encode('cp437')
        put(screen, row, 2, line, 0x1e)
        borders.update({(row, 2+i): code for i, code in enumerate(line)})
    for row in (4, 6, 7, 8):
        for col in (2, 21, 57):
            put(screen, row, col, b'\xba', 0x1e)
            borders[row, col] = 0xba
    for row, name, value in [(4, '项目 Item', '内容 / Value'),
                             (6, '中文 + English', '文件编辑 ABC 123'),
                             (7, '符号 Symbols', 'αΑ ℃①，Ａ中'),
                             (8, '框线与正文', '屯 / CD CD = one Hanzi')]:
        put(screen, row, 4, name, 0x1e)
        put(screen, row, 23, value, 0x1e)
    put(screen, 11, 2, 'FG 0..15:')
    put(screen, 13, 2, 'BG 0..15:')
    for color in range(16):
        put(screen, 11, 14+color*4, f'{color:X}中', 0x70 | color)
        put(screen, 13, 14+color*4, f'{color:X}中', (color << 4) | (15-color))
    put(screen, 15, 2, 'Odd/even cell positions:')
    put(screen, 16, 3, '中文 A 中文 B 中文', 0x2e)
    put(screen, 17, 4, '中文 A 中文 B 中文', 0x2e)
    put(screen, 19, 2, 'Last complete pair in columns 79-80 ->')
    put(screen, 19, 78, '中', 0x4f)
    put(screen, 20, 2, 'Orphan D6 at column 80; no cross-row pairing ->')
    put(screen, 20, 79, b'\xd6', 0x4f)
    put(screen, 21, 0, b'\xd0', 0x4f)
    put(screen, 21, 2, '<- D0 at column 1; separate Western glyph')
    put(screen, 23, 2, 'Last row / bottom-right:')
    put(screen, 24, 0, '底行从第一列到最后一列 / no scrolling', 0x1e)
    put(screen, 24, 78, '字', 0x1e)
    shots, font = capture([(3, screen)])
    shot = shots[0]
    assert_text(screen, shot.text, set(borders))
    for (row, col), code in borders.items():
        assert_char(shot, font, row, col, code, 0x1e)
    assert_hanzi(shot, 8, 23, '屯', 0x1e)
    for color in range(16):
        assert_hanzi(shot, 11, 15+color*4, '中', 0x70 | color)
        assert_hanzi(shot, 13, 15+color*4, '中', (color << 4) | (15-color))
    assert_hanzi(shot, 16, 3, '中文', 0x2e)
    assert_hanzi(shot, 17, 4, '中文', 0x2e)
    assert_hanzi(shot, 19, 78, '中', 0x4f)
    assert_char(shot, font, 20, 79, 0xd6, 0x4f)
    assert_char(shot, font, 21, 0, 0xd0, 0x4f)
    assert_hanzi(shot, 24, 78, '字', 0x1e)


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

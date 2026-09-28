"""Sustained AH=40h output and line scrolling under the real MS-DOS kernel."""
import json
import os
import subprocess

import pytest

from qa.spec.dos import ROOT, Snapshot, digest, run_process
from qa.spec.test_dos_display import guest_build
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_setup_font_dos import font_rows

pytestmark = pytest.mark.dos

# Fixed guest cycle budget, including the visible cursor and final repaint.
# Allow timer phase and scheduling variation, but reject full classification
# of the page on every printable ASCII byte.
TICK_LIMITS = {
    25: {'BLOCK_TICKS': 80, 'SCROLL_TICKS': 110, 'CHINESE_TICKS': 130},
    43: {'BLOCK_TICKS': 90, 'SCROLL_TICKS': 140, 'CHINESE_TICKS': 155},
}


@pytest.fixture(scope='session')
def stream_build(tmp_path_factory):
    output = tmp_path_factory.mktemp('dos-stream') / 'STREAM.COM'
    subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/dosstream.c',
                    str(output)], cwd=ROOT, check=True, capture_output=True)
    return output


def terminal_result(data, rows, bottom=False):
    """Text bytes plus CR/LF, independent of the driver's redraw strategy."""
    screen = bytearray(b' \x07' * (rows * 80))
    row, column = (rows - 1 if bottom else 0), 0
    for code in data:
        if code == 13:
            column = 0
        elif code == 10:
            row += 1
        else:
            screen[(row * 80 + column) * 2] = code
            column += 1
            if column == 80:
                column = 0
                row += 1
        if row == rows:
            screen[:(rows - 1) * 160] = screen[160:]
            screen[-160:] = b' \x07' * 80
            row -= 1
    return bytes(screen), (row, column)


def assert_console_pixels(shot, font):
    expected = {}
    blank = (0,) * shot.cell_height
    for row in range(shot.rows):
        column = 0
        while column < 80:
            code = shot.text[(row * 80 + column) * 2]
            cells = 1
            if 0xa1 <= code <= 0xf7 and column < 79:
                trail = shot.text[(row * 80 + column + 1) * 2]
                if 0xa1 <= trail <= 0xfe:
                    code = code * 256 + trail
                    cells = 2
            for half in range(cells):
                if (code, half) not in expected:
                    expected[code, half] = font_rows(font, code, half)
                assert shot.text[(row * 80 + column + half) * 2 + 1] == 7
                for plane in range(4):
                    assert shot.glyph(row, column + half, plane) == (
                        expected[code, half] if plane < 3 else blank), (row, column, code, plane)
            column += cells


@pytest.mark.parametrize('rows,font_name', [(25, 'F1229.FNT'), (43, 'F1217.FNT')])
@pytest.mark.parametrize('stage', ['ascii', 'chinese'])
def test_msdos_sustained_console_output(dosbox_binary, guest_build, stream_build,
                                        msdos_image, tmp_path, rows, font_name, stage):
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM'):
        copy_in(guest_build / name, '::HHBIOS/' + name)
    copy_in(stream_build, '::HHBIOS/STREAM.COM')
    for path in (ROOT / 'fonts/large').glob('F????.FNT'):
        copy_in(path, '::HHBIOS/' + path.name)
    commands = [
        '@ECHO OFF', 'CD \\HHBIOS', 'READ5', 'IF ERRORLEVEL 1 GOTO FAILED',
        'CKBD /E', 'IF ERRORLEVEL 1 GOTO FAILED',
        'VESA /M:104', 'IF ERRORLEVEL 1 GOTO FAILED',
        f'STREAM {rows}' + (' CN' if stage == 'chinese' else ''),
        'IF ERRORLEVEL 1 GOTO FAILED',
        'ECHO complete>C:\\RESULT.TXT', 'GOTO END',
        ':FAILED', 'ECHO failed>C:\\RESULT.TXT', ':END', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path / 'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    (tmp_path / 'dosbox.conf').write_text(
        '[sdl]\noutput=surface\n[dosbox]\nmachine=svga_s3\nmemsize=16\n'
        '[cpu]\ncore=normal\ncputype=386\ncycles=30000\n[autoexec]\n'
        'imgmount 0 empty -fs none -t floppy\n'
        f'imgmount c "{image}" -ide 1m\nboot c:\n')
    run_process([str(dosbox_binary), '-conf', str(tmp_path / 'dosbox.conf')],
                tmp_path, 180,
                dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy'))
    assert read('RESULT.TXT').strip() == b'complete'
    counts = {key: int(value) for key, value in
              (line.split('=') for line in read('HHBIOS/STREAM.TXT').decode().splitlines())}
    assert (counts['MODE'], counts['WIDTH'], counts['HEIGHT'], counts['ROWS']) == (
        0x104, 1024, 768, rows)
    assert (counts['FONT_WIDTH'], counts['FONT_HEIGHT'], counts['SCALE']) == (
        12, 29 if rows == 25 else 17, 1)
    assert counts['FONT_FAULT'] == 0
    assert not counts['CURSOR_SHAPE'] & 0x2000, 'Timing must include the normal visible cursor'
    if stage == 'ascii':
        assert counts['BLOCK_BYTES'] == 4096 and counts['SCROLL_BYTES'] == 5120
        assert counts['SCROLL_LINES'] == 64
        metrics = ('BLOCK_TICKS', 'SCROLL_TICKS')
    else:
        assert counts['CHINESE_BYTES'] == 1088 and counts['CHINESE_LINES'] == 32
        metrics = ('CHINESE_TICKS',)
    (tmp_path / 'timings.json').write_text(json.dumps(counts, indent=2) + '\n')
    (tmp_path / 'provenance.json').write_text(json.dumps({
        'vesa_sha256': digest(guest_build / 'VESA.COM'),
        'probe_sha256': digest(stream_build), 'font': font_name,
        'font_sha256': digest(ROOT / 'fonts/large' / font_name),
        'emulator_sha256': digest(dosbox_binary), 'cycles': 30000,
    }, indent=2) + '\n')
    print(rows, stage, counts)

    block = bytes(ord('A') + i % 26 for i in range(4096))
    lines = b''.join(f'{line:02}:'.encode() + bytes(
        ord('a') + (line + column) % 26 for column in range(3, 78)) + b'\r\n'
        for line in range(64))
    codes = [character.encode('gb2312') for character in '中国汉字系统测试']
    chinese = b''.join(b''.join(codes[(line + i) % 8] for i in range(16)) + b'\r\n'
                       for line in range(32))
    font = (ROOT / 'fonts/large' / font_name).read_bytes()
    captures = [('CHINESE', chinese, True)] if stage == 'chinese' else [
        ('BLOCK', block, False), ('SCROLL', lines, True)]
    for name, data, bottom in captures:
        read('HHBIOS/' + name + '.BIN')
        shot = Snapshot.read(tmp_path / 'HHBIOS' / (name + '.BIN'))
        assert (shot.width, shot.height, shot.rows, shot.cell_width, shot.cell_height) == (
            1024, 768, rows, 12, counts['FONT_HEIGHT'])
        assert (shot.text, shot.cursor) == terminal_result(data, rows, bottom)
        assert_console_pixels(shot, font)

    for metric in metrics:
        limit = TICK_LIMITS[rows][metric]
        assert 0 < counts[metric] <= limit, (
            f'{rows} rows: {metric}={counts[metric]}, budget={limit} BIOS ticks')

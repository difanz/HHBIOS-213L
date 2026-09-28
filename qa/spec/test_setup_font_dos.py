"""Boot MS-DOS, save a font-pack layout, then run the generated startup file."""
import os
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, Snapshot, run_process
from qa.spec.test_application import keyboard_config
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_vesa import vesa_build
from qa.spec.test_dos_display import guest_build
from qa.spec.test_setup_widescreen import HD_SETTINGS, sample

pytestmark = pytest.mark.dos


def font_rows(data, code, half):
    width, height = struct.unpack_from('<HH', data, 8)
    slot = code if code < 256 else 256 + ((code >> 8) - 0xa1) * 94 + (code & 255) - 0xa1
    index, = struct.unpack_from('<H', data, 32 + slot * 2)
    pitch = (width * 2 + 7) // 8
    record_size = (pitch * height + 1) & ~1
    record = data[32 + 33736 + index * record_size:][:record_size]
    shift = pitch * 8 - width * (half + 1)
    return tuple((int.from_bytes(record[row * pitch:(row + 1) * pitch], 'big') >> shift)
                 & ((1 << width) - 1) for row in range(height))


def assert_font_pixels(shot, text, pairs, font):
    width = shot.cell_width
    witnesses = dict(pairs)
    witnesses[0, 2] = (ord('A'), 0)
    witnesses[shot.rows - 1, 4] = (ord(' '), 0)
    for column, code in ((1, 0xd3a2), (3, 0xcec4)):
        witnesses[shot.rows, column] = (code, 0)
        witnesses[shot.rows, column + 1] = (code, 1)
    for (row, column), (code, half) in witnesses.items():
        attribute = text[(row * 80 + column) * 2 + 1] if row < shot.rows else 0x70
        inset = row == shot.rows and shot.origin_y + (shot.rows + 1) * shot.cell_height * shot.scale + 2 <= shot.height
        for plane in range(4):
            mask = (1 << width) - 1
            foreground = mask if attribute & (1 << plane) else 0
            background = mask if attribute & (16 << plane) else 0
            expected = tuple((bits & foreground) | ((mask ^ bits) & background)
                             for bits in font_rows(font, code, half))
            assert shot.glyph(row, column, plane, y_offset=inset) == expected, (row, column, plane)


@pytest.mark.parametrize('video,width,height,rows,font_name,cell', [
    ('104', 1024, 768, 25, 'F1229.FNT', (12, 29)),
    ('104', 1024, 768, 43, 'F1217.FNT', (12, 17)),
    ('106', 1280, 1024, 50, 'F1620.FNT', (16, 20)),
    ('1920x1080', 1920, 1080, 50, 'F2421.FNT', (24, 21)),
])
def test_msdos_generated_font_pack_layout(dosbox_binary, msdos_image, vesa_build,
                                          tmp_path, pytestconfig, video, width,
                                          height, rows, font_name, cell):
    setup = pytestconfig.getoption('--setup-exe')
    if setup is None:
        pytest.skip('Supply --setup-exe for the production setup program')
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    with image.open('rb') as disk:
        disk.seek(454)
        volume = f'{image}@@{struct.unpack("<I", disk.read(4))[0] * 512}'
    subprocess.run(['mmd', '-i', volume, '::FONTCFG'], check=True)
    copy_in(setup, '::FONTCFG/SETUP.EXE')
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM', 'SNAPSHOT.COM', 'VESATEST.COM'):
        copy_in(vesa_build/name, '::FONTCFG/' + name)
    for name in ('HZK16', 'HH20.FNT'):
        copy_in(ROOT/'fonts'/name, '::FONTCFG/' + name)
    for path in (ROOT/'fonts/large').glob('F????.FNT'):
        copy_in(path, '::FONTCFG/' + path.name)
    keyboard_config(tmp_path)
    copy_in(tmp_path/'213L.INI', '::FONTCFG/213L.INI')
    text, pairs = sample(rows)
    text[4:6] = b'A\x2e'
    (tmp_path/'INPUT.BIN').write_bytes(b'\1' + text)
    copy_in(tmp_path/'INPUT.BIN', '::FONTCFG/INPUT.BIN')
    commands = [
        '@ECHO OFF', 'CD \\FONTCFG', 'SETUP /REPORT > BEFORE.TXT',
        f'SETUP /AUTO /VIDEO:{video} /TEXT:80x{rows} /IME:NONE > SAVE.TXT',
        'IF ERRORLEVEL 1 GOTO FAILED', 'SETUP /REPORT > AFTER.TXT',
        'CALL HHBIOS.BAT > LOAD.TXT', 'VESATEST resident',
        'IF ERRORLEVEL 1 GOTO FAILED', 'SNAPSHOT',
        'IF ERRORLEVEL 1 GOTO FAILED', 'ECHO complete>C:\\RESULT.TXT',
        'GOTO END', ':FAILED', 'ECHO failed>C:\\RESULT.TXT', ':END',
        'C:\\DOS\\SHUTDOWN /S']
    (tmp_path/'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path/'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    config = ('[sdl]\noutput=surface\n[dosbox]\nmemsize=16\n'
              '[cpu]\ncore=normal\ncycles=30000\n' + HD_SETTINGS +
              '\n[autoexec]\nimgmount 0 empty -fs none -t floppy\n'
              f'imgmount c "{image}" -ide 1m\nboot c:\n')
    (tmp_path/'dosbox.conf').write_text(config)
    run_process([str(dosbox_binary), '-conf', str(tmp_path/'dosbox.conf')], tmp_path,
                120, dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy'))
    assert read('RESULT.TXT').strip() == b'complete', read('FONTCFG/SAVE.TXT')
    before = read('FONTCFG/BEFORE.TXT')
    assert before == read('FONTCFG/AFTER.TXT'), 'SETUP must not load fonts or leak manager memory'
    report = dict(line.split('=', 1) for line in before.decode().splitlines())
    assert report['HHBIOS_LOADED'] == '0'
    assert report['FONT_' + font_name].startswith(f'{cell[0]}x{cell[1]};')
    modes = [value for key, value in report.items() if key.startswith('VBE_MODE_')]
    assert any(value.startswith(f'{width}x{height};') and f'80x{rows}' in value for value in modes)
    batch = read('FONTCFG/HHBIOS.BAT')
    assert (f'/R:{rows}'.encode() in batch or rows == 25) and b'/F:' not in batch
    assert b'HHBIOS load failed' not in read('FONTCFG/LOAD.TXT')
    read('FONTCFG/SNAP00.BIN')
    shot = Snapshot.read(tmp_path/'FONTCFG/SNAP00.BIN')
    assert (shot.width, shot.height, shot.rows, shot.columns) == (width, height, rows, 80)
    assert (shot.cell_width, shot.cell_height, shot.scale) == (*cell, 1)
    assert shot.text == text
    font = (ROOT/'fonts/large'/font_name).read_bytes()
    assert_font_pixels(shot, text, pairs, font)
    shot.save_ppm(tmp_path/'screen.ppm')

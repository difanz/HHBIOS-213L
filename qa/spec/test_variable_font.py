"""Variable font geometry through the real DOS renderer, including bank edges."""
import json
import os
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, Snapshot, plane_bits, run_dos, run_process
from qa.spec.physical_keyboard import PhysicalKeyboard
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build
from qa.spec.test_font20 import sized_font
from qa.spec.test_vesa import vesa_build
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_resident_text import mouseview_build

pytestmark = pytest.mark.dos


def sample_text(rows=25):
    text = bytearray(b' \x17' * (80 * rows))
    for row in range(rows):
        for column in range(0, 80, 4):
            offset = (row * 80 + column) * 2
            text[offset:offset + 8] = b'A\x2e\xd6\x1e\xd0\x4b \x17'
    return text


def assert_cells(shot, text, width, height):
    for row in range(shot.rows):
        for column in range(80):
            role = column % 4
            origin = width if role == 2 else 0
            attribute = text[(row * 80 + column) * 2 + 1]
            for plane in range(4):
                expected = tuple(sum(1 << (width - 1 - x) for x in range(width)
                    if attribute & (1 << (plane if role != 3 and
                        ((x + origin) * 3 + y * 5) % 11 < 4 else plane + 4)))
                    for y in range(height))
                actual = plane_bits(shot.planes[plane], shot.pitch,
                    shot.origin_x + column * width, shot.origin_y + row * height, width, height)
                assert actual == expected, (row, column, plane)


@pytest.mark.parametrize('mode,width,height', [('102', 8, 16), ('104', 12, 29), ('106', 16, 39)])
def test_variable_font_direct_text_pixels(dosbox_binary, vesa_build, tmp_path, mode, width, height):
    for path in vesa_build.glob('*.COM'):
        shutil.copy2(path, tmp_path)
    shutil.copy2(ROOT / 'fonts/HZK16', tmp_path)
    (tmp_path / 'CUSTOM.FNT').write_bytes(sized_font(width, height))
    keyboard_config(tmp_path)
    text = sample_text()
    (tmp_path / 'INPUT.BIN').write_bytes(b'\1' + text)
    files = run_dos(dosbox_binary, tmp_path,
        ['READ5', 'CKBD /E', f'VESA /M:{mode} /F:CUSTOM.FNT', 'SNAPSHOT'],
        settings='\n[dosbox]\nmachine=svga_s3\n', timeout=90)
    shot = Snapshot.read(files['SNAP00.BIN'])
    assert (shot.columns, shot.rows, shot.cell_width, shot.cell_height) == (80, 25, width, height)
    assert shot.text == text
    assert_cells(shot, text, width, height)


@pytest.mark.parametrize('mode,width,height,physical_width,physical_height',
                         [('104', 12, 29, 1024, 768), ('106', 16, 39, 1280, 1024)])
def test_msdos_variable_font_mouse(dosbox_binary, vesa_build, mouseview_build, msdos_image,
                                  tmp_path, mode, width, height, physical_width, physical_height):
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM', 'SNAPSHOT.COM'):
        copy_in(vesa_build / name, '::HHBIOS/' + name)
    copy_in(mouseview_build, '::HHBIOS/MOUSEVW.COM')
    text = sample_text()
    (tmp_path / 'INPUT.BIN').write_bytes(b'\1' + text)
    (tmp_path / 'CUSTOM.FNT').write_bytes(sized_font(width, height))
    for name in ('INPUT.BIN', 'CUSTOM.FNT'):
        copy_in(tmp_path / name, '::HHBIOS/' + name)
    commands = ['@ECHO OFF', 'C:\\DOS\\VBMOUSE.EXE install low', 'CD \\HHBIOS',
                'READ5', 'CKBD /E', f'VESA /M:{mode} /F:CUSTOM.FNT',
                'IF ERRORLEVEL 1 GOTO END', 'SNAPSHOT', 'MOUSEVW software',
                'IF ERRORLEVEL 1 GOTO END', 'SNAPSHOT', 'ECHO complete>C:\\DONE.TXT',
                ':END', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path / 'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands) + '\r\n').encode())
    copy_in(tmp_path / 'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    x = (physical_width - 80 * width) // 2 + 79 * width - 1
    y = (physical_height - 26 * height) // 2 + 24 * height - 1
    (tmp_path / 'MOUSE.JSN').write_text(json.dumps([dict(x=x, y=y)]))
    with PhysicalKeyboard(tmp_path, True) as keyboard:
        copy_in(tmp_path / 'SCREEN.KEY', '::HHBIOS/SCREEN.KEY')
        config = ('[sdl]\noutput=surface\nautolock=false\nmouse_emulation=locked\n'
                  '[dos]\nvmware=true\n[dosbox]\nmachine=svga_s3\nmemsize=16\n'
                  '[cpu]\ncore=normal\ncycles=30000\n' + keyboard.config +
                  f'\n[autoexec]\nimgmount 0 empty -fs none -t floppy\nimgmount c "{image}" -ide 1m\nboot c:\n')
        (tmp_path / 'dosbox.conf').write_text(config)
        env = dict(os.environ, DISPLAY=keyboard.name, SDL_VIDEODRIVER='x11', SDL_AUDIODRIVER='dummy')
        run_process([str(dosbox_binary), '-conf', str(tmp_path / 'dosbox.conf')], tmp_path, 120, env, keyboard)
    assert read('DONE.TXT').strip() == b'complete'
    assert json.loads((tmp_path / 'physical-keys.json').read_text()) == [65535, 65534, 65535]
    log = read('HHBIOS/MOUSELOG.BIN')
    assert struct.unpack_from('<H', log)[0] == 32768
    for index in range(3):
        assert struct.unpack_from('<10H', log, 2 + index * 20)[2:4] == (78 * 8, 23 * 8)
    read('HHBIOS/SNAP00.BIN')
    shot = Snapshot.read(tmp_path / 'HHBIOS/SNAP00.BIN')
    assert shot.text == text
    text[(23 * 80 + 78) * 2 + 1] ^= 0x77
    assert_cells(shot, text, width, height)
    shot.save_ppm(tmp_path / 'expected.ppm')
    captures = json.loads((tmp_path / 'screenshots.json').read_text())
    pixels = subprocess.check_output(['convert', str(tmp_path / captures[-1]['file']), '-depth', '8', 'rgb:-'])
    assert pixels == (tmp_path / 'expected.ppm').read_bytes().split(b'\n', 3)[3]

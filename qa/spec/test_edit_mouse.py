"""MS-DOS EDIT's text cursor over its welcome dialog and restored borders."""
import json
import os
import re
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, digest, run_process
from qa.spec.physical_keyboard import PhysicalKeyboard
from qa.spec.test_dos_display import guest_build
from qa.spec.test_dosshell import shellcap_build
from qa.spec.test_msdos import copy_disk, msdos_image

pytestmark = [pytest.mark.application, pytest.mark.dos]


@pytest.mark.parametrize('display', ['native', 'vga', 'vesa102', 'vesa104'])
def test_edit_mouse_border(dosbox_binary, pytestconfig, tmp_path, request,
                           guest_build, shellcap_build, msdos_image, display):
    editor = pytestconfig.getoption('--qbasic')
    mouse = pytestconfig.getoption('--vbmouse')
    if editor is None or mouse is None or not pytestconfig.getoption('--screenshots'):
        pytest.skip('Supply --qbasic, --vbmouse and --screenshots for MS-DOS EDIT')
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    request.addfinalizer(lambda: image.unlink(missing_ok=True))
    with image.open('rb') as disk:
        disk.seek(454)
        volume = f'{image}@@{struct.unpack("<I", disk.read(4))[0]*512}'
    subprocess.run(['mmd', '-i', volume, '::EDITQA'], check=True)
    copy_in(editor, '::EDITQA/QBASIC.EXE')
    copy_in(mouse, '::DOS/VBMOUSE.EXE')
    copy_in(shellcap_build, '::EDITQA/SHELLCAP.COM')
    (tmp_path/'application.json').write_text(json.dumps(
        dict(application='MS-DOS EDIT', sha256=digest(editor)), indent=2)+'\n')
    for name in ('READ5.COM', 'CKBD.COM', 'VGA.COM', 'VESA.COM'):
        copy_in(guest_build/name, '::HHBIOS/'+name)
    for path in (ROOT/'fonts/HH20.FNT', ROOT/'fonts/large/F1229.FNT'):
        copy_in(path, '::HHBIOS/'+path.name)
    startup = read('AUTOEXEC.BAT').replace(b'@ECHO ON', b'@ECHO OFF')
    startup, count = re.subn(
        rb'(?im)^(?:LH )?C:\\DOS\\(?:CTMOUSE|VBMOUSE)\.EXE[^\r\n]*',
        lambda _: b'C:\\DOS\\VBMOUSE.EXE install low', startup)
    assert count == 1, 'QA startup must load exactly one mouse driver'
    if display == 'native':
        startup = startup.replace(b'CALL HHBIOS.BAT', b'REM native text')
    else:
        driver = 'VGA' if display == 'vga' else 'VESA /M:'+display[4:]
        (tmp_path/'HHBIOS.BAT').write_bytes((
            '@ECHO OFF\r\nCD \\HHBIOS\r\nREAD5\r\nCKBD /E\r\n'+driver+'\r\n').encode())
        copy_in(tmp_path/'HHBIOS.BAT', '::HHBIOS/HHBIOS.BAT')
    actions = [0xfffe, 0xffff, 0xfffe, 0xffff, 0xfffe, 0xffff,
               0xfffe, 0xffff, 0x011b, 0x2100, 0x4800, 0x1c0d]
    (tmp_path/'ACTIONS.BIN').write_bytes(struct.pack('<'+'H'*len(actions), *actions))
    (tmp_path/'MARKER.TXT').write_bytes(b'Welcome')
    for name in ('ACTIONS.BIN', 'MARKER.TXT'):
        copy_in(tmp_path/name, '::EDITQA/'+name)
    commands = ['CD \\EDITQA', 'SHELLCAP QBASIC.EXE /EDITOR',
                'ECHO complete>C:\\DONE.TXT', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path/'AUTOEXEC.BAT').write_bytes(
        startup+b'\r\n'+('\r\n'.join(commands)+'\r\n').encode())
    copy_in(tmp_path/'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    cw, ch, ox = {'native': (9, 16, 0), 'vga': (8, 19, 0),
                  'vesa102': (10, 23, 0), 'vesa104': (12, 29, 32)}[display]
    positions = [(2, 2), (12, 6), (12, 7), (2, 2)]
    (tmp_path/'MOUSE.JSN').write_text(json.dumps([
        dict(x=ox+col*cw+cw//2, y=row*ch+ch//2, click=False)
        for col, row in positions]))
    with PhysicalKeyboard(tmp_path, True) as keyboard:
        config = ('[sdl]\noutput=surface\nautolock=false\nmouse_emulation=locked\n'
                  '[dos]\nvmware=true\n[dosbox]\nmachine=svga_s3\nmemsize=16\n'
                  '[cpu]\ncycles=30000\n')
        config += keyboard.config+f'\n[autoexec]\nimgmount 0 empty -fs none -t floppy\nimgmount c "{image}" -ide 1m\nboot c:\n'
        (tmp_path/'dosbox.conf').write_text(config)
        env = dict(os.environ, DISPLAY=keyboard.name, SDL_VIDEODRIVER='x11',
                   SDL_AUDIODRIVER='dummy')
        run_process([str(dosbox_binary), '-conf', str(tmp_path/'dosbox.conf')],
                    tmp_path, 90, env, keyboard)
    assert read('DONE.TXT').strip() == b'complete'
    assert struct.unpack('<4H', read('EDITQA/STATUS.BIN')) == (0, 0, len(actions), len(actions))
    raw = read('EDITQA/SHELL.BIN')
    assert len(raw) == 4*8280
    assert b'Welcome' in raw[280:4280:2]
    assert_cursor_pixels(tmp_path, raw, display)


def assert_cursor_pixels(directory, frames, display):
    shots = json.loads((directory/'screenshots.json').read_text())
    pixels = []
    for offset in range(0, len(frames), 8280):
        meta = struct.unpack_from('<12H', frames, offset)
        shot = shots[meta[0]]
        width, height = shot['width'], shot['height']
        pixels.append(subprocess.check_output([
            'convert', str(directory/shot['file']), '-depth', '8', 'rgb:-']))
        if display.startswith('vesa'):
            ox, oy, scale, ch = meta[7:11]
            cw = 10 if display == 'vesa102' else 12
            assert scale == 1
        else:
            cw, ch = width//80, height//(26 if display == 'vga' else 25)
            ox = oy = 0

    def cell(image, row, column):
        result = []
        for y in range(ch):
            for x in range(cw):
                offset = ((oy+row*ch+y)*width+ox+column*cw+x)*3
                result.append(image[offset:offset+3])
        return result

    for index, row in ((1, 6), (2, 7)):
        original = cell(pixels[0], row, 12)
        ink, paper = sorted(set(original))
        # EDIT's default text cursor reverses colors, retaining the glyph.
        assert cell(pixels[index], row, 12) == [
            paper if pixel == ink else ink for pixel in original]
        assert cell(pixels[3], row, 12) == original
    assert cell(pixels[2], 6, 12) == cell(pixels[0], 6, 12)

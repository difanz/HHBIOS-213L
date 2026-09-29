"""PEDIT's shaded menus on the real MS-DOS QA installation."""
import json
import os
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, digest, run_process
from qa.spec.physical_keyboard import PhysicalKeyboard
from qa.spec.test_dos_display import guest_build
from qa.spec.test_dosshell import shellcap_build
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_setup_font_dos import font_rows

pytestmark = [pytest.mark.application, pytest.mark.dos]


@pytest.mark.parametrize('display', ['native', 'vga', 'vesa102', 'vesa104'])
def test_pedit_tables(dosbox_binary, pytestconfig, tmp_path, request, guest_build,
                      shellcap_build, msdos_image, display):
    editor = pytestconfig.getoption('--pedit')
    if editor is None or not pytestconfig.getoption('--screenshots'):
        pytest.skip('Supply --pedit and --screenshots for the real editor')
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    # Keep the small evidence files, never a disk image per regression run.
    request.addfinalizer(lambda: image.unlink(missing_ok=True))
    with image.open('rb') as disk:
        disk.seek(454)
        volume = f'{image}@@{struct.unpack("<I", disk.read(4))[0]*512}'
    subprocess.run(['mmd', '-i', volume, '::PEDITQA'], check=True)
    copy_in(editor, '::PEDITQA/PEDIT.EXE')
    (tmp_path/'application.json').write_text(json.dumps(
        dict(application='PEDIT', sha256=digest(editor)), indent=2)+'\n')
    copy_in(shellcap_build, '::SHELLCAP.COM')
    for name in ('READ5.COM', 'CKBD.COM', 'VGA.COM', 'VESA.COM'):
        copy_in(guest_build/name, '::HHBIOS/'+name)
    for path in (ROOT/'fonts/HH20.FNT', ROOT/'fonts/large/F1229.FNT'):
        copy_in(path, '::HHBIOS/'+path.name)
    startup = read('AUTOEXEC.BAT').replace(b'@ECHO ON', b'@ECHO OFF')
    if display == 'native':
        startup = startup.replace(b'CALL HHBIOS.BAT', b'REM native text')
    else:
        driver = 'VGA' if display == 'vga' else 'VESA /M:'+display[4:]
        (tmp_path/'HHBIOS.BAT').write_bytes((
            '@ECHO OFF\r\nCD \\HHBIOS\r\nREAD5\r\nCKBD /E\r\n'+driver+'\r\n').encode())
        copy_in(tmp_path/'HHBIOS.BAT', '::HHBIOS/HHBIOS.BAT')
    actions = [0x011b, 0xffff, 0x2100, 0x4d00, 0x4d00, 0x4d00, 0xffff,
               0x011b, 0x2100, 0x4800, 0x1c0d]
    (tmp_path/'ACTIONS.BIN').write_bytes(struct.pack('<'+'H'*len(actions), *actions))
    (tmp_path/'MARKER.TXT').write_bytes(b'File')
    for name in ('ACTIONS.BIN', 'MARKER.TXT'):
        copy_in(tmp_path/name, '::PEDITQA/'+name)
    commands = ['CD \\PEDITQA', 'C:\\SHELLCAP PEDIT.EXE',
                'ECHO complete>C:\\DONE.TXT', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path/'AUTOEXEC.BAT').write_bytes(
        startup+b'\r\n'+('\r\n'.join(commands)+'\r\n').encode())
    copy_in(tmp_path/'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
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
    for name in ('SHELL.BIN', 'HARDWARE.BIN', 'VIDEO.BIN', 'STATUS.BIN'):
        read('PEDITQA/'+name)
    assert read('DONE.TXT').strip() == b'complete'
    status = struct.unpack('<4H', (tmp_path/'PEDITQA/STATUS.BIN').read_bytes())
    assert status == (0, 0, len(actions), len(actions))
    raw = (tmp_path/'PEDITQA/SHELL.BIN').read_bytes()
    assert len(raw) == 2*8280
    assert_tables(tmp_path, raw[8280:], display)


def assert_tables(directory, frame, display):
    text = frame[280:4280:2]
    assert b'ASCII Chart' in text and b'Line-Drawing Chars' in text
    separator = b'\xde'+b'\xfa'*20+b'\xdd'
    assert text.count(separator) == 1
    row, column = divmod(text.index(separator), 80)
    if not display.startswith('vesa'):
        return
    meta = struct.unpack_from('<12H', frame)
    font = (ROOT/('fonts/large/F1229.FNT' if display == 'vesa104'
                 else 'fonts/HH20.FNT')).read_bytes()
    cw, ch = struct.unpack_from('<HH', font, 8)
    width, height = meta[2:4]
    ox, oy, scale, raster_height = meta[7:11]
    assert (width, height) == ((800, 600) if display == 'vesa102' else (1024, 768))
    assert (scale, raster_height) == (1, ch)
    shot = json.loads((directory/'screenshots.json').read_text())[meta[0]]
    rgb = subprocess.check_output(['convert', str(directory/shot['file']),
                                   '-depth', '8', 'rgb:-'])
    assert len(rgb) == width*height*3
    for offset, code in enumerate(separator):
        ink, paper = set(), set()
        for y, bits in enumerate(font_rows(font, code, 0)):
            for x in range(cw):
                pixel = ((oy+row*ch+y)*width+ox+(column+offset)*cw+x)*3
                (ink if bits & (1 << (cw-1-x)) else paper).add(rgb[pixel:pixel+3])
        assert len(ink) == len(paper) == 1 and ink != paper, (row, column+offset, hex(code))

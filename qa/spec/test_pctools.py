"""PC Tools' main window mixes directory branches, frames and filenames."""
import json
import os
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, digest, run_process
from qa.spec.machine import FRAME_ALIASES
from qa.spec.physical_keyboard import PhysicalKeyboard
from qa.spec.test_dos_display import guest_build
from qa.spec.test_dosshell import shellcap_build
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_setup_font_dos import font_rows


pytestmark = [pytest.mark.application, pytest.mark.dos]


@pytest.mark.parametrize('display', ['native', 'vga', 'vesa102', 'vesa104'])
def test_pctools_main_window(dosbox_binary, pytestconfig, tmp_path, guest_build,
                            shellcap_build, msdos_image, display):
    source = pytestconfig.getoption('--pctools')
    if source is None or not pytestconfig.getoption('--screenshots'):
        pytest.skip('Supply --pctools and --screenshots for the real PC Tools UI')
    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM', 'VGA.COM', 'VESA.COM'):
        copy_in(guest_build/name, '::HHBIOS/'+name)
    for path in (ROOT/'fonts/HH20.FNT', ROOT/'fonts/large/F1229.FNT'):
        copy_in(path, '::HHBIOS/'+path.name)
    copy_in(shellcap_build, '::SHELLCAP.COM')
    # Restore the supplied initial configuration: the editor tests select List1
    # and miss the tree that appears when users first open PC Tools.
    files = {p.name.upper(): digest(p) for p in source.iterdir() if p.is_file()}
    assert {'PCSHELL.EXE', 'PCSHELL.CFG'} <= files.keys()
    (tmp_path/'application.json').write_text(json.dumps(
        dict(application='PC Tools', files=files), indent=2)+'\n')
    for path in source.iterdir():
        if path.is_file():
            copy_in(path, '::QA/PCTOOLS/'+path.name.upper())
    startup = read('AUTOEXEC.BAT').replace(b'@ECHO ON', b'@ECHO OFF')
    if display == 'native':
        startup = startup.replace(b'CALL HHBIOS.BAT', b'REM native text')
    else:
        driver = 'VGA' if display == 'vga' else 'VESA /M:'+display[4:]
        (tmp_path/'HHBIOS.BAT').write_bytes((
            '@ECHO OFF\r\nCD \\HHBIOS\r\nREAD5\r\nCKBD /E\r\n'+driver+'\r\n').encode())
        copy_in(tmp_path/'HHBIOS.BAT', '::HHBIOS/HHBIOS.BAT')
    actions = [0xffff, 0x011b, 0xffff, 0x2100, 0xffff, 0x4800, 0x1c0d, 0x1c0d]
    (tmp_path/'ACTIONS.BIN').write_bytes(struct.pack('<'+'H'*len(actions), *actions))
    (tmp_path/'MARKER.TXT').write_bytes(b"You haven't done an application search yet.")
    for name in ('ACTIONS.BIN', 'MARKER.TXT'):
        copy_in(tmp_path/name, '::QA/PCTOOLS/'+name)
    commands = ['CD \\QA\\PCTOOLS', 'C:\\SHELLCAP PCSHELL C: /NF /25 /IM',
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
                    tmp_path, 120, env, keyboard)
    raw = read('QA/PCTOOLS/SHELL.BIN')
    read('QA/PCTOOLS/HARDWARE.BIN')
    read('QA/PCTOOLS/VIDEO.BIN')
    status = struct.unpack('<4H', read('QA/PCTOOLS/STATUS.BIN'))
    assert status == (0, 0, len(actions), len(actions))
    assert read('DONE.TXT').strip() == b'complete'
    assert len(raw) == 3*8280
    shots = json.loads((tmp_path/'screenshots.json').read_text())
    assert len(shots) == len(actions)
    font = (ROOT/('fonts/large/F1229.FNT' if display == 'vesa104'
                 else 'fonts/HH20.FNT')).read_bytes()
    for offset in range(0, len(raw), 8280):
        frame = raw[offset:offset+8280]
        meta = struct.unpack_from('<12H', frame)
        assert meta[1] == 4000
        text = frame[280:4280:2]
        if display.startswith('vesa'):
            width, height = meta[2:4]
            ox, oy, scale, ch = meta[7:11]
            cw, fh = struct.unpack_from('<HH', font, 8)
            assert (width, height) == ((800, 600) if display == 'vesa102' else (1024, 768))
            assert (scale, ch) == (1, fh)
            shot = shots[meta[0]]
            rgb = subprocess.check_output(['convert', str(tmp_path/shot['file']),
                                           '-depth', '8', 'rgb:-'])
            assert len(rgb) == width*height*3
        checked = 0
        # Inspect every visible branch in the initial dialog, main tree and
        # menu overlay. Do not tie the test to one installed directory list.
        for row in range(25):
            for col in range(76):
                start = row*80+col
                branch, rail = text[start:start+2]
                if (branch not in (0xc0, 0xc3, 0x8a, 0x8d) or
                        rail not in (0xc4, 0x12) or
                        text[start+2:start+5] not in (b'[ ]', b'[-]', b'[+]')):
                    continue
                code = 0xc0 if branch in (0xc0, 0x8a) else 0xc3
                for half, value in enumerate((code, 0xc4)):
                    expected = value if display == 'native' else FRAME_ALIASES[value]
                    assert text[start+half] == expected, (row, col+half, hex(value))
                    if not display.startswith('vesa'):
                        continue
                    ink, paper = set(), set()
                    for y, bits in enumerate(font_rows(font, value, 0)):
                        for x in range(cw):
                            pixel = ((oy+row*ch+y)*width+ox+(col+half)*cw+x)*3
                            (ink if bits & (1 << (cw-1-x)) else paper).add(rgb[pixel:pixel+3])
                    assert len(ink) == len(paper) == 1 and ink != paper, (row, col+half)
                checked += 1
        if meta[0] == 2:
            assert checked >= 2, 'The main window must exercise connected tree branches'

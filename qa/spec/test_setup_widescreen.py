"""Actual DOS setup, BIOS mode discovery and wide console scanout."""
import json
import os
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, Snapshot, run_dos, run_process
from qa.spec.physical_keyboard import PhysicalKeyboard
from qa.spec.pixels import colored_rows, native_rows
from qa.spec.test_application import keyboard_config
from qa.spec.test_direct_video import expected_planes
from qa.spec.test_dos_display import guest_build
from qa.spec.test_setup import setup_guest
from qa.spec.test_setup_display import edid
from qa.spec.test_msdos import copy_disk, msdos_image
from qa.spec.test_resident_text import mouseview_build
from qa.spec.test_vesa import vesa_build

pytestmark = pytest.mark.dos
HD_SETTINGS = '\n' + (ROOT / 'qa/profiles/vesa-hd.conf').read_text()


@pytest.fixture(scope='session')
def edid_bios(assembler,tmp_path_factory):
    out = tmp_path_factory.mktemp('edid-bios') / 'EDIDBIOS.COM'
    subprocess.run([assembler,'-q','-0','-bin','-Fo'+str(out),
                    str(ROOT/'qa/harness/edidbios.asm')],check=True,
                   env={k:v for k,v in os.environ.items() if k!='JWASM'})
    return out


def copy_probes(directory, vesa_build):
    for name in ('SNAPSHOT.COM','VESATEST.COM'):
        shutil.copy2(vesa_build/name,directory)
    keyboard_config(directory)


def sample(rows):
    text = bytearray(b' \x17' * (80 * rows)); pairs = {}
    for row,col in ((0,0),(0,78),(rows-1,0),(rows-1,78),(rows//2,37)):
        text[(row*80+col)*2:(row*80+col)*2+4] = b'\xd6\x1e\xd0\x4f'
        pairs[row,col] = (0xd6d0,0); pairs[row,col+1] = (0xd6d0,1)
    return text,pairs


def assert_text_pixels(shot,text,pairs,font):
    expected = expected_planes(shot,text,pairs,font)
    # CKBD owns the IME text. Compare the application and margins, then
    # check the English-mode indicator's exact glyphs, colors and placement.
    first = (shot.origin_y + shot.rows * shot.cell_height * shot.scale) * shot.pitch
    last = first + shot.cell_height * shot.scale * shot.pitch
    inset = last + 2 * shot.pitch <= shot.height * shot.pitch
    last += 2 * shot.pitch * inset
    for actual, wanted in zip(shot.planes,expected):
        assert actual[:first] == wanted[:first]
        assert actual[last:] == wanted[last:]
    for index,code in enumerate((0xd3a2,0xcec4)):
        for half in (0,1):
            for plane in range(4):
                glyph = colored_rows(native_rows(code,half),shot.cell_width,
                                     shot.cell_height,0x70,plane)
                scaled = tuple(sum(((row >> (shot.cell_width-1-x//shot.scale)) & 1)
                                   << (shot.cell_width*shot.scale-1-x)
                                   for x in range(shot.cell_width*shot.scale))
                               for row in glyph for _ in range(shot.scale))
                assert shot.glyph(shot.rows,index*2+half,plane,y_offset=inset) == scaled


@pytest.mark.parametrize('width,height,rows',[
    (1280,720,25),(1280,800,25),(1920,1080,43),(1920,1080,50),(1920,1200,50)])
def test_generated_wide_console(dosbox_binary,setup_guest,vesa_build,pytestconfig,
                                width,height,rows):
    copy_probes(setup_guest,vesa_build)
    text,pairs = sample(rows)
    (setup_guest/'INPUT.BIN').write_bytes(b'\1'+text)
    shots = pytestconfig.getoption('--screenshots')
    files = run_dos(dosbox_binary,setup_guest,[
        'SNAPSHOT font','SETUP /REPORT > MODES.TXT',
        f'SETUP /AUTO /VIDEO:{width}x{height} /TEXT:80x{rows} /IME:NONE',
        'CALL HHBIOS.BAT > LOAD.TXT','VESATEST resident','SNAPSHOT'],
        settings=HD_SETTINGS,timeout=120,physical_keys=shots,screenshots=shots,
        desktop_size=(max(width,1280),max(height,1024)))
    assert 'HHBIOS load failed' not in files['LOAD.TXT'].read_text()
    abi = files['RESIDENT.BIN'].read_bytes()
    assert struct.unpack_from('<HH',abi,20) == (width,height)
    batch = files['HHBIOS.BAT'].read_text()
    if rows > 25: assert f'/R:{rows}' in batch
    shot = Snapshot.read(files['SNAP00.BIN'])
    assert (shot.width,shot.height,shot.columns,shot.rows) == (width,height,80,rows)
    assert shot.text == text
    assert_text_pixels(shot,text,pairs,files['FONT.BIN'].read_bytes())
    if shots:
        shot.save_ppm(setup_guest/'expected.ppm')
        actual = subprocess.check_output(['convert',str(setup_guest/'screenshots/step-000.png'),
                                          '-depth','8','rgb:-'])
        assert actual == (setup_guest/'expected.ppm').read_bytes().split(b'\n',3)[3]


@pytest.mark.parametrize('kind',['native','unavailable','corrupt'])
def test_edid_bios_selection_is_checked(dosbox_binary,setup_guest,edid_bios,kind):
    shutil.copy2(edid_bios,setup_guest)
    data = edid(1366,768) if kind=='unavailable' else edid(1920,1080)
    if kind=='corrupt': data[30] ^= 1
    (setup_guest/'EDID.BIN').write_bytes(data)
    files = run_dos(dosbox_binary,setup_guest,[
        'EDIDBIOS','SETUP /REPORT > REPORT.TXT',
        ('SETUP /AUTO /VIDEO:NATIVE /TEXT:80x25 /IME:NONE',0 if kind=='native' else 1)],
        settings=HD_SETTINGS)
    report = dict(line.split('=',1) for line in files['REPORT.TXT'].read_text().splitlines())
    assert report['EDID_STATUS'] == ('1' if kind=='corrupt' else '3')
    assert report['EDID_PREFERRED'] == ('0x0' if kind=='corrupt' else
                                       '1366x768' if kind=='unavailable' else '1920x1080')
    if kind=='native':
        assert report['EDID_BIOS_MODE']=='1'
        mode, = [key[9:] for key,value in report.items()
                  if key.startswith('VBE_MODE_') and value.startswith('1920x1080;')]
        assert f'/M:{int(mode,16):X}' in files['HHBIOS.BAT'].read_text()
    else:
        assert 'HHBIOS.BAT' not in files and '213L.INI' not in files


def test_setup_changes_live_text_rows_without_reloading(dosbox_binary,setup_guest,vesa_build):
    copy_probes(setup_guest,vesa_build)
    original_ini = (setup_guest/'213L.INI').read_bytes()
    commands = ['SNAPSHOT font','READ5','CKBD /E','VESA /M:106']
    for rows in (50,43,25):
        text,_ = sample(rows)
        (setup_guest/f'IN{rows}.BIN').write_bytes(b'\1'+text)
        commands += [f'SETUP /TEXT:80x{rows}',f'COPY IN{rows}.BIN INPUT.BIN > NUL',
                     'SNAPSHOT',f'COPY SNAP00.BIN ROW{rows}.BIN > NUL']
    commands += ['VESATEST resident']
    files = run_dos(dosbox_binary,setup_guest,commands,settings=HD_SETTINGS,timeout=120)
    for rows in (50,43,25):
        shot = Snapshot.read(files[f'ROW{rows}.BIN'])
        text,pairs = sample(rows)
        assert (shot.columns,shot.rows,shot.width,shot.height)==(80,rows,1280,1024)
        assert shot.text == text
        assert_text_pixels(shot,text,pairs,files['FONT.BIN'].read_bytes())
    assert 'HHBIOS.BAT' not in files and files['213L.INI'].read_bytes() == original_ini


@pytest.mark.parametrize('option',['/R:24','/R:025','/R:50x','/R:','/R:100'])
def test_bad_row_option_does_not_install(dosbox_binary,setup_guest,option):
    files = run_dos(dosbox_binary,setup_guest,[(f'VESA {option}',1),'SETUP /REPORT > AFTER.TXT'])
    assert 'HHBIOS_LOADED=0' in files['AFTER.TXT'].read_text()


@pytest.mark.parametrize('mode,rows',[(0x102,43),(0x102,50),(0x104,50)])
def test_rows_that_do_not_fit_leave_vesa_uninstalled(dosbox_binary,setup_guest,vesa_build,
                                                    mode,rows):
    copy_probes(setup_guest,vesa_build)
    run_dos(dosbox_binary,setup_guest,[
        'READ5',(f'VESA /M:{mode:x} /R:{rows}',1),('VESATEST resident',14)],
        settings=HD_SETTINGS)


def test_msdos_wide_text_switch_and_mouse(dosbox_binary,setup_guest,vesa_build,
                                         mouseview_build,msdos_image,pytestconfig):
    vbmouse = pytestconfig.getoption('--vbmouse')
    if vbmouse is None:
        pytest.skip('Supply --vbmouse for the real MS-DOS absolute-input test')
    assert vbmouse.is_file(), vbmouse
    image,copy_in,read = copy_disk(msdos_image,setup_guest)
    copy_in(vbmouse,'::DOS/VBMOUSE.EXE')
    copy_probes(setup_guest,vesa_build)
    for name in ('SETUP.EXE','READ5.COM','CKBD.COM','VESA.COM','SNAPSHOT.COM',
                 'HZK16','HH20.FNT','213L.INI'):
        copy_in(setup_guest/name,'::HHBIOS/'+name)
    copy_in(mouseview_build,'::HHBIOS/MOUSEVW.COM')
    text,pairs = sample(50)
    (setup_guest/'INPUT.BIN').write_bytes(b'\1'+text)
    copy_in(setup_guest/'INPUT.BIN','::HHBIOS/INPUT.BIN')
    commands = ['@ECHO OFF','C:\\DOS\\VBMOUSE.EXE install low','CD \\HHBIOS',
                'SNAPSHOT font','READ5','CKBD /E','VESA /M:242 /R:50',
                'IF ERRORLEVEL 1 GOTO FAILED','SETUP /TEXT:80x43',
                'IF ERRORLEVEL 1 GOTO FAILED','SETUP /TEXT:80x50',
                'IF ERRORLEVEL 1 GOTO FAILED','SNAPSHOT','MOUSEVW software',
                'IF ERRORLEVEL 1 GOTO FAILED','SNAPSHOT','ECHO complete>C:\\DONE.TXT',
                'GOTO END',':FAILED','ECHO failed>C:\\DONE.TXT',':END',
                'C:\\DOS\\SHUTDOWN /S']
    (setup_guest/'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands)+'\r\n').encode())
    copy_in(setup_guest/'AUTOEXEC.BAT','::AUTOEXEC.BAT')
    # Last pixel of cell (78,48), including the centered application's origin.
    (setup_guest/'MOUSE.JSN').write_text(json.dumps([dict(x=1349,y=1009)]))
    with PhysicalKeyboard(setup_guest,True,(1920,1200)) as keyboard:
        copy_in(setup_guest/'SCREEN.KEY','::HHBIOS/SCREEN.KEY')
        config = ('[sdl]\noutput=surface\nshowmenu=false\nautolock=false\n'
                  'mouse_emulation=locked\n[dos]\nvmware=true\n'
                  '[cpu]\ncore=normal\ncycles=30000\n')
        config += HD_SETTINGS + keyboard.config
        config += ('\n[autoexec]\nimgmount 0 empty -fs none -t floppy\n'
                   f'imgmount c "{image}" -ide 1m\nboot c:\n')
        (setup_guest/'dosbox.conf').write_text(config)
        run_process([str(dosbox_binary),'-conf',str(setup_guest/'dosbox.conf')],
                    setup_guest,120,dict(os.environ,DISPLAY=keyboard.name,
                                        SDL_VIDEODRIVER='x11',SDL_AUDIODRIVER='dummy'),keyboard)
    assert read('DONE.TXT').strip() == b'complete'
    assert keyboard.requests == [0xffff,0xfffe,0xffff]
    raw = read('HHBIOS/MOUSELOG.BIN')
    assert struct.unpack_from('<H',raw)[0] == 32768
    for index in range(3):
        assert struct.unpack_from('<10H',raw,2+index*20)[2:4] == (624,384)
    count, = struct.unpack_from('<H',raw,62)
    callbacks = [struct.unpack_from('<4H',raw,64+index*8) for index in range(count)]
    assert any(event[0]&2 for event in callbacks) and any(event[0]&4 for event in callbacks)
    assert all(event[2:] == (624,384) for event in callbacks if event[0]&6)
    read('HHBIOS/SNAP00.BIN')
    shot = Snapshot.read(setup_guest/'HHBIOS/SNAP00.BIN')
    assert (shot.width,shot.height,shot.columns,shot.rows) == (1920,1080,80,50)
    assert shot.text == text
    text[(48*80+78)*2+1] ^= 0x77
    assert_text_pixels(shot,text,pairs,read('HHBIOS/FONT.BIN'))
    shot.save_ppm(setup_guest/'expected.ppm')
    actual = subprocess.check_output(['convert',str(setup_guest/keyboard.captures[-1]['file']),
                                      '-depth','8','rgb:-'])
    assert actual == (setup_guest/'expected.ppm').read_bytes().split(b'\n',3)[3]

"""Boot the shipped interactive QA configuration under a real MS-DOS kernel."""
import os
import re
from pathlib import Path
import shutil
import struct
import subprocess
from contextlib import nullcontext

import pytest

from qa.spec.dos import run_process, plane_bits
from qa.spec.pixels import colored_rows, native_rows
from qa.spec.physical_keyboard import PhysicalKeyboard
from qa.spec.test_dos_display import guest_build
from qa.spec.test_vesa import vesa_build
from qa.spec.test_memory import Arena, memory_build
from qa.spec.test_dosshell import shellcap_build


@pytest.fixture
def msdos_image(pytestconfig):
    source = pytestconfig.getoption('--msdos-image')
    if source is None:
        pytest.skip('Supply --msdos-image to test a real MS-DOS installation')
    assert Path(source).is_file(), source
    return source


def copy_disk(source,tmp_path):
    tmp_path.mkdir(parents=True,exist_ok=True)
    image = tmp_path/'DOS.IMG'
    shutil.copyfile(source, image)
    with image.open('rb') as disk:
        mbr = disk.read(512)
    assert mbr[446] == 0x80
    volume = f'{image}@@{struct.unpack_from("<I", mbr, 454)[0]*512}'
    def copy_in(path, target):
        subprocess.run(['mcopy','-o','-i',volume,str(path),target],check=True)
    def read(name):
        data = subprocess.check_output(['mtype','-i',volume,'::'+name])
        (tmp_path/name).parent.mkdir(parents=True,exist_ok=True)
        (tmp_path/name).write_bytes(data)
        return data
    return image,copy_in,read


@pytest.mark.dos
@pytest.mark.parametrize('core,low', [('auto',False),('normal',False),('auto',True),('normal',True)])
def test_msdos_console(dosbox_binary, pytestconfig, tmp_path, guest_build, vesa_build,
                       memory_build, msdos_image, core, low):
    image,copy_in,read=copy_disk(msdos_image,tmp_path)
    for name in ('READ5.COM','CKBD.COM','VESA.COM'):
        copy_in(guest_build/name,'::HHBIOS/'+name)
    copy_in(vesa_build/'VESATEST.COM','::QA/PROBES/VESATEST.COM')
    copy_in(memory_build/'MEMORY.COM','::QA/PROBES/MEMTEST.COM')
    if low:
        startup = read('HHBIOS/HHBIOS.BAT')
        startup = re.sub(rb'(?im)^(READ5|CKBD|VESA)([^\r\n]*)', rb'\1 /N\2',startup)
        (tmp_path/'HHBIOS.BAT').write_bytes(startup)
        copy_in(tmp_path/'HHBIOS.BAT','::HHBIOS/HHBIOS.BAT')
    offset = int(re.search(r'[0-9a-f]{4}:([0-9a-f]{4})[*+ ]+\s+_stack_bottom',
                          (guest_build/'VESA.map').read_text()).group(1),16)
    (tmp_path/'STACK.OFF').write_bytes(struct.pack('<H',offset))
    copy_in(tmp_path/'STACK.OFF','::STACK.OFF')
    (tmp_path/'STARTUP.BAT').write_bytes(read('AUTOEXEC.BAT'))
    copy_in(tmp_path/'STARTUP.BAT','::STARTUP.BAT')
    commands = ['@ECHO OFF','CALL C:\\STARTUP.BAT','@ECHO OFF',
                'Q:\\PROBES\\VESATEST rawscreen',
                'COPY SCREEN.BIN BEFORE.BIN > NUL','COPY PALETTE.BIN BEFORE.PAL > NUL',
                'CLS','Q:\\PROBES\\VESATEST rawscreen',
                'COPY SCREEN.BIN AFTER.BIN > NUL','COPY PALETTE.BIN AFTER.PAL > NUL',
                'C:\\HHBIOS\\VESA /?','Q:\\PROBES\\VESATEST guard',
                'Q:\\PROBES\\MEMTEST ARENA0.TXT','CALL C:\\STRESS.BAT',
                'Q:\\PROBES\\MEMTEST ARENA1.TXT',
                'VER > VERSION.TXT','C:\\HHBIOS\\SETUP /REPORT > MACHINE.TXT','CD \\',
                'Q:\\PROBES\\PERF','CLS',
                'C:\\HHBIOS\\CKBD /?',
                'Q:\\PROBES\\VESATEST screen','ECHO complete>DONE.TXT',
                'C:\\DOS\\SHUTDOWN /S']
    stress = ['@ECHO OFF']
    for step in range(100):
        stress += [f'ECHO {step}>STRESS.TXT','C:\\HHBIOS\\VESA /?',
                   'IF ERRORLEVEL 1 GOTO FAILED','Q:\\PROBES\\VESATEST guard',
                   'IF ERRORLEVEL 1 GOTO FAILED','ECHO Console output after VESA help.','CLS']
    stress += ['ECHO complete>STRESS.TXT','GOTO END',':FAILED','ECHO failed>STRESS.TXT',':END']
    (tmp_path/'STRESS.BAT').write_bytes(('\r\n'.join(stress)+'\r\n').encode('ascii'))
    copy_in(tmp_path/'STRESS.BAT','::STRESS.BAT')
    (tmp_path/'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands)+'\r\n').encode('ascii'))
    copy_in(tmp_path/'AUTOEXEC.BAT','::AUTOEXEC.BAT')
    shot = pytestconfig.getoption('--screenshots')
    with PhysicalKeyboard(tmp_path,True) if shot else nullcontext() as keyboard:
        env = dict(os.environ,SDL_VIDEODRIVER='dummy',SDL_AUDIODRIVER='dummy')
        config = f'[sdl]\noutput=surface\n[dosbox]\nmachine=svga_s3\nmemsize=16\n[cpu]\ncore={core}\ncycles=30000\n'
        if keyboard:
            config += keyboard.config
            env.update(DISPLAY=keyboard.name,SDL_VIDEODRIVER='x11')
            copy_in(tmp_path/'SCREEN.KEY','::SCREEN.KEY')
        config += f'\n[autoexec]\nimgmount 0 empty -fs none -t floppy\nimgmount c "{image}" -ide 1m\nboot c:\n'
        (tmp_path/'dosbox.conf').write_text(config)
        run_process([str(dosbox_binary),'-conf',str(tmp_path/'dosbox.conf')],tmp_path,180,env,keyboard)
    assert read('DONE.TXT').strip() == b'complete'
    assert read('STRESS.TXT').strip() == b'complete'
    for name in ('ARENA0.TXT','ARENA1.TXT'):
        read(name)
    initial,final = (Arena(tmp_path/name) for name in ('ARENA0.TXT','ARENA1.TXT'))
    assert initial.vectors == final.vectors
    assert (initial.strategy,initial.linked,initial.xms,initial.ems) == (
        final.strategy,final.linked,final.xms,final.ems)
    for arena in (initial,final):
        for interrupt in (8,9,0x10,0x16,0x2f,0x7f):
            assert (arena.resident(interrupt) < 0xa000) == low
    assert initial.occupied() == final.occupied()
    assert initial.occupied(True) == final.occupied(True)
    assert b'MS-DOS Version 6.22' in read('VERSION.TXT')
    report = read('MACHINE.TXT')
    assert b'DOS=6.22' in report and b'HHBIOS_LOADED=1' in report
    counts = dict(line.split('=') for line in read('PERF.TXT').decode().splitlines())
    for name,budget in dict(ASCII_32=3,CHINESE_16=4,DIRECT_2000=8,SCROLL_4=3,DOS_256=15,KEY_POLL_100=2).items():
        assert int(counts[name]) <= budget, counts
    before,after = read('BEFORE.BIN'),read('AFTER.BIN')
    assert read('BEFORE.PAL') == read('AFTER.PAL'), 'CLS changed the palette'
    for plane in range(4):
        start = 4000+plane*60000+57500
        assert before[start:start+2500] == after[start:start+2500], 'CLS changed the IME row'
    raw = read('SCREEN.BIN')
    assert len(raw) == 244000
    text = raw[:4000]
    title = '汉字系统键盘模块'.encode('gb2312')
    assert text[::2].count(title) == 1
    start = text[::2].index(title)
    for i in range(0,len(title),2):
        code = int.from_bytes(title[i:i+2],'big')
        for half in (0,1):
            cell = start+i+half
            row,col = divmod(cell,80)
            for p in range(4):
                plane = raw[4000+p*60000:4000+(p+1)*60000]
                assert plane_bits(plane,100,col*10,row*23,10,23) == colored_rows(
                    native_rows(code,half),10,23,text[cell*2+1],p)


@pytest.mark.dos
def test_msdos_backup_downloaded_font(dosbox_binary,pytestconfig,tmp_path,guest_build,
                                     shellcap_build,msdos_image):
    """Compare downloaded borders/cursor with MSBACKUP on native VGA text."""
    import json
    from qa.spec.machine import FRAME_ALIASES
    if not pytestconfig.getoption('--screenshots'):
        pytest.skip('MSBACKUP needs --screenshots to observe actual VGA scanout')
    observations=[]
    actions=[0xffff,0xfffe,0xffff,0x011b]
    for mode in (None,0x102,0x104):
        directory=tmp_path/('native' if mode is None else f'vesa{mode:x}')
        image,copy_in,read=copy_disk(msdos_image,directory)
        for name in ('READ5.COM','CKBD.COM','VESA.COM'):
            copy_in(guest_build/name,'::HHBIOS/'+name)
        copy_in(shellcap_build,'::SHELLCAP.COM')
        startup=read('AUTOEXEC.BAT').replace(b'@ECHO ON',b'@ECHO OFF')
        if mode is None:
            startup=startup.replace(b'CALL HHBIOS.BAT',b'REM native VGA')
        elif mode!=0x102:
            bat=read('HHBIOS/HHBIOS.BAT')
            bat=re.sub(rb'(?im)^VESA[^\r\n]*',f'VESA /M:{mode:x}'.encode(),bat)
            (directory/'HHBIOS.BAT').write_bytes(bat)
            copy_in(directory/'HHBIOS.BAT','::HHBIOS/HHBIOS.BAT')
        commands=['CD \\DOS','C:\\SHELLCAP MSBACKUP',
                  'ECHO complete>C:\\DONE.TXT','C:\\DOS\\SHUTDOWN /S']
        (directory/'AUTOEXEC.BAT').write_bytes(startup+b'\r\n'+('\r\n'.join(commands)+'\r\n').encode())
        copy_in(directory/'AUTOEXEC.BAT','::AUTOEXEC.BAT')
        (directory/'ACTIONS.BIN').write_bytes(struct.pack('<4H',*actions))
        (directory/'MARKER.TXT').write_bytes(b'Alert')
        copy_in(directory/'ACTIONS.BIN','::DOS/ACTIONS.BIN')
        copy_in(directory/'MARKER.TXT','::DOS/MARKER.TXT')
        (directory/'MOUSE.JSN').write_text(json.dumps([dict(x=49 if mode is None else 55,y=88 if mode is None else 126)]))
        with PhysicalKeyboard(directory,True) as keyboard:
            config='[sdl]\noutput=surface\n[dosbox]\nmachine=svga_s3\nmemsize=16\n[cpu]\ncycles=30000\n'
            config+=keyboard.config+f'\n[autoexec]\nimgmount 0 empty -fs none -t floppy\nimgmount c "{image}" -ide 1m\nboot c:\n'
            (directory/'dosbox.conf').write_text(config)
            env=dict(os.environ,DISPLAY=keyboard.name,SDL_VIDEODRIVER='x11',SDL_AUDIODRIVER='dummy')
            run_process([str(dosbox_binary),'-conf',str(directory/'dosbox.conf')],directory,120,env,keyboard)
        assert read('DONE.TXT').strip()==b'complete'
        status=struct.unpack('<4H',read('DOS/STATUS.BIN'))
        assert status[0]==2, 'Cancelling initial MSBACKUP configuration returns 2'
        assert status[1:]==(0,len(actions),len(actions)),status
        raw=read('DOS/SHELL.BIN'); read('DOS/HARDWARE.BIN'); read('DOS/VIDEO.BIN')
        assert len(raw)==2*8280
        shots=json.loads((directory/'screenshots.json').read_text())
        frames=[]
        for offset in (0,8280):
            frame=raw[offset:offset+8280]; meta=struct.unpack_from('<12H',frame)
            assert meta[1]==4000
            shot=shots[meta[0]]
            rgb=subprocess.check_output(['convert',str(directory/shot['file']),'-depth','8','rgb:-'])
            width,height=shot['width'],shot['height']
            assert len(rgb)==width*height*3
            frames.append((frame[280:4280],meta,rgb,width))
        observations.append(frames)
    for frames in observations[1:]:
        for (expected,_,reference,rw),(actual,meta,rgb,width) in zip(observations[0],frames):
            assert actual[1::2]==expected[1::2], 'Attribute bytes differ from native MSBACKUP'
            assert all(a==e or a==FRAME_ALIASES.get(e) for a,e in zip(actual[::2],expected[::2]))
            ox,oy,ch=meta[7],meta[8],meta[10]
            checked=0
            for cell,code in enumerate(expected[::2]):
                if code not in (0xb9,0xd9,0xd3,0xcd,0xc8,0xcb,0xb2,0xce,0xb4): continue
                row,col=divmod(cell,80)
                for y in range(ch):
                    for x in range(10):
                        src=((row*16+y*16//ch)*rw+col*(rw//80)+x*8//10)*3
                        dst=((oy+row*ch+y)*width+ox+col*10+x)*3
                        assert rgb[dst:dst+3]==reference[src:src+3], (row,col,hex(code),x,y)
                checked+=1
            assert checked>=60, 'Must inspect borders and the font-based mouse cursor'

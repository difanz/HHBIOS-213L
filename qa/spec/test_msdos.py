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
from qa.spec.test_text_modes import textmode_build


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


@pytest.fixture(scope='session')
def mousedir_build(tmp_path_factory):
    out=tmp_path_factory.mktemp('mousedir')/'MOUSEDIR.COM'
    subprocess.run(['bash','tools/build-watcom-com.sh','qa/harness/mousedir.c',str(out)],check=True)
    return out


@pytest.mark.dos
@pytest.mark.parametrize('driver',['cutemouse','vbmouse'])
@pytest.mark.parametrize('display',['native','vesa25','vesa50'])
def test_msdos_mouse_directions(dosbox_binary,pytestconfig,tmp_path,guest_build,
                                mousedir_build,textmode_build,msdos_image,driver,display):
    """Exercise signed relative motion and remote-desktop absolute positions."""
    import json
    vbmouse=pytestconfig.getoption('--vbmouse')
    if driver=='vbmouse':
        if vbmouse is None: pytest.skip('Supply --vbmouse for absolute mouse integration')
        assert vbmouse.is_file(),vbmouse
    image,copy_in,read=copy_disk(msdos_image,tmp_path)
    for name in ('READ5.COM','CKBD.COM','VESA.COM'):
        copy_in(guest_build/name,'::HHBIOS/'+name)
    copy_in(mousedir_build,'::MOUSEDIR.COM')
    copy_in(textmode_build,'::TEXTMODE.COM')
    if driver=='vbmouse': copy_in(vbmouse,'::DOS/VBMOUSE.EXE')
    else:
        ctmouse=pytestconfig.getoption('--ctmouse')
        if ctmouse is not None:
            assert ctmouse.is_file(),ctmouse
            copy_in(ctmouse,'::DOS/CTMOUSE.EXE')
        else:
            # Absolute-input disks need not include the optional relative driver.
            with image.open('rb') as disk:
                disk.seek(454); offset=struct.unpack('<I',disk.read(4))[0]*512
            found=subprocess.run(['mdir','-b','-i',f'{image}@@{offset}','::DOS/CTMOUSE.EXE'],
                                 capture_output=True)
            if found.returncode: pytest.skip('Supply --ctmouse or install CTMOUSE.EXE in the QA disk')
    startup=read('AUTOEXEC.BAT').replace(b'@ECHO ON',b'@ECHO OFF')
    command=b'C:\\DOS\\VBMOUSE.EXE install low' if driver=='vbmouse' else b'LH C:\\DOS\\CTMOUSE.EXE'
    startup,n=re.subn(rb'(?im)^(?:LH )?C:\\DOS\\(?:CTMOUSE|VBMOUSE)\.EXE[^\r\n]*',
                      lambda _: command,startup)
    assert n==1,'QA startup must load exactly one supported mouse driver'
    if display=='native': startup=startup.replace(b'CALL HHBIOS.BAT',b'REM native text')
    commands=['CD \\']+(['C:\\TEXTMODE 50'] if display=='vesa50' else [])
    commands+=['C:\\MOUSEDIR','IF ERRORLEVEL 1 GOTO FAILED','ECHO complete>C:\\DONE.TXT',
               ':FAILED','C:\\DOS\\SHUTDOWN /S']
    (tmp_path/'AUTOEXEC.BAT').write_bytes(startup+b'\r\n'+('\r\n'.join(commands)+'\r\n').encode())
    copy_in(tmp_path/'AUTOEXEC.BAT','::AUTOEXEC.BAT')
    if driver=='cutemouse':
        moves=[dict(x=x,y=y,relative=True,repeat=8,click=False) for x,y in
               ((5,0),(-5,0),(-5,0),(5,0),(0,5),(0,-5),(0,-5),(0,5))]
        checks=[(i,axis,sign) for i,axis,sign in
                ((1,0,1),(2,0,-1),(3,0,-1),(4,0,1),(5,1,1),(6,1,-1),(7,1,-1),(8,1,1))]
    else:
        # These remain on the same side of the capture center when reversing.
        # A relative/captured path interprets both directions as positive.
        moves=[dict(x=x,y=y,click=False) for x,y in
               ((520,220),(600,220),(520,220),(440,220),(400,300),(400,380),(400,300),(400,220))]
        checks=[(2,0,1),(3,0,-1),(4,0,-1),(6,1,1),(7,1,-1),(8,1,-1)]
    (tmp_path/'MOUSE.JSN').write_text(json.dumps([dict(x=360,y=220)]+moves))
    with PhysicalKeyboard(tmp_path,True) as keyboard:
        copy_in(tmp_path/'SCREEN.KEY','::SCREEN.KEY')
        config=('[sdl]\noutput=surface\nmouse_emulation=locked\n'
                f'autolock={"true" if driver=="cutemouse" else "false"}\n'
                '[dos]\nvmware=true\n[dosbox]\nmachine=svga_s3\nmemsize=16\n[cpu]\ncycles=30000\n')
        config+=keyboard.config+f'\n[autoexec]\nimgmount 0 empty -fs none -t floppy\nimgmount c "{image}" -ide 1m\nboot c:\n'
        (tmp_path/'dosbox.conf').write_text(config)
        env=dict(os.environ,DISPLAY=keyboard.name,SDL_VIDEODRIVER='x11',SDL_AUDIODRIVER='dummy')
        run_process([str(dosbox_binary),'-conf',str(tmp_path/'dosbox.conf')],tmp_path,90,env,keyboard)
    assert read('DONE.TXT').strip()==b'complete'
    if display=='vesa50':
        mode=read('TEXTMODE.BIN')
        assert mode[20+0x84]+1==50,'The high-row mouse test must actually enter 80x50'
    rows=[list(map(int,line.split())) for line in read('MOUSEDIR.TXT').splitlines()]
    assert len(rows)==9 and [r[0] for r in rows]==list(range(9))
    for step,axis,sign in checks:
        assert (rows[step][axis+1]-rows[step-1][axis+1])*sign>0,(step,rows)
        assert rows[step][axis+3]*sign>0,(step,rows)


@pytest.mark.dos
@pytest.mark.parametrize('core,low', [('auto',False),('normal',False),('auto',True),('normal',True)])
def test_msdos_console(dosbox_binary, pytestconfig, tmp_path, guest_build, vesa_build,
                       memory_build, msdos_image, core, low):
    image,copy_in,read=copy_disk(msdos_image,tmp_path)
    for name in ('READ5.COM','CKBD.COM','VESA.COM'):
        copy_in(guest_build/name,'::HHBIOS/'+name)
    copy_in(vesa_build/'VESATEST.COM','::QA/PROBES/VESATEST.COM')
    copy_in(memory_build/'MEMORY.COM','::QA/PROBES/MEMTEST.COM')
    # This pixel oracle uses 800x600 and HH20, independent of the interactive
    # disk's saved resolution/font. Change only this disposable startup copy.
    startup = read('HHBIOS/HHBIOS.BAT')
    startup, count = re.subn(rb'(?im)^(?:\.\\)?VESA(?:\.COM)?[^\r\n]*',
                            b'VESA /M:102 /R:25 /F:HH20.FNT', startup)
    assert count == 1
    if low:
        startup = re.sub(rb'(?im)^((?:\.\\)?(?:READ5|CKBD|VESA)(?:\.COM)?)([^\r\n]*)',
                         rb'\1 /N\2', startup)
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
    vbmouse=pytestconfig.getoption('--vbmouse')
    if vbmouse is None:
        pytest.skip('Supply --vbmouse to exercise MSBACKUP with absolute host input')
    assert vbmouse.is_file(),vbmouse
    observations=[]
    actions=[0xffff,0xfffe,0xfffe,0xffff,0xfffe,0xffff,0xfffe,0xffff,0x011b]
    for mode in (None,0x102,0x104):
        directory=tmp_path/('native' if mode is None else f'vesa{mode:x}')
        image,copy_in,read=copy_disk(msdos_image,directory)
        for name in ('READ5.COM','CKBD.COM','VESA.COM'):
            copy_in(guest_build/name,'::HHBIOS/'+name)
        copy_in(shellcap_build,'::SHELLCAP.COM')
        copy_in(vbmouse,'::DOS/VBMOUSE.EXE')
        startup=read('AUTOEXEC.BAT').replace(b'@ECHO ON',b'@ECHO OFF')
        startup,count=re.subn(rb'(?im)^(?:LH )?C:\\DOS\\(?:CTMOUSE|VBMOUSE)\.EXE[^\r\n]*',
                              lambda _: b'C:\\DOS\\VBMOUSE.EXE install low',startup)
        assert count==1,'QA startup must load exactly one supported mouse driver'
        if mode is None:
            startup=startup.replace(b'CALL HHBIOS.BAT',b'REM native VGA')
        else:
            # Use an explicit test configuration; SETUP may emit qualified
            # executable paths, and the user's saved mode is not this case.
            commands=['@ECHO OFF','CD \\HHBIOS','READ5','CKBD /E',f'VESA /M:{mode:x}']
            (directory/'HHBIOS.BAT').write_bytes(('\r\n'.join(commands)+'\r\n').encode())
            copy_in(directory/'HHBIOS.BAT','::HHBIOS/HHBIOS.BAT')
        commands=['CD \\DOS','C:\\SHELLCAP MSBACKUP',
                  'ECHO complete>C:\\DONE.TXT','C:\\DOS\\SHUTDOWN /S']
        (directory/'AUTOEXEC.BAT').write_bytes(startup+b'\r\n'+('\r\n'.join(commands)+'\r\n').encode())
        copy_in(directory/'AUTOEXEC.BAT','::AUTOEXEC.BAT')
        (directory/'ACTIONS.BIN').write_bytes(struct.pack('<'+'H'*len(actions),*actions))
        (directory/'MARKER.TXT').write_bytes(b'Alert')
        copy_in(directory/'ACTIONS.BIN','::DOS/ACTIONS.BIN')
        copy_in(directory/'MARKER.TXT','::DOS/MARKER.TXT')
        # MSBACKUP's callback consumes SI/DI mickeys, not CX/DX positions.
        # Establish absolute history, reach the top-left, then reverse both
        # axes. Pixel-to-mickey scaling differs between physical surfaces.
        (directory/'MOUSE.JSN').write_text(json.dumps([
            dict(x=x,y=y,click=False) for x,y in ((700,350),(10,10),(22,22),(16,16))]))
        with PhysicalKeyboard(directory,True) as keyboard:
            config='[sdl]\noutput=surface\nautolock=false\nmouse_emulation=locked\n[dos]\nvmware=true\n[dosbox]\nmachine=svga_s3\nmemsize=16\n[cpu]\ncycles=30000\n'
            config+=keyboard.config+f'\n[autoexec]\nimgmount 0 empty -fs none -t floppy\nimgmount c "{image}" -ide 1m\nboot c:\n'
            (directory/'dosbox.conf').write_text(config)
            env=dict(os.environ,DISPLAY=keyboard.name,SDL_VIDEODRIVER='x11',SDL_AUDIODRIVER='dummy')
            run_process([str(dosbox_binary),'-conf',str(directory/'dosbox.conf')],directory,120,env,keyboard)
        assert read('DONE.TXT').strip()==b'complete'
        status=struct.unpack('<4H',read('DOS/STATUS.BIN'))
        assert status[0]==2, 'Cancelling initial MSBACKUP configuration returns 2'
        assert status[1:]==(0,len(actions),len(actions)),status
        raw=read('DOS/SHELL.BIN'); read('DOS/HARDWARE.BIN'); read('DOS/VIDEO.BIN')
        assert len(raw)==4*8280
        shots=json.loads((directory/'screenshots.json').read_text())
        frames=[]
        cursor_positions=[]
        for offset in range(0,len(raw),8280):
            frame=raw[offset:offset+8280]; meta=struct.unpack_from('<12H',frame)
            assert meta[1]==4000
            if mode is not None:
                assert meta[2:4] == {0x102: (800,600), 0x104: (1024,768)}[mode]
            shot=shots[meta[0]]
            rgb=subprocess.check_output(['convert',str(directory/shot['file']),'-depth','8','rgb:-'])
            width,height=shot['width'],shot['height']
            assert len(rgb)==width*height*3
            text=frame[280:4280]
            cursor=text[::2].index(0xcb)
            assert all(text[(cursor+delta)*2]==code for delta,code in
                       ((0,0xcb),(1,0xb2),(80,0xce),(81,0xb4)))
            cursor_positions.append(divmod(cursor,80))
            frames.append((text,meta,rgb,width))
        assert cursor_positions[1]==(0,0),cursor_positions
        for axis in (0,1):
            assert cursor_positions[2][axis]>cursor_positions[1][axis],cursor_positions
            assert 0<cursor_positions[3][axis]<cursor_positions[2][axis],cursor_positions
        observations.append(frames)
    # Restore the initial arrow's four cells from the later native frame.
    # Every remaining cell must match this canvas, including vacated cursor
    # cells. Arrow positions are checked above; their actual pixels below.
    canvas=bytearray(observations[0][0][0])
    initial_cursor=canvas[::2].index(0xcb)
    for delta in (0,1,80,81):
        cell=initial_cursor+delta
        canvas[cell*2:cell*2+2]=observations[0][1][0][cell*2:cell*2+2]

    def mouse_sprite(frame,native):
        from collections import Counter
        text,meta,rgb,width=frame
        row,col=divmod(text[::2].index(0xcb),80)
        ox,oy,cell_width,cell_height=(0,0,width//80,16) if native else (
            meta[7],meta[8],(width-2*meta[7])//80,meta[10]*meta[9])
        # Recover the 8x16 source pixels from each of the four cursor cells.
        pixels=[]
        for y in range(32):
            line=[]
            for x in range(16):
                glyph_x=x%8
                scaled_x=glyph_x if native else (glyph_x*cell_width+7)//8
                px=ox+(col+x//8)*cell_width+scaled_x
                py=oy+(row+y//16)*cell_height+((y%16)*cell_height+15)//16
                offset=(py*width+px)*3
                line.append(rgb[offset:offset+3])
            pixels.append(line)
        background=Counter(color for line in pixels for color in line).most_common(1)[0][0]
        ink=[(x,y) for y,line in enumerate(pixels) for x,color in enumerate(line) if color!=background]
        assert ink,'The downloaded arrow must be visible'
        left,right=min(x for x,y in ink),max(x for x,y in ink)
        top,bottom=min(y for x,y in ink),max(y for x,y in ink)
        # MSBACKUP redraws its glyphs at sub-cell offsets as mickeys change.
        # Compare the complete colored shape independent of that translation.
        return background,[line[left:right+1] for line in pixels[top:bottom+1]]

    for frames in observations[1:]:
        for native_frame,vesa_frame in zip(observations[0],frames):
            expected,_,reference,rw=native_frame
            actual,meta,rgb,width=vesa_frame
            assert mouse_sprite(vesa_frame,False)==mouse_sprite(native_frame,True)
            arrow={code:expected[::2].index(code) for code in (0xcb,0xb2,0xce,0xb4)}
            ox,oy,ch=meta[7],meta[8],meta[10]*meta[9]
            cw=(width-2*ox)//80
            checked=0
            for cell,code in enumerate(actual[::2]):
                source_cell=arrow.get(code,cell)
                reference_text=expected if code in arrow else canvas
                wanted=reference_text[source_cell*2]
                assert code==wanted or code==FRAME_ALIASES.get(wanted),(cell,code,wanted)
                assert actual[cell*2+1]==reference_text[source_cell*2+1],cell
                if code not in (0xb9,0xd9,0xd3,0xcd,0xc8): continue
                row,col=divmod(cell,80)
                source_row,source_col=divmod(source_cell,80)
                for y in range(ch):
                    for x in range(cw):
                        src=((source_row*16+y*16//ch)*rw+source_col*(rw//80)+x*8//cw)*3
                        dst=((oy+row*ch+y)*width+ox+col*cw+x)*3
                        assert rgb[dst:dst+3]==reference[src:src+3], (row,col,hex(code),x,y)
                checked+=1
            assert checked>=60, 'Must inspect the downloaded borders'

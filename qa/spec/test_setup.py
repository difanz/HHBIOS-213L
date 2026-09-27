"""Setup decisions and real generated DOS startup paths."""
import ctypes as C
import shutil
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos


class DisplayMode(C.Structure):
    _fields_=[(s,C.c_uint) for s in 'number width height rows'.split()]


class Machine(C.Structure):
    _fields_=[(s,C.c_uint) for s in ('dos_major dos_minor conventional_kb free_kb umb_kb cpu '
        'xms_version xms_largest xms_total ems_version ems_pages ems_frame dpmi adapter '
        'vbe_version modes loaded alloc_strategy umb_link edid_status preferred_width '
        'preferred_height preferred_bios display_count display_truncated').split()] + [
        ('display_modes',DisplayMode*64)]


class Files(C.Structure):
    _fields_=[('size',C.c_ulong*15)]


class Choices(C.Structure):
    _fields_=[(s,C.c_uint) for s in 'font low video ime paired mode rows'.split()]


@pytest.fixture(scope='module')
def setup_policy(tmp_path_factory,source_dir):
    out=tmp_path_factory.mktemp('setup-host')/'setup.so'
    result=subprocess.run(['c++','-std=c++98','-shared','-fPIC','-Wall','-Wextra','-Werror','-DVESA_HOST',
        '-I'+str(source_dir/'setup'), '-I'+str(source_dir/'video/vesa'), str(source_dir/'setup/config.c'),
        str(source_dir/'setup/display.c'), str(source_dir/'video/vesa/vesa.c'),
        str(ROOT/'qa/harness/setup_host.cpp'),'-o',str(out)],capture_output=True,text=True)
    assert result.returncode==0,result.stdout+result.stderr
    lib=C.CDLL(str(out))
    for name in ('hh_validate','hh_save'): getattr(lib,name).restype=C.c_char_p
    lib.hh_recommend.argtypes=[C.POINTER(Machine),C.POINTER(Files),C.POINTER(Choices)]
    lib.hh_validate.argtypes=lib.hh_recommend.argtypes
    lib.hh_batch.argtypes=[C.c_char_p,C.POINTER(Choices),C.c_char_p]
    lib.hh_ini.argtypes=lib.hh_batch.argtypes
    lib.hh_save.argtypes=[C.c_char_p,C.c_char_p]
    return lib


def capable():
    m=Machine(dos_major=6,dos_minor=22,conventional_kb=640,free_kb=580,umb_kb=64,
              cpu=386,xms_version=0x300,xms_largest=8192,xms_total=8192,
              ems_version=0x40,ems_pages=128,ems_frame=0xe000,adapter=4,vbe_version=0x200,modes=7)
    f=Files((C.c_ulong*15)(*[10000]*15))
    f.size[9]=261696;f.size[10]=733208
    return m,f


@pytest.mark.unit
@pytest.mark.parametrize('xms,ems,vbe,expected',[
    (8192,128,7,(0,1)), (0,128,7,(1,1)), (0,0,7,(2,0)),
    (256,0,7,(0,0)), (1004,0,7,(0,0)), (1007,0,7,(0,0)), (1008,0,7,(0,1)),
    (0,63,7,(1,1)), (0,62,7,(1,0)), (8192,128,0,(0,0)),
])
def test_recommend_fits_two_font_stores(setup_policy,xms,ems,vbe,expected):
    m,f=capable();m.xms_largest=m.xms_total=xms;m.ems_pages=ems;m.modes=vbe
    c=Choices();setup_policy.hh_recommend(m,f,c)
    assert (c.font,c.video)==expected
    assert setup_policy.hh_validate(m,f,c) is None


@pytest.mark.unit
@pytest.mark.parametrize('path',[b'C:\\HHBIOS',b'D:\\',b'Z:\\DOS\\HH213L'])
def test_batch_uses_guest_path_and_real_loader_options(setup_policy,path):
    c=Choices(1,1,3,8,1);out=C.create_string_buffer(4096)
    assert setup_policy.hh_batch(path,c,out)
    lines=out.value.decode().splitlines()
    assert lines[3:6]==[chr(path[0])+':','CD '+path[2:].decode(),'IF ERRORLEVEL 1 GOTO HHFAIL']
    assert '.\\READ4.COM /N' in lines and '.\\CKBD.COM /E /N' in lines
    assert '.\\VESA.COM /M:106 /N' in lines
    assert '.\\WBX.COM' in lines and all('WBX.COM /N' not in s for s in lines)
    assert lines[-1]=='@ECHO ON'
    assert b'\n' not in out.value.replace(b'\r\n',b'')


@pytest.mark.unit
@pytest.mark.parametrize('path',[b'',b'C:',b'C:\\BAD NAME',b'C:\\A&B',b'C:\\%PATH%',
    b'C:\\A\r\nDEL C:\\*.*',b'C:\\..',b'C:\\'+b'ABCDEFGH\\'*4+b'A',b'C:\\DIR\\'])
def test_reject_batch_expansion_and_legacy_path_overflow(setup_policy,path):
    assert not setup_policy.hh_batch(path,Choices(),C.create_string_buffer(4096))


@pytest.mark.unit
def test_ini_preserves_comments_and_unrelated_values(setup_policy):
    lines=[f'{i:02X}H\t; '.encode()+'原配置'.encode('gb2312')+b'\r\n' for i in range(32)]
    source=b''.join(lines)+b'\x1a';out=C.create_string_buffer(8192)
    assert setup_policy.hh_ini(source,Choices(0,0,0,5,1),out)
    expected=lines[:29]+[b'59'+lines[29][2:],b'4E'+lines[30][2:],b'59'+lines[31][2:]]
    assert out.value==b''.join(expected)+b'\x1a'


@pytest.mark.unit
@pytest.mark.parametrize('data',[b'02\n'*31,b'garbage\n'*32,b'02\n'*31+b'4E',b'0Z\n'*32])
def test_reject_invalid_ini_without_guessing_values(setup_policy,data):
    assert not setup_policy.hh_ini(data,Choices(),C.create_string_buffer(8192))


@pytest.mark.unit
def test_save_backs_up_pair_and_never_overwrites_previous_backup(setup_policy,tmp_path,monkeypatch):
    monkeypatch.chdir(tmp_path)
    (tmp_path/'HHBIOS.BAT').write_bytes(b'old batch')
    (tmp_path/'213L.INI').write_bytes(b'old ini')
    assert setup_policy.hh_save(b'new batch',b'new ini') is None
    assert (tmp_path/'HHBIOS.BAK').read_bytes()==b'old batch'
    assert (tmp_path/'213L.BAK').read_bytes()==b'old ini'
    assert setup_policy.hh_save(b'third batch',b'third ini')
    assert (tmp_path/'HHBIOS.BAT').read_bytes()==b'new batch'
    assert (tmp_path/'213L.INI').read_bytes()==b'new ini'
    assert not list(tmp_path.glob('*.$$$'))


@pytest.mark.unit
def test_non_file_target_and_stale_temporary_are_preserved(setup_policy,tmp_path,monkeypatch):
    monkeypatch.chdir(tmp_path)
    (tmp_path/'213L.INI').mkdir()
    assert setup_policy.hh_save(b'new',b'new')
    assert (tmp_path/'213L.INI').is_dir()
    (tmp_path/'213L.INI').rmdir()
    (tmp_path/'HHBAT.$$$').write_bytes(b'previous interrupted save')
    assert setup_policy.hh_save(b'new',b'new')
    assert (tmp_path/'HHBAT.$$$').read_bytes()==b'previous interrupted save'
    assert not (tmp_path/'HHBIOS.BAT').exists()


@pytest.mark.unit
def test_monochrome_equipment_does_not_imply_hercules(setup_policy):
    m,f=capable();m.adapter=1;m.modes=0
    c=Choices();setup_policy.hh_recommend(m,f,c)
    assert setup_policy.hh_validate(m,f,c), 'MDA-only cards must not be offered a working graphics default'


@pytest.mark.unit
@pytest.mark.parametrize('cpu',[86,186,286])
def test_older_cpu_uses_vga_even_when_vbe_is_present(setup_policy,cpu):
    m,f=capable();m.cpu=cpu
    c=Choices();setup_policy.hh_recommend(m,f,c)
    assert c.video==0
    c.video=1
    assert b'386' in setup_policy.hh_validate(m,f,c)


@pytest.mark.unit
def test_missing_assets_and_unavailable_managers_block_save(setup_policy):
    m,f=capable();c=Choices(0,0,1,0,1)
    for asset in (0,3,5,9,10):
        old=f.size[asset];f.size[asset]=0
        assert setup_policy.hh_validate(m,f,c)
        f.size[asset]=old
    c.font=1;m.ems_frame=0
    assert b'page frame' in setup_policy.hh_validate(m,f,c)
    m.ems_frame=0xe000;m.loaded=1
    assert b'already loaded' in setup_policy.hh_validate(m,f,c)


@pytest.fixture
def setup_guest(tmp_path,pytestconfig):
    exe=pytestconfig.getoption('--setup-exe')
    if exe is None:
        pytest.skip('Optional SETUP build: pass --setup-exe or SETUP_EXE')
    assert exe.is_file(),f'SETUP.EXE does not exist: {exe}'
    shutil.copy2(exe,tmp_path)
    for name in ('READ2','READ4','READ5','CKBD','VGA','VESA','EGA','HGA','CGA','WBX'):
        shutil.copy2(ROOT/'build'/f'{name}.COM',tmp_path)
    for name in ('HZK16','HH20.FNT'): shutil.copy2(ROOT/'fonts'/name,tmp_path)
    return tmp_path


@pytest.mark.dos
@pytest.mark.parametrize('settings,options,reader,display',[
    ('xms=true\nems=true\numb=true','','READ5','VESA'),
    ('xms=false\nems=true\numb=true','','READ4','VESA'),
    ('xms=false\nems=false\numb=false','','READ2','VGA'),
    ('xms=true\nems=true\numb=true','/LOW /VIDEO:VGA /IME:WB','READ5','VGA'),
])
def test_generated_startup_in_dos(dosbox_binary,setup_guest,settings,options,reader,display):
    directory=setup_guest
    files=run_dos(dosbox_binary,directory,[
        'SETUP /REPORT > BEFORE.TXT', 'SETUP /AUTO '+options+' > SAVE.TXT',
        'SETUP /REPORT > AFTER.TXT','CALL HHBIOS.BAT > LOAD.TXT',
        'SETUP /REPORT > LOADED.TXT'],settings='\n[dosbox]\nmachine=svga_s3\n[dos]\n'+settings+'\n')
    before=dict(line.split('=',1) for line in files['BEFORE.TXT'].read_text().splitlines())
    after=dict(line.split('=',1) for line in files['AFTER.TXT'].read_text().splitlines())
    assert before==after, 'Setup changed manager state or leaked memory'
    assert 'HHBIOS_LOADED=1' in files['LOADED.TXT'].read_text()
    batch=files['HHBIOS.BAT'].read_text()
    assert reader+'.COM' in batch and display+'.COM' in batch
    assert 'HHBIOS load failed' not in files['LOAD.TXT'].read_text(errors='replace')


@pytest.mark.dos
def test_setup_started_from_another_drive(dosbox_binary,setup_guest):
    files=run_dos(dosbox_binary,setup_guest,['Z:',r'C:\SETUP /AUTO','C:'],
                  settings='\n[dosbox]\nmachine=svga_s3\n')
    assert '\nC:\nCD \\\n' in files['HHBIOS.BAT'].read_text()


@pytest.mark.dos
def test_chinese_setup_rejects_missing_font_without_writing(dosbox_binary,setup_guest):
    (setup_guest/'HZK16').unlink()
    files=run_dos(dosbox_binary,setup_guest,[('SETUP /ZH > ERROR.TXT',1)],
                  settings='\n[dosbox]\nmachine=svga_s3\n')
    assert 'HZK16' in files['ERROR.TXT'].read_text()
    assert 'HHBIOS.BAT' not in files and '213L.INI' not in files

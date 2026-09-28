"""Setup decisions and real generated DOS startup paths."""
import ctypes as C
import shutil
import struct
import subprocess

import pytest

from qa.spec.dos import ROOT, run_dos


class DisplayMode(C.Structure):
    _fields_=[(s,C.c_uint) for s in 'number width height rows banked'.split()]


class Machine(C.Structure):
    _fields_=[(s,C.c_uint) for s in ('dos_major dos_minor conventional_kb free_kb umb_kb cpu '
        'xms_version xms_largest xms_total ems_version ems_pages ems_frame dpmi adapter '
        'vbe_version modes loaded alloc_strategy umb_link edid_status preferred_width '
        'preferred_height preferred_bios display_count display_truncated').split()] + [
        ('display_modes',DisplayMode*64)]


class FontInfo(C.Structure):
    _fields_=[(name,C.c_ushort) for name in
        ('format','width','height','record_bytes','records')]+[('payload_bytes',C.c_uint)]


class DisplayFont(C.Structure):
    _fields_=[('name',C.c_char*13),('info',FontInfo)]


class Files(C.Structure):
    _fields_=[('size',C.c_ulong*31),('display_font_count',C.c_uint),
        ('display_font_truncated',C.c_uint),('display_fonts',DisplayFont*257)]


class Choices(C.Structure):
    _fields_=[(s,C.c_uint) for s in ('font low video ime paired mode rows '
        'special_display printer print_fonts print_memory printer_flags vector_access').split()] + [
        ('print_files', ((C.c_char*128)*4)*3)]


class Ini(C.Structure):
    _fields_=[('value', C.c_ubyte*32)]


@pytest.fixture(scope='module')
def setup_policy(tmp_path_factory,source_dir):
    out=tmp_path_factory.mktemp('setup-host')/'setup.so'
    result=subprocess.run(['c++','-std=c++98','-shared','-fPIC','-Wall','-Wextra','-Werror','-DVESA_HOST',
        '-I'+str(source_dir/'setup'), '-I'+str(source_dir/'video/vesa'), str(source_dir/'setup/config.c'),
        str(source_dir/'setup/modules.c'),
        str(source_dir/'setup/font.c'), str(source_dir/'common/font_file.c'),
        str(source_dir/'common/font_layout.c'),
        str(source_dir/'setup/display.c'), str(source_dir/'video/vesa/vesa.c'),
        str(ROOT/'qa/harness/setup_host.cpp'),'-o',str(out)],capture_output=True,text=True)
    assert result.returncode==0,result.stdout+result.stderr
    lib=C.CDLL(str(out))
    lib.hh_abi_size.argtypes=[C.c_uint]
    for index,structure in enumerate((Machine,Files,Choices,Ini)):
        assert lib.hh_abi_size(index)==C.sizeof(structure), 'host fixture ABI mismatch'
    for name in ('hh_validate','hh_validate_ini','hh_save'): getattr(lib,name).restype=C.c_char_p
    lib.hh_recommend.argtypes=[C.POINTER(Machine),C.POINTER(Files),C.POINTER(Choices)]
    lib.hh_validate.argtypes=lib.hh_recommend.argtypes
    lib.hh_batch.argtypes=[C.c_char_p,C.POINTER(Choices),C.c_char_p]
    lib.hh_ini.argtypes=lib.hh_batch.argtypes
    lib.hh_save.argtypes=[C.c_char_p,C.c_char_p]
    lib.hh_read_ini.argtypes=[C.c_char_p,C.POINTER(Ini)]
    lib.hh_make_ini.argtypes=[C.c_char_p,C.POINTER(Ini),C.c_char_p]
    lib.hh_validate_ini.argtypes=[C.POINTER(Ini)]
    lib.hh_assign.argtypes=[C.POINTER(Ini),C.c_uint,C.c_uint]
    lib.hh_great_wall.argtypes=[C.POINTER(Ini),C.c_uint]
    lib.hh_key_name.argtypes=[C.c_uint,C.c_char_p]
    lib.hh_import.argtypes=[C.c_char_p,C.POINTER(Choices)]
    return lib


def capable():
    m=Machine(dos_major=6,dos_minor=22,conventional_kb=640,free_kb=580,umb_kb=64,
              cpu=386,xms_version=0x300,xms_largest=8192,xms_total=8192,
              ems_version=0x40,ems_pages=128,ems_frame=0xe000,adapter=4,vbe_version=0x200,modes=7)
    f=Files((C.c_ulong*31)(*[10000]*31))
    f.size[9]=261696;f.size[10]=733208
    _,width,height,slots,records,payload=struct.unpack('<8s4HI12x',
        (ROOT/'fonts/HH20.FNT').read_bytes()[:32])
    assert slots==8434
    f.display_font_count=1
    f.display_fonts[0]=DisplayFont(b'HH20.FNT',FontInfo(1,width,height,
        (((width*2+7)//8)*height+1)&~1,records,payload))
    return m,f


@pytest.fixture
def printing_files(tmp_path,monkeypatch):
    monkeypatch.chdir(tmp_path)
    for size in (24,32,40):
        record_bytes=size*size//8
        data=struct.pack('<8s4HI12x',b'HHFONT2\n',size//2,size,8434,1,
                         33736+record_bytes)+bytes(33736+record_bytes)
        (tmp_path/f'HH{size}.FNT').write_bytes(data)
        (tmp_path/f'HH{size}F.FNT').write_bytes(data)
    return tmp_path


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
        if asset==10: f.display_font_count=0
        assert setup_policy.hh_validate(m,f,c)
        f.size[asset]=old
        if asset==10: f.display_font_count=1
    c.font=1;m.ems_frame=0
    assert b'page frame' in setup_policy.hh_validate(m,f,c)
    m.ems_frame=0xe000;m.loaded=1
    m.free_kb=m.xms_largest=m.xms_total=m.ems_pages=0
    assert setup_policy.hh_validate(m,f,c) is None


# The shipped 2.13L INI uses Great Wall pseudo scan codes, ASCII switches and
# two reserved byte pairs. Keep this independent of generated defaults.
LEGACY_VALUES = bytes([
    2, 1, 5, 0x39, 0, 0x1e, 0x1a, 0x4e, 0x4a, 0, 0x10,
    0x64, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0x6c, 0x71,
    0x86, 0x85, 0x62, 0x70, 0x67, 0, 0, ord('Y'), ord('1'),
    ord('Y'), ord('N'), ord('N')])


def legacy_ini():
    return b''.join(f'{v:02X}H\t; '.encode() + '原配置'.encode('gb2312') + b'\r\n'
                    for v in LEGACY_VALUES) + b'; trailing comment\r\n\x1a'


@pytest.mark.unit
def test_legacy_great_wall_roundtrip_and_disable(setup_policy):
    source = legacy_ini()
    settings = Ini()
    output = C.create_string_buffer(8192)
    assert setup_policy.hh_read_ini(source, settings)
    assert bytes(settings.value) == LEGACY_VALUES
    assert setup_policy.hh_validate_ini(settings) is None
    assert setup_policy.hh_make_ini(source, settings, output)
    assert output.value == source
    assert setup_policy.hh_great_wall(settings, 0)
    assert bytes(settings.value[12:18]) == bytes([0x68, 0x69, 0x6a, 0x6b, 0x66, 0x6d])
    assert bytes(settings.value[:12]) == LEGACY_VALUES[:12]
    assert bytes(settings.value[18:27]) == LEGACY_VALUES[18:27]
    assert setup_policy.hh_validate_ini(settings) is None
    assert setup_policy.hh_make_ini(source, settings, output)
    assert output.value.endswith(b'; trailing comment\r\n\x1a')
    assert setup_policy.hh_great_wall(settings, 1)
    assert bytes(settings.value) == LEGACY_VALUES


@pytest.mark.unit
def test_conflicting_keys_and_great_wall_remap_are_transactional(setup_policy):
    settings = Ini((C.c_ubyte*32).from_buffer_copy(LEGACY_VALUES))
    before = bytes(settings)
    assert not setup_policy.hh_assign(settings, 0, 0x62)
    assert not setup_policy.hh_assign(settings, 0, 0)
    assert not setup_policy.hh_assign(settings, 14, 0x54)
    assert not setup_policy.hh_assign(settings, 2, 0x55)  # CKBD overrides GW keys.
    assert bytes(settings) == before
    assert setup_policy.hh_assign(settings, 0, 0x68)
    before = bytes(settings)
    assert not setup_policy.hh_great_wall(settings, 0)  # standard Alt+F1 conflicts
    assert bytes(settings) == before


@pytest.mark.unit
@pytest.mark.parametrize('key,name', [(0x3b,b'F1'), (0x44,b'F10'),
    (0x54,b'Shift+F1'), (0x67,b'Ctrl+F10'), (0x71,b'Alt+F10'),
    (0x73,b'Ctrl+Left'), (0x78,b'Alt+1'), (0x84,b'Ctrl+PageUp'),
    (0x85,b'F11'), (0x8d,b'Ctrl+Up'), (0x96,b'Ctrl+Keypad*'),
    (0xf1,b'Insert (GW)'), (0xe1,b'E1h')])
def test_function_key_names_match_stored_scan_codes(setup_policy,key,name):
    output=C.create_string_buffer(32)
    setup_policy.hh_key_name(key,output)
    assert output.value==name


@pytest.mark.unit
@pytest.mark.parametrize('index,value', [(10,3),(28,ord(':')),(27,ord('y')),
    (29,0),(11,0),(11,0x62)])
def test_reject_invalid_editable_ini_values(setup_policy,index,value):
    settings=Ini((C.c_ubyte*32).from_buffer_copy(LEGACY_VALUES))
    settings.value[index]=value
    assert setup_policy.hh_validate_ini(settings)


@pytest.mark.unit
@pytest.mark.parametrize('ending',[b'\n',b'\r\n'])
def test_ini_retains_unknown_bits_reserved_bytes_and_short_hex(setup_policy,ending):
    lines=[f'{v:02x}h ; keep'.encode()+ending for v in LEGACY_VALUES]
    lines[4]=b'0 ; reserved'+ending
    lines[25]=b'A5H ; vendor extension'+ending
    source=b''.join(lines)+b'\x1a'
    settings=Ini(); output=C.create_string_buffer(8192)
    assert setup_policy.hh_read_ini(source,settings)
    settings.value[0]^=8
    settings.value[6]=0x32
    assert setup_policy.hh_make_ini(source,settings,output)
    expected=lines[:]
    for index in (0,6):
        expected[index]=f'{settings.value[index]:02X}'.encode()+lines[index][2:]
    assert output.value==b''.join(expected)+b'\x1a'


@pytest.mark.unit
def test_nearly_full_ini_does_not_need_extra_save_slack(setup_policy):
    prefix=b'02\n'*32
    source=prefix+b';'*(8190-len(prefix))+b'\x1a'
    settings=Ini(); output=C.create_string_buffer(8192)
    assert setup_policy.hh_read_ini(source,settings)
    settings.value[5]=0xee
    assert setup_policy.hh_make_ini(source,settings,output)
    assert len(output.value)==len(source)==8191
    assert output.value[:15]==source[:15]
    assert output.value[15:17]==b'EE'


@pytest.mark.unit
@pytest.mark.parametrize('source',[b'02\n'*31+b'\x1a02\n',b'0\t\n'*32,b'02\n'*32+b'x'*8192])
def test_invalid_ini_leaves_settings_untouched(setup_policy,source):
    settings=Ini((C.c_ubyte*32).from_buffer_copy(LEGACY_VALUES))
    assert not setup_policy.hh_read_ini(source,settings)
    assert bytes(settings.value)==LEGACY_VALUES


@pytest.mark.unit
@pytest.mark.parametrize('font,video,mode,rows,low',[(0,0,0,0,0),
    (1,3,0,50,1),(2,4,0,25,0),(0,7,0x220,43,1)])
def test_reopening_generated_batch_restores_startup_choices(setup_policy,font,video,mode,rows,low):
    original=Choices(font,low,video,15,1,mode,rows)
    original.special_display=2
    original.printer=12  # PR 11 precedes PRTH
    original.print_fonts=31
    original.print_memory=2
    original.print_files[0][1].value=b'HH24F.FNT'
    original.print_files[1][2].value=b'HH32H.FNT'
    original.print_files[2][3].value=b'HH40K.FNT'
    first=C.create_string_buffer(4096); second=C.create_string_buffer(4096)
    assert setup_policy.hh_batch(br'C:\HHBIOS',original,first)
    restored=Choices(ime=7)
    assert setup_policy.hh_import(first.value,restored)
    assert (restored.font,restored.video,restored.mode,restored.rows,restored.low)==(
        font,video,mode,rows if rows>25 else 0,low)
    assert restored.ime==15 and restored.paired==1
    assert restored.special_display==2 and restored.printer==12
    assert first.value.index(b'.\\PR.EXE 11') < first.value.index(b'.\\PRTH.COM')
    assert b'.\\READ24.COM /F1:HH24F.FNT /E' in first.value
    assert setup_policy.hh_batch(br'C:\HHBIOS',restored,second)
    assert first.value==second.value


@pytest.mark.unit
def test_legacy_batch_paths_font_styles_and_printer_flags(setup_policy):
    source=(b'@echo off\r\nREM PRNT 9\r\nLH C:\\213L\\READ4.COM /N\r\n'
            b'  ckbd /b\r\nC:\\213L\\VGA\r\nINT10K\r\n'
            b'READ24 /F1:HH24F.FNT /X\r\nREADSL\r\nPRNT 5 /1 /4 /N\r\n\x1aPRNT 9\r\n')
    choices=Choices(ime=5); output=C.create_string_buffer(4096)
    assert setup_policy.hh_import(source,choices)
    assert (choices.font,choices.low,choices.video,choices.paired)==(1,1,0,0)
    assert choices.print_fonts==18 and choices.print_memory==1
    assert choices.vector_access==2 and choices.printer_flags==9
    assert choices.ime==5
    assert setup_policy.hh_batch(br'C:\213L',choices,output)
    assert b'.\\READ24.COM /F1:HH24F.FNT /X /N\r\n' in output.value
    assert b'.\\READSL.COM /N\r\n' in output.value
    assert b'.\\PRNT.COM 5 /1 /4 /N\r\n' in output.value


@pytest.mark.unit
@pytest.mark.parametrize('bitmap,vector,expected', [
    (b'/X', b'', 2), (b'/E', b'W', 1)])
def test_vector_and_bitmap_readers_keep_independent_access(setup_policy,bitmap,vector,expected):
    source=b'READ24 '+bitmap+b'\r\nREADSL '+vector+b'\r\n'
    choices=Choices(); output=C.create_string_buffer(4096)
    assert setup_policy.hh_import(source,choices)
    assert choices.vector_access==expected
    assert setup_policy.hh_batch(br'C:\HHBIOS',choices,output)
    assert b'.\\READ24.COM '+bitmap+b'\r\n' in output.value
    assert b'.\\READSL.COM'+(b' '+vector if vector else b'')+b'\r\n' in output.value
    restored=Choices()
    assert setup_policy.hh_import(output.value,restored)
    assert restored.vector_access==expected


@pytest.mark.unit
@pytest.mark.parametrize('source',[b'PRNT garbage',b'PRNT -1',b'PRNT 10',
    b'PRNT 2extra',b'PRTH',b'PR 12\nPRTH',b'READ24 W',b'READ24 WXYZ',
    b'READ24 WSFHKJ',b'READ24 1S\nREAD32 2S',b'CKBD /BOGUS',
    b'VESA /M:garbage',b'VESA /M:4102',b'VESA /R:0',b'VESA /R:51',b'PRTH /S'])
def test_malformed_loader_arguments_never_partially_replace_choices(setup_policy,source):
    choices=Choices(1,1,3,15,1,0,50)
    before=bytes(choices)
    assert not setup_policy.hh_import(source,choices)
    assert bytes(choices)==before


@pytest.mark.unit
def test_selected_printing_fonts_and_models_require_real_assets(setup_policy,printing_files):
    machine,files=capable(); choices=Choices(0,0,0,0,1)
    choices.print_fonts=2; choices.print_files[0][1].value=b'HH24F.FNT'
    files.size[21]=0
    assert setup_policy.hh_validate(machine,files,choices)
    files.size[21]=10000
    for name in ('HH24.FNT','HH24F.FNT'):
        path=printing_files/name
        original=path.read_bytes(); path.unlink()
        assert setup_policy.hh_validate(machine,files,choices)
        path.write_bytes(original)
    choices.print_fonts=16
    for missing in (24,28,29):
        original=files.size[missing]; files.size[missing]=0
        assert setup_policy.hh_validate(machine,files,choices)
        files.size[missing]=original
    choices.print_fonts=0; choices.printer=11
    files.size[19]=0  # PR.EXE
    assert b'PR.EXE' in setup_policy.hh_validate(machine,files,choices)
    files.size[19]=10000
    files.size[30]=0  # PRTA.TAB
    assert b'PRTA.TAB' in setup_policy.hh_validate(machine,files,choices)


@pytest.mark.unit
def test_optional_modules_count_toward_conventional_load_estimate(setup_policy,printing_files):
    machine,files=capable(); choices=Choices(0,0,0,0,1)
    machine.free_kb=70
    assert setup_policy.hh_validate(machine,files,choices) is None
    choices.print_fonts=2
    assert b'conventional' in setup_policy.hh_validate(machine,files,choices)
    machine.loaded=1; machine.free_kb=0
    assert setup_policy.hh_validate(machine,files,choices) is None


@pytest.mark.unit
def test_batch_rejects_unterminated_or_injected_font_path(setup_policy):
    choices=Choices(); choices.print_fonts=2
    choices.print_files[0][0].value=b'HH24.FNT&X'
    assert not setup_policy.hh_batch(br'C:\HHBIOS',choices,C.create_string_buffer(4096))


@pytest.mark.unit
def test_printing_memory_reserves_core_and_distinct_faces(setup_policy,printing_files):
    machine,files=capable(); choices=Choices(0,0,0,0,1)
    choices.print_fonts=2
    machine.xms_largest=machine.xms_total=290  # READ5 256 + font 34 KiB
    machine.ems_pages=0
    assert setup_policy.hh_validate(machine,files,choices) is None
    choices.print_files[0][1].value=b'HH24.FNT'  # aliases share one allocation
    assert setup_policy.hh_validate(machine,files,choices) is None
    choices.print_files[0][1].value=b'HH24F.FNT'
    assert b'printing fonts' in setup_policy.hh_validate(machine,files,choices)
    machine.ems_pages=3  # second font fits a 48 KiB EMS allocation
    assert setup_policy.hh_validate(machine,files,choices) is None
    choices.print_memory=1
    assert b'printing fonts' in setup_policy.hh_validate(machine,files,choices)
    choices.print_memory=2; machine.ems_pages=6
    assert setup_policy.hh_validate(machine,files,choices) is None
    machine.loaded=1; machine.ems_pages=0; machine.xms_largest=machine.xms_total=0
    assert setup_policy.hh_validate(machine,files,choices) is None
    machine.ems_version=0
    assert b'printing fonts' in setup_policy.hh_validate(machine,files,choices)


@pytest.mark.unit
@pytest.mark.parametrize('corruption',['truncated','wrong-cell','reserved','extra-byte'])
def test_printing_font_is_validated_before_batch_replacement(setup_policy,printing_files,corruption):
    machine,files=capable(); choices=Choices(0,0,0,0,1)
    choices.print_fonts=2
    path=printing_files/'HH24.FNT'
    data=bytearray(path.read_bytes())
    if corruption=='truncated': del data[-1:]
    elif corruption=='wrong-cell': data[8]=16
    elif corruption=='reserved': data[31]=1
    else: data.append(0)
    path.write_bytes(data)
    assert b'HHFONT2' in setup_policy.hh_validate(machine,files,choices)


@pytest.mark.unit
@pytest.mark.parametrize('source',[b'READ24 /F:',b'READ24 /F4:X.FNT',
    b'READ24 /F0:X.FNT&OTHER',b'READ24 /X /E',b'READ24 /X\nREAD32 /E',
    b'READ24 WSFHK',b'READ40 9S'])
def test_unrepresentable_printing_options_are_rejected_transactionally(setup_policy,source):
    choices=Choices(); before=bytes(choices)
    assert not setup_policy.hh_import(source,choices)
    assert bytes(choices)==before


@pytest.mark.unit
def test_printing_command_respects_dos_tail_limit(setup_policy):
    choices=Choices(); choices.print_fonts=2
    for face in range(4): choices.print_files[0][face].value=b'C:\\'+b'A'*32+b'.FNT'
    assert not setup_policy.hh_batch(br'C:\HHBIOS',choices,C.create_string_buffer(4096))


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

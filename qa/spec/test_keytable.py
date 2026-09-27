"""Production CKBD searches and XMS transfers, plus DOS ownership lifecycle."""
import os
import re
import shutil
import struct
import subprocess

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn import x86_const as reg

from qa.spec.dos import ROOT, run_dos
from qa.spec.test_application import keyboard_config
from qa.spec.test_dos_display import guest_build
from qa.spec.test_memory import Arena, memory_build
from qa.spec.test_msdos import copy_disk, msdos_image

SYMBOLS = ('S_TABLE_WORD', 'S_TABLE_NEXT', 'S_TABLE_OPEN', 'T_XMS', 'T_HANDLE',
           'T_BASE', 'T_LENGTH', 'T_PAGE', 'T_BUSY', 'T_FAULT', 'T_CACHE', 'T_LOCAL',
           'S_A017', 'S_A011', 'L_A28F', 'D_2BD6', 'D_2BD8', 'D_2BAD', 'D_963A',
           'D_2BB0', 'D_2BB1', 'D_2BB9', 'D_2BBA', 'D_2BD2', 'D_9597',
           'S_A9C0', 'D_PY', 'L_A597', 'D_DB')


@pytest.fixture(scope='session')
def table_binary(assembler, source_dir, tmp_path_factory):
    out = tmp_path_factory.mktemp('keytable')
    source = (source_dir / 'CKBD.ASM').read_bytes()
    footer = b"DB 'HHTABLE1'\r\nDW " + ', '.join(SYMBOLS).encode() + b'\r\nSEG_A ENDS'
    source, count = re.subn(rb'SEG_A\s+ENDS', lambda _: footer, source)
    assert count == 1
    path = out / 'ckbd.asm'
    path.write_bytes(source)
    result = subprocess.run([assembler, '-q', '-Zm', '-bin', '-I'+str(source_dir),
                             '-Fo'+str(out/'CKBD.COM'), str(path)], capture_output=True,
                            env={k: v for k, v in os.environ.items() if k != 'JWASM'})
    assert result.returncode == 0, result.stdout + result.stderr
    raw = (out/'CKBD.COM').read_bytes()
    symbols = dict(zip(SYMBOLS, struct.unpack_from('<'+str(len(SYMBOLS))+'H', raw,
                                                  raw.rindex(b'HHTABLE1')+8)))
    return raw, symbols


class Tables:
    def __init__(self, binary, payload, xms=True):
        raw, self.symbols = binary
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, 0x100000)
        self.uc.mem_write(0x10100, raw)
        self.payload = payload
        self.base = 0x6000
        self.moves = []
        self.allocated = xms
        self.failure = None
        self.nested = None
        self.xms_present = True
        self.uc.mem_write(0x90000, b'\xcd\x65\xcb')  # manager far-call boundary
        self.write('T_XMS', struct.pack('<HH', 0, 0x9000))
        self.word('T_BASE', self.base)
        self.word('T_LENGTH', len(payload))
        self.word('T_HANDLE', 7 if xms else 0)
        self.uc.mem_write(0x10000+self.base, b'\xa5'*len(payload) if xms else payload)
        self.uc.hook_add(UC_HOOK_INTR, self.interrupt)

    def get(self, name):
        return self.uc.reg_read(getattr(reg, 'UC_X86_REG_'+name))

    def put(self, name, value):
        self.uc.reg_write(getattr(reg, 'UC_X86_REG_'+name), value)

    def write(self, name, value):
        self.uc.mem_write(0x10000+self.symbols[name], value)

    def read(self, name, size=2):
        return bytes(self.uc.mem_read(0x10000+self.symbols[name], size))

    def word(self, name, value):
        self.write(name, struct.pack('<H', value))

    def interrupt(self, uc, number, _):
        if number == 0x2f:
            if self.get('AX') == 0x4300:
                self.put('AX', 0x4380 if self.xms_present else 0x4300)
            else:
                assert self.get('AX') == 0x4310
                self.put('ES', 0x9000)
                self.put('BX', 0)
            return
        assert number == 0x65
        function = self.get('AX') >> 8
        if function == 9:
            assert not self.allocated
            self.allocated = self.failure != 'allocate'
            self.put('AX', int(self.allocated))
            self.put('DX', 7)
        elif function == 10:
            assert self.allocated and self.get('DX') == 7
            self.allocated = False
            self.put('AX', 1)
        else:
            assert function == 11 and self.allocated
            descriptor = bytes(uc.mem_read(self.get('DS')*16+self.get('SI'), 16))
            length, source, offset, target, destination = struct.unpack('<IHIHI', descriptor)
            assert length and not length & 1
            self.moves.append((length, source, offset, target, destination))
            if source:
                assert source == 7 and target == 0 and offset+length <= len(self.payload)
                address = (destination >> 16)*16+(destination & 65535)
                uc.mem_write(address, self.payload[offset:offset+length])
                if self.nested is not None:
                    nested, self.nested = self.nested, None
                    context = uc.context_save()
                    assert self.read('T_BUSY', 1) == b'\1'
                    assert self.call('S_TABLE_WORD', BX=self.base+nested) == int.from_bytes(
                        self.payload[nested:nested+2], 'little')
                    uc.context_restore(context)
                    assert bytes(uc.mem_read(self.get('DS')*16+self.get('SI'), 16)) == descriptor
            else:
                assert target == 7 and destination == 0
                address = (offset >> 16)*16+(offset & 65535)
                assert bytes(uc.mem_read(address, length)) == self.payload
            self.put('AX', 0 if self.failure == 'move' else 1)
        # XMS returns an error code in BL; callers must not keep an offset there.
        self.put('BX', (self.get('BX') & 0xff00) | 0x80)

    def call(self, entry, **registers):
        depth = getattr(self, 'depth', 0)
        self.depth = depth+1
        sp = 0xf000-depth*0x1000
        defaults = dict(CS=0x1000, DS=0x1000, ES=0x1000, SS=0x8000, SP=sp,
                        EFLAGS=0x202, AX=0x2345, BX=0x3456, CX=0x4567,
                        DX=0x5678, SI=0x6789, DI=0x789a, BP=0x89ab)
        defaults.update(registers)
        for name, value in defaults.items():
            self.put(name, value)
        self.uc.mem_write(defaults['SS']*16+sp, b'\x00\xff')
        self.uc.emu_start(0x10000+self.symbols[entry], 0x1ff00, count=2000000)
        assert self.get('IP') == 0xff00 and self.get('SP') == sp+2
        self.depth = depth
        if entry == 'S_TABLE_WORD':
            for name, value in defaults.items():
                if name not in ('AX', 'SP'):
                    assert self.get(name) == value, name
        return self.get('AX')


@pytest.mark.unit
@pytest.mark.parametrize('flags', [0x2, 0x202, 0x602, 0x647])
def test_table_words_cache_tail_and_registers(table_binary, flags):
    data = bytes((i*17+i//256) & 255 for i in range(3078))
    machine = Tables(table_binary, data)
    for offset in [0, 2, 1022, 1024, 2046, 3072, 3076, 0]:
        assert machine.call('S_TABLE_WORD', BX=machine.base+offset, DS=0x7000,
                            EFLAGS=flags) == int.from_bytes(data[offset:offset+2], 'little')
    assert [move[:3] for move in machine.moves] == [
        (1024, 7, 0), (1024, 7, 1024), (6, 7, 3072), (1024, 7, 0)]
    for offset in [-2, 1, len(data), len(data)+2]:
        assert machine.call('S_TABLE_WORD', BX=machine.base+offset) == 0
    assert machine.read('T_FAULT', 1) == b'\1'


@pytest.mark.unit
def test_failed_fill_and_nested_lookup_do_not_publish_or_replace_cache(table_binary):
    data = bytes(range(256))*16
    machine = Tables(table_binary, data)
    machine.failure = 'move'
    assert machine.call('S_TABLE_WORD', BX=machine.base) == 0
    assert machine.read('T_PAGE') == b'\xff\xff'
    assert machine.read('T_BUSY', 1) == b'\0'
    machine.failure = None
    machine.nested = 2050
    assert machine.call('S_TABLE_WORD', BX=machine.base+10) == 0x0b0a
    assert machine.moves[-1][:3] == (2, 7, 2050)
    assert machine.read('T_PAGE') == b'\0\0'
    assert machine.call('S_TABLE_WORD', BX=machine.base+12) == 0x0d0c
    assert len(machine.moves) == 3


@pytest.mark.unit
@pytest.mark.parametrize('failure', [None, 'absent', 'allocate', 'move', 'local'])
def test_install_only_discards_tables_after_success(table_binary, failure):
    data = bytes(range(256))*8
    machine = Tables(table_binary, data, False)
    machine.failure = failure
    machine.xms_present = failure != 'absent'
    machine.write('T_LOCAL', bytes([failure == 'local']))
    machine.call('S_TABLE_OPEN', BP=machine.base+len(data))
    assert machine.get('BP') == machine.base+(len(data) if failure else 1024)
    assert machine.allocated == (failure is None)
    assert machine.read('T_HANDLE') == (b'\0\0' if failure else b'\7\0')
    assert bytes(machine.uc.mem_read(0x10000+machine.base, len(data))) == data


@pytest.mark.unit
@pytest.mark.parametrize('reverse', [False, True])
@pytest.mark.parametrize('keys', [b'a', b'ab', b'abc'])
@pytest.mark.parametrize('xms', [False, True])
def test_production_candidate_search_and_reverse_order(table_binary, reverse, keys, xms):
    codes = [(i % 26+1) | ((i//26 % 26+1) << 5) | ((i//676 % 26+1) << 10)
             for i in range(6768)]
    machine = Tables(table_binary, struct.pack('<6768H', *codes), xms)
    base = machine.base
    machine.word('D_2BD6', base)
    machine.word('D_2BD8', base+len(codes)*2)
    machine.word('D_2BAD', base+(len(codes)-1)*2 if reverse else base)
    machine.write('D_963A', b'\2')  # shape-code search, without pinyin preprocessing
    machine.write('D_2BB0', bytes([len(keys)]))
    machine.write('D_2BB1', keys)
    machine.call('S_A011' if reverse else 'S_A017')
    mask = (1 << (5*len(keys)))-1
    wanted = sum((key-96) << (5*i) for i, key in enumerate(keys))
    matches = [i for i, code in enumerate(codes) if code & mask == wanted]
    assert int.from_bytes(machine.read('D_9597'), 'little') == len(matches)
    candidates = matches[-11:] if reverse else matches[:11]
    raw = machine.read('D_2BBA', 22)
    if reverse:
        raw = raw[22-len(candidates)*2:]
    else:
        raw = raw[:len(candidates)*2]
    assert raw == b''.join(bytes([0xb0+i//94, 0xa1+i % 94]) for i in candidates)
    assert machine.read('T_FAULT', 1) == b'\0'


@pytest.mark.unit
@pytest.mark.parametrize('xms', [False, True])
def test_high_frequency_header_and_hanzi_reverse_lookup(table_binary, xms):
    header = bytes((i*31) & 255 for i in range(572))
    codes = [(i*613) & 65535 for i in range(6768)]
    machine = Tables(table_binary, header+struct.pack('<6768H', *codes), xms)
    machine.word('D_2BD6', machine.base+572)
    machine.word('D_PY', machine.base+572)
    for letter in range(26):
        machine.write('D_2BB9', b'\0')
        machine.call('L_A28F', BX=ord('a')+letter)
        assert machine.read('D_2BBA', 22) == header[letter*22:(letter+1)*22]
    for index in (0, 1, 225, 226, 511, 512, 1023, 1024, 6767):
        code = (0xb0+index//94) | ((0xa1+index % 94) << 8)
        assert machine.call('S_A9C0', AX=code) == codes[index]


@pytest.mark.unit
def test_two_key_frequency_flag_comes_from_xms(table_binary):
    codes = [(0x8000 if i % 3 == 0 else 0) | 0x41 for i in range(6768)]
    machine = Tables(table_binary, struct.pack('<6768H', *codes))
    machine.word('D_2BD6', machine.base)
    machine.word('D_2BD8', machine.base+len(codes)*2)
    machine.word('D_2BAD', machine.base)
    machine.write('D_963A', b'\x08')
    machine.write('D_2BB0', b'\2')
    machine.write('D_2BB1', b'ab')
    machine.call('S_A017')
    assert int.from_bytes(machine.read('D_9597'), 'little') == 2256
    assert machine.read('D_2BBA', 22) == b''.join(bytes([0xb0, 0xa1+i*3]) for i in range(11))


@pytest.mark.unit
def test_telegraph_reverse_search_stops_before_table_end(table_binary):
    machine = Tables(table_binary, bytes(20000))
    machine.word('D_DB', machine.base)
    machine.call('L_A597', DI=machine.base, CX=machine.base+20000, DX=0xd6d0)
    assert machine.read('T_FAULT', 1) == b'\0'
    assert machine.get('DI') == machine.base+20000


@pytest.mark.dos
@pytest.mark.parametrize('xms,low,local', [(True, False, False), (True, True, False),
                                        (False, False, False), (True, False, True)])
@pytest.mark.parametrize('all_tables', [False, True])
def test_tables_and_vesa_release_all_memory(dosbox_binary, memory_build, table_binary,
                                           tmp_path, xms, low, local, all_tables):
    for path in memory_build.glob('*.COM'):
        shutil.copy2(path, tmp_path)
    for name in ('HZK16', 'HH20.FNT'):
        shutil.copy2(ROOT/'fonts'/name, tmp_path)
    result = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/imetable.c',
                             str(tmp_path/'IMETABLE.COM')], cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout+result.stderr
    keyboard_config(tmp_path)
    config = (tmp_path/'213L.INI').read_bytes().splitlines()
    config[29] = b'59'  # PYMB
    if all_tables:
        config[30] = config[31] = b'59'
    (tmp_path/'213L.INI').write_bytes(b'\r\n'.join(config)+b'\r\n')
    codes = [(i % 26+1) | ((i//26 % 26+1) << 5) for i in range(6768)]
    (tmp_path/'PYMB').write_bytes(bytes(572)+struct.pack('<6768H', *codes))
    if all_tables:
        (tmp_path/'SWMB').write_bytes(bytes(4)+struct.pack('<6768H', *reversed(codes)))
        (tmp_path/'DBMB').write_bytes(bytes(20000))
    suffix = ' /N' if low else ''
    commands = ['MEMORY BEFORE.TXT']
    for cycle in range(2):
        commands += [('READ5' if xms else 'READ4')+suffix,
                     'CKBD'+suffix+(' /C' if local else ''), 'VESA'+suffix+' > VESA.LOG',
                     f'MEMORY LIVE{cycle}.TXT', 'IMETABLE', f'COPY CODES.BIN CODES{cycle}.BIN',
                     'MEMORY off', f'MEMORY FREE{cycle}.TXT']
    files = run_dos(dosbox_binary, tmp_path, commands, timeout=90,
                    settings=f'\n[dosbox]\nmachine=svga_s3\n[dos]\nxms={str(xms).lower()}\nems=true\n')
    before = Arena(files['BEFORE.TXT'])
    for cycle in range(2):
        live, freed = (Arena(files[f'{name}{cycle}.TXT']) for name in ('LIVE', 'FREE'))
        expected = bytes(value for code in codes for value in (96+(code & 31), 96+(code >> 5)))
        assert files[f'CODES{cycle}.BIN'].read_bytes() == expected
        assert (freed.xms, freed.ems, freed.vectors, freed.occupied(), freed.occupied(True)) == (
            before.xms, before.ems, before.vectors, before.occupied(), before.occupied(True))
        keyboard = live.resident(0x16)
        size = next(block[3]*16 for block in live.blocks if block[0]+1 == keyboard)
        payload_size = 14108 + (13540+20000 if all_tables else 0)
        retained = 1024 if xms and not local else payload_size
        assert size == ((table_binary[1]['T_CACHE']+retained)//16+4)*16


@pytest.mark.dos
def test_msdos_distribution_tables_and_unload(dosbox_binary, memory_build,
                                             msdos_image, tmp_path):
    """Use the complete installed distribution, including its mutable SPCZ."""
    from qa.spec.dos import run_process

    image, copy_in, read = copy_disk(msdos_image, tmp_path)
    for name in ('READ5.COM', 'CKBD.COM', 'VESA.COM'):
        copy_in(memory_build/name, '::HHBIOS/'+name)
    copy_in(memory_build/'MEMORY.COM', '::MEMORY.COM')
    result = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/imetable.c',
                             str(tmp_path/'IMETABLE.COM')], cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout+result.stderr
    copy_in(tmp_path/'IMETABLE.COM', '::IMETABLE.COM')
    payload = read('HHBIOS/PYMB')
    assert len(payload) == 14108
    startup = re.sub(rb'(?im)^CALL HHBIOS.BAT\s*$', b'', read('AUTOEXEC.BAT'))
    (tmp_path/'STARTUP.BAT').write_bytes(startup)
    copy_in(tmp_path/'STARTUP.BAT', '::STARTUP.BAT')
    commands = ['@ECHO OFF', 'CALL C:\\STARTUP.BAT', '@ECHO OFF',
                'CD \\HHBIOS', 'C:\\MEMORY C:\\BEFORE.TXT']
    for cycle, option in enumerate(('/C', '', '')):
        commands += ['READ5', 'CKBD '+option, 'VESA',
                     f'C:\\MEMORY C:\\LIVE{cycle}.TXT', 'C:\\IMETABLE',
                     f'COPY CODES.BIN C:\\CODES{cycle}.BIN > NUL',
                     'C:\\MEMORY off', f'C:\\MEMORY C:\\FREE{cycle}.TXT']
    commands += ['ECHO complete>C:\\DONE.TXT', 'C:\\DOS\\SHUTDOWN /S']
    (tmp_path/'AUTOEXEC.BAT').write_bytes(('\r\n'.join(commands)+'\r\n').encode())
    copy_in(tmp_path/'AUTOEXEC.BAT', '::AUTOEXEC.BAT')
    config = (ROOT/'qa/dosbox.conf').read_text()
    config += '\n[dosbox]\nmachine=svga_s3\n[autoexec]\n'
    config += f'imgmount c "{image}" -ide 1m\nboot c:\n'
    (tmp_path/'dosbox.conf').write_text(config)
    run_process([str(dosbox_binary), '-conf', str(tmp_path/'dosbox.conf')], tmp_path, 180,
                dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy'))
    assert read('DONE.TXT').strip() == b'complete'
    read('BEFORE.TXT')
    before = Arena(tmp_path/'BEFORE.TXT')
    sizes = []
    expected = bytes(value for (code,) in struct.iter_unpack('<H', payload[572:])
                     for value in (96+(code & 31), 96+((code >> 5) & 31)))
    for cycle in range(3):
        for name in ('LIVE', 'FREE'):
            read(f'{name}{cycle}.TXT')
        live, freed = (Arena(tmp_path/f'{name}{cycle}.TXT') for name in ('LIVE', 'FREE'))
        assert read(f'CODES{cycle}.BIN') == expected
        assert (freed.xms, freed.ems, freed.vectors, freed.occupied(), freed.occupied(True)) == (
            before.xms, before.ems, before.vectors, before.occupied(), before.occupied(True))
        keyboard = live.resident(0x16)
        sizes.append(next(block[3]*16 for block in live.blocks if block[0]+1 == keyboard))
        assert keyboard >= 0xa000
        if cycle:
            assert live.resident(0x10) >= 0xa000
            assert live.occupied() == before.occupied()
    assert sizes[1] == sizes[2]
    assert abs((sizes[0]-sizes[1])-(len(payload)-1024)) < 16


@pytest.mark.dos
@pytest.mark.parametrize('local', [False, True])
def test_irq_input_and_candidate_paging(dosbox_binary, memory_build, tmp_path, local):
    for path in memory_build.glob('*.COM'):
        shutil.copy2(path, tmp_path)
    for name in ('HZK16', 'HH20.FNT'):
        shutil.copy2(ROOT/'fonts'/name, tmp_path)
    result = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/imetable.c',
                             str(tmp_path/'IMETABLE.COM')], cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout+result.stderr
    keyboard_config(tmp_path)
    config = (tmp_path/'213L.INI').read_bytes().splitlines()
    config[30] = b'59'
    (tmp_path/'213L.INI').write_bytes(b'\r\n'.join(config)+b'\r\n')
    codes = [(i % 26+1) | ((i//26 % 26+1) << 5) | ((i//676 % 26+1) << 10)
             for i in range(6768)]
    (tmp_path/'SWMB').write_bytes('首尾'.encode('gb2312')+struct.pack('<6768H', *codes))
    (tmp_path/'SCREEN.KEY').touch()
    files = run_dos(dosbox_binary, tmp_path, ['READ5', 'CKBD'+(' /C' if local else ''),
                    'VESA', 'IMETABLE type', 'MEMORY off'], physical_keys=True,
                    settings='\n[dosbox]\nmachine=svga_s3\n')
    # First candidates for a, a after forward/back paging, ab, and abc.
    assert files['TYPED.BIN'].read_bytes() == b''.join(
        bytes([0xb0+index//94, 0xa1+index % 94]) for index in (0, 0, 26, 1378))

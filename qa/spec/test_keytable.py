"""Production CKBD searches and XMS transfers, plus DOS ownership lifecycle."""
import os
import re
import shutil
import struct
import subprocess

import pytest
from qa.spec.build import source_file, build_mixed
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
           'S_A9C0', 'D_PY', 'L_A597', 'D_DB', 'D_SW', 'S_INDEX_OPEN',
           'I_HANDLE', 'I_SW', 'I_PY', 'I_LENGTH', 'P_HANDLE', 'P_LENGTH',
           'S_PHRASE_OPEN', 'S_A9000', 'D_SPCZ', 'D_2CC1', 'D_9648',
           'S_INDEX_SIZE', 'S_PHRASE_NEXT', 'D_959D', 'L_S60',
           'INT_16', 'S_DICT_OPEN', 'Q_HANDLE', 'Q_BASE', 'Q_CACHE',
           'Q_SERIAL', 'D_INKEY', 'D_PUMP')


@pytest.fixture(scope='session', params=['8086', '386', '586'])
def table_binary(assembler, source_dir, tmp_path_factory, request):
    out = tmp_path_factory.mktemp('keytable')
    source = source_file(source_dir, 'CKBD.ASM').read_bytes()
    footer = b"DB 'HHTABLE1'\r\nDW " + ', '.join(SYMBOLS).encode() + b'\r\nSEG_TAIL ENDS'
    source, count = re.subn(rb'SEG_TAIL\s+ENDS', lambda _: footer, source)
    assert count == 1
    path = out / 'ckbd.asm'
    path.write_bytes(source)
    raw = build_mixed(path, out/'CKBD.COM', source_dir, assembler, request.param)
    symbols = dict(zip(SYMBOLS, struct.unpack_from('<'+str(len(SYMBOLS))+'H', raw,
                                                  raw.rindex(b'HHTABLE1')+8)))
    return raw, symbols


@pytest.mark.unit
def test_install_helpers_fit_existing_return_buffer_prefix(table_binary):
    _, symbols = table_binary
    start = symbols['D_959D']
    assert start == symbols['S_INDEX_SIZE'] < symbols['S_PHRASE_NEXT'] < start + 64
    assert symbols['L_S60'] == start + 64
    assert symbols['T_CACHE'] == start + 1024


@pytest.mark.unit
def test_all_tables_and_index_staging_fit_the_installer_segment(table_binary):
    # The loader initially reads all three shipped code tables into this
    # segment, then stages index records above them before moving to XMS.
    _, symbols = table_binary
    assert symbols['T_CACHE'] + 14108 + 13540 + 20000 + 1024 <= 65536


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
        self.blocks = {7: bytearray(payload)} if xms else {}
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
            handle = max(self.blocks, default=6)+1
            ok = self.failure != 'allocate' and not (
                handle == 8 and self.failure == 'index_allocate')
            if ok:
                self.blocks[handle] = bytearray(self.get('DX') * 1024)
            self.allocated = 7 in self.blocks
            self.put('AX', int(ok))
            self.put('DX', handle)
        elif function == 10:
            del self.blocks[self.get('DX')]
            self.allocated = 7 in self.blocks
            self.put('AX', 1)
        else:
            assert function == 11 and self.allocated
            descriptor = bytes(uc.mem_read(self.get('DS')*16+self.get('SI'), 16))
            length, source, offset, target, destination = struct.unpack('<IHIHI', descriptor)
            assert length and not length & 1
            self.moves.append((length, source, offset, target, destination))
            if source:
                assert source in self.blocks and target == 0
                assert offset+length <= len(self.blocks[source])
                address = (destination >> 16)*16+(destination & 65535)
                uc.mem_write(address, bytes(self.blocks[source][offset:offset+length]))
                if self.nested is not None:
                    nested, self.nested = self.nested, None
                    context = uc.context_save()
                    assert self.read('T_BUSY', 1) == b'\1'
                    assert self.call('S_TABLE_WORD', BX=self.base+nested) == int.from_bytes(
                        self.payload[nested:nested+2], 'little')
                    uc.context_restore(context)
                    assert bytes(uc.mem_read(self.get('DS')*16+self.get('SI'), 16)) == descriptor
            else:
                assert target in self.blocks and destination+length <= len(self.blocks[target])
                address = (offset >> 16)*16+(offset & 65535)
                self.blocks[target][destination:destination+length] = uc.mem_read(address, length)
                if target == 7:
                    assert bytes(uc.mem_read(address, length)) == self.payload
            failed = self.failure == 'move' or (
                self.failure == 'index_move' and (source == 8 or target == 8))
            self.put('AX', int(not failed))
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
        sp = defaults['SP']
        for name, value in defaults.items():
            self.put(name, value)
        self.uc.mem_write(defaults['SS']*16+sp, b'\x00\xff')
        self.uc.emu_start(0x10000+self.symbols[entry], 0x1ff00, count=5000000)
        assert self.get('IP') == 0xff00 and self.get('SP') == sp+2
        self.depth = depth
        if entry == 'S_TABLE_WORD':
            for name, value in defaults.items():
                if name not in ('AX', 'SP'):
                    assert self.get(name) == value, name
        return self.get('AX')

    def index(self, table='D_SW', **registers):
        self.word(table, self.base)
        self.write(table, struct.pack('<HH', self.base, self.base+len(self.payload)))
        self.uc.mem_write(0x10000+self.base, self.payload)
        self.call('S_INDEX_OPEN', BP=self.base+len(self.payload), **registers)
        self.uc.mem_write(0x10000+self.base, b'\xa5'*len(self.payload))
        self.moves.clear()


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
@pytest.mark.parametrize('xms', [False, True, 'indexed'])
def test_production_candidate_search_and_reverse_order(table_binary, reverse, keys, xms):
    codes = [(i % 26+1) | ((i//26 % 26+1) << 5) | ((i//676 % 26+1) << 10)
             for i in range(6768)]
    machine = Tables(table_binary, struct.pack('<6768H', *codes), xms)
    if xms == 'indexed':
        machine.index()
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
    if xms == 'indexed':
        assert len(machine.moves) <= 2
        assert all(move[1] == 8 for move in machine.moves)


@pytest.mark.unit
@pytest.mark.parametrize('table', ['D_SW', 'D_PY'])
def test_index_builder_keeps_every_record_and_stable_order(table_binary, table):
    codes = [(i*613) & 65535 for i in range(6768)]
    machine = Tables(table_binary, struct.pack('<6768H', *codes))
    machine.index(table)
    assert machine.read('I_HANDLE') == b'\x08\0'
    heads = struct.unpack('<33H', machine.read('I_'+table[2:], 66))
    assert heads[0] == 0 and heads[-1] == 6768*4
    for key, (start, end) in enumerate(zip(heads, heads[1:])):
        expected = b''.join(struct.pack('<HH', machine.base+i*2, code)
                            for i, code in enumerate(codes) if code & 31 == key)
        assert machine.blocks[8][start:end] == expected


@pytest.mark.unit
@pytest.mark.parametrize('stack,expected', [(0xd0, True), (0xff00, True),
                                           (0x95e0, False)])
def test_index_scratch_handles_psp_and_high_stacks(table_binary, stack, expected):
    machine = Tables(table_binary, struct.pack('<6768H', *([1]*6768)))
    machine.index(SS=0x1000, SP=stack)
    assert (machine.read('I_HANDLE') != b'\0\0') == expected


@pytest.mark.unit
@pytest.mark.parametrize('failure', [None, 'index_allocate', 'index_move'])
@pytest.mark.parametrize('reverse,start', [(False, 0), (False, 2801), (True, 6767),
                                          (True, 1997)])
def test_index_matches_linear_paging_and_frequency_rules(table_binary, failure, reverse, start):
    codes = [((i*613) & 32767) | (32768 if i % 3 else 0) for i in range(6768)]
    payload = struct.pack('<6768H', *codes)
    linear = Tables(table_binary, payload)
    indexed = Tables(table_binary, payload)
    indexed.failure = failure
    indexed.index('D_PY')
    assert (8 in indexed.blocks) == (failure is None)
    indexed.failure = None
    indexed.nested = 512  # nested reverse-code lookup cannot replace index data
    for keys in (b'a', b'ab', b'abc', b'zz', b'zzz'):
        for machine in (linear, indexed):
            machine.word('D_2BD6', machine.base)
            machine.word('D_2BD8', machine.base+len(payload))
            machine.word('D_2BAD', machine.base+start*2)
            machine.write('D_963A', b'\x08')
            machine.write('D_2BB9', b'\x01')
            machine.write('D_2BB0', bytes([len(keys)]))
            machine.write('D_2BB1', keys)
            machine.write('D_2BBA', bytes(22))
            machine.call('S_A011' if reverse else 'S_A017')
        for name, length in [('D_2BBA', 22), ('D_2BD2', 1), ('D_9597', 2),
                             ('D_2BAD', 2), ('D_2BB9', 1)]:
            assert indexed.read(name, length) == linear.read(name, length), (keys, name)
        assert indexed.read('T_BUSY', 1) == b'\0'


@pytest.mark.unit
def test_failed_index_read_releases_cache_and_reports_fault(table_binary):
    machine = Tables(table_binary, struct.pack('<6768H', *([1]*6768)))
    machine.index()
    machine.failure = 'index_move'
    machine.word('D_2BD6', machine.base)
    machine.word('D_2BD8', machine.base+len(machine.payload))
    machine.word('D_2BAD', machine.base)
    machine.write('D_963A', b'\2')
    machine.write('D_2BB0', b'\1')
    machine.write('D_2BB1', b'a')
    machine.call('S_A017')
    assert machine.read('T_FAULT', 1) == b'\1'
    assert machine.read('T_BUSY', 1) == b'\0'
    assert machine.read('T_PAGE') == b'\xff\xff'


def phrase_fixture():
    codes = [(i % 26+1) | ((i//26 % 26+1) << 5) for i in range(6768)]
    def hanzi(index):
        return bytes([0xb0+index//94, 0xa1+index % 94])
    def keys(index):
        return bytes([96+(codes[index] & 31), 96+(codes[index] >> 5 & 31)])
    dictionary = bytearray(16)
    entries, queries = [], []
    for i in range(700):
        first = i*313 % 6768
        entries.append(struct.pack('<2sH', keys(first), len(dictionary)))
        dictionary += bytes(c & 127 for c in hanzi(first))
        for j in range(i % 9):  # includes empty groups
            second = (i*211+j*53) % 6768
            dictionary += hanzi(second)
            if i % 73 == 1:
                queries.append(keys(first)+keys(second))
    end = len(dictionary)
    # As in SPCZ.DAT, the first three-character record starts with a masked
    # Hanzi. It also terminates the preceding variable-length phrase group.
    dictionary += bytes(c & 127 for c in hanzi(310)) + hanzi(511) + hanzi(912)
    multi = len(dictionary)
    dictionary += hanzi(220) + hanzi(520) + hanzi(820) + hanzi(1120) + b','
    struct.pack_into('<4H', dictionary, 0, end, multi, len(dictionary), len(dictionary))
    dictionary[15] = 255
    return struct.pack('<6768H', *codes), dictionary, b''.join(entries), queries, hanzi


@pytest.mark.unit
@pytest.mark.parametrize('failure', [None, 'allocate', 'index_move'])
def test_phrase_index_matches_order_and_mutable_extension(table_binary, failure):
    payload, dictionary, expected, queries, hanzi = phrase_fixture()
    linear = Tables(table_binary, payload)
    indexed = Tables(table_binary, payload)
    for machine in (linear, indexed):
        machine.word('D_PY', machine.base)
        machine.word('D_SPCZ', 0x4000)
        machine.uc.mem_write(0x40000, bytes(dictionary))
    indexed.failure = failure
    indexed.call('S_PHRASE_OPEN')
    if failure is None:
        assert indexed.blocks[8][:len(expected)] == expected
        assert int.from_bytes(indexed.read('P_LENGTH'), 'little') == len(expected)
    else:
        assert 8 not in indexed.blocks and indexed.read('P_HANDLE') == b'\0\0'
    indexed.failure = None
    # Add a phrase after index construction, as ALT+F9 does. It must precede
    # basic candidates without rebuilding or invalidating their immutable index.
    extension = hanzi(313)+hanzi(211)+b','
    dictionary += extension
    struct.pack_into('<H', dictionary, 6, len(dictionary))
    for machine in (linear, indexed):
        machine.uc.mem_write(0x40000, bytes(dictionary))
    for query in [b'zzzz', b'~~~?'] + queries + [q[:3]+b'?' for q in queries]:
        for machine in (linear, indexed):
            machine.write('D_2CC1', query)
            machine.word('D_9597', 0)
            machine.write('D_2BD2', b'\0')
            machine.write('D_9648', bytes(44))
            machine.moves.clear()
            machine.call('S_A9000', DX=0)
        for name, size in [('D_9597', 2), ('D_2BD2', 1), ('D_9648', 44)]:
            assert indexed.read(name, size) == linear.read(name, size), (query, name)
        assert indexed.read('T_BUSY', 1) == b'\0'
        assert indexed.read('T_FAULT', 1) == b'\0'
        if failure is None and query == b'~~~?':
            assert len(indexed.moves) <= 5
            assert len(linear.moves) > 100


@pytest.mark.unit
def test_phrase_read_failure_releases_shared_cache(table_binary):
    payload, dictionary, _, _, _ = phrase_fixture()
    machine = Tables(table_binary, payload)
    machine.word('D_PY', machine.base)
    machine.word('D_SPCZ', 0x4000)
    machine.uc.mem_write(0x40000, bytes(dictionary))
    machine.call('S_PHRASE_OPEN')
    machine.failure = 'index_move'
    machine.write('D_2CC1', b'~~~?')
    machine.call('S_A9000', DX=0)
    assert machine.read('T_FAULT', 1) == b'\1'
    assert machine.read('T_BUSY', 1) == b'\0'


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
    # Measure the same CPU variant whose resident offsets we assert below.
    (tmp_path/'CKBD.COM').write_bytes(table_binary[0])
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
    dictionary = read('HHBIOS/SPCZ.DAT')
    two_end, = struct.unpack_from('<H', dictionary)
    basic_end, = struct.unpack_from('<H', dictionary, 4)
    groups = sum(not (word & 0x8080) for (word,) in
                 struct.iter_unpack('<H', dictionary[16:two_end]))
    table_kb = (len(payload)+1023)//1024
    index_kb = ((len(payload)-572)*2+1023)//1024 + (groups*4+1023)//1024
    dictionary_kb = (basic_end+1023)//1024
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
            assert local_xms-live.xms == table_kb+index_kb+dictionary_kb
            assert sizes[-1] < 24*1024
        else:
            local_xms = live.xms
    assert sizes[1] == sizes[2]
    # The full basic dictionary is replaced by its live header and 2 KiB
    # cache; mutable capacity remains resident. Paragraph rounding affects
    # both the table/dictionary boundary and the final allocation.
    saved = len(payload)-1024 + basic_end-16-2048
    assert abs((sizes[0]-sizes[1])-saved) < 64


@pytest.mark.dos
@pytest.mark.parametrize('local', [False, True])
@pytest.mark.parametrize('mode', ['type', 'phrase', 'pinyin'])
def test_irq_input_and_candidate_paging(dosbox_binary, memory_build, tmp_path, local, mode):
    for path in memory_build.glob('*.COM'):
        shutil.copy2(path, tmp_path)
    for name in ('HZK16', 'HH20.FNT'):
        shutil.copy2(ROOT/'fonts'/name, tmp_path)
    result = subprocess.run(['bash', 'tools/build-watcom-com.sh', 'qa/harness/imetable.c',
                             str(tmp_path/'IMETABLE.COM')], cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout+result.stderr
    keyboard_config(tmp_path)
    config = (tmp_path/'213L.INI').read_bytes().splitlines()
    config[30 if mode == 'type' else 29] = b'59'
    if mode == 'phrase':
        config[28] = b'31'  # mutable phrase extension space
    (tmp_path/'213L.INI').write_bytes(b'\r\n'.join(config)+b'\r\n')
    codes = [(i % 26+1) | ((i//26 % 26+1) << 5) | ((i//676 % 26+1) << 10)
             for i in range(6768)]
    (tmp_path/'SWMB').write_bytes('首尾'.encode('gb2312')+struct.pack('<6768H', *codes))
    if mode == 'pinyin':
        # zhong -> vs, shuang' -> ux, ang -> ag; three distinct GB2312 results.
        codes = [0x8276, 0x8315, 0x80e1] + [0x8042]*6765
        (tmp_path/'PYMB').write_bytes(b'\xb0\xa1'*286+struct.pack('<6768H', *codes))
    if mode == 'phrase':
        codes = [0x8041, 0x8023] + [0x8042]*6766
        (tmp_path/'PYMB').write_bytes(b'\xb0\xa1'*286+struct.pack('<6768H', *codes))
        dictionary = bytearray(16)
        dictionary += b'\x30\x21\xb0\xa2'  # two-character group
        # Large enough to exercise real XMS compaction, including its second
        # cache page; these groups have a different first pinyin key.
        dictionary += b'\x30\x23\xb0\xa4' * 1200
        two_end = len(dictionary)
        dictionary += b'\x30\x23\xb0\xa4\xb0\xa5'  # three-character section
        three_end = len(dictionary)
        dictionary += b'\xb0\xa3\xb0\xa4\xb0\xa5\xb0\xa6,'
        struct.pack_into('<4H', dictionary, 0, two_end, three_end,
                         len(dictionary), len(dictionary))
        dictionary[15] = 255
        (tmp_path/'SPCZ.DAT').write_bytes(dictionary)
    (tmp_path/'SCREEN.KEY').touch()
    files = run_dos(dosbox_binary, tmp_path, ['READ5', 'CKBD'+(' /C' if local else ''),
                    'VESA', 'IMETABLE '+mode, 'MEMORY off'], physical_keys=True,
                    settings='\n[dosbox]\nmachine=svga_s3\n')
    # First candidates for a, a after forward/back paging, ab, and abc.
    expected = {
        'type': b''.join(bytes([0xb0+index//94, 0xa1+index % 94])
                         for index in (0, 0, 26, 1378)),
        'phrase': b'\xb0\xa1\xb0\xa2',
        'pinyin': b'\xb0\xa1\xb0\xa2\xb0\xa3',
    }[mode]
    assert files['TYPED.BIN'].read_bytes() == expected

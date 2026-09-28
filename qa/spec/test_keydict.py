"""Execute the real dictionary storage layer across its XMS boundary."""
import os
import struct
import subprocess

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn import x86_const as reg

from qa.spec.build import asm_includes

pytestmark = pytest.mark.unit

SYMBOLS = ('S_DICT_OPEN', 'S_DICT_BYTE', 'S_DICT_WORD', 'S_DICT_LODSB',
           'S_DICT_LODSW', 'S_DICT_COPY', 'Q_HANDLE', 'Q_BASE', 'Q_CACHE',
           'Q_PAGE', 'Q_BUSY', 'T_XMS', 'T_HANDLE', 'T_LOCAL', 'T_FAULT', 'D_SPCZ', 'Q_SEG')


@pytest.fixture(scope='module', params=['8086', '386', '586'])
def dictionary_binary(request, assembler, source_dir, tmp_path_factory):
    directory = tmp_path_factory.mktemp('keydict')
    source = directory/'dictionary.asm'
    source.write_text('.model tiny\n.code\norg 100h\nstart label near\n'
                      'dw ' + ','.join(SYMBOLS) + '\n'
                      'D_SPCZ dw 0\nT_HANDLE dw 0\nT_LOCAL db 0\n'
                      'T_FAULT db 0\nT_XMS dd 0\ninclude KEYDICT.INC\nend start\n')
    target = directory/'dictionary.com'
    result = subprocess.run([assembler, '-q', '-0', '-Zm', '-bin',
                             '-DHH_CPU=' + {'8086': '0', '386': '3', '586': '5'}[request.param],
                             *asm_includes(source_dir), '-Fo' + str(target), str(source)],
                            env={key: value for key, value in os.environ.items() if key != 'JWASM'},
                            capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    image = target.read_bytes()
    return image, dict(zip(SYMBOLS, struct.unpack_from('<' + 'H'*len(SYMBOLS), image)))


class Dictionary:
    def __init__(self, binary, base=31865, extension=b'existing phrase,', reserve=1024):
        image, self.symbols = binary
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, 0x100000)
        self.uc.mem_write(0x10100, image)
        self.segment = 0x3000
        self.base = base
        self.used = base + len(extension)
        self.capacity = self.used + reserve
        data = bytearray((index * 73 + 29) & 255 for index in range(self.capacity + 2))
        struct.pack_into('<8H', data, 0, 16000, 30000, base, self.used,
                         self.capacity, 0, 0, 0xff00)
        data[base:self.used] = extension
        data[self.used:self.used + 2] = b'\0\0'
        self.original = bytes(data)
        self.uc.mem_write(self.segment * 16, self.original)
        self.blocks = {7: bytearray(1024)}
        self.moves = []
        self.failure = None
        self.nested = None
        self.write_word('D_SPCZ', self.segment)
        self.write_word('T_HANDLE', 7)
        self.write('T_XMS', struct.pack('<HH', 0, 0x9000))
        self.uc.mem_write(0x90000, b'\xcd\x65\xcb')
        self.uc.hook_add(UC_HOOK_INTR, self.interrupt)

    def get(self, name):
        return self.uc.reg_read(getattr(reg, 'UC_X86_REG_' + name))

    def put(self, name, value):
        self.uc.reg_write(getattr(reg, 'UC_X86_REG_' + name), value)

    def read(self, name, count=2):
        return bytes(self.uc.mem_read(0x10000 + self.symbols[name], count))

    def write(self, name, data):
        self.uc.mem_write(0x10000 + self.symbols[name], data)

    def word(self, name):
        return int.from_bytes(self.read(name), 'little')

    def write_word(self, name, value):
        self.write(name, struct.pack('<H', value))

    def interrupt(self, uc, number, _):
        assert number == 0x65
        function = self.get('AX') >> 8
        if function == 9:
            ok = self.failure != 'allocate'
            if ok:
                self.blocks[8] = bytearray(self.get('DX') * 1024)
            self.put('DX', 8)
        elif function == 10:
            del self.blocks[self.get('DX')]
            ok = True
        else:
            assert function == 11
            pointer = self.get('DS') * 16 + self.get('SI')
            descriptor = bytes(uc.mem_read(pointer, 16))
            length, source, offset, target, destination = struct.unpack('<IHIHI', descriptor)
            assert length and not length & 1
            self.moves.append((length, source, offset, target, destination))
            ok = self.failure != 'move'
            if source:
                assert source in self.blocks and not target
                assert offset + length <= len(self.blocks[source])
                if self.nested:
                    nested, self.nested = self.nested, None
                    assert self.read('Q_BUSY', 1) == b'\1'
                    context = uc.context_save()
                    nested(self)
                    uc.context_restore(context)
                    assert bytes(uc.mem_read(pointer, 16)) == descriptor
                if ok:
                    address = (destination >> 16) * 16 + (destination & 65535)
                    uc.mem_write(address, bytes(self.blocks[source][offset:offset + length]))
            else:
                assert target in self.blocks
                assert destination + length <= len(self.blocks[target])
                if ok:
                    address = (offset >> 16) * 16 + (offset & 65535)
                    self.blocks[target][destination:destination + length] = uc.mem_read(address, length)
        self.put('AX', int(ok))
        self.put('BX', self.get('BX') & 0xff00 | 0x80)

    def call(self, entry, **registers):
        depth = getattr(self, 'depth', 0)
        self.depth = depth + 1
        inputs = dict(CS=0x1000, DS=self.segment, ES=0x4000,
                      SS=0x8000, SP=0xf000 - depth * 0x1000,
                      AX=0x9a45, BX=0x3456, CX=0x4567, DX=0x5678,
                      SI=0x6789, DI=0x789a, BP=0x89ab, EFLAGS=0x602)
        inputs.update(registers)
        for name, value in inputs.items():
            self.put(name, value)
        self.uc.mem_write(inputs['SS'] * 16 + inputs['SP'], b'\0\xff')
        self.uc.emu_start(0x10000 + self.symbols[entry], 0x1ff00, count=5000000)
        assert self.get('IP') == 0xff00 and self.get('SP') == inputs['SP'] + 2
        outputs = {'S_DICT_OPEN': {'BP'}, 'S_DICT_COPY': {'SI', 'DI', 'CX'}}.get(entry, {'AX'})
        if entry in ('S_DICT_LODSB', 'S_DICT_LODSW'):
            outputs.add('SI')
        for name, value in inputs.items():
            if name not in outputs | {'SP'}:
                assert self.get(name) == value, name
        if entry in ('S_DICT_BYTE', 'S_DICT_LODSB'):
            assert self.get('AX') >> 8 == inputs['AX'] >> 8
        self.depth = depth
        return self.get('AX')

    def open(self, **registers):
        end = self.segment + self.capacity // 16 + 1
        self.call('S_DICT_OPEN', BP=end, DS=0x5000, **registers)
        return end


@pytest.mark.parametrize('base,extension', [(31865, b''), (31864, b'old,'), (4096, b'odd')])
def test_open_preserves_logical_header_and_compacts_extension(dictionary_binary, base, extension):
    machine = Dictionary(dictionary_binary, base, extension)
    end = machine.open()
    cache = (16 + machine.capacity - base + 3) & ~1
    assert machine.word('Q_HANDLE') == 8 and machine.word('Q_BASE') == base
    assert machine.word('Q_SEG') == machine.segment
    assert machine.word('Q_CACHE') == cache and machine.word('Q_PAGE') == 65535
    assert machine.get('BP') == machine.segment + (cache + 2048) // 16 + 1 < end
    assert bytes(machine.uc.mem_read(0x30000, 16)) == machine.original[:16]
    assert bytes(machine.uc.mem_read(0x30010, len(extension) + 2)) == extension + b'\0\0'
    assert bytes(machine.blocks[8][:base]) == machine.original[:base]
    assert machine.moves == [((base + 1) & ~1, 0, 0x30000000, 8, 0)]


@pytest.mark.parametrize('failure', ['allocate', 'move', 'local', 'no-table', 'old-header',
                                    'bad-base', 'bad-used', 'bad-capacity', 'too-small'])
def test_open_failure_keeps_original_dictionary_and_allocation(dictionary_binary, failure):
    machine = Dictionary(dictionary_binary, 1024 if failure == 'too-small' else 31865)
    machine.failure = failure
    if failure == 'local':
        machine.write('T_LOCAL', b'\1')
    elif failure == 'no-table':
        machine.write_word('T_HANDLE', 0)
    elif failure == 'old-header':
        machine.uc.mem_write(0x3000f, b'\0')
    elif failure == 'bad-base':
        machine.uc.mem_write(0x30004, struct.pack('<H', machine.used + 1))
    elif failure == 'bad-used':
        machine.uc.mem_write(0x30006, struct.pack('<H', machine.capacity + 1))
    elif failure == 'bad-capacity':
        machine.uc.mem_write(0x30008, b'\xff\xff')
    original = bytes(machine.uc.mem_read(0x30000, len(machine.original)))
    end = machine.open()
    assert machine.get('BP') == end
    assert machine.word('Q_HANDLE') == machine.word('Q_BASE') == machine.word('Q_CACHE') == 0
    assert machine.word('Q_SEG') == 0
    assert set(machine.blocks) == {7}
    assert bytes(machine.uc.mem_read(0x30000, len(original))) == original


@pytest.mark.parametrize('flags', [2, 0x202, 0x602])
@pytest.mark.parametrize('word', [False, True])
def test_reads_across_header_cache_and_mutable_boundaries(dictionary_binary, flags, word):
    machine = Dictionary(dictionary_binary)
    machine.open()
    for offset in (0, 1, 14, 15, 16, 17, 2046, 2047, 2048, 2049, 4095, 4096,
                   machine.base - 2, machine.base - 1, machine.base,
                   machine.used - 1, machine.used, machine.used + 1):
        result = machine.call('S_DICT_WORD' if word else 'S_DICT_BYTE', BX=offset, EFLAGS=flags)
        count = 2 if word else 1
        if offset + count > machine.used + 2:
            continue  # Unused extension capacity has no stored contents.
        assert result & (65535 if word else 255) == int.from_bytes(machine.original[offset:offset + count], 'little')
    # Header updates are live, even though XMS still has the installation copy.
    machine.uc.mem_write(0x30006, struct.pack('<H', machine.used + 1))
    assert machine.call('S_DICT_WORD', BX=6) == machine.used + 1
    assert machine.read('T_FAULT', 1) == b'\0'


@pytest.mark.parametrize('entry,step', [('S_DICT_LODSB', 1), ('S_DICT_LODSW', 2)])
@pytest.mark.parametrize('reverse', [False, True])
def test_loads_preserve_direction_and_registers(dictionary_binary, entry, step, reverse):
    machine = Dictionary(dictionary_binary)
    machine.open()
    for offset in (15, 2047, machine.base - 1, machine.base + 1):
        result = machine.call(entry, SI=offset, EFLAGS=0x602 if reverse else 0x202)
        assert result & (255 if step == 1 else 65535) == int.from_bytes(machine.original[offset:offset + step], 'little')
        assert machine.get('SI') == offset + (-step if reverse else step)


@pytest.mark.parametrize('reverse', [False, True])
@pytest.mark.parametrize('mode', ['mapped', 'foreign', 'conventional'])
def test_copy_preserves_rep_movsb_contract(dictionary_binary, reverse, mode):
    machine = Dictionary(dictionary_binary)
    if mode != 'conventional':
        machine.open()
    segment = 0x6000 if mode == 'foreign' else machine.segment
    if mode == 'foreign':
        machine.uc.mem_write(segment * 16, machine.original)
    start, count = machine.base - 17, 32
    for amount in (0, count):
        offset = start + (amount - 1 if reverse and amount else 0)
        dest = 200 + (amount - 1 if reverse and amount else 0)
        machine.uc.mem_write(0x400c7, b'\xa5' * 34)
        machine.call('S_DICT_COPY', DS=segment, SI=offset, DI=dest, CX=amount,
                     EFLAGS=0x602 if reverse else 0x202)
        distance = -amount if reverse else amount
        assert machine.get('SI') == offset + distance
        assert machine.get('DI') == dest + distance and machine.get('CX') == 0
        expected = machine.original[start:start + amount] + b'\xa5' * (32 - amount)
        assert bytes(machine.uc.mem_read(0x400c7, 34)) == b'\xa5' + expected + b'\xa5'


def test_nested_xms_fetch_uses_private_buffer_and_keeps_outer_cache(dictionary_binary):
    machine = Dictionary(dictionary_binary)
    machine.open()
    machine.nested = lambda nested: nested.call('S_DICT_WORD', BX=4095)
    assert machine.call('S_DICT_WORD', BX=2046) == int.from_bytes(machine.original[2046:2048], 'little')
    assert machine.word('Q_PAGE') == 0 and machine.read('Q_BUSY', 1) == b'\0'
    assert [move[0] for move in machine.moves[1:]] == [2048, 2, 2]
    count = len(machine.moves)
    assert machine.call('S_DICT_WORD', BX=2044) == int.from_bytes(machine.original[2044:2046], 'little')
    assert len(machine.moves) == count


def test_fault_and_mutable_terminator_do_not_corrupt_cache(dictionary_binary):
    machine = Dictionary(dictionary_binary)
    machine.open()
    assert machine.call('S_DICT_WORD', BX=4096) == int.from_bytes(machine.original[4096:4098], 'little')
    cache = machine.word('Q_CACHE')
    cached = bytes(machine.uc.mem_read(0x30000 + cache, 2048))
    physical_end = 16 + machine.capacity - machine.base
    machine.uc.mem_write(0x30000 + physical_end, b'\0\0')
    assert machine.call('S_DICT_WORD', BX=machine.capacity) == 0
    assert machine.call('S_DICT_BYTE', BX=machine.capacity + 1) & 255 == 0
    assert bytes(machine.uc.mem_read(0x30000 + cache, 2048)) == cached
    assert machine.call('S_DICT_WORD', BX=machine.capacity + 1) == 0
    assert machine.read('T_FAULT', 1) == b'\1'
    machine.write('T_FAULT', b'\0')
    machine.failure = 'move'
    assert machine.call('S_DICT_WORD', BX=8000) == 0
    assert machine.read('T_FAULT', 1) == b'\1'
    assert machine.read('Q_BUSY', 1) == b'\0' and machine.word('Q_PAGE') == 65535


@pytest.mark.parametrize('reverse', [False, True])
def test_failed_copy_does_not_retry_xms_for_each_byte(dictionary_binary, reverse):
    machine = Dictionary(dictionary_binary)
    machine.open()
    machine.failure = 'move'
    source, dest, count = 4096, 200, 31
    machine.call('S_DICT_COPY', SI=source, DI=dest, CX=count,
                 EFLAGS=0x602 if reverse else 0x202)
    direction = -1 if reverse else 1
    assert machine.get('SI') == source + direction * count
    assert machine.get('DI') == dest + direction * count
    assert machine.get('CX') == 0 and machine.read('T_FAULT', 1) == b'\1'
    start = dest - count + 1 if reverse else dest
    assert bytes(machine.uc.mem_read(0x40000 + start, count)) == bytes(count)
    assert len(machine.moves) == 2  # Initial copy and exactly one failed read.


def test_replacing_active_dictionary_does_not_transfer_cache_ownership(dictionary_binary):
    machine = Dictionary(dictionary_binary)
    machine.open()
    foreign = bytes(byte ^ 0x5a for byte in machine.original)
    machine.uc.mem_write(0x60000, foreign)
    machine.write_word('D_SPCZ', 0x6000)
    count = len(machine.moves)
    for offset in (15, 2047, machine.base - 1, machine.base + 1):
        assert machine.call('S_DICT_WORD', DS=0x6000, BX=offset) == int.from_bytes(foreign[offset:offset + 2], 'little')
    machine.call('S_DICT_COPY', DS=0x6000, SI=machine.base - 4, DI=100, CX=8, EFLAGS=0x202)
    assert bytes(machine.uc.mem_read(0x40064, 8)) == foreign[machine.base - 4:machine.base + 4]
    assert len(machine.moves) == count
    for offset in (4095, machine.base - 1, machine.base + 1):
        assert machine.call('S_DICT_WORD', BX=offset) == int.from_bytes(machine.original[offset:offset + 2], 'little')
    assert machine.word('Q_SEG') == 0x3000 and machine.word('D_SPCZ') == 0x6000

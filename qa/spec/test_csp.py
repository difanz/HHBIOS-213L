"""Run the production CSP editor through its DOS and CKBD interfaces."""
import struct
import subprocess
import re

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn import x86_const as reg

from qa.spec.build import build_mixed, source_file

pytestmark = pytest.mark.unit


@pytest.fixture(scope='module')
def csp_binary(assembler, source_dir, tmp_path_factory):
    output = tmp_path_factory.mktemp('csp') / 'CSP.COM'
    result = subprocess.run([assembler, '-q', '-0', '-bin', f'-Fo{output}',
                             str(source_file(source_dir, 'CSP.ASM'))],
                            capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    return output.read_bytes()


@pytest.fixture(scope='module', params=['8086', '386', '586'])
def csp_keyboard(request, assembler, source_dir, tmp_path_factory):
    names = ('INT_16', 'D_SPCZ', 'D_INKEY', 'D_PUMP', 'Q_HANDLE', 'Q_SEG',
             'Q_BASE', 'Q_CACHE', 'Q_PAGE', 'Q_SERIAL', 'T_XMS', 'T_FAULT')
    source = source_file(source_dir, 'CKBD.ASM').read_bytes()
    footer = b"DB 'HHCSPAPI'\r\nDW " + ','.join(names).encode() + b'\r\nSEG_TAIL ENDS'
    source, count = re.subn(rb'SEG_TAIL\s+ENDS', lambda _: footer, source)
    assert count == 1
    directory = tmp_path_factory.mktemp('csp-keyboard')
    path = directory / 'CKBD.ASM'
    path.write_bytes(source)
    raw = build_mixed(path, directory / 'CKBD.COM', source_dir, assembler, request.param)
    symbols = dict(zip(names, struct.unpack_from('<' + 'H' * len(names), raw,
                                                 raw.rindex(b'HHCSPAPI') + 8)))
    return raw, symbols


def encoded(text):
    return text.encode('gb2312')


def lead(text):
    return bytes(value & 0x7f for value in encoded(text))


def dictionary(two=None, three=None, multi=None, extension=None, reserve=128):
    if two is None:
        two = [('中', ['国', '华']), ('人', ['民'])]
    if three is None:
        three = ['中国人']
    if multi is None:
        multi = ['中华人民']
    if extension is None:
        extension = ['北京', '中国话', '中华人民共和国']
    data = bytearray(16)
    for initial, tails in two:
        data += lead(initial) + b''.join(encoded(tail) for tail in tails)
    end_two = len(data)
    for phrase in three:
        data += lead(phrase[0]) + encoded(phrase[1:])
    end_three = len(data)
    for phrase in multi:
        data += encoded(phrase) + b','
    basic_end = len(data)
    data += b''.join(encoded(phrase) + b',' for phrase in extension)
    end = len(data)
    capacity = end + reserve
    struct.pack_into('<5H', data, 0, end_two, end_three, basic_end, end, capacity)
    data[10:16] = b'\x11\x22\x33\x44\x55\xff'
    return data + bytes(capacity + 2 - len(data))


def extension_bytes(data):
    begin, end = struct.unpack_from('<2H', data, 4)
    return bytes(data[begin:end])


class Csp:
    """Only DOS services and the published dictionary API are substituted.

    Virtual mode exposes a poisoned compact resident block. Any old-style
    direct access to its dictionary bytes is a test failure.
    """
    def __init__(self, binary, mode='virtual', keys='\x1b', lines=(), data=None,
                 failure=None, learn_before_commit=False):
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, 0x100000)
        self.uc.mem_write(0x20100, binary)
        self.data = bytearray(dictionary() if data is None else data)
        self.original = bytes(self.data)
        self.mode = mode
        self.keys = list(keys)
        self.lines = list(lines)
        self.failure = failure
        self.learn_before_commit = learn_before_commit
        self.generation = 7
        self.snapshots = 0
        self.updates = []
        self.output = bytearray()
        self.file = None
        self.filename = None
        self.closed = False
        self.allocations = []
        self.resized = False
        self.exit_code = None
        self.uc.mem_write(0x80000, bytes(self.data) if mode != 'virtual' else b'\xa5' * 65536)
        self.uc.mem_write(0x90112, struct.pack('<H', 0x8000))
        self.uc.mem_write(0x90200, b'C:\\HHBIOS\0')
        self.uc.mem_write(0x20002, struct.pack('<H', 0x7000))
        for name, value in dict(CS=0x2000, DS=0x2000, ES=0x2000, SS=0x2000,
                                SP=0xfffe, EFLAGS=0x202).items():
            self.put(name, value)
        self.uc.hook_add(UC_HOOK_INTR, self.interrupt)
        if mode == 'virtual':
            def forbidden(*args):
                pytest.fail('CSP dereferenced the compact resident dictionary')
            self.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, forbidden,
                             begin=0x80000, end=0x8ffff)

    def get(self, name):
        return self.uc.reg_read(getattr(reg, 'UC_X86_REG_' + name))

    def put(self, name, value):
        self.uc.reg_write(getattr(reg, 'UC_X86_REG_' + name), value)

    def carry(self, value):
        self.put('EFLAGS', (self.get('EFLAGS') & ~1) | bool(value))

    def string(self, address, terminator=0):
        result = bytearray()
        for offset in range(512):
            value = self.uc.mem_read(address + offset, 1)[0]
            if value == terminator:
                return bytes(result)
            result.append(value)
        pytest.fail('Unterminated CSP string')

    def dictionary_api(self, function):
        assert self.get('BX') == 0x4b48
        if self.mode == 'legacy':
            return  # Unsupported BIOS leaves AX unchanged.
        if function == 0:
            if self.failure == 'query':
                self.put('AX', 0)
                return
            self.put('AX', 0x4b48)
            self.put('CX', len(self.data))
            self.put('DX', struct.unpack_from('<H', self.data, 4)[0])
            return
        assert function in (1, 2)
        assert self.get('DI') + len(self.data) <= 65536
        assert self.get('CX') >= len(self.data)
        address = self.get('ES') * 16 + self.get('DI')
        assert (address, 65536) in self.allocations
        if function == 1:
            self.snapshots += 1
            if self.failure == 'snapshot':
                self.put('AX', 0)
                return
            self.uc.mem_write(address, bytes(self.data))
            self.put('DX', self.generation)
        else:
            if self.learn_before_commit:
                self.generation += 1
                self.learn_before_commit = False
            if self.failure == 'update' or self.get('DX') != self.generation:
                self.put('AX', 0)
                return
            candidate = bytes(self.uc.mem_read(address, len(self.data)))
            basic = struct.unpack_from('<H', self.data, 4)[0]
            assert candidate[:6] == self.data[:6]
            assert candidate[8:basic] == self.data[8:basic]
            end, capacity = struct.unpack_from('<2H', candidate, 6)
            assert basic <= end <= capacity
            assert candidate[end:end + 2] == b'\0\0'
            self.data[:] = candidate
            self.updates.append(extension_bytes(candidate))
            self.generation += 1
            self.put('DX', self.generation)
        self.put('AX', 0x4b48)

    def interrupt(self, uc, number, _):
        ax = self.get('AX')
        function = ax >> 8
        if number == 0x16:
            if function == 0x2f:
                self.put('BP', 0x9000)
                self.put('DX', 0x200)
                self.put('DI', 0x100)
            elif function == 0x2e:
                self.dictionary_api(ax & 255)
            else:
                assert function == 0 and self.keys, f'Unexpected keyboard request {ax:04x}'
                self.put('AX', ord(self.keys.pop(0)))
            return
        if number == 0x10:
            assert ax == 0x0e07
            return
        assert number == 0x21, f'Unexpected interrupt {number:02x}'
        address = self.get('DS') * 16 + self.get('DX')
        self.carry(False)
        if function == 9:
            self.output += self.string(address, ord('$'))
        elif function == 2:
            self.output.append(self.get('DX') & 255)
        elif function == 0x0a:
            assert self.lines, 'Unexpected line input'
            line = self.lines.pop(0)
            line = encoded(line) if isinstance(line, str) else line
            assert len(line) <= self.uc.mem_read(address, 1)[0]
            self.uc.mem_write(address + 1, bytes([len(line)]) + line + b'\r')
        elif function == 0x4a:
            assert self.get('ES') == 0x2000 and self.get('BX') == 0x1000
            self.resized = True
            self.carry(self.failure == 'resize')
        elif function == 0x48:
            assert self.resized and self.get('BX') == 0x1000
            if self.failure == 'allocate' or (self.failure == 'merge_allocate' and self.allocations):
                self.carry(True)
            else:
                segment = [0x3000, 0x5000][len(self.allocations)]
                self.allocations.append((segment * 16, 65536))
                self.put('AX', segment)
        elif function == 0x3c:
            self.filename = self.string(address)
            self.file = bytearray()
            self.put('AX', 5)
            self.carry(self.failure == 'create')
        elif function == 0x40:
            assert self.get('BX') == 5
            count = self.get('CX')
            self.file += self.uc.mem_read(address, count)
            self.put('AX', count)
            self.carry(self.failure == 'write')
        elif function == 0x3e:
            assert self.get('BX') == 5
            self.closed = True
        elif function == 0x4c:
            self.exit_code = ax & 255
            self.uc.emu_stop()
        else:
            pytest.fail(f'Unexpected DOS function {ax:04x}')

    def run(self):
        self.uc.emu_start(0x20100, 0x100000, count=2000000)
        assert self.exit_code is not None, 'CSP did not return to DOS'
        if self.mode == 'legacy':
            self.data[:] = self.uc.mem_read(0x80000, len(self.data))
        return self


class ResidentCsp(Csp):
    """CSP and CKBD execute together; only DOS, keyboard input and XMS are external."""
    def __init__(self, binary, keyboard, xms, **kwargs):
        super().__init__(binary, mode='local', **kwargs)
        raw, self.symbols = keyboard
        self.uc.mem_write(0x10100, raw)
        self.uc.mem_write(0x10082, b'C:\\HHBIOS\0')
        self.xms = xms
        basic = struct.unpack_from('<H', self.data, 4)[0]
        self.xms_data = bytes(self.data[:(basic + 1) & ~1])
        self.moves = []
        self.api_calls = []
        self.resident_word('D_SPCZ', 0x8000)
        self.resident_word('Q_HANDLE', 7 if xms else 0)
        self.resident_word('Q_SERIAL', self.generation)
        if xms:
            self.resident_word('Q_SEG', 0x8000)
            self.resident_word('Q_BASE', basic)
            self.resident_word('Q_CACHE', 0x200)
            self.resident_word('Q_PAGE', 0xffff)
            self.uc.mem_write(0x80000, bytes(self.data[:16] + self.data[basic:]))
        self.uc.mem_write(0x10000 + self.symbols['T_XMS'], struct.pack('<HH', 0, 0xf000))
        self.uc.mem_write(0xf0000, b'\xcd\x65\xcb')

        def no_pointer_access(uc, *args):
            assert self.get('CS') != 0x2000, 'CSP bypassed the resident snapshot API'
        self.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, no_pointer_access,
                         begin=0x80000, end=0x8ffff)

    def resident_word(self, name, value=None):
        address = 0x10000 + self.symbols[name]
        if value is not None:
            self.uc.mem_write(address, struct.pack('<H', value))
        return struct.unpack('<H', self.uc.mem_read(address, 2))[0]

    def interrupt(self, uc, number, user):
        if number == 0x16 and self.get('AX') >> 8 in (0x2e, 0x2f):
            if self.get('AX') >> 8 == 0x2e:
                self.api_calls.append(self.get('AX') & 255)
                if self.get('AX') & 255 == 2 and self.learn_before_commit:
                    self.resident_word('Q_SERIAL', self.generation + 1)
                    self.learn_before_commit = False
            stack = self.get('SP') - 6
            self.uc.mem_write(self.get('SS') * 16 + stack,
                              struct.pack('<3H', self.get('IP'), self.get('CS'), self.get('EFLAGS')))
            self.put('SP', stack)
            self.put('CS', 0x1000)
            self.put('IP', self.symbols['INT_16'])
            self.put('EFLAGS', self.get('EFLAGS') & ~0x300)
            return
        if number == 0x65:
            assert self.get('AX') >> 8 == 11
            address = self.get('DS') * 16 + self.get('SI')
            count, source, offset, target, destination = struct.unpack('<IHIHI', self.uc.mem_read(address, 16))
            assert source == 7 and target == 0 and count % 2 == 0
            assert offset + count <= len(self.xms_data)
            self.moves.append((offset, count))
            if self.failure == 'xms':
                self.put('AX', 0)
            else:
                address = (destination >> 16) * 16 + (destination & 65535)
                self.uc.mem_write(address, self.xms_data[offset:offset + count])
                self.put('AX', 1)
            return
        super().interrupt(uc, number, user)

    def run(self):
        super().run()
        header = bytes(self.uc.mem_read(0x80000, 16))
        basic, end = struct.unpack_from('<2H', header, 4)
        self.data[:16] = header
        start = 16 if self.xms else basic
        self.data[basic:end + 2] = self.uc.mem_read(0x80000 + start, end - basic + 2)
        assert self.uc.mem_read(0x10000 + self.symbols['D_INKEY'], 1) == b'\0'
        assert self.uc.mem_read(0x10000 + self.symbols['D_PUMP'], 1) == b'\0'
        return self


@pytest.mark.parametrize('mode', ['legacy', 'local', 'virtual'])
def test_csp_escape_does_not_write_disk(csp_binary, mode):
    machine = Csp(csp_binary, mode).run()
    assert machine.exit_code == 1 and machine.file is None
    assert bytes(machine.data) == machine.original
    assert machine.snapshots == (mode != 'legacy')


@pytest.mark.parametrize('mode', ['legacy', 'local', 'virtual'])
def test_csp_add_is_live_even_when_exiting_without_save(csp_binary, mode):
    machine = Csp(csp_binary, mode, keys='1\x1b', lines=['中美', '']).run()
    assert machine.exit_code == 1 and machine.file is None
    expected = extension_bytes(machine.original) + encoded('中美') + b','
    assert extension_bytes(machine.data) == expected
    assert machine.updates == ([] if mode == 'legacy' else [expected])


@pytest.mark.parametrize('mode', ['legacy', 'local', 'virtual'])
def test_csp_delete_last_entry_publishes_the_new_end(csp_binary, mode):
    machine = Csp(csp_binary, mode, keys='2\x1b', lines=['3']).run()
    assert machine.exit_code == 1 and machine.file is None
    expected = encoded('北京,中国话,')
    assert extension_bytes(machine.data) == expected
    assert machine.updates == ([] if mode == 'legacy' else [expected])


@pytest.mark.parametrize('mode', ['legacy', 'local', 'virtual'])
def test_csp_add_then_delete_last_entry(csp_binary, mode):
    machine = Csp(csp_binary, mode, keys='12\x1b', lines=['中美', '', '4']).run()
    assert machine.exit_code == 1 and machine.file is None
    assert extension_bytes(machine.data) == extension_bytes(machine.original)


@pytest.mark.parametrize('mode', ['legacy', 'local', 'virtual'])
def test_csp_save_merges_all_phrase_formats(csp_binary, mode):
    machine = Csp(csp_binary, mode, keys='10', lines=['中美', '']).run()
    expected = dictionary(two=[('中', ['美', '国', '华']), ('人', ['民']), ('北', ['京'])],
                          three=['中国话', '中国人'],
                          multi=['中华人民共和国', '中华人民'], extension=[], reserve=0)[:-2]
    struct.pack_into('<H', expected, 8, 0)
    assert machine.exit_code == 0 and machine.closed
    assert machine.filename == b'C:\\HHBIOS\\SPCZ.DAT'
    assert machine.file == expected
    assert extension_bytes(machine.data) == extension_bytes(machine.original) + encoded('中美,')
    assert len(machine.allocations) == (1 if mode == 'legacy' else 2)


@pytest.mark.parametrize('failure', ['query', 'resize', 'allocate', 'snapshot', 'update',
                                    'merge_allocate', 'create', 'write'])
def test_csp_failure_reports_error_without_losing_resident_edits(csp_binary, failure):
    machine = Csp(csp_binary, keys='10', lines=['中美', ''], failure=failure).run()
    assert machine.exit_code == 1
    if failure in ('query', 'resize', 'allocate', 'snapshot', 'update'):
        assert bytes(machine.data) == machine.original and machine.file is None
    else:
        assert extension_bytes(machine.data) == extension_bytes(machine.original) + encoded('中美,')
    assert machine.output


def test_csp_stale_snapshot_cannot_overwrite_newly_learned_phrases(csp_binary):
    machine = Csp(csp_binary, keys='1', lines=['中美'], learn_before_commit=True).run()
    assert machine.exit_code == 1 and machine.file is None
    assert bytes(machine.data) == machine.original
    assert machine.updates == []
    assert b'Cannot update' in machine.output


@pytest.mark.parametrize('xms', [False, True])
def test_csp_edits_and_saves_through_the_resident_keyboard(csp_binary, csp_keyboard, xms):
    machine = ResidentCsp(csp_binary, csp_keyboard, xms,
                          keys='120', lines=['中美', '', '4']).run()
    expected = dictionary(two=[('中', ['国', '华']), ('人', ['民']), ('北', ['京'])],
                          three=['中国话', '中国人'],
                          multi=['中华人民共和国', '中华人民'], extension=[], reserve=0)[:-2]
    struct.pack_into('<H', expected, 8, 0)
    assert machine.exit_code == 0 and machine.closed
    assert machine.file == expected
    assert extension_bytes(machine.data) == extension_bytes(machine.original)
    assert machine.resident_word('Q_SERIAL') == machine.generation + 2
    assert machine.api_calls == [0, 1, 2, 2]
    assert bool(machine.moves) == xms


@pytest.mark.parametrize('xms', [False, True])
def test_csp_actual_keyboard_rejects_stale_edits(csp_binary, csp_keyboard, xms):
    machine = ResidentCsp(csp_binary, csp_keyboard, xms, keys='1', lines=['中美'],
                          learn_before_commit=True).run()
    assert machine.exit_code == 1 and machine.file is None
    assert extension_bytes(machine.data) == extension_bytes(machine.original)
    assert b'Cannot update' in machine.output


def test_csp_actual_xms_failure_does_not_enter_editor(csp_binary, csp_keyboard):
    machine = ResidentCsp(csp_binary, csp_keyboard, True, keys='', failure='xms').run()
    assert machine.exit_code == 1 and machine.file is None
    assert machine.api_calls == [0, 1]
    assert extension_bytes(machine.data) == extension_bytes(machine.original)
    assert b'Cannot update' in machine.output


@pytest.mark.parametrize('xms', [False, True])
def test_csp_mixed_content_phrase_keeps_its_odd_byte_length(csp_binary, csp_keyboard, xms):
    phrase = '中华人民共和国A中国'
    assert len(encoded(phrase)) % 2 == 1
    machine = ResidentCsp(csp_binary, csp_keyboard, xms,
                          keys='10', lines=[phrase, '']).run()
    expected = dictionary(two=[('中', ['国', '华']), ('人', ['民']), ('北', ['京'])],
                          three=['中国话', '中国人'],
                          multi=[phrase, '中华人民共和国', '中华人民'],
                          extension=[], reserve=0)[:-2]
    struct.pack_into('<H', expected, 8, 0)
    assert machine.exit_code == 0 and machine.closed
    assert machine.file == expected
    assert extension_bytes(machine.data) == extension_bytes(machine.original) + encoded(phrase + ',')

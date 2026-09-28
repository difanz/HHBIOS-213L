"""Execute legacy display entries with BIOS boundaries supplied by the test.

The exported address table changes no production instructions. Tests exercise
transaction nesting, interrupt windows, and mode ownership; guest tests cover
the actual adapter and keyboard together.
"""
import os
import struct
import subprocess

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE, UC_HOOK_INTR
from unicorn import x86_const as reg

from qa.spec.build import asm_includes, build_mixed

pytestmark = pytest.mark.unit


@pytest.fixture(scope='module', params=['VGA', 'EGA', 'HGA', 'CGA', 'CGA11', 'CGA16'])
def legacy_video(request, assembler, source_dir, tmp_path_factory):
    name = request.param
    directory = tmp_path_factory.mktemp('video-irq-' + name)
    source = (source_dir / 'video' / (name + '.ASM')).read_bytes()
    symbols = ['INT_10', 'D_INT10', 'D_INT16', 'IN_INT10', 'S_VIDEO_RETURN']
    if name in ('VGA', 'EGA', 'HGA'):
        symbols += ['INT_8', 'D_INT8', 'D_8', 'K_INT8', 'D_B800', 'D_XPQ',
                    'S_SETB8', 'S_XR', 'K_HZ1', 'D_LASTHZ', 'D_ZBFS',
                    'D_LASTMODE', 'L_0830']
    if name in ('VGA', 'EGA'):
        symbols += ['D_VBEBUSY']
    if name in ('CGA11', 'CGA16'):
        symbols += ['D_49', 'D_4A', 'D_ZFQ', 'D_SXQ', 'D_BZQ', 'S_XSGB']
    marker = b'VIDEO-IRQ-SYMBOLS'
    table = b'DB "' + marker + b'"\r\n'
    table += ('DW ' + ','.join('OFFSET ' + symbol for symbol in symbols) + '\r\n').encode()
    source = source.replace(b'SEG_A ENDS', table + b'SEG_A ENDS')
    if marker not in source:
        source = source.replace(b'SEG_A\t\tENDS', table + b'SEG_A\t\tENDS')
    assert marker in source
    assembly = directory / (name + '.ASM')
    assembly.write_bytes(source)
    output = directory / (name + '.COM')
    if name in ('VGA', 'EGA', 'HGA'):
        binary = build_mixed(assembly, output, source_dir, assembler)
    else:
        result = subprocess.run([assembler, '-q', '-0', '-Zm', '-bin',
                                 *asm_includes(source_dir), '-Fo' + str(output), str(assembly)],
                                env={k: v for k, v in os.environ.items() if k != 'JWASM'},
                                capture_output=True)
        assert result.returncode == 0, result.stdout + result.stderr
        binary = output.read_bytes()
    offset = binary.index(marker) + len(marker)
    addresses = struct.unpack_from('<' + 'H' * len(symbols), binary, offset)
    return name, binary, dict(zip(symbols, addresses))


class LegacyVideo:
    def __init__(self, fixture):
        self.name, binary, self.symbols = fixture
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, 0x100000)
        self.uc.mem_write(0x10100, binary)
        self.uc.mem_write(0x1f000, b'\xcd\xf1\xcf')
        self.write('D_INT10', struct.pack('<HH', 0xf000, 0x1000))
        self.write('D_INT16', struct.pack('<H', 0x2000))
        self.uc.mem_write(0x20103, b'\xef\xcd')
        self.uc.mem_write(0x10100, b'\1')
        self.bios_calls = []
        self.callbacks = []
        self.capability_queries = 0
        self.keyboard_supports_callback = True
        self.bios = lambda: None
        self.on_callback = lambda: None
        self.uc.hook_add(UC_HOOK_INTR, self.interrupt)

    def get(self, name):
        return self.uc.reg_read(getattr(reg, 'UC_X86_REG_' + name))

    def put(self, name, value):
        self.uc.reg_write(getattr(reg, 'UC_X86_REG_' + name), value)

    def address(self, name):
        return 0x10000 + self.symbols[name]

    def write(self, name, value):
        self.uc.mem_write(self.address(name), value)

    def read(self, name, size=1):
        return bytes(self.uc.mem_read(self.address(name), size))

    def interrupt(self, uc, number, _):
        if number == 0xf1:
            self.bios_calls.append(self.get('AX'))
            self.bios()
        else:
            assert number == 0x16
            if self.get('AX') == 0x2d01:
                assert self.get('BX') == 0x4b48
                self.capability_queries += 1
                if self.keyboard_supports_callback:
                    self.put('AX', 0x4b48)
                else:
                    for name in ('CX', 'DX', 'SI', 'DI', 'BP', 'ES'):
                        self.put(name, 0xbeef)
                return
            assert (self.get('AX'), self.get('BX')) == (0x2d00, 0x4b48)
            self.callbacks.append(self.read('IN_INT10')[0])
            self.on_callback()

    def enter(self, entry='INT_10', expect_return=True, **registers):
        self.uc.mem_write(0x8ff00, struct.pack('<3H', 0xff00, 0x1000, 0x602))
        defaults = dict(CS=0x1000, DS=0x3000, ES=0x4000, SS=0x8000, SP=0xff00,
                        AX=0xff00, BX=0x1234, CX=0x5678, DX=0x9abc,
                        SI=0x1357, DI=0x2468, BP=0xace0, EFLAGS=0x202)
        defaults.update(registers)
        for name, value in defaults.items():
            self.put(name, value)
        self.uc.emu_start(self.address(entry), 0x1ff00, count=200000)
        if expect_return:
            assert (self.get('CS'), self.get('IP')) == (0x1000, 0xff00)


@pytest.mark.parametrize('depth', [0, 1, 2, 7])
def test_busy_query_preserves_transaction_and_never_calls_keyboard(legacy_video, depth):
    machine = LegacyVideo(legacy_video)
    machine.write('IN_INT10', bytes([depth]))
    machine.enter(AX=0x1416, BX=0)
    assert (machine.get('AX'), machine.get('BX')) == (bool(depth), 0x4b48)
    assert machine.read('IN_INT10') == bytes([depth])
    assert machine.callbacks == machine.bios_calls == []
    assert machine.get('DX') == 0x9abc
    assert machine.get('EFLAGS') & 0x600 == 0x600


@pytest.mark.parametrize('depth', [0, 1, 2])
def test_nested_bios_call_releases_only_its_own_transaction(legacy_video, depth):
    machine = LegacyVideo(legacy_video)
    machine.write('IN_INT10', bytes([depth]))
    observed = []
    def bios():
        observed.append(machine.read('IN_INT10')[0])
        assert machine.get('EFLAGS') & 0x400 == 0
        machine.put('AX', 0xbeef)
        machine.put('BX', 0x9876)
        machine.put('BP', 0xabc1)
        stack = machine.get('SS') * 16 + machine.get('SP')
        flags = struct.unpack('<H', machine.uc.mem_read(stack + 4, 2))[0]
        machine.uc.mem_write(stack + 4, struct.pack('<H', flags | 1))
    machine.bios = bios
    machine.enter(AX=0x4f03)
    assert observed == [depth + 1]
    assert machine.read('IN_INT10') == bytes([depth])
    assert machine.callbacks == ([] if depth else [0])
    assert (machine.get('AX'), machine.get('BX')) == (0xbeef, 0x9876)
    assert machine.get('EFLAGS') & 0x601 == 0x601
    assert machine.get('BP') == 0xabc1


def test_callback_requires_installed_keyboard(legacy_video):
    machine = LegacyVideo(legacy_video)
    machine.uc.mem_write(0x20103, b'\0\0')
    machine.enter()
    assert machine.callbacks == []
    assert machine.read('IN_INT10') == b'\0'


def test_old_keyboard_is_negotiated_once_and_never_called_back(legacy_video):
    machine = LegacyVideo(legacy_video)
    machine.keyboard_supports_callback = False
    machine.enter()
    machine.enter()
    assert machine.capability_queries == 1
    assert machine.callbacks == []
    assert machine.get('CX') == 0x5678
    assert machine.get('ES') == 0x4000
    assert machine.get('BP') == 0xace0


def test_new_keyboard_capability_is_cached(legacy_video):
    machine = LegacyVideo(legacy_video)
    machine.enter()
    machine.enter()
    assert machine.capability_queries == 1
    assert machine.callbacks == [0, 0]


def test_release_cannot_be_interrupted_before_keyboard_lifetime_guard(legacy_video):
    machine = LegacyVideo(legacy_video)
    releasing = False
    observed = []
    def observe(uc, address, size, _):
        nonlocal releasing
        if address == machine.address('S_VIDEO_RETURN'):
            releasing = True
        if releasing and machine.read('IN_INT10') == b'\0':
            observed.append(address)
            assert machine.get('EFLAGS') & 0x200 == 0
    machine.uc.hook_add(UC_HOOK_CODE, observe)
    machine.enter()
    assert observed
    assert machine.callbacks == [0]
    assert machine.get('EFLAGS') & 0x200


@pytest.mark.parametrize('depth', [1, 2])
def test_timer_cannot_touch_glyph_scratch_during_int10(legacy_video, depth):
    if legacy_video[0] not in ('VGA', 'EGA', 'HGA'):
        pytest.skip('This CGA driver does not install a refresh timer.')
    machine = LegacyVideo(legacy_video)
    machine.write('D_INT8', struct.pack('<HH', 0xf000, 0x1000))
    machine.write('D_8', b'\1')
    machine.write('K_INT8', b'\x75')
    machine.write('D_B800', struct.pack('<H', 0xb800))
    machine.uc.mem_write(0xb8000, b'A\x07' * 2000)
    machine.write('D_XPQ', b' \x07' * 2000)
    machine.write('IN_INT10', bytes([depth]))
    scratch = bytes(range(64))
    machine.uc.mem_write(0x10060, scratch)
    drawing = []
    for symbol in ('S_SETB8', 'S_XR'):
        address = machine.address(symbol)
        machine.uc.hook_add(UC_HOOK_CODE, lambda u, a, s, _: drawing.append(a),
                            begin=address, end=address)
    machine.enter('INT_8')
    assert drawing == []
    assert machine.read('D_8') == b'\1'
    assert machine.read('IN_INT10') == bytes([depth])
    assert bytes(machine.uc.mem_read(0x10060, 64)) == scratch
    assert machine.callbacks == []


def test_timer_claim_has_no_interruptible_gap(legacy_video):
    if legacy_video[0] not in ('VGA', 'EGA', 'HGA'):
        pytest.skip('This CGA driver does not install a refresh timer.')
    machine = LegacyVideo(legacy_video)
    machine.write('D_INT8', struct.pack('<HH', 0xf000, 0x1000))
    machine.write('D_8', b'\1')
    machine.write('K_INT8', b'\x75')
    checked = []
    after_bios = False
    def bios():
        nonlocal after_bios
        after_bios = True
    machine.bios = bios
    def observe(uc, address, size, _):
        if not after_bios or address >= 0x1f000:
            return
        if machine.get('EFLAGS') & 0x200:
            assert machine.read('IN_INT10') == b'\1'
        if address == machine.address('S_SETB8'):
            checked.append(address)
            assert machine.get('EFLAGS') & 0x200
            uc.emu_stop()
    machine.uc.hook_add(UC_HOOK_CODE, observe)
    # Stop at the first adapter register routine, after the transaction claim.
    machine.enter('INT_8', expect_return=False, EFLAGS=2)
    assert checked == [machine.address('S_SETB8')]


@pytest.mark.parametrize('result', [0x004f, 0x014f])
def test_vbe_mode_ownership_and_failure_rollback(legacy_video, result):
    if legacy_video[0] not in ('VGA', 'EGA'):
        pytest.skip('VBE handoff is required for the EGA/VGA color drivers.')
    machine = LegacyVideo(legacy_video)
    machine.write('K_INT8', b'\x75')
    machine.uc.mem_write(0x20101, b'\x12')
    def bios():
        assert machine.read('IN_INT10') == b'\1'
        assert machine.read('K_INT8') == b'\xeb'
        assert machine.read('D_VBEBUSY') == b'\1'
        machine.put('AX', result)
    machine.bios = bios
    machine.enter(AX=0x4f02, BX=0x101)
    assert machine.get('AX') == result
    assert machine.read('IN_INT10') == machine.read('D_VBEBUSY') == b'\0'
    assert machine.callbacks == [0]
    assert machine.read('K_INT8') == (b'\xeb' if result == 0x004f else b'\x75')
    assert bytes(machine.uc.mem_read(0x10100, 1)) == (b'\0' if result == 0x004f else b'\1')
    assert bytes(machine.uc.mem_read(0x20101, 1)) == (b'\xff' if result == 0x004f else b'\x12')


@pytest.mark.parametrize('mode', [4, 5, 6, 0x12, 0x84, 0x85, 0x86, 0x92])
def test_cga_mode_fallback_geometry_and_preserved_text(legacy_video, mode):
    if legacy_video[0] not in ('CGA11', 'CGA16'):
        pytest.skip('The compact CGA renderers provide this mode fallback.')
    machine = LegacyVideo(legacy_video)
    old_text = b'Z' * 2000
    for symbol in ('D_ZFQ', 'D_SXQ', 'D_BZQ'):
        machine.write(symbol, old_text)
    # Adapter cursor drawing is independently exercised in the DOS guest.
    def skip_cursor(uc, address, size, _):
        stack = machine.get('SS') * 16 + machine.get('SP')
        target = struct.unpack('<H', uc.mem_read(stack, 2))[0]
        machine.put('SP', machine.get('SP') + 2)
        machine.put('IP', target)
    entry = machine.address('S_XSGB')
    machine.uc.hook_add(UC_HOOK_CODE, skip_cursor, begin=entry, end=entry)
    machine.enter(AX=mode)
    actual = min(mode & 0x7f, 6)
    assert machine.bios_calls == [actual | (mode & 0x80), 0x0b00 | actual | (mode & 0x80)]
    assert machine.read('D_49') == bytes([actual])
    assert machine.read('D_4A') == bytes([80 if actual == 6 else 40])
    assert bytes(machine.uc.mem_read(0x20100, 2)) == bytes([actual, actual])
    assert machine.read('IN_INT10') == b'\0'
    for symbol in ('D_ZFQ', 'D_SXQ', 'D_BZQ'):
        expected = old_text if mode & 0x80 else bytes([3 if symbol == 'D_SXQ' else 0]) * 2000
        assert machine.read(symbol, 2000) == expected


@pytest.mark.parametrize('mode', [4, 5, 6])
def test_cga_glyph_output_balances_stack_and_preserves_registers(legacy_video, mode):
    if legacy_video[0] not in ('CGA11', 'CGA16'):
        pytest.skip('The compact CGA renderers have their own glyph routines.')
    machine = LegacyVideo(legacy_video)
    machine.enter(AX=mode)
    machine.enter(AX=0x0200, BX=0, DX=3)
    machine.enter(AX=0x0951, BX=7, CX=3)
    assert machine.get('SP') == 0xff06
    assert machine.get('AX') == 0x0951
    assert machine.get('CX') == 3
    assert machine.get('DS') == 0x3000
    assert machine.read('IN_INT10') == b'\0'
    machine.enter(AX=0x0800, BX=0)
    assert machine.get('AX') & 0xff == ord('Q')


def test_hercules_activation_publishes_keyboard_chinese_mode(legacy_video):
    if legacy_video[0] != 'HGA':
        pytest.skip('Hercules uses its own graphics mode and initialization.')
    machine = LegacyVideo(legacy_video)
    machine.uc.mem_write(0x20100, b'\x12\x03')
    machine.enter(AX=3)
    assert bytes(machine.uc.mem_read(0x20100, 2)) == b'\x09\x09'
    assert machine.read('IN_INT10') == b'\0'

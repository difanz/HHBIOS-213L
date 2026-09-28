"""Run CKBD's actual confirmation, installation and DOS idle handlers."""
import re
import struct

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR, UC_HOOK_CODE
from unicorn import x86_const as reg

from qa.spec.build import build_mixed, source_file

pytestmark = pytest.mark.unit
BASE = 0x10000
RETURN = 0xff00


@pytest.fixture(scope='session', params=['8086', '386', '586'])
def menu_binary(assembler, source_dir, tmp_path_factory, request):
    directory = tmp_path_factory.mktemp('keymenu')
    source = source_file(source_dir, 'CKBD.ASM').read_bytes()
    names = ('INT_28', 'D_EXIT', 'D_INT28', 'D_INDOS', 'D_CRITERR',
             'D_INKEY', 'D_INT16', 'L_XTK1D', 'S_QTXS', 'S_CXTUX', 'S_SETINT',
             'INT_9', 'D_INT9', 'K_SHIFT', 'K_DEL', 'INT_16', 'D_DEFER',
             'D_PUMP', 'D_IRQ', 'S_FOREGROUND_EXIT', 'S_JRCL', 'D_95D5',
             'D_KEYCONSUMED', 'D_2BAA', 'D_KBDBUF')
    # Export addresses for observation, without replacing production code.
    source = source.replace(b'SEG_A ENDS',
                            ('PUBLIC ' + ','.join(names) + '\r\nSEG_A ENDS').encode())
    assembly = directory / 'CKBD.ASM'
    assembly.write_bytes(source)
    output = directory / 'CKBD.COM'
    binary = build_mixed(assembly, output, source_dir, assembler, request.param)
    symbols = {name: int(segment, 16)*16 + int(offset, 16)
               for segment, offset, name in re.findall(
                   r'^([0-9a-f]{4}):([0-9a-f]{4})[ +*]*\s+(\w+)$',
                   output.with_suffix('.map').read_text(), re.M)}
    assert set(names) <= symbols.keys()
    return binary, symbols


class KeyboardModule:
    def __init__(self, module):
        binary, self.symbols = module
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, 0x100000)
        self.uc.mem_write(BASE+0x100, binary)
        self.initial = dict(AX=0x1234, BX=0x2345, CX=0x3456, DX=0x4567,
                            SI=0x5678, DI=0x6789, BP=0x789a, DS=0x3000,
                            ES=0x4000, SS=0x7000, SP=0xff00, CS=BASE//16,
                            EFLAGS=0x603)
        for name, value in self.initial.items():
            self.set(name, value)
        self.console = b''.join(bytes((32 + cell % 90, 7)) for cell in range(2000))
        self.uc.mem_write(0xb8000, self.console)
        self.uc.mem_write(0x50000, b'\0' * 4000)
        self.uc.mem_write(0x449, b'\3\x50\0')
        self.uc.mem_write(0x450, struct.pack('<H', 0x040d))
        self.uc.mem_write(0x460, struct.pack('<H', 0x0d0e))
        self.uc.mem_write(0x484, b'\x18\x10\0')

    def video(self):
        function = self.get('AX')
        if function == 0x1416:
            assert self.get('BX') == 0
            self.set('AX', 0)
            self.set('BX', 0x4b48)
        elif function == 0x140c:
            self.set('AX', 0)
            self.set('BX', 0x5000)
        elif function == 0x1406:
            self.set('DX', 0x80)  # Direct B800 text is authoritative.
        elif function >> 8 == 3:
            self.set('CX', int.from_bytes(self.uc.mem_read(0x460, 2), 'little'))
            self.set('DX', int.from_bytes(self.uc.mem_read(0x450, 2), 'little'))
        elif function >> 8 == 2:
            assert self.get('BX') >> 8 == 0
            self.uc.mem_write(0x450, struct.pack('<H', self.get('DX')))
        else:
            assert function >> 8 == 1, hex(function)
            self.uc.mem_write(0x460, struct.pack('<H', self.get('CX')))

    def mode_reset(self):
        # Model the reader's final hardware mode set, after virtual B800 is
        # no longer mapped. The driver's freed RAM shadow remains intact.
        self.uc.mem_write(0xb8000, b'\0' * 4000)
        self.uc.mem_write(0x450, b'\0\0')
        self.uc.mem_write(0x460, b'\0\0')

    def check_console(self):
        assert self.uc.mem_read(0xb8000, 4000) == self.console
        assert self.uc.mem_read(0x450, 2) == struct.pack('<H', 0x040d)
        assert self.uc.mem_read(0x460, 2) == struct.pack('<H', 0x0d0e)

    def get(self, name):
        return self.uc.reg_read(getattr(reg, 'UC_X86_REG_'+name))

    def set(self, name, value):
        self.uc.reg_write(getattr(reg, 'UC_X86_REG_'+name), value)

    def write(self, name, value):
        self.uc.mem_write(BASE+self.symbols[name], value)

    def byte(self, name):
        return self.uc.mem_read(BASE+self.symbols[name], 1)[0]

    def call(self, entry, interrupt=False):
        frame = struct.pack('<HHH', RETURN, BASE//16, self.get('EFLAGS')) if interrupt else struct.pack('<H', RETURN)
        self.uc.mem_write(self.get('SS')*16+self.get('SP'), frame)
        self.uc.emu_start(BASE+self.symbols[entry], BASE+RETURN, count=100000)
        assert self.get('IP') == RETURN, 'handler did not return'
        assert self.get('SS') == self.initial['SS']
        assert self.get('SP') == self.initial['SP'] + len(frame)


@pytest.mark.parametrize('toggle', [1, 2, 0x10])
def test_modal_input_does_not_toggle_the_keyboard(menu_binary, toggle):
    machine = KeyboardModule(menu_binary)
    machine.write('D_INKEY', b'\1')
    machine.write('K_SHIFT', bytes([toggle]))
    machine.write('D_INT9', struct.pack('<HH', 0xf000, BASE//16))
    machine.uc.mem_write(BASE+0xf000, b'\xcf')
    machine.uc.mem_write(0x417, bytes([toggle, 0]) if toggle < 0x10 else b'\0\x10')

    def display(uc, number, _):
        assert number == 0x10

    machine.uc.hook_add(UC_HOOK_INTR, display)
    machine.call('INT_9', interrupt=True)
    assert machine.byte('K_DEL') == 0, 'a confirmation key disabled the keyboard'
    assert machine.byte('D_INKEY') == 1
    # N/Y can finish the menu before its key-up arrives, with Shift still held.
    machine.write('D_INKEY', b'\0')
    machine.uc.mem_write(0x41a, b'\x1e\0\x1e\0')
    machine.set('SP', machine.initial['SP'])
    machine.call('INT_9', interrupt=True)
    assert machine.byte('K_DEL') == 0, 'the confirmation key-up toggled the keyboard'
    # A subsequent fresh modifier press outside the menu must still work.
    machine.uc.mem_write(0x417, b'\0\0')
    machine.set('SP', machine.initial['SP'])
    machine.call('INT_9', interrupt=True)
    machine.uc.mem_write(0x417, bytes([toggle, 0]) if toggle < 0x10 else b'\0\x10')
    machine.set('SP', machine.initial['SP'])
    machine.call('INT_9', interrupt=True)
    assert machine.byte('K_DEL') == 0xff


@pytest.mark.parametrize('keys,confirmed', [
    ([0x316e], False), ([0x314e], False), ([0x011b], False),
    ([0x1579], True), ([0x1559], True),
    ([0x1c0d, 0x2d78, 0x4d00, 0x314e], False),
    ([0x1c0d, 0x1c0d, 0x1579], True),
])
def test_confirmation_accepts_only_yes_no_or_escape(menu_binary, keys, confirmed):
    machine = KeyboardModule(menu_binary)
    queue = list(keys)
    restored = []
    # Rendering is a separate boundary; keep the real BIOS read and decision.
    machine.write('S_QTXS', b'\xc3')
    machine.write('S_CXTUX', b'\xcd\x61\xc3')
    machine.write('D_INT16', struct.pack('<HH', 0xf000, BASE//16))
    machine.uc.mem_write(BASE+0xf000, b'\xcd\x60\xcf')

    def bios(uc, number, _):
        if number == 0x61:
            restored.append(True)
        else:
            assert number == 0x60 and machine.get('AX') >> 8 == 0x10
            assert queue, 'confirmation requested an unexpected extra key'
            machine.set('AX', queue.pop(0))

    machine.uc.hook_add(UC_HOOK_INTR, bios)
    machine.set('AX', 5)
    machine.set('DS', BASE//16)
    machine.call('L_XTK1D')
    assert not queue, 'an unrelated key dismissed the confirmation'
    assert machine.byte('D_EXIT') == (2 if confirmed else 0)
    assert bool(restored) == (not confirmed)


@pytest.mark.parametrize('version', [2, 3, 6])
@pytest.mark.parametrize('relocated', [False, True])
def test_install_keeps_dos_flag_addresses_in_the_resident(menu_binary, version, relocated):
    machine = KeyboardModule(menu_binary)
    resident = 0x5000 if relocated else BASE//16
    machine.uc.mem_write(resident*16+0x100, menu_binary[0])
    machine.set('DS', resident)
    queried_sda = []

    def dos(uc, number, _):
        assert number == 0x21
        function = machine.get('AX')
        if function >> 8 == 0x25:
            assert machine.get('DS') == resident
        elif function == 0x3528:
            machine.set('ES', 0x9000)
            machine.set('BX', 0x100)
        elif function >> 8 == 0x34:
            machine.set('ES', 0x8000)
            machine.set('BX', 0x321)
        elif function >> 8 == 0x30:
            machine.set('AX', version)
        else:
            assert function == 0x5d06 and version >= 3
            queried_sda.append(True)
            # Deliberately not adjacent to InDOS: older OEM layouts differ.
            machine.set('DS', 0x8100)
            machine.set('SI', 0x200)

    machine.uc.hook_add(UC_HOOK_INTR, dos)
    machine.call('S_SETINT')
    assert machine.get('DS') == resident
    address = resident*16+machine.symbols['D_CRITERR']
    expected = (0x322, 0x8000) if version == 2 else (0x200, 0x8100)
    assert struct.unpack('<HH', machine.uc.mem_read(address, 4)) == expected
    assert bool(queried_sda) == (version >= 3)


@pytest.mark.parametrize('pending,indos,error,in_key', [
    (0, 0, 0, 0), (2, 2, 0, 0), (2, 1, 1, 0), (2, 1, 0, 1),
    (2, 0, 0, 0), (2, 1, 0, 0),
])
@pytest.mark.parametrize('busy', [False, True])
def test_idle_unload_preserves_caller_and_retries_when_busy(
        menu_binary, pending, indos, error, in_key, busy):
    machine = KeyboardModule(menu_binary)
    machine.write('D_EXIT', bytes([pending]))
    machine.write('D_INKEY', bytes([in_key]))
    machine.write('D_INDOS', struct.pack('<HH', 0x321, 0x8000))
    machine.write('D_CRITERR', struct.pack('<HH', 0x320, 0x8000))
    # FF is the drive/error field that the faulty handler mistook for CritErr.
    machine.uc.mem_write(0x80320, bytes([error, indos, 0xff]))
    machine.write('D_INT28', struct.pack('<HH', 0xf000, BASE//16))
    machine.uc.mem_write(BASE+0xf000, b'\xcd\x61\xcf')
    calls = []

    def services(uc, number, _):
        if number == 0x10:
            machine.video()
            return
        if number == 0x61:
            for name, value in machine.initial.items():
                if name not in ('CS', 'SS', 'SP', 'EFLAGS'):
                    assert machine.get(name) == value, name
            assert machine.get('EFLAGS') & 0x601 == 0x601
            return
        assert number == 0x2f, 'menu exit must not terminate the foreground process'
        assert machine.get('AX') == 0x4a06
        assert machine.get('SS') == BASE//16, 'unload needs a private stack'
        assert not machine.get('EFLAGS') & 0x400, 'unload needs forward string operations'
        assert machine.byte('D_EXIT') == 0, 'unload must not reenter itself'
        calls.append(machine.get('SI'))
        if machine.get('SI') == 0:
            if not busy:
                machine.mode_reset()
            for name in ('AX', 'BX', 'CX', 'DX', 'SI', 'DI', 'BP', 'DS', 'ES'):
                machine.set(name, 0x9876)
        else:
            assert machine.get('SI') == 3
            machine.set('BX', 0x4a06 if busy else 0)

    machine.uc.hook_add(UC_HOOK_INTR, services)
    machine.call('INT_28', interrupt=True)
    eligible = pending and indos <= 1 and not error and not in_key
    assert calls == ([0, 3] if eligible else [])
    assert machine.byte('D_EXIT') == (2 if eligible and busy else 0 if eligible else pending)
    machine.check_console()


def dos_flags(machine, indos=0):
    machine.write('D_INDOS', struct.pack('<HH', 0x321, 0x8000))
    machine.write('D_CRITERR', struct.pack('<HH', 0x320, 0x8000))
    machine.uc.mem_write(0x80320, bytes([0, indos]))


@pytest.mark.parametrize('columns,rows', [(132, 25), (132, 50), (80, 60)])
def test_unload_leaves_unsupported_native_geometry_intact(menu_binary, columns, rows):
    machine = KeyboardModule(menu_binary)
    dos_flags(machine)
    machine.write('D_EXIT', b'\2')
    machine.uc.mem_write(0x44a, struct.pack('<H', columns))
    machine.uc.mem_write(0x484, bytes([rows - 1]))
    calls = []

    def services(uc, number, _):
        if number == 0x10:
            assert machine.get('AX') == 0x1416
            machine.video()
        else:
            assert number == 0x2f
            calls.append(machine.get('SI'))
            if machine.get('SI') == 3:
                machine.set('BX', 0)

    machine.uc.hook_add(UC_HOOK_INTR, services)
    machine.call('S_FOREGROUND_EXIT')
    assert calls == [0, 3] and machine.byte('D_EXIT') == 0
    assert machine.get('EFLAGS') & 1
    assert machine.uc.mem_read(0x44a, 2) == struct.pack('<H', columns)
    assert machine.uc.mem_read(0x484, 1) == bytes([rows - 1])
    machine.check_console()


@pytest.mark.parametrize('function', [0, 1, 0x10, 0x11])
@pytest.mark.parametrize('initially_pending', [False, True])
def test_bios_only_foreground_completes_unload(menu_binary, function, initially_pending):
    machine = KeyboardModule(menu_binary)
    dos_flags(machine)
    machine.write('D_EXIT', bytes([2 if initially_pending else 0]))
    machine.write('D_INT16', struct.pack('<HH', 0xf000, BASE//16))
    machine.uc.mem_write(BASE+0xf000, b'\xcd\x60\xcf')
    calls = []
    unloaded = []
    machine.set('AX', function << 8)

    def services(uc, number, _):
        if number == 0x10:
            machine.video()
        elif number == 0x2f:
            if machine.get('SI') == 0:
                assert machine.get('SS') == BASE//16
                unloaded.append(True)
                machine.mode_reset()
            else:
                assert machine.get('SI') == 3
                machine.set('BX', 0)
        else:
            assert number == 0x60
            operation = machine.get('AX') >> 8
            calls.append(operation)
            if not unloaded:
                assert operation in (function | 1, 0x11)
                # Simulate Y arriving while the original BIOS read is waiting.
                machine.write('D_EXIT', b'\2')
            else:
                assert operation == function
                # No return address in freed CKBD may survive the BIOS call.
                assert machine.get('SP') == machine.initial['SP']
                machine.set('AX', 0x342e)
            flags_at = machine.get('SS')*16+machine.get('SP')+4
            flags = int.from_bytes(uc.mem_read(flags_at, 2), 'little')
            uc.mem_write(flags_at, struct.pack('<H', flags & ~64 if unloaded else flags | 64))

    def timer(uc, address, size, _):
        if uc.mem_read(address, 1) == b'\xf4':
            # Wake the actual wait loop as a timer IRQ would, without replacing it.
            machine.set('IP', machine.get('IP')+1)

    machine.uc.hook_add(UC_HOOK_INTR, services)
    machine.uc.hook_add(UC_HOOK_CODE, timer)
    machine.call('INT_16', interrupt=True)
    if function & 1 and not initially_pending:
        assert not unloaded and machine.get('EFLAGS') & 64
        machine.set('SP', machine.initial['SP'])
        machine.set('AX', function << 8)
        machine.set('EFLAGS', machine.initial['EFLAGS'])
        machine.call('INT_16', interrupt=True)
    assert unloaded == [True]
    assert machine.get('AX') == 0x342e
    assert calls[-1] == function
    assert machine.get('EFLAGS') & 0x600 == 0x600
    machine.check_console()


@pytest.mark.parametrize('guard', ['D_INKEY', 'D_PUMP', 'D_IRQ', 'indos', 'video'])
def test_foreground_never_unloads_a_live_interrupt_or_display_frame(menu_binary, guard):
    machine = KeyboardModule(menu_binary)
    dos_flags(machine, int(guard == 'indos'))
    machine.write('D_EXIT', b'\2')
    if guard.startswith('D_'):
        machine.write(guard, b'\1')

    def query(uc, number, _):
        assert number == 0x10 and guard == 'video'
        machine.set('AX', 1)
        machine.set('BX', 0x4b48)

    machine.uc.hook_add(UC_HOOK_INTR, query)
    machine.call('S_FOREGROUND_EXIT')
    assert machine.byte('D_EXIT') == 2
    assert not machine.get('EFLAGS') & 1


def test_busy_irq_drains_consumed_keys_and_preserves_foreground_typeahead(menu_binary):
    machine = KeyboardModule(menu_binary)
    machine.write('D_INT9', struct.pack('<HH', 0xf000, BASE//16))
    machine.uc.mem_write(BASE+0xf000, b'\xcf')
    machine.uc.mem_write(0x41a, struct.pack('<HH', 0x1e, 0x24))
    machine.uc.mem_write(0x480, struct.pack('<HH', 0x1e, 0x3e))
    machine.uc.mem_write(0x41e, struct.pack('<3H', 0x316e, 0x1769, 0x342e))
    # Keep IRQ deferral, buffer ownership and dispatch production instructions;
    # substitute only IME lookup, whose separate tests cover character choices.
    machine.write('S_JRCL', b'\xcd\x61\xc3')
    busy = [True]
    consumed = []

    def service(uc, number, _):
        if number == 0x10:
            assert machine.get('AX') == 0x1416
            machine.set('BX', 0x4b48)
            machine.set('AX', int(busy[0]))
        else:
            assert number == 0x61 and not busy[0]
            consumed.append(machine.get('AX') & 255)
            machine.write('D_95D5', bytes([int(consumed[-1] == ord('.'))]))

    machine.uc.hook_add(UC_HOOK_INTR, service)
    machine.call('INT_9', interrupt=True)
    assert not consumed and machine.byte('D_DEFER') == 1
    assert machine.uc.mem_read(0x41a, 2) == b'\x1e\0'
    busy[0] = False
    machine.set('SP', machine.initial['SP'])
    machine.set('AX', 0x2d00)
    machine.set('BX', 0x4b48)
    machine.call('INT_16', interrupt=True)
    assert consumed == list(b'ni.')
    assert machine.uc.mem_read(0x41a, 4) == struct.pack('<HH', 0x22, 0x24)
    assert machine.byte('D_PUMP') == 0 and machine.byte('D_INKEY') == 0


def test_keys_typed_during_modal_repaint_are_not_discarded(menu_binary):
    machine = KeyboardModule(menu_binary)
    machine.write('D_INT9', struct.pack('<HH', 0xf000, BASE//16))
    machine.uc.mem_write(BASE+0xf000, b'\xcf')
    machine.uc.mem_write(0x41a, struct.pack('<HH', 0x1e, 0x20))
    machine.uc.mem_write(0x480, struct.pack('<HH', 0x1e, 0x3e))
    machine.uc.mem_write(0x41e, struct.pack('<H', 0x6200))
    machine.write('S_JRCL', b'\xcd\x61\xc3')

    def service(uc, number, _):
        if number == 0x10:
            assert machine.get('BX') == 0
            return  # An older driver does not implement the busy query.
        assert number == 0x61
        machine.write('D_KEYCONSUMED', b'\1')
        # The menu consumed its keys; a later key arrived during final repaint.
        # Include a complete ring wrap back to the original head address.
        machine.uc.mem_write(0x41e, struct.pack('<H', 0x342e))
        machine.write('D_95D5', b'\0')

    machine.uc.hook_add(UC_HOOK_INTR, service)
    machine.call('INT_9', interrupt=True)
    assert machine.uc.mem_read(0x41a, 4) == struct.pack('<HH', 0x1e, 0x20)
    assert machine.uc.mem_read(0x41e, 2) == b'.4'


def test_capability_query_does_not_drain_keys(menu_binary):
    machine = KeyboardModule(menu_binary)
    machine.write('D_DEFER', b'\1')
    machine.set('AX', 0x2d01)
    machine.set('BX', 0x4b48)
    machine.call('INT_16', interrupt=True)
    assert machine.get('AX') == 0x4b48
    assert machine.byte('D_DEFER') == 1
    assert machine.get('EFLAGS') & 0x601 == 0x601


def test_unload_preserves_32bit_registers(menu_binary, request):
    if request.node.callspec.params['menu_binary'] == '8086':
        pytest.skip('The 8086 variant cannot call a 32-bit DOS or extender.')
    machine = KeyboardModule(menu_binary)
    dos_flags(machine)
    machine.write('D_EXIT', b'\2')
    saved = {}
    for index, name in enumerate(('EAX', 'EBX', 'ECX', 'EDX', 'ESI', 'EDI', 'EBP')):
        saved[name] = 0x87650000+index*0x10000+machine.get(name)
        machine.set(name, saved[name])

    def services(uc, number, _):
        if number == 0x10:
            machine.video()
        else:
            assert number == 0x2f
            if machine.get('SI') == 0:
                machine.mode_reset()
                for name in saved:
                    machine.set(name, 0xbaad9876)
            else:
                assert machine.get('SI') == 3
                machine.set('BX', 0)

    machine.uc.hook_add(UC_HOOK_INTR, services)
    machine.call('S_FOREGROUND_EXIT')
    assert machine.get('EFLAGS') & 1
    assert {name: machine.get(name) for name in saved} == saved
    machine.check_console()


@pytest.mark.parametrize('function', [0, 0x10])
def test_blocking_read_refills_an_ime_phrase_remainder(menu_binary, function):
    machine = KeyboardModule(menu_binary)
    machine.write('D_INT16', struct.pack('<HH', 0xf000, BASE//16))
    machine.uc.mem_write(BASE+0xf000, b'\xcd\x60\xcf')
    machine.write('D_95D5', b'\2')
    machine.write('D_2BAA', struct.pack('<H', 0xe000))
    machine.write('D_KBDBUF', struct.pack('<H', 16))
    machine.uc.mem_write(BASE+0xe000, b'ab')
    machine.uc.mem_write(0x41a, struct.pack('<HH', 0x1e, 0x1e))
    machine.uc.mem_write(0x480, struct.pack('<HH', 0x1e, 0x3e))
    machine.set('AX', function << 8)

    def bios(uc, number, _):
        assert number == 0x60
        head, tail = struct.unpack('<HH', uc.mem_read(0x41a, 4))
        function = machine.get('AX') >> 8
        if head != tail:
            machine.set('AX', int.from_bytes(uc.mem_read(0x400+head, 2), 'little'))
        if not function & 1:
            assert head != tail, 'phrase refill must precede the blocking BIOS read'
            uc.mem_write(0x41a, struct.pack('<H', head+2))
        flags_at = machine.get('SS')*16+machine.get('SP')+4
        flags = int.from_bytes(uc.mem_read(flags_at, 2), 'little')
        uc.mem_write(flags_at, struct.pack('<H', flags | 64 if head == tail else flags & ~64))

    machine.uc.hook_add(UC_HOOK_INTR, bios)
    machine.call('INT_16', interrupt=True)
    assert machine.get('AX') == ord('a')
    assert machine.uc.mem_read(0x41a, 4) == struct.pack('<HH', 0x20, 0x22)
    assert machine.byte('D_95D5') == 0

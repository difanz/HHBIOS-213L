"""Run CKBD's actual confirmation, installation and DOS idle handlers."""
import re
import struct

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
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
             'INT_9', 'D_INT9', 'K_SHIFT', 'K_DEL')
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

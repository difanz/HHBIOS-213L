"""Keyboard/render ownership and native text policy in the linked driver."""
import struct

import pytest
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_WRITE

from qa.spec.test_keymenu import menu_binary
from qa.spec.test_vesa_api import Driver, initialize_with_font, vesa_driver

pytestmark = pytest.mark.unit


@pytest.mark.parametrize('busy,native', [(0, 0), (1, 0), (0, 1), (1, 1)])
def test_keyboard_busy_query_does_not_enter_the_renderer(vesa_driver, busy, native):
    machine = Driver(vesa_driver, lambda m: pytest.fail('query reached BIOS'))
    machine.write('busy', bytes([busy]))
    machine.write('mouse_native', bytes([native]))
    before = machine.read('request', 20)
    stack = machine.read('stack_bottom', 2050)
    machine.run(AX=0x1416, BX=0, CX=0x1234, DS=0x3000, ES=0x4000)
    assert (machine.get('AX'), machine.get('BX')) == (int(busy or native), 0x4b48)
    assert (machine.get('CX'), machine.get('DS'), machine.get('ES')) == (0x1234, 0x3000, 0x4000)
    assert machine.read('request', 20) == before
    assert machine.read('stack_bottom', 2050) == stack


@pytest.mark.parametrize('entry', ['int10_handler', 'int8_handler'])
def test_deferred_menu_reenters_after_restoring_the_foreground_stack(vesa_driver, entry):
    notifications = []

    def keyboard(machine):
        if machine.get('AX') == 0x2d01:
            machine.put('AX', 0x4b48)
            return
        assert machine.get('AX') == 0x2d00 and machine.get('BX') == 0x4b48
        assert machine.get('SS') == 0x8000 and machine.read('busy') == b'\0'
        notifications.append(machine.get('SP'))
        if len(notifications) != 1:
            return  # CKBD's pump rejects reentry while its menu is open.
        sp = machine.get('SP') - 6
        machine.uc.mem_write(0x80000 + sp, struct.pack(
            '<3H', machine.get('IP'), machine.get('CS'), machine.get('EFLAGS')))
        machine.put('SP', sp)
        machine.put('CS', 0x3000)
        machine.put('IP', 0)

    machine = Driver(vesa_driver, lambda m: pytest.fail('menu reached BIOS'), keyboard)
    machine.write('keyboard_segment', struct.pack('<H', 0x2000))
    machine.uc.mem_write(0x20103, b'\xef\xcd')
    machine.write('active', b'\1')
    machine.write('old8', struct.pack('<HH', 0xf100, 0x1000))
    machine.uc.mem_write(0x1f100, b'\xcf')
    # Clear/open the real status row, write Y, then deliberately clobber the
    # callback's registers. The interrupted caller's entire context survives.
    call = b'\x9c\x9a' + struct.pack('<HH', machine.symbols['int10_handler'], 0x1000)
    code = b'\xb8\x00\x14\xbb\x1e\x00' + call
    code += b'\xb8\x03\x14\xba\x59\x00' + call
    code += b'\x66\xb9\xef\xbe\xad\xde\xb8\xad\xde\x8e\xd8\xcf'
    machine.uc.mem_write(0x30000, code)
    pixels = []
    machine.uc.hook_add(UC_HOOK_MEM_WRITE,
                       lambda uc, access, address, size, value, _: pixels.append(address),
                       begin=0xa0000 + 57500, end=0xa0000 + 59800 - 1)
    machine.run(entry, AX=0x0f00, ECX=0x12345678, DS=0x4000, ES=0x5000,
                limit=2000000)
    assert len(notifications) == 3
    assert pixels, 'the deferred menu never reached the status-row framebuffer'
    assert struct.unpack_from('<4H', machine.read('request', 8)) == (0x1403, 0x1e, 0x5678, ord('Y'))
    assert machine.get('ECX') == 0x12345678
    assert (machine.get('DS'), machine.get('ES'), machine.get('SS')) == (0x4000, 0x5000, 0x8000)


def test_old_keyboard_is_not_called_on_every_refresh(vesa_driver):
    calls = []
    machine = Driver(vesa_driver, lambda m: pytest.fail('unexpected BIOS call'),
                     lambda m: calls.append(m.get('AX')))
    machine.write('keyboard_segment', struct.pack('<H', 0x2000))
    machine.uc.mem_write(0x20103, b'\xef\xcd')
    for _ in range(4):
        machine.run(AX=0x1411)
    assert calls == [0x2d01]
    machine.write('keyboard_segment', struct.pack('<H', 0x2100))
    machine.uc.mem_write(0x21103, b'\xef\xcd')
    machine.run(AX=0x1411)
    assert calls == [0x2d01, 0x2d01]


@pytest.mark.parametrize('notification', [0x2900, 0x2d00])
def test_notifications_keep_the_display_return_frame_resident(vesa_driver, notification):
    calls = []

    def keyboard(machine):
        ax = machine.get('AX')
        if ax == 0x2d01:
            machine.put('AX', 0x4b48)
            return
        calls.append(ax)
        assert machine.read('busy') == b'\0'
        if len(calls) != 1:
            return
        # A concurrent DOS idle handler must not unload this display even
        # though its renderer is available for nested status-line drawing.
        sp = machine.get('SP') - 6
        machine.uc.mem_write(machine.get('SS') * 16 + sp, struct.pack(
            '<3H', machine.get('IP'), machine.get('CS'), machine.get('EFLAGS')))
        machine.put('SP', sp)
        machine.put('CS', 0x3000)
        machine.put('IP', 0)

    machine = Driver(vesa_driver, lambda m: pytest.fail('unexpected BIOS call'), keyboard)
    if notification == 0x2900:
        machine.write('prompt_notify', b'\1')
    else:
        machine.write('keyboard_segment', struct.pack('<H', 0x2000))
        machine.uc.mem_write(0x20103, b'\xef\xcd')
    # Complete a nested status request before trying to unload the outer
    # notification: a boolean lifetime flag would clear too early here.
    code = b'\xb8\x02\x14\x31\xd2\x9c\x9a'
    code += struct.pack('<HH', machine.symbols['int10_handler'], 0x1000)
    code += b'\xb8\x06\x4a\x31\xf6\x9c\x9a'
    code += struct.pack('<HH', machine.symbols['int2f_handler'], 0x1000) + b'\xcf'
    machine.uc.mem_write(0x30000, code)
    machine.write('active', b'\1')
    machine.run(AX=0x1411, DS=0x4000, ES=0x5000)
    assert calls == [notification] * (1 if notification == 0x2900 else 2)
    assert (machine.get('AX'), machine.get('DS'), machine.get('SS')) == (0x5356, 0x4000, 0x8000)


def mode_switch_driver(image, failure=0x4f02):
    calls = []
    initializing = True

    def bios(machine):
        ax = machine.get('AX')
        if not initializing:
            calls.append((ax, machine.get('BX')))
            if ax == 3:
                machine.uc.mem_write(0x449, b'\3')
            elif ax == 0x4f04 and machine.get('DX') == 0:
                machine.put('BX', 1)
            machine.put('AX', 0x014f if ax == failure else 0x004f)
            return
        address = machine.get('ES') * 16 + machine.get('DI')
        machine.put('AX', 0x004f)
        if ax == 0x4f00:
            info = bytearray(256)
            info[:4] = b'VESA'
            struct.pack_into('<H', info, 4, 0x200)
            machine.uc.mem_write(address, bytes(info))
        elif ax == 0x4f01:
            info = bytearray(256)
            struct.pack_into('<HBBHHHHIHHHHBBBB', info, 0, 0x1b, 7, 0,
                             64, 64, 0xa000, 0, 0, 100, 800, 600, 0x1008, 4, 4, 1, 3)
            info[29] = 1
            machine.uc.mem_write(address, bytes(info))
        elif ax == 0x1130:
            machine.put('ES', 0xc000)
            machine.put('BP', 0x100)
        elif ax == 0x0f00:
            machine.put('AX', 0x5003)
        elif ax == 0x4f03:
            machine.put('BX', 3)
        elif ax == 0x4f05:
            machine.put('AX', 0x014f)
        else:
            assert ax in (0x4f02, 3)

    machine = initialize_with_font(image, bios)
    initializing = False
    machine.write('active', b'\1')
    machine.write('keyboard_segment', struct.pack('<H', 0x2000))
    return machine, calls


@pytest.mark.parametrize('mode', [3, 0x83, 0x4f02])
def test_disabled_text_translation_reaches_native_bios(vesa_driver, mode):
    machine, calls = mode_switch_driver(vesa_driver, failure=None)
    machine.run(AX=0x180a)
    machine.run(AX=mode, BX=3)
    assert calls == [(mode, 3)]
    assert machine.read('active') == machine.read('direct') == b'\0'
    assert machine.uc.mem_read(0x20100, 3) == b'\x12\3\0'


@pytest.mark.parametrize('failure', [0x4f02, 0x4f05])
@pytest.mark.parametrize('translated', [False, True])
def test_native_return_uses_requested_policy_and_keeps_failures_inactive(
        vesa_driver, failure, translated):
    machine, calls = mode_switch_driver(vesa_driver, failure=failure)
    machine.run(AX=0x180a)
    machine.run(AX=3)
    calls.clear()
    if translated:
        machine.run(AX=0x180b)  # Policy changes also work in native mode.
    machine.run(AX=3 if translated else 0x12)
    assert calls == ([(0x4f02, 0x102)] if failure == 0x4f02 else
                     [(0x4f02, 0x102), (0x4f05, 0)])
    assert machine.read('active') == b'\0'
    assert machine.read('direct') == bytes([translated])
    assert machine.uc.mem_read(0x20101, 1) == (b'\3' if failure == 0x4f02 else b'\xff')


def test_failed_vbe_set_does_not_forget_native_keyboard_mode(vesa_driver):
    machine, calls = mode_switch_driver(vesa_driver)
    machine.run(AX=0x180a)
    machine.run(AX=3)
    machine.run(AX=0x4f02, BX=0x101)
    assert machine.get('AX') == 0x014f and machine.read('active') == b'\0'
    assert machine.uc.mem_read(0x20100, 3) == b'\x12\3\0'


@pytest.mark.parametrize('extension', [False, True])
def test_video_state_restores_policy_without_reinterpreting_old_records(vesa_driver, extension):
    machine, calls = mode_switch_driver(vesa_driver)
    record = bytearray(64)
    record[:4] = b'HHV\1'
    record[5] = 3
    record[13] = 9
    if extension:
        record[52] = 3
        record[53] = 1
    machine.uc.mem_write(0x30040, bytes(record))
    machine.run(AX=0x4f04, BX=0, CX=9, DX=2, ES=0x3000)
    assert machine.get('AX') == 0x004f
    assert machine.uc.mem_read(0x20101, 1) == (b'\3' if extension else b'\xff')
    calls.clear()
    machine.run(AX=3)
    assert calls == ([(3, 0)] if extension else [(0x4f02, 0x102)])


def test_keyboard_irq_during_real_refresh_defers_the_complete_menu(vesa_driver, menu_binary):
    keyboard_image, keyboard_symbols = menu_binary
    keyboard_base = 0x50000
    entries = []
    menu_calls = []
    bios_reads = []

    def enter_interrupt(machine, segment, offset):
        sp = machine.get('SP') - 6
        machine.uc.mem_write(machine.get('SS') * 16 + sp, struct.pack(
            '<3H', machine.get('IP'), machine.get('CS'), machine.get('EFLAGS')))
        machine.put('SP', sp)
        machine.put('EFLAGS', machine.get('EFLAGS') & ~0x300)
        machine.put('CS', segment)
        machine.put('IP', offset)

    def keyboard(machine):
        enter_interrupt(machine, keyboard_base // 16, keyboard_symbols['INT_16'])

    def service(machine, number):
        if number == 0x10:
            if machine.get('AX') != 0x1416:
                assert machine.read('busy') == b'\0'
                assert len(entries) == 2, 'menu entered before the interrupted renderer resumed'
                menu_calls.append(machine.get('AX'))
            enter_interrupt(machine, 0x1000, machine.symbols['int10_handler'])
            return
        assert number == 0x60, f'unexpected external service {number:02x}'
        assert machine.get('AX') >> 8 == 0x10
        assert machine.get('SS') == 0x8000, 'modal input reused the renderer stack'
        assert machine.read('busy') == b'\0' and menu_calls
        head, tail = struct.unpack('<HH', machine.uc.mem_read(0x41a, 4))
        assert head != tail, 'menu consumed the complete foreground key queue'
        key, = struct.unpack('<H', machine.uc.mem_read(0x400 + head, 2))
        bios_reads.append(key)
        machine.put('AX', key)
        machine.uc.mem_write(0x41a, struct.pack('<H', head + 2))

    machine = Driver(vesa_driver, lambda m: pytest.fail('menu reached video BIOS'),
                     keyboard, service)
    machine.uc.mem_write(keyboard_base + 0x100, keyboard_image)
    machine.uc.mem_write(keyboard_base + 0x100, b'\x12\x12\1\xef\xcd')
    machine.write('keyboard_segment', struct.pack('<H', keyboard_base // 16))
    machine.uc.mem_write(keyboard_base + keyboard_symbols['D_INT9'],
                         struct.pack('<HH', 0xf000, keyboard_base // 16))
    machine.uc.mem_write(keyboard_base + 0xf000, b'\xcf')
    machine.uc.mem_write(keyboard_base + keyboard_symbols['D_INT16'],
                         struct.pack('<HH', 0xf100, keyboard_base // 16))
    machine.uc.mem_write(keyboard_base + 0xf100, b'\xcd\x60\xcf')
    keys = [0x6200] + [0x4d00] * 4 + [0x1c0d, 0x316e, 0x342e]
    machine.uc.mem_write(0x41a, struct.pack('<HH', 0x1e, 0x1e + 2 * len(keys)))
    machine.uc.mem_write(0x480, struct.pack('<HH', 0x1e, 0x3e))
    machine.uc.mem_write(0x41e, struct.pack('<8H', *keys))
    machine.uc.mem_write(0xb8000, b'A\x07' * 2000)
    machine.write('active', b'\1')

    def interrupt_refresh(uc, address, size, _):
        if len(entries) == 2:
            return
        assert machine.read('busy') == b'\1'
        entries.append(address)
        if len(entries) == 1:
            enter_interrupt(machine, keyboard_base // 16, keyboard_symbols['INT_9'])
        else:
            assert machine.uc.mem_read(keyboard_base + keyboard_symbols['D_DEFER'], 1) == b'\1'
            assert not menu_calls and not bios_reads

    refresh = 0x10000 + machine.symbols['refresh_dirty']
    machine.uc.hook_add(UC_HOOK_CODE, interrupt_refresh, begin=refresh, end=refresh)
    machine.run(AX=0x1500, DS=0x3000, ES=0x4000, limit=100000000)
    assert len(entries) == 2 and bios_reads == keys[:-1]
    assert 0x1400 in menu_calls and 0x1403 in menu_calls
    for name in ('D_DEFER', 'D_PUMP', 'D_IRQ', 'D_INKEY', 'D_EXIT'):
        assert machine.uc.mem_read(keyboard_base + keyboard_symbols[name], 1) == b'\0'
    head, tail = struct.unpack('<HH', machine.uc.mem_read(0x41a, 4))
    assert tail - head == 2 and machine.uc.mem_read(0x400 + head, 2) == b'.4'
    assert (machine.get('AX'), machine.get('DS'), machine.get('ES')) == (0x1500, 0x3000, 0x4000)

"""Full production scroll loops against an independent four-plane pixel image."""
import struct

import pytest
from unicorn import UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn import x86_const as reg

from qa.spec.test_vesa_api import Driver, vesa_driver

pytestmark = pytest.mark.unit


@pytest.mark.parametrize('shift', [0, 3, 7])
@pytest.mark.parametrize('down', [0, 1])
@pytest.mark.parametrize('count', [1, 3])
def test_scroll_preserves_partial_edges_and_crosses_banks(vesa_driver, shift, down, count):
    pitch, height, rows, first, last = 172, 17, 43, 1, 41
    initial = [bytes((index * 19 + index // pitch + plane * 71) & 255
                     for index in range(3 * 65536)) for plane in range(4)]
    planes = [bytearray(plane) for plane in initial]
    state = dict(bank=0, read=0, write=15, mode=0, latches=[0] * 4, banks=set())

    def bios(machine):
        assert machine.get('AX') == 0x4f05
        state['bank'] = machine.get('DX')
        state['banks'].add(state['bank'])
        assert state['bank'] in (0, 1, 2)
        machine.put('AX', 0x004f)

    machine = Driver(vesa_driver, bios)
    machine.uc.mem_write(0x10000 + machine.symbols['begin_draw'], b'\xb8\1\0\xc3')
    machine.uc.mem_write(0x10000 + machine.symbols['end_draw'], b'\xc3')
    machine.write('screen', struct.pack('<4H', 1376, 768, pitch, 0xa000))
    for name, value in dict(font_width=17, raster_height=height, viewport_x=shift,
                            viewport_y=9, pixel_scale=1, display_pitch=pitch,
                            bank_step=1, mapped_block=0, text_rows=rows).items():
        machine.write(name, struct.pack('<H', value))
    machine.write('active', b'\1')
    shadow = struct.pack('<4000H', *range(4000))
    machine.write('shadow', shadow)

    def out(uc, port, size, value, user):
        assert size == 2
        if port == 0x3c4:
            assert value & 255 == 2
            state['write'] = value >> 8
        else:
            assert port == 0x3ce
            if value & 255 == 4:
                state['read'] = value >> 8
            else:
                assert value & 255 == 5 and value >> 8 in (0, 1)
                state['mode'] = value >> 8

    def memory(uc, access, address, size, value, user):
        offset = state['bank'] * 65536 + address - 0xa0000
        assert address + size <= 0xb0000
        if access != UC_MEM_WRITE:
            state['latches'] = [plane[offset + size - 1] for plane in planes]
            uc.mem_write(address, bytes(planes[state['read']][offset:offset + size]))
        else:
            if state['mode'] == 1:
                assert size == 1, 'Each VGA latch read must be followed by its byte write'
            for plane in range(4):
                if state['write'] & (1 << plane):
                    planes[plane][offset:offset + size] = (
                        bytes([state['latches'][plane]]) if state['mode'] == 1
                        else value.to_bytes(size, 'little'))

    machine.uc.hook_add(UC_HOOK_INSN, out, None, 1, 0, reg.UC_X86_INS_OUT)
    machine.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, memory,
                        begin=0xa0000, end=0xaffff)
    machine.uc.mem_write(0x1e002, struct.pack('<4H', first, last, count, down))
    machine.run('raster_scroll', limit=10000000)
    assert machine.get('AX') == 1
    assert state['banks'] >= {0, 1}
    # Work with entire pixel rows, preserving all pixels outside the viewport.
    mask = ((1 << 1360) - 1) << (pitch * 8 - shift - 1360)
    retained_rows = (last - first + 1 - count) * height
    destination_y = 9 + (first + (count if down else 0)) * height
    delta = (-count if down else count) * height
    for plane, before in enumerate(initial):
        expected = bytearray(before)
        for y in range(destination_y, destination_y + retained_rows):
            source = int.from_bytes(before[(y + delta) * pitch:(y + delta + 1) * pitch], 'big')
            previous = int.from_bytes(before[y * pitch:(y + 1) * pitch], 'big')
            expected[y * pitch:(y + 1) * pitch] = (
                (previous & ~mask) | (source & mask)).to_bytes(pitch, 'big')
        assert planes[plane] == expected, (plane, shift, down, count)
    expected_shadow = bytearray(shadow)
    start = (first + (count if down else 0)) * 160
    length = (last - first + 1 - count) * 160
    source = start + (-count if down else count) * 160
    expected_shadow[start:start + length] = shadow[source:source + length]
    assert bytes(machine.uc.mem_read(0x10000 + machine.symbols['shadow'], 8000)) == expected_shadow

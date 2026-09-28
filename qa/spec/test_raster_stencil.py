"""All-plane native glyphs against an independent VGA and pixel oracle."""
import struct

import pytest

from qa.spec.planar_memory import PlanarMemory
from qa.spec.test_vesa_api import Driver, vesa_driver

pytestmark = pytest.mark.unit


@pytest.mark.parametrize('width,shift', [(12, 0), (12, 4), (17, 3), (17, 7),
                                        (24, 3), (24, 7)])
@pytest.mark.parametrize('rows', [1, 29, 64])
@pytest.mark.parametrize('attribute', [0, 0xff, 0x07, 0x1e, 0x1b, 0x70, 0xa5, 0x44])
def test_native_stencil_preserves_edges_and_registers(vesa_driver, width, shift,
                                                      rows, attribute):
    machine = Driver(vesa_driver, lambda m: pytest.fail('No BIOS call inside a bank span'))
    pitch = 240
    span = (width + shift + 7) // 8
    offset = 65536 - span - (rows - 1) * pitch
    machine.write('display_pitch', struct.pack('<H', pitch))
    machine.uc.mem_write(0x10000 + machine.symbols['screen'] + 6, struct.pack('<H', 0xa000))
    original = [bytes((index * 29 + plane * 71) & 255 for index in range(65536))
                for plane in range(4)]
    memory = PlanarMemory(machine, original)
    memory.gc[0] = 9
    source = bytes((index * 137 + 49) & 255 for index in range(64 * 16))
    masks = bytearray(span)
    for pixel in range(shift, shift + width):
        masks[pixel // 8] |= 128 >> (pixel & 7)
    machine.uc.mem_write(0x1d000, source)
    machine.uc.mem_write(0x1d400, bytes(masks))
    machine.uc.mem_write(0x1e002, struct.pack('<7H', 0xd000, offset, rows,
                                             span, 0xd400, attribute, 16))
    registers = {name: 0xa1234567 + index for index, name in
                 enumerate(('EAX', 'EBX', 'ECX', 'EDX', 'ESI', 'EDI', 'EBP'))}
    machine.run('raster_stencil', ES=0x3000, **registers)
    for plane, initial in enumerate(original):
        expected = bytearray(initial)
        for row in range(rows):
            for pixel in range(shift, shift + width):
                byte, bit = divmod(pixel, 8)
                mask = 128 >> bit
                ink = source[row * 16 + byte] & mask
                color = attribute & (1 << (plane if ink else plane + 4))
                position = offset + row * pitch + byte
                expected[position] = (expected[position] & ~mask) | (mask if color else 0)
        assert memory.planes[plane] == expected
    edges = sum(mask != 255 for mask in masks)
    assert len(memory.reads) <= 2 * rows * edges + span - edges
    assert memory.gc[0] == 9 and memory.gc[1] == memory.gc[5] == 0 and memory.gc[8] == 255
    assert all(machine.get(name) == value for name, value in registers.items())
    assert machine.get('ES') == 0x3000
    assert bytes(machine.uc.mem_read(0x1d000, len(source))) == source

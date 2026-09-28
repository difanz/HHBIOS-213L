"""Native aligned cells: exact plane bytes, bank limits and C calling convention."""
import struct

import pytest
from unicorn import UC_HOOK_CODE, UC_HOOK_MEM_READ

from qa.spec.test_vesa_api import Driver, vesa_driver

pytestmark = pytest.mark.unit


@pytest.mark.parametrize('width', [1, 2, 3])
@pytest.mark.parametrize('rows', [1, 23, 64])
@pytest.mark.parametrize('foreground,background', [(0, 0), (0, 65535),
                                                  (65535, 0), (65535, 65535)])
def test_native_spans_overwrite_without_vram_reads(vesa_driver, width, rows,
                                                  foreground, background):
    machine = Driver(vesa_driver, lambda m: pytest.fail('No BIOS call inside a bank span'))
    pitch = 512
    offset = 65536 - width - (rows - 1) * pitch
    machine.write('display_pitch', struct.pack('<H', pitch))
    machine.uc.mem_write(0x10000 + machine.symbols['screen'] + 6, struct.pack('<H', 0xa000))
    initial = bytes((index * 17 + 83) & 255 for index in range(65536))
    source = bytes((index * 137 + 49) & 255 for index in range(64 * 16))
    machine.uc.mem_write(0xa0000, initial)
    machine.uc.mem_write(0x1d000, source)
    machine.uc.mem_write(0x1d400, b'\xff' * width)
    machine.uc.mem_write(0x1e002, struct.pack('<9H', 0xd000, offset, rows, width,
                                             0xd400, foreground, background, 1, 0))
    reads = []
    machine.uc.hook_add(UC_HOOK_MEM_READ,
                        lambda uc, access, address, size, value, user: reads.append(address),
                        begin=0xa0000, end=0xaffff)
    registers = {name: 0xa1234567 + index for index, name in
                 enumerate(('EAX', 'EBX', 'ECX', 'EDX', 'ESI', 'EDI', 'EBP'))}
    machine.run('raster_span', ES=0x3000, **registers)
    expected = bytearray(initial)
    for row in range(rows):
        for column in range(width):
            expected[offset + row * pitch + column] = (
                (source[row * 16 + column] & (foreground ^ background)) ^ background) & 255
    assert bytes(machine.uc.mem_read(0xa0000, 65536)) == expected
    assert not reads
    assert all(machine.get(name) == value for name, value in registers.items())
    assert machine.get('ES') == 0x3000


@pytest.mark.parametrize('shift', [0, 4])
@pytest.mark.parametrize('rows', [1, 29, 64])
@pytest.mark.parametrize('foreground,background', [(0, 0), (0, 65535),
                                                  (65535, 0), (65535, 65535)])
def test_native_twelve_pixel_spans_merge_one_word(vesa_driver, shift, rows,
                                                  foreground, background):
    machine = Driver(vesa_driver, lambda m: pytest.fail('No BIOS call inside a bank span'))
    pitch = 128
    offset = 65534 - (rows - 1) * pitch
    machine.write('display_pitch', struct.pack('<H', pitch))
    machine.uc.mem_write(0x10000 + machine.symbols['screen'] + 6, struct.pack('<H', 0xa000))
    initial = bytes((index * 29 + 71) & 255 for index in range(65536))
    source = bytes((index * 137 + 49) & 255 for index in range(64 * 16))
    masks = (0xfff0 >> shift).to_bytes(2, 'big')
    machine.uc.mem_write(0xa0000, initial)
    machine.uc.mem_write(0x1d000, source)
    machine.uc.mem_write(0x1d400, masks)
    machine.uc.mem_write(0x1e002, struct.pack('<9H', 0xd000, offset, rows, 2,
                                             0xd400, foreground, background, 1, 0))
    reads, instructions = [], []
    machine.uc.hook_add(UC_HOOK_MEM_READ,
                        lambda uc, access, address, size, value, user: reads.append((address, size)),
                        begin=0xa0000, end=0xaffff)
    machine.uc.hook_add(UC_HOOK_CODE,
                        lambda uc, address, size, user: instructions.append(address))
    registers = {name: 0xa1234567 + index for index, name in
                 enumerate(('EAX', 'EBX', 'ECX', 'EDX', 'ESI', 'EDI', 'EBP'))}
    machine.run('raster_span', ES=0x3000, **registers)
    expected = bytearray(initial)
    for row in range(rows):
        for pixel in range(shift, shift + 12):
            byte, bit = divmod(pixel, 8)
            mask = 128 >> bit
            ink = source[row * 16 + byte] & mask
            color = foreground if ink else background
            position = offset + row * pitch + byte
            expected[position] = (expected[position] & ~mask) | (mask if color else 0)
    assert bytes(machine.uc.mem_read(0xa0000, 65536)) == expected
    assert reads == [(0xa0000 + offset + row * pitch, 2) for row in range(rows)]
    # Count executed production instructions, so a return to the generic
    # per-row dispatch cannot silently retain the old repaint cost.
    assert len(instructions) <= 80 + rows * 12
    assert all(machine.get(name) == value for name, value in registers.items())
    assert machine.get('ES') == 0x3000

"""Render cached font records through the real store and VGA stencil writer."""
import struct

import pytest

from qa.spec.planar_memory import PlanarMemory
from qa.spec.test_font20 import FontMachine, sized_font
from qa.spec.test_vesa_api import Driver, vesa_driver

pytestmark = pytest.mark.unit


@pytest.mark.parametrize('width,height', [(8, 16), (9, 23), (10, 20), (12, 29),
                                         (16, 39), (17, 64), (23, 63), (24, 41)])
@pytest.mark.parametrize('shift', [0, 3, 7])
@pytest.mark.parametrize('code', [32, 65, 0xd6d0])
def test_cached_font_pixels_and_split_attributes(vesa_driver, width, height, shift, code):
    machine = FontMachine(vesa_driver, data=sized_font(width, height))
    assert machine.call('font_open') == 1
    pitch, x, y = 240, 80 + shift, 30
    machine.write('screen', struct.pack('<4H', 1920, 1080, pitch, 0xa000))
    for name, value in dict(display_pitch=pitch, viewport_x=x, viewport_y=y,
                            pixel_scale=1, raster_height=height).items():
        machine.write(name, struct.pack('<H', value))
    machine.write('active', b'\1')
    initial = [bytes((i * 29 + plane * 71) & 255 for i in range(65536))
               for plane in range(4)]
    memory = PlanarMemory(machine, initial)
    for attribute in (0x1e4f, 0xa527):
        machine.call('font_draw', code, attribute, 0, 1)
        for plane in range(4):
            expected = bytearray(initial[plane])
            for row in range(height):
                for column in range(width * (2 if code >= 256 else 1)):
                    ink = code != 32 and (column * 3 + row * 5) % 11 < 4
                    color = attribute >> 8 if code >= 256 and column < width else attribute
                    mask = 128 >> ((x + column) & 7)
                    offset = (y + row) * pitch + (x + column) // 8
                    expected[offset] = (expected[offset] & ~mask) | (
                        mask if color & (1 << (plane if ink else plane + 4)) else 0)
            assert memory.planes[plane] == expected, (width, height, code, plane)
    assert not machine.word('font_fault')


@pytest.mark.parametrize('width,source_bit,pitch', [(8, 0, 2), (12, 0, 3),
                                                  (12, 12, 3), (17, 17, 5),
                                                  (23, 23, 6), (24, 24, 6)])
@pytest.mark.parametrize('shift', [0, 3, 7])
def test_packed_cell_crosses_window_without_touching_neighbors(vesa_driver, width,
                                                             source_bit, pitch, shift):
    def bios(machine):
        assert machine.get('AX') == 0x4f05
        memory.bank = machine.get('DX')
        assert memory.bank in (0, 1)
        machine.put('AX', 0x004f)
    machine = Driver(vesa_driver, bios)
    # First row can straddle FFFFh; remaining rows use the next bank.
    x, y, height, display_pitch = shift, 257, 23, 255
    machine.write('screen', struct.pack('<4H', 1920, 1080, display_pitch, 0xa000))
    for name, value in dict(font_width=width, raster_height=height,
                            viewport_x=x, viewport_y=y, pixel_scale=1,
                            display_pitch=display_pitch, bank_step=1).items():
        machine.write(name, struct.pack('<H', value))
    machine.write('active', b'\1')
    original = [bytes((i * 29 + plane * 71) & 255 for i in range(131072))
                for plane in range(4)]
    memory = PlanarMemory(machine, original)
    source = bytes((i * 53 + 17) & 255 for i in range(height * pitch))
    machine.uc.mem_write(0x1d000, source)
    machine.uc.mem_write(0x1e002, struct.pack('<5H', 0xd000, 0xa5, 0, pitch, source_bit))
    machine.run('raster_packed_cell', limit=1000000)
    for plane in range(4):
        expected = bytearray(original[plane])
        for row in range(height):
            for column in range(width):
                bit = source_bit + column
                ink = source[row * pitch + bit // 8] & (128 >> (bit & 7))
                mask = 128 >> ((x + column) & 7)
                offset = (y + row) * display_pitch + (x + column) // 8
                expected[offset] = (expected[offset] & ~mask) | (
                    mask if 0xa5 & (1 << (plane if ink else plane + 4)) else 0)
        assert memory.planes[plane] == expected

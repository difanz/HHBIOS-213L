"""Exercise linked 386 raster loops against a per-pixel memory oracle."""
import struct

import pytest
from unicorn import UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn import x86_const as reg

from qa.spec.test_vesa_api import Driver, vesa_driver

pytestmark = pytest.mark.unit


@pytest.mark.parametrize('width,scale,lines', [(8, 1, 0), (8, 1, 2), (16, 1, 16),
                                              (24, 2, 3), (24, 4, 32)])
@pytest.mark.parametrize('shift', range(8))
def test_cursor_byte_masks_match_pixels_across_banks(vesa_driver, width, scale, lines, shift):
    initial = bytes((i*19+i//160) & 255 for i in range(131072))
    planes = [bytearray(initial) for _ in range(4)]
    state = dict(bank=0, plane=0, writes=0)
    def save():
        start = state['bank']*65536
        planes[state['plane']][start:start+65536] = m.uc.mem_read(0xa0000, 65536)
    def load():
        start = state['bank']*65536
        m.uc.mem_write(0xa0000, bytes(planes[state['plane']][start:start+65536]))
    def bios(m):
        assert m.get('AX') == 0x4f05
        save()
        state['bank'] = m.get('DX')
        assert state['bank'] in (0, 1)
        load()
        m.put('AX', 0x004f)
    m = Driver(vesa_driver, bios)
    # Register save/restore is tested through the IRQ boundary elsewhere.
    m.uc.mem_write(0x10000+m.symbols['begin_draw'], b'\xb8\1\0\xc3')
    m.uc.mem_write(0x10000+m.symbols['end_draw'], b'\xc3')
    m.write('screen', struct.pack('<4H', 1280, 1024, 160, 0xa000))
    for name, value in dict(font_width=width, font_body_height=64, raster_height=64,
                            viewport_x=760+shift, viewport_y=350, pixel_scale=scale,
                            display_pitch=160, bank_step=1).items():
        m.write(name, struct.pack('<H', value))
    m.write('active', b'\1')
    load()
    def out(uc, port, size, value, _):
        if port == 0x3ce:
            assert size == 2 and value & 255 == 4
            save()
            state['plane'] = value >> 8
            load()
    def write(uc, access, address, size, value, _):
        state['writes'] += size
    m.uc.hook_add(UC_HOOK_INSN, out, None, 1, 0, reg.UC_X86_INS_OUT)
    m.uc.hook_add(UC_HOOK_MEM_WRITE, write, begin=0xa0000, end=0xaffff)
    m.uc.mem_write(0x1e002, struct.pack('<2H', 0, lines))
    m.run('raster_cursor', limit=3000000)
    save()
    height = ((min(lines, 16)*64+15)//16)*scale
    x, y = 760+shift, 350+64*scale-height
    expected = bytearray(initial)
    for row in range(height):
        for column in range(width*scale):
            expected[(y+row)*160+(x+column)//8] ^= 128 >> ((x+column) & 7)
    assert all(plane == expected for plane in planes)
    assert state['writes'] == 4*height*((shift+width*scale+7)//8)


@pytest.mark.parametrize('shift', range(7))
@pytest.mark.parametrize('rows', [1, 2, 3, 20, 23])
@pytest.mark.parametrize('foreground,background', [(0, 0), (0, 65535), (65535, 0), (65535, 65535)])
def test_word_rows_preserve_neighbors_and_tail(vesa_driver, shift, rows, foreground, background):
    m = Driver(vesa_driver, lambda m: pytest.fail('no BIOS call inside a bank span'))
    pitch, offset = 128, 65534 - (rows - 1) * 128
    m.write('display_pitch', struct.pack('<H', pitch))
    m.uc.mem_write(0x10000 + m.symbols['screen'] + 6, struct.pack('<H', 0xa000))
    initial = bytes((i * 53 + 17) & 255 for i in range(65536))
    m.uc.mem_write(0xa0000, initial)
    bits = [((i * 137 + 0x255) & 1023) << 6 for i in range(rows)]
    m.uc.mem_write(0x1d000, struct.pack(f'<{rows}H', *bits))
    m.uc.mem_write(0x1e002, struct.pack('<6H', 0xd000, offset, rows, shift, foreground, background))
    registers = {name: 0xa1234567 + i for i, name in
                 enumerate(('EAX', 'EBX', 'ECX', 'EDX', 'ESI', 'EDI', 'EBP'))}
    m.run('raster_words', ES=0x3000, **registers)
    expected = bytearray(initial)
    for row, glyph in enumerate(bits):
        for x in range(10):
            index = offset + row * pitch + (shift + x) // 8
            mask = 128 >> ((shift + x) % 8)
            color = foreground if glyph & (0x8000 >> x) else background
            expected[index] = (expected[index] & ~mask) | (mask if color else 0)
    assert bytes(m.uc.mem_read(0xa0000, 65536)) == expected
    assert all(m.get(name) == value for name, value in registers.items())
    assert m.get('ES') == 0x3000


@pytest.mark.parametrize('width,height,scale,legacy', [
    (8, 16, 1, False), (9, 23, 1, False), (12, 29, 1, False),
    (16, 39, 1, False), (24, 64, 1, False), (24, 64, 2, False),
    (10, 23, 4, False), (10, 23, 1, True), (10, 23, 2, True), (10, 23, 4, True)])
@pytest.mark.parametrize('shift', [0, 3, 7])
def test_raster_preparation_across_bank_edges(vesa_driver, width, height, scale, shift, legacy):
    # Emulate only bank/plane selection, with ordinary memory stores. Actual
    # VGA latch and scanout behavior are covered by the DOS pixel tests.
    initial = bytes((i * 19 + i // 160) & 255 for i in range(131072))
    planes = [bytearray(initial) for _ in range(4)]
    state = dict(bank=0, plane=0, writes=15)
    def save():
        start = state['bank'] * 65536
        planes[state['plane']][start:start + 65536] = m.uc.mem_read(0xa0000, 65536)
    def load():
        start = state['bank'] * 65536
        m.uc.mem_write(0xa0000, bytes(planes[state['plane']][start:start + 65536]))
    def bios(m):
        assert m.get('AX') == 0x4f05
        save()
        state['bank'] = m.get('DX')
        assert state['bank'] in (0, 1)
        load()
        m.put('AX', 0x004f)
    m = Driver(vesa_driver, bios)
    m.write('screen', struct.pack('<4H', 1280, 1024, 160, 0xa000))
    for name, value in dict(font_width=width, font_height=height, raster_height=height,
                            viewport_x=760 + shift, viewport_y=409,
                            pixel_scale=scale, display_pitch=160, bank_step=1).items():
        m.write(name, struct.pack('<H', value))
    m.write('active', b'\1')
    load()
    def out(uc, port, size, value, _):
        assert size == 2
        if port == 0x3ce:
            assert value & 255 == 4
            save()
            state['plane'] = value >> 8
            load()
        else:
            assert port == 0x3c4 and value & 255 == 2
            state['writes'] = value >> 8
    def memory(uc, access, address, size, value, _):
        assert address + size <= 0xb0000
        assert state['writes'] & (1 << state['plane'])
        if access == UC_MEM_WRITE:
            start = state['bank'] * 65536 + address - 0xa0000
            for plane in range(4):
                if state['writes'] & (1 << plane):
                    planes[plane][start:start+size] = value.to_bytes(size, 'little')
    m.uc.hook_add(UC_HOOK_INSN, out, None, 1, 0, reg.UC_X86_INS_OUT)
    m.uc.hook_add(UC_HOOK_MEM_READ | UC_HOOK_MEM_WRITE, memory, begin=0xa0000, end=0xaffff)
    rows = [sum(1 << (31 - x) for x in range(width) if (x * 3 + y * 5) % 11 < 4)
            for y in range(height)]
    packed = struct.pack(f'<{height}H', *(r >> 16 for r in rows)) if legacy else struct.pack(f'<{height}I', *rows)
    m.uc.mem_write(0x1d000, packed)
    m.uc.mem_write(0x1e002, struct.pack('<3H', 0xd000, 0xa5, 0))
    m.run('raster_cell' if legacy else 'raster_large_cell', limit=3000000)
    save()
    for plane in range(4):
        expected = bytearray(initial)
        for y in range(height * scale):
            for x in range(width * scale):
                offset = (409 + y) * 160 + (760 + shift + x) // 8
                mask = 128 >> ((760 + shift + x) & 7)
                ink = rows[y // scale] & (0x80000000 >> (x // scale))
                color = 0xa5 & (1 << (plane if ink else plane + 4))
                expected[offset] = (expected[offset] & ~mask) | (mask if color else 0)
        assert planes[plane] == expected, plane


@pytest.mark.parametrize('width', [1, 3, 4, 5, 13])
@pytest.mark.parametrize('repeats,phase', [(1, 0), (2, 0), (2, 1), (4, 3)])
@pytest.mark.parametrize('foreground,background', [(0, 0), (0, 65535), (65535, 0), (65535, 65535)])
def test_dword_spans_and_byte_tails(vesa_driver, width, repeats, phase, foreground, background):
    m = Driver(vesa_driver, lambda m: pytest.fail('no BIOS call inside a bank span'))
    pitch, rows = 512, 23
    offset = 65536 - width - (rows - 1) * pitch
    m.write('display_pitch', struct.pack('<H', pitch))
    m.uc.mem_write(0x10000 + m.symbols['screen'] + 6, struct.pack('<H', 0xa000))
    initial = bytes((i * 53 + 17) & 255 for i in range(65536))
    source = bytes((i * 137 + 49) & 255 for i in range(64 * 16))
    masks = bytes((0x5a if i == 0 else 0xa5 if i == width - 1 else 255) for i in range(width))
    m.uc.mem_write(0xa0000, initial)
    m.uc.mem_write(0x1d000, source)
    m.uc.mem_write(0x1d400, masks)
    m.uc.mem_write(0x1e002, struct.pack('<9H', 0xd000, offset, rows, width, 0xd400,
                                     foreground, background, repeats, phase))
    registers = {name: 0xa1234567 + i for i, name in
                 enumerate(('EAX', 'EBX', 'ECX', 'EDX', 'ESI', 'EDI', 'EBP'))}
    m.run('raster_span', ES=0x3000, **registers)
    expected = bytearray(initial)
    for row in range(rows):
        for x, mask in enumerate(masks):
            index = offset + row * pitch + x
            color = ((source[(row + phase) // repeats * 16 + x] &
                     (foreground ^ background)) ^ background) & 255
            expected[index] = (expected[index] & ~mask) | (color & mask)
    assert bytes(m.uc.mem_read(0xa0000, 65536)) == expected
    assert all(m.get(name) == value for name, value in registers.items())
    assert m.get('ES') == 0x3000

"""Exercise linked 386 raster loops against a per-pixel memory oracle."""
import struct

import pytest
from unicorn import UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE, UC_MEM_WRITE
from unicorn import x86_const as reg

from qa.spec.test_vesa_api import Driver, vesa_driver
from qa.spec.planar_memory import PlanarMemory

pytestmark = pytest.mark.unit


@pytest.mark.parametrize('column', [0, 70])
@pytest.mark.parametrize('width', [8, 10])
@pytest.mark.parametrize('style', [1, 2])
@pytest.mark.parametrize('inset', [0, 1])
def test_status_panel_edges_preserve_glyph_area_and_neighbors(vesa_driver, column,
                                                            width, style, inset):
    initial = bytes((i * 53 + 17) & 255 for i in range(131072))
    def bios(machine):
        assert machine.get('AX') == 0x4f05
        memory.bank = machine.get('DX')
        machine.put('AX', 0x004f)
    machine = Driver(vesa_driver, bios)
    memory = PlanarMemory(machine, [initial] * 4)
    machine.write('screen', struct.pack('<4H', 1920, 1080, 240, 0xa000))
    for name, value in dict(viewport_x=0, viewport_y=43, text_rows=10,
                            raster_height=23, font_width=24, pixel_scale=1,
                            display_pitch=240, bank_step=1).items():
        machine.write(name, struct.pack('<H', value))
    machine.write('active', b'\1')
    machine.uc.mem_write(0x1fe02, struct.pack('<4H', column, width, style, inset))
    machine.run('raster_status_panel', limit=1000000)
    left, right = column * 24 + 1, (column + width) * 24 - 2
    top, bottom = 273, 295 + 2 * inset
    light, dark = (8, 15) if style == 2 else (15, 0)
    pixels = {}
    if inset:
        pixels.update({(x, top): light for x in range(left, right + 1)})
        pixels.update({(x, bottom): dark for x in range(left, right + 1)})
    for y in range(top + inset, bottom - inset + 1):
        pixels.update({(left, y): light, (left + 1, y): 0 if style == 2 else 7,
                       (right - 1, y): 7 if style == 2 else 8, (right, y): dark})
    for plane in range(4):
        expected = bytearray(initial)
        for (x, y), color in pixels.items():
            offset, mask = y * 240 + x // 8, 128 >> (x & 7)
            expected[offset] = (expected[offset] & ~mask) | (mask if color & (1 << plane) else 0)
        assert memory.planes[plane] == expected


@pytest.mark.parametrize('shift', [0, 1, 3, 7])
@pytest.mark.parametrize('color', [0, 7, 8, 15])
def test_status_frame_preserves_neighbors_across_banks(vesa_driver, shift, color):
    initial = bytes((i * 53 + 17) & 255 for i in range(131072))

    def bios(machine):
        assert machine.get('AX') == 0x4f05
        memory.bank = machine.get('DX')
        machine.put('AX', 0x004f)

    machine = Driver(vesa_driver, bios)
    memory = PlanarMemory(machine, [initial] * 4)
    machine.write('screen', struct.pack('<4H', 1920, 1080, 240, 0xa000))
    for name, value in dict(viewport_x=shift, font_width=10, pixel_scale=1,
                            display_pitch=240, bank_step=1).items():
        machine.write(name, struct.pack('<H', value))
    machine.write('active', b'\1')
    # Scanline 273 crosses the 64 KiB aperture after sixteen bytes.
    machine.uc.mem_write(0x1fe02, struct.pack('<2H', 273, color))
    machine.run('raster_status_edge')
    for plane in range(4):
        expected = bytearray(initial)
        for x in range(shift, shift + 800):
            offset, mask = 273 * 240 + x // 8, 128 >> (x & 7)
            expected[offset] = (expected[offset] & ~mask) | (mask if color & (1 << plane) else 0)
        assert memory.planes[plane] == expected
    assert memory.gc[1] == 0 and memory.gc[8] == 255


@pytest.mark.parametrize('count', [0, 1, 2, 3, 79, 80, 81, 3920])
@pytest.mark.parametrize('destination,source', [(0, 80), (80, 0), (1, 0), (0, 1), (0, 0)])
def test_cell_block_move_preserves_overlap_and_registers(vesa_driver, count, destination, source):
    machine = Driver(vesa_driver, lambda m: pytest.fail('text moves need no BIOS'))
    original = bytes((i * 53 + 17) & 255 for i in range(8200))
    machine.uc.mem_write(0x30000, original)
    machine.uc.mem_write(0x1fe02, struct.pack('<5H', 2, 0x3000, destination, source, count))
    registers = {name: 0xa1234567 + i for i, name in
                 enumerate(('EAX', 'EBX', 'ECX', 'EDX', 'ESI', 'EDI', 'EBP'))}
    machine.run('move_cells', ES=0x4321, EFLAGS=0x602, **registers)
    expected = bytearray(original)
    start = 2 + destination * 2
    expected[start:start + count * 2] = original[2 + source * 2:2 + (source + count) * 2]
    assert machine.uc.mem_read(0x30000, len(original)) == expected
    assert all(machine.get(name) == value for name, value in registers.items())
    assert machine.get('DS') == 0x1000 and machine.get('ES') == 0x4321
    assert machine.get('EFLAGS') & 0x400


@pytest.mark.parametrize('count', [0, 1, 2, 3, 80, 4000])
def test_cell_block_fill_preserves_guards(vesa_driver, count):
    machine = Driver(vesa_driver, lambda m: pytest.fail('text fills need no BIOS'))
    machine.uc.mem_write(0x30000, b'\xa5' * 8004)
    machine.uc.mem_write(0x1fe02, struct.pack('<4H', 2, 0x3000, 0x9e20, count))
    machine.run('fill_cells', EFLAGS=0x602)
    assert machine.uc.mem_read(0x30000, 8004) == b'\xa5' * 2 + b'\x20\x9e' * count + b'\xa5' * (8002 - count * 2)
    assert machine.get('EFLAGS') & 0x400


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
    m.uc.mem_write(0x1fe02, struct.pack('<2H', 0, lines))
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
    m.uc.mem_write(0x1fe02, struct.pack('<6H', 0xd000, offset, rows, shift, foreground, background))
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
    # Execute the complete preparation and bank-splitting paths with VGA
    # latches; actual scanout is also checked by the DOS pixel tests.
    initial = bytes((i * 19 + i // 160) & 255 for i in range(131072))
    def bios(m):
        assert m.get('AX') == 0x4f05
        memory.bank = m.get('DX')
        assert memory.bank in (0, 1)
        m.put('AX', 0x004f)
    m = Driver(vesa_driver, bios)
    memory = PlanarMemory(m, [initial] * 4)
    m.write('screen', struct.pack('<4H', 1280, 1024, 160, 0xa000))
    for name, value in dict(font_width=width, font_height=height, raster_height=height,
                            viewport_x=760 + shift, viewport_y=409,
                            pixel_scale=scale, display_pitch=160, bank_step=1).items():
        m.write(name, struct.pack('<H', value))
    m.write('active', b'\1')
    rows = [sum(1 << (31 - x) for x in range(width) if (x * 3 + y * 5) % 11 < 4)
            for y in range(height)]
    packed = struct.pack(f'<{height}H', *(r >> 16 for r in rows)) if legacy else struct.pack(f'<{height}I', *rows)
    m.uc.mem_write(0x1d000, packed)
    m.uc.mem_write(0x1fe02, struct.pack('<3H', 0xd000, 0xa5, 0))
    m.run('raster_cell' if legacy else 'raster_large_cell', limit=3000000)
    for plane in range(4):
        expected = bytearray(initial)
        for y in range(height * scale):
            for x in range(width * scale):
                offset = (409 + y) * 160 + (760 + shift + x) // 8
                mask = 128 >> ((760 + shift + x) & 7)
                ink = rows[y // scale] & (0x80000000 >> (x // scale))
                color = 0xa5 & (1 << (plane if ink else plane + 4))
                expected[offset] = (expected[offset] & ~mask) | (mask if color else 0)
        assert memory.planes[plane] == expected, plane


@pytest.mark.parametrize('width,shift', [(8, 0), (16, 0), (24, 0),
                                        (10, 0), (10, 2), (10, 4), (10, 6),
                                        (12, 4), (24, 7)])
@pytest.mark.parametrize('attribute', [0x00, 0xff, 0x07, 0x70, 0x1e, 0x2f, 0xa5, 0x5a])
@pytest.mark.parametrize('rows', [1, 39])
def test_native_stencil_colors_and_neighbors(vesa_driver, width, shift, attribute, rows):
    m = Driver(vesa_driver, lambda m: pytest.fail('no BIOS call inside a bank span'))
    pitch = 240
    byte_count = (width + shift + 7) // 8
    offset = 65536 - byte_count - (rows - 1) * pitch
    initial = [bytes((i * 53 + i // pitch + plane * 71) & 255
                     for i in range(65536)) for plane in range(4)]
    memory = PlanarMemory(m, initial)
    memory.gc[0] = 9
    m.write('screen', struct.pack('<4H', 1920, 1080, pitch, 0xa000))
    m.write('display_pitch', struct.pack('<H', pitch))
    masks = bytearray(byte_count)
    source_pitch = 2 if width == 10 else 16
    ink = bytearray(rows * source_pitch)
    for x in range(width):
        masks[(shift + x) // 8] |= 128 >> ((shift + x) % 8)
        for y in range(rows):
            if (x * 3 + y * 5) % 11 < 4:
                ink[y * source_pitch + (shift + x) // 8] |= 128 >> ((shift + x) % 8)
    m.uc.mem_write(0x1d000, bytes(ink))
    m.uc.mem_write(0x1d400, bytes(masks))
    m.uc.mem_write(0x1fe02, struct.pack('<7H', 0xd000, offset, rows,
                                     byte_count, 0xd400, attribute, source_pitch))
    registers = {name: 0xa1234567 + i for i, name in
                 enumerate(('EAX', 'EBX', 'ECX', 'EDX', 'ESI', 'EDI', 'EBP'))}
    m.run('raster_stencil', ES=0x3000, **registers)
    for plane in range(4):
        expected = bytearray(initial[plane])
        for y in range(rows):
            for x in range(width):
                index = offset + y * pitch + (shift + x) // 8
                mask = 128 >> ((shift + x) % 8)
                foreground = (x * 3 + y * 5) % 11 < 4
                color = attribute & (1 << (plane if foreground else plane + 4))
                expected[index] = (expected[index] & ~mask) | (mask if color else 0)
        assert memory.planes[plane] == expected, plane
    assert all(m.get(name) == value for name, value in registers.items())
    assert m.get('ES') == 0x3000
    assert (memory.gc[0], memory.gc[1], memory.gc[5], memory.gc[8]) == (9, 0, 0, 255)
    assert memory.mask == 15


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
    m.uc.mem_write(0x1fe02, struct.pack('<9H', 0xd000, offset, rows, width, 0xd400,
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


@pytest.mark.parametrize('row,column', [(0, 0), (15, 2), (25, 79)])
def test_fixed_cells_use_relocated_aperture(vesa_driver, row, column):
    m = Driver(vesa_driver, lambda m: pytest.fail('unbanked drawing needs no BIOS call'))
    m.write('active', b'\1')
    m.write('screen', struct.pack('<4H', 800, 600, 100, 0xa000))
    # The one-image layout places scanout around the reserved B800 text page.
    segment = 0xa943
    m.write('framebuffer', struct.pack('<H', segment))
    m.uc.mem_write(0x1d000, struct.pack('<23H', *([0xa540] * 23)))
    m.uc.mem_write(0x1fe02, struct.pack('<3H', 0xd000, 0x1e, row * 256 + column))
    written = set()
    m.uc.hook_add(UC_HOOK_MEM_WRITE,
                 lambda uc, access, address, size, value, _: written.update(range(address, address + size)),
                 begin=0xa0000, end=0xbffff)
    m.run('draw_half')
    start = segment * 16 + row * 23 * 100 + column * 10 // 8
    assert written == {start + y * 100 + x for y in range(23) for x in range(2)}

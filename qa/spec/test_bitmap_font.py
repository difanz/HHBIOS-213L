"""Shared file validation and printer bands, using production C on the host."""
import ctypes as C
import struct
import subprocess

import pytest
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE
from unicorn import x86_const as reg

from qa.spec.build import asm_includes
from qa.spec.dos import ROOT


class FontInfo(C.Structure):
    _fields_ = [(name, C.c_ushort) for name in
                ('format', 'width', 'height', 'record_bytes', 'records')] + [
                    ('payload_bytes', C.c_uint)]


class Bitmap(C.Structure):
    _fields_ = [(name, C.c_ushort) for name in
                ('width', 'height', 'stride', 'record_bytes', 'records')] + [
                    ('payload_bytes', C.c_uint)]


@pytest.fixture(scope='module')
def bitmap_library(tmp_path_factory, source_dir):
    library = tmp_path_factory.mktemp('bitmap-font') / 'bitmap.so'
    subprocess.run(['cc', '-std=c99', '-Wall', '-Wextra', '-Werror', '-shared',
                    '-fPIC', '-DPRINTFONT_HOST', str(source_dir / 'font/bitmap.c'),
                    str(source_dir / 'common/font_file.c'), '-o', str(library)],
                   check=True, capture_output=True)
    result = C.CDLL(str(library))
    result.DecodeFontFile.argtypes = [C.c_char_p, C.POINTER(FontInfo)]
    result.DecodeBitmapFont.argtypes = [C.c_char_p, C.c_ushort, C.POINTER(Bitmap)]
    result.BitmapFontSlot.argtypes = [C.c_ushort]
    result.BitmapFontSlot.restype = C.c_ushort
    result.RenderPrintBand.argtypes = [C.POINTER(Bitmap), C.c_char_p] + [
        C.c_ushort] * 4 + [C.c_char_p]
    return result


def header(size, records=2):
    return struct.pack('<8s4HI12x', b'HHFONT2\n', size // 2, size, 8434,
                       records, 33736 + records * size * (size // 8))


@pytest.mark.unit
@pytest.mark.parametrize('size', [24, 32, 40])
def test_native_printer_geometry(bitmap_library, size):
    info = FontInfo()
    font = Bitmap()
    assert bitmap_library.DecodeFontFile(header(size), info)
    assert bitmap_library.DecodeBitmapFont(header(size), size, font)
    assert (info.format, font.width, font.height, font.stride) == (
        2, size // 2, size, size // 8)
    assert not bitmap_library.DecodeBitmapFont(header(size), 16, font)


@pytest.mark.unit
def test_display_v1_remains_readable_but_not_a_new_printing_font(bitmap_library):
    original = struct.pack('<8s4HI12x', b'HH20F01\n', 10, 23, 8434, 1, 33806)
    info = FontInfo()
    assert bitmap_library.DecodeFontFile(original, info)
    assert (info.format, info.record_bytes) == (1, 70)
    assert not bitmap_library.DecodeBitmapFont(original, 24, Bitmap())


@pytest.mark.unit
@pytest.mark.parametrize('offset,value', [(0, 0), (8, 7), (10, 65), (12, 0),
                                         (14, 0), (16, 0), (20, 1), (31, 1)])
def test_malformed_font_header_does_not_overwrite_metadata(bitmap_library, offset, value):
    source = bytearray(header(32))
    source[offset] = value
    info = FontInfo(9, 8, 7, 6, 5, 4)
    before = bytes(info)
    assert not bitmap_library.DecodeFontFile(bytes(source), info)
    assert bytes(info) == before


@pytest.mark.unit
@pytest.mark.parametrize('code,slot', [(0x41, 65), (0xaa41, 65), (0xaac1, 65),
    (0xaaa0, 32), (0xa1a1, 256), (0xb0a1, 1666), (0xf7fe, 8433),
    (0xa0a1, 65535), (0xb07f, 65535), (0xb0ff, 65535), (0xf8a1, 65535)])
def test_printer_codes_select_real_font_slots(bitmap_library, code, slot):
    assert bitmap_library.BitmapFontSlot(code) == slot


def pattern(size):
    # Asymmetric edges catch rotated/transposed bit order and band reversal.
    return [[int(x == 1 or (y == size - 2 and x < size // 2) or
                 (x == size - 3 and y < size // 3))
             for x in range(size)] for y in range(size)]


def packed_rows(pixels):
    return b''.join(sum(bit << (len(row) - x - 1) for x, bit in enumerate(row))
                    .to_bytes(len(row) // 8, 'big') for row in pixels)


def unpack_columns(data, columns):
    return [[int(bool(data[x * 3 + y // 8] & (128 >> (y % 8))))
             for x in range(columns)] for y in range(24)]


def render(library, size, pixels, code=0xb0a1, attributes=0, band=0, format=None):
    font = Bitmap()
    assert library.DecodeBitmapFont(header(size), size, font)
    output = C.create_string_buffer(180)
    if format is None:
        format = {24: 0x40, 32: 0x80, 40: 0xc0}[size]
    columns = library.RenderPrintBand(font, packed_rows(pixels), code, format,
                                     attributes, band, output)
    return unpack_columns(output.raw, columns)


@pytest.mark.unit
@pytest.mark.parametrize('size', [24, 32, 40])
def test_printer_bands_reconstruct_native_rows_without_disk_layout_conversion(bitmap_library, size):
    pixels = pattern(size)
    bands = [0] if size == 24 else [1, 0]
    output = sum((render(bitmap_library, size, pixels, band=band) for band in bands), [])
    assert output[:size] == pixels
    assert not any(any(row) for row in output[size:])
    ascii_output = render(bitmap_library, size, pixels, code=0xaac1, band=bands[0])
    assert ascii_output == [row[:size // 2] for row in pixels[:24]]


@pytest.mark.unit
@pytest.mark.parametrize('attribute', [2, 4, 8, 16, 128, 32, 64, 8 | 128])
def test_read24_effects_use_glyph_coordinates(bitmap_library, attribute):
    pixels = pattern(24)
    expected = pixels
    if attribute & 8:
        expected = [list(row) for row in zip(*expected)][::-1]
    elif attribute & 16:
        expected = [list(row) for row in zip(*expected[::-1])]
    if attribute & 128:
        expected = [row[::-1] for row in expected[::-1]]
    if attribute & (32 | 64):
        compressed = [[a | b for a, b in zip(expected[y], expected[y + 1])]
                      for y in range(0, 24, 2)]
        blank = [[0] * 24 for _ in range(12)]
        expected = compressed + blank if attribute & 32 else blank + compressed
    if attribute & 2:
        expected[0] = [1] * 24
    if attribute & 4:
        expected[-1] = [1] * 24
    assert render(bitmap_library, 24, pixels, attributes=attribute) == expected


@pytest.mark.unit
def test_native_read24_ignores_printer_line_number(bitmap_library):
    pixels = pattern(24)
    assert render(bitmap_library, 24, pixels, band=1) == pixels


@pytest.fixture(scope='module')
def original_read24(assembler, source_dir, tmp_path_factory):
    directory = tmp_path_factory.mktemp('original-read24')
    source = (ROOT / 'qa/fixtures/legacy/READ24.ASM').read_bytes()
    exports = (b"DB 'HH24BASE'\r\nDW OFFSET INT_7B, OFFSET S_GET, OFFSET D_ZFK\r\n")
    source = source.replace(b'SEG_A\t\tENDS', exports + b'SEG_A\t\tENDS')
    assembly = directory / 'original.asm'
    output = directory / 'original.com'
    assembly.write_bytes(source)
    subprocess.run([assembler, '-q', '-Zm', '-bin', *asm_includes(source_dir),
                    '-Fo' + str(output), str(assembly)], check=True, capture_output=True)
    binary = output.read_bytes()
    return binary, struct.unpack_from('<3H', binary, binary.rindex(b'HH24BASE') + 8)


def run_original_read24(original, pixels, code, format, attributes, band):
    binary, (handler, storage, ascii_pointer) = original
    machine = Uc(UC_ARCH_X86, UC_MODE_16)
    machine.mem_map(0, 0x100000)
    machine.mem_write(0x10100, binary)
    columns = [[pixels[y][x] for y in range(24)] for x in range(24)]
    raw = b''.join(sum(bit << (23 - y) for y, bit in enumerate(column)).to_bytes(3, 'big')
                   for column in columns)
    machine.mem_write(0x1e000, raw)
    if code < 256:
        offset = struct.unpack('<H', machine.mem_read(0x10000 + ascii_pointer, 2))[0]
        machine.mem_write(0x10000 + offset + code * 36, raw[:36])
    registers = dict(CS=0x1000, DS=0x2000, ES=0x3000, SS=0x7000, SP=0xfe00,
                     AX=format << 8, BX=(band << 8) | attributes, DX=code,
                     DI=0x5555, BP=0x6666, EFLAGS=0x202)
    for name, value in registers.items():
        machine.reg_write(getattr(reg, 'UC_X86_REG_' + name), value)
    machine.mem_write(0x7fe00, struct.pack('<3H', 0xff00, 0x1000, 0x202))

    def cache_hit(uc, address, size, unused):
        if address != 0x10000 + storage:
            return
        # Replace only the file/cache boundary. Every transformation instruction
        # is executed from the original production binary unchanged.
        stack = uc.reg_read(reg.UC_X86_REG_SP)
        return_address = struct.unpack('<H', uc.mem_read(0x70000 + stack, 2))[0]
        uc.reg_write(reg.UC_X86_REG_SI, 0xe000)
        uc.reg_write(reg.UC_X86_REG_SP, stack + 2)
        uc.reg_write(reg.UC_X86_REG_IP, return_address)

    machine.hook_add(UC_HOOK_CODE, cache_hit)
    machine.emu_start(0x10000 + handler, 0x1ff00, count=100000)
    assert machine.reg_read(reg.UC_X86_REG_IP) == 0xff00
    assert machine.reg_read(reg.UC_X86_REG_ES) == registers['ES']
    assert machine.reg_read(reg.UC_X86_REG_DI) == registers['DI']
    width = machine.reg_read(reg.UC_X86_REG_CX)
    address = machine.reg_read(reg.UC_X86_REG_DS) * 16 + machine.reg_read(reg.UC_X86_REG_SI)
    return unpack_columns(machine.mem_read(address, width * 3), width)


@pytest.mark.unit
@pytest.mark.parametrize('format,band', [(0x40, 0), (0x50, 0), (0x60, 0), (0x70, 1),
    (0x10, 0), (0x11, 0), (0x12, 1), (0x12, 0), (0x13, 1), (0x13, 0)])
@pytest.mark.parametrize('attribute', [0, 2, 4, 6, 8, 16, 32, 64, 128, 8 | 128])
def test_read24_transforms_match_original_machine_code(bitmap_library, original_read24,
                                                       format, band, attribute):
    pixels = pattern(24)
    expected = run_original_read24(original_read24, pixels, 0xb0a1, format, attribute, band)
    assert render(bitmap_library, 24, pixels, attributes=attribute, band=band,
                  format=format) == expected


@pytest.mark.unit
@pytest.mark.parametrize('code', [0x41, 0xa1a1, 0xa9a1])
@pytest.mark.parametrize('attribute', [0, 2, 4, 8, 16, 32, 64])
def test_read24_ascii_and_symbol_rules_match_original(bitmap_library, original_read24, code, attribute):
    pixels = pattern(24)
    expected = run_original_read24(original_read24, pixels, code, 0x40, attribute, 0)
    assert render(bitmap_library, 24, pixels, code=code, attributes=attribute) == expected

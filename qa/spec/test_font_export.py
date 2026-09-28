"""Native source pixels, clipping rules and physical font-pack geometry."""
import importlib.util
import hashlib
import json
import struct

import pytest

from qa.spec.dos import ROOT

pytestmark = pytest.mark.unit


def test_distributed_pack_matches_provenance_and_binary_bounds():
    directory = ROOT/'fonts/large'
    manifest = json.loads((directory/'FONTS.json').read_text())
    assert len(manifest['fonts']) == 19
    assert {entry['file'] for entry in manifest['fonts']} == {
        path.name for path in directory.glob('*.FNT')}
    for entry in manifest['fonts']:
        data = (directory/entry['file']).read_bytes()
        assert hashlib.sha256(data).hexdigest() == entry['sha256']
        magic, width, height, slots, records, payload = struct.unpack_from('<8sHHHHI', data)
        assert magic == b'HHFONT2\n' and slots == 8434
        assert [width, height] == entry['cell']
        assert payload == entry['payload_bytes'] == len(data) - 32
        assert records == entry['records']
        assert max(struct.unpack_from('<16868H', data, 32)) < records
        record_bytes = (((2 * width + 7) // 8) * height + 1) & ~1
        assert len(data) == 32 + 33736 + records * record_bytes
        assert data[20:32] == bytes(12)
        assert (directory/entry['file']).with_suffix('.json').exists()
    for entry in manifest['licenses']:
        assert hashlib.sha256((directory/entry['file']).read_bytes()).hexdigest() == entry['sha256']


@pytest.fixture
def exporter():
    pytest.importorskip('freetype')
    pytest.importorskip('opencc')
    spec = importlib.util.spec_from_file_location('font_export', ROOT / 'tools/build-font.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def bitmap_font(tmp_path):
    # Deliberately asymmetric pixels expose centering, mirroring and bit order.
    glyphs = {
        'A': (8, [0, 0x18, 0x24, 0x42, 0x81, 0xFF, 0x81, 0x81] + [0] * 8),
        '中': (16, [0x0080, 0x0080, 0x7FFE, 0x4082, 0x4082, 0x7FFE,
                    0x0080, 0x0180, 0x4080, 0x0081] + [0] * 6),
        '─': (8, [0] * 7 + [0xFF] + [0] * 8),
    }
    lines = ['STARTFONT 2.1',
             'FONT -test-witness-medium-r-normal--16-160-72-72-c-80-iso10646-1',
             'SIZE 16 72 72', 'FONTBOUNDINGBOX 16 16 0 -4', 'STARTPROPERTIES 6',
             'FONT_ASCENT 12', 'FONT_DESCENT 4', 'PIXEL_SIZE 16',
             'CHARSET_REGISTRY "ISO10646"', 'CHARSET_ENCODING "1"',
             'FAMILY_NAME "Pixel witness"', 'ENDPROPERTIES', 'CHARS 3']
    for char, (width, rows) in glyphs.items():
        lines += [f'STARTCHAR U{ord(char):04X}', f'ENCODING {ord(char)}',
                  'SWIDTH 500 0', f'DWIDTH {width} 0', f'BBX {width} 16 0 -4',
                  'BITMAP', *(f'{row:0{width // 4}X}' for row in rows), 'ENDCHAR']
    path = tmp_path / 'witness.bdf'
    path.write_text('\n'.join(lines + ['ENDFONT']) + '\n')
    return path, glyphs


def test_native_pixels_are_centered_without_resampling(exporter, bitmap_font):
    path, glyphs = bitmap_font
    face = exporter.open_face(path, 0, 16)
    rows = exporter.raster(face, 'A', 12, 20, 14)
    assert rows == [0, 0] + [row << 2 for row in glyphs['A'][1]] + [0, 0]
    assert face.hh_source == 'bitmap'
    with pytest.raises(ValueError, match='no native 20-pixel strike'):
        exporter.open_face(path, 0, 20)
    with pytest.raises(ValueError, match=r'lacks U\+0042'):
        exporter.raster(face, 'B', 12, 20, 14)


def test_native_rule_meets_both_cell_edges(exporter, bitmap_font):
    face = exporter.open_face(bitmap_font[0], 0, 16)
    rows = exporter.raster(face, '─', 12, 20, 14, frame=True)
    assert rows == [0] * 9 + [0xFFF] + [0] * 10


def test_native_glyph_cannot_be_silently_clipped(exporter, bitmap_font):
    face = exporter.open_face(bitmap_font[0], 0, 16)
    with pytest.raises(ValueError, match='exceeds'):
        exporter.raster(face, '中', 8, 16, 12)


def test_non_unicode_source_cannot_silently_map_wrong_characters(exporter, bitmap_font):
    path, _ = bitmap_font
    path.write_text(path.read_text().replace('ISO10646', 'GB2312.1980'))
    with pytest.raises(ValueError, match='Unicode character map'):
        exporter.open_face(path, 0, 16)


def test_pack_grid_reserves_ime_row_and_rejects_short_cells(exporter):
    cells, unavailable = exporter.pack_cells(
        [(640, 480), (800, 600), (1366, 768), (1920, 1080)], [25, 43, 50])
    assert (8, 18) in cells
    assert cells[17, 29] == [dict(mode=[1366, 768], text=[80, 25])]
    assert (24, 21) in cells  # 50 text rows plus the input-method row.
    assert dict(mode=[800, 600], text=[80, 43]) in unavailable
    assert dict(mode=[1366, 768], text=[80, 50]) in unavailable
    for (width, height), layouts in cells.items():
        for layout in layouts:
            screen_width, screen_height = layout['mode']
            columns, rows = layout['text']
            assert columns * width <= screen_width
            assert (rows + 1) * height <= screen_height
            assert screen_width - columns * width < columns
            assert screen_height - (rows + 1) * height < rows + 1


def test_generated_hhfont2_maps_match_independent_source_pixels(exporter, bitmap_font,
                                                               monkeypatch):
    path, glyphs = bitmap_font
    charset = [('', False)] * 256 + [('', True)] * (87 * 94)
    chinese_slot = 256 + (0xD6 - 0xA1) * 94 + 0xD0 - 0xA1
    charset[65] = ('A', False)
    charset[chinese_slot] = ('中', True)
    monkeypatch.setattr(exporter, 'mapped_characters', lambda: tuple(charset * 2))
    cjk = exporter.FontFitter(path, 0, True)
    terminal = exporter.FontFitter(path, 0, False)
    assert exporter.fit_cell(cjk, terminal, 8, 18) == (16, 16, 13)
    face = exporter.open_face(path, 0, 16)
    data, count, baseline = exporter.build(face, face, 8, 18)
    magic, width, height, slots, records, length = struct.unpack_from('<8s4HI', data)
    assert (magic, width, height, slots, records, length) == (
        b'HHFONT2\n', 8, 18, 8434, 3, len(data) - 32)
    assert count == 3 and baseline == 13
    record_start = 32 + 8434 * 4
    for bank in (0, 8434):
        for slot, char, shift in [(65, 'A', 8), (chinese_slot, '中', 0)]:
            record = struct.unpack_from('<H', data, 32 + (bank + slot) * 2)[0]
            pixels = struct.unpack_from('>18H', data, record_start + record * 36)
            assert pixels == tuple([0] + [row << shift for row in glyphs[char][1]] + [0])
        blank = struct.unpack_from('<H', data, 32 + (bank + 66) * 2)[0]
        assert data[record_start + blank * 36:record_start + (blank + 1) * 36] == bytes(36)

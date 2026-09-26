#!/usr/bin/env python3
"""Build the HH Console 20 bitmap from explicitly supplied open source fonts.

Requires freetype-py and opencc-python-reimplemented. Font files are inputs,
never looked up through the host's font configuration. See fonts/README.md.
"""
import argparse
import gzip
import hashlib
import json
import struct
from pathlib import Path

import freetype
from opencc import OpenCC

SLOTS = 256 + 87 * 94
ROWS = 23
RECORD = 70
CONTROLS = '\0☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼'


def read_hex(path):
    """Read original Unifont pixels, without passing CJK through a rasterizer."""
    opener = gzip.open if path.suffix == '.gz' else open
    glyphs = {}
    with opener(path, 'rt', encoding='ascii') as source:
        for line in source:
            code, pixels = line.strip().split(':')
            code, pixels = int(code, 16), bytes.fromhex(pixels)
            if code in glyphs or len(pixels) not in (16, 32):
                raise ValueError(f'invalid or duplicate Unifont glyph U+{code:04X}')
            glyphs[code] = pixels
    return glyphs


def bitmap_rows(glyphs, char):
    pixels = glyphs.get(ord(char))
    if pixels is None:
        raise ValueError(f'Unifont lacks U+{ord(char):04X}')
    stride = len(pixels) // 16
    # Native 16-pixel body, ascent 14: align its baseline with Terminus at 16.
    # Center 8- or 16-pixel ink in the 20-pixel fullwidth slot; never resample.
    shift = (20 - stride * 8) // 2
    return [0, 0] + [int.from_bytes(pixels[y*stride:(y+1)*stride], 'big') << shift
                     for y in range(16)] + [0] * (ROWS - 18)


def raster(face, char, width, baseline):
    if not face.get_char_index(char):
        raise ValueError(f'{face.family_name!r} lacks U+{ord(char):04X}')
    face.load_char(char, freetype.FT_LOAD_RENDER | freetype.FT_LOAD_TARGET_MONO)
    glyph = face.glyph
    bitmap = glyph.bitmap
    assert bitmap.pixel_mode == freetype.FT_PIXEL_MODE_MONO
    # Keep the complete terminal bitmap in the cell without clipping strokes.
    advance = glyph.advance.x // 64
    left = max(0, min(glyph.bitmap_left + (width-advance)//2, width-bitmap.width))
    top = max(0, min(baseline-glyph.bitmap_top, ROWS-bitmap.rows))
    rows = [0] * ROWS
    pixels = bitmap.buffer
    for y in range(bitmap.rows):
        for x in range(bitmap.width):
            if pixels[y * bitmap.pitch + x // 8] & (128 >> (x % 8)):
                dx, dy = x + left, y + top
                if not (0 <= dx < width and 0 <= dy < ROWS):
                    raise ValueError(f'U+{ord(char):04X} overflows {width}x{ROWS}: {dx},{dy}')
                rows[dy] |= 1 << (width - 1 - dx)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cjk', type=Path, required=True, help='Unifont .hex or .hex.gz bitmap')
    parser.add_argument('--terminal', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('fonts/HH20.FNT'))
    args = parser.parse_args()
    cjk = read_hex(args.cjk)
    terminal = freetype.Face(str(args.terminal))
    terminal.set_pixel_sizes(0, 20)
    convert = OpenCC('s2t').convert
    records, ids, banks = [], {}, []

    def record(char, width):
        if not char or char == '\0':
            rows = [0] * ROWS
        elif width == 10 or (0x2500 <= ord(char) <= 0x259f and terminal.get_char_index(char)):
            rows = raster(terminal, char, 10, 16)
            if 0x2500 <= ord(char) <= 0x259f:
                # Terminal rules meet the next row; preserve shade periodicity.
                rows[20:] = [rows[18], rows[19], rows[18]]
            if width == 20:
                rows = [sum((3 << (18-2*x)) for x in range(10) if r & (512 >> x)) for r in rows]
        else:
            rows = bitmap_rows(cjk, char)
        data = b''.join((r << (24-width)).to_bytes(3, 'big') for r in rows) + b'\0'
        if data not in ids:
            ids[data] = len(records)
            records.append(data)
        return ids[data]

    for traditional in (False, True):
        bank = []
        for code in range(256):
            ch = CONTROLS[code] if code < 32 else ('⌂' if code == 127 else bytes([code]).decode('cp437'))
            bank.append(record(ch, 10))
        for lead in range(0xa1, 0xf8):
            for trail in range(0xa1, 0xff):
                try:
                    ch = bytes([lead, trail]).decode('gb2312')
                except UnicodeDecodeError:
                    ch = ''
                # Legacy font-bank semantics: one code selects one glyph.
                if ch and traditional:
                    ch = convert(ch)
                    if len(ch) != 1:
                        raise ValueError(f'non-character conversion for {lead:02x}{trail:02x}')
                bank.append(record(ch, 20))
        banks.extend(bank)
    payload = struct.pack(f'<{len(banks)}H', *banks) + b''.join(records)
    # Header is followed by two slot maps, then deduplicated 70-byte records.
    header = struct.pack('<8s4HI12x', b'HH20F01\n', 10, ROWS, SLOTS, len(records), len(payload))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(header + payload)
    metadata = dict(name='HH Console 20', format=1, cell=[10, ROWS],
                    cjk_bitmap=[16, 16], cjk_origin=[2, 2], terminal_bitmap=[10, 20],
                    records=len(records), payload_bytes=len(payload),
                    freetype='.'.join(map(str, freetype.version())),
                    inputs=[dict(file=p.name, sha256=hashlib.sha256(p.read_bytes()).hexdigest())
                            for p in (args.cjk, args.terminal)],
                    sha256=hashlib.sha256(header + payload).hexdigest())
    args.output.with_suffix('.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()

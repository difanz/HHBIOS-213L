#!/usr/bin/env python3
"""Export Linux bitmap or outline fonts to a variable-size HHBIOS font.

Inputs are explicit font files, including a face index for TTC collections.
FreeType uses native strikes when present, otherwise monochrome outlines.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

import freetype
from opencc import OpenCC

SLOTS = 256 + 87 * 94
CONTROLS = '\0☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼'


def open_face(path, index, size, width=None):
    face = freetype.Face(str(path), index=index)
    face.set_pixel_sizes(0, size)
    if width is not None and face.is_scalable:
        face.load_char('0', freetype.FT_LOAD_TARGET_MONO)
        advance = face.glyph.advance.x / 64
        face.set_pixel_sizes(round(size * width / advance), size)
    return face


def raster(face, char, width, height, baseline, frame=False):
    if not face.get_char_index(char):
        raise ValueError(f'{face.family_name!r} lacks U+{ord(char):04X} {char}')
    face.load_char(char, freetype.FT_LOAD_RENDER | freetype.FT_LOAD_TARGET_MONO)
    glyph = face.glyph
    bitmap = glyph.bitmap
    if bitmap.pixel_mode != freetype.FT_PIXEL_MODE_MONO:
        raise ValueError('Font must provide monochrome pixels')
    advance = round(glyph.advance.x / 64)
    left = glyph.bitmap_left + (width - advance) // 2
    top = baseline - glyph.bitmap_top
    pixels = bitmap.buffer
    rows = [0] * height
    for y in range(bitmap.rows):
        source_y = y if bitmap.pitch >= 0 else bitmap.rows - 1 - y
        for x in range(bitmap.width):
            if pixels[source_y * abs(bitmap.pitch) + x // 8] & (128 >> (x % 8)):
                dx, dy = x + left, y + top
                if not (0 <= dx < width and 0 <= dy < height):
                    if frame:
                        continue
                    raise ValueError(f'U+{ord(char):04X} {char} exceeds {width}x{height} at {dx},{dy}; '
                                     'increase the cell or adjust --baseline/--size')
                rows[dy] |= 1 << (width - 1 - dx)
    if frame and bitmap.rows:
        # Terminal rules and block edges meet the adjacent cell even when
        # line spacing is larger than the native bitmap strike.
        first = max(0, min(height - 1, top))
        last = max(0, min(height - 1, top + bitmap.rows - 1))
        rows[:first] = [rows[first]] * first
        rows[last + 1:] = [rows[last]] * (height - last - 1)
    return rows


def characters():
    convert = OpenCC('s2t').convert
    for traditional in (False, True):
        for code in range(256):
            char = CONTROLS[code] if code < 32 else ('⌂' if code == 127 else bytes([code]).decode('cp437'))
            yield char, False
        for lead in range(0xa1, 0xf8):
            for trail in range(0xa1, 0xff):
                try:
                    char = bytes([lead, trail]).decode('gb2312')
                except UnicodeDecodeError:
                    char = ''
                if traditional and char:
                    char = convert(char)
                    if len(char) != 1:
                        raise ValueError(f'Non-character conversion for {lead:02X}{trail:02X}')
                yield char, True


def build(cjk, terminal, width, height, baseline=None):
    charset = list(characters())
    if baseline is None:
        ascent, descent = 0, 0
        for char, fullwidth in sorted(set(charset)):
            if not char or char == '\0' or 0x2500 <= ord(char) <= 0x259f:
                continue
            face = cjk if fullwidth else terminal
            face.load_char(char, freetype.FT_LOAD_RENDER | freetype.FT_LOAD_TARGET_MONO)
            ascent = max(ascent, face.glyph.bitmap_top)
            descent = max(descent, face.glyph.bitmap.rows - face.glyph.bitmap_top)
        if ascent + descent > height:
            raise ValueError(f'Font needs a line height of at least {ascent + descent} pixels')
        baseline = ascent + (height - ascent - descent) // 2
    stride = (width * 2 + 7) // 8
    record_size = (stride * height + 1) & ~1
    records, indexes, slots = [], {}, []
    rendered = {}

    def record(char, fullwidth):
        key = char, fullwidth
        if key in rendered:
            return rendered[key]
        target_width = width * (2 if fullwidth else 1)
        frame = bool(char) and 0x2500 <= ord(char) <= 0x259f
        if not char or char == '\0':
            rows = [0] * height
        elif (frame and terminal.get_char_index(char)) or not fullwidth:
            rows = raster(terminal, char, width, height, baseline, frame)
            if fullwidth:
                rows = [sum(3 << (2 * x) for x in range(width) if row & (1 << x))
                        for row in rows]
        else:
            rows = raster(cjk, char, target_width, height, baseline, frame)
        packed = b''.join((row << (stride * 8 - target_width)).to_bytes(stride, 'big')
                          for row in rows)
        packed = packed.ljust(record_size, b'\0')
        if packed not in indexes:
            indexes[packed] = len(records)
            records.append(packed)
        rendered[key] = indexes[packed]
        return indexes[packed]

    for char, fullwidth in charset:
        slots.append(record(char, fullwidth))
    payload = struct.pack(f'<{len(slots)}H', *slots) + b''.join(records)
    header = struct.pack('<8s4HI12x', b'HHFONT2\n', width, height, SLOTS, len(records), len(payload))
    return header + payload, len(records), baseline


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cjk', type=Path, required=True)
    parser.add_argument('--cjk-index', type=int, default=0)
    parser.add_argument('--terminal', type=Path, required=True)
    parser.add_argument('--terminal-index', type=int, default=0)
    parser.add_argument('--size', type=int, required=True, help='Font pixel size, 16..48')
    parser.add_argument('--cell', required=True, help='Halfwidth cell dimensions, e.g. 16x38')
    parser.add_argument('--baseline', type=int, help='Baseline from the cell top')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        width, height = map(int, args.cell.lower().split('x'))
        if not (8 <= width <= 24 and 16 <= height <= 64 and 16 <= args.size <= 48):
            raise ValueError('Cell must be 8..24 by 16..64; font size must be 16..48')
        if args.baseline is not None and not 0 < args.baseline <= height:
            raise ValueError('Baseline must be inside the cell')
        cjk = open_face(args.cjk, args.cjk_index, args.size)
        terminal = open_face(args.terminal, args.terminal_index, args.size, width)
        data, records, baseline = build(cjk, terminal, width, height, args.baseline)
    except (ValueError, freetype.FT_Exception) as error:
        parser.error(str(error))
    metadata = dict(format=2, cell=[width, height], pixel_size=args.size, baseline=baseline,
                    records=records, payload_bytes=len(data) - 32,
                    freetype='.'.join(map(str, freetype.version())),
                    inputs=[dict(file=path.name, index=index, family=face.family_name.decode(),
                                 sha256=hashlib.sha256(path.read_bytes()).hexdigest())
                            for path, index, face in ((args.cjk, args.cjk_index, cjk),
                                                      (args.terminal, args.terminal_index, terminal))],
                    sha256=hashlib.sha256(data).hexdigest())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(data)
    args.output.with_suffix('.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
    print(f'{args.output}: {width}x{height}, {len(data)} bytes')


if __name__ == '__main__':
    main()

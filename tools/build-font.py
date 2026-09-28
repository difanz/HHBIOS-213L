#!/usr/bin/env python3
"""Export Linux bitmap or outline fonts to a variable-size HHBIOS font.

Inputs are explicit font files, including a face index for TTC collections.
FreeType uses native strikes when present, otherwise monochrome outlines.
"""
import argparse
from functools import lru_cache
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
    try:
        face.select_charmap(freetype.FT_ENCODING_UNICODE)
    except freetype.FT_Exception:
        raise ValueError(f'{path.name} needs a Unicode character map') from None
    strikes = [i for i, strike in enumerate(face.available_sizes)
               if strike.y_ppem == size * 64]
    if strikes:
        face.select_size(strikes[0])
        face.hh_source = 'bitmap'
    elif face.is_scalable:
        face.set_pixel_sizes(0, size)
        face.hh_source = 'outline'
    else:
        raise ValueError(f'{face.family_name!r} has no native {size}-pixel strike')
    face.hh_size = size
    face.hh_flags = (freetype.FT_LOAD_RENDER | freetype.FT_LOAD_TARGET_MONO |
                     (freetype.FT_LOAD_SBITS_ONLY if face.hh_source == 'bitmap'
                      else freetype.FT_LOAD_NO_BITMAP))
    if width is not None and face.hh_source == 'outline':
        face.load_char('0', face.hh_flags)
        advance = face.glyph.advance.x / 64
        face.set_pixel_sizes(round(size * width / advance), size)
        face.hh_source = 'outline'
        face.hh_flags = (freetype.FT_LOAD_RENDER | freetype.FT_LOAD_TARGET_MONO |
                         freetype.FT_LOAD_NO_BITMAP)
    return face


def raster(face, char, width, height, baseline, frame=False):
    if not face.get_char_index(char):
        raise ValueError(f'{face.family_name!r} lacks U+{ord(char):04X} {char}')
    face.load_char(char, face.hh_flags)
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
        # A native terminal strike can be narrower than the selected cell.
        # Extend only strokes touching its edges; do not resample the glyph.
        first_x = max(0, min(width - 1, left))
        last_x = max(0, min(width - 1, left + bitmap.width - 1))
        for y, row in enumerate(rows):
            if row & (1 << (width - 1 - first_x)):
                rows[y] |= ((1 << first_x) - 1) << (width - first_x)
            if row & (1 << (width - 1 - last_x)):
                rows[y] |= (1 << (width - last_x - 1)) - 1
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


@lru_cache(maxsize=1)
def mapped_characters():
    return tuple(characters())


def build(cjk, terminal, width, height, baseline=None):
    charset = mapped_characters()
    if baseline is None:
        ascent, descent = 0, 0
        for char, fullwidth in sorted(set(charset)):
            if not char or char == '\0' or 0x2500 <= ord(char) <= 0x259f:
                continue
            face = cjk if fullwidth else terminal
            face.load_char(char, face.hh_flags)
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


def font_copyright(face):
    notices = []
    for index in range(face.sfnt_name_count):
        name = face.get_sfnt_name(index)
        if name.name_id == 0:
            encoding = 'utf-16-be' if name.platform_id in (0, 3) else 'mac_roman'
            notice = name.string.decode(encoding)
            if notice not in notices:
                notices.append(notice)
    return notices


def font_metadata(data, records, baseline, width, height, sources):
    return dict(format=2, cell=[width, height], baseline=baseline,
                records=records, payload_bytes=len(data) - 32,
                freetype='.'.join(map(str, freetype.version())),
                inputs=[dict(file=path.name, index=index,
                             family=face.family_name.decode(),
                             source=face.hh_source, pixel_size=face.hh_size,
                             copyright=font_copyright(face),
                             sha256=hashlib.sha256(path.read_bytes()).hexdigest())
                        for path, index, face in sources],
                sha256=hashlib.sha256(data).hexdigest())


def write_font(path, data, metadata):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    path.with_suffix('.json').write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
    print(f'{path}: {metadata["cell"][0]}x{metadata["cell"][1]}, {len(data)} bytes',
          flush=True)


def pack_cells(modes, rows):
    """One exact grid cell per physical mode/layout, including the IME row."""
    cells = {}
    unavailable = []
    for width, height in modes:
        for count in rows:
            cell = min(width // 80, 24), min(height // (count + 1), 64)
            layout = dict(mode=[width, height], text=[80, count])
            if cell[0] < 8 or cell[1] < 16:
                unavailable.append(layout)
                continue
            cells.setdefault(cell, []).append(layout)
    return cells, unavailable


class FontFitter:
    """Measure real glyphs, preserving aspect ratio and native bitmap pixels."""
    def __init__(self, path, index, fullwidth):
        self.path, self.index = path, index
        self.fullwidth = fullwidth
        self.face = freetype.Face(str(path), index=index)
        self.characters = sorted({char for char, full in mapped_characters()
                                  if char and char != '\0' and full == fullwidth
                                  and not 0x2500 <= ord(char) <= 0x259f})
        self.metrics = {}

    def sizes(self, maximum):
        if self.face.is_scalable:
            return range(maximum, 7, -1)
        return sorted({strike.y_ppem // 64 for strike in self.face.available_sizes
                       if 8 <= strike.y_ppem // 64 <= maximum}, reverse=True)

    def measure(self, size, width):
        if size not in self.metrics:
            face = open_face(self.path, self.index, size)
            ascent, descent, bounds = 0, 0, []
            for char in self.characters:
                if not face.get_char_index(char):
                    raise ValueError(f'{face.family_name!r} lacks U+{ord(char):04X} {char}')
                face.load_char(char, face.hh_flags)
                glyph = face.glyph
                ascent = max(ascent, glyph.bitmap_top)
                descent = max(descent, glyph.bitmap.rows - glyph.bitmap_top)
                if glyph.bitmap.width:
                    bounds.append((glyph.bitmap_left, glyph.bitmap.width,
                                   round(glyph.advance.x / 64)))
            self.metrics[size] = ascent, descent, bounds
        ascent, descent, bounds = self.metrics[size]
        for left, ink_width, advance in bounds:
            left += (width - advance) // 2
            if left < 0 or left + ink_width > width:
                return None
        return ascent, descent


def fit_cell(cjk, terminal, width, height):
    # Pick the largest complete CJK body first. The terminal strike may be
    # smaller, but shares its baseline; neither source is stretched to fit.
    for cjk_size in cjk.sizes(min(width * 2, height, 48)):
        chinese = cjk.measure(cjk_size, width * 2)
        if not chinese or sum(chinese) > height:
            continue
        for terminal_size in terminal.sizes(min(width * 2, height, 48)):
            western = terminal.measure(terminal_size, width)
            if not western:
                continue
            ascent = max(chinese[0], western[0])
            descent = max(chinese[1], western[1])
            if ascent + descent <= height:
                baseline = ascent + (height - ascent - descent) // 2
                return cjk_size, terminal_size, baseline
    raise ValueError(f'The supplied fonts have no complete glyph set fitting {width}x{height}')


def build_pack(args):
    modes = args.mode or ['640x480', '800x600', '1024x768', '1280x720',
                          '1280x800', '1280x1024', '1366x768', '1920x1080']
    modes = [parse_pair(value) for value in modes]
    rows = args.rows or [25, 43, 50]
    licenses = {}
    for path in args.license or []:
        if path.name in licenses:
            raise ValueError(f'Duplicate license filename: {path.name}')
        licenses[path.name] = path.read_bytes()
    cells, unavailable = pack_cells(modes, rows)
    printers = {(size // 2, size): size for size in (24, 32, 40)}
    cjk = FontFitter(args.cjk, args.cjk_index, True)
    terminal = FontFitter(args.terminal, args.terminal_index, False)
    entries = []
    for width, height in sorted(set(cells) | set(printers)):
        cjk_size, terminal_size, baseline = fit_cell(cjk, terminal, width, height)
        faces = (open_face(args.cjk, args.cjk_index, cjk_size),
                 open_face(args.terminal, args.terminal_index, terminal_size))
        data, records, baseline = build(*faces, width, height, baseline)
        metadata = font_metadata(data, records, baseline, width, height,
                                 ((args.cjk, args.cjk_index, faces[0]),
                                  (args.terminal, args.terminal_index, faces[1])))
        metadata['aspect'] = 'native'
        if (width, height) in cells:
            name = f'F{width:02d}{height:02d}.FNT'
            metadata['layouts'] = cells[width, height]
            write_font(args.pack / name, data, metadata)
            entries.append(dict(file=name, **metadata))
        if (width, height) in printers:
            name = f'HH{printers[width, height]}.FNT'
            print_metadata = dict(metadata, purpose='printing')
            print_metadata.pop('layouts', None)
            write_font(args.pack / name, data, print_metadata)
            entries.append(dict(file=name, **print_metadata))
    args.pack.mkdir(parents=True, exist_ok=True)
    (args.pack / 'FONTS.json').write_text(json.dumps(
        dict(name='HH Console Pack', format=2, fonts=entries,
             unavailable_layouts=unavailable,
             licenses=[dict(file=name, sha256=hashlib.sha256(data).hexdigest())
                       for name, data in licenses.items()]),
        ensure_ascii=False, indent=2) + '\n')
    for name, data in licenses.items():
        (args.pack / name).write_bytes(data)
    notices = sorted({notice for entry in entries for source in entry['inputs']
                      for notice in source['copyright']})
    (args.pack / 'NOTICE.txt').write_text('HH Console Pack\n\n' + '\n\n'.join(notices) + '\n')


def parse_pair(value):
    try:
        first, second = map(int, value.lower().split('x'))
    except ValueError:
        raise ValueError(f'Expected WIDTHxHEIGHT, got {value!r}') from None
    if first <= 0 or second <= 0:
        raise ValueError('Dimensions must be positive')
    return first, second


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cjk', type=Path, required=True)
    parser.add_argument('--cjk-index', type=int, default=0)
    parser.add_argument('--terminal', type=Path, required=True)
    parser.add_argument('--terminal-index', type=int, default=0)
    parser.add_argument('--size', type=int, help='Font pixel size, 16..48')
    parser.add_argument('--cell', help='Halfwidth cell dimensions, e.g. 16x38')
    parser.add_argument('--baseline', type=int, help='Baseline from the cell top')
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument('--output', type=Path)
    destination.add_argument('--pack', type=Path, help='Create console and printing fonts in this directory')
    parser.add_argument('--mode', action='append', help='Pack physical mode, e.g. 1366x768; repeat to combine')
    parser.add_argument('--rows', action='append', type=int, choices=(25, 43, 50), help='Pack text rows')
    parser.add_argument('--license', type=Path, action='append', help='Copy a source-font license into the pack')
    args = parser.parse_args()
    try:
        if args.pack:
            if args.size or args.cell or args.baseline is not None:
                raise ValueError('--pack chooses font sizes and baselines from the target layouts')
            build_pack(args)
            return
        if args.mode or args.rows or args.license or args.size is None or args.cell is None:
            raise ValueError('Single output needs --size/--cell; --mode/--rows/--license require --pack')
        width, height = parse_pair(args.cell)
        if not (8 <= width <= 24 and 16 <= height <= 64 and 16 <= args.size <= 48):
            raise ValueError('Cell must be 8..24 by 16..64; font size must be 16..48')
        if args.baseline is not None and not 0 < args.baseline <= height:
            raise ValueError('Baseline must be inside the cell')
        cjk = open_face(args.cjk, args.cjk_index, args.size)
        terminal = open_face(args.terminal, args.terminal_index, args.size, width)
        data, records, baseline = build(cjk, terminal, width, height, args.baseline)
    except (OSError, ValueError, freetype.FT_Exception) as error:
        parser.error(str(error))
    metadata = font_metadata(data, records, baseline, width, height,
                             ((args.cjk, args.cjk_index, cjk),
                              (args.terminal, args.terminal_index, terminal)))
    metadata['pixel_size'] = args.size
    write_font(args.output, data, metadata)


if __name__ == '__main__':
    main()

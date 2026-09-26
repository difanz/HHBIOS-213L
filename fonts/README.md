# HH Console 20

`HH20.FNT` supplies the VESA console with native 20-pixel Chinese and 10x20
Western glyphs, in 10x23 cells. The 80x25 text area occupies 800x575 pixels;
the input-method row occupies y=575..597. Frame strokes extend through the
row spacing so adjacent boxes join. This is a monochrome font for the
16-color renderer; no antialiasing or runtime font rasterizer is needed.

Chinese glyphs come from **Noto Sans Mono CJK SC Regular 2.004**, rasterized
with FreeType's monochrome hinting at 20 pixels. Western CP437 glyphs and
available box-drawing characters come from **Terminus Font 10x20**, using
its original bitmap strike. GB2312 box characters available in Terminus
use the same strokes, with doubled horizontal pixels. Other CJK glyphs
come directly from Noto outlines. Proportional symbols are centered in their
fullwidth GB2312 slots. Accents are positioned inside the cell
without clipping or shrinking their bitmap.

Both fonts use [SIL OFL 1.1](OFL.txt). Redistribute that file with HH20.FNT.
Upstreams: [Noto CJK](https://github.com/notofonts/noto-cjk),
[Terminus Font](https://terminus-font.sourceforge.net/).
The bitmap is named **HH Console 20** to distinguish this derivative from
the upstream fonts. Original source-file hashes and output hash are in
[HH20.json](HH20.json).

## Rebuilding

The binary font is checked in; ordinary builds and DOS installations do not
need Python font libraries or host-installed fonts. To regenerate it, install
the optional dependencies from `tools/font-requirements.txt`, obtain the
upstream fonts (Linux packages `fonts-noto-cjk` and `fonts-terminus-otb` are
one source), and pass their paths explicitly:

```sh
python tools/build-font20.py --cjk /path/to/NotoSansCJK-Regular.ttc \
    --face 7 --terminal /path/to/terminus-normal.otb --output fonts/HH20.FNT
```

Face 7 is the SC monospace face in the regular Noto collection. FreeType
2.13.2 produced the committed output; other rasterizer/font versions can
change pixels. The generator records its inputs and rejects missing or
oversized glyphs. It never substitutes a font from the host's font search.

The traditional bank uses OpenCC's `s2t` single-character conversion,
matching the legacy one-GB2312-code/one-glyph bank interface. This is not
phrase-aware text conversion. The conversion dictionary comes from
[OpenCC](https://github.com/BYVoid/OpenCC) through
[opencc-python](https://github.com/yichen0831/opencc-python), under Apache 2.0;
see [OpenCC-LICENSE.txt](OpenCC-LICENSE.txt).

## Storage format

All header/map integers are little-endian. The 32-byte header is:

| Offset | Size | Value |
| --- | --- | --- |
| 0 | 8 | ASCII `HH20F01` followed by LF |
| 8 | 2 | Cell width, 10 |
| 10 | 2 | Cell height, 23 |
| 12 | 2 | Slots per bank, 8434 |
| 14 | 2 | Number of distinct glyph records |
| 16 | 4 | Payload length, excluding header |
| 20 | 12 | Reserved, zero |

The payload starts with simplified and traditional slot maps, 8434 uint16
record indexes each. Slots 0..255 are IBM CP437, including graphical control
characters; the remaining slots are GB2312 A1A1..F7FE, 94 columns per row.
Unassigned positions map to a blank glyph. Each shared record is 70 bytes:
23 rows of 3 bytes, most significant pixel first, plus one zero pad byte for
even-length XMS moves. Chinese occupies the first 20 bits; Western occupies
the first 10 bits. Identical records, including blanks and unchanged
traditional forms, share one index.

The committed payload is 733106 bytes: 716 KiB of XMS allocation, or 45 EMS
pages (720 KiB). The 16-entry resident cache uses 1120 bytes of glyph data
plus keys and validity words. No DOS or file calls occur while drawing.

`HZK16` remains the original 16-pixel font used by the legacy drivers and
the compatible INT 10h/AH=16h bitmap query. It is not the source of HH20.FNT.

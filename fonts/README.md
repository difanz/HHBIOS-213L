# HH Console 20

`HH20.FNT` supplies the VESA console with native 16x16 Chinese and 10x20
Western bitmaps, in 10x23 cells. The 80x25 text area occupies 800x575 pixels;
the input-method row occupies y=575..597. Frame strokes extend through the
row spacing so adjacent boxes join. This is a monochrome font for the
16-color renderer; no antialiasing or runtime font rasterizer is needed.

Chinese glyphs come from **GNU Unifont 18.0.01**, using the original HEX
bitmaps. A 16x16 glyph is placed at (2,2) inside its 20x23 fullwidth slot;
its strokes are neither rasterized from outlines nor stretched to 20 pixels.
The baseline is aligned with the Western font. Western CP437 glyphs and
available box-drawing characters come from **Terminus Font 10x20**, using
its original bitmap strike. GB2312 box characters available in Terminus
use the same strokes, with doubled horizontal pixels. Unifont's narrow
symbols are centered without scaling in their fullwidth GB2312 slots.
The filename and format retain the 20-pixel fullwidth slot; this does not
mean that the Chinese source has a native 20-pixel strike.

Both fonts use [SIL OFL 1.1](OFL.txt). Redistribute that file with HH20.FNT.
Unifont's dual license is used under its OFL option.
Upstreams: [GNU Unifont](https://unifoundry.com/unifont/index.html),
[Terminus Font](https://terminus-font.sourceforge.net/).
The bitmap is named **HH Console 20** to distinguish this derivative from
the upstream fonts. Original source-file hashes and output hash are in
[HH20.json](HH20.json).

## Rebuilding

The binary font is checked in; ordinary builds and DOS installations do not
need Python font libraries or host-installed fonts. To regenerate it, install
the optional dependencies from `tools/font-requirements.txt`, obtain the
upstream [Unifont HEX bitmap](https://unifoundry.com/pub/unifont/unifont-18.0.01/font-builds/unifont-18.0.01.hex.gz)
and Terminus OTB (`fonts-terminus-otb` on Debian/Ubuntu), and pass their paths
explicitly:

```sh
python tools/build-font20.py --cjk /path/to/unifont-18.0.01.hex.gz \
    --terminal /path/to/terminus-normal.otb --output fonts/HH20.FNT
```

FreeType 2.13.2 reads the Terminus bitmap strike in the committed build.
Chinese pixels are copied directly from HEX; FreeType is not involved.
The generator records its inputs and rejects missing, malformed or oversized
glyphs. It never substitutes a font from the host's font search.

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

The committed font payload is 733176 bytes, rounded to 716 KiB. VESA reserves
another 32 KiB in the same handle for text-page preservation during row changes:
748 KiB in XMS, or 47 EMS pages (752 KiB). The 16-entry resident cache uses 1120 bytes of glyph data
plus keys and validity words. No DOS or file calls occur while drawing.

`HZK16` remains the original 16-pixel font used by the legacy drivers and
the compatible INT 10h/AH=16h bitmap query. It is not the source of HH20.FNT.

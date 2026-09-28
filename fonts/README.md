# Console fonts

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
another 36 KiB in the same handle for text-page and downloaded-font preservation:
752 KiB in XMS, or 47 EMS pages. The 2176-byte cache holds a 128-byte record-map
page and 29 HH20 glyphs, plus separate keys and reference flags. No DOS or file
calls occur while drawing.

`HZK16` remains the original 16-pixel font used by the legacy drivers and
the compatible INT 10h/AH=16h bitmap query. It is not the source of HH20.FNT.

## Variable sizes from Linux fonts

`F0818.FNT` and `F1229.FNT` use the original ISAS Song bitmap strikes:
`gb16st` (16x16) and `gb24st` (24x24), respectively. Their pixels are copied
without resizing into 8x18 and 12x29 halfwidth cells. These X11 fonts are
distributed by [X.Org font-isas-misc](https://www.x.org/releases/individual/font/)
and included in Debian/Ubuntu's `xfonts-base`. BDF source and compiled PCF
files are both accepted. See [the ISAS license](large/ISAS.txt).

The exporter translates Unicode characters to the font's declared
GB2312.1980-0 row/cell codes. It does not treat those codes as Unicode.
ISAS does not cover every traditional character: these two files explicitly
use Unifont 16 and Noto Sans CJK SC 24, respectively, for missing characters.
Terminus supplies the Western characters. Input hashes, font sizes and the
fallback sources are recorded in each file's JSON metadata.

For example, to rebuild the 24-pixel face:

```sh
python tools/build-font.py --cjk /path/to/gb24st.pcf.gz \
    --cjk-fallback /path/to/NotoSansCJK-Regular.ttc --cjk-fallback-index 2 \
    --terminal /path/to/terminus-normal.otb --size 24 --cell 12x29 \
    --output F1229.FNT
```

Use `gb16st`, an uncompressed Unifont BDF fallback, size 16 and cell 8x18
for `F0818.FNT`. Fonts and licenses are packaged with the distribution;
DOS does not need an installed Linux font system.

VESA selects a font from `HH20.FNT` and `F????.FNT` in the current DOS
directory to fit the physical mode and text layout. `VESA /F:file` selects
one explicit font instead.
`tools/build-font.py` exports an explicitly selected TTF, OTF, TTC face or
bitmap strike at the requested pixel size. It uses FreeType's monochrome
renderer; DOS loads the resulting bitmaps into XMS/EMS and does no outline
rasterization. Bitmap fonts must contain the requested native strike.

For example, Noto Sans CJK SC and Terminus at 32 pixels fit an 80x25 console
plus its IME row in 1280x1024, using 16x39 halfwidth cells:

```sh
python tools/build-font.py \
    --cjk /path/to/NotoSansCJK-Regular.ttc --cjk-index 2 \
    --terminal /path/to/terminus-normal.otb \
    --size 32 --cell 16x39 --output DISPLAY.FNT
```

The TTC face index depends on the supplied collection. The JSON sidecar
records the selected family, index, input hashes, geometry and output hash.
Copy `DISPLAY.FNT` to DOS and select it with `VESA /M:106 /F:DISPLAY.FNT`.
The font must fit all 80 columns and 26 rows, including the IME. A mode too
small for the selected font is rejected before installation. Changing the
font file/size requires a clean DOS session; `/F` does not reload a resident
driver. SETUP uses the same font headers and selection rules when checking
the available text layouts and extended-memory requirements.

Halfwidth cells may be 8..24 pixels wide and 16..64 pixels high; Chinese
occupies two cells. `--size` selects the source font's pixel size; `--cell`
sets the grid and line spacing. The default baseline fits all mapped glyphs
without clipping; `--baseline` overrides it. Missing or overflowing glyphs
are errors. No host font fallback silently substitutes a different family.
Terminal box rules extend to cell edges. Larger physical modes may enlarge
the complete cell by an integer factor, without changing the B800 layout.

Use font files under an appropriate redistribution license and include their
license when distributing generated data. The exporter does not bundle or
download fonts. The existing Unifont/Terminus HH20 pixels are unchanged.
FreeType's [glyph loading](https://freetype.org/freetype2/docs/reference/ft2-glyph_retrieval.html)
and [sizing](https://freetype.org/freetype2/docs/reference/ft2-sizing_and_scaling.html)
interfaces define the bitmap/outline selection and monochrome rendering.

Version 2 has the same 32-byte header and two GB2312/CP437 slot maps as above,
with signature `HHFONT2` followed by LF. Width and height contain the chosen
halfwidth dimensions; bytes 20..31 remain zero. A record has
`ceil(2 * width / 8)` bytes per row, MSB first, padded to an even total size.
Western characters occupy the left half of the record. Record size follows
the header geometry; it is not fixed at 70 bytes. The loader validates the
dimensions and exact payload length before allocating memory.

The resident packed-glyph cache occupies 2176 bytes and holds up to 60
records (five at the maximum 48x64 fullwidth size). Larger Western records
whose second cell is empty use halfwidth storage; drawing reads those rows
directly. Chinese and application-defined bitmaps retain their complete data.
The complete font and
the additional 36 KiB text/font backup remain in XMS or EMS.

## Font packs for different screen sizes

The generated pack in [large/](large/) is included with the source tree;
ordinary builds do not need host fonts or Python font libraries.

`--pack` creates ordinary HHFONT2 files for a set of physical resolutions
and 80-column text layouts. Each `Fwwhh.FNT` filename contains its halfwidth
cell width and height. VESA reads the actual dimensions from the font header.
Copy these files beside `VESA.COM` and `SETUP.EXE`; the generated startup
batch changes to that directory. The driver chooses the
largest covered screen area, preferring native pixels over integer enlargement
when the coverage is equal. With matching 10x23 cells, it retains the bundled
HH20 fast path. Fonts for text-row switches are loaded before the driver
becomes resident; switching rows does not read font files through DOS.
The pack also contains `HH24.FNT`, `HH32.FNT` and `HH40.FNT`, with 12x24,
16x32 and 20x40 cells for the corresponding printing readers.

This example converts Noto Sans CJK SC outlines to monochrome pixels on the
host and uses the native Terminus bitmap strikes for Western characters:

```sh
python tools/build-font.py \
    --cjk /path/to/NotoSansCJK-Regular.ttc --cjk-index 2 \
    --terminal /path/to/terminus-normal.otb \
    --license fonts/OFL.txt --license fonts/OpenCC-LICENSE.txt \
    --pack build/fonts
```

Both inputs use SIL OFL 1.1. Source projects and licensing:
[Noto CJK](https://github.com/notofonts/noto-cjk),
[Noto Sans license](https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE),
[Terminus](https://terminus-font.sourceforge.net/).
The output is named **HH Console Pack**. Redistribute its `OFL.txt`,
`OpenCC-LICENSE.txt`, `NOTICE.txt` and JSON metadata with the font files.
The generator copies the
explicitly supplied license and extracts copyright notices from the sources.
Additional `--license` arguments can include notices for other source fonts.

The largest complete glyph set that fits each cell is selected from the
supplied faces. Chinese and Western glyphs retain their aspect ratios and
share a baseline. Native bitmap pixels are centered without resampling;
outlines are rasterized at their recorded pixel sizes. Terminal frame strokes
extend to cell edges so boxes remain connected. Unsupported characters,
missing native strikes and glyph clipping are errors. Inputs must provide a
Unicode character map; host font search is never used.

By default the following cell sizes are generated. The height calculation
reserves one additional row for the input-method status line:

| Physical mode | 80x25 | 80x43 | 80x50 |
| --- | --- | --- | --- |
| 640x480 | 8x18 | — | — |
| 800x600 | 10x23 | — | — |
| 1024x768 | 12x29 | 12x17 | — |
| 1280x720 | 16x27 | 16x16 | — |
| 1280x800 | 16x30 | 16x18 | — |
| 1280x1024 | 16x39 | 16x23 | 16x20 |
| 1366x768 | 17x29 | 17x17 | — |
| 1920x1080 | 24x41 | 24x24 | 24x21 |

A dash means that the layout needs cells shorter than HHFONT2's 16-pixel
minimum. Physical modes remain subject to the video driver's capabilities.
Repeat `--mode WIDTHxHEIGHT` and `--rows 25`, `--rows 43` or `--rows 50` to
generate a smaller or different set. The cell dimensions are
`floor(width / 80)` and `floor(height / (rows + 1))`, bounded by the format's
24x64 maximum. Identical geometries share one file. Each sidecar records
source hashes, face indexes, native-bitmap or outline origin, source pixel
sizes, baseline and output hash; `FONTS.json` lists the pack and its layouts.
Existing `HH20.FNT` and `HZK16` are unchanged.

## Printing fonts

`READ24.COM`, `READ32.COM` and `READ40.COM` read HHFONT2 directly. Their
default files are `HH24.FNT`, `HH32.FNT` and `HH40.FNT` beside the reader.
For example:

```dos
READ32 /F:HH32.FNT /X
```

`/X` selects XMS, `/E` selects EMS, and omitting both tries XMS then EMS.
`/N` keeps the small resident program in conventional memory; the complete
font still uses extended memory. `/F1:`, `/F2:` and `/F3:` select additional
actual font files for the printer's style positions. Unspecified positions
share the default face. The readers load these files before becoming
resident, and service printing requests without DOS file reads. They do not
read the old headerless HZK24/32/40 files. `READ16` and vector `READSL` retain
their existing separate font interfaces.

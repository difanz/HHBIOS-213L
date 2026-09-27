# Existing text modes on a high-resolution graphics backend

The compatibility target is the text interface that DOS programs already use.
Pixel resolution, font strike and integer enlargement are backend choices.
Increasing the framebuffer size must not invent a new application-visible mode
or force a program to accept more columns.

The resident VESA driver supports standard VGA ROM-font row changes, including
80x43 and 80x50, with B800, BIOS, keyboard and mouse using the same geometry.
`/M:hex` independently selects the preferred physical surface. Bank-spanning
stores and integer bitmap enlargement preserve complete glyphs. Direct-memory
programs do not need to change their ordinary BIOS/B800 interface.
The legacy display drivers remain 80x25. Wider resident grids and virtual VBE
108h..10Ch text-mode enumeration are not implemented yet.
The [wide framebuffer experiments](WIDE-RENDERING.md) exercise larger bitmap
grids, integer enlargement, bank crossings and several pixel formats in a
foreground DOS program. They also extend the native mouse/page observations.

## Resident VGA row selection

`AH=12h, BL=30h` selects the logical scanline count; mode 03h and
`AX=1112h` select the usual 350/8 (43-row) or 400/8 (50-row) layout.
ROM 14/16-line selections work as well; the transition test includes 80x28.
BIOS font queries return logical character height, independent of physical
glyph enlargement. More than 25 rows uses four 8 KiB text pages. Full 32 KiB
preservation during font changes uses external XMS/EMS backup, including inactive
pages and padding.

The current native 10x20 glyph cells plus prompt row need at least 880 pixels
for 43 rows and 1020 for 50 rows. Extra spacing is used where it fits. If the
preferred surface is too short, the driver tries BIOS modes 104h and 106h;
it retains the previous grid if no suitable surface is available. No custom
mode number is substituted for an application's VGA row-selection sequence.

`test_resident_text.py` checks row/page/font agreement, text preservation and
all four graphics planes, plus real mouse movement, press/release callbacks,
cursor masks/shapes and exclusion areas after VBE state restoration.
`test_vesa_application.py -k 50_row` runs TVEDIT and EDIT 2 with Chinese below
row 25 and checks Delete/Backspace results in both screen rows and saved files.
These are separate from the native BIOS observations below.

## Mode families

Start with the following existing interfaces, not a special 132x50-only API:

| Application-visible grid | Existing selection interface |
| --- | --- |
| 80x25 | BIOS mode 03h |
| 80x43 | EGA/VGA 350 scanlines, mode 03h, ROM 8x8 font |
| 80x50 | VGA 400 scanlines, mode 03h, ROM 8x8 font |
| 80x60 | VBE 108h |
| 132x25 | VBE 109h |
| 132x43 | VBE 10Ah |
| 132x50 | VBE 10Bh |
| 132x60 | VBE 10Ch |

The VBE mode numbers are the historical assignments in the
[VBE 2.0 specification, section 2](https://www.phatcode.net/res/221/files/vbe20.pdf).
Native availability must be discovered. Other vendor text modes can be added
after identifying their BIOS interface and applications that actually use them;
100-, 160- or wider-column layouts must not be advertised as invented VBE
standard modes. The internal geometry descriptor should not assume either
80 or 132 columns.

## Native observations

`qa/harness/textmode.c` queries the BIOS mode list and records the complete raw
controller/mode blocks. Its mode setter records AH=0Fh, 4F03h and the BIOS data
area (BDA), draws a boundary in B800, and requests an actual SDL screenshot.
It does not install a Chinese driver or change the emulator implementation.

Both tested S3 BIOS implementations advertise planar 800x600, 1024x768 and
1280x1024 graphics. Their text support differs:

| Native probe | DOSBox-X | Classic DOSBox |
| --- | --- | --- |
| BIOS 80x25/43/50 | All three observed | All three observed |
| VBE 108h..10Ch | All five observed | All five rejected, AX=014Fh; absent from list |

In DOSBox-X the corresponding AH=0Fh mode bytes are 70h..74h. These are BIOS
observations, not a portable definition of the VBE mode numbers. Its reported
page sizes are 8 KiB for 132x25 and 16 KiB for the other VBE text grids. The two
emulators also report different page sizes for 80x43/50. Do not infer page
stride solely from visible cells or copy an emulator's quirk without testing
page isolation.

`gridcap.c` launches a real application under an INT 1Ch observer. After the
fixture appears, it records BDA and visible B800 words, requests a screenshot,
then sends physical exit keys. File writes happen after the application exits.
These observations used default application settings in fresh directories:

| Initial native grid | Turbo Vision TVEDIT r415 | MS-DOS EDIT 2.0.026 | Turbo C 2.01 |
| --- | --- | --- | --- |
| 80x50 | 80x50 | 80x50 | 80x25 |
| 80x60 | 80x60 | 80x50 | 80x25 |
| 132x25 | 132x25 | 80x25 | 80x25 |
| 132x43 | 132x43 | 80x50 | 80x25 |
| 132x50 | 132x50 | 80x50 | 80x25 |
| 132x60 | 132x60 | 80x50 | 80x25 |

TVEDIT uses the extra screen area. EDIT and Turbo C select narrower modes on
entry; this must remain possible. The table measures startup behavior, not the
maximum configurable capability of each application, all Turbo Vision versions,
or Chinese editing compatibility in these grids. Page switching, mouse behavior
and mode restoration need separate checks.

## Two descriptors, one text contract

Keep a logical text descriptor (mode identities, columns, rows, row/page strides,
page count, BIOS character height and cursor units) separate from the physical
surface (pixel dimensions, pitch, format, bank window, viewport, font and scale).
Applications see the former; drawing uses the latter.

The emulation needs consistent behavior at all of these boundaries:

* Mode selection and query: BIOS mode/font/scanline services and VBE
  4F00h/4F01h/4F02h/4F03h must agree. Advertise a virtual text mode only after its
  backing surface and text storage can be provided. Build a stable resident
  mode list, preserving unrelated BIOS modes. In VBE text-mode information,
  X/Y resolution means columns/rows, not framebuffer pixels (VBE section 4).
* BDA: mode, columns, page size/offset, cursor positions, active page, last row,
  character height and applicable mode flags must describe the selected text
  mode. A logical 8-scanline BIOS font must not become a reported 32-scanline
  font merely because the renderer enlarges its pixels.
* Text memory and BIOS drawing: B800 bytes, attributes, page selection,
  scrolling, teletype, string writes, cursor shape and font queries must use
  the same logical geometry. Programs may write memory without calling BIOS.
* Mouse coordinates and text cursors must follow the logical mode. A physical
  viewport offset or scale requires input/output translation; it must not make
  menu hit targets drift. Programs that program VGA registers directly require
  separate compatibility work beyond BIOS emulation.
* A program's explicit switch to mode 03h returns to its requested 80-column
  interface. External graphics modes retain BIOS ownership as in VBE-RULES.md.
  Save/restore must include both the virtual mode and backend state.

This separation also avoids needing a DPMI transition just to enlarge text.
Banked drawing can remain a real-mode backend; an LFB or protected-mode backend
can be added independently, without taking ownership of an application's DPMI
host or changing its visible text mode.

## Fonts and physical screen choices

Use native bitmap strikes, or uniform integer enlargement of a strike. Do not
stretch a 16x16 Chinese glyph to 20x20. A future dense mode can pair 16x16 Chinese
with native 8x16 Western text. The current 800x600 console retains its existing
10x23 cells and Terminus 10x20 Western font; Unifont's native 16x16 Chinese ink
is padded inside a two-cell slot. See [font provenance](../fonts/README.md).

For a future 8x16 cell with one separate input-method row, these are pixel
budgets, not implemented mode promises:

| Logical grid | Minimum viewport at 1x | Example backend that fits |
| --- | --- | --- |
| 80x25 | 640x416 | 1280x1024 at 2x: 1280x832 |
| 80x43 | 640x704 | 1024x768 at 1x |
| 80x50 | 640x816 | 1280x1024 at 1x |
| 80x60 | 640x976 | 1280x1024 at 1x |
| 132x25 | 1056x416 | 1280x1024 at 1x |
| 132x43 | 1056x704 | 2560x1440 at 2x: 2112x1408 |
| 132x50 | 1056x816 | 3840x2160 at 2x: 2112x1632 |
| 132x60 | 1056x976 | 3840x2160 at 2x: 2112x1952 |

The fit rule is `columns * cell_width * scale <= width` and
`(rows + prompt_rows) * cell_height * scale <= height`. Additional line spacing
consumes real height. For example, 132 columns of 8-pixel cells need 1056 pixels;
they do not fit 1024 pixels without narrower glyphs. A 1920x1080 surface fits
132x60 at 1x but cannot double it. A native larger strike is another option once
its coverage, appearance and redistribution terms have been checked. Choose
readability and margins deliberately; unused screen area is preferable to
distorted strokes. These backend sizes must still be found in the BIOS mode
list; no assumption that a DOS VBE BIOS supplies widescreen or 4K modes.

## Memory and incremental implementation

`vesa.c` has variable row count, page stride/count and BIOS font height, with
80 columns and a maximum of 50 rows. `vesa.asm` has an 8000-byte shadow and an
8192-byte banked transfer buffer. Its 800x600
fast path uses 16-bit offsets; `vesa_raster.c` handles larger planes with 32-bit
offsets and bank-spanning stores. `KEYEDIT.INC` keeps an 80-byte row and checks
the BDA row limit. Shared classification has overridable row bounds, preserving
25-row legacy defaults. Extending column count still requires coordinated
changes to classification, BIOS, keyboard, buffers and mouse coordinates.

A 132x50 text image is 13200 bytes; 132x60 is 15840. Eight such pages cannot
fit the 32 KiB B800 aperture. A full shadow plus reentrant snapshot would add
roughly 15 KiB at 132x60 over the existing two buffers. Prefer bounded row work
buffers and external shadow storage, but first preserve the AX=1410h read-only
snapshot contract: its caller currently receives a pointer to a complete text
image. A row-only replacement needs an explicit new query, not a silently
truncated old pointer. No DOS calls or large interrupt-disabled copies belong
in the refresh path.

1024x768 planar graphics uses 98304 bytes per plane; 1280x1024 uses 163840.
The resident rasterizer already splits writes at 64 KiB bank boundaries,
including glyphs crossing that boundary. This wider arithmetic does not
require a 386. Logical-grid extensions must retain that behavior and the
existing 800x600 fast path.

The next logical-grid extension is 108h..10Ch emulation using the bank-spanning
backend, with each mode advertised only when its required services work.
Retain the old VGA path and shared classifier behavior while making specific
geometry assumptions explicit. Later backends can add packed pixels and larger
bitmap strikes.

For each stage test mode-query/BDA agreement, all four corners, tabs and mixed
frames, orphan bytes at both row ends, whole-character Delete/Backspace, scroll
rectangles, alternate pages, font/attribute changes, bank crossings and return
from application graphics. Compare actual SDL pixels as well as memory reads;
the two have already exposed different bugs in this project.

## Reproduce

Use the normal QA toolchain and a fresh evidence directory created by the runner:

```sh
python qa/run.py dos qa/spec/test_resident_text.py --screenshots --dosbox /path/to/dosbox
python qa/run.py application qa/spec/test_vesa_application.py -k 50_row --screenshots \
    --dosbox /path/to/dosbox --msedit2 /path/to/EDIT.COM
python qa/run.py dos qa/spec/test_text_modes.py --screenshots --dosbox /path/to/dosbox
python qa/run.py application qa/spec/test_application_modes.py --screenshots \
    --dosbox /path/to/dosbox-with-vbe-text-modes \
    --msedit2 /path/to/EDIT.COM --dos-apps /path/to/application-fixtures
```

The application observations query native support first and skip VBE modes
absent from the BIOS list. TVEDIT uses the existing pinned fixture; optional editor
paths and hashes follow [README.md](README.md). `grid.json` records before/during
geometry, while `GRID.BIN` and `TEXTMODE.BIN` retain the original observations.
Run `qa/gallery.py` on these evidence directories for a portable screenshot
gallery. Nothing in this probe changes production driver behavior.

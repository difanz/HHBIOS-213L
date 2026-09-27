# High-resolution and widescreen framebuffer experiments

`wideview.c` draws native bitmap text into advertised banked VBE graphics modes.
It runs in real-mode DOS, using 8086 compiler output and the production
`vesa_layout` descriptor decoder. This is a foreground experiment, not a TSR:
it does not expose B800 text memory to applications, hook BIOS/mouse services,
or implement Chinese editing. The shipping console remains 80x25.

The application contract remains [existing text modes](TEXT-MODES.md). A physical
surface can center and enlarge one of those grids without changing its BIOS
identity. Wider experimental grids below establish geometry/rendering capacity;
they are not new standard mode numbers and are not advertised to applications.

## Observed drawing

All rows below passed a complete framebuffer comparison and an independent
actual SDL window comparison. Each viewport includes one extra demonstration
prompt row. Chinese is native 16x16 Unifont from HH20.FNT; Western text is the
BIOS's native 8x16 ROM bitmap. Glyphs use only uniform integer enlargement.

| Physical pixels | Text grid | Scale | Pixel format | Full-draw bank calls, 64 KiB window |
| --- | --- | --- | --- | --- |
| 1024x768 | 80x43 | 1 | planar 4-bit | 8 |
| 1280x1024 | 132x60 | 1 | planar 4-bit | 12 |
| 1280x800 | 132x43 | 1 | planar 4-bit | 8 |
| 1920x1080 | 80x25 | 2 | planar 4-bit | 16 |
| 1920x1080 | 132x60 | 1 | planar 4-bit | 16 |
| 1920x1080 | 160x50, geometry only | 1 | indexed 8-bit | 32 |
| 1920x1080 | 240x66, geometry only | 1 | RGB 16-bit | 64 |
| 1920x1080 | 132x50 | 1 | RGB 32-bit | 127 |
| 1920x1200 | 132x60 | 1 | RGB 16-bit | 71 |

The two standard 4:3 planar modes also passed on classic DOSBox. The larger
surface list was observed using the optional DOSBox-X HD profile; it is not a
claim about real S3 hardware or other BIOS implementations. This installed
BIOS advertised up to 1920-wide surfaces, not 2560x1440 or 4K. Mode selection
uses queried dimensions, format and window information, never a hardcoded HD
mode number. Unsupported surfaces produce an explicit capability result (77);
invalid geometry and rendering failures are errors, not skips.

The experiment restores the previous legacy or full VBE mode number, including
the LFB flag, on normal completion and rendering errors. A legacy AH=0Fh mode
byte cannot identify a VBE mode. This mode restoration does not save previous
pixel contents or custom font/CRTC programming.

The 1080p 80x25 viewport is 1280x832 at (320,124). The 132x60 viewport is
1056x976 at (432,52). Preserving these existing grids leaves margins; filling
the entire widescreen would require more columns, a larger native bitmap
strike, or a different scale. The dense 240x66 experiment nearly fills 1080p
but uses small 16-pixel Chinese ink. More cells alone do not make a screen
easier to read.

## Bank arithmetic and rendering cost

Offsets are 32-bit byte counts, per plane for planar graphics. The writer
caches the selected window and splits transfers at its actual end. Bank
selection units are `WinGranularity`, not `WinSize`; the values can differ.
The reader and screenshot comparisons exercise pixels on both sides of bank
boundaries. Packed-color stores use the BIOS mask sizes/positions. These
contracts follow [VBE 2.0](https://www.phatcode.net/res/221/files/vbe20.pdf).

For 1920x1080 planar graphics, one plane occupies 259200 bytes and a full draw
needs four windows per plane. Selecting a bank per scanline group needs only
16 BIOS bank calls for the four planes. This is a useful bound for the future
resident renderer: avoid bank changes per character. Incremental updates should
merge dirty spans within each window, retain the glyph cache and avoid a full
redraw for ordinary typing.

The foreground prototype uses a 16 KiB scanline buffer and an 8 KiB fixture
glyph table; it has no full-frame conventional-memory buffer. It performs DOS
file reads while drawing and redraws the complete surface, so its elapsed BIOS
ticks are diagnostic observations, not resident latency measurements or a fair
speed ranking between pixel formats. No unreal-mode or DPMI transition is
needed for the tested banked path. LFB work must separately validate mapping,
ownership and the linear pitch/mask fields: VBE 3.0 permits banked and linear
layouts to differ ([VBE 3.0, function 01h](https://pdos.csail.mit.edu/6.828/2018/readings/hardware/vbe3.pdf)).

The input bounds independently reject a viewport that does not fit, zero
scale, a column count exceeding the selected 8-bit BIOS column contract, and
a visible two-byte text image larger than the 32 KiB B800 aperture. A 240x66
grid needs 31680 bytes; a 240x80 grid would need 38400 and is rejected even
when the pixel viewport could hold it. Prompt storage is separate.

With a 16 KiB window and 4 KiB granularity, the 1280x1024 planar case passed
with 40 write-bank calls and 32 split scanlines. The 800x600 indexed 8-bit
case passed with 30 calls and 28 splits. Both checks compare the entire
framebuffer and actual window pixels. Under that stress profile the tested
BIOS advertises 800x600 and 1920x1080 16-bit surfaces as LFB-only (mode attribute
bit 6 set, no bank window). The banked renderer rejects them explicitly;
these cases are not counted as rendering successes.

## Native text-page and mouse observations

`TEXTMODE <mode> audit` records mouse reset/position results and writes distinct
patterns into candidate text pages. It bounds each visible image against the
32 KiB aperture, rather than requiring padding after the final image to fit.
It then checks every visible word for interference from other pages.

* DOSBox-X's tested 80x25/43/50 modes have respectively 8/4/4 addressable,
  isolated pages. 80x50's fourth visible image ends exactly at 32 KiB despite
  its 8256-byte stride. The VBE modes have four pages at 132x25 and two at
  80x60 or 132x43/50/60.
* Classic DOSBox reports a 4096-byte stride after selecting 80x43/50. Writing
  successive pages overwrites 1392/1952 words of earlier visible images.
  A virtual text BIOS must provide coherent page size, offsets and availability
  instead of retaining that stride. These are observations of the tested
  implementations, not a rule to copy.
* In DOSBox-X BIOS mode 03h, a mouse position request (13,21) reads back (8,16);
  VBE text modes read back (13,21). At native 132x25, the default mouse maximum
  is (1055,399), and setting ranges to `columns*8-1, rows*8-1` changes it to
  (1055,199). Classic DOSBox's tested mode 03h returns unquantized (13,21).

The [original interrupt reference](https://www.cs.cmu.edu/~ralf/interrupt-list/)
(INTER61C, INTERRUP.N, INT 33h functions 3/4/7/8) describes text coordinates in
cell-size units, commonly 8x8, with truncation. The emulator observations above
show why application mouse behavior cannot be inferred from BDA alone. These
tests position the cursor through INT 33h; they do not test physical mouse
movement, callbacks, menu clicks or an external mouse driver.

A resident design must virtualize the application's mouse ranges, position,
callbacks and text cursor consistently. Logical mouse units and drawn glyph
pixels differ: with an 8x16 cell enlarged 2x, eight logical mouse units map to
16 physical horizontal pixels but 32 vertical pixels. The viewport offset also
matters. A point in a margin must not become a fictitious cell. Mouse cursor
drawing must avoid corrupting Chinese pairs or exposing the graphics backend
to an application expecting a text cursor.

## Evidence and reproduction

The optional profiles only configure the emulator used by these experiments.
No developer path or required DOSBox-X version is part of the driver:

```sh
python qa/run.py dos qa/spec/test_wideview.py --screenshots --dosbox /path/to/dosbox
python qa/run.py dos qa/spec/test_wideview.py --screenshots --dosbox /path/to/dosbox-x \
    --vesa-research-config qa/profiles/vesa-hd.conf
python qa/run.py dos qa/spec/test_wideview.py -k '1280-1024 or 800-600' \
    --screenshots --dosbox /path/to/dosbox-x \
    --vesa-research-config qa/profiles/vesa-hd-small-window.conf
python qa/run.py dos qa/spec/test_text_modes.py -k services --dosbox /path/to/dosbox
python qa/run.py dos qa/spec/test_text_modes.py -k catalog --dosbox /path/to/dosbox-x \
    --vesa-research-config qa/profiles/vesa-hd-small-window.conf
```

DOSBox-X documents the optional HD modes and mode-list limits in its
[reference configuration](https://github.com/joncampbell123/dosbox-x/blob/master/dosbox-x.reference.full.conf).
The small-window profile requests a 16 KiB window with 4 KiB granularity.
`wide.json` records the values actually returned, bank-call counts, split
scanlines, viewport and font hash. `FRAME.BIN` retains every framebuffer byte;
`RESULT.BIN`, `STATUS.BIN`, `MOUSE.BIN`, `PAGES.BIN` and `services.json` retain
the other observations. `qa/gallery.py` includes experimental status in its
captions so a rendering fixture is not mistaken for a running application.

The screenshot host allocates a desktop large enough for the requested mode.
Moving the SDL window completes before SDL repaints the newly exposed area;
an immediate capture can contain stale, clipped rectangles even when the
framebuffer is correct. Captures now allow that repaint to finish, and tests
still compare every resulting pixel. Only exact DAC/pixel-format expansions
are admitted; there is no blanket color-error tolerance.

The next integration step is a bounded logical text descriptor, then the
existing 80x43/50 selection services and explicit page ownership. Wider B800
emulation, mixed-text classification, whole-character editing, mouse callbacks
and mode save/restore must be verified before advertising new resident modes.

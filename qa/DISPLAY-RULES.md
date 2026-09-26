# Mixed text display contract

The input is 80 x 25 character/attribute words in B800. CP437 line characters
overlap GB2312 bytes: `CD CD` can mean either `══` or `屯`. Display modes select
how the classifier resolves this ambiguity.

## Frame recognition and conversion

`ZJXP.INC` recognizes frames through vertical runs, repeated characters, and
neighboring stroke directions. `D_ZBF` describes the four directions and
single/double weights; `S_QSX` reads those properties for raw CP437 bytes and
conversion codes. Neighbor reads stay within the screen and the current row.

`FRM.INC:S_CORNER` checks corners and their adjacent horizontal strokes. It
handles single, double, and mixed corners, including short scrollbar caps
terminated by up/down arrows. These checks also seed the frame conversion
pass so a corner beside Chinese text can establish the frame boundary.

Recognized frames may be converted in B800 using the public `D_ZBFB` table.
Attributes are preserved. The renderer uses `S_ALVB` to decode conversion
codes. Several fill characters share an alias, so the conversion table is
not a reversible encoding of every CP437 glyph.

Horizontal strokes use a three-character run; shading and block characters
use four. The two-character upper-block pattern (`DF DF`) also counts as a
frame pattern. In mode 3, neighboring frame evidence can identify shorter
runs. Colors do not determine Chinese pairing or frame connectivity.

| Mode (`INT 10h AX=180Ch, BH=mode`) | Frame recognition | Chinese pairing |
| --- | --- | --- |
| 0 | Disabled | Disabled (Western) |
| 1 | Disabled | Enabled, including ambiguous runs |
| 2 | Repeated-character rules | Enabled elsewhere |
| 3 | Vertical runs, neighboring strokes, corners, and repeated characters | Enabled elsewhere |

For example, a long run of `CD` bytes displays as horizontal strokes in
modes 2/3 and as `屯` pairs in mode 1. Mode 1 does not reconstruct the original
bytes of frames that have already been converted in B800; applications can
write fresh text when changing the intended interpretation.

## Per-row pairing state

`S_XRXS` renders cells in row order. `S_PVHZ` maintains the two-state pairing
flag `D_PAIR`. HZK16 contains lead rows A1..F7 and trail columns A1..FE.
Pairing checks both cells, including whether the next cell is a frame.

| State | Input | Result | Next state |
| --- | --- | --- | --- |
| TEXT | Valid lead followed by a valid, unprotected trail in this row | Draw both halves | PENDING |
| TEXT | Frame, ordinary byte, invalid lead, or orphan | Draw a single cell | TEXT |
| PENDING | The trail already drawn by the lead | Advance without drawing again | TEXT |
| Either | End of row | Reset pairing | TEXT on next row |

The two halves may have different attributes. Western mode draws individual
cells. The Chinese-enable switch at `K_HZ1` can render a pair as two Western
cells while keeping their original attributes.

## Change detection and rendering

`S_XR` compares B800 with the shadow buffer `D_XPQ`. A changed word redraws its
row, because changing one byte can shift pairing throughout a Chinese run.
The row is copied to the shadow as it is rendered. An unchanged row requires
no drawing. Display-policy changes invalidate the shadow and trigger repaint.

Changing half a Chinese character preserves the application's other byte;
an orphan displays as a single cell. BIOS teletype backspace moves one cell
left without deleting text. Character deletion belongs to the application.

## Tests and limits

Unit tests execute the assembled routines and observe their drawing calls.
They check frame/Chinese boundaries, mode rules, incremental versus fresh
rendering, and bounded memory access. Scanner writes are restricted to the
public frame conversion table; attribute changes and character erasure fail.

DOS tests compare rendered VGA planes with BIOS/HZK16 glyph bytes and allow
B800 conversion only at explicitly identified frame cells. A tvedit case
checks unindented Chinese text and window corners in the actual application.

Unicorn is not cycle accurate. Framebuffer checks do not prove host window
scanout or physical VGA/EGA/HGA behavior. See [README.md](README.md) for the
test layers and their artifacts.

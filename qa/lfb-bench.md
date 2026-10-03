# Direct-color dirty-refresh samples

DOSBox-X, `cycles=30000`, `core=normal`, `qa/profiles/vesa-hd.conf`, font
`HH20.FNT`. The guest program is `qa/harness/lfbbench.c`. It latches PIT
channel 0 (about 1.193182 MHz) around one synchronous `AX=1500h` repaint
and reads `AX=1418h` with `CX=1`. Milliseconds are `counts / 1193`. A
BIOS tick is about 55 ms, so sub-tick work can report `ticks=0`. These
samples are not a pass/fail threshold. `test_vesa_lfb.py` checks the byte
counter only: idle is 0, and a few cells write fewer bytes than one line,
which writes fewer than a full frame.

A full blank and a full hanzi frame both cover the text grid plus the
status row, so their byte counts match. Scroll bytes are the pixel move
plus the cleared row and do not include a status-row repaint. Spaces are
one horizontal fill per run, still on the 16-bit path, so a blank pair
is not a painter result. Why the painter is one glyph chunk, and why a
long protected-mode session and unreal mode are not used, is in
`qa/lfb-fastpath.md`.

## Linear painter

Same harness, shipping painter: one protected-mode entry per glyph
chunk, packed rows stored with `REP STOS`, including linear scale 2.
Idle `AX=1418h` is 0. A negative PIT latch has one 65536-count period
added before the line is used. Blank on 114h/117h is still one PIT
period apart and is not attributed to the painter. The 245h blank
sample is 118 ms with the fill routine unchanged.

| Mode | Hanzi counts | Hanzi ms | Bytes | Scroll | ASCII line |
| --- | ---: | ---: | ---: | ---: | ---: |
| 114h | 297932 and 296724 | 249 and 248 | 956800 | 26 ms, 920000 bytes | 33 ms, 73600 bytes |
| 117h | 298128 and 296918 | 249 and 248 | 960000 | 26 ms, 920000 bytes | 33 ms, 76800 bytes |
| 245h | 481320 and 480110 | 403 and 402 | 3334400 | 24 ms, 3200000 bytes |  |

Cell pixels dumped by `LFBDUMP` at 114h and 245h match between scale 1
and the packed scale-2 painter. 114h line and the paired hanzi readings
that latched one period low are the corrected counts above.

## 64 KiB bank window

`qa/harness/bankwin.asm` is the paint-only probe. The same window
switch and glyph walk live in `VESA.COM` (link `0xFEF7`, 9 bytes under
`0xFF00`). The harness stays in real mode: no CR0, no VCPI, no DPMI.
The window is the 64 KiB buffer at A000. `DX` is the 64 KiB bank
(`granularity` 64, so `bank_step` is 1). When mode info has a
`WinFuncPtr`, the switch is a far call with `AX=4F05h`; the other
sample is `INT 10h` `AX=4F05h`. Both probes returned success on 114h
and 117h. A negative latch adds one 65536-count period before the
line is printed.

The harness times the paint only. It does not run the console's
`AX=1500h` classifier. That real-mode walk is about 30 ms on a full
hanzi frame and is the same cost on either painter. The resident
console samples are in `qa/lfb-latency.md`.

DOSBox-X with `qa/profiles/vesa-hd.conf` publishes a writable 64 KiB
window and a `PhysBasePtr` for both 114h and 117h. 117h is not
linear-only on this card. Mode 245h is not in the 128-mode list this
profile returns (`MODES=128`, list ends at `0xFFFF`). There is no 245h
banked sample.

Glyph order matches the console. A full frame is the 80×25 grid of
10×23 cells plus the 23-line status band (598 lines, 956800 bytes at
16 bpp). Sparse is four cells on text row 2 plus that status band.
One line is text row 10, ASCII, plus status. Scroll moves 552 lines up
by 23 and clears the vacated row. It does not repaint status. At pitch
1600 the row is the whole pitch, so the copy is one span in 4 KiB
pieces. At pitch 2048 the copy is one 1600-byte span per scanline.
Bytes are the bytes stored, not the bytes read back from the window.

A scanline fill crosses a bank 15 times at pitch 1600 (956800 bytes,
15 windows). Cell order does not. Pitch 1600 holds 40.96 lines per
window, so some 23-line rows straddle a 64 KiB edge. Text row 10
therefore switches twice per cell (160) plus the status window, 161
switches. A full hanzi frame in the same order is 2171 switches. The
switch itself is cheap: the 114h hanzi pair differs by 516 counts
(0.4 ms) between `WinFuncPtr` and `INT 10h` `AX=4F05h`, both at 2171
switches and 417 ms.

| Sample | 114h far counts | ms | switches | bytes | 117h far counts | ms | switches | bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Full blank | 50652 | 42 | 15 | 956800 | 50602 | 42 | 19 | 956800 |
| Four cells | 3488 | 2 | 2 | 38640 | 3498 | 2 | 10 | 38640 |
| One ASCII line | 43968 | 36 | 161 | 73600 | 43766 | 36 | 3 | 73600 |
| Scroll one row | 91236 | 76 | 251 | 920000 | 94604 | 79 | 800 | 920000 |
| Full hanzi | 498402 | 417 | 2171 | 956800 | 433522 | 363 | 2705 | 956800 |

114h blank, sparse, line, and hanzi through `INT 10h` `AX=4F05h` match
those times. 117h blank in the raw latch was `counts=4294952362`;
adding the missed period gives 50602. 117h hanzi is one pass and is
not corrected up by a period. 114h hanzi is the paired reading (498402
and 432866).

| Sample | LFB 114h | Banked 114h | LFB 117h | Banked 117h |
| --- | ---: | ---: | ---: | ---: |
| Four cells | — | 2 ms, 2 switches | — | 2 ms, 10 switches |
| One ASCII line | 33 ms | 36 ms, 161 switches | 33 ms | 36 ms, 3 switches |
| Scroll one row | 26 ms | 76 ms, 251 switches | 26 ms | 79 ms, 800 switches |
| Full hanzi | 249 ms | 417 ms, 2171 switches | 249 ms | 363 ms, 2705 switches |

Sparse dirt is 2 ms. A full line that straddles a bank is a wash with
the linear painter (36 ms versus 33 ms). Scroll and a full hanzi frame
are not: 26 ms versus 76 ms, and 249 ms versus 417 ms, at 114h. The
extra banked time is the 16-bit bit walk and the cell-order stores,
not the far call. The harness copies the contiguous grid in 4 KiB
chunks (251 switches at pitch 1600). At pitch 2048 each 1600-byte row
is its own span (800 switches). A few hundred extra far calls are
under a millisecond.

Resident dispatch is [Direct-color dispatch](VBE-RULES.md#direct-color-dispatch).
The console timings, including the dirty walk, are in `qa/lfb-latency.md`.

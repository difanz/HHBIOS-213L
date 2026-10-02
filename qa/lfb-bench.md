# Direct-color dirty-refresh samples

DOSBox-X, `cycles=30000`, `core=normal`, `qa/profiles/vesa-hd.conf`, font
`HH20.FNT`. The guest program is `qa/harness/lfbbench.c`. It latches PIT
channel 0 (about 1.193182 MHz) around one synchronous `AX=1500h` repaint and
reads `AX=1418h` with `CX=1`. Milliseconds in the tables are `counts / 1193`.
A BIOS tick is about 55 ms, so sub-tick work can report `ticks=0`. These
samples are not a pass/fail threshold. `test_vesa_lfb.py` checks the byte
counter only: idle is 0, and a few cells write fewer bytes than one line,
which writes fewer than a full frame.

The same pixels are stored before and after the change. A full blank and a
full hanzi frame both cover the text grid plus the status row, so their byte
counts match. Scroll bytes are the pixel move plus the cleared row and do not
include a status-row repaint.

Before the space-run change, a blank frame wrote about as many bytes as a
scroll and took much longer. The cost was one protected-mode entry per glyph
run, not the 4096-byte copy cap. Spaces are one horizontal fill per run.
The tables below that heading record the following step, one entry per glyph
scanline. A later step paints a whole glyph chunk in one entry and
run-length-fills packed rows; those samples are in the last section.
`qa/lfb-fastpath.md` records why unreal mode, a long protected-mode session,
and a conventional staging buffer were not used.

## One entry per glyph scanline

## 114h, 800×600×16, pitch 1600, scale 1

| Sample | Before counts | Before ms | Before bytes | After counts | After ms | After bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Full blank | 885594 | 742 | 956800 | 50282 | 42 | 956800 |
| Four cells | 77716 | 65 | 38640 | 66064 | 55 | 38640 |
| One ASCII line | 112370 | 94 | 73600 | 55452 | 46 | 73600 |
| Scroll one row | 34112 | 28 | 920000 | 31216 | 26 | 920000 |
| Full hanzi | 1267024 | 1062 | 956800 | 764242 | 640 | 956800 |
| Idle, 8 ticks | 486380 | 407 | 0 | 471040 | 394 | 0 |

Second passes of the full frames agreed within a few percent (blank 739 ms
before and 42 ms after; hanzi 1115 ms before and 639 ms after).

## 117h, 1024×768×16, pitch 2048, scale 1

| Sample | Before counts | Before ms | Before bytes | After counts | After ms | After bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Full blank | 885784 | 742 | 960000 | 50468 | 42 | 960000 |
| Four cells | 77906 | 65 | 41840 | 66254 | 55 | 41840 |
| One ASCII line | 47022 | 39 | 76800 | 55642 | 46 | 76800 |
| Scroll one row | 99646 | 83 | 920000 | see note |  | 920000 |
| Full hanzi | 1267218 | 1062 | 960000 | 829968 | 695 | 960000 |
| Idle, 8 ticks | 519548 | 435 | 0 | 501740 | 420 | 0 |

The mode 117h scroll sample reads `counts=4294932976` on both runs. That is
one PIT period (65536 counts) below the 31216-count result from mode 114h,
which moves the same 920000 bytes. The BIOS tick word did not advance across
that latch. Adding the missed period gives 31216 counts, 26 ms.

## 245h, 1920×1080×16, pitch 4096, scale 2

| Sample | Before counts | Before ms | Before bytes | After counts | After ms | After bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Full blank | 1509398 | 1265 | 3334400 | 168574 | 141 | 3334400 |
| Four cells | 62326 | 52 | 140800 | 61658 | 51 | 140800 |
| One ASCII line | 173896 | 145 | 262400 | 106582 | 89 | 262400 |
| Scroll one row | 73202 | 61 | 3200000 | 28666 | 24 | 3200000 |
| Full hanzi | 2264118 | 1897 | 3334400 | 1503056 | 1259 | 3334400 |
| Idle, 8 ticks | 509248 | 426 | 0 | 517264 | 433 | 0 |

## One glyph chunk, packed runs

Same harness, after painting every framebuffer line of one glyph chunk in a
single protected-mode entry and filling packed rows with `REP STOS`. "Before"
is the scanline-entry sample above. Hanzi repeats agreed within 1 ms. Blank
and scroll samples on this run still drop or add one 65536-count PIT period;
the two blank readings in a mode differ by that period, and the corrected
scroll matches the previous 26 ms (114h/117h) or 24 ms (245h). Byte counts
did not change. Idle stayed 0.

| Mode | Blank before ms | Blank after counts | Hanzi before ms | Hanzi after counts | Hanzi after ms | Bytes |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| 114h | 42 | 16898 and 82434 | 640 | 399978 and 398774 | 335 and 334 | 956800 |
| 117h | 42 | 17084 and 82622 | 695 | 400166 and 398960 | 335 and 334 | 960000 |
| 245h | 141 | 76134 and 141668 | 1259 | 1131224 and 1130016 | 948 and 947 | 3334400 |

## 32-bit code segment

Same harness, after the glyph painter moved to a 32-bit code selector and
measured packed runs with `BSR`. "Before" is the one-chunk `REP STOS` sample
above. Hanzi bytes did not change. Idle stayed 0. Scroll stayed 26 ms
(114h/117h) and 24 ms (245h). Two boots produced the same hanzi pair. On
245h the second pass is repeatably 64336 counts slower, just under one PIT
period, with the same byte count.

Blank on 114h/117h is still one PIT period apart (70902 vs 5362, 71092 vs
5552). 245h blank agrees at 124230 counts, 104 ms. Spaces are still the
16-bit horizontal fill, so those blank readings are not attributed to the
painter. One ASCII line on 114h/117h latches one period low
(`counts=4294941190` and `4294941378`); adding that period gives 39430 and
39618 counts, 33 ms, with the same 73600 and 76800 bytes.

| Mode | Hanzi before ms | Hanzi after counts | Hanzi after ms | Bytes |
| --- | ---: | --- | ---: | ---: |
| 114h | 335 and 334 | 298018 and 296812 | 249 and 248 | 956800 |
| 117h | 335 and 334 | 298214 and 297006 | 249 and 248 | 960000 |
| 245h | 948 and 947 | 878690 and 943026 | 736 and 790 | 3334400 |

## Packed rows at scale 2

Same harness, after a linear console stopped unpacking scaled glyphs in C.
Scale 1 was already on the packed painter, so 114h and 117h did not move.
245h had been a 16-bit unpack plus the per-column loop. Cell pixels dumped
by `LFBDUMP` at 114h and 245h match the previous painter byte for byte.
Idle stayed 0. Scroll stayed 24 ms. Bytes stayed 3334400. The two hanzi
passes now agree; the old 736/790 split was the per-column store. Blank
bytes are unchanged. The 245h blank sample moved from 104 ms to 118 ms
with no change to the fill routine; the link shifted that code by 6 bytes.

| Mode | Hanzi before ms | Hanzi after counts | Hanzi after ms | Bytes |
| --- | ---: | --- | ---: | ---: |
| 114h | 249 and 248 | 297932 and 296724 | 249 and 248 | 956800 |
| 117h | 249 and 248 | 298128 and 296918 | 249 and 248 | 960000 |
| 245h | 736 and 790 | 481320 and 480110 | 403 and 402 | 3334400 |

## 64 KiB bank window, real mode only

`qa/harness/bankwin.asm` is a separate COM. It is not linked into
`VESA.COM` (the resident image is 23 bytes under `0xFF00`). It stays in
real mode: no CR0, no VCPI, no DPMI. The window is the 64 KiB buffer at
A000. `DX` is the 64 KiB bank (`granularity` 64, so `bank_step` is 1).
When mode info has a `WinFuncPtr`, the switch is a far call with
`AX=4F05h`; the other sample is `INT 10h` `AX=4F05h`. Both probes
returned success on 114h and 117h. Milliseconds are still PIT counts
divided by 1193, at `cycles=30000`, `core=normal`, `HH20.FNT`. A negative
latch adds one 65536-count period before the line is printed.

The harness times the paint only. It does not run the console's
`AX=1500h` classifier. That real-mode walk is about 30 ms on a full
hanzi frame in `qa/lfb-latency.md` and is the same cost on either
painter.

DOSBox-X with `qa/profiles/vesa-hd.conf` publishes a writable 64 KiB
window and a `PhysBasePtr` for both 114h and 117h. 117h is not
linear-only on this card. Mode 245h is not in the 128-mode list this
profile returns (`MODES=128`, list ends at `0xFFFF`). There is no 245h
banked sample. The 245h LFB numbers above are from the earlier linear
harness.

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
window, so some 23-line rows straddle a 64 KiB edge. The next cell
starts back in the previous window. Text row 10 therefore switches
twice per cell (160) plus the status window, 161 switches, not three.
A full hanzi frame in the same order is 2171 switches. The switch
itself is cheap: the 114h hanzi pair differs by 516 counts (0.4 ms)
between `WinFuncPtr` and `INT 10h` `AX=4F05h`, both at 2171 switches
and 417 ms.

| Sample | 114h far counts | ms | switches | bytes | 117h far counts | ms | switches | bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Full blank | 50652 | 42 | 15 | 956800 | 50602 | 42 | 19 | 956800 |
| Four cells | 3488 | 2 | 2 | 38640 | 3498 | 2 | 10 | 38640 |
| One ASCII line | 43968 | 36 | 161 | 73600 | 43766 | 36 | 3 | 73600 |
| Scroll one row | 91236 | 76 | 251 | 920000 | 94604 | 79 | 800 | 920000 |
| Full hanzi | 498402 | 417 | 2171 | 956800 | 433522 | 363 | 2705 | 956800 |

114h blank, sparse, line, and hanzi were also run through `INT 10h`
`AX=4F05h`. Blank stayed 42 ms and 15 switches, sparse 2 ms and 2
switches, the line 43928 counts (36 ms, 161 switches). Hanzi reads were
497886 and 432350 counts, the same 417 ms and 2171 switches after the
missed PIT period. `WinFuncPtr` does not change the result at this
granularity.

117h blank in the raw latch was `counts=4294952362`. Adding the missed
period gives 50602. 117h hanzi is one pass. It was not paired, so it is
not corrected up by a period. 114h hanzi is the paired reading (498402
and 432866).

LFB numbers in the table below are the published 32-bit painter, not a
new boot. Blank is the same 16-bit space fill on both paths and is PIT
noise around 42 ms. The LFB four-cell figure of 55 ms is from before
that 32-bit painter and is not reused here.

| Sample | LFB 114h | Banked 114h | LFB 117h | Banked 117h |
| --- | ---: | ---: | ---: | ---: |
| Four cells | — | 2 ms, 2 switches | — | 2 ms, 10 switches |
| One ASCII line | 33 ms | 36 ms, 161 switches | 33 ms | 36 ms, 3 switches |
| Scroll one row | 26 ms | 76 ms, 251 switches | 26 ms | 79 ms, 800 switches |
| Full hanzi | 249 ms | 417 ms, 2171 switches | 249 ms | 363 ms, 2705 switches |

Sparse dirt sits in one window at pitch 1600 (2 switches, 2 ms) and in
a handful at pitch 2048 (10 switches, still 2 ms). That is the common
console case. A full line that straddles a bank is a wash with the
linear painter (36 ms versus 33 ms). Scroll and a full hanzi frame are
not. The linear copy is 26 ms; the banked copy is 76 ms at 114h and
79 ms at 117h, for the same 920000 bytes. Full hanzi is 249 ms linear
and 417 ms banked at 114h. The extra banked time is the 16-bit bit walk
and the cell-order stores, not the far call.

A per-scanline read then write at pitch 1600 would ping-pong and land
near 643 switches. The harness does not do that. It copies the
contiguous grid in 4 KiB chunks and switches only when the source or
destination window changes (251). At pitch 2048 the 1600-byte rows are
not contiguous, so each row is its own span (800 switches). The two
scroll times still agree, which matches the hanzi pair: a few hundred
extra far calls are under a millisecond.

## Which painter

Use the linear short-PE painter when install finds PE clear and the
mode has `PhysBasePtr`. That is the 249 ms frame and the 26 ms scroll.

Use the bank window and `WinFuncPtr` when the console is forced banked,
or when `SMSW` shows PE (V86: Win95, EMM386, JEMM). There is no
protected-mode entry on that path. Hybrid linear paint is not available
there, because the short CR0 session is illegal. The banked frame is
the one measured above: sparse dirt stays near 2 ms, a straddling line
near 36 ms, a scroll near 76 ms, a full hanzi frame near 417 ms.

A hybrid is viable only as an optimization, and only when all three
hold: the mode has a 64 KiB window, it has `PhysBasePtr`, and PE is
still clear. Keep the banked `WinFuncPtr` path for sparse dirt (no PE,
2 switches at 114h). For a scroll or a full frame, the linear short-PE
painter is the faster one (26 ms versus 76 ms, 249 ms versus 417 ms).
One text line is not worth the switch. Under V86 the hybrid cannot take
the linear side, so the console stays banked for every sample.

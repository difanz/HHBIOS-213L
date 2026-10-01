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

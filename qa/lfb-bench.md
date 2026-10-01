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

Before this change, a blank frame wrote about as many bytes as a scroll and
took much longer. The cost was one protected-mode entry per glyph run, not
the 4096-byte copy cap. Spaces are now one horizontal fill per run, and each
glyph scanline is one entry. The cap is unchanged: a longer interrupt-off
chunk would not remove the remaining per-glyph entries. Hanzi is still one
entry per cell scanline, which is the time left on a full frame.

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

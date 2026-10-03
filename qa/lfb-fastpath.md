# Direct-color painter

`VESA.COM` stays a 16-bit real-mode TSR. It does not load VCPI, DPMI, a
DOS extender, or CWSDPMI. Install requires an EMS manager (`EMMXXXX0`
and INT 67h `AH=40h`) so the TSR can use a UMB. EMM386 and JEMM then
run the guest in V86: `SMSW` shows PE, the short-PE transfer is not
used, and the console stays installed on the 64 KiB window. A Win95
DOS box is the same V86 case. No window and PE already set is the
install that does not keep the direct-color console. Layout, the EMS
gate, and the aperture rules are in `qa/lfb-latency.md`. Samples are
in `qa/lfb-bench.md`.

## Which painter

Fewer than 80 dirty text cells, a bank-only mode, and every refresh
while PE is set use the 64 KiB window and `WinFuncPtr` (else INT 10h
`AX=4F05h` through the saved vector). There is no protected-mode entry
on that path. Scroll, and 80 or more dirty cells, use the short-PE
linear painter only when `PhysBasePtr` was recorded and PE is clear.
`PhysBasePtr` with no usable window is linear only; PE set still
refuses that install.

## One glyph chunk

One protected-mode entry paints one glyph chunk: every framebuffer
line of the glyph when the store is at most 4096 bytes, otherwise one
source row at a time. On these fonts that is one entry per half-cell
(460 bytes at scale 1, 1600 at scale 2). Packed rows, the HH20 and
ASCII glyphs, walk bits with a shift mask and emit each same-color
run with `REP STOSW` or `REP STOSD`. Word and dword glyphs stay on
the per-column loop. PE is cleared, still under CLI, before any DOS
or BIOS interrupt. There is no `STI` while PE is set. The real-mode
IVT is not an IDT, and this image does not install one.

The glyph painter far-jumps to selector 18h, a 4 GB 32-bit code
descriptor based at the resident segment. Copies, solid fills, and
XOR stay on the 16-bit selector. Interrupt hooks stay 16-bit. Font
lookup, the dirty-map walk, and every DOS or BIOS interrupt stay in
real mode between glyphs. `vesa_pm32.asm` is assembled with
`jwasm -bin` and included in the resident segment, because JWasm will
not assemble `use32` into the 16-bit segment and a second segment
would restart offsets at 0.

DS, ES, and SS are the flat data selector for that entry. `[ebp+disp]`
uses SS, so a real-mode SS would add the COM paragraph base on top of
the linear address. Real SS is saved before PE is set and restored
after the return to real mode, before `popad`. The painter does not
push or call, so it needs no protected-mode stack. The display pitch
is read with a CS override because DS is already flat. `origin` is
set from EDI; each later framebuffer row adds the pitch.

Packed rows load a dword, swap the bytes so bit 31 is the leftmost
pixel, shift off `gbit & 7`, and measure the run with `BSR`. The run
is clamped to the columns left in the cell, multiplied by the
horizontal scale, and stored with `REP STOSW` or `REP STOSD`. A
vertical scale repeats the source row.

The resident stack is 1040 bytes. `RestoreSurface` uses about 1022 of
those, and the timer interrupt chains the previous handler on this
stack before it checks the busy flag. The switches are `/M`, `/F`,
`/R`, `/N`, and `/AF`. `/AF` defaults off and does not call an
accelerator. The COM image is `0xFEF7` (9 bytes under `0xFF00`). Font
bytes move with XMS `AH=0Bh` or EMS `AH=57h`. The glyph arena stays a
near pointer.

On the same harness, full hanzi is 249 ms and 248 ms at 114h and 117h
(956800 and 960000 bytes) and 403 ms and 402 ms at 245h (3334400
bytes). Of the 114h/117h frame, about 30 ms is real mode, 9 ms is
protected-mode entry, 166 ms is the bit scan, and 44 ms is
`REP STOS`. Idle `AX=1418h` is 0. Scroll is 26 ms on 114h/117h and
24 ms on 245h. Spaces remain a horizontal fill on the 16-bit path.

## Not used

- PE held for a whole refresh. That would leave interrupts off for the
  hanzi repaint to save the per-glyph entries (about 9 ms).
- Unreal mode. An FS or GS limit left at 4 GB faults if an interrupt
  reloads that segment. V86 cannot arm it. Re-arming per glyph costs
  the same entry as painting inside that entry.
- One transfer of neighboring hanzi. Those cells are different glyphs.
  A row of expanded RGB565 does not fit beside the live shadow and
  `text_transfer`. Run-length `REP STOS` inside the glyph entry is the
  coalescing that fits.
- A second linear painter for an 8086 or 286. Install already refuses
  those CPUs.
- An AF entry. `/AF` only sets `af_on`.
- VCPI, DPMI, and CWSDPMI. V86 stays on the window.

# Direct-color fast path

The console stays a 16-bit real-mode TSR inside `VESA.COM`. It does not load
VCPI, DPMI, a DOS extender, or a Windows VxD, and it does not require one.
A Win95 DOS box, EMM386, and JEMM are V86: `SMSW` already shows PE, the
linear transfer aborts, and install does not keep the console. VCPI and
DPMI are not product paths around that abort. The host write-up is
`qa/lfb-latency.md`.

Samples use DOSBox-X at `cycles=30000` with `HH20.FNT`. Counts and the PIT
period are in `qa/lfb-bench.md`.

## What was slow

After space runs became one fill, mode 114h full hanzi was 640 ms and wrote
the same 956800 bytes as a full blank. A blank was about 42 ms. The gap was
not the 4096-byte copy cap. One protected-mode entry per glyph scanline was
about 130 ms of that 640 ms (roughly 3 µs per entry). The rest was the
per-pixel bit test.

## Chosen path

The 16-bit code segment below is the previous painter. The following section
moves that same chunk into a 32-bit code selector.

One glyph chunk is one protected-mode entry. The chunk is every framebuffer
line of the glyph when the store is at most 4096 bytes, otherwise one source
row at a time. For the bench fonts that is one entry per half-cell (460 bytes
at scale 1, 1600 at scale 2). Packed rows, which are the HH20 and ASCII
glyphs, walk bits with a shift mask and emit each same-color run with
`REP STOSW` or `REP STOSD`. Word and dword glyphs stay on the per-column
loop. PE is cleared before any DOS or BIOS interrupt.

On 114h that moved full hanzi from 640 ms to 335 ms (second pass 334 ms).
An intermediate per-glyph entry that still stored one pixel at a time landed
near 350–404 ms, so the run-length store is the smaller part of the gain.
117h matches 114h (335 ms) because the text grid is the same 80×25 cells.
245h, scale 2, moved from 1259 ms to 948 ms. Idle `AX=1418h` stayed 0.
Byte counts stayed 956800, 960000 and 3334400.

Interrupt-off budget: one chunk, at most 4096 bytes, then back to real mode.
A half-cell at these sizes is well under that cap, so the window is one
glyph (tens of microseconds), not the frame.

That image was `0xFEE9` bytes (23 bytes under the COM limit). The resident
stack is now 1040 bytes. `RestoreSurface` uses about 1022 of those, and the
timer interrupt chains the previous handler on this stack before it checks
the busy flag. Do not shrink the stack further without measuring that chain.
The install banners were shortened by the same budget. The switches are
unchanged, including `/M`, `/F` and `/R`.

## 32-bit painter

The paint itself now runs with a 32-bit code selector. Selector 18h is a
4 GB 32-bit code descriptor based at the resident segment, patched the same
way as the 16-bit code descriptor. Copies, solid fills, and XOR stay on the
16-bit selector. Only the glyph painter far-jumps to selector 18h. Interrupt
hooks stay 16-bit. Font lookup, the dirty-map walk, and every DOS or BIOS
interrupt stay in real mode between glyphs. One entry is still one glyph
chunk.

JWasm will not assemble `use32` into the 16-bit segment, and a second segment
restarts offsets at 0. `vesa_pm32.asm` is assembled with `jwasm -bin` and
included into the resident segment. Its jumps are relative.

DS, ES, and SS are the flat data selector for that entry. `[ebp+disp]` uses
SS, so a real-mode SS would add the COM paragraph base on top of the linear
address. Real SS is saved before PE is set and restored after the return to
real mode, before `popad`. The painter does not push or call, so it needs no
protected-mode stack. The display pitch is read with a CS override because DS
is already flat. `origin` is set from EDI; each later framebuffer row adds
the pitch. Leaving `origin` at 0 writes the second row at physical address
`pitch` and walks into ROM.

Packed rows (HH20 and ASCII) load a dword, swap the bytes so bit 31 is the
leftmost pixel, shift off `gbit & 7`, and measure the run with `BSR`: leading
zeros, or leading ones of the complement. The run is clamped to the columns
left in the cell, multiplied by the horizontal scale, and stored with
`REP STOSW` or `REP STOSD`. Word and dword glyphs stay on the per-column
loop. A vertical scale repeats the source row. PE is cleared, still under
CLI, before any real-mode interrupt.

There is no STI while PE is set. The real-mode IVT is not a valid IDT, and
this image does not install one. The interrupt-off window remains one chunk
of at most 4096 bytes: 460 bytes for a scale-1 half-cell and 1600 bytes at
scale 2 on these fonts. That is one glyph, not the frame. Entering PM once
for a whole refresh would require the font walker inside the 32-bit blob, or
CLI across the whole hanzi repaint (249 ms at 114h), to save the leftover
per-glyph entries. Those entries were about 12 ms after the previous
batching. A later probe measured them at 9 ms. A frame of CLI is not
worth that. The ranked leftovers, the UMB/EXE question, and EMM386 are
in `qa/lfb-latency.md`.

That link reported `0xFED9`. The image is now `0xFEF1` (15 bytes under
`0xFF00`). The resident stack is 1040 bytes. The painter does not use
VCPI, DPMI, or XMS. A real-mode 64 KiB window path is in the resident
image: below 80 dirty cells it paints through `WinFuncPtr` and does not
enter PE. A full line, a scroll, or a full frame still uses short-PE
linear when PE is clear. When `SMSW` shows PE and a window exists, every
refresh stays banked. No window still aborts the linear console. The
numbers are in `qa/lfb-latency.md`.

Full hanzi on the same harness, two passes, from the 335 ms / 948 ms
painter: 114h 249 ms and 248 ms, 117h 249 ms and 248 ms, 245h 736 ms and
790 ms. The 245h pair repeated on a second boot; the passes differ by 64336
counts, just under one PIT period, and the byte count matches, so the slower
pass is not a longer store. Bytes stayed 956800, 960000, and 3334400. Idle
`AX=1418h` stayed 0. Scroll stayed 26 ms on 114h/117h and 24 ms on 245h.
Blank samples are still a one-period PIT pair on 114h/117h. Spaces remain a
horizontal fill on the 16-bit path, so that pair is not a painter result.
Linear scale 2 later joined this packed painter; 245h is 403 ms and 402 ms
in `qa/lfb-bench.md`.

## Rejected

Long protected-mode session. Staying in PE for a whole refresh, still under
CLI, would coalesce the remaining entries. After per-glyph batching there are
about 4000 half-cell entries on a full hanzi frame, about 12 ms. The 32-bit
painter above does not do this: it returns to real mode after each glyph.
The frame itself would be the whole hanzi repaint with interrupts off if
that work stayed inside one CLI window. A TSR cannot hold CLI for a frame
to save 12 ms.

Unreal / big-real. On a 386 the existing 4 GB data selector can be loaded
into FS or GS, then PE cleared, leaving a real-mode segment limit of 4 GB.
`SMSW` PE stays clear afterward. V86 cannot arm it, same abort as today.
ES is not usable: interrupt handlers `push`/`pop` ES and the 4 GB limit
dies. The resident handlers do not touch FS, but any interrupt that reloads
FS during the window general-protects. Re-arming per glyph costs the same
entry as painting inside that entry. The leftover after per-glyph batching
is the 12 ms above. Not implemented.

Adjacent hanzi as one transfer. Neighboring cells are different glyphs, so
they become one store only after expansion. A row of expanded RGB565 is about
36 KB, and one scanline at 800×600×16 is 1600 bytes. The COM link is
`0xFEF1`, 15 bytes under `0xFF00`. `text_transfer` (8192) and the shadow (8000) are live. The stack cannot
hold a row during refresh. Run-length `REP STOS` inside the glyph entry is
the coalescing that fits.

CPU split. Install already refuses an 8086 or 286 (`requires a 386`). There
is no second linear painter for a weaker CPU.

Banked VBE window (`WinFuncPtr`, else `AX=4F05h` through the saved vector).
The resident console uses it for fewer than 80 dirty cells, and for every
refresh when PE is set. A full line or more still prefers the linear map
when `PhysBasePtr` is present and PE is clear. Planar 4 bpp remains
preferred when the BIOS offers it.

XMS is already optional for the font cache. It is not required to reach the
framebuffer.

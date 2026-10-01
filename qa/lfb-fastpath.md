# Direct-color fast path

The console stays a 16-bit real-mode TSR inside `VESA.COM`. It does not load
VCPI, DPMI, a DOS extender, or a Windows VxD. A Win95 DOS box and EMM386 are
V86: `SMSW` already shows PE, the linear transfer aborts, and install does
not keep the console. That is the same failure as the short protected-mode
copy. VCPI is not a workaround; it conflicts with those V86 hosts.

Samples use DOSBox-X at `cycles=30000` with `HH20.FNT`. Counts and the PIT
period are in `qa/lfb-bench.md`.

## What was slow

After space runs became one fill, mode 114h full hanzi was 640 ms and wrote
the same 956800 bytes as a full blank. A blank was about 42 ms. The gap was
not the 4096-byte copy cap. One protected-mode entry per glyph scanline was
about 130 ms of that 640 ms (roughly 3 µs per entry). The rest was the
per-pixel bit test.

## Chosen path

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

The image is `0xFEE9` bytes (23 bytes under the COM limit). The resident
stack is 1104 bytes so the painter fits. `RestoreSurface` uses about 1022 of
those, and the timer interrupt chains the previous handler on this stack
before it checks the busy flag. Do not shrink the stack further without
measuring that chain. The install banners were shortened by the same budget.
The switches are unchanged, including `/M`, `/F` and `/R`.

## Rejected

Long protected-mode session. Staying in PE for a whole refresh, still under
CLI, would coalesce the remaining entries. After per-glyph batching there are
about 4000 half-cell entries on a full hanzi frame, about 12 ms. The frame
itself is 335 ms with interrupts off if that work stays inside one CLI
window. A TSR cannot hold CLI for a frame to save 12 ms.

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
36 KB, and one scanline at 800×600×16 is 1600 bytes. The COM has 23 bytes
free. `text_transfer` (8192) and the shadow (8000) are live. The stack cannot
hold a row during refresh. Run-length `REP STOS` inside the glyph entry is
the coalescing that fits.

CPU split. Install already refuses an 8086 or 286 (`requires a 386`). There
is no second linear painter for a weaker CPU.

Banked VBE window (`AX=4F05h`). A bank switch per 64 KB window adds calls on
top of the copies. It is not faster than the linear map, and it is not
required for cards that publish `PhysBasePtr`. Linear remains preferred when
that pointer is present. Planar 4 bpp remains preferred when the BIOS offers
it.

XMS is already optional for the font cache. It is not required to reach the
framebuffer.

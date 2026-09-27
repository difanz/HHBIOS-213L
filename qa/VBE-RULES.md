# VBE coexistence and rendering

`VGA.COM` retains its 640x480 renderer. The independent `VESA.COM`, built from
`vesa.c`, `vesa.asm` and `vesa_raster.c`, draws a planar 16-color console. Its mouse adapter is in `vesa_mouse.c`/`.asm`. Load one display
driver at a time, after a font reader and optionally CKBD. The logical screen
starts at 80x25 cells. At the default 800x600 size, cells are 10x23 pixels and
the input-method row starts at y=575.
Chinese uses native 16x16 Unifont bitmaps centered in fullwidth 20x23 slots;
Western/CP437 uses Terminus 10x20 bitmaps. Box strokes extend through the row spacing. Font generation,
licenses, traditional mapping and file format are in [fonts/README.md](../fonts/README.md).
At the default 800x600 size, the final two scanlines remain available to pixel APIs.

The IME row is outside the application's B800 text grid. When CKBD's keep-prompt
setting is enabled, installation opens it through INT 16h/AH=29h. That callback
runs only after the display handler has restored the caller's stack and released
its busy guard, allowing CKBD's nested INT 10h/AH=14h drawing calls. Open prompt
text and copied 8x16 bitmap cells survive geometry changes, graphics excursions
and console state restoration. A closed prompt remains hidden during refresh;
returning to a text mode may reopen it according to CKBD's keep-prompt setting.
The bounded bitmap store is 1280 bytes plus a 10-byte validity map. Character
writes replace only the affected bitmap cells; source buffers need not stay live.
An unchanged prompt is not redrawn on every timer tick.

While the console is active, INT 10h/AH=0Bh follows text-mode semantics:
BH=0 changes the border using the selected palette entry, and BH=1 updates
the BIOS color-select flag without remapping text colors. MS-DOS `CLS` uses
this legacy CGA interface; forwarding it to a VBE graphics BIOS can otherwise
change the status row's colors. The application's palette remains intact.

`VESA /M:hex` selects a BIOS-provided physical mode, for example 104h for
1024x768 or 106h for 1280x1024. Selecting a larger surface alone retains the
logical text geometry. The viewport is centered,
including the input-method row. Native glyphs use the largest integer scale
from 1 through 4 that fits. If necessary to fit a larger integer scale, only
the three spacing rows are removed; the complete 20-row font ink is retained.
The 800x600 assembly path remains separate from the bank-spanning C rasterizer.
No protected-mode switch or framebuffer-sized conventional-memory allocation
is needed. Vendor widescreen mode numbers must be discovered, not assumed.

By default VESA queries mode 102h, then a bounded BIOS mode list. An explicit
`/M` requests exactly that mode. It requires VGA-compatible planar 4-bpp
graphics, 800x600 through 4096x2160, an even pitch up to 512 bytes, and a
readable/writable 64 KiB A000 window whose granularity divides 64 KiB.
Larger surfaces require isolated banked text storage. It rejects unsupported
layouts without hooking interrupts. This is a
specific backend requirement, not a claim that all VBE modes use VGA registers.
The [VBE specification](https://www.phatcode.net/res/221/files/vbe20.pdf) defines
the geometry, stride, window permissions/granularity and format fields used here.

## Mode ownership

Both drivers forward VBE queries to the original BIOS. During `4F02h` (set mode),
they suspend rendering and let nested BIOS INT 10h calls reach the original
handler. They forward the mode word and ES:DI without rewriting flags or buffer
pointers. Only `AX=004Fh` is success.

After a successful external graphics-mode selection, the BIOS owns the display:
HHBIOS timer and INT 10h drawing stay inactive, and CKBD is told this is an
external display. On failure, the previous display/keyboard ownership returns.
Legacy BIOS mode 3 reactivates Chinese display. VESA also reactivates its selected
console when a VBE caller selects native text mode 0..3. Applications may use
their own bank/WinFuncPtr routines while HHBIOS is suspended.

VESA appends one 64-byte ownership record to the BIOS's `4F04h` state buffer and
includes it in size queries. It validates size/segment bounds and returns native
BIOS errors. Restoration of either controller hardware (CX bit 0) or extended
register state (CX bit 3) changes display ownership. A valid private record can
restore the console; an unrelated or invalid record leaves rendering suspended.
For a validated console record, restoration re-establishes its physical mode
with the preserve-memory flag after the native restore, retaining the resulting
BIOS data and VGA palette. This avoids relying on a BIOS's extended-register
restore to reproduce the console's timing. External state buffers remain native.
Saved state does not include pixel
memory, just as the underlying VBE service does not save it. Successful external
bank, stride or display-start changes also relinquish console ownership,
including VBE 3.0 scheduled and stereoscopic display-start operations. Read-only
queries retain ownership. The input subfunction determines this policy; the
returned BX from 4F06h contains bytes per scanline, not a subfunction number.
The text and mouse cursors are erased before a layout change, while their original bank
and stride are valid. Failed BIOS calls restore ownership and the cursor unless
erasing it already failed a bank operation; that failure must leave rendering
and CKBD interception disabled.

These additional return/state paths belong to VESA. Legacy VGA's small mode-set
guard still leaves VBE text-mode selection under BIOS control and does not
integrate arbitrary `4F04h` restoration with its renderer.

## Memory and interrupt boundary

Where an extra image page and relocatable window are available, VESA keeps 32 KiB
of text pages in spare VRAM: eight 4 KiB pages at 25 rows, four 8 KiB pages above 25 rows. B800 is
mapped while applications run. Each outer drawing transaction snapshots the
active text page (up to 8000 bytes) in the resident transfer buffer before
switching to graphics bank zero. Refresh draws changed
cells, and restores the text bank. Classification conversions are copied back
to the text page. The shared `ZJXP.INC`, `FRM.INC` and `HZPOS.INC` use overridable
row bounds; their legacy defaults and classification rules are retained.
The installer starts beyond the complete visible plane and tests up to four candidate banks by
writing distinct words across all 32 KiB of B800 and clearing the complete
visible plane through A000, including every graphics bank on larger surfaces.
It accepts a bank only if every text word survives.
This verifies isolation even on BIOS/emulator mappings whose B800 bank address
differs from the planar A000 address; an advertised extra page alone is not
sufficient. It first probes the shared A000-BFFF VGA aperture, then the narrower
B800-BFFF aperture if necessary. This preserves planar scanout on implementations
that interpret B800-only decoding as CGA, while supporting implementations whose
shared aperture does not expose banked B800 memory. The selected bank and aperture
are retained across mode returns. SDL window captures check the resulting visible
pixels independently of the driver's plane-read API.

The read-only `AX=1410h` character-boundary query also works during drawing.
On a banked adapter, its CX points to this text snapshot; callers must not
write through it. A query outside drawing first refreshes the snapshot from
B800. Queries run on the caller's stack and preserve the occupied renderer
stack, so keyboard IRQ consumers such as EDIT 2.x can still complete a paired
deletion while a font read is in progress. Interrupts are masked only during
the bounded text snapshot/copy-back operations, not during rasterization
or XMS/EMS calls. The shadow is 8000 bytes and the banked snapshot is 8192 bytes.

Banked consoles keep the first VGA 8x16 font block in plane two of the text
bank, initialized from the ROM font. Ordinary linear B800 writes use only
plane zero so they cannot overwrite it. Programs such as MSBACKUP can update
this block directly and restore odd/even text addressing. Drawing temporarily
selects linear plane addressing and then restores the application's registers.
Refresh waits while a font downloader has temporarily unmapped B800.

Application-defined glyphs remain single-byte symbols through classification
and keyboard boundary queries. Their bitmaps fill the complete physical cell;
unchanged characters retain the configured console font. Font changes invalidate
only affected cached glyphs and cells, including software mouse cursors. The
4 KiB font copy is held in XMS/EMS and compared using the existing scratch buffer;
only a 256-byte glyph flag table is added to conventional data. A keyboard query
uses the still-mapped B800 page while that scratch buffer is in use.

HH20.FNT is loaded before mode installation into XMS, or EMS 4.0 using its
mapping-preserving move-region service. The resident cache holds 16 packed
glyphs (1120 bitmap bytes plus 64 bytes of keys/validity). Simplified and
traditional slot maps share deduplicated glyphs in the external allocation.
An additional 36 KiB in that same allocation holds the downloaded font and
preserves all text pages across font/row changes that require a physical mode switch. No DOS allocation occurs
during those transitions.
The loader closes its file and releases its allocation on installation failure.
No full framebuffer or font copy occupies conventional memory. Font lookup
failures leave the cache entry invalid and set the diagnostic error flag.

On a one-image adapter, the backend probes the VGA 128 KiB aperture. It uses a
line-aligned scanout wrap when that aperture aliases at 64 KiB, reserving B800
page zero. Other text pages are unavailable on this fallback. A strict 64 KiB
mapping without spare banked VRAM cannot expose B800 and is rejected. Failed
installation restores the previous mode. A later failed bank selection disables
rendering before further graphics access.

The COM contains no CRT and both compiler and assembler target 8086. INT 10h and
IRQ0 use a 2 KiB private stack with CS=DS=SS, preserving the interrupted stack,
segment registers and interrupt/direction flags. A busy guard prevents nested
rendering. Rendering restores all GC registers, the sequencer plane mask and
selected register indexes. BIOS/font calls run on the resident stack; resident
code performs no DOS allocation or file I/O.

DOS 5 UMBs are preferred; `/N` forces conventional memory. Allocation strategy
and UMB linkage are restored, and installer code/buffers and the DOS environment
are released. The 8 KiB text transfer buffer is retained only by the
banked backend. `AX=1411h` reports the actual resident byte count including PSP.

Uncoordinated TSRs that directly touch B800 or VGA ports during another
interrupt's rendering are outside this ownership contract. Bank-aware capture
can use the interface below and retry when busy. As with the legacy renderer,
direct hardware reprogramming without a BIOS mode transition cannot always be
detected.

## Public display interfaces

VESA provides text/cursor/page/scroll, teletype, string, palette and pixel BIOS
operations used by the console, plus HHBIOS font, prompt, bitmap, wide-text,
redraw, policy and Chinese-boundary interfaces. `AH=12h/BL=30h` selects
200/350/400 logical scanlines. `AX=1111h/1112h/1114h` selects the ROM
14/8/16-line font geometry, including the usual 80x43 and 80x50 sequences.
The resident limit is 50 rows and 80 columns. More than 25 rows requires banked
text storage. A taller physical mode is selected when necessary to fit native
glyphs and the prompt row; failed selection retains the previous grid.
`AX=1130h` forwards the ROM font pointer while returning logical height and last
row. Custom uploaded fonts are unsupported. The compatible `AH=16h`
bitmap query uses the existing 16-pixel reader; the 8x16 input bitmap API
scales at the rendering boundary. Normal text draws directly from HH20.FNT.
`AX=1406h` reports CX=171Ah (23 scanlines, 26 rows) and maximum pixel
coordinates 799/599 at the default size. Larger surfaces report their physical
pixel limits and unscaled raster height (20 or 23). Its framebuffer segment is diagnostic, not a promise of a
permanently mapped graphics window.

## Mouse contract

Load a native INT 33h mouse driver before VESA. It retains hardware input,
buttons, event timing, mickeys and sensitivity. While the Chinese console is
active, its native cursor stays hidden. HHBIOS paints a software text cursor
(AND/XOR masks) or a scanline-shaped text cursor, preserving Chinese halves
and all B800 bytes. The ordinary BIOS caret is suppressed where it overlaps.

Position queries/setters, button press/release positions, ranges, callbacks
(`0Ch`/`14h`) and maximum coordinates use logical 8x8 units per cell. Physical
viewport, scale and raster height are internal. The native driver's range
covers the complete physical surface; logical clipping happens after
translation so absolute mouse input is not rescaled to a cropped viewport.
Show/hide nesting, conditional exclusion (`10h`), cursor page (`1Dh`/`1Eh`)
and state save/restore (`15h`–`17h`, with an appended 64-byte record) are handled.
See Microsoft's [mouse function reference](https://msarchive.pcjs.org/mspl13/msdos/advdos/).

INT 33h and callback entry points use the caller's stack and explicit far
register packets. Callbacks translate coordinates and return to the application;
only the serialized renderer draws. Mouse reset temporarily exposes the physical
BIOS mode to the native driver. External graphics-mode ownership restores the
application callback and native cursor. Alternate modifier-specific callbacks
(`18h`/`19h`), light-pen emulation, direct mouse-driver entry calls and loading a
replacement mouse driver after VESA have not been validated. Emulator runtime
checks do not establish compatibility with every hardware mouse driver.

| VESA extension | Contract |
| --- | --- |
| `AX=1411h` | Returns AX=5356h, BX=ABI version 1, CX=descriptor size, ES:DI=read-only packed `struct surface` from `vesa.h`, SI=resident bytes, BP=banked-text flag, DX=framebuffer segment. Available while suspended. |
| `AX=1412h` | Read plane BX=0..3, 16-bit starting byte offset SI, byte count CX, destination ES:DI. Returns AX=0 on success, 1 on invalid bounds/inactive/bank failure, 2 when busy (retry). Source must remain within the complete plane (60000 bytes at 800x600); destination must not wrap. Zero count checks availability without bank changes. Caller serializes subsequent direct text reads against interrupts. |
| `AX=1413h` | Returns AX=4632h, BX=font storage (1 XMS, 2 EMS), CX=payload size rounded up to KiB, DX=sticky font-read error flag, SI=cell width, DI=cell height. EMS allocation rounds further to 16 KiB pages. |
| `AX=1414h` | Bank-spanning raw plane read: same plane, destination, count and status as 1412h, with a 32-bit byte offset in DX:SI. No redraw. A failed bank switch disables rendering and keyboard interception. |
| `AX=1415h` | Returns AX=5650h, BX/CX=physical viewport x/y, DX=integer scale, DI:SI=bytes per complete plane. AX=1406h reports the unscaled raster cell height; BDA character height remains logical. |

## API sequence

The [VESA specification's revision appendix](https://www.13thmonkey.org/documentation/Graphics/vbe3.pdf)
distinguishes the interfaces below. Implement and validate them separately:

| Interface generation | Work and validation |
| --- | --- |
| 1.0 core | Controller/mode query, set/get mode, bank control and state ownership. VESA uses optional geometry only when advertised. |
| 1.1 | External scanline/display-start calls are forwarded; successful layout changes suspend rendering. |
| 1.2 | Mandatory extended mode fields and image-page capacity used for banked text. Direct-color masks are decoded, but no high-color rasterizer is selected. |
| 2.0 | LFB address retained in the descriptor when advertised. Protected-mode/LFB rendering is not enabled. |
| 3.0 | Calls pass to BIOS. No CRTC refresh selection, linear-layout backend or protected entry is installed. |

The descriptor decoder also accepts other dimensions, padded strides, packed
8-bit and direct 15/16/24/32-bit formats with validated RGB masks. The console
selector admits only the implemented planar layout. DOSBox runtime fixtures
cover VBE 1.2 and later; 1.0/1.1 field handling has unit coverage only.

## Evidence

`test_vbe.py` compares native BIOS operation with READ5 + CKBD + VGA or VESA.
It uses `vesa_oldvbe`, `vesa_nolfb` and `svga_s3`, observing the reported VBE
version. Tests check controller/mode buffer guards, a bounded mode list, bank
set/get and complete framebuffer readback at 640x480 and 800x600 in packed 8-bit
modes. Window permissions, segment, size, granularity and scanline pitch come
from the BIOS. The application leaves its pixels live for 32 BIOS ticks before
reading them back, exposing erroneous timer drawing. Both INT 10h and the
mode-specific `WinFuncPtr` bank entry are exercised; the latter's AX return is
not assumed valid for VBE 1.x.

Returning to legacy mode 3 must restore exact Chinese glyph pixels in all four
VGA planes. A rejected mode must also leave that rendering functional. Production
INT 10h instructions run separately under Unicorn with success, failure and
absent-function responses, nested BIOS calls, distinct segment registers and
stack/register checks. All production modules still assemble for 8086.

Before the mode-set guard, the native BIOS framebuffer matched the test pattern
but the resident case corrupted it. The test therefore observes the original
failure, rather than only checking for a success return code.

`test_vesa.py` additionally checks exact Chinese pixels and every blank cell
at 800x600, all text pages across refresh and scrolling,
offscreen scrolling, prompt bitmaps, wide text, pixel bounds, GC/SEQ ownership,
state round trips and UMB/conventional MCB ownership. `test_vesa_api.py` executes
the linked C/ASM COM across foreign stacks with BIOS/allocator failure injection.
Native simplified/traditional glyphs and an edge-aligned cursor are checked
with both XMS and EMS in DOS. `test_font20.py` executes the linked loader and
cache with observable memory-manager calls, including short files, failed
moves, release on failure and retry after a failed cache miss.
Real editor movement, whole-character deletion and saved file contents are
checked by `test_vesa_application.py`. The regular mixed-text pixel suite also
runs against VESA. These establish framebuffer contents and behavior under
emulated BIOSes, not physical scanout, every VBE application or every card.
An additional guest shim hides only spare-image capacity: the one-image path
must either render exact pixels or reject installation with the previous text
mode restored. VGA memory mapping and ports remain the emulator's own.

## Rendering implementation and performance

`vesa.c` owns mode discovery, geometry validation, BIOS policy and ownership.
`vesa.asm` owns interrupt entry, VGA/bank access and the 800x600 planar fast path.
`vesa_raster.c` owns bank-spanning drawing, viewport placement and integer scaling.
`vesa_font.c` and `vesa_font.asm` own font loading, XMS/EMS moves and the glyph cache.
The classifier supplies character/cell coordinates independently of framebuffer
stride. Drawing batches changed text cells between bank selections, writes four
planes directly and makes no per-pixel BIOS calls. `VGA.ASM` is unchanged by this
implementation. Both rasterizers use 8086 arithmetic and banked access;
larger planes do not themselves require unreal mode or DPMI.
At 800x600, an instruction-level work-count test observes two bank calls per refresh for
idle, single-cell edits and full redraws, and no framebuffer writes on idle
refresh. This bounds work, not elapsed time on a particular graphics card.
Software cursor blinking adds its own small draws outside that text-refresh test.
At that size, prompt clear/output and wide strings also share a bank transaction across all
their glyphs; their work-count tests require just two bank calls per operation.

Other memory-access backends can be added without changing the classifier, but must be
compared using the same pixels and update regions:

| Path | Intended environment | Costs and lifetime to verify |
| --- | --- | --- |
| 16-bit banked, BIOS interrupt | Real mode or a compatible host | Bank crossings and BIOS calls; use returned granularity/stride |
| 16-bit banked, `WinFuncPtr` | BIOS advertising a callable entry | Same geometry, reduced call overhead; no per-pixel banking |
| 32-bit LFB via DPMI | Host providing physical device mapping | Map once where possible; selectors, callbacks and mappings must remain valid for the resident service |
| Unreal-mode LFB | Optional 386+ unmanaged real-mode environment | Segment-cache setup/maintenance, interrupts and A20; do not take over an existing protected-mode host |

DPMI's [physical mapping API](https://www.delorie.com/djgpp/doc/dpmi/api/310800.html)
returns a linear address for device memory. It does not, by itself, make that
mapping a permanent resource of a real-mode TSR. A resident backend must define
ownership across client exit and switching, and a valid execution/stack context
for callbacks. A selector obtained from an arbitrary foreground DPMI client
cannot simply be kept for later timer use. CPU-mode changes must respect the
host's control of protected/virtual-8086 execution; see
[Intel's system programming manual](https://cdrdv2-public.intel.com/774491/253669-sdm-vol-3b.pdf).

For host-assisted transitions, compare DPMI 0.9 real-mode callbacks (`0303h`)
with its raw mode-switch entry points (`0306h`), including their stack/context
requirements; both are described in
[Stacks and Mode Switching](https://delorie.com/djgpp/doc/dpmi/ch4.3.html).
Do not assume DPMI 1.0's resident-service APIs `0C00h/0C01h` are available on
Windows 95. Their [resident-provider lifecycle](https://delorie.com/djgpp/doc/dpmi/ch4.8.html)
also destroys the original LDT/IDT and requires per-client setup. A proposed
32-bit resident design must be tested with the targeted 0.9 hosts, not just with
a standalone host accepting newer APIs.

Batch work into consecutive scanlines or dirty rectangles. Reuse a selected bank,
and enter a protected rendering context for a batch, rather than for each pixel
or character. Font caching must be bounded and measured against XMS/EMS transfer
cost and conventional-memory use. Avoid a full framebuffer copy in conventional
memory merely to simplify the implementation.

Performance comparisons should include an idle screen, a single Chinese glyph,
short text edits, scrolling, a full redraw and regions crossing bank boundaries.
Record guest elapsed time, worst interrupt-disabled duration, bank/mode switches,
bytes written, resident conventional/UMB memory and font-cache storage. Check exact
pixels for every path before comparing speed. Separate fixture/pattern generation
from timed drawing. Emulator results are comparative evidence, not estimates of
ISA/VLB/PCI hardware performance. No renderer throughput benchmark has been
established yet; these are criteria for choosing the next implementation.

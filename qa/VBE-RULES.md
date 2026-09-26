# VBE coexistence and rendering

`VGA.COM` retains its 640x480 renderer. The independent `VESA.COM`, built from
`vesa.c` and `vesa.asm`, draws an 800x600, 16-color console. Load one display
driver at a time, after a font reader and optionally CKBD. The logical screen
remains 80x25 cells of 10x23 pixels; the input-method row starts at y=575.
Chinese uses native 20-pixel Noto CJK glyphs, and Western/CP437 uses Terminus
10x20 bitmaps. Box strokes extend through the row spacing. Font generation,
licenses, traditional mapping and file format are in [fonts/README.md](../fonts/README.md).
The final two scanlines remain available to pixel APIs.

VESA queries mode 102h, then a bounded BIOS mode list. It requires VGA-compatible
800x600 planar 4-bpp graphics, pitch 100, and a readable/writable 64 KiB A000
window. It rejects unsupported layouts without hooking interrupts. This is a
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
Legacy BIOS mode 3 reactivates Chinese display. VESA also reactivates its 800x600
console when a VBE caller selects native text mode 0..3. Applications may use
their own bank/WinFuncPtr routines while HHBIOS is suspended.

VESA appends one 64-byte ownership record to the BIOS's `4F04h` state buffer and
includes it in size queries. It validates size/segment bounds and returns native
BIOS errors. Hardware restoration changes ownership only when the hardware-state
mask is requested. A valid private record can restore the console; an unrelated
or invalid record leaves rendering suspended. Saved state does not include pixel
memory, just as the underlying VBE service does not save it. Successful external
bank, stride or display-start changes also relinquish console ownership.

These additional return/state paths belong to VESA. Legacy VGA's small mode-set
guard still leaves VBE text-mode selection under BIOS control and does not
integrate arbitrary `4F04h` restoration with its renderer.

## Memory and interrupt boundary

Where an extra image page and relocatable window are available, VESA keeps eight
4 KiB text pages in spare VRAM. B800 is
mapped while applications run. Each outer drawing transaction snapshots the
active 4000-byte text page in the existing resident transfer buffer before
switching to graphics bank zero. Refresh draws changed
cells, and restores the text bank. Classification conversions are copied back
to the text page. The original `ZJXP.INC` and `HZPOS.INC` are included unchanged.
The installer tests candidate banks at 64 KiB intervals, up to four, by
writing distinct words across all 32 KiB of B800 and clearing the complete
visible plane through A000. It accepts a bank only if every text word survives.
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
the bounded 4000-byte snapshot/copy-back operations, not during rasterization
or XMS/EMS calls. No additional resident text buffer is allocated.

HH20.FNT is loaded before mode installation into XMS, or EMS 4.0 using its
mapping-preserving move-region service. The resident cache holds 16 packed
glyphs (1120 bitmap bytes plus 64 bytes of keys/validity). Simplified and
traditional slot maps share deduplicated glyphs in the external allocation.
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
are released. The extra 4 KiB text transfer buffer is retained only by the
banked backend. `AX=1411h` reports the actual resident byte count including PSP.

Uncoordinated TSRs that directly touch B800 or VGA ports during another
interrupt's rendering are outside this ownership contract. Bank-aware capture
can use the interface below and retry when busy. As with the legacy renderer,
direct hardware reprogramming without a BIOS mode transition cannot always be
detected.

## Public display interfaces

VESA provides text/cursor/page/scroll, teletype, string, palette and pixel BIOS
operations used by the console, plus HHBIOS font, prompt, bitmap, wide-text,
redraw, policy and Chinese-boundary interfaces. Font reprogramming is unsupported;
`AH=11h/AL=30h` still forwards the ROM font query. The compatible `AH=16h`
bitmap query uses the existing 16-pixel reader; the 8x16 input bitmap API
scales at the rendering boundary. Normal text draws directly from HH20.FNT.
`AX=1406h` reports CX=171Ah (23 scanlines, 26 rows) and maximum pixel
coordinates 799/599. Its framebuffer segment is diagnostic, not a promise of a
permanently mapped graphics window.

| VESA extension | Contract |
| --- | --- |
| `AX=1411h` | Returns AX=5356h, BX=ABI version 1, CX=descriptor size, ES:DI=read-only packed `struct surface` from `vesa.h`, SI=resident bytes, BP=banked-text flag, DX=framebuffer segment. Available while suspended. |
| `AX=1412h` | Read plane BX=0..3, source byte offset SI, byte count CX, destination ES:DI. Returns AX=0 on success, 1 on invalid bounds/inactive/bank failure, 2 when busy (retry). Source is bounded by 60000 bytes; destination must not wrap. Zero count checks availability without bank changes. Caller serializes subsequent direct text reads against interrupts. |
| `AX=1413h` | Returns AX=4632h, BX=font storage (1 XMS, 2 EMS), CX=payload size rounded up to KiB, DX=sticky font-read error flag, SI=cell width, DI=cell height. EMS allocation rounds further to 16 KiB pages. |

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
`vesa.asm` owns interrupt entry, VGA/bank access and the planar rasterizer.
`vesa_font.c` and `vesa_font.asm` own font loading, XMS/EMS moves and the glyph cache.
The classifier supplies character/cell coordinates independently of framebuffer
stride. Drawing batches changed text cells between bank selections, writes four
planes directly and makes no per-pixel BIOS calls. `VGA.ASM` is unchanged by this
implementation. Unreal mode and DPMI would add transition and residency costs
without addressing a need of this 60,000-byte-per-plane backend.
An instruction-level work-count test observes two bank calls per refresh for
idle, single-cell edits and full redraws, and no framebuffer writes on idle
refresh. This bounds work, not elapsed time on a particular graphics card.
Software cursor blinking adds its own small draws outside that text-refresh test.
Prompt clear/output and wide strings also share a bank transaction across all
their glyphs; their work-count tests require just two bank calls per operation.

Wider-memory backends can be added without changing the classifier, but must be
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

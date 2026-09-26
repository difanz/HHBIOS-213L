# VBE coexistence and rendering

HHBIOS's current VGA renderer draws a fixed 640x480 planar display. An application
that selects a VBE mode owns that mode's framebuffer and VGA register settings.
The resident driver must stop applying its old planar drawing rules there.
This coexistence contract is separate from drawing Chinese text inside a VBE
mode, which needs a renderer for the advertised geometry and pixel format.

## Mode ownership

`VGA.COM` forwards VBE controller/mode queries and bank operations to the original
BIOS. During `4F02h` (set mode), it suspends its timer renderer and lets nested
BIOS INT 10h calls reach the original handler. It forwards the entire mode word
and ES:DI without rewriting flags or buffer pointers. Only `AX=004Fh` is success.

After success, the BIOS owns the display: HHBIOS's old timer renderer and planar
INT 10h drawing stay inactive, and CKBD is told this is an external display mode.
On failure, HHBIOS restores the previous timer state and retains its display and
keyboard state. Returning through legacy INT 10h AH=00h, AL=03h activates the
existing Chinese display again.

A mode selected with `4F02h`, including a native text mode, currently remains
under BIOS control. Returning to the HHBIOS Chinese view through a saved VBE
state or through `4F02h` text-mode selection is not implemented. Arbitrary
`4F04h` hardware-state restoration while HHBIOS owns the display is not covered
by the mode-set guard. These paths need their own state-transition design and
tests; successful banked-mode coexistence does not establish full VBE support.

## API sequence

The [VESA specification's revision appendix](https://www.13thmonkey.org/documentation/Graphics/vbe3.pdf)
distinguishes the interfaces below. Implement and validate them separately:

| Interface generation | Work and validation |
| --- | --- |
| 1.0 core | Controller/mode query, set/get mode and bank control: current coexistence tests. Save/restore state still needs integration with HHBIOS ownership. |
| 1.1 | Logical scanline length and display start; exercise padded strides, scrolling and pages. |
| 1.2 | DAC width and direct-color formats; use returned masks. Extended mode-info fields become mandatory here; 1.0/1.1 callers must check their presence. |
| 2.0 | Linear framebuffer, protected-mode bank/display/palette entry points, extended information buffers. Keep banked operation available. |
| 3.0 | Additional protected-mode entry, refresh/CRTC controls, separate linear-mode layout fields and buffering operations. |

The resident coexistence handler does not parse optional mode fields or assume
a VBE version. Actual DOSBox fixtures cover VBE 1.2 and later, not historical
1.0/1.1 BIOS implementations.

## Evidence

`test_vbe.py` compares native BIOS operation with READ5 + CKBD + VGA resident.
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

These tests establish memory contents and driver behavior under emulated BIOSes.
They do not establish physical scanout, every VBE application, or every card.

## Rendering implementation and performance

The planned VESA renderer is an independent `VESA.COM`, built from `vesa.c` and
`vesa.asm`. These production files will be introduced with working rendering
code, not empty placeholders. `VGA.ASM` retains its existing renderer and the
small coexistence guard; adding VESA rendering does not require converting it
to C or linking it with the new driver.

`vesa.c` owns mode discovery, clipping, dirty-region management and pixel-format
conversion. `vesa.asm` owns interrupt entry, bank calls, mode transitions and
measured memory-copy bottlenecks. Their interface passes explicit buffers,
geometry and update spans; it must specify segment/selector ownership, register
preservation and interrupt/stack requirements. Access backends must not expose
unreal-mode or DPMI assumptions to the character classifier.

Load one display driver at a time. The VESA driver should reuse the existing
font and keyboard service contracts, with separate tests for those public
interfaces, rather than stacking two competing renderers on INT 10h and IRQ0.
Build and test each driver independently. A 16-bit C implementation can retain
the 8086 baseline; optional wider-memory backends can state their own CPU
requirements without changing the legacy VGA target.

Compare these access paths using the same pixels and update regions:

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

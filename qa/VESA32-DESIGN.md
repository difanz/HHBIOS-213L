# Protected-mode VESA renderer

Displaying Chinese must not require loading an additional DOS extender or DPMI
host. The default remains the freestanding 386 real-mode TSR, with 32-bit
register loops and batched rendering. Improve this path independently of any
protected-mode work.

A separate `wcc386` rendering core is an optional research direction for systems
with an existing, verified host. Its bridge would target DPMI 0.9 services;
detecting a host alone is not sufficient to enable it. The installed `VESA.COM`
has no protected-mode backend, and SETUP must not add a host just for rendering.

## Existing boundaries

`tools/build-vesa.sh` builds a freestanding 386 real-mode COM with `wcc`.
`vesa_raster.asm` already uses dword registers and transfers in USE16 code.
Changing compiler alone will not remove the planar framebuffer's bank changes,
plane selection, or video-memory reads.

`int10_handler` and `int8_handler` in `vesa.asm` serialize entry and switch to a
private stack. `RefreshConsole` handles text changes, the IME status row, and
mouse/caret overlays. `video_begin` snapshots the application's B800 page before
mapping graphics memory; `video_end` restores the application mapping and VGA
registers. These interfaces must remain valid during a protected-mode render.

## Host choice and resident lifetime

An extender loads and supports an application. A DPMI host supplies protected
mode, descriptors, memory and callbacks. VCPI is a lower-level mechanism a host
can use under a virtual-8086 memory manager. They are not three interchangeable
renderer APIs. The [DPMI specification, introduction and execution model][dpmi]
describes this distinction.

Use `INT 2Fh/1687h` to discover an existing host and its 32-bit support. Never
replace a Windows DPMI host by loading a second standalone host. The standalone
hosts below were loaded on private QA disks to study the interface; they are
not proposed additions to HHBIOS startup.

`INT 31h/0303h` supplies a real-mode callback into protected-mode code. Callback
code, data and stack must be resident and its entry state must be handled
explicitly; a normal C function is not an interrupt trampoline. Raw switching
through `0306h` needs the state handling defined by `0305h`, so it is not the
initial implementation choice. See the [callback][callbacks] and
[raw-switch][rawswitch] contracts.

DPMI 1.0's `0C00h/0C01h` resident-provider interface is for services offered to
protected-mode clients. The [specification explicitly distinguishes][tsr]
real-mode services, for which it describes invoking DOS `INT 21h/AH=31h` through
`0300h`. Therefore the absence of `0C01h` does not by itself rule out this design.
Conversely, keeping the host resident does not prove that the client's memory,
selectors and callbacks survive other clients. This requires execution tests.

CauseWay provides a documented TSR entry but does not provide a complete unload
operation for it. Its [manual][causeway] also documents preferring VCPI unless
the DPMI path is requested. It is useful for the lifecycle experiment, but its
ordinary application startup and TSR exit are not a finished driver runtime.

## Lifecycle experiment

A separate Watcom 32-bit program retained a 128 KiB buffer above 1 MiB and
installed a real-mode callback. After returning to DOS, a 16-bit program and
four 32-bit programs invoked it. The worker checksummed the entire buffer;
the expected result was `46509DC5`, with a monotonically increasing call count.
The foreground binaries used DOS/4GW, DOS/32A, CauseWay and PMODE/W. Each was
followed by another real-mode call. These were small clients, not the actual
EDIT, DOSSHELL or Turbo Vision applications.

The experiments booted MS-DOS on private QA disk copies. They exercised neither
the renderer nor hardware-interrupt entry. They do not establish a speedup,
safe unloading, or compatibility with Windows 95.

| Configuration | Observed result |
| --- | --- |
| EMM386, CauseWay VCPI backend | All nine callbacks returned the expected buffer checksum. |
| HDPMI32 with separate client address contexts (`-a`), forced DPMI backend | All nine callbacks passed, with both CauseWay TSR exit and the real-mode DOS TSR exit route. |
| Default HDPMI32, forced DPMI backend | Initial real-mode callback passed; the sequence stalled after the DOS/4GW client's output. |
| CWSDPMI, forced DPMI backend | Same failure boundary as default HDPMI32. |
| CauseWay raw backend with HIMEM and no EMM386 | Initial resident call passed; the foreground-client sequence did not complete. |

The two failing DPMI configurations also stalled when the foreground DOS/4GW
program did not call the service. Without the experimental resident program,
both hosts completed the four foreground programs. Changing the TSR exit route
did not cure the failure. This isolates a coexistence problem in the tested
resident/extender/host combination; it does not identify a defect in the host
alone. A bridge without CauseWay's application runtime remains to be tested.

Host installation alone was not accepted as evidence of using that host:
CauseWay's backend flags were inspected. Early runs with an external host
loaded but CauseWay still choosing VCPI were excluded from the DPMI results.

HDPMI documents both [shared and separate client contexts][hdpmi]. The separate
configuration provides a controlled research baseline. Its passing result does
not justify adding a host to the distribution's startup. CWSDPMI and Windows
must have their own verified paths or retain the existing renderer. Do not infer
resident-client support from a DPMI version number alone.

## Renderer and bridge

The low-memory part owns the interrupt chain, mode ownership, B800 access,
keyboard boundary queries and the transition into/out of a rendering batch.
The 32-bit core owns the expanded glyph cache, composition buffers and raster
loops. Exchange fixed-width geometry, offsets and bounded spans; never pass a
16-bit near pointer as a flat pointer. Keep DPMI calls out of the raster code.

Allocate and lock the service's resources during installation. An interrupt
must not allocate memory, open files, or fault in a pageable font/cache page.
Use a locked private flat stack for C. Copy callback state before enabling
interrupts; preserve the existing busy guard and bounded keyboard queries.
Nested requests cannot wait for the renderer they interrupted. Timer refreshes
can leave dirty work pending; BIOS operations with synchronous results must
retain their existing semantics.

Enter protected mode for a batch, not a character, pixel or scanline. Group
planar output by bank/plane where this preserves the same pixels and ordering.
The core can write through an appropriately mapped graphics window; bank/port
setup remains an adapter operation. A BIOS-only bank change may need a real-mode
transition, but that transition belongs at the bank boundary. Never keep the
whole high-resolution repaint under CLI to simplify the callback.

Use bounded tile or strip buffers first. At 1920x1080, one 32-bpp canvas takes
7.91 MiB and two take 15.82 MiB, before fonts, the host and applications. Flat
addressing allows larger buffers; it does not make full double buffering a good
default for a 16 MiB DOS machine. Dirty spans and a larger hot glyph cache are
useful independently of a full framebuffer shadow.

## VBE and direct text memory

First retain the existing planar modes, B800 bank isolation, custom VGA glyphs,
status row, and mouse behavior. A 32-bit core and an LFB backend are separate
changes. The existing decoder requires a usable banked window even when it
records `PhysBasePtr`; that field alone is not LFB support.

The [VBE specification][vbe] requires mapping `PhysBasePtr` through the host
(DPMI `0800h`); VBE 3.0 may provide different linear pitch and color masks.
Its `4F0Ah` protected-mode interface can avoid some BIOS transitions but is
optional in VBE 3.0 and requires the advertised I/O/MMIO access.

Crucially, VBE `4F05h` bank switching is not supported while using the linear
framebuffer memory model. The current B800 compatibility mechanism cannot
simply be carried into LFB mode on that assumption. An LFB backend needs an
independently verified text aperture or host-specific virtualization of it.
A private RAM text shadow alone cannot observe stores by an unmodified DOS
program to physical/virtual B800. DPMI access to an LFB does not solve that.

## Implementation order and acceptance

1. Profile and optimize the existing renderer: batch bank/plane operations,
   reduce video-memory reads, retain useful glyphs and avoid redundant work.
   Separate composition from presentation without requiring a mode switch.
2. If the optional 32-bit worker is pursued, first prove callback ownership,
   interrupt entry and complete unload on existing hosts. Its total memory cost
   must include the bridge and any retained host resources. Keep the current
   renderer available without an extender or DPMI host.
3. Preserve the existing planar presentation and shared Chinese/frame rules.
   Exercise direct B800 writes, downloadable VGA fonts, keyboard activity during
   repaint, status bar and mouse overlays, graphics excursions, and nested
   foreground extenders. Verify allocation/lock failures and repeated unload.
4. Measure single-character latency, scrolling, sparse updates and full-screen
   repaint at equal CPU settings. Count transitions, banks, video reads/writes
   and missed timer/keyboard service alongside elapsed time.
5. Treat additional host configurations and LFB presentation as independent
   optional work. Windows 95 requires an actual environment before claiming
   compatibility. Do not introduce a general-purpose host into the normal boot
   sequence or build a private replacement merely to obtain 32-bit addressing.

[dpmi]: https://docs.pcjs.org/specs/dpmi/1991_03_12-DPMI_Spec_v10.pdf
[callbacks]: https://www.delorie.com/djgpp/doc/dpmi/ch4.6.html
[rawswitch]: https://www.delorie.com/djgpp/doc/dpmi/api/310306.html
[tsr]: https://www.delorie.com/djgpp/doc/dpmi/api/310c01.html
[causeway]: https://open-watcom.github.io/open-watcom-v2-wikidocs/cw.html
[hdpmi]: https://github.com/Baron-von-Riedesel/HX/blob/master/Src/HDPMI/HDPMI.TXT
[vbe]: https://www.cs.utexas.edu/~dahlin/Classes/439/ref/hardware/vbe3.pdf

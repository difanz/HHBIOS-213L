# EMS, XMS and DOS extender compatibility

Use READ5 with an XMS manager, or READ4 with an EMS manager and a page frame.
The font reader remains a real-mode resident service. A protected-mode client
can call its INT 7Fh interface through DPMI's real-mode interrupt simulation.
READ2 provides conventional-memory storage when these managers are unavailable.

## Memory ownership

| Reader | Storage and interfaces | Constraint |
| --- | --- | --- |
| READ4 | EMS allocation/free (INT 67h AH=43h/45h), page mapping (44h), save/restore map (47h/48h) | 16 pages, or 256 KiB, per distinct font; needs a page frame |
| READ5 | XMS discovery (INT 2Fh AX=4300h/4310h), allocation/free/move (09h/0Ah/0Bh) | Needs a sufficiently large free XMS block for each distinct font |
| READ6 | CMOS memory size and BIOS INT 15h AH=87h physical-memory copies | Standalone unmanaged DOS only; no reservation visible to another allocator |
| READ3 | Legacy RAM-disk layout and BIOS physical-memory copies | Layout-specific; not validated with modern hosts |

READ4 saves the complete EMS page-frame map on its own font handle before
mapping a glyph, then restores it before returning. The calling application's
handle and saved mapping slot are untouched. The short save/map/copy/restore
sequence runs with interrupts disabled; the prior interrupt state is restored.
Font installation preserves the caller's map too. Allocation, save or map
failures close the input file and release newly allocated handles as applicable.
These follow the TSR requirements in the original
[LIM EMS specification](https://github.com/OpenRakis/Spice86/wiki/LIM-4.0-Specs-(EMS)).

READ5 uses handles and the manager's move service, without locking XMS blocks
or retaining their physical addresses. Glyph transfers are 32 bytes into a
resident conventional/UMB buffer. XMS owns A20 handling during these moves;
the driver does not take over the host's memory allocator. See the original
[XMS specification](https://jnz.dk/swag/FAQ/0053.PAS.html).

READ6 rejects an already-present DPMI host, XMS manager or EMS manager before
reading CMOS or copying a font. This check cannot prevent a manager or extender
started **after** READ6 from reusing its unreserved memory. Do not combine READ6
with such programs, or carry it into Windows. R16's automatic selection does
not make raw memory safe: if it reaches READ6 in a managed environment, that
reader will reject installation. Select READ4/READ5 with sufficient managed
memory, or use a conventional/disk reader.

READ4's fixed allocation does not support font files over 256 KiB. Its legacy
read loop does not validate oversized files. READ5's glyph path still does not
report a failed XMS move, and uses a shared descriptor/result buffer; nested
calls from arbitrary third-party interrupt handlers are not covered by the
coexistence tests. INT 7Fh returns a temporary buffer, which callers must copy
before another font request. These are limits, not evidence of universal
compatibility with every TSR or memory manager.

## Runtime matrix

The following cases run under both DOSBox 0.74-3 and DOSBox-X. Executable hashes
in each run identify the actual inputs; these versions do not constrain users.

| Client / host | Font readers | Observations |
| --- | --- | --- |
| Real-mode Watcom client | None, READ4, READ5 | Four competing EMS pages, caller's saved map, exact simplified/traditional glyphs |
| DOS/4GW, DOS/32A, CauseWay, PMODE/W | None, READ4, READ5 | DPMI real-mode calls, live 2 MiB allocation, competing EMS pages, timer activity, unload |
| DJGPP + CWSDPMI r7 | None, READ4, READ5 | Same checks with an existing persistent host |
| DJGPP + HDPMI32 3.23 (HX 2.23) | None, READ4, READ5 | Same checks with an existing persistent host |
| Borland C++ 3.1 / Turbo C++ 3.0 DPMI16BI | READ4, READ5 | Real editor movement, Delete, Backspace and exact saved Chinese bytes |
| Existing XMS, EMS, CWSDPMI or HDPMI32 | READ6 | Installation refused, memory and vectors unchanged |

The shared client alternates three Chinese characters and two distinct fonts
for 64 passes. While allocations and EMS maps are live, it repeatedly changes
Chinese B800 text and waits at least 32 BIOS ticks in total. The protected-mode
font cases load VGA and CKBD. The checks compare all returned glyph bytes,
the current EMS mappings **before** restoring the client's saved context, that
saved context after restoration, and the entire protected allocation. Font and
HHBIOS unload must return XMS, EMS, DOS/UMB ownership and vectors to baseline.
Standalone hosts are warmed up before the resident-memory comparison, and their
own unload must restore the earlier baseline too.

These observations establish memory coexistence and API results. The extender
client does not capture pixels; the separate framebuffer and application tests
provide display evidence. The timer check does not exercise every possible
interrupt interleaving or force host paging under memory pressure.

The pre-fix READ4 failed the competing-map case in real mode and under DOS/4GW,
DOS/32A and PMODE/W; CauseWay did not expose that failure in this fixture.
An independent test reproduced mapping loss during font installation.
Unicorn tests execute production READ4 instructions with failed allocation,
save and map calls, checking map restoration, stack balance and cleanup.
These controls distinguish a detected driver defect from a build or host error.

## Windows 95: interface audit, no runtime claim

No Windows 95 environment was available for this audit. Passing the standalone
hosts above does **not** establish compatibility with Windows 95's DPMI host,
VMM, VGA virtualization or task switching.

Windows 95 provides DPMI 0.9, with selected coprocessor extensions; clients that
require other DPMI 1.0 services can fail. This is documented in Microsoft's
[KB Q121962](https://helparchive.huntertur.net/document/106868) (archived copy).
DOS/4GW can use an existing Windows DPMI server instead of installing its own.
A VCPI-only extender that needs control of the machine is a different case,
as described by [Microsoft's compatibility history](https://devblogs.microsoft.com/oldnewthing/20230829-00/?p=108661).

The reviewed font-call path uses DPMI 0.9
[INT 31h AX=0300h](https://www.delorie.com/djgpp/doc/dpmi/api/310300.html): a
50-byte register structure, real-mode segment values, host-provided stack and
IRET return. The returned font segment is a real-mode paragraph address, not a
protected-mode selector; clients must access it through a suitable low-memory
mapping or copy service. READ4 restores the shared EMS frame, and READ5 uses
managed XMS handles. Neither reader needs a private protected-mode host.
This supports an interface-level compatibility expectation, not a test result.

Remaining Windows checks require an actual VM or machine:

- Install HHBIOS inside a DOS session using READ5, and READ4 when the session
  exposes EMS. Check the session's XMS/EMS limits and complete unload.
- Exercise DOS/4GW and Borland's 16-bit client under the Windows host; include
  memory pressure and repeated switches between DOS applications.
- Check Chinese rendering, keyboard hooks and IRQ-driven refresh in full-screen
  and windowed sessions, including background/foreground transitions. HHBIOS
  uses VGA ports and resident interrupt handlers, which depend on virtualization
  beyond the DPMI memory API.
- Keep READ6 out of the Windows session and out of the boot sequence leading
  into Windows. “Restart in MS-DOS mode” is a separate environment and still
  requires checking which memory managers it loads.

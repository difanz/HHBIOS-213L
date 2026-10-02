# What is left of the linear-console latency

Samples are DOSBox-X at `cycles=30000`, `core=normal`, `HH20.FNT`, PIT
channel 0 divided by 1193. The harness is `qa/harness/lfbbench.c`. Byte
counts are the stable contract. A pair that differs by about 65536 counts
is one PIT period; the sample that agrees with a nested probe is the one
used below. Idle `AX=1418h` is 0 throughout.

The painter under test is the 32-bit glyph path in `qa/lfb-fastpath.md`.
Full hanzi is 249 ms and 248 ms at 114h and at 117h (956800 and 960000
bytes). Before the scale-2 change below, 245h was 736 ms and 790 ms
(3334400 bytes).

## Measured split

Probes were temporary builds, not shipped. They skip one layer of a full
hanzi refresh and leave the classifier, font cache, and dirty-map walk in
place.

| Layer | 114h / 117h | 245h, old per-column path |
| --- | ---: | ---: |
| Real mode: space scan, classifier, font hit, call overhead | 30 ms | 86 ms |
| Protected-mode entry and exit, no pixels | 9 ms | 8 ms |
| Bit walk or per-column loop, no framebuffer store | 166 ms | 530 ms |
| `REP STOS` / per-pixel store | 44 ms | 112 ms, then 166 ms |
| Full hanzi | 249 ms | 736 ms, then 790 ms |

117h matches 114h because both are an 80×25 grid at scale 1. The 245h real
mode was slower because every glyph was unpacked in 16-bit C before the
per-column loop. The two 245h store times are the two passes of one run;
both wrote 3334400 bytes. Scroll stays a copy: 26 ms at 114h/117h and 24 ms
at 245h. A blank frame is the 16-bit horizontal fill, not this painter.
Its PIT pair is still one period apart at 114h/117h and is not a painter
result.

About 2000 protected-mode entries run in a full hanzi frame (one per
half-cell). The 9 ms entry total is about 4.5 µs each. The interrupt-off
window is that one half-cell, not the 249 ms frame. There is still no
`STI` while PE is set.

## Scale 2 now uses the packed painter

`font_draw` used to unpack whenever `pixel_scale` was not 1, then walk
columns. The linear painter already scales a packed row. Linear consoles
now take the packed path at every scale. Planar scaling still unpacks.
Dumped cells at 114h and 245h match the previous image byte for byte.

245h full hanzi moved from 736/790 ms to 403/402 ms. Bytes stayed
3334400. 114h and 117h stayed 249/248 ms. Idle stayed 0. One ASCII line
at 245h moved from 67 ms to 57 ms. The image link at that measurement was `0xFEE9`.

## Ranked leftovers

| Option | Expected gain | RAM | CLI | Verdict |
| --- | --- | --- | --- | --- |
| Packed painter at scale 2 | 245h 736 → 403 ms, measured. 114h unchanged | 0 | one glyph | Done |
| Runtime cache of expanded half-cells, 8 KiB | Up to the 166 ms bit walk on the 8-glyph bench, if every blit hits. A mixed screen misses | 8 KiB conventional, not in the COM | one glyph | Later |
| Same cache, 4 KiB | About 0 on this bench | 4 KiB conventional | one glyph | No |
| Copy a repeated scale row instead of walking it again | 245h only, tens of ms, not measured | 0, but the blob does not fit | one glyph | Later |
| One PM session for the whole refresh | 9 ms | 0 | the whole 249 ms frame | No |
| Move the classifier into the 32-bit blob | A fraction of the 30 ms real-mode side | 0, and the COM cannot hold it | one glyph or the frame | No |
| Unreal FS | The same 9 ms, and the bit walk grows 66h prefixes again | 0 | interrupts can reload FS | No |
| Precomputed scale tables, wider RLE, skip blank glyph rows | Noise. `BSR` is already one run. A blank row is already one store. Scale 1 multiplies by 1 | 0 | — | No |
| EXE or overlays | No paint change. See below | — | — | No |
| VCPI paint or install path | Rejected. One VCPI client at a time; a resident console blocks games and extenders. Not a latency win | — | — | No. Out of scope |
| DPMI dual path, bundled or required | Rejected for the product. Normal DOS does not load a DPMI host, and this TSR must not require or ship CWSDPMI or any other server | — | — | No |

### 4 KiB and 8 KiB of conventional scratch

A scale-1 half-cell is 10×23×2 = 460 bytes of RGB565. The bench uses 8
hanzi codes, 16 half-cells, 7360 bytes. An 8 KiB arena holds that working
set, so a later frame could replace the 166 ms bit walk with a copy of
pixels that still have to be stored. The store is 44 ms today. A perfect
hit would land near 249 − 166 = 83 ms on this bench only. A page of
distinct hanzi does not fit in 16 slots, and a different attribute is a
different slot. 4 KiB holds 8 half-cells. This bench cycles all 16 before
it repeats one, so an 8-slot cache misses. 4 KiB does not help this
measurement.

The arena must be a DOS allocation after install, not bytes in the image.
`S_UMB` asks for the resident size only, then restores the allocation
strategy, so a later low-memory `AH=48h` does not grow the UMB block.
Baking 8 KiB into the COM is the opposite: the file cannot pass `0xFF00`,
and the banked resident image is already 60832 bytes against the 62 KiB
test cap. The cache lookup itself also does not fit. The link is
`0xFEF1`, 15 bytes under the COM limit, and the tail segment moves after
4 more bytes of code.

### Whole-frame protected mode, unreal mode, classifier

The entry probe is 9 ms, not a reason to hold CLI across 249 ms. Moving
the dirty-map walk into the 32-bit blob means rewriting the shared
classifier and the font cache. The whole real-mode side is 30 ms. Unreal
mode saves the entry and puts the 166 ms bit walk back under operand-size
prefixes, and an interrupt that reloads FS still faults. None of these
beats the packed scale-2 change, and none is worth the CLI.

## COM, EXE, and overlays

The file is a COM because the hot path is a near tiny model: `DS=SS=CS`,
near C pointers, and a raw copy onto a UMB. `S_UMB` allocates
`resident_paragraphs` with strategy `41h` and `rep movsb`s that many
bytes. It does not allocate the whole file.

| Image | Offset | Bytes | Kept after install |
| --- | ---: | ---: | --- |
| Load image (`Memory size`) | `0xFEF1` | 65265 | Only long enough to install. `LOADHIGH` of the file needs a hole this big |
| LFB resident (`banked_text=0`, `resident_end`) | `0xCD55` | 52565 | Yes. This is the UMB request for a direct-color console |
| Banked resident (`image_end`, includes `text_transfer`) | `0xED60` | 60768 | Yes, when the 64 KiB text window is kept |
| `INIT_TEXT` | `0x1191` | 4497 | No. Option parse, VBE probe, font file decode |
| `text_transfer` | `0x2000` | 8192 | No on the LFB path. Yes if `banked_text` is set |

The file on disk is 65009 bytes (`Memory size` minus the `ORG 100h` prefix),
8 bytes above the previous `0xFEE9` image and 15 bytes under `0xFF00`.
`resident_end` moved down 70 bytes and `image_end` moved down 64. The
resident stack is 1040 bytes plus the `0xA55A` marker. The packed-glyph
arena is still 2176 bytes, with 28 live slots. `large_glyph` and
`doubled_glyph` are one 624-byte object (two 312-byte halves). A 24×64
record is 384 bytes and is staged at the start of that object.

What has to stay for a Chinese LFB console: the INT 10h, INT 08h, INT 33h,
and INT 2Fh hooks; the 8000-byte shadow; the 1040-byte stack; the glyph
cache; the private GDT and the 32-bit painter; the real-mode bank painter;
the classifier and `font_draw`. Init code and, on the LFB path, the
8192-byte transfer buffer are already outside the resident image. Little
else is cold. An EXE does not discover a hidden 20 KiB.

An MZ EXE can be larger than 64 KiB and can put install code in another
segment. The resident hot path would still be one near segment, or every
pointer in the painter and the classifier changes. The UMB copy is a byte
copy with no relocation fixups. An EXE's segment fixups would be wrong
after that copy unless the resident piece stayed a tiny image, which is
the COM we have. `LOADHIGH` of an EXE still needs a hole for the load
image before the program shrinks. The driver's own UMB request is already
the smaller resident size. Packaging does not make a 51 KiB LFB TSR fit
where a 51 KiB allocation failed, and it does not speed the painter.

Watcom overlays keep seldom-used code on disk. The overlay manager has to
stay resident and has to call DOS to read the file. This TSR does not call
DOS after install. Paint, the timer hook, and INT 10h cannot page an
overlay in. Install-only code is already discarded with `INIT_TEXT`.
Overlays do not shrink the hot path and they are a bad fit for a FreeDOS
or Win95 DOS box, where the file handle and the DOS busy flag are not ours.
They do not help latency.

Recommendation for the image we have: stay a COM. The paragraphs above
are why an EXE or an OVL is not smaller or faster by itself. A glyph
cache, if built, is 8 KiB of conventional memory at runtime, not bytes
baked into the image. Slimmer packaging stays on the latency list only
where it actually shrinks the resident image UMB install keeps.

## Hosts that already own protected mode

The shipping painter does not call VCPI or DPMI, and it does not load
or require a server. When PE is clear, a private GDT and a short CR0
session are legal. When PE is already set (Win95, EMM386, JEMM), that
session is not. A mode that still has a 64 KiB window is painted
through the window. A mode with neither a usable window nor a legal
linear map fails the direct-color console and leaves the planar
driver. VCPI and DPMI are not product paths around that.

### What each host actually is

EMM386 and JEMM run the guest in V86. CR0.PE is set, a pager owns CR3,
and `LGDT` or a write to CR0 from the guest faults. The same driver
usually publishes UMBs. Unless it was started with `NOVCPI`, it also
publishes VCPI. The EMS page frame is a 64 KiB window in upper memory.
It is not a map of `PhysBasePtr` (here `0xE0000000`).

A Win95 DOS box is V86 under the Windows VMM, not under EMM386. Windows
does not hand that box ring 0. A VCPI mode switch there is the conflict
already called out: it faults, or it is refused. Windows does answer the
DPMI installation check. DPMI clients run at ring 3 in the host's address
space. They do not load their own GDT, and they cannot clear PE.

HIMEM alone does not set PE. It is not why the linear console aborts.

### Detection

`SMSW` bit 0 is the test the painter already uses. PE clear means path A
is legal. PE set means a raw CR0 switch is not.

Windows enhanced mode is INT 2Fh `AX=1600h`. `AL` below `80h` and not
zero is a Windows version (`AL=3` for Windows 3.x, `AL=4` for Windows 95
and 98). `AL=0` or `AL=80h` means that check did not find Windows. This
is the Win95-hostile test. If it says Windows is running, do not call
VCPI even when INT 67h answers.

VCPI presence is INT 67h `AX=DE00h`, and only after the INT 67h vector
points at a real EMS driver (`EMMXXXX0` at offset `0Ah` of that segment).
A bare INT 67h with no driver is a crash. `AH=0` means a VCPI server
answered. `NOVCPI` and `NOEMS` builds still leave PE set and fail this
check. That is an abort, not a prompt to load anything.

DPMI presence is INT 2Fh `AX=1687h`. `AX=0` means a host is already
there. `ES:DI` is the real-to-protected entry, `SI` is the private-data
paragraph count, and `BX` bit 0 means 32-bit clients are allowed. INT 2Fh
`AX=1686h` is the other half: `AX=0` means the caller is already a
protected-mode client. A resident INT 10h hook on Win95 is still entered
in V86, so 1686h will say it is not in protected mode at the start of
the hook.

There is no switch for this today. `/N` only forces the resident image
to stay in conventional memory. Do not add `/V`, and do not add a DPMI
switch. Neither server is an install option.

### Path A, the default

PE is clear. The private GDT, the short CR0 session, and the `SMSW`
abort stay as they are. On that machine the protected-mode entry for a
full hanzi frame is 9 ms out of 249 ms. VCPI or DPMI would replace those
9 ms with a host call. That is slower, not faster. The 166 ms bit walk
does not care which host entered PM.

### VCPI, rejected for the resident console

VCPI is one protected-mode client at a time. EMM386 and JEMM give that
client `DE01h`'s protected-mode entry, and the client is expected to
build page tables on top of the server's and to switch back to V86
before another program does the same. DOS games and extenders (DOS/4GW
and the same family) are that client. They call VCPI when they start,
and they keep protected mode until they exit.

VESA.COM is a TSR. Its job is to stay loaded across that program. If the
console itself remains the VCPI client, the game's `DE01h` / mode switch
fails or the two sessions share one GDT and one page directory and both
crash. Allocating VCPI pages for an LFB map and never freeing them
shrinks the pool the game expected to own. There is no reliable
"someone else is in protected mode" query. From V86, `SMSW` already
shows PE whether the foreground program is in V86 or has switched. The
dangerous moment is a reflected interrupt: the game is the VCPI client,
the server drops into V86 to run INT 10h or the timer, and the hook
calls VCPI again.

A brief switch that always returns to V86 before the hook returns is the
only pattern that does not hold the server across the application's
life. It is still a poor paint client. The hook runs because an
application is drawing, which is exactly when that application may
already be the VCPI client. Nesting a second switch inside the game's
session is the conflict, not a fallback. Detecting a refused switch and
skipping the frame (fail soft) is safer than crashing, and it means the
linear console goes blank for the whole game. Falling back to path A is
impossible while PE is set: raw CR0 is still illegal. The planar console
is the soft landing, and it does not need VCPI.

Entering VCPI only at install, then leaving it before the prompt
returns, does not unlock later paints. The next INT 10h is in V86 again
and would have to re-enter. The feature people want from path B, a
linear console that stays up under EMM while other programs run, is the
long-lived client. That is the shape to reject.

This path also does not speed the hot path on a machine where path A
already works. The switch saves the server's state and is heavier than
`LGDT` plus CR0. The 166 ms bit walk does not move. Mapping the
framebuffer means page-table entries for the physical LFB. The EMS page
frame cannot cover `0xE0000000`.

VCPI is out of scope for this console. Do not plan a shipping dual path,
do not call it at install, and do not call it from the paint or timer
hook. Do not add `/V`. A non-default experiment belongs in a throwaway
harness, not in VESA.COM. Under EMM386 the linear console still aborts,
and the planar driver can still sit in the UMB.

### DPMI, not a product path

A DOS user does not load a DPMI host at boot. Shipping a dual path that
needs one would mean requiring CWSDPMI or another server, or bundling
one. This program does neither. If `1687h` fails, which is the normal
DOS box, there is no DPMI client to become.

Win95 does answer `1687h` inside a DOS box. That is a niche host that
happens to be present, not a second console we plan to ship. The notes
below are why even that opportunistic case stays off the product.

What DPMI buys is a supported way into the host's protected mode, plus,
on hosts that implement it, INT 31h `AX=0800h` to map a physical range
to a linear address. Windows 95 is a DPMI 0.9 host with that call.
Windows 3.1's DPMI 0.9 generally does not have it. The linear address is
not `PhysBasePtr`, and it is not valid in V86. The flat selector based
at physical 0, which the painter uses today, does not see the LFB
through the Windows page tables. The glyph code would have to write
through a descriptor whose base is the address `0800h` returned.

A 16-bit DPMI client is the natural shape of this COM. `BX` bit 0 at
`1687h` says whether a 32-bit client is even offered. The painter's code
is 32-bit. A 16-bit client can create a 32-bit code selector only when
that host allows it. Some do. It is a probe, not a promise.

The resident INT 10h hook is the part that does not fit DPMI 0.9.

- The hook is entered in V86. Painting means a real-to-protected switch
  on that call, then a switch back before the hook returns. DPMI 0.9 has
  no supported way for a client to terminate-and-stay-resident in
  protected mode. The usual pattern (switch back to real mode, then
  INT 21h `AH=31h`) drops the protected-mode client. Every later paint
  has to enter again through `1687h` or through the raw switch from
  INT 31h `AX=0306h`, and `0306h` is only valid for a client the host
  still remembers.
- The host may call DOS on the way in. The hook often runs while DOS is
  already busy, because applications write the screen with DOS. A
  reentrant mode switch there deadlocks.
- `CLI` is not available to a ring-3 client. The current painter loads
  the flat selector into SS and does not use a stack, which is safe only
  because interrupts are off. Under DPMI the host can interrupt, and it
  will push on SS. That is a fault or a write into the framebuffer. The
  32-bit blob would need a real protected-mode stack and a normal SS for
  the whole session. That is a different painter, not a flag on
  `flat_run`.
- DPMI 1.0 resident services (`0C00h` / `0C01h`) are not what Win95
  provides. A selector borrowed from whatever DOS program happens to be
  in the foreground dies when that program exits. The TSR has to be its
  own client for the life of the box, which is the lifetime problem
  above.

DPMI does not make the 249 ms frame shorter. On plain DOS it does not
exist unless we ship a server, which we will not. On a Win95 box the
sketch is a different painter, about as slow as today's, plus a host
switch, and only on a machine that already loaded DPMI. That is a niche
note, not a dual path. Do not implement it.

### Recommendation

When PE is clear, use the self-contained short CR0 session for a full
text line or more, and the real-mode window for sparser dirt when that
window exists. When PE is set, do not enter protected mode. If the mode
has a 64 KiB window, paint through it. Otherwise fail the linear
console and keep the planar driver. That covers Win95, EMM386, and
JEMM. Do not paper over a missing window with VCPI or DPMI.

VCPI is rejected. One client at a time is too poor a fit for a resident
painter: the TSR would block the game or extender that also needs VCPI,
and an install-time switch does not keep later paints working.

DPMI is rejected as a product path and deferred with no schedule. Do
not depend on a DPMI host, do not bundle CWSDPMI or any other server,
and do not add a Win95 dual path. A DOS box that already has DPMI is a
niche note, not a console we ship.

Latency work that is still in scope is the 249 ms frame itself: a
runtime 4–8 KiB conventional glyph cache (8 KiB can hold this bench;
4 KiB does not), a slimmer resident image if EXE or OVL packaging can
shrink what UMB install actually keeps, and algorithmic cuts to the bit
walk. Not a mode-switch host.

### Banked window in the resident console

`qa/lfb-bench.md` records both the paint-only harness and the resident
hybrid. The harness never enters protected mode. `WinFuncPtr` (or
`INT 10h` `AX=4F05h` through the saved vector, never a nested
`INT 10h`) moves a 64 KiB window at A000. That painter now lives in
`VESA.COM`, ahead of `resident_end`. The link is `0xFEF1`.

`bank_cell_limit` is 80 dirty text cells, one full line. Counted on
the active B800 page against the shadow, with `CS` overrides while
`DS` is the text page:

- Fewer than 80 dirty cells, and the mode has a usable 64 KiB window:
  paint through the window. Stay in real mode. Do not set PE.
- 80 or more dirty cells, `PhysBasePtr` was recorded, and `SMSW` still
  shows PE clear: the existing short-PE linear painter.
- Scroll (`INT 10h` `AH=06h`) is not a dirty-cell refresh. It clears
  the bank choice and uses the linear copy while PE is clear. Under
  V86 the same copy uses the window.
- A refresh with no dirty text cells (status or caret only) uses the
  window when one exists. Zero is below the limit.
- Window but no `PhysBasePtr`: bank for every refresh.
- `PhysBasePtr` but no usable window: the linear path only. PE set
  still refuses it.
- PE set at install: `have_lfb` is cleared, so the short-PE path is
  not armed. If a window exists, install binds sticky B800 and does
  not call `lfb_load`. Rows above 25 still need the linear alias read,
  so 43 and 50 fail that install. If no window exists, install fails
  the direct-color console as before.

The limit is the harness wash, not a new sweep. Four cells were about
2 ms and 2 switches on the paint-only harness; a scroll was 76 ms
versus 26 ms linear; full hanzi was 417 ms versus 249 ms. A full line
was 36 ms banked versus 33 ms linear, so 80 stays on the linear side.

Console samples are the whole `AX=1500h` refresh at `cycles=30000`,
`core=normal`, `HH20.FNT`, not the paint-only harness. A negative PIT
latch has one 65536-count period added. Idle `AX=1418h` is 0.

| Sample | 114h | 117h | Path |
| --- | ---: | ---: | --- |
| Four cells | 24 ms, 38640 bytes | 25 ms, 41840 bytes | bank |
| One ASCII line | 33 ms, 73600 bytes | 33 ms, 76800 bytes | linear |
| Scroll one row | 28 ms, 920000 bytes | 28 ms, 920000 bytes | linear |
| Full hanzi | 252 and 251 ms, 956800 bytes | 252 and 251 ms, 960000 bytes | linear |

114h line and 117h four-cell were one period low in the raw latch
(39646 and 30118 counts after the add). 117h hanzi's first pass was
one period low and agrees with the second pass after the add. Blank
is still the old one-period pair (about 60 ms and about 5 ms) and is
not a painter result. Line, scroll, and hanzi sit on the published
linear numbers (33 ms, 26 ms, 249 ms). The extra few milliseconds are
the dirty-cell scan. The four-cell console time includes that scan
and the status band; the 2 ms figure remains the paint-only harness.

`WinFuncPtr` and `INT 10h` `AX=4F05h` differ by 0.4 ms on a 2171-switch
hanzi frame in the harness. The far pointer is the one the resident
uses when mode info has it. 117h on this DOSBox-X profile has both the
window and `PhysBasePtr`. 245h was not in that mode list. These V86
rules were not booted under JEMM or EMM386; they are what `SMSW` and
`linear_bind_v86` do.

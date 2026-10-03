# Direct-color console

`VESA.COM` is a 16-bit real-mode TSR. Direct-color dispatch is
[Direct-color dispatch](VBE-RULES.md#direct-color-dispatch). The linear
entry, when that rule selects it, is `qa/lfb-fastpath.md`.

Samples are DOSBox-X at `cycles=30000`, `core=normal`, `HH20.FNT`. The
harness is `qa/harness/lfbbench.c`. PIT counts and the byte contract are
in `qa/lfb-bench.md`. Idle `AX=1418h` is 0. A full hanzi frame at 114h
and 117h is 249 ms and 248 ms (956800 and 960000 bytes). At 245h it is
403 ms and 402 ms (3334400 bytes). Of the 114h/117h frame, about 30 ms
is real mode, 9 ms is protected-mode entry, 166 ms is the bit scan, and
44 ms is `REP STOS`. About 2000 entries run, one per half-cell. Interrupts
stay off for that chunk, at most 4096 bytes. There is no `STI` while PE
is set. Linear consoles take the packed painter at every scale. Planar
scaling still unpacks.

The driver does not add an expanded-glyph cache, hold PE for a frame, or
use unreal mode. Those would add conventional RAM or hold CLI across the
repaint. The link is `0xFEF7`, 9 bytes under the COM limit.

## COM, EXE, and overlays

The file is a COM because the hot path is a near tiny model: `DS=SS=CS`,
near C pointers, and a raw copy onto a UMB. `S_UMB` allocates
`resident_paragraphs` with strategy `41h` and `rep movsb`s that many
bytes. It does not allocate the whole file.

| Image | Offset | Bytes | Kept after install |
| --- | ---: | ---: | --- |
| Load image (`Memory size`) | `0xFEF7` | 65271 | Only long enough to install. `LOADHIGH` of the file needs a hole this big |
| LFB resident (`banked_text=0`, `resident_end`) | `0xCD07` | 52487 | Yes. DOS is asked for the paragraph round-up, `0xCD10` |
| Banked resident (`image_end`, includes `text_transfer`) | `0xED10` | 60688 | Yes, when the 64 KiB text window is kept |
| `INIT_TEXT` | `0x11E7` | 4583 | No. Option parse, VBE probe, font file decode, EMS check |
| `text_transfer` | `0x2000` | 8192 | No on the LFB path. Yes if `banked_text` is set |

The file on disk is 65015 bytes (`Memory size` minus the `ORG 100h` prefix),
9 bytes under `0xFF00`. The packed-glyph arena is 2096 bytes, with 28
live slots. `large_glyph` and `doubled_glyph` are one 624-byte object
(two 312-byte halves). A 24×64 record is 384 bytes and is staged at the
start of that object.

What has to stay for a Chinese LFB console: the INT 10h, INT 08h, INT 33h,
and INT 2Fh hooks; the 8000-byte shadow; the 1040-byte stack; the glyph
cache; the private GDT and the 32-bit painter; the real-mode bank painter;
the classifier and `font_draw`. Init code and, on the LFB path, the
8192-byte transfer buffer are already outside the resident image. Little
else is cold. An EXE does not discover a hidden 20 KiB.

Stay a COM. The UMB copy is a raw prefix with no fixups, and the hot
path is one near segment. An EXE or an overlay does not shrink that
prefix: install-only code is already `INIT_TEXT`, and paint cannot call
DOS to page an overlay. There is no expanded-glyph cache.

## What the UMB keeps

`0xFEF7` is the COM load image. The UMB block is a prefix of that image,
copied with `rep movsb` and no fixups. Direct color stops at
`resident_end` (`0xCD07`, 52487). Planar 43/50 rows stop at `image_end`
(`0xED10`, 60688) so the copy includes `text_transfer`. `INIT_TEXT` is
already past both stops. A byte that the short-PE glyph body does not
touch is still in the UMB when the real-mode hooks, the bank painter, or
the classifier do touch it.

| Region | Bytes | Direct-color UMB | Planar UMB | Who addresses it |
| --- | ---: | --- | --- | --- |
| `_TEXT` | 45336 | yes | yes | INT 10h, INT 08h, INT 33h, INT 2Fh |
| shadow inside `_TEXT` | 8000 | yes | yes | real-mode compare, every refresh, including V86 |
| stack inside `_TEXT` | 1042 | yes | yes | those hooks and `RestoreSurface` |
| 32-bit glyph body (`pm32.bin` plus the far return) | 309 | yes | yes | selector 18h, only while PE is clear |
| DATA | 132 | yes | yes | near `DS` |
| BSS | 6931 | yes | yes | near `DS` |
| glyph arena inside BSS | 2096 | yes | yes | `font_draw`, then the bank walker or the 32-bit walker |
| slot tables inside BSS | 260 | yes | yes | the same real-mode lookup |
| glyph scratch inside BSS | 624 | yes | yes | real-mode staging before either painter |
| planar scratch inside BSS | 1296 | yes | yes | planar draw and scroll, real mode |
| status line inside BSS | 1680 | yes | yes | real-mode prompt and status cells |
| `font_custom` inside BSS | 256 | yes | yes | real-mode font check |
| mouse glyph temps inside BSS | 404 | yes | yes | real-mode cursor |
| `text_transfer` | 8192 | no | yes | real-mode text snapshot and font bounce |
| `INIT_TEXT` | 4583 | no | no | install only |

BSS rows above share the 6931. The rest of that 6931 is scalars and the
four-font catalog. `_TEXT` minus the shadow and the stack is instructions
and small tables. The bank dispatcher and window painter, from
`choose_bank_paint` through `bank_span`, are 1096 bytes of that code.
They run with PE clear or with PE already set. The 309-byte 32-bit body
is the only paint code that runs exclusively inside the short CR0 session.

`S_UMB` copies a prefix. Direct color is the shorter prefix, so anything
it needs is also in the planar image. The 32-bit body has to sit in that
prefix, or the far jump lands outside the UMB after DOS frees the load
image. Putting it after `text_transfer` and skipping the hole is not a
prefix. Two resident layouts would be two binaries.

There is no owned extended heap. The font payload is already in XMS or
EMS, whichever answered at install, and neither one is required to be
the other. XMS lock can return a linear address; an EMS-only machine
has no such lock. INT 15h reports extended memory and does not reserve
it. Writing that range collides with HIMEM when HIMEM is loaded. The
framebuffer's `PhysBasePtr` is video memory, and V86 cannot read it
with the flat selector. The bank path would have to switch the window
away from the pixel bank to fetch a blob stored there, then switch
back. That stays on the real-mode path the sparse and V86 cases already
use, and it does not remove the bytes from a hybrid image that still
has to carry them for the linear case.

None of those regions move. The 32-bit body has no host-free owner, and
the hybrid image still needs it when PE is clear. The classifier runs
in real mode before either painter, so folding it into the 32-bit body
would grow the prefix and would not run under V86. The link is
`0xFEF7`. The shadow and `text_transfer` stay where the table puts them.

## VESA.COM requires an EMS manager

VESA is the console for a machine that already has an expanded-memory
manager. The manager is how the TSR gets a UMB. The font file already
lives in XMS or EMS. The glyph arena stays in the prefix, as the next
section describes. The manager is not a paint host. There is still no
VCPI client and no DPMI client.

`emm_ready` runs in the install stub, after the font driver is found
and before `initialize` sets a mode. INT 21h `AX=3567h` must point at a
device whose name at offset 10 is `EMMXXXX0`. INT 67h `AH=40h` must
return status 0. EMM386, JEMM386, and JEMMEX all publish that name.
DOSBox-X `ems=true` does too. A manager that is present but has EMS
turned off (the `EMMQXXX0` name) does not pass.

Without that manager the stub prints two lines and exits 1. It does not
change video mode:

```
No EMM.
需要EMM386。
```

The second line is GB2312. VGA.COM, EGA, CGA, and HGA do not call
`emm_ready`. A planar VBE mode installed by VESA.COM does. The UMB is
for this TSR, planar or direct color. `/N` still forces the conventional
copy after the manager check has passed. `S_UMB` still asks DOS for a
high block (strategy `41h`) and, if that alloc fails, stays in
conventional memory. The footprint is the same bytes either way:
direct color keeps `0xCD07` (52487), and planar 43/50 rows keep
`0xED10` (60688).

Real EMM386 or JEMM runs the guest in V86, so `SMSW` shows PE and
dispatch takes that case of the direct-color rule. DOSBox-X `ems=true`
publishes the same device and does not set PE, so the harness still
takes the linear case. `qa/profiles/vesa-hd.conf` sets `ems=true` for
that reason.

### Glyph arena stays in the prefix

The 2096-byte arena is the hot pin. A hit is a near pointer and issues
no manager call. The link stays `0xFEF7`.

`cache` is 2096 bytes. The first 128 bytes (`FONT_MAP_CACHE` of 64
words) are one page of the record index. The other 1968 bytes hold
packed glyphs: 28 HH20 records are 1960 bytes, with 8 spare. The slot
tables sit beside it and stay too: `keys`, `cache_offsets`, and
`cache_lengths` are 28 words each, `valid` is 28 bytes, and `lookup`
is 64 bytes (260). `glyph_buf` is a separate 624-byte stage. A 24×64
record is 384 bytes and is written at `large_glyph`, continuing into
`doubled_glyph`. Cropped hits expand into `doubled_glyph` and return
that pointer. Every other hit returns `cache + 128 + offset`.

A hit does not call the memory manager. The warmed-alphabet checks
require that: 26 glyphs, then the same 26 again, and the second pass
adds zero XMS/EMS moves. A one-record bounce on every hit would fail
those checks. It would also sit on the real-mode side of the 249 ms
frame. That side is 30 ms today and already includes the hit. A full
hanzi refresh walks on the order of 2000 half-cells. The 166 ms bit
walk is the store, not the lookup. Paying a manager call per cell
does not shrink that walk.

Miss path, both painters. `LoadGlyph` copies one index page into the
128-byte window when the 64-slot page changes, then copies one raw
record into `large_glyph`, then `CacheGlyph` compacts it into the
1968-byte region. `font_draw` calls `LoadGlyph` once per cell. The
packed path then calls `raster_packed_cell` twice with that same
pointer (left half, then right half). The bank path and the linear path share this lookup. They differ only
in the store: `bank_span` versus the short-PE body.

`bank_span` reads the glyph with `DS:[SI]` in the same loop that calls
`bank_fill_px` and `set_win`. `set_win` is `WinFuncPtr` or INT 10h
`AX=4F05h`. `DS` stays the resident segment for the whole span. The
glyph bytes have to be near pointers before the first window switch
and have to stay there until the span returns. The short-PE path does
the same: `paint_span` turns `CS<<4+SI` into the flat source, so the
bytes are still in the resident image.

### XMS, EMS, and the two apertures

The font file, including HZK and `HH20.FNT`, already lives in extended
memory. Install prefers XMS (`AH=09h` allocate). EMS is the fallback
(`AH=43h` allocate pages) after `EMMXXXX0` and a version of at least
`40h`. Reads and writes go through `TransferFontBytes`:

- XMS `AH=0Bh` moves between the handle and a conventional buffer.
- EMS `AH=57h` moves between a handle's logical page and a conventional
  buffer. It does not change the visible page frame.

There is no INT 67h `AH=44h` map in this driver, and no `AH=47h` /
`AH=48h` save of the frame. The 128-byte index window is a copy, not a
mapped page. HZK is not paged through the frame.

XMS lock (`AH=0Ch`) can return a linear address. The short-PE painter
could read that address while PE is clear. A real EMM386 or JEMM
manager leaves the CPU in V86, `route_mem` takes the bank path, and a
locked address above 1 MiB is not a near pointer. DOSBox-X `ems=true`
does not set PE, so the short-PE path still runs there, but the image
is one painter. Forking the glyph source for that lab would keep the
conventional bytes for V86 anyway.

The EMS page frame is the other 64 KiB aperture. The VESA window is
the one `WinFuncPtr` moves, usually at A000, 64 KiB at a time. They
are not the same object, and they are not guaranteed to be different
addresses. `FRAME=A000` puts the page frame on the graphics window.
Mapping a font page there, then letting `set_win` move that window,
drops the glyph and the pixels into the same hole. Other software
also owns the frame between paints. A map that is left up across a
refresh is a loan of that hole, not a private buffer.

`bank_span` already switches one aperture while it reads the glyph.
An EMS map inside that loop is a second switch nested in the first.
Save/restore around the map does not make that safe: the glyph pointer
would have to stay valid across `set_win`, which is the thing that
can move the same addresses.

### Aperture rules

The 2096-byte pin stays. These are the rules for any other buffer.

1. Keep the hot records conventional. The pin has to cover the
   26-glyph alphabet with zero manager calls, which is most of the
   1968 glyph bytes. A one-record bounce thrashes that set.
2. Cold bytes stay in the existing XMS handle, or in EMS logical pages
   reached only with `AH=57h`. Do not park the arena in the page frame
   just because an EMS manager is required.
3. Copy into the conventional stage before `raster_packed_cell` or
   `paint_span`. Do not remap during a glyph, and do not call a map
   from inside `bank_span`.
4. Do not use INT 67h `AH=44h`. The page frame is not a glyph buffer,
   and `set_win` must not run while that frame points at glyph data.
5. Do not take an XMS lock on the banked path. A lock is only a
   short-PE address, and V86 never takes that path.

`text_transfer` (8192) is already outside the direct-color UMB. The
ranking below is why it still cannot leave the planar image. `/AF` is
unchanged: the flag defaults off and no accelerator entry is called.

## What stays conventional

Direct color and planar 43/50 rows are two stops in one prefix, not two
programs. `S_UMB` copies from offset 0 through `resident_end` or through
`image_end`. A hole cannot be skipped. Bytes the direct-color painter
never reads still sit in its UMB when the planar painter needs them in
the same file.

| Stop | Offset | Bytes | What DOS is asked to keep |
| --- | ---: | ---: | --- |
| Direct color, `resident_end` | `0xCD07` | 52487 | Rounded up to `0xCD10` (52496) |
| Planar 43/50 rows, `image_end` | `0xED10` | 60688 | Already a paragraph boundary |
| COM load image | `0xFEF7` | 65271 | File is 65015. Nine bytes under `0xFF00` |

`text_transfer` is the 8192 bytes between `0xCD10` and `0xED10`. It is
in the COM image and in the planar UMB. It is not in the direct-color
UMB. `INIT_TEXT` (4583) is in the COM image only.

| Buffer | Bytes | Direct-color UMB | Planar UMB | COM | Decision |
| --- | ---: | --- | --- | --- | --- |
| Shadow | 8000 | yes | yes | yes | Stays. `text_changed`, `choose_bank_paint`, and the space fill compare it on every refresh, including the timer |
| `text_transfer` | 8192 | no | yes | yes | Stays. The keyboard query and `refresh_dirty` retarget `D_B800` at this snapshot and then use near loads. No XMS call fits there |
| Planar scratch | 1296 | yes | yes | yes | Stays. `raster_large_cell` reads it while `graphics_bank` owns the window. Dead on direct color, but the prefix is shared |
| Status line (`prompt_bits` and the cells around it) | 1680 | yes | yes | yes | Stays. `RefreshConsole` runs from IRQ0. A bounce would call HIMEM from that tick |
| Glyph stage (`glyph_buf`) | 624 | yes | yes | yes | Stays. Misses and 24×64 records are staged here before either painter |
| Glyph arena and slot tables | 2096 + 260 | yes | yes | yes | Stays. Already decided |
| `font_custom` | 256 | yes | yes | yes | Stays. The classifier tests it per cell. Too small to move |
| Mouse glyph temps | 404 | yes | yes | yes | Stays. Cursor draw is real mode, on the same lock as paint |
| Stack | 1042 | yes | yes | yes | Stays |
| 32-bit body | 309 | yes | yes | yes | Stays. V86 never runs it, and the hybrid image still needs it when PE is clear |
| `INIT_TEXT` | 4583 | no | no | yes | Already dropped from both UMBs. An EXE would not shrink the prefix |

HIMEM `AH=0Bh` is not reentrant. IRQ0 calls `tick`, and `tick` calls
`RefreshConsole`, while a foreground program may already be inside
HIMEM. The keyboard service (`AX` query while `busy` is set) is
narrower: it points `D_B800` at `text_transfer` and scans with no C
stack and no manager call. Replacing that snapshot with an XMS move
would run HIMEM from that query. A chunked bounce does not help,
because the scan treats the buffer as a text segment and walks all
`text_cells`.

`font_sync` and `font_text` already use `text_transfer` as the
conventional side of an `AH=0Bh` or `AH=57h` move. Those calls happen
under the renderer lock, not from the keyboard query. Shrinking the
buffer would shrink the bounce those calls need. The planar space fill
also reads it while the VGA window covers B800, so the snapshot cannot
be the same bytes as the planar scratch.

No remaining buffer is cold on both UMB stops. The only large region
absent from the direct-color UMB is `text_transfer`, and the planar
stop plus the keyboard query keep it. The shadow, the planar scratch,
the status line, and the glyph stage are read from IRQ0 or while
`set_win` is in progress. An XMS move there is not reentrant, and an
EMS map there is the hard refusal: glyph bytes, the planar scratch,
and the shadow are read while `WinFuncPtr` owns the window. Fetching
them with `AH=44h` is not a candidate.

## VBE/AF stays off unless `/AF` is set

VBE/AF (Accelerator Functions) is not the INT 10h VBE BIOS. The common
SciTech driver exports 32-bit flat calls for a rectangle copy and a
solid fill. DOSBox-X implements VBE BIOS modes and does not provide
that driver. A few late-1990s S3, Cirrus, and Tseng packs shipped one.
Coverage is the card plus that module, not "VESA is present."

Chinese glyphs are a 1bpp packed row expanded to 16bpp. An AF copy
does not replace that walk. Calling a 32-bit AF table would need VCPI
or DPMI, which this TSR does not use. Under EMM the CPU is already in
V86, so that entry is the same illegal CR0 switch as the short-PE
painter.

The install switch is `/AF` to enable and `/AF-` to disable. Default
off: omitting the switch leaves the resident byte `af_on` clear, the
same as `/AF-`. No AF device is a no-op. This image parses the switch
and stores it. It does not call an AF entry, so `/AF` does not change
pixels on DOSBox-X or on a card with no real-mode accelerator entry.
An unknown switch, including `/A` without `F`, is rejected with the
usage line. Do not call a 32-bit AF entry from this TSR.

## Protected mode is private

The painter does not call VCPI or DPMI, and it does not load a server,
CWSDPMI, or any other host. There is no VCPI probe, no DPMI probe, and
no switch that selects either one. What runs when PE is set is
[Direct-color dispatch](VBE-RULES.md#direct-color-dispatch).

## Console samples

Dispatch is [Direct-color dispatch](VBE-RULES.md#direct-color-dispatch).
`qa/lfb-bench.md` records the paint-only harness. The table below is the
resident `AX=1500h` refresh. The limit in that rule is the harness wash.
Four cells were about
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
is a one-period PIT pair (about 60 ms and about 5 ms) and is
not a painter result. Line, scroll, and hanzi are 33 ms, 26 ms, and
249 ms on the paint-only linear samples. The extra few milliseconds are
the dirty-cell scan. The four-cell console time includes that scan
and the status band; the 2 ms figure remains the paint-only harness.

`WinFuncPtr` and `INT 10h` `AX=4F05h` differ by 0.4 ms on a 2171-switch
hanzi frame in the harness. The far pointer is the one the resident
uses when mode info has it. 117h on this DOSBox-X profile has both the
window and `PhysBasePtr`. 245h was not in that mode list. These V86
rules were not booted under JEMM or EMM386; they are what `SMSW` and
`linear_bind_v86` do.

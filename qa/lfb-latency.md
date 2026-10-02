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
at 245h moved from 67 ms to 57 ms. The image link stayed `0xFEE9`.

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
| EMM386 / optional VCPI | No paint change, and the switch gets heavier. See below | — | — | No |

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
`0xFEE9`, 23 bytes under the COM limit, and the tail segment moves after
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
| Load image (`Memory size`) | `0xFEE9` | 65257 | Only long enough to install. `LOADHIGH` of the file needs a hole this big |
| LFB resident (`banked_text=0`, `resident_end`) | `0xCD9B` | 52635 | Yes. This is the UMB request for a direct-color console |
| Banked resident (`image_end`, includes `text_transfer`) | `0xEDA0` | 60832 | Yes, when the 64 KiB text window is kept |
| `INIT_TEXT` | `0x1149` | 4425 | No. Option parse, VBE probe, font file decode |
| `text_transfer` | `0x2000` | 8192 | No on the LFB path. Yes if `banked_text` is set |

What has to stay for a Chinese LFB console: the INT 10h, INT 08h, INT 33h,
and INT 2Fh hooks; the 8000-byte shadow; the 1104-byte stack; the glyph
cache (2176 bytes plus its tables); the private GDT and the 32-bit painter;
the classifier and `font_draw`. `large_glyph` and `doubled_glyph` are 512
bytes each and still serve planar and custom cells. Init code and, on the
LFB path, the 8192-byte transfer buffer are already outside the resident
image. Little else is cold. An EXE does not discover a hidden 20 KiB.

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

Recommendation: stay a COM. If a glyph cache is built later, allocate 8 KiB
of conventional memory at runtime. Do not convert to EXE or OVL for UMB
fit or for paint speed. Do not bake the scratch into the image.

## EMM386

EMM386 (and the Windows DOS box) runs the CPU in V86: CR0.PE is set, the
guest is virtual-8086, and a pager owns CR3. The same program usually
publishes UMBs and, unless started with `NOVCPI`, a VCPI server. The EMS
page frame is a 64 KiB window in the upper memory area. It is a banked
view of expanded memory, not a map of `PhysBasePtr`.

The linear path reads `SMSW` and aborts when PE is already set. From V86,
`LGDT` and a write to CR0 are privileged. EMM386 would fault them and
would not leave our GDT, our CLI window, or our identity map in place.
The console does not stay installed. That abort is the honest outcome
when no VCPI client is implemented.

VCPI, where an EMM386 actually exports it, is how a DOS program is
supposed to enter protected mode under that host. The client calls
INT 67h `AX=DE00h` / `DE01h`, receives a server entry, and switches with
the server's page tables. It is optional in the market and absent in a
lot of real machines: `NOVCPI`, `NOEMS` builds that still set PE, and a
Win95 DOS box. Windows is the V86 host there. It does not hand a DOS
program ring 0, and a VCPI client that worked under EMM386 before Windows
started is the conflict called out earlier. A path that required VCPI
would refuse the same machines the current abort refuses, plus any
EMM386 with VCPI turned off.

It would also not be a faster switch. One entry today is a private `LGDT`
and a CR0 write, 9 ms across the whole frame. A VCPI call saves the
server's CR3, IDT, and registers and returns through the server. That is
more work per glyph, not less. The ceiling, if every entry were free and
the 30 ms real-mode side were somehow inside the same session, is under
40 ms of a 249 ms frame. The 166 ms bit walk does not move. Mapping the
framebuffer still needs page-table entries for `PhysBasePtr` (here
`0xE0000000`). The EMS page frame cannot cover that address. EMS remains
what it already is: an optional font-cache backend, unrelated to pixels.

EMM386's real benefit to this program is UMBs, and only for a resident
image that can install. The planar driver can live in an EMM386 UMB. The
linear console cannot start while that EMM386 has PE set. HIMEM alone
does not set PE; it is not the obstacle.

Recommendation: ignore EMM386 when tuning paint speed. Do not add an
optional VCPI painter. Keep the `SMSW` abort when PE is already set.

# Direct text-memory writes

The resident 80x25 console observes foreground stores to color text memory at
`B800:0000`. An application does not need to call BIOS text-output functions or
an HHBIOS repaint function after changing the text cells. Timer refresh compares
the active page with the saved screen and draws the changed cells.

For banked VESA, B800 maps the text bank whenever the foreground application is
running. A refresh interrupt suspends that application, snapshots the text,
switches to the graphics bank, renders, and restores the text bank before
returning. Thus foreground stores can leave interrupts enabled. This does not
extend to an unrelated TSR that writes B800 from a nested interrupt while the
graphics bank is mapped; see [the interrupt contract](VBE-RULES.md#memory-and-interrupt-boundary).

The same B800 layout is retained with `/M:104` (1024x768), `/M:106`
(1280x1024), or a compatible larger BIOS mode. Physical viewport placement,
integer bitmap enlargement and 32-bit offsets across graphics banks do not
change an application's page, row or column arithmetic. The text-bank probe
covers the entire physical framebuffer, rather than just its first 64 KiB.

## Runtime checks

```sh
python qa/run.py dos qa/spec/test_direct_video.py --dosbox dosbox --screenshots
python qa/run.py dos qa/spec/test_direct_video.py --dosbox dosbox-x --screenshots
# Optional BIOS profile advertising widescreen modes; vendor numbers are queried.
python qa/run.py dos qa/spec/test_direct_video.py -k 1920 --dosbox dosbox-x \
    --screenshots --vesa-research-config qa/profiles/vesa-hd.conf
```

`SNAPSHOT direct <page>` selects the page and display policy once before the
tested writes. It leaves interrupts enabled and performs these operations:

- Ordinary word stores across the complete page.
- Separate character-byte stores that first leave an orphan GB2312 lead byte,
  then complete the Chinese pair in a later frame.
- Attribute-byte stores with different colors on the two halves of a character.
- `REP MOVSW` from an application buffer to B800.
- Overlapping forward `REP MOVSW` to scroll upward, followed by a new bottom row.
- `REP STOSW` to clear the visible page.

The scene also contains a Chinese character at the last two columns, isolated
high bytes on opposite sides of a row boundary, and all 16 background colors.
Each operation is followed by 24 BIOS ticks, without a policy change, BIOS text
output or explicit invalidation. Read-only observation calls do not repaint.

Host assertions independently place known fixture glyphs and check every byte
of all four graphics planes. They also check exact B800 contents, inactive text
pages and page padding. With `--screenshots`, every pixel of the actual emulator
window must match the already-checked planes. Raw `SNAPnn.BIN`, `PAGEnn.BIN`, the
framebuffer segment in `DIRECT.BIN`, and window screenshots remain in the run
directory. This tests eventual refresh, not a maximum redraw-latency bound.

## Supported boundaries and known failure

| Backend | Direct-write coverage | Boundary |
| --- | --- | --- |
| Banked VESA, 800x600 / 80x25 | Active pages 0 and 7; preservation of all eight 4 KiB pages | The bank-isolation probe must succeed. |
| Banked VESA, 1024x768 and 1280x1024 / 80x25 | Active page 7, every operation above, all eight pages and full-window pixels | A BIOS-provided planar mode and isolated text bank are required. |
| Banked VESA, 1920x1080 / 80x25 | The same stores with native glyphs at 2x and centered 20x40 physical cells | The test discovers the vendor mode; unavailable geometry is reported separately. |
| Legacy VGA, 640x480 / 80x25 | Active pages 0 and 5; preservation of pages 0 through 5 on the aliased aperture | The AE020 framebuffer aliases text pages 6/7 on a 64 KiB aperture. |
| One-image VESA fallback | Not exercised by this direct-write matrix | Its existing contract permits page 0 only. |

The legacy VGA page-7 case is a **strict expected failure** only when its
reported framebuffer segment is AE02h. Both DOSBox and DOSBox-X reproduce it:
B800 offsets starting at 6020h alias the beginning of the graphics framebuffer,
so drawing overwrites high-page text. Page selection currently accepts page 7
despite that overlap. The test retains this defect rather than counting it as
supported; an unexpected pass requires updating the test. No legacy driver
rewrite is implied by the VESA direct-write result.

The byte-preservation checks use display policy 1. In mixed-frame policies 2/3,
recognized CP437 frame characters may be converted to the documented legacy
aliases in text memory; applications must not assume those bytes are untouched.
The tests hide the software cursor to isolate glyph and attribute updates.

Direct CRTC/GC reprogramming, monochrome B000 applications, physical mouse
callbacks and protected-mode mapping policies are separate compatibility
questions. These results do not establish them. Widescreen physical surfaces
can host the resident 80x25 console; larger logical grids such as 132x50 remain
foreground rendering experiments and are not yet advertised as resident text
modes. These are distinct features.

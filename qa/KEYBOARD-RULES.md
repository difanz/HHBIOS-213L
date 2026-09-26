# Whole-character editing

`CKBD /E` enables whole-Hanzi Left, Right, Delete and Backspace in byte-oriented
INT 16h applications. `CKBD /B` restores byte editing, which is the default.
Both commands can change an already resident CKBD. Use `/B` for binary or hex
editing, where each byte is intentional.

This requires the matching VGA, EGA or HGA driver, direct-screen Chinese mode,
an 80-column page-zero view and a visible BIOS cursor. Mode 0, disabled Chinese
display, Shift/Ctrl/Alt combinations and other screen contexts pass through.
The pairing policy follows [the display rules](DISPLAY-RULES.md); ambiguous
CP437/GB2312 bytes still depend on the selected display mode.

## Application updates

The filter reads the cursor and text row; it never edits an application's
document or video memory. It offers a companion key only after observing the
application's response to the first key:

| State | Observation | Result |
| --- | --- | --- |
| Idle | Relevant key at a displayed pair | Save cursor, row and expected one-byte update |
| Waiting | Status poll before any update | Keep waiting |
| Waiting | One-column move, unchanged row | Offer the same movement key |
| Waiting | Exactly one-byte deletion, remaining text shifted left | Offer the companion deletion |
| Waiting | Two-byte update, selection deletion, context change or read-ahead | Cancel the companion |
| Ready | Status poll | Return the same key without consuming it |
| Ready | Key read | Consume the companion before queued physical input |

Both legacy (`AH=00h/01h`) and enhanced (`AH=10h/11h`) BIOS interfaces are
supported. Status and read return the same key, including when an editor uses
the status value and discards the value from its subsequent read.

A cursor placed between bytes by vertical movement or a mouse needs a different
sequence: Backspace removes the lead and Delete removes the trail. Delete at
that position is reported as Backspace on both status and read, then followed
by Delete after the observed one-byte update. ASCII characters on either side
must remain intact.

The filter does not infer application data from a screen that has scrolled or
changed in another way. Horizontally clipped characters, selection semantics,
replacement/overwrite operations, undo grouping and programs that bypass
INT 16h need application-specific support. A pair uses two application editing
operations, so an application's undo can expose the intermediate byte state.

## Driver interfaces

- `INT 16h AH=2Ch`: AL=0 disables, AL=1 enables, other values query. Returns
  AX=4B48h and BX=0 or 1. Setting the mode clears pending companion input.
- `INT 10h AX=1410h`: DX contains row/column. Returns AX=0 (single), 1 (lead)
  or 2 (trail), BX=4B48h, and CX=the direct-screen segment. CX=0 means the
  display policy is inactive or the coordinate is outside the supported view.

## Evidence

The CPU tests execute the production routines, including polling order, native
two-byte application updates, modifiers, boundaries, screen-segment changes
and frame/Chinese boundaries. Deliberate mutants check that premature
companions, inconsistent status keys and discarded pre-update polls fail.

Application cases assert per-action cursor/row data and exact saved file bytes.
Each scenario runs with `/E` and `/B`; the latter positively demonstrates the
original byte-oriented behavior. Scenarios cover Left/Right followed by Delete
and Backspace, and vertical placement between bytes followed by either delete
key. The MS-DOS editor uses actual emulated keyboard interrupts, including its
menu-driven Save operation.

The fixture set includes Turbo Vision tvedit r415, Turbo C 2.01, Turbo C++ 3.0,
Borland C++ 3.1, QBASIC 1.1 `/EDITOR` (classic MS-DOS EDIT), standalone
MS-DOS Editor 2.0.026, and the PC Tools 9 text editor. These are concrete
regression cases, not a claim that every version or workflow is verified.
See [test setup](README.md) for optional application fixtures and evidence files.

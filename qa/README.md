# HHBIOS tests

The pytest suite checks display and editing behavior at three levels: production
linked C/assembly instructions, DOS framebuffer and BIOS state, and real editors. Host
assertions compare observed state with expected character roles, font pixels,
API results, cursor movement and saved document bytes.

Read [DISPLAY-RULES.md](DISPLAY-RULES.md) for the mixed-text contract and the
two-state Chinese-pairing FSM. Ambiguous GB2312/CP437 bytes require explicit
policy to determine how they display.
The [VBE contract](VBE-RULES.md) covers mode ownership, banked framebuffer tests,
the independent VESA renderer, its high-resolution surfaces, interfaces and extension boundaries.
The [text-mode study](TEXT-MODES.md) records native BIOS and application behavior
for 80x43/50/60 and 132x25/43/50/60, and the design for rendering existing text
modes on larger graphics surfaces. Resident 80x43/50 rendering and mouse tests
are in `test_resident_text.py`; wider native observations do not imply resident
support for those grids.
The [wide rendering study](WIDE-RENDERING.md) adds standalone DOS framebuffer
experiments for larger and widescreen surfaces, with exact memory and scanout
checks. Optional emulator profiles are confined to QA; they also allow resident
1080p tests when the emulator would otherwise hide those BIOS modes.
`test_setup_display.py` covers EDID and mode selection; `test_setup_widescreen.py`
checks generated wide-mode startup, live text-row changes, window pixels and
MS-DOS mouse input. Its DDC fixture supplies only EDID replies, leaving the
BIOS mode list and framebuffer operations intact. See [SETUP](../src/setup/README.md)
for probe limits and test options.
The [direct-video checks](DIRECT-VIDEO.md) verify foreground B800 writes with
interrupts enabled and timer-only refresh, including the legacy VGA high-page
overlap that remains an explicit expected failure.

## Setup

Use Python 3.10 or newer and the patched JWasm described in the root
README. Install the dependencies for the selected layer before running it.
The shared text and VESA unit cases build production code with Open Watcom
`wcc` and `wlink`; descriptor checks also use the host C compiler `cc`.
Missing tools or required fixtures cause a test failure; tests do not download
them. Optional proprietary application cases skip unless configured. A supplied
but missing or unusable fixture fails.

```sh
python3 -m venv qa/.venv
. qa/.venv/bin/activate
python -m pip install -r qa/requirements.txt
```

The virtual environment can live anywhere. `make` uses `python3` from `PATH`;
override it with `QA_PYTHON=/path/to/python` if needed. The host runner uses
POSIX process groups and the guest build uses Bash (on Windows, use WSL).
These are host test requirements, not requirements for running the DOS COMs.

Put the patched `jwasm`, Open Watcom tools, and a DOSBox executable on `PATH`,
or configure their locations with `JWASM`, `WATCOM`, and `DOSBOX`. For example,
`DOSBOX=dosbox-x make qa-dos` selects another implementation without editing
the repository. `--dosbox /path/to/executable` also works; `DOSBOX_X` is
a fallback when `DOSBOX` is unset. Open Watcom's own environment setup is also
supported. No tool needs to be installed into a particular directory.

JWasm may also be built at `qa/.cache/JWasm/build/GccUnixR/jwasm`. `JWASM` is
removed from the assembler subprocess environment because that assembler
interprets the same environment variable as extra command-line arguments.

The guest layer targets DOSBox's VGA emulation, with no DOSBox-X version
requirement. Each case uses the common `-conf` / `[autoexec]` interface and a
private config, so personal DOSBox settings do not affect the test. Executable
paths/hashes are recorded in ignored output directories for reproduction.

The GB2312 filename case first checks DOS file creation without HHBIOS. If the
emulator rejects these filename bytes, the case reports a skip with its DOS
error code. Supported environments must create, enumerate, reopen and read the
same filename and contents with HHBIOS loaded.

## Interactive MS-DOS environment

`qa/prepare.sh` builds an actual bootable MS-DOS disk for interactive QA with
DOSBox-X. It uses local installation media: supply the files from all three
MS-DOS 6.22 disks in one directory, a bootable floppy image of that version,
and a DOS mouse driver. Host dependencies are Bash, GNU coreutils, mtools, psmisc (`fuser`), 7z,
unzip and iconv, plus the normal COM build tools. No DOS or compiler download
is implicit.

```sh
export DOSBOX=/path/to/dosbox-x
bash qa/prepare.sh --msdos-dir /path/to/msdos622/files \
  --msdos-boot /path/to/msdos622-boot.img --mouse /path/to/CTMOUSE.EXE \
  --borland /path/to/borland-cpp-3.1
"$DOSBOX" -conf build/run/dosbox.conf
```

The equivalent environment variables are `MSDOS_DIR`, `MSDOS_BOOT`,
`CTMOUSE_EXE` and `BORLAND_DIR`. Application fixture variables documented below
also apply. Available fixtures are copied; unavailable optional applications
are reported. Preparation builds the modules, probes and
[SETUP.EXE](../src/setup/README.md); `--no-build` requires these existing outputs.
SETUP needs a local Open Watcom UI source tree. Supply `WATCOM_SOURCE`, or run
`bash tools/build-setup.sh --fetch` once to obtain it. Preparation does not fetch
compiler or UI dependencies.

The default `--mouse-driver cutemouse` loads CuteMouse and enables click-to-capture
for its relative PS/2 input. Ctrl+Alt+F10 releases the pointer. Remote desktops such
as Chrome Remote Desktop may send absolute positions that conflict with captured
relative input: reversing the host pointer can continue moving the DOS pointer
in the same direction. For that environment, use
[VBMouse](https://git.javispedro.com/cgit/vbados.git/about/) with VMware absolute
mouse integration and leave the pointer uncaptured:

```sh
bash qa/prepare.sh --mouse-driver vbmouse --mouse /path/to/VBMOUSE.EXE
```

`QA_MOUSE_DRIVER=vbmouse` and `VBMOUSE_EXE=/path/to/VBMOUSE.EXE` are equivalent.
Supply the driver locally; preparation never downloads it. This profile sets
`autolock=false` and `vmware=true` and loads only VBMouse. It is a QA guest
choice, not a dependency of HHBIOS. VBMouse is loaded in conventional memory
to leave large UMB blocks for CKBD/VESA; otherwise its small UMB allocation can
force the much larger VESA resident into conventional memory. VBMouse requires
a 386; CuteMouse remains available for older machines and relative-input tests.
The observed VBADOS 0.67
archive has SHA-256 `824d74731d719ff4c8ca7914f6f93e554812fca3a9ef8c44317c1da728184d27`.

The image boots Microsoft's kernel and COMMAND.COM with HIMEM, EMM386 and
the selected mouse driver. `C:\HHBIOS` contains the original binary distribution from the
repository's `original-import` tag, the files inside its three self-extracting
archives, and current compiled modules. Both HZK16 fonts, input tables and
optional utilities are included; `SETUP.EXE` is the configuration editor.
`Q:` is an MS-DOS `SUBST` for `C:\QA`; `TOOLS`
lists the editors, IDEs, DOSSHELL and PC Tools available there. Guest probes
are on the PATH through `Q:\PROBES`.

The generated configuration uses `qa/dosbox-x.map`, with mappings for both SDL
backends. Function keys go to DOS, including Ctrl+F5 (HHBIOS control menu),
Ctrl+F9, Ctrl+F10 and F11/F12. Emulator shortcuts are unbound except
Ctrl+Alt+F10 for mouse capture; use DOSBox-X's menus for other emulator commands.
This does not change the desktop or remote client's own shortcuts.

The supplied `213L.INI` selects the Great Wall keyboard layout: Insert, Home,
PageUp, Delete, End and PageDown select input modes. Ctrl+F5, then 6 (仿长城键),
switches to the standard Alt+function-key layout for the current session.
The DOS `README` command opens the installed GB2312 help file beside
`README.COM`, even when invoked from another directory through PATH.

Preparation refuses to update a disk held open by DOSBox. Close DOSBox first,
or select a separate disk with `--image /path/to/QA.IMG`. The generated
`build/run/dosbox.conf` points to that disk on the next launch.
Existing application settings and
HHBIOS configuration inside the disk are preserved; compiled modules, probes,
launch wrappers and the generated DOS startup files are updated. Source
fixtures remain untouched. The disk and staging directories live under ignored
`build/`; nothing there is part of an open-source commit.

The optional real-kernel regression boots a disposable copy of this disk and
checks DOS identity, HHBIOS residency, console timing, streamed Chinese pixels,
CLS palette/status-row preservation and repeated help invocations. It compares
interrupt vectors and DOS arenas before and after the loop, and checks the
resident stack guard on each iteration. Both UMB and conventional residency run
with automatic and normal CPU cores. Tests use fresh builds of the modules and
never write to the interactive disk itself. With `--screenshots` and `--vbmouse`,
MSBACKUP's downloaded border and mouse glyphs are compared against native VGA
text on both 800×600 and 1024×768 VESA surfaces. Its callback consumes relative
mickeys, so the test verifies reversals on both axes and vacated text cells,
then compares the complete arrow bitmap independent of its sub-cell offset:

```sh
python -m pytest qa/spec/test_msdos.py --msdos-image build/run/MSDOS.IMG \
  --dosbox "$DOSBOX" --screenshots --vbmouse /path/to/VBMOUSE.EXE
```

`test_msdos_mouse_directions` exercises real host movement in both directions
on each axis, checking signed mickeys and INT 33h positions in native VGA and
VESA 25/50-row modes. It uses captured relative input with CuteMouse and
uncaptured absolute input with optional `--vbmouse /path/to/VBMOUSE.EXE`
(`VBMOUSE_EXE` also works). If the disk does not contain CuteMouse, supply
`--ctmouse /path/to/CTMOUSE.EXE` or `CTMOUSE_EXE` for the relative cases.
Absolute reversals deliberately remain on one side
of the window center, so capture-induced one-way motion cannot pass.

The DOS layer also uses Open Watcom's `wcl386` and the `dos4g`, `dos32a`,
`causeway`, and `pmodew` linker systems. Include its `binw` directory on `PATH`
so the linker can find the DOS extender stubs and `dos4gw.exe`; setting `WATCOM`
does this for the test fixture. Standalone DPMI hosts are optional:

| Option / environment | Fixture |
| --- | --- |
| `--djgpp-cc` / `DJGPP_CC` | DJGPP cross compiler; defaults to `i586-pc-msdosdjgpp-gcc` on PATH |
| `--cwsdpmi` / `CWSDPMI_EXE` | [CWSDPMI](https://sandmann.dotster.com/cwsdpmi/) executable |
| `--hdpmi32` / `HDPMI32_EXE` | HDPMI32 from [HX releases](https://github.com/Baron-von-Riedesel/HX/releases) |

Use `python qa/run.py dos -k extenders` to select the memory coexistence cases.
They compile a shared real/protected-mode client, retain competing EMS mappings
and a 2 MiB allocation during font calls and timer activity, and check exact
glyph bytes, memory contents and reclamation. External hosts are installed before
HHBIOS and unloaded after it. Unconfigured host fixtures skip; explicit invalid
paths fail. See [MEMORY-COMPAT.md](MEMORY-COMPAT.md) for the compatibility limits
and Windows 95 interface audit.

For the application layer, download the tvision r415 editor fixture:

```sh
mkdir -p qa/.cache/tvision
curl -fL -o qa/.cache/tvision/tvedit-dos.zip \
  https://github.com/magiblot/tvision/releases/download/r415/tvedit-dos.zip
```

Expected archive SHA-256:
`c72678d79a66bb2ac28f612d4c63970e58b29c26f9ef4a30d1317105306ffe9c`.
The test verifies this before extracting the single named executable.
The archive may live elsewhere: use `TVEDIT_ARCHIVE` or `--tvedit`. Its pin
identifies test input; it is not a restriction on user applications.

Additional application fixtures are optional and are never redistributed in the
repository. Supply copies you can use via these options or environment variables:

| Option / environment | Fixture |
| --- | --- |
| `--borland-bin` / `BORLAND_BIN` | BC 3.1 BIN directory with BC.EXE, DPMI16BI.OVL, DPMILOAD.EXE and DPMIMEM.DLL |
| `--qbasic` / `QBASIC_EXE` | QBASIC 1.1 executable, used as the IDE and with `/EDITOR` |
| `--msedit2` / `MSEDIT2_COM` | Standalone MS-DOS Editor 2.0.026 EDIT.COM |
| `--pedit` / `PEDIT_EXE` | PEDIT executable, with the Tables / ASCII Chart menu |
| `--dos-apps` / `DOS_APPS` | Root containing `tc201/TC.EXE` and `tc30/TC.EXE`; tc30 also needs the three DPMI files above |
| `--pctools` / `PCTOOLS_DIR` | Unpacked PC Tools 9 directory, including PCSHELL.EXE, its configuration and overlays |
| `--dosshell` / `DOSSHELL_DIR` | MS-DOS Shell with DOSSHELL.EXE, DOSSHELL.VID, DOSSHELL.INI and DOSSHELL.HLP; use the standard VGA configuration |

The [DOS software collection](https://software-archive.tifan.la/cndos-new-dos-16-years-collection/)
contains Turbo C 2.01 (`soft/doswaref/TC201.zip`) and Turbo C++ 3.0
(`soft/doswaref/tc30.zip`). TC201's executable is in Disk2. The TC30 IDE archive
spans IDE.CA1 and IDE.CA2: remove each four-byte wrapper, concatenate the payloads
in order, then extract TC.EXE; the DPMI files are in BIN.ZIP. Extraction requires
a tool supporting ZIP's legacy implode method. Keep downloads and extraction
under ignored `qa/.cache/`, or anywhere outside the checkout.

These source archive hashes identify the fixtures used:

| Archive | SHA-256 |
| --- | --- |
| TC201.zip | `2c87f988605ae9ed70e5fef35b9854de87e36ccdb021caec35ab2424ca4b5553` |
| tc30.zip | `ee028467cf1b5d63b81f8cf8dabc80b1fe9af567fba6ad7e9e3a4a8c37275a2d` |
| soft/doswareh/pct9.zip | `b1628757223ccfb355d5118098c7e7ef2edc3e0e97a8f59994411cf4637c9744` |
| soft/doswarea/msdos71f.zip | `36262793c92caae9443d8eeb1c8f68f4e4e52a735eb2887b22ee5fc6755ce7d3` |

The standalone editor is `DOSGUI/EDIT.COM` inside DOS71_2S.PAK on DOS71_2.IMG.
The installation script on DOS71_1.IMG supplies the archive password `:MSDOS`.

Each application run records the actual executable/overlay hashes in
`application.json`; alternate fixtures can be tested without changing a pin.
Editing and keyboard/menu tests additionally need Xvfb, libX11 and libXtst on the
host, and DOSBox's null-modem serial support. Each test creates a private X
display and a loopback connection. No input goes to the user's desktop.

PC Tools also needs mtools (`mformat`, `mcopy`, `mtype`) and an emulator that
supports its absolute DOS disk reads. The test creates a disposable FAT12 disk,
opens it in PC Shell, and checks the saved file inside the image. DOSBox 0.74-3
stalls during PC Shell's drive scan even without HHBIOS; the PC Tools case is
therefore separately selected with `--pctools`. The keyboard implementation
has no emulator-name or version checks. PC Tools uses the existing `READ5`
XMS font loader to leave conventional memory available, and `/NF /25 /IM`
to retain the display font and use the 25-row keyboard interface.
`test_pctools.py` also checks its initial dialog, directory tree and File menu
under native text, VGA and VESA. Supply `--msdos-image` and `--screenshots` with
`--pctools`; it boots disposable copies of the QA disk and checks the rendered
tree glyphs as well as the text buffer.
`test_pedit.py` checks half-block menu borders and dotted separators with the
same MS-DOS and screenshot options, deleting its temporary disk after each
case. Interactive preparation keeps `EDIT2` (Microsoft Editor) and `PEDIT`
as separate launchers; their default fixture locations are
`dos-apps/edit2/EDIT.COM` and `dos-apps/pedit/PEDIT.EXE` under the cache.
Turbo C 2.01 also uses READ5 so its real-mode IDE has enough conventional memory.
`test_borland_dpmi_font_memory` exercises Borland C++ 3.1 and Turbo C++ 3.0
with each of READ4 and READ5, checking Chinese cursor movement, deletion and
saved file bytes through their 16-bit DPMI runtime.

### DOSSHELL text modes

The [MS-DOS 6.22 supplemental package](https://ftp.zx.net.nz/pub/archive/ftp.microsoft.com/Softlib/MSLFILES/SUP622.EXE)
contains DOSSHELL. The archive SHA-256 is
`9240c2c624b9fd328f0ac21cbea93e3d75f8ede6485c43bbe86a95071ddda69a`.
Unpack the self-extracting ZIP, then use its DOS `EXPAND.EXE` to expand
`DOSSHELL.EX_` and `DOSSHELL.HL_`. For VGA, expand `VGA.VI_` to
`DOSSHELL.VID` and `EGA.IN_` to `DOSSHELL.INI`, as specified by the package's
`SETUP.BAT`. Keep these optional binaries outside version control.

```sh
python qa/run.py application qa/spec/test_dosshell.py \
  --dosshell /path/to/dosshell --screenshots --dosbox /path/to/dosbox
```

The tests launch the actual shell in `/T:L`, `/T:H1` and `/T:H2` (80×25,
80×43 and 80×50), with a native BIOS control and the resident VESA driver.
They select a program item below row 24 in high modes, click File in each
geometry, and choose high-row modes in DOSSHELL's
Display dialog, then return to 25 rows. No helper preselects the row count.
The VESA cases load CKBD and verify both DOSSHELL's last-row shortcuts and the
separate HHBIOS input-method row, including its original four-cell bitmap logo.
Only the copied configuration gets a Chinese program title; the supplied
application files are untouched.

`test_prompt.py` additionally checks prompt visibility settings, copied bitmap
lifetime, clipped/overlapping bitmap and character writes, 25/43/50-row changes,
VBE state restoration and graphics-to-text returns using actual planar pixels.

`SHELL.BIN` holds up to five records, each containing twelve metadata words,
256 BDA bytes, and an 8000-byte text area (the metadata gives the used length).
`AFTER.BIN` records the BDA after exit. `VIDEO.BIN` logs up to 256 AX/BX/CX/DX
requests for mode, font and adapter services. The observer calls no DOS
services from INT 1Ch and waits for a safe text aperture before reading B800.
Physical keyboard/mouse events and SDL screenshots use the existing serial
handshake. Assertions cover actual row counts, menu responses, exit geometry,
Chinese glyph pixels, pane borders, directory branches and the last-row footer.

DOSSHELL loads its text font with `AX=1110h`, including after temporary graphics
mode probes, and checks the scanline count returned by `AX=1B00h`. These paths
are distinct from selecting the ROM font with `AX=1112h`. The VESA driver
preserves its native Chinese font while honoring the logical font height;
arbitrary application-supplied glyph shapes are not installed in its renderer.

## Layers

| Command | What it establishes |
| --- | --- |
| `make check` | All DOS modules build, including the C/assembly keyboard and display drivers; this is not behavioral proof |
| `make qa-test` | Real 16-bit display and keyboard instructions, UMB allocation failures/state restoration, memory boundaries, FSM/geometry cases, transport failures |
| `make qa-dos` | DOS memory ownership and reclamation, font storage, raw B800, four VGA planes, attributes, cursor, font API, mode changes, incremental updates, command-line behavior, VBE queries and GB2312 filenames |
| `make qa-application` | tvedit glyphs/frames plus editor cursor movement, Delete, Backspace and saved bytes; configured optional editors run the same scenarios |
| `make qa-all` | All three required layers; missing prerequisites fail |
| `make qa-mutate` | Eight reviewed display/keyboard faults are caught by actual assertion failures |

`make qa-smoke` selects the mixed-frame DOS case. Selected tests require their
compiler, emulator, and fixtures. Deselected tests appear separately in the
report and do not count as passing.

Use `qa/run.py` for unique artifact directories, or pytest directly for focused
work. For example:

```sh
python qa/run.py unit -k pending
python qa/run.py dos --dosbox dosbox -k mode_change
python qa/run.py dos --dosbox dosbox-x -k mode_change
python -m pytest -m unit --source-dir=/path/to/baseline/src
```

Do not use `--basetemp` on a directory containing evidence you want to retain:
pytest owns that directory. `qa/run.py` creates a new run every time.
Use `--output-dir /path/to/runs` to store evidence elsewhere. A Git checkout
is optional; extracted source archives are identified by their file hashes.

## Oracles and failure artifacts

Unit tests link production C and `.INC` files into small COM harnesses. Display
and keyboard checks cover 8086, 386 and Pentium compiler targets. Unicorn
executes the machine code with distinct code/screen/stack segments, a bounded
instruction count, guarded screen reads/writes, and stack-balance checks. Only
the final hardware drawing routines are replaced, with recording stubs that
also clobber DS as the real routines do. Expectations are explicit glyph roles,
Unicode stroke semantics, and incremental-versus-fresh invariants, not a second
implementation of the classifier. Failed cases save input, B800, shadow, CPU
registers and drawing events.

The DOS observer returns binary data with a versioned header and exact length.
Host assertions compare all glyph scanlines in all four planes against the
BIOS 8x16 font and committed HZK16 for VGA, or the distributed HH20.FNT for
VESA, including frame extensions and per-cell colors. VESA's HHSNAP2 header
records pixel dimensions, pitch and cell dimensions; all 800x600 pixels are
captured. HHSNAP3 additionally records viewport origin and integer scale, with
32-bit bank-spanning capture for the entire high-resolution surface.
B800 attributes and Chinese text must remain
unchanged; explicitly identified frame cells may use the public conversion
codes. The tests distinguish those conversions from character erasure.
API checks include the resident IDs, video mode, full 32-byte Chinese glyph,
and teletype backspace position/data. Rendering is allowed to settle for 24 BIOS
ticks after each explicit frame write; no host sleep decides test success.

Memory tests walk the DOS MCB chain before installation, after running another
program, and after two unload/reload cycles. They check resident ownership and
interrupt bounds, conventional/UMB occupancy, XMS/EMS reclamation, and preservation
of the caller's environment and DOS allocation policy. Cases cover `/N`, unavailable
UMBs, and DOS-managed UMBs with the XMS discovery interface hidden by a small guest
fixture. Font tests use distinct simplified/traditional glyph data to verify both
selection orders and shared single-font storage. The READ2 case checks that an
extra 16 font bytes require only one extra paragraph, with no retained environment.
`R16` cases reserve real XMS/EMS handles, leaving exactly 256 KiB, exactly 16
EMS pages, or two separate 192 KiB XMS holes. They check the chosen reader,
glyph bytes, conventional memory use and complete reclamation. `READ6` also
checks that its startup environment is released while its resident block remains.
API failure injection separately executes the allocator procedures extracted from
all 15 production modules, including unsupported DOS versions and failed queries,
linking, strategy changes, and allocation.

For legacy drivers the framebuffer address comes from HHBIOS's public
`INT 10h AX=1406h` API. It may be AE02h, not A000h. VESA capture uses its
bank-aware `AX=1412h` API; a framebuffer pointer is not permanently mapped
while B800 holds the text pages. CRTC registers are recorded for diagnosis, not used
as an unquestioned scanout oracle: DOSBox-X's [overflow-register write path](https://github.com/joncampbell123/dosbox-x/blob/master/src/hardware/vga_crtc.cpp)
can update the live line comparator while leaving protected-register readback
unchanged. These assertions prove framebuffer contents, not host compositing.

`test_vesa_api.py` executes the linked C/assembly COM with a substituted BIOS:
nested calls, foreign caller stacks, returned status, bank failures, initialization
rollback, state-buffer overflow and DOS UMB allocation failures. Its host C cases
check geometry, window permissions and RGB masks independently of renderer selection.
Character-boundary cases poison B800 during a banked draw and require the
query to use the text snapshot without touching the occupied renderer stack.
`test_vesa.py` captures all 800x600 pixels in four planes under three VBE profiles,
checks resident MCB ownership and `/N`, mode/state restoration, GC/SEQ preservation,
bitmap/wide text, pixel bounds and all eight text pages across scrolling.
It checks blank cells across the entire viewport to detect text-bank aliases,
and checks native simplified/traditional glyphs plus cursor XOR under both
XMS and EMS. `test_font20.py` executes the linked font loader and cache with
manager failure injection, verifying file closure, allocation release and
failed-cache-miss retries. Neither test execution nor a normal build needs
the optional FreeType/OpenCC font-generation dependencies.
`test_vesa_application.py` runs the same editing scenarios on VESA as on VGA.

The application observer waits for its unique fixture marker and 24 guest
ticks. It feeds keys individually, records cursor/row data after each action,
and captures B800 plus the top ten green-plane rows. HHAPP2 records pitch and
cell dimensions, so the same observer covers VGA and VESA. DOS writes happen only
after the editor exits. Missing marker, incomplete capture or failed exit is
a failure. Saved files must match exact expected bytes, including the DOS EOF
marker written by Turbo C 2.01 and PC Tools. Each editing scenario has an
enabled/disabled control.

Editing cases use physical keys requested by the observer over COM1. This also
exercises application keyboard interrupts, such as QBASIC's menu input path.
The host sends make/break events through the isolated SDL window
and acknowledges each key. Guest-side observations determine when to request
the next action. `KEYLOG.BIN` contains 164-byte records: requested key (word),
BIOS cursor (word), and the 160-byte cursor row. The initial record has key zero.
See [KEYBOARD-RULES.md](KEYBOARD-RULES.md) for behavior and scope.

## Display screenshots

Add `--screenshots` to display or editor runs to capture the actual SDL window
through an isolated Xvfb display. This optional workflow needs ImageMagick
(`import` and `convert`) in addition to the physical-keyboard dependencies.
For example, with the selected toolchain and application fixture options:

```sh
python qa/run.py dos qa/spec/test_dos_display.py qa/spec/test_vesa.py --screenshots
python qa/run.py application qa/spec/test_vesa_application.py --screenshots
python qa/run.py application qa/spec/test_application.py -k tabs_and_long --screenshots
python qa/gallery.py --output qa/out/gallery qa/out/runs/<run-id> [qa/out/runs/<another-run> ...]
```

Open `qa/out/gallery/index.html` locally. The self-contained gallery retains
original PNGs, source/tool hashes, raw observations, test outcomes and failures.
It copies no third-party executables. `screenshots.json` links each frame to the
next requested key; the guest has settled and recorded its previous action at
that point. Startup and exit-menu frames are included. No screenshot hotkey is
sent to the guest, and capture does not replace or repaint any glyphs.

The virtual desktop accommodates a window resized from DOS text mode to the
full graphics resolution. Tests reject clipped or scaled window dimensions.
Text-screen cases compare every SDL pixel against the four recorded planes,
normalizing only the exact VGA-palette quantization of SDL RGB565 surfaces.
This checks visible scanout as well as framebuffer contents. Boundary scenes
include tables mixed with Chinese, 16 foreground/background colors, odd/even
cell positions, all four corners, orphan bytes at row boundaries, bottom-right
glyphs, policy changes, prompt clipping, simplified/traditional glyphs and
cursor XOR. The Turbo Vision document includes real tabs and clipped long lines;
its assertions cover tab alignment and unchanged file bytes, while right-edge
appearance remains available for visual review.

Capturing delays delivery of the next requested key. These runs establish
screen contents and editing results, not interactive latency. A passing case
does not assert that every visual detail is correct; review the full pictures
and retain unexpected or intermittent results alongside successful captures.

Every `qa/run.py` execution retains `qa/out/runs/<unique-id>/` containing a
JUnit XML report, console log, source/font/tool hashes and commands. DOS cases
add build products, guest logs, raw snapshots and PPM images. Host subprocess
timeouts kill/reap the emulator process group. Each case runs with a private
working directory and configuration, using SDL's dummy drivers or the private
X display for physical keyboard cases.

`qa/mutate.py` works on isolated source copies. It rejects surviving mutants
and compile/setup errors; only selected tests' assertion failures count as a
kill. This validates specific detection abilities, not total code coverage.

## Scope

Unicorn is not cycle accurate. The DOS layer uses `VGA.COM` with
`machine=vgaonly` and `VESA.COM` with SVGA profiles. EGA/HGA share the assembly
classifier and are built, but are not validated on physical hardware. VBE tests
cover coexistence with both resident drivers and VESA's 800x600 planar Chinese
rendering. They do not establish arbitrary resolutions or high-color rendering.
The full suite's executable provenance is in its manifest; font and emulator
results cannot be generalized to every BIOS/font/card combination.

The framework uses [pytest fixtures/parametrization](https://docs.pytest.org/en/stable/how-to/fixtures.html)
and [Unicorn's CPU execution API](https://github.com/unicorn-engine/unicorn/wiki/Quick-Start).

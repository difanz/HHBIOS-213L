# HHBIOS tests

The pytest suite checks display and editing behavior at three levels: production
assembly instructions, DOS framebuffer and BIOS state, and real editors. Host
assertions compare observed state with expected character roles, font pixels,
API results, cursor movement and saved document bytes.

Read [DISPLAY-RULES.md](DISPLAY-RULES.md) for the mixed-text contract and the
two-state Chinese-pairing FSM. Ambiguous GB2312/CP437 bytes require explicit
policy to determine how they display.

## Setup

Use Python 3.10 or newer and the patched JWasm described in the root
README. Install the dependencies for the selected layer before running it.
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
| `--qbasic` / `QBASIC_EXE` | QBASIC 1.1 executable, invoked with `/EDITOR` |
| `--msedit2` / `MSEDIT2_COM` | Standalone MS-DOS Editor 2.0.026 EDIT.COM |
| `--dos-apps` / `DOS_APPS` | Root containing `tc201/TC.EXE` and `tc30/TC.EXE`; tc30 also needs the three DPMI files above |
| `--pctools` / `PCTOOLS_DIR` | Unpacked PC Tools 9 directory, including PCSHELL.EXE, its configuration and overlays |

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
Turbo C 2.01 also uses READ5 so its real-mode IDE has enough conventional memory.

## Layers

| Command | What it establishes |
| --- | --- |
| `make check` | All 51 COM modules assemble; this is not behavioral proof |
| `make qa-test` | Real 16-bit display and keyboard instructions, UMB allocation failures/state restoration, memory boundaries, FSM/geometry cases, transport failures |
| `make qa-dos` | DOS memory ownership and reclamation, font storage, raw B800, four VGA planes, attributes, cursor, font API, mode changes, incremental updates |
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

Unit tests include the production `.INC` files in a small COM harness. Unicorn
executes the machine code with distinct code/screen/stack segments, a bounded
instruction count, guarded screen reads/writes, and stack-balance checks. Only
the final hardware drawing routines are replaced, with recording stubs that
also clobber DS as the real routines do. Expectations are explicit glyph roles,
Unicode stroke semantics, and incremental-versus-fresh invariants, not a second
implementation of the classifier. Failed cases save input, B800, shadow, CPU
registers and drawing events.

The DOS observer returns binary data with a versioned header and exact length.
Host assertions compare all glyph scanlines in all four planes against the
BIOS 8x16 font and the committed HZK16, including the driver's 18-line frame
extension and per-cell colors. B800 attributes and Chinese text must remain
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
API failure injection separately executes the allocator procedures extracted from
all 15 production modules, including unsupported DOS versions and failed queries,
linking, strategy changes, and allocation.

The framebuffer address comes from HHBIOS's public `INT 10h AX=1406h` API.
It may be AE02h, not A000h. CRTC registers are recorded for diagnosis, not used
as an unquestioned scanout oracle: DOSBox-X's [overflow-register write path](https://github.com/joncampbell123/dosbox-x/blob/master/src/hardware/vga_crtc.cpp)
can update the live line comparator while leaving protected-register readback
unchanged. These assertions prove framebuffer contents, not host compositing.

The application observer waits for its unique fixture marker and 24 guest
ticks. It feeds keys individually, records cursor/row data after each action,
and captures B800 plus the top ten green-plane rows. DOS writes happen only
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
`machine=vgaonly`; EGA/HGA share the assembly classifier and are built, but are
not validated on physical hardware. There is no VBE-driver validation here.
The full suite's executable provenance is in its manifest; font and emulator
results cannot be generalized to every BIOS/font/card combination.

The framework uses [pytest fixtures/parametrization](https://docs.pytest.org/en/stable/how-to/fixtures.html)
and [Unicorn's CPU execution API](https://github.com/unicorn-engine/unicorn/wiki/Quick-Start).

## Auxiliary probes

`make qa-legacy` and `make qa-smoke-usage` run the shell probes in `qa/tests`
and `qa/smoke-usage`, using helpers from `qa/input`. These targets are outside
`qa-all`. Their expectations differ from the display contract: `half-del`
expects erasure of the unmodified half of a Chinese character, and `tv-edit`
uses space-prefixed Chinese lines. Use `qa/spec` for display regression tests.

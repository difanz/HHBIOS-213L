# HHBIOS tests

The pytest suite checks display behavior at three levels: production assembly
instructions, DOS framebuffer and BIOS state, and a real editor's mixed-text
view. Host assertions compare observed state with expected character roles,
font pixels, and API results.

Read [DISPLAY-RULES.md](DISPLAY-RULES.md) for the mixed-text contract and the
two-state Chinese-pairing FSM. Ambiguous GB2312/CP437 bytes require explicit
policy to determine how they display.

## Setup

Use Python 3.10 or newer and the patched JWasm described in the root
README. Install the dependencies for the selected layer before running it.
Missing tools or fixtures cause a test failure; tests do not download them.

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

## Layers

| Command | What it establishes |
| --- | --- |
| `make check` | All 51 COM modules assemble; this is not behavioral proof |
| `make qa-test` | Real 16-bit classifier/repaint/teletype instructions, memory boundaries, directed FSM/geometry cases, deterministic incremental updates, transport failure handling |
| `make qa-dos` | READ2 + VGA + CMODE in the selected DOSBox: raw B800, four VGA planes, attributes, cursor, font API, mode changes, incremental updates |
| `make qa-application` | tvedit displays unindented GB2312 text; Chinese glyphs and window frame caps match the expected font pixels |
| `make qa-all` | All three required layers; missing prerequisites fail |
| `make qa-mutate` | Five reviewed production-assembly faults are caught by actual assertion failures |

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

The framebuffer address comes from HHBIOS's public `INT 10h AX=1406h` API.
It may be AE02h, not A000h. CRTC registers are recorded for diagnosis, not used
as an unquestioned scanout oracle: DOSBox-X's [overflow-register write path](https://github.com/joncampbell123/dosbox-x/blob/master/src/hardware/vga_crtc.cpp)
can update the live line comparator while leaving protected-register readback
unchanged. These assertions prove framebuffer contents, not host compositing.

The application observer waits until its unique fixture marker appears, then
24 guest ticks, copies B800 and the top ten rows of the green plane into resident
RAM, and sends Alt-X through the BIOS keyboard buffer. DOS writes happen only
after the editor exits. Missing marker, incomplete capture or failed exit is
a failure. This covers the loaded-file view, not arbitrary editing workflows.

Every `qa/run.py` execution retains `qa/out/runs/<unique-id>/` containing a
JUnit XML report, console log, source/font/tool hashes and commands. DOS cases
add build products, guest logs, raw snapshots and PPM images. Host subprocess
timeouts kill/reap the emulator process group. Each case runs with a private
working directory and configuration, using SDL's dummy video/audio drivers.

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

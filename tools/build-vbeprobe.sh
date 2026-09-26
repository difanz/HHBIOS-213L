#!/usr/bin/env bash
# Build the VBE test probe into build/VBEPROBE.COM. Not part of default `make`.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bash "$ROOT/tools/build-watcom-com.sh" qa/tests/vbeprobe/vbeprobe.c build/VBEPROBE.COM

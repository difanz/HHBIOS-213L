#!/usr/bin/env bash
# Build src/c/vbeprobe.c into build/VBEPROBE.COM. Not part of default `make`.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bash "$ROOT/tools/build-watcom-com.sh" src/c/vbeprobe.c build/VBEPROBE.COM

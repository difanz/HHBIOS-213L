#!/usr/bin/env bash
# Build src/c/vbeprobe.c into build/VBEPROBE.COM with Open Watcom.
# Default `make` does not call this. Watcom itself is not in the repo.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

if [[ -n "${WATCOM:-}" ]]; then
    if [[ -d "$WATCOM/binl" ]]; then
        PATH="$WATCOM/binl:${PATH:-}"
    fi
    if [[ -d "$WATCOM/binl64" ]]; then
        PATH="$WATCOM/binl64:${PATH:-}"
    fi
    export PATH
    if [[ -z "${INCLUDE:-}" && -d "$WATCOM/h" ]]; then
        INCLUDE="$WATCOM/h"
        export INCLUDE
    fi
    if [[ -z "${EDPATH:-}" && -d "$WATCOM/eddat" ]]; then
        EDPATH="$WATCOM/eddat"
        export EDPATH
    fi
fi

if ! command -v wcl >/dev/null 2>&1; then
    echo "vbeprobe: Open Watcom wcl not found." >&2
    echo "Install the Open Watcom v2 Linux x64 C compiler, then:" >&2
    echo "  export WATCOM=<prefix>" >&2
    echo "  . \"\$WATCOM/owsetenv.sh\"" >&2
    echo "  make vbeprobe" >&2
    exit 1
fi

mkdir -p build
(
    cd build
    wcl -y -q -0 -bt=dos -mt -lr -fe=VBEPROBE.COM ../src/c/vbeprobe.c
    rm -f vbeprobe.obj vbeprobe.err VBEPROBE.ERR
)
test -s build/VBEPROBE.COM
echo "vbeprobe: build/VBEPROBE.COM"

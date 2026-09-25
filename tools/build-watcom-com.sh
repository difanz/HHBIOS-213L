#!/usr/bin/env bash
# Build one 16-bit DOS .COM with Open Watcom.
#   tools/build-watcom-com.sh <source.c> <output.com> [extra.c-or-.asm ...]
# Watcom is not in the repo. Set WATCOM or put wcl on PATH.
set -eu

if [[ $# -lt 2 ]]; then
    echo "usage: tools/build-watcom-com.sh <source.c> <output.com> [extra...]" >&2
    exit 1
fi

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

src=$1
out=$2
shift 2
extras=()
for extra in "$@"; do
    case "$extra" in
        /*|~*|*..*)
            echo "watcom: extra path must stay inside the repo: $extra" >&2
            exit 1
            ;;
    esac
    extras+=("$ROOT/$extra")
done

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
    echo "watcom: wcl not found." >&2
    echo "Install the Open Watcom v2 Linux x64 C compiler, then:" >&2
    echo "  export WATCOM=<prefix>" >&2
    echo "  . \"\$WATCOM/owsetenv.sh\"" >&2
    exit 1
fi

mkdir -p "$(dirname "$out")"
objdir=$(dirname "$out")
base=$(basename "$src" .c)
(
    cd "$objdir"
    if [[ ${#extras[@]} -eq 0 ]]; then
        wcl -y -q -0 -bt=dos -mt -lr -fe="$(basename "$out")" "$ROOT/$src"
    else
        # wcl treats an .asm on the same command as an assembler program and
        # drops the C runtime. Compile each file, then link the objects.
        objs=("$base.obj")
        wcc -q -0 -bt=dos -ms -fo="$base.obj" "$ROOT/$src"
        extra_i=0
        for extra in "${extras[@]}"; do
            extra_i=$((extra_i + 1))
            eobj="extra${extra_i}.obj"
            case "$extra" in
                *.asm|*.ASM)
                    if ! command -v wasm >/dev/null 2>&1; then
                        echo "watcom: wasm not found (needed for $extra)." >&2
                        exit 1
                    fi
                    wasm -q -0 -bt=dos -ms -fo="$eobj" "$extra"
                    ;;
                *.c|*.C)
                    wcc -q -0 -bt=dos -ms -fo="$eobj" "$extra"
                    ;;
                *)
                    echo "watcom: unsupported extra file: $extra" >&2
                    exit 1
                    ;;
            esac
            objs+=("$eobj")
        done
        wcl -q -0 -bt=dos -mt -lr -fe="$(basename "$out")" "${objs[@]}"
        rm -f "${objs[@]}"
    fi
    rm -f "$base.obj" "$base.err" "$(basename "$out" .COM).ERR" "$(basename "$out" .com).err"
)
test -s "$out"
echo "watcom: $out"

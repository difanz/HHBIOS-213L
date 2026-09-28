#!/usr/bin/env bash
# Freestanding 8086 printer font reader; all three sizes use the same C backend.
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
size=$1
output=$2
source_dir=${3:-"$root/src"}
case "$size" in 24|32|40) ;; *) echo 'Printing size must be 24, 32 or 40' >&2; exit 2;; esac
[[ -z ${WATCOM:-} ]] || export PATH="$WATCOM/binl64:$WATCOM/binl:$PATH"
assembler=$(realpath "$(command -v "${JWASM:-jwasm}")")
mkdir -p "$(dirname -- "$output")"
output=$(realpath "$output")
source_dir=$(realpath "$source_dir")
work=$(mktemp -d "$(dirname -- "$output")/.printfont-XXXXXX")
trap 'rm -rf "$work"' EXIT
(
    cd "$work"
    for source in font/bitmap font/print_font common/font_file; do
        object=${source##*/}
        wcc -q -0 -bt=dos -ms -s -os -oi -zl -zlf -dPRINT_SIZE="$size" \
            -fo="$object.obj" "$source_dir/$source.c"
    done
    env -u JWASM "$assembler" -q -0 -Zm -omf -DPRINT_SIZE="$size" \
        -Fobridge.obj "$source_dir/font/print_font.asm"
    wlink option quiet option nodefaultlibs format dos com option map=reader.map \
        name reader.com file bridge.obj,bitmap.obj,print_font.obj,font_file.obj \
        order clname CODE clname DATA clname BSS clname ZZEND clname TAIL clname INIT
    cp reader.com "$output"
    cp reader.map "${output%.*}.map"
)

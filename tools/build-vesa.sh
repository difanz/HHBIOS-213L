#!/usr/bin/env bash
# Freestanding 8086 COM: no CRT, heap, extender or installed absolute paths.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${1:-"$root/build/VESA.COM"}
source_dir=${2:-"$root/src"}
mkdir -p "$(dirname -- "$out")"
out=$(realpath "$out")
source_dir=$(realpath "$source_dir")
if [[ -n ${WATCOM:-} ]]; then
    export PATH="$WATCOM/binl64:$WATCOM/binl:$PATH"
fi
for tool in wcc wlink; do
    command -v "$tool" >/dev/null || { echo "VESA needs Open Watcom ($tool); set WATCOM or PATH" >&2; exit 1; }
done
assembler=${JWASM:-jwasm}
assembler=$(realpath "$(command -v "$assembler")")
work=$(mktemp -d "$(dirname -- "$out")/.vesa-XXXXXX")
trap 'rm -rf "$work"' EXIT
(
    cd "$work"
    wcc -q -0 -bt=dos -ms -s -os -zl -zlf -fo=vesac.obj "$source_dir/vesa.c"
    env -u JWASM "$assembler" -q -0 -Zm -omf -I"$source_dir" -Fovesaa.obj "$source_dir/vesa.asm"
    wlink option quiet option nodefaultlibs format dos com option map=vesa.map name vesa.com file vesaa.obj,vesac.obj order clname CODE clname DATA clname BSS clname ZZEND clname TAIL clname INIT
    cp vesa.com "$out"
    cp vesa.map "${out%.*}.map"
)

#!/usr/bin/env bash
# Link a freestanding real-mode assembly module with shared WCC routines.
# build-module.sh source.asm output.com [source-root] [8086|386|586] [common ...]
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
input=$(realpath "$1")
output=$2
source_dir=$(realpath "${3:-$root/src}")
source "$root/tools/cpu-target.sh" "${4:-8086}"
[[ -z ${WATCOM:-} ]] || export PATH="$WATCOM/binl64:$WATCOM/binl:$PATH"
assembler=$(realpath "$(command -v "${JWASM:-jwasm}")")
source "$root/tools/source-tree.sh"
source_includes "$source_dir"
mkdir -p "$(dirname -- "$output")"
output=$(realpath "$output")
work=$(mktemp -d "$(dirname -- "$output")/.module-XXXXXX")
trap 'rm -rf "$work"' EXIT
(
    cd "$work"
    env -u JWASM "$assembler" -q -0 -Zm -omf -DHH_CPU="$cpu_flag" \
        "${asm_includes[@]}" -Fomain.obj "$input"
    objects=main.obj
    common_sources=("${@:5}")
    if ((${#common_sources[@]} == 0)); then
        case "$(basename "$input" | tr '[:lower:]' '[:upper:]')" in
            CKBD.ASM) common_sources=(text_edit pinyin);;
            KEYEDIT.ASM) common_sources=(text_edit);;
            *) common_sources=(frame);;
        esac
    fi
    for common in "${common_sources[@]}"; do
        case "$common" in
            frame|text_edit) c_source="$source_dir/common/$common.c";;
            pinyin) c_source="$source_dir/input/pinyin.c";;
            *) exit 2;;
        esac
        wcc "${common_c_flags[@]}" \
            -nt=COMMON_TEXT -nc=COMMON -fo="$common.obj" "$c_source"
        objects+=",$common.obj"
    done
    wlink option quiet option nodefaultlibs format dos com option map=module.map \
        name module.com file "$objects" \
        order clname CODE clname COMMON clname DATA clname BSS clname TAIL
    cp module.com "$output"
    cp module.map "${output%.*}.map"
)

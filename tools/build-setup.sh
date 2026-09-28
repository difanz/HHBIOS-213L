#!/usr/bin/env bash
# Native host build of an 8086 DOS executable and Open Watcom's C UI library.
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_dir=${WATCOM_SOURCE:-"$root/qa/.cache/setup/open-watcom-v2"}
output="$root/build/SETUP.EXE"
fetch=false
die() { echo "$*" >&2; exit 1; }
while (($#)); do
    case $1 in
        --watcom-source|--output)
            (($# >= 2)) || die "Missing value for $1"
            case $1 in
                --watcom-source) source_dir=$2;;
                --output) output=$2;;
            esac
            shift 2;;
        --fetch) fetch=true; shift;;
        -h|--help)
            echo "Usage: $0 [--watcom-source DIR] [--output EXE] [--fetch]"
            echo 'Set WATCOM for the compiler; WATCOM_SOURCE supplies Open Watcom sources.'
            echo '--fetch obtains the current upstream default branch if sources are absent.'
            exit 0;;
        *) die "Unknown option: $1";;
    esac
done
[[ -n ${WATCOM:-} ]] || die 'Set WATCOM to the Open Watcom installation directory.'
export PATH="$WATCOM/binl64:$WATCOM/binl:$PATH"
export INCLUDE="$WATCOM/h"
for tool in wcc wlib wlink; do
    command -v "$tool" >/dev/null || die "Open Watcom tool not found: $tool"
done
if $fetch && [[ ! -d $source_dir ]]; then
    git clone --depth 1 --filter=blob:none --sparse \
        https://github.com/open-watcom/open-watcom-v2.git "$source_dir"
    git -C "$source_dir" sparse-checkout set bld/ui bld/watcom/h \
        bld/clib/mbyte/h bld/trmem
fi
[[ -f $source_dir/bld/ui/master.mif ]] || die 'Set WATCOM_SOURCE or use --fetch to obtain Open Watcom UI sources.'
source_dir=$(realpath "$source_dir")
ui="$source_dir/bld/ui"
work="$root/build/setup-ui"
mkdir -p "$work/ui" "$(dirname -- "$output")"
output=$(realpath -m "$output")
flags=(-q -0 -bt=dos -ml -os -dNDEBUG -dCHARMAP
    -i="$ui/h" -i="$ui/dos/h" -i="$source_dir/bld/watcom/h"
    -i="$source_dir/bld/clib/mbyte/h" -i="$source_dir/bld/trmem")
# Follow upstream's platform object list, not every .c file in the tree.
mapfile -t objects < <(awk '
    /^common_objs =/ { common = 1; next }
    common && !NF { common = 0 }
    common { for (i = 1; i <= NF; ++i) if ($i ~ /\.obj$/) print $i }
    /^!inject / && $3 == "dos" { print $2 }
' "$ui/master.mif" | sed 's/\.obj$//' | LC_ALL=C sort -u)
((${#objects[@]})) || die 'Empty Open Watcom UI object list.'
fingerprint=$({
    sha256sum "$0" "$(command -v wcc)" "$(command -v wlib)"
    find "$ui" "$source_dir/bld/watcom/h" "$source_dir/bld/clib/mbyte/h" \
        "$source_dir/bld/trmem" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
} | sha256sum | cut -d' ' -f1)
if [[ ! -s $work/ui.lib || ! -f $work/ui.sha256 ]] ||
        [[ $(<"$work/ui.sha256") != "$fingerprint" ]]; then
    echo 'Building Open Watcom UI (8086, large model).'
    library_objects=()
    for name in "${objects[@]}" uialloc; do
        # SETUP supplies character decoding and mouse coordinates for its VGA buffer.
        [[ $name != uichlen && $name != uimous ]] || continue
        source="$ui/dos/c/$name.c"
        [[ -f $source ]] || source="$ui/c/$name.c"
        [[ -f $source ]] || die "Missing UI source: $name"
        extra=()
        # Initialize the text backend before SETUP optionally selects graphics.
        [[ $name != uibios ]] || extra=(-dinitbios=InitTextBios)
        wcc "${flags[@]}" "${extra[@]}" -fo="$work/ui/$name.obj" "$source"
        library_objects+=("+$work/ui/$name.obj")
    done
    rm -f "$work/ui.lib"
    wlib -q -b "$work/ui.lib" "${library_objects[@]}"
    printf '%s\n' "$fingerprint" > "$work/ui.sha256"
fi
app_objects=()
for source in "$root"/src/setup/*.c; do
    name=$(basename "$source" .c)
    # Source stays UTF-8 in Git; the standalone DOS UI displays GB2312 glyphs.
    iconv -f UTF-8 -t GB2312 "$source" > "$work/$name.c"
    wcc "${flags[@]}" -za99 -zt=4096 -i="$root/src/setup" -i="$root/src/video/vesa" \
        -fo="$work/$name.obj" "$work/$name.c"
    app_objects+=("$work/$name.obj")
done
for name in font_file font_layout; do
    wcc "${flags[@]}" -fo="$work/$name.obj" "$root/src/common/$name.c"
    app_objects+=("$work/$name.obj")
done
wcc "${flags[@]}" -dVESA_HOST -fo="$work/vlayout.obj" "$root/src/video/vesa/vesa.c"
{
    printf '%s\n' 'system dos' 'option quiet' 'option stack=32768'
    printf "name '%s'\noption map='%s/setup.map'\n" "$output" "$work"
    printf "file '%s'\n" "${app_objects[@]}" "$work/vlayout.obj"
    printf "library '%s/ui.lib'\n" "$work"
    printf "libpath '%s/lib286/dos'\nlibpath '%s/lib286'\n" "$WATCOM" "$WATCOM"
} > "$work/setup.lnk"
wlink @"$work/setup.lnk"
cp "$source_dir/license.txt" "$(dirname -- "$output")/SETUP.LIC"
printf '%s: %s bytes (8086 real-mode DOS)\n' "$output" "$(wc -c < "$output")"

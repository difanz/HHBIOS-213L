#!/usr/bin/env bash
# Real-mode Turbo Vision SETUP.EXE, built with a user-supplied BC++ 3.1.
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tv_rev=222c5042bd4ffd0ac8fb673c680d0d9301a2ab23
compiler=${BORLAND_DIR:-}
tv=${TVISION_DIR:-}
dosbox=${DOSBOX:-dosbox}
output="$root/build/SETUP.EXE"
fetch=false
die() { echo "$*" >&2; exit 1; }
usage() {
    echo "Usage: $0 [--borland DIR] [--tvision DIR] [--dosbox EXE] [--output EXE] [--fetch]"
    echo 'Defaults: BORLAND_DIR, TVISION_DIR, DOSBOX; --fetch downloads pinned TV 2.0 sources.'
}
while (($#)); do
    case $1 in
        --borland|--tvision|--dosbox|--output)
            (($# >= 2)) || die "Missing value for $1"
            case $1 in
                --borland) compiler=$2;; --tvision) tv=$2;;
                --dosbox) dosbox=$2;; --output) output=$2;;
            esac
            shift 2;;
        --fetch) fetch=true; shift;;
        -h|--help) usage; exit 0;;
        *) die "Unknown option: $1";;
    esac
done
[[ -n $compiler ]] || die 'Set BORLAND_DIR or pass --borland (Borland C++ 3.1 with TASM).'
compiler=$(realpath "$compiler")
for name in BCC TASM TLIB; do
    [[ -f $compiler/BIN/$name.EXE ]] || die "Missing $compiler/BIN/$name.EXE"
done
dosbox=$(command -v "$dosbox") || die 'DOSBox executable not found.'
dosbox=$(realpath "$dosbox")
cache="$root/qa/.cache/setup"
if $fetch; then
    mkdir -p "$cache"
    curl -fL "https://github.com/magiblot/tvision/archive/$tv_rev.tar.gz" -o "$cache/tvision.tar.gz"
    tar -xzf "$cache/tvision.tar.gz" -C "$cache" --no-same-owner
    tv="$cache/tvision-$tv_rev"
fi
tv=${tv:-"$cache/tvision-$tv_rev"}
[[ -f $tv/source/tvision/geninc.cpp ]] || die 'Set TVISION_DIR or use --fetch to obtain Turbo Vision 2.0.'
tv=$(realpath "$tv")
work="$root/build/setup"
mkdir -p "$work" "$(dirname -- "$output")"
output=$(realpath -m "$output")
for path in "$work" "$compiler"; do
    [[ $path != *'"'* && $path != *$'\n'* && $path != *$'\r'* ]] || die 'Invalid DOSBox mount path.'
done

# Cache libraries by content, compiler and recipe, independent of mtimes.
fingerprint=$({
    sha256sum "$root/tools/build-setup.sh" "$root/tools/tvision-bc31.patch"
    (cd "$tv"; find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum)
    (cd "$compiler"; sha256sum BIN/BCC.EXE BIN/TASM.EXE BIN/TLIB.EXE)
} | sha256sum | cut -d' ' -f1)
rebuild=true
if [[ -s $work/TV0.LIB && -s $work/TV1.LIB && -f $work/tv.sha256 ]] &&
        [[ $(<"$work/tv.sha256") == "$fingerprint" ]]; then
    rebuild=false
fi
if $rebuild; then
    mkdir -p "$work/tv/include" "$work/tv/src"
    cp -R "$tv/include/." "$work/tv/include/"
    cp -R "$tv/source/tvision/." "$work/tv/src/"
    for name in new.cpp tobjstrm.cpp; do
        tr -d '\r' < "$work/tv/src/$name" > "$work/$name.lf"
        mv "$work/$name.lf" "$work/tv/src/$name"
    done
    patch --batch --fuzz=0 -d "$work/tv/src" -p1 < "$root/tools/tvision-bc31.patch"
fi
for source in "$root"/src/setup/*.cpp "$root"/src/setup/*.h; do
    iconv -f UTF-8 -t GB2312 "$source" | sed 's/$/\r/' > "$work/$(basename "$source")"
done
cp "$root/src/vesa.h" "$work/vesa.h"
cp "$root/src/vesa.c" "$work/vlayout.cpp"
rm -f "$work"/{DONE.TXT,FAIL.TXT,BUILD.LOG,SETUP.EXE,TVBUILT.TXT}
flags='-ml -P -O1 -DNDEBUG -IB:\INCLUDE;C:\TV\INCLUDE -LB:\LIB'
dos_line() { printf '%s\r\n' "$@"; }
step() { dos_line "$* >> C:\BUILD.LOG" 'if errorlevel 1 goto failed'; }
{
    dos_line '@echo off' 'set PATH=B:\BIN' 'set INCLUDE=B:\INCLUDE' 'set LIB=B:\LIB'
    if $rebuild; then
        dos_line 'cd \tv\src'
        step "bcc $flags -egeninc.exe geninc.cpp"
        dos_line 'geninc > tvwrite.inc'
        # Only upstream's object list: the tree also has obsolete .cpp files.
        mapfile -t objects < <(grep -oE 'pfx[[:alnum:]_]+\.OBJ' "$tv/source/tvision/makefile" |
                              sed 's/^pfx//; s/\.OBJ$//' | tr '[:upper:]' '[:lower:]' | LC_ALL=C sort -u)
        ((${#objects[@]})) || die 'Empty Turbo Vision object list.'
        for name in "${objects[@]}"; do
            if [[ -f $work/tv/src/$name.cpp ]]; then
                step "bcc $flags -c $name.cpp"
            elif [[ -f $work/tv/src/$name.asm ]]; then
                step "tasm /ml /m2 $name.asm"
            else
                die "Missing Turbo Vision source: $name"
            fi
        done
        # TLIB 3.02 holds an archive in conventional memory. Split the library.
        for n in 0 1; do
            rm -f "$work/TV$n.LIB"
            start=$((n * ${#objects[@]} / 2))
            end=$(((n + 1) * ${#objects[@]} / 2))
            chunk=0
            while ((start < end)); do
                count=$((end - start)); ((count <= 12)) || count=12
                response="L${n}_${chunk}.RSP"
                { printf '+%s.obj ' "${objects[@]:start:count}"; printf '\r\n'; } > "$work/tv/src/$response"
                step "tlib /P128 /0 C:\TV$n.LIB @$response"
                start=$((start + count)); chunk=$((chunk + 1))
            done
        done
        dos_line 'echo done>C:\TVBUILT.TXT'
    fi
    dos_line 'cd \'
    step "bcc $flags -DVESA_HOST -c vlayout.cpp"
    # Response file avoids DOS's 126-byte command-tail limit.
    dos_line "$flags" '-esetup.exe' \
        'main.cpp probe.cpp config.cpp screen.cpp vlayout.obj tv0.lib tv1.lib' > "$work/SETUP.RSP"
    step 'bcc @SETUP.RSP'
    dos_line 'echo done>DONE.TXT' 'goto end' ':failed' 'echo failed>FAIL.TXT' ':end'
} > "$work/BUILD.BAT"
{
    printf '%s\n' '[sdl]' 'output=surface' '[cpu]' 'core=dynamic' 'cycles=max' '[autoexec]'
    printf 'mount c "%s"\nmount b "%s"\n' "$work" "$compiler"
    printf '%s\n' 'c:' 'call BUILD.BAT' 'exit'
} > "$work/build.conf"
echo "Building SETUP.EXE (Turbo Vision rebuild: $rebuild); log: $work/BUILD.LOG"
(
    cd "$work"
    SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 3600 "$dosbox" -conf "$work/build.conf"
) > "$work/emulator.log" 2>&1 || { tail -60 "$work/emulator.log" >&2; exit 1; }
[[ ! -f $work/TVBUILT.TXT ]] || printf '%s\n' "$fingerprint" > "$work/tv.sha256"
if [[ ! -f $work/DONE.TXT || -f $work/FAIL.TXT || ! -s $work/SETUP.EXE ]]; then
    tail -80 "$work/BUILD.LOG" >&2
    exit 1
fi
cp "$work/SETUP.EXE" "$output"
printf '%s: %s bytes (16-bit real-mode DOS)\n' "$output" "$(wc -c < "$output")"

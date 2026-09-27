#!/usr/bin/env bash
# Stage local QA fixtures and boot real MS-DOS with the full HHBIOS distribution.
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cache="$root/qa/.cache"
run="$root/build/run"
drive="$root/build/qa-tools"
dist="$root/build/distribution"
apps=${DOS_APPS:-"$cache/dos-apps"}
borland=${BORLAND_DIR:-${BORLAND_BIN:+"$(dirname "$BORLAND_BIN")"}}
borland=${borland:-"$cache/bc31"}
dosbox=${DOSBOX:-dosbox-x}
msdos_dir=${MSDOS_DIR:-"$apps/msdos622/files"}
msdos_boot=${MSDOS_BOOT:-"$apps/msdos622/MSD622BD.IMG"}
mouse=
mouse_driver=${QA_MOUSE_DRIVER:-cutemouse}
image="$run/MSDOS.IMG"
build=true
die() { echo "$*" >&2; exit 1; }
while (($#)); do
    case $1 in
        --borland|--dosbox|--msdos-dir|--msdos-boot|--mouse|--mouse-driver|--image)
            (($# >= 2)) || die "Missing value for $1"
            case $1 in
                --borland) borland=$2;; --dosbox) dosbox=$2;;
                --msdos-dir) msdos_dir=$2;; --msdos-boot) msdos_boot=$2;; --mouse) mouse=$2;;
                --mouse-driver) mouse_driver=$2;; --image) image=$2;;
            esac
            shift 2;;
        --no-build) build=false; shift;;
        -h|--help)
            echo "Usage: $0 [--borland DIR] [--dosbox EXE] [--msdos-dir DIR] [--msdos-boot IMG] [--mouse-driver cutemouse|vbmouse] [--mouse EXE] [--image IMG] [--no-build]"
            echo 'Requires local MS-DOS 6.x installation files (all disks), boot floppy, mouse driver, mtools and 7z.'
            echo 'CuteMouse uses captured relative input; VBMouse supports uncaptured absolute input for remote desktops.'
            echo 'Existing guest application settings are preserved. Close DOSBox before updating its disk.'
            exit 0;;
        *) die "Unknown option: $1";;
    esac
done
case $mouse_driver in
    cutemouse) mouse=${mouse:-${CTMOUSE_EXE:-"$apps/CTMOUSE.EXE"}};;
    vbmouse) mouse=${mouse:-${VBMOUSE_EXE:-"$cache/vbados/VBMOUSE.EXE"}};;
    *) die "Unknown mouse driver: $mouse_driver (use cutemouse or vbmouse)";;
esac
dosbox=$(command -v "$dosbox") || die 'DOSBox-X executable not found.'
dosbox=$(realpath "$dosbox")
msdos_dir=$(realpath -m "$msdos_dir")
msdos_boot=$(realpath -m "$msdos_boot")
mouse=$(realpath -m "$mouse")
image=$(realpath -m "$image")
mkdir -p "$run" "$drive/PROBES" "$dist" "$cache/distribution"
assembler=${JWASM:-$(command -v jwasm || printf '%s' "$cache/JWasm/build/GccUnixR/jwasm")}
assembler=$(realpath "$assembler")
if $build; then
    make -C "$root" all "JWASM=$assembler"
    # DOS names stay within 8.3. Additional entries are assembly helper files.
    while read -r name source helpers; do
        output="$drive/PROBES/$name.COM"
        dependencies=("$root/qa/harness/$source.c" "$root/tools/build-watcom-com.sh" "$root"/qa/harness/*.h)
        extra=()
        for helper in $helpers; do
            extra+=("qa/harness/$helper.asm")
            dependencies+=("$root/qa/harness/$helper.asm")
        done
        changed=false
        for dependency in "${dependencies[@]}"; do
            [[ -s $output && ! $dependency -nt $output ]] || changed=true
        done
        if $changed; then
            (cd "$root"; bash tools/build-watcom-com.sh "qa/harness/$source.c" "$output" "${extra[@]}")
        fi
    done <<'PROBES'
APPCAP appcap appcap
COMPAT compat
GRIDCAP gridcap appcap
KEYAPI keyapi
MEMCLI memclient
MEMTEST memory
MOUSEVW mouseview mouseview
MOUSEDIR mousedir
PERF perf
PRESSURE pressure
PRMTEST prompt
ROWGUARD rowguard
SELECTMD selectmode
SHELLCAP shellcap appcap videolog
SNAPSHOT snapshot
TEXTMODE textmode
VBETEST vbe
VESATEST vesatest
WIDEVIEW wideview
PROBES
    for name in NOXMS VESACAPS; do
        env -u JWASM "$assembler" -q -0 -bin "-Fo$drive/PROBES/$name.COM" "$root/qa/harness/${name,,}.asm"
    done
fi
modules=("$run/VESA.COM")
cp "$root/build/VESA.COM" "$root/fonts/HH20.FNT" "$run/"
for source in "$root"/src/*.ASM; do
    name=$(basename "$source" .ASM)
    cp "$root/build/$name.COM" "$run/"
    modules+=("$run/$name.COM")
done
[[ ! -f $root/build/SETUP.EXE ]] || cp "$root/build/SETUP.EXE" "$run/"
[[ ! -f $root/build/SETUP.LIC ]] || cp "$root/build/SETUP.LIC" "$run/"

# Preserve the original binary distribution, including its optional utilities,
# code tables and both 16-pixel fonts; overlay rebuilt modules in the disk.
command -v 7z >/dev/null || die 'Extracting the original ARJ self-extractors requires 7z.'
while IFS= read -r name; do
    case ${name^^} in
        *.COM|*.EXE|*.BAT|*.INI|*.SYS|*.DAT|*.TAB|*.BIN)
            git -C "$root" show "original-import:$name" > "$dist/${name^^}";;
    esac
done < <(git -C "$root" ls-tree --name-only original-import)
for name in 213L 213M H16F; do
    7z x -y -aoa "-o$dist" "$dist/$name.EXE" > "$cache/distribution/$name.log"
done
# shellcheck source=qa/msdos.sh
source "$root/qa/msdos.sh"
dos_lines '@ECHO OFF' 'C:' 'CD \HHBIOS' 'READ5' 'IF ERRORLEVEL 1 GOTO END' \
    'CKBD /E' 'IF ERRORLEVEL 1 GOTO END' 'VESA' ':END' '@ECHO ON' > "$dist/HHBIOS.BAT"

missing=()
: > "$drive/sources.tsv"
stage_app() {
    local name=$1 source=$2
    if [[ ! -d $source ]]; then missing+=("$name"); return; fi
    mkdir -p "$drive/$name"
    cp -R --update=none "$source/." "$drive/$name/"
    printf '%s\t%s\n' "$name" "$(realpath "$source")" >> "$drive/sources.tsv"
}
stage_app BC31 "$borland"
stage_app TC201 "$apps/tc201"
stage_app TC30 "$apps/tc30"
stage_app EDIT1 "$(dirname "${QBASIC_EXE:-$cache/msedit/QBASIC.EXE}")"
stage_app EDIT2 "$(dirname "${MSEDIT2_COM:-$cache/edit/EDIT.COM}")"
stage_app DOSSHELL "${DOSSHELL_DIR:-$apps/dosshell622}"
stage_app PCTOOLS "${PCTOOLS_DIR:-$apps/pct9}"
stage_app CWSDPMI "$(dirname "${CWSDPMI_EXE:-$cache/extenders/cwsdpmi7/bin/CWSDPMI.EXE}")"
stage_app HDPMI "$(dirname "${HDPMI32_EXE:-$cache/extenders/hx223/BIN/HDPMI32.EXE}")"
archive=${TVEDIT_ARCHIVE:-"$cache/tvision/tvedit-dos.zip"}
if [[ -f $archive ]]; then
    mkdir -p "$drive/TVEDIT"
    unzip -p "$archive" tvedit.exe > "$drive/TVEDIT/TVEDIT.EXE"
    printf 'TVEDIT\t%s\n' "$(realpath "$archive")" >> "$drive/sources.tsv"
else
    missing+=(TVEDIT)
fi
if [[ ! -f $drive/DEMO.TXT ]]; then
    printf '中文混排测试\r\nHHBIOS DOS QA\r\n边界：中文 ABC 中文\r\n' | iconv -f UTF-8 -t GB2312 > "$drive/DEMO.TXT"
fi
dos_lines '@ECHO OFF' 'ECHO C:\HHBIOS: full distribution and current modules / SETUP.EXE' \
    'ECHO Q: QA applications, Q:\PROBES: guest probes' 'ECHO.' > "$drive/TOOLS.BAT"
while read -r name folder command; do
    [[ -d $drive/$name ]] || continue
    dos_lines '@ECHO OFF' 'Q:' "CD \\$folder" "$command %1 %2 %3 %4 %5 %6 %7 %8 %9" '@ECHO ON' > "$drive/$name.BAT"
    dos_lines "ECHO   $name  -  Q:\\$folder\\$command" >> "$drive/TOOLS.BAT"
done <<'APPS'
BC31 BC31\BIN BC.EXE
TC201 TC201 TC.EXE
TC30 TC30 TC.EXE
EDIT1 EDIT1 QBASIC.EXE /EDITOR
EDIT2 EDIT2 EDIT.COM
DOSSHELL DOSSHELL DOSSHELL.EXE /T
PCTOOLS PCTOOLS PCSHELL.EXE C: /NF /25 /IM
TVEDIT TVEDIT TVEDIT.EXE
APPS
dos_lines 'ECHO.' 'ECHO Example: TVEDIT Q:\DEMO.TXT' '@ECHO ON' >> "$drive/TOOLS.BAT"
prepare_image
echo "Ready: $run/dosbox.conf (real MS-DOS; TOOLS lists QA applications)."
((${#missing[@]} == 0)) || echo "Unavailable optional fixtures: ${missing[*]}"

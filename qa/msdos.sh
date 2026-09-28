#!/usr/bin/env bash
# Sourced by prepare.sh. Local MS-DOS media provide EXPAND, SYS and FDISK.
# No DOS kernel, compiler or application binaries are downloaded by this tool.

dos_lines() { printf '%s\r\n' "$@"; }
stage_distribution() {
    local name
    command -v 7z >/dev/null || die 'Extracting the original ARJ self-extractors requires 7z.'
    mkdir -p "$dist" "$cache/distribution"
    while IFS= read -r name; do
        case ${name^^} in
            *.COM|*.EXE|*.BAT|*.INI|*.SYS|*.DAT|*.TAB|*.BIN)
                git -C "$root" show "original-import:$name" > "$dist/${name^^}";;
        esac
    done < <(git -C "$root" ls-tree --name-only original-import)
    for name in 213L 213M H16F; do
        7z x -y -aoa "-o$dist" "$dist/$name.EXE" > "$cache/distribution/$name.log"
    done
    # SETUP.EXE is the configuration editor in the runnable distribution.
    rm -f "$dist/LSETUP.COM"
}
remove_guest_lsetup() {
    if mdir -b -i "$volume" ::HHBIOS/LSETUP.COM >/dev/null 2>&1; then
        mdel -i "$volume" ::HHBIOS/LSETUP.COM
    fi
}
install_emulator() {
    {
        printf '%s\n' '[sdl]' 'output=surface' '[dosbox]' 'machine=svga_s3' \
            '[cpu]' 'cycles=max' '[autoexec]' '@echo off' "$@"
    } > "$install/install.conf"
    (
        cd "$install"
        SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 180 "$dosbox" -conf install.conf
    ) > "$install/install.log" 2>&1 || die "DOS installation failed; see $install/install.log"
}
fat_volume() {
    # IMGMAKE creates one active FAT16 partition in the first MBR entry.
    local -a entry
    read -ra entry < <(od -An -tu1 -j446 -N16 "$1")
    [[ ${entry[0]} == 128 && ${entry[4]} =~ ^(4|6|14)$ ]] || die "Invalid QA disk partition: $1"
    printf '%s@@%s\n' "$1" "$(( (entry[8]+entry[9]*256+entry[10]*65536+entry[11]*16777216)*512 ))"
}
word_at() {
    local lo hi
    read -r lo hi < <(od -An -tu1 -j"$2" -N2 "$1")
    echo "$((lo + hi*256))"
}
copy_missing() {
    # mcopy -n returns failure for skipped files. Check names explicitly so
    # an existing file is preserved without swallowing actual I/O failures.
    local source=$1 target="$2/$(basename "$1")" child
    if ! mdir -b -i "$volume" "$target" >/dev/null 2>&1; then
        mcopy -s -i "$volume" "$source" "$2/"
    elif [[ -d $source ]]; then
        while IFS= read -r -d '' child; do
            copy_missing "$child" "$target"
        done < <(find "$source" -mindepth 1 -maxdepth 1 -print0)
    fi
}
install_dos() {
    local source target size bytes
    for source in PACKING.LST EXPAND.EXE IO.SYS MSDOS.SYS COMMAND.COM FDISK.EXE SYS.COM; do
        [[ -f $msdos_dir/$source ]] || die "Missing installation file: $msdos_dir/$source"
    done
    [[ -f $msdos_boot ]] || die "Missing boot floppy: $msdos_boot"
    mkdir -p "$install/DOS"
    tr -d '\r' < "$msdos_dir/PACKING.LST" |
        awk 'NF==2 && $1~/^[A-Z0-9_.]+$/ && $2~/^[A-Z0-9_.]+$/ {print $1, $2}' > "$install/PACKING.TXT"
    [[ -s $install/PACKING.TXT ]] || die 'Empty MS-DOS packing list.'
    : > "$install/EXPAND.LOG"
    {
        dos_lines '@echo off'
        while read -r source target; do
            [[ -f $msdos_dir/$source ]] || die "Incomplete installation media: $source"
            if [[ $source == *_ ]]; then
                rm -f "$install/DOS/$target"
                dos_lines "D:\\EXPAND D:\\$source C:\\DOS\\$target >> C:\\EXPAND.LOG"
            else
                cp -f "$msdos_dir/$source" "$install/DOS/$target"
            fi
        done < "$install/PACKING.TXT"
        dos_lines 'copy Z:\BIN\SHUTDOWN.COM C:\SHUTDOWN.COM > nul' 'exit'
    } > "$install/EXPAND.BAT"
    install_emulator "mount c \"$install\"" "mount d \"$msdos_dir\"" 'c:' 'call EXPAND.BAT'
    while read -r source target; do
        [[ -s $install/DOS/$target ]] || die "EXPAND did not produce $target; see $install/EXPAND.LOG"
    done < "$install/PACKING.TXT"

    # Archived floppies sometimes omit unused sectors. Pad a disposable copy.
    size=$(( $(word_at "$msdos_boot" 19) * $(word_at "$msdos_boot" 11) ))
    bytes=$(wc -c < "$msdos_boot")
    [[ $size =~ ^(737280|1228800|1474560|2949120)$ && $bytes -le $size ]] || die 'Unsupported boot floppy geometry.'
    cp "$msdos_boot" "$install/BOOT.IMG"
    truncate -s "$size" "$install/BOOT.IMG"
    dos_lines 'FILES=30' 'BUFFERS=20' > "$install/CONFIG.SYS"
    dos_lines '@ECHO OFF' 'A:\FDISK /MBR' 'A:\SYS C:' 'IF ERRORLEVEL 1 GOTO FAILED' \
        'ECHO INSTALLED>C:\SYS.OK' ':FAILED' 'A:\SHUTDOWN /S' > "$install/AUTOEXEC.BAT"
    mcopy -o -i "$install/BOOT.IMG" "$install/CONFIG.SYS" "$install/AUTOEXEC.BAT" \
        "$install/SHUTDOWN.COM" "$msdos_dir/FDISK.EXE" "$msdos_dir/SYS.COM" ::/
    install_emulator "imgmake \"$image.new\" -t hd -size 128" \
        "imgmount c \"$image.new\"" "boot \"$install/BOOT.IMG\""
    volume=$(fat_volume "$image.new")
    [[ $(mtype -i "$volume" ::SYS.OK | tr -d '\r\n') == INSTALLED ]] || die "SYS failed; see $install/install.log"
    mcopy -s -i "$volume" "$install/DOS" ::/
    mcopy -i "$volume" "$install/SHUTDOWN.COM" ::DOS/
    mv "$image.new" "$image"
}
prepare_image() {
    local install="$root/build/msdos-install" volume path tool mouse_command mouse_lock
    for tool in mcopy mtype mmd mdir mdel od truncate fuser; do
        command -v "$tool" >/dev/null || die "Disk preparation requires $tool (mtools/coreutils/psmisc)."
    done
    if [[ -f $image ]] && fuser -s "$image"; then
        die "QA disk is in use. Close DOSBox or use --image with a separate disk: $image"
    fi
    [[ -f $mouse ]] || die "Missing $mouse_driver driver: $mouse (supply --mouse)."
    for path in "$run" "$image" "$msdos_dir" "$msdos_boot" "$mouse"; do
        [[ $path != *'"'* && $path != *$'\n'* && $path != *$'\r'* ]] || die 'Invalid DOSBox path.'
    done
    mkdir -p "$install" "$(dirname "$image")"
    if [[ ! -f $image ]]; then
        [[ ! -f $image.new ]] || die "Inspect/remove the incomplete disk before retrying: $image.new"
        echo 'Installing real MS-DOS from local media...'
        install_dos
    fi
    volume=$(fat_volume "$image")
    # Preserve guest application settings and HHBIOS configuration on updates.
    mmd -i "$volume" ::HHBIOS ::QA 2>/dev/null || true
    for path in "$dist"/*; do copy_missing "$path" ::HHBIOS; done
    for path in "$drive"/*; do
        case $(basename "$path") in sources.*|DATA.IMG) continue;; esac
        copy_missing "$path" ::QA
    done
    mcopy -o -i "$volume" "${modules[@]}" "$run/HH20.FNT" ::HHBIOS/
    mcopy -s -o -i "$volume" "$run/FONTINFO" ::HHBIOS/
    for path in "$run/SETUP.EXE" "$run/SETUP.LIC"; do
        [[ ! -f $path ]] || mcopy -o -i "$volume" "$path" ::HHBIOS/
    done
    remove_guest_lsetup
    mcopy -s -o -i "$volume" "$drive/PROBES" "$drive"/*.BAT ::QA/
    if [[ $mouse_driver == vbmouse ]]; then
        mcopy -o -i "$volume" "$mouse" ::DOS/VBMOUSE.EXE
        # Leave the large UMB blocks for CKBD and VESA. A small mouse driver
        # in low memory costs less than forcing the whole display TSR there.
        mouse_command='C:\DOS\VBMOUSE.EXE install low'
        mouse_lock=false
    else
        mcopy -o -i "$volume" "$mouse" ::DOS/CTMOUSE.EXE
        mouse_command='LH C:\DOS\CTMOUSE.EXE'
        mouse_lock=true
    fi
    dos_lines 'DEVICE=C:\DOS\HIMEM.SYS /TESTMEM:OFF' 'DEVICE=C:\DOS\EMM386.EXE RAM' \
        'DOS=HIGH,UMB' 'FILES=40' 'BUFFERS=20' 'LASTDRIVE=Z' \
        'SHELL=C:\COMMAND.COM C:\ /E:1024 /P' > "$install/CONFIG.SYS"
    dos_lines '@ECHO OFF' 'PROMPT $P$G' 'PATH C:\DOS;C:\HHBIOS;Q:\;Q:\PROBES;Q:\CWSDPMI;Q:\HDPMI' \
        'C:\DOS\SUBST Q: C:\QA' "$mouse_command" 'CD \HHBIOS' \
        'CALL HHBIOS.BAT' 'CD \' 'VER' 'ECHO TOOLS lists QA applications.' '@ECHO ON' > "$install/AUTOEXEC.BAT"
    mcopy -o -i "$volume" "$install/CONFIG.SYS" "$install/AUTOEXEC.BAT" ::/
    # Keep the function keys for HHBIOS and DOS applications. The mapper has
    # SDL1 and SDL2 sections; Ctrl+Alt+F10 remains available to release a mouse.
    cp "$root/qa/dosbox-x.map" "$run/dosbox-x.map"
    {
        printf '%s\n' '[sdl]' "autolock=$mouse_lock" 'mouse_emulation=locked' 'middle_unlock=none'
        printf 'mapperfile=%s/dosbox-x.map\n' "$run"
        [[ $mouse_driver != vbmouse ]] || printf '%s\n' '[dos]' 'vmware=true'
        printf '%s\n' '[dosbox]' 'machine=svga_s3' 'memsize=16' '[cpu]' 'cycles=30000' \
            '[autoexec]' '@echo off' 'imgmount 0 empty -fs none -t floppy'
        printf 'imgmount c "%s" -ide 1m\nboot c:\n' "$image"
    } > "$run/dosbox.conf"
}

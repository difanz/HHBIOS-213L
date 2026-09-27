#!/usr/bin/env bash
# Confirm every assembly module produced a non-empty COM.
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_dir=${1:-"$root/src"}
build=${2:-"$root/build"}
missing=(); empty=(); built=()
for source in "$source_dir"/*.ASM; do
    name=$(basename "$source" .ASM)
    if [[ ! -f $build/$name.COM ]]; then
        missing+=("$name")
    elif [[ ! -s $build/$name.COM ]]; then
        empty+=("$name")
    else
        built+=("$name")
    fi
done
printf 'assembled %s  missing %s  empty %s\n' "${#built[@]}" "${#missing[@]}" "${#empty[@]}"
for name in "${built[@]}"; do printf '%-10s %7s\n' "$name" "$(wc -c < "$build/$name.COM")"; done
for name in "${missing[@]}"; do echo "missing $name"; done
for name in "${empty[@]}"; do echo "empty $name"; done
((${#missing[@]} == 0 && ${#empty[@]} == 0))

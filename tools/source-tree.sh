#!/usr/bin/env bash
# Shared include search path for the legacy assembly modules.
source_includes() {
    local directory
    asm_includes=()
    while IFS= read -r -d '' directory; do
        asm_includes+=("-I$directory")
    done < <(find "$1" -type d -print0 | LC_ALL=C sort -z)
}

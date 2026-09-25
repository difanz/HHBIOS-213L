#!/usr/bin/env bash
# Run DOSBox-X cases under qa/tests/<name>/.
#
#   case.bat    DOS commands, one per line. The runner writes run.bat that
#               redirects each command into case.log (later lines append).
#               A line that already contains > is left as written.
#               Blank lines, REM, ::, and @echo are not launched.
#   expect.txt  ASCII markers, one per line. Each must appear in case.log.
#               Blank lines and lines starting with # are ignored.
#   files.txt   Repo-relative files copied onto the drive (basename kept).
#   prep        Host shell run from the repo root before the case (optional).
#   conf        qa/ config file name (optional; default dosbox-x-vbe.conf).
#   skip        If present, the case is not run. The first line is the reason.
#
# Usage: qa/run-suite.sh [--label NAME] [test-name ...]
# With no test names, every qa/tests/* directory is considered.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

LABEL=qa-test
if [[ "${1:-}" == "--label" ]]; then
    LABEL=${2:-qa-test}
    shift 2
fi

bash "$ROOT/qa/fetch-dosbox-x.sh"

BIN="$ROOT/qa/.cache/dosbox-x/dosbox-x-sdl2"
if [[ ! -x "$BIN" ]]; then
    echo "$LABEL: DOSBox-X binary missing at qa/.cache/dosbox-x/dosbox-x-sdl2" >&2
    exit 1
fi

missing=$(ldd "$BIN" | awk '/not found/ { print $1 }')
if [[ -n "$missing" ]]; then
    echo "$LABEL: DOSBox-X is missing host libraries:" >&2
    echo "$missing" >&2
    echo "Debian/Ubuntu packages: libsdl2-net-2.0-0 libpcap0.8 libslirp0 libfluidsynth3 libncurses6" >&2
    exit 1
fi

trim() {
    local s=$1
    s=${s//$'\r'/}
    s=${s#"${s%%[![:space:]]*}"}
    s=${s%"${s##*[![:space:]]}"}
    printf '%s' "$s"
}

run_dbx() {
    if [[ -n "${DISPLAY:-}" ]]; then
        SDL_AUDIODRIVER=dummy "$@"
    else
        if ! command -v xvfb-run >/dev/null 2>&1; then
            echo "$LABEL: DISPLAY is unset and xvfb-run is not installed." >&2
            exit 1
        fi
        SDL_AUDIODRIVER=dummy xvfb-run -a "$@"
    fi
}

passed=0
skipped=0
failed=0

run_one() {
    local dir=$1
    local name conf_name conf stage line src base
    local out found log marker markers=0 miss=0
    local dbx_status reason

    name=$(basename "$dir")
    if [[ ! -d "$dir" ]]; then
        echo "FAIL $name: no such test directory" >&2
        failed=$((failed + 1))
        return 0
    fi

    if [[ -f "$dir/skip" ]]; then
        reason=$(trim "$(head -n 1 "$dir/skip")")
        echo "SKIP $name: $reason"
        skipped=$((skipped + 1))
        return 0
    fi

    if [[ ! -f "$dir/case.bat" ]]; then
        echo "FAIL $name: case.bat is missing" >&2
        failed=$((failed + 1))
        return 0
    fi
    if [[ ! -f "$dir/expect.txt" ]]; then
        echo "FAIL $name: expect.txt is missing" >&2
        failed=$((failed + 1))
        return 0
    fi

    if [[ -f "$dir/prep" ]]; then
        echo "PREP $name"
        if ! bash "$dir/prep"; then
            echo "FAIL $name: prep failed" >&2
            failed=$((failed + 1))
            return 0
        fi
    fi

    conf_name=dosbox-x-vbe.conf
    if [[ -f "$dir/conf" ]]; then
        conf_name=$(trim "$(head -n 1 "$dir/conf")")
    fi
    conf="$ROOT/qa/$conf_name"
    if [[ ! -f "$conf" ]]; then
        echo "FAIL $name: config qa/$conf_name is missing" >&2
        failed=$((failed + 1))
        return 0
    fi

    out="$ROOT/qa/out/$name"
    stage="$out/stage"
    rm -rf "$out"
    mkdir -p "$stage" "$ROOT/qa/out/captures"
    # DOSBox captures stdout only when the redirect sits on that command,
    # not when it sits on a CALL of the batch file.
    {
        printf '@echo off\r\n'
        local first=1 raw low
        while IFS= read -r raw || [[ -n "$raw" ]]; do
            line=$(trim "$raw")
            [[ -z "$line" ]] && continue
            low=${line,,}
            case "$low" in
                @echo*|rem|rem\ *|::*) continue ;;
            esac
            if [[ "$line" == *">"* ]]; then
                printf '%s\r\n' "$line"
            elif [[ "$first" -eq 1 ]]; then
                printf '%s > case.log\r\n' "$line"
                first=0
            else
                printf '%s >> case.log\r\n' "$line"
            fi
        done <"$dir/case.bat"
    } >"$stage/run.bat"

    if [[ -f "$dir/files.txt" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(trim "${line%%#*}")
            [[ -z "$line" ]] && continue
            case "$line" in
                /*|~*|*..*)
                    echo "FAIL $name: files.txt path must stay inside the repo: $line" >&2
                    failed=$((failed + 1))
                    return 0
                    ;;
            esac
            src="$ROOT/$line"
            if [[ ! -f "$src" ]]; then
                echo "FAIL $name: missing $line" >&2
                failed=$((failed + 1))
                return 0
            fi
            base=$(basename "$line")
            cp "$src" "$stage/$base"
        done <"$dir/files.txt"
    fi

    set +e
    run_dbx "$BIN" \
        -conf "$conf" \
        -nomenu \
        -fastlaunch \
        -silent \
        -time-limit 45 \
        -c "mount c qa/out/$name/stage" \
        -c "c:" \
        -c "run.bat" \
        -c "exit" \
        >"$out/dosbox.log" 2>&1
    dbx_status=$?
    set -e

    found=$(find "$stage" -iname 'case.log' -type f | head -n 1)
    if [[ -z "$found" ]]; then
        echo "FAIL $name: case.log was not written (dosbox-x status ${dbx_status})" >&2
        echo "--- qa/out/$name/dosbox.log ---" >&2
        tail -n 40 "$out/dosbox.log" >&2 || true
        failed=$((failed + 1))
        return 0
    fi
    tr -d '\r' <"$found" >"$out/case.log"
    log="$out/case.log"

    while IFS= read -r marker || [[ -n "$marker" ]]; do
        marker=$(trim "$marker")
        [[ -z "$marker" || "$marker" == \#* ]] && continue
        markers=$((markers + 1))
        if ! grep -q -F -e "$marker" "$log"; then
            echo "FAIL $name: missing marker: $marker" >&2
            miss=1
        fi
    done <"$dir/expect.txt"

    if [[ "$markers" -eq 0 ]]; then
        echo "FAIL $name: expect.txt has no markers" >&2
        failed=$((failed + 1))
        return 0
    fi
    if [[ "$miss" -ne 0 ]]; then
        echo "--- qa/out/$name/case.log ---" >&2
        cat "$log" >&2
        failed=$((failed + 1))
        return 0
    fi

    echo "PASS $name (qa/out/$name/case.log)"
    passed=$((passed + 1))
}

if [[ $# -gt 0 ]]; then
    for name in "$@"; do
        run_one "$ROOT/qa/tests/$name"
    done
else
    found_any=0
    for dir in "$ROOT"/qa/tests/*/; do
        [[ -d "$dir" ]] || continue
        found_any=1
        run_one "$dir"
    done
    if [[ "$found_any" -eq 0 ]]; then
        echo "$LABEL: qa/tests is empty" >&2
        exit 1
    fi
fi

echo "$LABEL: passed $passed, skipped $skipped, failed $failed"
[[ "$failed" -eq 0 ]]

#!/usr/bin/env bash
# Run DOSBox-X cases under qa/tests/<name>/ or another suite root.
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
#   guest.txt   Paths relative to qa/guest/. A missing file skips the case.
#               Present files are copied onto the drive (basename kept).
#   keys.txt    Timed keystrokes. DOSBox-X listens on a local nullmodem
#               socket; qa/input/sendkeys.py sends the file after ready.flg
#               appears on the drive. The guest TSR writes the BIOS keyboard
#               buffer. See qa/input/sendkeys.py.
#
# Usage: qa/run-suite.sh [--label NAME] [--root qa/tests] [test-name ...]
# With no test names, every directory under the suite root is considered.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

LABEL=qa-test
SUITE_REL=qa/tests
while [[ $# -gt 0 ]]; do
    case "$1" in
        --label)
            LABEL=${2:?--label needs a name}
            shift 2
            ;;
        --root)
            SUITE_REL=${2:?--root needs a path}
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "$LABEL: unknown option $1" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

case "$SUITE_REL" in
    /*|~*|*..*)
        echo "run-suite: --root must stay inside the repo: $SUITE_REL" >&2
        exit 1
        ;;
esac
SUITE="$ROOT/$SUITE_REL"
if [[ ! -d "$SUITE" ]]; then
    echo "$LABEL: suite directory $SUITE_REL is missing" >&2
    exit 1
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

# qa/tests keeps the historical qa/out/<name> path. Other suites nest.
out_for() {
    local name=$1
    local base
    base=$(basename "$SUITE_REL")
    if [[ "$base" == "tests" ]]; then
        printf '%s\n' "$ROOT/qa/out/$name"
    else
        printf '%s\n' "$ROOT/qa/out/$base/$name"
    fi
}

passed=0
skipped=0
failed=0

run_one() {
    local dir=$1
    local name conf_name conf stage line src base
    local out found log marker markers=0 miss=0
    local dbx_status reason mount_rel
    local port dbx_pid ready keys_status

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

    if [[ -f "$dir/guest.txt" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(trim "${line%%#*}")
            [[ -z "$line" ]] && continue
            case "$line" in
                /*|~*|*..*)
                    echo "FAIL $name: guest.txt path must stay inside qa/guest: $line" >&2
                    failed=$((failed + 1))
                    return 0
                    ;;
            esac
            if [[ ! -f "$ROOT/qa/guest/$line" ]]; then
                echo "SKIP $name: missing qa/guest/$line"
                skipped=$((skipped + 1))
                return 0
            fi
        done <"$dir/guest.txt"
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

    out=$(out_for "$name")
    stage="$out/stage"
    rm -rf "$out"
    mkdir -p "$stage" "$ROOT/qa/out/captures"
    mount_rel=${out#"$ROOT/"}/stage
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

    if [[ -f "$dir/guest.txt" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(trim "${line%%#*}")
            [[ -z "$line" ]] && continue
            base=$(basename "$line")
            cp "$ROOT/qa/guest/$line" "$stage/$base"
        done <"$dir/guest.txt"
    fi

    set +e
    if [[ -f "$dir/keys.txt" ]]; then
        port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
        echo "KEYS $name via 127.0.0.1:$port"
        run_dbx "$BIN" \
            -conf "$conf" \
            -set "serial serial1=nullmodem port:${port} sock:0 usedtr:0 transparent:1" \
            -nomenu \
            -fastlaunch \
            -silent \
            -time-limit 45 \
            -c "mount c $mount_rel" \
            -c "c:" \
            -c "run.bat" \
            -c "exit" \
            >"$out/dosbox.log" 2>&1 &
        dbx_pid=$!
        ready=""
        local spins
        for spins in $(seq 1 200); do
            ready=$(find "$stage" -iname 'ready.flg' -type f | head -n 1)
            if [[ -n "$ready" ]]; then
                break
            fi
            if ! kill -0 "$dbx_pid" 2>/dev/null; then
                break
            fi
            sleep 0.1
        done
        if [[ -z "$ready" ]]; then
            echo "FAIL $name: ready.flg was not created" >&2
            kill "$dbx_pid" 2>/dev/null || true
            wait "$dbx_pid" 2>/dev/null || true
            echo "--- qa/out/.../$name/dosbox.log ---" >&2
            tail -n 40 "$out/dosbox.log" >&2 || true
            failed=$((failed + 1))
            set -e
            return 0
        fi
        python3 "$ROOT/qa/input/sendkeys.py" --port "$port" --keys "$dir/keys.txt"
        keys_status=$?
        if [[ "$keys_status" -ne 0 ]]; then
            echo "FAIL $name: sendkeys exited $keys_status" >&2
            kill "$dbx_pid" 2>/dev/null || true
            wait "$dbx_pid" 2>/dev/null || true
            failed=$((failed + 1))
            set -e
            return 0
        fi
        wait "$dbx_pid"
        dbx_status=$?
    else
        run_dbx "$BIN" \
            -conf "$conf" \
            -nomenu \
            -fastlaunch \
            -silent \
            -time-limit 45 \
            -c "mount c $mount_rel" \
            -c "c:" \
            -c "run.bat" \
            -c "exit" \
            >"$out/dosbox.log" 2>&1
        dbx_status=$?
    fi
    set -e

    found=$(find "$stage" -iname 'case.log' -type f | head -n 1)
    if [[ -z "$found" ]]; then
        echo "FAIL $name: case.log was not written (dosbox-x status ${dbx_status})" >&2
        echo "--- dosbox.log ---" >&2
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
        echo "--- case.log ---" >&2
        cat "$log" >&2
        failed=$((failed + 1))
        return 0
    fi

    echo "PASS $name ($log)"
    passed=$((passed + 1))
}

if [[ $# -gt 0 ]]; then
    for name in "$@"; do
        run_one "$SUITE/$name"
    done
else
    found_any=0
    for dir in "$SUITE"/*/; do
        [[ -d "$dir" ]] || continue
        found_any=1
        run_one "$dir"
    done
    if [[ "$found_any" -eq 0 ]]; then
        echo "$LABEL: $SUITE_REL is empty" >&2
        exit 1
    fi
fi

echo "$LABEL: passed $passed, skipped $skipped, failed $failed"
[[ "$failed" -eq 0 ]]

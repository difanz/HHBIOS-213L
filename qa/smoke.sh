#!/usr/bin/env bash
# Build VBEPROBE, run it under the pinned DOSBox-X, check the log.
# Guest fonts, a FreeDOS image, and a full HHBIOS boot are out of scope:
# this mounts only the probe COM.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

bash "$ROOT/qa/fetch-dosbox-x.sh"
make vbeprobe

BIN="$ROOT/qa/.cache/dosbox-x/dosbox-x-sdl2"
if [[ ! -x "$BIN" ]]; then
    echo "qa-smoke: DOSBox-X binary missing at qa/.cache/dosbox-x/dosbox-x-sdl2" >&2
    exit 1
fi

missing=$(ldd "$BIN" | awk '/not found/ { print $1 }')
if [[ -n "$missing" ]]; then
    echo "qa-smoke: DOSBox-X is missing host libraries:" >&2
    echo "$missing" >&2
    echo "Debian/Ubuntu packages: libsdl2-net-2.0-0 libpcap0.8 libslirp0 libfluidsynth3 libncurses6" >&2
    exit 1
fi

OUT="$ROOT/qa/out"
STAGE="$OUT/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE" "$OUT/captures"
cp "$ROOT/build/VBEPROBE.COM" "$STAGE/VBEPROBE.COM"

run_dbx() {
    if [[ -n "${DISPLAY:-}" ]]; then
        SDL_AUDIODRIVER=dummy "$@"
    else
        if ! command -v xvfb-run >/dev/null 2>&1; then
            echo "qa-smoke: DISPLAY is unset and xvfb-run is not installed." >&2
            exit 1
        fi
        SDL_AUDIODRIVER=dummy xvfb-run -a "$@"
    fi
}

set +e
run_dbx "$BIN" \
    -conf "$ROOT/qa/dosbox-x-vbe.conf" \
    -nomenu \
    -fastlaunch \
    -silent \
    -time-limit 45 \
    -c "mount c qa/out/stage" \
    -c "c:" \
    -c "vbeprobe.com > vbeprobe.log" \
    -c "exit" \
    >"$OUT/dosbox-x.log" 2>&1
dbx_status=$?
set -e

found=$(find "$STAGE" -iname 'vbeprobe.log' -type f | head -n 1)
if [[ -z "$found" ]]; then
    echo "qa-smoke: VBEPROBE did not write a log (dosbox-x status ${dbx_status})." >&2
    echo "--- qa/out/dosbox-x.log ---" >&2
    tail -n 80 "$OUT/dosbox-x.log" >&2 || true
    exit 1
fi

tr -d '\r' <"$found" >"$OUT/vbeprobe.log"

fail=0
grep -q '^signature=VESA$' "$OUT/vbeprobe.log" || fail=1
grep -q '^VBEPROBE_OK$' "$OUT/vbeprobe.log" || fail=1
grep -q 'lfb=yes' "$OUT/vbeprobe.log" || fail=1
if [[ "$fail" -ne 0 ]]; then
    echo "qa-smoke: log is missing signature=VESA, lfb=yes, or VBEPROBE_OK." >&2
    cat "$OUT/vbeprobe.log" >&2
    exit 1
fi

echo "qa-smoke: ok ($OUT/vbeprobe.log)"

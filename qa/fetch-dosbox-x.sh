#!/usr/bin/env bash
# Download the pinned DOSBox-X Linux x86_64 build into qa/.cache/.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. "$ROOT/qa/DOSBOX_X_VERSION"

CACHE="$ROOT/qa/.cache/dosbox-x"
BIN="$CACHE/dosbox-x-sdl2"
STAMP="$CACHE/PINNED"
URL="https://api.github.com/repos/joncampbell123/dosbox-x/actions/artifacts/${DOSBOX_X_ARTIFACT_ID}/zip"

die() {
    echo "fetch-dosbox-x: $*" >&2
    exit 1
}

if [[ -x "$BIN" && -f "$STAMP" ]] && [[ "$(cat "$STAMP")" == "$DOSBOX_X_ARTIFACT_ID $DOSBOX_X_SHA256" ]]; then
    exit 0
fi

mkdir -p "$CACHE"
ZIP="$CACHE/dosbox-x.zip.partial"
rm -f "$ZIP"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if ! gh api --header "Accept: application/vnd.github+json" \
        "repos/joncampbell123/dosbox-x/actions/artifacts/${DOSBOX_X_ARTIFACT_ID}/zip" >"$ZIP"; then
        rm -f "$ZIP"
        die "gh download failed for artifact ${DOSBOX_X_ARTIFACT_ID} (run ${DOSBOX_X_RUN_ID})"
    fi
else
    token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    if [[ -z "$token" ]]; then
        die "need GitHub credentials to download ${DOSBOX_X_TAG} Linux build ${DOSBOX_X_ARTIFACT} (artifact ${DOSBOX_X_ARTIFACT_ID}). Release assets for that tag do not include a Linux binary. Run 'gh auth login', or export GITHUB_TOKEN, then retry."
    fi
    if ! curl -fL --retry 3 \
        -H "Authorization: Bearer ${token}" \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: hhbios-qa" \
        -o "$ZIP" "$URL"; then
        rm -f "$ZIP"
        die "download failed: ${URL}"
    fi
fi

python3 - "$ZIP" "$CACHE" "$DOSBOX_X_SHA256" <<'PY'
import hashlib, sys, zipfile
zip_path, cache, expect = sys.argv[1:4]
data = open(zip_path, "rb").read()
if not data.startswith(b"PK"):
    sys.stderr.write("fetch-dosbox-x: download is not a zip\n")
    sys.exit(1)
got = hashlib.sha256(data).hexdigest()
if got != expect:
    sys.stderr.write("fetch-dosbox-x: sha256 mismatch\n  expected %s\n  got      %s\n" % (expect, got))
    sys.exit(1)
with zipfile.ZipFile(zip_path) as zf:
    if "dosbox-x-sdl2" not in zf.namelist():
        sys.stderr.write("fetch-dosbox-x: zip has no dosbox-x-sdl2\n")
        sys.exit(1)
    zf.extractall(cache)
PY

if [[ ! -f "$BIN" ]]; then
    rm -f "$ZIP"
    die "extracted archive has no dosbox-x-sdl2"
fi
chmod +x "$CACHE/dosbox-x-sdl2" "$CACHE/dosbox-x-sdl1" 2>/dev/null || chmod +x "$BIN"
rm -f "$ZIP"
echo "$DOSBOX_X_ARTIFACT_ID $DOSBOX_X_SHA256" >"$STAMP"
echo "fetch-dosbox-x: $BIN"

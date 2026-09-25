#!/usr/bin/env bash
# Quick path: the vbeprobe case only. The full tree is `make qa-test`.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec bash "$ROOT/qa/run-suite.sh" --label qa-smoke vbeprobe

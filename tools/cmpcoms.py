#!/usr/bin/env python3
"""Confirm every src/*.ASM produced a non-empty build/*.COM."""
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[1]
src = root / "src"
build = root / "build"
missing = []
empty = []
built = []
for asm in sorted(src.glob("*.ASM")):
    com = build / f"{asm.stem}.COM"
    if not com.is_file():
        missing.append(asm.stem)
        continue
    size = com.stat().st_size
    if size == 0:
        empty.append(asm.stem)
        continue
    built.append((asm.stem, size))

print(f"assembled {len(built)}  missing {len(missing)}  empty {len(empty)}")
for name, size in built:
    print(f"{name:<10} {size:7}")
if missing or empty:
    for name in missing:
        print(f"missing {name}")
    for name in empty:
        print(f"empty {name}")
    sys.exit(1)
sys.exit(0)

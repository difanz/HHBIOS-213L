#!/usr/bin/env python3
"""Join READ3..READ6 onto the R16 stub, the way R16 /S does.

The stub's D_0 (five words at file offset 0x52) is filled with the
load address of each module and the address just past the last one.
"""
import sys
from pathlib import Path

D0_OFF = 0x52


def main() -> None:
    stub_path, r3, r4, r5, r6, out_path = sys.argv[1:]
    stub = bytearray(Path(stub_path).read_bytes())
    if stub[D0_OFF:D0_OFF + 10] != b"\x00" * 10:
        raise SystemExit(f"D_0 at {D0_OFF:#x} is not five zero words")
    mods = [Path(p).read_bytes() for p in (r3, r4, r5, r6)]
    addr = 0x100 + len(stub)
    ptrs = []
    for mod in mods:
        ptrs.append(addr)
        addr += len(mod)
    ptrs.append(addr)
    for i, ptr in enumerate(ptrs):
        stub[D0_OFF + 2 * i:D0_OFF + 2 * i + 2] = ptr.to_bytes(2, "little")
    Path(out_path).write_bytes(bytes(stub) + b"".join(mods))


if __name__ == "__main__":
    main()

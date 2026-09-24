# Building HHBIOS-213L

## Toolchain

- **JWasm** (MASM-compatible): https://github.com/Baron-von-Riedesel/JWasm
- Classic MASM 5.x / TASM should also work; this repo targets JWasm on modern hosts.

## Encoding

ASM sources are **GB2312/GBK**. Do not open-save them as UTF-8. The `Makefile` and this file are UTF-8 and do not touch source encoding.

## Quick start

```bash
# install jwasm, then:
make pilot   # CMODE / KEY / CM — often byte-identical to shipped .COM
make all     # all *.ASM → build/*.COM
```

Recipe used per module:

```text
jwasm -Zm -bin -Fo=build/FOO.COM FOO.ASM
```

`-Zm` = MASM 5.x compatibility; `-bin` = raw binary for `ORG 100H` COM programs.

## Status (local smoke test)

- Most modules assemble; several match the original `.COM` byte-for-byte.
- Still failing or special-cased: `INT10K`, `INT10V` (macros), `PHGA` (operand size), `WBX` (missing INC), `BG` (structure after `END`).
- Large `.EXE` files such as `213L.EXE` are **not** link products of the matching `.ASM` (e.g. `213L.EXE` is an ARJ self-extractor). Treat shipped binaries as reference, not as `make` link targets.

## Original model

Each `ORG 100H` unit was assembled independently to a `.COM` (MASM → LINK → EXE2BIN, or TASM/TLINK `/t`). `INCLUDE` is text insert, not multi-module linking.

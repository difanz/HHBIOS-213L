# Shared resident code

`frame.c` classifies CP437 corners, adjacent bars and directory-tree branches.
`text_edit.c` compares character bytes and verifies a one- or two-byte deletion;
attributes and fixed right borders do not change the editing decision.

The register interfaces in `text.h` match `frame.inc` and `input/edit_check.inc`.
The wrappers establish DS=CS, accept an unrelated SS, restore DF/IF and preserve
the caller's registers, including their upper halves in 386 builds. The C code
uses no runtime library, DOS services, heap or mutable global scratch space.

Legacy COMs link as one DGROUP: assembly, shared C, constants, then the legacy
buffer/installation tail. `OPTION OFFSET:GROUP` is required for pointer immediates
as well as memory operands. C and constants must precede the overwriteable tail
so loading tables or relocating to a UMB cannot discard live code.

CPU selection and common compiler flags live in `tools/cpu-target.sh`. All
variants execute the same behavior tests. Tests also check the actual 16-bit
wrappers with a foreign stack, dirty DF, upper-register sentinels, and bounded
instruction counts. DOS tests separately cover installation, rendering and
unloading; instruction counts are not CPU cycle measurements.

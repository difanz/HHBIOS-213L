; A single real-mode group, with C before the legacy discardable tail.
; All OFFSET relocations use the group base, including fixed PSP fields.
include cpu.inc
option offset:group
SEG_A segment para public 'CODE'
SEG_A ends
SEG_TAIL segment word public 'TAIL'
SEG_TAIL ends
COMMON_TEXT segment word public 'COMMON'
COMMON_TEXT ends
CONST segment word public 'DATA'
CONST ends
CONST2 segment word public 'DATA'
CONST2 ends
_DATA segment word public 'DATA'
_DATA ends
_BSS segment word public 'BSS'
_BSS ends
DGROUP group SEG_A, COMMON_TEXT, CONST, CONST2, _DATA, _BSS, SEG_TAIL

; Exercise the resident wrapper with the same input/query layout as CKBD.
include segments.inc
SEG_A segment para public 'CODE'
assume cs:DGROUP, ds:DGROUP
org 100h
start label near
dw S_A010, D_2BB0, D_2BB1, D_2CC1, D_2CC0, D_2B, display_count, display_keys
D_2BB0 db 0
D_2BB1 db 10 dup (0)
D_2CC1 db 10 dup (0)
D_2CC0 db 0
D_2B db 0
display_count dw 0
display_keys dw 0
include pinyin.inc
S_A080:
    inc display_count
    mov display_keys,bx
    ret
SEG_A ends
end start

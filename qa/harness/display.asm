; The routines under test are included verbatim, not translated to Python.
; Only the hardware renderers and the interrupt-return tail are test doubles.
.model tiny
.code
org 100h
exports dw S_XR, S_XSZF, S_XSHZ, D_XPQ, D_ZBFS, K_HZ1
        dw L_AH0E, L_RET, D_0050, D_005A
        dw S_QSX
        dw S_HZPOS
D_B800 dw 2000h
D_005A db 1
D_0050 db 0
include AH0E.INC
include ZJXP.INC
include HZPOS.INC
S_XSZF:
    xor ax, ax
    mov ds, ax
    ret
S_XSHZ:
    xor ax, ax
    mov ds, ax
    ret
S_GB:
    ret
L_INT10:
L_RET:
    ret
D_XPQ db 4000 dup (0)
end

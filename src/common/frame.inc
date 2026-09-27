include TEXTGEOM.INC
include abi.inc
extrn syscall TextIsFrame:near

; ES:BX = cell, DX = row/column. Preserve registers and return ZF=1 for
; frame geometry. The upper halves are preserved in 386/Pentium builds.
S_CORNER proc near
    save_c_regs
    xor cx,cx
    mov cl,XR_LASTROW
    call TextIsFrame
    cmp ax,1
    restore_c_regs
    ret
S_CORNER endp

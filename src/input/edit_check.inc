include abi.inc
extrn syscall TextRowSame:near, TextRowShifted:near

S_ESAME proc near
    save_c_regs
    mov si,offset D_EROW
    mov bx,D_EOFF
    call TextRowSame
    cmp ax,1
    cmc                         ; CF=1 iff the row is unchanged
    restore_c_regs
    ret
S_ESAME endp

S_ESHIFT proc near
    save_c_regs
    mov si,offset D_EROW
    mov bx,D_EOFF
    mov dx,D_EDEL
    call TextRowShifted
    cmp ax,1
    cmc                         ; CF=1 iff exactly CX bytes were deleted
    restore_c_regs
    ret
S_ESHIFT endp

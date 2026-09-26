.model tiny
.code
org 100h
exports dw S_EDIT, D_EDIT, D_ESTATE
D_INT16 label dword
    dw old_bios,1000h
include KEYEDIT.INC
S_INT16_1:
    mov ah,11h
    pushf
    call cs:D_INT16
    ret
old_bios:
    int 60h
    retf 2
end

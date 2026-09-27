; The 16-bit C ABI returns word registers. Keep the interrupted program's
; upper halves, including callers using 32-bit registers in real/v86 mode.
; PUSHAD sits outside the existing 20-byte BIOS register packet.
.386
restore_dword_regs macro
    push bp
    mov bp,sp
    mov [bp+30],ax
    mov [bp+26],cx
    mov [bp+22],dx
    mov [bp+18],bx
    mov [bp+6],si
    mov [bp+2],di
    mov ax,[bp]
    mov [bp+10],ax
    pop bp
    popad
endm

; Mouse entry/callbacks run on the caller's stack. C receives an explicit far
; pointer to saved registers; no global request packet or renderer stack is used.
.model tiny,c
.code
include vesa_cpu.inc
public old33, int33_handler, mouse_callback, mouse_bios, mouse_thunk_offset
extrn mouse_dispatch:near, mouse_event:near, mouse_target:dword
old33 dd 0
mouse_thunk_offset dw offset mouse_callback
save_mouse macro
    pushf
    push es
    push ds
    push bp
    push di
    push si
    push dx
    push cx
    push bx
    push ax
endm
load_mouse macro
    pop ax
    pop bx
    pop cx
    pop dx
    pop si
    pop di
    pop bp
    pop ds
    pop es
    popf
endm
int33_handler proc far
    pushad
    save_mouse
    mov ax,sp
    push cs
    pop ds
    cld
    push ss
    push ax
    call mouse_dispatch
    add sp,4
    load_mouse
    restore_dword_regs
    iret
int33_handler endp
mouse_callback proc far
    pushad
    save_mouse
    mov ax,sp
    push cs
    pop ds
    cld
    push ss
    push ax
    call mouse_event
    add sp,4
    or ax,ax
    jz mouse_no_callback
    load_mouse
    restore_dword_regs
    jmp cs:mouse_target
mouse_no_callback:
    load_mouse
    restore_dword_regs
    retf
mouse_callback endp

mouse_bios proc near
    push bp
    mov bp,sp
    save_mouse
    les si,[bp+4]
    push es
    push si
    push word ptr es:[si+16]
    push word ptr es:[si+14]
    push word ptr es:[si+12]
    push word ptr es:[si+10]
    push word ptr es:[si+8]
    mov ax,es:[si]
    mov bx,es:[si+2]
    mov cx,es:[si+4]
    mov dx,es:[si+6]
    pop si
    pop di
    pop bp
    pop ds
    pop es
    pushf
    call cs:old33
    save_mouse
    mov bp,sp
    les di,ss:[bp+20]
    push ss
    pop ds
    mov si,sp
    mov cx,9
    cld
    rep movsw
    add sp,24
    load_mouse
    pop bp
    ret
mouse_bios endp
end

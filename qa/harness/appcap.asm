; Timer observer for application tests. No DOS calls from the interrupt.
.code
extrn app_poll_:near
old_vec dw 0,0
tick:
    pushf
    push ds
    push es
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    cld
    mov ax,cs
    mov ds,ax
    call app_poll_
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop ds
    popf
    jmp dword ptr cs:[old_vec]
public install_app_tick_
install_app_tick_:
    mov ax,351ch
    int 21h
    mov word ptr cs:[old_vec],bx
    mov word ptr cs:[old_vec+2],es
    mov dx,offset tick
    mov ax,251ch
    int 21h
    ret
end

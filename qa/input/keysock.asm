; INT 1Ch stub for KEYSOCK. COM images drop segment relocations, so the
; handler segment is CS and the previous vector lives in this segment.
; CPU and model come from wcl (-0 -mt), not from directives here.

.code

extrn do_poll_:near

public old_vec
old_vec dw 0, 0

public tick_stub_
tick_stub_:
    push ds
    push es
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov ax, cs
    mov ds, ax
    call do_poll_
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop ds
    jmp dword ptr cs:[old_vec]

public install_tick_
install_tick_:
    mov ax, 351ch
    int 21h
    mov word ptr cs:[old_vec], bx
    mov word ptr cs:[old_vec+2], es
    mov dx, offset tick_stub_
    mov ax, 251ch
    int 21h
    ret

end

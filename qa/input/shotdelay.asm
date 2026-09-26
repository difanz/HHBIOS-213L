; Resident INT 1Ch. After about nine seconds, and only when DOS is
; idle, create SHOT.FLG in the current directory. An interactive
; program started on the next batch line (cached tvdemo) is then on
; screen before Host+P.
; JWasm: jwasm -q -Zm -bin -Fo build/SHOTDLY.COM qa/input/shotdelay.asm

.model tiny
.code
org 100h

start:
    mov ah, 34h
    int 21h
    mov word ptr cs:[indos_off], bx
    mov word ptr cs:[indos_seg], es

    mov ax, 351ch
    int 21h
    mov word ptr cs:[old_vec], bx
    mov word ptr cs:[old_vec+2], es
    mov dx, offset tick
    mov ax, 251ch
    int 21h

    mov dx, offset msg
    mov ah, 09h
    int 21h

    mov dx, offset resident_end
    int 27h

tick:
    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    cmp byte ptr cs:[armed], 0
    jne chain
    inc word ptr cs:[ticks]
    cmp word ptr cs:[ticks], 160
    jb chain
    les bx, dword ptr cs:[indos_off]
    cmp byte ptr es:[bx], 0
    jne chain
    cmp byte ptr es:[bx-1], 0
    jne chain
    mov byte ptr cs:[armed], 1
    mov cs:[save_ss], ss
    mov cs:[save_sp], sp
    mov ax, cs
    cli
    mov ss, ax
    mov sp, offset stack_top
    sti
    mov ax, cs
    mov ds, ax
    mov dx, offset fname
    xor cx, cx
    mov ah, 3ch
    int 21h
    jc made
    mov bx, ax
    mov ah, 3eh
    int 21h
made:
    cli
    mov ss, cs:[save_ss]
    mov sp, cs:[save_sp]
chain:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    jmp dword ptr cs:[old_vec]

ticks dw 0
armed db 0
indos_off dw 0
indos_seg dw 0
old_vec dw 0, 0
save_ss dw 0
save_sp dw 0
fname db 'SHOT.FLG', 0
msg db 'SHOTDELAY_OK', 13, 10, '$'
    dw 48 dup (0)
stack_top:
resident_end:

end start

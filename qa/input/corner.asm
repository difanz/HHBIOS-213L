; Direct-write CP437 corners. B800 bytes stay as written.
; JWasm: jwasm -q -Zm -bin -Fo build/CORNER.COM qa/input/corner.asm

.model tiny
.code
org 100h

; One bar beside each corner. A run of four would already be lowered.
start:
    cli
    mov     dh, 1
    mov     dl, 0
    mov     al, 0C9h
    call    putc
    mov     dl, 1
    mov     al, 0CDh
    call    putc
    mov     dl, 3
    call    putc
    mov     dl, 4
    mov     al, 0BBh
    call    putc
    mov     dh, 2
    mov     dl, 0
    mov     al, 0BAh
    call    putc
    mov     dl, 4
    call    putc
    mov     dh, 3
    mov     dl, 0
    mov     al, 0C8h
    call    putc
    mov     dl, 1
    mov     al, 0CDh
    call    putc
    mov     dl, 3
    call    putc
    mov     dl, 4
    mov     al, 0BCh
    call    putc

    mov     dh, 5
    mov     dl, 0
    mov     al, 0DAh
    call    putc
    mov     dl, 1
    mov     al, 0C4h
    call    putc
    mov     dl, 3
    call    putc
    mov     dl, 4
    mov     al, 0BFh
    call    putc
    mov     dh, 6
    mov     dl, 0
    mov     al, 0B3h
    call    putc
    mov     dl, 4
    call    putc
    mov     dh, 7
    mov     dl, 0
    mov     al, 0C0h
    call    putc
    mov     dl, 1
    mov     al, 0C4h
    call    putc
    mov     dl, 3
    call    putc
    mov     dl, 4
    mov     al, 0D9h
    call    putc

    mov     dh, 9
    mov     dl, 0
    mov     al, 0BAh
    call    putc
    mov     dh, 10
    mov     al, 0C0h
    call    putc
    mov     dl, 1
    mov     al, 0C4h
    call    putc
    sti

    call    wait18
    mov     dx, offset m_ok
    call    log
    call    flag
    mov     ah, 00h
    int     16h
    mov     dx, offset m_done
    call    log
    mov     ax, 4C00h
    int     21h

putc:
    push    es
    push    ax
    push    bx
    push    cx
    push    dx
    mov     cx, ax
    mov     ax, 0B800h
    mov     es, ax
    mov     al, dh
    mov     bl, 80
    mul     bl
    xor     bh, bh
    mov     bl, dl
    add     ax, bx
    shl     ax, 1
    mov     bx, ax
    mov     al, cl
    mov     byte ptr es:[bx], al
    mov     byte ptr es:[bx+1], 1Fh
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    pop     es
    ret

wait18:
    push    ax
    push    bx
    push    cx
    push    es
    mov     ax, 40h
    mov     es, ax
    mov     cx, 18
w1:
    mov     bx, es:[6Ch]
w2:
    cmp     bx, es:[6Ch]
    je      w2
    loop    w1
    pop     es
    pop     cx
    pop     bx
    pop     ax
    ret

log:
    push    ax
    push    bx
    push    cx
    push    dx
    mov     ah, 3Dh
    mov     al, 2
    mov     dx, offset fname
    int     21h
    jnc     log_ok
    mov     ah, 3Ch
    xor     cx, cx
    mov     dx, offset fname
    int     21h
    jc      log_out
log_ok:
    mov     bx, ax
    mov     ax, 4202h
    xor     cx, cx
    xor     dx, dx
    int     21h
    pop     dx
    push    dx
    mov     si, dx
    mov     cx, 0
len:
    cmp     byte ptr [si], '$'
    je      wr
    inc     cx
    inc     si
    jmp     short len
wr:
    mov     ah, 40h
    pop     dx
    push    dx
    int     21h
    mov     ah, 3Eh
    int     21h
log_out:
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

flag:
    mov     ah, 3Ch
    xor     cx, cx
    mov     dx, offset sname
    int     21h
    jc      flag_out
    mov     bx, ax
    mov     ah, 40h
    mov     cx, 2
    mov     dx, offset sbody
    int     21h
    mov     ah, 3Eh
    int     21h
flag_out:
    ret

fname   db 'CASE.LOG',0
sname   db 'SHOT.FLG',0
sbody   db '1',10
m_ok    db 'CORNER_OK',13,10,'$'
m_done  db 'SHOT_DONE',13,10,'$'

end start

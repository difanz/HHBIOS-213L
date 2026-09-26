; Direct-write half-delete and teletype backspace under READ2+VGA+CMODE 3.
; JWasm: jwasm -q -Zm -bin -Fo build/HDEL.COM qa/input/hdel.asm

.model tiny
.code
org 100h

start:
    call    test_lead
    call    test_trail
    call    test_corner
    call    test_ascii
    call    test_tty
    mov     ax, 4C00h
    int     21h

; Change the lead of E0 AB. The trail must become a space.
test_lead:
    mov     dh, 2
    mov     dl, 4
    mov     al, 0E0h
    mov     ah, 0ABh
    call    put_pair
    call    wait18
    mov     dh, 2
    mov     dl, 4
    mov     al, 20h
    call    put_char
    call    wait18
    mov     dh, 2
    mov     dl, 5
    call    get_char
    cmp     al, 20h
    jnz     lead_bad
    mov     dx, offset m_hdel
    jmp     short say
lead_bad:
    mov     dx, offset m_hfail
say:
    mov     ah, 09h
    int     21h
    ret

; Change the trail. The lead must become a space.
test_trail:
    mov     dh, 3
    mov     dl, 4
    mov     al, 0E1h
    mov     ah, 0E1h
    call    put_pair
    call    wait18
    mov     dh, 3
    mov     dl, 5
    mov     al, 20h
    call    put_char
    call    wait18
    mov     dh, 3
    mov     dl, 4
    call    get_char
    cmp     al, 20h
    jnz     trail_bad
    mov     dx, offset m_trail
    jmp     short say2
trail_bad:
    mov     dx, offset m_tfail
say2:
    mov     ah, 09h
    int     21h
    ret

; Corner plus bar, with a line on the other axis, is left alone.
test_corner:
    cli
    mov     dh, 5
    mov     dl, 4
    mov     al, 0C9h
    call    put_char
    mov     dl, 5
    mov     al, 0CDh
    call    put_char
    mov     dh, 6
    mov     dl, 4
    mov     al, 0BAh
    call    put_char
    sti
    call    wait18
    mov     dh, 5
    mov     dl, 4
    mov     al, 20h
    call    put_char
    call    wait18
    mov     dh, 5
    mov     dl, 5
    call    get_char
    cmp     al, 20h
    jz      cor_bad
    mov     dx, offset m_cor
    jmp     short say3
cor_bad:
    mov     dx, offset m_cfail
say3:
    mov     ah, 09h
    int     21h
    ret

test_ascii:
    cli
    mov     dh, 8
    mov     dl, 4
    mov     al, 'A'
    call    put_char
    mov     dl, 5
    mov     al, 'B'
    call    put_char
    sti
    call    wait18
    mov     dh, 8
    mov     dl, 4
    mov     al, 20h
    call    put_char
    call    wait18
    mov     dh, 8
    mov     dl, 5
    call    get_char
    cmp     al, 'B'
    jnz     asc_bad
    mov     dx, offset m_asc
    jmp     short say4
asc_bad:
    mov     dx, offset m_afail
say4:
    mov     ah, 09h
    int     21h
    ret

; Teletype of a non-corner pair, then one backspace, clears both cells.
test_tty:
    mov     ah, 02h
    mov     bh, 0
    mov     dh, 10
    mov     dl, 10
    int     10h
    mov     bl, 07h
    mov     ah, 0Eh
    mov     al, 0E0h
    int     10h
    mov     ah, 0Eh
    mov     al, 0ABh
    int     10h
    mov     ah, 0Eh
    mov     al, 8
    int     10h
    mov     dh, 10
    mov     dl, 10
    call    get_char
    cmp     al, 20h
    jnz     tty_bad
    mov     dl, 11
    call    get_char
    cmp     al, 20h
    jnz     tty_bad
    mov     ax, 40h
    mov     es, ax
    cmp     byte ptr es:[50h], 10
    jnz     tty_bad
    mov     dx, offset m_tty
    jmp     short say5
tty_bad:
    mov     dx, offset m_tyfail
say5:
    mov     ah, 09h
    int     21h
    ret

; DH=row DL=col AL=lead AH=trail. Attribute 1Eh.
put_pair:
    push    ax
    call    put_char
    pop     ax
    inc     dl
    mov     al, ah
    call    put_char
    ret

put_char:
    push    bx
    push    cx
    push    dx
    push    es
    mov     cl, al
    call    cell
    mov     byte ptr es:[bx], cl
    mov     byte ptr es:[bx+1], 1Eh
    pop     es
    pop     dx
    pop     cx
    pop     bx
    ret

get_char:
    push    bx
    push    es
    call    cell
    mov     al, es:[bx]
    pop     es
    pop     bx
    ret

; DH row, DL col -> ES:BX cell in B800.
cell:
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
    ret

wait18:
    push    ax
    push    bx
    push    cx
    push    es
    mov     ax, 40h
    mov     es, ax
    mov     cx, 18
w18a:
    mov     bx, es:[6Ch]
w18b:
    cmp     bx, es:[6Ch]
    je      w18b
    loop    w18a
    pop     es
    pop     cx
    pop     bx
    pop     ax
    ret

m_hdel   db 'HDEL_OK',13,10,'$'
m_hfail  db 'HDEL_FAIL',13,10,'$'
m_trail  db 'TRAIL_OK',13,10,'$'
m_tfail  db 'TRAIL_FAIL',13,10,'$'
m_cor    db 'CORNER_KEEP',13,10,'$'
m_cfail  db 'CORNER_WIPED',13,10,'$'
m_asc    db 'ASCII_KEEP',13,10,'$'
m_afail  db 'ASCII_WIPED',13,10,'$'
m_tty    db 'TTY_OK',13,10,'$'
m_tyfail db 'TTY_FAIL',13,10,'$'

end start

; Register-packet bridge for the font store. All calls preserve the C ABI.
.model tiny,c
.code
extrn font_entry:dword
public font_service
font_service proc near
    push bp
    mov bp,sp
    pushf
    push es
    push ds
    push di
    push si
    push dx
    push cx
    push bx
    mov si,[bp+6]
    push word ptr [si+16]
    push word ptr [si+14]
    push word ptr [si+8]
    mov ax,[si]
    mov bx,[si+2]
    mov cx,[si+4]
    mov dx,[si+6]
    mov di,[si+10]
    pop si
    pop ds
    pop es
    cmp word ptr ss:[bp+4],0
    je service_dos
    cmp word ptr ss:[bp+4],1
    je service_multiplex
    cmp word ptr ss:[bp+4],2
    je service_ems
    push bp
    call cs:font_entry
    pop bp
    jmp short service_result
service_dos:
    int 21h
    jmp short service_result
service_multiplex:
    int 2fh
    jmp short service_result
service_ems:
    int 67h
service_result:
    pushf
    push es
    push ds
    push di
    push si
    push dx
    push cx
    push bx
    push ax
    push cs
    pop ds
    push cs
    pop es
    mov si,sp
    mov di,ss:[bp+6]
    mov cx,6
    rep movsw
    add di,2                 ; packet BP is unused
    mov cx,3
    rep movsw
    add sp,18
    pop bx
    pop cx
    pop dx
    pop si
    pop di
    pop ds
    pop es
    popf
    pop bp
    ret
font_service endp
end

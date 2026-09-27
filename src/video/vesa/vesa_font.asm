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

; Packed 16..48-pixel rows become two left-aligned 32-bit cell rows.
; Every source access stays within its 2..6-byte row. USE16, 386 only.
.386
public font_unpack
font_unpack proc near
    push bp
    mov bp,sp
    sub sp,6
    pushad
    push es
    push ds
    pop es
    mov di,[bp+6]
    xor eax,eax
    mov cx,128
    rep stosd
    mov di,[bp+6]
    mov si,[bp+4]
    mov ax,[bp+10]
    mov [bp-6],ax
    mov cx,32
    sub cx,[bp+8]
    mov eax,-1
    shl eax,cl
    mov [bp-4],eax
unpack_row:
    xor eax,eax
    xor ebx,ebx
    mov cx,[bp+12]
    cmp cx,4
    jae unpack_four
    mov ax,[si]
    xchg al,ah
    shl eax,16
    cmp cx,2
    je unpack_halves
    mov ah,[si+2]
    jmp short unpack_halves
unpack_four:
    mov eax,[si]
    xchg al,ah
    ror eax,16
    xchg al,ah
    cmp cx,4
    je unpack_halves
    mov bh,[si+4]
    cmp cx,5
    je unpack_low
    mov bl,[si+5]
unpack_low:
    shl ebx,16
unpack_halves:
    add si,cx
    mov edx,eax
    and edx,[bp-4]
    mov [di],edx
    mov cx,[bp+8]
    shld eax,ebx,cl
    and eax,[bp-4]
    mov [di+256],eax
    add di,4
    dec word ptr [bp-6]
    jnz unpack_row
    pop es
    popad
    mov sp,bp
    pop bp
    ret
font_unpack endp
end

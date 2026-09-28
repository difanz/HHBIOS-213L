; Capture only the BIOS-facing printer bytes; PRNT itself remains unmodified.
.code
extrn _PrintBytes:byte, _PrintCount:word, _PrintOverflow:word
public install_print_capture_
capture:
    push ds
    push bx
    push ax
    mov bx,cs
    mov ds,bx
    or ah,ah
    jnz ready
    mov bx,_PrintCount
    cmp bx,8192
    jae overflow
    mov _PrintBytes[bx],al
    inc _PrintCount
    jmp short ready
overflow:
    mov _PrintOverflow,1
ready:
    pop ax
    pop bx
    pop ds
    mov ah,90h
    iret
install_print_capture_:
    mov dx,offset capture
    mov ax,2517h
    int 21h
    ret
end

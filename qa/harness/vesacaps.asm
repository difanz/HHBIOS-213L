; Limit only the BIOS-reported spare image capacity. Real VGA memory/ports
; and all mode/bank operations remain those of the emulator being tested.
.model tiny
.code
org 100h
start: jmp install
old10 dd 0
handler:
    cmp ax,4f01h
    jne chain
    pushf
    call cs:old10
    cmp ax,004fh
    jne done
    mov byte ptr es:[di+29],0
done:
    iret
chain:
    jmp cs:old10
install:
    mov ax,3510h
    int 21h
    mov word ptr old10,bx
    mov word ptr old10+2,es
    mov ax,2510h
    mov dx,offset handler
    int 21h
    mov dx,offset install+15
    mov cl,4
    shr dx,cl
    mov ax,3100h
    int 21h
end start

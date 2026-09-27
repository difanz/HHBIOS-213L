; Test-only EDID provider. All display modes and rendering stay in the BIOS.
.8086
.model tiny
.code
org 100h
start:
    jmp install
old10 dd 0
edid db 128 dup (0)
handler proc far
    cmp ax,4f15h
    jne chain
    cmp bx,1
    jne failed
    or cx,cx
    jnz failed
    or dx,dx
    jnz failed
    push ds
    push si
    push di
    push cx
    pushf
    push cs
    pop ds
    mov si,offset edid
    mov cx,64
    cld
    rep movsw
    popf
    pop cx
    pop di
    pop si
    pop ds
    mov ax,004fh
    iret
failed:
    mov ax,014fh
    iret
chain:
    jmp cs:old10
handler endp
resident_end label byte
filename db 'EDID.BIN',0
install:
    mov dx,offset filename
    mov ax,3d00h
    int 21h
    jc error
    mov bx,ax
    mov dx,offset edid
    mov cx,128
    mov ah,3fh
    int 21h
    jc error
    cmp ax,128
    jne error
    mov ah,3eh
    int 21h
    mov ax,3510h
    int 21h
    mov word ptr old10,bx
    mov word ptr old10+2,es
    mov dx,offset handler
    mov ax,2510h
    int 21h
    mov dx,offset resident_end + 15
    mov cl,4
    shr dx,cl
    mov ax,3100h
    int 21h
error:
    mov ax,4c01h
    int 21h
end start

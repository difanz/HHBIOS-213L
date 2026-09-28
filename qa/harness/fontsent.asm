; An unrelated pre-existing font vector must survive partial printer unload.
.model tiny
.code
org 100h
start:
    mov dx,offset sentinel
    mov ax,257eh
    int 21h
    mov dx,offset resident_end+15
    mov cl,4
    shr dx,cl
    mov ax,3100h
    int 21h
sentinel:
    iret
resident_end:
end start

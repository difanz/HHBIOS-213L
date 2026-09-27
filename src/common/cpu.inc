; Check before installing vectors or entering CPU-specific C. This uses only
; 8086 instructions; the same FLAGS test is used by the VESA installer.
IFNDEF HH_CPU
HH_CPU EQU 0
ENDIF
require_386 MACRO
    LOCAL old_cpu, supported, message
    IF HH_CPU GE 3
        .8086
        pushf
        pop dx
        mov ax,dx
        and ax,0fffh
        push ax
        popf
        pushf
        pop ax
        and ax,0f000h
        cmp ax,0f000h
        je old_cpu
        mov ax,dx
        or ax,7000h
        push ax
        popf
        pushf
        pop ax
        test ax,7000h
        jnz supported
old_cpu:
        push dx
        popf
        push cs
        pop ds
        mov dx,offset message
        mov ah,9
        int 21h
        mov ax,4c01h
        int 21h
message db 'This build requires a 386 or newer CPU.',13,10,'$'
supported:
        push dx
        popf
        .386
    ENDIF
ENDM

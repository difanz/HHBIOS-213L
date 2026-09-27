; C runs with DS=CS but may be called on an application's SS. Keep the
; interrupted program's complete register state around the C boundary.
IFNDEF HH_C_ABI
HH_C_ABI EQU 1
IFNDEF HH_CPU
HH_CPU EQU 0
ENDIF
save_c_regs MACRO
    pushf
    IF HH_CPU GE 3
        .386
        pushad
    ELSE
        push ax
        push bx
        push cx
        push dx
        push si
        push di
        push bp
    ENDIF
    push ds
    push es
    push cs
    pop ds
    cld
ENDM
restore_c_regs MACRO
    ; Return low arithmetic flags; retain the caller's DF, IF and TF.
    lahf
    mov bp,sp
    IF HH_CPU GE 3
        mov ss:[bp+36],ah
    ELSE
        mov ss:[bp+18],ah
    ENDIF
    pop es
    pop ds
    IF HH_CPU GE 3
        popad
    ELSE
        pop bp
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
    ENDIF
    popf
ENDM
ENDIF

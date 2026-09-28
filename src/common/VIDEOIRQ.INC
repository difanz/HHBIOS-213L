; Shared display transaction and deferred keyboard service, 8086 compatible.
; IN_INT10 counts both BIOS drawing and the timer's complete refresh operation.

D_VIDEO_KSEG DW 0
D_VIDEO_KAPI DB 0                 ; 0 unknown, 1 supported, 2 older keyboard

S_VIDEO_BUSY PROC NEAR
        MOV     BX,4B48H
        XOR     AX,AX
        CMP     CS:IN_INT10,0
        JZ      L_VIDEO_QUERY_RET
        INC     AX
L_VIDEO_QUERY_RET:
        IRET
S_VIDEO_BUSY ENDP

; Keep the display transaction occupied while the original BIOS owns control.
; Preserve its returned flags, including CF, in the caller's interrupt frame.
S_VIDEO_CHAIN PROC NEAR
        PUSH    BP
        MOV     BP,SP
        PUSH    WORD PTR SS:[BP+6]
        MOV     BP,SS:[BP]
        CALL    CS:D_INT10
        PUSH    BP
        MOV     BP,SP
        PUSHF
        POP     WORD PTR SS:[BP+8]
        POP     BP
        ADD     SP,2
S_VIDEO_CHAIN ENDP

S_VIDEO_RETURN PROC NEAR
        CLI
        DEC     CS:IN_INT10
        CALL    S_VIDEO_IDLE
        IRET
S_VIDEO_RETURN ENDP

; The keyboard callback services pending input only. It must not unload any
; resident module while this display driver's return address remains live.
S_VIDEO_IDLE PROC NEAR
        PUSHF
        CLI
        CMP     CS:IN_INT10,0
        JNZ     L_VIDEO_IDLE_RET
        PUSH    AX
        PUSH    BX
        PUSH    DS
        MOV     AX,CS:D_INT16
        OR      AX,AX
        JZ      L_VIDEO_IDLE_DONE
        MOV     DS,AX
        CMP     WORD PTR DS:[103H],0CDEFH
        JNZ     L_VIDEO_IDLE_DONE
        CMP     AX,CS:D_VIDEO_KSEG
        JE      L_VIDEO_IDLE_CAPABILITY
        MOV     CS:D_VIDEO_KSEG,AX
        MOV     CS:D_VIDEO_KAPI,0
L_VIDEO_IDLE_CAPABILITY:
        CMP     CS:D_VIDEO_KAPI,2
        JE      L_VIDEO_IDLE_DONE
        CMP     CS:D_VIDEO_KAPI,1
        JE      L_VIDEO_IDLE_CALL
        MOV     AX,2D01H
        MOV     BX,4B48H
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI
        PUSH    BP
        PUSH    ES
        INT     16H
        POP     ES
        POP     BP
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        MOV     CS:D_VIDEO_KAPI,2
        CMP     AX,4B48H
        JNE     L_VIDEO_IDLE_DONE
        MOV     CS:D_VIDEO_KAPI,1
L_VIDEO_IDLE_CALL:
        MOV     AX,2D00H
        MOV     BX,4B48H
        INT     16H
L_VIDEO_IDLE_DONE:
        POP     DS
        POP     BX
        POP     AX
L_VIDEO_IDLE_RET:
        POPF
        RET
S_VIDEO_IDLE ENDP

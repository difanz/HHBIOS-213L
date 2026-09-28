; Coordination with resident display drivers. A modal IRQ must not enter a
; renderer whose private stack or glyph scratch is occupied. AX=1416h is a
; stack-free query; older drivers simply do not return the signature.
S_VIDEO_BUSY PROC NEAR
        PUSH AX
        PUSH BX
        MOV AX,1416H
        XOR BX,BX
        INT 10H
        CMP BX,4B48H
        JNE KV_READY
        CMP AX,1
        JE KV_BUSY
KV_READY:
        POP BX
        POP AX
        CLC
        RET
KV_BUSY:
        POP BX
        POP AX
        STC
        RET
S_VIDEO_BUSY ENDP

; Called after the display driver releases its stack and drawing transaction.
; Its return address is still live, so even a nested INT16/INT28 cannot unload.
KEY_DRAIN PROC FAR
        CMP AL,1
        JE KD_QUERY
        CMP AL,0
        JNE KD_DONE
        CMP CS:D_DEFER,0
        JE KD_DONE
        CMP CS:D_PUMP,0
        JNE KD_DONE
        INC CS:D_PUMP
        PUSHF
        PUSH CS
        CALL KEY_PUMP
        DEC CS:D_PUMP
KD_DONE:
        IRET
KD_QUERY:
        MOV AX,4B48H
        IRET
KEY_DRAIN ENDP

; Foreground INT16 reads/polls may complete a request without DOS idle calls.
; Return CF=1 only after unload: the caller must restore its original frame
; and tail-chain BIOS immediately, without enabling IRQs or allocating memory.
S_FOREGROUND_EXIT PROC NEAR
        CMP CS:D_EXIT,2
        JNE KF_PASS
        CMP CS:D_INKEY,0
        JNE KF_PASS
        CMP CS:D_PUMP,0
        JNE KF_PASS
        CMP CS:D_IRQ,0
        JNE KF_PASS
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH SI
        PUSH DI
        PUSH BP
        PUSH DS
        PUSH ES
        LES BX,CS:D_INDOS
        CMP BYTE PTR ES:[BX],0
        JNE KF_RESTORE
        LES BX,CS:D_CRITERR
        CMP BYTE PTR ES:[BX],0
        JNE KF_RESTORE
        CALL S_VIDEO_BUSY
        JC KF_RESTORE
        MOV AL,2
        CALL S_EXIT_REQUEST
KF_RESTORE:
        POP ES
        POP DS
        POP BP
        POP DI
        POP SI
        POP DX
        POP CX
        POP BX
        POP AX
        CMP CS:D_EXIT,0
        JNE KF_PASS
        STC
        RET
KF_PASS:
        CLC
        RET
S_FOREGROUND_EXIT ENDP

; AL=1 emergency termination, AL=2 normal unload. Callers have saved all
; registers and checked DOS, keyboard and display lifetimes. A refused unload
; stays pending. Successful unload returns with IRQs disabled for immediate
; escape from the released CKBD block.
S_EXIT_REQUEST PROC NEAR
IF HH_CPU GE 3
        .386
        PUSHAD
ENDIF
        MOV CS:D_EXIT,0
        CLI
        MOV CS:D_INKEY,1
        MOV CS:D_28SS,SS
        MOV CS:D_28SP,SP
        PUSH CS
        POP SS
        MOV SP,OFFSET D_28STK
        CLD
        STI
        CMP AL,1
        JE KX_EMERGENCY
        XOR SI,SI
        MOV AX,4A06H
        INT 2FH
        MOV AX,4A06H
        MOV SI,3
        XOR BX,BX
        INT 2FH
        CMP BX,4A06H
        JNE KX_RESTORE
        MOV CS:D_EXIT,2
KX_RESTORE:
        CLI
        MOV CS:D_INKEY,0
        MOV SS,CS:D_28SS
        MOV SP,CS:D_28SP
IF HH_CPU GE 3
        POPAD
ENDIF
        RET
KX_EMERGENCY:
        MOV AX,4CFFH
        INT 21H
S_EXIT_REQUEST ENDP

; INT 2F AX=4A06h/SI=4: query the range affected by a later unload.
; BX=resident PSP, DI=unload kind (0 system, 1 printer, 2 printer fonts).
; AX=1 if recorded in that range, otherwise 0; DX=4A06h signature.
; All other registers are preserved. This query neither frees nor edits TSRs.
L_EXITQUERY:
        CALL S_EXIT_RANGE
        MOV DX,4A06H
        IRET

S_EXIT_RANGE PROC NEAR
        PUSH CX
        PUSH SI
        PUSH BP
        MOV BP,BX
        XOR AX,AX
        CMP DI,2
        JA EQ_DONE
        OR BX,BX
        JZ EQ_DONE
        XOR SI,SI
        OR DI,DI
        JZ EQ_RANGE
        MOV SI,CS:TSRD
        OR SI,SI
        JZ EQ_DONE
        CMP DI,1
        JE EQ_RANGE
        INC SI
EQ_RANGE:
        MOV CX,CS:TSRC
        SUB CX,SI
        JBE EQ_DONE
        SHL SI,1
        SHL SI,1
        ADD SI,OFFSET TSR
EQ_NEXT:
        CMP CS:[SI],BP
        JE EQ_FOUND
        ADD SI,4
        LOOP EQ_NEXT
        JMP SHORT EQ_DONE
EQ_FOUND:
        INC AX
EQ_DONE:
        POP BP
        POP SI
        POP CX
        RET
S_EXIT_RANGE ENDP

; Partial unload leaves unrelated fonts installed. Remove only interrupt
; targets in the blocks that this request is about to release, including a
; printer's blank-glyph fallbacks restored by an earlier font-only unload.
S_EXIT_FONT_VECTORS PROC NEAR
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH SI
        PUSH DI
        PUSH ES
        MOV DI,SI
        XOR AX,AX
        MOV ES,AX
        MOV DX,7AH*4
        MOV CX,6
EV_NEXT:
        MOV SI,DX
        MOV BX,ES:[SI+2]
        CALL S_EXIT_RANGE
        OR AX,AX
        JZ EV_KEEP
        PUSHF
        CLI
        MOV WORD PTR ES:[SI],0
        MOV WORD PTR ES:[SI+2],0
        POPF
EV_KEEP:
        ADD DX,4
        LOOP EV_NEXT
        POP ES
        POP DI
        POP SI
        POP DX
        POP CX
        POP BX
        POP AX
        RET
S_EXIT_FONT_VECTORS ENDP

; The Chinese backends expose 40/80 columns and at most 50 logical rows.
; Larger geometry belongs to a native application: do not reset its mode.
S_EXIT_KEEP_NATIVE PROC NEAR
        PUSH ES
        MOV AX,40H
        MOV ES,AX
        XOR AX,AX
        CMP WORD PTR ES:[4AH],40
        JE EN_ROWS
        CMP WORD PTR ES:[4AH],80
        JNE EN_KEEP
EN_ROWS:
        CMP BYTE PTR ES:[84H],50
        JB EN_DONE
EN_KEEP:
        INC AX
EN_DONE:
        POP ES
        RET
S_EXIT_KEEP_NATIVE ENDP

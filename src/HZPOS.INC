; Read-only character boundary query for the keyboard compatibility filter.
; DX = row/column, AX = 0 single byte, 1 lead, 2 trail; BX = 'HK'.
; CX = direct-screen segment, or zero when the display policy is inactive.
; Use the display policy and corner classifier, including converted frames.
S_HZPOS PROC NEAR
        PUSHF
        CLI
        XOR AX,AX
        CMP CS:D_005A,1
        JNE HP_OFF
        CMP CS:D_ZBFS,0
        JE HP_OFF
        CMP BYTE PTR CS:K_HZ1,0EBH
        JE HP_OFF
        CMP DH,25
        JAE HP_OFF
        CMP DL,80
        JAE HP_OFF
        MOV ES,CS:D_B800
        MOV CL,DL
        MOV AL,160
        MUL DH
        MOV BX,AX
        XOR DL,DL
HP_SCAN:
        MOV AL,ES:[BX]
        CMP AL,0A1H
        JB HP_SINGLE
        CMP AL,0F7H
        JA HP_SINGLE
        CMP DL,79
        JAE HP_SINGLE
        CMP BYTE PTR ES:[BX+2],0A1H
        JB HP_SINGLE
        CMP BYTE PTR ES:[BX+2],0FEH
        JA HP_SINGLE
        CMP CS:D_ZBFS,3
        JNE HP_PAIR
        CALL S_CORNER
        JZ HP_SINGLE
        ADD BX,2
        INC DL
        CALL S_CORNER
        PUSHF
        DEC DL
        SUB BX,2
        POPF
        JZ HP_SINGLE
HP_PAIR:
        MOV AX,1
        CMP DL,CL
        JE HP_DONE
        INC AX
        INC DL
        ADD BX,2
        CMP DL,CL
        JE HP_DONE
HP_NEXT:
        INC DL
        ADD BX,2
        JMP SHORT HP_SCAN
HP_SINGLE:
        XOR AX,AX
        CMP DL,CL
        JNE HP_NEXT
HP_DONE:
        MOV CX,CS:D_B800
        JMP SHORT HP_RETURN
HP_OFF:
        XOR CX,CX
HP_RETURN:
        MOV BX,4B48H
        POPF
        RET
S_HZPOS ENDP

; Keep the DOS UMB arena available while hiding the optional XMS interface.
; This small fixture is installed before HHBIOS and survives its unload.
CSEG SEGMENT
        ASSUME CS:CSEG, DS:CSEG
        ORG 100H
        JMP INSTALL
PREVIOUS DD 0
HANDLER PROC FAR
        CMP AX,4300H
        JNZ CHAIN
        XOR AL,AL
        IRET
CHAIN:  JMP CS:PREVIOUS
HANDLER ENDP
RESIDENT_END LABEL BYTE
INSTALL:
        MOV AX,352FH
        INT 21H
        MOV WORD PTR PREVIOUS,BX
        MOV WORD PTR PREVIOUS+2,ES
        MOV DX,OFFSET HANDLER
        MOV AX,252FH
        INT 21H
        MOV ES,DS:[2CH]
        MOV AH,49H
        INT 21H
        MOV WORD PTR DS:[2CH],0
        MOV DX,OFFSET RESIDENT_END
        ADD DX,15
        MOV CL,4
        SHR DX,CL
        MOV AX,3100H
        INT 21H
CSEG ENDS
END INSTALL

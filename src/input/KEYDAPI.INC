; Foreground dictionary access for CSP. No resident dictionary pointer escapes.
; INT 16h AH=2Eh, BX=4B48h; AX=4B48h on success, zero on failure.
; AL=0: query CX=logical capacity including terminator, DX=basic section end.
; AL=1: snapshot to ES:DI, CX=buffer capacity; return DX=edit generation.
; AL=2: replace extension from snapshot ES:DI, CX=capacity, DX=generation;
;       return the new generation. Other registers and caller FLAGS survive.
Q_SERIAL        DW      0

DICT_API        PROC    FAR
                PUSH    DS
                PUSH    ES
                PUSH    BX
                PUSH    CX
                PUSH    DX
                PUSH    SI
                PUSH    DI
                PUSH    BP
                MOV     BP,SP
                CLI
                CMP     CS:D_INKEY,0
                JNE     QA_BUSY
                CMP     AL,2
                JA      QA_BUSY
                MOV     BX,CS:D_SPCZ
                OR      BX,BX
                JZ      QA_BUSY
                MOV     DS,BX
                MOV     BX,DS:[8]
                ADD     BX,2
                JC      QA_BUSY
                MOV     CS:D_INKEY,1
                INC     CS:D_PUMP
                CLD
                OR      AL,AL
                JZ      QA_QUERY
                CMP     CX,BX
                JB      QA_FAILED
                MOV     SI,DI
                ADD     SI,BX
                JC      QA_FAILED
                CMP     AL,2
                JE      QA_REPLACE
                MOV     CS:T_FAULT,0
                PUSH    DI
                MOV     CX,BX
                XOR     AX,AX
                REP     STOSB
                POP     DI
                MOV     CX,DS:[6]
                ADD     CX,2
                JC      QA_FAILED
                CMP     CX,BX
                JA      QA_FAILED
                XOR     SI,SI
                STI
                CALL    S_DICT_COPY
                CLI
                CMP     CS:T_FAULT,0
                JNE     QA_FAILED
                MOV     DX,CS:Q_SERIAL
                MOV     SS:[BP+6],DX
                JMP     SHORT QA_SUCCESS
QA_QUERY:
                MOV     SS:[BP+8],BX
                MOV     DX,DS:[4]
                MOV     SS:[BP+6],DX
QA_SUCCESS:
                MOV     AX,4B48H
                JMP     SHORT QA_RELEASE
QA_BUSY:
                XOR     AX,AX
                JMP     QA_RETURN
QA_FAILED:
                XOR     AX,AX
QA_RELEASE:
                DEC     CS:D_PUMP
                MOV     CS:D_INKEY,0
QA_RETURN:
                POP     BP
                POP     DI
                POP     SI
                POP     DX
                POP     CX
                POP     BX
                POP     ES
                POP     DS
                IRET

; Only mutable records may be replaced. Validate everything before writing;
; a stale editor must not erase phrases learned after its snapshot.
QA_REPLACE:
                CMP     DX,CS:Q_SERIAL
                JNE     QA_FAILED
                MOV     BX,DI
                XOR     SI,SI
QA_HEADER:
                MOV     AX,DS:[SI]
                CMP     AX,ES:[BX+SI]
                JNE     QA_FAILED
                ADD     SI,2
                CMP     SI,6
                JB      QA_HEADER
                MOV     AX,DS:[8]
                CMP     AX,ES:[DI+8]
                JNE     QA_FAILED
                MOV     AL,DS:[15]
                CMP     AL,ES:[DI+15]
                JNE     QA_FAILED
                MOV     DX,ES:[DI+6]
                CMP     DX,DS:[4]
                JB      QA_FAILED
                CMP     DX,DS:[8]
                JA      QA_FAILED
                MOV     SI,DS:[4]
                ADD     SI,DI
                MOV     BX,DX
                ADD     BX,DI
                CMP     WORD PTR ES:[BX],0
                JNE     QA_FAILED
QA_RECORD:
                CMP     SI,BX
                JE      QA_COMMIT
                XOR     CX,CX
QA_LETTER:
                CMP     SI,BX
                JAE     QA_FAILED
                MOV     AL,ES:[SI]
                INC     SI
                CMP     AL,','
                JE      QA_LENGTH
                INC     CX
                JMP     SHORT QA_LETTER
QA_LENGTH:
                CMP     CX,4
                JB      QA_FAILED
                CMP     CX,254
                JA      QA_FAILED
                CMP     CX,6
                JA      QA_RECORD
                TEST    CL,1
                JNZ     QA_FAILED
                JMP     SHORT QA_RECORD
QA_COMMIT:
                MOV     SI,DS:[4]
                MOV     CX,DX
                SUB     CX,SI
                ADD     CX,2
                ADD     SI,DI
                MOV     DI,DS:[4]
                CMP     CS:Q_HANDLE,0
                JE      QA_DESTINATION
                MOV     AX,DS
                CMP     AX,CS:Q_SEG
                JNE     QA_DESTINATION
                MOV     DI,16
QA_DESTINATION:
                PUSH    DS
                PUSH    ES
                POP     DS
                POP     ES
                REP     MOVSB
                MOV     ES:[6],DX
                INC     CS:Q_SERIAL
                MOV     DX,CS:Q_SERIAL
                MOV     SS:[BP+6],DX
                JMP     QA_SUCCESS
DICT_API        ENDP

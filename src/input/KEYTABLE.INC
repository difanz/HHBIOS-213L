; Read-only CKBD tables retain their original offsets, including scan cursors.
; A single 1 KiB cache covers sequential searches in either direction. No DOS
; calls, locked XMS addresses, or A20 changes are needed while typing.
T_XMS           DD      0
T_INT2F         DD      0
T_HANDLE        DW      0
T_BASE          DW      0
T_LENGTH        DW      0
T_PAGE          DW      -1
T_BUSY          DB      0
T_FAULT         DB      0
T_LOCAL         DB      0
; Reuse the first discarded table page. With no XMS, no cache is retained.
T_CACHE         EQU     D_BUF+768

; CS:BX is the original table address. Return AX, preserving all other
; registers and FLAGS (in particular DF for reverse candidate searches).
S_TABLE_WORD    PROC    NEAR
                PUSHF
                CMP     CS:T_HANDLE,0
                JNZ     L_TW_XMS
                MOV     AX,CS:[BX]
                POPF
                RET
L_TW_XMS:
                CLI
                PUSH    BX
                SUB     BX,CS:T_BASE
                JC      L_TW_BAD
                CMP     BX,CS:T_LENGTH
                JAE     L_TW_BAD
                TEST    BX,1
                JNZ     L_TW_BAD
                MOV     AX,BX
                AND     AX,0FC00H
                CMP     CS:T_BUSY,0
                JNZ     L_TW_MISS
                CMP     AX,CS:T_PAGE
                JNZ     L_TW_MISS
                AND     BX,3FFH
                MOV     AX,WORD PTR CS:T_CACHE[BX]
L_TW_DONE:
                POP     BX
                POPF
                RET
L_TW_BAD:
                MOV     CS:T_FAULT,1
                XOR     AX,AX
                JMP     SHORT L_TW_DONE
L_TW_MISS:
                CALL    S_TABLE_FETCH
                JMP     SHORT L_TW_DONE
S_TABLE_WORD    ENDP

; Each request has its own stack descriptor. XMS may open an interrupt window;
; a nested lookup uses a private word instead of replacing an in-flight cache.
S_TABLE_FETCH   PROC    NEAR
                PUSH    CX
                PUSH    DX
                PUSH    SI
                PUSH    DI
                PUSH    BP
                PUSH    DS
                MOV     BP,SP
                SUB     SP,20
                MOV     SI,SP
                PUSH    SS
                POP     DS
                MOV     DI,AX
                MOV     CX,CS:T_LENGTH
                SUB     CX,AX
                CMP     CX,1024
                JBE     L_TF_SIZE
                MOV     CX,1024
L_TF_SIZE:
                MOV     WORD PTR [SI+12],OFFSET T_CACHE
                MOV     [SI+14],CS
                MOV     WORD PTR [SI+16],0
                CMP     CS:T_BUSY,0
                JE      L_TF_CACHE
                MOV     AX,BX
                MOV     CX,2
                LEA     DX,[SI+18]
                MOV     [SI+12],DX
                MOV     [SI+14],SS
                MOV     WORD PTR [SI+16],1
                JMP     SHORT L_TF_MOVE
L_TF_CACHE:
                MOV     CS:T_BUSY,1
                MOV     CS:T_PAGE,-1
L_TF_MOVE:
                MOV     [SI],CX
                MOV     WORD PTR [SI+2],0
                MOV     DX,CS:T_HANDLE
                MOV     [SI+4],DX
                MOV     [SI+6],AX
                MOV     WORD PTR [SI+8],0
                MOV     WORD PTR [SI+10],0
                MOV     AH,0BH
                CLD
                PUSH    BX
                CALL    CS:T_XMS
                POP     BX
                CLI
                CMP     WORD PTR [SI+16],0
                JNZ     L_TF_PRIVATE
                MOV     CS:T_BUSY,0
                CMP     AX,1
                JNE     L_TF_BAD
                MOV     CS:T_PAGE,DI
                PUSH    BX
                AND     BX,3FFH
                MOV     AX,WORD PTR CS:T_CACHE[BX]
                POP     BX
                JMP     SHORT L_TF_DONE
L_TF_PRIVATE:
                CMP     AX,1
                JNE     L_TF_BAD
                MOV     AX,[SI+18]
                JMP     SHORT L_TF_DONE
L_TF_BAD:
                MOV     CS:T_FAULT,1
                XOR     AX,AX
L_TF_DONE:
                MOV     SP,BP
                POP     DS
                POP     BP
                POP     DI
                POP     SI
                POP     DX
                POP     CX
                RET
S_TABLE_FETCH   ENDP

S_TABLE_SI      PROC    NEAR
                PUSH    BX
                MOV     BX,SI
                CALL    S_TABLE_WORD
                POP     BX
                RET
S_TABLE_SI      ENDP
S_TABLE_DI      PROC    NEAR
                PUSH    BX
                MOV     BX,DI
                CALL    S_TABLE_WORD
                POP     BX
                RET
S_TABLE_DI      ENDP

; Advance a virtual scan cursor without dereferencing its former memory.
S_TABLE_NEXT    PROC    NEAR
                PUSHF
                PUSH    AX
                PUSHF
                POP     AX
                TEST    AX,400H
                JNZ     L_TN_BACK
                LEA     SI,[SI+2]
                JMP     SHORT L_TN_DONE
L_TN_BACK:
                LEA     SI,[SI-2]
L_TN_DONE:
                POP     AX
                POPF
                RET
S_TABLE_NEXT    ENDP

                INCLUDE KEYINDEX.INC
                INCLUDE KEYPHRASE.INC

; Called once with CS=DS, BP immediately past the loaded tables. Keep their
; conventional copy unless allocation AND the initial transfer succeed.
S_TABLE_OPEN    PROC    NEAR
                MOV     AX,BP
                SUB     AX,T_BASE
                JC      L_TO_DONE
                CMP     AX,1024
                JBE     L_TO_DONE
                TEST    AX,1
                JNZ     L_TO_DONE
                CMP     T_LOCAL,0
                JNZ     L_TO_DONE
                MOV     T_LENGTH,AX
                MOV     AX,4300H
                INT     2FH
                CMP     AL,80H
                JNE     L_TO_DONE
                MOV     AX,4310H
                INT     2FH
                MOV     WORD PTR T_XMS,BX
                MOV     WORD PTR T_XMS+2,ES
                MOV     DX,T_LENGTH
                DEC     DX
                MOV     CL,10
                SHR     DX,CL
                INC     DX
                MOV     AH,9
                CALL    T_XMS
                CMP     AX,1
                JNE     L_TO_DONE
                MOV     T_HANDLE,DX
                PUSH    BP
                SUB     SP,16
                MOV     BP,SP
                MOV     AX,T_LENGTH
                MOV     [BP],AX
                MOV     WORD PTR [BP+2],0
                MOV     WORD PTR [BP+4],0
                MOV     AX,T_BASE
                MOV     [BP+6],AX
                MOV     [BP+8],CS
                MOV     [BP+10],DX
                MOV     WORD PTR [BP+12],0
                MOV     WORD PTR [BP+14],0
                MOV     SI,BP
                PUSH    DS
                PUSH    SS
                POP     DS
                MOV     AH,0BH
                CALL    CS:T_XMS
                POP     DS
                ADD     SP,16
                POP     BP
                CMP     AX,1
                JNE     L_TO_FREE
                CALL    S_INDEX_OPEN
                MOV     BP,T_BASE
                ADD     BP,1024
                JMP     SHORT L_TO_DONE
L_TO_FREE:
                MOV     DX,T_HANDLE
                MOV     AH,0AH
                CALL    T_XMS
                MOV     T_HANDLE,0
L_TO_DONE:
                PUSH    CS
                POP     ES
                RET
S_TABLE_OPEN    ENDP

; Chain full-system unload only after releasing our own XMS handles. The font
; reader restores the saved INT 2Fh vector and frees CKBD's DOS block.
TABLE_INT2F     PROC    FAR
                PUSHF
                CMP     AX,4A06H
                JNE     L_TI_CHAIN
                OR      SI,SI
                JNZ     L_TI_CHAIN
                PUSH    AX
                PUSH    BX
                PUSH    DX
                MOV     DX,CS:Q_HANDLE
                OR      DX,DX
                JZ      L_TI_PHRASE
                MOV     AH,0AH
                CLD
                CALL    CS:T_XMS
                MOV     CS:Q_HANDLE,0
L_TI_PHRASE:
                MOV     DX,CS:P_HANDLE
                OR      DX,DX
                JZ      L_TI_INDEX
                MOV     AH,0AH
                CLD
                CALL    CS:T_XMS
                MOV     CS:P_HANDLE,0
L_TI_INDEX:
                MOV     DX,CS:I_HANDLE
                OR      DX,DX
                JZ      L_TI_RAW
                MOV     AH,0AH
                CLD
                CALL    CS:T_XMS
                MOV     CS:I_HANDLE,0
L_TI_RAW:
                MOV     DX,CS:T_HANDLE
                OR      DX,DX
                JZ      L_TI_DONE
                MOV     AH,0AH
                CLD
                CALL    CS:T_XMS
                MOV     CS:T_HANDLE,0
L_TI_DONE:
                POP     DX
                POP     BX
                POP     AX
L_TI_CHAIN:
                POPF
                JMP     CS:T_INT2F
TABLE_INT2F     ENDP

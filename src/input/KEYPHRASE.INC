; Index immutable two-character phrase groups by their first Hanzi's double
; pinyin. Entries retain dictionary order: {double pinyin, group offset}.
; The mutable extension and the three/multi-character scanners stay intact.
P_HANDLE        DW      0
P_LENGTH        DW      0
P_CURSOR        DW      0
P_PAGE          DW      -1
P_END           DW      0

S_PHRASE_MOVE   PROC    NEAR
                PUSH    DX
                MOV     DX,CS:P_HANDLE
                CALL    S_EXTERNAL_MOVE
                POP     DX
                RET
S_PHRASE_MOVE   ENDP

; Called after SPCZ.DAT is loaded. Borrow the table cache only during setup;
; raw pinyin lookups then use private stack words, not the staging buffer.
S_PHRASE_OPEN   PROC    NEAR
                PUSHF
                PUSH    AX
                PUSH    BX
                PUSH    CX
                PUSH    DX
                PUSH    SI
                PUSH    DI
                PUSH    BP
                PUSH    DS
                CLD
                CMP     CS:T_HANDLE,0
                JE      L_PO_DONE
                CMP     CS:D_PY,0
                JE      L_PO_DONE
                MOV     AX,CS:D_SPCZ
                OR      AX,AX
                JZ      L_PO_DONE
                MOV     DS,AX
                CMP     BYTE PTR DS:[0FH],0FFH
                JNE     L_PO_DONE
                MOV     AX,DS:[0]
                CMP     AX,16
                JBE     L_PO_DONE
                CMP     AX,DS:[6]
                JA      L_PO_DONE
                TEST    AX,1
                JNZ     L_PO_DONE
                MOV     CS:P_END,AX
                MOV     SI,16
                XOR     CX,CX
L_PO_COUNT:
                ADD     CX,4
                JC      L_PO_DONE
                ADD     SI,2
                CALL    S_PHRASE_NEXT
                CMP     SI,CS:P_END
                JB      L_PO_COUNT
                MOV     DX,CX
                DEC     DX
                MOV     CL,10
                SHR     DX,CL
                INC     DX
                MOV     AH,9
                CALL    CS:T_XMS
                CMP     AX,1
                JNE     L_PO_DONE
                MOV     CS:P_HANDLE,DX
                MOV     CS:T_BUSY,1
                MOV     CS:T_PAGE,-1
                MOV     SI,16
L_PO_GROUP:
                MOV     DI,SI
                LODSW
                CALL    S_A9A0
                MOV     BX,CS:P_CURSOR
                MOV     WORD PTR CS:T_CACHE[BX],AX
                MOV     WORD PTR CS:T_CACHE[BX+2],DI
                ADD     CS:P_CURSOR,4
                CALL    S_PHRASE_NEXT
                CMP     CS:P_CURSOR,1024
                JAE     L_PO_FLUSH
                CMP     SI,CS:P_END
                JB      L_PO_GROUP
L_PO_FLUSH:
                PUSH    SI
                MOV     SI,OFFSET T_CACHE
                MOV     DI,CS:P_LENGTH
                MOV     CX,CS:P_CURSOR
                MOV     AX,1
                CALL    S_PHRASE_MOVE
                POP     SI
                CMP     AX,1
                JNE     L_PO_FREE
                CMP     CS:T_FAULT,0
                JNE     L_PO_FREE
                ADD     CS:P_LENGTH,CX
                MOV     CS:P_CURSOR,0
                CMP     SI,CS:P_END
                JB      L_PO_GROUP
                JMP     SHORT L_PO_UNLOCK
L_PO_FREE:
                MOV     DX,CS:P_HANDLE
                MOV     AH,0AH
                CALL    CS:T_XMS
                MOV     CS:P_HANDLE,0
L_PO_UNLOCK:
                MOV     CS:T_BUSY,0
                MOV     CS:T_FAULT,0
L_PO_DONE:
                POP     DS
                POP     BP
                POP     DI
                POP     SI
                POP     DX
                POP     CX
                POP     BX
                POP     AX
                POPF
                RET
S_PHRASE_OPEN   ENDP

; Enter where the original basic dictionary scanner starts. CF=0 completed
; two-character groups; CF=1 selects the original linear scanner.
; DS remains the dictionary; SI points to its three-character section.
S_PHRASE_SEARCH PROC    NEAR
                CMP     CS:P_HANDLE,0
                JE      L_PS_FALLBACK
                CMP     CS:T_BUSY,0
                JNE     L_PS_FALLBACK
                MOV     AX,DS:[0]
                CMP     AX,CS:P_END
                JNE     L_PS_FALLBACK
                MOV     CS:T_BUSY,1
                MOV     CS:T_PAGE,-1
                MOV     CS:P_PAGE,-1
                MOV     CS:P_CURSOR,0
L_PS_ENTRY:
                MOV     BX,CS:P_CURSOR
                CMP     BX,CS:P_LENGTH
                JAE     L_PS_DONE
                MOV     AX,BX
                AND     AX,0FC00H
                CMP     AX,CS:P_PAGE
                JE      L_PS_CACHED
                MOV     DI,AX
                MOV     SI,OFFSET T_CACHE
                MOV     CX,CS:P_LENGTH
                SUB     CX,DI
                CMP     CX,1024
                JBE     L_PS_SIZE
                MOV     CX,1024
L_PS_SIZE:
                XOR     AX,AX
                CALL    S_PHRASE_MOVE
                CMP     AX,1
                JNE     L_PS_FAILED
                MOV     CS:P_PAGE,DI
L_PS_CACHED:
                AND     BX,3FFH
                MOV     AX,WORD PTR CS:T_CACHE[BX]
                CMP     AX,WORD PTR CS:D_2CC1
                JNE     L_PS_NEXT
                MOV     DI,WORD PTR CS:T_CACHE[BX+2]
                LEA     SI,[DI+2]
                MOV     BP,4
                XOR     DL,DL
L_PS_SECOND:
                CMP     SI,CS:P_END
                JAE     L_PS_NEXT
                LODSW
                TEST    AX,8080H
                JZ      L_PS_NEXT
                CALL    S_A9A0
                CMP     AL,CS:D_2CC1+2
                JNE     L_PS_SKIP
                CMP     CS:D_2CC1+3,'?'
                JE      L_PS_MATCH
                CMP     AH,CS:D_2CC1+3
                JNE     L_PS_SKIP
L_PS_MATCH:
                CALL    S_A990
L_PS_SKIP:
                ADD     DL,2
                JMP     SHORT L_PS_SECOND
L_PS_NEXT:
                ADD     CS:P_CURSOR,4
                JMP     L_PS_ENTRY
L_PS_FAILED:
                MOV     CS:T_FAULT,1
L_PS_DONE:
                MOV     SI,CS:P_END
                MOV     BP,4
                XOR     DL,DL
                MOV     CS:T_BUSY,0
                CLC
                RET
L_PS_FALLBACK:
                STC
                RET
S_PHRASE_SEARCH ENDP

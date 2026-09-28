; The basic SPCZ dictionary keeps its logical offsets in XMS. Its live header
; and mutable extension remain in the original dictionary segment. A separate
; 2 KiB cache avoids evicting the pinyin tables during phrase searches.
Q_HANDLE        DW      0
Q_SEG           DW      0
Q_BASE          DW      0
Q_CACHE         DW      0
Q_PAGE          DW      -1
Q_BUSY          DB      0

; DS:BX is a logical dictionary address. Preserve other registers and FLAGS.
S_DICT_BYTE     PROC    NEAR
                PUSHF
                CLI
                PUSH    BX
                PUSH    CX
                PUSH    DX
                PUSH    AX
                MOV     DX,1
                CALL    S_DICT_READ
                POP     DX
                MOV     AH,DH
                POP     DX
                POP     CX
                POP     BX
                POPF
                RET
S_DICT_BYTE     ENDP

S_DICT_WORD     PROC    NEAR
                PUSHF
                CLI
                PUSH    BX
                PUSH    CX
                PUSH    DX
                MOV     DX,2
                CALL    S_DICT_READ
                POP     DX
                POP     CX
                POP     BX
                POPF
                RET
S_DICT_WORD     ENDP

; Internal read, DX=1 or 2. Interrupts stay masked until a cache miss calls
; XMS; that call owns Q_BUSY so a nested read uses its own stack buffer.
S_DICT_READ     PROC    NEAR
                MOV     AX,DS
                CMP     AX,CS:Q_SEG
                JNE     L_QR_DIRECT
                CMP     CS:Q_HANDLE,0
                JE      L_QR_DIRECT
                CMP     BX,16
                JB      L_QR_HEADER
                CMP     BX,CS:Q_BASE
                JB      L_QR_BASIC
                MOV     AX,DS:[8]
                ADD     AX,2
                JC      L_QR_BAD
                SUB     AX,BX
                JC      L_QR_BAD
                CMP     AX,DX
                JB      L_QR_BAD
                SUB     BX,CS:Q_BASE
                ADD     BX,16
L_QR_DIRECT:
                MOV     AL,[BX]
                CMP     DL,1
                JE      L_QR_DONE
                MOV     AX,[BX]
L_QR_DONE:
                RET
L_QR_HEADER:
                CMP     BX,15
                JNE     L_QR_DIRECT
                CMP     DL,1
                JE      L_QR_DIRECT
                JMP     SHORT L_QR_SPLIT
L_QR_BASIC:
                MOV     AX,CS:Q_BASE
                SUB     AX,BX
                CMP     AX,DX
                JB      L_QR_SPLIT
                MOV     CX,BX
                AND     CX,1
                CMP     DL,1
                JE      L_QR_ALIGNED
                JCXZ    L_QR_ALIGNED
L_QR_SPLIT:
                CALL    S_DICT_BYTE
                MOV     CX,AX
                INC     BX
                CALL    S_DICT_BYTE
                MOV     AH,AL
                MOV     AL,CL
                CMP     CS:T_FAULT,0
                JE      L_QR_DONE
                XOR     AX,AX
                RET
L_QR_ALIGNED:
                AND     BX,0FFFEH
                MOV     AX,BX
                AND     AX,0F800H
                CMP     CS:Q_BUSY,0
                JNE     L_QR_FETCH
                CMP     AX,CS:Q_PAGE
                JNE     L_QR_FETCH
                AND     BX,7FFH
                ADD     BX,CS:Q_CACHE
                MOV     AX,[BX]
                JMP     SHORT L_QR_BYTE
L_QR_FETCH:
                CALL    S_DICT_FETCH
L_QR_BYTE:
                JCXZ    L_QR_DONE
                MOV     AL,AH
                RET
L_QR_BAD:
                MOV     CS:T_FAULT,1
                XOR     AX,AX
                RET
S_DICT_READ     ENDP

; AX is the page start, BX an even logical offset. Return its word. The final
; page includes one padded byte when Q_BASE is odd; no read exceeds the XMS
; allocation. Nested calls never replace a cache page being transferred.
S_DICT_FETCH    PROC    NEAR
                PUSH    BX
                PUSH    CX
                PUSH    DX
                PUSH    SI
                PUSH    DI
                PUSH    BP
                PUSH    DS
                PUSH    ES
                MOV     BP,SP
                SUB     SP,20
                MOV     SI,SP
                MOV     DX,DS
                PUSH    SS
                POP     DS
                MOV     DI,AX
                MOV     CX,CS:Q_BASE
                INC     CX
                AND     CX,0FFFEH
                SUB     CX,AX
                CMP     CX,2048
                JBE     L_QF_SIZE
                MOV     CX,2048
L_QF_SIZE:
                MOV     [SI+14],DX
                MOV     DX,CS:Q_CACHE
                MOV     [SI+12],DX
                MOV     WORD PTR [SI+16],0
                CMP     CS:Q_BUSY,0
                JE      L_QF_CACHE
                MOV     AX,BX
                MOV     CX,2
                LEA     DX,[SI+18]
                MOV     [SI+12],DX
                MOV     [SI+14],SS
                MOV     WORD PTR [SI+16],1
                JMP     SHORT L_QF_MOVE
L_QF_CACHE:
                MOV     CS:Q_BUSY,1
                MOV     CS:Q_PAGE,-1
L_QF_MOVE:
                MOV     [SI],CX
                MOV     WORD PTR [SI+2],0
                MOV     DX,CS:Q_HANDLE
                MOV     [SI+4],DX
                MOV     [SI+6],AX
                MOV     WORD PTR [SI+8],0
                MOV     WORD PTR [SI+10],0
                PUSH    BX
                MOV     AH,0BH
                CLD
                CALL    CS:T_XMS
                POP     BX
                CLI
                CMP     WORD PTR [SI+16],0
                JNE     L_QF_PRIVATE
                MOV     CS:Q_BUSY,0
                CMP     AX,1
                JNE     L_QF_BAD
                MOV     CS:Q_PAGE,DI
                MOV     ES,CS:Q_SEG
                AND     BX,7FFH
                ADD     BX,CS:Q_CACHE
                MOV     AX,ES:[BX]
                JMP     SHORT L_QF_DONE
L_QF_PRIVATE:
                CMP     AX,1
                JNE     L_QF_BAD
                MOV     AX,[SI+18]
                JMP     SHORT L_QF_DONE
L_QF_BAD:
                MOV     CS:T_FAULT,1
                XOR     AX,AX
L_QF_DONE:
                MOV     SP,BP
                POP     ES
                POP     DS
                POP     BP
                POP     DI
                POP     SI
                POP     DX
                POP     CX
                POP     BX
                RET
S_DICT_FETCH    ENDP

S_DICT_LODSB    PROC    NEAR
                PUSHF
                PUSH    BX
                MOV     BX,SI
                CALL    S_DICT_BYTE
                PUSHF
                POP     BX
                TEST    BH,4
                JNZ     L_QLB_BACK
                INC     SI
                JMP     SHORT L_QLB_DONE
L_QLB_BACK:
                DEC     SI
L_QLB_DONE:
                POP     BX
                POPF
                RET
S_DICT_LODSB    ENDP

S_DICT_LODSW    PROC    NEAR
                PUSHF
                PUSH    BX
                MOV     BX,SI
                CALL    S_DICT_WORD
                PUSHF
                POP     BX
                TEST    BH,4
                JNZ     L_QLW_BACK
                ADD     SI,2
                JMP     SHORT L_QLW_DONE
L_QLW_BACK:
                SUB     SI,2
L_QLW_DONE:
                POP     BX
                POPF
                RET
S_DICT_LODSW    ENDP

; REP MOVSB with a logical source. Foreign dictionaries retain their ordinary
; direct copy. Return CX=0, preserving AX/BX/DX/BP and the caller's FLAGS.
S_DICT_COPY     PROC    NEAR
                PUSHF
                PUSH    AX
                JCXZ    L_QC_DONE
                MOV     AX,DS
                CMP     AX,CS:Q_SEG
                JNE     L_QC_DIRECT
                CMP     CS:Q_HANDLE,0
                JE      L_QC_DIRECT
L_QC_NEXT:
                CMP     CS:T_FAULT,0
                JNE     L_QC_BLANK
                CALL    S_DICT_LODSB
                STOSB
                LOOP    L_QC_NEXT
                JMP     SHORT L_QC_DONE
L_QC_BLANK:
                PUSHF
                POP     AX
                TEST    AH,4
                JNZ     L_QC_BACK
                ADD     SI,CX
                JMP     SHORT L_QC_FILL
L_QC_BACK:
                SUB     SI,CX
L_QC_FILL:
                XOR     AL,AL
                REP     STOSB
                JMP     SHORT L_QC_DONE
L_QC_DIRECT:
                REP     MOVSB
L_QC_DONE:
                POP     AX
                POPF
                RET
S_DICT_COPY     ENDP

; BP is the original allocated-end segment. Commit the compacted layout only
; after the immutable copy succeeds. Preserve all other registers and FLAGS.
S_DICT_OPEN     PROC    NEAR
                PUSHF
                PUSH    AX
                PUSH    BX
                PUSH    CX
                PUSH    DX
                PUSH    SI
                PUSH    DI
                PUSH    DS
                PUSH    ES
                PUSH    BP
                MOV     BP,SP
                SUB     SP,22
                CLD
                CMP     CS:Q_HANDLE,0
                JNE     L_QO_DONE
                CMP     CS:T_HANDLE,0
                JE      L_QO_DONE
                CMP     CS:T_LOCAL,0
                JNE     L_QO_DONE
                MOV     AX,CS:D_SPCZ
                OR      AX,AX
                JZ      L_QO_DONE
                MOV     DS,AX
                CMP     BYTE PTR DS:[0FH],0FFH
                JNE     L_QO_DONE
                MOV     SI,DS:[4]
                CMP     SI,16
                JBE     L_QO_DONE
                CMP     SI,DS:[6]
                JA      L_QO_DONE
                MOV     BX,DS:[8]
                CMP     BX,DS:[6]
                JB      L_QO_DONE
                CMP     BX,0FFFDH
                JA      L_QO_DONE
                MOV     AX,BX
                SUB     AX,SI
                ADD     AX,19
                JC      L_QO_DONE
                AND     AX,0FFFEH
                MOV     [BP-18],AX
                ADD     AX,2048
                JC      L_QO_DONE
                MOV     CL,4
                SHR     AX,CL
                INC     AX
                MOV     DX,DS
                ADD     AX,DX
                JC      L_QO_DONE
                CMP     AX,[BP]
                JAE     L_QO_DONE
                MOV     [BP-20],AX
                MOV     [BP-22],SI
                MOV     DX,SI
                DEC     DX
                MOV     CL,10
                SHR     DX,CL
                INC     DX
                MOV     AH,9
                CALL    CS:T_XMS
                CMP     AX,1
                JNE     L_QO_DONE
                MOV     AX,SI
                INC     AX
                AND     AX,0FFFEH
                MOV     [BP-16],AX
                MOV     WORD PTR [BP-14],0
                MOV     WORD PTR [BP-12],0
                MOV     WORD PTR [BP-10],0
                MOV     [BP-8],DS
                MOV     [BP-6],DX
                MOV     WORD PTR [BP-4],0
                MOV     WORD PTR [BP-2],0
                LEA     SI,[BP-16]
                PUSH    DS
                PUSH    SS
                POP     DS
                MOV     AH,0BH
                CALL    CS:T_XMS
                POP     DS
                CMP     AX,1
                JNE     L_QO_FREE
                PUSH    DS
                POP     ES
                MOV     SI,[BP-22]
                MOV     CX,DS:[6]
                SUB     CX,SI
                ADD     CX,2
                MOV     DI,16
                REP     MOVSB
                MOV     AX,[BP-22]
                MOV     CS:Q_BASE,AX
                MOV     AX,[BP-18]
                MOV     CS:Q_CACHE,AX
                MOV     AX,[BP-6]
                MOV     CS:Q_HANDLE,AX
                MOV     CS:Q_SEG,DS
                MOV     CS:Q_PAGE,-1
                MOV     AX,[BP-20]
                MOV     [BP],AX
                JMP     SHORT L_QO_DONE
L_QO_FREE:
                MOV     DX,[BP-6]
                MOV     AH,0AH
                CALL    CS:T_XMS
L_QO_DONE:
                MOV     SP,BP
                POP     BP
                POP     ES
                POP     DS
                POP     DI
                POP     SI
                POP     DX
                POP     CX
                POP     BX
                POP     AX
                POPF
                RET
S_DICT_OPEN     ENDP

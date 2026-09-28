; These installation helpers occupy the first 64 bytes of the future return
; buffer. Table loading starts 1024 bytes later and cannot overwrite them.
S_INDEX_SIZE    PROC    NEAR
                MOV     AX,[SI]
                OR      AX,AX
                JZ      L_IZ_EMPTY
                CMP     AX,T_BASE
                JB      L_IZ_BAD
                MOV     DX,[SI+2]
                CMP     DX,BP
                JA      L_IZ_BAD
                SUB     DX,AX
                CMP     DX,6768*2
                JNE     L_IZ_BAD
                ADD     CX,DX
                RET
L_IZ_EMPTY:
                CMP     WORD PTR [SI+2],0
                JNE     L_IZ_BAD
                CLC
                RET
L_IZ_BAD:
                STC
                RET
S_INDEX_SIZE    ENDP

; DS is the dictionary; SI is just after a group header. Return the next
; header, bounded by the basic two-character section, including empty groups.
S_PHRASE_NEXT   PROC    NEAR
L_PN_SCAN:
                CMP     SI,CS:P_END
                JAE     L_PN_DONE
                TEST    WORD PTR [SI],8080H
                JZ      L_PN_DONE
                ADD     SI,2
                JMP     SHORT L_PN_SCAN
L_PN_DONE:
                RET
S_PHRASE_NEXT   ENDP

; Stable first-code buckets: {original table offset, packed code} records.
; The optional index lives in XMS and borrows the existing 1 KiB table cache.
I_HANDLE        DW      0
I_LENGTH        DW      0
I_SW            DW      33 DUP(0)
I_PY            DW      33 DUP(0)
I_BUFFER        DW      0
I_USED          DW      0
I_PAGE          DW      -1
I_CURSOR        DW      0
I_LIMIT         DW      0
I_START         DW      0
I_MASK          DW      0
I_QUERY         DW      0
I_STEP          DW      4

; CX bytes between CS:SI and index offset DI. AX=0 reads, AX=1 writes.
; Preserve all registers except AX (XMS status), and preserve DF/IF.
S_INDEX_MOVE    PROC    NEAR
                PUSH    DX
                MOV     DX,CS:I_HANDLE
                CALL    S_EXTERNAL_MOVE
                POP     DX
                RET
S_INDEX_MOVE    ENDP

; Same transfer contract, with the XMS handle supplied in DX.
S_EXTERNAL_MOVE PROC    NEAR
                PUSHF
                PUSH    BX
                PUSH    CX
                PUSH    DX
                PUSH    SI
                PUSH    DI
                PUSH    BP
                PUSH    DS
                MOV     BP,SP
                SUB     SP,16
                MOV     [BP-16],CX
                MOV     WORD PTR [BP-14],0
                OR      AX,AX
                JNZ     L_IM_WRITE
                MOV     [BP-12],DX
                MOV     [BP-10],DI
                MOV     WORD PTR [BP-8],0
                MOV     WORD PTR [BP-6],0
                MOV     [BP-4],SI
                MOV     [BP-2],CS
                JMP     SHORT L_IM_CALL
L_IM_WRITE:
                MOV     WORD PTR [BP-12],0
                MOV     [BP-10],SI
                MOV     [BP-8],CS
                MOV     [BP-6],DX
                MOV     [BP-4],DI
                MOV     WORD PTR [BP-2],0
L_IM_CALL:
                MOV     SI,SP
                PUSH    SS
                POP     DS
                MOV     AH,0BH
                CLD
                CALL    CS:T_XMS
                MOV     SP,BP
                POP     DS
                POP     BP
                POP     DI
                POP     SI
                POP     DX
                POP     CX
                POP     BX
                POPF
                RET
S_EXTERNAL_MOVE ENDP

; Flush the temporary installation buffer without consuming resident memory.
S_INDEX_FLUSH   PROC    NEAR
                PUSH    CX
                PUSH    SI
                PUSH    DI
                MOV     CX,I_USED
                MOV     AX,1
                JCXZ    L_IF_DONE
                MOV     SI,I_BUFFER
                MOV     DI,I_LENGTH
                CALL    S_INDEX_MOVE
                CMP     AX,1
                JNE     L_IF_DONE
                ADD     I_LENGTH,CX
                MOV     I_USED,0
L_IF_DONE:
                POP     DI
                POP     SI
                POP     CX
                RET
S_INDEX_FLUSH   ENDP

; SI..BX is a validated table; DI points to its 33-word bucket directory.
S_INDEX_BUILD   PROC    NEAR
                PUSH    BP
                MOV     BP,SI
                XOR     DX,DX
L_IB_BUCKET:
                MOV     AX,I_LENGTH
                ADD     AX,I_USED
                MOV     [DI],AX
                ADD     DI,2
                MOV     SI,BP
L_IB_SCAN:
                CMP     SI,BX
                JAE     L_IB_NEXT
                MOV     AX,[SI]
                AND     AL,1FH
                CMP     AL,DL
                JNE     L_IB_SKIP
                PUSH    BX
                MOV     BX,I_BUFFER
                ADD     BX,I_USED
                MOV     [BX],SI
                MOV     AX,[SI]
                MOV     [BX+2],AX
                POP     BX
                ADD     I_USED,4
                CMP     I_USED,1024
                JB      L_IB_SKIP
                CALL    S_INDEX_FLUSH
                CMP     AX,1
                JNE     L_IB_DONE
L_IB_SKIP:
                ADD     SI,2
                JMP     SHORT L_IB_SCAN
L_IB_NEXT:
                INC     DL
                CMP     DL,32
                JB      L_IB_BUCKET
                MOV     AX,I_LENGTH
                ADD     AX,I_USED
                MOV     [DI],AX
                CALL    S_INDEX_FLUSH
L_IB_DONE:
                POP     BP
                RET
S_INDEX_BUILD   ENDP

; The raw tables are still present; BP is their end. Allocation/build failure
; leaves the original XMS table backend usable, with linear search as fallback.
S_INDEX_OPEN    PROC    NEAR
                MOV     AX,BP
                ADD     AX,1024
                JC      L_IO_DONE
                MOV     DX,SS
                MOV     CX,CS
                CMP     DX,CX
                JNE     L_IO_BUFFER
                MOV     DX,SP
                CMP     DX,BP
                JBE     L_IO_BUFFER
                SUB     DX,512
                JC      L_IO_DONE
                CMP     AX,DX
                JA      L_IO_DONE
L_IO_BUFFER:
                MOV     I_BUFFER,BP
                XOR     CX,CX
                MOV     SI,OFFSET D_SW
                CALL    S_INDEX_SIZE
                JC      L_IO_DONE
                MOV     SI,OFFSET D_PY
                CALL    S_INDEX_SIZE
                JC      L_IO_DONE
                JCXZ    L_IO_DONE
                SHL     CX,1
                JC      L_IO_DONE
                MOV     DX,CX
                DEC     DX
                MOV     CL,10
                SHR     DX,CL
                INC     DX
                MOV     AH,9
                CALL    T_XMS
                CMP     AX,1
                JNE     L_IO_DONE
                MOV     I_HANDLE,DX
                MOV     SI,D_SW
                MOV     BX,D_SW+2
                MOV     DI,OFFSET I_SW
                CALL    S_INDEX_BUILD
                CMP     AX,1
                JNE     L_IO_FREE
                MOV     SI,D_PY
                MOV     BX,D_PY+2
                MOV     DI,OFFSET I_PY
                CALL    S_INDEX_BUILD
                CMP     AX,1
                JE      L_IO_DONE
L_IO_FREE:
                MOV     DX,I_HANDLE
                MOV     AH,0AH
                CALL    T_XMS
                MOV     I_HANDLE,0
L_IO_DONE:
                RET
S_INDEX_OPEN    ENDP

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

; AX mask, BX packed keys, SI inclusive cursor, DI exclusive boundary.
; CF=0 handled, CF=1 use the unchanged linear scanner. Preserve its order,
; candidate count, paging cursor, and reverse STOSW direction.
S_INDEX_SEARCH  PROC    NEAR
                CMP     I_HANDLE,0
                JE      L_IS_FALLBACK
                CMP     T_BUSY,0
                JNE     L_IS_FALLBACK
                PUSH    BP
                MOV     BP,OFFSET I_SW
                PUSH    AX
                MOV     AX,D_2BD6
                CMP     AX,D_SW
                JE      L_IS_TABLE
                MOV     BP,OFFSET I_PY
                CMP     AX,D_PY
                JE      L_IS_TABLE
                POP     AX
                POP     BP
L_IS_FALLBACK:
                STC
                RET
L_IS_TABLE:
                POP     AX
                PUSHF
                CLI
                MOV     T_BUSY,1
                MOV     T_PAGE,-1
                MOV     I_PAGE,-1
                POPF
                MOV     I_MASK,AX
                MOV     I_QUERY,BX
                AND     I_QUERY,AX
                TEST    AH,80H
                JZ      L_IS_KEYS
                OR      I_QUERY,8000H
L_IS_KEYS:
                MOV     I_START,SI
                PUSH    BX
                PUSH    DX
                AND     BX,1FH
                SHL     BX,1
                ADD     BP,BX
                MOV     AX,DS:[BP]
                MOV     DX,DS:[BP+2]
                MOV     I_STEP,4
                PUSHF
                POP     BX
                TEST    BX,400H
                JZ      L_IS_RANGE
                XCHG    AX,DX
                SUB     AX,4
                SUB     DX,4
                MOV     I_STEP,-4
L_IS_RANGE:
                MOV     I_CURSOR,AX
                MOV     I_LIMIT,DX
L_IS_LOOP:
                MOV     BX,I_CURSOR
                CMP     BX,I_LIMIT
                JE      L_IS_DONE
                MOV     AX,BX
                AND     AX,0FC00H
                CMP     AX,I_PAGE
                JE      L_IS_CACHED
                PUSH    CX
                PUSH    SI
                PUSH    DI
                MOV     DI,AX
                MOV     SI,OFFSET T_CACHE
                MOV     CX,I_LENGTH
                SUB     CX,DI
                CMP     CX,1024
                JBE     L_IS_SIZE
                MOV     CX,1024
L_IS_SIZE:
                XOR     AX,AX
                CALL    S_INDEX_MOVE
                MOV     I_PAGE,DI
                POP     DI
                POP     SI
                POP     CX
                CMP     AX,1
                JNE     L_IS_FAILED
L_IS_CACHED:
                AND     BX,3FFH
                MOV     SI,WORD PTR T_CACHE[BX]
                CMP     I_STEP,0
                JL      L_IS_BACK
                CMP     SI,I_START
                JB      L_IS_NEXT
                CMP     SI,DI
                JAE     L_IS_DONE
                JMP     SHORT L_IS_MATCH
L_IS_BACK:
                CMP     SI,I_START
                JA      L_IS_NEXT
                CMP     SI,DI
                JBE     L_IS_DONE
L_IS_MATCH:
                MOV     AX,WORD PTR T_CACHE[BX+2]
                AND     AX,I_MASK
                CMP     AX,I_QUERY
                JNE     L_IS_NEXT
                CALL    S_A2D9
L_IS_NEXT:
                MOV     AX,I_STEP
                ADD     I_CURSOR,AX
                JMP     L_IS_LOOP
L_IS_FAILED:
                MOV     T_FAULT,1
L_IS_DONE:
                MOV     SI,DI
                MOV     T_BUSY,0
                POP     DX
                POP     BX
                POP     BP
                CLC
                RET
S_INDEX_SEARCH  ENDP

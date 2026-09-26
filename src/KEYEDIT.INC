; Optional adaptation for byte-oriented editors using INT 16h and a BIOS
; cursor. Never edit application text or video RAM. A second key is offered only
; after the application demonstrably consumed one byte of a displayed pair.
D_EDIT          DB 0
D_ESTATE        DB 0             ; 0 idle, 1 awaiting update, 2 key ready
D_EFIRST        DB 0             ; Delete at a trail starts with Backspace
D_ENEXT         DW 0
D_ECUR          DW 0
D_EOLD          DW 0
D_EOFF          DW 0
D_ESEG          DW 0
D_EDEL          DW 0             ; 0FFFFh for cursor movement
D_EROW          DB 80 DUP (0)

; DS=CS; caller has saved all registers except AX. CF=1: key returned, ZF=0.
; CF=0: continue the original handler with its original AX.
S_EDIT PROC NEAR
        CMP D_EDIT,0
        JE ED_PASS
        CMP AH,0
        JE ED_REQUEST
        CMP AH,10H
        JE ED_REQUEST
        CMP AH,1
        JE ED_REQUEST
        CMP AH,11H
        JNE ED_PASS
ED_REQUEST:
        MOV BP,AX
        CMP D_ESTATE,1
        JNE ED_READY
        CALL S_EVERIFY
ED_READY:
        CMP D_ESTATE,2
        JNE ED_READ
        MOV AX,D_ENEXT
        TEST BP,0100H
        JNZ ED_RETURN
        MOV D_ESTATE,0
ED_RETURN:
        OR AX,AX
        STC
        RET
ED_READ:
        MOV AX,BP
        TEST AH,1
        JZ ED_CONSUME
        CALL S_INT16_1
        JZ ED_EMPTY
        CALL S_EPEEK
        JMP SHORT ED_RETURN
ED_EMPTY:
        MOV AX,BP
        JMP SHORT ED_PASS
ED_CONSUME:
        ; A consumer reading ahead cannot receive a delayed companion later.
        MOV D_ESTATE,0
        PUSHF
        CALL CS:D_INT16
        PUSH AX
        CALL S_ESTART
        POP AX
        ; S_ESTART can replace Delete at a trail by Backspace, then Delete.
        CMP D_ESTATE,1
        JNE ED_RETURN
        CMP D_EFIRST,1
        JNE ED_RETURN
        MOV AX,0E08H
        JMP SHORT ED_RETURN
ED_PASS:
        CLC
        RET
S_EDIT ENDP

; Some programs use the status key value and discard the subsequent read.
; Normalize both interfaces, but never arm a companion just from a peek.
S_EPEEK PROC NEAR
        CMP AH,53H
        JNE EP_DONE
        CMP AL,0
        JE EP_CHECK
        CMP AL,0E0H
        JNE EP_DONE
EP_CHECK:
        PUSH AX
        PUSH BP
        CALL S_ECURSOR
        JC EP_ORIGINAL
        MOV AX,1410H
        XOR BX,BX
        INT 10H
        CMP BX,4B48H
        JNE EP_ORIGINAL
        CMP AX,2
        JNE EP_ORIGINAL
        POP BP
        POP AX
        MOV AX,0E08H
        RET
EP_ORIGINAL:
        POP BP
        POP AX
EP_DONE:
        RET
S_EPEEK ENDP

; BIOS-visible, unmodified, page-zero cursor in HHBIOS's 80x25 text view.
S_ECURSOR PROC NEAR
        MOV BX,40H
        MOV ES,BX
        TEST BYTE PTR ES:[17H],0FH
        JNZ EC_NO
        CMP BYTE PTR ES:[62H],0
        JNE EC_NO
        CMP WORD PTR ES:[4AH],80
        JNE EC_NO
        TEST BYTE PTR ES:[61H],20H
        JNZ EC_NO
        MOV DX,ES:[50H]
        CMP DH,25
        JAE EC_NO
        CMP DL,80
        JAE EC_NO
        MOV AX,1410H
        XOR BX,BX
        INT 10H
        CMP BX,4B48H
        JNE EC_NO
        JCXZ EC_NO
        MOV ES,CX
        CLC
        RET
EC_NO:
        STC
        RET
S_ECURSOR ENDP

S_ESTART PROC NEAR
        MOV D_EFIRST,0
        MOV DI,AX
        CMP AX,0E08H
        JE ES_KEY
        CMP AL,0
        JE ES_EXT
        CMP AL,0E0H
        JNE ES_DONE
ES_EXT:
        CMP AH,4BH
        JE ES_KEY
        CMP AH,4DH
        JE ES_KEY
        CMP AH,53H
        JNE ES_DONE
ES_KEY:
        CALL S_ECURSOR
        JC ES_DONE
        MOV D_ECUR,DX
        MOV D_EOLD,DX
        MOV AX,DI
        MOV D_ENEXT,AX
        MOV D_EDEL,0FFFFH
        CMP AH,4BH
        JE ES_LEFT
        CMP AH,0EH
        JNE ES_QUERY
ES_LEFT:
        OR DL,DL
        JZ ES_DONE
        DEC DL
ES_QUERY:
        PUSH DI
        PUSH DX
        MOV AX,1410H
        XOR BX,BX
        INT 10H
        POP DX
        POP DI
        CMP BX,4B48H
        JNE ES_DONE
        OR AX,AX
        JZ ES_DONE
        MOV CX,AX
        MOV AX,DI
        CMP AH,4BH
        JE ES_BACK
        CMP AH,0EH
        JE ES_BACK
        CMP CX,1
        JE ES_FORWARD
        CMP AH,53H
        JNE ES_DONE
        ; Cursor was placed between halves (mouse, vertical movement, etc.).
        DEC DL
        MOV D_EFIRST,1
        JMP SHORT ES_DELETE
ES_FORWARD:
        CMP AH,53H
        JE ES_DELETE
        INC D_ECUR
        JMP SHORT ES_SNAPSHOT
ES_BACK:
        CMP CX,2
        JE ES_BACK2
        CMP AH,0EH
        JNE ES_DONE
        MOV D_ENEXT,5300H
        TEST BP,1000H
        JZ ES_BACK2
        MOV D_ENEXT,53E0H
ES_BACK2:
        DEC D_ECUR
        CMP AH,4BH
        JE ES_SNAPSHOT
ES_DELETE:
        XOR BH,BH
        MOV BL,DL
        MOV D_EDEL,BX
        CMP AH,53H
        JNE ES_SNAPSHOT
        CMP CX,2
        JNE ES_SNAPSHOT
        DEC D_ECUR
ES_SNAPSHOT:
        MOV AL,160
        MUL DH
        MOV D_EOFF,AX
        MOV SI,AX
        MOV D_ESEG,ES
        MOV BX,OFFSET D_EROW
        MOV CX,80
ES_COPY:
        MOV AL,ES:[SI]
        MOV [BX],AL
        ADD SI,2
        INC BX
        LOOP ES_COPY
        MOV D_ESTATE,1
ES_DONE:
        RET
S_ESTART ENDP

; Compare the application's update before exposing the companion key.
S_EVERIFY PROC NEAR
        CALL S_ECURSOR
        JC EV_CANCEL
        MOV AX,ES
        CMP AX,D_ESEG
        JNE EV_CANCEL
        CMP DX,D_EOLD
        JNE EV_UPDATED
        ; Empty polling before the application's update is not consumption.
        CALL S_ESAME
        JC EV_DONE
EV_UPDATED:
        CMP DX,D_ECUR
        JNE EV_CANCEL
        MOV BX,D_EDEL
        CMP BX,0FFFFH
        JNE EV_DELETE
        CALL S_ESAME
        JNC EV_CANCEL
        JMP SHORT EV_YES
EV_DELETE:
        MOV CX,1
        CALL S_ESHIFT
        JNC EV_CANCEL
        ; A native DBCS deletion or an ambiguous update must not be doubled.
        MOV CX,2
        CALL S_ESHIFT
        JC EV_CANCEL
EV_YES:
        MOV D_ESTATE,2
EV_DONE:
        RET
EV_CANCEL:
        MOV D_ESTATE,0
        RET
S_EVERIFY ENDP

S_ESAME PROC NEAR
        XOR BX,BX
        MOV SI,D_EOFF
EM_LOOP:
        MOV AL,ES:[SI]
        CMP AL,D_EROW[BX]
        JNE EM_NO
        ADD SI,2
        INC BX
        CMP BX,80
        JB EM_LOOP
        STC
        RET
EM_NO:
        CLC
        RET
S_ESAME ENDP

; CF=1 iff the row underwent exactly CX (1 or 2) byte deletions at D_EDEL.
; A fixed right border is allowed: the shifted field ends in spaces, with
; the rest of the row unchanged. Attributes are deliberately not consulted.
S_ESHIFT PROC NEAR
        MOV SI,D_EOFF
        MOV BX,79
ET_LAST:
        MOV DI,BX
        SHL DI,1
        ADD DI,SI
        MOV AL,ES:[DI]
        CMP AL,D_EROW[BX]
        JNE ET_FOUND
        DEC BX
        JNS ET_LAST
        JMP SHORT ET_NO
ET_FOUND:
        INC BX
        SUB BX,CX
        JC ET_NO
        CMP BX,D_EDEL
        JB ET_NO
        MOV DX,BX
        XOR BX,BX
ET_PREFIX:
        CMP BX,D_EDEL
        JAE ET_SHIFT
        MOV AL,ES:[SI]
        CMP AL,D_EROW[BX]
        JNE ET_NO
        INC BX
        ADD SI,2
        JMP SHORT ET_PREFIX
ET_SHIFT:
        CMP BX,DX
        JAE ET_SPACES
        MOV DI,BX
        ADD DI,CX
        MOV AL,ES:[SI]
        CMP AL,D_EROW[DI]
        JNE ET_NO
        INC BX
        ADD SI,2
        JMP SHORT ET_SHIFT
ET_SPACES:
        CMP BYTE PTR ES:[SI],' '
        JNE ET_NO
        ADD SI,2
        LOOP ET_SPACES
        STC
        RET
ET_NO:
        CLC
        RET
S_ESHIFT ENDP

; One status row lists every system command. Left and Right change the
; highlighted command. Enter runs it. Esc closes the row. The words on
; that row are the mouse targets for the same four actions.
S_CDKZ PROC NEAR
        PUSH    DS
        PUSH    CS
        POP     DS
        CLD
        MOV     D_MENU_ITEM,1
        MOV     D_MENU_BTN,0FFH
L_CD_DRAW:
        CALL    S_MENU_DRAW
L_CD_WAIT:
        CALL    S_MENU_POLL
        CMP     AL,0FFH
        JE      L_CD_WAIT
        CMP     AL,0
        JE      L_CD_DRAW
        CMP     AL,1BH
        JE      L_CD_ESC
        CALL    S_1404
        MOV     AL,D_MENU_ITEM
        POP     DS
        RET
L_CD_ESC:
        CALL    S_1404
        MOV     AL,1BH
        POP     DS
        RET
S_CDKZ ENDP

; AL=0FFh nothing, AL=0 redraw, AL=0Dh run, AL=1Bh close.
S_MENU_POLL PROC NEAR
        CALL    S_MENU_MOUSE_READY
        JZ      L_POLL_BLOCK
        CALL    S_INT16_1
        JZ      L_POLL_MOUSE
        CALL    S_INT16
        JMP     S_MENU_KEY
L_POLL_MOUSE:
        CALL    S_MENU_MOUSE
        CMP     AL,0FFH
        JNE     L_POLL_DONE
        STI
        HLT
L_POLL_DONE:
        RET
L_POLL_BLOCK:
        CALL    S_INT16
        JMP     S_MENU_KEY
S_MENU_POLL ENDP

S_MENU_KEY PROC NEAR
        CMP     AL,1BH
        JE      L_KEY_RET
        CMP     AL,0DH
        JE      L_KEY_RET
        CMP     AH,4BH
        JE      L_KEY_PREV
        CMP     AH,4DH
        JE      L_KEY_NEXT
        MOV     AL,0FFH
L_KEY_RET:
        RET
L_KEY_PREV:
        DEC     D_MENU_ITEM
        JNZ     L_KEY_MOVED
        MOV     D_MENU_ITEM,14
L_KEY_MOVED:
        XOR     AL,AL
        RET
L_KEY_NEXT:
        INC     D_MENU_ITEM
        CMP     D_MENU_ITEM,14
        JBE     L_KEY_MOVED
        MOV     D_MENU_ITEM,1
        JMP     L_KEY_MOVED
S_MENU_KEY ENDP

S_MENU_MOUSE_READY PROC NEAR
        PUSH    ES
        XOR     AX,AX
        MOV     ES,AX
        MOV     AX,ES:[0CCH]
        OR      AX,ES:[0CEH]
        POP     ES
        RET
S_MENU_MOUSE_READY ENDP

; Sample INT 33h. A press on the prompt row hits one word.
S_MENU_MOUSE PROC NEAR
        MOV     AX,3
        INT     33H
        PUSH    CS
        POP     DS
        MOV     SI,BX
        MOV     DI,CX
        MOV     BP,DX
        CMP     D_MENU_BTN,0FFH
        JNE     L_MS_EDGE
        XOR     AL,AL
        TEST    SI,3
        JZ      L_MS_ARM
        MOV     AL,1
L_MS_ARM:
        MOV     D_MENU_BTN,AL
        MOV     AL,0FFH
        RET
L_MS_EDGE:
        TEST    SI,3
        JNZ     L_MS_DOWN
        MOV     D_MENU_BTN,0
        MOV     AL,0FFH
        RET
L_MS_DOWN:
        CMP     D_MENU_BTN,0
        JZ      L_MS_NEW
        MOV     AL,0FFH
        RET
L_MS_NEW:
        MOV     D_MENU_BTN,1
        CALL    S_MENU_POINT
        JC      L_MS_HIT
        MOV     AL,0FFH
        RET
L_MS_HIT:
        TEST    SI,2
        JZ      L_MS_LEFT
        MOV     AL,1BH
        RET
L_MS_LEFT:
        CMP     AX,9
        JB      L_MS_NONE
        CMP     AX,14
        JA      L_MS_NOT_PREV
        JMP     L_KEY_PREV
L_MS_NOT_PREV:
        CMP     AX,16
        JB      L_MS_NONE
        CMP     AX,27
        JBE     L_MS_RUN
        CMP     AX,29
        JB      L_MS_NONE
        CMP     AX,34
        JA      L_MS_NOT_NEXT
        JMP     L_KEY_NEXT
L_MS_NOT_NEXT:
        CMP     AX,36
        JB      L_MS_NONE
        CMP     AX,39
        JBE     L_MS_RUN
        CMP     AX,41
        JB      L_MS_NONE
        CMP     AX,44
        JBE     L_MS_CLOSE
L_MS_NONE:
        MOV     AL,0FFH
        RET
L_MS_RUN:
        MOV     AL,0DH
        RET
L_MS_CLOSE:
        MOV     AL,1BH
        RET
S_MENU_MOUSE ENDP

; CF=1 and AX=column when the pointer is on the prompt row.
S_MENU_POINT PROC NEAR
        PUSH    DI
        PUSH    BP
        MOV     AX,1406H
        INT     10H
        POP     BP
        POP     DI
        PUSH    CS
        POP     DS
        MOV     AL,BH
        XOR     AH,AH
        MOV     SI,AX
        MOV     AL,CH
        XOR     AH,AH
        MOV     BX,AX
        MOV     AX,BP
        XOR     DX,DX
        MOV     CX,8
        DIV     CX
        CMP     AX,SI
        JE      L_POINT_COL
        CMP     BX,8
        JB      L_POINT_MISS
        MOV     AX,BP
        XOR     DX,DX
        MOV     CX,BX
        DIV     CX
        CMP     AX,SI
        JNE     L_POINT_MISS
L_POINT_COL:
        MOV     AX,DI
        XOR     DX,DX
        MOV     CX,8
        DIV     CX
        STC
        RET
L_POINT_MISS:
        CLC
        RET
S_MENU_POINT ENDP

S_MENU_DRAW PROC NEAR
        CALL    S_1400
        XOR     DL,DL
        CALL    S_1402
        MOV     BL,D_TUX1
        MOV     SI,OFFSET D_MENU_TITLE
        MOV     CX,9
        CALL    S_MENU_PUT
        MOV     BL,D_TUX1
        MOV     SI,OFFSET D_MENU_PREV
        MOV     CX,7
        CALL    S_MENU_PUT
        MOV     DL,'['
        CALL    S_1403
        MOV     AL,D_MENU_ITEM
        DEC     AL
        MOV     AH,10
        MUL     AH
        ADD     AX,OFFSET D_MENU_NAMES
        MOV     SI,AX
        MOV     CX,10
        MOV     BL,D_QTS1
        CALL    S_MENU_PUT
        MOV     BL,D_TUX1
        MOV     SI,OFFSET D_MENU_MARK
        MOV     CX,2
        CALL    S_MENU_PUT
        MOV     BL,D_TUX1
        MOV     SI,OFFSET D_MENU_NEXT
        MOV     CX,7
        CALL    S_MENU_PUT
        MOV     BL,D_TUX1
        MOV     SI,OFFSET D_MENU_RUN
        MOV     CX,5
        CALL    S_MENU_PUT
        MOV     BL,D_TUX1
        MOV     SI,OFFSET D_MENU_CLOSE
        MOV     CX,4
        CALL    S_MENU_PUT
        MOV     CX,23
L_MENU_PAD:
        MOV     BL,D_TUX1
        MOV     DL,' '
        PUSH    CX
        CALL    S_1403
        POP     CX
        LOOP    L_MENU_PAD
        MOV     AL,D_MENU_ITEM
        AAM
        ADD     AX,3030H
        MOV     BL,D_TUX1
        MOV     DL,AH
        PUSH    AX
        CALL    S_1403
        POP     AX
        MOV     BL,D_TUX1
        MOV     DL,AL
        CALL    S_1403
        MOV     DL,'/'
        CALL    S_1403
        MOV     DL,'1'
        CALL    S_1403
        MOV     DL,'4'
        CALL    S_1403
        RET
S_MENU_DRAW ENDP

S_MENU_PUT PROC NEAR
        JCXZ    L_PUT_DONE
L_PUT:
        LODSB
        PUSH    CX
        PUSH    SI
        PUSH    BX
        MOV     DL,AL
        CALL    S_1403
        POP     BX
        POP     SI
        POP     CX
        LOOP    L_PUT
L_PUT_DONE:
        RET
S_MENU_PUT ENDP

; Idle title text. The input-method name is ordinary status text.
S_IDLE_PANEL PROC NEAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        XOR     DL,DL
        CALL    S_1402
        MOV     CX,8
        MOV     BL,D_TUX1
L_IDLE_CLEAR:
        MOV     DL,' '
        CALL    S_1403
        LOOP    L_IDLE_CLEAR
        MOV     DL,1
        CALL    S_1402
        CALL    S_A24A
        CALL    S_A24E
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET
S_IDLE_PANEL ENDP

D_MENU_ITEM DB 1
D_MENU_BTN  DB 0
D_MENU_TITLE DB 0CFH,0B5H,0CDH,0B3H,0B2H,0CBH,0B5H,0A5H,020H
D_MENU_PREV  DB 0C9H,0CFH,0D2H,0BBH,0CFH,0EEH,020H
D_MENU_NEXT  DB 0CFH,0C2H,0D2H,0BBH,0CFH,0EEH,020H
D_MENU_RUN   DB 0D6H,0B4H,0D0H,0D0H,020H
D_MENU_CLOSE DB 0B9H,0D8H,0B1H,0D5H
D_MENU_MARK  DB 05DH,020H
D_MENU_NAMES:
        DB 0B9H,0E2H,0B1H,0EAH,0BFH,0AAH,0B9H,0D8H,020H,020H ; cursor
        DB 0CCH,0D8H,0CFH,0D4H,0D7H,0D6H,0B7H,0FBH,0B4H,0AEH ; special display
        DB 0BCH,0F2H,0B7H,0B1H,0C7H,0D0H,0BBH,0BBH,020H,020H ; traditional
        DB 0CDH,0CBH,0B3H,0F6H,0BAH,0BAH,0D7H,0D6H,020H,020H ; exit Chinese
        DB 0B3H,0A4H,0B3H,0C7H,0BCH,0FCH,0C5H,0CCH,020H,020H ; Great Wall keys
        DB 0C1H,0AAH,0CFH,0EBH,0BFH,0AAH,0B9H,0D8H,020H,020H ; association
        DB 0D6H,0B1H,0BDH,0D3H,0D0H,0B4H,0C6H,0C1H,020H,020H ; direct write
        DB 0B4H,0F2H,0D3H,0A1H,0D7H,0D6H,0B7H,0FBH,0B4H,0AEH ; print string
        DB 0CFH,0D4H,0CAH,0BEH,0C4H,0A3H,0CAH,0BDH,020H,020H ; mode name
        DB 0D6H,0D8H,0BBH,0E6H,0C6H,0C1H,0C4H,0BBH,020H,020H ; redraw
        DB 0C6H,0B4H,0D2H,0F4H,0B4H,0CAH,0D7H,0E9H,020H,020H ; pinyin phrases
        DB 0D7H,0D6H,0B5H,0E4H,0B7H,0BDH,0CAH,0BDH,020H,020H ; dictionary
        DB 0D6H,0D8H,0C2H,0EBH,0CCH,0E1H,0CAH,0BEH,020H,020H ; duplicate prompt
        DB 0B3H,0A3H,0D7H,0A4H,0CCH,0E1H,0CAH,0BEH,0D0H,0D0H ; keep the status row

; Several commands share the status row. Left, Right, and the pointer
; move the selection. Enter or a left click runs it. Esc or the right
; button leaves. Unselected text is black on bright cyan; the selected
; command is black on yellow.
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

; Pointer movement selects a visible command. A new left press runs it.
; A new right press leaves. The first sample only records the buttons.
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
        PUSH    SI
        CALL    S_MENU_POINT
        POP     SI
        JC      L_MS_ON
        TEST    SI,3
        JNZ     L_MS_AWAY
        MOV     D_MENU_BTN,0
L_MS_AWAY:
        MOV     AL,0FFH
        RET
L_MS_ON:
        CALL    S_MENU_SLOT
        PUSHF
        PUSH    AX
        TEST    SI,3
        JNZ     L_MS_HELD
        MOV     D_MENU_BTN,0
        JMP     L_MS_HOVER
L_MS_HELD:
        CMP     D_MENU_BTN,0
        JNE     L_MS_HOVER
        MOV     D_MENU_BTN,1
        TEST    SI,2
        JZ      L_MS_LEFT
        POP     AX
        POPF
        MOV     AL,1BH
        RET
L_MS_LEFT:
        POP     AX
        POPF
        JNC     L_MS_NONE
        MOV     D_MENU_ITEM,AL
        MOV     AL,0DH
        RET
L_MS_HOVER:
        POP     AX
        POPF
        JNC     L_MS_NONE
        CMP     AL,D_MENU_ITEM
        JE      L_MS_NONE
        MOV     D_MENU_ITEM,AL
        XOR     AL,AL
        RET
L_MS_NONE:
        MOV     AL,0FFH
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

; AL=first visible command. Seven names stay on the row.
S_MENU_ORIGIN PROC NEAR
        MOV     AL,D_MENU_ITEM
        CMP     AL,4
        JBE     L_ORIGIN_HEAD
        CMP     AL,11
        JB      L_ORIGIN_MID
        MOV     AL,8
        RET
L_ORIGIN_HEAD:
        MOV     AL,1
        RET
L_ORIGIN_MID:
        SUB     AL,3
        RET
S_MENU_ORIGIN ENDP

; AX=column. CF=1 and AL=command when that column is one of the seven names.
S_MENU_SLOT PROC NEAR
        CMP     AX,76
        JA      L_SLOT_MISS
        XOR     DX,DX
        MOV     CX,11
        DIV     CX
        CMP     DX,10
        JAE     L_SLOT_MISS
        PUSH    AX
        CALL    S_MENU_ORIGIN
        POP     BX
        ADD     AL,BL
        STC
        RET
L_SLOT_MISS:
        CLC
        RET
S_MENU_SLOT ENDP

S_MENU_DRAW PROC NEAR
        CALL    S_1400
        XOR     DL,DL
        CALL    S_1402
        CALL    S_MENU_ORIGIN
        MOV     D_MENU_WALK,AL
        MOV     D_MENU_LEFT,7
L_DRAW_NAME:
        MOV     AL,D_MENU_WALK
        MOV     BL,0B0H
        CMP     AL,D_MENU_ITEM
        JNE     L_DRAW_COLOR
        MOV     BL,0E0H
L_DRAW_COLOR:
        DEC     AL
        MOV     AH,10
        MUL     AH
        ADD     AX,OFFSET D_MENU_NAMES
        MOV     SI,AX
        MOV     CX,10
        CALL    S_MENU_PUT
        DEC     D_MENU_LEFT
        JZ      L_DRAW_PAD
        MOV     BL,0B0H
        MOV     DL,' '
        CALL    S_1403
        INC     D_MENU_WALK
        JMP     L_DRAW_NAME
L_DRAW_PAD:
        MOV     CX,4
L_DRAW_GAP:
        MOV     BL,0B0H
        MOV     DL,' '
        PUSH    CX
        CALL    S_1403
        POP     CX
        LOOP    L_DRAW_GAP
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
D_MENU_WALK DB 1
D_MENU_LEFT DB 0
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

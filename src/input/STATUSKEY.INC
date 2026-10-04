; Digit keys on the status row. The row lists four groups. A group digit
; replaces it with that group's numbered commands, and a second digit runs
; the command. Esc steps back one level. The row uses the normal prompt color.
S_CDKZ PROC NEAR
        PUSH    DS
        PUSH    CS
        POP     DS
        CLD
        MOV     D_MENU_GROUP,0
L_CD_DRAW:
        CALL    S_MENU_DRAW
L_CD_WAIT:
        CALL    S_INT16
        CALL    S_MENU_KEY
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
S_MENU_KEY PROC NEAR
        PUSH    CS
        POP     DS
        CMP     AL,1BH
        JE      L_KEY_ESC
        CMP     AL,'1'
        JB      L_KEY_IGN
        CMP     AL,'9'
        JA      L_KEY_IGN
        SUB     AL,'0'
        CMP     D_MENU_GROUP,0
        JE      L_KEY_GROUP
        MOV     BL,D_MENU_GROUP
        DEC     BL
        XOR     BH,BH
        CMP     AL,D_MENU_LEN[BX]
        JA      L_KEY_IGN
        DEC     AL
        ADD     AL,D_MENU_OFF[BX]
        MOV     BL,AL
        XOR     BH,BH
        MOV     AL,D_MENU_MAP[BX]
        MOV     D_MENU_ITEM,AL
        MOV     AL,0DH
        RET
L_KEY_GROUP:
        CMP     AL,4
        JA      L_KEY_IGN
        MOV     D_MENU_GROUP,AL
        XOR     AL,AL
        RET
L_KEY_ESC:
        CMP     D_MENU_GROUP,0
        JNE     L_KEY_BACK
        MOV     AL,1BH
        RET
L_KEY_BACK:
        MOV     D_MENU_GROUP,0
        XOR     AL,AL
        RET
L_KEY_IGN:
        MOV     AL,0FFH
        RET
S_MENU_KEY ENDP

S_MENU_DRAW PROC NEAR
        CALL    S_1400
        XOR     DL,DL
        CALL    S_1402
        MOV     BL,D_MENU_GROUP
        XOR     BH,BH
        MOV     CL,D_MENU_LLEN[BX]
        XOR     CH,CH
        PUSH    CX
        ADD     BX,BX
        MOV     SI,D_MENU_LINES[BX]
        MOV     BL,D_TUX1
        CALL    S_MENU_PUT
        POP     CX
        MOV     AX,80
        SUB     AX,CX
        MOV     CX,AX
        JCXZ    L_DRAW_DONE
L_DRAW_PAD:
        MOV     BL,D_TUX1
        MOV     DL,' '
        PUSH    CX
        CALL    S_1403
        POP     CX
        LOOP    L_DRAW_PAD
L_DRAW_DONE:
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

D_MENU_GROUP DB 0
D_MENU_ITEM DB 1
D_MENU_OFF  DB 0,5,11,13
D_MENU_LEN  DB 5,6,2,1
D_MENU_MAP  DB 5,6,11,12,13, 1,3,9,7,10,14, 2,8, 4
D_MENU_LLEN DB 80,80,80,34,15
D_MENU_LINES DW OFFSET D_LINE0, OFFSET D_LINE1, OFFSET D_LINE2
        DW OFFSET D_LINE3, OFFSET D_LINE4
D_LINE0 DB 31H,20H,20H,20H,20H,20H,20H,0CAH,0E4H,0C8H,0EBH,20H
        DB 20H,20H,20H,20H,20H,20H,20H,20H,20H,20H,20H,32H
        DB 20H,20H,20H,20H,20H,20H,0CFH,0D4H,0CAH,0BEH,20H,20H
        DB 20H,20H,20H,20H,20H,20H,20H,20H,20H,20H,33H,20H
        DB 20H,20H,20H,20H,20H,0CAH,0E4H,0B3H,0F6H,20H,20H,20H
        DB 20H,20H,20H,20H,20H,20H,20H,20H,20H,34H,20H,20H
        DB 20H,20H,20H,20H,0CDH,0CBH,0B3H,0F6H
D_LINE1 DB 31H,20H,20H,20H,20H,20H,0B3H,0A4H,0B3H,0C7H,0BCH,0FCH
        DB 0C5H,0CCH,20H,20H,20H,20H,20H,20H,32H,20H,20H,20H
        DB 20H,20H,0C1H,0AAH,0CFH,0EBH,20H,20H,20H,20H,20H,20H
        DB 33H,20H,20H,20H,20H,20H,0C6H,0B4H,0D2H,0F4H,0B4H,0CAH
        DB 0D7H,0E9H,20H,20H,20H,20H,20H,34H,20H,20H,20H,20H
        DB 20H,0D7H,0D6H,0B5H,0E4H,20H,20H,20H,20H,20H,35H,20H
        DB 20H,20H,20H,20H,0D6H,0D8H,0C2H,0EBH
D_LINE2 DB 31H,20H,20H,20H,0B9H,0E2H,0B1H,0EAH,20H,20H,20H,20H
        DB 32H,20H,20H,20H,0BCH,0F2H,0B7H,0B1H,20H,20H,20H,20H
        DB 33H,20H,20H,20H,0CFH,0D4H,0CAH,0BEH,0C4H,0A3H,0CAH,0BDH
        DB 20H,20H,20H,20H,34H,20H,20H,20H,0D6H,0B1H,0BDH,0D3H
        DB 0D0H,0B4H,0C6H,0C1H,20H,20H,20H,35H,20H,20H,20H,0D6H
        DB 0D8H,0BBH,0E6H,20H,20H,20H,36H,20H,20H,20H,0B3H,0A3H
        DB 0D7H,0A4H,0CCH,0E1H,0CAH,0BEH,0D0H,0D0H
D_LINE3 DB 31H,20H,20H,20H,20H,20H,20H,0CCH,0D8H,0CFH,0D4H,20H
        DB 20H,20H,20H,20H,20H,20H,20H,20H,20H,20H,20H,32H
        DB 20H,20H,20H,20H,20H,20H,0B4H,0F2H,0D3H,0A1H
D_LINE4 DB 31H,20H,20H,20H,20H,20H,20H,0CDH,0CBH,0B3H,0F6H,0BAH
        DB 0BAH,0D7H,0D6H

; Menu navigation shares the existing selection and action dispatch.
; AX is the key; DH is the selection, CH the item count.
S_MENU_KEY PROC NEAR
        CMP     AL,'1'
        JB      L_MK_NAV
        CMP     AL,'9'
        JA      L_MK_NAV
        SUB     AL,'0'
        CMP     AL,CH
        JA      L_MK_DONE
        MOV     DH,AL
        MOV     AL,13
        RET
L_MK_NAV:
        CMP     AH,47H          ; Home
        JNE     L_MK_END
        CALL    S_A250
        MOV     DH,1
        RET
L_MK_END:
        CMP     AH,4FH          ; End
        JNE     L_MK_PREV
        CALL    S_A250
        MOV     DH,CH
        RET
L_MK_PREV:
        CMP     AH,49H          ; Page Up
        JNE     L_MK_NEXT
        MOV     AH,48H
        RET
L_MK_NEXT:
        CMP     AH,51H          ; Page Down
        JNE     L_MK_TAB
        MOV     AH,50H
        RET
L_MK_TAB:
        CMP     AL,9
        JNE     L_MK_DONE
        MOV     AH,4DH
L_MK_DONE:
        RET
S_MENU_KEY ENDP

; Frame requests are optional: older adapters ignore AX=1417h. Text and
; navigation use the same ten-column layout on every adapter.
S_MENU_FRAMES PROC NEAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        MOV     CL,CH
        XOR     CH,CH
        MOV     DX,0A00H
        MOV     BL,1
L_MENU_FRAMES:
        MOV     AX,1417H
        INT     10H
        INC     DL
        LOOP    L_MENU_FRAMES
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET
S_MENU_FRAMES ENDP

S_MENU_FRAME PROC NEAR
        PUSH    AX
        PUSH    BX
        PUSH    DX
        MOV     DL,DH
        DEC     DL
        MOV     DH,10
        MOV     BL,BH
        MOV     AX,1417H
        INT     10H
        POP     DX
        POP     BX
        POP     AX
        RET
S_MENU_FRAME ENDP

; Only the idle title has a padded input-method button. Composition keeps
; its original columns, including all candidate and input-code positions.
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
        MOV     DL,D_CZW
        CALL    S_1403
        CALL    S_A24E
        MOV     DX,0800H
        MOV     BL,1
        MOV     AX,1417H
        INT     10H
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET
S_IDLE_PANEL ENDP

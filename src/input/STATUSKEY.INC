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

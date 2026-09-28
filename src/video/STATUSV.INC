; The padded VGA status strip has six spare lines above and below its text.
; DI addresses its saved 30-line region; no application pixels are touched.
S_STATUS_BAND PROC NEAR
        MOV     CS:D_STATUS_CURSOR,0
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DI
        MOV     DX,3CEH
        MOV     AX,0005H
        OUT     DX,AX
        MOV     AX,0001H
        OUT     DX,AX
        MOV     AX,0003H
        OUT     DX,AX
        MOV     AX,0FF08H
        OUT     DX,AX
        MOV     BX,DI
        MOV     AH,CS:D_TUXS
        SHR     AH,1
        SHR     AH,1
        SHR     AH,1
        SHR     AH,1
        MOV     CX,30*80
        CALL    S_STATUS_FILL
        MOV     DI,BX
        MOV     AH,15
        MOV     CX,80
        CALL    S_STATUS_FILL
        LEA     DI,[BX+29*80]
        MOV     AH,8
        MOV     CX,80
        CALL    S_STATUS_FILL
        MOV     AX,0F02H
        OUT     DX,AX
        POP     DI
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET
S_STATUS_BAND ENDP

S_STATUS_FILL PROC NEAR
        MOV     DX,3C4H
        PUSH    AX
        MOV     AX,0F02H
        OUT     DX,AX
        POP     AX
        PUSH    DI
        PUSH    CX
        XOR     AL,AL
        REP     STOSB
        POP     CX
        POP     DI
        MOV     AL,2
        OUT     DX,AX
        MOV     AL,255
        REP     STOSB
        RET
S_STATUS_FILL ENDP

; AX=1417h: DL selects a ten-column slot, DH is its width (3..10),
; BL=1 raised, BL=2 pressed. Padding cells belong to the control's caller.
S_STATUS_PANEL:
        CMP     CS:D_0059,0
        JE      L_PANEL_DONE
        CMP     DL,8
        JAE     L_PANEL_DONE
        CMP     DH,3
        JB      L_PANEL_DONE
        CMP     DH,10
        JA      L_PANEL_DONE
        CMP     BL,1
        JB      L_PANEL_DONE
        CMP     BL,2
        JA      L_PANEL_DONE
        XOR     AX,AX
        MOV     AL,DH
        MOV     SI,AX
        MOV     AL,DL
        MOV     AH,10
        MUL     AH
        MOV     DL,AL
        MOV     DH,CS:D_0059
        CALL    S_SPDZ
        SUB     DI,4*80          ; y=452, four rows above the glyph
        MOV     BP,DI
        MOV     DX,3C4H
        MOV     AX,0F02H
        OUT     DX,AX
        MOV     DX,3CEH
        MOV     AX,0005H         ; write mode 0
        OUT     DX,AX
        MOV     AX,0003H
        OUT     DX,AX
        MOV     AX,0F01H         ; set/reset broadcasts to all planes
        OUT     DX,AX
        MOV     BH,15
        CMP     BL,2
        MOV     BL,0
        JNE     L_PANEL_COLORS
        MOV     BH,8
        MOV     BL,15
L_PANEL_COLORS:
        MOV     AH,BH
        CALL    S_PANEL_ROW
        LEA     DI,[BP+25*80]
        MOV     AH,BL
        CALL    S_PANEL_ROW
        LEA     DI,[BP+80]
        MOV     AX,0740H         ; inside highlight
        CMP     BL,15
        JNE     L_PANEL_INNER_TOP
        XOR     AH,AH
L_PANEL_INNER_TOP:
        CALL    S_PANEL_ROW
        LEA     DI,[BP+24*80]
        MOV     AH,8
        CMP     BL,15
        JNE     L_PANEL_INNER_BOTTOM
        MOV     AH,7
L_PANEL_INNER_BOTTOM:
        CALL    S_PANEL_ROW
        LEA     DI,[BP+80]
        MOV     AH,BH
        MOV     AL,40H
        CALL    S_PANEL_COLUMN
        LEA     DI,[BP+80]
        ADD     DI,SI
        DEC     DI
        MOV     AH,BL
        MOV     AL,2
        CALL    S_PANEL_COLUMN
        LEA     DI,[BP+2*80]
        MOV     AX,0720H
        CMP     BL,15
        JNE     L_PANEL_INNER_LEFT
        XOR     AH,AH
L_PANEL_INNER_LEFT:
        CALL    S_PANEL_COLUMN
        LEA     DI,[BP+2*80]
        ADD     DI,SI
        DEC     DI
        MOV     AX,0804H
        CMP     BL,15
        JNE     L_PANEL_INNER_RIGHT
        MOV     AH,7
L_PANEL_INNER_RIGHT:
        CALL    S_PANEL_COLUMN
        MOV     AX,0001H
        OUT     DX,AX
        MOV     AX,0FF08H
        OUT     DX,AX
L_PANEL_DONE:
        JMP     L_RET

; DI=first byte, SI=width in bytes, AH=color. Preserve neighboring pixels.
S_PANEL_ROW PROC NEAR
        MOV     AL,0
        OUT     DX,AX
        MOV     AX,7F08H
        OUT     DX,AX
        MOV     AL,ES:[DI]
        MOV     ES:[DI],AL
        INC     DI
        MOV     AX,0FF08H
        OUT     DX,AX
        MOV     CX,SI
        SUB     CX,2
        REP     STOSB
        MOV     AX,0FE08H
        OUT     DX,AX
        MOV     AL,ES:[DI]
        MOV     ES:[DI],AL
        RET
S_PANEL_ROW ENDP

; DI=top, AL=mask, AH=color. The inner columns are one scanline shorter.
S_PANEL_COLUMN PROC NEAR
        PUSH    AX
        MOV     AL,0
        OUT     DX,AX
        POP     AX
        MOV     AH,AL
        MOV     AL,8
        OUT     DX,AX
        MOV     CX,24
        TEST    AH,24H
        JZ      L_PANEL_PIXELS
        DEC     CX
L_PANEL_PIXELS:
        MOV     AL,ES:[DI]
        MOV     ES:[DI],AL
        ADD     DI,80
        LOOP    L_PANEL_PIXELS
        RET
S_PANEL_COLUMN ENDP

; Remember whether XOR ink exists. Hiding twice, or positioning after a
; hidden cursor, must not turn an old underline back on.
D_STATUS_CURSOR DB 0
S_STATUS_HIDE PROC NEAR
        CMP     CS:D_STATUS_CURSOR,0
        JE      L_STATUS_HIDDEN
        MOV     CS:D_STATUS_CURSOR,0
        JMP     S_TXGB
L_STATUS_HIDDEN:
        RET
S_STATUS_HIDE ENDP

S_STATUS_SHOW PROC NEAR
        CMP     CS:D_STATUS_CURSOR,0
        JNE     L_STATUS_VISIBLE
        MOV     CS:D_STATUS_CURSOR,1
        JMP     S_TXGB
L_STATUS_VISIBLE:
        RET
S_STATUS_SHOW ENDP

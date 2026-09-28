; The padded VGA status strip has six spare lines above and below its text.
; DI addresses its saved 30-line region; no application pixels are touched.
S_STATUS_BAND PROC NEAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DI
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

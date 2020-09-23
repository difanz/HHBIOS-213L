;	ZJXP.INC ´¦ÀíÖ±½ÓÐ´ÆÁÄ£¿é
;	1995.1.12, 1.18, 2.16
;	1996.1.19

D_ZBFS		DB	3		;=0´¿Î÷ÎÄ·½Ê½,=1²»´¦ÀíÖÆ±í·û
					;=2´¦Àí²¿·ÖÖÆ±í·û,=3´¦ÀíÈ«²¿ÖÆ±í·û
D_NUM		DB	0		;×Ö·ûÉÁË¸¼ÆÊý

;×Ó³ÌÐò:´¦ÀíÖ±½ÓÐ´ÆÁ
S_XR		PROC	NEAR
		CMP	CS:D_ZBFS,1		;=1²»´¦ÀíÖÆ±í·û
		JZ	L_XR10

		CMP	CS:D_ZBFS,2		;=2´¦Àí²¿·ÖÖÆ±í·û
		JZ	L_XR1
		CALL	S_SXSM			;ÊúÏòÉ¨Ãè
L_XR1:
		MOV	CX,25*80		;ÐéÆÁÇø³¤¶È
		XOR	SI,SI
L_XR2:
		LODSW				;È¡×Ö·û
		CMP	AL,0B0H 		;ÅÐÎ÷ÎÄÖÆ±í·û
		JB	L_XR9
		CMP	AL,0E0H
		JAE	L_XR9

		PUSH	SI			;Î÷ÎÄÖÆ±í·û´¦Àí
		PUSH	CX
		XOR	CX,CX			;			1.19
		MOV	DI,SI
L_XR3:
		INC	CX
		CMP	AL,[DI] 		;×Ö·ûÏàÍ¬?
		JNZ	L_XR3A
		ADD	DI,2
		JMP	SHORT L_XR3
L_XR3A:
		CMP	CX,4			;4¸öÒÔÉÏÊÇÎ÷ÎÄÖÆ±í·û
		JAE	L_XR4
		CMP	CX,1			;1¸ö
		JZ	L_XR5
		CMP	AL,0DFH 		;×¨ÎªFOXPROÉè 2-3¸öß
		JZ	L_XR4
		CMP	CX,2			;2¸ö
		JZ	L_XR5
		CMP	AL,0C4H 		;Ä ;Èý¸öÒ»Ñù
		JZ	L_XR4
		CMP	AL,0CDH 		;Í
		JNZ	L_XR5			;			1.18
L_XR4:
		CALL	S_LXZF			;×ª»»ÂëÐ´ÈëB800
		JMP	SHORT L_XR8
L_XR5:
		CALL	S_QTZF			;´¦ÀíÖÆ±í·û
L_XR8:
		POP	CX
		POP	SI
L_XR9:
		LOOP	L_XR2			;´¦ÀíÏÂÒ»¸ö×Ö·û
L_XR10:
		MOV	CX,25*80		;ÐéÆÁÇø³¤¶È
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_XPQ
		XOR	SI,SI
L_XR11:
		REPE	CMPSW			;±È½ÏÁ½¸öÇø
		JZ	L_XR12
		PUSH	DS
		PUSH	ES
		PUSH	CX
		PUSH	SI
		PUSH	DI
		SUB	SI,2
		MOV	AX,SI			;Ö¸Ïò²»Í¬µÄµÚÒ»¸ö×Ö·û
		SHR	AX,1
		MOV	DL,80
		DIV	DL			;Ã¿ÐÐ×Ö·ûÊý
		XCHG	AH,AL
		MOV	DX,AX			;µ±Ç°×Ö·ûÎ»ÖÃ
		LODSW				;È¡×Ö·û
		MOV	WORD PTR CS:D_XPQ[SI-2],AX
		MOV	CX,AX
		CALL	S_XRXS			;ÏÔÊ¾
		POP	DI
		POP	SI
		POP	CX
		POP	ES
		POP	DS
		OR	CX,CX
		JNZ	L_XR11			;Ã»Íê,¼ÌÐø
L_XR12:
		RET
S_XR		ENDP

D_ZBFB		DB	80H, 81H, 82H, 14H, 83H, 84H, 85H,0B7H
	;0B0H		°    ±	  ²    ³    ´	 µ    ¶    ·
		DB     0B8H, 86H, 15H, 87H, 88H,0BDH,0BEH, 89H
	;0B8H		·    ¹	  º    »    ¼	 ½    ¾    ¿
		DB	8AH, 8BH, 8CH, 8DH, 12H, 8EH, 8FH, 90H
	;0C0H		À    Á	  Â    Ã    Ä	 Å    Æ    Ç
		DB	91H, 92H, 93H, 94H, 95H, 13H, 96H, 97H
	;0C8H		È    É	  Ê    Ë    Ì	 Í    Î    Ï
		DB	98H, 99H, 9AH,0D3H,0D4H,0D5H,0D6H, 9BH
	;0D0H		Ð    Ñ	  Ò    Ó    Ô	 Õ    Ö    ×
		DB	9CH, 9DH, 9EH, 82H, 9FH, 82H, 82H,0A0H
	;0D8H		Ø    Ù	  Ú    Û    Ü	 Ý    Þ    ß

S_ZBF		PROC	NEAR
		MOV	BL,AL
		XOR	BH,BH
		MOV	BL,CS:D_ZBFB[BX-0B0H]
		RET
S_ZBF		ENDP

;×Ó³ÌÐò:´¦ÀíÖÆ±í·û
S_QTZF		PROC	NEAR
		CMP	CS:D_ZBFS,2		;´¦Àí²¿·ÖÖÆ±í·û
		JNZ	L_QT1
		RET
L_QT1:
		CMP	AL,0B2H 		;° ± ²			1.16
		JBE	L_QT11
		CMP	AL,0DBH 		;Û ß Ü
		JB	L_QT3
L_QT11:
		CALL	S_ZBF			;È¡×ª»»Âë
		MOV	DL,[SI] 		;ÓÒ±ß×Ö·û		1.16
		CMP	AL,DL
		JZ	L_QT12
		CMP	DL,BL			;ÅÐÒÑÊÇÖÆ±í·û?
		JNZ	L_QT13
L_QT12:
		MOV	DL,[SI-4]		;×ó±ß×Ö·û		1.16
		CMP	DL,BL			;ÅÐÒÑÊÇÖÆ±í·û?
		JZ	L_QT14
		CMP	AL,DL
		JNZ	L_QT13
		CMP	BYTE PTR [SI+2],0A0H	;ÓÒ±ßµÚ¶þ×Ö·ûÎªºº×Ö?	1.19
		JBE	L_QT14
L_QT13:
		RET
L_QT14:
		JMP	L_QT9
L_QT3:
		MOV	BL,AL
		XOR	BH,BH
		MOV	DL,CS:D_ZBF[BX-0B3H]	;È¡ÊôÐÔ
		XOR	BP,BP
		TEST	DL,30H			;ÅÐ×ó±ß?
		JZ	L_QT4
		MOV	CH,DL
		AND	CH,30H			;×ó±ß
		MOV	CL,4
		SHR	CH,CL
		MOV	BL,[SI-4]		;×ó±ß×Ö·û
	;	CMP	BL,11H			;
	;	JZ	L_QT3A
		CALL	S_QSX			;È¡ÊôÐÔ
		JC	L_QT4
		AND	DH,3			;ÓÒ±ß
		CMP	CH,DH			;ÅÐ?
		JNZ	L_QT4
		CMP	BL,0A0H 		;ÅÐÖÆ±í·û?
		JA	L_QT4
L_QT3A: 	CALL	L_QT9			;Ð´Èë
		INC	BP
L_QT4:
		TEST	DL,0CH			;ÅÐÉÏ±ß?
		JZ	L_QT5
		MOV	CH,DL
		AND	CH,0CH
		MOV	CL,4
		SHL	CH,CL
		MOV	BL,[SI-80*2-2]		;ÉÏ±ß×Ö·û
	;	CMP	BL,1EH			;
	;	JZ	L_QT4A
		CALL	S_QSX			;È¡ÊôÐÔ
		JC	L_QT5
		AND	DH,0C0H 		;ÏÂ±ß
		CMP	CH,DH			;ÅÐ?
		JNZ	L_QT5
		CMP	BL,0A0H 		;ÅÐÖÆ±í·û?
		JBE	L_QT44
		OR	BP,BP			;ÅÐÒÑÐ´ÈëÖÆ±í·û?
		JZ	L_QT5
		PUSH	SI
		PUSH	AX
		SUB	SI,80*2
		MOV	AL,BL
		CALL	L_QT9			;ÉÏ±ßÐ´Èë
		POP	AX
		POP	SI
		JMP	SHORT L_QT5
L_QT44:
		OR	BP,BP
		JNZ	L_QT5
L_QT4A:
		CALL	L_QT9			;Ð´Èë
		INC	BP
L_QT5:
		TEST	DL,3			;ÅÐÓÒ±ß?
		JZ	L_QT6
		MOV	CH,DL
		AND	CH,3
		MOV	CL,4
		SHL	CH,CL
		MOV	BL,[SI] 		;ÓÒ±ß×Ö·û
	;	CMP	BL,10H			;
	;	JZ	L_QT5A
		CALL	S_QSX			;È¡ÊôÐÔ
		JC	L_QT6
		AND	DH,30H			;×ó±ß
		CMP	CH,DH			;ÅÐ?
		JNZ	L_QT6
		CMP	BL,0A0H 		;ÅÐÖÆ±í·û?
		JA	L_QT6
		OR	BP,BP
		JNZ	L_QT6
L_QT5A:
		CALL	L_QT9			;Ð´Èë
		INC	BP
L_QT6:
		TEST	DL,0C0H 		;ÅÐÏÂ±ß?
		JZ	L_QT7
		MOV	CH,DL
		AND	CH,0C0H
		MOV	CL,4
		SHR	CH,CL
		MOV	BL,[SI+80*2-2]		;ÏÂ±ß×Ö·û
	;	CMP	BL,1FH			;
	;	JZ	L_QT9
		CMP	BL,0A0H
		JA	L_QT7
		CALL	S_QSX			;È¡ÊôÐÔ
		JC	L_QT7
		AND	DH,0CH			;ÉÏ±ß
		CMP	CH,DH			;ÅÐ?
		JZ	L_QT8
L_QT7:
		RET
L_QT8:
		OR	BP,BP
		JNZ	L_QT7
L_QT9:
		MOV	CX,1
;×Ó³ÌÐò:ÖÆ±í·û×ª»»ÂëÐ´ÈëB800
S_ZJZF:
		CMP	CX,4
		JB	L_ZJ0
		MOV	BL,AL			;ËÄ¸öÒÔÉÏÏàÍ¬
		CALL	S_QSX			;È¡ÊôÐÔ
		JB	L_ZJ0
		AND	DH,33H			;È¡×óÓÒÎ»
		CMP	DH,11H			;×óÓÒÏ¸Ïß?
		JZ	L_ZJ0
		CMP	DH,22H			;×óÓÒ´ÖÏß?
		JZ	L_ZJ0
		RET
L_ZJ0:
		CALL	S_ZBF			;È¡×ª»»Âë
		MOV	AL,BL
		MOV	ES,CS:D_B800		;B800Çø¶Î
		MOV	DI,SI
		SUB	DI,2
L_ZJ7:
		STOSB				;Ð´Èë×Ö·û
		INC	DI
		LOOP	L_ZJ7
L_ZJ8:
		RET
S_QTZF		ENDP

;×Ó³ÌÐò:Èý¸öÒÔÉÏÖÆ±í·ûÏò×ó²éÑ¯
S_LXZF		PROC	NEAR
		PUSH	CX
		MOV	BL,[SI-4]		;×ó±ß×Ö·û
		CMP	BL,0A0H 		;ÅÐºº×Ö?
		JBE	L_LX1
		CALL	S_QSX			;È¡ÊôÐÔ
		JB	L_LX1
		AND	DH,3

		MOV	BL,AL
		XOR	BH,BH
		MOV	DL,CS:D_ZBF[BX-0B3H]	;È¡ÊôÐÔ
		AND	DL,30H
		MOV	CL,4
		SHR	DL,CL

		CMP	DL,DH			;ÅÐ?
		JNZ	L_LX1
		PUSH	AX
		PUSH	SI
		SUB	SI,2
		MOV	AL,[SI-2]		;×ó±ß×Ö·û
		CALL	L_QT9			;Ð´Èë
		POP	SI
		POP	AX
L_LX1:
		POP	CX
		JMP	S_ZJZF
S_LXZF		ENDP

;×Ó³ÌÐò:È¡ÖÆ±í·ûBLÊôÐÔ->DH
S_QSX		PROC	NEAR
		PUSH	BX
		XOR	BH,BH
		CMP	BL,20H
		JB	L_QSX1
		CMP	BL,7FH
		JB	L_QSX0			;ASCII×Ö·û
		CMP	BL,0A0H
		JBE	L_QSX1			;ºº×ÖÄÚÂë
L_QSX00:
		CMP	BL,0B3H 		;ÅÐÖÆ±í·û?
		JB	L_QSX0
		CMP	BL,0DAH
		JBE	L_QSX3
L_QSX0:
		STC
		POP	BX
		RET
L_QSX1:
		MOV	DH,BL
		MOV	BX,0
L_QSX2:
		CMP	DH,CS:D_ZBFB[BX]
		JZ	L_QSX4
		INC	BX
		CMP	BL,48
		JB	L_QSX2
		JMP	SHORT L_QSX0
L_QSX4:
		ADD	BL,0B0H
		JMP	SHORT L_QSX00
L_QSX3:
		MOV	DH,CS:D_ZBF[BX-0B3H]
		CLC
		POP	BX
		RET
S_QSX		ENDP

;Î÷ÎÄÖÆ±í·ûÊôÐÔ×Ö½Ú
;	Î»67-ÏÂ, 45-×ó, 23-ÉÏ, 01-ÓÒ
;	Á½Î»=01µ¥Ïß, =10Ë«Ïß
D_ZBF		DB	01000100B,01010100B,01100100B,10011000B
	;		³ 0B3H	  ´ 0B4H    µ 0B5H    ¶ 0B6H
		DB	10010000B,01100000B,10101000B,10001000B
	;		· 0B7H	  ¸ 0B8H    ¹ 0B9H    º 0BAH
		DB	10100000B,00101000B,00011000B,00100100B
	;		» 0BBH	  ¼ 0BCH    ½ 0BDH    ¾ 0BEH
		DB	01010000B,00000101B,00010101B,01010001B
	;		¿ 0BFH	  À 0C0H    Á 0C1H    Â 0C2H
		DB	01000101B,00010001B,01010101B,01000110B
	;		Ã 0C3H	  Ä 0C4H    Å 0C5H    Æ 0C6H
		DB	10001001B,00001010B,10000010B,00101010B
	;		Ç 0C7H	  È 0C8H    É 0C9H    Ê 0CAH
		DB	10100010B,10001010B,00100010B,10101010B
	;		Ë 0CBH	  Ì 0CCH    Í 0CDH    Î 0CEH
		DB	00100110B,00011001B,01100010B,10010001B
	;		Ï 0CFH	  Ð 0D0H    Ñ 0D1H    Ò 0D2H
		DB	00001001B,00000110B,01000010B,10000001B
	;		Ó 0D3H	  Ô 0D4H    Õ 0D5H    Ö 0D6H
		DB	10011001B,01100110B,00010100B,01000001B
	;		× 0D7H	  Ø 0D8H    Ù 0D9H    Ú 0DAH

;×Ó³ÌÐò:ÊúÏòÉ¨Ãè
S_SXSM		PROC	NEAR
		XOR	SI,SI
		MOV	CX,80			;Ã¿ÐÐ×Ö·ûÊý
L_SX1:
		PUSH	SI
		PUSH	CX
		MOV	CX,25			;×î´óÐÐºÅ
L_SX2:
		MOV	AL,[SI]
		CMP	AL,0B3H 		;³
		JZ	L_SX3
		CMP	AL,0BAH 		;º
		JNZ	L_SX4
L_SX3:
		CALL	S_ZBF			;È¡×ª»»ÂëBL		1.18
		CALL	S_ZXSM
		OR	CX,CX
		JZ	L_SX5
L_SX4:
		ADD	SI,80*2
		LOOP	L_SX2
L_SX5:
		POP	CX
		POP	SI
		ADD	SI,2
		LOOP	L_SX1
		RET
S_SXSM		ENDP

;×Ó³ÌÐò:×ÝÏòÉ¨Ãè´¦Àí
S_ZXSM		PROC	NEAR
		XOR	DX,DX
		MOV	DI,SI
L_ZX1:
		INC	DX
		ADD	SI,80*2 		;ÏÂÒ»ÐÐ
		DEC	CX
		CMP	BL,DS:[SI]		;ÅÐ×ª»»Âë?
		JZ	L_ZX2
		CMP	AL,DS:[SI]		;ÅÐ×Ö·û?
		JNZ	L_ZX3
L_ZX2:
		OR	CX,CX
		JNZ	L_ZX1
L_ZX3:
		MOV	AL,BL

		PUSH	CX
		CMP	DL,3			;ÈýÐÐ?
		JB	L_ZX5
	;	MOV	BL,AL
		CALL	S_QSX			;È¡ÊúÏßÊôÐÔ
		AND	DH,0FH
		MOV	CH,DH			;±£ÁôµÍ4Î»
		MOV	BL,[DI-80*2]		;ÉÏÒ»ÐÐ×Ö·û
		CMP	BL,0A0H 		;ÅÐÖÆ±í·û?
		JA	L_ZX5
		CALL	S_QSX			;È¡ÊôÐÔ
		MOV	CL,4
		SHR	DH,CL			;ÒÆµÍ4Î»
		CMP	CH,DH			;ÅÐ?
		JZ	L_ZX7
L_ZX5:
		CMP	BYTE PTR [DI-2],0A0H	;×óÓÒÎª×Ö·û?
		JA	L_ZX8
		CMP	BYTE PTR [DI+2],0A0H
		JA	L_ZX8
L_ZX7:
		MOV	[DI],AL 		;×ª»»ÂëÐ´Èë
		ADD	DI,80*2
		DEC	DL
		JNZ	L_ZX7

		POP	CX
		OR	CX,CX
		JZ	L_ZX9
		PUSH	CX

		MOV	BL,AL
		CALL	S_QSX			;È¡ÊúÏßÊôÐÔ
		AND	DH,0F0H
		MOV	CH,DH
		MOV	BL,[DI] 		;ÏÂÒ»ÐÐ×Ö·û
		CMP	BL,0A0H
		JBE	L_ZX8
		CALL	S_QSX			;È¡ÊôÐÔ
		MOV	CL,4
		SHL	DH,CL
		CMP	CH,DH			;ÅÐ?
		JNZ	L_ZX8
		PUSH	SI
		MOV	SI,DI
		ADD	SI,2
		MOV	AL,BL
		CALL	L_QT9			;Ð´Èë
		POP	SI
L_ZX8:
		POP	CX
L_ZX9:
		RET
S_ZXSM		ENDP

;×Ó³ÌÐò:ALÖÆ±í·û×ª³ÉÎ÷ÎÄÖÆ±í·û
S_ALVB		PROC	NEAR
		CMP	AL,20H
		JB	L_AV0
		CMP	AL,7FH
		JB	L_AV3			;ASCII×Ö·û
		CMP	AL,0A0H
		JA	L_AV3			;ºº×ÖÄÚÂë
L_AV0:
		XOR	BX,BX
L_AV1:
		CMP	AL,CS:D_ZBFB[BX]
		JZ	L_AV2
		INC	BX
		CMP	BL,48
		JB	L_AV1
		RET
L_AV2:
		MOV	AL,BL
		ADD	AL,0B0H
L_AV3:
		RET
S_ALVB		ENDP

;×Ó³ÌÐò:ÏÔÊ¾
S_XRXS		PROC	NEAR
		CMP	CS:D_ZBFS,0		;=0´¿Î÷ÎÄ·½Ê½
		JZ	L_XX1
		CMP	AL,0A0H 		;ÅÐºº×Ö?
		JA	L_XX2
L_XX1:
		CMP	CS:D_ZBFS,1		;=0´¿Î÷ÎÄ·½Ê½ »ò1²»´¦ÀíÖÆ±í·û
		JBE	L_XX1A
		CALL	S_ALVB			;ALÖÆ±í·û×ª³ÉASCIIÖÆ±í·û
L_XX1A:
		MOV	BL,CH			;µ±Ç°×Ö·ûÊôÐÔ(×Ö·ûAL)
   ;×Ó³ÌÐò:ÏÔÊ¾×Ö·ûAL,ÊôÐÔBL,Î»ÖÃSI
S_XRZF:
		MOV	CX,1
		XOR	BP,BP
		MOV	DS,BP
		JMP	S_XSZF
L_XX2:
		CALL	S_PVHZ			;ÅÐÕûºº×Ö?
		JZ	L_XX3
		CMP	DL,1			;µ±Ç°×Ö·ûÁÐÎ»ÖÃ
		JB	L_XX1
		MOV	BX,DS:[SI-4]		;×ó±ß×Ö·û
		CMP	BL,0A0H
		JBE	L_XX1
		MOV	AH,BL			;×ó±ß×Ö·û(ÊôÐÔBH)
		MOV	BL,CH			;µ±Ç°×Ö·ûÊôÐÔ(×Ö·ûAL)
		DEC	DX
		JMP	SHORT S_XRHZ
L_XX3:
		CMP	DL,79			;µ±Ç°×Ö·ûÔÚÐÐÎ²
		JAE	L_XX1
		MOV	BX,DS:[SI]		;ÓÒ±ß×Ö·û
		CMP	BL,0A0H
		JBE	L_XX1
		MOV	AL,BL			;ÓÒ±ß×Ö·û
		MOV	BL,BH			;	 ÊôÐÔ
		MOV	AH,CL			;µ±Ç°×Ö·û
		MOV	BH,CH			;	 ÊôÐÔ
   ;×Ó³ÌÐò:ÏÔÊ¾ºº×Ö Ç°×Ö½ÚAH,ÊôÐÔBH,Î»ÖÃSI;ºó×Ö½ÚAL,ÊôÐÔBL
S_XRHZ:
		CMP	DL,79			;ÔÚÐÐÎ²?
K_HZ1	EQU	$
		JZ	L_XRHZ1

		XOR	BP,BP
		JMP	S_XSHZ
L_XRHZ1:
		PUSH	AX
		PUSH	BX
		MOV	AL,AH
		MOV	BL,BH
		CALL	S_XRZF
		POP	BX
		POP	AX
		INC	DX
		CMP	DL,80
		JNZ	L_XRHZ2
		XOR	DL,DL
		INC	DH
L_XRHZ2:
		JMP	S_XRZF
S_XRXS		ENDP

;×Ó³ÌÐò:ÅÐÕûºº×Ö ·µ»ØZF=0ÎªÇ°×Ö½Ú,=1Îªºó×Ö½Ú
S_PVHZ		PROC	NEAR
		PUSH	SI
		XOR	BL,BL
		OR	DL,DL
		JZ	L_PV2
		MOV	BH,DL			;µ±Ç°×Ö·ûÁÐÎ»ÖÃ
		SUB	SI,4
L_PV1:
		CMP	BYTE PTR [SI],0A0H
		JB	L_PV2
		SUB	SI,2
		NOT	BL
		DEC	BH
		JNZ	L_PV1
L_PV2:
		POP	SI
		OR	BL,BL
		RET
S_PVHZ		ENDP

;	LHELP.ASM
;	1997.2.20, 3.21, 6.29, 7.31
;	1998.4.8
;	1999.1.13

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

D_FILE		DW	0			;ÎÄ¼þÃûÊ×
D_MODE		DB	0			;ÏÔÊ¾·½Ê½
D_WIN		DB	0			;µ±Ç°´°¿ÚºÅ
D_B1		DB	'ÉÍ»',0
D_B2		DB	'º º',0
D_B3		DB	'ÈÍ¼',0
D_CDXZ		DB	4FH			;²Ëµ¥Ñ¡ÔñÉ«
D_TS		DB	' ALT+×¨ÓÃ¼üÅÌ| ¹â±ê-ÒÆ¶¯,±³¾°:INS+,DEL-.Ç°¾°:HOME+,END-.±ß¿ò:PGUP+,PGDN-,´æÅÌ:+',0
D_ALT		DB	0			;¼üÈëALT±êÖ¾
K_NUM		DB	14			;×Ó´°¿ÚÊý
H_MAIN		DB	1			;Ö÷²Ëµ¥µ±Ç°ºÅ

K_MAIN		DB	1EH			;Ö÷²Ëµ¥´°¿ÚÉ«
		DB	1EH			;±êÌâÉ«
		DW	1218H			;Ö÷²Ëµ¥´°¿Ú´óÐ¡
		DW	204H			;	   ×óÉÏ½ÇÎ»ÖÃ

K_ZFB		DB	6FH			;×Ö·û±í
		DB	6EH
		DW	1325H
		DW	410H

K_KZASC 	DB	57H			;À©Õ¹ASC±í
		DB	5AH
		DW	182FH
		DW	18H

K_GQHZ		DB	61H			;¸÷Çøºº×Ö
		DB	6BH
		DW	0E28H
		DW	610H

K_SPDM		DB	4AH			;Ë«Æ´´úÂë
		DB	4EH
		DW	122FH
		DW	315H

K_YS		DB	2AH			;Ç°¾°±³¾°ÑÕÉ«
		DB	2FH
		DW	133DH
		DW	410H

K_XSFS		DB	67H			;ÏÔÊ¾·½Ê½
		DB	6FH
		DW	946H
		DW	808H

K_SLZT		DB	52H			;Ê¸Á¿×ÖÌå
		DB	5EH
		DW	1130H
		DW	515H

K_ZXZH		DB	21H			;×ÖÐÍ×ÖºÅ
		DB	2FH
		DW	174AH
		DW	103H

K_XTPB		DB	4FH			;ÏµÍ³ÅÅ°æ
		DB	4EH
		DW	183FH
		DW	0AH

K_TSXS		DB	1EH			;ÌØÊâÏÔÊ¾
		DB	1FH
		DW	144DH
		DW	101H

K_TSDY		DB	1EH			;ÌØÊâ´òÓ¡
		DB	1FH
		DW	1447H
		DW	206H

K_INT10 	DB	1EH			;ÏÔÊ¾ÖÐ¶Ï
		DB	1FH
		DW	164EH
		DW	101H

K_QTINT 	DB	1EH			;ÆäËûÖÐ¶Ï
		DB	1FH
		DW	174EH
		DW	201H

K_GNJ		DB	30H			;¹¦ÄÜ¼üÓÃ·¨
		DB	30H
		DW	0D39H
		DW	910H

D_BT		DB	' !2.13L Áª»ú°ïÖúÏµÍ³!',0
		DB	' ',0
D_CD		DB	'ASCII×Ö·û±í         ',0        ;ZFB
		DB	'À©Õ¹ASCIIÂë±í       ',0        ;KZASC
		DB	'ÇøÎ»Âë±í            ',0        ;GQHZ
		DB	'Ë«Æ´´úÂë±í          ',0        ;SPDM
		DB	'ÏÔÊ¾16ÖÖÇ°¾°±³¾°ÑÕÉ«',0        ;YS
		DB	'ÏÔÊ¾·½Ê½Ò»ÀÀ±í      ',0        ;XSFS
		DB	'Ê¸Á¿ºº×Ö×ÖÌåÓë×Ö¿âÃû',0        ;SLZT
		DB	'×ÖÐÍÓë×ÖºÅ±í        ',0        ;ZXZH
		DB	'¹«ÎÄÅÅ°æ´òÓ¡¹¦ÄÜ    ',0        ;XTPB
		DB	'ÌØÊâÏÔÊ¾¹¦ÄÜ        ',0        ;TSXS
		DB	'ÌØÊâ´òÓ¡¹¦ÄÜ        ',0        ;TSDY
		DB	'ÏÔÊ¾ÖÐ¶Ï¹¦ÄÜµ÷ÓÃ    ',0        ;INT10
		DB	'¼üÅÌºÍ´òÓ¡ÖÐ¶Ïµ÷ÓÃ  ',0        ;QTINT
		DB	'±¾Ä£¿é¹¦ÄÜ¼üÓÃ·¨    ',0,0      ;GNJ

D_XZ		DW	OFFSET S_ZFB
		DW	OFFSET S_KZASC
		DW	OFFSET S_GQHZ
		DW	OFFSET S_SPDM
		DW	OFFSET S_YS
		DW	OFFSET S_XSFS
		DW	OFFSET S_SLZT
		DW	OFFSET S_ZXZH
		DW	OFFSET S_XTPB
		DW	OFFSET S_TSXS
		DW	OFFSET S_TSDY
		DW	OFFSET S_INT10
		DW	OFFSET S_QTINT
		DW	OFFSET S_GNJ
		DW	0

L_HELP		PROC	FAR
		PUSH	DS
		PUSH	ES
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES

		MOV	CX,2000H
		MOV	AH,1			;¹Ø¹â±ê
		INT	10H
L_40:
		MOV	AL,D_WIN
		OR	AL,AL
		JNZ	L_55
L_44:
		MOV	DI,OFFSET K_MAIN
		CALL	S_XSCK			;ÏÔÊ¾¿Õ´°¿Ú
		MOV	SI,OFFSET D_BT		;±êÌâ¼°Ö÷²Ëµ¥
		CALL	S_CKXS102
L_50:
		MOV	CH,K_NUM		;ÏîÊý
		MOV	CL,21			;¿í¶È
		INC	DH			;²Ëµ¥Î»ÖÃ
		MOV	D_DX,DX
		MOV	DH,H_MAIN		;Ä¬ÈÏºÅ
		MOV	BP,OFFSET D_CD		;Ö÷²Ëµ¥
		CALL	S_CDKZ			;²Ëµ¥¿ØÖÆ

		CMP	D_ALT,0FFH		;¼üÈëALT
		JZ	L_44
		CMP	AL,1BH			;ESC
		JZ	L_RET
L_55:
		MOV	H_MAIN,AL
		MOV	D_WIN,AL
L_60:
		CBW
		DEC	AX
		SHL	AX,1
		MOV	BX,AX
		CALL	D_XZ[BX]		;Ö´ÐÐ¸÷¹¦ÄÜ×Ó³ÌÐò

		CMP	D_ALT,0 		;ÅÐALT
		JZ	L_62
		MOV	AL,D_WIN
		OR	AL,AL
		JNZ	L_60
l_62:
		MOV	D_WIN,0
		JMP	SHORT L_44
L_RET:
		MOV	AX,1406H
		INT	10H
		MOV	AX,1813H		;»Ö¸´ÆÁÄ»
		TEST	DL,80H
		JZ	L_RET1
		MOV	AL,23
L_RET1:
		INT	10H
		MOV	CX,0E0FH
		MOV	AH,1			;¿ª¹â±ê
		INT	10H
		POP	ES
		POP	DS
		RET
L_HELP		ENDP

;¹«ÓÃ×Ó³ÌÐò==================================================================
D_K		DW	0			;¿í
D_G		DW	0			;¸ß
;×Ó³ÌÐò:ÏÔÊ¾¿Õ´°¿Ú DI=´°¿Ú²ÎÊýÊ×(´°¿ÚÉ«,ÏÔÊ¾É«,´°¿Ú´óÐ¡,´°¿Ú×óÉÏ½Ç)
S_XSCK		PROC	NEAR
		MOV	BL,[DI] 		;´°¿ÚÉ«
		MOV	CX,[DI+2]		;´óÐ¡
		MOV	DX,[DI+4]		;×óÉÏ½Ç
		PUSH	DX
		SUB	CX,202H
		MOV	AL,CH
		CBW
		MOV	D_G,AX			;´°¿ÚÄÚ¸ß
		MOV	AL,CL
		MOV	D_K,AX			;      ¿í

		XOR	CX,CX
		MOV	SI,OFFSET D_B1		;ÉÏºáÏß
		CALL	S_XSYH

		MOV	SI,OFFSET D_B2		;ÖÐ¼ä
		MOV	BP,D_G
L_CK1:
		INC	DH
		CALL	S_XSYH
		DEC	BP
		JNZ	L_CK1
		INC	DH
		CMP	DH,18H
		JA	L_CK3
		MOV	SI,OFFSET D_B3		;ÏÂºáÏß
		CALL	S_XSYH

		ADD	DX,101H
		CMP	D_MODE,9		;ÅÐµ¥ÏÔ?
		JBE	L_CK3
		CMP	DH,18H			;µ½µ×ÐÐ?
		JA	L_CK3
		MOV	BX,2000H		;ÏÂÒõÓ°
		MOV	BP,D_K
		ADD	BP,2
L_CK2:
		CALL	S_XSZF
		DEC	BP
		JNZ	L_CK2
L_CK3:
		MOV	BL,[DI+1]		;ÏÔÊ¾É«
		POP	DX
		RET
;×Ó³ÌÐò:ÏÔÊ¾Ò»ÐÐ:
S_XSYH:
		PUSH	DX
		PUSH	BP
		MOV	BH,[SI] 		;×ó±ß
		CALL	S_XSZF
		MOV	BH,[SI+1]		;ÖÐ¼ä
		MOV	BP,D_K
L_YH1:
		CALL	S_XSZF
		DEC	BP
		JNZ	L_YH1
		MOV	BH,[SI+2]		;ÓÒ±ß
		CALL	S_XSZF
		CMP	D_MODE,9		;ÅÐµ¥ÏÔ?
		JBE	L_YH2
		CMP	SI,OFFSET D_B1		;ÅÐÉÏºáÏß?
		JZ	L_YH2
		CMP	DL,80			;ÅÐµ½ÓÒ±ß?
		JZ	L_YH2
		PUSH	BX
		MOV	BX,2000H		;ÓÒ±ßÒõÓ°
		CALL	S_XSZF
		POP	BX
L_YH2:
		POP	BP
		POP	DX
		RET
S_XSCK		ENDP

;×Ó³ÌÐò:ÏÔÊ¾´°¿ÚÄÚÈÝSI(Ã¿ÐÐÎ²0,×îºóÔÙ¼Ó0),DX=Ê×Î»ÖÃ,BL=ÊôÐÔ
S_CKXS102	PROC	NEAR
		ADD	DX,102H
S_CKXS:
		MOV	CX,1
		PUSH	DX
L_CKXS1:
		CMP	BYTE PTR [SI],0 	;½áÊø?
		JZ	L_CKXS2
		PUSH	DX
		CALL	S_XSZFC 		;ÏÔÊ¾Ò»ÐÐ
		POP	DX
		INC	DH
		JMP	SHORT L_CKXS1
L_CKXS2:
		POP	DX
		RET
S_CKXS102	ENDP

;×Ó³ÌÐò:¼üÈë
S_INPUT 	PROC	NEAR
		MOV	D_ALT,0 		;Çå±êÖ¾
		MOV	AX,2B10H		;µ÷BIOS¼üÈë
		INT	16H
		PUSH	AX
		MOV	AL,6
		MUL	D_WIN
		ADD	AX,OFFSET K_MAIN
		MOV	SI,AX
		POP	AX

		CMP	AH,98H			;ALT+¡ü
		JNZ	L_IN1
		MOV	DL,[SI+5]
		OR	DL,DL
		JZ	L_IN00
		DEC	DL
		MOV	[SI+5],DL
L_IN00:
		NOT	D_ALT			;ÖÃ±êÖ¾
		RET
L_IN1:
		CMP	AH,0A0H 		;ALT+¡ý
		JNZ	L_IN2
		MOV	DL,[SI+5]		;´°¿Ú×óÉÏ½ºÐÐ
		ADD	DL,[SI+3]		;+´°¿ÚÐÐÊý
		CMP	DL,25			;µ½µ×?
		JAE	L_IN10
		INC	BYTE PTR [SI+5]
L_IN10:
		JMP	L_IN00
L_IN2:
		CMP	AH,9BH			;ALT+¡û
		JNZ	L_IN3
		MOV	DL,[SI+4]
		OR	DL,DL
		JZ	L_IN20
		DEC	DL
		MOV	[SI+4],DL
L_IN20:
		JMP	L_IN00
L_IN3:
		CMP	AH,9DH			;ALT+¡ú
		JNZ	L_IN4
		MOV	DL,[SI+4]
		ADD	DL,[SI+2]
		CMP	DL,80
		JAE	L_IN30
		INC	BYTE PTR [SI+4]
L_IN30:
		JMP	L_IN00
L_IN4:
		CMP	AH,0A2H 		;ALT+INS*	±³¾°É«+
		JNZ	L_IN5
		ADD	BYTE PTR [SI],10H
		ADD	BYTE PTR [SI+1],10H
		JMP	L_IN00
L_IN5:
		CMP	AH,0A3H 		;ALT+DEL*	±³¾°É«-
		JNZ	L_IN6
		SUB	BYTE PTR [SI],10H
		SUB	BYTE PTR [SI+1],10H
		JMP	L_IN00
L_IN6:
		CMP	AH,97H			;ALY+HOME*	Ç°¾°É«+
		JNZ	L_IN7
		MOV	DL,[SI+1]
		MOV	DH,DL
		AND	DH,0F0H
		INC	DL
		AND	DL,0FH
		OR	DL,DH
		MOV	[SI+1],DL
		JMP	L_IN00
L_IN7:
		CMP	AH,9FH			;ALT+END*	Ç°¾°É«-
		JNZ	L_IN8
		MOV	DL,[SI+1]
		MOV	DH,DL
		AND	DH,0F0H
		DEC	DL
		AND	DL,0FH
		OR	DL,DH
		MOV	[SI+1],DL
		JMP	L_IN00
L_IN8:
		CMP	AH,99H			;ALT+PGUP*	±ß¿òÉ«+
		JNZ	L_IN9
		MOV	DL,[SI]
		MOV	DH,DL
		AND	DH,0F0H
		INC	DL
		AND	DL,0FH
		OR	DL,DH
		MOV	[SI],DL
		JMP	L_IN00
L_IN9:
		CMP	AH,0A1H 		;ALT+PGDN*	±ß¿òÉ«-
		JNZ	L_INA
		MOV	DL,[SI]
		MOV	DH,DL
		AND	DH,0F0H
		DEC	DL
		AND	DL,0FH
		OR	DL,DH
		MOV	[SI],DL
		JMP	L_IN00
L_INA:
		CMP	AH,0A6H 		;ALT+ENTER*	ÌáÊ¾ÐÐÏÔÊ¾
		JNZ	L_INB
		MOV	AX,1400H
		INT	10H
		MOV	SI,OFFSET D_TS
		MOV	BX,1EH
L_INA0:
		LODSB
		OR	AL,AL
		JZ	L_INA1
		MOV	DL,AL
		MOV	AX,1403H
		INT	10H
		JMP	SHORT L_INA0
L_INA1:
		JMP	S_INPUT
L_INB:
		CMP	AH,4EH			;ALT+'+'*       ÉèÖÃ´æÅÌ
		JNZ	L_INC
		MOV	AH,51H			;È¡PSP
		INT	21H
		PUSH	BX			;±£´æ
		MOV	BX,CS
		MOV	AH,50H			;µ±Ç°PSP
		INT	21H
		MOV	DX,D_FILE		;µ÷³öÎÄ¼þÃû(´øÂ·¾¶)
		MOV	DS,DS:[2CH]
		MOV	CX,20H
		MOV	AH,3CH			;ÖØ½¨ÎÄ¼þ
		INT	21H
		MOV	BX,AX
		PUSH	CS
		POP	DS
		MOV	DX,100H
		MOV	CX,OFFSET D_END-100H
		MOV	AH,40H			;Ð´Èë
		INT	21H
		MOV	AH,3EH			;¹Ø±Õ
		INT	21H
		POP	BX			;»Ö¸´
		MOV	AH,50H			;µ±Ç°PSP
		INT	21H
		JMP	S_INPUT
L_INC:
		RET
S_INPUT 	ENDP

D_DH		DB	1			;¿ªÊ¼Ñ¡ÔñºÅ
D_DX		DW	0			;Î»ÖÃ
;¡¼×Ó³ÌÐò:²Ëµ¥¿ØÖÆ¡½×Ö·û´®Ê×BP,ÏîÊýCH,Ïî³¤CL(°üÀ¨0),D_DX=Î»ÖÃ
;		    ·µ»ØAL=Ñ¡ÖÐÏî
S_CDKZ		PROC	NEAR
L_CD10:
		CALL	S_XCD
		CALL	S_INPUT 		;¼üÈë
		CMP	D_ALT,0FFH		;ÅÐALT
		JZ	L_CD20
		CMP	AL,1BH			;ESC?
		JZ	L_CD20
		CMP	AL,' '
		JZ	L_CD20
		CMP	AL,0DH			;»Ø³µ
		JNZ	L_CD30
		MOV	AL,DH			;Ñ¡ÖÐÏîºÅ
L_CD20:
		RET
L_CD30:
		CMP	AH,80			;¡ý
		JNZ	L_CD50
		CALL	S_QCD			;ÇåÔ­ÏÔÊ¾
		CMP	DH,CH			;ÒÑµ½×î´óºÅ?
		JZ	L_CD40
		INC	DH			;Ôö1
		JMP	SHORT L_CD10
L_CD40:
		MOV	DH,1			;ÖÃ1
		JMP	SHORT L_CD10
L_CD50:
		CMP	AH,72			;¡ü
		JNZ	L_CD10
		CALL	S_QCD			;ÇåÔ­ÏÔÊ¾
		CMP	DH,1			;ÅÐ=1?
		JZ	L_CD60
		DEC	DH			;¼õ1
		JMP	SHORT L_CD10
L_CD60:
		MOV	DH,CH			;ÖÃ×î´óºÅ
		JMP	SHORT L_CD10
;¡¼×Ó³ÌÐò:¶¨Î»ÏÔÊ¾²Ëµ¥¡½
S_QCD:						;Çå²Ëµ¥ÐÐ
		MOV	BL,K_MAIN+1		;ÆÕÍ¨ÏÔÊ¾ÑÕÉ«
		JMP	SHORT L_XCD
S_XCD:						;Ð´²Ëµ¥ÐÐ
		MOV	BL,D_CDXZ		;²Ëµ¥Ñ¡ÔñÑÕÉ«
L_XCD:
		PUSH	CX
		PUSH	DX
		MOV	AL,CL			;Ïî³¤
		MUL	DH			;*ºÅ
		XOR	CH,CH
		SUB	AX,CX
		ADD	AX,BP
		MOV	SI,AX			;´®Ê×
		ADD	DH,BYTE PTR D_DX+1	;ÐÐ
		MOV	DL,BYTE PTR D_DX	;ÁÐ
		CALL	S_XSZFC 		;ÏÔÊ¾×Ö·û´®
		POP	DX
		POP	CX
		RET
S_CDKZ		ENDP

;×Ó³ÌÐò:ÏÔÊ¾×Ö·ûBH,Î»ÖÃDX(ÏÔÊ¾ºó+1
S_XSZF		PROC	NEAR
		PUSH	BX
		CMP	D_MODE,9		;ÅÐµ¥ÏÔ?
		JA	L_XF1
		CMP	BL,70H			;ÅÐ·´Ïà?
		JZ	L_XF1
		MOV	BL,7
L_XF1:
		MOV	AX,1409H		;ÏÔÊ¾
		INT	10H
		INC	DX			;ÁÐ+1
		POP	BX
		RET
S_XSZF		ENDP

;×Ó³ÌÐò:ÏÔÊ¾×Ö·û´®SI,½áÎ²0,BL=ÊôÐÔ
S_XSZFC 	PROC	NEAR
		LODSB
		OR	AL,AL			;ÅÐ½áÊø?
		JZ	L_X4
		CMP	AL,'!'                  ;·´ÏÔ?
		JNZ	L_X3
		CMP	D_MODE,9		;ÅÐµ¥ÏÔ?
		JBE	L_X1
		CALL	S_BL
		JMP	SHORT S_XSZFC
L_X1:
		CMP	BL,70H			;Ô­·´ÏÔ?
		JZ	L_X2
		MOV	BL,70H
		JMP	SHORT S_XSZFC
L_X2:
		MOV	BL,7
		JMP	SHORT S_XSZFC
L_X3:
		MOV	BH,AL
		CALL	S_XSZF			;ÏÔÊ¾×Ö·û
		JMP	SHORT S_XSZFC
L_X4:
		RET
S_BL:
		ROR	BL,1			;Ç°¾°±³¾°½»»»
		ROR	BL,1
		ROR	BL,1
		ROR	BL,1
		RET
S_XSZFC 	ENDP

;×Ó³ÌÐò:´¦ÀíÒ³ DL=×î´óÒ³ºÅ,DH=µ±Ç°ºÅ
S_PAGE		PROC	NEAR
		CALL	S_INPUT 		;¼üÈë
		CMP	D_ALT,0FFH		;ÅÐALT
		JZ	L_P00
		CMP	AL,1BH			;ESC?
		JNZ	L_P0
		POP	AX
		POP	AX
		JMP	L_RET
L_P0:
		OR	AL,AL
		JZ	L_P1
		CMP	AL,80H			;»Ø³µ?
		JAE	L_P1
L_P00:
		POP	AX
		RET
L_P1:
		MOV	AL,DH
		CMP	AH,72			;¡ü
		JZ	L_P2
		CMP	AH,73			;PGUP
		JNZ	L_P4
L_P2:
		OR	AL,AL
		JNZ	L_P3
		MOV	AL,DL
		RET
L_P3:
		DEC	AX
		RET
L_P4:
		CMP	AH,80			;¡ý
		JZ	L_P5
		CMP	AH,81			;PGDN
		JNZ	S_PAGE
L_P5:
		CMP	AL,DL
		JNZ	L_P6
		XOR	AL,AL
		RET
L_P6:
		INC	AX
		RET
S_PAGE		ENDP

;×Ó³ÌÐò:¾ÓÖÐ¼Ó¿íÏÔÊ¾±êÌâES:SI ´°¿Ú²ÎÊýÊ×:DI(DI+2-´°¿Ú¿í)
S_XSBT		PROC	NEAR
		PUSH	SI
		XOR	CX,CX
L_BT1:
		LODSB
		OR	AL,AL			;ÅÐ´®Î²?
		JZ	L_BT2
		INC	CX
		JMP	SHORT L_BT1
L_BT2:
		POP	SI

		SHL	CL,1			;´®³¤*2
		MOV	CH,[DI+2]		;´°¿Ú¿í
		SUB	CH,CL
		SHR	CH,1			;×ó¿Õ

		PUSH	DX
		PUSH	BX
		ADD	DL,CH
		CALL	S_BL
		MOV	AX,140FH		;ÏÔÊ¾×Ö·û´®
		INT	10H
		POP	BX
		POP	DX
		RET
S_XSBT		ENDP
;============================================================================
D_16		DB	'0123456789ABCDEF',0
T_ASC		DB	'ASCII ×Ö·û±í',0
D_ZF		DB	0			;µ±Ç°×Ö·û

S_ZFB		PROC	NEAR
		MOV	DI,OFFSET K_ZFB
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_ASC
		CALL	S_XSBT			;ÏÔÊ¾±êÌâ
		XOR	CX,CX
		MOV	SI,OFFSET D_16		;'0123456789ABCDEF'
		PUSH	DX
		ADD	DX,104H
L_ZFB1:
		LODSB
		OR	AL,AL			;½áÊø?
		JZ	L_ZFB2
		MOV	BH,AL			;×Ö·û
		CALL	S_XSZF
		MOV	BH,' '                  ;¿Õ¸ñ
		CALL	S_XSZF
		JMP	SHORT L_ZFB1
L_ZFB2:
		POP	DX
		ADD	DX,202H

		MOV	SI,OFFSET D_16		;'0123456789ABCDEF'
		MOV	D_ZF,0
L_ZFB3:
		LODSB
		OR	AL,AL			;½áÊø?
		JZ	L_INRET
		PUSH	DX
		MOV	BH,AL			;ÐÐ×Ö·û
		CALL	S_XSZF
		MOV	BH,' '                  ;¿Õ¸ñ
		CALL	S_XSZF
		MOV	DI,16
L_ZFB4:
		MOV	BH,D_ZF 		;µ±Ç°×Ö·û
		CALL	S_XSZF
		MOV	BH,' '                  ;¿Õ¸ñ
		CALL	S_XSZF
		INC	D_ZF			;×Ö·û+1
		DEC	DI
		JNZ	L_ZFB4
		POP	DX
		INC	DH
		JMP	SHORT L_ZFB3
L_INRET:
		CALL	S_INPUT 		;¼üÈë²¢·µ»Ø
		CMP	AL,1BH
		JZ	L_INRET1
		RET
L_INRET1:
		POP	AX
		JMP	L_RET
S_ZFB		ENDP
;----------------------------------------------------------------------------
T_KZASC 	DB	'À©Õ¹ASCIIÂë±í',0
D_KZASC 	DB	'0FH-SHIFT+TAB  10H-19H:ALT+QWERTYUIOP',0
		DB	'1EH-26H:ALT+ASDFGHJKL   2CH-32H:ALT+ZXCVBNM',0
		DB	'3BH-44H:F1~F10 47H-HOME       48H-UP¡ü',0
		DB	'49H-PGUP       4AH-ALT+"-"¡ù  4BH-LEFT¡û',0
		DB	'4DH-RIGHT¡ú    4EH-ALT+"+"¡ù  4FH-END',0
		DB	'50H-DOWN¡ý     51H-PGDN       52H-INS',0
		DB	'53H-DEL        54H-5DH:SHIFT+F1~F10',0
		DB	'5EH-67H:CTRL+F1~F10     68H-71H:ALT+F1~F10',0
		DB	'72H-CTRL+PRTSC 73H-CTRL+¡û    74H-CTRL+¡ú',0
		DB	'75H-CTRL+END   76H-CTRL+PGDN  77H-CTRL+HOME',0
		DB	'78H-83H:ALT+1~0,-,=           84H-CTRL+PGUP',0
		DB	'85H-F11        86H-F12        87H-SHIFT+F11',0
		DB	'88H-SHIFT+F12  89H-CTRL+F11   8AH-CTRL+F12',0
		DB	'8BH-ALT+F11    8CH-ALT+F12    8DH-CTRL+¡ü',0
		DB	'8EH-CTRL+"-"   8FH-CTRL+5     90H-CTTRL+"+"',0
		DB	'91H-CTRL+¡ý    92H-CTRL+INS   93H-CTRL+DEL',0
		DB	'94H-CTRL+TAB   95H-CTRL+/¡ù   96H-CTRL+*¡ù',0
		DB	'97H-ALT+HOME¡ù 98H-ALT+¡ü¡ù   99H-ALT+PGUP¡ù',0
		DB	'9BH-ALT+¡û¡ù   9DH-ALT+¡ú¡ù   9FH-ALT+END¡ù',0
		DB	'A0H-ALT+¡ý¡ù   A1H-ALT+PGDN¡ù A2H-ALT+INS¡ù',0
		DB	'A3H-ALT+DEL¡ù  A4H-ALT+/¡ù    A5H-ALT+TAB',0
		DB	'A6H-ALT+ENTER¡ù         ÓÐ¡ùÎª×¨ÓÃÐ¡¼üÅÌ',0,0

S_KZASC 	PROC	NEAR
		MOV	DI,OFFSET K_KZASC
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_KZASC
		CALL	S_XSBT			;ÏÔÊ¾±êÌâ
		MOV	SI,OFFSET D_KZASC
L_XSINRET:
		CALL	S_CKXS102		;ÏÔÊ¾´°¿ÚÄÚÈÝ
		JMP	L_INRET
S_KZASC 	ENDP
;----------------------------------------------------------------------------
T_QWXS		DB	'ÏÔÊ¾¸÷Çøºº×Ö',0
D_QW		DB	'µÚ16Çø £° £± £² £³ £´ £µ £¶ £· £¸ £¹',0
		DB	'  1600    °¡ °¢ °£ °¤ °¥ °¦ °§ °¨ °©',0
		DB	'  1610 °ª °« °¬ °­ °® °¯ °° °± °² °³',0
		DB	'  1620 °´ °µ °¶ °· °¸ °¹ °º °» °¼ °½',0
		DB	'  1630 °¾ °¿ °À °Á °Â °Ã °Ä °Å °Æ °Ç',0
		DB	'  1640 °È °É °Ê °Ë °Ì °Í °Î °Ï °Ð °Ñ',0
		DB	'  1650 °Ò °Ó °Ô °Õ °Ö °× °Ø °Ù °Ú °Û',0
		DB	'  1660 °Ü °Ý °Þ °ß °à °á °â °ã °ä °å',0
		DB	'  1670 °æ °ç °è °é °ê °ë °ì °í °î °ï',0
		DB	'  1680 °ð °ñ °ò °ó °ô °õ °ö °÷ °ø °ù',0
		DB	'  1690 °ú °û °ü °ý °þ               ',0
		DB	'!°´¡ü¡úÔö¼Ó,¡û¡ý¼õÉÙ,<ESC>·µ»ØÖ÷²Ëµ¥.!',0,0
D_Q		DB	16			;ÇøºÅ

S_GQHZ		PROC	NEAR
		MOV	DI,OFFSET K_GQHZ
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_QWXS
		CALL	S_XSBT			;ÏÔÊ¾±êÌâ
		ADD	DX,102H
L_GQHZ1:
		MOV	AL,D_Q			;ÇøºÅ
		CBW
		MOV	CL,10
		DIV	CL
		OR	AX,3030H		;Ê®½øÖÆ
		MOV	SI,OFFSET D_QW+2
		MOV	CX,11
L_GQHZ2:
		MOV	[SI],AX 		;Ð´ÈëÇøºÅ
		ADD	SI,37			;ÏÂÒ»ÐÐ
		LOOP	L_GQHZ2

		PUSH	BX
		PUSH	DX
		MOV	DI,OFFSET D_QW+37
		MOV	BL,10
		XOR	DH,DH			;Î»ºÅ
L_GQHZ3:
		ADD	DI,7
		MOV	BH,10
L_GQHZ4:
		CMP	DH,94
		JA	L_GQHZ5
		OR	DH,DH
		JNZ	L_GQHZ6
L_GQHZ5:
		MOV	AX,'  '
		JMP	SHORT L_GQHZ7
L_GQHZ6:
		MOV	DL,D_Q			;ÇøºÅ
		MOV	AX,DX
		ADD	AX,0A0A0H		;ºº×ÖÄÚÂë
L_GQHZ7:
		STOSW				;Ð´Èë
		INC	DI
		INC	DH
		DEC	BH
		JNZ	L_GQHZ4
		DEC	BL
		JNZ	L_GQHZ3
		POP	DX
		POP	BX

		MOV	SI,OFFSET D_QW
		CALL	S_CKXS			;´°¿ÚÄÚÈÝÏÔÊ¾
L_GQHZ8:
		MOV	BH,D_Q
		CALL	S_INPUT 		;È¡°´¼ü
		CMP	D_ALT,0FFH		;ÅÐALT
		JZ	L_GQHZA
		CMP	AL,1BH			;ESC?
		JNZ	L_GQHZ9
		POP	AX
		JMP	L_RET
L_GQHZ9:
		CMP	AL,0DH			;·µÖ÷²Ëµ¥
		JNZ	L_GQHZB
L_GQHZA:
		RET
L_GQHZB:
		CMP	AH,75			;¡û
		JZ	L_GQHZC
		CMP	AH,80			;¡ý
		JNZ	L_GQHZD
L_GQHZC:
		DEC	BH
		CMP	BH,1
		JNB	L_GQHZF
		MOV	BH,87
		JMP	SHORT L_GQHZF
L_GQHZD:
		CMP	AH,72			;¡ü
		JZ	L_GQHZE
		CMP	AH,77			;¡ú
		JNZ	L_GQHZ8
L_GQHZE:
		INC	BH			;ÇøºÅ+1
		CMP	BH,95
		JB	L_GQHZF
		MOV	BH,1
L_GQHZF:
		MOV	D_Q,BH
		JMP	L_GQHZ1
S_GQHZ		ENDP
;----------------------------------------------------------------------------
T_SP		DB	'Ë«Æ´´úÂë±í',0
D_SP		DB	'ÉùÄ¸£ºzh-V     ch-I      sh-U',0
		DB	'ÔÏÄ¸£º          i-I       u-U     ¨¹-V',0
		DB	'      a-A      ia-R *    ua-W ÍÚ',0
		DB	'      o-O      uo-O',0
		DB	'      e-E      ie-T Ìú            ¨¹e-W',0
		DB	'      ai-L               uai-Y',0
		DB	'      ei-D               ui-V',0
		DB	'      ao-K    iao-M Ãç',0
		DB	'      ou-P    iu-Q',0
		DB	'      an-J    ian-B ±ß   uan-Z×ê  ¨¹an-Z',0
		DB	'      en-F    in-N  Äú   un-C ´å  ¨¹n-C',0
		DB	'      ang-H   iang-XÏã   uang-X',0
		DB	'      eng-G   ing-Y Ó¢',0
		DB	'      ong-S   iong-SÓµ',0
		DB	'×¢:µ¥ÔÏÄ¸aeoË«´ò,Ë«×ÖÄ¸ÕÕ´ò,angÎªag,engÎªeg',0
		DB	'   ¼üÈëap¿Éµ÷³öËùÓÐµÄÆ«ÅÔ²¿Ê×(ÔÚ¶þ¼¶×ÖÇø)',0,0

S_SPDM		PROC	NEAR
		MOV	DI,OFFSET K_SPDM
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_SP
		CALL	S_XSBT			;ÏÔÊ¾±êÌâ
		MOV	SI,OFFSET D_SP
		JMP	L_XSINRET		;ÏÔÊ¾´°¿ÚÄÚÈÝ²¢¼üÈë
S_SPDM		ENDP
;----------------------------------------------------------------------------
T_XSYS		DB	'ÏÔÊ¾16ÖÖÇ°¾°±³¾°ÑÕÉ«',0
D_XSYS		DB	'±³¾°\£° £± £² £³ £´ £µ £¶ £· £¸ £¹ £Á £Â £Ã £Ä £Å £Æ Ç°¾°',0,0
D_YS		DB	'ºÚ À¶ ÂÌ Çà ºì ·Û ×Ø °× »Ò À¶ ÂÌ Çà ºì ·Û »Æ °× ',0

S_YS		PROC	NEAR
		MOV	DI,OFFSET K_YS
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_XSYS
		CALL	S_XSBT
		MOV	SI,OFFSET D_XSYS
		CALL	S_CKXS102		;ÏÔÊ¾´°¿ÚÄÚÈÝ²¢¼üÈë
		MOV	BH,'0'                  ;±³¾°É«
L_YS1:
		INC	DH			;ÐÐ+1
		PUSH	DX
		CALL	S_XSKG			;ÏÔÊ¾¿Õ¸ñ
		CALL	S_XSKG
		CALL	S_XSZF			;ÏÔÊ¾±³¾°É«
		CALL	S_XSKG
		CALL	S_XSKG
		CALL	S_XSYS			;ÏÔÊ¾Ò»ÐÐ
		POP	DX
		INC	BH			;±³¾°É«+1
		CMP	BH,'G'
		JZ	L_YS2
		CMP	BH,3AH
		JNZ	L_YS1
		ADD	BH,7
		JMP	SHORT L_YS1
L_YS2:
		JMP	L_INRET
S_XSYS:
		PUSH	BX
		MOV	SI,OFFSET D_YS		;ÑÕÉ«´®
		MOV	BL,BH
		SUB	BL,'0'
		CMP	BL,9
		JBE	L_XY1
		SUB	BL,7
L_XY1:
		MOV	CL,4
		SHL	BL,CL			;±³¾°É«
		MOV	CX,16
L_XY2:
		LODSB
		CALL	S_XSAL
		LODSB
		CALL	S_XSAL
		LODSB
		CALL	S_XSAL
		INC	BL			;Ç°¾°É«+1
		LOOP	L_XY2
		POP	BX
		RET
S_XSKG:
		MOV	AL,' '
S_XSAL:
		PUSH	BX
		MOV	BH,AL
		CALL	S_XSZF
		POP	BX
		RET
S_YS		ENDP
;----------------------------------------------------------------------------
T_XSFS		DB	'ÏÔÊ¾·½Ê½Ò»ÀÀ±í',0
D_XSFS		DB	'ÏÔÊ¾·½Ê½  ·Ö±æÂÊ   ÐÐ¡ÁÁÐ   µãÕó  É«ºÅ   ÏÔÊ¾Ä£¿é     ÏÔÊ¾Æ÷ÀàÐÍ',0
		DB	'©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤©¤',0
		DB	'    6    640¡Á200  25¡Á80   8¡Á8   0,1   CGA,CGA25   CGA,EGA,VGA',0
		DB	'    9    640¡Á400  25¡Á80   8¡Á16  0,1    HGA.COM        HGA',0
		DB	'  10H    640¡Á350  25¡Á80   8¡Á14   16    EGA.COM      EGA,VGA',0
		DB	'  12H    640¡Á480  26¡Á80   8¡Á16   16    VGA.COM        VGA',0
		DB	'  255    640¡Á480  30¡Á80   8¡Á16  256    VGA.COM       SVGA',0,0

S_XSFS		PROC	NEAR
		MOV	DI,OFFSET K_XSFS
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_XSFS
		CALL	S_XSBT
		MOV	SI,OFFSET D_XSFS
		JMP	L_XSINRET		;ÏÔÊ¾´°¿ÚÄÚÈÝ²¢¼üÈë
S_XSFS		ENDP
;----------------------------------------------------------------------------
T_SL		DB	'Ê¸Á¿ºº×Ö×ÖÌåºÅ',0
D_SL1		DB	' 0-ËÎÌå¼ò(HZKSJSTJ)       8-Á¥±ä¼ò(HZKSLLBJ) ',0
		DB	' 1-·ÂËÎ¼ò(HZKSLFSJ)       9-´óºÚ¼ò(HZKSLDHJ) ',0
		DB	' 2-ºÚÌå¼ò(HZKSLHTJ)      10-Îº±®¼ò(HZKSLWBJ) ',0
		DB	' 3-¿¬Ìå¼ò(HZKSLKTJ)      11-ÐÐ¿¬¼ò(HZKSLXKJ) ',0
		DB	' 4-±êËÎ¼ò(HZKSLXBJ)      12-Á¥Êé¼ò(HZKSLLSJ) ',0
		DB	' 6-Ï¸Ô²¼ò(HZKSLY1J)      13-Ò¦Ìå¼ò(HZKSLYTJ) ',0
		DB	' 7-×¼Ô²¼ò(HZKSLY3J)      14-ÃÀºÚ¼ò(HZKSLMHJ) ',0
		DB	' ',0
D_SL2		DB	'20-ËÎÌå·±(HZKSLSTF)      28-Á¥±ä·±(HZKSLLBF) ',0
		DB	'21-·ÂËÎ·±(HZKSLFSF)      29-´óºÚ·±(HZKSLDHF) ',0
		DB	'22-ºÚÌå·±(HZKSLHTF)      30-Îº±®·±(HZKSLWBF) ',0
		DB	'23-¿¬Ìå·±(HZKSLKTF)      31-ÐÐ¿¬·±(HZKSLXKF) ',0
		DB	'26-Ï¸Ô²·±(HZKSLY1F)      32-çúçê·±(HZKSLHPF) ',0
		DB	'27-×¼Ô²·±(HZKSLY3F)      33-×ÛÒÕ·±(HZKSLZYF) ',0
		DB	'            ÓÐ',127,'Îª´Ë×Ö¿âÒÑ°²×°',0,0

S_SLZT		PROC	NEAR
		MOV	AX,357EH		;È¡INT7E
		INT	21H
		OR	BX,BX			;ÅÐ°²×°?
		JZ	L_SLZT9
		XOR	DX,DX			;È¡READSL°²×°×´Ì¬
		INT	7EH
		MOV	BX,ES
		CMP	BX,DX			;ÅÐÊÇ·ñREADSLÄ£¿é?
		JNZ	L_SLZT9
		MOV	SI,AX
		MOV	DI,OFFSET D_SL1
		MOV	CX,0
		MOV	BX,19
L_SLZT1:
		LODS	WORD PTR ES:[SI]
		OR	AX,AX
		JZ	L_SLZT2
		MOV	BYTE PTR DS:[BX+DI],7FH
L_SLZT2:
		ADD	DI,46
		INC	CX
		CMP	CX,8
		JNZ	L_SLZT3
		MOV	BX,44
		MOV	DI,OFFSET D_SL1
L_SLZT3:
		CMP	CX,5
		JNZ	L_SLZT4
		ADD	SI,2
		INC	CX
L_SLZT4:
		CMP	CX,14
		JBE	L_SLZT1

		ADD	SI,10
		MOV	DI,OFFSET D_SL2
		MOV	CX,20
		MOV	BX,19
L_SLZT5:
		LODS	WORD PTR ES:[SI]
		OR	AX,AX
		JZ	L_SLZT6
		MOV	BYTE PTR DS:[BX+DI],7FH
L_SLZT6:
		ADD	DI,46
		INC	CX
		CMP	CX,28
		JNZ	L_SLZT7
		MOV	BX,44
		MOV	DI,OFFSET D_SL2
L_SLZT7:
		CMP	CX,24
		JNZ	L_SLZT8
		ADD	CX,2
		ADD	SI,4
L_SLZT8:
		CMP	CX,33
		JBE	L_SLZT5
L_SLZT9:
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET K_SLZT
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_SL
		CALL	S_XSBT
		MOV	SI,OFFSET D_SL1
		JMP	L_XSINRET		;ÏÔÊ¾´°¿ÚÄÚÈÝ²¢¼üÈë
S_SLZT		ENDP
;----------------------------------------------------------------------------
T_ZXB		DB	'×ÖÐÍºÍ×ÖºÅ±í',0
D_ZXB		DB	'!×ÖÐÍ±í!(`@A~x):',0
		DB	'A-ËÎÌå24¡Á24   E-·ÂËÎ24¡Á24   I-ºÚÌå24¡Á24   M-¿¬Ìå24¡Á24 (»ù±¾µãÕó)',0
		DB	'B-ËÎÌå48¡Á24   F-·ÂËÎ48¡Á24   J-ºÚÌå48¡Á24   N-¿¬Ìå48¡Á24 (ºáÀ©Ò»±¶)',0
		DB	'C-ËÎÌå24¡Á48   G-·ÂËÎ24¡Á48   K-ºÚÌå24¡Á48   O-¿¬Ìå24¡Á48 (×ÝÀ©Ò»±¶)',0
		DB	'D-ËÎÌå48¡Á48   H-·ÂËÎ48¡Á48   L-ºÚÌå48¡Á48   P-¿¬Ìå48¡Á48 (ºá×ÝÀ©Ò»±¶)',0
		DB	'Q-16¡Á16(»ù±¾) R-32¡Á16(ºáÀ©) S-16¡Á32(×ÝÀ©) T-32¡Á32(ºá×ÝÀ©)',0
		DB	'U-40¡Á40(ËÎÌå) V-40¡Á40(·ÂËÎ) W-40¡Á40(ºÚÌå) X-40¡Á40(¿¬Ìå)',0
		DB	'a-ËÎÌå16¡Á24   e-·ÂËÎ16¡Á24   i-ºÚÌå16¡Á24   m-¿¬Ìå16¡Á24 (ºáËõ°ë±¶)',0
		DB	'b-ËÎÌå36¡Á24   f-·ÂËÎ36¡Á24   j-ºÚÌå36¡Á24   n-¿¬Ìå36¡Á24 (ºáÀ©°ë±¶)',0
		DB	'c-ËÎÌå24¡Á36   g-·ÂËÎ24¡Á36   k-ºÚÌå24¡Á36   o-¿¬Ìå24¡Á36 (×ÝÀ©°ë±¶)',0
		DB	'd-ËÎÌå36¡Á36   h-·ÂËÎ36¡Á36   l-ºÚÌå36¡Á36   p-¿¬Ìå36¡Á36 (ºá×ÝÀ©°ë±¶)',0
		DB	'q-16¡Á24(»ù±¾) r-32¡Á24(ºáÀ©) s-16¡Á48(×ÝÀ©) t-32¡Á48(ºá×ÝÀ©) ×ÝÏòÀ©24',0
		DB	'u-32¡Á32(ËÎÌå) v-32¡Á32(·ÂËÎ) w-32¡Á32(ºÚÌå) x-32¡Á32(¿¬Ìå)',0
		DB	'!×ÖºÅ±í!(180DPI.¿í¡Á¸ß):0-90¡Á90',0
		DB	'1-72¡Á72 10-80¡Á80 11-60¡Á80 12-80¡Á60 13-54¡Á72 14-72¡Á54',0
		DB	'2-48¡Á48 20-60¡Á60 21-45¡Á80 22-80¡Á45 23-36¡Á48 24-48¡Á36',0
		DB	'3-40¡Á40 30-44¡Á44 31-33¡Á44 32-44¡Á33 33-30¡Á40 34-40¡Á30',0
		DB	'4-32¡Á32 40-36¡Á36 41-27¡Á36 42-36¡Á27 43-24¡Á32 44-32¡Á24',0
		DB	'5-24¡Á24 50-28¡Á28 51-21¡Á28 52-28¡Á21 53-18¡Á24 54-24¡Á18',0
		DB	'6-20¡Á20 60-22¡Á22 61-16¡Á22 62-22¡Á16 63-15¡Á20 64-20¡Á15',0
		DB	'7-16¡Á16 70-18¡Á18 71-13¡Á18 72-18¡Á13 73-12¡Á16 74-16¡Á12',0,0

S_ZXZH		PROC	NEAR
		MOV	DI,OFFSET K_ZXZH
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_ZXB
		CALL	S_XSBT
		MOV	SI,OFFSET D_ZXB
		JMP	L_XSINRET		;ÏÔÊ¾´°¿ÚÄÚÈÝ²¢¼üÈë
S_ZXZH		ENDP
;----------------------------------------------------------------------------
T_PB		DB	'ÏµÍ³¼¶¹«ÎÄÅÅ°æ',0
D_PB		DB	"  `'°æºÅ,Ò³ºÅ` - ÉèÖÃÅÅ°æ(È¡ÏûÈí»Ø³µ¡¢ÐÐ½ûÔò¡¢Ò³ºÅ³õÖµ1)",0
		DB	'        ÓÐ°æºÅÔò°´ÅÅ°æ²ÎÊýÉèÖÃÒ³³¤¡¢×ó¿ÕºÍÐÐ¿í,·ñÔò±£³ÖÔ­Öµ',0
		DB	'        ÈôÓÐÒ³ºÅÔòÉèÖÃ³õÊ¼´òÓ¡Ò³ºÅ(È±Ê¡Îª1.Îª0Ôò²»´òÒ³ºÅ)',0
		DB	'  `,` - ÉèÖÃ±¾ÐÐ¾ÓÖÐ(°´µ±Ç°ÐÐ¿í)',0
		DB	'  `,,` - ÉèÖÃ±¾ÐÐ¾ÓÓÒ(°´µ±Ç°ÐÐ¿í)',0
		DB	'  `[[¿Õ¸ñÊý` - ¶ÎÅÅ°æµÚ¶þÐÐºóÐÐÊ×¼Ó¿Õ¸ñÊý',0
		DB	'  `:` - ´òÓ¡²ÎÊý³õÊ¼»¯.ÈôÔ­ÅÅ°æÔò´òÓ¡Ä©Ò³Ò³ºÅ',0
		DB	'  `@×ÖÐÍ` - ÖÃµãÕóºº×Ö×ÖÐÍ(A~x,Ä¬ÈÏA)',0
		DB	'  `@@×ÖºÅ,×ÖÌå` - ÉèÖÃ×ÖºÅ(PRTH¿É°´·Ö±æÂÊDPI×Ô¶¯ÕÛËã)',0
		DB	'  `&ÐÐ¾à` - ÖÃÐÐ¾à(1~255,Ä¬ÈÏ20)',0
		DB	'  `^ÁÐÊý` - ÖÃ×Ö·û¼ä¾à(0~255,ºº×Ö¼Ó±¶,Ä¬ÈÏ0.µ¥Î»:µã)',0
		DB	'  `#Ò³³¤` - ÖÃÒ³³¤(µ¥Î»µã.Ä¬ÈÏÖ½³¤)',0
		DB	'  `##` - Ïò´òÓ¡»úËÍ»»Ò³·û(Ç¿ÖÆ»»Ò³)',0
		DB	'  `[×Ö·ûÊý` - ÖÃ×ó±ß¿Õ(0~2447,Ä¬ÈÏ0.ÒÔµãÎªµ¥Î»)',0
		DB	'  `]×Ö·ûÊý` - ÖÃÐÐ¿í(1~2448,ÒÔµãÎªµ¥Î».Ä¬ÈÏ×î¿í)',0
		DB	"Àý: `'1&30",0
		DB	'    `,@W`Í¨  Öª',0
		DB	'    `@X',0
		DB	'        ¸ù¾ÝÊÐÈËÃñÕþ¸®Í¨Öª¾«Éñ,½áºÏÎÒµ¥Î»¾ßÌåÇé¿ö,×Ô',0
		DB	'    ±¾ÔÂ29ÈÕÖÁ10ÔÂ4ÈÕ·Å¼Ù6Ìì,10ÔÂ5ÈÕ(ÐÇÆÚÈý)ÉÏ°à¡£',0
		DB	'        ÌØ´ËÍ¨Öª¡£',0
		DB	'    `,,@U¡Á¡Á³§°ì¹«ÊÒ  `',0,0

S_XTPB		PROC	NEAR
		MOV	DI,OFFSET K_XTPB
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_PB
		CALL	S_XSBT
		MOV	SI,OFFSET D_PB
		JMP	L_XSINRET		;ÏÔÊ¾´°¿ÚÄÚÈÝ²¢¼üÈë
S_XTPB		ENDP
;----------------------------------------------------------------------------
T_TSXS		DB	'2.13LÌØÊâÏÔÊ¾¹¦ÄÜ',0
D_TSXS1 	DB	'CÉ«ºÅ,Ìî³äÉ«] - ÉèÖÃÍ¼ÐÎÑÕÉ«          DµãX,Y] - »­µã',0
		DB	'E¿í¶È] - ÏòÓÒÉÏ»­Ïß                   U³¤¶È] - ÏòÉÏ»­Ïß',0
		DB	'F¿í¶È] - ÏòÓÒÏÂ»­Ïß                   X¸ß¶È] - ÏòÏÂ»­Ïß',0
		DB	'G¿í¶È] - Ïò×óÏÂ»­Ïß                   Y³¤¶È] - ÏòÓÒ»­Ïß',0
		DB	'H¿í¶È] - Ïò×óÉÏ»­Ïß                   Z³¤¶È] - Ïò×ó»­Ïß',0
		DB	'LÖÕµãX,Y] - »­Ð±Ïß(ÈôXÓÐ·ûºÅÔòÎªÏà¶Ôµ±Ç°µãµÄÏà¶Ô×ø±ê)',0
		DB	'L/³¤¶È,½Ç¶È] - °´½Ç¶È»­Ïß(ÒÔÏòÓÒÎª0¶È,²»ÒÆµ±Ç°µã)',0
		DB	'B¿í,¸ß] - »­¾ØÐÎ(µ±Ç°µãÎª×óÏÂ½Ç.¿í»ò¸ß=0²»»­,¿íºÍ¸ß¶¼=0»­ÆÁÄ»±ß¿òÏß',0
		DB	'   ÈôCÃüÁîÖ¸¶¨ÁËÌî³äÉ«Ôò¾ØÐÎÖÐÌî³äÖ¸¶¨ÑÕÉ«',0
		DB	'VÉ«ºÅ,×óÏÂ½ÇX,Y,¿í,¸ß,ÀàÐÍ,¼ä¸ô,Ïß¿í,·½Ê½] - ¾ØÐÎÇøÌîÏß      /,0=²»»­',0
		DB	'   ÆäÖÐ:ÀàÐÍ=1ºáÏß,=2ÊúÏß,=3×óÐ±Ïß,=4ÓÒÐ±Ïß.·½Ê½=1»­±ß¿òÏß(CÃüÁîÖ¸¶¨ÑÕÉ«)',0
		DB	'OÔ²ÐÄX,Y,°ë¾¶,·½Ê½] - »­Ô²(INT10K).ÈôCÃüÁîÖ¸¶¨ÁËÌî³äÉ«ÔòÔ²ºÍ°ëÔ²ÖÐÌî³ä',0
		DB	'   ÆäÖÐ:·½Ê½ÏîËÄÉáÎåÈëºó=0Ôò»­°ëÔ²,=1»­°ëÔ²»¡,·ñÔò»­ÕûÔ²',0
		DB	'OÔ²ÐÄX,Y,³¤°ë¾¶,·½Ê½,¶Ì°ë¾¶,ÆðÊ¼½Ç,ÖÕÖ¹½Ç,±êÖ¾] - »­Ô²,ÍÖÔ²»òÔ²»¡(INT10V)',0
		DB	'   ÆäÖÐ:·½Ê½=0Îª°ëÔ²,=1Îª°ëÔ²»¡,µÈÓÚÆäËüÖµºÍÈ±Ê¡Ê±ÎªÔ²)',0
		DB	'        ±êÖ¾=1»­»¡,=0»­ÉÈÐÎ(»¡¶ÏµãÓëÔ²ÐÄÓÐÁ¬Ïß). Ìî³äÑÕÉ«ÓÉCÃüÁîÖ¸¶¨',0
		DB	'K±ÈÀýÒò×Ó] - ÉèÖÃ±ÈÀýÒò×Ó(1~255,Êµ¼ÊÒª/16)',0
		DB	'J] - Ö´ÐÐÃüÁî´®                       W...] - ¶¨ÒåÃüÁî´®(ÃüÁîÐÐ×îºó)',0,0

D_TSXS2 	DB	'PÄÚÉ«ºÅ,±ß½çÉ«ºÅ] - Ìî³ä',0
		DB	'M...] - Ç°×º£ºÒÆµ±Ç°µãµ«²»»­Ïß»òµã    N...] - Ç°×º£º»­Ïßµ«²»ÒÆµ±Ç°µã',0
		DB	'_ÐÐ,ÁÐ,³¤] - °´×Ö·ûÐÐÁÐ»­ºáÏß         |ÐÐ,ÁÐ,³¤] - °´×Ö·ûÐÐÁÐ»­ÊúÏß',0
		DB	'#ÐÐ,ÁÐ,¸ß,¿í,·½Ê½] - °´×Ö·ûÐÐÁÐ»­¿òÏß(ÈôÓÐ·½Ê½,ÔòÏòÀïËõ½ø4µã)',0
		DB	'QÉ«ºÅ] - ÇåÆÁ(ÈôÎÞÉ«ºÅÔò³õÊ¼»¯¹¤×÷²ÎÊý.ÈôÓÐ¡°É«ºÅ¡±Ôò°´´ËÑÕÉ«ÇåÆÁ)',0
		DB	'R¿ØÖÆ×Ö] - ¹â±ê¿ØÖÆ(ÆæÊý½¨Á¢,Å¼ÊýÈ¡Ïû)',0
		DB	'I²ÎÊý´®] - Ö´ÐÐINT10ÖÐ¶Ï(ÆäÖÐ:²ÎÊý´®Îª¼Ä´æÆ÷ AH,AL,BH,BL,CH,CL,DH,DL)',0
		DB	'   µ±µÚÒ»²ÎÊýÎª255Ê±,µÚ¶þ²ÎÊý¾ÍÊÇÖ´ÐÐµÄÖÐ¶ÏºÅ,ÒÔÏÂË³ÐòÎªAH,AL,BH...',0
		DB	'   ÈôÓÐ·µ»Ø²ÎÊýÔòÌîÈë40:0F0H¿ªÊ¼µÄ14¸öµ¥ÔªÀï,Ë³ÐòÎª:AX,BX,CX,DX,BP,SI,DI',0
		DB	'SÇ°¾°É«,±³¾°É«] - ÉèÖÃ×Ö·ûºÍºº×ÖÑÕÉ«',0
		DB	'*ÐÐ,ÁÐ,×Ö·ûÊý,Ç°¾°É«,±³¾°É«] - ÖØÏÔÆÁÄ»ÉÏµÄ×Ö·û´®',0
		DB	'AÀ©Õ¹ASCIIÂë] - Ä£Äâ¹¦ÄÜ¼ü(²Î¿´SETUP¹¦ÄÜ¼üÉèÖÃ)',0
		DB	'%¹¦ÄÜ·û»òÒô·û] - ÑÝ×àÒôÀÖ(ÃüÁîÐÐ×îºó)',0
		DB	'   ÆäÖÐ:¹¦ÄÜ·ûÎª   t½ÚÅÄ    Ö¸¶¨½ÚÅÄ(Ä¬ÈÏ100,Ã¿·ÖÖÓ½ÚÅÄÊý)',0
		DB	'        CDEFGAB  ¶¨µ÷(¿ª»úÎªCµ÷)     1234567  ÒôÃû   0  ÐÝÖ¹·û',0
		DB	'        #  Éý°ëÒô       b  ½µ°ëÒô    q  Éý°Ë¶È       d  ½µ°Ë¶È',0
		DB	'        .  ¸½µã         -  ÑÓ³¤Òô    _  °Ë·ÖÒô·û     =  Ê®Áù·ÖÒô·û',0
		DB	'   ×¢:Éý½µ°Ë¶È¡¢Éý½µ°ëÒôÔÚÒôÃûÇ°£¬ÑÓ³¤¡¢¸½µã¡¢ËÄ°Ë·ÖÒô·ûÔÚÒôÃûºó',0,0

D_TSXS3 	DB	'£¡ÃëÊý - ÑÓÊ± µ¥Î»:Ãë.·¶Î§:0-4096      T0»ò1] - ¼ò·±ÏÔÊ¾ÇÐ»»(1¼ò0·±)',0
		DB	'^´ÎÊý] - ÉèÖÃÑÝ×à´ÎÊý,ÎÞ´ÎÊýÔò´ò¿ª»ò¹Ø±ÕÒôÀÖ',0
		DB	'@×óÉÏ½Ç×Ö·ûÁÐ,É¨ÃèÏßÐÐ,Í¼ÏóÎÄ¼þÃû$] - ÏÔÊ¾16É«PCX¸ñÊ½Í¼Ïó',0
		DB	'~X1,Y1,X2,Y2,Í¼ÏóÎÄ¼þÃû$] - ±£´æ16É«PCX¸ñÊ½Í¼Ïó',0
		DB	'   ÆäÖÐ:X1ÎªÍ¼Ïó×óÉÏ½Ç×Ö·ûÁÐ(0-79), Y1Îª×óÉÏ½Ç×Ý×ø±ê(0-479)',0
		DB	'        X2ÎªÍ¼ÏóÓÒÏÂ½Ç×Ö·ûÁÐ(1-79), Y2ÎªÓÒÏÂ½Ç×Ý×ø±ê(1-479)',0
		DB	'        Í¼ÏóÎÄ¼þÀ©Õ¹ÃûÓ¦ÎªPCX,Æäºó±ØÐëÓÐ$·û',0
		DB	'[¹¦ÄÜ·û¡¢ºº×Ö»ò×Ö·û] - ÏÔÊ¾ºº×Ö»ò×Ö·û(ÃüÁîÐÐ×îºó).ÒÔÏÂÎª¹¦ÄÜ·û:',0
		DB	'   @×ÖÐÍ  Ö¸¶¨×ÖÐÍ(¿ª»ú×ÖÐÍA)',0
		DB	'   ¸ñÊ½Ò»:×ÖÐÍÎª×ÖÄ¸A-X,a-x(A-PÍ¬´òÓ¡,a~pÎªA~Pºá×ÝÀ©,Q~T»òu~xÎª16µãÕó)',0
		DB	'   ¸ñÊ½¶þ:×ÖÐÍÎªÊ¸Á¿ºº×ÖµÄÈý¸ö²ÎÊý(ÓÃ¶ººÅ¸ô¿ª).½öINT10KºÍINT10V',0
		DB	'       µÚÒ»¸öÎªºáÏòµãÊý(·¶Î§:4~639), µÚ¶þ¸öÎª×ÝÏòµãÊý(·¶Î§:4~479)',0
		DB	'       µÚÈý¸öÊýÎªÊ¸Á¿×ÖÌåºÅ(ÈôÈ±Ê¡Ôò±£³ÖÔ­Öµ)',0
		DB	'   ^¼ä¾à  Ö¸¶¨×Ö·û¼ä¾à(0-255,ºº×Ö¼ä¾à¼Ó±¶,¿ª»úÎª0)',0
		DB	'   &¼ä¾à  Ö¸¶¨ÐÐ¼ä¾à(0-255,¿ª»úÎª1)',0
		DB	'   _µãÊý  Ë®Æ½¶¨Î»(0-639,¿ª»úÎª0)      |µãÊý  ´¹Ö±¶¨Î»(0-479,¿ª»úÎª0)',0
		DB	'   *É«ºÅ  Ç°¾°ÑÕÉ«(0-15,¿ª»ú×î´ó)      #É«ºÅ  ±³¾°ÑÕÉ«(0-15,¿ª»úÎª0)',0
		DB	'   \0»ò1  0Îªºº×Ö±³¾°¸´¸ÇÔ­Í¼ÐÎ,1²»¸´¸Ç(¿ª»úÎª²»¸´¸Ç)',0,0
D_TSXS		DB	0			;´°¿ÚÒ³ºÅ

S_TSXS		PROC	NEAR
		MOV	SI,OFFSET D_TSXS1	;µÚÒ»Ò³
		CMP	D_TSXS,0
		JZ	L_TSXS1
		MOV	SI,OFFSET D_TSXS2	;µÚ¶þÒ³
		CMP	D_TSXS,1
		JZ	L_TSXS1
		MOV	SI,OFFSET D_TSXS3	;µÚÈýÒ³
L_TSXS1:
		PUSH	SI
		MOV	DI,OFFSET K_TSXS
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_TSXS
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;ÏÔÊ¾´°¿ÚÄÚÈÝ
		MOV	DH,D_TSXS
		MOV	DL,2			;×î´óÒ³ºÅ
		CALL	S_PAGE			;´¦ÀíÒ³
		MOV	D_TSXS,AL
		JMP	SHORT S_TSXS
S_TSXS		ENDP
;----------------------------------------------------------------------------
T_TSDY		DB	'ÌØÊâ´òÓ¡¹¦ÄÜ',0
D_TSDY1 	DB	'`@×ÖÐÍ` - ÖÃµãÕóºº×Ö×ÖÐÍ(A~x,Ä¬ÈÏA)',0
		DB	'`@×ÖÐÍ` - ÖÃÊ¸Á¿ºº×Ö×ÖÐÍ(×ÖÐÍÎªÈý¸öÊý:¿í,¸ß,×ÖÌåºÅ)',0
		DB	'    ÆäÖÐ: ¿í»ò¸ß·¶Î§1~255.×ÖÌåºÅÇë²Î¼ûÊ¸Á¿ºº×Ö±í¡£È±Ê¡Ô­Öµ²»±ä)',0
		DB	'`@@×ÖºÅ,×ÖÌå` - ÉèÖÃ×ÖºÅ(PRTH¿É°´·Ö±æÂÊDPI×Ô¶¯ÕÛËã)',0
		DB	'    ×ÖºÅ:0-90,1-72,2-48,3-40,4-32,5-24,6-20,7-16(¿í=¸ß.Îª180DPI)',0
		DB	'    Ê®Î»ÊýÎª1~7,¸öÎ»>0ÆæÊý¸ßÎªÔ­¸ßµÄ3/4,Å¼Êý¿íÎªÔ­¿íµÄ3/4',0
		DB	'    ¸öÎ»<3Îª´óºÅ×Ö:´ó1=80,´ó2=60,´ó3=44,´ó4=36,´ó5=28,´ó6=22,´ó7=18',0
		DB	'`@/»ò\` - ´ò¿ª°´·Ö±æÂÊÕÛËã(PRTH:@/½ö×ÖÐÍºÍ×Ö¾à,@&»¹ÓÐÐÐ¾à,@\¹Ø±Õ)',0
		DB	'`@-»ò=` - ÖÃ¶àÐÐ×ÖµÄ¿ÕÐÐ¿ÕÒ»ÐÐ(-,Ä¬ÈÏ)»ò¶àÐÐ(=)',0
		DB	'`@<»ò>` - ÖÃ¶àÐÐ×ÖË«Ïò»òµ¥Ïò´òÓ¡(Ä¬ÈÏµ¥Ïò(PRTHÎÞÐ§)',0
		DB	'`&ÐÐ¾à` - ÖÃÐÐ¾à(1~255)',0
		DB	'`&A»òB` - ÉèÖÃÐÐ¾àµ¥Î»:A-1/180Ó¢´ç,B-1/120Ó¢´ç(Ä¬ÈÏ.½öPRNT)',0
		DB	'`&C` - ÉèÖÃÎªÐÐ¼ä¾à1/180Ó¢´ç(´ËÊ±&ÐÐ¼ä¾à¿ÉÓÃ¸ºÊý.ÐÐ¼ä¾à+24=ÐÐ¾à)',0
		DB	'`&D` - ÉèÖÃÎªÐÐ¼ä¾à1/120Ó¢´ç(´ËÊ±&ÐÐ¼ä¾à¿ÉÓÃ¸ºÊý.ÐÐ¼ä¾à+16=ÐÐ¾à)',0
		DB	'`^ÁÐÊý` - ÖÃ×Ö·û¼ä¾à(0~255,ºº×Ö¼Ó±¶,Ä¬ÈÏ0.µ¥Î»:µã)',0
		DB	'`#Ò³³¤` - ÖÃÒ³³¤(PRNT:0-255ÐÐ.Ä¬ÈÏ0;PRTH:0~65535µã.Ä¬ÈÏµ¥Ò³Ö½³¤)',0
		DB	'`##` - Ïò´òÓ¡»úËÍ»»Ò³·û(Ç¿ÖÆ»»Ò³)[µ±ÉèÎªÐÐ¼ä¾àÊ±¿ÉÓÃ`E`]',0
		DB	'`*ÐÐÊý` - ÖÃÒ³¼ä¿ÕÐÐ(0~255,Ä¬ÈÏ0.PRTHÎÞ´Ë¹¦ÄÜ)',0,0

D_TSDY2 	DB	'`*` - ÇåÒÑ×ßÖ½(½öPRTH)',0
		DB	'`[×Ö·ûÊý` - ÖÃ×ó±ß¿Õ(0~2447,Ä¬ÈÏ0.ÒÔµãÎªµ¥Î»)',0
		DB	'`]×Ö·ûÊý` - ÖÃÐÐ¿í(1~2448,ÒÔµãÎªµ¥Î».Ä¬ÈÏ×î¿í)',0
		DB	'`~ÁÐÊý` - Êä³ö¿ÕÁÐ(0~2447.Ò»´ÎÓÐÐ§)',0
		DB	'`|ÁÐÊý` - Ë®Æ½¶¨Î»(1~2447.µ±Ç°ÐÐÓÐÐ§)',0
		DB	'`%0~7` - ÖÃ±³¾°:0ÎÞ,1Íøµã,2Íø¸ñ,3ºáÏß,4ÊúÏß,5ÓÒÐ±Ïß,6×óÐ±Ïß,7½»²æÏß',0
		DB	'`"É«ºÅ` - ÖÃÑÕÉ«(LQ2500¡¢M1570ÓÃ,0ºÚ,1ºì,2À¶,3×Ï,4»Æ,5³È,6ÂÌ',0
		DB	'`$...$` - ½«¶þ$¼ä×Ö·ûÖ±ËÍ´òÓ¡»ú',0
		DB	'`>`»òESC+I+> - ÖÃµ¥Ïò´òÓ¡(PRTHÎÞ)',0
		DB	'`<`»òESC+I+< - ÖÃË«Ïò´òÓ¡(PRTHÎÞ)',0
		DB	'`;` (·ÖºÅ) - ÖÃ³éµã´òÓ¡(Çá´ò)',0
		DB	'`\` (·´Ð±Ïß) - ÖÃ·´°×´òÓ¡',0
		DB	'`/` (Ð±Ïß) - ÖÃÉÏ»®Ïß´òÓ¡',0
		DB	'`_` (ÏÂ»®Ïß) - ÖÃÏÂ»®Ïß´òÓ¡',0
		DB	'`=` (µÈºÅ) - ÖÃÕý³£´òÓ¡(¿ª»ú×´Ì¬,ÇåÒÔÉÏËÄÏî)',0
		DB	'`(` (×óÀ¨ºÅ) - ÖÃ×óÐý90¶È´òÓ¡',0
		DB	'`)` (ÓÒÀ¨ºÅ) - ÖÃÓÒÐý90¶È´òÓ¡',0
		DB	'`?` (ÎÊºÅ) - ÖÃ½áÊøÐý×ª(¿ª»ú×´Ì¬,ÇåÒÔÉÏ¶þÏî)',0,0

D_TSDY3 	DB	'`+` (¼ÓºÅ) - ÖÃÉÏ±ê×Ö·û',0
		DB	'`-` (¼õºÅ) - ÖÃÏÂ±ê×Ö·û',0
		DB	'`£¡` (¾ªÌ¾ºÅ) - ÖÃÕý³£×Ö·û(¿ª»ú×´Ì¬,ÇåÒÔÉÏ¶þÏî)',0
		DB	'`.` (Ð¡Êýµã) - ÔÝÍ£´òÓ¡(°´ÈÎÒ»¼ü¼ÌÐø)',0
		DB	"`'°æºÅ,Ò³ºÅ` (µ¥ÒýºÅ) - ÉèÖÃÅÅ°æ(È¡ÏûÈí»Ø³µ¡¢ÐÐ½ûÔò¡¢Ò³ºÅ³õÖµ1)",0
		DB	'    ÓÐ°æºÅÔò°´ÅÅ°æ²ÎÊýÉèÖÃÒ³³¤¡¢×ó¿ÕºÍÐÐ¿í,·ñÔò±£³ÖÔ­Öµ(ÐèÖØÐÂÉèÖÃ)',0
		DB	'    ÈôÓÐÒ³ºÅÔòÉèÖÃ³õÊ¼´òÓ¡Ò³ºÅ(È±Ê¡Îª1.Îª0Ôò²»´òÒ³ºÅ)',0
		DB	'`,` (¶ººÅ) - ÉèÖÃ±¾ÐÐ¾ÓÖÐ(°´µ±Ç°ÐÐ¿í)',0
		DB	'`,,` (Á½¸ö¶ººÅ) - ÉèÖÃ±¾ÐÐ¾ÓÓÒ(°´µ±Ç°ÐÐ¿í)',0
		DB	'`[[¿Õ¸ñÊý` - ¶ÎÅÅ°æµÚ¶þÐÐºóÐÐÊ×¼Ó¿Õ¸ñÊý',0
		DB	'`:` (Ã°ºÅ) - ´òÓ¡²ÎÊý³õÊ¼»¯.ÈôÔ­ÅÅ°æÔò´òÓ¡Ä©Ò³Ò³ºÅ',0
		DB	'ESC+I+N1+N2 - Í¼Ïó´òÓ¡ N1¸ß×Ö½Ú,N2µÍ×Ö½Ú.ºó¸ú(N1*256+N2)*3×Ö½ÚÊý¾Ý',0
		DB	'ESC+I+A~x - ÖÃ×ÖÐÍ(A~x)',0
		DB	'ESC+I+£§ - È¡ÏûÌØÊâ´òÓ¡¹¦ÄÜ',0
		DB	'ESC+I+£à - »Ö¸´ÌØÊâ´òÓ¡¹¦ÄÜ(¿ª»ú×´Ì¬)',0
		DB	'ESC+I+\  - È¡ÏûWSÈí»Ø³µ(8DHºÍ0AH)',0
		DB	'ESC+I+/  - »Ö¸´WSÈí»Ø³µ8DHÎª0DH(¿ª»ú×´Ì¬)',0
		DB	'ESC+W - Ö´ÐÐÆÁÄ»¿½±´',0,0
D_TSDY		DB	0			;Ò³ºÅ

S_TSDY		PROC	NEAR
		MOV	SI,OFFSET D_TSDY1	;µÚÒ»Ò³
		CMP	D_TSDY,0
		JZ	L_TSDY1
		MOV	SI,OFFSET D_TSDY2	;µÚ¶þÒ³
		CMP	D_TSDY,1
		JZ	L_TSDY1
		MOV	SI,OFFSET D_TSDY3	;µÚÈýÒ³
L_TSDY1:
		PUSH	SI
		MOV	DI,OFFSET K_TSDY
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_TSDY
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;ÏÔÊ¾´°¿ÚÄÚÈÝ
		MOV	DH,D_TSDY
		MOV	DL,2
		CALL	S_PAGE			;´¦ÀíÒ³
		MOV	D_TSDY,AL
		JMP	SHORT S_TSDY
S_TSDY		ENDP
;----------------------------------------------------------------------------
T_INT10 	DB	'ÏÔÊ¾ÖÐ¶Ï¹¦ÄÜµ÷ÓÃ',0
D_INT1		DB	'AH=0,AL=ÏÔÊ¾·½Ê½ºÅ - ÉèÖÃÏÔÊ¾·½Ê½',0
		DB	'AH=1,CH=¹â±êÆðÊ¼Ïß,CL=½áÊøÏß - Éè¶¨¹â±ê´óÐ¡',0
		DB	'AH=2,BH=Ò³ºÅ,DH=ÐÐºÅ,DL=ÁÐºÅ - Éè¶¨¹â±êÎ»ÖÃ',0
		DB	'AH=3,BH=Ò³ºÅ - È¡¹â±êÎ»ÖÃ  ·µ»Ø:DH=ÐÐºÅ,DL=ÁÐºÅ,CX=¹â±ê´óÐ¡',0
		DB	'AH=4(²Î¿´BIOSÊÖ²á) - È¡¹â±ÊÎ»ÖÃ (ROM-BIOS)',0
		DB	'AH=5,AL=Ò³ºÅ - ¸Ä±äµ±Ç°ÏÔÊ¾Ò³',0
		DB	'AH=6,AL=ÐÐÊý(=0È«¹ö),BH=¿ÕÐÐÌî³äÊôÐÔ - ÉÏ¹öµ±Ç°Ò³',0
		DB	'     CH=¹ö¶¯´°¿Ú×óÉÏ½ÇÐÐºÅ,CL=ÁÐºÅ,DH=¹ö¶¯´°¿ÚÓÒÏÂ½ÇÐÐºÅ,DL=ÁÐºÅ',0
		DB	'AH=7(ÆäËü²ÎÊýÍ¬ÉÏ) - ÏÂ¹öµ±Ç°Ò³',0
		DB	'AH=8,BH=Ò³ºÅ -È¡¹â±êÎ»ÖÃ×Ö·û¼°ÊôÐÔ  ·µ»Ø:AL=ASCIIÂë,AH=ÊôÐÔ',0
		DB	'AH=9,AL=ASCÂë,BH=Ò³ºÅ,BL=ÊôÐÔ,CX=×Ö·û¸öÊý - ÔÚµ±Ç°¹â±êÎ»ÖÃÏÔÊ¾×Ö·û¼°ÊôÐÔ',0
		DB	'AH=0AH(ÊôÐÔÈ¡µ±Ç°Î»ÖÃÔ­Öµ,ÆäËü²ÎÊýÍ¬ÉÏ) - ÔÚµ±Ç°¹â±êÎ»ÖÃÏÔÊ¾×Ö·û',0
		DB	'AH=0BH(²Î¿´BIOSÊÖ²á) - ÖÃÆÁÄ»²ÊÉ«(CGAÓÃ)',0
		DB	'AH=0CH,AL=É«ºÅ,CX=X×ø±ê,DX=Y×ø±ê - ÔÚÖ¸¶¨×ø±ê´¦Ð´µã',0
		DB	'AH=0DH,CX=X×ø±ê,DX=Y×ø±ê - ÔÚÖ¸¶¨×ø±ê´¦¶Áµã  ·µ»Ø:AL=É«ºÅ',0
		DB	'AH=0EH,AL=ASCÂë - ÒÔTTY·½Ê½ÏÔÊ¾×Ö·û',0
		DB	'AH=0FH - È¡µ±Ç°ÏÔÊ¾·½Ê½  ·µ»Ø:AL=ÏÔÊ¾·½Ê½,AH=ÐÐ×Ö·ûÊý,BH=µ±Ç°Ò³ºÅ',0
		DB	'AH=10H(²Î¿´BIOSÊÖ²á) - ÉèÖÃEGA»òVGAµ÷É«°å (ROM-BIOS)',0
		DB	'AH=11H(²Î¿´BIOSÊÖ²á) - ÉèÖÃEGA»òVGA×Ö·û¼¯ (ROM-BIOS)Ä¬ÈÏ½öAL=30HÓÐÐ§',0
		DB	'AH=12H(²Î¿´BIOSÊÖ²á) - È¡EGAVGA¿¨¹¤×÷×´Ì¬ (ROM-BIOS)',0,0

D_INT2		DB	'AH=13H,ES:BP=×Ö·û´®Ê×Ö·(AL=5²»ÓÃ),DX=Î»ÖÃ,CX=´®³¤,BH=Ò³ºÅ - ÏÔÊ¾×Ö·û´®',0
		DB	'    AL=0 BL=ÊôÐÔ   ÏÔÊ¾ºó¹â±ê²»±ä',0
		DB	'    AL=1 BL=ÊôÐÔ   ÏÔÊ¾ºó¹â±êÒÆ´®Î²',0
		DB	'    AL=2 ´®º¬ÊôÐÔ  ÏÔÊ¾ºó¹â±ê²»±ä',0
		DB	'    AL=3 ´®º¬ÊôÐÔ  ÏÔÊ¾ºó¹â±êÒÆ´®Î²',0
		DB	'    AL=4 BL=ÊôÐÔ   ´®ÒÔ0½áÎ² ÏÔÊ¾ºó¹â±êÒÆ´®Î²',0
		DB	'    AL=5 BL=ÐÂÊôÐÔ ÖØÏÔÆÁÄ»ÉÏÒÑÓÐ×Ö·û´®,ÏÔÊ¾ºóÔ­¹â±êÎ»ÖÃ²»±ä',0
		DB	'AH=14H - ÌáÊ¾ÐÐ²Ù×÷',0
		DB	'    AL=0 - ´ò¿ª»òÇåÌáÊ¾ÐÐ',0
		DB	'    AL=1,DL=×Ö·ûÂë,CL=¸öÊý - ÏÔÊ¾×Ö·û',0
		DB	'    AL=2,DL=ÌáÊ¾ÐÐÎ»ÖÃ - ÌáÊ¾ÐÐ¹â±ê¶¨Î»',0
		DB	'    AL=3,DL=×Ö·ûÂë - ÏÔÊ¾×Ö·ûDL²¢ÍÆ½ø¹â±ê  ¹¦ÄÜ·û½ö7ºÍ8ÓÐÐ§',0
		DB	'    AL=4 - ¹Ø±ÕÌáÊ¾ÐÐ',0
		DB	'    AL=5,BH=ÌáÊ¾ÐÐ¸¡¶¯ÐÐºÅ(VGAÎÞÐ§),BL=ÌáÊ¾ÐÐ¹â´øÉ«(=0ÎÞ¹â´ø,½öVGA)',0
		DB	'    AL=6 - È¡ÏÔÊ¾²ÎÊý  AL=ÏÔÊ¾·½Ê½, AH=×î´óÉ«ºÅ, BH=ÌáÊ¾ÐÐ¸¡¶¯Î»ÖÃ',0
		DB	'           BL=4ÔÊÐíÖ±½ÓÐ´ÆÁ,=0·Ç, CL=ÏÔÊ¾ÐÐÊý, CH=Ã¿ÐÐÉ¨ÃèÏßÊý',0
		DB	'           SI=ºáÏòµãÊý-1, DI=×ÝÏòµãÊý-1, BP=ÏÔÊ¾»º³åÇø¶Î',0
		DB	'           DL=ÏÔÊ¾¿ØÖÆ²ÎÊý,DH=µ±Ç°ÌáÊ¾ÐÐÎ»ÖÃ',0
		DB	'      DL:Î»3=0:16µãÕó,Î»0=0·±Ìå,·Ç0¼òÌå',0
		DB	'         Î»7=1Ö±½ÓÐ´ÆÁ,Î»6=1±£³ÖÌáÊ¾ÐÐ,Î»5=1À©Õ¹×Ö·û¿â,Î»4-ÏÔÊ¾·½Ê½>5¼´ºº×Ö',0,0

D_INT3		DB	'    AL=7 - ÉèÖÃ¶ÔÍâÏÔÊ¾·½Ê½BH',0
		DB	'    AL=8 - Î»ÖÃDX´¦×Ö·û·´ÏàÏÔÊ¾',0
		DB	'    AL=9 - ÔÚÎ»ÖÃDX´¦ÏÔÊ¾×Ö·ûBH, ÊôÐÔÎªBL, CX=0°´×Ö·ûÏÔÊ¾,·Ç0¿ÉÏÔÊ¾ºº×Ö',0
		DB	'    AL=0AH - ÔÚÌáÊ¾ÐÐÖ¸¶¨Î»ÖÃDLÏÔÊ¾BLÊôÐÔBP:SI´¦µÄµãÕó64×Ö½Ú',0
		DB	'    AL=0BH - ¹â±êÉÁË¸¿ØÖÆ  BH=0²»,·Ç0ÉÁË¸',0
		DB	'    AL=0CH - È¡ÐéÆÁÇøµØÖ·  BX:AX (ÔÙ+25*80*2¾ÍÊÇÀ©Õ¹×Ö·û¿âÊ×µØÖ·)',0
		DB	'    AL=0DH - Ö±½ÓÐ´ÆÁÖÜÆÚBH  È¡Öµ·¶Î§1-8',0
		DB	'    AL=0EH - È¡Î÷ÎÄÖÆ±í·û×ª»»Âë±íµØÖ· BX:AX',0
		DB	'    AL=0FH - ÔÚÖ¸¶¨Î»ÖÃDXÏÔÊ¾¼Ó¿í×Ö·û´®DS:SI(ÒÔ0½áÎ²,ÊôÐÔÎªBL)',0
		DB	'    AL=10H - ´ò¿ªµÚ¶þÌáÊ¾ÐÐ BL=Ö¸¶¨ÑÕÉ«(½öVGA,ÏÂÍ¬)',0
		DB	'    AL=11H - ÔÚµÚ¶þÌáÊ¾ÐÐÏÔÊ¾×Ö·ûDL CL=¸öÊý,BL=ÑÕÉ«',0
		DB	'    AL=12H - µÚ¶þÌáÊ¾ÐÐ¹â±ê¶¨Î»DL',0
		DB	'    AL=13H - ÔÚµÚ¶þÌáÊ¾ÐÐÏÔÊ¾×Ö·ûDL²¢ÍÆ½ø¹â±ê BL=ÑÕÉ«',0
		DB	'    AL=14H - ¹Ø±ÕµÚ¶þÌáÊ¾ÐÐ',0
		DB	'AH=15H,AL=1Çå³ý,=0ÏÔÊ¾ - ÏÔÊ¾¹â±ê',0
		DB	'AH=16H,DX=ºº×ÖÄÚÂë(×Ö·ûDH=0),BP:BX=Ð´ÈëµØÖ· - ¶ÁÏÔÊ¾×ÖÄ£µãÕó',0
		DB	'    ÆäÖÐ:×Ö·û16×Ö½Ú,ºº×Ö32×Ö½Ú(0-15×Ö½ÚÎª×ó°ë×Ö,16-31ÎªÓÒ°ë×Ö)',0
		DB	'AH=17H,AL=0È¡Ïû,·Ç0½¨Á¢ - ½¨Á¢£¯È¡Ïû¹â±ê',0
		DB	'AH=18H - ÏµÍ³¿ª¹Ø',0
		DB	'    AL=0Ê¶±ðºº×Ö            AL=1²»Ê¶ºº×Ö',0,0

D_INT4		DB	'    AL=2ÊôÐÔ¸ßÎ»¸ßÁÁ        AL=3Òì»ò',0
		DB	'    AL=4²»ÔÊÐíÉèÖÃÏÔÊ¾·½Ê½  AL=5ÔÊÐíÉèÖÃÏÔÊ¾·½Ê½',0
		DB	'    AL=8²»ÔÊÐíÉèÖÃÉÁË¸      AL=9ÔÊÐíÉèÖÃÉÁË¸(AH=10H,BL=3)',0
		DB	'    AL=0AH¹Ø±ÕÖ±½ÓÐ´ÆÁ      AL=0BH»Ö¸´Ö±½ÓÐ´ÆÁ',0
		DB	'    AL=0CHÎ÷ÎÄÖÆ±í·û´¦Àí·½Ê½BH',0
		DB	'    AL=0DH¹â±ê¿ØÖÆ BH=1ÓÉAH=1ÉèÖÃ, =0¹Ì¶¨¹â±ê´óÐ¡BL',0
		DB	'    AL=0EHÏÔÊ¾·½Ê½>=6Îªºº×Ö AL=0FH»Ö¸´Ô­·½Ê½',0
		DB	'    AL=10HÉèÖÃ×Ö·ûÉÁË¸      AL=11H·±Ìå           AL=12H¼òÌå',0
		DB	'    AL=13HÖØÏÔÆÁÄ»          AL=14H¹Ø±ÕÊ±ÖÓÏÔÊ¾   AL=15H»Ö¸´Ê±ÖÓÏÔÊ¾',0
		DB	'    AL=16HÉèÖÃÆÁÄ»ÑÕÉ«:BH-Ç°¾°,BL-±³¾°,CH-±ß¿ò(½öEGAºÍVGA)',0
		DB	'    AL=17HÇåÐéÆÁÇø          AL=18HÉèÖÃ18ÏßÄ£Ê½   AL=19H»Ö¸´16ÏßÄ£Ê½',0
		DB	'    AL=1AH½ûÖ¹ÉèÖÃ×Ö·û¼¯    AL=1BHÔÊÐíÉèÖÃ×Ö·û¼¯(AH=11H¹¦ÄÜ)',0
		DB	'    AL=1CH-INT10AH=6~10Ö±½ÓÐ´ÆÁ·½Ê½    AL=1DH»Ö¸´ÖÐ¶Ï·½Ê½',0
		DB	'    AL=1EHÖ´ÐÐINT10³õÊ¼»¯ÊôÐÔ¼Ä´æÆ÷    AL=1FH²»³õÊ¼»¯',0
		DB	'AH=19H,AL=0¹Ø±Õ,=1´ò¿ª - ÌØÏÔ¿ª¹Ø',0
		DB	'    AL=2 - ÌØÏÔ²ÎÊý³õÊ¼»¯(GWÎÞ´Ë¹¦ÄÜ)',0
		DB	'    AL=3,Èô°²×°·µ»ØAL=83H(L),=84H(K),=85H(V),ES=ÌØÏÔÄ£¿é¶Î - ·µ»Ø°²×°×´Ì¬',0
		DB	'    AL=4 - Í£Ö¹ÑÝ×àÒôÀÖ',0
		DB	'AH=0FFH - È¡°²×°µÄÏÔÊ¾Ä£¿é',0
		DB	'    ·µ»Ø:AH=0,AL="V"-VGA,="E"-EGA,="H"-HGA,="C"-CGA,="c"-CGA11',0,0
D_INT10 	DB	0			;Ò³ºÅ

S_INT10 	PROC	NEAR
		MOV	SI,OFFSET D_INT1	;µÚÒ»Ò³
		CMP	D_INT10,0
		JZ	L_INT10
		MOV	SI,OFFSET D_INT2	;µÚ¶þÒ³
		CMP	D_INT10,1
		JZ	L_INT10
		MOV	SI,OFFSET D_INT3	;µÚÈýÒ³
		CMP	D_INT10,2
		JZ	L_INT10
		MOV	SI,OFFSET D_INT4	;µÚËÄÒ³
L_INT10:
		PUSH	SI
		MOV	DI,OFFSET K_INT10
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_INT10
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;ÏÔÊ¾´°¿ÚÄÚÈÝ
		MOV	DH,D_INT10
		MOV	DL,3
		CALL	S_PAGE			;´¦ÀíÒ³
		MOV	D_INT10,AL
		JMP	SHORT S_INT10
S_INT10 	ENDP
;----------------------------------------------------------------------------
T_INT		DB	'¼üÅÌºÍ´òÓ¡ÖÐ¶Ïµ÷ÓÃ',0
D_INT11 	DB	'    !INT 16©¤©¤¼üÅÌ¹ÜÀí!',0
		DB	'AH=0,·µ»ØAL=¼üÈë×Ö·û»òºº×Ö - ¼üÅÌÊäÈë',0
		DB	'AH=1,·µ»ØZ±êÖ¾=0ÓÐ×Ö·û,=1ÎÞ×Ö·û - ¼ì²é¼üÅÌ»º³åÇø',0
		DB	'AH=2,·µ»ØAL=×ª»»¼ü×´Ì¬ - È¡µ±Ç°×ª»»¼ü×´Ì¬',0
		DB	'     ÆäÖÐ: Î»0-ÓÒShift, 1-×óShift, 2-Ctrl,3-Alt',0
		DB	'             4-ScrollLock, 5-NumLock, 6-CapsLock, 7-INS',0
		DB	'AH=3,AL=5 - ÉèÖÃ»÷¼üËÙ¶ÈºÍÑÓ³Ù(Ö»286ÒÔÉÏÓÐÐ§)',0
		DB	'     BH=ÑÓ³Ù,=0Îª250ºÁÃë(×îÐ¡). BL=»÷¼üËÙ¶È,=0Îª30×Ö·û/Ãë(×î¿ì)',0
		DB	'AH=4,AL=×ª»»¼ü×´Ì¬(Í¬AH=2) - ÖÃµ±Ç°×ª»»¼ü×´Ì¬',0
		DB	'AH=5,CL=×Ö·ûÂë,CH=É¨ÃèÂë - Ïò¼üÅÌ»º³åÇøÐ´×Ö·û(Ö»286ÒÔÉÏÓÐÐ§)',0
		DB	'AH=10H Í¬AH=0',0
		DB	'AH=11H Í¬AH=1',0
		DB	'AH=12H Í¬AH=2',0
		DB	'AH=20H,BP=¶Î,CX=ÄÚÂëÇøÊ×,DX=ÍâÂëÇøÊ×.(0-3×°Èë,4-7È¡³ö)',0
		DB	'     AL=0»ò4Íâ²¿´Ê×é,=1»ò5ÁªÏë¿â,=2»ò6Îå±ÊÄ£¿é,=3»ò7Ë«Æ´´Ê×é',0
		DB	'AH=21H,AL=À©Õ¹ASCIIÂë - Ä£Äâ¹¦ÄÜ¼ü',0
		DB	'AH=22H,DX=ºº×ÖÄÚÂë - È¡ºº×ÖË«Æ´Âë  ·µ»ØAL=Ë«Æ´µÚÒ»Âë,AH=Ë«Æ´µÚ¶þÂë',0
		DB	'AH=25H,BL=ÑÕÉ« - ÏÔÊ¾°æ±¾ÐÅÏ¢',0
		DB	'AH=27H, AL=0 È¡ºº×ÖÊäÈë·½Ê½ºÅDL, AL=1 ÉèÖÃºº×ÖÊäÈë·½Ê½ DL=ÊäÈë·½Ê½ºÅ',0
		DB	'   DL=0ÎªASCII·½Ê½,Î»0ÇøÎ»,Î»1Ê×Î²,Î»2Æ´Òô,Î»3Ë«Æ´,Î»4Îå±Ê,Î»7µç±¨',0,0

D_INT12 	DB	'AH=29H - ÖØÏÔÌáÊ¾ÐÐ',0
		DB	'AH=2AH,AL=0:Ð´Èë,=1È¡³ö - È¡»òÖÃ°ïÖúÄ£¿éµØÖ·BP:SI',0
		DB	'AH=2BH,AL=INT16AHÖµ,·µ»ØAX - Ö´ÐÐROM-BIOS INT 16H',0
		DB	'AH=2FH - ·µ»Ø:±¾Ä£¿éÖÐ¶ÏÏòÁ¿BP:SI¡¢´Ê²ÎÊýÇøµØÖ·BP:DIºÍ2.13°²×°Â·¾¶',0
		DB	'              AX=44H-°²×°¼üÅÌÄ£¿éCKBD',0
		DB	'   ÆäÖÐ:[DI]-Íâ²¿´Ê×é,[DI+6]-ÁªÏë¿â,[DI+12]-Îå±Ê,[DI+18]-Ë«Æ´´Ê×é',0
		DB	'    !INT 17©¤©¤´òÓ¡¹ÜÀí!',0
		DB	'AH=0,AL=×Ö·û»òºº×Ö,·µ»ØAH=´òÓ¡»ú×´Ì¬×Ö -  ´òÓ¡Êä³ö',0
		DB	'AH=1,DX=´òÓ¡¿ÚºÅ,·µ»ØAH=´òÓ¡»ú×´Ì¬×Ö - ³õÊ¼»¯´òÓ¡»ú',0
		DB	'AH=2,DX=´òÓ¡¿ÚºÅ,·µ»ØAH=´òÓ¡»ú×´Ì¬×Ö - È¡´òÓ¡»ú×´Ì¬',0
		DB	'AH=3,AL=0Ö±ËÍ´òÓ¡»ú,=1±¾ÏµÍ³ºº×Ö´òÓ¡ - ÉèÖÃ´òÓ¡´¦ÀíÄ£Ê½',0
		DB	'AH=4,AL=0¹Ø±Õ,=1´ò¿ª - ÌØÊâ´òÓ¡¹¦ÄÜ¿ª¹Ø',0
		DB	'AH=5,AL=×Ö·ûÂë - Ö±½ÓÊä³ö×Ö·ûAL',0
		DB	'AH=6 - È¡´òÓ¡²ÎÊý  ·µ»Ø:ES=×¤ÁôÄÚ´æµÄÇý¶¯³ÌÐò¶ÎµØÖ·',0
		DB	'        AH=×ÖÐÍ×Ö½Ú,AL=´òÓ¡·½Ïò,CH=×Ö·û¼ä¾à,CL=ÐÐ¾à,DL=×ÖÐÍ×ÖÄ¸',0
		DB	'        DH="N"ÎªPRNT, ="H"ÎªPRTH',0
		DB	'        SI=×ó±ß¿ÕÁÐ,DI=ÐÐ¿í,BPµÍ8Î»=×ÖÐÍ¿í,BP¸ß8Î»=×ÖÐÍ¸ß',0
		DB	'        BL=¹¦ÄÜ×Ö½Ú1:Î»0-2±³¾°1~7,Î»3Çá´ò',0
		DB	'        BH=¹¦ÄÜ×Ö½Ú2:Î»0-·´°×,Î»1-ÏÂ»®Ïß,Î»2-ÉÏ»®Ïß,Î»3-×óÐý',0
		DB	'                     Î»4-ÓÒÐý,Î»5-ÉÏ±ê,Î»6-ÏÂ±ê',0
		DB	'AX=-1(»ò65535) - È¡°²×°×´Ì¬ Èô°²×°Ôò·µ»Ø:AX=-2130H,DX:BX=BIOS INT17',0,0

D_INT13 	DB	'    !INT 2F©¤©¤¶àÂ·ÖÐ¶Ï!(ÏµÍ³ÅäÖÃ¹ÜÀí)',0
		DB	'AX=4A06H,SI=0 ÍË³öºº×ÖÏµÍ³, =1 ÇåÇý¶¯³ÌÐòºÍÍâ¼ÓÄ£¿é, =2 ÇåÍâ¼ÓÄ£¿é',0
		DB	'           =3 ·µ»Ø:AX=0,BX=4A06HÔòÏµÍ³ÒÑ×°ÔØ,ÈôAX²»±äÔòÎ´×°ÔØ',0
		DB	'              CX:DX-BIOSÖÐ¶Ï±í(1×Ö½ÚÖÐ¶ÏºÅ,4×Ö½ÚÖÐ¶ÏÏòÁ¿),[DX-2]-ÖÐ¶ÏÊý',0
		DB	'    !INT 7A©¤©¤¶Á16¡Á16µãÕó×Ö¿â   INT 7C©¤©¤¶Á32¡Á32µãÕó×Ö¿â!',0
		DB	'    !INT 7B©¤©¤¶Á24¡Á24µãÕó×Ö¿â   INT 7D©¤©¤¶Á40¡Á40µãÕó×Ö¿â!',0
		DB	'AH=×ÖÐÍ(Î»0-1ºáÀ©,2-3×ÝÀ©,4-5×ÖÌå,6-7µãÕó',0
		DB	'     ÈôÎ»6-7=0,Î»4-5=01Îª24µãÕó¸ôµãÀ©,=10Îª16µãÕó,=11Îª16µãÕóÀ©24µã',0
		DB	'     Î»4-5×ÖÌå:=00ËÎÌå,=01·ÂËÎÌå,=10ºÚÌå,=11¿¬Ìå)',0
		DB	'   BH=ÌØÊâ¹¦ÄÜ(Î»1ÉÏ»®Ïß,2ÏÂ»®Ïß,3×óÐý,4ÓÒÐý,5ÉÏ±ê,6ÏÂ±ê,7µ¹×ª½ö24µãÕó)',0
		DB	'   BL=µ±Ç°´òÓ¡ÐÐÊý(×ÝÏò³¬¹ý24µãÊ±½«´òÓ¡¶àÐÐ,BLÖ¸Ê¾ÊÇµÚ¼¸ÐÐ,×îÏÂ24µãÊ±Îª0)',0
		DB	'   DX=ºº×ÖÄÚÂë,ÈôDH=0ÔòDL=ASCIIÂë(×Ö·û)',0
		DB	'   DS:SI¶Á³öµãÕóÊý¾ÝÆðÊ¼µØÖ·,CX=×Ö½ÚÊý',0
		DB	'    !INT 7E©¤©¤¶ÁÊ¸Á¿×Ö¿â! DX=0·µ»ØDX:BX»º³åÇøµØÖ·,AX=×Ö¿âµØÖ·',0
		DB	'AX=×ÖÐÍ¿í¶È,BX=×ÖÌå±àºÅ,CX=×ÖÐÍ¸ß¶È,DX=ºº×ÖÄÚÂë(×Ö·ûDH=0)',0
		DB	'SI=ÆðÊ¼ÐÐ,DI=ÖÕÖ¹ÐÐ,BP=ÊôÐÔ(Î»0=0Ë®Æ½µãÕó,=1´¹Ö±µãÕó,Î»11=1ÏÂ±ê,Î»12=1ÉÏ±ê',0
		DB	'         Î»13=0Ðý×ª90¶È,=1Ðý×ª180¶È,Î»14=0×óÐý,=1ÓÒÐý,Î»15=0²»Ðý×ª,=1Ðý×ª)',0
		DB	'·µ»Ø DX:BX=µãÕó»º³åÇøµØÖ·,AX=Êµ¼Ê¿í¶È,CX=Êµ¼Ê¸ß¶È',0
		DB	'    !INT 7F©¤©¤¶Á16¡Á16µãÕóÏÔÊ¾×Ö¿â!(Ë®Æ½µãÕó)',0
		DB	'DX=ºº×ÖÄÚÂë,·µ»Ø DX=µãÕóÊý¾ÝÆðÊ¼¶Î(Æ«ÒÆ=0)',0,0
D_QTINT 	DB	0			;Ò³ºÅ

S_QTINT 	PROC	NEAR
		MOV	SI,OFFSET D_INT11	;µÚÒ»Ò³
		CMP	D_QTINT,0
		JZ	L_QTINT
		MOV	SI,OFFSET D_INT12	;µÚ¶þÒ³
		CMP	D_QTINT,1
		JZ	L_QTINT
		MOV	SI,OFFSET D_INT13	;µÚÈýÒ³
L_QTINT:
		PUSH	SI
		MOV	DI,OFFSET K_QTINT
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_INT
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;ÏÔÊ¾´°¿ÚÄÚÈÝ
		MOV	DH,D_QTINT
		MOV	DL,2
		CALL	S_PAGE			;´¦ÀíÒ³
		MOV	D_QTINT,AL
		JMP	SHORT S_QTINT
S_QTINT 	ENDP
;----------------------------------------------------------------------------
T_GNJ		DB	'Áª»ú°ïÖúÏµÍ³Ê¹ÓÃ·½·¨',0
D_GNJ		DB	'Ö´ÐÐÁª»ú°ïÖú:Ê¹ÓÃ¼üÅÌÄ£¿é°ïÖú¹¦ÄÜ¼ü(F11)',0
		DB	'ÍË³öÁª»ú°ïÖú:¼üÈë<Esc>¼ü',0
		DB	'ÍË³ö±¾Ä£¿é:  ÔÚDOSÏÂ¼üÈë LHELP ¼Ó¿Õ¸ñ»òÈÎÒâ²ÎÊý',0
		DB	'×Ó´°¿Ú·µ»ØÖ÷²Ëµ¥:´ò³ý¡ü¡ýÒÔÍâµÄ¼ü',0
		DB	'  ÔÚ×Ó´°¿Ú´ò<Esc>Ö±½ÓÍË³ö,ÔÙ´Î°´<F11>¿ÉÖ±½Ó½øÈë¸Ã´°¿Ú.',0
		DB	'¼üÈë<Alt>+<Enter>(Ð¡¼üÅÌ):ÌáÊ¾ÐÐÌáÊ¾ÒÔÏÂ¸½¼Ó¹¦ÄÜ:',0
		DB	'  <Alt>+¹â±êÒÆ¶¯¼ü¡û¡ú¡ü¡ý---ÒÆ¶¯µ±Ç°´°¿Ú',0
		DB	'  <Alt>+<Ins*>--±³¾°É«+1  <Alt>+<Del*>--±³¾°É«-1',0
		DB	'  <Alt>+<Home*>-Ç°¾°É«+1  <Alt>+<End*>--Ç°¾°É«-1',0
		DB	'  <Alt>+<PgUp*>-±ß¿òÉ«+1  <Alt>+<PgDn*>-±ß¿òÉ«-1',0
		DB	'  <Alt>+<+>----ÉèÖÃ´æÅÌ  (ÓÐ*¼üÔÚ×¨ÓÃ¹â±ê¼üÉÏ·½)',0,0

S_GNJ		PROC	NEAR
		MOV	DI,OFFSET K_GNJ
		CALL	S_XSCK			;ÏÔÊ¾´°¿Ú
		MOV	SI,OFFSET T_GNJ
		CALL	S_XSBT
		MOV	SI,OFFSET D_GNJ
		JMP	L_XSINRET		;ÏÔÊ¾´°¿ÚÄÚÈÝ²¢¼üÈë
S_GNJ		ENDP

;****************************************************************************
BEGIN:
		XOR	BP,BP
		MOV	AX,1406H		;È¡ÏÔÊ¾²ÎÊý
		INT	10H
		OR	BP,BP
		JNZ	L_S5
		MOV	DX,OFFSET NO213
		JMP	SHORT L_ERR
L_S5:
		CMP	CL,25			;ÅÐ25ÐÐ?
		JAE	L_S6
		MOV	DX,OFFSET NO25		;Ð¡ÓÚ25,ÏìÁå
		JMP	SHORT L_ERR
L_S6:
		MOV	D_MODE,AL		;´æ
		CMP	AL,9			;ÅÐµ¥ÏÔ?
		JA	L_S10
		MOV	D_CDXZ,70H
L_S10:
		XOR	BP,BP
		MOV	AX,2A01H		;È¡°ïÖúÄ£¿é¶Î?
		INT	16H
		OR	BP,BP
		JZ	L_S20
		CMP	BYTE PTR DS:[80H],0	;ÓÐ²ÎÊýÍË³ö?
		JZ	L_S12
		MOV	ES,BP
		XOR	BP,BP
		XOR	SI,SI
		MOV	AX,2A00H		;ÕªÄ£¿é
		INT	16H
		MOV	AH,49H			;Çå±¾Ä£¿é
		INT	21H
		MOV	ES,ES:[2CH]
		MOV	AH,49H			;Çå»·¾³¿é
		INT	21H
		MOV	DX,OFFSET D_TVIU
		JMP	SHORT L_ERR
L_S12:
		MOV	DX,OFFSET D_YJCZ
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_S20:
		MOV	ES,DS:[2CH]		;»·¾³±äÁ¿¶Î
		XOR	SI,SI
		XOR	AX,AX
L_S122:
		CMP	ES:[SI],AX		;²éÕÒ»·¾³ÇøÎ²?
		JZ	L_S124
		INC	SI
		JMP	SHORT L_S122
L_S124:
		ADD	SI,4
		MOV	D_FILE,SI

		MOV	BP,CS
		MOV	SI,OFFSET L_HELP
		MOV	AX,2A00H		;½Óµ½¼üÅÌÄ£¿é
		INT	16H
		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
		MOV	DX,OFFSET D_END
		INT	27H

MSG		DB	'2.13L Áª»ú°ïÖúÏµÍ³ v2.0 1999.11.15',13,10
		DB	'Ê¹ÓÃ¼üÅÌÄ£¿é°ïÖú¹¦ÄÜ¼ü(F11)½øÈë°ïÖú',13,10
		DB	'    ÔÚDOSÏÂ¼üÈë LHELP ¼Ó¿Õ¸ñ:ÍË³ö±¾Ä£¿é',13,10,'$'

D_TVIU		DB	'ÍË³ö!',7,13,10,'$'
D_YJCZ		DB	'³ÌÐòÒÑ¾­µ÷Èë!',7,13,10,'$'
NOHELP		DB	'Î´°²×°±¾³ÌÐò!',7,13,10,'$'
NO213		DB	'NOT INSTALLED 2.13 SYSTEM!',7,13,10,'$'
NO25		DB	'CGA11ÏÔÊ¾Ä£¿é²»ÄÜÊ¹ÓÃ±¾³ÌÐò!',7,13,10,'$'
D_INPUT 	DB	5 DUP(0)

D_END	EQU	$

CSEG		ENDS
		END	START

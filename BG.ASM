.model small
.code
org 256
s:	push	cs
	pop	ds
	call	t
db	'Ñ¥$'
t:	pop	dx
	mov	ah,9
	int	33
	mov	ah,76
	int	33
end s
B	'      ±í©³                     Í¨ÓÃÖÆ±í³ÌÐò',13,10
		DB	'      Í·©»    1993Äê3ÔÂ21ÈÕ                     µÚ 1 Ò³        2 ÐÐ',13,10
		DB	'      ±ê©³   ©³©¥©¥©¥©Ó©¥©¥©¥©¥©¥©¥©Ó©¥©¥©¥©¥©¥©Ó©¥©¥©¥©¥',13,10
		DB	'      Ìâ©§   ©§ ÐòºÅ ©¦  ÐÕ    Ãû  ©¦          ©¦              1 ÐÐ',13,10
		DB	'      À¸©»   ©Ä©¤©¤©¤©à©¤©¤©¤©¤©¤©¤©à©¤©¤©¤©¤©¤©à©¤©¤©¤©¤',13,10
		DB	'        ©³   ©§  £±  ©¦  ÕÅ    Èý  ©¦          ©¦',13,10
		DB	'      ±í©§   ©Ä©¤©¤©¤©à©¤©¤©¤©¤©¤©¤©à©¤©¤©¤©¤©¤©à©¤©¤©¤©¤      2 ÐÐ',13,10
		DB	'      Ìå©§   ©§  £²  ©¦  Àî    ËÄ  ©¦          ©¦',13,10
		DB	'            ±ÕÊ½                                        ¿ªÊ½',13,10,'$'
D_INNAME	DB	'Çë¼üÈë±í¸ñÎÄ¼þÃû£º$'
D_INBT		DB	13,10,'      ±íÍ·ÐÐÊý£º$'
D_INBTL 	DB	13,10,'      ±êÌâÀ¸ÐÐÊý(<10)£º$'
D_INBTH 	DB	13,10,'      ±íÌåÐÐÊý£º$'
D_INHX		DB	13,10,'      ÐÐ¼äºáÏß£º(Y/N) $'
D_INBK		DB	13,10,'      ±ÕÊ½£¯¿ªÊ½£º(B/K) $'
D_INBC		DB	13,10,'      ±ß¿ò¼Ó´Ö£º(Y/N) $'
D_INBTLK	DB	13,10,'±íÌå¸÷À¸¿í¶È£º£¨ÒªÇóÅ¼Êý£¬µ¥Î»£º×Ö·û£¬À¸Êý¡Ü£³£¹£©',13,10,'$'
D_ZKD		DB	13,10,' ** ×Ü¿í¶È£º    '
		DB	13,10,'ÐÞ¸Ä£¿ (Y/RETURN) $'
D_INLH		DB	13,10,'À¸ºÅ£º$'
D_KD		DB	' ¿í¶È£º    ¸Ä³É£º$'
D_SXD		DB	'Ïò×ó©¤S  ÏòÓÒ©¤D  ÏòÏÂ©¤X  ÖØ×ö©¤A  ÍË³ö©¤E',0
D_MY		DB	'ÂúÒâ²»ÂúÒâ (Y/RETURN) ?',0
D_3		DB	'   $'

D_FILE		DB	40 DUP(0)		;±í¸ñÎÄ¼þÃû
D_HAN		DW	0			;ÎÄ¼þºÅ
D_INPUT 	DB	10 DUP(0)		;¼üÈë»º³åÇø
D_TH		DB	1			;±íÍ·ÐÐÊý
D_LH		DB	1			;±êÌâÀ¸ÐÐÊý
D_BTH		DB	1			;±íÌåÐÐÊý
D_X		DB	1			;ÐÐ¼äºáÏß=1
D_B		DB	1			;±ÕÊ½1/¿ªÊ½2
D_C		DB	1			;±ß¿ò¼Ó´Ö=1
D_L1		DB	0
D_P1		DW	0
D_LM		DB	0			;×î´óÀ¸ºÅ
D_H		DB	0			;µ±Ç°ÐÐ
D_L		DB	40 DUP(0)		;¸÷À¸¿í
D_M		DB	40 DUP(' ')             ;SDX

BEGIN:
		CALL	S_CLS			;ÇåÆÁ
		XOR	DX,DX
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		MOV	DX,OFFSET MSG
		MOV	AH,9			;ÏÔÊ¾
		INT	21H

		MOV	DX,OFFSET D_INNAME	;'Çë¼üÈë±í¸ñÎÄ¼þÃû£º$'
		MOV	AH,9
		INT	21H
		CALL	S_INPUT 		;¼üÈëÎÄ¼þÃû
		JNB	L_260
		MOV	AX,4C00H
		INT	21H
L_260:
		MOV	DX,OFFSET D_INBT	;'±íÍ·ÐÐÊý£º$'
		MOV	AH,9
		INT	21H
		CALL	S_INNUM 		;¼üÈëÊý×ÖAX
		OR	AL,AL
		JZ	L_270
		MOV	D_TH,AL
L_270:
		MOV	DX,OFFSET D_INBTL	;'±êÌâÀ¸ÐÐÊý(<10)£º'
		MOV	AH,9
		INT	21H
		CALL	S_INNUM 		;¼üÈëÊý×ÖAX
		OR	AL,AL
		JZ	L_280
		MOV	D_LH,AL
L_280:
		MOV	DX,OFFSET D_INBTH	;'±íÌåÐÐÊý£º'
		MOV	AH,9
		INT	21H
		CALL	S_INNUM 		;¼üÈëÊý×ÖAX
		OR	AL,AL
		JZ	L_290
		MOV	D_BTH,AL
L_290:
		MOV	DX,OFFSET D_INHX	;'ÐÐ¼äºáÏß£º(Y/N)'
		MOV	AH,9
		INT	21H
L_291:
		XOR	AH,AH			;¼üÈë
		INT	16H
		CMP	AL,0DH
		JZ	L_310
		AND	AL,5FH
		CMP	AL,'Y'
		JZ	L_292
		CMP	AL,'N'
		JNZ	L_291
L_292:
		CALL	S_XSAL			;ÏÔÊ¾
		CMP	AL,'Y'
		JNZ	L_310
		MOV	D_X,1
L_310:
		MOV	DX,OFFSET D_INBK	;'±ÕÊ½/¿ªÊ½£º(B/K)'
		MOV	AH,9
		INT	21H
L_311:
		XOR	AH,AH			;¼üÈë
		INT	16H
		CMP	AL,0DH
		JZ	L_330
		AND	AL,5FH
		CMP	AL,'B'
		JZ	L_312
		CMP	AL,'K'
		JNZ	L_311
L_312:
		CALL	S_XSAL			;ÏÔÊ¾

		CMP	AL,'K'
		JNZ	L_330
		MOV	D_B,2
L_330:
		MOV	DX,OFFSET D_INBC	;'±ß¿ò¼Ó´Ö£º(Y/N)'
		MOV	AH,9
		INT	21H
L_331:
		XOR	AH,AH			;¼üÈë
		INT	16H
		CMP	AL,0DH
		JZ	L_350
		AND	AL,5FH
		CMP	AL,'Y'
		JZ	L_332
		CMP	AL,'N'
		JNZ	L_331
L_332:
		CALL	S_XSAL			;ÏÔÊ¾

		CMP	AL,'Y'
		JNZ	L_350
		MOV	D_C,1
L_350:
		MOV	DX,OFFSET D_INBTLK	;'±íÌå¸÷À¸¿í¶È..'
		MOV	AH,9			;ÏÔÊ¾
		INT	21H
		XOR	BH,BH
		MOV	AH,3			;È¡µ±Ç°¹â±êÎ»ÖÃ
		INT	10H
		MOV	DS:[0FFH],DH
		MOV	CX,1			;À¸ºÅ
L_360:
		MOV	AX,CX
		DEC	AX
		MOV	DH,8
		DIV	DH
		ADD	AL,DS:[0FFH]
		MOV	DH,AL			;ÐÐºÅ
		MOV	AL,10
		MUL	AH
		MOV	DL,AL			;ÁÐºÅ
L_361:
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		MOV	AX,CX
		MOV	BL,10
		DIV	BL
		OR	AX,3030H
		CMP	AL,'0'
		JNZ	L_362
		MOV	AL,' '
L_362:
		CALL	S_XSAX			;ÏÔÊ¾ÁÐºÅ
		MOV	DL,':'
		CALL	S_XSDL
		MOV	AX,'  '
		CALL	S_XSAX
		MOV	AX,808H 		;ÍË¸ñ
		CALL	S_XSAX
		PUSH	CX
		PUSH	DX
		CALL	S_INNUM 		;¼üÈëÊý×Ö:À¸¿í
		POP	DX
		POP	CX
		TEST	AL,1			;ÅÐÆæÊý?
		JZ	L_380
		CALL	S_BEEP
		JMP	SHORT L_361
L_380:
		MOV	BX,CX
		DEC	BX
		MOV	D_L[BX],AL		;Ð´Èë
		OR	AL,AL
		JZ	L_390
		TEST	CL,7			;ÅÐ8¸ö?
		JNZ	L_381
		MOV	AX,0D0AH
		CALL	S_XSAX
L_381:
		INC	CX
		JMP	L_360
L_390:
		DEC	CL
		MOV	D_LM,CL 		;×î´óÀ¸ºÅ
		OR	CL,CL
		JNZ	L_400
		MOV	AX,4C00H
		INT	21H
L_400:
		XOR	BX,BX
		MOV	SI,OFFSET D_L
L_401:
		LODSB
		OR	AL,AL
		JZ	L_410
		CBW
		ADD	BX,AX			;ÀÛ¼Ó
		JMP	SHORT L_401
L_410:
		MOV	SI,OFFSET D_ZKD+16
		MOV	AX,BX			;×Ü¿í
		CALL	S_1610			;Ê®Áù½øÖÆ->Ê®½øÖÆ
		MOV	DX,OFFSET D_ZKD 	;'** ×Ü¿í¶È£º??? ÐÞ¸Ä?...'
		MOV	AH,9
		INT	21H

		XOR	AH,AH			;¼üÈëÑ¡Ôñ
		INT	16H
		AND	AL,5FH
		CMP	AL,'Y'                  ;='Y'ÐÞ¸Ä
		JZ	L_421
		JMP	L_460
L_421:
		MOV	DX,OFFSET D_INLH	;ÌáÊ¾'À¸ºÅ:'
		MOV	AH,9
		INT	21H
		CALL	S_INNUM 		;¼üÈëÀ¸ºÅ
		CMP	AL,0
		JZ	L_455
		MOV	CX,AX
		MOV	BX,CX
		DEC	BX
		MOV	AL,D_L[BX]		;È¡À¸¿í
		CBW
		MOV	SI,OFFSET D_KD+9
		CALL	S_1610			;Ê®Áù½øÖÆ->Ê®½øÖÆ
		MOV	DX,OFFSET D_KD		;'¿í¶È: ??? ¸Ä³É:'
		MOV	AH,9
		INT	21H
		CALL	S_INNUM 		;¼üÈë¿í¶È
		OR	AL,AL
		JZ	L_421
		CMP	CL,D_LM 		;³¬×î´óÀ¸ºÅ
		JBE	L_450
		MOV	D_LM,CL 		;ÖÃ
L_450:
		MOV	BX,CX
		DEC	BX
		MOV	D_L[BX],AL		;Ð´ÈëÀ¸¿í
		JMP	SHORT L_421
L_455:
		XOR	BH,BH
		MOV	AH,3			;È¡µ±Ç°¹â±êÎ»ÖÃ
		INT	10H
		MOV	DS:[0FFH],DH
		MOV	CX,1			;À¸ºÅ
L_456:
		MOV	AX,CX
		DEC	AX
		MOV	DH,8
		DIV	DH
		ADD	AL,DS:[0FFH]
		MOV	DH,AL			;ÐÐºÅ
		MOV	AL,10
		MUL	AH
		MOV	DL,AL			;ÁÐºÅ
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		MOV	AX,CX
		MOV	BL,10
		DIV	BL
		OR	AX,3030H
		CMP	AL,'0'
		JNZ	L_457
		MOV	AL,' '
L_457:
		CALL	S_XSAX			;ÏÔÊ¾À¸ºÅ
		MOV	DL,':'
		CALL	S_XSDL
		PUSH	CX
		PUSH	DX
		MOV	BX,CX
		DEC	BX
		MOV	AL,D_L[BX]		;È¡À¸¿í
		CBW
		MOV	SI,OFFSET D_3+2
		CALL	S_1610
		MOV	DX,OFFSET D_3
		MOV	AH,9			;ÏÔÊ¾À¸¿í
		INT	21H
		POP	DX
		POP	CX
		TEST	CL,7			;ÅÐ8¸ö?
		JNZ	L_458
		MOV	AX,0D0AH
		CALL	S_XSAX
L_458:
		INC	CX
		CMP	CL,D_LM 		;ÅÐµ½×î´óÀ¸ºÅ
		JBE	L_456
		JMP	L_400			;ÀÛ¼Æ×Ü¿í²¢ÖØÏÔÀ¸¿í
L_460:
		CALL	S_CLS			;ÇåÆÁ
		MOV	SI,OFFSET D_SXD 	;'Ïò×ó©¤S  ÏòÓÒ©¤D  ÏòÏÂ©¤X ...
		MOV	DX,1800H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	AX,1801H		;ÉèÖÃ²»Ê¶ºº×Ö
		INT	10H

		MOV	DX,1300H
		XOR	BH,BH
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		MOV	DL,' '
		CMP	D_B,1			;±ÕÊ½=1,¿ªÊ½=2
		JNZ	L_481
		MOV	DL,0C7H 		;'Ç'
		CMP	D_C,0
		JNZ	L_481
		MOV	DL,0C3H 		;'Ã'
L_481:
		CALL	S_XSDL			;ÏÔÊ¾

		MOV	CX,1			;À¸ºÅ
L_490:
		MOV	DL,0C4H 		;'Ä'
		CALL	S_XSDL
		CMP	CL,D_LM
		JZ	L_491
		MOV	DL,0C5H 		;'Å'
		JMP	SHORT L_492
L_491:
		CMP	D_B,1			;=1±ÕÊ½
		JNZ	L_500
		MOV	DL,0B6H 		;'¶'
		CMP	D_C,1			;=1¼Ó´Ö
		JZ	L_492
		MOV	DL,0B4H 		;'´'
L_492:
		CALL	S_XSDL			;ÏÔÊ¾
L_500:
		INC	CX
		CMP	CL,D_LM
		JBE	L_490

		MOV	DX,1400H
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		MOV	DL,'0'
		CALL	S_XSDL
		MOV	CX,1			;À¸ºÅ
L_510:
		MOV	AX,CX
		MOV	BL,10
		DIV	BL
		OR	AH,AH			;ÅÐÕû10
		JZ	L_511
		MOV	AX,'  '
		JMP	SHORT L_512
L_511:
		MOV	AH,'0'
		OR	AL,AH
L_512:
		CALL	S_XSAX			;ÏÔÊ¾Õû10
		INC	CX
		CMP	CL,D_LM
		JBE	L_510

		MOV	DX,1200H
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		MOV	DL,' '
		CMP	D_B,1			;±ÕÊ½?
		JNZ	L_531
		MOV	DL,0BAH 		;'º'
		CMP	D_C,1
		JZ	L_531
		MOV	DL,0B3H 		;'³'
L_531:
		CALL	S_XSDL
		MOV	CX,1
L_540:
		MOV	AL,CL
		CBW
		MOV	BL,10
		DIV	BL
		MOV	AL,AH
		OR	AL,30H
		MOV	DL,AL
		CALL	S_XSDL			;ÏÔÊ¾ÐòºÅ¸öÎ»
		CMP	CL,D_LM
		JZ	L_550
		MOV	DL,0B3H 		;ÏÔÊ¾'³'
		CALL	S_XSDL
		INC	CX
		JMP	SHORT L_540
L_550:
		CMP	D_B,1			;=1±ÕÊ½
		JNZ	L_560
		MOV	DL,0BAH 		;'º'
		CMP	D_C,1
		JZ	L_551
		MOV	DL,0B3H 		;'³'
L_551:
		CALL	S_XSDL
L_560:
		CMP	D_LH,1			;±êÌâÀ¸Ò»ÐÐ?
		JNZ	L_561
		MOV	DH,12H
		JMP	L_810
L_561:
		MOV	DH,10H
		MOV	AL,D_LH
		MOV	D_L1,AL
L_570:
		CMP	D_B,1			;=1±ÕÊ½
		JNZ	L_580
		MOV	D_M,'X'
L_580:
		MOV	BX,1			;À¸ºÅ
L_590:
		MOV	DL,BL
		SHL	DL,1
		DEC	DL
		MOV	AH,2
		INT	10H
		MOV	CX,1
		MOV	AX,0A20H
		INT	10H
		XOR	AH,AH			;¼üÈë
		INT	16H
		CMP	AL,96
		JB	L_610
		AND	AL,5FH
L_610:
		CMP	AL,'A'                  ;ÖØ×ö
		JNZ	L_660
		JMP	L_460
L_660:
		CMP	AL,'E'                  ;½áÊø
		JNZ	L_670
		MOV	AX,1800H
		INT	10H
		CALL	S_CLS
		MOV	AX,4C00H
		INT	21H
L_670:
		CMP	AL,'S'
		JZ	L_680
		CMP	AL,'D'
		JZ	L_680
		CMP	AL,'X'
		JZ	L_680
L_677:
		CALL	S_BEEP
		JMP	L_590
L_680:
		MOV	D_M[BX],AL		;Ð´Èë
		CALL	S_XSAL			;ÏÔÊ¾

		CMP	D_M[BX-1],'X'
		JNZ	L_700
		CMP	D_M[BX],'S'
		JZ	L_677
L_700:
		CMP	D_M[BX-1],'S'
		JNZ	L_710
		CMP	D_M[BX],'S'
		JZ	L_677
L_710:
		CMP	D_M[BX-1],'D'
		JNZ	L_720
		CMP	D_M[BX],'X'
		JZ	L_677
L_720:
		CMP	D_M[BX-1],'X'
		JNZ	L_730
		CMP	D_M[BX],'X'
		JNZ	L_730
		CMP	BL,1
		JNZ	L_722
		CMP	D_C,1
		JNZ	L_722
		XOR	DL,DL
		MOV	AH,2
		INT	10H
		MOV	DL,0BAH 		;'º'
		CALL	S_XSDL
		PUSH	DX
		INC	DH
		XOR	DL,DL
		MOV	AH,2
		INT	10H
		POP	DX
		MOV	DL,0BAH 		;'º'
		CALL	S_XSDL
		JMP	SHORT L_730
L_722:
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		PUSH	DX
		MOV	DL,0B3H 		;'³'
		CALL	S_XSDL
		POP	DX
		PUSH	DX
		INC	DH
		MOV	AH,2
		INT	10H
		POP	DX
		MOV	DL,0B3H 		;'³'
		CALL	S_XSDL
L_730:
		CMP	D_M[BX-1],'X'
		JNZ	L_740
		CMP	D_M[BX],'D'
		JNZ	L_740
		CMP	BL,1
		JNZ	L_733
		CMP	D_C,1
		JNZ	L_733
		XOR	DL,DL
		MOV	AH,2
		INT	10H
		MOV	DL,0BAH 		;'º'
		CALL	S_XSDL
		PUSH	DX
		INC	DH
		XOR	DL,DL
		MOV	AH,2
		INT	10H
		POP	DX
		MOV	DL,0C7H 		;'Ç'
		CALL	S_XSDL
		MOV	DL,0C4H 		;'Ä'
		CALL	S_XSDL
		JMP	SHORT L_740
L_733:
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		PUSH	DX
		MOV	DL,0B3H 		;'³'
		CALL	S_XSDL
		POP	DX
		PUSH	DX
		INC	DH
		MOV	AH,2
		INT	10H
		POP	DX
		MOV	DL,0C3H 		;'Ã'
		CALL	S_XSDL
		MOV	DL,0C4H 		;'Ä'
		CALL	S_XSDL
L_740:
		CMP	D_M[BX-1],'D'
		JNZ	L_750
		CMP	D_M[BX],'D'
		JZ	L_742
		CMP	D_M[BX],'S'
		JNZ	L_750
L_742:
		PUSH	DX
		ADD	DH,2
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		POP	DX
		PUSH	DX
		INC	DH
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		POP	DX
		CMP	AL,179			;'³'
		JNZ	L_744
		MOV	DL,0C2H 		;'Â'
		CALL	S_XSDL
		MOV	DL,0C4H 		;'Ä'
		CALL	S_XSDL
		JMP	SHORT L_750
L_744:
		MOV	DL,0C4H 		;'Ä'
		CALL	S_XSDL
		MOV	DL,0C4H 		;'Ä'
		CALL	S_XSDL
L_750:
		CMP	D_M[BX-1],'S'
		JNZ	L_760
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		PUSH	DX
		MOV	DL,0B3H 		;³'
		CALL	S_XSDL
		POP	DX
		PUSH	DX
		INC	DH
		MOV	AH,2
		INT	10H
		POP	DX
		CMP	D_M[BX],'X'
		JNZ	L_755
		MOV	DL,0B4H 		;´'
		CALL	S_XSDL
		JMP	SHORT L_760
L_755:
		CMP	D_M[BX],'D'
		JNZ	L_760
		MOV	DL,0C5H 		;'Å'
		CALL	S_XSDL
		MOV	DL,0C4H 		;'Ä'
		CALL	S_XSDL
L_760:
		CMP	BL,D_LM
		JNZ	L_800
		CMP	D_B,1
		JNZ	L_800
		MOV	DL,BL
		SHL	DL,1
		MOV	AH,2
		INT	10H
		PUSH	DX
		MOV	DL,0BAH 		;'º'
		CMP	D_C,1
		JZ	L_770
		MOV	DL,0B3H 		;'³'
L_770:
		CALL	S_XSDL
		POP	DX
		PUSH	DX
		INC	DH
		MOV	AH,2
		INT	10H
		POP	DX
		CMP	D_M[BX],'X'
		JNZ	L_790
		MOV	DL,0BAH 		;'º'
		CMP	D_C,1
		JZ	L_788
		MOV	DL,0B3H 		;'³'
L_788:
		CALL	S_XSDL
L_790:
		CMP	D_M[BX],'S'
		JNZ	L_800
		MOV	DL,0B6H 		;'¶'
		CMP	D_C,1
		JZ	L_797
		MOV	DL,0B4H 		;'´'
L_797:
		CALL	S_XSDL
L_800:
		INC	BX
		CMP	BL,D_LM
		JA	L_801
		JMP	L_590
L_801:
		DEC	D_L1
		CMP	D_L1,1
		JZ	L_810
		SUB	DH,2
		JMP	L_570
L_810:
		MOV	BL,D_B
L_811:
		MOV	DL,BL
		DEC	DL
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		PUSH	DX
		DEC	DH
		MOV	AH,2
		INT	10H
		POP	DX

		CMP	AL,179			;'³'
		JZ	L_830
		CMP	AL,186			;'º'
		JZ	L_830
		CMP	D_C,1
		JNZ	L_822
		MOV	DL,0CDH 		;'Í'
		CALL	S_XSDL
		JMP	SHORT L_860
L_822:
		MOV	DL,0C4H 		;'Ä'
		CALL	S_XSDL
		JMP	SHORT L_860
L_830:
		CMP	BL,1
		JNZ	L_840
		CMP	D_C,1
		JNZ	L_833
		MOV	DL,0C9H 		;'É'
		CALL	S_XSDL
		JMP	SHORT L_860
L_833:
		MOV	DL,0DAH 		;'Ú'
		CALL	S_XSDL
		JMP	SHORT L_860
L_840:
		MOV	AL,D_LM
		SHL	AL,1
		ADD	AL,2
		SUB	AL,D_B
		CMP	BL,AL
		JNZ	L_850
		CMP	D_C,1
		JNZ	L_844
		MOV	DL,0BBH 		;'»'
		CALL	S_XSDL
		JMP	SHORT L_860
L_844:
		MOV	DL,0BFH 		;'¿'
		CALL	S_XSDL
		JMP	SHORT L_860
L_850:
		CMP	D_C,1
		JNZ	L_855
		MOV	DL,0D1H 		;Ñ'
		CALL	S_XSDL
		JMP	SHORT L_860
L_855:
		MOV	DL,0C2H 		;'Â'
		CALL	S_XSDL
L_860:
		INC	BL
		MOV	AL,D_LM
		SHL	AL,1
		ADD	AL,2
		SUB	AL,D_B
		CMP	BL,AL
		JA	L_870
		JMP	L_811
L_870:
		MOV	D_H,DH

		MOV	AX,1800H		;ÉèÖÃÊ¶±ðºº×Ö
		INT	10H
		MOV	SI,OFFSET D_MY		;'ÂúÒâ²»ÂúÒâ?...'
		MOV	DX,1832H
		MOV	BX,1EH
		CALL	S_XSZF
		XOR	AH,AH			;¼üÈëÑ¡Ôñ
		INT	16H
		CMP	AL,1BH			;ESC?
		JNZ	L_877
		JMP	L_1120
L_877:
		AND	AL,5FH
		CMP	AL,'Y'                  ;ÅÐY?
		JZ	L_880
		JMP	L_460
L_880:
		MOV	DX,OFFSET D_FILE	;±í¸ñÎÄ¼þÃû
		MOV	CX,20H
		MOV	AH,3CH			;½¨Á¢ÎÄ¼þ
		INT	21H
		MOV	D_HAN,AX
		MOV	BX,AX
		MOV	AL,D_TH 		;±íÍ·ÐÐÊý
		CBW
		MOV	SI,AX
L_882:
		MOV	DX,OFFSET D_INBT	;13,10
		MOV	CX,2
		MOV	AH,40H			;Ð´Èë
		INT	21H
		DEC	SI
		JNZ	L_882

		MOV	DI,OFFSET D_BUF 	;ÐÐÊä³ö»º³åÇø
		MOV	DH,D_H
		MOV	BX,1
L_890:
		PUSH	DX
		DEC	DH
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		POP	DX
		CMP	AL,' '
		JZ	L_980
		CMP	AL,196			;'Ä'
		JNZ	L_910
		MOV	AX,'©¤'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_910:
		CMP	AL,205			;'Í'
		JNZ	L_920
		MOV	AX,'©¥'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_920:
		CMP	AL,194			;'Â'
		JNZ	L_930
		MOV	AX,'©Ð'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_930:
		CMP	AL,209			;'Ñ'
		JNZ	L_940
		MOV	AX,'©Ó'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_940:
		CMP	AL,218			;'Ú'
		JNZ	L_950
		MOV	AX,'©°'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_950:
		CMP	AL,201			;'É'
		JNZ	L_960
		MOV	AX,'©³'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_960:
		CMP	AL,191			;'¿'
		JNZ	L_970
		MOV	AX,'©´'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_970:
		CMP	AL,187			;'»'
		JNZ	L_980
		MOV	AX,'©·'
		XCHG	AH,AL
		STOSW
L_980:
		CMP	BL,D_LM
		JA	L_1010
		MOV	CL,D_L[BX-1]		;È¡À¸¿í
		XOR	CH,CH
		SHR	CX,1
L_990:
		MOV	AX,'©¥'
		CMP	D_C,1
		JZ	L_991
		MOV	AX,'©¤'
L_991:
		XCHG	AH,AL
		STOSW
		LOOP	L_990
L_1010:
		INC	BX
		MOV	AL,D_LM
		INC	AX
		CMP	BL,AL
		JA	L_1011
		JMP	L_890
L_1011:
		CALL	S_WRIT			;Ð´Èë

		MOV	BP,1			;´¦Àí±êÌâÀ¸ÆäËûÐÐ
L_1020:
		CALL	S_1130			;´¦ÀíÒ»ÐÐ
		INC	BP
		MOV	AL,D_LH
		CBW
		SHL	AX,1
		CMP	BP,AX
		JBE	L_1020

		MOV	D_P1,BP 		;´¦Àí±íÌå
		SUB	D_P1,2
		MOV	BX,1
L_1030:
		MOV	BP,D_P1
		CALL	S_1130			;´¦ÀíÒ»ÐÐ
		CMP	BL,D_BTH
		JZ	L_1050
		CMP	D_X,1			;ÐÐ¼äºáÏß?
		JNZ	L_1050
		MOV	BP,D_P1
		INC	BP
		CALL	S_1130			;´¦ÀíÒ»ÐÐ
L_1050:
		INC	BX
		CMP	BL,D_BTH
		JBE	L_1030

		MOV	DI,OFFSET D_BUF 	;´¦ÀíÎ²ÐÐ
		CMP	D_B,1
		JNZ	L_1080
		MOV	AX,'©»'
		CMP	D_C,1
		JZ	L_1071
		MOV	AX,'©¸'
L_1071:
		XCHG	AH,AL
		STOSW
L_1080:
		MOV	BX,1
L_1081:
		MOV	CL,D_L[BX-1]
		XOR	CH,CH
		SHR	CX,1
		MOV	AX,'©¥'
		CMP	D_C,1
		JZ	L_1082
		MOV	AX,'©¤'
L_1082:
		XCHG	AH,AL
		REP	STOSW
		CMP	BL,D_LM
		JNZ	L_1100
		CMP	D_B,1
		JNZ	L_1100
		MOV	AX,'©¿'
		CMP	D_C,1
		JZ	L_1091
		MOV	AX,'©¼'
L_1091:
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1110
L_1100:
		MOV	AX,'©Û'
		CMP	D_C,1
		JZ	L_1101
		MOV	AX,'©Ø'
L_1101:
		XCHG	AH,AL
		STOSW
L_1110:
		INC	BX
		CMP	BL,D_LM
		JBE	L_1081
		MOV	AX,0A0DH		;»Ø³µ»»ÐÐ
		STOSW
		MOV	AL,1AH			;ÎÄ±¾ÎÄ¼þ½áÊø±êÖ¾
		STOSB
		CALL	S_WRIT1 		;Ð´Èë

		MOV	AH,3EH			;¹Ø±ÕÎÄ¼þ
		INT	21H
L_1120:
		XOR	BX,BX
		MOV	AH,3			;È¡µ±Ç°¹â±êÎ»ÖÃ
		INT	10H
		PUSH	DX
		MOV	DX,1800H
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		MOV	AX,920H 		;Çåµ×ÐÐÐÅÏ¢
		MOV	CX,80
		INT	10H
		POP	DX
		INC	DH
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H

		MOV	AX,4C00H
		INT	21H

;×Ó³ÌÐò:´¦ÀíÖÐ¼äÐÐ
S_1130		PROC	NEAR
		PUSH	BX
		MOV	DI,OFFSET D_BUF
		MOV	BX,1
L_1140:
		MOV	DH,D_H
		MOV	AX,BP
		ADD	DH,AL
		DEC	DH
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		CMP	AL,128
		JA	L_1160
		CMP	BL,1
		JZ	L_1160
		MOV	AX,'  '
		STOSW
L_1160:
		CMP	AL,196			;'Ä'
		JNZ	L_1170
		MOV	AX,'©¤'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1170:
		CMP	AL,179			;'³'
		JNZ	L_1180
		MOV	AX,'©¦'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1180:
		CMP	AL,186			;'º'
		JNZ	L_1190
		MOV	AX,'©§'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1190:
		CMP	AL,194			;'Â'
		JNZ	L_1200
		MOV	AX,'©Ð'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1200:
		CMP	AL,193			;'Á'
		JNZ	L_1210
		MOV	AX,'©Ø'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1210:
		CMP	AL,195			;'Ã'
		JNZ	L_1220
		MOV	AX,'©À'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1220:
		CMP	AL,199			;'Ç'
		JNZ	L_1230
		MOV	AX,'©Ä'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1230:
		CMP	AL,180			;'´'
		JNZ	L_1240
		MOV	AX,'©È'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1240:
		CMP	AL,182			;'¶'
		JNZ	L_1250
		MOV	AX,'©Ì'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1250:
		CMP	AL,197			;'Å'
		JNZ	L_1260
		MOV	AX,'©à'
		XCHG	AH,AL
		STOSW
L_1260:
		MOV	DH,D_H
		MOV	AX,BP
		ADD	DH,AL
		DEC	DH
		MOV	DL,BL
		SHL	DL,1
		DEC	DL
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		CMP	AL,128
		JA	L_1270
		MOV	CL,D_L[BX-1]
		OR	CL,CL
		JZ	L_1270
		XOR	CH,CH
		MOV	AL,' '
		REP	STOSB
L_1270:
		CMP	AL,196			;'Ä'
		JNZ	L_1280
		MOV	CL,D_L[BX-1]
		OR	CL,CL
		JZ	L_1280
		XOR	CH,CH
		SHR	CX,1
		MOV	AX,'©¤'
		XCHG	AH,AL
		REP	STOSW
L_1280:
		INC	BX
		MOV	AL,D_LM
		INC	AX
		CMP	BL,AL
		JA	L_1290
		JMP	L_1140
L_1290:
		CALL	S_WRIT
		POP	BX
		RET
;×Ó³ÌÐò:Ð´ÈëÎÄ¼þ
S_WRIT:
		MOV	AX,0A0DH		;»Ø³µ»»ÐÐ
		STOSW
S_WRIT1:
		MOV	BX,D_HAN		;ÎÄ¼þºÅ
		MOV	DX,OFFSET D_BUF
		MOV	CX,DI
		SUB	CX,DX
		MOV	AH,40H			;Ð´ÎÄ¼þ
		INT	21H
		RET
S_1130		ENDP

;×Ó³ÌÐò:ÏÔÊ¾×Ö·û´®SI,DX=´®Ê×Î»ÖÃ,BL=ÊôÐÔ.ÏÔÊ¾ºó¹â±êÔÚ´®Î²
S_XSZF		PROC	NEAR
L_XZ1:
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		LODSB				;È¡Ò»×Ö·û
		OR	AL,AL			;½áÊø?
		JZ	L_XZ2
		MOV	CX,1
		MOV	AH,9			;ÏÔÊ¾
		INT	10H
		INC	DX			;ÁÐ+1
		JMP	SHORT L_XZ1
L_XZ2:
		RET
S_XSZF		ENDP

;×Ó³ÌÐò:ÏÔÊ¾AX(ÏÈAL,ÔÙAH)
S_XSAX		PROC	NEAR
		XCHG	AH,AL
		PUSH	AX
		MOV	DL,AH
		CALL	S_XSDL
		POP	AX
S_XSAL:
		MOV	DL,AL
S_XSDL:
		MOV	AH,2
		INT	21H
		RET
S_XSAX		ENDP

;×Ó³ÌÐò:ÏìÁå
S_BEEP		PROC	NEAR
		MOV	AX,0E07H
		INT	10H
		RET
S_BEEP		ENDP

;×Ó³ÌÐò:ÇåÆÁ
S_CLS		PROC	NEAR
		MOV	AX,600H
		XOR	BX,BX
		XOR	CX,CX
		MOV	DX,184FH
		INT	10H
		RET
S_CLS		ENDP

;×Ó³ÌÐò:¼üÈëÎÄ¼þÃû
S_INPUT 	PROC	NEAR
		MOV	SI,OFFSET D_FILE	;¼üÈë»º³åÇø
L_IN1:
		XOR	AH,AH			;¼üÈë
		INT	16H
		CMP	AL,0DH			;»Ø³µ?
		JZ	L_IN6
		CMP	AL,1BH			;<ESC>
		JNZ	L_IN1A
		POPF
		INT	20H
L_IN1A:
		CMP	AL,8			;ÍË¸ñ?
		JNZ	L_IN5
		CMP	SI,OFFSET D_FILE	;Ö¸ÕëÔÚÇøÊ×?
		JA	L_IN3
L_IN2:
		CALL	S_BEEP
		JMP	SHORT L_IN1
L_IN3:
		DEC	SI			;Î»ÖÃ-1
L_IN4:
		CALL	S_XSAL			;ÏÔÊ¾

		CMP	AL,8			;ÍË¸ñ?
		JNZ	L_IN1
		MOV	CX,1
		MOV	AX,0A20H		;ÏÔÊ¾¿Õ¸ñ
		INT	10H
		JMP	SHORT L_IN1
L_IN5:
		MOV	[SI],AL 		;Ð´Èë
		INC	SI
		JMP	SHORT L_IN4		;ÏÔÊ¾
L_IN6:
		CMP	SI,OFFSET D_FILE
		JZ	L_IN7
		MOV	BYTE PTR [SI],0
		CLC
		RET
L_IN7:
		STC
		RET
S_INPUT 	ENDP

;×Ó³ÌÐò:¼üÈëÊý×Ö ·µ»ØAX
S_INNUM 	PROC	NEAR
		MOV	SI,OFFSET D_INPUT	;¼üÈë»º³åÇø
		MOV	DI,SI
		MOV	BX,7
L_NUM1:
		XOR	AH,AH			;¼üÈë
		INT	16H
		CMP	AL,0DH			;»Ø³µ?
		JZ	L_NUM6
		CMP	AL,1BH			;<ESC>
		JNZ	L_NUM1A
		POPF
		INT	20H
L_NUM1A:
		CMP	AL,8			;ÍË¸ñ?
		JNZ	L_NUM5
		CMP	SI,OFFSET D_INPUT	;Ö¸ÕëÔÚÇøÊ×?
		JA	L_NUM3
L_NUM2:
		CALL	S_BEEP
		JMP	SHORT L_NUM1
L_NUM3:
		DEC	SI			;Î»ÖÃ-1
L_NUM4:
		CALL	S_XSAL			;ÏÔÊ¾

		CMP	AL,8			;ÍË¸ñ?
		JNZ	L_NUM1
		MOV	CX,1
		MOV	AX,0A20H		;ÏÔÊ¾¿Õ¸ñ
		INT	10H
		JMP	SHORT L_NUM1
L_NUM5:
		CMP	AL,'0'                  ;ÅÐÊý×Ö?
		JB	L_NUM1
		CMP	AL,'9'
		JA	L_NUM1
		MOV	[SI],AL 		;Ð´Èë
		INC	SI
		JMP	SHORT L_NUM4
L_NUM6:
		CMP	SI,OFFSET D_INPUT
		JZ	L_NUM9
		XOR	BX,BX
		MOV	[SI],BL
		MOV	SI,OFFSET D_INPUT	;¼üÈëÇøÊ×
L_NUM7:
		LODSB				;È¡
		OR	AL,AL
		JZ	L_NUM8
		AND	AL,0FH
		CBW
		PUSH	AX
		MOV	AX,10
		MUL	BX
		MOV	BX,AX
		POP	AX
		ADD	BX,AX
		JMP	SHORT L_NUM7
L_NUM8:
		MOV	AX,BX
		RET
L_NUM9:
		XOR	AX,AX
		RET
S_INNUM 	ENDP

;×Ó³ÌÐò:Ê®Áù½øÖÆ->Ê®½øÖÆAX,SI-¸öÎ»µØÖ·
S_1610		PROC	NEAR
		MOV	BL,10
L_161:
		DIV	BL
		OR	AH,30H
		MOV	[SI],AH
		XOR	AH,AH
		DEC	SI
		OR	AL,AL
		JNZ	L_161
		RET
S_1610		ENDP

D_BUF	EQU	$

CSEG		ENDS
		END	START
;	BG.ASM (2.13L)
;	1995.7.15
;	1996.10.9

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

MSG		DB	'      ±í©³                     Í¨ÓÃÖÆ±í³ÌÐò',13,10
		DB	'      Í·©»    1993Äê3ÔÂ21ÈÕ                     µÚ 1 Ò³        2 Ð
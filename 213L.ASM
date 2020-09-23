;	213L.ASM FOR FOXPRO 2.5B
;	1996.1.18, 1.31

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:
		XOR	BP,BP
		MOV	AX,1406H		;È¡ÏÔÊ¾²ÎÊý
		INT	10H
		OR	BP,BP			;ÅÐ2.13L?
		JNZ	L_10
		MOV	DX,OFFSET NO213
		JMP	SHORT L_ERR
L_10:
		CMP	BL,4			;ÅÐÖ±½ÓÐ´ÆÁ?
		JZ	L_20
		MOV	DX,OFFSET NOZJXP
		JMP	SHORT L_ERR
L_20:
		TEST	DL,20H			;ÅÐÀ©Õ¹×Ö·û¿â?
		JNZ	L_30
		MOV	DX,OFFSET NOKZZF
		JMP	SHORT L_ERR
L_30:
		TEST	DL,8			;ÅÐ16µãÕóÏÔÊ¾?
		JZ	L_40
		MOV	DX,OFFSET NO16
L_ERR:
		MOV	AH,9
		INT	21H
L_EXIT:
		INT	20H
L_40:
		MOV	AX,140EH		;È¡Î÷ÎÄÖÆ±í·û×ª»»±íBX:AX
		INT	10H
		CMP	AX,140EH		;ÅÐ96Äê°æ2.13L?
		JNZ	L_44
		MOV	DX,OFFSET NO961
		JMP	SHORT L_ERR
L_44:
		MOV	ES,BX
		MOV	DI,AX
		MOV	AX,140CH		;È¡ÐéÆÁÇøµØÖ·BX:AX
		INT	10H
		ADD	AX,25*80*2
		MOV	BP,AX			;À©Õ¹×Ö·û¿â
		MOV	CX,48

		MOV	AL,DS:[5DH]
		AND	AL,5FH
		CMP	AL,'R'                  ;»Ö¸´
		JNZ	L_50
		MOV	SI,OFFSET D_ZBFB	;Ô­×ª»»±í
		REP	MOVSB

		XOR	AX,AX
		MOV	DS,AX
		LDS	DX,DWORD PTR DS:[10CH]	;VGA×Ö·û¿â
		XOR	BX,BX
L_48:
		MOV	AL,CS:D_XGA[BX]
		XOR	AH,AH
		MOV	CL,4
		SHL	AX,CL
		MOV	SI,DX
		ADD	SI,AX
		MOV	DI,BP
		ADD	DI,AX
		MOV	CL,16
		REP	MOVSB
		INC	BX
		CMP	BX,6
		JB	L_48
		INT	20H
L_50:
		MOV	SI,OFFSET D_ZBFA	;ÐÂ×ª»»±í
		REP	MOVSB

		XOR	AX,AX
		MOV	DS,AX
		LDS	DX,DWORD PTR DS:[10CH]	;VGA×Ö·û¿â
		XOR	BX,BX
L_52:
		MOV	AL,CS:D_XGB[BX]
		XOR	AH,AH
		MOV	CL,4
		SHL	AX,CL
		MOV	SI,DX
		ADD	SI,AX
		MOV	AL,CS:D_XGA[BX]
		XOR	AH,AH
		SHL	AX,CL
		MOV	DI,BP
		ADD	DI,AX
		MOV	CL,16
		REP	MOVSB
		INC	BX
		CMP	BX,6
		JB	L_52
		INT	20H

D_XGA		DB	 80H, 8AH, 8BH, 8CH, 8FH, 91H
D_XGB		DB	0FEH,0F9H,0AEH,0AFH,0F0H,0F7H

D_ZBFA		DB	81H, 82H, 83H, 6,   0BH, 0B5H,9BH, 97H
	;0B0H		°    ±	  ²    ³    ´	 µ    ¶    ·
		DB	93H, 7FH, 15H, 0FH, 14H, 99H, 95H, 2
	;0B8H		·    ¹	  º    »    ¼	 ½    ¾    ¿
		DB	3,   9CH, 9DH, 8EH, 8,	 9,   0C6H,9AH
	;0C0H		À    Á	  Â    Ã    Ä	 Å    Æ    Ç
		DB	13H, 90H, 9EH, 9FH, 1CH, 16H, 17H, 89H
	;0C8H		È    É	  Ê    Ë    Ì	 Í    Î    Ï
		DB	0D0H,0D1H,0D2H,98H, 94H, 92H, 96H,0D7H
	;0D0H		Ð    Ñ	  Ò    Ó    Ô	 Õ    Ö    ×
		DB	0DH, 5,   1,   84H, 85H, 86H, 87H, 88H
	;0D8H		Ø    Ù	  Ú    Û    Ü	 Ý    Þ    ß

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

;×ª»»±í DB	  1, 0DAH,   2, 0BFH,	3, 0C0H,   5, 0D9H
;	DB	  6, 0B3H,   8, 0C4H,	9, 0C5H, 0BH, 0B4H
;	DB	0DH, 0D8H, 0FH, 0BBH, 13H, 0C8H, 14H, 0BCH
;	DB	15H, 0BAH, 16H, 0CDH, 17H, 0CEH, 1CH, 0CCH
;	DB	7FH, 0B9H, 80H- 0FEH, 81H, 0B0H, 82H, 0B1H	;0FEH
;	DB	83H, 0B2H, 84H, 0DBH, 85H, 0DCH, 86H, 0DDH
;	DB	87H, 0DEH, 88H, 0DFH, 89H, 0CFH, 8AH- 0F9H	;0F9H
;	DB	8BH- 0AEH, 8CH- 0AFH, 8EH, 0C3H, 8FH- 0F0H	;0AEH,0AFH,0F0H
;	DB	90H, 0C9H, 91H- 0F7H, 92H, 0D5H, 93H, 0B8H	;0F7H
;	DB	94H, 0D4H, 95H, 0BEH, 96H, 0D6H, 97H, 0B7H
;	DB	98H, 0D3H, 99H, 0BDH, 9AH, 0C7H, 9BH, 0B6H, 0, 0

NO213		DB	'²»ÊÇ95Äê°æ2.13ÏµÁÐºº×ÖÏµÍ³!',7,13,10,'$'
NOZJXP		DB	'²»ÊÇÖ±½ÓÐ´ÆÁ·½Ê½!',7,13,10,'$'
NOKZZF		DB	'Î´Ê¹ÓÃÀ©Õ¹×Ö·û¿â!',7,13,10,'$'
NO16		DB	'Ö»ÄÜÊ¹ÓÃ16µãÕóÏÔÊ¾!',7,13,10,'$'
NO961		DB	'²»ÊÇ1996Äê°æ2.13Lºº×ÖÏµÍ³!',7,13,10,'$'

SEG_A		ENDS
		END	START

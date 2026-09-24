;	LSETUP.ASM
;	1999.2.13, 11.14
DATE	EQU	"1999.11.29"

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

D_0		DW	204H			;Ö÷²Ëµ¥Î»ÖÃ
C_0		DW	1EH			;      ÑÕÉ«
A_0		DW	0F16H			;      ´óÐ¡

D_9		DW	201H			;¹¦ÄÜ¼ü²Ëµ¥Î»ÖÃ
C_9		DW	6FH			;	   ÑÕÉ«
A_9		DW	101DH			;	   ´óÐ¡

D_9A		DW	21FH			;¹¦ÄÜ¼ü±íÎ»ÖÃ
C_9A		DW	6FH			;	 ÑÕÉ«
A_9A		DW	1030H			;	 ´óÐ¡

D_10		DW	420H			;´òÓ¡»ú²Ëµ¥Î»ÖÃ
C_10		DW	2FH			;	   ÑÕÉ«
A_10		DW	0E14H			;	   ´óÐ¡

D_14		DW	20H			;ÏÔÊ¾²ÎÊý²Ëµ¥Î»ÖÃ
C_14		DW	5FH			;	     ÑÕÉ«
A_14		DW	151AH			;	     ´óÐ¡

D_15		DW	41CH			;ÐÞ¸Ä213L.BAT´°¿ÚÎ»ÖÃ
C_15		DW	34H			;		 ÑÕÉ«
A_15		DW	0A1AH			;		 ´óÐ¡

D_PR		DW	438H			;PRÑ¡Ôñ´°¿ÚÎ»ÖÃ
C_PR		DW	0FF6FH			;	   ÑÕÉ«
A_PR		DW	0C17H			;	   ´óÐ¡

D_PRNT		DW	438H			;PRNTÑ¡Ôñ´°¿ÚÎ»ÖÃ
C_PRNT		DW	0FF6FH			;	     ÑÕÉ«
A_PRNT		DW	0C13H			;	     ´óÐ¡

D_HELP		DW	1504H			;°ïÖú´°¿ÚÎ»ÖÃ
C_HELP		DW	30H
A_HELP		DW	448H			;	 ´óÐ¡

D_IN		DW	1222H			;¼üÈë´°¿ÚÎ»ÖÃ
C_IN		DW	0FF71H			;	 ÑÕÉ«
A_IN		DW	32AH			;	 ´óÐ¡

D_XTPZ		DB	'2.13L ÏµÍ³ÅäÖÃ',0
F_INI		DB	'213L.INI',0
D_W		DB	0			;='W':ÐÞ¸Äµ±Ç°Ä¿Â¼ÏÂµÄINIÎÄ¼þ
NOINI		DB	'ÏµÍ³ÅäÖÃÎÄ¼þ 213L.INI Î´ÕÒµ½!',7,13,10,'$'
MSG		DB	'2.13L ºº×ÖÏµÍ³ÅäÖÃ³ÌÐò ',DATE,13,10
		DB	'¸ñÊ½: LSETUP [/W][/?]',13,10
		DB	'ÆäÖÐ: /W - ´¦Àíµ±Ç°Ä¿Â¼µÄÏµÍ³ÅäÖÃÎÄ¼þ213L.INI',13,10
		DB	'           È±Ê¡:´¦Àí±¾³ÌÐòËùÔÚÄ¿Â¼µÄÅäÖÃÎÄ¼þ',13,10
		DB	'      /? - ÏÔÊ¾ËµÃ÷',13,10,'$'

D_210A		DB	4, 0, 0, 0

D_SPCZ		DB	'Ë«Æ´´Ê×éÀ©Õ¹Çø´óÐ¡(0~9):',0,0
D_XTKG		DB	'1-×ó,2-ÓÒSHIFT,3-SCROLL LOCK:',0,0

D_MODE		DB	0			;ÏÔÊ¾·½Ê½ºÅ
D_ZJXP		DB	0			;=1Ö±½ÓÐ´ÆÁ
D_CKBD		DW	0			;¼üÅÌÄ£¿é¶Î
D_HAN		DW	0			;ÎÄ¼þºÅ
D_SELE		DB	0			;Ö÷²Ëµ¥Ä¬ÈÏÑ¡ÔñºÅ
D_DX		DW	0			;ÎÄ¼þÃûÊ×
D_CX		DW	0			;    ³¤¶È
D_SX		DW	0			;    ÊôÐÔ

D_B1		DB	'ÉÍ»',0
D_B2		DB	'º º',0
D_B3		DB	'ÈÍ¼',0

;Ö÷²Ëµ¥
D_S1		DB	'ÉèÖÃ´æÅÌ²¢ÍË³ö    ',0
D_S2		DB	'²» ´æ ÅÌ ÍË ³ö    ',0
D_S3		DB	'ÊÇ·ñ·Â³¤³Ç¼üÅÌ  Y ',0
D_S4		DB	'°²×°Æ´ÒôÂë±í£¿  Y ',0
D_S5		DB	'°²×°Ê×Î²Âë±í£¿  N ',0
D_S6		DB	'°²×°µç±¨Âë±í£¿  N ',0
D_S7		DB	'Ë«Æ´´Ê×éÀ©Õ¹Çø  1K',0
D_S8		DB	'¹¦ÄÜ¿ª¹ØSHIFT:  ÓÒ',0
D_S9		DB	'Ñ¡Ôñ¹¦ÄÜ¼üÅäÖÃ    ',0
D_S10		DB	'ÖÃÏÔÊ¾Ä£¿é²ÎÊý    ',0
D_S11		DB	'ÐÞ¸ÄÎÄ¼þ213L.BAT  ',0,0

D_SB1		DB	'¶ÔÏµÍ³ÅäÖÃµÄÈÎºÎÐÞ¸Ä,±ØÐë´æÅÌ²Å¿ÉÔÚÖØÐÂÆô¶¯ºº×ÖÏµÍ³Ê±ÓÐÐ§!',0,0
D_SB2		DB	'±¾Ñ¡Ôñ¿ÉÈ¡ÏûËù×÷µÄÐÞ¸Ä. ËæÊ±¼üÈë<ESC>Ò²¿É.',0,0
D_SB3		DB	'101¼üÅÌ¹â±ê¼üÉÏ·½µÄ  ÇøÎ»(Insert)  Ê×  Î²(Home)  Æ´Òô(PageUp)',0
		DB	'6¸ö¼ü·Â³¤³ÇµÄ·½Ê½¼ü  Ë«Æ´(Delete)  È«/°ë½Ç(End)  Ó¢ÎÄ(PageDn)',0,0
D_SB4		DB	'Ö±½Ó»Ø³µ¼´¿ÉÑ¡Ôñ Y-°²×° »ò N-²»°²×°.',0
		DB	'  Èô²»°²×°Æ´ÒôÂë±í,ÔòË«Æ´´Ê×éÒ²½«Ê§Ð§,ÊäÈë·½·¨ÔòÈ¡ÏûÆ´ÒôºÍË«Æ´.',0,0
D_SB5		DB	'Ö±½Ó»Ø³µ¼´¿ÉÑ¡Ôñ Y-°²×° »ò N-²»°²×°.',0
		DB	'  Èô²»°²×°Ê×Î²Âë±í,ÔòÊäÈë·½·¨È¡ÏûÊ×Î².',0,0
D_SB6		DB	'Ö±½Ó»Ø³µ¼´¿ÉÑ¡Ôñ Y-°²×° »ò N-²»°²×°.',0
		DB	'  Èô²»°²×°µç±¨Âë±í,ÔòÊäÈë·½·¨È¡Ïûµç±¨.',0,0
D_SB7		DB	'±¾¹¦ÄÜ¿ÉÑ¡ÔñË«Æ´´Ê×éÀ©Õ¹Çø´óÐ¡,·¶Î§0-9,µ¥Î»ÎªK×Ö½Ú.',0
		DB	'  Èô²»°²×°Ë«Æ´´Ê×é,Ñ¡ÔñË«Æ´´Ê×éÀ©Õ¹ÇøÎª0¼´¿É.',0,0
D_SB8		DB	'¿ÉÑ¡ÔñÏµÍ³¹¦ÄÜ¼ü¿ª¹ØÊ¹ÓÃ×ó»òÓÒSHIFTÒÔ¼°SCROLL LOCK¼ü.',0,0
D_SB9		DB	'Ñ¡Ôñ´Ë¹¦ÄÜ,¿ÉÈÎÒâÅäÖÃÏµÍ³¹¦ÄÜ¼üµÄ¼üÎ».',0
		DB	'  Ö´ÐÐ´Ë¹¦ÄÜ½«ÏÔÊ¾¶þ¼¶²Ëµ¥¹©½øÒ»²½Ñ¡Ôñ.',0,0
D_SB10		DB	'±¾¹¦ÄÜ¿ÉÉèÖÃÏÔÊ¾Ä£¿éµÄÒ»Ð©ÖØÒª¹¤×÷²ÎÊý.',0
		DB	'  ÒÔ¼°ÌáÊ¾ÐÐÑÕÉ«µÄÉèÖÃ.',0,0
D_SB11		DB	'ÐÞ¸Ä±¾ÏµÍ³Æô¶¯Åú´¦ÀíÎÄ¼þ213L.BAT',0
		DB	'  ¿ÉÑ¡Ôñ¼üÅÌÄ£¿é¡¢ÌØÏÔÄ£¿é¡¢´òÓ¡Çý¶¯³ÌÐòµÈ.',0,0

D_SBZ1		DW	OFFSET D_SB1
D_SBZ2		DW	OFFSET D_SB2
D_SBZ3		DW	OFFSET D_SB3
D_SBZ4		DW	OFFSET D_SB4
D_SBZ5		DW	OFFSET D_SB5
D_SBZ6		DW	OFFSET D_SB6
D_SBZ7		DW	OFFSET D_SB7
D_SBZ8		DW	OFFSET D_SB8
D_DBZ9		DW	OFFSET D_SB9
D_SBZ10 	DW	OFFSET D_SB10
D_SBZ11 	DW	OFFSET D_SB11

C_DISP		DB	02H	;ÏÔÊ¾²ÎÊý1
C_DISP2 	DB	01H	;	 2
C_DISP3 	DB	05H	;	 3
C_DISP4 	DB	39H	;	 4
		DB	00
C_TUXN1 	DB	1EH	;ÌáÊ¾ÐÐÄÚÈÝ1
C_TUXN2 	DB	1AH	;	   2
C_TUXB1 	DB	4EH	;ÌáÊ¾ÐÐ±êÌâ1ÑÕÉ«
C_TUXB2 	DB	4AH	;	   2
		DB	00
C_SHIFT 	DB	01H	;=1ÓÒ,=2×ó
C_KEY		DB	64H	;ÖÐÎ÷ÎÄÏÔÊ¾¿ª¹Ø CTRL+F7
		DB	68H	;ÇøÎ»ÂëÊäÈë	ALT+F1
		DB	69H	;Ê×Î²ÂëÊäÈë	ALT+F2
		DB	6AH	;Æ´ÒôÂëÊäÈë	ALT+F3
		DB	6BH	;Ë«Æ´ÂëÊäÈë	ALT+F4
		DB	66H	;½¨Á¢/È¡Ïû´¿ÖÐÎÄCTRL+F9
		DB	6DH	;ASCIIÊäÈë	ALT+F6
		DB	6CH	;Îå±ÊÂëÊäÈë	ALT+F5
		DB	71H	;µç±¨ÂëÊäÈë	ALT+F10
		DB	86H	;Ô¤Ñ¡×ÖÊäÈë	F12
		DB	85H	;Áª»ú°ïÖú	F11
		DB	62H	;ÏµÍ³¿ØÖÆ	CTRL+F5
		DB	70H	;¶¨ÒåË«Æ´´Ê×é	ALT+F9
		DB	67H	;ÉèÖÃ´òÓ¡²ÎÊý	CTRL+F10
		DB	00	;
		DB	00	;
C_FCC		DB	59H	;·Â³¤³Ç¼üÅÌ	(Y»òN)
C_SPKZ		DB	31H	;Ë«Æ´´Ê×éÀ©Õ¹Çø (1-9)
C_PY		DB	59H	;°²×°Æ´ÒôÂë±í	(Y»òN)
C_SW		DB	4EH	;°²×°Ê×Î²Âë±í	(Y»òN)
C_DB		DB	4EH	;°²×°µç±¨Âë±í	(Y»òN)

;****************************************************************************
BEGIN:
		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_10
L_1:
		LODSB
		CMP	AL,' '
		JZ	L_1
		CMP	AL,0DH
		JZ	L_10
		CMP	AL,'/'
		JNZ	L_1
		LODSB
		CMP	AL,'?'
		JNZ	L_2
		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
		INT	20H
L_2:
		AND	AL,5FH
		CMP	AL,'W'                  ;´¦Àíµ±Ç°Ä¿Â¼INI
		JNZ	L_1
		MOV	D_W,AL
		JMP	SHORT L_1
L_10:
		XOR	BP,BP
		MOV	AH,2FH			;È¡¼üÅÌÄ£¿é¶Î
		INT	16H
		OR	BP,BP
		JNZ	L_12
		MOV	AX,0E07H
		INT	10H
		INT	20H
L_12:
		MOV	D_CKBD,BP
		MOV	ES,BP
		MOV	AL,ES:[100H]
		MOV	D_MODE,AL
		MOV	AL,ES:[102H]
		MOV	D_ZJXP,AL

		CMP	D_W,'W'                 ;ÐÞ¸Äµ±Ç°Ä¿Â¼ÅäÖÃÎÄ¼þ
		JNZ	L_20
		MOV	DX,OFFSET F_INI
		JMP	L_30
L_20:
		MOV	DS,DS:[2CH]		;»·¾³¶Î
		XOR	SI,SI
L_21:
		CMP	WORD PTR DS:[SI],0	;²éÕÒ»·¾³ÇøÎ²?
		JZ	L_22
		INC	SI
		JMP	SHORT L_21
L_22:
		ADD	SI,4
		MOV	DI,OFFSET D_FILE	;´øÂ·¾¶Ô´ÎÄ¼þÃûÇø
		PUSH	CS
		POP	ES
		CALL	S_MOVE
		PUSH	CS
		POP	DS
L_24:
		CMP	BYTE PTR [DI-1],'\'
		JZ	L_25
		CMP	BYTE PTR [DI-1],':'
		JZ	L_25
		DEC	DI
		JMP	SHORT L_24
L_25:
		MOV	SI,OFFSET F_INI
		CALL	S_MOVE
		MOV	DX,OFFSET D_FILE	;'213L.INI'
L_30:
		MOV	D_DX,DX 		;±£´æ
		MOV	AX,4300H		;È¡ÎÄ¼þÊôÐÔ
		INT	21H
		JB	L_40
		MOV	D_SX,CX 		;±£´æ
		MOV	CX,20H
		MOV	AX,4301H		;ÉèÖÃÊôÐÔ
		INT	21H

		MOV	AX,3D02H		;´ò¿ªÎÄ¼þ
		INT	21H
		JB	L_40
		MOV	D_HAN,AX		;ÎÄ¼þºÅ
		MOV	BX,AX
		MOV	DX,OFFSET B_BUF+100H	;¶ÁÈëµØÖ·
		MOV	CX,-1			;³¤¶È
		MOV	AH,3FH			;¶Á
		INT	21H
		JNB	SHORT L_50
L_40:
		MOV	DX,OFFSET NOINI 	;'NOT FOUND FILE'
		MOV	AH,9
		INT	21H
		MOV	AL,-1
		JMP	L_END
L_50:
		MOV	D_CX,AX 		;ÎÄ¼þ³¤¶È
L_S0:
		MOV	SI,OFFSET B_BUF+100H
		MOV	DI,OFFSET C_DISP	;²ÎÊý±í
		MOV	CX,32
L_S0A:
		CALL	S_GETB			;È¡Ò»²ÎÊý
		STOSB
		LOOP	L_S0A

		CALL	S_CLS			;ÇåÆÁ
L_S00:
;Ð´ÈëÖ÷²Ëµ¥×´Ì¬
		MOV	AL,C_FCC		;·Â³¤³Ç¼üÅÌ
		MOV	D_S3+16,AL
		MOV	AL,C_PY 		;Æ´ÒôÂë±í
		MOV	D_S4+16,AL
		MOV	AL,C_SW 		;Ê×Î²Âë±í
		MOV	D_S5+16,AL
		MOV	AL,C_DB 		;µç±¨Âë±í
		MOV	D_S6+16,AL
		MOV	AL,C_SPKZ		;Ë«Æ´´Ê×éÀ©Õ¹Çø´óÐ¡
		MOV	D_S7+16,AL
		MOV	AX,'ÓÒ'
		CMP	C_SHIFT,1		;ÓÒSHIFT
		JZ	L_S01
		MOV	AX,'×ó'
		CMP	C_SHIFT,2		;×óSHIFT
		JZ	L_S01
		MOV	AX,'SL'
L_S01:
		MOV	D_S8+16,AH
		MOV	D_S8+17,AL

		MOV	DX,D_0			;Ö÷²Ëµ¥Î»ÖÃ
		MOV	BX,C_0			;      ÑÕÉ«
		MOV	CX,A_0			;      ´óÐ¡
		CALL	S_XSCK			;ÏÔÊ¾¿Õ´°¿Ú
		MOV	SI,OFFSET D_XTPZ	;×Ü±êÌâ
		ADD	DX,104H
		MOV	BL,4EH
		CALL	S_XSZFC
		MOV	SI,OFFSET D_S1		;ÌáÊ¾´®Ê×
		MOV	DX,D_0
		ADD	DX,302H 		;Î»ÖÃ
		MOV	BX,C_0			;ÑÕÉ«
		CALL	S_CKXS			;ÏÔÊ¾

		MOV	SI,OFFSET D_S1		;²Ëµ¥Ê×
		MOV	BP,OFFSET D_SBZ1	;°ïÖúÖ¸Õë
		MOV	BH,19			;Ïî³¤
		MOV	CH,10			;ÏîÊý-1
		MOV	CL,D_SELE		;³õºÅ
		CALL	S_CDKZ			;²Ëµ¥¿ØÖÆ
		MOV	D_SELE,AL		;Ñ¡ÔñºÅ
;----------------------------------------------------------------------------
		CMP	AL,0			;**ÉèÖÃ´æÅÌ**
		JNZ	L_S2
		MOV	SI,OFFSET C_DISP	;²ÎÊý±í
		MOV	DI,OFFSET B_BUF+100H
		MOV	CX,32
L_S1A:
		LODSB
		CALL	S_SETB			;Ð´Èë²ÎÊý
		LOOP	L_S1A

		MOV	BX,D_HAN		;ÎÄ¼þºÅ
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4200H		;ÒÆ¶¯¶ÁÐ´Ö¸Õë
		INT	21H
		MOV	DX,OFFSET B_BUF+100H	;Ð´ÈëµØÖ·
		MOV	CX,D_CX 		;³¤¶È
		MOV	AH,40H			;Ð´ÅÌ
		INT	21H
		MOV	AH,3EH			;¹Ø±Õ
		INT	21H
L_S1B:
		MOV	DX,D_DX
		MOV	CX,D_SX
		MOV	AX,4301H		;»Ö¸´Ô­ÊôÐÔ
		INT	21H

		MOV	AX,1813H
		INT	10H
		CALL	S_KGB
		XOR	AL,AL
L_END:
		MOV	AH,4CH			;ÍË³ö
		INT	21H
;----------------------------------------------------------------------------
L_S2:
		CMP	AL,1			;**²»´æÅÌ**
		JZ	L_S1B
		CMP	AL,1BH			;<ESC>Í¬AL=1
		JZ	L_S1B
;----------------------------------------------------------------------------
L_S3:
		CMP	AL,2			;**·Â³¤³Ç¼üÅÌ**
		JNZ	L_S4
		MOV	AL,'Y'
		CMP	AL,C_FCC		;ÅÐ?
		JNZ	L_S3A
		MOV	AL,'N'
L_S3A:
		MOV	C_FCC,AL

		CMP	AL,'N'                  ;²»·Â³¤³Ç?
		JNZ	L_S3B
		MOV	BX,6869H		;ALT+F1~F6
		MOV	CX,6A6BH
		MOV	DX,666DH
		JMP	SHORT L_S3C
L_S3B:
		MOV	BX,0F1F2H
		MOV	CX,0F3F4H
		MOV	DX,0F5F6H
L_S3C:
		MOV	C_KEY+1,BH
		MOV	C_KEY+2,BL
		MOV	C_KEY+3,CH
		MOV	C_KEY+4,CL
		MOV	C_KEY+5,DH
		MOV	C_KEY+6,DL
		JMP	L_S00
;----------------------------------------------------------------------------
L_S4:
		CMP	AL,3			;**Æ´ÒôÂë±í**
		JNZ	L_S5
		MOV	BX,OFFSET C_PY
L_S4A:
		MOV	AL,'Y'
		CMP	AL,[BX] 		;ÅÐÔ­'Y'?
		JNZ	L_S4B
		MOV	AL,'N'
L_S4B:
		MOV	[BX],AL 		;Ð´Èë
		JMP	L_S00
;----------------------------------------------------------------------------
L_S5:
		CMP	AL,4			;**Ê×Î²Âë±í**
		JNZ	L_S6
		MOV	BX,OFFSET C_SW
		JMP	L_S4A
;----------------------------------------------------------------------------
L_S6:
		CMP	AL,5			;**µç±¨Âë±í**
		JNZ	L_S7
		MOV	BX,OFFSET C_DB
		JMP	L_S4A
;----------------------------------------------------------------------------
L_S7:
		CMP	AL,6			;**Ë«Æ´´Ê×éÀ©Õ¹Çø**
		JNZ	L_S8
		MOV	SI,OFFSET D_SPCZ	;'Ë«Æ´´Ê×éÀ©Õ¹Çø´óÐ¡:'
		CALL	S_INKEY 		;ÏÔÊ¾²¢¼üÈë->AL
		CMP	AL,0DH
		JZ	L_S7A
		MOV	C_SPKZ,AL		;Ð´Èë
L_S7A:
		JMP	L_S00
;----------------------------------------------------------------------------
L_S8:
		CMP	AL,7			;**Ñ¡ÔñÏµÍ³¹¦ÄÜ¿ª¹Ø¼ü**
		JNZ	L_S9
		MOV	SI,OFFSET D_XTKG	;'ÏµÍ³¹¦ÄÜ¿ª¹Ø¼ü..'
		CALL	S_INKEY 		;ÏÔÊ¾²¢¼üÈë->AL
		CMP	AL,'1'                  ;ÅÐ123?
		JB	L_S8B
		CMP	AL,'3'
		JA	L_S8B
		AND	AL,0FH
		CMP	AL,3			;ÅÐSCROOL LOCK?
		JNZ	L_S8A
		MOV	AL,16
L_S8A:
		MOV	C_SHIFT,AL		;´æ
L_S8B:
		JMP	L_S00
;----------------------------------------------------------------------------
L_S9:
		CMP	AL,8			;**ÉèÖÃ¹¦ÄÜ¼ü**
		JNZ	L_S10
		JMP	L_JPCS
;----------------------------------------------------------------------------
L_S10:
		CMP	AL,9			;**ÏÔÊ¾Ä£¿é²ÎÊý**
		JNZ	L_S11
		JMP	L_XSCS
;----------------------------------------------------------------------------
L_S11:
		CMP	AL,10			;**ÐÞ¸Ä213L.BAT**
		JNZ	L_S11A
		JMP	L_BAT
L_S11A:
		JMP	L_S00

;==¹¦ÄÜ¼üÅäÖÃ================================================================
D_PV		DB	'2.13L ¹¦ÄÜ¼üÅäÖÃ',0
D_PV1		DB	'¹¦   ÄÜ   ¼ü   ±í',0
D_PV0		DB	'CTRL+F7   1-ÖÐ/Î÷ÎÄÏÔÊ¾¿ª¹Ø',0
		DB	'ALT+F1    2-ÇøÎ»ÂëÊäÈë     ',0
		DB	'ALT+F2    3-Ê×Î²ÂëÊäÈë     ',0
		DB	'ALT+F3    4-Æ´ÒôÂëÊäÈë     ',0
		DB	'ALT+F4    5-Ë«Æ´ÂëÊäÈë     ',0
		DB	'CTRL+F9   6-½¨Á¢/È¡Ïû´¿ÖÐÎÄ',0
		DB	'ALT+F6    7-ASCIIÂëÊäÈë    ',0
		DB	'ALT+F5    8-Îå±Ê×ÖÐÍÊäÈë   ',0
		DB	'ALT+F10   9-µç±¨ÂëÊäÈë     ',0
		DB	'F12      10-Ô¤Ñ¡×ÖÊäÈë     ',0
		DB	'F11      11-Áª»ú°ïÖú       ',0
		DB	'CTRL+F5  12-ÏµÍ³¿ØÖÆ       ',0
		DB	'ALT+F9   13-¶¨ÒåË«Æ´´Ê×é   ',0
		DB	'CTRL+F10 14-ÉèÖÃ´òÓ¡²ÎÊý   ',0,0

D_GNJTS 	DB	'54H-SHIFT+F1   5EH-CTRL+F1    68H-ALT+F1    ',0
		DB	'55H-SHIFT+F2   5FH-CTRL+F2    69H-ALT+F2    ',0
		DB	'56H-SHIFT+F3   60H-CTRL+F3    6AH-ALT+F3    ',0
		DB	'57H-SHIFT+F4   61H-CTRL+F4    6BH-ALT+F4    ',0
		DB	'58H-SHIFT+F5   62H-CTRL+F5    6CH-ALT+F5    ',0
		DB	'59H-SHIFT+F6   63H-CTRL+F6    6DH-ALT+F6    ',0
		DB	'5AH-SHIFT+F7   64H-CTRL+F7    6EH-ALT+F7    ',0
		DB	'5BH-SHIFT+F8   65H-CTRL+F8    6FH-ALT+F8    ',0
		DB	'5CH-SHIFT+F9   66H-CTRL+F9    70H-ALT+F9    ',0
		DB	'5DH-SHIFT+F10  67H-CTRL+F10   71H-ALT+F10   ',0
D_GNJTS1	DB	'85H-F11        86H-F12        87H-SHIFT+F11 ',0
		DB	'88H-SHIFT+F12  89H-CTRL+F11   8AH-CTRL+F12  ',0
		DB	'8BH-ALT+F11    8CH-ALT+F12    8DH-CTRL+¡ü   ',0
		DB	'               (À©Õ¹ASCIIÂë-¹¦ÄÜ¼üÃû³Æ)     ',0,0

D_PVB1		DB	'¿ÉÇÐ»»ºº×Ö·½Ê½ºÍÎ÷ÎÄ·½Ê½µÄÏÔÊ¾,µ«ºº×ÖÏÔÊ¾Ä£¿é»¹Æð×÷ÓÃ.',0,0
D_PVB2		DB	'¿ÉÓÃËÄÎ»ÇøÎ»ÂëÊäÈëºº×Ö,Ò²¿É¼üÈëÇøºÅÔÙ´ò¿Õ¸ñ,°´ÇøÎ»Ë³ÐòÏÔÊ¾²¢Ñ¡Ôñ.',0,0
D_PVB3		DB	'¿ÉÓÃÊ×Î²ÂëÊäÈëºº×Ö.',0,0
D_PVB4		DB	'¿ÉÓÃÈ«Æ´Âë¡¢¼òÆ´Âë(³ýzh-VÍâÍ¬CCDOS)»òË«Æ´ÂëÊäÈëºº×Ö.',0,0
D_PVB5		DB	'¿ÉÓÃË«Æ´Âë»òË«Æ´¼Ó²¿Ê×ÂëÊäÈëºº×Ö,»ò´òËÄ¼üÖ±½ÓÉÏ´Ê.',0
		DB	'  ÆÕÍ¨²Ù×÷Õß¿É´ó´ó¼Ó¿ìºº×ÖÊäÈëËÙ¶È.Ö£ÖØÍÆ¼ö´ËÊäÈë·¨!',0,0
D_PVB6		DB	'½¨Á¢´¿ÖÐÎÄ·½Ê½,¼üÈëµÄ×Ö·û½«µÃµ½¶ÔÓ¦ÈýÇøµÄÍ¼ÐÎ·ûºÅ.',0,0
D_PVB7		DB	'È¡ÏûËùÓÐºº×ÖÊäÈë·¨,»Ö¸´Ó¢ÎÄÊäÈë.',0
		DB	'  Èô²»±£³ÖÏÔÊ¾ÌáÊ¾ÐÐ,Ôò½«Çå³ýÌáÊ¾ÐÐ.',0,0
D_PVB8		DB	'¿ÉÓÃÎå±Ê×ÖÐÍ·½Ê½ÊäÈëºº×ÖºÍ´Ê×é.±ØÐë°²×°WBXÄ£¿é',0,0
D_PVB9		DB	'¿ÉÓÃµç±¨ÂëÊäÈëºº×Ö.',0,0
D_PVB10 	DB	'¿ÉÔ¤Ñ¡Ò»Åúºº×Ö»òÍ¼ÐÎ·ûºÅ¹©Ñ¡ÔñÊäÈë.ÊäÈëÇëÓÃ´óÐ´×ÖÄ¸.',0
		DB	'  ÏµÍ³Ìá¹©ÓÐ³£ÓÃ¾ÅÇøÖÆ±í·û¡¢³£ÓÃ·ûºÅ¡¢ºº×ÖÊý×ÖµÄÈýÒ³Ô¤Ñ¡×Ö.',0,0
D_PVB11 	DB	'Ö´ÐÐÁª»ú°ïÖú,Ìá¹©ÏµÍ³ÐÅÏ¢.',0
		DB	'  ÐèÔÚDOSÏÂÏÈÖ´ÐÐLHELP',0,0
D_PVB12 	DB	'¿ÉÓÃÌáÊ¾ÐÐ²Ëµ¥·½Ê½¶ÔÏµÍ³½øÐÐ¿ØÖÆ.²Î¿´READMEÓÐ¹ØËµÃ÷.',0,0
D_PVB13 	DB	'¿ÉÔÚÏÖ³¡Ö±½Ó¶¨ÒåË«Æ´´Ê×é,²¢¿ÉÁ¢¼´Ê¹ÓÃ.',0
		DB	'  ÈôÒª´æÅÌ,Ó¦ÔÚDOSÏÂÖ´ÐÐCSP±£´æË«Æ´´Ê×é.',0,0
D_PVB14 	DB	'¿ÉÉèÖÃÈçÏÂ´òÓ¡²ÎÊý:×ÖÐÍ¡¢ÐÐ¾à¡¢×Ö·û¼ä¾à¡¢×ó±ß¿Õ¡¢ÐÐ¿í¡¢µ¥Ë«Ïò´òÓ¡.',0
		DB	'  »¹¿É¹Ø±Õ»ò»Ö¸´ÌØÊâ´òÓ¡¹¦ÄÜ¡¢¹Ø±Õ»ò»Ö¸´ºº×Ö´òÓ¡Çý¶¯Ä£¿é.',0,0

D_PVZ1		DW	OFFSET D_PVB1
D_PVZ2		DW	OFFSET D_PVB2
D_PVZ3		DW	OFFSET D_PVB3
D_PVZ4		DW	OFFSET D_PVB4
D_PVZ5		DW	OFFSET D_PVB5
D_PVZ6		DW	OFFSET D_PVB6
D_PVZ7		DW	OFFSET D_PVB7
D_PVZ8		DW	OFFSET D_PVB8
D_PVZ9		DW	OFFSET D_PVB9
D_PVZ10 	DW	OFFSET D_PVB10
D_PVZ11 	DW	OFFSET D_PVB11
D_PVZ12 	DW	OFFSET D_PVB12
D_PVZ13 	DW	OFFSET D_PVB13
D_PVZ14 	DW	OFFSET D_PVB14

L_JPCS:
		CALL	S_CLS			;ÇåÆÁ
		PUSH	CS
		POP	ES
L_S81:
		MOV	BP,OFFSET D_PV0 	;ÌáÊ¾´®Ê×
		MOV	SI,OFFSET C_KEY 	;¹¦ÄÜ¼üµØÖ·
		MOV	CX,14			;¸öÊý
L_S811:
		LODSB				;È¡¸÷¹¦ÄÜ¼ü
		CALL	S_SET
		ADD	BP,28
		LOOP	L_S811

		MOV	DX,D_9A
		MOV	BX,C_9A
		MOV	CX,A_9A
		CALL	S_XSCK
		MOV	SI,OFFSET D_PV1 	;'¹¦ÄÜ¼ü±í'
		ADD	DX,0EH			;Î»ÖÃ
		MOV	BL,4EH			;ÑÕÉ«
		CALL	S_XSZFC 		;ÏÔÊ¾
		MOV	SI,OFFSET D_GNJTS	;¹¦ÄÜ¼ü±í
		MOV	BX,C_9A 		;ÑÕÉ«
		MOV	DX,D_9A
		ADD	DX,101H
		CALL	S_CKXS			;ÏÔÊ¾

		MOV	DX,D_9
		MOV	BX,C_9
		MOV	CX,A_9
		CALL	S_XSCK
		MOV	SI,OFFSET D_PV		;'¹¦ÄÜ¼üÅäÖÃ'
		ADD	DX,7			;Î»ÖÃ
		MOV	BL,4EH			;ÑÕÉ«
		CALL	S_XSZFC 		;ÏÔÊ¾
L_S82:
		MOV	SI,OFFSET D_PV0 	;µ±Ç°ÉèÖÃ
		MOV	BX,C_9			;ÑÕÉ«
		MOV	DX,D_9
		ADD	DX,101H 		;Î»ÖÃ
		CALL	S_CKXS			;ÏÔÊ¾
		MOV	SI,OFFSET D_PV0 	;²Ëµ¥Ê×
		MOV	BP,OFFSET D_PVZ1	;°ïÖúÖ¸Õë
		MOV	BH,28			;Ïî³¤
		MOV	CH,13			;ÏîÊý-1
		MOV	CL,D_YH 		;Ä¬ÈÏºÅ
		CALL	S_CDKZ			;²Ëµ¥¿ØÖÆ
		CMP	AL,1BH			;<ESC>·µ»ØÖ÷²Ëµ¥
		JNZ	L_S821
		JMP	L_S0
L_S821:
		CMP	BYTE PTR DS:[DI],' '    ;ÅÐ·Â³¤³Ç¹¦ÄÜ¼ü?
		JNZ	L_S83
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_S82
L_S83:
		CBW
		ADD	AX,OFFSET C_KEY 	;Ñ¡¶¨¼üµØÖ·
		MOV	DI,AX
		MOV	AL,[DI] 		;È¡¼üÖµ
		XOR	AH,AH
		CMP	AL,85H
		JB	L_S831
		MOV	CH,10
		SUB	AL,85H
		MOV	CL,3
		DIV	CL
		ADD	CH,AL
		MOV	CL,AH
		JMP	SHORT L_S832
L_S831:
		MOV	CH,10
		SUB	AL,54H
		DIV	CH
		MOV	CX,AX
L_S832:
		MOV	D_YW,CX 		;¹¦ÄÜ¼ü±íCH=ÐÐ,CL=ÁÐ
		CALL	S_CD1			;ÒÔºìµ×°××ÖÏÔÊ¾
L_S84:
		XOR	AH,AH			;¼üÈëÑ¡Ôñ
		INT	16H
		OR	AL,AL			;ÅÐ¹¦ÄÜ¼ü?
		JNZ	L_S88
		CMP	AH,48H			;¡ü
		JNZ	L_S85
		OR	CH,CH
		JNZ	L_S841
		MOV	CH,15
		JMP	SHORT L_S842
L_S841:
		DEC	CH
L_S842:
		CALL	S_CD
		JMP	SHORT L_S84
L_S85:
		CMP	AH,50H			;¡ý
		JNZ	L_S86
		CMP	CH,15
		JNZ	L_S851
		XOR	CH,CH
		JMP	SHORT L_S842
L_S851:
		INC	CH
		JMP	SHORT L_S842
L_S86:
		CMP	AH,4BH			;¡û
		JNZ	L_S87
		OR	CL,CL
		JNZ	L_S861
		OR	CH,CH
		JZ	L_S862
		DEC	CH
		MOV	CL,2
		JMP	SHORT L_S842
L_S861:
		DEC	CL
		JMP	SHORT L_S842
L_S862:
		MOV	CX,0F02H
		JMP	SHORT L_S842
L_S87:
		CMP	AH,4DH			;¡ú
		JNZ	L_S883
		CMP	CL,2
		JNZ	L_S871
		CMP	CH,15
		JZ	L_S872
		INC	CH
		XOR	CL,CL
		JMP	SHORT L_S842
L_S871:
		INC	CL
		JMP	SHORT L_S842
L_S872:
		XOR	CX,CX
		JMP	SHORT L_S842
L_S88:
		CMP	AL,0DH			;»Ø³µÑ¡ÖÐ?
		JNZ	L_S89
		MOV	DX,D_YW
		MOV	BX,C_9A
		CALL	S_CD2
		CMP	CH,10
		JB	L_S881
		MOV	DL,85H
		SUB	CH,10
		MOV	AL,3
		MUL	CH
		ADD	AL,CL
		JMP	SHORT L_S882
L_S881:
		MOV	DL,54H
		MOV	AL,10
		MUL	CL
		ADD	AL,CH
L_S882:
		ADD	AL,DL
		MOV	[DI],AL 		;Ð´Èë
L_S883:
		JMP	L_S81
L_S89:
		CMP	AL,1BH			;<ESC>·µ»ØÖ÷²Ëµ¥
		JNZ	L_S883
		JMP	L_S0
;----------------------------------------------------------------------------
D_YW		DW	0
;×Ó³ÌÐò:ÏÔÊ¾²Ëµ¥
S_CD		PROC	NEAR
		MOV	DX,D_YW 		;Ô­Î»
		MOV	BX,C_9A
		CALL	S_CD2			;»Ö¸´
S_CD1:
		MOV	DX,CX			;ÏÖÎ»
		MOV	D_YW,DX
		MOV	BL,70H			;ºìµ×»Æ×Ö
S_CD2:
		MOV	AL,3
		MUL	DH
		ADD	AL,DL			;Ë³ÐòºÅ
		MOV	AH,15
		MUL	AH
		ADD	AX,OFFSET D_GNJTS
		MOV	BP,AX			;ÏÔÊ¾×Ö·û´®Ê×
		MOV	AL,15
		MUL	DL
		MOV	DL,AL
		ADD	DX,D_9A
		ADD	DX,101H
		PUSH	CX
		MOV	CX,15
		CALL	S_XSZFI 		;ÏÔÊ¾
		POP	CX
		RET
;×Ó³ÌÐò:ÏÔÊ¾×Ö·û´®DS:BP,CX=³¤¶È,DX=Î»ÖÃ,BL=ÊôÐÔ
S_XSZFI:
		MOV	BH,DS:[BP]		;È¡×Ö·û
		INC	BP
		CALL	S_XSZF
		LOOP	S_XSZFI
		RET
S_CD		ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:Ð´Èë¹¦ÄÜ¼üÃû
S_SET		PROC	NEAR
		PUSH	SI
		CMP	AL,0F0H 		;·Â³¤³Ç¼ü?
		JB	L_SET3
		MOV	AL,9			;¿Õ
		JMP	SHORT L_SET4
L_SET3:
		CMP	AL,85H			;F11,F12
		JB	L_SET5
		SUB	AL,85H
L_SET4:
		MOV	SI,OFFSET D_GNJTS1
		JMP	SHORT L_SET6
L_SET5:
		SUB	AL,54H			;SHIFTF1~ALTF10
		CBW
		MOV	DL,10
		DIV	DL
		MOV	DL,AL
		MOV	AL,3
		MUL	AH
		ADD	AL,DL
		MOV	SI,OFFSET D_GNJTS
L_SET6:
		MOV	AH,15
		MUL	AH
		ADD	SI,AX
		ADD	SI,4
		MOV	DI,BP
		PUSH	CX
		MOV	CX,9
		REP	MOVSB			;Ð´Èë¼üÃû
		POP	CX
		POP	SI
		RET
S_SET		ENDP

;==ÏÔÊ¾Ä£¿é²ÎÊý==============================================================
D_XS0		DB	'2.13L ÏÔÊ¾Ä£¿é²ÎÊýÉèÖÃ',0
D_XS1		DB	'Ê¹ÓÃÀ©Õ¹×Ö·û¿â(Y£¯N) N',0
D_XS2		DB	'Ö§³ÖÖ±½ÓÐ´ÆÁ£¿(Y£¯N) Y',0
D_XS3		DB	'ÏÔÊ¾·½Ê½>5¼´ÏÔÊ¾ºº×Ö N',0
D_XS4		DB	'ÌáÊ¾ÐÐ¹â´øÑÕÉ«(0£­9) 9',0
D_XS5		DB	'ÏÔÊ¾ÏµÍ³ÐÅÏ¢£¿(Y£¯N) Y',0
D_XS6		DB	'¹â±êÏÂÒÆ£²Ïß£¿(Y£¯N) N',0
D_XS7		DB	'CGAµ÷É«°å¿ª¹Ø?(Y£¯N) N',0
D_XS8		DB	'È¡ÏûÆÁÄ»·Ö¸î£¿(Y£¯N) N',0
D_XS9		DB	'±£³ÖÏÔÊ¾ÌáÊ¾ÐÐ(Y£¯N) Y',0
D_XS10		DB	'¿É±ä»ò¹Ì¶¨¹â±ê(Y£¯N) Y',0
D_XS11		DB	'³õÊ¼ÊôÐÔ¼Ä´æÆ÷(Y£¯N) Y',0
D_XS12		DB	'Í¼ÐÎ·½Ê½´ò¿ªB8(Y£¯N) N',0
D_XS13		DB	'ÏÔÊ¾ÖÐ¶Ïµ÷BIOS(Y£¯N) N',0
D_XS14		DB	'ÌáÊ¾ÐÐÄÚÈÝ£±ÑÕÉ« £­ 1E',0
D_XS15		DB	'ÌáÊ¾ÐÐÄÚÈÝ£²ÑÕÉ« £­ 1A',0
D_XS16		DB	'ÌáÊ¾ÐÐ±êÌâ£±ÑÕÉ« £­ 4E',0
D_XS17		DB	'ÌáÊ¾ÐÐ±êÌâ£²ÑÕÉ« £­ 4A',0,0

D_GDS		DB	'Çë¼üÈëÌáÊ¾ÐÐ¹â´øÑÕÉ«ºÅ(0-9):',0,0
D_AL1		DB	0

D_XSB1		DB	'Y¿ÉÊ¹ÓÃÍâ¼ÓµÄÀ©Õ¹×Ö·û¿â(³¤³ÇÏÔÊ¾×Ö·ûÌå.Òª¶àÕ¼ÄÚ´æ4K).',0
		DB	'NÖ±½ÓÊ¹ÓÃVGA¿¨ÉÏµÄ×Ö·û¿â.',0,0
D_XSB2		DB	'Ö§³ÖÖ±½ÓÐ´ÆÁ,´ó¶àÊýÎ÷ÎÄ×Ö·ûÐÍÈí¼þÎãÐèºº»¯¼´¿ÉÊ¹ÓÃºº×Ö.',0
		DB	'  Ö§³ÖVGA¡¢EGAºÍHGA(Ë«Æµµ¥ÏÔ)¿¨.',0,0
D_XSB3		DB	'Y-ÈôÉèÖÃÏÔÊ¾·½Ê½ºÅ´óÓÚ5Ê±¾Í¿ÉÏÔÊ¾ºº×Ö(Ö÷ÒªÓÃÓÚºº»¯Èí¼þµÈ).',0
		DB	'N-ÉèÖÃÊ²Ã´ÏÔÊ¾·½Ê½¾Í¿É½øÈëËùÉèµÄÏÔÊ¾·½Ê½.¿ÉÖ±½ÓÔËÐÐ¼¸ºõËùÓÐ³ÌÐò.',0,0
D_XSB4		DB	'ÔÚTVGA»òÓëÖ®¼æÈÝµÄÏÔÊ¾¿¨²¢Ê¹ÓÃVGAÄ£¿éÊ±,ÌáÊ¾ÐÐÉÏÏÂ½«ÓÐ¶þÌõ¹â´ø.',0
		DB	'  ±¾¹¦ÄÜ¿ÉÉèÖÃ´Ë¹â´øµÄÑÕÉ«,·¶Î§0-9.µ±ÉèÖÃÎª0Ê±½«È¡Ïû¹â´ø.',0,0
D_XSB5		DB	'¿É´ò¿ª»ò¹Ø±ÕÆô¶¯±¾ºº×ÖÏµÍ³Ê±ÏÔÊ¾µÄÏµÍ³ÐÅÏ¢.',0,0
D_XSB6		DB	'Ê¹ÓÃVGAÄ£¿éÊ±,¿É½«¹â±êÏÔÊ¾ÔÚÐÐ¼äµÄÁ½ÌõÏßÉÏ.',0,0
D_XSB7		DB	'ÏÔÊ¾ÖÐ¶ÏINT10HÖÐAH=0BHÉèÖÃCGAµ÷É«°å´¦Àí:µ÷BIOS»òÖ±½Ó·µ»Ø.',0
		DB	'  Ò»°ãÇé¿öÏÂÓ¦ÉèÖÃÎªN.',0,0
D_XSB8		DB	'ÔÚÄ³Ð©SVGAÏÔÊ¾µÄ»úÆ÷ÉÏÖ±½ÓÐ´ÆÁ¿ÉÄÜÏÔÊ¾»ìÂÒ,¿É´ò¿ª´Ë¹¦ÄÜÒ»ÊÔ.',0,0
D_XSB9		DB	'¿É±£³ÖÌáÊ¾ÐÐ´ò¿ª×´Ì¬,ÒÔËæÊ±ÁË½âµ±Ç°ºº×ÖÊäÈë×´Ì¬.',0
		DB	'  Èô²»±£³ÖÌáÊ¾ÐÐ´ò¿ª,Ôò¿ÉËæÊ±¹Ø±ÕÌáÊ¾ÐÐ,´¦ÀíÍ¼ÐÎÍ¼ÏóÊ±ÌØ±ðÐèÒª.',0,0
D_XSB10 	DB	'Ä¬ÈÏ¹â±ê´óÐ¡¿ÉÓÉÈí¼þ¿ØÖÆ(Y),ÈçDOSÏÂºÍEDIT»òPE±à¼­ÖÐ²åÈëºÍÐÞ¸Ä×´Ì¬.',0
		DB	'  Ò²¿ÉÉèÖÃ³É¹Ì¶¨¹â±êÎª2Ïß(N)',0,0
D_XSB11 	DB	'ÔÚ½øÈëINT10ÖÐ¶ÏÊ±³õÊ¼»¯ÊôÐÔ¼Ä´æÆ÷,¿É±£Ö¤ºº×Ö·½Ê½ÏÂÏÔÊ¾Õý³£.',0,0
D_XSB12 	DB	'ÉèÖÃÍ¼ÐÎÏÔÊ¾·½Ê½(VGAÎª12H,EGAÎª10H)´ò¿ªB800H¶Î.',0
		DB	'  ¿ÉÔÚVGAºÍEGAÊ¹ÓÃÏÔÊ¾»º³åÇø°²×°Ë«Æ´´Ê×éµÈ.',0,0
D_XSB13 	DB	'Y-ÏÔÊ¾ÖÐ¶ÏÖÐÏÔÊ¾×Ö·ûºÍ¹öÆÁÄ»Ö±½Óµ÷BIOS.ÔÚC¡¢PASCALºÍLISTµÈ¹öÆÁÕý³£.',0
		DB	'N-ÉÏÊö¹¦ÄÜÓÉ±¾ÏµÍ³ÏÔÊ¾Ä£¿é´¦Àí(°²×°Ä¬ÈÏ×´Ì¬)',0,0
D_XSB14 	DB	'ÄÚÈÝ¾ÍÊÇÌáÊ¾ÐÐÏÔÊ¾µÄÖØÂë×Ö»ò´Ê(×Ö±¾ÉíºÍ´ÊµÄÐòºÅ).',0,0
D_XSB15 	DB	'ÄÚÈÝ¾ÍÊÇÌáÊ¾ÐÐÏÔÊ¾µÄÖØÂë×Ö»ò´Ê(´Ê±¾ÉíºÍ×ÖµÄÐòºÅ).',0,0
D_XSB16 	DB	'±êÌâ¾ÍÊÇÌáÊ¾ÐÐ×ó¶ËÏÔÊ¾µÄºº×ÖÊäÈë·¨µÈ(¶ÔÍâÏÔÊ¾ÎªÍ¼ÐÎÊ±).',0,0
D_XSB17 	DB	'±êÌâ¾ÍÊÇÌáÊ¾ÐÐ×ó¶ËÏÔÊ¾µÄºº×ÖÊäÈë·¨µÈ(¶ÔÍâÏÔÊ¾Îª×Ö·ûÊ±).',0,0

D_XSZ1		DW	OFFSET D_XSB1
D_XSZ2		DW	OFFSET D_XSB2
D_XSZ3		DW	OFFSET D_XSB3
D_XSZ4		DW	OFFSET D_XSB4
D_XSZ5		DW	OFFSET D_XSB5
D_XSZ6		DW	OFFSET D_XSB6
D_XSZ7		DW	OFFSET D_XSB7
D_XSZ8		DW	OFFSET D_XSB8
D_XSZ9		DW	OFFSET D_XSB9
D_XSZ10 	DW	OFFSET D_XSB10
D_XSZ11 	DW	OFFSET D_XSB11
D_XSZ12 	DW	OFFSET D_XSB12
D_XSZ13 	DW	OFFSET D_XSB13
D_XSZ14 	DW	OFFSET D_XSB14
D_XSZ15 	DW	OFFSET D_XSB15
D_XSZ16 	DW	OFFSET D_XSB16
D_XSZ17 	DW	OFFSET D_XSB17

D_16		DB	'0123456789ABCDEF'
D_INPUT 	DB	'Çë¼üÈë:',0,0
D_INPBUF	DB	0,0,0

L_XSCS:
		MOV	SI,OFFSET C_DISP	;ÏÔÊ¾Ä£¿é²ÎÊýÊ×
		LODSB
		MOV	AH,'Y'
		TEST	AL,1			;=1Ê¹ÓÃÀ©Õ¹×Ö·û¿â
		JNZ	L_XS1
		MOV	AH,'N'
L_XS1:
		MOV	D_XS1+21,AH
		MOV	AH,'Y'
		TEST	AL,2			;=1¹Ø±ÕÌáÊ¾ÐÐ
		JNZ	L_XS1A
		MOV	AH,'N'
L_XS1A:
		MOV	D_XS9+21,AH
		MOV	AH,'Y'
		TEST	AL,8			;=1²»ÏÔÊ¾ÏµÍ³ÐÅÏ¢
		JZ	L_XS2
		MOV	AH,'N'
L_XS2:
		MOV	D_XS5+21,AH

		LODSB
		MOV	AH,'Y'
		TEST	AL,1			;=1Ö§³ÖÖ±½ÓÐ´ÆÁ
		JNZ	L_XS3
		MOV	AH,'N'
L_XS3:
		MOV	D_XS2+21,AH		;10.24
		MOV	AH,'Y'
		TEST	AL,2			;=1Í¼ÐÎ·½Ê½´ò¿ªB8
		JNZ	L_XS3A
		MOV	AH,'N'
L_XS3A:
		MOV	D_XS12+21,AH
		MOV	AH,'Y'
		TEST	AL,4			;=1ÏÔÊ¾ÖÐ¶Ïµ÷BIOS
		JNZ	L_XS3B
		MOV	AH,'N'
L_XS3B:
		MOV	D_XS13+21,AH
		MOV	AH,'Y'
		TEST	AL,8			;=1¹â±êÏÂÒÆ2Ïß
		JNZ	L_XS4
		MOV	AH,'N'
L_XS4:
		MOV	D_XS6+21,AH

		LODSB
		MOV	AH,'Y'
		TEST	AL,1			;=1ÏÔÊ¾·½Ê½>5¼´ºº×Ö
		JZ	L_XS5
		MOV	AH,'N'
L_XS5:
		MOV	D_XS3+21,AH
		MOV	AH,'Y'
		TEST	AL,2			;=1¿É±ä¹â±ê
		JZ	L_XS5A
		MOV	AH,'N'
L_XS5A:
		MOV	D_XS10+21,AH
		MOV	AH,'Y'
		TEST	AL,4			;=1³õÊ¼»¯ÊôÐÔ¼Ä´æÆ÷
		JNZ	L_XS5B
		MOV	AH,'N'
L_XS5B:
		MOV	D_XS11+21,AH
		MOV	AH,'Y'
		TEST	AL,8			;=1CGAµ÷É«°åµ÷BIOS
		JNZ	L_XS6
		MOV	AH,'N'
L_XS6:
		MOV	D_XS7+21,AH

		LODSB
		CMP	AL,'0'
		JB	L_XS7
		CMP	AL,'9'                  ;ÌáÊ¾ÐÐ¹â´øÉ«
		JA	L_XS7
		MOV	D_XS4+21,AL
		JMP	SHORT L_XS8
L_XS7:
		MOV	D_XS4+21,' '
L_XS8:
		MOV	AH,'Y'
		CMP	AL,'9'                  ;È¡ÏûÆÁÄ»·Ö¸î
		JA	L_XS9
		MOV	AH,'N'
L_XS9:
		MOV	D_XS8+21,AH

		MOV	SI,OFFSET C_TUXN1	;ÌáÊ¾ÐÐÑÕÉ«´®Ê×
		MOV	DI,OFFSET D_XS14+20	;Ð´ÈëÎ»ÖÃ
		MOV	CX,4
L_XS9A:
		LODSB
		CALL	S_16
		MOV	WORD PTR DS:[DI],AX	;Ð´Èë
		ADD	DI,23
		LOOP	L_XS9A

		MOV	DX,D_14 		;
		MOV	BX,C_14
		MOV	CX,A_14
		CALL	S_XSCK
		MOV	SI,OFFSET D_XS0 	;ÏÔÊ¾±êÌâ
		ADD	DX,102H 		;Î»ÖÃ
		MOV	BL,4EH			;ÑÕÉ«
		CALL	S_XSZFC 		;ÏÔÊ¾²Ëµ¥
		MOV	SI,OFFSET D_XS1 	;ÏÔÊ¾²Ëµ¥
		MOV	DX,D_14
		ADD	DX,302H 		;Î»ÖÃ
		MOV	BX,C_14 		;ÑÕÉ«
		CALL	S_CKXS			;ÏÔÊ¾²Ëµ¥

		MOV	SI,OFFSET D_XS1 	;²Ëµ¥Ê×
		MOV	BP,OFFSET D_XSZ1	;°ïÖúÖ¸Õë
		MOV	BH,23			;Ïî³¤
		MOV	CH,16			;ÏîÊý-1
		MOV	CL,D_AL1		;³õÊ¼ºÅ
		CALL	S_CDKZ			;²Ëµ¥¿ØÖÆ
		CMP	AL,1BH			;<ESC>·µ»ØÖ÷²Ëµ¥
		JNZ	L_XS10
		MOV	DX,D_14 		;
		MOV	BX,11H
		MOV	CX,A_14
		CALL	S_XSCK
		JMP	L_S00
L_XS10:
		MOV	D_AL1,AL		;´æÑ¡ÔñºÅ

		CMP	AL,0			;<Ê¹ÓÃÀ©Õ¹×Ö·û¿â>
		JNZ	L_XS20
		XOR	C_DISP,1
		JMP	L_XSCS
L_XS20:
		CMP	AL,1			;<Ö§³ÖÖ±½ÓÐ´ÆÁ>
		JNZ	L_XS30
		XOR	C_DISP2,1
		JMP	L_XSCS
L_XS30:
		CMP	AL,2			;<ÏÔÊ¾·½Ê½>5¼´ºº×Ö>
		JNZ	L_XS40
		XOR	C_DISP3,1
		MOV	AL,14
		TEST	C_DISP3,1
		JZ	L_XS33
		MOV	AL,15
L_XS33:
		MOV	AH,18H			;Ö´ÐÐ
		INT	10H
		JMP	L_XSCS
L_XS40:
		CMP	AL,3			;<ÌáÊ¾ÐÐ¹â´øÉ«>
		JNZ	L_XS50
		MOV	SI,OFFSET D_GDS 	;'ÌáÊ¾ÐÐ¹â´øÑÕÉ«ºÅ(0-9):'
		CALL	S_INKEY 		;ÏÔÊ¾²¢¼üÈë×Ö·û
		CMP	AL,'0'
		JB	L_XS41
		CMP	AL,'9'
		JA	L_XS41
		MOV	C_DISP4,AL		;Ð´Èë
		MOV	BL,AL
		MOV	AX,1405H		;Ö´ÐÐ
		INT	10H
L_XS41:
		JMP	L_XSCS
L_XS50:
		CMP	AL,4			;<ÏÔÊ¾ÏµÍ³ÐÅÏ¢>
		JNZ	L_XS60
		XOR	C_DISP,8
		JMP	L_XSCS
L_XS60:
		CMP	AL,5			;<¹â±êÏÂÒÆ2Ïß>
		JNZ	L_XS70
		XOR	C_DISP2,8
		JMP	L_XSCS
L_XS70:
		CMP	AL,6			;<CGAµ÷É«°å>
		JNZ	L_XS80
		XOR	C_DISP3,8
		JMP	L_XSCS
L_XS80:
		CMP	AL,7			;<È¡ÏûÆÁÄ»·Ö¸î>
		JNZ	L_XS90
		MOV	AL,C_DISP4
		CMP	AL,'9'
		JA	L_XS82
		MOV	AL,'A'
		JMP	SHORT L_XS84
L_XS82:
		MOV	AL,' '
L_XS84:
		MOV	C_DISP4,AL
		JMP	L_XSCS
L_XS90:
		CMP	AL,8			;<¹Ø±ÕÌáÊ¾ÐÐ>
		JNZ	L_XS95
		XOR	C_DISP,2
		JMP	L_XSCS
L_XS95:
		CMP	AL,9			;<¿É±ä»ò¹Ì¶¨¹â±ê>
		JNZ	L_XS100
		XOR	C_DISP3,2
		MOV	BH,1
		TEST	C_DISP3,2
		JZ	L_XS96
		MOV	BX,2
L_XS96:
		MOV	AX,180DH		;Ö´ÐÐ
		INT	10H
		JMP	L_XSCS
L_XS100:
		CMP	AL,10			;<INT10³õÊ¼»¯ÊôÐÔ¼Ä´æÆ÷>
		JNZ	L_XS110
		XOR	C_DISP3,4
		JMP	L_XSCS
L_XS110:
		CMP	AL,11			;<Í¼ÐÎ·½Ê½´ò¿ªB8>
		JNZ	L_XS120
		XOR	C_DISP2,2
		JMP	L_XSCS
L_XS120:
		CMP	AL,12			;<ÏÔÊ¾ÖÐ¶Ïµ÷BIOS>
		JNZ	L_XS130
		XOR	C_DISP2,4
L_XS130:
		CMP	AL,13			;<ÌáÊ¾ÐÐÄÚÈÝ1ÑÕÉ«>
		JNZ	L_XS140
		CALL	S_INCOLOR		;¼üÈëÊ®Áù½øÖÆÑÕÉ«Öµ
		JB	L_XS133
		MOV	C_TUXN1,AL
L_XS133:
		JMP	L_XSCS
L_XS140:
		CMP	AL,14			;<ÌáÊ¾ÐÐÄÚÈÝ2ÑÕÉ«>
		JNZ	L_XS150
		CALL	S_INCOLOR		;¼üÈëÊ®Áù½øÖÆÑÕÉ«Öµ
		JB	L_XS144
		MOV	C_TUXN2,AL
L_XS144:
		JMP	L_XSCS
L_XS150:
		CMP	AL,15			;<ÌáÊ¾ÐÐ±êÌâ1ÑÕÉ«>
		JNZ	L_XS160
		CALL	S_INCOLOR		;¼üÈëÊ®Áù½øÖÆÑÕÉ«Öµ
		JB	L_XS155
		MOV	C_TUXB1,AL
L_XS155:
		JMP	L_XSCS
L_XS160:
		CMP	AL,16			;<ÌáÊ¾ÐÐ±êÌâ2ÑÕÉ«>
		JNZ	L_XS170
		CALL	S_INCOLOR		;¼üÈëÊ®Áù½øÖÆÑÕÉ«Öµ
		JB	L_XS166
		MOV	C_TUXB2,AL
L_XS166:
		JMP	L_XSCS
L_XS170:
		JMP	L_XSCS

;==ÐÞ¸Ä213L.BAT==============================================================
D_XGBAT 	DB	'ÐÞ¸Ä213L.BAT',0
D_XG1		DB	'Ñ¡ÔñÌØÏÔÄ£¿é(K,V,0):  ',0
D_XG2		DB	'Ñ¡Ôñ´òÓ¡Ä£¿é  (N,H):  ',0
D_XG3		DB	'Ñ¡ÔñHPÖ§³ÖµÄ´òÓ¡»úºÅ  ',0
D_XG4		DB	'Ñ¡ÔñNTÖ§³ÖµÄ´òÓ¡»úºÅ  ',0
D_XG5		DB	'¶Á´òÓ¡×Ö¿â·½Ê½(n,W):  ',0
D_XG6		DB	'´æÅÌ:´æÎÄ¼þ 213L.BAT  ',0,0

D_XGB1		DB	'¿ÉÑ¡K(INT10K)»òV(INT10V).ÈôÑ¡0Ôò²»×¤ÁôÌØÏÔÄ£¿é.',0,0
D_XGB2		DB	'»Ø³µÑ¡Ôñ´òÓ¡»úÇý¶¯³ÌÐò:N-PRNT,H-PRTH.',0
		DB	'    Ñ¡Ôñºó»¹Òª¼ÌÐøÑ¡Ôñ´òÓ¡»úºÅ.',0,0
D_XGB3		DB	'ÒÑ¾­Ñ¡ÔñÁËÖ§³Ö¼¤¹âºÍÅçÄ«´òÓ¡»úµÄPRTH¿ÉÔÙ´ÎÑ¡Ôñ´òÓ¡»úºÅ.',0,0
D_XGB4		DB	'ÒÑ¾­Ñ¡ÔñÁËÖ§³Ö24Õë´òÓ¡»úµÄPRNT¿ÉÔÙ´ÎÑ¡Ôñ´òÓ¡»úºÅ.',0,0
D_XGB5		DB	'n-¶Á×Ö¿âÄ£¿éREAD24,READ32,READ40ºÍREADSLÊ¹ÓÃINT13ÖÐ¶ÏÖ±½Ó¶Á×Ö¿âÉÈÇø.',0
		DB	'W-ÉÏÊöÄ£¿éÓÃÎÄ¼þ·½Ê½¶Á×Ö¿â(ÓÃÓÚÑ¹ËõÅÌ¡¢¹âÅÌ»òÍøÂç·þÎñÆ÷)',0,0
D_XGB6		DB	'½«ÐÞ¸ÄµÄ½á¹û±£´æµ½ÎÄ¼þ C:\213L.BAT.',0,0

D_XGZ1		DW	OFFSET D_XGB1
D_XGZ2		DW	OFFSET D_XGB2
D_XGZ3		DW	OFFSET D_XGB3
D_XGZ4		DW	OFFSET D_XGB4
D_XGZ5		DW	OFFSET D_XGB5
D_XGZ6		DW	OFFSET D_XGB6

D_PRTH		DB	'PRTH ´òÓ¡»úÑ¡Ôñ',0
D_PRTHB 	DB	'10 : HP-2            ',0
		DB	'11 : HP-3            ',0
		DB	'13 : PECAN 300DPI    ',0
		DB	'14 : PECAN 400DPI    ',0
		DB	'16 : HP JET 500      ',0
		DB	'19 : ¼ÑÄÜ LBP-8II    ',0
		DB	'20 : ±±¼Ñ·ÂÕæHP400DPI',0
		DB	'21 : XP-11-B4 400Dpi ',0
		DB	'22 : XP-11-A4 400DPI ',0
		DB	'23 : ¼ÑÄÜ BJ-10ex    ',0,0

D_PRTHB1	DB	'ÓÃ¹â±ê¼üÉÏÏÂÑ¡Ôñ´òÓ¡»ú,»Ø³µÑ¡ÖÐ',0,0

D_PRTHZ1	DW	OFFSET D_PRTHB1
D_PRTHZ2	DW	OFFSET D_PRTHB1
D_PRTHZ3	DW	OFFSET D_PRTHB1
D_PRTHZ4	DW	OFFSET D_PRTHB1
D_PRTHZ5	DW	OFFSET D_PRTHB1
D_PRTHZ6	DW	OFFSET D_PRTHB1
D_PRTHZ7	DW	OFFSET D_PRTHB1
D_PRTHZ8	DW	OFFSET D_PRTHB1
D_PRTHZ9	DW	OFFSET D_PRTHB1
D_PRTHZ10	DW	OFFSET D_PRTHB1

D_PRNT1 	DB	'PRNT ´òÓ¡»úÑ¡Ôñ',0
D_PRNTB 	DB	'0 - AR3240       ',0
		DB	'1 - P1351        ',0
		DB	'2 - M2024(M1724) ',0
		DB	'3 - TH3070(3080) ',0
		DB	'4 - AR2463       ',0
		DB	'5 - LQ1500(NECP7)',0
		DB	'6 - OKI8320,8330 ',0
		DB	'7 - M1570        ',0
		DB	'8 - NEC3824      ',0
		DB	'9 - NM9400       ',0,0

D_PRNTB1	DB	'AR3240: »¹¿ÉÓÃÓÚCR3240¡¢3200´òÓ¡»ú.',0,0
D_PRNTB2	DB	'P1351: »¹¿ÉÓÃÓÚP1351¡¢P350²ÊÉ«´òÓ¡»ú.',0,0
D_PRNTB3	DB	'M2024: »¹¿ÉÓÃÓÚM1724¡¢M1924´òÓ¡»ú.',0,0
D_PRNTB4	DB	'TH3070: »¹¿ÉÓÃÓÚKC3070¡¢×Ï½ð3070ºÍ3080ÏµÁÐ´òÓ¡»ú.',0,0
D_PRNTB5	DB	'AR2463',0,0
D_PRNTB6	DB	'LQ1500: »¹¿ÉÓÃÓÚÆäËûLQÏµÁÐ¡¢NEC P7¡¢VP8624ÒÔ¼°ÓëEPSON¼æÈÝµÄ´òÓ¡»ú.',0,0
D_PRNTB7	DB	'OKI8320: »¹¿ÉÓÃÓÚÆäËûOKIÏµÁÐ24Õë´òÓ¡»ú.',0,0
D_PRNTB8	DB	'M1570',0,0
D_PRNTB9	DB	'NEC3824: »¹¿ÉÓÃÓÚNEC P5´òÓ¡»ú.',0,0
D_PRNTB10	DB	'NM9400',0,0

D_PRNTZ1	DW	OFFSET D_PRNTB1
D_PRNTZ2	DW	OFFSET D_PRNTB2
D_PRNTZ3	DW	OFFSET D_PRNTB3
D_PRNTZ4	DW	OFFSET D_PRNTB4
D_PRNTZ5	DW	OFFSET D_PRNTB5
D_PRNTZ6	DW	OFFSET D_PRNTB6
D_PRNTZ7	DW	OFFSET D_PRNTB7
D_PRNTZ8	DW	OFFSET D_PRNTB8
D_PRNTZ9	DW	OFFSET D_PRNTB9
D_PRNTZ10	DW	OFFSET D_PRNTB10

D_BAT		DB	'C:\213L.BAT',0
H_BAT		DW	0			;HANDLE
D_END		DW	0			;ÎÄ¼þÎ²µØÖ·
NO213L		DB	'Î´ÕÒµ½Åú´¦ÀíÎÄ¼þC:\213L.BAT!',0
NOCKB		DB	'Åú´¦ÀíÎÄ¼þC:\213L.BATÖÐÎÞ¼üÅÌÄ£¿é!',0
NOCCDISP	DB	'Åú´¦ÀíÎÄ¼þC:\213L.BATÖÐÎÞCCDISPÐÐ',0
NOPRTH		DB	'Åú´¦ÀíÎÄ¼þC:\213L.BATÖÐÎÞPRTHÐÐ',0
D_SELE15	DB	0
D_SELEPR	DB	0
F_R16		DB	3,'R16'
F_CKB		DB	3,'CKB'
F_CCDISP	DB	6,'CCDISP'
F_INT10 	DB	5,'INT10?',13,10
F_READ16	DB	6,'READ16'
F_READ24	DB	6,'READ24'
F_READ32	DB	6,'READ32'
F_READ40	DB	6,'READ40'
F_READSL	DB	6,'READSL'
F_PR		DB	3,'PR 00',13,10
F_PRNT		DB	4,'PRNT',13,10
F_PRTH		DB	4,'PRTH',13,10
K_INT10 	DB	'ÇëÑ¡Ôñ(K,V,0):',0
K_READ24	DB	'ÇëÑ¡Ôñ(1-9,W):',0
;----------------------------------------------------------------------------
L_BAT:
		MOV	DX,OFFSET D_BAT 	;'C:\213L.BAT'
		MOV	AX,3D02H		;´ò¿ªÎÄ¼þ
		INT	21H
		JNB	L_BAT1
		MOV	SI,OFFSET NO213L
L_BAT2B:
		MOV	DX,D_15
		ADD	DX,102H
		MOV	BL,4EH
		CALL	S_XSZFC 		;ÏÔÊ¾×Ö·û´®
		MOV	AX,0E07H		;ÏìÁå
		INT	10H
		XOR	AH,AH			;°´¼ü
		INT	16H
		JMP	L_S0
L_BAT1:
		MOV	BX,AX
		MOV	H_BAT,AX
		MOV	DX,OFFSET B_BUF
		MOV	SI,DX
		MOV	CX,-1
		MOV	AH,3FH			;¶ÁÎÄ¼þ
		INT	21H
		ADD	SI,AX
		CMP	BYTE PTR [SI-1],1AH	;ÎÄ±¾ÎÄ¼þ½áÊø±êÖ¾
		JZ	L_BAT2
		MOV	BYTE PTR [SI],1AH	;ÖÃ±êÖ¾
		INC	SI
L_BAT2:
		MOV	D_END,SI		;ÎÄ¼þÎ²
L_BAT2A:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_INT10	;'INT10'
		CALL	S_SCAN			;²éÕÒ
		MOV	AL,' '
		JB	L_BAT4
		MOV	AL,[BX+5]		;'INT10'ºó×Ö·û
L_BAT4:
		MOV	D_XG1+21,AL

		MOV	D_XG2+21,' '
		MOV	WORD PTR D_XG3+20,'  '
		MOV	D_XG4+21,' '
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PR		;'PR '
		CALL	S_SCAN			;²éÕÒ
		JB	L_BAT7
		MOV	D_XG2+21,'H'
		MOV	AX,[BX+3]		;´òÓ¡»úºÅ
		CMP	AH,0DH
		JNZ	L_BAT6
		MOV	AH,' '
L_BAT6:
		MOV	WORD PTR D_XG3+20,AX
		JMP	SHORT L_BAT8
L_BAT7:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRNT	;'PRNT'
		CALL	S_SCAN			;²éÕÒ
		MOV	AL,' '
		JB	L_BAT8
		MOV	D_XG2+21,'N'
		MOV	AL,[BX+5]		;´òÓ¡»úºÅ
		MOV	D_XG4+21,AL
L_BAT8:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_READ24	;'READ24'
		CALL	S_SCAN			;²éÕÒ
		JB	L_BAT9
		MOV	AL,[BX+7]		;READ24ºóµÄ×Ö·û
		MOV	D_XG5+21,AL
L_BAT9:
		MOV	DX,D_15
		MOV	BX,C_15
		MOV	CX,A_15
		CALL	S_XSCK			;ÏÔÊ¾¿Õ´°¿Ú
		MOV	SI,OFFSET D_XGBAT
		ADD	DX,107H
		MOV	BL,4EH
		CALL	S_XSZFC 		;ÏÔÊ¾±êÌâ
L_BAT10:
		MOV	SI,OFFSET D_XG1
		MOV	DX,D_15
		ADD	DX,302H
		MOV	BX,C_15
		CALL	S_CKXS			;ÏÔÊ¾´°¿ÚÄÚÈÝ

		MOV	SI,OFFSET D_XG1 	;²Ëµ¥Ê×
		MOV	BP,OFFSET D_XGZ1	;°ïÖúÖ¸Õë
		MOV	BH,23			;Ïî³¤
		MOV	CH,5			;ÏîÊý-1
		MOV	CL,D_SELE15		;³õºÅ
		CALL	S_CDKZ			;²Ëµ¥¿ØÖÆ

		CMP	AL,1BH			;<ESC>?
		JNZ	L_BAT12
		MOV	BX,H_BAT
		MOV	AH,3EH
		INT	21H
L_BAT11:
		MOV	DX,D_15
		MOV	BX,11H
		MOV	CX,A_15
		CALL	S_XSCK			;Çå´°¿Ú
		JMP	L_S00
L_BAT12:
		MOV	D_SELE15,AL		;Ñ¡ÔñºÅ

		CMP	AL,0			;<INT10?>
		JNZ	L_BAT30
		MOV	SI,OFFSET K_INT10
		CALL	S_INKEY 		;¼üÈë×Ö·û
		CMP	AL,'0'
		JB	L_BAT22
		JZ	L_BAT21
		AND	AL,5FH
L_BAT21:
		MOV	DL,AL

		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_INT10	;'INT10'
		CALL	S_SCAN			;²éÕÒ
		JB	L_BAT24
		CMP	DL,'0'                  ;ÎÞ?
		JZ	L_BAT23
		CMP	DL,[BX+5]		;ÅÐ?
		JZ	L_BAT22
		MOV	[BX+5],DL		;Ð´Èë
L_BAT22:
		JMP	L_BAT2A
L_BAT23:
		MOV	DI,BX
		MOV	CX,8
		CMP	BYTE PTR [DI-1],' '     ;Ç°ÓÐ¿Õ¸ñ(LH)
		JNZ	L_BAT23A
		SUB	DI,3
		ADD	CX,3
L_BAT23A:
		CALL	S_DELBAT		;Çå¸ÃÐÐ
		JMP	L_BAT2A
L_BAT24:
		CMP	DL,'0'                  ;ÎÞ?
		JZ	L_BAT22
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_CCDISP	;'CCDISP'
		CALL	S_SCAN			;²éÕÒ
		JNB	L_BAT24A
		MOV	SI,OFFSET NOCCDISP
		JMP	L_BAT2B
L_BAT24A:
		MOV	SI,BX
L_BAT25:
		LODSB
		CMP	AL,0DH			;ÅÐÐÐÎ²?
		JZ	L_BAT26
		CMP	AL,0AH
		JNZ	L_BAT25
L_BAT26:
		LODSB				;ÏÂÐÐÊ×

		MOV	DI,OFFSET F_INT10+1
		MOV	[DI+5],DL
		MOV	CX,8
		CALL	S_INBUF 		;Ð´ÈëÒ»ÐÐ
		JMP	L_BAT2A
L_BAT30:
		CMP	AL,1			;<PRT>
		JZ	L_BAT31
		JMP	L_BAT60
L_BAT31:
		MOV	AL,'N'
		CMP	D_XG3+21,AL
		JNZ	L_BAT32
		MOV	AL,'H'
L_BAT32:
		MOV	D_XG3+21,AL
		MOV	DL,AL

		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRTH	;'PRTH'---------------------
		CALL	S_SCAN			;²éÕÒ
		JB	L_BAT50
		CMP	DL,'N'                  ;¸ÄPRNT?
		JNZ	L_BAT49
		MOV	WORD PTR [BX+2],'TN'    ;¸Ä'NT'
		MOV	SI,BX
		ADD	SI,4
		MOV	DI,OFFSET D_PRNTB+14
		MOV	CX,2
		CALL	S_INBUF 		;Ð´Èë'  '
		CALL	S_PRNT			;PRNTÑ¡´òÓ¡»ú
L_BAT47:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PR		;3,'PR '
		CALL	S_SCAN			;²éÕÒ
		JB	L_BAT49
		MOV	CX,7
		CMP	BYTE PTR [BX+4],0DH
		JNZ	L_BAT48
		MOV	CL,6
L_BAT48:
		MOV	DI,BX
		CALL	S_DELBAT		;É¾PRÐÐ
L_BAT49:
		JMP	L_BAT2A
L_BAT50:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRNT	;'PRNT'----------------------
		CALL	S_SCAN			;²éÕÒ
		JB	L_BAT64
		CMP	DL,'H'                  ;¸ÄPRTH?
		JNZ	L_BAT54
		MOV	DI,BX
		ADD	DI,4
		MOV	CX,2
		CALL	S_DELBAT		;É¾´òÓ¡»úºÅ
		MOV	WORD PTR [BX+2],'HT'    ;¸Ä'TH'
		CALL	S_INPR			;²åÈëPRÐÐ
L_BAT54:
		JMP	L_BAT2A
L_BAT60:
		CMP	AL,2			;<PRÑ¡´òÓ¡»ú>
		JNZ	L_BAT66
		CMP	D_XG3+21,'H'
		JNZ	L_BAT64
		CALL	S_PR
		JMP	L_BAT2A
L_BAT64:
		MOV	AX,0E07H
		INT	10H
		JMP	L_BAT2A
L_BAT66:
		CMP	AL,3			;<PRNTÑ¡´òÓ¡»ú>
		JNZ	L_BAT80
		CMP	D_XG3+21,'N'
		JNZ	L_BAT64
		CALL	S_PRNT
L_BAT69:
		JMP	L_BAT2A
L_BAT70:
		CMP	AL,5			;<´æÅÌ>
		JNZ	L_BAT69
		MOV	BX,H_BAT		;ÎÄ¼þºÅ
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4200H		;ÒÆÎÄ¼þÍ·
		INT	21H
		MOV	DX,OFFSET B_BUF
		MOV	CX,D_END
		SUB	CX,DX
		MOV	AH,40H			;Ð´Èë
		INT	21H
		MOV	AH,3EH			;¹Ø±Õ
		INT	21H
		JMP	L_BAT11 		;¹Ø´°¿Ú·µÖ÷²Ëµ¥
L_BAT80:
		CMP	AL,4			;<READ24Ñ¡W>
		JNZ	L_BAT70
		MOV	SI,OFFSET K_READ24
		CALL	S_INKEY 		;¼üÈë×Ö·û
		CMP	AL,'w'
		JNZ	L_BAT81
		AND	AL,5FH
L_BAT81:
		CMP	AL,'W'
		JZ	L_BAT82
		CMP	AL,'1'
		JB	L_BAT86
		CMP	AL,'9'
		JA	L_BAT86
L_BAT82:
		MOV	DL,AL

		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_READ24	;'READ24'
		CALL	S_SCAN			;²éÕÒ
		JB	L_BAT83
		CALL	S_24W
L_BAT83:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_READ32	;'READ32'
		CALL	S_SCAN			;²éÕÒ
		JB	L_BAT84
		CALL	S_24W
L_BAT84:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_READ40	;'READ40'
		CALL	S_SCAN			;²éÕÒ
		JB	L_BAT85
		CALL	S_24W
L_BAT85:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_READSL	;'READSL'
		CALL	S_SCAN			;²éÕÒ
		JB	L_BAT86
		CALL	S_24W
L_BAT86:
		JMP	L_BAT2A

;×Ó³ÌÐò:READ24W´¦Àí
S_24W		PROC	NEAR
		CMP	BYTE PTR [BX+6],0DH	;ÃüÁîÃûºóÎÞ²ÎÊý?
		JZ	L_24W2
		CMP	DL,[BX+7]
		JZ	L_24W1
		MOV	[BX+7],DL
L_24W1:
		RET
L_24W2:
		LEA	SI,[BX+6]
		MOV	DI,OFFSET D_XG5+20
		MOV	[DI+1],DL
		MOV	CX,2
		JMP	S_INBUF
S_24W		ENDP

;×Ó³ÌÐò:Ñ¡ÔñPR
S_PR		PROC	NEAR
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PR		;'PR '
		CALL	S_SCAN			;²éÕÒ
		JNB	L_PR1
		RET
L_PR1:
		MOV	AX,[BX+3]		;´òÓ¡»úºÅ
		MOV	SI,OFFSET D_PRTHB	;	±í
		XOR	CX,CX
L_PR2:
		CMP	AH,0DH
		JZ	L_PR2A
		CMP	AX,[SI]
		JZ	L_PR3
		JMP	SHORT L_PR2B
L_PR2A:
		CMP	AL,[SI] 		;ÅÐ?
		JZ	L_PR3
L_PR2B:
		ADD	SI,22			;ÏÂÒ»ÐÐ
		INC	CX
		JMP	SHORT L_PR2
L_PR3:
		MOV	D_SELEPR,CL		;Ô­ºÅ
		JMP	SHORT L_INPR1

;×Ó³ÌÐò:²åÈëPRÐÐ
S_INPR:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRTH	;'PRTH'
		CALL	S_SCAN			;²éÕÒ
		JNB	L_INPR0
		MOV	SI,OFFSET NOPRTH
		JMP	L_BAT2B
L_INPR0:
		MOV	SI,BX
		MOV	DI,OFFSET F_PR+1
		MOV	CX,7
		CALL	S_INBUF 		;²åÈëÒ»ÐÐ:PR 00
L_INPR1:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PR		;3,'PR '
		CALL	S_SCAN			;²éÕÒ
		CMP	BYTE PTR [BX+4],0DH	;ÅÐPRºóÒ»Î»Êý?
		JNZ	L_INPR2
		MOV	DI,OFFSET D_PRTHB+2	;¿Õ¸ñ
		MOV	CX,1
		LEA	SI,[BX+3]
		CALL	S_INBUF 		;Ð´Èë×Ö·û´®
L_INPR2:
		PUSH	BX
		CALL	S_SELEPR		;Ñ¡Ôñ´òÓ¡»úºÅAL
		POP	BX
		JB	L_INPR3
		MOV	AX,WORD PTR D_PRTHB[SI]
		MOV	[BX+3],AX
L_INPR3:
		MOV	DX,D_PR
		MOV	BX,0FF11H
		MOV	CX,A_PR
		CALL	S_XSCK			;ÇåPR´°¿Ú
		RET
S_SELEPR:
		MOV	DX,D_PR
		MOV	BX,C_PR
		MOV	CX,A_PR
		CALL	S_XSCK			;ÏÔÊ¾PR´°¿Ú
		MOV	SI,OFFSET D_PRTH
		ADD	DX,3
		MOV	BH,4EH
		CALL	S_XSZFC 		;ÏÔÊ¾±êÌâ
		MOV	SI,OFFSET D_PRTHB
		MOV	DX,D_PR
		ADD	DX,101H
		MOV	BX,C_PR
		CALL	S_CKXS			;ÏÔÊ¾´°¿ÚÄÚÈÝ

		MOV	SI,OFFSET D_PRTHB
		MOV	BP,OFFSET D_PRTHZ1	;°ïÖúÖ¸Õë
		MOV	BH,22			;Ïî³¤
		MOV	CH,9			;ÏîÊý-1
		MOV	CL,D_SELEPR		;³õºÅ
		CALL	S_CDKZ			;²Ëµ¥¿ØÖÆ
		CMP	AL,1BH			;ESC
		JZ	L_SELEPR1
		MUL	BH
		MOV	SI,AX
		CLC
		RET
L_SELEPR1:
		STC
		RET
S_PR		ENDP

;×Ó³ÌÐò:PRNTÑ¡´òÓ¡»ú
S_PRNT		PROC	NEAR
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRNT	;'PRNT '
		CALL	S_SCAN			;²éÕÒ
		JNB	L_PRNT1
		RET
L_PRNT1:
		XOR	CX,CX
		MOV	AL,[BX+5]		;´òÓ¡»úºÅ
		CMP	AL,' '
		JZ	L_PRNT4
		MOV	SI,OFFSET D_PRNTB	;	±í
L_PRNT2:
		CMP	AL,[SI]
		JZ	L_PRNT5
		ADD	SI,18			;ÏÂÒ»ÐÐ
		INC	CX
		JMP	SHORT L_PRNT2
L_PRNT4:
		MOV	CL,5
L_PRNT5:
		MOV	D_SELEPR,CL		;Ô­ºÅ

		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRNT	;5,'PRNT '
		CALL	S_SCAN			;²éÕÒ
		CMP	BYTE PTR [BX+6],0DH	;ÅÐPRNTºóÒ»Î»Êý?
		JZ	L_PRNT6
		MOV	DI,BX
		ADD	DI,6
		MOV	CX,1
		CALL	S_DELBAT		;
L_PRNT6:
		PUSH	BX
		CALL	S_SELEPRNT		;Ñ¡Ôñ´òÓ¡»úºÅAL
		POP	BX
		JB	L_PRNT7
		MOV	AL,D_PRNTB[SI]
		MOV	[BX+5],AL
L_PRNT7:
		MOV	DX,D_PRNT
		MOV	BX,0FF11H
		MOV	CX,A_PRNT
		CALL	S_XSCK			;ÇåPR´°¿Ú
		RET
S_SELEPRNT:
		MOV	DX,D_PRNT
		MOV	BX,C_PRNT
		MOV	CX,A_PRNT
		CALL	S_XSCK			;ÏÔÊ¾PR´°¿Ú
		MOV	SI,OFFSET D_PRNT1
		ADD	DX,2
		MOV	BH,4EH
		CALL	S_XSZFC 		;ÏÔÊ¾±êÌâ
		MOV	SI,OFFSET D_PRNTB
		MOV	DX,D_PRNT
		ADD	DX,101H
		MOV	BX,C_PRNT
		CALL	S_CKXS			;ÏÔÊ¾´°¿ÚÄÚÈÝ

		MOV	SI,OFFSET D_PRNTB
		MOV	BP,OFFSET D_PRNTZ1	;°ïÖúÖ¸Õë
		MOV	BH,18			;Ïî³¤
		MOV	CH,9			;ÏîÊý-1
		MOV	CL,D_SELEPR		;³õºÅ
		CALL	S_CDKZ			;²Ëµ¥¿ØÖÆ
		CMP	AL,1BH			;ESC
		JZ	L_SELEPRNT1
		MUL	BH
		MOV	SI,AX
		CLC
		RET
L_SELEPRNT1:
		STC
		RET
S_PRNT		ENDP

;×Ó³ÌÐò:²éÕÒ×Ö·û´® DS:SI-¿ªÊ¼µØÖ·,ES:DI-×Ö·û´®,CX-³¤¶È
S_SCAN		PROC	NEAR
		PUSH	SI
		MOV	CL,ES:[DI]
		XOR	CH,CH
		INC	DI
L_SC1:
		PUSH	SI
		PUSH	DI
		PUSH	CX
		REP	CMPSB			;²éÕÒ
		POP	CX
		POP	DI
		POP	SI
		JZ	L_SC2
		INC	SI
		CMP	BYTE PTR [SI],1AH	;µ½ÎÄ¼þÎ²
		JNZ	L_SC1
		POP	SI
		STC
		RET
L_SC2:
		MOV	BX,SI
		POP	SI
		CLC
		RET
S_SCAN		ENDP

;×Ó³ÌÐò:Ð´Èë×Ö·û´®DI,CX-³¤¶È,SI-Ð´Èëµã
S_INBUF 	PROC	NEAR
		PUSH	BX
		PUSH	DI
		MOV	BX,CX
		MOV	DI,D_END
L_IB1:
		DEC	DI
		MOV	AL,[DI]
		MOV	[BX+DI],AL
		CMP	SI,DI
		JNZ	L_IB1
		POP	SI
		REP	MOVSB
		ADD	D_END,BX
		POP	BX
		RET
S_INBUF 	ENDP

;×Ó³ÌÐò:É¾³ý×Ö·û´®DI,CX-³¤¶È
S_DELBAT	PROC	NEAR
		PUSH	BX
		PUSH	DI
		MOV	BX,CX
L_DB1:
		MOV	AL,[BX+DI]
		MOV	[DI],AL
		INC	DI
		CMP	AL,1AH
		JNZ	L_DB1
		SUB	D_END,BX
		POP	DI
		POP	BX
		RET
S_DELBAT	ENDP

;Í¨ÓÃ×Ó³ÌÐò******************************************************************
D_YH		DB	0			;Ä¬ÈÏºÅ
D_YS		DB	0			;Ô­²Ëµ¥É«
D_CD		DW	0			;²Ëµ¥×óÉÏ½ÇÎ»ÖÃ
;×Ó³ÌÐò:²Ëµ¥¿ØÖÆ SI=²Ëµ¥Ê×,BH=Ïî³¤,BL=²Ëµ¥É«,CH=ÏîÊý-1,CL=Ä¬ÈÏºÅ,BP=°ïÖú²Ëµ¥Ö¸Õë
;		 ·µ»Ø:AL=Ñ¡ÖÐºÅ(=1BH:ÍË³ö)
S_CDKZ		PROC	NEAR
		MOV	D_YH,CL
		MOV	D_YS,BL
		MOV	D_CD,DX
		CALL	S_XSCD1 		;ÏÔÊ¾
L_CDKZ1:
		XOR	AH,AH			;¼üÈëÑ¡Ôñ
		INT	16H
		CMP	AL,1BH			;<ESC>
		JZ	L_CDKZ2
		CMP	AL,0DH			;»Ø³µÑ¡ÖÐ?
		JNZ	L_CDKZ3
		MOV	AL,CL
L_CDKZ2:
		RET
L_CDKZ3:
		CMP	AH,48H			;¡ü
		JNZ	L_CDKZ6
		CMP	CL,0
		JNZ	L_CDKZ4
		MOV	CL,CH
		JMP	SHORT L_CDKZ5
L_CDKZ4:
		DEC	CL
L_CDKZ5:
		CALL	S_XSCD
		JMP	SHORT L_CDKZ1
L_CDKZ6:
		CMP	AH,50H			;¡ý
		JNZ	L_CDKZ1
		CMP	CL,CH
		JNZ	L_CDKZ7
		XOR	CL,CL
		JMP	SHORT L_CDKZ5
L_CDKZ7:
		INC	CL
		JMP	SHORT L_CDKZ5
S_CDKZ		ENDP

S_XSCD		PROC	NEAR
		MOV	DH,D_YH 		;Ô­ºÅ
		MOV	BL,D_YS 		;²Ëµ¥É«
		CALL	S_XSCD2 		;»Ö¸´
S_XSCD1:
		PUSH	SI
		PUSH	BX
		PUSH	CX
		MOV	DX,D_HELP
		MOV	BX,C_HELP
		MOV	CX,A_HELP
		CALL	S_XSCK			;ÏÔÊ¾°ïÖú´°¿Ú
		POP	CX
		PUSH	CX
		XOR	CH,CH
		SHL	CX,1			;*2
		MOV	SI,BP
		ADD	SI,CX			;Ö¸Õë
		INC	CX
		MOV	SI,DS:[SI]		;°ïÖú´®Ê×
		ADD	DX,102H 		;ÏÔÊ¾Î»ÖÃ
		CALL	S_CKXS			;ÏÔÊ¾°ïÖú
		POP	CX
		POP	BX
		POP	SI

		MOV	DH,CL
		MOV	BL,70H
S_XSCD2:
		PUSH	BP
		PUSH	CX
		MOV	AL,BH			;Ïî³¤
		MUL	DH			;*
		ADD	AX,SI			;+´®Ê×
		MOV	BP,AX			;ÏÔÊ¾Ê×
		MOV	DI,AX
		XOR	DL,DL			;×î×óÁÐ
		ADD	DX,D_CD
		MOV	CL,BH			;Ïî³¤
		XOR	CH,CH
		DEC	CX			;-1(È¥0)
		PUSH	BX
		CALL	S_XSZFI 		;ÏÔÊ¾
		POP	BX
		POP	CX
		POP	BP
		MOV	D_YH,CL 		;µ±Ç°ºÅ
		RET
S_XSCD		ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:ÇåÆÁ
S_CLS		PROC	NEAR
		MOV	AL,D_MODE		;ÏÔÊ¾·½Ê½
		CMP	D_ZJXP,1		;ÅÐÖ±½ÓÐ´ÆÁ
		JNZ	L_CLS0
		MOV	AL,3
L_CLS0:
		CBW
		INT	10H			;ÖØÉèÏÔÊ¾·½Ê½

		CALL	S_GGB			;¹Ø¹â±ê

		MOV	BX,0FF11H		;BH=-1:ÎÞÒõÓ°,BL=11H	2.19
		MOV	CX,1950H		;CH=25,CL=80
		XOR	DX,DX			;ÆÁÄ»×óÉÏ½Ç
		CALL	S_XSCK			;ÏÔÊ¾ÂúÆÁ
		RET
S_CLS		ENDP
;----------------------------------------------------------------------------
D_K		DW	0			;¿í
D_G		DW	0			;¸ß
D_YY		DB	0
;×Ó³ÌÐò:ÏÔÊ¾¿Õ´°¿Ú DX=´°¿Ú×óÉÏ½Ç,CH=¸ß,CL=¿í,BL=ÑÕÉ«,BH=-1ÎÞÒõÓ°
S_XSCK		PROC	NEAR
		MOV	D_YY,BH
		PUSH	DX
		PUSH	CX
		PUSH	SI
		PUSH	BP
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
		MOV	DI,D_G
L_CK1:
		INC	DH
		CALL	S_XSYH
		DEC	DI
		JNZ	L_CK1
		INC	DH
		CMP	DH,18H
		JA	L_CK3
		MOV	SI,OFFSET D_B3		;ÏÂºáÏß
		CALL	S_XSYH

		CMP	D_YY,-1
		JZ	L_CK3
		ADD	DX,101H
		CMP	D_MODE,9		;ÅÐµ¥ÏÔ?
		JBE	L_CK3
		CMP	DH,18H			;µ½µ×ÐÐ?
		JA	L_CK3
		PUSH	BX
		MOV	BH,' '                  ;ÏÂÒõÓ°
		CMP	BL,11H
		JZ	L_CK1A
		XOR	BL,BL
L_CK1A:
		MOV	DI,D_K
		ADD	DI,2
L_CK2:
		CALL	S_XSZF
		DEC	DI
		JNZ	L_CK2
		POP	BX
L_CK3:
		POP	BP
		POP	SI
		POP	CX
		POP	DX
		RET
;×Ó³ÌÐò:ÏÔÊ¾Ò»ÐÐ:
S_XSYH:
		PUSH	DX
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

		CMP	D_YY,-1
		JZ	L_YH2
		CMP	D_MODE,9		;ÅÐµ¥ÏÔ?
		JBE	L_YH2
		CMP	SI,OFFSET D_B1		;ÅÐÉÏºáÏß?
		JZ	L_YH2
		CMP	DL,80			;ÅÐµ½ÓÒ±ß?
		JZ	L_YH2
		PUSH	BX
		MOV	BH,' '                  ;ÓÒ±ßÒõÓ°
		CMP	BL,11H
		JZ	L_YH1A
		XOR	BL,BL
L_YH1A:
		CALL	S_XSZF
		POP	BX
L_YH2:
		POP	DX
		RET
S_XSCK		ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:ÏÔÊ¾´°¿ÚÄÚÈÝSI(Ã¿ÐÐÎ²0,×îºóÔÙ¼Ó0),DX=Ê×Î»ÖÃ,BL=ÊôÐÔ
S_CKXS		PROC	NEAR
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
S_CKXS		ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:ÏÔÊ¾×Ö·ûBH,Î»ÖÃDX(ÏÔÊ¾ºó+1) CX=0°´×Ö·ûÏÔÊ¾,>0¿ÉÏÔÊ¾ºº×Ö
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
;----------------------------------------------------------------------------
;×Ó³ÌÐò:ÏÔÊ¾×Ö·û´®SI,½áÎ²0,BL=ÊôÐÔ
S_XSZFC 	PROC	NEAR
		LODSB
		OR	AL,AL			;ÅÐ½áÊø?
		JZ	L_X1
		MOV	BH,AL
		CALL	S_XSZF			;ÏÔÊ¾×Ö·û
		JMP	SHORT S_XSZFC
L_X1:
		RET
S_XSZFC 	ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:¹Ø±Õ¹â±ê
S_GGB		PROC	NEAR
		PUSH	AX
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		POP	AX
		RET
S_GGB		ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:¿ª¹â±ê
S_KGB		PROC	NEAR
		MOV	CX,0E0FH
		MOV	AH,1			;¿ª¹â±ê
		INT	10H
		RET
S_KGB		ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:ÏÔÊ¾¼üÈë´°¿Ú DS:SI-ÌáÊ¾ÐÅÏ¢
S_XSIN		PROC	NEAR
		MOV	DX,D_IN
		MOV	BX,C_IN
		MOV	CX,A_IN
		CALL	S_XSCK			;ÏÔÊ¾¼üÈë¿Õ´°¿Ú
		ADD	DX,102H
		RET
S_XSIN		ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:¼üÈë×Ö·û DS:SI-ÌáÊ¾ÐÅÏ¢
S_INKEY 	PROC	NEAR
		CALL	S_XSIN			;ÏÔÊ¾¼üÈë´°¿Ú
		CALL	S_XSZFC 		;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢
		XOR	AH,AH			;¼üÈë
		INT	16H
		PUSH	AX
		MOV	DX,D_IN
		MOV	BX,0FF11H
		MOV	CX,A_IN
		CALL	S_XSCK			;Çå´°¿Ú
		POP	AX
		RET
S_INKEY 	ENDP
;----------------------------------------------------------------------------
D_NUM		DW	0
;×Ó³ÌÐò:¼üÈë16½øÖÆÊý CX:×Ö½ÚÊý,·µ»ØD_NUM
S_IN16		PROC	NEAR
		MOV	BP,16
		JMP	SHORT L_IN0
;×Ó³ÌÐò:¼üÈë10½øÖÆÊý
S_IN10:
		MOV	BP,10
L_IN0:
		PUSH	CX
		CALL	S_XSIN
		CALL	S_XSZFC
		POP	CX
		MOV	SI,OFFSET D_INPBUF	;¼üÈë»º³åÇø
		MOV	DI,SI
		ADD	DI,CX
		MOV	D_NUM,0
L_IN1:
		XOR	BH,BH
		MOV	AH,2
		INT	10H
		XOR	AH,AH			;¼üÈë
		INT	16H
		CMP	AL,80H
		JA	L_IN1
		CMP	AL,0DH			;»Ø³µ?
		JB	L_IN1
		JZ	L_IN6
		CMP	AL,1BH			;<ESC>
		JZ	L_IN9A
		CMP	AL,8			;ÍË¸ñ?
		JNZ	L_IN5
		CMP	SI,OFFSET D_INPBUF	;Ö¸ÕëÔÚÇøÊ×?
		JA	L_IN3
L_IN2:
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_IN1
L_IN3:
		DEC	SI			;Î»ÖÃ-1
L_IN4:
		CALL	S_GGB
		DEC	DX
		MOV	BH,' '
		CALL	S_XSZF			;ÏÔÊ¾¿Õ¸ñ
		DEC	DX
		CALL	S_KGB
		JMP	SHORT L_IN1
L_IN9A:
		CALL	L_IN9
		STC
		RET
L_IN5:
		CMP	AL,'0'                  ;ÅÐÊý×Ö?
		JB	L_IN1
		CMP	AL,'9'
		JBE	L_IN5A
		CMP	BP,10
		JZ	L_IN1
		AND	AL,5FH
		CMP	AL,'A'
		JB	L_IN1
		CMP	AL,'F'
		JA	L_IN1
L_IN5A:
		CMP	SI,DI			;¼üÈëÂú?
		JZ	L_IN2
		MOV	[SI],AL 		;Ð´Èë
		INC	SI
		MOV	BH,AL
		CALL	S_GGB
		CALL	S_XSZF
		CALL	S_KGB
		JMP	SHORT L_IN1
L_IN6:
		CMP	SI,OFFSET D_INPBUF
		JZ	L_IN9A
		MOV	BYTE PTR [SI],0
		MOV	SI,OFFSET D_INPBUF	;¼üÈëÇøÊ×
L_IN7:
		LODSB				;È¡
		OR	AL,AL
		JZ	L_IN9
		SUB	AL,'0'
		CMP	AL,9
		JBE	L_IN8
		SUB	AL,7
L_IN8:
		CBW
		PUSH	AX
		MOV	AX,BP
		MUL	D_NUM
		MOV	D_NUM,AX
		POP	AX
		ADD	D_NUM,AX
		JMP	SHORT L_IN7
L_IN9:
		PUSH	AX
		CALL	S_GGB
		MOV	DX,D_IN
		MOV	BX,0FF11H
		MOV	CX,A_IN
		CALL	S_XSCK
		POP	AX
		CLC
		RET
S_INCOLOR:	;¼üÈëÊ®Áù½øÖÆÑÕÉ«Öµ
		MOV	SI,OFFSET D_INPUT
		MOV	CX,2			;ÏÞ2Î»
		CALL	S_IN16			;¼üÈëÊ®Áù½øÖÆÊý
		JB	L_INCO
		MOV	AX,D_NUM
		CLC
L_INCO:
		RET
S_IN16		ENDP

;×Ó³ÌÐò:È¡INIÒ»²ÎÊý->AL
S_GETB		PROC	NEAR
		PUSH	CX
		LODSB				;È¡Ò»×Ö½Ú
		CALL	S_TO10			;×ªÊ®½øÖÆ
		CMP	BYTE PTR [SI],' '       ;ÅÐÏÂÒ»×Ö½ÚÎª¿Õ¸ñ?
		JZ	L_GETB1
		MOV	CL,4
		SHL	AL,CL			;*16
		MOV	CL,AL
		LODSB				;ÔÙÈ¡Ò»×Ö½Ú
		CALL	S_TO10			;×ªÊ®½øÖÆ
		ADD	AL,CL			;+
L_GETB1:
		PUSH	AX
L_GETB2:
		LODSB
		CMP	AL,0AH
		JNZ	L_GETB2
		POP	AX
		POP	CX
		RET
S_TO10: ;×ªÊ®½øÖÆ
		CMP	AL,'9'                  ;ÅÐÊý×Ö?
		JBE	L_T1
		AND	AL,5FH			;Ð¡Ð´±ä´óÐ´
L_T1:
		SUB	AL,'0'
		CMP	AL,9
		JBE	L_T2
		SUB	AL,7
L_T2:
		RET
S_GETB		ENDP

;×Ó³ÌÐò:Ð´Èë²ÎÊý AL
S_SETB		PROC	NEAR
		PUSH	CX
		CALL	S_TO16
		MOV	[DI],AH
		MOV	[DI+1],AL
L_SETB1:
		INC	DI
		CMP	BYTE PTR [DI],0AH
		JNZ	L_SETB1
		INC	DI
		POP	CX
		RET
S_TO16:
		MOV	CH,AL
		MOV	CL,4
		SHR	AL,CL
		CALL	S_GET16
		MOV	AH,AL
		MOV	AL,CH
		AND	AL,0FH
S_GET16:
		MOV	BX,OFFSET D_16
		XLAT
		RET
S_SETB		ENDP

;×Ó³ÌÐò:AL->16½øÖÆAX---------------------------------------------------------
S_16		PROC	NEAR
		MOV	BX,OFFSET D_16
		PUSH	AX
		AND	AL,0FH
		XLAT
		MOV	DL,AL
		POP	AX
		SHR	AL,1
		SHR	AL,1
		SHR	AL,1
		SHR	AL,1
		XLAT
		MOV	AH,DL
		RET
S_16		ENDP

;×Ó³ÌÐò:´«ËÍ
S_MOVE		PROC	NEAR
		LODSB
		STOSB
		OR	AL,AL
		JNZ	S_MOVE
		RET
S_MOVE		ENDP

D_FILE		EQU	$
B_BUF		EQU	$+40H

SEG_A		ENDS
		END    START

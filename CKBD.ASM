;	CKB?.ASM 2.13L ¼üÅÌ¹ÜÀíÄ£¿é
;	1998.8.16
DATE	EQU	"1999.11.17"

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

D_PATH	EQU	82H    ;32 DUP (0)		;2.13°²×°ÅÌ¼°Â·¾¶

; 100H BYTE ºº×ÖÏÔÊ¾·½Ê½
; 101H BYTE Êµ¼ÊÏÔÊ¾·½Ê½
; 102H BYTE =1Ö±½ÓÐ´ÆÁ

		ORG	100H
START:		JMP	BEGIN
		DW	0CDEFH			;CKBD±êÖ¾	[103H]

K_DISP		DB	2,1,5,39H		;ÏÔÊ¾²ÎÊý	[105H]
		DB	0
D_TUX1		DB	1EH			;ÌáÊ¾ÐÐ×Ö·ûÉ«1	[10AH]
D_TUX2		DB	1AH			;ÌáÊ¾ÐÐ×Ö·ûÉ«2
D_QTS1		DB	4EH			;ÌáÊ¾ÐÐÐÅÏ¢ÑÕÉ«1
D_QTS2		DB	4AH			;ÌáÊ¾ÐÐÐÅÏ¢ÑÕÉ«2
		DB	0
K_SHIFT 	DB	2			;¹¦ÄÜ¼ü¿ª¹ØSHIFT
K_CF7		DB	64H			;ÖÐ/Î÷ÎÄÏÔÊ¾¿ª¹Ø [110H]
K_AF1		DB	68H			;ÇøÎ»ÂëÊäÈë
K_AF2		DB	69H			;Ê×Î²ÂëÊäÈë
K_AF3		DB	6AH			;Æ´ÒôÂëÊäÈë
K_AF4		DB	6BH			;Ë«Æ´ÂëÊäÈë
K_CF9		DB	66H			;½¨Á¢/È¡Ïû´¿ÖÐÎÄ
K_AF6		DB	6DH			;ASCIIÂëÊäÈë
K_AF5		DB	6CH			;Îå±ÊÂëÊäÈë
K_AF10		DB	71H			;µç±¨ÂëÊäÈë
K_F12		DB	86H			;Ô¤Ñ¡×ÖÊäÈë
K_F11		DB	85H			;Áª»ú°ïÖú
K_CF5		DB	62H			;ÏµÍ³¿ØÖÆ
K_AF9		DB	70H			;¶¨ÒåË«Æ´´Ê×é
K_CF10		DB	67H			;ÉèÖÃ´òÓ¡²ÎÊý
		DB	0,0
K_FCC		DB	'Y'                     ;·Â³¤³Ç¼üÅÌ     [120H]
K_SPKZ		DB	'1'                     ;Ë«Æ´´Ê×éÀ©Õ¹Çø´óÐ¡
K_PY		DB	'Y'                     ;°²×°Æ´ÒôÂë±í
K_SW		DB	'N'                     ;°²×°Ê×Î²Âë±í
K_DB		DB	'N'                     ;°²×°µç±¨Âë±í

D_INT16 	DD	0			;INT16	  [0119H]
D_INT9		DD	0			;INT9
D_INKEY 	DB	0			;Ö´ÐÐINT9±êÖ¾
D_KBDBUF	DW	0			;¼üÅÌ»º³åÇø¿É´æ×Ö·ûÊý
K_DEL		DB	0			;¹¦ÄÜ¼ü¿ª¹Ø(=0FFH¹Ø)

D_PY		DW	0, 0			;Æ´ÒôÂë±íÊ×¡¢Î²Ö·
D_SW		DW	0, 0			;Ê×Î²Âë±íÊ×¡¢Î²Ö·
D_2BD6		DW	0			;Âë±íÊ×
D_2BD8		DW	0			;Âë±íÎ²

D_2BAD		DW	0			;²éÂë±íÖ¸Õë
D_2BAF		DW	0			;ÕýÏò²éÂë±íÖ¸Õë
D_9646		DW	0			;·´Ïò²éÂë±íÖ¸Õë

D_2BB0		DB	0			;¼üÈëÂë¼ÆÊý
D_2BB1		DB	10 DUP(0)		;¼üÈëÂëÇø(10×Ö½Ú)
D_2CC1		DB	10 DUP(0)		;¼üÈëÂëÇø(10×Ö½Ú)
D_2CC0		DB	0			;Æ´Òô¼òÂë±êÖ¾0FFH
D_2BCF		DB	11			;Ä©Ò³ÖØÂëÊý
D_2BC0		DW	0			;Ð´ÖØÂëÇøÖ¸Õë
	;--------------------------------------------------------------------+
D_2BBA		DW	0			;ÖØÂëÇø(¿É´æ11ºº×Ö)	     |
D_2BBC		DW	9 DUP (0)		;			     |
D_2BCE		DW	0			;ÖØÂëÇøÄ©×Ö		     |
	;--------------------------------------------------------------------+
D_2BD0		DB	11			;ÖØÂëÇøÈÝÁ¿
D_2BD2		DB	0			;ÖØÂëÇø¼ÆÊý
D_9597		DW	0			;ÖØÂë×ÜÊý

D_959B		DB	0FFH			;ºº×ÖÊäÈëÍê³ÉÌ¬
D_95D5		DB	0			;·µ»ØÂëÇøÖ¸Õë
D_95D6		DB	0			;±£´æ..
D_2BD4		DB	0			;·µ»ØË«Æ´´ÊÆ«ÒÆ
D_2BAA		DW	0			;¶Á·µ»ØÂëÇøÖ¸Õë
D_2BAC		DB	0			;´¿ÖÐÎÄ±êÖ¾

D_2BB9		DB	0			;ÊäÈë×´Ì¬±êÖ¾
	;=1Ò»¼ü¸ßÆµ,  =2¶þ¼ü¸ßÆµ		=8Ë«Æ´´Ê×é
	;=10H´Ê×éÖØÂë,=20HÊ£ÓàÖØÂë,=40HÔ¤Ñ¡±êÖ¾ =80H¶þ×Ö´ÊÖØ×Ö±êÖ¾
D_963A		DB	0			;ÊäÈë·½Ê½
	;=1ÇøÎ»,      =2Ê×Î²,	   =4Æ´Òô,    =8Ë«Æ´
	;	      =20HÎå±Ê×ÖÐÍ,	      =80Hµç±¨
D_963B		DB	0			;×Öµä·½Ê½

D_2B98		DW	0			;´Ê×é¶ÎÂë
D_2B9A		DW	0			;²é´Ê±íÄÚÂëÇøÖ¸Õë
D_2B9C		DW	0			;·´Ïò²é´Ê±íÄÚÂëÇøÊ×Ö¸Õë
D_2B9E		DW	0			;ÕýÏò²é´Ê±íÄÚÂëÇøÊ×Ö¸Õë
D_2BA0		DW	0			;´Ê±íÄÚÂëÇøÊ×Ö¸Õë
D_2BA2		DW	0			;´Ê±íÍâÂëÇøÊ×Ö¸Õë
D_2BA5		DB	0			;²é´Ê±í·½Ïò(0=Õý,FF=·´)
D_9669		DW	0			;Ñ¡ÖÐ´Ê×éÄÚÂëÔÚ´Ê±íµØÖ·
D_966B		DB	0			;Ñ¡ÖÐ´Ê×éÄÚÂë³¤¶È
	;--------------------------------------------------------------------+
D_9648		DW	0			;´Ê×éÖØÂëÇø(¿É´æ11¸ö)	     |
D_964A		DB	0
D_964B		DB	0			;·Ç0±íÊ¾Ë«Æ´¶þ×Ö´ÊµÚ¶þ×ÖÎ»ÒÆ

F_SPCZ		DB	'SPCZ.DAT',0    ;9      ;¹²17
F_YX		DB	'YX0.DAT',0     ;8
F_INI		DB	'213L.INI',0    ;9      ;¹²23
F_SWMB		DB	'SWMB',0        ;5
F_PYMB		DB	'PYMB',0        ;5
F_DBMB		DB	'DBMB',0        ;5
	;--------------------------------------------------------------------+
D_9650		DB	0			;Îå±Ê´Ê»ãÖØÂëÊý
D_9668		DB	56			;ÌáÊ¾ÐÐ´Ê×éÇø³¤¶È
D_966C		DB	0			;Íâ²¿´Ê×é=0,ÁªÏë=1
D_9639		DB	0			;ÁªÏë¿ª¹Ø
D_966D		DB	0			;ÁªÏë±êÖ¾(FFH)
D_966F		DB	0			;Ë«Æ´´Ê×é´¦Àí±êÖ¾

D_AH		DB	0			;µ±Ç°AHÖµ

D_AH20		DW	OFFSET L_AH20		;<×°Èë´Ê×éÁªÏë¿âÔ¤Ñ¡>
		DW	OFFSET L_AH21		;<Ä£Äâ¹¦ÄÜ¼ü>
		DW	OFFSET L_AH22		;<È¡ºº×ÖË«Æ´Âë>
		DW	OFFSET L_INT16		;<µ÷ÓÃ×Ó³ÌÐò>
		DW	OFFSET L_INT16		;<ÍË³öºº×Ö¹¦ÄÜ¿ª¹Ø>
		DW	OFFSET L_AH25		;<ÏÔÊ¾°æ±¾ÐÅÏ¢>
		DW	OFFSET L_INT16		;<ÉèÖÃÊ±ÖÓ>
		DW	OFFSET L_AH27		;<È¡»òÖÃºº×ÖÊäÈë·½Ê½ºÅ>
		DW	OFFSET L_INT16		;<Ö§³ÖÑÇÎ°ËÙÂ¼»ú>
		DW	OFFSET L_AH29		;<ÖØÏÔÌáÊ¾ÐÐ>
		DW	OFFSET L_AH2A		;<°ïÖúÄ£¿éµØÖ·>
		DW	OFFSET L_AH2B		;<µ÷ROM BIOS>
		DW	OFFSET L_INT16		;AH=2CH
		DW	OFFSET L_INT16		;AH=2DH
		DW	OFFSET L_INT16		;AH=2EH
		DW	OFFSET L_AH2F		;<È¡±¾Ä£¿éÖÐ¶ÏÏòÁ¿>

D_213L		DB	'2.13L ºº×ÖÏµÍ³    1999Äê11ÔÂ    °æÈ¨ËùÓÐ   Öø×÷È¨ÈË:ÎâÏþ¾ü',0

D_9680		DW	0, 0, 0 		;Íâ²¿´Ê×é²ÎÊý	 [DI]
D_9686		DW	0, 0, 0 		;ÁªÏë²ÎÊý	 [DI+6]
D_INTWB 	DW	0, 0, 0 		;Îå±ÊÄ£¿éÆ«ÒÆ,¶Î [DI+12]
D_SPCZ		DW	0, 0, 0 		;Ë«Æ´´Ê×é¶Î,Ê×Ö· [DI+18]

D_YX		DW	0			;Ô¤Ñ¡×Ö±íµ±Ç°ÐÐÊ×Ö·
D_YXH		DB	1			;µ±Ç°ÐÐºÅ
D_DB		DW	0			;µç±¨Âë±íµØÖ·

;---¼üÅÌ¹ÜÀíÖÐ¶Ï---------------------------------
INT_16		PROC	FAR
		CLD
		STI
		PUSH	DS
		PUSH	ES
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	DI
		PUSH	SI
		PUSH	BP
		PUSH	CS
		POP	DS
		MOV	D_AH,AH

		CMP	AH,4			;<ÖÃÀ©Õ¹¼ü×´Ì¬>
		JNZ	L_02
		XOR	DX,DX
		MOV	DS,DX
		MOV	DS:[417H],AL
		JMP	L_RET
L_02:
		CMP	AH,1			;<È¡¼üÈë×´Ì¬>
		JNZ	L_04
L_03:
		JMP	L_AH01
L_04:
		CMP	AH,11H
		JZ	L_03

		CMP	AH,20H
		JB	L_INT16
		CMP	AH,2FH
		JA	L_INT16
		PUSH	AX
		MOV	AL,AH
		SUB	AL,20H
		CBW
		MOV	DI,AX
		POP	AX
		SHL	DI,1
		JMP	D_AH20[DI]		;Ö´ÐÐ¹¦ÄÜ20H-2FH
L_INT16:
		POP	BP			;·µ»Ø²¢Ö´ÐÐÔ­INT16
		POP	SI
		POP	DI
		POP	DX
		POP	CX
		POP	BX
		POP	ES
		POP	DS
		JMP	CS:D_INT16

;AH=1 *** È¡¼üÈë×´Ì¬ ***
L_AH01:
		CLI
		CALL	S_INT16_1		;ÅÐ¼üÅÌ»º³åÇøÓÐ×Ö·û
		JNZ	L_0010
		CMP	D_95D5,0		;ÅÐÓÐ·µ»Ø×Ö·û?
		JZ	L_0010
		MOV	AX,40H
		MOV	ES,AX
		MOV	SI,D_2BAA		;¶Á·µ»ØÂëÇøÖ¸Õë
		CALL	S_XBUF1 		;Ð´µ½¼üÅÌ»º³åÇø
		CALL	S_INT16_1		;ÔÙÅÐ
L_0010:
		STI
		POP	BP
		POP	SI
		POP	DI
		POP	DX
		POP	CX
		POP	BX
		POP	ES
		POP	DS
		RET	2			;±£´æ±êÖ¾¼Ä´æÆ÷·µ»Ø

;AH=25H *** ÏÔÊ¾°æ±¾ÐÅÏ¢ BL=ÏÔÊ¾ÊôÐÔ
L_AH25:
		CALL	S_XSBB
		JMP	SHORT L_RET

;AH=29H *** ÖØÏÔÌáÊ¾ÐÐ
L_AH29:
		CALL	S_CXTUX
		JMP	SHORT L_RET

;AH=2FH *** È¡±¾Ä£¿éÖÐ¶ÏÏòÁ¿BP:SI¡¢´Ê²ÎÊýÇøµØÖ·BP:DIºÍ2.13°²×°Â·¾¶BP:DX
L_AH2F:
		MOV	SI,OFFSET INT_16	;±¾Ä£¿éÖÐ¶ÏÏòÁ¿
		MOV	DI,OFFSET D_9680	;´Ê²ÎÊýÇøµØÖ·
		MOV	DX,D_PATH		;2.13°²×°Â·¾¶
		MOV	BP,CS
		MOV	AX,44H			;CKBD
		POP	CX
		POP	CX
		POP	CX
		POP	CX
		JMP	SHORT L_RET2

;AH=22H *** È¡ºº×ÖË«Æ´Âë DX=ºº×ÖÄÚÂë,·µ»ØAL=Ë«Æ´µÚÒ»Âë,AH=Ë«Æ´µÚ¶þÂë
L_AH22:
		MOV	AX,DX
		XCHG	AH,AL
		CALL	S_A9A0
		JMP	SHORT L_RET

;AH=21H *** Ä£Äâ¹¦ÄÜ¼ü AL=À©Õ¹ASCÂë
L_AH21:
		MOV	AH,AL
		XOR	AL,AL
		PUSH	AX
		CALL	S_JRCL
		POP	AX
		MOV	D_95D5,0
		JMP	SHORT L_RET

;AH=20H *** ×°Èë´Ê×éºÍÁªÏë¿â AL=0Íâ²¿´Ê×é,=1ÁªÏë¿â,=2Îå±Ê,3Ë«Æ´´Ê×é
;		    È¡µØÖ·:  AL=4Íâ²¿´Ê×é,=5ÁªÏë¿â,=6Îå±Ê,=7Ë«Æ´´Ê×é
L_AH20:
		MOV	BL,AL			;±£´æ
		AND	AL,3			;×ª0-3
		MOV	AH,6			;Ã¿ÖÖ6×Ö½Ú
		MUL	AH
		ADD	AX,OFFSET D_9680	;²ÎÊýÇøÊ×
		MOV	DI,AX			;

		CMP	BL,3			;ÅÐ×°Èë?
		JBE	L_2000
		MOV	BP,[DI] 		;È¡¶Î
		MOV	DX,[DI+2]		;È¡ÍâÂëÇøÊ×
		POP	SI
		POP	SI
		POP	DI
		POP	CX
		JMP	SHORT L_RET2
L_2000:
		MOV	[DI],BP 		;¶Î
		MOV	[DI+2],DX		;ÍâÂëÇøÊ×
		MOV	[DI+4],CX		;ÄÚÂëÇøÊ×
L_RET:
		POP	BP			;·µ»Ø
		POP	SI
L_RET1:
		POP	DI
		POP	DX
L_RET2:
		POP	CX
		POP	BX
		POP	ES
		POP	DS
		IRET

;AH=2BH *** µ÷ROM BIOS AL=AHµÄÖµ
L_AH2B:
		MOV	AH,AL
		CALL	L_INT16_1		;µ÷ROM BIOS INT16
		JMP	SHORT L_RET

;AH=2AH *** °ïÖúÄ£¿éµØÖ·BP:SI AL=0:Ð´Èë,=1È¡³ö
L_AH2A:
		OR	AL,AL
		JNZ	L_2A01
		MOV	D_HELP,SI		;Ð´Èë
		MOV	D_HELP+2,BP
		JMP	SHORT L_RET
L_2A01:
		MOV	SI,D_HELP		;È¡³ö
		MOV	BP,D_HELP+2
		POP	DI
		POP	DI
		JMP	SHORT L_RET1

;AH=27H *** È¡»òÖÃºº×ÖÊäÈë·½Ê½ºÅ AL=0È¡,=1ÖÃ:DL=ºº×ÖÊäÈë·½Ê½ºÅ
L_AH27:
		OR	AL,AL
		JZ	L_2701
		MOV	D_963A,DL		;ÖÃ
		JMP	SHORT L_RET
L_2701:
		MOV	DL,D_963A		;È¡
		POP	CX
		POP	CX
		POP	CX
		POP	CX
		JMP	SHORT L_RET2

INT_16		ENDP

D_KX		DB	'ÉÍ»'                   ;¿òÏß
		DB	'º º'
		DB	'ÈÍ¼'
D_MSG		DB	'2.13L ºº ×Ö Ïµ Í³',0
D_MSG1		DB	'  ÑÐ ÖÆ ÈË: Îâ Ïþ ¾ü   1999Äê11ÔÂ '

;×Ó³ÌÐò:ÏÔÊ¾°æ±¾ÐÅÏ¢ BL=ÏÔÊ¾ÊôÐÔ
S_XSBB		PROC	NEAR
		XOR	BH,BH
		MOV	DX,15
		MOV	SI,OFFSET D_KX		;¿òÏß
		CALL	S_XSYH			;ÏÔÊ¾ÉÏ±ßÏß
		INC	DH
L_2501:
		PUSH	SI
		CALL	S_XSYH			;ÏÔÊ¾¿ÕÐÐ
		POP	SI
		INC	DH
		CMP	DH,6
		JNZ	L_2501

		ADD	SI,3
		CALL	S_XSYH			;ÏÔÊ¾µ×Ïß

		PUSH	CS
		POP	ES
		MOV	SI,OFFSET D_MSG
		MOV	DX,217H
		MOV	AX,140FH		;¼Ó¿íÏÔÊ¾
		INT	10H
		XOR	BH,BH
		MOV	DX,417H
		MOV	BP,OFFSET D_MSG1	;°æÈ¨ÐÅÏ¢
		MOV	CX,34
		MOV	AX,1300H		;ÏÔÊ¾Ò»ÐÐ
		INT	10H

		MOV	DX,700H
		MOV	AH,2
		INT	10H
		RET
;×Ó³ÌÐò:ÏÔÊ¾Ò»ÐÐ
S_XSYH:
		PUSH	DX
		LODSB
		CALL	S_DWXS			;ÏÔÊ¾×ó¶Ë
		MOV	CL,48
		LODSB
		CALL	S_DWXS0 		;ÏÔÊ¾ÖÐ¼ä
		LODSB
		CALL	S_DWXS			;ÏÔÊ¾ÓÒ¶Ë
		POP	DX
		RET
S_DWXS:
		MOV	CX,1
S_DWXS0:
		PUSH	AX
		MOV	AH,2
		INT	10H
		POP	AX
		MOV	AH,9
		INT	10H
		ADD	DX,CX
		RET
S_XSBB		ENDP

;---¼üÅÌÓ²ÖÐ¶Ï-----------------------------------
INT_9		PROC	FAR
		CLD
		PUSHF
		CALL	CS:D_INT9		;Ö´ÐÐÔ­INT9

		PUSH	DS
		PUSH	ES
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	BP
		PUSH	CS
		POP	DS
		MOV	AX,40H
		MOV	ES,AX

		MOV	AX,ES:[17H]
		MOV	BL,K_SHIFT		;=1ÓÒ,=2×ó,=10H-SCROLL LOCK
		CMP	BL,10H
		JZ	L_9001
		TEST	AL,BL			;ÅÐSHIFT°´ÏÂ?
		JZ	L_9010
		JMP	SHORT L_9002
L_9001:
		TEST	AH,BL
		JZ	L_9010
L_9002:
		XOR	K_DEL,0FFH		;×ª»»
		JZ	L_9003
		CALL	L_1404			;¹ØÌáÊ¾ÐÐ
		JMP	SHORT L_9030
L_9003:
		CALL	S_CXTUX 		;ÖØÏÔÌáÊ¾ÐÐ
		JMP	SHORT L_9030
L_9010:
		AND	AL,0FH
		CMP	AL,0FH			;ÅÐCTRL+ALT+Ë«SHIFT?
		JNZ	L_9020
		MOV	AX,4CFFH		;·µ»ØDOS
		INT	21H
L_9020:
		CMP	D_INKEY,0		;ÅÐÖØÈë?
		JNZ	L_9030

		MOV	BX,ES:[1AH]		;¼üÅÌ»º³åÇøÊ×Ö·
		CMP	BX,ES:[1CH]		;=¼üÅÌ»º³åÇøÎ²?
		JNZ	L_9040
L_9030:
		MOV	AL,20H
		OUT	20H,AL
		POP	BP
		POP	DI
		POP	SI
		POP	DX
		POP	CX
		POP	BX
		POP	AX
		POP	ES
		POP	DS
		IRET
L_9040:
		MOV	D_INKEY,1		;ÖÃ±êÖ¾
		MOV	AX,ES:[BX]		;È¡¼üÈë×Ö·û
		CMP	AL,80H			;¼üÈë×Ö·ûASCIIÂë>80H?
		JB	L_9042
		OR	AH,AH			;ÅÐÐ´ÈëµÄºº×Ö?
		JZ	L_9042
		MOV	D_AH,0
		CALL	S_101K			;101À©Õ¹¼ü´¦Àí
L_9042:
		STI
		CALL	S_JRCL			;¼üÈë×Ö·û´¦Àí
		CLI

		MOV	BX,40H
		MOV	ES,BX
		CMP	D_95D5,0		;ÎÞ·µ»Ø¼ü?
		JNZ	L_9048
		MOV	DI,ES:[1CH]		;¼üÅÌ»º³åÇøÎ²Ö·
		MOV	ES:[1AH],DI		;=¼üÅÌ»º³åÇøÊ×Ö·
L_9044:
		MOV	D_95D5,0
L_9046:
		MOV	D_INKEY,0		;Çå±êÖ¾
		JMP	SHORT L_9030
L_9048:
		CMP	D_95D5,1		;1¸ö·µ»ØÂë?
		JZ	L_9044
		CALL	S_XBUF			;Ð´µ½¼üÅÌ»º³åÇø
		JMP	SHORT L_9046
INT_9		ENDP

;×Ó³ÌÐò:Ð´µ½¼üÅÌ»º³åÇø ES=40H
S_XBUF		PROC	NEAR
		MOV	SI,OFFSET D_959D	;·µ»ØÂëÇø
S_XBUF1:
		MOV	DI,ES:[1CH]		;¼üÅÌ»º³åÇøÎ²Ö· 	8.7
		MOV	ES:[1AH],DI		;=¼üÅÌ»º³åÇøÊ×Ö·
		MOV	CL,D_95D5		;·µ»ØÂë¼ÆÊý
		XOR	CH,CH
		XOR	BX,BX
		CMP	CX,D_KBDBUF		;±È¼üÅÌ»º³åÇøÈÝÁ¿?
		JB	L_XB1
		MOV	CX,D_KBDBUF
		DEC	CX
		INC	BX
L_XB1:
		SUB	D_95D5,CL
L_XB2:
		LODSB
		MOV	AH,0
		STOSW
		CMP	DI,ES:[82H]		;=¼üÅÌ»º³åÇøÎ²?
		JNZ	L_XB3
		MOV	DI,ES:[80H]		;Ö¸ÏòÇøÊ×
L_XB3:
		LOOP	L_XB2
		MOV	ES:[1CH],DI		;¼üÅÌ»º³åÇøÎ²

		OR	BX,BX
		JZ	L_XB4
		MOV	D_2BAA,SI
L_XB4:
		RET
S_XBUF		ENDP

;×Ó³ÌÐò:101¼üÅÌÀ©Õ¹¼ü´¦Àí<AH , >AH
S_101K		PROC	NEAR
		CMP	K_FCC,'Y'               ;ÅÐ·Â³¤³Ç¼ü?
		JNZ	L_101K3
		XOR	SI,SI
L_101K1:
		CMP	AH,D_KZJB[SI]		;ÅÐ¼ü?
		JZ	L_101K2
		INC	SI
		CMP	SI,6			;½áÊø?
		JB	L_101K1
		JMP	SHORT L_101K3
L_101K2:
		MOV	AH,K_AF1[SI]		;·µ»ØAX
		XOR	AL,AL
L_101K3:
		CMP	D_AH,10H
		JZ	L_101K4
		XOR	AL,AL
L_101K4:
		RET
S_101K		ENDP

D_KZJB		DB	52H, 47H, 49H, 53H, 4FH, 51H
	;		Ins  Home PgUp Del  End  PgDn	×¨ÓÃ¹â±ê¼üÉÏÁù¸ö¼ü

D_GNJB		DW	OFFSET L_QW		;ÇøÎ»(ALT+F1)
		DW	OFFSET L_SW		;Ê×Î²(ALT+F2)
		DW	OFFSET L_PY		;Æ´Òô(ALT+F3)
		DW	OFFSET L_SP		;Ë«Æ´(ALT+F4)
		DW	OFFSET L_CF9		;½¨Á¢/È¡Ïû´¿ÖÐÎÄ(CTRL+F9)
		DW	OFFSET L_ASC		;ASCII(ALT+F6)
		DW	OFFSET L_WBZX		;Îå±Ê(ALT+F5)
		DW	OFFSET L_DB		;µç±¨(ALT+F10)
		DW	OFFSET L_YX		;Ô¤Ñ¡×Ö±í(F12)
		DW	OFFSET L_HELP		;Áª»ú°ïÖú(F11)
		DW	OFFSET L_XTK1		;ÏµÍ³¿ØÖÆ(CTRL+F5)
		DW	OFFSET L_AF9		;¶¨ÒåË«Æ´´Ê×é(ALT+F9)
		DW	OFFSET L_CF10		;ÉèÖÃ´òÓ¡²ÎÊý(CTRL+F10)

;×Ó³ÌÐò:¼üÈë×Ö·û´¦Àí-----------------------------
S_JRCL		PROC	NEAR
		CMP	K_DEL,0 		;¹¦ÄÜ¼üÓÐÐ§?
		JZ	L_J20
		JMP	L_9BB9			;ÎÞÐ§
L_J20:
		CMP	AH,K_CF7		;ÖÐÎ÷ÎÄÏÔÊ¾ÇÐ»»:CTRL+F7
		JNZ	L_J30
		JMP	SHORT L_J40
L_J30:
		JMP	L_J100
L_J40:
		MOV	AX,DS:[101H]		;AL:µ±Ç°ÏÔÊ¾·½Ê½,AH=1:Ö±½ÓÐ´ÆÁ
		CMP	AL,4			;ÅÐÎ÷ÎÄ?
		JB	L_J50
		CMP	AL,7
		JZ	L_J50
		MOV	AX,1805H		;ÔÊÐíÏÔÊ¾·½Ê½×ª»»
		INT	10H
		MOV	AX,180AH		;¹Ø±ÕÖ±½ÓÐ´ÆÁ
		INT	10H
		MOV	AX,3			;ÉèÖÃÎ÷ÎÄÏÔÊ¾·½Ê½
		INT	10H
		JMP	SHORT L_J80
L_J50:
		OR	AH,AH			;=0:·ÇÖ±½ÓÐ´ÆÁ
		JNZ	L_J60
		MOV	AL,DS:[100H]		;ºº×ÖÏÔÊ¾·½Ê½
		JMP	SHORT L_J70
L_J60:
		MOV	AX,180BH		;´ò¿ªÖ±½ÓÐ´ÆÁ
		INT	10H
		MOV	AX,3
L_J70:
		INT	10H
L_J80:
		MOV	AX,1C0DH		;»Ø³µ
		MOV	BX,40H
		MOV	ES,BX
		MOV	BX,ES:[1AH]
		MOV	ES:[BX],AX		;·µ»Ø»Ø³µ¼ü
L_J90:
		JMP	L_9BB9			;·µ»ØÒ»¸ö¼ü
L_J100:
		MOV	DX,CS:[100H]		;DL=ºº×Ö·½Ê½,DH=µ±Ç°·½Ê½
		CMP	DH,DL			;ÊÇ·ñºº×ÖÏÔÊ¾·½Ê½?
		JNZ	L_J90
		OR	AL,AL			;ÅÐ¹¦ÄÜ¼ü
		JNZ	L_J130

		CMP	AH,0A1H 		;ALT+PGDN*,ÏÔÊ¾2.13L±êÌâ
		JNZ	L_J110
		MOV	BL,D_0A1H		;É«ºÅ
		CALL	S_XSBB			;ÏÔÊ¾
		INC	D_0A1H			;É«ºÅ+1
		JMP	L_9BB9
D_0A1H		DB	1EH

;¡¾²éÕÒ¹¦ÄÜ¼ü¡¿
L_J110:
		MOV	SI,OFFSET K_AF1 	;¹¦ÄÜ¼ü±í
L_J120:
		CMP	AH,[SI] 		;ÅÐ¹¦ÄÜ¼ü?
		JZ	L_J140
		INC	SI
		CMP	BYTE PTR [SI],0 	;±íÎ²?
		JNZ	L_J120
L_J130:
		JMP	L_9C86			;×Ö·û´¦Àí.Ô­Îª9C90	12.10
L_J140:
		SUB	SI,OFFSET K_AF1
		SHL	SI,1
		JMP	D_GNJB[SI]		;×ª¹¦ÄÜÄ£¿é

D_DX0		DW	0			;³õÊ¼Î»ÖÃ
D_AF9		DB	0
;¡¾¶¨ÒåË«Æ´´Ê×é¡¿
L_AF9:
		MOV	D_AF9,AH
		JMP	CF1_0
AF9_A:
		MOV	SI,OFFSET D_BUF
		MOV	DI,30H			;´Ê×éÔÝ´æÇø
		PUSH	CS
		POP	ES
		XOR	CX,CX
AF9_B:
		LODSW				;È¡Ò»Î»ÖÃ
		MOV	DX,AX
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		MOV	AH,8			;È¡¹â±ê´¦×Ö·û
		INT	10H
		STOSB				;Ð´ÈëÔÝ´æÇø
		INC	CX
		CMP	SI,A_BUF		;µ½¶¨Î»ÇøÎ²?
		JNZ	AF9_B

		TEST	WORD PTR [DI-2],8080H	;ÅÐÄ©×Ö?
		JNZ	AF9_C
AF9_ERR:
		MOV	AX,0E07H
		INT	10H
		RET
AF9_C:
		MOV	SI,30H			;´Ê×éÔÝ´æÇø
		MOV	DX,CX
		CMP	CL,6			;¶þ»òÈý×Ö?		10.16
		JBE	AF9_D
		MOV	CL,6			;È¡Ç°Èý×Ö
AF9_D:
		LODSB				;È¡Ç°Èý×Ö
		CMP	AL,0A0H 		;ÅÐºº×Ö?
		JBE	AF9_ERR
		LOOP	AF9_D
		MOV	CX,DX

		MOV	ES,D_SPCZ		;Ë«Æ´´Ê×é¶Î
		MOV	AX,ES:[6]		;Ô­´Ê×éÀ©Õ¹ÇøÎ²
		MOV	DI,AX
		MOV	SI,30H
		ADD	AX,CX			;+³¤¶È
		INC	AX			;+¶ººÅ
		CMP	AX,ES:[8]		;±ÈË«Æ´´Ê×éÇøÎ²?
		JA	AF9_ERR
		MOV	ES:[6],AX
		REP	MOVSB			;Ð´ÈëÐÂ´Ê
		MOV	AL,','
		STOSB
		XOR	AX,AX
		STOSW				;½áÊø±êÖ¾
		RET
CF1_0:
		XOR	BH,BH
		MOV	AH,3			;È¡¹â±êÎ»ÖÃ
		INT	10H
		MOV	D_DX0,DX
		MOV	A_BUF,OFFSET D_BUF
CF1_1:
		MOV	AX,1408H		;DX´¦×Ö·û±äÉ«
		INT	10H
		MOV	SI,A_BUF
		MOV	[SI],DX 		;´æ
		ADD	SI,2
		INC	DX
		CMP	SI,OFFSET D_BUF+510
		JZ	CF1_2
		MOV	A_BUF,SI
CF1_2:
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		CALL	S_INT16 		;¼üÈë
		CMP	AH,48H			;¡ü
		JNZ	CF1_3
		OR	DH,DH
		JZ	CF1_2
		DEC	DH
		JMP	SHORT CF1_2
CF1_3:
		CMP	AH,50H			;¡ý
		JNZ	CF1_3A
		CMP	DH,24
		JAE	CF1_2
		INC	DH
		JMP	SHORT CF1_2
CF1_3A:
		CMP	AH,4BH			;¡û
		JNZ	CF1_3B
		OR	DL,DL
		JZ	CF1_2
		DEC	DL
		JMP	SHORT CF1_2
CF1_3B:
		CMP	AH,4DH			;¡ú
		JNZ	CF1_3C
		CMP	DL,79
		JAE	CF1_2
		INC	DL
		JMP	SHORT CF1_2
CF1_3C:
		CMP	AH,D_AF9		;ALT_F9
		JZ	CF1_1
CF1_5:
		CMP	AL,1BH			;ESC
		JNZ	CF1_6
S_CF1_5:					;»Ö¸´
		MOV	SI,OFFSET D_BUF
CF1_5A:
		CMP	SI,A_BUF
		JZ	CF1_5B
		LODSW
		MOV	DX,AX
		MOV	AX,1408H
		INT	10H
		JMP	SHORT CF1_5A
CF1_5B:
		MOV	DX,D_DX0
		MOV	AH,2			;»Ö¸´Ô­¹â±ê
		INT	10H
		RET
CF1_6:
		CMP	AL,8			;ÍË¸ñ?
		JNZ	CF1_7
		MOV	SI,A_BUF
		CMP	SI,OFFSET D_BUF 	;µ½ÇøÊ×?
		JZ	CF1_6A
		MOV	DX,[SI-2]
		MOV	AX,1408H
		INT	10H
		SUB	A_BUF,2
CF1_6A:
		JMP	CF1_2
CF1_7:
		CMP	AL,0DH			;»Ø³µ?
		JNZ	CF1_6A
		CALL	S_CF1_5 		;»Ö¸´
		CMP	D_AF9,0
		JZ	CF1_8
		JMP	AF9_A
CF1_8:
		MOV	SI,OFFSET D_BUF 	;
CF1_A:
		CMP	SI,A_BUF		;ÅÐ½áÊø?
		JZ	CF1_B
		LODSW				;È¡
		MOV	DX,AX
		MOV	AH,2			;¹â±ê¶¨Î»
		INT	10H
		MOV	AH,8			;È¡¹â±ê´¦×Ö·û
		INT	10H
		XOR	AH,AH
		MOV	[SI-2],AX		;Ð´Èë´Ê×éÇø
		JMP	SHORT CF1_A
CF1_B:
		RET

D_DYCS		DB	'´òÓ¡²ÎÊý',0
D_DYCS1 	DB	' 1-×ÖÐÍ 2-ÐÐ¾à 3-×ó¿Õ 4-µ¥Ïò '
		DB	'5-Ë«Ïò 6-ÌØ´ò¹Ø 7-¿ª 8-Î÷ÎÄ´òÓ¡ 9-ºº×Ö',0
D_C101		DB	'Çë¼üÈë×ÖÐÍ(A-x):',0
D_C102		DB	'Çë¼üÈëÐÐ¾à(1-255):',0
D_C103		DB	'Çë¼üÈë×ó±ß¿ÕÁÐ(0-2000):',0
D_INPUT 	DB	'`',7 DUP(0)
;¡¾ÉèÖÃ´òÓ¡²ÎÊý¡¿
L_CF10:
		MOV	AH,6			;È¡´òÓ¡²ÎÊý
		INT	17H
		CMP	AH,6			;ÅÐÓÐÇý¶¯Ä£¿é?
		JNZ	L_C100
		JMP	L_9DC0
L_C100:
		MOV	SI,OFFSET D_DYCS
		CALL	S_QTXS			;ÇåÌáÊ¾ÐÐ²¢ÏÔÊ¾
		MOV	SI,OFFSET D_DYCS1
		MOV	BL,1EH
		CALL	S_A24A			;ÏÔÊ¾²Ëµ¥
		CALL	S_INT16 		;Ñ¡Ôñ
		PUSH	AX
		CALL	S_1400
		POP	AX
		MOV	BL,1EH
		MOV	DI,OFFSET D_INPUT+1	;¼üÈë»º³åÇø

		CMP	AL,'1'                  ;×ÖÐÍ
		JNZ	L_C102
		MOV	SI,OFFSET D_C101
		CALL	S_A24A			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢
		MOV	BYTE PTR [DI],'@'
		CALL	S_INT16 		;¼üÈë
		CMP	AL,'A'
		JB	L_C10ERR
		CMP	AL,'z'
		JA	L_C10ERR
		MOV	AH,'`'
		MOV	[DI+1],AX
		MOV	BYTE PTR [DI+3],0
		MOV	SI,OFFSET D_INPUT
L_C101:
		XOR	AH,AH
		XOR	DX,DX
L_C101A:
		LODSB
		OR	AL,AL
		JZ	L_C101B
		INT	17H
		JMP	SHORT L_C101A
L_C101B:
		JMP	SHORT L_CF10
L_C10ERR:
		MOV	DL,7
		CALL	S_1403			;ÏìÁå
		JMP	SHORT L_CF10
L_C102:
		CMP	AL,'2'                  ;ÐÐ¾à
		JNZ	L_C103
		MOV	SI,OFFSET D_C102
		CALL	S_A24A			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢
		MOV	BYTE PTR [DI],'&'
		CALL	S_INPUT 		;¼üÈëÊý
		JB	L_C10ERR
		JMP	SHORT L_C101
L_C103:
		CMP	AL,'3'                  ;×ó±ß¿Õ
		JNZ	L_C104
		MOV	SI,OFFSET D_C103
		CALL	S_A24A
		MOV	BYTE PTR [DI],'['
		CALL	S_INPUT 		;¼üÈëÊý
		JB	L_C10ERR
		JMP	SHORT L_C101
L_C104:
		CMP	AL,'4'                  ;µ¥Ïò´òÓ¡
		JNZ	L_C105
		MOV	AL,'>'
L_C104A:
		MOV	[DI],AL
		MOV	WORD PTR [DI+1],60H
		JMP	SHORT L_C101
L_C105:
		CMP	AL,'5'                  ;Ë«Ïò´òÓ¡
		JNZ	L_C106
		MOV	AL,'<'
		JMP	SHORT L_C104A
L_C106:
		CMP	AL,'6'                  ;ÌØÊâ´òÓ¡¹Ø
		JNZ	L_C107
L_C106A:
		SUB	AL,'6'
		MOV	AH,4			;ÉèÖÃ
		INT	17H
		JMP	S_1404
L_C107:
		CMP	AL,'7'                  ;ÌØÊâ´òÓ¡¿ª
		JZ	L_C106A

		CMP	AL,'8'                  ;Î÷ÎÄ´òÓ¡
		JNZ	L_C109
L_C108:
		SUB	AL,'8'
		MOV	AH,3			;ÉèÖÃ
		INT	17H
		JMP	S_1404
L_C109:
		CMP	AL,'9'                  ;ºº×Ö´òÓ¡
		JZ	L_C108
		JMP	S_1404

;×Ó³ÌÐò:¼üÈëÊý×Ö
S_INPUT 	PROC	NEAR
		INC	DI			;¼üÈë»º³åÇø
L_IN1:
		CALL	S_INT16 		;¼üÈë
		CMP	AL,0DH			;»Ø³µ?
		JZ	L_IN6
		CMP	AL,8			;ÍË¸ñ?
		JNZ	L_IN5
		CMP	DI,OFFSET D_INPUT+2	;Ö¸ÕëÔÚÇøÊ×?
		JBE	L_IN1
		DEC	DI			;Î»ÖÃ-1
L_IN4:
		CALL	S_1403A 		;ÍË¸ñ
		JMP	SHORT L_IN1
L_IN5:
		CMP	AL,'0'                  ;ÅÐÊý×Ö?
		JB	L_IN1
		CMP	AL,'9'
		JA	L_IN1
		MOV	[DI],AL 		;Ð´Èë
		INC	DI
		JMP	SHORT L_IN4
L_IN6:
		CMP	DI,OFFSET D_INPUT+2	;Ö¸ÕëÔÚÇøÊ×?
		JZ	L_IN9
		MOV	BYTE PTR [DI],0
		MOV	SI,OFFSET D_INPUT
		CLC
		RET
L_IN9:
		STC
		RET
S_INPUT 	ENDP

;¡¾Ô¤Ñ¡×Ö±í¡¿
L_YX:
		MOV	AX,D_YX 		;Ô¤Ñ¡×Ö±íÊ×Ö·
		OR	AX,AX
		JZ	L_YX3
		MOV	D_2BB9,40H		;Ô¤Ñ¡±êÖ¾
L_YX1:
		CALL	S_1400			;ÇåÌáÊ¾ÐÐ
		MOV	BL,D_TUX1		;ÑÕÉ«:À¶µ×»Æ×Ö
		MOV	DL,' '
		CALL	S_1403
		MOV	SI,D_YX 		;Ô¤Ñ¡×Ö±íµ±Ç°ÐÐµØÖ·
		MOV	DL,'A'                  ;ÐòºÅ
L_YX2:
		PUSH	DX
		CALL	S_1403			;ÏÔÊ¾ÐòºÅ
		LODSB				;Ç°×Ö½Ú
		CALL	S_1403A
		LODSB				;ºó×Ö½Ú
		CALL	S_1403A
		POP	DX
		INC	DX			;ÐòºÅ¼ÓÒ»
		CMP	DL,'Z'
		JBE	L_YX2			;Î´Íê
		CALL	S_A24E			;Çå¹â±ê
L_YX3:
		RET

D_HELP		DW	0,0			;°ïÖúÄ£¿éµØÖ·
;¡¾°ïÖú¡¿
L_HELP:
		CMP	D_HELP+2,0		;ÅÐÒÑ¹Ò½Ó°ïÖúÄ£¿é?
		JZ	L_HELP1
		CALL	DWORD PTR D_HELP	;Ö´ÐÐ°ïÖú³ÌÐò
L_HELP1:
		RET

D_CZW		DB	' '                     ;´¿ÖÐÎÄÏÔÊ¾±êÖ¾
;¡¾½¨Á¢/È¡Ïû´¿ÖÐÎÄ¡¿
L_CF9:
		MOV	AL,7FH
		XOR	D_2BAC,0FFH		;´¿ÖÐÎÄ·½Ê½
		JNZ	L_CF9_1
		MOV	AL,' '
L_CF9_1:
		MOV	D_CZW,AL		;´æ±êÖ¾

;×Ó³ÌÐò:ÖØÏÔÌáÊ¾ÐÐ
S_CXTUX:
		MOV	AL,D_963A
		MOV	SI,OFFSET D_QWXS	;ÇøÎ»
		TEST	AL,1
		JNZ	L_CT1
		MOV	SI,OFFSET D_SWXS	;Ê×Î²
		TEST	AL,2
		JNZ	L_CT1
		MOV	SI,OFFSET D_PYXS	;Æ´Òô
		TEST	AL,4
		JNZ	L_CT1
		MOV	SI,OFFSET D_SPXS	;Ë«Æ´
		TEST	AL,8
		JNZ	L_CT1
		MOV	SI,OFFSET D_WBZX	;Îå±Ê
		TEST	AL,20H
		JNZ	L_CT1
		MOV	SI,OFFSET D_DBXS	;µç±¨
		TEST	AL,80H
		JNZ	L_CT1
		MOV	SI,OFFSET D_YWXS	;Ó¢ÎÄ
L_CT1:
		CALL	S_QTXSC 		;ÇåÌáÊ¾ÐÐ²¢ÏÔÊ¾ÊäÈë·½Ê½¼°´¿ÖÐÎÄ±êÖ¾
		MOV	SI,OFFSET D_213L	;ÌáÊ¾ÐÐ°æÈ¨±êÖ¾
		MOV	BL,D_TUX1
		MOV	DL,10
		CALL	S_A249			;ÏÔÊ¾×Ö·û´®
		RET

;----------------------------------------------------------------------------
D_XTK1		DB	'×ªµÚ¶þÒ³  ¹â±ê¿ª¹Ø  Ö´ÐÐÌØÏÔ  ¼ò·±ÇÐ»»  '
		DB	'ÍË³öºº×Ö  ·Â³¤³Ç¼ü  ÁªÏë¿ª¹Ø  Ö±½ÓÐ´ÆÁ',0
;¡¾ÏµÍ³¿ØÖÆ-µÚÒ»Ò³¡¿
L_XTK1:
		MOV	SI,OFFSET D_XTK1	;µÚÒ»Ò³²Ëµ¥
		MOV	CX,800H
		CALL	S_CDKZ			;ÌáÊ¾ÐÐ²Ëµ¥¿ØÖÆ
		CMP	AL,1BH			;<ESC>
		JNZ	L_XTK1A
		RET

K_GBKG		DB	0FFH			;¹â±ê¿ª¹Ø
L_XTK1A:
		CMP	AL,2			;<¹â±ê¿ª¹Ø>
		JNZ	L_XTK1B
		NOT	K_GBKG
		MOV	AH,17H
		MOV	AL,K_GBKG
		INT	10H
		RET

D_TXZF		DB	'ÌØÏÔ×Ö·û´®:',0
L_XTK1B:
		CMP	AL,3			;<Ö´ÐÐÌØÏÔ>
		JNZ	L_XTK1C
		PUSH	CS
		POP	ES
		MOV	SI,OFFSET D_TXZF
		CALL	S_QTXS			;ÇåÌáÊ¾ÐÐ²¢ÏÔÊ¾
		MOV	DI,030H 		;½èCS:30HÇøÎª×Ö·û´æ·ÅÇø
		MOV	SI,DI			;±£´æ
		MOV	AL,14			;Òýµ¼·û
		STOSB
L_XTK1B1:
		CALL	S_INT16 		;È¡¼üÈë×Ö·û
		CMP	AL,8			;ÍË¸ñ?
		JNZ	L_XTK1B3
		CMP	SI,DI
		JZ	L_XTK1B1
		DEC	DI
L_XTK1B2:
		MOV	BL,D_TUX1		;ÑÕÉ«:À¶µ×»Æ×Ö
		CALL	S_1403A 		;ÏÔÊ¾ÍË¸ñ
		JMP	SHORT L_XTK1B1
L_XTK1B3:
		CMP	AL,1BH			;<ESC>?
		JZ	L_XTK1B6
		CMP	AL,0DH			;»Ø³µ?
		JZ	L_XTK1B4
		STOSB				;´æ·Å
		JMP	SHORT L_XTK1B2
L_XTK1B4:
		MOV	AL,']'                  ;½áÊø·û
		STOSB
L_XTK1B5:
		CMP	SI,DI			;Êä³öÍê?
		JZ	L_XTK1B6
		LODSB				;È¡Ò»×Ö·û
		MOV	CX,1
		MOV	AH,9
		INT	10H			;Êä³ö
		JMP	SHORT L_XTK1B5
L_XTK1B6:
		JMP	S_1404			;¹Ø±ÕÌáÊ¾ÐÐ

D_JF		DB	18			;¼ò·±±êÖ¾
L_XTK1C:
		CMP	AL,4			;<¼ò·±ÇÐ»»>
K_JFQH	EQU	$
		JNZ	L_XTK1D
		MOV	AL,18
		CMP	AL,D_JF
		JNZ	L_XTK1C1
		DEC	AX
L_XTK1C1:
		MOV	D_JF,AL
		MOV	AH,18H			;AL=17·±Ìå,=18¼òÌå
		INT	10H
		MOV	AX,1813H		;ÖØÏÔÆÁÄ»
		INT	10H
		RET

D_QR		DB	'ÇëÔÙ´ÎÈ·ÈÏ(Y/N)',7,0
L_XTK1D:
		CMP	AL,5			;<ÍË³öºº×Ö>
K_TCHZ	EQU	$
		JNZ	L_XTK1E
		MOV	SI,OFFSET D_QR
		CALL	S_QTXS			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢
		CALL	S_INT16 		;¼üÈë
		AND	AL,5FH
		CMP	AL,'Y'                  ;ÅÐ?
		JZ	L_XTK1D1
		JMP	S_CXTUX 		;ÖØÏÔÌáÊ¾ÐÐ
L_XTK1D1:
		XOR	SI,SI
		MOV	AX,4A06H		;ÇåÀíÄÚ´æ
		INT	2FH
		MOV	AX,4CFFH		;ÍË³ö
		INT	21H

D_FCCJ		DB	'·Â³¤³Ç¼ü',0, '±ê×¼¼üÅÌ',0
D_JHJB		DB	68H, 69H, 6AH, 6BH, 66H, 6DH	;·Â³¤³Ç½»»»¼ü±í
	;		A-F1 A-F2 A-F3 A-F4 C-F9 A-F6	;·Â³¤³ÇÊ±Óë[0D2H]½»»»
L_XTK1E:
		CMP	AL,6			;<·Â³¤³Ç¼ü>
		JNZ	L_XTK1F
		MOV	DI,OFFSET K_AF1 	;¼üÎ»±í
		MOV	CX,6			;ÐÞ¸ÄÁù¸ö¼ü
		MOV	BX,OFFSET D_JHJB	;·Â³¤³Ç½»»»¼ü±í
		MOV	SI,OFFSET D_FCCJ	;ÏÔÊ¾ÄÚÈÝ
		MOV	AL,'Y'
		CMP	K_FCC,AL		;·Â³¤³Ç¼ü?
		JNZ	L_XTK1E1
		MOV	AL,'N'
		ADD	SI,9
L_XTK1E1:
		MOV	K_FCC,AL		;±ä»»
L_XTK1E2:
		MOV	AL,[BX]
		XCHG	AL,[DI] 		;½»»»
		MOV	[BX],AL
		INC	BX
		INC	DI
		LOOP	L_XTK1E2
		JMP	S_QTXS			;ÏÔÊ¾

L_XTK1F:
		CMP	AL,7			;<ÁªÏë¿ª¹Ø>
		JNZ	L_XTK1G
		NOT	D_9639			;ÁªÏë±êÖ¾
		CMP	D_9639,0
		JZ	L_XTK1F1
		MOV	SI,OFFSET D_9A60
		JMP	S_QTXS			;ÏÔÊ¾ÁªÏë×´Ì¬
L_XTK1F1:
		RET

L_XTK1G:
		CMP	AL,8			;<Ö±½ÓÐ´ÆÁ>
K_ZJXP	EQU	$
		JNZ	L_XTK1H
		MOV	AL,11			;ÉèÖÃÖ±½ÓÐ´ÆÁ
		CMP	BYTE PTR CS:[102H],0	;ÅÐµ±Ç°Ö±½ÓÐ´ÆÁ?	9.11
		JZ	L_AH18
		MOV	AL,10			;È¡ÏûÖ±½ÓÐ´ÆÁ
L_AH18:
		MOV	AH,18H			;ÉèÖÃ
		INT	10H
		RET
L_XTK1H:
		JMP	SHORT L_XTK2

;----------------------------------------------------------------------------
D_XTK2		DB	'×ªµÚÒ»Ò³  ´òÓ¡×Ö·û  ¶ÔÍâÏÔÊ¾  ÖØÏÔÆÁÄ»  '
		DB	'Æ´Òô´Ê×é  ×Öµä·½Ê½  ÖØÂëÌáÊ¾  ±£³ÖÌáÊ¾',0
D_DK		DB	'´ò¿ª',0
D_GB		DB	'¹Ø±Õ',0
D_DYZF		DB	'´òÓ¡×Ö·û´®:',0
;¡¾ÏµÍ³¿ØÖÆ-µÚ¶þÒ³¡¿
L_XTK2:
		MOV	SI,OFFSET D_XTK2	;µÚ¶þÒ³²Ëµ¥
		MOV	CX,800H
		CALL	S_CDKZ			;ÌáÊ¾ÐÐ²Ëµ¥¿ØÖÆ
		CMP	AL,1BH			;<ESC>
		JNZ	L_XTK2A
		RET

L_XTK2A:
		CMP	AL,2			;<´òÓ¡×Ö·û>
		JNZ	L_XTK2B
		PUSH	CS
		POP	ES
		MOV	SI,OFFSET D_DYZF
		CALL	S_QTXS			;ÇåÌáÊ¾ÐÐ²¢ÏÔÊ¾
		MOV	DI,030H 		;½èCS:30HÇøÎª×Ö·û´æ·ÅÇø
		MOV	SI,DI			;±£´æ
L_XTK2A1:
		CALL	S_INT16 		;È¡¼üÈë×Ö·û
		CMP	AL,8			;ÍË¸ñ?
		JNZ	L_XTK2A3
		CMP	SI,DI
		JZ	L_XTK2A1
		DEC	DI
L_XTK2A2:
		MOV	BL,D_TUX1		;ÑÕÉ«:À¶µ×»Æ×Ö
		CALL	S_1403A 		;ÏÔÊ¾ÍË¸ñ
		JMP	SHORT L_XTK2A1
L_XTK2A3:
		CMP	AL,0AH			;CTRL+»Ø³µ?
		JZ	L_XTK2A5
		CMP	AL,0DH			;»Ø³µ?
		JZ	L_XTK2A4
		STOSB				;´æ·Å
		JMP	SHORT L_XTK2A2
L_XTK2A4:
		MOV	AX,0A0DH		;»Ø³µ»»ÐÐ
		STOSW				;´æ·Å
L_XTK2A5:
		CMP	SI,DI			;´òÓ¡Íê?
		JZ	L_XTK2A6
		LODSB				;È¡Ò»×Ö·û
		XOR	DX,DX
		XOR	AH,AH
		INT	17H			;´òÓ¡
		JMP	SHORT L_XTK2A5
L_XTK2A6:
		JMP	S_1404			;¹Ø±ÕÌáÊ¾ÐÐ

L_XTK2B:
		CMP	AL,3			;<¶ÔÍâÏÔÊ¾>
		JNZ	L_XTK2C
		XOR	AX,AX
		MOV	DS,AX
		MOV	BH,3			;×Ö·û
		CMP	BYTE PTR DS:[449H],3	;¶ÔÍâÏÔÊ¾×Ö·û?
		PUSH	CS
		POP	DS
		JA	L_XTK2B1
		MOV	BH,DS:[100H]		;Í¼ÐÎ(ºº×ÖÏÔÊ¾·½Ê½)
L_XTK2B1:
		MOV	AX,1407H		;ÉèÖÃ
		INT	10H
		JMP	S_CXTUX 		;ÖØÏÔÌáÊ¾ÐÐ

L_XTK2C:
		CMP	AL,4			;<ÖØÏÔÆÁÄ»>
		JNZ	L_XTK2D
K_CXPM	EQU	$
		MOV	AX,1813H
		INT	10H
		RET

L_XTK2D:
		CMP	AL,5			;<Æ´Òô´Ê×é>
		JNZ	L_XTK2E
		MOV	AL,74H			;JZ
		MOV	SI,OFFSET D_DK
		CMP	AL,BYTE PTR K_PYCZ
		JNZ	L_XTK2D1
		MOV	AL,0EBH 		;JMP
		MOV	SI,OFFSET D_GB
L_XTK2D1:
		MOV	BYTE PTR K_PYCZ,AL
		JMP	S_QTXS

L_XTK2E:
		CMP	AL,6			;<×Öµä·½Ê½>
		JNZ	L_XTK2F
		MOV	SI,OFFSET D_GB
		XOR	D_963B,0FFH
		JZ	L_XTK2E1
		MOV	SI,OFFSET D_DK
L_XTK2E1:
		JMP	S_QTXS

L_XTK2F:
		CMP	AL,7			;<ÖØÂëÌáÊ¾>
		JNZ	L_XTK2G
		MOV	AL,BYTE PTR K_CMTS
		CMP	AL,7
		JZ	L_XTK2F1
		MOV	AL,7
		MOV	SI,OFFSET D_DK
		JMP	SHORT L_XTK2F2
L_XTK2F1:
		MOV	AL,' '
		MOV	SI,OFFSET D_GB
L_XTK2F2:
		MOV	BYTE PTR K_CMTS,AL
		JMP	S_QTXS

L_XTK2G:
		CMP	AL,8			;<±£³ÖÌáÊ¾ÐÐ>
		JNZ	L_XTK2H
		XOR	BYTE PTR DS:[0F4H],2
		JZ	L_XTK2G1
		JMP	S_CXTUX
L_XTK2G1:
		JMP	L_1404
L_XTK2H:
		CMP	AL,48H			;¡ü
		JNZ	L_XTK2I
		JMP	L_XTK1
L_XTK2I:
		JMP	L_XTK2

;----------------------------------------------------------------------------
D_QWXS		DB	'ÇøÎ»',0
D_SWXS		DB	'Ê×Î²',0
D_PYXS		DB	'Æ´Òô',0
D_PYTS		DB	' V-zh I-ch U-sh L-ai J-an H-ang K-ao'
		DB	' F-en G-eng Y-ing S-ong V-',0
D_SPXS		DB	'Ë«Æ´',0
D_SPTS		DB	' Q-iu W-ua.ve R-ia T-ie D-ei P-ou'
		DB	' Z-uan X-i.uang C-un B-ian N-in M-iao',0
D_WBZX		DB	'Îå±Ê',0
D_CZXS		DB	'´Ê×é',0
D_DBXS		DB	'µç±¨',0
D_YWXS		DB	'Ó¢ÎÄ',0
;¡¾ÇøÎ»¡¿
L_QW:
		MOV	SI,OFFSET D_QWXS	;ÇøÎ»
		MOV	AL,1
		JMP	SHORT L_PY1
;¡¾Ê×Î²¡¿
L_SW:
		CMP	D_SW,0			;ÅÐÓÐÎÞÊ×Î²Âë±í?	5.31
		JZ	L_ERROR
		MOV	AX,D_SW
		MOV	D_2BD6,AX
		MOV	AX,D_SW+2
		MOV	D_2BD8,AX
		MOV	SI,OFFSET D_SWXS	;Ê×Î²
		MOV	AL,2
		JMP	SHORT L_PY1
;¡¾Æ´Òô¡¿
L_PY:
		CMP	D_PY,0			;ÅÐÓÐÎÞÆ´ÒôÂë±í?
		JZ	L_ERROR
		MOV	AX,D_PY
		MOV	D_2BD6,AX
		MOV	AX,D_PY+2
		MOV	D_2BD8,AX
		MOV	AL,4
		MOV	SI,OFFSET D_PYXS	;Æ´Òô
		CALL	L_PY1
		MOV	SI,OFFSET D_PYTS
		JMP	SHORT L_SP1
;¡¾Ë«Æ´¡¿
L_SP:
		CMP	D_PY,0			;ÅÐÓÐÎÞÆ´ÒôÂë±í?
		JZ	L_ERROR
		MOV	AX,D_PY
		MOV	D_2BD6,AX
		MOV	AX,D_PY+2
		MOV	D_2BD8,AX
		MOV	AL,8
		MOV	SI,OFFSET D_SPXS	;Ë«Æ´
		CALL	L_PY1
		MOV	SI,OFFSET D_SPTS
L_SP1:
		MOV	BL,D_TUX2		;ÑÕÉ«:
		JMP	S_A24C
L_ERROR:
		JMP	L_9DC0
;¡¾µç±¨¡¿
L_DB:
		CMP	D_DB,0			;ÅÐÓÐÎÞµç±¨Âë±í?
		JZ	L_ERROR
		MOV	SI,OFFSET D_DBXS
		MOV	AL,80H
L_PY1:
		MOV	D_963A,AL
		MOV	D_2BB9,0		;Çå±êÖ¾
		MOV	D_2BB0,0		;Çå¼üÈë×Ö·û¼ÆÊý
		MOV	D_959B,0FFH		;ÖÃºº×ÖÊäÈëÍê³ÉÌ¬
S_QTXSC:
		CALL	S_QTXS			;ÇåÌáÊ¾ÐÐ²¢ÏÔÊ¾
		PUSH	AX
		MOV	DL,D_CZW
		CALL	S_1403
		POP	AX
L_PY9:
		RET
;¡¾Îå±Ê¡¿
L_WBZX:
		CMP	D_INTWB+2,0		;ÅÐÎå±ÊÄ£¿é°²×°?
		JZ	L_PY9
		MOV	SI,OFFSET D_WBZX
		MOV	AL,20H
		MOV	D_2BD2,0
		JMP	SHORT L_PY1
;¡¾Ó¢ÎÄ¡¿
L_ASC:
		MOV	D_963A,AL		;=0
		MOV	D_2BB9,AL		;Çå±êÖ¾
		MOV	D_959B,0FFH		;ÖÃºº×ÖÊäÈëÍê³ÉÌ¬
		JMP	S_1404

D_A210		DB	60H,'¡¢', 2EH,'¡£', 27H,'¡°', 22H,'¡±'
		DB	5BH,'¡¶', 5DH,'¡·', 5CH,'£®', 7CH,'¡­'
		DB	7BH,'¡®', 7DH,'¡¯'
;¡¾´¿ÖÐÎÄ·½Ê½´¦Àí¡¿
L_9BA6:
		CMP	D_2BAC,0FFH		;´¿ÖÐÎÄ·½Ê½?
		JZ	L_9BB0
L_9BB9:
		MOV	D_95D5,1		;·µ»ØÒ»¸ö×Ö·û
		RET
L_9BB0:
		MOV	DI,OFFSET D_959D
L_9BB1:
		INC	D_95D5			;·µ»ØÂëÇø¼ÆÊý=1
L_A1E0:
		CMP	AL,7FH
		JAE	L_A1E5
		CMP	AL,' '                  ;´¿ÖÐÎÄ´¦Àí
		JNB	L_A1E7
L_A1E5:
		MOV	[DI],AL 		;Ò»×Ö½ÚÐ´Èë·µ»ØÂëÇø
		RET
L_A1E7:
		JA	L_A1F2
		MOV	AH,AL
L_A1EB:
		MOV	[DI],AX
		INC	D_95D5
		RET
L_A1F2:
		MOV	SI,OFFSET D_A210	;´¿ÖÐÎÄ×ª»»Âë±í
		MOV	BL,AL
		MOV	CX,10
L_A1FA:
		LODSB				;È¡±íÏî
		CMP	AL,BL			;ÊÇ·ñ¸Ã¼ü
		JNZ	L_A202
		LODSW				;È¡×ª»»Âë
		JMP	SHORT L_A1EB
L_A202:
		LODSW				;Ö¸ÕëºóÒÆ
		LOOP	L_A1FA
		MOV	AH,BL
		MOV	AL,0A3H 		;ÈýÇø
		OR	AH,80H			;ÖÃ´¿ÖÐÎÄ
		JMP	SHORT L_A1EB

;¡¾×Ö·û´¦ÀíÈë¿Ú¡¿
L_9C86:
		TEST	D_2BB9,40H		;Ô¤Ñ¡±êÖ¾
		JZ	L_9C90
		JMP	L_A4F0			;¡úÔ¤Ñ¡´¦Àí
L_9C90:
		CMP	D_959B,0FFH		;Íê³ÉÌ¬?
		JNZ	L_9C9A
		JMP	L_9E68			;¡úÊ×¼ü´¦Àí
L_9C9A:
		TEST	BYTE PTR D_2BB9,10H	;ÓÐ´Ê×éÖØÂë?
		JZ	L_9CA5
		JMP	L_A798
L_9CA5:
		MOV	BX,OFFSET D_963A	;ÊäÈë·½Ê½
		TEST	BYTE PTR [BX],1 	;ÇøÎ»?
		JZ	L_9CA6
		JMP	L_QWCL
L_9CA6:
		TEST	BYTE PTR [BX],20H	;Îå±Ê?
		JZ	L_9CA8
		JMP	L_WBCL
L_9CA8:
		CMP	AL,';'                  ;×ªÍâ²¿´Ê×é?
		JNZ	L_9CB3
L_9CA9:
		JMP	L_A5D7
L_9CB3:
		TEST	BYTE PTR [BX],80H	;µç±¨?
		JZ	L_9CC0
		JMP	L_DBCL
L_9CC0:
		TEST	BYTE PTR [BX],2 	;Ê×Î²?
		JZ	L_9CC7
		CMP	AL,0DH			;»Ø³µ?
		JNZ	L_9CF2
		JMP	L_SW			;ÖØÈëÊ×Î²
L_9CC7:
		TEST	BYTE PTR [BX],4 	;Æ´Òô?
		JNZ	L_9CEB
		CMP	AL,0DH			;Ë«Æ´»Ø³µ?
		JNZ	L_9CF2
		JMP	L_SP			;ÖØÈëË«Æ´
L_9CEB:
		CMP	AL,0DH			;»Ø³µ?
		JNZ	L_9CF2
		JMP	L_PY			;ÖØÈëÆ´Òô
L_9CF2:
		CMP	AL,8			;ÍË¸ñ?
		JNZ	L_9CF8
		CMP	D_2BB0,0
		JZ	L_9D48
		CALL	S_9D7D			;¶¨Î»
		CALL	S_1403K
		DEC	D_2BB0			;¼üÈë×Ö·û¼ÆÊý¼õÒ»
		JNZ	L_9D4B
		MOV	AL,0DH
		JMP	SHORT L_9CC0
L_9D48:
		JMP	L_9DC5
L_9D4B:
		CALL	S_9FC0			;´ÓÂë±íÊ×Îª²éÖØÂëÉèÖÃÖ¸Õë
		JMP	L_9FA0
L_9CF8:
		CMP	AL,' '
		JNZ	L_9CFE
		MOV	AL,0			;¿Õ¸ñ=0
		JMP	SHORT L_9D0C
L_9CFE:
		CMP	AL,'9'
		JA	L_9D51
		CMP	AL,'0'
		JB	L_9D51
		JNZ	L_9D0A
		MOV	AL,3AH
L_9D0A:
		AND	AL,0FH			;Ñ¡ÖÐ
L_9D0C:
		CMP	AL,D_2BD2
		JA	L_9D27
		CBW
		SHL	AX,1
		ADD	AX,OFFSET D_2BBA
		MOV	BX,AX
		MOV	AX,[BX]
		MOV	WORD PTR D_959D,AX
		JMP	L_A559			;×ªÁªÏë
L_9D27:
		JMP	L_9DC0			;ÏìÁå²¢ÍË³ö
L_9D49:
		JMP	L_9DAE
L_9D51:
		CMP	AL,"'"                  ;Æ´Òô¸ôÒô·û             2.3
		JZ	L_9D55
		CMP	AL,'['                  ;ÍùÇ°·­Ò³
		JZ	L_9D8B
		CMP	AL,']'                  ;Íùºó·­Ò³
		JZ	L_9D49
L_9D54:
		CMP	AL,'`'                  ;ÅÐÐ¡Ð´×ÖÄ¸¼°`
		JB	L_9D7A
		CMP	AL,'z'
		JA	L_9D7A
L_9D55:
		TEST	D_963A,8		;ÅÐË«Æ´?
		JZ	L_9D58
		CMP	D_2BB0,4		;ÒÑ4¼ü?
		JB	L_9D58
		MOV	D_959B,0FFH		;ÖÃÍê³ÉÌ¬
		JMP	L_9F08			;Ë«Æ´Ê×¼ü
L_9D58:
		CMP	D_2BB0,8
		JAE	L_9DC0
		INC	D_2BB0			;¼üÈë×Ö·û¼ÆÊý¼ÓÒ»
		CALL	S_9D7D			;¶¨Î»
		CALL	S_9F89			;Ð´Èë¼üÈëÂëÇø²¢ÏÔÊ¾
		CALL	S_9FD0			;ÎªÕýÏò²éÖØÂëÉèÖÃÖ¸Õë
L_9FA0:
		MOV	AX,D_2BD6		;Âë±íÊ×
		MOV	D_2BAD,AX
		MOV	D_2BD0,11
		AND	D_2BB9,0F5H		;Çå¶þ¼ü¸ßÆµºÍË«Æ´´Ê×éÎ»
		CALL	S_A017			;Ïò>²éÂë±í
		CALL	S_9FD9			;ÎªÕýÏòÏÂ´Î²éÖØÂëÉèÖÃÖ¸Õë
		CMP	D_2CC0,0FFH		;ÅÐÆ´Òô¼òÂë?
		JZ	L_9D60
		CMP	D_2BB0,2
		JNZ	L_9D70
L_9D60:
		MOV	AX,D_2BD6
		MOV	D_2BAF,AX		;Ïòºó²é´ÓÊ×¿ªÊ¼
L_9D70:
		TEST	D_2BB9,8		;ÅÐË«Æ´´Ê×é?
		JNZ	L_9DC6
		CALL	S_A164			;ÏÔÊ¾ÖØÂë×Ö
		JMP	SHORT L_9DC5
L_9D7A:
		OR	AL,AL
		JNZ	L_9DC0
		JMP	L_9BB9			;´¿ÖÐÎÄ´¦Àí
;¡¾ÏìÁå¡¿
L_9DC0:
		MOV	DL,7
		CALL	S_1403
L_9DC5:
		MOV	D_95D5,0		;ÍË³ö
L_9DC6:
		RET
;¡¾Ç°Ò³¡¿
L_9D8B:
		OR	D_2BB9,2		;¶þ¼ü¸ßÆµ
		CALL	S_A001			;Îª·´Ïò²éÖØÂëÉèÖÃÖ¸Õë
		CALL	S_A011			;Ïò<²éÂë±í
		CALL	S_9FED			;Îª·´ÏòÏÂ´Î²éÖØÂëÉèÖÃÖ¸Õë
		CMP	D_2BD0,11
		JZ	L_9D97
		MOV	D_2BD0,11
L_9D97:
		CALL	S_A164			;ÏÔÊ¾ÖØÂë×Ö
		JMP	SHORT L_9DC5
;¡¾ºóÒ³¡¿
L_9DAE:
		OR	D_2BB9,2		;¶þ¼ü¸ßÆµ
		CALL	S_9FD0			;ÎªÕýÏò²éÖØÂëÉèÖÃÖ¸Õë
		CALL	S_A017			;Ïò>²éÂë±í
		CALL	S_9FD9			;ÎªÕýÏòÏÂ´Î²éÖØÂëÉèÖÃÖ¸Õë
		CMP	D_9597,0
		JNZ	L_9DAF
		MOV	AL,D_2BCF		;È¡Ä©Ò³ÖØÂëÊý
		MOV	D_2BD0,AL		;ÖÃ×î´óÖØÂëÊý
		JMP	SHORT L_9D97
L_9DAF:
		MOV	AL,D_2BD2
		OR	AL,AL
		JZ	L_9D97
		CMP	AL,11
		JZ	L_9D97
		MOV	D_2BCF,AL		;´æÄ©Ò³ÖØÂëÊý
		JMP	SHORT L_9D97
;¡¾Îå±Ê´¦Àí¡¿
L_WBCL:
		CMP	AL,8			;<ÍË¸ñ>
		JNZ	L_WB10
		MOV	BL,D_2BB0
		OR	BL,BL			;ÅÐÓÐ¼ü?
		JZ	L_WB2
		XOR	BH,BH
		CMP	D_2BB0[BX],' '          ;ÅÐ²»Âú4¼üµÄZ¹¦ÄÜ?
		JNZ	L_WB0
		DEC	D_2BB0
L_WB0:
		MOV	D_2BD2,0
		CALL	S_9D7D			;¼üÈëÂëÇø¶¨Î»
		CALL	S_1403K 		;Çå¿Õ
		DEC	D_2BB0			;¼üÈëÂë¼ÆÊý-1
		JNZ	L_WB2
L_WB1:
		MOV	D_959B,0FFH
L_WB2:
		RET
L_WB10:
		CMP	AL,0DH			;<»Ø³µ>
		JNZ	L_WB18
		JMP	L_WBZX
L_WB18:
		CMP	AL,' '                  ;<¿Õ¸ñ>
		JNZ	L_WB20
		CMP	D_2BD2,0		;ÒÑÓÐÖØÂë?
		JZ	L_WB19
		MOV	AX,0FFH 		;·­Ò³
		JMP	L_WB61
L_WB19:
		INC	D_2BB0
		CALL	S_9F89			;Ð´Èë¼üÈëÂëÇø²¢ÏÔÊ¾
		JMP	L_WB60
L_WB20:
		MOV	CL,D_9650		;´Ê»ãÖØÂëÊý
		OR	CL,CL
		JZ	L_WB30
L_WB21:
		XOR	CH,CH
		MOV	D_9650,CH		;Çå
		XOR	BP,BP
		OR	CL,'0'
		CMP	AL,CL
		JA	L_WB22
		CMP	AL,'1'
		JAE	L_WB24
L_WB22:
		MOV	BP,AX			;BP=0:ÒÑÑ¡Ôñ
		MOV	AL,1			;ÎÞÑ¡Ôñ,Ä¬ÈÏµÚÒ»¸ö
L_WB24:
		AND	AL,0FH
		MOV	CL,AL
		DEC	CX
		MOV	SI,OFFSET D_BUF 	;ÖØÂëÇø(½èÓÃ)
L_WB24B:
		OR	CX,CX
		JZ	L_WB26
L_WB25:
		LODSW				;²éÕÒµÚCL¸ö´Ê
		TEST	AX,8080H
		JNZ	L_WB25
		LOOP	L_WB25
L_WB26:
		MOV	DI,OFFSET D_959D	;·µ»ØÂëÇø
		XOR	CX,CX
L_WB27:
		LODSW				;È¡Ò»×Ö
		MOV	[DI],AX
		ADD	DI,2
		INC	CX
		INC	CX
		TEST	AX,8080H		;ÅÐ´Ê½áÊø
		JNZ	L_WB27
		OR	BYTE PTR [DI-4],80H	;¸ßÎ»ÖÃ1
		OR	BYTE PTR [DI-2],80H	;¸ßÎ»ÖÃ1
		MOV	D_95D5,CL		;·µ»Ø×Ö½ÚÊý
		MOV	D_2BD2,0
		OR	BP,BP			;=0:ÒÑÑ¡Ôñ
		JNZ	L_WB29
		JMP	L_WB1
L_WB29:
		MOV	AX,BP
		JMP	L_WB35			;·ÇÊý×Ö´¦Àí
L_WB30:
		MOV	CL,D_2BD2
		OR	CL,CL			;×ÖÖØÂëÊý
		JZ	L_WB51
		MOV	D_95D5,2		;·µ»Ø×Ö½ÚÊý
		MOV	D_2BD2,0
		OR	CL,'0'
		CMP	AL,CL
		JA	L_WB34
		CMP	AL,'1'
		JB	L_WB34
		MOV	BL,AL
		AND	BL,0FH
		XOR	BH,BH
		SHL	BX,1
		MOV	AX,D_2BBA[BX]		;Ñ¡ÖÐ
		JMP	L_WB98
L_WB34:
		MOV	DI,OFFSET D_959D
		MOV	CX,D_2BBC		;Ê××Ö
		MOV	[DI],CX 		;·µ»Ø
		ADD	DI,2
L_WB35:
		CMP	AL,'a'                  ;ÅÐÐ¡Ð´×ÖÄ¸?
		JB	L_WB36
		CMP	AL,'z'
		JA	L_WB36
L_WB35A:
		MOV	D_959B,0
		MOV	D_2BB0,1
		MOV	SI,OFFSET D_WBZX
		CALL	S_QTXSC 		;ÇåÌáÊ¾ÐÐ²¢ÏÔÊ¾        2.13
		JMP	S_9F89			;Ð´Èë¼üÈëÂëÇø²¢ÏÔÊ¾
L_WB36:
		MOV	D_959B,0FFH
		CMP	D_2BAC,0FFH		;ÅÐ´¿ÖÐÎÄ·½Ê½?
		JNZ	L_WB38
		JMP	L_9BB1			;´¿ÖÐÎÄ´¦Àí
L_WB38:
		XOR	AH,AH
		MOV	DS:[DI],AX
		INC	D_95D5
		RET
L_WB50:
		JMP	L_9BB9
L_WB51:
		CMP	AL,'a'
		JB	L_WB50
		CMP	AL,'z'
		JA	L_WB50
		CMP	D_2BB0,4
		JZ	L_WB35A
		INC	D_2BB0			;¼ü+1
		CALL	S_9F89			;Ð´Èë¼üÈëÂëÇø²¢ÏÔÊ¾
		CMP	D_2BB0,4		;Âú4¼ü?
		JZ	L_WB60
		RET
;²éWBZX
L_WB60:
		XOR	AX,AX
L_WB61:
		MOV	SI,OFFSET D_BUF 	;½èÓÃ:·µ»ØÇø
		MOV	BX,OFFSET D_2BB1	;¼üÈëÂëÇø
		MOV	CX,1EH
		PUSHF
		CALL	DWORD PTR D_INTWB	;µ÷WBZXÄ£¿é
L_WB63:
		PUSH	CS
		POP	ES

		TEST	DL,80H			;ÅÐÓÐÎÞ×Ö´Ê?
		JNZ	L_WB70
L_WB64:
		CALL	S_BEEP			;ÏìÁå
		RET				;2.13
L_WB70:
		TEST	DL,1			;´Ê»ã?
		JNZ	L_WB70A
		JMP	L_WB80
L_WB70A:
		TEST	DL,4			;ÓÐÖØÂë?
		JZ	L_WB76
L_WB71:
		MOV	D_9650,CL
		XOR	CH,CH
		PUSH	CX
		MOV	DL,10H
		CALL	S_9F30			;¶¨Î»ÇåÌáÊ¾ÐÐ
		POP	CX
		MOV	DI,16
		MOV	DL,'1'
L_WB72:
		PUSH	DX
		MOV	BL,D_TUX1
		CALL	S_1403			;ÏÔÊ¾ÐòºÅ
		INC	DI
L_WB73:
		LODSW				;È¡Ò»×Ö
		MOV	BL,D_TUX2
		PUSH	AX
		OR	AX,8080H
		PUSH	AX
		CALL	S_1403A 		;ÏÔÊ¾Ç°×Ö½Ú
		INC	DI
		POP	AX
		MOV	AL,AH
		CALL	S_1403A 		;ÏÔÊ¾ºó×Ö½Ú
		INC	DI
		POP	AX
		CMP	DI,78			;ÅÐÌáÊ¾ÐÐÂú?
		JBE	L_WB74
		POP	DX
		RET
L_WB74:
		TEST	AX,8080H		;ÅÐ´ÊÎ²?
		JZ	L_WB75
		JMP	SHORT L_WB73
L_WB75:
		MOV	DL,' '
		CALL	S_1403
		INC	DI
		POP	DX
		INC	DX
		LOOP	L_WB72
		RET
L_WB76:
		XOR	CX,CX
L_WB77:
		MOV	DI,OFFSET D_959D
L_WB771:
		LODSW
		INC	CX
		INC	CX
		TEST	AX,8080H		;ÕÒ´ÊÎ²
		JZ	L_WB78
		MOV	[DI],AX
		ADD	DI,2
		JMP	SHORT L_WB771
L_WB770:
		JMP	L_WB64
L_WB78:
		CMP	AH,' '
		JB	L_WB770
		CMP	AL,' '
		JB	L_WB770
		OR	AX,8080H		;¸ßÎ»ÖÃ1
		MOV	[DI],AX
L_WB79:
		MOV	D_95D5,CL		;·µ»Ø×Ö½ÚÊý
		JMP	L_WB1
L_WB80:
		TEST	DL,2			;Z¹¦ÄÜ?
		JZ	L_WB90
		MOV	DL,10H
		CALL	S_9F30			;¶¨Î»ÇåÌáÊ¾ÐÐ
		MOV	DI,OFFSET D_2BBC	;×ÖÖØÂëÇø
		LODSB				;ÖØÂëÊý
L_WB84:
		MOV	CL,AL
		XOR	CH,CH
		MOV	D_2BD2,CL		;´æ
		MOV	DL,'1'
L_WB88:
		PUSH	DX
		CALL	S_1403			;ÏÔÊ¾ÐòºÅ
		LODSW				;Ð´Èë×ÖÖØÂëÇø
		STOSW
		PUSH	AX
		CALL	S_1403A 		;ÏÔÊ¾Ç°×Ö½Ú
		POP	AX
		MOV	DL,AH
		CALL	S_1403			;ÏÔÊ¾ºó×Ö½Ú
		LODSB
		CALL	S_1403A 		;ÏÔÊ¾Îå±ÊÂë
		LODSB
		CALL	S_1403A
		LODSB
		CALL	S_1403A
		LODSB
		CALL	S_1403A
		MOV	DL,' '
		CALL	S_1403
		POP	DX
		INC	DX
		LOOP	L_WB88
		RET
L_WB90:
		TEST	DL,4			;ÖØÂë×Ö?
		JZ	L_WB97
		MOV	DI,OFFSET D_2BBC	;×ÖÖØÂëÇø
		LODSB				;ÖØÂëÊý
L_WB92:
		MOV	CL,AL
		XOR	CH,CH
		MOV	D_2BD2,CL		;´æ
		REP	MOVSW			;´«ËÍ
		CALL	S_BEEP
L_WB94:
		MOV	DL,10H
		CALL	S_9F30			;¶¨Î»ÇåÌáÊ¾ÐÐ
		MOV	DL,'1'
		CALL	S_A180			;ÏÔÊ¾ÖØÂë×Ö²¢ÏìÁå
		RET
L_WB97:
		XCHG	AH,AL
L_WB98:
		MOV	WORD PTR D_959D,AX	;·µ»ØÂë
		MOV	D_95D5,2		;·µ»Ø×Ö½ÚÊý
		MOV	D_959B,0FFH
		RET
;¡¾µç±¨´¦Àí¡¿
L_DBCL:
		CMP	AL,0DH			;»Ø³µ?
		JNZ	L_DB1
		JMP	L_DB			;ÖØÈëµç±¨
L_DB1:
		CMP	AL,8			;ÍË¸ñ?
		JZ	L_9DE0
		JMP	L_9E2A
;¡¾ÇøÎ»·­Ò³¡¿
L_9C3E:
		CMP	AL,'['                  ;<
		JNZ	L_9C54
		MOV	AX,D_2BBA		;µ±Ç°ÐÐÊ××Ö
		SUB	AH,11		       ;Î»ºÅ-11
		CMP	AH,0A1H 		;<0
		JNB	L_9C51
		ADD	AH,94		       ;+94
		DEC	AX			;ÇøºÅ-1
		CMP	AL,0A1H
		JNB	L_9C51
		MOV	AX,0A1A1H
L_9C51:
		JMP	L_9E0D			;ÏÔÊ¾
L_9C54:
		CMP	AL,']'                  ;>
		JNZ	L_9C60
		MOV	AX,D_2BCE		;µ±Ç°ÐÐÄ©×Ö
		INC	AH			;Î»ºÅ+1
		CMP	AH,0FFH
		JNZ	L_9C5C
		MOV	AH,0A1H
		INC	AL
L_9C5C:
		CMP	AL,0FFH
		JNZ	L_9C5E
		MOV	AX,0A1A1H
L_9C5E:
		JMP	L_9E0D			;ÏÔÊ¾
;¡¾ÇøÎ»Ñ¡ÖÐ¡¿
L_9C60:
		CMP	AL,' '
		JNZ	L_9C68
		MOV	AL,'0'                  ;¿Õ¸ñ=0
		JMP	SHORT L_9C74
L_9C68:
		CMP	AL,'9'                  ;ÅÐÊý×Ö
		JA	L_9C77
		CMP	AL,'0'
		JB	L_9C77
		JNZ	L_9C74
		MOV	AL,3AH
L_9C74:
		JMP	L_9D0A			;Ñ¡ÖÐ
L_9C77:
		JMP	L_9BA6			;×ªÅÐÐ¡Ð´×ÖÄ¸
;¡¾ÇøÎ»´¦Àí¡¿
L_QWCL:
		CMP	AL,0DH			;»Ø³µ?
		JNZ	L_9DD2
		JMP	L_QW			;ÖØÈëÇøÎ»
L_9DD2:
		CMP	D_2BB0,5		;ÇøÎ»+¿Õ¸ñ?
		JZ	L_9C3E
L_9DDC:
		CMP	AL,8			;ÍË¸ñ?
		JNZ	L_9DF7
L_9DE0:
		MOV	DL,8
		CALL	S_1403			;ÍË¸ñ
		DEC	D_2BB0			;¼üÈëÂë¼ÆÊý-1
		CMP	D_2BB0,0		;=0?
		JNZ	L_9DF4
		MOV	D_959B,0FFH		;ÖÃÍê³ÉÌ¬
L_9DF4:
		JMP	L_9DC5
L_9DF7:
		CMP	AL,' '                  ;ÇøÎ»+¿Õ¸ñ?
		JNZ	L_9E2A
		MOV	AX,WORD PTR D_2BB1	;È¡ÒÑ¼üÈëÇøºÅ
		CMP	D_2BB0,2
		JZ	L_9DF8
		CBW
		XCHG	AH,AL
L_9DF8:
		MOV	D_2BB0,5		;ÖÃ±êÖ¾
		XCHG	AL,AH
		AND	AX,0F0FH
		AAD				;ÇøºÅ=AL
		OR	AL,AL
		JZ	L_9DF9
		CMP	AL,94
		JBE	L_9DFA
L_9DF9:
		MOV	AL,1
L_9DFA:
		ADD	AX,0A1A0H		;AX=¸ÃÇøÊ××Ö
L_9E0D:
		MOV	SI,OFFSET D_2BBA	;ÖØÂëÇøÊ×Ö·
		MOV	CX,0BH			;=11
		MOV	D_2BD2,CL
L_9E17:
		CMP	AH,0FFH 		;=95?
		JNZ	L_9E18
		MOV	AH,0A1H 		;ÖÃÇøÊ×
		INC	AX			;ÇøºÅ+1
L_9E18:
		CMP	AL,0FFH
		JNZ	L_9E1A
		MOV	AL,0A1H
L_9E1A:
		PUSH	AX
		MOV	DL,5
		CALL	S_1402			;¶¨Î»
		POP	AX
		PUSH	AX
		CALL	S_9E50			;ÏÔÊ¾Ê××ÖÇøºÅ
		POP	AX
		PUSH	AX
		MOV	AL,AH
		CALL	S_9E50			;ÏÔÊ¾Ê××ÖÎ»ºÅ
		POP	AX
L_9E1F:
		MOV	[SI],AX 		;Ð´ÈëÖØÂëÇø
		ADD	SI,2			;Ö¸Õë¼Ó2
		INC	AH			;Î»ºÅ+1
		CMP	AH,0FFH 		;ÇøÎ²(Î»ºÅ=95)
		JNZ	L_9E20
		MOV	AH,0A1H 		;ÖÃÇøÊ×
		INC	AX			;ÇøºÅ+1
		CMP	AL,0FFH
		JNZ	L_9E20
		MOV	AL,0A1H
L_9E20:
		LOOP	L_9E1F
		JMP	L_A172			;ÏÔÊ¾
L_9E28:
		JMP	L_9BA6			;×ª´¿ÖÐÎÄ´¦Àí
L_9E2A:
		CMP	AL,'0'
		JB	L_9E28
		CMP	AL,'9'
		JA	L_9E28
		INC	D_2BB0
		CALL	S_9F89			;Ð´Èë¼üÈëÂëÇø²¢ÏÔÊ¾
		CMP	D_2BB0,4		;ÒÑËÄ¼ü?
		JNB	L_9E40
		RET
L_9E40:
		MOV	SI,OFFSET D_2BB1
		LODSW				;È¡Ç°¶þ¼ü
		XCHG	AL,AH
		AND	AX,0F0FH
		AAD
		MOV	BL,AL			;ÇøºÅ
		LODSW				;È¡ºó¶þ¼ü
		XCHG	AL,AH
		AND	AX,0F0FH
		AAD
		MOV	BH,AL			;Î»ºÅ
		TEST	D_963A,1		;ÅÐÇøÎ»·½Ê½?
		JZ	L_9E48
		OR	BH,BH
		JZ	L_9E47
		CMP	BH,94
		JA	L_9E47
		OR	BL,BL
		JZ	L_9E47
		CMP	BL,94
		JA	L_9E47
		ADD	BX,0A0A0H		;×ªÎªÄÚÂë
L_9E46:
		MOV	WORD PTR D_959D,BX	;´æ·µ»ØÂëÇø
		JMP	L_A559			;×ªÁªÏë
L_9E47:
		MOV	D_959B,-1
		JMP	L_9DC0
L_9E48:
		MOV	AL,100
		MUL	BL
		MOV	BL,BH
		XOR	BH,BH
		ADD	BX,AX
		SHL	BX,1
		ADD	BX,D_DB 		;¼Óµç±¨Âë±íÊ×Ö·
		MOV	BX,[BX] 		;È¡ºº×Ö
		JMP	SHORT L_9E46

;×Ó³ÌÐò:ÏÔÊ¾ÇøºÅ»òÎ»ºÅ
S_9E50:
		SUB	AL,0A0H
S_9E51:
		XOR	AH,AH
		MOV	DH,0AH			;=10
		DIV	DH
		MOV	BL,D_TUX2		;ÑÕÉ«:À¶µ×°××Ö
		PUSH	AX			;±£´æ¸öÎ»AH
		OR	AL,30H			;Ê®Î»
		CALL	S_1403A
		POP	AX
		MOV	DL,AH
		OR	DL,30H			;¸öÎ»
		JMP	S_1403

;¡¾Ê×¼ü´¦Àí¡¿
L_9E68:
		CMP	D_963A,0		;ASCII?
		JNZ	L_9E72
L_9E6F:
		JMP	L_9BA6			;´¿ÖÐÎÄ´¦Àí
L_9E72:
		CALL	S_9F62			;ÅÐSHIFT+¿Õ¸ñ?
		JNB	L_9E80
		MOV	AL,D_95D6
		MOV	D_95D5,AL
		RET
L_9E80:
		TEST	D_2BB9,10H		;ÓÐ´Ê×éÖØÂë?
		JZ	L_9E86
		JMP	L_A73B			;ÖØÑ¡´Ê×é
L_9E86:
		CMP	D_2BB0,0
		JZ	L_9EC0
		CMP	AH,82H			;ALT+'-'
		JNB	L_9EAB
		CMP	AH,78H			;ALT+1
		JB	L_9E9E
		MOV	AL,AH
		SUB	AL,77H
		JMP	L_9D0C			;Ñ¡ÖÐ
L_9E9E:
		CALL	S_9F66			;ÅÐALT+¿Õ¸ñ
		JNB	L_9EC0
		JMP	L_9D0C			;Ñ¡ÖÐ
L_9EAB:
		JNZ	L_9EB4
		TEST	D_963A,1		;ÅÐÇøÎ»?
		JNZ	L_9E6F
		NOT	D_959B			;ALT+'-'
		JMP	L_9D8B
L_9EB4:
		CMP	AH,83H			;ALT+'+'?
		JNZ	L_9EC0
		TEST	D_963A,1		;ÅÐÇøÎ»?
		JNZ	L_9E6F
		NOT	D_959B
		JMP	L_9DAE
;¡¾ÇøÎ»Ê×¼ü¡¿
L_9EC0:
		TEST	D_963A,1		;ÇøÎ»?
		JZ	L_9F00
		CMP	D_2BB0,5		;ÇøºÅ+¿Õ¸ñ?
		JNZ	L_9ED0
		JMP	L_QWCL
L_9ED0:
		CMP	AL,'0'                  ;ÅÐÊý×Ö
		JB	L_9EFE
		CMP	AL,'9'
		JA	L_9EFE
		MOV	SI,OFFSET D_QWXS	;'ÇøÎ»'
L_9ED8:
		CALL	S_QTXSC 		;ÇåÌáÊ¾ÐÐ²¢ÏÔÊ¾
		MOV	D_2BB1,AL
		MOV	BL,D_TUX1		;ÑÕÉ«:À¶µ×°××Ö
		CALL	S_1403A 		;ÏÔÊ¾
		MOV	D_2BB0,1
L_9EFA:
		AND	D_2BB9,0EFH		;Çå´Ê×éÖØÂëÎ»
		MOV	D_959B,0		;ÖÃÎ´Íê³ÉÌ¬
		JMP	L_9DC5
L_9EFE:
		JMP	L_9BA6			;×ª´¿ÖÐÎÄ
;¡¾µç±¨Ê×¼ü¡¿
L_9F00:
		TEST	D_963A,80H		;<µç±¨>
		JZ	L_9F08
		CMP	AL,'0'                  ;ÅÐÊý×Ö
		JB	L_9EFE
		CMP	AL,'9'
		JA	L_9EFE
		MOV	SI,OFFSET D_DBXS	;'µç±¨'
		JMP	SHORT L_9ED8
;¡¾Ê×Î²¡¢Æ´Òô¡¢Ë«Æ´¡¢Îå±ÊÊ×¼ü¡¿
L_9F08:
		CALL	S_9F61			;ÅÐCTRL+¿Õ¸ñ?		11.14
		JNB	L_9F08A
		MOV	D_2BB0,0		;¼üÈëÂëÊý=0
		OR	D_2BB9,80H		;ÖÃ±êÖ¾
		JMP	L_9DC0
L_9F08A:
		CMP	AL,'a'                  ;ÅÐÐ¡Ð´×ÖÄ¸
		JB	L_9F09
		CMP	AL,'z'
		JBE	L_9F0A
L_9F09:
		AND	D_2BB9,0B0H	       ;		       12.23
		JMP	L_9BA6
L_9F0A:
		MOV	D_959B,0FFH		;ÖÃÍê³ÉÌ¬
		MOV	D_2BB0,1		;¼üÈëÂëÊý=1
		TEST	D_963A,20H		;Îå±Ê×ÖÐÍ?
		JZ	L_9F10
		MOV	D_2BD2,0
		MOV	SI,OFFSET D_WBZX	;'Îå±Ê '
		CALL	S_QTXSC
		CALL	S_9F89
		JMP	L_9EFA
L_9F10:
		TEST	D_963A,2		;Ê×Î²?
		JZ	L_9F12
		MOV	SI,OFFSET D_SWXS	;'Ê×Î² '
		JMP	SHORT L_9F18
L_9F12:
		TEST	D_963A,4		;Æ´Òô?
		JZ	L_9F14
		MOV	SI,OFFSET D_PYXS	;'Æ´Òô '
		JMP	SHORT L_9F18
L_9F14:
		MOV	SI,OFFSET D_SPXS	;'Ë«Æ´ '
L_9F18:
		CALL	S_QTXSC 		;ÇåÌáÊ¾ÐÐ²¢ÏÔÊ¾
		AND	D_2BB9,0F6H		;ÇåÒ»¼ü¸ßÆµ¼°Ë«Æ´´Ê×éÎ»
		MOV	D_2BB0,1
		CALL	S_9F89			;Ð´Èë¼üÈëÂëÇø²¢ÏÔÊ¾
		CALL	S_9FC0			;´ÓÂë±íÊ×Îª²éÖØÂëÉèÖÃÖ¸Õë
		CALL	S_A017			;Ïò>²éÂë±í
		CALL	S_9FD9			;ÎªÕýÏòÏÂ´Î²éÖØÂëÉèÖÃÖ¸Õë
		CALL	S_A164			;ÏÔÊ¾ÖØÂë×Ö
L_9F20:
		JMP	L_9EFA			;ÇåÖØÂëÎ»²¢ÖÃÎ´Íê³ÉÌ¬

;×Ó³ÌÐò:ÇåÌáÊ¾ÐÐ²¢ÏÔÊ¾
S_QTXS1:
		PUSH	AX
		JMP	SHORT L_QT2
S_QTXS:
		PUSH	AX
		CALL	S_1400			;ÇåÌáÊ¾ÐÐ
		XOR	DL,DL			;¶¨Î»×ó¶Ë
		XOR	BH,BH
		MOV	BL,D_QTS1		;ÑÕÉ«:ºìµ×»Æ×Ö(ÏÔÊ¾·½Ê½>3)
		PUSH	DS
		XOR	AX,AX
		MOV	DS,AX
		CMP	BYTE PTR DS:[449H],4
		POP	DS
		JNB	L_QT1
		MOV	BL,D_QTS2		;ÑÕÉ«:ºìµ×ÂÌ×Ö(ÏÔÊ¾·½Ê½<4)
L_QT1:
		CALL	S_A249			;¶¨Î»ÏÔÊ¾
L_QT2:
		MOV	BP,CS
		MOV	SI,OFFSET D_QT
		MOV	BL,4EH
		MOV	DL,4CH
		MOV	AX,140AH
		INT	10H
		POP	AX
		RET

;×Ó³ÌÐò:¶¨Î»ÏÔÊ¾×Ö·û´®
S_A249:
		CALL	S_1402
;×Ó³ÌÐò:ÏÔÊ¾×Ö·û´®²¢Çå¹â±ê
S_A24C:
		CALL	S_A24A
S_A24E:
		MOV	DL,82			;8.7
		JMP	S_1402
;×Ó³ÌÐò:ÏÔÊ¾×Ö·û´®
S_A24A:
		LODSB				;È¡Ò»×Ö·û
		OR	AL,AL			;´®½áÊø·û?
		JZ	L_A24B
		CALL	S_1403A 		;ÏÔÊ¾
		JMP	SHORT S_A24A
L_A24B:
		RET

D_QT	DB	255,128,128,159,177,129,131,134,140,152,176,177,191,128,128,255
	DB	255,  0,  0,  0,128,128,  0,  0,  0,  0,  0,152,152,  0,  0,255
	DB	255,  0,  0, 48,113,240, 48, 48, 48, 48, 48, 49,252,  0,  0,255
	DB	255,  1,  1,249,141, 13, 13,121, 13, 13, 13,141,249,  1,  1,255

;×Ó³ÌÐò:²Ëµ¥¿ØÖÆ ×Ö·û´®SI,ÏîÊýCH,Ê×ÏîÎ»ÖÃCL ·µ»ØAL=Ñ¡ÖÐÏî
S_CDKZ:
		MOV	DI,SI
		CALL	S_1400			;ÇåÌáÊ¾ÐÐ
		MOV	BL,D_TUX1		;ÑÕÉ«:À¶µ×»Æ×Ö
		XOR	DL,DL			;¶¨Î»
		CALL	S_A249			;ÏÔÊ¾
		MOV	DH,1			;Ä¬ÈÏºÅ
L_CD00:
		CALL	S_A251
		CALL	S_INT16 		;¼üÈë
		CMP	AL,1BH			;ESC
		JZ	L_CD08
		CMP	AL,0DH			;»Ø³µ
		JNZ	L_CD10
		CALL	S_1404			;¹Ø±ÕÌáÊ¾ÐÐ
		MOV	AL,DH			;Ñ¡ÖÐÏîºÅ
		RET
L_CD08:
		CALL	S_1404			;¹Ø±ÕÌáÊ¾ÐÐ
		MOV	AL,1BH			;ESC
		RET
L_CD10:
		CMP	AH,4DH			;¡ú
		JNZ	L_CD20
		CALL	S_A250			;ÇåÔ­ÏÔÊ¾
		CMP	DH,CH			;ÒÑµ½×î´óºÅ?
		JZ	L_CD11
		INC	DH			;Ôö1
		JMP	SHORT L_CD00
L_CD11:
		MOV	DH,1			;ÖÃ1
		JMP	SHORT L_CD00
L_CD20:
		CMP	AH,4BH			;¡û
		JNZ	L_CD30
		CALL	S_A250			;ÇåÔ­ÏÔÊ¾
		CMP	DH,1			;ÅÐ=1?
		JZ	L_CD21
		DEC	DH			;¼õ1
		JMP	SHORT L_CD00
L_CD21:
		MOV	DH,CH			;ÖÃ×î´óºÅ
		JMP	SHORT L_CD00
L_CD30:
		CMP	AH,48H			;¡ü
		JZ	L_CD33
		CMP	AH,50H			;¡ý
		JNZ	L_CD00
L_CD33:
		MOV	AL,AH
		RET

;×Ó³ÌÐò:¶¨Î»ÏÔÊ¾×Ö·û´®SI
S_A250:
		MOV	BL,D_TUX1		;ÑÕÉ«:À¶µ×»Æ×Ö
		JMP	SHORT L_A252
S_A251:
		MOV	BL,D_QTS1		;ÑÕÉ«:ºìµ×»Æ×Ö
L_A252:
		PUSH	CX
		MOV	AL,10
		MUL	DH
		SUB	AX,10
		MOV	SI,DI
		ADD	SI,AX
		XOR	CH,CH
		ADD	SI,CX
		MOV	DL,CL
		ADD	DL,AL
		CALL	S_1402			;¶¨Î»
		MOV	CX,8
L_A253:
		LODSB				;È¡Ò»×Ö·û
		CALL	S_1403A 		;ÏÔÊ¾
		LOOP	L_A253
		CALL	S_A24E			;8.7
		POP	CX
		RET

;×Ó³ÌÐò:µ÷Ô­INT16È¡¼üÈë×Ö·û
S_INT16_1:
		MOV	AH,11H
INT16_AH1	EQU	$-1
		JMP	SHORT L_INT16_1
S_INT16:
		MOV	AH,10H
INT16_AH0	EQU	$-1
L_INT16_1:
		PUSHF
		CALL	CS:D_INT16
		RET

;×Ó³ÌÐò:ºº×ÖÊäÈëÂë¶¨Î»
S_9D7D:
		MOV	DL,4
;×Ó³ÌÐò:¼üÈë×Ö·û¶¨Î»
S_9D7F:
		ADD	DL,D_2BB0
		PUSH	AX
		CALL	S_1402			;ÌáÊ¾ÐÐ¹â±ê¶¨Î»
		POP	AX
		RET

;×Ó³ÌÐò:¶¨Î»5ÇåÌáÊ¾ÐÐ
S_9F2E:
		MOV	DL,5
;×Ó³ÌÐò:¶¨Î»ÇåÌáÊ¾ÐÐ
S_9F30:
		CALL	S_1402			;ÌáÊ¾ÐÐ¹â±ê¶¨Î»
;×Ó³ÌÐò:´ÓÖ¸¶¨Î»ÖÃ¿ªÊ¼ÇåÌáÊ¾ÐÐ
S_9F35:
		MOV	CX,76
D_9F36	EQU	$-2
		SUB	CL,DL			;´ÓÖ¸¶¨Î»ÖÃÆð×Ö½ÚÊý
		PUSH	DX
		CALL	S_1401
		POP	DX
;×Ó³ÌÐò:ÌáÊ¾ÐÐ¹â±ê¶¨Î»
S_1402:
		MOV	AX,1402H
		INT	10H
		RET
S_1401:
		MOV	DL,' '                  ;¿Õ¸ñ
S_1401A:
		MOV	BL,D_TUX1
		XOR	BH,BH
		MOV	AX,1401H
		INT	10H
		RET
S_1403K:
		PUSH	BX
		MOV	CX,1
		CALL	S_1401			;ÏÔÊ¾Ò»¸ö¿Õ¸ñ
		POP	BX
		RET

;×Ó³ÌÐò:¹Ø±ÕÌáÊ¾ÐÐ
S_1404:
		MOV	BL,10H
S_14041:
		CMP	BYTE PTR CS:[100H],12H	;ÅÐVGA?
		JB	L_1404
		TEST	BYTE PTR CS:[0F4H],2	;±£³ÖÌáÊ¾ÐÐ?
		JZ	L_1404
		JMP	S_CXTUX
L_1404:
		MOV	AX,1404H
D_1404	EQU	$-2				;³¤³Ç·½Ê½¸ÄÎª1400H
		INT	10H
		RET

;×Ó³ÌÐò:ÇåÌáÊ¾ÐÐ
S_1400:
		MOV	BL,10H
		MOV	AX,1400H
		INT	10H
		RET

;×Ó³ÌÐò:ÏÔÊ¾×Ö·ûAL
S_1403A:
		MOV	DL,AL
;×Ó³ÌÐò:ÏÔÊ¾×Ö·ûDL
S_1403:
		MOV	AX,1403H
		INT	10H
		RET

;×Ó³ÌÐò:ÅÐCTRL+¿Õ¸ñ
S_9F61:
		MOV	DL,4			;CTRL
		JMP	SHORT L_9F60
;×Ó³ÌÐò:ÅÐSHIFT+¿Õ¸ñ
S_9F62:
		MOV	DL,3			;×óÓÒSHIFT
		JMP	SHORT L_9F60
;×Ó³ÌÐò:ÅÐALT+¿Õ¸ñ
S_9F66:
		MOV	DL,8			;ALT
L_9F60:
		MOV	DI,40H
		MOV	ES,DI
		CMP	AH,39H			;¿Õ¸ñµÄÉ¨ÃèÂë?
		JNZ	L_9F77
		TEST	ES:[17H],DL		;ÅÐ×ª»»¼ü?
		JZ	L_9F77
		XOR	AL,AL
		STC				;ÊÇ
		RET
L_9F77:
		CLC				;·ñ
		RET

;×Ó³ÌÐò:Ð´Èë¼üÈëÂëÇø²¢ÏÔÊ¾
S_9F89:
		PUSH	AX
		XOR	BH,BH
		MOV	BL,D_2BB0
		MOV	D_2BB0[BX],AL		;Ð´Èë¼üÈëÂëÇø
		MOV	BL,D_TUX1		;ÑÕÉ«:À¶µ×°××Ö
		CALL	S_1403A 		;ÏÔÊ¾
		POP	AX
		RET

;×Ó³ÌÐò:´ÓÂë±íÊ×Îª²éÖØÂëÉèÖÃÖ¸Õë
S_9FC0:
		MOV	AX,D_2BD6
		MOV	D_2BAD,AX
		ADD	AX,2
L_9FCA:
		MOV	D_2BAF,AX
		RET
;×Ó³ÌÐò:ÎªÕýÏòÏÂ´Î²éÖØÂëÉèÖÃÖ¸Õë
S_9FD9:
		MOV	AX,D_2BAF
		SUB	AX,2
		MOV	D_9646,AX
		MOV	AX,D_2BAD
		JMP	SHORT L_9FCA
;×Ó³ÌÐò:ÎªÕýÏò²éÖØÂëÉèÖÃÖ¸Õë
S_9FD0:
		MOV	AX,D_2BAF
L_9FD4:
		MOV	D_2BAD,AX
		RET
;×Ó³ÌÐò:Îª·´Ïò²éÖØÂëÉèÖÃÖ¸Õë
S_A001:
		MOV	AX,D_9646
		JMP	SHORT L_9FD4
;×Ó³ÌÐò:Îª·´ÏòÏÂ´Î²éÖØÂëÉèÖÃÖ¸Õë
S_9FED:
		MOV	AX,D_9646
		ADD	AX,2
		MOV	D_2BAF,AX
		MOV	AX,D_2BAD
		MOV	D_9646,AX
		RET

D_1J		DW	OFFSET L_A28E		;Ò»¼ü
D_2J		DW	OFFSET L_A300		;¶þ¼ü
D_3J		DW	OFFSET L_A350		;Èý¼ü
D_4J		DW	OFFSET L_A390		;ËÄ¼ü
;×Ó³ÌÐò:Ïò<²éÂë±í
S_A011:
		MOV	DI,D_2BD6
		SUB	DI,2
		STD
		MOV	AL,D_2BD0
		CBW
		DEC	AX
		SHL	AX,1
		ADD	AX,OFFSET D_2BBA
		MOV	D_2BC0,AX		;ÖØÂë¿ªÊ¼Ð´ÈëµØÖ·
		JMP	SHORT L_A018
;×Ó³ÌÐò:Ïò>²éÂë±í
S_A017:
		MOV	DI,D_2BD8		;Âë±íÎ²
		MOV	D_2BC0,OFFSET D_2BBA	;ÖØÂë¿ªÊ¼Ð´ÈëµØÖ·
L_A018:
		MOV	SI,D_2BAD		;±¾´Î²é±í³õÊ¼Î»ÖÃ
		AND	D_2BB9,0DFH		;ÇåÌáÊ¾ÐÐÖØÂëÎ»
		XOR	CX,CX
		MOV	D_2BD2,CL		;ÇåÌáÊ¾ÐÐÖØÂëÊý
		MOV	D_9597,CX		;ÇåÖØÂë¼ÆÊýÆ÷
		MOV	D_2CC0,CL		;ÇåÆ´Òô¼òÂë±êÖ¾
		PUSH	CS
		POP	ES
		MOV	BL,D_2BB0
		TEST	D_963A,4		;ÅÐÆ´Òô?
		JNZ	L_A01B
		CMP	BL,4			;9.27
		JBE	L_A01A
		JMP	L_9DC0
L_A01A:
		XOR	BH,BH
		SHL	BX,1
		JMP	D_1J-2[BX]		;Ò»~ËÄ¼ü´¦Àí
L_A01B:
		CALL	S_A010			;Æ´ÒôÂëÔ¤´¦Àí
		OR	BP,BP
		JZ	L_A01C
		CMP	BP,1
		JNZ	L_A01BB
		JMP	L_A28F			;Ò»¼ü´¦Àí
L_A01BB:
		MOV	D_2A,BX 		;±£´æ×ª»»Ë«Æ´Âë
		JMP	L_A301			;¶þ¼ü´¦Àí
L_A01C:
		CMP	D_2A,0
K_PYCZ	EQU	$
		JZ	L_A01D
		MOV	AX,D_2A
		MOV	WORD PTR D_2CC1,AX	;
		MOV	AL,D_2B
		CMP	AL,'`'
		JZ	L_A01D
		MOV	D_2CC1+2,AL		;µÚ¶þ×ÖÉùÄ¸
		MOV	D_2CC1+3,'?'
		MOV	D_2A,0
		XOR	DX,DX			;DH:ÌáÊ¾ÐÐ
		MOV	D_9597,DX		;ÖØÂë¼ÆÊý
		MOV	D_2BD2,DH
		MOV	D_966C,3		;=3Ë«Æ´´Ê×é
		OR	D_2BB9,8		;Ë«Æ´´Ê×é
		CMP	D_SPCZ,0		;ÅÐÊÇ·ñ°²×°Ë«Æ´´Ê×é?
		JZ	L_A01F
		CALL	S_A9000 		;²éË«Æ´´Ê×é
		JMP	L_A610
L_A01D:
		CMP	D_2BB0,3
		JBE	L_A01F
		CMP	D_2BB0,5
		JA	L_A01F
		JMP	L_A390			;Ë«Æ´ËÄ¼ü´¦Àí
L_A01F:
		RET

D_2A		DW	0			;±£´æ×ª»»µÄË«Æ´Âë
D_2B		DB	0			;Ä©¼ü

;¡¾Æ´ÒôÂëÔ¤´¦Àí¡¿½«2BB1Çø¿½±´µ½2CC1Çø,·µ»Ø:BP=²éÑ¯¼üÊý,²éÑ¯¼üÂë:BL,BH,DL
S_A010:
		MOV	AH,BL			;¼üÊý
		MOV	BP,OFFSET D_2BB1
L_A012:
		MOV	AL,CS:[BP]		;½«¼üÈëÂë´Ó2BB1Çø¿½±´µ½2CC1Çø
		MOV	CS:[BP+10],AL
		INC	BP
		DEC	AH
		JNZ	L_A012
		MOV	D_2B,AL 		;Ä©¼ü
		MOV	DH,AL

		CMP	BL,1			;<Ò»¼ü>?
		JNZ	L_A020
		MOV	BL,AL
		MOV	BP,1			;Ò»¼ü´¦Àí
		RET
L_A020:
		MOV	AX,WORD PTR D_2CC1
		CMP	BL,2			;<¶þ¼ü>?
		JNZ	L_A030
		MOV	BX,AX
		JMP	L_A061
L_A030:
		MOV	BP,OFFSET D_3JB0	;Ë«ÉùÄ¸¼ü±í
L_A031:
		CMP	BYTE PTR CS:[BP],0
		JZ	L_A034
		CMP	AX,CS:[BP]
		JZ	L_A032
		ADD	BP,3
		JMP	SHORT L_A031
L_A032:
		MOV	AL,CS:[BP+2]		;viuÈý¼ü
		MOV	D_2CC1,AL
		MOV	AH,D_2BB0
		SUB	AH,2			;ÔÏÄ¸³¤
		MOV	BP,OFFSET D_2CC1+2	;ÔÏÄ¸Ê×Ö·
L_A033:
		MOV	AL,CS:[BP]
		MOV	CS:[BP-1],AL
		INC	BP
		DEC	AH
		JNZ	L_A033
		DEC	BL			;¼üÊý-1
		MOV	D_2CC0,0FFH		;ÖÃÆ´Òô¼òÂë±êÖ¾
		JMP	SHORT L_A020		;¶þ¼ü´¦Àí
L_A034:
		MOV	AX,WORD PTR D_2CC1+1	;Ö¸ÏòÔÏÄ¸

		CMP	BL,3			;<Èý¼ü>?
		JNZ	L_A040
		CMP	BYTE PTR D_2CC1,'a'
		JNZ	L_A036
		CMP	WORD PTR D_2CC1+1,'gn'
		JNZ	L_A035
		MOV	BX,'ga'
		JMP	L_A060			;¶þ¼ü´¦Àí
L_A035:
		XOR	BP,BP
		RET
L_A036:
		CMP	DH,"'"                  ;¸ôÒô·ûºÅ?              2.3
		JNZ	L_A036A
		MOV	BX,WORD PTR D_2CC1
		JMP	L_A061
L_A036A:
		MOV	DL,D_2CC1
		MOV	BX,OFFSET D_3JB
L_A037:
		CMP	BYTE PTR [BX],0
		JZ	L_A035
		CMP	AX,[BX]
		JZ	L_A038
		ADD	BX,3
		JMP	SHORT L_A037
L_A038:
		MOV	BH,[BX+2]
		MOV	BL,DL
L_A039:
		JMP	L_A060			;¶þ¼ü´¦Àí
L_A040:
		CMP	BL,4			;<ËÄ¼ü>?
		JNZ	L_A050
		CMP	DH,"'"                  ;¸ôÒô·ûºÅ?              2.3
		JZ	L_A036A
L_A040A:
		MOV	DL,D_2CC1+3
		MOV	BX,OFFSET D_4JB
L_A041:
		CMP	BYTE PTR DS:[BX],0
		JZ	L_A044
		CMP	AX,[BX]
		JNZ	L_A042
		CMP	DL,[BX+2]
		JZ	L_A043
L_A042:
		ADD	BX,4
		JMP	SHORT L_A041
L_A043:
		MOV	BH,[BX+3]
		MOV	BL,D_2CC1
		JMP	SHORT L_A060		;¶þ¼ü´¦Àí
L_A044:
		XOR	BP,BP
		RET
L_A048:
		CMP	BL,6			;<Áù¼ü>?		2.3
		JNZ	L_A044
		CMP	DH,"'"                  ;¸ôÒô·ûºÅ               2.3
		JZ	L_A050A
		JMP	SHORT L_A044
L_A050:
		CMP	BL,5			;<Îå¼ü>?
		JNZ	L_A048
		CMP	DH,"'"                  ;¸ôÒô·ûºÅ               2.3
		JZ	L_A040A
L_A050A:
		MOV	DX,WORD PTR D_2CC1+3
		MOV	BX,OFFSET D_5JB
L_A051:
		CMP	BYTE PTR DS:[BX],0
		JZ	L_A044
		CMP	AX,[BX]
		JNZ	L_A052
		CMP	DX,[BX+2]
		JZ	L_A053
L_A052:
		ADD	BX,5
		JMP	SHORT L_A051
L_A053:
		MOV	BH,[BX+4]
		MOV	BL,D_2CC1
L_A060:
		MOV	D_2CC0,0FFH		;ÖÃÆ´Òô¼òÂë±êÖ¾
L_A061:
		CALL	S_A080
		MOV	BP,2			;¶þ¼ü´¦Àí
		RET

;×Ó³ÌÐò:ÏÔÊ¾²éÑ¯Âë
S_A080:
		PUSH	DX
		MOV	DL,13
		CALL	S_1402
		MOV	DL,BL
		CALL	S_14030
		MOV	DL,BH
		CALL	S_14030
		POP	DX
		RET
S_14030:
		PUSH	BX
		MOV	BX,1DH				;2.12
		CALL	S_1403
		POP	BX
		RET

D_3JB0		DB	'zhv', 'chi', 'shu', 0         ;Ë«ÉùÄ¸¼ü±í
D_3JB		DB	'ail', 'anj', 'aok', 'eid', 'enf', 'ons', 'oup'
		DB	'iar', 'iet', 'ihx', 'ijb', 'ikm', 'inn', 'ios'
		DB	'iuq', 'iss', 'uaw', 'uew', 'uhx', 'uiv', 'ujz'
		DB	'uly', 'unc', 'uoo', 'vew', 0  ;Èý¼ü±í
D_4JB		DB	'angh', 'engg', 'ongs'
		DB	'ianb', 'iaom', 'ingy', 'ions'
		DB	'uaiy', 'uanz', 0              ;ËÄ¼ü±í
D_5JB		DB	'iangx', 'iongs', 'uangx', 0   ;Îå¼ü±í

;¡¾Ò»¼ü´¦Àí¡¿
L_A28E:
		MOV	BL,D_2BB1		;È¡Ò»²éÑ¯Âë
L_A28F:
		TEST	D_963A,2		;ÅÐÊ×Î²?
		JNZ	L_A290
		TEST	D_2BB9,1		;Ò»¼ü¸ßÆµ?
		JNZ	L_A290
		MOV	SI,D_2BD6		;Æ´ÒôÂë±íÊ×
		SUB	SI,11*26*2		;ÒÆÒ»¼ü×Ö±íÊ×
		MOV	DI,OFFSET D_2BBA	;ÖØÂëÇøÊ×
		MOV	AL,BL
		AND	AL,1FH			;±äÎª1~26
		CBW
		DEC	AX			;0~25
		MOV	CX,22			;Ã¿¼ü11×Ö
		MUL	CX
		ADD	SI,AX			;¸ßÆµ±í¸Ã×ÖÄ¸Ïî
		REP	MOVSB			;Ð´ÈëÖØÂëÇø
		MOV	D_2BD2,11		;ÖØÂëÊý
		OR	D_2BB9,1		;ÖÃÒ»¼ü¸ßÆµÎ»
		RET
L_A290:
		AND	BL,1FH			;×ª»»
L_A295:
		CMP	SI,DI			;²éÍê?
		JZ	L_A2AF
		MOV	AL,[SI] 		;È¡Ê×Î²±íÏî
		AND	AL,1FH			;È¡³öÒ»¼üÂë
		CMP	AL,BL			;ÅÐ
		JZ	L_A2C7
L_A2AB:
		LODSW				;×ªÏÂÒ»±íÏî
		JMP	SHORT L_A295
L_A2AF:
		OR	CX,CX			;ÖØÂëÊý=0?
		JZ	L_A2C1
		MOV	D_9597,CX		;´æ
		CMP	CX,11			;>11?
		JA	L_A2C1
		MOV	D_2BAD,DI		;´æÏÂ´Î²é±íÖ¸Õë
L_A2C1:
		CLD
		RET
L_A2C7:
		CALL	S_A2D9			;ÖØÂë´¦Àí
		JMP	SHORT L_A2AB
;×Ó³ÌÐò:ÖØÂë´¦Àí
S_A2D9:
		CALL	S_A257			;×ª»»Îªºº×ÖÄÚÂë²¢Ð´ÈëÖØÂëÇø
		JB	L_A2EE
		TEST	D_2BB9,20H		;ÌáÊ¾ÐÐÖØÂëÎ»?
		JNZ	L_A2EE
		MOV	D_2BAD,SI		;´æÏÂ´Î²é±íÖ¸Õë
		OR	D_2BB9,20H		;ÖÃÌáÊ¾ÐÐÖØÂëÎ»
L_A2EE:
		INC	CX			;ÖØÂëÊý+1
		RET
;¡¾¶þ¼ü´¦Àí¡¿
L_A300:
		MOV	BX,WORD PTR D_2BB1	;È¡Ç°¶þ²éÑ¯Âë
L_A301:
		AND	BX,1F1FH		;×ª»»
		MOV	AH,BH
		XOR	AL,AL
		SHR	AX,1
		SHR	AX,1
		SHR	AX,1
		MOV	BH,AH
		OR	BL,AL
L_A31F:
		CMP	SI,DI			;²éÍê?
		JZ	L_A338
		MOV	AX,[SI] 		;È¡±íÏî
		AND	AX,3FFH 		;È¡10Î»
		CMP	AX,BX			;ÅÐ
		JZ	L_A33A
L_A336:
		LODSW				;×ªÏÂÒ»±íÏî
		JMP	SHORT L_A31F
L_A338:
		JMP	L_A2AF
L_A33A:
		TEST	D_963A,2		;ÅÐÊ×Î²
		JNZ	L_A33C
		TEST	D_2BB9,2		;¶þ¼ü¸ßÆµ?
		JNZ	L_A33C
		TEST	BYTE PTR DS:[SI+1],80H
		JZ	L_A336
L_A33C:
		CALL	S_A2D9			;ÖØÂë´¦Àí
		JMP	SHORT L_A336
;¡¾Èý¼ü´¦Àí¡¿
L_A350:
		MOV	BX,WORD PTR D_2BB1	;È¡Ç°¶þ²éÑ¯Âë
		MOV	DL,D_2BB1+2		;È¡µÚÈý²éÑ¯Âë
L_A351:
		AND	BX,1F1FH		;×ª»»
		MOV	AH,BH
		XOR	AL,AL
		SHR	AX,1
		SHR	AX,1
		SHR	AX,1
		MOV	BH,AH
		OR	BL,AL
		AND	DL,1FH			;×ª»»
		SHL	DL,1
		SHL	DL,1
		OR	BH,DL
L_A361:
		CMP	SI,DI			;²éÍê?
		JZ	L_A38B
		MOV	AX,[SI] 		;È¡±íÏî
		AND	AX,7FFFH
L_A383:
		CMP	AX,BX			;ÅÐ
		JZ	L_A38E
L_A387:
		LODSW				;×ªÏÂÒ»±íÏî
		JMP	SHORT L_A361
L_A38B:
		JMP	L_A2AF			;²éÍê´¦Àí
L_A38E:
		CALL	S_A2D9			;ÖØÂë´¦Àí
		JMP	SHORT L_A387
;¡¾ËÄ¼ü´¦Àí¡¿
L_A390:
		XOR	DX,DX			;DH:ÌáÊ¾ÐÐ
		MOV	D_9597,DX		;ÖØÂë¼ÆÊý
		MOV	D_2BD2,DH
		CMP	D_SPCZ,0		;ÅÐÊÇ·ñ°²×°Ë«Æ´´Ê×é?
		JZ	L_A391
		MOV	D_966C,3
		OR	D_2BB9,8		;Ë«Æ´´Ê×é
		CALL	S_A900
		JMP	L_A610
L_A391:
		RET

;×Ó³ÌÐò:ÏÔÊ¾ÖØÂë×Ö
S_A164:
		MOV	DL,10H			;¶¨Î»
		CALL	S_9F30			;¶¨Î»ÇåÌáÊ¾ÐÐ
L_A172:
		MOV	DL,'0'
S_A180:
		MOV	CX,11
		CMP	CX,D_9597		;ÖØÂë¼ÆÊý>11?
		JNB	L_A185
		SUB	D_9597,CX		;ÖØÂë¼ÆÊý-11
		JMP	SHORT L_A189
L_A185:
		MOV	D_9597,0		;ÇåÖØÂë¼ÆÊý
L_A189:
		MOV	CL,D_2BD2		;ÌáÊ¾ÐÐÖØÂëÊý
		OR	CL,CL			;=0?
		JNZ	L_A19D
		TEST	D_963A,8		;ÅÐË«Æ´?
		JNZ	L_A190
S_BEEP:
		MOV	DL,7
K_CMTS	EQU	$-1
		CALL	S_1403			;ÏìÁå,ÍË³ö
L_A190:
		RET
L_A19D:
		MOV	SI,OFFSET D_2BBC
		CMP	DL,'0'
		JNZ	L_A1A2
		MOV	SI,OFFSET D_2BBA	;ÖØÂëÇøÖ¸Õë
		PUSH	DX
		JMP	SHORT L_A1A6
L_A1A2:
		PUSH	DX
		MOV	BL,D_TUX2		;ÑÕÉ«:À¶µ×ÂÌ×Ö
		CALL	S_1403			;ÏÔÊ¾ÐòºÅ
L_A1A6:
		TEST	D_963A,8		;ÅÐË«Æ´?
		JNZ	L_A1A7
L_A1A7A:
		MOV	DL,':'
		CALL	S_1403			;ÏÔÊ¾':'
L_A1A7:
		MOV	BL,D_TUX1		;ÑÕÉ«:À¶µ×»Æ×Ö
		LODSB
		CALL	S_1403A 		;ÏÔÊ¾Ç°×Ö½Ú
		LODSB
		CALL	S_1403A 		;ÏÔÊ¾ºó×Ö½Ú
		TEST	D_963A,8		;ÅÐË«Æ´?
		JZ	L_A1B0
		MOV	AX,[SI-2]		;È¡ºº×ÖÄÚÂë
		CMP	D_2BB0,1		;Ò»¼ü?
		JNZ	L_A1A8
		CALL	S_A9A0			;È¡Ë«Æ´Âë
		MOV	AL,AH
		JMP	SHORT L_A1A9
L_A1A8:
		CMP	D_2BB0,2		;¶þ¼ü?
		JNZ	L_A1B0
		CALL	S_A9B8			;È¡²¿Ê×Âë
L_A1A9:
		CALL	S_1403A
L_A1B0:
		MOV	DL,' '
		CALL	S_1403			;ÏÔÊ¾¿Õ¸ñ
		POP	DX
		INC	DL			;ÐòºÅ¼ÓÒ»
		CMP	DL,3AH			;µÚ10ºÅ
		JNZ	L_A1C8
		MOV	DL,'0'                  ;ÖÃ'0'
L_A1C8:
		LOOP	L_A1A2
		MOV	DL,8
		CALL	S_1403			;ÍË¸ñ
;×Ó³ÌÐò:ÏÔÊ¾Ê£ÓàÖØÂëÊý
S_A1CC:
		MOV	AX,D_9597		;Ê£ÓàÖØÂëÊý
		MOV	SI,OFFSET D_A1D8+3	;¸öÎ»
		MOV	CX,30AH
L_A1D0:
		DIV	CL			;³ýÒÔ10
		OR	AH,'0'
		MOV	[SI],AH 		;Ð´Èë
		XOR	AH,AH
		DEC	SI
		DEC	CH
		JNZ	L_A1D0
L_A1D1:
		MOV	BL,D_TUX2		;ÑÕÉ«:À¶µ×ÂÌ×Ö
		JMP	S_A24C			;ÏÔÊ¾×Ö·û´®
D_A1D8		DB	'[000]',0

;×Ó³ÌÐò:×ª»»²éµ½µØÖ·Îªºº×ÖÄÚÂë²¢Ð´ÈëÖØÂëÇø
S_A257:
		PUSH	DI
		MOV	AL,D_2BD2		;ÌáÊ¾ÐÐÖØÂëÊý
		CMP	AL,D_2BD0		;>=11
		JNB	L_A289
		MOV	AX,SI			;²éµ½µØÖ·
		SUB	AX,D_2BD6		;¼õÂë±íÊ×Ö·
		SHR	AX,1			;³ýÒÔ2µÃºº×ÖÐòºÅ
		MOV	DL,5EH			;=94
		DIV	DL			;³ýÒÔ94
		ADD	AX,0A1B0H		;µÃºº×ÖÄÚÂë
		MOV	DI,D_2BC0
		STOSW				;Ð´ÈëÖØÂëÇø
		MOV	D_2BC0,DI
		INC	D_2BD2			;ÌáÊ¾ÐÐÖØÂëÊý+1
		STC
L_A289:
		POP	DI
		RET

;¡¾Ô¤Ñ¡´¦Àí¡¿
L_A4F0:
		CMP	AL,'['                  ;<
		JNZ	L_A512
		CMP	D_YXH,1 		;µÚÒ»ÐÐ?
		JZ	L_A50D
		DEC	D_YXH			;ÐÐºÅ-1
		SUB	D_YX,36H		;µ±Ç°ÐÐµØÖ·-54
		JMP	L_YX1			;ÏÔÊ¾
L_A50D:
		JMP	L_9DC0			;ÏìÁå²¢·µ»Ø
L_A512:
		CMP	AL,']'                  ;>
		JNZ	L_A52C
		MOV	SI,D_YX 		;µ±Ç°ÐÐµØÖ·
		CMP	BYTE PTR [SI+36H],'$'   ;ÐÐÎ²Îª'$'?
		JZ	L_A50D
		INC	D_YXH			;ÐÐºÅ+1
		ADD	D_YX,36H		;µ±Ç°ÐÐµØÖ·+54
		JMP	L_YX1			;ÏÔÊ¾
L_A52C:
		CMP	AL,'A'                  ;ÅÐ´óÐ´×ÖÄ¸
		JNB	L_A535
L_A530:
		TEST	D_963A,3EH		;ÅÐÔ­ÎªÊ×Î²,Æ´Òô,Ë«Æ´,Îå±Ê,´Ê×é?
		JNZ	L_A532
L_A531:
		JMP	L_9BA6			;Ö±½ÓÊä³ö
L_A532:
		CMP	AL,'a'                  ;ÅÐÐ¡Ð´×ÖÄ¸
		JB	L_A531
		CMP	AL,'z'
		JA	L_A531
		AND	D_2BB9,0BFH		;ÇåÔ¤Ñ¡Î»
		JMP	L_9C90			;×ªÔ­ÊäÈë·½Ê½´¦Àí
L_A535:
		CMP	AL,'Z'
		JA	L_A530
		SUB	AL,'A'                  ;µÃÐòºÅ
		XOR	AH,AH
		SHL	AX,1			;µÃÏà¶ÔµØÖ·
		ADD	AX,D_YX 		;¼Óµ±Ç°ÐÐµØÖ·
		MOV	SI,AX			;Ñ¡ÖÐ×ÖµØÖ·
		LODSW				;È¡×Ö
		MOV	WORD PTR D_959D,AX	;Ð´Èë·µ»ØÂëÇø
;¡¾ÁªÏë´¦Àí¡¿
L_A559:
		MOV	D_95D5,2		;·µ»ØÂë¼ÆÊý=2
		MOV	D_95D6,2		;±£´æ..
		MOV	D_959B,0FFH		;ÖÃÍê³ÉÌ¬
		MOV	AX,WORD PTR D_959D	;È¡·µ»Øºº×Ö
		MOV	BP,AX

		TEST	D_9639,1		;ÅÐÁªÏë¿ª¹Ø×´Ì¬
		JZ	L_A58F			;¹ØÔò×ª
		CMP	D_9686,0		;ÁªÏë¿â¶Î=0?
		JZ	L_A58F
L_A574:
		CMP	AL,0B0H 		;ÅÐºº×Ö?
		JB	L_A58F
		AND	AX,7F7FH		;È¥¸ßÎ»
		MOV	WORD PTR D_2BB1,AX	;×÷Îª¼üÈëÂë
		MOV	D_2BB0,2		;¼üÈëÂë¼ÆÊý=2
		MOV	D_966C,1		;ÁªÏë
		MOV	D_966D,0FFH		;ÁªÏë±êÖ¾
		MOV	SI,OFFSET D_9A60	;'ÁªÏë'
		JMP	L_A5DF			;´Ê´¦Àí
D_9A60		DB	'ÁªÏë ',0

L_A58F:
		CMP	D_963B,0FFH		;ÅÐ×Öµä·½Ê½?
		JZ	L_A591
L_A590:
		RET
L_A591:
		CALL	S_1400
		MOV	SI,OFFSET D_QWXS	;'ÇøÎ»'
		MOV	BL,D_QTS2
		CALL	S_A24A
		MOV	AX,BP			;È¡·µ»Øºº×Ö
		CALL	S_9E50			;ÏÔÊ¾¶þÎ»Êý×Ö
		MOV	AX,BP
		MOV	AL,AH
		CALL	S_9E50
		MOV	DL,' '
		CALL	S_1403

		CMP	BYTE PTR D_959D,0B0H	;ÅÐºº×Ö?
		JB	L_A590

		MOV	DI,D_SW
		OR	DI,DI			;ÅÐ°²×°Ê×Î²?
		JZ	L_A594
		MOV	SI,OFFSET D_SWXS	;'Ê×Î²'
		MOV	BL,D_QTS2
		CALL	S_A24A
		CALL	S_XSSW
L_A594:
		MOV	DI,D_PY
		OR	DI,DI			;ÅÐ°²×°Æ´Òô?
		JZ	L_A595
		MOV	SI,OFFSET D_PYXS	;'Æ´Òô'
		MOV	BL,D_QTS2
		CALL	S_A24A
		CALL	S_XSPY
L_A595:
		MOV	DX,D_INTWB+2
		OR	DX,DX			;ÅÐ°²×°Îå±Ê?
		JNZ	L_A595A
		JMP	L_A596
L_A595A:
		MOV	ES,DX
		MOV	SI,OFFSET D_WBZX	;
		CMP	BYTE PTR [SI],80H
		JNB	L_A595B
		NOT	WORD PTR [SI]
		NOT	WORD PTR [SI+2]
L_A595B:
		MOV	BL,D_QTS2
		CALL	S_A24A
		MOV	BL,D_TUX2
		MOV	AX,BP			;È¡·µ»Øºº×Ö
		AND	AX,7F7FH
		SUB	AX,2130H
		MOV	DX,AX
		MOV	AL,94
		MUL	DL
		MOV	DL,DH
		XOR	DH,DH
		ADD	AX,DX			;ºº×ÖÐòºÅ
		MOV	DX,AX
		SHL	AX,1
		ADD	AX,DX			;AX*3
		ADD	AX,0BDH 		;Îå±ÊÄ£¿éÂë±íµØÖ·
		MOV	SI,AX
		MOV	AL,ES:[SI]
		MOV	CL,3
		SHR	AL,CL
		OR	AL,60H
		CALL	S_1403A
		MOV	AX,ES:[SI]
		XCHG	AH,AL
		AND	AH,7
		SHL	AL,1
		SHL	AL,1
		SHL	AX,1
		SHL	AX,1
		MOV	AL,AH
		OR	AL,60H
		CALL	S_1403A
		MOV	AX,ES:[SI+1]
		XCHG	AH,AL
		AND	AH,0FH
		SHL	AL,1
		SHL	AL,1
		SHL	AX,1
		MOV	AL,AH
		OR	AL,60H
		CALL	S_1403A
		MOV	AL,ES:[SI+2]
		AND	AL,1FH
		OR	AL,60H
		CALL	S_1403A
		MOV	DL,' '
		CALL	S_1403
L_A596:
		MOV	DI,D_DB 		;ÅÐ°²×°µç±¨?
		MOV	CX,DI
		ADD	CX,20000
		OR	DI,DI
		JZ	L_A599
		MOV	SI,OFFSET D_DBXS
		MOV	BL,D_QTS2
		CALL	S_A24A
		MOV	DX,BP			;È¡·µ»Øºº×Ö
L_A597:
		ADD	DI,2
		MOV	AX,[DI]
		CMP	AX,DX
		JNZ	L_A598
		MOV	AX,DI
		SUB	AX,D_DB
		SHR	AX,1
		MOV	DL,100
		DIV	DL
		PUSH	AX
		CALL	S_9E51
		POP	AX
		MOV	AL,AH
		JMP	S_9E51
L_A598:
		CMP	DI,CX
		JBE	L_A597
L_A599:
		RET

D_WBCZ		DB	'´Ê×é:',0
;¡¾´Ê×é´¦Àí¡¿
L_A5D7:
		MOV	SI,OFFSET D_WBCZ	;'´Ê×é:'
		MOV	D_966C,0		;Íâ²¿´Ê×é
L_A5DF:
		CALL	S_QTXS			;ÇåÌáÊ¾ÐÐ²¢ÏÔÊ¾
		MOV	SI,OFFSET D_2BB1	;¼üÈëÂëÇøÊ×
		MOV	CL,D_2BB0		;¼üÈëÂë¼ÆÊý
		XOR	CH,CH
		MOV	BL,D_TUX1		;ÑÕÉ«:À¶µ×°××Ö
L_A5F0:
		LODSB				;È¡´Ê×éÍâÂë
		CMP	D_966C,1		;ÅÐÁªÏë?
		JNZ	L_A5F8
		OR	AL,80H
L_A5F8:
		CALL	S_1403A 		;ÏÔÊ¾´Ê×éÍâÂë
		LOOP	L_A5F0
L_A5FA:
		MOV	SI,OFFSET D_9680	;´Ê´¦Àí²ÎÊý±íÊ×Ö·
		MOV	AL,6			;Ã¿ÖÖ6×Ö½Ú
		MUL	D_966C			;³Ë´Ê´¦Àí·½Ê½ºÅ
		ADD	SI,AX			;Ö¸¶¨´Ê´¦Àí²ÎÊýÊ×
		LODSW				;´Ê±í¶Î
		OR	AX,AX
		JNZ	L_A5FC
		JMP	L_9DC0
L_A5FC:
		MOV	D_2B98,AX
		LODSW				;´Ê±íÍâÂëÇøÊ×
		MOV	D_2BA2,AX
		LODSW				;´Ê±íÄÚÂëÇøÊ×
		MOV	D_2BA0,AX
		MOV	D_2B9A,AX
		MOV	SI,D_2BA2		;´Ê±íÍâÂëÇøÊ×
		CALL	S_A809			;SIÖ¸ÕëÏÂ´Ê³¤
		ADD	AX,D_2B9A		;ÏÂÒ»´ÊÔÚÄÚÂëÇøµØÖ·
		MOV	D_2B9E,AX		;´æ
		MOV	AX,D_2BA2
		MOV	D_2BAD,AX
		INC	AX
		MOV	D_2BAF,AX
L_A600:
		MOV	D_2BA5,0		;²é´Ê±í·½Ïò:ÕýÏò
		MOV	DI,D_2BA0		;ÄÚÂëÇøÊ×Ö¸Õë
		CALL	S_A85A			;²é´Ê±í
		CALL	S_A816			;ÎªÏÂ´Î²é±íÉèÖ¸Õë
L_A610:
		TEST	D_2BB9,8		;ÅÐË«Æ´´Ê×é?
		JZ	L_A618
		CMP	D_2BD2,1		;ÅÐÖØÂëÊý=1?
		JNZ	L_A616
		MOV	DL,13
		CALL	S_9F30			;¶¨Î»ÇåÌáÊ¾ÐÐ
		XOR	AL,AL
		JMP	SHORT L_A634		;Ö±½ÓÑ¡ÖÐ
L_A616:
		CALL	S_BEEP
		CMP	D_2BD2,0
		JZ	L_A627
L_A618:
		OR	D_2BB9,10H		;´Ê×éÖØÂë±êÖ¾
		MOV	D_959B,0		;ÖÃÎ´Íê³ÉÌ¬
		CALL	S_A694			;ÏÔÊ¾ÖØÂë´Ê
		CMP	D_966D,0FFH		;ÁªÏë±êÖ¾?
		JZ	L_A627
		JMP	L_9DC5
L_A627:
		RET

;¡¾´Ê×éÑ¡ÖÐ´¦Àí¡¿
L_A634:
		MOV	D_959B,0FFH		;ÖÃÍê³ÉÌ¬
		MOV	BL,4
		MUL	BL
		MOV	BX,AX			;Ñ¡ÖÐ´ÊÔÚ´ÊÖØÂëÇøÎ»ÖÃ
		MOV	AX,D_9648[BX]		;È¡µØÖ·
		MOV	D_9669,AX		;Ñ¡ÖÐ´ÊÄÚÂëµØÖ·
		MOV	AX,WORD PTR D_964A[BX]	;È¡´Ê³¤
		MOV	D_966B,AL		;Ñ¡ÖÐ´Ê³¤
		MOV	D_2BD4,AH		;¶þ×Ö´ÊÆ«ÒÆ
						;Ô­A701
		MOV	CL,D_966B		;Ñ¡ÖÐ´Ê³¤
		MOV	D_95D5,CL		;·µ»ØÂë¼ÆÊý
		XOR	CH,CH

		MOV	SI,D_9669		;Ñ¡ÖÐ´ÊÄÚÂëÖ¸Õë
		MOV	DS,D_2B98		;DS=´Ê±í¶Î
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_959D	;·µ»ØÂëÇøÊ×
		CMP	CS:D_2BD4,0		;ÅÐ¶þ×Ö´ÊÆ«ÒÆ?
		JZ	L_A650
L_A640:
		LODSW				;´«ËÍµÚÒ»×Ö
		OR	AX,8080H
		STOSW
		TEST	CS:D_2BB9,80H		;¶þ×Ö´Êµþ×Ö?
		JZ	L_A642
		MOV	AX,[SI-2]
		STOSW
L_A642:
		MOV	AL,CS:D_2BD4
		CBW
		MOV	CS:D_2BD4,AH		;Çå0
		ADD	SI,AX			;¼ÓÆ«ÒÆ
		MOVSW				;´«ËÍµÚ¶þ×Ö
		TEST	CS:D_2BB9,80H		;¶þ×Ö´Êµþ×Ö?		11.11
		JZ	L_A660
		MOV	AX,[SI-2]
		STOSW
		ADD	CS:D_95D5,4
		JMP	SHORT L_A660
L_A650:
		TEST	CS:D_2BB9,80H		;¶þ×Ö´Êµþ×Ö?		11.11
		JZ	L_A654
		CMP	CL,4			;ÅÐ¶þ×Ö´Ê?
		JZ	L_A640
L_A654:
		REP	MOVSB
L_A660:
		PUSH	CS
		POP	DS
		TEST	D_2BB9,8		;ÅÐË«Æ´´Ê×é?
		JZ	L_A664
		MOV	CL,4
		MOV	DI,OFFSET D_959D
L_A662:
		OR	BYTE PTR DS:[DI],80H	;¸ßÎ»ÖÃ1		11.11
		INC	DI
		LOOP	L_A662
L_A664:
		MOV	AL,D_95D5		;±£´æ			11.15
		MOV	D_95D6,AL
		AND	D_2BB9,7FH		;Çå±êÖ¾ 		11.11
		RET

;×Ó³ÌÐò:ÏÔÊ¾ÖØÂë´Ê
S_A694:
		MOV	DL,16
		CALL	S_9F30			;¶¨Î»ÇåÌáÊ¾ÐÐ
		MOV	DL,D_2BD2		;ÌáÊ¾ÐÐÖØÂëÊý
		OR	DL,DL			;=0?
		JNZ	L_A6A0
	;	AND	D_2BB9,0F7H		;ÇåË«Æ´´Ê×éÎ»
		RET
L_A6A0:
		XOR	DH,DH
		SUB	D_9597,DX		;Ê£ÓàÖØÂëÊý
		CALL	S_A1CC			;ÏÔÊ¾Ê£ÓàÖØÂëÊý
		MOV	DL,21
		CALL	S_1402
		MOV	DL,'0'                  ;ÐòºÅ
		MOV	CL,D_2BD2		;ÌáÊ¾ÐÐÖØÂëÊý
		PUSH	DX
		JMP	SHORT L_A6BC
L_A6B8:
		PUSH	DX
		MOV	BL,D_TUX1		;ÑÕÉ«:À¶µ×»Æ×Ö
		CALL	S_1403			;ÏÔÊ¾ÐòºÅ
L_A6BC:
		MOV	BL,D_2BD2
		SUB	BL,CL
		MOV	AL,4
		MUL	BL
		MOV	BX,AX
		MOV	SI,D_9648[BX]		;ÄÚÂëÇøÊ×
		PUSH	CX
		MOV	CX,WORD PTR D_964A[BX]	;´Ê³¤
		MOV	BL,D_TUX2		;ÑÕÉ«:À¶µ×ÂÌ×Ö
		MOV	DS,D_2B98		;´Ê±í¶Î
		OR	CH,CH			;ÅÐ¶þ×Ö´ÊÆ«ÒÆ?
		JZ	L_A6DB
		LODSB				;È¡Ò»×Ö½Ú
		OR	AL,80H
		CALL	S_1403A 		;ÏÔÊ¾
		LODSB				;È¡Ò»×Ö½Ú
		OR	AL,80H
		CALL	S_1403A 		;ÏÔÊ¾
		MOV	AL,CH
		XOR	AH,AH
		ADD	SI,AX			;¼ÓÆ«ÒÆ
		LODSB				;È¡Ò»×Ö½Ú
		CALL	S_1403A 		;ÏÔÊ¾
		LODSB				;È¡Ò»×Ö½Ú
		CALL	S_1403A 		;ÏÔÊ¾
		JMP	SHORT L_A6E0
L_A6DB:
		TEST	CS:D_2BB9,8		;ÅÐË«Æ´´Ê×é?
		JZ	L_A6DE
L_A6DC:
		LODSB				;È¡Ò»×Ö½Ú		3.15
		OR	AL,80H
		CALL	S_1403A 		;ÏÔÊ¾
		LODSB				;È¡Ò»×Ö½Ú
		OR	AL,80H
		CALL	S_1403A 		;ÏÔÊ¾
		SUB	CX,2
L_A6DE:
		LODSB				;È¡Ò»×Ö½Ú
		CALL	S_1403A 		;ÏÔÊ¾
		LOOP	L_A6DE
L_A6E0:
		MOV	DL,' '
		CALL	S_1403			;ÏÔÊ¾¿Õ¸ñ
		PUSH	CS
		POP	DS
		POP	CX
		POP	DX
		INC	DL			;ÐòºÅ+1
		CMP	DL,3AH
		JNZ	L_A6F3
		MOV	DL,'0'                  ;10='0'
L_A6F3:
		LOOP	L_A6B8
		RET

;¡¾ÖØÑ¡´Ê×é¡¿
L_A73B:
		CMP	AH,82H			;ALT+'-'
		JNB	L_A760
		CMP	AH,78H			;ALT+1
		JB	L_A757
		MOV	AL,AH
		SUB	AL,77H			;ALT+1~0×ª»»Îª0~9
L_A749:
		CMP	AL,D_2BD2		;³¬³öÑ¡Ôñ·¶Î§?
		JB	L_A752
		JMP	L_9DC0			;ÏìÁå²¢·µ»Ø
L_A752:
		JMP	L_A634			;Ñ¡ÖÐ´Ê
L_A757:
		CALL	S_9F66			;ÅÐALT+¿Õ¸ñ
		JB	L_A749
		JMP	SHORT L_A767
L_A760:
		JZ	L_A76A			;ÊÇALT+'-'
		CMP	AH,83H			;ALT+'+'
		JZ	L_A783
L_A767:
		JMP	L_9E86			;·Ç´ÊÊ×¼ü´¦Àí
L_A76A:
		TEST	D_2BB9,8		;ÅÐË«Æ´´Ê×é
		JZ	L_A770
		RET
L_A770:
		CALL	S_A831			;Îª·´Ïò²é´Ê±íÉèÖ¸Õë
		MOV	DI,D_2BA2		;´Ê±íÍâÂëÇøÖ¸Õë
		DEC	DI
		STD
		MOV	D_2BA5,0FFH		;²é´Ê±í·½Ïò:·´Ïò
		CALL	S_A85A			;²é´Ê±í
		CALL	S_A83A			;·´ÏòÎªÏÂ´Î²é´Ê±íÉèÖ¸Õë
		JMP	L_A610			;ÔÙÈë´Ê·½Ê½
L_A783:
		TEST	D_2BB9,8		;ÅÐË«Æ´´Ê×é
		JZ	L_A790
		RET
L_A790:
		CALL	S_A851			;ÎªÕýÏò²é´Ê±íÉèÖ¸Õë
		JMP	L_A600			;ÔÙÈë´Ê·½Ê½
;¡¾´Ê×éÑ¡ÖÐ¡¿
L_A798:
		CMP	AL,0DH			;»Ø³µ?
		JNZ	L_A7C0
L_A79D:
		MOV	D_2BB0,0
		AND	D_2BB9,0EFH		;Çå´Ê±êÖ¾Î»
		CALL	S_9F2E			;¶¨Î»ÇåÌáÊ¾ÐÐ
		MOV	D_959B,0FFH		;ÖÃÍê³ÉÌ¬
		JMP	L_9DC5			;·µ»Ø
L_A7C0:
		CMP	AL,'['
		JNZ	L_A7C1
		JMP	L_A76A
L_A7C1:
		CMP	AL,']'
		JZ	L_A783
		CMP	AL,'9'                  ;ÅÐÊý×Ö
		JA	L_A7E2
		CMP	AL,'0'
		JB	L_A7D9
		JNZ	L_A7D4
		MOV	AL,3AH
L_A7D4:
		AND	AL,0FH
		JMP	L_A749			;´ÊÑ¡ÖÐ
L_A7D9:
		CMP	AL,' '
		JB	L_A79D
		JNZ	L_A7E2
		XOR	AL,AL			;¿Õ¸ñ=0
		JMP	L_A749			;´ÊÑ¡ÖÐ
L_A7E2:
		CMP	D_963A,4
		JZ	L_A7E3
		JMP	L_9E86			;ÖØÈëÔ­ÊäÈë·½Ê½
L_A7E3:
		JMP	L_9D54

;×Ó³ÌÐò:È¡Ö¸ÕëÏÂSI´Ê³¤
S_A809:
		PUSH	DS
		MOV	DS,D_2B98
		MOV	AL,[SI]
		XOR	AH,AH
		POP	DS
		RET
;×Ó³ÌÐò:ÕýÏòÎªÏÂ´Î²é´Ê±íÉèÖ¸Õë
S_A816:
		MOV	AX,D_2BAF
		DEC	AX
		MOV	D_9646,AX
		MOV	AX,D_2BAD
		MOV	D_2BAF,AX
		MOV	SI,D_9646
		CALL	S_A809
		SUB	D_2B9E,AX
		MOV	AX,D_2B9E
		MOV	D_2B9C,AX
		MOV	AX,D_2B9A
		MOV	D_2B9E,AX
		RET
;×Ó³ÌÐò:Îª·´Ïò²é´Ê±íÉèÖ¸Õë
S_A831:
		MOV	AX,D_2B9C
		MOV	D_2B9A,AX
		MOV	AX,D_9646
		MOV	D_2BAD,AX
		RET
;×Ó³ÌÐò:·´ÏòÎªÏÂ´Î²é´Ê±íÉèÖ¸Õë
S_A83A:
		MOV	SI,D_9646
		CALL	S_A809
		ADD	AX,D_2B9C
		MOV	D_2B9E,AX
		MOV	AX,D_2B9A
		MOV	D_2B9C,AX
		MOV	AX,D_9646
		INC	AX
		MOV	D_2BAF,AX
		MOV	AX,D_2BAD
		MOV	D_9646,AX
		RET
;×Ó³ÌÐò:ÎªÕýÏò²é´Ê±íÉèÖ¸Õë
S_A851:
		MOV	AX,D_2B9E
		MOV	D_2B9A,AX
		MOV	AX,D_2BAF
		MOV	D_2BAD,AX
		RET

;×Ó³ÌÐò:²é´Ê±í
S_A85A:
		AND	D_2BB9,0DFH		;ÇåÖØÂëÎ»
		XOR	DX,DX			;DH:ÌáÊ¾ÐÐ´Ê×é×Ü³¤
		MOV	D_9597,DX		;ÖØÂë¼ÆÊý
		MOV	D_2BD2,DH		;ÇåÌáÊ¾ÐÐÖØÂëÊý
		XOR	CH,CH
		MOV	SI,D_2BAD		;µ±Ç°´Ê±íÖ¸Õë
		MOV	BP,D_2B9A		;µ±Ç°ÄÚÂëÖ¸Õë
		MOV	DS,D_2B98		;´Ê±í¶Î
L_A87C:
		CMP	SI,DI			;²éÍê?
		JNZ	L_A899
		PUSH	CS
		POP	DS
		MOV	AL,D_2BD2		;ÌáÊ¾ÐÐÖØÂëÊý
		XOR	AH,AH
		CMP	AX,D_9597		;ÖØÂëÊý>ÌáÊ¾ÐÐÖØÂëÊý?
		JBE	L_A897
		MOV	D_2BAD,SI		;´æµ±Ç°²é±íÖ¸Õë
		MOV	D_2B9A,BP		;´æµ±Ç°ÄÚÂëÇøÖ¸Õë
L_A897:
		CLD
		RET
L_A899:
		PUSH	BP
		MOV	CL,CS:D_2BB0		;¼üÈëÂëÊý
		MOV	BX,OFFSET D_2BB1	;¼üÈëÂëÇøÊ×
L_A89D:
		MOV	AL,DS:[BP]
		CMP	AL,CS:[BX]		;ÅÐ¼ü
		JNZ	L_A8BC
		INC	BP
		INC	BX
		LOOP	L_A89D
		JMP	SHORT L_A8DC
L_A8BC:
		POP	BP
L_A8BD:
		LODSB				;×ªÏÂÒ»´Ê
		XOR	AH,AH
		CMP	CS:D_2BA5,0FFH		;·´Ïò²é´Ê±í?
		JZ	L_A8D2
		ADD	BP,AX			;ÄÚÂëÖ¸ÕëÏÂÒÆ
		JMP	SHORT L_A87C
L_A8D2:
		MOV	AL,[SI] 		;Ö¸ÕëÏÂ´Ê³¤
		SUB	BP,AX			;ÄÚÂëÇøÖ¸ÕëÉÏÒÆ
		JMP	SHORT L_A87C
L_A8DC:
		POP	BP
		INC	CS:D_9597		;ÖØÂëÊý+1
		MOV	DL,[SI] 		;´Ê³¤
		PUSH	BP
		CMP	CS:D_966D,0FFH
		JNZ	L_A8E0
L_A8DE:
		CMP	BYTE PTR DS:[BP],0A0H	;ÅÐºº×Ö?
		JA	L_A8E8
		INC	BP
		DEC	DL
		JMP	SHORT L_A8DE
L_A8E0:
		CMP	BYTE PTR DS:[BP],60H	;ÅÐÐ¡Ð´×ÖÄ¸?
		JB	L_A8E8
		CMP	BYTE PTR DS:[BP],7AH
		JA	L_A8E8
		INC	BP
		DEC	DL
		JMP	SHORT L_A8E0
L_A8E8:
		MOV	AX,BP
		POP	BP
		ADD	DH,DL			;ÀÛ¼ÆÌáÊ¾ÐÐ´Ê³¤
		ADD	DH,2			;¼ÓÐòºÅºÍ¿Õ¸ñ
		TEST	CS:D_2BB9,20H		;ÌáÊ¾ÐÐÖØÂë¼ÇÂ¼Î»?
		JNZ	L_A8BD
		MOV	BL,CS:D_2BD2		;ÌáÊ¾ÐÐÖØÂëÊý
		CMP	DH,CS:D_9668		;±ÈÌáÊ¾ÐÐ´Ê×éÇø³¤¶È?
		JA	L_A8FA
		CMP	BL,11			;ÌáÊ¾ÐÐÖØÂëÊý>11
		JB	L_A8FB
L_A8FA:
		OR	BL,BL			;ÌáÊ¾ÐÐÎÞÖØÂë´Ê?
		JNZ	L_A8FC
L_A8FB:
		PUSH	AX
		MOV	AL,4
		MUL	BL			;´ÊÖØÂëÇøÖ¸Õë
		MOV	BX,AX
		POP	AX
		MOV	CS:D_964A[BX],DL	;´æ²éµ½´Ê³¤
		MOV	CS:D_964B[BX],0
		MOV	CS:D_9648[BX],AX	;´æÄÚÂëÇøµØÖ·
		INC	CS:D_2BD2		;ÌáÊ¾ÐÐÖØÂëÊý+1
		JMP	L_A8BD
L_A8FC:
		TEST	CS:D_2BB9,20H		;ÌáÊ¾ÐÐÖØÂë¼ÇÂ¼Î»?
		JNZ	L_A8FD
		MOV	CS:D_2BAD,SI		;´æµ±Ç°²é´Ê±íÖ¸Õë
		MOV	CS:D_2B9A,BP		;´æµ±Ç°ÄÚÂëÇøÖ¸Õë7
		OR	CS:D_2BB9,20H		;ÖÃÌáÊ¾ÐÐÖØÂë¼ÇÂ¼Î»
L_A8FD:
		JMP	L_A8BD

;×Ó³ÌÐò:²éË«Æ´´Ê±í
;	SI-µØÖ·,BP-´Ê³¤,DH-ÀÛ¼Æ³¤,DL-¶þ×ÖÆ«ÒÆ
S_A900:
		MOV	AX,WORD PTR D_2BB1
		MOV	WORD PTR D_2CC1,AX
		MOV	AX,WORD PTR D_2BB1+2
		MOV	WORD PTR D_2CC1+2,AX
S_A9000:
		MOV	DS,D_SPCZ		;Ë«Æ´´Ê±í¶Î
		MOV	CS:D_2B98,DS

		MOV	SI,DS:[4]		;À©Õ¹´Ê¿âÊ×
L_A901:
		CMP	SI,DS:[6]		;ÅÐ:À©Õ¹´Ê¿âÎ²?
		JZ	L_A940			;ÅÐ:»ù±¾´Ê¿â
		XOR	BP,BP
L_A903:
		CMP	BYTE PTR DS:[BP+SI],',' ;ÅÐ´ÊÎ²?
		JZ	L_A910
		INC	BP
		JMP	SHORT L_A903
L_A910:
		CMP	BP,4			;¶þ×Ö´Ê?
		JNZ	L_A920
		MOV	DI,SI
		LODSW				;È¡Ò»×Ö
		CALL	S_A9A0			;È¡Ë«Æ´
		CMP	AX,WORD PTR CS:D_2CC1	;ÅÐ?
		LODSW
		JNZ	L_A919
		CALL	S_A9A0			;È¡Ë«Æ´
		CMP	AL,CS:D_2CC1+2		;ÅÐµÚÈýÂë?
		JNZ	L_A919
		CMP	CS:D_2CC1+3,'?'
		JZ	L_A912
		CMP	AH,CS:D_2CC1+3		;ÅÐµÚËÄ¼ü?
		JNZ	L_A919
L_A912:
		CALL	S_A990			;´æ
L_A919:
		INC	SI
		JMP	SHORT L_A901
L_A920:
		CMP	BP,6			;Èý×Ö´Ê?
		JNZ	L_A930
		CALL	S_SP6			;²éÈý×Ö´Ê
		JMP	SHORT L_A919
L_A930:
		CALL	S_SP8			;²é¶à×Ö´Ê
		JMP	SHORT L_A919

L_A940:
		MOV	BP,4			;¶þ×Ö´Ê
		MOV	SI,16
L_A941:
		XOR	DL,DL
		CMP	SI,DS:[0]		;Èý×Ö´Ê¿ªÊ¼?
		JZ	L_A950
		MOV	DI,SI
		LODSW				;È¡Ò»×Ö
		CALL	S_A9A0			;È¡Ë«Æ´
		CMP	AX,WORD PTR CS:D_2CC1	;ÅÐ?
		JZ	L_A945
L_A942:
		LODSW
		TEST	AX,8080H		;ÅÐÏÂÒ»ÐÐÊ×?
		JNZ	L_A942
L_A943:
		SUB	SI,2			;Ö¸ÏòÏÂÒ»ÐÐÊ×
		JMP	SHORT L_A941
L_A944:
		ADD	DL,2			;Æ«ÒÆ
L_A945:
		LODSW				;È¡Ò»×Ö
		TEST	AX,8080H		;ÅÐÏÂÒ»ÐÐÊ×?
		JZ	L_A943
		CALL	S_A9A0			;È¡Ë«Æ´
		CMP	AL,CS:D_2CC1+2		;ÅÐµÚÈýÂë?
		JNZ	L_A944
		CMP	CS:D_2CC1+3,'?'
		JZ	L_A946
		CMP	AH,CS:D_2CC1+3		;ÅÐµÚËÄÂë?
		JNZ	L_A944
L_A946:
		CALL	S_A990			;´æ
		JMP	SHORT L_A944
L_A950:
		CMP	CS:D_2CC1+3,'`'         ;µÚËÄ¼ü`Ö»ÄÜÊÇÈý×Ö´Ê
		JNZ	L_A960
		MOV	BP,6			;Èý×Ö´Ê
L_A951:
		CMP	SI,DS:[2]		;ËÄ×Ö´Ê¿ªÊ¼µØÖ·?
		JZ	L_A970
		CALL	S_SP6
		JMP	SHORT L_A951
L_A960:
		CMP	SI,DS:[4]		;ËÄ×Ö´Ê½áÊø?
		JZ	L_A970
		CALL	S_SP8
		INC	SI
		JMP	SHORT L_A960
L_A970:
		PUSH	CS			;½áÊø
		POP	DS
		RET
;×Ó³ÌÐò:²éÕÒÈý×Ö´Ê
S_SP6:
		LODSW
		CALL	S_A9B0			;È¡Ë«Æ´ÉùÄ¸
		CMP	AL,CS:D_2CC1
		JZ	L_SP61
		ADD	SI,4
		RET
L_SP61:
		LODSW
		CALL	S_A9B0			;È¡Ë«Æ´ÉùÄ¸
		CMP	AL,CS:D_2CC1+1
		LODSW
		JNZ	L_SP62
		CALL	S_A9B0			;È¡Ë«Æ´ÉùÄ¸
		CMP	AL,CS:D_2CC1+2
		JNZ	L_SP62
		CALL	S_A990			;´æ
L_SP62:
		RET
;×Ó³ÌÐò:²éÕÒ¶à×Ö´Ê
S_SP8:
		LODSW				;µÚÒ»×Ö
		CALL	S_A9B0			;È¡Ë«Æ´ÉùÄ¸
		CMP	AL,CS:D_2CC1
		JZ	L_SP82
;×Ó³ÌÐò:²éÕÒ´ÊÎ² Ö¸Ïò¶ººÅ
S_A980:
		MOV	BP,6
L_A981:
		CMP	BYTE PTR [SI],','       ;ÅÐ´ÊÎ²?
		JZ	L_A981A
		INC	BP
		INC	SI
		JMP	SHORT L_A981
L_A981A:
		RET
L_SP82:
		LODSW				;µÚ¶þ×Ö
		CALL	S_A9B0			;È¡Ë«Æ´ÉùÄ¸
		CMP	AL,CS:D_2CC1+1
		JNZ	S_A980
		LODSW				;µÚÈý×Ö
		CALL	S_A9B0			;È¡Ë«Æ´ÉùÄ¸
		CMP	AL,CS:D_2CC1+2
		JNZ	S_A980
		CALL	S_A980			;²éÕÒ´ÊÎ²
		MOV	AX,[SI-2]		;È¡Ä©×Ö
		CALL	S_A9B0			;È¡Ë«Æ´ÉùÄ¸
		CMP	AL,CS:D_2CC1+3
		JNZ	L_SP83
		CALL	S_A990			;´æ
L_SP83:
		RET
;×Ó³ÌÐò:´æ²éµ½´ÊµØÖ·
S_A990:
		INC	CS:D_9597		;ÖØÂëÊý+1	11.16-
		MOV	CX,BP			;´Ê³¤
		ADD	DH,CL			;ÀÛ¼Æ´Ê³¤
		ADD	DH,2			;¼ÓÐòºÅºÍ¿Õ¸ñ
		CMP	DH,CS:D_9668		;ÅÐÂú?
		JA	L_A993			;		11.16©´
		MOV	AL,CS:D_2BD2		;È¡ÌáÊ¾ÐÐÖØÂëÊý
		CMP	AL,11
		JAE	L_A993
		INC	CS:D_2BD2		;ÌáÊ¾ÐÐÖØÂëÊý+1
		MOV	AH,4
		MUL	AH			;		11.16©¼
		MOV	BX,AX			;Ö¸Õë
		MOV	CS:D_964A[BX],CL	;´æ²éµ½´Ê³¤
		MOV	CS:D_964B[BX],DL	;¶þ×Ö´ÊÆ«ÒÆ
		CMP	BP,4
		JZ	L_A992
		MOV	AX,SI			;ÏÂÒ»´ÊµØÖ·
		SUB	AX,BP			;¼õ´Ê³¤
		MOV	CS:D_9648[BX],AX	;´æ²éµ½´ÊµØÖ·
		RET
L_A992:
		MOV	CS:D_9648[BX],DI	;´æ²éµ½´ÊµØÖ·
L_A993:
		RET
;×Ó³ÌÐò:È¡Ë«Æ´
S_A9A0:
		CALL	S_A9C0			;È¡Âë±í±íÏî	A960
S_A9A1:
		AND	AX,3FFH 		;È¡µÍÊ®Î»	A961
		PUSH	CX
		MOV	CL,3
		SHL	AX,CL
		SHR	AL,CL			;AHµÚ¶þ,ALµÚÒ»
		POP	CX
		ADD	AX,6060H		;±äÎªÐ¡Ð´×ÖÄ¸
		RET
;×Ó³ÌÐò:È¡Ê×Æ´Âë
S_A9B0:
		CALL	S_A9C0			;È¡Âë±í±íÏî	A970
		AND	AL,1FH			;È¡µÍÎåÎ»
		ADD	AL,60H			;±äÎªÐ¡Ð´×ÖÄ¸
		RET
;×Ó³ÌÐò:È¡²¿Ê×Âë
S_A9B8:
		CALL	S_A9C0			;È¡Âë±í±íÏî
		MOV	AL,AH
		AND	AL,7FH
		SHR	AL,1
		SHR	AL,1
		OR	AL,60H
		RET
;×Ó³ÌÐò:È¡ºº×ÖÔÚÆ´ÒôÂë±íÖÐµÄ±íÏî			      A990
S_A9C0:
		PUSH	BX
		AND	AX,7F7FH
		SUB	AX,2130H
		MOV	BL,AH
		MOV	BH,94
		MUL	BH
		XOR	BH,BH
		ADD	AX,BX
		SHL	AX,1
		ADD	AX,CS:D_PY
		MOV	BX,AX
		MOV	AX,CS:[BX]
		POP	BX
		RET

;×Ó³ÌÐò:ÏÔÊ¾Æ´Òô
S_XSPY:
		MOV	AX,BP
		PUSH	AX
		CALL	S_A9A0			;È¡Ç°¶þÂë
		CALL	S_XSAX
		POP	AX
		CALL	S_A9B8
		MOV	AH,' '
S_XSAX:
		MOV	BL,D_TUX2
		PUSH	AX
		CALL	S_1403A
		POP	AX
		MOV	AL,AH
		CALL	S_1403A
		RET

;×Ó³ÌÐò:ÏÔÊ¾Ê×Î²
S_XSSW:
		MOV	AX,BP
		SUB	AX,0A1B0H
		MOV	DL,AH
		MOV	DH,94
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX
		SHL	AX,1
		ADD	AX,CS:D_SW
		MOV	BX,AX
		MOV	AX,CS:[BX]
		CALL	S_A9A1
		CALL	S_XSAX
		MOV	DL,' '
		CALL	S_1403
		RET

S_JRCL		ENDP

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
A_BUF		DW	0			;¹«ÓÃ»º³åÇøÖ¸Õë
D_959D		EQU	$			;·µ»ØÂëÇø(ÈÝÁ¿256)
D_BUF		EQU	$+256			;¹«ÓÃ»º³åÇø(512×Ö½Ú)

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		ORG	$+64
L_S60:
		CMP	K_SW,'Y'                ;°²×°Ê×Î²Âë±í?
		JNZ	L_S70
		MOV	DX,OFFSET F_SWMB	;'SWMB', 0
		CALL	S_HF			;Ð´ÈëÎÄ¼þÃû²¢´ò¿ª
		JB	L_S62
		CALL	S_READ			;¶Á
		JB	L_S62
		OR	CX,CX
		JZ	L_S62
		MOV	DX,CS:[BP]		;'Ê×'
		MOV	WORD PTR D_SWXS,DX
		MOV	DX,CS:[BP+2]		;'Î²'
		MOV	WORD PTR D_SWXS+2,DX
		MOV	D_SW,BP 		;´æÊ×Î²Âë±íÊ×µØÖ·
		ADD	D_SW,4
		ADD	BP,CX			;¼ÓÊ×Î²Âë±í³¤¶È
		MOV	D_SW+2,BP		;´æÊ×Î²Âë±íÎ²µØÖ·
		JMP	SHORT L_S70
L_S62:
		MOV	K_SW,'N'
		MOV	SI,OFFSET F_SWMB	;'SWMB', 0
		CALL	S_NOFOUND
L_S70:
		CMP	K_PY,'Y'                ;°²×°Æ´ÒôÂë±í?
		JNZ	L_S80
		MOV	DX,OFFSET F_PYMB	;'PYMB', 0
		CALL	S_HF			;Ð´ÈëÎÄ¼þÃû²¢´ò¿ª
		JB	L_S72
		CALL	S_READ			;¶Á
		JB	L_S72
		OR	CX,CX
		JZ	L_S72
		MOV	D_PY,BP 		;´æÆ´ÒôÂë±íÊ×µØÖ·
		ADD	D_PY,11*26*2
		ADD	BP,CX			;¼ÓÆ´ÒôÂë±í³¤¶È
		MOV	D_PY+2,BP		;´æÆ´ÒôÂë±íÎ²µØÖ·
		JMP	SHORT L_S80
L_S72:
		MOV	K_PY,'N'
		MOV	SI,OFFSET F_PYMB	;'PYMB', 0
		CALL	S_NOFOUND
L_S80:
		CMP	K_DB,'Y'                ;°²×°µç±¨Âë±í?
		JNZ	L_S90
		MOV	DX,OFFSET F_DBMB	;'DBMB', 0
		CALL	S_HF			;Ð´ÈëÎÄ¼þÃû²¢´ò¿ª
		JB	L_S82
		CALL	S_READ			;¶Á
		JB	L_S82
		OR	CX,CX
		JZ	L_S82
		MOV	D_DB,BP 		;´æµç±¨Âë±íÊ×µØÖ·
		ADD	BP,CX			;¼Óµç±¨Âë±í³¤¶È
		JMP	SHORT L_S90
L_S82:
		MOV	K_DB,'N'
		MOV	SI,OFFSET F_DBMB	;'DBMB', 0
		CALL	S_NOFOUND
L_S90:
		MOV	DX,OFFSET F_YX		;'YX0.DAT'
		CALL	S_HF			;Ð´ÈëÎÄ¼þÃû²¢´ò¿ª
		JB	L_S92
		CALL	S_READ			;¶Á
		JB	L_S92
		OR	CX,CX
		JZ	L_S92
		MOV	D_YX,DX
		ADD	BP,CX
		JMP	SHORT L_S95
L_S92:
		MOV	SI,OFFSET F_YX
		CALL	S_NOFOUND
L_S95:
		MOV	AX,BP
		MOV	CL,4
		SHR	AX,CL
		INC	AX
		MOV	BP,CS
		ADD	BP,AX

		MOV	AL,K_SPKZ		;Ë«Æ´´Ê×éÇø´óÐ¡
		CMP	AL,'1'
		JB	L_S100
		CMP	AL,'9'
		JA	L_S100
		AND	AL,0FH
		CBW
		MOV	DX,400H 		;=1K
		MUL	DX
		MOV	DS:[0FCH],AX		;Ë«Æ´´Ê×éÔ¤ÁôÇø

		MOV	DX,OFFSET F_SPCZ
		CALL	S_HF			;Ð´ÈëÎÄ¼þÃû²¢´ò¿ª
		JB	L_S98
		MOV	BX,AX
		MOV	DS,BP
		MOV	CS:D_SPCZ,BP
		MOV	DX,0
		MOV	CX,-1
		MOV	AH,3FH			;¶ÁË«Æ´´Ê×éÎÄ¼þ
		INT	21H
		MOV	DI,AX
		MOV	WORD PTR DS:[DI],0	;Î²ÖÃ0
		MOV	AX,CS:[0FCH]
		ADD	AX,DS:[6]		;¼ÓË«Æ´´Ê×éÇø³¤¶È
		MOV	DS:[8],AX		;Ë«Æ´´Ê×éÇøÎ²
		MOV	CL,4
		SHR	AX,CL
		INC	AX
		MOV	DX,AX			;
		MOV	AH,3EH
		INT	21H
		CMP	BYTE PTR DS:[0FH],0FFH	;ÐÂSPCZ.DAT±êÖ¾?
		JNZ	L_S98
		ADD	BP,DX			;
		JMP	SHORT L_S100
L_S98:
		MOV	SI,OFFSET F_SPCZ
		CALL	S_NOFOUND
L_S100:
		MOV	DX,BP
		MOV	BP,CS
		MOV	DS,BP
		SUB	DX,BP
		ADD	DX,3
		MOV	D_LEN,DX		;×¤Áô³¤¶È(½Ú)

		MOV	AX,CS
		CMP	AX,0A000H		;ÅÐLH?
		JA	L_S110
		CMP	D_RAM,'N'               ;×¤Áô»ù±¾ÄÚ´æ
		JZ	L_S110
		CALL	S_GETUMB		;·ÖÅäUMB¶Î
		JZ	L_S120
L_S110:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;Çå»·¾³¿é
		INT	21H
		CALL	S_SETINT
		JMP	L_S140			;×¤Áô
L_S120:
		MOV	AX,D_UMB
		OR	AX,AX
		JZ	L_S110
		DEC	AX
		MOV	ES,AX
		MOV	DI,8
		MOV	SI,OFFSET D_NAME
		MOV	CX,5
		REP	MOVSB			;ÏòUMBÎÄ¼þ¿ØÖÆ¿éÐ´Èë±¾Ä£¿éÃû

		MOV	DX,D_UMB		;¶Î
		MOV	ES,DX
		XOR	SI,SI
		MOV	DI,SI
		MOV	BP,D_LEN
		CMP	BP,1000H
		JB	L_S130
		SUB	BP,1000H
		MOV	CX,8000H
		REP	MOVSB			;¿½±´±¾Ä£¿éµ½UMB
		MOV	CX,8000H
		REP	MOVSB			;¿½±´±¾Ä£¿éµ½UMB
		ADD	DX,1000H
		MOV	ES,DX
		MOV	DX,DS
		ADD	DX,1000H
		MOV	DS,DX
L_S130:
		MOV	AX,16
		MUL	BP
		MOV	CX,AX
		REP	MOVSB			;¿½±´±¾Ä£¿éµ½UMB
		MOV	DS,CS:D_UMB

		CALL	S_SETINT

		PUSH	CS
		POP	DS
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;Çå»·¾³¿é
		INT	21H
		PUSH	CS
		POP	ES
		MOV	AH,49H			;Çå±¾Ä£¿é
		INT	21H

		MOV	AH,50H			;ÉèÖÃÐÂPSP
		MOV	BX,D_UMB
		INT	21H
L_S140:
		MOV	DX,D_LEN		;±¾Ä£¿é³¤¶È(½Ú)
		MOV	AX,3100H		;×¤Áô
		INT	21H

D_XMS		DD	0			;XMSÇý¶¯µØÖ·
D_NCFP		DW	0			;Ô­ÄÚ´æ·ÖÅä²ßÂÔ
D_UMB0		DW	0			;Ô­UMBÁ¬½Ó×´Ì¬
D_UMB		DW	0			;·ÖÅäUMB¶Î
D_LEN		DW	0			;±¾Ä£¿é³¤¶È(½Ú)
D_RAM		DB	0			;='N':×¤Áô»ù±¾ÄÚ´æ

;×Ó³ÌÐò:È¡UMB¶Î
S_GETUMB	PROC	NEAR
		CALL	S_GETXMS		;È¡XMSÇý¶¯µØÖ·
		JNZ	L_GU2
		MOV	AH,10H			;ÇëÇóUMB
		CALL	D_XMS			;XMS
		CMP	AX,1			;=1:³É¹¦,BX=¶Î
		JZ	L_GU1
		CALL	S_UMB			;·ÖÅäUMB¶ÎBX
		CMP	AL,AL			;ZF=1
		RET
L_GU1:
		MOV	D_UMB,BX		;È¡³öUMB¶Î
L_GU2:
		RET
S_GETUMB	ENDP

S_UMB		PROC	NEAR
		MOV	AX,3000H		;È¡DOS°æ±¾ºÅ
		INT	21H
		CMP	AL,5			;ÅÐ>5.0
		JB	L_UMB3
		MOV	AX,5800H		;È¡ÄÚ´æ·ÖÅä²ßÂÔAX
		INT	21H
		MOV	D_NCFP,AX
		MOV	AX,5802H		;È¡UMBÁ¬½Ó×´Ì¬AL
		INT	21H
		CBW
		MOV	D_UMB0,AX

		MOV	AX,5803H		;ÖÃUMBÁ¬½Ó
		MOV	BX,1			;=1Á¬½Ó
		INT	21H
		JC	L_UMB3
		MOV	AX,5801H		;ÖÃÄÚ´æ·ÖÅä²ßÂÔ
		MOV	BX,41H			;×î¼ÑÊÊºÏ¿é
		INT	21H
		JC	L_UMB2
		MOV	AH,48H			;·ÖÅäÄÚ´æ
		MOV	BX,D_LEN
		INT	21H
		JC	L_UMB1
		MOV	D_UMB,AX		;·ÖÅä¿é¶Î
L_UMB1:
		MOV	AX,5801H		;»Ö¸´ÄÚ´æ·ÖÅä²ßÂÔ
		MOV	BX,D_NCFP
		INT	21H
L_UMB2:
		MOV	BX,D_UMB0
		MOV	AX,5803H		;»Ö¸´UMBÁ¬½Ó×´Ì¬
		INT	21H
L_UMB3:
		RET
S_UMB		ENDP

;×Ó³ÌÐò:È¡XMSÇý¶¯µØÖ· ->D_XMS
S_GETXMS	PROC	NEAR
		MOV	AX,4300H		;È¡XMS°²×°×´Ì¬
		INT	2FH
		CMP	AL,80H			;=80H:ÒÑ°²×°
		JNZ	L_GX1
		MOV	AX,4310H		;È¡XMSÇý¶¯µØÖ·
		INT	2FH
		MOV	WORD PTR D_XMS,BX	;±£´æ
		MOV	WORD PTR D_XMS+2,ES
		CMP	AL,AL			;·µ»ØZF=1
L_GX1:
		RET
S_GETXMS	ENDP

S_SETINT	PROC	NEAR
		MOV	DX,OFFSET INT_16
		MOV	AX,2516H		;½¨ÖÐ¶Ï16H
		INT	21H
		MOV	DX,OFFSET INT_9
		MOV	AX,2509H		;½¨ÖÐ¶Ï9
		INT	21H

		MOV	AX,D_SPCZ
		OR	AX,AX
		JZ	L_SI2
		MOV	BX,CS
		SUB	AX,BX
		MOV	DX,DS
		ADD	AX,DX
		MOV	D_SPCZ,AX
L_SI2:
		RET
S_SETINT	ENDP

;×Ó³ÌÐò:Ð´ÈëÎÄ¼þÃû²¢´ò¿ª DX=ÎÄ¼þÃûÊ× ·µ»ØDX=ÎÄ¼þÃûÊ×
S_HF		PROC	NEAR
		MOV	DI,A_S			;±¾³ÌÐòÂ·¾¶Ð´ÈëµØÖ·
		OR	DI,DI			;ÅÐÓÐÎÞ?
		JZ	L_HF1
		MOV	CX,10
		MOV	SI,DX			;²»´ø»·¾³µÄÎÄ¼þÃû
		CALL	S_MOVE			;´«ËÍ
		MOV	DX,OFFSET F_S		;´ø»·¾³µÄÎÄ¼þÃû
L_HF1:
		MOV	AX,3D00H		;´ò¿ªÎÄ¼þ
		INT	21H
		RET
S_MOVE:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	S_MOVE
		RET
S_HF		ENDP

;×Ó³ÌÐò:¶ÁÎÄ¼þ DX=ÎÄ¼þÃûÊ×,BP=¶ÁÈëµØÖ· ·µ»ØCX=¶Á³ö³¤¶È
S_READ		PROC	NEAR
		MOV	BX,AX
		MOV	DX,BP			;¶ÁÈëµØÖ·
		MOV	CX,-1
		MOV	AH,3FH
		INT	21H
		JB	L_RD1
		MOV	CX,AX			;¶Á³ö³¤¶È
		MOV	AH,3EH
		INT	21H
		CLC
L_RD1:
		RET
S_READ		ENDP

NOFOUND 	DB	13,10,'NOT FOUND FILE ',7,'$'
;×Ó³ÌÐò:ÏÔÊ¾Î´ÕÒµ½ SI:ÎÄ¼þÃû
S_NOFOUND	PROC	NEAR
		PUSH	CS			;			3.15
		POP	DS
		MOV	DX,OFFSET NOFOUND
		MOV	AH,9
		INT	21H
		MOV	AH,2
L_NF1:
		LODSB
		OR	AL,AL
		JZ	L_NF2
		MOV	DL,AL
		INT	21H
		JMP	SHORT L_NF1
L_NF2:
		RET
S_NOFOUND	ENDP

D_NAME		DB	'CKBD',0                ;Ä£¿éÃû
F_S		DB	40 DUP(0)		;Ô´ÎÄ¼þÃû
A_S		DW	0			;Ð´ÈëµØÖ·
MSG		DB	'2.13L ºº×ÖÏµÍ³¼üÅÌÄ£¿é ',DATE,13,10,'$'

;****************************************************************************
;¡¾±¾Ä£¿é¿ªÊ¼Ö´ÐÐ¡¿
BEGIN:
		MOV	SP,0D0H

		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_S10
L_S1:
		LODSB
		CMP	AL,0DH
		JZ	L_S10
		CMP	AL,'/'
		JNZ	L_S1
		LODSB
		CMP	AL,'?'
		JNZ	L_S2
		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
		INT	20H
L_S2:
		AND	AL,5FH
		CMP	AL,'N'                  ;/N:×¤Áô»ù±¾ÄÚ´æ
		JNZ	L_S1
		MOV	D_RAM,AL
		JMP	SHORT L_S1
L_S10:
		MOV	CX,-1
		MOV	AH,5			;Ïò¼üÅÌ»º³åÇøËÍ0FFFFH
		INT	16H
		OR	AL,AL			;ÅÐÖ§³Ö?
		JNZ	L_S14
		MOV	CX,15
L_S12:
		MOV	AH,10H			;È¡¼üÂë
		INT	16H
		CMP	AX,-1			;ÊÇ·ñÐ´ÈëµÄ?
		JZ	L_S15
		LOOP	L_S12
L_S14:
		MOV	BYTE PTR INT16_AH0,0	;ÀÏ¼üÅÌ,Ö»ÄÜÓÃAH=0
		MOV	BYTE PTR INT16_AH1,1
L_S15:
		MOV	AH,2FH			;È¡±¾Ä£¿é¶Î
		INT	16H
		CMP	AX,44H			;ÅÐCKBDÒÑ×¤Áô?		2.10
		JNZ	L_S20
		MOV	DX,OFFSET ALREADY
L_ERR:
		MOV	AH,9
		INT	21H
L_ERR1:
		MOV	AX,4C01H
		INT	21H
L_S20:
		MOV	AX,40H
		MOV	ES,AX
		MOV	AX,ES:[82H]		;¼üÅÌ»º³åÇøÎ²Ö·
		SUB	AX,ES:[80H]		;-ÇøÊ×=»º³åÇø´óÐ¡
		SHR	AX,1
		MOV	D_KBDBUF,AX
		MOV	AX,3516H		;È¡ÖÐ¶Ï16H
		INT	21H
		MOV	WORD PTR D_INT16,BX	;´æ
		MOV	WORD PTR D_INT16+2,ES
		MOV	AX,3509H		;;È¡ÖÐ¶Ï9
		INT	21H
		MOV	WORD PTR D_INT9,BX	;´æ
		MOV	WORD PTR D_INT9+2,ES

		MOV	DS,DS:[2CH]		;»·¾³¶Î
		XOR	SI,SI
L_S30:
		CMP	WORD PTR DS:[SI],0	;²éÕÒ»·¾³ÇøÎ²?
		JZ	L_S32
		INC	SI
		JMP	SHORT L_S30
L_S32:
		ADD	SI,4
		MOV	DI,OFFSET F_S		;´øÂ·¾¶Ô´ÎÄ¼þÃûÇø
		PUSH	CS
		POP	ES
		CMP	BYTE PTR [SI+1],':'     ;ÅÐÓÐÅÌ·û?
		JZ	L_S33
		MOV	AH,19H			;È¡µ±Ç°ÅÌ
		INT	21H
		INC	AL
		MOV	DL,AL
		OR	AL,40H
		STOSB				;Ð´ÈëÅÌ·û
		MOV	AL,':'
		STOSB
		CMP	BYTE PTR [SI],'\'       ;ÅÐÓÐ¾ø¶ÔÂ·¾¶?
		JZ	L_S33
		MOV	AL,'\'
		STOSB
		JMP	SHORT L_S34
L_S33:
		CMP	BYTE PTR [SI+2],'\'     ;ÅÐÓÐ¾ø¶ÔÂ·¾¶?
		JZ	L_S35
		LODSW				;ÅÌ·ûºÍ\
		SUB	AL,40H
		MOV	DL,AL			;ÅÌ·û
		STOSW
L_S34:
		PUSH	SI
		MOV	SI,DI
		MOV	AH,47H			;È¡µ±Ç°Â·¾¶
		INT	21H
		POP	SI
L_S35:
		CALL	S_MOVE			;´«ËÍ
		PUSH	CS
		POP	DS
L_S37:
		CMP	BYTE PTR [DI-1],'\'
		JZ	L_S38
		DEC	DI
		JMP	SHORT L_S37
L_S38:
		MOV	A_S,DI			;ÎÄ¼þÃûÐ´ÈëµØÖ·

		MOV	SI,OFFSET F_S
		MOV	DI,D_PATH
		MOV	WORD PTR [DI-2],'  '
L_S40:
		CMP	SI,A_S
		JZ	L_S41
		MOVSB				;´«ËÍµ½°²×°Â·¾¶
		JMP	SHORT L_S40
L_S41:
		MOV	BYTE PTR [DI-1],0

		MOV	DX,OFFSET F_INI
		CALL	S_HF			;Ð´ÈëÎÄ¼þÃû²¢´ò¿ª
		JNB	L_S42
		MOV	SI,OFFSET F_INI
		CALL	S_NOFOUND
		JMP	L_ERR1
L_S42:
		MOV	BX,AX
		MOV	DX,OFFSET BUF
		MOV	SI,DX
		MOV	CX,-1
		MOV	AH,3FH			;¶ÁÅäÖÃÎÄ¼þ
		INT	21H
		MOV	AH,3EH			;¹Ø±ÕÎÄ¼þ
		INT	21H
		MOV	DI,OFFSET K_DISP	;²ÎÊý±í
		MOV	CX,32
L_S44:
		CALL	S_GETB			;È¡Ò»²ÎÊý
		STOSB
		LOOP	L_S44
		MOV	SI,OFFSET K_DISP
		MOV	DI,0F4H
		MOVSW
		MOVSW

		MOV	AX,6F1H
		MOV	SI,OFFSET K_AF1
		CMP	K_FCC,'Y'               ;·Â³¤³Ç¼ü?
		JZ	L_S46
		MOV	SI,OFFSET D_JHJB	;½»»»¼ü±í
L_S46:
		MOV	[SI],AL
		INC	SI
		INC	AX
		DEC	AH
		JNZ	L_S46
L_S50:
		MOV	D_9680,CS

		MOV	BP,OFFSET D_BUF+768	;¿Õ768×Ö½Ú
		JMP	L_S60

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

ALREADY 	DB	'CKBD IS ALREADY!',7,13,10,'$'

BUF		EQU	$

SEG_A		ENDS
		END	START

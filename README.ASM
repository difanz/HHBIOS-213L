;	README.ASM
;	1995.9.20, 9.28, 10.18, 10.26, 12.23
;	1996.1.3

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

C_B		DB	9EH		;Ç¿µ÷ÐÅÏ¢ÑÕÉ«
C_A		DB	1EH		;Õý³£ÎÄ±¾ÑÕÉ«
C_D		DB	4AH		;Ä¿Â¼ÐÅÏ¢ÑÕÉ«
C_1		DB	6FH		;¶¥ÐÐÑÕÉ«
C_DH		DB	70H		;µ×ÐÐºº×ÖÑÕÉ«
C_DZ		DB	74H		;    ×Ö·ûÑÕÉ«
D_CX		DW	1		;=1:¿ÉÏÔÊ¾ºº×Ö,=0:°´×Ö·ûÏÔÊ¾

D_L		DW	0		;µ±Ç°ÐÐ
D_SI		DW	0		;µ±Ç°Ò³Ê×ÐÐºÅ
D_STAS		DW	0		;ÎÄ¼þÊ×¶Î
D_END		DW	0		;ÎÄ¼þÎ²µØÖ·
D_ENDS		DW	0		;      ¶Î
D_TAB		DW	0		;Ä¿Â¼Çøµ±Ç°ÐÐµØÖ·
D_LM		DW	0		;×î´óÐÐºÅ
D_DM		DW	0		;Ä¿Â¼ÇøÎ²µØÖ·
D_DH		DB	0		;=0Çå,=-1ÖÃ Ä¿Â¼

D_MODE		DB	0		;ÏÔÊ¾·½Ê½
D_MSG		DB	' F1-°ïÖú TAB-ÏÂÒÆ»ò·µ»ØÄ¿Â¼ Shift+TAB-ÉÏÒÆÄ¿Â¼ CR-Ìø×ª²éÔÄ ESC-ÍË³ö F10-ÉèÖÃ´æÅÌ',0
D_MSG1		DB	' F2-ÎÄ±¾Ç°¾° F3-±³¾° F4-Ä¿Â¼Ç°¾° F5-±³¾° F6-Ç¿µ÷Ç°¾° F7-±³¾° F8-¶¥ÐÐÇ°¾° F9-±³¾°',0
D_TUX		DB	0		;µ±Ç°ÌáÊ¾ºÅ:0-MSG,-1-MSG1

D_HELP		DB	'Í¨ÓÃÎÄ±¾ÔÄ¶Á³ÌÐò README.COM Ê¹ÓÃËµÃ÷',0
D_HELP1 	DB	'µ÷ÓÃ¸ñÊ½: README [¸ñÊ½ÎÄ¼þ]',0
		DB	'  È±Ê¡ÎªÓë±¾³ÌÐòÍ¬Ä¿Â¼µÄÎÞÀ©Õ¹ÃûµÄÎÄ¼þÃû',0
		DB	'¸ñÊ½ÎÄ¼þÎÄ±¾¸ñÊ½(Çë²Î¿¼±¾ÏµÍ³µÄREADME):',0
		DB	'  !c±êºÅ-Ë÷Òý±êÖ¾  !d±êºÅ-Ä¿Â¼ÐÅÏ¢',0
		DB	'  !e-¿ÉÏÔÊ¾ºº×Ö    !f-°´×Ö·ûÏÔÊ¾',0
		DB	'  !aÕý³£ÎÄ±¾  !bÇ¿µ÷ÐÅÏ¢(¿É¼Ó±³Ç°¾°ÑÕÉ«)',0
		DB	'       ÆäÖÐ:±³¾°É«0-9,Ç°¾°É«0-9,A-F»òa-f',0
		DB	'  ±êºÅÎªÁ½¸ö×Ö·û»òÒ»¸öºº×Ö(×î¶à256¸ö)',0
		DB	'¹¦ÄÜ¼üËµÃ÷:          <INS>-ÌáÊ¾ÇÐ»»',0
		DB	'  <TAB>-Ä¿Â¼Çø¹â±êÏÂÒÆ»ò´ÓÎÄ±¾Çø·µÄ¿Â¼Çø',0
		DB	'  <Shift+TAB>-Ä¿Â¼Çø¹â±êÉÏÒÆ',0
		DB	'  <PgUp>-ÉÏ¾íÒ»Ò³    <PgDn>-ÏÂ¾íÒ»Ò³',0
		DB	'  <HOME>-ÖÁÎÄ±¾Ê×Ò³  <END>--ÖÁÎÄ±¾Ä©Ò³',0
		DB	'ÑÕÉ«ÉèÖÃ:            F10-ÉèÖÃ´æÅÌ',0
		DB	'  F2-Õý³£ÎÄ±¾Ç°¾°É«  F6-Ç¿µ÷ÐÅÏ¢Ç°¾°É«',0
		DB	'  F3-        ±³¾°É«  F7-        ±³¾°É«',0
		DB	'  F4-Ä¿Â¼ÐÅÏ¢Ç°¾°É«  F8-¶¥ÐÐÐÅÏ¢Ç°¾°É«',0
		DB	'  F5-        ±³¾°É«  F9-        ±³¾°É«',0
		DB	' °æÈ¨ËùÓÐ:±±¾©Ïþ¾üµçÄÔ¹«Ë¾  1996Äê1ÔÂ2ÈÕ',0,0
D_BP		DW	0			;D_COMÖÐÎÄ¼þÀ©Õ¹Ãû·Ö¸ô·ûµØÖ·
D_WJM		DB	'ÎÄ¼þÃû: ',0
D_YSH		DB	'Ò³Ê×ÐÐºÅ:',0
D_LMH		DB	'×Ü¼ÆÐÐÊý:',0
D_HH		DB	'    ',0
NOFILE		DB	'ÎÄ¼þÎ´ÕÒµ½!',7,13,10,'$'
NODIR		DB	'ÓÐË÷ÒýÐÅÏ¢Î´ÕÒµ½!',7,13,10,'$'
NO213		DB	'NO 2.13 CHINESE SYSTEM!',7,13,10,'$'
;----------------------------------------------------------------------------
BEGIN:
		XOR	BP,BP
		MOV	AX,1406H		;È¡ÏÔÊ¾Ä£¿é²ÎÊý
		INT	10H
		OR	BP,BP			;ÅÐ2.13?
		JNZ	L_10
		MOV	DX,OFFSET NO213
		JMP	L_ERR
L_10:
		MOV	D_MODE,AL		;ÏÔÊ¾·½Ê½

		MOV	SI,80H
		LODSB
		OR	AL,AL			;ÃüÁîÐÐ²ÎÊý?
		JZ	L_20
		CBW
		MOV	BX,AX
		MOV	[BX+SI],AH		;ÎÄ¼þÃûÎ²
L_12:
		LODSB
		CMP	AL,' '
		JBE	L_12
		DEC	SI
		MOV	DX,SI			;Ö¸¶¨ÎÄ¼þÃû
		JMP	SHORT L_30		;		12.23
L_20:
		MOV	DS,DS:[2CH]		;»·¾³¶Î
		XOR	SI,SI
L_21:
		CMP	WORD PTR DS:[SI],0	;ÅÐ»·¾³ÇøÎ²?
		JZ	L_22
		INC	SI
		JMP	SHORT L_21
L_22:
		LODSW
		LODSW				;SI:README.COMÈ«Â·¾¶Ê×
		MOV	DI,OFFSET D_COM
L_23:
		LODSB
		STOSB
		CMP	AL,'.'                  ;À©Õ¹Ãû·Ö¸ô·û
		JNZ	L_24
		MOV	BP,DI			;´æ
		DEC	BP
		JMP	SHORT L_23
L_24:
		OR	AL,AL
		JNZ	L_23

		PUSH	CS
		POP	DS
		MOV	D_BP,BP
		MOV	BYTE PTR DS:[BP],0	;È¥À©Õ¹Ãû
		MOV	DX,OFFSET D_COM
L_30:
		MOV	AX,3D00H		;´ò¿ªÎÄ¼þ
		INT	21H
		JNB	L_32
		MOV	DX,OFFSET NOFILE
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_32:
		MOV	BX,AX

		MOV	SI,DX			;ÎÄ¼þÃû´«ËÍµ½DS:60H
		MOV	DI,60H
L_34:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	L_34

		MOV	BP,DS
		MOV	D_STAS,BP
		ADD	D_STAS,1000H		;Ê×¶Î
L_36:
		ADD	BP,1000H		;ÏÂÒ»¶Î
		MOV	DS,BP
		XOR	DX,DX
		MOV	CX,8000H
		MOV	AH,3FH			;¶ÁÎÄ¼þ
		INT	21H
		CMP	AX,CX
		JB	L_38
		MOV	DX,CX
		MOV	AH,3FH			;¶ÁÎÄ¼þ
		INT	21H
		CMP	AX,CX
		JZ	L_36
		ADD	AX,DX
L_38:
		MOV	CS:D_END,AX		;ÎÄ¼þÎ²µØÖ·
		MOV	CS:D_ENDS,BP
		MOV	AH,3EH
		INT	21H

		CALL	S_LINE			;È¡Ã¿ÐÐÊ×µØÖ· CS=>DS

		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		CALL	S_CLS			;ÇåÆÁ
;----------------------------------------------------------------------------
L_90:
		MOV	BP,D_STAS		;Ê×¶Î
		XOR	SI,SI
L_92:
		MOV	D_SI,SI 		;Ò³Ê×ÐÐºÅ
		MOV	DX,100H 		;µÚÒ»ÐÐÊ×
L_94:
		MOV	SI,D_SI 		;Ò³Ê×ÐÐ
		MOV	DI,D_TAB		;Ä¿Â¼ÐÐµØÖ·
		OR	DI,DI			;ÅÐÔÚÄ¿Â¼Çø
		JZ	L_98
		MOV	AX,[DI]
		SUB	AX,SI
		JB	L_96
		CMP	AX,23
		JB	L_98
L_96:
		MOV	D_TAB,0
L_98:
		CALL	S_XS			;ÏÔÊ¾Ò»Ò³
L_100:
		XOR	AH,AH			;¼üÈë.ÒÔÏÂ:DI=Ò³Ê×µÄÐÐÊ×µØÖ·Çø
		INT	16H			;	   BP=	  ¶Î
;----------------------------------------------------------------------------
		CMP	AX,4800H		;¡ü
		JNZ	L_110
		CMP	D_SI,0			;Ò³Ê×ÐÐµ½ÎÄ¼þÊ×
		JZ	L_100
		DEC	D_SI			;Ò³Ê×ÐÐ-1
		JMP	L_94			;ÏÔÊ¾
;----------------------------------------------------------------------------
L_110:
		CMP	AX,5000H		;¡ý
		JNZ	L_120
		MOV	AX,D_LM
		SUB	AX,23
		CMP	D_SI,AX 		;Ò³Ê×<ÎÄ¼þÎ²-23ÐÐ
		JAE	L_100
		INC	D_SI			;Ò³Ê×ÐÐ+1
		JMP	L_94			;ÏÔÊ¾
;----------------------------------------------------------------------------
L_120:
		CMP	AX,4900H		;PGUP
		JNZ	L_130
		MOV	SI,D_SI
		CMP	SI,23			;=ÎÄ¼þÊ×?
		JAE	L_121
		XOR	SI,SI
		JMP	SHORT L_122
L_121:
		SUB	SI,23
L_122:
		MOV	D_SI,SI 		;Ò³Ê×ÐÐÊý
		JMP	L_94
;----------------------------------------------------------------------------
L_130:
		CMP	AX,5100H		;PGDN
		JNZ	L_140
		MOV	SI,D_SI
		MOV	AX,D_LM 		;ÎÄ¼þÎ²ÐÐ
		SUB	AX,23
		CMP	SI,AX			;=ÎÄ¼þÎ²µØÖ·?
		JBE	L_131
		MOV	SI,AX
		JMP	SHORT L_133
L_131:
		SUB	AX,SI
		CMP	AX,23
		JBE	L_132
		MOV	AX,23
L_132:
		ADD	SI,AX			;ÏÂÒ»Ò³
L_133:
		MOV	D_SI,SI 		;Ò³Ê×µØÖ·
		JMP	L_94
;----------------------------------------------------------------------------
L_140:
		CMP	AX,4700H		;HOME
		JNZ	L_150
		JMP	L_90
;----------------------------------------------------------------------------
L_150:
		CMP	AX,4F00H		;END
		JNZ	L_160
		MOV	SI,D_LM
		SUB	SI,23
		JMP	L_92
;----------------------------------------------------------------------------
L_160:
		CMP	AL,9			;<TAB>
		JNZ	L_170
		CMP	D_TAB,0
		JNZ	L_166
		MOV	SI,D_SI
		MOV	DI,D_DM
		CMP	SI,[DI]
		JA	L_162
		MOV	DI,OFFSET D_DIR 	;Ä¿Â¼Çø
L_161:
		CMP	SI,[DI]
		JBE	L_164
		ADD	DI,4
		JMP	SHORT L_161
L_162:
		MOV	DI,OFFSET D_DIR 	;Ä¿Â¼Çø
L_163:
		CMP	SI,[DI+2]		;µ±Ç°ÐÐ<Ä¿Â¼ÐÐºÅ
		JBE	L_164
		ADD	DI,4
		CMP	DI,D_DM
		JZ	L_164
		CMP	SI,[DI+2]		;<ÏÂÒ»¸ö?
		JA	L_163
L_164:
		MOV	D_TAB,DI		;µ±Ç°Ä¿Â¼ÐÐµØÖ·

		MOV	SI,[DI] 		;Ä¿Â¼ÐÐ
		MOV	AX,D_SI 		;Ò³Ê×ÐÐ
		CMP	SI,AX
		JB	L_165
		ADD	AX,23
		CMP	SI,AX
		JBE	L_173
L_165:
		JMP	L_92			;ÏÔÊ¾
L_166:
		MOV	DI,D_TAB
		CMP	DI,D_DM 		;µ½Ä¿Â¼ÇøÎ²?
		JAE	L_174
		CALL	S_CLSDIR		;ÇåÔ­Ä¿Â¼
		ADD	DI,4
		MOV	D_TAB,DI
		JMP	SHORT L_171
;----------------------------------------------------------------------------
L_170:
		CMP	AX,0F00H		;SHIFT+TAB
		JNZ	L_180
		CMP	D_TAB,0 		;ÅÐÔÚÄ¿Â¼Çø?
		JZ	L_174
		MOV	DI,D_TAB
		CMP	DI,OFFSET D_DIR 	;µ½Ä¿Â¼ÇøÊ×
		JZ	L_174
		CALL	S_CLSDIR		;ÇåÔ­Ä¿Â¼
		SUB	DI,4
		MOV	D_TAB,DI
L_171:
		MOV	AX,D_SI 		;Ò³Ê×ÐÐºÅ
		CMP	[DI],AX 		;Ä¿Â¼ÐÐ<Ò³Ê×
		JB	L_172
		ADD	AX,23
		CMP	[DI],AX 		;>Ò³Î²?
		JB	L_173
L_172:
		MOV	SI,[DI]
		JMP	L_92			;ÏÔÊ¾
L_173:
		CALL	S_SETDIR		;ÖÃµ±Ç°Ä¿Â¼
L_174:
		CALL	S_280			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢
		JMP	L_100
;----------------------------------------------------------------------------
L_180:
		CMP	AX,3B00H		;F1?
		JNZ	L_190
		CALL	S_280			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢
		MOV	DX,212H 		;×óÉÏ½ÇÎ»ÖÃ
		MOV	CX,152CH		;¸ßºÍ¿í
		MOV	BL,30H			;ÑÕÉ«
		CALL	S_XSCK			;ÏÔÊ¾¿Õ´°¿Ú
		PUSH	DX
		ADD	DX,4
		MOV	SI,OFFSET D_HELP
		CALL	S_XSZFC
		POP	DX
		MOV	SI,OFFSET D_HELP1
		ADD	DX,102H
		CALL	S_CKXS			;ÏÔÊ¾ÄÚÈÝ
		XOR	AH,AH			;¼üÈë
		INT	16H
		XOR	DL,DL
		JMP	L_98			;ÖØÏÔµ±Ç°Ò³
;----------------------------------------------------------------------------
L_190:
		MOV	CL,4
		CMP	AX,3C00H		;F2:Õý³£ÎÄ±¾Ç°¾°É«
		JNZ	L_200
		MOV	AL,C_A
		MOV	AH,AL
		AND	AX,0F00FH
		INC	AL
		CMP	AL,10H
		JB	L_191
		XOR	AL,AL
L_191:
		OR	AL,AH
		MOV	C_A,AL
		CALL	S_281			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢1
		JMP	L_94
;----------------------------------------------------------------------------
L_200:
		CMP	AX,3D00H		;F3:Õý³£ÎÄ±¾±³¾°É«
		JNZ	L_210
		MOV	AL,C_A
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_191
;----------------------------------------------------------------------------
L_210:
		CMP	AX,3E00H		;F4:Ä¿Â¼ÐÅÏ¢Ç°¾°É«
		JNZ	L_220
		MOV	AL,C_D
		MOV	AH,AL
		AND	AX,0F00FH
		INC	AL
		CMP	AL,10H
		JB	L_211
		XOR	AL,AL
L_211:
		OR	AL,AH
		MOV	C_D,AL
		CALL	S_281			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢1
		JMP	L_94
;----------------------------------------------------------------------------
L_220:
		CMP	AX,3F00H		;F5:Ä¿Â¼ÐÅÏ¢±³¾°É«
		JNZ	L_230
		MOV	AL,C_D
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_211
;----------------------------------------------------------------------------
L_230:
		CMP	AX,4000H		;F6:Ç¿µ÷ÐÅÏ¢Ç°¾°É«
		JNZ	L_240
		MOV	AL,C_B
		MOV	AH,AL
		AND	AX,0F00FH
		INC	AL
		CMP	AL,10H
		JB	L_231
		XOR	AL,AL
L_231:
		OR	AL,AH
		MOV	C_B,AL
		CALL	S_281			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢1
		JMP	L_94
;----------------------------------------------------------------------------
L_240:
		CMP	AX,4100H		;F7:Ç¿µ÷ÐÅÏ¢±³¾°É«
		JNZ	L_250
		MOV	AL,C_B
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_231
;----------------------------------------------------------------------------
L_250:
		CMP	AX,4200H		;F8:¶¥ÐÐÐÅÏ¢Ç°¾°É«
		JNZ	L_260
		MOV	AL,C_1			;¶¥ÐÐÑÕÉ«
		MOV	AH,AL
		AND	AX,0F00FH
		INC	AL
		CMP	AL,10H
		JB	L_251
		XOR	AL,AL
L_251:
		OR	AL,AH
		MOV	C_1,AL
		CALL	S_XSDH			;ÏÔÊ¾¶¥ÐÐ
		MOV	DX,100H
		CALL	S_281			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢1
		JMP	L_100
;----------------------------------------------------------------------------
L_260:
		CMP	AX,4300H		;F9:¶¥ÐÐÐÅÏ¢±³¾°É«
		JNZ	L_270
		MOV	AL,C_1
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_251
;----------------------------------------------------------------------------
L_270:
		CMP	AX,4400H		;F10:ÉèÖÃ´æÅÌ
		JNZ	L_280
		MOV	DX,OFFSET D_COM
		MOV	BX,D_BP
		MOV	BYTE PTR DS:[BX],'.'    ;»Ö¸´À©Õ¹Ãû
		MOV	CX,20H
		MOV	AH,3CH			;ÖØ½¨ÎÄ¼þ
		INT	21H
		MOV	BX,AX
		MOV	DX,100H 		;ÎÄ¼þÊ×
		MOV	CX,OFFSET D_COM 	;ÎÄ¼þÎ²
		SUB	CX,DX			;³¤¶È
		MOV	AH,40H			;Ð´Èë
		INT	21H
		MOV	AH,3EH			;¹Ø±ÕÎÄ¼þ
		INT	21H
		CALL	S_280			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢
		JMP	L_100
;----------------------------------------------------------------------------
L_280:
		CMP	AH,52H			;<INS>:ÇÐ»»ÌáÊ¾
		JNZ	L_290
		CMP	D_TUX,0 		;µ±Ç°ÌáÊ¾?
		JZ	L_281
		CALL	S_280			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢
		JMP	SHORT L_282
L_281:
		CALL	S_281			;ÏÔÊ¾ÌáÊ¾ÐÅÏ¢1
L_282:
		JMP	L_100
S_280:
		MOV	D_TUX,0
		MOV	SI,OFFSET D_MSG
		JMP	S_XSTS
S_281:
		MOV	D_TUX,-1
		MOV	SI,OFFSET D_MSG1
		JMP	S_XSTS
;----------------------------------------------------------------------------
L_290:
		CMP	AL,0DH			;»Ø³µ
		JNZ	L_300
		CALL	S_280
		MOV	DI,D_TAB		;µ±Ç°Ä¿Â¼µØÖ·
		OR	DI,DI			;ÅÐ0
		JZ	L_291
		MOV	SI,[DI+2]		;Ë÷ÒýÐÐ
		JMP	L_92			;ÏÔÊ¾
L_291:
		JMP	L_100
;----------------------------------------------------------------------------
L_300:
		CMP	AL,1BH			;ESC
		JNZ	L_291
		MOV	AX,1813H		;ÖØÏÔÆÁÄ»
		INT	10H
		MOV	CX,0E0FH
		MOV	AH,1			;¿ª¹â±ê
		INT	10H
		MOV	AX,4C00H		;ÍË³ö
		INT	21H
;============================================================================
;×Ó³ÌÐò:²éÕÒÃ¿ÐÐÊ×¡¢Ä¿Â¼ÐÐÊ×ºÍË÷ÒýÐÐÊ×µØÖ· CS=>DS
S_LINE		PROC	NEAR
		MOV	BP,CS:D_STAS		;ÎÄ±¾ÇøÊ×¶Î
		MOV	DS,BP			;		BP:µ±Ç°¶Î
		MOV	BX,OFFSET D_DIR 	;Ä¿Â¼ÐÅÏ¢µØÖ·	BX:
		MOV	DI,OFFSET D_LINE	;ÐÐÊ×µØÖ·´æ·ÅÇø DI:
		XOR	CX,CX			;ÐÐºÅ		CX:
		XOR	AX,AX
		STOSW
		MOV	AX,BP
		STOSW
		XOR	SI,SI			;µ±Ç°¾ø¶ÔµØÖ·
L_L1:
		LODSB				;È¡Ò»×Ö·û
		CALL	S_SEG			;ÅÐ¿ç¶Î
		CMP	AL,'!'                  ;¹¦ÄÜ·û?
		JNZ	L_L3
		LODSB
		CALL	S_SEG
		CMP	AL,'d'                  ;Ä¿Â¼ÐÅÏ¢
		JNZ	L_L2
		MOV	CS:[BX],CX		;ÐÐºÅ
		ADD	BX,4
		JMP	SHORT L_L1
L_L2:
		CMP	AL,'c'                  ;Ë÷ÒýÐÅÏ¢
		JNZ	L_L3
		CALL	S_SORT			;²éÄ¿Â¼Çø²¢Ð´Èë
		JMP	SHORT L_L1
L_L3:
		CMP	AL,0DH			;»Ø³µ?
		JZ	L_L4
		CMP	AL,8DH			;Èí»Ø³µ?
		JZ	L_L4
		CMP	AL,0AH			;»»ÐÐ?
		JZ	L_L4
		CMP	AL,8AH			;·ÖÒ³·û?
		JNZ	L_L1
L_L4:
		OR	SI,SI			;ÅÐ¿ç¶Î?
		JZ	L_L5
		MOV	BYTE PTR [SI-1],0	;¾ùÖÃ0(ÐÐÎ²)
		JMP	SHORT L_L6
L_L5:
		PUSH	DS
		MOV	AX,DS
		SUB	AX,1000H		;ÉÏÒ»¶Î
		MOV	DS,AX
		MOV	BYTE PTR DS:[0FFFFH],0	;ÖÃ0
		POP	DS
L_L6:
		LODSB
		CALL	S_SEG
		MOV	AX,SI			;ÏÂÐÐÊ×µØÖ·
		STOSW
		MOV	AX,BP			;¶Î
		STOSW
		INC	CX

		CMP	BYTE PTR [SI],1AH	;½áÊø?
		JNZ	L_L1

		PUSH	CS
		POP	DS
		MOV	D_LM,CX 		;×î´óÐÐºÅ
		XOR	AX,AX
		STOSW
		MOV	[BX+4],AX		;½áÎ²
		MOV	[BX+6],AX
		RET
S_LINE		ENDP

;×Ó³ÌÐò:²éÄ¿Â¼Çø²¢Ð´Èë BX=Ä¿Â¼ÐÅÏ¢µØÖ·, CX=µ±Ç°ÐÐºÅ
S_SORT		PROC	NEAR
		CMP	CS:D_DM,0		;Ä¿Â¼ÇøÎ²
		JNZ	L_S0
		SUB	BX,4
		MOV	CS:D_DM,BX		;Ä¿Â¼ÇøÎ²
L_S0:
		LODSB				;Ë÷ÒýÄÚÈÝ1
		CALL	S_SEG
		MOV	DL,AL
		LODSB				;Ë÷ÒýÄÚÈÝ2
		CALL	S_SEG
		MOV	DH,AL

		PUSH	DS
		MOV	DS,CS:D_STAS		;ÎÄ¼þÊ×¶Î
		PUSH	SI
		MOV	BX,OFFSET D_DIR 	;Ä¿Â¼ÇøÊ×
L_S1:
		MOV	SI,CS:[BX]		;Ä¿Â¼ÐÐºÅ
		SHL	SI,1
		SHL	SI,1
		MOV	SI,WORD PTR CS:D_LINE[SI]	;ÐÐÊ×
L_S2:
		LODSB
		CMP	AL,'!'                  ;¹¦ÄÜ·û?
		JNZ	L_S2
		LODSB
		CMP	AL,'d'                  ;Ä¿Â¼ÐÅÏ¢
		JNZ	L_S2
		LODSW
		CMP	AX,DX			;ÅÐ
		JZ	L_S3
		ADD	BX,4
		CMP	BX,CS:D_DM		;µ½Ä¿Â¼ÇøÎ²?
		JBE	L_S1
		POP	AX
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET NODIR
		JMP	L_ERR
L_S3:
		MOV	CS:[BX+2],CX		;Ä¿Â¼Ë÷ÒýÐÐºÅ
		POP	SI
		POP	DS
		RET
S_SORT		ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:ÇåÆÁ²¢ÏÔÊ¾¶¥ÐÐÎ²ÐÐÐÅÏ¢
S_CLS		PROC	NEAR
		CALL	S_XSDH			;ÏÔÊ¾¶¥ÐÐ

		XOR	BL,BL
		CMP	D_MODE,9
		JZ	L_CLS1
		MOV	BL,C_A
L_CLS1:
		INC	DH
		CALL	S_CLSYH 		;Çå
		CMP	DH,24
		JB	L_CLS1

		MOV	SI,OFFSET D_MSG
S_XSTS: 					;×Ó³ÌÐò:ÏÔÊ¾ÌáÊ¾ÐÅÏ¢
		PUSH	DX
		MOV	DX,1800H
L_CLS3:
		LODSB
		OR	AL,AL
		JZ	L_CLS5
		MOV	BL,C_DZ
		CMP	AL,0A1H 		;ÅÐºº×Ö?
		JB	L_CLS4
		MOV	BL,C_DH
L_CLS4:
		CALL	S_XSZF			;ÏÔÊ¾
		JMP	SHORT L_CLS3
L_CLS5:
		POP	DX
		RET
;×Ó³ÌÐò:ÏÔÊ¾¶¥ÐÐ
S_XSDH:
		XOR	DX,DX
		MOV	BL,C_1
		CALL	S_CLSYH 		;Çå¶¥ÐÐ

		MOV	SI,OFFSET D_WJM 	;'ÎÄ¼þÃû:'
		MOV	DL,6
		CALL	S_XSZFC
		MOV	SI,60H			;ÎÄ¼þÃû´æ·ÅÇø
		MOV	DL,14
		CALL	S_XSZFC
		MOV	SI,OFFSET D_YSH 	;'Ò³Ê×ÐÐºÅ:'
		MOV	DL,40
		CALL	S_XSZFC
		MOV	SI,OFFSET D_LMH 	;'×Ü¼ÆÐÐÊý:'
		MOV	DL,60
;×Ó³ÌÐò:ÏÔÊ¾×Ö·û´® DX=Î»ÖÃ,SI=×Ö·û´®
S_XSZFC:
		LODSB
		OR	AL,AL			;½áÊø
		JZ	L_XC1
		CALL	S_XSZF			;ÏÔÊ¾
		JMP	SHORT S_XSZFC
L_XC1:
		RET
;×Ó³ÌÐò:ÇåÒ»ÐÐ BL=ÊôÐÔ,DH=ÐÐ
S_CLSYH:
		XOR	DL,DL
		MOV	CX,80
L_CLSYH:
		MOV	AL,' '
		CALL	S_XSZF
		LOOP	L_CLSYH
		RET
;×Ó³ÌÐò:ÏÔÊ¾×Ö·û DX:Î»ÖÃ,AL:×Ö·û
S_XSZF:
		PUSH	CX
		MOV	CX,CS:D_CX		;=1:¿ÉÏÔÊ¾ºº×Ö,=0:°´×Ö·ûÏÔÊ¾1.3
		CMP	CS:D_MODE,9		;µ¥ÏÔ?
		JNZ	L_XSZF2
		TEST	BL,0E0H
		JZ	L_XSZF1
		MOV	BL,70H
		JMP	SHORT L_XSZF2
L_XSZF1:
		MOV	BL,7
L_XSZF2:
		MOV	BH,AL
		MOV	AX,1409H		;ÏÔÊ¾
		INT	10H
		POP	CX
		INC	DX			;Î»ÖÃ+1
		RET
S_CLS		ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:ÏÔÊ¾Ò»Ò³
S_XS		PROC	NEAR
		PUSH	DX
		PUSH	SI
		MOV	D_DH,-1
		MOV	DX,100H 		;ÎÄ±¾Çø×óÉÏ½Ç
		MOV	DI,D_SI 		;Ò³Ê×ÐÐºÅ
L_XS1:
		MOV	SI,DI
		SHL	SI,1
		SHL	SI,1
		ADD	SI,OFFSET D_LINE
		MOV	BP,CS:[SI+2]		;¶Î

		MOV	DS,BP
		MOV	SI,CS:[SI]		;ÐÐÊ×µØÖ·
		CALL	S_XSYH			;ÏÔÊ¾Ò»ÐÐ
		INC	DI
		INC	DH
		CMP	DH,24
		JNZ	L_XS1
		PUSH	CS
		POP	DS

		CALL	S_XSYS			;ÏÔÊ¾Ò³Ê×ÐÐºÅ
		CALL	S_XSZJ			;ÏÔÊ¾×Ü¼ÆÐÐÊý
		POP	SI
		POP	DX
		RET
;×Ó³ÌÐò:ÏÔÊ¾Ò»ÐÐ
S_XSYH:
		MOV	BL,CS:C_A
L_X10:
		LODSB				;È¡Ò»×Ö·û
		CALL	S_SEG
		CMP	AL,'!'                  ;¹¦ÄÜ×Ö·û?
		JZ	L_X11
		JMP	L_X20
L_X11:
		LODSB
		CALL	S_SEG
		CMP	AL,'b'                  ;Ç¿µ÷×Ö·û?
		JNZ	L_X14
		CMP	BYTE PTR [SI],'0'       ;ÅÐÓÐÑÕÉ«?
		JB	L_X13
		CMP	BYTE PTR [SI],'9'
		JA	L_X13
		LODSB				;È¡±³¾°É«
		MOV	CL,4
		SHL	AL,CL
		MOV	BL,AL
		LODSB				;È¡Ç°¾°É«
		CMP	AL,'9'
		JBE	L_X12
		AND	AL,5FH
		SUB	AL,7
L_X12:
		SUB	AL,'0'
		OR	BL,AL
		JMP	SHORT L_X10
L_X13:
		MOV	BL,CS:C_B
		JMP	SHORT L_X10
L_X14:
		CMP	AL,'a'                  ;Õý³£ÎÄ±¾?
		JNZ	L_X15A
		MOV	BL,CS:C_A		;Õý³£ÎÄ±¾ÑÕÉ«
		MOV	CS:D_CX,1		;¿ÉÏÔÊ¾ºº×Ö		1.3
		JMP	SHORT L_X10
L_X15A:
		CMP	AL,'e'                  ;¿ÉÏÔÊ¾ºº×Ö?            1.3
		JNZ	L_X15B
		MOV	CS:D_CX,1		;¿ÉÏÔÊ¾ºº×Ö		1.3
		JMP	SHORT L_X10
L_X15B:
		CMP	AL,'f'                  ;°´×Ö·ûÏÔÊ¾?
		JNZ	L_X15
		MOV	CS:D_CX,0		;°´×Ö·ûÏÔÊ¾		1.3
		JMP	SHORT L_X10
L_X15:
		CMP	AL,'d'                  ;Ä¿Â¼ÐÅÏ¢?
		JNZ	L_X17
		LODSB
		CALL	S_SEG
		LODSB
		CALL	S_SEG
		MOV	BL,CS:C_D		;Ä¿Â¼ÐÅÏ¢ÑÕÉ«
		CMP	CS:D_MODE,9
		JNZ	L_X16
		MOV	BL,7
L_X16:
		CMP	CS:D_DH,0		;¿ª¹Ø
		JZ	L_X16A
		MOV	BP,CS:D_TAB		;µ±Ç°Ä¿Â¼µØÖ·
		OR	BP,BP			;ÅÐ0
		JZ	L_X16A
		CMP	DI,CS:[BP]		;ÊÇ·ñÄ¿Â¼ÐÐ
		JNZ	L_X16A
		MOV	CL,4
		ROR	BL,CL			;Ç°¾°±³¾°½»»»
L_X16A:
		JMP	L_X10
L_X17:
		CMP	AL,'c'                  ;Ë÷ÒýÐÅÏ¢?
		JNZ	L_X18
		LODSB
		CALL	S_SEG
		LODSB
		CALL	S_SEG
		JMP	L_X10
L_X18:
		PUSH	AX
		MOV	AL,'!'
		CALL	S_XSZF			;ÏÔÊ¾×Ö·û\
		POP	AX
L_X20:
		CMP	AL,9			;Ìø¸ñ?
		JNZ	L_X24
L_X21:
		MOV	AL,' '
		CALL	S_XSZF
		TEST	DL,7
		JZ	L_X22
		JMP	SHORT L_X21
L_X22:
		JMP	L_X10
L_X24:
		OR	AL,AL			;ÐÐ½áÊø?
		JZ	L_X30
L_X25:
		CALL	S_XSZF			;ÏÔÊ¾
		JMP	L_X10
L_X30:
		CMP	DL,80			;ÐÐÂú?
		JAE	L_X40
		MOV	AL,' '
		CALL	S_XSZF
		JMP	SHORT L_X30
L_X40:
		LODSB
		CALL	S_SEG
		XOR	DL,DL			;Î»ÖÃÐÐÊ×
		RET
;×Ó³ÌÐò:ÅÐ¿ç¶Î
S_SEG:
		OR	SI,SI
		JNZ	L_SEG1
		MOV	BP,DS
		ADD	BP,1000H
		MOV	DS,BP
L_SEG1:
		RET
S_XS		ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:ÇåÄ¿Â¼ÏÔÊ¾
S_CLSDIR	PROC	NEAR
		XOR	AL,AL
		JMP	SHORT L_DIR1
S_SETDIR:
		MOV	AL,-1
L_DIR1:
		MOV	D_DH,AL
		PUSH	DI
		MOV	SI,[DI]
		MOV	AX,SI
		SUB	AX,D_SI
		INC	AX
		MOV	DH,AL

		MOV	DI,SI
		SHL	SI,1
		SHL	SI,1
		ADD	SI,OFFSET D_LINE
		MOV	BP,[SI+2]		;¶Î
		MOV	DS,BP
		MOV	SI,CS:[SI]		;ÐÐÊ×µØÖ·
		CALL	S_XSYH
		POP	DI
		PUSH	CS
		POP	DS
		RET
S_CLSDIR	ENDP
;----------------------------------------------------------------------------
;×Ó³ÌÐò:ÏÔÊ¾Ò³Ê×ÐÐºÅ
S_XSYS		PROC	NEAR
		MOV	AX,D_SI 		;Ò³Ê×ÐÐ
		INC	AX
		MOV	DX,49
		JMP	SHORT L_XSH1
;×Ó³ÌÐò:ÏÔÊ¾×Ü¼ÆÐÐÊý
S_XSZJ:
		MOV	AX,D_LM 		;×Ü¼ÆÐÐÊý
		MOV	DX,69
L_XSH1:
		XOR	DH,DH
		MOV	BX,10
		MOV	CX,4
		MOV	DI,OFFSET D_HH+3
		PUSH	DX
L_XSH2:
		OR	AX,AX
		JZ	L_XSH3
		XOR	DX,DX
		DIV	BX
		OR	DL,'0'
		JMP	SHORT L_XSH4
L_XSH3:
		MOV	DL,' '
L_XSH4:
		MOV	[DI],DL
		DEC	DI
		LOOP	L_XSH2
		POP	DX

		MOV	DI,OFFSET D_HH
		MOV	BL,C_1
L_XSH5:
		MOV	AL,[DI]
		OR	AL,AL
		JZ	L_XSH6
		INC	DI
		CALL	S_XSZF
		JMP	SHORT L_XSH5
L_XSH6:
		RET
S_XSYS		ENDP
;----------------------------------------------------------------------------
D_G		DW	0			;´°¿Ú¸ß
D_K		DW	0			;    ¿í
D_B1		DB	'ÉÍ»',0
D_B2		DB	'º º',0
D_B3		DB	'ÈÍ¼',0
;×Ó³ÌÐò:ÏÔÊ¾¿Õ´°¿Ú DX=´°¿Ú×óÉÏ½Ç,CH=¸ß,CL=¿í,BL=ÑÕÉ«
S_XSCK		PROC	NEAR
		PUSH	DX
		SUB	CX,202H
		MOV	AL,CH
		CBW
		MOV	D_G,AX			;´°¿ÚÄÚ¸ß
		MOV	AL,CL
		MOV	D_K,AX			;      ¿í

		XOR	CX,CX
		MOV	SI,OFFSET D_B1		;ÉÏºáÏß
		CALL	S_XS1H

		MOV	SI,OFFSET D_B2		;ÖÐ¼ä
		MOV	DI,D_G
L_CK1:
		INC	DH
		CALL	S_XS1H
		DEC	DI
		JNZ	L_CK1
		INC	DH
		MOV	SI,OFFSET D_B3		;ÏÂºáÏß
		CALL	S_XS1H

		POP	DX
		RET
;×Ó³ÌÐò:ÏÔÊ¾Ò»ÐÐ:
S_XS1H:
		PUSH	DX
		MOV	AL,[SI] 		;×ó±ß
		CALL	S_XSZF1
		MOV	BP,D_K
L_YH1:
		MOV	AL,[SI+1]		;ÖÐ¼ä
		CALL	S_XSZF1
		DEC	BP
		JNZ	L_YH1
		MOV	AL,[SI+2]		;ÓÒ±ß
		CALL	S_XSZF1
		POP	DX
		RET
S_XSZF1:
		CMP	CS:D_MODE,9		;µ¥ÏÔ?
		JNZ	L_XSZF22
		TEST	BL,0E0H
		JZ	L_XSZF11
		MOV	BL,70H
		JMP	SHORT L_XSZF22
L_XSZF11:
		MOV	BL,7
L_XSZF22:
		MOV	BH,AL
		MOV	AX,1409H		;ÏÔÊ¾
		INT	10H
		INC	DX			;Î»ÖÃ+1
		RET
S_XSCK		ENDP

;×Ó³ÌÐò:ÏÔÊ¾´°¿ÚÄÚÈÝSI(Ã¿ÐÐÎ²0,×îºóÔÙ¼Ó0),DX=Ê×Î»ÖÃ,BL=ÊôÐÔ
S_CKXS		PROC	NEAR
		PUSH	DX
L_CKXS1:
		CMP	BYTE PTR [SI],0 	;½áÊø?
		JZ	L_CKXS4
		PUSH	DX
		CALL	S_XSZFC
		POP	DX
		INC	DH
		JMP	SHORT L_CKXS1
L_CKXS4:
		POP	DX
		RET
S_CKXS		ENDP
;----------------------------------------------------------------------------
D_COM	EQU	$			;ÎÄ¼þÈ«Ãû
D_DIR	EQU	$+64			;Ä¿Â¼ÐÐÐÅÏ¢ ×î¶à255¸ö
		;¸ñÊ½:ÐÐºÅ,Ë÷ÒýÐÐºÅ...	;½áÎ²Îª0
D_LINE	EQU	$+64+1024		;ÐÐÊ×µØÖ·´æ·ÅÇø
		;¸ñÊ½:ÐÐÊ×µØÖ·,¶Î,...	½áÎ²Îª0

CSEG		ENDS
		END	START

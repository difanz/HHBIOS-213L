;	CZ.ASM (2.13L)
;	1995.7.18
;	1996.1.2, 3.21, 11.14

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

D_TITLE 	DB	' 功  能  选  择  菜  单 ',0
D_MENU		DB	' 建词组库 (指定词典文件建立2.13K外部词组文件) ',0
		DB	' 词组方式 (指定编码词典建词组,可指定输入方法) ',0
		DB	' 建联想库 (指定词典文件，建立2.13K联想库文件) ',0
		DB	' 老双拼转换 (将2.13K的双拼词组转换为词典文件) ',0
		DB	' 老联想转换 (将2.13H的联想文件转换为词典文件) ',0
		DB	' 老词组转换 (将2.13H的词组文件转换为词典文件) ',0
		DB	' 老词组转换 (将2.13H的词组文件转换为编码词典) ',0
		DB	' 新联想转换 (将2.13K的联想文件转换为词典文件) ',0
		DB	' 新词组转换 (将2.13K的词组文件转换为词典文件) ',0
		DB	' 新词组转换 (将2.13K的词组文件转换为编码词典) ',0
		DB	' 双拼词组转换(将SPCZ.DAT转换为词典文件CK.DAT) ',0
		DB	' 词典格式转换(原词典文件转换为专用格式CK.DAT) ',0
		DB	' 建双拼词组(用CK.DAT建立双拼词组文件SPCZ.DAT) ',0
D_MSG		DB	'按<ESC>键退出, 按光标上下键移动, 按回车-选中...',0
D_T1		DB	'┌───────────────────────┐',0
D_T2		DB	'└───────────────────────┘',0
D_SX		DB	'│',0
NO213		DB	'非2.13系列汉字系统!',7,13,10,'$'
NOCKDAT 	DB	'文件CK.DAT不存在或读错误!',13,10,'$'
NOALLHZ 	DB	'二字词中有字符!',13,10,'$'
HZNUM		DB	'取前几个汉字首拼码(回车默认8个.键入数字不用回车): ',0
D_HZNUM 	DB	0
D_ZJ		DB	'总计词组 00000 个,总长度 00000 字节',13,10
		DB	'按回车键返回主菜单...$'
D_INCZ		DB	'请键入词组文件名: '
D_CZ		DB	'CZ$'
D_INLX		DB	'请键入联想文件名: '
D_LX		DB	'LX$'
D_COM		DB	'.COM',0
D_HAN		DW	0
D_INCD		DB	'请键入词典文件名: $'
D_SPCZ		DB	'SPCZ.DAT',0
D_CK		DB	'CK.DAT',0
D_INPUT 	DB	40 DUP(0)
D_1A		DB	1AH

D_X		DB	0			;主菜单当前行
D_X1		DB	0
D_CX		DW	0
D_SI		DW	0			;保存SI
D_DI		DW	0			;保存DI
D_END		DW	0			;读出区尾
D_0D		DB	0
D_K		DW	0			;总长度
D_FILE1 	DW	0			;第一中间文件指针
D_FILE2 	DW	0			;第二中间文件指针
D_FILE3 	DW	0			;第二中间文件指针
D_FILE4 	DW	0			;第二中间文件指针
;----------------------------------------------------------------------------
BEGIN:
		CALL	S_CLS
		MOV	SI,OFFSET D_TITLE	;标题
		MOV	DX,1CH
		MOV	BX,4FH
		CALL	S_XSZF

		MOV	SI,OFFSET D_T1		;显示上横线
		MOV	DX,10EH
		MOV	BX,7
		CALL	S_XSZF
		MOV	BP,13
		MOV	DX,20EH
L_130:
		MOV	SI,OFFSET D_SX		;竖线
		PUSH	DX
		CALL	S_XSZF			;显示左边竖线
		POP	DX
		INC	DH
		DEC	BP
		JNZ	L_130

		MOV	BP,13
		MOV	DX,23EH
L_132:
		MOV	SI,OFFSET D_SX
		PUSH	DX
		CALL	S_XSZF			;显示右边竖线
		POP	DX
		INC	DH
		DEC	BP
		JNZ	L_132

		MOV	SI,OFFSET D_T2		;显示底线
		MOV	DL,0EH
		CALL	S_XSZF
		MOV	D_X1,0
L_133:
		CALL	S_XSCD1
		INC	D_X1
		CMP	D_X1,13
		JB	L_133

		MOV	SI,OFFSET D_MSG
		MOV	DX,1800H
		MOV	BX,7
		CALL	S_XSZF
L_150:
		MOV	CX,2000H
		MOV	AH,1			;关光标
		INT	10H
L_160:
		CALL	S_XSCD
L_170:
		XOR	AH,AH
		INT	16H
		CMP	AH,72			;↑
		JNZ	L_200
		CMP	D_X,0
		JNZ	L_191
		MOV	D_X,12
		JMP	SHORT L_199
L_191:
		DEC	D_X
L_199:
		CALL	S_XSCD1
		JMP	SHORT L_160
L_200:
		CMP	AH,80			;↓
		JNZ	L_220
		CMP	D_X,12
		JB	L_201
		MOV	D_X,0
		JMP	SHORT L_199
L_201:
		INC	D_X
		JMP	SHORT L_199
L_220:
		CMP	AL,1BH			;ESC?
		JNZ	L_222
		CALL	S_CLS
		CALL	S_KGB
		INT	20H
L_222:
		CMP	AL,0DH			;回车?
		JNZ	L_170
		CALL	S_KGB
		MOV	SI,OFFSET D_MSG 	;清提示
		MOV	DX,1800H
		MOV	BX,0
		CALL	S_XSZF
		MOV	AL,47
		MUL	D_X
		ADD	AX,OFFSET D_MENU
		MOV	SI,AX
		MOV	DX,1000H
		MOV	BX,1EH
		CALL	S_XSZF
		CALL	S_0D0A

		MOV	AL,D_X
;----------------------------------------------------------------------------
		CMP	AL,0
		JZ	L_1000
		JMP	L_2000
L_1000: 	; 建词组库 (指定词典文件建立2.13K外部词组文件)
		XOR	BP,BP
		MOV	AH,2FH			;取CKBD段
		INT	16H
		OR	BP,BP			;判安装?
		JNZ	L_1001
		MOV	SI,OFFSET NO213
		MOV	DX,1800H
		MOV	BX,1EH
		CALL	S_XSZF
		JMP	L_150
L_1001:
		MOV	D_FILE1,OFFSET D_BUF1	;CCZZ1
		MOV	D_FILE2,0
		MOV	D_CX,0			;词组计数=0
		MOV	D_K,0			;总长度=0

		MOV	SI,OFFSET HZNUM 	;'取前几个汉字首拼码...'
		MOV	DX,1100H
		MOV	BX,7
		CALL	S_XSZF
L_1040:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,0DH			;回车(默认8个)
		JNZ	L_1045
		MOV	AL,8
		JMP	SHORT L_1048
L_1045:
		CMP	AL,'1'
		JB	L_1040
		CMP	AL,'9'
		JA	L_1040
		MOV	BX,1EH
		MOV	CX,1
		MOV	AH,9			;显示
		INT	10H
		AND	AL,0FH
L_1048:
		MOV	D_HZNUM,AL
		CALL	S_0D0A
L_1050:
		MOV	DX,OFFSET D_INCD	;'请键入词典文件名:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;键入词典文件名
		JNB	L_1055
		JMP	L_1130
L_1055:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_1060
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_1050
L_1060:
		MOV	D_HAN,AX

		MOV	D_DI,OFFSET D_BUF
		CALL	S_READ			;读词典文件32K
		JNB	L_1080
		MOV	BX,D_HAN
		MOV	AH,3EH
		JMP	SHORT L_1050
L_1080:
		CALL	S_GETSTR		;取得字符串SI
		JB	L_1050
L_1100:
		MOV	D_SI,SI 		;保存
		MOV	DI,OFFSET D_STR 	;词组编码存放区
		XOR	BX,BX			;	 个数
		CMP	BYTE PTR [SI],0B0H	;判串首汉字?
		JB	L_1080
L_1110:
		CMP	BYTE PTR [SI],0B0H	;判汉字?
		JB	L_1120
		LODSB
		MOV	AH,AL
		LODSB
		CALL	S_PYM			;取汉字双拼码
		STOSB				;存
		INC	BX			;编码个数+1
		CMP	BL,D_HZNUM		;比设定数?
		JB	L_1110
L_1120:
		ADD	D_K,BX
		ADD	D_K,CX
		MOV	BH,BL			;编码长
		ADD	BH,CL			;+词组长
		MOV	SI,D_FILE1
		MOV	[SI],BH 		;写入CCZZ1
		INC	SI
		MOV	D_FILE1,SI
		PUSH	DI
		PUSH	CX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	ES,AX
		MOV	CL,BL			;编码长
		MOV	SI,OFFSET D_STR
		MOV	DI,D_FILE2
		REP	MOVSB			;写入编码
		POP	CX
		MOV	SI,D_SI
		REP	MOVSB			;写入词组内容
		MOV	D_FILE2,DI
		POP	DI
		PUSH	CS
		POP	ES
		INC	D_CX			;词组计数+1
		JMP	L_1080
L_1130:
		MOV	AX,D_CX 		;词组个数
		OR	AX,AX
		JNZ	L_1133
		JMP	BEGIN
L_1133:
		MOV	WORD PTR D_DATA1+30,AX
		ADD	AX,D_K
		MOV	WORD PTR D_DATA1+28,AX

		MOV	DX,OFFSET D_INCZ	;'请键入词组文件名: CZ'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入词组文件名
		MOV	AX,WORD PTR D_CZ
		MOV	WORD PTR D_INPUT,AX
		MOV	SI,OFFSET D_INPUT
		MOV	DX,SI
L_1140:
		LODSB
		OR	AL,AL
		JNZ	L_1140
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;形成文件名

		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		MOV	BX,AX
		MOV	DX,OFFSET D_DATA1	;COM程序区
		MOV	CX,32
		MOV	AH,40H			;写入文件
		INT	21H
		MOV	DX,OFFSET D_BUF1
		MOV	CX,D_FILE1
		SUB	CX,DX
		MOV	AH,40H			;写入文件
		INT	21H
		MOV	CX,D_FILE2
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		XOR	DX,DX
		MOV	AH,40H			;写入文件
		INT	21H
		PUSH	CS
		POP	DS
		MOV	AH,3EH
		INT	21H

		CALL	S_ZJ
L_1150:
		XOR	AH,AH
		INT	16H
		CMP	AL,0DH
		JNZ	L_1150
		JMP	BEGIN

D_DATA1 	DB	 8CH,0CDH,0BAH, 20H,   1, 89H,0D1H,   3
		DB	 0EH, 1EH,   1,0BEH, 18H,   1,0B4H, 20H
		DB	0CDH, 16H,   3, 16H, 1CH,   1,0CDH, 27H
		DB	0B4H,0CAH,0D7H,0E9H,   0,   0,	 0,   0

;----------------------------------------------------------------------------
D_CKY		DB	'请键入词库源文件名: $'
D_SRFS		DB	'请键入输入方式名(两个汉字): $'
L_2000:
		CMP	AL,1
		JZ	L_2001
		JMP	L_3000
L_2001: 	; 词组方式 (指定编码词典建词组,可指定输入方法)
		MOV	D_FILE1,OFFSET D_BUF1	;CCZZ1
		MOV	D_FILE2,0
		MOV	D_CX,0			;词组计数=0
		MOV	D_K,0			;总长度=0
L_2030:
		MOV	DX,OFFSET D_CKY 	;'请键入词库源文件名:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入词库源文件名
		JNB	L_2040
		JMP	L_2160
L_2040:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_2050
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_2030
L_2050:
		MOV	D_HAN,AX

		MOV	D_DI,OFFSET D_BUF
		CALL	S_READ			;读词典文件32K
		JNB	L_2060
		MOV	BX,D_HAN
		MOV	AH,3EH
		JMP	SHORT L_2030
L_2060:
		CALL	S_GETLINE		;取得一行SI
		JB	L_2030
		MOV	D_SI,SI 		;保存编码首
		MOV	DI,OFFSET D_STR 	;词组编码存放区
		XOR	BX,BX			;	 个数
L_2070:
		LODSB
		CMP	AL,'a'
		JB	L_2072
		CMP	AL,'z'
		JA	L_2072
		STOSB
		INC	BX
		JMP	SHORT L_2070
L_2072:
		DEC	SI
L_2074:
		LODSB
		OR	AL,AL
		JZ	L_2060
		CMP	AL,' '
		JZ	L_2074
		CMP	AL,9
		JZ	L_2074
		DEC	SI
L_2080:
		ADD	D_K,BX

		MOV	AX,CS
		ADD	AX,1000H
		MOV	ES,AX
		MOV	DI,D_FILE2
		PUSH	SI
		MOV	CL,BL			;编码长
		MOV	SI,D_SI
		REP	MOVSB			;写入编码
		POP	SI
		XOR	CX,CX
L_2090:
		LODSB
		CMP	AL,','
		JZ	L_2092
		OR	AL,AL
		JZ	L_2092
		STOSB				;写入词组内容
		INC	CX
		JMP	SHORT L_2090
L_2092:
		MOV	D_FILE2,DI
		ADD	D_K,CX
		PUSH	CS
		POP	ES
		MOV	DI,D_FILE1
		MOV	DX,CX
		ADD	DX,BX
		MOV	[DI],DL
		INC	DI
		MOV	D_FILE1,DI

		INC	D_CX			;词组计数+1
		OR	AL,AL
		JZ	L_2100
		JMP	L_2080
L_2100:
		JMP	L_2060
L_2160:
		MOV	AX,D_CX 		;词组个数
		OR	AX,AX
		JNZ	L_2166
		JMP	BEGIN
L_2166:
		MOV	WORD PTR D_DATA2+30,AX
		ADD	AX,D_K
		MOV	WORD PTR D_DATA2+28,AX

		MOV	DX,OFFSET D_INCZ	;'请键入词组文件名: CZ'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入词组文件名
		MOV	AX,WORD PTR D_CZ
		MOV	WORD PTR D_INPUT,AX
		MOV	SI,OFFSET D_INPUT
		MOV	DX,SI
L_2180:
		LODSB
		OR	AL,AL
		JNZ	L_2180
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;形成文件名

		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		MOV	BX,AX

		MOV	DX,OFFSET D_SRFS	;'请键入输入方式名(两个汉字): $'
		MOV	AH,9
		INT	21H
		MOV	DX,OFFSET D_INPUT	;键入缓冲区
		MOV	DI,DX
		MOV	WORD PTR [DI],5
		MOV	AH,0AH			;键入
		INT	21H
		CALL	S_0D0A
		CMP	BYTE PTR [DI+1],0
		JZ	L_2200
		MOV	AX,[DI+2]
		MOV	WORD PTR D_DATA2+24,AX
		MOV	AX,[DI+4]
		MOV	WORD PTR D_DATA2+26,AX
L_2200:
		MOV	DX,OFFSET D_DATA2	;COM程序区
		MOV	CX,32
		MOV	AH,40H			;写入文件
		INT	21H
		MOV	DX,OFFSET D_BUF1
		MOV	CX,D_FILE1
		SUB	CX,DX
		MOV	AH,40H			;写入文件
		INT	21H
		MOV	CX,D_FILE2
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		XOR	DX,DX
		MOV	AH,40H			;写入文件
		INT	21H
		PUSH	CS
		POP	DS
		MOV	AH,3EH
		INT	21H

		CALL	S_ZJ
L_2210:
		XOR	AH,AH
		INT	16H
		CMP	AL,0DH
		JNZ	L_2210
		JMP	BEGIN

D_DATA2 	DB	 8CH,0CDH,0BAH, 20H,   1, 89H,0D1H,   3
		DB	 0EH, 1EH,   1,0BEH, 18H,   1,0B4H, 20H
		DB	0CDH, 16H,   3, 16H, 1CH,   1,0CDH, 27H
		DB	0B4H,0CAH,0D7H,0E9H,   0,   0,	 0,   0

;----------------------------------------------------------------------------
L_3000:
		CMP	AL,2
		JZ	L_3001
		JMP	L_4000
L_3001: 	; 建联想库 (指定词典文件，建立2.13K联想库文件)
		MOV	D_FILE1,OFFSET D_BUF1	;CCZZ1
		MOV	D_FILE2,0
		MOV	D_CX,0			;词组计数=0
		MOV	D_K,0			;总长度=0
		MOV	AX,CS
		ADD	AX,1000H
		MOV	ES,AX
L_3030:
		MOV	DX,OFFSET D_INCD	;'请键入词典文件名:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;键入词典文件名
		JNB	L_3040
		JMP	L_3120
L_3040:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_3045
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_3030
L_3045:
		MOV	D_HAN,AX

		MOV	D_DI,OFFSET D_BUF
		CALL	S_READ			;读词典文件32K
		JNB	L_3060
		MOV	BX,D_HAN
		MOV	AH,3EH
		JMP	SHORT L_3030
L_3060:
		CALL	S_GETSTR		;取得字符串SI
		JB	L_3030
		MOV	D_SI,SI 		;保存
		MOV	DI,D_FILE2		;词组编码存放区
		XOR	BX,BX			;	 个数
		CMP	BYTE PTR [SI],0B0H	;判串首汉字?
		JB	L_3060
L_3070:
		LODSB
		AND	AL,7FH
		STOSB
		LODSB
		AND	AL,7FH
		STOSB
L_3080:
		LODSB
		OR	AL,AL
		JZ	L_3090
		STOSB
		JMP	SHORT L_3080
L_3090:
		MOV	D_FILE2,DI
		MOV	DI,D_FILE1
		MOV	[DI],CL
		INC	DI
		MOV	D_FILE1,DI

		ADD	D_K,CX
		INC	D_CX
		JMP	L_3060
L_3120:
		PUSH	CS
		POP	ES
		MOV	AX,D_CX 		;词组个数
		OR	AX,AX
		JNZ	L_3130
		JMP	BEGIN
L_3130:
		MOV	WORD PTR D_DATA3+30,AX
		ADD	AX,D_K
		MOV	WORD PTR D_DATA3+28,AX

		MOV	DX,OFFSET D_INLX	;'请键入联想文件名: LX'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入词组文件名
		MOV	AX,WORD PTR D_LX
		MOV	WORD PTR D_INPUT,AX
		MOV	SI,OFFSET D_INPUT
		MOV	DX,SI
L_3140:
		LODSB
		OR	AL,AL
		JNZ	L_3140
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;形成文件名

		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		MOV	BX,AX

		MOV	DX,OFFSET D_DATA3	;COM程序区
		MOV	CX,32
		MOV	AH,40H			;写入文件
		INT	21H
		MOV	DX,OFFSET D_BUF1
		MOV	CX,D_FILE1
		SUB	CX,DX
		MOV	AH,40H			;写入文件
		INT	21H
		MOV	CX,D_FILE2
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		XOR	DX,DX
		MOV	AH,40H			;写入文件
		INT	21H
		PUSH	CS
		POP	DS
		MOV	AH,3EH
		INT	21H

		CALL	S_ZJ
L_3150:
		XOR	AH,AH
		INT	16H
		CMP	AL,0DH
		JNZ	L_3150
		JMP	BEGIN

D_DATA3 	DB	 8CH,0CDH,0BAH, 20H,   1, 89H,0D1H,   3
		DB	 0EH, 1EH,   1,0B8H,   1, 20H,0CDH, 16H
		DB	 89H,0CAH,   3, 16H, 1CH,   1,0CDH, 27H
		DB	   0,	0,   0,   0,   0,   0,	 0,   0

;----------------------------------------------------------------------------
D_SPK		DB	'请键入2.13K双拼词组文件名(不要扩展名): $'
L_4000:
		CMP	AL,3
		JZ	L_4001
		JMP	L_5000
L_4001: 	; 老双拼转换 (将2.13K的双拼词组转换为词典文件)
		MOV	DX,OFFSET D_SPK 	;'请键入2.13H联想库文件名:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入文件名
		JNB	L_4010
		JMP	BEGIN
L_4010:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_4012:
		LODSB
		OR	AL,AL			;找尾?
		JNZ	L_4012
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;形成文件名

		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_4014
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_4014:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'请键入词典文件名:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;键入词典文件名
		JNB	L_4020
		JMP	BEGIN
L_4020:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;读双拼词组文件
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[128H]		;三字词首
		SUB	CX,2
		SUB	CX,130H
		SHR	CX,1
		SHR	CX,1
		MOV	SI,130H 		;双拼词首
		MOV	DI,OFFSET D_STR 	;词典一行区首
		XOR	BP,BP			;	 计数
L_4050:
		CMP	SI,130H 		;首词?
		JZ	L_4080
		MOV	AX,BP
		ADD	AX,4
		CMP	AX,78			;判满一行?
		JBE	L_4070
		CALL	S_WLINE 		;写入一行
		XOR	BP,BP			;清0
		JMP	SHORT L_4080
L_4070:
		MOV	AL,','                  ;分隔符
		STOSB
L_4080:
		LODSW				;写入二字词
		STOSW
		LODSW
		STOSW
		ADD	BP,5
		LOOP	L_4050
		CALL	S_WLINE

		MOV	AX,DS:[12AH]		;四字词首
		MOV	SI,DS:[128H]		;-三字词首
		SUB	AX,SI
		XOR	DX,DX
		MOV	CX,6
		DIV	CX
		MOV	CX,AX			;词数
	;	MOV	DI,OFFSET D_STR 	;词典一行区首
		XOR	BP,BP			;	 计数
L_4090:
		CMP	SI,DS:[128H]		;首词?
		JZ	L_4110
		MOV	AX,BP
		ADD	AX,6
		CMP	AX,78			;判满一行?
		JBE	L_4100
		CALL	S_WLINE
		XOR	BP,BP			;清0
		JMP	SHORT L_4110
L_4100:
		MOV	AL,','                  ;分隔符
		STOSB
L_4110:
		LODSW				;写入三字词
		STOSW
		LODSW
		STOSW
		LODSW
		STOSW
		ADD	BP,7
		LOOP	L_4090
		CALL	S_WLINE

		MOV	SI,DS:[12AH]		;多字词首
	;	MOV	DI,OFFSET D_STR
		XOR	BP,BP
L_4120:
		CMP	SI,DS:[12AH]		;多字词首?
		JZ	L_4150
		MOV	DX,SI
L_4130:
		LODSB
		CMP	AL,','
		JNZ	L_4130
		DEC	SI
		SUB	SI,DX
		XCHG	SI,DX

		ADD	DX,BP
		CMP	DX,78
		JBE	L_4140
		CALL	S_WLINE
		XOR	BP,BP
		JMP	SHORT L_4150
L_4140:
		MOV	AL,','                  ;分隔符
		STOSB
		INC	BP
L_4150:
		LODSB
		CMP	AL,','
		JZ	L_4160
		STOSB
		INC	BP
		JMP	SHORT L_4150
L_4160:
		CMP	BYTE PTR [SI],1AH
		JNZ	L_4120
		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;子程序:写入一行
S_WLINE 	PROC	NEAR
		MOV	AX,0A0DH
		STOSW				;写入
		JMP	SHORT L_WL1
S_WLINE1:
		MOV	AX,0A0DH
		STOSW				;写入
		MOV	AL,1AH
		STOSB
L_WL1:
		PUSH	CX
		PUSH	DX
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_STR
		MOV	CX,DI
		SUB	CX,DX
		MOV	AH,40H			;存文件
		INT	21H
		MOV	DI,OFFSET D_STR
		POP	DS
		POP	DX
		POP	CX
		RET
S_WLINE 	ENDP

;----------------------------------------------------------------------------
D_LXH		DB	'请键入2.13H联想库文件名(不要扩展名): $'
L_5000:
		CMP	AL,4
		JZ	L_5001
		JMP	L_6000
L_5001: 	; 老联想转换 (将2.13H的联想文件转换为词典文件)
		MOV	DX,OFFSET D_LXH 	;'请键入2.13H联想库文件名:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入文件名
		JNB	L_5010
		JMP	BEGIN
L_5010:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_5012:
		LODSB
		OR	AL,AL			;找尾?
		JNZ	L_5012
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;形成文件名

		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_5014
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_5014:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'请键入词典文件名:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;键入词典文件名
		JNB	L_5020
		JMP	BEGIN
L_5020:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;读全部联想库文件
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;词组个数
		MOV	SI,120H 		;联想字首
		MOV	BP,CX
		SHL	BP,1
		SHL	BP,1
		ADD	BP,SI			;联想内容首
		MOV	DI,OFFSET D_STR 	;词典一行区首
		MOV	CS:D_CX,0		;	 计数
L_5050:
		MOV	DL,[SI+3]		;联想内容长度
		XOR	DH,DH

		CMP	CX,DS:[11EH]		;首词?
		JZ	L_5080
		MOV	AX,CS:D_CX		;计数
		ADD	AX,DX			;累加
		ADD	AX,2
		CMP	AL,78			;判满一行?
		JBE	L_5070
		CALL	S_WLINE
		MOV	CS:D_CX,0		;清0
		JMP	SHORT L_5080
L_5070:
		MOV	AL,','                  ;分隔符
		STOSB
L_5080:
		LODSW				;写入首字
		STOSW
		ADD	SI,2
		MOV	DH,DL
		SHR	DH,1
L_5090:
		MOV	AX,DS:[BP]
		ADD	BP,2
		STOSW				;写入内容
		DEC	DH
		JNZ	L_5090

		MOV	AX,CS:D_CX
		ADD	AX,3
		ADD	AX,DX
		MOV	CS:D_CX,AX
		LOOP	L_5050
		CALL	S_WLINE1		;写入末行

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;----------------------------------------------------------------------------
D_CZH		DB	'请键入2.13H词组文件名(不要扩展名): $'
L_6000:
		CMP	AL,5
		JZ	L_6001
		JMP	L_6600
L_6001: 	; 老词组转换 (将2.13H的词组文件转换为词典文件)
		MOV	DX,OFFSET D_CZH 	;'请键入2.13H词组文件名:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入文件名
		JNB	L_6010
		JMP	BEGIN
L_6010:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_6012:
		LODSB
		OR	AL,AL			;找尾?
		JNZ	L_6012
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;形成文件名

		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_6014
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_6014:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'请键入词典文件名:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;键入词典文件名
		JNB	L_6020
		JMP	BEGIN
L_6020:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;读全部词组文件
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;词组个数
		MOV	SI,120H 		;外码区首
		MOV	BP,CX
		SHL	BP,1
		SHL	BP,1
		ADD	BP,SI			;内码区首
		MOV	DI,OFFSET D_STR
		MOV	CS:D_CX,0
L_6060:
		MOV	DL,[SI+3]		;内码长度
		XOR	DH,DH

		CMP	SI,120H 		;首词?
		JZ	L_6080
		MOV	AX,CS:D_CX
		ADD	AX,DX
		CMP	AL,78
		JBE	L_6070
		CALL	S_WLINE
		MOV	CS:D_CX,0		;清0
		JMP	SHORT L_6080
L_6070:
		MOV	AL,','                  ;分隔符
		STOSB
L_6080:
		ADD	SI,4
		MOV	AX,CS:D_CX
		ADD	AX,DX
		INC	DX
		MOV	CS:D_CX,AX
L_6090:
		MOV	AL,DS:[BP]
		INC	BP
		STOSB
		DEC	DL
		JNZ	L_6090
		LOOP	L_6060
		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;----------------------------------------------------------------------------
L_6600:
		CMP	AL,6
		JZ	L_6601
		JMP	L_7000
L_6601: 	; 老词组转换 (将2.13H的词组文件转换为编码词典)
		MOV	DX,OFFSET D_CZH 	;'请键入2.13H词组文件名:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入文件名
		JNB	L_6610
		JMP	BEGIN
L_6610:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_6612:
		LODSB
		OR	AL,AL			;找尾?
		JNZ	L_6612
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;形成文件名

		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_6614
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_6614:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'请键入词典文件名:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;键入词典文件名
		JNB	L_6620
		JMP	BEGIN
L_6620:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;读全部词组文件
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;词组个数
		MOV	SI,120H 		;外码区首
		MOV	BP,CX
		SHL	BP,1
		SHL	BP,1
		ADD	BP,SI			;内码区首
		MOV	DI,OFFSET D_STR
		MOV	CS:D_CX,0
L_6660:
		MOV	DL,[SI+3]		;内码长度
		XOR	DH,DH

		CMP	SI,120H 		;首词?
		JZ	L_6680
		MOV	AX,CS:D_CX
		ADD	AX,DX
		CMP	AL,78
		JBE	L_6670
		CALL	S_WLINE
		MOV	CS:D_CX,0		;清0
		JMP	SHORT L_6680
L_6670:
		MOV	AL,','                  ;分隔符
		STOSB
L_6680:
		LODSW
		STOSW				;存编码
		LODSB
		STOSB
		INC	SI
		MOV	AX,CS:D_CX
		ADD	AX,DX
		INC	DX
		MOV	CS:D_CX,AX
L_6690:
		MOV	AL,DS:[BP]
		INC	BP
		STOSB				;存词组
		DEC	DL
		JNZ	L_6690
		LOOP	L_6660
		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;----------------------------------------------------------------------------
D_LXK		DB	'请键入2.13K联想库文件名: $'
L_7000:
		CMP	AL,7
		JZ	L_7001
		JMP	L_8000
L_7001: 	; 新联想转换 (将2.13K的联想文件转换为词典文件)
		MOV	DX,OFFSET D_LXH 	;'请键入2.13K联想库文件名:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入文件名
		JNB	L_7010
		JMP	BEGIN
L_7010:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_7012:
		LODSB
		OR	AL,AL			;找尾?
		JNZ	L_7012
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;形成文件名

		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_7014
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_7014:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'请键入词典文件名:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;键入词典文件名
		JNB	L_7020
		JMP	BEGIN
L_7020:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;读全部联想库文件
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;词组个数
		MOV	SI,120H 		;联想字首
		MOV	BP,CX
		ADD	BP,SI			;联想内容首
		MOV	DI,OFFSET D_STR 	;词典一行区首
		MOV	CS:D_CX,0		;	 计数
L_7050:
		LODSB				;联想内容长度
		XOR	AH,AH
		MOV	DX,AX

		CMP	CX,DS:[11EH]		;首词?
		JZ	L_7080
		MOV	AX,CS:D_CX		;计数
		ADD	AX,DX			;累加
		INC	AX
		CMP	AL,78			;判满一行?
		JBE	L_7070
		CALL	S_WLINE
		MOV	CS:D_CX,0		;清0
		JMP	SHORT L_7080
L_7070:
		MOV	AL,','                  ;分隔符
		STOSB
L_7080:
		PUSH	DX
		MOV	AX,DS:[BP]
		ADD	BP,2
		OR	AX,8080H
		STOSW
		SUB	DX,2
L_7090:
		MOV	AL,DS:[BP]
		INC	BP
		STOSB
		DEC	DX
		JNZ	L_7090
		POP	DX

		MOV	AX,CS:D_CX
		ADD	AX,DX
		INC	AX
		MOV	CS:D_CX,AX
		LOOP	L_7050
		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;----------------------------------------------------------------------------
D_CZK		DB	'请键入2.13K词组文件名(不要扩展名): $'
L_8000:
		CMP	AL,8
		JZ	L_8001
		JMP	L_8600
L_8001: 	; 新词组转换 (将2.13K的词组文件转换为词典文件)
		MOV	DX,OFFSET D_CZK 	;'请键入2.13K词组文件名:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入文件名
		JNB	L_8010
		JMP	BEGIN
L_8010:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_8012:
		LODSB
		OR	AL,AL			;找尾?
		JNZ	L_8012
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;形成文件名

		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_8014
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_8014:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'请键入词典文件名:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;键入词典文件名
		JNB	L_8020
		JMP	BEGIN
L_8020:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;读全部词组文件
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;词组个数
		MOV	BP,120H 		;外码区首
		MOV	SI,CX
		ADD	SI,BP			;内码区首
		MOV	DI,OFFSET D_STR
		MOV	CS:D_CX,0
L_8060:
		MOV	AL,DS:[BP]		;内码长度
		INC	BP
		MOV	DH,AL
		XOR	DL,DL
		PUSH	DI
		MOV	DI,OFFSET D_BUF1
L_8062:
		LODSB				;查找编码尾
		SUB	DH,1
		CMP	AL,'`'
		JB	L_8064
		CMP	AL,'z'
		JBE	L_8062
L_8064:
		STOSB
		INC	DL
		LODSB
		SUB	DH,1
		JNB	L_8064
		XOR	DH,DH
		DEC	SI
		POP	DI

		CMP	CX,DS:[11EH]		;首词?
		JZ	L_8080
		MOV	AX,CS:D_CX
		ADD	AX,DX
		INC	AX
		CMP	AL,78
		JBE	L_8070
		CALL	S_WLINE
		MOV	CS:D_CX,0		;清0
		JMP	SHORT L_8080
L_8070:
		MOV	AL,','                  ;分隔符
		STOSB
L_8080:
		MOV	AX,CS:D_CX
		ADD	AX,DX
		INC	AX
		MOV	CS:D_CX,AX
		PUSH	SI
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	SI,OFFSET D_BUF1
L_8090:
		LODSB
		STOSB
		DEC	DX
		JNZ	L_8090
		POP	DS
		POP	SI
		LOOP	L_8060

		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;----------------------------------------------------------------------------
L_8600:
		CMP	AL,9
		JZ	L_8601
		JMP	L_9000
L_8601: 	; 新词组转换 (将2.13K的词组文件转换为编码词典)
		MOV	DX,OFFSET D_CZK 	;'请键入2.13K词组文件名:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入文件名
		JNB	L_8610
		JMP	BEGIN
L_8610:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_8612:
		LODSB
		OR	AL,AL			;找尾?
		JNZ	L_8612
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;形成文件名

		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_8614
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_8614:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'请键入词典文件名:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;键入词典文件名
		JNB	L_8620
		JMP	BEGIN
L_8620:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;读全部词组文件
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;词组个数
		MOV	SI,120H 		;外码区首
		MOV	BP,CX
		ADD	BP,SI			;内码区首
		MOV	DI,OFFSET D_STR
		MOV	CS:D_CX,0
		MOV	WORD PTR DS:[0],0A0DH
L_8660:
		LODSB				;内码长度
		MOV	DL,AL
		XOR	DH,DH
		PUSH	CX
		PUSH	DX
		MOV	CX,DX
		MOV	DX,BP
		MOV	AH,40H
		INT	21H
		XOR	DX,DX
		MOV	CX,2
		MOV	AH,40H
		INT	21H
		POP	DX
		POP	CX
		ADD	BP,DX
		LOOP	L_8660
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_1A
		MOV	CX,1
		MOV	AH,40H
		INT	21H
		MOV	AH,3EH
		INT	21H
		JMP	BEGIN
;----------------------------------------------------------------------------
L_9000:
		CMP	AL,10
		JZ	L_9001
		JMP	L_10000
L_9001: 	; 双拼词组转换(将SPCZ.DAT转换为词典文件CK.DAT)
		MOV	DX,OFFSET D_SPCZ	;双拼词组文件
		MOV	AX,3D00H		;打开
		INT	21H
		JNB	L_9010
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_9010:
		MOV	BX,AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX			;下一段
		XOR	DX,DX
		MOV	CX,-1
		MOV	AH,3FH			;读文件
		INT	21H
		MOV	SI,AX
		MOV	WORD PTR [SI],0 	;读出区尾加0
		MOV	AH,3EH			;关闭
		INT	21H

		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_CK		;'CK.DAT'
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		MOV	BX,AX
		POP	DS

		MOV	SI,16			;二字词首
		MOV	DI,OFFSET D_STR 	;输出行区
L_9020:
		LODSW				;取首字
		OR	AX,8080H
		STOSW
		MOV	AL,':'
		STOSB
L_9030:
		TEST	WORD PTR [SI],8080H	;判下一首字
		JZ	L_9040
		LODSW
		STOSW				;存第二字
		JMP	SHORT L_9030
L_9040:
		CALL	S_WLINE
		CMP	SI,DS:[0]		;判三字词首?
		JB	L_9020

		XOR	BP,BP			;计数
L_9050:
		CMP	BP,73			;行满?
		JB	L_9060
		CALL	S_WLINE 		;写入
		XOR	BP,BP
L_9060:
		OR	BP,BP
		JZ	L_9070
		MOV	AL,','
		STOSB
		INC	BP
L_9070:
		LODSW				;取首字
		OR	AX,8080H
		STOSW				;存首字
		LODSW
		STOSW				;存第二字
		LODSW
		STOSW				;存第三字
		ADD	BP,6
		CMP	SI,DS:[2]		;判多字词首?
		JB	L_9050
		CALL	S_WLINE

		XOR	BP,BP
L_9100:
		PUSH	SI
		XOR	DX,DX			;			3.15
L_9110:
		LODSB
		CMP	AL,','                  ;判词尾?
		JZ	L_9120
		INC	DX
		JMP	SHORT L_9110
L_9120:
		POP	SI
		ADD	DX,BP			;累计
		CMP	DX,78			;判满?
		JBE	L_9130
		CALL	S_WLINE
		XOR	BP,BP
L_9130:
		OR	BP,BP			;行首?
		JZ	L_9140
		MOV	AL,','
		STOSB
		INC	BP
L_9140:
		LODSB				;			3.15
		CMP	AL,','                  ;判词尾?
		JZ	L_9160
		STOSB
		INC	BP
		JMP	SHORT L_9140
L_9160:
		CMP	SI,DS:[4]		;扩展区首
		JB	L_9100
		CALL	S_WLINE1
		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN
;----------------------------------------------------------------------------
D_CDK		DB	'请键入2.13K词典文件名: $'
L_10000:
		CMP	AL,11
		JZ	L_10001
		JMP	L_11000
L_10001:	; 词典格式转换(原词典文件转换为专用格式CK.DAT)
		MOV	DX,OFFSET D_CDK 	;'请键入2.13K词典文件名:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;键入词典文件名
		JNB	L_10010
		JMP	BEGIN
L_10010:
		MOV	DX,OFFSET D_INPUT+2	;词典文件名首
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_10020
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_10020:
		MOV	D_HAN,AX

		MOV	DX,OFFSET D_CK		;'CK.DAT',0
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		MOV	BX,AX

		MOV	D_DI,OFFSET D_BUF
		MOV	DI,OFFSET D_STR
		XOR	BP,BP
		CALL	S_READ			;读词典文件32K
		JNB	L_10022
		MOV	BX,D_HAN
		MOV	AH,3EH
		JMP	BEGIN
L_10022:
		XOR	DX,DX
L_10030:
		CALL	S_GETSTR		;取得字符串SI
		JNB	L_10040
		JMP	L_10100
L_10040:
		CMP	CX,4			;判二字词?
		JNZ	L_10060
		LODSW				;取第一字
		CMP	AX,DX			;判同首字?
		JZ	L_10050
		OR	DX,DX
		JZ	L_10044
		PUSH	AX
		CALL	S_WLINE 		;写入一行
		POP	AX
L_10044:
		MOV	DX,AX			;置首字
		STOSW
		MOV	AL,':'
		STOSB
L_10050:
		LODSW				;取第二字
		STOSW
		JMP	SHORT L_10030
L_10060:
		CALL	S_WLINE

	;	MOV	DI,OFFSET D_STR
		XOR	BP,BP
		JMP	SHORT L_10080
L_10070:
		CALL	S_GETSTR
		JB	L_10100
L_10080:
		MOV	AX,BP
		ADD	AX,CX
		INC	AX
		CMP	AX,78
		JBE	L_10090
		CALL	S_WLINE
		XOR	BP,BP
L_10090:
		OR	BP,BP
		JZ	L_10091
		MOV	AL,','
		STOSB
L_10091:
		ADD	BP,CX
		INC	BP
		REP	MOVSB
		JMP	SHORT L_10070
L_10100:
		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		JMP	BEGIN
;----------------------------------------------------------------------------
L_11000:
		CMP	AL,12
		JZ	L_11001
		MOV	AX,600H 		;局部清屏
		XOR	BX,BX
		MOV	CX,1000H
		MOV	DX,174FH
		INT	10H
		JMP	L_150
L_11001:	; 建双拼词组(用CK.DAT建立双拼词组文件SPCZ.DAT)
		MOV	DX,OFFSET D_CK		;'CK.DAT',0
		MOV	AX,3D00H
		INT	21H
		JNB	L_11010
L_11002:
		MOV	DX,OFFSET NOCKDAT	;			11.6
L_11005:
		MOV	AH,9			;			11.5
		INT	21H
		XOR	AH,AH
		INT	16H
		JMP	BEGIN
L_11010:
		MOV	D_HAN,AX

		MOV	AX,CS
		ADD	AX,1000H		;下一段
		MOV	ES,AX
		XOR	DI,DI
		MOV	CX,16
		XOR	AL,AL
		REP	STOSB			;16个空格

		MOV	D_DI,OFFSET D_BUF
		CALL	S_READ			;读词典文件32K
		JNB	L_11020
		MOV	BX,D_HAN
		MOV	AH,3EH
		JMP	SHORT L_11002
L_11020:
		CALL	S_GETLINE		;取一行SI,CX=长度
		CMP	BYTE PTR [SI+2],':'     ;判二字词?
		JNZ	L_11030
		LODSW				;首字
		AND	AX,7F7FH		;去高位
		STOSW
		INC	SI
		SUB	CX,3
		TEST	CL,1			;奇数:有字符?		11.5
		JZ	L_11022
		MOV	DX,OFFSET NOALLHZ
		JMP	SHORT L_11005
L_11022:
		MOV	AX,CX
		SHR	AX,1
		ADD	BP,AX
		REP	MOVSB			;存
		JMP	SHORT L_11020
L_11030:
		MOV	SI,D_DI 		;下一行首
		MOV	WORD PTR [SI-2],0A0DH	;恢复ODOA
		ADD	CX,2
		SUB	D_DI,CX
		MOV	ES:[0],DI		;三字词首
L_11040:
		CALL	S_GETSTR		;取一词
		CMP	CL,6
		JNZ	L_11050
		LODSW				;首字
		AND	AX,7F7FH
		STOSW				;存
		LODSW
		STOSW
		LODSW
		STOSW
		INC	BP
		JMP	SHORT L_11040
L_11050:
		MOV	ES:[2],DI		;多字词首
		JMP	SHORT L_11070
L_11060:
		CALL	S_GETSTR		;取一词
		JB	L_11080
L_11070:
		REP	MOVSB			;存			3.15
		MOV	AL,','
		STOSB
		INC	BP
		JMP	SHORT L_11060
L_11080:
		MOV	ES:[4],DI		;多字词尾
		MOV	ES:[6],DI		;扩展区尾
		MOV	BYTE PTR ES:[0FH],0FFH	;新SPCZ.DAT标志 	3.15

		MOV	DX,OFFSET D_SPCZ	;SPCZ.DAT',0
		MOV	CX,20H
		MOV	AH,3CH
		INT	21H
		MOV	BX,AX

		PUSH	ES
		POP	DS
		XOR	DX,DX
		MOV	CX,DI
		MOV	AH,40H			;写入文件
		INT	21H
		MOV	AH,3EH			;关闭文件
		INT	21H

		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	D_CX,BP 		;词组数 		11.5
		MOV	D_K,DI			;总长度
		CALL	S_ZJ			;显示
		XOR	AH,AH
		INT	16H
		JMP	BEGIN
;通用子程序==================================================================
;子程序:清屏
S_CLS		PROC	NEAR
		MOV	AX,600H
		XOR	BX,BX
		XOR	CX,CX
		MOV	DX,184FH
		INT	10H
		RET
S_CLS		ENDP

;子程序:回车换行
S_0D0A		PROC	NEAR
		MOV	AX,0E0DH
		INT	10H
		MOV	AX,0E0AH
		INT	10H
		RET
S_0D0A		ENDP

;子程序:显示菜单 D_X:序号(0-12)
S_XSCD		PROC	NEAR
		MOV	BX,4EH
		MOV	AL,D_X
		MOV	D_X1,AL
		JMP	SHORT L_XC1
S_XSCD1:
		MOV	BX,7
		MOV	AL,D_X1
L_XC1:
		MOV	DH,AL
		ADD	DH,2
		MOV	DL,16
		MOV	AH,47
		MUL	AH
		ADD	AX,OFFSET D_MENU
		MOV	SI,AX

;子程序:显示字符串SI,DX=串首位置,BL=属性.显示后光标在串尾
S_XSZF:
L_XZ1:
		MOV	AH,2
		INT	10H
		LODSB
		OR	AL,AL
		JZ	L_XZ2
		MOV	AH,9
		MOV	CX,1
		INT	10H
		INC	DX
		JMP	SHORT L_XZ1
L_XZ2:
		RET
S_XSCD		ENDP

S_KGB		PROC	NEAR
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		RET
S_KGB		ENDP

;子程序:计算并显示
S_ZJ		PROC	NEAR
		MOV	SI,OFFSET D_ZJ+13
		MOV	AX,D_CX 		;词组个数
		MOV	CX,5
		CALL	S_JS
		MOV	SI,OFFSET D_ZJ+29
		MOV	AX,D_K
		MOV	CX,5
		CALL	S_JS
		MOV	SI,OFFSET D_ZJ		;'总计词组    个,总长度     字节'
L_ZJ1:
		LODSB
		CMP	AL,'$'
		JZ	L_ZJ2
		OR	AL,AL
		JZ	L_ZJ1
		MOV	DL,AL
		MOV	AH,2
		INT	21H
		JMP	SHORT L_ZJ1
L_ZJ2:
		RET
S_JS:
		MOV	DI,10
L_JS1:
		XOR	DX,DX
		DIV	DI
		OR	DL,DL
		JNZ	L_JS2
		OR	AL,AL
		JZ	L_JS3
L_JS2:
		OR	DL,30H
L_JS3:
		MOV	[SI],DL
		DEC	SI
		LOOP	L_JS1
		RET
S_ZJ		ENDP

;子程序:键入文件名->D_INPUT+2
S_INFILE	PROC	NEAR
		MOV	SI,OFFSET D_INPUT+2	;键入缓冲区
L_IN1:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,0DH			;回车?
		JZ	L_IN6
		CMP	AL,1BH			;<ESC>
		JZ	L_IN7
		CMP	AL,8			;退格?
		JNZ	L_IN5
		CMP	SI,OFFSET D_INPUT+2	;指针在区首?
		JA	L_IN3
L_IN2:
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_IN1
L_IN3:
		DEC	SI			;位置-1
L_IN4:
		MOV	DL,AL
		MOV	AH,2			;显示
		INT	21H
		CMP	AL,8			;退格?
		JNZ	L_IN1
		MOV	CX,1
		MOV	AL,20H			;显示空格
		JMP	SHORT L_IN4
L_IN5:
		MOV	[SI],AL 		;写入
		INC	SI
		JMP	SHORT L_IN4		;显示
L_IN6:
		CALL	S_0D0A
		CMP	SI,OFFSET D_INPUT+2
		JZ	L_IN7
		MOV	BYTE PTR [SI],0
		CLC
		RET
L_IN7:
		STC
		RET
S_INFILE	ENDP

;子程序:得到字符串SI,CX=长度,D_DI=下一字符串首
S_GETSTR	PROC	NEAR
		MOV	BYTE PTR K_LINE,OFFSET L_GS6-OFFSET L_GS3A
		JMP	SHORT L_GSA
S_GETLINE:
		MOV	BYTE PTR K_LINE,0
L_GSA:
		MOV	D_0D,0
		PUSH	DI
		MOV	DI,D_DI
		XOR	CX,CX
		MOV	SI,DI			;本字符串首
		CMP	SI,D_END		;判到读出区尾?
		JB	L_GS1
		CALL	S_READ			;读32K
		JNB	L_GS1
L_GS0:
		POP	DI
		STC
		RET
L_GS1:
		MOV	DI,SI			;指向区首
L_GS2:
		CMP	SI,D_END		;判到读出区尾?
		JB	L_GS3
		PUSH	CX
		MOV	CX,D_END
		SUB	CX,DI			;本字符串已处理长
		MOV	SI,DI			;	 首
		MOV	DI,OFFSET D_BUF
		SUB	DI,CX			;移动地址
		PUSH	DI
		PUSH	ES
		PUSH	CS
		POP	ES
		REP	MOVSB			;未完串移BUF区前
		POP	ES
		POP	DI
		POP	CX
		CALL	S_READ			;读32K
		JB	L_GS0
L_GS3:
		LODSB				;取一字符
		CMP	AL,','                  ;分隔符?
		JZ	L_GS6
K_LINE	EQU	$-1
L_GS3A:
		CMP	AL,0DH			;回车?
		JNZ	L_GS5
		CMP	D_0D,0AH		;已有换行?
		JZ	L_GS6
L_GS4:
		MOV	BYTE PTR [SI-1],0
		MOV	D_0D,AL 		;存
		JMP	SHORT L_GS2
L_GS5:
		CMP	AL,0AH			;换行?
		JNZ	L_GS7
		CMP	D_0D,0DH		;已有回车?
		JNZ	L_GS4
L_GS6:
		MOV	BYTE PTR [SI-1],0
		XCHG	SI,DI			;
		MOV	D_DI,DI
		POP	DI
		CLC
		RET
L_GS7:
		INC	CX			;串长+1
		JMP	SHORT L_GS2
S_GETSTR	ENDP

;子程序:读词典文件32K->D_BUF,D_END=读出区尾
S_READ		PROC	NEAR
		PUSH	BX
		PUSH	CX
		MOV	BX,D_HAN
		MOV	DX,OFFSET D_BUF
		MOV	SI,DX
		MOV	CX,8000H		;32K
		MOV	AH,3FH			;读文件
		INT	21H
		OR	AX,AX
		JZ	L_READ1
		ADD	AX,SI
		MOV	D_END,AX
		POP	CX
		POP	BX
		CLC
		RET
L_READ1:
		POP	CX
		POP	BX
		STC
		RET
S_READ		ENDP

;子程序:取汉字AX拼音码AL,AH
S_PYM		PROC	NEAR
		MOV	DX,AX
		MOV	AH,22H
		INT	16H
		RET
S_PYM		ENDP

D_STR	EQU	$
D_BUF	EQU	$+512
D_BUF1	EQU	D_BUF+8000H

CSEG		ENDS
		END	START

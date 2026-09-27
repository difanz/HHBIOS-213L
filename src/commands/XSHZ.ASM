;	XSHZ.ASM
;	1996.12.10
;	1997.3.12, 7.31

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

D_BT		DB	'┏━━━━━━━━━━━━━━━━━━━━━━━━━┓',13,10
		DB	'┃    显  示  各  区  汉  字  或  图  形  符  号    ┃',13,10
		DB	'┠─────────────────────────┨',13,10
		DB	'┃1-点阵, 2-矢量, ESC-退出, Y-显示并打印,其他-仅显示┃',13,10
		DB	'┗━━━━━━━━━━━━━━━━━━━━━━━━━┛$'
D_TS		DB	'ESC-重选区号,退格-上一区,其他-下一区',0
D_QH		DB	10,13,'区号: $'
D_QIN		DB	3,0,'  ',0
D_QW		DB	10,13
D_QW1		DB	'第16区 ０ １ ２ ３ ４ ５ ６ ７ ８ ９ ',10,13
		DB	'  1600    啊 阿 埃 挨 哎 唉 哀 皑 癌 ',10,13
		DB	'  1610 蔼 矮 艾 碍 爱 隘 鞍 氨 安 俺 ',10,13
		DB	'  1620 按 暗 岸 胺 案 肮 昂 盎 凹 敖 ',10,13
		DB	'  1630 熬 翱 袄 傲 奥 懊 澳 芭 捌 扒 ',10,13
		DB	'  1640 叭 吧 笆 八 疤 巴 拔 跋 靶 把 ',10,13
		DB	'  1650 耙 坝 霸 罢 爸 白 柏 百 摆 佰 ',10,13
		DB	'  1660 败 拜 稗 斑 班 搬 扳 般 颁 板 ',10,13
		DB	'  1670 版 扮 拌 伴 瓣 半 办 绊 邦 帮 ',10,13
		DB	'  1680 梆 榜 膀 绑 棒 磅 蚌 镑 傍 谤 ',10,13
		DB	'  1690 苞 胞 包 褒 剥                ',10,13,'$'
D_PRT		DB	0			;打印标志
D_CD		DW	0			;菜单地址
;****************************************************************************
BEGIN:
		MOV	DX,OFFSET D_BT		;显示'显示各区汉字或图形符号'
		MOV	AH,9			;
		INT	21H
		MOV	AH,1			;按键
		INT	21H
		CMP	AL,1BH
		JNZ	L_0
		MOV	AX,4C00H
		INT	21H
L_0:
		CMP	AL,'1'                  ;点阵
		JNZ	L_1
		JMP	L_100
L_1:
		CMP	AL,'2'                  ;矢量
		JNZ	L_2
		JMP	L_200
L_2:
		CMP	AL,'y'
		JNZ	L_3
		MOV	AL,'Y'
L_3:
		MOV	D_PRT,AL		;打印标志
L_10:
		MOV	DX,OFFSET D_QH		;显示'区号: '
		MOV	AH,9
		INT	21H
		MOV	DX,OFFSET D_QIN
		MOV	SI,DX
		MOV	AH,0AH			;键入区号
		INT	21H
		INC	SI
		MOV	CL,[SI]
		OR	CL,CL
		JNZ	L_20
L_EXIT:
		MOV	AX,4C00H
		INT	21H
L_20:
		XOR	CH,CH
L_22:
		INC	SI
		MOV	AL,10
		MUL	CH
		MOV	AH,[SI]
		AND	AH,0FH
		ADD	AL,AH
		MOV	CH,AL
		DEC	CL
		JNZ	L_22
		OR	AL,AL
		JZ	L_10
		CMP	AL,94
		JA	L_10
		MOV	D_Q,AL			;区号
L_30:
		XOR	AH,AH
		MOV	CL,10
		DIV	CL
		OR	AX,3030H
		MOV	SI,OFFSET D_QW1+2
		MOV	CX,11
L_33:
		MOV	[SI],AX 		;写入区号
		ADD	SI,39
		LOOP	L_33

		MOV	DI,OFFSET D_QW1+39
		MOV	BL,10
		XOR	DH,DH			;位号
L_40:
		ADD	DI,7
		MOV	BH,10
L_42:
		CMP	DH,94
		JA	L_44
		OR	DH,DH
		JNZ	L_46
L_44:
		MOV	AX,'  '
		JMP	SHORT L_48
L_46:
		MOV	DL,D_Q			;区号
		MOV	AX,DX
		ADD	AX,0A0A0H		;汉字内码
L_48:
		STOSW				;写入
		INC	DI
		INC	DH
		DEC	BH
		JNZ	L_42
		ADD	DI,2
		DEC	BL
		JNZ	L_40

		MOV	DX,OFFSET D_QW
		MOV	AH,9			;显示该区汉字
		INT	21H

		CMP	D_PRT,'Y'               ;打印标志
		JNZ	L_60
		MOV	SI,OFFSET D_QW		;输出区首
L_50:
		LODSB
		CMP	AL,'$'
		JZ	L_60
		MOV	DL,AL
		MOV	AH,5			;打印
		INT	21H
		JMP	SHORT L_50
L_60:
		XOR	BH,BH
		MOV	AH,3
		INT	10H
		MOV	BP,OFFSET D_TS
		MOV	BL,1EH
		MOV	AX,1304H
		INT	10H

		XOR	AH,AH			;取按键
		INT	16H
		CMP	AL,1BH			;ESC
		JNZ	L_70
		JMP	L_10
L_70:
		MOV	DL,D_Q
		CMP	AL,8			;退格键?
		JNZ	L_80
		DEC	DL
		OR	DL,DL
		JNZ	L_90
L_80:
		INC	DL			;区号+1
		CMP	DL,95
		JB	L_90
		MOV	DL,1
L_90:
		MOV	D_Q,DL
		MOV	AL,DL
		JMP	L_30

;============================================================================
D_MODE		DB	3
D_XZT		DB	' <ESC> - 退出, <回车> - 选中',0
D_XQH		DB	'<ESC>-选字体, <空格>-选区, <退格>-上一区, 其他键-下一区',0
D_INQH		DB	'开始区号: ',0

D_R1		DB	14,'R1]',0
D_XSQH		DB	14,'[\0&4^1_|*15@A第 ',0
D_XSQH1 	DB	' 区 @',0
D_XSH		DB	14,'[',0
D_ZT		DB	'B',0,0,0,'F',0,0,0,'J',0,0,0,'N',0,0,0
		DB	'3111','3211','3311','3411'
		DB	'4111','4211','4311','4411'
D_XS		DB	'宋体(24)',0,'仿宋(24)',0,'黑体(24)',0,'楷体(24)',0
		DB	'宋体(32)',0,'仿宋(32)',0,'黑体(32)',0,'楷体(32)',0
		DB	'宋体(40)',0,'仿宋(40)',0,'黑体(40)',0,'楷体(40)',0
D_X		DB	0			;主菜单当前行
D_X1		DB	0
D_Q		DB	0			;区号
D_C		DB	1			;色号
NOINT10 	DB	13,10,'未安装特殊显示模块 INT10L 或 INT10K!',7,13,10,10,'$'
NOREAD32	DB	13,10,'未安装读32点阵字库模块 READ32!',7,13,10,10,'$'
NOREAD40	DB	13,10,'未安装读40点阵字库模块 READ40!',7,13,10,10,'$'

L_100:
		MOV	AX,1903H		;取特显模块安装状态?
		INT	10H
		CMP	AL,83H			;判INT10L?
		JZ	L_101
		CMP	AL,84H			;判INT10K?
		JZ	L_101
		MOV	DX,OFFSET NOINT10
		JMP	L_ERR
L_101:
		MOV	AX,OFFSET D_XS
		MOV	D_CD,AX

		MOV	AX,1406H		;取显示参数
		INT	10H
		CMP	BL,4			;判直接写屏
		JNZ	L_108
		MOV	AL,3
L_108:
		MOV	D_MODE,AL
		MOV	D_X,0
L_109:
		CALL	S_CLS			;清屏
		MOV	SI,OFFSET D_XZT 	;' <ESC> - 退出, <回车> - 选中'
		MOV	DX,1814H
		MOV	BL,1EH
		CALL	S_XSZF
		MOV	D_X1,0
L_110:
		CALL	S_XSCD1 		;显示菜单条
		INC	D_X1
		CMP	D_X1,12
		JB	L_110
		MOV	AL,D_X
		MOV	D_X1,AL
		CALL	S_GGB			;关光标
L_112:
		CALL	S_XSCD			;显示菜单
L_120:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AH,72			;↑
		JNZ	L_130
		CMP	D_X,0
		JNZ	L_121
		MOV	D_X,11
		JMP	SHORT L_122
L_121:
		DEC	D_X
L_122:
		CALL	S_XSCD1 		;清菜单
		JMP	SHORT L_110
L_130:
		CMP	AH,80			;↓
		JNZ	L_140
		CMP	D_X,11
		JB	L_131
		MOV	D_X,0
		JMP	SHORT L_122
L_131:
		INC	D_X
		JMP	SHORT L_122
L_140:
		CMP	AL,1BH			;ESC?
		JNZ	L_150
		CALL	S_CLS			;清屏
		CALL	S_KGB			;开光标
		JMP	L_EXIT
L_150:
		CMP	AL,0DH			;回车?
		JNZ	L_120
L_155:
		CALL	S_KGB			;开光标

		CMP	D_X,3
		JBE	L_159
		CMP	D_X,7
		JBE	L_157
		MOV	AX,357EH		;取中断7E
		INT	21H
		OR	BX,BX			;判安装READ40?
		JNZ	L_159
		MOV	DX,OFFSET NOREAD40
		JMP	L_ERR
L_157:
		MOV	AX,357EH		;取中断7E
		INT	21H
		OR	BX,BX			;判安装READ40?
		JZ	L_158
		XOR	BX,BX
		XOR	DX,DX			;取READSL安装状态?
		INT	7EH
		OR	BX,BX			;判READSL?
		JZ	L_159
L_158:
		MOV	DX,OFFSET NOREAD32
		JMP	L_ERR
L_159:
		MOV	SI,OFFSET D_XQH 	;'<ESC>-选字体, <空格>-选区, <退格>-上一区, 其他键-下一区'
		MOV	DX,180FH
		MOV	BL,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_INQH	;'开始区号: '
		MOV	DX,1800H
		MOV	BL,7
		CALL	S_XSZF
		CALL	S_INQH			;键入区号
		MOV	D_Q,AL
		JNB	L_160
		MOV	SI,OFFSET D_R1		;14,'R1]'
		CALL	S_TX
		JMP	L_109
L_160:
		CALL	S_GGB
		MOV	SI,OFFSET D_XSQH	;14,'[\0&4^1_|*15@A第 '
		CALL	S_TX
		MOV	AL,D_Q
		CALL	S_TXQH			;区号按字符输出
		MOV	SI,OFFSET D_XSQH1	;' 区@'
		CALL	S_TX
		MOV	AL,D_X			;字体序号
		MOV	DX,0909H
		CMP	AL,8
		JB	L_170
		MOV	DX,0B07H
L_170:
		MOV	BYTE PTR K_2,DH
		INC	DH
		MOV	BYTE PTR K_1,DH
		MOV	BYTE PTR K_3,DL

		CBW
		SHL	AX,1
		SHL	AX,1
		ADD	AX,OFFSET D_ZT		;字体号区
		MOV	SI,AX
		MOV	AH,9
		LODSB
		INT	10H
		LODSB
		OR	AL,AL
		JZ	L_177
		INT	10H
		LODSB
		INT	10H
		LODSB
		INT	10H
L_177:
		MOV	AL,']'
		INT	10H

		MOV	DL,0			;十位数
L_180:
		MOV	SI,OFFSET D_XSH 	;14,'['
		CALL	S_TX

		MOV	DH,0			;个位数
L_182:
		MOV	AL,10
K_1	EQU	$-1
		MUL	DL
		ADD	AL,DH			;位号
		OR	AL,AL			;=0?
		JNZ	L_184
		MOV	AL,' '
		MOV	AH,9
		INT	10H			;双空格
		INT	10H
		JMP	SHORT L_186
L_184:
		CMP	AL,94			;>94?
		JA	L_186
		PUSH	AX
		MOV	AL,'*'
		MOV	AH,9
		INT	10H
		MOV	AL,D_C
		ADD	AL,8
		CALL	S_TXQH
		INC	D_C
		CMP	D_C,8
		JNZ	L_185
		MOV	D_C,1
L_185:
		POP	AX
		PUSH	AX
		MOV	AL,D_Q
		ADD	AL,160			;前字节
		MOV	AH,9
		INT	10H
		POP	AX
		ADD	AL,160			;后字节
		MOV	AH,9
		INT	10H
L_186:
		INC	DH			;个位+1
		CMP	DH,9
K_2	EQU	$-1
		JBE	L_182
		MOV	AL,']'
		MOV	AH,9
		INT	10H

		MOV	AH,1
		INT	16H
		JNZ	L_190

		INC	DL			;十位+1
		CMP	DL,9
K_3	EQU	$-1
		JBE	L_180
L_190:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,1BH			;<ESC>?
		JNZ	L_192
		JMP	L_109
L_192:
		CMP	AL,' '                  ;空格?
		JNZ	L_194
		JMP	L_155
L_194:
		CMP	AL,8			;退格?
		JNZ	L_196
		DEC	D_Q
		CMP	D_Q,15
		JA	L_198
		MOV	D_Q,87
		JMP	L_160
L_196:
		INC	D_Q			;区号+1
		CMP	D_Q,87
		JBE	L_198
		MOV	D_Q,16
L_198:
		JMP	L_160

;============================================================================
V_XSQH		DB	14,'[\0&4^1_|*15@40,30,2第 ',0
V_XSQH1 	DB	' 区 @50,34,',0
V_ZT		DB	'00','01','02','03','04','06','07','08'
		DB	'09','10','11','12','13','14','20','21'
		DB	'22','23','26','27','28','30','32','33'
V_XS		DB	'宋体(简)',0,'仿宋(简)',0,'黑体(简)',0,'楷体(简)',0
		DB	'标宋(简)',0,'细圆(简)',0,'准圆(简)',0,'隶变(简)',0
		DB	'大黑(简)',0,'魏碑(简)',0,'行楷(简)',0,'隶书(简)',0
		DB	'姚体(简)',0,'美黑(简)',0,'宋体(繁)',0,'仿宋(繁)',0
		DB	'黑体(繁)',0,'楷体(繁)',0,'细圆(繁)',0,'准圆(繁)',0
		DB	'隶变(繁)',0,'魏碑(繁)',0,'琥珀(繁)',0,'综艺(繁)',0
NOREADSL	DB	13,10,'未安装读矢量字库模块 READSL!',7,13,10,10,'$'
NOINT10V	DB	13,10,'未安装特殊显示模块 INT10K 或 INT10V!',7,13,10,10,'$'

L_200:
		MOV	AX,357EH
		INT	21H
		OR	BX,BX
		JZ	L_201

		XOR	BX,BX
		XOR	DX,DX
		INT	7EH
		OR	BX,BX
		JNZ	L_202
L_201:
		MOV	DX,OFFSET NOREADSL
L_ERR:
		MOV	AH,9
		INT	21H
		JMP	BEGIN
L_202:
		MOV	AX,1903H
		INT	10H
		CMP	AL,84H
		JZ	L_203
		CMP	AL,85H
		JZ	L_203
		MOV	DX,OFFSET NOINT10V
		JMP	L_ERR
L_203:
		MOV	AX,OFFSET V_XS
		MOV	D_CD,AX

		MOV	AX,1406H
		INT	10H
		CMP	BL,4
		JNZ	L_208
		MOV	AL,3
L_208:
		MOV	D_MODE,AL
		MOV	D_X,0
L_209:
		CALL	S_CLS			;清屏
		MOV	SI,OFFSET D_XZT 	;' <ESC> - 退出, <回车> - 选中'
		MOV	DX,1814H
		MOV	BL,1EH
		CALL	S_XSZF
		MOV	D_X1,0
L_210:
		CALL	S_XSCD1 		;显示菜单条
		INC	D_X1
		CMP	D_X1,24
		JB	L_210
		MOV	AL,D_X
		MOV	D_X1,AL
		CALL	S_GGB			;关光标
L_212:
		CALL	S_XSCD			;显示菜单
L_220:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AH,72			;↑
		JNZ	L_230
		CMP	D_X,0
		JNZ	L_221
		MOV	D_X,23
		JMP	SHORT L_222
L_221:
		DEC	D_X
L_222:
		CALL	S_XSCD1 		;清菜单
		JMP	SHORT L_212
L_230:
		CMP	AH,80			;↓
		JNZ	L_240
		CMP	D_X,23
		JB	L_231
		MOV	D_X,0
		JMP	SHORT L_222
L_231:
		INC	D_X
		JMP	SHORT L_222
L_240:
		CMP	AL,1BH			;ESC?
		JNZ	L_250
		CALL	S_CLS			;清屏
		CALL	S_KGB			;开光标
		JMP	L_EXIT
L_250:
		CMP	AL,0DH			;回车?
		JNZ	L_220
L_255:
		CALL	S_KGB			;开光标
		MOV	SI,OFFSET D_XQH 	;'<ESC>-选字体, <空格>-选区, <退格>-上一区, 其他键-下一区'
		MOV	DX,180FH
		MOV	BL,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_INQH	;'开始区号: '
		MOV	DX,1800H
		MOV	BL,7
		CALL	S_XSZF
		CALL	S_INQH			;键入区号
		MOV	D_Q,AL
		JNB	L_260
		MOV	SI,OFFSET D_R1		;14,'R1]'
		CALL	S_TX
		JMP	L_209
L_260:
		CALL	S_GGB
		MOV	SI,OFFSET V_XSQH	;14,'[\0&4^1_|*15@40,30,2第'
		CALL	S_TX
		MOV	AL,D_Q
		CALL	S_TXQH			;区号按字符输出
		MOV	SI,OFFSET V_XSQH1	;'区@50,34,'
		CALL	S_TX
		MOV	AL,D_X			;字体序号
		CBW
		SHL	AX,1
		ADD	AX,OFFSET V_ZT		;字体号区
		MOV	SI,AX
		MOV	AH,9
		LODSB
		INT	10H
		LODSB
		INT	10H
		MOV	AL,']'
		INT	10H

		MOV	DL,0			;十位数
L_270:
		MOV	SI,OFFSET D_XSH 	;14,'['
		CALL	S_TX

		MOV	DH,0			;个位数
L_272:
		MOV	AL,10
		MUL	DL
		ADD	AL,DH			;位号
		OR	AL,AL			;=0?
		JNZ	L_274
		MOV	AL,' '
		MOV	AH,9
		INT	10H			;双空格
		INT	10H
		JMP	SHORT L_276
L_274:
		CMP	AL,94			;>94?
		JA	L_276
		PUSH	AX
		MOV	AL,'*'
		MOV	AH,9
		INT	10H
		MOV	AL,D_C
		ADD	AL,8
		CALL	S_TXQH
		INC	D_C
		CMP	D_C,8
		JNZ	L_275
		MOV	D_C,1
L_275:
		POP	AX
		PUSH	AX
		MOV	AL,D_Q
		ADD	AL,160			;前字节
		MOV	AH,9
		INT	10H
		POP	AX
		ADD	AL,160			;后字节
		MOV	AH,9
		INT	10H
L_276:
		INC	DH			;个位+1
		CMP	DH,9
		JBE	L_272
		MOV	AL,']'
		MOV	AH,9
		INT	10H

		MOV	AH,1
		INT	16H
		JNZ	L_280

		INC	DL			;十位+1
		CMP	DL,9
		JBE	L_270
L_280:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,1BH			;<ESC>?
		JNZ	L_282
		JMP	L_209
L_282:
		CMP	AL,' '                  ;空格?
		JNZ	L_284
		JMP	L_255
L_284:
		CMP	AL,8			;退格?
		JNZ	L_290
		DEC	D_Q
		CMP	D_Q,15
		JA	L_292
		MOV	D_Q,87
		JMP	L_260
L_290:
		INC	D_Q			;区号+1
		CMP	D_Q,87
		JBE	L_292
		MOV	D_Q,16
L_292:
		JMP	L_260

;公共子程序==================================================================
;子程序:清屏
S_CLS		PROC	NEAR
		MOV	AL,D_MODE
		CBW
		INT	10H
		RET
S_CLS		ENDP

;子程序:关光标
S_GGB		PROC	NEAR
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		RET
S_GGB		ENDP

;子程序:开光标
S_KGB		PROC	NEAR
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		RET
S_KGB		ENDP

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
		MOV	DL,70
		MOV	AH,9
		MUL	AH
		ADD	AX,D_CD
		MOV	SI,AX

;子程序:显示字符串SI,DX=串首位置,BL=属性.显示后光标在串尾
S_XSZF:
		XOR	BH,BH
		MOV	AH,2
		INT	10H
		LODSB
		OR	AL,AL
		JZ	L_XZ2
		MOV	AH,9
		MOV	CX,1
		INT	10H
		INC	DX
		JMP	SHORT S_XSZF
L_XZ2:
		RET
S_XSCD		ENDP

;子程序:键入区号
S_INQH		PROC	NEAR
		MOV	BL,7
		MOV	CX,2
		MOV	AX,920H
		INT	10H

		MOV	DX,OFFSET D_QIN
		MOV	SI,DX
		MOV	AH,0AH			;键入区号
		INT	21H
		INC	SI
		MOV	CL,[SI]
		OR	CL,CL
		JNZ	L_IN1
L_IN0:
		STC
		RET
L_IN1:
		XOR	CH,CH
L_IN2:
		INC	SI
		MOV	AL,10
		MUL	CH
		MOV	AH,[SI]
		AND	AH,0FH
		ADD	AL,AH
		MOV	CH,AL
		DEC	CL
		JNZ	L_IN2
		OR	AL,AL
		JZ	L_IN0
		CMP	AL,94
		JA	L_IN0
		CLC
		RET
S_INQH		ENDP

;子程序:输出特显字符串SI
S_TX		PROC	NEAR
		MOV	CX,1
		MOV	AH,9
L_TX1:
		LODSB
		OR	AL,AL
		JZ	L_TX2
		INT	10H
		JMP	SHORT L_TX1
L_TX2:
		RET
S_TX		ENDP

;子程序:区号AL按字符输出
S_TXQH		PROC	NEAR
		CBW
		MOV	CL,10
		DIV	CL
		OR	AL,AL
		JZ	L_TXQH1
		PUSH	AX
		CALL	S_TXQH1
		POP	AX
L_TXQH1:
		MOV	AL,AH
S_TXQH1:
		OR	AL,'0'
		MOV	AH,9
		INT	10H
		RET
S_TXQH		ENDP

CSEG		ENDS
		END	START

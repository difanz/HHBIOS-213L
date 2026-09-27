;	README.ASM
;	1995.9.20, 9.28, 10.18, 10.26, 12.23
;	1996.1.3

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

C_B		DB	9EH		;强调信息颜色
C_A		DB	1EH		;正常文本颜色
C_D		DB	4AH		;目录信息颜色
C_1		DB	6FH		;顶行颜色
C_DH		DB	70H		;底行汉字颜色
C_DZ		DB	74H		;    字符颜色
D_CX		DW	1		;=1:可显示汉字,=0:按字符显示

D_L		DW	0		;当前行
D_SI		DW	0		;当前页首行号
D_STAS		DW	0		;文件首段
D_END		DW	0		;文件尾地址
D_ENDS		DW	0		;      段
D_TAB		DW	0		;目录区当前行地址
D_LM		DW	0		;最大行号
D_DM		DW	0		;目录区尾地址
D_DH		DB	0		;=0清,=-1置 目录

D_MODE		DB	0		;显示方式
D_MSG		DB	' F1-帮助 TAB-下移或返回目录 Shift+TAB-上移目录 CR-跳转查阅 ESC-退出 F10-设置存盘',0
D_MSG1		DB	' F2-文本前景 F3-背景 F4-目录前景 F5-背景 F6-强调前景 F7-背景 F8-顶行前景 F9-背景',0
D_TUX		DB	0		;当前提示号:0-MSG,-1-MSG1

D_HELP		DB	'通用文本阅读程序 README.COM 使用说明',0
D_HELP1 	DB	'调用格式: README [格式文件]',0
		DB	'  缺省为与本程序同目录的无扩展名的文件名',0
		DB	'格式文件文本格式(请参考本系统的README):',0
		DB	'  !c标号-索引标志  !d标号-目录信息',0
		DB	'  !e-可显示汉字    !f-按字符显示',0
		DB	'  !a正常文本  !b强调信息(可加背前景颜色)',0
		DB	'       其中:背景色0-9,前景色0-9,A-F或a-f',0
		DB	'  标号为两个字符或一个汉字(最多256个)',0
		DB	'功能键说明:          <INS>-提示切换',0
		DB	'  <TAB>-目录区光标下移或从文本区返目录区',0
		DB	'  <Shift+TAB>-目录区光标上移',0
		DB	'  <PgUp>-上卷一页    <PgDn>-下卷一页',0
		DB	'  <HOME>-至文本首页  <END>--至文本末页',0
		DB	'颜色设置:            F10-设置存盘',0
		DB	'  F2-正常文本前景色  F6-强调信息前景色',0
		DB	'  F3-        背景色  F7-        背景色',0
		DB	'  F4-目录信息前景色  F8-顶行信息前景色',0
		DB	'  F5-        背景色  F9-        背景色',0
		DB	' 版权所有:北京晓军电脑公司  1996年1月2日',0,0
D_BP		DW	0			;D_COM中文件扩展名分隔符地址
D_WJM		DB	'文件名: ',0
D_YSH		DB	'页首行号:',0
D_LMH		DB	'总计行数:',0
D_HH		DB	'    ',0
NOFILE		DB	'文件未找到!',7,13,10,'$'
NODIR		DB	'有索引信息未找到!',7,13,10,'$'
NO213		DB	'NO 2.13 CHINESE SYSTEM!',7,13,10,'$'
;----------------------------------------------------------------------------
BEGIN:
		XOR	BP,BP
		MOV	AX,1406H		;取显示模块参数
		INT	10H
		OR	BP,BP			;判2.13?
		JNZ	L_10
		MOV	DX,OFFSET NO213
		JMP	L_ERR
L_10:
		MOV	D_MODE,AL		;显示方式

		MOV	SI,80H
		LODSB
		OR	AL,AL			;命令行参数?
		JZ	L_20
		CBW
		MOV	BX,AX
		MOV	[BX+SI],AH		;文件名尾
L_12:
		LODSB
		CMP	AL,' '
		JBE	L_12
		DEC	SI
		MOV	DX,SI			;指定文件名
		JMP	SHORT L_30		;		12.23
L_20:
		MOV	DS,DS:[2CH]		;环境段
		XOR	SI,SI
L_21:
		CMP	WORD PTR DS:[SI],0	;判环境区尾?
		JZ	L_22
		INC	SI
		JMP	SHORT L_21
L_22:
		LODSW
		LODSW				;SI:README.COM全路径首
		MOV	DI,OFFSET D_COM
L_23:
		LODSB
		STOSB
		CMP	AL,'.'                  ;扩展名分隔符
		JNZ	L_24
		MOV	BP,DI			;存
		DEC	BP
		JMP	SHORT L_23
L_24:
		OR	AL,AL
		JNZ	L_23

		PUSH	CS
		POP	DS
		MOV	D_BP,BP
		MOV	BYTE PTR DS:[BP],0	;去扩展名
		MOV	DX,OFFSET D_COM
L_30:
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_32
		MOV	DX,OFFSET NOFILE
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_32:
		MOV	BX,AX

		MOV	SI,DX			;文件名传送到DS:60H
		MOV	DI,60H
L_34:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	L_34

		MOV	BP,DS
		MOV	D_STAS,BP
		ADD	D_STAS,1000H		;首段
L_36:
		ADD	BP,1000H		;下一段
		MOV	DS,BP
		XOR	DX,DX
		MOV	CX,8000H
		MOV	AH,3FH			;读文件
		INT	21H
		CMP	AX,CX
		JB	L_38
		MOV	DX,CX
		MOV	AH,3FH			;读文件
		INT	21H
		CMP	AX,CX
		JZ	L_36
		ADD	AX,DX
L_38:
		MOV	CS:D_END,AX		;文件尾地址
		MOV	CS:D_ENDS,BP
		MOV	AH,3EH
		INT	21H

		CALL	S_LINE			;取每行首地址 CS=>DS

		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		CALL	S_CLS			;清屏
;----------------------------------------------------------------------------
L_90:
		MOV	BP,D_STAS		;首段
		XOR	SI,SI
L_92:
		MOV	D_SI,SI 		;页首行号
		MOV	DX,100H 		;第一行首
L_94:
		MOV	SI,D_SI 		;页首行
		MOV	DI,D_TAB		;目录行地址
		OR	DI,DI			;判在目录区
		JZ	L_98
		MOV	AX,[DI]
		SUB	AX,SI
		JB	L_96
		CMP	AX,23
		JB	L_98
L_96:
		MOV	D_TAB,0
L_98:
		CALL	S_XS			;显示一页
L_100:
		XOR	AH,AH			;键入.以下:DI=页首的行首地址区
		INT	16H			;	   BP=	  段
;----------------------------------------------------------------------------
		CMP	AX,4800H		;↑
		JNZ	L_110
		CMP	D_SI,0			;页首行到文件首
		JZ	L_100
		DEC	D_SI			;页首行-1
		JMP	L_94			;显示
;----------------------------------------------------------------------------
L_110:
		CMP	AX,5000H		;↓
		JNZ	L_120
		MOV	AX,D_LM
		SUB	AX,23
		CMP	D_SI,AX 		;页首<文件尾-23行
		JAE	L_100
		INC	D_SI			;页首行+1
		JMP	L_94			;显示
;----------------------------------------------------------------------------
L_120:
		CMP	AX,4900H		;PGUP
		JNZ	L_130
		MOV	SI,D_SI
		CMP	SI,23			;=文件首?
		JAE	L_121
		XOR	SI,SI
		JMP	SHORT L_122
L_121:
		SUB	SI,23
L_122:
		MOV	D_SI,SI 		;页首行数
		JMP	L_94
;----------------------------------------------------------------------------
L_130:
		CMP	AX,5100H		;PGDN
		JNZ	L_140
		MOV	SI,D_SI
		MOV	AX,D_LM 		;文件尾行
		SUB	AX,23
		CMP	SI,AX			;=文件尾地址?
		JBE	L_131
		MOV	SI,AX
		JMP	SHORT L_133
L_131:
		SUB	AX,SI
		CMP	AX,23
		JBE	L_132
		MOV	AX,23
L_132:
		ADD	SI,AX			;下一页
L_133:
		MOV	D_SI,SI 		;页首地址
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
		MOV	DI,OFFSET D_DIR 	;目录区
L_161:
		CMP	SI,[DI]
		JBE	L_164
		ADD	DI,4
		JMP	SHORT L_161
L_162:
		MOV	DI,OFFSET D_DIR 	;目录区
L_163:
		CMP	SI,[DI+2]		;当前行<目录行号
		JBE	L_164
		ADD	DI,4
		CMP	DI,D_DM
		JZ	L_164
		CMP	SI,[DI+2]		;<下一个?
		JA	L_163
L_164:
		MOV	D_TAB,DI		;当前目录行地址

		MOV	SI,[DI] 		;目录行
		MOV	AX,D_SI 		;页首行
		CMP	SI,AX
		JB	L_165
		ADD	AX,23
		CMP	SI,AX
		JBE	L_173
L_165:
		JMP	L_92			;显示
L_166:
		MOV	DI,D_TAB
		CMP	DI,D_DM 		;到目录区尾?
		JAE	L_174
		CALL	S_CLSDIR		;清原目录
		ADD	DI,4
		MOV	D_TAB,DI
		JMP	SHORT L_171
;----------------------------------------------------------------------------
L_170:
		CMP	AX,0F00H		;SHIFT+TAB
		JNZ	L_180
		CMP	D_TAB,0 		;判在目录区?
		JZ	L_174
		MOV	DI,D_TAB
		CMP	DI,OFFSET D_DIR 	;到目录区首
		JZ	L_174
		CALL	S_CLSDIR		;清原目录
		SUB	DI,4
		MOV	D_TAB,DI
L_171:
		MOV	AX,D_SI 		;页首行号
		CMP	[DI],AX 		;目录行<页首
		JB	L_172
		ADD	AX,23
		CMP	[DI],AX 		;>页尾?
		JB	L_173
L_172:
		MOV	SI,[DI]
		JMP	L_92			;显示
L_173:
		CALL	S_SETDIR		;置当前目录
L_174:
		CALL	S_280			;显示提示信息
		JMP	L_100
;----------------------------------------------------------------------------
L_180:
		CMP	AX,3B00H		;F1?
		JNZ	L_190
		CALL	S_280			;显示提示信息
		MOV	DX,212H 		;左上角位置
		MOV	CX,152CH		;高和宽
		MOV	BL,30H			;颜色
		CALL	S_XSCK			;显示空窗口
		PUSH	DX
		ADD	DX,4
		MOV	SI,OFFSET D_HELP
		CALL	S_XSZFC
		POP	DX
		MOV	SI,OFFSET D_HELP1
		ADD	DX,102H
		CALL	S_CKXS			;显示内容
		XOR	AH,AH			;键入
		INT	16H
		XOR	DL,DL
		JMP	L_98			;重显当前页
;----------------------------------------------------------------------------
L_190:
		MOV	CL,4
		CMP	AX,3C00H		;F2:正常文本前景色
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
		CALL	S_281			;显示提示信息1
		JMP	L_94
;----------------------------------------------------------------------------
L_200:
		CMP	AX,3D00H		;F3:正常文本背景色
		JNZ	L_210
		MOV	AL,C_A
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_191
;----------------------------------------------------------------------------
L_210:
		CMP	AX,3E00H		;F4:目录信息前景色
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
		CALL	S_281			;显示提示信息1
		JMP	L_94
;----------------------------------------------------------------------------
L_220:
		CMP	AX,3F00H		;F5:目录信息背景色
		JNZ	L_230
		MOV	AL,C_D
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_211
;----------------------------------------------------------------------------
L_230:
		CMP	AX,4000H		;F6:强调信息前景色
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
		CALL	S_281			;显示提示信息1
		JMP	L_94
;----------------------------------------------------------------------------
L_240:
		CMP	AX,4100H		;F7:强调信息背景色
		JNZ	L_250
		MOV	AL,C_B
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_231
;----------------------------------------------------------------------------
L_250:
		CMP	AX,4200H		;F8:顶行信息前景色
		JNZ	L_260
		MOV	AL,C_1			;顶行颜色
		MOV	AH,AL
		AND	AX,0F00FH
		INC	AL
		CMP	AL,10H
		JB	L_251
		XOR	AL,AL
L_251:
		OR	AL,AH
		MOV	C_1,AL
		CALL	S_XSDH			;显示顶行
		MOV	DX,100H
		CALL	S_281			;显示提示信息1
		JMP	L_100
;----------------------------------------------------------------------------
L_260:
		CMP	AX,4300H		;F9:顶行信息背景色
		JNZ	L_270
		MOV	AL,C_1
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_251
;----------------------------------------------------------------------------
L_270:
		CMP	AX,4400H		;F10:设置存盘
		JNZ	L_280
		MOV	DX,OFFSET D_COM
		MOV	BX,D_BP
		MOV	BYTE PTR DS:[BX],'.'    ;恢复扩展名
		MOV	CX,20H
		MOV	AH,3CH			;重建文件
		INT	21H
		MOV	BX,AX
		MOV	DX,100H 		;文件首
		MOV	CX,OFFSET D_COM 	;文件尾
		SUB	CX,DX			;长度
		MOV	AH,40H			;写入
		INT	21H
		MOV	AH,3EH			;关闭文件
		INT	21H
		CALL	S_280			;显示提示信息
		JMP	L_100
;----------------------------------------------------------------------------
L_280:
		CMP	AH,52H			;<INS>:切换提示
		JNZ	L_290
		CMP	D_TUX,0 		;当前提示?
		JZ	L_281
		CALL	S_280			;显示提示信息
		JMP	SHORT L_282
L_281:
		CALL	S_281			;显示提示信息1
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
		CMP	AL,0DH			;回车
		JNZ	L_300
		CALL	S_280
		MOV	DI,D_TAB		;当前目录地址
		OR	DI,DI			;判0
		JZ	L_291
		MOV	SI,[DI+2]		;索引行
		JMP	L_92			;显示
L_291:
		JMP	L_100
;----------------------------------------------------------------------------
L_300:
		CMP	AL,1BH			;ESC
		JNZ	L_291
		MOV	AX,1813H		;重显屏幕
		INT	10H
		MOV	CX,0E0FH
		MOV	AH,1			;开光标
		INT	10H
		MOV	AX,4C00H		;退出
		INT	21H
;============================================================================
;子程序:查找每行首、目录行首和索引行首地址 CS=>DS
S_LINE		PROC	NEAR
		MOV	BP,CS:D_STAS		;文本区首段
		MOV	DS,BP			;		BP:当前段
		MOV	BX,OFFSET D_DIR 	;目录信息地址	BX:
		MOV	DI,OFFSET D_LINE	;行首地址存放区 DI:
		XOR	CX,CX			;行号		CX:
		XOR	AX,AX
		STOSW
		MOV	AX,BP
		STOSW
		XOR	SI,SI			;当前绝对地址
L_L1:
		LODSB				;取一字符
		CALL	S_SEG			;判跨段
		CMP	AL,'!'                  ;功能符?
		JNZ	L_L3
		LODSB
		CALL	S_SEG
		CMP	AL,'d'                  ;目录信息
		JNZ	L_L2
		MOV	CS:[BX],CX		;行号
		ADD	BX,4
		JMP	SHORT L_L1
L_L2:
		CMP	AL,'c'                  ;索引信息
		JNZ	L_L3
		CALL	S_SORT			;查目录区并写入
		JMP	SHORT L_L1
L_L3:
		CMP	AL,0DH			;回车?
		JZ	L_L4
		CMP	AL,8DH			;软回车?
		JZ	L_L4
		CMP	AL,0AH			;换行?
		JZ	L_L4
		CMP	AL,8AH			;分页符?
		JNZ	L_L1
L_L4:
		OR	SI,SI			;判跨段?
		JZ	L_L5
		MOV	BYTE PTR [SI-1],0	;均置0(行尾)
		JMP	SHORT L_L6
L_L5:
		PUSH	DS
		MOV	AX,DS
		SUB	AX,1000H		;上一段
		MOV	DS,AX
		MOV	BYTE PTR DS:[0FFFFH],0	;置0
		POP	DS
L_L6:
		LODSB
		CALL	S_SEG
		MOV	AX,SI			;下行首地址
		STOSW
		MOV	AX,BP			;段
		STOSW
		INC	CX

		CMP	BYTE PTR [SI],1AH	;结束?
		JNZ	L_L1

		PUSH	CS
		POP	DS
		MOV	D_LM,CX 		;最大行号
		XOR	AX,AX
		STOSW
		MOV	[BX+4],AX		;结尾
		MOV	[BX+6],AX
		RET
S_LINE		ENDP

;子程序:查目录区并写入 BX=目录信息地址, CX=当前行号
S_SORT		PROC	NEAR
		CMP	CS:D_DM,0		;目录区尾
		JNZ	L_S0
		SUB	BX,4
		MOV	CS:D_DM,BX		;目录区尾
L_S0:
		LODSB				;索引内容1
		CALL	S_SEG
		MOV	DL,AL
		LODSB				;索引内容2
		CALL	S_SEG
		MOV	DH,AL

		PUSH	DS
		MOV	DS,CS:D_STAS		;文件首段
		PUSH	SI
		MOV	BX,OFFSET D_DIR 	;目录区首
L_S1:
		MOV	SI,CS:[BX]		;目录行号
		SHL	SI,1
		SHL	SI,1
		MOV	SI,WORD PTR CS:D_LINE[SI]	;行首
L_S2:
		LODSB
		CMP	AL,'!'                  ;功能符?
		JNZ	L_S2
		LODSB
		CMP	AL,'d'                  ;目录信息
		JNZ	L_S2
		LODSW
		CMP	AX,DX			;判
		JZ	L_S3
		ADD	BX,4
		CMP	BX,CS:D_DM		;到目录区尾?
		JBE	L_S1
		POP	AX
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET NODIR
		JMP	L_ERR
L_S3:
		MOV	CS:[BX+2],CX		;目录索引行号
		POP	SI
		POP	DS
		RET
S_SORT		ENDP
;----------------------------------------------------------------------------
;子程序:清屏并显示顶行尾行信息
S_CLS		PROC	NEAR
		CALL	S_XSDH			;显示顶行

		XOR	BL,BL
		CMP	D_MODE,9
		JZ	L_CLS1
		MOV	BL,C_A
L_CLS1:
		INC	DH
		CALL	S_CLSYH 		;清
		CMP	DH,24
		JB	L_CLS1

		MOV	SI,OFFSET D_MSG
S_XSTS: 					;子程序:显示提示信息
		PUSH	DX
		MOV	DX,1800H
L_CLS3:
		LODSB
		OR	AL,AL
		JZ	L_CLS5
		MOV	BL,C_DZ
		CMP	AL,0A1H 		;判汉字?
		JB	L_CLS4
		MOV	BL,C_DH
L_CLS4:
		CALL	S_XSZF			;显示
		JMP	SHORT L_CLS3
L_CLS5:
		POP	DX
		RET
;子程序:显示顶行
S_XSDH:
		XOR	DX,DX
		MOV	BL,C_1
		CALL	S_CLSYH 		;清顶行

		MOV	SI,OFFSET D_WJM 	;'文件名:'
		MOV	DL,6
		CALL	S_XSZFC
		MOV	SI,60H			;文件名存放区
		MOV	DL,14
		CALL	S_XSZFC
		MOV	SI,OFFSET D_YSH 	;'页首行号:'
		MOV	DL,40
		CALL	S_XSZFC
		MOV	SI,OFFSET D_LMH 	;'总计行数:'
		MOV	DL,60
;子程序:显示字符串 DX=位置,SI=字符串
S_XSZFC:
		LODSB
		OR	AL,AL			;结束
		JZ	L_XC1
		CALL	S_XSZF			;显示
		JMP	SHORT S_XSZFC
L_XC1:
		RET
;子程序:清一行 BL=属性,DH=行
S_CLSYH:
		XOR	DL,DL
		MOV	CX,80
L_CLSYH:
		MOV	AL,' '
		CALL	S_XSZF
		LOOP	L_CLSYH
		RET
;子程序:显示字符 DX:位置,AL:字符
S_XSZF:
		PUSH	CX
		MOV	CX,CS:D_CX		;=1:可显示汉字,=0:按字符显示1.3
		CMP	CS:D_MODE,9		;单显?
		JNZ	L_XSZF2
		TEST	BL,0E0H
		JZ	L_XSZF1
		MOV	BL,70H
		JMP	SHORT L_XSZF2
L_XSZF1:
		MOV	BL,7
L_XSZF2:
		MOV	BH,AL
		MOV	AX,1409H		;显示
		INT	10H
		POP	CX
		INC	DX			;位置+1
		RET
S_CLS		ENDP
;----------------------------------------------------------------------------
;子程序:显示一页
S_XS		PROC	NEAR
		PUSH	DX
		PUSH	SI
		MOV	D_DH,-1
		MOV	DX,100H 		;文本区左上角
		MOV	DI,D_SI 		;页首行号
L_XS1:
		MOV	SI,DI
		SHL	SI,1
		SHL	SI,1
		ADD	SI,OFFSET D_LINE
		MOV	BP,CS:[SI+2]		;段

		MOV	DS,BP
		MOV	SI,CS:[SI]		;行首地址
		CALL	S_XSYH			;显示一行
		INC	DI
		INC	DH
		CMP	DH,24
		JNZ	L_XS1
		PUSH	CS
		POP	DS

		CALL	S_XSYS			;显示页首行号
		CALL	S_XSZJ			;显示总计行数
		POP	SI
		POP	DX
		RET
;子程序:显示一行
S_XSYH:
		MOV	BL,CS:C_A
L_X10:
		LODSB				;取一字符
		CALL	S_SEG
		CMP	AL,'!'                  ;功能字符?
		JZ	L_X11
		JMP	L_X20
L_X11:
		LODSB
		CALL	S_SEG
		CMP	AL,'b'                  ;强调字符?
		JNZ	L_X14
		CMP	BYTE PTR [SI],'0'       ;判有颜色?
		JB	L_X13
		CMP	BYTE PTR [SI],'9'
		JA	L_X13
		LODSB				;取背景色
		MOV	CL,4
		SHL	AL,CL
		MOV	BL,AL
		LODSB				;取前景色
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
		CMP	AL,'a'                  ;正常文本?
		JNZ	L_X15A
		MOV	BL,CS:C_A		;正常文本颜色
		MOV	CS:D_CX,1		;可显示汉字		1.3
		JMP	SHORT L_X10
L_X15A:
		CMP	AL,'e'                  ;可显示汉字?            1.3
		JNZ	L_X15B
		MOV	CS:D_CX,1		;可显示汉字		1.3
		JMP	SHORT L_X10
L_X15B:
		CMP	AL,'f'                  ;按字符显示?
		JNZ	L_X15
		MOV	CS:D_CX,0		;按字符显示		1.3
		JMP	SHORT L_X10
L_X15:
		CMP	AL,'d'                  ;目录信息?
		JNZ	L_X17
		LODSB
		CALL	S_SEG
		LODSB
		CALL	S_SEG
		MOV	BL,CS:C_D		;目录信息颜色
		CMP	CS:D_MODE,9
		JNZ	L_X16
		MOV	BL,7
L_X16:
		CMP	CS:D_DH,0		;开关
		JZ	L_X16A
		MOV	BP,CS:D_TAB		;当前目录地址
		OR	BP,BP			;判0
		JZ	L_X16A
		CMP	DI,CS:[BP]		;是否目录行
		JNZ	L_X16A
		MOV	CL,4
		ROR	BL,CL			;前景背景交换
L_X16A:
		JMP	L_X10
L_X17:
		CMP	AL,'c'                  ;索引信息?
		JNZ	L_X18
		LODSB
		CALL	S_SEG
		LODSB
		CALL	S_SEG
		JMP	L_X10
L_X18:
		PUSH	AX
		MOV	AL,'!'
		CALL	S_XSZF			;显示字符\
		POP	AX
L_X20:
		CMP	AL,9			;跳格?
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
		OR	AL,AL			;行结束?
		JZ	L_X30
L_X25:
		CALL	S_XSZF			;显示
		JMP	L_X10
L_X30:
		CMP	DL,80			;行满?
		JAE	L_X40
		MOV	AL,' '
		CALL	S_XSZF
		JMP	SHORT L_X30
L_X40:
		LODSB
		CALL	S_SEG
		XOR	DL,DL			;位置行首
		RET
;子程序:判跨段
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
;子程序:清目录显示
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
		MOV	BP,[SI+2]		;段
		MOV	DS,BP
		MOV	SI,CS:[SI]		;行首地址
		CALL	S_XSYH
		POP	DI
		PUSH	CS
		POP	DS
		RET
S_CLSDIR	ENDP
;----------------------------------------------------------------------------
;子程序:显示页首行号
S_XSYS		PROC	NEAR
		MOV	AX,D_SI 		;页首行
		INC	AX
		MOV	DX,49
		JMP	SHORT L_XSH1
;子程序:显示总计行数
S_XSZJ:
		MOV	AX,D_LM 		;总计行数
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
D_G		DW	0			;窗口高
D_K		DW	0			;    宽
D_B1		DB	0C9H,0CDH,0BBH,0
D_B2		DB	0BAH,20H,0BAH,0
D_B3		DB	0C8H,0CDH,0BCH,0
;子程序:显示空窗口 DX=窗口左上角,CH=高,CL=宽,BL=颜色
S_XSCK		PROC	NEAR
		PUSH	DX
		SUB	CX,202H
		MOV	AL,CH
		CBW
		MOV	D_G,AX			;窗口内高
		MOV	AL,CL
		MOV	D_K,AX			;      宽

		XOR	CX,CX
		MOV	SI,OFFSET D_B1		;上横线
		CALL	S_XS1H

		MOV	SI,OFFSET D_B2		;中间
		MOV	DI,D_G
L_CK1:
		INC	DH
		CALL	S_XS1H
		DEC	DI
		JNZ	L_CK1
		INC	DH
		MOV	SI,OFFSET D_B3		;下横线
		CALL	S_XS1H

		POP	DX
		RET
;子程序:显示一行:
S_XS1H:
		PUSH	DX
		MOV	AL,[SI] 		;左边
		CALL	S_XSZF1
		MOV	BP,D_K
L_YH1:
		MOV	AL,[SI+1]		;中间
		CALL	S_XSZF1
		DEC	BP
		JNZ	L_YH1
		MOV	AL,[SI+2]		;右边
		CALL	S_XSZF1
		POP	DX
		RET
S_XSZF1:
		CMP	CS:D_MODE,9		;单显?
		JNZ	L_XSZF22
		TEST	BL,0E0H
		JZ	L_XSZF11
		MOV	BL,70H
		JMP	SHORT L_XSZF22
L_XSZF11:
		MOV	BL,7
L_XSZF22:
		MOV	BH,AL
		MOV	AX,1409H		;显示
		INT	10H
		INC	DX			;位置+1
		RET
S_XSCK		ENDP

;子程序:显示窗口内容SI(每行尾0,最后再加0),DX=首位置,BL=属性
S_CKXS		PROC	NEAR
		PUSH	DX
L_CKXS1:
		CMP	BYTE PTR [SI],0 	;结束?
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
D_COM	EQU	$			;文件全名
D_DIR	EQU	$+64			;目录行信息 最多255个
		;格式:行号,索引行号...	;结尾为0
D_LINE	EQU	$+64+1024		;行首地址存放区
		;格式:行首地址,段,...	结尾为0

CSEG		ENDS
		END	START

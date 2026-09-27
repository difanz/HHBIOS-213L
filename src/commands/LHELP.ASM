;	LHELP.ASM
;	1997.2.20, 3.21, 6.29, 7.31
;	1998.4.8
;	1999.1.13

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

D_FILE		DW	0			;文件名首
D_MODE		DB	0			;显示方式
D_WIN		DB	0			;当前窗口号
D_B1		DB	0C9H,0CDH,0BBH,0
D_B2		DB	0BAH,20H,0BAH,0
D_B3		DB	0C8H,0CDH,0BCH,0
D_CDXZ		DB	4FH			;菜单选择色
D_TS		DB	' ALT+专用键盘| 光标-移动,背景:INS+,DEL-.前景:HOME+,END-.边框:PGUP+,PGDN-,存盘:+',0
D_ALT		DB	0			;键入ALT标志
K_NUM		DB	14			;子窗口数
H_MAIN		DB	1			;主菜单当前号

K_MAIN		DB	1EH			;主菜单窗口色
		DB	1EH			;标题色
		DW	1218H			;主菜单窗口大小
		DW	204H			;	   左上角位置

K_ZFB		DB	6FH			;字符表
		DB	6EH
		DW	1325H
		DW	410H

K_KZASC 	DB	57H			;扩展ASC表
		DB	5AH
		DW	182FH
		DW	18H

K_GQHZ		DB	61H			;各区汉字
		DB	6BH
		DW	0E28H
		DW	610H

K_SPDM		DB	4AH			;双拼代码
		DB	4EH
		DW	122FH
		DW	315H

K_YS		DB	2AH			;前景背景颜色
		DB	2FH
		DW	133DH
		DW	410H

K_XSFS		DB	67H			;显示方式
		DB	6FH
		DW	946H
		DW	808H

K_SLZT		DB	52H			;矢量字体
		DB	5EH
		DW	1130H
		DW	515H

K_ZXZH		DB	21H			;字型字号
		DB	2FH
		DW	174AH
		DW	103H

K_XTPB		DB	4FH			;系统排版
		DB	4EH
		DW	183FH
		DW	0AH

K_TSXS		DB	1EH			;特殊显示
		DB	1FH
		DW	144DH
		DW	101H

K_TSDY		DB	1EH			;特殊打印
		DB	1FH
		DW	1447H
		DW	206H

K_INT10 	DB	1EH			;显示中断
		DB	1FH
		DW	164EH
		DW	101H

K_QTINT 	DB	1EH			;其他中断
		DB	1FH
		DW	174EH
		DW	201H

K_GNJ		DB	30H			;功能键用法
		DB	30H
		DW	0D39H
		DW	910H

D_BT		DB	' !2.13L 联机帮助系统!',0
		DB	' ',0
D_CD		DB	'ASCII字符表         ',0        ;ZFB
		DB	'扩展ASCII码表       ',0        ;KZASC
		DB	'区位码表            ',0        ;GQHZ
		DB	'双拼代码表          ',0        ;SPDM
		DB	'显示16种前景背景颜色',0        ;YS
		DB	'显示方式一览表      ',0        ;XSFS
		DB	'矢量汉字字体与字库名',0        ;SLZT
		DB	'字型与字号表        ',0        ;ZXZH
		DB	'公文排版打印功能    ',0        ;XTPB
		DB	'特殊显示功能        ',0        ;TSXS
		DB	'特殊打印功能        ',0        ;TSDY
		DB	'显示中断功能调用    ',0        ;INT10
		DB	'键盘和打印中断调用  ',0        ;QTINT
		DB	'本模块功能键用法    ',0,0      ;GNJ

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
		MOV	AH,1			;关光标
		INT	10H
L_40:
		MOV	AL,D_WIN
		OR	AL,AL
		JNZ	L_55
L_44:
		MOV	DI,OFFSET K_MAIN
		CALL	S_XSCK			;显示空窗口
		MOV	SI,OFFSET D_BT		;标题及主菜单
		CALL	S_CKXS102
L_50:
		MOV	CH,K_NUM		;项数
		MOV	CL,21			;宽度
		INC	DH			;菜单位置
		MOV	D_DX,DX
		MOV	DH,H_MAIN		;默认号
		MOV	BP,OFFSET D_CD		;主菜单
		CALL	S_CDKZ			;菜单控制

		CMP	D_ALT,0FFH		;键入ALT
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
		CALL	D_XZ[BX]		;执行各功能子程序

		CMP	D_ALT,0 		;判ALT
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
		MOV	AX,1813H		;恢复屏幕
		TEST	DL,80H
		JZ	L_RET1
		MOV	AL,23
L_RET1:
		INT	10H
		MOV	CX,0E0FH
		MOV	AH,1			;开光标
		INT	10H
		POP	ES
		POP	DS
		RET
L_HELP		ENDP

;公用子程序==================================================================
D_K		DW	0			;宽
D_G		DW	0			;高
;子程序:显示空窗口 DI=窗口参数首(窗口色,显示色,窗口大小,窗口左上角)
S_XSCK		PROC	NEAR
		MOV	BL,[DI] 		;窗口色
		MOV	CX,[DI+2]		;大小
		MOV	DX,[DI+4]		;左上角
		PUSH	DX
		SUB	CX,202H
		MOV	AL,CH
		CBW
		MOV	D_G,AX			;窗口内高
		MOV	AL,CL
		MOV	D_K,AX			;      宽

		XOR	CX,CX
		MOV	SI,OFFSET D_B1		;上横线
		CALL	S_XSYH

		MOV	SI,OFFSET D_B2		;中间
		MOV	BP,D_G
L_CK1:
		INC	DH
		CALL	S_XSYH
		DEC	BP
		JNZ	L_CK1
		INC	DH
		CMP	DH,18H
		JA	L_CK3
		MOV	SI,OFFSET D_B3		;下横线
		CALL	S_XSYH

		ADD	DX,101H
		CMP	D_MODE,9		;判单显?
		JBE	L_CK3
		CMP	DH,18H			;到底行?
		JA	L_CK3
		MOV	BX,2000H		;下阴影
		MOV	BP,D_K
		ADD	BP,2
L_CK2:
		CALL	S_XSZF
		DEC	BP
		JNZ	L_CK2
L_CK3:
		MOV	BL,[DI+1]		;显示色
		POP	DX
		RET
;子程序:显示一行:
S_XSYH:
		PUSH	DX
		PUSH	BP
		MOV	BH,[SI] 		;左边
		CALL	S_XSZF
		MOV	BH,[SI+1]		;中间
		MOV	BP,D_K
L_YH1:
		CALL	S_XSZF
		DEC	BP
		JNZ	L_YH1
		MOV	BH,[SI+2]		;右边
		CALL	S_XSZF
		CMP	D_MODE,9		;判单显?
		JBE	L_YH2
		CMP	SI,OFFSET D_B1		;判上横线?
		JZ	L_YH2
		CMP	DL,80			;判到右边?
		JZ	L_YH2
		PUSH	BX
		MOV	BX,2000H		;右边阴影
		CALL	S_XSZF
		POP	BX
L_YH2:
		POP	BP
		POP	DX
		RET
S_XSCK		ENDP

;子程序:显示窗口内容SI(每行尾0,最后再加0),DX=首位置,BL=属性
S_CKXS102	PROC	NEAR
		ADD	DX,102H
S_CKXS:
		MOV	CX,1
		PUSH	DX
L_CKXS1:
		CMP	BYTE PTR [SI],0 	;结束?
		JZ	L_CKXS2
		PUSH	DX
		CALL	S_XSZFC 		;显示一行
		POP	DX
		INC	DH
		JMP	SHORT L_CKXS1
L_CKXS2:
		POP	DX
		RET
S_CKXS102	ENDP

;子程序:键入
S_INPUT 	PROC	NEAR
		MOV	D_ALT,0 		;清标志
		MOV	AX,2B10H		;调BIOS键入
		INT	16H
		PUSH	AX
		MOV	AL,6
		MUL	D_WIN
		ADD	AX,OFFSET K_MAIN
		MOV	SI,AX
		POP	AX

		CMP	AH,98H			;ALT+↑
		JNZ	L_IN1
		MOV	DL,[SI+5]
		OR	DL,DL
		JZ	L_IN00
		DEC	DL
		MOV	[SI+5],DL
L_IN00:
		NOT	D_ALT			;置标志
		RET
L_IN1:
		CMP	AH,0A0H 		;ALT+↓
		JNZ	L_IN2
		MOV	DL,[SI+5]		;窗口左上胶行
		ADD	DL,[SI+3]		;+窗口行数
		CMP	DL,25			;到底?
		JAE	L_IN10
		INC	BYTE PTR [SI+5]
L_IN10:
		JMP	L_IN00
L_IN2:
		CMP	AH,9BH			;ALT+←
		JNZ	L_IN3
		MOV	DL,[SI+4]
		OR	DL,DL
		JZ	L_IN20
		DEC	DL
		MOV	[SI+4],DL
L_IN20:
		JMP	L_IN00
L_IN3:
		CMP	AH,9DH			;ALT+→
		JNZ	L_IN4
		MOV	DL,[SI+4]
		ADD	DL,[SI+2]
		CMP	DL,80
		JAE	L_IN30
		INC	BYTE PTR [SI+4]
L_IN30:
		JMP	L_IN00
L_IN4:
		CMP	AH,0A2H 		;ALT+INS*	背景色+
		JNZ	L_IN5
		ADD	BYTE PTR [SI],10H
		ADD	BYTE PTR [SI+1],10H
		JMP	L_IN00
L_IN5:
		CMP	AH,0A3H 		;ALT+DEL*	背景色-
		JNZ	L_IN6
		SUB	BYTE PTR [SI],10H
		SUB	BYTE PTR [SI+1],10H
		JMP	L_IN00
L_IN6:
		CMP	AH,97H			;ALY+HOME*	前景色+
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
		CMP	AH,9FH			;ALT+END*	前景色-
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
		CMP	AH,99H			;ALT+PGUP*	边框色+
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
		CMP	AH,0A1H 		;ALT+PGDN*	边框色-
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
		CMP	AH,0A6H 		;ALT+ENTER*	提示行显示
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
		CMP	AH,4EH			;ALT+'+'*       设置存盘
		JNZ	L_INC
		MOV	AH,51H			;取PSP
		INT	21H
		PUSH	BX			;保存
		MOV	BX,CS
		MOV	AH,50H			;当前PSP
		INT	21H
		MOV	DX,D_FILE		;调出文件名(带路径)
		MOV	DS,DS:[2CH]
		MOV	CX,20H
		MOV	AH,3CH			;重建文件
		INT	21H
		MOV	BX,AX
		PUSH	CS
		POP	DS
		MOV	DX,100H
		MOV	CX,OFFSET D_END-100H
		MOV	AH,40H			;写入
		INT	21H
		MOV	AH,3EH			;关闭
		INT	21H
		POP	BX			;恢复
		MOV	AH,50H			;当前PSP
		INT	21H
		JMP	S_INPUT
L_INC:
		RET
S_INPUT 	ENDP

D_DH		DB	1			;开始选择号
D_DX		DW	0			;位置
;〖子程序:菜单控制〗字符串首BP,项数CH,项长CL(包括0),D_DX=位置
;		    返回AL=选中项
S_CDKZ		PROC	NEAR
L_CD10:
		CALL	S_XCD
		CALL	S_INPUT 		;键入
		CMP	D_ALT,0FFH		;判ALT
		JZ	L_CD20
		CMP	AL,1BH			;ESC?
		JZ	L_CD20
		CMP	AL,' '
		JZ	L_CD20
		CMP	AL,0DH			;回车
		JNZ	L_CD30
		MOV	AL,DH			;选中项号
L_CD20:
		RET
L_CD30:
		CMP	AH,80			;↓
		JNZ	L_CD50
		CALL	S_QCD			;清原显示
		CMP	DH,CH			;已到最大号?
		JZ	L_CD40
		INC	DH			;增1
		JMP	SHORT L_CD10
L_CD40:
		MOV	DH,1			;置1
		JMP	SHORT L_CD10
L_CD50:
		CMP	AH,72			;↑
		JNZ	L_CD10
		CALL	S_QCD			;清原显示
		CMP	DH,1			;判=1?
		JZ	L_CD60
		DEC	DH			;减1
		JMP	SHORT L_CD10
L_CD60:
		MOV	DH,CH			;置最大号
		JMP	SHORT L_CD10
;〖子程序:定位显示菜单〗
S_QCD:						;清菜单行
		MOV	BL,K_MAIN+1		;普通显示颜色
		JMP	SHORT L_XCD
S_XCD:						;写菜单行
		MOV	BL,D_CDXZ		;菜单选择颜色
L_XCD:
		PUSH	CX
		PUSH	DX
		MOV	AL,CL			;项长
		MUL	DH			;*号
		XOR	CH,CH
		SUB	AX,CX
		ADD	AX,BP
		MOV	SI,AX			;串首
		ADD	DH,BYTE PTR D_DX+1	;行
		MOV	DL,BYTE PTR D_DX	;列
		CALL	S_XSZFC 		;显示字符串
		POP	DX
		POP	CX
		RET
S_CDKZ		ENDP

;子程序:显示字符BH,位置DX(显示后+1
S_XSZF		PROC	NEAR
		PUSH	BX
		CMP	D_MODE,9		;判单显?
		JA	L_XF1
		CMP	BL,70H			;判反相?
		JZ	L_XF1
		MOV	BL,7
L_XF1:
		MOV	AX,1409H		;显示
		INT	10H
		INC	DX			;列+1
		POP	BX
		RET
S_XSZF		ENDP

;子程序:显示字符串SI,结尾0,BL=属性
S_XSZFC 	PROC	NEAR
		LODSB
		OR	AL,AL			;判结束?
		JZ	L_X4
		CMP	AL,'!'                  ;反显?
		JNZ	L_X3
		CMP	D_MODE,9		;判单显?
		JBE	L_X1
		CALL	S_BL
		JMP	SHORT S_XSZFC
L_X1:
		CMP	BL,70H			;原反显?
		JZ	L_X2
		MOV	BL,70H
		JMP	SHORT S_XSZFC
L_X2:
		MOV	BL,7
		JMP	SHORT S_XSZFC
L_X3:
		MOV	BH,AL
		CALL	S_XSZF			;显示字符
		JMP	SHORT S_XSZFC
L_X4:
		RET
S_BL:
		ROR	BL,1			;前景背景交换
		ROR	BL,1
		ROR	BL,1
		ROR	BL,1
		RET
S_XSZFC 	ENDP

;子程序:处理页 DL=最大页号,DH=当前号
S_PAGE		PROC	NEAR
		CALL	S_INPUT 		;键入
		CMP	D_ALT,0FFH		;判ALT
		JZ	L_P00
		CMP	AL,1BH			;ESC?
		JNZ	L_P0
		POP	AX
		POP	AX
		JMP	L_RET
L_P0:
		OR	AL,AL
		JZ	L_P1
		CMP	AL,80H			;回车?
		JAE	L_P1
L_P00:
		POP	AX
		RET
L_P1:
		MOV	AL,DH
		CMP	AH,72			;↑
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
		CMP	AH,80			;↓
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

;子程序:居中加宽显示标题ES:SI 窗口参数首:DI(DI+2-窗口宽)
S_XSBT		PROC	NEAR
		PUSH	SI
		XOR	CX,CX
L_BT1:
		LODSB
		OR	AL,AL			;判串尾?
		JZ	L_BT2
		INC	CX
		JMP	SHORT L_BT1
L_BT2:
		POP	SI

		SHL	CL,1			;串长*2
		MOV	CH,[DI+2]		;窗口宽
		SUB	CH,CL
		SHR	CH,1			;左空

		PUSH	DX
		PUSH	BX
		ADD	DL,CH
		CALL	S_BL
		MOV	AX,140FH		;显示字符串
		INT	10H
		POP	BX
		POP	DX
		RET
S_XSBT		ENDP
;============================================================================
D_16		DB	'0123456789ABCDEF',0
T_ASC		DB	'ASCII 字符表',0
D_ZF		DB	0			;当前字符

S_ZFB		PROC	NEAR
		MOV	DI,OFFSET K_ZFB
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_ASC
		CALL	S_XSBT			;显示标题
		XOR	CX,CX
		MOV	SI,OFFSET D_16		;'0123456789ABCDEF'
		PUSH	DX
		ADD	DX,104H
L_ZFB1:
		LODSB
		OR	AL,AL			;结束?
		JZ	L_ZFB2
		MOV	BH,AL			;字符
		CALL	S_XSZF
		MOV	BH,' '                  ;空格
		CALL	S_XSZF
		JMP	SHORT L_ZFB1
L_ZFB2:
		POP	DX
		ADD	DX,202H

		MOV	SI,OFFSET D_16		;'0123456789ABCDEF'
		MOV	D_ZF,0
L_ZFB3:
		LODSB
		OR	AL,AL			;结束?
		JZ	L_INRET
		PUSH	DX
		MOV	BH,AL			;行字符
		CALL	S_XSZF
		MOV	BH,' '                  ;空格
		CALL	S_XSZF
		MOV	DI,16
L_ZFB4:
		MOV	BH,D_ZF 		;当前字符
		CALL	S_XSZF
		MOV	BH,' '                  ;空格
		CALL	S_XSZF
		INC	D_ZF			;字符+1
		DEC	DI
		JNZ	L_ZFB4
		POP	DX
		INC	DH
		JMP	SHORT L_ZFB3
L_INRET:
		CALL	S_INPUT 		;键入并返回
		CMP	AL,1BH
		JZ	L_INRET1
		RET
L_INRET1:
		POP	AX
		JMP	L_RET
S_ZFB		ENDP
;----------------------------------------------------------------------------
T_KZASC 	DB	'扩展ASCII码表',0
D_KZASC 	DB	'0FH-SHIFT+TAB  10H-19H:ALT+QWERTYUIOP',0
		DB	'1EH-26H:ALT+ASDFGHJKL   2CH-32H:ALT+ZXCVBNM',0
		DB	'3BH-44H:F1~F10 47H-HOME       48H-UP↑',0
		DB	'49H-PGUP       4AH-ALT+"-"※  4BH-LEFT←',0
		DB	'4DH-RIGHT→    4EH-ALT+"+"※  4FH-END',0
		DB	'50H-DOWN↓     51H-PGDN       52H-INS',0
		DB	'53H-DEL        54H-5DH:SHIFT+F1~F10',0
		DB	'5EH-67H:CTRL+F1~F10     68H-71H:ALT+F1~F10',0
		DB	'72H-CTRL+PRTSC 73H-CTRL+←    74H-CTRL+→',0
		DB	'75H-CTRL+END   76H-CTRL+PGDN  77H-CTRL+HOME',0
		DB	'78H-83H:ALT+1~0,-,=           84H-CTRL+PGUP',0
		DB	'85H-F11        86H-F12        87H-SHIFT+F11',0
		DB	'88H-SHIFT+F12  89H-CTRL+F11   8AH-CTRL+F12',0
		DB	'8BH-ALT+F11    8CH-ALT+F12    8DH-CTRL+↑',0
		DB	'8EH-CTRL+"-"   8FH-CTRL+5     90H-CTTRL+"+"',0
		DB	'91H-CTRL+↓    92H-CTRL+INS   93H-CTRL+DEL',0
		DB	'94H-CTRL+TAB   95H-CTRL+/※   96H-CTRL+*※',0
		DB	'97H-ALT+HOME※ 98H-ALT+↑※   99H-ALT+PGUP※',0
		DB	'9BH-ALT+←※   9DH-ALT+→※   9FH-ALT+END※',0
		DB	'A0H-ALT+↓※   A1H-ALT+PGDN※ A2H-ALT+INS※',0
		DB	'A3H-ALT+DEL※  A4H-ALT+/※    A5H-ALT+TAB',0
		DB	'A6H-ALT+ENTER※         有※为专用小键盘',0,0

S_KZASC 	PROC	NEAR
		MOV	DI,OFFSET K_KZASC
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_KZASC
		CALL	S_XSBT			;显示标题
		MOV	SI,OFFSET D_KZASC
L_XSINRET:
		CALL	S_CKXS102		;显示窗口内容
		JMP	L_INRET
S_KZASC 	ENDP
;----------------------------------------------------------------------------
T_QWXS		DB	'显示各区汉字',0
D_QW		DB	'第16区 ０ １ ２ ３ ４ ５ ６ ７ ８ ９',0
		DB	'  1600    啊 阿 埃 挨 哎 唉 哀 皑 癌',0
		DB	'  1610 蔼 矮 艾 碍 爱 隘 鞍 氨 安 俺',0
		DB	'  1620 按 暗 岸 胺 案 肮 昂 盎 凹 敖',0
		DB	'  1630 熬 翱 袄 傲 奥 懊 澳 芭 捌 扒',0
		DB	'  1640 叭 吧 笆 八 疤 巴 拔 跋 靶 把',0
		DB	'  1650 耙 坝 霸 罢 爸 白 柏 百 摆 佰',0
		DB	'  1660 败 拜 稗 斑 班 搬 扳 般 颁 板',0
		DB	'  1670 版 扮 拌 伴 瓣 半 办 绊 邦 帮',0
		DB	'  1680 梆 榜 膀 绑 棒 磅 蚌 镑 傍 谤',0
		DB	'  1690 苞 胞 包 褒 剥               ',0
		DB	'!按↑→增加,←↓减少,<ESC>返回主菜单.!',0,0
D_Q		DB	16			;区号

S_GQHZ		PROC	NEAR
		MOV	DI,OFFSET K_GQHZ
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_QWXS
		CALL	S_XSBT			;显示标题
		ADD	DX,102H
L_GQHZ1:
		MOV	AL,D_Q			;区号
		CBW
		MOV	CL,10
		DIV	CL
		OR	AX,3030H		;十进制
		MOV	SI,OFFSET D_QW+2
		MOV	CX,11
L_GQHZ2:
		MOV	[SI],AX 		;写入区号
		ADD	SI,37			;下一行
		LOOP	L_GQHZ2

		PUSH	BX
		PUSH	DX
		MOV	DI,OFFSET D_QW+37
		MOV	BL,10
		XOR	DH,DH			;位号
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
		MOV	DL,D_Q			;区号
		MOV	AX,DX
		ADD	AX,0A0A0H		;汉字内码
L_GQHZ7:
		STOSW				;写入
		INC	DI
		INC	DH
		DEC	BH
		JNZ	L_GQHZ4
		DEC	BL
		JNZ	L_GQHZ3
		POP	DX
		POP	BX

		MOV	SI,OFFSET D_QW
		CALL	S_CKXS			;窗口内容显示
L_GQHZ8:
		MOV	BH,D_Q
		CALL	S_INPUT 		;取按键
		CMP	D_ALT,0FFH		;判ALT
		JZ	L_GQHZA
		CMP	AL,1BH			;ESC?
		JNZ	L_GQHZ9
		POP	AX
		JMP	L_RET
L_GQHZ9:
		CMP	AL,0DH			;返主菜单
		JNZ	L_GQHZB
L_GQHZA:
		RET
L_GQHZB:
		CMP	AH,75			;←
		JZ	L_GQHZC
		CMP	AH,80			;↓
		JNZ	L_GQHZD
L_GQHZC:
		DEC	BH
		CMP	BH,1
		JNB	L_GQHZF
		MOV	BH,87
		JMP	SHORT L_GQHZF
L_GQHZD:
		CMP	AH,72			;↑
		JZ	L_GQHZE
		CMP	AH,77			;→
		JNZ	L_GQHZ8
L_GQHZE:
		INC	BH			;区号+1
		CMP	BH,95
		JB	L_GQHZF
		MOV	BH,1
L_GQHZF:
		MOV	D_Q,BH
		JMP	L_GQHZ1
S_GQHZ		ENDP
;----------------------------------------------------------------------------
T_SP		DB	'双拼代码表',0
D_SP		DB	'声母：zh-V     ch-I      sh-U',0
		DB	'韵母：          i-I       u-U     ü-V',0
		DB	'      a-A      ia-R *    ua-W 挖',0
		DB	'      o-O      uo-O',0
		DB	'      e-E      ie-T 铁            üe-W',0
		DB	'      ai-L               uai-Y',0
		DB	'      ei-D               ui-V',0
		DB	'      ao-K    iao-M 苗',0
		DB	'      ou-P    iu-Q',0
		DB	'      an-J    ian-B 边   uan-Z钻  üan-Z',0
		DB	'      en-F    in-N  您   un-C 村  ün-C',0
		DB	'      ang-H   iang-X香   uang-X',0
		DB	'      eng-G   ing-Y 英',0
		DB	'      ong-S   iong-S拥',0
		DB	'注:单韵母aeo双打,双字母照打,ang为ag,eng为eg',0
		DB	'   键入ap可调出所有的偏旁部首(在二级字区)',0,0

S_SPDM		PROC	NEAR
		MOV	DI,OFFSET K_SPDM
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_SP
		CALL	S_XSBT			;显示标题
		MOV	SI,OFFSET D_SP
		JMP	L_XSINRET		;显示窗口内容并键入
S_SPDM		ENDP
;----------------------------------------------------------------------------
T_XSYS		DB	'显示16种前景背景颜色',0
D_XSYS		DB	'背景\０ １ ２ ３ ４ ５ ６ ７ ８ ９ Ａ Ｂ Ｃ Ｄ Ｅ Ｆ 前景',0,0
D_YS		DB	'黑 蓝 绿 青 红 粉 棕 白 灰 蓝 绿 青 红 粉 黄 白 ',0

S_YS		PROC	NEAR
		MOV	DI,OFFSET K_YS
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_XSYS
		CALL	S_XSBT
		MOV	SI,OFFSET D_XSYS
		CALL	S_CKXS102		;显示窗口内容并键入
		MOV	BH,'0'                  ;背景色
L_YS1:
		INC	DH			;行+1
		PUSH	DX
		CALL	S_XSKG			;显示空格
		CALL	S_XSKG
		CALL	S_XSZF			;显示背景色
		CALL	S_XSKG
		CALL	S_XSKG
		CALL	S_XSYS			;显示一行
		POP	DX
		INC	BH			;背景色+1
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
		MOV	SI,OFFSET D_YS		;颜色串
		MOV	BL,BH
		SUB	BL,'0'
		CMP	BL,9
		JBE	L_XY1
		SUB	BL,7
L_XY1:
		MOV	CL,4
		SHL	BL,CL			;背景色
		MOV	CX,16
L_XY2:
		LODSB
		CALL	S_XSAL
		LODSB
		CALL	S_XSAL
		LODSB
		CALL	S_XSAL
		INC	BL			;前景色+1
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
T_XSFS		DB	'显示方式一览表',0
D_XSFS		DB	'显示方式  分辨率   行×列   点阵  色号   显示模块     显示器类型',0
		DB	'─────────────────────────────────',0
		DB	'    6    640×200  25×80   8×8   0,1   CGA,CGA25   CGA,EGA,VGA',0
		DB	'    9    640×400  25×80   8×16  0,1    HGA.COM        HGA',0
		DB	'  10H    640×350  25×80   8×14   16    EGA.COM      EGA,VGA',0
		DB	'  12H    640×480  26×80   8×16   16    VGA.COM        VGA',0
		DB	'  255    640×480  30×80   8×16  256    VGA.COM       SVGA',0,0

S_XSFS		PROC	NEAR
		MOV	DI,OFFSET K_XSFS
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_XSFS
		CALL	S_XSBT
		MOV	SI,OFFSET D_XSFS
		JMP	L_XSINRET		;显示窗口内容并键入
S_XSFS		ENDP
;----------------------------------------------------------------------------
T_SL		DB	'矢量汉字字体号',0
D_SL1		DB	' 0-宋体简(HZKSJSTJ)       8-隶变简(HZKSLLBJ) ',0
		DB	' 1-仿宋简(HZKSLFSJ)       9-大黑简(HZKSLDHJ) ',0
		DB	' 2-黑体简(HZKSLHTJ)      10-魏碑简(HZKSLWBJ) ',0
		DB	' 3-楷体简(HZKSLKTJ)      11-行楷简(HZKSLXKJ) ',0
		DB	' 4-标宋简(HZKSLXBJ)      12-隶书简(HZKSLLSJ) ',0
		DB	' 6-细圆简(HZKSLY1J)      13-姚体简(HZKSLYTJ) ',0
		DB	' 7-准圆简(HZKSLY3J)      14-美黑简(HZKSLMHJ) ',0
		DB	' ',0
D_SL2		DB	'20-宋体繁(HZKSLSTF)      28-隶变繁(HZKSLLBF) ',0
		DB	'21-仿宋繁(HZKSLFSF)      29-大黑繁(HZKSLDHF) ',0
		DB	'22-黑体繁(HZKSLHTF)      30-魏碑繁(HZKSLWBF) ',0
		DB	'23-楷体繁(HZKSLKTF)      31-行楷繁(HZKSLXKF) ',0
		DB	'26-细圆繁(HZKSLY1F)      32-琥珀繁(HZKSLHPF) ',0
		DB	'27-准圆繁(HZKSLY3F)      33-综艺繁(HZKSLZYF) ',0
		DB	'            有',127,'为此字库已安装',0,0

S_SLZT		PROC	NEAR
		MOV	AX,357EH		;取INT7E
		INT	21H
		OR	BX,BX			;判安装?
		JZ	L_SLZT9
		XOR	DX,DX			;取READSL安装状态
		INT	7EH
		MOV	BX,ES
		CMP	BX,DX			;判是否READSL模块?
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
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_SL
		CALL	S_XSBT
		MOV	SI,OFFSET D_SL1
		JMP	L_XSINRET		;显示窗口内容并键入
S_SLZT		ENDP
;----------------------------------------------------------------------------
T_ZXB		DB	'字型和字号表',0
D_ZXB		DB	'!字型表!(`@A~x):',0
		DB	'A-宋体24×24   E-仿宋24×24   I-黑体24×24   M-楷体24×24 (基本点阵)',0
		DB	'B-宋体48×24   F-仿宋48×24   J-黑体48×24   N-楷体48×24 (横扩一倍)',0
		DB	'C-宋体24×48   G-仿宋24×48   K-黑体24×48   O-楷体24×48 (纵扩一倍)',0
		DB	'D-宋体48×48   H-仿宋48×48   L-黑体48×48   P-楷体48×48 (横纵扩一倍)',0
		DB	'Q-16×16(基本) R-32×16(横扩) S-16×32(纵扩) T-32×32(横纵扩)',0
		DB	'U-40×40(宋体) V-40×40(仿宋) W-40×40(黑体) X-40×40(楷体)',0
		DB	'a-宋体16×24   e-仿宋16×24   i-黑体16×24   m-楷体16×24 (横缩半倍)',0
		DB	'b-宋体36×24   f-仿宋36×24   j-黑体36×24   n-楷体36×24 (横扩半倍)',0
		DB	'c-宋体24×36   g-仿宋24×36   k-黑体24×36   o-楷体24×36 (纵扩半倍)',0
		DB	'd-宋体36×36   h-仿宋36×36   l-黑体36×36   p-楷体36×36 (横纵扩半倍)',0
		DB	'q-16×24(基本) r-32×24(横扩) s-16×48(纵扩) t-32×48(横纵扩) 纵向扩24',0
		DB	'u-32×32(宋体) v-32×32(仿宋) w-32×32(黑体) x-32×32(楷体)',0
		DB	'!字号表!(180DPI.宽×高):0-90×90',0
		DB	'1-72×72 10-80×80 11-60×80 12-80×60 13-54×72 14-72×54',0
		DB	'2-48×48 20-60×60 21-45×80 22-80×45 23-36×48 24-48×36',0
		DB	'3-40×40 30-44×44 31-33×44 32-44×33 33-30×40 34-40×30',0
		DB	'4-32×32 40-36×36 41-27×36 42-36×27 43-24×32 44-32×24',0
		DB	'5-24×24 50-28×28 51-21×28 52-28×21 53-18×24 54-24×18',0
		DB	'6-20×20 60-22×22 61-16×22 62-22×16 63-15×20 64-20×15',0
		DB	'7-16×16 70-18×18 71-13×18 72-18×13 73-12×16 74-16×12',0,0

S_ZXZH		PROC	NEAR
		MOV	DI,OFFSET K_ZXZH
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_ZXB
		CALL	S_XSBT
		MOV	SI,OFFSET D_ZXB
		JMP	L_XSINRET		;显示窗口内容并键入
S_ZXZH		ENDP
;----------------------------------------------------------------------------
T_PB		DB	'系统级公文排版',0
D_PB		DB	"  `'版号,页号` - 设置排版(取消软回车、行禁则、页号初值1)",0
		DB	'        有版号则按排版参数设置页长、左空和行宽,否则保持原值',0
		DB	'        若有页号则设置初始打印页号(缺省为1.为0则不打页号)',0
		DB	'  `,` - 设置本行居中(按当前行宽)',0
		DB	'  `,,` - 设置本行居右(按当前行宽)',0
		DB	'  `[[空格数` - 段排版第二行后行首加空格数',0
		DB	'  `:` - 打印参数初始化.若原排版则打印末页页号',0
		DB	'  `@字型` - 置点阵汉字字型(A~x,默认A)',0
		DB	'  `@@字号,字体` - 设置字号(PRTH可按分辨率DPI自动折算)',0
		DB	'  `&行距` - 置行距(1~255,默认20)',0
		DB	'  `^列数` - 置字符间距(0~255,汉字加倍,默认0.单位:点)',0
		DB	'  `#页长` - 置页长(单位点.默认纸长)',0
		DB	'  `##` - 向打印机送换页符(强制换页)',0
		DB	'  `[字符数` - 置左边空(0~2447,默认0.以点为单位)',0
		DB	'  `]字符数` - 置行宽(1~2448,以点为单位.默认最宽)',0
		DB	"例: `'1&30",0
		DB	'    `,@W`通  知',0
		DB	'    `@X',0
		DB	'        根据市人民政府通知精神,结合我单位具体情况,自',0
		DB	'    本月29日至10月4日放假6天,10月5日(星期三)上班。',0
		DB	'        特此通知。',0
		DB	'    `,,@U××厂办公室  `',0,0

S_XTPB		PROC	NEAR
		MOV	DI,OFFSET K_XTPB
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_PB
		CALL	S_XSBT
		MOV	SI,OFFSET D_PB
		JMP	L_XSINRET		;显示窗口内容并键入
S_XTPB		ENDP
;----------------------------------------------------------------------------
T_TSXS		DB	'2.13L特殊显示功能',0
D_TSXS1 	DB	'C色号,填充色] - 设置图形颜色          D点X,Y] - 画点',0
		DB	'E宽度] - 向右上画线                   U长度] - 向上画线',0
		DB	'F宽度] - 向右下画线                   X高度] - 向下画线',0
		DB	'G宽度] - 向左下画线                   Y长度] - 向右画线',0
		DB	'H宽度] - 向左上画线                   Z长度] - 向左画线',0
		DB	'L终点X,Y] - 画斜线(若X有符号则为相对当前点的相对坐标)',0
		DB	'L/长度,角度] - 按角度画线(以向右为0度,不移当前点)',0
		DB	'B宽,高] - 画矩形(当前点为左下角.宽或高=0不画,宽和高都=0画屏幕边框线',0
		DB	'   若C命令指定了填充色则矩形中填充指定颜色',0
		DB	'V色号,左下角X,Y,宽,高,类型,间隔,线宽,方式] - 矩形区填线      /,0=不画',0
		DB	'   其中:类型=1横线,=2竖线,=3左斜线,=4右斜线.方式=1画边框线(C命令指定颜色)',0
		DB	'O圆心X,Y,半径,方式] - 画圆(INT10K).若C命令指定了填充色则圆和半圆中填充',0
		DB	'   其中:方式项四舍五入后=0则画半圆,=1画半圆弧,否则画整圆',0
		DB	'O圆心X,Y,长半径,方式,短半径,起始角,终止角,标志] - 画圆,椭圆或圆弧(INT10V)',0
		DB	'   其中:方式=0为半圆,=1为半圆弧,等于其它值和缺省时为圆)',0
		DB	'        标志=1画弧,=0画扇形(弧断点与圆心有连线). 填充颜色由C命令指定',0
		DB	'K比例因子] - 设置比例因子(1~255,实际要/16)',0
		DB	'J] - 执行命令串                       W...] - 定义命令串(命令行最后)',0,0

D_TSXS2 	DB	'P内色号,边界色号] - 填充',0
		DB	'M...] - 前缀：移当前点但不画线或点    N...] - 前缀：画线但不移当前点',0
		DB	'_行,列,长] - 按字符行列画横线         |行,列,长] - 按字符行列画竖线',0
		DB	'#行,列,高,宽,方式] - 按字符行列画框线(若有方式,则向里缩进4点)',0
		DB	'Q色号] - 清屏(若无色号则初始化工作参数.若有“色号”则按此颜色清屏)',0
		DB	'R控制字] - 光标控制(奇数建立,偶数取消)',0
		DB	'I参数串] - 执行INT10中断(其中:参数串为寄存器 AH,AL,BH,BL,CH,CL,DH,DL)',0
		DB	'   当第一参数为255时,第二参数就是执行的中断号,以下顺序为AH,AL,BH...',0
		DB	'   若有返回参数则填入40:0F0H开始的14个单元里,顺序为:AX,BX,CX,DX,BP,SI,DI',0
		DB	'S前景色,背景色] - 设置字符和汉字颜色',0
		DB	'*行,列,字符数,前景色,背景色] - 重显屏幕上的字符串',0
		DB	'A扩展ASCII码] - 模拟功能键(参看SETUP功能键设置)',0
		DB	'%功能符或音符] - 演奏音乐(命令行最后)',0
		DB	'   其中:功能符为   t节拍    指定节拍(默认100,每分钟节拍数)',0
		DB	'        CDEFGAB  定调(开机为C调)     1234567  音名   0  休止符',0
		DB	'        #  升半音       b  降半音    q  升八度       d  降八度',0
		DB	'        .  附点         -  延长音    _  八分音符     =  十六分音符',0
		DB	'   注:升降八度、升降半音在音名前，延长、附点、四八分音符在音名后',0,0

D_TSXS3 	DB	'！秒数 - 延时 单位:秒.范围:0-4096      T0或1] - 简繁显示切换(1简0繁)',0
		DB	'^次数] - 设置演奏次数,无次数则打开或关闭音乐',0
		DB	'@左上角字符列,扫描线行,图象文件名$] - 显示16色PCX格式图象',0
		DB	'~X1,Y1,X2,Y2,图象文件名$] - 保存16色PCX格式图象',0
		DB	'   其中:X1为图象左上角字符列(0-79), Y1为左上角纵坐标(0-479)',0
		DB	'        X2为图象右下角字符列(1-79), Y2为右下角纵坐标(1-479)',0
		DB	'        图象文件扩展名应为PCX,其后必须有$符',0
		DB	'[功能符、汉字或字符] - 显示汉字或字符(命令行最后).以下为功能符:',0
		DB	'   @字型  指定字型(开机字型A)',0
		DB	'   格式一:字型为字母A-X,a-x(A-P同打印,a~p为A~P横纵扩,Q~T或u~x为16点阵)',0
		DB	'   格式二:字型为矢量汉字的三个参数(用逗号隔开).仅INT10K和INT10V',0
		DB	'       第一个为横向点数(范围:4~639), 第二个为纵向点数(范围:4~479)',0
		DB	'       第三个数为矢量字体号(若缺省则保持原值)',0
		DB	'   ^间距  指定字符间距(0-255,汉字间距加倍,开机为0)',0
		DB	'   &间距  指定行间距(0-255,开机为1)',0
		DB	'   _点数  水平定位(0-639,开机为0)      |点数  垂直定位(0-479,开机为0)',0
		DB	'   *色号  前景颜色(0-15,开机最大)      #色号  背景颜色(0-15,开机为0)',0
		DB	'   \0或1  0为汉字背景复盖原图形,1不复盖(开机为不复盖)',0,0
D_TSXS		DB	0			;窗口页号

S_TSXS		PROC	NEAR
		MOV	SI,OFFSET D_TSXS1	;第一页
		CMP	D_TSXS,0
		JZ	L_TSXS1
		MOV	SI,OFFSET D_TSXS2	;第二页
		CMP	D_TSXS,1
		JZ	L_TSXS1
		MOV	SI,OFFSET D_TSXS3	;第三页
L_TSXS1:
		PUSH	SI
		MOV	DI,OFFSET K_TSXS
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_TSXS
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;显示窗口内容
		MOV	DH,D_TSXS
		MOV	DL,2			;最大页号
		CALL	S_PAGE			;处理页
		MOV	D_TSXS,AL
		JMP	SHORT S_TSXS
S_TSXS		ENDP
;----------------------------------------------------------------------------
T_TSDY		DB	'特殊打印功能',0
D_TSDY1 	DB	'`@字型` - 置点阵汉字字型(A~x,默认A)',0
		DB	'`@字型` - 置矢量汉字字型(字型为三个数:宽,高,字体号)',0
		DB	'    其中: 宽或高范围1~255.字体号请参见矢量汉字表。缺省原值不变)',0
		DB	'`@@字号,字体` - 设置字号(PRTH可按分辨率DPI自动折算)',0
		DB	'    字号:0-90,1-72,2-48,3-40,4-32,5-24,6-20,7-16(宽=高.为180DPI)',0
		DB	'    十位数为1~7,个位>0奇数高为原高的3/4,偶数宽为原宽的3/4',0
		DB	'    个位<3为大号字:大1=80,大2=60,大3=44,大4=36,大5=28,大6=22,大7=18',0
		DB	'`@/或\` - 打开按分辨率折算(PRTH:@/仅字型和字距,@&还有行距,@\关闭)',0
		DB	'`@-或=` - 置多行字的空行空一行(-,默认)或多行(=)',0
		DB	'`@<或>` - 置多行字双向或单向打印(默认单向(PRTH无效)',0
		DB	'`&行距` - 置行距(1~255)',0
		DB	'`&A或B` - 设置行距单位:A-1/180英寸,B-1/120英寸(默认.仅PRNT)',0
		DB	'`&C` - 设置为行间距1/180英寸(此时&行间距可用负数.行间距+24=行距)',0
		DB	'`&D` - 设置为行间距1/120英寸(此时&行间距可用负数.行间距+16=行距)',0
		DB	'`^列数` - 置字符间距(0~255,汉字加倍,默认0.单位:点)',0
		DB	'`#页长` - 置页长(PRNT:0-255行.默认0;PRTH:0~65535点.默认单页纸长)',0
		DB	'`##` - 向打印机送换页符(强制换页)[当设为行间距时可用`E`]',0
		DB	'`*行数` - 置页间空行(0~255,默认0.PRTH无此功能)',0,0

D_TSDY2 	DB	'`*` - 清已走纸(仅PRTH)',0
		DB	'`[字符数` - 置左边空(0~2447,默认0.以点为单位)',0
		DB	'`]字符数` - 置行宽(1~2448,以点为单位.默认最宽)',0
		DB	'`~列数` - 输出空列(0~2447.一次有效)',0
		DB	'`|列数` - 水平定位(1~2447.当前行有效)',0
		DB	'`%0~7` - 置背景:0无,1网点,2网格,3横线,4竖线,5右斜线,6左斜线,7交叉线',0
		DB	'`"色号` - 置颜色(LQ2500、M1570用,0黑,1红,2蓝,3紫,4黄,5橙,6绿',0
		DB	'`$...$` - 将二$间字符直送打印机',0
		DB	'`>`或ESC+I+> - 置单向打印(PRTH无)',0
		DB	'`<`或ESC+I+< - 置双向打印(PRTH无)',0
		DB	'`;` (分号) - 置抽点打印(轻打)',0
		DB	'`\` (反斜线) - 置反白打印',0
		DB	'`/` (斜线) - 置上划线打印',0
		DB	'`_` (下划线) - 置下划线打印',0
		DB	'`=` (等号) - 置正常打印(开机状态,清以上四项)',0
		DB	'`(` (左括号) - 置左旋90度打印',0
		DB	'`)` (右括号) - 置右旋90度打印',0
		DB	'`?` (问号) - 置结束旋转(开机状态,清以上二项)',0,0

D_TSDY3 	DB	'`+` (加号) - 置上标字符',0
		DB	'`-` (减号) - 置下标字符',0
		DB	'`！` (惊叹号) - 置正常字符(开机状态,清以上二项)',0
		DB	'`.` (小数点) - 暂停打印(按任一键继续)',0
		DB	"`'版号,页号` (单引号) - 设置排版(取消软回车、行禁则、页号初值1)",0
		DB	'    有版号则按排版参数设置页长、左空和行宽,否则保持原值(需重新设置)',0
		DB	'    若有页号则设置初始打印页号(缺省为1.为0则不打页号)',0
		DB	'`,` (逗号) - 设置本行居中(按当前行宽)',0
		DB	'`,,` (两个逗号) - 设置本行居右(按当前行宽)',0
		DB	'`[[空格数` - 段排版第二行后行首加空格数',0
		DB	'`:` (冒号) - 打印参数初始化.若原排版则打印末页页号',0
		DB	'ESC+I+N1+N2 - 图象打印 N1高字节,N2低字节.后跟(N1*256+N2)*3字节数据',0
		DB	'ESC+I+A~x - 置字型(A~x)',0
		DB	'ESC+I+＇ - 取消特殊打印功能',0
		DB	'ESC+I+｀ - 恢复特殊打印功能(开机状态)',0
		DB	'ESC+I+\  - 取消WS软回车(8DH和0AH)',0
		DB	'ESC+I+/  - 恢复WS软回车8DH为0DH(开机状态)',0
		DB	'ESC+W - 执行屏幕拷贝',0,0
D_TSDY		DB	0			;页号

S_TSDY		PROC	NEAR
		MOV	SI,OFFSET D_TSDY1	;第一页
		CMP	D_TSDY,0
		JZ	L_TSDY1
		MOV	SI,OFFSET D_TSDY2	;第二页
		CMP	D_TSDY,1
		JZ	L_TSDY1
		MOV	SI,OFFSET D_TSDY3	;第三页
L_TSDY1:
		PUSH	SI
		MOV	DI,OFFSET K_TSDY
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_TSDY
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;显示窗口内容
		MOV	DH,D_TSDY
		MOV	DL,2
		CALL	S_PAGE			;处理页
		MOV	D_TSDY,AL
		JMP	SHORT S_TSDY
S_TSDY		ENDP
;----------------------------------------------------------------------------
T_INT10 	DB	'显示中断功能调用',0
D_INT1		DB	'AH=0,AL=显示方式号 - 设置显示方式',0
		DB	'AH=1,CH=光标起始线,CL=结束线 - 设定光标大小',0
		DB	'AH=2,BH=页号,DH=行号,DL=列号 - 设定光标位置',0
		DB	'AH=3,BH=页号 - 取光标位置  返回:DH=行号,DL=列号,CX=光标大小',0
		DB	'AH=4(参看BIOS手册) - 取光笔位置 (ROM-BIOS)',0
		DB	'AH=5,AL=页号 - 改变当前显示页',0
		DB	'AH=6,AL=行数(=0全滚),BH=空行填充属性 - 上滚当前页',0
		DB	'     CH=滚动窗口左上角行号,CL=列号,DH=滚动窗口右下角行号,DL=列号',0
		DB	'AH=7(其它参数同上) - 下滚当前页',0
		DB	'AH=8,BH=页号 -取光标位置字符及属性  返回:AL=ASCII码,AH=属性',0
		DB	'AH=9,AL=ASC码,BH=页号,BL=属性,CX=字符个数 - 在当前光标位置显示字符及属性',0
		DB	'AH=0AH(属性取当前位置原值,其它参数同上) - 在当前光标位置显示字符',0
		DB	'AH=0BH(参看BIOS手册) - 置屏幕彩色(CGA用)',0
		DB	'AH=0CH,AL=色号,CX=X坐标,DX=Y坐标 - 在指定坐标处写点',0
		DB	'AH=0DH,CX=X坐标,DX=Y坐标 - 在指定坐标处读点  返回:AL=色号',0
		DB	'AH=0EH,AL=ASC码 - 以TTY方式显示字符',0
		DB	'AH=0FH - 取当前显示方式  返回:AL=显示方式,AH=行字符数,BH=当前页号',0
		DB	'AH=10H(参看BIOS手册) - 设置EGA或VGA调色板 (ROM-BIOS)',0
		DB	'AH=11H(参看BIOS手册) - 设置EGA或VGA字符集 (ROM-BIOS)默认仅AL=30H有效',0
		DB	'AH=12H(参看BIOS手册) - 取EGAVGA卡工作状态 (ROM-BIOS)',0,0

D_INT2		DB	'AH=13H,ES:BP=字符串首址(AL=5不用),DX=位置,CX=串长,BH=页号 - 显示字符串',0
		DB	'    AL=0 BL=属性   显示后光标不变',0
		DB	'    AL=1 BL=属性   显示后光标移串尾',0
		DB	'    AL=2 串含属性  显示后光标不变',0
		DB	'    AL=3 串含属性  显示后光标移串尾',0
		DB	'    AL=4 BL=属性   串以0结尾 显示后光标移串尾',0
		DB	'    AL=5 BL=新属性 重显屏幕上已有字符串,显示后原光标位置不变',0
		DB	'AH=14H - 提示行操作',0
		DB	'    AL=0 - 打开或清提示行',0
		DB	'    AL=1,DL=字符码,CL=个数 - 显示字符',0
		DB	'    AL=2,DL=提示行位置 - 提示行光标定位',0
		DB	'    AL=3,DL=字符码 - 显示字符DL并推进光标  功能符仅7和8有效',0
		DB	'    AL=4 - 关闭提示行',0
		DB	'    AL=5,BH=提示行浮动行号(VGA无效),BL=提示行光带色(=0无光带,仅VGA)',0
		DB	'    AL=6 - 取显示参数  AL=显示方式, AH=最大色号, BH=提示行浮动位置',0
		DB	'           BL=4允许直接写屏,=0非, CL=显示行数, CH=每行扫描线数',0
		DB	'           SI=横向点数-1, DI=纵向点数-1, BP=显示缓冲区段',0
		DB	'           DL=显示控制参数,DH=当前提示行位置',0
		DB	'      DL:位3=0:16点阵,位0=0繁体,非0简体',0
		DB	'         位7=1直接写屏,位6=1保持提示行,位5=1扩展字符库,位4-显示方式>5即汉字',0,0

D_INT3		DB	'    AL=7 - 设置对外显示方式BH',0
		DB	'    AL=8 - 位置DX处字符反相显示',0
		DB	'    AL=9 - 在位置DX处显示字符BH, 属性为BL, CX=0按字符显示,非0可显示汉字',0
		DB	'    AL=0AH - 在提示行指定位置DL显示BL属性BP:SI处的点阵64字节',0
		DB	'    AL=0BH - 光标闪烁控制  BH=0不,非0闪烁',0
		DB	'    AL=0CH - 取虚屏区地址  BX:AX (再+25*80*2就是扩展字符库首地址)',0
		DB	'    AL=0DH - 直接写屏周期BH  取值范围1-8',0
		DB	'    AL=0EH - 取西文制表符转换码表地址 BX:AX',0
		DB	'    AL=0FH - 在指定位置DX显示加宽字符串DS:SI(以0结尾,属性为BL)',0
		DB	'    AL=10H - 打开第二提示行 BL=指定颜色(仅VGA,下同)',0
		DB	'    AL=11H - 在第二提示行显示字符DL CL=个数,BL=颜色',0
		DB	'    AL=12H - 第二提示行光标定位DL',0
		DB	'    AL=13H - 在第二提示行显示字符DL并推进光标 BL=颜色',0
		DB	'    AL=14H - 关闭第二提示行',0
		DB	'AH=15H,AL=1清除,=0显示 - 显示光标',0
		DB	'AH=16H,DX=汉字内码(字符DH=0),BP:BX=写入地址 - 读显示字模点阵',0
		DB	'    其中:字符16字节,汉字32字节(0-15字节为左半字,16-31为右半字)',0
		DB	'AH=17H,AL=0取消,非0建立 - 建立／取消光标',0
		DB	'AH=18H - 系统开关',0
		DB	'    AL=0识别汉字            AL=1不识汉字',0,0

D_INT4		DB	'    AL=2属性高位高亮        AL=3异或',0
		DB	'    AL=4不允许设置显示方式  AL=5允许设置显示方式',0
		DB	'    AL=8不允许设置闪烁      AL=9允许设置闪烁(AH=10H,BL=3)',0
		DB	'    AL=0AH关闭直接写屏      AL=0BH恢复直接写屏',0
		DB	'    AL=0CH西文制表符处理方式BH',0
		DB	'    AL=0DH光标控制 BH=1由AH=1设置, =0固定光标大小BL',0
		DB	'    AL=0EH显示方式>=6为汉字 AL=0FH恢复原方式',0
		DB	'    AL=10H设置字符闪烁      AL=11H繁体           AL=12H简体',0
		DB	'    AL=13H重显屏幕          AL=14H关闭时钟显示   AL=15H恢复时钟显示',0
		DB	'    AL=16H设置屏幕颜色:BH-前景,BL-背景,CH-边框(仅EGA和VGA)',0
		DB	'    AL=17H清虚屏区          AL=18H设置18线模式   AL=19H恢复16线模式',0
		DB	'    AL=1AH禁止设置字符集    AL=1BH允许设置字符集(AH=11H功能)',0
		DB	'    AL=1CH-INT10AH=6~10直接写屏方式    AL=1DH恢复中断方式',0
		DB	'    AL=1EH执行INT10初始化属性寄存器    AL=1FH不初始化',0
		DB	'AH=19H,AL=0关闭,=1打开 - 特显开关',0
		DB	'    AL=2 - 特显参数初始化(GW无此功能)',0
		DB	'    AL=3,若安装返回AL=83H(L),=84H(K),=85H(V),ES=特显模块段 - 返回安装状态',0
		DB	'    AL=4 - 停止演奏音乐',0
		DB	'AH=0FFH - 取安装的显示模块',0
		DB	'    返回:AH=0,AL="V"-VGA,="E"-EGA,="H"-HGA,="C"-CGA,="c"-CGA11',0,0
D_INT10 	DB	0			;页号

S_INT10 	PROC	NEAR
		MOV	SI,OFFSET D_INT1	;第一页
		CMP	D_INT10,0
		JZ	L_INT10
		MOV	SI,OFFSET D_INT2	;第二页
		CMP	D_INT10,1
		JZ	L_INT10
		MOV	SI,OFFSET D_INT3	;第三页
		CMP	D_INT10,2
		JZ	L_INT10
		MOV	SI,OFFSET D_INT4	;第四页
L_INT10:
		PUSH	SI
		MOV	DI,OFFSET K_INT10
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_INT10
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;显示窗口内容
		MOV	DH,D_INT10
		MOV	DL,3
		CALL	S_PAGE			;处理页
		MOV	D_INT10,AL
		JMP	SHORT S_INT10
S_INT10 	ENDP
;----------------------------------------------------------------------------
T_INT		DB	'键盘和打印中断调用',0
D_INT11 	DB	'    !INT 16──键盘管理!',0
		DB	'AH=0,返回AL=键入字符或汉字 - 键盘输入',0
		DB	'AH=1,返回Z标志=0有字符,=1无字符 - 检查键盘缓冲区',0
		DB	'AH=2,返回AL=转换键状态 - 取当前转换键状态',0
		DB	'     其中: 位0-右Shift, 1-左Shift, 2-Ctrl,3-Alt',0
		DB	'             4-ScrollLock, 5-NumLock, 6-CapsLock, 7-INS',0
		DB	'AH=3,AL=5 - 设置击键速度和延迟(只286以上有效)',0
		DB	'     BH=延迟,=0为250毫秒(最小). BL=击键速度,=0为30字符/秒(最快)',0
		DB	'AH=4,AL=转换键状态(同AH=2) - 置当前转换键状态',0
		DB	'AH=5,CL=字符码,CH=扫描码 - 向键盘缓冲区写字符(只286以上有效)',0
		DB	'AH=10H 同AH=0',0
		DB	'AH=11H 同AH=1',0
		DB	'AH=12H 同AH=2',0
		DB	'AH=20H,BP=段,CX=内码区首,DX=外码区首.(0-3装入,4-7取出)',0
		DB	'     AL=0或4外部词组,=1或5联想库,=2或6五笔模块,=3或7双拼词组',0
		DB	'AH=21H,AL=扩展ASCII码 - 模拟功能键',0
		DB	'AH=22H,DX=汉字内码 - 取汉字双拼码  返回AL=双拼第一码,AH=双拼第二码',0
		DB	'AH=25H,BL=颜色 - 显示版本信息',0
		DB	'AH=27H, AL=0 取汉字输入方式号DL, AL=1 设置汉字输入方式 DL=输入方式号',0
		DB	'   DL=0为ASCII方式,位0区位,位1首尾,位2拼音,位3双拼,位4五笔,位7电报',0,0

D_INT12 	DB	'AH=29H - 重显提示行',0
		DB	'AH=2AH,AL=0:写入,=1取出 - 取或置帮助模块地址BP:SI',0
		DB	'AH=2BH,AL=INT16AH值,返回AX - 执行ROM-BIOS INT 16H',0
		DB	'AH=2FH - 返回:本模块中断向量BP:SI、词参数区地址BP:DI和2.13安装路径',0
		DB	'              AX=44H-安装键盘模块CKBD',0
		DB	'   其中:[DI]-外部词组,[DI+6]-联想库,[DI+12]-五笔,[DI+18]-双拼词组',0
		DB	'    !INT 17──打印管理!',0
		DB	'AH=0,AL=字符或汉字,返回AH=打印机状态字 -  打印输出',0
		DB	'AH=1,DX=打印口号,返回AH=打印机状态字 - 初始化打印机',0
		DB	'AH=2,DX=打印口号,返回AH=打印机状态字 - 取打印机状态',0
		DB	'AH=3,AL=0直送打印机,=1本系统汉字打印 - 设置打印处理模式',0
		DB	'AH=4,AL=0关闭,=1打开 - 特殊打印功能开关',0
		DB	'AH=5,AL=字符码 - 直接输出字符AL',0
		DB	'AH=6 - 取打印参数  返回:ES=驻留内存的驱动程序段地址',0
		DB	'        AH=字型字节,AL=打印方向,CH=字符间距,CL=行距,DL=字型字母',0
		DB	'        DH="N"为PRNT, ="H"为PRTH',0
		DB	'        SI=左边空列,DI=行宽,BP低8位=字型宽,BP高8位=字型高',0
		DB	'        BL=功能字节1:位0-2背景1~7,位3轻打',0
		DB	'        BH=功能字节2:位0-反白,位1-下划线,位2-上划线,位3-左旋',0
		DB	'                     位4-右旋,位5-上标,位6-下标',0
		DB	'AX=-1(或65535) - 取安装状态 若安装则返回:AX=-2130H,DX:BX=BIOS INT17',0,0

D_INT13 	DB	'    !INT 2F──多路中断!(系统配置管理)',0
		DB	'AX=4A06H,SI=0 退出汉字系统, =1 清驱动程序和外加模块, =2 清外加模块',0
		DB	'           =3 返回:AX=0,BX=4A06H则系统已装载,若AX不变则未装载',0
		DB	'              CX:DX-BIOS中断表(1字节中断号,4字节中断向量),[DX-2]-中断数',0
		DB	'    !INT 7A──读16×16点阵字库   INT 7C──读32×32点阵字库!',0
		DB	'    !INT 7B──读24×24点阵字库   INT 7D──读40×40点阵字库!',0
		DB	'AH=字型(位0-1横扩,2-3纵扩,4-5字体,6-7点阵',0
		DB	'     若位6-7=0,位4-5=01为24点阵隔点扩,=10为16点阵,=11为16点阵扩24点',0
		DB	'     位4-5字体:=00宋体,=01仿宋体,=10黑体,=11楷体)',0
		DB	'   BH=特殊功能(位1上划线,2下划线,3左旋,4右旋,5上标,6下标,7倒转仅24点阵)',0
		DB	'   BL=当前打印行数(纵向超过24点时将打印多行,BL指示是第几行,最下24点时为0)',0
		DB	'   DX=汉字内码,若DH=0则DL=ASCII码(字符)',0
		DB	'   DS:SI读出点阵数据起始地址,CX=字节数',0
		DB	'    !INT 7E──读矢量字库! DX=0返回DX:BX缓冲区地址,AX=字库地址',0
		DB	'AX=字型宽度,BX=字体编号,CX=字型高度,DX=汉字内码(字符DH=0)',0
		DB	'SI=起始行,DI=终止行,BP=属性(位0=0水平点阵,=1垂直点阵,位11=1下标,位12=1上标',0
		DB	'         位13=0旋转90度,=1旋转180度,位14=0左旋,=1右旋,位15=0不旋转,=1旋转)',0
		DB	'返回 DX:BX=点阵缓冲区地址,AX=实际宽度,CX=实际高度',0
		DB	'    !INT 7F──读16×16点阵显示字库!(水平点阵)',0
		DB	'DX=汉字内码,返回 DX=点阵数据起始段(偏移=0)',0,0
D_QTINT 	DB	0			;页号

S_QTINT 	PROC	NEAR
		MOV	SI,OFFSET D_INT11	;第一页
		CMP	D_QTINT,0
		JZ	L_QTINT
		MOV	SI,OFFSET D_INT12	;第二页
		CMP	D_QTINT,1
		JZ	L_QTINT
		MOV	SI,OFFSET D_INT13	;第三页
L_QTINT:
		PUSH	SI
		MOV	DI,OFFSET K_QTINT
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_INT
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;显示窗口内容
		MOV	DH,D_QTINT
		MOV	DL,2
		CALL	S_PAGE			;处理页
		MOV	D_QTINT,AL
		JMP	SHORT S_QTINT
S_QTINT 	ENDP
;----------------------------------------------------------------------------
T_GNJ		DB	'联机帮助系统使用方法',0
D_GNJ		DB	'执行联机帮助:使用键盘模块帮助功能键(F11)',0
		DB	'退出联机帮助:键入<Esc>键',0
		DB	'退出本模块:  在DOS下键入 LHELP 加空格或任意参数',0
		DB	'子窗口返回主菜单:打除↑↓以外的键',0
		DB	'  在子窗口打<Esc>直接退出,再次按<F11>可直接进入该窗口.',0
		DB	'键入<Alt>+<Enter>(小键盘):提示行提示以下附加功能:',0
		DB	'  <Alt>+光标移动键←→↑↓---移动当前窗口',0
		DB	'  <Alt>+<Ins*>--背景色+1  <Alt>+<Del*>--背景色-1',0
		DB	'  <Alt>+<Home*>-前景色+1  <Alt>+<End*>--前景色-1',0
		DB	'  <Alt>+<PgUp*>-边框色+1  <Alt>+<PgDn*>-边框色-1',0
		DB	'  <Alt>+<+>----设置存盘  (有*键在专用光标键上方)',0,0

S_GNJ		PROC	NEAR
		MOV	DI,OFFSET K_GNJ
		CALL	S_XSCK			;显示窗口
		MOV	SI,OFFSET T_GNJ
		CALL	S_XSBT
		MOV	SI,OFFSET D_GNJ
		JMP	L_XSINRET		;显示窗口内容并键入
S_GNJ		ENDP

;****************************************************************************
BEGIN:
		XOR	BP,BP
		MOV	AX,1406H		;取显示参数
		INT	10H
		OR	BP,BP
		JNZ	L_S5
		MOV	DX,OFFSET NO213
		JMP	SHORT L_ERR
L_S5:
		CMP	CL,25			;判25行?
		JAE	L_S6
		MOV	DX,OFFSET NO25		;小于25,响铃
		JMP	SHORT L_ERR
L_S6:
		MOV	D_MODE,AL		;存
		CMP	AL,9			;判单显?
		JA	L_S10
		MOV	D_CDXZ,70H
L_S10:
		XOR	BP,BP
		MOV	AX,2A01H		;取帮助模块段?
		INT	16H
		OR	BP,BP
		JZ	L_S20
		CMP	BYTE PTR DS:[80H],0	;有参数退出?
		JZ	L_S12
		MOV	ES,BP
		XOR	BP,BP
		XOR	SI,SI
		MOV	AX,2A00H		;摘模块
		INT	16H
		MOV	AH,49H			;清本模块
		INT	21H
		MOV	ES,ES:[2CH]
		MOV	AH,49H			;清环境块
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
		MOV	ES,DS:[2CH]		;环境变量段
		XOR	SI,SI
		XOR	AX,AX
L_S122:
		CMP	ES:[SI],AX		;查找环境区尾?
		JZ	L_S124
		INC	SI
		JMP	SHORT L_S122
L_S124:
		ADD	SI,4
		MOV	D_FILE,SI

		MOV	BP,CS
		MOV	SI,OFFSET L_HELP
		MOV	AX,2A00H		;接到键盘模块
		INT	16H
		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
		MOV	DX,OFFSET D_END
		INT	27H

MSG		DB	'2.13L 联机帮助系统 v2.0 1999.11.15',13,10
		DB	'使用键盘模块帮助功能键(F11)进入帮助',13,10
		DB	'    在DOS下键入 LHELP 加空格:退出本模块',13,10,'$'

D_TVIU		DB	'退出!',7,13,10,'$'
D_YJCZ		DB	'程序已经调入!',7,13,10,'$'
NOHELP		DB	'未安装本程序!',7,13,10,'$'
NO213		DB	'NOT INSTALLED 2.13 SYSTEM!',7,13,10,'$'
NO25		DB	'CGA11显示模块不能使用本程序!',7,13,10,'$'
D_INPUT 	DB	5 DUP(0)

D_END	EQU	$

CSEG		ENDS
		END	START

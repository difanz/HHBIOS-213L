;	CXMB.ASM
;	1996.10.9
;	1997.1.7
DATE	EQU	'1999.11.30'

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

D_V		DB	1			;主菜单当前项
D_V1		DB	1
D_T1		DB	'┌──────────────────────────────────────┐',0
D_T3		DB	'├──────────────────────────────────────┤',0
D_T24		DB	'└──────────────────────────────────────┘',0
D_SX		DB	'│',0
D_ST		DB	'★',0
D_TITLE 	DB	' HHBIOS 2.13L 汉字系统 修改码表程序',0
D_MAIN		DB	'拼 音 码首 尾 码一键高频二键高频存    盘退    出'
D_MSG1		DB	'左右移动光标,按回车键选择功能.',0
D_MSG2		DB	'可键入区号,也可键入汉字,自动进入该字所在区,直接回车则返回主菜单.',0
D_MSG3		DB	'回车下一汉字,PgUp上一区,PgDn下一区,空格选区号,ESC退出(除ESC外均保存修改结果)',0
D_MSG4		DB	'键入汉字修改,按空格键存变量返主菜单,按ESC键直接返回主菜单.',0
D_MSG5		DB	'键入双拼码(大小写均可),直接回车返回主菜单.',0
D_MSG6		DB	'键入汉字验证是该双拼时修改,按空格键存变量,按ESC不存变量,可再选双拼码',0
D_QWMAX 	DB	'最大区位号:',0
D_INPUT 	DB	5 DUP(0)
D_QQ		DB	0
D_QH		DB	'区号:',0
D_QM		DB	'第  区',0
D_QM1		DB	'  0      1      2      3      4      5      6      7      8      9',0
D_QWM		DB	'0000',0
D_HZM		DB	'字???',0
D_GPZ		DB	'A 啊 阿 爱 安 按 案 鞍 岸 昂 奥 澳',0
D_JRSP		DB	'请键入双拼码:',0
D_11		DB	' 1  2  3  4  5  6  7  8  9 10 11',0
D_GPZ2		DB	'斑班搬般颁板版扮伴半办'
NOFILE		DB	'指定码表文件未找到!',7,13,10,'$'

D_Q		DB	0			;区号
D_W		DB	0,0			;位号
D_WI		DB	0			;写入标志
D_H		DB	0
D_L		DB	0
D_M		DB	0
D_N		DB	0
D_A1		DB	0
D_A2		DB	0
D_MB		DW	OFFSET D_PYMB

D_PYMB		DB	'PYMB',0
D_SWMB		DB	'SWMB',0

A_DZ		DW	OFFSET D_FILE		;文件名写入地址
D_FILE		DB	64 DUP(0)
D_HAN		DW	0
D_LONG		DW	0			;码表前字节数
D_SW		DB	'首尾'
D_GPZQ		DB	286*2 DUP(0)
D_END		DW	0			;文件尾地址
D_ZS		DW	0			;码表字数
D_X		DB	0			;列
D_Y		DB	0			;行
D_Z		DB	0			;码字符位

MSG		DB	'2.13L 汉字系统 修改码表程序 ',DATE,13,10
		DB	'格式: CXMB [/F:路径][/W][/?]',13,10
		DB	'其中: /F:路径 修改指定路径的码表',13,10
		DB	'      /W 修改当前目录. 缺省为2.13L安装路径的码表',13,10
		DB	'      /? 显示本程序命令行参数说明',13,10,'$'
D_WW		DB	0	;='W':2.13L安装路径, ='F':指定路径

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
		CMP	AL,0DH			;结束?
		JZ	L_10
		CMP	AL,'/'                  ;开关符?
		JNZ	L_1
		LODSB
		CMP	AL,'?'                  ;<显示帮助>
		JNZ	L_2
		MOV	DX,OFFSET MSG		;帮助
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_2:
		AND	AL,5FH
		CMP	AL,'W'                  ;处理当前目录字库
		JNZ	L_3
		MOV	D_WW,AL
		JMP	SHORT L_1
L_3:
		CMP	AL,'F'                  ;处理指定路径的字库
		JNZ	L_1
		MOV	D_WW,AL
		LODSB			;':'
		MOV	DI,OFFSET D_FILE
L_4:
		LODSB				;传送路径
		CMP	AL,' '
		JBE	L_5
		STOSB
		JMP	SHORT L_4
L_5:
		MOV	AL,'\'
		STOSB
		MOV	A_DZ,DI 		;保存文件名写入地址
		JMP	L_1
L_10:
		CMP	D_WW,'W'                ;修改当前目录码表?
		JNZ	L_20
		MOV	A_DZ,OFFSET D_FILE
		JMP	SHORT L_50
		MOV	A_DZ,DI 		;文件名写入地址
L_20:
		CMP	D_WW,'F'                ;修改指定目录码表?
		JZ	L_50
		MOV	AH,2FH			;取2.13L安装路径BP:DX
		INT	16H
		MOV	DS,BP
		MOV	SI,DX
		MOV	DI,OFFSET D_FILE	;文件名保存区
L_22:
		LODSB
		OR	AL,AL
		JZ	L_24
		STOSB
		JMP	SHORT L_22
L_24:
		MOV	AL,'\'
		STOSB
		PUSH	CS
		POP	DS
		MOV	A_DZ,DI
L_50:
		CALL	S_280			;打开码表文件
L_60:
		CALL	S_CLS			;清屏
		MOV	SI,OFFSET D_T1		;表顶
		XOR	DX,DX
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_TITLE	;标题
		MOV	DX,16H
		MOV	BX,4EH
		CALL	S_XSZF
		MOV	BX,1EH
		MOV	BP,23
		MOV	DX,100H
L_70:
		MOV	SI,OFFSET D_SX		;竖线
		PUSH	DX
		CALL	S_XSZF			;显示左边竖线
		POP	DX
		INC	DH
		DEC	BP
		JNZ	L_70

		MOV	BP,23
		MOV	DX,14EH
L_80:
		MOV	SI,OFFSET D_SX
		PUSH	DX
		CALL	S_XSZF			;显示右边竖线
		POP	DX
		INC	DH
		DEC	BP
		JNZ	L_80

		MOV	SI,OFFSET D_T3		;显示横线
		MOV	DX,200H
		CALL	S_XSZF
		MOV	SI,OFFSET D_T24 	;显示底线
		MOV	DX,1800H
		CALL	S_XSZF

		MOV	SI,6
		MOV	BP,OFFSET D_MAIN	;主菜单
		MOV	DX,105H
		MOV	BL,7
L_90:
		MOV	CX,8
		MOV	AX,1300H
		INT	10H
		ADD	BP,CX
		ADD	DL,12
		DEC	SI
		JNZ	L_90

		MOV	SI,OFFSET D_MSG1	;主菜单提示
		MOV	DX,1802H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_ST		;'★'
		MOV	DX,103H
		CMP	D_MB,OFFSET D_PYMB
		JZ	L_170
		MOV	DX,10FH
L_170:
		MOV	BX,1DH
		CALL	S_XSZF
		CALL	S_270
		MOV	CX,2000H
		MOV	AH,1			;关光标
		INT	10H
L_180:
		MOV	AH,1
		INT	16H
		JZ	L_180
		XOR	AH,AH
		INT	16H

		CMP	AL,0DH
		JZ	L_240
L_200:
		CMP	AH,77			;→
		JNZ	L_210
		INC	D_V
		CMP	D_V,7
		JB	L_210
		MOV	D_V,1
L_210:
		CMP	AH,75			;←
		JNZ	L_220
		DEC	D_V
		CMP	D_V,0
		JA	L_220
		MOV	D_V,6
L_220:
		CMP	D_MB,OFFSET D_SWMB
		JNZ	L_230
		CMP	D_V,3
		JZ	L_200
		CMP	D_V,4
		JZ	L_200
L_230:
		CALL	S_260
		MOV	AL,D_V
		MOV	D_V1,AL
		JMP	L_180
L_240:
		MOV	CX,0E0FH
		MOV	AH,1			;开光标
		INT	10H
		MOV	AL,D_V
		CMP	AL,6			;<退出>
		JNZ	L_350
		MOV	BX,D_HAN
		MOV	AH,3EH			;关闭文件
		INT	21H
		CALL	S_CLS
		MOV	AX,4C00H		;退出
		INT	21H
;----------------------------------------------------------------------------
L_350:
		CMP	AL,5			;<存盘>
		JZ	L_351
		JMP	L_450
L_351:
		CMP	D_QQ,0
		JZ	L_390
		MOV	SI,OFFSET D_QWMAX
		MOV	DX,1632H
		MOV	BX,1EH
		CALL	S_XSZF
		CALL	S_INPUT
		OR	BX,BX
		JZ	L_390
		MOV	AX,BX
		MOV	BL,100
		DIV	BL
		MOV	BL,AH
		XOR	BH,BH
		SUB	AL,16
		MOV	AH,94
		MUL	AH
		ADD	AX,BX
		SHL	AX,1
		MOV	AX,OFFSET D_BUF
		MOV	D_END,AX

		MOV	BX,D_HAN
		MOV	AH,3EH			;关闭文件
		INT	21H
		MOV	DX,OFFSET D_FILE
		MOV	AH,41H			;删除文件
		INT	21H
		MOV	DX,OFFSET D_FILE
		MOV	AX,3D02H		;打开文件
		INT	21H
		MOV	D_HAN,AX
L_390:
		MOV	BX,D_HAN
		XOR	CX,CX			;7.27
		XOR	DX,DX
		MOV	AX,4200H		;读写指针移文件首
		INT	21H
		CMP	D_MB,OFFSET D_PYMB
		JNZ	L_400
		MOV	DX,OFFSET D_GPZQ
		MOV	CX,286*2
		MOV	AH,40H
		INT	21H
		JMP	SHORT L_410
L_400:
		MOV	DX,OFFSET D_SW
		MOV	CX,4
		MOV	AH,40H
		INT	21H
L_410:
		MOV	DX,OFFSET D_BUF
		MOV	CX,D_END
		SUB	CX,DX
		MOV	AH,40H
		INT	21H
		JMP	L_60
;----------------------------------------------------------------------------
L_450:
		CMP	AL,2			;<首尾码>
		JNZ	L_480
		MOV	SI,OFFSET D_ST		;'★'
		MOV	DX,10FH
		MOV	BX,1DH			;显示
		CALL	S_XSZF
		MOV	DX,103H
		MOV	CX,2			;清
		CALL	S_QP
		CMP	D_MB,OFFSET D_PYMB	;原为拼音?
		JNZ	L_510
		MOV	BX,D_HAN
		MOV	AH,3EH
		INT	21H
		MOV	D_MB,OFFSET D_SWMB
		JMP	SHORT L_505
;............................................................................
L_480:
		CMP	AL,1			;<拼音码>
		JZ	L_481
		JMP	L_1000
L_481:
		MOV	SI,OFFSET D_ST		;'★'
		MOV	DX,103H
		MOV	BX,1DH			;显示
		CALL	S_XSZF
		MOV	DX,10FH
		MOV	CX,2			;清
		CALL	S_QP
		CMP	D_MB,OFFSET D_SWMB
		JNZ	L_510
		MOV	BX,D_HAN
		MOV	AH,3EH
		INT	21H
		MOV	D_MB,OFFSET D_PYMB
L_505:
		CALL	S_300
L_510:
		MOV	SI,OFFSET D_MSG2
		MOV	DX,1803H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_QH		;'区号:'
		MOV	DX,1732H
		MOV	BX,1EH
		CALL	S_XSZF
L_520:
		XOR	AH,AH
		INT	16H
		CMP	AL,0DH
		JNZ	L_530
		JMP	L_60
L_530:
		CMP	AL,0A0H
		JB	L_531
		CALL	S_XSAL
		SUB	AL,0A0H
		MOV	D_Q,AL
		XOR	AH,AH
		INT	16H
		CALL	S_XSAL
		SUB	AL,0A0H
		MOV	D_W,AL
		JMP	SHORT L_550
L_531:
		CMP	AL,'1'
		JB	L_532
		CMP	AL,'9'
		JBE	L_533
L_532:
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_520
L_533:
		CALL	S_XSAL
		AND	AL,0FH
		MOV	BL,AL
		XOR	AH,AH
		INT	16H
		CMP	AL,'0'
		JB	L_534
		CMP	AL,'9'
		JBE	L_535
L_534:
		MOV	AX,0E07H
		INT	10H
		JMP	L_520
L_535:
		CALL	S_XSAL
		AND	AL,0FH
		CBW
		PUSH	AX
		MOV	AL,10
		MUL	BL
		MOV	BX,AX
		POP	AX
		ADD	BX,AX
L_538:
		OR	BL,BL
		JZ	L_534
		CMP	BL,94
		JA	L_534
		MOV	D_Q,BL
		MOV	D_W,1
L_550:
		MOV	DX,1732H
		MOV	CX,9
		CALL	S_QP
L_560:
		MOV	AL,D_Q			;区号
		ADD	AL,0A0H
		MOV	D_HZM,AL
		MOV	AL,D_Q			;区号
		CBW
		MOV	DL,10
		DIV	DL
		OR	AX,3030H
		MOV	WORD PTR D_QWM,AX
		MOV	WORD PTR D_QM+2,AX
		MOV	SI,OFFSET D_QM		;'第??区'
		MOV	DX,302H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_QM1 	;'  0     1 ...'
		MOV	BX,0FH
		CALL	S_XSZF
		MOV	D_WI,0			;清写入标志

		MOV	DH,5
		MOV	BX,0FH
		MOV	CH,0
L_580:
		MOV	AL,CH
		ADD	AL,30H
		MOV	D_QWM+2,AL
		MOV	SI,OFFSET D_QWM 	;显示'1610'
		MOV	DL,2
		PUSH	CX
		CALL	S_XSZF
		POP	CX

		MOV	CL,0
L_600:
		MOV	AL,7
		MUL	CL
		ADD	AL,8
		MOV	DL,AL			;每字显示位置
		MOV	AL,10
		MUL	CH
		ADD	AL,CL			;位号
		CMP	AL,0
		JZ	L_620
		CMP	AL,94
		JA	L_620
		PUSH	AX
		ADD	AL,0A0H
		MOV	D_HZM+1,AL
		POP	BX

		MOV	AL,D_Q
		SUB	AL,16
		MOV	AH,94
		MUL	AH
		ADD	AX,BX			;汉字序号
		DEC	AX
		SHL	AX,1
		ADD	AX,OFFSET D_BUF
		MOV	BX,AX			;码表项
		MOV	AX,[BX]
		PUSH	AX
		AND	AL,1FH
		ADD	AL,60H
		MOV	D_HZM+2,AL		;第一码
		SHR	AH,1
		SHR	AH,1
		AND	AH,1FH
		ADD	AH,60H
		MOV	D_HZM+4,AH		;第三码
		POP	AX
		SHL	AX,1
		SHL	AX,1
		SHL	AX,1
		AND	AH,1FH
		ADD	AH,60H
		MOV	D_HZM+3,AH
		MOV	SI,OFFSET D_HZM 	;显示 汉字和拼音码
		MOV	BX,0FH
		PUSH	CX
		CALL	S_XSZF
		POP	CX
L_620:
		INC	CL
		CMP	CL,9
		JBE	L_600
		ADD	DH,2
		INC	CH
		CMP	CH,9
		JA	L_630
		JMP	L_580
L_630:
		MOV	SI,OFFSET D_MSG3	;底行提示
		MOV	DX,1802H
		MOV	BX,1EH
		CALL	S_XSZF

		MOV	D_QQ,0
		CMP	D_Q,87
		JBE	L_633
		MOV	D_Q,1
L_633:
		MOV	AL,D_W
		CBW
		MOV	CL,10
		DIV	CL
		MOV	D_X,AH
		MOV	D_Y,AL
		MOV	D_Z,0
L_650:
		MOV	DH,D_Y
		SHL	DH,1
		ADD	DH,5
		MOV	AL,7
		MUL	D_X
		ADD	AL,10
		ADD	AL,D_Z
		MOV	DL,AL
		MOV	AH,2			;定位
		INT	10H
L_660:
		XOR	AH,AH			;按键
		INT	16H

		CMP	AH,75			;←
		JNZ	L_730
		CMP	D_Z,0
		JZ	L_710
		DEC	D_Z
		JMP	SHORT L_650
L_710:
		CMP	D_X,1
		JNZ	L_712
		CMP	D_Y,0
		JNZ	L_712
		MOV	D_X,9
		MOV	D_Z,2
		JMP	SHORT L_650
L_712:
		CMP	D_X,0
		JZ	L_720
		MOV	D_Z,2
		DEC	D_X
		JMP	L_650
L_720:
		MOV	D_X,9
		MOV	D_Z,2
		DEC	D_Y
		JMP	L_650
L_730:
		CMP	AH,77			;→
		JNZ	L_770
L_740:
		CMP	D_Z,2
		JAE	L_750
		INC	D_Z
		JMP	L_650
L_750:
		CMP	D_X,4
		JNZ	L_752
		CMP	D_Y,9
		JNZ	L_752
		MOV	D_X,0
		MOV	D_Z,0
		JMP	L_650
L_752:
		CMP	D_X,9
		JAE	L_760
		MOV	D_Z,0
		INC	D_X
		JMP	L_650
L_760:
		MOV	D_X,0
		MOV	D_Z,0
		INC	D_Y
		JMP	L_650
L_770:
		CMP	AH,72			;↑
		JNZ	L_800
		CMP	D_X,0
		JNZ	L_772
		CMP	D_Y,1
		JNZ	L_772
		MOV	D_Y,9
		JMP	L_650
L_772:
		CMP	D_Y,0
		JZ	L_790
		DEC	D_Y
		JMP	L_650
L_790:
		CMP	D_X,4
		JBE	L_792
		MOV	D_Y,8
		JMP	L_650
L_792:
		MOV	D_Y,9
		JMP	L_650
L_800:
		CMP	AH,80			;↓
		JNZ	L_830
		CMP	D_X,4
		JBE	L_802
		CMP	D_Y,8
		JNZ	L_802
		MOV	D_Y,0
		JMP	L_650
L_802:
		CMP	D_Y,9
		JAE	L_820
		INC	D_Y
		JMP	L_650
L_820:
		CMP	D_X,0
		JNZ	L_822
		MOV	D_Y,1
		JMP	L_650
L_822:
		MOV	D_Y,0
		JMP	L_650
L_830:
		CMP	AH,73			;PGUP
		JNZ	L_840
		CALL	S_930			;将屏幕上的拼音码存缓冲区
		CMP	D_Q,16
		JBE	L_832
		DEC	D_Q
		JMP	L_560
L_832:
		JMP	L_650
L_840:
		CMP	AH,81			;PGDN
		JNZ	L_860
		CALL	S_930			;将屏幕上的拼音码存缓冲区
		CMP	D_Q,94
		JAE	L_842
		INC	D_Q
		JMP	L_560
L_842:
		JMP	L_650
L_860:
		CMP	AL,0DH			;回车
		JNZ	L_880
		CMP	D_X,4
		JNZ	L_862
		CMP	D_Y,9
		JNZ	L_862
		MOV	D_X,0
		MOV	D_Z,0
		JMP	L_650
L_862:
		CMP	D_X,9
		JAE	L_864
		INC	D_X
		JMP	L_650
L_864:
		MOV	D_X,0
		INC	D_Y
		JMP	L_650
L_880:
		CMP	AL,1BH			;ESC?
		JNZ	L_890
		JMP	L_60
L_890:
		CMP	AL,' '                  ;空格?
		JNZ	L_900
		CALL	S_930			;将屏幕上的拼音码存缓冲区
		JMP	L_510
L_900:
		CMP	AL,'A'
		JB	L_910
		CMP	AL,'Z'
		JA	L_910
		OR	AL,20H			;大写变小写
L_910:
		CMP	AL,96			;`
		JB	L_920
		CMP	AL,'z'
		JA	L_920
		MOV	CX,1
		MOV	BX,4EH
		MOV	AH,9			;显示
		INT	10H
		MOV	D_WI,1			;置写入标志
		JMP	L_740
L_920:
		JMP	L_660
;----------------------------------------------------------------------------
L_1000:
		CMP	AL,3			;<一键高频>
		JZ	L_1001
		JMP	L_1330
L_1001:
		MOV	CH,0
L_1010:
		MOV	CL,0
L_1020:
		MOV	AL,13
		MUL	CL
		ADD	AL,CH
		MOV	BL,AL
		ADD	AL,65
		MOV	D_GPZ,AL
		MOV	AL,11
		MUL	BL
		SHL	AX,1
		ADD	AX,OFFSET D_GPZQ
		MOV	SI,AX
		MOV	BX,2
L_1030:
		LODSW
		MOV	WORD PTR D_GPZ[BX],AX
		ADD	BX,3
		CMP	BL,35
		JB	L_1030
		MOV	DH,CH
		ADD	DH,5
		MOV	AL,38
		MUL	CL
		ADD	AL,4
		MOV	DL,AL
		MOV	SI,OFFSET D_GPZ
		MOV	BX,7
		PUSH	CX
		CALL	S_XSZF
		POP	CX
		INC	CL
		CMP	CL,1
		JBE	L_1020
		INC	CH
		CMP	CH,12
		JBE	L_1010

		MOV	SI,OFFSET D_MSG4	;底行提示
		MOV	DX,1802H
		MOV	BX,1EH
		CALL	S_XSZF

		XOR	AL,AL
		MOV	D_X,AL
		MOV	D_Y,AL
		MOV	D_Z,AL
		MOV	D_WI,AL
		MOV	D_H,AL
		MOV	BX,4EH
L_1070:
		MOV	DH,D_Y
		ADD	DH,5
		MOV	AL,3
		MUL	D_X
		MOV	DL,AL
		MOV	AL,38
		MUL	D_Z
		ADD	AL,6
		ADD	DL,AL
L_1080:
		MOV	AH,2
		INT	10H

		XOR	AH,AH			;键入
		INT	16H
		CMP	AH,75			;←
		JNZ	L_1140
		CMP	D_X,0
		JZ	L_1120
		DEC	D_X
		JMP	L_1070
L_1120:
		MOV	D_X,10
		JMP	L_1070
L_1140:
		CMP	AH,77			;→
		JNZ	L_1170
		CMP	D_X,10
		JAE	L_1150
		INC	D_X
		JMP	L_1070
L_1150:
		MOV	D_X,0
		JMP	L_1070
L_1170:
		CMP	AH,72			;↑
		JNZ	L_1200
		CMP	D_Y,0
		JZ	L_1180
		DEC	D_Y
		JMP	L_1070
L_1180:
		MOV	D_Y,12
		CMP	D_Z,0
		JNZ	L_1182
		MOV	D_Z,1
		JMP	L_1070
L_1182:
		MOV	D_Z,0
		JMP	L_1070
L_1200:
		CMP	AH,80			;↓
		JNZ	L_1230
		CMP	D_Y,12
		JAE	L_1210
		INC	D_Y
		JMP	L_1070
L_1210:
		MOV	D_Y,0
		CMP	D_Z,0
		JNZ	L_1212
		MOV	D_Z,1
		JMP	L_1070
L_1212:
		MOV	D_Z,0
		JMP	L_1070
L_1230:
		CMP	AL,1BH			;ESC?
		JNZ	L_1240
		JMP	L_60
L_1240:
		CMP	AL,' '                  ;空格?
		JNZ	L_1250
		CALL	S_1280
		JMP	L_60
L_1250:
		CMP	AL,0A0H 		;判汉字?
		JA	L_1260
		JMP	L_1070
L_1260:
		MOV	D_WI,1
		MOV	CX,1
		MOV	AH,9
		INT	10H
		CMP	D_H,0
		JNZ	L_1270
		MOV	D_H,1
		INC	DL
		JMP	L_1080
L_1270:
		MOV	D_H,0
		JMP	L_1070			;原为1150
;----------------------------------------------------------------------------
L_1330:
		CMP	AL,4			;<二键高频>
		JZ	L_1331
		JMP	L_60
L_1331:
		MOV	SI,OFFSET D_MSG5	;底行提示
		MOV	DX,1802H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_JRSP	;键入提示
		MOV	DX,409H
		CALL	S_XSZF
		MOV	AL,' '
		MOV	DI,OFFSET D_GPZ2	;二键高频字保存区
		MOV	CX,22
		REP	STOSB			;清
L_1360:
		XOR	AH,AH
		INT	16H
		CMP	AL,1BH			;<ESC>
		JZ	L_1362
		CMP	AL,0DH			;回车
		JNZ	L_1370
L_1362:
		JMP	L_60
L_1370:
		OR	AL,20H			;大写变小写
		CMP	AL,'a'
		JB	L_1372
		CMP	AL,'z'
		JBE	L_1380
L_1372:
		MOV	AX,0E07H
		JMP	SHORT L_1360
L_1380:
		CALL	S_XSAL
		AND	AL,1FH
		MOV	D_HZM,AL		;保存
L_1382:
		XOR	AH,AH
		INT	16H
		CMP	AL,8			;退格?
		JNZ	L_1383
		CALL	S_XSAL
		JMP	SHORT L_1360
L_1383:
		CMP	AL,0DH
		JZ	L_1362
		OR	AL,20H			;大写变小写
		CMP	AL,'a'
		JB	L_1384
		CMP	AL,'z'
		JBE	L_1386
L_1384:
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_1382
L_1386:
		CALL	S_XSAL
		AND	AL,1FH
		MOV	D_HZM[1],AL

		MOV	SI,OFFSET D_11		;'1  2  ..  11'
		MOV	DX,60CH
		MOV	BX,7
		CALL	S_XSZF

		MOV	AL,D_HZM[1]
		MOV	AH,AL
		AND	AL,7
		MOV	CL,5
		SHL	AL,CL
		ADD	AL,D_HZM
		MOV	D_A1,AL
		MOV	CL,3
		SHR	AH,CL
		MOV	D_A2,AH

		XOR	AL,AL
		MOV	D_L,AL
		MOV	D_M,AL
		MOV	D_N,AL

		MOV	CX,0
L_1410:
		MOV	BX,CX
		SHL	BX,1
		ADD	BX,OFFSET D_BUF 	;BUF区地址
		MOV	AL,[BX]
		CMP	AL,D_A1 		;判码1
		JNZ	L_1446
		MOV	AL,[BX+1]
		AND	AL,3
		CMP	AL,D_A2 		;判码2
		JNZ	L_1446
		INC	D_N
		MOV	AL,D_N
		XOR	AH,AH
		MOV	DL,31
		DIV	DL
		OR	AH,AH
		JNZ	L_1440
		INC	D_M
		MOV	D_N,0
L_1440:
		MOV	AX,CX
		MOV	DL,94
		DIV	DL
		ADD	AL,16
		MOV	D_Q,AL
		INC	AH
		MOV	D_W,AH

		MOV	DH,D_M
		ADD	DH,9
		MOV	DL,D_N
		SHL	DL,1
		ADD	DL,7
		PUSH	BX
		PUSH	CX
		MOV	BX,7
		MOV	AH,D_Q
		ADD	AH,0A0H
		MOV	AL,D_W
		ADD	AL,0A0H
		CALL	S_XSAX
		POP	CX
		POP	BX
		TEST	BYTE PTR [BX+1],80H	 ;判二键高频?
		JNZ	L_1450
L_1446:
		JMP	SHORT L_1460
L_1450:
		MOV	AL,D_L
		CBW
		SHL	AX,1
		MOV	SI,AX
		MOV	AL,D_Q
		ADD	AL,0A0H
		MOV	D_GPZ2[SI],AL
		MOV	AL,D_W
		ADD	AL,0A0H
		MOV	D_GPZ2[SI+1],AL
		INC	D_L
L_1460:
		INC	CX
		CMP	CX,D_ZS
		JA	L_1470
		JMP	L_1410
L_1470:
		MOV	BP,OFFSET D_GPZ2
		MOV	CX,2
		MOV	DX,70CH
		MOV	BX,7
		MOV	SI,11
L_1472:
		MOV	AX,1300H		;显示
		INT	10H
		ADD	BP,2
		ADD	DX,3
		DEC	SI
		JNZ	L_1472

		MOV	SI,OFFSET D_MSG6	;底行提示
		MOV	DX,1802H
		MOV	BX,1EH
		CALL	S_XSZF

		XOR	AL,AL
		MOV	D_X,AL			;初值
		MOV	D_WI,AL
		MOV	D_H,AL
L_1490:
		MOV	DH,7			;定位
		MOV	AL,3
		MUL	D_X
		ADD	AL,12
		MOV	DL,AL
		MOV	AH,2
		INT	10H
L_1500:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AH,75			;←
		JNZ	L_1540
		CMP	D_X,0
		JZ	L_1532
		DEC	D_X
		JMP	L_1490
L_1532:
		MOV	D_X,10
		JMP	L_1490
L_1540:
		CMP	AH,77			;→
		JNZ	L_1570
L_1541:
		CMP	D_X,10
		JAE	L_1542
		INC	D_X
		JMP	L_1490
L_1542:
		MOV	D_X,0
		JMP	L_1490
L_1570:
		CMP	AL,1BH			;ESC?
		JNZ	L_1580
		JMP	L_1650
L_1580:
		CMP	AL,' '                  ;空格
		JNZ	L_1590
		CALL	S_1660			;写入缓冲区
		JMP	L_1650
L_1590:
		CMP	AL,0A0H 		;判汉字?
		JBE	L_1500

		CMP	D_H,0			;汉字前字节标志
		JNZ	L_1610
		MOV	D_Q,AL
		MOV	D_H,1
		JMP	L_1500
L_1610:
		MOV	D_H,0
		MOV	D_W,AL

		MOV	AL,D_Q
		SUB	AL,176
		MOV	BX,94
		MUL	BL
		MOV	BL,D_W
		SUB	BL,161
		ADD	AX,BX
		SHL	AX,1
		ADD	AX,OFFSET D_BUF
		MOV	BX,AX

		MOV	AL,[BX]
		CMP	AL,D_A1
		JZ	L_1630
		JMP	L_1500
L_1630:
		MOV	AL,[BX+1]
		AND	AL,3
		CMP	AL,D_A2
		JZ	L_1640
		JMP	L_1500
L_1640:
		MOV	D_WI,1
		MOV	SI,OFFSET D_Q
		MOV	BX,4EH
		CALL	S_XSZF
		JMP	L_1541
L_1650:
		MOV	AX,600H 		;局部清屏
		XOR	BX,BX
		MOV	CX,402H
		MOV	DX,174DH
		INT	10H
		JMP	L_1331
;============================================================================
;子程序:显示AX DX-位置,BX-属性
S_XSAX		PROC	NEAR
		PUSH	AX
		MOV	AL,AH
		CALL	S_XSAX1
		POP	AX
S_XSAX1:
		MOV	AH,2
		INT	10H
		INC	DX
		MOV	CX,1
		MOV	AH,9
		INT	10H
		RET
S_XSAX		ENDP

;子程序:显示AL
S_XSAL		PROC	NEAR
		PUSH	DX
		MOV	DL,AL
		MOV	AH,2
		INT	21H
		POP	DX
		RET
S_XSAL		ENDP

;子程序:将屏幕上的二键高频字存缓冲区
S_1660		PROC	NEAR
		CMP	D_WI,0			;判有写入?
		JNZ	L_1680
		RET
L_1680:
		MOV	CX,0
L_1682:
		MOV	DH,7			;定位
		MOV	AL,3
		MUL	CL
		ADD	AL,12
		MOV	DL,AL
		XOR	BH,BH
		MOV	AH,2
		INT	10H
		MOV	AH,8			;取屏幕上的高频字
		INT	10H
		CMP	AL,176			;判汉字?
		JBE	L_1700
		MOV	D_Q,AL			;前字节
		INC	DX
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		CMP	AL,160			;判
		JBE	L_1700
		MOV	D_W,AL			;后字节

		MOV	BX,CX
		SHL	BX,1
		MOV	DH,D_GPZ2[BX]		;原高频字前字节
		MOV	DL,D_GPZ2[BX+1] 	;	 后字节
		CMP	DH,D_Q			;比?
		JNZ	L_1690
		CMP	DL,D_W			;比?
		JZ	L_1700
L_1690:
		CALL	S_1701
		AND	BYTE PTR [BX+1],7FH	;去原二键高频位

		MOV	DH,D_Q
		MOV	DL,D_W
		CALL	S_1701
		OR	BYTE PTR [BX+1],80H	;置新二键高频位
L_1700:
		INC	CX
		CMP	CX,10
		JBE	L_1682
		RET
S_1701:
		SUB	DH,176
		MOV	AL,94
		MUL	DH
		SUB	DL,161
		XOR	DH,DH
		ADD	AX,DX
		SHL	AX,1
		ADD	AX,OFFSET D_BUF
		MOV	BX,AX
		RET
S_1660		ENDP

;子程序:将屏幕上的一键高频字存缓冲区
S_1280		PROC	NEAR
		CMP	D_WI,0
		JNZ	L_1300
		RET
L_1300:
		MOV	CH,0			;行
L_1302:
		MOV	CL,0			;左右二列
L_1304:
		MOV	BX,0			;每列11字
L_1306:
		MOV	AL,13
		MUL	CL
		ADD	AL,CH
		MOV	AH,11
		MUL	AH
		ADD	AX,BX
	;	INC	AX
		SHL	AX,1
		ADD	AX,OFFSET D_GPZQ	;			1.7
		MOV	SI,AX

		MOV	DH,CH
		ADD	DH,5
		MOV	AL,38
		MUL	CL
		MOV	DL,AL
		MOV	AL,3
		MUL	BL
		ADD	AL,6
		ADD	DL,AL
		PUSH	BX
		XOR	BH,BH
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		MOV	[SI],AL
		INC	DX
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		MOV	[SI+1],AL
		POP	BX

		INC	BX
		CMP	BX,10
		JBE	L_1306
		INC	CL
		CMP	CL,1
		JBE	L_1304
		INC	CH
		CMP	CH,12
		JBE	L_1302
		RET
S_1280		ENDP

;子程序:将屏幕上的拼音码存缓冲区
S_930		PROC	NEAR
		CMP	D_WI,0
		JNZ	L_950
		RET
L_950:
		XOR	BH,BH
		MOV	AH,3			;取当前光标位置
		INT	10H
		PUSH	DX			;保存
		MOV	CH,0
L_952:
		MOV	CL,0
L_954:
		MOV	AL,10
		MUL	CH
		ADD	AL,CL			;K
		OR	AL,AL
		JZ	L_990
		CMP	AL,94
		JA	L_990
		CBW
		DEC	AX
		MOV	BX,AX
		MOV	AL,D_Q			;区号
		SUB	AL,16
		MOV	AH,94
		MUL	AH
		ADD	AX,BX			;序号
		SHL	AX,1
		ADD	AX,OFFSET D_BUF
		MOV	BX,AX			;码表项

		PUSH	BX
		XOR	BX,BX
		MOV	AL,2
		MUL	CH
		ADD	AL,5
		MOV	DH,AL
		MOV	AL,7
		MUL	CL
		ADD	AL,10
		MOV	DL,AL
L_960:
		MOV	AH,2			;光标定位
		INT	10H
		MOV	AH,8			;取屏幕拼音码
		INT	10H
		SUB	AL,60H
		MOV	D_HZM[BX],AL		;存
		INC	DX
		INC	BX
		CMP	BL,2
		JBE	L_960
		POP	BX

		MOV	DL,[BX+1]
		AND	DL,80H			;B
		MOV	AL,D_HZM[1]		;B(1)
		MOV	DH,AL
		SHL	AL,1			;*32
		SHL	AL,1
		SHL	AL,1
		SHL	AL,1
		SHL	AL,1
		ADD	AL,D_HZM
		MOV	[BX],AL
		SHR	DH,1
		SHR	DH,1
		SHR	DH,1
		MOV	AL,D_HZM[2]
		SHL	AL,1
		SHL	AL,1
		ADD	AL,DH
		OR	AL,DL
		MOV	[BX+1],AL
L_990:
		INC	CL
		CMP	CL,9
		JA	L_991
		JMP	L_954
L_991:
		INC	CH
		CMP	CH,9
		JA	L_992
		JMP	L_952
L_992:
		POP	DX
		XOR	BH,BH
		MOV	AH,2
		INT	10H
		RET
S_930		ENDP

;子程序:主菜单显示
S_260		PROC	NEAR
		MOV	AL,D_V1
		MOV	BX,7
		CALL	S_XSCD			;显示菜单项
S_270:
		MOV	AL,D_V
		MOV	BX,4EH
S_XSCD:
		DEC	AX
		MOV	CX,8
		PUSH	AX
		MUL	CL
		ADD	AX,OFFSET D_MAIN
		MOV	BP,AX
		POP	AX
		MOV	AH,12
		MUL	AH
		ADD	AL,5
		MOV	DL,AL
		MOV	DH,1
		MOV	AX,1300H
		INT	10H
		RET
S_260		ENDP

;子程序:打开码表文件
S_280		PROC	NEAR
S_300:
		MOV	SI,D_MB 		;当前码表文件名地址
		MOV	DI,A_DZ 		;文件名写入地址
L_301:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	L_301
		MOV	DX,OFFSET D_FILE
		MOV	AX,3D02H
		INT	21H
		JNB	L_302
		POP	AX
		MOV	DX,OFFSET NOFILE
		JMP	L_ERR
L_302:
		MOV	D_HAN,AX
		MOV	BX,AX

		CMP	D_MB,OFFSET D_PYMB
		JZ	L_303
		MOV	CX,4
		MOV	DX,OFFSET D_SWMB
		JMP	SHORT L_304
L_303:
		MOV	DX,OFFSET D_GPZQ
		MOV	CX,286*2
L_304:
		MOV	D_LONG,CX
		MOV	AH,3FH
		INT	21H

		MOV	DX,OFFSET D_BUF
		MOV	CX,-1
		MOV	AH,3FH
		INT	21H
		ADD	DX,AX
		MOV	D_END,DX		;文件尾地址
		SHR	AX,1
		MOV	D_ZS,AX 		;码表字数
		RET
S_280		ENDP

;子程序:显示字符串SI,DX=串首位置,BL=属性.显示后光标在串尾
S_XSZF		PROC	NEAR
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
S_XSZF		ENDP

;子程序:定位显示空 DX=位置,CX=长
S_QP		PROC	NEAR
		MOV	AH,2
		INT	10H
		XOR	BX,BX
		MOV	AX,920H
		INT	10H
		RET
S_QP		ENDP

;子程序:清屏
S_CLS		PROC	NEAR
		MOV	AX,600H
		XOR	BX,BX
		XOR	CX,CX
		MOV	DX,184FH
		INT	10H
		RET
S_CLS		ENDP

;子程序:键入数字 CX:字节数,返回BX
S_INPUT 	PROC	NEAR
		MOV	SI,OFFSET D_INPUT	;键入缓冲区
		MOV	DI,SI
		ADD	DI,CX
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		XOR	BX,BX
L_IN1:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,0DH			;回车?
		JZ	L_IN6
		CMP	AL,1BH			;<ESC>
		JZ	L_IN9
		CMP	AL,8			;退格?
		JNZ	L_IN5
		CMP	SI,OFFSET D_INPUT	;指针在区首?
		JA	L_IN3
L_IN2:
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_IN1
L_IN3:
		DEC	SI			;位置-1
L_IN4:
		CALL	S_XSAL			;退格
		CMP	AL,8			;退格?
		JNZ	L_IN1
		MOV	CX,1
		MOV	AX,0A20H		;显示空格
		INT	10H
		JMP	SHORT L_IN1
L_IN5:
		CMP	AL,'0'                  ;判数字?
		JB	L_IN1
		CMP	AL,'9'
		JA	L_IN1
		CMP	SI,DI			;键入满?
		JZ	L_IN2
		MOV	[SI],AL 		;写入
		INC	SI
		JMP	SHORT L_IN4
L_IN6:
		CMP	SI,OFFSET D_INPUT
		JZ	L_IN9
		MOV	BYTE PTR [SI],0
		MOV	SI,OFFSET D_INPUT	;键入区首
L_IN7:
		LODSB				;取
		OR	AL,AL
		JZ	L_IN9
		AND	AL,0FH
		CBW
		PUSH	AX
		MOV	AX,10
		MUL	BX
		MOV	BX,AX
		POP	AX
		ADD	BX,AX
		JMP	SHORT L_IN7
L_IN9:
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		RET
S_INPUT 	ENDP

D_BUF	EQU	$

CSEG		ENDS
		END	START

;	CKB?.ASM 2.13L 键盘管理模块
;	1998.8.16
DATE	EQU	"1999.11.17"

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

D_PATH	EQU	82H    ;32 DUP (0)		;2.13安装盘及路径

; 100H BYTE 汉字显示方式
; 101H BYTE 实际显示方式
; 102H BYTE =1直接写屏

		ORG	100H
START:		JMP	BEGIN
		DW	0CDEFH			;CKBD标志	[103H]

K_DISP		DB	2,1,5,39H		;显示参数	[105H]
		DB	0
D_TUX1		DB	1EH			;提示行字符色1	[10AH]
D_TUX2		DB	1AH			;提示行字符色2
D_QTS1		DB	4EH			;提示行信息颜色1
D_QTS2		DB	4AH			;提示行信息颜色2
		DB	0
K_SHIFT 	DB	2			;功能键开关SHIFT
K_CF7		DB	64H			;中/西文显示开关 [110H]
K_AF1		DB	68H			;区位码输入
K_AF2		DB	69H			;首尾码输入
K_AF3		DB	6AH			;拼音码输入
K_AF4		DB	6BH			;双拼码输入
K_CF9		DB	66H			;建立/取消纯中文
K_AF6		DB	6DH			;ASCII码输入
K_AF5		DB	6CH			;五笔码输入
K_AF10		DB	71H			;电报码输入
K_F12		DB	86H			;预选字输入
K_F11		DB	85H			;联机帮助
K_CF5		DB	62H			;系统控制
K_AF9		DB	70H			;定义双拼词组
K_CF10		DB	67H			;设置打印参数
		DB	0,0
K_FCC		DB	'Y'                     ;仿长城键盘     [120H]
K_SPKZ		DB	'1'                     ;双拼词组扩展区大小
K_PY		DB	'Y'                     ;安装拼音码表
K_SW		DB	'N'                     ;安装首尾码表
K_DB		DB	'N'                     ;安装电报码表

D_INT16 	DD	0			;INT16	  [0119H]
D_INT9		DD	0			;INT9
D_INKEY 	DB	0			;执行INT9标志
D_KBDBUF	DW	0			;键盘缓冲区可存字符数
K_DEL		DB	0			;功能键开关(=0FFH关)

D_PY		DW	0, 0			;拼音码表首、尾址
D_SW		DW	0, 0			;首尾码表首、尾址
D_2BD6		DW	0			;码表首
D_2BD8		DW	0			;码表尾

D_2BAD		DW	0			;查码表指针
D_2BAF		DW	0			;正向查码表指针
D_9646		DW	0			;反向查码表指针

D_2BB0		DB	0			;键入码计数
D_2BB1		DB	10 DUP(0)		;键入码区(10字节)
D_2CC1		DB	10 DUP(0)		;键入码区(10字节)
D_2CC0		DB	0			;拼音简码标志0FFH
D_2BCF		DB	11			;末页重码数
D_2BC0		DW	0			;写重码区指针
	;--------------------------------------------------------------------+
D_2BBA		DW	0			;重码区(可存11汉字)	     |
D_2BBC		DW	9 DUP (0)		;			     |
D_2BCE		DW	0			;重码区末字		     |
	;--------------------------------------------------------------------+
D_2BD0		DB	11			;重码区容量
D_2BD2		DB	0			;重码区计数
D_9597		DW	0			;重码总数

D_959B		DB	0FFH			;汉字输入完成态
D_95D5		DB	0			;返回码区指针
D_95D6		DB	0			;保存..
D_2BD4		DB	0			;返回双拼词偏移
D_2BAA		DW	0			;读返回码区指针
D_2BAC		DB	0			;纯中文标志

D_2BB9		DB	0			;输入状态标志
	;=1一键高频,  =2二键高频		=8双拼词组
	;=10H词组重码,=20H剩余重码,=40H预选标志 =80H二字词重字标志
D_963A		DB	0			;输入方式
	;=1区位,      =2首尾,	   =4拼音,    =8双拼
	;	      =20H五笔字型,	      =80H电报
D_963B		DB	0			;字典方式

D_2B98		DW	0			;词组段码
D_2B9A		DW	0			;查词表内码区指针
D_2B9C		DW	0			;反向查词表内码区首指针
D_2B9E		DW	0			;正向查词表内码区首指针
D_2BA0		DW	0			;词表内码区首指针
D_2BA2		DW	0			;词表外码区首指针
D_2BA5		DB	0			;查词表方向(0=正,FF=反)
D_9669		DW	0			;选中词组内码在词表地址
D_966B		DB	0			;选中词组内码长度
	;--------------------------------------------------------------------+
D_9648		DW	0			;词组重码区(可存11个)	     |
D_964A		DB	0
D_964B		DB	0			;非0表示双拼二字词第二字位移

F_SPCZ		DB	'SPCZ.DAT',0    ;9      ;共17
F_YX		DB	'YX0.DAT',0     ;8
F_INI		DB	'213L.INI',0    ;9      ;共23
F_SWMB		DB	'SWMB',0        ;5
F_PYMB		DB	'PYMB',0        ;5
F_DBMB		DB	'DBMB',0        ;5
	;--------------------------------------------------------------------+
D_9650		DB	0			;五笔词汇重码数
D_9668		DB	56			;提示行词组区长度
D_966C		DB	0			;外部词组=0,联想=1
D_9639		DB	0			;联想开关
D_966D		DB	0			;联想标志(FFH)
D_966F		DB	0			;双拼词组处理标志

D_AH		DB	0			;当前AH值

D_AH20		DW	OFFSET L_AH20		;<装入词组联想库预选>
		DW	OFFSET L_AH21		;<模拟功能键>
		DW	OFFSET L_AH22		;<取汉字双拼码>
		DW	OFFSET L_INT16		;<调用子程序>
		DW	OFFSET L_INT16		;<退出汉字功能开关>
		DW	OFFSET L_AH25		;<显示版本信息>
		DW	OFFSET L_INT16		;<设置时钟>
		DW	OFFSET L_AH27		;<取或置汉字输入方式号>
		DW	OFFSET L_INT16		;<支持亚伟速录机>
		DW	OFFSET L_AH29		;<重显提示行>
		DW	OFFSET L_AH2A		;<帮助模块地址>
		DW	OFFSET L_AH2B		;<调ROM BIOS>
		DW	OFFSET L_AH2C		;AH=2CH
		DW	OFFSET L_INT16		;AH=2DH
		DW	OFFSET L_INT16		;AH=2EH
		DW	OFFSET L_AH2F		;<取本模块中断向量>

D_213L		DB	'2.13L 汉字系统    1999年11月    版权所有   著作权人:吴晓军',0

D_9680		DW	0, 0, 0 		;外部词组参数	 [DI]
D_9686		DW	0, 0, 0 		;联想参数	 [DI+6]
D_INTWB 	DW	0, 0, 0 		;五笔模块偏移,段 [DI+12]
D_SPCZ		DW	0, 0, 0 		;双拼词组段,首址 [DI+18]

D_YX		DW	0			;预选字表当前行首址
D_YXH		DB	1			;当前行号
D_DB		DW	0			;电报码表地址

;---键盘管理中断---------------------------------
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
		CALL	S_EDIT
		JC	L_0010

		CMP	AH,4			;<置扩展键状态>
		JNZ	L_02
		XOR	DX,DX
		MOV	DS,DX
		MOV	DS:[417H],AL
		JMP	L_RET
L_02:
		CMP	AH,1			;<取键入状态>
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
		JMP	D_AH20[DI]		;执行功能20H-2FH
L_INT16:
		POP	BP			;返回并执行原INT16
		POP	SI
		POP	DI
		POP	DX
		POP	CX
		POP	BX
		POP	ES
		POP	DS
		JMP	CS:D_INT16

;AH=1 *** 取键入状态 ***
L_AH01:
		CLI
		CALL	S_INT16_1		;判键盘缓冲区有字符
		JNZ	L_0010
		CMP	D_95D5,0		;判有返回字符?
		JZ	L_0010
		MOV	AX,40H
		MOV	ES,AX
		MOV	SI,D_2BAA		;读返回码区指针
		CALL	S_XBUF1 		;写到键盘缓冲区
		CALL	S_INT16_1		;再判
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
		RET	2			;保存标志寄存器返回

;AH=25H *** 显示版本信息 BL=显示属性
L_AH25:
		CALL	S_XSBB
		JMP	SHORT L_RET

;AH=29H *** 重显提示行
L_AH29:
		CALL	S_CXTUX
		JMP	SHORT L_RET

;AH=2CH *** AL=0 byte editing, 1 pair editing, other query; AX='HK', BX=mode
L_AH2C:
		CMP	AL,1
		JA	L_EQUERY
		MOV	D_EDIT,AL
		MOV	D_ESTATE,0
L_EQUERY:
		XOR	BX,BX
		MOV	BL,D_EDIT
		MOV	AX,4B48H
		; Return BX through the saved-register slot.
		MOV	BP,SP
		MOV	[BP+10],BX
		JMP	L_RET

;AH=2FH *** 取本模块中断向量BP:SI、词参数区地址BP:DI和2.13安装路径BP:DX
L_AH2F:
		MOV	SI,OFFSET INT_16	;本模块中断向量
		MOV	DI,OFFSET D_9680	;词参数区地址
		MOV	DX,D_PATH		;2.13安装路径
		MOV	BP,CS
		MOV	AX,44H			;CKBD
		POP	CX
		POP	CX
		POP	CX
		POP	CX
		JMP	SHORT L_RET2

;AH=22H *** 取汉字双拼码 DX=汉字内码,返回AL=双拼第一码,AH=双拼第二码
L_AH22:
		MOV	AX,DX
		XCHG	AH,AL
		CALL	S_A9A0
		JMP	SHORT L_RET

;AH=21H *** 模拟功能键 AL=扩展ASC码
L_AH21:
		MOV	AH,AL
		XOR	AL,AL
		PUSH	AX
		CALL	S_JRCL
		POP	AX
		MOV	D_95D5,0
		JMP	SHORT L_RET

;AH=20H *** 装入词组和联想库 AL=0外部词组,=1联想库,=2五笔,3双拼词组
;		    取地址:  AL=4外部词组,=5联想库,=6五笔,=7双拼词组
L_AH20:
		MOV	BL,AL			;保存
		AND	AL,3			;转0-3
		MOV	AH,6			;每种6字节
		MUL	AH
		ADD	AX,OFFSET D_9680	;参数区首
		MOV	DI,AX			;

		CMP	BL,3			;判装入?
		JBE	L_2000
		MOV	BP,[DI] 		;取段
		MOV	DX,[DI+2]		;取外码区首
		POP	SI
		POP	SI
		POP	DI
		POP	CX
		JMP	SHORT L_RET2
L_2000:
		MOV	[DI],BP 		;段
		MOV	[DI+2],DX		;外码区首
		MOV	[DI+4],CX		;内码区首
L_RET:
		POP	BP			;返回
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

;AH=2BH *** 调ROM BIOS AL=AH的值
L_AH2B:
		MOV	AH,AL
		CALL	L_INT16_1		;调ROM BIOS INT16
		JMP	SHORT L_RET

;AH=2AH *** 帮助模块地址BP:SI AL=0:写入,=1取出
L_AH2A:
		OR	AL,AL
		JNZ	L_2A01
		MOV	D_HELP,SI		;写入
		MOV	D_HELP+2,BP
		JMP	SHORT L_RET
L_2A01:
		MOV	SI,D_HELP		;取出
		MOV	BP,D_HELP+2
		POP	DI
		POP	DI
		JMP	SHORT L_RET1

;AH=27H *** 取或置汉字输入方式号 AL=0取,=1置:DL=汉字输入方式号
L_AH27:
		OR	AL,AL
		JZ	L_2701
		MOV	D_963A,DL		;置
		JMP	SHORT L_RET
L_2701:
		MOV	DL,D_963A		;取
		POP	CX
		POP	CX
		POP	CX
		POP	CX
		JMP	SHORT L_RET2

INT_16		ENDP

D_KX		DB	0C9H,0CDH,0BBH                   ;框线
		DB	0BAH,20H,0BAH
		DB	0C8H,0CDH,0BCH
D_MSG		DB	'2.13L 汉 字 系 统',0
D_MSG1		DB	'  研 制 人: 吴 晓 军   1999年11月 '

;子程序:显示版本信息 BL=显示属性
S_XSBB		PROC	NEAR
		XOR	BH,BH
		MOV	DX,15
		MOV	SI,OFFSET D_KX		;框线
		CALL	S_XSYH			;显示上边线
		INC	DH
L_2501:
		PUSH	SI
		CALL	S_XSYH			;显示空行
		POP	SI
		INC	DH
		CMP	DH,6
		JNZ	L_2501

		ADD	SI,3
		CALL	S_XSYH			;显示底线

		PUSH	CS
		POP	ES
		MOV	SI,OFFSET D_MSG
		MOV	DX,217H
		MOV	AX,140FH		;加宽显示
		INT	10H
		XOR	BH,BH
		MOV	DX,417H
		MOV	BP,OFFSET D_MSG1	;版权信息
		MOV	CX,34
		MOV	AX,1300H		;显示一行
		INT	10H

		MOV	DX,700H
		MOV	AH,2
		INT	10H
		RET
;子程序:显示一行
S_XSYH:
		PUSH	DX
		LODSB
		CALL	S_DWXS			;显示左端
		MOV	CL,48
		LODSB
		CALL	S_DWXS0 		;显示中间
		LODSB
		CALL	S_DWXS			;显示右端
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

;---键盘硬中断-----------------------------------
INT_9		PROC	FAR
		CLD
		PUSHF
		CALL	CS:D_INT9		;执行原INT9

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
		MOV	BL,K_SHIFT		;=1右,=2左,=10H-SCROLL LOCK
		CMP	BL,10H
		JZ	L_9001
		TEST	AL,BL			;判SHIFT按下?
		JZ	L_9010
		JMP	SHORT L_9002
L_9001:
		TEST	AH,BL
		JZ	L_9010
L_9002:
		XOR	K_DEL,0FFH		;转换
		JZ	L_9003
		CALL	L_1404			;关提示行
		JMP	SHORT L_9030
L_9003:
		CALL	S_CXTUX 		;重显提示行
		JMP	SHORT L_9030
L_9010:
		AND	AL,0FH
		CMP	AL,0FH			;判CTRL+ALT+双SHIFT?
		JNZ	L_9020
		MOV	CS:D_EXIT,1
		JMP	SHORT L_9030
L_9020:
		CMP	D_INKEY,0		;判重入?
		JNZ	L_9030

		MOV	BX,ES:[1AH]		;键盘缓冲区首址
		CMP	BX,ES:[1CH]		;=键盘缓冲区尾?
		JNZ	L_9040
L_9030:
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
		MOV	D_INKEY,1		;置标志
		MOV	AX,ES:[BX]		;取键入字符
		CMP	AL,80H			;键入字符ASCII码>80H?
		JB	L_9042
		OR	AH,AH			;判写入的汉字?
		JZ	L_9042
		MOV	D_AH,0
		CALL	S_101K			;101扩展键处理
L_9042:
		STI
		CALL	S_JRCL			;键入字符处理
		CLI

		MOV	BX,40H
		MOV	ES,BX
		CMP	D_95D5,0		;无返回键?
		JNZ	L_9048
		MOV	DI,ES:[1CH]		;键盘缓冲区尾址
		MOV	ES:[1AH],DI		;=键盘缓冲区首址
L_9044:
		MOV	D_95D5,0
L_9046:
		MOV	D_INKEY,0		;清标志
		JMP	SHORT L_9030
L_9048:
		CMP	D_95D5,1		;1个返回码?
		JZ	L_9044
		CALL	S_XBUF			;写到键盘缓冲区
		JMP	SHORT L_9046
INT_9		ENDP

;子程序:写到键盘缓冲区 ES=40H
S_XBUF		PROC	NEAR
		MOV	SI,OFFSET D_959D	;返回码区
S_XBUF1:
		MOV	DI,ES:[1CH]		;键盘缓冲区尾址 	8.7
		MOV	ES:[1AH],DI		;=键盘缓冲区首址
		MOV	CL,D_95D5		;返回码计数
		XOR	CH,CH
		XOR	BX,BX
		CMP	CX,D_KBDBUF		;比键盘缓冲区容量?
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
		CMP	DI,ES:[82H]		;=键盘缓冲区尾?
		JNZ	L_XB3
		MOV	DI,ES:[80H]		;指向区首
L_XB3:
		LOOP	L_XB2
		MOV	ES:[1CH],DI		;键盘缓冲区尾

		OR	BX,BX
		JZ	L_XB4
		MOV	D_2BAA,SI
L_XB4:
		RET
S_XBUF		ENDP

;子程序:101键盘扩展键处理<AH , >AH
S_101K		PROC	NEAR
		CMP	K_FCC,'Y'               ;判仿长城键?
		JNZ	L_101K3
		XOR	SI,SI
L_101K1:
		CMP	AH,D_KZJB[SI]		;判键?
		JZ	L_101K2
		INC	SI
		CMP	SI,6			;结束?
		JB	L_101K1
		JMP	SHORT L_101K3
L_101K2:
		MOV	AH,K_AF1[SI]		;返回AX
		XOR	AL,AL
L_101K3:
		CMP	D_AH,10H
		JZ	L_101K4
		XOR	AL,AL
L_101K4:
		RET
S_101K		ENDP

D_KZJB		DB	52H, 47H, 49H, 53H, 4FH, 51H
	;		Ins  Home PgUp Del  End  PgDn	专用光标键上六个键

D_GNJB		DW	OFFSET L_QW		;区位(ALT+F1)
		DW	OFFSET L_SW		;首尾(ALT+F2)
		DW	OFFSET L_PY		;拼音(ALT+F3)
		DW	OFFSET L_SP		;双拼(ALT+F4)
		DW	OFFSET L_CF9		;建立/取消纯中文(CTRL+F9)
		DW	OFFSET L_ASC		;ASCII(ALT+F6)
		DW	OFFSET L_WBZX		;五笔(ALT+F5)
		DW	OFFSET L_DB		;电报(ALT+F10)
		DW	OFFSET L_YX		;预选字表(F12)
		DW	OFFSET L_HELP		;联机帮助(F11)
		DW	OFFSET L_XTK1		;系统控制(CTRL+F5)
		DW	OFFSET L_AF9		;定义双拼词组(ALT+F9)
		DW	OFFSET L_CF10		;设置打印参数(CTRL+F10)

;子程序:键入字符处理-----------------------------
S_JRCL		PROC	NEAR
		CMP	K_DEL,0 		;功能键有效?
		JZ	L_J20
		JMP	L_9BB9			;无效
L_J20:
		CMP	AH,K_CF7		;中西文显示切换:CTRL+F7
		JNZ	L_J30
		JMP	SHORT L_J40
L_J30:
		JMP	L_J100
L_J40:
		MOV	AX,DS:[101H]		;AL:当前显示方式,AH=1:直接写屏
		CMP	AL,4			;判西文?
		JB	L_J50
		CMP	AL,7
		JZ	L_J50
		MOV	AX,1805H		;允许显示方式转换
		INT	10H
		MOV	AX,180AH		;关闭直接写屏
		INT	10H
		MOV	AX,3			;设置西文显示方式
		INT	10H
		JMP	SHORT L_J80
L_J50:
		OR	AH,AH			;=0:非直接写屏
		JNZ	L_J60
		MOV	AL,DS:[100H]		;汉字显示方式
		JMP	SHORT L_J70
L_J60:
		MOV	AX,180BH		;打开直接写屏
		INT	10H
		MOV	AX,3
L_J70:
		INT	10H
L_J80:
		MOV	AX,1C0DH		;回车
		MOV	BX,40H
		MOV	ES,BX
		MOV	BX,ES:[1AH]
		MOV	ES:[BX],AX		;返回回车键
L_J90:
		JMP	L_9BB9			;返回一个键
L_J100:
		MOV	DX,CS:[100H]		;DL=汉字方式,DH=当前方式
		CMP	DH,DL			;是否汉字显示方式?
		JNZ	L_J90
		OR	AL,AL			;判功能键
		JNZ	L_J130

		CMP	AH,0A1H 		;ALT+PGDN*,显示2.13L标题
		JNZ	L_J110
		MOV	BL,D_0A1H		;色号
		CALL	S_XSBB			;显示
		INC	D_0A1H			;色号+1
		JMP	L_9BB9
D_0A1H		DB	1EH

;【查找功能键】
L_J110:
		MOV	SI,OFFSET K_AF1 	;功能键表
L_J120:
		CMP	AH,[SI] 		;判功能键?
		JZ	L_J140
		INC	SI
		CMP	BYTE PTR [SI],0 	;表尾?
		JNZ	L_J120
L_J130:
		JMP	L_9C86			;字符处理.原为9C90	12.10
L_J140:
		SUB	SI,OFFSET K_AF1
		SHL	SI,1
		JMP	D_GNJB[SI]		;转功能模块

D_DX0		DW	0			;初始位置
D_AF9		DB	0
;【定义双拼词组】
L_AF9:
		MOV	D_AF9,AH
		JMP	CF1_0
AF9_A:
		MOV	SI,OFFSET D_BUF
		MOV	DI,30H			;词组暂存区
		PUSH	CS
		POP	ES
		XOR	CX,CX
AF9_B:
		LODSW				;取一位置
		MOV	DX,AX
		MOV	AH,2			;光标定位
		INT	10H
		MOV	AH,8			;取光标处字符
		INT	10H
		STOSB				;写入暂存区
		INC	CX
		CMP	SI,A_BUF		;到定位区尾?
		JNZ	AF9_B

		TEST	WORD PTR [DI-2],8080H	;判末字?
		JNZ	AF9_C
AF9_ERR:
		MOV	AX,0E07H
		INT	10H
		RET
AF9_C:
		MOV	SI,30H			;词组暂存区
		MOV	DX,CX
		CMP	CL,6			;二或三字?		10.16
		JBE	AF9_D
		MOV	CL,6			;取前三字
AF9_D:
		LODSB				;取前三字
		CMP	AL,0A0H 		;判汉字?
		JBE	AF9_ERR
		LOOP	AF9_D
		MOV	CX,DX

		MOV	ES,D_SPCZ		;双拼词组段
		MOV	AX,ES:[6]		;原词组扩展区尾
		MOV	DI,AX
		MOV	SI,30H
		ADD	AX,CX			;+长度
		INC	AX			;+逗号
		CMP	AX,ES:[8]		;比双拼词组区尾?
		JA	AF9_ERR
		MOV	ES:[6],AX
		REP	MOVSB			;写入新词
		MOV	AL,','
		STOSB
		XOR	AX,AX
		STOSW				;结束标志
		RET
CF1_0:
		XOR	BH,BH
		MOV	AH,3			;取光标位置
		INT	10H
		MOV	D_DX0,DX
		MOV	A_BUF,OFFSET D_BUF
CF1_1:
		MOV	AX,1408H		;DX处字符变色
		INT	10H
		MOV	SI,A_BUF
		MOV	[SI],DX 		;存
		ADD	SI,2
		INC	DX
		CMP	SI,OFFSET D_BUF+510
		JZ	CF1_2
		MOV	A_BUF,SI
CF1_2:
		MOV	AH,2			;光标定位
		INT	10H
		CALL	S_INT16 		;键入
		CMP	AH,48H			;↑
		JNZ	CF1_3
		OR	DH,DH
		JZ	CF1_2
		DEC	DH
		JMP	SHORT CF1_2
CF1_3:
		CMP	AH,50H			;↓
		JNZ	CF1_3A
		CMP	DH,24
		JAE	CF1_2
		INC	DH
		JMP	SHORT CF1_2
CF1_3A:
		CMP	AH,4BH			;←
		JNZ	CF1_3B
		OR	DL,DL
		JZ	CF1_2
		DEC	DL
		JMP	SHORT CF1_2
CF1_3B:
		CMP	AH,4DH			;→
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
S_CF1_5:					;恢复
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
		MOV	AH,2			;恢复原光标
		INT	10H
		RET
CF1_6:
		CMP	AL,8			;退格?
		JNZ	CF1_7
		MOV	SI,A_BUF
		CMP	SI,OFFSET D_BUF 	;到区首?
		JZ	CF1_6A
		MOV	DX,[SI-2]
		MOV	AX,1408H
		INT	10H
		SUB	A_BUF,2
CF1_6A:
		JMP	CF1_2
CF1_7:
		CMP	AL,0DH			;回车?
		JNZ	CF1_6A
		CALL	S_CF1_5 		;恢复
		CMP	D_AF9,0
		JZ	CF1_8
		JMP	AF9_A
CF1_8:
		MOV	SI,OFFSET D_BUF 	;
CF1_A:
		CMP	SI,A_BUF		;判结束?
		JZ	CF1_B
		LODSW				;取
		MOV	DX,AX
		MOV	AH,2			;光标定位
		INT	10H
		MOV	AH,8			;取光标处字符
		INT	10H
		XOR	AH,AH
		MOV	[SI-2],AX		;写入词组区
		JMP	SHORT CF1_A
CF1_B:
		RET

D_DYCS		DB	'打印参数',0
D_DYCS1 	DB	' 1-字型 2-行距 3-左空 4-单向 '
		DB	'5-双向 6-特打关 7-开 8-西文打印 9-汉字',0
D_C101		DB	'请键入字型(A-x):',0
D_C102		DB	'请键入行距(1-255):',0
D_C103		DB	'请键入左边空列(0-2000):',0
D_INPUT 	DB	'`',7 DUP(0)
;【设置打印参数】
L_CF10:
		MOV	AH,6			;取打印参数
		INT	17H
		CMP	AH,6			;判有驱动模块?
		JNZ	L_C100
		JMP	L_9DC0
L_C100:
		MOV	SI,OFFSET D_DYCS
		CALL	S_QTXS			;清提示行并显示
		MOV	SI,OFFSET D_DYCS1
		MOV	BL,1EH
		CALL	S_A24A			;显示菜单
		CALL	S_INT16 		;选择
		PUSH	AX
		CALL	S_1400
		POP	AX
		MOV	BL,1EH
		MOV	DI,OFFSET D_INPUT+1	;键入缓冲区

		CMP	AL,'1'                  ;字型
		JNZ	L_C102
		MOV	SI,OFFSET D_C101
		CALL	S_A24A			;显示提示信息
		MOV	BYTE PTR [DI],'@'
		CALL	S_INT16 		;键入
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
		CALL	S_1403			;响铃
		JMP	SHORT L_CF10
L_C102:
		CMP	AL,'2'                  ;行距
		JNZ	L_C103
		MOV	SI,OFFSET D_C102
		CALL	S_A24A			;显示提示信息
		MOV	BYTE PTR [DI],'&'
		CALL	S_INPUT 		;键入数
		JB	L_C10ERR
		JMP	SHORT L_C101
L_C103:
		CMP	AL,'3'                  ;左边空
		JNZ	L_C104
		MOV	SI,OFFSET D_C103
		CALL	S_A24A
		MOV	BYTE PTR [DI],'['
		CALL	S_INPUT 		;键入数
		JB	L_C10ERR
		JMP	SHORT L_C101
L_C104:
		CMP	AL,'4'                  ;单向打印
		JNZ	L_C105
		MOV	AL,'>'
L_C104A:
		MOV	[DI],AL
		MOV	WORD PTR [DI+1],60H
		JMP	SHORT L_C101
L_C105:
		CMP	AL,'5'                  ;双向打印
		JNZ	L_C106
		MOV	AL,'<'
		JMP	SHORT L_C104A
L_C106:
		CMP	AL,'6'                  ;特殊打印关
		JNZ	L_C107
L_C106A:
		SUB	AL,'6'
		MOV	AH,4			;设置
		INT	17H
		JMP	S_1404
L_C107:
		CMP	AL,'7'                  ;特殊打印开
		JZ	L_C106A

		CMP	AL,'8'                  ;西文打印
		JNZ	L_C109
L_C108:
		SUB	AL,'8'
		MOV	AH,3			;设置
		INT	17H
		JMP	S_1404
L_C109:
		CMP	AL,'9'                  ;汉字打印
		JZ	L_C108
		JMP	S_1404

;子程序:键入数字
S_INPUT 	PROC	NEAR
		INC	DI			;键入缓冲区
L_IN1:
		CALL	S_INT16 		;键入
		CMP	AL,0DH			;回车?
		JZ	L_IN6
		CMP	AL,8			;退格?
		JNZ	L_IN5
		CMP	DI,OFFSET D_INPUT+2	;指针在区首?
		JBE	L_IN1
		DEC	DI			;位置-1
L_IN4:
		CALL	S_1403A 		;退格
		JMP	SHORT L_IN1
L_IN5:
		CMP	AL,'0'                  ;判数字?
		JB	L_IN1
		CMP	AL,'9'
		JA	L_IN1
		MOV	[DI],AL 		;写入
		INC	DI
		JMP	SHORT L_IN4
L_IN6:
		CMP	DI,OFFSET D_INPUT+2	;指针在区首?
		JZ	L_IN9
		MOV	BYTE PTR [DI],0
		MOV	SI,OFFSET D_INPUT
		CLC
		RET
L_IN9:
		STC
		RET
S_INPUT 	ENDP

;【预选字表】
L_YX:
		MOV	AX,D_YX 		;预选字表首址
		OR	AX,AX
		JZ	L_YX3
		MOV	D_2BB9,40H		;预选标志
L_YX1:
		CALL	S_1400			;清提示行
		MOV	BL,D_TUX1		;颜色:蓝底黄字
		MOV	DL,' '
		CALL	S_1403
		MOV	SI,D_YX 		;预选字表当前行地址
		MOV	DL,'A'                  ;序号
L_YX2:
		PUSH	DX
		CALL	S_1403			;显示序号
		LODSB				;前字节
		CALL	S_1403A
		LODSB				;后字节
		CALL	S_1403A
		POP	DX
		INC	DX			;序号加一
		CMP	DL,'Z'
		JBE	L_YX2			;未完
		CALL	S_A24E			;清光标
L_YX3:
		RET

D_HELP		DW	0,0			;帮助模块地址
;【帮助】
L_HELP:
		CMP	D_HELP+2,0		;判已挂接帮助模块?
		JZ	L_HELP1
		CALL	DWORD PTR D_HELP	;执行帮助程序
L_HELP1:
		RET

D_CZW		DB	' '                     ;纯中文显示标志
;【建立/取消纯中文】
L_CF9:
		MOV	AL,7FH
		XOR	D_2BAC,0FFH		;纯中文方式
		JNZ	L_CF9_1
		MOV	AL,' '
L_CF9_1:
		MOV	D_CZW,AL		;存标志

;子程序:重显提示行
S_CXTUX:
		MOV	AL,D_963A
		MOV	SI,OFFSET D_QWXS	;区位
		TEST	AL,1
		JNZ	L_CT1
		MOV	SI,OFFSET D_SWXS	;首尾
		TEST	AL,2
		JNZ	L_CT1
		MOV	SI,OFFSET D_PYXS	;拼音
		TEST	AL,4
		JNZ	L_CT1
		MOV	SI,OFFSET D_SPXS	;双拼
		TEST	AL,8
		JNZ	L_CT1
		MOV	SI,OFFSET D_WBZX	;五笔
		TEST	AL,20H
		JNZ	L_CT1
		MOV	SI,OFFSET D_DBXS	;电报
		TEST	AL,80H
		JNZ	L_CT1
		MOV	SI,OFFSET D_YWXS	;英文
L_CT1:
		CALL	S_QTXSC 		;清提示行并显示输入方式及纯中文标志
		MOV	SI,OFFSET D_213L	;提示行版权标志
		MOV	BL,D_TUX1
		MOV	DL,10
		CALL	S_A249			;显示字符串
		RET

;----------------------------------------------------------------------------
D_XTK1		DB	'转第二页  光标开关  执行特显  简繁切换  '
		DB	'退出汉字  仿长城键  联想开关  直接写屏',0
;【系统控制-第一页】
L_XTK1:
		MOV	SI,OFFSET D_XTK1	;第一页菜单
		MOV	CX,800H
		CALL	S_CDKZ			;提示行菜单控制
		CMP	AL,1BH			;<ESC>
		JNZ	L_XTK1A
		RET

K_GBKG		DB	0FFH			;光标开关
L_XTK1A:
		CMP	AL,2			;<光标开关>
		JNZ	L_XTK1B
		NOT	K_GBKG
		MOV	AH,17H
		MOV	AL,K_GBKG
		INT	10H
		RET

D_TXZF		DB	'特显字符串:',0
L_XTK1B:
		CMP	AL,3			;<执行特显>
		JNZ	L_XTK1C
		PUSH	CS
		POP	ES
		MOV	SI,OFFSET D_TXZF
		CALL	S_QTXS			;清提示行并显示
		MOV	DI,030H 		;借CS:30H区为字符存放区
		MOV	SI,DI			;保存
		MOV	AL,14			;引导符
		STOSB
L_XTK1B1:
		CALL	S_INT16 		;取键入字符
		CMP	AL,8			;退格?
		JNZ	L_XTK1B3
		CMP	SI,DI
		JZ	L_XTK1B1
		DEC	DI
L_XTK1B2:
		MOV	BL,D_TUX1		;颜色:蓝底黄字
		CALL	S_1403A 		;显示退格
		JMP	SHORT L_XTK1B1
L_XTK1B3:
		CMP	AL,1BH			;<ESC>?
		JZ	L_XTK1B6
		CMP	AL,0DH			;回车?
		JZ	L_XTK1B4
		STOSB				;存放
		JMP	SHORT L_XTK1B2
L_XTK1B4:
		MOV	AL,']'                  ;结束符
		STOSB
L_XTK1B5:
		CMP	SI,DI			;输出完?
		JZ	L_XTK1B6
		LODSB				;取一字符
		MOV	CX,1
		MOV	AH,9
		INT	10H			;输出
		JMP	SHORT L_XTK1B5
L_XTK1B6:
		JMP	S_1404			;关闭提示行

D_JF		DB	18			;简繁标志
L_XTK1C:
		CMP	AL,4			;<简繁切换>
K_JFQH	EQU	$
		JNZ	L_XTK1D
		MOV	AL,18
		CMP	AL,D_JF
		JNZ	L_XTK1C1
		DEC	AX
L_XTK1C1:
		MOV	D_JF,AL
		MOV	AH,18H			;AL=17繁体,=18简体
		INT	10H
		MOV	AX,1813H		;重显屏幕
		INT	10H
		RET

D_QR		DB	'请再次确认(Y/N)',7,0
L_XTK1D:
		CMP	AL,5			;<退出汉字>
K_TCHZ	EQU	$
		JNZ	L_XTK1E
		MOV	SI,OFFSET D_QR
		CALL	S_QTXS			;显示提示信息
		CALL	S_INT16 		;键入
		AND	AL,5FH
		CMP	AL,'Y'                  ;判?
		JZ	L_XTK1D1
		JMP	S_CXTUX 		;重显提示行
L_XTK1D1:
		MOV	CS:D_EXIT,2
		RET

D_FCCJ		DB	'仿长城键',0, '标准键盘',0
D_JHJB		DB	68H, 69H, 6AH, 6BH, 66H, 6DH	;仿长城交换键表
	;		A-F1 A-F2 A-F3 A-F4 C-F9 A-F6	;仿长城时与[0D2H]交换
L_XTK1E:
		CMP	AL,6			;<仿长城键>
		JNZ	L_XTK1F
		MOV	DI,OFFSET K_AF1 	;键位表
		MOV	CX,6			;修改六个键
		MOV	BX,OFFSET D_JHJB	;仿长城交换键表
		MOV	SI,OFFSET D_FCCJ	;显示内容
		MOV	AL,'Y'
		CMP	K_FCC,AL		;仿长城键?
		JNZ	L_XTK1E1
		MOV	AL,'N'
		ADD	SI,9
L_XTK1E1:
		MOV	K_FCC,AL		;变换
L_XTK1E2:
		MOV	AL,[BX]
		XCHG	AL,[DI] 		;交换
		MOV	[BX],AL
		INC	BX
		INC	DI
		LOOP	L_XTK1E2
		JMP	S_QTXS			;显示

L_XTK1F:
		CMP	AL,7			;<联想开关>
		JNZ	L_XTK1G
		NOT	D_9639			;联想标志
		CMP	D_9639,0
		JZ	L_XTK1F1
		MOV	SI,OFFSET D_9A60
		JMP	S_QTXS			;显示联想状态
L_XTK1F1:
		RET

L_XTK1G:
		CMP	AL,8			;<直接写屏>
K_ZJXP	EQU	$
		JNZ	L_XTK1H
		MOV	AL,11			;设置直接写屏
		CMP	BYTE PTR CS:[102H],0	;判当前直接写屏?	9.11
		JZ	L_AH18
		MOV	AL,10			;取消直接写屏
L_AH18:
		MOV	AH,18H			;设置
		INT	10H
		RET
L_XTK1H:
		JMP	SHORT L_XTK2

;----------------------------------------------------------------------------
D_XTK2		DB	'转第一页  打印字符  对外显示  重显屏幕  '
		DB	'拼音词组  字典方式  重码提示  保持提示',0
D_DK		DB	'打开',0
D_GB		DB	'关闭',0
D_DYZF		DB	'打印字符串:',0
;【系统控制-第二页】
L_XTK2:
		MOV	SI,OFFSET D_XTK2	;第二页菜单
		MOV	CX,800H
		CALL	S_CDKZ			;提示行菜单控制
		CMP	AL,1BH			;<ESC>
		JNZ	L_XTK2A
		RET

L_XTK2A:
		CMP	AL,2			;<打印字符>
		JNZ	L_XTK2B
		PUSH	CS
		POP	ES
		MOV	SI,OFFSET D_DYZF
		CALL	S_QTXS			;清提示行并显示
		MOV	DI,030H 		;借CS:30H区为字符存放区
		MOV	SI,DI			;保存
L_XTK2A1:
		CALL	S_INT16 		;取键入字符
		CMP	AL,8			;退格?
		JNZ	L_XTK2A3
		CMP	SI,DI
		JZ	L_XTK2A1
		DEC	DI
L_XTK2A2:
		MOV	BL,D_TUX1		;颜色:蓝底黄字
		CALL	S_1403A 		;显示退格
		JMP	SHORT L_XTK2A1
L_XTK2A3:
		CMP	AL,0AH			;CTRL+回车?
		JZ	L_XTK2A5
		CMP	AL,0DH			;回车?
		JZ	L_XTK2A4
		STOSB				;存放
		JMP	SHORT L_XTK2A2
L_XTK2A4:
		MOV	AX,0A0DH		;回车换行
		STOSW				;存放
L_XTK2A5:
		CMP	SI,DI			;打印完?
		JZ	L_XTK2A6
		LODSB				;取一字符
		XOR	DX,DX
		XOR	AH,AH
		INT	17H			;打印
		JMP	SHORT L_XTK2A5
L_XTK2A6:
		JMP	S_1404			;关闭提示行

L_XTK2B:
		CMP	AL,3			;<对外显示>
		JNZ	L_XTK2C
		XOR	AX,AX
		MOV	DS,AX
		MOV	BH,3			;字符
		CMP	BYTE PTR DS:[449H],3	;对外显示字符?
		PUSH	CS
		POP	DS
		JA	L_XTK2B1
		MOV	BH,DS:[100H]		;图形(汉字显示方式)
L_XTK2B1:
		MOV	AX,1407H		;设置
		INT	10H
		JMP	S_CXTUX 		;重显提示行

L_XTK2C:
		CMP	AL,4			;<重显屏幕>
		JNZ	L_XTK2D
K_CXPM	EQU	$
		MOV	AX,1813H
		INT	10H
		RET

L_XTK2D:
		CMP	AL,5			;<拼音词组>
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
		CMP	AL,6			;<字典方式>
		JNZ	L_XTK2F
		MOV	SI,OFFSET D_GB
		XOR	D_963B,0FFH
		JZ	L_XTK2E1
		MOV	SI,OFFSET D_DK
L_XTK2E1:
		JMP	S_QTXS

L_XTK2F:
		CMP	AL,7			;<重码提示>
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
		CMP	AL,8			;<保持提示行>
		JNZ	L_XTK2H
		XOR	BYTE PTR DS:[0F4H],2
		JZ	L_XTK2G1
		JMP	S_CXTUX
L_XTK2G1:
		JMP	L_1404
L_XTK2H:
		CMP	AL,48H			;↑
		JNZ	L_XTK2I
		JMP	L_XTK1
L_XTK2I:
		JMP	L_XTK2

;----------------------------------------------------------------------------
D_QWXS		DB	'区位',0
D_SWXS		DB	'首尾',0
D_PYXS		DB	'拼音',0
D_PYTS		DB	' V-zh I-ch U-sh L-ai J-an H-ang K-ao'
		DB	' F-en G-eng Y-ing S-ong V-',81H,0
D_SPXS		DB	'双拼',0
D_SPTS		DB	' Q-iu W-ua.ve R-ia T-ie D-ei P-ou'
		DB	' Z-uan X-i.uang C-un B-ian N-in M-iao',0
D_WBZX		DB	'五笔',0
D_CZXS		DB	'词组',0
D_DBXS		DB	'电报',0
D_YWXS		DB	'英文',0
;【区位】
L_QW:
		MOV	SI,OFFSET D_QWXS	;区位
		MOV	AL,1
		JMP	SHORT L_PY1
;【首尾】
L_SW:
		CMP	D_SW,0			;判有无首尾码表?	5.31
		JZ	L_ERROR
		MOV	AX,D_SW
		MOV	D_2BD6,AX
		MOV	AX,D_SW+2
		MOV	D_2BD8,AX
		MOV	SI,OFFSET D_SWXS	;首尾
		MOV	AL,2
		JMP	SHORT L_PY1
;【拼音】
L_PY:
		CMP	D_PY,0			;判有无拼音码表?
		JZ	L_ERROR
		MOV	AX,D_PY
		MOV	D_2BD6,AX
		MOV	AX,D_PY+2
		MOV	D_2BD8,AX
		MOV	AL,4
		MOV	SI,OFFSET D_PYXS	;拼音
		CALL	L_PY1
		MOV	SI,OFFSET D_PYTS
		JMP	SHORT L_SP1
;【双拼】
L_SP:
		CMP	D_PY,0			;判有无拼音码表?
		JZ	L_ERROR
		MOV	AX,D_PY
		MOV	D_2BD6,AX
		MOV	AX,D_PY+2
		MOV	D_2BD8,AX
		MOV	AL,8
		MOV	SI,OFFSET D_SPXS	;双拼
		CALL	L_PY1
		MOV	SI,OFFSET D_SPTS
L_SP1:
		MOV	BL,D_TUX2		;颜色:
		JMP	S_A24C
L_ERROR:
		JMP	L_9DC0
;【电报】
L_DB:
		CMP	D_DB,0			;判有无电报码表?
		JZ	L_ERROR
		MOV	SI,OFFSET D_DBXS
		MOV	AL,80H
L_PY1:
		MOV	D_963A,AL
		MOV	D_2BB9,0		;清标志
		MOV	D_2BB0,0		;清键入字符计数
		MOV	D_959B,0FFH		;置汉字输入完成态
S_QTXSC:
		CALL	S_QTXS			;清提示行并显示
		PUSH	AX
		MOV	DL,D_CZW
		CALL	S_1403
		POP	AX
L_PY9:
		RET
;【五笔】
L_WBZX:
		CMP	D_INTWB+2,0		;判五笔模块安装?
		JZ	L_PY9
		MOV	SI,OFFSET D_WBZX
		MOV	AL,20H
		MOV	D_2BD2,0
		JMP	SHORT L_PY1
;【英文】
L_ASC:
		MOV	D_963A,AL		;=0
		MOV	D_2BB9,AL		;清标志
		MOV	D_959B,0FFH		;置汉字输入完成态
		JMP	S_1404

D_A210		DB	60H,'、', 2EH,'。', 27H,'“', 22H,'”'
		DB	5BH,'《', 5DH,'》', 5CH,'．', 7CH,'…'
		DB	7BH,'‘', 7DH,'’'
;【纯中文方式处理】
L_9BA6:
		CMP	D_2BAC,0FFH		;纯中文方式?
		JZ	L_9BB0
L_9BB9:
		MOV	D_95D5,1		;返回一个字符
		RET
L_9BB0:
		MOV	DI,OFFSET D_959D
L_9BB1:
		INC	D_95D5			;返回码区计数=1
L_A1E0:
		CMP	AL,7FH
		JAE	L_A1E5
		CMP	AL,' '                  ;纯中文处理
		JNB	L_A1E7
L_A1E5:
		MOV	[DI],AL 		;一字节写入返回码区
		RET
L_A1E7:
		JA	L_A1F2
		MOV	AH,AL
L_A1EB:
		MOV	[DI],AX
		INC	D_95D5
		RET
L_A1F2:
		MOV	SI,OFFSET D_A210	;纯中文转换码表
		MOV	BL,AL
		MOV	CX,10
L_A1FA:
		LODSB				;取表项
		CMP	AL,BL			;是否该键
		JNZ	L_A202
		LODSW				;取转换码
		JMP	SHORT L_A1EB
L_A202:
		LODSW				;指针后移
		LOOP	L_A1FA
		MOV	AH,BL
		MOV	AL,0A3H 		;三区
		OR	AH,80H			;置纯中文
		JMP	SHORT L_A1EB

;【字符处理入口】
L_9C86:
		TEST	D_2BB9,40H		;预选标志
		JZ	L_9C90
		JMP	L_A4F0			;→预选处理
L_9C90:
		CMP	D_959B,0FFH		;完成态?
		JNZ	L_9C9A
		JMP	L_9E68			;→首键处理
L_9C9A:
		TEST	BYTE PTR D_2BB9,10H	;有词组重码?
		JZ	L_9CA5
		JMP	L_A798
L_9CA5:
		MOV	BX,OFFSET D_963A	;输入方式
		TEST	BYTE PTR [BX],1 	;区位?
		JZ	L_9CA6
		JMP	L_QWCL
L_9CA6:
		TEST	BYTE PTR [BX],20H	;五笔?
		JZ	L_9CA8
		JMP	L_WBCL
L_9CA8:
		CMP	AL,';'                  ;转外部词组?
		JNZ	L_9CB3
L_9CA9:
		JMP	L_A5D7
L_9CB3:
		TEST	BYTE PTR [BX],80H	;电报?
		JZ	L_9CC0
		JMP	L_DBCL
L_9CC0:
		TEST	BYTE PTR [BX],2 	;首尾?
		JZ	L_9CC7
		CMP	AL,0DH			;回车?
		JNZ	L_9CF2
		JMP	L_SW			;重入首尾
L_9CC7:
		TEST	BYTE PTR [BX],4 	;拼音?
		JNZ	L_9CEB
		CMP	AL,0DH			;双拼回车?
		JNZ	L_9CF2
		JMP	L_SP			;重入双拼
L_9CEB:
		CMP	AL,0DH			;回车?
		JNZ	L_9CF2
		JMP	L_PY			;重入拼音
L_9CF2:
		CMP	AL,8			;退格?
		JNZ	L_9CF8
		CMP	D_2BB0,0
		JZ	L_9D48
		CALL	S_9D7D			;定位
		CALL	S_1403K
		DEC	D_2BB0			;键入字符计数减一
		JNZ	L_9D4B
		MOV	AL,0DH
		JMP	SHORT L_9CC0
L_9D48:
		JMP	L_9DC5
L_9D4B:
		CALL	S_9FC0			;从码表首为查重码设置指针
		JMP	L_9FA0
L_9CF8:
		CMP	AL,' '
		JNZ	L_9CFE
		MOV	AL,0			;空格=0
		JMP	SHORT L_9D0C
L_9CFE:
		CMP	AL,'9'
		JA	L_9D51
		CMP	AL,'0'
		JB	L_9D51
		JNZ	L_9D0A
		MOV	AL,3AH
L_9D0A:
		AND	AL,0FH			;选中
L_9D0C:
		CMP	AL,D_2BD2
		JA	L_9D27
		CBW
		SHL	AX,1
		ADD	AX,OFFSET D_2BBA
		MOV	BX,AX
		MOV	AX,[BX]
		MOV	WORD PTR D_959D,AX
		JMP	L_A559			;转联想
L_9D27:
		JMP	L_9DC0			;响铃并退出
L_9D49:
		JMP	L_9DAE
L_9D51:
		CMP	AL,"'"                  ;拼音隔音符             2.3
		JZ	L_9D55
		CMP	AL,'['                  ;往前翻页
		JZ	L_9D8B
		CMP	AL,']'                  ;往后翻页
		JZ	L_9D49
L_9D54:
		CMP	AL,'`'                  ;判小写字母及`
		JB	L_9D7A
		CMP	AL,'z'
		JA	L_9D7A
L_9D55:
		TEST	D_963A,8		;判双拼?
		JZ	L_9D58
		CMP	D_2BB0,4		;已4键?
		JB	L_9D58
		MOV	D_959B,0FFH		;置完成态
		JMP	L_9F08			;双拼首键
L_9D58:
		CMP	D_2BB0,8
		JAE	L_9DC0
		INC	D_2BB0			;键入字符计数加一
		CALL	S_9D7D			;定位
		CALL	S_9F89			;写入键入码区并显示
		CALL	S_9FD0			;为正向查重码设置指针
L_9FA0:
		MOV	AX,D_2BD6		;码表首
		MOV	D_2BAD,AX
		MOV	D_2BD0,11
		AND	D_2BB9,0F5H		;清二键高频和双拼词组位
		CALL	S_A017			;向>查码表
		CALL	S_9FD9			;为正向下次查重码设置指针
		CMP	D_2CC0,0FFH		;判拼音简码?
		JZ	L_9D60
		CMP	D_2BB0,2
		JNZ	L_9D70
L_9D60:
		MOV	AX,D_2BD6
		MOV	D_2BAF,AX		;向后查从首开始
L_9D70:
		TEST	D_2BB9,8		;判双拼词组?
		JNZ	L_9DC6
		CALL	S_A164			;显示重码字
		JMP	SHORT L_9DC5
L_9D7A:
		OR	AL,AL
		JNZ	L_9DC0
		JMP	L_9BB9			;纯中文处理
;【响铃】
L_9DC0:
		MOV	DL,7
		CALL	S_1403
L_9DC5:
		MOV	D_95D5,0		;退出
L_9DC6:
		RET
;【前页】
L_9D8B:
		OR	D_2BB9,2		;二键高频
		CALL	S_A001			;为反向查重码设置指针
		CALL	S_A011			;向<查码表
		CALL	S_9FED			;为反向下次查重码设置指针
		CMP	D_2BD0,11
		JZ	L_9D97
		MOV	D_2BD0,11
L_9D97:
		CALL	S_A164			;显示重码字
		JMP	SHORT L_9DC5
;【后页】
L_9DAE:
		OR	D_2BB9,2		;二键高频
		CALL	S_9FD0			;为正向查重码设置指针
		CALL	S_A017			;向>查码表
		CALL	S_9FD9			;为正向下次查重码设置指针
		CMP	D_9597,0
		JNZ	L_9DAF
		MOV	AL,D_2BCF		;取末页重码数
		MOV	D_2BD0,AL		;置最大重码数
		JMP	SHORT L_9D97
L_9DAF:
		MOV	AL,D_2BD2
		OR	AL,AL
		JZ	L_9D97
		CMP	AL,11
		JZ	L_9D97
		MOV	D_2BCF,AL		;存末页重码数
		JMP	SHORT L_9D97
;【五笔处理】
L_WBCL:
		CMP	AL,8			;<退格>
		JNZ	L_WB10
		MOV	BL,D_2BB0
		OR	BL,BL			;判有键?
		JZ	L_WB2
		XOR	BH,BH
		CMP	D_2BB0[BX],' '          ;判不满4键的Z功能?
		JNZ	L_WB0
		DEC	D_2BB0
L_WB0:
		MOV	D_2BD2,0
		CALL	S_9D7D			;键入码区定位
		CALL	S_1403K 		;清空
		DEC	D_2BB0			;键入码计数-1
		JNZ	L_WB2
L_WB1:
		MOV	D_959B,0FFH
L_WB2:
		RET
L_WB10:
		CMP	AL,0DH			;<回车>
		JNZ	L_WB18
		JMP	L_WBZX
L_WB18:
		CMP	AL,' '                  ;<空格>
		JNZ	L_WB20
		CMP	D_2BD2,0		;已有重码?
		JZ	L_WB19
		MOV	AX,0FFH 		;翻页
		JMP	L_WB61
L_WB19:
		INC	D_2BB0
		CALL	S_9F89			;写入键入码区并显示
		JMP	L_WB60
L_WB20:
		MOV	CL,D_9650		;词汇重码数
		OR	CL,CL
		JZ	L_WB30
L_WB21:
		XOR	CH,CH
		MOV	D_9650,CH		;清
		XOR	BP,BP
		OR	CL,'0'
		CMP	AL,CL
		JA	L_WB22
		CMP	AL,'1'
		JAE	L_WB24
L_WB22:
		MOV	BP,AX			;BP=0:已选择
		MOV	AL,1			;无选择,默认第一个
L_WB24:
		AND	AL,0FH
		MOV	CL,AL
		DEC	CX
		MOV	SI,OFFSET D_BUF 	;重码区(借用)
L_WB24B:
		OR	CX,CX
		JZ	L_WB26
L_WB25:
		LODSW				;查找第CL个词
		TEST	AX,8080H
		JNZ	L_WB25
		LOOP	L_WB25
L_WB26:
		MOV	DI,OFFSET D_959D	;返回码区
		XOR	CX,CX
L_WB27:
		LODSW				;取一字
		MOV	[DI],AX
		ADD	DI,2
		INC	CX
		INC	CX
		TEST	AX,8080H		;判词结束
		JNZ	L_WB27
		OR	BYTE PTR [DI-4],80H	;高位置1
		OR	BYTE PTR [DI-2],80H	;高位置1
		MOV	D_95D5,CL		;返回字节数
		MOV	D_2BD2,0
		OR	BP,BP			;=0:已选择
		JNZ	L_WB29
		JMP	L_WB1
L_WB29:
		MOV	AX,BP
		JMP	L_WB35			;非数字处理
L_WB30:
		MOV	CL,D_2BD2
		OR	CL,CL			;字重码数
		JZ	L_WB51
		MOV	D_95D5,2		;返回字节数
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
		MOV	AX,D_2BBA[BX]		;选中
		JMP	L_WB98
L_WB34:
		MOV	DI,OFFSET D_959D
		MOV	CX,D_2BBC		;首字
		MOV	[DI],CX 		;返回
		ADD	DI,2
L_WB35:
		CMP	AL,'a'                  ;判小写字母?
		JB	L_WB36
		CMP	AL,'z'
		JA	L_WB36
L_WB35A:
		MOV	D_959B,0
		MOV	D_2BB0,1
		MOV	SI,OFFSET D_WBZX
		CALL	S_QTXSC 		;清提示行并显示        2.13
		JMP	S_9F89			;写入键入码区并显示
L_WB36:
		MOV	D_959B,0FFH
		CMP	D_2BAC,0FFH		;判纯中文方式?
		JNZ	L_WB38
		JMP	L_9BB1			;纯中文处理
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
		INC	D_2BB0			;键+1
		CALL	S_9F89			;写入键入码区并显示
		CMP	D_2BB0,4		;满4键?
		JZ	L_WB60
		RET
;查WBZX
L_WB60:
		XOR	AX,AX
L_WB61:
		MOV	SI,OFFSET D_BUF 	;借用:返回区
		MOV	BX,OFFSET D_2BB1	;键入码区
		MOV	CX,1EH
		PUSHF
		CALL	DWORD PTR D_INTWB	;调WBZX模块
L_WB63:
		PUSH	CS
		POP	ES

		TEST	DL,80H			;判有无字词?
		JNZ	L_WB70
L_WB64:
		CALL	S_BEEP			;响铃
		RET				;2.13
L_WB70:
		TEST	DL,1			;词汇?
		JNZ	L_WB70A
		JMP	L_WB80
L_WB70A:
		TEST	DL,4			;有重码?
		JZ	L_WB76
L_WB71:
		MOV	D_9650,CL
		XOR	CH,CH
		PUSH	CX
		MOV	DL,10H
		CALL	S_9F30			;定位清提示行
		POP	CX
		MOV	DI,16
		MOV	DL,'1'
L_WB72:
		PUSH	DX
		MOV	BL,D_TUX1
		CALL	S_1403			;显示序号
		INC	DI
L_WB73:
		LODSW				;取一字
		MOV	BL,D_TUX2
		PUSH	AX
		OR	AX,8080H
		PUSH	AX
		CALL	S_1403A 		;显示前字节
		INC	DI
		POP	AX
		MOV	AL,AH
		CALL	S_1403A 		;显示后字节
		INC	DI
		POP	AX
		CMP	DI,78			;判提示行满?
		JBE	L_WB74
		POP	DX
		RET
L_WB74:
		TEST	AX,8080H		;判词尾?
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
		TEST	AX,8080H		;找词尾
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
		OR	AX,8080H		;高位置1
		MOV	[DI],AX
L_WB79:
		MOV	D_95D5,CL		;返回字节数
		JMP	L_WB1
L_WB80:
		TEST	DL,2			;Z功能?
		JZ	L_WB90
		MOV	DL,10H
		CALL	S_9F30			;定位清提示行
		MOV	DI,OFFSET D_2BBC	;字重码区
		LODSB				;重码数
L_WB84:
		MOV	CL,AL
		XOR	CH,CH
		MOV	D_2BD2,CL		;存
		MOV	DL,'1'
L_WB88:
		PUSH	DX
		CALL	S_1403			;显示序号
		LODSW				;写入字重码区
		STOSW
		PUSH	AX
		CALL	S_1403A 		;显示前字节
		POP	AX
		MOV	DL,AH
		CALL	S_1403			;显示后字节
		LODSB
		CALL	S_1403A 		;显示五笔码
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
		TEST	DL,4			;重码字?
		JZ	L_WB97
		MOV	DI,OFFSET D_2BBC	;字重码区
		LODSB				;重码数
L_WB92:
		MOV	CL,AL
		XOR	CH,CH
		MOV	D_2BD2,CL		;存
		REP	MOVSW			;传送
		CALL	S_BEEP
L_WB94:
		MOV	DL,10H
		CALL	S_9F30			;定位清提示行
		MOV	DL,'1'
		CALL	S_A180			;显示重码字并响铃
		RET
L_WB97:
		XCHG	AH,AL
L_WB98:
		MOV	WORD PTR D_959D,AX	;返回码
		MOV	D_95D5,2		;返回字节数
		MOV	D_959B,0FFH
		RET
;【电报处理】
L_DBCL:
		CMP	AL,0DH			;回车?
		JNZ	L_DB1
		JMP	L_DB			;重入电报
L_DB1:
		CMP	AL,8			;退格?
		JZ	L_9DE0
		JMP	L_9E2A
;【区位翻页】
L_9C3E:
		CMP	AL,'['                  ;<
		JNZ	L_9C54
		MOV	AX,D_2BBA		;当前行首字
		SUB	AH,11		       ;位号-11
		CMP	AH,0A1H 		;<0
		JNB	L_9C51
		ADD	AH,94		       ;+94
		DEC	AX			;区号-1
		CMP	AL,0A1H
		JNB	L_9C51
		MOV	AX,0A1A1H
L_9C51:
		JMP	L_9E0D			;显示
L_9C54:
		CMP	AL,']'                  ;>
		JNZ	L_9C60
		MOV	AX,D_2BCE		;当前行末字
		INC	AH			;位号+1
		CMP	AH,0FFH
		JNZ	L_9C5C
		MOV	AH,0A1H
		INC	AL
L_9C5C:
		CMP	AL,0FFH
		JNZ	L_9C5E
		MOV	AX,0A1A1H
L_9C5E:
		JMP	L_9E0D			;显示
;【区位选中】
L_9C60:
		CMP	AL,' '
		JNZ	L_9C68
		MOV	AL,'0'                  ;空格=0
		JMP	SHORT L_9C74
L_9C68:
		CMP	AL,'9'                  ;判数字
		JA	L_9C77
		CMP	AL,'0'
		JB	L_9C77
		JNZ	L_9C74
		MOV	AL,3AH
L_9C74:
		JMP	L_9D0A			;选中
L_9C77:
		JMP	L_9BA6			;转判小写字母
;【区位处理】
L_QWCL:
		CMP	AL,0DH			;回车?
		JNZ	L_9DD2
		JMP	L_QW			;重入区位
L_9DD2:
		CMP	D_2BB0,5		;区位+空格?
		JZ	L_9C3E
L_9DDC:
		CMP	AL,8			;退格?
		JNZ	L_9DF7
L_9DE0:
		MOV	DL,8
		CALL	S_1403			;退格
		DEC	D_2BB0			;键入码计数-1
		CMP	D_2BB0,0		;=0?
		JNZ	L_9DF4
		MOV	D_959B,0FFH		;置完成态
L_9DF4:
		JMP	L_9DC5
L_9DF7:
		CMP	AL,' '                  ;区位+空格?
		JNZ	L_9E2A
		MOV	AX,WORD PTR D_2BB1	;取已键入区号
		CMP	D_2BB0,2
		JZ	L_9DF8
		CBW
		XCHG	AH,AL
L_9DF8:
		MOV	D_2BB0,5		;置标志
		XCHG	AL,AH
		AND	AX,0F0FH
		AAD				;区号=AL
		OR	AL,AL
		JZ	L_9DF9
		CMP	AL,94
		JBE	L_9DFA
L_9DF9:
		MOV	AL,1
L_9DFA:
		ADD	AX,0A1A0H		;AX=该区首字
L_9E0D:
		MOV	SI,OFFSET D_2BBA	;重码区首址
		MOV	CX,0BH			;=11
		MOV	D_2BD2,CL
L_9E17:
		CMP	AH,0FFH 		;=95?
		JNZ	L_9E18
		MOV	AH,0A1H 		;置区首
		INC	AX			;区号+1
L_9E18:
		CMP	AL,0FFH
		JNZ	L_9E1A
		MOV	AL,0A1H
L_9E1A:
		PUSH	AX
		MOV	DL,5
		CALL	S_1402			;定位
		POP	AX
		PUSH	AX
		CALL	S_9E50			;显示首字区号
		POP	AX
		PUSH	AX
		MOV	AL,AH
		CALL	S_9E50			;显示首字位号
		POP	AX
L_9E1F:
		MOV	[SI],AX 		;写入重码区
		ADD	SI,2			;指针加2
		INC	AH			;位号+1
		CMP	AH,0FFH 		;区尾(位号=95)
		JNZ	L_9E20
		MOV	AH,0A1H 		;置区首
		INC	AX			;区号+1
		CMP	AL,0FFH
		JNZ	L_9E20
		MOV	AL,0A1H
L_9E20:
		LOOP	L_9E1F
		JMP	L_A172			;显示
L_9E28:
		JMP	L_9BA6			;转纯中文处理
L_9E2A:
		CMP	AL,'0'
		JB	L_9E28
		CMP	AL,'9'
		JA	L_9E28
		INC	D_2BB0
		CALL	S_9F89			;写入键入码区并显示
		CMP	D_2BB0,4		;已四键?
		JNB	L_9E40
		RET
L_9E40:
		MOV	SI,OFFSET D_2BB1
		LODSW				;取前二键
		XCHG	AL,AH
		AND	AX,0F0FH
		AAD
		MOV	BL,AL			;区号
		LODSW				;取后二键
		XCHG	AL,AH
		AND	AX,0F0FH
		AAD
		MOV	BH,AL			;位号
		TEST	D_963A,1		;判区位方式?
		JZ	L_9E48
		OR	BH,BH
		JZ	L_9E47
		CMP	BH,94
		JA	L_9E47
		OR	BL,BL
		JZ	L_9E47
		CMP	BL,94
		JA	L_9E47
		ADD	BX,0A0A0H		;转为内码
L_9E46:
		MOV	WORD PTR D_959D,BX	;存返回码区
		JMP	L_A559			;转联想
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
		ADD	BX,D_DB 		;加电报码表首址
		MOV	BX,[BX] 		;取汉字
		JMP	SHORT L_9E46

;子程序:显示区号或位号
S_9E50:
		SUB	AL,0A0H
S_9E51:
		XOR	AH,AH
		MOV	DH,0AH			;=10
		DIV	DH
		MOV	BL,D_TUX2		;颜色:蓝底白字
		PUSH	AX			;保存个位AH
		OR	AL,30H			;十位
		CALL	S_1403A
		POP	AX
		MOV	DL,AH
		OR	DL,30H			;个位
		JMP	S_1403

;【首键处理】
L_9E68:
		CMP	D_963A,0		;ASCII?
		JNZ	L_9E72
L_9E6F:
		JMP	L_9BA6			;纯中文处理
L_9E72:
		CALL	S_9F62			;判SHIFT+空格?
		JNB	L_9E80
		MOV	AL,D_95D6
		MOV	D_95D5,AL
		RET
L_9E80:
		TEST	D_2BB9,10H		;有词组重码?
		JZ	L_9E86
		JMP	L_A73B			;重选词组
L_9E86:
		CMP	D_2BB0,0
		JZ	L_9EC0
		CMP	AH,82H			;ALT+'-'
		JNB	L_9EAB
		CMP	AH,78H			;ALT+1
		JB	L_9E9E
		MOV	AL,AH
		SUB	AL,77H
		JMP	L_9D0C			;选中
L_9E9E:
		CALL	S_9F66			;判ALT+空格
		JNB	L_9EC0
		JMP	L_9D0C			;选中
L_9EAB:
		JNZ	L_9EB4
		TEST	D_963A,1		;判区位?
		JNZ	L_9E6F
		NOT	D_959B			;ALT+'-'
		JMP	L_9D8B
L_9EB4:
		CMP	AH,83H			;ALT+'+'?
		JNZ	L_9EC0
		TEST	D_963A,1		;判区位?
		JNZ	L_9E6F
		NOT	D_959B
		JMP	L_9DAE
;【区位首键】
L_9EC0:
		TEST	D_963A,1		;区位?
		JZ	L_9F00
		CMP	D_2BB0,5		;区号+空格?
		JNZ	L_9ED0
		JMP	L_QWCL
L_9ED0:
		CMP	AL,'0'                  ;判数字
		JB	L_9EFE
		CMP	AL,'9'
		JA	L_9EFE
		MOV	SI,OFFSET D_QWXS	;'区位'
L_9ED8:
		CALL	S_QTXSC 		;清提示行并显示
		MOV	D_2BB1,AL
		MOV	BL,D_TUX1		;颜色:蓝底白字
		CALL	S_1403A 		;显示
		MOV	D_2BB0,1
L_9EFA:
		AND	D_2BB9,0EFH		;清词组重码位
		MOV	D_959B,0		;置未完成态
		JMP	L_9DC5
L_9EFE:
		JMP	L_9BA6			;转纯中文
;【电报首键】
L_9F00:
		TEST	D_963A,80H		;<电报>
		JZ	L_9F08
		CMP	AL,'0'                  ;判数字
		JB	L_9EFE
		CMP	AL,'9'
		JA	L_9EFE
		MOV	SI,OFFSET D_DBXS	;'电报'
		JMP	SHORT L_9ED8
;【首尾、拼音、双拼、五笔首键】
L_9F08:
		CALL	S_9F61			;判CTRL+空格?		11.14
		JNB	L_9F08A
		MOV	D_2BB0,0		;键入码数=0
		OR	D_2BB9,80H		;置标志
		JMP	L_9DC0
L_9F08A:
		CMP	AL,'a'                  ;判小写字母
		JB	L_9F09
		CMP	AL,'z'
		JBE	L_9F0A
L_9F09:
		AND	D_2BB9,0B0H	       ;		       12.23
		JMP	L_9BA6
L_9F0A:
		MOV	D_959B,0FFH		;置完成态
		MOV	D_2BB0,1		;键入码数=1
		TEST	D_963A,20H		;五笔字型?
		JZ	L_9F10
		MOV	D_2BD2,0
		MOV	SI,OFFSET D_WBZX	;'五笔 '
		CALL	S_QTXSC
		CALL	S_9F89
		JMP	L_9EFA
L_9F10:
		TEST	D_963A,2		;首尾?
		JZ	L_9F12
		MOV	SI,OFFSET D_SWXS	;'首尾 '
		JMP	SHORT L_9F18
L_9F12:
		TEST	D_963A,4		;拼音?
		JZ	L_9F14
		MOV	SI,OFFSET D_PYXS	;'拼音 '
		JMP	SHORT L_9F18
L_9F14:
		MOV	SI,OFFSET D_SPXS	;'双拼 '
L_9F18:
		CALL	S_QTXSC 		;清提示行并显示
		AND	D_2BB9,0F6H		;清一键高频及双拼词组位
		MOV	D_2BB0,1
		CALL	S_9F89			;写入键入码区并显示
		CALL	S_9FC0			;从码表首为查重码设置指针
		CALL	S_A017			;向>查码表
		CALL	S_9FD9			;为正向下次查重码设置指针
		CALL	S_A164			;显示重码字
L_9F20:
		JMP	L_9EFA			;清重码位并置未完成态

;子程序:清提示行并显示
S_QTXS1:
		PUSH	AX
		JMP	SHORT L_QT2
S_QTXS:
		PUSH	AX
		CALL	S_1400			;清提示行
		XOR	DL,DL			;定位左端
		XOR	BH,BH
		MOV	BL,D_QTS1		;颜色:红底黄字(显示方式>3)
		PUSH	DS
		XOR	AX,AX
		MOV	DS,AX
		CMP	BYTE PTR DS:[449H],4
		POP	DS
		JNB	L_QT1
		MOV	BL,D_QTS2		;颜色:红底绿字(显示方式<4)
L_QT1:
		CALL	S_A249			;定位显示
L_QT2:
		MOV	BP,CS
		MOV	SI,OFFSET D_QT
		MOV	BL,4EH
		MOV	DL,4CH
		MOV	AX,140AH
		INT	10H
		POP	AX
		RET

;子程序:定位显示字符串
S_A249:
		CALL	S_1402
;子程序:显示字符串并清光标
S_A24C:
		CALL	S_A24A
S_A24E:
		MOV	DL,82			;8.7
		JMP	S_1402
;子程序:显示字符串
S_A24A:
		LODSB				;取一字符
		OR	AL,AL			;串结束符?
		JZ	L_A24B
		CALL	S_1403A 		;显示
		JMP	SHORT S_A24A
L_A24B:
		RET

D_QT	DB	255,128,128,159,177,129,131,134,140,152,176,177,191,128,128,255
	DB	255,  0,  0,  0,128,128,  0,  0,  0,  0,  0,152,152,  0,  0,255
	DB	255,  0,  0, 48,113,240, 48, 48, 48, 48, 48, 49,252,  0,  0,255
	DB	255,  1,  1,249,141, 13, 13,121, 13, 13, 13,141,249,  1,  1,255

;子程序:菜单控制 字符串SI,项数CH,首项位置CL 返回AL=选中项
S_CDKZ:
		MOV	DI,SI
		CALL	S_1400			;清提示行
		MOV	BL,D_TUX1		;颜色:蓝底黄字
		XOR	DL,DL			;定位
		CALL	S_A249			;显示
		MOV	DH,1			;默认号
L_CD00:
		CALL	S_A251
		CALL	S_INT16 		;键入
		CMP	AL,1BH			;ESC
		JZ	L_CD08
		CMP	AL,0DH			;回车
		JNZ	L_CD10
		CALL	S_1404			;关闭提示行
		MOV	AL,DH			;选中项号
		RET
L_CD08:
		CALL	S_1404			;关闭提示行
		MOV	AL,1BH			;ESC
		RET
L_CD10:
		CMP	AH,4DH			;→
		JNZ	L_CD20
		CALL	S_A250			;清原显示
		CMP	DH,CH			;已到最大号?
		JZ	L_CD11
		INC	DH			;增1
		JMP	SHORT L_CD00
L_CD11:
		MOV	DH,1			;置1
		JMP	SHORT L_CD00
L_CD20:
		CMP	AH,4BH			;←
		JNZ	L_CD30
		CALL	S_A250			;清原显示
		CMP	DH,1			;判=1?
		JZ	L_CD21
		DEC	DH			;减1
		JMP	SHORT L_CD00
L_CD21:
		MOV	DH,CH			;置最大号
		JMP	SHORT L_CD00
L_CD30:
		CMP	AH,48H			;↑
		JZ	L_CD33
		CMP	AH,50H			;↓
		JNZ	L_CD00
L_CD33:
		MOV	AL,AH
		RET

;子程序:定位显示字符串SI
S_A250:
		MOV	BL,D_TUX1		;颜色:蓝底黄字
		JMP	SHORT L_A252
S_A251:
		MOV	BL,D_QTS1		;颜色:红底黄字
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
		CALL	S_1402			;定位
		MOV	CX,8
L_A253:
		LODSB				;取一字符
		CALL	S_1403A 		;显示
		LOOP	L_A253
		CALL	S_A24E			;8.7
		POP	CX
		RET

;子程序:调原INT16取键入字符
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

;子程序:汉字输入码定位
S_9D7D:
		MOV	DL,4
;子程序:键入字符定位
S_9D7F:
		ADD	DL,D_2BB0
		PUSH	AX
		CALL	S_1402			;提示行光标定位
		POP	AX
		RET

;子程序:定位5清提示行
S_9F2E:
		MOV	DL,5
;子程序:定位清提示行
S_9F30:
		CALL	S_1402			;提示行光标定位
;子程序:从指定位置开始清提示行
S_9F35:
		MOV	CX,76
D_9F36	EQU	$-2
		SUB	CL,DL			;从指定位置起字节数
		PUSH	DX
		CALL	S_1401
		POP	DX
;子程序:提示行光标定位
S_1402:
		MOV	AX,1402H
		INT	10H
		RET
S_1401:
		MOV	DL,' '                  ;空格
S_1401A:
		MOV	BL,D_TUX1
		XOR	BH,BH
		MOV	AX,1401H
		INT	10H
		RET
S_1403K:
		PUSH	BX
		MOV	CX,1
		CALL	S_1401			;显示一个空格
		POP	BX
		RET

;子程序:关闭提示行
S_1404:
		MOV	BL,10H
S_14041:
		CMP	BYTE PTR CS:[100H],12H	;判VGA?
		JB	L_1404
		TEST	BYTE PTR CS:[0F4H],2	;保持提示行?
		JZ	L_1404
		JMP	S_CXTUX
L_1404:
		MOV	AX,1404H
D_1404	EQU	$-2				;长城方式改为1400H
		INT	10H
		RET

;子程序:清提示行
S_1400:
		MOV	BL,10H
		MOV	AX,1400H
		INT	10H
		RET

;子程序:显示字符AL
S_1403A:
		MOV	DL,AL
;子程序:显示字符DL
S_1403:
		MOV	AX,1403H
		INT	10H
		RET

;子程序:判CTRL+空格
S_9F61:
		MOV	DL,4			;CTRL
		JMP	SHORT L_9F60
;子程序:判SHIFT+空格
S_9F62:
		MOV	DL,3			;左右SHIFT
		JMP	SHORT L_9F60
;子程序:判ALT+空格
S_9F66:
		MOV	DL,8			;ALT
L_9F60:
		MOV	DI,40H
		MOV	ES,DI
		CMP	AH,39H			;空格的扫描码?
		JNZ	L_9F77
		TEST	ES:[17H],DL		;判转换键?
		JZ	L_9F77
		XOR	AL,AL
		STC				;是
		RET
L_9F77:
		CLC				;否
		RET

;子程序:写入键入码区并显示
S_9F89:
		PUSH	AX
		XOR	BH,BH
		MOV	BL,D_2BB0
		MOV	D_2BB0[BX],AL		;写入键入码区
		MOV	BL,D_TUX1		;颜色:蓝底白字
		CALL	S_1403A 		;显示
		POP	AX
		RET

;子程序:从码表首为查重码设置指针
S_9FC0:
		MOV	AX,D_2BD6
		MOV	D_2BAD,AX
		ADD	AX,2
L_9FCA:
		MOV	D_2BAF,AX
		RET
;子程序:为正向下次查重码设置指针
S_9FD9:
		MOV	AX,D_2BAF
		SUB	AX,2
		MOV	D_9646,AX
		MOV	AX,D_2BAD
		JMP	SHORT L_9FCA
;子程序:为正向查重码设置指针
S_9FD0:
		MOV	AX,D_2BAF
L_9FD4:
		MOV	D_2BAD,AX
		RET
;子程序:为反向查重码设置指针
S_A001:
		MOV	AX,D_9646
		JMP	SHORT L_9FD4
;子程序:为反向下次查重码设置指针
S_9FED:
		MOV	AX,D_9646
		ADD	AX,2
		MOV	D_2BAF,AX
		MOV	AX,D_2BAD
		MOV	D_9646,AX
		RET

D_1J		DW	OFFSET L_A28E		;一键
D_2J		DW	OFFSET L_A300		;二键
D_3J		DW	OFFSET L_A350		;三键
D_4J		DW	OFFSET L_A390		;四键
;子程序:向<查码表
S_A011:
		MOV	DI,D_2BD6
		SUB	DI,2
		STD
		MOV	AL,D_2BD0
		CBW
		DEC	AX
		SHL	AX,1
		ADD	AX,OFFSET D_2BBA
		MOV	D_2BC0,AX		;重码开始写入地址
		JMP	SHORT L_A018
;子程序:向>查码表
S_A017:
		MOV	DI,D_2BD8		;码表尾
		MOV	D_2BC0,OFFSET D_2BBA	;重码开始写入地址
L_A018:
		MOV	SI,D_2BAD		;本次查表初始位置
		AND	D_2BB9,0DFH		;清提示行重码位
		XOR	CX,CX
		MOV	D_2BD2,CL		;清提示行重码数
		MOV	D_9597,CX		;清重码计数器
		MOV	D_2CC0,CL		;清拼音简码标志
		PUSH	CS
		POP	ES
		MOV	BL,D_2BB0
		TEST	D_963A,4		;判拼音?
		JNZ	L_A01B
		CMP	BL,4			;9.27
		JBE	L_A01A
		JMP	L_9DC0
L_A01A:
		XOR	BH,BH
		SHL	BX,1
		JMP	D_1J-2[BX]		;一~四键处理
L_A01B:
		CALL	S_A010			;拼音码预处理
		OR	BP,BP
		JZ	L_A01C
		CMP	BP,1
		JNZ	L_A01BB
		JMP	L_A28F			;一键处理
L_A01BB:
		MOV	D_2A,BX 		;保存转换双拼码
		JMP	L_A301			;二键处理
L_A01C:
		CMP	D_2A,0
K_PYCZ	EQU	$
		JZ	L_A01D
		MOV	AX,D_2A
		MOV	WORD PTR D_2CC1,AX	;
		MOV	AL,D_2B
		CMP	AL,'`'
		JZ	L_A01D
		MOV	D_2CC1+2,AL		;第二字声母
		MOV	D_2CC1+3,'?'
		MOV	D_2A,0
		XOR	DX,DX			;DH:提示行
		MOV	D_9597,DX		;重码计数
		MOV	D_2BD2,DH
		MOV	D_966C,3		;=3双拼词组
		OR	D_2BB9,8		;双拼词组
		CMP	D_SPCZ,0		;判是否安装双拼词组?
		JZ	L_A01F
		CALL	S_A9000 		;查双拼词组
		JMP	L_A610
L_A01D:
		CMP	D_2BB0,3
		JBE	L_A01F
		CMP	D_2BB0,5
		JA	L_A01F
		JMP	L_A390			;双拼四键处理
L_A01F:
		RET

D_2A		DW	0			;保存转换的双拼码
D_2B		DB	0			;末键

;【拼音码预处理】将2BB1区拷贝到2CC1区,返回:BP=查询键数,查询键码:BL,BH,DL
S_A010:
		MOV	AH,BL			;键数
		MOV	BP,OFFSET D_2BB1
L_A012:
		MOV	AL,CS:[BP]		;将键入码从2BB1区拷贝到2CC1区
		MOV	CS:[BP+10],AL
		INC	BP
		DEC	AH
		JNZ	L_A012
		MOV	D_2B,AL 		;末键
		MOV	DH,AL

		CMP	BL,1			;<一键>?
		JNZ	L_A020
		MOV	BL,AL
		MOV	BP,1			;一键处理
		RET
L_A020:
		MOV	AX,WORD PTR D_2CC1
		CMP	BL,2			;<二键>?
		JNZ	L_A030
		MOV	BX,AX
		JMP	L_A061
L_A030:
		MOV	BP,OFFSET D_3JB0	;双声母键表
L_A031:
		CMP	BYTE PTR CS:[BP],0
		JZ	L_A034
		CMP	AX,CS:[BP]
		JZ	L_A032
		ADD	BP,3
		JMP	SHORT L_A031
L_A032:
		MOV	AL,CS:[BP+2]		;viu三键
		MOV	D_2CC1,AL
		MOV	AH,D_2BB0
		SUB	AH,2			;韵母长
		MOV	BP,OFFSET D_2CC1+2	;韵母首址
L_A033:
		MOV	AL,CS:[BP]
		MOV	CS:[BP-1],AL
		INC	BP
		DEC	AH
		JNZ	L_A033
		DEC	BL			;键数-1
		MOV	D_2CC0,0FFH		;置拼音简码标志
		JMP	SHORT L_A020		;二键处理
L_A034:
		MOV	AX,WORD PTR D_2CC1+1	;指向韵母

		CMP	BL,3			;<三键>?
		JNZ	L_A040
		CMP	BYTE PTR D_2CC1,'a'
		JNZ	L_A036
		CMP	WORD PTR D_2CC1+1,'gn'
		JNZ	L_A035
		MOV	BX,'ga'
		JMP	L_A060			;二键处理
L_A035:
		XOR	BP,BP
		RET
L_A036:
		CMP	DH,"'"                  ;隔音符号?              2.3
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
		JMP	L_A060			;二键处理
L_A040:
		CMP	BL,4			;<四键>?
		JNZ	L_A050
		CMP	DH,"'"                  ;隔音符号?              2.3
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
		JMP	SHORT L_A060		;二键处理
L_A044:
		XOR	BP,BP
		RET
L_A048:
		CMP	BL,6			;<六键>?		2.3
		JNZ	L_A044
		CMP	DH,"'"                  ;隔音符号               2.3
		JZ	L_A050A
		JMP	SHORT L_A044
L_A050:
		CMP	BL,5			;<五键>?
		JNZ	L_A048
		CMP	DH,"'"                  ;隔音符号               2.3
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
		MOV	D_2CC0,0FFH		;置拼音简码标志
L_A061:
		CALL	S_A080
		MOV	BP,2			;二键处理
		RET

;子程序:显示查询码
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

D_3JB0		DB	'zhv', 'chi', 'shu', 0         ;双声母键表
D_3JB		DB	'ail', 'anj', 'aok', 'eid', 'enf', 'ons', 'oup'
		DB	'iar', 'iet', 'ihx', 'ijb', 'ikm', 'inn', 'ios'
		DB	'iuq', 'iss', 'uaw', 'uew', 'uhx', 'uiv', 'ujz'
		DB	'uly', 'unc', 'uoo', 'vew', 0  ;三键表
D_4JB		DB	'angh', 'engg', 'ongs'
		DB	'ianb', 'iaom', 'ingy', 'ions'
		DB	'uaiy', 'uanz', 0              ;四键表
D_5JB		DB	'iangx', 'iongs', 'uangx', 0   ;五键表

;【一键处理】
L_A28E:
		MOV	BL,D_2BB1		;取一查询码
L_A28F:
		TEST	D_963A,2		;判首尾?
		JNZ	L_A290
		TEST	D_2BB9,1		;一键高频?
		JNZ	L_A290
		MOV	SI,D_2BD6		;拼音码表首
		SUB	SI,11*26*2		;移一键字表首
		MOV	DI,OFFSET D_2BBA	;重码区首
		MOV	AL,BL
		AND	AL,1FH			;变为1~26
		CBW
		DEC	AX			;0~25
		MOV	CX,22			;每键11字
		MUL	CX
		ADD	SI,AX			;高频表该字母项
		REP	MOVSB			;写入重码区
		MOV	D_2BD2,11		;重码数
		OR	D_2BB9,1		;置一键高频位
		RET
L_A290:
		AND	BL,1FH			;转换
L_A295:
		CMP	SI,DI			;查完?
		JZ	L_A2AF
		MOV	AL,[SI] 		;取首尾表项
		AND	AL,1FH			;取出一键码
		CMP	AL,BL			;判
		JZ	L_A2C7
L_A2AB:
		LODSW				;转下一表项
		JMP	SHORT L_A295
L_A2AF:
		OR	CX,CX			;重码数=0?
		JZ	L_A2C1
		MOV	D_9597,CX		;存
		CMP	CX,11			;>11?
		JA	L_A2C1
		MOV	D_2BAD,DI		;存下次查表指针
L_A2C1:
		CLD
		RET
L_A2C7:
		CALL	S_A2D9			;重码处理
		JMP	SHORT L_A2AB
;子程序:重码处理
S_A2D9:
		CALL	S_A257			;转换为汉字内码并写入重码区
		JB	L_A2EE
		TEST	D_2BB9,20H		;提示行重码位?
		JNZ	L_A2EE
		MOV	D_2BAD,SI		;存下次查表指针
		OR	D_2BB9,20H		;置提示行重码位
L_A2EE:
		INC	CX			;重码数+1
		RET
;【二键处理】
L_A300:
		MOV	BX,WORD PTR D_2BB1	;取前二查询码
L_A301:
		AND	BX,1F1FH		;转换
		MOV	AH,BH
		XOR	AL,AL
		SHR	AX,1
		SHR	AX,1
		SHR	AX,1
		MOV	BH,AH
		OR	BL,AL
L_A31F:
		CMP	SI,DI			;查完?
		JZ	L_A338
		MOV	AX,[SI] 		;取表项
		AND	AX,3FFH 		;取10位
		CMP	AX,BX			;判
		JZ	L_A33A
L_A336:
		LODSW				;转下一表项
		JMP	SHORT L_A31F
L_A338:
		JMP	L_A2AF
L_A33A:
		TEST	D_963A,2		;判首尾
		JNZ	L_A33C
		TEST	D_2BB9,2		;二键高频?
		JNZ	L_A33C
		TEST	BYTE PTR DS:[SI+1],80H
		JZ	L_A336
L_A33C:
		CALL	S_A2D9			;重码处理
		JMP	SHORT L_A336
;【三键处理】
L_A350:
		MOV	BX,WORD PTR D_2BB1	;取前二查询码
		MOV	DL,D_2BB1+2		;取第三查询码
L_A351:
		AND	BX,1F1FH		;转换
		MOV	AH,BH
		XOR	AL,AL
		SHR	AX,1
		SHR	AX,1
		SHR	AX,1
		MOV	BH,AH
		OR	BL,AL
		AND	DL,1FH			;转换
		SHL	DL,1
		SHL	DL,1
		OR	BH,DL
L_A361:
		CMP	SI,DI			;查完?
		JZ	L_A38B
		MOV	AX,[SI] 		;取表项
		AND	AX,7FFFH
L_A383:
		CMP	AX,BX			;判
		JZ	L_A38E
L_A387:
		LODSW				;转下一表项
		JMP	SHORT L_A361
L_A38B:
		JMP	L_A2AF			;查完处理
L_A38E:
		CALL	S_A2D9			;重码处理
		JMP	SHORT L_A387
;【四键处理】
L_A390:
		XOR	DX,DX			;DH:提示行
		MOV	D_9597,DX		;重码计数
		MOV	D_2BD2,DH
		CMP	D_SPCZ,0		;判是否安装双拼词组?
		JZ	L_A391
		MOV	D_966C,3
		OR	D_2BB9,8		;双拼词组
		CALL	S_A900
		JMP	L_A610
L_A391:
		RET

;子程序:显示重码字
S_A164:
		MOV	DL,10H			;定位
		CALL	S_9F30			;定位清提示行
L_A172:
		MOV	DL,'0'
S_A180:
		MOV	CX,11
		CMP	CX,D_9597		;重码计数>11?
		JNB	L_A185
		SUB	D_9597,CX		;重码计数-11
		JMP	SHORT L_A189
L_A185:
		MOV	D_9597,0		;清重码计数
L_A189:
		MOV	CL,D_2BD2		;提示行重码数
		OR	CL,CL			;=0?
		JNZ	L_A19D
		TEST	D_963A,8		;判双拼?
		JNZ	L_A190
S_BEEP:
		MOV	DL,7
K_CMTS	EQU	$-1
		CALL	S_1403			;响铃,退出
L_A190:
		RET
L_A19D:
		MOV	SI,OFFSET D_2BBC
		CMP	DL,'0'
		JNZ	L_A1A2
		MOV	SI,OFFSET D_2BBA	;重码区指针
		PUSH	DX
		JMP	SHORT L_A1A6
L_A1A2:
		PUSH	DX
		MOV	BL,D_TUX2		;颜色:蓝底绿字
		CALL	S_1403			;显示序号
L_A1A6:
		TEST	D_963A,8		;判双拼?
		JNZ	L_A1A7
L_A1A7A:
		MOV	DL,':'
		CALL	S_1403			;显示':'
L_A1A7:
		MOV	BL,D_TUX1		;颜色:蓝底黄字
		LODSB
		CALL	S_1403A 		;显示前字节
		LODSB
		CALL	S_1403A 		;显示后字节
		TEST	D_963A,8		;判双拼?
		JZ	L_A1B0
		MOV	AX,[SI-2]		;取汉字内码
		CMP	D_2BB0,1		;一键?
		JNZ	L_A1A8
		CALL	S_A9A0			;取双拼码
		MOV	AL,AH
		JMP	SHORT L_A1A9
L_A1A8:
		CMP	D_2BB0,2		;二键?
		JNZ	L_A1B0
		CALL	S_A9B8			;取部首码
L_A1A9:
		CALL	S_1403A
L_A1B0:
		MOV	DL,' '
		CALL	S_1403			;显示空格
		POP	DX
		INC	DL			;序号加一
		CMP	DL,3AH			;第10号
		JNZ	L_A1C8
		MOV	DL,'0'                  ;置'0'
L_A1C8:
		LOOP	L_A1A2
		MOV	DL,8
		CALL	S_1403			;退格
;子程序:显示剩余重码数
S_A1CC:
		MOV	AX,D_9597		;剩余重码数
		MOV	SI,OFFSET D_A1D8+3	;个位
		MOV	CX,30AH
L_A1D0:
		DIV	CL			;除以10
		OR	AH,'0'
		MOV	[SI],AH 		;写入
		XOR	AH,AH
		DEC	SI
		DEC	CH
		JNZ	L_A1D0
L_A1D1:
		MOV	BL,D_TUX2		;颜色:蓝底绿字
		JMP	S_A24C			;显示字符串
D_A1D8		DB	'[000]',0

;子程序:转换查到地址为汉字内码并写入重码区
S_A257:
		PUSH	DI
		MOV	AL,D_2BD2		;提示行重码数
		CMP	AL,D_2BD0		;>=11
		JNB	L_A289
		MOV	AX,SI			;查到地址
		SUB	AX,D_2BD6		;减码表首址
		SHR	AX,1			;除以2得汉字序号
		MOV	DL,5EH			;=94
		DIV	DL			;除以94
		ADD	AX,0A1B0H		;得汉字内码
		MOV	DI,D_2BC0
		STOSW				;写入重码区
		MOV	D_2BC0,DI
		INC	D_2BD2			;提示行重码数+1
		STC
L_A289:
		POP	DI
		RET

;【预选处理】
L_A4F0:
		CMP	AL,'['                  ;<
		JNZ	L_A512
		CMP	D_YXH,1 		;第一行?
		JZ	L_A50D
		DEC	D_YXH			;行号-1
		SUB	D_YX,36H		;当前行地址-54
		JMP	L_YX1			;显示
L_A50D:
		JMP	L_9DC0			;响铃并返回
L_A512:
		CMP	AL,']'                  ;>
		JNZ	L_A52C
		MOV	SI,D_YX 		;当前行地址
		CMP	BYTE PTR [SI+36H],'$'   ;行尾为'$'?
		JZ	L_A50D
		INC	D_YXH			;行号+1
		ADD	D_YX,36H		;当前行地址+54
		JMP	L_YX1			;显示
L_A52C:
		CMP	AL,'A'                  ;判大写字母
		JNB	L_A535
L_A530:
		TEST	D_963A,3EH		;判原为首尾,拼音,双拼,五笔,词组?
		JNZ	L_A532
L_A531:
		JMP	L_9BA6			;直接输出
L_A532:
		CMP	AL,'a'                  ;判小写字母
		JB	L_A531
		CMP	AL,'z'
		JA	L_A531
		AND	D_2BB9,0BFH		;清预选位
		JMP	L_9C90			;转原输入方式处理
L_A535:
		CMP	AL,'Z'
		JA	L_A530
		SUB	AL,'A'                  ;得序号
		XOR	AH,AH
		SHL	AX,1			;得相对地址
		ADD	AX,D_YX 		;加当前行地址
		MOV	SI,AX			;选中字地址
		LODSW				;取字
		MOV	WORD PTR D_959D,AX	;写入返回码区
;【联想处理】
L_A559:
		MOV	D_95D5,2		;返回码计数=2
		MOV	D_95D6,2		;保存..
		MOV	D_959B,0FFH		;置完成态
		MOV	AX,WORD PTR D_959D	;取返回汉字
		MOV	BP,AX

		TEST	D_9639,1		;判联想开关状态
		JZ	L_A58F			;关则转
		CMP	D_9686,0		;联想库段=0?
		JZ	L_A58F
L_A574:
		CMP	AL,0B0H 		;判汉字?
		JB	L_A58F
		AND	AX,7F7FH		;去高位
		MOV	WORD PTR D_2BB1,AX	;作为键入码
		MOV	D_2BB0,2		;键入码计数=2
		MOV	D_966C,1		;联想
		MOV	D_966D,0FFH		;联想标志
		MOV	SI,OFFSET D_9A60	;'联想'
		JMP	L_A5DF			;词处理
D_9A60		DB	'联想 ',0

L_A58F:
		CMP	D_963B,0FFH		;判字典方式?
		JZ	L_A591
L_A590:
		RET
L_A591:
		CALL	S_1400
		MOV	SI,OFFSET D_QWXS	;'区位'
		MOV	BL,D_QTS2
		CALL	S_A24A
		MOV	AX,BP			;取返回汉字
		CALL	S_9E50			;显示二位数字
		MOV	AX,BP
		MOV	AL,AH
		CALL	S_9E50
		MOV	DL,' '
		CALL	S_1403

		CMP	BYTE PTR D_959D,0B0H	;判汉字?
		JB	L_A590

		MOV	DI,D_SW
		OR	DI,DI			;判安装首尾?
		JZ	L_A594
		MOV	SI,OFFSET D_SWXS	;'首尾'
		MOV	BL,D_QTS2
		CALL	S_A24A
		CALL	S_XSSW
L_A594:
		MOV	DI,D_PY
		OR	DI,DI			;判安装拼音?
		JZ	L_A595
		MOV	SI,OFFSET D_PYXS	;'拼音'
		MOV	BL,D_QTS2
		CALL	S_A24A
		CALL	S_XSPY
L_A595:
		MOV	DX,D_INTWB+2
		OR	DX,DX			;判安装五笔?
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
		MOV	AX,BP			;取返回汉字
		AND	AX,7F7FH
		SUB	AX,2130H
		MOV	DX,AX
		MOV	AL,94
		MUL	DL
		MOV	DL,DH
		XOR	DH,DH
		ADD	AX,DX			;汉字序号
		MOV	DX,AX
		SHL	AX,1
		ADD	AX,DX			;AX*3
		ADD	AX,0BDH 		;五笔模块码表地址
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
		MOV	DI,D_DB 		;判安装电报?
		MOV	CX,DI
		ADD	CX,20000
		OR	DI,DI
		JZ	L_A599
		MOV	SI,OFFSET D_DBXS
		MOV	BL,D_QTS2
		CALL	S_A24A
		MOV	DX,BP			;取返回汉字
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

D_WBCZ		DB	'词组:',0
;【词组处理】
L_A5D7:
		MOV	SI,OFFSET D_WBCZ	;'词组:'
		MOV	D_966C,0		;外部词组
L_A5DF:
		CALL	S_QTXS			;清提示行并显示
		MOV	SI,OFFSET D_2BB1	;键入码区首
		MOV	CL,D_2BB0		;键入码计数
		XOR	CH,CH
		MOV	BL,D_TUX1		;颜色:蓝底白字
L_A5F0:
		LODSB				;取词组外码
		CMP	D_966C,1		;判联想?
		JNZ	L_A5F8
		OR	AL,80H
L_A5F8:
		CALL	S_1403A 		;显示词组外码
		LOOP	L_A5F0
L_A5FA:
		MOV	SI,OFFSET D_9680	;词处理参数表首址
		MOV	AL,6			;每种6字节
		MUL	D_966C			;乘词处理方式号
		ADD	SI,AX			;指定词处理参数首
		LODSW				;词表段
		OR	AX,AX
		JNZ	L_A5FC
		JMP	L_9DC0
L_A5FC:
		MOV	D_2B98,AX
		LODSW				;词表外码区首
		MOV	D_2BA2,AX
		LODSW				;词表内码区首
		MOV	D_2BA0,AX
		MOV	D_2B9A,AX
		MOV	SI,D_2BA2		;词表外码区首
		CALL	S_A809			;SI指针下词长
		ADD	AX,D_2B9A		;下一词在内码区地址
		MOV	D_2B9E,AX		;存
		MOV	AX,D_2BA2
		MOV	D_2BAD,AX
		INC	AX
		MOV	D_2BAF,AX
L_A600:
		MOV	D_2BA5,0		;查词表方向:正向
		MOV	DI,D_2BA0		;内码区首指针
		CALL	S_A85A			;查词表
		CALL	S_A816			;为下次查表设指针
L_A610:
		TEST	D_2BB9,8		;判双拼词组?
		JZ	L_A618
		CMP	D_2BD2,1		;判重码数=1?
		JNZ	L_A616
		MOV	DL,13
		CALL	S_9F30			;定位清提示行
		XOR	AL,AL
		JMP	SHORT L_A634		;直接选中
L_A616:
		CALL	S_BEEP
		CMP	D_2BD2,0
		JZ	L_A627
L_A618:
		OR	D_2BB9,10H		;词组重码标志
		MOV	D_959B,0		;置未完成态
		CALL	S_A694			;显示重码词
		CMP	D_966D,0FFH		;联想标志?
		JZ	L_A627
		JMP	L_9DC5
L_A627:
		RET

;【词组选中处理】
L_A634:
		MOV	D_959B,0FFH		;置完成态
		MOV	BL,4
		MUL	BL
		MOV	BX,AX			;选中词在词重码区位置
		MOV	AX,D_9648[BX]		;取地址
		MOV	D_9669,AX		;选中词内码地址
		MOV	AX,WORD PTR D_964A[BX]	;取词长
		MOV	D_966B,AL		;选中词长
		MOV	D_2BD4,AH		;二字词偏移
						;原A701
		MOV	CL,D_966B		;选中词长
		MOV	D_95D5,CL		;返回码计数
		XOR	CH,CH

		MOV	SI,D_9669		;选中词内码指针
		MOV	DS,D_2B98		;DS=词表段
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_959D	;返回码区首
		CMP	CS:D_2BD4,0		;判二字词偏移?
		JZ	L_A650
L_A640:
		LODSW				;传送第一字
		OR	AX,8080H
		STOSW
		TEST	CS:D_2BB9,80H		;二字词叠字?
		JZ	L_A642
		MOV	AX,[SI-2]
		STOSW
L_A642:
		MOV	AL,CS:D_2BD4
		CBW
		MOV	CS:D_2BD4,AH		;清0
		ADD	SI,AX			;加偏移
		MOVSW				;传送第二字
		TEST	CS:D_2BB9,80H		;二字词叠字?		11.11
		JZ	L_A660
		MOV	AX,[SI-2]
		STOSW
		ADD	CS:D_95D5,4
		JMP	SHORT L_A660
L_A650:
		TEST	CS:D_2BB9,80H		;二字词叠字?		11.11
		JZ	L_A654
		CMP	CL,4			;判二字词?
		JZ	L_A640
L_A654:
		REP	MOVSB
L_A660:
		PUSH	CS
		POP	DS
		TEST	D_2BB9,8		;判双拼词组?
		JZ	L_A664
		MOV	CL,4
		MOV	DI,OFFSET D_959D
L_A662:
		OR	BYTE PTR DS:[DI],80H	;高位置1		11.11
		INC	DI
		LOOP	L_A662
L_A664:
		MOV	AL,D_95D5		;保存			11.15
		MOV	D_95D6,AL
		AND	D_2BB9,7FH		;清标志 		11.11
		RET

;子程序:显示重码词
S_A694:
		MOV	DL,16
		CALL	S_9F30			;定位清提示行
		MOV	DL,D_2BD2		;提示行重码数
		OR	DL,DL			;=0?
		JNZ	L_A6A0
	;	AND	D_2BB9,0F7H		;清双拼词组位
		RET
L_A6A0:
		XOR	DH,DH
		SUB	D_9597,DX		;剩余重码数
		CALL	S_A1CC			;显示剩余重码数
		MOV	DL,21
		CALL	S_1402
		MOV	DL,'0'                  ;序号
		MOV	CL,D_2BD2		;提示行重码数
		PUSH	DX
		JMP	SHORT L_A6BC
L_A6B8:
		PUSH	DX
		MOV	BL,D_TUX1		;颜色:蓝底黄字
		CALL	S_1403			;显示序号
L_A6BC:
		MOV	BL,D_2BD2
		SUB	BL,CL
		MOV	AL,4
		MUL	BL
		MOV	BX,AX
		MOV	SI,D_9648[BX]		;内码区首
		PUSH	CX
		MOV	CX,WORD PTR D_964A[BX]	;词长
		MOV	BL,D_TUX2		;颜色:蓝底绿字
		MOV	DS,D_2B98		;词表段
		OR	CH,CH			;判二字词偏移?
		JZ	L_A6DB
		LODSB				;取一字节
		OR	AL,80H
		CALL	S_1403A 		;显示
		LODSB				;取一字节
		OR	AL,80H
		CALL	S_1403A 		;显示
		MOV	AL,CH
		XOR	AH,AH
		ADD	SI,AX			;加偏移
		LODSB				;取一字节
		CALL	S_1403A 		;显示
		LODSB				;取一字节
		CALL	S_1403A 		;显示
		JMP	SHORT L_A6E0
L_A6DB:
		TEST	CS:D_2BB9,8		;判双拼词组?
		JZ	L_A6DE
L_A6DC:
		LODSB				;取一字节		3.15
		OR	AL,80H
		CALL	S_1403A 		;显示
		LODSB				;取一字节
		OR	AL,80H
		CALL	S_1403A 		;显示
		SUB	CX,2
L_A6DE:
		LODSB				;取一字节
		CALL	S_1403A 		;显示
		LOOP	L_A6DE
L_A6E0:
		MOV	DL,' '
		CALL	S_1403			;显示空格
		PUSH	CS
		POP	DS
		POP	CX
		POP	DX
		INC	DL			;序号+1
		CMP	DL,3AH
		JNZ	L_A6F3
		MOV	DL,'0'                  ;10='0'
L_A6F3:
		LOOP	L_A6B8
		RET

;【重选词组】
L_A73B:
		CMP	AH,82H			;ALT+'-'
		JNB	L_A760
		CMP	AH,78H			;ALT+1
		JB	L_A757
		MOV	AL,AH
		SUB	AL,77H			;ALT+1~0转换为0~9
L_A749:
		CMP	AL,D_2BD2		;超出选择范围?
		JB	L_A752
		JMP	L_9DC0			;响铃并返回
L_A752:
		JMP	L_A634			;选中词
L_A757:
		CALL	S_9F66			;判ALT+空格
		JB	L_A749
		JMP	SHORT L_A767
L_A760:
		JZ	L_A76A			;是ALT+'-'
		CMP	AH,83H			;ALT+'+'
		JZ	L_A783
L_A767:
		JMP	L_9E86			;非词首键处理
L_A76A:
		TEST	D_2BB9,8		;判双拼词组
		JZ	L_A770
		RET
L_A770:
		CALL	S_A831			;为反向查词表设指针
		MOV	DI,D_2BA2		;词表外码区指针
		DEC	DI
		STD
		MOV	D_2BA5,0FFH		;查词表方向:反向
		CALL	S_A85A			;查词表
		CALL	S_A83A			;反向为下次查词表设指针
		JMP	L_A610			;再入词方式
L_A783:
		TEST	D_2BB9,8		;判双拼词组
		JZ	L_A790
		RET
L_A790:
		CALL	S_A851			;为正向查词表设指针
		JMP	L_A600			;再入词方式
;【词组选中】
L_A798:
		CMP	AL,0DH			;回车?
		JNZ	L_A7C0
L_A79D:
		MOV	D_2BB0,0
		AND	D_2BB9,0EFH		;清词标志位
		CALL	S_9F2E			;定位清提示行
		MOV	D_959B,0FFH		;置完成态
		JMP	L_9DC5			;返回
L_A7C0:
		CMP	AL,'['
		JNZ	L_A7C1
		JMP	L_A76A
L_A7C1:
		CMP	AL,']'
		JZ	L_A783
		CMP	AL,'9'                  ;判数字
		JA	L_A7E2
		CMP	AL,'0'
		JB	L_A7D9
		JNZ	L_A7D4
		MOV	AL,3AH
L_A7D4:
		AND	AL,0FH
		JMP	L_A749			;词选中
L_A7D9:
		CMP	AL,' '
		JB	L_A79D
		JNZ	L_A7E2
		XOR	AL,AL			;空格=0
		JMP	L_A749			;词选中
L_A7E2:
		CMP	D_963A,4
		JZ	L_A7E3
		JMP	L_9E86			;重入原输入方式
L_A7E3:
		JMP	L_9D54

;子程序:取指针下SI词长
S_A809:
		PUSH	DS
		MOV	DS,D_2B98
		MOV	AL,[SI]
		XOR	AH,AH
		POP	DS
		RET
;子程序:正向为下次查词表设指针
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
;子程序:为反向查词表设指针
S_A831:
		MOV	AX,D_2B9C
		MOV	D_2B9A,AX
		MOV	AX,D_9646
		MOV	D_2BAD,AX
		RET
;子程序:反向为下次查词表设指针
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
;子程序:为正向查词表设指针
S_A851:
		MOV	AX,D_2B9E
		MOV	D_2B9A,AX
		MOV	AX,D_2BAF
		MOV	D_2BAD,AX
		RET

;子程序:查词表
S_A85A:
		AND	D_2BB9,0DFH		;清重码位
		XOR	DX,DX			;DH:提示行词组总长
		MOV	D_9597,DX		;重码计数
		MOV	D_2BD2,DH		;清提示行重码数
		XOR	CH,CH
		MOV	SI,D_2BAD		;当前词表指针
		MOV	BP,D_2B9A		;当前内码指针
		MOV	DS,D_2B98		;词表段
L_A87C:
		CMP	SI,DI			;查完?
		JNZ	L_A899
		PUSH	CS
		POP	DS
		MOV	AL,D_2BD2		;提示行重码数
		XOR	AH,AH
		CMP	AX,D_9597		;重码数>提示行重码数?
		JBE	L_A897
		MOV	D_2BAD,SI		;存当前查表指针
		MOV	D_2B9A,BP		;存当前内码区指针
L_A897:
		CLD
		RET
L_A899:
		PUSH	BP
		MOV	CL,CS:D_2BB0		;键入码数
		MOV	BX,OFFSET D_2BB1	;键入码区首
L_A89D:
		MOV	AL,DS:[BP]
		CMP	AL,CS:[BX]		;判键
		JNZ	L_A8BC
		INC	BP
		INC	BX
		LOOP	L_A89D
		JMP	SHORT L_A8DC
L_A8BC:
		POP	BP
L_A8BD:
		LODSB				;转下一词
		XOR	AH,AH
		CMP	CS:D_2BA5,0FFH		;反向查词表?
		JZ	L_A8D2
		ADD	BP,AX			;内码指针下移
		JMP	SHORT L_A87C
L_A8D2:
		MOV	AL,[SI] 		;指针下词长
		SUB	BP,AX			;内码区指针上移
		JMP	SHORT L_A87C
L_A8DC:
		POP	BP
		INC	CS:D_9597		;重码数+1
		MOV	DL,[SI] 		;词长
		PUSH	BP
		CMP	CS:D_966D,0FFH
		JNZ	L_A8E0
L_A8DE:
		CMP	BYTE PTR DS:[BP],0A0H	;判汉字?
		JA	L_A8E8
		INC	BP
		DEC	DL
		JMP	SHORT L_A8DE
L_A8E0:
		CMP	BYTE PTR DS:[BP],60H	;判小写字母?
		JB	L_A8E8
		CMP	BYTE PTR DS:[BP],7AH
		JA	L_A8E8
		INC	BP
		DEC	DL
		JMP	SHORT L_A8E0
L_A8E8:
		MOV	AX,BP
		POP	BP
		ADD	DH,DL			;累计提示行词长
		ADD	DH,2			;加序号和空格
		TEST	CS:D_2BB9,20H		;提示行重码记录位?
		JNZ	L_A8BD
		MOV	BL,CS:D_2BD2		;提示行重码数
		CMP	DH,CS:D_9668		;比提示行词组区长度?
		JA	L_A8FA
		CMP	BL,11			;提示行重码数>11
		JB	L_A8FB
L_A8FA:
		OR	BL,BL			;提示行无重码词?
		JNZ	L_A8FC
L_A8FB:
		PUSH	AX
		MOV	AL,4
		MUL	BL			;词重码区指针
		MOV	BX,AX
		POP	AX
		MOV	CS:D_964A[BX],DL	;存查到词长
		MOV	CS:D_964B[BX],0
		MOV	CS:D_9648[BX],AX	;存内码区地址
		INC	CS:D_2BD2		;提示行重码数+1
		JMP	L_A8BD
L_A8FC:
		TEST	CS:D_2BB9,20H		;提示行重码记录位?
		JNZ	L_A8FD
		MOV	CS:D_2BAD,SI		;存当前查词表指针
		MOV	CS:D_2B9A,BP		;存当前内码区指针7
		OR	CS:D_2BB9,20H		;置提示行重码记录位
L_A8FD:
		JMP	L_A8BD

;子程序:查双拼词表
;	SI-地址,BP-词长,DH-累计长,DL-二字偏移
S_A900:
		MOV	AX,WORD PTR D_2BB1
		MOV	WORD PTR D_2CC1,AX
		MOV	AX,WORD PTR D_2BB1+2
		MOV	WORD PTR D_2CC1+2,AX
S_A9000:
		MOV	DS,D_SPCZ		;双拼词表段
		MOV	CS:D_2B98,DS

		MOV	SI,DS:[4]		;扩展词库首
L_A901:
		CMP	SI,DS:[6]		;判:扩展词库尾?
		JZ	L_A940			;判:基本词库
		XOR	BP,BP
L_A903:
		CMP	BYTE PTR DS:[BP+SI],',' ;判词尾?
		JZ	L_A910
		INC	BP
		JMP	SHORT L_A903
L_A910:
		CMP	BP,4			;二字词?
		JNZ	L_A920
		MOV	DI,SI
		LODSW				;取一字
		CALL	S_A9A0			;取双拼
		CMP	AX,WORD PTR CS:D_2CC1	;判?
		LODSW
		JNZ	L_A919
		CALL	S_A9A0			;取双拼
		CMP	AL,CS:D_2CC1+2		;判第三码?
		JNZ	L_A919
		CMP	CS:D_2CC1+3,'?'
		JZ	L_A912
		CMP	AH,CS:D_2CC1+3		;判第四键?
		JNZ	L_A919
L_A912:
		CALL	S_A990			;存
L_A919:
		INC	SI
		JMP	SHORT L_A901
L_A920:
		CMP	BP,6			;三字词?
		JNZ	L_A930
		CALL	S_SP6			;查三字词
		JMP	SHORT L_A919
L_A930:
		CALL	S_SP8			;查多字词
		JMP	SHORT L_A919

L_A940:
		MOV	BP,4			;二字词
		MOV	SI,16
L_A941:
		XOR	DL,DL
		CMP	SI,DS:[0]		;三字词开始?
		JZ	L_A950
		MOV	DI,SI
		LODSW				;取一字
		CALL	S_A9A0			;取双拼
		CMP	AX,WORD PTR CS:D_2CC1	;判?
		JZ	L_A945
L_A942:
		LODSW
		TEST	AX,8080H		;判下一行首?
		JNZ	L_A942
L_A943:
		SUB	SI,2			;指向下一行首
		JMP	SHORT L_A941
L_A944:
		ADD	DL,2			;偏移
L_A945:
		LODSW				;取一字
		TEST	AX,8080H		;判下一行首?
		JZ	L_A943
		CALL	S_A9A0			;取双拼
		CMP	AL,CS:D_2CC1+2		;判第三码?
		JNZ	L_A944
		CMP	CS:D_2CC1+3,'?'
		JZ	L_A946
		CMP	AH,CS:D_2CC1+3		;判第四码?
		JNZ	L_A944
L_A946:
		CALL	S_A990			;存
		JMP	SHORT L_A944
L_A950:
		CMP	CS:D_2CC1+3,'`'         ;第四键`只能是三字词
		JNZ	L_A960
		MOV	BP,6			;三字词
L_A951:
		CMP	SI,DS:[2]		;四字词开始地址?
		JZ	L_A970
		CALL	S_SP6
		JMP	SHORT L_A951
L_A960:
		CMP	SI,DS:[4]		;四字词结束?
		JZ	L_A970
		CALL	S_SP8
		INC	SI
		JMP	SHORT L_A960
L_A970:
		PUSH	CS			;结束
		POP	DS
		RET
;子程序:查找三字词
S_SP6:
		LODSW
		CALL	S_A9B0			;取双拼声母
		CMP	AL,CS:D_2CC1
		JZ	L_SP61
		ADD	SI,4
		RET
L_SP61:
		LODSW
		CALL	S_A9B0			;取双拼声母
		CMP	AL,CS:D_2CC1+1
		LODSW
		JNZ	L_SP62
		CALL	S_A9B0			;取双拼声母
		CMP	AL,CS:D_2CC1+2
		JNZ	L_SP62
		CALL	S_A990			;存
L_SP62:
		RET
;子程序:查找多字词
S_SP8:
		LODSW				;第一字
		CALL	S_A9B0			;取双拼声母
		CMP	AL,CS:D_2CC1
		JZ	L_SP82
;子程序:查找词尾 指向逗号
S_A980:
		MOV	BP,6
L_A981:
		CMP	BYTE PTR [SI],','       ;判词尾?
		JZ	L_A981A
		INC	BP
		INC	SI
		JMP	SHORT L_A981
L_A981A:
		RET
L_SP82:
		LODSW				;第二字
		CALL	S_A9B0			;取双拼声母
		CMP	AL,CS:D_2CC1+1
		JNZ	S_A980
		LODSW				;第三字
		CALL	S_A9B0			;取双拼声母
		CMP	AL,CS:D_2CC1+2
		JNZ	S_A980
		CALL	S_A980			;查找词尾
		MOV	AX,[SI-2]		;取末字
		CALL	S_A9B0			;取双拼声母
		CMP	AL,CS:D_2CC1+3
		JNZ	L_SP83
		CALL	S_A990			;存
L_SP83:
		RET
;子程序:存查到词地址
S_A990:
		INC	CS:D_9597		;重码数+1	11.16-
		MOV	CX,BP			;词长
		ADD	DH,CL			;累计词长
		ADD	DH,2			;加序号和空格
		CMP	DH,CS:D_9668		;判满?
		JA	L_A993			;		11.16┐
		MOV	AL,CS:D_2BD2		;取提示行重码数
		CMP	AL,11
		JAE	L_A993
		INC	CS:D_2BD2		;提示行重码数+1
		MOV	AH,4
		MUL	AH			;		11.16┘
		MOV	BX,AX			;指针
		MOV	CS:D_964A[BX],CL	;存查到词长
		MOV	CS:D_964B[BX],DL	;二字词偏移
		CMP	BP,4
		JZ	L_A992
		MOV	AX,SI			;下一词地址
		SUB	AX,BP			;减词长
		MOV	CS:D_9648[BX],AX	;存查到词地址
		RET
L_A992:
		MOV	CS:D_9648[BX],DI	;存查到词地址
L_A993:
		RET
;子程序:取双拼
S_A9A0:
		CALL	S_A9C0			;取码表表项	A960
S_A9A1:
		AND	AX,3FFH 		;取低十位	A961
		PUSH	CX
		MOV	CL,3
		SHL	AX,CL
		SHR	AL,CL			;AH第二,AL第一
		POP	CX
		ADD	AX,6060H		;变为小写字母
		RET
;子程序:取首拼码
S_A9B0:
		CALL	S_A9C0			;取码表表项	A970
		AND	AL,1FH			;取低五位
		ADD	AL,60H			;变为小写字母
		RET
;子程序:取部首码
S_A9B8:
		CALL	S_A9C0			;取码表表项
		MOV	AL,AH
		AND	AL,7FH
		SHR	AL,1
		SHR	AL,1
		OR	AL,60H
		RET
;子程序:取汉字在拼音码表中的表项			      A990
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

;子程序:显示拼音
S_XSPY:
		MOV	AX,BP
		PUSH	AX
		CALL	S_A9A0			;取前二码
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

;子程序:显示首尾
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
		INCLUDE	KEYEDIT.INC

A_BUF		DW	0			;公用缓冲区指针
D_959D		EQU	$			;返回码区(容量256)
D_BUF		EQU	$+256			;公用缓冲区(512字节)

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		ORG	$+64
L_S60:
		CMP	K_SW,'Y'                ;安装首尾码表?
		JNZ	L_S70
		MOV	DX,OFFSET F_SWMB	;'SWMB', 0
		CALL	S_HF			;写入文件名并打开
		JB	L_S62
		CALL	S_READ			;读
		JB	L_S62
		OR	CX,CX
		JZ	L_S62
		MOV	DX,CS:[BP]		;'首'
		MOV	WORD PTR D_SWXS,DX
		MOV	DX,CS:[BP+2]		;'尾'
		MOV	WORD PTR D_SWXS+2,DX
		MOV	D_SW,BP 		;存首尾码表首地址
		ADD	D_SW,4
		ADD	BP,CX			;加首尾码表长度
		MOV	D_SW+2,BP		;存首尾码表尾地址
		JMP	SHORT L_S70
L_S62:
		MOV	K_SW,'N'
		MOV	SI,OFFSET F_SWMB	;'SWMB', 0
		CALL	S_NOFOUND
L_S70:
		CMP	K_PY,'Y'                ;安装拼音码表?
		JNZ	L_S80
		MOV	DX,OFFSET F_PYMB	;'PYMB', 0
		CALL	S_HF			;写入文件名并打开
		JB	L_S72
		CALL	S_READ			;读
		JB	L_S72
		OR	CX,CX
		JZ	L_S72
		MOV	D_PY,BP 		;存拼音码表首地址
		ADD	D_PY,11*26*2
		ADD	BP,CX			;加拼音码表长度
		MOV	D_PY+2,BP		;存拼音码表尾地址
		JMP	SHORT L_S80
L_S72:
		MOV	K_PY,'N'
		MOV	SI,OFFSET F_PYMB	;'PYMB', 0
		CALL	S_NOFOUND
L_S80:
		CMP	K_DB,'Y'                ;安装电报码表?
		JNZ	L_S90
		MOV	DX,OFFSET F_DBMB	;'DBMB', 0
		CALL	S_HF			;写入文件名并打开
		JB	L_S82
		CALL	S_READ			;读
		JB	L_S82
		OR	CX,CX
		JZ	L_S82
		MOV	D_DB,BP 		;存电报码表首地址
		ADD	BP,CX			;加电报码表长度
		JMP	SHORT L_S90
L_S82:
		MOV	K_DB,'N'
		MOV	SI,OFFSET F_DBMB	;'DBMB', 0
		CALL	S_NOFOUND
L_S90:
		MOV	DX,OFFSET F_YX		;'YX0.DAT'
		CALL	S_HF			;写入文件名并打开
		JB	L_S92
		CALL	S_READ			;读
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

		MOV	AL,K_SPKZ		;双拼词组区大小
		CMP	AL,'1'
		JB	L_S100
		CMP	AL,'9'
		JA	L_S100
		AND	AL,0FH
		CBW
		MOV	DX,400H 		;=1K
		MUL	DX
		MOV	DS:[0FCH],AX		;双拼词组预留区

		MOV	DX,OFFSET F_SPCZ
		CALL	S_HF			;写入文件名并打开
		JB	L_S98
		MOV	BX,AX
		MOV	DS,BP
		MOV	CS:D_SPCZ,BP
		MOV	DX,0
		MOV	CX,-1
		MOV	AH,3FH			;读双拼词组文件
		INT	21H
		MOV	DI,AX
		MOV	WORD PTR DS:[DI],0	;尾置0
		MOV	AX,CS:[0FCH]
		ADD	AX,DS:[6]		;加双拼词组区长度
		MOV	DS:[8],AX		;双拼词组区尾
		MOV	CL,4
		SHR	AX,CL
		INC	AX
		MOV	DX,AX			;
		MOV	AH,3EH
		INT	21H
		CMP	BYTE PTR DS:[0FH],0FFH	;新SPCZ.DAT标志?
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
		MOV	D_LEN,DX		;驻留长度(节)

		MOV	AX,CS
		CMP	AX,0A000H		;判LH?
		JA	L_S110
		CMP	D_RAM,'N'               ;驻留基本内存
		JZ	L_S110
		CALL	S_GETUMB		;分配UMB段
		JZ	L_S120
L_S110:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		CALL	S_SETINT
		JMP	L_S140			;驻留
L_S120:
		MOV	AX,D_UMB
		OR	AX,AX
		JZ	L_S110
		DEC	AX
		MOV	ES,AX
		MOV	DI,8
		MOV	SI,OFFSET D_NAME
		MOV	CX,5
		REP	MOVSB			;向UMB文件控制块写入本模块名

		MOV	DX,D_UMB		;段
		MOV	ES,DX
		XOR	SI,SI
		MOV	DI,SI
		MOV	BP,D_LEN
		CMP	BP,1000H
		JB	L_S130
		SUB	BP,1000H
		MOV	CX,8000H
		REP	MOVSB			;拷贝本模块到UMB
		MOV	CX,8000H
		REP	MOVSB			;拷贝本模块到UMB
		ADD	DX,1000H
		MOV	ES,DX
		MOV	DX,DS
		ADD	DX,1000H
		MOV	DS,DX
L_S130:
		MOV	AX,16
		MUL	BP
		MOV	CX,AX
		REP	MOVSB			;拷贝本模块到UMB
		MOV	DS,CS:D_UMB

		CALL	S_SETINT

		PUSH	CS
		POP	DS
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		PUSH	CS
		POP	ES
		MOV	AH,49H			;清本模块
		INT	21H

		MOV	AH,50H			;设置新PSP
		MOV	BX,D_UMB
		INT	21H
L_S140:
		MOV	DX,D_LEN		;本模块长度(节)
		MOV	AX,3100H		;驻留
		INT	21H

D_XMS		DD	0			;XMS驱动地址
D_NCFP		DW	0			;原内存分配策略
D_UMB0		DW	0			;原UMB连接状态
D_UMB		DW	0			;分配UMB段
D_LEN		DW	0			;本模块长度(节)
D_RAM		DB	0			;='N':驻留基本内存

;子程序:取UMB段
S_GETUMB	PROC	NEAR
		CALL	S_GETXMS		;取XMS驱动地址
		JNZ	L_GU2
		MOV	AH,10H			;请求UMB
		CALL	D_XMS			;XMS
		CMP	AX,1			;=1:成功,BX=段
		JZ	L_GU1
		CALL	S_UMB			;分配UMB段BX
		CMP	AL,AL			;ZF=1
		RET
L_GU1:
		MOV	D_UMB,BX		;取出UMB段
L_GU2:
		RET
S_GETUMB	ENDP

S_UMB		PROC	NEAR
		MOV	AX,3000H		;取DOS版本号
		INT	21H
		CMP	AL,5			;判>5.0
		JB	L_UMB3
		MOV	AX,5800H		;取内存分配策略AX
		INT	21H
		MOV	D_NCFP,AX
		MOV	AX,5802H		;取UMB连接状态AL
		INT	21H
		CBW
		MOV	D_UMB0,AX

		MOV	AX,5803H		;置UMB连接
		MOV	BX,1			;=1连接
		INT	21H
		JC	L_UMB3
		MOV	AX,5801H		;置内存分配策略
		MOV	BX,41H			;最佳适合块
		INT	21H
		JC	L_UMB2
		MOV	AH,48H			;分配内存
		MOV	BX,D_LEN
		INT	21H
		JC	L_UMB1
		MOV	D_UMB,AX		;分配块段
L_UMB1:
		MOV	AX,5801H		;恢复内存分配策略
		MOV	BX,D_NCFP
		INT	21H
L_UMB2:
		MOV	BX,D_UMB0
		MOV	AX,5803H		;恢复UMB连接状态
		INT	21H
L_UMB3:
		RET
S_UMB		ENDP

;子程序:取XMS驱动地址 ->D_XMS
S_GETXMS	PROC	NEAR
		MOV	AX,4300H		;取XMS安装状态
		INT	2FH
		CMP	AL,80H			;=80H:已安装
		JNZ	L_GX1
		MOV	AX,4310H		;取XMS驱动地址
		INT	2FH
		MOV	WORD PTR D_XMS,BX	;保存
		MOV	WORD PTR D_XMS+2,ES
		CMP	AL,AL			;返回ZF=1
L_GX1:
		RET
S_GETXMS	ENDP

D_EXIT		DB	0
D_INT28		DD	0
D_INDOS		DD	0
D_28SS		DW	0
D_28SP		DW	0
		DW	80H DUP(0)
D_28STK		EQU	$

INT_28		PROC	FAR
		CMP	CS:D_EXIT,0
		JZ	L_28C
		MOV	AX,WORD PTR CS:D_INDOS+2
		OR	AX,AX
		JZ	L_28GO
		LES	BX,CS:D_INDOS
		CMP	BYTE PTR ES:[BX+1],0
		JNZ	L_28C
L_28GO:
		MOV	AL,CS:D_EXIT
		MOV	CS:D_EXIT,0
		MOV	CS:D_28SS,SS
		MOV	CS:D_28SP,SP
		PUSH	CS
		POP	SS
		MOV	SP,OFFSET D_28STK
		STI
		CMP	AL,1
		JZ	L_28EX
		XOR	SI,SI
		MOV	AX,4A06H
		INT	2FH
L_28EX:
		MOV	AX,4CFFH
		INT	21H
L_28C:
		JMP	CS:D_INT28
INT_28		ENDP

S_SETINT	PROC	NEAR
		MOV	DX,OFFSET INT_16
		MOV	AX,2516H		;建中断16H
		INT	21H
		MOV	DX,OFFSET INT_9
		MOV	AX,2509H		;建中断9
		INT	21H
		MOV	AX,3528H
		INT	21H
		MOV	WORD PTR D_INT28,BX
		MOV	WORD PTR D_INT28+2,ES
		MOV	DX,OFFSET INT_28
		MOV	AX,2528H
		INT	21H
		MOV	AH,34H
		INT	21H
		MOV	WORD PTR D_INDOS,BX
		MOV	WORD PTR D_INDOS+2,ES


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

;子程序:写入文件名并打开 DX=文件名首 返回DX=文件名首
S_HF		PROC	NEAR
		MOV	DI,A_S			;本程序路径写入地址
		OR	DI,DI			;判有无?
		JZ	L_HF1
		MOV	CX,10
		MOV	SI,DX			;不带环境的文件名
		CALL	S_MOVE			;传送
		MOV	DX,OFFSET F_S		;带环境的文件名
L_HF1:
		MOV	AX,3D00H		;打开文件
		INT	21H
		RET
S_MOVE:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	S_MOVE
		RET
S_HF		ENDP

;子程序:读文件 DX=文件名首,BP=读入地址 返回CX=读出长度
S_READ		PROC	NEAR
		MOV	BX,AX
		MOV	DX,BP			;读入地址
		MOV	CX,-1
		MOV	AH,3FH
		INT	21H
		JB	L_RD1
		MOV	CX,AX			;读出长度
		MOV	AH,3EH
		INT	21H
		CLC
L_RD1:
		RET
S_READ		ENDP

NOFOUND 	DB	13,10,'NOT FOUND FILE ',7,'$'
;子程序:显示未找到 SI:文件名
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

D_NAME		DB	'CKBD',0                ;模块名
F_S		DB	40 DUP(0)		;源文件名
A_S		DW	0			;写入地址
MSG		DB	'2.13L 汉字系统键盘模块 ',DATE,13,10
		DB	'  /E  Enable whole-Hanzi editing (INT 16h applications)',13,10
		DB	'  /B  Byte editing (default); /E and /B also change a resident CKBD',13,10,'$'

;****************************************************************************
;【本模块开始执行】
D_EDITREQ	DB	0FFH
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
		CMP	AL,'E'
		JNE	L_EOFF
		MOV	D_EDIT,1
		MOV	D_EDITREQ,1
		JMP	SHORT L_S1
L_EOFF:
		CMP	AL,'B'
		JNE	L_EOTHER
		MOV	D_EDIT,0
		MOV	D_EDITREQ,0
		JMP	SHORT L_S1
L_EOTHER:
		CMP	AL,'N'                  ;/N:驻留基本内存
		JNZ	L_S1
		MOV	D_RAM,AL
		JMP	SHORT L_S1
L_S10:
		; Resident mode changes must not drain queued keyboard input.
		MOV	AH,2FH
		INT	16H
		CMP	AX,44H
		JE	L_EINSTALLED
		MOV	CX,-1
		MOV	AH,5			;向键盘缓冲区送0FFFFH
		INT	16H
		OR	AL,AL			;判支持?
		JNZ	L_S14
		MOV	CX,15
L_S12:
		MOV	AH,10H			;取键码
		INT	16H
		CMP	AX,-1			;是否写入的?
		JZ	L_S15
		LOOP	L_S12
L_S14:
		MOV	BYTE PTR INT16_AH0,0	;老键盘,只能用AH=0
		MOV	BYTE PTR INT16_AH1,1
L_S15:
		MOV	AH,2FH			;取本模块段
		INT	16H
		CMP	AX,44H			;判CKBD已驻留?		2.10
		JNZ	L_S20
L_EINSTALLED:
		CMP	D_EDITREQ,0FFH
		JE	L_EALREADY
		MOV	AL,D_EDITREQ
		MOV	AH,2CH
		INT	16H
		CMP	AX,4B48H
		JNE	L_EALREADY
		MOV	AX,4C00H
		INT	21H
L_EALREADY:
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
		MOV	AX,ES:[82H]		;键盘缓冲区尾址
		SUB	AX,ES:[80H]		;-区首=缓冲区大小
		SHR	AX,1
		MOV	D_KBDBUF,AX
		MOV	AX,3516H		;取中断16H
		INT	21H
		MOV	WORD PTR D_INT16,BX	;存
		MOV	WORD PTR D_INT16+2,ES
		MOV	AX,3509H		;;取中断9
		INT	21H
		MOV	WORD PTR D_INT9,BX	;存
		MOV	WORD PTR D_INT9+2,ES

		MOV	DS,DS:[2CH]		;环境段
		XOR	SI,SI
L_S30:
		CMP	WORD PTR DS:[SI],0	;查找环境区尾?
		JZ	L_S32
		INC	SI
		JMP	SHORT L_S30
L_S32:
		ADD	SI,4
		MOV	DI,OFFSET F_S		;带路径源文件名区
		PUSH	CS
		POP	ES
		CMP	BYTE PTR [SI+1],':'     ;判有盘符?
		JZ	L_S33
		MOV	AH,19H			;取当前盘
		INT	21H
		INC	AL
		MOV	DL,AL
		OR	AL,40H
		STOSB				;写入盘符
		MOV	AL,':'
		STOSB
		CMP	BYTE PTR [SI],'\'       ;判有绝对路径?
		JZ	L_S33
		MOV	AL,'\'
		STOSB
		JMP	SHORT L_S34
L_S33:
		CMP	BYTE PTR [SI+2],'\'     ;判有绝对路径?
		JZ	L_S35
		LODSW				;盘符和\
		SUB	AL,40H
		MOV	DL,AL			;盘符
		STOSW
L_S34:
		PUSH	SI
		MOV	SI,DI
		MOV	AH,47H			;取当前路径
		INT	21H
		POP	SI
L_S35:
		CALL	S_MOVE			;传送
		PUSH	CS
		POP	DS
L_S37:
		CMP	BYTE PTR [DI-1],'\'
		JZ	L_S38
		DEC	DI
		JMP	SHORT L_S37
L_S38:
		MOV	A_S,DI			;文件名写入地址

		MOV	SI,OFFSET F_S
		MOV	DI,D_PATH
		MOV	WORD PTR [DI-2],'  '
L_S40:
		CMP	SI,A_S
		JZ	L_S41
		MOVSB				;传送到安装路径
		JMP	SHORT L_S40
L_S41:
		MOV	BYTE PTR [DI-1],0

		MOV	DX,OFFSET F_INI
		CALL	S_HF			;写入文件名并打开
		JNB	L_S42
		MOV	SI,OFFSET F_INI
		CALL	S_NOFOUND
		JMP	L_ERR1
L_S42:
		MOV	BX,AX
		MOV	DX,OFFSET BUF
		MOV	SI,DX
		MOV	CX,-1
		MOV	AH,3FH			;读配置文件
		INT	21H
		MOV	AH,3EH			;关闭文件
		INT	21H
		MOV	DI,OFFSET K_DISP	;参数表
		MOV	CX,32
L_S44:
		CALL	S_GETB			;取一参数
		STOSB
		LOOP	L_S44
		MOV	SI,OFFSET K_DISP
		MOV	DI,0F4H
		MOVSW
		MOVSW

		MOV	AX,6F1H
		MOV	SI,OFFSET K_AF1
		CMP	K_FCC,'Y'               ;仿长城键?
		JZ	L_S46
		MOV	SI,OFFSET D_JHJB	;交换键表
L_S46:
		MOV	[SI],AL
		INC	SI
		INC	AX
		DEC	AH
		JNZ	L_S46
L_S50:
		MOV	D_9680,CS

		MOV	BP,OFFSET D_BUF+768	;空768字节
		JMP	L_S60

;子程序:取INI一参数->AL
S_GETB		PROC	NEAR
		PUSH	CX
		LODSB				;取一字节
		CALL	S_TO10			;转十进制
		CMP	BYTE PTR [SI],' '       ;判下一字节为空格?
		JZ	L_GETB1
		MOV	CL,4
		SHL	AL,CL			;*16
		MOV	CL,AL
		LODSB				;再取一字节
		CALL	S_TO10			;转十进制
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
S_TO10: ;转十进制
		CMP	AL,'9'                  ;判数字?
		JBE	L_T1
		AND	AL,5FH			;小写变大写
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
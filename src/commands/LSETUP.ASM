;	LSETUP.ASM
;	1999.2.13, 11.14
DATE	EQU	"1999.11.29"

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

D_0		DW	204H			;主菜单位置
C_0		DW	1EH			;      颜色
A_0		DW	0F16H			;      大小

D_9		DW	201H			;功能键菜单位置
C_9		DW	6FH			;	   颜色
A_9		DW	101DH			;	   大小

D_9A		DW	21FH			;功能键表位置
C_9A		DW	6FH			;	 颜色
A_9A		DW	1030H			;	 大小

D_10		DW	420H			;打印机菜单位置
C_10		DW	2FH			;	   颜色
A_10		DW	0E14H			;	   大小

D_14		DW	20H			;显示参数菜单位置
C_14		DW	5FH			;	     颜色
A_14		DW	151AH			;	     大小

D_15		DW	41CH			;修改213L.BAT窗口位置
C_15		DW	34H			;		 颜色
A_15		DW	0A1AH			;		 大小

D_PR		DW	438H			;PR选择窗口位置
C_PR		DW	0FF6FH			;	   颜色
A_PR		DW	0C17H			;	   大小

D_PRNT		DW	438H			;PRNT选择窗口位置
C_PRNT		DW	0FF6FH			;	     颜色
A_PRNT		DW	0C13H			;	     大小

D_HELP		DW	1504H			;帮助窗口位置
C_HELP		DW	30H
A_HELP		DW	448H			;	 大小

D_IN		DW	1222H			;键入窗口位置
C_IN		DW	0FF71H			;	 颜色
A_IN		DW	32AH			;	 大小

D_XTPZ		DB	'2.13L 系统配置',0
F_INI		DB	'213L.INI',0
D_W		DB	0			;='W':修改当前目录下的INI文件
NOINI		DB	'系统配置文件 213L.INI 未找到!',7,13,10,'$'
MSG		DB	'2.13L 汉字系统配置程序 ',DATE,13,10
		DB	'格式: LSETUP [/W][/?]',13,10
		DB	'其中: /W - 处理当前目录的系统配置文件213L.INI',13,10
		DB	'           缺省:处理本程序所在目录的配置文件',13,10
		DB	'      /? - 显示说明',13,10,'$'

D_210A		DB	4, 0, 0, 0

D_SPCZ		DB	'双拼词组扩展区大小(0~9):',0,0
D_XTKG		DB	'1-左,2-右SHIFT,3-SCROLL LOCK:',0,0

D_MODE		DB	0			;显示方式号
D_ZJXP		DB	0			;=1直接写屏
D_CKBD		DW	0			;键盘模块段
D_HAN		DW	0			;文件号
D_SELE		DB	0			;主菜单默认选择号
D_DX		DW	0			;文件名首
D_CX		DW	0			;    长度
D_SX		DW	0			;    属性

D_B1		DB	0C9H,0CDH,0BBH,0
D_B2		DB	0BAH,20H,0BAH,0
D_B3		DB	0C8H,0CDH,0BCH,0

;主菜单
D_S1		DB	'设置存盘并退出    ',0
D_S2		DB	'不 存 盘 退 出    ',0
D_S3		DB	'是否仿长城键盘  Y ',0
D_S4		DB	'安装拼音码表？  Y ',0
D_S5		DB	'安装首尾码表？  N ',0
D_S6		DB	'安装电报码表？  N ',0
D_S7		DB	'双拼词组扩展区  1K',0
D_S8		DB	'功能开关SHIFT:  右',0
D_S9		DB	'选择功能键配置    ',0
D_S10		DB	'置显示模块参数    ',0
D_S11		DB	'修改文件213L.BAT  ',0,0

D_SB1		DB	'对系统配置的任何修改,必须存盘才可在重新启动汉字系统时有效!',0,0
D_SB2		DB	'本选择可取消所作的修改. 随时键入<ESC>也可.',0,0
D_SB3		DB	'101键盘光标键上方的  区位(Insert)  首  尾(Home)  拼音(PageUp)',0
		DB	'6个键仿长城的方式键  双拼(Delete)  全/半角(End)  英文(PageDn)',0,0
D_SB4		DB	'直接回车即可选择 Y-安装 或 N-不安装.',0
		DB	'  若不安装拼音码表,则双拼词组也将失效,输入方法则取消拼音和双拼.',0,0
D_SB5		DB	'直接回车即可选择 Y-安装 或 N-不安装.',0
		DB	'  若不安装首尾码表,则输入方法取消首尾.',0,0
D_SB6		DB	'直接回车即可选择 Y-安装 或 N-不安装.',0
		DB	'  若不安装电报码表,则输入方法取消电报.',0,0
D_SB7		DB	'本功能可选择双拼词组扩展区大小,范围0-9,单位为K字节.',0
		DB	'  若不安装双拼词组,选择双拼词组扩展区为0即可.',0,0
D_SB8		DB	'可选择系统功能键开关使用左或右SHIFT以及SCROLL LOCK键.',0,0
D_SB9		DB	'选择此功能,可任意配置系统功能键的键位.',0
		DB	'  执行此功能将显示二级菜单供进一步选择.',0,0
D_SB10		DB	'本功能可设置显示模块的一些重要工作参数.',0
		DB	'  以及提示行颜色的设置.',0,0
D_SB11		DB	'修改本系统启动批处理文件213L.BAT',0
		DB	'  可选择键盘模块、特显模块、打印驱动程序等.',0,0

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

C_DISP		DB	02H	;显示参数1
C_DISP2 	DB	01H	;	 2
C_DISP3 	DB	05H	;	 3
C_DISP4 	DB	39H	;	 4
		DB	00
C_TUXN1 	DB	1EH	;提示行内容1
C_TUXN2 	DB	1AH	;	   2
C_TUXB1 	DB	4EH	;提示行标题1颜色
C_TUXB2 	DB	4AH	;	   2
		DB	00
C_SHIFT 	DB	01H	;=1右,=2左
C_KEY		DB	64H	;中西文显示开关 CTRL+F7
		DB	68H	;区位码输入	ALT+F1
		DB	69H	;首尾码输入	ALT+F2
		DB	6AH	;拼音码输入	ALT+F3
		DB	6BH	;双拼码输入	ALT+F4
		DB	66H	;建立/取消纯中文CTRL+F9
		DB	6DH	;ASCII输入	ALT+F6
		DB	6CH	;五笔码输入	ALT+F5
		DB	71H	;电报码输入	ALT+F10
		DB	86H	;预选字输入	F12
		DB	85H	;联机帮助	F11
		DB	62H	;系统控制	CTRL+F5
		DB	70H	;定义双拼词组	ALT+F9
		DB	67H	;设置打印参数	CTRL+F10
		DB	00	;
		DB	00	;
C_FCC		DB	59H	;仿长城键盘	(Y或N)
C_SPKZ		DB	31H	;双拼词组扩展区 (1-9)
C_PY		DB	59H	;安装拼音码表	(Y或N)
C_SW		DB	4EH	;安装首尾码表	(Y或N)
C_DB		DB	4EH	;安装电报码表	(Y或N)

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
		CMP	AL,'W'                  ;处理当前目录INI
		JNZ	L_1
		MOV	D_W,AL
		JMP	SHORT L_1
L_10:
		XOR	BP,BP
		MOV	AH,2FH			;取键盘模块段
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

		CMP	D_W,'W'                 ;修改当前目录配置文件
		JNZ	L_20
		MOV	DX,OFFSET F_INI
		JMP	L_30
L_20:
		MOV	DS,DS:[2CH]		;环境段
		XOR	SI,SI
L_21:
		CMP	WORD PTR DS:[SI],0	;查找环境区尾?
		JZ	L_22
		INC	SI
		JMP	SHORT L_21
L_22:
		ADD	SI,4
		MOV	DI,OFFSET D_FILE	;带路径源文件名区
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
		MOV	D_DX,DX 		;保存
		MOV	AX,4300H		;取文件属性
		INT	21H
		JB	L_40
		MOV	D_SX,CX 		;保存
		MOV	CX,20H
		MOV	AX,4301H		;设置属性
		INT	21H

		MOV	AX,3D02H		;打开文件
		INT	21H
		JB	L_40
		MOV	D_HAN,AX		;文件号
		MOV	BX,AX
		MOV	DX,OFFSET B_BUF+100H	;读入地址
		MOV	CX,-1			;长度
		MOV	AH,3FH			;读
		INT	21H
		JNB	SHORT L_50
L_40:
		MOV	DX,OFFSET NOINI 	;'NOT FOUND FILE'
		MOV	AH,9
		INT	21H
		MOV	AL,-1
		JMP	L_END
L_50:
		MOV	D_CX,AX 		;文件长度
L_S0:
		MOV	SI,OFFSET B_BUF+100H
		MOV	DI,OFFSET C_DISP	;参数表
		MOV	CX,32
L_S0A:
		CALL	S_GETB			;取一参数
		STOSB
		LOOP	L_S0A

		CALL	S_CLS			;清屏
L_S00:
;写入主菜单状态
		MOV	AL,C_FCC		;仿长城键盘
		MOV	D_S3+16,AL
		MOV	AL,C_PY 		;拼音码表
		MOV	D_S4+16,AL
		MOV	AL,C_SW 		;首尾码表
		MOV	D_S5+16,AL
		MOV	AL,C_DB 		;电报码表
		MOV	D_S6+16,AL
		MOV	AL,C_SPKZ		;双拼词组扩展区大小
		MOV	D_S7+16,AL
		MOV	AX,'右'
		CMP	C_SHIFT,1		;右SHIFT
		JZ	L_S01
		MOV	AX,'左'
		CMP	C_SHIFT,2		;左SHIFT
		JZ	L_S01
		MOV	AX,'SL'
L_S01:
		MOV	D_S8+16,AH
		MOV	D_S8+17,AL

		MOV	DX,D_0			;主菜单位置
		MOV	BX,C_0			;      颜色
		MOV	CX,A_0			;      大小
		CALL	S_XSCK			;显示空窗口
		MOV	SI,OFFSET D_XTPZ	;总标题
		ADD	DX,104H
		MOV	BL,4EH
		CALL	S_XSZFC
		MOV	SI,OFFSET D_S1		;提示串首
		MOV	DX,D_0
		ADD	DX,302H 		;位置
		MOV	BX,C_0			;颜色
		CALL	S_CKXS			;显示

		MOV	SI,OFFSET D_S1		;菜单首
		MOV	BP,OFFSET D_SBZ1	;帮助指针
		MOV	BH,19			;项长
		MOV	CH,10			;项数-1
		MOV	CL,D_SELE		;初号
		CALL	S_CDKZ			;菜单控制
		MOV	D_SELE,AL		;选择号
;----------------------------------------------------------------------------
		CMP	AL,0			;**设置存盘**
		JNZ	L_S2
		MOV	SI,OFFSET C_DISP	;参数表
		MOV	DI,OFFSET B_BUF+100H
		MOV	CX,32
L_S1A:
		LODSB
		CALL	S_SETB			;写入参数
		LOOP	L_S1A

		MOV	BX,D_HAN		;文件号
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4200H		;移动读写指针
		INT	21H
		MOV	DX,OFFSET B_BUF+100H	;写入地址
		MOV	CX,D_CX 		;长度
		MOV	AH,40H			;写盘
		INT	21H
		MOV	AH,3EH			;关闭
		INT	21H
L_S1B:
		MOV	DX,D_DX
		MOV	CX,D_SX
		MOV	AX,4301H		;恢复原属性
		INT	21H

		MOV	AX,1813H
		INT	10H
		CALL	S_KGB
		XOR	AL,AL
L_END:
		MOV	AH,4CH			;退出
		INT	21H
;----------------------------------------------------------------------------
L_S2:
		CMP	AL,1			;**不存盘**
		JZ	L_S1B
		CMP	AL,1BH			;<ESC>同AL=1
		JZ	L_S1B
;----------------------------------------------------------------------------
L_S3:
		CMP	AL,2			;**仿长城键盘**
		JNZ	L_S4
		MOV	AL,'Y'
		CMP	AL,C_FCC		;判?
		JNZ	L_S3A
		MOV	AL,'N'
L_S3A:
		MOV	C_FCC,AL

		CMP	AL,'N'                  ;不仿长城?
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
		CMP	AL,3			;**拼音码表**
		JNZ	L_S5
		MOV	BX,OFFSET C_PY
L_S4A:
		MOV	AL,'Y'
		CMP	AL,[BX] 		;判原'Y'?
		JNZ	L_S4B
		MOV	AL,'N'
L_S4B:
		MOV	[BX],AL 		;写入
		JMP	L_S00
;----------------------------------------------------------------------------
L_S5:
		CMP	AL,4			;**首尾码表**
		JNZ	L_S6
		MOV	BX,OFFSET C_SW
		JMP	L_S4A
;----------------------------------------------------------------------------
L_S6:
		CMP	AL,5			;**电报码表**
		JNZ	L_S7
		MOV	BX,OFFSET C_DB
		JMP	L_S4A
;----------------------------------------------------------------------------
L_S7:
		CMP	AL,6			;**双拼词组扩展区**
		JNZ	L_S8
		MOV	SI,OFFSET D_SPCZ	;'双拼词组扩展区大小:'
		CALL	S_INKEY 		;显示并键入->AL
		CMP	AL,0DH
		JZ	L_S7A
		MOV	C_SPKZ,AL		;写入
L_S7A:
		JMP	L_S00
;----------------------------------------------------------------------------
L_S8:
		CMP	AL,7			;**选择系统功能开关键**
		JNZ	L_S9
		MOV	SI,OFFSET D_XTKG	;'系统功能开关键..'
		CALL	S_INKEY 		;显示并键入->AL
		CMP	AL,'1'                  ;判123?
		JB	L_S8B
		CMP	AL,'3'
		JA	L_S8B
		AND	AL,0FH
		CMP	AL,3			;判SCROOL LOCK?
		JNZ	L_S8A
		MOV	AL,16
L_S8A:
		MOV	C_SHIFT,AL		;存
L_S8B:
		JMP	L_S00
;----------------------------------------------------------------------------
L_S9:
		CMP	AL,8			;**设置功能键**
		JNZ	L_S10
		JMP	L_JPCS
;----------------------------------------------------------------------------
L_S10:
		CMP	AL,9			;**显示模块参数**
		JNZ	L_S11
		JMP	L_XSCS
;----------------------------------------------------------------------------
L_S11:
		CMP	AL,10			;**修改213L.BAT**
		JNZ	L_S11A
		JMP	L_BAT
L_S11A:
		JMP	L_S00

;==功能键配置================================================================
D_PV		DB	'2.13L 功能键配置',0
D_PV1		DB	'功   能   键   表',0
D_PV0		DB	'CTRL+F7   1-中/西文显示开关',0
		DB	'ALT+F1    2-区位码输入     ',0
		DB	'ALT+F2    3-首尾码输入     ',0
		DB	'ALT+F3    4-拼音码输入     ',0
		DB	'ALT+F4    5-双拼码输入     ',0
		DB	'CTRL+F9   6-建立/取消纯中文',0
		DB	'ALT+F6    7-ASCII码输入    ',0
		DB	'ALT+F5    8-五笔字型输入   ',0
		DB	'ALT+F10   9-电报码输入     ',0
		DB	'F12      10-预选字输入     ',0
		DB	'F11      11-联机帮助       ',0
		DB	'CTRL+F5  12-系统控制       ',0
		DB	'ALT+F9   13-定义双拼词组   ',0
		DB	'CTRL+F10 14-设置打印参数   ',0,0

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
		DB	'8BH-ALT+F11    8CH-ALT+F12    8DH-CTRL+↑   ',0
		DB	'               (扩展ASCII码-功能键名称)     ',0,0

D_PVB1		DB	'可切换汉字方式和西文方式的显示,但汉字显示模块还起作用.',0,0
D_PVB2		DB	'可用四位区位码输入汉字,也可键入区号再打空格,按区位顺序显示并选择.',0,0
D_PVB3		DB	'可用首尾码输入汉字.',0,0
D_PVB4		DB	'可用全拼码、简拼码(除zh-V外同CCDOS)或双拼码输入汉字.',0,0
D_PVB5		DB	'可用双拼码或双拼加部首码输入汉字,或打四键直接上词.',0
		DB	'  普通操作者可大大加快汉字输入速度.郑重推荐此输入法!',0,0
D_PVB6		DB	'建立纯中文方式,键入的字符将得到对应三区的图形符号.',0,0
D_PVB7		DB	'取消所有汉字输入法,恢复英文输入.',0
		DB	'  若不保持显示提示行,则将清除提示行.',0,0
D_PVB8		DB	'可用五笔字型方式输入汉字和词组.必须安装WBX模块',0,0
D_PVB9		DB	'可用电报码输入汉字.',0,0
D_PVB10 	DB	'可预选一批汉字或图形符号供选择输入.输入请用大写字母.',0
		DB	'  系统提供有常用九区制表符、常用符号、汉字数字的三页预选字.',0,0
D_PVB11 	DB	'执行联机帮助,提供系统信息.',0
		DB	'  需在DOS下先执行LHELP',0,0
D_PVB12 	DB	'可用提示行菜单方式对系统进行控制.参看README有关说明.',0,0
D_PVB13 	DB	'可在现场直接定义双拼词组,并可立即使用.',0
		DB	'  若要存盘,应在DOS下执行CSP保存双拼词组.',0,0
D_PVB14 	DB	'可设置如下打印参数:字型、行距、字符间距、左边空、行宽、单双向打印.',0
		DB	'  还可关闭或恢复特殊打印功能、关闭或恢复汉字打印驱动模块.',0,0

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
		CALL	S_CLS			;清屏
		PUSH	CS
		POP	ES
L_S81:
		MOV	BP,OFFSET D_PV0 	;提示串首
		MOV	SI,OFFSET C_KEY 	;功能键地址
		MOV	CX,14			;个数
L_S811:
		LODSB				;取各功能键
		CALL	S_SET
		ADD	BP,28
		LOOP	L_S811

		MOV	DX,D_9A
		MOV	BX,C_9A
		MOV	CX,A_9A
		CALL	S_XSCK
		MOV	SI,OFFSET D_PV1 	;'功能键表'
		ADD	DX,0EH			;位置
		MOV	BL,4EH			;颜色
		CALL	S_XSZFC 		;显示
		MOV	SI,OFFSET D_GNJTS	;功能键表
		MOV	BX,C_9A 		;颜色
		MOV	DX,D_9A
		ADD	DX,101H
		CALL	S_CKXS			;显示

		MOV	DX,D_9
		MOV	BX,C_9
		MOV	CX,A_9
		CALL	S_XSCK
		MOV	SI,OFFSET D_PV		;'功能键配置'
		ADD	DX,7			;位置
		MOV	BL,4EH			;颜色
		CALL	S_XSZFC 		;显示
L_S82:
		MOV	SI,OFFSET D_PV0 	;当前设置
		MOV	BX,C_9			;颜色
		MOV	DX,D_9
		ADD	DX,101H 		;位置
		CALL	S_CKXS			;显示
		MOV	SI,OFFSET D_PV0 	;菜单首
		MOV	BP,OFFSET D_PVZ1	;帮助指针
		MOV	BH,28			;项长
		MOV	CH,13			;项数-1
		MOV	CL,D_YH 		;默认号
		CALL	S_CDKZ			;菜单控制
		CMP	AL,1BH			;<ESC>返回主菜单
		JNZ	L_S821
		JMP	L_S0
L_S821:
		CMP	BYTE PTR DS:[DI],' '    ;判仿长城功能键?
		JNZ	L_S83
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_S82
L_S83:
		CBW
		ADD	AX,OFFSET C_KEY 	;选定键地址
		MOV	DI,AX
		MOV	AL,[DI] 		;取键值
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
		MOV	D_YW,CX 		;功能键表CH=行,CL=列
		CALL	S_CD1			;以红底白字显示
L_S84:
		XOR	AH,AH			;键入选择
		INT	16H
		OR	AL,AL			;判功能键?
		JNZ	L_S88
		CMP	AH,48H			;↑
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
		CMP	AH,50H			;↓
		JNZ	L_S86
		CMP	CH,15
		JNZ	L_S851
		XOR	CH,CH
		JMP	SHORT L_S842
L_S851:
		INC	CH
		JMP	SHORT L_S842
L_S86:
		CMP	AH,4BH			;←
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
		CMP	AH,4DH			;→
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
		CMP	AL,0DH			;回车选中?
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
		MOV	[DI],AL 		;写入
L_S883:
		JMP	L_S81
L_S89:
		CMP	AL,1BH			;<ESC>返回主菜单
		JNZ	L_S883
		JMP	L_S0
;----------------------------------------------------------------------------
D_YW		DW	0
;子程序:显示菜单
S_CD		PROC	NEAR
		MOV	DX,D_YW 		;原位
		MOV	BX,C_9A
		CALL	S_CD2			;恢复
S_CD1:
		MOV	DX,CX			;现位
		MOV	D_YW,DX
		MOV	BL,70H			;红底黄字
S_CD2:
		MOV	AL,3
		MUL	DH
		ADD	AL,DL			;顺序号
		MOV	AH,15
		MUL	AH
		ADD	AX,OFFSET D_GNJTS
		MOV	BP,AX			;显示字符串首
		MOV	AL,15
		MUL	DL
		MOV	DL,AL
		ADD	DX,D_9A
		ADD	DX,101H
		PUSH	CX
		MOV	CX,15
		CALL	S_XSZFI 		;显示
		POP	CX
		RET
;子程序:显示字符串DS:BP,CX=长度,DX=位置,BL=属性
S_XSZFI:
		MOV	BH,DS:[BP]		;取字符
		INC	BP
		CALL	S_XSZF
		LOOP	S_XSZFI
		RET
S_CD		ENDP
;----------------------------------------------------------------------------
;子程序:写入功能键名
S_SET		PROC	NEAR
		PUSH	SI
		CMP	AL,0F0H 		;仿长城键?
		JB	L_SET3
		MOV	AL,9			;空
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
		REP	MOVSB			;写入键名
		POP	CX
		POP	SI
		RET
S_SET		ENDP

;==显示模块参数==============================================================
D_XS0		DB	'2.13L 显示模块参数设置',0
D_XS1		DB	'使用扩展字符库(Y／N) N',0
D_XS2		DB	'支持直接写屏？(Y／N) Y',0
D_XS3		DB	'显示方式>5即显示汉字 N',0
D_XS4		DB	'提示行光带颜色(0－9) 9',0
D_XS5		DB	'显示系统信息？(Y／N) Y',0
D_XS6		DB	'光标下移２线？(Y／N) N',0
D_XS7		DB	'CGA调色板开关?(Y／N) N',0
D_XS8		DB	'取消屏幕分割？(Y／N) N',0
D_XS9		DB	'保持显示提示行(Y／N) Y',0
D_XS10		DB	'可变或固定光标(Y／N) Y',0
D_XS11		DB	'初始属性寄存器(Y／N) Y',0
D_XS12		DB	'图形方式打开B8(Y／N) N',0
D_XS13		DB	'显示中断调BIOS(Y／N) N',0
D_XS14		DB	'提示行内容１颜色 － 1E',0
D_XS15		DB	'提示行内容２颜色 － 1A',0
D_XS16		DB	'提示行标题１颜色 － 4E',0
D_XS17		DB	'提示行标题２颜色 － 4A',0,0

D_GDS		DB	'请键入提示行光带颜色号(0-9):',0,0
D_AL1		DB	0

D_XSB1		DB	'Y可使用外加的扩展字符库(长城显示字符体.要多占内存4K).',0
		DB	'N直接使用VGA卡上的字符库.',0,0
D_XSB2		DB	'支持直接写屏,大多数西文字符型软件毋需汉化即可使用汉字.',0
		DB	'  支持VGA、EGA和HGA(双频单显)卡.',0,0
D_XSB3		DB	'Y-若设置显示方式号大于5时就可显示汉字(主要用于汉化软件等).',0
		DB	'N-设置什么显示方式就可进入所设的显示方式.可直接运行几乎所有程序.',0,0
D_XSB4		DB	'在TVGA或与之兼容的显示卡并使用VGA模块时,提示行上下将有二条光带.',0
		DB	'  本功能可设置此光带的颜色,范围0-9.当设置为0时将取消光带.',0,0
D_XSB5		DB	'可打开或关闭启动本汉字系统时显示的系统信息.',0,0
D_XSB6		DB	'使用VGA模块时,可将光标显示在行间的两条线上.',0,0
D_XSB7		DB	'显示中断INT10H中AH=0BH设置CGA调色板处理:调BIOS或直接返回.',0
		DB	'  一般情况下应设置为N.',0,0
D_XSB8		DB	'在某些SVGA显示的机器上直接写屏可能显示混乱,可打开此功能一试.',0,0
D_XSB9		DB	'可保持提示行打开状态,以随时了解当前汉字输入状态.',0
		DB	'  若不保持提示行打开,则可随时关闭提示行,处理图形图象时特别需要.',0,0
D_XSB10 	DB	'默认光标大小可由软件控制(Y),如DOS下和EDIT或PE编辑中插入和修改状态.',0
		DB	'  也可设置成固定光标为2线(N)',0,0
D_XSB11 	DB	'在进入INT10中断时初始化属性寄存器,可保证汉字方式下显示正常.',0,0
D_XSB12 	DB	'设置图形显示方式(VGA为12H,EGA为10H)打开B800H段.',0
		DB	'  可在VGA和EGA使用显示缓冲区安装双拼词组等.',0,0
D_XSB13 	DB	'Y-显示中断中显示字符和滚屏幕直接调BIOS.在C、PASCAL和LIST等滚屏正常.',0
		DB	'N-上述功能由本系统显示模块处理(安装默认状态)',0,0
D_XSB14 	DB	'内容就是提示行显示的重码字或词(字本身和词的序号).',0,0
D_XSB15 	DB	'内容就是提示行显示的重码字或词(词本身和字的序号).',0,0
D_XSB16 	DB	'标题就是提示行左端显示的汉字输入法等(对外显示为图形时).',0,0
D_XSB17 	DB	'标题就是提示行左端显示的汉字输入法等(对外显示为字符时).',0,0

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
D_INPUT 	DB	'请键入:',0,0
D_INPBUF	DB	0,0,0

L_XSCS:
		MOV	SI,OFFSET C_DISP	;显示模块参数首
		LODSB
		MOV	AH,'Y'
		TEST	AL,1			;=1使用扩展字符库
		JNZ	L_XS1
		MOV	AH,'N'
L_XS1:
		MOV	D_XS1+21,AH
		MOV	AH,'Y'
		TEST	AL,2			;=1关闭提示行
		JNZ	L_XS1A
		MOV	AH,'N'
L_XS1A:
		MOV	D_XS9+21,AH
		MOV	AH,'Y'
		TEST	AL,8			;=1不显示系统信息
		JZ	L_XS2
		MOV	AH,'N'
L_XS2:
		MOV	D_XS5+21,AH

		LODSB
		MOV	AH,'Y'
		TEST	AL,1			;=1支持直接写屏
		JNZ	L_XS3
		MOV	AH,'N'
L_XS3:
		MOV	D_XS2+21,AH		;10.24
		MOV	AH,'Y'
		TEST	AL,2			;=1图形方式打开B8
		JNZ	L_XS3A
		MOV	AH,'N'
L_XS3A:
		MOV	D_XS12+21,AH
		MOV	AH,'Y'
		TEST	AL,4			;=1显示中断调BIOS
		JNZ	L_XS3B
		MOV	AH,'N'
L_XS3B:
		MOV	D_XS13+21,AH
		MOV	AH,'Y'
		TEST	AL,8			;=1光标下移2线
		JNZ	L_XS4
		MOV	AH,'N'
L_XS4:
		MOV	D_XS6+21,AH

		LODSB
		MOV	AH,'Y'
		TEST	AL,1			;=1显示方式>5即汉字
		JZ	L_XS5
		MOV	AH,'N'
L_XS5:
		MOV	D_XS3+21,AH
		MOV	AH,'Y'
		TEST	AL,2			;=1可变光标
		JZ	L_XS5A
		MOV	AH,'N'
L_XS5A:
		MOV	D_XS10+21,AH
		MOV	AH,'Y'
		TEST	AL,4			;=1初始化属性寄存器
		JNZ	L_XS5B
		MOV	AH,'N'
L_XS5B:
		MOV	D_XS11+21,AH
		MOV	AH,'Y'
		TEST	AL,8			;=1CGA调色板调BIOS
		JNZ	L_XS6
		MOV	AH,'N'
L_XS6:
		MOV	D_XS7+21,AH

		LODSB
		CMP	AL,'0'
		JB	L_XS7
		CMP	AL,'9'                  ;提示行光带色
		JA	L_XS7
		MOV	D_XS4+21,AL
		JMP	SHORT L_XS8
L_XS7:
		MOV	D_XS4+21,' '
L_XS8:
		MOV	AH,'Y'
		CMP	AL,'9'                  ;取消屏幕分割
		JA	L_XS9
		MOV	AH,'N'
L_XS9:
		MOV	D_XS8+21,AH

		MOV	SI,OFFSET C_TUXN1	;提示行颜色串首
		MOV	DI,OFFSET D_XS14+20	;写入位置
		MOV	CX,4
L_XS9A:
		LODSB
		CALL	S_16
		MOV	WORD PTR DS:[DI],AX	;写入
		ADD	DI,23
		LOOP	L_XS9A

		MOV	DX,D_14 		;
		MOV	BX,C_14
		MOV	CX,A_14
		CALL	S_XSCK
		MOV	SI,OFFSET D_XS0 	;显示标题
		ADD	DX,102H 		;位置
		MOV	BL,4EH			;颜色
		CALL	S_XSZFC 		;显示菜单
		MOV	SI,OFFSET D_XS1 	;显示菜单
		MOV	DX,D_14
		ADD	DX,302H 		;位置
		MOV	BX,C_14 		;颜色
		CALL	S_CKXS			;显示菜单

		MOV	SI,OFFSET D_XS1 	;菜单首
		MOV	BP,OFFSET D_XSZ1	;帮助指针
		MOV	BH,23			;项长
		MOV	CH,16			;项数-1
		MOV	CL,D_AL1		;初始号
		CALL	S_CDKZ			;菜单控制
		CMP	AL,1BH			;<ESC>返回主菜单
		JNZ	L_XS10
		MOV	DX,D_14 		;
		MOV	BX,11H
		MOV	CX,A_14
		CALL	S_XSCK
		JMP	L_S00
L_XS10:
		MOV	D_AL1,AL		;存选择号

		CMP	AL,0			;<使用扩展字符库>
		JNZ	L_XS20
		XOR	C_DISP,1
		JMP	L_XSCS
L_XS20:
		CMP	AL,1			;<支持直接写屏>
		JNZ	L_XS30
		XOR	C_DISP2,1
		JMP	L_XSCS
L_XS30:
		CMP	AL,2			;<显示方式>5即汉字>
		JNZ	L_XS40
		XOR	C_DISP3,1
		MOV	AL,14
		TEST	C_DISP3,1
		JZ	L_XS33
		MOV	AL,15
L_XS33:
		MOV	AH,18H			;执行
		INT	10H
		JMP	L_XSCS
L_XS40:
		CMP	AL,3			;<提示行光带色>
		JNZ	L_XS50
		MOV	SI,OFFSET D_GDS 	;'提示行光带颜色号(0-9):'
		CALL	S_INKEY 		;显示并键入字符
		CMP	AL,'0'
		JB	L_XS41
		CMP	AL,'9'
		JA	L_XS41
		MOV	C_DISP4,AL		;写入
		MOV	BL,AL
		MOV	AX,1405H		;执行
		INT	10H
L_XS41:
		JMP	L_XSCS
L_XS50:
		CMP	AL,4			;<显示系统信息>
		JNZ	L_XS60
		XOR	C_DISP,8
		JMP	L_XSCS
L_XS60:
		CMP	AL,5			;<光标下移2线>
		JNZ	L_XS70
		XOR	C_DISP2,8
		JMP	L_XSCS
L_XS70:
		CMP	AL,6			;<CGA调色板>
		JNZ	L_XS80
		XOR	C_DISP3,8
		JMP	L_XSCS
L_XS80:
		CMP	AL,7			;<取消屏幕分割>
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
		CMP	AL,8			;<关闭提示行>
		JNZ	L_XS95
		XOR	C_DISP,2
		JMP	L_XSCS
L_XS95:
		CMP	AL,9			;<可变或固定光标>
		JNZ	L_XS100
		XOR	C_DISP3,2
		MOV	BH,1
		TEST	C_DISP3,2
		JZ	L_XS96
		MOV	BX,2
L_XS96:
		MOV	AX,180DH		;执行
		INT	10H
		JMP	L_XSCS
L_XS100:
		CMP	AL,10			;<INT10初始化属性寄存器>
		JNZ	L_XS110
		XOR	C_DISP3,4
		JMP	L_XSCS
L_XS110:
		CMP	AL,11			;<图形方式打开B8>
		JNZ	L_XS120
		XOR	C_DISP2,2
		JMP	L_XSCS
L_XS120:
		CMP	AL,12			;<显示中断调BIOS>
		JNZ	L_XS130
		XOR	C_DISP2,4
L_XS130:
		CMP	AL,13			;<提示行内容1颜色>
		JNZ	L_XS140
		CALL	S_INCOLOR		;键入十六进制颜色值
		JB	L_XS133
		MOV	C_TUXN1,AL
L_XS133:
		JMP	L_XSCS
L_XS140:
		CMP	AL,14			;<提示行内容2颜色>
		JNZ	L_XS150
		CALL	S_INCOLOR		;键入十六进制颜色值
		JB	L_XS144
		MOV	C_TUXN2,AL
L_XS144:
		JMP	L_XSCS
L_XS150:
		CMP	AL,15			;<提示行标题1颜色>
		JNZ	L_XS160
		CALL	S_INCOLOR		;键入十六进制颜色值
		JB	L_XS155
		MOV	C_TUXB1,AL
L_XS155:
		JMP	L_XSCS
L_XS160:
		CMP	AL,16			;<提示行标题2颜色>
		JNZ	L_XS170
		CALL	S_INCOLOR		;键入十六进制颜色值
		JB	L_XS166
		MOV	C_TUXB2,AL
L_XS166:
		JMP	L_XSCS
L_XS170:
		JMP	L_XSCS

;==修改213L.BAT==============================================================
D_XGBAT 	DB	'修改213L.BAT',0
D_XG1		DB	'选择特显模块(K,V,0):  ',0
D_XG2		DB	'选择打印模块  (N,H):  ',0
D_XG3		DB	'选择HP支持的打印机号  ',0
D_XG4		DB	'选择NT支持的打印机号  ',0
D_XG5		DB	'读打印字库方式(n,W):  ',0
D_XG6		DB	'存盘:存文件 213L.BAT  ',0,0

D_XGB1		DB	'可选K(INT10K)或V(INT10V).若选0则不驻留特显模块.',0,0
D_XGB2		DB	'回车选择打印机驱动程序:N-PRNT,H-PRTH.',0
		DB	'    选择后还要继续选择打印机号.',0,0
D_XGB3		DB	'已经选择了支持激光和喷墨打印机的PRTH可再次选择打印机号.',0,0
D_XGB4		DB	'已经选择了支持24针打印机的PRNT可再次选择打印机号.',0,0
D_XGB5		DB	'n-读字库模块READ24,READ32,READ40和READSL使用INT13中断直接读字库扇区.',0
		DB	'W-上述模块用文件方式读字库(用于压缩盘、光盘或网络服务器)',0,0
D_XGB6		DB	'将修改的结果保存到文件 C:\213L.BAT.',0,0

D_XGZ1		DW	OFFSET D_XGB1
D_XGZ2		DW	OFFSET D_XGB2
D_XGZ3		DW	OFFSET D_XGB3
D_XGZ4		DW	OFFSET D_XGB4
D_XGZ5		DW	OFFSET D_XGB5
D_XGZ6		DW	OFFSET D_XGB6

D_PRTH		DB	'PRTH 打印机选择',0
D_PRTHB 	DB	'10 : HP-2            ',0
		DB	'11 : HP-3            ',0
		DB	'13 : PECAN 300DPI    ',0
		DB	'14 : PECAN 400DPI    ',0
		DB	'16 : HP JET 500      ',0
		DB	'19 : 佳能 LBP-8II    ',0
		DB	'20 : 北佳仿真HP400DPI',0
		DB	'21 : XP-11-B4 400Dpi ',0
		DB	'22 : XP-11-A4 400DPI ',0
		DB	'23 : 佳能 BJ-10ex    ',0,0

D_PRTHB1	DB	'用光标键上下选择打印机,回车选中',0,0

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

D_PRNT1 	DB	'PRNT 打印机选择',0
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

D_PRNTB1	DB	'AR3240: 还可用于CR3240、3200打印机.',0,0
D_PRNTB2	DB	'P1351: 还可用于P1351、P350彩色打印机.',0,0
D_PRNTB3	DB	'M2024: 还可用于M1724、M1924打印机.',0,0
D_PRNTB4	DB	'TH3070: 还可用于KC3070、紫金3070和3080系列打印机.',0,0
D_PRNTB5	DB	'AR2463',0,0
D_PRNTB6	DB	'LQ1500: 还可用于其他LQ系列、NEC P7、VP8624以及与EPSON兼容的打印机.',0,0
D_PRNTB7	DB	'OKI8320: 还可用于其他OKI系列24针打印机.',0,0
D_PRNTB8	DB	'M1570',0,0
D_PRNTB9	DB	'NEC3824: 还可用于NEC P5打印机.',0,0
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
D_END		DW	0			;文件尾地址
NO213L		DB	'未找到批处理文件C:\213L.BAT!',0
NOCKB		DB	'批处理文件C:\213L.BAT中无键盘模块!',0
NOCCDISP	DB	'批处理文件C:\213L.BAT中无CCDISP行',0
NOPRTH		DB	'批处理文件C:\213L.BAT中无PRTH行',0
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
K_INT10 	DB	'请选择(K,V,0):',0
K_READ24	DB	'请选择(1-9,W):',0
;----------------------------------------------------------------------------
L_BAT:
		MOV	DX,OFFSET D_BAT 	;'C:\213L.BAT'
		MOV	AX,3D02H		;打开文件
		INT	21H
		JNB	L_BAT1
		MOV	SI,OFFSET NO213L
L_BAT2B:
		MOV	DX,D_15
		ADD	DX,102H
		MOV	BL,4EH
		CALL	S_XSZFC 		;显示字符串
		MOV	AX,0E07H		;响铃
		INT	10H
		XOR	AH,AH			;按键
		INT	16H
		JMP	L_S0
L_BAT1:
		MOV	BX,AX
		MOV	H_BAT,AX
		MOV	DX,OFFSET B_BUF
		MOV	SI,DX
		MOV	CX,-1
		MOV	AH,3FH			;读文件
		INT	21H
		ADD	SI,AX
		CMP	BYTE PTR [SI-1],1AH	;文本文件结束标志
		JZ	L_BAT2
		MOV	BYTE PTR [SI],1AH	;置标志
		INC	SI
L_BAT2:
		MOV	D_END,SI		;文件尾
L_BAT2A:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_INT10	;'INT10'
		CALL	S_SCAN			;查找
		MOV	AL,' '
		JB	L_BAT4
		MOV	AL,[BX+5]		;'INT10'后字符
L_BAT4:
		MOV	D_XG1+21,AL

		MOV	D_XG2+21,' '
		MOV	WORD PTR D_XG3+20,'  '
		MOV	D_XG4+21,' '
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PR		;'PR '
		CALL	S_SCAN			;查找
		JB	L_BAT7
		MOV	D_XG2+21,'H'
		MOV	AX,[BX+3]		;打印机号
		CMP	AH,0DH
		JNZ	L_BAT6
		MOV	AH,' '
L_BAT6:
		MOV	WORD PTR D_XG3+20,AX
		JMP	SHORT L_BAT8
L_BAT7:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRNT	;'PRNT'
		CALL	S_SCAN			;查找
		MOV	AL,' '
		JB	L_BAT8
		MOV	D_XG2+21,'N'
		MOV	AL,[BX+5]		;打印机号
		MOV	D_XG4+21,AL
L_BAT8:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_READ24	;'READ24'
		CALL	S_SCAN			;查找
		JB	L_BAT9
		MOV	AL,[BX+7]		;READ24后的字符
		MOV	D_XG5+21,AL
L_BAT9:
		MOV	DX,D_15
		MOV	BX,C_15
		MOV	CX,A_15
		CALL	S_XSCK			;显示空窗口
		MOV	SI,OFFSET D_XGBAT
		ADD	DX,107H
		MOV	BL,4EH
		CALL	S_XSZFC 		;显示标题
L_BAT10:
		MOV	SI,OFFSET D_XG1
		MOV	DX,D_15
		ADD	DX,302H
		MOV	BX,C_15
		CALL	S_CKXS			;显示窗口内容

		MOV	SI,OFFSET D_XG1 	;菜单首
		MOV	BP,OFFSET D_XGZ1	;帮助指针
		MOV	BH,23			;项长
		MOV	CH,5			;项数-1
		MOV	CL,D_SELE15		;初号
		CALL	S_CDKZ			;菜单控制

		CMP	AL,1BH			;<ESC>?
		JNZ	L_BAT12
		MOV	BX,H_BAT
		MOV	AH,3EH
		INT	21H
L_BAT11:
		MOV	DX,D_15
		MOV	BX,11H
		MOV	CX,A_15
		CALL	S_XSCK			;清窗口
		JMP	L_S00
L_BAT12:
		MOV	D_SELE15,AL		;选择号

		CMP	AL,0			;<INT10?>
		JNZ	L_BAT30
		MOV	SI,OFFSET K_INT10
		CALL	S_INKEY 		;键入字符
		CMP	AL,'0'
		JB	L_BAT22
		JZ	L_BAT21
		AND	AL,5FH
L_BAT21:
		MOV	DL,AL

		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_INT10	;'INT10'
		CALL	S_SCAN			;查找
		JB	L_BAT24
		CMP	DL,'0'                  ;无?
		JZ	L_BAT23
		CMP	DL,[BX+5]		;判?
		JZ	L_BAT22
		MOV	[BX+5],DL		;写入
L_BAT22:
		JMP	L_BAT2A
L_BAT23:
		MOV	DI,BX
		MOV	CX,8
		CMP	BYTE PTR [DI-1],' '     ;前有空格(LH)
		JNZ	L_BAT23A
		SUB	DI,3
		ADD	CX,3
L_BAT23A:
		CALL	S_DELBAT		;清该行
		JMP	L_BAT2A
L_BAT24:
		CMP	DL,'0'                  ;无?
		JZ	L_BAT22
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_CCDISP	;'CCDISP'
		CALL	S_SCAN			;查找
		JNB	L_BAT24A
		MOV	SI,OFFSET NOCCDISP
		JMP	L_BAT2B
L_BAT24A:
		MOV	SI,BX
L_BAT25:
		LODSB
		CMP	AL,0DH			;判行尾?
		JZ	L_BAT26
		CMP	AL,0AH
		JNZ	L_BAT25
L_BAT26:
		LODSB				;下行首

		MOV	DI,OFFSET F_INT10+1
		MOV	[DI+5],DL
		MOV	CX,8
		CALL	S_INBUF 		;写入一行
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
		CALL	S_SCAN			;查找
		JB	L_BAT50
		CMP	DL,'N'                  ;改PRNT?
		JNZ	L_BAT49
		MOV	WORD PTR [BX+2],'TN'    ;改'NT'
		MOV	SI,BX
		ADD	SI,4
		MOV	DI,OFFSET D_PRNTB+14
		MOV	CX,2
		CALL	S_INBUF 		;写入'  '
		CALL	S_PRNT			;PRNT选打印机
L_BAT47:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PR		;3,'PR '
		CALL	S_SCAN			;查找
		JB	L_BAT49
		MOV	CX,7
		CMP	BYTE PTR [BX+4],0DH
		JNZ	L_BAT48
		MOV	CL,6
L_BAT48:
		MOV	DI,BX
		CALL	S_DELBAT		;删PR行
L_BAT49:
		JMP	L_BAT2A
L_BAT50:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRNT	;'PRNT'----------------------
		CALL	S_SCAN			;查找
		JB	L_BAT64
		CMP	DL,'H'                  ;改PRTH?
		JNZ	L_BAT54
		MOV	DI,BX
		ADD	DI,4
		MOV	CX,2
		CALL	S_DELBAT		;删打印机号
		MOV	WORD PTR [BX+2],'HT'    ;改'TH'
		CALL	S_INPR			;插入PR行
L_BAT54:
		JMP	L_BAT2A
L_BAT60:
		CMP	AL,2			;<PR选打印机>
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
		CMP	AL,3			;<PRNT选打印机>
		JNZ	L_BAT80
		CMP	D_XG3+21,'N'
		JNZ	L_BAT64
		CALL	S_PRNT
L_BAT69:
		JMP	L_BAT2A
L_BAT70:
		CMP	AL,5			;<存盘>
		JNZ	L_BAT69
		MOV	BX,H_BAT		;文件号
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4200H		;移文件头
		INT	21H
		MOV	DX,OFFSET B_BUF
		MOV	CX,D_END
		SUB	CX,DX
		MOV	AH,40H			;写入
		INT	21H
		MOV	AH,3EH			;关闭
		INT	21H
		JMP	L_BAT11 		;关窗口返主菜单
L_BAT80:
		CMP	AL,4			;<READ24选W>
		JNZ	L_BAT70
		MOV	SI,OFFSET K_READ24
		CALL	S_INKEY 		;键入字符
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
		CALL	S_SCAN			;查找
		JB	L_BAT83
		CALL	S_24W
L_BAT83:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_READ32	;'READ32'
		CALL	S_SCAN			;查找
		JB	L_BAT84
		CALL	S_24W
L_BAT84:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_READ40	;'READ40'
		CALL	S_SCAN			;查找
		JB	L_BAT85
		CALL	S_24W
L_BAT85:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_READSL	;'READSL'
		CALL	S_SCAN			;查找
		JB	L_BAT86
		CALL	S_24W
L_BAT86:
		JMP	L_BAT2A

;子程序:READ24W处理
S_24W		PROC	NEAR
		CMP	BYTE PTR [BX+6],0DH	;命令名后无参数?
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

;子程序:选择PR
S_PR		PROC	NEAR
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PR		;'PR '
		CALL	S_SCAN			;查找
		JNB	L_PR1
		RET
L_PR1:
		MOV	AX,[BX+3]		;打印机号
		MOV	SI,OFFSET D_PRTHB	;	表
		XOR	CX,CX
L_PR2:
		CMP	AH,0DH
		JZ	L_PR2A
		CMP	AX,[SI]
		JZ	L_PR3
		JMP	SHORT L_PR2B
L_PR2A:
		CMP	AL,[SI] 		;判?
		JZ	L_PR3
L_PR2B:
		ADD	SI,22			;下一行
		INC	CX
		JMP	SHORT L_PR2
L_PR3:
		MOV	D_SELEPR,CL		;原号
		JMP	SHORT L_INPR1

;子程序:插入PR行
S_INPR:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRTH	;'PRTH'
		CALL	S_SCAN			;查找
		JNB	L_INPR0
		MOV	SI,OFFSET NOPRTH
		JMP	L_BAT2B
L_INPR0:
		MOV	SI,BX
		MOV	DI,OFFSET F_PR+1
		MOV	CX,7
		CALL	S_INBUF 		;插入一行:PR 00
L_INPR1:
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PR		;3,'PR '
		CALL	S_SCAN			;查找
		CMP	BYTE PTR [BX+4],0DH	;判PR后一位数?
		JNZ	L_INPR2
		MOV	DI,OFFSET D_PRTHB+2	;空格
		MOV	CX,1
		LEA	SI,[BX+3]
		CALL	S_INBUF 		;写入字符串
L_INPR2:
		PUSH	BX
		CALL	S_SELEPR		;选择打印机号AL
		POP	BX
		JB	L_INPR3
		MOV	AX,WORD PTR D_PRTHB[SI]
		MOV	[BX+3],AX
L_INPR3:
		MOV	DX,D_PR
		MOV	BX,0FF11H
		MOV	CX,A_PR
		CALL	S_XSCK			;清PR窗口
		RET
S_SELEPR:
		MOV	DX,D_PR
		MOV	BX,C_PR
		MOV	CX,A_PR
		CALL	S_XSCK			;显示PR窗口
		MOV	SI,OFFSET D_PRTH
		ADD	DX,3
		MOV	BH,4EH
		CALL	S_XSZFC 		;显示标题
		MOV	SI,OFFSET D_PRTHB
		MOV	DX,D_PR
		ADD	DX,101H
		MOV	BX,C_PR
		CALL	S_CKXS			;显示窗口内容

		MOV	SI,OFFSET D_PRTHB
		MOV	BP,OFFSET D_PRTHZ1	;帮助指针
		MOV	BH,22			;项长
		MOV	CH,9			;项数-1
		MOV	CL,D_SELEPR		;初号
		CALL	S_CDKZ			;菜单控制
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

;子程序:PRNT选打印机
S_PRNT		PROC	NEAR
		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRNT	;'PRNT '
		CALL	S_SCAN			;查找
		JNB	L_PRNT1
		RET
L_PRNT1:
		XOR	CX,CX
		MOV	AL,[BX+5]		;打印机号
		CMP	AL,' '
		JZ	L_PRNT4
		MOV	SI,OFFSET D_PRNTB	;	表
L_PRNT2:
		CMP	AL,[SI]
		JZ	L_PRNT5
		ADD	SI,18			;下一行
		INC	CX
		JMP	SHORT L_PRNT2
L_PRNT4:
		MOV	CL,5
L_PRNT5:
		MOV	D_SELEPR,CL		;原号

		MOV	SI,OFFSET B_BUF
		MOV	DI,OFFSET F_PRNT	;5,'PRNT '
		CALL	S_SCAN			;查找
		CMP	BYTE PTR [BX+6],0DH	;判PRNT后一位数?
		JZ	L_PRNT6
		MOV	DI,BX
		ADD	DI,6
		MOV	CX,1
		CALL	S_DELBAT		;
L_PRNT6:
		PUSH	BX
		CALL	S_SELEPRNT		;选择打印机号AL
		POP	BX
		JB	L_PRNT7
		MOV	AL,D_PRNTB[SI]
		MOV	[BX+5],AL
L_PRNT7:
		MOV	DX,D_PRNT
		MOV	BX,0FF11H
		MOV	CX,A_PRNT
		CALL	S_XSCK			;清PR窗口
		RET
S_SELEPRNT:
		MOV	DX,D_PRNT
		MOV	BX,C_PRNT
		MOV	CX,A_PRNT
		CALL	S_XSCK			;显示PR窗口
		MOV	SI,OFFSET D_PRNT1
		ADD	DX,2
		MOV	BH,4EH
		CALL	S_XSZFC 		;显示标题
		MOV	SI,OFFSET D_PRNTB
		MOV	DX,D_PRNT
		ADD	DX,101H
		MOV	BX,C_PRNT
		CALL	S_CKXS			;显示窗口内容

		MOV	SI,OFFSET D_PRNTB
		MOV	BP,OFFSET D_PRNTZ1	;帮助指针
		MOV	BH,18			;项长
		MOV	CH,9			;项数-1
		MOV	CL,D_SELEPR		;初号
		CALL	S_CDKZ			;菜单控制
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

;子程序:查找字符串 DS:SI-开始地址,ES:DI-字符串,CX-长度
S_SCAN		PROC	NEAR
		PUSH	SI
		MOV	CL,ES:[DI]
		XOR	CH,CH
		INC	DI
L_SC1:
		PUSH	SI
		PUSH	DI
		PUSH	CX
		REP	CMPSB			;查找
		POP	CX
		POP	DI
		POP	SI
		JZ	L_SC2
		INC	SI
		CMP	BYTE PTR [SI],1AH	;到文件尾
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

;子程序:写入字符串DI,CX-长度,SI-写入点
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

;子程序:删除字符串DI,CX-长度
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

;通用子程序******************************************************************
D_YH		DB	0			;默认号
D_YS		DB	0			;原菜单色
D_CD		DW	0			;菜单左上角位置
;子程序:菜单控制 SI=菜单首,BH=项长,BL=菜单色,CH=项数-1,CL=默认号,BP=帮助菜单指针
;		 返回:AL=选中号(=1BH:退出)
S_CDKZ		PROC	NEAR
		MOV	D_YH,CL
		MOV	D_YS,BL
		MOV	D_CD,DX
		CALL	S_XSCD1 		;显示
L_CDKZ1:
		XOR	AH,AH			;键入选择
		INT	16H
		CMP	AL,1BH			;<ESC>
		JZ	L_CDKZ2
		CMP	AL,0DH			;回车选中?
		JNZ	L_CDKZ3
		MOV	AL,CL
L_CDKZ2:
		RET
L_CDKZ3:
		CMP	AH,48H			;↑
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
		CMP	AH,50H			;↓
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
		MOV	DH,D_YH 		;原号
		MOV	BL,D_YS 		;菜单色
		CALL	S_XSCD2 		;恢复
S_XSCD1:
		PUSH	SI
		PUSH	BX
		PUSH	CX
		MOV	DX,D_HELP
		MOV	BX,C_HELP
		MOV	CX,A_HELP
		CALL	S_XSCK			;显示帮助窗口
		POP	CX
		PUSH	CX
		XOR	CH,CH
		SHL	CX,1			;*2
		MOV	SI,BP
		ADD	SI,CX			;指针
		INC	CX
		MOV	SI,DS:[SI]		;帮助串首
		ADD	DX,102H 		;显示位置
		CALL	S_CKXS			;显示帮助
		POP	CX
		POP	BX
		POP	SI

		MOV	DH,CL
		MOV	BL,70H
S_XSCD2:
		PUSH	BP
		PUSH	CX
		MOV	AL,BH			;项长
		MUL	DH			;*
		ADD	AX,SI			;+串首
		MOV	BP,AX			;显示首
		MOV	DI,AX
		XOR	DL,DL			;最左列
		ADD	DX,D_CD
		MOV	CL,BH			;项长
		XOR	CH,CH
		DEC	CX			;-1(去0)
		PUSH	BX
		CALL	S_XSZFI 		;显示
		POP	BX
		POP	CX
		POP	BP
		MOV	D_YH,CL 		;当前号
		RET
S_XSCD		ENDP
;----------------------------------------------------------------------------
;子程序:清屏
S_CLS		PROC	NEAR
		MOV	AL,D_MODE		;显示方式
		CMP	D_ZJXP,1		;判直接写屏
		JNZ	L_CLS0
		MOV	AL,3
L_CLS0:
		CBW
		INT	10H			;重设显示方式

		CALL	S_GGB			;关光标

		MOV	BX,0FF11H		;BH=-1:无阴影,BL=11H	2.19
		MOV	CX,1950H		;CH=25,CL=80
		XOR	DX,DX			;屏幕左上角
		CALL	S_XSCK			;显示满屏
		RET
S_CLS		ENDP
;----------------------------------------------------------------------------
D_K		DW	0			;宽
D_G		DW	0			;高
D_YY		DB	0
;子程序:显示空窗口 DX=窗口左上角,CH=高,CL=宽,BL=颜色,BH=-1无阴影
S_XSCK		PROC	NEAR
		MOV	D_YY,BH
		PUSH	DX
		PUSH	CX
		PUSH	SI
		PUSH	BP
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
		MOV	DI,D_G
L_CK1:
		INC	DH
		CALL	S_XSYH
		DEC	DI
		JNZ	L_CK1
		INC	DH
		CMP	DH,18H
		JA	L_CK3
		MOV	SI,OFFSET D_B3		;下横线
		CALL	S_XSYH

		CMP	D_YY,-1
		JZ	L_CK3
		ADD	DX,101H
		CMP	D_MODE,9		;判单显?
		JBE	L_CK3
		CMP	DH,18H			;到底行?
		JA	L_CK3
		PUSH	BX
		MOV	BH,' '                  ;下阴影
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
;子程序:显示一行:
S_XSYH:
		PUSH	DX
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

		CMP	D_YY,-1
		JZ	L_YH2
		CMP	D_MODE,9		;判单显?
		JBE	L_YH2
		CMP	SI,OFFSET D_B1		;判上横线?
		JZ	L_YH2
		CMP	DL,80			;判到右边?
		JZ	L_YH2
		PUSH	BX
		MOV	BH,' '                  ;右边阴影
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
;子程序:显示窗口内容SI(每行尾0,最后再加0),DX=首位置,BL=属性
S_CKXS		PROC	NEAR
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
S_CKXS		ENDP
;----------------------------------------------------------------------------
;子程序:显示字符BH,位置DX(显示后+1) CX=0按字符显示,>0可显示汉字
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
;----------------------------------------------------------------------------
;子程序:显示字符串SI,结尾0,BL=属性
S_XSZFC 	PROC	NEAR
		LODSB
		OR	AL,AL			;判结束?
		JZ	L_X1
		MOV	BH,AL
		CALL	S_XSZF			;显示字符
		JMP	SHORT S_XSZFC
L_X1:
		RET
S_XSZFC 	ENDP
;----------------------------------------------------------------------------
;子程序:关闭光标
S_GGB		PROC	NEAR
		PUSH	AX
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		POP	AX
		RET
S_GGB		ENDP
;----------------------------------------------------------------------------
;子程序:开光标
S_KGB		PROC	NEAR
		MOV	CX,0E0FH
		MOV	AH,1			;开光标
		INT	10H
		RET
S_KGB		ENDP
;----------------------------------------------------------------------------
;子程序:显示键入窗口 DS:SI-提示信息
S_XSIN		PROC	NEAR
		MOV	DX,D_IN
		MOV	BX,C_IN
		MOV	CX,A_IN
		CALL	S_XSCK			;显示键入空窗口
		ADD	DX,102H
		RET
S_XSIN		ENDP
;----------------------------------------------------------------------------
;子程序:键入字符 DS:SI-提示信息
S_INKEY 	PROC	NEAR
		CALL	S_XSIN			;显示键入窗口
		CALL	S_XSZFC 		;显示提示信息
		XOR	AH,AH			;键入
		INT	16H
		PUSH	AX
		MOV	DX,D_IN
		MOV	BX,0FF11H
		MOV	CX,A_IN
		CALL	S_XSCK			;清窗口
		POP	AX
		RET
S_INKEY 	ENDP
;----------------------------------------------------------------------------
D_NUM		DW	0
;子程序:键入16进制数 CX:字节数,返回D_NUM
S_IN16		PROC	NEAR
		MOV	BP,16
		JMP	SHORT L_IN0
;子程序:键入10进制数
S_IN10:
		MOV	BP,10
L_IN0:
		PUSH	CX
		CALL	S_XSIN
		CALL	S_XSZFC
		POP	CX
		MOV	SI,OFFSET D_INPBUF	;键入缓冲区
		MOV	DI,SI
		ADD	DI,CX
		MOV	D_NUM,0
L_IN1:
		XOR	BH,BH
		MOV	AH,2
		INT	10H
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,80H
		JA	L_IN1
		CMP	AL,0DH			;回车?
		JB	L_IN1
		JZ	L_IN6
		CMP	AL,1BH			;<ESC>
		JZ	L_IN9A
		CMP	AL,8			;退格?
		JNZ	L_IN5
		CMP	SI,OFFSET D_INPBUF	;指针在区首?
		JA	L_IN3
L_IN2:
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_IN1
L_IN3:
		DEC	SI			;位置-1
L_IN4:
		CALL	S_GGB
		DEC	DX
		MOV	BH,' '
		CALL	S_XSZF			;显示空格
		DEC	DX
		CALL	S_KGB
		JMP	SHORT L_IN1
L_IN9A:
		CALL	L_IN9
		STC
		RET
L_IN5:
		CMP	AL,'0'                  ;判数字?
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
		CMP	SI,DI			;键入满?
		JZ	L_IN2
		MOV	[SI],AL 		;写入
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
		MOV	SI,OFFSET D_INPBUF	;键入区首
L_IN7:
		LODSB				;取
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
S_INCOLOR:	;键入十六进制颜色值
		MOV	SI,OFFSET D_INPUT
		MOV	CX,2			;限2位
		CALL	S_IN16			;键入十六进制数
		JB	L_INCO
		MOV	AX,D_NUM
		CLC
L_INCO:
		RET
S_IN16		ENDP

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

;子程序:写入参数 AL
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

;子程序:AL->16进制AX---------------------------------------------------------
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

;子程序:传送
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
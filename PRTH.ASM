;	PRTH.ASM 2.13L-97
;	1997.3.4, 7.31

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

K_PORT		DW	0			;打印端口
D_INT17 	DD	0			;ROM BIOS INT17 地址

;打印参数--------------------------------------------------------------------
D_01E0		DB	0			;取消本行回车换行
D_BUF0		DW	OFFSET BEGIN		;输入区首
D_BUF1		DW	OFFSET BEGIN+512	;输入区尾,第一缓冲区首(垂直点阵)
D_BUF2		DW	0			;第二缓冲区首(一行水平点阵)
D_BUF3		DW	0			;第三缓冲区首(压缩用)

D_0200		DW	0			;页长
D_0201		DW	0			;页首空
D_0202		DW	0			;累计走纸
D_0203		DW	0			;打印页号
D_0207		DW	0			;AX
D_0209		DW	0			;已输出列
D_020B		DW	0			;行首D_020D,D_020E
D_020D		DB	0			;功能字节1
	;位0-2背景1~7,位3轻打
D_020E		DB	0			;功能字节2
	;位0-反白,位1-下划线,位2-上划线,位3-左旋,位4-右旋,位5-上标,位6-下标
D_020F		DB	0			;输入标志
	;位7-ESC,位6-ESC+I,位5-ECS+I+N1
D_0210		DB	0			;打印行数(输出时逐行减1)
D_210A		DW	0			;本打印行高度
D_0211		DB	40H			;行首D_0213
D_0211A 	DB	18H			;    D_0213A
D_0211B 	DB	18H			;    D_0213B
D_0211C 	DB	0			;    D_0213C
D_0212		DB	0			;    D_0214
D_0213		DB	40H			;字型
	;位0-1横扩倍数,位2-3纵扩倍数,位4-5字体(宋仿黑楷),位6-7点阵(16,24,32,40)
	;点阵=00时:字体=00为矢量(D_0213C为字体号),=10为16点阵,=11为扩24
	;	       =01为隔点扩:此时:位2-3为字体,位0横扩,位1纵扩
D_0213A 	DB	18H			;字型宽度
D_0213B 	DB	18H			;    高度
D_0213C 	DB	0			;字体号
D_FBL		DB	0			;=/仅字型,=&字型和行距 按分辨率折算
D_FBL1		DB	0			;行尾D_FBL
D_0214		DB	0			;    行数
D_0215		DB	30,0			;行距
D_0216		DB	0			;打印方向
D_0217		DW	0			;字符间距
D_0219		DW	0			;行首D_0217
D_021D		DW	0			;左边空列  [SI]
D_HJDW		DB	0			;行距单位=0:1/180,=1:1/120

D_021F		DB	0			;暂存字节
D_0220		DW	0			;行宽(列)  [SI+3]
D_0221		DW	0			;行总宽
D_0205		DW	OFFSET BEGIN		;输入区指针

D_0228		DW	0			;页长度(点行)

D_022A		DB	0			;｀标志
D_022B		DB	0			;功能字节
D_022C		DW	0			;直接输出字节数
D_022E		DW	0			;计数暂存

D_0222		DW	0			;存当前汉字内码
D_0224		DB	0			;本行打印行数
D_0226		DB	0			;暂存当前字型
D_0204		DB	0			;软回车8DH

D_0230		DB	88H, 0, 0, 0, 88H, 0, 0, 0	;背景1
		DB	0AAH, 0, 80H, 0, 80H, 0, 80H, 0 ;背景2
		DB	80H, 0, 80H, 0, 80H, 0, 80H, 0	;背景3
		DB	0AAH, 0, 0, 0, 0, 0, 0, 0	;背景4
		DB	10H, 20H, 40H, 80H, 1, 2, 4, 8	;背景5
		DB	80H, 40H, 20H, 10H, 8, 4, 2, 1	;背景6
		DB	90H, 60H, 60H, 90H, 9, 6, 6 ,9	;背景7

;字型数据--------------------------------------------------------------------
D_ZX		DB	24,24,40H,48,24,41H,24,48,44H,48,48,45H ;ABCD
		DB	24,24,50H,48,24,51H,24,48,54H,48,48,55H ;EFGH
		DB	24,24,60H,48,24,61H,24,48,64H,48,48,65H ;IJKL
		DB	24,24,70H,48,24,71H,24,48,74H,48,48,75H ;MNOP
		DB	16,16,20H,32,16,21H,16,32,24H,32,32,25H ;QRST
		DB	40,40,80H,40,40,81H,40,40,82H,48,48,83H,0,0	;UVWXYZ
D_ZX1		DB	16,24,10H,36,24,11H,24,36,12H,36,36,13H ;abcd
		DB	16,24,14H,36,24,15H,24,36,16H,36,36,17H ;efgh
		DB	16,24,18H,36,24,19H,24,36,1AH,36,36,1BH ;ijkl
		DB	16,24,1CH,36,24,1DH,24,36,1EH,36,36,1FH ;mnop
		DB	16,24,30H,32,24,31H,16,48,34H,32,48,35H ;qrst
		DB	32,32,80H,32,32,81H,32,32,82H,32,32,83H,0,0	;uvwxyz

D_ZH		DB	90,72,48,40,32,24,20,16 	;0-7 号字
D_ZH1		DB	0, 80,60,44,36,28,22,18 	;小号字
D_DI		DW	OFFSET BEGIN+512
D_ZX0		DB	'A'                     ;字型字母
D_ESCI		DW	0
D_DPI		DW	0			;分辨率

;排版------------------------------------------------------------------------
D_YH		DB	'        '              ;打印页号区
D_YH1		DB	'1 ─',0
D_P		DB	7 DUP(0)
D_ZJJ		DW	0			;字间距计数
D_ZJA		DW	0			;字间距增量
D_ZJB		DW	0			;从此再+1
D_JZ		DB	0			;=-1居中,=80H居右
D_PBHS		DB	0			;排版行首空格数

D_PBCS		DW	3000,100,200,1900	;HP-3 A4 排版参数表
		DW	2400,100,200,1600	;HP-3 B5
		DW	3900,100,250,2320	;BJ10 A4
		DW	3200,100,250,2100	;BJ10 B5
		DW	6000,100,400,3800	;HP-4 A4
		DW	4 DUP(0)

;INT17-----------------------------------------------------------------------
D_AH		DW	OFFSET S_AH00		; AH=0 打印一字节AL
		DW	OFFSET S_01A2		; AH=1 打印机初始化
		DW	OFFSET S_01A2		; AH=2 取打印机状态AX
		DW	0			; AH=3 切换中西文打印
		DW	OFFSET S_AH04		; AH=4 特殊打印开关
		DW	OFFSET S_01A0		; AH=5 直接打印一字节AL

INT_17		PROC	FAR
		STI
		CLD
		CMP	AX,-1			;取安装状态?
		JNZ	L_0
		MOV	AX,-2130H
		MOV	BX,WORD PTR CS:D_INT17
		MOV	DX,WORD PTR CS:D_INT17+2
		IRET
L_0:
		CMP	AH,3			;切换中西文打印
		JNZ	L_2
		XOR	AH,AH			;L_1处指令为JB 0:JMP CS:D_INT17
		OR	AL,AL
		JZ	L_1
		MOV	AH,5			;L_1处指令为JB L_2 (正常打印)
L_1:
		MOV	BYTE PTR CS:K_DY,AH
		IRET
L_2:
		CMP	AH,6			;取打印参数?
		JNZ	L_3
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	AH,D_0213		;字型
		MOV	AL,D_0216		;打印方向
		MOV	BX,WORD PTR D_020D	;功能字节BL-1.BH-2
		MOV	CH,BYTE PTR D_0217	;字符间距
		MOV	CL,D_0215		;行距
		MOV	DH,'H'                  ;PRTH标志
		MOV	DL,D_ZX0		;字型字母
		MOV	SI,OFFSET D_021D	;左边空列地址
		MOV	DI,OFFSET D_0200	;页长地址
		MOV	BP,WORD PTR D_0213A	;字型宽(低八位)和高(高八位)
		PUSH	CS
		POP	ES
		POP	DS
		IRET
L_3:
		JB	L_4
K_DY	EQU	$-1
		JMP	CS:D_INT17
L_4:
		PUSH	DS
		PUSH	ES
		PUSH	BP
		PUSH	DI
		PUSH	SI
		PUSH	DX
		PUSH	CX
		PUSH	BX
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	WORD PTR K_PORT,DX
		MOV	D_0207,AX		;保存AX
		PUSH	AX
		MOV	AL,AH
		CBW
		SHL	AX,1
		MOV	DI,AX
		POP	AX
		CALL	D_AH[DI]		;转执行各功能
		MOV	AX,CS:D_0207		;返回AX
		POP	BX
		POP	CX
		POP	DX
		POP	SI
		POP	DI
		POP	BP
		POP	ES
		POP	DS
		IRET
INT_17		ENDP

;子程序:AH=4:特殊打印开关 AL=0关,=1开
S_AH04		PROC	NEAR
		OR	AL,AL			;特殊打印开关
		JZ	L_0401
		MOV	AL,3
L_0401:
		MOV	BYTE PTR D_60K1,AL	;切换｀功能处理
		MOV	BYTE PTR D_60K2,AL
		RET
S_AH04		ENDP

;子程序:AH=0 打印 -----------------------------------------------------------
S_AH00		PROC	NEAR
		CMP	D_022C,0		;取直接输出字节数
		JZ	L_02BE
		DEC	D_022C			;-1
		JMP	S_01A0			;输出字节
L_02BE:
		CMP	D_021F,0		;暂存字节
		JZ	L_02E5
		CALL	S_03EA
		MOV	D_021F,0		;清暂存
		JMP	S_03D7
L_02E5:
		TEST	D_020F,20H		;ESC+I+N1标志
		JZ	L_02EC
		MOV	AH,D_0226
		MOV	CX,AX			;列数→CX
		MOV	D_ESCI,AX
		SHL	AX,1
		ADD	AX,CX			;AX*3
		MOV	D_022C,AX
	;	CALL	S_0965			;置图形打印
		JMP	SHORT L_02F4
L_02EC:
		TEST	D_020F,40H		;ESC+I标志
		JZ	L_033F
		CMP	AL,'\'                  ;取消软回车8D0A
		JNZ	L_0308
		MOV	AL,0C3H
L_0307:
		MOV	BYTE PTR K_RHC,AL
		MOV	BYTE PTR K_RHC1,AL
L_02F4:
		DEC	D_0205			;输入区指针-1
L_02F8:
		DEC	D_0205			;输入区指针-1
L_02FC:
		AND	D_020F,3		;清标志
		RET
L_0308:
		CMP	AL,'/'                  ;恢复软回车8D0A为0D0A
		JNZ	L_0310
		MOV	AL,90H
		JMP	SHORT L_0307
L_0310:
		CMP	AL,60H			;恢复`
		JA	L_0322
		JNZ	L_031A
		MOV	AL,3
L_0312:
		MOV	BYTE PTR D_60K1,AL	;切换｀功能处理
		MOV	BYTE PTR D_60K2,AL
		JMP	SHORT L_02F4
L_031A:
		CMP	AL,27H			;取消`
		JNZ	L_0328
		XOR	AL,AL
		JMP	SHORT L_0312
L_0322:
		CMP	AL,'z'
		JA	L_02F4
		JMP	SHORT L_0334
L_0328:
		CMP	AL,'A'
		JB	L_0338
		CMP	AL,'Z'
		JA	L_02F4
		MOV	BX,OFFSET D_01E0-41H
		XLAT				;变换字型
L_0334:
		CALL	S_03D7			;写入输入区
		CALL	S_ZX			;置字型
		CMP	CH,D_0210		;与已指定行数比
		JBE	L_02FC
		MOV	D_0210,CH
		JMP	SHORT L_02FC
L_0338:
		OR	D_020F,20H		;置ESC+I+N1标志
		MOV	D_0226,AL		;暂存
		RET
L_033F:
		TEST	D_020F,80H		;ESC标志
		JZ	L_04DC
		AND	AL,5FH
		CMP	AL,'I'
		JNZ	L_0354
		OR	D_020F,40H		;置ESC+I标志
		JMP	S_03D7			;写入输入区
L_0354:
		CMP	AL,'W'
		JNZ	L_0355
		INT	5			;执行屏幕拷贝
L_0355:
		JMP	L_02F8

;特殊打印功能处理------------------------------------------------------------
L_04DC:
		MOV	SI,OFFSET D_022B	;功能符
		CMP	D_022A,60H		;当前标识符?
		JZ	L_04E0
		CMP	AL,60H			;标识符?
		JZ	L_04DE
D_60K1		EQU	$-1
		JMP	L_035C
L_04DE:
		MOV	D_022A,AL		;置｀标志
		JMP	S_03D7			;写入输入区
L_04E0:
		CMP	BYTE PTR [SI],'2'       ;第二参数
		JNZ	L_04F4
		CALL	S_Q
		JB	L_04F3
		OR	CL,CL
		JZ	L_04F2
		MOV	CH,CL
L_04F1:
		CALL	S_HIGH1
L_04F2:
		CMP	AL,','
		JNZ	L_04F5
		MOV	BYTE PTR [SI],'3'
L_04F3:
		JMP	S_03D7
L_04F4:
		CMP	BYTE PTR [SI],'3'       ;第三参数
		JNZ	L_04F6
		CALL	S_Q
		JB	L_04F3
		MOV	D_0213C,CL
L_04F5:
		JMP	L_051C
L_04F6:
		CMP	BYTE PTR [SI],0E0H	;<@设置字号>
		JNZ	L_04F8
		CALL	S_Q
		JB	L_04F3
		PUSH	AX
		CALL	S_ZH			;处理字号
		POP	AX
		MOV	D_0213A,CL		;列数
		MOV	D_0213,0
		JMP	SHORT L_04F1		;处理高和字体号
L_04F7:
		JMP	L_0505
L_04F8:
		CMP	BYTE PTR [SI],'@'       ;字型
		JNZ	L_0509
		CMP	AL,'@'                  ;字号
		JNZ	L_04F9
		MOV	BYTE PTR [SI],0E0H	;字号标志
		JMP	S_03D7			;存
L_04F9:
		CMP	AL,'-'                  ;多行字型空行走纸一行?
		JNZ	L_04FB
		MOV	AL,OFFSET L_0378-OFFSET L_0375-2
		JMP	SHORT L_04FBA
L_04FB:
		CMP	AL,'='                  ;多行字型空行走纸多行?
		JNZ	L_04FC
		XOR	AL,AL
L_04FBA:
		MOV	BYTE PTR D_0A00,AL
L_04FBB:
		DEC	D_0205			;去@
		JMP	SHORT L_0505
L_04FC:
		CMP	AL,'/'                  ;字型按分辨率折算
		JZ	L_04FC0
		CMP	AL,'&'                  ;字型和行距按分辨率折算
		JZ	L_04FC0
		CMP	AL,'\'                  ;关闭按分辨率折算
		JNZ	L_04FD
L_04FC0:
		MOV	D_FBL,AL
		CALL	S_03D7
		JMP	SHORT L_0505
L_04FD:
		CMP	AL,'9'
		JA	L_0502
		CALL	S_Q
		JB	L_04FF
		OR	CL,CL
		JZ	L_04FE
		MOV	D_0213A,CL		;列数
		MOV	D_0213,0
L_04FE:
		CMP	AL,','
		JNZ	L_051C
		MOV	BYTE PTR [SI],'2'
L_04FF:
		JMP	S_03D7
L_0502:
		CALL	S_03D7			;写入输入区
		CALL	S_ZX			;置字型
		CMP	CH,D_0210		;与已指定行数比
		JBE	L_0505
		MOV	D_0210,CH
L_0505:
		MOV	BYTE PTR [SI],0 	;清功能字节
L_0508:
		RET
L_0509:
		CMP	BYTE PTR [SI],'#'       ;页长
		JNZ	L_0537
		CMP	AL,'#'
		JNZ	L_0510
		DEC	D_0205
		MOV	BYTE PTR [SI],0 	;清功能字节
		JMP	L_0389			;换页
L_0510:
		CALL	S_Q			;取参数
		JB	L_0508
		CMP	CX,D_0228		;比页高度?
		JBE	L_0511
		MOV	CX,D_0228
L_0511:
		MOV	D_0200,CX		;置页长
		MOV	D_0202,0		;清累计走纸
L_051C:
		MOV	BYTE PTR [SI],0 	;清功能字节
		JMP	L_05F0
L_0537:
		CMP	BYTE PTR [SI],'&'       ;行距
		JNZ	L_0540
		CALL	S_Q			;取参数
		JB	L_0508
		CALL	S_HJ			;处理行距
		JMP	SHORT L_051C
L_0540:
		CMP	BYTE PTR [SI],0DBH	;排版行首空格
		JNZ	L_0547
		CALL	S_Q
		JB	L_0508
		MOV	D_PBHS,CL
		JMP	SHORT L_051C
L_0547:
		CMP	BYTE PTR [SI],'['       ;左边空列
		JNZ	L_0557
		CMP	AL,'['                  ;排版行首空
		JNZ	L_0549
		MOV	BYTE PTR [SI],0DBH	;'['=5BH+80H
L_0548:
		RET
L_0549:
		CALL	S_Q			;取参数
		JB	L_0548
		MOV	D_021D,CX		;置左边空列
		JMP	SHORT L_051C
L_0557:
		CMP	BYTE PTR [SI],']'       ;行宽
		JNZ	L_0560
		CALL	S_Q			;取参数
		JNB	L_0558
		RET
L_0558:
		CMP	CX,D_0221		;比行总宽?
		JBE	L_0559
		MOV	CX,D_0221
L_0559:
		MOV	D_0220,CX		;置行宽
		JMP	SHORT L_051C
L_0560:
		CMP	BYTE PTR [SI],28H	;处理页号
		JNZ	L_0567
		CALL	S_Q
		JNB	L_0561
		RET
L_0561:
		MOV	D_0203,CX
		JMP	SHORT L_051C
L_0566:
		JMP	SHORT L_051C
L_0567:
		CMP	BYTE PTR [SI],27H	;排版参数
		JNZ	L_0572
		CALL	S_Q
		JNB	L_0568
		JMP	L_0508
L_0568:
		MOV	D_0203,1		;页号
		MOV	BYTE PTR K_RHC,0C3H	;取消软回车
		MOV	BYTE PTR K_RHC1,0C3H
		MOV	BYTE PTR D_0A00,0	;多行字型空行打多行
		MOV	BYTE PTR S_PB,90H	;打开行禁则处理 4.27
		MOV	D_01E0,1		;本行回车换行无效
		OR	CX,CX
		JZ	L_0566
		PUSH	SI
		PUSH	AX
		DEC	CL
		MOV	AL,8
		MUL	CL
		ADD	AX,OFFSET D_PBCS
		MOV	SI,AX
		LODSW
		MOV	D_0200,AX		;页长
		LODSW
		MOV	D_0201,AX		;页首空
		LODSW
		MOV	D_021D,AX		;左空
		LODSW
		MOV	D_0220,AX		;行宽
		CALL	S_YS			;执行页首空
		POP	AX
		POP	SI
		CMP	AL,','
		JZ	L_0569
		JMP	L_051C
L_0569:
		MOV	BYTE PTR [SI],28H
		RET
L_0572:
		CMP	BYTE PTR [SI],'$'       ;直送打印机
		JNZ	L_057B
		CMP	AL,'$'
		JZ	L_0575
		JMP	S_01A0
L_0575:
		MOV	BYTE PTR [SI],0
		RET
L_057B:
		CMP	BYTE PTR [SI],'^'       ;字符间距
		JNZ	L_058E
		CALL	S_Q			;取参数
		JNB	L_0588
		JMP	S_03D7			;写入输入区
L_0588:
		CALL	S_ZJ			;处理字符间距
		JMP	L_051C
L_058E:
		CMP	BYTE PTR [SI],'~'       ;空列
		JNZ	L_05A2
		CALL	S_Q			;取参数
		JB	L_059F
		ADD	D_0209,CX		;已输出列累计
		JMP	L_051C
L_059F:
		JMP	S_03D7			;写入输入区
L_05A2:
		CMP	BYTE PTR [SI],'|'       ;水平定位
		JNZ	L_05E6
		CALL	S_Q			;取参数
		JNB	L_05AD
		RET
L_05AD:
		CMP	CX,D_0209		;<=已输出列?
		JBE	L_05E3
		PUSH	AX
		MOV	AL,'~'                  ;空列命令符
		CALL	S_03D7			;写入输入区
		MOV	AX,CX
		SUB	AX,D_0209		;得应输出空列
		MOV	D_0209,CX		;置已输出列
		MOV	CX,40AH
		MOV	BX,D_0205
		MOV	DI,3
L_05CD:
		DIV	CL
		OR	AH,'0'
		MOV	[BX+DI],AH		;写入输出空列命令
		MOV	AH,0
		DEC	DI
		DEC	CH
		JNZ	L_05CD
		POP	AX
		ADD	BX,4
		MOV	D_0205,BX		;存输入区指针
L_05E3:
		JMP	L_051C
L_05E6:
		CMP	BYTE PTR [SI],'*'       ;打印份数
		JNZ	L_05EE
		CALL	S_Q
		JNB	L_05E7
		RET
L_05E7:
		CMP	CL,0
		JZ	L_05E8
		CMP	CL,99
		JA	L_05E8
		CALL	S_DYFS			;设置打印份数
L_05E8:
		RET
L_05EE:
		CMP	BYTE PTR [SI],'%'       ;背景
		JNZ	L_05F0
		CALL	S_03D7			;写入输入区
		JMP	L_0505
L_05F0:
		CMP	AL,60H			;特殊打印功能标识符
		JNZ	L_0600
		MOV	D_022A,0		;清｀标志
		JMP	S_03D7			;写入输入区
L_0600:
		CMP	AL,'#'                  ;页长
		JNZ	L_0612
L_0610:
		MOV	[SI],AL
		RET
L_0612:
		CMP	AL,'$'                  ;直送打印机
		JZ	L_0610
		CMP	AL,'*'                  ;打印份数
		JZ	L_0610
		CMP	AL,'&'                  ;行距
		JZ	L_0610
		CMP	AL,'['                  ;左边空
		JZ	L_0610
		CMP	AL,']'                  ;行宽
		JZ	L_0610
		CMP	AL,'|'                  ;水平定位
		JZ	L_0610
		CMP	AL,27H			;设置排版
		JZ	L_0610

		CMP	AL,'%'                  ;背景
		JZ	L_0640
		CMP	AL,'@'                  ;字型
		JZ	L_0640
		CMP	AL,'^'                  ;字符间距
		JZ	L_0640
		CMP	AL,'~'                  ;空列
		JNZ	L_0650
L_0640:
		MOV	[SI],AL
		JMP	S_03D7			;写入输入区
L_0650:
	;	CMP	AL,'<'                  ;双向
	;	JZ	L_0652
	;	CMP	AL,'>'                  ;单向
	;	JNZ	L_0660
L_0652: ;
	;	MOV	D_0216,AL		;置打印方向
	;	JMP	S_FX
L_0660:
		CMP	AL,'.'                  ;暂停
		JNZ	L_0670
		MOV	AX,0E07H
		INT	10H			;响铃
L_0666:
		XOR	AH,AH
		INT	16H			;按键
		CMP	AL,0DH			;判回车?
		JNZ	L_0666
		RET
L_0670:
		CMP	AL,':'                  ;初始化工作参数
		JNZ	L_0680
		CMP	BYTE PTR S_PB,90H	;判原排版?
		JNZ	L_0672
		MOV	AL,24
		MUL	D_0224			;*行数
		ADD	AX,WORD PTR D_0215	;+行距
		MOV	CX,AX			;每行走纸
		MOV	AX,D_0200		;页长
		SUB	AX,D_0202		;-已走纸
		SUB	AX,CX			;-1行
		MOV	DX,AX
		CALL	S_DYDN			;走纸
		MOV	D_0201,0
		CALL	S_DYYH			;打印页号
L_0672:
		MOV	AX,D_0228		;页总长
		MOV	D_0200,AX
		MOV	AX,D_0221		;行总宽
		MOV	D_0220,AX
		XOR	AX,AX
		MOV	D_0201,AX		;清页首空
		MOV	D_0202,AX		;清已走纸
		MOV	D_0203,AX		;清页号
		MOV	D_PBHS,AL		;清排版行首空
		MOV	D_FBL,AL		;清按分辨率折算
		MOV	DI,OFFSET D_020B
		MOV	CX,OFFSET D_021F-OFFSET D_020B
		REP	STOSB			;清D_020B~D_021F
		MOV	AL,90H
		MOV	BYTE PTR K_RHC,AL	;恢复软回车为0D0A
		MOV	BYTE PTR K_RHC1,AL
		MOV	BYTE PTR S_PB,0C3H	;关闭行禁则处理
		MOV	AL,'A'
		CALL	S_ZX
		MOV	AL,30
		CMP	D_HJDW,0
		JZ	L_0674
		MOV	AL,20
L_0674:
		MOV	D_0215,AL		;行距
		JMP	S_0467
L_0680:
		CMP	AL,','                  ;<居中>
		JNZ	L_0685
		CMP	D_JZ,-1 		;判居中?
		JZ	L_0682
		MOV	D_JZ,-1 		;设标志
		RET
L_0682:
		MOV	D_JZ,80H		;设居右
		RET
L_0685:
		CMP	AL,';'                  ;<轻打>
		JNZ	L_0690
L_0688:
		JMP	S_03D7
L_0690:
		CMP	AL,'\'                  ;<反白>
		JZ	L_0688
		CMP	AL,'/'                  ;<上划线>
		JZ	L_0688
		CMP	AL,'_'                  ;<下划线>
		JZ	L_0688
		CMP	AL,'='                  ;<恢复>
		JZ	L_0688
		CMP	AL,'('                  ;<左旋>
		JZ	L_0688
		CMP	AL,')'                  ;<右旋>
		JZ	L_0688
		CMP	AL,'?'                  ;<清旋转>
		JZ	L_0688
		CMP	AL,'+'                  ;<上标>
		JNZ	L_06A0
		MOV	AL,20H
L_0699:
		MOV	D_020E,AL
		JMP	S_03D7
L_06A0:
		CMP	AL,'-'                  ;<下标>
		JNZ	L_06B0
		MOV	AL,40H
		JMP	SHORT L_0699
L_06B0:
		CMP	AL,'!'                  ;<正常>
		JNZ	L_06C0
		XOR	AL,AL
		JMP	SHORT L_0699
L_06C0:
		CMP	AL,'{'                  ;设置旋转打印
		JNZ	L_06D0
		CALL	S_SET90
		RET
L_06D0:
		CMP	AL,'}'                  ;设置正常打印
		JNZ	L_0368
		CALL	S_SET0
		RET
;打印字符处理----------------------------------------------------------------
L_035C:
		CMP	AL,1BH			;<ESC>?
		JNZ	L_0368
		OR	D_020F,80H		;置ESC标志
		JMP	S_03D7			;写入输入区
L_0368:
		CMP	AL,0A0H 		;判汉字?
		JBE	L_0370
		MOV	D_021F,AL		;暂存前字节
		JMP	S_03D7
L_0370:
		CMP	AL,8AH			;WS换页?
		JNZ	L_0371
		MOV	AL,0AH
L_0371:
		CMP	AL,0AH			;换行?
		JNZ	L_0382
		CMP	D_0204,8DH
		JNZ	L_0372
		MOV	D_0204,AL
K_RHC1	EQU	$
		NOP
L_0372:
		MOV	BYTE PTR D_0207,AL	;写回AX
		MOV	DX,D_BUF0
		CMP	DX,D_0205		;输入区无数据?
		JZ	L_0373
		JMP	S_0450			;打印
L_0373:
		CMP	AL,0DH
		JNZ	L_0374
		MOV	D_0204,0
		RET
L_0374:
		CMP	D_0204,0DH		;回车时有打印内容并走纸?
		JZ	L_0378
		JMP	SHORT L_0378
D_0A00	EQU	$-1
L_0375:
		MOV	AL,D_0212		;行首行数
		MOV	D_0210,AL
		JMP	SHORT L_0378
L_0376:
		DEC	D_0210
L_0378:
		CALL	S_0988			;走纸
		CMP	D_0210,0
		JNZ	L_0376
L_0379:
		RET
L_0382:
		CMP	AL,0DH			;回车?
		JZ	L_0372
		CMP	AL,8DH			;WS软回车?
		JNZ	L_0388
		MOV	D_0204,AL
K_RHC	EQU	$
		NOP
		MOV	AL,0DH
		JMP	SHORT L_0372
L_0388:
		AND	AL,7FH			;去高位
		CMP	AL,0CH			;换页?
		JNZ	L_03AD
L_0389:
		CALL	S_PAGE			;换页			INT60
S_YS:
		MOV	DX,D_0201		;页首空
		MOV	D_0202,DX		;清累计走纸
		OR	DX,DX
		JZ	L_0391
		CALL	S_DYDN			;向下走纸
L_0391:
		RET
L_03AD:
		CMP	AL,9			;跳格?
		JNZ	L_03D4
L_03B3:
		MOV	AL,' '
		CALL	S_03EA			;计算列数
		CALL	S_03D7			;写入输入区
		MOV	AX,D_0205
		SUB	AX,D_BUF0
		TEST	AX,7			;判8字符位置
		JZ	L_03C3
		JMP	SHORT L_03B3
L_03C3:
		RET
L_03D4:
		CALL	S_03EA
;子程序:写入输入区
S_03D7:
		MOV	DI,D_0205		;输入区指针
		CMP	DI,D_BUF1		;判输入区尾
		JNB	L_03E6
		STOSB				;写入
		MOV	D_0205,DI		;存指针
L_03E6:
		RET

;子程序:计算列数
S_03EA:
		INC	D_ZJJ			;字间距计数+1
		PUSH	AX
		MOV	CX,D_0217		;字符间距
		MOV	AL,D_0213		;字型
		TEST	AL,80H			;矢量字?
		JNZ	L_03F0
		AND	AL,0F0H
		CMP	AL,10H			;隔点扩?
		JZ	L_03F0
		MOV	AL,D_0213
		AND	AL,3
		INC	AX
		MUL	CL
		MOV	CX,AX
L_03F0:
		POP	AX
		MOV	BL,D_0213A		;字型列数
		XOR	BH,BH
		TEST	D_0213,80H		;判矢量汉字?
		JZ	L_03F1
		TEST	D_020E,60H		;判上下标?
		JZ	L_03F1
		SHR	BX,1
L_03F1:
		CMP	AL,0A0H 		;判汉字?
		JA	L_03F2
		SHR	BX,1			;字符:列数减半
		JMP	SHORT L_03F6
L_03F2:
		ADD	BX,CX			;加字符间距
L_03F6:
		ADD	BX,CX			;加字符间距
		MOV	CX,D_0209		;已输出列
		ADD	CX,BX			;累计
		CMP	CX,D_0220		;比行宽
		JA	L_042F
		MOV	D_0209,CX		;置已输出列
		RET
L_042F:
		CMP	D_021F,0		;
		JZ	L_0430
		DEC	D_0205			;去汉字前字节
L_0430:
		PUSH	BX
		PUSH	AX
		CALL	S_PB			;处理行禁则

		CALL	S_0450

		MOV	AL,D_PBHS		;排版行首空格数
		OR	AL,AL
		JZ	L_0433
L_0432:
		PUSH	AX
		MOV	AL,' '
		CALL	S_03EA
		CALL	S_03D7
		POP	AX
		DEC	AL
		JNZ	L_0432
L_0433:
		MOV	SI,OFFSET D_P		;保存前字节
L_0434:
		LODSB
		OR	AL,AL
		JZ	L_0436
		CMP	AL,0A0H
		JBE	L_0435
		CALL	S_03D7
		LODSB
L_0435:
		CALL	S_03EA
		CALL	S_03D7
		JMP	SHORT L_0434
L_0436:
		MOV	D_P,0
		MOV	AL,D_021F		;重存汉字前字节
		OR	AL,AL
		JZ	L_0438
		CALL	S_03D7
L_0438:
		POP	AX
		POP	BX
		ADD	D_0209,BX
		INC	D_ZJJ
		RET
;子程序:打印
S_0450:
		MOV	AL,D_0212		;上行尾行数
		CMP	AL,D_0210
		JBE	L_0452
		MOV	D_0210,AL
L_0452:
		MOV	D_0224,AL		;本行打印行数

		CMP	D_0200,0
		JZ	L_0455
		MOV	AL,24
		MUL	D_0224			;非底行走纸
		ADD	AX,WORD PTR D_0215	;+行距
		ADD	AX,D_0202		;累计走纸
		CMP	AX,D_0200		;比页长?
		JBE	L_0455
		CALL	S_PAGE			;换页
		MOV	D_0202,0
L_0455:
		MOV	AL,D_0210
		INC	AL
		MOV	AH,24
		MUL	AH
		MOV	D_210A,AX		;本行高度
		CALL	S_STAR			;设置分辨率和开始光栅图象
		JMP	SHORT L_0462
L_0460:
		DEC	D_0210
L_0462:
		CALL	S_0470			;置行首状态
		CALL	S_0480			;处理一行
		CALL	S_0980			;输出
		CMP	D_0210,0
		JNZ	L_0460

		CALL	S_DYEND 		;结束光栅
		MOV	DX,D_210A		;本行高度
		CALL	S_DYUP			;光标恢复
		CALL	S_0988			;走纸(处理回车换行)
S_0466:
		MOV	AX,D_BUF0		;输入区首
		MOV	D_0205,AX		;清输入区指针
S_0467:
		XOR	AX,AX
		MOV	D_0209,AX		;清已输出列数
		MOV	WORD PTR D_022A,AX	;清｀标志
		MOV	D_JZ,AL 		;清居中
		MOV	D_ZJJ,AX
		MOV	D_ZJA,AX
		MOV	D_ZJB,AX
		MOV	AX,WORD PTR D_020D	;以下为置行首状态
		MOV	D_020B,AX
		MOV	AX,WORD PTR D_0213
		MOV	WORD PTR D_0211,AX
		MOV	AX,WORD PTR D_0213B
		MOV	WORD PTR D_0211B,AX
		MOV	AL,D_0214
		MOV	D_0212,AL
		MOV	AX,D_0217
		MOV	D_0219,AX
		MOV	AL,D_FBL
		MOV	D_FBL1,AL
		RET

;子程序:置行首状态
S_0470:
		MOV	WORD PTR D_022A,0	;清｀标志字节
		MOV	AX,D_020B
		MOV	WORD PTR D_020D,AX
		MOV	AX,WORD PTR D_0211
		MOV	WORD PTR D_0213,AX
		MOV	AX,WORD PTR D_0211B
		MOV	WORD PTR D_0213B,AX
		MOV	AL,D_0212
		MOV	D_0214,AL
		MOV	AX,D_0219
		MOV	D_0217,AX
		MOV	AL,D_FBL1
		MOV	D_FBL,AL
		RET

;子程序:打印一行
S_0480:
		CALL	S_0965			;置图形打印
		MOV	SI,D_BUF0		;输入区首
		MOV	D_ZJJ,0
L_0490:
		MOV	AH,D_0213		;字型
		LODSB
		CMP	AL,0A0H 		;判汉字
		JA	L_049E
		CALL	S_07B9			;处理字符
		JMP	SHORT L_04A6
L_049E:
		MOV	DH,AL			;汉字前字节
		LODSB
		MOV	DL,AL			;汉字后字节
		CALL	S_06B8			;处理汉字
L_04A6:
		CMP	SI,D_0205		;处理完?(比输入区尾)
		JB	L_0490
		RET

;子程序:字符处理
S_07B9:
		CMP	D_022A,60H		;判｀标志
		JZ	L_07CB
		CMP	AL,60H
		JZ	L_07C7
D_60K2		EQU	$-1
		JMP	L_089A
L_07C7:
		MOV	D_022A,AL		;置/清｀标志
		RET
L_07CB:
		CMP	AL,60H
		JNZ	L_07D0
		XOR	AL,AL
		JMP	SHORT L_07C7
L_07D0:
		CMP	AL,'^'                  ;字符间距
		JNZ	L_07E0
L_07D7:
		LODSB
		CALL	S_Q			;取参数
		JB	L_07D7
		CALL	S_ZJ			;处理字符间距
L_07E1:
		DEC	SI
		RET
L_07E0:
		CMP	AL,'~'                  ;空列
		JNZ	L_07F0
L_07EC:
		LODSB
		CALL	S_Q			;取参数
		JB	L_07EC
		CALL	S_075B			;输出空列
		JMP	SHORT L_07E1
L_07F0:
		CMP	AL,'@'                  ;字型
		JNZ	L_0810
		LODSB
		CMP	AL,'/'
		JZ	L_07F1
		CMP	AL,'&'
		JZ	L_07F1
		CMP	AL,'\'
		JNZ	L_07F2
L_07F1:
		MOV	D_FBL,AL
		RET
L_07F2:
		CMP	AL,'@'                  ;设置字号
		JNZ	L_07F5
L_07F3:
		LODSB
		CALL	S_Q			;取字号
		JB	L_07F3
		PUSH	AX
		CALL	S_ZH			;处理字号
		POP	AX
		MOV	D_0213A,CL		;宽度
		MOV	D_0213,80H
		JMP	SHORT L_07FAA
L_07F5:
		CMP	AL,'9'
		JBE	L_07F8
		CALL	S_ZX
		RET
L_07F7:
		LODSB
L_07F8:
		CALL	S_Q
		JB	L_07F7
		OR	CL,CL
		JZ	L_07F9
		MOV	D_0213A,CL		;宽度
		MOV	D_0213,80H
L_07F9:
		CMP	AL,','
		JNZ	L_07FE
L_07FA:
		LODSB
		CALL	S_Q
		JB	L_07FA
		OR	CL,CL
		JZ	L_07FC
		MOV	CH,CL
L_07FAA:
		MOV	D_0213B,CH		;高度
		PUSH	AX
		MOV	AL,CH
		XOR	AH,AH
		MOV	CL,24
		DIV	CL
		OR	AH,AH
		JNZ	L_07FB
		DEC	AX
L_07FB:
		MOV	D_0214,AL		;行数
		POP	AX
L_07FC:
		CMP	AL,','
		JNZ	L_07FE
L_07FD:
		LODSB
		CALL	S_Q
		JB	L_07FD
		MOV	D_0213C,CL		;字体号
L_07FE:
		DEC	SI
		RET
L_0810:
		CMP	AL,'%'                  ;背景
		JNZ	L_081B
		LODSB
		AND	AL,0FH
		CMP	AL,7
		JA	L_0812
		AND	D_020D,0F8H
		OR	D_020D,AL		;置背景
L_0812:
		RET
L_081B:
		MOV	BX,OFFSET D_020E	;标志字节
		CMP	AL,';'                  ;轻打
		JNZ	L_082E
		OR	D_020D,8
		RET
L_082E:
		CMP	AL,'\'                  ;反白
		JNZ	L_0836
		OR	BYTE PTR [BX],1
		RET
L_0836:
		CMP	AL,'/'                  ;上划线
		JNZ	L_083E
		OR	BYTE PTR [BX],2
		RET
L_083E:
		CMP	AL,'_'                  ;下划线
		JNZ	L_0846
		OR	BYTE PTR [BX],4
		RET
L_0846:
		CMP	AL,'='                  ;恢复
		JNZ	L_0853
		AND	BYTE PTR [BX],0F8H	;清上下划线和反白
		AND	D_020D,7		;轻打
		RET
L_0853:
		CMP	AL,'('                  ;左旋
		JNZ	L_085E
		AND	BYTE PTR [BX],0E7H
		OR	BYTE PTR [BX],8
		RET
L_085E:
		CMP	AL,')'                  ;右旋
		JNZ	L_0869
		AND	BYTE PTR [BX],0E7H
		OR	BYTE PTR [BX],10H
		RET
L_0869:
		CMP	AL,'?'                  ;不旋
		JNZ	L_0871
		AND	BYTE PTR [BX],0E7H
		RET
L_0871:
		CMP	AL,'+'                  ;上标
		JNZ	L_087C
		AND	BYTE PTR [BX],1FH
		OR	BYTE PTR [BX],20H
		RET
L_087C:
		CMP	AL,'-'                  ;下标
		JNZ	L_0892
		AND	BYTE PTR [BX],1FH
		OR	BYTE PTR [BX],40H
		RET
L_0892:
		CMP	AL,'!'                  ;正常
		JNZ	L_089A
		AND	BYTE PTR [BX],1FH
		RET
L_089A:
		CMP	AL,1BH			;ESC
		JNZ	L_08A2
		LODSB
		LODSB
		JMP	S_ZX			;置单双向或字型
L_08A2:
		XOR	DH,DH
		MOV	DL,AL

;子程序:处理汉字 DX
S_06B8:
		MOV	D_0222,DX		;暂存
		PUSH	SI
		MOV	BL,D_020E		;取状态
		MOV	BH,D_0210		;取打印行数
		MOV	D_0226,AH		;暂存字型
		MOV	AL,AH
		TEST	AL,80H			;矢量汉字?
		JZ	L_06E5
		MOV	AL,D_0213C
		CBW
		MOV	BX,AX			;字体号
		MOV	AL,D_0214
		SUB	AL,D_0210
		MOV	AH,24
		MUL	AH
		MOV	SI,AX			;起始行
		ADD	AX,24
		MOV	DI,AX			;终止行
		PUSH	BP
		CALL	S_SX			;属性转换
		MOV	AL,D_0213A		;横向点数
		XOR	AH,AH
		OR	DH,DH			;判汉字
		JNZ	L_06BA
		XOR	BX,BX
L_06BA:
		MOV	CL,D_0213B		;纵向点数
		XOR	CH,CH
		INT	7DH			;读矢量字库
		POP	BP
		MOV	DS,DX
		MOV	SI,BX
		MOV	CX,AX
		JMP	SHORT L_06F0
L_06E5:
		AND	AL,0F0H
		CMP	AL,10H			;隔点扩?
		JZ	L_06EE
		AND	AL,0C0H
		OR	AL,AL
		JNZ	L_06EE
		INT	7CH			;读16点阵
		JMP	SHORT L_06F0
L_06EE:
		INT	7BH			;读24点阵
L_06F0:
		MOV	BH,AH
		MOV	DH,CS:D_0210		;当前行数
		CMP	DH,CS:D_0214		;判此行空打?
		JA	L_0735
L_0700:
		CALL	S_0780			;输出

		INC	CS:D_ZJJ		;字间距计数+1
		MOV	CX,CS:D_0217		;字符间距
		ADD	CX,CS:D_ZJA		;+增量
		CMP	CS:D_ZJB,0
		JZ	L_0701
		MOV	AX,CS:D_ZJJ		;计数
		CMP	AX,CS:D_ZJB		;从此再+1
		JBE	L_0701
		INC	CX
L_0701:
		OR	CX,CX			;=0?
		JZ	L_0731
		CALL	S_08B8			;字符间距处理
L_0731:
		POP	SI
		PUSH	CS
		POP	DS
		RET
;输出空列CX
L_0735:
		POP	SI
L_0736:
		PUSH	CS
		POP	DS
		MOV	BX,D_0217		;字符间距
		MOV	AL,AH			;字型
		TEST	AL,80H
		JNZ	L_0740
		AND	AL,0F0H
		CMP	AL,10H			;隔点扩?
		JZ	L_0740
		MOV	AL,AH
		AND	AL,3			;横扩
		INC	AX			;倍数
		PUSH	AX
		MUL	CL
		MOV	CX,AX
		POP	AX
		MUL	BL
		MOV	BX,AX
L_0740:
		ADD	CX,D_ZJA		;+增量
		CMP	D_ZJB,0
		JZ	L_0747
		MOV	AX,D_ZJJ		;计数
		CMP	AX,D_ZJB		;从此再+1
		JBE	L_0747
		INC	CX
L_0747:
		MOV	DX,D_0222
		OR	DH,DH			;判空汉字
		JZ	L_074F
		ADD	CX,BX			;加字符间距
L_074F:
		ADD	CX,BX			;加字符间距
;子程序:输出空列
S_075B:
		INC	BP
		XOR	AL,AL
		CALL	S_015A
		XOR	AL,AL
		CALL	S_015A
		XOR	AL,AL
		CALL	S_015A
		LOOP	S_075B			;输出空列
		RET

;子程序:字符间距处理 CX=字符间距
S_08B8:
		MOV	DX,CS:D_0222		;取当前码
		CMP	DH,0A9H 		;判九区?
		JZ	L_08F0
		MOV	AH,BH
		XOR	CX,CX
		JMP	L_0736			;输出空列
L_08F0:
		SUB	SI,6			;复制倒数第二列
		MOV	CX,CS:D_0217		;字符间距
		SHL	CX,1
		ADD	CX,CS:D_ZJA		;+增量
		CMP	CS:D_ZJB,0
		JZ	L_08E8
		MOV	AX,CS:D_ZJJ		;计数
		CMP	AX,CS:D_ZJB		;从此再+1
		JBE	L_08E8
		INC	CX
L_08E8:
L_08F1:
		PUSH	CX
		PUSH	SI
		MOV	CL,1
		CALL	S_0780
		POP	SI
		POP	CX
		LOOP	L_08F1
		RET

;子程序:打印处理 DS:SI=点阵地址,CL=打印列数,BH=字型
S_0780:
		MOV	CH,1
		TEST	BH,80H
		JNZ	L_0780
		MOV	CH,BH
		AND	CH,3			;横扩
		INC	CH			;倍数
L_0780:
		LODSB
		MOV	DH,AL		;高
		LODSB
		MOV	DL,AL		;中
		LODSB
		MOV	BL,AL		;低
		MOV	AL,BH
		TEST	AL,80H			;矢量
		JNZ	L_0793
		TEST	AL,0CH			;非纵扩
		JZ	L_0793
L_0782:
		CALL	S_0794			;纵扩二倍
L_0793:
		CALL	S_0152			;输出
		DEC	CL
		JNZ	L_0780
		RET

;子程序:打印一列 DH-DL-BL=打印数据,CH=横向放大倍数
S_0152:
		PUSH	CX
L_0153:
		INC	BP
		MOV	AL,DH
		CALL	S_015A
		MOV	AL,DL
		CALL	S_015A
		MOV	AL,BL
		CALL	S_015A
		DEC	CH
		JNZ	L_0153
		POP	CX
		RET

;子程序:纵扩一列 DH-DL-BL=一列数据 返回:DH-DL-BL=一列数据
S_0794:
		PUSH	CX
L_0795:
		TEST	CS:D_0210,1		;下半行?
		JZ	L_079A
		MOV	AL,DL
		CALL	S_07A0
		MOV	BL,CL
		MOV	AL,DH
		CALL	S_07B0
		MOV	DL,CL
		MOV	AL,DH
		CALL	S_07A0
		MOV	DH,CL
		JMP	SHORT L_079C
L_079A:
		MOV	AL,DL
		CALL	S_07B0
		MOV	DH,CL
		MOV	AL,BL
		CALL	S_07A0
		MOV	DL,CL
		MOV	AL,BL
		CALL	S_07B0
		MOV	BL,CL
L_079C:
		POP	CX
		RET
;子程序:高半字节扩展
S_07A0:
		MOV	AH,4
L_07A1:
		RCL	AL,1
		PUSHF
		RCL	CL,1
		POPF
		RCL	CL,1
		DEC	AH
		JNZ	L_07A1
		RET
;子程序:低半字节扩展
S_07B0:
		MOV	AH,4
L_07B1:
		RCR	AL,1
		PUSHF
		RCR	CL,1
		POPF
		RCR	CL,1
		DEC	AH
		JNZ	L_07B1
		RET

;子程序:属性转换到RDHZK2
	;位0=1垂直点阵,位9-下划线,位10-上划线,位11-下标,位12-上标
	;位13=0旋转90度;=1旋转180度,位14=0左旋;=1右旋,位15=0不旋转;=1旋转
S_SX:
		PUSH	BX
		MOV	AL,D_020E
		MOV	BX,1			;垂直点阵
L_SX1:
		TEST	AL,2		;上划线
		JZ	L_SX2
		OR	BH,4
L_SX2:
		TEST	AL,4		;下划线
		JZ	L_SX3
		OR	BH,2
L_SX3:
		OR	DH,DH
		JZ	L_SX5
		TEST	AL,8		;左旋
		JZ	L_SX4
		OR	BH,80H
		JMP	SHORT L_SX5
L_SX4:
		TEST	AL,10H		;右旋
		JZ	L_SX5
		OR	BH,0C0H
L_SX5:
		TEST	AL,20H		;上标
		JZ	L_SX6
		OR	BH,10H
		JMP	L_SX7
L_SX6:
		TEST	AL,40H		;下标
		JZ	L_SX7
		OR	BH,8
L_SX7:
		MOV	BP,BX
		POP	BX
		RET

;子程序:置图形打印
S_0965:
		XOR	BP,BP
		TEST	D_JZ,80H		;判居中或居右?
		JZ	L_0969
		MOV	AX,D_0220		;行宽
		SUB	AX,D_0209		;-本行输出列
		JB	L_0969			;
		CMP	D_JZ,-1 		;判居中?
		JNZ	L_0966
		SHR	AX,1			;左边加空
L_0966:
		MOV	BP,AX
L_0969:
		MOV	CX,D_021D		;左边空列
		ADD	CX,BP
		MOV	BP,CX
		OR	CX,CX			;=0?
		JZ	L_0970
		MOV	AX,CX
		SHL	AX,1
		ADD	CX,AX
L_096A:
		XOR	AL,AL
		CALL	S_0190			;送出无属性的AL
		LOOP	L_096A
L_0970:
		RET

;子程序:输出点阵 BP>0处理点阵
S_0980:
		CMP	D_ESCI,0		;是否ESC+I图象方式?
		JZ	L_0981
		MOV	BP,D_ESCI
		MOV	D_ESCI,0
L_0981:
		OR	BP,BP			;有无输出点阵?
		JZ	L_0984
		MOV	AX,BP
		AND	AX,7
		JZ	L_0982
		MOV	CX,8
		SUB	CX,AX			;BP补足整字节点数
		ADD	BP,CX			;调整到横向字节位置
		MOV	AX,CX
		SHL	CX,1
		ADD	CX,AX			;*3
		MOV	DI,D_DI
		XOR	AL,AL
		REP	STOSB			;填空
L_0982:
		CALL	S_XZ			;点阵旋转并传送

		MOV	AX,D_BUF1		;点阵地址
		MOV	D_DI,AX 		;初始指针
L_0984:
		RET

;子程序:走纸
S_0988:
		MOV	AL,BYTE PTR D_0207
		CMP	AL,0DH
		JNZ	L_0989
		MOV	D_0204,AL		;回车时有打印内容
		RET
L_0989:
		MOV	DX,D_210A		;本行高度
		OR	DX,DX
		JZ	L_098A
		SUB	DX,24
L_098A:
		MOV	AX,WORD PTR D_0215
		ADD	DX,AX
		ADD	D_0202,DX		;走纸累加
		CALL	S_DYDN			;光标下移
		MOV	D_210A,0

		CMP	D_0203,-1		;连续打印?
		JZ	L_09A9
		CMP	D_0210,0
		JNZ	L_09A9
		CMP	D_0200,0		;不打页号?
		JZ	L_09A9
		MOV	AL,24
		MUL	D_0224			;非底行走纸
		ADD	AX,WORD PTR D_0215	;加行距
		MOV	CX,AX
		MOV	AX,D_0202		;已走纸
		ADD	AX,CX
		ADD	AX,CX

		CMP	AX,D_0200		;是否超页长?
		JBE	L_09A9
		CALL	S_DYYH			;打印页号
L_09A9:
		RET

;子程序:点阵转置
S_XZ:
		PUSH	BP
		PUSH	BX
		MOV	SI,D_BUF1		;垂直点阵地址
		MOV	CX,3			;3块
		SHR	BP,CL			;BP转横向字节数
L_XZ1:
		PUSH	CX
		MOV	CX,8			;8位
L_XZ2:
		MOV	DI,D_BUF2		;水平点阵地址
		PUSH	SI
		MOV	BX,BP			;横向字节
L_XZ3:
		MOV	DH,8			;8位
L_XZ4:
		MOV	AL,[SI]
		SHR	AL,CL
		RCL	DL,1
		ADD	SI,3
		DEC	DH
		JNZ	L_XZ4
		MOV	[DI],DL
		INC	DI
		DEC	BX
		JNZ	L_XZ3
		CALL	S_CSYH			;传送一行光栅数据
		POP	SI
		LOOP	L_XZ2
		INC	SI
		POP	CX
		LOOP	L_XZ1
		POP	BX
		POP	BP
		RET

;子程序:传送一行光栅数据 BP=字节数
S_CSYH:
		PUSH	CX
		PUSH	BP
		MOV	SI,90H
		CALL	S_DYZF			;传送光栅数据命令
		CMP	BYTE PTR DS:[9FH],1	;=1压缩,=0不压缩
		JZ	L_CS2
		MOV	DX,BP
		CALL	L_DYFS0 		;数据字节数和'W'

		MOV	SI,D_BUF2		;水平点阵区首
		MOV	CX,BP			;	 字节数
		JMP	L_CS8
L_CS2:
		PUSH	SI
		MOV	SI,D_BUF2		;水平点阵区首
		ADD	BP,SI			;	   尾
		MOV	DI,D_BUF3		;压缩点阵区首
L_CS3:
		XOR	CX,CX			;计数(实际+1)
		LODSB				;取一字节
		CMP	SI,BP			;判结束?
		JZ	L_CS4D
		MOV	DL,AL
		LODSB				;再取一字节
		INC	CX
		CMP	AL,DL			;判相等?
		JNZ	L_CS5
		CMP	SI,BP			;判结束?
		JZ	L_CS4D
L_CS4:					;相等处理
		LODSB				;判下一个?
		CMP	AL,DL
		JNZ	L_CS4A
		INC	CX
		CMP	SI,BP			;判结束?
		JB	L_CS4
		JMP	SHORT L_CS4B
L_CS4A:
		DEC	SI
L_CS4B:
		CMP	CX,127			;>127?
		JBE	L_CS4D
		SUB	CX,127
		MOV	BYTE PTR [DI],-127	;重复标志
		INC	DI
		MOV	[DI],DL 		;重复字节
		INC	DI
		JMP	SHORT L_CS4B
L_CS4D:
		NEG	CL
		MOV	[DI],CL 		;重复标志
		INC	DI
		MOV	[DI],DL 		;重复字节
		INC	DI
		CMP	SI,BP			;判结束?
		JB	L_CS3
		JMP	L_CS7
L_CS5:					;不相等处理
		CMP	SI,BP			;判结束?
		JZ	L_CS5D
		PUSH	SI
L_CS5A:
		MOV	DL,AL
		LODSB				;取一字节
		CMP	AL,DL			;判?
		JZ	L_CS5B
		INC	CX
		CMP	SI,BP			;判结束?
		JB	L_CS5A
		JMP	SHORT L_CS5C
L_CS5B:
		DEC	SI			;不等区尾
L_CS5C:
		MOV	CX,SI
		POP	SI
		SUB	CX,SI
		INC	CX
L_CS5D:
		SUB	SI,2			;不等区首
L_CS6:
		CMP	CX,127			;>127?
		JBE	L_CS6A
		SUB	CX,127
		PUSH	CX
		MOV	CX,127
		MOV	[DI],CL 		;不等字节计数
		INC	DI
		REP	MOVSB			;传送不等字节
		POP	CX
		JMP	SHORT L_CS6
L_CS6A:
		MOV	[DI],CL 		;不等字节计数
		INC	CX
		INC	DI
		REP	MOVSB			;传送不等字节
		CMP	SI,BP			;判结束?
		JZ	L_CS7
		JMP	L_CS3
L_CS7:
		MOV	CX,DI
		SUB	CX,D_BUF3		;CX=不等区长度
		POP	SI
		MOV	DX,CX
		PUSH	CX
		CALL	L_DYFS0 		;数据字节数和'W'
		POP	CX
		MOV	SI,D_BUF3
L_CS8:
		LODSB				;取一字节
		CALL	S_01A0			;送打印机
		LOOP	L_CS8
L_CS9:
		POP	BP
		POP	CX
		RET

;子程序:打印页号
S_DYYH:
		MOV	AX,D_0203		;页号
		OR	AX,AX			;=0不打页号
		JZ	L_DYYH7
		MOV	CX,10
		MOV	SI,OFFSET D_YH1
L_DYYH1:
		XOR	DX,DX
		DIV	CX
		OR	DL,'0'
		MOV	[SI],DL 		;写页号
		DEC	SI
		OR	AX,AX
		JNZ	L_DYYH1
		MOV	BYTE PTR [SI],' '       ;8.11
		SUB	SI,2
		MOV	WORD PTR [SI],0A4A9H	;'─'
		CALL	S_0466
L_DYYH2:
		LODSB				;取字符
		OR	AL,AL			;结束?
		JZ	L_DYYH6
		OR	DL,DL			;前字节?
		JZ	L_DYYH5
L_DYYH3:
		CALL	S_03EA			;计算列数
		XOR	DL,DL
L_DYYH4:
		CALL	S_03D7			;写入缓冲区
		JMP	SHORT L_DYYH2
L_DYYH5:
		CMP	AL,0A1H 		;判汉字?
		JB	L_DYYH3
		MOV	DL,AL			;存前字节
		JMP	SHORT L_DYYH4
L_DYYH6:
		PUSH	D_0200
		MOV	D_JZ,-1 		;居中标志
		MOV	D_0200,0		;不处理换页和页号
		CALL	S_0450			;打印
		POP	D_0200
		INC	D_0203			;页号+1
L_DYYH7:
		CALL	S_PAGE			;换页			INT60
		CALL	S_YS			;执行页首空
		RET

;子程序:取参数
S_Q:
		XOR	CH,CH
		CMP	AL,'0'                  ;判数字?
		JB	L_Q1
		CMP	AL,'9'
		JA	L_Q1
		PUSH	AX
		AND	AL,0FH
		MOV	CL,AL
		MOV	AX,0AH			;=10
		MUL	D_022E			;原值*10
		ADD	AX,CX
		MOV	D_022E,AX		;暂存
		POP	AX
		STC
		RET
L_Q1:
		MOV	CX,D_022E		;参数
		MOV	D_022E,0
		CLC
		RET

;子程序:处理字号CX 返回:CH-高,CL-宽
S_ZH		PROC	NEAR
		MOV	BX,OFFSET D_ZH		;字号表
		CMP	CL,7
		JA	L_ZH1
S_ZH1:
		ADD	BX,CX
		MOV	AL,[BX] 		;取宽(180DPI)
		CBW
		CALL	S_DPI
		MOV	CL,AL			;宽
		MOV	CH,AL			;高
		RET
S_DPI:						;按分辨率折算(AX,返回AX)
		PUSH	DX
		MUL	D_DPI
		MOV	BX,180
		DIV	BX
		POP	DX
		RET
L_ZH1:
		MOV	AL,CL
		XOR	AH,AH
		MOV	CL,10
		DIV	CL
		MOV	DL,AH			;个位
		CMP	DL,3			;=012为小字号
		JAE	L_ZH2
		MOV	BX,OFFSET D_ZH1 	;小字号表
L_ZH2:
		CBW
		MOV	CX,AX
		CALL	S_ZH1			;取基本字号

		OR	DL,DL			;个位=0?
		JZ	L_ZH4
		TEST	DL,1			;=1或3?
		JZ	L_ZH3
		MOV	AL,CL
		CALL	S_43			;*3/4
		MOV	CL,AL
		JMP	SHORT L_ZH4
L_ZH3:
		MOV	AL,CH
		CALL	S_43			;*3/4
		MOV	CH,AL
L_ZH4:
		RET
S_43:
		MOV	DH,3
		MUL	DH			;*3
		SHR	AX,1			;/4
		SHR	AX,1
		RET
S_ZH		ENDP

;子程序:处理字高CH
S_HIGH:
		MOV	D_0213B,CH		;高度
		PUSH	AX
		MOV	AL,CH
		XOR	AH,AH
		MOV	BL,24
		DIV	BL
		OR	AH,AH
		JNZ	L_HIGH1
		DEC	AX
L_HIGH1:
		MOV	D_0214,AL		;行数
		POP	AX
		RET
S_HIGH1:
		CALL	S_HIGH
		MOV	BL,D_0214
		CMP	BL,D_0210		;与已指定行数比
		JBE	L_HIGH2
		MOV	D_0210,BL
L_HIGH2:
		RET

;子程序:设置字型 入口:AL 返回:CH行数,CL=列数
S_ZX:
		MOV	D_ZX0,AL
		CMP	AL,'a'
		JB	L_ZX1
		SUB	AL,'a'
		MOV	DI,OFFSET D_ZX1
		JMP	SHORT L_ZX2
L_ZX1:
		SUB	AL,'A'
		MOV	DI,OFFSET D_ZX
L_ZX2:
		MOV	AH,AL
		SHL	AL,1
		ADD	AL,AH			;AL*3
		CBW
		ADD	DI,AX
		MOV	CX,WORD PTR DS:[DI]	;取字宽CL和高CH
		MOV	AL,DS:[DI+2]		;取字型

		CMP	D_FBL,'/'               ;仅字型按分辨率折算?
		JZ	L_ZX20
		CMP	D_FBL,'&'               ;字型和行距按分辨率折算?
		JNZ	L_ZX3
L_ZX20:
		PUSH	AX
		MOV	AL,CL
		XOR	AH,AH
		CALL	S_DPI			;按分辨率折算
		MOV	CL,AL
		MOV	AL,CH
		XOR	AH,AH
		CALL	S_DPI			;按分辨率折算
		MOV	CH,AL
		POP	AX
		TEST	AL,80H
		JNZ	L_ZX3
		CMP	D_ZX0,'q'
		JA	L_ZX2B
		CMP	D_ZX0,'a'
		JAE	L_ZX2A
		CMP	D_ZX0,'P'
		JA	L_ZX2B
		SHR	AL,1
		SHR	AL,1
L_ZX2A:
		SHR	AL,1
		SHR	AL,1
		AND	AL,3
		OR	AL,80H
		JMP	SHORT L_ZX3
L_ZX2B:
		MOV	AL,80H
L_ZX3:
		MOV	D_0213A,CL		;列数
		MOV	D_0213B,CH		;高度

		TEST	AL,80H
		JZ	L_ZX4
		AND	AL,7FH
		MOV	D_0213C,AL		;字体号
		MOV	AL,80H
L_ZX4:
		MOV	D_0213,AL		;字型

		MOV	AL,CH
		XOR	AH,AH
		DEC	AX
		MOV	CH,24
		DIV	CH
		MOV	CH,AL			;行数
		MOV	D_0214,AL		;行数
		RET

;子程序:处理行距CL
S_HJ:
		XOR	CH,CH
		MOV	DX,CX
		SHL	DX,1
		ADD	DX,CX			;AL*3
		SHR	DX,1			;AL/2
		MOV	D_0215,DL		;置行距

		CMP	D_FBL,'&'               ;字型和行距按分辨率折算?
		JNZ	L_HJ3
		CMP	D_0213B,40		;字型高=24?
		JNZ	L_HJ3
		CMP	DL,30
		JA	L_HJ3
		PUSH	AX
		CMP	DL,15
		JAE	L_HJ1
		MOV	AL,1
		JMP	SHORT L_HJ2
L_HJ1:
		MOV	AL,5
		MUL	DL
		MOV	DL,3
		DIV	DL
		SUB	AL,24
L_HJ2:
		MOV	D_0215,AL
		POP	AX
L_HJ3:
		RET

;子程序:处理字符间距CX
S_ZJ:
		CMP	CX,100H
		JAE	L_ZJ2
		CMP	D_FBL,'&'               ;按分辨率折算?
		JZ	L_ZJ0
		CMP	D_FBL,'/'               ;按分辨率折算?
		JNZ	L_ZJ1
L_ZJ0:
		PUSH	AX
		MOV	AX,CX
		CALL	S_DPI			;按分辨率折算
		MOV	CX,AX
		POP	AX
L_ZJ1:
		MOV	D_0217,CX		;置字符间距
L_ZJ2:
		RET

D_WHZ		DW	0
D_WZF		DW	0
;子程序:处理行禁则
S_PB:
		RET				;=90H打开,=0C3H关闭
		DEC	D_ZJJ			;字间距计数-1
		MOV	DL,AL
		CMP	AL,0A1H 		;判汉字?
		JB	L_PB1
		MOV	DH,AL
		MOV	DL,D_021F		;汉字前字节
		MOV	D_WHZ,BX
		SHR	BX,1
		MOV	D_WZF,BX
		JMP	SHORT L_PB2
L_PB1:
		MOV	D_WZF,BX
		SHL	BX,1			;折汉字宽
		MOV	D_WHZ,BX
L_PB2:
		MOV	DI,OFFSET D_P		;下移存放区
		XOR	CX,CX			;    列数
		XOR	BP,BP
		CALL	S_FINDS
		CMP	D_P,0
		JNZ	L_PB3
		CALL	S_FINDW 		;查找行尾
L_PB3:
		MOV	AX,CX			;下移列数
		ADD	AX,D_0220
		SUB	AX,D_0209
		XOR	DX,DX
		DIV	D_ZJJ
		MOV	D_ZJA,AX		;字间距增量
		MOV	AX,D_ZJJ
		SUB	AX,DX
		MOV	D_ZJB,AX		;从此再+1
		MOV	AX,D_0220
		MOV	D_0209,AX
		RET
;子程序:行禁则处理 AL或AX-行尾,DI-下移存放区指针 返回:CX-下移列宽
						;BP=1:行首找到,>1行尾找到
S_FINDS:
		CMP	DL,0A1H 		;下行首字符为汉字?
		JAE	L_FS1
		MOV	SI,OFFSET D_LTOP1	;行首禁则字符
		CALL	S_FINDDL		;查
		JNB	L_FS3
		JMP	SHORT L_FS2		;找到
L_FS1:
		MOV	SI,OFFSET D_LTOP	;行首禁则符号
		CALL	S_FINDDX
		JNB	L_FS3
L_FS2:
		RET
L_FS3:						;行首找到------
		INC	BP
		MOV	SI,D_0205		;输入缓冲区指针
		MOV	DL,[SI-1]		;行尾字符
		CMP	DL,0A1H 		;判汉字?
		JB	L_FS4
		MOV	DX,[SI-2]		;行尾汉字
		MOV	BX,2
		SUB	D_0205,BX		;指针-2
		CALL	S_POR			;后移
		MOV	[DI],DX
		ADD	DI,2
		MOV	AX,D_WHZ
		JMP	SHORT L_FS5
L_FS4:
		MOV	BX,1
		DEC	D_0205			;指针-1
		CALL	S_POR
		MOV	[DI],DL
		INC	DI
		MOV	AX,D_WZF
L_FS5:
		ADD	CX,AX
		DEC	D_ZJJ
		CMP	BP,1
		JNZ	S_FINDS
		MOV	BYTE PTR [DI],0
		JMP	SHORT S_FINDS
S_FINDW:
		MOV	BP,-1
		CALL	S_POR
		MOV	SI,D_0205		;输入缓冲区指针
		MOV	DL,[SI-1]		;行尾字符
		CMP	DL,0A1H 		;判汉字?
		JAE	L_FW1
		MOV	SI,OFFSET D_LEND1	;行尾禁则字符
		CALL	S_FINDDL		;查
		JNB	L_FW2
L_FW0:						;行尾未找到----
		MOV	BYTE PTR [DI],0
		RET
L_FW1:
		MOV	DX,[SI-2]
		MOV	SI,OFFSET D_LEND	;行尾禁则符号
		CALL	S_FINDDX		;查
		JB	L_FW0
		SUB	D_0205,2		;指针-2
		MOV	[DI],DX
		ADD	DI,2
		MOV	AX,D_WHZ
		MOV	BX,2
		JMP	SHORT L_FW3
L_FW2:						;找到处理字符-
		DEC	D_0205			;指针-1
		MOV	[DI],DL
		INC	DI
		MOV	BX,1
		MOV	AX,D_WZF
L_FW3:
		ADD	CX,AX
		DEC	D_ZJJ
		JMP	SHORT S_FINDW

;子程序:下移字符区后移BX字节
S_POR:
		CMP	BP,1			;行首找到?
		JZ	L_PR3
		MOV	SI,OFFSET D_P
L_PR1:
		LODSB
		OR	AL,AL
		JNZ	L_PR1
		CMP	BP,-1			;
		JNZ	L_PR2
		DEC	SI
		MOV	DI,SI
		RET
L_PR2:
		DEC	SI
		MOV	AL,[SI]
		MOV	[BX+SI],AL
		CMP	SI,OFFSET D_P
		JNZ	L_PR2
L_PR3:
		MOV	DI,OFFSET D_P
		RET
;子程序:查找字符 SI-查找区,DL-待查字符
S_FINDDL:
		LODSB
		OR	AL,AL
		JZ	L_FIND1
		CMP	DL,AL
		JNZ	S_FINDDL
		CLC
		RET
;子程序:查找符号 SI-查找区,DL-待查符号
S_FINDDX:
		LODSW
		OR	AX,AX
		JZ	L_FIND1
		CMP	DX,AX
		JNZ	S_FINDDX
		CLC
		RET
L_FIND1:
		STC
		RET

D_LEND		DB	'“‘《',0,0            ;行尾
D_LEND1 	DB	'([',0
D_LTOP		DB	'”’》，。；、？！',0,0  ;行首
D_LTOP1 	DB	',;?!)]',0

;子程序:打印预处理
S_STAR:
		MOV	SI,0A0H 		;打印预处理命令串
S_DYZF:
		LODSB
		CBW
		MOV	CX,AX
L_DYZF1:
		LODSB
		CALL	S_01A0
		LOOP	L_DYZF1
		RET

;子程序:终止光栅
S_DYEND:
		MOV	SI,0B8H
		JMP	SHORT S_DYZF

;子程序:换页(复位)
S_PAGE:
		MOV	SI,0B0H
		JMP	SHORT S_DYZF

;子程序:设置打印份数AL
S_DYFS:
		CBW
		MOV	DX,AX
		MOV	SI,0D0H
		CALL	S_DYZF
L_DYFS0:
		LODSB
		OR	AL,AL
		JNZ	L_DYFS1
		RET
L_DYFS1:
		CMP	AL,'1'
		JB	L_DYFS2
		CMP	AL,'9'
		JA	L_DYFS2
		AND	AL,0FH
		MOV	BL,AL			;数字
		JMP	SHORT L_DYFS0
L_DYFS2:
		CMP	AL,'a'                  ;ASCII码
		JNZ	L_DYFS6
		MOV	AX,DX
		XOR	DX,DX
		CMP	AX,1000
		JAE	L_DYFS3A
		CMP	BL,4
		JB	L_DYFS3
L_DYFS3A:
		MOV	CX,1000
		CALL	S_DIVAL
L_DYFS3:
		CMP	BL,3
		JB	L_DYFS4
		MOV	CX,100
		CALL	S_DIVAL
L_DYFS4:
		CMP	BL,2
		JB	L_DYFS5
		MOV	CX,10
		CALL	S_DIVAL
L_DYFS5:
		OR	AL,'0'
		CALL	S_01A0
		JMP	L_DYFS0
L_DYFS6:
		CMP	AL,'b'                  ;十六进制数?
		JNZ	L_DYFS8
		MOV	AL,DL
		CALL	S_01A0
		CMP	BL,2
		JNZ	L_DYFS7
		MOV	AL,DH
		CALL	S_01A0
L_DYFS7:
		JMP	L_DYFS0
L_DYFS8:
		CMP	AL,'c'                  ;高位在前,低位在后?
		JNZ	L_DYFS9
		MOV	AL,DH
		CALL	S_01A0
		MOV	AL,DL
L_DYFS9:
		CALL	S_01A0
		JMP	L_DYFS0
S_DIVAL:
		DIV	CX
		OR	AL,'0'
		CALL	S_01A0
		MOV	AX,DX
		XOR	DX,DX
		RET

;子程序:光标位置向上DX
S_DYUP:
		MOV	SI,0C0H
		CALL	S_DYZF
		MOV	AL,'-'
		CALL	S_01A0
		JMP	L_DYFS0

;子程序:光标位置向下DX
S_DYDN:
		MOV	SI,0C0H
		CALL	S_DYZF
		MOV	AL,'+'
		CALL	S_01A0
		JMP	L_DYFS0

;子程序:设置正常方位
S_SET0:
		MOV	SI,0E0H
		CALL	S_DYZF
		MOV	AX,D_0221		;行总宽
		MOV	DX,D_0228		;页高度
L_SET0:
		CMP	AX,DX			;比?
		JB	L_SET00
		MOV	DX,D_0228
		MOV	D_0228,AX
		MOV	D_0220,AX
		MOV	D_0220,DX
		MOV	D_0221,DX
L_SET00:
		RET

;子程序:设置旋转90度
S_SET90:
		MOV	SI,0F0H
		CALL	S_DYZF
		MOV	AX,D_0228		;页高度
		MOV	DX,D_0221		;最总宽
		JMP	L_SET0

S_AH00		ENDP

;----------------------------------------------------------------------------
INT_7C		PROC	FAR
		MOV	CX,10H			;16点阵
		JMP	SHORT L_7B01
INT_7C		ENDP

INT_7B		PROC	FAR
		MOV	CX,18H			;24点阵
		MOV	AL,AH
		AND	AL,0F0H
		CMP	AL,10H			;判隔点扩?
		JNZ	L_7B01
		MOV	CL,CS:D_0213A		;字型列数
		AND	AH,0FCH
L_7B01:
		PUSH	CS
		POP	DS
		XOR	SI,SI
		MOV	AX,80H
L_7B02:
		MOV	BYTE PTR [SI],0
		INC	SI
		DEC	AX
		JNZ	L_7B02
		XOR	SI,SI
		IRET
INT_7B		ENDP

INT_7D		PROC	FAR
		MOV	CL,CS:D_0213A		;字型列数
		XOR	CH,CH
		OR	DH,DH
		JNZ	L_7B01
		SHR	CX,1
		JMP	L_7B01
INT_7D		ENDP

;子程序:向打印机输出一个字节-------------------------------------------------
S_01A0		PROC	NEAR
		MOV	AH,2			;取打印机状态
		CALL	S_01A2
		TEST	AH,29H			;检查错误?
		JNZ	S_01A0
		XOR	AH,AH
S_01A2:
		PUSH	DX
		MOV	DX,CS:K_PORT		;0号打印口
		PUSHF
		CALL	CS:D_INT17
		POP	DX
		MOV	BYTE PTR CS:D_0207+1,AH ;状态
		RET
S_01A0		ENDP

;子程序:输出一字节图形数据
S_015A		PROC	NEAR
		TEST	BYTE PTR CS:D_020D,7	;判背景?
		JZ	L_0179
		PUSH	BP
		PUSH	AX
		MOV	AL,CS:D_020D		;功能字节2
		AND	AL,7			;背景号
		MOV	AH,8
		MUL	AH
		AND	BP,7			;取当前列末三位
		ADD	BP,AX
		POP	AX
		OR	AL,CS:D_0230-8[BP]	;迭加背景图形字节
		POP	BP
L_0179:
		TEST	BYTE PTR CS:D_020E,1	;反白?
		JZ	L_0183
		NOT	AL
L_0183:
		TEST	BYTE PTR CS:D_020D,8	;轻打?
		JZ	S_0190
		TEST	BP,1			;判奇数列?
		JZ	S_0190
		XOR	AL,AL			;变空列
S_0190:
		MOV	DI,CS:D_DI		;取指针
		CMP	DI,CS:D_BUF2		;判第一缓冲区尾?
		JZ	L_01A1
		MOV	CS:[DI],AL		;写入缓冲区
		INC	DI			;指针+1
		MOV	CS:D_DI,DI		;存指针
L_01A1:
		RET
S_015A		ENDP

D_BP		DW	0
D_CX		DW	0			;屏幕行数计数
D_ORCX		DB	0			;叠加行数
D_OR		DW	0

;****************************************************************************
BEGIN:
		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_S30
L_S10:
		LODSB
		CMP	AL,' '
		JBE	L_S10
		CMP	AL,'/'
		JNZ	L_S30
		LODSB
		CMP	AL,'?'                  ;显示帮助?
		JNZ	L_S20
		MOV	DX,OFFSET MSG
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_S20:
		AND	AL,5FH
		CMP	AL,'S'                  ;设置排版参数?
		JNZ	L_S22
		JMP	L_SET
L_S22:
		CMP	AL,'N'                  ;驻留基本内存
		JNZ	L_S30
		MOV	D_RAM,AL
L_S30:
		MOV	DL,1
		CMP	AL,'1'                  ;判有打印机号?
		JB	L_S31
		CMP	AL,'9'
		JA	L_S31
		AND	AL,0FH
		MOV	DL,AL
		LODSB
		CMP	AL,'0'                  ;十位?
		JB	L_S31
		CMP	AL,'9'
		JA	L_S31
		AND	AL,0FH
		XCHG	AL,DL
		MOV	AH,10
		MUL	AH
		ADD	AL,DL
		MOV	DL,AL
L_S31:
		MOV	DS:[100H],DL		;存打印机号

		MOV	AX,-1
		INT	17H
		CMP	AX,-2130H		;是否已装载?
		JNZ	L_S33
		MOV	DX,OFFSET ALREDY
		JMP	SHORT L_ERR
L_S33:
		MOV	AX,3517H		;取原INT17
		INT	21H
		MOV	WORD PTR D_INT17,BX	;保存
		MOV	WORD PTR D_INT17+2,ES
		PUSH	CS
		POP	ES

		MOV	DX,OFFSET F_HP		;'HP.COM'
		MOV	AX,3D00H
		INT	21H
		JNB	L_S48
L_S47:
		MOV	DX,OFFSET NOHP
		JMP	L_ERR
L_S48:
		MOV	BX,AX
		MOV	DX,OFFSET D_END
		MOV	CX,-1
		MOV	AH,3FH			;读打印机参数文件
		INT	21H
		MOV	DX,AX			;读出长度
		MOV	AH,3EH			;关闭
		INT	21H
		OR	DX,DX			;判空文件?
		JZ	L_S47
		MOV	AX,DX
		XOR	DX,DX
		MOV	CX,128			;每打印机字节数
		DIV	CX			;AX=打印机数+1
		MOV	DL,DS:[100H]
		CMP	AL,DL
		JA	L_S50
		MOV	DL,1
L_S50:
		MOV	AL,128
		MUL	DL
		ADD	AX,OFFSET D_END
		MOV	SI,AX
		MOV	DI,80H
		MOV	CX,128
		REP	MOVSB			;传送

		MOV	SI,80H
		MOV	AX,DS:[SI+6]		;打印机分辨率
		MOV	D_DPI,AX
		MOV	AX,DS:[SI+2]		;最大宽度(列数)
		MOV	D_0220,AX
		MOV	D_0221,AX
		MOV	AX,DS:[SI+4]		;最大高度(点行)
		MOV	D_0228,AX
		MOV	D_0200,AX
		MOV	DX,AX
		SHR	DX,1			;DX/8=宽度(字节数)
		SHR	DX,1
		SHR	DX,1
		MOV	CX,AX
		SHL	AX,1
		ADD	AX,CX			;*3
		ADD	AX,512
		ADD	AX,OFFSET BEGIN
		MOV	D_BUF2,AX		;第一缓冲区尾
		ADD	AX,DX			;+一行
		MOV	D_BUF3,AX
		ADD	AX,DX			;+一行
		MOV	BP,AX

		MOV	AX,CS
		CMP	AX,0A000H		;判LH?
		JA	L_S80
		CMP	D_RAM,'N'               ;驻留基本内存
		JZ	L_S80
		CALL	S_GETUMB		;分配UMB段
		JZ	L_S90
L_S80:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		CALL	S_SETINT
		MOV	DX,BP			;驻留
		INT	27H
L_S90:
		MOV	AX,D_UMB
		OR	AX,AX
		JZ	L_S80
		DEC	AX
		MOV	ES,AX
		MOV	DI,8
		MOV	SI,OFFSET D_NAME
		MOV	CX,6
		REP	MOVSB			;向UMB文件控制块写入本模块名

		MOV	ES,D_UMB		;段
		XOR	SI,SI
		MOV	DI,SI
		MOV	CX,OFFSET BEGIN
		REP	MOVSB			;拷贝本模块到UMB
		PUSH	ES
		POP	DS

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
		MOV	AX,BP
		MOV	CL,4
		SHR	AX,CL
		INC	AX
		MOV	D_LEN,AX		;本模块驻留长度(节)

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

S_SETINT	PROC	NEAR
		MOV	DX,OFFSET INT_17	;建中断
		MOV	AX,2517H
		INT	21H

		MOV	AX,357BH		;取INT7B
		INT	21H
		OR	BX,BX
		JNZ	L_SI1
		MOV	DX,OFFSET INT_7B
		MOV	AX,257BH		;建中断
		INT	21H
L_SI1:
		MOV	AX,357CH		;取INT7C
		INT	21H
		OR	BX,BX
		JNZ	L_SI2
		MOV	DX,OFFSET INT_7C
		MOV	AX,257CH		;建中断
		INT	21H
L_SI2:
		MOV	AX,357DH		;取INT7D
		INT	21H
		OR	BX,BX
		JNZ	L_SI3
		MOV	DX,OFFSET INT_7D
		MOV	AX,257DH		;建中断
		INT	21H
L_SI3:
		RET
S_SETINT	ENDP

;----------------------------------------------------------------------------
L_SET:
		MOV	DX,OFFSET D_PBMSG	;'** 设  置  排  版  参  数 **'
		MOV	AH,9
		INT	21H
		XOR	BP,BP
		MOV	SI,OFFSET D_PBCS	;排版参数表
L_SET1:
		MOV	DI,OFFSET D_PBCSB
		MOV	CX,30
		MOV	AL,' '
		REP	STOSB			;清空
		MOV	AX,BP
		INC	AX
		OR	AL,30H
		MOV	D_PBCSB+3,AL		;序号
		MOV	DI,OFFSET D_PBCSB+9
		LODSW				;页长
		CALL	S_JS
		MOV	DI,OFFSET D_PBCSB+15
		LODSW				;页首
		CALL	S_JS
		MOV	DI,OFFSET D_PBCSB+21
		LODSW				;左空
		CALL	S_JS
		MOV	DI,OFFSET D_PBCSB+27
		LODSW				;行宽
		CALL	S_JS
		MOV	DX,OFFSET D_PBCSB
		MOV	AH,9			;显示
		INT	21H
		MOV	AX,12
		MUL	BP
		ADD	AX,OFFSET D_PBBZ	;备注
		MOV	BX,AX
		MOV	CX,12
L_SET2:
		MOV	DL,[BX]
		INC	BX
		MOV	AH,2			;显示
		INT	21H
		LOOP	L_SET2
		MOV	AX,0E0DH		;回车
		INT	10H
		MOV	AX,0E0AH		;换行
		INT	10H
		INC	BP
		CMP	BP,6
		JNZ	L_SET1
L_SET3:
		MOV	DX,OFFSET D_JRXH	;'请 键 入 序 号: $'
		MOV	AH,9
		INT	21H
L_SET4:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,1BH			;ESC?
		JNZ	L_SET5
		JMP	L_SET10
L_SET5:
		CMP	AL,0DH			;回车
		JZ	L_SET
		CMP	AL,'1'                  ;判1~6
		JB	L_SET4
		CMP	AL,'6'
		JA	L_SET4
		MOV	DL,AL
		MOV	AH,2			;显示序号
		INT	21H
		DEC	AX
		AND	AL,0FH
		PUSH	AX
		MOV	AH,8
		MUL	AH
		ADD	AX,OFFSET D_PBCS
		MOV	DI,AX			;参数写入地址
		POP	AX
		MOV	AH,12
		MUL	AH
		ADD	AX,OFFSET D_PBBZ
		MOV	BP,AX			;备注写入地址

		MOV	DX,OFFSET D_YC		;'页长(单位：行): $'
		MOV	AH,9
		INT	21H
		CALL	S_INPUT 		;键入
		JB	L_SET6A
		MOV	[DI],AX 		;写入
L_SET6A:
		ADD	DI,2
		MOV	DX,OFFSET D_YS		;'页首(单位：点): $'
		MOV	AH,9
		INT	21H
		CALL	S_INPUT 		;键入
		JB	L_SET6
		MOV	[DI],AX 		;写入
L_SET6:
		ADD	DI,2
		MOV	DX,OFFSET D_ZK		;'左空(单位：点): $'
		MOV	AH,9
		INT	21H
		CALL	S_INPUT 		;键入
		JB	L_SET7
		MOV	[DI],AX 		;写入
L_SET7:
		ADD	DI,2
		MOV	DX,OFFSET D_HK		;'行宽(单位：点): $'
		MOV	AH,9
		INT	21H
		CALL	S_INPUT 		;键入
		JB	L_SET8
		MOV	[DI],AX 		;写入
L_SET8:
		MOV	DX,OFFSET D_BZ		;'备注(12个字符): $'
		MOV	AH,9
		INT	21H
		MOV	DX,OFFSET D_INPUT	;键入缓冲区
		MOV	SI,DX
		MOV	WORD PTR [SI],13	;限制12个字符
		MOV	AH,0AH			;键入
		INT	21H
		INC	SI
		LODSB
		OR	AL,AL			;判无键入?
		JZ	L_SET9
		CBW
		MOV	CX,AX
		MOV	DI,BP
		REP	MOVSB			;传送
		MOV	CX,12
		SUB	CX,AX
		JZ	L_SET9			;是否12?
		MOV	AL,' '
		REP	STOSB			;补空格
L_SET9:
		JMP	L_SET3
L_SET10:
		MOV	DX,OFFSET D_CP		;'1-存盘并写入内存, 2-仅存盘: '
		MOV	AH,9
		INT	21H
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,'1'                  ;判1(写入排版参数?
		JNZ	L_SET11
		MOV	AX,3517H		;取INT17段
		INT	21H
		MOV	SI,OFFSET D_PBCS
		MOV	DI,SI
		MOV	CX,6*4
		REP	MOVSW			;传送排版参数
		JMP	SHORT L_SET12
L_SET11:
		CMP	AL,'2'                  ;判2(存盘)?
		JNZ	L_SET15
L_SET12:
		MOV	DS,DS:[2CH]		;环境变量段
		XOR	SI,SI
		XOR	AX,AX
L_SET13:
		CMP	DS:[SI],AX		;查找环境区尾?
		JZ	L_SET14
		INC	SI
		JMP	SHORT L_SET13
L_SET14:
		ADD	SI,4
		MOV	DX,SI			;调出文件名(带路径)
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
L_SET15:
		INT	20H

S_JS		PROC	NEAR
		MOV	CX,10
L_JS1:
		XOR	DX,DX
		DIV	CX
		OR	DL,30H
		MOV	[DI],DL
		DEC	DI
		OR	AX,AX
		JNZ	L_JS1
		RET
S_JS		ENDP

;子程序:键入数字 返回BX
S_INPUT 	PROC	NEAR
		MOV	SI,OFFSET D_INPUT	;键入缓冲区
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
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_IN1
L_IN3:
		DEC	SI			;位置-1
L_IN4:
		MOV	AH,0EH			;退格
		INT	10H
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
		JZ	L_IN8
		AND	AL,0FH
		CBW
		PUSH	AX
		MOV	AX,10
		MUL	BX
		MOV	BX,AX
		POP	AX
		ADD	BX,AX
		JMP	SHORT L_IN7
L_IN8:
		MOV	AX,BX
		CLC
		RET
L_IN9:
		STC
		RET
S_INPUT 	ENDP

D_NAME		DB	'PRTH',0
D_PBMSG 	DB	13,10,'** 设  置  排  版  参  数 **',13,10
		DB	'序号  页长  页首  左空  行宽  备注',13,10,'$'
D_PBCSB 	DB	'                              $'
D_PBBZ		DB	'HP-3 A4纸   '          ;排版参数信息
		DB	'HP-3 B5纸   '
		DB	'BJ10 A4-360 '
		DB	'BJ10 B5-360 '
		DB	'HP-4 A4纸   '
		DB	12 DUP(' ')
D_JRXH		DB	13,10,'请键入序号(回车-重显,ESC-退出): $'
D_YC		DB	13,10,'页长度(单位：点): $'
D_YS		DB	13,10,'页首空(单位：点): $'
D_ZK		DB	13,10,'左边空(单位：点): $'
D_HK		DB	13,10,'行宽度(单位：点): $'
D_BZ		DB	13,10,'备  注(12个字符): $'
D_CP		DB	13,10,'1-存盘并写入内存, 2-仅存盘, 其他-退出: $'
D_INPUT 	DB	15 DUP(0)

F_HP		DB	'HP.COM',0
NOHP		DB	'未找到打印机参数文件 HP.COM!',7,13,10
ALREDY		DB	'已经安装过本模块!',7,13,10,'$'

MSG		DB	'2.13L 汉字系统-97 页式打印机驱动程序  1997年3月',13,10
		DB	'命令行参数: PRTH [1-99][/S]',13,10
		DB	'      其中: [1-99]-打印机号',13,10
		DB	'            [/S]-设置排版参数',13,10,'$'

;----------------------------------------------------------------------------
;命令集 'ESC+I+N1+N2+...图象打印(后跟3*(N1*256+N2)字节图形数据.N1和N2为字节码0-255)',13,10
;	'ESC+I+A~x      设置字型        ;ESC+W          执行INT5',13,10
;	'ESC+I+＇       取消`功能       ;ESC+I+`        恢复`功能',13,10
;	'ESC+I+\        取消软回车8D0A  ;ESC+I+/        恢复软回车8D0A为0D0A',13,10
;	' `@n1,n2,n3`   设置字型(n1为横向宽度,n2为纵向高度,n3为字体号)',13,10
;	' `@A~x`        设置字型(默认A字型)',13,10
;	' `@/&或\`      按打印分辨率折算(`@/`仅字型`@A~x`有效,`@&`字型和行距,`@\`关闭)',13,10
;	' `@@字号,n3`   设置字号(字号0=90,1=72,2=48,3=40,4=32,5=24,6=20,7-16.为180DPI)',13,10
;	'       小字号:10=80,20=60,30=44,40=36,50=28,60=22,70=18',13,10
;	'       可按分辨率折算.个位:12小字号,34标准字号.奇数宽减为3/4,偶数高减为3/4',13,10
;	' `@-或=`       多行字型空行走纸一行(`@-`,默认)或多行(`@=`)',13,10
;	' `&1~255`      设置行距(以1/120英寸为单位)',13,10
;	' `^0~255`      设置字符间距(点)',13,10
;	' `#1~65535`    设置页长(0为整页.=255不打印页号.`##`强制换页',13,10
;	' `[0~2447`     设置左边空(单位:点列)',13,10
;	' `]1~2447`     设置行宽(单位:点列)',13,10
;	' `|1~2447`     水平定位(点)',13,10
;	' `~列数`       输出空列(点)',13,10
;	' `%0~7`        设置背景(0无,1网点,2网格,3横线,4竖线,5右斜线,6左斜线,7交叉线',13,10
;	" `'版号,页号`  设置排版:取消软回车、行禁则、打印页号初值1、多行字空行空多行",13,10
;	'               有版号则按排版参数设置页长、左空和行宽,否则保持原值(需重新设置)',13,10
;	'               版号后有页号则设置初始打印页号(缺省1.-0不打页号,=65535连续打印)',13,10
;	' `:`           初始化打印参数.若原排版则打印末页页号.当前行回车换行无效',13,10
;	' `,`           本行居中打印            `,,`    本行居右打印',13,10
;	' `[[空格数`    段排版第二行后行首加空格数',13,10
;	' `{`           页旋转打印(横式)        `￥...￥`     直送打印机',13,10
;	' `}`           恢复竖式打印            `.`     暂停打印',13,10
;	' `*份数`       设置打印份数            `(`     左旋90度',13,10
;	' `;`           抽点(轻打)              `)`     右旋90度',13,10
;	' `\`           反白                    `?`     停止旋转',13,10
;	' `/`           上划线                  `+`     上标字符',13,10
;	' `_`           下划线                  `-`     下标字符',13,10
;	' `=`           正常(清以上四项)        `!`     正常字符',13,10,'$'

D_END	EQU	$

SEG_A		ENDS
		END	START

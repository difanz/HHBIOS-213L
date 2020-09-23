;	HGA.ASM (2.13L)
;	1996.1.4, 1.19, 2.10, 3.6, 3.12, 3.31, 5.20, 12.4
;	1997.2.20, 7.7, 9.11
;	1998.8.9

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

IN_INT10	DB	0
	;[0F4H] 1-安装KZZF,2-保持提示行,4-显示用BIOS,8-不显示提示信息
	;[0F5H] 1-直接写屏,2-图形方式打开B8,4-显示中断调BIOS,8-光标下移
	;[0F6H] 1-原有方式,2-固定光标,4-初始化寄存器,8-AH=0B调BIOS
	;[0F7H] =1~9提示行光带色,其他:关闭屏幕分割
	;[100H] 中西文显示方式开关	=0西文,=1汉字
	;[101H] 光标开关		位0=0无,=1有光标
	;[102H] 当前光标状态		=0无光标,=0FFH有
D_INT10 	DD	0			;原INT10
D_INT8		DD	0			;原INT8
D_INT16 	DW	0			;键盘模块段
		INCLUDE ZF80.INC
D_0050		DB	0			;前字节
D_0051		DB	0			;      属性
D_0052		DW	0			;      位置
D_0058		DB	0			;提示行列位置
D_0059		DB	0			;      行号,无(=0)
D_005A		DB	1			;=1:直接写屏
D_005B		DB	16H			;提示行浮动行号
D_005E		DW	2			;光标高度
D_0060		DB	0			;=0属性高位高亮,=1异或,=2闪烁
D_0062		DB	0			;提示行汉字前字节
D_0064		DB	7			;对外显示方式
D_A000		DW	0B800H
D_B800		DW	0B000H
D_0068		DW	0			;保存光标位置
D_0069		DB	1			;=0繁体,非0简体
D_ZJXP		DB	2			;直接写屏周期

D_AH		DW	OFFSET L_AH00		;AH=0
D_AH01		DW	OFFSET L_AH01		;AH=1
		DW	OFFSET L_AH02		;AH=2
		DW	OFFSET L_INT10		;AH=3
		DW	OFFSET L_INT10		;AH=4
		DW	OFFSET L_AH05		;AH=5
		DW	OFFSET L_AH06		;AH=6
		DW	OFFSET L_AH07		;AH=7
		DW	OFFSET L_AH08		;AH=8
		DW	OFFSET L_AH09		;AH=9
		DW	OFFSET L_AH09		;AH=0AH
		DW	OFFSET L_RET		;AH=0BH
		DW	OFFSET L_AH0C		;AH=0CH
		DW	OFFSET L_AH0D		;AH=0DH
		DW	OFFSET L_AH0E		;AH=0EH
		DW	OFFSET L_INT10		;AH=0FH
		DW	OFFSET L_INT10		;AH=10H
		DW	OFFSET L_INT10		;AH=11H
		DW	OFFSET L_INT10		;AH=12H
		DW	OFFSET L_AH13		;AH=13H
		DW	OFFSET L_AH14		;AH=14H
		DW	OFFSET L_AH15		;AH=15H
		DW	OFFSET L_AH16		;AH=16H
		DW	OFFSET L_AH17		;AH=17H
		DW	OFFSET L_AH18		;AH=18H

INT_10		PROC	FAR
		STI
		CLD
		CMP	AH,-1			;判安装?		2.10
		JNZ	L_00
		MOV	AX,48H			;HGA-'H'
		IRET
L_00:
		MOV	CS:IN_INT10,0FFH
		OR	AH,AH
		JZ	L_01
		CMP	AH,18H			;功能号>18H?
		JZ	L_01
		JA	L_10
		CMP	BYTE PTR CS:[100H],0	;判西文方式?
		JZ	L_10
L_01:
		PUSH	DS			;保存现场
		PUSH	ES
		PUSH	BP
		PUSH	SI
		PUSH	DI
		PUSH	DX
		PUSH	CX
		PUSH	BX
		PUSH	AX

		CMP	CS:D_005A,1		;判直接写屏?
		JNZ	L_02
		CMP	AH,6
K_10ZJXP	EQU	$
		JMP	L_02			;若改JB则直接写屏
		CMP	AH,7			;3.12
		JBE	L_INT10
L_02:
		XOR	DI,DI			;0→DS
		MOV	DS,DI
		XCHG	AL,AH
		MOV	DI,AX
		AND	DI,7FH
		SHL	DI,1
		XCHG	AL,AH
		JMP	CS:D_AH[DI]
L_INT10:
		POP	AX			;恢复现场并执行原INT10
		POP	BX
		POP	CX
		POP	DX
		POP	DI
		POP	SI
		POP	BP
		POP	ES
		POP	DS
L_10:
		MOV	CS:IN_INT10,0
		JMP	CS:D_INT10
L_RET:
		POP	AX			;恢复现场并返回
L_RET1:
		POP	BX
L_RET3:
		POP	CX
		POP	DX
		POP	DI
		POP	SI
		POP	BP
L_RET2:
		POP	ES
		POP	DS
		MOV	CS:IN_INT10,0
		IRET
INT_10		ENDP

INT_1D		DB	38H, 28H, 2DH, 0AH, 1FH, 6, 19H, 1CH
		DB	2, 7, 6, 7, 0, 0, 0, 0
		DB	71H, 50H, 5AH, 0AH, 1FH, 6, 19H, 1CH
		DB	2, 7, 6, 7, 0, 0, 0, 0
D_MOD9		DB	35H, 28H, 2DH, 7, 64H, 0DH, 64H, 64H
		DB	2, 3, 6, 7, 0, 0, 0, 0
		DB	61H, 50H, 52H, 0FH, 19H, 6, 19H, 19H
		DB	2, 0DH, 0BH, 0CH, 0, 0, 0, 0

;AH=0 设置显示方式AL
L_AH00:
		MOV	BX,AX
		MOV	BYTE PTR CS:K_INT8,0EBH ;JMP 关闭INT8		3.30
		MOV	ES,CS:D_INT16		;键盘模块段

		AND	AL,7FH
		CMP	AL,4
K_VJXP	EQU	$-1
		JB	L_0010
		CMP	AL,7
K_VJXP1 EQU	$-1
		JZ	L_0010

		CMP	AL,9
D_6	EQU	$-1
		JZ	L_0020

		MOV	ES:[101H],AL
		MOV	CS:[100H],AH		;西文显示方式
		MOV	AX,BX
		JMP	L_INT10
L_0010:
		MOV	CS:D_005A,1
		MOV	CS:D_0064,3
		MOV	CS:D_B800,0B000H
		JMP	SHORT L_0030
L_0020:
		MOV	CS:D_005A,0
		MOV	CS:D_0064,9
L_0030:
		MOV	BYTE PTR ES:[101H],9
		CLI
		MOV	DX,3BFH
		MOV	AL,3
		OUT	DX,AL			;打开HGA卡
		MOV	DX,3B8H
		MOV	AL,2
		OUT	DX,AL
		MOV	DX,3B4H
		MOV	BX,OFFSET D_MOD9
		XOR	AL,AL
L_0032:
		MOV	AH,CS:[BX]
		OUT	DX,AX
		INC	BX
		INC	AL
		CMP	AL,10H
		JB	L_0032

		PUSH	CS
		POP	ES			;CS→ES
		MOV	DI,OFFSET D_XPQ 	;虚屏区首址
		MOV	CX,25*80
		MOV	AX,720H
		REP	STOSW			;清虚屏区

		MOV	DI,0B000H
		MOV	ES,DI
		XOR	DI,DI
		MOV	CX,25*80
		REP	STOSW			;清写屏区
		MOV	DI,8000H
		MOV	CX,4000H
		XOR	AX,AX
		REP	STOSW			;清实屏区

		MOV	DX,3B8H
		MOV	AL,8AH
		OUT	DX,AL
		MOV	DS:[465H],AL
		STI
		MOV	WORD PTR DS:[44AH],50H
		MOV	WORD PTR DS:[463H],3B4H

		CMP	CS:D_005A,0		;判直接写屏?
		JZ	L_0040
		MOV	BYTE PTR CS:K_INT8,75H	;JNZ 打开INT8		3.30
		MOV	WORD PTR DS:[44CH],1000H
L_0040:
		MOV	AL,CS:D_0064
		MOV	DS:[449H],AL
		MOV	CS:D_0059,0
		MOV	BYTE PTR CS:[102H],0
		MOV	WORD PTR CS:[100H],101H ;汉字方式,打开光标
		MOV	WORD PTR DS:[460H],0B0CH
		XOR	DX,DX
		MOV	CS:D_0068,DX
		CALL	S_XSGB			;显示光标
		JMP	L_RET

;AH=1 设置光标大小 CH=起始扫描线,CL=终止线
L_AH01:
		CLI
		OR	CX,CX
		JZ	L_0103
		CALL	S_QGB
		PUSH	CX
		AND	CX,1F1FH
		CMP	CL,CH
		JNB	L_0101
		MOV	CH,CL
L_0101:
		SUB	CL,CH
		INC	CX
		CMP	CL,15
		JBE	L_0102
		MOV	CL,15
L_0102:
		XOR	CH,CH
		MOV	CS:D_005E,CX
		POP	AX
		MOV	BYTE PTR CS:[101H],0
		TEST	AH,20H
		JNZ	L_0103
		MOV	BYTE PTR CS:[101H],1
		CALL	S_GB
L_0103:
		STI
		JMP	L_RET

;AH=2 设置光标位置DX,BH=页号
L_AH02:
		CLI
		CMP	CS:D_0059,0		;判有无提示行?
		JZ	L_0201
		CMP	DH,CS:D_0059		;定位行是否提示行?
		JNZ	L_0201
		MOV	AX,1404H		;关闭提示行
		INT	10H
L_0201:
		CMP	CS:D_005A,0		;判图形方式?
		JNZ	L_0202
		MOV	DS:[450H],DX
		JMP	SHORT L_0203
L_0202:
		PUSH	BX
		MOV	AL,BH
		MOV	BL,BH
		XOR	BH,BH
		SHL	BX,1
		MOV	DS:[BX+450H],DX 	;设置光标位置
		POP	BX
		CMP	AL,DS:[462H]		;判是否当前页?
		JNZ	L_0204
L_0203:
		CALL	S_GB			;显示光标
L_0204:
		STI
		MOV	AH,2
		JMP	L_INT10

;AH=5 选择显示页 AL
L_AH05: 	CMP	CS:D_005A,0
		JZ	L_0501
		MOV	DS:[462H],AL
		CLI
		PUSH	AX
		MOV	CL,4
		SHL	AL,CL
		MOV	DS:[44FH],AL
		POP	AX
		ADD	AL,0B0H
		MOV	AH,AL
		XOR	AL,AL
		MOV	CS:D_B800,AX
		STI
L_0501:
		JMP	L_RET

D_SI		DW	0
D_DI		DW	0
D_67		DB	0
;AH=6 上滚当前页  AL=行数,CX=左上角,DX=右下角,BH=空行填充属性
L_AH06:
		CALL	S_QGB			;关光标
		MOV	CS:D_67,AH
		CMP	CS:D_0059,0
		JZ	L_0602
		PUSH	AX
		MOV	AX,1404H
		INT	10H
		POP	AX
L_0602:
		CMP	CS:D_005A,0
		JZ	L_0603
		CLI
L_0603:
		CALL	S_GDHS			;判滚动行数
		MOV	AX,CX			;左上角
		CALL	S_GDFW			;滚动范围,CS→DS,CS→ES
		ADD	SI,AX
		ADD	D_SI,BP
		MOV	BP,4*80

		OR	BL,BL			;滚动行=0?
		JNZ	L_0604
		MOV	BL,DH
		JMP	SHORT L_0606
L_0604:
		MOV	AH,DH
		SUB	AH,BL
L_0605:
		CALL	S_XPGD			;虚屏上滚一行
		ADD	SI,160			;指向下一行
		ADD	DI,160
		ADD	D_SI,BP
		ADD	D_DI,BP
		DEC	AH
		JNZ	L_0605
L_0606:
		MOV	AH,BH			;恢复空行填充属性
		OR	AH,AH			;属性=0?
		JNZ	L_0607
		MOV	AH,7
L_0607:
		SHR	BH,1			;实际的空行填充属性
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
L_0608:
		CALL	S_KHTC			;空行填充
		ADD	DI,160			;指向下一行
		ADD	D_DI,BP
		DEC	BL
		JNZ	L_0608

		JMP	L_RET

;子程序:判滚动行数
S_GDHS		PROC	NEAR
		CMP	CH,24
		JBE	L_HS1
		MOV	CH,24
L_HS1:
		CMP	CL,79
		JBE	L_HS2
		MOV	CL,79
L_HS2:
		CMP	DH,24
		JBE	L_HS3
		MOV	DH,24
L_HS3:
		CMP	DL,79
		JBE	L_HS4
		MOV	DL,79
L_HS4:
		MOV	BL,AL			;滚动行数
		OR	AL,AL			;=0?
		JZ	L_HS5
		PUSH	AX
		MOV	AL,DH
		SUB	AL,CH
		INC	AL			;窗口行
		CMP	AL,BL			;>=滚动行
		POP	AX
		JA	L_HS5
		XOR	BL,BL
L_HS5:
		RET
S_GDHS		ENDP

;子程序:滚动范围
S_GDFW		PROC	NEAR
		SUB	DX,CX
		ADD	DX,101H 		;DH=窗口行,DL=宽

		PUSH	CS
		POP	DS			;CS→DS
		PUSH	CS
		POP	ES			;CS→ES

		PUSH	DX
		PUSH	AX
		MOV	CL,AL			;列
		MOV	AL,AH			;行
		CBW
		MOV	DX,4*80 		;每行4*80字节
		MUL	DX
		XOR	CH,CH
		ADD	AX,CX
		MOV	D_SI,AX 		;起点在显示缓冲区地址
		MOV	D_DI,AX
		POP	AX
		POP	DX

		MOV	CL,AL			;列
		MOV	AL,80
		MUL	AH			;行*80
		XOR	CH,CH
		ADD	AX,CX			;+列
		SHL	AX,1
		ADD	AX,OFFSET D_XPQ
		MOV	SI,AX			;虚屏区地址
		MOV	DI,AX

		PUSH	DX
		MOV	AL,BL			;滚动行数
		CBW
		MOV	DX,4*80 		;每行4*80字节
		MUL	DX
		MOV	BP,AX			;滚动字节数
		POP	DX

		MOV	AL,80
		MUL	BL			;滚动行
		SHL	AX,1			;虚屏滚动区大小

		XOR	CH,CH
		RET
S_GDFW		ENDP

;子程序:虚屏滚动一行
S_XPGD		PROC	NEAR
		PUSH	AX
		MOV	CL,DL
		CMP	CS:D_67,6
		JNZ	L_GD3
		PUSHF				;保存方向标志
		PUSH	SI
		PUSH	DI
		DEC	CX
		SHL	CX,1
		ADD	SI,CX			;移行尾
		ADD	DI,CX
		MOV	CL,DL
		MOV	AL,0A1H
		STD
L_GD1:
		CMP	[SI],AL
		JNB	L_GD2
		CMPSW				;判两行相同?
		LOOPZ	L_GD1
		INC	CX
L_GD2:
		POP	DI
		POP	SI
		POPF				;恢复方向标志
L_GD3:
		MOV	AL,CL
		PUSH	SI
		PUSH	DI
		REP	MOVSW			;虚屏滚动
		POP	DI
		POP	SI

		PUSH	SI
		PUSH	DI
		CMP	CS:D_005A,0
		JZ	L_GD3A
		MOV	ES,D_B800
		MOV	DS,D_B800
		SUB	SI,OFFSET D_XPQ
		SUB	DI,OFFSET D_XPQ
		MOV	CL,AL
		REP	MOVSW			;写屏区滚动
L_GD3A:
		MOV	DS,CS:D_A000		;显示缓冲区段
		MOV	ES,CS:D_A000
		MOV	SI,CS:D_SI		;本行首显示缓冲区地址
		MOV	DI,CS:D_DI
		MOV	AH,4
		CMP	CS:D_67,7
		JZ	L_GD5
L_GD4:
		CALL	S_GD
		SUB	SI,5FB0H		;-6000H+50H
		SUB	DI,5FB0H
		DEC	AH
		JNZ	L_GD4
		JMP	SHORT L_GD6
L_GD5:
		CALL	S_GD
		SUB	SI,6050H
		SUB	DI,6050H
		DEC	AH
		JNZ	L_GD5
L_GD6:
		POP	DI
		POP	SI

		POP	AX
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		RET
S_XPGD		ENDP

S_GD		PROC	NEAR		;滚动
		CALL	S_GD2
		CALL	S_GD1
		CALL	S_GD1
S_GD1:
		ADD	SI,2000H
		ADD	DI,2000H
S_GD2:
		PUSH	SI
		PUSH	DI
		MOV	CL,AL
		REP	MOVSB
		POP	DI
		POP	SI
		RET
S_GD		ENDP

;子程序:空行填充
S_KHTC		PROC	NEAR
		MOV	AL,' '
		MOV	CL,DL
		PUSH	DI
		REP	STOSW			;虚屏区填充
		POP	DI

		PUSH	DI
		CMP	CS:D_005A,0
		JZ	L_TC1A
		MOV	ES,D_B800		;写屏区段
		SUB	DI,OFFSET D_XPQ
		MOV	CL,DL
		REP	STOSW			;写屏区填充
L_TC1A:
		MOV	ES,D_A000		;显示缓冲区段
		MOV	DI,D_DI 		;本行首在显示缓冲区地址
		MOV	AL,BH
		MOV	DH,4
L_TC1:
		MOV	CL,DL
		PUSH	DI
L_TC2:
		MOV	ES:[DI+2000H],AL
		MOV	ES:[DI+4000H],AL
		MOV	ES:[DI+6000H],AL
		STOSB
		LOOP	L_TC2
		POP	DI
		CMP	CS:D_67,6
		JZ	L_TC3
		SUB	DI,80
		JMP	SHORT L_TC4
L_TC3:
		ADD	DI,80
L_TC4:
		DEC	DH
		JNZ	L_TC1
		POP	DI

		PUSH	CS
		POP	ES
		RET
S_KHTC		ENDP

;AH=7 下滚当前页 AL=行数,CX=左上角,DX=右下角,BH=空行填充属性
L_AH07:
		CALL	S_QGB			 ;关光标
		MOV	CS:D_67,AH
		CMP	CS:D_0059,0
		JZ	L_0702
		PUSH	AX
		MOV	AX,1404H
		INT	10H
		POP	AX
L_0702:
		CMP	CS:D_005A,0
		JZ	L_0703
		CLI
L_0703:
		STD
		CALL	S_GDHS			;判滚动行数
		MOV	AX,DX			;右下角
		CALL	S_GDFW			;滚动范围,CS→DS
		SUB	SI,AX
		ADD	D_SI,3*80
		ADD	D_DI,3*80
		SUB	D_SI,BP
		MOV	BP,4*80

		OR	BL,BL
		JNZ	L_0704
		MOV	BL,DH
		JMP	SHORT L_0706
L_0704:
		MOV	AH,DH
		SUB	AH,BL
L_0705:
		CALL	S_XPGD			;虚屏下滚一行
		SUB	SI,160			;指向下一行
		SUB	DI,160
		SUB	D_SI,BP
		SUB	D_DI,BP
		DEC	AH
		JNZ	L_0705
L_0706:
		MOV	AH,BH			;恢复空行填充属性
		OR	AH,AH			;属性=0?
		JNZ	L_0707
		MOV	AH,7
L_0707:
		SHR	BH,1			;实际的空行填充属性
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
L_0708:
		CALL	S_KHTC			;空行填充
		SUB	DI,160			;指向下一行
		SUB	D_DI,BP
		DEC	BL
		JNZ	L_0708

		CLD
		JMP	L_RET

;AH=8 读当前光标位置字符AL及属性AH
L_AH08: 	CALL	S_XPDZ			;计算当前光标在虚屏区地址→SI
		MOV	AX,WORD PTR CS:D_XPQ[SI]
		POP	BX
		JMP	L_RET1

;子程序:计算当前光标在虚屏区地址→SI
S_XPDZ		PROC	NEAR
		PUSH	BX
		CALL	S_DQGB
		POP	BX
		PUSH	AX
		PUSH	BX
		MOV	AX,DX
		MOV	BL,AL
		MOV	AL,80
		MUL	AH
		XOR	BH,BH
		ADD	AX,BX
		SHL	AX,1
		MOV	SI,AX
		POP	BX
		POP	AX
		RET
S_XPDZ		ENDP

;AH=9,0AH 写光标位置字符AL及属性BL CX=个数,BH=页号
L_AH09:
		OR	CX,CX			;字符个数=0?
		JZ	L_0906
		CALL	S_QGB			;关光标

		CALL	S_XPDZ			;计算当前光标在虚屏区地址→SI
		CMP	CS:D_005A,0
		JZ	L_0903
		CLI
		PUSH	BX
		XOR	BL,BL
		ADD	BH,0B0H
		MOV	ES,BX
		POP	BX

		MOV	DI,SI
		PUSH	CX
L_0901:
		STOSB				;向写屏区写字符及属性
		CMP	AH,0AH
		JZ	L_0902
		MOV	ES:[DI],BL
L_0902:
		INC	DI
		LOOP	L_0901
		POP	CX

		CMP	BH,DS:[462H]		;判是否当前页?
		JNZ	L_0908
L_0903:
		CMP	DH,24
		JA	L_0906
		ADD	SI,OFFSET D_XPQ
		PUSH	CX
L_0904:
		MOV	CS:[SI],AL		;写入字符代码
		CMP	AH,0AH
		JZ	L_0905
		MOV	CS:[SI+1],BL		;写入字符属性
L_0905:
		ADD	SI,2
		LOOP	L_0904
		POP	CX

		CMP	AH,0AH
		JNZ	L_0906
		MOV	BL,CS:[SI-1]		;取字符属性
L_0906:
		XOR	BP,BP
	;	CMP	CS:D_005A,0		;4.26
	;	JZ	L_0906A
		CMP	CS:D_0060,1
		JNZ	L_0907
L_0906A:
		TEST	BL,80H			;异或方式?
		JZ	L_0907
		NOT	BP
L_0907:
		CALL	S_XS			;显示
L_0908:
		JMP	L_RET			;返回

;子程序:显示
S_XS		PROC	NEAR
		CMP	AL,0FFH 		;字符ASC码=0FFH?
		JZ	L_XSZF
K_HZ	EQU	$-2
		CMP	AL,0A0H 		;判汉字?
		JBE	L_XSZF
		CMP	CX,1
		JNZ	L_XSZF
		OR	BP,BP
		JNZ	L_XSZF
		CMP	CS:D_0050,0		;有前字节?
		JNZ	L_XS1
L_XS0:
		MOV	CS:D_0050,AL		;存前字节
		MOV	CS:D_0051,BL		;	 属性
		MOV	CS:D_0052,DX		;	 位置
		JMP	SHORT L_XSZF		;按扩展ASC码显示前字节
L_XS2:
		INC	DX
		JMP	SHORT L_XS0		;按扩展ASC码显示后字节
L_XS1:
		OR	DL,DL			;左边一位
		JZ	L_XS0
		DEC	DX
		CMP	DX,CS:D_0052		;是否前字节?
		JNZ	L_XS2
		MOV	AH,CS:D_0050		;取前字节
		MOV	BH,CS:D_0051		;存后字节属性
	;子程序:显示汉字 前字节AH,属性BH,位置DX,后字节AL,属性BL
S_XSHZ:
		PUSH	DX
		CALL	S_ZMZH			;读字库并转换→DS:SI=60H
		POP	DX			;左半区位置
		CALL	S_SPDZ			;计算光标DX在实屏区地址→DI
		PUSH	BX
		MOV	BL,BH			;前字节属性
		CALL	S_ZMXS			;字模送显示缓冲区
		INC	DI			;指向右半区
		POP	BX			;后字节属性
		MOV	SI,70H
		CALL	S_ZMXS			;字模送显示缓冲区
		MOV	CS:D_0050,0		;清前字节
		RET

	;子程序:显示字符AL DX=光标位置,CX=个数,BL=属性
S_XSZF:
		OR	CX,CX
		JZ	L_ZF4
L_XSZF:
		CMP	CS:D_005A,1		;判直接写屏?
		JNZ	L_ZF1
		PUSH	BX
		CALL	S_ALVB			;转西文制表符
		POP	BX
L_ZF1:
		CALL	S_ZFZH			;读字符库并转换→DS:SI=60H
		CALL	S_SPDZ			;计算光标DX在实屏区地址→DI
L_ZF2:
		PUSH	SI
		CALL	S_ZMXS			;显示字符
		POP	SI
		INC	DL
		CMP	DL,80
		JNZ	L_ZF3
		XOR	DL,DL
		CMP	DH,18H
		JZ	L_ZF3
		INC	DH
L_ZF3:
		CALL	S_SPDZ
		LOOP	L_ZF2
L_ZF4:
		RET
S_XS		ENDP

D_K		DW	1			;=1:加宽
;子程序:字模送显示缓冲区
S_ZMXS		PROC	NEAR
		PUSH	DI
		PUSH	CX
		PUSH	DX
		MOV	CX,4
L_ZM1:
		LODSB
		TEST	BL,70H
		JZ	L_ZM2
		NOT	AL
L_ZM2:
		CMP	CS:D_K,2
		JZ	L_ZM3A
		OR	BP,BP			;异或方式?
		JZ	L_ZM3
		XOR	AL,ES:[DI]
L_ZM3:
		MOV	ES:[DI],AL
		JMP	SHORT L_ZM3C
L_ZM3A:
		CALL	S_KZ
		OR	BP,BP			;异或方式?
		JZ	L_ZM3B
		XOR	AL,ES:[DI]
		XOR	AH,ES:[DI+1]
L_ZM3B:
		MOV	ES:[DI],AX
L_ZM3C:
		LODSB
		TEST	BL,70H
		JZ	L_ZM4
		NOT	AL
L_ZM4:
		CMP	CS:D_K,2
		JZ	L_ZM5A
		OR	BP,BP
		JZ	L_ZM5
		XOR	AL,ES:[DI+2000H]
L_ZM5:
		MOV	ES:[DI+2000H],AL
		JMP	SHORT L_ZM5C
L_ZM5A:
		CALL	S_KZ
		OR	BP,BP
		JZ	L_ZM5B
		XOR	AL,ES:[DI+2000H]
		XOR	AH,ES:[DI+2001H]
L_ZM5B:
		MOV	ES:[DI+2000H],AX
L_ZM5C:
		LODSB
		TEST	BL,70H
		JZ	L_ZM6
		NOT	AL
L_ZM6:
		CMP	CS:D_K,2
		JZ	L_ZM7A
		OR	BP,BP
		JZ	L_ZM7
		XOR	AL,ES:[DI+4000H]
L_ZM7:
		MOV	ES:[DI+4000H],AL
		JMP	SHORT L_ZM7C
L_ZM7A:
		CALL	S_KZ
		OR	BP,BP
		JZ	L_ZM7B
		XOR	AL,ES:[DI+4000H]
		XOR	AH,ES:[DI+4001H]
L_ZM7B:
		MOV	ES:[DI+4000H],AX
L_ZM7C:
		LODSB
		TEST	BL,70H
		JZ	L_ZM8
		NOT	AL
L_ZM8:
		CMP	CS:D_K,2
		JZ	L_ZM9A
		OR	BP,BP
		JZ	L_ZM9
		XOR	AL,ES:[DI+6000H]
L_ZM9:
		MOV	ES:[DI+6000H],AL
		JMP	SHORT L_ZM9C
L_ZM9A:
		CALL	S_KZ
		OR	BP,BP
		JZ	L_ZM9B
		XOR	AL,ES:[DI+6000H]
		XOR	AH,ES:[DI+6001H]
L_ZM9B:
		MOV	ES:[DI+6000H],AX
L_ZM9C:
		ADD	DI,80
		LOOP	L_ZMA
		POP	DX
		POP	CX
		POP	DI
		RET
L_ZMA:
		JMP	L_ZM1
;子程序:字节AL扩展AL->AX
S_KZ:
		MOV	CH,8
L_KZ1:					       ;扩展
		RCL	AL,1
		LAHF
		RCL	DX,1
		SAHF
		RCL	DX,1
		DEC	CH
		JNZ	L_KZ1
		MOV	AX,DX
		XCHG	AH,AL
		RET
S_ZMXS		ENDP

;子程序:计算光标DX在实屏区地址→DI
S_SPDZ		PROC	NEAR
		PUSH	AX
		PUSH	DX
		PUSH	BX
		MOV	BX,DX
		MOV	AL,DH			;行号
		CBW
		MOV	DX,4*80 		;每字符行占实屏区字节数
		MUL	DX			;行首地址
		XOR	BH,BH
		ADD	AX,BX
		MOV	DI,AX			;实屏区地址
		MOV	AX,0B800H
		MOV	ES,AX
		POP	BX
		POP	DX
		POP	AX
		RET
S_SPDZ		ENDP

	INCLUDE GB.INC

;子程序:显示光标
S_XSGB		PROC	NEAR
		NOT	BYTE PTR CS:[102H]
S_XSGB0:
		MOV	CX,CS:D_005E
		OR	CX,CX
		JZ	L_GB5
S_XSGB1:
		CMP	DL,4FH
		JBE	L_GB3
		RET
L_GB3:
		PUSH	ES
		CALL	S_SPDZ			;计算光标DX在实屏区地址→DI

		ADD	DI,3*80
L_GB4:
		NOT	BYTE PTR ES:[DI+6000H]
		DEC	CX
		JZ	L_GB4A
		NOT	BYTE PTR ES:[DI+4000H]
		DEC	CX
		JZ	L_GB4A
		NOT	BYTE PTR ES:[DI+2000H]
		DEC	CX
		JZ	L_GB4A
		NOT	BYTE PTR ES:[DI]
		SUB	DI,80
		DEC	CX
		JNZ	L_GB4
L_GB4A:
		POP	ES
L_GB5:
		STI
		RET
S_XSGB		ENDP

;AH=0DH 读点 CX=列, DX=行 AL=点色值
L_AH0D: 	CALL	S_DWZ
		MOV	SI,AX
		MOV	AL,ES:[SI]
		ROL	AL,CL
		MOV	CL,7
		SHR	AL,CL
		JMP	L_RET

;AH=0CH 写点 AL=点色值(位7=1异或), CX=列, DX=行
L_AH0C: 	PUSH	AX
		CALL	S_DWZ
		MOV	SI,AX
		MOV	BL,ES:[SI]
		ROL	BL,CL
		POP	AX
		AND	AL,81H
		JS	L_0C02
		ROR	AL,1
		AND	BL,7FH
		OR	BL,AL
L_0C01:
		ROR	BL,CL
		MOV	ES:[SI],BL
		JMP	L_RET
L_0C02:
		AND	AL,1
		ROR	AL,1
		XOR	BL,AL
		JMP	SHORT L_0C01
;子程序:计算点位置
S_DWZ		PROC	NEAR
		MOV	AX,0B800H
		MOV	ES,AX
		XOR	AX,AX
		SHR	DX,1
		JNB	L_DWZ1
		ADD	AX,2000H
L_DWZ1:
		SHR	DX,1
		JNB	L_DWZ2
		ADD	AX,4000H
L_DWZ2:
		XCHG	AX,DX
		MOV	AH,50H
		MUL	AH
		ADD	DX,AX
		MOV	AX,CX
		MOV	CL,8
		DIV	CL
		MOV	CL,AH
		XOR	AH,AH
		ADD	AX,DX
		RET
S_DWZ		ENDP

	INCLUDE AH0E.INC
	INCLUDE AH13.INC

;AH=14H 提示行管理
;	AL=0 清提示行
;	AL=1 显示字符DL CL=个数
;	AL=2 提示行光标定位DL
;	AL=3 显示字符DL并推进光标
;	AL=4 关闭提示行
;	AL=5 设置提示行颜色BL及浮动位置BH
;	AL=6 取显示参数 AL=显示方式,AH=最大色号
;			BL=显示工作方式,BH=浮动位置
;			CL=显示行数,CH=每行扫描线数
;			DL=显示控制参数,DH=提示行当前行号
;			SI=横向点数,DI=纵向扫描线数
;			BP=显示缓冲区段
;	AL=7 设置对外显示方式BH
;	AL=8 位置DX处字符反相显示
;	AL=9 在指定位置DX显示字符BH
;	AL=10 在指定位置DL显示BL属性BP:SI处的点阵64字节
;	AL=11 设置光标闪烁周期BH
;	AL=12 取虚屏区地址 BX:AX
;	AL=13 直接写屏周期BH
;	AL=14 取西文制表符转换表地址 BX:AX				1.18
;	AL=15 在指定位置DX显示加宽字符串DS:SI(属性BL)
L_AH14:
		OR	AL,AL			;<清提示行>
		JNZ	L_1410
		MOV	CS:D_0058,AL		;提示行定位在左端
		MOV	CS:D_0062,AL
		CMP	CS:D_0059,AL		;提示行已打开?
		JNZ	L_1402
		MOV	DH,18H
		CMP	DH,DS:[451H]		;是否第18H行?
		JNZ	L_1401
		MOV	DH,CS:D_005B		;取浮动位置
L_1401:
		MOV	CS:D_0059,DH		;置提示行位置
		XOR	DL,DL
		CALL	S_SPDZ			;计算光标DX在实屏区地址→DI
		MOV	SI,DI
		MOV	DI,OFFSET D_TUXBC
		MOV	CX,80*4
L_1401A:
		MOV	AL,ES:[SI]
		MOV	AH,ES:[SI+2000H]
		MOV	CS:[DI],AX
		MOV	AL,ES:[SI+4000H]
		MOV	AH,ES:[SI+6000H]
		MOV	CS:[DI+2],AX
		INC	SI
		ADD	DI,4
		LOOP	L_1401A
		CALL	S_TXGB
L_1402:
		MOV	DL,' '
		MOV	CX,80
L_1403:
		MOV	BL,7
		CALL	S_TXZF			;清提示行
L_1405:
		JMP	L_RET
L_1410:
		CMP	AL,1			;<写字符DL>
		JNZ	L_1420
		OR	CX,CX
		JZ	L_1405
		CALL	S_DKTX
		JMP	SHORT L_1403
L_1420:
		CMP	AL,2			;<光标定位>
		JNZ	L_1430
		CALL	S_DKTX
		CALL	S_TXGB
		CMP	DL,79
		JA	L_1423			;9.29
		MOV	CS:D_0058,DL
L_1422:
		CALL	S_TXGB
L_1423:
		JMP	L_RET
L_1430:
		CMP	AL,3			;<写字符并推进光标>
		JNZ	L_1440
		CMP	DL,7			;响铃?
		JNZ	L_1431
		MOV	AX,0E07H
		INT	10H
		JMP	L_RET
L_1431:
		CALL	S_DKTX
		CMP	DL,8			;退格?
		JNZ	L_1433
		CALL	S_TXGB
		MOV	AL,CS:D_0058		;取提示行光标位置
		OR	AL,AL			;=0? (行首)
		JZ	L_1432
		DEC	AX			;光标左移
L_1432:
		MOV	CS:D_0058,AL		;存光标位置
		MOV	DL,' '
		MOV	CX,1
		MOV	BL,7
		CALL	S_TXZF
		JMP	SHORT L_1422
L_1433:
		CALL	S_TXGB
		MOV	CX,1
		CALL	S_TXZF			;显示字符
		MOV	AL,CS:D_0058		;取提示行光标位置
		CMP	AL,79			;判行尾?
		JNB	L_1422
		INC	AX			;光标右移
		MOV	CS:D_0058,AL		;存光标位置
		JMP	SHORT L_1422
L_1440:
		CMP	AL,4			;<关闭提示行>
		JNZ	L_1450
		MOV	DH,CS:D_0059		;取提示行号
		OR	DH,DH			;判有无提示行?
		JZ	L_1442
		XOR	DL,DL			;行首
		MOV	CS:D_0059,DL		;清提示行号
		CALL	S_SPDZ			;计算光标DX在实屏区地址→DI
		MOV	SI,OFFSET D_TUXBC	;提示行保存区
		MOV	CX,80*4
L_1441:
		MOV	AX,CS:[SI]
		MOV	ES:[DI],AL
		MOV	ES:[DI+2000H],AH
		MOV	AX,CS:[SI+2]
		MOV	ES:[DI+4000H],AL
		MOV	ES:[DI+6000H],AH
		ADD	SI,4
		INC	DI
		LOOP	L_1441
L_1442:
		JMP	L_RET
L_1450:
		CMP	AL,5			;<设置提示行浮动位置>
		JNZ	L_1460
		MOV	CS:D_005B,BH
		JMP	L_RET
L_1460:
		CMP	AL,6			;<取显示参数>
		JNZ	L_1470
		MOV	AX,109H 		;AH=最大色号,AL=显示方式
		MOV	BH,CS:D_005B		;提示行浮动位置
		MOV	BL,BYTE PTR CS:K_VJXP
		MOV	CX,1019H		;取每行扫描线数和显示行数
		MOV	DH,CS:D_0059		;提示行位置

		PUSH	AX
		XOR	DL,DL
		MOV	AX,CS:[0F4H]
		SHR	AL,1			;调扩展字符库
		RCR	DL,1			;位5
		SHR	AL,1			;保持提示行打开
		RCR	DL,1			;位6
		SHR	DL,1			;位7
		CMP	CS:D_005A,0		;判直接写屏	9.26
		JZ	L_1463
		OR	DL,80H
L_1463:
		MOV	AL,BYTE PTR CS:D_6	;>5即汉字
		AND	AL,10H
		OR	DL,AL			;位4
		OR	DL,CS:D_0069		;简繁
		POP	AX

		MOV	SI,639			;横向点数
		MOV	DI,399			;纵向扫描线数
		MOV	BP,0B800H
		POP	ES
		POP	ES
		POP	ES
		POP	ES
		POP	ES
		POP	ES
		POP	ES
		JMP	L_RET2
L_1470:
		CMP	AL,7			;<设置对外显示方式>
		JNZ	L_1480
		MOV	CS:D_0064,BH
		MOV	DS:[449H],BH
		JMP	L_RET
L_1480:
		CMP	AL,8			;<位置DX处字符反相>
		JNZ	L_1490
		MOV	CX,16
		CALL	S_XSGB1
		JMP	L_RET
L_1490:
		CMP	AL,9			;<在指定位置DX显示字符BH>
K_1490	EQU	$
		JNZ	L_14A0
		MOV	AL,BH
		XOR	BP,BP
		OR	CX,CX			;=0:按字符显示
		JNZ	L_1491
		INC	CX
		CALL	S_XSZF
		JMP	L_RET
L_1491:
		CMP	CX,-1			;=-1:直接写屏显示
		JZ	L_1492
		CMP	CS:D_005A,1		;判直接写屏?
		JNZ	L_1492
		MOV	AL,80
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX
		SHL	AX,1
		MOV	DI,AX
		MOV	ES,CS:D_B800
		XCHG	BL,BH
		MOV	ES:[DI],BX
		JMP	L_RET
L_1492:
		MOV	CX,1			;否则:可显示汉字
		CALL	S_XS
		JMP	L_RET
L_14A0:
		CMP	AL,10			;<在指定位置DL显示BL属性
		JNZ	L_14B0			; BP:SI处的点阵64字节>
		MOV	DS,BP
		MOV	DH,CS:D_0059		;提示行号
		CALL	S_SPDZ			;计算光标DX在实屏区地址→DI
		XOR	BP,BP
		MOV	CX,4
L_14A1:
		CALL	S_ZMXS
		INC	DI
		LOOP	L_14A1
		JMP	L_RET
L_14B0:
		CMP	AL,11			;<光标闪烁控制>
		JNZ	L_14C0
		MOV	AL,0C3H 		;RET
		OR	BH,BH
		JZ	L_14B1
		MOV	AL,90H			;NOP
L_14B1:
		MOV	BYTE PTR CS:K_GBSS,AL
		MOV	CS:D_NUM1,0
		JMP	L_RET
L_14C0:
		CMP	AL,12			;<取虚屏区地址BX:AX>
		JNZ	L_14D0
		MOV	AX,OFFSET D_XPQ
L_14C1:
		PUSH	CS
		POP	BX
		POP	CX
		POP	CX
		JMP	L_RET3
L_14D0: 					;<直接写屏周期>
		CMP	AL,13
		JNZ	L_14E0
		OR	BH,BH
		JZ	L_14D9
		MOV	CS:D_ZJXP,BH
L_14D9:
		JMP	L_RET
L_14E0:
		CMP	AL,14			;<取西文制表符转换表地址>1.18
		JNZ	L_14F0
		MOV	AX,OFFSET D_ZBFB
		JMP	SHORT L_14C1
L_14F0:
		CMP	AL,15			;<在指定位置DX显示加宽字符串ES:SI,以0结尾>
		JNZ	L_14D9
		MOV	CS:D_K,2		;加宽标志
		MOV	CS:D_0062,0
		XOR	BP,BP
L_14F1:
		MOV	AL,ES:[SI]
		INC	SI
		OR	AL,AL			;结束?
		JZ	L_14F4

		CMP	AL,0A0H 		;判汉字?
		JBE	L_14F3
		CMP	CS:D_0062,0		;有前字节?
		JNZ	L_14F2
		MOV	CS:D_0062,AL		;存
		JMP	SHORT L_14F1
L_14F2:
		MOV	AH,CS:D_0062		;取前字节
		MOV	CS:D_0062,0
		PUSH	ES
		PUSH	BX
		PUSH	DX
		PUSH	SI
		MOV	BH,BL
		CALL	S_XSHZ			;显示汉字
		POP	SI
		POP	DX
		POP	BX
		POP	ES
		ADD	DX,4			;位置后移
		JMP	SHORT L_14F1
L_14F3:
		XOR	DI,DI
		MOV	DS,DI
		PUSH	ES
		PUSH	BX
		PUSH	DX
		PUSH	SI
		MOV	CX,1
		CALL	S_XSZF			;显示字符
		POP	SI
		POP	DX
		POP	BX
		POP	ES
		ADD	DX,2			;位置后移
		JMP	SHORT L_14F1
L_14F4:
		MOV	CS:D_K,1		;清标志
		JMP	L_RET

;子程序:判是否打开提示行
S_DKTX		PROC	NEAR
		CMP	CS:D_0059,0
		JNZ	L_DK1
		MOV	AX,1400H
		INT	10H
L_DK1:
		RET
S_DKTX		ENDP

;子程序:提示行光标处理
S_TXGB		PROC	NEAR
		PUSH	BX
		PUSH	DX
		MOV	DX,WORD PTR CS:D_0058
		CALL	S_XSGB0
		POP	DX
		POP	BX
		RET
S_TXGB		ENDP

;子程序:在提示行写字符
S_TXZF		PROC	NEAR
		XOR	BP,BP
		MOV	AL,DL			;字符
		AND	BL,0EFH
		MOV	DX,WORD PTR CS:D_0058	;位置
		CMP	CS:D_0062,0		;判汉字前字节?
		JNZ	L_TX2
		CMP	AL,0A0H 		;判汉字?
		JBE	L_TX1
		MOV	CS:D_0062,AL		;存汉字前字节
		MOV	CS:D_0051,BL		;存前字节属性
L_TX1:
		JMP	S_XSZF
L_TX2:
		CMP	AL,0A0H
		JBE	L_TX3
		MOV	AH,CS:D_0062		;取前字节
		MOV	BH,CS:D_0051		;存后字节属性
		DEC	DX
		MOV	CS:D_0062,0		;清前字节
		JMP	S_XSHZ			;显示汉字
L_TX3:
		MOV	CS:D_0062,0		;清前字节
		JMP	SHORT L_TX1
S_TXZF		ENDP

;子程序:读字库并转换 DX=汉字内码 →DS:60H
S_ZMZH		PROC	NEAR
		MOV	DX,AX
		MOV	AH,CS:D_0069		;简-繁
		INT	7FH			;读字库并转换
		MOV	DS,DX			;字模段
		XOR	SI,SI			;    偏移
		MOV	DI,60H			 ;转换地址
		MOV	CX,16
L_ZMZH1:
		LODSW
		MOV	CS:[DI],AL		;写左半字
		MOV	CS:[DI+10H],AH		;写右半字
		INC	DI
		LOOP	L_ZMZH1
		PUSH	CS
		POP	DS
		MOV	SI,60H
		RET
S_ZMZH		ENDP

;子程序:读字符库并转换 AL=ASC码 →DS:60H
S_ZFZH1 	PROC	NEAR
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	DI,60H

		PUSH	CX
		MOV	CX,8
		JMP	SHORT L_ZFZH0
S_ZFZH:
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	DI,60H

		PUSH	CX
		MOV	CX,8
		TEST	BYTE PTR CS:[0F4H],4	;=1:显示用KZZF
		JZ	L_ZFZH1
L_ZFZH0:
		TEST	BYTE PTR CS:[0F4H],1	;=1:扩展字符库
		JZ	L_ZFZH1
		MOV	CL,16
		MOV	SI,OFFSET D_KZZFQ
		MUL	CL
		ADD	SI,AX
		REP	MOVSB
		JMP	SHORT L_ZFZH5
L_ZFZH1:
		CMP	AL,80H			;扩展ASC码?
		JB	L_ZFZH3
		SUB	AL,80H
		MUL	CL
		ADD	AX,OFFSET D_ZF80	;自带扩展ASC字符字模
		MOV	SI,AX
L_ZFZH2:
		LODSB
		STOSB
		STOSB
		LOOP	L_ZFZH2
		JMP	SHORT L_ZFZH5
L_ZFZH3:
		MUL	CL
		ADD	AX,0FA6EH		;ROM-BIOS字符库首址
		MOV	SI,AX
		MOV	AX,0F000H
		MOV	DS,AX			;ROM-BIOS段
		XOR	AX,AX
		STOSW
		STOSB
		MOV	CL,4
L_ZFZH4:
		MOVSB
		LODSB
		STOSB
		STOSB
		LOOP	L_ZFZH4
		XOR	AL,AL
		STOSB
		PUSH	CS
		POP	DS
L_ZFZH5:
		POP	CX
		MOV	SI,60H
		RET
S_ZFZH1 	ENDP

;AH=16H 取汉字或字符字模 DX=内码,BP:BX=传送地址
L_AH16: 	OR	DH,DH			;判汉字?
		JZ	L_1601
		CALL	S_ZMZH			;读汉字库并转换
		MOV	ES,BP			;目标段
		MOV	DI,BX			;    偏移
		MOV	CX,16
		REP	MOVSW			;传送
		JMP	L_RET
L_1601:
		CALL	S_ZFZH1 		;读字符库并转换
		MOV	ES,BP			;目标段
		MOV	DI,BX			;    偏移
		MOV	CX,16
		MOVSB				;传送
		JMP	L_RET

;AH=17H 光标控制
L_AH17:
		OR	AL,AL
		JZ	L_1703
		MOV	BYTE PTR CS:[101H],1	;开光标
L_AH15:
		CALL	S_GB
		JMP	L_RET
L_1703:
		CALL	S_QGB
		MOV	CS:[101H],AL		;关光标
		JMP	L_RET

;AH=18H AL=0识别汉字		AL=1不识汉字
;	AL=2属性高位高亮	AL=3异或
;	AL=4不允许设置显示方式	AL=5允许
;	AL=10关闭直接写屏	AL=11恢复直接写屏
;	AL=12西文制表符处理方式
;	AL=13光标大小控制 BH=1由AH=1控制;BH=0,BL=光标大小
;	AL=14显示方式>=6为汉字	AL=15恢复原方式
;	AL=16设置高位闪烁
;	AL=17繁体		AL=18简体
;	AL=19重显屏幕
;	AL=20关闭时钟显示	AL=21恢复时钟显示
;	AL=23清虚屏区
;	AL=28:INT10AH=6~10直接写屏	AL=29恢复
D_AH18		DW	OFFSET L_1800
		DW	OFFSET L_1801
		DW	OFFSET L_1802
		DW	OFFSET L_1803
		DW	OFFSET L_1804
		DW	OFFSET L_1805
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_1810
		DW	OFFSET L_1811
		DW	OFFSET L_1812
		DW	OFFSET L_1813
		DW	OFFSET L_1814
		DW	OFFSET L_1815
		DW	OFFSET L_1816
		DW	OFFSET L_1817
		DW	OFFSET L_1818
		DW	OFFSET L_1819
		DW	OFFSET L_1820
		DW	OFFSET L_1821
		DW	OFFSET L_18000
		DW	OFFSET L_1823
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_1828
		DW	OFFSET L_1829
L_AH18:
		CMP	AL,29
		JA	L_1899
		CBW
		MOV	DI,AX
		SHL	DI,1
		CALL	CS:D_AH18[DI]
L_1899:
		JMP	L_RET
L_1800: 					;<识别汉字>
		MOV	AL,74H			;JZ
L_18001:
		MOV	BYTE PTR CS:K_HZ,AL
		MOV	BYTE PTR CS:K_HZ1,AL
L_18000:
		RET
L_1801: 					;<不识汉字>
		MOV	AL,0EBH 		;JMP SHORT
		JMP	SHORT L_18001
L_1802: 					;<属性高位高亮>
L_1803: 					;<高位异或>
		SUB	AL,2
L_18022:
		MOV	CS:D_0060,AL
		RET
L_1804: 					;<不允许设置显示方式>
		MOV	CS:D_AH,OFFSET L_RET
		RET
L_1805: 					;<允许设置显示方式>
		MOV	CS:D_AH,OFFSET L_AH00
		RET
L_1810: 					;<关闭直接写屏>
		MOV	BYTE PTR CS:K_VJXP,0
		MOV	AX,9			;			9.11
L_1810B:
		INT	10H
L_1810A:
		RET
L_1811: 					;<打开直接写屏>
		TEST	BYTE PTR CS:[0F5H],1	;=1:允许直接写屏
		JZ	L_1810A
		MOV	BYTE PTR CS:K_VJXP,4
		MOV	AX,3			;			9.11
		JMP	SHORT L_1810B
L_1812: 					;<西文制表符处理方式>
		MOV	CS:D_ZBFS,BH
		RET
L_1813: 					;<光标大小控制>
		OR	BH,BH
		JZ	L_18131
		MOV	CS:D_AH01,OFFSET L_AH01
		RET
L_18131:
		MOV	CS:D_AH01,OFFSET L_RET
		MOV	CS:D_005E,BX
		RET
L_1814: 					;<显示方式>=6为汉字>
		MOV	AX,673H
L_18141:
		MOV	BYTE PTR CS:D_6,AH
		MOV	BYTE PTR CS:D_6+1,AL
		RET
L_1815: 					;<恢复原方式>
		MOV	AX,974H
		JMP	SHORT L_18141
L_1816: 					;<高位闪烁>
		MOV	AL,2
		JMP	L_18022
L_1817: 					;<繁体>
L_1818: 					;<简体>
		SUB	AL,17
		MOV	CS:D_0069,AL
		RET
L_1819: 					;<重显屏幕>
		PUSH	CS
		POP	DS
		MOV	SI,OFFSET D_XPQ
		XOR	DX,DX			;窗口左上角
L_1819A:
		LODSW				;取光标处字符及属性
		XCHG	AH,AL
		MOV	BX,AX
		MOV	CX,1
		MOV	AX,1409H		;显示
		INT	10H
		INC	DX
		CMP	DL,80
		JB	L_1819A
		XOR	DL,DL
		INC	DH
		CMP	DH,25
		JB	L_1819A
		CALL	S_XGB
		RET
L_1820: 					;<关闭时钟显示>
		MOV	AL,0EBH
L_18201:
		MOV	BYTE PTR CS:K_1490,AL
		RET
L_1821: 					;<恢复时钟显示>
		MOV	AL,75H
		JMP	SHORT L_18201
L_1823: 					;<清虚屏区>
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_XPQ
		MOV	CX,25*80
		XOR	AX,AX
		REP	STOSW
		RET
L_1828: 					;<INT10AH=6~10直接写屏>
		MOV	AL,72H			;JB
L_18281:
		MOV	BYTE PTR CS:K_10ZJXP,AL
		RET
L_1829: 					;<恢复INT10>
		MOV	AL,0EBH 		;JMP
		JMP	SHORT L_18281

S_SETB8 	PROC	NEAR
		RET
S_SETB8 	ENDP

	INCLUDE INT8.INC
	INCLUDE ZJXP.INC

D_XPQ		DB	25*80*2 DUP(0)		;虚屏区
D_TUXBC 	DB	16*80 DUP(0)		;提示行覆盖区保存
D_KZZFQ 	DB	4096 DUP(0)		;扩展字符库
D_KZZF		DB	'KZZF',0

;****************************************************************************
;程序执行开始
BEGIN:
		MOV	AX,3510H
		INT	21H			;取原INT10地址
		MOV	WORD PTR D_INT10,BX	;保存
		MOV	WORD PTR D_INT10+2,ES
		MOV	AX,3508H
		INT	21H			;取原INT8地址
		MOV	WORD PTR D_INT8,BX	;保存
		MOV	WORD PTR D_INT8+2,ES

		XOR	AX,AX
		MOV	ES,AX
		MOV	BYTE PTR ES:[484H],18H	;显示行数

		XOR	BP,BP
		MOV	AH,2FH			;取键盘模块段
		INT	16H
		OR	BP,BP			;判?
		JNZ	L_S10
		MOV	BP,CS
L_S10:
		MOV	D_INT16,BP		;键盘模块段
		MOV	ES,BP			;键盘模块段	1.20

		MOV	AX,CS
		CMP	AX,BP			;判有无键盘模块?	1.14
		JZ	L_S21
		MOV	AX,ES:[0F4H]		;显示参数
		MOV	DS:[0F4H],AX
		MOV	AX,ES:[0F6H]
		MOV	DS:[0F6H],AX
		PUSH	CS
		POP	ES
		JMP	SHORT L_S22
L_S21:
		MOV	BYTE PTR DS:[0F4H],8	;不显示版本信息
		MOV	BYTE PTR DS:[0F5H],1	;设置直接写屏
		MOV	BYTE PTR DS:[0F6H],1	;原有方式
		MOV	BYTE PTR DS:[0F7H],9	;提示行光带色
L_S22:
		MOV	SI,80H			;命令行参数区首
		LODSB
		OR	AL,AL			;有参数?
		JNZ	L_S30
L_S23:
		JMP	L_S60			;命令行结束
L_S30:
		LODSB
		CMP	AL,' '                  ;空格?
		JZ	L_S30
		CMP	AL,0DH			;结束?
		JZ	L_S23
		CMP	AL,'/'                  ;开关符?
		JNZ	L_S30
		LODSB
		CMP	AL,'?'                  ;<显示帮助>
		JNZ	L_S31
		MOV	DX,OFFSET MSG		;帮助
		MOV	AH,9
		INT	21H
		INT	20H
L_S31:
		AND	AL,5FH
		CMP	AL,'G'                  ;<固定光标2线>
		JNZ	L_S32
		MOV	D_AH01,OFFSET L_RET
		OR	BYTE PTR ES:[0F6H],2
		JMP	L_S30
L_S32:
		CMP	AL,'H'                  ;<显示方式>5即为汉字>
		JNZ	L_S33
		MOV	BYTE PTR D_6,6
		MOV	BYTE PTR D_6+1,73H
		AND	BYTE PTR ES:[0F6H],0FEH
		JMP	L_S30
L_S33:
		CMP	AL,'K'                  ;<安装KZZF>
		JNZ	L_S34
		OR	BYTE PTR ES:[0F4H],5
		JMP	L_S30
L_S34:
		CMP	AL,'L'                  ;<安装KZZF,显示用BIOS>
		JNZ	L_S35
		OR	BYTE PTR ES:[0F4H],1
		JMP	L_S30
L_S35:
		CMP	AL,'N'                  ;<驻留基本内存>
		JNZ	L_S36
		MOV	D_RAM,AL
		JMP	L_S30
L_S36:
		CMP	AL,'P'                  ;<显示中断调BIOS>
		JNZ	L_S37
		MOV	BYTE PTR DS:K_10ZJXP,72H
		OR	BYTE PTR ES:[0F5H],4
		JMP	L_S30
L_S37:
		CMP	AL,'X'                  ;<不显示版本信息>
		JNZ	L_S38
		OR	BYTE PTR ES:[0F4H],8
		JMP	L_S30
L_S38:
		CMP	AL,'Z'                  ;<禁止直接写屏>
		JNZ	L_S50
		MOV	BYTE PTR K_VJXP,0	;禁止直接写屏
		MOV	BYTE PTR K_VJXP1,0
		AND	BYTE PTR ES:[0F5H],0FEH
L_S50:
		JMP	L_S30
L_S60:
		MOV	BP,OFFSET D_KZZFQ
		TEST	BYTE PTR DS:[0F4H],1   ;安装KZZF
		JZ	L_S61
		MOV	DX,OFFSET D_KZZF	;'KZZF',0
		MOV	AX,3D00H		;打开文件
		INT	21H
		JB	L_S61
		MOV	BX,AX
		MOV	DX,BP
		MOV	CX,1000H
		MOV	AH,3FH			;读
		INT	21H
		MOV	AH,3EH			;关闭
		INT	21H
		ADD	BP,1000H
L_S61:
		MOV	D_LEN0,BP
		MOV	CL,4
		SHR	BP,CL
		INC	BP			;驻留长度(节)
		MOV	D_LEN,BP

		MOV	AH,-1			;取安装模块?
		INT	10H
		CMP	AX,45H			;判安装?
		JNZ	L_S70
		MOV	AX,0E07H
		INT	10H
		MOV	AX,4C01H
		INT	21H
L_S70:
		MOV	AX,CS
		CMP	AX,0A000H		;判LH?
		JA	L_S90
		CMP	D_RAM,'N'               ;驻留基本内存
		JZ	L_S90
		CALL	S_GETUMB		;分配UMB段
		JZ	L_S100
L_S90:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		CALL	S_SETINT
		JMP	L_S120
L_S100:
		MOV	AX,D_UMB
		OR	AX,AX
		JZ	L_S90
		DEC	AX
		MOV	ES,AX
		MOV	DI,8
		MOV	SI,OFFSET D_NAME
		MOVSW				;向UMB文件控制块写入本模块名
		MOVSW

		MOV	ES,D_UMB		;段
		XOR	SI,SI
		MOV	DI,SI
		MOV	CX,D_LEN0
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
L_S120:
		MOV	DX,D_LEN		;本模块长度(节)
		MOV	AX,3100H		;驻留
		INT	21H

D_XMS		DD	0			;XMS驱动地址
D_NCFP		DW	0			;原内存分配策略
D_UMB0		DW	0			;原UMB连接状态
D_UMB		DW	0			;分配UMB段
D_LEN		DW	0			;本模块长度(节)
D_LEN0		DW	0			;驻留模块长度
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

S_SETINT	PROC	NEAR
		MOV	DX,OFFSET INT_8
		MOV	AX,2508H		;建中断INT8		3.26
		INT	21H
		MOV	DX,OFFSET INT_10
		MOV	AX,2510H		;建中断INT10
		INT	21H
		MOV	DX,OFFSET INT_1D
		MOV	AX,251DH		;建中断INT1D
		INT	21H

		MOV	ES,D_INT16		;			2.24
		MOV	AX,3			;设置显示方式
		MOV	DL,1
		TEST	BYTE PTR DS:[0F5H],1	;=1:允许直接写屏?
		JNZ	L_SI1
		MOV	AL,9
		MOV	DL,0
L_SI1:
		INT	10H
		MOV	ES:[102H],DL

		TEST	BYTE PTR DS:[0F4H],8	;不显示版本信息?	10.22
		JNZ	L_SI5
		MOV	BL,70H
		MOV	AH,25H
		INT	16H
L_SI5:
		RET
S_SETINT	ENDP

D_NAME		DB	'HGA',0
MSG		DB	'HGA.COM HGA显示模块 1998.8.9',13,10
		DB	'命令行格式:VGA [/G][/H][/K][/L][/N][/P][/X][/Z]',13,10
		DB	'    其中:/G:固定光标2线',13,10
		DB	'         /H:显示方式>5即汉字',13,10
		DB	'         /K:调用扩展字符库',13,10
		DB	'         /L:安装KZZF,显示用BIOS',13,10
		DB	'         /N:驻留基本内存',13,10
		DB	'         /P:滚屏中断调BIOS',13,10
		DB	'         /X:不显示版本信息',13,10
		DB	'         /Z:不使用直接写屏',13,10,'$'

SEG_A		ENDS
		END	START

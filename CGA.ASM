;	CGA.ASM
;	1995.10.7, 12.21
;	1996.1.4, 2.10, 10.4
;	1997.2.20, 7.7

SEG_A		SEGMENT PARA PUBLIC
		ASSUME CS:SEG_A , DS:SEG_A

		ORG	100H
START:		JMP	BEGIN
IN_INT10	DB	0
	;[0F4H]TEST-1:安装KZZF,-2:保持提示行,-8:不显示提示信息
	;[0F5H]TEST-1:直接写屏,-2:图形方式打开B8,-4:显示中断调BIOS,-8:光标下移
	;[0F6H]TEST-1:原有方式,-2:固定光标,-4:初始化寄存器,-8:AH=0B调BIOS
	;[0F7H]='1'~'9':提示行光带色,其他:关闭屏幕分割
	;[100H] 中西文显示方式		=0西文,=1汉字
	;[101H] 光标开关		位0=0无,=1有光标
	;[102H] 当前光标状态		=0无光标,=0FFH有
D_INT10 	DD	0			;原INT10
D_INT16 	DW	0			;键盘模块段
		INCLUDE ZF80.INC
D_0050		DB	0			;前字节
D_0051		DB	0			;前字节属性
D_0052		DW	0			;前字节位置
D_0058		DB	0			;提示行列位置
D_0059		DB	0			;当前提示行号,无(=0)
D_005B		DB	16H			;提示行浮动行号
D_005E		DW	2			;光标起始/结束线
D_0060		DB	0			;=0属性高位高亮,非0异或
D_0062		DB	0			;提示行汉字前字节
D_0064		DB	6			;对外显示方式
D_0068		DW	0			;保存光标位置
D_0069		DB	1			;=0繁体,非0简体

D_AH		DW	OFFSET L_AH00		;AH=0
D_AH01		DW	OFFSET L_AH01		;AH=1
		DW	OFFSET L_AH02		;AH=2
		DW	OFFSET L_INT10		;AH=3
		DW	OFFSET L_INT10		;AH=4
		DW	OFFSET L_INT10		;AH=5
		DW	OFFSET L_AH06		;AH=6
		DW	OFFSET L_AH07		;AH=7
		DW	OFFSET L_AH08		;AH=8
		DW	OFFSET L_AH09		;AH=9
		DW	OFFSET L_AH09		;AH=0AH
		DW	OFFSET L_INT10		;AH=0BH
		DW	OFFSET L_AH0C		;AH=0CH
		DW	OFFSET L_AH0D		;AH=0DH
		DW	OFFSET L_AH0E		;AH=0EH
		DW	OFFSET L_INT10		;AH=0FH
D_AH10		DW	OFFSET L_INT10		;AH=10H
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
		MOV	AX,43H			;CGA:'C'
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

;AH=0 设置显示方式
L_AH00:
		MOV	BX,AX
		MOV	ES,CS:D_INT16		;键盘模块段

		AND	AL,7FH
		CMP	AL,6
D_6	EQU	$
		JZ	L_0010
		MOV	ES:[101H],AL		;实际显示方式
		MOV	CS:[100H],AH   ;西文方式
		MOV	AX,BX
		JMP	L_INT10
L_0010:
		MOV	AL,6
		MOV	ES:[101H],AL
		MOV	AX,BX
		PUSHF
		CALL	CS:D_INT10		;调原INT10
		MOV	AH,0BH
		MOV	BX,102H
		PUSHF
		CALL	CS:D_INT10

		PUSH	CS
		POP	ES			;CS→ES
		MOV	DI,OFFSET D_XPQ 	;虚屏区首址
		MOV	AX,720H
		MOV	CX,25*80
		REP	STOSW			;清虚屏区

		MOV	AL,CS:D_0064
		MOV	DS:[449H],AL
		MOV	CS:D_0059,0		;关提示行
		MOV	WORD PTR CS:[100H],101H ;打开光标
		MOV	BYTE PTR CS:[102H],0	;无光标(初始状态)
		MOV	WORD PTR DS:[460H],607H ;光标大小

		XOR	DX,DX
		MOV	CS:D_0068,DX
		CALL	S_XSGB			;显示光标
		JMP	L_RET

;AH=1 设置光标大小 CH=起始扫描线,CL=终止线
L_AH01:
		CLI
		OR	CX,CX
		JZ	L_0103
		CALL	S_QGB			;清光标
		PUSH	CX
		AND	CX,1F1FH
		CMP	CL,CH
		JNB	L_0101
		MOV	CH,CL
L_0101:
		SUB	CL,CH
		INC	CX
		CMP	CL,7
		JB	L_0102
		MOV	CL,7
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
		JMP	L_INT10

;AH=2 设置光标位置
L_AH02:
		CMP	CS:D_0059,0		;判有无提示行?
		JZ	L_0201
		CMP	DH,CS:D_0059		;定位行是否提示行?
		JNZ	L_0201
		MOV	AX,1404H		;关闭提示行
		INT	10H
L_0201:
		MOV	DS:[450H],DX
		CALL	S_GB
		MOV	AH,2
		JMP	L_INT10

;AH=6 上滚
L_AH06:
		CALL	S_QGB			 ;关光标
		CMP	CS:D_0059,0		;判有无提示行?
		JZ	L_0603
		PUSH	AX
		MOV	AX,1404H
		INT	10H			;关闭提示行
		POP	AX
L_0603:
		CALL	S_GDHS			;判滚动行数
		MOV	AX,CX			;左上角
		CALL	S_GDFW			;滚动范围,CS→DS
		ADD	SI,AX
		MOV	BP,80*2

		OR	BL,BL
		JNZ	L_0604
		MOV	BL,DH
		JMP	SHORT L_0606
L_0604:
		MOV	AH,DH
		SUB	AH,BL
L_0605:
		CALL	S_XPGD			;虚屏上滚一行
		ADD	SI,BP			;指向下一行
		ADD	DI,BP
		DEC	AH
		JNZ	L_0605
L_0606:
		MOV	AH,BH			;恢复空行填充属性
		OR	AH,AH
		JNZ	L_0607
		MOV	AH,7
L_0607:
		SHR	BH,1			;实际的空行填充属性
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
L_0608:
		CALL	S_KHTC			;空行填充
		ADD	DI,BP			;指向下一行
		DEC	BL
		JNZ	L_0608
		POP	AX			;恢复滚动参数
		POP	BX
		POP	CX
		POP	DX
		PUSH	DX
		PUSH	CX
		PUSH	BX
		PUSH	AX
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
		XOR	DI,DI
		MOV	DS,DI
		MOV	BYTE PTR DS:[449H],6
		PUSHF
		CALL	CS:D_INT10		;调原INT10上滚
		MOV	AL,CS:D_0064
		MOV	DS:[449H],AL
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
		ADD	DX,101H 		;窗口行

		PUSH	CS
		POP	DS			;CS→DS
		PUSH	CS
		POP	ES			;CS→ES

		MOV	CL,AL
		MOV	AL,80
		MUL	AH			;行号
		XOR	CH,CH
		ADD	AX,CX
		SHL	AX,1
		ADD	AX,OFFSET D_XPQ 	;虚屏区地址
		MOV	DI,AX
		MOV	SI,AX

		MOV	AL,80
		MUL	BL			;滚动行
		SHL	AX,1

		XOR	CH,CH
		RET
S_GDFW		ENDP

;子程序:虚屏滚动一行
S_XPGD		PROC	NEAR
		MOV	CL,DL
		PUSH	SI
		PUSH	DI
		REP	MOVSW
		POP	DI
		POP	SI
		RET
S_XPGD		ENDP

;子程序:空行填充
S_KHTC		PROC	NEAR
		MOV	AL,' '
		MOV	CL,DL
		PUSH	DI
		REP	STOSW
		POP	DI
		RET
S_KHTC		ENDP

;AH=7 下滚
L_AH07:
		CALL	S_QGB			;关光标
		CMP	CS:D_0059,0		;判有无提示行
		JZ	L_0703
		PUSH	AX
		MOV	AX,1404H
		INT	10H			;关闭提示行
		POP	AX
L_0703:
		STD
		CALL	S_GDHS			;判滚动行数
		MOV	AX,DX			;右下角
		CALL	S_GDFW			;滚动范围,CS→DS
		SUB	SI,AX
		MOV	BP,0A0H

		OR	BL,BL
		JNZ	L_0704
		MOV	BL,DH
		JMP	SHORT L_0706
L_0704:
		MOV	AH,DH
		SUB	AH,BL
L_0705:
		CALL	S_XPGD			;虚屏下滚一行
		SUB	SI,BP			;指向下一行
		SUB	DI,BP
		DEC	AH
		JNZ	L_0705
L_0706:
		MOV	AH,BH			;恢复空行填充属性
		OR	AH,AH
		JNZ	L_0707
		MOV	AH,7
L_0707:
		SHR	BH,1			;实际的空行填充属性
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
L_0708:
		CALL	S_KHTC			;空行填充
		SUB	DI,BP			;指向下一行
		DEC	BL
		JNZ	L_0708

		POP	AX			;恢复滚动参数
		POP	BX
		POP	CX
		POP	DX
		PUSH	DX
		PUSH	CX
		PUSH	BX
		PUSH	AX
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
		XOR	DI,DI
		MOV	DS,DI
		MOV	BYTE PTR DS:[449H],6
		PUSHF
		CALL	CS:D_INT10		;调原INT10下滚
		MOV	AL,CS:D_0064
		MOV	DS:[449H],AL
		CLD
		JMP	L_RET

;AH=8 读当前光标位置字符及属性
L_AH08: 	CALL	S_XPDZ			;计算当前光标在虚屏区地址→SI
		MOV	AX,CS:[SI]		;取出字符和属性
		POP	BX
		JMP	L_RET1

;子程序:计算当前光标在虚屏区地址→SI
S_XPDZ		PROC	NEAR
		PUSH	AX
		PUSH	BX
		MOV	AX,DS:[450H]		;取当前页光标位置
		MOV	DX,AX
		MOV	BL,AL			;存列
		MOV	AL,80			;每行字符数
		MUL	AH			;乘行数
		XOR	BH,BH
		ADD	AX,BX			;加列
		SHL	AX,1			;乘2
		ADD	AX,OFFSET D_XPQ
		MOV	SI,AX
		POP	BX
		POP	AX
		RET
S_XPDZ		ENDP

;AH=9,0AH 写当前光标位置字符及属性
L_AH09:
		OR	CX,CX			;字符个数=0?
		JZ	L_0908
		CALL	S_QGB			;关光标

		CALL	S_XPDZ			;计算当前光标在虚屏区地址→SI
		PUSH	CX
L_0904:
		MOV	CS:[SI],AL		;写入字符代码
		CMP	AH,0AH
		JZ	L_0905
		MOV	CS:[SI+1],BL
L_0905:
		ADD	SI,2
		LOOP	L_0904
		POP	CX

		CMP	AH,0AH
		JNZ	L_0906
		MOV	BL,CS:[SI-1]
L_0906:
		XOR	BP,BP
		CMP	CS:D_0060,1
		JNZ	L_0907
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
K_HZ		EQU	$-2
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
		JMP	SHORT L_XS0
L_XS1:
		OR	DL,DL
		JZ	L_XS0
		DEC	DX			;左边一位
		CMP	DX,CS:D_0052
		JNZ	L_XS2
		MOV	AH,CS:D_0050		;取前字节
		MOV	BH,CS:D_0051
	 ;子程序:显示汉字
S_XSHZ:
		PUSH	DX
		CALL	S_ZMZH
		POP	DX
		PUSH	CS
		POP	ES
		MOV	DI,80H
		MOV	CH,2			;两半区
L_HZ1:
		MOV	CL,8
L_HZ2:
		LODSW				;取一字
		OR	AL,AH			;迭加一字节
		STOSB				;写
		DEC	CL
		JNZ	L_HZ2
		DEC	CH
		JNZ	L_HZ1

		CALL	S_SPDZ			;计算光标DX在实屏区地址→DI
		MOV	SI,80H			;字模加工区首地址
		PUSH	BX
		MOV	BL,BH
		CALL	S_ZMXS			;字模送显示缓冲区
		ADD	DI,CS:D_K		;指向右半区
		POP	BX
		CALL	S_ZMXS			;字模送显示缓冲区
		MOV	CS:D_0050,0		;清前字节
		RET

	;子程序:显示字符AL DX=光标位置,CX=个数,BL=属性
S_XSZF:
		OR	CX,CX
		JZ	L_ZF5
L_XSZF:
		CALL	S_ZFZH
		CALL	S_SPDZ			;计算光标DX在实屏区地址→DI
L_ZF1:
		PUSH	SI
		PUSH	DX
		CALL	S_ZMXS			;显示字符
		POP	DX
		POP	SI
		INC	DL
		CMP	DL,80
		JB	L_ZF2
		XOR	DL,DL
		CMP	DH,18H
		JZ	L_ZF2
		INC	DH
L_ZF2:
		CALL	S_SPDZ
		LOOP	L_ZF1
L_ZF5:
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
		TEST	BL,70H			;反白?
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
		TEST	BL,70H			;反白?
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
		ADD	DI,80
		LOOP	L_ZM1
		POP	DX
		POP	CX
		POP	DI
		RET
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
		MOV	DX,80*4 		;每字符行占实屏区字节数
		MUL	DX			;行首地址
		XOR	BH,BH
		ADD	AX,BX
		MOV	DI,AX			;实屏区地址
		MOV	AX,0B800H
		MOV	ES,AX			;显示缓冲区段
		POP	BX
		POP	DX
		POP	AX
		RET
S_SPDZ		ENDP

	INCLUDE GB.INC

S_XSGB		PROC	NEAR
		NOT	BYTE PTR CS:[102H]	;状态反
S_XSGB0:
		MOV	CX,CS:D_005E		;光标大小
		OR	CX,CX
		JZ	L_GB5
S_XSGB1:
		CMP	DL,4FH
		JBE	L_GB3
		RET
L_GB3:
		PUSH	ES
		CALL	S_SPDZ

		ADD	DI,80*3
L_GB4:
		NOT	BYTE PTR ES:[DI+2000H]
		DEC	CX
		JZ	L_GB5
		NOT	BYTE PTR ES:[DI]
		SUB	DI,80
		DEC	CX
		JNZ	L_GB4
L_GB5:
		POP	ES
		RET
S_XSGB		ENDP

;AH=0CH 显示点
L_AH0C: 	MOV	BYTE PTR DS:[449H],6
		PUSHF
		CALL	CS:D_INT10
		MOV	AL,CS:D_0064
		MOV	DS:[449H],AL
		JMP	L_RET

;AH=0DH 读出点
L_AH0D: 	MOV	BYTE PTR DS:[449H],6
		PUSHF
		CALL	CS:D_INT10
		MOV	BH,CS:D_0064
		MOV	DS:[449H],BH
		POP	BP
		JMP	L_RET1

	INCLUDE AH0E.INC
	INCLUDE AH13.INC

;AH=14H 提示行管理
;	AL=0 清提示行
;	AL=1 显示字符DL CL=个数
;	AL=2 提示行光标定位DL
;	AL=3 显示字符DL并推进光标
;	AL=4 关闭提示行
;	AL=5 设置提示行浮动位置BH
;	AL=6 取显示参数 AL=显示方式 AH=最大色号
;			BL=提示行颜色 BH=浮动位置
;			CL=显示行数,CH=每行扫描线数
;			DL=提示行光标位置 DH=当前提示行位置
;			SI=横向点数 DI=纵向扫描线数
;	AL=7 设置对外显示方式BH
;	AL=8 位置DX处字符反相显示
;	AL=9 在指定位置DX显示字符BH
;	AL=10 在指定位置DL显示BL属性BP:SI处的点阵64字节
;	AL=12 取虚屏区地址 BX:AX
;	AL=15 在指定位置DX显示加宽字符串DS:SI(属性BL)
L_AH14:
		OR	AL,AL			;清提示行
		JNZ	L_1410
L_1400:
		MOV	CS:D_0058,AL		;提示行定位在左端
		MOV	CS:D_0062,AL
		CMP	CS:D_0059,AL		;提示行已打开?
		JNZ	L_1405
		MOV	DH,18H			;			10.4
		CMP	DH,DS:[451H]		;光标在第25行?
		JA	L_1401
		MOV	DH,CS:D_005B
L_1401:
		MOV	CS:D_0059,DH		;置提示行位置
		XOR	DL,DL
		CALL	S_SPDZ			;计算光标DX在实屏区地址→DI

		MOV	SI,DI
		MOV	DI,OFFSET D_TSBC	;提示行保存区
		MOV	CX,80*4
L_1404:
		MOV	AL,ES:[SI]		;保存被提示行复盖的内容
		MOV	AH,ES:[SI+2000H]
		MOV	CS:[DI],AX
		INC	SI
		ADD	DI,2
		LOOP	L_1404
L_1405:
		MOV	DL,' '
		MOV	CX,80			;清提示行
		MOV	BL,7
L_1407:
		CALL	S_TXZF
L_1408:
		JMP	L_RET
L_1410:
		CMP	AL,1			;写字符DL
		JNZ	L_1420
		OR	CX,CX
		JZ	L_1408
		CALL	S_DKTX
		JMP	SHORT L_1407
L_1420:
		CMP	AL,2			;光标定位
		JNZ	L_1430
		CALL	S_DKTX
		CALL	S_TXGB
		CMP	DL,79
		JA	L_1423
		MOV	CS:D_0058,DL
L_1422:
		CALL	S_TXGB
L_1423:
		JMP	L_RET
L_1430:
		CMP	AL,3			;TTY写字符
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
		MOV	CS:D_0058,AL		;存光标位置
L_1432:
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
		INC	AX
		MOV	CS:D_0058,AL		;存光标位置
		JMP	SHORT L_1422
L_1440:
		CMP	AL,4			;关闭提示行
		JNZ	L_1450
		MOV	DH,CS:D_0059		;提示行位置
		OR	DH,DH
		JZ	L_1442
		XOR	DL,DL
		MOV	CS:D_0059,DL		;清提示行
		CALL	S_SPDZ			;计算光标DX在实屏区地址→DI
		MOV	SI,OFFSET D_XPQ+25*80*2 ;提示行保存区
		MOV	CX,80*4
L_1441:
		MOV	AX,CS:[SI]		;恢复被提示行复盖的内容
		MOV	ES:[DI],AL
		MOV	ES:[DI+2000H],AH
		ADD	SI,2
		INC	DI
		LOOP	L_1441
L_1442:
		JMP	L_RET
L_1450:
		CMP	AL,5			;设置提示行浮动位置
		JNZ	L_1460
		MOV	CS:D_005B,BH
		JMP	L_RET
L_1460:
		CMP	AL,6			;取显示参数
		JNZ	L_1470
		MOV	AX,106H 		;取显示方式和最大色号
		MOV	BH,CS:D_005B   ;取提示行颜色和浮动位置
		XOR	BL,BL
		MOV	CX,819H 		;取每行扫描线数和显示行数
		MOV	DH,CS:D_0059
		MOV	DL,0
		MOV	SI,639			;横向点数
		MOV	DI,199			;纵向扫描线数
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
		CMP	AL,7			;设置对外显示方式
		JNZ	L_1480
		MOV	CS:D_0064,BH
		MOV	DS:[449H],BH
		JMP	L_RET
L_1480:
		CMP	AL,8			;<位置DX处字符反相>
		JNZ	L_1490
		MOV	CX,8
		CALL	S_XSGB1
		JMP	L_RET
L_1490:
		CMP	AL,9			;<在指定位置DX显示字符BH>
K_1490	EQU	$
		JNZ	L_14A0
		MOV	AL,BH
		XOR	BP,BP
		OR	CX,CX			; *5.21*
		JZ	L_1491
		MOV	CX,1
		CALL	S_XS
		JMP	L_RET
L_1491:
		INC	CX			; *5.21*
		CALL	S_XSZF
		JMP	L_RET
L_14A0:
		CMP	AL,10			;显示2.13标志
		JNZ	L_14C0
		MOV	BX,4E4EH
		MOV	DL,4BH
		MOV	DH,CS:D_0059		;			10.4
		MOV	AX,0AFA1H
		CALL	S_XSHZ
		MOV	DL,4DH
		MOV	AX,0AFA2H
		CALL	S_XSHZ
L_14A9:
		JMP	L_RET
L_14C0:
		CMP	AL,12			;<取虚屏区地址BX:AX>
		JNZ	L_14F0
		MOV	AX,OFFSET D_XPQ
		PUSH	CS
		POP	BX
		POP	CX
		POP	CX
		JMP	L_RET3
L_14F0:
		CMP	AL,15			;<在指定位置DX显示加宽字符串ES:SI,以0结尾>
		JNZ	L_14A9
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
		CALL	S_XSGB
		POP	DX
		POP	BX
		RET
S_TXGB		ENDP

;子程序:在提示行写字符
S_TXZF		PROC	NEAR
		XOR	BP,BP
		MOV	AL,DL			;字符
		MOV	DX,WORD PTR CS:D_0058	;位置
		CMP	BL,10H
		JB	L_TX0
		CMP	BL,20H
		JNB	L_TX1A
		AND	BL,0FH
		JMP	SHORT L_TX0
L_TX1A:
		MOV	BL,70H
L_TX0:
		CMP	CS:D_0062,0		;判汉字前字节?
		JNZ	L_TX2
		CMP	AL,0A0H 		;判汉字?
		JBE	L_TX1
		MOV	CS:D_0062,AL		;存汉字前字节
		MOV	CS:D_0051,BL		;存前字节属性
L_TX1:
		JMP	S_XSZF			;显示字符
L_TX2:
		CMP	AL,0A0H
		JBE	L_TX3
		MOV	AH,CS:D_0062		;取前字节
		MOV	BH,CS:D_0051
		DEC	DX
		MOV	CS:D_0062,0		;清前字节
		JMP	S_XSHZ			;显示汉字
L_TX3:
		MOV	CS:D_0062,0		;清前字节
		JMP	SHORT L_TX1
S_TXZF		ENDP

;子程序:读字库并转换 AX=汉字内码 →DS:60H
S_ZMZH		PROC	NEAR
		MOV	DX,AX
S_ZMZH1:
		MOV	AH,CS:D_0069
		INT	7FH			;读字库并转换
		MOV	DS,DX			;字模段
		XOR	SI,SI			;    偏移
		MOV	DI,60H			;转换地址
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

;子程序:读字符库 AL=ASC码 →DS:SI		;1.14
S_ZFZH		PROC	NEAR
		CMP	AL,80H
		JB	L_ZFZH1
		SUB	AL,80H			;变为0~7FH
		MOV	SI,OFFSET D_ZF80	;加扩展ASCII字符库首
		PUSH	CS
		POP	DS
		JMP	SHORT L_ZFZH2
L_ZFZH1:
		MOV	SI,0F000H
		MOV	DS,SI			;ROM-BIOS段
		MOV	SI,0FA6EH		;ROM-BIOS字符库首址
L_ZFZH2:
		MOV	AH,8			;每字符8字节
		MUL	AH
		ADD	SI,AX
		RET
S_ZFZH		ENDP

;AH=16H 取汉字或字符字模
L_AH16: 	OR	DH,DH			;判汉字?
		JZ	L_1601
		CALL	S_ZMZH1 		;读字库并转换
		MOV	ES,BP			;目标段
		MOV	DI,BX			;    偏移
		MOV	CX,16			;传送10H个字
		REP	MOVSW
		JMP	L_RET
L_1601:
		MOV	DL,AL
		CALL	S_ZFZH
		MOV	DI,BX			;目标偏移
		MOV	ES,BP			;    段
		MOV	CX,8
L_1602: 	LODSB
		STOSB
		STOSB
		LOOP	L_1602
		JMP	L_RET

;AH=17H 光标控制
L_AH17:
		OR	AL,AL
		JZ	L_1701
		MOV	BYTE PTR CS:[101H],1	;开光标
L_AH15:
		CALL	S_GB
		JMP	L_RET
L_1701:
		CALL	S_QGB
		MOV	CS:[101H],AL		;存光标开关
		JMP	L_RET

;AH=18H AL=0不识汉字		AL=1识别汉字
;	AL=2属性高位高亮	AL=3异或
;	AL=4不允许设置显示方式	AL=5允许
;	AL=8不允许设置调色板	AL=9允许设置调色板
;	AL=13光标大小控制 BH=1由AH=1控制*;BH=0,BL=光标大小
;	AL=14显示方式>=6为汉字	AL=15恢复原方式*
;	AL=17繁体		AL=18简体*
;	AL=19重显屏幕
;	AL=20关闭时钟显示*	AL=21恢复时钟显示
;	AL=23清虚屏区
L_AH18:
		OR	AL,AL			;<不识汉字>
		JNZ	L_1801
		MOV	AL,74H			;JZ
L_1800A:
		MOV	BYTE PTR CS:K_HZ,AL
		JMP	L_RET
L_1801:
		CMP	AL,1			;<识别汉字>
		JNZ	L_1802
		MOV	AL,0EBH 		;JMP SHORT
		JMP	SHORT L_1800A
L_1802:
		CMP	AL,2			;<属性高位高亮>
		JNZ	L_1803
L_1802A:
		SUB	AL,2
		MOV	CS:D_0060,AL
		JMP	L_RET
L_1803:
		CMP	AL,3			;<高位异或>
		JZ	L_1802A

		CMP	AL,4			;<不允许设置显示方式>
		JNZ	L_1805
		MOV	CS:D_AH,OFFSET L_RET
		JMP	L_RET
L_1805:
		CMP	AL,5			;<允许设置显示方式>
		JNZ	L_1808
		MOV	CS:D_AH,OFFSET L_AH00
		JMP	L_RET
L_1808:
		CMP	AL,8			;<不允许设置调色板>
		JNZ	L_1809
		MOV	AX,OFFSET L_RET
L_1808A:	MOV	CS:D_AH10,AX
		JMP	L_RET
L_1809:
		CMP	AL,9			;<允许设置调色板>
		JNZ	L_1813
		MOV	AX,OFFSET L_INT10
		JMP	SHORT L_1808A
L_1813:
		CMP	AL,13			;<光标大小控制>
		JNZ	L_1814
		OR	BH,BH
		JZ	L_1813A
		MOV	CS:D_AH01,OFFSET L_AH01
		JMP	L_RET
L_1813A:
		MOV	CS:D_AH01,OFFSET L_RET
		MOV	CS:D_005E,BX
		JMP	L_RET
L_1814:
		CMP	AL,14			;<显示方式>=6为汉字>
		JNZ	L_1815
		MOV	AX,673H 		;JAE
L_1814A:
		MOV	BYTE PTR CS:D_6,AH
		MOV	BYTE PTR CS:D_6+1,AL
		JMP	L_RET
L_1815:
		CMP	AL,15			;<恢复原方式>
		JNZ	L_1817
		MOV	AX,1274H		;JZ
		JMP	SHORT L_1814A
L_1817:
		CMP	AL,17			;<繁体>
		JNZ	L_1818
L_1817A:
		SUB	AL,17
		MOV	CS:D_0069,AL
		JMP	L_RET
L_1818:
		CMP	AL,18			;<简体>
		JZ	L_1817A

		CMP	AL,19			;<重显屏幕>
		JNZ	L_1820
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
		JMP	L_RET
L_1820:
		CMP	AL,20			;<关闭时钟显示>
		JNZ	L_1821
		MOV	AL,0EBH 		;JMP
L_1820A:
		MOV	BYTE PTR CS:K_1490,AL
		JMP	L_RET
L_1821:
		CMP	AL,21			;<恢复时钟显示>
		JNZ	L_1823
		MOV	AL,75H			;JNZ
		JMP	SHORT L_1820A
L_1823:
		CMP	AL,23			;<清虚屏区>
		JNZ	L_1823A
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_XPQ
		MOV	CX,25*80
		XOR	AX,AX
		REP	STOSW
L_1823A:
		JMP	L_RET

D_XPQ		DB	25*80*2 DUP(0)		;虚屏区
D_TSBC		DB	80*8 DUP(0)
;****************************************************************************
;程序执行开始
BEGIN:
		MOV	AX,3510H
		INT	21H			;取原INT10地址
		MOV	WORD PTR D_INT10,BX	;保存
		MOV	WORD PTR D_INT10+2,ES

		XOR	BP,BP
		MOV	AH,2FH			;取键盘中断
		INT	16H
		OR	BP,BP			;判有键盘模块?
		JNZ	L_S10
		MOV	BP,CS
L_S10:
		MOV	D_INT16,BP		;保存
		MOV	ES,BP
		MOV	BYTE PTR ES:[100H],6

		MOV	AX,CS			;10.22
		CMP	AX,BP
		JB	L_S21
		MOV	AX,ES:[0F4H]		;显示参数
		MOV	DS:[0F4H],AX		;存
		MOV	AX,ES:[0F6H]
		MOV	DS:[0F6H],AX
		PUSH	CS
		POP	ES
		JMP	SHORT L_S22
L_S21:
		MOV	BYTE PTR DS:[0F4H],8	;不显示版本信息
		MOV	BYTE PTR DS:[0F5H],0	;不设置直接写屏
		MOV	BYTE PTR DS:[0F6H],1	;原有方式
		MOV	BYTE PTR DS:[0F7H],'9'  ;提示行光带色
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
		CMP	AL,'X'                  ;<不显示版本信息>
		JNZ	L_S34
		OR	BYTE PTR ES:[0F4H],8
		JMP	L_S30
L_S34:
		CMP	AL,'H'                  ;<显示方式>5即为汉字>
		JNZ	L_S39
		MOV	BYTE PTR DS:D_6,6
		MOV	BYTE PTR DS:D_6+1,73H
		AND	BYTE PTR ES:[0F6H],0FEH
		JMP	L_S30
L_S39:
		CMP	AL,'G'                  ;<固定光标>
		JNZ	L_S40
		MOV	D_AH01,OFFSET L_RET
		OR	BYTE PTR ES:[0F6H],2
		JMP	L_S30
L_S40:
		CMP	AL,'N'                  ;<驻留基本内存>
		JNZ	L_S50
		MOV	D_RAM,AL
L_S50:
		JMP	L_S30
L_S60:
		MOV	AX,OFFSET BEGIN
		MOV	CL,4
		SHR	AX,CL
		INC	AX			;驻留长度(节)
		MOV	D_LEN,AX

		MOV	AH,-1			;取安装模块?
		INT	10H
		CMP	AX,43H			;CGA
		JNZ	L_S8
		MOV	AX,0E07H
		INT	10H
		INT	20H
L_S8:
		MOV	AX,CS
		CMP	AX,0A000H		;判LH?
		JA	L_S90
		CMP	D_RAM,'N'                  ;/N:驻留基本内存
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
L_S120:
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

S_SETINT	PROC	NEAR
		MOV	DX,OFFSET INT_10
		MOV	AX,2510H
		INT	21H			;建中断INT10
		MOV	AX,6
		INT	10H			;设置显示方式

		TEST	BYTE PTR DS:[0F4H],8	;不显示版本信息?
		JNZ	L_SI2
		MOV	BL,7
		MOV	AH,25H			;显示版本信息
		INT	16H
L_SI2:
		RET
S_SETINT	ENDP

D_NAME		DB	'CGA',0
MSG		DB	'CGA.COM CGA显示模块 1997.7.7',13,10
		DB	'命令行格式:VGA [/X][/H][/G][/N]',13,10
		DB	'    其中:/X:不显示版本信息,/H:显示方式>5即汉字',13,10
		DB	'         /G:固定光标,      /N:驻留基本内存',13,10,'$'

SEG_A		ENDS
		END	START

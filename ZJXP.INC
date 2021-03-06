;	ZJXP.INC 处理直接写屏模块
;	1995.1.12, 1.18, 2.16
;	1996.1.19

D_ZBFS		DB	3		;=0纯西文方式,=1不处理制表符
					;=2处理部分制表符,=3处理全部制表符
D_NUM		DB	0		;字符闪烁计数

;子程序:处理直接写屏
S_XR		PROC	NEAR
		CMP	CS:D_ZBFS,1		;=1不处理制表符
		JZ	L_XR10

		CMP	CS:D_ZBFS,2		;=2处理部分制表符
		JZ	L_XR1
		CALL	S_SXSM			;竖向扫描
L_XR1:
		MOV	CX,25*80		;虚屏区长度
		XOR	SI,SI
L_XR2:
		LODSW				;取字符
		CMP	AL,0B0H 		;判西文制表符
		JB	L_XR9
		CMP	AL,0E0H
		JAE	L_XR9

		PUSH	SI			;西文制表符处理
		PUSH	CX
		XOR	CX,CX			;			1.19
		MOV	DI,SI
L_XR3:
		INC	CX
		CMP	AL,[DI] 		;字符相同?
		JNZ	L_XR3A
		ADD	DI,2
		JMP	SHORT L_XR3
L_XR3A:
		CMP	CX,4			;4个以上是西文制表符
		JAE	L_XR4
		CMP	CX,1			;1个
		JZ	L_XR5
		CMP	AL,0DFH 		;专为FOXPRO设 2-3个�
		JZ	L_XR4
		CMP	CX,2			;2个
		JZ	L_XR5
		CMP	AL,0C4H 		;� ;三个一样
		JZ	L_XR4
		CMP	AL,0CDH 		;�
		JNZ	L_XR5			;			1.18
L_XR4:
		CALL	S_LXZF			;转换码写入B800
		JMP	SHORT L_XR8
L_XR5:
		CALL	S_QTZF			;处理制表符
L_XR8:
		POP	CX
		POP	SI
L_XR9:
		LOOP	L_XR2			;处理下一个字符
L_XR10:
		MOV	CX,25*80		;虚屏区长度
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_XPQ
		XOR	SI,SI
L_XR11:
		REPE	CMPSW			;比较两个区
		JZ	L_XR12
		PUSH	DS
		PUSH	ES
		PUSH	CX
		PUSH	SI
		PUSH	DI
		SUB	SI,2
		MOV	AX,SI			;指向不同的第一个字符
		SHR	AX,1
		MOV	DL,80
		DIV	DL			;每行字符数
		XCHG	AH,AL
		MOV	DX,AX			;当前字符位置
		LODSW				;取字符
		MOV	WORD PTR CS:D_XPQ[SI-2],AX
		MOV	CX,AX
		CALL	S_XRXS			;显示
		POP	DI
		POP	SI
		POP	CX
		POP	ES
		POP	DS
		OR	CX,CX
		JNZ	L_XR11			;没完,继续
L_XR12:
		RET
S_XR		ENDP

D_ZBFB		DB	80H, 81H, 82H, 14H, 83H, 84H, 85H,0B7H
	;0B0H		�    �	  �    �    �	 �    �    �
		DB     0B8H, 86H, 15H, 87H, 88H,0BDH,0BEH, 89H
	;0B8H		�    �	  �    �    �	 �    �    �
		DB	8AH, 8BH, 8CH, 8DH, 12H, 8EH, 8FH, 90H
	;0C0H		�    �	  �    �    �	 �    �    �
		DB	91H, 92H, 93H, 94H, 95H, 13H, 96H, 97H
	;0C8H		�    �	  �    �    �	 �    �    �
		DB	98H, 99H, 9AH,0D3H,0D4H,0D5H,0D6H, 9BH
	;0D0H		�    �	  �    �    �	 �    �    �
		DB	9CH, 9DH, 9EH, 82H, 9FH, 82H, 82H,0A0H
	;0D8H		�    �	  �    �    �	 �    �    �

S_ZBF		PROC	NEAR
		MOV	BL,AL
		XOR	BH,BH
		MOV	BL,CS:D_ZBFB[BX-0B0H]
		RET
S_ZBF		ENDP

;子程序:处理制表符
S_QTZF		PROC	NEAR
		CMP	CS:D_ZBFS,2		;处理部分制表符
		JNZ	L_QT1
		RET
L_QT1:
		CMP	AL,0B2H 		;� � �			1.16
		JBE	L_QT11
		CMP	AL,0DBH 		;� � �
		JB	L_QT3
L_QT11:
		CALL	S_ZBF			;取转换码
		MOV	DL,[SI] 		;右边字符		1.16
		CMP	AL,DL
		JZ	L_QT12
		CMP	DL,BL			;判已是制表符?
		JNZ	L_QT13
L_QT12:
		MOV	DL,[SI-4]		;左边字符		1.16
		CMP	DL,BL			;判已是制表符?
		JZ	L_QT14
		CMP	AL,DL
		JNZ	L_QT13
		CMP	BYTE PTR [SI+2],0A0H	;右边第二字符为汉字?	1.19
		JBE	L_QT14
L_QT13:
		RET
L_QT14:
		JMP	L_QT9
L_QT3:
		MOV	BL,AL
		XOR	BH,BH
		MOV	DL,CS:D_ZBF[BX-0B3H]	;取属性
		XOR	BP,BP
		TEST	DL,30H			;判左边?
		JZ	L_QT4
		MOV	CH,DL
		AND	CH,30H			;左边
		MOV	CL,4
		SHR	CH,CL
		MOV	BL,[SI-4]		;左边字符
	;	CMP	BL,11H			;
	;	JZ	L_QT3A
		CALL	S_QSX			;取属性
		JC	L_QT4
		AND	DH,3			;右边
		CMP	CH,DH			;判?
		JNZ	L_QT4
		CMP	BL,0A0H 		;判制表符?
		JA	L_QT4
L_QT3A: 	CALL	L_QT9			;写入
		INC	BP
L_QT4:
		TEST	DL,0CH			;判上边?
		JZ	L_QT5
		MOV	CH,DL
		AND	CH,0CH
		MOV	CL,4
		SHL	CH,CL
		MOV	BL,[SI-80*2-2]		;上边字符
	;	CMP	BL,1EH			;
	;	JZ	L_QT4A
		CALL	S_QSX			;取属性
		JC	L_QT5
		AND	DH,0C0H 		;下边
		CMP	CH,DH			;判?
		JNZ	L_QT5
		CMP	BL,0A0H 		;判制表符?
		JBE	L_QT44
		OR	BP,BP			;判已写入制表符?
		JZ	L_QT5
		PUSH	SI
		PUSH	AX
		SUB	SI,80*2
		MOV	AL,BL
		CALL	L_QT9			;上边写入
		POP	AX
		POP	SI
		JMP	SHORT L_QT5
L_QT44:
		OR	BP,BP
		JNZ	L_QT5
L_QT4A:
		CALL	L_QT9			;写入
		INC	BP
L_QT5:
		TEST	DL,3			;判右边?
		JZ	L_QT6
		MOV	CH,DL
		AND	CH,3
		MOV	CL,4
		SHL	CH,CL
		MOV	BL,[SI] 		;右边字符
	;	CMP	BL,10H			;
	;	JZ	L_QT5A
		CALL	S_QSX			;取属性
		JC	L_QT6
		AND	DH,30H			;左边
		CMP	CH,DH			;判?
		JNZ	L_QT6
		CMP	BL,0A0H 		;判制表符?
		JA	L_QT6
		OR	BP,BP
		JNZ	L_QT6
L_QT5A:
		CALL	L_QT9			;写入
		INC	BP
L_QT6:
		TEST	DL,0C0H 		;判下边?
		JZ	L_QT7
		MOV	CH,DL
		AND	CH,0C0H
		MOV	CL,4
		SHR	CH,CL
		MOV	BL,[SI+80*2-2]		;下边字符
	;	CMP	BL,1FH			;
	;	JZ	L_QT9
		CMP	BL,0A0H
		JA	L_QT7
		CALL	S_QSX			;取属性
		JC	L_QT7
		AND	DH,0CH			;上边
		CMP	CH,DH			;判?
		JZ	L_QT8
L_QT7:
		RET
L_QT8:
		OR	BP,BP
		JNZ	L_QT7
L_QT9:
		MOV	CX,1
;子程序:制表符转换码写入B800
S_ZJZF:
		CMP	CX,4
		JB	L_ZJ0
		MOV	BL,AL			;四个以上相同
		CALL	S_QSX			;取属性
		JB	L_ZJ0
		AND	DH,33H			;取左右位
		CMP	DH,11H			;左右细线?
		JZ	L_ZJ0
		CMP	DH,22H			;左右粗线?
		JZ	L_ZJ0
		RET
L_ZJ0:
		CALL	S_ZBF			;取转换码
		MOV	AL,BL
		MOV	ES,CS:D_B800		;B800区段
		MOV	DI,SI
		SUB	DI,2
L_ZJ7:
		STOSB				;写入字符
		INC	DI
		LOOP	L_ZJ7
L_ZJ8:
		RET
S_QTZF		ENDP

;子程序:三个以上制表符向左查询
S_LXZF		PROC	NEAR
		PUSH	CX
		MOV	BL,[SI-4]		;左边字符
		CMP	BL,0A0H 		;判汉字?
		JBE	L_LX1
		CALL	S_QSX			;取属性
		JB	L_LX1
		AND	DH,3

		MOV	BL,AL
		XOR	BH,BH
		MOV	DL,CS:D_ZBF[BX-0B3H]	;取属性
		AND	DL,30H
		MOV	CL,4
		SHR	DL,CL

		CMP	DL,DH			;判?
		JNZ	L_LX1
		PUSH	AX
		PUSH	SI
		SUB	SI,2
		MOV	AL,[SI-2]		;左边字符
		CALL	L_QT9			;写入
		POP	SI
		POP	AX
L_LX1:
		POP	CX
		JMP	S_ZJZF
S_LXZF		ENDP

;子程序:取制表符BL属性->DH
S_QSX		PROC	NEAR
		PUSH	BX
		XOR	BH,BH
		CMP	BL,20H
		JB	L_QSX1
		CMP	BL,7FH
		JB	L_QSX0			;ASCII字符
		CMP	BL,0A0H
		JBE	L_QSX1			;汉字内码
L_QSX00:
		CMP	BL,0B3H 		;判制表符?
		JB	L_QSX0
		CMP	BL,0DAH
		JBE	L_QSX3
L_QSX0:
		STC
		POP	BX
		RET
L_QSX1:
		MOV	DH,BL
		MOV	BX,0
L_QSX2:
		CMP	DH,CS:D_ZBFB[BX]
		JZ	L_QSX4
		INC	BX
		CMP	BL,48
		JB	L_QSX2
		JMP	SHORT L_QSX0
L_QSX4:
		ADD	BL,0B0H
		JMP	SHORT L_QSX00
L_QSX3:
		MOV	DH,CS:D_ZBF[BX-0B3H]
		CLC
		POP	BX
		RET
S_QSX		ENDP

;西文制表符属性字节
;	位67-下, 45-左, 23-上, 01-右
;	两位=01单线, =10双线
D_ZBF		DB	01000100B,01010100B,01100100B,10011000B
	;		� 0B3H	  � 0B4H    � 0B5H    � 0B6H
		DB	10010000B,01100000B,10101000B,10001000B
	;		� 0B7H	  � 0B8H    � 0B9H    � 0BAH
		DB	10100000B,00101000B,00011000B,00100100B
	;		� 0BBH	  � 0BCH    � 0BDH    � 0BEH
		DB	01010000B,00000101B,00010101B,01010001B
	;		� 0BFH	  � 0C0H    � 0C1H    � 0C2H
		DB	01000101B,00010001B,01010101B,01000110B
	;		� 0C3H	  � 0C4H    � 0C5H    � 0C6H
		DB	10001001B,00001010B,10000010B,00101010B
	;		� 0C7H	  � 0C8H    � 0C9H    � 0CAH
		DB	10100010B,10001010B,00100010B,10101010B
	;		� 0CBH	  � 0CCH    � 0CDH    � 0CEH
		DB	00100110B,00011001B,01100010B,10010001B
	;		� 0CFH	  � 0D0H    � 0D1H    � 0D2H
		DB	00001001B,00000110B,01000010B,10000001B
	;		� 0D3H	  � 0D4H    � 0D5H    � 0D6H
		DB	10011001B,01100110B,00010100B,01000001B
	;		� 0D7H	  � 0D8H    � 0D9H    � 0DAH

;子程序:竖向扫描
S_SXSM		PROC	NEAR
		XOR	SI,SI
		MOV	CX,80			;每行字符数
L_SX1:
		PUSH	SI
		PUSH	CX
		MOV	CX,25			;最大行号
L_SX2:
		MOV	AL,[SI]
		CMP	AL,0B3H 		;�
		JZ	L_SX3
		CMP	AL,0BAH 		;�
		JNZ	L_SX4
L_SX3:
		CALL	S_ZBF			;取转换码BL		1.18
		CALL	S_ZXSM
		OR	CX,CX
		JZ	L_SX5
L_SX4:
		ADD	SI,80*2
		LOOP	L_SX2
L_SX5:
		POP	CX
		POP	SI
		ADD	SI,2
		LOOP	L_SX1
		RET
S_SXSM		ENDP

;子程序:纵向扫描处理
S_ZXSM		PROC	NEAR
		XOR	DX,DX
		MOV	DI,SI
L_ZX1:
		INC	DX
		ADD	SI,80*2 		;下一行
		DEC	CX
		CMP	BL,DS:[SI]		;判转换码?
		JZ	L_ZX2
		CMP	AL,DS:[SI]		;判字符?
		JNZ	L_ZX3
L_ZX2:
		OR	CX,CX
		JNZ	L_ZX1
L_ZX3:
		MOV	AL,BL

		PUSH	CX
		CMP	DL,3			;三行?
		JB	L_ZX5
	;	MOV	BL,AL
		CALL	S_QSX			;取竖线属性
		AND	DH,0FH
		MOV	CH,DH			;保留低4位
		MOV	BL,[DI-80*2]		;上一行字符
		CMP	BL,0A0H 		;判制表符?
		JA	L_ZX5
		CALL	S_QSX			;取属性
		MOV	CL,4
		SHR	DH,CL			;移低4位
		CMP	CH,DH			;判?
		JZ	L_ZX7
L_ZX5:
		CMP	BYTE PTR [DI-2],0A0H	;左右为字符?
		JA	L_ZX8
		CMP	BYTE PTR [DI+2],0A0H
		JA	L_ZX8
L_ZX7:
		MOV	[DI],AL 		;转换码写入
		ADD	DI,80*2
		DEC	DL
		JNZ	L_ZX7

		POP	CX
		OR	CX,CX
		JZ	L_ZX9
		PUSH	CX

		MOV	BL,AL
		CALL	S_QSX			;取竖线属性
		AND	DH,0F0H
		MOV	CH,DH
		MOV	BL,[DI] 		;下一行字符
		CMP	BL,0A0H
		JBE	L_ZX8
		CALL	S_QSX			;取属性
		MOV	CL,4
		SHL	DH,CL
		CMP	CH,DH			;判?
		JNZ	L_ZX8
		PUSH	SI
		MOV	SI,DI
		ADD	SI,2
		MOV	AL,BL
		CALL	L_QT9			;写入
		POP	SI
L_ZX8:
		POP	CX
L_ZX9:
		RET
S_ZXSM		ENDP

;子程序:AL制表符转成西文制表符
S_ALVB		PROC	NEAR
		CMP	AL,20H
		JB	L_AV0
		CMP	AL,7FH
		JB	L_AV3			;ASCII字符
		CMP	AL,0A0H
		JA	L_AV3			;汉字内码
L_AV0:
		XOR	BX,BX
L_AV1:
		CMP	AL,CS:D_ZBFB[BX]
		JZ	L_AV2
		INC	BX
		CMP	BL,48
		JB	L_AV1
		RET
L_AV2:
		MOV	AL,BL
		ADD	AL,0B0H
L_AV3:
		RET
S_ALVB		ENDP

;子程序:显示
S_XRXS		PROC	NEAR
		CMP	CS:D_ZBFS,0		;=0纯西文方式
		JZ	L_XX1
		CMP	AL,0A0H 		;判汉字?
		JA	L_XX2
L_XX1:
		CMP	CS:D_ZBFS,1		;=0纯西文方式 或1不处理制表符
		JBE	L_XX1A
		CALL	S_ALVB			;AL制表符转成ASCII制表符
L_XX1A:
		MOV	BL,CH			;当前字符属性(字符AL)
   ;子程序:显示字符AL,属性BL,位置SI
S_XRZF:
		MOV	CX,1
		XOR	BP,BP
		MOV	DS,BP
		JMP	S_XSZF
L_XX2:
		CALL	S_PVHZ			;判整汉字?
		JZ	L_XX3
		CMP	DL,1			;当前字符列位置
		JB	L_XX1
		MOV	BX,DS:[SI-4]		;左边字符
		CMP	BL,0A0H
		JBE	L_XX1
		MOV	AH,BL			;左边字符(属性BH)
		MOV	BL,CH			;当前字符属性(字符AL)
		DEC	DX
		JMP	SHORT S_XRHZ
L_XX3:
		CMP	DL,79			;当前字符在行尾
		JAE	L_XX1
		MOV	BX,DS:[SI]		;右边字符
		CMP	BL,0A0H
		JBE	L_XX1
		MOV	AL,BL			;右边字符
		MOV	BL,BH			;	 属性
		MOV	AH,CL			;当前字符
		MOV	BH,CH			;	 属性
   ;子程序:显示汉字 前字节AH,属性BH,位置SI;后字节AL,属性BL
S_XRHZ:
		CMP	DL,79			;在行尾?
K_HZ1	EQU	$
		JZ	L_XRHZ1

		XOR	BP,BP
		JMP	S_XSHZ
L_XRHZ1:
		PUSH	AX
		PUSH	BX
		MOV	AL,AH
		MOV	BL,BH
		CALL	S_XRZF
		POP	BX
		POP	AX
		INC	DX
		CMP	DL,80
		JNZ	L_XRHZ2
		XOR	DL,DL
		INC	DH
L_XRHZ2:
		JMP	S_XRZF
S_XRXS		ENDP

;子程序:判整汉字 返回ZF=0为前字节,=1为后字节
S_PVHZ		PROC	NEAR
		PUSH	SI
		XOR	BL,BL
		OR	DL,DL
		JZ	L_PV2
		MOV	BH,DL			;当前字符列位置
		SUB	SI,4
L_PV1:
		CMP	BYTE PTR [SI],0A0H
		JB	L_PV2
		SUB	SI,2
		NOT	BL
		DEC	BH
		JNZ	L_PV1
L_PV2:
		POP	SI
		OR	BL,BL
		RET
S_PVHZ		ENDP

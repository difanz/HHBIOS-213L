;	READ16.ASM (2.13L)
;	1994.5.3, 10.17, 12.17
;	1996.1.3
;	1997.6.29

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN
	;[100H] 字型
	;[101H] 属性
		DB	'READ16'

INT_7A		PROC	FAR
		STI
		CLD
		PUSH	BP
		PUSH	DI
		PUSH	BX
		PUSH	AX
		PUSH	ES
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	DS:[100H],AH		;字型
		MOV	DS:[101H],BL		;属性
		MOV	BP,DS
		MOV	BX,60H
		MOV	SI,BX
		MOV	AH,16H			;读显示字库
		INT	10H

		MOV	AX,8
		OR	DH,DH			;判汉字?
		JNZ	L_HZ
		MOV	DS:[102H],AX		;列数
		MOV	CX,AX
		PUSH	CX
		XOR	DI,DI
		CALL	S_CZDZ			;变垂直点阵
		POP	CX
		JMP	L_SB
L_HZ:
		MOV	AL,16			;汉字
		MOV	DS:[102H],AX		;列数
		MOV	CX,AX

		XOR	DI,DI
		TEST	BYTE PTR DS:[101H],8	;左旋?
		JZ	L_YX
		PUSH	CX
		MOV	SI,60H
L_ZX:
		XOR	AL,AL
		STOSB
		MOV	AL,[SI+16]
		CALL	S_FW			;AL反位
		STOSB
		LODSB
		CALL	S_FW			;AL反位
		STOSB
		LOOP	L_ZX
		POP	CX
		JMP	L_K24
L_YX:
		TEST	BYTE PTR CS:[101H],10H	;右旋?
		JZ	L_HZCZ
		PUSH	CX
		MOV	SI,6FH
L_YX1:
		XOR	AL,AL
		STOSB
		MOV	AL,[SI]
		STOSB
		MOV	AL,[SI+16]
		STOSB
		DEC	SI
		LOOP	L_YX1
		POP	CX
		JMP	SHORT L_K24
L_HZCZ:
		PUSH	CX
		MOV	SI,60H
		CALL	S_CZDZ			;左半变垂直点阵
		MOV	SI,70H
		CALL	S_CZDZ			;右半变垂直点阵
		POP	CX
L_SB:
		XOR	DI,DI
		TEST	BYTE PTR DS:[101H],20H	;上标?
		JZ	L_XB
		PUSH	CX
L_SB1:
		INC	DI
		MOV	AX,[DI]
		XCHG	AL,AH
		XOR	DX,DX
		MOV	BL,8
L_SB2:
		SHL	AX,1
		JNB	L_SB3
		PUSHF
		SHL	AX,1
		POPF
		JMP	SHORT L_SB4
L_SB3:
		SHL	AX,1
L_SB4:
		RCL	DL,1
		DEC	BL
		JNZ	L_SB2
		MOV	AX,DX
		STOSW
		LOOP	L_SB1
		POP	CX
		JMP	SHORT L_K24
L_XB:
		TEST	BYTE PTR DS:[101H],40H	;下标?
		JZ	L_K24
		PUSH	CX
L_XB1:
		INC	DI
		MOV	AX,[DI]
		XCHG	AL,AH
		XOR	DX,DX
		MOV	BL,8
L_XB2:
		SHR	AX,1
		JNB	L_XB3
		PUSHF
		SHR	AX,1
		POPF
		JMP	SHORT L_XB4
L_XB3:
		SHR	AX,1
L_XB4:
		RCR	DH,1
		DEC	BL
		JNZ	L_XB2
		MOV	AX,DX
		STOSW
		LOOP	L_XB1
		POP	CX
L_K24:
		XOR	SI,SI
		XOR	DI,DI
		TEST	BYTE PTR DS:[100H],10H	;扩24?
		JZ	L_EXIT
L_K241:
		PUSH	CX
		INC	SI
		MOV	CX,5
		MOV	BH,[SI]
		MOV	BL,[SI+1]
		CALL	S_K24
		PUSH	BX
		RCL	BX,1
		RCL	AX,1
		XCHG	AL,AH
		STOSW
		POP	BX
		XOR	AX,AX
		RCL	BX,1
		RCL	AL,1
		RCL	BX,1
		RCL	AL,1
		MOV	CX,2
		CALL	S_K24
		STOSB
		INC	SI
		INC	SI
		POP	CX
		LOOP	L_K241
L_EXIT:
		MOV	CX,DS:[102H]
		XOR	SI,SI
		POP	ES
		POP	AX
		POP	BX
		POP	DI
		POP	BP
		IRET
INT_7A		ENDP

;子程序:扩24
S_K24		PROC	NEAR
L_K24_1:
		RCL	BX,1
		PUSHF
		RCL	AX,1
		POPF
		RCL	AX,1
		RCL	BX,1
		RCL	AX,1
		LOOP	L_K24_1
		RET
S_K24		ENDP

;子程序:一水平点阵变垂直点阵
S_CZDZ		PROC	NEAR
		MOV	CL,8
L_CZ1:
		PUSH	SI
		XOR	AL,AL
		STOSB
		CALL	S_CL
		CALL	S_CL
		POP	SI
		LOOP	L_CZ1
		RET
S_CZDZ		ENDP

;子程序:处理一列
S_CL		PROC	NEAR
		MOV	DL,8
L_CL1:
		LODSB
		SHR	AL,CL
		RCL	BL,1
		DEC	DL
		JNZ	L_CL1
		MOV	AL,BL
		STOSB
		RET
S_CL		ENDP

;子程序:AL反位
S_FW		PROC	NEAR
		MOV	AH,AL
		MOV	DL,8
L_FW1:
		SHL	AH,1
		RCR	AL,1
		DEC	DL
		JNZ	L_FW1
		RET
S_FW		ENDP

;****************************************************************************
BEGIN:
		MOV	AX,357AH
		INT	21H
		CMP	WORD PTR ES:[BX-2],'61' ;判驻留?
		JNZ	L_S10
		MOV	DX,OFFSET ALREADY
		MOV	AH,9
		INT	21H
		MOV	AX,4C01H
		INT	21H
L_S10:
		MOV	AX,CS
		CMP	AX,0A000H		;判LH?
		JA	L_S20
		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_S15
L_S12:
		LODSB
		CMP	AL,0DH
		JZ	L_S15
		CMP	AL,'/'
		JNZ	L_S12
		LODSB
		AND	AL,5FH
		CMP	AL,'N'                  ;/N:驻留基本内存
		JNZ	L_S12
		JMP	SHORT L_S20
L_S15:
		CALL	S_GETUMB		;分配UMB段
		JZ	L_S30
L_S20:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		CALL	S_SETINT
		MOV	DX,OFFSET BEGIN 	;驻留
		INT	27H
L_S30:
		MOV	AX,D_UMB
		OR	AX,AX			;1.3
		JZ	L_S20
		DEC	AX
		MOV	ES,AX
		MOV	DI,8
		MOV	SI,OFFSET D_NAME
		MOV	CX,7
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

;子程序:取UMB段
S_GETUMB	PROC	NEAR
		CALL	S_GETXMS		;取XMS驱动地址
		JNZ	L_GU2
		MOV	DX,OFFSET BEGIN
		SHR	DX,1
		SHR	DX,1
		SHR	DX,1
		SHR	DX,1
		INC	DX
		MOV	D_LEN,DX		;本模块驻留长度(节)

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
		MOV	DX,OFFSET INT_7A
		MOV	AX,257AH		;建中断
		INT	21H
		RET
S_SETINT	ENDP

D_NAME		DB	'READ16',0
ALREADY 	DB	'READ16 IS ALREADY!', 13,10,'$'

SEG_A		ENDS
		END	START

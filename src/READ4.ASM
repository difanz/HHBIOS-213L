;	READ4.ASM (2.13L)
;	1995.1.24, 12.17
;	1999.11.2, 11.16

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

	INCLUDE EXIT.INC

S_EX		PROC	NEAR
		MOV	DX,CS:D_HJ
		MOV	AH,45H			;清EMS
		INT	67H
		MOV	DX,CS:D_HF
		MOV	AH,45H
		INT	67H
		RET
S_EX		ENDP

D_HJ		DW	0			;申请到的描述字
D_HF		DW	0			;
D_PMJ		DW	0			;字库最后页号
D_PMF		DW	0			;
D_SEG		DW	0			;物理窗口段

;INT 7FH入口:DX=汉字内码 出口:DX:0的32字节
INT_7F		PROC	FAR
		STI
		CLD
		PUSH	DS
		PUSH	ES
		PUSH	BP
		PUSH	SI
		PUSH	DI
		PUSH	CX
		PUSH	BX
		PUSH	AX
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES

		OR	AH,AH			;=0繁体,非0简体
		JZ	L_1
		MOV	DI,D_HJ
		MOV	BP,D_PMJ
		JMP	SHORT L_2
L_1:
		MOV	DI,D_HF
		MOV	BP,D_PMF
L_2:
		AND	DX,7F7FH
		SUB	DX,2121H
		MOV	AL,94
		MUL	DH			;区号*94
		XOR	DH,DH
		ADD	AX,DX			;+位号
		SHL	AX,1

		XOR	BX,BX
		MOV	CX,6
L_10:
		SHL	AX,1
		RCL	BX,1
		LOOP	L_10
		SHR	AX,1
		SHR	AX,1
		MOV	SI,AX			;偏移,BX=逻辑页号

		CMP	BX,BP			;判字库最后页号?
		JA	L_20
		MOV	DX,DI			;申请的描述字
		MOV	AX,4400H		;AH映射,AL物理页号
		INT	67H
		MOV	DS,D_SEG		;物理窗口段
		MOV	CX,20H
		XOR	DI,DI			;存放地址
		REP	MOVSB			;传送
L_20:
		PUSH	CS
		POP	DX
L_30:
		POP	AX
		POP	BX
		POP	CX
		POP	DI
		POP	SI
		POP	BP
		POP	ES
		POP	DS
		IRET
INT_7F		ENDP

;****************************************************************************
BEGIN:
		MOV	SI,80H			;10.22
		LODSB
		OR	AL,AL
		JZ	L_S10
L_S2:
		LODSB
		CMP	AL,0DH
		JZ	L_S10
		CMP	AL,' '
		JBE	L_S2
		CMP	AL,'/'
		JNZ	L_S2
		LODSB
		AND	AL,5FH
		CMP	AL,'N'                  ;驻留基本内存?
		JNZ	L_S10
		MOV	D_RAM,AL
L_S10:
		MOV	AX,4A06H
		MOV	SI,3			;取驻留状态
		INT	2FH
		CMP	BX,4A06H		;判是否已驻留?
		JNZ	L_S12
		MOV	DX,OFFSET D_ALREADY
L_ERR:
		MOV	AH,9
		INT	21H
		MOV	AX,4C01H
		INT	21H
L_S12:
		XOR	AX,AX
		MOV	ES,AX
		MOV	ES,ES:[19EH]		;INT67段
		MOV	DI,0AH			;偏移
		MOV	SI,OFFSET D_EMM 	;EMS设备名
		MOV	CX,8
		REPE	CMPSB			;比较
		JZ	L_S14
		MOV	DX,OFFSET D_NOEMS	;'NOT INSTALL EMS!'
		JMP	SHORT L_ERR
L_S14:
		MOV	AH,41H			;取物理窗口段
		INT	67H
		OR	AH,AH
		JZ	L_S20
		MOV	DX,OFFSET D_EMSERR	;'EMS ERROR!'
		JMP	SHORT L_ERR
L_S20:
		MOV	D_SEG,BX		 ;物理窗口段

		MOV	SI,5DH
		MOV	AX,CS
		CMP	AX,0A000H		;LH?
		JB	L_S30
		MOV	SI,6DH
L_S30:
		LODSW
		AND	AX,5F5FH
		MOV	DS:[101H],AX
		CMP	AL,'J'
		JZ	L_S40
		CMP	AL,'F'
		JZ	L_S40
		MOV	AL,'J'
		MOV	DS:[101H],AL
L_S40:
		CALL	S_READ
		JNB	L_S50
		JMP	L_ERR
L_S50:
		MOV	AX,D_HAN
		MOV	D_HJ,AX
		MOV	D_HF,AX
		MOV	AX,D_PAG
		MOV	D_PMJ,AX
		MOV	D_PMF,AX

		MOV	AL,DS:[102H]		;第二字库
		CMP	AL,' '
		JZ	L_S70
		CALL	S_READ			;拷贝第二字库
		JB	L_S70
		MOV	AX,D_HAN
		MOV	BX,D_PAG
		CMP	BYTE PTR DS:[102H],'F'
		JNZ	L_S40
		MOV	D_HF,AX
		MOV	D_PMF,BX
		JMP	SHORT L_S70
L_S60:
		MOV	D_HJ,AX
		MOV	D_PMJ,BX
L_S70:
		MOV	BYTE PTR DS:[100H],'4'

		MOV	AX,CS
		CMP	AX,0A000H
		JA	L_S75
		CMP	D_RAM,'N'               ;驻留基本内存
		JZ	L_S75
		CALL	S_GETUMB		;分配UMB段
		JZ	L_S80
L_S75:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		CALL	S_SETINT
		MOV	DX,OFFSET BEGIN 	;驻留
		INT	27H
L_S80:
		MOV	AX,D_UMB
		OR	AX,AX
		JZ	L_S75
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
		MOV	DX,OFFSET INT_7F
		MOV	AX,257FH
		INT	21H
	INCLUDE EXIT1.INC
		RET
S_SETINT	ENDP

;子程序:拷贝字库 AL=字库名(J,F)
S_READ		PROC	NEAR
		CMP	AL,'F'
		JZ	L_R0
		XOR	AL,AL
L_R0:
		MOV	D_FILE[5],AL

		MOV	DX,OFFSET D_FILE	;'HZK16',0
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_R1
		CALL	S_PATH			;查找本程序路径
		MOV	DX,OFFSET F_S
		MOV	AX,3D00H		;打开
		INT	21H
		JNB	L_R1
		MOV	DX,OFFSET D_NOFILE	;'NOT FOUND FILE HZK16!'
		STC
		RET
L_R1:
		MOV	D_HANDLE,AX		;文件号

		MOV	BX,10H			;页数
		MOV	AH,43H			;分配页
		INT	67H
		OR	AH,AH
		JZ	L_R3
L_R2:
		MOV	DX,OFFSET D_EMSERR
		STC
		RET
L_R3:
		MOV	D_HAN,DX		;描述字

		MOV	DS,D_SEG		;物理窗口段
		XOR	CX,CX
L_R4:
		CMP	CX,10H
		JZ	L_R5
		MOV	BX,CX			;逻辑页号
		MOV	DX,CS:D_HAN		;描述字
		MOV	AX,4400H		;AH映射,AL物理页号
		INT	67H
		OR	AH,AH
		JNZ	L_R2
		INC	CX
		CMP	CX,10H
		JZ	L_R5
		MOV	BX,CX			;逻辑页号
		MOV	AX,4401H		;AH映射,AL物理页号
		INT	67H
		OR	AH,AH
		JNZ	L_R2
		INC	CX
L_R5:
		PUSH	CX
		MOV	BX,CS:D_HANDLE
		MOV	CX,8000H
		MOV	DX,0
		MOV	AH,3FH
		INT	21H
		CMP	AX,CX
		JB	L_R6
		POP	CX
		JMP	L_R4
L_R6:
		POP	CX
		DEC	CX
		PUSH	CS
		POP	DS
		MOV	D_PAG,CX		 ;最后逻辑页号
		MOV	AH,3EH
		INT	21H
		RET
S_PATH: ;查找本程序路径
		MOV	DS,DS:[2CH]		;环境段
		XOR	SI,SI
L_P1:
		CMP	WORD PTR DS:[SI],0	;查找环境区尾?
		JZ	L_P2
		INC	SI
		JMP	SHORT L_P1
L_P2:
		ADD	SI,4
		MOV	DI,OFFSET F_S		;带路径源文件名区
		PUSH	CS
		POP	ES
		CALL	S_MOVE
		PUSH	CS
		POP	DS
L_P4:
		CMP	BYTE PTR [DI-1],'\'
		JZ	L_P5
		CMP	BYTE PTR [DI-1],':'
		JZ	L_P5
		DEC	DI
		JMP	SHORT L_P4
L_P5:
		MOV	SI,OFFSET D_FILE
S_MOVE:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	S_MOVE
		RET
S_READ		ENDP

D_HAN		DW	0			;描述字
D_PAG		DW	0			;最后页号
D_FILE		DB	'HZK16',0,0             ;文件名
D_HANDLE	DW	0			;文件号
F_S		DB	40 DUP(0)

D_NAME		DB	'READ4',0
D_ALREADY	DB	'READ4 IS ALREADY!',7,13,10,'$'
D_NOFILE	DB	'NOT FOUND FILE HZK16!',7,13,10,'$'
D_NOEMS 	DB	'NOT INSTALL EMS!',7,13,10,'$'
D_EMSERR	DB	'EMS ERROR!',7,13,10,'$'
D_EMM		DB	'EMMXXXX0',0

CSEG		ENDS
		END	START

;	READ6.ASM (2.13L)
;	1995.1.24
;	1999.11.2, 11.16

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

	INCLUDE EXIT.INC

S_EX		PROC	NEAR
		RET
S_EX		ENDP

INT_7F		PROC	FAR
		STI
		CLD
		PUSH	DS
		PUSH	ES
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	SI
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		OR	AH,AH		;=0繁体,非0简体
		JZ	L_2
L_1:
		MOV	SI,J_AX
		MOV	CL,J_DL
		JMP	SHORT L_3
L_2:
		MOV	SI,F_AX
		MOV	CL,F_DL
L_3:
		AND	DX,7F7FH
		SUB	DX,2121H
		MOV	AL,94
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX			;得汉字序号
		MOV	DL,32
		MUL	DX			;得字节位置
		ADD	AX,SI			;扩展内存偏移
		ADC	DL,CL			;	 段
		MOV	D_SOFF,AX
		MOV	D_SSEG,DL
		MOV	CX,10H
		MOV	SI,OFFSET D_GDT 	;GDT表地址
		MOV	AH,87H			;调ROM-BIOS
		INT	15H
		MOV	DX,CS
		ADD	DX,8
L_6:
		POP	SI
		POP	CX
		POP	BX
		POP	AX
		POP	ES
		POP	DS
		IRET
INT_7F		ENDP

J_AX		DW	0			;简体字库文件首址
J_DL		DB	0
F_AX		DW	0			;繁体字库文件首址
F_DL		DB	0

D_GDT		DB	16 DUP (0)
D_CX1		DW	20H			;传送字节数
D_SOFF		DW	0			;源地址
D_SSEG		DB	0
		DB	93H, 0, 0
D_CX2		DW	20H			;传送字节数
D_TOFF		DW	0			;目标地址
D_TSEG		DB	0
		DB	93H, 0, 0
		DB	16 DUP (0)

;****************************************************************************
BEGIN:
		MOV	AX,4A06H
		MOV	SI,3			;取驻留状态
		INT	2FH
		CMP	BX,4A06H		;判是否已驻留?
		JNZ	L_S10
		MOV	DX,OFFSET D_ALREADY
L_ERR:
		MOV	AH,9
		INT	21H
		MOV	AX,4C01H
		INT	21H
L_S10:
		MOV	AL,31H
		OUT	70H,AL
		IN	AL,71H
		MOV	AH,AL
		MOV	AL,30H
		OUT	70H,AL
		IN	AL,71H			;AX=扩充内存大小(K)
		OR	AX,AX
		JNZ	L_S20
		MOV	DX,OFFSET D_NOEX
		JMP	SHORT L_ERR
L_S20:
		MOV	D_EX,AX

		MOV	SI,5DH			;1.23
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
		CALL	S_READ			;拷贝第一字库
		JB	L_ERR
		MOV	AX,D_AX
		MOV	J_AX,AX 		;保存
		MOV	F_AX,AX
		MOV	AL,D_DL
		MOV	J_DL,AL
		MOV	F_DL,AL

		MOV	AL,DS:[102H]		;第二字库
		CMP	AL,' '
		JZ	L_S52
		CALL	S_READ			;拷贝第二字库
		JB	L_S52
		MOV	AX,D_AX
		MOV	DL,D_DL
		CMP	BYTE PTR DS:[102H],'F'
		JZ	L_S50
		MOV	J_AX,AX
		MOV	J_DL,DL
		JMP	SHORT L_S52
L_S50:
		MOV	F_AX,AX 		;保存
		MOV	F_DL,DL
L_S52:
		MOV	DX,CS
		MOV	CL,4
		SHR	DH,CL
		MOV	AX,CS
		SHL	AX,CL
		ADD	AX,80H
		ADC	DH,0
		MOV	D_TOFF,AX		;读字库传送目标地址CS:80H
		MOV	D_TSEG,DH
		MOV	AX,20H
		MOV	D_CX1,AX		;读字库字节数
		MOV	D_CX2,AX

		MOV	DX,OFFSET INT_7F
		MOV	AX,257FH
		INT	21H

	INCLUDE EXIT1.INC			;1.24

		MOV	BYTE PTR DS:[100H],'6'  ;READ6标志
		MOV	DX,OFFSET BEGIN
		INT	27H

;子程序:拷贝字库 AL=字库名(J,F)
S_READ		PROC	NEAR
		CMP	AL,'F'
		JZ	L_R0
		XOR	AL,AL
L_R0:
		MOV	SFILE[5],AL

		MOV	DX,OFFSET SFILE
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_R1
		CALL	S_PATH			;查找本程序路径
		MOV	DX,OFFSET F_S
		MOV	AX,3D00H		;打开
		INT	21H
		JNB	L_R1
		MOV	DX,OFFSET D_NOFILE
		STC
		RET
L_R1:
		MOV	BX,AX
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4202H		;取文件长度
		INT	21H
		MOV	CX,400H 		;=1K
		DIV	CX
		OR	DX,DX
		JZ	L_R2
		INC	AX
L_R2:
		MOV	CX,AX			;文件长度(K)

		MOV	AX,D_EX 		;扩充内存大小
		CMP	AX,CX			;判?
		JNB	L_R3
		MOV	DX,OFFSET D_NOEX
		STC
		RET
L_R3:
		SUB	AX,CX
		MOV	D_EX,AX 		;剩余大小

		MOV	DX,400H 		;=1K
		MUL	DX
		ADD	DL,10H
		MOV	D_TOFF,AX		;安装位置
		MOV	D_TSEG,DL
		MOV	D_AX,AX 		;字库起始地址
		MOV	D_DL,DL

		MOV	DX,CS
		MOV	CL,4
		SHR	DH,CL
		MOV	AX,CS
		SHL	AX,CL
		ADD	AX,OFFSET D_BUF
		ADC	DH,0
		MOV	D_SOFF,AX		;传送源地址CS:BUF
		MOV	D_SSEG,DH

		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4200H		;指针移文件首
		INT	21H
L_R4:
		MOV	DX,OFFSET D_BUF
		MOV	CX,1000H
		MOV	AH,3FH			;读文件
		INT	21H
		JB	L_R5
		OR	AX,AX
		JZ	L_R5
		MOV	D_CX1,AX		;长度(字节)
		MOV	D_CX2,AX
		MOV	CX,AX
		SHR	CX,1			;字数
		MOV	SI,OFFSET D_GDT
		MOV	AH,87H			;传送
		INT	15H
		MOV	AX,D_CX1
		ADD	D_TOFF,AX		;目标地址后移
		ADC	D_TSEG,0
		JMP	SHORT L_R4
L_R5:
		MOV	AH,3EH			;关闭文件
		INT	21H
		CLC
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
		MOV	SI,OFFSET SFILE
S_MOVE:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	S_MOVE
		RET
S_READ		ENDP

D_ALREADY	DB	'READ6 IS ALREADY!',7,13,10,'$'
D_NOEX		DB	'NO ENOUGH SPACE OF EXPANTED MEMORY!',7,13,10,'$'
D_NOFILE	DB	'NOT FOUND HZK16!',7,13,10,'$'
SFILE		DB	'HZK16',0,0
F_S		DB	40 DUP(0)
D_EX		DW	0			;扩充内存大小
D_AX		DW	0
D_DL		DB	0

D_BUF	EQU	$

CSEG		ENDS
		END	START

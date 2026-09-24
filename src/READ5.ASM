;	READ5.ASM (2.13L)
;	1995.1.24, 12.17
;	1999.11.2, 11.16

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

	;命令行:READ5 [J][F]

		ORG	100H
START:		JMP	BEGIN

D_HANDJ 	DW	0			;[103H]
D_HANDF 	DW	0			;[105H]

D_XMS		DD	0			;XMS驱动模块地址
D_CX		DW	32,0			;传送字节数
D_SHAN		DW	0			;源句柄
D_SOFF		DW	0			;32位源地址
D_SSEG		DW	0
		DW	0
D_TOFF		DW	80H			;32位目标地址CS:80H
D_TSEG		DW	0

	INCLUDE EXIT.INC

S_EX		PROC	NEAR
		PUSH	CS
		POP	DS
		MOV	DX,D_HANDJ
		MOV	AH,0AH
		CALL	D_XMS
		MOV	DX,D_HANDF
		MOV	AH,0AH
		CALL	D_XMS
		RET
S_EX		ENDP

INT_7F		PROC	FAR
		STI
		CLD
		PUSH	DS
		PUSH	AX
		PUSH	BX
		PUSH	SI
		PUSH	CS
		POP	DS
		OR	AH,AH			;=0繁体,非0简体
		JZ	L_50
L_40:
		MOV	AX,D_HANDJ		;简体句柄
		JMP	SHORT L_60
L_50:
		MOV	AX,D_HANDF		;繁体句柄
L_60:
		MOV	D_SHAN,AX

		AND	DX,7F7FH
		SUB	DX,2121H
		MOV	AL,94
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX			;得汉字序号
		MOV	DL,32
		MUL	DX			;得字节位置
		MOV	D_SOFF,AX
		MOV	D_SSEG,DX
		MOV	SI,OFFSET D_CX		;XMS块移动结构DS:SI
		MOV	AH,0BH			;XMS块移动
		CALL	D_XMS
		MOV	DX,CS
		ADD	DX,8
L_90:
		POP	SI
		POP	BX
		POP	AX
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
		MOV	AX,4300H		;取XMS安装状态
		INT	2FH
		CMP	AL,80H			;判XMS安装?
		JZ	L_S20
		MOV	DX,OFFSET D_NOXMS
		JMP	SHORT L_ERR
L_S20:
		MOV	AX,4310H		;取XMS驱动模块地址
		INT	2FH
		MOV	WORD PTR D_XMS,BX	;保存
		MOV	WORD PTR D_XMS+2,ES

		MOV	C_SSEG,CS

		MOV	SI,5DH
		MOV	AX,CS
		CMP	AX,0A000H		;判LH?
		JB	L_S30
		MOV	SI,6DH
L_S30:
		LODSW
		AND	AX,5F5FH
		MOV	DS:[101H],AX		;保存
		CMP	AL,'J'
		JZ	L_S40
		CMP	AL,'F'
		JZ	L_S40
		MOV	AL,'J'
		MOV	DS:[101H],AL
L_S40:
		CALL	S_READ			;拷贝第一字库
		JB	L_ERR
		MOV	AX,C_THAN
		MOV	D_HANDJ,AX		;保存简体句柄
		MOV	D_HANDF,AX

		MOV	AL,DS:[102H]		;第二字库
		CMP	AL,' '
		JZ	L_S52
		CALL	S_READ			;拷贝第二字库
		JB	L_S52
		MOV	AX,C_THAN
		CMP	BYTE PTR DS:[102H],'F'
		JNZ	L_S50
		MOV	D_HANDF,AX
		JMP	SHORT L_S52
L_S50:
		MOV	D_HANDJ,AX
L_S52:
		MOV	BYTE PTR DS:[100H],'5'  ;XMS标志

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

D_NCFP		DW	0			;原内存分配策略
D_UMB0		DW	0			;原UMB连接状态
D_UMB		DW	0			;分配UMB段
D_LEN		DW	0			;本模块长度(节)
D_RAM		DB	0			;='N':驻留基本内存

;子程序:取UMB段
S_GETUMB	PROC	NEAR
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

S_SETINT	PROC	NEAR
		MOV	D_TSEG,DS
		MOV	DX,OFFSET INT_7F
		MOV	AX,257FH		;建中断
		INT	21H
	INCLUDE EXIT1.INC			;1.24
		RET
S_SETINT	ENDP

;子程序:拷贝字库 AL=字库名(J,F)
S_READ		PROC	NEAR
		CMP	AL,'J'
		JZ	L_R0
		MOV	SFILE+5,AL
L_R0:
		XOR	AX,AX
		MOV	C_TOFF,AX
		MOV	C_TSEG,AX

		MOV	DX,OFFSET SFILE 	;指向当前目录的HZK16
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_R1
		CALL	S_PATH			;查找本程序路径
		MOV	DX,OFFSET F_S
		MOV	AX,3D00H		;打开
		INT	21H
		JB	L_ERR1
L_R1:
		MOV	HAN,AX			;源文件号

		MOV	BX,AX
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4202H		;取文件长度
		INT	21H
		MOV	CX,400H 		;=1K
		DIV	CX
		OR	DX,DX
		JZ	L_R2
		INC	AX			;文件长度K数
L_R2:
		MOV	DX,AX
		MOV	AH,9			;分配扩充内存
		CALL	D_XMS
		OR	AX,AX
		JZ	L_ERR2
		MOV	C_THAN,DX		;句柄

		MOV	BX,HAN			;源文件号
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4200H		;移文件首
		INT	21H
L_R3:
		MOV	DX,OFFSET D_BUF 	;读写缓冲区首址
		MOV	CX,1000H		;一次读4K
		MOV	AH,3FH			;读文件
		INT	21H
		JB	L_R4
		OR	AX,AX
		JZ	L_R4
		MOV	C_CX,AX 		;传送字节数
		MOV	SI,OFFSET C_CX		;
		MOV	AH,0BH
		CALL	D_XMS
		MOV	AX,C_CX
		ADD	C_TOFF,AX		;目标地址+传送字节数
		ADC	C_TSEG,0
		JMP	SHORT L_R3
L_R4:
		MOV	AH,3EH			;关闭源文件
		INT	21H
		CLC
		RET
L_ERR1:
		MOV	DX,OFFSET D_NOFILE
		STC
		RET
L_ERR2:
		MOV	DX,OFFSET D_XMSERR
		STC
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

SFILE		DB	'HZK16',0,0             ;源文件
F_S		DB	40 DUP(0)		;带路径文件名
HAN		DW	0			;源文件号
C_CX		DW	1000H,0 		;传送字节数
		DW	0			;源句柄
C_SOFF		DW	OFFSET D_BUF		;32位源地址
C_SSEG		DW	0
C_THAN		DW	0
C_TOFF		DW	0			;32位目标地址
C_TSEG		DW	0

D_NAME		DB	'READ5',0
D_ALREADY	DB	'READ5 IS ALREADY!',7,13,10,'$'
D_NOFILE	DB	'NOT FOUND THE FILE!',7,13,10,'$'
D_XMSERR	DB	'NOT ENOUGH SPACE OF XMS!',7,13,10,'$'
D_NOXMS 	DB	'NO XMS DRIVE!',7,13,10,'$'

D_BUF	EQU	$

SEG_A		ENDS
		END	START

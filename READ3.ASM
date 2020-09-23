;	READ3.ASM (2.13L)
;	1995.1.24, 12.17
;	1999.11.2, 11.16

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

	;命令行:READV [J][F]
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

D_XPH		DB	0			;虚盘号
D_HZK1		DB	0			;第一字库
D_HZK2		DB	0			;第二字库
J_AX		DW	0			;虚盘简体字库文件首址
J_DL		DB	10H
F_AX		DW	0			;虚盘繁体字库文件首址
F_DL		DB	10H

D_GDT		DB	16 DUP (0)
		DW	20H			;传送字节数
D_SOFF		DW	0			;源地址
D_SSEG		DB	10H
		DB	93H, 0, 0
		DW	20H			;传送字节数
D_TOFF		DW	0			;目标地址
D_TSEG		DB	0
		DB	93H, 0, 0
		DB	16 DUP (0)

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
		MOV	DX,CS
		MOV	CL,4
		SHR	DH,CL
		MOV	AX,CS
		MOV	ES,AX
		MOV	D_CS,AX

		SHL	AX,CL
		ADD	AX,0A0H
		MOV	D_TOFF,AX		;传送目标地址CS:80H
		MOV	D_TSEG,DH

		MOV	D_XPH,2 		;指向C盘
L_S20:
		MOV	AL,D_XPH
		MOV	BX,OFFSET D_BUF
		MOV	CX,1
		XOR	DX,DX
		INT	25H			;读盘首扇区
		POP	AX
		JNB	L_S22
		MOV	AL,D_XPH
		MOV	BX,OFFSET D_INT25
		MOV	CX,0FFFFH
		INT	25H			;读大盘分区首扇区
		POP	AX
		JNB	L_S22
		MOV	DX,OFFSET D_VDISKERR
		JMP	L_ERR
L_S22:
		CMP	BYTE PTR DS:[BX+3],'V'  ;判VDISK?
		JZ	L_S30
		CMP	BYTE PTR DS:[BX+3],'R'  ;判RAMDRIVE?
		JZ	L_S24
		INC	D_XPH			;下一盘号
		JMP	SHORT L_S20
L_S24:
		MOV	CX,10H
		MOV	SI,OFFSET D_GDT 	;GDT表地址
		MOV	AH,87H			;调ROM-BIOS
		INT	15H
		MOV	SI,OFFSET D_BUF 	;虚拟盘首
		MOV	DI,0A0H 		;读出
		MOV	CX,10H			;10H个字
		REP	CMPSW			;比较
		JZ	L_S26
		ADD	D_SOFF,400H		;下一扇区
		JNB	L_S24
		INC	D_SSEG			;下一段
		JMP	SHORT L_S24
L_S26:
		MOV	AX,D_SOFF		;虚拟盘首绝对地址
		MOV	D_BP,AX
		MOV	AL,D_SSEG
		CBW
		MOV	D_DI,AX
L_S30:
		MOV	AL,D_XPH		;虚盘号
		INC	AL
		MOV	HZK16,AL		;虚盘盘号(查找用)
		ADD	AL,40H
		MOV	VFILE,AL

		MOV	SI,5DH
		MOV	AX,CS
		CMP	AX,0A000H		;LH?
		JB	L_S40
		MOV	SI,6DH
L_S40:
		LODSW
		AND	AX,5F5FH
		MOV	WORD PTR D_HZK1,AX	;保存
		CMP	AL,'J'
		JZ	L_S42
		CMP	AL,'F'
		JZ	L_S42
		MOV	AL,'J'
		MOV	D_HZK1,AL
L_S42:
		CALL	S_READ			;拷贝简体字库
		JNB	L_S50
		MOV	DX,OFFSET D_NOFILE
		JMP	L_ERR
L_S50:
		MOV	J_AX,BP
		MOV	F_AX,BP
		MOV	AX,DI
		MOV	J_DL,AL
		MOV	F_DL,AL

		MOV	AL,D_HZK2		;第二字库
		CMP	AL,' '
		JZ	L_S70
		CALL	S_READ			;拷贝繁体字库
		JB	L_S70
		CMP	D_HZK2,'J'
		JZ	L_S66
		MOV	F_AX,BP
		MOV	AX,DI
		MOV	F_DL,AL
		JMP	SHORT L_S70
L_S66:
		MOV	J_AX,BP
		MOV	AX,DI
		MOV	J_DL,AL
L_S70:
		MOV	BYTE PTR DS:[100H],'3'  ;READV标志

		MOV	AX,CS
		CMP	AX,0A000H		;判LH?
		JA	L_S75
		CMP	D_RAM,'N'               ;驻留基本内存
		JZ	L_S75
		CALL	S_GETUMB		;分配UMB段
		JZ	L_S80
L_S75:
	;	MOV	ES,DS:[2CH]
	;	MOV	AH,49H			;清环境块
	;	INT	21H
		CALL	S_SETINT
		MOV	DX,OFFSET BEGIN 	;驻留常规内存
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
		CALL	S_UMB			;分配UMB段
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
		MOV	DX,DS
		MOV	CL,4
		SHR	DH,CL
		MOV	AX,DS
		SHL	AX,CL
		ADD	AX,80H
		MOV	D_TOFF,AX		;传送目标地址CS:80H
		MOV	D_TSEG,DH

		MOV	DX,OFFSET INT_7F
		MOV	AX,257FH
		INT	21H
	INCLUDE EXIT1.INC			;1.24
		RET
S_SETINT	ENDP

;子程序:拷贝字库 AL=字库名(J,F)
S_READ		PROC	NEAR
		MOV	AH,AL
		CMP	AL,'J'
		JNZ	L_R0
		MOV	AX,2000H
L_R0:
		MOV	SFILE+5,AL		;源文件名
		MOV	VFILE+7,AL		;虚盘文件名
		MOV	HZK16+6,AH		;FCB文件名

		MOV	BP,D_BP
		MOV	DI,D_DI
		MOV	DX,OFFSET VFILE 	;指向目标文件
		MOV	AX,4300H		;取文件属性
		INT	21H
		JNB	L_R4			;该文件已存在,转
		MOV	DX,OFFSET SFILE 	;指向当前目录的HZK16
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_R1
		CALL	S_PATH			;查找本程序路径
		MOV	DX,OFFSET F_S
		MOV	AX,3D00H		;打开
		INT	21H
		JB	L_ERROR
L_R1:
		MOV	H_S,AX			;源文件号
		MOV	DX,OFFSET VFILE 	;指向虚拟盘HZK16
		MOV	CX,21H			;只读
		MOV	AH,3CH			;在虚拟盘建立文件
		INT	21H
		JB	L_ERROR
		MOV	H_V,AX			;目标文件号
L_R2:
		MOV	BX,H_S			;源文件号
		MOV	DX,OFFSET D_BUF+200H	;读写缓冲区首址
		MOV	CX,1000H		;一次读4K
		MOV	AH,3FH			;读文件
		INT	21H
		JB	L_R3
		OR	AX,AX
		JZ	L_R3
		MOV	CX,AX
		MOV	BX,H_V			;目标文件号
		MOV	AH,40H			;写文件
		INT	21H
		JMP	SHORT L_R2
L_ERROR:
		STC
		RET
L_R3:
		MOV	BX,H_S
		MOV	AH,3EH			;关闭源文件
		INT	21H
		MOV	BX,H_V
		MOV	AH,3EH			;关闭目标文件
		INT	21H
L_R4:
		MOV	BX,OFFSET D_BUF 	;虚拟盘首扇区
		MOV	AL,[BX+0DH]		;每簇扇区数
		CBW
		MOV	DS:[70H],AX
		MOV	AL,[BX+16H]		;每FAT扇区数
		MUL	BYTE PTR DS:[BX+10H]	;乘FAT数
		ADD	AX,[BX+0EH]		;加保留扇区数
		MUL	WORD PTR DS:[BX+0BH]	;乘每扇区字节数
		MOV	CX,AX
		MOV	AX,20H
		MUL	WORD PTR DS:[BX+11H]	;根目录项数乘20H
		ADD	AX,CX			;加
		ADD	BP,AX			;虚拟盘文件区首址
		ADC	DI,0

		MOV	DX,OFFSET HZK16
		MOV	AH,11H			;查找目录项
		INT	21H			;DTA地址:DS:80H
		OR	AL,AL
		JNZ	L_ERROR
		MOV	AX,DS:[9BH]		;首簇号
		SUB	AX,2
		MUL	WORD PTR DS:[70H]	;乘每簇扇区数
		MUL	WORD PTR DS:[BX+0BH]	;乘每扇区字节数
		ADD	BP,AX			;虚盘字库文件首址
		ADC	DI,DX
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

D_NAME		DB	'READ3',0
D_ALREADY	DB	'READ3 IS ALREADY!',7,13,10,'$'
D_VDISKERR	DB	'VDISK READ ERROR!',7,13,10,'$'
D_NOFILE	DB	'NOT FOUND HZK16!',7,13,10,'$'
SFILE		DB	'HZK16',0,0
VFILE		DB	'D:HZK16',0,0
HZK16		DB	3,'HZK16      ',25 DUP (0)
F_S		DB	40 DUP(0)
H_S		DW	0
H_V		DW	0
D_BP		DW	0
D_DI		DW	10H
D_INT25 	DD	0		;首扇区号	;读大盘扇区
		DW	1		;扇区数
		DW	OFFSET D_BUF	;缓冲区偏移
D_CS		DW	0		;      段

D_BUF		EQU	$

SEG_A		ENDS
		END	START

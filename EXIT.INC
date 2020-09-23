;	EXIT.INC 清理内存及内存管理(装在读显示字库模块中)
;	1995.2.8
;	1996.2.10

TSRD		DW	0			;打印模块开始
TSRC		DW	0			;内存驻留模块计数
TSR		DD	64 DUP(0)		;内存驻留模块PSP段和环境段保存区

D_INTNUM	DW	13			;保存中断个数
D_INT		DB	5			;中断号
D_INT5		DD	0			;中断向量
		DB	8
D_INT8		DD	0
		DB	9
D_INT9		DD	0
		DB	10H
D_INT10 	DD	0
		DB	16H
D_INT16 	DD	0
		DB	17H
D_INT17 	DD	0
		DB	1CH
D_INT1C 	DD	0
		DB	1DH
D_INT1D 	DD	0
		DB	21H
D_INT21 	DD	0
		DB	27H
D_INT27 	DD	0
		DB	28H
D_INT28 	DD	0
		DB	2FH
D_INT2F 	DD	0
		DB	60H
D_INT60 	DD	0

INT_2F		PROC	FAR
		PUSHF
		CMP	AX,4A06H		;判功能号?
		JNZ	L_2F10
		POPF
		OR	SI,SI			;子功能0?
		JNZ	L_2F01
		CALL	S_EX			;清EMS或XMS
		CALL	S_EXIT			;清内存
		MOV	AX,3			;重设显示方式
		INT	10H
		IRET
L_2F01:
		CMP	SI,1			;子功能1?
		JNZ	L_2F03
L_2F02:
		CALL	S_EXIT1 		;清内存
		IRET
L_2F03:
		CMP	SI,2			;子功能2?
		JZ	L_2F02
		CMP	SI,3			;子功能3?
		JNZ	L_2F11
		XOR	AX,AX
		MOV	BX,4A06H		;返回已驻留状态
		MOV	CX,CS			;返回BIOS中断向量表	2.10
		MOV	DX,OFFSET D_INT
		IRET
L_2F10:
		POPF
L_2F11:
		JMP	CS:D_INT2F		;执行原INT2F
INT_2F		ENDP

S_EXIT1 	PROC	NEAR
		CMP	CS:TSRD,0		;判安装打印机驱动模块?
		JNZ	S_EXIT
		RET
S_EXIT:
		CMP	SI,0
		JNZ	L_E2
		MOV	DI,OFFSET D_INT 	;中断保存区
		MOV	CX,CS:D_INTNUM		;个数
L_E1:
		MOV	AL,CS:[DI]		;中断号
		MOV	DX,CS:[DI+1]		;    偏移
		MOV	DS,CS:[DI+3]		;    段
		MOV	AH,25H			;恢复中断
		INT	21H
		ADD	DI,5			;下一中断
		LOOP	L_E1

		XOR	AX,AX
		MOV	ES,AX
		MOV	DI,1E0H
		MOV	CX,20H
		REP	STOSB			;清中断78H-7FH
		JMP	SHORT L_E3
L_E2:
		CMP	SI,1
		JNZ	L_E3
		LDS	DX,CS:D_INT17
		MOV	AX,2517H		;恢复INT17
		INT	21H
L_E3:
		PUSH	CS
		POP	DS

		MOV	DI,OFFSET TSR		;内存驻留模块PSP段保存区
		CMP	SI,0
		JZ	L_E5
		MOV	AX,TSRD 		;打印模块PSP段序号
		CMP	SI,1
		JZ	L_E4
		INC	AX
L_E4:
		SHL	AX,1
		SHL	AX,1
		ADD	DI,AX
L_E5:
		MOV	SI,DI
L_EXIT:
		LODSW
		OR	AX,AX
		JZ	N_EXIT
		MOV	ES,AX			;PSP段
		MOV	AH,49H			;清
		INT	21H
		JMP	SHORT L_EXIT
N_EXIT:
		RET
S_EXIT1 	ENDP

S_SETTSR	PROC	NEAR
		PUSH	DS
		PUSH	AX
		PUSH	BX
		PUSH	SI
		MOV	SI,DS
		XOR	AX,AX
		MOV	DS,AX
		CMP	SI,DS:[5EH]		;是否驱动程序段?
		PUSH	CS
		POP	DS
		JNZ	L_ST1
		MOV	AX,TSRC
		MOV	TSRD,AX
L_ST1:
		MOV	AH,51H			;取PSP段
		INT	21H
		MOV	AX,TSRC 		;计数
		CMP	AX,64			;判TSR保存区满?
		JZ	L_STRET
		SHL	AX,1			;*4
		SHL	AX,1
		MOV	SI,OFFSET TSR		;保存区
		ADD	SI,AX
		MOV	[SI],BX 		;保存
		MOV	DS,BX
		MOV	AX,DS:[2CH]		;环境段
		MOV	CS:[SI+2],AX
		INC	CS:TSRC 		;计数+1
L_STRET:
		POP	SI
		POP	BX
		POP	AX
		POP	DS
		RET
S_SETTSR	ENDP

INT_21		PROC	FAR
		PUSHF
		CMP	AH,31H			;判驻留功能?
		JNZ	L_2101
		CALL	S_SETTSR		;保存TSR段
L_2101:
		POPF
		JMP	CS:D_INT21		;执行原INT21
INT_21		ENDP

INT_27		PROC	FAR
		CALL	S_SETTSR		;保存TSR段
		JMP	CS:D_INT27		;执行原INT27
INT_27		ENDP

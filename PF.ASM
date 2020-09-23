;	PF.ASM 打印输出转文件程序
;	1994.4.7, 4.10
;	1996.12.3

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

D_INT17 	DD	0			;原INT17
D_DI		DW	140H			;指针
D_END		DW	0			;缓冲区尾

INT_17		PROC	FAR
		STI
		CLD
		CMP	AH,17H			;取安装状态?
		JNZ	L_10
		MOV	AL,AH
		PUSH	CS
		POP	ES
		IRET
L_10:
		JMP	SHORT L_20
K_DY	EQU	$-1				;正常打印=0
		JMP	CS:D_INT17
L_20:
		OR	AH,AH			;=0:打印
		JNZ	L_33
		PUSH	DI
		MOV	DI,CS:D_DI		;取指针
		CMP	DI,CS:D_END		;判尾?
		JZ	L_30
		MOV	CS:[DI],AL		;写入
		INC	DI			;指针+1
		MOV	CS:D_DI,DI		;存指针
L_30:
		POP	DI
L_33:
		MOV	AH,10H
		IRET
INT_17		ENDP
;****************************************************************************
BEGIN:
		MOV	SI,80H
		LODSB
		OR	AL,AL
		JNZ	L_S10
		MOV	DX,OFFSET MSG		;使用说明
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_S10:
		CBW
		MOV	BX,AX
		MOV	BYTE PTR [BX+SI],0
L_S20:
		LODSB
		CMP	AL,' '                  ;空格?
		JZ	L_S20
		CMP	AL,'0'                  ;数字?
		JB	L_S100
		CMP	AL,'9'
		JA	L_S100
		AND	AL,0FH
		CMP	BYTE PTR [SI],0
		JZ	L_S30
		MOV	CL,10
		MUL	CL
		ADD	AL,[SI]
		SUB	AL,'0'
L_S30:
		CBW
		CMP	AL,63			;>63?
		JBE	L_S40
		MOV	AL,3FH
L_S40:
		MOV	CX,400H 		;=1K
		MUL	CX
		ADD	AX,140H 		;加缓冲区首(BEGIN)
		MOV	D_END,AX		;缓冲区尾
		MOV	DX,AX

		MOV	AH,17H			;取安装状态?
		INT	17H
		CMP	AH,AL
		JNZ	L_S50
		MOV	DX,OFFSET ALREADY
		JMP	SHORT L_ERR
L_S50:
		PUSH	DX
		MOV	AX,3517H
		INT	21H
		MOV	WORD PTR D_INT17,BX	;保存
		MOV	WORD PTR D_INT17+2,ES
		MOV	DX,OFFSET INT_17
		MOV	AX,2517H		;建中断
		INT	21H
		MOV	DX,OFFSET ALREADY+1
		MOV	AH,9
		INT	21H
		POP	DX
		INT	27H			;驻留
L_S100:
		MOV	DL,AL
		MOV	AH,17H			;取安装状态
		INT	17H
		CMP	AH,AL
		JZ	L_S110
		MOV	DX,OFFSET NOPF
		JMP	SHORT L_ERR
L_S110:
		CMP	DL,'!'                  ;初始化?
		JZ	L_S130
		CMP	DL,'+'                  ;正常打印?
		JZ	L_S140
		CMP	DL,'-'                  ;退出?
		JZ	L_S150
		MOV	DI,ES:D_DI
		MOV	AL,1AH			;文件结束标志
		STOSB
		LEA	DX,[SI-1]
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		JNC	L_S120
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_EXIT
L_S120:
		MOV	BX,AX
		MOV	DX,140H 		;BEGIN
		PUSH	ES
		POP	DS
		MOV	CX,D_DI
		SUB	CX,DX
		INC	CX
		MOV	AH,40H			;写文件
		INT	21H
		MOV	AH,3EH			;关闭文件
		INT	21H
L_EXIT:
		INT	20H
L_S130:
		MOV	ES:D_DI,140H		;BEGIN
		MOV	BYTE PTR ES:K_DY,5
		MOV	DX,OFFSET INIT
		JMP	L_ERR
L_S140:
		MOV	BYTE PTR ES:K_DY,0
		MOV	DX,OFFSET NORMAL
		JMP	L_ERR
L_S150:
		LDS	DX,ES:D_INT17
		MOV	AX,2517H
		INT	21H
		MOV	AH,49H
		INT	21H
		MOV	ES,ES:[2CH]
		MOV	AH,49H
		INT	21H
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET EXIT
		JMP	L_ERR

MSG		DB	'保存打印内容到文件程序',13,10
		DB	'格式: PF [缓冲区大小]  驻留内存(K数)',13,10
		DB	'      PF [文件名]      将缓冲区内容存文件',13,10
		DB	'      PF !             初始化',13,10
		DB	'      PF +             正常打印',13,10
		DB	'      PF -             退出,恢复原INT17',13,10
		DB	'其中: 缓冲区大小范围 1~63K',13,10
		DB	'      文件名应以非数字字符打头',13,10,'$'
ALREADY 	DB	7,'PF模块已经驻留!',13,10,'$'
INIT		DB	'PF模块已经初始化!',13,10,'$'
EXIT		DB	'PF模块已经退出!',7,13,10,'$'
NOPF		DB	'PF模块未安装!',7,13,10,'$'
NORMAL		DB	'恢复正常打印!',7,13,10,'$'

SEG_A		ENDS
		END	START

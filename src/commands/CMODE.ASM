;	CMODE.ASM
;	1995.10.1, 10.18

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:
		MOV	SI,5DH
		MOV	CX,1000H
L_1:
		LODSB
		CMP	AL,' '
		JZ	L_3
		SUB	AL,'0'
		CMP	AL,9
		JBE	L_2
		SUB	AL,7
L_2:
		XCHG	AL,CL
		MUL	CH
		ADD	AL,CL
		MOV	CL,AL
		JMP	SHORT L_1
L_3:
		MOV	AL,CL
		OR	AL,AL
		JZ	L_4
		XOR	AH,AH			;设置显示方式
		INT	10H
		JMP	SHORT L_5
L_4:
		MOV	AH,15			;取当前显示方式
		INT	10H
		MOV	BX,OFFSET D_16
		PUSH	AX
		MOV	CL,4
		SHR	AL,CL
		XLAT
		MOV	MSG[23],AL
		POP	AX
		PUSH	AX
		AND	AL,0FH
		XLAT
		MOV	MSG[24],AL
		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
		POP	AX
L_5:
		MOV	AH,4CH
		INT	21H

MSG		DB	'Curent displey mode is 00.',13,10
		DB	'Run CMODE nn to set display demo.',13,10
		DB	'  The nn is HEX number.',13,10,'$'
D_16		DB	'0123456789ABCDEF'

SEG_A		ENDS
		END	START

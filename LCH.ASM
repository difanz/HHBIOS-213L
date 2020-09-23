;	LCH.ASM
;	1996.2.20, 3.14
;	1999.2.11

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100h
START:		JMP	SHORT BEGIN

L_60:
		MOV	CX,8000H
		XOR	DX,DX
		MOV	AH,3FH			;���ļ�
		INT	21H
		CMP	AX,CX			;����?
		JNZ	L_70
		MOV	AX,DS
		ADD	AX,800H
		MOV	DS,AX
		ADD	BP,800H 		;��������
		JMP	SHORT L_60
L_70:
		POP	DS
		MOV	CL,4
		SHR	AX,CL
		INC	AX
		ADD	AX,DI			;������
		ADD	AX,BP

		PUSH	AX
		MOV	ES,DS:[100H]
		MOV	WORD PTR ES:[0B0F0H],SI ;0FE4A
		MOV	ES:[0B0F2H],CS		;0FE4C
		POP	DX
		MOV	AX,3100H
		INT	21H

;****************************************************************************
BEGIN:
		MOV	SP,100H 		;��ջ

		MOV	SI,3
		MOV	AX,4A06H		;�а�װ2.13
		INT	2FH
		CMP	BX,4A06H
		JZ	L_10
		MOV	DX,OFFSET NO213
		JMP	L_ERR
L_10:
		MOV	SI,BX
		MOV	AH,2FH			;ȡINT16
		INT	16H
		CMP	SI,4A06H		;�а�װCKBD?
		JZ	L_ERR
		MOV	AX,2006H		;ȡ���ģ�����BP:DX
		INT	16H
		OR	DX,DX			;��?
		JNZ	L_12
		MOV	DX,OFFSET NOWBZX
		JMP	L_ERR
L_12:
		MOV	ES,DX
		MOV	DS:[100H],DX

		CMP	BYTE PTR DS:[80H],0
		JZ	L_15
		MOV	DX,ES:[0B0F2H]		;��פ���Ĵʻ�� FE4C
		XOR	AX,AX
		MOV	ES:[0B0F0H],AX		;FE4A
		MOV	ES:[0B0F2H],AX		;FE4C
		OR	DX,DX			;��������ʻ�?
		JZ	L_18
		MOV	ES,DX
		MOV	AH,49H
		INT	21H
		MOV	ES,ES:[2CH]
		MOV	AH,49H
		INT	21H
		MOV	DX,OFFSET EXIT
		JMP	SHORT L_ERR
L_15:
		CMP	WORD PTR ES:[0B0F2H],0	;����פ��?	FE4C
		JZ	L_18
		MOV	DX,OFFSET ALREADY
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_18:
		MOV	DS,DS:[2CH]		;������
		XOR	SI,SI
L_20:
		CMP	WORD PTR DS:[SI],0	;�л�����β?
		JZ	L_22
		INC	SI
		JMP	SHORT L_20
L_22:
		LODSW
		LODSW				;SI:LCH.COMȫ·����
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_COM 	;д���ַ
		XOR	BP,BP
L_23:
		LODSB
		STOSB
		CMP	AL,'\'                  ;·���ָ���?
		JNZ	L_24
		MOV	BP,DI
		JMP	SHORT L_23
L_24:
		CMP	AL,'.'                  ;��չ���ָ���?
		JNZ	L_23

		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_FILE	;'WBZXCH.DAT',0
		OR	BP,BP			;��·��?
		JZ	L_30
		MOV	SI,DX
		MOV	DI,BP
L_26:
		LODSB				;�����ļ���
		STOSB
		OR	AL,AL
		JNZ	L_26
		MOV	DX,OFFSET D_COM
L_30:
		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNC	L_40
		MOV	DX,OFFSET NOFILE
		JMP	SHORT L_ERR
L_40:
		MOV	BX,AX			;�ļ���

		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H

		PUSH	DS
		MOV	SI,OFFSET BEGIN
		TEST	SI,0FH			;���ڽ���?
		JZ	L_50
		AND	SI,0FFF0H
		ADD	SI,10H
L_50:
		MOV	DI,SI
		MOV	CL,4
		SHR	DI,CL
		MOV	AX,CS
		ADD	AX,DI
		MOV	DS,AX
		XOR	BP,BP			;��������
		JMP	L_60

D_FILE		DB	'WBZXCH.DAT',0
MSG		DB	'פ�����������չ�ʻ�.',13,10,'$'
ALREADY 	DB	'����פ���Ĵʻ��ļ�!',7,13,10,'$'
NOFILE		DB	'�ʻ��ļ�������!',7,13,10,'$'
D_0120		DB	'�ʻ��ļ���д����!',7,13,10,'$'
NO213		DB	'����2.13ϵ�к���ϵͳ!',7,13,10,'$'
NOWBZX		DB	'δװ���������ģ�� WBZX !',7,13,10,'$'
EXIT		DB	'פ���Ĵʻ��ļ��Ѿ��˳�!',13,10,'$'
D_COM	EQU	$

SEG_A		ENDS
		END	START

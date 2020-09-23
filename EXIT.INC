;	EXIT.INC �����ڴ漰�ڴ����(װ�ڶ���ʾ�ֿ�ģ����)
;	1995.2.8
;	1996.2.10

TSRD		DW	0			;��ӡģ�鿪ʼ
TSRC		DW	0			;�ڴ�פ��ģ�����
TSR		DD	64 DUP(0)		;�ڴ�פ��ģ��PSP�κͻ����α�����

D_INTNUM	DW	13			;�����жϸ���
D_INT		DB	5			;�жϺ�
D_INT5		DD	0			;�ж�����
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
		CMP	AX,4A06H		;�й��ܺ�?
		JNZ	L_2F10
		POPF
		OR	SI,SI			;�ӹ���0?
		JNZ	L_2F01
		CALL	S_EX			;��EMS��XMS
		CALL	S_EXIT			;���ڴ�
		MOV	AX,3			;������ʾ��ʽ
		INT	10H
		IRET
L_2F01:
		CMP	SI,1			;�ӹ���1?
		JNZ	L_2F03
L_2F02:
		CALL	S_EXIT1 		;���ڴ�
		IRET
L_2F03:
		CMP	SI,2			;�ӹ���2?
		JZ	L_2F02
		CMP	SI,3			;�ӹ���3?
		JNZ	L_2F11
		XOR	AX,AX
		MOV	BX,4A06H		;������פ��״̬
		MOV	CX,CS			;����BIOS�ж�������	2.10
		MOV	DX,OFFSET D_INT
		IRET
L_2F10:
		POPF
L_2F11:
		JMP	CS:D_INT2F		;ִ��ԭINT2F
INT_2F		ENDP

S_EXIT1 	PROC	NEAR
		CMP	CS:TSRD,0		;�а�װ��ӡ������ģ��?
		JNZ	S_EXIT
		RET
S_EXIT:
		CMP	SI,0
		JNZ	L_E2
		MOV	DI,OFFSET D_INT 	;�жϱ�����
		MOV	CX,CS:D_INTNUM		;����
L_E1:
		MOV	AL,CS:[DI]		;�жϺ�
		MOV	DX,CS:[DI+1]		;    ƫ��
		MOV	DS,CS:[DI+3]		;    ��
		MOV	AH,25H			;�ָ��ж�
		INT	21H
		ADD	DI,5			;��һ�ж�
		LOOP	L_E1

		XOR	AX,AX
		MOV	ES,AX
		MOV	DI,1E0H
		MOV	CX,20H
		REP	STOSB			;���ж�78H-7FH
		JMP	SHORT L_E3
L_E2:
		CMP	SI,1
		JNZ	L_E3
		LDS	DX,CS:D_INT17
		MOV	AX,2517H		;�ָ�INT17
		INT	21H
L_E3:
		PUSH	CS
		POP	DS

		MOV	DI,OFFSET TSR		;�ڴ�פ��ģ��PSP�α�����
		CMP	SI,0
		JZ	L_E5
		MOV	AX,TSRD 		;��ӡģ��PSP�����
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
		MOV	ES,AX			;PSP��
		MOV	AH,49H			;��
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
		CMP	SI,DS:[5EH]		;�Ƿ����������?
		PUSH	CS
		POP	DS
		JNZ	L_ST1
		MOV	AX,TSRC
		MOV	TSRD,AX
L_ST1:
		MOV	AH,51H			;ȡPSP��
		INT	21H
		MOV	AX,TSRC 		;����
		CMP	AX,64			;��TSR��������?
		JZ	L_STRET
		SHL	AX,1			;*4
		SHL	AX,1
		MOV	SI,OFFSET TSR		;������
		ADD	SI,AX
		MOV	[SI],BX 		;����
		MOV	DS,BX
		MOV	AX,DS:[2CH]		;������
		MOV	CS:[SI+2],AX
		INC	CS:TSRC 		;����+1
L_STRET:
		POP	SI
		POP	BX
		POP	AX
		POP	DS
		RET
S_SETTSR	ENDP

INT_21		PROC	FAR
		PUSHF
		CMP	AH,31H			;��פ������?
		JNZ	L_2101
		CALL	S_SETTSR		;����TSR��
L_2101:
		POPF
		JMP	CS:D_INT21		;ִ��ԭINT21
INT_21		ENDP

INT_27		PROC	FAR
		CALL	S_SETTSR		;����TSR��
		JMP	CS:D_INT27		;ִ��ԭINT27
INT_27		ENDP

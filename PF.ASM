;	PF.ASM ��ӡ���ת�ļ�����
;	1994.4.7, 4.10
;	1996.12.3

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

D_INT17 	DD	0			;ԭINT17
D_DI		DW	140H			;ָ��
D_END		DW	0			;������β

INT_17		PROC	FAR
		STI
		CLD
		CMP	AH,17H			;ȡ��װ״̬?
		JNZ	L_10
		MOV	AL,AH
		PUSH	CS
		POP	ES
		IRET
L_10:
		JMP	SHORT L_20
K_DY	EQU	$-1				;������ӡ=0
		JMP	CS:D_INT17
L_20:
		OR	AH,AH			;=0:��ӡ
		JNZ	L_33
		PUSH	DI
		MOV	DI,CS:D_DI		;ȡָ��
		CMP	DI,CS:D_END		;��β?
		JZ	L_30
		MOV	CS:[DI],AL		;д��
		INC	DI			;ָ��+1
		MOV	CS:D_DI,DI		;��ָ��
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
		MOV	DX,OFFSET MSG		;ʹ��˵��
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
		CMP	AL,' '                  ;�ո�?
		JZ	L_S20
		CMP	AL,'0'                  ;����?
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
		ADD	AX,140H 		;�ӻ�������(BEGIN)
		MOV	D_END,AX		;������β
		MOV	DX,AX

		MOV	AH,17H			;ȡ��װ״̬?
		INT	17H
		CMP	AH,AL
		JNZ	L_S50
		MOV	DX,OFFSET ALREADY
		JMP	SHORT L_ERR
L_S50:
		PUSH	DX
		MOV	AX,3517H
		INT	21H
		MOV	WORD PTR D_INT17,BX	;����
		MOV	WORD PTR D_INT17+2,ES
		MOV	DX,OFFSET INT_17
		MOV	AX,2517H		;���ж�
		INT	21H
		MOV	DX,OFFSET ALREADY+1
		MOV	AH,9
		INT	21H
		POP	DX
		INT	27H			;פ��
L_S100:
		MOV	DL,AL
		MOV	AH,17H			;ȡ��װ״̬
		INT	17H
		CMP	AH,AL
		JZ	L_S110
		MOV	DX,OFFSET NOPF
		JMP	SHORT L_ERR
L_S110:
		CMP	DL,'!'                  ;��ʼ��?
		JZ	L_S130
		CMP	DL,'+'                  ;������ӡ?
		JZ	L_S140
		CMP	DL,'-'                  ;�˳�?
		JZ	L_S150
		MOV	DI,ES:D_DI
		MOV	AL,1AH			;�ļ�������־
		STOSB
		LEA	DX,[SI-1]
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
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
		MOV	AH,40H			;д�ļ�
		INT	21H
		MOV	AH,3EH			;�ر��ļ�
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

MSG		DB	'�����ӡ���ݵ��ļ�����',13,10
		DB	'��ʽ: PF [��������С]  פ���ڴ�(K��)',13,10
		DB	'      PF [�ļ���]      �����������ݴ��ļ�',13,10
		DB	'      PF !             ��ʼ��',13,10
		DB	'      PF +             ������ӡ',13,10
		DB	'      PF -             �˳�,�ָ�ԭINT17',13,10
		DB	'����: ��������С��Χ 1~63K',13,10
		DB	'      �ļ���Ӧ�Է������ַ���ͷ',13,10,'$'
ALREADY 	DB	7,'PFģ���Ѿ�פ��!',13,10,'$'
INIT		DB	'PFģ���Ѿ���ʼ��!',13,10,'$'
EXIT		DB	'PFģ���Ѿ��˳�!',7,13,10,'$'
NOPF		DB	'PFģ��δ��װ!',7,13,10,'$'
NORMAL		DB	'�ָ�������ӡ!',7,13,10,'$'

SEG_A		ENDS
		END	START

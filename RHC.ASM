;	RHC.ASM WS�ı��ļ����س�����
;	1995.11.21
;	1996.6.5, 7.21, 9.3

CSEG	SEGMENT
	ASSUME	CS:CSEG, DS:CSEG

	ORG	100H
START:	JMP	BEGIN

MSG	DB	'WordStar��ʽ�ı��ļ����س���������',13,10
	DB	'  ������: ������  ����: 1995��11��21��',13,10
	DB	'���ø�ʽ: RHC �ļ���[/A][/B][/C][/D]',13,10
	DB	'    ����: �ļ���-�����̷���·��,��֧��ͨ���?��*',13,10
	DB	'          /A - Ӳ�س������س�(�����׷ǿո���)',13,10
	DB	'          /B - ����ԭ�ļ���Ŀ���ļ�VSJBWFJB.DAT',13,10
	DB	'          /C - ɾ�����׿ո�',13,10
	DB	'          /D - ɾ�����س�',13,10
	DB	'      ע: /A������/C��/Dͬʱʹ��.',13,10,'$'
NOFILE	DB	'ָ���ļ�δ�ҵ�!',7,13,10,'$'
HAN1	DW	0			;ԭ�ļ���
HAN2	DW	0			;Ŀ���ļ���
FILE1	DW	0			;ԭ�ļ�����ַ
FILE2	DB	'VSJBWFJB.DAT',0        ;�м��ļ�
D_A	DB	0			;='A':Ӳ�س������س�
D_B	DB	0			;='B':����ԭ�ļ�
D_C	DB	0			;='C':ɾ�����׿ո�
D_D	DB	0			;='D':ɾ�����س�
D_8D	DB	0			;=8DH:������βΪ8DH
D_C0	DB	0			;���ױ�־
D_LEN	DW	0			;��������

BEGIN:
	MOV	SI,80H
	LODSB
	OR	AL,AL
	JNZ	L_10
L_1:
	MOV	DX,OFFSET MSG
L_ERR:
	MOV	AH,9
	INT	21H
	MOV	AX,4C01H
	INT	21H
L_10:
	CBW
	MOV	BX,AX
	MOV	[BX+SI],AH		;������β��0
L_12:
	LODSB
	CMP	AL,' '                  ;�������׿ո�
	JBE	L_12
	DEC	SI
	MOV	DX,SI			;�ļ�����
L_20:
	LODSB
	OR	AL,AL			;������β?
	JZ	L_30
	CMP	AL,' '
	JA	L_21
	MOV	BYTE PTR [SI-1],0
	JMP	SHORT L_20
L_21:
	CMP	AL,'/'                  ;����?
	JNZ	L_20
	MOV	BYTE PTR [SI-1],0
	LODSB
	CMP	AL,'?'
	JNZ	L_22
	JMP	L_1
L_22:
	AND	AL,5FH
	CMP	AL,'A'                  ;Ӳ�س������س�
	JNZ	L_23
	MOV	D_A,AL
	JMP	SHORT L_20
L_23:
	CMP	AL,'B'                  ;����ԭ�ļ�
	JNZ	L_24
	MOV	D_B,AL
	JMP	SHORT L_20
L_24:
	CMP	AL,'C'                  ;ɾ�����׿ո�
	JNZ	L_25
	MOV	D_C,AL
	JMP	SHORT L_20
L_25:
	CMP	AL,'D'                  ;ɾ�����س�
	JNZ	L_20
	MOV	D_D,AL
	JMP	SHORT L_20
L_30:
	MOV	FILE1,DX		;����ԭ�ļ�����ַ
	MOV	AX,3D00H		;���ļ�
	INT	21H
	JNB	L_31
	MOV	DX,OFFSET NOFILE
	JMP	SHORT L_ERR
L_31:
	MOV	HAN1,AX
	MOV	DX,OFFSET FILE2
	MOV	CX,20H
	MOV	AH,3CH			;�����м��ļ�
	INT	21H
	MOV	HAN2,AX
L_33:
	MOV	DX,OFFSET D_BUF
	MOV	SI,DX
	MOV	CX,8000H
	MOV	BX,HAN1
	MOV	AH,3FH			;��Դ�ļ�
	INT	21H
	OR	AX,AX
	JNZ	L_35
	JMP	L_80
L_35:
	MOV	D_LEN,AX	;��������
	ADD	DX,AX
	MOV	BP,DX		;������β
L_40:
	LODSB
	CMP	D_C,'C'         ;ɾ�����׿ո�?
	JNZ	L_45
	CMP	D_C0,0		;������?
	JNZ	L_45
	CMP	AL,' '          ;���׿ո�?
	JNZ	L_45
	MOV	DI,SI
L_41:
	CMP	[DI],AL
	JNZ	L_42
	INC	DI
	CMP	DI,BP		;����β?
	JB	L_41
L_42:
	MOV	AX,DI
	SUB	AX,SI
	INC	AX
	JMP	L_53
L_45:
	CMP	D_8D,0AH	;��һ�ζ�����βΪ0AH?
	JNZ	L_48
	CMP	AL,0AH
	JZ	L_52
L_48:
	CMP	D_8D,8DH	;��һ�ζ�����βΪ8DH?
	JNZ	L_50
	MOV	D_8D,0
	CMP	AL,0AH
	JZ	L_49
	CMP	AL,8AH
	JNZ	L_50
L_49:
	JMP	L_52
L_50:
	CMP	AL,8DH		;���س�?
	JNZ	L_55
	CMP	D_D,'D'         ;ɾ��?
	JNZ	L_56
	CMP	SI,BP		;����β?
	JNZ	L_51
	MOV	D_8D,AL
	JMP	SHORT L_52
L_51:
	MOV	AX,2
	CMP	BYTE PTR [SI],0AH
	JZ	L_53
	CMP	BYTE PTR [SI],8AH
	JZ	L_53
L_52:
	MOV	AX,1
L_53:
	DEC	SI
	MOV	DI,SI		;ָ�����س�
	PUSH	SI
	ADD	SI,AX		;ָ�����س���һ�ֽ�
	MOV	CX,BP		;��β
	SUB	CX,SI		;���ͳ���
	REP	MOVSB		;ɾ�����س�
	SUB	BP,AX		;��β��ַ
	POP	SI
	JMP	SHORT L_40
L_55:
	CMP	AL,8AH		;WS��ҳ��?
	JNZ	L_60
L_56:
	AND	AL,7FH		;��Ӳ�س�
	MOV	[SI-1],AL	;д��
L_60:
	CMP	AL,0AH		;����?
	JNZ	L_70
	CMP	SI,BP		;����β?
	JNZ	L_61
	MOV	D_8D,AL
	JMP	L_74
L_61:
	CMP	AL,[SI] 	;��һ�ַ�Ϊ0AH?
	JNZ	L_74
	INC	SI
	JMP	SHORT L_52
L_70:
	CMP	AL,0DH		;�س�?
	JNZ	L_75
	CMP	D_A,'A'         ;Ӳ�س������س�?
	JNZ	L_74
	MOV	AX,BP
	SUB	AX,SI
	CMP	AX,2		;����β2�ֽ�?
	JA	L_71
	MOV	DX,BP
	MOV	CX,2
	MOV	AH,3FH		;�ٶ�2�ֽ�
	INT	21H
	MOV	CX,-1
	MOV	DX,-2
	MOV	AX,4201H	;�ָ�ԭλ��
	INT	21H
L_71:
	CMP	BYTE PTR [SI+1],0DH	;������Ϊ�س�?
	JBE	L_74			;			6.5
	CMP	BYTE PTR [SI+1],' '     ;��������Ϊ�ո�?
	JZ	L_74
	CMP	BYTE PTR [SI+1],0A9H	;��������Ϊ�����Ʊ���?	7.21
	JZ	L_74
	MOV	BYTE PTR [SI-1],8DH	;�����س�
L_74:
	MOV	D_C0,0		;�����ױ�־
	JMP	SHORT L_78
L_75:
	INC	D_C0
L_78:
	CMP	SI,BP		;����β?
	JAE	L_80
	JMP	L_40
L_80:
	MOV	DX,OFFSET D_BUF
	MOV	CX,BP
	SUB	CX,DX
	MOV	BX,HAN2
	MOV	AH,40H		;д
	INT	21H

	MOV	AX,D_LEN
	CMP	AX,8000H
	JB	L_90
	JMP	L_33
L_90:
	MOV	BX,HAN1
	MOV	AH,3EH
	INT	21H
	MOV	BX,HAN2
	MOV	AH,3EH
	INT	21H

	CMP	D_B,'B'                 ;����ԭ�ļ�
	JZ	L_99
	MOV	DX,FILE1
	MOV	AH,41H			;ɾ��Դ�ļ�
	INT	21H
	MOV	DX,OFFSET FILE2 	;ԭ�ļ���
	MOV	DI,FILE1		;���ļ���
	MOV	AH,56H			;�ļ�����
	INT	21H
L_99:
	MOV	AX,4C00H
	INT	21H

D_BUF	EQU	$

CSEG	ENDS
	END	START

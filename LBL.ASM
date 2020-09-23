;	LBL.ASM �������޸ġ��������̾������
;	1993.12.6
;	1994.1.28
;	1995.12.25

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	SHORT BEGIN

W_DRV		DB	0			;�����̺�
S_DRV		DB	0			;Դ�̺�
T_DRV		DB	0			;Ŀ���̺�
C_LABEL 	DW	0			;�������꿪ʼ��ַ
D_DIR		DW	0			;��Ŀ¼����
D_E5		DW	0			;��һ����Ŀ¼��
D_INPUT 	DB	12,0
D_LABEL 	DB	11 DUP(' ')             ;����
		DB	13

BEGIN:
		MOV	D_INT25[8],CS
		MOV	AL,DS:[5CH]		;ȡԴ�̺�
		MOV	S_DRV,AL		;Դ�̺�(0δָ��,1=A,2=B,3=C...)
		MOV	AL,DS:[6CH]
		MOV	T_DRV,AL		;Ŀ���̺�(ͬ��)

		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_70
L_10:
		LODSB
		CMP	AL,' '
		JZ	L_10
		DEC	SI
		CMP	WORD PTR DS:[SI],'?/'
		JNZ	L_20
		MOV	DX,OFFSET MSG		;��ʾ����
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_20:
		CMP	S_DRV,0 		;δָ��Դ�̷�?
		JZ	L_40
		CMP	T_DRV,0 		;δָ��Ŀ���̷�?
		JNZ	L_70
L_30:
		LODSB
		CMP	AL,':'
		JNZ	L_30
L_40:
		CMP	BYTE PTR DS:[SI],0DH	;δָ������?
		JZ	L_70
		MOV	C_LABEL,SI		;ָ�������ַ
		MOV	D_INPUT+1,11
		MOV	DI,OFFSET D_LABEL
		XOR	BX,BX
L_50:
		LODSB
		CMP	AL,0DH
		JZ	L_60
		STOSB
		INC	BX
		JMP	SHORT L_50
L_60:
		MOV	CX,11
		SUB	CX,BX
		JZ	L_90
		MOV	AL,' '
		REP	STOSB
		JMP	SHORT L_90
L_70:
		CALL	S_READS 		;��Դ�̾���
		JB	L_90
		MOV	D_INPUT+1,11
		CMP	T_DRV,0
		JZ	L_90
L_80:
		CALL	S_COPY			;��������
		MOV	DX,OFFSET OK
		JMP	SHORT L_ERR
L_90:
		CMP	T_DRV,0
		JZ	L_92
		MOV	DX,OFFSET NOCOPY
		JMP	SHORT L_ERR
L_92:
		MOV	AL,S_DRV
		MOV	T_DRV,AL
		CMP	C_LABEL,0		;�Ƿ�ָ������?
		JNZ	L_80
		CALL	S_INPUT 		;�������
		JNB	L_80
		INT	20H

;�ӳ���:������ ���ҵ�SIΪ������,����D_E5Ϊ��д���Ŀ¼��
S_READS 	PROC	NEAR
		MOV	AL,S_DRV		;Դ�̺�
		CALL	S_READ
		MOV	DI,OFFSET D_LABEL
		MOV	CX,11
		REP	MOVSB
		CALL	S_DISP			;��ʾ����
		RET
S_READT:
		MOV	AL,T_DRV		;Ŀ���̺�
S_READ:
		OR	AL,AL
		JZ	L_SR0
		DEC	AX
		JMP	SHORT L_SR1
L_SR0:
		MOV	AH,19H			;ȡ��ǰ��(0=A,1=B,2=C...)
		INT	21H
L_SR1:
		MOV	W_DRV,AL
		MOV	D_E5,0

		MOV	CX,1
		XOR	DX,DX
		CALL	S_READSEC		;��Դ��BOOT
		JNB	L_SR2
		POP	AX
		MOV	DX,OFFSET READERR
		JMP	L_ERR
L_SR2:
		MOV	AX,DS:[BX+11H]		;��Ŀ¼����
		MOV	D_DIR,AX
		MOV	CL,20H			;ÿ����Ŀ¼����
		DIV	CL
		OR	AH,AH			;12.25
		JZ	L_SR3
		INC	AL
L_SR3:
		CBW
		MOV	CX,AX			;Ŀ¼��������
		MOV	D_INT25+4,AX
		MOV	AL,DS:[BX+10H]		;FAT����
		MUL	BYTE PTR DS:[BX+16H]	;*FAT������
		INC	AX
		MOV	D_INT25,AX		;Ŀ¼����������
		MOV	DX,AX
		CALL	S_READSEC		;��Դ��Ŀ¼��

		MOV	CX,D_DIR		;��Ŀ¼����
		MOV	SI,BX
L_SR4:
		CMP	BYTE PTR DS:[SI],0
		JZ	L_SR7
		CMP	BYTE PTR DS:[SI],0E5H
		JZ	L_SR6
		TEST	BYTE PTR DS:[SI+11],8	;�о���?
		JNZ	L_SR9
		JMP	SHORT L_SR6
L_SR5:
		CMP	D_E5,0
		JNZ	L_SR5
		MOV	D_E5,SI
L_SR6:
		ADD	SI,20H
		LOOP	L_SR4
		JMP	SHORT L_SR8
L_SR7:
		MOV	D_E5,SI
L_SR8:
		MOV	DX,OFFSET NOLABEL
		MOV	AH,9
		INT	21H
		STC
		RET
L_SR9:
		CLC
		RET
S_READS 	ENDP

;�ӳ���:������
S_READSEC	PROC	NEAR
		MOV	AL,W_DRV		;Դ�̺�
		MOV	BX,OFFSET D_BUF
		INT	25H			;����������
		POP	AX
		JNB	L_RS1
		MOV	AL,W_DRV		;Դ�̺�
		MOV	BX,OFFSET D_INT25
		MOV	D_INT25+4,CX
		MOV	D_INT25,DX
		MOV	CX,0FFFFH
		INT	25H			;�����̷���������
		POP	AX
		MOV	BX,OFFSET D_BUF
L_RS1:
		RET
S_READSEC	ENDP

;�ӳ���:������� ->D_LABEL,����11
S_INPUT 	PROC	NEAR
		MOV	DX,OFFSET INPUT
		MOV	AH,9
		INT	21H
		MOV	DX,OFFSET D_INPUT
		MOV	SI,DX
		MOV	AH,0AH
		INT	21H
		MOV	DX,OFFSET M0D0A
		MOV	AH,9
		INT	21H
		INC	SI
		CMP	BYTE PTR DS:[SI],0
		JZ	L_IP1
		MOV	AL,DS:[SI]
		CBW
		INC	SI
		MOV	DI,OFFSET D_LABEL
		MOV	CX,AX
		REP	MOVSB
		MOV	CX,11
		SUB	CX,AX
		JBE	L_IP0
		MOV	AL,' '
		REP	STOSB
L_IP0:
		CLC
		RET
L_IP1:
		STC
		RET
S_INPUT 	ENDP

;�ӳ���:���� ������������д��Ŀ������
S_COPY		PROC	NEAR
		CALL	S_READT 		;��Ŀ���̾���
		JNB	L_CP1
		MOV	SI,D_E5 		;��д��Ŀ¼��
		OR	SI,SI
		JNZ	L_CP1
		POP	AX
		MOV	DX,OFFSET NOROOM
		JMP	L_ERR
L_CP1:
		MOV	DI,SI
		MOV	SI,OFFSET D_LABEL
		MOV	CX,11
		REP	MOVSB			;����
		MOV	AL,8			;д���������
		STOSB

		MOV	AL,W_DRV		;Ŀ���̺�
		MOV	BX,OFFSET D_BUF
		MOV	CX,D_INT25+4
		MOV	DX,D_INT25
		INT	26H			;д��
		POP	AX
		JNB	L_CP2
		MOV	AL,W_DRV		;Ŀ���̺�
		MOV	BX,OFFSET D_INT25
		MOV	CX,-1
		INT	26H			;д���̷�������
		POP	AX
		JNB	L_CP2
		POP	AX
		MOV	DX,OFFSET COPYERR
		JMP	L_ERR
L_CP2:
		RET
S_COPY		ENDP

S_DISP		PROC	NEAR
		MOV	AL,W_DRV
		ADD	DISP[22],AL
		MOV	DX,OFFSET DISP
		MOV	AH,9
		INT	21H
		MOV	SI,OFFSET D_LABEL
		MOV	CX,11
L_DP1:
		LODSB
		MOV	DL,AL
		MOV	AH,2
		INT	21H
		LOOP	L_DP1
		MOV	DL,0DH
		INT	21H
		MOV	DL,0AH
		INT	21H
		RET
S_DISP		ENDP

D_INT25 	DW	0,0		;��������	;����������
		DW	1		;������
		DW	OFFSET D_BUF	;������ƫ��
		DW	0
READERR 	DB	' Source disk read error!',7,13,10,'$'
NOLABEL 	DB	' Source disk no label.',13,10,'$'
NOROOM		DB	13,10,' Target disk direction area is full!',7,13,10,'$'
NOCOPY		DB	' No label to copy!',7,13,10,'$'
COPYERR 	DB	13,10,' Target disk write error!',7,13,10,'$'
OK		DB	13,10,' New label is created.',13,10,'$'
DISP		DB	13,10,' The label in drive A: is :$'
INPUT		DB	' Please input new label...:$'
MSG		DB	'Creates, changes or copy volume label.',13,10,13,10
		DB	'LBL [drive:][label]    create or change',13,10
		DB	'LBL drive1 drive2      copy',13,10
M0D0A		DB	13,10,'$'

D_BUF	EQU	$

CSEG		ENDS
		END	START

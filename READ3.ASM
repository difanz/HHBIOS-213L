;	READ3.ASM (2.13L)
;	1995.1.24, 12.17
;	1999.11.2, 11.16

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

	;������:READV [J][F]
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
		OR	AH,AH		;=0����,��0����
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
		ADD	AX,DX			;�ú������
		MOV	DL,32
		MUL	DX			;���ֽ�λ��
		ADD	AX,SI			;��չ�ڴ�ƫ��
		ADC	DL,CL			;	 ��
		MOV	D_SOFF,AX
		MOV	D_SSEG,DL
		MOV	CX,10H
		MOV	SI,OFFSET D_GDT 	;GDT����ַ
		MOV	AH,87H			;��ROM-BIOS
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

D_XPH		DB	0			;���̺�
D_HZK1		DB	0			;��һ�ֿ�
D_HZK2		DB	0			;�ڶ��ֿ�
J_AX		DW	0			;���̼����ֿ��ļ���ַ
J_DL		DB	10H
F_AX		DW	0			;���̷����ֿ��ļ���ַ
F_DL		DB	10H

D_GDT		DB	16 DUP (0)
		DW	20H			;�����ֽ���
D_SOFF		DW	0			;Դ��ַ
D_SSEG		DB	10H
		DB	93H, 0, 0
		DW	20H			;�����ֽ���
D_TOFF		DW	0			;Ŀ���ַ
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
		CMP	AL,'N'                  ;פ�������ڴ�?
		JNZ	L_S10
		MOV	D_RAM,AL
L_S10:
		MOV	AX,4A06H
		MOV	SI,3			;ȡפ��״̬
		INT	2FH
		CMP	BX,4A06H		;���Ƿ���פ��?
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
		MOV	D_TOFF,AX		;����Ŀ���ַCS:80H
		MOV	D_TSEG,DH

		MOV	D_XPH,2 		;ָ��C��
L_S20:
		MOV	AL,D_XPH
		MOV	BX,OFFSET D_BUF
		MOV	CX,1
		XOR	DX,DX
		INT	25H			;����������
		POP	AX
		JNB	L_S22
		MOV	AL,D_XPH
		MOV	BX,OFFSET D_INT25
		MOV	CX,0FFFFH
		INT	25H			;�����̷���������
		POP	AX
		JNB	L_S22
		MOV	DX,OFFSET D_VDISKERR
		JMP	L_ERR
L_S22:
		CMP	BYTE PTR DS:[BX+3],'V'  ;��VDISK?
		JZ	L_S30
		CMP	BYTE PTR DS:[BX+3],'R'  ;��RAMDRIVE?
		JZ	L_S24
		INC	D_XPH			;��һ�̺�
		JMP	SHORT L_S20
L_S24:
		MOV	CX,10H
		MOV	SI,OFFSET D_GDT 	;GDT����ַ
		MOV	AH,87H			;��ROM-BIOS
		INT	15H
		MOV	SI,OFFSET D_BUF 	;��������
		MOV	DI,0A0H 		;����
		MOV	CX,10H			;10H����
		REP	CMPSW			;�Ƚ�
		JZ	L_S26
		ADD	D_SOFF,400H		;��һ����
		JNB	L_S24
		INC	D_SSEG			;��һ��
		JMP	SHORT L_S24
L_S26:
		MOV	AX,D_SOFF		;�������׾��Ե�ַ
		MOV	D_BP,AX
		MOV	AL,D_SSEG
		CBW
		MOV	D_DI,AX
L_S30:
		MOV	AL,D_XPH		;���̺�
		INC	AL
		MOV	HZK16,AL		;�����̺�(������)
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
		MOV	WORD PTR D_HZK1,AX	;����
		CMP	AL,'J'
		JZ	L_S42
		CMP	AL,'F'
		JZ	L_S42
		MOV	AL,'J'
		MOV	D_HZK1,AL
L_S42:
		CALL	S_READ			;���������ֿ�
		JNB	L_S50
		MOV	DX,OFFSET D_NOFILE
		JMP	L_ERR
L_S50:
		MOV	J_AX,BP
		MOV	F_AX,BP
		MOV	AX,DI
		MOV	J_DL,AL
		MOV	F_DL,AL

		MOV	AL,D_HZK2		;�ڶ��ֿ�
		CMP	AL,' '
		JZ	L_S70
		CALL	S_READ			;���������ֿ�
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
		MOV	BYTE PTR DS:[100H],'3'  ;READV��־

		MOV	AX,CS
		CMP	AX,0A000H		;��LH?
		JA	L_S75
		CMP	D_RAM,'N'               ;פ�������ڴ�
		JZ	L_S75
		CALL	S_GETUMB		;����UMB��
		JZ	L_S80
L_S75:
	;	MOV	ES,DS:[2CH]
	;	MOV	AH,49H			;�廷����
	;	INT	21H
		CALL	S_SETINT
		MOV	DX,OFFSET BEGIN 	;פ�������ڴ�
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
		REP	MOVSB			;��UMB�ļ����ƿ�д�뱾ģ����

		MOV	ES,D_UMB		;��
		XOR	SI,SI
		MOV	DI,SI
		MOV	CX,OFFSET BEGIN
		REP	MOVSB			;������ģ�鵽UMB
		PUSH	ES
		POP	DS

		CALL	S_SETINT

		PUSH	CS
		POP	DS
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;�廷����
		INT	21H
		PUSH	CS
		POP	ES
		MOV	AH,49H			;�屾ģ��
		INT	21H

		MOV	AH,50H			;������PSP
		MOV	BX,D_UMB
		INT	21H
		MOV	DX,D_LEN		;��ģ�鳤��(��)
		MOV	AX,3100H		;פ��
		INT	21H

D_XMS		DD	0			;XMS������ַ
D_NCFP		DW	0			;ԭ�ڴ�������
D_UMB0		DW	0			;ԭUMB����״̬
D_UMB		DW	0			;����UMB��
D_LEN		DW	0			;��ģ�鳤��(��)
D_RAM		DB	0			;='N':פ�������ڴ�

;�ӳ���:ȡUMB��
S_GETUMB	PROC	NEAR
		CALL	S_GETXMS		;ȡXMS������ַ
		JNZ	L_GU2
		MOV	DX,OFFSET BEGIN
		SHR	DX,1
		SHR	DX,1
		SHR	DX,1
		SHR	DX,1
		INC	DX
		MOV	D_LEN,DX		;��ģ��פ������(��)

		MOV	AH,10H			;����UMB
		CALL	D_XMS			;XMS
		CMP	AX,1			;=1:�ɹ�,BX=��
		JZ	L_GU1
		CALL	S_UMB			;����UMB��
		CMP	AL,AL			;ZF=1
		RET
L_GU1:
		MOV	D_UMB,BX		;ȡ��UMB��
L_GU2:
		RET
S_GETUMB	ENDP

S_UMB		PROC	NEAR
		MOV	AX,3000H		;ȡDOS�汾��
		INT	21H
		CMP	AL,5			;��>5.0
		JB	L_UMB3
		MOV	AX,5800H		;ȡ�ڴ�������AX
		INT	21H
		MOV	D_NCFP,AX
		MOV	AX,5802H		;ȡUMB����״̬AL
		INT	21H
		CBW
		MOV	D_UMB0,AX

		MOV	AX,5803H		;��UMB����
		MOV	BX,1			;=1����
		INT	21H
		JC	L_UMB3
		MOV	AX,5801H		;���ڴ�������
		MOV	BX,41H			;����ʺϿ�
		INT	21H
		JC	L_UMB2
		MOV	AH,48H			;�����ڴ�
		MOV	BX,D_LEN
		INT	21H
		JC	L_UMB1
		MOV	D_UMB,AX		;������
L_UMB1:
		MOV	AX,5801H		;�ָ��ڴ�������
		MOV	BX,D_NCFP
		INT	21H
L_UMB2:
		MOV	BX,D_UMB0
		MOV	AX,5803H		;�ָ�UMB����״̬
		INT	21H
L_UMB3:
		RET
S_UMB		ENDP

;�ӳ���:ȡXMS������ַ ->D_XMS
S_GETXMS	PROC	NEAR
		MOV	AX,4300H		;ȡXMS��װ״̬
		INT	2FH
		CMP	AL,80H			;=80H:�Ѱ�װ
		JNZ	L_GX1
		MOV	AX,4310H		;ȡXMS������ַ
		INT	2FH
		MOV	WORD PTR D_XMS,BX	;����
		MOV	WORD PTR D_XMS+2,ES
		CMP	AL,AL			;����ZF=1
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
		MOV	D_TOFF,AX		;����Ŀ���ַCS:80H
		MOV	D_TSEG,DH

		MOV	DX,OFFSET INT_7F
		MOV	AX,257FH
		INT	21H
	INCLUDE EXIT1.INC			;1.24
		RET
S_SETINT	ENDP

;�ӳ���:�����ֿ� AL=�ֿ���(J,F)
S_READ		PROC	NEAR
		MOV	AH,AL
		CMP	AL,'J'
		JNZ	L_R0
		MOV	AX,2000H
L_R0:
		MOV	SFILE+5,AL		;Դ�ļ���
		MOV	VFILE+7,AL		;�����ļ���
		MOV	HZK16+6,AH		;FCB�ļ���

		MOV	BP,D_BP
		MOV	DI,D_DI
		MOV	DX,OFFSET VFILE 	;ָ��Ŀ���ļ�
		MOV	AX,4300H		;ȡ�ļ�����
		INT	21H
		JNB	L_R4			;���ļ��Ѵ���,ת
		MOV	DX,OFFSET SFILE 	;ָ��ǰĿ¼��HZK16
		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_R1
		CALL	S_PATH			;���ұ�����·��
		MOV	DX,OFFSET F_S
		MOV	AX,3D00H		;��
		INT	21H
		JB	L_ERROR
L_R1:
		MOV	H_S,AX			;Դ�ļ���
		MOV	DX,OFFSET VFILE 	;ָ��������HZK16
		MOV	CX,21H			;ֻ��
		MOV	AH,3CH			;�������̽����ļ�
		INT	21H
		JB	L_ERROR
		MOV	H_V,AX			;Ŀ���ļ���
L_R2:
		MOV	BX,H_S			;Դ�ļ���
		MOV	DX,OFFSET D_BUF+200H	;��д��������ַ
		MOV	CX,1000H		;һ�ζ�4K
		MOV	AH,3FH			;���ļ�
		INT	21H
		JB	L_R3
		OR	AX,AX
		JZ	L_R3
		MOV	CX,AX
		MOV	BX,H_V			;Ŀ���ļ���
		MOV	AH,40H			;д�ļ�
		INT	21H
		JMP	SHORT L_R2
L_ERROR:
		STC
		RET
L_R3:
		MOV	BX,H_S
		MOV	AH,3EH			;�ر�Դ�ļ�
		INT	21H
		MOV	BX,H_V
		MOV	AH,3EH			;�ر�Ŀ���ļ�
		INT	21H
L_R4:
		MOV	BX,OFFSET D_BUF 	;������������
		MOV	AL,[BX+0DH]		;ÿ��������
		CBW
		MOV	DS:[70H],AX
		MOV	AL,[BX+16H]		;ÿFAT������
		MUL	BYTE PTR DS:[BX+10H]	;��FAT��
		ADD	AX,[BX+0EH]		;�ӱ���������
		MUL	WORD PTR DS:[BX+0BH]	;��ÿ�����ֽ���
		MOV	CX,AX
		MOV	AX,20H
		MUL	WORD PTR DS:[BX+11H]	;��Ŀ¼������20H
		ADD	AX,CX			;��
		ADD	BP,AX			;�������ļ�����ַ
		ADC	DI,0

		MOV	DX,OFFSET HZK16
		MOV	AH,11H			;����Ŀ¼��
		INT	21H			;DTA��ַ:DS:80H
		OR	AL,AL
		JNZ	L_ERROR
		MOV	AX,DS:[9BH]		;�״غ�
		SUB	AX,2
		MUL	WORD PTR DS:[70H]	;��ÿ��������
		MUL	WORD PTR DS:[BX+0BH]	;��ÿ�����ֽ���
		ADD	BP,AX			;�����ֿ��ļ���ַ
		ADC	DI,DX
		CLC
		RET
S_PATH: ;���ұ�����·��
		MOV	DS,DS:[2CH]		;������
		XOR	SI,SI
L_P1:
		CMP	WORD PTR DS:[SI],0	;���һ�����β?
		JZ	L_P2
		INC	SI
		JMP	SHORT L_P1
L_P2:
		ADD	SI,4
		MOV	DI,OFFSET F_S		;��·��Դ�ļ�����
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
D_INT25 	DD	0		;��������	;����������
		DW	1		;������
		DW	OFFSET D_BUF	;������ƫ��
D_CS		DW	0		;      ��

D_BUF		EQU	$

SEG_A		ENDS
		END	START

;	CZ.ASM (2.13L)
;	1995.7.18
;	1996.1.2, 3.21, 11.14

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

D_TITLE 	DB	' ��  ��  ѡ  ��  ��  �� ',0
D_MENU		DB	' ������� (ָ���ʵ��ļ�����2.13K�ⲿ�����ļ�) ',0
		DB	' ���鷽ʽ (ָ������ʵ佨����,��ָ�����뷽��) ',0
		DB	' ������� (ָ���ʵ��ļ�������2.13K������ļ�) ',0
		DB	' ��˫ƴת�� (��2.13K��˫ƴ����ת��Ϊ�ʵ��ļ�) ',0
		DB	' ������ת�� (��2.13H�������ļ�ת��Ϊ�ʵ��ļ�) ',0
		DB	' �ϴ���ת�� (��2.13H�Ĵ����ļ�ת��Ϊ�ʵ��ļ�) ',0
		DB	' �ϴ���ת�� (��2.13H�Ĵ����ļ�ת��Ϊ����ʵ�) ',0
		DB	' ������ת�� (��2.13K�������ļ�ת��Ϊ�ʵ��ļ�) ',0
		DB	' �´���ת�� (��2.13K�Ĵ����ļ�ת��Ϊ�ʵ��ļ�) ',0
		DB	' �´���ת�� (��2.13K�Ĵ����ļ�ת��Ϊ����ʵ�) ',0
		DB	' ˫ƴ����ת��(��SPCZ.DATת��Ϊ�ʵ��ļ�CK.DAT) ',0
		DB	' �ʵ��ʽת��(ԭ�ʵ��ļ�ת��Ϊר�ø�ʽCK.DAT) ',0
		DB	' ��˫ƴ����(��CK.DAT����˫ƴ�����ļ�SPCZ.DAT) ',0
D_MSG		DB	'��<ESC>���˳�, ��������¼��ƶ�, ���س�-ѡ��...',0
D_T1		DB	'��������������������������������������������������',0
D_T2		DB	'��������������������������������������������������',0
D_SX		DB	'��',0
NO213		DB	'��2.13ϵ�к���ϵͳ!',7,13,10,'$'
NOCKDAT 	DB	'�ļ�CK.DAT�����ڻ������!',13,10,'$'
NOALLHZ 	DB	'���ִ������ַ�!',13,10,'$'
HZNUM		DB	'ȡǰ����������ƴ��(�س�Ĭ��8��.�������ֲ��ûس�): ',0
D_HZNUM 	DB	0
D_ZJ		DB	'�ܼƴ��� 00000 ��,�ܳ��� 00000 �ֽ�',13,10
		DB	'���س����������˵�...$'
D_INCZ		DB	'���������ļ���: '
D_CZ		DB	'CZ$'
D_INLX		DB	'����������ļ���: '
D_LX		DB	'LX$'
D_COM		DB	'.COM',0
D_HAN		DW	0
D_INCD		DB	'�����ʵ��ļ���: $'
D_SPCZ		DB	'SPCZ.DAT',0
D_CK		DB	'CK.DAT',0
D_INPUT 	DB	40 DUP(0)
D_1A		DB	1AH

D_X		DB	0			;���˵���ǰ��
D_X1		DB	0
D_CX		DW	0
D_SI		DW	0			;����SI
D_DI		DW	0			;����DI
D_END		DW	0			;������β
D_0D		DB	0
D_K		DW	0			;�ܳ���
D_FILE1 	DW	0			;��һ�м��ļ�ָ��
D_FILE2 	DW	0			;�ڶ��м��ļ�ָ��
D_FILE3 	DW	0			;�ڶ��м��ļ�ָ��
D_FILE4 	DW	0			;�ڶ��м��ļ�ָ��
;----------------------------------------------------------------------------
BEGIN:
		CALL	S_CLS
		MOV	SI,OFFSET D_TITLE	;����
		MOV	DX,1CH
		MOV	BX,4FH
		CALL	S_XSZF

		MOV	SI,OFFSET D_T1		;��ʾ�Ϻ���
		MOV	DX,10EH
		MOV	BX,7
		CALL	S_XSZF
		MOV	BP,13
		MOV	DX,20EH
L_130:
		MOV	SI,OFFSET D_SX		;����
		PUSH	DX
		CALL	S_XSZF			;��ʾ�������
		POP	DX
		INC	DH
		DEC	BP
		JNZ	L_130

		MOV	BP,13
		MOV	DX,23EH
L_132:
		MOV	SI,OFFSET D_SX
		PUSH	DX
		CALL	S_XSZF			;��ʾ�ұ�����
		POP	DX
		INC	DH
		DEC	BP
		JNZ	L_132

		MOV	SI,OFFSET D_T2		;��ʾ����
		MOV	DL,0EH
		CALL	S_XSZF
		MOV	D_X1,0
L_133:
		CALL	S_XSCD1
		INC	D_X1
		CMP	D_X1,13
		JB	L_133

		MOV	SI,OFFSET D_MSG
		MOV	DX,1800H
		MOV	BX,7
		CALL	S_XSZF
L_150:
		MOV	CX,2000H
		MOV	AH,1			;�ع��
		INT	10H
L_160:
		CALL	S_XSCD
L_170:
		XOR	AH,AH
		INT	16H
		CMP	AH,72			;��
		JNZ	L_200
		CMP	D_X,0
		JNZ	L_191
		MOV	D_X,12
		JMP	SHORT L_199
L_191:
		DEC	D_X
L_199:
		CALL	S_XSCD1
		JMP	SHORT L_160
L_200:
		CMP	AH,80			;��
		JNZ	L_220
		CMP	D_X,12
		JB	L_201
		MOV	D_X,0
		JMP	SHORT L_199
L_201:
		INC	D_X
		JMP	SHORT L_199
L_220:
		CMP	AL,1BH			;ESC?
		JNZ	L_222
		CALL	S_CLS
		CALL	S_KGB
		INT	20H
L_222:
		CMP	AL,0DH			;�س�?
		JNZ	L_170
		CALL	S_KGB
		MOV	SI,OFFSET D_MSG 	;����ʾ
		MOV	DX,1800H
		MOV	BX,0
		CALL	S_XSZF
		MOV	AL,47
		MUL	D_X
		ADD	AX,OFFSET D_MENU
		MOV	SI,AX
		MOV	DX,1000H
		MOV	BX,1EH
		CALL	S_XSZF
		CALL	S_0D0A

		MOV	AL,D_X
;----------------------------------------------------------------------------
		CMP	AL,0
		JZ	L_1000
		JMP	L_2000
L_1000: 	; ������� (ָ���ʵ��ļ�����2.13K�ⲿ�����ļ�)
		XOR	BP,BP
		MOV	AH,2FH			;ȡCKBD��
		INT	16H
		OR	BP,BP			;�а�װ?
		JNZ	L_1001
		MOV	SI,OFFSET NO213
		MOV	DX,1800H
		MOV	BX,1EH
		CALL	S_XSZF
		JMP	L_150
L_1001:
		MOV	D_FILE1,OFFSET D_BUF1	;CCZZ1
		MOV	D_FILE2,0
		MOV	D_CX,0			;�������=0
		MOV	D_K,0			;�ܳ���=0

		MOV	SI,OFFSET HZNUM 	;'ȡǰ����������ƴ��...'
		MOV	DX,1100H
		MOV	BX,7
		CALL	S_XSZF
L_1040:
		XOR	AH,AH			;����
		INT	16H
		CMP	AL,0DH			;�س�(Ĭ��8��)
		JNZ	L_1045
		MOV	AL,8
		JMP	SHORT L_1048
L_1045:
		CMP	AL,'1'
		JB	L_1040
		CMP	AL,'9'
		JA	L_1040
		MOV	BX,1EH
		MOV	CX,1
		MOV	AH,9			;��ʾ
		INT	10H
		AND	AL,0FH
L_1048:
		MOV	D_HZNUM,AL
		CALL	S_0D0A
L_1050:
		MOV	DX,OFFSET D_INCD	;'�����ʵ��ļ���:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;����ʵ��ļ���
		JNB	L_1055
		JMP	L_1130
L_1055:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_1060
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_1050
L_1060:
		MOV	D_HAN,AX

		MOV	D_DI,OFFSET D_BUF
		CALL	S_READ			;���ʵ��ļ�32K
		JNB	L_1080
		MOV	BX,D_HAN
		MOV	AH,3EH
		JMP	SHORT L_1050
L_1080:
		CALL	S_GETSTR		;ȡ���ַ���SI
		JB	L_1050
L_1100:
		MOV	D_SI,SI 		;����
		MOV	DI,OFFSET D_STR 	;�����������
		XOR	BX,BX			;	 ����
		CMP	BYTE PTR [SI],0B0H	;�д��׺���?
		JB	L_1080
L_1110:
		CMP	BYTE PTR [SI],0B0H	;�к���?
		JB	L_1120
		LODSB
		MOV	AH,AL
		LODSB
		CALL	S_PYM			;ȡ����˫ƴ��
		STOSB				;��
		INC	BX			;�������+1
		CMP	BL,D_HZNUM		;���趨��?
		JB	L_1110
L_1120:
		ADD	D_K,BX
		ADD	D_K,CX
		MOV	BH,BL			;���볤
		ADD	BH,CL			;+���鳤
		MOV	SI,D_FILE1
		MOV	[SI],BH 		;д��CCZZ1
		INC	SI
		MOV	D_FILE1,SI
		PUSH	DI
		PUSH	CX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	ES,AX
		MOV	CL,BL			;���볤
		MOV	SI,OFFSET D_STR
		MOV	DI,D_FILE2
		REP	MOVSB			;д�����
		POP	CX
		MOV	SI,D_SI
		REP	MOVSB			;д���������
		MOV	D_FILE2,DI
		POP	DI
		PUSH	CS
		POP	ES
		INC	D_CX			;�������+1
		JMP	L_1080
L_1130:
		MOV	AX,D_CX 		;�������
		OR	AX,AX
		JNZ	L_1133
		JMP	BEGIN
L_1133:
		MOV	WORD PTR D_DATA1+30,AX
		ADD	AX,D_K
		MOV	WORD PTR D_DATA1+28,AX

		MOV	DX,OFFSET D_INCZ	;'���������ļ���: CZ'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;��������ļ���
		MOV	AX,WORD PTR D_CZ
		MOV	WORD PTR D_INPUT,AX
		MOV	SI,OFFSET D_INPUT
		MOV	DX,SI
L_1140:
		LODSB
		OR	AL,AL
		JNZ	L_1140
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;�γ��ļ���

		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		MOV	BX,AX
		MOV	DX,OFFSET D_DATA1	;COM������
		MOV	CX,32
		MOV	AH,40H			;д���ļ�
		INT	21H
		MOV	DX,OFFSET D_BUF1
		MOV	CX,D_FILE1
		SUB	CX,DX
		MOV	AH,40H			;д���ļ�
		INT	21H
		MOV	CX,D_FILE2
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		XOR	DX,DX
		MOV	AH,40H			;д���ļ�
		INT	21H
		PUSH	CS
		POP	DS
		MOV	AH,3EH
		INT	21H

		CALL	S_ZJ
L_1150:
		XOR	AH,AH
		INT	16H
		CMP	AL,0DH
		JNZ	L_1150
		JMP	BEGIN

D_DATA1 	DB	 8CH,0CDH,0BAH, 20H,   1, 89H,0D1H,   3
		DB	 0EH, 1EH,   1,0BEH, 18H,   1,0B4H, 20H
		DB	0CDH, 16H,   3, 16H, 1CH,   1,0CDH, 27H
		DB	0B4H,0CAH,0D7H,0E9H,   0,   0,	 0,   0

;----------------------------------------------------------------------------
D_CKY		DB	'�����ʿ�Դ�ļ���: $'
D_SRFS		DB	'��������뷽ʽ��(��������): $'
L_2000:
		CMP	AL,1
		JZ	L_2001
		JMP	L_3000
L_2001: 	; ���鷽ʽ (ָ������ʵ佨����,��ָ�����뷽��)
		MOV	D_FILE1,OFFSET D_BUF1	;CCZZ1
		MOV	D_FILE2,0
		MOV	D_CX,0			;�������=0
		MOV	D_K,0			;�ܳ���=0
L_2030:
		MOV	DX,OFFSET D_CKY 	;'�����ʿ�Դ�ļ���:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;����ʿ�Դ�ļ���
		JNB	L_2040
		JMP	L_2160
L_2040:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_2050
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_2030
L_2050:
		MOV	D_HAN,AX

		MOV	D_DI,OFFSET D_BUF
		CALL	S_READ			;���ʵ��ļ�32K
		JNB	L_2060
		MOV	BX,D_HAN
		MOV	AH,3EH
		JMP	SHORT L_2030
L_2060:
		CALL	S_GETLINE		;ȡ��һ��SI
		JB	L_2030
		MOV	D_SI,SI 		;���������
		MOV	DI,OFFSET D_STR 	;�����������
		XOR	BX,BX			;	 ����
L_2070:
		LODSB
		CMP	AL,'a'
		JB	L_2072
		CMP	AL,'z'
		JA	L_2072
		STOSB
		INC	BX
		JMP	SHORT L_2070
L_2072:
		DEC	SI
L_2074:
		LODSB
		OR	AL,AL
		JZ	L_2060
		CMP	AL,' '
		JZ	L_2074
		CMP	AL,9
		JZ	L_2074
		DEC	SI
L_2080:
		ADD	D_K,BX

		MOV	AX,CS
		ADD	AX,1000H
		MOV	ES,AX
		MOV	DI,D_FILE2
		PUSH	SI
		MOV	CL,BL			;���볤
		MOV	SI,D_SI
		REP	MOVSB			;д�����
		POP	SI
		XOR	CX,CX
L_2090:
		LODSB
		CMP	AL,','
		JZ	L_2092
		OR	AL,AL
		JZ	L_2092
		STOSB				;д���������
		INC	CX
		JMP	SHORT L_2090
L_2092:
		MOV	D_FILE2,DI
		ADD	D_K,CX
		PUSH	CS
		POP	ES
		MOV	DI,D_FILE1
		MOV	DX,CX
		ADD	DX,BX
		MOV	[DI],DL
		INC	DI
		MOV	D_FILE1,DI

		INC	D_CX			;�������+1
		OR	AL,AL
		JZ	L_2100
		JMP	L_2080
L_2100:
		JMP	L_2060
L_2160:
		MOV	AX,D_CX 		;�������
		OR	AX,AX
		JNZ	L_2166
		JMP	BEGIN
L_2166:
		MOV	WORD PTR D_DATA2+30,AX
		ADD	AX,D_K
		MOV	WORD PTR D_DATA2+28,AX

		MOV	DX,OFFSET D_INCZ	;'���������ļ���: CZ'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;��������ļ���
		MOV	AX,WORD PTR D_CZ
		MOV	WORD PTR D_INPUT,AX
		MOV	SI,OFFSET D_INPUT
		MOV	DX,SI
L_2180:
		LODSB
		OR	AL,AL
		JNZ	L_2180
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;�γ��ļ���

		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		MOV	BX,AX

		MOV	DX,OFFSET D_SRFS	;'��������뷽ʽ��(��������): $'
		MOV	AH,9
		INT	21H
		MOV	DX,OFFSET D_INPUT	;���뻺����
		MOV	DI,DX
		MOV	WORD PTR [DI],5
		MOV	AH,0AH			;����
		INT	21H
		CALL	S_0D0A
		CMP	BYTE PTR [DI+1],0
		JZ	L_2200
		MOV	AX,[DI+2]
		MOV	WORD PTR D_DATA2+24,AX
		MOV	AX,[DI+4]
		MOV	WORD PTR D_DATA2+26,AX
L_2200:
		MOV	DX,OFFSET D_DATA2	;COM������
		MOV	CX,32
		MOV	AH,40H			;д���ļ�
		INT	21H
		MOV	DX,OFFSET D_BUF1
		MOV	CX,D_FILE1
		SUB	CX,DX
		MOV	AH,40H			;д���ļ�
		INT	21H
		MOV	CX,D_FILE2
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		XOR	DX,DX
		MOV	AH,40H			;д���ļ�
		INT	21H
		PUSH	CS
		POP	DS
		MOV	AH,3EH
		INT	21H

		CALL	S_ZJ
L_2210:
		XOR	AH,AH
		INT	16H
		CMP	AL,0DH
		JNZ	L_2210
		JMP	BEGIN

D_DATA2 	DB	 8CH,0CDH,0BAH, 20H,   1, 89H,0D1H,   3
		DB	 0EH, 1EH,   1,0BEH, 18H,   1,0B4H, 20H
		DB	0CDH, 16H,   3, 16H, 1CH,   1,0CDH, 27H
		DB	0B4H,0CAH,0D7H,0E9H,   0,   0,	 0,   0

;----------------------------------------------------------------------------
L_3000:
		CMP	AL,2
		JZ	L_3001
		JMP	L_4000
L_3001: 	; ������� (ָ���ʵ��ļ�������2.13K������ļ�)
		MOV	D_FILE1,OFFSET D_BUF1	;CCZZ1
		MOV	D_FILE2,0
		MOV	D_CX,0			;�������=0
		MOV	D_K,0			;�ܳ���=0
		MOV	AX,CS
		ADD	AX,1000H
		MOV	ES,AX
L_3030:
		MOV	DX,OFFSET D_INCD	;'�����ʵ��ļ���:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;����ʵ��ļ���
		JNB	L_3040
		JMP	L_3120
L_3040:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_3045
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_3030
L_3045:
		MOV	D_HAN,AX

		MOV	D_DI,OFFSET D_BUF
		CALL	S_READ			;���ʵ��ļ�32K
		JNB	L_3060
		MOV	BX,D_HAN
		MOV	AH,3EH
		JMP	SHORT L_3030
L_3060:
		CALL	S_GETSTR		;ȡ���ַ���SI
		JB	L_3030
		MOV	D_SI,SI 		;����
		MOV	DI,D_FILE2		;�����������
		XOR	BX,BX			;	 ����
		CMP	BYTE PTR [SI],0B0H	;�д��׺���?
		JB	L_3060
L_3070:
		LODSB
		AND	AL,7FH
		STOSB
		LODSB
		AND	AL,7FH
		STOSB
L_3080:
		LODSB
		OR	AL,AL
		JZ	L_3090
		STOSB
		JMP	SHORT L_3080
L_3090:
		MOV	D_FILE2,DI
		MOV	DI,D_FILE1
		MOV	[DI],CL
		INC	DI
		MOV	D_FILE1,DI

		ADD	D_K,CX
		INC	D_CX
		JMP	L_3060
L_3120:
		PUSH	CS
		POP	ES
		MOV	AX,D_CX 		;�������
		OR	AX,AX
		JNZ	L_3130
		JMP	BEGIN
L_3130:
		MOV	WORD PTR D_DATA3+30,AX
		ADD	AX,D_K
		MOV	WORD PTR D_DATA3+28,AX

		MOV	DX,OFFSET D_INLX	;'����������ļ���: LX'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;��������ļ���
		MOV	AX,WORD PTR D_LX
		MOV	WORD PTR D_INPUT,AX
		MOV	SI,OFFSET D_INPUT
		MOV	DX,SI
L_3140:
		LODSB
		OR	AL,AL
		JNZ	L_3140
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;�γ��ļ���

		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		MOV	BX,AX

		MOV	DX,OFFSET D_DATA3	;COM������
		MOV	CX,32
		MOV	AH,40H			;д���ļ�
		INT	21H
		MOV	DX,OFFSET D_BUF1
		MOV	CX,D_FILE1
		SUB	CX,DX
		MOV	AH,40H			;д���ļ�
		INT	21H
		MOV	CX,D_FILE2
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		XOR	DX,DX
		MOV	AH,40H			;д���ļ�
		INT	21H
		PUSH	CS
		POP	DS
		MOV	AH,3EH
		INT	21H

		CALL	S_ZJ
L_3150:
		XOR	AH,AH
		INT	16H
		CMP	AL,0DH
		JNZ	L_3150
		JMP	BEGIN

D_DATA3 	DB	 8CH,0CDH,0BAH, 20H,   1, 89H,0D1H,   3
		DB	 0EH, 1EH,   1,0B8H,   1, 20H,0CDH, 16H
		DB	 89H,0CAH,   3, 16H, 1CH,   1,0CDH, 27H
		DB	   0,	0,   0,   0,   0,   0,	 0,   0

;----------------------------------------------------------------------------
D_SPK		DB	'�����2.13K˫ƴ�����ļ���(��Ҫ��չ��): $'
L_4000:
		CMP	AL,3
		JZ	L_4001
		JMP	L_5000
L_4001: 	; ��˫ƴת�� (��2.13K��˫ƴ����ת��Ϊ�ʵ��ļ�)
		MOV	DX,OFFSET D_SPK 	;'�����2.13H������ļ���:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;�����ļ���
		JNB	L_4010
		JMP	BEGIN
L_4010:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_4012:
		LODSB
		OR	AL,AL			;��β?
		JNZ	L_4012
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;�γ��ļ���

		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_4014
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_4014:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'�����ʵ��ļ���:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;����ʵ��ļ���
		JNB	L_4020
		JMP	BEGIN
L_4020:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;��˫ƴ�����ļ�
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[128H]		;���ִ���
		SUB	CX,2
		SUB	CX,130H
		SHR	CX,1
		SHR	CX,1
		MOV	SI,130H 		;˫ƴ����
		MOV	DI,OFFSET D_STR 	;�ʵ�һ������
		XOR	BP,BP			;	 ����
L_4050:
		CMP	SI,130H 		;�״�?
		JZ	L_4080
		MOV	AX,BP
		ADD	AX,4
		CMP	AX,78			;����һ��?
		JBE	L_4070
		CALL	S_WLINE 		;д��һ��
		XOR	BP,BP			;��0
		JMP	SHORT L_4080
L_4070:
		MOV	AL,','                  ;�ָ���
		STOSB
L_4080:
		LODSW				;д����ִ�
		STOSW
		LODSW
		STOSW
		ADD	BP,5
		LOOP	L_4050
		CALL	S_WLINE

		MOV	AX,DS:[12AH]		;���ִ���
		MOV	SI,DS:[128H]		;-���ִ���
		SUB	AX,SI
		XOR	DX,DX
		MOV	CX,6
		DIV	CX
		MOV	CX,AX			;����
	;	MOV	DI,OFFSET D_STR 	;�ʵ�һ������
		XOR	BP,BP			;	 ����
L_4090:
		CMP	SI,DS:[128H]		;�״�?
		JZ	L_4110
		MOV	AX,BP
		ADD	AX,6
		CMP	AX,78			;����һ��?
		JBE	L_4100
		CALL	S_WLINE
		XOR	BP,BP			;��0
		JMP	SHORT L_4110
L_4100:
		MOV	AL,','                  ;�ָ���
		STOSB
L_4110:
		LODSW				;д�����ִ�
		STOSW
		LODSW
		STOSW
		LODSW
		STOSW
		ADD	BP,7
		LOOP	L_4090
		CALL	S_WLINE

		MOV	SI,DS:[12AH]		;���ִ���
	;	MOV	DI,OFFSET D_STR
		XOR	BP,BP
L_4120:
		CMP	SI,DS:[12AH]		;���ִ���?
		JZ	L_4150
		MOV	DX,SI
L_4130:
		LODSB
		CMP	AL,','
		JNZ	L_4130
		DEC	SI
		SUB	SI,DX
		XCHG	SI,DX

		ADD	DX,BP
		CMP	DX,78
		JBE	L_4140
		CALL	S_WLINE
		XOR	BP,BP
		JMP	SHORT L_4150
L_4140:
		MOV	AL,','                  ;�ָ���
		STOSB
		INC	BP
L_4150:
		LODSB
		CMP	AL,','
		JZ	L_4160
		STOSB
		INC	BP
		JMP	SHORT L_4150
L_4160:
		CMP	BYTE PTR [SI],1AH
		JNZ	L_4120
		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;�ӳ���:д��һ��
S_WLINE 	PROC	NEAR
		MOV	AX,0A0DH
		STOSW				;д��
		JMP	SHORT L_WL1
S_WLINE1:
		MOV	AX,0A0DH
		STOSW				;д��
		MOV	AL,1AH
		STOSB
L_WL1:
		PUSH	CX
		PUSH	DX
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_STR
		MOV	CX,DI
		SUB	CX,DX
		MOV	AH,40H			;���ļ�
		INT	21H
		MOV	DI,OFFSET D_STR
		POP	DS
		POP	DX
		POP	CX
		RET
S_WLINE 	ENDP

;----------------------------------------------------------------------------
D_LXH		DB	'�����2.13H������ļ���(��Ҫ��չ��): $'
L_5000:
		CMP	AL,4
		JZ	L_5001
		JMP	L_6000
L_5001: 	; ������ת�� (��2.13H�������ļ�ת��Ϊ�ʵ��ļ�)
		MOV	DX,OFFSET D_LXH 	;'�����2.13H������ļ���:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;�����ļ���
		JNB	L_5010
		JMP	BEGIN
L_5010:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_5012:
		LODSB
		OR	AL,AL			;��β?
		JNZ	L_5012
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;�γ��ļ���

		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_5014
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_5014:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'�����ʵ��ļ���:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;����ʵ��ļ���
		JNB	L_5020
		JMP	BEGIN
L_5020:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;��ȫ��������ļ�
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;�������
		MOV	SI,120H 		;��������
		MOV	BP,CX
		SHL	BP,1
		SHL	BP,1
		ADD	BP,SI			;����������
		MOV	DI,OFFSET D_STR 	;�ʵ�һ������
		MOV	CS:D_CX,0		;	 ����
L_5050:
		MOV	DL,[SI+3]		;�������ݳ���
		XOR	DH,DH

		CMP	CX,DS:[11EH]		;�״�?
		JZ	L_5080
		MOV	AX,CS:D_CX		;����
		ADD	AX,DX			;�ۼ�
		ADD	AX,2
		CMP	AL,78			;����һ��?
		JBE	L_5070
		CALL	S_WLINE
		MOV	CS:D_CX,0		;��0
		JMP	SHORT L_5080
L_5070:
		MOV	AL,','                  ;�ָ���
		STOSB
L_5080:
		LODSW				;д������
		STOSW
		ADD	SI,2
		MOV	DH,DL
		SHR	DH,1
L_5090:
		MOV	AX,DS:[BP]
		ADD	BP,2
		STOSW				;д������
		DEC	DH
		JNZ	L_5090

		MOV	AX,CS:D_CX
		ADD	AX,3
		ADD	AX,DX
		MOV	CS:D_CX,AX
		LOOP	L_5050
		CALL	S_WLINE1		;д��ĩ��

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;----------------------------------------------------------------------------
D_CZH		DB	'�����2.13H�����ļ���(��Ҫ��չ��): $'
L_6000:
		CMP	AL,5
		JZ	L_6001
		JMP	L_6600
L_6001: 	; �ϴ���ת�� (��2.13H�Ĵ����ļ�ת��Ϊ�ʵ��ļ�)
		MOV	DX,OFFSET D_CZH 	;'�����2.13H�����ļ���:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;�����ļ���
		JNB	L_6010
		JMP	BEGIN
L_6010:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_6012:
		LODSB
		OR	AL,AL			;��β?
		JNZ	L_6012
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;�γ��ļ���

		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_6014
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_6014:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'�����ʵ��ļ���:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;����ʵ��ļ���
		JNB	L_6020
		JMP	BEGIN
L_6020:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;��ȫ�������ļ�
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;�������
		MOV	SI,120H 		;��������
		MOV	BP,CX
		SHL	BP,1
		SHL	BP,1
		ADD	BP,SI			;��������
		MOV	DI,OFFSET D_STR
		MOV	CS:D_CX,0
L_6060:
		MOV	DL,[SI+3]		;���볤��
		XOR	DH,DH

		CMP	SI,120H 		;�״�?
		JZ	L_6080
		MOV	AX,CS:D_CX
		ADD	AX,DX
		CMP	AL,78
		JBE	L_6070
		CALL	S_WLINE
		MOV	CS:D_CX,0		;��0
		JMP	SHORT L_6080
L_6070:
		MOV	AL,','                  ;�ָ���
		STOSB
L_6080:
		ADD	SI,4
		MOV	AX,CS:D_CX
		ADD	AX,DX
		INC	DX
		MOV	CS:D_CX,AX
L_6090:
		MOV	AL,DS:[BP]
		INC	BP
		STOSB
		DEC	DL
		JNZ	L_6090
		LOOP	L_6060
		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;----------------------------------------------------------------------------
L_6600:
		CMP	AL,6
		JZ	L_6601
		JMP	L_7000
L_6601: 	; �ϴ���ת�� (��2.13H�Ĵ����ļ�ת��Ϊ����ʵ�)
		MOV	DX,OFFSET D_CZH 	;'�����2.13H�����ļ���:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;�����ļ���
		JNB	L_6610
		JMP	BEGIN
L_6610:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_6612:
		LODSB
		OR	AL,AL			;��β?
		JNZ	L_6612
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;�γ��ļ���

		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_6614
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_6614:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'�����ʵ��ļ���:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;����ʵ��ļ���
		JNB	L_6620
		JMP	BEGIN
L_6620:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;��ȫ�������ļ�
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;�������
		MOV	SI,120H 		;��������
		MOV	BP,CX
		SHL	BP,1
		SHL	BP,1
		ADD	BP,SI			;��������
		MOV	DI,OFFSET D_STR
		MOV	CS:D_CX,0
L_6660:
		MOV	DL,[SI+3]		;���볤��
		XOR	DH,DH

		CMP	SI,120H 		;�״�?
		JZ	L_6680
		MOV	AX,CS:D_CX
		ADD	AX,DX
		CMP	AL,78
		JBE	L_6670
		CALL	S_WLINE
		MOV	CS:D_CX,0		;��0
		JMP	SHORT L_6680
L_6670:
		MOV	AL,','                  ;�ָ���
		STOSB
L_6680:
		LODSW
		STOSW				;�����
		LODSB
		STOSB
		INC	SI
		MOV	AX,CS:D_CX
		ADD	AX,DX
		INC	DX
		MOV	CS:D_CX,AX
L_6690:
		MOV	AL,DS:[BP]
		INC	BP
		STOSB				;�����
		DEC	DL
		JNZ	L_6690
		LOOP	L_6660
		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;----------------------------------------------------------------------------
D_LXK		DB	'�����2.13K������ļ���: $'
L_7000:
		CMP	AL,7
		JZ	L_7001
		JMP	L_8000
L_7001: 	; ������ת�� (��2.13K�������ļ�ת��Ϊ�ʵ��ļ�)
		MOV	DX,OFFSET D_LXH 	;'�����2.13K������ļ���:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;�����ļ���
		JNB	L_7010
		JMP	BEGIN
L_7010:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_7012:
		LODSB
		OR	AL,AL			;��β?
		JNZ	L_7012
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;�γ��ļ���

		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_7014
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_7014:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'�����ʵ��ļ���:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;����ʵ��ļ���
		JNB	L_7020
		JMP	BEGIN
L_7020:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;��ȫ��������ļ�
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;�������
		MOV	SI,120H 		;��������
		MOV	BP,CX
		ADD	BP,SI			;����������
		MOV	DI,OFFSET D_STR 	;�ʵ�һ������
		MOV	CS:D_CX,0		;	 ����
L_7050:
		LODSB				;�������ݳ���
		XOR	AH,AH
		MOV	DX,AX

		CMP	CX,DS:[11EH]		;�״�?
		JZ	L_7080
		MOV	AX,CS:D_CX		;����
		ADD	AX,DX			;�ۼ�
		INC	AX
		CMP	AL,78			;����һ��?
		JBE	L_7070
		CALL	S_WLINE
		MOV	CS:D_CX,0		;��0
		JMP	SHORT L_7080
L_7070:
		MOV	AL,','                  ;�ָ���
		STOSB
L_7080:
		PUSH	DX
		MOV	AX,DS:[BP]
		ADD	BP,2
		OR	AX,8080H
		STOSW
		SUB	DX,2
L_7090:
		MOV	AL,DS:[BP]
		INC	BP
		STOSB
		DEC	DX
		JNZ	L_7090
		POP	DX

		MOV	AX,CS:D_CX
		ADD	AX,DX
		INC	AX
		MOV	CS:D_CX,AX
		LOOP	L_7050
		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;----------------------------------------------------------------------------
D_CZK		DB	'�����2.13K�����ļ���(��Ҫ��չ��): $'
L_8000:
		CMP	AL,8
		JZ	L_8001
		JMP	L_8600
L_8001: 	; �´���ת�� (��2.13K�Ĵ����ļ�ת��Ϊ�ʵ��ļ�)
		MOV	DX,OFFSET D_CZK 	;'�����2.13K�����ļ���:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;�����ļ���
		JNB	L_8010
		JMP	BEGIN
L_8010:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_8012:
		LODSB
		OR	AL,AL			;��β?
		JNZ	L_8012
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;�γ��ļ���

		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_8014
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_8014:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'�����ʵ��ļ���:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;����ʵ��ļ���
		JNB	L_8020
		JMP	BEGIN
L_8020:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;��ȫ�������ļ�
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;�������
		MOV	BP,120H 		;��������
		MOV	SI,CX
		ADD	SI,BP			;��������
		MOV	DI,OFFSET D_STR
		MOV	CS:D_CX,0
L_8060:
		MOV	AL,DS:[BP]		;���볤��
		INC	BP
		MOV	DH,AL
		XOR	DL,DL
		PUSH	DI
		MOV	DI,OFFSET D_BUF1
L_8062:
		LODSB				;���ұ���β
		SUB	DH,1
		CMP	AL,'`'
		JB	L_8064
		CMP	AL,'z'
		JBE	L_8062
L_8064:
		STOSB
		INC	DL
		LODSB
		SUB	DH,1
		JNB	L_8064
		XOR	DH,DH
		DEC	SI
		POP	DI

		CMP	CX,DS:[11EH]		;�״�?
		JZ	L_8080
		MOV	AX,CS:D_CX
		ADD	AX,DX
		INC	AX
		CMP	AL,78
		JBE	L_8070
		CALL	S_WLINE
		MOV	CS:D_CX,0		;��0
		JMP	SHORT L_8080
L_8070:
		MOV	AL,','                  ;�ָ���
		STOSB
L_8080:
		MOV	AX,CS:D_CX
		ADD	AX,DX
		INC	AX
		MOV	CS:D_CX,AX
		PUSH	SI
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	SI,OFFSET D_BUF1
L_8090:
		LODSB
		STOSB
		DEC	DX
		JNZ	L_8090
		POP	DS
		POP	SI
		LOOP	L_8060

		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN

;----------------------------------------------------------------------------
L_8600:
		CMP	AL,9
		JZ	L_8601
		JMP	L_9000
L_8601: 	; �´���ת�� (��2.13K�Ĵ����ļ�ת��Ϊ����ʵ�)
		MOV	DX,OFFSET D_CZK 	;'�����2.13K�����ļ���:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;�����ļ���
		JNB	L_8610
		JMP	BEGIN
L_8610:
		MOV	SI,OFFSET D_INPUT+2
		MOV	DX,SI
L_8612:
		LODSB
		OR	AL,AL			;��β?
		JNZ	L_8612
		DEC	SI
		MOV	DI,SI
		MOV	SI,OFFSET D_COM
		MOV	CX,5
		REP	MOVSB			;�γ��ļ���

		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_8614
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_8614:
		MOV	BX,AX

		MOV	DX,OFFSET D_INCD	;'�����ʵ��ļ���:'
		MOV	AH,9
		INT	21H

		CALL	S_INFILE		;����ʵ��ļ���
		JNB	L_8620
		JMP	BEGIN
L_8620:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		PUSH	AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH			;��ȫ�������ļ�
		INT	21H
		MOV	AH,3EH
		INT	21H
		POP	BX

		MOV	CX,DS:[11EH]		;�������
		MOV	SI,120H 		;��������
		MOV	BP,CX
		ADD	BP,SI			;��������
		MOV	DI,OFFSET D_STR
		MOV	CS:D_CX,0
		MOV	WORD PTR DS:[0],0A0DH
L_8660:
		LODSB				;���볤��
		MOV	DL,AL
		XOR	DH,DH
		PUSH	CX
		PUSH	DX
		MOV	CX,DX
		MOV	DX,BP
		MOV	AH,40H
		INT	21H
		XOR	DX,DX
		MOV	CX,2
		MOV	AH,40H
		INT	21H
		POP	DX
		POP	CX
		ADD	BP,DX
		LOOP	L_8660
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_1A
		MOV	CX,1
		MOV	AH,40H
		INT	21H
		MOV	AH,3EH
		INT	21H
		JMP	BEGIN
;----------------------------------------------------------------------------
L_9000:
		CMP	AL,10
		JZ	L_9001
		JMP	L_10000
L_9001: 	; ˫ƴ����ת��(��SPCZ.DATת��Ϊ�ʵ��ļ�CK.DAT)
		MOV	DX,OFFSET D_SPCZ	;˫ƴ�����ļ�
		MOV	AX,3D00H		;��
		INT	21H
		JNB	L_9010
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_9010:
		MOV	BX,AX
		MOV	AX,CS
		ADD	AX,1000H
		MOV	DS,AX			;��һ��
		XOR	DX,DX
		MOV	CX,-1
		MOV	AH,3FH			;���ļ�
		INT	21H
		MOV	SI,AX
		MOV	WORD PTR [SI],0 	;������β��0
		MOV	AH,3EH			;�ر�
		INT	21H

		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_CK		;'CK.DAT'
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		MOV	BX,AX
		POP	DS

		MOV	SI,16			;���ִ���
		MOV	DI,OFFSET D_STR 	;�������
L_9020:
		LODSW				;ȡ����
		OR	AX,8080H
		STOSW
		MOV	AL,':'
		STOSB
L_9030:
		TEST	WORD PTR [SI],8080H	;����һ����
		JZ	L_9040
		LODSW
		STOSW				;��ڶ���
		JMP	SHORT L_9030
L_9040:
		CALL	S_WLINE
		CMP	SI,DS:[0]		;�����ִ���?
		JB	L_9020

		XOR	BP,BP			;����
L_9050:
		CMP	BP,73			;����?
		JB	L_9060
		CALL	S_WLINE 		;д��
		XOR	BP,BP
L_9060:
		OR	BP,BP
		JZ	L_9070
		MOV	AL,','
		STOSB
		INC	BP
L_9070:
		LODSW				;ȡ����
		OR	AX,8080H
		STOSW				;������
		LODSW
		STOSW				;��ڶ���
		LODSW
		STOSW				;�������
		ADD	BP,6
		CMP	SI,DS:[2]		;�ж��ִ���?
		JB	L_9050
		CALL	S_WLINE

		XOR	BP,BP
L_9100:
		PUSH	SI
		XOR	DX,DX			;			3.15
L_9110:
		LODSB
		CMP	AL,','                  ;�д�β?
		JZ	L_9120
		INC	DX
		JMP	SHORT L_9110
L_9120:
		POP	SI
		ADD	DX,BP			;�ۼ�
		CMP	DX,78			;����?
		JBE	L_9130
		CALL	S_WLINE
		XOR	BP,BP
L_9130:
		OR	BP,BP			;����?
		JZ	L_9140
		MOV	AL,','
		STOSB
		INC	BP
L_9140:
		LODSB				;			3.15
		CMP	AL,','                  ;�д�β?
		JZ	L_9160
		STOSB
		INC	BP
		JMP	SHORT L_9140
L_9160:
		CMP	SI,DS:[4]		;��չ����
		JB	L_9100
		CALL	S_WLINE1
		MOV	AH,3EH
		INT	21H
		PUSH	CS
		POP	DS
		JMP	BEGIN
;----------------------------------------------------------------------------
D_CDK		DB	'�����2.13K�ʵ��ļ���: $'
L_10000:
		CMP	AL,11
		JZ	L_10001
		JMP	L_11000
L_10001:	; �ʵ��ʽת��(ԭ�ʵ��ļ�ת��Ϊר�ø�ʽCK.DAT)
		MOV	DX,OFFSET D_CDK 	;'�����2.13K�ʵ��ļ���:'
		MOV	AH,9
		INT	21H
		CALL	S_INFILE		;����ʵ��ļ���
		JNB	L_10010
		JMP	BEGIN
L_10010:
		MOV	DX,OFFSET D_INPUT+2	;�ʵ��ļ�����
		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_10020
		MOV	AX,0E07H
		INT	10H
		JMP	BEGIN
L_10020:
		MOV	D_HAN,AX

		MOV	DX,OFFSET D_CK		;'CK.DAT',0
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		MOV	BX,AX

		MOV	D_DI,OFFSET D_BUF
		MOV	DI,OFFSET D_STR
		XOR	BP,BP
		CALL	S_READ			;���ʵ��ļ�32K
		JNB	L_10022
		MOV	BX,D_HAN
		MOV	AH,3EH
		JMP	BEGIN
L_10022:
		XOR	DX,DX
L_10030:
		CALL	S_GETSTR		;ȡ���ַ���SI
		JNB	L_10040
		JMP	L_10100
L_10040:
		CMP	CX,4			;�ж��ִ�?
		JNZ	L_10060
		LODSW				;ȡ��һ��
		CMP	AX,DX			;��ͬ����?
		JZ	L_10050
		OR	DX,DX
		JZ	L_10044
		PUSH	AX
		CALL	S_WLINE 		;д��һ��
		POP	AX
L_10044:
		MOV	DX,AX			;������
		STOSW
		MOV	AL,':'
		STOSB
L_10050:
		LODSW				;ȡ�ڶ���
		STOSW
		JMP	SHORT L_10030
L_10060:
		CALL	S_WLINE

	;	MOV	DI,OFFSET D_STR
		XOR	BP,BP
		JMP	SHORT L_10080
L_10070:
		CALL	S_GETSTR
		JB	L_10100
L_10080:
		MOV	AX,BP
		ADD	AX,CX
		INC	AX
		CMP	AX,78
		JBE	L_10090
		CALL	S_WLINE
		XOR	BP,BP
L_10090:
		OR	BP,BP
		JZ	L_10091
		MOV	AL,','
		STOSB
L_10091:
		ADD	BP,CX
		INC	BP
		REP	MOVSB
		JMP	SHORT L_10070
L_10100:
		CALL	S_WLINE1

		MOV	AH,3EH
		INT	21H
		JMP	BEGIN
;----------------------------------------------------------------------------
L_11000:
		CMP	AL,12
		JZ	L_11001
		MOV	AX,600H 		;�ֲ�����
		XOR	BX,BX
		MOV	CX,1000H
		MOV	DX,174FH
		INT	10H
		JMP	L_150
L_11001:	; ��˫ƴ����(��CK.DAT����˫ƴ�����ļ�SPCZ.DAT)
		MOV	DX,OFFSET D_CK		;'CK.DAT',0
		MOV	AX,3D00H
		INT	21H
		JNB	L_11010
L_11002:
		MOV	DX,OFFSET NOCKDAT	;			11.6
L_11005:
		MOV	AH,9			;			11.5
		INT	21H
		XOR	AH,AH
		INT	16H
		JMP	BEGIN
L_11010:
		MOV	D_HAN,AX

		MOV	AX,CS
		ADD	AX,1000H		;��һ��
		MOV	ES,AX
		XOR	DI,DI
		MOV	CX,16
		XOR	AL,AL
		REP	STOSB			;16���ո�

		MOV	D_DI,OFFSET D_BUF
		CALL	S_READ			;���ʵ��ļ�32K
		JNB	L_11020
		MOV	BX,D_HAN
		MOV	AH,3EH
		JMP	SHORT L_11002
L_11020:
		CALL	S_GETLINE		;ȡһ��SI,CX=����
		CMP	BYTE PTR [SI+2],':'     ;�ж��ִ�?
		JNZ	L_11030
		LODSW				;����
		AND	AX,7F7FH		;ȥ��λ
		STOSW
		INC	SI
		SUB	CX,3
		TEST	CL,1			;����:���ַ�?		11.5
		JZ	L_11022
		MOV	DX,OFFSET NOALLHZ
		JMP	SHORT L_11005
L_11022:
		MOV	AX,CX
		SHR	AX,1
		ADD	BP,AX
		REP	MOVSB			;��
		JMP	SHORT L_11020
L_11030:
		MOV	SI,D_DI 		;��һ����
		MOV	WORD PTR [SI-2],0A0DH	;�ָ�ODOA
		ADD	CX,2
		SUB	D_DI,CX
		MOV	ES:[0],DI		;���ִ���
L_11040:
		CALL	S_GETSTR		;ȡһ��
		CMP	CL,6
		JNZ	L_11050
		LODSW				;����
		AND	AX,7F7FH
		STOSW				;��
		LODSW
		STOSW
		LODSW
		STOSW
		INC	BP
		JMP	SHORT L_11040
L_11050:
		MOV	ES:[2],DI		;���ִ���
		JMP	SHORT L_11070
L_11060:
		CALL	S_GETSTR		;ȡһ��
		JB	L_11080
L_11070:
		REP	MOVSB			;��			3.15
		MOV	AL,','
		STOSB
		INC	BP
		JMP	SHORT L_11060
L_11080:
		MOV	ES:[4],DI		;���ִ�β
		MOV	ES:[6],DI		;��չ��β
		MOV	BYTE PTR ES:[0FH],0FFH	;��SPCZ.DAT��־ 	3.15

		MOV	DX,OFFSET D_SPCZ	;SPCZ.DAT',0
		MOV	CX,20H
		MOV	AH,3CH
		INT	21H
		MOV	BX,AX

		PUSH	ES
		POP	DS
		XOR	DX,DX
		MOV	CX,DI
		MOV	AH,40H			;д���ļ�
		INT	21H
		MOV	AH,3EH			;�ر��ļ�
		INT	21H

		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	D_CX,BP 		;������ 		11.5
		MOV	D_K,DI			;�ܳ���
		CALL	S_ZJ			;��ʾ
		XOR	AH,AH
		INT	16H
		JMP	BEGIN
;ͨ���ӳ���==================================================================
;�ӳ���:����
S_CLS		PROC	NEAR
		MOV	AX,600H
		XOR	BX,BX
		XOR	CX,CX
		MOV	DX,184FH
		INT	10H
		RET
S_CLS		ENDP

;�ӳ���:�س�����
S_0D0A		PROC	NEAR
		MOV	AX,0E0DH
		INT	10H
		MOV	AX,0E0AH
		INT	10H
		RET
S_0D0A		ENDP

;�ӳ���:��ʾ�˵� D_X:���(0-12)
S_XSCD		PROC	NEAR
		MOV	BX,4EH
		MOV	AL,D_X
		MOV	D_X1,AL
		JMP	SHORT L_XC1
S_XSCD1:
		MOV	BX,7
		MOV	AL,D_X1
L_XC1:
		MOV	DH,AL
		ADD	DH,2
		MOV	DL,16
		MOV	AH,47
		MUL	AH
		ADD	AX,OFFSET D_MENU
		MOV	SI,AX

;�ӳ���:��ʾ�ַ���SI,DX=����λ��,BL=����.��ʾ�����ڴ�β
S_XSZF:
L_XZ1:
		MOV	AH,2
		INT	10H
		LODSB
		OR	AL,AL
		JZ	L_XZ2
		MOV	AH,9
		MOV	CX,1
		INT	10H
		INC	DX
		JMP	SHORT L_XZ1
L_XZ2:
		RET
S_XSCD		ENDP

S_KGB		PROC	NEAR
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		RET
S_KGB		ENDP

;�ӳ���:���㲢��ʾ
S_ZJ		PROC	NEAR
		MOV	SI,OFFSET D_ZJ+13
		MOV	AX,D_CX 		;�������
		MOV	CX,5
		CALL	S_JS
		MOV	SI,OFFSET D_ZJ+29
		MOV	AX,D_K
		MOV	CX,5
		CALL	S_JS
		MOV	SI,OFFSET D_ZJ		;'�ܼƴ���    ��,�ܳ���     �ֽ�'
L_ZJ1:
		LODSB
		CMP	AL,'$'
		JZ	L_ZJ2
		OR	AL,AL
		JZ	L_ZJ1
		MOV	DL,AL
		MOV	AH,2
		INT	21H
		JMP	SHORT L_ZJ1
L_ZJ2:
		RET
S_JS:
		MOV	DI,10
L_JS1:
		XOR	DX,DX
		DIV	DI
		OR	DL,DL
		JNZ	L_JS2
		OR	AL,AL
		JZ	L_JS3
L_JS2:
		OR	DL,30H
L_JS3:
		MOV	[SI],DL
		DEC	SI
		LOOP	L_JS1
		RET
S_ZJ		ENDP

;�ӳ���:�����ļ���->D_INPUT+2
S_INFILE	PROC	NEAR
		MOV	SI,OFFSET D_INPUT+2	;���뻺����
L_IN1:
		XOR	AH,AH			;����
		INT	16H
		CMP	AL,0DH			;�س�?
		JZ	L_IN6
		CMP	AL,1BH			;<ESC>
		JZ	L_IN7
		CMP	AL,8			;�˸�?
		JNZ	L_IN5
		CMP	SI,OFFSET D_INPUT+2	;ָ��������?
		JA	L_IN3
L_IN2:
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_IN1
L_IN3:
		DEC	SI			;λ��-1
L_IN4:
		MOV	DL,AL
		MOV	AH,2			;��ʾ
		INT	21H
		CMP	AL,8			;�˸�?
		JNZ	L_IN1
		MOV	CX,1
		MOV	AL,20H			;��ʾ�ո�
		JMP	SHORT L_IN4
L_IN5:
		MOV	[SI],AL 		;д��
		INC	SI
		JMP	SHORT L_IN4		;��ʾ
L_IN6:
		CALL	S_0D0A
		CMP	SI,OFFSET D_INPUT+2
		JZ	L_IN7
		MOV	BYTE PTR [SI],0
		CLC
		RET
L_IN7:
		STC
		RET
S_INFILE	ENDP

;�ӳ���:�õ��ַ���SI,CX=����,D_DI=��һ�ַ�����
S_GETSTR	PROC	NEAR
		MOV	BYTE PTR K_LINE,OFFSET L_GS6-OFFSET L_GS3A
		JMP	SHORT L_GSA
S_GETLINE:
		MOV	BYTE PTR K_LINE,0
L_GSA:
		MOV	D_0D,0
		PUSH	DI
		MOV	DI,D_DI
		XOR	CX,CX
		MOV	SI,DI			;���ַ�����
		CMP	SI,D_END		;�е�������β?
		JB	L_GS1
		CALL	S_READ			;��32K
		JNB	L_GS1
L_GS0:
		POP	DI
		STC
		RET
L_GS1:
		MOV	DI,SI			;ָ������
L_GS2:
		CMP	SI,D_END		;�е�������β?
		JB	L_GS3
		PUSH	CX
		MOV	CX,D_END
		SUB	CX,DI			;���ַ����Ѵ�����
		MOV	SI,DI			;	 ��
		MOV	DI,OFFSET D_BUF
		SUB	DI,CX			;�ƶ���ַ
		PUSH	DI
		PUSH	ES
		PUSH	CS
		POP	ES
		REP	MOVSB			;δ�괮��BUF��ǰ
		POP	ES
		POP	DI
		POP	CX
		CALL	S_READ			;��32K
		JB	L_GS0
L_GS3:
		LODSB				;ȡһ�ַ�
		CMP	AL,','                  ;�ָ���?
		JZ	L_GS6
K_LINE	EQU	$-1
L_GS3A:
		CMP	AL,0DH			;�س�?
		JNZ	L_GS5
		CMP	D_0D,0AH		;���л���?
		JZ	L_GS6
L_GS4:
		MOV	BYTE PTR [SI-1],0
		MOV	D_0D,AL 		;��
		JMP	SHORT L_GS2
L_GS5:
		CMP	AL,0AH			;����?
		JNZ	L_GS7
		CMP	D_0D,0DH		;���лس�?
		JNZ	L_GS4
L_GS6:
		MOV	BYTE PTR [SI-1],0
		XCHG	SI,DI			;
		MOV	D_DI,DI
		POP	DI
		CLC
		RET
L_GS7:
		INC	CX			;����+1
		JMP	SHORT L_GS2
S_GETSTR	ENDP

;�ӳ���:���ʵ��ļ�32K->D_BUF,D_END=������β
S_READ		PROC	NEAR
		PUSH	BX
		PUSH	CX
		MOV	BX,D_HAN
		MOV	DX,OFFSET D_BUF
		MOV	SI,DX
		MOV	CX,8000H		;32K
		MOV	AH,3FH			;���ļ�
		INT	21H
		OR	AX,AX
		JZ	L_READ1
		ADD	AX,SI
		MOV	D_END,AX
		POP	CX
		POP	BX
		CLC
		RET
L_READ1:
		POP	CX
		POP	BX
		STC
		RET
S_READ		ENDP

;�ӳ���:ȡ����AXƴ����AL,AH
S_PYM		PROC	NEAR
		MOV	DX,AX
		MOV	AH,22H
		INT	16H
		RET
S_PYM		ENDP

D_STR	EQU	$
D_BUF	EQU	$+512
D_BUF1	EQU	D_BUF+8000H

CSEG		ENDS
		END	START

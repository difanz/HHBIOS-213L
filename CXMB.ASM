;	CXMB.ASM
;	1996.10.9
;	1997.1.7
DATE	EQU	'1999.11.30'

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

D_V		DB	1			;���˵���ǰ��
D_V1		DB	1
D_T1		DB	'��������������������������������������������������������������������������������',0
D_T3		DB	'��������������������������������������������������������������������������������',0
D_T24		DB	'��������������������������������������������������������������������������������',0
D_SX		DB	'��',0
D_ST		DB	'��',0
D_TITLE 	DB	' HHBIOS 2.13L ����ϵͳ �޸��������',0
D_MAIN		DB	'ƴ �� ���� β ��һ����Ƶ������Ƶ��    ����    ��'
D_MSG1		DB	'�����ƶ����,���س���ѡ����.',0
D_MSG2		DB	'�ɼ�������,Ҳ�ɼ��뺺��,�Զ��������������,ֱ�ӻس��򷵻����˵�.',0
D_MSG3		DB	'�س���һ����,PgUp��һ��,PgDn��һ��,�ո�ѡ����,ESC�˳�(��ESC��������޸Ľ��)',0
D_MSG4		DB	'���뺺���޸�,���ո������������˵�,��ESC��ֱ�ӷ������˵�.',0
D_MSG5		DB	'����˫ƴ��(��Сд����),ֱ�ӻس��������˵�.',0
D_MSG6		DB	'���뺺����֤�Ǹ�˫ƴʱ�޸�,���ո�������,��ESC�������,����ѡ˫ƴ��',0
D_QWMAX 	DB	'�����λ��:',0
D_INPUT 	DB	5 DUP(0)
D_QQ		DB	0
D_QH		DB	'����:',0
D_QM		DB	'��  ��',0
D_QM1		DB	'  0      1      2      3      4      5      6      7      8      9',0
D_QWM		DB	'0000',0
D_HZM		DB	'��???',0
D_GPZ		DB	'A �� �� �� �� �� �� �� �� �� �� ��',0
D_JRSP		DB	'�����˫ƴ��:',0
D_11		DB	' 1  2  3  4  5  6  7  8  9 10 11',0
D_GPZ2		DB	'�߰����������'
NOFILE		DB	'ָ������ļ�δ�ҵ�!',7,13,10,'$'

D_Q		DB	0			;����
D_W		DB	0,0			;λ��
D_WI		DB	0			;д���־
D_H		DB	0
D_L		DB	0
D_M		DB	0
D_N		DB	0
D_A1		DB	0
D_A2		DB	0
D_MB		DW	OFFSET D_PYMB

D_PYMB		DB	'PYMB',0
D_SWMB		DB	'SWMB',0

A_DZ		DW	OFFSET D_FILE		;�ļ���д���ַ
D_FILE		DB	64 DUP(0)
D_HAN		DW	0
D_LONG		DW	0			;���ǰ�ֽ���
D_SW		DB	'��β'
D_GPZQ		DB	286*2 DUP(0)
D_END		DW	0			;�ļ�β��ַ
D_ZS		DW	0			;�������
D_X		DB	0			;��
D_Y		DB	0			;��
D_Z		DB	0			;���ַ�λ

MSG		DB	'2.13L ����ϵͳ �޸�������� ',DATE,13,10
		DB	'��ʽ: CXMB [/F:·��][/W][/?]',13,10
		DB	'����: /F:·�� �޸�ָ��·�������',13,10
		DB	'      /W �޸ĵ�ǰĿ¼. ȱʡΪ2.13L��װ·�������',13,10
		DB	'      /? ��ʾ�����������в���˵��',13,10,'$'
D_WW		DB	0	;='W':2.13L��װ·��, ='F':ָ��·��

;****************************************************************************
BEGIN:
		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_10
L_1:
		LODSB
		CMP	AL,' '
		JZ	L_1
		CMP	AL,0DH			;����?
		JZ	L_10
		CMP	AL,'/'                  ;���ط�?
		JNZ	L_1
		LODSB
		CMP	AL,'?'                  ;<��ʾ����>
		JNZ	L_2
		MOV	DX,OFFSET MSG		;����
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_2:
		AND	AL,5FH
		CMP	AL,'W'                  ;������ǰĿ¼�ֿ�
		JNZ	L_3
		MOV	D_WW,AL
		JMP	SHORT L_1
L_3:
		CMP	AL,'F'                  ;����ָ��·�����ֿ�
		JNZ	L_1
		MOV	D_WW,AL
		LODSB			;':'
		MOV	DI,OFFSET D_FILE
L_4:
		LODSB				;����·��
		CMP	AL,' '
		JBE	L_5
		STOSB
		JMP	SHORT L_4
L_5:
		MOV	AL,'\'
		STOSB
		MOV	A_DZ,DI 		;�����ļ���д���ַ
		JMP	L_1
L_10:
		CMP	D_WW,'W'                ;�޸ĵ�ǰĿ¼���?
		JNZ	L_20
		MOV	A_DZ,OFFSET D_FILE
		JMP	SHORT L_50
		MOV	A_DZ,DI 		;�ļ���д���ַ
L_20:
		CMP	D_WW,'F'                ;�޸�ָ��Ŀ¼���?
		JZ	L_50
		MOV	AH,2FH			;ȡ2.13L��װ·��BP:DX
		INT	16H
		MOV	DS,BP
		MOV	SI,DX
		MOV	DI,OFFSET D_FILE	;�ļ���������
L_22:
		LODSB
		OR	AL,AL
		JZ	L_24
		STOSB
		JMP	SHORT L_22
L_24:
		MOV	AL,'\'
		STOSB
		PUSH	CS
		POP	DS
		MOV	A_DZ,DI
L_50:
		CALL	S_280			;������ļ�
L_60:
		CALL	S_CLS			;����
		MOV	SI,OFFSET D_T1		;����
		XOR	DX,DX
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_TITLE	;����
		MOV	DX,16H
		MOV	BX,4EH
		CALL	S_XSZF
		MOV	BX,1EH
		MOV	BP,23
		MOV	DX,100H
L_70:
		MOV	SI,OFFSET D_SX		;����
		PUSH	DX
		CALL	S_XSZF			;��ʾ�������
		POP	DX
		INC	DH
		DEC	BP
		JNZ	L_70

		MOV	BP,23
		MOV	DX,14EH
L_80:
		MOV	SI,OFFSET D_SX
		PUSH	DX
		CALL	S_XSZF			;��ʾ�ұ�����
		POP	DX
		INC	DH
		DEC	BP
		JNZ	L_80

		MOV	SI,OFFSET D_T3		;��ʾ����
		MOV	DX,200H
		CALL	S_XSZF
		MOV	SI,OFFSET D_T24 	;��ʾ����
		MOV	DX,1800H
		CALL	S_XSZF

		MOV	SI,6
		MOV	BP,OFFSET D_MAIN	;���˵�
		MOV	DX,105H
		MOV	BL,7
L_90:
		MOV	CX,8
		MOV	AX,1300H
		INT	10H
		ADD	BP,CX
		ADD	DL,12
		DEC	SI
		JNZ	L_90

		MOV	SI,OFFSET D_MSG1	;���˵���ʾ
		MOV	DX,1802H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_ST		;'��'
		MOV	DX,103H
		CMP	D_MB,OFFSET D_PYMB
		JZ	L_170
		MOV	DX,10FH
L_170:
		MOV	BX,1DH
		CALL	S_XSZF
		CALL	S_270
		MOV	CX,2000H
		MOV	AH,1			;�ع��
		INT	10H
L_180:
		MOV	AH,1
		INT	16H
		JZ	L_180
		XOR	AH,AH
		INT	16H

		CMP	AL,0DH
		JZ	L_240
L_200:
		CMP	AH,77			;��
		JNZ	L_210
		INC	D_V
		CMP	D_V,7
		JB	L_210
		MOV	D_V,1
L_210:
		CMP	AH,75			;��
		JNZ	L_220
		DEC	D_V
		CMP	D_V,0
		JA	L_220
		MOV	D_V,6
L_220:
		CMP	D_MB,OFFSET D_SWMB
		JNZ	L_230
		CMP	D_V,3
		JZ	L_200
		CMP	D_V,4
		JZ	L_200
L_230:
		CALL	S_260
		MOV	AL,D_V
		MOV	D_V1,AL
		JMP	L_180
L_240:
		MOV	CX,0E0FH
		MOV	AH,1			;�����
		INT	10H
		MOV	AL,D_V
		CMP	AL,6			;<�˳�>
		JNZ	L_350
		MOV	BX,D_HAN
		MOV	AH,3EH			;�ر��ļ�
		INT	21H
		CALL	S_CLS
		MOV	AX,4C00H		;�˳�
		INT	21H
;----------------------------------------------------------------------------
L_350:
		CMP	AL,5			;<����>
		JZ	L_351
		JMP	L_450
L_351:
		CMP	D_QQ,0
		JZ	L_390
		MOV	SI,OFFSET D_QWMAX
		MOV	DX,1632H
		MOV	BX,1EH
		CALL	S_XSZF
		CALL	S_INPUT
		OR	BX,BX
		JZ	L_390
		MOV	AX,BX
		MOV	BL,100
		DIV	BL
		MOV	BL,AH
		XOR	BH,BH
		SUB	AL,16
		MOV	AH,94
		MUL	AH
		ADD	AX,BX
		SHL	AX,1
		MOV	AX,OFFSET D_BUF
		MOV	D_END,AX

		MOV	BX,D_HAN
		MOV	AH,3EH			;�ر��ļ�
		INT	21H
		MOV	DX,OFFSET D_FILE
		MOV	AH,41H			;ɾ���ļ�
		INT	21H
		MOV	DX,OFFSET D_FILE
		MOV	AX,3D02H		;���ļ�
		INT	21H
		MOV	D_HAN,AX
L_390:
		MOV	BX,D_HAN
		XOR	CX,CX			;7.27
		XOR	DX,DX
		MOV	AX,4200H		;��дָ�����ļ���
		INT	21H
		CMP	D_MB,OFFSET D_PYMB
		JNZ	L_400
		MOV	DX,OFFSET D_GPZQ
		MOV	CX,286*2
		MOV	AH,40H
		INT	21H
		JMP	SHORT L_410
L_400:
		MOV	DX,OFFSET D_SW
		MOV	CX,4
		MOV	AH,40H
		INT	21H
L_410:
		MOV	DX,OFFSET D_BUF
		MOV	CX,D_END
		SUB	CX,DX
		MOV	AH,40H
		INT	21H
		JMP	L_60
;----------------------------------------------------------------------------
L_450:
		CMP	AL,2			;<��β��>
		JNZ	L_480
		MOV	SI,OFFSET D_ST		;'��'
		MOV	DX,10FH
		MOV	BX,1DH			;��ʾ
		CALL	S_XSZF
		MOV	DX,103H
		MOV	CX,2			;��
		CALL	S_QP
		CMP	D_MB,OFFSET D_PYMB	;ԭΪƴ��?
		JNZ	L_510
		MOV	BX,D_HAN
		MOV	AH,3EH
		INT	21H
		MOV	D_MB,OFFSET D_SWMB
		JMP	SHORT L_505
;............................................................................
L_480:
		CMP	AL,1			;<ƴ����>
		JZ	L_481
		JMP	L_1000
L_481:
		MOV	SI,OFFSET D_ST		;'��'
		MOV	DX,103H
		MOV	BX,1DH			;��ʾ
		CALL	S_XSZF
		MOV	DX,10FH
		MOV	CX,2			;��
		CALL	S_QP
		CMP	D_MB,OFFSET D_SWMB
		JNZ	L_510
		MOV	BX,D_HAN
		MOV	AH,3EH
		INT	21H
		MOV	D_MB,OFFSET D_PYMB
L_505:
		CALL	S_300
L_510:
		MOV	SI,OFFSET D_MSG2
		MOV	DX,1803H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_QH		;'����:'
		MOV	DX,1732H
		MOV	BX,1EH
		CALL	S_XSZF
L_520:
		XOR	AH,AH
		INT	16H
		CMP	AL,0DH
		JNZ	L_530
		JMP	L_60
L_530:
		CMP	AL,0A0H
		JB	L_531
		CALL	S_XSAL
		SUB	AL,0A0H
		MOV	D_Q,AL
		XOR	AH,AH
		INT	16H
		CALL	S_XSAL
		SUB	AL,0A0H
		MOV	D_W,AL
		JMP	SHORT L_550
L_531:
		CMP	AL,'1'
		JB	L_532
		CMP	AL,'9'
		JBE	L_533
L_532:
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_520
L_533:
		CALL	S_XSAL
		AND	AL,0FH
		MOV	BL,AL
		XOR	AH,AH
		INT	16H
		CMP	AL,'0'
		JB	L_534
		CMP	AL,'9'
		JBE	L_535
L_534:
		MOV	AX,0E07H
		INT	10H
		JMP	L_520
L_535:
		CALL	S_XSAL
		AND	AL,0FH
		CBW
		PUSH	AX
		MOV	AL,10
		MUL	BL
		MOV	BX,AX
		POP	AX
		ADD	BX,AX
L_538:
		OR	BL,BL
		JZ	L_534
		CMP	BL,94
		JA	L_534
		MOV	D_Q,BL
		MOV	D_W,1
L_550:
		MOV	DX,1732H
		MOV	CX,9
		CALL	S_QP
L_560:
		MOV	AL,D_Q			;����
		ADD	AL,0A0H
		MOV	D_HZM,AL
		MOV	AL,D_Q			;����
		CBW
		MOV	DL,10
		DIV	DL
		OR	AX,3030H
		MOV	WORD PTR D_QWM,AX
		MOV	WORD PTR D_QM+2,AX
		MOV	SI,OFFSET D_QM		;'��??��'
		MOV	DX,302H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_QM1 	;'  0     1 ...'
		MOV	BX,0FH
		CALL	S_XSZF
		MOV	D_WI,0			;��д���־

		MOV	DH,5
		MOV	BX,0FH
		MOV	CH,0
L_580:
		MOV	AL,CH
		ADD	AL,30H
		MOV	D_QWM+2,AL
		MOV	SI,OFFSET D_QWM 	;��ʾ'1610'
		MOV	DL,2
		PUSH	CX
		CALL	S_XSZF
		POP	CX

		MOV	CL,0
L_600:
		MOV	AL,7
		MUL	CL
		ADD	AL,8
		MOV	DL,AL			;ÿ����ʾλ��
		MOV	AL,10
		MUL	CH
		ADD	AL,CL			;λ��
		CMP	AL,0
		JZ	L_620
		CMP	AL,94
		JA	L_620
		PUSH	AX
		ADD	AL,0A0H
		MOV	D_HZM+1,AL
		POP	BX

		MOV	AL,D_Q
		SUB	AL,16
		MOV	AH,94
		MUL	AH
		ADD	AX,BX			;�������
		DEC	AX
		SHL	AX,1
		ADD	AX,OFFSET D_BUF
		MOV	BX,AX			;�����
		MOV	AX,[BX]
		PUSH	AX
		AND	AL,1FH
		ADD	AL,60H
		MOV	D_HZM+2,AL		;��һ��
		SHR	AH,1
		SHR	AH,1
		AND	AH,1FH
		ADD	AH,60H
		MOV	D_HZM+4,AH		;������
		POP	AX
		SHL	AX,1
		SHL	AX,1
		SHL	AX,1
		AND	AH,1FH
		ADD	AH,60H
		MOV	D_HZM+3,AH
		MOV	SI,OFFSET D_HZM 	;��ʾ ���ֺ�ƴ����
		MOV	BX,0FH
		PUSH	CX
		CALL	S_XSZF
		POP	CX
L_620:
		INC	CL
		CMP	CL,9
		JBE	L_600
		ADD	DH,2
		INC	CH
		CMP	CH,9
		JA	L_630
		JMP	L_580
L_630:
		MOV	SI,OFFSET D_MSG3	;������ʾ
		MOV	DX,1802H
		MOV	BX,1EH
		CALL	S_XSZF

		MOV	D_QQ,0
		CMP	D_Q,87
		JBE	L_633
		MOV	D_Q,1
L_633:
		MOV	AL,D_W
		CBW
		MOV	CL,10
		DIV	CL
		MOV	D_X,AH
		MOV	D_Y,AL
		MOV	D_Z,0
L_650:
		MOV	DH,D_Y
		SHL	DH,1
		ADD	DH,5
		MOV	AL,7
		MUL	D_X
		ADD	AL,10
		ADD	AL,D_Z
		MOV	DL,AL
		MOV	AH,2			;��λ
		INT	10H
L_660:
		XOR	AH,AH			;����
		INT	16H

		CMP	AH,75			;��
		JNZ	L_730
		CMP	D_Z,0
		JZ	L_710
		DEC	D_Z
		JMP	SHORT L_650
L_710:
		CMP	D_X,1
		JNZ	L_712
		CMP	D_Y,0
		JNZ	L_712
		MOV	D_X,9
		MOV	D_Z,2
		JMP	SHORT L_650
L_712:
		CMP	D_X,0
		JZ	L_720
		MOV	D_Z,2
		DEC	D_X
		JMP	L_650
L_720:
		MOV	D_X,9
		MOV	D_Z,2
		DEC	D_Y
		JMP	L_650
L_730:
		CMP	AH,77			;��
		JNZ	L_770
L_740:
		CMP	D_Z,2
		JAE	L_750
		INC	D_Z
		JMP	L_650
L_750:
		CMP	D_X,4
		JNZ	L_752
		CMP	D_Y,9
		JNZ	L_752
		MOV	D_X,0
		MOV	D_Z,0
		JMP	L_650
L_752:
		CMP	D_X,9
		JAE	L_760
		MOV	D_Z,0
		INC	D_X
		JMP	L_650
L_760:
		MOV	D_X,0
		MOV	D_Z,0
		INC	D_Y
		JMP	L_650
L_770:
		CMP	AH,72			;��
		JNZ	L_800
		CMP	D_X,0
		JNZ	L_772
		CMP	D_Y,1
		JNZ	L_772
		MOV	D_Y,9
		JMP	L_650
L_772:
		CMP	D_Y,0
		JZ	L_790
		DEC	D_Y
		JMP	L_650
L_790:
		CMP	D_X,4
		JBE	L_792
		MOV	D_Y,8
		JMP	L_650
L_792:
		MOV	D_Y,9
		JMP	L_650
L_800:
		CMP	AH,80			;��
		JNZ	L_830
		CMP	D_X,4
		JBE	L_802
		CMP	D_Y,8
		JNZ	L_802
		MOV	D_Y,0
		JMP	L_650
L_802:
		CMP	D_Y,9
		JAE	L_820
		INC	D_Y
		JMP	L_650
L_820:
		CMP	D_X,0
		JNZ	L_822
		MOV	D_Y,1
		JMP	L_650
L_822:
		MOV	D_Y,0
		JMP	L_650
L_830:
		CMP	AH,73			;PGUP
		JNZ	L_840
		CALL	S_930			;����Ļ�ϵ�ƴ����滺����
		CMP	D_Q,16
		JBE	L_832
		DEC	D_Q
		JMP	L_560
L_832:
		JMP	L_650
L_840:
		CMP	AH,81			;PGDN
		JNZ	L_860
		CALL	S_930			;����Ļ�ϵ�ƴ����滺����
		CMP	D_Q,94
		JAE	L_842
		INC	D_Q
		JMP	L_560
L_842:
		JMP	L_650
L_860:
		CMP	AL,0DH			;�س�
		JNZ	L_880
		CMP	D_X,4
		JNZ	L_862
		CMP	D_Y,9
		JNZ	L_862
		MOV	D_X,0
		MOV	D_Z,0
		JMP	L_650
L_862:
		CMP	D_X,9
		JAE	L_864
		INC	D_X
		JMP	L_650
L_864:
		MOV	D_X,0
		INC	D_Y
		JMP	L_650
L_880:
		CMP	AL,1BH			;ESC?
		JNZ	L_890
		JMP	L_60
L_890:
		CMP	AL,' '                  ;�ո�?
		JNZ	L_900
		CALL	S_930			;����Ļ�ϵ�ƴ����滺����
		JMP	L_510
L_900:
		CMP	AL,'A'
		JB	L_910
		CMP	AL,'Z'
		JA	L_910
		OR	AL,20H			;��д��Сд
L_910:
		CMP	AL,96			;`
		JB	L_920
		CMP	AL,'z'
		JA	L_920
		MOV	CX,1
		MOV	BX,4EH
		MOV	AH,9			;��ʾ
		INT	10H
		MOV	D_WI,1			;��д���־
		JMP	L_740
L_920:
		JMP	L_660
;----------------------------------------------------------------------------
L_1000:
		CMP	AL,3			;<һ����Ƶ>
		JZ	L_1001
		JMP	L_1330
L_1001:
		MOV	CH,0
L_1010:
		MOV	CL,0
L_1020:
		MOV	AL,13
		MUL	CL
		ADD	AL,CH
		MOV	BL,AL
		ADD	AL,65
		MOV	D_GPZ,AL
		MOV	AL,11
		MUL	BL
		SHL	AX,1
		ADD	AX,OFFSET D_GPZQ
		MOV	SI,AX
		MOV	BX,2
L_1030:
		LODSW
		MOV	WORD PTR D_GPZ[BX],AX
		ADD	BX,3
		CMP	BL,35
		JB	L_1030
		MOV	DH,CH
		ADD	DH,5
		MOV	AL,38
		MUL	CL
		ADD	AL,4
		MOV	DL,AL
		MOV	SI,OFFSET D_GPZ
		MOV	BX,7
		PUSH	CX
		CALL	S_XSZF
		POP	CX
		INC	CL
		CMP	CL,1
		JBE	L_1020
		INC	CH
		CMP	CH,12
		JBE	L_1010

		MOV	SI,OFFSET D_MSG4	;������ʾ
		MOV	DX,1802H
		MOV	BX,1EH
		CALL	S_XSZF

		XOR	AL,AL
		MOV	D_X,AL
		MOV	D_Y,AL
		MOV	D_Z,AL
		MOV	D_WI,AL
		MOV	D_H,AL
		MOV	BX,4EH
L_1070:
		MOV	DH,D_Y
		ADD	DH,5
		MOV	AL,3
		MUL	D_X
		MOV	DL,AL
		MOV	AL,38
		MUL	D_Z
		ADD	AL,6
		ADD	DL,AL
L_1080:
		MOV	AH,2
		INT	10H

		XOR	AH,AH			;����
		INT	16H
		CMP	AH,75			;��
		JNZ	L_1140
		CMP	D_X,0
		JZ	L_1120
		DEC	D_X
		JMP	L_1070
L_1120:
		MOV	D_X,10
		JMP	L_1070
L_1140:
		CMP	AH,77			;��
		JNZ	L_1170
		CMP	D_X,10
		JAE	L_1150
		INC	D_X
		JMP	L_1070
L_1150:
		MOV	D_X,0
		JMP	L_1070
L_1170:
		CMP	AH,72			;��
		JNZ	L_1200
		CMP	D_Y,0
		JZ	L_1180
		DEC	D_Y
		JMP	L_1070
L_1180:
		MOV	D_Y,12
		CMP	D_Z,0
		JNZ	L_1182
		MOV	D_Z,1
		JMP	L_1070
L_1182:
		MOV	D_Z,0
		JMP	L_1070
L_1200:
		CMP	AH,80			;��
		JNZ	L_1230
		CMP	D_Y,12
		JAE	L_1210
		INC	D_Y
		JMP	L_1070
L_1210:
		MOV	D_Y,0
		CMP	D_Z,0
		JNZ	L_1212
		MOV	D_Z,1
		JMP	L_1070
L_1212:
		MOV	D_Z,0
		JMP	L_1070
L_1230:
		CMP	AL,1BH			;ESC?
		JNZ	L_1240
		JMP	L_60
L_1240:
		CMP	AL,' '                  ;�ո�?
		JNZ	L_1250
		CALL	S_1280
		JMP	L_60
L_1250:
		CMP	AL,0A0H 		;�к���?
		JA	L_1260
		JMP	L_1070
L_1260:
		MOV	D_WI,1
		MOV	CX,1
		MOV	AH,9
		INT	10H
		CMP	D_H,0
		JNZ	L_1270
		MOV	D_H,1
		INC	DL
		JMP	L_1080
L_1270:
		MOV	D_H,0
		JMP	L_1070			;ԭΪ1150
;----------------------------------------------------------------------------
L_1330:
		CMP	AL,4			;<������Ƶ>
		JZ	L_1331
		JMP	L_60
L_1331:
		MOV	SI,OFFSET D_MSG5	;������ʾ
		MOV	DX,1802H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_JRSP	;������ʾ
		MOV	DX,409H
		CALL	S_XSZF
		MOV	AL,' '
		MOV	DI,OFFSET D_GPZ2	;������Ƶ�ֱ�����
		MOV	CX,22
		REP	STOSB			;��
L_1360:
		XOR	AH,AH
		INT	16H
		CMP	AL,1BH			;<ESC>
		JZ	L_1362
		CMP	AL,0DH			;�س�
		JNZ	L_1370
L_1362:
		JMP	L_60
L_1370:
		OR	AL,20H			;��д��Сд
		CMP	AL,'a'
		JB	L_1372
		CMP	AL,'z'
		JBE	L_1380
L_1372:
		MOV	AX,0E07H
		JMP	SHORT L_1360
L_1380:
		CALL	S_XSAL
		AND	AL,1FH
		MOV	D_HZM,AL		;����
L_1382:
		XOR	AH,AH
		INT	16H
		CMP	AL,8			;�˸�?
		JNZ	L_1383
		CALL	S_XSAL
		JMP	SHORT L_1360
L_1383:
		CMP	AL,0DH
		JZ	L_1362
		OR	AL,20H			;��д��Сд
		CMP	AL,'a'
		JB	L_1384
		CMP	AL,'z'
		JBE	L_1386
L_1384:
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_1382
L_1386:
		CALL	S_XSAL
		AND	AL,1FH
		MOV	D_HZM[1],AL

		MOV	SI,OFFSET D_11		;'1  2  ..  11'
		MOV	DX,60CH
		MOV	BX,7
		CALL	S_XSZF

		MOV	AL,D_HZM[1]
		MOV	AH,AL
		AND	AL,7
		MOV	CL,5
		SHL	AL,CL
		ADD	AL,D_HZM
		MOV	D_A1,AL
		MOV	CL,3
		SHR	AH,CL
		MOV	D_A2,AH

		XOR	AL,AL
		MOV	D_L,AL
		MOV	D_M,AL
		MOV	D_N,AL

		MOV	CX,0
L_1410:
		MOV	BX,CX
		SHL	BX,1
		ADD	BX,OFFSET D_BUF 	;BUF����ַ
		MOV	AL,[BX]
		CMP	AL,D_A1 		;����1
		JNZ	L_1446
		MOV	AL,[BX+1]
		AND	AL,3
		CMP	AL,D_A2 		;����2
		JNZ	L_1446
		INC	D_N
		MOV	AL,D_N
		XOR	AH,AH
		MOV	DL,31
		DIV	DL
		OR	AH,AH
		JNZ	L_1440
		INC	D_M
		MOV	D_N,0
L_1440:
		MOV	AX,CX
		MOV	DL,94
		DIV	DL
		ADD	AL,16
		MOV	D_Q,AL
		INC	AH
		MOV	D_W,AH

		MOV	DH,D_M
		ADD	DH,9
		MOV	DL,D_N
		SHL	DL,1
		ADD	DL,7
		PUSH	BX
		PUSH	CX
		MOV	BX,7
		MOV	AH,D_Q
		ADD	AH,0A0H
		MOV	AL,D_W
		ADD	AL,0A0H
		CALL	S_XSAX
		POP	CX
		POP	BX
		TEST	BYTE PTR [BX+1],80H	 ;�ж�����Ƶ?
		JNZ	L_1450
L_1446:
		JMP	SHORT L_1460
L_1450:
		MOV	AL,D_L
		CBW
		SHL	AX,1
		MOV	SI,AX
		MOV	AL,D_Q
		ADD	AL,0A0H
		MOV	D_GPZ2[SI],AL
		MOV	AL,D_W
		ADD	AL,0A0H
		MOV	D_GPZ2[SI+1],AL
		INC	D_L
L_1460:
		INC	CX
		CMP	CX,D_ZS
		JA	L_1470
		JMP	L_1410
L_1470:
		MOV	BP,OFFSET D_GPZ2
		MOV	CX,2
		MOV	DX,70CH
		MOV	BX,7
		MOV	SI,11
L_1472:
		MOV	AX,1300H		;��ʾ
		INT	10H
		ADD	BP,2
		ADD	DX,3
		DEC	SI
		JNZ	L_1472

		MOV	SI,OFFSET D_MSG6	;������ʾ
		MOV	DX,1802H
		MOV	BX,1EH
		CALL	S_XSZF

		XOR	AL,AL
		MOV	D_X,AL			;��ֵ
		MOV	D_WI,AL
		MOV	D_H,AL
L_1490:
		MOV	DH,7			;��λ
		MOV	AL,3
		MUL	D_X
		ADD	AL,12
		MOV	DL,AL
		MOV	AH,2
		INT	10H
L_1500:
		XOR	AH,AH			;����
		INT	16H
		CMP	AH,75			;��
		JNZ	L_1540
		CMP	D_X,0
		JZ	L_1532
		DEC	D_X
		JMP	L_1490
L_1532:
		MOV	D_X,10
		JMP	L_1490
L_1540:
		CMP	AH,77			;��
		JNZ	L_1570
L_1541:
		CMP	D_X,10
		JAE	L_1542
		INC	D_X
		JMP	L_1490
L_1542:
		MOV	D_X,0
		JMP	L_1490
L_1570:
		CMP	AL,1BH			;ESC?
		JNZ	L_1580
		JMP	L_1650
L_1580:
		CMP	AL,' '                  ;�ո�
		JNZ	L_1590
		CALL	S_1660			;д�뻺����
		JMP	L_1650
L_1590:
		CMP	AL,0A0H 		;�к���?
		JBE	L_1500

		CMP	D_H,0			;����ǰ�ֽڱ�־
		JNZ	L_1610
		MOV	D_Q,AL
		MOV	D_H,1
		JMP	L_1500
L_1610:
		MOV	D_H,0
		MOV	D_W,AL

		MOV	AL,D_Q
		SUB	AL,176
		MOV	BX,94
		MUL	BL
		MOV	BL,D_W
		SUB	BL,161
		ADD	AX,BX
		SHL	AX,1
		ADD	AX,OFFSET D_BUF
		MOV	BX,AX

		MOV	AL,[BX]
		CMP	AL,D_A1
		JZ	L_1630
		JMP	L_1500
L_1630:
		MOV	AL,[BX+1]
		AND	AL,3
		CMP	AL,D_A2
		JZ	L_1640
		JMP	L_1500
L_1640:
		MOV	D_WI,1
		MOV	SI,OFFSET D_Q
		MOV	BX,4EH
		CALL	S_XSZF
		JMP	L_1541
L_1650:
		MOV	AX,600H 		;�ֲ�����
		XOR	BX,BX
		MOV	CX,402H
		MOV	DX,174DH
		INT	10H
		JMP	L_1331
;============================================================================
;�ӳ���:��ʾAX DX-λ��,BX-����
S_XSAX		PROC	NEAR
		PUSH	AX
		MOV	AL,AH
		CALL	S_XSAX1
		POP	AX
S_XSAX1:
		MOV	AH,2
		INT	10H
		INC	DX
		MOV	CX,1
		MOV	AH,9
		INT	10H
		RET
S_XSAX		ENDP

;�ӳ���:��ʾAL
S_XSAL		PROC	NEAR
		PUSH	DX
		MOV	DL,AL
		MOV	AH,2
		INT	21H
		POP	DX
		RET
S_XSAL		ENDP

;�ӳ���:����Ļ�ϵĶ�����Ƶ�ִ滺����
S_1660		PROC	NEAR
		CMP	D_WI,0			;����д��?
		JNZ	L_1680
		RET
L_1680:
		MOV	CX,0
L_1682:
		MOV	DH,7			;��λ
		MOV	AL,3
		MUL	CL
		ADD	AL,12
		MOV	DL,AL
		XOR	BH,BH
		MOV	AH,2
		INT	10H
		MOV	AH,8			;ȡ��Ļ�ϵĸ�Ƶ��
		INT	10H
		CMP	AL,176			;�к���?
		JBE	L_1700
		MOV	D_Q,AL			;ǰ�ֽ�
		INC	DX
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		CMP	AL,160			;��
		JBE	L_1700
		MOV	D_W,AL			;���ֽ�

		MOV	BX,CX
		SHL	BX,1
		MOV	DH,D_GPZ2[BX]		;ԭ��Ƶ��ǰ�ֽ�
		MOV	DL,D_GPZ2[BX+1] 	;	 ���ֽ�
		CMP	DH,D_Q			;��?
		JNZ	L_1690
		CMP	DL,D_W			;��?
		JZ	L_1700
L_1690:
		CALL	S_1701
		AND	BYTE PTR [BX+1],7FH	;ȥԭ������Ƶλ

		MOV	DH,D_Q
		MOV	DL,D_W
		CALL	S_1701
		OR	BYTE PTR [BX+1],80H	;���¶�����Ƶλ
L_1700:
		INC	CX
		CMP	CX,10
		JBE	L_1682
		RET
S_1701:
		SUB	DH,176
		MOV	AL,94
		MUL	DH
		SUB	DL,161
		XOR	DH,DH
		ADD	AX,DX
		SHL	AX,1
		ADD	AX,OFFSET D_BUF
		MOV	BX,AX
		RET
S_1660		ENDP

;�ӳ���:����Ļ�ϵ�һ����Ƶ�ִ滺����
S_1280		PROC	NEAR
		CMP	D_WI,0
		JNZ	L_1300
		RET
L_1300:
		MOV	CH,0			;��
L_1302:
		MOV	CL,0			;���Ҷ���
L_1304:
		MOV	BX,0			;ÿ��11��
L_1306:
		MOV	AL,13
		MUL	CL
		ADD	AL,CH
		MOV	AH,11
		MUL	AH
		ADD	AX,BX
	;	INC	AX
		SHL	AX,1
		ADD	AX,OFFSET D_GPZQ	;			1.7
		MOV	SI,AX

		MOV	DH,CH
		ADD	DH,5
		MOV	AL,38
		MUL	CL
		MOV	DL,AL
		MOV	AL,3
		MUL	BL
		ADD	AL,6
		ADD	DL,AL
		PUSH	BX
		XOR	BH,BH
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		MOV	[SI],AL
		INC	DX
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		MOV	[SI+1],AL
		POP	BX

		INC	BX
		CMP	BX,10
		JBE	L_1306
		INC	CL
		CMP	CL,1
		JBE	L_1304
		INC	CH
		CMP	CH,12
		JBE	L_1302
		RET
S_1280		ENDP

;�ӳ���:����Ļ�ϵ�ƴ����滺����
S_930		PROC	NEAR
		CMP	D_WI,0
		JNZ	L_950
		RET
L_950:
		XOR	BH,BH
		MOV	AH,3			;ȡ��ǰ���λ��
		INT	10H
		PUSH	DX			;����
		MOV	CH,0
L_952:
		MOV	CL,0
L_954:
		MOV	AL,10
		MUL	CH
		ADD	AL,CL			;K
		OR	AL,AL
		JZ	L_990
		CMP	AL,94
		JA	L_990
		CBW
		DEC	AX
		MOV	BX,AX
		MOV	AL,D_Q			;����
		SUB	AL,16
		MOV	AH,94
		MUL	AH
		ADD	AX,BX			;���
		SHL	AX,1
		ADD	AX,OFFSET D_BUF
		MOV	BX,AX			;�����

		PUSH	BX
		XOR	BX,BX
		MOV	AL,2
		MUL	CH
		ADD	AL,5
		MOV	DH,AL
		MOV	AL,7
		MUL	CL
		ADD	AL,10
		MOV	DL,AL
L_960:
		MOV	AH,2			;��궨λ
		INT	10H
		MOV	AH,8			;ȡ��Ļƴ����
		INT	10H
		SUB	AL,60H
		MOV	D_HZM[BX],AL		;��
		INC	DX
		INC	BX
		CMP	BL,2
		JBE	L_960
		POP	BX

		MOV	DL,[BX+1]
		AND	DL,80H			;B
		MOV	AL,D_HZM[1]		;B(1)
		MOV	DH,AL
		SHL	AL,1			;*32
		SHL	AL,1
		SHL	AL,1
		SHL	AL,1
		SHL	AL,1
		ADD	AL,D_HZM
		MOV	[BX],AL
		SHR	DH,1
		SHR	DH,1
		SHR	DH,1
		MOV	AL,D_HZM[2]
		SHL	AL,1
		SHL	AL,1
		ADD	AL,DH
		OR	AL,DL
		MOV	[BX+1],AL
L_990:
		INC	CL
		CMP	CL,9
		JA	L_991
		JMP	L_954
L_991:
		INC	CH
		CMP	CH,9
		JA	L_992
		JMP	L_952
L_992:
		POP	DX
		XOR	BH,BH
		MOV	AH,2
		INT	10H
		RET
S_930		ENDP

;�ӳ���:���˵���ʾ
S_260		PROC	NEAR
		MOV	AL,D_V1
		MOV	BX,7
		CALL	S_XSCD			;��ʾ�˵���
S_270:
		MOV	AL,D_V
		MOV	BX,4EH
S_XSCD:
		DEC	AX
		MOV	CX,8
		PUSH	AX
		MUL	CL
		ADD	AX,OFFSET D_MAIN
		MOV	BP,AX
		POP	AX
		MOV	AH,12
		MUL	AH
		ADD	AL,5
		MOV	DL,AL
		MOV	DH,1
		MOV	AX,1300H
		INT	10H
		RET
S_260		ENDP

;�ӳ���:������ļ�
S_280		PROC	NEAR
S_300:
		MOV	SI,D_MB 		;��ǰ����ļ�����ַ
		MOV	DI,A_DZ 		;�ļ���д���ַ
L_301:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	L_301
		MOV	DX,OFFSET D_FILE
		MOV	AX,3D02H
		INT	21H
		JNB	L_302
		POP	AX
		MOV	DX,OFFSET NOFILE
		JMP	L_ERR
L_302:
		MOV	D_HAN,AX
		MOV	BX,AX

		CMP	D_MB,OFFSET D_PYMB
		JZ	L_303
		MOV	CX,4
		MOV	DX,OFFSET D_SWMB
		JMP	SHORT L_304
L_303:
		MOV	DX,OFFSET D_GPZQ
		MOV	CX,286*2
L_304:
		MOV	D_LONG,CX
		MOV	AH,3FH
		INT	21H

		MOV	DX,OFFSET D_BUF
		MOV	CX,-1
		MOV	AH,3FH
		INT	21H
		ADD	DX,AX
		MOV	D_END,DX		;�ļ�β��ַ
		SHR	AX,1
		MOV	D_ZS,AX 		;�������
		RET
S_280		ENDP

;�ӳ���:��ʾ�ַ���SI,DX=����λ��,BL=����.��ʾ�����ڴ�β
S_XSZF		PROC	NEAR
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
S_XSZF		ENDP

;�ӳ���:��λ��ʾ�� DX=λ��,CX=��
S_QP		PROC	NEAR
		MOV	AH,2
		INT	10H
		XOR	BX,BX
		MOV	AX,920H
		INT	10H
		RET
S_QP		ENDP

;�ӳ���:����
S_CLS		PROC	NEAR
		MOV	AX,600H
		XOR	BX,BX
		XOR	CX,CX
		MOV	DX,184FH
		INT	10H
		RET
S_CLS		ENDP

;�ӳ���:�������� CX:�ֽ���,����BX
S_INPUT 	PROC	NEAR
		MOV	SI,OFFSET D_INPUT	;���뻺����
		MOV	DI,SI
		ADD	DI,CX
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		XOR	BX,BX
L_IN1:
		XOR	AH,AH			;����
		INT	16H
		CMP	AL,0DH			;�س�?
		JZ	L_IN6
		CMP	AL,1BH			;<ESC>
		JZ	L_IN9
		CMP	AL,8			;�˸�?
		JNZ	L_IN5
		CMP	SI,OFFSET D_INPUT	;ָ��������?
		JA	L_IN3
L_IN2:
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_IN1
L_IN3:
		DEC	SI			;λ��-1
L_IN4:
		CALL	S_XSAL			;�˸�
		CMP	AL,8			;�˸�?
		JNZ	L_IN1
		MOV	CX,1
		MOV	AX,0A20H		;��ʾ�ո�
		INT	10H
		JMP	SHORT L_IN1
L_IN5:
		CMP	AL,'0'                  ;������?
		JB	L_IN1
		CMP	AL,'9'
		JA	L_IN1
		CMP	SI,DI			;������?
		JZ	L_IN2
		MOV	[SI],AL 		;д��
		INC	SI
		JMP	SHORT L_IN4
L_IN6:
		CMP	SI,OFFSET D_INPUT
		JZ	L_IN9
		MOV	BYTE PTR [SI],0
		MOV	SI,OFFSET D_INPUT	;��������
L_IN7:
		LODSB				;ȡ
		OR	AL,AL
		JZ	L_IN9
		AND	AL,0FH
		CBW
		PUSH	AX
		MOV	AX,10
		MUL	BX
		MOV	BX,AX
		POP	AX
		ADD	BX,AX
		JMP	SHORT L_IN7
L_IN9:
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		RET
S_INPUT 	ENDP

D_BUF	EQU	$

CSEG		ENDS
		END	START

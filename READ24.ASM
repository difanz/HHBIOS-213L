;	READ24.ASM (L)
;	1997.7.31
;	1999.11.26

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

D_24T		DB	'HZK24T',34 DUP (0)
D_24S		DB	'HZK24S',34 DUP (0)
D_24F		DB	'HZK24F',34 DUP (0)
D_24H		DB	'HZK24H',34 DUP (0)
D_24K		DB	'HZK24K',34 DUP (0)

		ORG	200H
D_CHKS		DW	0			;�����ֿ�����
D_CHKW		DW	0			;	   β
D_CHKC		DW	0			;������β
D_CHKX		DW	0			;����ָ��

D_DQSQ		DW	0			;��ǰ����
D_DQZK		DW	0			;��ǰ�ֿ�
D_ZFK		DW	OFFSET ZF00		;�ַ�����ַ DS:20CH

D_ZX		DB	0			;����
D_DH		DB	0			;ǰ�ֽ�
D_SX		DB	0			;����
D_HS		DB	0			;����

;�ж����:AH=����,BH=����,DX=��������(�ַ�DH=0)
;BL=����:λ0-����,λ1-�»�,λ2-�ϻ�,λ3-����,λ4-����,λ5-�ϱ�,λ6-�±�,λ7-��ת
;����:DS:SI=�����׵�ַ,CX=����(ÿ��3�ֽ�)

		DB	'24'                    ;פ����־
INT_7B		PROC	FAR
		STI
		CLD
		PUSH	ES
		PUSH	DI
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	D_ZX,AH 		;����
		MOV	D_DH,DH 		;ǰ�ֽ�
		MOV	WORD PTR D_SX,BX	;���Լ�����

		OR	DH,DH			;�к���
		JNZ	L_10
		AND	DL,7FH
		MOV	AL,36			;ÿ�ַ�36�ֽ�
		MUL	DL
		ADD	AX,D_ZFK		;+�ַ���������
		MOV	SI,AX			;ָ���ַ�����
		MOV	CX,12
		JMP	L_50
L_10:	;ȡ��������
		MOV	AL,AH
		AND	AL,0F0H
		CMP	AL,10H			;�и�����?
		JNZ	L_12
		SHL	AH,1			;λ01��λ23
		SHL	AH,1
L_12:
		TEST	AH,20H			;������
		JNZ	L_14
		AND	DH,7FH
L_14:
		TEST	AH,10H
		JNZ	L_20
		AND	DL,7FH
L_20:
		CALL	S_GET			;ȡ�ú��ֵ���DS:SI

		MOV	CX,24
	;��ת����
		CMP	D_DH,0A9H		;�о���?
		JZ	L_50
		TEST	D_SX,8			;����?
		JZ	L_40
		XOR	DI,DI
		ADD	SI,45H
		MOV	CL,3
L_32:
		PUSH	CX
		MOV	CL,8
L_34:
		PUSH	SI
		MOV	DH,3
L_36:
		MOV	DL,8
L_38:
		MOV	AL,[SI]
		SHR	AL,CL
		RCL	BL,1
		SUB	SI,3
		DEC	DL
		JNZ	L_38
		MOV	AL,BL
		STOSB
		DEC	DH
		JNZ	L_36
		POP	SI
		LOOP	L_34
		INC	SI
		POP	CX
		LOOP	L_32
		XOR	SI,SI
		MOV	CL,24
		JMP	SHORT L_60
L_40:
		TEST	D_SX,10H		  ;����?
		JZ	L_50
		XOR	DI,DI
		INC	SI
		INC	SI
		MOV	CL,3
L_42:
		PUSH	CX
		MOV	CL,8
L_44:
		PUSH	SI
		MOV	DH,3
L_46:
		MOV	DL,8
L_48:
		MOV	AL,[SI]
		SHL	AL,CL
		RCL	BL,1
		ADD	SI,3
		DEC	DL
		JNZ	L_48
		MOV	AL,BL
		STOSB
		DEC	DH
		JNZ	L_46
		POP	SI
		LOOP	L_44
		DEC	SI
		POP	CX
		LOOP	L_42
		XOR	SI,SI
		MOV	CL,24
		JMP	SHORT L_60
L_50:	;�����͵�DS:0
		OR	SI,SI
		JZ	L_60
		PUSH	CX
		MOV	AX,CX
		SHL	AX,1
		ADD	CX,AX
		XOR	DI,DI
		REP	MOVSB
		XOR	SI,SI
		POP	CX
L_60:
		TEST	D_SX,80H		;��ת?
		JZ	L_63
		MOV	DI,80H+72-3		;1.12
		PUSH	CX
L_61:
		LODSB
		CALL	S_FW			;��λ
		MOV	[DI+2],AH
		LODSB
		CALL	S_FW			;��λ
		MOV	[DI+1],AH
		LODSB
		CALL	S_FW			;��λ
		MOV	[DI],AH
		SUB	DI,3
		DEC	CL
		JNZ	L_61
		POP	CX
		MOV	SI,80H
		AND	D_SX,7FH
		JMP	SHORT L_50
L_63:
		TEST	D_SX,20H		;�ϱ�?
		JZ	L_70
		PUSH	CX
		XOR	DI,DI
L_64:
		LODSW
		CALL	S_YS			;ѹ��
		LODSB
		XOR	AH,AH
		CALL	S_YS			;ѹ��
		XOR	AL,AL
		STOSB
		LOOP	L_64
		POP	CX
		XOR	SI,SI
		JMP	SHORT L_80
L_70:
		TEST	D_SX,40H		;�±�?
		JZ	L_80
		PUSH	CX
		MOV	DI,80H
L_74:
		XOR	AL,AL
		STOSB
		LODSB
		XOR	AH,AH
		CALL	S_YSAX			;ѹ��
		LODSW
		CALL	S_YS			;ѹ��
		LOOP	L_74
		POP	CX
		MOV	SI,80H
		AND	D_SX,0BFH
		JMP	L_50
L_80:
		TEST	D_SX,2			;�ϻ���?
		JZ	L_90
		PUSH	CX
		XOR	BX,BX
L_84:
		OR	BYTE PTR [BX],80H
		ADD	BX,3
		LOOP	L_84
		POP	CX
L_90:
		TEST	D_SX,4			;�»���?
		JZ	L_100
		PUSH	CX
		MOV	BX,2
L_94:
		OR	BYTE PTR [BX],1
		ADD	BX,3
		LOOP	L_94
		POP	CX
L_100:
		MOV	AL,D_ZX
		AND	AL,0F0H
		CMP	AL,10H			;������?
		JNZ	L_104
		TEST	D_ZX,3			;����չ?
		JNZ	L_110
		XOR	BX,BX
		XOR	DI,DI
L_102:
		LODSB
		STOSB
		LODSW
		STOSW
		INC	BX
		LODSB
		OR	AL,[SI+2]
		STOSB
		LODSW
		OR	AX,[SI+1]
		STOSW
		INC	BX
		ADD	SI,3
		DEC	CX
		DEC	CX
		LOOP	L_102
		MOV	CX,BX
		XOR	SI,SI
		JMP	L_140
L_104:
		JMP	L_150
L_110:
		TEST	D_ZX,2			;����?
		JZ	L_130
		XOR	DI,DI
		CMP	D_HS,1			;�ϰ���?
		JNZ	L_120
		PUSH	CX
L_112:
		LODSB
		XOR	AH,AH
		CALL	S_K24			;��24
		ADD	SI,2
		LOOP	L_112
		POP	CX
		XOR	SI,SI
		JMP	SHORT L_130
L_120:
		PUSH	CX			;�°���
L_122:
		INC	SI
		LODSW
		XCHG	AL,AH
		CALL	S_K24			;��24
		LOOP	L_122
		POP	CX
		XOR	SI,SI
L_130:
		TEST	D_ZX,1			;����?
		JZ	L_140
		XOR	BX,BX
		MOV	DI,80H
L_132:
		LODSB
		STOSB
		LODSW
		STOSW
		INC	BX
		LODSB
		STOSB
		MOV	[DI+2],AL
		LODSW
		STOSW
		MOV	[DI+1],AX
		INC	BX
		INC	BX
		ADD	DI,3
		DEC	CX
		LOOP	L_132
		MOV	SI,80H
		MOV	CX,BX
L_140:
		AND	D_ZX,0F0H
L_150:
		MOV	AH,D_ZX 		;�ָ�����
		POP	DI
		POP	ES
		IRET
INT_7B		ENDP

;�ӳ���:�ֽڷ�λAL->AH
S_FW		PROC	NEAR
		MOV	CH,8
L_FW1:
		SHR	AL,1
		RCL	AH,1
		DEC	CH
		JNZ	L_FW1
		RET
S_FW		ENDP

;�ӳ���:AL:AHѹ��
S_YS		PROC	NEAR
		XCHG	AL,AH
;�ӳ���:AXѹ��Ϊ8λ->ES:DI
S_YSAX:
		MOV	DL,8
L_YS1:
		SHL	AX,1
		JNB	L_YS2
		RCL	BL,1
		SHL	AX,1
		JMP	SHORT L_YS3
L_YS2:
		SHL	AX,1
		RCL	BL,1
L_YS3:
		DEC	DL
		JNZ	L_YS1
		MOV	AL,BL
		STOSB
		RET
S_YS		ENDP

;�ӳ���:AX��3�ֽ�->ES:DI
S_K24		PROC	NEAR
		PUSH	CX
		MOV	BX,AX
		MOV	CL,5
		CALL	S_K24A
		PUSH	BX
		RCL	BX,1
		RCL	AX,1
		PUSH	AX
		MOV	AL,AH
		STOSB
		POP	AX
		STOSB
		POP	BX
		XOR	AX,AX
		RCL	BX,1
		RCL	AL,1
		RCL	BX,1
		RCL	AL,1
		MOV	CL,2
		CALL	S_K24A
		STOSB
		POP	CX
		RET
;�ӳ���:AX<-BX��1λ��1λ��CX��
S_K24A:
		RCL	BX,1
		PUSHF
		RCL	AX,1
		POPF
		RCL	AX,1
		RCL	BX,1
		RCL	AX,1
		LOOP	S_K24A
		RET
S_K24		ENDP

	INCLUDE ZF00.INC
	INCLUDE ZF3.INC

;�ӳ���:ȡ�ú��ֵ��� DX=���κ�������,����:SI=���ֵ����ַ
S_GET		PROC	NEAR
		MOV	SI,D_CHKS		;�����ֿ�����
		JMP	SHORT L_GET2
L_GET1:
		ADD	SI,72
L_GET2:
		CMP	SI,D_CHKC		;�д�����β?
		JNZ	L_GET5
		CALL	S_READ			;���ֿ�

		CMP	DI,D_CHKC		;��д���ַ>�����ֿ������β?
		JBE	L_GET3
		MOV	D_CHKC,DI
L_GET3:
		CMP	DI,D_CHKW		;��д���ַ=�����ֿ���β?
		JNZ	L_GET4
		MOV	DI,D_CHKS
L_GET4:
		MOV	D_CHKX,DI		;��д���ַ
		RET
L_GET5:
		LODSW				;ȡ�����ֿ⺺����?
		CMP	AX,DX			;��?
		JNZ	L_GET1
		RET
S_GET		ENDP

D_T		DW	OFFSET D_BUFF		;T����
D_512		DW	0			;�����ֽ���
D_440		DW	0			;�����ֽ���-72
D_S		DW	0			;S��
D_F		DW	0			;F��
D_H		DW	0			;H��
D_K		DW	0			;K��
D_SECD		DW	0			;ÿ��������
D_CTS		DW	0			;��ͷ��
D_DQP		DB	2			;��ǰ��
D_SSEC		DW	0			;������������
D_SCZH		DW	0			;      ������
;	DS:[0F0H]				;ÿ��������
;	DS:[0F4H]				;�ļ�����������
;	DS:[0F6H]				;���������
;	DS:[0F8H]				;��һFAT����
;	DS:[0FAH]				;�ڶ�FAT����
;	DS:[0FFH]				;������־(1=12λ,����16λ)

;�ӳ���:���ֿ�
S_READ		PROC	NEAR
		MOV	DI,D_CHKX		;����ָ��
		MOV	AX,DX
		STOSW				;д��
		PUSH	DI
		PUSH	AX
		AND	AH,7FH
		CMP	AH,30H			;��16��?
		POP	AX
		JNB	L_R1
		MOV	AX,D_T			;T��
		JMP	SHORT L_R2
L_R1:
		SUB	DH,15
		XOR	BX,BX
		SHL	AH,1
		RCL	BX,1
		SHL	AL,1
		RCL	BX,1
		SHL	BX,1
		MOV	AX,D_S[BX]		;ȡ��Ӧ��
L_R2:
		MOV	D_DQZK,AX		;��ǰ��
		AND	DX,7F7FH
		SUB	DX,2121H
		MOV	AL,94
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX			;�������
		MOV	DX,72
		MUL	DX			;�ֽ�λ��
		DIV	D_512			;�����ֽ���
		PUSH	DX
		MOV	D_DQSQ,AX		;��ǰ������
		CALL	S_READSEC		;������
		POP	SI
		MOV	CX,72
		CMP	SI,D_440		;�������ֽ���-72��
		JB	L_R3
		MOV	CX,D_512		;�����ֽ���
		SUB	CX,SI
L_R3:
		POP	DI
		PUSH	DI
		PUSH	CX
		REP	MOVSB			;����
		POP	CX
		CMP	CX,72			;���Ƿ����?
		JZ	L_R4
		PUSH	CX
		PUSH	DI
		MOV	AX,D_DQSQ		;��ǰ����
		INC	AX			;��һ����
		CALL	S_READSEC		;������
		POP	DI
		POP	AX
		XOR	SI,SI
		MOV	CX,72
		SUB	CX,AX
		REP	MOVSB			;����
L_R4:
		POP	SI
		RET
;�ӳ���:������ AX=˳���
S_READSEC:
		MOV	BX,D_DQZK		;��ǰ��
L_RS1:
		CMP	AX,[BX+4]
		JB	L_RS2
		SUB	AX,[BX+4]
		ADD	BX,6
		JMP	SHORT L_RS1
L_RS2:
		MOV	DX,[BX+2]
		ADD	AX,[BX]
		ADC	DX,0
		DIV	D_SECD			;ÿ��������
		ADD	DX,D_SSEC		;�ӷ�����������
		CMP	DX,D_SECD
		JBE	L_RS3
		MOV	DL,1
		INC	AX
L_RS3:
		MOV	CL,DL			;������
		XOR	DX,DX
		DIV	D_CTS			;��ͷ��
		MOV	DH,DL
		ADD	AX,D_SCZH		;�ӷ����״�����
		MOV	CH,AL			;������
		MOV	AL,40H
		MUL	AH			;AH����6λ
		ADD	CL,AL			;�ӵ�CL��
		MOV	DL,80H
		XOR	BX,BX
		MOV	AX,201H
		INT	13H			;������
		RET
S_READ		ENDP

D_BUFF		EQU	$

		ORG	$+400H
;****************************************************************************
BEGIN:
		MOV	AX,357BH		;ȡINT7B�ж�
		INT	21H
		CMP	WORD PTR ES:[BX-2],'42' ;�а�װ?
		JNZ	L_S10
		MOV	DX,OFFSET ALREADY
L_ERR:
		MOV	AH,9
		INT	21H
		MOV	AX,4C01H
		INT	21H
L_S10:
		PUSH	CS
		POP	ES
		MOV	AH,19H			;ȡ��ǰ��
		INT	21H
		ADD	CUR_DRIVE,AL
		MOV	FCB_DRIVE,AL
		INC	AL
		MOV	DL,AL
		MOV	SI,OFFSET CUR_PATH
		MOV	AH,47H			;ȡ��ǰ·��->DS:SI
		INT	21H

		CALL	S_GETPATH		;ȡ����������·��

		MOV	SI,5DH
		MOV	AX,CS
		CMP	AX,0A000H		;��LH
		JB	L_S11
		MOV	SI,6DH
L_S11:
		LODSB
		AND	AL,5FH
		MOV	DS:[101H],AL		;����
		PUSH	SI
		LODSB				;'S'
		CMP	BYTE PTR [SI],' '
		JZ	L_S12
		LODSB				;'F'
		CMP	BYTE PTR [SI],' '
		JZ	L_S13
		LODSB				;'H'
		CMP	BYTE PTR [SI],' '
		JZ	L_S14
		JMP	SHORT L_S15
L_S12:
		MOV	[SI],AL
		INC	SI
L_S13:
		MOV	[SI],AL
		INC	SI
L_S14:
		MOV	[SI],AL
L_S15:
		POP	SI

		CMP	BYTE PTR DS:[101H],'W'  ;='W':���ļ���ʽ���ֿ�?
		JZ	L_S18
		JMP	L_S40
L_S18:	;READ24W-------------------------------------------------------------
		LODSB
		MOV	F_24S+5,AL
		LODSB
		MOV	F_24F+5,AL
		LODSB
		MOV	F_24H+5,AL
		LODSB
		MOV	F_24K+5,AL

		MOV	SI,OFFSET F_24T 	;Դ�ļ���
		MOV	DI,OFFSET D_24T 	;�����ļ���
		MOV	BP,5
L_S24:
		PUSH	DI
		PUSH	SI
		MOV	SI,OFFSET F_S
		CALL	S_MOVE			;����·��
		DEC	DI
		MOV	AL,'\'
		STOSB
		POP	SI
		CALL	S_MOVE			;�����ļ���
		POP	DI
		ADD	DI,40
		DEC	BP
		JNZ	L_S24

		MOV	DX,OFFSET D_24T
		MOV	AX,4300H		;ȡT������
		INT	21H
		JNB	L_S33
L_S31:
		MOV	AX,4CFFH
		INT	21H
L_S33:
		MOV	DX,OFFSET D_24S
		MOV	AX,4300H		;ȡS������
		INT	21H
		JB	L_S31
		MOV	DX,OFFSET D_24F
		MOV	AX,4300H		;ȡF������
		INT	21H
		JB	L_S31
		MOV	DX,OFFSET D_24H
		MOV	AX,4300H		;ȡH������
		INT	21H
		JB	L_S31
		MOV	DX,OFFSET D_24K
		MOV	AX,4300H		;ȡK������
		INT	21H
		JB	L_S31

		MOV	SI,OFFSET S_GET1
		MOV	DI,OFFSET S_GET
		MOV	CX,OFFSET K_GET1
		SUB	CX,SI
		REP	MOVSB			;����READ24Wȡ�����ӳ���
		MOV	D_CHKS,DI		;������������		10.29
		ADD	DI,72
		MOV	BP,DI			;פ����ַ
		JMP	L_S100

L_S40:	;READ24--------------------------------------------------------------
		MOV	DL,FCB_DRIVE
		INC	DL
		MOV	AH,36H			;ȡ������Ϣ
		INT	21H
		CMP	AX,-1			;���̲�����?
		JNZ	L_S41
		JMP	L_S73			;פ�����ж�
L_S41:
		CMP	AX,4			;<4:�����̻����?
		JAE	L_S42
		JMP	L_S18			;���ļ���ʽ
L_S42:
		MOV	DI,OFFSET F_S		;������·��
		MOV	DL,[DI] 		;ȡ�̷�
		AND	DL,5FH
		SUB	DL,'A'

		CMP	DL,1			;��Ӳ��?
		JA	L_S46
L_S44:
		MOV	DX,OFFSET NOPATH	;'�ֿⲻ��!'
		JMP	L_ERR
L_S46:
		MOV	AH,0EH			;�õ�ǰ��
		INT	21H
L_S48:
		MOV	DX,DI
		MOV	AH,3BH			;���ֿ�·��
		INT	21H
		JB	L_S44
L_S50:
		MOV	AH,19H			;ȡ��ǰ��
		INT	21H
		MOV	D_DQP,AL		;��ǰ�̺�
		INC	AL
		MOV	D_FCB,AL

		MOV	AX,201H 		;��C����������
		MOV	BX,OFFSET D_BUF+100H
		MOV	CX,1
		MOV	DX,80H
		PUSH	CX
		INT	13H
		POP	CX

		DEC	D_DQP
L_S52:
		DEC	D_DQP
		JZ	L_S54
		CALL	READBOOT		;����һ����BOOT
		JMP	SHORT L_S52
L_S54:
		PUSH	CX
		MOV	DL,CH			;�����ŵ�8λ
		XOR	CH,CH
		SHL	CX,1			;�����Ÿ�2λ��CH
		SHL	CX,1
		MOV	DH,CH
		POP	CX
		AND	CX,3FH
		MOV	D_SSEC,CX		;������������
		MOV	D_SCZH,DX		;      ������

		MOV	SI,1BEH
L_S56:
		MOV	AL,DS:[BX+SI+4]
		CMP	AL,1			;��12λFAT DOS����
		JZ	L_S58
		CMP	AL,4			;��16λFAT DOS����
		JZ	L_S58
		CMP	AL,6			;�д�Ӳ��DOS����
		JZ	L_S58
		ADD	SI,10H
		JMP	SHORT L_S56
L_S58:
		MOV	DS:[0FFH],AL
		MOV	CX,[BX+SI+2]
		MOV	DX,[BX+SI]
		OR	DL,80H
		MOV	AX,201H
		PUSH	CX
		INT	13H			;��DOS��������
		POP	CX

		PUSH	DX
		MOV	AX,[BX+0BH]		;�����ֽ���
		MOV	D_512,AX
		SUB	AX,72
		MOV	D_440,AX
		MOV	AX,[BX+18H]		;ÿ��������
		MOV	D_SECD,AX
		MOV	AX,[BX+1AH]		;��ͷ��
		MOV	D_CTS,AX
		MOV	AL,[BX+0DH]		;ÿ��������
		XOR	AH,AH
		MOV	DS:[0F0H],AX
		MOV	AX,[BX+16H]		;FAT������
		MUL	BYTE PTR [BX+10H]	;*FAT����
		ADD	AX,[BX+0EH]		;+����������
		ADD	AX,[BX+1CH]		;+����������
		MOV	DS:[0F4H],AX		;Ŀ¼��������
		MOV	AX,20H
		MUL	WORD PTR [BX+11H]	;��Ŀ¼����
		DIV	D_512			;=��Ŀ¼������
		ADD	DS:[0F4H],AX		;=�ļ�����������
		POP	DX

		MOV	AX,CS
		CMP	AX,0A000H		;��UMB?
		JB	L_S62
		PUSH	BX
		MOV	AH,52H			;ȡDOS�ڲ���
		INT	21H
		MOV	AX,ES:[BX-2]		;�ڴ�������׶�
		POP	BX
L_S60:
		MOV	ES,AX
		INC	AX
		ADD	AX,ES:[3]
		CMP	AX,7000H
		JB	L_S60
		SUB	AX,ES:[3]		;�����ڴ����ɿ�
L_S62:
		ADD	AX,1000H
		MOV	DS:[0F8H],AX
		MOV	ES,AX
		ADD	AX,1000H
		MOV	DS:[0FAH],AX

		MOV	AX,[BX+16H]		;ÿFAT������
		PUSH	AX
		CMP	AX,80H			;		4.8
		JBE	L_S64
		MOV	AL,80H
L_S64:
		XOR	BX,BX
		INC	CX
		MOV	AH,2
		PUSH	CX
		INT	13H			;��FAT
		POP	CX
		ADD	CL,80H
		MOV	AL,CL
		XOR	AH,AH
		DIV	BYTE PTR D_SECD 	;ÿ��������
		MOV	CL,AH
		ADD	AL,DH
		XOR	AH,AH
		DIV	BYTE PTR D_CTS		;��ͷ��
		MOV	DH,AH
		ADD	CH,AL

		POP	AX
		CMP	AX,80H			;		   4.8
		JBE	L_S70
		SUB	AL,80H
		MOV	ES,DS:[0FAH]
		XOR	BX,BX
		MOV	AH,2
		INT	13H
L_S70:
		MOV	SI,5DH
		MOV	AX,CS
		CMP	AX,0A000H		;��LH	4.8
		JB	L_S72
		MOV	SI,6DH
L_S72:
		LODSB
		MOV	DS:[100H],AL		;�����ֿ�����С

		MOV	ES,DS:[0F8H]		;ָ��FAT��
		MOV	BP,D_T			;T��
		CALL	S_SET1
		JNC	L_S74
L_S73:
		CALL	S_HF			;�ָ���ǰ�̺�·��
		MOV	AX,4CFFH
		INT	21H
L_S74:
		MOV	D_S,BP			;S��
		LODSB
		CALL	S_SET
		JC	L_S73
		MOV	D_F,BP			;F��
		LODSB
		CALL	S_SET
		MOV	D_H,BP			;H��
		LODSB
		CALL	S_SET
		MOV	D_K,BP			;K��
		LODSB
		CALL	S_SET
		MOV	D_CHKS,BP		;9.25
		MOV	D_CHKC,BP
		MOV	D_CHKX,BP

		MOV	AL,DS:[100H]
		CMP	AL,'A'
		JB	L_S80
		SUB	AL,7
L_S80:
		SUB	AL,'0'
		XOR	AH,AH
		MOV	DX,50*74		;50�֡�74�ֽ�
		MUL	DX
		ADD	AX,D_CHKS
		MOV	D_CHKW,AX
		INC	AX
		MOV	BP,AX			;BP:פ����ַ

L_S100: ;פ������------------------------------------------------------------
		MOV	AX,CS
		CMP	AX,0A000H		;��LH?
		JA	L_S130
		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_S120
L_S110:
		LODSB
		CMP	AL,0DH
		JZ	L_S120
		CMP	AL,'/'
		JNZ	L_S110
		LODSB
		AND	AL,5FH
		CMP	AL,'N'                  ;/N:פ�������ڴ�
		JNZ	L_S110
		JMP	SHORT L_S130
L_S120:
		CALL	S_GETUMB		;����UMB��
		JZ	L_S140
L_S130:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;�廷����
		INT	21H
		CALL	S_SETINT
		MOV	DX,BP			;פ��
		INT	27H
L_S140:
		MOV	AX,D_UMB
		OR	AX,AX
		JZ	L_S130
		DEC	AX
		MOV	ES,AX
		MOV	DI,8
		MOV	SI,OFFSET D_NAME
		MOV	CX,7
		REP	MOVSB		       ;��UMB�ļ����ƿ�д�뱾ģ����

		MOV	ES,D_UMB		;��
		XOR	SI,SI
		MOV	DI,SI
		MOV	CX,BP			;			10.29
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

;�ӳ���:ȡUMB��
S_GETUMB	PROC	NEAR
		CALL	S_GETXMS		;ȡXMS������ַ
		JNZ	L_GU2
		MOV	AX,BP
		MOV	CL,4
		SHR	AX,CL
		INC	AX
		MOV	D_LEN,AX		;��ģ��פ������(��)

		MOV	AH,10H			;����UMB
		CALL	D_XMS			;XMS
		CMP	AX,1			;=1:�ɹ�,BX=��
		JZ	L_GU1
		CALL	S_UMB			;����UMB��BX
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
		MOV	DX,OFFSET INT_7B
		MOV	AX,257BH		;���ж�
		INT	21H
		CALL	S_HF			;�ָ���ǰ�̺�·��
		RET
S_SETINT	ENDP

;READ24��--------------------------------------------------------------------
;���ӳ���:�ָ���ǰ�̼�·����
S_HF		PROC	NEAR
		PUSH	CS			;			6.18
		POP	DS
		MOV	DX,OFFSET CUR_DRIVE
		MOV	AH,3BH			;�õ�ǰ·��
		INT	21H
		MOV	DL,FCB_DRIVE
		MOV	AH,0EH			;�õ�ǰ��
		INT	21H
		RET
S_HF		ENDP

;�ӳ���:���ֿ���
S_SET		PROC	NEAR
		MOV	D_FCB+6,AL
;�ӳ���:���ֿ�����������
S_SET1:
		MOV	DX,OFFSET D_BUF
		MOV	DI,DX
		MOV	AH,1AH			;��DTA��ַ
		INT	21H
		MOV	DX,OFFSET D_FCB
		MOV	AH,11H			;����Ŀ¼��
		INT	21H
		OR	AL,AL
		JZ	L_SET1
		STC
		RET
L_SET1:
		MOV	AX,[DI+1BH]		;�״غ�
		PUSH	AX
		SUB	AX,2
		MUL	WORD PTR DS:[0F0H]	;ÿ��������
		ADD	AX,DS:[0F4H]		;�ļ�����������
		ADC	DX,0
		MOV	DS:[BP],AX		;����
		MOV	DS:[BP+2],DX
		POP	AX
		MOV	WORD PTR DS:[0F6H],0	;����������������
L_SET2:
		PUSH	AX
		INC	WORD PTR DS:[0F6H]	;��������+1
		MOV	BX,AX
		CMP	BYTE PTR DS:[0FFH],1	;��12λFAT?
		JZ	L_SET4
		MOV	ES,DS:[0F8H]
		ADD	BX,AX
		JNC	L_SET3
		MOV	ES,DS:[0FAH]
L_SET3:
		MOV	AX,ES:[BX]
		CMP	AX,0FFF8H
		JMP	SHORT L_SET7
L_SET4:
		SHR	AX,1
		PUSHF
		ADD	BX,AX
		MOV	AX,ES:[BX]
		POPF
		JNB	L_SET5
		MOV	CL,4
		SHR	AX,CL
		JMP	SHORT L_SET6
L_SET5:
		AND	AX,0FFFH
L_SET6:
		CMP	AX,0FF8H
L_SET7:
		POP	BX
		JB	L_SET8			;�н���?
		MOV	AX,0FFFFH
		MOV	DS:[BP+4],AX		;β���־
		ADD	BP,6
		CLC
		RET
L_SET8:
		INC	BX
		CMP	AX,BX			;������?
		JZ	L_SET2
		PUSH	AX
		MOV	AX,DS:[0F0H]		;ÿ��������
		MUL	WORD PTR DS:[0F6H]	;*��������
		MOV	DS:[BP+4],AX
		MOV	WORD PTR DS:[0F6H],0	;��
		MOV	AX,DS:[0F0H]
		POP	BX
		PUSH	BX
		SUB	BX,2
		MUL	BX
		ADD	AX,DS:[0F4H]
		ADC	DX,0
		ADD	BP,6
		MOV	DS:[BP],AX
		MOV	DS:[BP+2],DX
		POP	AX
		JMP	SHORT L_SET2
S_SET		ENDP

;�ӳ���:����һ����BOOT
READBOOT	PROC	NEAR
		MOV	SI,1BEH 		;��������
L_RB1:
		CMP	BYTE PTR [BX+SI+4],5	;����չ����
		JZ	L_RB2
		ADD	SI,10H			;ת��һ����
		JMP	SHORT L_RB1
L_RB2:
		MOV	CX,[BX+SI+2]
		MOV	DX,[BX+SI]
		OR	DL,80H
		MOV	AX,201H
		INT	13H			;����һ����BOOT
		RET
READBOOT	ENDP

FCB_DRIVE	DB	2
CUR_DRIVE	DB	'A:\'
CUR_PATH	DB	64 DUP(0)

D_FCB		DB	3,'HZK24T     ',25 DUP(0)    ;�ֿ�FCB

;READ24W��-------------------------------------------------------------------
;�ӳ���:���ֿ� DX=���κ�������,����:SI=���ֵ����ַ
S_GET1		PROC	NEAR
		CMP	DX,D_DQSQ		;���ϴ��Ѷ���?
		JZ	L_GET13
		MOV	AH,62H			;ȡ��ǰPSP		10.29
		INT	21H
		PUSH	BX
		MOV	AX,DX
		MOV	D_DQSQ,AX		;����
		AND	DX,7F7FH
		PUSH	AX
		AND	AH,7FH
		CMP	AH,30H			;��<16��?
		POP	AX
		JNB	L_GET11
		MOV	SI,OFFSET D_24T 	;T��
		JMP	SHORT L_GET12
L_GET11:
		SUB	DH,0FH			;����-15
		XOR	BL,BL
		SHL	AH,1
		RCL	BL,1
		SHL	AL,1
		RCL	BL,1			;�ֿ����
		MOV	AL,40
		MUL	BL
		ADD	AX,OFFSET D_24S
		MOV	SI,AX			;ָ���ֿ�FCB
L_GET12:
		SUB	DX,2121H
		MOV	AL,94
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX			;�������
		MOV	DX,72
		MUL	DX
		PUSH	AX
		PUSH	DX
		MOV	DX,SI
		MOV	AX,3D00H		;���ֿ��ļ�
		INT	21H
		MOV	BX,AX
		POP	CX
		POP	DX
		MOV	AX,4200H		;�ƶ�ָ��
		INT	21H
		MOV	DX,D_CHKS		;������ 		10.29
		MOV	CX,72
		MOV	AH,3FH			;���ļ�
		INT	21H
		MOV	AH,3EH			;�ر�
		INT	21H
		POP	BX
		MOV	AH,51H			;�ָ�ԭPSP		10.29
		INT	21H
L_GET13:
		MOV	SI,D_CHKS		;������ 		10.29
		RET
S_GET1		ENDP
K_GET1	EQU	$

F_24T		DB	'HZK24T',0
F_24S		DB	'HZK24S',0
F_24F		DB	'HZK24F',0
F_24H		DB	'HZK24H',0
F_24K		DB	'HZK24K',0

;��������--------------------------------------------------------------------
;�ӳ���:ȡ����������·��
S_GETPATH	PROC	NEAR
		MOV	DS,DS:[2CH]		;������
		XOR	SI,SI
L_GP1:
		CMP	WORD PTR DS:[SI],0	;���һ�����β?
		JZ	L_GP2
		INC	SI
		JMP	SHORT L_GP1
L_GP2:
		ADD	SI,4
		MOV	DI,OFFSET F_S		;��·��Դ�ļ�����
		PUSH	CS
		POP	ES
		CMP	BYTE PTR [SI+1],':'     ;�����̷�?
		JZ	L_GP3
		MOV	AH,19H			;ȡ��ǰ��
		INT	21H
		INC	AL
		MOV	DL,AL
		OR	AL,40H
		STOSB				;д���̷�
		MOV	AL,':'
		STOSB
		CMP	BYTE PTR [SI],'\'       ;���о���·��?
		JZ	L_GP3
		MOV	AL,'\'
		STOSB
		JMP	SHORT L_GP4
L_GP3:
		CMP	BYTE PTR [SI+2],'\'     ;���о���·��?
		JZ	L_GP5
		LODSW				;�̷���\
		MOV	DL,AL			;�̷�
		SUB	DL,40H
		STOSW
L_GP4:
		PUSH	SI
		MOV	SI,DI
		MOV	AH,47H			;ȡ��ǰ·��
		INT	21H
		POP	SI
L_GP5:
		CALL	S_MOVE			;����
		PUSH	CS
		POP	DS
L_GP6:
		CMP	BYTE PTR [DI],'\'       ;���һ��\
		JZ	L_GP7
		DEC	DI
		JMP	SHORT L_GP6
L_GP7:
		MOV	BYTE PTR [DI],0
		RET
S_MOVE:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	S_MOVE
		RET
S_GETPATH	ENDP

D_NAME		DB	'READ24',0
ALREADY 	DB	'��ģ�� READ24 �Ѿ�פ��!',7,13,10,'$'
NOPATH		DB	'�ֿⲻ��!',7,13,10,'$'
F_S		DB	40 DUP(0)

D_BUF		EQU	$

SEG_A		ENDS
		END	START

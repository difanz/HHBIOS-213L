;	LHELP.ASM
;	1997.2.20, 3.21, 6.29, 7.31
;	1998.4.8
;	1999.1.13

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

D_FILE		DW	0			;�ļ�����
D_MODE		DB	0			;��ʾ��ʽ
D_WIN		DB	0			;��ǰ���ں�
D_B1		DB	'�ͻ',0
D_B2		DB	'� �',0
D_B3		DB	'�ͼ',0
D_CDXZ		DB	4FH			;�˵�ѡ��ɫ
D_TS		DB	' ALT+ר�ü���| ���-�ƶ�,����:INS+,DEL-.ǰ��:HOME+,END-.�߿�:PGUP+,PGDN-,����:+',0
D_ALT		DB	0			;����ALT��־
K_NUM		DB	14			;�Ӵ�����
H_MAIN		DB	1			;���˵���ǰ��

K_MAIN		DB	1EH			;���˵�����ɫ
		DB	1EH			;����ɫ
		DW	1218H			;���˵����ڴ�С
		DW	204H			;	   ���Ͻ�λ��

K_ZFB		DB	6FH			;�ַ���
		DB	6EH
		DW	1325H
		DW	410H

K_KZASC 	DB	57H			;��չASC��
		DB	5AH
		DW	182FH
		DW	18H

K_GQHZ		DB	61H			;��������
		DB	6BH
		DW	0E28H
		DW	610H

K_SPDM		DB	4AH			;˫ƴ����
		DB	4EH
		DW	122FH
		DW	315H

K_YS		DB	2AH			;ǰ��������ɫ
		DB	2FH
		DW	133DH
		DW	410H

K_XSFS		DB	67H			;��ʾ��ʽ
		DB	6FH
		DW	946H
		DW	808H

K_SLZT		DB	52H			;ʸ������
		DB	5EH
		DW	1130H
		DW	515H

K_ZXZH		DB	21H			;�����ֺ�
		DB	2FH
		DW	174AH
		DW	103H

K_XTPB		DB	4FH			;ϵͳ�Ű�
		DB	4EH
		DW	183FH
		DW	0AH

K_TSXS		DB	1EH			;������ʾ
		DB	1FH
		DW	144DH
		DW	101H

K_TSDY		DB	1EH			;�����ӡ
		DB	1FH
		DW	1447H
		DW	206H

K_INT10 	DB	1EH			;��ʾ�ж�
		DB	1FH
		DW	164EH
		DW	101H

K_QTINT 	DB	1EH			;�����ж�
		DB	1FH
		DW	174EH
		DW	201H

K_GNJ		DB	30H			;���ܼ��÷�
		DB	30H
		DW	0D39H
		DW	910H

D_BT		DB	' !2.13L ��������ϵͳ!',0
		DB	' ',0
D_CD		DB	'ASCII�ַ���         ',0        ;ZFB
		DB	'��չASCII���       ',0        ;KZASC
		DB	'��λ���            ',0        ;GQHZ
		DB	'˫ƴ�����          ',0        ;SPDM
		DB	'��ʾ16��ǰ��������ɫ',0        ;YS
		DB	'��ʾ��ʽһ����      ',0        ;XSFS
		DB	'ʸ�������������ֿ���',0        ;SLZT
		DB	'�������ֺű�        ',0        ;ZXZH
		DB	'�����Ű��ӡ����    ',0        ;XTPB
		DB	'������ʾ����        ',0        ;TSXS
		DB	'�����ӡ����        ',0        ;TSDY
		DB	'��ʾ�жϹ��ܵ���    ',0        ;INT10
		DB	'���̺ʹ�ӡ�жϵ���  ',0        ;QTINT
		DB	'��ģ�鹦�ܼ��÷�    ',0,0      ;GNJ

D_XZ		DW	OFFSET S_ZFB
		DW	OFFSET S_KZASC
		DW	OFFSET S_GQHZ
		DW	OFFSET S_SPDM
		DW	OFFSET S_YS
		DW	OFFSET S_XSFS
		DW	OFFSET S_SLZT
		DW	OFFSET S_ZXZH
		DW	OFFSET S_XTPB
		DW	OFFSET S_TSXS
		DW	OFFSET S_TSDY
		DW	OFFSET S_INT10
		DW	OFFSET S_QTINT
		DW	OFFSET S_GNJ
		DW	0

L_HELP		PROC	FAR
		PUSH	DS
		PUSH	ES
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES

		MOV	CX,2000H
		MOV	AH,1			;�ع��
		INT	10H
L_40:
		MOV	AL,D_WIN
		OR	AL,AL
		JNZ	L_55
L_44:
		MOV	DI,OFFSET K_MAIN
		CALL	S_XSCK			;��ʾ�մ���
		MOV	SI,OFFSET D_BT		;���⼰���˵�
		CALL	S_CKXS102
L_50:
		MOV	CH,K_NUM		;����
		MOV	CL,21			;����
		INC	DH			;�˵�λ��
		MOV	D_DX,DX
		MOV	DH,H_MAIN		;Ĭ�Ϻ�
		MOV	BP,OFFSET D_CD		;���˵�
		CALL	S_CDKZ			;�˵�����

		CMP	D_ALT,0FFH		;����ALT
		JZ	L_44
		CMP	AL,1BH			;ESC
		JZ	L_RET
L_55:
		MOV	H_MAIN,AL
		MOV	D_WIN,AL
L_60:
		CBW
		DEC	AX
		SHL	AX,1
		MOV	BX,AX
		CALL	D_XZ[BX]		;ִ�и������ӳ���

		CMP	D_ALT,0 		;��ALT
		JZ	L_62
		MOV	AL,D_WIN
		OR	AL,AL
		JNZ	L_60
l_62:
		MOV	D_WIN,0
		JMP	SHORT L_44
L_RET:
		MOV	AX,1406H
		INT	10H
		MOV	AX,1813H		;�ָ���Ļ
		TEST	DL,80H
		JZ	L_RET1
		MOV	AL,23
L_RET1:
		INT	10H
		MOV	CX,0E0FH
		MOV	AH,1			;�����
		INT	10H
		POP	ES
		POP	DS
		RET
L_HELP		ENDP

;�����ӳ���==================================================================
D_K		DW	0			;��
D_G		DW	0			;��
;�ӳ���:��ʾ�մ��� DI=���ڲ�����(����ɫ,��ʾɫ,���ڴ�С,�������Ͻ�)
S_XSCK		PROC	NEAR
		MOV	BL,[DI] 		;����ɫ
		MOV	CX,[DI+2]		;��С
		MOV	DX,[DI+4]		;���Ͻ�
		PUSH	DX
		SUB	CX,202H
		MOV	AL,CH
		CBW
		MOV	D_G,AX			;�����ڸ�
		MOV	AL,CL
		MOV	D_K,AX			;      ��

		XOR	CX,CX
		MOV	SI,OFFSET D_B1		;�Ϻ���
		CALL	S_XSYH

		MOV	SI,OFFSET D_B2		;�м�
		MOV	BP,D_G
L_CK1:
		INC	DH
		CALL	S_XSYH
		DEC	BP
		JNZ	L_CK1
		INC	DH
		CMP	DH,18H
		JA	L_CK3
		MOV	SI,OFFSET D_B3		;�º���
		CALL	S_XSYH

		ADD	DX,101H
		CMP	D_MODE,9		;�е���?
		JBE	L_CK3
		CMP	DH,18H			;������?
		JA	L_CK3
		MOV	BX,2000H		;����Ӱ
		MOV	BP,D_K
		ADD	BP,2
L_CK2:
		CALL	S_XSZF
		DEC	BP
		JNZ	L_CK2
L_CK3:
		MOV	BL,[DI+1]		;��ʾɫ
		POP	DX
		RET
;�ӳ���:��ʾһ��:
S_XSYH:
		PUSH	DX
		PUSH	BP
		MOV	BH,[SI] 		;���
		CALL	S_XSZF
		MOV	BH,[SI+1]		;�м�
		MOV	BP,D_K
L_YH1:
		CALL	S_XSZF
		DEC	BP
		JNZ	L_YH1
		MOV	BH,[SI+2]		;�ұ�
		CALL	S_XSZF
		CMP	D_MODE,9		;�е���?
		JBE	L_YH2
		CMP	SI,OFFSET D_B1		;���Ϻ���?
		JZ	L_YH2
		CMP	DL,80			;�е��ұ�?
		JZ	L_YH2
		PUSH	BX
		MOV	BX,2000H		;�ұ���Ӱ
		CALL	S_XSZF
		POP	BX
L_YH2:
		POP	BP
		POP	DX
		RET
S_XSCK		ENDP

;�ӳ���:��ʾ��������SI(ÿ��β0,����ټ�0),DX=��λ��,BL=����
S_CKXS102	PROC	NEAR
		ADD	DX,102H
S_CKXS:
		MOV	CX,1
		PUSH	DX
L_CKXS1:
		CMP	BYTE PTR [SI],0 	;����?
		JZ	L_CKXS2
		PUSH	DX
		CALL	S_XSZFC 		;��ʾһ��
		POP	DX
		INC	DH
		JMP	SHORT L_CKXS1
L_CKXS2:
		POP	DX
		RET
S_CKXS102	ENDP

;�ӳ���:����
S_INPUT 	PROC	NEAR
		MOV	D_ALT,0 		;���־
		MOV	AX,2B10H		;��BIOS����
		INT	16H
		PUSH	AX
		MOV	AL,6
		MUL	D_WIN
		ADD	AX,OFFSET K_MAIN
		MOV	SI,AX
		POP	AX

		CMP	AH,98H			;ALT+��
		JNZ	L_IN1
		MOV	DL,[SI+5]
		OR	DL,DL
		JZ	L_IN00
		DEC	DL
		MOV	[SI+5],DL
L_IN00:
		NOT	D_ALT			;�ñ�־
		RET
L_IN1:
		CMP	AH,0A0H 		;ALT+��
		JNZ	L_IN2
		MOV	DL,[SI+5]		;�������Ͻ���
		ADD	DL,[SI+3]		;+��������
		CMP	DL,25			;����?
		JAE	L_IN10
		INC	BYTE PTR [SI+5]
L_IN10:
		JMP	L_IN00
L_IN2:
		CMP	AH,9BH			;ALT+��
		JNZ	L_IN3
		MOV	DL,[SI+4]
		OR	DL,DL
		JZ	L_IN20
		DEC	DL
		MOV	[SI+4],DL
L_IN20:
		JMP	L_IN00
L_IN3:
		CMP	AH,9DH			;ALT+��
		JNZ	L_IN4
		MOV	DL,[SI+4]
		ADD	DL,[SI+2]
		CMP	DL,80
		JAE	L_IN30
		INC	BYTE PTR [SI+4]
L_IN30:
		JMP	L_IN00
L_IN4:
		CMP	AH,0A2H 		;ALT+INS*	����ɫ+
		JNZ	L_IN5
		ADD	BYTE PTR [SI],10H
		ADD	BYTE PTR [SI+1],10H
		JMP	L_IN00
L_IN5:
		CMP	AH,0A3H 		;ALT+DEL*	����ɫ-
		JNZ	L_IN6
		SUB	BYTE PTR [SI],10H
		SUB	BYTE PTR [SI+1],10H
		JMP	L_IN00
L_IN6:
		CMP	AH,97H			;ALY+HOME*	ǰ��ɫ+
		JNZ	L_IN7
		MOV	DL,[SI+1]
		MOV	DH,DL
		AND	DH,0F0H
		INC	DL
		AND	DL,0FH
		OR	DL,DH
		MOV	[SI+1],DL
		JMP	L_IN00
L_IN7:
		CMP	AH,9FH			;ALT+END*	ǰ��ɫ-
		JNZ	L_IN8
		MOV	DL,[SI+1]
		MOV	DH,DL
		AND	DH,0F0H
		DEC	DL
		AND	DL,0FH
		OR	DL,DH
		MOV	[SI+1],DL
		JMP	L_IN00
L_IN8:
		CMP	AH,99H			;ALT+PGUP*	�߿�ɫ+
		JNZ	L_IN9
		MOV	DL,[SI]
		MOV	DH,DL
		AND	DH,0F0H
		INC	DL
		AND	DL,0FH
		OR	DL,DH
		MOV	[SI],DL
		JMP	L_IN00
L_IN9:
		CMP	AH,0A1H 		;ALT+PGDN*	�߿�ɫ-
		JNZ	L_INA
		MOV	DL,[SI]
		MOV	DH,DL
		AND	DH,0F0H
		DEC	DL
		AND	DL,0FH
		OR	DL,DH
		MOV	[SI],DL
		JMP	L_IN00
L_INA:
		CMP	AH,0A6H 		;ALT+ENTER*	��ʾ����ʾ
		JNZ	L_INB
		MOV	AX,1400H
		INT	10H
		MOV	SI,OFFSET D_TS
		MOV	BX,1EH
L_INA0:
		LODSB
		OR	AL,AL
		JZ	L_INA1
		MOV	DL,AL
		MOV	AX,1403H
		INT	10H
		JMP	SHORT L_INA0
L_INA1:
		JMP	S_INPUT
L_INB:
		CMP	AH,4EH			;ALT+'+'*       ���ô���
		JNZ	L_INC
		MOV	AH,51H			;ȡPSP
		INT	21H
		PUSH	BX			;����
		MOV	BX,CS
		MOV	AH,50H			;��ǰPSP
		INT	21H
		MOV	DX,D_FILE		;�����ļ���(��·��)
		MOV	DS,DS:[2CH]
		MOV	CX,20H
		MOV	AH,3CH			;�ؽ��ļ�
		INT	21H
		MOV	BX,AX
		PUSH	CS
		POP	DS
		MOV	DX,100H
		MOV	CX,OFFSET D_END-100H
		MOV	AH,40H			;д��
		INT	21H
		MOV	AH,3EH			;�ر�
		INT	21H
		POP	BX			;�ָ�
		MOV	AH,50H			;��ǰPSP
		INT	21H
		JMP	S_INPUT
L_INC:
		RET
S_INPUT 	ENDP

D_DH		DB	1			;��ʼѡ���
D_DX		DW	0			;λ��
;���ӳ���:�˵����ơ��ַ�����BP,����CH,�CL(����0),D_DX=λ��
;		    ����AL=ѡ����
S_CDKZ		PROC	NEAR
L_CD10:
		CALL	S_XCD
		CALL	S_INPUT 		;����
		CMP	D_ALT,0FFH		;��ALT
		JZ	L_CD20
		CMP	AL,1BH			;ESC?
		JZ	L_CD20
		CMP	AL,' '
		JZ	L_CD20
		CMP	AL,0DH			;�س�
		JNZ	L_CD30
		MOV	AL,DH			;ѡ�����
L_CD20:
		RET
L_CD30:
		CMP	AH,80			;��
		JNZ	L_CD50
		CALL	S_QCD			;��ԭ��ʾ
		CMP	DH,CH			;�ѵ�����?
		JZ	L_CD40
		INC	DH			;��1
		JMP	SHORT L_CD10
L_CD40:
		MOV	DH,1			;��1
		JMP	SHORT L_CD10
L_CD50:
		CMP	AH,72			;��
		JNZ	L_CD10
		CALL	S_QCD			;��ԭ��ʾ
		CMP	DH,1			;��=1?
		JZ	L_CD60
		DEC	DH			;��1
		JMP	SHORT L_CD10
L_CD60:
		MOV	DH,CH			;������
		JMP	SHORT L_CD10
;���ӳ���:��λ��ʾ�˵���
S_QCD:						;��˵���
		MOV	BL,K_MAIN+1		;��ͨ��ʾ��ɫ
		JMP	SHORT L_XCD
S_XCD:						;д�˵���
		MOV	BL,D_CDXZ		;�˵�ѡ����ɫ
L_XCD:
		PUSH	CX
		PUSH	DX
		MOV	AL,CL			;�
		MUL	DH			;*��
		XOR	CH,CH
		SUB	AX,CX
		ADD	AX,BP
		MOV	SI,AX			;����
		ADD	DH,BYTE PTR D_DX+1	;��
		MOV	DL,BYTE PTR D_DX	;��
		CALL	S_XSZFC 		;��ʾ�ַ���
		POP	DX
		POP	CX
		RET
S_CDKZ		ENDP

;�ӳ���:��ʾ�ַ�BH,λ��DX(��ʾ��+1
S_XSZF		PROC	NEAR
		PUSH	BX
		CMP	D_MODE,9		;�е���?
		JA	L_XF1
		CMP	BL,70H			;�з���?
		JZ	L_XF1
		MOV	BL,7
L_XF1:
		MOV	AX,1409H		;��ʾ
		INT	10H
		INC	DX			;��+1
		POP	BX
		RET
S_XSZF		ENDP

;�ӳ���:��ʾ�ַ���SI,��β0,BL=����
S_XSZFC 	PROC	NEAR
		LODSB
		OR	AL,AL			;�н���?
		JZ	L_X4
		CMP	AL,'!'                  ;����?
		JNZ	L_X3
		CMP	D_MODE,9		;�е���?
		JBE	L_X1
		CALL	S_BL
		JMP	SHORT S_XSZFC
L_X1:
		CMP	BL,70H			;ԭ����?
		JZ	L_X2
		MOV	BL,70H
		JMP	SHORT S_XSZFC
L_X2:
		MOV	BL,7
		JMP	SHORT S_XSZFC
L_X3:
		MOV	BH,AL
		CALL	S_XSZF			;��ʾ�ַ�
		JMP	SHORT S_XSZFC
L_X4:
		RET
S_BL:
		ROR	BL,1			;ǰ����������
		ROR	BL,1
		ROR	BL,1
		ROR	BL,1
		RET
S_XSZFC 	ENDP

;�ӳ���:����ҳ DL=���ҳ��,DH=��ǰ��
S_PAGE		PROC	NEAR
		CALL	S_INPUT 		;����
		CMP	D_ALT,0FFH		;��ALT
		JZ	L_P00
		CMP	AL,1BH			;ESC?
		JNZ	L_P0
		POP	AX
		POP	AX
		JMP	L_RET
L_P0:
		OR	AL,AL
		JZ	L_P1
		CMP	AL,80H			;�س�?
		JAE	L_P1
L_P00:
		POP	AX
		RET
L_P1:
		MOV	AL,DH
		CMP	AH,72			;��
		JZ	L_P2
		CMP	AH,73			;PGUP
		JNZ	L_P4
L_P2:
		OR	AL,AL
		JNZ	L_P3
		MOV	AL,DL
		RET
L_P3:
		DEC	AX
		RET
L_P4:
		CMP	AH,80			;��
		JZ	L_P5
		CMP	AH,81			;PGDN
		JNZ	S_PAGE
L_P5:
		CMP	AL,DL
		JNZ	L_P6
		XOR	AL,AL
		RET
L_P6:
		INC	AX
		RET
S_PAGE		ENDP

;�ӳ���:���мӿ���ʾ����ES:SI ���ڲ�����:DI(DI+2-���ڿ�)
S_XSBT		PROC	NEAR
		PUSH	SI
		XOR	CX,CX
L_BT1:
		LODSB
		OR	AL,AL			;�д�β?
		JZ	L_BT2
		INC	CX
		JMP	SHORT L_BT1
L_BT2:
		POP	SI

		SHL	CL,1			;����*2
		MOV	CH,[DI+2]		;���ڿ�
		SUB	CH,CL
		SHR	CH,1			;���

		PUSH	DX
		PUSH	BX
		ADD	DL,CH
		CALL	S_BL
		MOV	AX,140FH		;��ʾ�ַ���
		INT	10H
		POP	BX
		POP	DX
		RET
S_XSBT		ENDP
;============================================================================
D_16		DB	'0123456789ABCDEF',0
T_ASC		DB	'ASCII �ַ���',0
D_ZF		DB	0			;��ǰ�ַ�

S_ZFB		PROC	NEAR
		MOV	DI,OFFSET K_ZFB
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_ASC
		CALL	S_XSBT			;��ʾ����
		XOR	CX,CX
		MOV	SI,OFFSET D_16		;'0123456789ABCDEF'
		PUSH	DX
		ADD	DX,104H
L_ZFB1:
		LODSB
		OR	AL,AL			;����?
		JZ	L_ZFB2
		MOV	BH,AL			;�ַ�
		CALL	S_XSZF
		MOV	BH,' '                  ;�ո�
		CALL	S_XSZF
		JMP	SHORT L_ZFB1
L_ZFB2:
		POP	DX
		ADD	DX,202H

		MOV	SI,OFFSET D_16		;'0123456789ABCDEF'
		MOV	D_ZF,0
L_ZFB3:
		LODSB
		OR	AL,AL			;����?
		JZ	L_INRET
		PUSH	DX
		MOV	BH,AL			;���ַ�
		CALL	S_XSZF
		MOV	BH,' '                  ;�ո�
		CALL	S_XSZF
		MOV	DI,16
L_ZFB4:
		MOV	BH,D_ZF 		;��ǰ�ַ�
		CALL	S_XSZF
		MOV	BH,' '                  ;�ո�
		CALL	S_XSZF
		INC	D_ZF			;�ַ�+1
		DEC	DI
		JNZ	L_ZFB4
		POP	DX
		INC	DH
		JMP	SHORT L_ZFB3
L_INRET:
		CALL	S_INPUT 		;���벢����
		CMP	AL,1BH
		JZ	L_INRET1
		RET
L_INRET1:
		POP	AX
		JMP	L_RET
S_ZFB		ENDP
;----------------------------------------------------------------------------
T_KZASC 	DB	'��չASCII���',0
D_KZASC 	DB	'0FH-SHIFT+TAB  10H-19H:ALT+QWERTYUIOP',0
		DB	'1EH-26H:ALT+ASDFGHJKL   2CH-32H:ALT+ZXCVBNM',0
		DB	'3BH-44H:F1~F10 47H-HOME       48H-UP��',0
		DB	'49H-PGUP       4AH-ALT+"-"��  4BH-LEFT��',0
		DB	'4DH-RIGHT��    4EH-ALT+"+"��  4FH-END',0
		DB	'50H-DOWN��     51H-PGDN       52H-INS',0
		DB	'53H-DEL        54H-5DH:SHIFT+F1~F10',0
		DB	'5EH-67H:CTRL+F1~F10     68H-71H:ALT+F1~F10',0
		DB	'72H-CTRL+PRTSC 73H-CTRL+��    74H-CTRL+��',0
		DB	'75H-CTRL+END   76H-CTRL+PGDN  77H-CTRL+HOME',0
		DB	'78H-83H:ALT+1~0,-,=           84H-CTRL+PGUP',0
		DB	'85H-F11        86H-F12        87H-SHIFT+F11',0
		DB	'88H-SHIFT+F12  89H-CTRL+F11   8AH-CTRL+F12',0
		DB	'8BH-ALT+F11    8CH-ALT+F12    8DH-CTRL+��',0
		DB	'8EH-CTRL+"-"   8FH-CTRL+5     90H-CTTRL+"+"',0
		DB	'91H-CTRL+��    92H-CTRL+INS   93H-CTRL+DEL',0
		DB	'94H-CTRL+TAB   95H-CTRL+/��   96H-CTRL+*��',0
		DB	'97H-ALT+HOME�� 98H-ALT+����   99H-ALT+PGUP��',0
		DB	'9BH-ALT+����   9DH-ALT+����   9FH-ALT+END��',0
		DB	'A0H-ALT+����   A1H-ALT+PGDN�� A2H-ALT+INS��',0
		DB	'A3H-ALT+DEL��  A4H-ALT+/��    A5H-ALT+TAB',0
		DB	'A6H-ALT+ENTER��         �С�Ϊר��С����',0,0

S_KZASC 	PROC	NEAR
		MOV	DI,OFFSET K_KZASC
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_KZASC
		CALL	S_XSBT			;��ʾ����
		MOV	SI,OFFSET D_KZASC
L_XSINRET:
		CALL	S_CKXS102		;��ʾ��������
		JMP	L_INRET
S_KZASC 	ENDP
;----------------------------------------------------------------------------
T_QWXS		DB	'��ʾ��������',0
D_QW		DB	'��16�� �� �� �� �� �� �� �� �� �� ��',0
		DB	'  1600    �� �� �� �� �� �� �� �� ��',0
		DB	'  1610 �� �� �� �� �� �� �� �� �� ��',0
		DB	'  1620 �� �� �� �� �� �� �� �� �� ��',0
		DB	'  1630 �� �� �� �� �� �� �� �� �� ��',0
		DB	'  1640 �� �� �� �� �� �� �� �� �� ��',0
		DB	'  1650 �� �� �� �� �� �� �� �� �� ��',0
		DB	'  1660 �� �� �� �� �� �� �� �� �� ��',0
		DB	'  1670 �� �� �� �� �� �� �� �� �� ��',0
		DB	'  1680 �� �� �� �� �� �� �� �� �� ��',0
		DB	'  1690 �� �� �� �� ��               ',0
		DB	'!����������,��������,<ESC>�������˵�.!',0,0
D_Q		DB	16			;����

S_GQHZ		PROC	NEAR
		MOV	DI,OFFSET K_GQHZ
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_QWXS
		CALL	S_XSBT			;��ʾ����
		ADD	DX,102H
L_GQHZ1:
		MOV	AL,D_Q			;����
		CBW
		MOV	CL,10
		DIV	CL
		OR	AX,3030H		;ʮ����
		MOV	SI,OFFSET D_QW+2
		MOV	CX,11
L_GQHZ2:
		MOV	[SI],AX 		;д������
		ADD	SI,37			;��һ��
		LOOP	L_GQHZ2

		PUSH	BX
		PUSH	DX
		MOV	DI,OFFSET D_QW+37
		MOV	BL,10
		XOR	DH,DH			;λ��
L_GQHZ3:
		ADD	DI,7
		MOV	BH,10
L_GQHZ4:
		CMP	DH,94
		JA	L_GQHZ5
		OR	DH,DH
		JNZ	L_GQHZ6
L_GQHZ5:
		MOV	AX,'  '
		JMP	SHORT L_GQHZ7
L_GQHZ6:
		MOV	DL,D_Q			;����
		MOV	AX,DX
		ADD	AX,0A0A0H		;��������
L_GQHZ7:
		STOSW				;д��
		INC	DI
		INC	DH
		DEC	BH
		JNZ	L_GQHZ4
		DEC	BL
		JNZ	L_GQHZ3
		POP	DX
		POP	BX

		MOV	SI,OFFSET D_QW
		CALL	S_CKXS			;����������ʾ
L_GQHZ8:
		MOV	BH,D_Q
		CALL	S_INPUT 		;ȡ����
		CMP	D_ALT,0FFH		;��ALT
		JZ	L_GQHZA
		CMP	AL,1BH			;ESC?
		JNZ	L_GQHZ9
		POP	AX
		JMP	L_RET
L_GQHZ9:
		CMP	AL,0DH			;�����˵�
		JNZ	L_GQHZB
L_GQHZA:
		RET
L_GQHZB:
		CMP	AH,75			;��
		JZ	L_GQHZC
		CMP	AH,80			;��
		JNZ	L_GQHZD
L_GQHZC:
		DEC	BH
		CMP	BH,1
		JNB	L_GQHZF
		MOV	BH,87
		JMP	SHORT L_GQHZF
L_GQHZD:
		CMP	AH,72			;��
		JZ	L_GQHZE
		CMP	AH,77			;��
		JNZ	L_GQHZ8
L_GQHZE:
		INC	BH			;����+1
		CMP	BH,95
		JB	L_GQHZF
		MOV	BH,1
L_GQHZF:
		MOV	D_Q,BH
		JMP	L_GQHZ1
S_GQHZ		ENDP
;----------------------------------------------------------------------------
T_SP		DB	'˫ƴ�����',0
D_SP		DB	'��ĸ��zh-V     ch-I      sh-U',0
		DB	'��ĸ��          i-I       u-U     ��-V',0
		DB	'      a-A      ia-R *    ua-W ��',0
		DB	'      o-O      uo-O',0
		DB	'      e-E      ie-T ��            ��e-W',0
		DB	'      ai-L               uai-Y',0
		DB	'      ei-D               ui-V',0
		DB	'      ao-K    iao-M ��',0
		DB	'      ou-P    iu-Q',0
		DB	'      an-J    ian-B ��   uan-Z��  ��an-Z',0
		DB	'      en-F    in-N  ��   un-C ��  ��n-C',0
		DB	'      ang-H   iang-X��   uang-X',0
		DB	'      eng-G   ing-Y Ӣ',0
		DB	'      ong-S   iong-Sӵ',0
		DB	'ע:����ĸaeo˫��,˫��ĸ�մ�,angΪag,engΪeg',0
		DB	'   ����ap�ɵ������е�ƫ�Բ���(�ڶ�������)',0,0

S_SPDM		PROC	NEAR
		MOV	DI,OFFSET K_SPDM
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_SP
		CALL	S_XSBT			;��ʾ����
		MOV	SI,OFFSET D_SP
		JMP	L_XSINRET		;��ʾ�������ݲ�����
S_SPDM		ENDP
;----------------------------------------------------------------------------
T_XSYS		DB	'��ʾ16��ǰ��������ɫ',0
D_XSYS		DB	'����\�� �� �� �� �� �� �� �� �� �� �� �� �� �� �� �� ǰ��',0,0
D_YS		DB	'�� �� �� �� �� �� �� �� �� �� �� �� �� �� �� �� ',0

S_YS		PROC	NEAR
		MOV	DI,OFFSET K_YS
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_XSYS
		CALL	S_XSBT
		MOV	SI,OFFSET D_XSYS
		CALL	S_CKXS102		;��ʾ�������ݲ�����
		MOV	BH,'0'                  ;����ɫ
L_YS1:
		INC	DH			;��+1
		PUSH	DX
		CALL	S_XSKG			;��ʾ�ո�
		CALL	S_XSKG
		CALL	S_XSZF			;��ʾ����ɫ
		CALL	S_XSKG
		CALL	S_XSKG
		CALL	S_XSYS			;��ʾһ��
		POP	DX
		INC	BH			;����ɫ+1
		CMP	BH,'G'
		JZ	L_YS2
		CMP	BH,3AH
		JNZ	L_YS1
		ADD	BH,7
		JMP	SHORT L_YS1
L_YS2:
		JMP	L_INRET
S_XSYS:
		PUSH	BX
		MOV	SI,OFFSET D_YS		;��ɫ��
		MOV	BL,BH
		SUB	BL,'0'
		CMP	BL,9
		JBE	L_XY1
		SUB	BL,7
L_XY1:
		MOV	CL,4
		SHL	BL,CL			;����ɫ
		MOV	CX,16
L_XY2:
		LODSB
		CALL	S_XSAL
		LODSB
		CALL	S_XSAL
		LODSB
		CALL	S_XSAL
		INC	BL			;ǰ��ɫ+1
		LOOP	L_XY2
		POP	BX
		RET
S_XSKG:
		MOV	AL,' '
S_XSAL:
		PUSH	BX
		MOV	BH,AL
		CALL	S_XSZF
		POP	BX
		RET
S_YS		ENDP
;----------------------------------------------------------------------------
T_XSFS		DB	'��ʾ��ʽһ����',0
D_XSFS		DB	'��ʾ��ʽ  �ֱ���   �С���   ����  ɫ��   ��ʾģ��     ��ʾ������',0
		DB	'������������������������������������������������������������������',0
		DB	'    6    640��200  25��80   8��8   0,1   CGA,CGA25   CGA,EGA,VGA',0
		DB	'    9    640��400  25��80   8��16  0,1    HGA.COM        HGA',0
		DB	'  10H    640��350  25��80   8��14   16    EGA.COM      EGA,VGA',0
		DB	'  12H    640��480  26��80   8��16   16    VGA.COM        VGA',0
		DB	'  255    640��480  30��80   8��16  256    VGA.COM       SVGA',0,0

S_XSFS		PROC	NEAR
		MOV	DI,OFFSET K_XSFS
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_XSFS
		CALL	S_XSBT
		MOV	SI,OFFSET D_XSFS
		JMP	L_XSINRET		;��ʾ�������ݲ�����
S_XSFS		ENDP
;----------------------------------------------------------------------------
T_SL		DB	'ʸ�����������',0
D_SL1		DB	' 0-�����(HZKSJSTJ)       8-�����(HZKSLLBJ) ',0
		DB	' 1-���μ�(HZKSLFSJ)       9-��ڼ�(HZKSLDHJ) ',0
		DB	' 2-�����(HZKSLHTJ)      10-κ����(HZKSLWBJ) ',0
		DB	' 3-�����(HZKSLKTJ)      11-�п���(HZKSLXKJ) ',0
		DB	' 4-���μ�(HZKSLXBJ)      12-�����(HZKSLLSJ) ',0
		DB	' 6-ϸԲ��(HZKSLY1J)      13-Ҧ���(HZKSLYTJ) ',0
		DB	' 7-׼Բ��(HZKSLY3J)      14-���ڼ�(HZKSLMHJ) ',0
		DB	' ',0
D_SL2		DB	'20-���己(HZKSLSTF)      28-���䷱(HZKSLLBF) ',0
		DB	'21-���η�(HZKSLFSF)      29-��ڷ�(HZKSLDHF) ',0
		DB	'22-���己(HZKSLHTF)      30-κ����(HZKSLWBF) ',0
		DB	'23-���己(HZKSLKTF)      31-�п���(HZKSLXKF) ',0
		DB	'26-ϸԲ��(HZKSLY1F)      32-���귱(HZKSLHPF) ',0
		DB	'27-׼Բ��(HZKSLY3F)      33-���շ�(HZKSLZYF) ',0
		DB	'            ��',127,'Ϊ���ֿ��Ѱ�װ',0,0

S_SLZT		PROC	NEAR
		MOV	AX,357EH		;ȡINT7E
		INT	21H
		OR	BX,BX			;�а�װ?
		JZ	L_SLZT9
		XOR	DX,DX			;ȡREADSL��װ״̬
		INT	7EH
		MOV	BX,ES
		CMP	BX,DX			;���Ƿ�READSLģ��?
		JNZ	L_SLZT9
		MOV	SI,AX
		MOV	DI,OFFSET D_SL1
		MOV	CX,0
		MOV	BX,19
L_SLZT1:
		LODS	WORD PTR ES:[SI]
		OR	AX,AX
		JZ	L_SLZT2
		MOV	BYTE PTR DS:[BX+DI],7FH
L_SLZT2:
		ADD	DI,46
		INC	CX
		CMP	CX,8
		JNZ	L_SLZT3
		MOV	BX,44
		MOV	DI,OFFSET D_SL1
L_SLZT3:
		CMP	CX,5
		JNZ	L_SLZT4
		ADD	SI,2
		INC	CX
L_SLZT4:
		CMP	CX,14
		JBE	L_SLZT1

		ADD	SI,10
		MOV	DI,OFFSET D_SL2
		MOV	CX,20
		MOV	BX,19
L_SLZT5:
		LODS	WORD PTR ES:[SI]
		OR	AX,AX
		JZ	L_SLZT6
		MOV	BYTE PTR DS:[BX+DI],7FH
L_SLZT6:
		ADD	DI,46
		INC	CX
		CMP	CX,28
		JNZ	L_SLZT7
		MOV	BX,44
		MOV	DI,OFFSET D_SL2
L_SLZT7:
		CMP	CX,24
		JNZ	L_SLZT8
		ADD	CX,2
		ADD	SI,4
L_SLZT8:
		CMP	CX,33
		JBE	L_SLZT5
L_SLZT9:
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET K_SLZT
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_SL
		CALL	S_XSBT
		MOV	SI,OFFSET D_SL1
		JMP	L_XSINRET		;��ʾ�������ݲ�����
S_SLZT		ENDP
;----------------------------------------------------------------------------
T_ZXB		DB	'���ͺ��ֺű�',0
D_ZXB		DB	'!���ͱ�!(`@A~x):',0
		DB	'A-����24��24   E-����24��24   I-����24��24   M-����24��24 (��������)',0
		DB	'B-����48��24   F-����48��24   J-����48��24   N-����48��24 (����һ��)',0
		DB	'C-����24��48   G-����24��48   K-����24��48   O-����24��48 (����һ��)',0
		DB	'D-����48��48   H-����48��48   L-����48��48   P-����48��48 (������һ��)',0
		DB	'Q-16��16(����) R-32��16(����) S-16��32(����) T-32��32(������)',0
		DB	'U-40��40(����) V-40��40(����) W-40��40(����) X-40��40(����)',0
		DB	'a-����16��24   e-����16��24   i-����16��24   m-����16��24 (�����뱶)',0
		DB	'b-����36��24   f-����36��24   j-����36��24   n-����36��24 (�����뱶)',0
		DB	'c-����24��36   g-����24��36   k-����24��36   o-����24��36 (�����뱶)',0
		DB	'd-����36��36   h-����36��36   l-����36��36   p-����36��36 (�������뱶)',0
		DB	'q-16��24(����) r-32��24(����) s-16��48(����) t-32��48(������) ������24',0
		DB	'u-32��32(����) v-32��32(����) w-32��32(����) x-32��32(����)',0
		DB	'!�ֺű�!(180DPI.������):0-90��90',0
		DB	'1-72��72 10-80��80 11-60��80 12-80��60 13-54��72 14-72��54',0
		DB	'2-48��48 20-60��60 21-45��80 22-80��45 23-36��48 24-48��36',0
		DB	'3-40��40 30-44��44 31-33��44 32-44��33 33-30��40 34-40��30',0
		DB	'4-32��32 40-36��36 41-27��36 42-36��27 43-24��32 44-32��24',0
		DB	'5-24��24 50-28��28 51-21��28 52-28��21 53-18��24 54-24��18',0
		DB	'6-20��20 60-22��22 61-16��22 62-22��16 63-15��20 64-20��15',0
		DB	'7-16��16 70-18��18 71-13��18 72-18��13 73-12��16 74-16��12',0,0

S_ZXZH		PROC	NEAR
		MOV	DI,OFFSET K_ZXZH
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_ZXB
		CALL	S_XSBT
		MOV	SI,OFFSET D_ZXB
		JMP	L_XSINRET		;��ʾ�������ݲ�����
S_ZXZH		ENDP
;----------------------------------------------------------------------------
T_PB		DB	'ϵͳ�������Ű�',0
D_PB		DB	"  `'���,ҳ��` - �����Ű�(ȡ�����س����н���ҳ�ų�ֵ1)",0
		DB	'        �а�����Ű��������ҳ������պ��п�,���򱣳�ԭֵ',0
		DB	'        ����ҳ�������ó�ʼ��ӡҳ��(ȱʡΪ1.Ϊ0�򲻴�ҳ��)',0
		DB	'  `,` - ���ñ��о���(����ǰ�п�)',0
		DB	'  `,,` - ���ñ��о���(����ǰ�п�)',0
		DB	'  `[[�ո���` - ���Ű�ڶ��к����׼ӿո���',0
		DB	'  `:` - ��ӡ������ʼ��.��ԭ�Ű����ӡĩҳҳ��',0
		DB	'  `@����` - �õ���������(A~x,Ĭ��A)',0
		DB	'  `@@�ֺ�,����` - �����ֺ�(PRTH�ɰ��ֱ���DPI�Զ�����)',0
		DB	'  `&�о�` - ���о�(1~255,Ĭ��20)',0
		DB	'  `^����` - ���ַ����(0~255,���ּӱ�,Ĭ��0.��λ:��)',0
		DB	'  `#ҳ��` - ��ҳ��(��λ��.Ĭ��ֽ��)',0
		DB	'  `##` - ���ӡ���ͻ�ҳ��(ǿ�ƻ�ҳ)',0
		DB	'  `[�ַ���` - ����߿�(0~2447,Ĭ��0.�Ե�Ϊ��λ)',0
		DB	'  `]�ַ���` - ���п�(1~2448,�Ե�Ϊ��λ.Ĭ�����)',0
		DB	"��: `'1&30",0
		DB	'    `,@W`ͨ  ֪',0
		DB	'    `@X',0
		DB	'        ��������������֪ͨ����,����ҵ�λ�������,��',0
		DB	'    ����29����10��4�շż�6��,10��5��(������)�ϰࡣ',0
		DB	'        �ش�֪ͨ��',0
		DB	'    `,,@U�������칫��  `',0,0

S_XTPB		PROC	NEAR
		MOV	DI,OFFSET K_XTPB
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_PB
		CALL	S_XSBT
		MOV	SI,OFFSET D_PB
		JMP	L_XSINRET		;��ʾ�������ݲ�����
S_XTPB		ENDP
;----------------------------------------------------------------------------
T_TSXS		DB	'2.13L������ʾ����',0
D_TSXS1 	DB	'Cɫ��,���ɫ] - ����ͼ����ɫ          D��X,Y] - ����',0
		DB	'E����] - �����ϻ���                   U����] - ���ϻ���',0
		DB	'F����] - �����»���                   X�߶�] - ���»���',0
		DB	'G����] - �����»���                   Y����] - ���һ���',0
		DB	'H����] - �����ϻ���                   Z����] - ������',0
		DB	'L�յ�X,Y] - ��б��(��X�з�����Ϊ��Ե�ǰ����������)',0
		DB	'L/����,�Ƕ�] - ���ǶȻ���(������Ϊ0��,���Ƶ�ǰ��)',0
		DB	'B��,��] - ������(��ǰ��Ϊ���½�.�����=0����,���͸߶�=0����Ļ�߿���',0
		DB	'   ��C����ָ�������ɫ����������ָ����ɫ',0
		DB	'Vɫ��,���½�X,Y,��,��,����,���,�߿�,��ʽ] - ����������      /,0=����',0
		DB	'   ����:����=1����,=2����,=3��б��,=4��б��.��ʽ=1���߿���(C����ָ����ɫ)',0
		DB	'OԲ��X,Y,�뾶,��ʽ] - ��Բ(INT10K).��C����ָ�������ɫ��Բ�Ͱ�Բ�����',0
		DB	'   ����:��ʽ�����������=0�򻭰�Բ,=1����Բ��,������Բ',0
		DB	'OԲ��X,Y,���뾶,��ʽ,�̰뾶,��ʼ��,��ֹ��,��־] - ��Բ,��Բ��Բ��(INT10V)',0
		DB	'   ����:��ʽ=0Ϊ��Բ,=1Ϊ��Բ��,��������ֵ��ȱʡʱΪԲ)',0
		DB	'        ��־=1����,=0������(���ϵ���Բ��������). �����ɫ��C����ָ��',0
		DB	'K��������] - ���ñ�������(1~255,ʵ��Ҫ/16)',0
		DB	'J] - ִ�����                       W...] - �������(���������)',0,0

D_TSXS2 	DB	'P��ɫ��,�߽�ɫ��] - ���',0
		DB	'M...] - ǰ׺���Ƶ�ǰ�㵫�����߻��    N...] - ǰ׺�����ߵ����Ƶ�ǰ��',0
		DB	'_��,��,��] - ���ַ����л�����         |��,��,��] - ���ַ����л�����',0
		DB	'#��,��,��,��,��ʽ] - ���ַ����л�����(���з�ʽ,����������4��)',0
		DB	'Qɫ��] - ����(����ɫ�����ʼ����������.���С�ɫ�š��򰴴���ɫ����)',0
		DB	'R������] - ������(��������,ż��ȡ��)',0
		DB	'I������] - ִ��INT10�ж�(����:������Ϊ�Ĵ��� AH,AL,BH,BL,CH,CL,DH,DL)',0
		DB	'   ����һ����Ϊ255ʱ,�ڶ���������ִ�е��жϺ�,����˳��ΪAH,AL,BH...',0
		DB	'   ���з��ز���������40:0F0H��ʼ��14����Ԫ��,˳��Ϊ:AX,BX,CX,DX,BP,SI,DI',0
		DB	'Sǰ��ɫ,����ɫ] - �����ַ��ͺ�����ɫ',0
		DB	'*��,��,�ַ���,ǰ��ɫ,����ɫ] - ������Ļ�ϵ��ַ���',0
		DB	'A��չASCII��] - ģ�⹦�ܼ�(�ο�SETUP���ܼ�����)',0
		DB	'%���ܷ�������] - ��������(���������)',0
		DB	'   ����:���ܷ�Ϊ   t����    ָ������(Ĭ��100,ÿ���ӽ�����)',0
		DB	'        CDEFGAB  ����(����ΪC��)     1234567  ����   0  ��ֹ��',0
		DB	'        #  ������       b  ������    q  ���˶�       d  ���˶�',0
		DB	'        .  ����         -  �ӳ���    _  �˷�����     =  ʮ��������',0
		DB	'   ע:�����˶ȡ���������������ǰ���ӳ������㡢�İ˷�������������',0,0

D_TSXS3 	DB	'������ - ��ʱ ��λ:��.��Χ:0-4096      T0��1] - ����ʾ�л�(1��0��)',0
		DB	'^����] - �����������,�޴�����򿪻�ر�����',0
		DB	'@���Ͻ��ַ���,ɨ������,ͼ���ļ���$] - ��ʾ16ɫPCX��ʽͼ��',0
		DB	'~X1,Y1,X2,Y2,ͼ���ļ���$] - ����16ɫPCX��ʽͼ��',0
		DB	'   ����:X1Ϊͼ�����Ͻ��ַ���(0-79), Y1Ϊ���Ͻ�������(0-479)',0
		DB	'        X2Ϊͼ�����½��ַ���(1-79), Y2Ϊ���½�������(1-479)',0
		DB	'        ͼ���ļ���չ��ӦΪPCX,��������$��',0
		DB	'[���ܷ������ֻ��ַ�] - ��ʾ���ֻ��ַ�(���������).����Ϊ���ܷ�:',0
		DB	'   @����  ָ������(��������A)',0
		DB	'   ��ʽһ:����Ϊ��ĸA-X,a-x(A-Pͬ��ӡ,a~pΪA~P������,Q~T��u~xΪ16����)',0
		DB	'   ��ʽ��:����Ϊʸ�����ֵ���������(�ö��Ÿ���).��INT10K��INT10V',0
		DB	'       ��һ��Ϊ�������(��Χ:4~639), �ڶ���Ϊ�������(��Χ:4~479)',0
		DB	'       ��������Ϊʸ�������(��ȱʡ�򱣳�ԭֵ)',0
		DB	'   ^���  ָ���ַ����(0-255,���ּ��ӱ�,����Ϊ0)',0
		DB	'   &���  ָ���м��(0-255,����Ϊ1)',0
		DB	'   _����  ˮƽ��λ(0-639,����Ϊ0)      |����  ��ֱ��λ(0-479,����Ϊ0)',0
		DB	'   *ɫ��  ǰ����ɫ(0-15,�������)      #ɫ��  ������ɫ(0-15,����Ϊ0)',0
		DB	'   \0��1  0Ϊ���ֱ�������ԭͼ��,1������(����Ϊ������)',0,0
D_TSXS		DB	0			;����ҳ��

S_TSXS		PROC	NEAR
		MOV	SI,OFFSET D_TSXS1	;��һҳ
		CMP	D_TSXS,0
		JZ	L_TSXS1
		MOV	SI,OFFSET D_TSXS2	;�ڶ�ҳ
		CMP	D_TSXS,1
		JZ	L_TSXS1
		MOV	SI,OFFSET D_TSXS3	;����ҳ
L_TSXS1:
		PUSH	SI
		MOV	DI,OFFSET K_TSXS
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_TSXS
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;��ʾ��������
		MOV	DH,D_TSXS
		MOV	DL,2			;���ҳ��
		CALL	S_PAGE			;����ҳ
		MOV	D_TSXS,AL
		JMP	SHORT S_TSXS
S_TSXS		ENDP
;----------------------------------------------------------------------------
T_TSDY		DB	'�����ӡ����',0
D_TSDY1 	DB	'`@����` - �õ���������(A~x,Ĭ��A)',0
		DB	'`@����` - ��ʸ����������(����Ϊ������:��,��,�����)',0
		DB	'    ����: ����߷�Χ1~255.�������μ�ʸ�����ֱ���ȱʡԭֵ����)',0
		DB	'`@@�ֺ�,����` - �����ֺ�(PRTH�ɰ��ֱ���DPI�Զ�����)',0
		DB	'    �ֺ�:0-90,1-72,2-48,3-40,4-32,5-24,6-20,7-16(��=��.Ϊ180DPI)',0
		DB	'    ʮλ��Ϊ1~7,��λ>0������Ϊԭ�ߵ�3/4,ż����Ϊԭ����3/4',0
		DB	'    ��λ<3Ϊ�����:��1=80,��2=60,��3=44,��4=36,��5=28,��6=22,��7=18',0
		DB	'`@/��\` - �򿪰��ֱ�������(PRTH:@/�����ͺ��־�,@&�����о�,@\�ر�)',0
		DB	'`@-��=` - �ö����ֵĿ��п�һ��(-,Ĭ��)�����(=)',0
		DB	'`@<��>` - �ö�����˫������ӡ(Ĭ�ϵ���(PRTH��Ч)',0
		DB	'`&�о�` - ���о�(1~255)',0
		DB	'`&A��B` - �����о൥λ:A-1/180Ӣ��,B-1/120Ӣ��(Ĭ��.��PRNT)',0
		DB	'`&C` - ����Ϊ�м��1/180Ӣ��(��ʱ&�м����ø���.�м��+24=�о�)',0
		DB	'`&D` - ����Ϊ�м��1/120Ӣ��(��ʱ&�м����ø���.�м��+16=�о�)',0
		DB	'`^����` - ���ַ����(0~255,���ּӱ�,Ĭ��0.��λ:��)',0
		DB	'`#ҳ��` - ��ҳ��(PRNT:0-255��.Ĭ��0;PRTH:0~65535��.Ĭ�ϵ�ҳֽ��)',0
		DB	'`##` - ���ӡ���ͻ�ҳ��(ǿ�ƻ�ҳ)[����Ϊ�м��ʱ����`E`]',0
		DB	'`*����` - ��ҳ�����(0~255,Ĭ��0.PRTH�޴˹���)',0,0

D_TSDY2 	DB	'`*` - ������ֽ(��PRTH)',0
		DB	'`[�ַ���` - ����߿�(0~2447,Ĭ��0.�Ե�Ϊ��λ)',0
		DB	'`]�ַ���` - ���п�(1~2448,�Ե�Ϊ��λ.Ĭ�����)',0
		DB	'`~����` - �������(0~2447.һ����Ч)',0
		DB	'`|����` - ˮƽ��λ(1~2447.��ǰ����Ч)',0
		DB	'`%0~7` - �ñ���:0��,1����,2����,3����,4����,5��б��,6��б��,7������',0
		DB	'`"ɫ��` - ����ɫ(LQ2500��M1570��,0��,1��,2��,3��,4��,5��,6��',0
		DB	'`$...$` - ����$���ַ�ֱ�ʹ�ӡ��',0
		DB	'`>`��ESC+I+> - �õ����ӡ(PRTH��)',0
		DB	'`<`��ESC+I+< - ��˫���ӡ(PRTH��)',0
		DB	'`;` (�ֺ�) - �ó���ӡ(���)',0
		DB	'`\` (��б��) - �÷��״�ӡ',0
		DB	'`/` (б��) - ���ϻ��ߴ�ӡ',0
		DB	'`_` (�»���) - ���»��ߴ�ӡ',0
		DB	'`=` (�Ⱥ�) - ��������ӡ(����״̬,����������)',0
		DB	'`(` (������) - ������90�ȴ�ӡ',0
		DB	'`)` (������) - ������90�ȴ�ӡ',0
		DB	'`?` (�ʺ�) - �ý�����ת(����״̬,�����϶���)',0,0

D_TSDY3 	DB	'`+` (�Ӻ�) - ���ϱ��ַ�',0
		DB	'`-` (����) - ���±��ַ�',0
		DB	'`��` (��̾��) - �������ַ�(����״̬,�����϶���)',0
		DB	'`.` (С����) - ��ͣ��ӡ(����һ������)',0
		DB	"`'���,ҳ��` (������) - �����Ű�(ȡ�����س����н���ҳ�ų�ֵ1)",0
		DB	'    �а�����Ű��������ҳ������պ��п�,���򱣳�ԭֵ(����������)',0
		DB	'    ����ҳ�������ó�ʼ��ӡҳ��(ȱʡΪ1.Ϊ0�򲻴�ҳ��)',0
		DB	'`,` (����) - ���ñ��о���(����ǰ�п�)',0
		DB	'`,,` (��������) - ���ñ��о���(����ǰ�п�)',0
		DB	'`[[�ո���` - ���Ű�ڶ��к����׼ӿո���',0
		DB	'`:` (ð��) - ��ӡ������ʼ��.��ԭ�Ű����ӡĩҳҳ��',0
		DB	'ESC+I+N1+N2 - ͼ���ӡ N1���ֽ�,N2���ֽ�.���(N1*256+N2)*3�ֽ�����',0
		DB	'ESC+I+A~x - ������(A~x)',0
		DB	'ESC+I+�� - ȡ�������ӡ����',0
		DB	'ESC+I+�� - �ָ������ӡ����(����״̬)',0
		DB	'ESC+I+\  - ȡ��WS���س�(8DH��0AH)',0
		DB	'ESC+I+/  - �ָ�WS���س�8DHΪ0DH(����״̬)',0
		DB	'ESC+W - ִ����Ļ����',0,0
D_TSDY		DB	0			;ҳ��

S_TSDY		PROC	NEAR
		MOV	SI,OFFSET D_TSDY1	;��һҳ
		CMP	D_TSDY,0
		JZ	L_TSDY1
		MOV	SI,OFFSET D_TSDY2	;�ڶ�ҳ
		CMP	D_TSDY,1
		JZ	L_TSDY1
		MOV	SI,OFFSET D_TSDY3	;����ҳ
L_TSDY1:
		PUSH	SI
		MOV	DI,OFFSET K_TSDY
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_TSDY
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;��ʾ��������
		MOV	DH,D_TSDY
		MOV	DL,2
		CALL	S_PAGE			;����ҳ
		MOV	D_TSDY,AL
		JMP	SHORT S_TSDY
S_TSDY		ENDP
;----------------------------------------------------------------------------
T_INT10 	DB	'��ʾ�жϹ��ܵ���',0
D_INT1		DB	'AH=0,AL=��ʾ��ʽ�� - ������ʾ��ʽ',0
		DB	'AH=1,CH=�����ʼ��,CL=������ - �趨����С',0
		DB	'AH=2,BH=ҳ��,DH=�к�,DL=�к� - �趨���λ��',0
		DB	'AH=3,BH=ҳ�� - ȡ���λ��  ����:DH=�к�,DL=�к�,CX=����С',0
		DB	'AH=4(�ο�BIOS�ֲ�) - ȡ���λ�� (ROM-BIOS)',0
		DB	'AH=5,AL=ҳ�� - �ı䵱ǰ��ʾҳ',0
		DB	'AH=6,AL=����(=0ȫ��),BH=����������� - �Ϲ���ǰҳ',0
		DB	'     CH=�����������Ͻ��к�,CL=�к�,DH=�����������½��к�,DL=�к�',0
		DB	'AH=7(��������ͬ��) - �¹���ǰҳ',0
		DB	'AH=8,BH=ҳ�� -ȡ���λ���ַ�������  ����:AL=ASCII��,AH=����',0
		DB	'AH=9,AL=ASC��,BH=ҳ��,BL=����,CX=�ַ����� - �ڵ�ǰ���λ����ʾ�ַ�������',0
		DB	'AH=0AH(����ȡ��ǰλ��ԭֵ,��������ͬ��) - �ڵ�ǰ���λ����ʾ�ַ�',0
		DB	'AH=0BH(�ο�BIOS�ֲ�) - ����Ļ��ɫ(CGA��)',0
		DB	'AH=0CH,AL=ɫ��,CX=X����,DX=Y���� - ��ָ�����괦д��',0
		DB	'AH=0DH,CX=X����,DX=Y���� - ��ָ�����괦����  ����:AL=ɫ��',0
		DB	'AH=0EH,AL=ASC�� - ��TTY��ʽ��ʾ�ַ�',0
		DB	'AH=0FH - ȡ��ǰ��ʾ��ʽ  ����:AL=��ʾ��ʽ,AH=���ַ���,BH=��ǰҳ��',0
		DB	'AH=10H(�ο�BIOS�ֲ�) - ����EGA��VGA��ɫ�� (ROM-BIOS)',0
		DB	'AH=11H(�ο�BIOS�ֲ�) - ����EGA��VGA�ַ��� (ROM-BIOS)Ĭ�Ͻ�AL=30H��Ч',0
		DB	'AH=12H(�ο�BIOS�ֲ�) - ȡEGAVGA������״̬ (ROM-BIOS)',0,0

D_INT2		DB	'AH=13H,ES:BP=�ַ�����ַ(AL=5����),DX=λ��,CX=����,BH=ҳ�� - ��ʾ�ַ���',0
		DB	'    AL=0 BL=����   ��ʾ���겻��',0
		DB	'    AL=1 BL=����   ��ʾ�����ƴ�β',0
		DB	'    AL=2 ��������  ��ʾ���겻��',0
		DB	'    AL=3 ��������  ��ʾ�����ƴ�β',0
		DB	'    AL=4 BL=����   ����0��β ��ʾ�����ƴ�β',0
		DB	'    AL=5 BL=������ ������Ļ�������ַ���,��ʾ��ԭ���λ�ò���',0
		DB	'AH=14H - ��ʾ�в���',0
		DB	'    AL=0 - �򿪻�����ʾ��',0
		DB	'    AL=1,DL=�ַ���,CL=���� - ��ʾ�ַ�',0
		DB	'    AL=2,DL=��ʾ��λ�� - ��ʾ�й�궨λ',0
		DB	'    AL=3,DL=�ַ��� - ��ʾ�ַ�DL���ƽ����  ���ܷ���7��8��Ч',0
		DB	'    AL=4 - �ر���ʾ��',0
		DB	'    AL=5,BH=��ʾ�и����к�(VGA��Ч),BL=��ʾ�й��ɫ(=0�޹��,��VGA)',0
		DB	'    AL=6 - ȡ��ʾ����  AL=��ʾ��ʽ, AH=���ɫ��, BH=��ʾ�и���λ��',0
		DB	'           BL=4����ֱ��д��,=0��, CL=��ʾ����, CH=ÿ��ɨ������',0
		DB	'           SI=�������-1, DI=�������-1, BP=��ʾ��������',0
		DB	'           DL=��ʾ���Ʋ���,DH=��ǰ��ʾ��λ��',0
		DB	'      DL:λ3=0:16����,λ0=0����,��0����',0
		DB	'         λ7=1ֱ��д��,λ6=1������ʾ��,λ5=1��չ�ַ���,λ4-��ʾ��ʽ>5������',0,0

D_INT3		DB	'    AL=7 - ���ö�����ʾ��ʽBH',0
		DB	'    AL=8 - λ��DX���ַ�������ʾ',0
		DB	'    AL=9 - ��λ��DX����ʾ�ַ�BH, ����ΪBL, CX=0���ַ���ʾ,��0����ʾ����',0
		DB	'    AL=0AH - ����ʾ��ָ��λ��DL��ʾBL����BP:SI���ĵ���64�ֽ�',0
		DB	'    AL=0BH - �����˸����  BH=0��,��0��˸',0
		DB	'    AL=0CH - ȡ��������ַ  BX:AX (��+25*80*2������չ�ַ����׵�ַ)',0
		DB	'    AL=0DH - ֱ��д������BH  ȡֵ��Χ1-8',0
		DB	'    AL=0EH - ȡ�����Ʊ���ת�������ַ BX:AX',0
		DB	'    AL=0FH - ��ָ��λ��DX��ʾ�ӿ��ַ���DS:SI(��0��β,����ΪBL)',0
		DB	'    AL=10H - �򿪵ڶ���ʾ�� BL=ָ����ɫ(��VGA,��ͬ)',0
		DB	'    AL=11H - �ڵڶ���ʾ����ʾ�ַ�DL CL=����,BL=��ɫ',0
		DB	'    AL=12H - �ڶ���ʾ�й�궨λDL',0
		DB	'    AL=13H - �ڵڶ���ʾ����ʾ�ַ�DL���ƽ���� BL=��ɫ',0
		DB	'    AL=14H - �رյڶ���ʾ��',0
		DB	'AH=15H,AL=1���,=0��ʾ - ��ʾ���',0
		DB	'AH=16H,DX=��������(�ַ�DH=0),BP:BX=д���ַ - ����ʾ��ģ����',0
		DB	'    ����:�ַ�16�ֽ�,����32�ֽ�(0-15�ֽ�Ϊ�����,16-31Ϊ�Ұ���)',0
		DB	'AH=17H,AL=0ȡ��,��0���� - ������ȡ�����',0
		DB	'AH=18H - ϵͳ����',0
		DB	'    AL=0ʶ����            AL=1��ʶ����',0,0

D_INT4		DB	'    AL=2���Ը�λ����        AL=3���',0
		DB	'    AL=4������������ʾ��ʽ  AL=5����������ʾ��ʽ',0
		DB	'    AL=8������������˸      AL=9����������˸(AH=10H,BL=3)',0
		DB	'    AL=0AH�ر�ֱ��д��      AL=0BH�ָ�ֱ��д��',0
		DB	'    AL=0CH�����Ʊ���������ʽBH',0
		DB	'    AL=0DH������ BH=1��AH=1����, =0�̶�����СBL',0
		DB	'    AL=0EH��ʾ��ʽ>=6Ϊ���� AL=0FH�ָ�ԭ��ʽ',0
		DB	'    AL=10H�����ַ���˸      AL=11H����           AL=12H����',0
		DB	'    AL=13H������Ļ          AL=14H�ر�ʱ����ʾ   AL=15H�ָ�ʱ����ʾ',0
		DB	'    AL=16H������Ļ��ɫ:BH-ǰ��,BL-����,CH-�߿�(��EGA��VGA)',0
		DB	'    AL=17H��������          AL=18H����18��ģʽ   AL=19H�ָ�16��ģʽ',0
		DB	'    AL=1AH��ֹ�����ַ���    AL=1BH���������ַ���(AH=11H����)',0
		DB	'    AL=1CH-INT10AH=6~10ֱ��д����ʽ    AL=1DH�ָ��жϷ�ʽ',0
		DB	'    AL=1EHִ��INT10��ʼ�����ԼĴ���    AL=1FH����ʼ��',0
		DB	'AH=19H,AL=0�ر�,=1�� - ���Կ���',0
		DB	'    AL=2 - ���Բ�����ʼ��(GW�޴˹���)',0
		DB	'    AL=3,����װ����AL=83H(L),=84H(K),=85H(V),ES=����ģ��� - ���ذ�װ״̬',0
		DB	'    AL=4 - ֹͣ��������',0
		DB	'AH=0FFH - ȡ��װ����ʾģ��',0
		DB	'    ����:AH=0,AL="V"-VGA,="E"-EGA,="H"-HGA,="C"-CGA,="c"-CGA11',0,0
D_INT10 	DB	0			;ҳ��

S_INT10 	PROC	NEAR
		MOV	SI,OFFSET D_INT1	;��һҳ
		CMP	D_INT10,0
		JZ	L_INT10
		MOV	SI,OFFSET D_INT2	;�ڶ�ҳ
		CMP	D_INT10,1
		JZ	L_INT10
		MOV	SI,OFFSET D_INT3	;����ҳ
		CMP	D_INT10,2
		JZ	L_INT10
		MOV	SI,OFFSET D_INT4	;����ҳ
L_INT10:
		PUSH	SI
		MOV	DI,OFFSET K_INT10
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_INT10
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;��ʾ��������
		MOV	DH,D_INT10
		MOV	DL,3
		CALL	S_PAGE			;����ҳ
		MOV	D_INT10,AL
		JMP	SHORT S_INT10
S_INT10 	ENDP
;----------------------------------------------------------------------------
T_INT		DB	'���̺ʹ�ӡ�жϵ���',0
D_INT11 	DB	'    !INT 16�������̹���!',0
		DB	'AH=0,����AL=�����ַ����� - ��������',0
		DB	'AH=1,����Z��־=0���ַ�,=1���ַ� - �����̻�����',0
		DB	'AH=2,����AL=ת����״̬ - ȡ��ǰת����״̬',0
		DB	'     ����: λ0-��Shift, 1-��Shift, 2-Ctrl,3-Alt',0
		DB	'             4-ScrollLock, 5-NumLock, 6-CapsLock, 7-INS',0
		DB	'AH=3,AL=5 - ���û����ٶȺ��ӳ�(ֻ286������Ч)',0
		DB	'     BH=�ӳ�,=0Ϊ250����(��С). BL=�����ٶ�,=0Ϊ30�ַ�/��(���)',0
		DB	'AH=4,AL=ת����״̬(ͬAH=2) - �õ�ǰת����״̬',0
		DB	'AH=5,CL=�ַ���,CH=ɨ���� - ����̻�����д�ַ�(ֻ286������Ч)',0
		DB	'AH=10H ͬAH=0',0
		DB	'AH=11H ͬAH=1',0
		DB	'AH=12H ͬAH=2',0
		DB	'AH=20H,BP=��,CX=��������,DX=��������.(0-3װ��,4-7ȡ��)',0
		DB	'     AL=0��4�ⲿ����,=1��5�����,=2��6���ģ��,=3��7˫ƴ����',0
		DB	'AH=21H,AL=��չASCII�� - ģ�⹦�ܼ�',0
		DB	'AH=22H,DX=�������� - ȡ����˫ƴ��  ����AL=˫ƴ��һ��,AH=˫ƴ�ڶ���',0
		DB	'AH=24H,AL=0��,=1�� - �˳����ֺ����������ܿ���(�ɹر�Ӱ����Ļ��ʾ�Ĺ���)',0
		DB	'AH=25H,BL=��ɫ - ��ʾ�汾��Ϣ',0
		DB	'AH=27H, AL=0 ȡ�������뷽ʽ��DL, AL=1 ���ú������뷽ʽ DL=���뷽ʽ��',0
		DB	'   DL=0ΪASCII��ʽ,λ0��λ,λ1��β,λ2ƴ��,λ3˫ƴ,λ4���,λ7�籨',0,0

D_INT12 	DB	'AH=29H - ������ʾ��',0
		DB	'AH=2AH,AL=0:д��,=1ȡ�� - ȡ���ð���ģ���ַBP:SI',0
		DB	'AH=2BH,AL=INT16AHֵ,����AX - ִ��ROM-BIOS INT 16H',0
		DB	'AH=2FH - ����:��ģ���ж�����BP:SI���ʲ�������ַBP:DI��2.13��װ·��',0
		DB	'              AX=44H-��װCKBD, =39H-��װCKB9',0
		DB	'      ����:[DI]-�ⲿ����,[DI+6]-�����,[DI+18]-˫ƴ����',0
		DB	'    !INT 17������ӡ����!',0
		DB	'AH=0,AL=�ַ�����,����AH=��ӡ��״̬�� -  ��ӡ���',0
		DB	'AH=1,DX=��ӡ�ں�,����AH=��ӡ��״̬�� - ��ʼ����ӡ��',0
		DB	'AH=2,DX=��ӡ�ں�,����AH=��ӡ��״̬�� - ȡ��ӡ��״̬',0
		DB	'AH=3,AL=0ֱ�ʹ�ӡ��,=1��ϵͳ���ִ�ӡ - ���ô�ӡ����ģʽ',0
		DB	'AH=4,AL=0�ر�,=1�� - �����ӡ���ܿ���',0
		DB	'AH=5,AL=�ַ��� - ֱ������ַ�AL',0
		DB	'AH=6 - ȡ��ӡ����  ����:ES=פ���ڴ����������ε�ַ',0
		DB	'        AH=�����ֽ�,AL=��ӡ����,CH=�ַ����,CL=�о�,DL=������ĸ',0
		DB	'        DH="N"ΪPRNT, ="H"ΪPRTH',0
		DB	'        SI=��߿���,DI=�п�,BP��8λ=���Ϳ�,BP��8λ=���͸�',0
		DB	'        BL=�����ֽ�1:λ0-2����1~7,λ3���',0
		DB	'        BH=�����ֽ�2:λ0-����,λ1-�»���,λ2-�ϻ���,λ3-����',0
		DB	'                     λ4-����,λ5-�ϱ�,λ6-�±�',0
		DB	'AX=-1(��65535) - ȡ��װ״̬ ����װ�򷵻�:AX=-2130H,DX:BX=BIOS INT17',0,0

D_INT13 	DB	'    !INT 2F������·�ж�!(ϵͳ���ù���)',0
		DB	'AX=4A06H,SI=0 �˳�����ϵͳ, =1 ��������������ģ��, =2 �����ģ��',0
		DB	'           =3 ����:AX=0,BX=4A06H��ϵͳ��װ��,��AX������δװ��',0
		DB	'              CX:DX-BIOS�жϱ�(1�ֽ��жϺ�,4�ֽ��ж�����),[DX-2]-�ж���',0
		DB	'    !INT 7A������16��16�����ֿ�   INT 7C������32��32�����ֿ�!',0
		DB	'    !INT 7B������24��24�����ֿ�   INT 7D������40��40�����ֿ�!',0
		DB	'AH=����(λ0-1����,2-3����,4-5����,6-7����',0
		DB	'     ��λ6-7=0,λ4-5=01Ϊ24���������,=10Ϊ16����,=11Ϊ16������24��',0
		DB	'     λ4-5����:=00����,=01������,=10����,=11����)',0
		DB	'   BH=���⹦��(λ1�ϻ���,2�»���,3����,4����,5�ϱ�,6�±�,7��ת��24����)',0
		DB	'   BL=��ǰ��ӡ����(���򳬹�24��ʱ����ӡ����,BLָʾ�ǵڼ���,����24��ʱΪ0)',0
		DB	'   DX=��������,��DH=0��DL=ASCII��(�ַ�)',0
		DB	'   DS:SI��������������ʼ��ַ,CX=�ֽ���',0
		DB	'    !INT 7E������ʸ���ֿ�! DX=0����DX:BX��������ַ,AX=�ֿ��ַ',0
		DB	'AX=���Ϳ���,BX=������,CX=���͸߶�,DX=��������(�ַ�DH=0)',0
		DB	'SI=��ʼ��,DI=��ֹ��,BP=����(λ0=0ˮƽ����,=1��ֱ����,λ11=1�±�,λ12=1�ϱ�',0
		DB	'         λ13=0��ת90��,=1��ת180��,λ14=0����,=1����,λ15=0����ת,=1��ת)',0
		DB	'���� DX:BX=���󻺳�����ַ,AX=ʵ�ʿ���,CX=ʵ�ʸ߶�',0
		DB	'    !INT 7F������16��16������ʾ�ֿ�!(ˮƽ����)',0
		DB	'DX=��������,���� DX=����������ʼ��(ƫ��=0)',0,0
D_QTINT 	DB	0			;ҳ��

S_QTINT 	PROC	NEAR
		MOV	SI,OFFSET D_INT11	;��һҳ
		CMP	D_QTINT,0
		JZ	L_QTINT
		MOV	SI,OFFSET D_INT12	;�ڶ�ҳ
		CMP	D_QTINT,1
		JZ	L_QTINT
		MOV	SI,OFFSET D_INT13	;����ҳ
L_QTINT:
		PUSH	SI
		MOV	DI,OFFSET K_QTINT
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_INT
		CALL	S_XSBT
		POP	SI
		CALL	S_CKXS102		;��ʾ��������
		MOV	DH,D_QTINT
		MOV	DL,2
		CALL	S_PAGE			;����ҳ
		MOV	D_QTINT,AL
		JMP	SHORT S_QTINT
S_QTINT 	ENDP
;----------------------------------------------------------------------------
T_GNJ		DB	'��������ϵͳʹ�÷���',0
D_GNJ		DB	'ִ����������:ʹ�ü���ģ��������ܼ�(F11)',0
		DB	'�˳���������:����<Esc>��',0
		DB	'�˳���ģ��:  ��DOS�¼��� LHELP �ӿո���������',0
		DB	'�Ӵ��ڷ������˵�:�����������ļ�',0
		DB	'  ���Ӵ��ڴ�<Esc>ֱ���˳�,�ٴΰ�<F11>��ֱ�ӽ���ô���.',0
		DB	'����<Alt>+<Enter>(С����):��ʾ����ʾ���¸��ӹ���:',0
		DB	'  <Alt>+����ƶ�����������---�ƶ���ǰ����',0
		DB	'  <Alt>+<Ins*>--����ɫ+1  <Alt>+<Del*>--����ɫ-1',0
		DB	'  <Alt>+<Home*>-ǰ��ɫ+1  <Alt>+<End*>--ǰ��ɫ-1',0
		DB	'  <Alt>+<PgUp*>-�߿�ɫ+1  <Alt>+<PgDn*>-�߿�ɫ-1',0
		DB	'  <Alt>+<+>----���ô���  (��*����ר�ù����Ϸ�)',0,0

S_GNJ		PROC	NEAR
		MOV	DI,OFFSET K_GNJ
		CALL	S_XSCK			;��ʾ����
		MOV	SI,OFFSET T_GNJ
		CALL	S_XSBT
		MOV	SI,OFFSET D_GNJ
		JMP	L_XSINRET		;��ʾ�������ݲ�����
S_GNJ		ENDP

;****************************************************************************
BEGIN:
		XOR	BP,BP
		MOV	AX,1406H		;ȡ��ʾ����
		INT	10H
		OR	BP,BP
		JNZ	L_S5
		MOV	DX,OFFSET NO213
		JMP	SHORT L_ERR
L_S5:
		CMP	CL,25			;��25��?
		JAE	L_S6
		MOV	DX,OFFSET NO25		;С��25,����
		JMP	SHORT L_ERR
L_S6:
		MOV	D_MODE,AL		;��
		CMP	AL,9			;�е���?
		JA	L_S10
		MOV	D_CDXZ,70H
L_S10:
		XOR	BP,BP
		MOV	AX,2A01H		;ȡ����ģ���?
		INT	16H
		OR	BP,BP
		JZ	L_S20
		CMP	BYTE PTR DS:[80H],0	;�в����˳�?
		JZ	L_S12
		MOV	ES,BP
		XOR	BP,BP
		XOR	SI,SI
		MOV	AX,2A00H		;ժģ��
		INT	16H
		MOV	AH,49H			;�屾ģ��
		INT	21H
		MOV	ES,ES:[2CH]
		MOV	AH,49H			;�廷����
		INT	21H
		MOV	DX,OFFSET D_TVIU
		JMP	SHORT L_ERR
L_S12:
		MOV	DX,OFFSET D_YJCZ
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_S20:
		MOV	ES,DS:[2CH]		;����������
		XOR	SI,SI
		XOR	AX,AX
L_S122:
		CMP	ES:[SI],AX		;���һ�����β?
		JZ	L_S124
		INC	SI
		JMP	SHORT L_S122
L_S124:
		ADD	SI,4
		MOV	D_FILE,SI

		MOV	BP,CS
		MOV	SI,OFFSET L_HELP
		MOV	AX,2A00H		;�ӵ�����ģ��
		INT	16H
		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
		MOV	DX,OFFSET D_END
		INT	27H

MSG		DB	'2.13L ��������ϵͳ v2.0 1998��8��',13,10
		DB	'ʹ�ü���ģ��������ܼ�(F11)�������',13,10
		DB	'    ��DOS�¼��� LHELP �ӿո�:�˳���ģ��',13,10,'$'

D_TVIU		DB	'�˳�!',7,13,10,'$'
D_YJCZ		DB	'�����Ѿ�����!',7,13,10,'$'
NOHELP		DB	'δ��װ������!',7,13,10,'$'
NO213		DB	'NOT INSTALLED 2.13 SYSTEM!',7,13,10,'$'
NO25		DB	'CGA11��ʾģ�鲻��ʹ�ñ�����!',7,13,10,'$'
D_INPUT 	DB	5 DUP(0)

D_END	EQU	$

CSEG		ENDS
		END	START

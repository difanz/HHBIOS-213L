;	ZJXP.INC ����ֱ��д��ģ��
;	1995.1.12, 1.18, 2.16
;	1996.1.19

D_ZBFS		DB	3		;=0�����ķ�ʽ,=1�������Ʊ���
					;=2���������Ʊ���,=3����ȫ���Ʊ���
D_NUM		DB	0		;�ַ���˸����

;�ӳ���:����ֱ��д��
S_XR		PROC	NEAR
		CMP	CS:D_ZBFS,1		;=1�������Ʊ���
		JZ	L_XR10

		CMP	CS:D_ZBFS,2		;=2���������Ʊ���
		JZ	L_XR1
		CALL	S_SXSM			;����ɨ��
L_XR1:
		MOV	CX,25*80		;����������
		XOR	SI,SI
L_XR2:
		LODSW				;ȡ�ַ�
		CMP	AL,0B0H 		;�������Ʊ���
		JB	L_XR9
		CMP	AL,0E0H
		JAE	L_XR9

		PUSH	SI			;�����Ʊ�������
		PUSH	CX
		XOR	CX,CX			;			1.19
		MOV	DI,SI
L_XR3:
		INC	CX
		CMP	AL,[DI] 		;�ַ���ͬ?
		JNZ	L_XR3A
		ADD	DI,2
		JMP	SHORT L_XR3
L_XR3A:
		CMP	CX,4			;4�������������Ʊ���
		JAE	L_XR4
		CMP	CX,1			;1��
		JZ	L_XR5
		CMP	AL,0DFH 		;רΪFOXPRO�� 2-3���
		JZ	L_XR4
		CMP	CX,2			;2��
		JZ	L_XR5
		CMP	AL,0C4H 		;� ;����һ��
		JZ	L_XR4
		CMP	AL,0CDH 		;�
		JNZ	L_XR5			;			1.18
L_XR4:
		CALL	S_LXZF			;ת����д��B800
		JMP	SHORT L_XR8
L_XR5:
		CALL	S_QTZF			;�����Ʊ���
L_XR8:
		POP	CX
		POP	SI
L_XR9:
		LOOP	L_XR2			;������һ���ַ�
L_XR10:
		MOV	CX,25*80		;����������
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_XPQ
		XOR	SI,SI
L_XR11:
		REPE	CMPSW			;�Ƚ�������
		JZ	L_XR12
		PUSH	DS
		PUSH	ES
		PUSH	CX
		PUSH	SI
		PUSH	DI
		SUB	SI,2
		MOV	AX,SI			;ָ��ͬ�ĵ�һ���ַ�
		SHR	AX,1
		MOV	DL,80
		DIV	DL			;ÿ���ַ���
		XCHG	AH,AL
		MOV	DX,AX			;��ǰ�ַ�λ��
		LODSW				;ȡ�ַ�
		MOV	WORD PTR CS:D_XPQ[SI-2],AX
		MOV	CX,AX
		CALL	S_XRXS			;��ʾ
		POP	DI
		POP	SI
		POP	CX
		POP	ES
		POP	DS
		OR	CX,CX
		JNZ	L_XR11			;û��,����
L_XR12:
		RET
S_XR		ENDP

D_ZBFB		DB	80H, 81H, 82H, 14H, 83H, 84H, 85H,0B7H
	;0B0H		�    �	  �    �    �	 �    �    �
		DB     0B8H, 86H, 15H, 87H, 88H,0BDH,0BEH, 89H
	;0B8H		�    �	  �    �    �	 �    �    �
		DB	8AH, 8BH, 8CH, 8DH, 12H, 8EH, 8FH, 90H
	;0C0H		�    �	  �    �    �	 �    �    �
		DB	91H, 92H, 93H, 94H, 95H, 13H, 96H, 97H
	;0C8H		�    �	  �    �    �	 �    �    �
		DB	98H, 99H, 9AH,0D3H,0D4H,0D5H,0D6H, 9BH
	;0D0H		�    �	  �    �    �	 �    �    �
		DB	9CH, 9DH, 9EH, 82H, 9FH, 82H, 82H,0A0H
	;0D8H		�    �	  �    �    �	 �    �    �

S_ZBF		PROC	NEAR
		MOV	BL,AL
		XOR	BH,BH
		MOV	BL,CS:D_ZBFB[BX-0B0H]
		RET
S_ZBF		ENDP

;�ӳ���:�����Ʊ���
S_QTZF		PROC	NEAR
		CMP	CS:D_ZBFS,2		;���������Ʊ���
		JNZ	L_QT1
		RET
L_QT1:
		CMP	AL,0B2H 		;� � �			1.16
		JBE	L_QT11
		CMP	AL,0DBH 		;� � �
		JB	L_QT3
L_QT11:
		CALL	S_ZBF			;ȡת����
		MOV	DL,[SI] 		;�ұ��ַ�		1.16
		CMP	AL,DL
		JZ	L_QT12
		CMP	DL,BL			;�������Ʊ���?
		JNZ	L_QT13
L_QT12:
		MOV	DL,[SI-4]		;����ַ�		1.16
		CMP	DL,BL			;�������Ʊ���?
		JZ	L_QT14
		CMP	AL,DL
		JNZ	L_QT13
		CMP	BYTE PTR [SI+2],0A0H	;�ұߵڶ��ַ�Ϊ����?	1.19
		JBE	L_QT14
L_QT13:
		RET
L_QT14:
		JMP	L_QT9
L_QT3:
		MOV	BL,AL
		XOR	BH,BH
		MOV	DL,CS:D_ZBF[BX-0B3H]	;ȡ����
		XOR	BP,BP
		TEST	DL,30H			;�����?
		JZ	L_QT4
		MOV	CH,DL
		AND	CH,30H			;���
		MOV	CL,4
		SHR	CH,CL
		MOV	BL,[SI-4]		;����ַ�
	;	CMP	BL,11H			;
	;	JZ	L_QT3A
		CALL	S_QSX			;ȡ����
		JC	L_QT4
		AND	DH,3			;�ұ�
		CMP	CH,DH			;��?
		JNZ	L_QT4
		CMP	BL,0A0H 		;���Ʊ���?
		JA	L_QT4
L_QT3A: 	CALL	L_QT9			;д��
		INC	BP
L_QT4:
		TEST	DL,0CH			;���ϱ�?
		JZ	L_QT5
		MOV	CH,DL
		AND	CH,0CH
		MOV	CL,4
		SHL	CH,CL
		MOV	BL,[SI-80*2-2]		;�ϱ��ַ�
	;	CMP	BL,1EH			;
	;	JZ	L_QT4A
		CALL	S_QSX			;ȡ����
		JC	L_QT5
		AND	DH,0C0H 		;�±�
		CMP	CH,DH			;��?
		JNZ	L_QT5
		CMP	BL,0A0H 		;���Ʊ���?
		JBE	L_QT44
		OR	BP,BP			;����д���Ʊ���?
		JZ	L_QT5
		PUSH	SI
		PUSH	AX
		SUB	SI,80*2
		MOV	AL,BL
		CALL	L_QT9			;�ϱ�д��
		POP	AX
		POP	SI
		JMP	SHORT L_QT5
L_QT44:
		OR	BP,BP
		JNZ	L_QT5
L_QT4A:
		CALL	L_QT9			;д��
		INC	BP
L_QT5:
		TEST	DL,3			;���ұ�?
		JZ	L_QT6
		MOV	CH,DL
		AND	CH,3
		MOV	CL,4
		SHL	CH,CL
		MOV	BL,[SI] 		;�ұ��ַ�
	;	CMP	BL,10H			;
	;	JZ	L_QT5A
		CALL	S_QSX			;ȡ����
		JC	L_QT6
		AND	DH,30H			;���
		CMP	CH,DH			;��?
		JNZ	L_QT6
		CMP	BL,0A0H 		;���Ʊ���?
		JA	L_QT6
		OR	BP,BP
		JNZ	L_QT6
L_QT5A:
		CALL	L_QT9			;д��
		INC	BP
L_QT6:
		TEST	DL,0C0H 		;���±�?
		JZ	L_QT7
		MOV	CH,DL
		AND	CH,0C0H
		MOV	CL,4
		SHR	CH,CL
		MOV	BL,[SI+80*2-2]		;�±��ַ�
	;	CMP	BL,1FH			;
	;	JZ	L_QT9
		CMP	BL,0A0H
		JA	L_QT7
		CALL	S_QSX			;ȡ����
		JC	L_QT7
		AND	DH,0CH			;�ϱ�
		CMP	CH,DH			;��?
		JZ	L_QT8
L_QT7:
		RET
L_QT8:
		OR	BP,BP
		JNZ	L_QT7
L_QT9:
		MOV	CX,1
;�ӳ���:�Ʊ���ת����д��B800
S_ZJZF:
		CMP	CX,4
		JB	L_ZJ0
		MOV	BL,AL			;�ĸ�������ͬ
		CALL	S_QSX			;ȡ����
		JB	L_ZJ0
		AND	DH,33H			;ȡ����λ
		CMP	DH,11H			;����ϸ��?
		JZ	L_ZJ0
		CMP	DH,22H			;���Ҵ���?
		JZ	L_ZJ0
		RET
L_ZJ0:
		CALL	S_ZBF			;ȡת����
		MOV	AL,BL
		MOV	ES,CS:D_B800		;B800����
		MOV	DI,SI
		SUB	DI,2
L_ZJ7:
		STOSB				;д���ַ�
		INC	DI
		LOOP	L_ZJ7
L_ZJ8:
		RET
S_QTZF		ENDP

;�ӳ���:���������Ʊ��������ѯ
S_LXZF		PROC	NEAR
		PUSH	CX
		MOV	BL,[SI-4]		;����ַ�
		CMP	BL,0A0H 		;�к���?
		JBE	L_LX1
		CALL	S_QSX			;ȡ����
		JB	L_LX1
		AND	DH,3

		MOV	BL,AL
		XOR	BH,BH
		MOV	DL,CS:D_ZBF[BX-0B3H]	;ȡ����
		AND	DL,30H
		MOV	CL,4
		SHR	DL,CL

		CMP	DL,DH			;��?
		JNZ	L_LX1
		PUSH	AX
		PUSH	SI
		SUB	SI,2
		MOV	AL,[SI-2]		;����ַ�
		CALL	L_QT9			;д��
		POP	SI
		POP	AX
L_LX1:
		POP	CX
		JMP	S_ZJZF
S_LXZF		ENDP

;�ӳ���:ȡ�Ʊ���BL����->DH
S_QSX		PROC	NEAR
		PUSH	BX
		XOR	BH,BH
		CMP	BL,20H
		JB	L_QSX1
		CMP	BL,7FH
		JB	L_QSX0			;ASCII�ַ�
		CMP	BL,0A0H
		JBE	L_QSX1			;��������
L_QSX00:
		CMP	BL,0B3H 		;���Ʊ���?
		JB	L_QSX0
		CMP	BL,0DAH
		JBE	L_QSX3
L_QSX0:
		STC
		POP	BX
		RET
L_QSX1:
		MOV	DH,BL
		MOV	BX,0
L_QSX2:
		CMP	DH,CS:D_ZBFB[BX]
		JZ	L_QSX4
		INC	BX
		CMP	BL,48
		JB	L_QSX2
		JMP	SHORT L_QSX0
L_QSX4:
		ADD	BL,0B0H
		JMP	SHORT L_QSX00
L_QSX3:
		MOV	DH,CS:D_ZBF[BX-0B3H]
		CLC
		POP	BX
		RET
S_QSX		ENDP

;�����Ʊ��������ֽ�
;	λ67-��, 45-��, 23-��, 01-��
;	��λ=01����, =10˫��
D_ZBF		DB	01000100B,01010100B,01100100B,10011000B
	;		� 0B3H	  � 0B4H    � 0B5H    � 0B6H
		DB	10010000B,01100000B,10101000B,10001000B
	;		� 0B7H	  � 0B8H    � 0B9H    � 0BAH
		DB	10100000B,00101000B,00011000B,00100100B
	;		� 0BBH	  � 0BCH    � 0BDH    � 0BEH
		DB	01010000B,00000101B,00010101B,01010001B
	;		� 0BFH	  � 0C0H    � 0C1H    � 0C2H
		DB	01000101B,00010001B,01010101B,01000110B
	;		� 0C3H	  � 0C4H    � 0C5H    � 0C6H
		DB	10001001B,00001010B,10000010B,00101010B
	;		� 0C7H	  � 0C8H    � 0C9H    � 0CAH
		DB	10100010B,10001010B,00100010B,10101010B
	;		� 0CBH	  � 0CCH    � 0CDH    � 0CEH
		DB	00100110B,00011001B,01100010B,10010001B
	;		� 0CFH	  � 0D0H    � 0D1H    � 0D2H
		DB	00001001B,00000110B,01000010B,10000001B
	;		� 0D3H	  � 0D4H    � 0D5H    � 0D6H
		DB	10011001B,01100110B,00010100B,01000001B
	;		� 0D7H	  � 0D8H    � 0D9H    � 0DAH

;�ӳ���:����ɨ��
S_SXSM		PROC	NEAR
		XOR	SI,SI
		MOV	CX,80			;ÿ���ַ���
L_SX1:
		PUSH	SI
		PUSH	CX
		MOV	CX,25			;����к�
L_SX2:
		MOV	AL,[SI]
		CMP	AL,0B3H 		;�
		JZ	L_SX3
		CMP	AL,0BAH 		;�
		JNZ	L_SX4
L_SX3:
		CALL	S_ZBF			;ȡת����BL		1.18
		CALL	S_ZXSM
		OR	CX,CX
		JZ	L_SX5
L_SX4:
		ADD	SI,80*2
		LOOP	L_SX2
L_SX5:
		POP	CX
		POP	SI
		ADD	SI,2
		LOOP	L_SX1
		RET
S_SXSM		ENDP

;�ӳ���:����ɨ�账��
S_ZXSM		PROC	NEAR
		XOR	DX,DX
		MOV	DI,SI
L_ZX1:
		INC	DX
		ADD	SI,80*2 		;��һ��
		DEC	CX
		CMP	BL,DS:[SI]		;��ת����?
		JZ	L_ZX2
		CMP	AL,DS:[SI]		;���ַ�?
		JNZ	L_ZX3
L_ZX2:
		OR	CX,CX
		JNZ	L_ZX1
L_ZX3:
		MOV	AL,BL

		PUSH	CX
		CMP	DL,3			;����?
		JB	L_ZX5
	;	MOV	BL,AL
		CALL	S_QSX			;ȡ��������
		AND	DH,0FH
		MOV	CH,DH			;������4λ
		MOV	BL,[DI-80*2]		;��һ���ַ�
		CMP	BL,0A0H 		;���Ʊ���?
		JA	L_ZX5
		CALL	S_QSX			;ȡ����
		MOV	CL,4
		SHR	DH,CL			;�Ƶ�4λ
		CMP	CH,DH			;��?
		JZ	L_ZX7
L_ZX5:
		CMP	BYTE PTR [DI-2],0A0H	;����Ϊ�ַ�?
		JA	L_ZX8
		CMP	BYTE PTR [DI+2],0A0H
		JA	L_ZX8
L_ZX7:
		MOV	[DI],AL 		;ת����д��
		ADD	DI,80*2
		DEC	DL
		JNZ	L_ZX7

		POP	CX
		OR	CX,CX
		JZ	L_ZX9
		PUSH	CX

		MOV	BL,AL
		CALL	S_QSX			;ȡ��������
		AND	DH,0F0H
		MOV	CH,DH
		MOV	BL,[DI] 		;��һ���ַ�
		CMP	BL,0A0H
		JBE	L_ZX8
		CALL	S_QSX			;ȡ����
		MOV	CL,4
		SHL	DH,CL
		CMP	CH,DH			;��?
		JNZ	L_ZX8
		PUSH	SI
		MOV	SI,DI
		ADD	SI,2
		MOV	AL,BL
		CALL	L_QT9			;д��
		POP	SI
L_ZX8:
		POP	CX
L_ZX9:
		RET
S_ZXSM		ENDP

;�ӳ���:AL�Ʊ���ת�������Ʊ���
S_ALVB		PROC	NEAR
		CMP	AL,20H
		JB	L_AV0
		CMP	AL,7FH
		JB	L_AV3			;ASCII�ַ�
		CMP	AL,0A0H
		JA	L_AV3			;��������
L_AV0:
		XOR	BX,BX
L_AV1:
		CMP	AL,CS:D_ZBFB[BX]
		JZ	L_AV2
		INC	BX
		CMP	BL,48
		JB	L_AV1
		RET
L_AV2:
		MOV	AL,BL
		ADD	AL,0B0H
L_AV3:
		RET
S_ALVB		ENDP

;�ӳ���:��ʾ
S_XRXS		PROC	NEAR
		CMP	CS:D_ZBFS,0		;=0�����ķ�ʽ
		JZ	L_XX1
		CMP	AL,0A0H 		;�к���?
		JA	L_XX2
L_XX1:
		CMP	CS:D_ZBFS,1		;=0�����ķ�ʽ ��1�������Ʊ���
		JBE	L_XX1A
		CALL	S_ALVB			;AL�Ʊ���ת��ASCII�Ʊ���
L_XX1A:
		MOV	BL,CH			;��ǰ�ַ�����(�ַ�AL)
   ;�ӳ���:��ʾ�ַ�AL,����BL,λ��SI
S_XRZF:
		MOV	CX,1
		XOR	BP,BP
		MOV	DS,BP
		JMP	S_XSZF
L_XX2:
		CALL	S_PVHZ			;��������?
		JZ	L_XX3
		CMP	DL,1			;��ǰ�ַ���λ��
		JB	L_XX1
		MOV	BX,DS:[SI-4]		;����ַ�
		CMP	BL,0A0H
		JBE	L_XX1
		MOV	AH,BL			;����ַ�(����BH)
		MOV	BL,CH			;��ǰ�ַ�����(�ַ�AL)
		DEC	DX
		JMP	SHORT S_XRHZ
L_XX3:
		CMP	DL,79			;��ǰ�ַ�����β
		JAE	L_XX1
		MOV	BX,DS:[SI]		;�ұ��ַ�
		CMP	BL,0A0H
		JBE	L_XX1
		MOV	AL,BL			;�ұ��ַ�
		MOV	BL,BH			;	 ����
		MOV	AH,CL			;��ǰ�ַ�
		MOV	BH,CH			;	 ����
   ;�ӳ���:��ʾ���� ǰ�ֽ�AH,����BH,λ��SI;���ֽ�AL,����BL
S_XRHZ:
		CMP	DL,79			;����β?
K_HZ1	EQU	$
		JZ	L_XRHZ1

		XOR	BP,BP
		JMP	S_XSHZ
L_XRHZ1:
		PUSH	AX
		PUSH	BX
		MOV	AL,AH
		MOV	BL,BH
		CALL	S_XRZF
		POP	BX
		POP	AX
		INC	DX
		CMP	DL,80
		JNZ	L_XRHZ2
		XOR	DL,DL
		INC	DH
L_XRHZ2:
		JMP	S_XRZF
S_XRXS		ENDP

;�ӳ���:�������� ����ZF=0Ϊǰ�ֽ�,=1Ϊ���ֽ�
S_PVHZ		PROC	NEAR
		PUSH	SI
		XOR	BL,BL
		OR	DL,DL
		JZ	L_PV2
		MOV	BH,DL			;��ǰ�ַ���λ��
		SUB	SI,4
L_PV1:
		CMP	BYTE PTR [SI],0A0H
		JB	L_PV2
		SUB	SI,2
		NOT	BL
		DEC	BH
		JNZ	L_PV1
L_PV2:
		POP	SI
		OR	BL,BL
		RET
S_PVHZ		ENDP

;	PEGA.ASM (2)
;	1993.8.18
;	1994.1.18
;	1995.2.10

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN			;[100H]-��־ 'PEG'

D_INT5		DD	0			;ԭINT5 	[103H]
D_FDBS		DW	2			;�Ŵ���	[107H]
D_FSWX		DB	0		;=1��ɫ����, =2����	[109H]
D_SPC		DW	0			;��߿�����	[10AH]
D_LEFT		DW	0			;����� 	[10CH]
D_RIGHT 	DW	79			;�ұ��� 	[10EH]
D_UP		DW	0			;�ϱ��� 	[110H]
D_DOWN		DW	479			;�±��� 	[112H]
D_ZZ		DB	'`&16`',13,10,'$'       ;��ֽ
D_DX		DB	'`>`$'                  ;����
D_SX		DB	'`<`$'                  ;˫��
D_TX		DB	1BH,'I'                 ;ͼ���ӡ
D_TX1		DB	0,0,'$'
D_DI		DW	0			;��ʾ����������ַ

INT_5		PROC	FAR
		STI
		CLD
		PUSH	DS
		PUSH	ES
		PUSH	BP
		PUSH	SI
		PUSH	DI
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	CS
		POP	DS
		MOV	AX,1406H		;ȡ��ʾ����
		INT	10H
		CMP	AL,10H			;EGA
		JZ	L_10
		CMP	AL,12H			;VGA
		JZ	L_10
		PUSHF
		CALL	D_INT5			;ִ��ԭINT5
		JMP	L_90
L_10:
		CMP	DI,D_DOWN		;�±���?
		JAE	L_20
		MOV	D_DOWN,DI
L_20:
		MOV	AX,80			;ÿ���ֽ���
		MUL	D_DOWN			;���±���
		ADD	AX,D_RIGHT
		MOV	D_DI,AX 		;=��Ļ����������ַ
		MOV	AX,D_RIGHT
		SUB	AX,D_LEFT
		INC	AX
		MOV	BX,8
		MUL	BX
		MOV	BX,D_FDBS
		MUL	BX
		ADD	AX,D_SPC
		XCHG	AH,AL
		MOV	WORD PTR D_TX1,AX	;ÿ��ͼ������

		MOV	BX,D_DOWN		;�����������
		SUB	BX,D_UP
		INC	BX			;	 ����
		MOV	ES,BP			;��ʾ��������

		MOV	AL,0AH
		CALL	S_PAL			;�س�
		CALL	S_DX			;���õ����ӡ
		MOV	AX,D_FDBS		;�Ŵ���
		MUL	BX
		MOV	DL,18H
		DIV	DL
		OR	AH,AH
		JZ	L_30
		INC	AX
		XOR	AH,AH
L_30:
		MOV	CX,AX			;��������
		MOV	AX,80
		MUL	D_UP
		ADD	AX,D_LEFT
		MOV	DI,AX			;��ʼ��ַ
L_40:
		PUSH	CX
		MOV	AH,1			;�а���?
		INT	16H
		JZ	L_50
		XOR	AH,AH
		INT	16H
		OR	AX,AX			;��CTRL+BREAK?
		JZ	L_80
L_50:
		CALL	S_TX			;����ͼ���ӡ
		MOV	CX,D_SPC		;��߿���
		OR	CX,CX
		JZ	L_70
		SHL	CX,1
		ADD	CX,D_SPC		;CX*3
		XOR	AL,AL
L_60:
		CALL	S_PAL			;�����
		LOOP	L_60
L_70:
		CALL	S_CL			;����һ��
		POP	CX
		LOOP	L_40
L_80:
		CALL	S_SX			;����˫���ӡ
L_90:
		POP	DX
		POP	CX
		POP	BX
		POP	AX
		POP	DI
		POP	SI
		POP	BP
		POP	ES
		POP	DS
		IRET
INT_5		ENDP

;�ӳ���:����һ��
S_CL		PROC	NEAR
		PUSH	CX
		PUSH	DI
		MOV	CX,D_RIGHT
		SUB	CX,D_LEFT
		INC	CX			;ÿ���ֽ���
L_CL1:
		PUSH	CX
		MOV	CL,8			;ÿ�ֽ�8λ
L_CL2:
		MOV	DX,24
		PUSH	DI
		XOR	AX,AX
		MOV	DS:[0],AX
		MOV	DS:[2],AL
L_CL3:
		CALL	S_DL			;����һ��
		ADD	DI,80			;ָ����һ��
		CMP	DI,D_DI
		JAE	L_CL3A
		OR	DL,DL			;�д�����24��?
		JNZ	L_CL3
L_CL3A:
		PUSH	CX
		MOV	CX,D_FDBS		;�Ŵ���
L_CL4:
		MOV	AL,DS:[0]
		CALL	S_PAL			;���һ�ֽ�ͼ������
		MOV	AL,DS:[1]
		CALL	S_PAL			;���һ�ֽ�ͼ������
		MOV	AL,DS:[2]
		CALL	S_PAL			;���һ�ֽ�ͼ������
		LOOP	L_CL4

		POP	CX
		POP	DI
		LOOP	L_CL2

		INC	DI
		POP	CX
		LOOP	L_CL1

		POP	DI
		CALL	S_ZZ			;��ֽ
		MOV	AX,24
		DIV	BYTE PTR D_FDBS 		 ;�Ŵ���
		MOV	DL,80
		MUL	DL
		ADD	DI,AX
		POP	CX
		RET
S_CL		ENDP

;�ӳ���:����һ��
S_DL		PROC	NEAR
		PUSH	AX
		PUSH	DX
		CALL	S_AL			;����һ�ֽ�-AL
		MOV	BH,AL
		MOV	BL,BYTE PTR D_FDBS		 ;�Ŵ���
		POP	DX
		POP	AX
L_DL1:
		MOV	AH,BH
		SHR	AH,CL			;�Ƴ�ָ��λ
		RCL	AL,1			;����AL
		DEC	DL			;����-1
		TEST	DL,7			;�����ֽ�?
		JNZ	L_DL2
		PUSH	AX
		MOV	AL,DH			;�ֽ���(0~2)
		XOR	AH,AH
		MOV	SI,AX
		POP	AX
		MOV	DS:[SI],AL		;����->DS:0~2
		INC	DH
L_DL2:
		DEC	BL
		JNZ	L_DL1
		RET
S_DL		ENDP

;�ӳ���:����һ�ֽ�-AL
S_AL		PROC	NEAR
		XOR	AL,AL
		TEST	D_FSWX,1		;�з�ɫ���߷�ʽ
		JNZ	L_AL1
		XOR	BL,BL
		XOR	AH,AH
		CALL	S_AH			;ȡָ��λ��AH�ֽ�-AH
		OR	AL,AH
		NOT	AH
		OR	BL,AH
		MOV	AH,1
		CALL	S_AH			;ȡָ��λ��AH�ֽ�-AH
		OR	AL,AH
		NOT	AH
		OR	BL,AH
		MOV	AH,2
		CALL	S_AH			;ȡָ��λ��AH�ֽ�-AH
		OR	AL,AH
		NOT	AH
		OR	BL,AH
		MOV	AH,3
		CALL	S_AH			;ȡָ��λ��AH�ֽ�-AH
		OR	AL,AH
		NOT	AH
		OR	BL,AH
		TEST	D_FSWX,2
		JZ	L_AL0
		MOV	AL,BL
L_AL0:
		RET
L_AL1:
		PUSH	CX
		MOV	CL,DL
		MOV	BX,8080H
		ROR	BH,CL
		ROL	BL,CL
		XOR	AH,AH
		CALL	S_AH			;ȡָ��λ��AH�ֽ�-AH
		AND	AH,BH
		OR	AL,AH
		MOV	AH,1
		CALL	S_AH			;ȡָ��λ��AH�ֽ�-AH
		AND	AH,88H
		OR	AL,AH
		MOV	AH,2
		CALL	S_AH			;ȡָ��λ��AH�ֽ�-AH
		AND	AH,BL
		OR	AL,AH
		MOV	AH,3
		CALL	S_AH			;ȡָ��λ��AH�ֽ�-AH
		OR	AL,AH
		POP	CX
		RET
S_AL		ENDP

;�ӳ���:ȡָ��λ��AH�ֽ�-AH
S_AH		PROC	NEAR
		PUSH	AX
		MOV	AL,4
		MOV	DX,3CEH
		OUT	DX,AX
		POP	AX
		MOV	AH,ES:[DI]
		RET
S_AH		ENDP

S_ZZ		PROC	NEAR
		MOV	SI,OFFSET D_ZZ		;��ֽ
		JMP	SHORT L_ZZ1
S_DX:
		MOV	SI,OFFSET D_DX		;����
		JMP	SHORT L_ZZ1
S_SX:
		MOV	SI,OFFSET D_SX		;˫��
		JMP	SHORT L_ZZ1
S_TX:
		MOV	SI,OFFSET D_TX		;ͼ���ӡ
L_ZZ1:
		LODSB
		CMP	AL,'$'
		JZ	L_ZZ2
		CALL	S_PAL
		JMP	SHORT L_ZZ1
L_ZZ2:
		RET
S_ZZ		ENDP

;�ӳ���:���һ�ֽ�
S_PAL		PROC	NEAR
		XOR	AH,AH
		PUSH	DX
		XOR	DX,DX
		INT	17H
		POP	DX
		RET
S_PAL		ENDP

;----------------------------------------------------------------------------
BEGIN:
		MOV	SI,5DH
		MOV	AX,CS
		CMP	AX,0A000H		;��LH?
		JB	L_S10
		MOV	SI,6DH
L_S10:
		MOV	AX,3505H
		INT	21H
		CMP	BYTE PTR DS:[SI],' '    ;�޲���?
		JZ	L_S100

		CMP	BX,OFFSET INT_5 	;����פ��?
		JNZ	L_S20
		CMP	BYTE PTR DS:[SI],'0'    ;�˳���ģ��
		JNZ	L_S14
		LDS	DX,ES:D_INT5
		MOV	AX,2505H		;�ָ�INT5
		INT	21H
		MOV	AH,49H			;���ڴ�
		INT	21H
		MOV	ES,ES:[2CH]
		MOV	AH,49H
		INT	21H
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET QUIT
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_S14:
		MOV	DX,OFFSET ALREADY
		JMP	SHORT L_ERR
L_S20:
		MOV	WORD PTR D_INT5,BX
		MOV	WORD PTR D_INT5+2,ES

		MOV	AL,DS:[SI]
		CMP	AL,'1'
		JB	L_S40
		CMP	AL,'4'
		JBE	L_S50
L_S40:
		MOV	AL,'2'
L_S50:
		AND	AL,0FH
		MOV	BYTE PTR D_FDBS,AL		 ;�Ŵ���

		MOV	AL,[SI+1]
		CMP	AL,' '
		JZ	L_S60
		MOV	D_FSWX,AL
L_S60:
		MOV	DX,OFFSET INT_5
		MOV	AX,2505H
		INT	21H
		MOV	WORD PTR DS:[100H],'EP' ;PEGA��־
		MOV	BYTE PTR DS:[102H],'G'

		MOV	DX,OFFSET BEGIN
		INT	27H
L_S100:
		CMP	WORD PTR ES:[100H],'EP' ;��PEGA?
		JNZ	L_S105
		CMP	BYTE PTR ES:[102H],'G'
		JZ	L_S110
L_S105:
		MOV	DX,OFFSET NOPEGA
		JMP	L_ERR
L_S110:
		MOV	AL,ES:[107H]		;�Ŵ���
		OR	AL,30H
		MOV	D_FD[19],AL
		MOV	AL,ES:[109H]		;��ɫ����
		OR	AL,30H
		MOV	D_FS[19],AL
		MOV	AX,ES:[10AH]		;��߿���
		MOV	SI,OFFSET D_ZK+22
		MOV	CX,4
		CALL	S_JS
		MOV	AX,ES:[10CH]		;�����
		MOV	SI,OFFSET D_ZB+20
		MOV	CX,2
		CALL	S_JS
		MOV	AX,ES:[10EH]		;�ұ���
		MOV	SI,OFFSET D_YB+20
		MOV	CX,2
		CALL	S_JS
		MOV	AX,ES:[110H]		;�ϱ���
		MOV	SI,OFFSET D_SB+21
		MOV	CX,3
		CALL	S_JS
		MOV	AX,ES:[112H]		;�±���
		MOV	SI,OFFSET D_XB+21
		MOV	CX,3
		CALL	S_JS

		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
L_S120:
		MOV	DX,OFFSET D_XZ
		MOV	AH,9
		INT	21H
		MOV	AH,1			;����
		INT	21H
		CMP	AL,0DH			;�س�?
		JNZ	L_S122
		CALL	S_0D0A			;��ʾ�س�����
		JMP	SHORT L_S110
L_S122:
		CMP	AL,1BH			;<ESC>?
		JNZ	L_S130
		INT	20H
L_S130:
		CMP	AL,'1'                  ;�Ŵ���
		JNZ	L_S140
		MOV	SI,OFFSET D_FD
		CALL	S_INPUT
		JB	L_S131
		AND	AL,0FH
		CMP	AL,1
		JB	L_S131
		CMP	AL,4
		JA	L_S131
		MOV	ES:[107H],AL
L_S131:
		JMP	L_S120
L_S140:
		CMP	AL,'2'                  ;��ɫ����
		JNZ	L_S150
		MOV	SI,OFFSET D_FS
		CALL	S_INPUT
		JB	L_S141
		AND	AL,0FH
		MOV	ES:[109H],AL
L_S141:
		JMP	L_S120
L_S150:
		CMP	AL,'3'                  ;��߿���
		JNZ	L_S160
		MOV	SI,OFFSET D_ZK
		CALL	S_INPUT
		JB	L_S151
		MOV	ES:[10AH],AX
L_S151:
		JMP	L_S120
L_S160:
		CMP	AL,'4'                  ;�����
		JNZ	L_S170
		MOV	SI,OFFSET D_ZB
		CALL	S_INPUT
		JB	L_S161
		MOV	ES:[10CH],AX
L_S161:
		JMP	L_S120
L_S170:
		CMP	AL,'5'                  ;�ұ���
		JNZ	L_S180
		MOV	SI,OFFSET D_YB
		CALL	S_INPUT
		JB	L_S171
		MOV	ES:[10EH],AX
L_S171:
		JMP	L_S120
L_S180:
		CMP	AL,'6'                  ;�ϱ���
		JNZ	L_S190
		MOV	SI,OFFSET D_SB
		CALL	S_INPUT
		JB	L_S181
		MOV	ES:[110H],AX
L_S181:
		JMP	L_S120
L_S190:
		CMP	AL,'7'                  ;�±���
		JNZ	L_S191
		MOV	SI,OFFSET D_XB
		CALL	S_INPUT
		JB	L_S191
		MOV	ES:[112H],AX
L_S191:
		JMP	L_S120

;�ӳ���:��ʾ������ SI-��ʾ���� ����AX-����ֵ
S_INPUT 	PROC	NEAR
		CALL	S_0D0A

		MOV	AH,2
L_IN1:
		LODSB
		MOV	DL,AL
		INT	21H
		CMP	AL,':'
		JNZ	L_IN1

		MOV	DX,OFFSET D_0AH
		MOV	SI,DX
		MOV	AH,0AH			;���볤��
		INT	21H
		CALL	S_0D0A
		INC	SI
		LODSB				;ȡ�����ַ���
		OR	AL,AL
		JZ	L_IN3
		CBW
		MOV	CX,AX
		MOV	BX,10
		XOR	AX,AX
L_IN2:
		MUL	BX			;ԭ��*10
		PUSH	AX
		LODSB				;ȡһ����
		AND	AL,0FH
		CBW
		POP	DX
		ADD	AX,DX			;��
		LOOP	L_IN2
		CLC
		RET
L_IN3:
		STC
		RET
S_INPUT 	ENDP

S_0D0A		PROC	NEAR
		MOV	AX,0E0DH
		INT	10H
		MOV	AX,0E0AH
		INT	10H
		RET
S_0D0A		ENDP

S_JS		PROC	NEAR
		MOV	BX,10
L_JS1:
		XOR	DX,DX
		DIV	BX
		OR	DL,30H
		MOV	[SI],DL
		DEC	SI
		LOOP	L_JS1
		RET
S_JS		ENDP

MSG		DB	13,10
		DB	'��Ļ����ģ��PEGA��������',13,10
		DB	'------------------------',13,10
D_FD		DB	'1-�Ŵ���(������):2',13,10
D_FS		DB	'2-��ɫ����1, ����2:0',13,10
D_ZK		DB	'3-��߿���(0-2000):0000',13,10
D_ZB		DB	'4-�� �� ��(�ַ�λ):00',13,10
D_YB		DB	'5-�� �� ��(�ַ�λ):79',13,10
D_SB		DB	'6-�� �� ��(ɨ����):000',13,10
D_XB		DB	'7-�� �� ��(ɨ����):479',13,10
		DB	'�س�--����',13,10
		DB	'<ESC>-�˳�',13,10,'$'
D_XZ		DB	'��ѡ��:$'
D_0AH		DB	5,0,0,0,0,0,0,0
NOPEGA		DB	'û�а�װPEGA��Ļ����ģ��!',7,13,10
		DB	'��ʽ:PEGA ab',13,10
		DB	'����:aΪ�Ŵ���(1~4,=0�����ģ��)',13,10
		DB	'     b=1Ϊ��ɫ���߷�ʽ',13,10
		DB	'��װ֮�����ñ������޸Ĺ�������.',13,10,'$'
ALREADY 	DB	'PEGA IS ALREADY!',7,13,10,'$'
QUIT		DB	'�˳���Ļ����ģ��,�ָ�ԭINT5�ж�.',7,13,10,'$'

SEG_A		ENDS
		END	START

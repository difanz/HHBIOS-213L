;	DUMP.ASM
;	1997.6.27, 7.4

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

D_INT25 	DD	0			;�߼�������
		DW	1			;������
		DW	OFFSET D_BUF
D_CS		DW	0

D_HAN		DW	0			;�ļ���
D_END		DW	OFFSET D_BUF+200H	;������β
D_LEN		DW	0			;��������
D_XX		DW	0,0			;�ļ�����
D_AX		DW	0			;�ļ�λ��
D_DX		DW	0
D_COM		DB	0			;COM�ļ���־

MSG		DB	'Display disk boot sector or file.',13,10
		DB	'STYLE: DUMP [d:] or DUMP [d:][path][filename] or [seg:off]',13,10
		DB	'Display: <backspace> - back 128 bytes.',13,10
		DB	'         <tab> ------- next 1000H bytes.',13,10
		DB	'         <`> --------- next 32K bytes.',13,10
		DB	'         othe key ---- next 128 bytes.$'
GSERR		DB	'SYNTAX ERROR!',7,13,10,'$'
D_FILE		DB	'File name is $'
D_BOOT		DB	'The hard disk BOOT:',13,10,'$'
D_BOOT1 	DB	'A: disk BOOT:',13,10,'$'

BEGIN:
		MOV	SI,80H
		LODSB
		OR	AL,AL			;=0:�޲���
		JNZ	L_10
		MOV	DL,80H
		MOV	AX,201H
		MOV	BX,OFFSET D_BUF
		MOV	CX,1
		XOR	DH,DH
		INT	13H			;��Ӳ����BOOT
		JNC	L_8
		JMP	L_ERR1
L_8:
		MOV	DX,OFFSET D_BOOT
		JMP	L_30
L_10:
		CBW
		MOV	BX,AX
		MOV	BYTE PTR [BX+SI],0	;�ļ���β
L_12:
		LODSB
		CMP	AL,' '
		JZ	L_12
		CMP	AL,'/'
		JNZ	L_13
		CMP	BYTE PTR [SI],'?'       ;��ʾ����
		JNZ	L_13
		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
		JMP	L_EXIT
L_13:
		DEC	SI
		MOV	DX,SI
		MOV	AX,3D00H		;���ļ�
		INT	21H
		JB	L_20
		MOV	D_HAN,AX
		MOV	BX,AX
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4202H		;ȡ�ļ�����
		INT	21H
		MOV	D_XX,AX 		;����
		MOV	D_XX+2,DX
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4200H		;�Ƶ��ļ���
		INT	21H

		MOV	DX,OFFSET D_FILE	;'File name is $'
		MOV	AH,9
		INT	21H
L_15:
		LODSB
		OR	AL,AL
		JZ	L_16
		CALL	S_XSAL			;��ʾ�ļ���
		JMP	SHORT L_15
L_16:
		SUB	SI,4			;����չ����
		LODSB
		AND	AL,5FH
		CMP	AL,'C'                  ;��.COM�ļ�?
		JNZ	L_17
		LODSB
		AND	AL,5FH
		CMP	AL,'O'
		JNZ	L_17
		LODSB
		AND	AL,5FH
		CMP	AL,'M'
		JNZ	L_17
		MOV	D_COM,1 		;�ñ�־
L_17:
		CALL	S_XS2KG 		;��ʾ˫�ո�
		MOV	AX,D_XX+2
		CALL	S_HEXAX 		;��ʾ��
		MOV	AL,':'
		CALL	S_XS1			;��ʾð��
		MOV	AX,D_XX
		CALL	S_HEXAX 		;��ʾƫ��
		CALL	S_0D0A			;�س�����
L_18:
		MOV	BX,D_HAN
		MOV	DX,OFFSET D_BUF
		MOV	CX,8000H
		MOV	AH,3FH			;���ļ�
		INT	21H
		MOV	D_LEN,AX		;��������
		ADD	AX,DX
		MOV	D_END,AX		;��ʾ��β
		JMP	SHORT L_31
L_20:
		MOV	SI,81H
L_21:
		LODSB
		CMP	AL,' '
		JBE	L_21
		CMP	BYTE PTR [SI],':'       ;���̷�?
		JNZ	L_23
		AND	AL,5FH
		CMP	AL,'A'
		JB	L_23
		CMP	AL,'Z'
		JBE	L_26
L_23:
		DEC	SI
		CALL	S_JSHEX 		;����ʮ��������-DX
		JB	L_23A
		CMP	AL,0DH			;�лس�?
		JZ	L_24
		MOV	D_DX,DX 		;��
		CALL	S_JSHEX 		;����ʮ��������-DX
		JMP	SHORT L_25
L_23A:
		MOV	DX,OFFSET GSERR
		JMP	L_ERR
L_24:
		MOV	D_DX,0			;Ĭ�϶�=0
L_25:
		MOV	D_AX,DX 		;ƫ��
		MOV	SI,DX
		MOV	D_END,-1		;�ڴ��־
		JMP	L_32
L_26:
		MOV	AL,DS:[5CH]		;ȡ�̷�
		DEC	AX
		ADD	D_BOOT1,AL
		MOV	BX,OFFSET D_BUF
		MOV	CX,1
		XOR	DX,DX
		INT	25H			;���ϸ�ʽ��BOOT
		POP	DX
		JNC	L_28
		MOV	D_CS,CS
		MOV	BX,OFFSET D_INT25
		MOV	CX,-1
		INT	25H			;���¸�ʽ��BOOT
		POP	DX
		JNC	L_28
		JMP	L_ERR1
L_28:
		MOV	DX,OFFSET D_BOOT1	;'A: disk BOOT:',13,10,'$'
L_30:
		MOV	AH,9
		INT	21H
L_31:
		MOV	D_DX,CS
		MOV	SI,OFFSET D_BUF 	;��������
L_32:
		CALL	S_XS8H			;��ʾ����
		CMP	CS:D_END,-1		;�ڴ�?
		JZ	L_33
		CMP	SI,D_END		;��������β?
		JB	L_33
L_32A:
		CMP	D_HAN,0 		;���ļ�?
		JZ	L_40
		CMP	D_LEN,8000H		;��32K?
		JB	L_40
L_32B:
		MOV	AX,D_LEN		;��������
		ADD	D_AX,AX 		;��ַָ��
		ADC	D_DX,0
		JMP	L_18
L_33:
		XOR	AH,AH			;����
		INT	16H
		CMP	AL,8			;�˸�-��һ128�ֽ�?
		JNZ	L_34
		CMP	SI,OFFSET D_BUF+80H	;��<=128
		JBE	L_33
		SUB	SI,100H 		;ǰ��?
		JMP	SHORT L_32
L_34:
		CMP	AL,9			;����-��һ1000H�ֽ�?
		JNZ	L_35
		ADD	SI,1000H		;����
		CMP	CS:D_END,-1		;���ڴ�?
		JZ	L_32
		CMP	SI,D_END		;���ļ�β?
		JB	L_32
		JMP	SHORT L_32A
L_35:
		CMP	AL,'`'                  ;��һ32K�ֽ�?
		JZ	L_32A
		CMP	AL,1BH			;��ESC?
		JZ	L_40
		JMP	SHORT L_32
L_40:
		XOR	AL,AL
L_EXIT:
		MOV	AH,4CH			;�������
		INT	21H
L_ERR:
		MOV	AH,9
		INT	21H
L_ERR1:
		MOV	AL,-1
		JMP	SHORT L_EXIT

;�ӳ���:��ʾ8��
S_XS8H		PROC	NEAR
		MOV	CX,8			;����
L_81:
		PUSH	CX
		MOV	AX,CS:D_DX		;��
		MOV	DS,AX
		CALL	S_HEXAX 		;��ʾ��ǰ��
		MOV	AL,':'
		CALL	S_XS1			;��ʾð��
		MOV	AX,SI
		CMP	CS:D_END,-1		;���ڴ�?
		JZ	L_81A
		SUB	AX,OFFSET D_BUF
		ADD	AX,CS:D_AX
		CMP	CS:D_COM,1		;��.COM�ļ�?
		JNZ	L_81A
		ADD	AX,100H
L_81A:
		CALL	S_HEXAX 		;��ʾ��ǰ��ַ
		CALL	S_XS2KG 		;��ʾ˫�ո�

		PUSH	SI
		MOV	CL,16
L_82:
		LODSB
		CALL	S_HEXAL 		;��ʾ�ֽ�����

		MOV	AL,' '
		CMP	CL,9
		JNZ	L_83
		MOV	AL,'-'
L_83:
		CALL	S_XS1			;��ʾ�ָ���
		LOOP	L_82
		POP	SI

		CALL	S_XS2KG 		;��ʾ˫�ո�
		MOV	CL,16
L_84:
		LODSB
		CMP	AL,' '
		JB	L_85
		CMP	AL,7FH
		JB	L_86
		CMP	AL,0A0H
		JA	L_86
L_85:
		MOV	AL,'.'
L_86:
		CALL	S_XSAL			;��ʾ�ַ�
		LOOP	L_84
		POP	CX

		CMP	CS:D_END,-1		;���ڴ�?
		JZ	L_87
		CMP	SI,D_END		;��������β?
		JAE	L_90
L_87:
		CALL	S_0D0A			;�س�����
		LOOP	L_81
L_90:
		CALL	S_0D0A			;�س�����
		PUSH	CS
		POP	DS
		RET
S_XS8H		ENDP

;�ӳ���:��ʾ˫�ո�
S_XS2KG 	PROC	NEAR
		MOV	AL,' '
		CALL	S_XSAL
		MOV	AL,' '
;�ӳ���:��ʾAL
S_XSAL:
		CMP	CS:D_END,-1		;���ڴ�?
		JZ	S_XS1
		CMP	SI,D_END		;��������β?
		JBE	S_XS1
		MOV	AL,' '
S_XS1:
		CMP	AL,' '
		JB	S_XS2
		PUSH	CX
		MOV	BX,7
		MOV	CX,1
		MOV	AH,9
		INT	10H
		POP	CX
S_XS2:
		MOV	AH,0EH
		INT	10H
		RET
S_XS2KG 	ENDP

;�ӳ���:�س�����
S_0D0A		PROC	NEAR
		MOV	AX,0E0DH
		INT	10H
		MOV	AL,0AH
		INT	10H
		RET
S_0D0A		ENDP

;�ӳ���:��ʾʮ������AX
S_HEXAX 	PROC	NEAR
		PUSH	AX
		MOV	AL,AH
		CALL	S_HEXAL
		POP	AX
;�ӳ���:��ʾʮ������AL
S_HEXAL:
		PUSH	AX
		SHR	AL,1
		SHR	AL,1
		SHR	AL,1
		SHR	AL,1
		CALL	S_HEXAL1
		POP	AX
		AND	AL,0FH
;�ӳ���:��ʾʮ������AL�Ͱ�λ
S_HEXAL1:
		OR	AL,'0'
		CMP	AL,'9'
		JBE	L_HEX1
		ADD	AL,7
L_HEX1:
		JMP	S_XSAL
S_HEXAX 	ENDP

;�ӳ���:����ʮ��������->DX
S_JSHEX 	PROC	NEAR
		XOR	DX,DX
L_JS0:
		LODSB
		CMP	AL,':'                  ;�ηָ���
		JZ	L_JS9
		CMP	AL,0DH			;��ַ����
		JZ	L_JS9
		CMP	AL,'0'                  ;������?
		JB	L_JSERR
		CMP	AL,'9'
		JA	L_JS1
		AND	AL,0FH
		JMP	SHORT L_JS2
L_JS1:
		AND	AL,5FH
		CMP	AL,'A'                  ;��A~F?
		JB	L_JSERR
		CMP	AL,'F'
		JA	L_JSERR
		SUB	AL,'A'
		ADD	AL,10
L_JS2:
		CBW
		PUSH	AX
		MOV	AX,16
		MUL	DX
		POP	CX
		ADD	AX,CX
		MOV	DX,AX
		JMP	SHORT L_JS0
L_JS9:
		CLC
		RET
L_JSERR:
		STC
		RET
S_JSHEX 	ENDP

D_BUF	EQU	$				;������

SEG_A		ENDS
		END	START

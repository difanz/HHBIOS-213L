;	AH0E.INC
;	1994.7.23

;AH=0EH ��ʾ�ַ����ƽ����
L_AH0E: 	MOV	DX,DS:[450H]
		CMP	AL,8			;�˸�?
		JZ	L_0E06
		CMP	AL,0AH			;����?
		JZ	L_0E02
		CMP	AL,0DH			;�س�?
		JZ	L_0E05
		CMP	AL,' '                  ;�����ַ�?
		JAE	L_0E01
		JMP	L_INT10 		;��ԭINT10
L_0E01: 	MOV	AH,0AH
		MOV	CX,1
		INT	10H			;��ʾ�ַ�
		INC	DL			;��+1
		CMP	DL,80			;����β?
		JNZ	L_0E04
		XOR	DL,DL			;����
L_0E02: 	CMP	DH,18H			;����β?
		JB	L_0E03
		MOV	AH,8
		INT	10H			;ȡ��ǰλ������BH
		MOV	BH,AH
		XOR	CX,CX			;��Ļ���Ͻ�
		MOV	DX,184FH		;    ���½�
		MOV	AX,601H
		INT	10H			;��Ļ�Ϲ�һ��
		XOR	DL,DL			;����
		JMP	SHORT L_0E04
L_0E03: 	INC	DH			;��+1
L_0E04: 	MOV	DS:[450H],DX
		CALL	S_GB			;��궨λ
		JMP	L_RET			;����
L_0E05: 	XOR	DL,DL			;����
		JMP	SHORT L_0E04
L_0E06: 	OR	DL,DL			;������?
		JZ	L_0E04
		DEC	DL			;��-1
		JMP	SHORT L_0E04


;	AH13.INC
;	1994.7.23

;AH=13H ��ʾ�ַ��� ES:BP=�ַ�����ַ, DX=λ��, CX=����
;		   AL=0 BL=���� ��ʾ���겻��
;		   AL=1 BL=���� ��ʾ�����ƴ�β
;		   AL=2 �������� ��ʾ���겻��
;		   AL=3 �������� ��ʾ�����ƴ�β
;		   AL=4 BL=���� ����0��β ��ʾ�����ƴ�β
;		   AL=5 BL=������ DX=����λ�� CX=���� ��ʾ��ԭ���λ�ò���
L_AH13: 	PUSH	ES
		CALL	S_QGB			;�ع��
		POP	ES
		SHL	BYTE PTR CS:[101H],1	;������λ
		CMP	AL,4			;��ʽ=4?
		JZ	L_1302
L_1301: 	OR	CX,CX			;����>0?
		JNZ	L_1302
		JMP	L_1308
L_1302: 	MOV	SI,DS:[450H]		;ȡ��ǰ���λ��
		PUSH	AX
		MOV	AH,2			;��궨λ
		INT	10H
		POP	AX
L_1303: 	PUSH	CX
		PUSH	BX
		PUSH	AX
		MOV	AH,AL			;��ʽ��
		CMP	AL,5
		JNZ	L_1303A
		MOV	AH,8			;ȡ��ǰ���λ���ַ�
		INT	10H
		JMP	SHORT L_1303B
L_1303A:	MOV	AL,ES:[BP]		;ȡһ�ַ�
		INC	BP
		CMP	AX,400H 		;��ʽ4:AL=0(����)
		JZ	L_1308A
L_1303B:	CMP	AL,8			;���˸�?
		JZ	L_1304
		CMP	AL,0DH			;�ǻس�?
		JZ	L_1304
		CMP	AL,0AH			;�ǻ���?
		JZ	L_1304
		CMP	AL,7			;������?
		JNZ	L_1305
L_1304: 	MOV	AH,0EH			;ִ��
		INT	10H
		MOV	DX,DS:[450H]		;ȡ��ǰ���λ��
		JMP	SHORT L_1307
L_1305: 	MOV	CX,1
		CMP	AH,4
		JNB	L_1306
		CMP	AH,2			;��ʽ=2,3?
		JB	L_1306
		MOV	BL,ES:[BP]		;ȡ����
		INC	BP
L_1306: 	MOV	AH,9			;��ʾ�ַ�
		INT	10H
		INC	DL			;��λ��+1
		CMP	DL,80			;����β?
		JB	L_1307
		XOR	DL,DL			;����
		INC	DH			;��+1
		CMP	DH,25			;��β?
		JB	L_1307
		DEC	DH
L_1307: 	MOV	AH,2			;��궨λ
		INT	10H
		POP	AX
		POP	BX
		POP	CX
		CMP	AL,4
		JZ	L_1303
		LOOP	L_1303
		CMP	AL,1			;��ʽ=1
		JZ	L_1308
		CMP	AL,3			;��ʽ=3
		JZ	L_1308
L_1307A:	MOV	DX,SI			;�ָ�ԭ���
		MOV	AH,2
		INT	10H
L_1308: 	SHR	BYTE PTR CS:[101H],1	;�ָ����λ
		CALL	S_GB			;�ָ����
		JMP	L_RET
L_1308A:	POP	AX
		POP	BX
		POP	CX
		JMP	SHORT L_1308


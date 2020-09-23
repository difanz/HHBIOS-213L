;	CSP.ASM �¸�ʽ˫ƴ����
;	1995.3.15
;	1996.1.29, 3.15, 3.31
;	1998.8.9

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

D_FILE1 	DB	'\SPCZ.DAT',0
D_END		DW	0			;˫ƴ����β
D_NUM		DW	0			;˫ƴ��չ������
WRITERR 	DB	'�ļ�д����!',7,13,10,'$'
NO213		DB	'���� 2.13L ����ϵͳ!',7,13,10,'$'
NOSPCZ		DB	'δ��װ˫ƴ����!',7,13,10,'$'

D_COMM		DB	'�� ESC-�������˳�, �س�-��ʾ��չ����, 1-����, 2-ɾ��, 0-�����˳� �� $'
D_INPUT 	DB	'�������չ����: $'
D_DEL		DB	'�����ɾ���������: $'
D_INKEY 	DB	255,0,256 DUP(0)	;���뻺����
D_STR1		DB	'˫ƴ��չ���鹲 000 ��:',13,10,'$'
D_XSNUM 	DB	'000:$'
D_MSG		DB	'2.13L ˫ƴ��չ����������� 1998.8.9',13,10,'$'

;****************************************************************************
BEGIN:
		XOR	BP,BP
		MOV	AH,2FH			;ȡ2.13��װ�̼�·��BP:DX
		INT	16H
		OR	BP,BP			;��2.13L?
		JNZ	L_10
		MOV	DX,OFFSET NO213
		JMP	L_ERR
L_10:
		PUSH	DI
		MOV	DS,BP			;����ģ���
		MOV	SI,DX			;
		MOV	DI,0A0H
L_12:
		LODSB				;ȡ��·��
		OR	AL,AL
		JZ	L_20
		STOSB				;����·��
		JMP	SHORT L_12
L_20:
		PUSH	CS
		POP	DS
		MOV	SI,OFFSET D_FILE1	;'\SPCZ.DAT',0
		MOV	CX,10
		REP	MOVSB			;�γ��ļ�ȫ��
		POP	DI

		MOV	ES,BP
		MOV	BX,ES:[DI+18]		;˫ƴ�����
		OR	BX,BX			;=0:δ��װ?
		JNZ	L_22
		MOV	DX,OFFSET NOSPCZ
		JMP	L_ERR
L_22:
		MOV	DX,OFFSET D_MSG
		MOV	AH,9			;��ʾ����������
		INT	21H

		MOV	DS,BX			;˫ƴ�����
		PUSH	DS
		POP	ES
		CALL	S_CL			;˫ƴ��չ���鴦��
		JNB	L_25
		JMP	L_EXIT1
L_25:
		XOR	SI,SI
		MOV	AX,CS
		ADD	AX,1000H		;��һ64K��
		MOV	ES,AX
		XOR	DI,DI
		MOV	CX,DS:[4]		;˫ƴ����234�ִ�β
		REP	MOVSB			;���ͻ���˫ƴ����
		XOR	AX,AX
		STOSW				;������־
		MOV	CS:D_END,DI		;β
		PUSH	DS
		PUSH	ES
		POP	DS			;DS:0-������
		POP	ES			;ES:0-ԭSPCZ

		MOV	SI,ES:[4]		;��չ����
L_30:
		CMP	SI,ES:[6]		;����չ��β?
		JNZ	L_31
		JMP	L_60
L_31:
		MOV	DX,ES:[SI]		;����
		AND	DX,7F7FH
		MOV	BP,SI			;����
L_32:
		INC	SI
		CMP	BYTE PTR ES:[SI],','    ;�д�β?                3.15
		JNZ	L_32
		MOV	BX,SI
		SUB	BX,BP

		CMP	BX,4			;�ж��ִ�?
		JNZ	L_40
		MOV	DI,16			;���ִ���
L_33:
		CMP	DI,DS:[0]		;�ж��ִ�β?
		JZ	L_37
		CMP	DX,DS:[DI]		;������?
		JZ	L_35
L_34:
		ADD	DI,2
		TEST	WORD PTR DS:[DI],8080H	;����һ����?
		JNZ	L_34
		JMP	SHORT L_33
L_35:
		MOV	BX,2			;���Ƴ���
		CALL	S_MOVE			;����
L_36:
		ADD	DI,2
		MOV	AX,ES:[SI-2]		;ȡ�ڶ���
		MOV	DS:[DI],AX		;д��
		INC	SI
		JMP	SHORT L_30
L_37:
		MOV	BX,4
		CALL	S_MOVE			;����4�ֽ�
		MOV	DS:[DI],DX		;��������
		JMP	SHORT L_36
L_40:
		CMP	BX,6			;������?
		JNZ	L_50
		MOV	DI,DS:[0]		;���ִ���
L_42:
		CMP	DI,DS:[2]		;�����ִ�β?
		JZ	L_46
		CMP	DX,DS:[DI]		;������?
		JZ	L_46
		ADD	DI,BX
		JMP	SHORT L_42
L_46:
		CALL	S_MOVE			;����6�ֽ�
		MOV	DS:[DI],DX		;д������
		MOV	AX,ES:[SI-4]
		MOV	DS:[DI+2],AX		;д��ڶ���
		MOV	AX,ES:[SI-2]
		MOV	DS:[DI+4],AX		;д�������
		INC	SI
		JMP	L_30
L_50:
		OR	DX,8080H
		MOV	DI,DS:[2]		;���ִ���
L_51:
		CMP	DI,DS:[4]		;�ж��ִ�β?
		JZ	L_54
		CMP	DX,DS:[DI]		;������?
		JZ	L_54
L_52:
		CMP	BYTE PTR DS:[DI],','    ;�д�β?
		JZ	L_52A
		INC	DI
		JMP	SHORT L_52
L_52A:
		INC	DI
		JMP	SHORT L_51
L_54:
		INC	BX
		CALL	S_MOVE			;����
		PUSH	SI			;8.7
		MOV	SI,BP			;����
		DEC	BX
		MOV	CX,BX
		PUSH	DS
		PUSH	ES
		PUSH	DS
		PUSH	ES
		POP	DS
		POP	ES
		REP	MOVSB			;д��
		MOV	AL,','
		STOSB
		POP	ES
		POP	DS
		POP	SI			;8.7
		INC	SI
		JMP	L_30
L_60:
		MOV	AX,DS:[4]
		MOV	DS:[6],AX
		MOV	WORD PTR DS:[8],0
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,0A0H 		;�ļ�����
		MOV	CX,20H
		MOV	AH,3CH			;����˫ƴ�����ļ�
		INT	21H
		POP	DS
		JB	L_WERR
		MOV	BX,AX
		MOV	DX,0			;˫ƴ�����ļ���ַ
		MOV	CX,DS:[4]		;˫ƴ����β
		SUB	CX,DX			;����
		MOV	AH,40H			;д��
		INT	21H
		JB	L_WERR
		MOV	AH,3EH			;�ر�
		INT	21H
		XOR	AL,AL
		JMP	SHORT L_EXIT
L_WERR:
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET WRITERR
L_ERR:
		MOV	AH,9
		INT	21H
L_EXIT1:
		MOV	AL,1
L_EXIT:
		MOV	AH,4CH
		INT	21H

;�ӳ���:�س�����
S_0D0A		PROC	NEAR
		PUSH	AX
		MOV	AH,2
		MOV	DL,0DH
		INT	21H
		MOV	DL,0AH
		INT	21H
		POP	AX
		RET
S_0D0A		ENDP

;�ӳ���:���� BX-�����ֽ���,DI-�����
S_MOVE		PROC	NEAR
		PUSH	SI
		PUSH	DI
		PUSH	ES
		PUSH	DS
		POP	ES
		MOV	SI,CS:D_END	;˫ƴ����β
		MOV	CX,SI
		SUB	CX,DI		;���ͳ���
		INC	CX
		MOV	DI,SI
		ADD	DI,BX
		MOV	CS:D_END,DI
		STD
		REP	MOVSB		;����
		CLD
		CMP	BX,8
		JAE	L_M2
		CMP	BX,6
		JZ	L_M1
		ADD	DS:[0],BX
L_M1:
		ADD	DS:[2],BX
L_M2:
		ADD	DS:[4],BX
		POP	ES
		POP	DI
		POP	SI
		RET
S_MOVE		ENDP

;�ӳ���:˫ƴ��չ���鴦��
S_CL		PROC	NEAR
		XOR	CX,CX			;����
		MOV	SI,DS:[4]		;��չ������
		MOV	DI,OFFSET D_BUF 	;��չ������ַ�����
L_CL1:
		MOV	CS:[DI],SI
		ADD	DI,2
		CMP	SI,DS:[6]		;��β?
		JZ	L_CL2A
		INC	CX
L_CL2:
		LODSB
		CMP	AL,','                  ;�д���β?
		JNZ	L_CL2
		JMP	SHORT L_CL1
L_CL2A:
		MOV	WORD PTR CS:[DI],0	;8.7
		MOV	CS:D_NUM,CX		;����
L_CL3:
		MOV	DX,OFFSET D_COMM
		CALL	S_XSZF			;��ʾ��ʾ
		XOR	AH,AH			;����
		INT	16H
		PUSH	AX
		MOV	AH,2			;��ʾ
		MOV	DL,AL
		INT	21H
		CALL	S_0D0A
		POP	AX

		CMP	AL,1BH			;ESC:�������˳�
		JNZ	L_CL4
		STC
		RET
L_CL4:
		CMP	AL,0DH			;�س�:��ʾ��չ����
		JNZ	L_CL5
L_CL4A:
		CALL	S_XSKZCZ		;��ʾ��չ����
		JMP	L_CL3
L_CL5:
		CMP	AL,'0'                  ;'0':�����˳�
		JNZ	L_CL6
		CLC
		RET
L_CL6:
		CMP	AL,'1'                  ;'1':����
		JNZ	L_CL7
L_CL6A:
		MOV	DX,OFFSET D_INPUT
		CALL	S_XSZF			;��ʾ:'�������չ����: $'
		CALL	S_INPUT 		;������鲢�б�
		JNB	L_CL6B
		OR	CX,CX			;=0:�޼���
		JNZ	L_CL6A
		JMP	L_CL3
L_CL6B:
		MOV	AX,DS:[6]		;��չ����β
		ADD	AX,CX			;+�ʳ�
		ADD	AX,3			;+���ź�2�ո�
		CMP	AX,DS:[8]		;����չ������β?
		JBE	L_CL6C
		MOV	AX,0E07H
		INT	10H
		JMP	L_CL3
L_CL6C:
		MOV	DI,DS:[6]		;ԭ��չ����β
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	BX,D_NUM
		SHL	BX,1
		ADD	BX,OFFSET D_BUF
		MOV	[BX],DI 		;�������
		MOV	WORD PTR [BX+2],0	;8.7
		INC	D_NUM			;������+1

		MOV	SI,OFFSET D_INKEY+2	;���������
		REP	MOVSB			;����
		MOV	AL,','
		STOSB
		POP	DS
		MOV	DS:[6],DI		;����չ����β
		XOR	AX,AX
		STOSW				;β��־
		JMP	L_CL6A
L_CL7:
		CMP	AL,'2'                  ;'2':ɾ��
		JZ	L_CL8
L_CL7A:
		JMP	L_CL3
L_CL8:
		CMP	CS:D_NUM,0
		JZ	L_CL7A
		MOV	DX,OFFSET D_DEL
		CALL	S_XSZF			;��ʾ:�����ɾ���������: $'
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_INKEY
		MOV	SI,DX
		MOV	AH,0AH			;����
		INT	21H
		INC	SI
		LODSB				;ȡ���������
		OR	AL,AL			;=0�޼���?
		JNZ	L_CL8A
		POP	DS
		JMP	L_CL3
L_CL8A:
		MOV	CX,10
L_CL8B:
		LODSB				;ȡһ�ַ�
		CMP	AL,0DH			;����?
		JZ	L_CL8D
		SUB	AL,'0'
		CMP	AL,9
		JBE	L_CL8C
		SUB	AL,7
L_CL8C:
		XCHG	AL,CH
		MUL	CL
		ADD	CH,AL
		JMP	SHORT L_CL8B
L_CL8D:
		MOV	AL,CH			;ɾ�����
		XOR	AH,AH
		DEC	AX
		SHL	AX,1
		ADD	AX,OFFSET D_BUF
		MOV	BX,AX
		MOV	DI,[BX] 		;ɾ������
		MOV	SI,[BX+2]		;��һ����
		MOV	AX,SI
		SUB	AX,DI			;ɾ�����鳤
L_CL8E:
		ADD	BX,2
		CMP	WORD PTR [BX],0
		JZ	L_CL8F
		MOV	DX,[BX]
		SUB	DX,AX
		MOV	[BX-2],DX
		JMP	SHORT L_CL8E
L_CL8F:
		MOV	WORD PTR [BX-2],0
		DEC	D_NUM
		CALL	S_0D0A
		POP	DS
		MOV	CX,DS:[6]		;ԭ��չ����β
		ADD	CX,2
		SUB	CX,SI
		REP	MOVSB			;ǰ��
		SUB	DI,2
		MOV	DS:[6],DI		;����չ����β
		JMP	L_CL4A

;�ӳ���:��ʾ�ַ���DS:DX($��β)
S_XSZF:
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	AH,9			;��ʾ�ַ���
		INT	21H
		POP	DS
		RET
;�ӳ���:��ʾ�ַ���DS:SI($��β.'0'����ʾ)
S_XSN0:
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	AH,2
L_N01:
		LODSB
		CMP	AL,'0'
		JNZ	L_N02
		CMP	BYTE PTR [SI],'0'
		JAE	L_N01
L_N02:
		CMP	AL,'$'
		JZ	L_N03
		MOV	DL,AL
		INT	21H
		JMP	SHORT L_N01
L_N03:
		POP	DS
		RET
S_XSKZCZ:
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	AX,D_NUM		;��չ������
		MOV	CX,AX
		MOV	BX,OFFSET D_STR1+17	;��ʾ����λ
		MOV	DX,30AH
L_XS1:
		DIV	DL
		OR	AH,'0'
		MOV	[BX],AH
		XOR	AH,AH
		DEC	BX
		DEC	DH
		JNZ	L_XS1
		MOV	SI,OFFSET D_STR1
		CALL	S_XSN0			;��ʾ
		MOV	AL,'0'
		MOV	D_XSNUM,AL
		MOV	D_XSNUM[1],AL
		MOV	D_XSNUM[2],AL
		POP	DS
		OR	CX,CX
		JZ	L_XS6
		MOV	DI,OFFSET D_BUF 	;������ַ
L_XS2:
		PUSH	DS
		PUSH	CS
		POP	DS
		INC	D_XSNUM[2]		;��λ+1
		CMP	D_XSNUM[2],'9'
		JBE	L_XS3
		MOV	D_XSNUM[2],'0'
		INC	D_XSNUM[1]		;ʮλ+1
		CMP	D_XSNUM[1],'9'
		JBE	L_XS3
		MOV	D_XSNUM[1],'0'
		INC	D_XSNUM 		;��λ+1
L_XS3:
		MOV	SI,OFFSET D_XSNUM
		CALL	S_XSN0			;��ʾ���
		POP	DS
		MOV	SI,CS:[DI]
		ADD	DI,2
		MOV	AH,2
L_XS4:
		LODSB				;ȡ��һ�ֽ�
		CMP	AL,','                  ;����?
		JZ	L_XS5
		MOV	DL,AL
		INT	21H			;��ʾ
		JMP	SHORT L_XS4
L_XS5:
		MOV	DL,0DH			;�س�
		INT	21H
		MOV	DL,0AH			;����
		INT	21H
		LOOP	L_XS2
L_XS6:
		RET
S_CL		ENDP

;�ӳ���:������鲢�к���
S_INPUT 	PROC	NEAR
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_INKEY
		MOV	SI,DX
		MOV	AH,0AH			;����
		INT	21H
		INC	SI
		LODSB				;�ַ���
		XOR	AH,AH
		MOV	CX,AX
		OR	AX,AX			;��0?
		JNZ	L_IN1
L_IN0:
		POP	DS
		STC
		RET
L_IN1:
		CALL	S_0D0A
		MOV	BX,AX
		CMP	AL,6			;��2-3�ִ�?
		JBE	L_IN2
		MOV	BL,6
L_IN2:
		CMP	BYTE PTR [BX+SI-1],0A0H ;�к���?
		JBE	L_IN0
		DEC	BX
		JNZ	L_IN2

		CMP	CL,6
		JBE	L_IN3
		ADD	SI,CX			;ָ���β
		TEST	WORD PTR [SI-2],8080H	;��ĩ��?
		JZ	L_IN0
L_IN3:
		POP	DS
		CLC
		RET
S_INPUT 	ENDP

D_BUF	EQU	$

SEG_A		ENDS
		END	START

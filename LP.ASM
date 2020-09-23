;	LP.ASM
;	1995.11.13
;	1997.2.17-֧��WINDOWS95��DOS�����´�ӡ

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:
		MOV	AX,3517H		;ȡINT17�ж�
		INT	21H
		MOV	WORD PTR D_INT17,BX	;����
		MOV	WORD PTR D_INT17+2,ES

		MOV	AH,2			;ȡ��ӡ��״̬
		CALL	S_INT17
		TEST	AH,20H			;����?
		JZ	L_10
		MOV	DX,OFFSET NOPAPE	;'��ӡ��ûֽ��!'
		JMP	SHORT L_ERR
L_10:
		TEST	AH,9
		JZ	L_20
		MOV	DX,OFFSET IOERR 	;'���п�I/O����!'
		JMP	SHORT L_ERR
L_20:
		MOV	SI,80H
		LODSB
		CMP	AL,1
		JBE	L_50			;�޲���ֱ�ӻس�����
		CBW
		MOV	BX,AX
		MOV	[BX+SI],AH		;�ļ�β
L_30:
		LODSB
		CMP	AL,' '
		JZ	L_30

		CMP	AL,'0'                  ;������?
		JB	L_40
		CMP	AL,'9'
		JBE	L_60
L_40:
		CALL	S_DYAL			;��ӡ
		LODSB				;ȡ�ַ�
		OR	AL,AL
		JNZ	L_40
L_50:
		MOV	AL,0DH			;�س�
		CALL	S_DYAL
		MOV	AL,0AH			;����
		CALL	S_DYAL
		JMP	L_210			;����AL=0,EXIT
L_60:
		PUSH	SI
L_70:
		LODSB
		CMP	AL,'0'                  ;������?
		JB	L_80
		CMP	AL,'9'
		JBE	L_70
L_80:
		POP	SI
		DEC	SI
		OR	AL,AL			;���ļ���?
		JNZ	L_100
		LODSB				;ԭ����
		JMP	SHORT L_40
L_100:
		MOV	CX,10			;����
		XOR	BX,BX			;���
L_110:
		LODSB
		CMP	AL,' '
		JZ	L_120
		AND	AL,0FH
		CBW
		XCHG	AX,BX
		MUL	CX			;���*10
		ADD	BX,AX			;�ۼ�
		JMP	SHORT L_110
L_120:
		MOV	BP,BX			;����
L_130:
		LODSB
		CMP	AL,' '
		JZ	L_130

		DEC	SI
		MOV	DX,SI
		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_140
		MOV	DX,OFFSET NOFILE	;'ָ���ļ�δ�ҵ�!'
L_ERR:
		MOV	AH,9
		INT	21H
		MOV	AL,1			;������
		JMP	L_EXIT
L_140:
		MOV	BX,AX
		MOV	DX,OFFSET D_BUF
		MOV	CX,-1
		MOV	AH,3FH			;���ļ�
		INT	21H
		JNB	L_150
		MOV	DX,OFFSET READERR	;'ָ���ļ�������!'
		JMP	SHORT L_ERR
L_150:
		MOV	DI,AX			;�ļ�����
		MOV	AH,3EH			;�ر��ļ�
		INT	21H

		MOV	BX,OFFSET PRINTING+10
L_160:
		MOV	DX,OFFSET PRINTING	;'���ڴ�ӡ�ڣ�������. . .$'
		MOV	AH,9
		INT	21H

		MOV	CX,DI			;�ļ�����
		MOV	SI,OFFSET D_BUF 	;�ļ���
L_170:
		LODSB				;ȡ�ַ�
		CMP	AL,1AH			;ESC?
		JZ	L_180
		CALL	S_DYAL			;��ӡ

		MOV	AH,1			;�а���?
		INT	16H
		JZ	L_171
		XOR	AH,AH			;ȡ��
		INT	16H
		OR	AX,AX			;��CTRL+BREAK?
		JZ	L_EXIT
L_171:
		LOOP	L_170
L_180:
		CMP	BP,1			;ֻ1��?
		JZ	L_210
		MOV	DX,OFFSET CONTINUE	;'���س���������ӡ��һ��!'
		MOV	AH,9
		INT	21H
L_190:
		MOV	AX,0C01H		;����
		INT	21H
		CMP	AX,0C01H
		JZ	L_210
		CMP	AL,0DH			;�س�?
		JNZ	L_190
		MOV	AX,0E0AH		;����
		INT	10H

		INC	BYTE PTR [BX+5] 	;��λ+1
		CMP	BYTE PTR [BX+5],0BAH
		JB	L_200
		MOV	BYTE PTR [BX+5],0B0H
		INC	BYTE PTR [BX+3] 	;ʮλ+1
		CMP	BYTE PTR [BX+3],0BAH
		JB	L_200
		MOV	BYTE PTR [BX+3],0B0H
		INC	BYTE PTR [BX+1] 	;��λ+1
L_200:
		DEC	BP
		JNZ	L_160
L_210:
		XOR	AL,AL
L_EXIT:
		MOV	AH,4CH
		INT	21H

S_DYAL		PROC	NEAR
		XOR	AH,AH
S_INT17:
		XOR	DX,DX
		PUSHF
		CALL	DS:D_INT17
		RET
S_DYAL		ENDP

D_INT17 	DD	0
NOPAPE		DB	'��ӡ��ûֽ��!',7,13,10,'$'
IOERR		DB	'���п�I/O����!',7,13,10,'$'
NOFILE		DB	'ָ���ļ�δ�ҵ�!',7,13,10,'$'
READERR 	DB	'ָ���ļ�������!',7,13,10,'$'
PRINTING	DB	'���ڴ�ӡ�ڣ�������. . .$'
CONTINUE	DB	'���س���������ӡ��һ��!',7,'$'

D_BUF	EQU	$

SEG_A		ENDS
		END	START

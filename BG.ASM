.model small
.code
org 256
s:	push	cs
	pop	ds
	call	t
db	'ѥ$'
t:	pop	dx
	mov	ah,9
	int	33
	mov	ah,76
	int	33
end s
B	'      ����                     ͨ���Ʊ�����',13,10
		DB	'      ͷ��    1993��3��21��                     �� 1 ҳ        2 ��',13,10
		DB	'      �ꩳ   ���������ө������������ө����������ө�������',13,10
		DB	'      �⩧   �� ��� ��  ��    ��  ��          ��              1 ��',13,10
		DB	'      ����   �ĩ������੤�����������੤���������੤������',13,10
		DB	'        ��   ��  ��  ��  ��    ��  ��          ��',13,10
		DB	'      ����   �ĩ������੤�����������੤���������੤������      2 ��',13,10
		DB	'      �婧   ��  ��  ��  ��    ��  ��          ��',13,10
		DB	'            ��ʽ                                        ��ʽ',13,10,'$'
D_INNAME	DB	'���������ļ�����$'
D_INBT		DB	13,10,'      ��ͷ������$'
D_INBTL 	DB	13,10,'      ����������(<10)��$'
D_INBTH 	DB	13,10,'      ����������$'
D_INHX		DB	13,10,'      �м���ߣ�(Y/N) $'
D_INBK		DB	13,10,'      ��ʽ����ʽ��(B/K) $'
D_INBC		DB	13,10,'      �߿�Ӵ֣�(Y/N) $'
D_INBTLK	DB	13,10,'����������ȣ���Ҫ��ż������λ���ַ��������ܣ�����',13,10,'$'
D_ZKD		DB	13,10,' ** �ܿ��ȣ�    '
		DB	13,10,'�޸ģ� (Y/RETURN) $'
D_INLH		DB	13,10,'���ţ�$'
D_KD		DB	' ���ȣ�    �ĳɣ�$'
D_SXD		DB	'����S  ���ҩ�D  ���©�X  ������A  �˳���E',0
D_MY		DB	'���ⲻ���� (Y/RETURN) ?',0
D_3		DB	'   $'

D_FILE		DB	40 DUP(0)		;�����ļ���
D_HAN		DW	0			;�ļ���
D_INPUT 	DB	10 DUP(0)		;���뻺����
D_TH		DB	1			;��ͷ����
D_LH		DB	1			;����������
D_BTH		DB	1			;��������
D_X		DB	1			;�м����=1
D_B		DB	1			;��ʽ1/��ʽ2
D_C		DB	1			;�߿�Ӵ�=1
D_L1		DB	0
D_P1		DW	0
D_LM		DB	0			;�������
D_H		DB	0			;��ǰ��
D_L		DB	40 DUP(0)		;������
D_M		DB	40 DUP(' ')             ;SDX

BEGIN:
		CALL	S_CLS			;����
		XOR	DX,DX
		MOV	AH,2			;��궨λ
		INT	10H
		MOV	DX,OFFSET MSG
		MOV	AH,9			;��ʾ
		INT	21H

		MOV	DX,OFFSET D_INNAME	;'���������ļ�����$'
		MOV	AH,9
		INT	21H
		CALL	S_INPUT 		;�����ļ���
		JNB	L_260
		MOV	AX,4C00H
		INT	21H
L_260:
		MOV	DX,OFFSET D_INBT	;'��ͷ������$'
		MOV	AH,9
		INT	21H
		CALL	S_INNUM 		;��������AX
		OR	AL,AL
		JZ	L_270
		MOV	D_TH,AL
L_270:
		MOV	DX,OFFSET D_INBTL	;'����������(<10)��'
		MOV	AH,9
		INT	21H
		CALL	S_INNUM 		;��������AX
		OR	AL,AL
		JZ	L_280
		MOV	D_LH,AL
L_280:
		MOV	DX,OFFSET D_INBTH	;'����������'
		MOV	AH,9
		INT	21H
		CALL	S_INNUM 		;��������AX
		OR	AL,AL
		JZ	L_290
		MOV	D_BTH,AL
L_290:
		MOV	DX,OFFSET D_INHX	;'�м���ߣ�(Y/N)'
		MOV	AH,9
		INT	21H
L_291:
		XOR	AH,AH			;����
		INT	16H
		CMP	AL,0DH
		JZ	L_310
		AND	AL,5FH
		CMP	AL,'Y'
		JZ	L_292
		CMP	AL,'N'
		JNZ	L_291
L_292:
		CALL	S_XSAL			;��ʾ
		CMP	AL,'Y'
		JNZ	L_310
		MOV	D_X,1
L_310:
		MOV	DX,OFFSET D_INBK	;'��ʽ/��ʽ��(B/K)'
		MOV	AH,9
		INT	21H
L_311:
		XOR	AH,AH			;����
		INT	16H
		CMP	AL,0DH
		JZ	L_330
		AND	AL,5FH
		CMP	AL,'B'
		JZ	L_312
		CMP	AL,'K'
		JNZ	L_311
L_312:
		CALL	S_XSAL			;��ʾ

		CMP	AL,'K'
		JNZ	L_330
		MOV	D_B,2
L_330:
		MOV	DX,OFFSET D_INBC	;'�߿�Ӵ֣�(Y/N)'
		MOV	AH,9
		INT	21H
L_331:
		XOR	AH,AH			;����
		INT	16H
		CMP	AL,0DH
		JZ	L_350
		AND	AL,5FH
		CMP	AL,'Y'
		JZ	L_332
		CMP	AL,'N'
		JNZ	L_331
L_332:
		CALL	S_XSAL			;��ʾ

		CMP	AL,'Y'
		JNZ	L_350
		MOV	D_C,1
L_350:
		MOV	DX,OFFSET D_INBTLK	;'�����������..'
		MOV	AH,9			;��ʾ
		INT	21H
		XOR	BH,BH
		MOV	AH,3			;ȡ��ǰ���λ��
		INT	10H
		MOV	DS:[0FFH],DH
		MOV	CX,1			;����
L_360:
		MOV	AX,CX
		DEC	AX
		MOV	DH,8
		DIV	DH
		ADD	AL,DS:[0FFH]
		MOV	DH,AL			;�к�
		MOV	AL,10
		MUL	AH
		MOV	DL,AL			;�к�
L_361:
		MOV	AH,2			;��궨λ
		INT	10H
		MOV	AX,CX
		MOV	BL,10
		DIV	BL
		OR	AX,3030H
		CMP	AL,'0'
		JNZ	L_362
		MOV	AL,' '
L_362:
		CALL	S_XSAX			;��ʾ�к�
		MOV	DL,':'
		CALL	S_XSDL
		MOV	AX,'  '
		CALL	S_XSAX
		MOV	AX,808H 		;�˸�
		CALL	S_XSAX
		PUSH	CX
		PUSH	DX
		CALL	S_INNUM 		;��������:����
		POP	DX
		POP	CX
		TEST	AL,1			;������?
		JZ	L_380
		CALL	S_BEEP
		JMP	SHORT L_361
L_380:
		MOV	BX,CX
		DEC	BX
		MOV	D_L[BX],AL		;д��
		OR	AL,AL
		JZ	L_390
		TEST	CL,7			;��8��?
		JNZ	L_381
		MOV	AX,0D0AH
		CALL	S_XSAX
L_381:
		INC	CX
		JMP	L_360
L_390:
		DEC	CL
		MOV	D_LM,CL 		;�������
		OR	CL,CL
		JNZ	L_400
		MOV	AX,4C00H
		INT	21H
L_400:
		XOR	BX,BX
		MOV	SI,OFFSET D_L
L_401:
		LODSB
		OR	AL,AL
		JZ	L_410
		CBW
		ADD	BX,AX			;�ۼ�
		JMP	SHORT L_401
L_410:
		MOV	SI,OFFSET D_ZKD+16
		MOV	AX,BX			;�ܿ�
		CALL	S_1610			;ʮ������->ʮ����
		MOV	DX,OFFSET D_ZKD 	;'** �ܿ��ȣ�??? �޸�?...'
		MOV	AH,9
		INT	21H

		XOR	AH,AH			;����ѡ��
		INT	16H
		AND	AL,5FH
		CMP	AL,'Y'                  ;='Y'�޸�
		JZ	L_421
		JMP	L_460
L_421:
		MOV	DX,OFFSET D_INLH	;��ʾ'����:'
		MOV	AH,9
		INT	21H
		CALL	S_INNUM 		;��������
		CMP	AL,0
		JZ	L_455
		MOV	CX,AX
		MOV	BX,CX
		DEC	BX
		MOV	AL,D_L[BX]		;ȡ����
		CBW
		MOV	SI,OFFSET D_KD+9
		CALL	S_1610			;ʮ������->ʮ����
		MOV	DX,OFFSET D_KD		;'����: ??? �ĳ�:'
		MOV	AH,9
		INT	21H
		CALL	S_INNUM 		;�������
		OR	AL,AL
		JZ	L_421
		CMP	CL,D_LM 		;���������
		JBE	L_450
		MOV	D_LM,CL 		;��
L_450:
		MOV	BX,CX
		DEC	BX
		MOV	D_L[BX],AL		;д������
		JMP	SHORT L_421
L_455:
		XOR	BH,BH
		MOV	AH,3			;ȡ��ǰ���λ��
		INT	10H
		MOV	DS:[0FFH],DH
		MOV	CX,1			;����
L_456:
		MOV	AX,CX
		DEC	AX
		MOV	DH,8
		DIV	DH
		ADD	AL,DS:[0FFH]
		MOV	DH,AL			;�к�
		MOV	AL,10
		MUL	AH
		MOV	DL,AL			;�к�
		MOV	AH,2			;��궨λ
		INT	10H
		MOV	AX,CX
		MOV	BL,10
		DIV	BL
		OR	AX,3030H
		CMP	AL,'0'
		JNZ	L_457
		MOV	AL,' '
L_457:
		CALL	S_XSAX			;��ʾ����
		MOV	DL,':'
		CALL	S_XSDL
		PUSH	CX
		PUSH	DX
		MOV	BX,CX
		DEC	BX
		MOV	AL,D_L[BX]		;ȡ����
		CBW
		MOV	SI,OFFSET D_3+2
		CALL	S_1610
		MOV	DX,OFFSET D_3
		MOV	AH,9			;��ʾ����
		INT	21H
		POP	DX
		POP	CX
		TEST	CL,7			;��8��?
		JNZ	L_458
		MOV	AX,0D0AH
		CALL	S_XSAX
L_458:
		INC	CX
		CMP	CL,D_LM 		;�е��������
		JBE	L_456
		JMP	L_400			;�ۼ��ܿ�����������
L_460:
		CALL	S_CLS			;����
		MOV	SI,OFFSET D_SXD 	;'����S  ���ҩ�D  ���©�X ...
		MOV	DX,1800H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	AX,1801H		;���ò�ʶ����
		INT	10H

		MOV	DX,1300H
		XOR	BH,BH
		MOV	AH,2			;��궨λ
		INT	10H
		MOV	DL,' '
		CMP	D_B,1			;��ʽ=1,��ʽ=2
		JNZ	L_481
		MOV	DL,0C7H 		;'�'
		CMP	D_C,0
		JNZ	L_481
		MOV	DL,0C3H 		;'�'
L_481:
		CALL	S_XSDL			;��ʾ

		MOV	CX,1			;����
L_490:
		MOV	DL,0C4H 		;'�'
		CALL	S_XSDL
		CMP	CL,D_LM
		JZ	L_491
		MOV	DL,0C5H 		;'�'
		JMP	SHORT L_492
L_491:
		CMP	D_B,1			;=1��ʽ
		JNZ	L_500
		MOV	DL,0B6H 		;'�'
		CMP	D_C,1			;=1�Ӵ�
		JZ	L_492
		MOV	DL,0B4H 		;'�'
L_492:
		CALL	S_XSDL			;��ʾ
L_500:
		INC	CX
		CMP	CL,D_LM
		JBE	L_490

		MOV	DX,1400H
		MOV	AH,2			;��궨λ
		INT	10H
		MOV	DL,'0'
		CALL	S_XSDL
		MOV	CX,1			;����
L_510:
		MOV	AX,CX
		MOV	BL,10
		DIV	BL
		OR	AH,AH			;����10
		JZ	L_511
		MOV	AX,'  '
		JMP	SHORT L_512
L_511:
		MOV	AH,'0'
		OR	AL,AH
L_512:
		CALL	S_XSAX			;��ʾ��10
		INC	CX
		CMP	CL,D_LM
		JBE	L_510

		MOV	DX,1200H
		MOV	AH,2			;��궨λ
		INT	10H
		MOV	DL,' '
		CMP	D_B,1			;��ʽ?
		JNZ	L_531
		MOV	DL,0BAH 		;'�'
		CMP	D_C,1
		JZ	L_531
		MOV	DL,0B3H 		;'�'
L_531:
		CALL	S_XSDL
		MOV	CX,1
L_540:
		MOV	AL,CL
		CBW
		MOV	BL,10
		DIV	BL
		MOV	AL,AH
		OR	AL,30H
		MOV	DL,AL
		CALL	S_XSDL			;��ʾ��Ÿ�λ
		CMP	CL,D_LM
		JZ	L_550
		MOV	DL,0B3H 		;��ʾ'�'
		CALL	S_XSDL
		INC	CX
		JMP	SHORT L_540
L_550:
		CMP	D_B,1			;=1��ʽ
		JNZ	L_560
		MOV	DL,0BAH 		;'�'
		CMP	D_C,1
		JZ	L_551
		MOV	DL,0B3H 		;'�'
L_551:
		CALL	S_XSDL
L_560:
		CMP	D_LH,1			;������һ��?
		JNZ	L_561
		MOV	DH,12H
		JMP	L_810
L_561:
		MOV	DH,10H
		MOV	AL,D_LH
		MOV	D_L1,AL
L_570:
		CMP	D_B,1			;=1��ʽ
		JNZ	L_580
		MOV	D_M,'X'
L_580:
		MOV	BX,1			;����
L_590:
		MOV	DL,BL
		SHL	DL,1
		DEC	DL
		MOV	AH,2
		INT	10H
		MOV	CX,1
		MOV	AX,0A20H
		INT	10H
		XOR	AH,AH			;����
		INT	16H
		CMP	AL,96
		JB	L_610
		AND	AL,5FH
L_610:
		CMP	AL,'A'                  ;����
		JNZ	L_660
		JMP	L_460
L_660:
		CMP	AL,'E'                  ;����
		JNZ	L_670
		MOV	AX,1800H
		INT	10H
		CALL	S_CLS
		MOV	AX,4C00H
		INT	21H
L_670:
		CMP	AL,'S'
		JZ	L_680
		CMP	AL,'D'
		JZ	L_680
		CMP	AL,'X'
		JZ	L_680
L_677:
		CALL	S_BEEP
		JMP	L_590
L_680:
		MOV	D_M[BX],AL		;д��
		CALL	S_XSAL			;��ʾ

		CMP	D_M[BX-1],'X'
		JNZ	L_700
		CMP	D_M[BX],'S'
		JZ	L_677
L_700:
		CMP	D_M[BX-1],'S'
		JNZ	L_710
		CMP	D_M[BX],'S'
		JZ	L_677
L_710:
		CMP	D_M[BX-1],'D'
		JNZ	L_720
		CMP	D_M[BX],'X'
		JZ	L_677
L_720:
		CMP	D_M[BX-1],'X'
		JNZ	L_730
		CMP	D_M[BX],'X'
		JNZ	L_730
		CMP	BL,1
		JNZ	L_722
		CMP	D_C,1
		JNZ	L_722
		XOR	DL,DL
		MOV	AH,2
		INT	10H
		MOV	DL,0BAH 		;'�'
		CALL	S_XSDL
		PUSH	DX
		INC	DH
		XOR	DL,DL
		MOV	AH,2
		INT	10H
		POP	DX
		MOV	DL,0BAH 		;'�'
		CALL	S_XSDL
		JMP	SHORT L_730
L_722:
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		PUSH	DX
		MOV	DL,0B3H 		;'�'
		CALL	S_XSDL
		POP	DX
		PUSH	DX
		INC	DH
		MOV	AH,2
		INT	10H
		POP	DX
		MOV	DL,0B3H 		;'�'
		CALL	S_XSDL
L_730:
		CMP	D_M[BX-1],'X'
		JNZ	L_740
		CMP	D_M[BX],'D'
		JNZ	L_740
		CMP	BL,1
		JNZ	L_733
		CMP	D_C,1
		JNZ	L_733
		XOR	DL,DL
		MOV	AH,2
		INT	10H
		MOV	DL,0BAH 		;'�'
		CALL	S_XSDL
		PUSH	DX
		INC	DH
		XOR	DL,DL
		MOV	AH,2
		INT	10H
		POP	DX
		MOV	DL,0C7H 		;'�'
		CALL	S_XSDL
		MOV	DL,0C4H 		;'�'
		CALL	S_XSDL
		JMP	SHORT L_740
L_733:
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		PUSH	DX
		MOV	DL,0B3H 		;'�'
		CALL	S_XSDL
		POP	DX
		PUSH	DX
		INC	DH
		MOV	AH,2
		INT	10H
		POP	DX
		MOV	DL,0C3H 		;'�'
		CALL	S_XSDL
		MOV	DL,0C4H 		;'�'
		CALL	S_XSDL
L_740:
		CMP	D_M[BX-1],'D'
		JNZ	L_750
		CMP	D_M[BX],'D'
		JZ	L_742
		CMP	D_M[BX],'S'
		JNZ	L_750
L_742:
		PUSH	DX
		ADD	DH,2
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		POP	DX
		PUSH	DX
		INC	DH
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		POP	DX
		CMP	AL,179			;'�'
		JNZ	L_744
		MOV	DL,0C2H 		;'�'
		CALL	S_XSDL
		MOV	DL,0C4H 		;'�'
		CALL	S_XSDL
		JMP	SHORT L_750
L_744:
		MOV	DL,0C4H 		;'�'
		CALL	S_XSDL
		MOV	DL,0C4H 		;'�'
		CALL	S_XSDL
L_750:
		CMP	D_M[BX-1],'S'
		JNZ	L_760
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		PUSH	DX
		MOV	DL,0B3H 		;�'
		CALL	S_XSDL
		POP	DX
		PUSH	DX
		INC	DH
		MOV	AH,2
		INT	10H
		POP	DX
		CMP	D_M[BX],'X'
		JNZ	L_755
		MOV	DL,0B4H 		;�'
		CALL	S_XSDL
		JMP	SHORT L_760
L_755:
		CMP	D_M[BX],'D'
		JNZ	L_760
		MOV	DL,0C5H 		;'�'
		CALL	S_XSDL
		MOV	DL,0C4H 		;'�'
		CALL	S_XSDL
L_760:
		CMP	BL,D_LM
		JNZ	L_800
		CMP	D_B,1
		JNZ	L_800
		MOV	DL,BL
		SHL	DL,1
		MOV	AH,2
		INT	10H
		PUSH	DX
		MOV	DL,0BAH 		;'�'
		CMP	D_C,1
		JZ	L_770
		MOV	DL,0B3H 		;'�'
L_770:
		CALL	S_XSDL
		POP	DX
		PUSH	DX
		INC	DH
		MOV	AH,2
		INT	10H
		POP	DX
		CMP	D_M[BX],'X'
		JNZ	L_790
		MOV	DL,0BAH 		;'�'
		CMP	D_C,1
		JZ	L_788
		MOV	DL,0B3H 		;'�'
L_788:
		CALL	S_XSDL
L_790:
		CMP	D_M[BX],'S'
		JNZ	L_800
		MOV	DL,0B6H 		;'�'
		CMP	D_C,1
		JZ	L_797
		MOV	DL,0B4H 		;'�'
L_797:
		CALL	S_XSDL
L_800:
		INC	BX
		CMP	BL,D_LM
		JA	L_801
		JMP	L_590
L_801:
		DEC	D_L1
		CMP	D_L1,1
		JZ	L_810
		SUB	DH,2
		JMP	L_570
L_810:
		MOV	BL,D_B
L_811:
		MOV	DL,BL
		DEC	DL
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		PUSH	DX
		DEC	DH
		MOV	AH,2
		INT	10H
		POP	DX

		CMP	AL,179			;'�'
		JZ	L_830
		CMP	AL,186			;'�'
		JZ	L_830
		CMP	D_C,1
		JNZ	L_822
		MOV	DL,0CDH 		;'�'
		CALL	S_XSDL
		JMP	SHORT L_860
L_822:
		MOV	DL,0C4H 		;'�'
		CALL	S_XSDL
		JMP	SHORT L_860
L_830:
		CMP	BL,1
		JNZ	L_840
		CMP	D_C,1
		JNZ	L_833
		MOV	DL,0C9H 		;'�'
		CALL	S_XSDL
		JMP	SHORT L_860
L_833:
		MOV	DL,0DAH 		;'�'
		CALL	S_XSDL
		JMP	SHORT L_860
L_840:
		MOV	AL,D_LM
		SHL	AL,1
		ADD	AL,2
		SUB	AL,D_B
		CMP	BL,AL
		JNZ	L_850
		CMP	D_C,1
		JNZ	L_844
		MOV	DL,0BBH 		;'�'
		CALL	S_XSDL
		JMP	SHORT L_860
L_844:
		MOV	DL,0BFH 		;'�'
		CALL	S_XSDL
		JMP	SHORT L_860
L_850:
		CMP	D_C,1
		JNZ	L_855
		MOV	DL,0D1H 		;�'
		CALL	S_XSDL
		JMP	SHORT L_860
L_855:
		MOV	DL,0C2H 		;'�'
		CALL	S_XSDL
L_860:
		INC	BL
		MOV	AL,D_LM
		SHL	AL,1
		ADD	AL,2
		SUB	AL,D_B
		CMP	BL,AL
		JA	L_870
		JMP	L_811
L_870:
		MOV	D_H,DH

		MOV	AX,1800H		;����ʶ����
		INT	10H
		MOV	SI,OFFSET D_MY		;'���ⲻ����?...'
		MOV	DX,1832H
		MOV	BX,1EH
		CALL	S_XSZF
		XOR	AH,AH			;����ѡ��
		INT	16H
		CMP	AL,1BH			;ESC?
		JNZ	L_877
		JMP	L_1120
L_877:
		AND	AL,5FH
		CMP	AL,'Y'                  ;��Y?
		JZ	L_880
		JMP	L_460
L_880:
		MOV	DX,OFFSET D_FILE	;�����ļ���
		MOV	CX,20H
		MOV	AH,3CH			;�����ļ�
		INT	21H
		MOV	D_HAN,AX
		MOV	BX,AX
		MOV	AL,D_TH 		;��ͷ����
		CBW
		MOV	SI,AX
L_882:
		MOV	DX,OFFSET D_INBT	;13,10
		MOV	CX,2
		MOV	AH,40H			;д��
		INT	21H
		DEC	SI
		JNZ	L_882

		MOV	DI,OFFSET D_BUF 	;�����������
		MOV	DH,D_H
		MOV	BX,1
L_890:
		PUSH	DX
		DEC	DH
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		POP	DX
		CMP	AL,' '
		JZ	L_980
		CMP	AL,196			;'�'
		JNZ	L_910
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_910:
		CMP	AL,205			;'�'
		JNZ	L_920
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_920:
		CMP	AL,194			;'�'
		JNZ	L_930
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_930:
		CMP	AL,209			;'�'
		JNZ	L_940
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_940:
		CMP	AL,218			;'�'
		JNZ	L_950
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_950:
		CMP	AL,201			;'�'
		JNZ	L_960
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_960:
		CMP	AL,191			;'�'
		JNZ	L_970
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_980
L_970:
		CMP	AL,187			;'�'
		JNZ	L_980
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
L_980:
		CMP	BL,D_LM
		JA	L_1010
		MOV	CL,D_L[BX-1]		;ȡ����
		XOR	CH,CH
		SHR	CX,1
L_990:
		MOV	AX,'��'
		CMP	D_C,1
		JZ	L_991
		MOV	AX,'��'
L_991:
		XCHG	AH,AL
		STOSW
		LOOP	L_990
L_1010:
		INC	BX
		MOV	AL,D_LM
		INC	AX
		CMP	BL,AL
		JA	L_1011
		JMP	L_890
L_1011:
		CALL	S_WRIT			;д��

		MOV	BP,1			;����������������
L_1020:
		CALL	S_1130			;����һ��
		INC	BP
		MOV	AL,D_LH
		CBW
		SHL	AX,1
		CMP	BP,AX
		JBE	L_1020

		MOV	D_P1,BP 		;��������
		SUB	D_P1,2
		MOV	BX,1
L_1030:
		MOV	BP,D_P1
		CALL	S_1130			;����һ��
		CMP	BL,D_BTH
		JZ	L_1050
		CMP	D_X,1			;�м����?
		JNZ	L_1050
		MOV	BP,D_P1
		INC	BP
		CALL	S_1130			;����һ��
L_1050:
		INC	BX
		CMP	BL,D_BTH
		JBE	L_1030

		MOV	DI,OFFSET D_BUF 	;����β��
		CMP	D_B,1
		JNZ	L_1080
		MOV	AX,'��'
		CMP	D_C,1
		JZ	L_1071
		MOV	AX,'��'
L_1071:
		XCHG	AH,AL
		STOSW
L_1080:
		MOV	BX,1
L_1081:
		MOV	CL,D_L[BX-1]
		XOR	CH,CH
		SHR	CX,1
		MOV	AX,'��'
		CMP	D_C,1
		JZ	L_1082
		MOV	AX,'��'
L_1082:
		XCHG	AH,AL
		REP	STOSW
		CMP	BL,D_LM
		JNZ	L_1100
		CMP	D_B,1
		JNZ	L_1100
		MOV	AX,'��'
		CMP	D_C,1
		JZ	L_1091
		MOV	AX,'��'
L_1091:
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1110
L_1100:
		MOV	AX,'��'
		CMP	D_C,1
		JZ	L_1101
		MOV	AX,'��'
L_1101:
		XCHG	AH,AL
		STOSW
L_1110:
		INC	BX
		CMP	BL,D_LM
		JBE	L_1081
		MOV	AX,0A0DH		;�س�����
		STOSW
		MOV	AL,1AH			;�ı��ļ�������־
		STOSB
		CALL	S_WRIT1 		;д��

		MOV	AH,3EH			;�ر��ļ�
		INT	21H
L_1120:
		XOR	BX,BX
		MOV	AH,3			;ȡ��ǰ���λ��
		INT	10H
		PUSH	DX
		MOV	DX,1800H
		MOV	AH,2			;��궨λ
		INT	10H
		MOV	AX,920H 		;�������Ϣ
		MOV	CX,80
		INT	10H
		POP	DX
		INC	DH
		MOV	AH,2			;��궨λ
		INT	10H

		MOV	AX,4C00H
		INT	21H

;�ӳ���:�����м���
S_1130		PROC	NEAR
		PUSH	BX
		MOV	DI,OFFSET D_BUF
		MOV	BX,1
L_1140:
		MOV	DH,D_H
		MOV	AX,BP
		ADD	DH,AL
		DEC	DH
		MOV	DL,BL
		SHL	DL,1
		SUB	DL,2
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		CMP	AL,128
		JA	L_1160
		CMP	BL,1
		JZ	L_1160
		MOV	AX,'  '
		STOSW
L_1160:
		CMP	AL,196			;'�'
		JNZ	L_1170
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1170:
		CMP	AL,179			;'�'
		JNZ	L_1180
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1180:
		CMP	AL,186			;'�'
		JNZ	L_1190
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1190:
		CMP	AL,194			;'�'
		JNZ	L_1200
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1200:
		CMP	AL,193			;'�'
		JNZ	L_1210
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1210:
		CMP	AL,195			;'�'
		JNZ	L_1220
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1220:
		CMP	AL,199			;'�'
		JNZ	L_1230
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1230:
		CMP	AL,180			;'�'
		JNZ	L_1240
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1240:
		CMP	AL,182			;'�'
		JNZ	L_1250
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
		JMP	SHORT L_1260
L_1250:
		CMP	AL,197			;'�'
		JNZ	L_1260
		MOV	AX,'��'
		XCHG	AH,AL
		STOSW
L_1260:
		MOV	DH,D_H
		MOV	AX,BP
		ADD	DH,AL
		DEC	DH
		MOV	DL,BL
		SHL	DL,1
		DEC	DL
		MOV	AH,2
		INT	10H
		MOV	AH,8
		INT	10H
		CMP	AL,128
		JA	L_1270
		MOV	CL,D_L[BX-1]
		OR	CL,CL
		JZ	L_1270
		XOR	CH,CH
		MOV	AL,' '
		REP	STOSB
L_1270:
		CMP	AL,196			;'�'
		JNZ	L_1280
		MOV	CL,D_L[BX-1]
		OR	CL,CL
		JZ	L_1280
		XOR	CH,CH
		SHR	CX,1
		MOV	AX,'��'
		XCHG	AH,AL
		REP	STOSW
L_1280:
		INC	BX
		MOV	AL,D_LM
		INC	AX
		CMP	BL,AL
		JA	L_1290
		JMP	L_1140
L_1290:
		CALL	S_WRIT
		POP	BX
		RET
;�ӳ���:д���ļ�
S_WRIT:
		MOV	AX,0A0DH		;�س�����
		STOSW
S_WRIT1:
		MOV	BX,D_HAN		;�ļ���
		MOV	DX,OFFSET D_BUF
		MOV	CX,DI
		SUB	CX,DX
		MOV	AH,40H			;д�ļ�
		INT	21H
		RET
S_1130		ENDP

;�ӳ���:��ʾ�ַ���SI,DX=����λ��,BL=����.��ʾ�����ڴ�β
S_XSZF		PROC	NEAR
L_XZ1:
		MOV	AH,2			;��궨λ
		INT	10H
		LODSB				;ȡһ�ַ�
		OR	AL,AL			;����?
		JZ	L_XZ2
		MOV	CX,1
		MOV	AH,9			;��ʾ
		INT	10H
		INC	DX			;��+1
		JMP	SHORT L_XZ1
L_XZ2:
		RET
S_XSZF		ENDP

;�ӳ���:��ʾAX(��AL,��AH)
S_XSAX		PROC	NEAR
		XCHG	AH,AL
		PUSH	AX
		MOV	DL,AH
		CALL	S_XSDL
		POP	AX
S_XSAL:
		MOV	DL,AL
S_XSDL:
		MOV	AH,2
		INT	21H
		RET
S_XSAX		ENDP

;�ӳ���:����
S_BEEP		PROC	NEAR
		MOV	AX,0E07H
		INT	10H
		RET
S_BEEP		ENDP

;�ӳ���:����
S_CLS		PROC	NEAR
		MOV	AX,600H
		XOR	BX,BX
		XOR	CX,CX
		MOV	DX,184FH
		INT	10H
		RET
S_CLS		ENDP

;�ӳ���:�����ļ���
S_INPUT 	PROC	NEAR
		MOV	SI,OFFSET D_FILE	;���뻺����
L_IN1:
		XOR	AH,AH			;����
		INT	16H
		CMP	AL,0DH			;�س�?
		JZ	L_IN6
		CMP	AL,1BH			;<ESC>
		JNZ	L_IN1A
		POPF
		INT	20H
L_IN1A:
		CMP	AL,8			;�˸�?
		JNZ	L_IN5
		CMP	SI,OFFSET D_FILE	;ָ��������?
		JA	L_IN3
L_IN2:
		CALL	S_BEEP
		JMP	SHORT L_IN1
L_IN3:
		DEC	SI			;λ��-1
L_IN4:
		CALL	S_XSAL			;��ʾ

		CMP	AL,8			;�˸�?
		JNZ	L_IN1
		MOV	CX,1
		MOV	AX,0A20H		;��ʾ�ո�
		INT	10H
		JMP	SHORT L_IN1
L_IN5:
		MOV	[SI],AL 		;д��
		INC	SI
		JMP	SHORT L_IN4		;��ʾ
L_IN6:
		CMP	SI,OFFSET D_FILE
		JZ	L_IN7
		MOV	BYTE PTR [SI],0
		CLC
		RET
L_IN7:
		STC
		RET
S_INPUT 	ENDP

;�ӳ���:�������� ����AX
S_INNUM 	PROC	NEAR
		MOV	SI,OFFSET D_INPUT	;���뻺����
		MOV	DI,SI
		MOV	BX,7
L_NUM1:
		XOR	AH,AH			;����
		INT	16H
		CMP	AL,0DH			;�س�?
		JZ	L_NUM6
		CMP	AL,1BH			;<ESC>
		JNZ	L_NUM1A
		POPF
		INT	20H
L_NUM1A:
		CMP	AL,8			;�˸�?
		JNZ	L_NUM5
		CMP	SI,OFFSET D_INPUT	;ָ��������?
		JA	L_NUM3
L_NUM2:
		CALL	S_BEEP
		JMP	SHORT L_NUM1
L_NUM3:
		DEC	SI			;λ��-1
L_NUM4:
		CALL	S_XSAL			;��ʾ

		CMP	AL,8			;�˸�?
		JNZ	L_NUM1
		MOV	CX,1
		MOV	AX,0A20H		;��ʾ�ո�
		INT	10H
		JMP	SHORT L_NUM1
L_NUM5:
		CMP	AL,'0'                  ;������?
		JB	L_NUM1
		CMP	AL,'9'
		JA	L_NUM1
		MOV	[SI],AL 		;д��
		INC	SI
		JMP	SHORT L_NUM4
L_NUM6:
		CMP	SI,OFFSET D_INPUT
		JZ	L_NUM9
		XOR	BX,BX
		MOV	[SI],BL
		MOV	SI,OFFSET D_INPUT	;��������
L_NUM7:
		LODSB				;ȡ
		OR	AL,AL
		JZ	L_NUM8
		AND	AL,0FH
		CBW
		PUSH	AX
		MOV	AX,10
		MUL	BX
		MOV	BX,AX
		POP	AX
		ADD	BX,AX
		JMP	SHORT L_NUM7
L_NUM8:
		MOV	AX,BX
		RET
L_NUM9:
		XOR	AX,AX
		RET
S_INNUM 	ENDP

;�ӳ���:ʮ������->ʮ����AX,SI-��λ��ַ
S_1610		PROC	NEAR
		MOV	BL,10
L_161:
		DIV	BL
		OR	AH,30H
		MOV	[SI],AH
		XOR	AH,AH
		DEC	SI
		OR	AL,AL
		JNZ	L_161
		RET
S_1610		ENDP

D_BUF	EQU	$

CSEG		ENDS
		END	START
;	BG.ASM (2.13L)
;	1995.7.15
;	1996.10.9

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

MSG		DB	'      ����                     ͨ���Ʊ�����',13,10
		DB	'      ͷ��    1993��3��21��                     �� 1 ҳ        2 �
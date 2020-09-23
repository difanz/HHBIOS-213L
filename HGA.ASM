;	HGA.ASM (2.13L)
;	1996.1.4, 1.19, 2.10, 3.6, 3.12, 3.31, 5.20, 12.4
;	1997.2.20, 7.7, 9.11
;	1998.8.9

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

IN_INT10	DB	0
	;[0F4H] 1-��װKZZF,2-������ʾ��,4-��ʾ��BIOS,8-����ʾ��ʾ��Ϣ
	;[0F5H] 1-ֱ��д��,2-ͼ�η�ʽ��B8,4-��ʾ�жϵ�BIOS,8-�������
	;[0F6H] 1-ԭ�з�ʽ,2-�̶����,4-��ʼ���Ĵ���,8-AH=0B��BIOS
	;[0F7H] =1~9��ʾ�й��ɫ,����:�ر���Ļ�ָ�
	;[100H] ��������ʾ��ʽ����	=0����,=1����
	;[101H] ��꿪��		λ0=0��,=1�й��
	;[102H] ��ǰ���״̬		=0�޹��,=0FFH��
D_INT10 	DD	0			;ԭINT10
D_INT8		DD	0			;ԭINT8
D_INT16 	DW	0			;����ģ���
		INCLUDE ZF80.INC
D_0050		DB	0			;ǰ�ֽ�
D_0051		DB	0			;      ����
D_0052		DW	0			;      λ��
D_0058		DB	0			;��ʾ����λ��
D_0059		DB	0			;      �к�,��(=0)
D_005A		DB	1			;=1:ֱ��д��
D_005B		DB	16H			;��ʾ�и����к�
D_005E		DW	2			;���߶�
D_0060		DB	0			;=0���Ը�λ����,=1���,=2��˸
D_0062		DB	0			;��ʾ�к���ǰ�ֽ�
D_0064		DB	7			;������ʾ��ʽ
D_A000		DW	0B800H
D_B800		DW	0B000H
D_0068		DW	0			;������λ��
D_0069		DB	1			;=0����,��0����
D_ZJXP		DB	2			;ֱ��д������

D_AH		DW	OFFSET L_AH00		;AH=0
D_AH01		DW	OFFSET L_AH01		;AH=1
		DW	OFFSET L_AH02		;AH=2
		DW	OFFSET L_INT10		;AH=3
		DW	OFFSET L_INT10		;AH=4
		DW	OFFSET L_AH05		;AH=5
		DW	OFFSET L_AH06		;AH=6
		DW	OFFSET L_AH07		;AH=7
		DW	OFFSET L_AH08		;AH=8
		DW	OFFSET L_AH09		;AH=9
		DW	OFFSET L_AH09		;AH=0AH
		DW	OFFSET L_RET		;AH=0BH
		DW	OFFSET L_AH0C		;AH=0CH
		DW	OFFSET L_AH0D		;AH=0DH
		DW	OFFSET L_AH0E		;AH=0EH
		DW	OFFSET L_INT10		;AH=0FH
		DW	OFFSET L_INT10		;AH=10H
		DW	OFFSET L_INT10		;AH=11H
		DW	OFFSET L_INT10		;AH=12H
		DW	OFFSET L_AH13		;AH=13H
		DW	OFFSET L_AH14		;AH=14H
		DW	OFFSET L_AH15		;AH=15H
		DW	OFFSET L_AH16		;AH=16H
		DW	OFFSET L_AH17		;AH=17H
		DW	OFFSET L_AH18		;AH=18H

INT_10		PROC	FAR
		STI
		CLD
		CMP	AH,-1			;�а�װ?		2.10
		JNZ	L_00
		MOV	AX,48H			;HGA-'H'
		IRET
L_00:
		MOV	CS:IN_INT10,0FFH
		OR	AH,AH
		JZ	L_01
		CMP	AH,18H			;���ܺ�>18H?
		JZ	L_01
		JA	L_10
		CMP	BYTE PTR CS:[100H],0	;�����ķ�ʽ?
		JZ	L_10
L_01:
		PUSH	DS			;�����ֳ�
		PUSH	ES
		PUSH	BP
		PUSH	SI
		PUSH	DI
		PUSH	DX
		PUSH	CX
		PUSH	BX
		PUSH	AX

		CMP	CS:D_005A,1		;��ֱ��д��?
		JNZ	L_02
		CMP	AH,6
K_10ZJXP	EQU	$
		JMP	L_02			;����JB��ֱ��д��
		CMP	AH,7			;3.12
		JBE	L_INT10
L_02:
		XOR	DI,DI			;0��DS
		MOV	DS,DI
		XCHG	AL,AH
		MOV	DI,AX
		AND	DI,7FH
		SHL	DI,1
		XCHG	AL,AH
		JMP	CS:D_AH[DI]
L_INT10:
		POP	AX			;�ָ��ֳ���ִ��ԭINT10
		POP	BX
		POP	CX
		POP	DX
		POP	DI
		POP	SI
		POP	BP
		POP	ES
		POP	DS
L_10:
		MOV	CS:IN_INT10,0
		JMP	CS:D_INT10
L_RET:
		POP	AX			;�ָ��ֳ�������
L_RET1:
		POP	BX
L_RET3:
		POP	CX
		POP	DX
		POP	DI
		POP	SI
		POP	BP
L_RET2:
		POP	ES
		POP	DS
		MOV	CS:IN_INT10,0
		IRET
INT_10		ENDP

INT_1D		DB	38H, 28H, 2DH, 0AH, 1FH, 6, 19H, 1CH
		DB	2, 7, 6, 7, 0, 0, 0, 0
		DB	71H, 50H, 5AH, 0AH, 1FH, 6, 19H, 1CH
		DB	2, 7, 6, 7, 0, 0, 0, 0
D_MOD9		DB	35H, 28H, 2DH, 7, 64H, 0DH, 64H, 64H
		DB	2, 3, 6, 7, 0, 0, 0, 0
		DB	61H, 50H, 52H, 0FH, 19H, 6, 19H, 19H
		DB	2, 0DH, 0BH, 0CH, 0, 0, 0, 0

;AH=0 ������ʾ��ʽAL
L_AH00:
		MOV	BX,AX
		MOV	BYTE PTR CS:K_INT8,0EBH ;JMP �ر�INT8		3.30
		MOV	ES,CS:D_INT16		;����ģ���

		AND	AL,7FH
		CMP	AL,4
K_VJXP	EQU	$-1
		JB	L_0010
		CMP	AL,7
K_VJXP1 EQU	$-1
		JZ	L_0010

		CMP	AL,9
D_6	EQU	$-1
		JZ	L_0020

		MOV	ES:[101H],AL
		MOV	CS:[100H],AH		;������ʾ��ʽ
		MOV	AX,BX
		JMP	L_INT10
L_0010:
		MOV	CS:D_005A,1
		MOV	CS:D_0064,3
		MOV	CS:D_B800,0B000H
		JMP	SHORT L_0030
L_0020:
		MOV	CS:D_005A,0
		MOV	CS:D_0064,9
L_0030:
		MOV	BYTE PTR ES:[101H],9
		CLI
		MOV	DX,3BFH
		MOV	AL,3
		OUT	DX,AL			;��HGA��
		MOV	DX,3B8H
		MOV	AL,2
		OUT	DX,AL
		MOV	DX,3B4H
		MOV	BX,OFFSET D_MOD9
		XOR	AL,AL
L_0032:
		MOV	AH,CS:[BX]
		OUT	DX,AX
		INC	BX
		INC	AL
		CMP	AL,10H
		JB	L_0032

		PUSH	CS
		POP	ES			;CS��ES
		MOV	DI,OFFSET D_XPQ 	;��������ַ
		MOV	CX,25*80
		MOV	AX,720H
		REP	STOSW			;��������

		MOV	DI,0B000H
		MOV	ES,DI
		XOR	DI,DI
		MOV	CX,25*80
		REP	STOSW			;��д����
		MOV	DI,8000H
		MOV	CX,4000H
		XOR	AX,AX
		REP	STOSW			;��ʵ����

		MOV	DX,3B8H
		MOV	AL,8AH
		OUT	DX,AL
		MOV	DS:[465H],AL
		STI
		MOV	WORD PTR DS:[44AH],50H
		MOV	WORD PTR DS:[463H],3B4H

		CMP	CS:D_005A,0		;��ֱ��д��?
		JZ	L_0040
		MOV	BYTE PTR CS:K_INT8,75H	;JNZ ��INT8		3.30
		MOV	WORD PTR DS:[44CH],1000H
L_0040:
		MOV	AL,CS:D_0064
		MOV	DS:[449H],AL
		MOV	CS:D_0059,0
		MOV	BYTE PTR CS:[102H],0
		MOV	WORD PTR CS:[100H],101H ;���ַ�ʽ,�򿪹��
		MOV	WORD PTR DS:[460H],0B0CH
		XOR	DX,DX
		MOV	CS:D_0068,DX
		CALL	S_XSGB			;��ʾ���
		JMP	L_RET

;AH=1 ���ù���С CH=��ʼɨ����,CL=��ֹ��
L_AH01:
		CLI
		OR	CX,CX
		JZ	L_0103
		CALL	S_QGB
		PUSH	CX
		AND	CX,1F1FH
		CMP	CL,CH
		JNB	L_0101
		MOV	CH,CL
L_0101:
		SUB	CL,CH
		INC	CX
		CMP	CL,15
		JBE	L_0102
		MOV	CL,15
L_0102:
		XOR	CH,CH
		MOV	CS:D_005E,CX
		POP	AX
		MOV	BYTE PTR CS:[101H],0
		TEST	AH,20H
		JNZ	L_0103
		MOV	BYTE PTR CS:[101H],1
		CALL	S_GB
L_0103:
		STI
		JMP	L_RET

;AH=2 ���ù��λ��DX,BH=ҳ��
L_AH02:
		CLI
		CMP	CS:D_0059,0		;��������ʾ��?
		JZ	L_0201
		CMP	DH,CS:D_0059		;��λ���Ƿ���ʾ��?
		JNZ	L_0201
		MOV	AX,1404H		;�ر���ʾ��
		INT	10H
L_0201:
		CMP	CS:D_005A,0		;��ͼ�η�ʽ?
		JNZ	L_0202
		MOV	DS:[450H],DX
		JMP	SHORT L_0203
L_0202:
		PUSH	BX
		MOV	AL,BH
		MOV	BL,BH
		XOR	BH,BH
		SHL	BX,1
		MOV	DS:[BX+450H],DX 	;���ù��λ��
		POP	BX
		CMP	AL,DS:[462H]		;���Ƿ�ǰҳ?
		JNZ	L_0204
L_0203:
		CALL	S_GB			;��ʾ���
L_0204:
		STI
		MOV	AH,2
		JMP	L_INT10

;AH=5 ѡ����ʾҳ AL
L_AH05: 	CMP	CS:D_005A,0
		JZ	L_0501
		MOV	DS:[462H],AL
		CLI
		PUSH	AX
		MOV	CL,4
		SHL	AL,CL
		MOV	DS:[44FH],AL
		POP	AX
		ADD	AL,0B0H
		MOV	AH,AL
		XOR	AL,AL
		MOV	CS:D_B800,AX
		STI
L_0501:
		JMP	L_RET

D_SI		DW	0
D_DI		DW	0
D_67		DB	0
;AH=6 �Ϲ���ǰҳ  AL=����,CX=���Ͻ�,DX=���½�,BH=�����������
L_AH06:
		CALL	S_QGB			;�ع��
		MOV	CS:D_67,AH
		CMP	CS:D_0059,0
		JZ	L_0602
		PUSH	AX
		MOV	AX,1404H
		INT	10H
		POP	AX
L_0602:
		CMP	CS:D_005A,0
		JZ	L_0603
		CLI
L_0603:
		CALL	S_GDHS			;�й�������
		MOV	AX,CX			;���Ͻ�
		CALL	S_GDFW			;������Χ,CS��DS,CS��ES
		ADD	SI,AX
		ADD	D_SI,BP
		MOV	BP,4*80

		OR	BL,BL			;������=0?
		JNZ	L_0604
		MOV	BL,DH
		JMP	SHORT L_0606
L_0604:
		MOV	AH,DH
		SUB	AH,BL
L_0605:
		CALL	S_XPGD			;�����Ϲ�һ��
		ADD	SI,160			;ָ����һ��
		ADD	DI,160
		ADD	D_SI,BP
		ADD	D_DI,BP
		DEC	AH
		JNZ	L_0605
L_0606:
		MOV	AH,BH			;�ָ������������
		OR	AH,AH			;����=0?
		JNZ	L_0607
		MOV	AH,7
L_0607:
		SHR	BH,1			;ʵ�ʵĿ����������
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
L_0608:
		CALL	S_KHTC			;�������
		ADD	DI,160			;ָ����һ��
		ADD	D_DI,BP
		DEC	BL
		JNZ	L_0608

		JMP	L_RET

;�ӳ���:�й�������
S_GDHS		PROC	NEAR
		CMP	CH,24
		JBE	L_HS1
		MOV	CH,24
L_HS1:
		CMP	CL,79
		JBE	L_HS2
		MOV	CL,79
L_HS2:
		CMP	DH,24
		JBE	L_HS3
		MOV	DH,24
L_HS3:
		CMP	DL,79
		JBE	L_HS4
		MOV	DL,79
L_HS4:
		MOV	BL,AL			;��������
		OR	AL,AL			;=0?
		JZ	L_HS5
		PUSH	AX
		MOV	AL,DH
		SUB	AL,CH
		INC	AL			;������
		CMP	AL,BL			;>=������
		POP	AX
		JA	L_HS5
		XOR	BL,BL
L_HS5:
		RET
S_GDHS		ENDP

;�ӳ���:������Χ
S_GDFW		PROC	NEAR
		SUB	DX,CX
		ADD	DX,101H 		;DH=������,DL=��

		PUSH	CS
		POP	DS			;CS��DS
		PUSH	CS
		POP	ES			;CS��ES

		PUSH	DX
		PUSH	AX
		MOV	CL,AL			;��
		MOV	AL,AH			;��
		CBW
		MOV	DX,4*80 		;ÿ��4*80�ֽ�
		MUL	DX
		XOR	CH,CH
		ADD	AX,CX
		MOV	D_SI,AX 		;�������ʾ��������ַ
		MOV	D_DI,AX
		POP	AX
		POP	DX

		MOV	CL,AL			;��
		MOV	AL,80
		MUL	AH			;��*80
		XOR	CH,CH
		ADD	AX,CX			;+��
		SHL	AX,1
		ADD	AX,OFFSET D_XPQ
		MOV	SI,AX			;��������ַ
		MOV	DI,AX

		PUSH	DX
		MOV	AL,BL			;��������
		CBW
		MOV	DX,4*80 		;ÿ��4*80�ֽ�
		MUL	DX
		MOV	BP,AX			;�����ֽ���
		POP	DX

		MOV	AL,80
		MUL	BL			;������
		SHL	AX,1			;������������С

		XOR	CH,CH
		RET
S_GDFW		ENDP

;�ӳ���:��������һ��
S_XPGD		PROC	NEAR
		PUSH	AX
		MOV	CL,DL
		CMP	CS:D_67,6
		JNZ	L_GD3
		PUSHF				;���淽���־
		PUSH	SI
		PUSH	DI
		DEC	CX
		SHL	CX,1
		ADD	SI,CX			;����β
		ADD	DI,CX
		MOV	CL,DL
		MOV	AL,0A1H
		STD
L_GD1:
		CMP	[SI],AL
		JNB	L_GD2
		CMPSW				;��������ͬ?
		LOOPZ	L_GD1
		INC	CX
L_GD2:
		POP	DI
		POP	SI
		POPF				;�ָ������־
L_GD3:
		MOV	AL,CL
		PUSH	SI
		PUSH	DI
		REP	MOVSW			;��������
		POP	DI
		POP	SI

		PUSH	SI
		PUSH	DI
		CMP	CS:D_005A,0
		JZ	L_GD3A
		MOV	ES,D_B800
		MOV	DS,D_B800
		SUB	SI,OFFSET D_XPQ
		SUB	DI,OFFSET D_XPQ
		MOV	CL,AL
		REP	MOVSW			;д��������
L_GD3A:
		MOV	DS,CS:D_A000		;��ʾ��������
		MOV	ES,CS:D_A000
		MOV	SI,CS:D_SI		;��������ʾ��������ַ
		MOV	DI,CS:D_DI
		MOV	AH,4
		CMP	CS:D_67,7
		JZ	L_GD5
L_GD4:
		CALL	S_GD
		SUB	SI,5FB0H		;-6000H+50H
		SUB	DI,5FB0H
		DEC	AH
		JNZ	L_GD4
		JMP	SHORT L_GD6
L_GD5:
		CALL	S_GD
		SUB	SI,6050H
		SUB	DI,6050H
		DEC	AH
		JNZ	L_GD5
L_GD6:
		POP	DI
		POP	SI

		POP	AX
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		RET
S_XPGD		ENDP

S_GD		PROC	NEAR		;����
		CALL	S_GD2
		CALL	S_GD1
		CALL	S_GD1
S_GD1:
		ADD	SI,2000H
		ADD	DI,2000H
S_GD2:
		PUSH	SI
		PUSH	DI
		MOV	CL,AL
		REP	MOVSB
		POP	DI
		POP	SI
		RET
S_GD		ENDP

;�ӳ���:�������
S_KHTC		PROC	NEAR
		MOV	AL,' '
		MOV	CL,DL
		PUSH	DI
		REP	STOSW			;���������
		POP	DI

		PUSH	DI
		CMP	CS:D_005A,0
		JZ	L_TC1A
		MOV	ES,D_B800		;д������
		SUB	DI,OFFSET D_XPQ
		MOV	CL,DL
		REP	STOSW			;д�������
L_TC1A:
		MOV	ES,D_A000		;��ʾ��������
		MOV	DI,D_DI 		;����������ʾ��������ַ
		MOV	AL,BH
		MOV	DH,4
L_TC1:
		MOV	CL,DL
		PUSH	DI
L_TC2:
		MOV	ES:[DI+2000H],AL
		MOV	ES:[DI+4000H],AL
		MOV	ES:[DI+6000H],AL
		STOSB
		LOOP	L_TC2
		POP	DI
		CMP	CS:D_67,6
		JZ	L_TC3
		SUB	DI,80
		JMP	SHORT L_TC4
L_TC3:
		ADD	DI,80
L_TC4:
		DEC	DH
		JNZ	L_TC1
		POP	DI

		PUSH	CS
		POP	ES
		RET
S_KHTC		ENDP

;AH=7 �¹���ǰҳ AL=����,CX=���Ͻ�,DX=���½�,BH=�����������
L_AH07:
		CALL	S_QGB			 ;�ع��
		MOV	CS:D_67,AH
		CMP	CS:D_0059,0
		JZ	L_0702
		PUSH	AX
		MOV	AX,1404H
		INT	10H
		POP	AX
L_0702:
		CMP	CS:D_005A,0
		JZ	L_0703
		CLI
L_0703:
		STD
		CALL	S_GDHS			;�й�������
		MOV	AX,DX			;���½�
		CALL	S_GDFW			;������Χ,CS��DS
		SUB	SI,AX
		ADD	D_SI,3*80
		ADD	D_DI,3*80
		SUB	D_SI,BP
		MOV	BP,4*80

		OR	BL,BL
		JNZ	L_0704
		MOV	BL,DH
		JMP	SHORT L_0706
L_0704:
		MOV	AH,DH
		SUB	AH,BL
L_0705:
		CALL	S_XPGD			;�����¹�һ��
		SUB	SI,160			;ָ����һ��
		SUB	DI,160
		SUB	D_SI,BP
		SUB	D_DI,BP
		DEC	AH
		JNZ	L_0705
L_0706:
		MOV	AH,BH			;�ָ������������
		OR	AH,AH			;����=0?
		JNZ	L_0707
		MOV	AH,7
L_0707:
		SHR	BH,1			;ʵ�ʵĿ����������
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
L_0708:
		CALL	S_KHTC			;�������
		SUB	DI,160			;ָ����һ��
		SUB	D_DI,BP
		DEC	BL
		JNZ	L_0708

		CLD
		JMP	L_RET

;AH=8 ����ǰ���λ���ַ�AL������AH
L_AH08: 	CALL	S_XPDZ			;���㵱ǰ�������������ַ��SI
		MOV	AX,WORD PTR CS:D_XPQ[SI]
		POP	BX
		JMP	L_RET1

;�ӳ���:���㵱ǰ�������������ַ��SI
S_XPDZ		PROC	NEAR
		PUSH	BX
		CALL	S_DQGB
		POP	BX
		PUSH	AX
		PUSH	BX
		MOV	AX,DX
		MOV	BL,AL
		MOV	AL,80
		MUL	AH
		XOR	BH,BH
		ADD	AX,BX
		SHL	AX,1
		MOV	SI,AX
		POP	BX
		POP	AX
		RET
S_XPDZ		ENDP

;AH=9,0AH д���λ���ַ�AL������BL CX=����,BH=ҳ��
L_AH09:
		OR	CX,CX			;�ַ�����=0?
		JZ	L_0906
		CALL	S_QGB			;�ع��

		CALL	S_XPDZ			;���㵱ǰ�������������ַ��SI
		CMP	CS:D_005A,0
		JZ	L_0903
		CLI
		PUSH	BX
		XOR	BL,BL
		ADD	BH,0B0H
		MOV	ES,BX
		POP	BX

		MOV	DI,SI
		PUSH	CX
L_0901:
		STOSB				;��д����д�ַ�������
		CMP	AH,0AH
		JZ	L_0902
		MOV	ES:[DI],BL
L_0902:
		INC	DI
		LOOP	L_0901
		POP	CX

		CMP	BH,DS:[462H]		;���Ƿ�ǰҳ?
		JNZ	L_0908
L_0903:
		CMP	DH,24
		JA	L_0906
		ADD	SI,OFFSET D_XPQ
		PUSH	CX
L_0904:
		MOV	CS:[SI],AL		;д���ַ�����
		CMP	AH,0AH
		JZ	L_0905
		MOV	CS:[SI+1],BL		;д���ַ�����
L_0905:
		ADD	SI,2
		LOOP	L_0904
		POP	CX

		CMP	AH,0AH
		JNZ	L_0906
		MOV	BL,CS:[SI-1]		;ȡ�ַ�����
L_0906:
		XOR	BP,BP
	;	CMP	CS:D_005A,0		;4.26
	;	JZ	L_0906A
		CMP	CS:D_0060,1
		JNZ	L_0907
L_0906A:
		TEST	BL,80H			;���ʽ?
		JZ	L_0907
		NOT	BP
L_0907:
		CALL	S_XS			;��ʾ
L_0908:
		JMP	L_RET			;����

;�ӳ���:��ʾ
S_XS		PROC	NEAR
		CMP	AL,0FFH 		;�ַ�ASC��=0FFH?
		JZ	L_XSZF
K_HZ	EQU	$-2
		CMP	AL,0A0H 		;�к���?
		JBE	L_XSZF
		CMP	CX,1
		JNZ	L_XSZF
		OR	BP,BP
		JNZ	L_XSZF
		CMP	CS:D_0050,0		;��ǰ�ֽ�?
		JNZ	L_XS1
L_XS0:
		MOV	CS:D_0050,AL		;��ǰ�ֽ�
		MOV	CS:D_0051,BL		;	 ����
		MOV	CS:D_0052,DX		;	 λ��
		JMP	SHORT L_XSZF		;����չASC����ʾǰ�ֽ�
L_XS2:
		INC	DX
		JMP	SHORT L_XS0		;����չASC����ʾ���ֽ�
L_XS1:
		OR	DL,DL			;���һλ
		JZ	L_XS0
		DEC	DX
		CMP	DX,CS:D_0052		;�Ƿ�ǰ�ֽ�?
		JNZ	L_XS2
		MOV	AH,CS:D_0050		;ȡǰ�ֽ�
		MOV	BH,CS:D_0051		;����ֽ�����
	;�ӳ���:��ʾ���� ǰ�ֽ�AH,����BH,λ��DX,���ֽ�AL,����BL
S_XSHZ:
		PUSH	DX
		CALL	S_ZMZH			;���ֿⲢת����DS:SI=60H
		POP	DX			;�����λ��
		CALL	S_SPDZ			;������DX��ʵ������ַ��DI
		PUSH	BX
		MOV	BL,BH			;ǰ�ֽ�����
		CALL	S_ZMXS			;��ģ����ʾ������
		INC	DI			;ָ���Ұ���
		POP	BX			;���ֽ�����
		MOV	SI,70H
		CALL	S_ZMXS			;��ģ����ʾ������
		MOV	CS:D_0050,0		;��ǰ�ֽ�
		RET

	;�ӳ���:��ʾ�ַ�AL DX=���λ��,CX=����,BL=����
S_XSZF:
		OR	CX,CX
		JZ	L_ZF4
L_XSZF:
		CMP	CS:D_005A,1		;��ֱ��д��?
		JNZ	L_ZF1
		PUSH	BX
		CALL	S_ALVB			;ת�����Ʊ���
		POP	BX
L_ZF1:
		CALL	S_ZFZH			;���ַ��Ⲣת����DS:SI=60H
		CALL	S_SPDZ			;������DX��ʵ������ַ��DI
L_ZF2:
		PUSH	SI
		CALL	S_ZMXS			;��ʾ�ַ�
		POP	SI
		INC	DL
		CMP	DL,80
		JNZ	L_ZF3
		XOR	DL,DL
		CMP	DH,18H
		JZ	L_ZF3
		INC	DH
L_ZF3:
		CALL	S_SPDZ
		LOOP	L_ZF2
L_ZF4:
		RET
S_XS		ENDP

D_K		DW	1			;=1:�ӿ�
;�ӳ���:��ģ����ʾ������
S_ZMXS		PROC	NEAR
		PUSH	DI
		PUSH	CX
		PUSH	DX
		MOV	CX,4
L_ZM1:
		LODSB
		TEST	BL,70H
		JZ	L_ZM2
		NOT	AL
L_ZM2:
		CMP	CS:D_K,2
		JZ	L_ZM3A
		OR	BP,BP			;���ʽ?
		JZ	L_ZM3
		XOR	AL,ES:[DI]
L_ZM3:
		MOV	ES:[DI],AL
		JMP	SHORT L_ZM3C
L_ZM3A:
		CALL	S_KZ
		OR	BP,BP			;���ʽ?
		JZ	L_ZM3B
		XOR	AL,ES:[DI]
		XOR	AH,ES:[DI+1]
L_ZM3B:
		MOV	ES:[DI],AX
L_ZM3C:
		LODSB
		TEST	BL,70H
		JZ	L_ZM4
		NOT	AL
L_ZM4:
		CMP	CS:D_K,2
		JZ	L_ZM5A
		OR	BP,BP
		JZ	L_ZM5
		XOR	AL,ES:[DI+2000H]
L_ZM5:
		MOV	ES:[DI+2000H],AL
		JMP	SHORT L_ZM5C
L_ZM5A:
		CALL	S_KZ
		OR	BP,BP
		JZ	L_ZM5B
		XOR	AL,ES:[DI+2000H]
		XOR	AH,ES:[DI+2001H]
L_ZM5B:
		MOV	ES:[DI+2000H],AX
L_ZM5C:
		LODSB
		TEST	BL,70H
		JZ	L_ZM6
		NOT	AL
L_ZM6:
		CMP	CS:D_K,2
		JZ	L_ZM7A
		OR	BP,BP
		JZ	L_ZM7
		XOR	AL,ES:[DI+4000H]
L_ZM7:
		MOV	ES:[DI+4000H],AL
		JMP	SHORT L_ZM7C
L_ZM7A:
		CALL	S_KZ
		OR	BP,BP
		JZ	L_ZM7B
		XOR	AL,ES:[DI+4000H]
		XOR	AH,ES:[DI+4001H]
L_ZM7B:
		MOV	ES:[DI+4000H],AX
L_ZM7C:
		LODSB
		TEST	BL,70H
		JZ	L_ZM8
		NOT	AL
L_ZM8:
		CMP	CS:D_K,2
		JZ	L_ZM9A
		OR	BP,BP
		JZ	L_ZM9
		XOR	AL,ES:[DI+6000H]
L_ZM9:
		MOV	ES:[DI+6000H],AL
		JMP	SHORT L_ZM9C
L_ZM9A:
		CALL	S_KZ
		OR	BP,BP
		JZ	L_ZM9B
		XOR	AL,ES:[DI+6000H]
		XOR	AH,ES:[DI+6001H]
L_ZM9B:
		MOV	ES:[DI+6000H],AX
L_ZM9C:
		ADD	DI,80
		LOOP	L_ZMA
		POP	DX
		POP	CX
		POP	DI
		RET
L_ZMA:
		JMP	L_ZM1
;�ӳ���:�ֽ�AL��չAL->AX
S_KZ:
		MOV	CH,8
L_KZ1:					       ;��չ
		RCL	AL,1
		LAHF
		RCL	DX,1
		SAHF
		RCL	DX,1
		DEC	CH
		JNZ	L_KZ1
		MOV	AX,DX
		XCHG	AH,AL
		RET
S_ZMXS		ENDP

;�ӳ���:������DX��ʵ������ַ��DI
S_SPDZ		PROC	NEAR
		PUSH	AX
		PUSH	DX
		PUSH	BX
		MOV	BX,DX
		MOV	AL,DH			;�к�
		CBW
		MOV	DX,4*80 		;ÿ�ַ���ռʵ�����ֽ���
		MUL	DX			;���׵�ַ
		XOR	BH,BH
		ADD	AX,BX
		MOV	DI,AX			;ʵ������ַ
		MOV	AX,0B800H
		MOV	ES,AX
		POP	BX
		POP	DX
		POP	AX
		RET
S_SPDZ		ENDP

	INCLUDE GB.INC

;�ӳ���:��ʾ���
S_XSGB		PROC	NEAR
		NOT	BYTE PTR CS:[102H]
S_XSGB0:
		MOV	CX,CS:D_005E
		OR	CX,CX
		JZ	L_GB5
S_XSGB1:
		CMP	DL,4FH
		JBE	L_GB3
		RET
L_GB3:
		PUSH	ES
		CALL	S_SPDZ			;������DX��ʵ������ַ��DI

		ADD	DI,3*80
L_GB4:
		NOT	BYTE PTR ES:[DI+6000H]
		DEC	CX
		JZ	L_GB4A
		NOT	BYTE PTR ES:[DI+4000H]
		DEC	CX
		JZ	L_GB4A
		NOT	BYTE PTR ES:[DI+2000H]
		DEC	CX
		JZ	L_GB4A
		NOT	BYTE PTR ES:[DI]
		SUB	DI,80
		DEC	CX
		JNZ	L_GB4
L_GB4A:
		POP	ES
L_GB5:
		STI
		RET
S_XSGB		ENDP

;AH=0DH ���� CX=��, DX=�� AL=��ɫֵ
L_AH0D: 	CALL	S_DWZ
		MOV	SI,AX
		MOV	AL,ES:[SI]
		ROL	AL,CL
		MOV	CL,7
		SHR	AL,CL
		JMP	L_RET

;AH=0CH д�� AL=��ɫֵ(λ7=1���), CX=��, DX=��
L_AH0C: 	PUSH	AX
		CALL	S_DWZ
		MOV	SI,AX
		MOV	BL,ES:[SI]
		ROL	BL,CL
		POP	AX
		AND	AL,81H
		JS	L_0C02
		ROR	AL,1
		AND	BL,7FH
		OR	BL,AL
L_0C01:
		ROR	BL,CL
		MOV	ES:[SI],BL
		JMP	L_RET
L_0C02:
		AND	AL,1
		ROR	AL,1
		XOR	BL,AL
		JMP	SHORT L_0C01
;�ӳ���:�����λ��
S_DWZ		PROC	NEAR
		MOV	AX,0B800H
		MOV	ES,AX
		XOR	AX,AX
		SHR	DX,1
		JNB	L_DWZ1
		ADD	AX,2000H
L_DWZ1:
		SHR	DX,1
		JNB	L_DWZ2
		ADD	AX,4000H
L_DWZ2:
		XCHG	AX,DX
		MOV	AH,50H
		MUL	AH
		ADD	DX,AX
		MOV	AX,CX
		MOV	CL,8
		DIV	CL
		MOV	CL,AH
		XOR	AH,AH
		ADD	AX,DX
		RET
S_DWZ		ENDP

	INCLUDE AH0E.INC
	INCLUDE AH13.INC

;AH=14H ��ʾ�й���
;	AL=0 ����ʾ��
;	AL=1 ��ʾ�ַ�DL CL=����
;	AL=2 ��ʾ�й�궨λDL
;	AL=3 ��ʾ�ַ�DL���ƽ����
;	AL=4 �ر���ʾ��
;	AL=5 ������ʾ����ɫBL������λ��BH
;	AL=6 ȡ��ʾ���� AL=��ʾ��ʽ,AH=���ɫ��
;			BL=��ʾ������ʽ,BH=����λ��
;			CL=��ʾ����,CH=ÿ��ɨ������
;			DL=��ʾ���Ʋ���,DH=��ʾ�е�ǰ�к�
;			SI=�������,DI=����ɨ������
;			BP=��ʾ��������
;	AL=7 ���ö�����ʾ��ʽBH
;	AL=8 λ��DX���ַ�������ʾ
;	AL=9 ��ָ��λ��DX��ʾ�ַ�BH
;	AL=10 ��ָ��λ��DL��ʾBL����BP:SI���ĵ���64�ֽ�
;	AL=11 ���ù����˸����BH
;	AL=12 ȡ��������ַ BX:AX
;	AL=13 ֱ��д������BH
;	AL=14 ȡ�����Ʊ���ת������ַ BX:AX				1.18
;	AL=15 ��ָ��λ��DX��ʾ�ӿ��ַ���DS:SI(����BL)
L_AH14:
		OR	AL,AL			;<����ʾ��>
		JNZ	L_1410
		MOV	CS:D_0058,AL		;��ʾ�ж�λ�����
		MOV	CS:D_0062,AL
		CMP	CS:D_0059,AL		;��ʾ���Ѵ�?
		JNZ	L_1402
		MOV	DH,18H
		CMP	DH,DS:[451H]		;�Ƿ��18H��?
		JNZ	L_1401
		MOV	DH,CS:D_005B		;ȡ����λ��
L_1401:
		MOV	CS:D_0059,DH		;����ʾ��λ��
		XOR	DL,DL
		CALL	S_SPDZ			;������DX��ʵ������ַ��DI
		MOV	SI,DI
		MOV	DI,OFFSET D_TUXBC
		MOV	CX,80*4
L_1401A:
		MOV	AL,ES:[SI]
		MOV	AH,ES:[SI+2000H]
		MOV	CS:[DI],AX
		MOV	AL,ES:[SI+4000H]
		MOV	AH,ES:[SI+6000H]
		MOV	CS:[DI+2],AX
		INC	SI
		ADD	DI,4
		LOOP	L_1401A
		CALL	S_TXGB
L_1402:
		MOV	DL,' '
		MOV	CX,80
L_1403:
		MOV	BL,7
		CALL	S_TXZF			;����ʾ��
L_1405:
		JMP	L_RET
L_1410:
		CMP	AL,1			;<д�ַ�DL>
		JNZ	L_1420
		OR	CX,CX
		JZ	L_1405
		CALL	S_DKTX
		JMP	SHORT L_1403
L_1420:
		CMP	AL,2			;<��궨λ>
		JNZ	L_1430
		CALL	S_DKTX
		CALL	S_TXGB
		CMP	DL,79
		JA	L_1423			;9.29
		MOV	CS:D_0058,DL
L_1422:
		CALL	S_TXGB
L_1423:
		JMP	L_RET
L_1430:
		CMP	AL,3			;<д�ַ����ƽ����>
		JNZ	L_1440
		CMP	DL,7			;����?
		JNZ	L_1431
		MOV	AX,0E07H
		INT	10H
		JMP	L_RET
L_1431:
		CALL	S_DKTX
		CMP	DL,8			;�˸�?
		JNZ	L_1433
		CALL	S_TXGB
		MOV	AL,CS:D_0058		;ȡ��ʾ�й��λ��
		OR	AL,AL			;=0? (����)
		JZ	L_1432
		DEC	AX			;�������
L_1432:
		MOV	CS:D_0058,AL		;����λ��
		MOV	DL,' '
		MOV	CX,1
		MOV	BL,7
		CALL	S_TXZF
		JMP	SHORT L_1422
L_1433:
		CALL	S_TXGB
		MOV	CX,1
		CALL	S_TXZF			;��ʾ�ַ�
		MOV	AL,CS:D_0058		;ȡ��ʾ�й��λ��
		CMP	AL,79			;����β?
		JNB	L_1422
		INC	AX			;�������
		MOV	CS:D_0058,AL		;����λ��
		JMP	SHORT L_1422
L_1440:
		CMP	AL,4			;<�ر���ʾ��>
		JNZ	L_1450
		MOV	DH,CS:D_0059		;ȡ��ʾ�к�
		OR	DH,DH			;��������ʾ��?
		JZ	L_1442
		XOR	DL,DL			;����
		MOV	CS:D_0059,DL		;����ʾ�к�
		CALL	S_SPDZ			;������DX��ʵ������ַ��DI
		MOV	SI,OFFSET D_TUXBC	;��ʾ�б�����
		MOV	CX,80*4
L_1441:
		MOV	AX,CS:[SI]
		MOV	ES:[DI],AL
		MOV	ES:[DI+2000H],AH
		MOV	AX,CS:[SI+2]
		MOV	ES:[DI+4000H],AL
		MOV	ES:[DI+6000H],AH
		ADD	SI,4
		INC	DI
		LOOP	L_1441
L_1442:
		JMP	L_RET
L_1450:
		CMP	AL,5			;<������ʾ�и���λ��>
		JNZ	L_1460
		MOV	CS:D_005B,BH
		JMP	L_RET
L_1460:
		CMP	AL,6			;<ȡ��ʾ����>
		JNZ	L_1470
		MOV	AX,109H 		;AH=���ɫ��,AL=��ʾ��ʽ
		MOV	BH,CS:D_005B		;��ʾ�и���λ��
		MOV	BL,BYTE PTR CS:K_VJXP
		MOV	CX,1019H		;ȡÿ��ɨ����������ʾ����
		MOV	DH,CS:D_0059		;��ʾ��λ��

		PUSH	AX
		XOR	DL,DL
		MOV	AX,CS:[0F4H]
		SHR	AL,1			;����չ�ַ���
		RCR	DL,1			;λ5
		SHR	AL,1			;������ʾ�д�
		RCR	DL,1			;λ6
		SHR	DL,1			;λ7
		CMP	CS:D_005A,0		;��ֱ��д��	9.26
		JZ	L_1463
		OR	DL,80H
L_1463:
		MOV	AL,BYTE PTR CS:D_6	;>5������
		AND	AL,10H
		OR	DL,AL			;λ4
		OR	DL,CS:D_0069		;��
		POP	AX

		MOV	SI,639			;�������
		MOV	DI,399			;����ɨ������
		MOV	BP,0B800H
		POP	ES
		POP	ES
		POP	ES
		POP	ES
		POP	ES
		POP	ES
		POP	ES
		JMP	L_RET2
L_1470:
		CMP	AL,7			;<���ö�����ʾ��ʽ>
		JNZ	L_1480
		MOV	CS:D_0064,BH
		MOV	DS:[449H],BH
		JMP	L_RET
L_1480:
		CMP	AL,8			;<λ��DX���ַ�����>
		JNZ	L_1490
		MOV	CX,16
		CALL	S_XSGB1
		JMP	L_RET
L_1490:
		CMP	AL,9			;<��ָ��λ��DX��ʾ�ַ�BH>
K_1490	EQU	$
		JNZ	L_14A0
		MOV	AL,BH
		XOR	BP,BP
		OR	CX,CX			;=0:���ַ���ʾ
		JNZ	L_1491
		INC	CX
		CALL	S_XSZF
		JMP	L_RET
L_1491:
		CMP	CX,-1			;=-1:ֱ��д����ʾ
		JZ	L_1492
		CMP	CS:D_005A,1		;��ֱ��д��?
		JNZ	L_1492
		MOV	AL,80
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX
		SHL	AX,1
		MOV	DI,AX
		MOV	ES,CS:D_B800
		XCHG	BL,BH
		MOV	ES:[DI],BX
		JMP	L_RET
L_1492:
		MOV	CX,1			;����:����ʾ����
		CALL	S_XS
		JMP	L_RET
L_14A0:
		CMP	AL,10			;<��ָ��λ��DL��ʾBL����
		JNZ	L_14B0			; BP:SI���ĵ���64�ֽ�>
		MOV	DS,BP
		MOV	DH,CS:D_0059		;��ʾ�к�
		CALL	S_SPDZ			;������DX��ʵ������ַ��DI
		XOR	BP,BP
		MOV	CX,4
L_14A1:
		CALL	S_ZMXS
		INC	DI
		LOOP	L_14A1
		JMP	L_RET
L_14B0:
		CMP	AL,11			;<�����˸����>
		JNZ	L_14C0
		MOV	AL,0C3H 		;RET
		OR	BH,BH
		JZ	L_14B1
		MOV	AL,90H			;NOP
L_14B1:
		MOV	BYTE PTR CS:K_GBSS,AL
		MOV	CS:D_NUM1,0
		JMP	L_RET
L_14C0:
		CMP	AL,12			;<ȡ��������ַBX:AX>
		JNZ	L_14D0
		MOV	AX,OFFSET D_XPQ
L_14C1:
		PUSH	CS
		POP	BX
		POP	CX
		POP	CX
		JMP	L_RET3
L_14D0: 					;<ֱ��д������>
		CMP	AL,13
		JNZ	L_14E0
		OR	BH,BH
		JZ	L_14D9
		MOV	CS:D_ZJXP,BH
L_14D9:
		JMP	L_RET
L_14E0:
		CMP	AL,14			;<ȡ�����Ʊ���ת������ַ>1.18
		JNZ	L_14F0
		MOV	AX,OFFSET D_ZBFB
		JMP	SHORT L_14C1
L_14F0:
		CMP	AL,15			;<��ָ��λ��DX��ʾ�ӿ��ַ���ES:SI,��0��β>
		JNZ	L_14D9
		MOV	CS:D_K,2		;�ӿ���־
		MOV	CS:D_0062,0
		XOR	BP,BP
L_14F1:
		MOV	AL,ES:[SI]
		INC	SI
		OR	AL,AL			;����?
		JZ	L_14F4

		CMP	AL,0A0H 		;�к���?
		JBE	L_14F3
		CMP	CS:D_0062,0		;��ǰ�ֽ�?
		JNZ	L_14F2
		MOV	CS:D_0062,AL		;��
		JMP	SHORT L_14F1
L_14F2:
		MOV	AH,CS:D_0062		;ȡǰ�ֽ�
		MOV	CS:D_0062,0
		PUSH	ES
		PUSH	BX
		PUSH	DX
		PUSH	SI
		MOV	BH,BL
		CALL	S_XSHZ			;��ʾ����
		POP	SI
		POP	DX
		POP	BX
		POP	ES
		ADD	DX,4			;λ�ú���
		JMP	SHORT L_14F1
L_14F3:
		XOR	DI,DI
		MOV	DS,DI
		PUSH	ES
		PUSH	BX
		PUSH	DX
		PUSH	SI
		MOV	CX,1
		CALL	S_XSZF			;��ʾ�ַ�
		POP	SI
		POP	DX
		POP	BX
		POP	ES
		ADD	DX,2			;λ�ú���
		JMP	SHORT L_14F1
L_14F4:
		MOV	CS:D_K,1		;���־
		JMP	L_RET

;�ӳ���:���Ƿ����ʾ��
S_DKTX		PROC	NEAR
		CMP	CS:D_0059,0
		JNZ	L_DK1
		MOV	AX,1400H
		INT	10H
L_DK1:
		RET
S_DKTX		ENDP

;�ӳ���:��ʾ�й�괦��
S_TXGB		PROC	NEAR
		PUSH	BX
		PUSH	DX
		MOV	DX,WORD PTR CS:D_0058
		CALL	S_XSGB0
		POP	DX
		POP	BX
		RET
S_TXGB		ENDP

;�ӳ���:����ʾ��д�ַ�
S_TXZF		PROC	NEAR
		XOR	BP,BP
		MOV	AL,DL			;�ַ�
		AND	BL,0EFH
		MOV	DX,WORD PTR CS:D_0058	;λ��
		CMP	CS:D_0062,0		;�к���ǰ�ֽ�?
		JNZ	L_TX2
		CMP	AL,0A0H 		;�к���?
		JBE	L_TX1
		MOV	CS:D_0062,AL		;�溺��ǰ�ֽ�
		MOV	CS:D_0051,BL		;��ǰ�ֽ�����
L_TX1:
		JMP	S_XSZF
L_TX2:
		CMP	AL,0A0H
		JBE	L_TX3
		MOV	AH,CS:D_0062		;ȡǰ�ֽ�
		MOV	BH,CS:D_0051		;����ֽ�����
		DEC	DX
		MOV	CS:D_0062,0		;��ǰ�ֽ�
		JMP	S_XSHZ			;��ʾ����
L_TX3:
		MOV	CS:D_0062,0		;��ǰ�ֽ�
		JMP	SHORT L_TX1
S_TXZF		ENDP

;�ӳ���:���ֿⲢת�� DX=�������� ��DS:60H
S_ZMZH		PROC	NEAR
		MOV	DX,AX
		MOV	AH,CS:D_0069		;��-��
		INT	7FH			;���ֿⲢת��
		MOV	DS,DX			;��ģ��
		XOR	SI,SI			;    ƫ��
		MOV	DI,60H			 ;ת����ַ
		MOV	CX,16
L_ZMZH1:
		LODSW
		MOV	CS:[DI],AL		;д�����
		MOV	CS:[DI+10H],AH		;д�Ұ���
		INC	DI
		LOOP	L_ZMZH1
		PUSH	CS
		POP	DS
		MOV	SI,60H
		RET
S_ZMZH		ENDP

;�ӳ���:���ַ��Ⲣת�� AL=ASC�� ��DS:60H
S_ZFZH1 	PROC	NEAR
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	DI,60H

		PUSH	CX
		MOV	CX,8
		JMP	SHORT L_ZFZH0
S_ZFZH:
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	DI,60H

		PUSH	CX
		MOV	CX,8
		TEST	BYTE PTR CS:[0F4H],4	;=1:��ʾ��KZZF
		JZ	L_ZFZH1
L_ZFZH0:
		TEST	BYTE PTR CS:[0F4H],1	;=1:��չ�ַ���
		JZ	L_ZFZH1
		MOV	CL,16
		MOV	SI,OFFSET D_KZZFQ
		MUL	CL
		ADD	SI,AX
		REP	MOVSB
		JMP	SHORT L_ZFZH5
L_ZFZH1:
		CMP	AL,80H			;��չASC��?
		JB	L_ZFZH3
		SUB	AL,80H
		MUL	CL
		ADD	AX,OFFSET D_ZF80	;�Դ���չASC�ַ���ģ
		MOV	SI,AX
L_ZFZH2:
		LODSB
		STOSB
		STOSB
		LOOP	L_ZFZH2
		JMP	SHORT L_ZFZH5
L_ZFZH3:
		MUL	CL
		ADD	AX,0FA6EH		;ROM-BIOS�ַ�����ַ
		MOV	SI,AX
		MOV	AX,0F000H
		MOV	DS,AX			;ROM-BIOS��
		XOR	AX,AX
		STOSW
		STOSB
		MOV	CL,4
L_ZFZH4:
		MOVSB
		LODSB
		STOSB
		STOSB
		LOOP	L_ZFZH4
		XOR	AL,AL
		STOSB
		PUSH	CS
		POP	DS
L_ZFZH5:
		POP	CX
		MOV	SI,60H
		RET
S_ZFZH1 	ENDP

;AH=16H ȡ���ֻ��ַ���ģ DX=����,BP:BX=���͵�ַ
L_AH16: 	OR	DH,DH			;�к���?
		JZ	L_1601
		CALL	S_ZMZH			;�����ֿⲢת��
		MOV	ES,BP			;Ŀ���
		MOV	DI,BX			;    ƫ��
		MOV	CX,16
		REP	MOVSW			;����
		JMP	L_RET
L_1601:
		CALL	S_ZFZH1 		;���ַ��Ⲣת��
		MOV	ES,BP			;Ŀ���
		MOV	DI,BX			;    ƫ��
		MOV	CX,16
		MOVSB				;����
		JMP	L_RET

;AH=17H ������
L_AH17:
		OR	AL,AL
		JZ	L_1703
		MOV	BYTE PTR CS:[101H],1	;�����
L_AH15:
		CALL	S_GB
		JMP	L_RET
L_1703:
		CALL	S_QGB
		MOV	CS:[101H],AL		;�ع��
		JMP	L_RET

;AH=18H AL=0ʶ����		AL=1��ʶ����
;	AL=2���Ը�λ����	AL=3���
;	AL=4������������ʾ��ʽ	AL=5����
;	AL=10�ر�ֱ��д��	AL=11�ָ�ֱ��д��
;	AL=12�����Ʊ���������ʽ
;	AL=13����С���� BH=1��AH=1����;BH=0,BL=����С
;	AL=14��ʾ��ʽ>=6Ϊ����	AL=15�ָ�ԭ��ʽ
;	AL=16���ø�λ��˸
;	AL=17����		AL=18����
;	AL=19������Ļ
;	AL=20�ر�ʱ����ʾ	AL=21�ָ�ʱ����ʾ
;	AL=23��������
;	AL=28:INT10AH=6~10ֱ��д��	AL=29�ָ�
D_AH18		DW	OFFSET L_1800
		DW	OFFSET L_1801
		DW	OFFSET L_1802
		DW	OFFSET L_1803
		DW	OFFSET L_1804
		DW	OFFSET L_1805
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_1810
		DW	OFFSET L_1811
		DW	OFFSET L_1812
		DW	OFFSET L_1813
		DW	OFFSET L_1814
		DW	OFFSET L_1815
		DW	OFFSET L_1816
		DW	OFFSET L_1817
		DW	OFFSET L_1818
		DW	OFFSET L_1819
		DW	OFFSET L_1820
		DW	OFFSET L_1821
		DW	OFFSET L_18000
		DW	OFFSET L_1823
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_18000
		DW	OFFSET L_1828
		DW	OFFSET L_1829
L_AH18:
		CMP	AL,29
		JA	L_1899
		CBW
		MOV	DI,AX
		SHL	DI,1
		CALL	CS:D_AH18[DI]
L_1899:
		JMP	L_RET
L_1800: 					;<ʶ����>
		MOV	AL,74H			;JZ
L_18001:
		MOV	BYTE PTR CS:K_HZ,AL
		MOV	BYTE PTR CS:K_HZ1,AL
L_18000:
		RET
L_1801: 					;<��ʶ����>
		MOV	AL,0EBH 		;JMP SHORT
		JMP	SHORT L_18001
L_1802: 					;<���Ը�λ����>
L_1803: 					;<��λ���>
		SUB	AL,2
L_18022:
		MOV	CS:D_0060,AL
		RET
L_1804: 					;<������������ʾ��ʽ>
		MOV	CS:D_AH,OFFSET L_RET
		RET
L_1805: 					;<����������ʾ��ʽ>
		MOV	CS:D_AH,OFFSET L_AH00
		RET
L_1810: 					;<�ر�ֱ��д��>
		MOV	BYTE PTR CS:K_VJXP,0
		MOV	AX,9			;			9.11
L_1810B:
		INT	10H
L_1810A:
		RET
L_1811: 					;<��ֱ��д��>
		TEST	BYTE PTR CS:[0F5H],1	;=1:����ֱ��д��
		JZ	L_1810A
		MOV	BYTE PTR CS:K_VJXP,4
		MOV	AX,3			;			9.11
		JMP	SHORT L_1810B
L_1812: 					;<�����Ʊ���������ʽ>
		MOV	CS:D_ZBFS,BH
		RET
L_1813: 					;<����С����>
		OR	BH,BH
		JZ	L_18131
		MOV	CS:D_AH01,OFFSET L_AH01
		RET
L_18131:
		MOV	CS:D_AH01,OFFSET L_RET
		MOV	CS:D_005E,BX
		RET
L_1814: 					;<��ʾ��ʽ>=6Ϊ����>
		MOV	AX,673H
L_18141:
		MOV	BYTE PTR CS:D_6,AH
		MOV	BYTE PTR CS:D_6+1,AL
		RET
L_1815: 					;<�ָ�ԭ��ʽ>
		MOV	AX,974H
		JMP	SHORT L_18141
L_1816: 					;<��λ��˸>
		MOV	AL,2
		JMP	L_18022
L_1817: 					;<����>
L_1818: 					;<����>
		SUB	AL,17
		MOV	CS:D_0069,AL
		RET
L_1819: 					;<������Ļ>
		PUSH	CS
		POP	DS
		MOV	SI,OFFSET D_XPQ
		XOR	DX,DX			;�������Ͻ�
L_1819A:
		LODSW				;ȡ��괦�ַ�������
		XCHG	AH,AL
		MOV	BX,AX
		MOV	CX,1
		MOV	AX,1409H		;��ʾ
		INT	10H
		INC	DX
		CMP	DL,80
		JB	L_1819A
		XOR	DL,DL
		INC	DH
		CMP	DH,25
		JB	L_1819A
		CALL	S_XGB
		RET
L_1820: 					;<�ر�ʱ����ʾ>
		MOV	AL,0EBH
L_18201:
		MOV	BYTE PTR CS:K_1490,AL
		RET
L_1821: 					;<�ָ�ʱ����ʾ>
		MOV	AL,75H
		JMP	SHORT L_18201
L_1823: 					;<��������>
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_XPQ
		MOV	CX,25*80
		XOR	AX,AX
		REP	STOSW
		RET
L_1828: 					;<INT10AH=6~10ֱ��д��>
		MOV	AL,72H			;JB
L_18281:
		MOV	BYTE PTR CS:K_10ZJXP,AL
		RET
L_1829: 					;<�ָ�INT10>
		MOV	AL,0EBH 		;JMP
		JMP	SHORT L_18281

S_SETB8 	PROC	NEAR
		RET
S_SETB8 	ENDP

	INCLUDE INT8.INC
	INCLUDE ZJXP.INC

D_XPQ		DB	25*80*2 DUP(0)		;������
D_TUXBC 	DB	16*80 DUP(0)		;��ʾ�и���������
D_KZZFQ 	DB	4096 DUP(0)		;��չ�ַ���
D_KZZF		DB	'KZZF',0

;****************************************************************************
;����ִ�п�ʼ
BEGIN:
		MOV	AX,3510H
		INT	21H			;ȡԭINT10��ַ
		MOV	WORD PTR D_INT10,BX	;����
		MOV	WORD PTR D_INT10+2,ES
		MOV	AX,3508H
		INT	21H			;ȡԭINT8��ַ
		MOV	WORD PTR D_INT8,BX	;����
		MOV	WORD PTR D_INT8+2,ES

		XOR	AX,AX
		MOV	ES,AX
		MOV	BYTE PTR ES:[484H],18H	;��ʾ����

		XOR	BP,BP
		MOV	AH,2FH			;ȡ����ģ���
		INT	16H
		OR	BP,BP			;��?
		JNZ	L_S10
		MOV	BP,CS
L_S10:
		MOV	D_INT16,BP		;����ģ���
		MOV	ES,BP			;����ģ���	1.20

		MOV	AX,CS
		CMP	AX,BP			;�����޼���ģ��?	1.14
		JZ	L_S21
		MOV	AX,ES:[0F4H]		;��ʾ����
		MOV	DS:[0F4H],AX
		MOV	AX,ES:[0F6H]
		MOV	DS:[0F6H],AX
		PUSH	CS
		POP	ES
		JMP	SHORT L_S22
L_S21:
		MOV	BYTE PTR DS:[0F4H],8	;����ʾ�汾��Ϣ
		MOV	BYTE PTR DS:[0F5H],1	;����ֱ��д��
		MOV	BYTE PTR DS:[0F6H],1	;ԭ�з�ʽ
		MOV	BYTE PTR DS:[0F7H],9	;��ʾ�й��ɫ
L_S22:
		MOV	SI,80H			;�����в�������
		LODSB
		OR	AL,AL			;�в���?
		JNZ	L_S30
L_S23:
		JMP	L_S60			;�����н���
L_S30:
		LODSB
		CMP	AL,' '                  ;�ո�?
		JZ	L_S30
		CMP	AL,0DH			;����?
		JZ	L_S23
		CMP	AL,'/'                  ;���ط�?
		JNZ	L_S30
		LODSB
		CMP	AL,'?'                  ;<��ʾ����>
		JNZ	L_S31
		MOV	DX,OFFSET MSG		;����
		MOV	AH,9
		INT	21H
		INT	20H
L_S31:
		AND	AL,5FH
		CMP	AL,'G'                  ;<�̶����2��>
		JNZ	L_S32
		MOV	D_AH01,OFFSET L_RET
		OR	BYTE PTR ES:[0F6H],2
		JMP	L_S30
L_S32:
		CMP	AL,'H'                  ;<��ʾ��ʽ>5��Ϊ����>
		JNZ	L_S33
		MOV	BYTE PTR D_6,6
		MOV	BYTE PTR D_6+1,73H
		AND	BYTE PTR ES:[0F6H],0FEH
		JMP	L_S30
L_S33:
		CMP	AL,'K'                  ;<��װKZZF>
		JNZ	L_S34
		OR	BYTE PTR ES:[0F4H],5
		JMP	L_S30
L_S34:
		CMP	AL,'L'                  ;<��װKZZF,��ʾ��BIOS>
		JNZ	L_S35
		OR	BYTE PTR ES:[0F4H],1
		JMP	L_S30
L_S35:
		CMP	AL,'N'                  ;<פ�������ڴ�>
		JNZ	L_S36
		MOV	D_RAM,AL
		JMP	L_S30
L_S36:
		CMP	AL,'P'                  ;<��ʾ�жϵ�BIOS>
		JNZ	L_S37
		MOV	BYTE PTR DS:K_10ZJXP,72H
		OR	BYTE PTR ES:[0F5H],4
		JMP	L_S30
L_S37:
		CMP	AL,'X'                  ;<����ʾ�汾��Ϣ>
		JNZ	L_S38
		OR	BYTE PTR ES:[0F4H],8
		JMP	L_S30
L_S38:
		CMP	AL,'Z'                  ;<��ֱֹ��д��>
		JNZ	L_S50
		MOV	BYTE PTR K_VJXP,0	;��ֱֹ��д��
		MOV	BYTE PTR K_VJXP1,0
		AND	BYTE PTR ES:[0F5H],0FEH
L_S50:
		JMP	L_S30
L_S60:
		MOV	BP,OFFSET D_KZZFQ
		TEST	BYTE PTR DS:[0F4H],1   ;��װKZZF
		JZ	L_S61
		MOV	DX,OFFSET D_KZZF	;'KZZF',0
		MOV	AX,3D00H		;���ļ�
		INT	21H
		JB	L_S61
		MOV	BX,AX
		MOV	DX,BP
		MOV	CX,1000H
		MOV	AH,3FH			;��
		INT	21H
		MOV	AH,3EH			;�ر�
		INT	21H
		ADD	BP,1000H
L_S61:
		MOV	D_LEN0,BP
		MOV	CL,4
		SHR	BP,CL
		INC	BP			;פ������(��)
		MOV	D_LEN,BP

		MOV	AH,-1			;ȡ��װģ��?
		INT	10H
		CMP	AX,45H			;�а�װ?
		JNZ	L_S70
		MOV	AX,0E07H
		INT	10H
		MOV	AX,4C01H
		INT	21H
L_S70:
		MOV	AX,CS
		CMP	AX,0A000H		;��LH?
		JA	L_S90
		CMP	D_RAM,'N'               ;פ�������ڴ�
		JZ	L_S90
		CALL	S_GETUMB		;����UMB��
		JZ	L_S100
L_S90:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;�廷����
		INT	21H
		CALL	S_SETINT
		JMP	L_S120
L_S100:
		MOV	AX,D_UMB
		OR	AX,AX
		JZ	L_S90
		DEC	AX
		MOV	ES,AX
		MOV	DI,8
		MOV	SI,OFFSET D_NAME
		MOVSW				;��UMB�ļ����ƿ�д�뱾ģ����
		MOVSW

		MOV	ES,D_UMB		;��
		XOR	SI,SI
		MOV	DI,SI
		MOV	CX,D_LEN0
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
L_S120:
		MOV	DX,D_LEN		;��ģ�鳤��(��)
		MOV	AX,3100H		;פ��
		INT	21H

D_XMS		DD	0			;XMS������ַ
D_NCFP		DW	0			;ԭ�ڴ�������
D_UMB0		DW	0			;ԭUMB����״̬
D_UMB		DW	0			;����UMB��
D_LEN		DW	0			;��ģ�鳤��(��)
D_LEN0		DW	0			;פ��ģ�鳤��
D_RAM		DB	0			;='N':פ�������ڴ�

;�ӳ���:ȡUMB��
S_GETUMB	PROC	NEAR
		CALL	S_GETXMS		;ȡXMS������ַ
		JNZ	L_GU2

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
		MOV	DX,OFFSET INT_8
		MOV	AX,2508H		;���ж�INT8		3.26
		INT	21H
		MOV	DX,OFFSET INT_10
		MOV	AX,2510H		;���ж�INT10
		INT	21H
		MOV	DX,OFFSET INT_1D
		MOV	AX,251DH		;���ж�INT1D
		INT	21H

		MOV	ES,D_INT16		;			2.24
		MOV	AX,3			;������ʾ��ʽ
		MOV	DL,1
		TEST	BYTE PTR DS:[0F5H],1	;=1:����ֱ��д��?
		JNZ	L_SI1
		MOV	AL,9
		MOV	DL,0
L_SI1:
		INT	10H
		MOV	ES:[102H],DL

		TEST	BYTE PTR DS:[0F4H],8	;����ʾ�汾��Ϣ?	10.22
		JNZ	L_SI5
		MOV	BL,70H
		MOV	AH,25H
		INT	16H
L_SI5:
		RET
S_SETINT	ENDP

D_NAME		DB	'HGA',0
MSG		DB	'HGA.COM HGA��ʾģ�� 1998.8.9',13,10
		DB	'�����и�ʽ:VGA [/G][/H][/K][/L][/N][/P][/X][/Z]',13,10
		DB	'    ����:/G:�̶����2��',13,10
		DB	'         /H:��ʾ��ʽ>5������',13,10
		DB	'         /K:������չ�ַ���',13,10
		DB	'         /L:��װKZZF,��ʾ��BIOS',13,10
		DB	'         /N:פ�������ڴ�',13,10
		DB	'         /P:�����жϵ�BIOS',13,10
		DB	'         /X:����ʾ�汾��Ϣ',13,10
		DB	'         /Z:��ʹ��ֱ��д��',13,10,'$'

SEG_A		ENDS
		END	START

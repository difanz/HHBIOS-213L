;	CGA.ASM
;	1995.10.7, 12.21
;	1996.1.4, 2.10, 10.4
;	1997.2.20, 7.7

SEG_A		SEGMENT PARA PUBLIC
		ASSUME CS:SEG_A , DS:SEG_A

		ORG	100H
START:		JMP	BEGIN
IN_INT10	DB	0
	;[0F4H]TEST-1:��װKZZF,-2:������ʾ��,-8:����ʾ��ʾ��Ϣ
	;[0F5H]TEST-1:ֱ��д��,-2:ͼ�η�ʽ��B8,-4:��ʾ�жϵ�BIOS,-8:�������
	;[0F6H]TEST-1:ԭ�з�ʽ,-2:�̶����,-4:��ʼ���Ĵ���,-8:AH=0B��BIOS
	;[0F7H]='1'~'9':��ʾ�й��ɫ,����:�ر���Ļ�ָ�
	;[100H] ��������ʾ��ʽ		=0����,=1����
	;[101H] ��꿪��		λ0=0��,=1�й��
	;[102H] ��ǰ���״̬		=0�޹��,=0FFH��
D_INT10 	DD	0			;ԭINT10
D_INT16 	DW	0			;����ģ���
		INCLUDE ZF80.INC
D_0050		DB	0			;ǰ�ֽ�
D_0051		DB	0			;ǰ�ֽ�����
D_0052		DW	0			;ǰ�ֽ�λ��
D_0058		DB	0			;��ʾ����λ��
D_0059		DB	0			;��ǰ��ʾ�к�,��(=0)
D_005B		DB	16H			;��ʾ�и����к�
D_005E		DW	2			;�����ʼ/������
D_0060		DB	0			;=0���Ը�λ����,��0���
D_0062		DB	0			;��ʾ�к���ǰ�ֽ�
D_0064		DB	6			;������ʾ��ʽ
D_0068		DW	0			;������λ��
D_0069		DB	1			;=0����,��0����

D_AH		DW	OFFSET L_AH00		;AH=0
D_AH01		DW	OFFSET L_AH01		;AH=1
		DW	OFFSET L_AH02		;AH=2
		DW	OFFSET L_INT10		;AH=3
		DW	OFFSET L_INT10		;AH=4
		DW	OFFSET L_INT10		;AH=5
		DW	OFFSET L_AH06		;AH=6
		DW	OFFSET L_AH07		;AH=7
		DW	OFFSET L_AH08		;AH=8
		DW	OFFSET L_AH09		;AH=9
		DW	OFFSET L_AH09		;AH=0AH
		DW	OFFSET L_INT10		;AH=0BH
		DW	OFFSET L_AH0C		;AH=0CH
		DW	OFFSET L_AH0D		;AH=0DH
		DW	OFFSET L_AH0E		;AH=0EH
		DW	OFFSET L_INT10		;AH=0FH
D_AH10		DW	OFFSET L_INT10		;AH=10H
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
		MOV	AX,43H			;CGA:'C'
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

;AH=0 ������ʾ��ʽ
L_AH00:
		MOV	BX,AX
		MOV	ES,CS:D_INT16		;����ģ���

		AND	AL,7FH
		CMP	AL,6
D_6	EQU	$
		JZ	L_0010
		MOV	ES:[101H],AL		;ʵ����ʾ��ʽ
		MOV	CS:[100H],AH   ;���ķ�ʽ
		MOV	AX,BX
		JMP	L_INT10
L_0010:
		MOV	AL,6
		MOV	ES:[101H],AL
		MOV	AX,BX
		PUSHF
		CALL	CS:D_INT10		;��ԭINT10
		MOV	AH,0BH
		MOV	BX,102H
		PUSHF
		CALL	CS:D_INT10

		PUSH	CS
		POP	ES			;CS��ES
		MOV	DI,OFFSET D_XPQ 	;��������ַ
		MOV	AX,720H
		MOV	CX,25*80
		REP	STOSW			;��������

		MOV	AL,CS:D_0064
		MOV	DS:[449H],AL
		MOV	CS:D_0059,0		;����ʾ��
		MOV	WORD PTR CS:[100H],101H ;�򿪹��
		MOV	BYTE PTR CS:[102H],0	;�޹��(��ʼ״̬)
		MOV	WORD PTR DS:[460H],607H ;����С

		XOR	DX,DX
		MOV	CS:D_0068,DX
		CALL	S_XSGB			;��ʾ���
		JMP	L_RET

;AH=1 ���ù���С CH=��ʼɨ����,CL=��ֹ��
L_AH01:
		CLI
		OR	CX,CX
		JZ	L_0103
		CALL	S_QGB			;����
		PUSH	CX
		AND	CX,1F1FH
		CMP	CL,CH
		JNB	L_0101
		MOV	CH,CL
L_0101:
		SUB	CL,CH
		INC	CX
		CMP	CL,7
		JB	L_0102
		MOV	CL,7
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
		JMP	L_INT10

;AH=2 ���ù��λ��
L_AH02:
		CMP	CS:D_0059,0		;��������ʾ��?
		JZ	L_0201
		CMP	DH,CS:D_0059		;��λ���Ƿ���ʾ��?
		JNZ	L_0201
		MOV	AX,1404H		;�ر���ʾ��
		INT	10H
L_0201:
		MOV	DS:[450H],DX
		CALL	S_GB
		MOV	AH,2
		JMP	L_INT10

;AH=6 �Ϲ�
L_AH06:
		CALL	S_QGB			 ;�ع��
		CMP	CS:D_0059,0		;��������ʾ��?
		JZ	L_0603
		PUSH	AX
		MOV	AX,1404H
		INT	10H			;�ر���ʾ��
		POP	AX
L_0603:
		CALL	S_GDHS			;�й�������
		MOV	AX,CX			;���Ͻ�
		CALL	S_GDFW			;������Χ,CS��DS
		ADD	SI,AX
		MOV	BP,80*2

		OR	BL,BL
		JNZ	L_0604
		MOV	BL,DH
		JMP	SHORT L_0606
L_0604:
		MOV	AH,DH
		SUB	AH,BL
L_0605:
		CALL	S_XPGD			;�����Ϲ�һ��
		ADD	SI,BP			;ָ����һ��
		ADD	DI,BP
		DEC	AH
		JNZ	L_0605
L_0606:
		MOV	AH,BH			;�ָ������������
		OR	AH,AH
		JNZ	L_0607
		MOV	AH,7
L_0607:
		SHR	BH,1			;ʵ�ʵĿ����������
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
L_0608:
		CALL	S_KHTC			;�������
		ADD	DI,BP			;ָ����һ��
		DEC	BL
		JNZ	L_0608
		POP	AX			;�ָ���������
		POP	BX
		POP	CX
		POP	DX
		PUSH	DX
		PUSH	CX
		PUSH	BX
		PUSH	AX
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
		XOR	DI,DI
		MOV	DS,DI
		MOV	BYTE PTR DS:[449H],6
		PUSHF
		CALL	CS:D_INT10		;��ԭINT10�Ϲ�
		MOV	AL,CS:D_0064
		MOV	DS:[449H],AL
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
		ADD	DX,101H 		;������

		PUSH	CS
		POP	DS			;CS��DS
		PUSH	CS
		POP	ES			;CS��ES

		MOV	CL,AL
		MOV	AL,80
		MUL	AH			;�к�
		XOR	CH,CH
		ADD	AX,CX
		SHL	AX,1
		ADD	AX,OFFSET D_XPQ 	;��������ַ
		MOV	DI,AX
		MOV	SI,AX

		MOV	AL,80
		MUL	BL			;������
		SHL	AX,1

		XOR	CH,CH
		RET
S_GDFW		ENDP

;�ӳ���:��������һ��
S_XPGD		PROC	NEAR
		MOV	CL,DL
		PUSH	SI
		PUSH	DI
		REP	MOVSW
		POP	DI
		POP	SI
		RET
S_XPGD		ENDP

;�ӳ���:�������
S_KHTC		PROC	NEAR
		MOV	AL,' '
		MOV	CL,DL
		PUSH	DI
		REP	STOSW
		POP	DI
		RET
S_KHTC		ENDP

;AH=7 �¹�
L_AH07:
		CALL	S_QGB			;�ع��
		CMP	CS:D_0059,0		;��������ʾ��
		JZ	L_0703
		PUSH	AX
		MOV	AX,1404H
		INT	10H			;�ر���ʾ��
		POP	AX
L_0703:
		STD
		CALL	S_GDHS			;�й�������
		MOV	AX,DX			;���½�
		CALL	S_GDFW			;������Χ,CS��DS
		SUB	SI,AX
		MOV	BP,0A0H

		OR	BL,BL
		JNZ	L_0704
		MOV	BL,DH
		JMP	SHORT L_0706
L_0704:
		MOV	AH,DH
		SUB	AH,BL
L_0705:
		CALL	S_XPGD			;�����¹�һ��
		SUB	SI,BP			;ָ����һ��
		SUB	DI,BP
		DEC	AH
		JNZ	L_0705
L_0706:
		MOV	AH,BH			;�ָ������������
		OR	AH,AH
		JNZ	L_0707
		MOV	AH,7
L_0707:
		SHR	BH,1			;ʵ�ʵĿ����������
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
L_0708:
		CALL	S_KHTC			;�������
		SUB	DI,BP			;ָ����һ��
		DEC	BL
		JNZ	L_0708

		POP	AX			;�ָ���������
		POP	BX
		POP	CX
		POP	DX
		PUSH	DX
		PUSH	CX
		PUSH	BX
		PUSH	AX
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
		SHR	BH,1
		XOR	DI,DI
		MOV	DS,DI
		MOV	BYTE PTR DS:[449H],6
		PUSHF
		CALL	CS:D_INT10		;��ԭINT10�¹�
		MOV	AL,CS:D_0064
		MOV	DS:[449H],AL
		CLD
		JMP	L_RET

;AH=8 ����ǰ���λ���ַ�������
L_AH08: 	CALL	S_XPDZ			;���㵱ǰ�������������ַ��SI
		MOV	AX,CS:[SI]		;ȡ���ַ�������
		POP	BX
		JMP	L_RET1

;�ӳ���:���㵱ǰ�������������ַ��SI
S_XPDZ		PROC	NEAR
		PUSH	AX
		PUSH	BX
		MOV	AX,DS:[450H]		;ȡ��ǰҳ���λ��
		MOV	DX,AX
		MOV	BL,AL			;����
		MOV	AL,80			;ÿ���ַ���
		MUL	AH			;������
		XOR	BH,BH
		ADD	AX,BX			;����
		SHL	AX,1			;��2
		ADD	AX,OFFSET D_XPQ
		MOV	SI,AX
		POP	BX
		POP	AX
		RET
S_XPDZ		ENDP

;AH=9,0AH д��ǰ���λ���ַ�������
L_AH09:
		OR	CX,CX			;�ַ�����=0?
		JZ	L_0908
		CALL	S_QGB			;�ع��

		CALL	S_XPDZ			;���㵱ǰ�������������ַ��SI
		PUSH	CX
L_0904:
		MOV	CS:[SI],AL		;д���ַ�����
		CMP	AH,0AH
		JZ	L_0905
		MOV	CS:[SI+1],BL
L_0905:
		ADD	SI,2
		LOOP	L_0904
		POP	CX

		CMP	AH,0AH
		JNZ	L_0906
		MOV	BL,CS:[SI-1]
L_0906:
		XOR	BP,BP
		CMP	CS:D_0060,1
		JNZ	L_0907
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
K_HZ		EQU	$-2
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
		JMP	SHORT L_XS0
L_XS1:
		OR	DL,DL
		JZ	L_XS0
		DEC	DX			;���һλ
		CMP	DX,CS:D_0052
		JNZ	L_XS2
		MOV	AH,CS:D_0050		;ȡǰ�ֽ�
		MOV	BH,CS:D_0051
	 ;�ӳ���:��ʾ����
S_XSHZ:
		PUSH	DX
		CALL	S_ZMZH
		POP	DX
		PUSH	CS
		POP	ES
		MOV	DI,80H
		MOV	CH,2			;������
L_HZ1:
		MOV	CL,8
L_HZ2:
		LODSW				;ȡһ��
		OR	AL,AH			;����һ�ֽ�
		STOSB				;д
		DEC	CL
		JNZ	L_HZ2
		DEC	CH
		JNZ	L_HZ1

		CALL	S_SPDZ			;������DX��ʵ������ַ��DI
		MOV	SI,80H			;��ģ�ӹ����׵�ַ
		PUSH	BX
		MOV	BL,BH
		CALL	S_ZMXS			;��ģ����ʾ������
		ADD	DI,CS:D_K		;ָ���Ұ���
		POP	BX
		CALL	S_ZMXS			;��ģ����ʾ������
		MOV	CS:D_0050,0		;��ǰ�ֽ�
		RET

	;�ӳ���:��ʾ�ַ�AL DX=���λ��,CX=����,BL=����
S_XSZF:
		OR	CX,CX
		JZ	L_ZF5
L_XSZF:
		CALL	S_ZFZH
		CALL	S_SPDZ			;������DX��ʵ������ַ��DI
L_ZF1:
		PUSH	SI
		PUSH	DX
		CALL	S_ZMXS			;��ʾ�ַ�
		POP	DX
		POP	SI
		INC	DL
		CMP	DL,80
		JB	L_ZF2
		XOR	DL,DL
		CMP	DH,18H
		JZ	L_ZF2
		INC	DH
L_ZF2:
		CALL	S_SPDZ
		LOOP	L_ZF1
L_ZF5:
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
		TEST	BL,70H			;����?
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
		TEST	BL,70H			;����?
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
		ADD	DI,80
		LOOP	L_ZM1
		POP	DX
		POP	CX
		POP	DI
		RET
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
		MOV	DX,80*4 		;ÿ�ַ���ռʵ�����ֽ���
		MUL	DX			;���׵�ַ
		XOR	BH,BH
		ADD	AX,BX
		MOV	DI,AX			;ʵ������ַ
		MOV	AX,0B800H
		MOV	ES,AX			;��ʾ��������
		POP	BX
		POP	DX
		POP	AX
		RET
S_SPDZ		ENDP

	INCLUDE GB.INC

S_XSGB		PROC	NEAR
		NOT	BYTE PTR CS:[102H]	;״̬��
S_XSGB0:
		MOV	CX,CS:D_005E		;����С
		OR	CX,CX
		JZ	L_GB5
S_XSGB1:
		CMP	DL,4FH
		JBE	L_GB3
		RET
L_GB3:
		PUSH	ES
		CALL	S_SPDZ

		ADD	DI,80*3
L_GB4:
		NOT	BYTE PTR ES:[DI+2000H]
		DEC	CX
		JZ	L_GB5
		NOT	BYTE PTR ES:[DI]
		SUB	DI,80
		DEC	CX
		JNZ	L_GB4
L_GB5:
		POP	ES
		RET
S_XSGB		ENDP

;AH=0CH ��ʾ��
L_AH0C: 	MOV	BYTE PTR DS:[449H],6
		PUSHF
		CALL	CS:D_INT10
		MOV	AL,CS:D_0064
		MOV	DS:[449H],AL
		JMP	L_RET

;AH=0DH ������
L_AH0D: 	MOV	BYTE PTR DS:[449H],6
		PUSHF
		CALL	CS:D_INT10
		MOV	BH,CS:D_0064
		MOV	DS:[449H],BH
		POP	BP
		JMP	L_RET1

	INCLUDE AH0E.INC
	INCLUDE AH13.INC

;AH=14H ��ʾ�й���
;	AL=0 ����ʾ��
;	AL=1 ��ʾ�ַ�DL CL=����
;	AL=2 ��ʾ�й�궨λDL
;	AL=3 ��ʾ�ַ�DL���ƽ����
;	AL=4 �ر���ʾ��
;	AL=5 ������ʾ�и���λ��BH
;	AL=6 ȡ��ʾ���� AL=��ʾ��ʽ AH=���ɫ��
;			BL=��ʾ����ɫ BH=����λ��
;			CL=��ʾ����,CH=ÿ��ɨ������
;			DL=��ʾ�й��λ�� DH=��ǰ��ʾ��λ��
;			SI=������� DI=����ɨ������
;	AL=7 ���ö�����ʾ��ʽBH
;	AL=8 λ��DX���ַ�������ʾ
;	AL=9 ��ָ��λ��DX��ʾ�ַ�BH
;	AL=10 ��ָ��λ��DL��ʾBL����BP:SI���ĵ���64�ֽ�
;	AL=12 ȡ��������ַ BX:AX
;	AL=15 ��ָ��λ��DX��ʾ�ӿ��ַ���DS:SI(����BL)
L_AH14:
		OR	AL,AL			;����ʾ��
		JNZ	L_1410
L_1400:
		MOV	CS:D_0058,AL		;��ʾ�ж�λ�����
		MOV	CS:D_0062,AL
		CMP	CS:D_0059,AL		;��ʾ���Ѵ�?
		JNZ	L_1405
		MOV	DH,18H			;			10.4
		CMP	DH,DS:[451H]		;����ڵ�25��?
		JA	L_1401
		MOV	DH,CS:D_005B
L_1401:
		MOV	CS:D_0059,DH		;����ʾ��λ��
		XOR	DL,DL
		CALL	S_SPDZ			;������DX��ʵ������ַ��DI

		MOV	SI,DI
		MOV	DI,OFFSET D_TSBC	;��ʾ�б�����
		MOV	CX,80*4
L_1404:
		MOV	AL,ES:[SI]		;���汻��ʾ�и��ǵ�����
		MOV	AH,ES:[SI+2000H]
		MOV	CS:[DI],AX
		INC	SI
		ADD	DI,2
		LOOP	L_1404
L_1405:
		MOV	DL,' '
		MOV	CX,80			;����ʾ��
		MOV	BL,7
L_1407:
		CALL	S_TXZF
L_1408:
		JMP	L_RET
L_1410:
		CMP	AL,1			;д�ַ�DL
		JNZ	L_1420
		OR	CX,CX
		JZ	L_1408
		CALL	S_DKTX
		JMP	SHORT L_1407
L_1420:
		CMP	AL,2			;��궨λ
		JNZ	L_1430
		CALL	S_DKTX
		CALL	S_TXGB
		CMP	DL,79
		JA	L_1423
		MOV	CS:D_0058,DL
L_1422:
		CALL	S_TXGB
L_1423:
		JMP	L_RET
L_1430:
		CMP	AL,3			;TTYд�ַ�
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
		MOV	CS:D_0058,AL		;����λ��
L_1432:
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
		INC	AX
		MOV	CS:D_0058,AL		;����λ��
		JMP	SHORT L_1422
L_1440:
		CMP	AL,4			;�ر���ʾ��
		JNZ	L_1450
		MOV	DH,CS:D_0059		;��ʾ��λ��
		OR	DH,DH
		JZ	L_1442
		XOR	DL,DL
		MOV	CS:D_0059,DL		;����ʾ��
		CALL	S_SPDZ			;������DX��ʵ������ַ��DI
		MOV	SI,OFFSET D_XPQ+25*80*2 ;��ʾ�б�����
		MOV	CX,80*4
L_1441:
		MOV	AX,CS:[SI]		;�ָ�����ʾ�и��ǵ�����
		MOV	ES:[DI],AL
		MOV	ES:[DI+2000H],AH
		ADD	SI,2
		INC	DI
		LOOP	L_1441
L_1442:
		JMP	L_RET
L_1450:
		CMP	AL,5			;������ʾ�и���λ��
		JNZ	L_1460
		MOV	CS:D_005B,BH
		JMP	L_RET
L_1460:
		CMP	AL,6			;ȡ��ʾ����
		JNZ	L_1470
		MOV	AX,106H 		;ȡ��ʾ��ʽ�����ɫ��
		MOV	BH,CS:D_005B   ;ȡ��ʾ����ɫ�͸���λ��
		XOR	BL,BL
		MOV	CX,819H 		;ȡÿ��ɨ����������ʾ����
		MOV	DH,CS:D_0059
		MOV	DL,0
		MOV	SI,639			;�������
		MOV	DI,199			;����ɨ������
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
		CMP	AL,7			;���ö�����ʾ��ʽ
		JNZ	L_1480
		MOV	CS:D_0064,BH
		MOV	DS:[449H],BH
		JMP	L_RET
L_1480:
		CMP	AL,8			;<λ��DX���ַ�����>
		JNZ	L_1490
		MOV	CX,8
		CALL	S_XSGB1
		JMP	L_RET
L_1490:
		CMP	AL,9			;<��ָ��λ��DX��ʾ�ַ�BH>
K_1490	EQU	$
		JNZ	L_14A0
		MOV	AL,BH
		XOR	BP,BP
		OR	CX,CX			; *5.21*
		JZ	L_1491
		MOV	CX,1
		CALL	S_XS
		JMP	L_RET
L_1491:
		INC	CX			; *5.21*
		CALL	S_XSZF
		JMP	L_RET
L_14A0:
		CMP	AL,10			;��ʾ2.13��־
		JNZ	L_14C0
		MOV	BX,4E4EH
		MOV	DL,4BH
		MOV	DH,CS:D_0059		;			10.4
		MOV	AX,0AFA1H
		CALL	S_XSHZ
		MOV	DL,4DH
		MOV	AX,0AFA2H
		CALL	S_XSHZ
L_14A9:
		JMP	L_RET
L_14C0:
		CMP	AL,12			;<ȡ��������ַBX:AX>
		JNZ	L_14F0
		MOV	AX,OFFSET D_XPQ
		PUSH	CS
		POP	BX
		POP	CX
		POP	CX
		JMP	L_RET3
L_14F0:
		CMP	AL,15			;<��ָ��λ��DX��ʾ�ӿ��ַ���ES:SI,��0��β>
		JNZ	L_14A9
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
		CALL	S_XSGB
		POP	DX
		POP	BX
		RET
S_TXGB		ENDP

;�ӳ���:����ʾ��д�ַ�
S_TXZF		PROC	NEAR
		XOR	BP,BP
		MOV	AL,DL			;�ַ�
		MOV	DX,WORD PTR CS:D_0058	;λ��
		CMP	BL,10H
		JB	L_TX0
		CMP	BL,20H
		JNB	L_TX1A
		AND	BL,0FH
		JMP	SHORT L_TX0
L_TX1A:
		MOV	BL,70H
L_TX0:
		CMP	CS:D_0062,0		;�к���ǰ�ֽ�?
		JNZ	L_TX2
		CMP	AL,0A0H 		;�к���?
		JBE	L_TX1
		MOV	CS:D_0062,AL		;�溺��ǰ�ֽ�
		MOV	CS:D_0051,BL		;��ǰ�ֽ�����
L_TX1:
		JMP	S_XSZF			;��ʾ�ַ�
L_TX2:
		CMP	AL,0A0H
		JBE	L_TX3
		MOV	AH,CS:D_0062		;ȡǰ�ֽ�
		MOV	BH,CS:D_0051
		DEC	DX
		MOV	CS:D_0062,0		;��ǰ�ֽ�
		JMP	S_XSHZ			;��ʾ����
L_TX3:
		MOV	CS:D_0062,0		;��ǰ�ֽ�
		JMP	SHORT L_TX1
S_TXZF		ENDP

;�ӳ���:���ֿⲢת�� AX=�������� ��DS:60H
S_ZMZH		PROC	NEAR
		MOV	DX,AX
S_ZMZH1:
		MOV	AH,CS:D_0069
		INT	7FH			;���ֿⲢת��
		MOV	DS,DX			;��ģ��
		XOR	SI,SI			;    ƫ��
		MOV	DI,60H			;ת����ַ
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

;�ӳ���:���ַ��� AL=ASC�� ��DS:SI		;1.14
S_ZFZH		PROC	NEAR
		CMP	AL,80H
		JB	L_ZFZH1
		SUB	AL,80H			;��Ϊ0~7FH
		MOV	SI,OFFSET D_ZF80	;����չASCII�ַ�����
		PUSH	CS
		POP	DS
		JMP	SHORT L_ZFZH2
L_ZFZH1:
		MOV	SI,0F000H
		MOV	DS,SI			;ROM-BIOS��
		MOV	SI,0FA6EH		;ROM-BIOS�ַ�����ַ
L_ZFZH2:
		MOV	AH,8			;ÿ�ַ�8�ֽ�
		MUL	AH
		ADD	SI,AX
		RET
S_ZFZH		ENDP

;AH=16H ȡ���ֻ��ַ���ģ
L_AH16: 	OR	DH,DH			;�к���?
		JZ	L_1601
		CALL	S_ZMZH1 		;���ֿⲢת��
		MOV	ES,BP			;Ŀ���
		MOV	DI,BX			;    ƫ��
		MOV	CX,16			;����10H����
		REP	MOVSW
		JMP	L_RET
L_1601:
		MOV	DL,AL
		CALL	S_ZFZH
		MOV	DI,BX			;Ŀ��ƫ��
		MOV	ES,BP			;    ��
		MOV	CX,8
L_1602: 	LODSB
		STOSB
		STOSB
		LOOP	L_1602
		JMP	L_RET

;AH=17H ������
L_AH17:
		OR	AL,AL
		JZ	L_1701
		MOV	BYTE PTR CS:[101H],1	;�����
L_AH15:
		CALL	S_GB
		JMP	L_RET
L_1701:
		CALL	S_QGB
		MOV	CS:[101H],AL		;���꿪��
		JMP	L_RET

;AH=18H AL=0��ʶ����		AL=1ʶ����
;	AL=2���Ը�λ����	AL=3���
;	AL=4������������ʾ��ʽ	AL=5����
;	AL=8���������õ�ɫ��	AL=9�������õ�ɫ��
;	AL=13����С���� BH=1��AH=1����*;BH=0,BL=����С
;	AL=14��ʾ��ʽ>=6Ϊ����	AL=15�ָ�ԭ��ʽ*
;	AL=17����		AL=18����*
;	AL=19������Ļ
;	AL=20�ر�ʱ����ʾ*	AL=21�ָ�ʱ����ʾ
;	AL=23��������
L_AH18:
		OR	AL,AL			;<��ʶ����>
		JNZ	L_1801
		MOV	AL,74H			;JZ
L_1800A:
		MOV	BYTE PTR CS:K_HZ,AL
		JMP	L_RET
L_1801:
		CMP	AL,1			;<ʶ����>
		JNZ	L_1802
		MOV	AL,0EBH 		;JMP SHORT
		JMP	SHORT L_1800A
L_1802:
		CMP	AL,2			;<���Ը�λ����>
		JNZ	L_1803
L_1802A:
		SUB	AL,2
		MOV	CS:D_0060,AL
		JMP	L_RET
L_1803:
		CMP	AL,3			;<��λ���>
		JZ	L_1802A

		CMP	AL,4			;<������������ʾ��ʽ>
		JNZ	L_1805
		MOV	CS:D_AH,OFFSET L_RET
		JMP	L_RET
L_1805:
		CMP	AL,5			;<����������ʾ��ʽ>
		JNZ	L_1808
		MOV	CS:D_AH,OFFSET L_AH00
		JMP	L_RET
L_1808:
		CMP	AL,8			;<���������õ�ɫ��>
		JNZ	L_1809
		MOV	AX,OFFSET L_RET
L_1808A:	MOV	CS:D_AH10,AX
		JMP	L_RET
L_1809:
		CMP	AL,9			;<�������õ�ɫ��>
		JNZ	L_1813
		MOV	AX,OFFSET L_INT10
		JMP	SHORT L_1808A
L_1813:
		CMP	AL,13			;<����С����>
		JNZ	L_1814
		OR	BH,BH
		JZ	L_1813A
		MOV	CS:D_AH01,OFFSET L_AH01
		JMP	L_RET
L_1813A:
		MOV	CS:D_AH01,OFFSET L_RET
		MOV	CS:D_005E,BX
		JMP	L_RET
L_1814:
		CMP	AL,14			;<��ʾ��ʽ>=6Ϊ����>
		JNZ	L_1815
		MOV	AX,673H 		;JAE
L_1814A:
		MOV	BYTE PTR CS:D_6,AH
		MOV	BYTE PTR CS:D_6+1,AL
		JMP	L_RET
L_1815:
		CMP	AL,15			;<�ָ�ԭ��ʽ>
		JNZ	L_1817
		MOV	AX,1274H		;JZ
		JMP	SHORT L_1814A
L_1817:
		CMP	AL,17			;<����>
		JNZ	L_1818
L_1817A:
		SUB	AL,17
		MOV	CS:D_0069,AL
		JMP	L_RET
L_1818:
		CMP	AL,18			;<����>
		JZ	L_1817A

		CMP	AL,19			;<������Ļ>
		JNZ	L_1820
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
		JMP	L_RET
L_1820:
		CMP	AL,20			;<�ر�ʱ����ʾ>
		JNZ	L_1821
		MOV	AL,0EBH 		;JMP
L_1820A:
		MOV	BYTE PTR CS:K_1490,AL
		JMP	L_RET
L_1821:
		CMP	AL,21			;<�ָ�ʱ����ʾ>
		JNZ	L_1823
		MOV	AL,75H			;JNZ
		JMP	SHORT L_1820A
L_1823:
		CMP	AL,23			;<��������>
		JNZ	L_1823A
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_XPQ
		MOV	CX,25*80
		XOR	AX,AX
		REP	STOSW
L_1823A:
		JMP	L_RET

D_XPQ		DB	25*80*2 DUP(0)		;������
D_TSBC		DB	80*8 DUP(0)
;****************************************************************************
;����ִ�п�ʼ
BEGIN:
		MOV	AX,3510H
		INT	21H			;ȡԭINT10��ַ
		MOV	WORD PTR D_INT10,BX	;����
		MOV	WORD PTR D_INT10+2,ES

		XOR	BP,BP
		MOV	AH,2FH			;ȡ�����ж�
		INT	16H
		OR	BP,BP			;���м���ģ��?
		JNZ	L_S10
		MOV	BP,CS
L_S10:
		MOV	D_INT16,BP		;����
		MOV	ES,BP
		MOV	BYTE PTR ES:[100H],6

		MOV	AX,CS			;10.22
		CMP	AX,BP
		JB	L_S21
		MOV	AX,ES:[0F4H]		;��ʾ����
		MOV	DS:[0F4H],AX		;��
		MOV	AX,ES:[0F6H]
		MOV	DS:[0F6H],AX
		PUSH	CS
		POP	ES
		JMP	SHORT L_S22
L_S21:
		MOV	BYTE PTR DS:[0F4H],8	;����ʾ�汾��Ϣ
		MOV	BYTE PTR DS:[0F5H],0	;������ֱ��д��
		MOV	BYTE PTR DS:[0F6H],1	;ԭ�з�ʽ
		MOV	BYTE PTR DS:[0F7H],'9'  ;��ʾ�й��ɫ
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
		CMP	AL,'X'                  ;<����ʾ�汾��Ϣ>
		JNZ	L_S34
		OR	BYTE PTR ES:[0F4H],8
		JMP	L_S30
L_S34:
		CMP	AL,'H'                  ;<��ʾ��ʽ>5��Ϊ����>
		JNZ	L_S39
		MOV	BYTE PTR DS:D_6,6
		MOV	BYTE PTR DS:D_6+1,73H
		AND	BYTE PTR ES:[0F6H],0FEH
		JMP	L_S30
L_S39:
		CMP	AL,'G'                  ;<�̶����>
		JNZ	L_S40
		MOV	D_AH01,OFFSET L_RET
		OR	BYTE PTR ES:[0F6H],2
		JMP	L_S30
L_S40:
		CMP	AL,'N'                  ;<פ�������ڴ�>
		JNZ	L_S50
		MOV	D_RAM,AL
L_S50:
		JMP	L_S30
L_S60:
		MOV	AX,OFFSET BEGIN
		MOV	CL,4
		SHR	AX,CL
		INC	AX			;פ������(��)
		MOV	D_LEN,AX

		MOV	AH,-1			;ȡ��װģ��?
		INT	10H
		CMP	AX,43H			;CGA
		JNZ	L_S8
		MOV	AX,0E07H
		INT	10H
		INT	20H
L_S8:
		MOV	AX,CS
		CMP	AX,0A000H		;��LH?
		JA	L_S90
		CMP	D_RAM,'N'                  ;/N:פ�������ڴ�
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
		MOV	CX,OFFSET BEGIN
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
		MOV	DX,OFFSET INT_10
		MOV	AX,2510H
		INT	21H			;���ж�INT10
		MOV	AX,6
		INT	10H			;������ʾ��ʽ

		TEST	BYTE PTR DS:[0F4H],8	;����ʾ�汾��Ϣ?
		JNZ	L_SI2
		MOV	BL,7
		MOV	AH,25H			;��ʾ�汾��Ϣ
		INT	16H
L_SI2:
		RET
S_SETINT	ENDP

D_NAME		DB	'CGA',0
MSG		DB	'CGA.COM CGA��ʾģ�� 1997.7.7',13,10
		DB	'�����и�ʽ:VGA [/X][/H][/G][/N]',13,10
		DB	'    ����:/X:����ʾ�汾��Ϣ,/H:��ʾ��ʽ>5������',13,10
		DB	'         /G:�̶����,      /N:פ�������ڴ�',13,10,'$'

SEG_A		ENDS
		END	START

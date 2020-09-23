;	README.ASM
;	1995.9.20, 9.28, 10.18, 10.26, 12.23
;	1996.1.3

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

C_B		DB	9EH		;ǿ����Ϣ��ɫ
C_A		DB	1EH		;�����ı���ɫ
C_D		DB	4AH		;Ŀ¼��Ϣ��ɫ
C_1		DB	6FH		;������ɫ
C_DH		DB	70H		;���к�����ɫ
C_DZ		DB	74H		;    �ַ���ɫ
D_CX		DW	1		;=1:����ʾ����,=0:���ַ���ʾ

D_L		DW	0		;��ǰ��
D_SI		DW	0		;��ǰҳ���к�
D_STAS		DW	0		;�ļ��׶�
D_END		DW	0		;�ļ�β��ַ
D_ENDS		DW	0		;      ��
D_TAB		DW	0		;Ŀ¼����ǰ�е�ַ
D_LM		DW	0		;����к�
D_DM		DW	0		;Ŀ¼��β��ַ
D_DH		DB	0		;=0��,=-1�� Ŀ¼

D_MODE		DB	0		;��ʾ��ʽ
D_MSG		DB	' F1-���� TAB-���ƻ򷵻�Ŀ¼ Shift+TAB-����Ŀ¼ CR-��ת���� ESC-�˳� F10-���ô���',0
D_MSG1		DB	' F2-�ı�ǰ�� F3-���� F4-Ŀ¼ǰ�� F5-���� F6-ǿ��ǰ�� F7-���� F8-����ǰ�� F9-����',0
D_TUX		DB	0		;��ǰ��ʾ��:0-MSG,-1-MSG1

D_HELP		DB	'ͨ���ı��Ķ����� README.COM ʹ��˵��',0
D_HELP1 	DB	'���ø�ʽ: README [��ʽ�ļ�]',0
		DB	'  ȱʡΪ�뱾����ͬĿ¼������չ�����ļ���',0
		DB	'��ʽ�ļ��ı���ʽ(��ο���ϵͳ��README):',0
		DB	'  !c���-������־  !d���-Ŀ¼��Ϣ',0
		DB	'  !e-����ʾ����    !f-���ַ���ʾ',0
		DB	'  !a�����ı�  !bǿ����Ϣ(�ɼӱ�ǰ����ɫ)',0
		DB	'       ����:����ɫ0-9,ǰ��ɫ0-9,A-F��a-f',0
		DB	'  ���Ϊ�����ַ���һ������(���256��)',0
		DB	'���ܼ�˵��:          <INS>-��ʾ�л�',0
		DB	'  <TAB>-Ŀ¼��������ƻ���ı�����Ŀ¼��',0
		DB	'  <Shift+TAB>-Ŀ¼���������',0
		DB	'  <PgUp>-�Ͼ�һҳ    <PgDn>-�¾�һҳ',0
		DB	'  <HOME>-���ı���ҳ  <END>--���ı�ĩҳ',0
		DB	'��ɫ����:            F10-���ô���',0
		DB	'  F2-�����ı�ǰ��ɫ  F6-ǿ����Ϣǰ��ɫ',0
		DB	'  F3-        ����ɫ  F7-        ����ɫ',0
		DB	'  F4-Ŀ¼��Ϣǰ��ɫ  F8-������Ϣǰ��ɫ',0
		DB	'  F5-        ����ɫ  F9-        ����ɫ',0
		DB	' ��Ȩ����:�����������Թ�˾  1996��1��2��',0,0
D_BP		DW	0			;D_COM���ļ���չ���ָ�����ַ
D_WJM		DB	'�ļ���: ',0
D_YSH		DB	'ҳ���к�:',0
D_LMH		DB	'�ܼ�����:',0
D_HH		DB	'    ',0
NOFILE		DB	'�ļ�δ�ҵ�!',7,13,10,'$'
NODIR		DB	'��������Ϣδ�ҵ�!',7,13,10,'$'
NO213		DB	'NO 2.13 CHINESE SYSTEM!',7,13,10,'$'
;----------------------------------------------------------------------------
BEGIN:
		XOR	BP,BP
		MOV	AX,1406H		;ȡ��ʾģ�����
		INT	10H
		OR	BP,BP			;��2.13?
		JNZ	L_10
		MOV	DX,OFFSET NO213
		JMP	L_ERR
L_10:
		MOV	D_MODE,AL		;��ʾ��ʽ

		MOV	SI,80H
		LODSB
		OR	AL,AL			;�����в���?
		JZ	L_20
		CBW
		MOV	BX,AX
		MOV	[BX+SI],AH		;�ļ���β
L_12:
		LODSB
		CMP	AL,' '
		JBE	L_12
		DEC	SI
		MOV	DX,SI			;ָ���ļ���
		JMP	SHORT L_30		;		12.23
L_20:
		MOV	DS,DS:[2CH]		;������
		XOR	SI,SI
L_21:
		CMP	WORD PTR DS:[SI],0	;�л�����β?
		JZ	L_22
		INC	SI
		JMP	SHORT L_21
L_22:
		LODSW
		LODSW				;SI:README.COMȫ·����
		MOV	DI,OFFSET D_COM
L_23:
		LODSB
		STOSB
		CMP	AL,'.'                  ;��չ���ָ���
		JNZ	L_24
		MOV	BP,DI			;��
		DEC	BP
		JMP	SHORT L_23
L_24:
		OR	AL,AL
		JNZ	L_23

		PUSH	CS
		POP	DS
		MOV	D_BP,BP
		MOV	BYTE PTR DS:[BP],0	;ȥ��չ��
		MOV	DX,OFFSET D_COM
L_30:
		MOV	AX,3D00H		;���ļ�
		INT	21H
		JNB	L_32
		MOV	DX,OFFSET NOFILE
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_32:
		MOV	BX,AX

		MOV	SI,DX			;�ļ������͵�DS:60H
		MOV	DI,60H
L_34:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	L_34

		MOV	BP,DS
		MOV	D_STAS,BP
		ADD	D_STAS,1000H		;�׶�
L_36:
		ADD	BP,1000H		;��һ��
		MOV	DS,BP
		XOR	DX,DX
		MOV	CX,8000H
		MOV	AH,3FH			;���ļ�
		INT	21H
		CMP	AX,CX
		JB	L_38
		MOV	DX,CX
		MOV	AH,3FH			;���ļ�
		INT	21H
		CMP	AX,CX
		JZ	L_36
		ADD	AX,DX
L_38:
		MOV	CS:D_END,AX		;�ļ�β��ַ
		MOV	CS:D_ENDS,BP
		MOV	AH,3EH
		INT	21H

		CALL	S_LINE			;ȡÿ���׵�ַ CS=>DS

		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		CALL	S_CLS			;����
;----------------------------------------------------------------------------
L_90:
		MOV	BP,D_STAS		;�׶�
		XOR	SI,SI
L_92:
		MOV	D_SI,SI 		;ҳ���к�
		MOV	DX,100H 		;��һ����
L_94:
		MOV	SI,D_SI 		;ҳ����
		MOV	DI,D_TAB		;Ŀ¼�е�ַ
		OR	DI,DI			;����Ŀ¼��
		JZ	L_98
		MOV	AX,[DI]
		SUB	AX,SI
		JB	L_96
		CMP	AX,23
		JB	L_98
L_96:
		MOV	D_TAB,0
L_98:
		CALL	S_XS			;��ʾһҳ
L_100:
		XOR	AH,AH			;����.����:DI=ҳ�׵����׵�ַ��
		INT	16H			;	   BP=	  ��
;----------------------------------------------------------------------------
		CMP	AX,4800H		;��
		JNZ	L_110
		CMP	D_SI,0			;ҳ���е��ļ���
		JZ	L_100
		DEC	D_SI			;ҳ����-1
		JMP	L_94			;��ʾ
;----------------------------------------------------------------------------
L_110:
		CMP	AX,5000H		;��
		JNZ	L_120
		MOV	AX,D_LM
		SUB	AX,23
		CMP	D_SI,AX 		;ҳ��<�ļ�β-23��
		JAE	L_100
		INC	D_SI			;ҳ����+1
		JMP	L_94			;��ʾ
;----------------------------------------------------------------------------
L_120:
		CMP	AX,4900H		;PGUP
		JNZ	L_130
		MOV	SI,D_SI
		CMP	SI,23			;=�ļ���?
		JAE	L_121
		XOR	SI,SI
		JMP	SHORT L_122
L_121:
		SUB	SI,23
L_122:
		MOV	D_SI,SI 		;ҳ������
		JMP	L_94
;----------------------------------------------------------------------------
L_130:
		CMP	AX,5100H		;PGDN
		JNZ	L_140
		MOV	SI,D_SI
		MOV	AX,D_LM 		;�ļ�β��
		SUB	AX,23
		CMP	SI,AX			;=�ļ�β��ַ?
		JBE	L_131
		MOV	SI,AX
		JMP	SHORT L_133
L_131:
		SUB	AX,SI
		CMP	AX,23
		JBE	L_132
		MOV	AX,23
L_132:
		ADD	SI,AX			;��һҳ
L_133:
		MOV	D_SI,SI 		;ҳ�׵�ַ
		JMP	L_94
;----------------------------------------------------------------------------
L_140:
		CMP	AX,4700H		;HOME
		JNZ	L_150
		JMP	L_90
;----------------------------------------------------------------------------
L_150:
		CMP	AX,4F00H		;END
		JNZ	L_160
		MOV	SI,D_LM
		SUB	SI,23
		JMP	L_92
;----------------------------------------------------------------------------
L_160:
		CMP	AL,9			;<TAB>
		JNZ	L_170
		CMP	D_TAB,0
		JNZ	L_166
		MOV	SI,D_SI
		MOV	DI,D_DM
		CMP	SI,[DI]
		JA	L_162
		MOV	DI,OFFSET D_DIR 	;Ŀ¼��
L_161:
		CMP	SI,[DI]
		JBE	L_164
		ADD	DI,4
		JMP	SHORT L_161
L_162:
		MOV	DI,OFFSET D_DIR 	;Ŀ¼��
L_163:
		CMP	SI,[DI+2]		;��ǰ��<Ŀ¼�к�
		JBE	L_164
		ADD	DI,4
		CMP	DI,D_DM
		JZ	L_164
		CMP	SI,[DI+2]		;<��һ��?
		JA	L_163
L_164:
		MOV	D_TAB,DI		;��ǰĿ¼�е�ַ

		MOV	SI,[DI] 		;Ŀ¼��
		MOV	AX,D_SI 		;ҳ����
		CMP	SI,AX
		JB	L_165
		ADD	AX,23
		CMP	SI,AX
		JBE	L_173
L_165:
		JMP	L_92			;��ʾ
L_166:
		MOV	DI,D_TAB
		CMP	DI,D_DM 		;��Ŀ¼��β?
		JAE	L_174
		CALL	S_CLSDIR		;��ԭĿ¼
		ADD	DI,4
		MOV	D_TAB,DI
		JMP	SHORT L_171
;----------------------------------------------------------------------------
L_170:
		CMP	AX,0F00H		;SHIFT+TAB
		JNZ	L_180
		CMP	D_TAB,0 		;����Ŀ¼��?
		JZ	L_174
		MOV	DI,D_TAB
		CMP	DI,OFFSET D_DIR 	;��Ŀ¼����
		JZ	L_174
		CALL	S_CLSDIR		;��ԭĿ¼
		SUB	DI,4
		MOV	D_TAB,DI
L_171:
		MOV	AX,D_SI 		;ҳ���к�
		CMP	[DI],AX 		;Ŀ¼��<ҳ��
		JB	L_172
		ADD	AX,23
		CMP	[DI],AX 		;>ҳβ?
		JB	L_173
L_172:
		MOV	SI,[DI]
		JMP	L_92			;��ʾ
L_173:
		CALL	S_SETDIR		;�õ�ǰĿ¼
L_174:
		CALL	S_280			;��ʾ��ʾ��Ϣ
		JMP	L_100
;----------------------------------------------------------------------------
L_180:
		CMP	AX,3B00H		;F1?
		JNZ	L_190
		CALL	S_280			;��ʾ��ʾ��Ϣ
		MOV	DX,212H 		;���Ͻ�λ��
		MOV	CX,152CH		;�ߺͿ�
		MOV	BL,30H			;��ɫ
		CALL	S_XSCK			;��ʾ�մ���
		PUSH	DX
		ADD	DX,4
		MOV	SI,OFFSET D_HELP
		CALL	S_XSZFC
		POP	DX
		MOV	SI,OFFSET D_HELP1
		ADD	DX,102H
		CALL	S_CKXS			;��ʾ����
		XOR	AH,AH			;����
		INT	16H
		XOR	DL,DL
		JMP	L_98			;���Ե�ǰҳ
;----------------------------------------------------------------------------
L_190:
		MOV	CL,4
		CMP	AX,3C00H		;F2:�����ı�ǰ��ɫ
		JNZ	L_200
		MOV	AL,C_A
		MOV	AH,AL
		AND	AX,0F00FH
		INC	AL
		CMP	AL,10H
		JB	L_191
		XOR	AL,AL
L_191:
		OR	AL,AH
		MOV	C_A,AL
		CALL	S_281			;��ʾ��ʾ��Ϣ1
		JMP	L_94
;----------------------------------------------------------------------------
L_200:
		CMP	AX,3D00H		;F3:�����ı�����ɫ
		JNZ	L_210
		MOV	AL,C_A
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_191
;----------------------------------------------------------------------------
L_210:
		CMP	AX,3E00H		;F4:Ŀ¼��Ϣǰ��ɫ
		JNZ	L_220
		MOV	AL,C_D
		MOV	AH,AL
		AND	AX,0F00FH
		INC	AL
		CMP	AL,10H
		JB	L_211
		XOR	AL,AL
L_211:
		OR	AL,AH
		MOV	C_D,AL
		CALL	S_281			;��ʾ��ʾ��Ϣ1
		JMP	L_94
;----------------------------------------------------------------------------
L_220:
		CMP	AX,3F00H		;F5:Ŀ¼��Ϣ����ɫ
		JNZ	L_230
		MOV	AL,C_D
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_211
;----------------------------------------------------------------------------
L_230:
		CMP	AX,4000H		;F6:ǿ����Ϣǰ��ɫ
		JNZ	L_240
		MOV	AL,C_B
		MOV	AH,AL
		AND	AX,0F00FH
		INC	AL
		CMP	AL,10H
		JB	L_231
		XOR	AL,AL
L_231:
		OR	AL,AH
		MOV	C_B,AL
		CALL	S_281			;��ʾ��ʾ��Ϣ1
		JMP	L_94
;----------------------------------------------------------------------------
L_240:
		CMP	AX,4100H		;F7:ǿ����Ϣ����ɫ
		JNZ	L_250
		MOV	AL,C_B
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_231
;----------------------------------------------------------------------------
L_250:
		CMP	AX,4200H		;F8:������Ϣǰ��ɫ
		JNZ	L_260
		MOV	AL,C_1			;������ɫ
		MOV	AH,AL
		AND	AX,0F00FH
		INC	AL
		CMP	AL,10H
		JB	L_251
		XOR	AL,AL
L_251:
		OR	AL,AH
		MOV	C_1,AL
		CALL	S_XSDH			;��ʾ����
		MOV	DX,100H
		CALL	S_281			;��ʾ��ʾ��Ϣ1
		JMP	L_100
;----------------------------------------------------------------------------
L_260:
		CMP	AX,4300H		;F9:������Ϣ����ɫ
		JNZ	L_270
		MOV	AL,C_1
		MOV	AH,AL
		AND	AX,0F00FH
		ADD	AH,10H
		JMP	SHORT L_251
;----------------------------------------------------------------------------
L_270:
		CMP	AX,4400H		;F10:���ô���
		JNZ	L_280
		MOV	DX,OFFSET D_COM
		MOV	BX,D_BP
		MOV	BYTE PTR DS:[BX],'.'    ;�ָ���չ��
		MOV	CX,20H
		MOV	AH,3CH			;�ؽ��ļ�
		INT	21H
		MOV	BX,AX
		MOV	DX,100H 		;�ļ���
		MOV	CX,OFFSET D_COM 	;�ļ�β
		SUB	CX,DX			;����
		MOV	AH,40H			;д��
		INT	21H
		MOV	AH,3EH			;�ر��ļ�
		INT	21H
		CALL	S_280			;��ʾ��ʾ��Ϣ
		JMP	L_100
;----------------------------------------------------------------------------
L_280:
		CMP	AH,52H			;<INS>:�л���ʾ
		JNZ	L_290
		CMP	D_TUX,0 		;��ǰ��ʾ?
		JZ	L_281
		CALL	S_280			;��ʾ��ʾ��Ϣ
		JMP	SHORT L_282
L_281:
		CALL	S_281			;��ʾ��ʾ��Ϣ1
L_282:
		JMP	L_100
S_280:
		MOV	D_TUX,0
		MOV	SI,OFFSET D_MSG
		JMP	S_XSTS
S_281:
		MOV	D_TUX,-1
		MOV	SI,OFFSET D_MSG1
		JMP	S_XSTS
;----------------------------------------------------------------------------
L_290:
		CMP	AL,0DH			;�س�
		JNZ	L_300
		CALL	S_280
		MOV	DI,D_TAB		;��ǰĿ¼��ַ
		OR	DI,DI			;��0
		JZ	L_291
		MOV	SI,[DI+2]		;������
		JMP	L_92			;��ʾ
L_291:
		JMP	L_100
;----------------------------------------------------------------------------
L_300:
		CMP	AL,1BH			;ESC
		JNZ	L_291
		MOV	AX,1813H		;������Ļ
		INT	10H
		MOV	CX,0E0FH
		MOV	AH,1			;�����
		INT	10H
		MOV	AX,4C00H		;�˳�
		INT	21H
;============================================================================
;�ӳ���:����ÿ���ס�Ŀ¼���׺��������׵�ַ CS=>DS
S_LINE		PROC	NEAR
		MOV	BP,CS:D_STAS		;�ı����׶�
		MOV	DS,BP			;		BP:��ǰ��
		MOV	BX,OFFSET D_DIR 	;Ŀ¼��Ϣ��ַ	BX:
		MOV	DI,OFFSET D_LINE	;���׵�ַ����� DI:
		XOR	CX,CX			;�к�		CX:
		XOR	AX,AX
		STOSW
		MOV	AX,BP
		STOSW
		XOR	SI,SI			;��ǰ���Ե�ַ
L_L1:
		LODSB				;ȡһ�ַ�
		CALL	S_SEG			;�п��
		CMP	AL,'!'                  ;���ܷ�?
		JNZ	L_L3
		LODSB
		CALL	S_SEG
		CMP	AL,'d'                  ;Ŀ¼��Ϣ
		JNZ	L_L2
		MOV	CS:[BX],CX		;�к�
		ADD	BX,4
		JMP	SHORT L_L1
L_L2:
		CMP	AL,'c'                  ;������Ϣ
		JNZ	L_L3
		CALL	S_SORT			;��Ŀ¼����д��
		JMP	SHORT L_L1
L_L3:
		CMP	AL,0DH			;�س�?
		JZ	L_L4
		CMP	AL,8DH			;���س�?
		JZ	L_L4
		CMP	AL,0AH			;����?
		JZ	L_L4
		CMP	AL,8AH			;��ҳ��?
		JNZ	L_L1
L_L4:
		OR	SI,SI			;�п��?
		JZ	L_L5
		MOV	BYTE PTR [SI-1],0	;����0(��β)
		JMP	SHORT L_L6
L_L5:
		PUSH	DS
		MOV	AX,DS
		SUB	AX,1000H		;��һ��
		MOV	DS,AX
		MOV	BYTE PTR DS:[0FFFFH],0	;��0
		POP	DS
L_L6:
		LODSB
		CALL	S_SEG
		MOV	AX,SI			;�����׵�ַ
		STOSW
		MOV	AX,BP			;��
		STOSW
		INC	CX

		CMP	BYTE PTR [SI],1AH	;����?
		JNZ	L_L1

		PUSH	CS
		POP	DS
		MOV	D_LM,CX 		;����к�
		XOR	AX,AX
		STOSW
		MOV	[BX+4],AX		;��β
		MOV	[BX+6],AX
		RET
S_LINE		ENDP

;�ӳ���:��Ŀ¼����д�� BX=Ŀ¼��Ϣ��ַ, CX=��ǰ�к�
S_SORT		PROC	NEAR
		CMP	CS:D_DM,0		;Ŀ¼��β
		JNZ	L_S0
		SUB	BX,4
		MOV	CS:D_DM,BX		;Ŀ¼��β
L_S0:
		LODSB				;��������1
		CALL	S_SEG
		MOV	DL,AL
		LODSB				;��������2
		CALL	S_SEG
		MOV	DH,AL

		PUSH	DS
		MOV	DS,CS:D_STAS		;�ļ��׶�
		PUSH	SI
		MOV	BX,OFFSET D_DIR 	;Ŀ¼����
L_S1:
		MOV	SI,CS:[BX]		;Ŀ¼�к�
		SHL	SI,1
		SHL	SI,1
		MOV	SI,WORD PTR CS:D_LINE[SI]	;����
L_S2:
		LODSB
		CMP	AL,'!'                  ;���ܷ�?
		JNZ	L_S2
		LODSB
		CMP	AL,'d'                  ;Ŀ¼��Ϣ
		JNZ	L_S2
		LODSW
		CMP	AX,DX			;��
		JZ	L_S3
		ADD	BX,4
		CMP	BX,CS:D_DM		;��Ŀ¼��β?
		JBE	L_S1
		POP	AX
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET NODIR
		JMP	L_ERR
L_S3:
		MOV	CS:[BX+2],CX		;Ŀ¼�����к�
		POP	SI
		POP	DS
		RET
S_SORT		ENDP
;----------------------------------------------------------------------------
;�ӳ���:��������ʾ����β����Ϣ
S_CLS		PROC	NEAR
		CALL	S_XSDH			;��ʾ����

		XOR	BL,BL
		CMP	D_MODE,9
		JZ	L_CLS1
		MOV	BL,C_A
L_CLS1:
		INC	DH
		CALL	S_CLSYH 		;��
		CMP	DH,24
		JB	L_CLS1

		MOV	SI,OFFSET D_MSG
S_XSTS: 					;�ӳ���:��ʾ��ʾ��Ϣ
		PUSH	DX
		MOV	DX,1800H
L_CLS3:
		LODSB
		OR	AL,AL
		JZ	L_CLS5
		MOV	BL,C_DZ
		CMP	AL,0A1H 		;�к���?
		JB	L_CLS4
		MOV	BL,C_DH
L_CLS4:
		CALL	S_XSZF			;��ʾ
		JMP	SHORT L_CLS3
L_CLS5:
		POP	DX
		RET
;�ӳ���:��ʾ����
S_XSDH:
		XOR	DX,DX
		MOV	BL,C_1
		CALL	S_CLSYH 		;�嶥��

		MOV	SI,OFFSET D_WJM 	;'�ļ���:'
		MOV	DL,6
		CALL	S_XSZFC
		MOV	SI,60H			;�ļ��������
		MOV	DL,14
		CALL	S_XSZFC
		MOV	SI,OFFSET D_YSH 	;'ҳ���к�:'
		MOV	DL,40
		CALL	S_XSZFC
		MOV	SI,OFFSET D_LMH 	;'�ܼ�����:'
		MOV	DL,60
;�ӳ���:��ʾ�ַ��� DX=λ��,SI=�ַ���
S_XSZFC:
		LODSB
		OR	AL,AL			;����
		JZ	L_XC1
		CALL	S_XSZF			;��ʾ
		JMP	SHORT S_XSZFC
L_XC1:
		RET
;�ӳ���:��һ�� BL=����,DH=��
S_CLSYH:
		XOR	DL,DL
		MOV	CX,80
L_CLSYH:
		MOV	AL,' '
		CALL	S_XSZF
		LOOP	L_CLSYH
		RET
;�ӳ���:��ʾ�ַ� DX:λ��,AL:�ַ�
S_XSZF:
		PUSH	CX
		MOV	CX,CS:D_CX		;=1:����ʾ����,=0:���ַ���ʾ1.3
		CMP	CS:D_MODE,9		;����?
		JNZ	L_XSZF2
		TEST	BL,0E0H
		JZ	L_XSZF1
		MOV	BL,70H
		JMP	SHORT L_XSZF2
L_XSZF1:
		MOV	BL,7
L_XSZF2:
		MOV	BH,AL
		MOV	AX,1409H		;��ʾ
		INT	10H
		POP	CX
		INC	DX			;λ��+1
		RET
S_CLS		ENDP
;----------------------------------------------------------------------------
;�ӳ���:��ʾһҳ
S_XS		PROC	NEAR
		PUSH	DX
		PUSH	SI
		MOV	D_DH,-1
		MOV	DX,100H 		;�ı������Ͻ�
		MOV	DI,D_SI 		;ҳ���к�
L_XS1:
		MOV	SI,DI
		SHL	SI,1
		SHL	SI,1
		ADD	SI,OFFSET D_LINE
		MOV	BP,CS:[SI+2]		;��

		MOV	DS,BP
		MOV	SI,CS:[SI]		;���׵�ַ
		CALL	S_XSYH			;��ʾһ��
		INC	DI
		INC	DH
		CMP	DH,24
		JNZ	L_XS1
		PUSH	CS
		POP	DS

		CALL	S_XSYS			;��ʾҳ���к�
		CALL	S_XSZJ			;��ʾ�ܼ�����
		POP	SI
		POP	DX
		RET
;�ӳ���:��ʾһ��
S_XSYH:
		MOV	BL,CS:C_A
L_X10:
		LODSB				;ȡһ�ַ�
		CALL	S_SEG
		CMP	AL,'!'                  ;�����ַ�?
		JZ	L_X11
		JMP	L_X20
L_X11:
		LODSB
		CALL	S_SEG
		CMP	AL,'b'                  ;ǿ���ַ�?
		JNZ	L_X14
		CMP	BYTE PTR [SI],'0'       ;������ɫ?
		JB	L_X13
		CMP	BYTE PTR [SI],'9'
		JA	L_X13
		LODSB				;ȡ����ɫ
		MOV	CL,4
		SHL	AL,CL
		MOV	BL,AL
		LODSB				;ȡǰ��ɫ
		CMP	AL,'9'
		JBE	L_X12
		AND	AL,5FH
		SUB	AL,7
L_X12:
		SUB	AL,'0'
		OR	BL,AL
		JMP	SHORT L_X10
L_X13:
		MOV	BL,CS:C_B
		JMP	SHORT L_X10
L_X14:
		CMP	AL,'a'                  ;�����ı�?
		JNZ	L_X15A
		MOV	BL,CS:C_A		;�����ı���ɫ
		MOV	CS:D_CX,1		;����ʾ����		1.3
		JMP	SHORT L_X10
L_X15A:
		CMP	AL,'e'                  ;����ʾ����?            1.3
		JNZ	L_X15B
		MOV	CS:D_CX,1		;����ʾ����		1.3
		JMP	SHORT L_X10
L_X15B:
		CMP	AL,'f'                  ;���ַ���ʾ?
		JNZ	L_X15
		MOV	CS:D_CX,0		;���ַ���ʾ		1.3
		JMP	SHORT L_X10
L_X15:
		CMP	AL,'d'                  ;Ŀ¼��Ϣ?
		JNZ	L_X17
		LODSB
		CALL	S_SEG
		LODSB
		CALL	S_SEG
		MOV	BL,CS:C_D		;Ŀ¼��Ϣ��ɫ
		CMP	CS:D_MODE,9
		JNZ	L_X16
		MOV	BL,7
L_X16:
		CMP	CS:D_DH,0		;����
		JZ	L_X16A
		MOV	BP,CS:D_TAB		;��ǰĿ¼��ַ
		OR	BP,BP			;��0
		JZ	L_X16A
		CMP	DI,CS:[BP]		;�Ƿ�Ŀ¼��
		JNZ	L_X16A
		MOV	CL,4
		ROR	BL,CL			;ǰ����������
L_X16A:
		JMP	L_X10
L_X17:
		CMP	AL,'c'                  ;������Ϣ?
		JNZ	L_X18
		LODSB
		CALL	S_SEG
		LODSB
		CALL	S_SEG
		JMP	L_X10
L_X18:
		PUSH	AX
		MOV	AL,'!'
		CALL	S_XSZF			;��ʾ�ַ�\
		POP	AX
L_X20:
		CMP	AL,9			;����?
		JNZ	L_X24
L_X21:
		MOV	AL,' '
		CALL	S_XSZF
		TEST	DL,7
		JZ	L_X22
		JMP	SHORT L_X21
L_X22:
		JMP	L_X10
L_X24:
		OR	AL,AL			;�н���?
		JZ	L_X30
L_X25:
		CALL	S_XSZF			;��ʾ
		JMP	L_X10
L_X30:
		CMP	DL,80			;����?
		JAE	L_X40
		MOV	AL,' '
		CALL	S_XSZF
		JMP	SHORT L_X30
L_X40:
		LODSB
		CALL	S_SEG
		XOR	DL,DL			;λ������
		RET
;�ӳ���:�п��
S_SEG:
		OR	SI,SI
		JNZ	L_SEG1
		MOV	BP,DS
		ADD	BP,1000H
		MOV	DS,BP
L_SEG1:
		RET
S_XS		ENDP
;----------------------------------------------------------------------------
;�ӳ���:��Ŀ¼��ʾ
S_CLSDIR	PROC	NEAR
		XOR	AL,AL
		JMP	SHORT L_DIR1
S_SETDIR:
		MOV	AL,-1
L_DIR1:
		MOV	D_DH,AL
		PUSH	DI
		MOV	SI,[DI]
		MOV	AX,SI
		SUB	AX,D_SI
		INC	AX
		MOV	DH,AL

		MOV	DI,SI
		SHL	SI,1
		SHL	SI,1
		ADD	SI,OFFSET D_LINE
		MOV	BP,[SI+2]		;��
		MOV	DS,BP
		MOV	SI,CS:[SI]		;���׵�ַ
		CALL	S_XSYH
		POP	DI
		PUSH	CS
		POP	DS
		RET
S_CLSDIR	ENDP
;----------------------------------------------------------------------------
;�ӳ���:��ʾҳ���к�
S_XSYS		PROC	NEAR
		MOV	AX,D_SI 		;ҳ����
		INC	AX
		MOV	DX,49
		JMP	SHORT L_XSH1
;�ӳ���:��ʾ�ܼ�����
S_XSZJ:
		MOV	AX,D_LM 		;�ܼ�����
		MOV	DX,69
L_XSH1:
		XOR	DH,DH
		MOV	BX,10
		MOV	CX,4
		MOV	DI,OFFSET D_HH+3
		PUSH	DX
L_XSH2:
		OR	AX,AX
		JZ	L_XSH3
		XOR	DX,DX
		DIV	BX
		OR	DL,'0'
		JMP	SHORT L_XSH4
L_XSH3:
		MOV	DL,' '
L_XSH4:
		MOV	[DI],DL
		DEC	DI
		LOOP	L_XSH2
		POP	DX

		MOV	DI,OFFSET D_HH
		MOV	BL,C_1
L_XSH5:
		MOV	AL,[DI]
		OR	AL,AL
		JZ	L_XSH6
		INC	DI
		CALL	S_XSZF
		JMP	SHORT L_XSH5
L_XSH6:
		RET
S_XSYS		ENDP
;----------------------------------------------------------------------------
D_G		DW	0			;���ڸ�
D_K		DW	0			;    ��
D_B1		DB	'�ͻ',0
D_B2		DB	'� �',0
D_B3		DB	'�ͼ',0
;�ӳ���:��ʾ�մ��� DX=�������Ͻ�,CH=��,CL=��,BL=��ɫ
S_XSCK		PROC	NEAR
		PUSH	DX
		SUB	CX,202H
		MOV	AL,CH
		CBW
		MOV	D_G,AX			;�����ڸ�
		MOV	AL,CL
		MOV	D_K,AX			;      ��

		XOR	CX,CX
		MOV	SI,OFFSET D_B1		;�Ϻ���
		CALL	S_XS1H

		MOV	SI,OFFSET D_B2		;�м�
		MOV	DI,D_G
L_CK1:
		INC	DH
		CALL	S_XS1H
		DEC	DI
		JNZ	L_CK1
		INC	DH
		MOV	SI,OFFSET D_B3		;�º���
		CALL	S_XS1H

		POP	DX
		RET
;�ӳ���:��ʾһ��:
S_XS1H:
		PUSH	DX
		MOV	AL,[SI] 		;���
		CALL	S_XSZF1
		MOV	BP,D_K
L_YH1:
		MOV	AL,[SI+1]		;�м�
		CALL	S_XSZF1
		DEC	BP
		JNZ	L_YH1
		MOV	AL,[SI+2]		;�ұ�
		CALL	S_XSZF1
		POP	DX
		RET
S_XSZF1:
		CMP	CS:D_MODE,9		;����?
		JNZ	L_XSZF22
		TEST	BL,0E0H
		JZ	L_XSZF11
		MOV	BL,70H
		JMP	SHORT L_XSZF22
L_XSZF11:
		MOV	BL,7
L_XSZF22:
		MOV	BH,AL
		MOV	AX,1409H		;��ʾ
		INT	10H
		INC	DX			;λ��+1
		RET
S_XSCK		ENDP

;�ӳ���:��ʾ��������SI(ÿ��β0,����ټ�0),DX=��λ��,BL=����
S_CKXS		PROC	NEAR
		PUSH	DX
L_CKXS1:
		CMP	BYTE PTR [SI],0 	;����?
		JZ	L_CKXS4
		PUSH	DX
		CALL	S_XSZFC
		POP	DX
		INC	DH
		JMP	SHORT L_CKXS1
L_CKXS4:
		POP	DX
		RET
S_CKXS		ENDP
;----------------------------------------------------------------------------
D_COM	EQU	$			;�ļ�ȫ��
D_DIR	EQU	$+64			;Ŀ¼����Ϣ ���255��
		;��ʽ:�к�,�����к�...	;��βΪ0
D_LINE	EQU	$+64+1024		;���׵�ַ�����
		;��ʽ:���׵�ַ,��,...	��βΪ0

CSEG		ENDS
		END	START

;	WBX.ASM 2.13L 五笔模块
;	1999.2.13, 11.14

D_0089_E	EQU	89H
D_00BD_E	EQU	0BDH
D_01EC_E	EQU	1ECH
D_01F4_E	EQU	1F4H
D_1A71_E	EQU	1A71H
D_5016_E	EQU	5016H
D_55DA_E	EQU	55DAH
D_55F2_E	EQU	55F2H
D_59DA_E	EQU	59DAH

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

	INCLUDE WBXMB2.INC			;码表103H以上部分

D_F1CC		DW	0
D_F1CE		DW	0
D_F1D0		DW	0
D_F1D2		DB	0

		ORG	0B0F0H
D_FE4A		DD	00000H			;扩充词汇地址

		ORG	0B100H
D_0000		DB	40H
D_0001		DB	2
D_0002		DB	0
D_0003		DB	0
D_0004		DB	1			;键入码数
D_0005		DB	0
D_0006		DB	0
D_0007		DB	0
D_0008		DB	0
D_0009		DB	0
D_000A		DB	5EH
		DB	0, 0
D_000D		DW	0	;返回码区
D_000F		DW	0	;返回码区首字节
D_0011		DW	D_55DA_E
D_0013		DW	D_01EC_E
D_0015		DW	0
		DW	0, 2
D_001B		DW	0
D_001D		DB	0
D_001E		DB	0, 0, 0 ;暂存键入码
D_0021		DB	0, 0	;	   第四码
D_0023		DB	1, 3, 9
D_0026		DB	19H
D_0027		DB	0, 0, 0, 0
D_002B		DW	3408H
D_002D		DB	39H
D_002E		DW	0
D_0030		DB	0
D_0031		DW	0
D_0033		DB	0, 0, 0
D_0037		DB	0, 0, 80H, 40H, 0
D_003C		DB	'GFDSAHJKLMNBVCXYUIOPTREWQ'
D_0055		DB	'张工了以在有地一上不是中国同民为这我的要和产发人经主'
D_IN		DW	0			;键入码区首

;== 五笔中断 ==============
;入口: BX-键入码区	 AX=0:首次
;      SI-返回区	   =-1:下一页
;      CX-1EH
;出口: DL|80H=0:无字词
;      DL|1=1:词汇
;      DL|4=1:重码
;      DL|2=1:Z功能

INT_3D		PROC	FAR			;F1D3
		CALL	S_F1E1
		JNC	L_F1DE
		OR	DL,80H			;有字或词
		IRET
L_F1DE:
		XOR	DL,DL			;=0:无字词
		IRET
INT_3D		ENDP

;---------------------------
S_F1E1		PROC	NEAR
		PUSH	ES
		PUSH	DS
		PUSH	SI
		PUSH	BX

		PUSH	DS
		POP	ES
		PUSH	CS
		POP	DS

		MOV	D_IN,BX
		MOV	BP,SI	;返回码区首	;S_F6B1
		MOV	D_0000,0
		MOV	D_F1CC,0
		MOV	D_F1CE,0
		MOV	D_F1D0,CX
		MOV	D_0007,0
		MOV	BYTE PTR ES:[BP],0	;清返回码区首
		MOV	D_000F,BP
		INC	BP
		MOV	D_000D,BP

		CMP	AX,0	;=0:首次
		JE	L_F1FB
		CMP	D_0008,0
		JE	L_F219
		JMP	L_F364
L_F1FB:
		CALL	S_F881	;参数初始化
		CALL	S_F734	;处理键入码
		JC	L_F206
		JMP	L_F41E
L_F206:
		CALL	S_F7A2	;键入码整理->0023和0027 码-40H
		CALL	S_F4AD	;键入码变形->002B和002E
		MOV	AL,D_0001
		CMP	AL,0		;判是否有Z?
		JNE	L_F219
		MOV	AL,D_0004
		MOV	D_0005,AL
L_F219:
		XOR	AX,AX
		MOV	AL,D_0005
		CMP	AL,1
		JNE	L_F225
		JMP	L_F2BC
L_F225:
		CMP	D_0004,AL
		JAE	L_F22E
		JMP	L_F3C7
L_F22E:
		MOV	BX,OFFSET D_0037
		XLAT
		CALL	S_F6FB
L_F235:
		CALL	S_F428	;查表
		JC	L_F26E
		CMP	D_0006,0
		JNE	L_F249
		CALL	S_F598	;置地址
		CALL	S_F428	;查表
		JC	L_F26E
L_F249:
		MOV	D_0006,0
		CMP	D_0001,0
		JNE	L_F258
		JMP	L_F36B
L_F258:
		MOV	AL,D_0004
		CMP	D_0005,AL
		JB	L_F264
		JMP	L_F2F6
L_F264:
		CALL	S_F585
		ADD	D_0005,1
		JMP	SHORT L_F219
L_F26E:
		CMP	D_0001,0
		JE	L_F292
		CMP	D_0005,4
		JNE	L_F287
		MOV	BX,D_0011
		MOV	AL,[BX-1]
		AND	AL,1FH
		JZ	L_F235
L_F287:
		CALL	S_F6E0
		CALL	S_F55C
		JC	L_F235
		JMP	L_F3C7
L_F292:
		CMP	D_0005,3
		JAE	L_F29F
		CALL	S_F6E0
		JMP	L_F3C7
L_F29F:
		CALL	S_F68A
		JC	L_F2A9
		CALL	S_F7F0
		JMP	SHORT L_F2AC
L_F2A9:
		CALL	S_F7E3
L_F2AC:
		CALL	S_F695
		JNC	L_F2B4
		JMP	L_F3C7
L_F2B4:
		MOV	D_0007,0FFH
		JMP	L_F235
L_F2BC:
		MOV	BX,OFFSET D_0026
		MOV	CX,3
L_F2C3:
		MOV	AL,[BX]
		DEC	BX
		CMP	AL,0
		JNE	L_F2EE
		LOOP	L_F2C3

		MOV	AL,[BX]
		CMP	AL,0
		JE	L_F2D7
		CALL	S_F806
		JMP	SHORT L_F2EE
L_F2D7:
		MOV	AL,D_0009
		INC	AL
		CMP	AL,1AH
		JAE	L_F2EE
		MOV	D_0009,AL
		CALL	S_F806
		CALL	S_F57A
		JC	L_F2D7
		JMP	L_F3C7
L_F2EE:
		ADD	D_0005,1
		JMP	L_F219
L_F2F6:
		CMP	D_0004,4
		JNE	L_F361
		CMP	D_0001,1
		JNE	L_F361
		CMP	D_0003,4
		JAE	L_F361
		CMP	D_0003,0
		JNE	L_F32B
		MOV	CL,3
		MOV	BX,OFFSET D_0021
		MOV	SI,BX
		STD
L_F31A:
		LODSB
		CMP	AL,5AH			; 'Z'
		JE	L_F31A
		MOV	[BX],AL
		DEC	BX
		LOOP	L_F31A

		MOV	BYTE PTR [BX],5AH	; 'Z'
		MOV	BYTE PTR [BX-1],5AH	; 'Z'
L_F32B:
		CMP	D_0003,4
		JAE	L_F361
		MOV	BX,OFFSET D_001D
		MOV	AL,D_0003
		XOR	AH,AH
		ADD	BX,AX
		MOV	AL,[BX]
		MOV	AH,[BX+1]
		MOV	[BX+1],AL
		MOV	[BX],AH
		ADD	D_0003,1
		MOV	AL,D_0003
		CMP	D_0002,AL
		JE	L_F32B
		CALL	S_F585
		MOV	D_0001,0
		CLD
		JMP	L_F206
L_F361:
		JMP	SHORT L_F3C7
L_F364:
		DEC	D_000D
		JMP	SHORT L_F3BA
L_F36B:
		CMP	D_0005,4
		JB	L_F3C7
		DEC	D_000D
		MOV	D_F1D2,0
		CALL	S_F4C4			;变换键入码第2-4码
		MOV	AL,D_0023	;第一码
		MOV	D_0008,0FFH
		XOR	AH,AH
		MOV	BX,D_0089_E	;首码索引    ;;;;
		SHL	AX,1
		ADD	BX,AX
		MOV	AX,[BX]
		MOV	BX,D_59DA_E	;词表首       ;;;;
		ADD	BX,AX
		MOV	DX,D_0031	;变换后
		MOV	CX,0FFFFH	;结束标志
L_F39E:
		MOV	AX,[BX]
		ADD	BX,2
		CMP	AX,DX		;判?
		JE	L_F3B7
		CMP	AX,-1		;判结束?
		JE	L_F3BA
L_F3AB:
		MOV	AX,[BX]
		ADD	BX,2
		TEST	AX,8080H	;找词尾?下一词首
		JZ	L_F3AB
		JMP	SHORT L_F39E
L_F3B7:
		CALL	S_F83E		;查到词处理
		JMP	SHORT L_F39E	;			2.13
L_F3BA:
		CALL	S_F5B0		;查扩充词汇
		JC	L_F3C2
		JMP	SHORT L_F3C7
L_F3C2:
		CALL	S_F871
		JC	L_F3BA
L_F3C7:
		CMP	D_0000,0
		JE	L_F41E
		XOR	DX,DX
		CMP	D_0008,0
		JNE	L_F408
		CMP	D_0001,0
		JNE	L_F414
		CMP	D_0007,0
		JNE	L_F419
		MOV	BP,D_000F
		OR	BYTE PTR ES:[BP],1
		MOV	AH,ES:[BP+1]
		MOV	AL,ES:[BP+2]
		STC				;无字词
		JMP	SHORT L_F41F
L_F3FA:
		MOV	BP,D_000F
		CMP	BYTE PTR ES:[BP],0
		JE	L_F41E
		STC				;无字词
		JMP	SHORT L_F41F
L_F408:
		OR	DL,1			;词汇
		CMP	D_0007,0
		JNE	L_F419
		JMP	SHORT L_F3FA
L_F414:
		OR	DL,2			;Z功能
		JMP	SHORT L_F3FA
L_F419:
		OR	DL,4			;有重码
		JMP	SHORT L_F3FA
L_F41E:
		CLC				;有字词
L_F41F:
		MOV	CX,D_F1CC
		POP	BX
		POP	SI
		POP	DS
		POP	ES
		RET
S_F1E1		ENDP

;查表-----------------------
S_F428		PROC	NEAR
		MOV	BX,D_0011
		MOV	CX,D_0013
		OR	CX,CX
		JZ	L_F460
		MOV	SI,D_002E
		MOV	DH,D_0030
		MOV	DI,D_002B
		MOV	DL,D_002D
L_F444:
		MOV	AX,[BX]
		AND	AX,SI
		CMP	AX,DI
		JE	L_F453
		ADD	BX,3
		LOOP	L_F444
		JMP	SHORT L_F460
L_F453:
		INC	BX
		INC	BX
		MOV	AL,[BX]
		INC	BX
		AND	AL,DH
		CMP	AL,DL
		LOOPNZ	L_F444
		JZ	L_F462
L_F460:
		CLC
		RET
L_F462:
		CMP	CX,0
		JNE	L_F468
		INC	CX
L_F468:
		MOV	D_0011,BX
		MOV	D_0013,CX
		MOV	D_0000,0FFH
		STC
		RET
S_F428		ENDP

;键入码变形-----------------
; 11111222 00223333 00344444
S_F477		PROC	NEAR
		MOV	AL,[SI]
		MOV	CL,3
		SHL	AL,CL
		MOV	DL,[SI+1]
		SHR	DL,1
		SHR	DL,1
		OR	AL,DL
		MOV	[BX],AL
		MOV	AL,[SI+1]
		MOV	CL,4
		SHL	AL,CL
		MOV	DL,[SI+2]
		SHR	DL,1
		OR	AL,DL
		AND	AL,3FH
		MOV	[BX+1],AL
		MOV	AL,[SI+2]
		MOV	CL,5
		SHL	AL,CL
		MOV	DL,[SI+3]
		OR	AL,DL
		AND	AL,3FH
		MOV	[BX+2],AL
		RET
S_F477		ENDP

;---------------------------
S_F4AD		PROC	NEAR
		MOV	SI,OFFSET D_0023
		MOV	BX,OFFSET D_002B
		CALL	S_F477
		MOV	SI,OFFSET D_0027
		MOV	BX,OFFSET D_002E
		CALL	S_F477
		RET
S_F4AD		ENDP

;为查词表,变换键入码--------
; 02222233 33344444
S_F4C4		PROC	NEAR
		MOV	SI,OFFSET D_0023
		MOV	BX,OFFSET D_0031
		MOV	AL,[SI+1]
		SHL	AL,1
		SHL	AL,1
		MOV	DL,[SI+2]
		SHR	DL,1
		SHR	DL,1
		SHR	DL,1
		OR	AL,DL
		MOV	[BX],AL
		MOV	AL,[SI+2]
		MOV	CL,5
		SHL	AL,CL
		MOV	DL,[SI+3]
		OR	AL,DL
		MOV	[BX+1],AL
		RET
S_F4C4		ENDP

;返回五笔码-----------------
S_F4F0		PROC	NEAR
		MOV	CH,D_0005
		MOV	SI,OFFSET D_0033
		MOV	BX,D_0011
		SUB	BX,3
		MOV	AL,[BX]
		MOV	AH,AL
		SHR	AL,1
		SHR	AL,1
		SHR	AL,1
		AND	AL,1FH
		OR	AL,60H			;原为40H		2.13
		MOV	[SI],AL
		DEC	CH
		SHL	AH,1
		SHL	AH,1
		AND	AH,1CH
		MOV	AL,[BX+1]
		MOV	CL,4
		SHR	AL,CL
		AND	AL,3
		OR	AL,AH
		OR	AL,60H			;			2.13
		MOV	[SI+1],AL
		DEC	CH
		JZ	L_F553
		MOV	AH,[BX+1]
		SHL	AH,1
		AND	AH,1EH
		MOV	AL,[BX+2]
		MOV	CL,5
		SHR	AL,CL
		AND	AL,1
		OR	AL,AH
		OR	AL,60H			;			2.13
		MOV	[SI+2],AL
		DEC	CH
		JZ	L_F557
		MOV	AL,[BX+2]
		AND	AL,1FH
		OR	AL,60H
		MOV	[SI+3],AL
		RET
L_F553:
		MOV	BYTE PTR [SI+2],20H
L_F557:
		MOV	BYTE PTR [SI+3],20H
		RET
S_F4F0		ENDP

;---------------------------
S_F55C		PROC	NEAR
		CALL	S_F4F0
		MOV	BP,D_000D
		MOV	BX,OFFSET D_0033
		MOV	CX,2
L_F56A:
		MOV	AX,[BX]
		MOV	ES:[BP],AX
		INC	BP
		INC	BP
		INC	BX
		INC	BX
		LOOP	L_F56A
		MOV	D_000D,BP
S_F57A:
		MOV	BP,D_000F
		MOV	AL,ES:[BP]
		CMP	AL,5
		RET
S_F55C		ENDP

;---------------------------
S_F585		PROC	NEAR
		MOV	D_0011,D_00BD_E
		MOV	D_0013,D_1A71_E
		MOV	D_0015,D_1A71_E
		RET
S_F585		ENDP

;---------------------------
S_F598		PROC	NEAR
		MOV	D_0011,D_5016_E
		MOV	D_0013,D_01F4_E
		MOV	D_0015,D_01F4_E
		MOV	D_0006,0FFH
		RET
S_F598		ENDP

;查扩充词汇-----------------
S_F5B0		PROC	NEAR
		PUSH	DS
		PUSH	ES
		LES	BX,D_FE4A		;扩充词汇
		NOP
		MOV	AX,ES
		CMP	AX,0			;判无?
		JE	L_F638
		MOV	AX,DS
		PUSH	ES
		POP	DS
		MOV	ES,AX
		CMP	ES:D_F1D2,0
		JNE	L_F5EE
		MOV	ES:D_F1D2,0FFH
		MOV	AX,[BX]
		MOV	ES:D_0015,AX
		MOV	ES:D_0013,AX
		MOV	AX,[BX+2]
		ADD	AX,BX
		MOV	ES:D_0011,AX
		MOV	AX,[BX+4]
		ADD	AX,BX
		MOV	ES:D_001B,AX
L_F5EE:
		MOV	BX,ES:D_0011
		MOV	CX,ES:D_0013
		OR	CX,CX
		JZ	L_F637
		MOV	SI,ES:D_002E
		MOV	DH,ES:D_0030
		MOV	DI,ES:D_002B
		MOV	DL,ES:D_002D
L_F610:
		MOV	AX,[BX]
		AND	AX,SI
		CMP	AX,DI
		JE	L_F620
		ADD	BX,3
		LOOP	L_F610
		JMP	SHORT L_F637
L_F620:
		INC	BX
		INC	BX
		MOV	AL,[BX]
		INC	BX
		AND	AL,DH
		CMP	AL,DL
		LOOPNZ	L_F610

		MOV	ES:D_0013,CX
		MOV	ES:D_0011,BX
		JZ	L_F63B
L_F637:
		CLC
L_F638:
		JMP	SHORT L_F687
L_F63B:
		MOV	ES:D_0000,0FFH
		MOV	AX,CX
		MOV	CX,ES:D_0015
		INC	AX
		SUB	CX,AX
		MOV	SI,ES:D_001B
		JZ	L_F65B
		CLD
L_F653:
		LODSW
		TEST	AX,8080H
		JNZ	L_F653
		LOOP	L_F653
L_F65B:
		MOV	DI,ES:D_000D
		POP	ES
		XOR	CX,CX
L_F663:
		LODSW
		STOSW
		INC	CX
		TEST	AX,8080H
		JNZ	L_F663
		POP	DS
		MOV	D_000D,DI
		INC	CX
		ADD	D_F1CE,CX
		CMP	D_F1CC,0
		JE	L_F681
		MOV	D_0007,0FFH
L_F681:
		INC	D_F1CC
		STC
		RET
L_F687:
		POP	ES
		POP	DS
		RET
S_F5B0		ENDP

;---------------------------
S_F68A		PROC	NEAR
		MOV	BX,D_0011
		DEC	BX
		MOV	AL,[BX]
		TEST	AL,40H
		JMP	SHORT L_F69E
S_F695:
		MOV	BX,D_0011
		DEC	BX
		MOV	AL,[BX]
		TEST	AL,80H
L_F69E:
		JZ	L_F6AF
		MOV	AH,D_0026
		CMP	AH,0
		JNE	L_F6AD
		TEST	AL,1FH
		JNZ	L_F6AF
L_F6AD:
		CLC
		RET
L_F6AF:
		STC
		RET
S_F68A		ENDP

;---------------------------
S_F6E0		PROC	NEAR
		CALL	S_F70E
S_F6E3:
		MOV	BP,D_000D
		MOV	ES:[BP],AX
S_F6EB:
		INC	BP
		INC	BP
		MOV	D_000D,BP
		MOV	BP,D_000F
		ADD	BYTE PTR ES:[BP],1
		RET
S_F6E0		ENDP

;---------------------------
S_F6FB		PROC	NEAR
		AND	BYTE PTR D_002B+1,3FH
		OR	BYTE PTR D_002B+1,AL
		AND	BYTE PTR D_002E+1,3FH
		OR	BYTE PTR D_002E+1,AL
		RET
S_F6FB		ENDP

;---------------------------
S_F70E		PROC	NEAR
		MOV	BX,D_0013
		INC	BX
		MOV	AX,D_0015
		SUB	AX,BX
		CMP	D_0006,0
		JNE	L_F727
		DIV	D_000A
		ADD	AX,0A1B0H
		RET
L_F727:
		SHL	AX,1
		MOV	BX,D_55F2_E		   ;;;;
		ADD	BX,AX
		MOV	AX,[BX]
		OR	AX,8080H
		RET
S_F70E		ENDP

;---------------------------
S_F734		PROC	NEAR
		MOV	BP,D_IN 		;入口:键入码区
		MOV	CX,4
		MOV	BX,OFFSET D_001E	;键入暂存区
L_F73F:
		MOV	AL,ES:[BP]
		CMP	AL,20H	; ' '
		JE	L_F78F
	;	CMP	AL,30H	; '0'
	;	JE	L_F78F
	;	CMP	AL,41H	; 'A'
	;	JB	L_F762
	CMP	AL,41H	;'A'                                    2.13
	JB	L_F7A0
		CMP	AL,7BH	; '{'
		JAE	L_F7A0
		AND	AL,5FH
L_F755:
		MOV	[BX],AL
		INC	BX
		INC	BP
		LOOP	L_F73F

		MOV	D_0004,4		;键入码数
		JMP	SHORT L_F79E
L_F762:
	;	CMP	AL,31H	; '1'
	;	JB	L_F7A0
	;	CMP	AL,37H	; '7'
	;	JAE	L_F7A0
	;	CMP	AL,36H	; '6'
	;	JE	L_F78A
	;	SUB	AL,31H
	;	MOV	AH,AL
	;	SHL	AL,1
	;	SHL	AL,1
	;	ADD	AH,AL	;*3
	;	INC	BP
	;	MOV	AL,ES:[BP]
	;	SUB	AL,31H
	;	ADD	AL,AH
	;	PUSH	BX
	;	MOV	BX,OFFSET D_003C
	;	XLAT
	;	POP	BX
	;	JMP	SHORT L_F755
L_F78A: ;
	;	INC	BP
	;	MOV	AL,5AH
	;	JMP	SHORT L_F755
L_F78F:
		MOV	AH,4
		SUB	AH,CL
		MOV	D_0004,AH
		MOV	AL,20H
L_F799:
		MOV	[BX],AL
		INC	BX
		LOOP	L_F799
L_F79E:
		STC
		RET
L_F7A0:
		CLC
		RET
S_F734		ENDP

;---------------------------
S_F7A2		PROC	NEAR
		MOV	BX,OFFSET D_001E	;键入码
		MOV	DI,OFFSET D_0023
		MOV	SI,OFFSET D_0027
		MOV	CX,4
L_F7B1:
		MOV	AL,[BX]
		CMP	AL,20H	; ' '
		JE	L_F7C8
		CMP	AL,5AH	; 'Z'
		JE	L_F7CE
		SUB	AL,40H
		MOV	BYTE PTR [SI],1FH
L_F7C0:
		MOV	[DI],AL
		INC	BX
		INC	DI
		INC	SI
		LOOP	L_F7B1
		RET
L_F7C8:
		XOR	AL,AL
		MOV	[SI],AL
		JMP	SHORT L_F7C0
L_F7CE:
		CMP	D_0003,0
		JNE	L_F7DC
		MOV	AL,5
		SUB	AL,CL
		MOV	D_0002,AL
L_F7DC:
		ADD	D_0001,1
		JMP	SHORT L_F7C8
S_F7A2		ENDP

;---------------------------
S_F7E3		PROC	NEAR
		CALL	S_F70E
		MOV	BP,D_000F
		INC	BP
		MOV	ES:[BP],AX
		RET
S_F7E3		ENDP

;---------------------------
S_F7F0		PROC	NEAR
		MOV	BP,D_000F
		CMP	BYTE PTR ES:[BP],0
		JNE	L_F802
		MOV	BP,D_000D
		CALL	S_F6EB
L_F802:
		CALL	S_F6E0
		RET
S_F7F0		ENDP

;Z功能:返回一键码-----------
S_F806		PROC	NEAR
		PUSH	AX
		SHL	AL,1
		XOR	AH,AH
		MOV	BX,OFFSET D_0055
		ADD	BX,AX
		MOV	AX,[BX]
		CALL	S_F6E3
		MOV	D_0000,0FFH
		POP	AX
		CMP	D_0001,0
		JE	L_F83D
		OR	AL,60H			;			2.13
		MOV	BP,D_000D
		MOV	ES:[BP],AL
		INC	BP
		MOV	CX,3
L_F831:
		MOV	BYTE PTR ES:[BP],20H
		INC	BP
		LOOP	L_F831

		MOV	D_000D,BP
L_F83D:
		RET
S_F806		ENDP

;查到词处理-----------------
S_F83E		PROC	NEAR
		CMP	D_F1CC,0
		JE	L_F84A
		MOV	D_0007,0FFH
L_F84A:
		MOV	SI,BX
		MOV	DI,D_000D
L_F850:
		LODSW
		INC	D_F1CE
		TEST	AX,8080H
		JNZ	L_F860
		OR	AX,8080H
		STOSW
		JMP	SHORT L_F850
L_F860:
		AND	AX,7F7FH
		STOSW
		MOV	D_000D,DI
		INC	D_F1CC
		MOV	D_0000,0FFH
S_F871:
		CMP	D_F1CC,8
		JA	L_F880
		MOV	CX,D_F1CE
		CMP	CX,D_F1D0
L_F880:
		RET
S_F83E		ENDP

;---------------------------
S_F881		PROC	NEAR
		MOV	D_0001,0
		MOV	D_0003,0
		MOV	D_0005,1
		MOV	D_0006,0
		MOV	D_0007,0
		MOV	D_0008,0
		MOV	D_0009,0
		CALL	S_F585
		RET
S_F881		ENDP

;==五笔处理模块==============================================================
D_KEY		DB	5 DUP(0)		;外码存放区
D_KEYS		DB	0			;	计数
D_CM		DB	0			;重码数
D_CMC		DB	0			;词汇重码数
D_BUF		DB	80 DUP(0)		;重码区
D_FHM		DB	80 DUP(0)		;返回码区
D_FHMS		DB	0			;	计数
D_WBZX		DB	'五笔',0
D_TUX1		DB	0
D_TUX2		DB	0
; 返回: AH-完成态
S_WBCL		PROC	FAR

		CMP	AL,8			;<退格>
		JNZ	L_WB10
		MOV	BL,D_KEYS
		OR	BL,BL			;判有键?
		JZ	L_WB2
		XOR	BH,BH
		CMP	D_KEY[BX],' '           ;判不满4键的Z功能?
		JNZ	L_WB0
		DEC	D_KEYS
L_WB0:
		MOV	D_CM,0
		CALL	S_9D7D			;键入码区定位
		CALL	S_1403K 		;清空
		DEC	D_KEYS			;键入码计数-1
		JNZ	L_WB2
L_WB1:
		MOV	AH,0FFH 	;完成态
L_WB2:
		RET
L_WB10:
		CMP	AL,0DH			;<回车>
		JNZ	L_WB18
		MOV	D_KEYS,0
		MOV	SI,OFFSET D_WBZX
		MOV	AX,2302H
		INT	16H
		RET
L_WB18:
		CMP	AL,' '                  ;<空格>
		JNZ	L_WB20
		CMP	D_CM,0			;已有重码?
		JZ	L_WB19
		MOV	AX,0FFH 		;翻页
		JMP	L_WB61
L_WB19:
		INC	D_KEYS
		CALL	S_9F89			;写入键入码区并显示
		JMP	L_WB60
L_WB20:
		MOV	CL,D_CMC		;词汇重码数
		OR	CL,CL
		JZ	L_WB30
L_WB21:
		XOR	CH,CH
		MOV	D_CMC,CH		;清
		XOR	BP,BP
		OR	CL,'0'
		CMP	AL,CL
		JA	L_WB22
		CMP	AL,'1'
		JAE	L_WB24
L_WB22:
		MOV	BP,AX			;BP=0:已选择
		MOV	AL,1			;无选择,默认第一个
L_WB24:
		AND	AL,0FH
		MOV	CL,AL
		DEC	CX
		MOV	SI,OFFSET D_BUF 	;重码区
L_WB24B:
		OR	CX,CX
		JZ	L_WB26
L_WB25:
		LODSW				;查找第CL个词
		TEST	AX,8080H
		JNZ	L_WB25
		LOOP	L_WB25
L_WB26:
		MOV	DI,OFFSET D_FHM 	;返回码区
		XOR	CX,CX
L_WB27:
		LODSW				;取一字
		MOV	[DI],AX
		ADD	DI,2
		INC	CX
		INC	CX
		TEST	AX,8080H		;判词结束
		JNZ	L_WB27
		OR	BYTE PTR [DI-4],80H	;高位置1
		OR	BYTE PTR [DI-2],80H	;高位置1
		MOV	D_FHMS,CL		;返回字节数
		MOV	D_CM,0
		OR	BP,BP			;=0:已选择
		JNZ	L_WB29
		JMP	L_WB1
L_WB29:
		MOV	AX,BP
		JMP	L_WB35			;非数字处理
L_WB30:
		MOV	CL,D_CM
		OR	CL,CL			;字重码数
		JZ	L_WB51
		MOV	D_FHMS,2		;返回字节数
		MOV	D_CM,0
		OR	CL,'0'
		CMP	AL,CL
		JA	L_WB34
		CMP	AL,'1'
		JB	L_WB34
		MOV	BL,AL
		AND	BL,0FH
		XOR	BH,BH
		SHL	BX,1
		MOV	AX,WORD PTR D_BUF[BX]	;选中
		JMP	L_WB98
L_WB34:
		MOV	DI,OFFSET D_FHM
		MOV	CX,WORD PTR D_BUF	;首字
		MOV	[DI],CX 		;返回
		ADD	DI,2
L_WB35:
		CMP	AL,'a'                  ;判小写字母?
		JB	L_WB36
		CMP	AL,'z'
		JA	L_WB36
L_WB35A:
		MOV	D_KEYS,1
		MOV	SI,OFFSET D_WBZX
		MOV	AX,2302H		;清提示行并显示
		INT	16H
		CALL	S_9F89			;写入键入码区并显示
		MOV	AH,0
		RET
L_WB36:
		MOV	AH,0FFH 	;完成态
		CMP	D_2BAC,0FFH		;判纯中文方式?		?
		JNZ	L_WB38
		CALL	L_9BB1			;纯中文处理
		RET
L_WB38:
		XOR	AH,AH
		MOV	DS:[DI],AX
		INC	D_FHMS
		RET
L_WB50:
		CALL	L_9BB9
		RET
L_WB51:
		CMP	AL,'a'
		JB	L_WB50
		CMP	AL,'z'
		JA	L_WB50
		CMP	D_KEYS,4
		JZ	L_WB35A
		INC	D_KEYS			;键+1
		CALL	S_9F89			;写入键入码区并显示
		CMP	D_KEYS,4		;满4键?
		JZ	L_WB60
		RET
;查WBZX
L_WB60:
		XOR	AX,AX
L_WB61:
		MOV	SI,OFFSET D_BUF 	;借用:返回区
		MOV	BX,OFFSET D_KEY 	;键入码区
		MOV	CX,1EH
		PUSHF
		CALL	INT_3D			;调WBZX模块
L_WB63:
		PUSH	CS
		POP	ES

		TEST	DL,80H			;判有无字词?
		JNZ	L_WB70
L_WB64:
		CALL	S_BEEP			;响铃
		RET
L_WB70:
		TEST	DL,1			;词汇?
		JNZ	L_WB70A
		JMP	L_WB80
L_WB70A:
		TEST	DL,4			;有重码?
		JZ	L_WB76
L_WB71:
		MOV	D_9650,CL	;?
		XOR	CH,CH
		PUSH	CX
		MOV	DL,10H
		CALL	S_9F30			;定位清提示行
		POP	CX
		MOV	DI,16
		MOV	DL,'1'
L_WB72:
		PUSH	DX
		MOV	BL,D_TUX1	;?
		CALL	S_1403			;显示序号
		INC	DI
L_WB73:
		LODSW				;取一字
		MOV	BL,D_TUX2	;?
		PUSH	AX
		OR	AX,8080H
		PUSH	AX
		CALL	S_1403A 		;显示前字节
		INC	DI
		POP	AX
		MOV	AL,AH
		CALL	S_1403A 		;显示后字节
		INC	DI
		POP	AX
		CMP	DI,78			;判提示行满?
		JBE	L_WB74
		POP	DX
		RET
L_WB74:
		TEST	AX,8080H		;判词尾?
		JZ	L_WB75
		JMP	SHORT L_WB73
L_WB75:
		MOV	DL,' '
		CALL	S_1403
		INC	DI
		POP	DX
		INC	DX
		LOOP	L_WB72
		RET
L_WB76:
		XOR	CX,CX
L_WB77:
		MOV	DI,OFFSET D_FHM
L_WB771:
		LODSW
		INC	CX
		INC	CX
		TEST	AX,8080H		;找词尾
		JZ	L_WB78
		MOV	[DI],AX
		ADD	DI,2
		JMP	SHORT L_WB771
L_WB770:
		JMP	L_WB64
L_WB78:
		CMP	AH,' '
		JB	L_WB770
		CMP	AL,' '
		JB	L_WB770
		OR	AX,8080H		;高位置1
		MOV	[DI],AX
L_WB79:
		MOV	D_FHMS,CL		;返回字节数
		JMP	L_WB1
L_WB80:
		TEST	DL,2			;Z功能?
		JZ	L_WB90
		MOV	DL,10H
		CALL	S_9F30			;定位清提示行
		MOV	DI,OFFSET D_BUF 	;字重码区
		LODSB				;重码数
L_WB84:
		MOV	CL,AL
		XOR	CH,CH
		MOV	D_CM,CL 		;存
		MOV	DL,'1'
L_WB88:
		PUSH	DX
		CALL	S_1403			;显示序号
		LODSW				;写入字重码区
		STOSW
		PUSH	AX
		CALL	S_1403A 		;显示前字节
		POP	AX
		MOV	DL,AH
		CALL	S_1403			;显示后字节
		LODSB
		CALL	S_1403A 		;显示五笔码
		LODSB
		CALL	S_1403A
		LODSB
		CALL	S_1403A
		LODSB
		CALL	S_1403A
		MOV	DL,' '
		CALL	S_1403
		POP	DX
		INC	DX
		LOOP	L_WB88
		RET
L_WB90:
		TEST	DL,4			;重码字?
		JZ	L_WB97
		MOV	DI,OFFSET D_BUF 	;字重码区
		LODSB				;重码数
L_WB92:
		MOV	CL,AL
		XOR	CH,CH
		MOV	D_CM,CL 		;存
		REP	MOVSW			;传送
		CALL	S_BEEP
L_WB94:
		MOV	DL,10H
		CALL	S_9F30			;定位清提示行
		MOV	DL,'1'
		CALL	S_A180			;显示重码字并响铃
		RET
L_WB97:
		XCHG	AH,AL
L_WB98:
		MOV	WORD PTR D_FHM,AX	;返回码
		MOV	D_FHMS,2		;返回字节数
		MOV	AH,0FFH
		RET
;子程序:写入键入码区并显示
S_9F89:
		PUSH	AX
		XOR	BH,BH
		MOV	BL,D_KEYS
		MOV	D_KEY[BX],AL		;写入键入码区
		MOV	BL,D_TUX1		;颜色:蓝底白字
		CALL	S_1403A 		;显示
		POP	AX
		RET
;子程序:汉字输入码定位
S_9D7D:
		MOV	DL,4
;子程序:键入字符定位
S_9D7F:
		ADD	DL,D_2BB0
		PUSH	AX
		CALL	S_1402			;提示行光标定位
		POP	AX
		RET

;子程序:定位5清提示行
S_9F2E:
		MOV	DL,5
;子程序:定位清提示行
S_9F30:
		CALL	S_1402			;提示行光标定位
;子程序:从指定位置开始清提示行
S_9F35:
		MOV	CX,76
D_9F36	EQU	$-2
		SUB	CL,DL			;从指定位置起字节数
		PUSH	DX
		CALL	S_1401
		POP	DX
;子程序:提示行光标定位
S_1402:
		MOV	AX,1402H
		INT	10H
		RET
S_1401:
		MOV	DL,' '                  ;空格
S_1401A:
		MOV	BL,D_TUX1
		XOR	BH,BH
		MOV	AX,1401H
		INT	10H
		RET
S_1403K:
		PUSH	BX
		MOV	CX,1
		CALL	S_1401			;显示一个空格
		POP	BX
		RET
;子程序:显示字符AL
S_1403A:
		MOV	DL,AL
;子程序:显示字符DL
S_1403:
		MOV	AX,1403H
		INT	10H
		RET
S_WBCL		ENDP

;****************************************************************************
BEGIN:
		MOV	SI,3
		MOV	AX,4A06H		;判安装2.13
		INT	2FH
		CMP	BX,4A06H
		JZ	L_10
L_ERR:
		MOV	DX,OFFSET NO213
L_EXIT:
		MOV	AH,9
		INT	21H
		INT	20H
L_10:
		MOV	SI,BX
		MOV	AH,2FH			;取INT16
		INT	16H
		CMP	SI,4A06H		;判安装CKBD?
		JZ	L_ERR
		MOV	AX,2006H		;取五笔模块参数BP:DX
		INT	16H
		OR	DX,DX			;判已安装?
		JNZ	L_20
	;	MOV	BP,OFFSET INT_3D
	;	MOV	DX,CS
	;	MOV	AX,2002H		;安装五笔参数
	;	INT	16H
		MOV	AX,2300H		;取提示行颜色
		INT	16H
		MOV	WORD PTR D_TUX1,AX
		PUSH	CS
		POP	ES
		MOV	SI,OFFSET D_0089
		MOV	DI,89H
		MOV	CX,103H-89H
		REP	MOVSB
		MOV	DX,OFFSET BEGIN
		INT	27H
L_20:
		CMP	BYTE PTR DS:[80H],0	;判命令行参数?
		JNZ	L_22
		MOV	DX,OFFSET EXIST
		JMP	L_EXIT
L_22:
		PUSH	DX
		XOR	BP,BP
		XOR	DX,DX
		MOV	AX,2002H		;清参数
		INT	16H
		XOR	DX,DX
		MOV	AX,2701H		;设置ASCII方式
		INT	16H
		MOV	AH,29H			;重显提示行
		INT	16H
		POP	ES
		PUSH	ES
		MOV	AH,49H			;清模块
		INT	21H
		MOV	ES,ES:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		POP	ES
		MOV	AX,ES:[0B0F2H]
		OR	AX,AX			;判安装扩充词汇?
		JZ	L_24
		MOV	ES,AX
		MOV	AH,49H			;清模块
		INT	21H
		MOV	ES,ES:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
L_24:
		MOV	DX,OFFSET EXIT
		JMP	L_EXIT

	INCLUDE WBXMB1.INC			;码表89H-103H部分

NO213		DB	'Not found 2.13 system!',7,13,10,'$'
EXIST		DB	'本模块已经安装!',7,13,10,'$'
EXIT		DB	'本模块已经退出!',7,13,10,'$'

SEG_A		ENDS
		END	START

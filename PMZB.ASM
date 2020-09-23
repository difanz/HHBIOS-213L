;	PMZB.ASM
;	1992.1.30
;	1995.2.10

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

		DW	1234H
D_INT9		DD	0			;原INT9
D_XMAX		DW	0			;X最大值
D_YMAX		DW	0			;Y最大值
D_X		DW	0			;X
D_Y		DW	0			;Y
D_DLTA		DW	1			;步距
DISP		DB	'<回车>退出 <空格>退出并返回坐标值 '
		DB	'<INS>步距10 <DEL>步距1]'
D_XS		DB	'坐标.'
D_XS1		DB	'000,000]$'
D_GB		DB	14,'NU5NY5NX5NZ5]$'
D_C143		DB	14,'C143]$'
D_C15		DB	14,'C15]$'
D_MD		DB	14,'MD$'

INT_9		PROC	FAR
		STI
		CLD
		PUSH	ES
		PUSH	AX
		XOR	AX,AX
		MOV	ES,AX
		IN	AL,60H
		TEST	AL,80H
		JNZ	EXIT
		TEST	BYTE PTR ES:[417H],8	;<ALT>
		JZ	EXIT
		CMP	AL,4AH			;'-'
		JNZ	EXIT
		JMP	SHORT L_10
EXIT:
		POP	AX
		POP	ES
		JMP	CS:D_INT9
L_10:
		IN	AL,60H
		PUSH	AX
		OR	AL,80H
		OUT	61H,AL
		POP	AX
		OUT	61H,AL
		MOV	AL,20H

		OUT	20H,AL
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	BP
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	SI,D_XMAX
		MOV	DI,D_YMAX
		MOV	BP,D_DLTA
		MOV	AX,1400H		;打开提示行
		INT	10H
		MOV	DX,1714H
		MOV	BX,OFFSET DISP
		CALL	S_XS1
		MOV	BX,OFFSET D_C143	;颜色=143
		CALL	S_STR
L_18:
		CALL	S_XS			;提示行显示
		MOV	BX,OFFSET D_MD		;14,'MD'
		CALL	S_STR
		MOV	BX,OFFSET D_XS1 	;画点
		CALL	S_STR
		MOV	BX,OFFSET D_GB
		CALL	S_STR			;显示光标
L_20:
		MOV	AH,1			;判按键?
		INT	16H
		JZ	L_20
		XOR	AH,AH			;取按键
		INT	16H
		CMP	AH,48H			;↑
		JNZ	L_32
		SUB	D_Y,BP
		JNB	L_38
		MOV	D_Y,0
		JMP	SHORT L_38
L_32:
		CMP	AH,50H			;↓
		JNZ	L_34
		ADD	D_Y,BP
		CMP	D_Y,DI
		JBE	L_38
		MOV	D_Y,DI
		JMP	SHORT L_38
L_34:
		CMP	AH,4BH			;←
		JNZ	L_36
		SUB	D_X,BP
		JNB	L_38
		MOV	D_X,0
		JMP	SHORT L_38
L_36:
		CMP	AH,4DH			;→
		JNZ	L_40
		ADD	D_X,BP
		CMP	D_X,SI
		JBE	L_38
		MOV	D_X,SI
L_38:
		MOV	BX,OFFSET D_GB
		CALL	S_STR			;关闭光标
		JMP	SHORT L_18
L_40:
		CMP	AH,52H			;<INS>
		JNZ	L_48
		MOV	AL,':'
		MOV	BP,10
L_42:
		MOV	D_DLTA,BP
		MOV	D_XS+4,AL
		JMP	L_38
L_48:
		CMP	AH,53H			;<DEL>
		JNZ	L_50
		MOV	AL,'.'
		MOV	BP,1
		JMP	SHORT L_42
L_50:
		CMP	AL,' '                  ;空格
		JNZ	L_54
		MOV	SI,OFFSET D_XS1
L_52:
		LODSB
		CMP	AL,']'
		JZ	L_56
		MOV	CL,AL
		MOV	AH,5
		INT	16H
		JMP	SHORT L_52
L_54:
		CMP	AL,0DH			;回车
		JNZ	L_60
L_56:
		MOV	AX,1404H		;关闭提示行
		INT	10H
		MOV	BX,OFFSET D_GB
		CALL	S_STR			;关闭光标
		MOV	BX,OFFSET D_C15 	;颜色=15
		CALL	S_STR
		POP	DS
		POP	BP
		POP	DI
		POP	SI
		POP	DX
		POP	CX
		POP	BX
		POP	AX
		POP	ES
		IRET
L_60:
		JMP	L_20
INT_9		ENDP

S_XS		PROC	NEAR
		MOV	AX,D_Y
		MOV	CX,30AH
		MOV	BX,OFFSET D_XS1+6
L_XS1:
		DIV	CL
		OR	AH,'0'
		MOV	DS:[BX],AH
		DEC	BX
		XOR	AH,AH
		DEC	CH
		JNZ	L_XS1
		MOV	AX,D_X
		MOV	CH,3
L_GB:
		DEC	BX
		DIV	CL
		OR	AH,'0'
		MOV	DS:[BX],AH
		XOR	AH,AH
		DEC	CH
		JNZ	L_GB
		MOV	BX,OFFSET D_XS
		MOV	DX,4E00H
S_XS1:
		MOV	AX,1402H
		INT	10H
L_C143:
		MOV	DL,[BX]
		CMP	DL,']'
		JZ	L_XSRET
		PUSH	BX
		MOV	BL,DH
		MOV	AX,1403H
		INT	10H
		POP	BX
		INC	BX
		JMP	SHORT L_C143
L_XSRET:
		RET
S_XS		ENDP

S_STR		PROC	NEAR
L_STR:
		MOV	AL,[BX]
		CMP	AL,'$'
		JZ	L_STR1
		MOV	AH,9
		INT	10H
		INC	BX
		JMP	SHORT L_STR
L_STR1:
		RET
S_STR		ENDP

;----------------------------------------------------------------------------
BEGIN:
		MOV	AX,3509H
		INT	21H
		CMP	ES:[103H],1234H 	;判本模块?
		JNZ	L_S10
		CMP	BYTE PTR DS:[80H],0	;有参数退出?
		JZ	L_S1
		LDS	DX,ES:D_INT9
		MOV	AX,2509H		;恢复INT9
		INT	21H
		MOV	AH,49H			;清本模块
		INT	21H
		MOV	ES,ES:[2CH]
		MOV	AH,49H
		INT	21H
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_TVIU
		MOV	AH,9
		INT	21H
		INT	20H
L_S1:
		MOV	DX,OFFSET D_YJCZ
		MOV	AH,9
		INT	21H
		INT	20H
L_S10:
		MOV	WORD PTR D_INT9,BX	;保存
		MOV	WORD PTR D_INT9+2,ES
		MOV	AX,1406H		;取显示参数
		INT	10H
		MOV	D_XMAX,SI		;X最大值
		MOV	D_YMAX,DI		;Y
		MOV	AX,SI
		INC	SI
		SHR	AX,1
		MOV	D_X,AX			;屏幕中心X
		MOV	AX,DI
		INC	AX
		SHR	AX,1
		MOV	D_Y,AX			;屏幕中心Y
		MOV	DX,OFFSET INT_9
		MOV	AX,2509H		;建中断
		INT	21H
		MOV	DX,OFFSET D_PMZB
		MOV	AH,9
		INT	21H
		MOV	DX,OFFSET BEGIN
		INT	27H

D_PMZB		DB	'屏幕坐标定位程序',13,10
		DB	'键入 ALT+"-"(小键盘) 屏幕坐标定位',13,10
		DB	'键入 PMZB 和任意参数 退出本模块',13,10,'$'
D_TVIU		DB	'退出屏幕坐标定位程序!',7,13,10,'$'
D_YJCZ		DB	'屏幕坐标定位程序已经调入!',7,13,10,'$'

CSEG		ENDS
		END	START

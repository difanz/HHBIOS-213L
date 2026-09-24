;	CM.ASM
;	1993.1.8

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		MOV	BL,DS:[80H]
		OR	BL,BL
		JNZ	L_10
		MOV	DX,OFFSET D_MSG
		MOV	AH,9
		INT	21H
		INT	20H

L_10:		XOR	BH,BH
		MOV	DS:[BX+81H],BH
		MOV	SI,81H
L_20:		LODSB
		CMP	AL,' '
		JZ	L_20

		CMP	AL,'+'
		JZ	L_100			;置属性
		JMP	L_200			;取属性

L_100:		XOR	CX,CX
L_110:		LODSB
		CMP	AL,' '
		JZ	L_120
		AND	AL,5FH
		CMP	AL,'R'                  ;读写
		JNZ	L_111
		AND	CL,0C0H
		JMP	SHORT L_110
L_111:		CMP	AL,'O'                  ;只读
		JNZ	L_112
		OR	CL,1
		JMP	SHORT L_110
L_112:		CMP	AL,'H'                  ;隐藏
		JNZ	L_113
		OR	CL,2
		JMP	SHORT L_110
L_113:		CMP	AL,'S'                  ;系统
		JNZ	L_114
		OR	CL,4
		JMP	SHORT L_110
L_114:		CMP	AL,'A'                  ;档案
		JNZ	L_115
		OR	CL,20H
		JMP	SHORT L_110
L_115:		CMP	AL,'G'                  ;共享
		JNZ	L_110
		OR	CL,80H
		JMP	SHORT L_110

L_120:		LODSB
		CMP	AL,' '
		JZ	L_120
		DEC	SI
		CALL	S_XS			;显示属性

		MOV	DI,OFFSET D_BUF 	;文件名处理区
		XOR	DX,DX
		XOR	BP,BP
L_130:		LODSB
		STOSB
		OR	AL,AL
		JZ	L_140
		CMP	AL,'*'
		JNZ	L_134
L_132:		MOV	DL,1
		JMP	SHORT L_130
L_134:		CMP	AL,'?'
		JZ	L_132
		CMP	AL,':'                  ;盘符
		JZ	L_136
		CMP	AL,'\'                  ;路径符
		JNZ	L_130
L_136:		MOV	BP,DI
		JMP	SHORT L_130

L_140:		OR	DL,DL			;=0单个文件
		JNZ	L_150
		MOV	DX,OFFSET D_BUF
		MOV	AX,4301H		;设置属性
		INT	21H
		JB	L_ERR
		INT	20H

L_150:		MOV	DS:[100H],CX
		MOV	DX,OFFSET D_BUF
		MOV	CX,0FFH
		MOV	AH,4EH			;找第一个文件
		INT	21H
		JB	L_ERR

L_160:		MOV	DX,9EH
		OR	BP,BP			;判有路径?
		JZ	L_170
		MOV	SI,DX
		MOV	DI,BP
		MOV	DH,0EH
L_162:		MOVSB
		DEC	DH
		JNZ	L_162
		MOV	DX,OFFSET D_BUF

L_170:		MOV	SI,DX
		PUSH	DX

		MOV	AH,2			;显示文件名
L_172:		LODSB
		CMP	AL,0
		JE	L_174
		MOV	DL,AL
		INT	21H
		JMP	SHORT L_172
L_174:		MOV	DL,0DH			;回车
		INT	21H
		MOV	DL,0AH			;换行
		INT	21H

		POP	DX
		MOV	CX,DS:[100H]
		MOV	AX,4301H		;设置属性
		INT	21H
		MOV	AH,4FH			;找下一个文件
		INT	21H
		JNB	L_160
		INT	20H

L_ERR:		MOV	DX,OFFSET D_02D0
		MOV	AH,9
		INT	21H
		INT	20H

;取属性
L_200:		DEC	SI
		MOV	DX,SI
		MOV	CX,0FFH
		MOV	AH,4EH			;找第一个文件
		INT	21H
		JB	L_ERR
L_210:		MOV	SI,9EH
		XOR	DH,DH

		MOV	AH,2			;显示文件名
L_220:		LODSB
		OR	AL,AL
		JZ	L_230
		MOV	DL,AL
		INT	21H
		INC	DH
		JMP	SHORT L_220

L_230:		CMP	DH,0EH
		JZ	L_240
		MOV	DL,'-'
		INT	21H
		INC	DH
		JMP	SHORT L_230

L_240:		MOV	CL,DS:[95H]		;属性
		CALL	S_XS			;显示属性
		MOV	AH,4FH			;找下一个文件
		INT	21H
		JNB	L_210
		INT	20H

S_XS		PROC	NEAR
		TEST	CL,1
		JZ	L_XS1
		MOV	DX,OFFSET D_RO		;'只读'
		MOV	AH,9
		INT	21H
L_XS1:		TEST	CL,2
		JZ	L_XS2
		MOV	DX,OFFSET D_HI		;'隐藏'
		MOV	AH,9
		INT	21H
L_XS2:		TEST	CL,4
		JZ	L_XS3
		MOV	DX,OFFSET D_XT		;'系统'
		MOV	AH,9
		INT	21H
L_XS3:		TEST	CL,8
		JZ	L_XS4
		MOV	DX,OFFSET D_JB		;'卷标'
		MOV	AH,9
		INT	21H
L_XS4:		TEST	CL,10H
		JZ	L_XS5
		MOV	DX,OFFSET D_SUB 	;'子目录'
		MOV	AH,9
		INT	21H
L_XS5:		TEST	CL,20H
		JZ	L_XS6
		MOV	DX,OFFSET D_DA		;'档案'
		MOV	AH,9
		INT	21H
L_XS6:		TEST	CL,80H
		JZ	L_XS7
		MOV	DX,OFFSET D_GX		;共享'
		MOV	AH,9
		INT	21H
L_XS7:		MOV	AH,2
		MOV	DL,0DH
		INT	21H
		MOV	DL,0AH
		INT	21H
		RET
S_XS		ENDP

D_RW		DB	'读写 $'
D_RO		DB	'只读 $'
D_HI		DB	'隐形 $'
D_XT		DB	'系统 $'
D_JB		DB	'卷标 $'
D_SUB		DB	'子目录 $'
D_DA		DB	'档案 $'
D_GX		DB	'共享 $'
D_MSG		DB	'格式:CM  [+属性符]  文件名',13,10
		DB	'其中:有[+属性符]项为设置属性',13,10
		DB	'     属性符:R-读写',13,10
		DB	'            O-只读',13,10
		DB	'            H-隐形',13,10
		DB	'            S-系统',13,10
		DB	'            A-档案',13,10
		DB	'            G-共享',13,10
		DB	'     文件名中可使用通配符?和*',13,10,'$'
D_02D0		DB	'参数错!', 7, 0DH, 0AH, '$'
D_BUF		EQU	$

SEG_A		ENDS
		END	START

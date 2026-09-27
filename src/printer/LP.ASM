;	LP.ASM
;	1995.11.13
;	1997.2.17-支持WINDOWS95在DOS窗口下打印

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:
		MOV	AX,3517H		;取INT17中断
		INT	21H
		MOV	WORD PTR D_INT17,BX	;保存
		MOV	WORD PTR D_INT17+2,ES

		MOV	AH,2			;取打印机状态
		CALL	S_INT17
		TEST	AH,20H			;联机?
		JZ	L_10
		MOV	DX,OFFSET NOPAPE	;'打印机没纸了!'
		JMP	SHORT L_ERR
L_10:
		TEST	AH,9
		JZ	L_20
		MOV	DX,OFFSET IOERR 	;'并行口I/O错误!'
		JMP	SHORT L_ERR
L_20:
		MOV	SI,80H
		LODSB
		CMP	AL,1
		JBE	L_50			;无参数直接回车换行
		CBW
		MOV	BX,AX
		MOV	[BX+SI],AH		;文件尾
L_30:
		LODSB
		CMP	AL,' '
		JZ	L_30

		CMP	AL,'0'                  ;判数字?
		JB	L_40
		CMP	AL,'9'
		JBE	L_60
L_40:
		CALL	S_DYAL			;打印
		LODSB				;取字符
		OR	AL,AL
		JNZ	L_40
L_50:
		MOV	AL,0DH			;回车
		CALL	S_DYAL
		MOV	AL,0AH			;换行
		CALL	S_DYAL
		JMP	L_210			;返回AL=0,EXIT
L_60:
		PUSH	SI
L_70:
		LODSB
		CMP	AL,'0'                  ;判数字?
		JB	L_80
		CMP	AL,'9'
		JBE	L_70
L_80:
		POP	SI
		DEC	SI
		OR	AL,AL			;无文件名?
		JNZ	L_100
		LODSB				;原数字
		JMP	SHORT L_40
L_100:
		MOV	CX,10			;乘数
		XOR	BX,BX			;结果
L_110:
		LODSB
		CMP	AL,' '
		JZ	L_120
		AND	AL,0FH
		CBW
		XCHG	AX,BX
		MUL	CX			;结果*10
		ADD	BX,AX			;累加
		JMP	SHORT L_110
L_120:
		MOV	BP,BX			;份数
L_130:
		LODSB
		CMP	AL,' '
		JZ	L_130

		DEC	SI
		MOV	DX,SI
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_140
		MOV	DX,OFFSET NOFILE	;'指定文件未找到!'
L_ERR:
		MOV	AH,9
		INT	21H
		MOV	AL,1			;返回码
		JMP	L_EXIT
L_140:
		MOV	BX,AX
		MOV	DX,OFFSET D_BUF
		MOV	CX,-1
		MOV	AH,3FH			;读文件
		INT	21H
		JNB	L_150
		MOV	DX,OFFSET READERR	;'指定文件读出错!'
		JMP	SHORT L_ERR
L_150:
		MOV	DI,AX			;文件长度
		MOV	AH,3EH			;关闭文件
		INT	21H

		MOV	BX,OFFSET PRINTING+10
L_160:
		MOV	DX,OFFSET PRINTING	;'正在打印第００１份. . .$'
		MOV	AH,9
		INT	21H

		MOV	CX,DI			;文件长度
		MOV	SI,OFFSET D_BUF 	;文件首
L_170:
		LODSB				;取字符
		CMP	AL,1AH			;ESC?
		JZ	L_180
		CALL	S_DYAL			;打印

		MOV	AH,1			;判按键?
		INT	16H
		JZ	L_171
		XOR	AH,AH			;取键
		INT	16H
		OR	AX,AX			;判CTRL+BREAK?
		JZ	L_EXIT
L_171:
		LOOP	L_170
L_180:
		CMP	BP,1			;只1份?
		JZ	L_210
		MOV	DX,OFFSET CONTINUE	;'按回车键继续打印下一份!'
		MOV	AH,9
		INT	21H
L_190:
		MOV	AX,0C01H		;键入
		INT	21H
		CMP	AX,0C01H
		JZ	L_210
		CMP	AL,0DH			;回车?
		JNZ	L_190
		MOV	AX,0E0AH		;换行
		INT	10H

		INC	BYTE PTR [BX+5] 	;个位+1
		CMP	BYTE PTR [BX+5],0BAH
		JB	L_200
		MOV	BYTE PTR [BX+5],0B0H
		INC	BYTE PTR [BX+3] 	;十位+1
		CMP	BYTE PTR [BX+3],0BAH
		JB	L_200
		MOV	BYTE PTR [BX+3],0B0H
		INC	BYTE PTR [BX+1] 	;百位+1
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
NOPAPE		DB	'打印机没纸了!',7,13,10,'$'
IOERR		DB	'并行口I/O错误!',7,13,10,'$'
NOFILE		DB	'指定文件未找到!',7,13,10,'$'
READERR 	DB	'指定文件读出错!',7,13,10,'$'
PRINTING	DB	'正在打印第００１份. . .$'
CONTINUE	DB	'按回车键继续打印下一份!',7,'$'

D_BUF	EQU	$

SEG_A		ENDS
		END	START

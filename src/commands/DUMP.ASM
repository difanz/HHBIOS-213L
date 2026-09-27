;	DUMP.ASM
;	1997.6.27, 7.4

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

D_INT25 	DD	0			;逻辑扇区号
		DW	1			;扇区数
		DW	OFFSET D_BUF
D_CS		DW	0

D_HAN		DW	0			;文件号
D_END		DW	OFFSET D_BUF+200H	;读出区尾
D_LEN		DW	0			;读出长度
D_XX		DW	0,0			;文件长度
D_AX		DW	0			;文件位置
D_DX		DW	0
D_COM		DB	0			;COM文件标志

MSG		DB	'Display disk boot sector or file.',13,10
		DB	'STYLE: DUMP [d:] or DUMP [d:][path][filename] or [seg:off]',13,10
		DB	'Display: <backspace> - back 128 bytes.',13,10
		DB	'         <tab> ------- next 1000H bytes.',13,10
		DB	'         <`> --------- next 32K bytes.',13,10
		DB	'         othe key ---- next 128 bytes.$'
GSERR		DB	'SYNTAX ERROR!',7,13,10,'$'
D_FILE		DB	'File name is $'
D_BOOT		DB	'The hard disk BOOT:',13,10,'$'
D_INP		DB	'INPUT: ESC-EXIT, OTHE-Next Area...$'
D_NEXT		DB	13,10,'Next Extender Area: $'
D_BOOT1 	DB	'A: disk BOOT:',13,10,'$'

BEGIN:
		MOV	SI,80H
		LODSB
		OR	AL,AL			;=0: no args
		JNZ	L_10
		MOV	DX,80H
		MOV	CX,1
L_RD:
		MOV	AX,201H
		MOV	BX,OFFSET D_BUF
		INT	13H			; read hard-disk boot
		JNC	L_8
		JMP	L_ERR1
L_8:
		MOV	DX,OFFSET D_BOOT
		CALL	S_MSG
		CALL	L_31
		MOV	BP,4
		MOV	BX,1BEH			; partition table
L_P1:
		CMP	BYTE PTR [BX+OFFSET D_BUF+4],5
		JZ	L_P2
		ADD	BX,10H
		DEC	BP
		JNZ	L_P1
		JMP	L_40
L_P2:
		MOV	DX,OFFSET D_INP
		CALL	S_MSG
		XOR	AH,AH
		INT	16H
		CMP	AL,1BH
		JNZ	L_P3
		JMP	L_40
L_P3:
		MOV	DX,OFFSET D_NEXT
		CALL	S_MSG
		MOV	CX,[BX+OFFSET D_BUF+2]
		MOV	DX,[BX+OFFSET D_BUF]
		ADD	DX,80H
		JMP	L_RD
L_10:
		CBW
		MOV	BX,AX
		MOV	BYTE PTR [BX+SI],0	; end of name
L_12:
		LODSB
		CMP	AL,' '
		JZ	L_12
		CMP	AL,'/'
		JNZ	L_13
		CMP	BYTE PTR [SI],'?'
		JNZ	L_13
		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
		JMP	L_EXIT
L_13:
		DEC	SI
		MOV	DX,SI
		MOV	AX,3D00H		; open file
		INT	21H
		JAE	L_14
		JMP	L_20
L_14:
		MOV	D_HAN,AX
		MOV	BX,AX
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4202H		; file length
		INT	21H
		MOV	D_XX,AX
		MOV	D_XX+2,DX
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4200H		; rewind
		INT	21H

		MOV	DX,OFFSET D_FILE	;'File name is $'
		MOV	AH,9
		INT	21H
L_15:
		LODSB
		OR	AL,AL
		JZ	L_16
		CALL	S_XSAL
		JMP	SHORT L_15
L_16:
		SUB	SI,4			; extension
		LODSB
		AND	AL,5FH
		CMP	AL,'C'                  ; .COM?
		JNZ	L_17
		LODSB
		AND	AL,5FH
		CMP	AL,'O'
		JNZ	L_17
		LODSB
		AND	AL,5FH
		CMP	AL,'M'
		JNZ	L_17
		MOV	D_COM,1
L_17:
		CALL	S_XS2KG
		MOV	AX,D_XX+2
		CALL	S_HEXAX
		MOV	AL,':'
		CALL	S_XS1
		MOV	AX,D_XX
		CALL	S_HEXAX
		CALL	S_0D0A
L_18:
		MOV	BX,D_HAN
		MOV	DX,OFFSET D_BUF
		MOV	CX,8000H
		MOV	AH,3FH			; read file
		INT	21H
		JAE	L_18A
		JMP	L_40
L_18A:
		OR	AX,AX
		JNZ	L_18B
		JMP	L_40
L_18B:
		MOV	D_LEN,AX
		ADD	AX,DX
		MOV	D_END,AX
		CALL	L_31
		JMP	L_18
L_20:
		MOV	SI,81H
L_21:
		LODSB
		CMP	AL,' '
		JBE	L_21
		CMP	BYTE PTR [SI],':'
		JNZ	L_23
		AND	AL,5FH
		CMP	AL,'A'
		JB	L_23
		CMP	AL,'Z'
		JBE	L_26
L_23:
		DEC	SI
		CALL	S_JSHEX
		JB	L_23A
		CMP	AL,0DH
		JZ	L_24
		MOV	D_DX,DX
		CALL	S_JSHEX
		JMP	SHORT L_25
L_23A:
		MOV	DX,OFFSET GSERR
		JMP	L_ERR
L_24:
		MOV	D_DX,0
L_25:
		MOV	D_AX,DX
		MOV	SI,DX
		MOV	D_END,-1
		CALL	L_32
		JMP	L_40
L_26:
		MOV	AL,DS:[5CH]
		DEC	AX
		MOV	BYTE PTR DS:[100H],AL
		ADD	D_BOOT1,AL
		MOV	BX,OFFSET D_BUF
		MOV	CX,1
		XOR	DX,DX
		INT	25H
		POP	DX
		JNC	L_28
		MOV	D_CS,CS
		MOV	AL,DS:[100H]
		MOV	BX,OFFSET D_INT25
		MOV	CX,-1
		INT	25H
		POP	DX
		JNC	L_28
		JMP	L_ERR1
L_28:
		MOV	DX,OFFSET D_BOOT1
		CALL	L_31
L_40:
		XOR	AL,AL
L_EXIT:
		MOV	AH,4CH
		INT	21H
L_ERR:
		MOV	AH,9
		INT	21H
L_ERR1:
		MOV	AL,-1
		JMP	SHORT L_EXIT

L_31:
		MOV	D_DX,CS
		MOV	SI,OFFSET D_BUF
L_32:
		CALL	S_XS8H
		CMP	CS:D_END,-1
		JZ	L_33
		CMP	SI,D_END
		JB	L_33
L_32A:
		CMP	D_HAN,0
		JZ	L_32R
		CMP	D_LEN,8000H
		JB	L_32R
L_32B:
		MOV	AX,D_LEN
		ADD	D_AX,AX
		ADC	D_DX,0
L_32R:
		RET
L_33:
		XOR	AH,AH
		INT	16H
		CMP	AL,8
		JNZ	L_34
		CMP	SI,OFFSET D_BUF+80H
		JBE	L_33
		SUB	SI,100H
		JMP	SHORT L_32
L_34:
		CMP	AL,9
		JNZ	L_35
		ADD	SI,1000H
		CMP	CS:D_END,-1
		JZ	L_32
		CMP	SI,D_END
		JB	L_32
		JMP	L_32B
L_35:
		CMP	AL,'`'
		JZ	L_32B
		CMP	AL,1BH
		JNZ	L_32
		POP	AX
		JMP	L_40

S_MSG		PROC	NEAR
		MOV	AH,9
		INT	21H
		RET
S_MSG		ENDP

;子程序:显示8行
S_XS8H		PROC	NEAR
		MOV	CX,8			;八行
L_81:
		PUSH	CX
		MOV	AX,CS:D_DX		;段
		MOV	DS,AX
		CALL	S_HEXAX 		;显示当前段
		MOV	AL,':'
		CALL	S_XS1			;显示冒号
		MOV	AX,SI
		CMP	CS:D_END,-1		;判内存?
		JZ	L_81A
		SUB	AX,OFFSET D_BUF
		ADD	AX,CS:D_AX
		CMP	CS:D_COM,1		;判.COM文件?
		JNZ	L_81A
		ADD	AX,100H
L_81A:
		CALL	S_HEXAX 		;显示当前地址
		CALL	S_XS2KG 		;显示双空格

		PUSH	SI
		MOV	CL,16
L_82:
		LODSB
		CALL	S_HEXAL 		;显示字节内容

		MOV	AL,' '
		CMP	CL,9
		JNZ	L_83
		MOV	AL,'-'
L_83:
		CALL	S_XS1			;显示分隔符
		LOOP	L_82
		POP	SI

		CALL	S_XS2KG 		;显示双空格
		MOV	CL,16
L_84:
		LODSB
		CMP	AL,' '
		JB	L_85
		CMP	AL,7FH
		JB	L_86
		CMP	AL,0A0H
		JA	L_86
L_85:
		MOV	AL,'.'
L_86:
		CALL	S_XSAL			;显示字符
		LOOP	L_84
		POP	CX

		CMP	CS:D_END,-1		;判内存?
		JZ	L_87
		CMP	SI,D_END		;到读出区尾?
		JAE	L_90
L_87:
		CALL	S_0D0A			;回车换行
		LOOP	L_81
L_90:
		CALL	S_0D0A			;回车换行
		PUSH	CS
		POP	DS
		RET
S_XS8H		ENDP

;子程序:显示双空格
S_XS2KG 	PROC	NEAR
		MOV	AL,' '
		CALL	S_XSAL
		MOV	AL,' '
;子程序:显示AL
S_XSAL:
		CMP	CS:D_END,-1		;判内存?
		JZ	S_XS1
		CMP	SI,D_END		;到读出区尾?
		JBE	S_XS1
		MOV	AL,' '
S_XS1:
		CMP	AL,' '
		JB	S_XS2
		PUSH	CX
		MOV	BX,7
		MOV	CX,1
		MOV	AH,9
		INT	10H
		POP	CX
S_XS2:
		MOV	AH,0EH
		INT	10H
		RET
S_XS2KG 	ENDP

;子程序:回车换行
S_0D0A		PROC	NEAR
		MOV	AX,0E0DH
		INT	10H
		MOV	AL,0AH
		INT	10H
		RET
S_0D0A		ENDP

;子程序:显示十六进制AX
S_HEXAX 	PROC	NEAR
		PUSH	AX
		MOV	AL,AH
		CALL	S_HEXAL
		POP	AX
;子程序:显示十六进制AL
S_HEXAL:
		PUSH	AX
		SHR	AL,1
		SHR	AL,1
		SHR	AL,1
		SHR	AL,1
		CALL	S_HEXAL1
		POP	AX
		AND	AL,0FH
;子程序:显示十六进制AL低八位
S_HEXAL1:
		OR	AL,'0'
		CMP	AL,'9'
		JBE	L_HEX1
		ADD	AL,7
L_HEX1:
		JMP	S_XSAL
S_HEXAX 	ENDP

;子程序:计算十六进制数->DX
S_JSHEX 	PROC	NEAR
		XOR	DX,DX
L_JS0:
		LODSB
		CMP	AL,':'                  ;段分隔符
		JZ	L_JS9
		CMP	AL,0DH			;地址结束
		JZ	L_JS9
		CMP	AL,'0'                  ;判数字?
		JB	L_JSERR
		CMP	AL,'9'
		JA	L_JS1
		AND	AL,0FH
		JMP	SHORT L_JS2
L_JS1:
		AND	AL,5FH
		CMP	AL,'A'                  ;判A~F?
		JB	L_JSERR
		CMP	AL,'F'
		JA	L_JSERR
		SUB	AL,'A'
		ADD	AL,10
L_JS2:
		CBW
		PUSH	AX
		MOV	AX,16
		MUL	DX
		POP	CX
		ADD	AX,CX
		MOV	DX,AX
		JMP	SHORT L_JS0
L_JS9:
		CLC
		RET
L_JSERR:
		STC
		RET
S_JSHEX 	ENDP

D_BUF	EQU	$				;读出区

SEG_A		ENDS
		END	START

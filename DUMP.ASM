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
D_BOOT1 	DB	'A: disk BOOT:',13,10,'$'

BEGIN:
		MOV	SI,80H
		LODSB
		OR	AL,AL			;=0:无参数
		JNZ	L_10
		MOV	DL,80H
		MOV	AX,201H
		MOV	BX,OFFSET D_BUF
		MOV	CX,1
		XOR	DH,DH
		INT	13H			;读硬盘总BOOT
		JNC	L_8
		JMP	L_ERR1
L_8:
		MOV	DX,OFFSET D_BOOT
		JMP	L_30
L_10:
		CBW
		MOV	BX,AX
		MOV	BYTE PTR [BX+SI],0	;文件名尾
L_12:
		LODSB
		CMP	AL,' '
		JZ	L_12
		CMP	AL,'/'
		JNZ	L_13
		CMP	BYTE PTR [SI],'?'       ;显示帮助
		JNZ	L_13
		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
		JMP	L_EXIT
L_13:
		DEC	SI
		MOV	DX,SI
		MOV	AX,3D00H		;打开文件
		INT	21H
		JB	L_20
		MOV	D_HAN,AX
		MOV	BX,AX
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4202H		;取文件长度
		INT	21H
		MOV	D_XX,AX 		;保存
		MOV	D_XX+2,DX
		XOR	CX,CX
		XOR	DX,DX
		MOV	AX,4200H		;移到文件首
		INT	21H

		MOV	DX,OFFSET D_FILE	;'File name is $'
		MOV	AH,9
		INT	21H
L_15:
		LODSB
		OR	AL,AL
		JZ	L_16
		CALL	S_XSAL			;显示文件名
		JMP	SHORT L_15
L_16:
		SUB	SI,4			;移扩展名首
		LODSB
		AND	AL,5FH
		CMP	AL,'C'                  ;判.COM文件?
		JNZ	L_17
		LODSB
		AND	AL,5FH
		CMP	AL,'O'
		JNZ	L_17
		LODSB
		AND	AL,5FH
		CMP	AL,'M'
		JNZ	L_17
		MOV	D_COM,1 		;置标志
L_17:
		CALL	S_XS2KG 		;显示双空格
		MOV	AX,D_XX+2
		CALL	S_HEXAX 		;显示段
		MOV	AL,':'
		CALL	S_XS1			;显示冒号
		MOV	AX,D_XX
		CALL	S_HEXAX 		;显示偏移
		CALL	S_0D0A			;回车换行
L_18:
		MOV	BX,D_HAN
		MOV	DX,OFFSET D_BUF
		MOV	CX,8000H
		MOV	AH,3FH			;读文件
		INT	21H
		MOV	D_LEN,AX		;读出长度
		ADD	AX,DX
		MOV	D_END,AX		;显示区尾
		JMP	SHORT L_31
L_20:
		MOV	SI,81H
L_21:
		LODSB
		CMP	AL,' '
		JBE	L_21
		CMP	BYTE PTR [SI],':'       ;判盘符?
		JNZ	L_23
		AND	AL,5FH
		CMP	AL,'A'
		JB	L_23
		CMP	AL,'Z'
		JBE	L_26
L_23:
		DEC	SI
		CALL	S_JSHEX 		;计算十六进制数-DX
		JB	L_23A
		CMP	AL,0DH			;判回车?
		JZ	L_24
		MOV	D_DX,DX 		;段
		CALL	S_JSHEX 		;计算十六进制数-DX
		JMP	SHORT L_25
L_23A:
		MOV	DX,OFFSET GSERR
		JMP	L_ERR
L_24:
		MOV	D_DX,0			;默认段=0
L_25:
		MOV	D_AX,DX 		;偏移
		MOV	SI,DX
		MOV	D_END,-1		;内存标志
		JMP	L_32
L_26:
		MOV	AL,DS:[5CH]		;取盘符
		DEC	AX
		ADD	D_BOOT1,AL
		MOV	BX,OFFSET D_BUF
		MOV	CX,1
		XOR	DX,DX
		INT	25H			;按老格式读BOOT
		POP	DX
		JNC	L_28
		MOV	D_CS,CS
		MOV	BX,OFFSET D_INT25
		MOV	CX,-1
		INT	25H			;按新格式读BOOT
		POP	DX
		JNC	L_28
		JMP	L_ERR1
L_28:
		MOV	DX,OFFSET D_BOOT1	;'A: disk BOOT:',13,10,'$'
L_30:
		MOV	AH,9
		INT	21H
L_31:
		MOV	D_DX,CS
		MOV	SI,OFFSET D_BUF 	;读出区首
L_32:
		CALL	S_XS8H			;显示八行
		CMP	CS:D_END,-1		;内存?
		JZ	L_33
		CMP	SI,D_END		;到读出区尾?
		JB	L_33
L_32A:
		CMP	D_HAN,0 		;判文件?
		JZ	L_40
		CMP	D_LEN,8000H		;判32K?
		JB	L_40
L_32B:
		MOV	AX,D_LEN		;读出长度
		ADD	D_AX,AX 		;地址指针
		ADC	D_DX,0
		JMP	L_18
L_33:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,8			;退格-上一128字节?
		JNZ	L_34
		CMP	SI,OFFSET D_BUF+80H	;判<=128
		JBE	L_33
		SUB	SI,100H 		;前移?
		JMP	SHORT L_32
L_34:
		CMP	AL,9			;跳格-下一1000H字节?
		JNZ	L_35
		ADD	SI,1000H		;后移
		CMP	CS:D_END,-1		;判内存?
		JZ	L_32
		CMP	SI,D_END		;到文件尾?
		JB	L_32
		JMP	SHORT L_32A
L_35:
		CMP	AL,'`'                  ;下一32K字节?
		JZ	L_32A
		CMP	AL,1BH			;判ESC?
		JZ	L_40
		JMP	SHORT L_32
L_40:
		XOR	AL,AL
L_EXIT:
		MOV	AH,4CH			;程序结束
		INT	21H
L_ERR:
		MOV	AH,9
		INT	21H
L_ERR1:
		MOV	AL,-1
		JMP	SHORT L_EXIT

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
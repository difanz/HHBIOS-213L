;	KEY.ASM
;	1994.2.5, 5.9
;	1996.9.12

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:
		MOV	SI,80H
		LODSB
		OR	AL,AL			;判无命令行参数?
		JNZ	L_20
L_8:
		MOV	AX,3529H
		INT	21H
		MOV	AL,1
		CMP	WORD PTR ES:[0AH],'OC'  ;判有ANSI?
		JNZ	L_10
		CMP	WORD PTR ES:[0CH],' N'
		JNZ	L_10
		MOV	DX,OFFSET D_KEY 	;送出键定义
		MOV	AH,9
		INT	21H
		XOR	AL,AL
L_10:
		MOV	AH,4CH
		INT	21H
L_20:
		CBW
		MOV	BX,AX
		MOV	BYTE PTR [BX+SI],0	;文件名尾
L_21:
		LODSB
		CMP	AL,' '
		JZ	L_21
		CMP	WORD PTR [SI-1],'?/'    ;判帮助?
		JNZ	L_25
		MOV	DX,OFFSET MSG
		MOV	AH,9
		INT	21H
		MOV	AL,-1
		JMP	SHORT L_10
L_25:
		MOV	BL,AL			;命令符
L_26:
		LODSB
		CMP	AL,' '
		JNZ	L_26
L_27:
		LODSB
		CMP	AL,' '
		JZ	L_27
		DEC	SI
		MOV	DX,SI			;文件名首

		CMP	BL,'1'                  ;判存键定义文件
		JNZ	L_40
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		JNB	L_30
		MOV	AL,2
		JMP	SHORT L_10
L_30:
		MOV	BX,AX
		MOV	SI,OFFSET D_KEY 	;键定义区
		XOR	BP,BP
L_31:
		LODSB
		CMP	AL,'$'                  ;判结束?
		JZ	L_32
		CMP	AL,1BH			;判ESC?
		JNZ	L_31
L_32:
		OR	BP,BP			;第一个?
		JZ	L_33
		PUSH	AX
		MOV	DX,BP			;上一个ESC地址
		MOV	CX,SI
		SUB	CX,BP
		DEC	CX			;串长
		MOV	AH,40H			;写入文件
		INT	21H
		MOV	DX,OFFSET DAH		;回车换行
		MOV	CX,2
		MOV	AH,40H			;写入文件
		INT	21H
		POP	AX
L_33:
		LEA	BP,[SI-1]		;保存ESC地址
		CMP	AL,'$'
		JNZ	L_31
		MOV	DX,OFFSET D_1A		;文件结束标志
		MOV	CX,1
		MOV	AH,40H			;写入文件
		INT	21H
		MOV	AH,3EH			;关闭文件
		INT	21H
		XOR	AL,AL
L_39:
		JMP	L_10
L_40:
		CMP	BL,'2'
		JNZ	L_39
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_41
		MOV	AL,4
		JMP	L_10
L_41:
		MOV	BX,AX
		MOV	DX,8000H		;读入区
		MOV	SI,DX
		MOV	CX,-1
		MOV	AH,3FH			;读文件
		INT	21H
		MOV	CX,AX
		MOV	AH,3EH			;关闭文件
		INT	21H
		OR	CX,CX
		JNZ	L_42
		MOV	AL,3
		JMP	L_10
L_42:
		MOV	DI,OFFSET D_KEY 	;键定义区
L_43:
		LODSB
		CMP	AL,0DH
		JZ	L_43
		CMP	AL,0AH
		JZ	L_43
		CMP	AL,1AH			;判结束?
		JZ	L_44
		STOSB
		JMP	SHORT L_43
L_44:
		MOV	BYTE PTR [DI],'$'       ;串结束符
		INC	DI

		MOV	DX,OFFSET KEYCOM
		MOV	AX,3D01H		;打开本文件KEY.COM
		INT	21H
		JNB	L_50
		MOV	AL,4
		JMP	L_10
L_50:
		MOV	BX,AX
		MOV	DX,100H
		MOV	CX,DI
		SUB	CX,DX
		MOV	AH,40H			;重写本文件
		INT	21H
		MOV	AH,3EH			;关闭
		INT	21H
		JMP	L_8			;执行定义

KEYCOM		DB	'KEY.COM',0
MSG		DB	'格式: KEY [n KEY定义文件]',13,10
		DB	'其中: n 为1 生成KEY定义文件',13,10
		DB	'      n 为2 用KEY定义文件生成KEY.COM',13,10
		DB	'键定义格式:ESC "[0;扫描码;带双引号的字符串 p',13,10
		DB	'ALT-扫描码: 16-Q W E R T Y U I O P-25',13,10
		DB	'             30-A S D F G H J K L-38',13,10
		DB	'              44-Z X C V B N M-50'
DAH		DB	13,10,'$'
D_1A		DB	1AH

D_KEY		DB	1BH,'[0;30;"AUTOEXEC.BAT"p'     ;ALT+A
		DB	1BH,'[0;48;"BUFFERS="p'         ;ALT+B
		DB	1BH,'[0;46;"COPY "p'            ;ALT+C
		DB	1BH,'[0;32;"DEVICE="p'          ;ALT+D
		DB	1BH,'[0;18;"EDIT "p'            ;ALT+E
		DB	1BH,'[0;33;"FORMAT A:"p'        ;ALT+F
		DB	1BH,'[0;23;"INSTALL"p'          ;ALT+I
		DB	1BH,'[0;38;"LINK "p'            ;ALT+L
		DB	1BH,'[0;50;"MASM "p'            ;ALT+M
		DB	1BH,'[0;24;"CONFIG.SYS"p'       ;ALT+O
		DB	1BH,'[0;25;"PROMPT "p'          ;ALT+P
		DB	1BH,'[0;19;"RAMDRIVE.SYS "p'    ;ALT+R
		DB	1BH,'[0;31;"SETUP"p'            ;ALT+S
		DB	1BH,'[0;20;"TYPE "p'            ;ALT+T
		DB	1BH,'[0;17;"WIN";13p'           ;ALT+W
		DB	1BH,'[0;45;"XCOPY "p'           ;ALT+X
		DB	'$'

SEG_A		ENDS
		END	START

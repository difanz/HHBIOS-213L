;	CSP.ASM 新格式双拼词组
;	1995.3.15
;	1996.1.29, 3.15, 3.31
;	1998.8.9

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

D_FILE1 	DB	'\SPCZ.DAT',0
D_END		DW	0			;双拼词组尾
D_NUM		DW	0			;双拼扩展词组数
WRITERR 	DB	'文件写错误!',7,13,10,'$'
NO213		DB	'不是 2.13L 汉字系统!',7,13,10,'$'
NOSPCZ		DB	'未安装双拼词组!',7,13,10,'$'

D_COMM		DB	'■ ESC-不存盘退出, 回车-显示扩展词组, 1-增加, 2-删除, 0-存盘退出 ■ $'
D_INPUT 	DB	'请键入扩展词组: $'
D_DEL		DB	'请键入删除词组序号: $'
D_INKEY 	DB	255,0,256 DUP(0)	;键入缓冲区
D_STR1		DB	'双拼扩展词组共 000 个:',13,10,'$'
D_XSNUM 	DB	'000:$'
D_MSG		DB	'2.13L 双拼扩展词组管理程序 1998.8.9',13,10,'$'

;****************************************************************************
BEGIN:
		XOR	BP,BP
		MOV	AH,2FH			;取2.13安装盘及路径BP:DX
		INT	16H
		OR	BP,BP			;判2.13L?
		JNZ	L_10
		MOV	DX,OFFSET NO213
		JMP	L_ERR
L_10:
		PUSH	DI
		MOV	DS,BP			;键盘模块段
		MOV	SI,DX			;
		MOV	DI,0A0H
L_12:
		LODSB				;取出路径
		OR	AL,AL
		JZ	L_20
		STOSB				;复制路径
		JMP	SHORT L_12
L_20:
		PUSH	CS
		POP	DS
		MOV	SI,OFFSET D_FILE1	;'\SPCZ.DAT',0
		MOV	CX,10
		REP	MOVSB			;形成文件全名
		POP	DI

		MOV	ES,BP
		MOV	BX,ES:[DI+18]		;双拼词组段
		OR	BX,BX			;=0:未安装?
		JNZ	L_22
		MOV	DX,OFFSET NOSPCZ
		JMP	L_ERR
L_22:
		MOV	DX,OFFSET D_MSG
		MOV	AH,9			;显示本程序名称
		INT	21H

		MOV	DS,BX			;双拼词组段
		PUSH	DS
		POP	ES
		CALL	S_CL			;双拼扩展词组处理
		JNB	L_25
		JMP	L_EXIT1
L_25:
		XOR	SI,SI
		MOV	AX,CS
		ADD	AX,1000H		;下一64K段
		MOV	ES,AX
		XOR	DI,DI
		MOV	CX,DS:[4]		;双拼词组234字词尾
		REP	MOVSB			;传送基本双拼词组
		XOR	AX,AX
		STOSW				;结束标志
		MOV	CS:D_END,DI		;尾
		PUSH	DS
		PUSH	ES
		POP	DS			;DS:0-处理区
		POP	ES			;ES:0-原SPCZ

		MOV	SI,ES:[4]		;扩展区首
L_30:
		CMP	SI,ES:[6]		;判扩展区尾?
		JNZ	L_31
		JMP	L_60
L_31:
		MOV	DX,ES:[SI]		;首字
		AND	DX,7F7FH
		MOV	BP,SI			;词首
L_32:
		INC	SI
		CMP	BYTE PTR ES:[SI],','    ;判词尾?                3.15
		JNZ	L_32
		MOV	BX,SI
		SUB	BX,BP

		CMP	BX,4			;判二字词?
		JNZ	L_40
		MOV	DI,16			;二字词首
L_33:
		CMP	DI,DS:[0]		;判二字词尾?
		JZ	L_37
		CMP	DX,DS:[DI]		;判首字?
		JZ	L_35
L_34:
		ADD	DI,2
		TEST	WORD PTR DS:[DI],8080H	;判下一首字?
		JNZ	L_34
		JMP	SHORT L_33
L_35:
		MOV	BX,2			;后移长度
		CALL	S_MOVE			;后移
L_36:
		ADD	DI,2
		MOV	AX,ES:[SI-2]		;取第二字
		MOV	DS:[DI],AX		;写入
		INC	SI
		JMP	SHORT L_30
L_37:
		MOV	BX,4
		CALL	S_MOVE			;后移4字节
		MOV	DS:[DI],DX		;增加首字
		JMP	SHORT L_36
L_40:
		CMP	BX,6			;判三字?
		JNZ	L_50
		MOV	DI,DS:[0]		;三字词首
L_42:
		CMP	DI,DS:[2]		;判三字词尾?
		JZ	L_46
		CMP	DX,DS:[DI]		;判首字?
		JZ	L_46
		ADD	DI,BX
		JMP	SHORT L_42
L_46:
		CALL	S_MOVE			;后移6字节
		MOV	DS:[DI],DX		;写入首字
		MOV	AX,ES:[SI-4]
		MOV	DS:[DI+2],AX		;写入第二字
		MOV	AX,ES:[SI-2]
		MOV	DS:[DI+4],AX		;写入第三字
		INC	SI
		JMP	L_30
L_50:
		OR	DX,8080H
		MOV	DI,DS:[2]		;多字词首
L_51:
		CMP	DI,DS:[4]		;判多字词尾?
		JZ	L_54
		CMP	DX,DS:[DI]		;判首字?
		JZ	L_54
L_52:
		CMP	BYTE PTR DS:[DI],','    ;判词尾?
		JZ	L_52A
		INC	DI
		JMP	SHORT L_52
L_52A:
		INC	DI
		JMP	SHORT L_51
L_54:
		INC	BX
		CALL	S_MOVE			;后移
		PUSH	SI			;8.7
		MOV	SI,BP			;词首
		DEC	BX
		MOV	CX,BX
		PUSH	DS
		PUSH	ES
		PUSH	DS
		PUSH	ES
		POP	DS
		POP	ES
		REP	MOVSB			;写入
		MOV	AL,','
		STOSB
		POP	ES
		POP	DS
		POP	SI			;8.7
		INC	SI
		JMP	L_30
L_60:
		MOV	AX,DS:[4]
		MOV	DS:[6],AX
		MOV	WORD PTR DS:[8],0
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,0A0H 		;文件名首
		MOV	CX,20H
		MOV	AH,3CH			;建立双拼词组文件
		INT	21H
		POP	DS
		JB	L_WERR
		MOV	BX,AX
		MOV	DX,0			;双拼词组文件首址
		MOV	CX,DS:[4]		;双拼词组尾
		SUB	CX,DX			;长度
		MOV	AH,40H			;写入
		INT	21H
		JB	L_WERR
		MOV	AH,3EH			;关闭
		INT	21H
		XOR	AL,AL
		JMP	SHORT L_EXIT
L_WERR:
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET WRITERR
L_ERR:
		MOV	AH,9
		INT	21H
L_EXIT1:
		MOV	AL,1
L_EXIT:
		MOV	AH,4CH
		INT	21H

;子程序:回车换行
S_0D0A		PROC	NEAR
		PUSH	AX
		MOV	AH,2
		MOV	DL,0DH
		INT	21H
		MOV	DL,0AH
		INT	21H
		POP	AX
		RET
S_0D0A		ENDP

;子程序:后移 BX-后移字节数,DI-插入点
S_MOVE		PROC	NEAR
		PUSH	SI
		PUSH	DI
		PUSH	ES
		PUSH	DS
		POP	ES
		MOV	SI,CS:D_END	;双拼词组尾
		MOV	CX,SI
		SUB	CX,DI		;传送长度
		INC	CX
		MOV	DI,SI
		ADD	DI,BX
		MOV	CS:D_END,DI
		STD
		REP	MOVSB		;后移
		CLD
		CMP	BX,8
		JAE	L_M2
		CMP	BX,6
		JZ	L_M1
		ADD	DS:[0],BX
L_M1:
		ADD	DS:[2],BX
L_M2:
		ADD	DS:[4],BX
		POP	ES
		POP	DI
		POP	SI
		RET
S_MOVE		ENDP

;子程序:双拼扩展词组处理
S_CL		PROC	NEAR
		XOR	CX,CX			;计数
		MOV	SI,DS:[4]		;扩展词组首
		MOV	DI,OFFSET D_BUF 	;扩展词组首址存放区
L_CL1:
		MOV	CS:[DI],SI
		ADD	DI,2
		CMP	SI,DS:[6]		;判尾?
		JZ	L_CL2A
		INC	CX
L_CL2:
		LODSB
		CMP	AL,','                  ;判词组尾?
		JNZ	L_CL2
		JMP	SHORT L_CL1
L_CL2A:
		MOV	WORD PTR CS:[DI],0	;8.7
		MOV	CS:D_NUM,CX		;个数
L_CL3:
		MOV	DX,OFFSET D_COMM
		CALL	S_XSZF			;显示提示
		XOR	AH,AH			;键入
		INT	16H
		PUSH	AX
		MOV	AH,2			;显示
		MOV	DL,AL
		INT	21H
		CALL	S_0D0A
		POP	AX

		CMP	AL,1BH			;ESC:不存盘退出
		JNZ	L_CL4
		STC
		RET
L_CL4:
		CMP	AL,0DH			;回车:显示扩展词组
		JNZ	L_CL5
L_CL4A:
		CALL	S_XSKZCZ		;显示扩展词组
		JMP	L_CL3
L_CL5:
		CMP	AL,'0'                  ;'0':存盘退出
		JNZ	L_CL6
		CLC
		RET
L_CL6:
		CMP	AL,'1'                  ;'1':增加
		JNZ	L_CL7
L_CL6A:
		MOV	DX,OFFSET D_INPUT
		CALL	S_XSZF			;提示:'请键入扩展词组: $'
		CALL	S_INPUT 		;键入词组并判别
		JNB	L_CL6B
		OR	CX,CX			;=0:无键入
		JNZ	L_CL6A
		JMP	L_CL3
L_CL6B:
		MOV	AX,DS:[6]		;扩展词组尾
		ADD	AX,CX			;+词长
		ADD	AX,3			;+逗号和2空格
		CMP	AX,DS:[8]		;判扩展词组区尾?
		JBE	L_CL6C
		MOV	AX,0E07H
		INT	10H
		JMP	L_CL3
L_CL6C:
		MOV	DI,DS:[6]		;原扩展词组尾
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	BX,D_NUM
		SHL	BX,1
		ADD	BX,OFFSET D_BUF
		MOV	[BX],DI 		;存词组首
		MOV	WORD PTR [BX+2],0	;8.7
		INC	D_NUM			;词组数+1

		MOV	SI,OFFSET D_INKEY+2	;键入词组首
		REP	MOVSB			;传送
		MOV	AL,','
		STOSB
		POP	DS
		MOV	DS:[6],DI		;新扩展词组尾
		XOR	AX,AX
		STOSW				;尾标志
		JMP	L_CL6A
L_CL7:
		CMP	AL,'2'                  ;'2':删除
		JZ	L_CL8
L_CL7A:
		JMP	L_CL3
L_CL8:
		CMP	CS:D_NUM,0
		JZ	L_CL7A
		MOV	DX,OFFSET D_DEL
		CALL	S_XSZF			;提示:请键入删除词组序号: $'
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_INKEY
		MOV	SI,DX
		MOV	AH,0AH			;键入
		INT	21H
		INC	SI
		LODSB				;取键入词组数
		OR	AL,AL			;=0无键入?
		JNZ	L_CL8A
		POP	DS
		JMP	L_CL3
L_CL8A:
		MOV	CX,10
L_CL8B:
		LODSB				;取一字符
		CMP	AL,0DH			;结束?
		JZ	L_CL8D
		SUB	AL,'0'
		CMP	AL,9
		JBE	L_CL8C
		SUB	AL,7
L_CL8C:
		XCHG	AL,CH
		MUL	CL
		ADD	CH,AL
		JMP	SHORT L_CL8B
L_CL8D:
		MOV	AL,CH			;删除序号
		XOR	AH,AH
		DEC	AX
		SHL	AX,1
		ADD	AX,OFFSET D_BUF
		MOV	BX,AX
		MOV	DI,[BX] 		;删除词首
		MOV	SI,[BX+2]		;下一词首
		MOV	AX,SI
		SUB	AX,DI			;删除词组长
L_CL8E:
		ADD	BX,2
		CMP	WORD PTR [BX],0
		JZ	L_CL8F
		MOV	DX,[BX]
		SUB	DX,AX
		MOV	[BX-2],DX
		JMP	SHORT L_CL8E
L_CL8F:
		MOV	WORD PTR [BX-2],0
		DEC	D_NUM
		CALL	S_0D0A
		POP	DS
		MOV	CX,DS:[6]		;原扩展词组尾
		ADD	CX,2
		SUB	CX,SI
		REP	MOVSB			;前移
		SUB	DI,2
		MOV	DS:[6],DI		;新扩展词组尾
		JMP	L_CL4A

;子程序:显示字符串DS:DX($结尾)
S_XSZF:
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	AH,9			;显示字符串
		INT	21H
		POP	DS
		RET
;子程序:显示字符串DS:SI($结尾.'0'不显示)
S_XSN0:
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	AH,2
L_N01:
		LODSB
		CMP	AL,'0'
		JNZ	L_N02
		CMP	BYTE PTR [SI],'0'
		JAE	L_N01
L_N02:
		CMP	AL,'$'
		JZ	L_N03
		MOV	DL,AL
		INT	21H
		JMP	SHORT L_N01
L_N03:
		POP	DS
		RET
S_XSKZCZ:
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	AX,D_NUM		;扩展词组数
		MOV	CX,AX
		MOV	BX,OFFSET D_STR1+17	;显示数个位
		MOV	DX,30AH
L_XS1:
		DIV	DL
		OR	AH,'0'
		MOV	[BX],AH
		XOR	AH,AH
		DEC	BX
		DEC	DH
		JNZ	L_XS1
		MOV	SI,OFFSET D_STR1
		CALL	S_XSN0			;显示
		MOV	AL,'0'
		MOV	D_XSNUM,AL
		MOV	D_XSNUM[1],AL
		MOV	D_XSNUM[2],AL
		POP	DS
		OR	CX,CX
		JZ	L_XS6
		MOV	DI,OFFSET D_BUF 	;各词首址
L_XS2:
		PUSH	DS
		PUSH	CS
		POP	DS
		INC	D_XSNUM[2]		;个位+1
		CMP	D_XSNUM[2],'9'
		JBE	L_XS3
		MOV	D_XSNUM[2],'0'
		INC	D_XSNUM[1]		;十位+1
		CMP	D_XSNUM[1],'9'
		JBE	L_XS3
		MOV	D_XSNUM[1],'0'
		INC	D_XSNUM 		;百位+1
L_XS3:
		MOV	SI,OFFSET D_XSNUM
		CALL	S_XSN0			;显示序号
		POP	DS
		MOV	SI,CS:[DI]
		ADD	DI,2
		MOV	AH,2
L_XS4:
		LODSB				;取词一字节
		CMP	AL,','                  ;结束?
		JZ	L_XS5
		MOV	DL,AL
		INT	21H			;显示
		JMP	SHORT L_XS4
L_XS5:
		MOV	DL,0DH			;回车
		INT	21H
		MOV	DL,0AH			;换行
		INT	21H
		LOOP	L_XS2
L_XS6:
		RET
S_CL		ENDP

;子程序:键入词组并判汉字
S_INPUT 	PROC	NEAR
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_INKEY
		MOV	SI,DX
		MOV	AH,0AH			;键入
		INT	21H
		INC	SI
		LODSB				;字符数
		XOR	AH,AH
		MOV	CX,AX
		OR	AX,AX			;判0?
		JNZ	L_IN1
L_IN0:
		POP	DS
		STC
		RET
L_IN1:
		CALL	S_0D0A
		MOV	BX,AX
		CMP	AL,6			;判2-3字词?
		JBE	L_IN2
		MOV	BL,6
L_IN2:
		CMP	BYTE PTR [BX+SI-1],0A0H ;判汉字?
		JBE	L_IN0
		DEC	BX
		JNZ	L_IN2

		CMP	CL,6
		JBE	L_IN3
		ADD	SI,CX			;指向词尾
		TEST	WORD PTR [SI-2],8080H	;判末字?
		JZ	L_IN0
L_IN3:
		POP	DS
		CLC
		RET
S_INPUT 	ENDP

D_BUF	EQU	$

SEG_A		ENDS
		END	START

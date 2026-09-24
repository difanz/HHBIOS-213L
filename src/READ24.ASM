;	READ24.ASM (L)
;	1997.7.31
;	1999.11.26

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

D_24T		DB	'HZK24T',34 DUP (0)
D_24S		DB	'HZK24S',34 DUP (0)
D_24F		DB	'HZK24F',34 DUP (0)
D_24H		DB	'HZK24H',34 DUP (0)
D_24K		DB	'HZK24K',34 DUP (0)

		ORG	200H
D_CHKS		DW	0			;常用字库区首
D_CHKW		DW	0			;	   尾
D_CHKC		DW	0			;存字区尾
D_CHKX		DW	0			;新字指针

D_DQSQ		DW	0			;当前扇区
D_DQZK		DW	0			;当前字库
D_ZFK		DW	OFFSET ZF00		;字符库首址 DS:20CH

D_ZX		DB	0			;字型
D_DH		DB	0			;前字节
D_SX		DB	0			;属性
D_HS		DB	0			;行数

;中断入口:AH=字型,BH=行数,DX=汉字内码(字符DH=0)
;BL=属性:位0-反白,位1-下划,位2-上划,位3-左旋,位4-右旋,位5-上标,位6-下标,位7-倒转
;返回:DS:SI=点阵首地址,CX=列数(每列3字节)

		DB	'24'                    ;驻留标志
INT_7B		PROC	FAR
		STI
		CLD
		PUSH	ES
		PUSH	DI
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	D_ZX,AH 		;字型
		MOV	D_DH,DH 		;前字节
		MOV	WORD PTR D_SX,BX	;属性及行数

		OR	DH,DH			;判汉字
		JNZ	L_10
		AND	DL,7FH
		MOV	AL,36			;每字符36字节
		MUL	DL
		ADD	AX,D_ZFK		;+字符点阵区首
		MOV	SI,AX			;指定字符点阵
		MOV	CX,12
		JMP	L_50
L_10:	;取汉字字体
		MOV	AL,AH
		AND	AL,0F0H
		CMP	AL,10H			;判隔点扩?
		JNZ	L_12
		SHL	AH,1			;位01移位23
		SHL	AH,1
L_12:
		TEST	AH,20H			;判字体
		JNZ	L_14
		AND	DH,7FH
L_14:
		TEST	AH,10H
		JNZ	L_20
		AND	DL,7FH
L_20:
		CALL	S_GET			;取得汉字点阵DS:SI

		MOV	CX,24
	;旋转处理
		CMP	D_DH,0A9H		;判九区?
		JZ	L_50
		TEST	D_SX,8			;左旋?
		JZ	L_40
		XOR	DI,DI
		ADD	SI,45H
		MOV	CL,3
L_32:
		PUSH	CX
		MOV	CL,8
L_34:
		PUSH	SI
		MOV	DH,3
L_36:
		MOV	DL,8
L_38:
		MOV	AL,[SI]
		SHR	AL,CL
		RCL	BL,1
		SUB	SI,3
		DEC	DL
		JNZ	L_38
		MOV	AL,BL
		STOSB
		DEC	DH
		JNZ	L_36
		POP	SI
		LOOP	L_34
		INC	SI
		POP	CX
		LOOP	L_32
		XOR	SI,SI
		MOV	CL,24
		JMP	SHORT L_60
L_40:
		TEST	D_SX,10H		  ;右旋?
		JZ	L_50
		XOR	DI,DI
		INC	SI
		INC	SI
		MOV	CL,3
L_42:
		PUSH	CX
		MOV	CL,8
L_44:
		PUSH	SI
		MOV	DH,3
L_46:
		MOV	DL,8
L_48:
		MOV	AL,[SI]
		SHL	AL,CL
		RCL	BL,1
		ADD	SI,3
		DEC	DL
		JNZ	L_48
		MOV	AL,BL
		STOSB
		DEC	DH
		JNZ	L_46
		POP	SI
		LOOP	L_44
		DEC	SI
		POP	CX
		LOOP	L_42
		XOR	SI,SI
		MOV	CL,24
		JMP	SHORT L_60
L_50:	;点阵传送到DS:0
		OR	SI,SI
		JZ	L_60
		PUSH	CX
		MOV	AX,CX
		SHL	AX,1
		ADD	CX,AX
		XOR	DI,DI
		REP	MOVSB
		XOR	SI,SI
		POP	CX
L_60:
		TEST	D_SX,80H		;倒转?
		JZ	L_63
		MOV	DI,80H+72-3		;1.12
		PUSH	CX
L_61:
		LODSB
		CALL	S_FW			;反位
		MOV	[DI+2],AH
		LODSB
		CALL	S_FW			;反位
		MOV	[DI+1],AH
		LODSB
		CALL	S_FW			;反位
		MOV	[DI],AH
		SUB	DI,3
		DEC	CL
		JNZ	L_61
		POP	CX
		MOV	SI,80H
		AND	D_SX,7FH
		JMP	SHORT L_50
L_63:
		TEST	D_SX,20H		;上标?
		JZ	L_70
		PUSH	CX
		XOR	DI,DI
L_64:
		LODSW
		CALL	S_YS			;压缩
		LODSB
		XOR	AH,AH
		CALL	S_YS			;压缩
		XOR	AL,AL
		STOSB
		LOOP	L_64
		POP	CX
		XOR	SI,SI
		JMP	SHORT L_80
L_70:
		TEST	D_SX,40H		;下标?
		JZ	L_80
		PUSH	CX
		MOV	DI,80H
L_74:
		XOR	AL,AL
		STOSB
		LODSB
		XOR	AH,AH
		CALL	S_YSAX			;压缩
		LODSW
		CALL	S_YS			;压缩
		LOOP	L_74
		POP	CX
		MOV	SI,80H
		AND	D_SX,0BFH
		JMP	L_50
L_80:
		TEST	D_SX,2			;上划线?
		JZ	L_90
		PUSH	CX
		XOR	BX,BX
L_84:
		OR	BYTE PTR [BX],80H
		ADD	BX,3
		LOOP	L_84
		POP	CX
L_90:
		TEST	D_SX,4			;下划线?
		JZ	L_100
		PUSH	CX
		MOV	BX,2
L_94:
		OR	BYTE PTR [BX],1
		ADD	BX,3
		LOOP	L_94
		POP	CX
L_100:
		MOV	AL,D_ZX
		AND	AL,0F0H
		CMP	AL,10H			;隔点扩?
		JNZ	L_104
		TEST	D_ZX,3			;不扩展?
		JNZ	L_110
		XOR	BX,BX
		XOR	DI,DI
L_102:
		LODSB
		STOSB
		LODSW
		STOSW
		INC	BX
		LODSB
		OR	AL,[SI+2]
		STOSB
		LODSW
		OR	AX,[SI+1]
		STOSW
		INC	BX
		ADD	SI,3
		DEC	CX
		DEC	CX
		LOOP	L_102
		MOV	CX,BX
		XOR	SI,SI
		JMP	L_140
L_104:
		JMP	L_150
L_110:
		TEST	D_ZX,2			;纵扩?
		JZ	L_130
		XOR	DI,DI
		CMP	D_HS,1			;上半行?
		JNZ	L_120
		PUSH	CX
L_112:
		LODSB
		XOR	AH,AH
		CALL	S_K24			;扩24
		ADD	SI,2
		LOOP	L_112
		POP	CX
		XOR	SI,SI
		JMP	SHORT L_130
L_120:
		PUSH	CX			;下半行
L_122:
		INC	SI
		LODSW
		XCHG	AL,AH
		CALL	S_K24			;扩24
		LOOP	L_122
		POP	CX
		XOR	SI,SI
L_130:
		TEST	D_ZX,1			;横扩?
		JZ	L_140
		XOR	BX,BX
		MOV	DI,80H
L_132:
		LODSB
		STOSB
		LODSW
		STOSW
		INC	BX
		LODSB
		STOSB
		MOV	[DI+2],AL
		LODSW
		STOSW
		MOV	[DI+1],AX
		INC	BX
		INC	BX
		ADD	DI,3
		DEC	CX
		LOOP	L_132
		MOV	SI,80H
		MOV	CX,BX
L_140:
		AND	D_ZX,0F0H
L_150:
		MOV	AH,D_ZX 		;恢复字型
		POP	DI
		POP	ES
		IRET
INT_7B		ENDP

;子程序:字节反位AL->AH
S_FW		PROC	NEAR
		MOV	CH,8
L_FW1:
		SHR	AL,1
		RCL	AH,1
		DEC	CH
		JNZ	L_FW1
		RET
S_FW		ENDP

;子程序:AL:AH压缩
S_YS		PROC	NEAR
		XCHG	AL,AH
;子程序:AX压缩为8位->ES:DI
S_YSAX:
		MOV	DL,8
L_YS1:
		SHL	AX,1
		JNB	L_YS2
		RCL	BL,1
		SHL	AX,1
		JMP	SHORT L_YS3
L_YS2:
		SHL	AX,1
		RCL	BL,1
L_YS3:
		DEC	DL
		JNZ	L_YS1
		MOV	AL,BL
		STOSB
		RET
S_YS		ENDP

;子程序:AX扩3字节->ES:DI
S_K24		PROC	NEAR
		PUSH	CX
		MOV	BX,AX
		MOV	CL,5
		CALL	S_K24A
		PUSH	BX
		RCL	BX,1
		RCL	AX,1
		PUSH	AX
		MOV	AL,AH
		STOSB
		POP	AX
		STOSB
		POP	BX
		XOR	AX,AX
		RCL	BX,1
		RCL	AL,1
		RCL	BX,1
		RCL	AL,1
		MOV	CL,2
		CALL	S_K24A
		STOSB
		POP	CX
		RET
;子程序:AX<-BX扩1位移1位共CX次
S_K24A:
		RCL	BX,1
		PUSHF
		RCL	AX,1
		POPF
		RCL	AX,1
		RCL	BX,1
		RCL	AX,1
		LOOP	S_K24A
		RET
S_K24		ENDP

	INCLUDE ZF00.INC
	INCLUDE ZF3.INC

;子程序:取得汉字点阵 DX=变形汉字内码,返回:SI=汉字点阵地址
S_GET		PROC	NEAR
		MOV	SI,D_CHKS		;常用字库区首
		JMP	SHORT L_GET2
L_GET1:
		ADD	SI,72
L_GET2:
		CMP	SI,D_CHKC		;判存字区尾?
		JNZ	L_GET5
		CALL	S_READ			;读字库

		CMP	DI,D_CHKC		;判写入地址>常用字库存字区尾?
		JBE	L_GET3
		MOV	D_CHKC,DI
L_GET3:
		CMP	DI,D_CHKW		;判写入地址=常用字库区尾?
		JNZ	L_GET4
		MOV	DI,D_CHKS
L_GET4:
		MOV	D_CHKX,DI		;存写入地址
		RET
L_GET5:
		LODSW				;取常用字库汉字码?
		CMP	AX,DX			;判?
		JNZ	L_GET1
		RET
S_GET		ENDP

D_T		DW	OFFSET D_BUFF		;T库区
D_512		DW	0			;扇区字节数
D_440		DW	0			;扇区字节数-72
D_S		DW	0			;S库
D_F		DW	0			;F库
D_H		DW	0			;H库
D_K		DW	0			;K库
D_SECD		DW	0			;每道扇区数
D_CTS		DW	0			;磁头数
D_DQP		DB	2			;当前盘
D_SSEC		DW	0			;分区首扇区号
D_SCZH		DW	0			;      磁柱号
;	DS:[0F0H]				;每簇扇区数
;	DS:[0F4H]				;文件区首扇区号
;	DS:[0F6H]				;连续块计数
;	DS:[0F8H]				;第一FAT表段
;	DS:[0FAH]				;第二FAT表段
;	DS:[0FFH]				;分区标志(1=12位,其他16位)

;子程序:读字库
S_READ		PROC	NEAR
		MOV	DI,D_CHKX		;新字指针
		MOV	AX,DX
		STOSW				;写入
		PUSH	DI
		PUSH	AX
		AND	AH,7FH
		CMP	AH,30H			;判16区?
		POP	AX
		JNB	L_R1
		MOV	AX,D_T			;T库
		JMP	SHORT L_R2
L_R1:
		SUB	DH,15
		XOR	BX,BX
		SHL	AH,1
		RCL	BX,1
		SHL	AL,1
		RCL	BX,1
		SHL	BX,1
		MOV	AX,D_S[BX]		;取相应库
L_R2:
		MOV	D_DQZK,AX		;当前库
		AND	DX,7F7FH
		SUB	DX,2121H
		MOV	AL,94
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX			;汉字序号
		MOV	DX,72
		MUL	DX			;字节位置
		DIV	D_512			;扇区字节数
		PUSH	DX
		MOV	D_DQSQ,AX		;当前扇区号
		CALL	S_READSEC		;读扇区
		POP	SI
		MOV	CX,72
		CMP	SI,D_440		;与扇区字节数-72比
		JB	L_R3
		MOV	CX,D_512		;扇区字节数
		SUB	CX,SI
L_R3:
		POP	DI
		PUSH	DI
		PUSH	CX
		REP	MOVSB			;传送
		POP	CX
		CMP	CX,72			;判是否读完?
		JZ	L_R4
		PUSH	CX
		PUSH	DI
		MOV	AX,D_DQSQ		;当前扇区
		INC	AX			;下一扇区
		CALL	S_READSEC		;读扇区
		POP	DI
		POP	AX
		XOR	SI,SI
		MOV	CX,72
		SUB	CX,AX
		REP	MOVSB			;传送
L_R4:
		POP	SI
		RET
;子程序:读扇区 AX=顺序号
S_READSEC:
		MOV	BX,D_DQZK		;当前库
L_RS1:
		CMP	AX,[BX+4]
		JB	L_RS2
		SUB	AX,[BX+4]
		ADD	BX,6
		JMP	SHORT L_RS1
L_RS2:
		MOV	DX,[BX+2]
		ADD	AX,[BX]
		ADC	DX,0
		DIV	D_SECD			;每道扇区数
		ADD	DX,D_SSEC		;加分区首扇区号
		CMP	DX,D_SECD
		JBE	L_RS3
		MOV	DL,1
		INC	AX
L_RS3:
		MOV	CL,DL			;扇区号
		XOR	DX,DX
		DIV	D_CTS			;磁头数
		MOV	DH,DL
		ADD	AX,D_SCZH		;加分区首磁柱号
		MOV	CH,AL			;磁柱号
		MOV	AL,40H
		MUL	AH			;AH左移6位
		ADD	CL,AL			;加到CL上
		MOV	DL,80H
		XOR	BX,BX
		MOV	AX,201H
		INT	13H			;读扇区
		RET
S_READ		ENDP

D_BUFF		EQU	$

		ORG	$+400H
;****************************************************************************
BEGIN:
		MOV	AX,357BH		;取INT7B中断
		INT	21H
		CMP	WORD PTR ES:[BX-2],'42' ;判安装?
		JNZ	L_S10
		MOV	DX,OFFSET ALREADY
L_ERR:
		MOV	AH,9
		INT	21H
		MOV	AX,4C01H
		INT	21H
L_S10:
		PUSH	CS
		POP	ES
		MOV	AH,19H			;取当前盘
		INT	21H
		ADD	CUR_DRIVE,AL
		MOV	FCB_DRIVE,AL
		INC	AL
		MOV	DL,AL
		MOV	SI,OFFSET CUR_PATH
		MOV	AH,47H			;取当前路径->DS:SI
		INT	21H

		CALL	S_GETPATH		;取本程序所在路径

		MOV	SI,5DH
		MOV	AX,CS
		CMP	AX,0A000H		;判LH
		JB	L_S11
		MOV	SI,6DH
L_S11:
		LODSB
		AND	AL,5FH
		MOV	DS:[101H],AL		;保存
		PUSH	SI
		LODSB				;'S'
		CMP	BYTE PTR [SI],' '
		JZ	L_S12
		LODSB				;'F'
		CMP	BYTE PTR [SI],' '
		JZ	L_S13
		LODSB				;'H'
		CMP	BYTE PTR [SI],' '
		JZ	L_S14
		JMP	SHORT L_S15
L_S12:
		MOV	[SI],AL
		INC	SI
L_S13:
		MOV	[SI],AL
		INC	SI
L_S14:
		MOV	[SI],AL
L_S15:
		POP	SI

		CMP	BYTE PTR DS:[101H],'W'  ;='W':用文件方式读字库?
		JZ	L_S18
		JMP	L_S40
L_S18:	;READ24W-------------------------------------------------------------
		LODSB
		MOV	F_24S+5,AL
		LODSB
		MOV	F_24F+5,AL
		LODSB
		MOV	F_24H+5,AL
		LODSB
		MOV	F_24K+5,AL

		MOV	SI,OFFSET F_24T 	;源文件名
		MOV	DI,OFFSET D_24T 	;工作文件名
		MOV	BP,5
L_S24:
		PUSH	DI
		PUSH	SI
		MOV	SI,OFFSET F_S
		CALL	S_MOVE			;复制路径
		DEC	DI
		MOV	AL,'\'
		STOSB
		POP	SI
		CALL	S_MOVE			;复制文件名
		POP	DI
		ADD	DI,40
		DEC	BP
		JNZ	L_S24

		MOV	DX,OFFSET D_24T
		MOV	AX,4300H		;取T库属性
		INT	21H
		JNB	L_S33
L_S31:
		MOV	AX,4CFFH
		INT	21H
L_S33:
		MOV	DX,OFFSET D_24S
		MOV	AX,4300H		;取S库属性
		INT	21H
		JB	L_S31
		MOV	DX,OFFSET D_24F
		MOV	AX,4300H		;取F库属性
		INT	21H
		JB	L_S31
		MOV	DX,OFFSET D_24H
		MOV	AX,4300H		;取H库属性
		INT	21H
		JB	L_S31
		MOV	DX,OFFSET D_24K
		MOV	AX,4300H		;取K库属性
		INT	21H
		JB	L_S31

		MOV	SI,OFFSET S_GET1
		MOV	DI,OFFSET S_GET
		MOV	CX,OFFSET K_GET1
		SUB	CX,SI
		REP	MOVSB			;复制READ24W取点阵子程序
		MOV	D_CHKS,DI		;读出缓冲区首		10.29
		ADD	DI,72
		MOV	BP,DI			;驻留地址
		JMP	L_S100

L_S40:	;READ24--------------------------------------------------------------
		MOV	DL,FCB_DRIVE
		INC	DL
		MOV	AH,36H			;取磁盘信息
		INT	21H
		CMP	AX,-1			;此盘不存在?
		JNZ	L_S41
		JMP	L_S73			;驻留空中断
L_S41:
		CMP	AX,4			;<4:虚拟盘或光盘?
		JAE	L_S42
		JMP	L_S18			;用文件方式
L_S42:
		MOV	DI,OFFSET F_S		;本程序路径
		MOV	DL,[DI] 		;取盘符
		AND	DL,5FH
		SUB	DL,'A'

		CMP	DL,1			;判硬盘?
		JA	L_S46
L_S44:
		MOV	DX,OFFSET NOPATH	;'字库不在!'
		JMP	L_ERR
L_S46:
		MOV	AH,0EH			;置当前盘
		INT	21H
L_S48:
		MOV	DX,DI
		MOV	AH,3BH			;置字库路径
		INT	21H
		JB	L_S44
L_S50:
		MOV	AH,19H			;取当前盘
		INT	21H
		MOV	D_DQP,AL		;当前盘号
		INC	AL
		MOV	D_FCB,AL

		MOV	AX,201H 		;读C盘总引导区
		MOV	BX,OFFSET D_BUF+100H
		MOV	CX,1
		MOV	DX,80H
		PUSH	CX
		INT	13H
		POP	CX

		DEC	D_DQP
L_S52:
		DEC	D_DQP
		JZ	L_S54
		CALL	READBOOT		;读下一分区BOOT
		JMP	SHORT L_S52
L_S54:
		PUSH	CX
		MOV	DL,CH			;磁柱号低8位
		XOR	CH,CH
		SHL	CX,1			;磁柱号高2位移CH
		SHL	CX,1
		MOV	DH,CH
		POP	CX
		AND	CX,3FH
		MOV	D_SSEC,CX		;分区首扇区号
		MOV	D_SCZH,DX		;      磁柱号

		MOV	SI,1BEH
L_S56:
		MOV	AL,DS:[BX+SI+4]
		CMP	AL,1			;判12位FAT DOS分区
		JZ	L_S58
		CMP	AL,4			;判16位FAT DOS分区
		JZ	L_S58
		CMP	AL,6			;判大硬盘DOS分区
		JZ	L_S58
		ADD	SI,10H
		JMP	SHORT L_S56
L_S58:
		MOV	DS:[0FFH],AL
		MOV	CX,[BX+SI+2]
		MOV	DX,[BX+SI]
		OR	DL,80H
		MOV	AX,201H
		PUSH	CX
		INT	13H			;读DOS引导扇区
		POP	CX

		PUSH	DX
		MOV	AX,[BX+0BH]		;扇区字节数
		MOV	D_512,AX
		SUB	AX,72
		MOV	D_440,AX
		MOV	AX,[BX+18H]		;每道扇区数
		MOV	D_SECD,AX
		MOV	AX,[BX+1AH]		;磁头数
		MOV	D_CTS,AX
		MOV	AL,[BX+0DH]		;每簇扇区数
		XOR	AH,AH
		MOV	DS:[0F0H],AX
		MOV	AX,[BX+16H]		;FAT扇区数
		MUL	BYTE PTR [BX+10H]	;*FAT个数
		ADD	AX,[BX+0EH]		;+保留扇区数
		ADD	AX,[BX+1CH]		;+隐含扇区数
		MOV	DS:[0F4H],AX		;目录区扇区号
		MOV	AX,20H
		MUL	WORD PTR [BX+11H]	;根目录项数
		DIV	D_512			;=根目录扇区数
		ADD	DS:[0F4H],AX		;=文件区首扇区号
		POP	DX

		MOV	AX,CS
		CMP	AX,0A000H		;判UMB?
		JB	L_S62
		PUSH	BX
		MOV	AH,52H			;取DOS内部表
		INT	21H
		MOV	AX,ES:[BX-2]		;内存控制链首段
		POP	BX
L_S60:
		MOV	ES,AX
		INC	AX
		ADD	AX,ES:[3]
		CMP	AX,7000H
		JB	L_S60
		SUB	AX,ES:[3]		;基本内存自由块
L_S62:
		ADD	AX,1000H
		MOV	DS:[0F8H],AX
		MOV	ES,AX
		ADD	AX,1000H
		MOV	DS:[0FAH],AX

		MOV	AX,[BX+16H]		;每FAT扇区数
		PUSH	AX
		CMP	AX,80H			;		4.8
		JBE	L_S64
		MOV	AL,80H
L_S64:
		XOR	BX,BX
		INC	CX
		MOV	AH,2
		PUSH	CX
		INT	13H			;读FAT
		POP	CX
		ADD	CL,80H
		MOV	AL,CL
		XOR	AH,AH
		DIV	BYTE PTR D_SECD 	;每道扇区数
		MOV	CL,AH
		ADD	AL,DH
		XOR	AH,AH
		DIV	BYTE PTR D_CTS		;磁头数
		MOV	DH,AH
		ADD	CH,AL

		POP	AX
		CMP	AX,80H			;		   4.8
		JBE	L_S70
		SUB	AL,80H
		MOV	ES,DS:[0FAH]
		XOR	BX,BX
		MOV	AH,2
		INT	13H
L_S70:
		MOV	SI,5DH
		MOV	AX,CS
		CMP	AX,0A000H		;判LH	4.8
		JB	L_S72
		MOV	SI,6DH
L_S72:
		LODSB
		MOV	DS:[100H],AL		;常用字库区大小

		MOV	ES,DS:[0F8H]		;指向FAT首
		MOV	BP,D_T			;T库
		CALL	S_SET1
		JNC	L_S74
L_S73:
		CALL	S_HF			;恢复当前盘和路径
		MOV	AX,4CFFH
		INT	21H
L_S74:
		MOV	D_S,BP			;S库
		LODSB
		CALL	S_SET
		JC	L_S73
		MOV	D_F,BP			;F库
		LODSB
		CALL	S_SET
		MOV	D_H,BP			;H库
		LODSB
		CALL	S_SET
		MOV	D_K,BP			;K库
		LODSB
		CALL	S_SET
		MOV	D_CHKS,BP		;9.25
		MOV	D_CHKC,BP
		MOV	D_CHKX,BP

		MOV	AL,DS:[100H]
		CMP	AL,'A'
		JB	L_S80
		SUB	AL,7
L_S80:
		SUB	AL,'0'
		XOR	AH,AH
		MOV	DX,50*74		;50字×74字节
		MUL	DX
		ADD	AX,D_CHKS
		MOV	D_CHKW,AX
		INC	AX
		MOV	BP,AX			;BP:驻留地址

L_S100: ;驻留处理------------------------------------------------------------
		MOV	AX,CS
		CMP	AX,0A000H		;判LH?
		JA	L_S130
		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_S120
L_S110:
		LODSB
		CMP	AL,0DH
		JZ	L_S120
		CMP	AL,'/'
		JNZ	L_S110
		LODSB
		AND	AL,5FH
		CMP	AL,'N'                  ;/N:驻留基本内存
		JNZ	L_S110
		JMP	SHORT L_S130
L_S120:
		CALL	S_GETUMB		;分配UMB段
		JZ	L_S140
L_S130:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		CALL	S_SETINT
		MOV	DX,BP			;驻留
		INT	27H
L_S140:
		MOV	AX,D_UMB
		OR	AX,AX
		JZ	L_S130
		DEC	AX
		MOV	ES,AX
		MOV	DI,8
		MOV	SI,OFFSET D_NAME
		MOV	CX,7
		REP	MOVSB		       ;向UMB文件控制块写入本模块名

		MOV	ES,D_UMB		;段
		XOR	SI,SI
		MOV	DI,SI
		MOV	CX,BP			;			10.29
		REP	MOVSB			;拷贝本模块到UMB
		PUSH	ES
		POP	DS

		CALL	S_SETINT

		PUSH	CS
		POP	DS
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		PUSH	CS
		POP	ES
		MOV	AH,49H			;清本模块
		INT	21H

		MOV	AH,50H			;设置新PSP
		MOV	BX,D_UMB
		INT	21H
		MOV	DX,D_LEN		;本模块长度(节)
		MOV	AX,3100H		;驻留
		INT	21H

D_XMS		DD	0			;XMS驱动地址
D_NCFP		DW	0			;原内存分配策略
D_UMB0		DW	0			;原UMB连接状态
D_UMB		DW	0			;分配UMB段
D_LEN		DW	0			;本模块长度(节)

;子程序:取UMB段
S_GETUMB	PROC	NEAR
		CALL	S_GETXMS		;取XMS驱动地址
		JNZ	L_GU2
		MOV	AX,BP
		MOV	CL,4
		SHR	AX,CL
		INC	AX
		MOV	D_LEN,AX		;本模块驻留长度(节)

		MOV	AH,10H			;请求UMB
		CALL	D_XMS			;XMS
		CMP	AX,1			;=1:成功,BX=段
		JZ	L_GU1
		CALL	S_UMB			;分配UMB段BX
		CMP	AL,AL			;ZF=1
		RET
L_GU1:
		MOV	D_UMB,BX		;取出UMB段
L_GU2:
		RET
S_GETUMB	ENDP

S_UMB		PROC	NEAR
		MOV	AX,3000H		;取DOS版本号
		INT	21H
		CMP	AL,5			;判>5.0
		JB	L_UMB3
		MOV	AX,5800H		;取内存分配策略AX
		INT	21H
		MOV	D_NCFP,AX
		MOV	AX,5802H		;取UMB连接状态AL
		INT	21H
		CBW
		MOV	D_UMB0,AX

		MOV	AX,5803H		;置UMB连接
		MOV	BX,1			;=1连接
		INT	21H
		JC	L_UMB3
		MOV	AX,5801H		;置内存分配策略
		MOV	BX,41H			;最佳适合块
		INT	21H
		JC	L_UMB2
		MOV	AH,48H			;分配内存
		MOV	BX,D_LEN
		INT	21H
		JC	L_UMB1
		MOV	D_UMB,AX		;分配块段
L_UMB1:
		MOV	AX,5801H		;恢复内存分配策略
		MOV	BX,D_NCFP
		INT	21H
L_UMB2:
		MOV	BX,D_UMB0
		MOV	AX,5803H		;恢复UMB连接状态
		INT	21H
L_UMB3:
		RET
S_UMB		ENDP

;子程序:取XMS驱动地址 ->D_XMS
S_GETXMS	PROC	NEAR
		MOV	AX,4300H		;取XMS安装状态
		INT	2FH
		CMP	AL,80H			;=80H:已安装
		JNZ	L_GX1
		MOV	AX,4310H		;取XMS驱动地址
		INT	2FH
		MOV	WORD PTR D_XMS,BX	;保存
		MOV	WORD PTR D_XMS+2,ES
		CMP	AL,AL			;返回ZF=1
L_GX1:
		RET
S_GETXMS	ENDP

S_SETINT	PROC	NEAR
		MOV	DX,OFFSET INT_7B
		MOV	AX,257BH		;建中断
		INT	21H
		CALL	S_HF			;恢复当前盘和路径
		RET
S_SETINT	ENDP

;READ24用--------------------------------------------------------------------
;〖子程序:恢复当前盘及路径〗
S_HF		PROC	NEAR
		PUSH	CS			;			6.18
		POP	DS
		MOV	DX,OFFSET CUR_DRIVE
		MOV	AH,3BH			;置当前路径
		INT	21H
		MOV	DL,FCB_DRIVE
		MOV	AH,0EH			;置当前盘
		INT	21H
		RET
S_HF		ENDP

;子程序:置字库名
S_SET		PROC	NEAR
		MOV	D_FCB+6,AL
;子程序:建字库连续扇区表
S_SET1:
		MOV	DX,OFFSET D_BUF
		MOV	DI,DX
		MOV	AH,1AH			;置DTA地址
		INT	21H
		MOV	DX,OFFSET D_FCB
		MOV	AH,11H			;查找目录项
		INT	21H
		OR	AL,AL
		JZ	L_SET1
		STC
		RET
L_SET1:
		MOV	AX,[DI+1BH]		;首簇号
		PUSH	AX
		SUB	AX,2
		MUL	WORD PTR DS:[0F0H]	;每簇扇区数
		ADD	AX,DS:[0F4H]		;文件区首扇区号
		ADC	DX,0
		MOV	DS:[BP],AX		;首项
		MOV	DS:[BP+2],DX
		POP	AX
		MOV	WORD PTR DS:[0F6H],0	;清连续块数计数器
L_SET2:
		PUSH	AX
		INC	WORD PTR DS:[0F6H]	;连续块数+1
		MOV	BX,AX
		CMP	BYTE PTR DS:[0FFH],1	;判12位FAT?
		JZ	L_SET4
		MOV	ES,DS:[0F8H]
		ADD	BX,AX
		JNC	L_SET3
		MOV	ES,DS:[0FAH]
L_SET3:
		MOV	AX,ES:[BX]
		CMP	AX,0FFF8H
		JMP	SHORT L_SET7
L_SET4:
		SHR	AX,1
		PUSHF
		ADD	BX,AX
		MOV	AX,ES:[BX]
		POPF
		JNB	L_SET5
		MOV	CL,4
		SHR	AX,CL
		JMP	SHORT L_SET6
L_SET5:
		AND	AX,0FFFH
L_SET6:
		CMP	AX,0FF8H
L_SET7:
		POP	BX
		JB	L_SET8			;判结束?
		MOV	AX,0FFFFH
		MOV	DS:[BP+4],AX		;尾块标志
		ADD	BP,6
		CLC
		RET
L_SET8:
		INC	BX
		CMP	AX,BX			;判连续?
		JZ	L_SET2
		PUSH	AX
		MOV	AX,DS:[0F0H]		;每簇扇区数
		MUL	WORD PTR DS:[0F6H]	;*连续簇数
		MOV	DS:[BP+4],AX
		MOV	WORD PTR DS:[0F6H],0	;清
		MOV	AX,DS:[0F0H]
		POP	BX
		PUSH	BX
		SUB	BX,2
		MUL	BX
		ADD	AX,DS:[0F4H]
		ADC	DX,0
		ADD	BP,6
		MOV	DS:[BP],AX
		MOV	DS:[BP+2],DX
		POP	AX
		JMP	SHORT L_SET2
S_SET		ENDP

;子程序:读下一分区BOOT
READBOOT	PROC	NEAR
		MOV	SI,1BEH 		;分区表首
L_RB1:
		CMP	BYTE PTR [BX+SI+4],5	;判扩展分区
		JZ	L_RB2
		ADD	SI,10H			;转下一分区
		JMP	SHORT L_RB1
L_RB2:
		MOV	CX,[BX+SI+2]
		MOV	DX,[BX+SI]
		OR	DL,80H
		MOV	AX,201H
		INT	13H			;读下一分区BOOT
		RET
READBOOT	ENDP

FCB_DRIVE	DB	2
CUR_DRIVE	DB	'A:\'
CUR_PATH	DB	64 DUP(0)

D_FCB		DB	3,'HZK24T     ',25 DUP(0)    ;字库FCB

;READ24W用-------------------------------------------------------------------
;子程序:读字库 DX=变形汉字内码,返回:SI=汉字点阵地址
S_GET1		PROC	NEAR
		CMP	DX,D_DQSQ		;判上次已读出?
		JZ	L_GET13
		MOV	AH,62H			;取当前PSP		10.29
		INT	21H
		PUSH	BX
		MOV	AX,DX
		MOV	D_DQSQ,AX		;保存
		AND	DX,7F7FH
		PUSH	AX
		AND	AH,7FH
		CMP	AH,30H			;判<16区?
		POP	AX
		JNB	L_GET11
		MOV	SI,OFFSET D_24T 	;T库
		JMP	SHORT L_GET12
L_GET11:
		SUB	DH,0FH			;区号-15
		XOR	BL,BL
		SHL	AH,1
		RCL	BL,1
		SHL	AL,1
		RCL	BL,1			;字库序号
		MOV	AL,40
		MUL	BL
		ADD	AX,OFFSET D_24S
		MOV	SI,AX			;指定字库FCB
L_GET12:
		SUB	DX,2121H
		MOV	AL,94
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX			;汉字序号
		MOV	DX,72
		MUL	DX
		PUSH	AX
		PUSH	DX
		MOV	DX,SI
		MOV	AX,3D00H		;打开字库文件
		INT	21H
		MOV	BX,AX
		POP	CX
		POP	DX
		MOV	AX,4200H		;移读指针
		INT	21H
		MOV	DX,D_CHKS		;缓冲区 		10.29
		MOV	CX,72
		MOV	AH,3FH			;读文件
		INT	21H
		MOV	AH,3EH			;关闭
		INT	21H
		POP	BX
		MOV	AH,51H			;恢复原PSP		10.29
		INT	21H
L_GET13:
		MOV	SI,D_CHKS		;缓冲区 		10.29
		RET
S_GET1		ENDP
K_GET1	EQU	$

F_24T		DB	'HZK24T',0
F_24S		DB	'HZK24S',0
F_24F		DB	'HZK24F',0
F_24H		DB	'HZK24H',0
F_24K		DB	'HZK24K',0

;本程序用--------------------------------------------------------------------
;子程序:取本程序所在路径
S_GETPATH	PROC	NEAR
		MOV	DS,DS:[2CH]		;环境段
		XOR	SI,SI
L_GP1:
		CMP	WORD PTR DS:[SI],0	;查找环境区尾?
		JZ	L_GP2
		INC	SI
		JMP	SHORT L_GP1
L_GP2:
		ADD	SI,4
		MOV	DI,OFFSET F_S		;带路径源文件名区
		PUSH	CS
		POP	ES
		CMP	BYTE PTR [SI+1],':'     ;判有盘符?
		JZ	L_GP3
		MOV	AH,19H			;取当前盘
		INT	21H
		INC	AL
		MOV	DL,AL
		OR	AL,40H
		STOSB				;写入盘符
		MOV	AL,':'
		STOSB
		CMP	BYTE PTR [SI],'\'       ;判有绝对路径?
		JZ	L_GP3
		MOV	AL,'\'
		STOSB
		JMP	SHORT L_GP4
L_GP3:
		CMP	BYTE PTR [SI+2],'\'     ;判有绝对路径?
		JZ	L_GP5
		LODSW				;盘符和\
		MOV	DL,AL			;盘符
		SUB	DL,40H
		STOSW
L_GP4:
		PUSH	SI
		MOV	SI,DI
		MOV	AH,47H			;取当前路径
		INT	21H
		POP	SI
L_GP5:
		CALL	S_MOVE			;传送
		PUSH	CS
		POP	DS
L_GP6:
		CMP	BYTE PTR [DI],'\'       ;最后一个\
		JZ	L_GP7
		DEC	DI
		JMP	SHORT L_GP6
L_GP7:
		MOV	BYTE PTR [DI],0
		RET
S_MOVE:
		LODSB
		STOSB
		OR	AL,AL
		JNZ	S_MOVE
		RET
S_GETPATH	ENDP

D_NAME		DB	'READ24',0
ALREADY 	DB	'本模块 READ24 已经驻留!',7,13,10,'$'
NOPATH		DB	'字库不在!',7,13,10,'$'
F_S		DB	40 DUP(0)

D_BUF		EQU	$

SEG_A		ENDS
		END	START

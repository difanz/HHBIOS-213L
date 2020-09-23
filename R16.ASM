;	R16.ASM (2.13L)
;	1995.1.26, 3.14, 4.6, 12.17
DATE	EQU	"1999.11.29"

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

D_R16		DB	'R16.COM',0     ;本程序文件名
D_FILE		DB	'READ0.COM',0
		DB	'READ1.COM',0
		DB	'READ2.COM',0
D_FILE3 	DB	'READ3.COM',0
		DB	'READ4.COM',0
		DB	'READ5.COM',0
		DB	'READ6.COM',0
		DB	0
D_0		DW	0,0,0,0,0	;各模块首地址
D_XMS		DD	0		;XMS模块地址
D_EMM		DB	'EMMXXXX0',0    ;EMS设备名
D_DRIVE 	DB	2		;虚盘盘号
D_INT25 	DD	0		;首扇区号	;读大盘扇区
		DW	1		;扇区数
		DW	2000H		;缓冲区偏移
D_CS		DW	0		;      段
D_NOFILE	DB	'THE READ?.COM FILE NOT FOUND!',13,10,'$'
D_S		DB	'THE MODULER IS JIONED!',13,10,'$'
D_T		DB	'THE MODULER IS SLIPED!',13,10,'$'
D_SERR		DB	'FILES FILES NOT FOUND!',13,10,'$'
MSG		DB	'调用格式: R16 [?][J][F] [/S][/T][/?] ',DATE,13,10
		DB	'    其中: ?-读字库模块号,若无数字则自动测试(仅3-6)',13,10
		DB	'          J-安装简体,F-安装繁体',13,10
		DB	'          /S-合成,/T-分解,/?-显示帮助',13,10
		DB	'读字库模块号(显示字库安装位置):',13,10
		DB	'    0-硬盘, 1-一级字库进内存, 2-全部进内存',13,10
		DB	'    3-虚拟盘, 4-EMS, 5-XMS, 6-扩展内存高端',13,10,'$'

BEGIN:
		MOV	AX,305H
		XOR	BX,BX
		INT	16H			;设置键盘速度
		MOV	AX,40H
		MOV	ES,AX
		AND	ES:[17H],AL		;置光标状态
		MOV	ES:[0F0H],AH
		PUSH	CS
		POP	ES

		MOV	SI,80H
		LODSB
		OR	AL,AL
		JNZ	L_10
L_9:
		JMP	TEST_XMS		;自动测试
L_10:
		LODSB
		CMP	AL,' '
		JBE	L_10
		CMP	AL,'/'
		JNZ	L_20
		LODSB
		CMP	AL,'?'                  ;显示帮助?
		JNZ	L_12
L_11:
		MOV	DX,OFFSET MSG
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_12:
		AND	AL,5FH
		CMP	AL,'S'
		JNZ	L_15
		CALL	S_S			;合成
		JB	L_13
		MOV	DX,OFFSET D_S
		JMP	SHORT L_ERR
L_13:
		MOV	DX,OFFSET D_SERR
		JMP	SHORT L_ERR
L_15:
		CMP	AL,'T'
		JNZ	L_9
		CALL	S_T			;分解
		MOV	DX,OFFSET D_T
		JMP	SHORT L_ERR
L_20:
		CMP	AL,'0'
		JB	L_30
		CMP	AL,'6'
		JA	L_30
		AND	AL,0FH
		MOV	BL,AL			;模块号
		LODSW
		MOV	DS:[5DH],AX
		JMP	LOAD0			;装入内存
L_30:
		MOV	AH,AL
		LODSB
		XCHG	AH,AL
		MOV	DS:[5DH],AX

TEST_XMS:
		MOV	AX,4300H		;测试XMS
		INT	2FH
		CMP	AL,80H
		JNZ	TEST_EMS
		MOV	AX,4310H		;取XMS驱动模块地址
		INT	2FH
		MOV	WORD PTR CS:D_XMS,BX	;保存
		MOV	WORD PTR CS:D_XMS+2,ES
		MOV	AH,8
		CALL	D_XMS
		CMP	DX,260
		JB	TEST_EMS
		MOV	BL,5
		JMP	LOAD
TEST_EMS:
		XOR	AX,AX
		MOV	ES,AX
		MOV	ES,ES:[19EH]		;INT67段
		MOV	DI,0AH			;偏移
		MOV	SI,OFFSET D_EMM 	;EMS设备名
		MOV	CX,8
		REPE	CMPSB			;判EMX?
		JNZ	TEST_15
		MOV	AH,42H
		INT	67H
		CMP	BX,10H
		JBE	TEST_15
		MOV	BL,4
		JMP	LOAD
TEST_15:
		CLC
		MOV	AH,88H		;取扩展内存大小
		INT	15H
		JB	TEST_VDISK
		CMP	AX,260
		JBE	TEST_VDISK
		MOV	BL,6
		JMP	LOAD
TEST_VDISK:
		MOV	D_DRIVE,2
		MOV	D_CS,CS
L_V1:		MOV	AL,D_DRIVE
		MOV	BX,2000H
		MOV	CX,1
		XOR	DX,DX
		INT	25H			;读盘首扇区
		POP	AX
		JNB	L_V2
		MOV	AL,D_DRIVE
		MOV	BX,OFFSET D_INT25
		MOV	CX,0FFFFH
		INT	25H			;读大盘分区首扇区
		POP	AX
		JNB	L_V2
		MOV	AL,'1'
		JMP	L_20			;执行READ1
L_V2:
		CMP	BYTE PTR DS:[2003H],'V' ;判VDISK?
		JZ	L_V3
		CMP	BYTE PTR DS:[2003H],'R' ;判RAMDRIVE?
		JZ	L_V3
		INC	D_DRIVE
		JMP	SHORT L_V1
L_V3:
		MOV	BL,3
		JMP	LOAD

;装入并执行读字库模块 BL=模块号
LOAD0:
		CMP	BL,3
		JAE	LOAD
		MOV	AL,10
		MUL	BL
		ADD	AX,OFFSET D_FILE
		MOV	DX,AX
		MOV	AX,3D00H
		INT	21H
		JNB	LOAD1
		MOV	DX,OFFSET D_NOFILE
		JMP	L_ERR
LOAD1:
		MOV	BX,AX
		PUSH	CS
		POP	ES
		MOV	SI,OFFSET LOAD2
		MOV	DI,0A0H 		;12.17
		MOV	CX,OFFSET LOAD-OFFSET LOAD2
		REP	MOVSB			;以下程序拷贝到CS:80H
		MOV	AX,0A0H 		;12.17
		JMP	AX
LOAD2:
		MOV	DX,100H
		MOV	CX,-1
		MOV	AH,3FH
		INT	21H
		MOV	AH,3EH
		INT	21H
		MOV	AX,100H
		JMP	AX
LOAD:
		SUB	BL,3
		XOR	BH,BH
		SHL	BX,1
		MOV	BP,D_0[BX]		;指定模块首
		MOV	DX,D_0[BX+2]		;下一模块首
		SUB	DX,BP			;本模块长度
		PUSH	CS
		POP	ES
		MOV	SI,OFFSET L_A
		MOV	DI,0A0H 		;12.17
		MOV	CX,OFFSET L_B-OFFSET L_A
		REP	MOVSB			;以下程序拷贝到CS:80H
		MOV	AX,0A0H 		;12.17
		JMP	AX
L_A:
		MOV	SI,BP
		MOV	DI,100H
		MOV	CX,DX
		REP	MOVSB
		MOV	AX,100H
		JMP	AX			;执行
L_B	EQU	$

;子程序:合成
S_S		PROC	NEAR
		MOV	SI,OFFSET D_FILE3	;文件表首
		MOV	DI,OFFSET BUF		;文件区首
		MOV	BP,OFFSET D_0		;模块区首地址
		MOV	DS:[BP],DI
L_S1:
		CMP	BYTE PTR DS:[SI],0
		JZ	L_S3
		MOV	DX,SI			;文件名
		MOV	AX,3D00H		;打开文件
		INT	21H
		JNB	L_S2
		RET
L_S2:
		MOV	BX,AX
		MOV	DX,DI			;模块首
		MOV	CX,-1
		MOV	AH,3FH			;读文件
		INT	21H
		ADD	DI,AX			;指向下一模块首
		MOV	AH,3EH			;关闭文件
		INT	21H
		ADD	SI,10			;下一文件名
		ADD	BP,2			;下一模块
		MOV	DS:[BP],DI		;下一模块首地址
		JMP	SHORT L_S1
L_S3:
		MOV	DX,OFFSET D_R16 	;本程序文件名
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		MOV	BX,AX			;文件号
		MOV	DX,100H 		;写入地址
		MOV	CX,DI			;文件尾
		SUB	CX,DX			;长度
		MOV	AH,40H			;写文件
		INT	21H
		MOV	AH,3EH			;关闭文件
		INT	21H
		CLC
		RET
S_S		ENDP

;子程序:分解
S_T		PROC	NEAR
		MOV	SI,OFFSET D_FILE3	;文件表首
		MOV	BP,OFFSET D_0		;模块区首地址
L_T1:
		CMP	BYTE PTR DS:[SI],0
		JZ	L_T2
		MOV	DX,SI
		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		MOV	BX,AX
		MOV	DX,DS:[BP]		;模块首
		MOV	CX,DS:[BP+2]		;下一模块首
		SUB	CX,DX			;本模块长度
		MOV	AH,40H			;写文件
		INT	21H
		MOV	AH,3EH			;关闭文件
		INT	21H
		ADD	SI,10			;下一文件名
		ADD	BP,2			;下一地址
		JMP	SHORT L_T1
L_T2:
		RET
S_T		ENDP

BUF	EQU	$

CSEG		ENDS
		END	START

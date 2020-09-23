;	RHC.ASM WS文本文件软回车处理
;	1995.11.21
;	1996.6.5, 7.21, 9.3

CSEG	SEGMENT
	ASSUME	CS:CSEG, DS:CSEG

	ORG	100H
START:	JMP	BEGIN

MSG	DB	'WordStar格式文本文件软回车处理程序',13,10
	DB	'  研制人: 吴晓军  日期: 1995年11月21日',13,10
	DB	'调用格式: RHC 文件名[/A][/B][/C][/D]',13,10
	DB	'    其中: 文件名-可用盘符和路径,不支持通配符?和*',13,10
	DB	'          /A - 硬回车改软回车(下行首非空格行)',13,10
	DB	'          /B - 保留原文件和目标文件VSJBWFJB.DAT',13,10
	DB	'          /C - 删除段首空格',13,10
	DB	'          /D - 删除软回车',13,10
	DB	'      注: /A不可与/C或/D同时使用.',13,10,'$'
NOFILE	DB	'指定文件未找到!',7,13,10,'$'
HAN1	DW	0			;原文件号
HAN2	DW	0			;目标文件号
FILE1	DW	0			;原文件名地址
FILE2	DB	'VSJBWFJB.DAT',0        ;中间文件
D_A	DB	0			;='A':硬回车改软回车
D_B	DB	0			;='B':保留原文件
D_C	DB	0			;='C':删除行首空格
D_D	DB	0			;='D':删除软回车
D_8D	DB	0			;=8DH:读出区尾为8DH
D_C0	DB	0			;行首标志
D_LEN	DW	0			;读出长度

BEGIN:
	MOV	SI,80H
	LODSB
	OR	AL,AL
	JNZ	L_10
L_1:
	MOV	DX,OFFSET MSG
L_ERR:
	MOV	AH,9
	INT	21H
	MOV	AX,4C01H
	INT	21H
L_10:
	CBW
	MOV	BX,AX
	MOV	[BX+SI],AH		;命令行尾置0
L_12:
	LODSB
	CMP	AL,' '                  ;命令行首空格
	JBE	L_12
	DEC	SI
	MOV	DX,SI			;文件名首
L_20:
	LODSB
	OR	AL,AL			;命令行尾?
	JZ	L_30
	CMP	AL,' '
	JA	L_21
	MOV	BYTE PTR [SI-1],0
	JMP	SHORT L_20
L_21:
	CMP	AL,'/'                  ;开关?
	JNZ	L_20
	MOV	BYTE PTR [SI-1],0
	LODSB
	CMP	AL,'?'
	JNZ	L_22
	JMP	L_1
L_22:
	AND	AL,5FH
	CMP	AL,'A'                  ;硬回车改软回车
	JNZ	L_23
	MOV	D_A,AL
	JMP	SHORT L_20
L_23:
	CMP	AL,'B'                  ;保留原文件
	JNZ	L_24
	MOV	D_B,AL
	JMP	SHORT L_20
L_24:
	CMP	AL,'C'                  ;删除行首空格
	JNZ	L_25
	MOV	D_C,AL
	JMP	SHORT L_20
L_25:
	CMP	AL,'D'                  ;删除软回车
	JNZ	L_20
	MOV	D_D,AL
	JMP	SHORT L_20
L_30:
	MOV	FILE1,DX		;保存原文件名首址
	MOV	AX,3D00H		;打开文件
	INT	21H
	JNB	L_31
	MOV	DX,OFFSET NOFILE
	JMP	SHORT L_ERR
L_31:
	MOV	HAN1,AX
	MOV	DX,OFFSET FILE2
	MOV	CX,20H
	MOV	AH,3CH			;建立中间文件
	INT	21H
	MOV	HAN2,AX
L_33:
	MOV	DX,OFFSET D_BUF
	MOV	SI,DX
	MOV	CX,8000H
	MOV	BX,HAN1
	MOV	AH,3FH			;读源文件
	INT	21H
	OR	AX,AX
	JNZ	L_35
	JMP	L_80
L_35:
	MOV	D_LEN,AX	;读出长度
	ADD	DX,AX
	MOV	BP,DX		;读出区尾
L_40:
	LODSB
	CMP	D_C,'C'         ;删除行首空格?
	JNZ	L_45
	CMP	D_C0,0		;判行首?
	JNZ	L_45
	CMP	AL,' '          ;行首空格?
	JNZ	L_45
	MOV	DI,SI
L_41:
	CMP	[DI],AL
	JNZ	L_42
	INC	DI
	CMP	DI,BP		;到区尾?
	JB	L_41
L_42:
	MOV	AX,DI
	SUB	AX,SI
	INC	AX
	JMP	L_53
L_45:
	CMP	D_8D,0AH	;上一次读出区尾为0AH?
	JNZ	L_48
	CMP	AL,0AH
	JZ	L_52
L_48:
	CMP	D_8D,8DH	;上一次读出区尾为8DH?
	JNZ	L_50
	MOV	D_8D,0
	CMP	AL,0AH
	JZ	L_49
	CMP	AL,8AH
	JNZ	L_50
L_49:
	JMP	L_52
L_50:
	CMP	AL,8DH		;软回车?
	JNZ	L_55
	CMP	D_D,'D'         ;删除?
	JNZ	L_56
	CMP	SI,BP		;到区尾?
	JNZ	L_51
	MOV	D_8D,AL
	JMP	SHORT L_52
L_51:
	MOV	AX,2
	CMP	BYTE PTR [SI],0AH
	JZ	L_53
	CMP	BYTE PTR [SI],8AH
	JZ	L_53
L_52:
	MOV	AX,1
L_53:
	DEC	SI
	MOV	DI,SI		;指向软回车
	PUSH	SI
	ADD	SI,AX		;指向软回车后一字节
	MOV	CX,BP		;区尾
	SUB	CX,SI		;传送长度
	REP	MOVSB		;删除软回车
	SUB	BP,AX		;区尾地址
	POP	SI
	JMP	SHORT L_40
L_55:
	CMP	AL,8AH		;WS换页符?
	JNZ	L_60
L_56:
	AND	AL,7FH		;变硬回车
	MOV	[SI-1],AL	;写入
L_60:
	CMP	AL,0AH		;换行?
	JNZ	L_70
	CMP	SI,BP		;判区尾?
	JNZ	L_61
	MOV	D_8D,AL
	JMP	L_74
L_61:
	CMP	AL,[SI] 	;下一字符为0AH?
	JNZ	L_74
	INC	SI
	JMP	SHORT L_52
L_70:
	CMP	AL,0DH		;回车?
	JNZ	L_75
	CMP	D_A,'A'         ;硬回车改软回车?
	JNZ	L_74
	MOV	AX,BP
	SUB	AX,SI
	CMP	AX,2		;距区尾2字节?
	JA	L_71
	MOV	DX,BP
	MOV	CX,2
	MOV	AH,3FH		;再读2字节
	INT	21H
	MOV	CX,-1
	MOV	DX,-2
	MOV	AX,4201H	;恢复原位置
	INT	21H
L_71:
	CMP	BYTE PTR [SI+1],0DH	;判下组为回车?
	JBE	L_74			;			6.5
	CMP	BYTE PTR [SI+1],' '     ;判下行首为空格?
	JZ	L_74
	CMP	BYTE PTR [SI+1],0A9H	;判下行首为九区制表符?	7.21
	JZ	L_74
	MOV	BYTE PTR [SI-1],8DH	;改软回车
L_74:
	MOV	D_C0,0		;置行首标志
	JMP	SHORT L_78
L_75:
	INC	D_C0
L_78:
	CMP	SI,BP		;到区尾?
	JAE	L_80
	JMP	L_40
L_80:
	MOV	DX,OFFSET D_BUF
	MOV	CX,BP
	SUB	CX,DX
	MOV	BX,HAN2
	MOV	AH,40H		;写
	INT	21H

	MOV	AX,D_LEN
	CMP	AX,8000H
	JB	L_90
	JMP	L_33
L_90:
	MOV	BX,HAN1
	MOV	AH,3EH
	INT	21H
	MOV	BX,HAN2
	MOV	AH,3EH
	INT	21H

	CMP	D_B,'B'                 ;保留原文件
	JZ	L_99
	MOV	DX,FILE1
	MOV	AH,41H			;删除源文件
	INT	21H
	MOV	DX,OFFSET FILE2 	;原文件名
	MOV	DI,FILE1		;新文件名
	MOV	AH,56H			;文件改名
	INT	21H
L_99:
	MOV	AX,4C00H
	INT	21H

D_BUF	EQU	$

CSEG	ENDS
	END	START

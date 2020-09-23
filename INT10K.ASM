;      INT10K.ASM (L)
;	1995.1.20, 3.31, 12.17
;	1996.2.2, 2.24, 3.31
;	1997.6.28, 7.6
;	1998.8.9

;命令:	A-模拟功能键	B-画矩形	C-置图形颜色	D-画点
;	E-向右上画线	F-向右下画线	G-向左下画线	H-向左上画线
;	I-执行INT 10	J-执行命令串	K-置比例因子	L-画斜线
;	M-移点不画线	N-画线不移点	O-画圆		P-填充
;	Q-清屏初始化	R-光标控制	S-置前景背景色	T-繁简转换
;	U-向上画线	V-矩形区填充线	W-存命令串	X-向下画线
;	Y-向右画线	Z-向左画线	_-按字符画横线	|-按行画竖线
;	#-字符行列框线	*-重显字符串	.-暂停		^-停止或设置演奏次数
;	%-演奏音乐	@-显示16色图象	~-保存16色图象	[-显示汉字
;	!-延时

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN			;执行程序

D_INT10 	DD	0			;[103H]
D_INT1C 	DD	0			;[107H]
D_A000		DW	0A000H			;[10BH]

		DB	'K'                     ;[10DH]

;子程序:执行原INT 10
INT10		PROC	NEAR
		PUSHF
		CALL	CS:D_INT10
		RET
INT10		ENDP

;中断入口
INT_10		PROC	FAR
		STI
		CLD
		PUSH	DS
		PUSH	AX
		PUSH	CS
		POP	DS
		CMP	AH,19H			;特显开关
		JNZ	L_AH09
		OR	AL,AL			;=0关,=1开
		JNZ	L_1910
		MOV	AX,OFFSET L_GO10-OFFSET L_AH0A
		MOV	AH,0EBH 		;JMP
L_1901:
		XCHG	AH,AL
		MOV	WORD PTR D_TXKG,AX
		JMP	L_RET2
L_1910:
		CMP	AL,1
		JNZ	L_1920
		MOV	AX,OFFSET L_AH0E-OFFSET L_AH0A
		MOV	AH,74H			;JNZ
		JMP	SHORT L_1901
L_1920:
		CMP	AL,2			;=2初始化
		JNZ	L_1930
		PUSH	BX
		PUSH	ES
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	BP
		CALL	S_0
		JMP	SHORT L_RET
L_1930:
		CMP	AL,3			;返回安装状态AL和ES
		JNZ	L_1940
		MOV	AL,84H
		PUSH	CS
		POP	ES
		POP	DS
		POP	DS
		IRET
L_1940:
		CMP	AL,4			;停止演奏音乐
		JNZ	L_RET2
		MOV	D_ADDR,OFFSET D_BUF3
		XOR	AL,AL
		MOV	YYC,AL
		CMP	D_NUM,0
		JNZ	L_1941
		MOV	AL,D_N
L_1941:
		MOV	D_NUM,AL
		IN	AL,61H
		AND	AL,0FCH 		;关闭扬声器
		OUT	61H,AL
		JMP	SHORT L_RET2
L_AH09:
		CMP	AH,9			;判调用号=9?
D_TXKG		EQU	$
		JZ	L_AH0E
L_AH0A:
		CMP	AH,0AH
		JZ	L_AH0E
		CMP	AH,0EH
		JNZ	L_GO10
L_AH0E:
		CMP	D_FF,0EH		;判引导符标志
		JZ	L_0E00
		CMP	AL,0EH			;判引导符
		JZ	L_AL0E
		MOV	AL,D_FD 		;指定颜色
		OR	AL,AL
		JZ	L_GO10
		AND	BL,80H
		OR	BL,AL
L_GO10:
		POP	AX
		POP	DS
		JMP	CS:D_INT10		;执行原INT 10
INT_10		ENDP

L_AL0E:
		MOV	D_FF,AL 		;置引导符标志
		JMP	SHORT L_RET2
L_RET:
		POP	BP
		POP	DI
		POP	SI
		POP	DX
		POP	CX
		POP	ES
L_RET1:
		POP	BX
L_RET2:
		POP	AX
L_RET3:
		POP	DS
		IRET
L_0E00:
		PUSH	BX
		MOV	BX,D_FE 		;取输入缓冲区指针
		MOV	[BX],AL 		;写入输入缓冲区
		INC	BX			;输入缓冲区指针加1
		CMP	BX,0FFH 		;判输入缓冲区尾
		JNZ	L_0E10
		MOV	BYTE PTR DS:[BX],']'
		JMP	SHORT L_0E20
L_0E10:
		MOV	D_FE,BX
		CMP	AL,']'                  ;判终止符
		JNZ	L_RET1
L_0E20:
		PUSH	ES
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	BP
		XOR	AX,AX
		MOV	D_FE,AX 		;清输入缓冲区指针
		MOV	D_FF,AL 		;清标志
		MOV	SI,AX			;置输入缓冲区指针
		CALL	S_ST			;处理
		JMP	SHORT L_RET

D_D0		DB	0	;[0D0H]:最大色号
D_D1		DW	0	;[0D1H]:X
D_D3		DW	0	;[0D3H]:Y
D_D5		DW	0	;[0D5H]:最大X坐标
D_D7		DW	0	;[0D7H]:最大Y坐标
D_D9		DW	0	;[0D9H]:X增量		输入参数1
D_DB		DW	0	;[0DBH]:Y增量			2
D_DD		DW	0	;[0DDH]:保存[0D1H]		3
D_DF		DW	0	;[0DFH]:保存[0D3H]		4
D_E1		DW	0	;[0E1H]:			5
D_E3		DW	0	;[0E3H]:			6
D_E5		DW	0	;[0E5H]:			7
D_E7		DW	0	;[0E7H]:			8
D_E9		DW	0	;[0E9H]:			9
D_EB		DW	0	;[0EBH];		       10
D_ED		DB	0	;[0EDH]:画图颜色
D_EE		DB	0	;[0EEH]:图形内色
D_EF		DB	0	;[0EFH]:位0-M命令标志,位1-N命令标志
D_F0		DB	0	;[0F0H]:字型
D_F1		DB	0	;[0F1H]:前景色
D_F2		DB	0	;[0F2H]:背景色
D_F3		DW	0	;[0F3H]:字间距
D_F5		DW	1	;[0F5H]:行间距
D_F7		DW	0	;[0F7H]:本行最大Y值
D_F9		DB	0	;[0F9H]:每屏显示行数
D_FA		DB	0	;[0FAH]:每行扫描线数
D_FB		DB	0	;[0FBH]:当前显示方式
D_FC		DB	0	;[0FCH]:每行字符数
D_FD		DB	0	;[0FDH]:指定字符颜色
D_FE		DW	0	;[0FEH]:输入码区指针
D_FF		DB	0	;[0FFH]:CHR(14)标志
D_100		DB	16	;[100H]:比例因子
D_PSP		DW	0	;保存PSP

D_SIN		DW	    0,	175,  349,  523,  698,	872, 1045
		DW	 1219, 1392, 1564, 1736, 1908, 2079, 2250
		DW	 2419, 2588, 2756, 2924, 3090, 3256, 3420
		DW	 3584, 3746, 3907, 4067, 4226, 4384, 4540
		DW	 4695, 4848, 5000, 5150, 5299, 5446, 5592
		DW	 5736, 5878, 6018, 6157, 6293, 6428, 6561
		DW	 6691, 6820, 6947, 7071, 7193, 7314, 7431
		DW	 7547, 7660, 7771, 7880, 7986, 8090, 8192
		DW	 8290, 8387, 8480, 8572, 8660, 8746, 8829
		DW	 8910, 8988, 9063, 9135, 9205, 9272, 9336
		DW	 9397, 9455, 9511, 9563, 9613, 9659, 9703
		DW	 9744, 9781, 9816, 9848, 9877, 9903, 9925
		DW	 9945, 9962, 9976, 9986, 9994, 9998,10000

D_ML		DW	OFFSET L_A
		DW	OFFSET L_B
		DW	OFFSET L_C
		DW	OFFSET L_D
		DW	OFFSET L_E
		DW	OFFSET L_F
		DW	OFFSET L_G
		DW	OFFSET L_H
		DW	OFFSET L_I
		DW	OFFSET L_J
		DW	OFFSET L_K
		DW	OFFSET L_L
		DW	OFFSET L_M
		DW	OFFSET L_N
		DW	OFFSET L_O
		DW	OFFSET L_P
		DW	OFFSET L_Q
		DW	OFFSET L_R
		DW	OFFSET L_S
		DW	OFFSET L_T
		DW	OFFSET L_U
		DW	OFFSET L_V
		DW	OFFSET L_W
		DW	OFFSET L_X
		DW	OFFSET L_Y
		DW	OFFSET L_Z
;子程序:处理
S_ST		PROC	NEAR
L_ST:
		PUSH	CS
		POP	ES
		LODSB				;取命令字符
		CMP	AL,'A'
		JB	L_ST2
		CMP	AL,'Z'
		JBE	L_ST1
		CMP	AL,'a'
		JB	L_ST2
		CMP	AL,'z'
		JA	L_ST2
		AND	AL,5FH			;小写变大写
L_ST1:
		SUB	AL,'A'
		CBW
		MOV	BX,AX
		SHL	BX,1
		JMP	D_ML[BX]		;执行A~命令
L_ST2:
		CMP	AL,'['                  ; *显示点阵汉字*
		JNZ	L_ST3
		JMP	L_XSHZ
L_ST3:
		CMP	AL,']'                  ;终止符
		JNZ	L_YS
		RET

;※延时※--------------------------------------------------------------------
;格式:CHR(14)+"!n]"
;其中:n 为延时时间(单位:秒.0-4096)
L_YS:
		CMP	AL,'!'
		JNZ	L_GPCX
		CALL	S_Q
		OR	AX,AX
		JZ	L_YS1
		MOV	BX,AX
		MOV	DX,4240H
		MUL	DX
		MOV	CX,DX
		MOV	DX,AX
		MOV	AX,0FH
		MUL	BX
		ADD	CX,AX
		MOV	AH,86H			;设置延时
		INT	15H
L_YS1:
		JMP	L_ST

;※保存16色图象※------------------------------------------------------------
;格式:CHR(14)+"~x1,y1,x2,y2,文件名$]"
;其中:x1为左上角列(0-79),y1为行坐标(0,479)
;     x2为右下角列(1-79),y2为行坐标(1,479),文件扩展名应为PCX
D_PCX		DB	10,5,1		;PCX标志
		DB	1		;每点位数
D_BYTES 	DW	0

L_GPCX:
		CMP	AL,'~'
		JZ	L_GP0
		JMP	L_@
L_GP0:
		CALL	S_Q
		MOV	WORD PTR D_BUF1+4,AX	;左上角X
		CALL	S_Q0
		MOV	WORD PTR D_BUF1+6,AX	;      Y
		CALL	S_Q0
		MOV	WORD PTR D_BUF1+8,AX	;右下角X
		CALL	S_Q0
		MOV	WORD PTR D_BUF1+10,AX	;      Y

		INC	SI
		MOV	DX,SI
L_GP1:
		LODSB
		CMP	AL,'$'                  ;查找文件名尾
		JNZ	L_GP1
		MOV	BYTE PTR [SI-1],0	;文件名尾

		MOV	AX,350
		CMP	D_FB,10H		;EGA?
		JZ	L_GP1A
		MOV	AX,480
		CMP	D_FB,12H		;VGA?
		JZ	L_GP1A
		JMP	L_ST
L_GP1A:
		MOV	WORD PTR D_BUF1+14,AX	;D_YM
		MOV	WORD PTR D_BUF1+12,640	;D_YM
		PUSH	SI

		MOV	AH,62H			;取当前PSP
		INT	21H
		MOV	D_PSP,BX		;保存
		MOV	BX,CS
		MOV	AH,50H			;设置当前PSP
		INT	21H

		MOV	CX,20H
		MOV	AH,3CH			;建立文件
		INT	21H
		JNB	L_GP2
		MOV	AX,0E07H
		INT	10H
		JMP	L_GP9
L_GP2:
		MOV	BX,AX			;文件号
		MOV	AX,WORD PTR D_PCX	;文件头
		MOV	WORD PTR D_BUF1,AX
		MOV	AX,WORD PTR D_PCX+2
		MOV	WORD PTR D_BUF1+2,AX
		MOV	D_BUF1+41H,4		;页面数

		PUSH	CS
		POP	ES
		MOV	DX,OFFSET D_BUF1+128
		MOV	SI,DX
		MOV	AX,1009H		;取全部调色板
		INT	10H
		MOV	DI,OFFSET D_BUF1+10H	;DAC数据区
		MOV	CX,1002H		;CH=16:调色板数,CL=2移位
L_GP3:
		LODSB
		MOV	DX,3C7H 		;DAC读地址寄存器
		OUT	DX,AL
		INC	DX
		INC	DX			;DAC数据寄存器
		IN	AL,DX			;取
		SHL	AL,CL			;左移2位
		STOSB				;存
		IN	AL,DX
		SHL	AL,CL
		STOSB
		IN	AL,DX
		SHL	AL,CL
		STOSB
		DEC	CH
		JNZ	L_GP3

		MOV	AX,WORD PTR D_BUF1+6	;D_Y
		MOV	DX,80
		MUL	DX
		ADD	AX,WORD PTR D_BUF1+4	;D_X
		MOV	SI,AX			;左上角地址
		MOV	AX,WORD PTR D_BUF1+8	;D_XN
		SUB	AX,WORD PTR D_BUF1+4	;D_X
		INC	AX
		MOV	WORD PTR D_BUF1+42H,AX	;每扫描线不压缩字节数
		MOV	D_BYTES,AX
		MOV	CX,8
		MOV	AX,WORD PTR D_BUF1+4	;D_X
		MUL	CX
		MOV	WORD PTR D_BUF1+4,AX	;D_X
		MOV	AX,WORD PTR D_BUF1+8	;D_XN
		MUL	CX
		ADD	AX,7
		MOV	WORD PTR D_BUF1+8,AX	;D_XN

		MOV	DX,OFFSET D_BUF1
		MOV	CX,80H
		MOV	AH,40H			;写文件头
		INT	21H

		MOV	CX,WORD PTR D_BUF1+10	;D_YN
		SUB	CX,WORD PTR D_BUF1+6	;D_Y
		INC	CX			;窗口扫描线数(高)
		MOV	AX,0A000H
		MOV	DS,AX
		PUSH	CS
		POP	ES
L_GP4:
		PUSH	CX
		MOV	AH,0
L_GP4A:
		MOV	DX,3CEH
		MOV	AL,4
		OUT	DX,AX			;读页面
		PUSH	AX
		PUSH	SI
		MOV	DI,OFFSET D_BUF1	;缓冲区
		MOV	BP,SI
		ADD	BP,CS:D_BYTES		;BP:扫描线尾
L_GP5:
		CMP	SI,BP			;判扫描线尾?
		JZ	L_GP6
		MOV	CX,1			;DX:计数
		LODSB				;取一字节
		MOV	AH,AL			;保存
L_GP5A:
		CMP	SI,BP			;判扫描线尾?
		JZ	L_GP5C
		LODSB				;取一字节
		CMP	AL,AH			;判?
		JNZ	L_GP5B
		INC	CX			;计数+1
		CMP	CX,63			;>63?
		JB	L_GP5A
		JMP	SHORT L_GP5C
L_GP5B:
		DEC	SI
L_GP5C:
		CMP	CX,1			;只一个?
		JNZ	L_GP5E
		CMP	AH,0C0H 		;>0C0H?
		JAE	L_GP5E
L_GP5D:
		MOV	AL,AH
		STOSB				;写入
		JMP	SHORT L_GP5
L_GP5E:
		MOV	AL,CL			;计数
		ADD	AL,0C0H
		STOSB				;写入个数(-0C0H=个数)
		JMP	SHORT L_GP5D
L_GP6:
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_BUF1	;缓冲区
		MOV	CX,DI
		SUB	CX,DX			;字节数
		MOV	AH,40H			;写入
		INT	21H
		POP	DS

		POP	SI
		POP	AX
		INC	AH
		CMP	AH,3
		JBE	L_GP4A

		ADD	SI,80			;下一行首
		POP	CX
		LOOP	L_GP4
		PUSH	CS
		POP	DS

		MOV	AH,3EH			;关闭文件
		INT	21H
L_GP9:
		MOV	BX,D_PSP
		MOV	AH,50H			;恢复原PSP
		INT	21H
		POP	SI
		JMP	L_ST

;※显示图象※----------------------------------------------------------------
;格式:CHR(14)+"@左上角字符列,扫描线行,图象文件名$]"
L_@:
		CMP	AL,'@'
		JZ	L_@10
		JMP	L_HX
L_@10:
		CALL	S_Q
		MOV	D_DD,AX 		;横向位置
		CALL	S_Q0
		MOV	D_DF,AX 		;纵向位置
		MOV	DX,80
		MUL	DX
		ADD	AX,D_DD
		MOV	BP,AX			;开始显示地址

		MOV	AH,62H			;取当前PSP
		INT	21H
		MOV	D_PSP,BX		;保存
		MOV	BX,CS
		MOV	AH,50H			;设置当前PSP
		INT	21H

		INC	SI
		MOV	DX,SI			;文件名首址
L_@20:
		LODSB
		CMP	AL,'$'                  ;查找文件名尾
		JNZ	L_@20
		MOV	BYTE PTR [SI-1],0	;文件名尾
		PUSH	SI
		MOV	AX,3D00H		;打开
		INT	21H
		JNB	L_@40
L_@33:
		MOV	AX,0E07H
		INT	10H
		JMP	L_@90
L_@40:
		MOV	BX,AX
		MOV	DX,OFFSET D_BUF1
		MOV	DI,DX
		MOV	CX,128
		MOV	AH,3FH			;读入首部
		INT	21H

		CMP	BYTE PTR DS:[DI],0AH	;判识别码
		JZ	L_@41
		MOV	AH,3EH
		INT	21H
		JMP	SHORT L_@33
L_@41:
		MOV	AL,[DI+41H]		;位面数
		MOV	[DI],AL
		MOV	AX,[DI+42H]		;每线不压缩字节数
		MOV	[DI+1],AX

		MOV	SI,OFFSET D_BUF1+10H	;指向DAC数据
		MOV	CX,3002H
L_@42:
		SHR	BYTE PTR [SI],CL	;DAC数据处理
		INC	SI
		DEC	CH
		JNZ	L_@42

		PUSH	CS
		POP	ES
		MOV	DX,OFFSET D_BUF1+80H
		MOV	AX,1009H		;读全部调色板寄存器
		INT	10H
		MOV	DI,DX
		MOV	SI,OFFSET D_BUF1+10H
		MOV	CX,16
L_@44:
		MOV	AL,[DI]
		INC	DI
		MOV	DX,3C8H 		;DAC地址寄存器
		OUT	DX,AL
		INC	DX			;DAC数据寄存器
		LODSB
		OUT	DX,AL
		LODSB
		OUT	DX,AL
		LODSB
		OUT	DX,AL
		LOOP	L_@44

		MOV	DX,OFFSET D_BUF3
		MOV	SI,DX
		MOV	CX,512
		MOV	AH,3FH			;读文件
		INT	21H
		JB	L_@55
		OR	AX,AX
		JNZ	L_@60
L_@55:
		JMP	L_@80
L_@60:
		MOV	DI,BP			;开始地址
		MOV	BP,SI
		ADD	BP,AX			;BP:读出区尾
		MOV	AX,0A000H
		MOV	ES,AX
		MOV	CX,WORD PTR D_BUF1+10	;图象Ymax
		INC	CX
L_@70:
		CALL	S_XS			;显示一线
		ADD	DI,80
		LOOP	L_@70
L_@80:
		MOV	AH,3EH			;关闭文件
		INT	21H
L_@90:
		MOV	BX,D_PSP
		MOV	AH,50H			;恢复原PSP
		INT	21H
		POP	SI
		JMP	L_ST

;子程序:显示一行
S_XS:
		PUSH	CX
		MOV	CL,D_BUF1		;位面数
		CMP	CL,1
		JNZ	L_XXA
		CALL	S_XSYH			;显示一线
		JMP	SHORT L_XXC
L_XXA:
		MOV	AH,1
L_XXB:
		PUSH	AX
		MOV	DX,3C4H
		MOV	AL,2
		OUT	DX,AX			;选择位面
		CALL	S_XSYH			;显示一线
		POP	AX
		SHL	AH,1
		DEC	CL
		JNZ	L_XXB
		MOV	DX,3C4H
		MOV	AX,0F02H
		OUT	DX,AX
L_XXC:
		POP	CX
		RET
S_XSYH:
		PUSH	CX
		PUSH	DI
		XOR	DX,DX
L_YH1:
		LODSB				;取一字节
		CALL	S_READ
		CMP	AL,0C0H 		;判压缩?
		JA	L_YH2
		INC	DX			;计数+1
		STOSB				;写一字节
		JMP	SHORT L_YH3
L_YH2:
		SUB	AL,0C0H
		CBW
		MOV	CX,AX			;重复字节数
		ADD	DX,CX			;计数
		LODSB				;重复字节
		CALL	S_READ
		REP	STOSB			;写
L_YH3:
		CMP	DX,WORD PTR D_BUF1+1	;判写满一线?(每线不压缩字节数)
		JB	L_YH1
		POP	DI
		POP	CX
		RET
S_READ:
		CMP	SI,BP			;到读出区尾?
		JB	L_READ
		PUSH	AX
		PUSH	CX
		PUSH	DX
		MOV	DX,OFFSET D_BUF3
		MOV	SI,DX
		MOV	CX,512
		MOV	AH,3FH			;读文件
		INT	21H
		MOV	BP,SI
		ADD	BP,AX			;读出区尾
		POP	DX
		POP	CX
		POP	AX
L_READ:
		RET
;※按字符画横线※------------------------------------------------------------
;格式:CHR(14)+"_行,列,长度]"  (字符数)
L_HX:
		CMP	AL,'_'
		JNZ	L_SX
		CALL	S_QZU			;取行列并转换为左上角坐标
		MOV	D_D9,1
		MOV	D_DB,0
		CALL	S_Q0
		MOV	CL,8
		MUL	CL
		JMP	L_Y3

;※按行画竖线※--------------------------------------------------------------
;格式:CHR(14)+"_行,列,长度]"  (行)
L_SX:
		CMP	AL,'|'
		JNZ	L_KX
		CALL	S_QZU			;取行列并转换为左上角坐标
		MOV	D_D9,0
		MOV	D_DB,1
		CALL	S_Q0
		MUL	D_FA
		JMP	L_Y3

;※按字符行列画框线※--------------------------------------------------------
;格式:CHR(14)+"_行,列,高,宽{,方式}]"  (均为字符行列,若有方式则缩进四点)
L_KX:
		CMP	AL,'#'
		JNZ	L_CX
		CALL	S_QZU			;取行列并转换为左上角坐标
		CALL	S_Q0			;取行
		MUL	D_FA
		MOV	DI,AX
		CALL	S_Q0			;取列
		MOV	CL,8
		MUL	CL
		CMP	BYTE PTR DS:[SI],','
		JNZ	L_KX1
		PUSH	AX
		CALL	S_Q0
		POP	AX
		SUB	D_D1,4
		SUB	D_D3,4
		ADD	DI,8
		ADD	AX,8
L_KX1:
		PUSH	SI
		MOV	SI,AX
		XCHG	SI,DI
		MOV	D_E1,SI
		MOV	CX,D_D1
		MOV	DX,D_D3
		JMP	L_B3

;※重显字符串※--------------------------------------------------------------
;格式:CHR(14)+"*行,列,字符数,前景色,背景色]"
L_CX:
		CMP	AL,'*'
		JNZ	L_ZT
		CALL	S_Q			;取行号
		PUSH	AX
		CALL	S_Q0			;取列号
		POP	DX
		MOV	DH,DL
		MOV	DL,AL
		PUSH	DX
		CALL	S_Q0			;取串长
		PUSH	AX
		CALL	S_Q0			;取前景色
		PUSH	AX
		XOR	AL,AL
		CMP	BYTE PTR DS:[SI],','
		JNZ	L_CX1
		CALL	S_Q0			;取背景色
		MOV	CL,4
		SHL	AL,CL
L_CX1:
		POP	BX
		OR	BL,AL			;属性
		POP	CX			;串长
		POP	DX			;位置
		MOV	AX,1305H		;重显字符串
		CALL	INT10
		JMP	L_ST

;※暂停※--------------------------------------------------------------------
;格式:CHR(14)+".]"  (按回车键继续)
L_ZT:
		CMP	AL,'.'
		JNZ	L_TZ
		MOV	AX,0E07H
		CALL	INT10			;响铃
L_ZT1:
		XOR	AH,AH
		INT	16H
		CMP	AL,0DH			;回车
		JNZ	L_ZT1
L_ZT2:
		JMP	L_ST

;※停止或设置演奏次数※------------------------------------------------------
;格式:CHR(14)+"^次数]"  (若无次数则停止)
L_TZ:
		CMP	AL,'^'
		JNZ	L_%
		LODSB
		CMP	AL,'0'
		JNZ	L_TZ1
		MOV	AL,0FFH
		JMP	SHORT L_TZ2
L_TZ1:
		CMP	AL,'1'
		JB	L_TZ3
		CMP	AL,'9'
		JA	L_TZ3
		AND	AL,0FH
L_TZ2:
		MOV	D_N,AL
		JMP	SHORT L_ZT2
L_TZ3:
		CMP	YYC,0
		JNZ	L_TZ3
		MOV	D_NUM,0
		MOV	D_ADDR,OFFSET D_BUF3
		DEC	SI
		JMP	SHORT L_ZT2

;※演奏音乐※----------------------------------------------------------------
;格式:CHR[$](14)+"%功能符或音符]"
;其中:功能符为	t节拍	指定节拍(默认100,每分钟节拍数)
;		CDEFGAB 定调(开机为C调)
;		1234567 音名		0	休止符
;		#	升半音		b	降半音
;		q	升八度		d	降八度
;		.	附点		-	延长音
;		_	八分音符	=	十六分音符
;	注:升将八度、升将半音在音名前，延长、附点、四八分音符在音名后
L_%:
		CMP	AL,'%'
		JZ	L_%10
		JMP	L_ST
L_%10:
		LODSB
L_%20:
		CMP	AL,'-'                  ;*延长音*
		JNZ	L_%30
		MOV	AX,JPI
L_%21:
		ADD	YC,AX
		JMP	SHORT L_%10
L_%30:
		CMP	AL,'.'
		JNZ	L_%40
		MOV	AX,YC
		SHR	AX,1
		JMP	SHORT L_%21
L_%40:
		CMP	AL,'_'                  ;*1/8音符*
		JNZ	L_%50
		SHR	YC,1
		JMP	SHORT L_%10
L_%50:
		CMP	AL,'='                  ;*1/16音符*
		JNZ	L_%60
		SHR	YC,1
		SHR	YC,1
		JMP	SHORT L_%10
L_%60:
		CMP	D_NUM,0
		JNZ	L_%60
		PUSH	AX
		CMP	D_FRE,-1
		JZ	L_%66
		MOV	DI,D_ADDR
		CMP	DI,OFFSET D_BUF3+1FAH
		JA	L_%61
		MOV	AX,D_FRE
		STOSW
		MOV	AX,YC
		STOSB
		MOV	D_ADDR,DI
L_%61:
		MOV	D_FRE,-1
L_%66:
		POP	AX
		CMP	AL,']'
		JNZ	L_%70
		DEC	SI
		MOV	DI,D_ADDR
		MOV	WORD PTR DS:[DI],-1
		MOV	D_ADDR,OFFSET D_BUF3
		MOV	AL,D_N
		MOV	D_NUM,AL
		JMP	L_ST
L_%70:
		CMP	AL,'t'                  ;*指定节拍*
		JNZ	L_%80
		CALL	S_Q			;取参数
		MOV	AX,1092 		;每分钟频率
		CWD
		DIV	CX
		MOV	JPI,AX			;存节拍
		JMP	L_%10
L_%80:
		CMP	AL,'#'                  ;*升半音*
		JNZ	L_%90
		MOV	AL,1			;升半音
L_%82:
		CBW
		ADD	SJ,AX
		JMP	L_%10
L_%90:
		CMP	AL,'b'                  ;*降半音*
		JNZ	L_%100
		MOV	AL,0FFH 		;降半音(=-1)
		JMP	SHORT L_%82
L_%100:
		CMP	AL,'q'                  ;*升八度*
		JNZ	L_%110
		MOV	AL,12
		JMP	SHORT L_%82
L_%110:
		CMP	AL,'d'                  ;*降八度*
		JNZ	L_%120
		MOV	AL,0F4H 		;=-12
		JMP	SHORT L_%82
L_%120:
		CMP	AL,'A'                  ;*定调号*
		JB	L_%130
		CMP	AL,'G'                  ;*定调号*
		JA	L_%130
		SUB	AL,'C'
		JNB	L_%121
		ADD	AL,7
L_%121:
		CBW
		MOV	BX,AX
		MOV	AL,YJ[BX]
		ADD	AX,SJ
		ADD	AL,12			;C调为262
		MOV	DDH,AX			;存调号
L_%122:
		MOV	SJ,0			;清升降音
L_%123:
		JMP	L_%10
L_%130:
		CMP	AL,'0'
		JNZ	L_%140
		XOR	AX,AX
		JMP	SHORT L_%141
L_%140:
		CMP	AL,'1'                  ;*音符*
		JB	L_%123
		CMP	AL,'7'                  ;*音符*
		JA	L_%123
		SUB	AL,'1'
		CBW
		MOV	BX,AX
		MOV	AL,YJ[BX]		;取音阶
		ADD	AX,SJ			;加升降
		ADD	AX,DDH			;加定调
		MOV	BL,12
		DIV	BL
		MOV	CL,3
		SUB	CL,AL
		MOV	BL,AH
		XOR	BH,BH
		SHL	BX,1
		MOV	BX,FDATA[BX]
		SHR	BX,CL
		MOV	DX,14H
		MOV	AX,533H*896
		DIV	BX
L_%141:
		MOV	D_FRE,AX
		MOV	AX,JPI
		MOV	YC,AX			;清音长
		JMP	L_%122

D_FRE		DW	0
DDH		DW	0CH			;定调(FDATA的字偏移)
JPI		DW	11			;节拍
SJ		DW	0			;升、降音程
YC		DW	4			;音长
YJ		DB	0,2,4,5,7,9,11		;音阶
FDATA		DW	1046,1109,1175,1245,1319,1397
		DW	1480,1568,1661,1760,1865,1976

;※模拟功能键※--------------------------------------------------------------
;格式:CHR(14)+"A扩展ASCII码]"
L_A:
		CALL	S_Q			;取参数AX:功能键扩展ASC码
		MOV	AH,21H
		INT	16H			;模拟功能键
		JMP	L_ST

;※画矩形※------------------------------------------------------------------
;格式:CHR(14)+"B宽,高]"
;		指像素点,若其中之一等于0则不画,若全等于0则画屏幕边框线
L_B:
		CALL	S_QK			;取参数并乘比例因子
		MOV	DI,AX
		XOR	AX,AX
		CMP	BYTE PTR DS:[SI],','
		JNZ	L_B1
		INC	SI
		CALL	S_QK			;取参数并乘比例因子
L_B1:
		OR	DI,DI			;判宽=0?
		JNZ	L_B2
		OR	AX,AX			;再判高=0?
		JNZ	L_B6
		XOR	CX,CX
		XOR	DX,DX			;屏幕左上角点
		PUSH	SI
		MOV	DI,D_D5 		;屏幕宽
		MOV	SI,D_D7 		;屏幕高
		JMP	SHORT L_B3		;画边框线
L_B2:
		OR	AX,AX			;判高=0?
		JZ	L_B6
		PUSH	SI
		MOV	SI,AX
		MOV	D_E1,AX 		;存高
		MOV	CX,D_D1 		;左下角
		MOV	DX,D_D3
		SUB	DX,SI			;改左上角
L_B3:
		CALL	S_JX			;画矩形
		POP	SI

		MOV	AL,D_EE 		;取填充色
		CMP	AL,-1			;=-1不填充
		JZ	L_B6
		PUSH	WORD PTR D_ED		;保护
		MOV	D_ED,AL 		;填充色
		INC	CX			;填充区左上角
		INC	DX
		MOV	BX,D_E1 		;高
		DEC	BX			;高-1
		DEC	DI			;宽-1
L_B4:
		MOV	BP,DI
		PUSH	CX
L_B5:
		CALL	S_D2			;写点
		INC	CX			;下一点
		DEC	BP			;宽
		JNZ	L_B5
		POP	CX
		INC	DX			;下一行
		DEC	BX			;高
		JNZ	L_B4
		POP	WORD PTR D_ED		;恢复
L_B6:
		JMP	L_ST

;子程序:画矩形(DI-宽,SI-高)
S_JX:
		MOV	BP,DI
L_JX1:
		CALL	S_D2
		INC	CX
		DEC	BP
		JNZ	L_JX1
		MOV	BP,SI
L_JX2:
		CALL	S_D2
		INC	DX
		DEC	BP
		JNZ	L_JX2
		MOV	BP,DI
L_JX3:
		CALL	S_D2
		DEC	CX
		DEC	BP
		JNZ	L_JX3
		MOV	BP,SI
L_JX4:
		CALL	S_D2
		DEC	DX
		DEC	BP
		JNZ	L_JX4
		RET

;※设置图形颜色※------------------------------------------------------------
;格式:CHR(14)+"C色号{,填充色号}]"
L_C:
		CALL	S_Q			;取参数
		MOV	D_ED,AL
		MOV	AL,-1
		CMP	BYTE PTR [SI],','       ;是否有填充色?
		JNZ	L_C1
		CALL	S_Q0			;取参数
L_C1:
		MOV	D_EE,AL 		;填充色(=-1不填充)
		JMP	L_ST

;※画点※--------------------------------------------------------------------
;格式:CHR(14)+"D点X,Y]"
L_D:
		CALL	S_Q			;取参数:X-坐标
		MOV	D_D1,AX
		CALL	S_Q0			;取参数:Y-坐标
		MOV	D_D3,AX
		CALL	S_D			;画点
		AND	D_EF,0FEH		;清M命令标志
		JMP	L_ST

;※向右上画线※--------------------------------------------------------------
;格式:CHR(14)+"E长度]"
L_E:
		MOV	AX,1
		JMP	SHORT L_U1
;※向右下画线※--------------------------------------------------------------
;格式:CHR(14)+"F长度]"
L_F:
		MOV	AX,1
		JMP	SHORT L_H1
;※向左下画线※--------------------------------------------------------------
;格式:CHR(14)+"G长度]"
L_G:
		MOV	AX,-1
		JMP	SHORT L_X1
;※向左上画线※--------------------------------------------------------------
;格式:CHR(14)+"H长度]"
L_H:
		MOV	AX,-1
L_H1:
		MOV	BX,AX
		JMP	SHORT L_Y2
;※向上画线※----------------------------------------------------------------
;格式:CHR(14)+"U长度]"
L_U:
		XOR	AX,AX
L_U1:
		MOV	BX,-1
		JMP	SHORT L_Y2
;※向下画线※----------------------------------------------------------------
;格式:CHR(14)+"X长度]"
L_X:
		XOR	AX,AX
L_X1:
		MOV	BX,1
		JMP	SHORT L_Y2
;※向左画线※----------------------------------------------------------------
;格式:CHR(14)+"Z长度]"
L_Z:
		MOV	AX,-1
		JMP	SHORT L_Y1
;※向右画线※----------------------------------------------------------------
;格式:CHR(14)+"Y长度]"
L_Y:
		MOV	AX,1
L_Y1:
		XOR	BX,BX
L_Y2:
		MOV	D_D9,AX 		;增量
		MOV	D_DB,BX
		CALL	S_QK			;取参数并乘比例因子
L_Y3:
		MOV	BP,AX
		CALL	S_PUSHD 		;保存起点坐标
		CALL	S_LINE2 		;画线
		CALL	S_POPD			;恢复起点坐标
		JMP	L_ST

;子程序:保存初值再画线
S_LINE:
		PUSH	CX
		PUSH	DX
		CALL	S_LINE1
		POP	DX
		POP	CX
		RET
;子程序:先画初点再画线
S_LINE1:
		CALL	S_D
		OR	BP,BP
		JZ	L_LINE3
;子程序:画线
S_LINE2:
		MOV	AX,D_D1
		ADD	AX,D_D9
		CMP	AX,0
		JB	L_LINE3
		CMP	AX,D_D5
		JA	L_LINE3
		MOV	D_D1,AX
		MOV	AX,D_D3
		ADD	AX,D_DB
		CMP	AX,0
		JB	L_LINE3
		CMP	AX,D_D7
		JA	L_LINE3
		MOV	D_D3,AX
		CALL	S_D
		DEC	BP
		JNZ	S_LINE2
L_LINE3:
		RET

;※执行INT10※---------------------------------------------------------------
;格式:CHR(14)+"I寄存器参数串]"
;		寄存器参数串为AH,AL,BH,BL,CH,CL,DH,DL的值
;		当AH=255时,AL为执行的中断号,其余顺序为AH,AL,...
;		返回值存放在0:4F0H开始的14个字节中,顺序为AX,BX,CX,DX,BP,SI,DI
L_I:
		MOV	DI,OFFSET D_BUF1
L_I1:
		CALL	S_Q			;取参数
		STOSB
		CMP	BYTE PTR [SI],','       ;判下一参数
		JNZ	L_I2
		INC	SI
		JMP	SHORT L_I1
L_I2:
		XOR	AL,AL
L_I3:
		CMP	DI,OFFSET D_BUF1+10
		JZ	L_I4
		STOSB				;清其他寄存器
		JMP	SHORT L_I3
L_I4:
		PUSH	SI
		MOV	DI,OFFSET D_BUF1	;寄存器参数区
		MOV	AX,[DI]
		CMP	AL,-1			;判执行其他中断?
		JNZ	L_I5
		MOV	D_INT[1],AH		;中断号
		ADD	DI,2
		MOV	AX,[DI]
L_I5:
		MOV	BX,[DI+2]
		MOV	CX,[DI+4]
		MOV	DX,[DI+6]
		XCHG	AL,AH
		XCHG	BL,BH
		XCHG	CL,CH
		XCHG	DL,DH
D_INT		DB	0CDH,10H		;INT 10
		MOV	D_INT[1],10H		;恢复INT 10H
		PUSH	DI
		XOR	DI,DI
		MOV	DS,DI
		MOV	DI,4F0H 		;返回参数区
		MOV	[DI],AX
		MOV	[DI+2],BX
		MOV	[DI+4],CX
		MOV	[DI+6],DX
		MOV	[DI+8],BP
		MOV	[DI+10],SI
		MOV	BX,DI
		POP	AX
		MOV	[BX+12],AX
		POP	SI
		PUSH	CS
		POP	DS
		JMP	L_ST

;※执行命令串※--------------------------------------------------------------
;格式:CHR(14)+"J]"
L_J:
		PUSH	SI
		MOV	SI,OFFSET D_BUF3	;命令串首
		CMP	BYTE PTR [SI],0
		JZ	L_J1
		CALL	S_ST			;执行
L_J1:
		POP	SI
		JMP	L_ST

;※定义命令串※--------------------------------------------------------------
;格式:CHR(14)+"W...]"
L_W:
		MOV	DI,OFFSET D_BUF3	;命令串首
L_W1:
		CMP	DI,OFFSET D_BUF3+1FEH
		JZ	L_W2
		LODSB
		STOSB
		CMP	AL,']'                  ;判终止符
		JNZ	L_W1
		RET
L_W2:
		MOV	AL,']'
		STOSB
		RET

;※设置比例因子※------------------------------------------------------------
;格式:CHR(14)+"K比例因子]"
L_K:
		CALL	S_Q			;取参数
		MOV	D_100,AL
		JMP	L_ST

;※画斜线※------------------------------------------------------------------
;格式1:CHR(14)+"L终点X,Y]"      (绝对坐标)
;格式2:CHR(14)+"L±终点X,±Y]"  (相对坐标)
;格式3:CHR(14)+"L/长度,角度]"   (以向右为0度)
L_L:
		CMP	BYTE PTR DS:[SI],'/'    ;以角度画线
		JNZ	L_0462
		CALL	S_Q0			;取长度
		MOV	BP,AX
		CALL	S_Q0			;取角度
		PUSH	AX
		SUB	AX,180
		JNB	L_457A
		NEG	AX
L_457A:
		CMP	AX,90
		JB	L_457B
		SUB	AX,180
		NEG	AX
L_457B:
		PUSH	AX
		CMP	AL,45
		JBE	L_457C
		SUB	AL,90
		NEG	AL
L_457C:
		MOV	BX,AX
		SHL	BX,1
		MOV	AX,D_SIN[BX]		;求SIN值
		MUL	BP
		MOV	CX,10000
		DIV	CX
		MOV	CX,AX			;CX=Y
		CALL	S_GOGU			;BX=X
		POP	AX			;角度
		CMP	AL,45
		JBE	L_457D
		XCHG	BX,CX
L_457D:
		POP	AX
		MOV	DX,D_D3
		SUB	AX,180			;AX-180
		JNB	L_0458
		SUB	DX,CX
		NEG	AX
		JMP	SHORT L_0459
L_0458:
		ADD	DX,CX
L_0459:
		MOV	D_E3,DX
		MOV	DX,D_D1
		SUB	AX,90			;AX-90
		JNB	L_0460
		SUB	DX,BX
		JMP	SHORT L_0461
L_0460:
		ADD	DX,BX
L_0461:
		MOV	D_E1,DX
		OR	D_EF,2			;画线不移当前点
		JMP	SHORT L_0490
L_0462:
		CALL	S_0569			;取终点X
		JNB	L_0488			;无符号转
		CALL	S_QK1			;乘比例因子
		MOV	CX,1
		CMP	BP,2			;判'-'?
		JNZ	L_0468
		NEG	CX
L_0468:
		MOV	D_E1,AX
		MOV	D_D9,CX
		INC	SI
		CALL	S_0569			;取终点Y
		CALL	S_QK1			;乘比例因子
		MOV	CX,1
		CMP	BP,2			;判'-'?
		JNZ	L_047F
		NEG	CX
L_047F:
		MOV	D_E3,AX
		MOV	D_DB,CX
		JMP	SHORT L_04B4
L_0488:
		MOV	D_E1,AX
		INC	SI
		CALL	S_0569			;取终点Y
		MOV	D_E3,AX
L_0490:
		MOV	AX,D_E1
		MOV	CX,1
		SUB	AX,D_D1 		;终点X-初点X
		JNB	L_0495
		NEG	CX
		NEG	AX
L_0495:
		MOV	D_E1,AX
		MOV	D_D9,CX
		MOV	AX,D_E3
		SUB	AX,D_D3 		;终点Y-初点Y
		MOV	CX,1
		JNB	L_04AD
		NEG	CX
		NEG	AX
L_04AD:
		MOV	D_E3,AX
		MOV	D_DB,CX
L_04B4:
		CALL	S_D			;画初点
		CALL	S_PUSHD 		;保存
		MOV	AX,D_E1 		;终点X
		CMP	AX,D_E3 		;与Y比
		JB	L_04C8
		CALL	S_04CF
		JMP	SHORT L_04CB
L_04C8:
		CALL	S_051C
L_04CB:
		CALL	S_POPD
		JMP	L_ST

;子程序:X>Y画线
S_04CF:
		MOV	AX,D_E1
		MOV	D_E9,AX
		INC	D_E9
		SHR	AX,1
		MOV	D_E5,AX
		MOV	D_E7,0
		MOV	AX,D_DB
		MOV	D_EB,AX
		JMP	SHORT L_04F2
L_04EC:
		MOV	BP,1
		CALL	S_LINE2
L_04F2:
		MOV	D_DB,0
		MOV	AX,D_E3
		ADD	AX,D_E7
		MOV	D_E7,AX
		CMP	AX,D_E5
		JLE	L_0515
		SUB	AX,D_E1
		MOV	D_E7,AX
		MOV	AX,D_EB
		MOV	D_DB,AX
L_0515:
		DEC	D_E9
		JNZ	L_04EC
		RET

;子程序:X<Y画线
S_051C:
		MOV	AX,D_E3
		MOV	D_E9,AX
		INC	D_E9
		SHR	AX,1
		MOV	D_E7,AX
		MOV	D_E5,0
		MOV	AX,D_D9
		MOV	D_EB,AX
		JMP	SHORT L_053F
L_0539:
		MOV	BP,1
		CALL	S_LINE2
L_053F:
		MOV	D_D9,0
		MOV	AX,D_E1
		ADD	AX,D_E5
		MOV	D_E5,AX
		CMP	AX,D_E7
		JLE	L_0562
		SUB	AX,D_E3
		MOV	D_E5,AX
		MOV	AX,D_EB
		MOV	D_D9,AX
L_0562:
		DEC	D_E9
		JNZ	L_0539
		RET

;子程序:取参数并判符号
S_0569:
		XOR	BP,BP
		CMP	BYTE PTR [SI],'+'
		JNZ	L_0574
		INC	BP
		INC	SI
		JMP	SHORT L_057D
L_0574:
		CMP	BYTE PTR [SI],'-'
		JNZ	L_057D
		MOV	BP,2
		INC	SI
L_057D:
		CALL	S_Q
		OR	BP,BP
		JNZ	L_0586
		CLC
		RET
L_0586:
		STC
		RET

;※前缀:移当前点但不画线※---------------------------------------------------
;格式:CHR(14)+"M...]"
L_M:
		OR	D_EF,1
		JMP	L_ST

;※前缀:画线但不移当前点※---------------------------------------------------
;格式:CHR(14)+"N...]"
L_N:
		OR	D_EF,2
		JMP	L_ST

;※画圆※--------------------------------------------------------------------
;格式:CHR(14)+"O圆心X,Y,半径,方式]"  (方式=0半圆,=1半圆弧,其他为圆)
L_O:
		CALL	S_Q			;取圆心X
		PUSH	AX
		CALL	S_Q0			;取圆心Y
		PUSH	AX
		CALL	S_Q0			;取半径
		MOV	BP,AX
		MOV	AX,707
		MUL	BP
		MOV	DI,1000
		DIV	DI
		INC	AX
		MOV	D_E1,AX 		;R*0.707
		MOV	D_E3,-1
		CMP	BYTE PTR DS:[SI],','
		JNZ	L_O2
		CALL	S_Q0			;取方式:0-半,1-半圆弧,其他圆
		CMP	AL,1
		JA	L_O2
		MOV	BYTE PTR D_E3,AL
L_O2:
		MOV	AL,D_EE
		MOV	BYTE PTR D_E3+1,AL
		POP	DI			;Y
		POP	AX			;X
		PUSH	SI
		MOV	SI,AX
		MOV	AX,D_E1 		;DLT-Y
L_O3:
		CALL	S_GOGU			;AX^2+BP^2→BX^2
		MOV	DX,DI			;Y
		SUB	DX,AX
		MOV	CX,SI			;X
		MOV	D_E5,BX
		CALL	S_XYHX			;填充
		ADD	CX,BX
		CALL	S_DOT
		MOV	CX,SI
		SUB	CX,BX
		CALL	S_DOT
		MOV	DX,DI
		SUB	DX,BX
		MOV	CX,SI
		MOV	D_E5,AX
		CALL	S_XYHX			;填充
		ADD	CX,AX
		CALL	S_DOT
		MOV	CX,SI
		SUB	CX,AX
		CALL	S_DOT
		CMP	BYTE PTR D_E3,0FFH	;半圆?
		JNZ	L_O4
		MOV	DX,DI
		ADD	DX,AX
		MOV	CX,SI
		MOV	D_E5,BX
		CALL	S_XYHX			;填充
		ADD	CX,BX
		CALL	S_DOT
		MOV	CX,SI
		SUB	CX,BX
		CALL	S_DOT
		MOV	DX,DI
		ADD	DX,BX
		MOV	CX,SI
		MOV	D_E5,AX
		CALL	S_XYHX			;填充
		ADD	CX,AX
		CALL	S_DOT
		MOV	CX,SI
		SUB	CX,AX
		CALL	S_DOT
L_O4:
		OR	AX,AX
		JZ	L_O4A
		DEC	AX
		JMP	SHORT L_O3
L_O4A:
		MOV	AX,SI
		POP	SI
		CMP	BYTE PTR D_E3,0 	;半圆?
		JNZ	L_O5
		SUB	AX,BP			;(AX,DI)为半圆左端
		MOV	D_D1,AX
		MOV	D_D3,DI
		MOV	D_D9,1
		MOV	D_DB,0
		MOV	AX,BP
		SHL	AX,1
		JMP	L_Y3
L_O5:
		JMP	L_ST

;子程序:向右画横线 中点:CX,DX 半长D_E5
S_XYHX:
		CMP	BYTE PTR D_E3+1,0FFH
		JZ	L_XYHX2
		CMP	D_E5,2
		JBE	L_XYHX2
		PUSH	CX
		SUB	CX,D_E5
		SHL	D_E5,1
		PUSH	AX
		MOV	AL,BYTE PTR D_E3+1
L_XYHX1:
		CALL	S_D3			;画点
		INC	CX
		DEC	D_E5
		JNZ	L_XYHX1
		POP	AX
		POP	CX
L_XYHX2:
		RET

;子程序:GOGU (求勾股数) AX^2+BP^2=BX^2
S_GOGU:
		PUSH	AX
		PUSH	CX
		MUL	AX
		MOV	BX,AX
		MOV	CX,DX
		MOV	AX,BP
		MUL	AX
		SUB	AX,BX
		SBB	DX,CX
S_SQR:
		PUSH	BP
		PUSH	DX
		PUSH	AX
		MOV	BP,SP
		MOV	BX,300
		DIV	BX
		ADD	AX,2
L_SQR1:
		MOV	BX,AX
		MOV	AX,[BP]
		MOV	DX,[BP+2]
		DIV	BX
		ADD	AX,BX
		SHR	AX,1
		CMP	AX,BX
		JZ	L_SQR2
		SUB	BX,AX
		CMP	BX,1
		JZ	L_SQR2
		CMP	BX,-1
		JNZ	L_SQR1
L_SQR2:
		MOV	BX,AX
		POP	AX
		POP	DX
		POP	BP
		POP	CX
		POP	AX
		RET

;※填充※--------------------------------------------------------------------
;格式:CHR(14)+"P内色,边界色]"
L_P:
		CALL	S_Q
		CMP	AL,D_D0
		JA	L_060C
		MOV	BYTE PTR D_E1,AL
		CALL	S_Q0
		CMP	AL,D_D0
		JA	L_060C
		MOV	BYTE PTR D_E1+1,AL
		MOV	CX,D_D1
		MOV	DX,D_D3
		CALL	S_06F6
		JB	L_060C
		CMP	AL,BYTE PTR D_E1+1
		JZ	L_060C
		MOV	BX,CX
L_05B6:
		DEC	CX
		CALL	S_06F6
		JB	L_05C6
		CMP	AL,BYTE PTR D_E1+1
		JZ	L_05C6
		MOV	BX,CX
		JMP	SHORT L_05B6
L_05C6:
		MOV	D_E3,BX
		PUSH	BX
		MOV	CX,D_D1
		MOV	BX,CX
L_05D1:
		INC	CX
		CALL	S_06F6
		JB	L_05E1
		CMP	AL,BYTE PTR D_E1+1
		JZ	L_05E1
		MOV	BX,CX
		JMP	SHORT L_05D1
L_05E1:
		MOV	D_E5,BX
		PUSH	BX
		SUB	BX,D_E3
		INC	BX
		MOV	CX,D_E3
L_05EF:
		MOV	AL,BYTE PTR D_E1
		CALL	S_D3
		INC	CX
		DEC	BX
		JNZ	L_05EF
		PUSH	DX
		DEC	DX
		CALL	S_060D
		POP	DX
		INC	DX
		POP	D_E5
		POP	D_E3
		CALL	S_060D
L_060C:
		JMP	L_ST

;子程序:
S_060D:
		MOV	CX,D_E3
		MOV	D_E7,CX
L_0611:
		MOV	CX,D_E7
		CALL	S_06F6
		JNB	L_061F
		RET
L_061F:
		CMP	AL,BYTE PTR D_E1+1
		JZ	L_0647
		CMP	AL,BYTE PTR D_E1
		JZ	L_0647
		MOV	D_E9,CX
		MOV	BX,CX
L_0631:
		DEC	CX
		CALL	S_06F6
		JB	L_0641
		CMP	AL,BYTE PTR D_E1+1
		JZ	L_0641
		MOV	BX,CX
		JMP	SHORT L_0631
L_0641:
		MOV	D_E7,BX
		JMP	SHORT L_066A
L_0647:
		INC	CX
L_0648:
		CMP	CX,D_E5
		JG	L_0662
		CALL	S_06F6
		JB	L_0662
		CMP	AL,BYTE PTR D_E1
		JZ	L_065F
		CMP	AL,BYTE PTR D_E1+1
		JNE	L_0662
L_065F:
		INC	CX
		JMP	SHORT L_0648
L_0662:
		MOV	D_E7,CX
		MOV	D_E9,CX
L_066A:
		MOV	BX,D_E7
		CMP	BX,D_E5
		JLE	L_0675
		RET
L_0675:
		MOV	BX,D_E9
		MOV	CX,BX
L_067B:
		INC	CX
		CALL	S_06F6
		JB	L_068B
		CMP	AL,BYTE PTR D_E1+1
		JZ	L_068B
		MOV	BX,CX
		JMP	SHORT L_067B
L_068B:
		MOV	D_E9,BX
		MOV	CX,D_E7
		SUB	BX,CX
		INC	BX
L_0696:
		MOV	AL,BYTE PTR D_E1
		CALL	S_D3
		INC	CX
		DEC	BX
		JNZ	L_0696
		PUSH	D_E3
		PUSH	D_E5
		MOV	CX,D_E7
		PUSH	CX
		MOV	D_E3,CX
		MOV	CX,D_E9
		PUSH	CX
		MOV	D_E5,CX
		PUSH	DX
		DEC	DX
		CALL	S_060D
		POP	DX
		POP	CX
		MOV	D_E5,CX
		MOV	D_E9,CX
		POP	AX
		MOV	D_E3,AX
		MOV	D_E7,AX
		PUSH	CX
		PUSH	DX
		INC	DX
		CALL	S_060D
		POP	DX
		POP	CX
		MOV	D_E9,CX
		ADD	CX,2
		MOV	D_E7,CX
		POP	D_E5
		POP	D_E3
		CMP	CX,D_E5
		JG	L_06F5
		JMP	L_0611
L_06F5:
		RET

;子程序:
S_06F6:
		CMP	CX,0
		JB	L_0716
		CMP	CX,D_D5
		JG	L_0716
		CMP	DX,0
		JB	L_0716
		CMP	DX,D_D7
		JG	L_0716
		PUSH	BX
		XOR	BX,BX
		MOV	AH,0DH
		CALL	INT10
		POP	BX
		CLC
		RET
L_0716:
		MOV	AL,0FFH
		STC
		RET

;※清屏并初始化参数※--------------------------------------------------------
;格式:CHR(14)+"Q屏幕色]"  (若无屏幕色则为黑色)
L_Q:
		CALL	S_CLS
		PUSH	SI
		CALL	S_0			;初始化参数
		POP	SI
		CALL	S_Q			;取屏幕颜色
		OR	AL,AL
		JZ	L_Q2
		MOV	CX,9600H
		CMP	D_FB,12H		;VGA
		JZ	L_Q1
		CMP	D_FB,10H		;EGA
		JNZ	L_Q2
		MOV	CX,6D60H
L_Q1:
		CLI
		MOV	AH,AL
		MOV	AL,2
		MOV	DX,3C4H
		OUT	DX,AX			;置颜色
		MOV	ES,D_A000
		XOR	DI,DI
		MOV	AL,0FFH
		REP	STOSB
		MOV	AX,0F02H
		OUT	DX,AX			;恢复
		MOV	AH,15H			;开光标
		CALL	INT10
		STI
		PUSH	CS
		POP	ES
L_Q2:
		JMP	L_ST

;子程序:清屏
S_CLS:
		PUSH	SI
		PUSH	DI
		PUSH	CX
		PUSH	DX
		PUSH	BX
		MOV	AX,1406H
		INT	10H
		CMP	BL,0			;判直接写屏?
		JZ	L_Q0
		MOV	AL,3
L_Q0:
		XOR	AH,AH
		CALL	INT10			;清屏
		POP	BX
		POP	DX
		POP	CX
		POP	DI
		POP	SI
		RET

;※光标控制※----------------------------------------------------------------
;格式:CHR(14)+"R0或1]"  (0无1有)
L_R:
		CALL	S_Q
		OR	AL,AL
		JNZ	L_R1
		MOV	AH,15H
		CALL	INT10
L_R1:
		MOV	AH,17H
		CALL	INT10
		OR	AL,AL
		JZ	L_R2
		MOV	AH,15H
		CALL	INT10
L_R2:
		JMP	L_ST

;※置字符前景背景颜色※------------------------------------------------------
;格式:CHR(14)+"S前景色,背景色]"
L_S:
		CALL	S_Q			;取参数:前景色
		AND	D_FD,0F0H
		OR	D_FD,AL
		CMP	BYTE PTR [SI],','
		JNZ	L_S1
		CALL	S_Q0			;取参数:背景色
		MOV	CL,4
		SHL	AL,CL
		AND	D_FD,0FH
		OR	D_FD,AL
L_S1:
		JMP	L_ST

;※简繁转换※----------------------------------------------------------------
;格式:CHR(14)+"T0或1]"  (0繁1简)
L_T:
		CALL	S_Q			;取参数
		CMP	AL,1
		JA	L_T1
		ADD	AL,17
		MOV	AH,18H
		INT	10H
L_T1:
		JMP	L_ST

;※矩形区填充线※------------------------------------------------------------
;格式:CHR(14)+"V色号,X,Y,宽,高,类型,间隔,线宽,方式]"
;	X,Y为左下角,类型1为横线,2为竖线,3为左斜线,4为右斜线
;	方式=1画边框线,0=不画
L_V:
		MOV	DI,OFFSET D_BUF2
L_V2:
		CALL	S_Q
		STOSW				;存参数
		CMP	BYTE PTR [SI],','
		JNZ	L_V3
		INC	SI
		JMP	SHORT L_V2
L_V3:
		XOR	AX,AX
L_V4:
		CMP	DI,OFFSET D_BUF2+12H
		JZ	L_V5
		STOSW				;清参数
		JMP	SHORT L_V4
L_V5:
		PUSH	SI
		MOV	BX,OFFSET D_BUF2
		MOV	CX,DS:[BX+2]		;X
		MOV	DX,DS:[BX+4]		;Y
		MOV	DI,DS:[BX+6]		;宽
		CMP	DI,2
		JBE	L_V7
		MOV	SI,DS:[BX+8]		;高
		CMP	SI,2
		JBE	L_V7
		CMP	BYTE PTR DS:[BX+16],0
		JZ	L_V6
		SUB	DX,SI
		CALL	S_JX			;画矩形
L_V6:
		CALL	S_V			;填线
L_V7:
		POP	SI
		JMP	L_ST

;子程序:矩形区填线 入口参数:从D_BUF2开始放V命令诸参数(八个字)
S_V:
		MOV	AL,[BX]
		MOV	D_ED,AL
		INC	WORD PTR [BX+2] 	;X+1
		DEC	WORD PTR [BX+4] 	;Y-1
		SUB	WORD PTR [BX+6],2	;宽-2
		SUB	WORD PTR [BX+8],2	;高-2
		MOV	AX,[BX+0AH]		;类型

		CMP	AL,1			;<横线>
		JNZ	L_SV2
		MOV	D_D9,AX 		;=1
		DEC	AX
		MOV	D_DB,AX 		;=0
		MOV	DI,[BX+4]		;Y
		SUB	DI,[BX+8]		;-高
L_SV11:
		ADD	DI,[BX+0CH]		;+间隔
		MOV	DX,1
L_SV12:
		MOV	BP,[BX+6]		;宽
		CMP	DI,[BX+4]		;Y
		JG	L_SV19
		MOV	D_D3,DI
		MOV	AX,[BX+2]		;X
		MOV	D_D1,AX
		CALL	S_LINE			;画线
		INC	DI
		INC	DX
		CMP	DX,[BX+0EH]		;线宽
		JG	L_SV11
		JMP	SHORT L_SV12
L_SV19:
		RET
L_SV2:
		CMP	AL,2
		JNZ	L_SV3
		XOR	AX,AX
		MOV	D_D9,AX 		;=0
		NOT	AX
		MOV	D_DB,AX 		;=-1
		MOV	DI,[BX+2]
		MOV	CX,DI
		ADD	CX,[BX+6]
L_SV21:
		ADD	DI,[BX+0CH]
		MOV	DX,1
L_SV22:
		MOV	BP,[BX+8]
		CMP	DI,CX
		JG	L_SV19
		MOV	D_D1,DI
		MOV	AX,[BX+4]
		MOV	D_D3,AX
		CALL	S_LINE
		INC	DI
		INC	DX
		CMP	DX,[BX+0EH]
		JG	L_SV21
		JMP	SHORT L_SV22
L_SV3:
		CMP	AL,3
		JNZ	L_SV4
		MOV	AX,1
		MOV	D_D9,AX
		NEG	AX			;=-1
		MOV	D_DB,AX
		MOV	SI,[BX+2]
		MOV	DI,[BX+4]
		SUB	DI,[BX+8]
		MOV	AX,DI
		ADD	AX,[BX+6]
		MOV	[BX+10H],AX
		MOV	AX,[BX+4]
		ADD	AX,[BX+6]
		MOV	[BX+12H],AX
L_SV31:
		ADD	DI,[BX+0CH]
		MOV	DX,1
L_SV32:
		CMP	DI,[BX+12H]
		JG	L_SV39
		MOV	BP,[BX+6]
		CMP	DI,[BX+10H]
		JGE	L_SV33
		MOV	BP,DI
		ADD	BP,[BX+8]
		SUB	BP,[BX+4]
L_SV33:
		MOV	D_D1,SI
		MOV	D_D3,DI
		CMP	DI,[BX+4]
		JLE	L_SV34
		MOV	AX,DI
		SUB	AX,[BX+4]
		SUB	BP,AX
		ADD	D_D1,AX
		MOV	AX,[BX+4]
		MOV	D_D3,AX
L_SV34:
		CALL	S_LINE
		INC	DI
		INC	DX
		CMP	DX,[BX+0EH]
		JG	L_SV31
		JMP	SHORT L_SV32
L_SV39:
		RET
L_SV4:
		MOV	AX,-1
		MOV	D_D9,AX
		MOV	D_DB,AX
		MOV	SI,[BX+2]
		ADD	SI,[BX+6]
		MOV	DI,[BX+4]
		SUB	DI,[BX+8]
		MOV	AX,DI
		ADD	AX,[BX+6]
		MOV	[BX+10H],AX
		MOV	AX,[BX+4]
		ADD	AX,[BX+6]
		MOV	[BX+12H],AX
L_SV41:
		ADD	DI,[BX+0CH]
		MOV	DX,1
L_SV42:
		MOV	BP,[BX+6]
		CMP	DI,[BX+12H]
		JG	L_SV39
		CMP	DI,[BX+10H]
		JGE	L_SV43
		MOV	BP,DI
		ADD	BP,[BX+8]
		SUB	BP,[BX+4]
L_SV43:
		MOV	D_D1,SI
		MOV	D_D3,DI
		CMP	DI,[BX+4]
		JLE	L_SV44
		MOV	AX,DI
		SUB	AX,[BX+4]
		SUB	BP,AX
		SUB	D_D1,AX
		MOV	AX,[BX+4]
		MOV	D_D3,AX
L_SV44:
		CALL	S_LINE
		INC	DI
		INC	DX
		CMP	DX,[BX+0EH]
		JG	L_SV41
		JMP	SHORT L_SV42

;----------------------------------------------------------------------------
;子程序:处理形如'@宽度,高度,字体'的设置字型命令
S_ZX:
		CALL	S_Q			;取宽度
		OR	AX,AX
		JZ	L_ZX2
		CMP	AX,D_D5 		;最大X坐标?
		JBE	L_ZX1
		MOV	AX,D_D5
L_ZX1:
		MOV	D_X,AX			;汉字的宽度
L_ZX2:
		CMP	BYTE PTR DS:[SI],','    ;有无高度?
		JNZ	L_ZX9
		CALL	S_Q0			;取高度
		OR	AX,AX
		JZ	L_ZX4
		CMP	AX,D_D7 		;最大Y坐标?
		JBE	L_ZX3
		MOV	AX,D_D7
L_ZX3:
		MOV	D_Y,AX			;汉字的高度
L_ZX4:
		CMP	BYTE PTR DS:[SI],','    ;有无字体?
		JNZ	L_ZX9
		CALL	S_Q0
		MOV	[DI],AL
L_ZX9:
		RET

;子程序:处理形如'@A-z'的设置字型命令
S_ZXA:
		CMP	AL,'P'
		JA	L_ZXA2
		SUB	AL,'A'                  ;字型A-P
L_ZXA1:
		MOV	BL,AL
		MOV	AL,D_ZX[BX]
		JMP	SHORT L_ZXA7
L_ZXA2:
		CMP	AL,'T'
		JA	L_ZXA3
		SUB	AL,'Q'                  ;字型Q-T
		MOV	DL,1			;16点阵
		JMP	SHORT L_ZXA1
L_ZXA3:
		CMP	AL,'a'
		JAE	L_ZXA4
		SUB	AL,'U'                  ;字型U-X:40点阵
		MOV	[DI],AL
		MOV	AX,40
		MOV	D_X,AX
		MOV	D_Y,AX
		RET
L_ZXA4:
		CMP	AL,'p'
		JA	L_ZXA5
		SUB	AL,'a'                  ;字型a-p
		MOV	DL,0AH			;再扩
		JMP	SHORT L_ZXA1
L_ZXA5:
		CMP	AL,'t'
		JA	L_ZXA6
		SUB	AL,'q'                  ;字型q-t
		MOV	DL,1			;16点阵
		JMP	SHORT L_ZXA1
L_ZXA6:
		SUB	AL,'u'                  ;字型u-x
		MOV	DL,1
		JMP	SHORT L_ZXA1
L_ZXA7:
		CMP	DL,1
		JNZ	L_ZXA8
		SUB	AL,20H
		JMP	SHORT L_ZXA9
L_ZXA8:
		OR	AL,DL
L_ZXA9:
		MOV	[DI],AL
		RET

D_ZX		DB	40H,41H,44H,45H 	;ABCD
		DB	50H,51H,54H,55H 	;EFGH
		DB	60H,61H,64H,65H 	;IJKL
		DB	70H,71H,74H,75H 	;MNOP
D_SL		DB	0			;0:点阵,0FFH:矢量
D_X		DW	24			;宽度
D_Y		DW	24			;高度
D_XB		DW	24			;水平实际宽度
D_XY		DW	0
D_YB		DW	0			;一次处理行数
D_XS		DW	0			;保存D_D1
D_YS		DW	0			;保存D_D3
;【显示汉字】
L_XSHZ:
		MOV	DI,OFFSET D_F0
L_HZ1:
		LODSB

		CMP	AL,'['
		JZ	L_HZ1

		CMP	AL,'@'                  ;<设置字型>
		JNZ	L_HZ20
		XOR	BH,BH
		XOR	DL,DL
		MOV	AL,[SI]
		CMP	AL,'9'
		JA	L_HZ10
		MOV	D_SL,0FFH		;0FFH(本格式状态标志)
		CALL	S_ZX			;'@宽度,高度,字体'格式
		JMP	SHORT L_HZ1
L_HZ10:
		AND	AL,5FH
		CMP	AL,'A'
		JB	L_HZ1
		CMP	AL,'X'
		JA	L_HZ1
		LODSB
		MOV	D_SL,0			;0 (普通格式'@A,旋转')
		CALL	S_ZXA			;'@A-z'格式
		JMP	SHORT L_HZ1
L_HZ20:
		CMP	AL,'*'                  ;<前景色>
		JNZ	L_HZ21
		CALL	S_Q
		MOV	D_F1,AL
		JMP	L_HZ1
L_HZ21:
		CMP	AL,'#'                  ;<背景色>
		JNZ	L_HZ22
		CALL	S_Q
		MOV	D_F2,AL
		JMP	L_HZ1
L_HZ22:
		CMP	AL,'_'                  ;<水平定位>
		JNZ	L_HZ23
		CALL	S_Q
		MOV	D_D1,AX
		JMP	L_HZ1
L_HZ23:
		CMP	AL,'|'                  ;<垂直定位>
		JNZ	L_HZ24
		CALL	S_Q
		MOV	D_D3,AX
		JMP	L_HZ1
L_HZ24:
		CMP	AL,'^'                  ;<字间距>
		JNZ	L_HZ25
		CALL	S_Q
		MOV	D_F3,AX
		JMP	L_HZ1
L_HZ25:
		CMP	AL,'&'                  ;<行间距>
		JNZ	L_HZ26
		CALL	S_Q
		MOV	D_F5,AX
		JMP	L_HZ1
L_HZ26:
		CMP	AL,'\'                  ;<复盖>
		JNZ	L_HZ3
		CALL	S_Q
		CMP	AL,0
		JZ	L_HZ27
		MOV	AL,3
L_HZ27:
		MOV	BYTE PTR D_FG1,AL
		MOV	BYTE PTR D_FG2,AL
		JMP	L_HZ1
L_HZ3:
		CMP	AL,']'                  ;<结束>
		JNZ	L_HZ4
L_HZ31:
		MOV	AX,D_F7
		ADD	AX,D_F5
		MOV	D_D3,AX
		XOR	AX,AX
		MOV	D_D1,AX
		MOV	D_F7,AX
		RET
L_HZ4:
		CMP	D_SL,0FFH		;矢量汉字?
		JNZ	L_HZ40
		MOV	CX,D_X			;宽度
		CMP	AL,0A1H 		;判汉字?
		JNB	L_HZ4A
		XOR	AH,AH
		SHR	CX,1
		JMP	SHORT L_HZ4B
L_HZ4A:
		MOV	AH,AL
		LODSB
L_HZ4B:
		MOV	DX,AX
		PUSH	SI
		MOV	BX,CX
		JMP	SHORT L_HZ53
L_HZ40:
		CMP	AL,0A1H 		;判汉字?
		JNB	L_HZ42
		XOR	AH,AH
		JMP	SHORT L_HZ43
L_HZ42:
		MOV	AH,AL
		LODSB
L_HZ43:
		MOV	DX,AX
		PUSH	SI
		CALL	S_READZK		;读点阵字库

		MOV	BX,CX
		TEST	BYTE PTR [DI],1 	;横扩?
		JZ	L_HZ51
		SHL	BX,1
L_HZ51:
		TEST	BYTE PTR [DI],2 	;再扩?
		JZ	L_HZ53
		SHL	BX,1
L_HZ53:
		MOV	AX,D_D5 		;横向最宽
		INC	AX
		SUB	AX,D_D1 		;-当前
		JB	L_HZ54
		CMP	AX,BX
		JNB	L_HZ55
L_HZ54:
		MOV	AX,D_F7 		;行最下点
		ADD	AX,D_F5 		;加行间距
		MOV	D_D3,AX 		;=Y
		XOR	AX,AX
		MOV	D_D1,AX 		;X=0
		MOV	D_F7,AX
L_HZ55:
		MOV	AX,D_D3 		;Y
		CMP	D_SL,0FFH
		JNZ	L_HZ56
		ADD	AX,D_Y
		JMP	SHORT L_HZ59
L_HZ56:
		MOV	BX,CX
		TEST	BYTE PTR [DI],4 	;横扩?
		JZ	L_HZ57
		SHL	BX,1
L_HZ57:
		TEST	BYTE PTR [DI],8 	;再扩?
		JZ	L_HZ58
		SHL	BX,1
L_HZ58:
		ADD	AX,BX
L_HZ59:
		CMP	AX,D_D7 		;比纵向扫描线
		JBE	L_HZ60
		MOV	AX,0E07H		;响铃
		CALL	INT10
		XOR	AH,AH			;按键
		INT	16H
		CMP	AL,1BH			;<ESC>?
		JNZ	L_HZ5A
		POP	SI
		JMP	L_HZ31
L_HZ5A:
		CALL	S_CLS
		XOR	AX,AX
		MOV	D_D3,AX 		;Y=0
L_HZ60:
		CMP	D_SL,0FFH		;矢量汉字?
		JZ	L_HZ70
		CMP	BYTE PTR [DI],40H	;判16点阵?		8.7恢复
		JAE	L_HZ61
		MOV	D_BYTE,2		;行处理2字节
		JMP	SHORT L_HZ62
L_HZ61:
		MOV	D_BYTE,3		;行处理3字节
L_HZ62:
		CALL	S_XSH			;显示一行
		JMP	L_HZ80
L_HZ70:
		XOR	BP,BP
		MOV	ES,BP
		CMP	WORD PTR ES:[1FAH],0	;判安装READSL?
		JNZ	L_HZ70A
		JMP	L_HZ81
L_HZ70A:
		MOV	D_XY,0			;行计数
		MOV	AX,D_D1
		MOV	D_XS,AX 		;保存起点
		MOV	AX,D_D3
		MOV	D_YS,AX
		PUSH	AX
		ADD	AX,D_Y			;起点Y+字型Y
		CMP	AX,D_F7 		;是否超纪录?
		JBE	L_HZ71
		MOV	D_F7,AX
L_HZ71:
		MOV	AX,D_X			;宽
		MOV	CX,D_Y			;高
		MOV	D_YB,24
		OR	AH,AH
		JZ	L_HZ7A
		MOV	D_YB,8
L_HZ7A:
		MOV	SI,D_XY 		;开始行
		MOV	DI,SI
		ADD	DI,D_YB 		;结束行
		CMP	DI,D_Y
		JBE	L_HZ7B
		MOV	BX,D_Y
		MOV	DI,BX
		SUB	BX,SI
		MOV	D_YB,BX
L_HZ7B:
		XOR	BX,BX
		OR	DH,DH
		JZ	L_HZ72
		MOV	BL,D_F0
L_HZ72:
		PUSH	DX
		CALL	S_INT7E 		;读矢量字库		7.6
		MOV	ES,DX
		MOV	SI,BX
		MOV	D_XB,AX 		;实际宽度

		MOV	DL,AL
		AND	DL,7			;位
		MOV	CL,3
		SHR	AX,CL
		MOV	DH,AL			;整字节

		CALL	S_SLH			;显示矢量汉字一行
		POP	DX

		MOV	AX,D_XY
		ADD	AX,D_YB
		MOV	D_XY,AX
		INC	AX
		CMP	AX,D_Y
		JAE	L_HZ73

		MOV	AX,D_XS
		MOV	D_D1,AX
		MOV	AX,D_YS
		ADD	AX,D_YB
		MOV	D_YS,AX
		MOV	D_D3,AX
		JMP	SHORT L_HZ71
L_HZ73:
		POP	D_D3
		MOV	AX,D_XS
		ADD	AX,D_XB
		MOV	D_D1,AX
L_HZ80:
		MOV	AX,D_F3 		;字间距
		ADD	D_D1,AX 		;加
L_HZ81:
		POP	SI
		JMP	L_XSHZ

;子程序:显示矢量汉字一行
S_SLH:
		MOV	CX,D_YB
L_SL0:
		PUSH	CX
		PUSH	D_D1
		OR	DH,DH			;整字节数
		JZ	L_SL2
		MOV	AL,DH
		CBW
		MOV	BP,AX
L_SL1:
		MOV	BL,ES:[SI]		;取一字节
		INC	SI
		MOV	BH,8
		CALL	S_XSB			;显示一字节
		DEC	BP
		JNZ	L_SL1
L_SL2:
		OR	DL,DL
		JZ	L_SL3
		MOV	BH,DL
		MOV	BL,ES:[SI]		;取一字节
		INC	SI
		CALL	S_XSB			;显示一字节
L_SL3:
		INC	D_D3			;Y+1
		POP	D_D1
		POP	CX
		LOOP	L_SL0
		RET

;子程序:显示一字节BH位
S_XSB:
		PUSH	DX
L_XSB0:
		SHL	BL,1
		JB	L_XSB1
		MOV	AL,D_F2 		;背景色
		JMP	SHORT L_XSB2
L_XSB1:
		MOV	AL,D_F1 		;前景色
L_XSB2:
		MOV	D_ED,AL 		;颜色
		CALL	S_XSC			;显示一点
		DEC	BH
		JNZ	L_XSB0
		POP	DX
		RET

;子程序:读点阵字库
S_READZK:
		XOR	BX,BX
		MOV	ES,BX
		MOV	AH,[DI]
		CMP	AH,40H			;判16点阵?
		JAE	L_READZK1
		CMP	WORD PTR ES:[1EAH],0	;判安装READ16?
		JZ	L_READZK3
		INT	7AH			;读16点阵字库
		JMP	SHORT L_READZK2
L_READZK1:
		CMP	WORD PTR ES:[1EEH],0	;判安装READ24?
		JZ	L_READZK4
		INT	7BH			;读24点阵字库
L_READZK2:
		PUSH	DS
		POP	ES
		PUSH	CS
		POP	DS
		RET
L_READZK3:
		MOV	BX,16
		MOV	CX,32
		JMP	SHORT L_READZK5
L_READZK4:
		MOV	BX,24
		MOV	CX,72
L_READZK5:
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_BUF3
		MOV	SI,DI
		XOR	AL,AL
		REP	STOSB
		MOV	CX,BX
		RET

;子程序:读矢量字库
S_INT7E:
		INT	7EH
		RET

;子程序:显示一行
S_XSH:
		PUSH	CX
		CALL	S_XSL			;显示一列
		TEST	BYTE PTR [DI],1 	;横扩
		JZ	L_XSH1
		CALL	S_XSL			;显示一列
L_XSH1:
		TEST	BYTE PTR [DI],2 	;再扩
		JZ	L_XSH2
		CALL	S_XSL			;显示一列
		TEST	BYTE PTR [DI],1 	;横扩
		JZ	L_XSH2
		CALL	S_XSL			;显示一列
L_XSH2:
		POP	CX
		ADD	SI,3
		LOOP	S_XSH
		RET

D_BYTE		DW	3
;子程序:显示一列
S_XSL:
		MOV	BP,D_BYTE		;处理字节数
		PUSH	SI
		PUSH	D_D3
		CMP	BP,3
		JZ	L_XSL1
		INC	SI
L_XSL1:
		MOV	BL,ES:[SI]		;取一字节
		INC	SI
		MOV	BH,8			;八位
L_XSL2:
		SHL	BL,1
		JB	L_XSL3
		MOV	AL,D_F2 		;背景色
		JMP	SHORT L_XSL4
L_XSL3:
		MOV	AL,D_F1 		;前景色
L_XSL4:
		MOV	D_ED,AL 		;颜色
		CALL	S_XSD			;显示一点
		TEST	BYTE PTR [DI],4 	;纵扩?
		JZ	L_XSL5
		CALL	S_XSD			;显示一点
L_XSL5:
		TEST	BYTE PTR [DI],8 	;再扩?
		JZ	L_XSL6
		CALL	S_XSD			;显示一点
		TEST	BYTE PTR [DI],4 	;纵扩?
		JZ	L_XSL6
		CALL	S_XSD			;显示一点
L_XSL6:
		DEC	BH
		JNZ	L_XSL2
		DEC	BP
		JNZ	L_XSL1

		MOV	AX,D_D3 		;最后Y值
		CMP	AX,D_F7 		;与本行最大Y值比?
		JBE	L_XSL7
		MOV	D_F7,AX
L_XSL7:
		POP	D_D3
		POP	SI
		INC	D_D1			;X+1
		RET

;子程序:显示一点(Y+1)
S_XSD:
		CMP	D_ED,0			;颜色=0
		JZ	L_XSD1
D_FG1		EQU	$-1
		CALL	S_D1			;显示点
L_XSD1:
		INC	D_D3			;Y+1
		RET

;子程序:显示一点(X+1)
S_XSC:
		CMP	D_ED,0			;颜色=0
		JZ	L_XSC1
D_FG2		EQU	$-1
		CALL	S_D1			;显示点
L_XSC1:
		INC	D_D1			;X+1
		RET

;公用子程序==================================================================
;子程序:取参数
S_Q0:
		INC	SI
S_Q:
		XOR	CX,CX			;计数
		XOR	DH,DH			;小数点标志
L_SQ1:
		LODSB				;取一字符
		CMP	AL,' '                  ; 空格
		JZ	L_SQ1
		CMP	AL,'.'                  ; 小数点
		JNZ	L_SQ3
		LODSB				;再取一字符
		CMP	AL,'5'
		JB	L_SQ2			;四舍
		INC	CX			;五入
L_SQ2:
		INC	DH			;置小数点标志
		JMP	SHORT L_SQ1
L_SQ3:
		CMP	AL,'0'
		JB	L_SQ4
		CMP	AL,'9'
		JA	L_SQ4
		OR	DH,DH
		JNZ	L_SQ1
		AND	AL,0FH
		CBW
		PUSH	AX
		MOV	AL,0AH
		MUL	CX
		POP	DX
		ADD	AX,DX
		MOV	CX,AX
		JMP	SHORT L_SQ1
L_SQ4:
		MOV	DL,AL
		MOV	AX,CX
		DEC	SI
		CMP	DL,','
		JNZ	L_SQ5
		CLC
		RET
L_SQ5:
		STC
		RET

;子程序:取字符行列坐标并转换为字符左上角点坐标
S_QZU:
		CALL	S_Q
		MUL	D_FA
		OR	AX,AX
		JZ	L_QZU1
		CMP	D_FB,12H		;VGA?
		JNZ	L_QZU1
		SUB	AX,2
L_QZU1:
		MOV	D_D3,AX
		CALL	S_Q0
		MOV	CL,8
		MUL	CL
		MOV	D_D1,AX
		RET

;子程序:取参数并乘比例因子
S_QK:
		CALL	S_Q
S_QK1:
		MOV	DL,D_100		;比例因子
		XOR	DH,DH
		MUL	DX			;乘
		SHR	AX,1			;除16
		SHR	AX,1
		SHR	AX,1
		SHR	AX,1
		RET

;子程序:取输入参数->D_D9开始的20字节(10个参数) BX:个数
S_IN:
		MOV	DI,OFFSET D_D9
L_IN1:
		CALL	S_Q
		STOSW
		DEC	BX
		JNZ	L_IN1
		RET

;子程序:画点
S_D:
		TEST	D_EF,1
		JNZ	L_D4
;子程序:画点(当前点)
S_D1:
		MOV	CX,D_D1
		MOV	DX,D_D3
;子程序:画点(指定颜色)
S_D2:
		MOV	AL,D_ED
;子程序:画点
S_D3:
		PUSH	BX
		XOR	BX,BX
		MOV	AH,0CH
		CALL	INT10
		POP	BX
L_D4:
		RET
;子程序:画点(保存AX)
S_DOT:
		PUSH	AX
		CALL	S_D2			;画点
		POP	AX
		RET

;子程序:保存起点
S_PUSHD:
		TEST	D_EF,2
		JZ	L_PD1
		MOV	AX,D_D1
		MOV	D_DD,AX
		MOV	AX,D_D3
		MOV	D_DF,AX
L_PD1:
		RET

;子程序:恢复起点
S_POPD:
		AND	D_EF,0FEH
		TEST	D_EF,2
		JZ	L_PD2
		MOV	AX,D_DD
		MOV	D_D1,AX
		MOV	AX,D_DF
		MOV	D_D3,AX
		AND	D_EF,0FDH
L_PD2:
		RET

;子程序:初始化工作参数
S_0:
		PUSH	CS
		POP	ES
S_00:
		XOR	AX,AX
		MOV	DI,OFFSET D_D0
		MOV	CX,29H
		REP	STOSB			;清图形参数区
		MOV	ES:D_FD,AL		;清字符颜色
		MOV	AX,1406H		;取显示参数
		INT	10H
		MOV	ES:D_A000,BP
		MOV	ES:D_FB,AL		;显示方式
		MOV	AL,AH
		CBW
		MOV	ES:D_D0,AL		;最大色号
		MOV	WORD PTR ES:D_ED,AX
		MOV	WORD PTR ES:D_F1,AX
		MOV	ES:D_D5,SI		;最大X坐标
		MOV	ES:D_D7,DI		;最大Y坐标
		MOV	ES:D_F9,CL		;显示行数
		MOV	ES:D_FA,CH		;每字符行扫描线数
		MOV	ES:D_EE,0FFH		;填充色
		MOV	ES:D_F0,40H		;A字型
		MOV	ES:D_F5,1
		MOV	ES:D_100,16		;设置比例因子
		MOV	BYTE PTR ES:D_BUF3,0	;清命令串
		PUSH	DS
		XOR	AX,AX
		MOV	DS,AX
		MOV	AL,DS:[44AH]
		POP	DS
		MOV	ES:D_FC,AL		;每行字符数
		RET

S_ST		ENDP

;----------------------------------------------------------------------------
FRE		DW	-1
YYC		DB	0
D_N		DB	1
D_NUM		DB	0		;循环次数
D_ADDR		DW	OFFSET D_BUF3	;处理地址

INT_1C		PROC	FAR
		STI
		CLD
		PUSH	DS
		PUSH	AX
		PUSH	SI
		PUSH	CS
		POP	DS
		PUSHF
		CALL	D_INT1C
		CMP	D_NUM,0 		;判执行次数?
		JZ	L_1CRET
		CMP	YYC,0			;判音长?
		JZ	L_1C01
		DEC	YYC			;音长-1
		JNZ	L_1CRET
		IN	AL,61H
		AND	AL,0FCH 		;关扬声器
		OUT	61H,AL
		JMP	SHORT L_1CRET
L_1C01:
		MOV	SI,D_ADDR
		LODSW				;取下一频率
		CMP	AX,-1			;判结束?
		JNZ	L_1C10
		MOV	D_ADDR,OFFSET D_BUF3
		CMP	D_NUM,0FFH		;判无限循环?
		JZ	L_1C01
		DEC	D_NUM			;执行次数-1
		JNZ	L_1C01
L_1CRET:
		POP	SI
		POP	AX
		POP	DS
		IRET
L_1C10:
		OR	AX,AX
		JZ	L_1C20
		PUSH	AX
		MOV	AL,0B6H
		OUT	43H,AL			;写定时器模式寄存器
		POP	AX
		OUT	42H,AL			;写定时器低位
		MOV	AL,AH
		OUT	42H,AL			;写定时器高位
		IN	AL,61H			;取端口B状态
		OR	AL,3
		OUT	61H,AL			;开启扬声器
L_1C20:
		LODSB				;取下一音长
		MOV	YYC,AL
		MOV	D_ADDR,SI		;存
		JMP	SHORT L_1CRET
INT_1C		ENDP

;----------------------------------------------------------------------------
D_BUF1		DB	32 DUP (0)
D_BUF2		DB	32 DUP (0)
D_BUF3		DB	512 DUP(0)

;****************************************************************************
BEGIN:
		MOV	AX,1406H
		INT	10H
		CMP	AX,1406H
		JNZ	L_S20
		MOV	DX,OFFSET D_GW		;'GWINT10K.COM',0
		MOV	AX,3D00H		;打开文件
		INT	21H
		JB	L_S10
		MOV	BX,AX
		PUSH	CS
		POP	ES
		MOV	DI,80H
		MOV	SI,OFFSET L_GW
		MOV	CX,OFFSET L_S20-OFFSET L_GW
		REP	MOVSB			;以下程序传送到CS:80H
		MOV	AX,80H
		JMP	AX			;转CS:80H执行
L_S10:
		MOV	DX,OFFSET NOGW
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_GW:
		MOV	DX,100H
		MOV	CX,2000H
		MOV	AH,3FH			;读文件
		INT	21H
		MOV	AH,3EH			;关闭
		INT	21H
		MOV	AX,100H
		JMP	AX			;转CS:100H执行
L_S20:
		MOV	AX,1903H		;取本模块安装状态AL
		INT	10H
		CMP	AL,84H			;判安装INT10K?
		JZ	L_S30
		CMP	AL,85H			;判安装INT10V?
		JNZ	L_S40
		MOV	SI,10EH
		MOV	DI,SI
		MOV	CX,OFFSET BEGIN-10DH
		REP	MOVSB			;覆盖原INT10V
		CALL	S_00			;初始化参数
		XOR	AX,AX
		MOV	ES:D_FE,AX

		PUSH	ES
		POP	DS
		MOV	DX,OFFSET INT_10
		MOV	AX,2510H
		INT	21H
		MOV	DX,OFFSET INT_1C
		MOV	AX,251CH
		INT	21H
		MOV	AX,4C00H
		INT	21H
L_S30:
		MOV	DX,OFFSET ALREADY
		JMP	L_ERR
L_S40:
		MOV	AX,3510H
		INT	21H
		MOV	WORD PTR D_INT10,BX
		MOV	WORD PTR D_INT10+2,ES

		CALL	S_0			;初始化参数

		MOV	AX,CS
		CMP	AX,0A000H		;判LH?
		JA	L_S50
		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_S45
L_S42:
		LODSB
		CMP	AL,0DH
		JZ	L_S45
		CMP	AL,'/'
		JNZ	L_S42
		LODSB
		AND	AL,5FH
		CMP	AL,'N'                  ;/N:驻留基本内存
		JNZ	L_S42
		JMP	SHORT L_S50
L_S45:
		CALL	S_GETUMB		;分配UMB段
		JZ	L_S60
L_S50:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		CALL	S_SETINT
		MOV	DX,OFFSET BEGIN 	;驻留
		INT	27H
L_S60:
		MOV	AX,D_UMB
		OR	AX,AX
		JZ	L_S50
		DEC	AX
		MOV	ES,AX
		MOV	DI,8
		MOV	SI,OFFSET D_NAME
		MOV	CX,7
		REP	MOVSB			;向UMB文件控制块写入本模块名

		MOV	ES,D_UMB		;段
		XOR	SI,SI
		MOV	DI,SI
		MOV	CX,OFFSET BEGIN
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
		MOV	DX,OFFSET BEGIN
		SHR	DX,1
		SHR	DX,1
		SHR	DX,1
		SHR	DX,1
		INC	DX
		MOV	D_LEN,DX		;本模块驻留长度(节)

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
		MOV	DX,OFFSET INT_10
		MOV	AX,2510H
		INT	21H

		MOV	AX,351CH
		INT	21H
		MOV	WORD PTR D_INT1C,BX
		MOV	WORD PTR D_INT1C+2,ES
		MOV	DX,OFFSET INT_1C
		MOV	AX,251CH
		INT	21H
		RET
S_SETINT	ENDP

D_NAME		DB	'INT10K',0
ALREADY 	DB	'特显模块已经驻留!',7,13,10,'$'
D_GW		DB	'GWINT10K.COM',0
NOGW		DB	'没有文件 GWINT10K.COM !',7,13,10,'$'

SEG_A		ENDS
		END	START

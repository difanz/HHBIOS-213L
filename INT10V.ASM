;      INT10V.ASM (L)
;	1995.2.7, 3.31, 12.17
;	1996.2.2, 2.24, 3.31
;	1997.6.28, 7.6

;命令:	A-模拟功能键	B-画矩形	C-置图形颜色	D-画点
;	E-向右上画线	F-向右下画线	G-向左下画线	H-向左上画线
;	I-执行INT 10	J-执行命令串	K-置比例因子	L-画斜线
;	M-移点不画线	N-画线不移点	O-画圆,椭圆等	P-填充
;	Q-清屏初始化	R-光标控制	S-置前景背景色	T-繁简转换
;	U-向上画线	V-矩形区填充线	W-取命令串	X-向下画线
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

		DB	'V'                     ;[10DH]

;子程序:执行INT 10
INT10		PROC	NEAR
		PUSHF
		CALL	CS:D_INT10    ;CALL FAR
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
		CMP	AL,3			;返回安装状态AL
		JNZ	L_1940
		MOV	AL,85H
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
D_TXKG	EQU	$				;特显开关
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
		MOV	D_FE,AX 	   ;清输入缓冲区指针
		MOV	D_FF,AL
		MOV	SI,AX			;置输入缓冲区指针
		CALL	S_ST			;处理
		JMP	SHORT L_RET

D_D0		DB	0	;[0D0H]:最大色号
D_D1		DW	0	;[0D1H]:X
D_D3		DW	0	;[0D3H]:Y
D_D5		DW	0	;[0D5H]:最大X坐标
D_D7		DW	0	;[0D7H]:最大Y坐标
D_D9		DW	0	;[0D9H]:X增量
D_DB		DW	0	;[0DBH]:Y增量
D_DD		DW	0	;[0DDH]:保存[0D1H]	输入参数1
D_DF		DW	0	;[0DFH]:保存[0D3H]		2
D_E1		DW	0	;[0E1H]:			3
D_E3		DW	0	;[0E3H]:			4
D_E5		DW	0	;[0E5H]:			5
D_E7		DW	0	;[0E7H]:			6
D_E9		DW	0	;[0E9H]:			7
D_EB		DW	0	;[0EBH];			8
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
		CMP	AL,'['                  ; *显示24点阵汉字*
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
;格式:CHR(14)+"@左上角字符列,扫描线行,图象文件名@]"
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
		CALL	S_QHL
		CALL	S_Q0
		MOV	DL,8
		MUL	DL
		MOV	BP,1
		MOV	DI,0
		JMP	L_Y3			;画线

;※按行画竖线※--------------------------------------------------------------
;格式:CHR(14)+"_行,列,长度]"  (行)
L_SX:
		CMP	AL,'|'
		JNZ	L_KX
		CALL	S_QHL			;取字符行列并转换为左上角点坐标
		CALL	S_Q0
		MUL	D_FA
		MOV	BP,0
		MOV	DI,1
		JMP	L_Y3			;画线

;※按字符行列画框线※--------------------------------------------------------
;格式:CHR(14)+"_行,列,高,宽{,方式}]"  (均为字符行列,若有方式则缩进4点)
L_KX:
		CMP	AL,'#'
		JNZ	L_CX
		CALL	S_QHL			;取字符行列并转换为左上角点坐标
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
		SUB	D_D1,4			;缩进
		SUB	D_D3,4
		ADD	DI,8			;缩小
		ADD	AX,8
L_KX1:
		PUSH	SI
		MOV	SI,AX
		XCHG	SI,DI
		MOV	CX,D_D1
		MOV	DX,D_D3
		JMP	L_B3			;显示矩形

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
;其中:功能符为	T节拍	指定节拍(默认100,每分钟节拍数)
;		CDEFGAB 定调(开机为C调)
;		1234567 音名		0	休止符
;		#	升半音		B	降半音
;		Q	升八度		D	降八度
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
		MOV	CX,AX
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
;   若其中之一等于0则不画,若全等于0则画屏幕边框线
L_B:
		MOV	AX,D_D3
		MOV	D_DF,AX
		CALL	S_QK			;宽:取参数并乘比例因子
		MOV	DI,AX
		XOR	AX,AX
		CMP	BYTE PTR DS:[SI],','
		JNZ	L_B1
		INC	SI
		CALL	S_QK			;高:取参数并乘比例因子
L_B1:
		OR	DI,DI			;判宽=0?
		JNZ	L_B2
		OR	AX,AX			;再判高=0?
		JNZ	L_B6
		MOV	D_D1,AX
		MOV	D_D3,AX
		MOV	D_DF,AX
		PUSH	SI
		MOV	DI,D_D5 	   ;屏幕宽
		MOV	SI,D_D7 	   ;屏幕高
		JMP	SHORT L_B3		;画边框线
L_B2:
		OR	AX,AX			;判高=0?
		JZ	L_B6
		PUSH	SI
		MOV	SI,AX
		SUB	D_D3,AX
L_B3:
		CALL	S_JX			;画矩形
		POP	SI

		MOV	AL,D_EE 	   ;取填充色
		CMP	AL,-1
		JZ	L_B5

		PUSH	WORD PTR D_ED		    ;边界色
		PUSH	D_D1
		ADD	D_D1,2
		ADD	D_D3,2
		PUSH	SI
		CALL	FILLADJLINE
		POP	SI
		POP	D_D1
		POP	WORD PTR D_ED
L_B5:
		MOV	AX,D_DF
		MOV	D_D3,AX
L_B6:
		JMP	L_ST

;子程序:画矩形(DI-宽,SI-高)
S_JX:
		CMP	D_FB,12H		;判VGA16色?
		JNZ	L_JX1
		MOV	BP,DI
		MOV	CX,1			;向右
		CALL	S_LINE
		MOV	BP,SI
		MOV	CX,100H 		;向下
		CALL	S_LINE
		MOV	BP,DI
		MOV	CX,0FFH 		;向左
		CALL	S_LINE
		MOV	BP,SI
		MOV	CX,0FF00H		;向上
		CALL	S_LINE
L_JX1:
		RET

;子程序:画横线或竖线 (BP=长度, CL=1右,=0FFH向左, CH=1向下,=0FFH向上)
S_LINE:
		MOV	AX,D_D1
		MOV	D_E5,AX
		MOV	AX,D_D3
		MOV	D_E7,AX
		CMP	CL,1			;X+
		JNZ	L_LINE1
		ADD	D_E5,BP
L_LINE1:
		CMP	CL,0FFH 		;X-
		JNZ	L_LINE2
		SUB	D_E5,BP
L_LINE2:
		CMP	CH,1			;Y+
		JNZ	L_LINE3
		ADD	D_E7,BP
L_LINE3:
		CMP	CH,0FFH 		;Y-
		JNZ	L_LINE4
		SUB	D_E7,BP
L_LINE4:
		JMP	L_L5

;※设置图形颜色※------------------------------------------------------------
;格式:CHR(14)+"C色号]"
L_C:
		CALL	S_Q			;取参数
		MOV	D_ED,AL 	   ;图形颜色
		MOV	AL,-1
		CMP	BYTE PTR [SI],','
		JNZ	L_C1
		CALL	S_Q0
L_C1:
		MOV	D_EE,AL 	   ;填充颜色
		JMP	L_ST

;※画点※--------------------------------------------------------------------
;格式:CHR(14)+"D点X,Y]"
L_D:
		CALL	S_Q			;取参数:X-座标
		MOV	D_D1,AX
		CALL	S_Q0			;取参数:Y-座标
		MOV	D_D3,AX
		TEST	D_EF,1			;M标志
		JNZ	L_D1
		CALL	S_D			;画点
L_D1:
		AND	D_EF,0FEH		;清标志
		JMP	L_ST

;子程序:画点
S_D:
		MOV	CX,D_D1
		MOV	DX,D_D3
S_D1:
		XOR	BH,BH
		MOV	AL,D_ED
		MOV	AH,0CH
		CALL	INT10
		RET

;※向右上画线※--------------------------------------------------------------
;格式:CHR(14)+"E长度]"
L_E:
		MOV	BP,1			;BP-X, DI-Y
		JMP	SHORT L_U1
;※向右下画线※--------------------------------------------------------------
;格式:CHR(14)+"F长度]"
L_F:
		MOV	BP,1
		JMP	SHORT L_H1
;※向左下画线※--------------------------------------------------------------
;格式:CHR(14)+"G长度]"
L_G:
		MOV	BP,-1
		JMP	SHORT L_X1
;※向左上画线※--------------------------------------------------------------
;格式:CHR(14)+"H长度]"
L_H:
		MOV	BP,-1
L_H1:
		MOV	DI,BP
		JMP	SHORT L_Y2
;※向上画线※----------------------------------------------------------------
;格式:CHR(14)+"U长度]"
L_U:
		MOV	BP,0
L_U1:
		MOV	DI,-1
		JMP	SHORT L_Y2
;※向下画线※----------------------------------------------------------------
;格式:CHR(14)+"X长度]"
L_X:
		MOV	BP,0
L_X1:
		MOV	DI,1
		JMP	SHORT L_Y2
;※向左画线※----------------------------------------------------------------
;格式:CHR(14)+"Z长度]"
L_Z:
		MOV	BP,-1
		JMP	SHORT L_Y1
;※向右画线※----------------------------------------------------------------
;格式:CHR(14)+"Y长度]"
L_Y:
		MOV	BP,1
L_Y1:
		XOR	DI,DI
L_Y2:
		CALL	S_QK			;取参数并乘比例因子
L_Y3:
		PUSH	SI
		MOV	SI,AX
		MOV	CX,D_D1 		;保存
		MOV	DX,D_D3
L_Y4:
		TEST	D_EF,1			;M标志
		JNZ	L_Y5
		CALL	S_D1
L_Y5:
		ADD	CX,BP
		CMP	CX,D_D5
		JBE	L_Y6
		SUB	CX,BP
		JMP	SHORT L_Y8
L_Y6:
		ADD	DX,DI
		CMP	DX,D_D7
		JBE	L_Y7
		SUB	DX,DI
		JMP	SHORT L_Y8
L_Y7:
		DEC	SI
		JNZ	L_Y4
L_Y8:
		TEST	D_EF,2			;N标志
		JNZ	L_Y9
		MOV	D_D1,CX
		MOV	D_D3,DX
L_Y9:
		AND	D_EF,0FCH		;清MN标志
		POP	SI
		JMP	L_ST

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
		CMP	AL,-1		       ;判执行其他中断?
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
		MOV	D_INT[1],10H
		PUSH	DI
		XOR	DI,DI
		MOV	DS,DI
		MOV	DI,4F0H
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
		PUSH	CS
		POP	ES
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

;※前缀:移当前点但不画线※---------------------------------------------------
;格式:CHR(14)+"M...]"
L_M:
		OR	D_EF,1			;置M标志
		JMP	L_ST

;※前缀:画线但不移当前点※---------------------------------------------------
;格式:CHR(14)+"N...]"
L_N:
		OR	D_EF,2			;置N标志
		JMP	L_ST

;※清屏并初始化参数※--------------------------------------------------------
;格式:CHR(14)+"Q屏幕色]"  (若无屏幕色则为黑色)
L_Q:
		CALL	S_CLS			;清屏
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
L_Q2:
		JMP	L_ST

;清屏子程序
S_CLS:
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	BP
		MOV	AX,1406H
		INT	10H
		CMP	AL,5DH
		JZ	L_CLS1
		OR	BL,BL
		JZ	L_CLS1
		MOV	AL,3
L_CLS1:
		XOR	AH,AH
		CALL	INT10
		POP	BP
		POP	DI
		POP	SI
		POP	DX
		POP	CX
		POP	BX
		XOR	AX,AX
		MOV	D_D1,AX
		MOV	D_D3,AX
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

		MOV	DI,DS:[BX+6]		;宽
		CMP	DI,2
		JBE	L_V7
		MOV	SI,DS:[BX+8]		;高
		CMP	SI,2
		JBE	L_V7

		MOV	AX,[BX+4]		;Y
		SUB	AX,SI			;-高
		MOV	[BX+4],AX
		MOV	D_D3,AX
		MOV	AX,[BX+2]		;X
		MOV	D_D1,AX

		CMP	BYTE PTR DS:[BX+16],0
		JZ	L_V6
		CALL	S_JX			;画矩形
L_V6:
		CALL	S_V			;填线
L_V7:
		POP	SI
		JMP	L_ST

;子程序:矩形区填线 入口参数:从D_09D0开始放V命令诸参数(八个字)
S_V:
		MOV	AL,[BX]
		MOV	D_ED,AL
		INC	WORD PTR [BX+2] 	;X+1
		INC	WORD PTR [BX+4] 	;Y+1
		SUB	WORD PTR [BX+6],2	;宽-2
		SUB	WORD PTR [BX+8],2	;高-2
		MOV	AX,[BX+0AH]		;类型

		CMP	AL,1			;<横线>
		JNZ	L_V20
		MOV	DI,[BX+4]		;Y
		ADD	[BX+4],SI		;+高
L_V11:
		ADD	DI,[BX+0CH]		;+间隔
		MOV	DX,1
L_V12:
		MOV	BP,[BX+6]		;宽
		MOV	CX,1			;向右
		CMP	DI,[BX+4]		;Y
		JG	L_V19
		MOV	D_D3,DI
		MOV	AX,[BX+2]		;X
		MOV	D_D1,AX
		CALL	S_LINE			;画线
		INC	DI
		INC	DX
		CMP	DX,[BX+0EH]		;线宽
		JG	L_V11
		JMP	SHORT L_V12
L_V19:
		RET
L_V20:
		CMP	AL,2			;<竖线>
		JNZ	L_V30
		MOV	SI,[BX+2]		;X
		ADD	[BX+2],DI		;+宽
L_V21:
		ADD	SI,[BX+0CH]		;+间隔
		MOV	DX,1
L_V22:
		MOV	BP,[BX+8]		;高
		MOV	CX,100H 		;向下
		CMP	SI,[BX+2]		;X
		JG	L_V19
		MOV	D_D1,SI
		MOV	AX,[BX+4]
		MOV	D_D3,AX
		CALL	S_LINE
		INC	SI
		INC	DX
		CMP	DX,[BX+0EH]		;线宽
		JG	L_V21
		JMP	SHORT L_V22
L_V30:
		CMP	AL,3			;<左斜线>
		JNZ	L_V40
		MOV	SI,[BX+2]		;X
		MOV	DI,[BX+4]		;Y
		MOV	AX,DI
		ADD	AX,[BX+6]		;Y+宽
		MOV	[BX+10H],AX
		ADD	AX,[BX+8]		;Y+宽+高
		MOV	[BX+12H],AX
L_V31:
		ADD	DI,[BX+0CH]		;间隔
		MOV	DX,1
L_V32:
		CMP	DI,[BX+12H]		;终点?
		JG	L_V39
		MOV	BP,[BX+6]		;宽
		CMP	DI,[BX+10H]		;转折点?
		JGE	L_V33
		MOV	BP,DI
		SUB	BP,[BX+4]		;-Y=小宽
L_V33:
		MOV	D_D1,SI
		MOV	D_D3,DI
		MOV	AX,[BX+4]
		ADD	AX,[BX+8]		;左下角Y
		CMP	DI,AX			;超过左下角?
		JLE	L_V34
		MOV	D_D3,AX
		MOV	CX,DI
		SUB	CX,AX
		ADD	D_D1,CX
		SUB	BP,CX
L_V34:
		MOV	CX,0FF01H		;向左上
		CALL	S_LINE
		INC	DI
		INC	DX
		CMP	DX,[BX+0EH]		;线宽
		JG	L_V31
		JMP	SHORT L_V32
L_V39:
		RET
L_V40:						;<右斜线>
		MOV	SI,[BX+2]		;X
		ADD	SI,[BX+6]		;X+宽 移右上角
		MOV	DI,[BX+4]		;Y
		MOV	AX,DI
		ADD	AX,[BX+6]		;Y+宽
		MOV	[BX+10H],AX		;转折点
		ADD	AX,[BX+8]		;Y+宽+高
		MOV	[BX+12H],AX		;终点
L_V41:
		ADD	DI,[BX+0CH]		;间隔
		MOV	DX,1
L_V42:
		MOV	BP,[BX+6]		;宽
		CMP	DI,[BX+12H]		;终点?
		JG	L_V39
		CMP	DI,[BX+10H]		;转折点?
		JGE	L_V43
		MOV	BP,DI
		SUB	BP,[BX+4]		;小宽
L_V43:
		MOV	D_D1,SI
		MOV	D_D3,DI
		MOV	AX,[BX+4]		;Y
		ADD	AX,[BX+8]		;左下角Y
		CMP	DI,AX			;宽<高时超过左下角?
		JLE	L_V44
		MOV	D_D3,AX
		MOV	CX,DI
		SUB	CX,AX
		SUB	D_D1,CX
		SUB	BP,CX
L_V44:
		MOV	CX,0FFFFH		;向左上角
		CALL	S_LINE
		INC	DI
		INC	DX
		CMP	DX,[BX+0EH]		;线宽?
		JG	L_V41
		JMP	SHORT L_V42

;※画斜线※------------------------------------------------------------------
;格式1:CHR(14)+"L终点X,Y]"      (绝对坐标)
;格式2:CHR(14)+"L±终点X,±Y]"  (相对坐标)
;格式3:CHR(14)+"L/长度,角度]"   (以向右为0度)
L_L:
		CALL	S_L
		JMP	L_ST

;子程序:画斜线
S_L:
		CMP	BYTE PTR DS:[SI],'/'    ;以角度画线
		JNZ	L_L1
		CALL	S_Q0			;取长度
		MOV	BP,AX
		CALL	S_Q0			;取角度
		CALL	PIXEL_1 		; AX:=SINX
						; BX:=COSX
		IMUL	BP			; L*SINX
		MOV	CX,10000
		IDIV	CX
		MOV	CX,D_D3
		SUB	CX,AX
		MOV	D_E7,CX 		; Y1

		MOV	AX,BX
		IMUL	BP			; L*COSX
		MOV	CX,10000
		IDIV	CX
		ADD	AX,D_D1
		MOV	D_E5,AX 		; X1
		MOV	D_EF,2			;置N标志
		JMP	SHORT L_L5
L_L1:
		CALL	S_QF			;取终点X
		JNB	L_L4			;无符号转
		CALL	S_QK1			;乘比例因子
		CMP	BP,2			;判'-'?
		JNZ	L_L2
		NEG	AX
L_L2:
		ADD	AX,D_D1
		MOV	D_E5,AX 		; X1

		INC	SI
		CALL	S_QF			;取终点Y
		CALL	S_QK1			;乘比例因子
		CMP	BP,2			;判'-'?
		JNZ	L_L3
		NEG	AX
L_L3:
		ADD	AX,D_D3
		MOV	D_E7,AX 		; Y1
		JMP	SHORT L_L5
L_L4:
		MOV	D_E5,AX
		INC	SI
		CALL	S_QF			;取终点Y
		MOV	D_E7,AX
L_L5:
		MOV	AX,D_D1 		; X0
		MOV	D_E1,AX
		MOV	AX,D_D3 		; Y0
		MOV	D_E3,AX
		CMP	D_EF,1			;有前缀M
		JNZ	L_L8
L_L6:
		MOV	AX,D_D9
		MOV	D_D1,AX
		MOV	AX,D_DB
		MOV	D_D3,AX
L_L7:
		AND	D_EF,0FEH		;清M标志
		RET
L_L8:
		PUSH	SI
		PUSH	DI
		PUSH	BX
		PUSH	DX
		CLI
		CALL	S_DRAW
		STI
		POP	DX
		POP	BX
		POP	DI
		POP	SI
		CMP	D_EF,2			;N标志
		JNZ	L_L6
		JMP	SHORT L_L7

;子程序:取参数并判符号
S_QF:
		XOR	BP,BP
		CMP	BYTE PTR [SI],'+'
		JNZ	L_QF1
		INC	BP
		INC	SI
		JMP	SHORT L_QF2
L_QF1:
		CMP	BYTE PTR [SI],'-'
		JNZ	L_QF2
		MOV	BP,2
		INC	SI
L_QF2:
		CALL	S_Q
		OR	BP,BP
		JNZ	L_QF3
		CLC
		RET
L_QF3:
		STC
		RET

;※画圆,椭圆,弧,扇形※-------------------------------------------------------
;格式:CHR(14)+"O圆心X,Y,长半径R,方式F,短半径R1,起始角A1,终止角A2,标志K]"
;    其中: 方式F=0为半圆, =1为半圆弧, 等于其它值和缺省时为圆)
;	   标志K=1画弧, =0画扇形
;	   填充颜色由C命令指定
L_O:
		CALL	S_Q			;取圆心X坐标
		PUSH	AX
		CALL	S_Q0			;取圆心Y坐标
		PUSH	AX
		CALL	S_Q0			;取长半径R
		MOV	D_E1,AX
		MOV	D_E3,AX 		;短半径R1=R
		XOR	AX,AX
		MOV	D_E5,AX 		;起始角
		MOV	D_E7,AX 		;终止角
		MOV	D_EB,AX 		;清填充标志和标志K(弧)

		CMP	BYTE PTR DS:[SI],','    ;判无后续参数?
		JNZ	L_O8

		CMP	BYTE PTR DS:[SI+1],','  ;判方式F缺省?
		JNZ	L_O2
		INC	SI
		JMP	SHORT L_O3
L_O2:
		CALL	S_Q0			;取方式F
		CMP	AL,1
		JA	L_O3			;F>1为圆 转
		MOV	D_E7,180		;终止角=180
		CMP	AL,1
		JZ	L_O3			; 180 弧
		MOV	BYTE PTR D_EB+1,1		   ;K=0半圆
L_O3:
		CMP	BYTE PTR DS:[SI],','    ;判无后续参数?
		JNZ	L_O8
		CALL	S_Q0			;取短半径R1
		OR	AX,AX
		JZ	L_O4			;短半径R1=0 转 (R1=R)
		MOV	D_E3,AX
L_O4:
		CMP	BYTE PTR DS:[SI],','    ;判无后续参数?
		JNZ	L_O8
		CALL	S_Q0			;取起始角A1
		MOV	D_E5,AX

		CMP	BYTE PTR DS:[SI],','    ;判无后续参数?
		JNZ	L_O8
		CALL	S_Q0			;取终止角A2
		MOV	D_E7,AX

		CMP	BYTE PTR DS:[SI],','    ;判无后续参数?
		JNZ	L_O8
		CALL	S_Q0			;取标志K
		MOV	BYTE PTR D_EB+1,AL
L_O8:
		CMP	D_EE,0FFH
		JZ	L_O9
		MOV	BYTE PTR D_EB,1 	;填充标志=1(填充)
L_O9:
		POP	BX			;Y
		POP	AX			;X
		PUSH	SI
		CALL	ELLARC			;画弧,扇形,圆,椭圆子程序
		POP	SI
		JMP	L_ST

;子程序：ELLARC
;		XC   D_E1
;		YC   D_E3
;	AX	X   EQU   WORD PTR [BP+0]
;	BX	Y   EQU   WORD PTR [BP+2]
;		R   EQU   WORD PTR [BP+4]
;		R1  EQU   WORD PTR [BP+6]
;		A1  EQU   BYTE PTR [BP+8]
;		A2  EQU   BYTE PTR [BP+10]
;		SINX EQU   [BP+18]
;		COSX EQU   [BP+20]
;		SINA EQU   [BP+22]
;		COSA EQU   [BP+24]
;		填充点X    [BP+26]
;		填充点Y    [BP+28]
;			   [BP+30]
ELLARC: 	PUSH	BP
		CLI
		MOV	BP,OFFSET D_BUF1

		MOV	DS:[BP],AX		; X
		MOV	DS:[BP+2],BX		; Y
		MOV	AX,D_E1
		MOV	DS:[BP+4],AX		; R
		MOV	AX,D_E3
		MOV	DS:[BP+6],AX		; R1
		MOV	AX,D_E5
		MOV	DS:[BP+8],AX		; A1
		MOV	AX,D_E7
		MOV	DS:[BP+10],AX		; A2

		MOV	AX,0			; AX=ARCALP
		CALL	PIXEL_1 		; RETURN: AX:=SINX BX:=COSX
		MOV	DS:[BP+22],AX		; SINA
		MOV	DS:[BP+24],BX		; SINB

		MOV	AX,DS:[BP+8]
		MOV	BX,DS:[BP+10]
		CMP	AX,BX
		JB	R01			; IF AX < BX JMP
		ADD	BX,360			; BX:=BX+360
		MOV	DS:[BP+10],BX
R01:
		MOV	AX,DS:[BP+8]
		SUB	BX,AX
		MOV	CX,BX			; CX:=A2-A1

		MOV	BX,CX
		SHR	BX,1
		ADD	BX,DS:[BP+8]
		MOV	DS:[BP+30],BX

; DRAW THE START LINE OF THE ARC
		MOV	AX,DS:[BP+8]

		CMP	CX,1
		JG	R02
		MOV	BYTE PTR D_EB,0
R02:
		CALL	PIXEL			; CALLER: AX:=DEGREE
		MOV	D_E5,AX 		; X1
		MOV	D_E7,BX 		; Y1

		CMP	BYTE PTR D_EB+1,0	; K=0 画弧
		JZ	ARC1

		MOV	AX,DS:[BP+0]		; K=1 画扇形
		MOV	D_E1,AX
		MOV	AX,DS:[BP+2]
		MOV	D_E3,AX

		PUSH	D_E5
		PUSH	D_E7
		PUSH	CX
		CALL	DRAWLINE
		POP	CX
		POP	D_E7
		POP	D_E5
		CMP	CX,1
		JG	ARC1
		MOV	BYTE PTR D_EB,0
ARC1:
		MOV	SI,DS:[BP+8]
LOOP1:
		MOV	AX,D_E5
		MOV	D_E1,AX
		MOV	AX,D_E7
		MOV	D_E3,AX
		INC	SI
		MOV	AX,SI
		CALL	PIXEL
		MOV	D_E5,AX
		MOV	D_E7,BX
		CMP	SI,DS:[BP+30]
		JNZ	LPI
		MOV	DX,DS:[BP+0]
		ADD	DX,AX
		SHR	DX,1
		MOV	DS:[BP+26],DX		; 填充点X=1/2(SEEDX+X)
		MOV	DX,DS:[BP+2]
		ADD	DX,BX
		SHR	DX,1
		MOV	DS:[BP+28],DX		; 填充点Y=1/2(SEEDY+Y)
LPI:
		PUSH	D_E5
		PUSH	D_E7
		PUSH	CX			; CX:= 循环次数
		PUSH	SI
		CALL	DRAWLINE
		POP	SI
		POP	CX
		POP	D_E7
		POP	D_E5
		LOOP	LOOP1

		CMP	BYTE PTR D_EB+1,0	; K=0, 画弧
		JZ	R03
		MOV	AX,DS:[BP+0]		; K=1, 画扇形
		MOV	D_E1,AX
		MOV	AX,DS:[BP+2]
		MOV	D_E3,AX
		MOV	AX,DS:[BP+10]
		CALL	PIXEL
		MOV	D_E5,AX
		MOV	D_E7,BX
		CALL	DRAWLINE
R03:
		CMP	BYTE PTR D_EB,0 	; 填充标志F
		JZ	ARC2
		CMP	BYTE PTR D_EB+1,1
		JZ	R04
		MOV	AX,DS:[BP+8]
		MOV	BX,DS:[BP+10]
		SUB	BX,AX
		CMP	BX,360
		JNE	ARC2
R04:
		MOV	AX,DS:[BP+26]
		MOV	D_D1,AX
		MOV	AX,DS:[BP+28]
		MOV	D_D3,AX
		CALL	FILLADJLINE		; CALL 填充子程序
ARC2:
		STI
		POP	BP
		RET

; 通用子程序
ARC_1:
		MOV	BX,AX
		SHL	BX,1
		MOV	CX,D_SIN[BX]
		RET

ARC_2:
		MOV	BX,AX
		MOV	CX,90
		SUB	CX,BX
		XCHG	CX,BX
		SHL	BX,1
		MOV	CX,D_SIN[BX]
		RET

ARC_3:
		IMUL	CX
		MOV	CX,10000
		IDIV	CX
		RET

; 子程序1:  PIXEL_1
PIXEL_1:
		XOR	DX,DX			; CALLER:AX:=角度数
		MOV	CX,360			; RETURN:正弦SINX,余弦COSX
		DIV	CX
		MOV	AX,DX
		MOV	CL,90
		DIV	CL			; 商-->AL 余数->AH
		CMP	AL,0
		JA	A01			; AX>=90 JMP
		MOV	AL,AH
		XOR	AH,AH
		CALL	ARC_1
		PUSH	CX			; SINX=SINX
		CALL	ARC_2
		PUSH	CX
		JMP	SHORT A04
A01:
		CMP	AL,1
		JA	A02			; AX>=180 JMP
		MOV	AL,AH
		XOR	AH,AH
		CALL	ARC_2			; SINX= SIN(180-X)
		PUSH	CX
		CALL	ARC_1
		NEG	CX			; COSX=-SIN(90+X)
		PUSH	CX
		JMP	SHORT A04
A02:
		CMP	AL,2
		JA	A03			; AX>=270 JMP
		MOV	AL,AH
		XOR	AH,AH
		CALL	ARC_1
		NEG	CX			; SINX=-SIN(X-180)
		PUSH	CX
		CALL	ARC_2
		NEG	CX			; COSX=-SIN(270-X)
		PUSH	CX
		JMP	SHORT A04
A03:
		MOV	AL,AH
		XOR	AH,AH
		CALL	ARC_2
		NEG	CX			; SINX=-SIN(360-X)
		PUSH	CX
		CALL	ARC_1
		PUSH	CX			; COSX=-SIN(X-270)
A04:
		POP	BX			; BX:=COSX
		POP	AX			; AX:=SINX
		RET

; 子程序2: PIXEL
PIXEL:
		PUSH	CX
		PUSH	SI
		CALL	PIXEL_1
		MOV	DS:[BP+18],AX
		MOV	DS:[BP+20],BX
		MOV	AX,DS:[BP+4]
		MOV	CX,DS:[BP+20]
		CALL	ARC_3
		MOV	SI,AX			; SI:= AX:=A*COST

		MOV	AX,DS:[BP+6]
		MOV	CX,DS:[BP+18]
		CALL	ARC_3
		MOV	DI,AX			; DI:= AX:=B*SINT

		MOV	AX,SI
		MOV	CX,DS:[BP+24]
		CALL	ARC_3
		MOV	BX,AX			; BX:= AX:=A*COST*COSA

		MOV	AX,DI
		MOV	CX,DS:[BP+22]
		CALL	ARC_3
		SUB	BX,AX			; AX:= A*SINT*SINA
		MOV	AX,DS:[BP+0]
		ADD	AX,BX			; AX:= XC+(A*COST*COSA-A*SINT*SINA)

		PUSH	AX
		MOV	AX,SI
		MOV	CX,DS:[BP+22]
		CALL	ARC_3
		MOV	BX,AX			; BX:= AX:=A*COST*SINA

		MOV	AX,DI
		MOV	CX,DS:[BP+24]
		CALL	ARC_3
		ADD	BX,AX			; AX:= A*SINT*COSA
		MOV	AX,DS:[BP+2]
		SUB	AX,BX
		MOV	BX,AX			; BX:= YC+(A*COST*SINA-A*SINT*COSA)
		POP	AX				; AX:= X 坐标 BX:= Y 坐标
		POP	SI
		POP	CX
		RET

; 画线子程序 (判异或)
S_DRAW:
		TEST	D_ED,80H
		JZ	L_DRAW1
		MOV	DX,3CEH
		MOV	AX,1803H
		OUT	DX,AX
L_DRAW1:
		MOV	AX,D_E5
		MOV	D_D9,AX
		MOV	AX,D_E7
		MOV	D_DB,AX
		CALL	DRAWLINE
		MOV	DX,3CEH
		MOV	AX,3
		OUT	DX,AX
		RET

; 画线子程序 DRAWLINE
;	CALLER :
;	起始点 X0   D_E1
;	起始点 Y0   D_E3
;	终止点 X1   D_E5
;	终止点 Y1   D_E7
;	画线颜色    D_ED
;	BP2	EQU   [BP+12]
;	BP4	EQU   [BP+14]
;	BP6	EQU   [BP+16]
DRAWLINE:
		PUSH	DS
		PUSH	ES
		PUSH	BP
		MOV	BP,OFFSET D_BUF1
		MOV	AX,D_E1
		MOV	CX,D_E5
		CMP	CX,AX
		JGE	GET_OFFSET
		MOV	BX,D_E3
		MOV	DX,D_E7
		MOV	D_E1,CX
		MOV	D_E3,DX
		MOV	D_E5,AX
		MOV	D_E7,BX

; CALCULATE FIRST POINT'S ADDRESS AND MASK
GET_OFFSET:
		MOV	CL,4
		MOV	AX,D_E3
		SHL	AX,CL
		MOV	BX,AX
		SHL	AX,1
		SHL	AX,1
		ADD	AX,BX
		MOV	BX,D_E1
		MOV	CL,3
		SHR	BX,CL
		ADD	AX,BX
		PUSH	AX
; SAVE MASK IN STACK
		MOV	CX,D_E1
		AND	CL,7
		MOV	BX,80H
		SHR	BX,CL
		PUSH	BX

		MOV	DX,3CEH
		MOV	AL,8
		OUT	DX,AL
		INC	DX
		MOV	AL,BL
		OUT	DX,AL
		MOV	DX,3CEH
		XOR	AL,AL
		OUT	DX,AL
		INC	DX
		MOV	AL,D_ED 	   ; 画线颜色
		OUT	DX,AL
		DEC	DX
		MOV	AL,1
		OUT	DX,AL
		INC	DX
		MOV	AL,0FH
		OUT	DX,AL
		MOV	DX,3C4H
		MOV	AL,2
		OUT	DX,AL
		INC	DX
		MOV	AL,0FH
		OUT	DX,AL
; LOAD SEGMENT REGISTERS
		MOV	DX,DS:D_A000
		MOV	DS,DX
		MOV	ES,DX

; CALC DX & DY, DECIDE IF A HORZ OR VERT OR ANGLE LINE
		MOV	AX,80
		MOV	CS:[BP+16],AX
		MOV	SI,CS:D_E5
		SUB	SI,CS:D_E1
		MOV	DI,CS:D_E7
		SUB	DI,CS:D_E3
		JGE	DYISPOS
		NEG	AX
		MOV	CS:[BP+16],AX
		NEG	DI
DYISPOS:
		CMP	SI,0
		JZ	VERT
		CMP	DI,0
		JZ	HORIZ
		JMP	DIAG
; DO VERT LINE
VERT:
		MOV	CX,DI
		INC	CX
		MOV	BX,CS:[BP+16]
		POP	SI
		MOV	DX,3CEH
		MOV	AL,8
		OUT	DX,AL
		INC	DX
		MOV	AX,SI
		OUT	DX,AL
		POP	DI
LOOPVERT:
		MOV	AL,[DI]
		MOV	[DI],AL
		ADD	DI,BX
		LOOP	LOOPVERT
		JMP	LINEDONE
; DO HORIZ LINE
HORIZ:
		MOV	CX,SI
		POP	SI
		POP	DI
; START AT NO BYTE ALAIN
		MOV	AX,CS:D_E1
		AND	AX,7
		JZ	FULLBYTES
		MOV	BX,0FFH
		PUSH	CX
		MOV	CX,AX
		SHR	BX,CL
		POP	CX
		ADD	CX,AX
		SUB	CX,8
		JGE	MASKSET
		NEG	CX
		SHR	BX,CL			; BAD ?????
		SHL	BX,CL
		XOR	CX,CX
MASKSET:
		MOV	DX,3CEH
		MOV	AL,8
		OUT	DX,AL
		INC	DX
		MOV	AL,BL
		OUT	DX,AL
		MOV	AH,[DI]
		MOV	[DI],AL
		INC	DI
; START MIDDLE BYTE
FULLBYTES:
		MOV	BX,CX
		CMP	BX,8
		JL	TRAILBYTES
		SHR	CX,1
		SHR	CX,1
		SHR	CX,1
		MOV	DX,3CEH
		MOV	AL,8
		OUT	DX,AL
		INC	DX
		MOV	AL,0FFH
		OUT	DX,AL
                CLD
LPBYTE:
		MOV	AL,[DI]
		CLD
		STOSB
		LOOP	LPBYTE
; START TRAILBYTES
TRAILBYTES:
		AND	BX,7
		JZ	HORIZDONE
		MOV	AX,0FFFFH
		MOV	CX,BX
		SHR	AX,CL
		XOR	AH,0FFH
		MOV	DX,3CEH
		MOV	AL,8
		OUT	DX,AL
		INC	DX
		MOV	AL,AH
		OUT	DX,AL
		MOV	AL,[DI]
		MOV	[DI],AL
HORIZDONE:
		JMP	LINEDONE
; XXXX
DIAG:
		CMP	SI,DI
		JLE	OCT12
CCT03:
		MOV	CX,SI
		INC	CX
		SHL	DI,1
		MOV	BX,DI
		SUB	BX,SI
		NEG	SI
		ADD	SI,BX
		MOV	CS:[BP+12],DI
		MOV	CS:[BP+14],SI
		MOV	DX,3CEH
		MOV	AL,8
		OUT	DX,AL
		INC	DX
		POP	AX
		POP	DI
NEXT0:
		OUT	DX,AL
		MOV	AH,[DI]
		MOV	[DI],AH
		ROR	AL,1
		ADC	DI,0
		TEST	BX,8000H
		JNZ	DNEG0
		ADD	BX,CS:[BP+14]
		ADD	DI,CS:[BP+16]
		LOOP	NEXT0
		JMP	LINEDONE
DNEG0:
		ADD	BX,CS:[BP+12]
		LOOP	NEXT0
		JMP	LINEDONE
OCT12:
		MOV	CX,DI
		INC	CX
		SHL	SI,1
		MOV	BX,SI
		SUB	BX,DI
		NEG	DI
		ADD	DI,BX
		MOV	CS:[BP+14],DI
		MOV	CS:[BP+12],SI
		MOV	DX,3CEH
		MOV	AL,8
		OUT	DX,AL
		INC	DX
		POP	AX
		POP	DI
		OUT	DX,AL
NEXT1:
		MOV	AH,[DI]
		MOV	[DI],AH
		ADD	DI,CS:[BP+16]
		TEST	BX,8000H
		JNZ	DNEG1
		ADD	BX,CS:[BP+14]
		ROR	AL,1
		ADC	DI,0
		OUT	DX,AL
		LOOP	NEXT1
		JMP	LINEDONE
DNEG1:
		ADD	BX,CS:[BP+12]
		LOOP	NEXT1
LINEDONE:
		MOV	DX,3CEH
		MOV	AL,8
		OUT	DX,AL
		INC	DX
		MOV	AL,0FFH
		OUT	DX,AL
		DEC	DX
		MOV	AL,1
		OUT	DX,AL
		INC	DX
		XOR	AX,AX
		OUT	DX,AL
		POP	BP
		POP	ES
		POP	DS
		RET

;※填充※--------------------------------------------------------------------
;格式:CHR(14)+"P内色,边界色]"
L_P:
		PUSH	WORD PTR D_ED
		CALL	S_Q
		CMP	AL,D_D0
		JA	L_P1
		MOV	D_EE,AL 		; 填充色_FILLVALUE
		CALL	S_Q0
		CMP	AL,D_D0
		JA	L_P1
		MOV	D_ED,AL 		; 边界色_BORDERVALUE

		PUSH	SI
		CALL	FILLADJLINE
		POP	SI
		POP	WORD PTR D_ED
		JMP	L_ST
L_P1:
		POP	WORD PTR D_ED
		RET

;子程序:计算屏幕点地址
PIXELADDR10:
		MOV	CL,BL
		PUSH	DX
		MOV	DX,80
		MUL	DX
		POP	DX
		SHR	BX,1
		SHR	BX,1
		SHR	BX,1
		ADD	BX,AX
		ADD	BX,0
		MOV	ES,CS:D_A000
		AND	CL,7
		XOR	CL,7
		MOV	AH,1
		RET

;填充子程序 FILLADJLINE
;	填充点SEEDX		D_D1
;	填充点SEEDY		D_D3
;	边界色_BORDERVALUE	D_ED
;	填充色_FILLVALUE	D_EE
;	ARGX	EQU	WORD PTR [BP+18]	; SCANLEFT && SCANRIGHT
;	ARGY	EQU	WORD PTR [BP+20]
;	XL	EQU	WORD PTR [BP+22]
;	XR	EQU	WORD PTR [BP+24]
;	ATTRI	EQU	BYTE PTR [BP+26]
;	LEFT	EQU	WORD PTR [BP+28]
;	RIGHT	EQU	WORD PTR [BP+30]
;	OFFSTK	EQU	WORD PTR [BP+0] 	; PRESERVE THE OFFSET OF THE STK

; 填充主程序
FILLADJLINE:
		CMP	D_FB,12H		;判VGA16色?
		JZ	L_FILL
		RET
L_FILL:
		PUSH	ES
		PUSH	BP
		CLI
		MOV	BP,OFFSET D_BUF1
		MOV	WORD PTR DS:[BP],0
;--------------------------------------------------------------------------
; DEAL WITH THE PRESENT LINE , DRAW THE ADJACENT LINE THAT INCLUDE THE SEED
;--------------------------------------------------------------------------
BEGIN0:
		MOV	BX,D_D1
		MOV	DS:[BP+18],BX
		MOV	AX,D_D3
		MOV	DS:[BP+20],AX
		MOV	D_E3,AX
		MOV	D_E7,AX
		CALL	SCANLEFT		; CALLER: (ARGX=X COORDINATE,ARGY= Y COORDINATE)
; RETURN: AX=THE X COORDINATE OF THE MOST LEFT PIXEL
		CMP	DS:[BP+18],AX
		JG	L
		JMP	SHORT MAIN2
L:
		MOV	DS:[BP+22],AX		; PRESERVE THE VALUE IN THE XL (THE MOST LEFT PIXEL)
		MOV	D_E1,AX
		CALL	SCANRIGHT		; CALLER: (ARGX=X COORDINATE,ARGY= Y COORDINATE)
; RETURN: AX=THE X COORDINATE OF THE MOST LEFT PIXEL
		CMP	DS:[BP+18],AX
		JB	R
		JMP	SHORT MAIN2
R:
		MOV	DS:[BP+24],AX		; PRESERVE THE VALUE IN THE XR (THE MOST RIGHT PIXEL)
		MOV	D_E5,AX

		PUSH	WORD PTR D_ED
		MOV	AL,D_EE
		MOV	D_ED,AL
		CALL	DRAWLINE
		POP	WORD PTR D_ED

;-------------------------------------------------------------
; SCANNED THE UP LINE, ANS PUSH STACK WITH THE AVALIABLE VALUE
;-------------------------------------------------------------
		MOV	SI,D_D3 		; SI:=Y COORDINATE
		CMP	SI,0
		JZ	MAIN1
		ADD	SI,-1
		CALL	FILL_1
		JZ	MAIN1			; BORDER LINE , JMP
		PUSH	DS:[BP+24]
		PUSH	DS:[BP+22]
		CALL	PUSH_STK
		POP	DS:[BP+22]
		POP	DS:[BP+24]

;---------------------------------------------------------------
; SCANNED THE DOWN LINE, ANS PUSH STACK WITH THE AVALIABLE VALUE
;---------------------------------------------------------------
MAIN1:
		MOV	SI,D_D3
		CMP	SI,D_D7 		;479
		JE	MAIN2
		INC	SI
		CALL	FILL_1
		JZ	MAIN2			; BORDER LINE , JMP
		CALL	PUSH_STK
MAIN2:
		MOV	AX,DS:[BP]
		CMP	AX,0
		JZ	MEXIT			; IF THE STK IS NULL,JMP
		MOV	DI,OFFSET STK
		MOV	BX,DS:[BP]
		SUB	BX,2
		MOV	AX,DS:[BX+DI]
		MOV	D_D3,AX
		SUB	BX,2
		MOV	AX,DS:[BX+DI]
		MOV	D_D1,AX
		MOV	DS:[BP],BX
		JMP	BEGIN0
MEXIT:
		STI
		POP	BP
		POP	ES
		RET

;子程序1: BORDE_FILL
;	功能: 判断线段XL--XR是否是边界行,或是否已被填充
;	CALLER : XR COORDINATE
;		 XL COORDINATE
;		 ARGY
;	RETURN : AX=0 -> NOT BORDER LINE OR UNFILLED
;		 AX=1 -> BORDER LINE OR FILLED
BORDER_FILL:
		CALL	FILL_2
		PUSH	DI

		MOV	AX,DS:[BP+24]
		CALL	FILL_3

		MOV	CH,0FFH
		CALL	FILL_4
		SHL	CH,1

		MOV	AH,DS:[BP+26]
		CALL	FILL_6

		PUSH	CX			; PUSH THE MASK OF XR
		CALL	FILL_12
		JG	BF1			; BX:=0 XR.XL IN THE SAME BYTE
		MOV	AX,DS:[BP+22]
		CALL	FILL_5
		POP	AX
		AND	CH,AH
		JMP	SHORT BF2
BF1:
		POP	CX
BF2:
		CALL	FILL_11 		; JUDGE THE FIRST BYTEFS
		CMP	AL,CH
		JNZ	BF5
		CALL	FILL_12
		JBE	BF7
		CMP	CX,1
		JBE	BF4
		DEC	CX
		DEC	DI
BF3:
		MOV	AL,ES:[DI]
		CMP	AL,0FFH
		JNZ	BF5			; NOT ,JMP
		DEC	DI
		LOOP	BF3
BF4:
		POP	DI			; DEAL WITH THE LAST BYTE
		MOV	AX,DS:[BP+22]
		CALL	FILL_3

		CALL	FILL_5

		CALL	FILL_11 		; DEAL WITH THE LAST BYTE
		CMP	AL,CH
		JNZ	BF6
		MOV	AX,1			; THE BORDER LINE OR FILLED
		JMP	SHORT BF8
BF5:
		POP	DI
BF6:
		MOV	AX,0			; NOT BORDER LINE OR UNFILLED
		JMP	SHORT BF8
BF7:
		MOV	AX,1
		POP	DI
BF8:
		PUSH	AX
		CALL	FILL_7
		POP	AX
		RET

;子程序2: LEFT_BORDER
;	CALLER:  ARGY:= Y COORDINATE
;		   AX:= X COORDINATE
;	RETURN:    DI:= THE BORDER BITS
LEFT_BORDER:
		PUSH	AX
		CALL	FILL_2

		POP	AX
		PUSH	DI			; 0TH BYTE ADDRESS
		CMP	AX,0
		JBE	PP3
		DEC	AX
		CALL	FILL_3

		MOV	CH,1
		CALL	FILL_4

		MOV	AH,CS:D_ED
		CALL	FILL_6
		MOV	BX,1
		POP	SI
		JMP	SHORT PP0
PP3:
		POP	SI
		MOV	BX,0
		JMP	SHORT PP2
PP0:
		CALL	FILL_11 		; JUDGE THE FIRST BIT
		JZ	PP1
		INC	BX
		SHL	CH,1
		CMP	CH,0
		JNZ	PP0
		CMP	DI,SI
		JBE	PP2
		MOV	CH,1
		DEC	DI
		JMP	SHORT PP0
PP1:
		CMP	DI,SI
		JG	PP2
		DEC	BX
PP2:
		MOV	DI,BX
		CALL	FILL_7
		RET

; 子程序3: RIGH_BORDER
;	CALLER:  ARGY= Y COORDINATE
;		   AX= X COORDINATE
;	RETURN:    DI= THE BORDER BITS
RIGH_BORDER:
		PUSH	AX
		CALL	FILL_2

		POP	AX
		CMP	AX,CS:D_D5
		JGE	PPP3
		INC	AX
		CALL	FILL_3
		MOV	SI,79
		ADD	SI,BX

		MOV	CH,1
		CALL	FILL_4

		MOV	AH,CS:D_ED
		CALL	FILL_6
		MOV	BX,1
		JMP	SHORT PPP0
PPP3:
		MOV	BX,0
		JMP	SHORT PPP2
PPP0:
		CALL	FILL_11 		; JUDGE THE FIRST BIT
		JZ	PPP1
		INC	BX
		SHR	CH,1
		CMP	CH,0
		JNZ	PPP0
		CMP	DI,SI
		JGE	PPP2
		MOV	CH,80H
		INC	DI
		JMP	SHORT PPP0
PPP1:
		CMP	DI,SI
		JB	PPP2
		INC	BX
PPP2:
		MOV	DI,BX
		CALL	FILL_7
		RET

;子程序4:  PUSH_STK
;	功能:	保存需填充点的坐标
;	CALLER :  XR COORDINATE
;		  XL COORDINATE
;		  ARGY -- Y COORDINATE
;	RETURN :  NOTHING
PUSH_STK:
		MOV	BX,CS:[BP+24]
		MOV	AX,CS:[BP+22]
		MOV	CS:[BP+28],AX
		MOV	CS:[BP+30],BX
		ADD	BX,AX
		SHR	BX,1			; BX:= (XR+XL) / 2 = XM

		MOV	CS:[BP+18],BX
		CALL	SCANLEFT		; RETURN AX(XL)
		MOV	CS:[BP+22],AX
		CALL	SCANRIGHT		; RETURN AX(XR)
		MOV	CS:[BP+24],AX

		CMP	AX,CS:[BP+22]
		JG	PUS
		JMP	SHORT PUSH4
PUS:
		CALL	FILL_8
		CMP	AX,0
		JNZ	PUSH4			; AX:=0 UNFILLED
						; PRESERVE THE VALUE
		CALL	FILL_9
PUSH4:
		PUSH	CS:[BP+22]
		PUSH	CS:[BP+24]
PUSH0:
		CMP	WORD PTR CS:[BP+22],1
		JBE	PUSH1
		MOV	AX,CS:[BP+22]		; LEFT
		PUSH	AX
		CALL	LEFT_BORDER		; CALLER: AX,ARGY
		POP	BX			; BX:= AX:= XL
		CMP	BX,DI
		JBE	PUSH1
		SUB	BX,DI			; NEXT SCAN VALUE
		MOV	CS:[BP+18],BX
		MOV	CS:[BP+24],BX
		CALL	SCANLEFT		; RETURN AX(XL)
		MOV	CS:[BP+22],AX
		ADD	AX,CS:[BP+24]
		SHR	AX,1			; AX:= (XR+XL) / 2
		CMP	AX,CS:[BP+28]
		JBE	PUSH1			; AX <= LEFT ,JMP

		CALL	FILL_8
		CMP	AX,0
		JNZ	PUSH0			; AX:=0 UNFILLED

		CALL	FILL_9			; PRESERVE THE VALUE
		JMP	SHORT PUSH0
PUSH1:
		POP	CS:[BP+24]
		POP	CS:[BP+22]
PUSH2:
		CMP	CS:[BP+24],638
		JGE	PUSH3
		MOV	AX,CS:[BP+24]
		PUSH	AX			; RIGHT
		CALL	RIGH_BORDER
		POP	BX
		ADD	BX,DI			; NEXT SCAN VALUE

		MOV	CS:[BP+18],BX
		MOV	CS:[BP+22],BX
		CALL	SCANRIGHT		; RETURN AX(XR)
		MOV	CS:[BP+24],AX
		ADD	AX,CS:[BP+22]
		SHR	AX,1			; AX:= (XR+XL) / 2
		CMP	AX,CS:[BP+30]
		JGE	PUSH3			; AX >= RIGHT

		CALL	FILL_8
		CMP	AX,0
		JNZ	PUSH2			; AX:=0 UNFILLED
		CALL	FILL_9
		JMP	SHORT PUSH2
PUSH3:
		RET

; 子程序5: SCANLEFT
;	功能:	得到左边界点的坐标
;	CALLER : ARGX -> X COORDINATE
;		 ARGY -> Y COORDINATE/
;	RETURN : AX <= ARGX
SCANLEFT:
		CALL	FILL_2

		MOV	AX,CS:[BP+18]
		CALL	FILL_3

		MOV	CH,0FFH
		CALL	FILL_4
		PUSH	CX			; PRESERVE THE CH
		MOV	CH,01
		SHL	CH,CL

		MOV	AH,CS:D_ED
		CALL	FILL_6

		CALL	FILL_11 		; ARGX IS THE BORDER PIXEL OR NOT
		JNZ	LEFT4			; AL != 0 , ARGX IS THE BORDERVALUE,JMP

		CMP	SI,0			; SI:=0 THE 0TH BYTE OF THE SCREEN
		JNZ	LEFT3

		XOR	CL,7			; THE FIRST BYTE OF THE SCREEN
LEFT1:
		SHL	CH,1
		CMP	CH,0
		JZ	LEFT2
		DEC	CL
		CALL	FILL_11 		; JUDGE THE FIRST BIT
		JZ	LEFT1
		INC	CL
LEFT2:
		SUB	DI,BX
		XOR	CH,CH
		ADD	DI,CX
		POP	CX
		JMP	SHORT LEFT11
LEFT3:
		POP	CX
		MOV	AL,ES:[DI]
		DEC	DI
		AND	AL,CH
		JNZ	LEFT7			; THE FIRST BYTE INCLUDE THE BORDER,JMP
		JMP	SHORT LEFT5
LEFT4:
		POP	CX			; ARGX IS THE BORDERVALUE
		MOV	DI,CS:[BP+18]
		CMP	DI,0
		JBE	LEFT11
		DEC	DI
		JMP	SHORT LEFT11
LEFT5:
		MOV	CX,SI
		DEC	CX			; THE SECOND BYTE OF THE SCREEN
		CMP	CX,0
		JNZ	LEFT6
		MOV	AL,ES:[DI]
		JMP	SHORT LEFT8
LEFT6:
		STD
		REPE	SCASB
		MOV	AL,ES:[DI+1]
		CMP	AL,0
		JNZ	LEFT7
		CMP	CX,0
		JNZ	LEFT6
		MOV	AL,ES:[DI]
		JMP	SHORT LEFT8
LEFT7:
		INC	DI
LEFT8:
		CALL	FILL_10
LEFT9:
		SHR	AL,1
		JC	LEFT10
		LOOP	LEFT9
		JMP	SHORT LEFT11		; FIND FAILED
LEFT10:
		ADD	DI,CX
LEFT11:
		CALL	FILL_7
		MOV	AX,DI
		RET

;子程序6: SCANRIGHT
;	功能 :	得到右边界点坐标
;	CALLER:  ARGX,ARGY
;	RETURN:  AX >= ARGX
SCANRIGHT:
		CALL	FILL_2

		MOV	AX,CS:[BP+18]
		CMP	AX,639
		JZ	L004			; THE SEED IS IN THE 79TH BYTE
		CALL	FILL_3

		CALL	FILL_5
		PUSH	CX
		XOR	CL,7
		MOV	CH,01
		SHL	CH,CL

		MOV	AH,CS:D_ED
		CALL	FILL_6

		CALL	FILL_11 		; ARGX IS THE BORDER PIXEL OR NOT
		JNZ	L003			; AL != 0 , ARGX IS THE BORDERVALUE

; INSPECT THE FIRST BYTE FOR BORDER PIXELS
		POP	CX
		MOV	AL,ES:[DI]
		INC	DI
		AND	AL,CH
		JNZ	L000			; THE FIRST BYTE INCLUDE BORDER VALUE ,JMP

; SCAN REMAINDER OF LINE FOR BORDER PIXELS
		MOV	CX,80
		SUB	CX,SI
		CMP	CX,0
		JZ	L000			; THE 80TH BYTE,JMP
		DEC	CX
		JZ	L005			; THE 79TH BYTE,JMP
		CLD
		REPE	SCASB
		MOV	AL,ES:[DI-1]
		JMP	SHORT L000

; COMPUTE X VALUE OF BORDER PIXEL
L004:
		MOV	DI,639
		JMP	SHORT L007
L005:
		MOV	AL,ES:[DI]
L000:
		CALL	FILL_10
L001:
		SHL	AL,1
		JC	L002
		LOOP	L001
L002:
		SUB	DI,CX			; DI:= X-COORIDINATE OF BORDER PIXEL
		CMP	DI,640
		JNE	L007
		DEC	DI
		JMP	SHORT L007
L003:
		POP	CX
		MOV	DI,CS:[BP+18]
		OR	DI,DI
		JZ	L007
		DEC	DI
L007:
		CALL	FILL_7
		MOV	AX,DI
		RET

;FILLADJLINE的通用子程序
FILL_1:
		MOV	CS:[BP+20],SI		; ARGY
		PUSH	CS:[BP+24]
		PUSH	CS:[BP+22]
		MOV	AL,CS:D_ED
		MOV	CS:[BP+26],AL
		CALL	BORDER_FILL		; RETURN: AX
		POP	CS:[BP+22]
		POP	CS:[BP+24]
		CMP	AX,1
		RET

FILL_2:
		MOV	AX,CS:[BP+20]
		XOR	BX,BX
		CALL	PIXELADDR10		;计算屏幕点地址
		MOV	DI,BX
		RET

; CALCULATE OFFSET OF X IN ROW
FILL_3:
		MOV	SI,AX
		MOV	CL,3
		SHR	SI,CL
		ADD	DI,SI
		RET

; CALCULATE A BIT MASK FOR THE FIRST BYTE TO SCAN
FILL_4:
		MOV	CL,AL
		AND	CL,7
		XOR	CL,7
		SHL	CH,CL
		RET

FILL_5:
		MOV	CH,0FFH
		MOV	CL,AL
		AND	CL,7
		SHR	CH,CL
		RET
; CONFIGURE THE GRAPHICS CONTROLLER
FILL_6:
		MOV	DX,3CEH
		MOV	AL,2
		OUT	DX,AX
		MOV	AX,805H
		OUT	DX,AX
		MOV	AX,0F07H
		OUT	DX,AX
		RET

; RESTORE DEFAULT GRAPHICS CONTROLLER STATE AND RETURN TO CALLER
FILL_7:
		MOV	AX,2
		OUT	DX,AX
		MOV	AL,5
		OUT	DX,AX
		RET

FILL_8:
		MOV	AL,CS:D_EE
		MOV	CS:[BP+26],AL
		CALL	BORDER_FILL
		RET

FILL_9:
		MOV	DI,OFFSET STK
		MOV	BX,CS:[BP+0]
		MOV	SI,CS:[BP+22]
		ADD	SI,CS:[BP+24]
		SHR	SI,1			; SI := (XL+XR)/2
		MOV	[DI+BX],SI		; PUSH X COORDINATE[( XL + XR ) / 2]
		ADD	BX,2
		MOV	SI,CS:[BP+20]		; PUSH Y COORDINATE
		MOV	[DI+BX],SI
		ADD	BX,2
		MOV	CS:[BP+0],BX
		RET

FILL_10:
		SUB	DI,BX
		MOV	CL,3
		SHL	DI,CL
		MOV	CX,8
		RET

FILL_11:
		MOV	AL,ES:[DI]
		AND	AL,CH
		RET

FILL_12:
		MOV	BX,CS:[BP+24]
		MOV	CL,3
		SHR	BX,CL
		MOV	AX,CS:[BP+22]
		SHR	AX,CL
		SUB	BX,AX
		MOV	CX,BX
		CMP	CX,0
		RET

;----------------------------------------------------------------------------
;子程序:处理形如'@宽度,高度,字体,旋转'的设置字型命令
S_ZX:
		MOV	BYTE PTR D_E9,0FFH	;D_E9=0FFH(本格式状态标志)
		CALL	S_Q			;取宽度
		OR	AX,AX
		JZ	L_ZX2
		CMP	AX,640
		JBE	L_ZX1
		MOV	AX,640
L_ZX1:
		MOV	D_X,AX			;汉字的宽度
L_ZX2:
		CMP	BYTE PTR DS:[SI],','    ;有无高度?
		JNZ	L_ZX9
		CALL	S_Q0			;取高度
		OR	AX,AX
		JZ	L_ZX4
		CMP	AX,480
		JB	L_ZX3
		MOV	AX,479
L_ZX3:
		MOV	D_Y,AX			;汉字的高度
L_ZX4:
		CMP	BYTE PTR DS:[SI],','    ;有无字体?
		JNZ	L_ZX9
		INC	SI
		CMP	BYTE PTR DS:[SI],','
		JZ	L_ZX8
		CMP	BYTE PTR DS:[SI],'9'
		JA	L_ZX9
		CALL	S_Q
		MOV	DS:[DI],AL
L_ZX8:
		CMP	BYTE PTR DS:[SI],','     ;有无旋转
		JNZ	L_ZX9
		INC	SI
		CMP	BYTE PTR DS:[SI],'9'
		JA	L_ZX9
		LODSB
		SUB	AL,'1'
		MOV	DS:D_094B,AL		;D_094B=0不旋转,=1左旋90度
L_ZX9:
		RET				;      =2旋转180,=3右旋90度

;子程序:处理形如'@A-Z,旋转'的设置字型命令
S_ZXA:
		CMP	AL,'A'
		JB	L_ZXA9
		CMP	AL,'P'
		JA	L_ZXA5
L_ZXA2:
		SUB	AL,'A'                  ;字型A-P
L_ZXA3:
		MOV	BL,AL
		MOV	AL,D_ZX[BX]
		JMP	SHORT L_ZXA8
L_ZXA4:
		CMP	AL,'X'
		JA	L_ZXA5
		SUB	AL,'Q'                  ;字型Q-X
		MOV	DL,0AH			;再扩
		JMP	SHORT L_ZXA3
L_ZXA5:
		CMP	AL,'a'
		JB	L_ZXA9
		CMP	AL,'p'
		JA	L_ZXA6
		AND	AL,5FH			;字型A-P
		MOV	DL,0AH			;再扩
		JMP	SHORT L_ZXA2
L_ZXA6:
		CMP	AL,'t'
		JA	L_ZXA7
		SUB	AL,'q'                  ;字型Q-T
		MOV	DL,8AH
		JMP	SHORT L_ZXA3
L_ZXA7:
		SUB	AL,'u'                  ;字型U-X
		MOV	BL,AL
		MOV	AL,D_ZX[BX]
		AND	AL,0FH
L_ZXA8:
		OR	AL,DL
		MOV	[DI],AL
		CMP	BYTE PTR DS:[SI],','     ;<旋转>
		JNZ	L_ZXA9
		INC	SI
		LODSB
		SUB	AL,'1'
		MOV	CS:D_094B,AL		;D_094B=0不旋转,=1左旋90度
L_ZXA9:
		RET

D_ZX		DB	40H,41H,44H,45H 	;ABCD
		DB	50H,51H,54H,55H 	;EFGH
		DB	60H,61H,64H,65H 	;IJKL
		DB	70H,71H,74H,75H 	;MNOP
D_X		DW	24			;宽度
D_Y		DW	24			;高度
;【显示汉字】
L_XSHZ:
		MOV	DI,OFFSET D_F0		;字型
L_XS0:
		LODSB
		CMP	AL,'['
		JZ	L_XS0

		CMP	AL,'@'                  ;<设置字型>
		JNZ	L_XS11
		MOV	AL,DS:[SI]
		XOR	BH,BH
		XOR	DL,DL
		CMP	AL,'9'
		JA	L_XS1
		CALL	S_ZX			;'@宽度,高度,字体,旋转'格式
		JMP	SHORT L_XS0
L_XS1:
		CMP	AL,0A0H
		JA	L_XS0
		INC	SI
		MOV	BYTE PTR D_E9,0 	;D_E9=0 (普通格式'@A,旋转')
		CALL	S_ZXA
		JMP	SHORT L_XS0
L_XS11:
		CMP	AL,'*'                  ;<前景色>
		JNZ	L_XS12
		CALL	S_Q
		MOV	D_F1,AL
		JMP	L_XS0
L_XS12:
		CMP	AL,'#'                  ;<背景色>
		JNZ	L_XS13
		CALL	S_Q
		MOV	D_F2,AL
		JMP	L_XS0
L_XS13:
		CMP	AL,'_'                  ;<水平定位>
		JNZ	L_XS14
		CALL	S_Q
		MOV	D_D1,AX
		JMP	L_XS0
L_XS14:
		CMP	AL,'|'                  ;<垂直定位>
		JNZ	L_XS15
		CALL	S_Q
		MOV	D_D3,AX
		JMP	L_XS0
L_XS15:
		CMP	AL,'^'                  ;<字间距>
		JNZ	L_XS16
		CALL	S_Q
		MOV	D_F3,AX
		JMP	L_XS0
L_XS16:
		CMP	AL,'&'                  ;<行间距>
		JNZ	L_XS17
		CALL	S_Q
		MOV	D_F5,AX
		JMP	L_XS0
L_XS17:
		CMP	AL,'\'                  ;<复盖>
		JNZ	L_XS19
		CALL	S_Q
		CMP	AL,0
		JZ	L_XS18
		MOV	AL,1
L_XS18:
		MOV	D_094A,AL
		JMP	L_XS0
L_XS19:
		CMP	AL,']'                  ;<结束>
		JNZ	L_XS20
		MOV	AX,D_F7
		ADD	AX,D_F5
		ADD	D_D3,AX
		XOR	AX,AX
		MOV	D_D1,AX
		MOV	D_F7,AX
		RET
L_XS20:
		CMP	AL,0A1H 		;判汉字?
		JNB	L_XS21
		XOR	AH,AH			;西文
		MOV	BX,0			;BX=字型编号(西文:0等宽)
		JMP	SHORT L_XS24
L_XS21:
		MOV	AH,AL			; 汉字
		LODSB
		XOR	BH,BH
		CMP	BYTE PTR D_E9,0FFH	;格式:@宽度,高度,字体,旋转
		JNZ	L_XS22
		MOV	BL,DS:[DI]		;字体编码
		CMP	BL,33
		JBE	L_XS24
		MOV	BL,0
		JMP	SHORT L_XS24
L_XS22:
		MOV	BL,DS:[DI]
		CMP	BL,40H
		JBE	L_XS23
		AND	BL,070H
		MOV	CL,4
		SHR	BL,CL
		SUB	BL,4			;字体
		JMP	SHORT L_XS24
L_XS23:
		MOV	BL,0
L_XS24:
		MOV	DX,AX			;汉字内码
		PUSH	SI
		XOR	AX,AX
		MOV	ES,AX
		CMP	WORD PTR ES:[1FAH],0	;判安装READSL?		7.6
		JNZ	L_XS25
		JMP	L_XS56
L_XS25:
		CMP	BYTE PTR D_E9,0FFH	;格式:@宽度,高度,字体,旋转
		JNZ	L_XS30
		MOV	AX,D_X			;宽度
		MOV	CX,D_Y			;高度
		JMP	SHORT L_XS40
L_XS30:
		CMP	BYTE PTR DS:[DI],40H
		JB	L_XS31
		MOV	CX,24			;24点阵 CX=高度
		MOV	AX,24			;AX=宽度
		JMP	SHORT L_XS32
L_XS31:
		MOV	CX,16			;16点阵
		MOV	AX,16
L_XS32:
		TEST	BYTE PTR DS:[DI],1	;横扩?
		JZ	L_XS33
		SHL	AX,1
L_XS33:
		TEST	BYTE PTR DS:[DI],2	;再扩?
		JZ	L_XS34
		SHL	AX,1
L_XS34:
		TEST	BYTE PTR DS:[DI],80H	;4倍扩?
		JZ	L_XS35
		SHL	AX,1
L_XS35:
		TEST	BYTE PTR DS:[DI],4	;纵扩
		JZ	L_XS36
		SHL	CX,1
L_XS36:
		TEST	BYTE PTR DS:[DI],8	;再扩
		JZ	L_XS37
		SHL	CX,1
L_XS37:
		TEST	BYTE PTR DS:[DI],80H	;4倍扩
		JZ	L_XS40
		SHL	CX,1
L_XS40:
		PUSH	CX
		CMP	CX,D_F7 		;[0F7H]=本行最大Y值
		JBE	L_XS41
		MOV	D_F7,CX
L_XS41:
		PUSH	AX
		PUSH	DX
		ADD	AX,7
		MOV	CL,3
		SHR	AX,CL
		MOV	CX,AX			;宽度占字节数
		XOR	DX,DX
		MOV	AX,768			;768=缓冲区的大小
		DIV	CX
		MOV	D_E1,AX 		;D_E1=缓冲区可容纳汉字的高度

		POP	DX			;DX=汉字内码
		POP	AX			;AX=汉字宽度
		POP	CX			;CX=汉字高度

		CMP	D_FB,12H		;判VGA16色?
		JZ	L_XS42
		POP	SI
		JMP	L_XSHZ
L_XS42:
		MOV	BP,0			;BP=0水平点阵
		CMP	DS:D_094B,1		;=1左旋90度
		JNZ	L_XS43
		MOV	BP,8000H		;BP=1000,0000,0000,0000
L_XS43:
		CMP	DS:D_094B,2		;=2旋转180
		JNZ	L_XS44
		MOV	BP,0A000H		;BP=1010,0000,0000,0000
L_XS44:
		CMP	CS:D_094B,3		;=3右旋90度
		JNZ	L_XS45
		MOV	BP,0C000H		;BP=1100,0000,0000,0000
L_XS45:
		MOV	SI,0			;SI=起始还原行
		MOV	DI,D_E1 		;DI=终止还原行
		CMP	DI,CX
		JB	L_XS50
		MOV	DI,CX
		MOV	D_E1,CX

;INT 7EH
;读取字模点阵(包括汉字及西文)
;入口参数:DX=汉字内码(若DH=0则DL为字符ASCII码)
;	  AX=字符宽度
;	  CX=字符高度
;	  BX=字体编号(西文:=0 等宽,汉字:字体)
;	  SI=起始还原行
;	  DI=终止还原行
;	  BP:第15位=1旋转,=0不旋转
;	     第14位=1向左旋转,=0向右旋转
;	     第13位=1旋转90度,=0旋转180度
;	     第0位=1垂直点阵,=0水平点阵
;返回参数:DX:BX=点阵缓冲区地址指针
;	     AX=返回字符实际宽度
;	     CX=字符实际高度
;注:当西文字符旋转90度时,返回的是旋转后的宽和高.

L_XS50:
		PUSH	AX			;保存寄存器
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	BP
		PUSH	D_E1
		CALL	S_INT7E 		;读矢量字库

	; 计算 D_D1 (XPIXEL)
	;      D_D3 (YPIXEL)
		PUSH	BX
		PUSH	AX
		MOV	BX,D_D3 		;BX=屏幕Y坐标
		ADD	BX,CX			;BX=屏幕Y坐标+字体实际高度
		DEC	BX
		CMP	BX,D_D7 		;D_D7=屏幕Y最大值
		JBE	L_XS51
		MOV	AX,0E07H		;响铃
		CALL	INT10
		XOR	AH,AH			;读键
		INT	16H
		CALL	S_CLS			;清屏
		JMP	SHORT L_XS52
L_XS51:
		MOV	BX,D_D1 		;BX=屏幕X坐标
		ADD	BX,AX			;BX=CX+汉字的实际宽度
		DEC	BX
		CMP	BX,D_D5 		;D_D5=屏幕X最大值
		JBE	L_XS52

		MOV	D_D1,0			;换行
		MOV	BX,D_F5
		ADD	BX,D_F7
		ADD	D_D3,BX
		MOV	BX,D_D3
		ADD	BX,CX
		DEC	BX

		CMP	BX,D_D7
		JBE	L_XS52
		MOV	AX,0E07H		;响铃
		CALL	INT10
		XOR	AH,AH			;读键
		INT	16H
		CALL	S_CLS			;清屏
L_XS52:
		POP	AX
		POP	BX

		CALL	SHOWFONT		; 显示点阵

		POP	D_E1
		POP	BP
		POP	DI
		POP	SI
		POP	DX
		POP	CX
		POP	BX
		POP	AX

		PUSH	D_D3			;保存屏幕Y坐标
L_XS53:
		CMP	DI,CX
		JGE	L_XS55			;显示完整汉字,转
		PUSH	AX
		MOV	AX,D_E1
		ADD	D_D3,AX
		POP	AX
		ADD	SI,D_E1
		ADD	DI,D_E1
		CMP	DI,CX
		JBE	L_XS54
		MOV	DI,CX
		SUB	DI,SI
		MOV	D_E1,DI
		MOV	DI,CX
L_XS54:
		PUSH	AX			;保存寄存器
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	BP
		PUSH	D_E1
		INT	7EH			;			6.28
		CALL	SHOWFONT		; 显示点阵
		POP	D_E1
		POP	BP
		POP	DI
		POP	SI
		POP	DX
		POP	CX
		POP	BX
		POP	AX
		JMP	L_XS53			;分段还原,显示点阵
L_XS55:
		POP	D_D3			;屏幕Y坐标
		MOV	AX,D_D1 		;AX=屏幕X坐标
		ADD	AX,DS:VARX		;AX=AX+汉字的实际宽度
		ADD	AX,D_F3 		;AX=AX+汉字的实际宽度+字间距
		MOV	D_D1,AX 		;改变屏幕X坐标
		MOV	AX,D_D5

		CMP	D_D1,AX
		JBE	L_XS56

		MOV	D_D1,0			;换行
		MOV	AX,D_F5
		ADD	AX,D_F7
		ADD	D_D3,AX
		MOV	AX,D_D3
		CMP	AX,D_D7
		JBE	L_XS56
		MOV	AX,0E07H		; 响铃
		CALL	INT10
		XOR	AH,AH			; 读键
		INT	16H
		CALL	S_CLS
L_XS56:
		POP	SI			;准备显示下一个点阵
		JMP	L_XSHZ

D_094A		DB	1			;覆盖标志 1=不覆盖
D_094B		DB	0			;D_094B=0不旋转,=1左旋90度
						;      =2旋转180,=3右旋90度
VARX		DW	0			;汉字的宽度
VAR_PB		DB	0			;显示汉字的屏蔽码
VAR_PBL 	DB	0			;汉字一个汉字的左字节屏蔽码
VAR_PBR 	DB	0			;最后一个汉字的右字节屏蔽码

SHOWFONT:
		PUSH	DS
		PUSH	ES
		CLI
		MOV	SI,BX
		MOV	DS,DX			;DS:SI -> 缓冲区地址
		MOV	CS:VARX,AX		;VARX=汉字的宽度
		PUSH	CS:VARX

		TEST	CS:D_F1,80H
		JZ	L_SHOW1
		MOV	DX,3CEH
		MOV	AX,1803H
		OUT	DX,AX
L_SHOW1:
		MOV	BX,CS:D_D1		;屏幕 X 坐标
		MOV	AX,CS:D_D3		;屏幕 Y 坐标
		CALL	PIXELADDR10		;计算屏幕点地址 ES:BX -> 显示缓冲区的地址
		INC	CL			; CL:= NUMBER OF BITS TO SHIFT LEFT
		AND	CL,7
		MOV	DI,BX

		MOV	BL,CL			; PRESERVE CL
		MOV	AX,CS:VARX		; VARX->PIXEL
		DEC	AX
		MOV	CX,0FF07H
		AND	CL,AL
		XOR	CL,7
		SHL	CH,CL			; CH:= BIT MASK FOR LAST BYTE IN ROW

		MOV	AX,CS:VARX
		MOV	CL,3
		ADD	AX,07
		SHR	AX,CL
		MOV	CS:VARX,AX		; VARX-> BYTE
		MOV	CL,BL			; CL:= NUMBER OF BITS TO SHIFT LEFT

		MOV	DX,3CEH
		MOV	AX,805H 		; MODE REG (READ MODE 1,WRITE MODE 0)
		OUT	DX,AX
		MOV	AX,7			; COLOR DON'T CARE REG
		OUT	DX,AX
		MOV	AX,0F01H		; ENABLE SET /RESET REG
		OUT	DX,AX

		MOV	DL,0C4H
		MOV	AX,0F02H		; FOUR PLANES
		OUT	DX,AX
		CMP	CX,0FF00H		; IF MASK <>0FFH OR BITS TO SHIFT<>0
		JNE	L15			; JUMP IF NOT BYTE_ALIGNED

	; ROUTINE FOR BYTE_ALIGNED BIT BLOCKS
		MOV	CX,CS:VARX
		MOV	DL,0CEH 		; DX:= 3CEH
L11:
		PUSH	DI
		PUSH	CX
L12:
		MOV	AH,0FFH
		CALL	SHOWBIT_1
		LODSB
		MOV	AH,AL
		CALL	SHOWBIT_2
		INC	DI
		LOOP	L12
		POP	CX
		POP	DI
		ADD	DI,80			; ES:DI -> NEXT PIXEL ROW IN BUFFER
		DEC	BYTE PTR CS:D_E1
		JNZ	L11
		JMP	LEXIT

	; ROUTINE FOR NON_ALIGNED BIT BLOCKS
L15:
		MOV	BX,0FFH 		; BH:= 0 (MASK FOR FIRST BYTE IN ROW)
						; BL:= 0FFH
		MOV	AL,CH			; AL:= MASK FOR LAST BYTE IN PIXEL ROW
		CBW				; AH:= 0FFH(MASK FOR LAST-1 BYTE)
		CMP	CS:VARX,1
		JNE	L16			; JUMP IF MORE THAN ONE BYTE PER ROW
		MOV	BL,CH
		MOV	AH,CH			; AH:= MASK FOR LAST-1 BYTE
		XOR	AL,AL			; AL:= 0(MASK FOR LAST BYTE)
L16:
		SHL	AX,CL
		SHL	BX,CL
		MOV	CS:VAR_PBL,AH		; LEFT END
		MOV	CS:VAR_PBR,AL		; RIGHT END
		MOV	CS:VAR_PB,BH		; START

		MOV	BX,CS:VARX
		MOV	DL,0CEH 		; GRAPHICS CONTROLLER PORT
L18:
		PUSH	DI			; PRESERVE OFFSET OF START OF PIXEL ROW
		PUSH	SI
		PUSH	BX			; PRESERVE BYTES PER PIXEL ROW
		LODSW				; AH:= 2ND BYTE OF PIXELS
						; AL:= 1ST BYTE OF PIXELS
		DEC	SI			; DS:SI-> 2ND BYTE OF PIXELS
		TEST	CL,CL
		JNZ	L19			; JMP IF NOT LEFT_ALIGNED
		DEC	BX			; BX:= BYTES PER ROW -1
		JNZ	L20			; JUMP IF AT LEAST 2 BYTES PER ROW
		JMP	SHORT L22
L19:
		ROL	AX,CL			; AH:= LEFT PART OF 1ST BYTE,RIGHT PART OF 2ND BYTE
						; AL:= RIGHT PART OF 1ST BYTE,LEFT PART OF 2ND BYTE
		PUSH	AX
		MOV	AH,CS:VAR_PB
		CALL	SHOWBIT_1
		POP	AX
		PUSH	AX
		AND	AH,CS:VAR_PB
		CALL	SHOWBIT_2		; SET PIXELS FOR LEFT PART OF FIRST BYTE
		POP	AX
		INC	DI
		DEC	BX			; BX:= BYTES PER ROW-1
L20:
		DEC	BX
		JNG	L22
L21:
		PUSH	AX
		MOV	AH,0FFH 		; SET BIT MASK REG FOR SUCCEEDING BYTES
		CALL	SHOWBIT_1
		POP	AX
		MOV	AH,AL
		CALL	SHOWBIT_2

		INC	DI			; BYTE AND LEFT PART OF NEAR BYTE
		LODSW				; AH:= NEXT +1 BYTE OF PIXELS
						; AL:= NEXT BYTE OF PIXELS
		DEC	SI
		ROL	AX,CL			; AH:= LEFT PART OF NEXT BYTE,RIGHT PART OF NEXT+1 BYTE
						; AL:= RIGHT PART OF NEXT BYTE,LEFT PART OF NEXT+1 BYTE
		DEC	BX
		JNZ	L21			; LOOP ACROSS PIXEL ROW
L22:
		MOV	BX,AX			; BH:= RIGHT PART OF LAST BYTE,LEFT PART OF LAST-1 BYTE
						; BL:= LEFT PART OF LAST BYTE,RIGHT PART OF LAST-1 BYTE
		MOV	AH,CS:VAR_PBL		; AH:= MASK FOR LAST-1 BYTE
						; AL:= BIT MASK REG NUMBER
		CALL	SHOWBIT_1
		MOV	AH,BL
		AND	AH,CS:VAR_PBL
		CALL	SHOWBIT_2		; SET PIXELS FOR LAST-1 BYTE

		INC	DI
		MOV	AH,CS:VAR_PBR		; MASK FOR LAST BYTE IN PIXEL ROW
		CALL	SHOWBIT_1
		MOV	AH,BH
		AND	AH,CS:VAR_PBR
		CALL	SHOWBIT_2

		POP	BX
		POP	SI
		ADD	SI,BX			; DS:SI -> NEXT ROW IN BIT BLOCK
		POP	DI
		ADD	DI,80			; ES:DI -> NEXT PIXEL ROW IN BUFFER
		DEC	BYTE PTR CS:D_E1
		JNZ	L18			; LOOP DOWN PIXEL ROWS
LEXIT:
		MOV	AX,0F02H
		OUT	DX,AX
		MOV	AX,1			; ENABLE SET/RESET REG
		OUT	DX,AX
		MOV	AX,3
		OUT	DX,AX
		MOV	AX,5
		OUT	DX,AX
		MOV	AX,0F07H
		OUT	DX,AX
		MOV	AX,0FF08H
		OUT	DX,AX
		POP	CS:VARX 		; THE WIDTH OF THE SYMBOL
		STI
		POP	ES
		POP	DS
		RET
SHOWBIT_1:
		MOV	AL,8
		OUT	DX,AX
		MOV	AH,CS:D_F2		; 背景色
		MOV	AL,0			; SET / RESET REG
		OUT	DX,AX
		OR	AH,AH
		JNZ	A_ND1
		CMP	BYTE PTR CS:D_094A,1	;2.7
		JZ	A_ND2
A_ND1:
		AND	BYTE PTR ES:[DI],0FFH
A_ND2:
		RET
SHOWBIT_2:
		MOV	AL,8			; BIT MASK REG
		OUT	DX,AX
		MOV	AH,CS:D_F1		; 前景色
		MOV	AL,0			; SET / RESET REG
		OUT	DX,AX
		AND	BYTE PTR ES:[DI],0FFH
		RET

;公用子程序==================================================================
;子程序:取参数
S_Q0:
		INC	SI
S_Q:
		PUSH	CX
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
		POP	CX
		CMP	DL,','
		JNZ	L_SQ5
		CLC
		RET
L_SQ5:
		STC
		RET

;子程序:取字符行列坐标并转换为字符左上角点坐标
S_QHL:
		CALL	S_Q
		MUL	D_FA
		OR	AX,AX
		JZ	L_QHL
		CMP	D_FB,12H
		JNZ	L_QHL
		SUB	AX,2
L_QHL:
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
		MOV	ES:D_F1,AL
		MOV	ES:D_D5,SI		;最大X坐标
		MOV	ES:D_D7,DI		;最大Y坐标
		MOV	ES:D_F9,CL		;显示行数
		MOV	ES:D_FA,CH		;每字符行扫描线数

		MOV	AL,0
		MOV	ES:D_F0,40H		;默认A字型
		MOV	ES:D_EE,0FFH		;填充色
		MOV	ES:D_F5,0
		MOV	ES:D_100,16		;设置比例因子
		MOV	BYTE PTR ES:D_BUF3,0	;清命令串
		PUSH	DS
		XOR	AX,AX
		MOV	DS,AX
		MOV	AL,DS:[44AH]
		POP	DS
		MOV	ES:D_FC,AL		;每行字符数
		RET

;子程序:读矢量字库
S_INT7E:
		INT	7EH
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
		CALL	DWORD PTR D_INT1C
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
		MOV	WORD PTR D_ADDR,OFFSET D_BUF3
		CMP	D_NUM,-1		;判无限循环?
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
STK		DB	256 DUP(0)
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
		CMP	AL,85H			;判安装INT10V?
		JZ	L_S30
		CMP	AL,84H			;判安装INT10K?
		JNZ	L_S40
		CMP	BYTE PTR ES:[10DH],'V'  ;判安装过INT10V?
		JNZ	L_S30
		MOV	SI,10EH
		MOV	DI,SI
		MOV	CX,OFFSET BEGIN-10DH
		REP	MOVSB			;覆盖原INT10K
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

D_NAME		DB	'INT10V',0
ALREADY 	DB	'特显模块已经驻留!',7,13,10,'$'
D_GW		DB	'GWINT10K.COM',0
NOGW		DB	'没有文件 GWINT10K.COM !',7,13,10,'$'

SEG_A		ENDS
		END	START

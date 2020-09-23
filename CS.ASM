;	CS.ASM (2.13L)
;	1996.2.1, 2.8, 2.23, 5.31

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:
		INT	12H
		MOV	DX,40H
		MUL	DX
		MOV	DX,CS
		SUB	AX,DX
		MOV	DX,10H
		MUL	DX
		MOV	BX,OFFSET D_DISP1+5
		MOV	CX,6
		MOV	SI,10
L_10:
		DIV	SI
		OR	DL,'0'
		MOV	[BX],DL
		DEC	BX
		XOR	DX,DX
		LOOP	L_10
		XOR	AX,AX
		MOV	ES,AX
		MOV	DX,OFFSET D_DISP
		MOV	AH,9
		INT	21H

		CMP	BYTE PTR DS:[5DH],'1'   ;显示打印参数?
		JZ	L_19
L_18:
		JMP	L_100
L_19:
		MOV	AH,6			;取打印参数
		INT	17H
		CMP	AH,6
		JZ	L_18
		PUSH	DX
		MOV	DX,OFFSET D_P
		MOV	AH,9
		INT	21H
		POP	DX

		PUSH	DS
		PUSH	ES
		POP	DS
		CMP	DH,'H'                  ;判HPRNT?
		JZ	L_1A
		MOV	DX,0F8H 		;打印机型号
		JMP	SHORT L_1E
L_1A:
		MOV	DX,88H
L_1E:
		MOV	AH,9			;显示打印机名
		INT	21H
		POP	DS

		MOV	AH,6			;取打印参数
		INT	17H

		MOV	D_P6+10,AL		;打印方向

		PUSH	SI
		PUSH	CX
		TEST	AH,80H			;判矢量?
		JNZ	L_20
		MOV	D_P11,DL		;字型字母
		MOV	AX,'  '
		MOV	WORD PTR D_P12,AX
		MOV	D_P12+2,AL
		MOV	WORD PTR D_P13,AX
		MOV	D_P13+2,AL
		JMP	SHORT L_28
L_20:
		MOV	AL,AH
		AND	AL,7FH
		CBW
		MOV	SI,OFFSET D_P11+1	;矢量字体号
		MOV	CX,2
		CALL	S_J

		MOV	AX,BP
		PUSH	AX
		MOV	AL,AH
		XOR	AH,AH
		MOV	SI,OFFSET D_P13+2	;高
		MOV	CX,3
		CALL	S_J
		POP	AX
		XOR	AH,AH
		MOV	SI,OFFSET D_P12+2	;宽
		MOV	CX,3
		CALL	S_J
L_28:
		POP	CX
		MOV	AL,CH			;字符间距
		XOR	AH,AH
		PUSH	CX
		MOV	SI,OFFSET D_P2+11
		MOV	CX,3
		CALL	S_J
		POP	CX
		MOV	AL,CL			;行距
		XOR	AH,AH
		MOV	SI,OFFSET D_P3+11
		MOV	CX,3
		CALL	S_J

		POP	SI
		MOV	AX,ES:[SI]		;左边空列
		PUSH	SI
		MOV	SI,OFFSET D_P4+12
		MOV	CX,4
		CALL	S_J
		POP	SI
		MOV	AX,ES:[SI+3]		;行宽
		MOV	SI,OFFSET D_P5+12
		MOV	CX,4
		CALL	S_J

		MOV	AL,ES:[200H]		;页长
		XOR	AH,AH
		CMP	DH,'H'                  ;HPRNT?
		JNZ	L_29
		MOV	AX,ES:[DI]
L_29:
		MOV	SI,OFFSET D_P7+13
		MOV	CX,5
		CALL	S_J

		MOV	SI,OFFSET D_P9
		MOV	AX,'  '
		TEST	BL,8			;轻打
		JNZ	L_40
		MOV	DS:[SI],AX
		MOV	DS:[SI+2],AX
L_40:
		AND	BL,7
		ADD	BL,'0'
		MOV	D_P8+9,BL		;背景

		TEST	BH,1			;反白
		JNZ	L_41
		MOV	DS:[SI+5],AX
		MOV	DS:[SI+7],AX
L_41:
		TEST	BH,2			;上划
		JNZ	L_42
		MOV	DS:[SI+10],AX
		MOV	DS:[SI+12],AX
L_42:
		TEST	BH,4			;下划
		JNZ	L_43
		MOV	DS:[SI+15],AX
		MOV	DS:[SI+17],AX
L_43:
		TEST	BH,8			;左旋
		JNZ	L_44
		MOV	DS:[SI+20],AX
		MOV	DS:[SI+22],AX
L_44:
		TEST	BH,10H			;右旋
		JNZ	L_45
		MOV	DS:[SI+25],AX
		MOV	DS:[SI+27],AX
L_45:
		TEST	BH,20H			;上标
		JNZ	L_46
		MOV	DS:[SI+30],AX
		MOV	DS:[SI+32],AX
L_46:
		TEST	BH,40H			;下标
		JNZ	L_50
		MOV	DS:[SI+35],AX
		MOV	DS:[SI+37],AX
L_50:
		MOV	DX,OFFSET D_P1
		MOV	AH,9			;显示打印参数
		INT	21H
		JMP	L_RET
L_100:
		CMP	BYTE PTR DS:[5DH],'2'   ;显示参数
		JZ	L_110
		JMP	L_200
L_110:
		MOV	AX,1406H		;取显示参数
		INT	10H
		MOV	D_256,DH
		MOV	D_XSCS,DL
		PUSH	SI
		PUSH	CX
		PUSH	AX
		XOR	AH,AH
		MOV	SI,OFFSET D_X1+10	;显示方式
		MOV	CX,2
		CALL	S_J
		POP	AX
		MOV	AL,AH
		XOR	AH,AH
		MOV	SI,OFFSET D_X3+11	;最大色号
		MOV	CX,3
		CALL	S_J
		POP	AX
		XOR	AH,AH
		MOV	SI,OFFSET D_X2+10	;显示行数
		MOV	CX,2
		CALL	S_J
		POP	AX
		INC	AX			;横向点数
		MOV	SI,OFFSET D_X4+12
		MOV	CX,4
		CALL	S_J
		MOV	AX,DI
		INC	AX			;纵向线数
		MOV	SI,OFFSET D_X5+12
		MOV	CX,4
		CALL	S_J
		PUSH	CS
		POP	ES
		XOR	AX,AX
		MOV	DI,OFFSET D_X6+9
		OR	BL,BL			;判直接写屏
		JZ	L_120
		MOV	DI,OFFSET D_X6+14
L_120:
		STOSW
		STOSW
		MOV	ES,AX
		MOV	DI,OFFSET D_X7+9
		CMP	BYTE PTR ES:[449H],3	;对外显示
		JA	L_130
		MOV	DI,OFFSET D_X7+14
L_130:
		PUSH	CS
		POP	ES
		STOSW
		STOSW
		MOV	DX,OFFSET D_X
		MOV	AH,9			;显示参数
		INT	21H

		MOV	DX,OFFSET D_X8
		MOV	AH,9
		INT	21H
		MOV	AX,357FH		;取读显示字库中断
		INT	21H
		MOV	AL,ES:[100H]		;读显示字库模块号
		AND	AL,0FH
		CBW
		SHL	AX,1
		MOV	BX,AX
		MOV	DX,D_XSZK[BX]
		MOV	AH,9
		INT	21H

		TEST	BYTE PTR D_XSCS,8
		JNZ	L_155
		MOV	AL,D_256
		OR	AL,AL
		JZ	L_140
		PUSH	AX
		MOV	CL,4
		SHR	AL,CL
		CBW
		MOV	BX,AX
		MOV	AL,D_16[BX]
		MOV	D_X9+16,AL
		POP	AX
		AND	AL,0FH
		CBW
		MOV	BX,AX
		MOV	AL,D_16[BX]
		MOV	D_X9+17,AL
		MOV	DX,OFFSET D_X9
		JMP	SHORT L_150
L_140:
		MOV	DX,OFFSET D_NOVESA
L_150:
		MOV	AH,9
		INT	21H
L_155:
		MOV	BL,D_XSCS
		TEST	BL,40H			;保持提示行?
		JZ	L_160
		MOV	DX,OFFSET D_BCTUX
		MOV	AH,9
		INT	21H
L_160:
		TEST	BL,20H			;使用扩展字符库
		JZ	L_170
		MOV	DX,OFFSET D_KZZF
		MOV	AH,9
		INT	21H
L_170:
		TEST	BL,10H			;显示方式>5即汉字?
		JNZ	L_180
		MOV	DX,OFFSET D_5HZ
		MOV	AH,9
		INT	21H
L_180:
		TEST	BL,8
		JNZ	L_190
		MOV	AX,'繁'
		TEST	BL,1
		JZ	L_181
		MOV	AX,'简'
L_181:
		XCHG	AH,AL
		MOV	WORD PTR D_16DZ+32,AX
		MOV	DX,OFFSET D_16DZ
		JMP	SHORT L_191
L_190:
		AND	BL,7
		XOR	BH,BH
		SHL	BX,1
		SHL	BX,1
		MOV	AX,WORD PTR D_24[BX]
		MOV	WORD PTR D_24DZ+32,AX
		MOV	AX,WORD PTR D_24[BX+2]
		MOV	WORD PTR D_24DZ+34,AX
		MOV	DX,OFFSET D_24DZ
L_191:
		MOV	AH,9
		INT	21H
L_199:
		JMP	L_RET
L_200:
		CMP	BYTE PTR DS:[5DH],'3'   ;键盘参数
		JNZ	L_199
		XOR	BP,BP
		MOV	AH,2FH			;取INT16->BP:SI
		INT	16H			;  词参数区->BP:DI
		OR	BP,BP			;判安装键盘模块?
		JZ	L_199
		MOV	ES,BP
		XOR	AX,AX
		CMP	BYTE PTR ES:[0F1H],'Y'  ;判拼音码表?
		JZ	L_220
		MOV	WORD PTR D_J1+9,AX
		MOV	WORD PTR D_J1+11,AX
L_220:
		CMP	BYTE PTR ES:[0F2H],'Y'  ;判首尾码表?
		JZ	L_225
		MOV	WORD PTR D_J1+14,AX
		MOV	WORD PTR D_J1+16,AX
L_225:
		CMP	WORD PTR ES:[226H],0	;判五笔模块?
		JNZ	L_228
		MOV	WORD PTR D_J1+19,AX
		MOV	WORD PTR D_J1+21,AX
L_228:
		CMP	BYTE PTR ES:[0EFH],'Y'  ;判电报模块?
		JZ	L_230
		MOV	WORD PTR D_J1+24,AX
		MOV	WORD PTR D_J1+26,AX
L_230:
		CMP	WORD PTR ES:[DI+18],0	;双拼词组段
		JNZ	L_240
		MOV	WORD PTR D_J2+9,AX
		MOV	WORD PTR D_J2+11,AX
		MOV	WORD PTR D_J2+13,AX
L_240:
		CMP	WORD PTR ES:[DI+6],0	;联想库段
		JNZ	L_250
		MOV	WORD PTR D_J2+16,AX
		MOV	WORD PTR D_J2+18,AX
		MOV	WORD PTR D_J2+20,AX
L_250:
		MOV	DX,OFFSET D_J
		MOV	AH,9
		INT	21H

		MOV	DX,OFFSET D_J4
		MOV	AH,9
		INT	21H
		MOV	AH,2FH			;取2.13安装路径->BP:DX	1.28
		INT	16H
		MOV	SI,DX			;			1.28
		PUSH	BP
		POP	DS
L_260:
		LODSB
		OR	AL,AL
		JZ	L_270
		MOV	DL,AL
		MOV	AH,2
		INT	21H
		JMP	SHORT L_260
L_270:
		PUSH	ES
		POP	DS
		PUSH	CS
		POP	ES
		MOV	BP,OFFSET D_UV		;提示串首
		MOV	SI,0D0H 		;功能键地址
		MOV	CX,19			;个数
L_280:
		LODSB				;取各功能键
		CALL	S_SET
		ADD	BP,29
		LOOP	L_280

		PUSH	CS
		POP	DS
		MOV	DX,OFFSET D_GNJ 	;功能键表
		MOV	AH,9
		INT	21H
L_RET:
		MOV	AX,4C00H
		INT	21H

S_SET		PROC	NEAR
		PUSH	DS
		PUSH	CS
		POP	DS
		PUSH	SI
		CMP	AL,0F0H
		JB	L_SET1
		MOV	AL,15
		JMP	SHORT L_SET2
L_SET1:
		CMP	AL,85H			;F11,F12
		JB	L_SET3
		SUB	AL,85H
L_SET2:
		MOV	SI,OFFSET D_GNJTS1
		JMP	SHORT L_SET4
L_SET3:
		SUB	AL,84			;SHIFTF1~ALTF10
		MOV	SI,OFFSET D_GNJTS
L_SET4:
		MOV	AH,15
		MUL	AH
		ADD	SI,AX
		ADD	SI,4
		MOV	DI,BP
		PUSH	CX
		MOV	CX,9
		REP	MOVSB
		POP	CX
		POP	SI
		POP	DS
		RET
S_SET		ENDP

S_J		PROC	NEAR
		PUSH	BX
		PUSH	DX
		MOV	BX,10
L_J1:
		XOR	DX,DX
		DIV	BX
		OR	DL,'0'
		MOV	[SI],DL
		DEC	SI
		LOOP	L_J1
		POP	DX
		POP	BX
		RET
S_J		ENDP

D_16		DB	'0123456789ABCDEF'
D_DISP		DB	'内存自由空间 '
D_DISP1 	DB	'000000 字节$'

D_P		DB	13,10,'****** 打印参数 ******',13,10
		DB	'打 印 机: $'
D_P1		DB	13,10,'字    型:'
D_P11		DB	'A   宽:'
D_P12		DB	'000 高:'
D_P13		DB	'000',13,10
D_P2		DB	'字符间距:000',13,10
D_P3		DB	'行    距:000',13,10
D_P4		DB	'左边空列:0000',13,10
D_P5		DB	'行    宽:0000',13,10
D_P6		DB	'打印方向: >',13,10
D_P7		DB	'页    长:00000',13,10
D_P8		DB	'背    景:0',13,10
D_P9		DB	'轻打 反白 上划 下划 左旋 右旋 上标 下标',13,10,'$'

D_X		DB	13,10,'****** 显示参数 ******',13,10
D_X1		DB	'显示方式:00',13,10
D_X2		DB	'显示行数:00',13,10
D_X3		DB	'最大色号:000',13,10
D_X4		DB	'横向点数:0000',13,10
D_X5		DB	'纵向线数:0000',13,10
D_X6		DB	'直接写屏:打开 关闭',13,10
D_X7		DB	'对外显示:字符 图形',13,10,'$'
D_X8		DB	'显示字库$'
D_X9		DB	'256色显示方式号:00(十六进制)',13,10,'$'
D_NOVESA	DB	'显示卡不支持VESA,不能使用256色汉字显示!',13,10,'$'
D_256		DB	0
D_XSZK		DW	OFFSET D_0
		DW	OFFSET D_1
		DW	OFFSET D_2
		DW	OFFSET D_3
		DW	OFFSET D_4
		DW	OFFSET D_5
		DW	OFFSET D_6
D_0		DB	'驻留硬盘',13,10,'$'
D_1		DB	'一级调内存,二级驻留硬盘',13,10,'$'
D_2		DB	'全部调入内存',13,10,'$'
D_3		DB	'驻留虚拟盘',13,10,'$'
D_4		DB	'驻留EMS',13,10,'$'
D_5		DB	'驻留XMS',13,10,'$'
D_6		DB	'驻留扩展内存最高端',13,10,'$'
D_XSCS		DB	0
D_BCTUX 	DB	'保持提示行',13,10,'$'
D_KZZF		DB	'使用扩展字符库',13,10,'$'
D_5HZ		DB	'显示方式号>5即汉字',13,10,'$'
D_16DZ		DB	'使用16点阵汉字显示,当前显示字体:简体',13,10,'$'
D_24DZ		DB	'使用24点阵汉字显示,当前显示字体:宋体',13,10,'$'
D_24		DB	'宋体仿宋黑体楷体繁体'

D_J		DB	13,10,'****** 键盘参数 ******',13,10
D_J1		DB	'安装码表:拼音 首尾 外一 电报',13,10
D_J2		DB	'安    装:双拼词 联想库',13,10,'$'
D_J4		DB	'系统安装:$'

D_GNJ		DB	13,10
D_UV		DB	'CTRL+DEL  1-系统功能键     ',13,10
		DB	'CTRL+F7   2-进入/退出纯西文',13,10
		DB	'ALT+F1    3-区位码输入     ',13,10
		DB	'ALT+F2    4-首尾码输入     ',13,10
		DB	'ALT+F3    5-拼音码输入     ',13,10
		DB	'ALT+F4    6-双拼码输入     ',13,10
		DB	'CTRL+F9   7-建立/取消纯中文',13,10
		DB	'ALT+F6    8-ASCII码输入    ',13,10
		DB	'ALT+F5    9-词组输入方式   ',13,10
		DB	'ALT+F7   10-外部输入方式一 ',13,10
		DB	'ALT+F8   11-外部输入方式二 ',13,10
		DB	'F12      12-预选字输入     ',13,10
		DB	'F11      13-联机帮助       ',13,10
		DB	'ALT+F9   14-内部词组管理   ',13,10
		DB	'ALT+F10  15-电报码输入     ',13,10
		DB	'CTRL+F5  16-系统控制       ',13,10
		DB	'CTRL+F1  17-取屏幕字符串   ',13,10
		DB	'CTRL+F3  18-执行宏功能     ',13,10
		DB	'CTRL+F10 19-设置打印参数   $'

D_GNJTS 	DB	' 84-SHIFT+F1    85-SHIFT+F2    86-SHIFT+F3   '
		DB	' 87-SHIFT+F4    88-SHIFT+F5   '
		DB	' 89-SHIFT+F6    90-SHIFT+F7    91-SHIFT+F8   '
		DB	' 92-SHIFT+F9    93-SHIFT+F10  '
		DB	' 94-CTRL+F1     95-CTRL+F2     96-CTRL+F3    '
		DB	' 97-CTRL+F4     98-CTRL+F5    '
		DB	' 99-CTRL+F6    100-CTRL+F7    101-CTRL+F8    '
		DB	'102-CTRL+F9    103-CTRL+F10   '
		DB	'104-ALT+F1     105-ALT+F2     106-ALT+F3     '
		DB	'107-ALT+F4     108-ALT+F5     '
		DB	'109-ALT+F6     110-ALT+F7     111-ALT+F8     '
		DB	'112-ALT+F9     113-ALT+F10    '
D_GNJTS1	DB	'133-F11        134-F12        135-SHIFT+F11  '
		DB	'136-SHIFT+F12  137-CTRL+F11   '
		DB	'138-CTRL+F12   139-ALT+F11    140-ALT+F12    '
		DB	'141-CTRL+↑    142-CTRL+-     '
		DB	'143-CTRL+5     144-CTRL++     145-CTRL+↓    '
		DB	'146-CTRL+INS   147-CTRL+DEL   '
		DB	'               149-CTRL+/     150-CTRL+*     '
		DB	'                              '

SEG_A		ENDS
		END	START

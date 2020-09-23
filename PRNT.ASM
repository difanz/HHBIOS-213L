;	PRNT.ASM(2.13L)
;	1997.3.4, 4.28, 6.7, 6.29, 7.4, 7.24
;	1998.1.1, 4.6, 4.26
;	1999.1.4, 1.6, 1.12, 2.1

SEG_A		SEGMENT
		ASSUME	CS:SEG_A, DS:SEG_A

		ORG	100H
START:		JMP	BEGIN

K_PORT		DW	0			;打印端口
D_INT17 	DD	0			;ROM BIOS INT17 地址

;打印机参数区----------------------------------------------------------------
		ORG	110H
D_DYJH		DB	0	  ;打印机序号.'0'-'9'
T_TX		DB	0	  ;位7=0:二进制数, =1:ASC数
				  ;  6=0:前高后低, =1:前低后高(位7=0时)
				  ;位5=1:先处理打印方向
				  ;位4=1:判打印方向
				  ;位0-3:数字位移
C_TX		DB	0	  ;命令字节数
		DB	8 DUP(0)  ;图象打印命令
T_ZZ		DB	0	  ;位7=0:二进制数,=1:ASC数
				  ;位0-3:数字位移
C_ZZ		DB	0	  ;命令字节数
		DB	7 DUP(0)  ;走纸命令
C_SX		DB	0	  ;命令字节数
		DB	3 DUP(?)  ;双向打印命令
C_DX		DB	0	  ;命令字节数
		DB	3 DUP(?)  ;单向打印命令
D_HJDW0 	DB	0	  ;行距单位=0:1/180,=1:1/120,=2:1/48,=3:1/360
D_LJHJ		DB	0	  ;行连接行距(1/180)
D_HZK		DW	0	  ;行总宽
D_DYJ		DB	15 DUP(0) ;打印机名
D_FF		DB	0	  ;暂存BH

D_0230		DB	 88H,  0,  0,  0,88H,0,  0,0	;背景1
		DB	0AAH,  0,80H,  0,80H,0,80H,0	;背景2
		DB	 80H,  0,80H,  0,80H,0,80H,0	;背景3
		DB	0AAH,  0,  0,  0,  0,0,  0,0	;背景4
		DB	 10H,20H,40H,80H,  1,2,  4,8	;背景5
		DB	 80H,40H,20H,10H,  8,4,  2,1	;背景6
		DB	 90H,60H,60H,90H,  9,6,  6,9	;背景7

;字型数据--------------------------------------------------------------------
D_ZX		DW	1840H,3041H,9844H,0B045H	;ABCD
		DW	1850H,3051H,9854H,0B055H	;EFGH
		DW	1860H,3061H,9864H,0B065H	;IJKL
		DW	1870H,3071H,9874H,0B075H	;MNOP
		DW	1020H,2021H,9024H,0A025H	;QRST
		DW	0A8C0H,0A8D0H,0A8E0H,0A8F0H,1,0 ;UVWXYZ
D_ZX1		DW	1010H,2411H,9812H,0A413H	;abcd
		DW	1014H,2415H,9816H,0A417H	;efgh
		DW	1018H,2419H,981AH,0A41BH	;ijkl
		DW	101CH,241DH,981EH,0A41FH	;mnop
		DW	1030H,2031H,9034H,0A035H	;qrst
		DW	0A080H,0A090H,0A0A0H,0A0B0H,1,0 ;uvwxyz
D_ZH		DB	90,72,48,40,32,24,20,16 	;0-7 号字
D_ZH1		DB	0, 80,60,44,36,28,22,18 	;小号字
D_ZX0		DB	'A'                     ;字型字母

D_022A		DB	0			;｀标志
D_022B		DB	0			;功能字节
D_022C		DW	0			;直接输出字节数
D_022E		DW	0			;计数暂存

D_0222		DW	0			;存当前汉字内码
D_0226		DB	0			;暂存当前字型和ESC+I+N1值
D_0204		DB	0			;软回车标志(8DH)
D_0C		DB	0			;=0:换页直送打印机,非0:自行处理
D_0C00		DB	0			;=0CH:本行有换页符

		ORG	200H
;打印参数--------------------------------------------------------------------
D_0200		DW	0			;页长
D_0201		DW	0			;页间空
D_0202		DW	0			;累计走纸
D_0203		DW	0			;打印页号
D_0207		DW	0			;AX
D_0209		DW	0			;已输出列
D_020B		DW	0			;行首D_020D,D_020E
D_020D		DB	0			;功能字节1
	;位0-2背景1~7,位3轻打
D_020E		DB	0			;功能字节2
	;位0-反白,位1-下划线,位2-上划线,位3-左旋,位4-右旋,位5-上标,位6-下标
D_020F		DB	0			;输入标志
	;位7-ESC,位6-ESC+I,位5-ECS+I+N1
D_0210		DB	0			;打印行数(输出时逐行减1)
D_0211		DB	40H			;行首D_0213
D_0211A 	DB	18H			;    D_0213A
D_0211B 	DB	18H			;    D_0213B
D_0211C 	DB	0			;    D_0213C
D_0212		DB	0			;    D_0214
D_0213		DB	40H			;字型
	;位0-1横扩倍数,位2-3纵扩倍数,位4-5字体(宋仿黑楷),位6-7点阵(16,24,32,40)
	;点阵=00时:字体=00为矢量(D_0213C为字体号),=10为16点阵,=11为扩24
	;	       =01为隔点扩:此时:位2-3为字体,位0横扩,位1纵扩
D_0213A 	DB	18H			;字型宽度
D_0213B 	DB	18H			;    高度
D_0213C 	DB	0			;字体号
D_0214		DB	0			;    行数
D_0215		DB	30			;行距
D_0216		DB	'<'                     ;打印方向
D_0217		DW	0			;字符间距
D_0219		DW	0			;行首D_0217
D_021D		DW	0			;左边空列
D_HJDW		DB	1			;行距单位=0:1/180,=1:1/120
						;	 =2:行间距1/180英寸
						;	 =3:行间距1/120英寸
D_021F		DB	0			;汉字前字节
D_0220		DW	990H			;行总宽

D_01FA		DW	0			;输入区首
D_01FC		DW	0			;输入区尾
D_0205		DW	0			;输入区指针

;排版------------------------------------------------------------------------
D_YH		DB	'        '              ;打印页号区
D_YH1		DB	'1 ─',0
D_P		DB	7 DUP(0)
D_ZJJ		DW	0			;字间距计数
D_ZJA		DW	0			;字间距增量
D_ZJB		DW	0			;从此再+1
D_JZ		DB	0			;=-1居中,=80H居右
D_PBHS		DB	0			;排版行首空格数

D_PBCS		DW	1650,0,0,1280		;LQ窄纸  排版参数表
		DW	2200,0,0,2280		;LQ宽纸
		DW	1800,100,100,1200	;A4 纸
		DW	1300,100,100,1000	;B5 纸
		DW	2*4 DUP(0)

;INT17-----------------------------------------------------------------------
D_AH		DW	OFFSET S_AH00		; AH=0 打印一字节AL
		DW	OFFSET S_1A2		; AH=1 打印机初始化
		DW	OFFSET S_1A2		; AH=2 取打印机状态AX
		DW	0			; AH=3 切换中西文打印
		DW	OFFSET S_AH04		; AH=4 特殊打印开关
		DW	OFFSET S_1A0		; AH=5 直接打印一字节AL

INT_17		PROC	FAR
		STI
		CLD
		CMP	AX,-1			;取安装状态和BIOS INT17
		JNZ	L_0
		MOV	AX,-2130H
		MOV	BX,WORD PTR CS:D_INT17
		MOV	DX,WORD PTR CS:D_INT17+2
		IRET
L_0:
		CMP	AH,3			;中西文打印切换
		JNZ	L_2
		XOR	AH,AH			;L_3处指令为JB 0:JMP CS:D_INT17
		OR	AL,AL
		JZ	L_1
		MOV	AH,5			;L_3处指令为JB L_2 (正常打印)
L_1:
		MOV	BYTE PTR CS:K_DY,AH
		IRET
L_2:
		CMP	AH,6			;取打印参数
		JNZ	L_3
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	AH,D_0213		;字型
		MOV	AL,D_0216		;打印方向
		MOV	BX,WORD PTR D_020D	;功能字节BL-1.BH-2
		MOV	CH,BYTE PTR D_0217	;字符间距
		MOV	CL,D_0215		;行距
		MOV	DH,'N'                  ;PRNT标志
		MOV	DL,D_ZX0		;字型字母
		MOV	SI,D_021D		;左边空列
		MOV	DI,OFFSET D_PBCS	;排版参数表
		MOV	BP,WORD PTR D_0213A	;字型宽(低八位)和高(高八位)
		PUSH	CS
		POP	ES
		POP	DS
		IRET
L_3:
		JB	L_4
K_DY	EQU	$-1
		JMP	CS:D_INT17
L_4:
		PUSH	DS
		PUSH	ES
		PUSH	BP
		PUSH	DI
		PUSH	SI
		PUSH	DX
		PUSH	CX
		PUSH	BX
		PUSH	CS
		POP	DS
		PUSH	CS
		POP	ES
		MOV	K_PORT,DX		;打印口
		MOV	D_0207,AX		;保存AX
		PUSH	AX
		MOV	AL,AH
		CBW
		SHL	AX,1
		MOV	DI,AX
		POP	AX
		CALL	D_AH[DI]		;转执行各功能
		MOV	AX,CS:D_0207		;返回AX
		POP	BX
		POP	CX
		POP	DX
		POP	SI
		POP	DI
		POP	BP
		POP	ES
		POP	DS
		IRET
INT_17		ENDP

;子程序:AH=4:特殊打印开关 AL=0关,=1开
S_AH04		PROC	NEAR
		OR	AL,AL			;特殊打印开关
		JZ	L_0401
		MOV	AL,3
L_0401:
		MOV	BYTE PTR D_60K1,AL	;切换｀功能处理
		MOV	BYTE PTR D_60K2,AL
		RET
S_AH04		ENDP

;子程序:AH=0 打印 -----------------------------------------------------------
S_AH00		PROC	NEAR
		CMP	D_022C,0		;取直接输出字节数
		JZ	L_10
		DEC	D_022C			;-1
		JMP	S_1A0			;输出字节
L_10:
		CMP	D_021F,0		;有汉字前字节?
		JZ	L_20
		CALL	S_480
		MOV	D_021F,0		;清
		JMP	S_470
L_20:
		TEST	D_020F,20H		;ESC+I+N1标志
		JZ	L_30
		MOV	AH,D_0226
		MOV	CX,AX			;列数→CX
		SHL	AX,1
		ADD	AX,CX			;AX*3
		MOV	D_022C,AX
		CALL	S_TX			;置图形打印
		JMP	SHORT L_34
L_30:
		TEST	D_020F,40H		;ESC+I标志
		JZ	L_90
		CMP	AL,'<'                  ;双向?
		JZ	L_32
		CMP	AL,'>'                  ;单向?
		JNZ	L_40
L_32:
		MOV	D_0216,AL		;置打印方向
		CALL	S_FX
L_34:
		DEC	D_0205			;输入区指针-1
L_36:
		DEC	D_0205			;输入区指针-1
L_38:
		AND	D_020F,3		;清标志
		RET
L_40:
		CMP	AL,'\'                  ;取消软回车8D0A
		JNZ	L_50
		MOV	AL,0C3H
L_42:
		MOV	BYTE PTR K_RHC,AL
		MOV	BYTE PTR K_RHC1,AL
		JMP	SHORT L_34
L_50:
		CMP	AL,'/'                  ;恢复软回车8D0A为0D0A
		JNZ	L_60
		MOV	AL,90H
		JMP	SHORT L_42
L_60:
		CMP	AL,60H			;恢复`
		JA	L_80
		JNZ	L_70
		MOV	AL,3
L_62:
		MOV	BYTE PTR D_60K1,AL	;切换｀功能处理
		MOV	BYTE PTR D_60K2,AL
		JMP	SHORT L_34
L_70:
		CMP	AL,27H			;取消`
		JNZ	L_82
		XOR	AL,AL
		JMP	SHORT L_62
L_80:
		CMP	AL,'z'
		JA	L_34
		JMP	SHORT L_84
L_82:
		CMP	AL,'A'
		JB	L_86
		CMP	AL,'Z'
		JA	L_34
L_84:
		CALL	S_470			;写入输入区
		CALL	S_ZX			;置字型
		CMP	CH,D_0210		;与已指定行数比
		JBE	L_38
		MOV	D_0210,CH
		JMP	SHORT L_38
L_86:
		OR	D_020F,20H		;置ESC+I+N1标志
		MOV	D_0226,AL		;暂存
		RET
L_90:
		TEST	D_020F,80H		;ESC标志
		JZ	L_100
		AND	AL,5FH
		CMP	AL,'I'
		JNZ	L_92
		OR	D_020F,40H		;置ESC+I标志
		JMP	S_470			;写入输入区
L_92:
		CMP	AL,'W'
		JNZ	L_94
		INT	5			;执行屏幕拷贝
L_94:
		JMP	L_36

;特殊打印功能处理------------------------------------------------------------
L_100:
		MOV	SI,OFFSET D_022B	;功能符
		CMP	D_022A,'`'              ;当前标识符?
		JZ	L_110
		CMP	AL,'`'                  ;标识符?
		JZ	L_102
D_60K1		EQU	$-1
		JMP	L_400
L_102:
		MOV	D_022A,AL		;置｀标志
		JMP	S_470			;写入输入区
L_110:
		CMP	BYTE PTR [SI],'2'       ;<@第二参数>
		JNZ	L_120
		CALL	S_Q
		JB	L_116
		OR	CL,CL
		JZ	L_114
		MOV	CH,CL
L_112:
		CALL	S_HIGH1 		;处理字高和行数
L_114:
		CMP	AL,','
		JNZ	L_122
		MOV	BYTE PTR [SI],'3'
L_116:
		JMP	S_470
L_120:
		CMP	BYTE PTR [SI],'3'       ;<@第三参数>
		JNZ	L_130
		CALL	S_Q
		JB	L_116
		MOV	D_0213C,CL		;字体号
L_122:
		JMP	L_166
L_130:
		CMP	BYTE PTR [SI],0E0H	;<@设置字号>
		JNZ	L_140
		CALL	S_Q
		JB	L_116
		CALL	S_ZH			;处理字号
		MOV	D_0213A,CL		;列数
		MOV	D_0213,0
		JMP	SHORT L_112		;处理高和字体号
L_140:
		CMP	BYTE PTR [SI],'@'       ;<字型>
		JNZ	L_160
		CMP	AL,'@'                  ;字号
		JNZ	L_142
		MOV	BYTE PTR [SI],0E0H	;字号标志
		JMP	SHORT L_152		;存
L_142:
		CMP	AL,'>'                  ;单向
		JZ	L_143
		CMP	AL,'<'                  ;双向
		JNZ	L_144
L_143:
		MOV	BYTE PTR K_DHFX,AL	;纵扩字方向
		JMP	SHORT L_147
L_144:
		CMP	AL,'-'                  ;多行字型空行走纸一行?
		JNZ	L_145
		MOV	AL,OFFSET L_427-OFFSET L_425-2
		JMP	SHORT L_146
L_145:
		CMP	AL,'='                  ;多行字型空行走纸多行?
		JNZ	L_150
		XOR	AL,AL
L_146:
		MOV	BYTE PTR D_0A00,AL
L_147:
		DEC	D_0205			;去@
		JMP	SHORT L_155
L_150:
		CMP	AL,'9'
		JA	L_154
		CALL	S_Q
		JB	L_152
		OR	CL,CL
		JZ	L_151
		MOV	D_0213A,CL		;列数
		MOV	D_0213,0
L_151:
		CMP	AL,','
		JNZ	L_166
		MOV	BYTE PTR [SI],'2'
L_152:
		JMP	S_470
L_154:
		CALL	S_470			;写入输入区
		CALL	S_ZX			;置字型
		CMP	CH,D_0210		;与已指定行数比
		JBE	L_155
		MOV	D_0210,CH
L_155:
		MOV	BYTE PTR [SI],0 	;清功能字节
		RET
L_160:
		CMP	BYTE PTR [SI],'#'       ;<页长>
		JNZ	L_170
		CMP	AL,'#'                  ;强制换页
		JNZ	L_164
		DEC	D_0205
L_161:
		MOV	AL,0CH
		CALL	S_442			;执行换页		7.23
		MOV	BYTE PTR [SI],0 	;清功能字节
		RET
L_164:
		CALL	S_Q			;取参数
		JNB	L_165
		RET
L_165:
		MOV	D_0200,CX		;置页长
		MOV	D_0202,0		;清累计走纸
L_166:
		MOV	BYTE PTR [SI],0 	;清功能字节
		JMP	L_300
L_170:
		CMP	BYTE PTR [SI],'*'       ;<页间空>
		JNZ	L_180
		CALL	S_Q			;取参数
		JNB	L_171
		RET
L_171:
		MOV	D_0201,CX		;置页间空行
		JMP	SHORT L_166
L_180:
		CMP	BYTE PTR [SI],0A6H	;<负行间距>		1.4
		JNZ	L_182
		CALL	S_Q			;取参数
		JNB	L_181
		RET
L_181:
		MOV	CH,24
		CMP	D_HJDW,2		;判行间距180英寸?	1.10
		JZ	L_181A
		MOV	CH,16
L_181A:
		CMP	CL,CH			;超?
		JBE	L_181B
		MOV	CL,CH
L_181B:
		NEG	CL
		JMP	SHORT L_187
L_182:
		CMP	BYTE PTR [SI],'&'       ;<行距>
		JNZ	L_190
		CMP	AL,'A'                  ;设置行距单位1/180
		JB	L_185
		CMP	AL,'D'                  ;设置行距单位1/120      1.12
		JA	L_185
		SUB	AL,'A'
		MOV	D_HJDW,AL		;设置行距单位
		MOV	AH,75H			;JNZ			1.4
		CMP	AL,2			;判行间距		1.4
		JZ	L_183
		MOV	AH,0EBH 		;JMP SHORT
L_183:
		MOV	BYTE PTR K_HJJ,AH
		JMP	L_155
L_185:
		CMP	AL,'-'                  ;负数?                  1.4
		JMP	SHORT L_186		;	行间距时为JNZ (75H)
K_HJJ	EQU	$-2
		MOV	BYTE PTR [SI],0A6H	;='&'+80H
		RET
L_186:
		CALL	S_Q			;取参数
		JNB	L_187
		RET
L_187:
		CMP	D_HJDW,2		;判行间距180英寸?	1.10
		JNZ	L_188
		ADD	CL,24
		JMP	SHORT L_189
L_188:
		CMP	D_HJDW,3		;判行间距1/120英寸?	1.10
		JNZ	L_189
		ADD	CL,16
L_189:
		MOV	D_0215,CL		;置行距
		JMP	L_166
L_190:
		CMP	BYTE PTR [SI],0DBH	;排版行首空格
		JNZ	L_200
		CALL	S_Q
		JNB	L_191
		RET
L_191:
		MOV	D_PBHS,CL
		JMP	L_166
L_200:
		CMP	BYTE PTR [SI],'['       ;<左边空列>
		JNZ	L_210
		CMP	AL,'['                  ;设置排版段第二行起缩进
		JNZ	L_204
		MOV	BYTE PTR [SI],0DBH	;'['=5BH+80H
		RET
L_204:
		CALL	S_Q			;取参数
		JNB	L_205
		RET
L_205:
		MOV	D_021D,CX		;置左边空列
		JMP	L_166
L_210:
		CMP	BYTE PTR [SI],']'       ;<行宽>
		JNZ	L_220
		CALL	S_Q			;取参数
		JNB	L_212
		RET
L_212:
		CMP	CX,D_HZK		;行总宽
		JBE	L_214
		MOV	CX,D_HZK
L_214:
		MOV	D_0220,CX
		JMP	L_166
L_220:
		CMP	BYTE PTR [SI],28H	;处理页号
		JNZ	L_230
		CALL	S_Q
		JNB	L_222
		RET
L_222:
		MOV	D_0203,CX
L_224:
		JMP	L_166
L_230:
		CMP	BYTE PTR [SI],27H	;排版参数
		JNZ	L_240
		CALL	S_Q
		JNB	L_232
		RET
L_232:
		MOV	D_0203,1		;页号
		MOV	BYTE PTR K_RHC,0C3H	;取消软回车
		MOV	BYTE PTR K_RHC1,0C3H
		MOV	BYTE PTR D_0A00,0	;多行字型空行打多行
		MOV	BYTE PTR S_PB,90H	;打开行禁则处理
		OR	CX,CX
		JZ	L_224
		PUSH	SI
		PUSH	AX
		DEC	CL
		MOV	AL,8
		MUL	CL
		ADD	AX,OFFSET D_PBCS
		MOV	SI,AX
		LODSW
		MOV	D_0200,AX		;页长
		LODSW
		MOV	D_0201,AX		;页首
		LODSW
		MOV	D_021D,AX		;左空
		LODSW
		MOV	D_0220,AX		;行宽
		CALL	S_YS			;处理页首空行
		POP	AX
		POP	SI
		CMP	AL,','
		JZ	L_234
		JMP	L_166
L_234:
		MOV	BYTE PTR [SI],28H	;继续处理初始页号
		RET
L_240:
		CMP	BYTE PTR [SI],'"'       ;<打印颜色>
		JNZ	L_250
		CMP	AL,'0'
		JB	L_242
		CMP	AL,'7'
		JA	L_242
		CALL	S_COLOR
L_242:
		JMP	L_155
L_250:
		CMP	BYTE PTR [SI],'$'       ;<直送打印机>
		JNZ	L_260
		CMP	AL,'$'
		JZ	L_252
		JMP	S_1A0
L_252:
		MOV	BYTE PTR [SI],0
		RET
L_260:
		CMP	BYTE PTR [SI],'^'       ;<字符间距>
		JNZ	L_270
		CALL	S_Q			;取参数
		JNB	L_262
		JMP	S_470			;写入输入区
L_262:
		MOV	BYTE PTR D_0217,CL	;置字符间距
		JMP	L_166
L_270:
		CMP	BYTE PTR [SI],'~'       ;<空列>
		JNZ	L_280
		CALL	S_Q			;取参数
		JB	L_272
		ADD	D_0209,CX		;已输出列累计
		JMP	L_166
L_272:
		JMP	S_470			;写入输入区
L_280:
		CMP	BYTE PTR [SI],'|'       ;<水平定位>
		JNZ	L_290
		CALL	S_Q			;取参数
		JNB	L_282
		RET
L_282:
		CMP	CX,D_0209		;<=已输出列?
		JBE	L_286
		PUSH	AX
		MOV	AL,'~'                  ;空列命令符
		CALL	S_470			;写入输入区
		MOV	AX,CX
		SUB	AX,D_0209		;得应输出空列
		MOV	D_0209,CX		;置已输出列
		MOV	CX,40AH
		MOV	BX,D_0205
		MOV	DI,3
L_284:
		DIV	CL
		OR	AH,'0'
		MOV	[BX+DI],AH		;写入输出空列命令
		MOV	AH,0
		DEC	DI
		DEC	CH
		JNZ	L_284
		POP	AX
		ADD	BX,4
		MOV	D_0205,BX		;存输入区指针
L_286:
		JMP	L_166
L_290:
		CMP	BYTE PTR [SI],'%'       ;<背景>
		JNZ	L_300
		CALL	S_470			;写入输入区
		JMP	L_155
L_300:
		CMP	AL,60H			;<特殊打印功能标识符>
		JNZ	L_310
		MOV	D_022A,0		;清｀标志
		JMP	S_470			;写入输入区
L_310:
		CMP	D_HJDW,2		;判行间距?		1.10
		JB	L_311
		CMP	AL,'E'                  ;换页?
		JNZ	L_311
		JMP	L_161			;强制换页
L_311:
		CMP	AL,'#'                  ;<页长>
		JNZ	L_314
L_312:
		MOV	[SI],AL
		RET
L_314:
		CMP	AL,'*'                  ;<页间空行>
		JZ	L_312
		CMP	AL,'$'                  ;<直送打印机>
		JZ	L_312
		CMP	AL,'"'                  ;<颜色>
		JZ	L_312
		CMP	AL,'&'                  ;<行距>
		JZ	L_312
		CMP	AL,'['                  ;<左边空>
		JZ	L_312
		CMP	AL,']'                  ;<行宽>
		JZ	L_312
		CMP	AL,'|'                  ;<水平定位>
		JZ	L_312
		CMP	AL,27H
		JZ	L_312

		CMP	AL,'%'                  ;<背景>
		JZ	L_316
		CMP	AL,'@'                  ;<字型>
		JZ	L_316
		CMP	AL,'^'                  ;<字符间距>
		JZ	L_316
		CMP	AL,'~'                  ;<空列>
		JNZ	L_320
L_316:
		MOV	[SI],AL
		JMP	S_470			;写入输入区
L_320:
		CMP	AL,'<'                  ;<双向>
		JZ	L_322
		CMP	AL,'>'                  ;<单向>
		JNZ	L_330
L_322:
		MOV	D_0216,AL		;置打印方向
		JMP	S_FX
L_330:
		CMP	AL,'.'                  ;<暂停>
		JNZ	L_340
		MOV	AX,0E07H
		INT	10H			;响铃
L_332:
		XOR	AH,AH
		INT	16H			;按键
		CMP	AL,0DH			;判回车?
		JNZ	L_332
		RET
L_340:
		CMP	AL,':'                  ;<打印参数初始化>
		JNZ	L_350
		CMP	BYTE PTR S_PB,90H	;判原排版?
		JNZ	L_342
		MOV	AX,D_0200		;页长
		SUB	AX,D_0202		;-已走纸
		CALL	S_9C0			;走纸
		CALL	S_DYYH			;打印页号
L_342:
		XOR	AX,AX
		MOV	D_PBHS,AL		;清排版行首空
		MOV	DI,OFFSET D_0200
		MOV	CX,OFFSET D_021F-OFFSET D_0200
		REP	STOSB			;清D_0200~D_021F
		MOV	DL,90H
		MOV	BYTE PTR K_RHC,DL	;恢复软回车为0D0A
		MOV	BYTE PTR K_RHC1,DL
		MOV	BYTE PTR S_PB,0C3H	;关闭行禁则处理
		MOV	AL,'A'
		CALL	S_ZX
		MOV	D_0215,14H		;行距
		MOV	D_0216,'<'              ;方向
		JMP	S_540
L_350:
		CMP	AL,','                  ;<居中>
		JNZ	L_360
		CMP	D_JZ,-1 		;判居中?
		JZ	L_352
		MOV	D_JZ,-1 		;设标志
		RET
L_352:
		MOV	D_JZ,80H		;设居右
		RET
L_360:
		CMP	AL,';'                  ;<轻打>
		JNZ	L_364
L_362:
		JMP	S_470
L_364:
		CMP	AL,'\'                  ;<反白>
		JZ	L_362
		CMP	AL,'/'                  ;<上划线>
		JZ	L_362
		CMP	AL,'_'                  ;<下划线>
		JZ	L_362
		CMP	AL,'='                  ;<恢复>
		JZ	L_362
		CMP	AL,'('                  ;<左旋>
		JZ	L_362
		CMP	AL,')'                  ;<右旋>
		JZ	L_362
		CMP	AL,'?'                  ;<清旋转>
		JZ	L_362
		CMP	AL,'+'                  ;<上标>
		JNZ	L_370
		MOV	D_020E,20H
		JMP	S_470
L_370:
		CMP	AL,'-'                  ;<下标>
		JNZ	L_380
		MOV	D_020E,40H
		JMP	S_470
L_380:
		CMP	AL,'!'                  ;<正常>
		JNZ	L_410
		MOV	D_020E,0
		JMP	S_470
;打印字符处理----------------------------------------------------------------
L_400:
		CMP	AL,1BH			;<ESC>
		JNZ	L_410
		OR	D_020F,80H		;置ESC标志
		JMP	S_470			;写入输入区
L_410:
		CMP	AL,0A0H 		;判汉字?
		JBE	L_420
		MOV	D_021F,AL		;暂存前字节
		JMP	S_470
L_420:
		CMP	AL,8AH			;WS换页?
		JNZ	L_421
		MOV	AL,0AH
L_421:
		CMP	AL,0AH			;换行?
		JNZ	L_430
		CMP	D_0204,8DH
		JNZ	L_422
		MOV	D_0204,AL
K_RHC1	EQU	$
		NOP
L_422:
		MOV	BYTE PTR D_0207,AL	;写回AX
		MOV	DX,D_01FA
		CMP	DX,D_0205		;输入区无数据?
		JZ	L_423
		JMP	S_500			;打印
L_423:
		CMP	AL,0DH
		JNZ	L_424
		MOV	D_0204,0
		JMP	S_1A0
L_424:
		CMP	D_0204,0DH		;回车时有打印内容?
		JZ	L_427
		JMP	SHORT L_427
D_0A00	EQU	$-1
L_425:
		MOV	AL,D_0212		;行首行数
		MOV	D_0210,AL
		JMP	SHORT L_427
L_426:
		DEC	D_0210
L_427:
		CALL	S_9A0			;走纸
		CMP	D_0210,0
		JNZ	L_426
L_428:
		JMP	S_9B0			;处理换页
L_430:
		CMP	AL,0DH			;回车?
		JZ	L_422
		CMP	AL,8DH			;WS软回车?
		JNZ	L_440
		MOV	D_0204,AL
K_RHC	EQU	$
		NOP
		MOV	AL,0DH
		JMP	SHORT L_422
L_440:
		AND	AL,7FH			;去高位
		CMP	AL,0CH			;换页?
		JNZ	L_450
S_442:
		MOV	D_0202,0		;清累计走纸		1.31
		MOV	D_0C00,AL
		CMP	D_0C,0			;直送打印机?		7.23
		JNZ	L_444
		JMP	S_1A0
L_444:
		MOV	AX,D_0200		;页长
		CMP	AX,D_0202		;与累计走纸比
		JBE	L_446
		SUB	AX,D_0202		;余行
		CALL	S_9C0			;走纸
L_446:
		RET
L_450:
		CMP	AL,9			;跳格?
		JNZ	L_460
L_452:
		MOV	AL,' '
		CALL	S_480			;计算列数
		CALL	S_470			;写入输入区
		MOV	AX,D_0205
		SUB	AX,D_01FA
		TEST	AX,7			;判8字符位置
		JZ	L_454
		JMP	SHORT L_452
L_454:
		RET
L_460:
		CALL	S_480
;子程序:写入输入区
S_470:
		MOV	DI,D_0205		;输入区指针
		CMP	DI,D_01FC		;判输入区尾
		JNB	L_472
		STOSB				;写入
		MOV	D_0205,DI		;存指针
L_472:
		RET

;子程序:计算列数
S_480:
		INC	D_ZJJ			;字间距计数+1
		PUSH	AX
		MOV	CX,D_0217		;字符间距
		MOV	AL,D_0213		;字型
		OR	AL,AL			;=0矢量汉字?
		JZ	L_481
		AND	AL,0F0H
		CMP	AL,10H			;隔点扩?
		JZ	L_481
		MOV	AL,D_0213
		AND	AL,3
		INC	AX
		MUL	CL
		MOV	CX,AX
L_481:
		POP	AX
		MOV	BL,D_0213A		;字型列数
		XOR	BH,BH
		CMP	D_0213,0		;判矢量汉字?
		JNZ	L_482
		TEST	D_020E,60H		;判上下标?
		JZ	L_482
		SHR	BX,1
L_482:
		CMP	AL,0A0H
		JA	L_483
		SHR	BX,1			;字符:列数减半
		JMP	SHORT L_484
L_483:
		ADD	BX,CX			;加字符间距
L_484:
		ADD	BX,CX			;加字符间距
		MOV	CX,D_0209		;已输出列
		ADD	CX,BX			;累计
		CMP	CX,D_0220		;比行宽
		JA	L_486
		MOV	D_0209,CX		;置已输出列
		RET
L_486:
		CMP	D_021F,0
		JZ	L_490
		DEC	D_0205			;去汉字前字节
L_490:
		PUSH	BX
		PUSH	AX
		CALL	S_PB			;处理行禁则

		CALL	S_500			;打印

		MOV	AL,D_PBHS		;排版行首空格数
		OR	AL,AL
		JZ	L_493
L_492:
		PUSH	AX
		MOV	AL,' '
		CALL	S_480
		CALL	S_470
		POP	AX
		DEC	AL
		JNZ	L_492
L_493:
		MOV	SI,OFFSET D_P		;保存前字节
L_494:
		LODSB
		OR	AL,AL
		JZ	L_496
		CMP	AL,0A0H
		JBE	L_495
		CALL	S_470
		LODSB
L_495:
		CALL	S_480
		CALL	S_470
		JMP	SHORT L_494
L_496:
		MOV	D_P,0
		MOV	AL,D_021F		;重存汉字前字节
		OR	AL,AL
		JZ	L_498
		CALL	S_470
L_498:
		POP	AX
		POP	BX
		ADD	D_0209,BX
		INC	D_ZJJ
		RET
;子程序:打印
S_500:
		MOV	AL,D_0212		;上行尾行数
		CMP	AL,D_0210
		JBE	L_520
		MOV	D_0210,AL
		JMP	SHORT L_520
L_510:
		DEC	D_0210
L_520:
		CALL	S_550
		CALL	S_600			;打印一行
		CALL	S_9A0			;走纸
		CMP	D_0210,0
		JNZ	L_510
		CALL	S_9B0			;处理换页
S_530:
		MOV	AX,D_01FA		;输入区首
		MOV	D_0205,AX		;清输入区指针
S_540:
		XOR	AX,AX
		MOV	D_0209,AX		;清已输出列数
		MOV	WORD PTR D_022A,AX	;清｀标志
		MOV	D_JZ,AL 		;清居中
		MOV	D_ZJJ,AX
		MOV	D_ZJA,AX
		MOV	D_ZJB,AX
		MOV	AX,WORD PTR D_020D	;以下为置行首状态
		MOV	D_020B,AX
		MOV	AX,WORD PTR D_0213
		MOV	WORD PTR D_0211,AX
		MOV	AX,WORD PTR D_0213B
		MOV	WORD PTR D_0211B,AX
		MOV	AL,D_0214
		MOV	D_0212,AL
		MOV	AX,D_0217
		MOV	D_0219,AX
		RET

;子程序:置行首状态
S_550:
		MOV	WORD PTR D_022A,0	;清｀标志字节
		MOV	AX,D_020B
		MOV	WORD PTR D_020D,AX
		MOV	AX,WORD PTR D_0211
		MOV	WORD PTR D_0213,AX
		MOV	AX,WORD PTR D_0211B
		MOV	WORD PTR D_0213B,AX
		MOV	AL,D_0212
		MOV	D_0214,AL
		MOV	AX,D_0219
		MOV	D_0217,AX
		RET

;子程序:打印一行
S_600:
		CALL	S_990			;置图形打印
		MOV	SI,D_01FA		;输入区首
		XOR	BP,BP
		MOV	D_ZJJ,BP
L_610:
		MOV	AH,D_0213		;字型
		LODSB
		CMP	AL,0A0H 		;判汉字
		JA	L_620
		CALL	S_700			;处理字符
		JMP	SHORT L_630
L_620:
		MOV	DH,AL			;汉字前字节
		LODSB
		MOV	DL,AL			;汉字后字节
		CALL	S_800			;处理汉字
L_630:
		CMP	SI,D_0205		;处理完?(比输入区尾)
		JB	L_610
		RET

;子程序:字符处理
S_700:
		CMP	D_022A,60H		;判｀标志
		JZ	L_704
		CMP	AL,60H
		JZ	L_702
D_60K2		EQU	$-1
		JMP	L_790
L_702:
		MOV	D_022A,AL		;置/清｀标志
		RET
L_704:
		CMP	AL,60H
		JNZ	L_710
		XOR	AL,AL
		JMP	SHORT L_702
L_710:
		CMP	AL,'^'                  ;字符间距
		JNZ	L_720
L_712:
		LODSB
		CALL	S_Q			;取参数
		JB	L_712
		MOV	D_0217,CX		;置字符间距
L_714:
		DEC	SI
		RET
L_720:
		CMP	AL,'~'                  ;空列
		JNZ	L_730
L_722:
		LODSB
		CALL	S_Q			;取参数
		JB	L_722
		CALL	S_870			;输出空列
		JMP	SHORT L_714
L_730:
		CMP	AL,'@'                  ;字型
		JNZ	L_750
		LODSB
		CMP	AL,'@'                  ;设置字号
		JNZ	L_734
L_732:
		LODSB
		CALL	S_Q			;取字号
		JB	L_732
		CALL	S_ZH			;处理字号
		MOV	D_0213A,CL		;宽度
		MOV	D_0213,0
		JMP	SHORT L_744
L_734:
		CMP	AL,'9'
		JBE	L_740
		JMP	S_ZX			;设置字型
L_736:
		LODSB
L_740:
		CALL	S_Q
		JB	L_736
		OR	CL,CL
		JZ	L_742
		MOV	D_0213A,CL		;宽度
		MOV	D_0213,0
L_742:
		CMP	AL,','
		JNZ	L_748
L_743:
		LODSB
		CALL	S_Q
		JB	L_743
		OR	CL,CL
		JZ	L_745
		MOV	CH,CL
L_744:
		CALL	S_HIGH			;处理字高
L_745:
		CMP	AL,','
		JNZ	L_748
L_746:
		LODSB
		CALL	S_Q
		JB	L_746
		MOV	D_0213C,CL		;字体号
L_748:
		DEC	SI
		RET
L_750:
		CMP	AL,'%'                  ;背景
		JNZ	L_760
		LODSB
		AND	AL,0FH
		CMP	AL,7
		JA	L_752
		AND	D_020D,0F8H
		OR	D_020D,AL		;置背景
L_752:
		RET
L_760:
		MOV	BX,OFFSET D_020E	;标志字节
		CMP	AL,';'                  ;轻打
		JNZ	L_762
		OR	D_020D,8
		RET
L_762:
		CMP	AL,'\'                  ;反白
		JNZ	L_764
		OR	BYTE PTR [BX],1
		RET
L_764:
		CMP	AL,'/'                  ;上划线
		JNZ	L_766
		OR	BYTE PTR [BX],2
		RET
L_766:
		CMP	AL,'_'                  ;下划线
		JNZ	L_768
		OR	BYTE PTR [BX],4
		RET
L_768:
		CMP	AL,'='                  ;恢复
		JNZ	L_770
		AND	BYTE PTR [BX],0F8H	;清上下划线和反白
		AND	D_020D,7		;轻打
		RET
L_770:
		CMP	AL,'('                  ;左旋
		JNZ	L_776
		TEST	BYTE PTR [BX],8 	;已经左旋?
		JZ	L_774
L_772:
		OR	BYTE PTR [BX],80H	;倒转
		AND	BYTE PTR [BX],0E7H
		RET
L_774:
		AND	BYTE PTR [BX],67H
		OR	BYTE PTR [BX],8
		RET
L_776:
		CMP	AL,')'                  ;右旋
		JNZ	L_778
		TEST	BYTE PTR [BX],10H	;已经右旋?
		JNZ	L_772
		AND	BYTE PTR [BX],67H
		OR	BYTE PTR [BX],10H
		RET
L_778:
		CMP	AL,'?'                  ;不旋
		JNZ	L_780
		AND	BYTE PTR [BX],67H	;去80H,10H,8位
		RET
L_780:
		CMP	AL,'+'                  ;上标
		JNZ	L_782
		AND	BYTE PTR [BX],1FH
		OR	BYTE PTR [BX],20H
		RET
L_782:
		CMP	AL,'-'                  ;下标
		JNZ	L_784
		AND	BYTE PTR [BX],1FH
		OR	BYTE PTR [BX],40H
		RET
L_784:
		CMP	AL,'!'                  ;正常
		JNZ	L_790
		AND	BYTE PTR [BX],1FH
		RET
L_790:
		CMP	AL,1BH			;ESC
		JNZ	L_792
		LODSB
		LODSB
		JMP	S_ZX			;置字型
L_792:
		XOR	DH,DH
		MOV	DL,AL

;子程序:处理汉字 DX
S_800:
		PUSH	SI
		MOV	BL,D_020E		;取状态
		MOV	BH,D_0210		;取打印行数
		MOV	D_0222,DX		;暂存
		MOV	D_0226,AH		;暂存字型
		MOV	AL,AH
		OR	AL,AL			;=0矢量汉字?
		JNZ	L_820
		MOV	AL,D_0213C
		CBW
		MOV	BX,AX			;字体号
		MOV	AL,D_0214
		SUB	AL,D_0210
		MOV	AH,24
		MUL	AH
		MOV	SI,AX			;起始行
		ADD	AX,24
		MOV	DI,AX			;终止行
		CALL	S_SX			;属性转换
		MOV	AL,D_0213A		;横向点数
		XOR	AH,AH
		OR	DH,DH			;判汉字
		JNZ	L_810
		XOR	BX,BX
L_810:
		MOV	CL,D_0213B		;纵向点数
		XOR	CH,CH
		CALL	S_INT7E 		;读矢量字库
		MOV	DS,DX
		MOV	SI,BX
		MOV	CX,AX
		JMP	SHORT L_840
L_820:
		TEST	AL,80H			;判高点阵?
		JZ	L_830
		OR	DH,DH			;判字符?
		JNZ	L_822
		MOV	DH,0AAH 		;十区
		OR	DL,80H
L_822:
		AND	AL,0C0H
		CMP	AL,0C0H
		JZ	L_824
		CALL	S_INT7C 		;读32点阵
		JMP	SHORT L_840
L_824:
		CALL	S_INT7D 		;读40点阵
		JMP	SHORT L_840
L_830:
		AND	AL,0F0H
		CMP	AL,10H			;隔点扩?
		JZ	L_832
		AND	AL,0C0H
		OR	AL,AL
		JNZ	L_832
		CALL	S_INT7A 		;读16点阵
		JMP	SHORT L_840
L_832:
		CALL	S_INT7B 		;读24点阵
L_840:
		MOV	BH,AH
		MOV	DH,CS:D_0210		;当前行数
		CMP	DH,CS:D_0214		;判此行空打?
		JA	L_860
		CALL	S_900			;输出

		INC	CS:D_ZJJ		;字间距计数+1
		MOV	CX,CS:D_0217		;字符间距
		ADD	CX,CS:D_ZJA		;+增量
		CMP	CS:D_ZJB,0
		JZ	L_850
		MOV	AX,CS:D_ZJJ		;计数
		CMP	AX,CS:D_ZJB		;从此再+1
		JBE	L_850
		INC	CX
L_850:
		OR	CX,CX			;=0?
		JZ	L_852
		CALL	S_880			;字符间距处理
L_852:
		POP	SI
		PUSH	CS
		POP	DS
		RET
;输出空
L_860:
		POP	SI
L_862:
		PUSH	CS
		POP	DS
		MOV	BX,D_0217		;字符间距
		MOV	AL,AH			;字型
		OR	AL,AL			;判矢量?
		JZ	L_864
		AND	AL,0F0H
		CMP	AL,10H			;隔点扩?
		JZ	L_864
		MOV	AL,AH
		AND	AL,3			;横扩
		INC	AX			;倍数
		PUSH	AX
		MUL	CL
		MOV	CX,AX
		POP	AX
		MUL	BL
		MOV	BX,AX
L_864:
		ADD	CX,CS:D_ZJA		;+增量
		CMP	CS:D_ZJB,0
		JZ	L_866
		MOV	AX,CS:D_ZJJ		;计数
		CMP	AX,CS:D_ZJB		;从此再+1
		JBE	L_866
		INC	CX
L_866:
		MOV	DX,D_0222
		OR	DH,DH			;判空汉字
		JZ	L_868
		ADD	CX,BX			;加字符间距
L_868:
		ADD	CX,BX			;加字符间距
;子程序:输出空列
S_870:
		INC	BP
		XOR	AL,AL
		CALL	S_1AA
		XOR	AL,AL
		CALL	S_1AA
		XOR	AL,AL
		CALL	S_1AA
		LOOP	S_870			;输出空列
		RET

;子程序:字符间距处理 CX=字符间距
S_880:
		MOV	DX,CS:D_0222		;取当前码
		CMP	DH,0A9H 		;判九区?
		JZ	L_882
		MOV	AH,BH
		XOR	CX,CX
		JMP	L_862			;输出空列
L_882:
		SUB	SI,6			;复制倒数第二列
		MOV	CX,CS:D_0217		;字符间距
		SHL	CX,1
		ADD	CX,CS:D_ZJA		;+增量
		CMP	CS:D_ZJB,0
		JZ	L_884
		MOV	AX,CS:D_ZJJ		;计数
		CMP	AX,CS:D_ZJB		;从此再+1
		JBE	L_884
		INC	CX
L_884:
		PUSH	CX
		PUSH	SI
		MOV	CL,1
		CALL	S_900
		POP	SI
		POP	CX
		LOOP	L_884
		RET

;子程序:打印处理 DS:SI=点阵地址,CL=打印列数,BH=字型
S_900:
		MOV	CH,1
		OR	BH,BH			;判矢量?
		JZ	L_910
		MOV	CH,BH
		AND	CH,3			;横扩
		INC	CH			;倍数
L_910:
		LODSB
		MOV	DH,AL		;高
		LODSB
		MOV	DL,AL		;中
		LODSB
		MOV	BL,AL		;低

		MOV	AL,BH
		OR	AL,AL			;矢量
		JZ	L_926
		AND	AL,0CH
		OR	AL,AL
		JZ	L_926
		CMP	AL,0CH			;非纵扩
		JNZ	L_920
		PUSH	WORD PTR CS:D_0210
		SHR	CS:D_0210,1
		CALL	S_960			;二倍
		POP	WORD PTR CS:D_0210
		JMP	SHORT L_922
L_920:
		CMP	AL,4			;纵扩二倍?
		JNZ	L_924
L_922:
		CALL	S_960			;纵扩二倍
		JMP	SHORT L_926
L_924:
		CALL	S_950			;纵扩三倍
L_926:
		CALL	S_940			;输出
		DEC	CL
		JNZ	L_910
		RET

;子程序:打印一列 DH-DL-BL=打印数据,CH=横向放大倍数
S_940:
		PUSH	CX
L_942:
		INC	BP
		MOV	AL,DH
		CALL	S_1AA
		MOV	AL,DL
		CALL	S_1AA
		MOV	AL,BL
		CALL	S_1AA
		DEC	CH
		JNZ	L_942
		POP	CX
		RET

;子程序:纵扩三倍
S_950:
		PUSH	CX
		MOV	AL,CS:D_0210
		CMP	AL,2
		JBE	L_952
		SUB	AL,3
L_952:
		CMP	AL,2			;第三行?
		JNZ	L_953
		MOV	AL,DH		;高
		JMP	SHORT L_955
L_953:
		CMP	AL,1			;第二行?
		JNZ	L_954
		MOV	AL,DL		;中
		JMP	SHORT L_955
L_954:
		MOV	AL,BL		;低
L_955:
		MOV	CH,8
L_956:
		MOV	CL,3
L_957:
		PUSH	AX
		SHL	AL,1
		RCL	BL,1
		RCL	DX,1
		POP	AX
		DEC	CL
		JNZ	L_957
		SHL	AL,1
		DEC	CH
		JNZ	L_956
		POP	CX
		RET

;子程序:纵扩一列 DH-DL-BL=一列数据 返回:DH-DL-BL=一列数据
S_960:
		PUSH	CX
		TEST	CS:D_0210,1		;下半行?
		JZ	L_962
		MOV	AL,DL
		CALL	S_970			;高半字节扩展
		MOV	BL,CL
		MOV	AL,DH
		CALL	S_980			;低半字节扩展
		MOV	DL,CL
		MOV	AL,DH
		CALL	S_970			;高半字节扩展
		MOV	DH,CL
		JMP	SHORT L_966
L_962:
		MOV	AL,DL
		CALL	S_980			;低半字节扩展
		MOV	DH,CL
		MOV	AL,BL
		CALL	S_970			;高半字节扩展
		MOV	DL,CL
		MOV	AL,BL
		CALL	S_980			;低半字节扩展
		MOV	BL,CL
L_966:
		POP	CX
		RET
;子程序:高半字节扩展
S_970:
		MOV	AH,4
L_972:
		RCL	AL,1
		PUSHF
		RCL	CL,1
		POPF
		RCL	CL,1
		DEC	AH
		JNZ	L_972
		RET
;子程序:低半字节扩展
S_980:
		MOV	AH,4
L_982:
		RCR	AL,1
		PUSHF
		RCR	CL,1
		POPF
		RCR	CL,1
		DEC	AH
		JNZ	L_982
		RET

;子程序:属性转换到READSL
	;位0=1垂直点阵,位9-下划线,位10-上划线,位11-下标,位12-上标
	;位13=0旋转90度;=1旋转180度,位14=0左旋;=1右旋,位15=0不旋转;=1旋转
S_SX:
		PUSH	BX
		MOV	AL,D_020E
		MOV	BX,1			;垂直点阵
L_SX1:
		TEST	AL,2			;上划线
		JZ	L_SX2
		OR	BH,4
L_SX2:
		TEST	AL,4			;下划线
		JZ	L_SX3
		OR	BH,2
L_SX3:
		OR	DH,DH
		JZ	L_SX5
		TEST	AL,8			;左旋
		JZ	L_SX4
		OR	BH,80H
		JMP	SHORT L_SX5
L_SX4:
		TEST	AL,10H			;右旋
		JZ	L_SX5
		OR	BH,0C0H
L_SX5:
		TEST	AL,20H			;上标
		JZ	L_SX6
		OR	BH,10H
		JMP	L_SX7
L_SX6:
		TEST	AL,40H			;下标
		JZ	L_SX7
		OR	BH,8
L_SX7:
		MOV	BP,BX
		POP	BX
		RET

;子程序:置图形打印
S_990:
		CMP	D_0210,0		;字型最后一行?
		JZ	L_991
		MOV	BH,0FFH 		;中间行
L_991:
		XOR	BP,BP
		TEST	D_JZ,80H		;判居中或居右?
		JZ	L_993
		MOV	AX,D_0220		;行宽
		SUB	AX,D_0209		;-本行输出列
		JB	L_993
		CMP	D_JZ,-1 		;判居中?
		JNZ	L_992
		SHR	AX,1			;左边加空
L_992:
		MOV	BP,AX
L_993:
		MOV	CX,D_0209		;本行输出列
		ADD	CX,D_021D		;加左边空列
		ADD	CX,BP
		OR	CX,CX
		JZ	L_995
		CALL	S_TX			;置图形打印

		MOV	CX,D_021D		;左边空列
		ADD	CX,BP			;+左边加空
		OR	CX,CX			;=0?
		JZ	L_995
		MOV	AX,CX
		SHL	AX,1
		ADD	CX,AX			;CX*3
L_994:
		XOR	AL,AL
		CALL	L_1AD			;送出无属性的AL
		LOOP	L_994
L_995:
		RET

;子程序:回车走纸
S_9A0:
		CMP	D_0210,0		;末行?
		JZ	L_9A2
		CALL	S_DX			;置单向打印
		MOV	AL,D_LJHJ		;纵扩默认行距
		TEST	D_HJDW,1		;当前行距单位=1/180?	1.12
		JZ	L_9A6
		CBW
		SHL	AL,1			;*2
		MOV	CL,3
		DIV	CL			;/3
		JMP	SHORT L_9A6
L_9A2:
		MOV	AL,BYTE PTR D_0207	;当前打印命令(回车或换行)
		CMP	AL,0DH			;判回车?
		JNZ	L_9A4
		MOV	D_0204,AL
		CALL	S_1A0
		RET
L_9A4:
		CMP	D_0C00,0CH		;判本行有换页符?	1.31
		JZ	L_9A8
		MOV	AL,D_0216
		CALL	S_FX			;置打印方向
		MOV	AL,D_0215		;行距
L_9A6:
		XOR	AH,AH
		CALL	S_ZZ			;走纸
		RET
L_9A8:
		MOV	D_0C00,0		;清换页符标志		2.1
		RET

;子程序:处理换页
S_9B0:
		CMP	BYTE PTR D_0207,0DH	;判回车?
		JZ	L_9B2
		CMP	D_0210,0		;末行?
		JNZ	L_9B2
		CMP	D_0203,-1		;连续打印
		JZ	L_9B2
		CMP	D_0200,0		;页长=0
		JZ	L_9B2
		MOV	AX,D_0202		;累计走纸
		CMP	AX,D_0200
		JB	L_9B2
		MOV	D_0202,0
		CALL	S_DYYH			;打印页号
		CALL	S_YS			;处理页首空
L_9B2:
		RET

;子程序:处理页首空
S_YS:
		MOV	AX,D_0201		;页首空
;子程序:空走纸AX
S_9C0:
		PUSH	CX
		MOV	CX,30
		TEST	D_HJDW,1		;=0:1/180,=1:1/120
		JZ	L_9C2
		MOV	CL,20
L_9C2:
		DIV	CL
		XOR	AH,AH
		XCHG	AX,CX
L_9C4:
		PUSH	AX
		PUSH	CX
		CALL	S_ZZ			;走纸
		POP	CX
		POP	AX
		LOOP	L_9C4
		POP	CX
		RET

;子程序:打印页号
S_DYYH:
		MOV	AX,D_0203		;页号
		OR	AX,AX			;=0不打页号
		JZ	L_DYYH7
		MOV	CX,10
		MOV	SI,OFFSET D_YH1
L_DYYH1:
		XOR	DX,DX
		DIV	CX
		OR	DL,'0'
		MOV	[SI],DL 		;写页号
		DEC	SI
		OR	AX,AX
		JNZ	L_DYYH1
		MOV	BYTE PTR [SI],' '
		SUB	SI,2
		MOV	WORD PTR [SI],0A4A9H	;'─'
		CALL	S_530
L_DYYH2:
		LODSB				;取字符
		OR	AL,AL			;结束?
		JZ	L_DYYH6
		OR	DL,DL			;前字节?
		JZ	L_DYYH5
L_DYYH3:
		CALL	S_480			;计算列数
		XOR	DL,DL
L_DYYH4:
		CALL	S_470			;写入缓冲区
		JMP	SHORT L_DYYH2
L_DYYH5:
		CMP	AL,0A1H 		;判汉字?
		JB	L_DYYH3
		MOV	DL,AL			;存前字节
		JMP	SHORT L_DYYH4
L_DYYH6:
		MOV	D_JZ,-1 		;居中标志
		MOV	D_0202,-1		;打印页号标志
		CALL	S_500			;打印
		INC	D_0203			;页号+1
L_DYYH7:
		CMP	D_0C,0			;换页送打印机?		7.23
		JNZ	L_DYYH8
		MOV	AL,0CH			;换页符
		CALL	S_1A0
L_DYYH8:
		RET
;子程序:设置颜色
S_COLOR:
		PUSH	AX
		MOV	AL,1BH			;ESC
		CALL	S_1A0
		MOV	AL,'C'                  ;颜色控制码
K_COLOR 	EQU	$-1
		CALL	S_1A0
		POP	AX
		AND	AL,0FFH 		;色号
K_COLFF 	EQU	$-1
		JMP	S_1A0

;子程序:取一字节参数AL并计数->CX
S_Q:
		CMP	AL,'0'                  ;判数字?
		JB	L_Q
		CMP	AL,'9'
		JA	L_Q
		PUSH	AX
		AND	AL,0FH
		CBW
		XCHG	AX,D_022E
		MOV	CX,10
		MUL	CX			;原值*10
		ADD	D_022E,AX		;暂存
		POP	AX
		STC
		RET
L_Q:
		MOV	CX,D_022E		;参数
		MOV	D_022E,0
		CLC
		RET

;子程序:设置字型 入口:AL 返回:AL字型,CH行数,CL=列数
S_ZX:
		MOV	D_ZX0,AL
		CMP	AL,'a'
		JB	L_ZX1
		SUB	AL,'a'
		MOV	DI,OFFSET D_ZX1
		JMP	SHORT L_ZX2
L_ZX1:
		SUB	AL,'A'
		MOV	DI,OFFSET D_ZX
L_ZX2:
		CBW
		SHL	AX,1
		ADD	DI,AX
		MOV	AX,DS:[DI]		;取字型
		MOV	CL,AH			;列数
		XOR	CH,CH
		CMP	CL,80H
		JB	L_ZX3
		SUB	CL,80H
		MOV	CH,1
L_ZX3:
		MOV	D_0213,AL		;字型
		MOV	D_0213A,CL		;列数
		MOV	D_0214,CH		;行数
		RET

;子程序:处理字号CL 返回:CH-高,CL-宽
S_ZH:
		PUSH	AX
		MOV	AL,CL
		MOV	BX,OFFSET D_ZH
		CMP	AL,7
		JA	L_ZH1
		CBW
		ADD	BX,AX
		MOV	CL,[BX] 		;宽
		MOV	CH,CL			;高
		POP	AX
		RET
L_ZH1:
		XOR	AH,AH
		MOV	CL,10
		DIV	CL
		MOV	DL,AH			;个位
		CMP	DL,3			;=012为小字号
		JAE	L_ZH2
		MOV	BX,OFFSET D_ZH1
L_ZH2:
		CBW
		ADD	BX,AX
		MOV	CL,[BX] 		;宽
		MOV	CH,CL			;高
		OR	DL,DL
		JZ	L_ZH4
		TEST	DL,1
		JZ	L_ZH3
		MOV	AL,CL
		CALL	S_43			;*3/4
		MOV	CL,AL
		JMP	SHORT L_ZH4
L_ZH3:
		MOV	AL,CH
		CALL	S_43			;*3/4
		MOV	CH,AL
L_ZH4:
		POP	AX
		RET
S_43:
		MOV	DH,3
		MUL	DH			;*3
		SHR	AL,1			;/4
		SHR	AL,1
		RET

;子程序:处理字高CH
S_HIGH:
		MOV	D_0213B,CH		;高度
		PUSH	AX
		MOV	AL,CH
		XOR	AH,AH
		MOV	BL,24
		DIV	BL
		OR	AH,AH
		JNZ	L_HIGH1
		DEC	AX
L_HIGH1:
		MOV	D_0214,AL		;行数
		POP	AX
		RET
S_HIGH1:
		CALL	S_HIGH
		MOV	BL,D_0214
		CMP	BL,D_0210		;与已指定行数比
		JBE	L_HIGH2
		MOV	D_0210,BL
L_HIGH2:
		RET

D_WHZ		DW	0
D_WZF		DW	0
;子程序:处理行禁则
S_PB:
		RET				;=90H打开,=0C3H关闭
		DEC	D_ZJJ			;字间距计数-1
		MOV	DL,AL
		CMP	AL,0A1H 		;判汉字?
		JB	L_PB1
		MOV	DH,AL
		MOV	DL,D_021F		;汉字前字节
		MOV	D_WHZ,BX
		SHR	BX,1
		MOV	D_WZF,BX
		JMP	SHORT L_PB2
L_PB1:
		MOV	D_WZF,BX
		SHL	BX,1
		MOV	D_WHZ,BX
L_PB2:
		MOV	DI,OFFSET D_P		;下移存放区
		XOR	CX,CX			;    列数
		XOR	BP,BP
		CALL	S_FINDS
		CMP	D_P,0
		JNZ	L_PB3
		CALL	S_FINDW 		;查找行尾
L_PB3:
		MOV	AX,CX			;下移列数
		ADD	AX,D_0220
		SUB	AX,D_0209
		XOR	DX,DX
		DIV	D_ZJJ
		MOV	D_ZJA,AX		;字间距增量
		MOV	AX,D_ZJJ
		SUB	AX,DX
		MOV	D_ZJB,AX		;从此再+1
		MOV	AX,D_0220
		MOV	D_0209,AX
		RET
;子程序:行禁则处理 AL或AX-行尾,DI-下移存放区指针 返回:CX-下移列宽
						;BP=0:行首找到,>0行尾找到
S_FINDS:
		CMP	DL,0A1H 		;下行首字符为汉字?
		JAE	L_FS1
		MOV	SI,OFFSET D_LTOP1	;行首禁则字符
		CALL	S_FINDDL		;查
		JNB	L_FS3
		JMP	SHORT L_FS2		;找到
L_FS1:
		MOV	SI,OFFSET D_LTOP	;行首禁则符号
		CALL	S_FINDDX
		JNB	L_FS3
L_FS2:
		RET
L_FS3:						;行首找到------
		INC	BP
		MOV	SI,D_0205		;输入缓冲区指针
		MOV	DL,[SI-1]		;行尾字符
		CMP	DL,0A1H 		;判汉字?
		JB	L_FS4
		MOV	DX,[SI-2]		;行尾汉字
		MOV	BX,2
		SUB	D_0205,BX		;指针-2
		CALL	S_POR			;后移
		MOV	[DI],DX
		ADD	DI,2
		MOV	AX,D_WHZ
		JMP	SHORT L_FS5
L_FS4:
		MOV	BX,1
		DEC	D_0205			;指针-1
		CALL	S_POR
		MOV	[DI],DL
		INC	DI
		MOV	AX,D_WZF
L_FS5:
		ADD	CX,AX
		DEC	D_ZJJ
		CMP	BP,1
		JNZ	S_FINDS
		MOV	BYTE PTR [DI],0
		JMP	SHORT S_FINDS
S_FINDW:
		MOV	BP,-1
		CALL	S_POR
		MOV	SI,D_0205		;输入缓冲区指针
		MOV	DL,[SI-1]		;行尾字符
		CMP	DL,0A1H 		;判汉字?
		JAE	L_FW1
		MOV	SI,OFFSET D_LEND1	;行尾禁则字符
		CALL	S_FINDDL		;查
		JNB	L_FW2
L_FW0:						;行尾未找到----
		MOV	BYTE PTR [DI],0
		RET
L_FW1:
		MOV	DX,[SI-2]
		MOV	SI,OFFSET D_LEND	;行尾禁则符号
		CALL	S_FINDDX		;查
		JB	L_FW0
		SUB	D_0205,2		;指针-2
		MOV	[DI],DX
		ADD	DI,2
		MOV	AX,D_WHZ
		MOV	BX,2
		JMP	SHORT L_FW3
L_FW2:						;找到处理字符-
		DEC	D_0205			;指针-1
		MOV	[DI],DL
		INC	DI
		MOV	BX,1
		MOV	AX,D_WZF
L_FW3:
		ADD	CX,AX
		DEC	D_ZJJ
		JMP	SHORT S_FINDW

;子程序:下移字符区后移BX字节
S_POR:
		CMP	BP,1
		JZ	L_PR3
		MOV	SI,OFFSET D_P
L_PR1:
		LODSB
		OR	AL,AL
		JNZ	L_PR1
		CMP	BP,-1
		JNZ	L_PR2
		DEC	SI
		MOV	DI,SI
		RET
L_PR2:
		DEC	SI
		MOV	AL,[SI]
		MOV	[BX+SI],AL
		CMP	SI,OFFSET D_P
		JNZ	L_PR2
L_PR3:
		MOV	DI,OFFSET D_P
		RET
;子程序:查找字符 SI-查找区,DL-待查字符
S_FINDDL:
		LODSB
		OR	AL,AL
		JZ	L_FIND1
		CMP	DL,AL
		JNZ	S_FINDDL
		CLC
		RET
;子程序:查找符号 SI-查找区,DL-待查符号
S_FINDDX:
		LODSW
		OR	AX,AX
		JZ	L_FIND1
		CMP	DX,AX
		JNZ	S_FINDDX
		CLC
		RET
L_FIND1:
		STC
		RET

D_LEND		DB	'“‘《',0,0            ;行尾
D_LEND1 	DB	'([',0
D_LTOP		DB	'”’》，。；、？！',0,0  ;行首
D_LTOP1 	DB	',;?!)]',0

;----------------------------------------------------------------------------
;子程序:设置图象打印方式 CX=列数,BH=-1中间行
S_TX:
		TEST	T_TX,10H		;判打印方向?
		JZ	L_TX2
		MOV	AL,'G'                  ;单向命令
		CMP	BH,-1			;中间行?
		JZ	L_TX1
		MOV	AL,D_FF 		;指定方向
L_TX1:
		MOV	C_TX[2],AL		;置打印方向
L_TX2:
		TEST	T_TX,20H		;=1:先处理打印方向
		JZ	L_TX4
		CMP	BH,-1			;中间行?
		JNZ	L_TX3
		MOV	D_FF,BH 		;保存
		CALL	S_DX			;单向
		JMP	SHORT L_TX4
L_TX3:
		MOV	AL,D_0216		;打印方向
		CALL	S_FX			;设置打印方向
L_TX4:
		MOV	SI,OFFSET C_TX
		MOV	AL,T_TX
		TEST	AL,80H			;判ASC码?
		JZ	L_TX7
		AND	AL,0FH
		CBW				;写入偏移
		ADD	SI,AX
		MOV	AX,CX
		MOV	CX,40AH
L_TX5:
		DIV	CL
		OR	AH,'0'                  ;转ASC
		MOV	[SI],AH 		;写入
		XOR	AH,AH
		DEC	SI
		DEC	CH
		JNZ	L_TX5
L_TX6:
		MOV	SI,OFFSET C_TX		;图象命令首
		JMP	S_DYC
L_TX7:
		TEST	AL,40H			;=0:前高后低
		JNZ	L_TX8			;=1:前低后高
		XCHG	CH,CL
L_TX8:
		AND	AL,0FH
		CBW				;偏移
		ADD	SI,AX
		MOV	[SI],CX 		;写入
		JMP	SHORT L_TX6

;子程序:走纸 AX=点数
S_ZZ:
		MOV	CL,3
		TEST	D_HJDW,1		;当前行距单位=1/180?
		JNZ	L_ZZ3
		ADD	D_0202,AX		;累计走纸		4.26

		CMP	D_HJDW0,1		;1/120?
		JNZ	L_ZZ1
		SHL	AX,1
		DIV	CL
		XOR	AH,AH
		JMP	SHORT L_ZZ6
L_ZZ1:
		CMP	D_HJDW0,2		;1/48?
		JNZ	L_ZZ2
		SHL	AX,1
		SHL	AX,1
		MOV	CL,15
		DIV	CL
		XOR	AH,AH
		JMP	SHORT L_ZZ6
L_ZZ2:
		CMP	D_HJDW0,3		;1/360?
		JNZ	L_ZZ6
		SHL	AX,1
		JMP	SHORT L_ZZ6
L_ZZ3:						;当前行距单位=1/120
		PUSH	AX
		MUL	CL
		SHR	AX,1
		ADD	D_0202,AX		;累计走纸		4.26
		POP	AX

		CMP	D_HJDW0,0		;1/180?
		JNZ	L_ZZ4
		MUL	CL
		SHR	AX,1
		JMP	SHORT L_ZZ6
L_ZZ4:
		CMP	D_HJDW0,2		;1/48?
		JNZ	L_ZZ5
		SHL	AX,1
		SHL	AX,1
		JMP	SHORT L_ZZ6
L_ZZ5:
		CMP	D_HJDW0,3		;1/360?
		JNZ	L_ZZ6
		MUL	CL
L_ZZ6:
		MOV	CL,T_ZZ
		AND	CL,0FH
		XOR	CH,CH
		ADD	CX,OFFSET C_ZZ
		MOV	SI,CX			;写入地址

		TEST	T_ZZ,80H		;ASC码?
		JZ	L_ZZ9
		MOV	CX,20AH
L_ZZ7:
		DIV	CL
		OR	AH,'0'
		MOV	[SI],AH
		XOR	AH,AH
		DEC	SI
		DEC	CH
		JNZ	L_ZZ7
L_ZZ8:
		MOV	SI,OFFSET C_ZZ		;走纸命令
		JMP	S_DYC
L_ZZ9:
		MOV	[SI],AL
		JMP	SHORT L_ZZ8

;子程序:置单向打印
S_DX:
		MOV	AL,'>'                  ;多行单向打印
K_DHFX	EQU	$-1
;子程序:设置打印方向AL(='>'或'<')
S_FX:
		TEST	T_TX,10H		;图象命令判方向?
		JZ	L_FX
		MOV	D_FF,AL 		;保存
L_FX:
		MOV	SI,OFFSET C_DX
		CMP	AL,'>'
		JZ	S_DYC
		MOV	SI,OFFSET C_SX
;子程序:输出字符串DS:SI(首字节为字节数)
S_DYC:
		PUSH	CX
		LODSB				;取首字节
		OR	AL,AL
		JZ	L_DYC2
		CBW
		MOV	CX,AX			;字节数
L_DYC1:
		LODSB
		CALL	S_1A0
		LOOP	L_DYC1
L_DYC2:
		POP	CX
		RET

;子程序:向打印机输出一个字节-------------------------------------------------
S_1A0:
		MOV	AH,2			;取打印机状态
		CALL	S_1A2
		TEST	AH,29H			;检查错误?
		JNZ	S_1A0
		XOR	AH,AH
S_1A2:
		PUSH	DX
		MOV	DX,CS:K_PORT		;0号打印口
		PUSHF
		CALL	CS:D_INT17
		POP	DX
		MOV	BYTE PTR CS:D_0207+1,AH ;状态
		RET

;子程序:输出一字节图形数据
S_1AA:
		TEST	BYTE PTR CS:D_020D,7	;判背景?
		JZ	L_1AB
		PUSH	AX
		MOV	AL,CS:D_020D		;功能字节2
		AND	AL,7			;背景号
		MOV	AH,8
		MUL	AH
		AND	BP,7			;取当前列末三位
		ADD	BP,AX
		POP	AX
		OR	AL,CS:D_0230-8[BP]	;迭加背景图形字节
L_1AB:
		TEST	BYTE PTR CS:D_020E,1	;反白?
		JZ	L_1AC
		NOT	AL
L_1AC:
		TEST	BYTE PTR CS:D_020D,8	;轻打?
		JZ	L_1AD
		TEST	BP,1			;判奇数列?
		JZ	L_1AD
		XOR	AL,AL			;变空列
K_AL		EQU	$			;若1351则 JMP L_0A60
L_1AD:
		JMP	SHORT S_1A0		;若字节反位则为 MOV AH,AL
		PUSH	CX
		MOV	CX,8
L_1AE:
		SHL	AH,1
		RCR	AL,1
		LOOP	L_1AE			;字节反位
		POP	CX
		JMP	S_1A0

;取点阵----------------------------------------------------------------------
;子程序:读16点阵字库
S_INT7A:
		XOR	DI,DI
		MOV	DS,DI
		CMP	WORD PTR DS:[1EAH],0	;INT7A段=0?
		JZ	L_7A1
		INT	7AH
		RET
L_7A1:
		MOV	CX,10H			;16点阵
		JMP	SHORT L_7B2

;子程序:读24点阵字库
S_INT7B:
		XOR	DI,DI
		MOV	DS,DI
		CMP	WORD PTR DS:[1EEH],0	;INT7B段=0?
		JZ	L_7B1
		INT	7BH
		RET
L_7B1:
		MOV	CX,18H			;24点阵
		MOV	AL,AH
		AND	AL,0F0H
		CMP	AL,10H			;判隔点扩?
		JNZ	L_7B2
		MOV	CL,CS:D_0213A		;字型列数
		AND	AH,0FCH
L_7B2:
		PUSH	CS
		POP	DS
		XOR	SI,SI
		MOV	AX,80H
L_7B3:
		MOV	BYTE PTR [SI],0
		INC	SI
		DEC	AX
		JNZ	L_7B3
		XOR	SI,SI
		IRET

;子程序:读32点阵字库
S_INT7C:
		XOR	DI,DI
		MOV	DS,DI
		CMP	WORD PTR DS:[1F2H],0	;INT7C段=0?
		JZ	L_7C1
		INT	7CH
		RET
L_7C1:
		MOV	CX,20H			;32点阵
		JMP	SHORT L_7B2

;子程序:读40点阵字库
S_INT7D:
		XOR	DI,DI
		MOV	DS,DI
		CMP	WORD PTR DS:[1F6H],0	;INT7D段=0?
		JZ	L_7D1
		INT	7DH
		RET
L_7D1:
		MOV	CX,28H			;40点阵
		JMP	SHORT L_7B2

;子程序:读矢量字库
S_INT7E:
		PUSH	DI
		XOR	DI,DI
		MOV	DS,DI
		CMP	WORD PTR DS:[1FAH],0	;INT7E段=0?
		POP	DI
		JZ	L_7E1
		INT	7EH
		RET
L_7E1:
		MOV	CL,CS:D_0213A		;字型列数
		XOR	CH,CH
		OR	DH,DH
		JNZ	L_7B2
		SHR	CX,1
		JMP	L_7B2

;P1351输出转换---------------------------------------------------------------
D_0A50		DB	0			;3字节指针
D_026C		DB	0, 0, 0
L_0A60: 					;P1351用3字节扩4字节子程序
		PUSH	BX
		PUSH	CX
		PUSH	DS
		PUSH	CS
		POP	DS
		MOV	BL,D_0A50		;取指针
		XOR	BH,BH
		MOV	D_026C[BX],AL		;存
		INC	D_0A50			;指针+1
		CMP	D_0A50,3		;判3个?
		JNZ	L_0A70
		MOV	D_0A50,0		;清
		MOV	CX,4
		MOV	BX,OFFSET D_026C	;3字节缓冲区
L_0A68:
		PUSH	CX
		MOV	CL,6
		XOR	AL,AL
L_0A6C:
		SHL	BYTE PTR [BX+2],1
		RCL	BYTE PTR [BX+1],1
		RCL	BYTE PTR [BX],1
		RCL	AL,1
		LOOP	L_0A6C
		CALL	S_1A0			;输出
		POP	CX
		LOOP	L_0A68
L_0A70:
		POP	DS
		POP	CX
		POP	BX
		RET
S_AH00		ENDP

;****************************************************************************
BEGIN:
		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_S10
L_S1:
		LODSB
		CMP	AL,' '
		JZ	L_S1

		CMP	AL,0DH
		JNZ	L_S2
		JMP	L_S10
L_S2:
		CMP	AL,'0'
		JB	L_S3
		CMP	AL,'9'
		JA	L_S3
		MOV	D_DYJH,AL
		JMP	SHORT L_S1
L_S3:
		CMP	AL,'/'
		JNZ	L_S1
		LODSB
		CMP	AL,'?'                  ;显示帮助?
		JNZ	L_S5
L_S4:
		MOV	DX,OFFSET MSG
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_S5:
		CMP	AL,'1'                  ;多行字型空行走纸
		JNZ	L_S5A
		MOV	BYTE PTR DS:D_0A00,0
		JMP	L_S1
L_S5A:
		CMP	AL,'2'                  ;换页自行处理?
		JNZ	L_S5B
		MOV	D_0C,AL
		JMP	L_S1
L_S5B:
		CMP	AL,'3'                  ;行距单位改1/180?       12.31
		JNZ	L_S5C
		MOV	D_HJDW,0
		JMP	L_S1
L_S5C:
		CMP	AL,'4'                  ;改为行间距1/180        1.10
		JNZ	L_S6
		MOV	D_HJDW,2
		MOV	BYTE PTR K_HJJ,75H
		JMP	L_S1
L_S6:
		CMP	AL,'4'                  ;改为行间距1/120        1.4
		JNZ	L_S7
		MOV	D_HJDW,3
		MOV	BYTE PTR K_HJJ,75H
		JMP	L_S1
L_S7:
		AND	AL,5FH
		CMP	AL,'S'                  ;设置排版参数?
		JNZ	L_S8
		JMP	L_SET
L_S8:
		CMP	AL,'N'                  ;驻留基本内存?
		JNZ	L_S9
		MOV	D_RAM,AL
L_S9:
		JMP	L_S1
L_S10:
		CMP	D_DYJH,0		;无打印机号?
		JNZ	L_S20
		JMP	L_S4
L_S20:
		MOV	AX,-1			;取本模块安装状态
		INT	17H
		CMP	AX,-2130H		;是否已装载?
		JNZ	L_S30
		MOV	DX,OFFSET ALREADY
		JMP	SHORT L_ERR
L_S30:
		MOV	AX,3517H		;取原INT17
		INT	21H
		MOV	WORD PTR D_INT17,BX	;保存
		MOV	WORD PTR D_INT17+2,ES
		PUSH	CS
		POP	ES

		MOV	AL,D_DYJH		;打印机号
		AND	AL,0FH
		MOV	CX,30H
		MUL	CL
		ADD	AX,OFFSET P_0		;指定打印机参数
		MOV	SI,AX
		MOV	DI,OFFSET D_DYJH	;打印机参数区
		REP	MOVSB			;传送

		MOV	AL,D_DYJH		;打印机号
		CMP	AL,'1'                  ;P1351?
		JNZ	L_S50
		MOV	BYTE PTR K_AL,0E9H	;JMP
		MOV	WORD PTR K_AL+1,OFFSET L_0A60-OFFSET K_AL-3
		MOV	DX,OFFSET BEGIN
		JMP	SHORT L_S80
L_S50:
		CMP	AL,'2'                  ;M2024?
		JNZ	L_S52
	;	MOV	BYTE PTR K_1724,0C3H
		JMP	SHORT L_S70
L_S52:
		CMP	AL,'4'                  ;AR2463?
		JZ	L_S60
		CMP	AL,'0'
		JZ	L_S54
		CMP	AL,'5'                  ;LQ1500?
		JNZ	L_S55
L_S54:
		MOV	BYTE PTR K_COLOR,'r'
		MOV	BYTE PTR K_COLFF,0FH
		JMP	SHORT L_S70
L_S55:
		CMP	AL,'7'                  ;M1570?
		JB	L_S70
L_S60:
		MOV	WORD PTR K_AL,0C488H	;打开字节反位
L_S70:
		MOV	DX,OFFSET L_0A60
L_S80:
		AND	DL,0F0H
		ADD	DX,10H
		MOV	D_01FA,DX		;置输入区首
		MOV	D_0205,DX
		ADD	DX,512			;加输入区长度
		MOV	D_01FC,DX		;置输入区尾
		MOV	BP,DX

		MOV	AX,CS
		CMP	AX,0A000H		;判LH?
		JA	L_S90
		CMP	D_RAM,'N'               ;驻留基本内存
		JZ	L_S90
		CALL	S_GETUMB		;分配UMB段
		JZ	L_S92
L_S90:
		MOV	ES,DS:[2CH]
		MOV	AH,49H			;清环境块
		INT	21H
		CALL	S_SETINT
		MOV	DX,BP			;驻留
		INT	27H
L_S92:
		MOV	AX,D_UMB
		OR	AX,AX
		JZ	L_S90
		DEC	AX
		MOV	ES,AX
		MOV	DI,8
		MOV	SI,OFFSET D_NAME
		MOV	CX,5
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
D_RAM		DB	0			;='N':驻留基本内存

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
		MOV	DX,OFFSET INT_17	;建中断
		MOV	AX,2517H
		INT	21H
		RET

S_SETINT	ENDP

;----------------------------------------------------------------------------
L_SET:
		MOV	DX,OFFSET D_PBMSG	;'** 设  置  排  版  参  数 **'
		MOV	AH,9
		INT	21H
		XOR	BP,BP
		MOV	SI,OFFSET D_PBCS	;排版参数表
L_SET1:
		MOV	DI,OFFSET D_PBCSB
		MOV	CX,30
		MOV	AL,' '
		REP	STOSB			;清空
		MOV	AX,BP
		INC	AX
		OR	AL,30H
		MOV	D_PBCSB+3,AL		;序号
		MOV	DI,OFFSET D_PBCSB+9
		LODSW				;页长
		CALL	S_JS
		MOV	DI,OFFSET D_PBCSB+15
		LODSW				;页首
		CALL	S_JS
		MOV	DI,OFFSET D_PBCSB+21
		LODSW				;左空
		CALL	S_JS
		MOV	DI,OFFSET D_PBCSB+27
		LODSW				;行宽
		CALL	S_JS
		MOV	DX,OFFSET D_PBCSB
		MOV	AH,9			;显示
		INT	21H
		MOV	AX,12
		MUL	BP
		ADD	AX,OFFSET D_PBBZ	;备注
		MOV	BX,AX
		MOV	CX,12
L_SET2:
		MOV	DL,[BX]
		INC	BX
		MOV	AH,2			;显示
		INT	21H
		LOOP	L_SET2
		MOV	AX,0E0DH		;回车
		INT	10H
		MOV	AX,0E0AH		;换行
		INT	10H
		INC	BP
		CMP	BP,6
		JNZ	L_SET1
L_SET3:
		MOV	DX,OFFSET D_JRXH	;'请 键 入 序 号: $'
		MOV	AH,9
		INT	21H
L_SET4:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,1BH			;ESC?
		JNZ	L_SET5
		JMP	L_SET10
L_SET5:
		CMP	AL,0DH			;回车
		JZ	L_SET
		CMP	AL,'1'                  ;判1~6
		JB	L_SET4
		CMP	AL,'6'
		JA	L_SET4
		MOV	DL,AL
		MOV	AH,2			;显示序号
		INT	21H
		DEC	AX
		AND	AL,0FH
		PUSH	AX
		MOV	AH,8
		MUL	AH
		ADD	AX,OFFSET D_PBCS
		MOV	DI,AX			;参数写入地址
		POP	AX
		MOV	AH,12
		MUL	AH
		ADD	AX,OFFSET D_PBBZ
		MOV	BP,AX			;备注写入地址

		MOV	DX,OFFSET D_YC		;'页长(单位：点): $'
		MOV	AH,9
		INT	21H
		CALL	S_INPUT 		;键入
		JB	L_SET6A
		MOV	[DI],AX 		;写入
L_SET6A:
		ADD	DI,2
		MOV	DX,OFFSET D_YS		;'页首(单位：点): $'
		MOV	AH,9
		INT	21H
		CALL	S_INPUT 		;键入
		JB	L_SET6
		MOV	[DI],AX 		;写入
L_SET6:
		ADD	DI,2
		MOV	DX,OFFSET D_ZK		;'左空(单位：点): $'
		MOV	AH,9
		INT	21H
		CALL	S_INPUT 		;键入
		JB	L_SET7
		MOV	[DI],AX 		;写入
L_SET7:
		ADD	DI,2
		MOV	DX,OFFSET D_HK		;'行宽(单位：点): $'
		MOV	AH,9
		INT	21H
		CALL	S_INPUT 		;键入
		JB	L_SET8
		MOV	[DI],AX 		;写入
L_SET8:
		MOV	DX,OFFSET D_BZ		;'备注(12个字符): $'
		MOV	AH,9
		INT	21H
		MOV	DX,OFFSET D_INPUT
		MOV	SI,DX
		MOV	WORD PTR [SI],13
		MOV	AH,0AH
		INT	21H
		INC	SI
		LODSB
		OR	AL,AL
		JZ	L_SET9
		CBW
		MOV	CX,AX
		MOV	DI,BP
		REP	MOVSB
		MOV	CX,12
		SUB	CX,AX
		JZ	L_SET9
		MOV	AL,' '
		REP	STOSB
L_SET9:
		JMP	L_SET3
L_SET10:
		MOV	DX,OFFSET D_CP		;'1-存盘并写入内存, 2-仅存盘: '
		MOV	AH,9
		INT	21H
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,'1'                  ;判1(写入排版参数?
		JNZ	L_SET11
		MOV	AX,3517H		;取INT17段
		INT	21H
		MOV	SI,OFFSET D_PBCS
		MOV	DI,SI
		MOV	CX,6*4
		REP	MOVSW			;传送排版参数
		JMP	SHORT L_SET12
L_SET11:
		CMP	AL,'2'                  ;判2(存盘)?
		JNZ	L_SET15
L_SET12:
		MOV	DS,DS:[2CH]		;环境变量段
		XOR	SI,SI
		XOR	AX,AX
L_SET13:
		CMP	DS:[SI],AX		;查找环境区尾?
		JZ	L_SET14
		INC	SI
		JMP	SHORT L_SET13
L_SET14:
		ADD	SI,4
		MOV	DX,SI			;调出文件名(带路径)
		MOV	CX,20H
		MOV	AH,3CH			;重建文件
		INT	21H
		MOV	BX,AX
		PUSH	CS
		POP	DS
		MOV	DX,100H
		MOV	CX,OFFSET D_END-100H
		MOV	AH,40H			;写入
		INT	21H
		MOV	AH,3EH			;关闭
		INT	21H
L_SET15:
		INT	20H

S_JS		PROC	NEAR
		MOV	CX,10
L_JS1:
		XOR	DX,DX
		DIV	CX
		OR	DL,30H
		MOV	[DI],DL
		DEC	DI
		OR	AX,AX
		JNZ	L_JS1
		RET
S_JS		ENDP

;子程序:键入数字 返回BX
S_INPUT 	PROC	NEAR
		MOV	SI,OFFSET D_INPUT	;键入缓冲区
		XOR	BX,BX
L_IN1:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,0DH			;回车?
		JZ	L_IN6
		CMP	AL,1BH			;<ESC>
		JZ	L_IN9
		CMP	AL,8			;退格?
		JNZ	L_IN5
		CMP	SI,OFFSET D_INPUT	;指针在区首?
		JA	L_IN3
		MOV	AX,0E07H
		INT	10H
		JMP	SHORT L_IN1
L_IN3:
		DEC	SI			;位置-1
L_IN4:
		MOV	AH,0EH			;退格
		INT	10H
		CMP	AL,8			;退格?
		JNZ	L_IN1
		MOV	CX,1
		MOV	AX,0A20H		;显示空格
		INT	10H
		JMP	SHORT L_IN1
L_IN5:
		CMP	AL,'0'                  ;判数字?
		JB	L_IN1
		CMP	AL,'9'
		JA	L_IN1
		MOV	[SI],AL 		;写入
		INC	SI
		JMP	SHORT L_IN4
L_IN6:
		CMP	SI,OFFSET D_INPUT
		JZ	L_IN9
		MOV	BYTE PTR [SI],0
		MOV	SI,OFFSET D_INPUT	;键入区首
L_IN7:
		LODSB				;取
		OR	AL,AL
		JZ	L_IN8
		AND	AL,0FH
		CBW
		PUSH	AX
		MOV	AX,10
		MUL	BX
		MOV	BX,AX
		POP	AX
		ADD	BX,AX
		JMP	SHORT L_IN7
L_IN8:
		MOV	AX,BX
		CLC
		RET
L_IN9:
		STC
		RET
S_INPUT 	ENDP

D_NAME		DB	'PRNT',0
D_PBMSG 	DB	13,10,'** 设  置  排  版  参  数 **',13,10
		DB	'序号  页长  页首  左空  行宽  备注',13,10,'$'
D_PBCSB 	DB	'                              $'
D_PBBZ		DB	'LQ窄纸      '
		DB	'LQ宽纸      '
		DB	'A4 纸       '
		DB	'B5 纸       '
		DB	2*12 DUP(' ')
D_JRXH		DB	13,10,'请键入序号(回车-重显,ESC-退出): $'
D_YC		DB	13,10,'页长度(单位：点): $'
D_YS		DB	13,10,'页首空(单位：点): $'
D_ZK		DB	13,10,'左边空(单位：点): $'
D_HK		DB	13,10,'行宽度(单位：点): $'
D_BZ		DB	13,10,'备  注(12个字符): $'
D_CP		DB	13,10,'1-存盘并写入内存, 2-仅存盘, 其他-退出: $'
D_INPUT 	DB	15 DUP(0)

ALREADY 	DB	'PRNT 模块已经驻留!',7,13,10,'$'
MSG		DB	'2.13L 汉字系统-97 针式打印机驱动程序 1999.1.10',13,10
		DB	'命令行参数: PRNT [0-9][/1][/2][/3][/4][/5]或[/S]',13,10
		DB	'      其中: [0-9]-打印机序号',13,10
		DB	'            [/1]-多行字型空行走纸多行',13,10
		DB	'            [/2]-换页自行处理(否则直送打印机)',13,10
		DB	'            [/3]-行距单位改1/180英寸(缺省1/120)',13,10
		DB	'            [/4]-&改行间距1/180英寸.加24=行距',13,10
		DB	'            [/5]-&改行间距1/120英寸.加16=行距',13,10
		DB	'            [/S]-设置排版参数.',13,10
		DB	'打印机序号:0-AR3240,1-P1351,  2-M2024, 3-TH3070, 4-AR2463',13,10
		DB	'           5-LQ1500,6-OKI8320,7-M1570, 8-NEC3824,9-NM9400',13,10,'$'

;各打印机参数----------------------------------------------------------------
P_0	DB	'0'                             ;AR3240
	DB	64H				;二进制数,前低后高
	DB	5,1BH,2AH,27H,0,0,0,0,0 	;图形
	DB	3				;二进制数
	DB	5,1BH,'3',0,0DH,0AH,0,0         ;走纸
	DB	3,1BH,'U',0                     ;双向
	DB	3,1BH,'U',1                     ;单向
	DB	0				;1/180
	DB	24				;连接行距
	DW	2448				;最大列数
	DB	'AR3240$',9 DUP(0)              ;打印机名

P_1	DB	'1'                             ;P1351
	DB	86H				;ASC数
	DB	6,1BH,';0000',0,0               ;图形
	DB	84H				;ASC数
	DB	6,1BH,'L00',0DH,0AH,0           ;走纸
	DB	2,1BH,'5',0                     ;双向
	DB	2,1BH,'6',0                     ;单向
	DB	2				;1/48
	DB	24				;连接行距
	DW	2448				;最大列数
	DB	'P1351$',10 DUP(0)              ;打印机名

P_2	DB	'2'                             ;M2024
	DB	13H				;二进制数,判打印方向
	DB	4,1BH,'4',0,0,0,0,0,0           ;图形
	DB	3				;二进制数
	DB	4,1BH,'J',0,0AH,0,0,0           ;走纸
	DB	8 DUP (0)
	DB	1				;1/120
	DB	27				;连接行距
	DW	2176				;最大列数
	DB	'M2024,M1724$',4 DUP(0)         ;打印机名

P_3	DB	'3'                             ;TH3070
	DB	3				;二进制数
	DB	4,1BH,'I',0,0,0,0,0,0           ;图形
	DB	86H				;ASC数
	DB	6,1BH,'W0000',0                 ;走纸
	DB	2,1BH,'<',0                     ;双向
	DB	2,1BH,'>',0                     ;单向
	DB	1				;1/120
	DB	24				;连接行距
	DW	2448				;最大列数
	DB	'TH3070$',9 DUP(0)              ;打印机名

P_4	DB	'4'                             ;AR2463
	DB	86H				;ASC数
	DB	6,1BH,'J0000',0,0               ;图形
	DB	84H				;ASC数
	DB	6,1BH,'T00',0DH,0AH,0           ;走纸
	DB	2,1BH,']',0                     ;双向
	DB	2,1BH,'>',0                     ;单向
	DB	1				;1/120
	DB	24				;连接行距
	DW	2448				;最大列数
	DB	'AR2463$',9 DUP(0)              ;打印机名

P_5	DB	'5'                             ;LQ1500
	DB	64H				;二进制数,前低后高
	DB	5,1BH,2AH,27H,0,0,0,0,0 	;图形
	DB	3				;二进制数
	DB	5,1BH,'3',0,0DH,0AH,0,0         ;走纸
	DB	3,1BH,'U',0                     ;双向
	DB	3,1BH,'U',1                     ;单向
	DB	0				;1/180
	DB	24				;连接行距
	DW	2448				;最大列数
	DB	'LQ1600系列$',5 DUP(0)          ;打印机名

P_6	DB	'6'                             ;OKI8320
	DB	4				;二进制数
	DB	5,1BH,'%1',0,0,0,0,0            ;图形
	DB	5				;二进制数
	DB	7,1BH,'%9',0,0,0DH,0AH          ;走纸
	DB	3,1BH,'%B'                      ;双向
	DB	3,1BH,'%U'                      ;单向
	DB	1				;1/120
	DB	24				;连接行距
	DW	2448				;最大列数
	DB	'OKI8320,5320$',3 DUP(0)        ;打印机名

P_7	DB	'7'                             ;M1570
	DB	86H				;ASC数
	DB	6,1BH,'G0000',0,0               ;图形
	DB	84H				;ASC数
	DB	6,1BH,'T00',0DH,0AH,0           ;走纸
	DB	2,1BH,']',0                     ;双向
	DB	2,1BH,'>',0                     ;单向
	DB	3				;1/360
	DB	24				;连接行距
	DW	2448				;最大列数
	DB	'M1570$',10 DUP(0)              ;打印机名

P_8	DB	'8'                             ;NEC3824
	DB	86H				;ASC数
	DB	6,1BH,'J0000',0,0               ;图形
	DB	84H				;ASC数
	DB	6,1BH,'T00',0DH,0AH,0           ;走纸
	DB	2,1BH,']',0                     ;双向
	DB	2,1BH,'>',0                     ;单向
	DB	1				;1/120
	DB	27				;连接行距
	DW	2176				;最大列数
	DB	'NEC3824$',8 DUP(0)             ;打印机名

P_9	DB	'9'                             ;NM9400
	DB	88H				;ASC数
	DB	8,1AH,43H,1BH,'J0000'           ;图形
	DB	84H				;ASC数
	DB	6,1BH,'T00',0DH,0AH,0           ;走纸
	DB	2,1BH,']',0                     ;双向
	DB	2,1BH,'>',0                     ;单向
	DB	1				;1/120
	DB	24				;连接行距
	DW	2448				;最大列数
	DB	'NM9400$',9 DUP(0)              ;打印机名

;----------------------------------------------------------------------------
;命令集:ESC+I+N1+N2+..图形方式打印(后跟3*(N1*256+N2)字节图形数据.NI和N2为0~255)
;	ESC+I+A~x     设置字型		    ESC+W     执行INT5
;	ESC+I+＇      取消`功能 	    ESC+I+`   恢复`功能(默认状态)
;	ESC+I+\       取消软回车8D0A	    ESC+I+/   恢复软回车8D0A为0D0A(默认状态)
;	`@n1,n2,n3`   设置字型(n1为横向宽度,n2为纵向高度,n3为字体号.均为十进制数)
;	`@A~x`	      设置字型(默认A字型)
;	`@@字号,n3`   设置字型(字号0=90,1=72,2=48,3=40,4=32,5=24,6=20,7-16)
;	      小字号:10=80,20=60,30=44,40=36,50=28,60=22,70=18
;	      个位:12小字号,34标准字号. 奇数宽减为3/4,偶数高减为3/4
;	`@<或>`       纵扩字双向或单向打印
;	`@-或=`       多行字型空行走纸一行(`@-`,默认)或多行(`@=`)
;	`"0~7`        颜色(仅彩色打印机有效)
;	`&1~255`      设置行距(默认以1/120英寸为单位)
;	`&A或B`       A-设置行距单位1/180,B-设置1/120英寸
;	`&C或D'       设置为行间距:C-1/180英寸,D-1/120英寸.此时可用负数
;	`^0~255`      设置字符间距(打印针列)
;	`#0~65535`    设置页长(单位:点.默认0)
;	`##`	      强制换页(在设置为行间距时 `E` 也可强制换页)
;	`*0~32767`    设置页间空(单位:点)
;	`[0~2447`     设置左边空(单位:点列)
;	`]1~2447`     设置行宽(单位:点列)
;	`|1~2447`     水平定位(打印针列)
;	`~列数`       输出空列(一次有效.打印针列)
;	`%0~7`	      设置背景(0无,1网点,2网格,3横线,4竖线,5右斜线,6左斜线,7交叉线
;	`:`	      初始化打印参数,取消居中设置的功能.若原排版则打印末页页号
;	`'版号,页号`  设置排版:取消软回车、行禁则、打印页号初值1、多行字空行空多行
;		      有版号则按排版参数设置页长、左空和行宽,否则保持原值(需重新设置)
;		      版号后有页号则设置初始打印页号(默认1.=0不打页号,=65535连续打印)
;	`[[空格数`    段排版第二行后行首加空格数
;	`,`	      本行居中		      `,,`    本行居右
;	`$.....$`     直送打印机	      `(`     左旋90度
;	`.`	      暂停打印		      `)`     右旋90度
;	`<或>`	      双或单向打印	      `((`    左旋180度(倒转)
;	`;`	      抽点(轻打)	      `))`    右旋180度(倒转)
;	`\`	      反白		      `?`     停止旋转
;	`/`	      上划线		      `+`     上标字符
;	`_`	      下划线		      `-`     下标字符
;	`=`	      正常(清以上四项)	      `!`     正常字符

D_END	EQU	$

SEG_A		ENDS
		END	START

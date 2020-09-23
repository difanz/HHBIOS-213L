;	ZZ.ASM (2.13L)
;	1995.6.30, 7.27, 8.14,9.11, 11.1
;	1997.7.5
DATE	EQU	'1999.11.30'

CSEG		SEGMENT
		ASSUME	CS:CSEG, DS:CSEG

		ORG	100H
START:		JMP	BEGIN

D_C1		DB	12		;有点色
D_C2		DB	1		;无点色
D_A		DB	0		;键入码
D_B		DB	0		;功能键序号
D_C		DB	0		;=1删点,=2写点
D_D		DW	1		;重复次数
D_D1		DW	1		;重复次数
D_X		DW	0		;点阵坐标(逻辑)
D_Y		DW	0
D_AX		DW	0		;横向点
D_AY		DW	0		;纵向点
D_N		DW	0		;字库每字字节数
D_H		DW	0		;每点高
D_K		DW	0		;每点宽

D_XSZT		DW	OFFSET D_ZTS	;字体显示地址
D_ZTS		DB	'宋体仿宋黑体楷体图形繁体简体字符打印'
D_ZT		DB	'S'             ;'SFHKTJFZD0123'
A_ZT		DW	0		;字体名写入地址
D_DZXS		DB	'    ',0        ;点阵 16,24,32,40,KZZF,ZF24,R24
D_DZ		DB	0		;      1  2  3	4  5	6   7
D_TOP		DW	0		;文件头字节数
D_FA		DW	OFFSET D_FAS
D_FAS		DB	'旋  转块操作压  缩平  移'
D_XSX		DB	'X=  ',0
D_XSY		DB	'Y=  ',0
D_XD		DB	'写点',0
D_SD		DB	'删点',0
D_ZZ		DB	'造字',0
D_MSG		DB	'F1__读  字 F2__存  字',0
		DB	'F3__叠  加 F4__旋  转',0
		DB	'F5__块操作 F6__压  缩',0
		DB	'F7__平  移 F8__选点阵',0
		DB	'F9__清  屏 F10_退  出',0
		DB	'INS_写  点 DEL_删  点',0
		DB	'ESC_移光标 0_字库转换',0
		DB	'1~9_比例因子  [ 1 ]  ',0
		DB	'S_宋体 F_仿宋 T_图形 ',0
		DB	'H_黑体 K_楷体 E_繁体 ',0,0
D_SELECT	DB	'请选择点阵(1-16,2-24,3-32,4-40,5-KZZF,6-ZF24,7-R24): ',0
D_SELEHZK	DB	'选择字体:',0
D_QDZ		DB	'Y-清点,Q-恢复,F-反转:',0
D_QUIT		DB	'退出(Y/N)? ',0
NOFILE		DB	'没找到该字库!',0
NOHZXT		DB	'NO CHINESE SYSTEM!',7,13,10,'$'
F_FILE		DW	0
F_KZZF		DB	'KZZF',0
F_ZF24		DB	'ZF24.COM',0
F_R24		DB	'READ24.COM',0

D_BUF		DB	180 DUP(0)		;读写盘缓冲区
D_A000		DW	0			;显示缓冲区段
D_XSFS		DB	12H			;显示方式
D_ZJXP		DB	0			;=4直接写屏

D_FILE		DB	64 DUP(0)		;文件名
D_HAN		DW	0			;文件号

D_HZ		DB	'读 汉字: ',0
D_ZF		DB	'读 字符码(16进制): ',0
D_CQW		DB	'存 '
D_QW		DB	'区位: 0000',0
D_INPUT 	DB	5 DUP(0)
D_Q		DB	0			;区
D_W		DB	0,0			;位
D_GNJ		DB	0			;功能键码

MSG		DB	'2.13L 汉字系统 造字程序 ',DATE,13,10
		DB	'格式: ZZ [n][F:路径][/W][/?]',13,10
		DB	'其中: n 选择字库: 1-16,2-24,3-32,4-40,5-KZZF,6-ZF24,7-R24',13,10
		DB	'      /F:路径 处理指定路径的字库',13,10
		DB	'      /W 处理当前目录字库(缺省:2.13L系统安装目录)',13,10
		DB	'      /? 显示命令行参数说明',13,10,'$'
D_WW		DB	0			;='W'处理当前目录字库
						;='F'处理指定路径字库
A_WW		DW	0			;文件名写入地址
;程序开始执行****************************************************************
BEGIN:
		MOV	SI,80H
		LODSB
		OR	AL,AL
		JZ	L_10
L_1:
		LODSB
		CMP	AL,' '
		JZ	L_1
		CMP	AL,0DH			;结束?
		JZ	L_10
		CMP	AL,'/'                  ;开关符?
		JNZ	L_1
		LODSB
		CMP	AL,'?'                  ;<显示帮助>
		JNZ	L_2
		MOV	DX,OFFSET MSG		;帮助
		JMP	L_ERR
L_2:
		AND	AL,5FH
		CMP	AL,'W'                  ;处理当前目录字库
		JNZ	L_3
		MOV	D_WW,AL
		JMP	SHORT L_1
L_3:
		CMP	AL,'F'                  ;处理指定路径的字库
		JNZ	L_1
		MOV	D_WW,AL
		LODSB			;':'
		MOV	DI,OFFSET D_FILE
L_4:
		LODSB				;传送路径
		CMP	AL,' '
		JBE	L_5
		STOSB
		JMP	SHORT L_4
L_5:
		MOV	AL,'\'
		STOSB
		MOV	A_WW,DI 		;保存文件名写入地址
		JMP	L_1
L_10:
		XOR	BP,BP
		MOV	AX,1406H		;取显示参数
		INT	10H
		OR	BP,BP			;判安装汉字系统?
		JNZ	L_50
		MOV	DX,OFFSET NOHZXT	;'NO CHINESE SYSTEM!'
L_ERR:
		MOV	AH,9
		INT	21H
		INT	20H
L_50:
		MOV	D_A000,BP		;显示缓冲区段
		MOV	D_XSFS,AL
		MOV	D_ZJXP,BL
		CALL	S_CLS			;清屏

		MOV	SI,OFFSET D_MSG 	;显示功能键表
		MOV	DX,53AH 		;位置
		MOV	BX,1EH
L_80:
		CMP	BYTE PTR [SI],0
		JZ	L_100
		PUSH	DX
		CALL	S_XSZF			;显示字符串
		POP	DX
		INC	DH
		JMP	SHORT L_80
;{选择点阵}------------------------------------------------------------------
L_100:
		MOV	D_ZT,'S'
		MOV	AL,DS:[5EH]		;指定字体
		CMP	AL,' '
		JZ	L_110
		AND	AL,5FH
		MOV	D_ZT,AL
L_110:
		MOV	AL,DS:[5DH]		;指定点阵号
		CMP	AL,' '
		JZ	L_180
		JMP	L_184
L_180:
		MOV	SI,OFFSET D_SELECT
		MOV	DX,1700H
		MOV	BX,1FH
		CALL	S_XSZF			;显示
		MOV	AX,0E08H
		INT	10H
L_181:
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		XOR	AH,AH			;选择点阵
		INT	16H
		PUSH	AX
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		POP	AX

		CMP	AL,0DH			;<回车>
		JZ	L_183
		CMP	AL,1BH			;<ESC>
		JNZ	L_184
L_183:
		CALL	S_CLS			;清屏
		MOV	AX,4C00H		;退出
		INT	21H
L_184:
;<设置各点阵参数>
		CMP	AL,'5'                  ;KZZF?
		JNZ	L_184A
		MOV	CX,'ZK'
		MOV	DX,'FZ'
		MOV	F_FILE,OFFSET F_KZZF
		MOV	D_XSZT,OFFSET D_ZTS+28
		MOV	D_ZT,'Z'
		MOV	D_AX,7
		MOV	D_AY,15
		MOV	D_N,16
		JMP	SHORT L_184C
L_184A:
		CMP	AL,'1'                  ;16点阵
		JNZ	L_185
		MOV	CX,'1 '
		MOV	DX,' 6'
		MOV	D_XSZT,OFFSET D_ZTS+24
		CMP	D_ZT,'F'
		JNZ	L_184B
		MOV	D_XSZT,OFFSET D_ZTS+20
L_184B:
		MOV	D_ZT,0
		MOV	D_AX,15
		MOV	D_AY,15
		MOV	D_N,32
L_184C:
		MOV	D_K,2			;点宽
		MOV	D_H,16			;点高
		CMP	D_XSFS,10H
		JNZ	L_184D
		MOV	D_H,12
L_184D:
		JMP	L_191
L_185:
		CMP	AL,'6'                  ;DY:ZF24
		JNZ	L_185A
		MOV	CX,'FZ'
		MOV	DX,'42'
		MOV	F_FILE,OFFSET F_ZF24
		JMP	SHORT L_185C
L_185A:
		CMP	AL,'7'                  ;DY:R24
		JNZ	L_186
		MOV	CX,'2R'
		MOV	DX,' 4'
		MOV	F_FILE,OFFSET F_R24
L_185C:
		MOV	D_XSZT,OFFSET D_ZTS+32
		MOV	D_ZT,'3'
		MOV	D_AX,11
		MOV	D_AY,23
		MOV	D_N,36
		JMP	L_184C
L_186:
		MOV	D_XSZT,OFFSET D_ZTS
		CMP	D_ZT,'S'
		JZ	L_186A
		ADD	D_XSZT,4
		CMP	D_ZT,'F'
		JZ	L_186A
		ADD	D_XSZT,4
		CMP	D_ZT,'H'
		JZ	L_186A
		ADD	D_XSZT,4
		CMP	D_ZT,'K'
		JZ	L_186A
		ADD	D_XSZT,4
L_186A:
		CMP	AL,'2'
		JNZ	L_188
		MOV	CX,'2 '
		MOV	DX,' 4'
		MOV	D_AX,23
		MOV	D_AY,23
		MOV	D_N,72
		MOV	D_H,16			;点高
		CMP	D_XSFS,10H
		JNZ	L_187
		MOV	D_H,12
L_187:
		MOV	D_K,2			;点宽
		JMP	L_191
L_188:
		MOV	D_K,1			;点宽
		CMP	AL,'3'
		JNZ	L_189
		MOV	CX,'3 '
		MOV	DX,' 2'
		MOV	D_AX,31
		MOV	D_AY,31
		MOV	D_N,128
		MOV	D_H,12			;点高
		CMP	D_XSFS,10H
		JNZ	L_191
		MOV	D_H,8
		JMP	SHORT L_191
L_189:
		CMP	AL,'4'
		JNZ	L_190
		MOV	CX,'4 '
		MOV	DX,' 0'
		MOV	D_AX,35
		MOV	D_AY,39
		MOV	D_N,180
		MOV	D_H,10			;点高
		CMP	D_XSFS,12H
		JZ	L_191
		MOV	D_H,8
		JMP	SHORT L_191
L_190:
		MOV	AX,0E07H
		INT	10H
		JMP	L_181
L_191:
		MOV	D_DZ,AL
		MOV	WORD PTR D_DZXS,CX
		MOV	WORD PTR D_DZXS+2,DX

		MOV	DX,1700H
		MOV	CX,60
		CALL	S_QP			;清

		MOV	AX,600H 		;局部清屏
		XOR	BX,BX
		MOV	CX,8
		MOV	DX,1638H
		INT	10H
;{打开字库}------------------------------------------------------------------
;<取2.13L安装路径>---
L_200:
		PUSH	CS
		POP	ES
		MOV	DI,OFFSET D_FILE	;文件名保存区
		CMP	D_WW,'W'                ;判处理当前目录字库?
		JZ	L_206
		CMP	D_WW,'F'                ;判处理指定路径字库?
		JNZ	L_201
		MOV	DI,A_WW 	;取出文件名写入地址
		JMP	SHORT L_206
L_201:
		MOV	AH,2FH			;取2.13L安装路径BP:DX
		INT	16H
		MOV	DS,BP
		MOV	SI,DX
		MOV	DI,OFFSET D_FILE	;文件名保存区
L_202:
		LODSB
		OR	AL,AL
		JZ	L_204
		STOSB
		JMP	SHORT L_202
L_204:
		MOV	AL,'\'
		STOSB
		PUSH	CS
		POP	DS
L_206:
		CMP	D_DZ,'5'                ;<5为各点阵字库
		JB	L_208
		MOV	SI,F_FILE		;指定文件名首
L_207:
		LODSB
		OR	AL,AL
		JZ	L_210
		STOSB
		JMP	SHORT L_207
L_208:
		MOV	AL,'H'
		STOSB
		MOV	AL,'Z'
		STOSB
		MOV	AL,'K'
		STOSB

		MOV	AX,WORD PTR D_DZXS+1	;点阵
		STOSW
		MOV	A_ZT,DI
L_209:
		MOV	AL,D_ZT 		;字体字符
		STOSB
L_210:
		XOR	AL,AL
		STOSB
;<打开字库文件>-
		MOV	BX,D_HAN		;取原文件号
		OR	BX,BX
		JZ	L_211
		MOV	AH,3EH			;关闭文件
		INT	21H
L_211:
		MOV	DX,173CH		;位置
		MOV	CX,13
		CALL	S_QP			;清字符串

		MOV	DX,OFFSET D_FILE	;文件名
		MOV	AX,3D02H		;打开文件
		INT	21H
		JNB	L_212
		MOV	SI,OFFSET NOFILE	;'没找到该字库!'
		MOV	DX,173CH		;位置
		MOV	BX,1EH
		CALL	S_XSZF
		XOR	AX,AX
L_212:
		MOV	D_HAN,AX

		MOV	D_TOP,0
		CMP	D_DZ,'6'                ;ZF24?
		JNZ	L_213
		MOV	AX,90H
		JMP	SHORT L_214
L_213:
		JB	L_215
		MOV	BX,AX
		XOR	CX,CX
		MOV	DX,10CH
		MOV	AX,4200H
		INT	21H
		MOV	DX,OFFSET D_BUF
		MOV	CX,2
		MOV	AH,3FH
		INT	21H
		MOV	AX,WORD PTR D_BUF
		SUB	AX,100H
L_214:
		MOV	D_TOP,AX
L_215:
;<屏幕显示>-----
		MOV	SI,OFFSET D_ZZ		;'造字'
		XOR	DX,DX
		MOV	BX,4EH
		CALL	S_XSZF
		MOV	SI,OFFSET D_DZXS	;点阵数
		MOV	DX,100H
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	BP,D_XSZT		;显示字体名
		MOV	DX,200H
		MOV	BX,5EH
		MOV	CX,4
		MOV	AX,1300H
		INT	10H

		XOR	AX,AX
		MOV	D_B,AL			;初始化
		MOV	D_X,AX
		MOV	D_Y,AX
		MOV	AL,D_C2
		MOV	DI,OFFSET D_DUP
		MOV	CX,36*40
		REP	STOSB			;清
		CALL	S_XSDZ
;按键------------------------------------------------------------------------
L_300:
		CALL	S_XY			;显示光标位置
		CALL	S_XSGB
L_301:
		MOV	AH,1			;判按键?
		INT	16H
		JZ	L_301
		CALL	S_XSGB
		XOR	AH,AH			;取键
		INT	16H
;[ESC]-清命令----------------------------------------------------------------
		CMP	AL,1BH			;<ESC>
		JNZ	L_320
		MOV	D_B,0
		MOV	DX,700H
		MOV	CX,6
		CALL	S_QP			;清命令提示
L_310:
		MOV	D_C,0
		MOV	DX,500H
		MOV	CX,4
		CALL	S_QP			;清命令提示
		JMP	L_300
L_320:
		MOV	DX,D_D
		MOV	D_D1,DX
;[0]-选择字库----------------------------------------------------------------
		CMP	AL,'0'                  ;<选择字库>
		JZ	L_450
		JMP	L_330
L_450:
		MOV	SI,OFFSET D_SELEHZK	;'选择字体:'
		MOV	DX,133CH
		MOV	BX,1EH
		CALL	S_XSZF
L_451:
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		XOR	AH,AH			;键入
		INT	16H
		PUSH	AX
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		POP	AX

		CMP	AL,0DH			;<回车>
		JNZ	L_452
		MOV	DX,133CH
		MOV	CX,9
		CALL	S_QP
		JMP	L_300
L_452:
		CMP	D_DZ,'4'
		JBE	L_452A
		MOV	D_ZT,AL
		JMP	L_300
L_452A:
		AND	AL,5FH			;小写变大写
		MOV	D_ZT,AL

		CMP	AL,'E'
		JZ	L_453
		CMP	AL,'F'
		JNZ	L_455
		CMP	D_DZ,'1'                ;16点阵?
		JNZ	L_454
L_453:
		MOV	D_XSZT,OFFSET D_ZTS+20	;'繁体'
		JMP	SHORT L_461
L_454:
		MOV	D_XSZT,OFFSET D_ZTS+4	;'仿宋'
		JMP	SHORT L_461
L_455:
		CMP	AL,'J'
		JNZ	L_456
		MOV	D_ZT,0
		MOV	D_XSZT,OFFSET D_ZTS+22	;'简体'
		JMP	SHORT L_461
L_456:
		CMP	AL,'S'
		JNZ	L_457
		MOV	D_XSZT,OFFSET D_ZTS	;'宋体'
		JMP	SHORT L_461
L_457:
		CMP	AL,'H'
		JNZ	L_458
		MOV	D_XSZT,OFFSET D_ZTS+8	;'黑体'
		JMP	SHORT L_461
L_458:
		CMP	AL,'K'
		JNZ	L_459
		MOV	D_XSZT,OFFSET D_ZTS+12	;'楷体'
		JMP	SHORT L_461
L_459:
		CMP	AL,'T'
		JNZ	L_460
		MOV	D_XSZT,OFFSET D_ZTS+16	;'图形'
		JMP	SHORT L_461
L_460:
		MOV	AX,0E07H
		INT	10H
		JMP	L_451
L_461:
		MOV	DX,133CH
		MOV	CX,9
		CALL	S_QP
		MOV	DI,A_ZT 		;字体名写入地址
		JMP	L_209			;打开文件
;[1-9]-选择重复次数----------------------------------------------------------
L_330:
		CMP	AL,'1'
		JB	L_350
		CMP	AL,'9'
		JA	L_350
		AND	AL,0FH
		CBW
		MOV	D_D,AX
		OR	AL,'0'
		MOV	BX,1EH
		MOV	DX,0C4AH
		MOV	AH,2			;定位
		INT	10H
		MOV	CX,1
		MOV	AH,9			;显示
		INT	10H
		JMP	L_300
;[INS]-设置写点--------------------------------------------------------------
L_350:
		CMP	AH,82			;<INS>
		JNZ	L_360
		CMP	D_C,2
		JNZ	L_351
		JMP	L_310
L_351:
		MOV	D_C,2
		MOV	SI,OFFSET D_XD		;'写点'
L_352:
		MOV	DX,500H
		MOV	BX,1EH
		CALL	S_XSZF
		JMP	L_300
;[DEL]-设置删点--------------------------------------------------------------
L_360:
		CMP	AH,83			;<DEL>
		JNZ	L_400
		CMP	D_C,1
		JNZ	L_361
		JMP	L_310
L_361:
		MOV	D_C,1
		MOV	SI,OFFSET D_SD		;'删点'
		JMP	SHORT L_352
;[F4]-[F7]处理---------------------------------------------------------------
L_400:
		CMP	AH,62			;F4
		JB	L_600
		CMP	AH,65			;F7
		JA	L_600
		SUB	AH,58
		MOV	D_B,AH
		MOV	AL,AH
		SUB	AL,4
		MOV	AH,6
		MUL	AH
		ADD	AX,OFFSET D_FAS
		MOV	BP,AX
		MOV	DX,700H
		MOV	CX,6
		MOV	BX,1EH
		MOV	AX,1300H
		INT	10H
		JMP	L_300
;[F1]-读点阵,[F3]-叠加-------------------------------------------------------
L_600:
		CMP	AH,59			;F1
		JZ	L_601
		CMP	AH,61			;F3
		JZ	L_601
		JMP	L_900
L_601:
		MOV	D_GNJ,AH		;保存

		MOV	DX,143H
		MOV	CX,2
		CALL	S_QP

		CMP	D_DZ,'4'
		JBE	L_601A
		MOV	SI,OFFSET D_ZF		;'读 字符码(16进制):'
		MOV	DX,131H
		JMP	SHORT L_601B
L_601A:
		MOV	SI,OFFSET D_HZ		;'读 汉字：'
		MOV	DX,13AH
L_601B:
		MOV	BX,1EH
		CALL	S_XSZF
;<键入汉字>-----
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		XOR	AH,AH			;键入
		INT	16H
		PUSH	AX
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		POP	AX
		CMP	AL,'-'                  ;上一汉字?
		JZ	L_604A
		CMP	AL,' '                  ;下一汉字?
		JB	L_602A			;包括回车等
		JNZ	L_601C
		JMP	L_604
L_601C:
		CMP	AL,0A0H 		;字符?
		JBE	L_602
		CMP	D_DZ,'1'                ;判16点阵?
		JZ	L_603
		CMP	D_ZT,'T'
		JNZ	L_603A
		CMP	AL,0B0H 		;判汉字?
		JB	L_603
L_602:
		CMP	D_DZ,'4'
		JA	L_603
L_602A:
		MOV	AX,0E07H
		INT	10H
		JMP	L_300
L_603A:
		CMP	AL,0B0H 		;判汉字?
		JB	L_602
L_603:
		MOV	D_Q,AL
		XOR	AH,AH			;取汉字后字节
		INT	16H
		MOV	D_W,AL
		JMP	L_605
L_604A:
		CMP	D_W,0
		JZ	L_602A
		CMP	D_DZ,'4'
		JA	L_604D
		DEC	D_W			;位号-1
		CMP	D_W,0A0H		;<1
		JA	L_604E
		MOV	D_W,0FEH		;=94
		DEC	D_Q			;区号-1
		CMP	D_DZ,'1'                ;判16点阵?
		JZ	L_604B
		CMP	D_Q,0B0H		;判16区?
		JAE	L_604E
		JMP	SHORT L_604C
L_604B:
		CMP	D_Q,0A0H		;判<1区
		JA	L_604E
L_604C:
		MOV	D_Q,0FEH		;=94区
		JMP	SHORT L_605
L_604D:
		MOV	AL,D_W
		CALL	S_DEC
		MOV	D_W,AL
		CMP	AL,'F'
		JNZ	L_604E
		MOV	AL,D_Q
		CALL	S_DEC
		MOV	D_Q,AL
L_604E:
		JMP	L_605
L_604F:
		MOV	AL,D_W
		CALL	S_INC
		MOV	D_W,AL
		CMP	AL,'0'
		JNZ	L_604E
		MOV	AL,D_Q
		CALL	S_INC
		MOV	D_Q,AL
		JMP	SHORT L_604E
L_604:
		CMP	D_W,0
		JNZ	L_6040
		JMP	L_602A
L_6040:
		CMP	D_DZ,'4'
		JA	L_604F
		INC	D_W			;位号+1
		CMP	D_W,0FFH		;=95
		JB	L_605
		MOV	D_W,0A1H		;=1
		INC	D_Q			;区号+1
		CMP	D_Q,0FFH		;=95
		JB	L_605
		MOV	D_Q,0A1H		;=1
		CMP	D_DZ,'1'                ;判16点阵?
		JZ	L_605
		MOV	D_Q,0B0H		;=16
L_605:
		MOV	SI,OFFSET D_Q		;显示所选汉字
		MOV	DX,143H
		MOV	BX,4EH
		CALL	S_XSZF
		CMP	D_DZ,'4'
		JA	L_606
;<显示区位>-----
		MOV	CL,10
		MOV	AL,D_Q
		SUB	AL,0A0H 		;得区号
		CBW
		DIV	CL
		OR	AX,3030H
		MOV	WORD PTR D_QW+6,AX
		MOV	AL,D_W
		SUB	AL,0A0H 		;得位号
		CBW
		DIV	CL
		OR	AX,3030H
		MOV	WORD PTR D_QW+8,AX

		MOV	SI,OFFSET D_QW		;'区位:????'
		MOV	DX,23DH
		MOV	BX,1EH
		CALL	S_XSZF
;<读字库>-------
L_606:
		CALL	S_800			;计算位置

		MOV	BX,D_HAN		;文件号
		MOV	CX,DX
		MOV	DX,AX
		MOV	AX,4200H		;定位
		INT	21H
		MOV	DX,OFFSET D_BUF
		MOV	SI,DX
		MOV	CX,D_N
		MOV	AH,3FH			;读字库
		INT	21H
		OR	AX,AX			;读出字节数
		JNZ	L_607
		JMP	L_602A			;响铃并JMP L_300
;<点阵转换>-----
L_607:
		MOV	DI,OFFSET D_DUP 	;点阵区
		CMP	D_GNJ,59		;F1?
		JZ	L_608
		MOV	DI,OFFSET D_DUP1	;叠加区
L_608:
		MOV	DH,D_C1 		;有点色
		MOV	DL,D_C2 		;无点色

		CMP	D_DZ,'5'                ;KZZF?
		JNZ	L_610
		MOV	CX,16
		JMP	SHORT L_611
L_610:
		CMP	D_DZ,'1'                ;16点阵?
		JNZ	L_620
		MOV	CX,32
L_611:
		LODSB
		MOV	AH,8
L_612:
		SHL	AL,1
		JC	L_613
		MOV	[DI],DL
		JMP	SHORT L_614
L_613:
		MOV	[DI],DH
L_614:
		INC	DI
		DEC	AH
		JNZ	L_612
		LOOP	L_611
		JMP	L_650
L_620:
		CMP	D_DZ,'6'                ;ZF24?
		JB	L_620A
		MOV	CX,12
		JMP	SHORT L_620B
L_620A:
		CMP	D_DZ,'2'                ;24点阵?
		JNZ	L_630
		MOV	CX,24
L_620B:
		MOV	BP,CX
L_621:
		XOR	BX,BX
		MOV	CH,3
L_622:
		LODSB
		MOV	AH,8
L_623:
		SHL	AL,1
		JC	L_624
		MOV	[BX+DI],DL
		JMP	SHORT L_625
L_624:
		MOV	[BX+DI],DH
L_625:
		ADD	BX,BP
		DEC	AH
		JNZ	L_623
		DEC	CH
		JNZ	L_622
		INC	DI
		DEC	CL
		JNZ	L_621
		JMP	L_650
L_630:
		CMP	D_DZ,'3'                ;32点阵?
		JNZ	L_640
		MOV	CX,32
L_631:
		XOR	BX,BX
		LODSB
		MOV	AH,8
L_632:
		SHL	AL,1
		JC	L_633
		MOV	[BX+DI],DL
		JMP	SHORT L_634
L_633:
		MOV	[BX+DI],DH
L_634:
		ADD	BX,32
		DEC	AH
		JNZ	L_632
		INC	DI
		LOOP	L_631

		MOV	CX,32
		ADD	DI,7*32
L_635:
		XOR	BX,BX
		MOV	BP,3
L_636:
		LODSB
		MOV	AH,8
L_637:
		SHL	AL,1
		JC	L_638
		MOV	[BX+DI],DL
		JMP	SHORT L_639
L_638:
		MOV	[BX+DI],DH
L_639:
		ADD	BX,32
		DEC	AH
		JNZ	L_637
		DEC	BP
		JNZ	L_636
		INC	DI
		LOOP	L_635
		JMP	L_650
L_640:						;40点阵
		MOV	CX,36
L_640A:
		XOR	BX,BX
		MOV	BP,2
L_641:
		LODSB
		MOV	AH,8
L_642:
		SHL	AL,1
		JC	L_643
		MOV	[BX+DI],DL
		JMP	SHORT L_644
L_643:
		MOV	[BX+DI],DH
L_644:
		ADD	BX,36
		DEC	AH
		JNZ	L_642
		DEC	BP
		JNZ	L_641
		INC	DI
		LOOP	L_640A

		MOV	CX,36
		ADD	DI,15*36
L_645:
		XOR	BX,BX
		MOV	BP,3
L_646:
		LODSB
		MOV	AH,8
L_647:
		SHL	AL,1
		JC	L_648
		MOV	[BX+DI],DL
		JMP	SHORT L_649
L_648:
		MOV	[BX+DI],DH
L_649:
		ADD	BX,36
		DEC	AH
		JNZ	L_647
		DEC	BP
		JNZ	L_646
		INC	DI
		LOOP	L_645
;<处理叠加>-----
L_650:
		MOV	AX,D_N			;每字字节数
		CMP	D_GNJ,61		;F3?
		JNZ	L_750
		MOV	AH,8
		MUL	AH
		MOV	CX,AX
		MOV	SI,OFFSET D_DUP
		MOV	DI,OFFSET D_DUP1
		MOV	AL,D_C1
L_652:
		CMP	[SI],AL
		JZ	L_653
		CMP	[DI],AL
		JNZ	L_653
		MOV	[SI],AL
L_653:
		INC	SI
		INC	DI
		LOOP	L_652
;<显示点阵>-----
L_750:
		CALL	S_XSDZ
		JMP	L_300
;[F2]-存盘-------------------------------------------------------------------
L_900:
		CMP	AH,60			;<F2>
		JZ	L_901
		JMP	L_960
L_901:
		MOV	AX,'  '
		MOV	WORD PTR D_QW+6,AX
		MOV	WORD PTR D_QW+8,AX
		MOV	BP,OFFSET D_CQW 	;'存 区位: '
		MOV	DX,33AH
		MOV	CX,13
		MOV	BX,1EH
		MOV	AX,1300H		;显示
		INT	10H
		MOV	DX,343H
		MOV	AH,2
		INT	10H

		CMP	D_DZ,'5'                ;KZZF?
		JB	L_901C
		MOV	CX,2
		CALL	S_IN16			;键入十六进制数->BX
		OR	BX,BX
		JNZ	L_901A
		JMP	L_300
L_901A:
		CMP	D_DZ,'6'                ;ZF24?
		JNZ	L_901B
		CMP	BX,32
		JB	L_901B
		MOV	AL,D_ZT
		AND	AL,0FH
		MOV	AH,96
		MUL	AH
		ADD	BX,AX
L_901B:
		MOV	AX,BX
		MUL	D_N
		CMP	D_DZ,'5'
		JZ	L_902A
		ADD	AX,D_TOP
		ADC	DX,0
		JMP	SHORT L_902A
L_901C:
		MOV	CX,4
		CALL	S_INPUT 		;键入数字串
		OR	BX,BX
		JNZ	L_902
		JMP	L_300
L_902:
		MOV	AX,BX
		XOR	DX,DX
		MOV	BX,100
		DIV	BX
		MOV	DH,AL			;区号,DL=位号
;<文件定位>-----
		CALL	S_800A			;转换为字库中位置
L_902A:
		MOV	BX,D_HAN		;文件号
		MOV	CX,DX
		MOV	DX,AX
		MOV	AX,4200H		;定位
		INT	21H
;<点阵转换>-----
		MOV	SI,OFFSET D_DUP
		MOV	DI,OFFSET D_BUF

		CMP	D_DZ,'5'                ;KZZF?
		JNZ	L_910
		MOV	CX,16
		JMP	SHORT L_911
L_910:
		CMP	D_DZ,'1'                ;16点阵?
		JNZ	L_920
		MOV	CX,32
L_911:
		MOV	DX,8
L_912:
		LODSB
		CLC
		CMP	AL,D_C2 		;无点?
		JZ	L_913
		STC
L_913:
		RCL	DH,1
		DEC	DL
		JNZ	L_912
		MOV	AL,DH
		STOSB
		LOOP	L_911
		JMP	L_950
L_920:
		CMP	D_DZ,'6'                ;ZF24?
		JB	L_920A
		MOV	CX,12
		JMP	SHORT L_920B
L_920A:
		CMP	D_DZ,'2'                ;24点阵?
		JNZ	L_930
		MOV	CX,24
L_920B:
		MOV	BP,CX
L_921:
		XOR	BX,BX
		MOV	CH,3
L_922:
		MOV	DX,8
L_923:
		MOV	AL,[BX+SI]
		CLC
		CMP	AL,D_C2 		;无点?
		JZ	L_924
		STC
L_924:
		RCL	DH,1
		ADD	BX,BP
		DEC	DL
		JNZ	L_923
		MOV	AL,DH
		STOSB
		DEC	CH
		JNZ	L_922
		INC	SI
		DEC	CL
		JNZ	L_921
		JMP	L_950
L_930:
		CMP	D_DZ,'3'                ;32点阵?
		JNZ	L_940
		MOV	CX,32
L_931:
		XOR	BX,BX
		MOV	DX,8
L_932:
		MOV	AL,[BX+SI]
		CLC
		CMP	AL,D_C2 		;无点?
		JZ	L_933
		STC
L_933:
		RCL	DH,1
		ADD	BX,32
		DEC	DL
		JNZ	L_932
		MOV	AL,DH
		STOSB
		INC	SI
		LOOP	L_931

		ADD	SI,7*32
		MOV	CX,24
L_934:
		XOR	BX,BX
		MOV	BP,3
L_935:
		MOV	DX,8
L_936:
		MOV	AL,[BX+SI]
		CLC
		CMP	AL,D_C2 		;无点?
		JZ	L_937
		STC
L_937:
		RCL	DH,1
		ADD	BX,24
		DEC	DL
		JNZ	L_936
		MOV	AL,DH
		STOSB
		DEC	BP
		JNZ	L_935
		INC	SI
		LOOP	L_934
		JMP	L_950
L_940:						;40点阵
		MOV	CX,36
L_941:
		MOV	BP,2
		XOR	BX,BX
L_942:
		MOV	DX,8
L_943:
		MOV	AL,[BX+SI]
		CLC
		CMP	AL,D_C2 		;无点?
		JZ	L_944
		STC
L_944:
		RCL	DH,1
		ADD	BX,36
		DEC	DL
		JNZ	L_943
		MOV	AL,DH
		STOSB
		DEC	BP
		JNZ	L_942
		INC	SI
		LOOP	L_941
		ADD	SI,15*36
		MOV	CX,36
L_945:
		MOV	BP,3
		XOR	BX,BX
L_946:
		MOV	DX,8
L_947:
		MOV	AL,[BX+SI]
		CLC
		CMP	AL,D_C2 		;无点?
		JZ	L_948
		STC
L_948:
		RCL	DH,1
		ADD	BX,36
		DEC	DL
		JNZ	L_947
		MOV	AL,DH
		STOSB
		DEC	BP
		JNZ	L_946
		INC	SI
		LOOP	L_945
;<存文件>-------
L_950:
		MOV	BX,D_HAN		;文件号
		MOV	DX,OFFSET D_BUF
		MOV	CX,D_N			;每字字节数
		MOV	AH,40H
		INT	21H
		JMP	L_300
;{选点阵}--------------------------------------------------------------------
L_960:
		CMP	AH,66			;F8?
		JNZ	L_970
		MOV	D_ZT,'S'
		CMP	D_DZ,'5'                ;KZZF?
		JAE	L_962
		MOV	DX,13AH
		MOV	CX,12
		JMP	SHORT L_964
L_962:
		MOV	DX,131H
		MOV	CX,20
L_964:
		CALL	S_QP
		JMP	L_180
;{清点阵}--------------------------------------------------------------------
L_970:
		CMP	AH,67			;F9?
		JNZ	L_980
		MOV	SI,OFFSET D_QDZ 	;'Y-清点阵,Q-恢复:'
		MOV	DX,153AH
		MOV	BX,1EH
		CALL	S_XSZF
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		XOR	AH,AH
		INT	16H
		PUSH	AX
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		MOV	DX,153AH
		MOV	CX,26
		CALL	S_QP
		POP	AX
		AND	AL,5FH
		CMP	AL,'Y'                  ;清点阵?
		JNZ	L_1702
		MOV	DI,OFFSET D_DUP
		MOV	AX,D_AX
		INC	AX
		MOV	BX,D_AY
		INC	BX
		MUL	BX
		MOV	CX,AX
		MOV	AL,D_C2
		REP	STOSB
L_1700:
		CALL	S_XSDZ
L_1701:
		JMP	L_300
L_1702:
		CMP	AL,'Q'                  ;恢复原字点阵?
		JNZ	L_1703
		MOV	SI,OFFSET D_BUF
		JMP	L_607
L_1703:
		CMP	AL,'F'                  ; 'F'
		JNZ	L_1701
		MOV	DI,OFFSET D_DUP
		MOV	AX,D_AX
		INC	AX
		MOV	BX,D_AY
		INC	BX
		MUL	BX
		MOV	CX,AX
L_1704:
		MOV	AL,D_C1
		CMP	AL,[DI]
		JNZ	L_1705
		MOV	AL,D_C2
L_1705:
		STOSB
		LOOP	L_1704
		JMP	SHORT L_1700
;{退出}----------------------------------------------------------------------
L_980:
		CMP	AH,68			;F10?
		JNZ	L_1000
		MOV	SI,OFFSET D_QUIT	;'退出(Y/N)?'
		MOV	DX,163AH
		MOV	BX,1EH
		CALL	S_XSZF			;显示
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		XOR	AH,AH			;键入
		INT	16H
		AND	AL,5FH
		CMP	AL,'Y'                  ;判?
		JZ	L_1901
		MOV	DX,163AH
		MOV	CX,11
		CALL	S_QP
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		JMP	L_300
L_1901:
		MOV	BX,D_HAN		;当前文件号
		MOV	AH,3EH			;关闭文件
		INT	21H
		CALL	S_CLS			;清屏
		MOV	AX,4C00H		;退出
		INT	21H
;{移光标}--------------------------------------------------------------------
L_1000:
		CMP	D_B,0
		JZ	L_1001
		JMP	L_1300
L_1001:
		CMP	D_C,0
		JZ	L_1010
		JMP	L_1100
L_1010:
		CMP	AH,72			;↑
		JNZ	L_1020
L_1011:
		DEC	D_Y
		CALL	S_850
		JMP	SHORT L_1011
L_1020:
		CMP	AH,80			;↓
		JNZ	L_1030
L_1021:
		INC	D_Y
		CALL	S_850
		JMP	SHORT L_1021
L_1030:
		CMP	AH,75			;←
		JNZ	L_1040
L_1031:
		DEC	D_X
		CALL	S_850
		JMP	SHORT L_1031
L_1040:
		CMP	AH,77			;→
		JNZ	L_1050
L_1041:
		INC	D_X
		CALL	S_850
		JMP	SHORT L_1041
L_1050:
		CMP	AH,71			;HOME
		JNZ	L_1060
L_1051:
		DEC	D_X
		DEC	D_Y
		CALL	S_850
		JMP	SHORT L_1051
L_1060:
		CMP	AH,79			;END
		JNZ	L_1070
L_1061:
		DEC	D_X
		INC	D_Y
		CALL	S_850
		JMP	SHORT L_1061
L_1070:
		CMP	AH,73			;PGUP
		JNZ	L_1080
L_1071:
		INC	D_X
		DEC	D_Y
		CALL	S_850
		JMP	SHORT L_1071
L_1080:
		CMP	AH,81			;PGDN
		JNZ	L_1090
L_1081:
		INC	D_X
		INC	D_Y
		CALL	S_850
		JMP	SHORT L_1081
L_1090:
		JMP	L_300
;{删点}----------------------------------------------------------------------
L_1100:
		CMP	D_C,1			;删点
		JZ	L_1110
		JMP	L_1200
L_1110:
		CMP	AH,72			;↑
		JNZ	L_1120
L_1111:
		CALL	S_540
		DEC	D_Y
		CALL	S_850
		JMP	SHORT L_1111
L_1120:
		CMP	AH,80			;↓
		JNZ	L_1130
L_1121:
		CALL	S_540
		INC	D_Y
		CALL	S_850
		JMP	SHORT L_1121
L_1130:
		CMP	AH,75			;←
		JNZ	L_1140
L_1131:
		CALL	S_540
		DEC	D_X
		CALL	S_850
		JMP	SHORT L_1131
L_1140:
		CMP	AH,77			;→
		JNZ	L_1150
L_1141:
		CALL	S_540
		INC	D_X
		CALL	S_850
		JMP	SHORT L_1141
L_1150:
		CMP	AH,71			;HOME
		JNZ	L_1160
L_1151:
		CALL	S_540
		DEC	D_X
		DEC	D_Y
		CALL	S_850
		JMP	SHORT L_1151
L_1160:
		CMP	AH,79			;END
		JNZ	L_1170
L_1161:
		CALL	S_540
		DEC	D_X
		INC	D_Y
		CALL	S_850
		JMP	SHORT L_1161
L_1170:
		CMP	AH,73			;PGUP
		JNZ	L_1180
L_1171:
		CALL	S_540
		INC	D_X
		DEC	D_Y
		CALL	S_850
		JMP	SHORT L_1171
L_1180:
		CMP	AH,81			;PGDN
		JNZ	L_1190
L_1181:
		CALL	S_540
		INC	D_X
		INC	D_Y
		CALL	S_850
		JMP	SHORT L_1181
L_1190:
		JMP	L_300
;{写点}----------------------------------------------------------------------
L_1200:
		CMP	D_C,2			;写点?
		JZ	L_1210
		JMP	L_300
L_1210:
		CMP	AH,72			;↑
		JNZ	L_1220
L_1211:
		CALL	S_530
		DEC	D_Y
		CALL	S_850
		JMP	SHORT L_1211
L_1220:
		CMP	AH,80			;↓
		JNZ	L_1230
L_1221:
		CALL	S_530
		INC	D_Y
		CALL	S_850
		JMP	SHORT L_1221
L_1230:
		CMP	AH,75			;←
		JNZ	L_1240
L_1231:
		CALL	S_530
		DEC	D_X
		CALL	S_850
		JMP	SHORT L_1231
L_1240:
		CMP	AH,77			;→
		JNZ	L_1250
L_1241:
		CALL	S_530
		INC	D_X
		CALL	S_850
		JMP	SHORT L_1241
L_1250:
		CMP	AH,71			;HOME
		JNZ	L_1260
L_1251:
		CALL	S_530
		DEC	D_X
		DEC	D_Y
		CALL	S_850
		JMP	SHORT L_1251
L_1260:
		CMP	AH,79			;END
		JNZ	L_1270
L_1261:
		CALL	S_530
		DEC	D_X
		INC	D_Y
		CALL	S_850
		JMP	SHORT L_1261
L_1270:
		CMP	AH,73			;PGUP
		JNZ	L_1280
L_1271:
		CALL	S_530
		INC	D_X
		DEC	D_Y
		CALL	S_850
		JMP	SHORT L_1271
L_1280:
		CMP	AH,81			;PGDN
		JNZ	L_1290
L_1281:
		CALL	S_530
		INC	D_X
		INC	D_Y
		CALL	S_850
		JMP	SHORT L_1281
L_1290:
		JMP	L_300
;[旋转]----------------------------------------------------------------------
L_1300:
		CMP	D_B,4			;旋转?
		JZ	L_1301
		JMP	L_1400
L_1301:
		CMP	AH,72			;↑:倒转
		JZ	L_1310
		CMP	AH,80			;↓:倒转
		JNZ	L_1330
L_1310:
		XOR	DI,DI
L_1311:
		XOR	SI,SI
		MOV	CX,D_AX 		;横向点数
		SUB	CX,DI
L_1312:
		CALL	S_GETD1
		MOV	BP,BX
		PUSH	DI
		MOV	DI,CX
		CALL	S_GETD1
		POP	DI
		MOV	AL,[BX]
		XCHG	AL,DS:[BP]
		MOV	[BX],AL
		INC	SI
		CMP	SI,D_AX
		JBE	L_1312
		INC	DI
		MOV	AX,D_AX
		SHR	AX,1
		CMP	DI,AX
		JBE	L_1311
		JMP	L_750
L_1330:
		CMP	AH,75			;←:左旋
		JNZ	L_1340
		MOV	DI,1
L_1331:
		XOR	SI,SI
L_1332:
		CALL	S_GETD1
		MOV	BP,BX
		PUSH	SI
		PUSH	DI
		XCHG	SI,DI
		CALL	S_GETD1
		POP	DI
		POP	SI
		MOV	AL,[BX]
		XCHG	AL,DS:[BP]
		MOV	[BX],AL
		INC	SI
		CMP	SI,DI
		JBE	L_1332
		INC	DI
		CMP	DI,D_AX
		JBE	L_1331
		JMP	L_1310
L_1340:
		CMP	AH,77			;→:右旋
		JNZ	L_1350
		XOR	DI,DI
L_1341:
		MOV	CX,D_AX
		SUB	CX,DI
		XOR	SI,SI
L_1342:
		CALL	S_GETD1
		MOV	BP,BX
		PUSH	SI
		PUSH	DI
		XCHG	SI,DI
		MOV	AX,D_AX
		SUB	AX,SI
		MOV	SI,AX
		MOV	AX,D_AX
		SUB	AX,DI
		MOV	DI,AX
		CALL	S_GETD1
		POP	DI
		POP	SI
		MOV	AL,[BX]
		XCHG	AL,DS:[BP]
		MOV	[BX],AL
		INC	SI
		CMP	SI,CX
		JBE	L_1342
		INC	DI
		CMP	DI,D_AX
		JBE	L_1341
		JMP	L_1310
L_1350:
		JMP	L_300
;{块操作}--------------------------------------------------------------------
L_1400:
		CMP	D_B,5			;块操作
		JZ	L_1401
		JMP	L_1500
L_1401:
		CMP	D_C,1			;删点?
		JNZ	L_1402
		MOV	DL,D_C2
		JMP	SHORT L_1410
L_1402:
		MOV	DL,D_C1
		CMP	D_C,2			;写点?
		JZ	L_1410
		JMP	L_602			;响铃并JMP L_100
L_1410:
		CMP	AH,72			;↑
		JNZ	L_1420
		MOV	DI,0
L_1411:
		MOV	SI,0
L_1412:
		CALL	S_GETD1
		MOV	[BX],DL
		INC	SI
		CMP	SI,D_AX
		JBE	L_1412
		INC	DI
		CMP	DI,D_Y
		JBE	L_1411
		JMP	L_750
L_1420:
		CMP	AH,80			;↓
		JNZ	L_1430
		MOV	DI,D_Y
L_1421:
		MOV	SI,0
L_1422:
		CALL	S_GETD1
		MOV	[BX],DL
		INC	SI
		CMP	SI,D_AX
		JBE	L_1422
		INC	DI
		CMP	DI,D_AY
		JBE	L_1421
		JMP	L_750
L_1430:
		CMP	AH,75			;←
		JNZ	L_1440
		MOV	DI,0
L_1431:
		MOV	SI,0
L_1432:
		CALL	S_GETD1
		MOV	[BX],DL
		INC	SI
		CMP	SI,D_X
		JBE	L_1432
		INC	DI
		CMP	DI,D_AY
		JBE	L_1431
		JMP	L_750
L_1440:
		CMP	AH,77			;→
		JNZ	L_1450
		MOV	DI,0
L_1441:
		MOV	SI,D_X
L_1442:
		CALL	S_GETD1
		MOV	[BX],DL
		INC	SI
		CMP	SI,D_AX
		JBE	L_1442
		INC	DI
		CMP	DI,D_AY
		JBE	L_1441
		JMP	L_750
L_1450:
		CMP	AH,71			;HOME
		JNZ	L_1460
		MOV	DI,0
L_1451:
		MOV	SI,0
L_1452:
		CALL	S_GETD1
		MOV	[BX],DL
		INC	SI
		CMP	SI,D_X
		JBE	L_1452
		INC	DI
		CMP	DI,D_Y
		JBE	L_1451
		JMP	L_750
L_1460:
		CMP	AH,79			;END
		JNZ	L_1470
		MOV	DI,D_Y
L_1461:
		MOV	SI,0
L_1462:
		CALL	S_GETD1
		MOV	[BX],DL
		INC	SI
		CMP	SI,D_X
		JBE	L_1462
		INC	DI
		CMP	DI,D_AY
		JBE	L_1461
		JMP	L_750
L_1470:
		CMP	AH,73			;PGUP
		JNZ	L_1480
		MOV	DI,0
L_1471:
		MOV	SI,D_X
L_1472:
		CALL	S_GETD1
		MOV	[BX],DL
		INC	SI
		CMP	SI,D_AX
		JBE	L_1472
		INC	DI
		CMP	DI,D_Y
		JBE	L_1471
		JMP	L_750
L_1480:
		CMP	AH,81			;PGDN
		JNZ	L_1490
		MOV	DI,D_Y
L_1481:
		MOV	SI,D_X
L_1482:
		CALL	S_GETD1
		MOV	[BX],DL
		INC	SI
		CMP	SI,D_AX
		JBE	L_1482
		INC	DI
		CMP	DI,D_AY
		JBE	L_1481
		JMP	L_750
L_1490:
		JMP	L_300
;{压缩}----------------------------------------------------------------------
L_1500:
		CMP	D_B,6			;压缩?
		JZ	L_1501
		JMP	L_1600
L_1501:
		CMP	AH,72			;↑
		JNZ	L_1520
		MOV	DI,0
L_1511:
		MOV	SI,0
L_1512:
		CALL	S_GETD1
		MOV	AL,[BX]
		CMP	AL,D_C1
		JNZ	L_1513
		MOV	AL,D_C2
		MOV	[BX],AL
		PUSH	DI
		MOV	AX,D_D
		MUL	DI
		MOV	BX,10
		DIV	BX
		MOV	DI,AX
		CALL	S_GETD1
		MOV	AL,D_C1
		MOV	[BX],AL
		POP	DI
L_1513:
		INC	SI
		CMP	SI,D_AX
		JBE	L_1512
		INC	DI
		CMP	DI,D_AY
		JBE	L_1511
		JMP	L_750
L_1520:
		CMP	AH,80			;↓
		JNZ	L_1530
		MOV	DI,D_AY
L_1521:
		MOV	SI,0
L_1522:
		CALL	S_GETD1
		MOV	AL,[BX]
		CMP	AL,D_C1
		JNZ	L_1523
		MOV	AL,D_C2
		MOV	[BX],AL
		PUSH	DI
		MOV	AX,D_AY
		SUB	AX,DI
		MUL	D_D
		MOV	BX,10
		DIV	BX
		MOV	BX,D_AY
		SUB	BX,AX
		MOV	DI,BX
		CALL	S_GETD1
		MOV	AL,D_C1
		MOV	[BX],AL
		POP	DI
L_1523:
		INC	SI
		CMP	SI,D_AX
		JBE	L_1522
		DEC	DI
		CMP	DI,0
		JGE	L_1521
		JMP	L_750
L_1530:
		CMP	AH,75			;←
		JNZ	L_1540
		MOV	DI,0
L_1531:
		MOV	SI,0
L_1532:
		CALL	S_GETD1
		MOV	AL,[BX]
		CMP	AL,D_C1
		JNZ	L_1533
		MOV	AL,D_C2
		MOV	[BX],AL
		PUSH	SI
		MOV	AX,D_D
		MUL	SI
		MOV	BX,10
		DIV	BX
		MOV	SI,AX
		CALL	S_GETD1
		MOV	AL,D_C1
		MOV	[BX],AL
		POP	SI
L_1533:
		INC	SI
		CMP	SI,D_AX
		JBE	L_1532
		INC	DI
		CMP	DI,D_AY
		JBE	L_1531
		JMP	L_750
L_1540:
		CMP	AH,77			;→
		JNZ	L_1590
		MOV	DI,0
L_1541:
		MOV	SI,D_AX
L_1542:
		CALL	S_GETD1
		MOV	AL,[BX]
		CMP	AL,D_C1
		JNZ	L_1543
		MOV	AL,D_C2
		MOV	[BX],AL
		PUSH	SI
		MOV	AX,D_AX
		SUB	AX,SI
		MUL	D_D
		MOV	BX,10
		DIV	BX
		MOV	BX,D_AX
		SUB	BX,AX
		MOV	SI,BX
		CALL	S_GETD1
		MOV	AL,D_C1
		MOV	[BX],AL
		POP	SI
L_1543:
		DEC	SI
		CMP	SI,0
		JGE	L_1542
		INC	DI
		CMP	DI,D_AY
		JBE	L_1541
		JMP	L_750
L_1590:
		JMP	L_300
;{平移}----------------------------------------------------------------------
L_1600:
		CMP	D_B,7
		JNZ	L_1590

		CMP	AH,72			;↑
		JNZ	L_1620
		MOV	DI,D_Y
L_1611:
		MOV	SI,0
L_1612:
		CALL	S_GETD1
		MOV	AL,[BX]
		CMP	AL,D_C1
		JNZ	L_1614
		MOV	AL,D_C2
		MOV	[BX],AL
		PUSH	DI
		SUB	DI,D_D
		JNC	L_1613
		XOR	DI,DI
L_1613:
		CALL	S_GETD1
		MOV	AL,D_C1
		MOV	[BX],AL
		POP	DI
L_1614:
		INC	SI
		CMP	SI,D_AX
		JBE	L_1612
		INC	DI
		CMP	DI,D_AY
		JBE	L_1611
		JMP	L_750
L_1620:
		CMP	AH,80			;↓
		JNZ	L_1630
		MOV	DI,D_Y
L_1621:
		MOV	SI,0
L_1622:
		CALL	S_GETD1
		MOV	AL,[BX]
		CMP	AL,D_C1
		JNZ	L_1624
		MOV	AL,D_C2
		MOV	[BX],AL
		PUSH	DI
		ADD	DI,D_D
		CMP	DI,D_AY
		JBE	L_1623
		MOV	DI,D_AY
L_1623:
		CALL	S_GETD1
		MOV	AL,D_C1
		MOV	[BX],AL
		POP	DI
L_1624:
		INC	SI
		CMP	SI,D_AX
		JBE	L_1622
		DEC	DI
		CMP	DI,0
		JGE	L_1621
		JMP	L_750
L_1630:
		CMP	AH,75			;←
		JNZ	L_1640
		MOV	DI,0
L_1631:
		MOV	SI,D_X
L_1632:
		CALL	S_GETD1
		MOV	AL,[BX]
		CMP	AL,D_C1
		JNZ	L_1634
		MOV	AL,D_C2
		MOV	[BX],AL
		PUSH	SI
		SUB	SI,D_D
		JNC	L_1633
		XOR	SI,SI
L_1633:
		CALL	S_GETD1
		MOV	AL,D_C1
		MOV	[BX],AL
		POP	SI
L_1634:
		INC	SI
		CMP	SI,D_AX
		JBE	L_1632
		INC	DI
		CMP	DI,D_AY
		JBE	L_1631
		JMP	L_750
L_1640:
		CMP	AH,77			;→
		JNZ	L_1690
		MOV	DI,0
L_1641:
		MOV	SI,D_X
L_1642:
		CALL	S_GETD1
		MOV	AL,[BX]
		CMP	AL,D_C1
		JNZ	L_1644
		MOV	AL,D_C2
		MOV	[BX],AL
		PUSH	SI
		ADD	SI,D_D
		CMP	SI,D_AX
		JBE	L_1643
		MOV	SI,D_AX
L_1643:
		CALL	S_GETD1
		MOV	AL,D_C1
		MOV	[BX],AL
		POP	SI
L_1644:
		DEC	SI
		CMP	SI,0
		JGE	L_1642
		INC	DI
		CMP	DI,D_AY
		JBE	L_1641
		JMP	L_750
L_1690:
		JMP	L_300

;公用子程序------------------------------------------------------------------
;子程序:写点
S_530		PROC	NEAR
		CALL	S_GETD			;取当前点在DUP区地址BX
		MOV	AL,D_C1
		MOV	[BX],AL
		MOV	BL,D_C1 		;有点色
		JMP	S_XSD			;写点
;子程序:删点
S_540:
		CALL	S_GETD			;取当前点在DUP区地址BX
		MOV	AL,D_C2
		MOV	[BX],AL
		MOV	BL,D_C2 		;无点色
		JMP	S_XSD			;删点
S_530		ENDP

;子程序:处理重复操作
S_850		PROC	NEAR
		CALL	S_860			;处理边界
		CMP	D_D1,1			;重复数=1?
		JNZ	L_851
		POP	AX
		JMP	L_300			;重复操作结束
L_851:
		DEC	D_D1			;重复数-1
		RET
;子程序:处理边界
S_860:
		MOV	AX,D_Y
		CMP	AX,0			;Y<0?
		JGE	L_861
		XOR	AX,AX
		JMP	SHORT L_862
L_861:
		CMP	AX,D_AY 		;Y>AY?
		JLE	L_863
		MOV	AX,D_AY
L_862:
		MOV	D_Y,AX
L_863:
		MOV	AX,D_X
		CMP	AX,0			;X<0?
		JGE	L_864
		XOR	AX,AX
		JMP	SHORT L_865
L_864:
		CMP	AX,D_AX 		;X>AX?
		JLE	L_866
		MOV	AX,D_AX
L_865:
		MOV	D_X,AX
L_866:
		RET
S_850		ENDP

;子程序:显示字符串SI,DX=串首位置,BL=属性.显示后光标在串尾
S_XSZF		PROC	NEAR
L_XZ1:
		MOV	AH,2			;光标定位
		INT	10H
		LODSB				;取一字符
		OR	AL,AL			;结束?
		JZ	L_XZ2
		MOV	CX,1
		MOV	AH,9			;显示
		INT	10H
		INC	DX			;列+1
		JMP	SHORT L_XZ1
L_XZ2:
		RET
S_XSZF		ENDP

;子程序:定位显示空 DX=位置,CX=长
S_QP		PROC	NEAR
		MOV	AH,2			;光标定位
		INT	10H
		XOR	BX,BX
		MOV	AX,920H 		;显示空格
		INT	10H
		RET
S_QP		ENDP

;子程序:清屏
S_CLS		PROC	NEAR
		MOV	AL,D_XSFS		;汉字显示方式
		CMP	D_ZJXP,0		;=4直接写屏
		JZ	L_12
		MOV	AL,3
L_12:
		XOR	AH,AH			;清屏
		INT	10H
		RET
S_CLS		ENDP

;子程序:取当前点在DUP区地址BX
S_GETD		PROC	NEAR
		MOV	SI,D_X
		MOV	DI,D_Y
S_GETD1:
		PUSH	DX
		MOV	AX,D_AX
		INC	AX
		MUL	DI
		ADD	AX,SI
		ADD	AX,OFFSET D_DUP
		MOV	BX,AX
		POP	DX
		RET
S_GETD		ENDP

;子程序:显示光标
S_XSGB		PROC	NEAR
		MOV	AX,D_K			;点宽
		MUL	D_X
		PUSH	AX
		MOV	AX,80
		MUL	D_Y
		MOV	CX,D_H
		CMP	D_XSFS,9		;单显?
		JNZ	L_XSGB1
		SHR	CX,1
		SHR	CX,1
L_XSGB1:
		MUL	CX
		POP	DX

		ADD	AX,DX
		ADD	AX,8
		MOV	DI,AX			;开始字节

		PUSH	ES
		MOV	ES,D_A000		;显示缓冲区段
		CMP	D_XSFS,9		;HGA单显?
		JZ	L_XSGB4
		MOV	AX,D_H
		SUB	AX,2
		MOV	DX,80
		MUL	DX
		ADD	DI,AX
		MOV	CX,2
		MOV	DX,3C4H
		CMP	D_K,2			;点宽=2?
		JZ	L_XSGB3
L_XSGB2:
		XOR	BYTE PTR ES:[DI],7EH
		ADD	DI,80
		LOOP	L_XSGB2
		POP	ES
		RET
L_XSGB3:
		XOR	WORD PTR ES:[DI],0FE7FH
		ADD	DI,80
		LOOP	L_XSGB3
		POP	ES
		RET
L_XSGB4:
		MOV	AX,D_H
		SHR	AX,1
		SHR	AX,1
		DEC	AX
		MOV	DX,80
		MUL	DX
		ADD	DI,AX
		MOV	AX,0FF3FH
		CMP	D_K,2			;点宽=2?
		JZ	L_XSGB5
		XOR	ES:[DI+4000H],AL
		XOR	ES:[DI+6000H],AL
		POP	ES
		RET
L_XSGB5:
		XOR	ES:[DI+4000H],AX
		XOR	ES:[DI+6000H],AX
		POP	ES
		RET
S_XSGB		ENDP

;子程序:显示点 BL:颜色
S_XSD		PROC	NEAR
		MOV	AX,D_K			;点宽
		MUL	D_X
		PUSH	AX
		MOV	AX,80
		MUL	D_Y
		MOV	CX,D_H
		CMP	D_XSFS,9		;单显?
		JNZ	L_XSD1
		SHR	CX,1
		SHR	CX,1
L_XSD1:
		MUL	CX
		POP	DX

		ADD	AX,DX
		ADD	AX,8
		MOV	DI,AX			;开始字节
S_XSD1:
		PUSH	ES
		PUSH	DI
		PUSH	CX
		MOV	CX,D_H
		SUB	CX,2
		MOV	ES,D_A000		;显示缓冲区段
		CMP	D_XSFS,9		;HGA单显?
		JZ	L_XSD5
		MOV	DX,3C4H
		CMP	D_K,2			;点宽=2?
		JZ	L_XSD3
L_XSD2:
		MOV	AX,0FF02H
		OUT	DX,AX
		MOV	BYTE PTR ES:[DI],0
		MOV	AH,BL
		OUT	DX,AX
		MOV	BYTE PTR ES:[DI],7EH
		ADD	DI,80
		LOOP	L_XSD2
		JMP	SHORT L_XSD4
L_XSD3:
		MOV	AX,0FF02H
		OUT	DX,AX
		MOV	WORD PTR ES:[DI],0
		MOV	AH,BL
		OUT	DX,AX
		MOV	WORD PTR ES:[DI],0FE7FH
		ADD	DI,80
		LOOP	L_XSD3
L_XSD4:
		MOV	AH,-1
		OUT	DX,AX
		POP	CX
		POP	DI
		POP	ES
		RET
L_XSD5:
		SHR	CX,1
		SHR	CX,1
		XOR	AH,AH
		CMP	D_K,2			;点宽=2?
		JZ	L_XSD7
		MOV	AL,15H
		CMP	BL,D_C2
		JZ	L_XSD6
		MOV	AL,3EH			;属性非0
L_XSD6:
		MOV	ES:[DI],AL
		MOV	ES:[DI+2000H],AL
		MOV	ES:[DI+4000H],AL
		MOV	ES:[DI+6000H],AL
		ADD	DI,80
		LOOP	L_XSD6
		MOV	ES:[DI],AL
		MOV	ES:[DI+2000H],AL
		JMP	SHORT L_XSD9
L_XSD7:
		MOV	AX,5515H
		CMP	BL,D_C2
		JZ	L_XSD8
		MOV	AX,0FE3FH		;属性非0
L_XSD8:
		MOV	ES:[DI],AX
		MOV	ES:[DI+2000H],AX
		MOV	ES:[DI+4000H],AX
		MOV	ES:[DI+6000H],AX
		ADD	DI,80
		LOOP	L_XSD8
		MOV	ES:[DI],AX
		MOV	ES:[DI+2000H],AX
L_XSD9:
		POP	CX
		POP	DI
		POP	ES
		RET
S_XSD		ENDP

;子程序:显示点阵
S_XSDZ		PROC	NEAR
		PUSH	D_X
		PUSH	D_Y
		XOR	AX,AX
		MOV	D_X,AX
		MOV	D_Y,AX
		MOV	BP,D_AY
		INC	BP
		MOV	SI,OFFSET D_DUP 	;点阵区
L_XD1:
		LODSB
		MOV	BL,AL
		CALL	S_XSD			;显示第一点
		MOV	CX,D_AX
L_XD2:
		ADD	DI,D_K
		LODSB
		MOV	BL,AL
		CALL	S_XSD1			;显示点
		LOOP	L_XD2
		MOV	D_X,CX
		INC	D_Y
		DEC	BP
		JNZ	L_XD1
		POP	D_Y
		POP	D_X
		RET
S_XSDZ		ENDP

;子程序:显示光标位置
S_XY		PROC	NEAR
		MOV	CL,10
		MOV	AX,D_X			;X
		INC	AX
		DIV	CL
		OR	AX,3030H
		CMP	AL,'0'
		JNZ	L_XY1
		MOV	AL,' '
L_XY1:
		MOV	WORD PTR D_XSX+2,AX
		MOV	AX,D_Y			;Y
		INC	AX
		DIV	CL
		OR	AX,3030H
		CMP	AL,'0'
		JNZ	L_XY2
		MOV	AL,' '
L_XY2:
		MOV	WORD PTR D_XSY+2,AX

		MOV	SI,OFFSET D_XSX
		MOV	DX,900H
		MOV	BX,1EH
		CALL	S_XSZF			;显示
		MOV	SI,OFFSET D_XSY
		MOV	DX,0A00H
		MOV	BX,1EH
		CALL	S_XSZF			;显示
		RET
S_XY		ENDP

;子程序:计算汉字在字库中位置DX:AX
S_800		PROC	NEAR
		MOV	DH,D_Q
		MOV	DL,D_W
		CMP	D_DZ,'4'
		JBE	L_800E
		CMP	DH,'Z'
		JBE	L_800A
		AND	DH,5FH
L_800A:
		CMP	DL,'Z'
		JBE	L_800B
		AND	DL,5FH
L_800B:
		SUB	DH,'0'
		CMP	DH,9
		JBE	L_800C
		SUB	DH,7
L_800C:
		SUB	DL,'0'
		CMP	DL,9
		JBE	L_800D
		SUB	DL,7
L_800D:
		MOV	AL,16
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX
		CMP	D_DZ,'5'                ;KZZF?
		JZ	L_803
		CMP	D_DZ,'6'                ;ZF24?
		JA	L_803
		CMP	AX,32
		JB	L_803
		PUSH	AX
		MOV	AL,D_ZT 		;字体号
		AND	AL,0FH
		MOV	AH,96			;每字体96个字符
		MUL	AH
		MOV	DX,AX
		POP	AX
		ADD	AX,DX
		JMP	SHORT L_803
L_800E:
		SUB	DX,0A0A0H
S_800A:
		CMP	D_DZ,'1'                ;16点阵?
		JZ	L_802
		CMP	DH,16			;判汉字?
		JAE	L_801
		CMP	D_ZT,'T'
		JZ	L_802
		POP	AX
		JMP	L_602			;响铃并JMP L_300
L_801:
		SUB	DH,15
L_802:
		SUB	DX,101H
		MOV	AL,94
		MUL	DH
		XOR	DH,DH
		ADD	AX,DX
L_803:
		MUL	D_N
		CMP	D_DZ,'6'                ;ZF24?
		JB	L_804
		ADD	AX,D_TOP
		ADC	DX,0
L_804:
		RET
S_800		ENDP

;子程序:键入数字 CX:字节数,返回BX
S_IN16		PROC	NEAR
		MOV	BP,16
		JMP	SHORT L_IN0
S_INPUT:
		MOV	BP,10
L_IN0:
		MOV	SI,OFFSET D_INPUT	;键入缓冲区
		MOV	DI,SI
		ADD	DI,CX
		MOV	CX,0E0FH
		MOV	AH,1
		INT	10H
		XOR	BX,BX
L_IN1:
		XOR	AH,AH			;键入
		INT	16H
		CMP	AL,80H
		JA	L_IN1
		CMP	AL,0DH			;回车?
		JB	L_IN1
		JZ	L_IN6
		CMP	AL,1BH			;<ESC>
		JZ	L_IN9
		CMP	AL,8			;退格?
		JNZ	L_IN5
		CMP	SI,OFFSET D_INPUT	;指针在区首?
		JA	L_IN3
L_IN2:
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
		JBE	L_IN5A
		CMP	BP,10
		JZ	L_IN1
		AND	AL,5FH
		CMP	AL,'A'
		JB	L_IN1
		CMP	AL,'F'
		JA	L_IN1
L_IN5A:
		CMP	SI,DI			;键入满?
		JZ	L_IN2
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
		JZ	L_IN9
		SUB	AL,'0'
		CMP	AL,9
		JBE	L_IN8
		SUB	AL,7
L_IN8:
		CBW
		PUSH	AX
		MOV	AX,BP
		MUL	BX
		MOV	BX,AX
		POP	AX
		ADD	BX,AX
		JMP	SHORT L_IN7
L_IN9:
		MOV	CX,2000H
		MOV	AH,1
		INT	10H
		RET
S_IN16		ENDP

S_DEC		PROC	NEAR
		CMP	AL,'A'
		JA	L_DEC2
		JNZ	L_DEC1
		MOV	AL,'9'
		RET
L_DEC1:
		CMP	AL,'0'
		JA	L_DEC2
		MOV	AL,'F'
		RET
L_DEC2:
		DEC	AL
		RET
S_DEC		ENDP

S_INC		PROC	NEAR
		CMP	AL,'9'
		JB	L_INC2
		JNZ	L_INC1
		MOV	AL,'A'
		RET
L_INC1:
		CMP	AL,'F'
		JB	L_INC2
		MOV	AL,'0'
		RET
L_INC2:
		INC	AL
		RET
S_INC		ENDP

D_DUP	EQU	$				;点阵区(40*40字节)
D_DUP1	EQU	$+40*40 			;点阵区(40*40字节)

CSEG		ENDS
		END	START

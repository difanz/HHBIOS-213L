;	AH0E.INC
;	1994.7.23

;AH=0EH 显示字符并推进光标
L_AH0E: 	MOV	DX,DS:[450H]
		CMP	AL,8			;退格?
		JZ	L_0E06
		CMP	AL,0AH			;换行?
		JZ	L_0E02
		CMP	AL,0DH			;回车?
		JZ	L_0E05
		CMP	AL,' '                  ;控制字符?
		JAE	L_0E01
		JMP	L_INT10 		;调原INT10
L_0E01: 	MOV	AH,0AH
		MOV	CX,1
		INT	10H			;显示字符
		INC	DL			;列+1
		CMP	DL,80			;判行尾?
		JNZ	L_0E04
		XOR	DL,DL			;行首
L_0E02: 	CMP	DH,18H			;判屏尾?
		JB	L_0E03
		MOV	AH,8
		INT	10H			;取当前位置属性BH
		MOV	BH,AH
		XOR	CX,CX			;屏幕左上角
		MOV	DX,184FH		;    右下角
		MOV	AX,601H
		INT	10H			;屏幕上滚一行
		XOR	DL,DL			;行首
		JMP	SHORT L_0E04
L_0E03: 	INC	DH			;行+1
L_0E04: 	MOV	DS:[450H],DX
		CALL	S_GB			;光标定位
		JMP	L_RET			;返回
L_0E05: 	XOR	DL,DL			;行首
		JMP	SHORT L_0E04
L_0E06: 	OR	DL,DL			;判行首?
		JZ	L_0E04
		DEC	DL			;列-1
		JMP	SHORT L_0E04


;	AH13.INC
;	1994.7.23

;AH=13H 显示字符串 ES:BP=字符串首址, DX=位置, CX=串长
;		   AL=0 BL=属性 显示后光标不变
;		   AL=1 BL=属性 显示后光标移串尾
;		   AL=2 串含属性 显示后光标不变
;		   AL=3 串含属性 显示后光标移串尾
;		   AL=4 BL=属性 串以0结尾 显示后光标移串尾
;		   AL=5 BL=新属性 DX=串首位置 CX=串长 显示后原光标位置不变
L_AH13: 	PUSH	ES
		CALL	S_QGB			;关光标
		POP	ES
		SHL	BYTE PTR CS:[101H],1	;保存光标位
		CMP	AL,4			;方式=4?
		JZ	L_1302
L_1301: 	OR	CX,CX			;串长>0?
		JNZ	L_1302
		JMP	L_1308
L_1302: 	MOV	SI,DS:[450H]		;取当前光标位置
		PUSH	AX
		MOV	AH,2			;光标定位
		INT	10H
		POP	AX
L_1303: 	PUSH	CX
		PUSH	BX
		PUSH	AX
		MOV	AH,AL			;方式号
		CMP	AL,5
		JNZ	L_1303A
		MOV	AH,8			;取当前光标位置字符
		INT	10H
		JMP	SHORT L_1303B
L_1303A:	MOV	AL,ES:[BP]		;取一字符
		INC	BP
		CMP	AX,400H 		;方式4:AL=0(结束)
		JZ	L_1308A
L_1303B:	CMP	AL,8			;是退格?
		JZ	L_1304
		CMP	AL,0DH			;是回车?
		JZ	L_1304
		CMP	AL,0AH			;是换行?
		JZ	L_1304
		CMP	AL,7			;是响铃?
		JNZ	L_1305
L_1304: 	MOV	AH,0EH			;执行
		INT	10H
		MOV	DX,DS:[450H]		;取当前光标位置
		JMP	SHORT L_1307
L_1305: 	MOV	CX,1
		CMP	AH,4
		JNB	L_1306
		CMP	AH,2			;方式=2,3?
		JB	L_1306
		MOV	BL,ES:[BP]		;取属性
		INC	BP
L_1306: 	MOV	AH,9			;显示字符
		INT	10H
		INC	DL			;列位置+1
		CMP	DL,80			;判行尾?
		JB	L_1307
		XOR	DL,DL			;行首
		INC	DH			;行+1
		CMP	DH,25			;屏尾?
		JB	L_1307
		DEC	DH
L_1307: 	MOV	AH,2			;光标定位
		INT	10H
		POP	AX
		POP	BX
		POP	CX
		CMP	AL,4
		JZ	L_1303
		LOOP	L_1303
		CMP	AL,1			;方式=1
		JZ	L_1308
		CMP	AL,3			;方式=3
		JZ	L_1308
L_1307A:	MOV	DX,SI			;恢复原光标
		MOV	AH,2
		INT	10H
L_1308: 	SHR	BYTE PTR CS:[101H],1	;恢复光标位
		CALL	S_GB			;恢复光标
		JMP	L_RET
L_1308A:	POP	AX
		POP	BX
		POP	CX
		JMP	SHORT L_1308


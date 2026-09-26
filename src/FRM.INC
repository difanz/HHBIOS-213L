; Frame corners stay CP437. The eight corner bytes, the matching
; bar (CD double, C4 single), and a line on the other axis.
; That line may still be B3 or BA, or already 14h / 15h after the
; vertical scan rewrites a short stroke. B800 is not rewritten here.

D_FRMC		LABEL	BYTE
		DB	0C9H, 0CDH, 3
		DB	0BBH, 0CDH, 2
		DB	0C8H, 0CDH, 1
		DB	0BCH, 0CDH, 0
		DB	0DAH, 0C4H, 3
		DB	0BFH, 0C4H, 2
		DB	0C0H, 0C4H, 1
		DB	0D9H, 0C4H, 0
D_CFLG		DB	0

; ES:BX = cell. DL = column, DH = row.
; ZF=1 when this cell is a corner or the bar beside that corner.
S_CORNER	PROC	NEAR
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		MOV	BYTE PTR CS:D_CFLG,0
		MOV	SI,BX
		MOV	AL,ES:[SI]
		MOV	DI,OFFSET D_FRMC
		MOV	CX,8
SC_TAB: 	CMP	AL,CS:[DI]
		JNZ	SC_NXT
		PUSH	AX
		PUSH	CX
		MOV	AH,CS:[DI+1]
		MOV	CL,CS:[DI+2]
		CALL	S_CGEO
		POP	CX
		POP	AX
		JZ	SC_YES
SC_NXT: 	ADD	DI,3
		LOOP	SC_TAB
		MOV	DI,OFFSET D_FRMC
		MOV	CX,8
SB_TAB: 	CMP	AL,CS:[DI+1]
		JNZ	SB_NXT
		PUSH	AX
		PUSH	CX
		MOV	AH,CS:[DI]
		MOV	CL,CS:[DI+2]
		CALL	S_BGEO
		POP	CX
		POP	AX
		JZ	SC_YES
SB_NXT: 	ADD	DI,3
		LOOP	SB_TAB
		JMP	SHORT SC_RET
SC_YES: 	MOV	BYTE PTR CS:D_CFLG,1
SC_RET: 	POP	DI
		POP	SI
		POP	DX
		POP	CX
		POP	BX
		POP	AX
		CMP	BYTE PTR CS:D_CFLG,1
		RET
S_CORNER	ENDP

; SI = corner cell. AH = bar byte. CL bit0 = bar on the right.
; CL bit1 = line below the corner. ES = buffer. DX = position.
S_CGEO		PROC	NEAR
		TEST	CL,1
		JZ	CG_LEFT
		CMP	DL,79
		JAE	CG_NO
		CMP	AH,ES:[SI+2]
		JNZ	CG_NO
		JMP	SHORT CG_VERT
CG_LEFT:	OR	DL,DL
		JZ	CG_NO
		CMP	AH,ES:[SI-2]
		JNZ	CG_NO
CG_VERT:	TEST	CL,2
		JZ	CG_UP
		CMP	DH,24
		JAE	CG_NO
		MOV	AL,ES:[SI+160]
		JMP	SHORT CG_LINE
CG_UP:		OR	DH,DH
		JZ	CG_NO
		MOV	AL,ES:[SI-160]
CG_LINE:	CMP	AL,0B3H
		JZ	CG_YES
		CMP	AL,0BAH
		JZ	CG_YES
		CMP	AL,14H
		JZ	CG_YES
		CMP	AL,15H
		JZ	CG_YES
CG_NO:		XOR	AL,AL
		INC	AL
		RET
CG_YES: 	XOR	AL,AL
		RET
S_CGEO		ENDP

; SI = bar cell. AH = corner byte. CL flags describe that corner.
S_BGEO		PROC	NEAR
		TEST	CL,1
		JZ	BG_RIGHT
		OR	DL,DL
		JZ	BG_NO
		CMP	AH,ES:[SI-2]
		JNZ	BG_NO
		TEST	CL,2
		JZ	BG_UPL
		CMP	DH,24
		JAE	BG_NO
		MOV	AL,ES:[SI-2+160]
		JMP	SHORT BG_LINE
BG_UPL: 	OR	DH,DH
		JZ	BG_NO
		MOV	AL,ES:[SI-2-160]
		JMP	SHORT BG_LINE
BG_RIGHT:	CMP	DL,79
		JAE	BG_NO
		CMP	AH,ES:[SI+2]
		JNZ	BG_NO
		TEST	CL,2
		JZ	BG_UPR
		CMP	DH,24
		JAE	BG_NO
		MOV	AL,ES:[SI+2+160]
		JMP	SHORT BG_LINE
BG_UPR: 	OR	DH,DH
		JZ	BG_NO
		MOV	AL,ES:[SI+2-160]
BG_LINE:	CMP	AL,0B3H
		JZ	BG_YES
		CMP	AL,0BAH
		JZ	BG_YES
		CMP	AL,14H
		JZ	BG_YES
		CMP	AL,15H
		JZ	BG_YES
BG_NO:		XOR	AL,AL
		INC	AL
		RET
BG_YES: 	XOR	AL,AL
		RET
S_BGEO		ENDP

IFDEF D_005A
D_EPF		DB	0

; Cursor has already stepped one column left (DL).
; ZF=1: that cell and the lead on its left were a non-corner
; pair and both cells are now spaces. Caller steps one more column.
S_0EP		PROC	NEAR
		PUSH	AX
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	ES
		MOV	BYTE PTR CS:D_EPF,0
		OR	DL,DL
		JZ	EP_RET
		MOV	AL,DH
		MOV	BL,80
		MUL	BL
		XOR	BH,BH
		MOV	BL,DL
		ADD	AX,BX
		SHL	AX,1
		MOV	BX,AX
		MOV	AL,CS:D_XPQ[BX]
		CMP	AL,0A0H
		JBE	EP_RET
		XOR	CL,CL
		MOV	CH,DL
		MOV	SI,BX
EP_WLK: 	SUB	SI,2
		CMP	BYTE PTR CS:D_XPQ[SI],0A0H
		JBE	EP_PAR
		NOT	CL
		DEC	CH
		JNZ	EP_WLK
EP_PAR: 	OR	CL,CL
		JZ	EP_RET
		MOV	AL,CS:D_XPQ[BX-2]
		CMP	AL,0A0H
		JBE	EP_RET
		PUSH	CS
		POP	ES
		PUSH	BX
		SUB	BX,2
		ADD	BX,OFFSET D_XPQ
		DEC	DL
		CALL	S_CORNER
		POP	BX
		JZ	EP_RET
		INC	DL
		PUSH	BX
		ADD	BX,OFFSET D_XPQ
		CALL	S_CORNER
		POP	BX
		JZ	EP_RET
		MOV	BYTE PTR CS:D_XPQ[BX],20H
		MOV	BYTE PTR CS:D_XPQ[BX-2],20H
		CMP	BYTE PTR CS:D_005A,1
		JNZ	EP_MARK
		PUSH	ES
		MOV	ES,CS:D_B800
		MOV	BYTE PTR ES:[BX],20H
		MOV	BYTE PTR ES:[BX-2],20H
		POP	ES
EP_MARK:	MOV	BYTE PTR CS:D_EPF,1
EP_RET: 	POP	ES
		POP	DI
		POP	SI
		POP	DX
		POP	CX
		POP	BX
		POP	AX
		CMP	BYTE PTR CS:D_EPF,1
		RET
S_0EP		ENDP
ENDIF

; A foreground DOS read already printed its prompt. Keep that logical page
; across the reader's final BIOS mode reset, without typing a key into DOS.
; Reuse the driver's logical page until the unload call returns. Like the
; existing released return frames, these bytes remain valid until DOS next
; allocates memory. Do not allocate between unload and SC_COPY.
console_segment DW 0
console_offset DW 0
console_columns DW 0
console_rows DW 0
console_cursor DW 0
console_shape DW 0
console_page DB 0
console_mode DB 3

S_SAVE_CONSOLE PROC NEAR
        PUSH CS
        POP DS
        MOV console_segment,0
        MOV AX,40H
        MOV ES,AX
        MOV AX,ES:[4AH]
        CMP AX,40
        JE SC_COLUMNS
        CMP AX,80
        JNE SC_FAILED
SC_COLUMNS:
        MOV console_columns,AX
        XOR AX,AX
        MOV AL,ES:[84H]
        INC AX
        CMP AX,25
        JAE SC_ROWS
        MOV AX,25
SC_ROWS:
        CMP AX,50
        JA SC_FAILED
        MOV console_rows,AX
        MOV AL,ES:[62H]
        MOV console_page,AL
        MOV AL,ES:[49H]
        AND AL,7FH
        MOV console_mode,AL
        MOV AH,3
        MOV BH,console_page
        INT 10H
        MOV console_cursor,DX
        MOV console_shape,CX
        MOV AX,140CH
        XOR BX,BX
        INT 10H
        OR BX,BX
        JZ SC_READY
        MOV console_segment,BX
        MOV console_offset,AX
        MOV AX,1406H
        INT 10H
        TEST DL,80H
        JZ SC_READY
        MOV ES,console_segment
        MOV DI,console_offset
        MOV AX,console_columns
        MUL console_rows
        MOV CX,AX
        MOV AX,40H
        MOV DS,AX
        MOV SI,DS:[4EH]
        MOV AX,0B800H
        CMP CS:console_mode,7
        JNE SC_SAVE_COLOR
        MOV AX,0B000H
SC_SAVE_COLOR:
        MOV DS,AX
        CLD
        REP MOVSW
SC_READY:
        CLC
        RET
SC_FAILED:
        ; A native application can own a larger text mode while HHBIOS is
        ; suspended. The base reader leaves that hardware mode untouched.
        MOV console_columns,0
        CLC
        RET
S_SAVE_CONSOLE ENDP

S_RESTORE_CONSOLE PROC NEAR
        PUSH CS
        POP DS
        CMP console_columns,0
        JNE SC_RESTORE
        RET
SC_RESTORE:
        CMP console_mode,7
        JE SC_MONO
        CMP console_columns,40
        JE SC_NARROW
        CMP console_rows,43
        JNE SC_FONT
        MOV AX,1201H
        MOV BL,30H
        INT 10H
        MOV AX,83H
        INT 10H
SC_FONT:
        CMP console_rows,25
        JBE SC_COPY
        MOV AX,1112H
        XOR BX,BX
        INT 10H
        JMP SHORT SC_COPY
SC_NARROW:
        MOV AX,81H
        INT 10H
        JMP SHORT SC_COPY
SC_MONO:
        MOV AX,87H
        INT 10H
SC_COPY:
        CMP console_segment,0
        JE SC_CURSOR
        MOV AX,0B800H
        CMP console_mode,7
        JNE SC_COLOR
        MOV AX,0B000H
SC_COLOR:
        MOV ES,AX
        MOV AX,console_columns
        MUL console_rows
        MOV CX,AX
        MOV SI,console_offset
        XOR DI,DI
        MOV DS,console_segment
        CLD
        REP MOVSW
        PUSH CS
        POP DS
SC_CURSOR:
        MOV DX,console_cursor
        XOR BX,BX
        MOV AH,2
        INT 10H
        MOV CX,console_shape
        MOV AH,1
        INT 10H
        RET
S_RESTORE_CONSOLE ENDP

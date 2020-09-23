;       EXIT1.INC 清理内存管理模块装载模块(在读显示字库模块执行部分之首)
;       1993.7.10
;       1995.1.24

                MOV     SI,OFFSET D_INT         ;中断向量保存区
                MOV     CX,D_INTNUM
L_S1:           LODSB                           ;取中断号
                MOV     AH,35H                  ;取中断向量
                INT     21H
                MOV     WORD PTR [SI],BX        ;保存
                MOV     WORD PTR [SI+2],ES
                ADD     SI,4
                LOOP    L_S1

                MOV     DX,OFFSET INT_21
                MOV     AX,2521H                ;建中断
                INT     21H
                MOV     DX,OFFSET INT_27
                MOV     AX,2527H                ;建中断
                INT     21H
                MOV     DX,OFFSET INT_2F
                MOV     AX,252FH                ;建中断
                INT     21H


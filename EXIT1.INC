;       EXIT1.INC �����ڴ����ģ��װ��ģ��(�ڶ���ʾ�ֿ�ģ��ִ�в���֮��)
;       1993.7.10
;       1995.1.24

                MOV     SI,OFFSET D_INT         ;�ж�����������
                MOV     CX,D_INTNUM
L_S1:           LODSB                           ;ȡ�жϺ�
                MOV     AH,35H                  ;ȡ�ж�����
                INT     21H
                MOV     WORD PTR [SI],BX        ;����
                MOV     WORD PTR [SI+2],ES
                ADD     SI,4
                LOOP    L_S1

                MOV     DX,OFFSET INT_21
                MOV     AX,2521H                ;���ж�
                INT     21H
                MOV     DX,OFFSET INT_27
                MOV     AX,2527H                ;���ж�
                INT     21H
                MOV     DX,OFFSET INT_2F
                MOV     AX,252FH                ;���ж�
                INT     21H


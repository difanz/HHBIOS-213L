; Pinyin conversion runs once per query, on the interrupted program's stack.
; BL = typed length; return BP = key count, BX = packed query keys.
include abi.inc
extrn syscall PinyinPrepare:near
S_A010:
    save_c_regs
    xor ch,ch
    mov cl,bl
    mov bx,cx
    dec bx
    cmp bx,7
    ja pinyin_call
    mov al,D_2BB1[bx]
    mov D_2B,al
pinyin_call:
    mov si,offset D_2BB1
    mov di,offset D_2CC1
    call PinyinPrepare
    xor dx,dx
    test ax,ax
    jz pinyin_result
    inc dx
    test ah,ah
    jz pinyin_result
    inc dx
pinyin_result:
    ; Replace only the two returned words in save_c_regs' stack frame.
    ; PUSHAD's upper halves belong to the interrupted application.
    mov bp,sp
    IF HH_CPU GE 3
        mov ss:[bp+20],ax       ; saved BX
        mov ss:[bp+12],dx       ; saved BP
    ELSE
        mov ss:[bp+14],ax       ; saved BX
        mov ss:[bp+4],dx        ; saved BP
    ENDIF
    restore_c_regs
    cmp bp,2
    jne pinyin_done
    call S_A080
    mov bp,2
pinyin_done:
    ret

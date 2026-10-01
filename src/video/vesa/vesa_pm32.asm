; 32-bit glyph painter. CS = selector 18h, DS = ES = SS = flat.
; EBP = flat address of gfg, ESI = first glyph row, EDI = first pixel.
; DF is clear. No stack traffic. Offsets match the gfg block in vesa_lfb.asm.
; origin ([ebp+28]) starts at EDI so later rows add display pitch, not 0.
; Falls off the end into a far jump back to 16-bit pm_exit.
.386p
.model tiny
.code use32

pm32_scan:
    mov [ebp+28],edi
    movzx eax,word ptr [ebp+20]
    mov [ebp+24],ax
    movzx eax,word ptr [ebp+26]
    mov [ebp+36],eax
pm32_line:
    cmp word ptr [ebp+18],0
    jne pm32_gen
    movzx ecx,word ptr [ebp+14]
    mov eax,ecx
    shr eax,3
    add eax,esi
    mov edx,eax
    mov eax,[edx]
    xchg al,ah
    rol eax,16
    xchg al,ah
    and cl,7
    shl eax,cl
    movzx ebx,word ptr [ebp+16]
pm32_run:
    test ebx,ebx
    jz pm32_eol
    mov edx,eax
    rol edx,1
    and edx,1
    test edx,edx
    jnz pm32_one
    bsr ecx,eax
    jz pm32_all
    neg ecx
    add ecx,31
    jmp pm32_fit
pm32_one:
    mov ecx,eax
    not ecx
    bsr ecx,ecx
    jz pm32_all
    neg ecx
    add ecx,31
pm32_fit:
    test ecx,ecx
    jz pm32_all
    cmp ecx,ebx
    jbe pm32_keep
    mov ecx,ebx
pm32_keep:
    sub ebx,ecx
    shl eax,cl
pm32_store:
    mov [ebp+32],eax
    movzx eax,word ptr [ebp+20]
    imul eax,ecx
    mov ecx,eax
    mov eax,[ebp+4]
    test edx,edx
    jz pm32_put
    mov eax,[ebp]
pm32_put:
    cmp byte ptr [ebp-1],2
    jne pm32_d32
    rep stosw
    jmp pm32_back
pm32_d32:
    rep stosd
pm32_back:
    mov eax,[ebp+32]
    jmp pm32_run
pm32_all:
    mov ecx,ebx
    xor ebx,ebx
    jmp pm32_store
pm32_gen:
    movzx edx,word ptr [ebp+20]
    xor ebx,ebx
pm32_col:
    cmp bx,word ptr [ebp+16]
    jae pm32_eol
    cmp word ptr [ebp+18],1
    je pm32_word
    cmp ebx,32
    jae pm32_bg
    mov eax,[esi]
    mov cl,bl
    shl eax,cl
    test eax,eax
    js pm32_fg
    jmp pm32_bg
pm32_word:
    cmp ebx,16
    jae pm32_bg
    mov ax,[esi]
    mov cl,bl
    shl ax,cl
    test ah,80h
    jnz pm32_fg
pm32_bg:
    mov eax,[ebp+4]
    jmp pm32_rep
pm32_fg:
    mov eax,[ebp]
pm32_rep:
    mov ecx,edx
    cmp byte ptr [ebp-1],2
    jne pm32_r32
    rep stosw
    jmp pm32_step
pm32_r32:
    rep stosd
pm32_step:
    inc ebx
    jmp pm32_col
pm32_eol:
    movzx eax,word ptr [ebp+22]
    add eax,[ebp+28]
    mov [ebp+28],eax
    mov edi,eax
    dec word ptr [ebp+24]
    jnz pm32_src
    movzx eax,word ptr [ebp+20]
    mov [ebp+24],ax
    movzx eax,word ptr [ebp+12]
    add esi,eax
pm32_src:
    dec dword ptr [ebp+36]
    jz pm32_leave
    jmp pm32_line
pm32_leave:

end

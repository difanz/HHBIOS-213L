; Direct-color framebuffer for a resident 16-bit TSR.
; Each transfer enters protected mode only long enough to use a 4 GB data
; descriptor, then returns to real mode. V86 (CR0.PE already set) fails.
; Copies stay at or below 4096 bytes so interrupts are off for one chunk.
; Glyph rows use one entry (op 7) instead of one entry per color run.
; Dirty space runs are filled with linear_hline before the glyph walk.
; Real-mode callers run with DS = CS. Protected-mode code uses CS overrides.
.model tiny,c
.code
.386p

public lfb_bytes, lfb_load, lfb_a20, linear_prepare, linear_use_bank
public linear_packed, linear_words, linear_large, linear_hline
public linear_scroll, linear_cursor, linear_pixel, linear_read
public linear_text_isolated, linear_bind_text, linear_paint_spaces

extrn active:byte, display_pitch:word, viewport_x:word, viewport_y:word
extrn font_width:word, pixel_scale:word, raster_height:word, text_rows:word
extrn font_body_height:word, screen:byte, begin_draw:near, end_draw:near
extrn banked_text:byte, page_bytes:word, page_count:word, plane_bytes:dword
extrn font_custom:byte, shadow:word, text_transfer:byte
extrn active_page:word, text_cells:word

lfb_bytes dd 0
op     dw 0
dest   dd 0
src    dd 0
cnt    dw 0
nbytes dw 0
color  dd 0
pixsz  dw 2
counting db 0
gfg    dd 0
gbg    dd 0
gaddr  dd 0
gpitch dw 0
gbit   dw 0
gwidth dw 0
gkind  dw 0
gscale dw 1
line_bytes dw 0
row_px dw 0
pix_lines dw 0
origin dd 0
distance dd 0
pix    dd 0
text_saved dw 0
linear_bpp_bytes db 2
linear_xor_mask dd 0
linear_palette dd 16 dup (0)
rgb db 000h,000h,000h, 000h,000h,0aah, 000h,0aah,000h, 000h,0aah,0aah
    db 0aah,000h,000h, 0aah,000h,0aah, 0aah,055h,000h, 0aah,0aah,0aah
    db 055h,055h,055h, 055h,055h,0ffh, 055h,0ffh,055h, 055h,0ffh,0ffh
    db 0ffh,055h,055h, 0ffh,055h,0ffh, 0ffh,0ffh,055h, 0ffh,0ffh,0ffh

gdt       dq 0
gdt_code  dw 0ffffh, 0, 9a00h, 0
gdt_data  dw 0ffffh, 0, 9200h, 00cfh
gdt_end   label byte
gdtr      dw gdt_end - gdt - 1
          dd 0

; ESI/EDI/ECX are set by flat_pm. DF is clear.
pm_copy:
    mov edx,ecx
    shr ecx,2
    jz pm_tail
    db 67h,66h,0f3h,0a5h
pm_tail:
    mov ecx,edx
    and ecx,3
    jz pm_done
    db 67h,0f3h,0a4h
pm_done:
    jmp pm_exit

; BL is 3 to store or 5 to xor. EDI/ECX preset. Pixels are packed.
pm_paint:
    mov eax,cs:color
    jecxz pm_done
    cmp bl,5
    je pm_xor
    cmp byte ptr cs:pixsz,2
    jne pm_stosd
    db 67h,0f3h,0abh
    jmp pm_exit
pm_stosd:
    db 67h,66h,0f3h,0abh
    jmp pm_exit
pm_xor:
    movzx edx,word ptr cs:pixsz
pm_xloop:
    jecxz pm_done
    cmp dl,2
    jne pm_x32
    xor [edi],ax
    jmp short pm_xstep
pm_x32:
    xor [edi],eax
pm_xstep:
    add edi,edx
    dec ecx
    jmp pm_xloop

flat_pm:
    mov ax,10h
    mov ds,ax
    mov es,ax
    cld
    mov bx,cs:op
    mov edi,cs:dest
    mov esi,cs:src
    movzx ecx,word ptr cs:cnt
    cmp bx,1
    je pm_copy
    cmp bx,7
    je pm_scan
    cmp bx,3
    je pm_paint
    cmp bx,5
    je pm_paint
    jmp pm_exit

; Op 7: one glyph scanline. ESI is the glyph row, EDI the framebuffer.
; Horizontal scale repeats each column. No stack: SS is still a real selector.
pm_scan:
    movzx ebp,word ptr cs:gwidth
    movzx edx,word ptr cs:gscale
    test edx,edx
    jnz pm_scale
    inc edx
pm_scale:
    xor ebx,ebx
pm_col:
    cmp ebx,ebp
    jb pm_bit
    jmp pm_exit
pm_bit:
    movzx ecx,word ptr cs:gkind
    or ecx,ecx
    jz pm_packed
    cmp ecx,1
    je pm_word
    cmp ebx,32
    jae pm_bg
    db 67h,66h,8bh,06h
    mov cl,bl
    shl eax,cl
    test eax,80000000h
    jmp short pm_pick
pm_word:
    cmp ebx,16
    jae pm_bg
    db 67h,8bh,06h
    mov cl,bl
    shl ax,cl
    test ah,80h
    jmp short pm_pick
pm_packed:
    movzx eax,word ptr cs:gbit
    add eax,ebx
    mov ecx,eax
    shr ecx,3
    and al,7
    mov ah,al
    db 67h,8ah,04h,0eh
    mov cl,ah
    mov ch,80h
    shr ch,cl
    test al,ch
pm_pick:
    mov eax,cs:gbg
    jz pm_reps
    mov eax,cs:gfg
    jmp short pm_reps
pm_bg:
    mov eax,cs:gbg
pm_reps:
    mov ecx,edx
pm_pix:
    cmp byte ptr cs:pixsz,2
    jne pm_pix32
    db 67h,89h,07h
    db 66h,83h,0c7h,02h
    jmp short pm_pixn
pm_pix32:
    db 67h,66h,89h,07h
    db 66h,83h,0c7h,04h
pm_pixn:
    db 66h,49h
    jnz pm_pix
    db 66h,43h
    jmp pm_col

pm_exit:
    mov eax,cr0
    and al,0feh
    mov cr0,eax
    db 0eah
    dw offset flat_back
flat_cs_slot dw 0

flat_run proc near
    push si
    push di
    push ds
    pushf
    cli
    smsw ax
    test al,1
    jnz flat_denied
    pushad
    mov ax,cs
    mov word ptr cs:flat_cs_slot,ax
    movzx ebx,ax
    shl ebx,4
    mov eax,ebx
    add eax,offset gdt
    mov dword ptr cs:gdtr+2,eax
    mov word ptr cs:gdt_code+2,bx
    shr ebx,16
    mov byte ptr cs:gdt_code+4,bl
    mov byte ptr cs:gdt_code+7,bh
    lgdt fword ptr cs:gdtr
    mov eax,cr0
    or al,1
    mov cr0,eax
    db 0eah
    dw offset flat_pm
    dw 8
flat_back:
    mov ax,cs
    mov ds,ax
    mov ax,cs:nbytes
    add word ptr cs:lfb_bytes,ax
    adc word ptr cs:lfb_bytes+2,0
    popad
    mov ax,1
    jmp short flat_leave
flat_denied:
    xor ax,ax
flat_leave:
    popf
    pop ds
    pop di
    pop si
    ret
flat_run endp

lfb_load proc near
    push bp
    mov bp,sp
    cmp word ptr [bp+10],4096
    ja load_no
    mov eax,[bp+4]
    mov src,eax
    movzx eax,word ptr [bp+8]
    mov edx,cs
    shl edx,4
    add eax,edx
    mov dest,eax
    mov ax,[bp+10]
    mov cnt,ax
    mov nbytes,0
    mov op,1
    call flat_run
    jmp short load_out
load_no:
    xor ax,ax
load_out:
    pop bp
    ret
lfb_load endp

lfb_a20 proc near
    pushf
    cli
    mov ax,2401h
    int 15h
    in al,92h
    or al,2
    and al,0feh
    out 92h,al
    popf
    ret
lfb_a20 endp

; AL = value, BL = field size, BH = position. Result in EAX.
pack_ch proc near
    push cx
    mov cl,8
    sub cl,bl
    jbe pack_full
    shr al,cl
pack_full:
    movzx eax,al
    mov cl,bl
    mov edx,1
    shl edx,cl
    dec edx
    and eax,edx
    mov cl,bh
    shl eax,cl
    pop cx
    ret
pack_ch endp

linear_prepare proc near
    push si
    push di
    push bp
    mov al,2
    cmp byte ptr screen+16,32
    jne prep_bpp
    mov al,4
prep_bpp:
    mov linear_bpp_bytes,al
    mov si,offset rgb
    xor di,di
prep_color:
    mov dword ptr pix,0
    xor bp,bp
prep_channel:
    mov al,[si]
    inc si
    mov bl,byte ptr screen+18[bp]
    mov bh,byte ptr screen+19[bp]
    call pack_ch
    or pix,eax
    add bp,2
    cmp bp,6
    jb prep_channel
    mov bx,di
    shl bx,2
    mov eax,pix
    mov linear_palette[bx],eax
    inc di
    cmp di,16
    jb prep_color
    mov eax,dword ptr linear_palette+60
    mov linear_xor_mask,eax
    mov eax,dword ptr screen+24
    mov edx,eax
    add edx,plane_bytes
    or eax,edx
    test eax,100000h
    jz prep_done
    call lfb_a20
prep_done:
    pop bp
    pop di
    pop si
    ret
linear_prepare endp

linear_use_bank proc near
    mov banked_text,1
    mov ax,32768
    xor dx,dx
    div page_bytes
    or ax,ax
    jnz use_pages
    mov ax,1
use_pages:
    mov page_count,ax
    cmp text_rows,25
    jbe use_read
    cmp ax,2
    jae use_read
    xor ax,ax
    ret
use_read:
    push 4
    push offset pix
    push dword ptr screen+24
    call lfb_load
    add sp,8
    ret
linear_use_bank endp

chunk_pix proc near
    push si
cp_loop:
    jcxz cp_ok
    mov ax,cx
    cmp ax,1024
    jbe cp_n
    mov ax,1024
cp_n:
    mov cnt,ax
    mul pixsz
    jc cp_bad
    cmp ax,4096
    ja cp_bad
    mov nbytes,ax
    mov si,ax
    push cx
    call flat_run
    pop cx
    or ax,ax
    jz cp_bad
    sub cx,cnt
    add word ptr dest,si
    adc word ptr dest+2,0
    jmp cp_loop
cp_ok:
    pop si
    mov ax,1
    ret
cp_bad:
    mov active,0
    pop si
    xor ax,ax
    ret
chunk_pix endp

copy_bytes proc near
    push si
cb_loop:
    jcxz cb_ok
    mov ax,cx
    cmp ax,4096
    jbe cb_n
    mov ax,4096
cb_n:
    mov cnt,ax
    mov nbytes,0
    cmp counting,0
    je cb_go
    mov nbytes,ax
cb_go:
    mov si,ax
    mov op,1
    push cx
    call flat_run
    pop cx
    or ax,ax
    jz cb_bad
    sub cx,si
    add word ptr dest,si
    adc word ptr dest+2,0
    add word ptr src,si
    adc word ptr src+2,0
    jmp cb_loop
cb_ok:
    pop si
    mov ax,1
    ret
cb_bad:
    mov active,0
    pop si
    xor ax,ax
    ret
copy_bytes endp

; AX = x, BX = y. Writes dest as physical + y * pitch + x * bytes per pixel.
xy_dest proc near
    push cx
    push ax
    mov ax,bx
    mul display_pitch
    add ax,word ptr screen+24
    adc dx,word ptr screen+26
    mov cx,ax
    mov bx,dx
    pop ax
    push bx
    push cx
    mov cl,linear_bpp_bytes
    xor ch,ch
    mul cx
    pop cx
    pop bx
    add cx,ax
    adc bx,dx
    mov word ptr dest,cx
    mov word ptr dest+2,bx
    pop cx
    ret
xy_dest endp

; One scanline of gwidth columns at gaddr, in a single protected-mode entry.
; SI is the glyph row and is not advanced. The next line is the saved start
; plus the BIOS pitch. A cell line is at most 24*4*4 bytes, under the 4096 cap.
paint_line proc near
    push si
    mov eax,gaddr
    mov dest,eax
    movzx eax,si
    mov dx,cs
    movzx edx,dx
    shl edx,4
    add eax,edx
    mov src,eax
    mov ax,gwidth
    mul word ptr gscale
    jc pl_bad
    mul word ptr pixsz
    jc pl_bad
    cmp ax,4096
    ja pl_bad
    mov nbytes,ax
    mov op,7
    call flat_run
    or ax,ax
    jz pl_bad
    movzx eax,display_pitch
    add eax,dest
    mov gaddr,eax
    mov ax,1
pl_leave:
    pop si
    ret
pl_bad:
    mov active,0
    xor ax,ax
    jmp pl_leave
paint_line endp

; BL = column, BH = row, CX = scale. Returns AX = x, BX = y. Preserves CX, SI.
cell_xy proc near
    push cx
    push si
    mov al,bl
    xor ah,ah
    mul font_width
    mul cx
    add ax,viewport_x
    mov si,ax
    mov al,bh
    xor ah,ah
    mul raster_height
    mul cx
    add ax,viewport_y
    mov bx,ax
    mov ax,si
    pop si
    pop cx
    ret
cell_xy endp

glyph_go:
    push si
    push di
    cmp active,0
    jne gg_live
    jmp gg_out
gg_live:
    mov al,linear_bpp_bytes
    xor ah,ah
    mov pixsz,ax
    mov cx,pixel_scale
    or cx,cx
    jnz gg_sc
    inc cx
gg_sc:
    mov gscale,cx
    mov bx,[bp+6]
    and bx,15
    shl bx,2
    mov eax,linear_palette[bx]
    mov gfg,eax
    mov bx,[bp+6]
    shr bx,4
    and bx,15
    shl bx,2
    mov eax,linear_palette[bx]
    mov gbg,eax
    mov bx,[bp+8]
    cmp bl,80
    jae gg_out
    mov al,bh
    xor ah,ah
    cmp ax,text_rows
    ja gg_out
    mov cx,gscale
    call cell_xy
    call xy_dest
    mov eax,dest
    mov gaddr,eax
    mov si,[bp+4]
    mov cx,raster_height
    jcxz gg_out
gg_row:
    push cx
    mov cx,gscale
gg_vert:
    push cx
    call paint_line
    pop cx
    cmp active,0
    je gg_pop
    loop gg_vert
    pop cx
    add si,gpitch
    loop gg_row
    jmp short gg_out
gg_pop:
    pop cx
gg_out:
    pop di
    pop si
    pop bp
    ret

; AX = kind, DX = source pitch, CX = first bit. BP frame holds source, attr, position.
glyph_args:
    mov gkind,ax
    mov gpitch,dx
    mov gbit,cx
    mov ax,font_width
    mov gwidth,ax
    jmp glyph_go

linear_packed proc near
    push bp
    mov bp,sp
    xor ax,ax
    mov dx,[bp+10]
    mov cx,[bp+12]
    jmp glyph_args
linear_packed endp

linear_words proc near
    push bp
    mov bp,sp
    mov ax,1
    mov dx,2
    xor cx,cx
    jmp glyph_args
linear_words endp

linear_large proc near
    push bp
    mov bp,sp
    mov ax,2
    mov dx,4
    xor cx,cx
    jmp glyph_args
linear_large endp

linear_hline proc near
    push bp
    mov bp,sp
    push si
    mov ax,[bp+4]
    mov bx,[bp+6]
    mov cx,[bp+8]
    mov dx,[bp+10]
    cmp linear_bpp_bytes,0
    je hl_done
    cmp bx,word ptr screen+2
    jae hl_done
    cmp ax,word ptr screen
    jae hl_done
    jcxz hl_done
    mov si,word ptr screen
    sub si,ax
    cmp cx,si
    jbe hl_clip
    mov cx,si
hl_clip:
    and dx,15
    mov bx,dx
    shl bx,2
    mov eax,linear_palette[bx]
    mov color,eax
    mov al,linear_bpp_bytes
    xor ah,ah
    mov pixsz,ax
    mov bx,[bp+6]
    mov ax,[bp+4]
    mov op,3
    call xy_dest
    call chunk_pix
hl_done:
    pop si
    pop bp
    ret
linear_hline endp

; EAX = physical, DI = near destination. Carry on failure. EAX preserved.
load_di proc near
    push eax
    push 4
    push di
    push eax
    call lfb_load
    add sp,8
    mov dx,ax
    pop eax
    or dx,dx
    jnz load_ok
    stc
    ret
load_ok:
    clc
    ret
load_di endp

; Carry when four bytes at EAX change after an A5 5A store at B800:0.
spot proc near
    push eax
    mov ax,0b800h
    mov es,ax
    mov ax,text_saved
    mov es:[0],ax
    pop eax
    mov di,offset pix
    call load_di
    jc spot_bad
    mov ax,0b800h
    mov es,ax
    mov word ptr es:[0],0a55ah
    mov di,offset gfg
    call load_di
    jc spot_bad
    mov eax,pix
    cmp eax,gfg
    jne spot_bad
    clc
    ret
spot_bad:
    stc
    ret
spot endp

text_ram proc near
    push ds
    mov ax,0b800h
    mov ds,ax
    mov bx,ds:[0]
    mov byte ptr ds:[0],55h
    cmp byte ptr ds:[0],55h
    jne tr_bad
    mov byte ptr ds:[0],0aah
    cmp byte ptr ds:[0],0aah
    jne tr_bad
    mov ds:[0],bx
    pop ds
    clc
    ret
tr_bad:
    mov ds:[0],bx
    pop ds
    stc
    ret
text_ram endp

alias_restore proc near
    mov ax,0b800h
    mov es,ax
    mov bx,text_saved
    mov es:[0],bx
    ret
alias_restore endp

alias_scan proc near
    mov eax,dword ptr screen+24
    call spot
    jc as_bad
    mov edx,plane_bytes
    cmp edx,18004h
    jb as_ok
    mov eax,dword ptr screen+24
    add eax,18000h
    call spot
    jc as_bad
as_ok:
    call alias_restore
    clc
    ret
as_bad:
    call alias_restore
    stc
    ret
alias_scan endp

linear_text_isolated proc near
    call text_ram
    jc iso_no
    mov text_saved,bx
    call alias_scan
    jc iso_no
    mov ax,1
    ret
iso_no:
    xor ax,ax
    ret
linear_text_isolated endp

; Direct B800 has one 4 KiB page. 43/50 rows need the banked window path.
linear_bind_text proc near
    mov banked_text,0
    mov page_count,1
    call linear_text_isolated
    or ax,ax
    jz bind_ret
    cmp text_rows,25
    jbe bind_ret
    xor ax,ax
bind_ret:
    ret
linear_bind_text endp

linear_cursor proc near
    push bp
    mov bp,sp
    push si
    push di
    mov cx,pixel_scale
    or cx,cx
    jnz cu_sc
    inc cx
cu_sc:
    mov ax,[bp+6]
    cmp ax,16
    jbe cu_h
    mov ax,16
cu_h:
    mul font_body_height
    add ax,15
    shr ax,4
    mul cx
    mov di,ax
    or di,di
    jz cu_off
    mov ax,font_width
    mul cx
    mov si,ax
    mov bl,byte ptr [bp+4]
    mov bh,byte ptr [bp+5]
    call cell_xy
    push ax
    mov ax,font_body_height
    mul cx
    add bx,ax
    pop ax
    sub bx,di
    push ax
    push bx
    call begin_draw
    mov dx,ax
    pop bx
    pop ax
    or dx,dx
    jz cu_off
    call xy_dest
    mov al,linear_bpp_bytes
    xor ah,ah
    mov pixsz,ax
    mov eax,linear_xor_mask
    mov color,eax
    mov op,5
    mov cx,di
cu_row:
    push cx
    mov eax,dest
    mov src,eax
    mov cx,si
    call chunk_pix
    pop cx
    or ax,ax
    jz cu_end
    movzx eax,display_pitch
    add eax,src
    mov dest,eax
    loop cu_row
cu_end:
    call end_draw
cu_off:
    pop di
    pop si
    pop bp
    ret
linear_cursor endp

linear_scroll proc near
    push bp
    mov bp,sp
    mov cx,pixel_scale
    or cx,cx
    jnz sl_sc
    inc cx
sl_sc:
    mov ax,font_width
    mul cx
    mov bx,80
    mul bx
    mov bl,linear_bpp_bytes
    xor bh,bh
    mul bx
    or dx,dx
    jnz sl_no
    or ax,ax
    jz sl_no
    mov line_bytes,ax
    mov ax,raster_height
    mul cx
    mov row_px,ax
    mov ax,[bp+6]
    sub ax,[bp+4]
    inc ax
    sub ax,[bp+8]
    mul row_px
    mov pix_lines,ax
    mov ax,[bp+8]
    mul row_px
    mul display_pitch
    mov word ptr distance,ax
    mov word ptr distance+2,dx
    mov ax,[bp+4]
    mul row_px
    add ax,viewport_y
    mov bx,ax
    mov ax,viewport_x
    call xy_dest
    mov eax,dest
    mov origin,eax
    call begin_draw
    or ax,ax
    jz sl_no
    mov cx,pix_lines
    jcxz sl_done
sl_row:
    mov ax,pix_lines
    sub ax,cx
    cmp word ptr [bp+10],0
    je sl_idx
    mov ax,cx
    dec ax
sl_idx:
    mul display_pitch
    add ax,word ptr origin
    adc dx,word ptr origin+2
    mov word ptr dest,ax
    mov word ptr dest+2,dx
    add ax,word ptr distance
    adc dx,word ptr distance+2
    mov word ptr src,ax
    mov word ptr src+2,dx
    cmp word ptr [bp+10],0
    je sl_copy
    mov eax,dest
    xchg eax,src
    mov dest,eax
sl_copy:
    push cx
    mov cx,line_bytes
    mov counting,1
    call copy_bytes
    pop cx
    or ax,ax
    jz sl_fail
    loop sl_row
sl_done:
    call end_draw
    mov ax,1
    jmp short sl_ret
sl_fail:
    call end_draw
sl_no:
    xor ax,ax
sl_ret:
    pop bp
    ret
linear_scroll endp

; Write path only. AH=0Dh readback is omitted so the resident image fits.
linear_pixel proc near
    push bp
    mov bp,sp
    cmp word ptr [bp+10],0
    je px_zero
    call begin_draw
    or ax,ax
    jz px_zero
    mov ax,[bp+4]
    mov bx,[bp+6]
    call xy_dest
    mov ax,[bp+8]
    mov op,3
    test al,80h
    jz px_color
    mov op,5
px_color:
    and ax,15
    shl ax,2
    mov bx,ax
    mov eax,linear_palette[bx]
    mov color,eax
    mov al,linear_bpp_bytes
    xor ah,ah
    mov pixsz,ax
    mov cx,1
    call chunk_pix
    call end_draw
px_zero:
    xor ax,ax
    pop bp
    ret
linear_pixel endp

linear_read proc near
    push bp
    mov bp,sp
    call begin_draw
    or ax,ax
    jz rd_done
    movzx edx,word ptr [bp+8]
    shl edx,4
    movzx eax,word ptr [bp+10]
    add edx,eax
    mov dest,edx
    mov eax,dword ptr screen+24
    add eax,[bp+4]
    mov src,eax
    mov cx,[bp+12]
    mov counting,0
    call copy_bytes
    call end_draw
rd_done:
    pop bp
    ret
linear_read endp

; col, row, count, background color. AX=1 when every scanline stored.
solid_run proc near
    push bp
    mov bp,sp
    sub sp,8
    push si
    push di
    push bx
    push cx
    push es
    mov cx,pixel_scale
    or cx,cx
    jnz sr_sc
    inc cx
sr_sc:
    mov ax,font_width
    mul cx
    mov si,ax
    mov ax,[bp+8]
    mul si
    mov [bp-6],ax
    mov ax,[bp+4]
    mul si
    add ax,viewport_x
    mov [bp-2],ax
    mov ax,raster_height
    mul cx
    mov [bp-8],ax
    mov si,ax
    mov ax,[bp+6]
    mul si
    add ax,viewport_y
    mov [bp-4],ax
    xor cx,cx
sr_line:
    cmp cx,[bp-8]
    jae sr_ok
    push cx
    mov ax,[bp-4]
    add ax,cx
    push word ptr [bp+10]
    push word ptr [bp-6]
    push ax
    push word ptr [bp-2]
    call linear_hline
    add sp,8
    pop cx
    cmp byte ptr active,0
    je sr_bad
    inc cx
    jmp sr_line
sr_ok:
    mov ax,1
    jmp short sr_leave
sr_bad:
    xor ax,ax
sr_leave:
    pop es
    pop cx
    pop bx
    pop di
    pop si
    mov sp,bp
    pop bp
    ret
solid_run endp

; Fill horizontal runs of dirty spaces, then mark those shadow cells current
; so the glyph walk skips them. A custom space bitmap still uses font_draw.
linear_paint_spaces proc near
    push si
    push di
    push bp
    push ds
    push es
    test byte ptr font_custom[32],1
    jnz sp_done
    push cs
    pop ds
    cmp byte ptr banked_text,0
    je sp_live
    push cs
    pop es
    mov si,offset text_transfer
    jmp short sp_set
sp_live:
    mov ax,active_page
    mul page_bytes
    mov cl,4
    shr ax,cl
    add ax,0b800h
    mov es,ax
    xor si,si
sp_set:
    mov di,offset shadow
    mov cx,text_cells
sp_loop:
    or cx,cx
    jnz sp_body
    jmp sp_done
sp_body:
    mov ax,es:[si]
    cmp ax,[di]
    je sp_skip
    cmp al,20h
    jne sp_skip
    mov bx,ax
    mov line_bytes,di
    mov ax,di
    sub ax,offset shadow
    shr ax,1
    xor dx,dx
    push bx
    mov bx,80
    div bx
    pop bx
    mov row_px,dx
    push ax
    xor bp,bp
sp_run:
    inc bp
    add si,2
    add di,2
    dec cx
    jz sp_emit
    mov ax,row_px
    add ax,bp
    cmp ax,80
    jae sp_emit
    mov ax,es:[si]
    cmp ax,bx
    jne sp_emit
    cmp ax,[di]
    je sp_emit
    jmp sp_run
sp_emit:
    mov pix_lines,bp
    pop ax
    mov dx,row_px
    mov bp,bx
    shr bp,12
    push bp
    push pix_lines
    push ax
    push dx
    call solid_run
    add sp,8
    mov bp,line_bytes
    mov dx,pix_lines
    or ax,ax
    jz sp_loop
    mov ax,bx
sp_sh:
    mov [bp],ax
    add bp,2
    dec dx
    jnz sp_sh
    jmp sp_loop
sp_skip:
    add si,2
    add di,2
    dec cx
    jmp sp_loop
sp_done:
    pop es
    pop ds
    pop bp
    pop di
    pop si
    ret
linear_paint_spaces endp

end

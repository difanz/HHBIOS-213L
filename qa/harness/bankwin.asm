; Real-mode VBE 64 KiB window paint bench. No CR0, VCPI, or DPMI.
; Far-calls WinFuncPtr when the mode info provides it; INT 10h AX=4F05h
; is the other switch. Grid matches the 114h console: 80 columns of 10x23
; from HH20.FNT, 25 text rows, plus the 23-line status band.
; PIT channel 0, milliseconds = counts / 1193.
; BANKWIN S times only the scroll sample.
;
;   jwasm -3 -bin -FoBANKWIN.COM qa/harness/bankwin.asm
.386
CSEG SEGMENT USE16
        ASSUME CS:CSEG, DS:CSEG
        ORG 100H

START:  JMP MAIN

fname   db 'HH20.FNT',0
outname db 'BENCH.TXT',0
fh      dw 0
oh      dw 0
mode_n  dw 0
modes   dw 400 dup (0)
bench_n dw 0
bench   dw 8 dup (0)
pitch   dw 0
scr_w   dw 0
scr_h   dw 0
bpp     db 0
bpp_b   dw 2
win_mem dw 0A000H
win_bx  dw 0
bank_step dw 1
gran_kb dw 64
win_size dw 64
win_ptr dd 0
have_fn db 0
use_far db 0
far_ok  db 0
int_ok  db 0
phys    dd 0
cur_win dw 0FFFFH
switches dd 0
written dd 0
pix_left dd 0
lin_off dd 0
src_off dd 0
xfer_left dd 0
only_sc db 0
color   dd 0
fg_col  dd 0
bg_col  dd 0
row_bits dd 0
cell_x  dw 0
cell_y  dw 0
run_left dw 0
run_x   dw 0
run_n   dw 0
g_row   dw 0
bit_sh  db 0
ink     db 0
failed  db 0
fr_x    dw 0
fr_y    dw 0
fr_w    dw 0
fr_h    dw 0
fr_i    dw 0
sc_i    dw 0
cur_mode dw 0
start_pit dd 0
sample_counts dd 0

hdr     db 32 dup (0)
recbuf  db 80 dup (0)
GLYPHS  equ 36
bits    dd GLYPHS * 23 dup (0)
scratch db 4096 dup (0)
vbe     db 512 dup (0)
minfo   db 256 dup (0)
linebuf db 180 dup (0)
linelen dw 0

codes   dw 0020H
        dw 0041H,0042H,0043H,0044H,0045H,0046H,0047H,0048H,0049H,004AH
        dw 004BH,004CH,004DH,004EH,004FH,0050H,0051H,0052H,0053H,0054H
        dw 0055H,0056H,0057H,0058H,0059H,005AH
        dw 0D6D0H,0B9FAH,0BABAH,0D7D6H,0CFB5H,0CDB3H,0B2E2H,0CAD4H
        dw 0CEC4H

s_ok    db 'STATUS=ok',0
s_nf    db 'STATUS=nofont',0
s_nv    db 'STATUS=novbe',0
s_vbe   db 'VBE=',0
s_cat   db 'CATALOG mode=',0
s_bank  db ' bank=',0
s_w     db ' w=',0
s_h     db ' h=',0
s_bpp   db ' bpp=',0
s_pitch db ' pitch=',0
s_seg   db ' seg=',0
s_gran  db ' gran=',0
s_size  db ' size=',0
s_func  db ' func=',0
s_phys  db ' phys=',0
s_yes   db 'yes',0
s_no    db 'no',0
s_bench db 'BENCH mode=',0
s_method db ' method=',0
s_far   db 'far',0
s_int   db 'int',0
s_probe db 'PROBE mode=',0
s_farf  db ' far=',0
s_intf  db ' int=',0
s_skip  db 'MODES=',0
s_fail  db ' FAIL=1',0
s_counts db ' counts=',0
s_ms    db ' ms=',0
s_sw    db ' switches=',0
s_bytes db ' bytes=',0
s_blank db 'FULL_BLANK',0
s_blank2 db 'FULL_BLANK2',0
s_sparse db 'SPARSE4',0
s_line  db 'LINE80',0
s_scroll db 'SCROLL1',0
s_hanzi db 'FULL_HANZI',0
s_hanzi2 db 'FULL_HANZI2',0

putc    proc near
        push bx
        mov bx,linelen
        cmp bx,170
        jae pc_skip
        mov linebuf[bx],al
        inc linelen
pc_skip:
        pop bx
        ret
putc    endp

puts    proc near
ps_l:   lodsb
        test al,al
        jz ps_d
        call putc
        jmp ps_l
ps_d:   ret
puts    endp

crlf    proc near
        mov al,13
        call putc
        mov al,10
        call putc
        mov ah,40H
        mov bx,oh
        mov cx,linelen
        mov dx,offset linebuf
        int 21H
        mov ah,68H
        mov bx,oh
        int 21H
        mov linelen,0
        ret
crlf    endp

puthex4 proc near
        push cx
        mov cx,4
ph_l:   rol ax,4
        push ax
        and al,0FH
        cmp al,10
        jb ph_d
        add al,'A'-10-'0'
ph_d:   add al,'0'
        call putc
        pop ax
        loop ph_l
        pop cx
        ret
puthex4 endp

puthex8 proc near
        ; EAX
        push eax
        shr eax,16
        call puthex4
        pop eax
        call puthex4
        ret
puthex8 endp

putdec  proc near
        push ebx
        push ecx
        push edx
        xor cx,cx
        mov ebx,10
pd_div: xor edx,edx
        div ebx
        push dx
        inc cx
        test eax,eax
        jnz pd_div
pd_out: pop ax
        add al,'0'
        call putc
        loop pd_out
        pop edx
        pop ecx
        pop ebx
        ret
putdec  endp

seek    proc near
        ; EAX = file offset
        push bx
        push cx
        mov dx,ax
        shr eax,16
        mov cx,ax
        mov ax,4200H
        mov bx,fh
        int 21H
        pop cx
        pop bx
        ret
seek    endp

load_font proc near
        mov ax,3D00H
        mov dx,offset fname
        int 21H
        jc lf_bad
        mov fh,ax
        mov ah,3FH
        mov bx,fh
        mov cx,32
        mov dx,offset hdr
        int 21H
        jc lf_bad
        cmp ax,32
        jne lf_bad
        cmp byte ptr hdr,'H'
        jne lf_bad
        cmp word ptr hdr+8,10
        jne lf_bad
        cmp word ptr hdr+10,23
        jne lf_bad
        xor bx,bx
lf_one: mov ax,codes[bx]
        call load_glyph
        jc lf_bad
        add bx,2
        cmp bx,GLYPHS*2
        jb lf_one
        mov ah,3EH
        mov bx,fh
        int 21H
        clc
        ret
lf_bad: stc
        ret
load_font endp

; AX = code, BX = glyph index * 2. BX is preserved by the caller via push.
load_glyph proc near
        push bx
        mov cx,ax
        test ch,ch
        jnz lg_hz
        movzx eax,cx
        jmp lg_map
lg_hz:  movzx eax,ch
        sub eax,0A1H
        imul eax,94
        movzx edx,cl
        sub edx,0A1H
        add eax,edx
        add eax,256
lg_map: shl eax,1
        add eax,32
        call seek
        mov ah,3FH
        mov bx,fh
        mov cx,2
        mov dx,offset recbuf
        int 21H
        jc lg_bad
        cmp ax,2
        jne lg_bad
        movzx eax,word ptr recbuf
        mov ecx,70
        mul ecx
        add eax,32+33736
        call seek
        mov ah,3FH
        mov bx,fh
        mov cx,70
        mov dx,offset recbuf
        int 21H
        jc lg_bad
        cmp ax,70
        jne lg_bad
        pop bx
        mov ax,bx
        mov cx,46
        mul cx
        mov di,offset bits
        add di,ax
        mov si,offset recbuf
        mov cx,23
lg_exp: mov al,[si]
        mov ah,[si+1]
        mov dl,[si+2]
        mov [di],ax
        mov [di+2],dl
        mov byte ptr [di+3],0
        add si,3
        add di,4
        loop lg_exp
        clc
        ret
lg_bad: pop bx
        stc
        ret
load_glyph endp

set_window proc near
        cmp dx,cur_win
        je sw_ret
        mov cur_win,dx
        add dword ptr switches,1
        cmp use_far,0
        je sw_int
        pusha
        push ds
        push es
        mov ax,4F05H
        mov bx,win_bx
        mov dx,cur_win
        call dword ptr win_ptr
        pop es
        pop ds
        popa
        ret
sw_int: pusha
        mov ax,4F05H
        mov bx,win_bx
        mov dx,cur_win
        int 10H
        popa
sw_ret: ret
set_window endp

; EAX = linear byte offset, ECX = pixels. color is the stored dword.
store_pix proc near
        mov pix_left,ecx
        mov lin_off,eax
sp_loop:
        cmp dword ptr pix_left,0
        je sp_done
        mov eax,lin_off
        shr eax,16
        movzx eax,ax
        movzx edx,bank_step
        mul edx
        mov dx,ax
        call set_window
        mov eax,lin_off
        and eax,0FFFFH
        mov ebx,10000H
        sub ebx,eax
        mov ecx,pix_left
        cmp bpp_b,2
        jne sp_b4
        shl ecx,1
        jmp sp_cmp
sp_b4:  shl ecx,2
sp_cmp: cmp ecx,ebx
        jbe sp_got
        mov ecx,ebx
sp_got: test ecx,ecx
        jz sp_fail
        push ecx
        mov es,win_mem
        mov di,word ptr lin_off
        cmp bpp_b,2
        jne sp_d32
        shr ecx,1
        jz sp_popfail
        mov ax,word ptr color
        rep stosw
        jmp sp_acc
sp_d32: shr ecx,2
        jz sp_popfail
        mov eax,color
        rep stosd
sp_acc: pop ecx
        add lin_off,ecx
        add dword ptr written,ecx
        cmp bpp_b,2
        jne sp_sub4
        shr ecx,1
        sub pix_left,ecx
        jmp sp_loop
sp_sub4:
        shr ecx,2
        sub pix_left,ecx
        jmp sp_loop
sp_popfail:
        pop ecx
sp_fail:
        mov failed,1
sp_done:
        ret
store_pix endp

; AX=x BX=y CX=width DX=height, solid color already in `color`.
fill_rect proc near
        mov fr_x,ax
        mov fr_y,bx
        mov fr_w,cx
        mov fr_h,dx
        mov fr_i,0
fr_l:   mov ax,fr_i
        cmp ax,fr_h
        jae fr_d
        mov ax,fr_y
        add ax,fr_i
        movzx eax,ax
        movzx edx,pitch
        mul edx
        movzx edx,fr_x
        movzx ecx,bpp_b
        imul edx,ecx
        add eax,edx
        movzx ecx,fr_w
        call store_pix
        inc fr_i
        jmp fr_l
fr_d:   ret
fill_rect endp

; SI = glyph dwords, AX = x, BX = y, CL = first bit. 10x23.
paint_half proc near
        push si
        mov cell_x,ax
        mov cell_y,bx
        mov bit_sh,cl
        mov g_row,0
ph_row: cmp g_row,23
        jae ph_done
        mov eax,[si]
        add si,4
        xchg al,ah
        rol eax,16
        xchg al,ah
        mov cl,bit_sh
        shl eax,cl
        mov row_bits,eax
        mov run_left,10
        mov ax,cell_x
        mov run_x,ax
ph_run: cmp run_left,0
        je ph_next
        mov eax,row_bits
        mov edx,eax
        rol edx,1
        and edx,1
        mov ink,dl
        test edx,edx
        jnz ph_one
        bsr ecx,eax
        jz ph_all
        neg ecx
        add ecx,31
        jmp ph_fit
ph_one: mov ecx,eax
        not ecx
        bsr ecx,ecx
        jz ph_all
        neg ecx
        add ecx,31
ph_fit: test ecx,ecx
        jz ph_all
        cmp cx,run_left
        jbe ph_keep
        mov cx,run_left
ph_keep: sub run_left,cx
        mov eax,row_bits
        shl eax,cl
        mov row_bits,eax
        jmp ph_put
ph_all: mov cx,run_left
        mov run_left,0
ph_put: mov run_n,cx
        cmp ink,0
        je ph_bg
        mov eax,fg_col
        jmp ph_col
ph_bg:  mov eax,bg_col
ph_col: mov color,eax
        mov ax,cell_y
        add ax,g_row
        movzx eax,ax
        movzx edx,pitch
        mul edx
        movzx edx,run_x
        movzx ecx,bpp_b
        imul edx,ecx
        add eax,edx
        movzx ecx,run_n
        call store_pix
        mov ax,run_x
        add ax,run_n
        mov run_x,ax
        cmp failed,0
        jne ph_done
        jmp ph_run
ph_next:
        inc g_row
        jmp ph_row
ph_done:
        pop si
        ret
paint_half endp

; AX = glyph index. Returns SI.
glyph_ptr proc near
        mov cx,92
        mul cx
        mov si,offset bits
        add si,ax
        ret
glyph_ptr endp

paint_status proc near
        mov eax,bg_col
        mov color,eax
        xor ax,ax
        mov bx,25*23
        mov cx,800
        mov dx,23
        call fill_rect
        ret
paint_status endp

do_blank proc near
        mov eax,bg_col
        mov color,eax
        xor ax,ax
        xor bx,bx
        mov cx,800
        mov dx,26*23
        call fill_rect
        ret
do_blank endp

do_sparse proc near
        mov ax,27
        call glyph_ptr
        mov ax,100
        mov bx,46
        xor cl,cl
        call paint_half
        mov ax,27
        call glyph_ptr
        mov ax,110
        mov bx,46
        mov cl,10
        call paint_half
        mov ax,35
        call glyph_ptr
        mov ax,120
        mov bx,46
        xor cl,cl
        call paint_half
        mov ax,35
        call glyph_ptr
        mov ax,130
        mov bx,46
        mov cl,10
        call paint_half
        call paint_status
        ret
do_sparse endp

do_line proc near
        xor bx,bx
dl_c:   cmp bx,80
        jae dl_d
        mov ax,bx
        xor dx,dx
        mov cx,26
        div cx
        mov ax,dx
        inc ax
        call glyph_ptr
        mov ax,bx
        mov cx,10
        mul cx
        push bx
        mov bx,10*23
        xor cl,cl
        call paint_half
        pop bx
        inc bx
        cmp failed,0
        je dl_c
dl_d:   call paint_status
        ret
do_line endp

; EAX = destination linear byte, EDX = source, ECX = even byte count.
; Copies through the 4 KiB scratch, switching only when a window changes.
copy_span proc near
        mov lin_off,eax
        mov src_off,edx
        mov xfer_left,ecx
cs_l:   cmp dword ptr xfer_left,0
        je cs_d
        mov eax,src_off
        shr eax,16
        movzx eax,ax
        movzx edx,bank_step
        mul edx
        mov dx,ax
        call set_window
        mov eax,src_off
        and eax,0FFFFH
        mov ebx,10000H
        sub ebx,eax
        mov eax,lin_off
        and eax,0FFFFH
        mov edx,10000H
        sub edx,eax
        cmp ebx,edx
        jbe cs_lim1
        mov ebx,edx
cs_lim1:
        cmp ebx,4096
        jbe cs_lim2
        mov ebx,4096
cs_lim2:
        cmp ebx,xfer_left
        jbe cs_lim3
        mov ebx,xfer_left
cs_lim3:
        and ebx,0FFFFFFFEh
        jz cs_bad
        cld
        mov cx,bx
        shr cx,1
        push ds
        mov si,word ptr src_off
        mov ax,win_mem
        mov ds,ax
        mov ax,cs
        mov es,ax
        mov di,offset scratch
        rep movsw
        pop ds
        mov eax,lin_off
        shr eax,16
        movzx eax,ax
        movzx edx,bank_step
        mul edx
        mov dx,ax
        call set_window
        cld
        mov cx,bx
        shr cx,1
        mov si,offset scratch
        mov es,win_mem
        mov di,word ptr lin_off
        rep movsw
        add dword ptr written,ebx
        add src_off,ebx
        add lin_off,ebx
        sub xfer_left,ebx
        jmp cs_l
cs_bad: mov failed,1
cs_d:   ret
copy_span endp

do_scroll proc near
        ; 800 pixels of 16 bpp is the whole pitch at 114h, so the text
        ; grid is one contiguous span. A wider pitch stays line-by-line.
        movzx eax,bpp_b
        mov edx,800
        mul edx
        movzx ebx,pitch
        cmp eax,ebx
        jne dsc_lines
        movzx eax,pitch
        mov edx,23
        mul edx
        mov src_off,eax
        movzx eax,pitch
        mov edx,24*23
        mul edx
        mov ecx,eax
        xor eax,eax
        mov edx,src_off
        call copy_span
        jmp dsc_c
dsc_lines:
        mov sc_i,0
dsc_l:  mov ax,sc_i
        cmp ax,24*23
        jae dsc_c
        movzx eax,ax
        add eax,23
        movzx edx,pitch
        mul edx
        mov src_off,eax
        movzx eax,sc_i
        movzx edx,pitch
        mul edx
        mov edx,src_off
        movzx ecx,bpp_b
        imul ecx,800
        call copy_span
        inc sc_i
        cmp failed,0
        je dsc_l
dsc_c:  mov eax,bg_col
        mov color,eax
        xor ax,ax
        mov bx,24*23
        mov cx,800
        mov dx,23
        call fill_rect
        ret
do_scroll endp

do_hanzi proc near
        xor cx,cx
dh_l:   cmp cx,80*25
        jae dh_d
        push cx
        mov ax,cx
        shr ax,1
        inc ax
        and ax,7
        add ax,27
        call glyph_ptr
        pop cx
        push cx
        mov ax,cx
        xor dx,dx
        mov bx,80
        div bx
        ; AX = row, DX = col
        push ax
        mov ax,dx
        mov bx,10
        mul bx
        pop bx
        push ax
        mov ax,bx
        mov bx,23
        mul bx
        mov bx,ax
        pop ax
        pop cx
        push cx
        test cl,1
        jnz dh_r
        xor cl,cl
        jmp dh_p
dh_r:   mov cl,10
dh_p:   call paint_half
        pop cx
        inc cx
        cmp failed,0
        je dh_l
dh_d:   call paint_status
        ret
do_hanzi endp

pit_now proc near
pn_l:   cli
        mov ax,40H
        mov es,ax
        mov bx,es:[6CH]
        mov al,0
        out 43H,al
        in al,40H
        mov ah,al
        in al,40H
        xchg al,ah
        mov cx,es:[6CH]
        sti
        cmp bx,cx
        jne pn_l
        mov cx,ax
        movzx eax,bx
        shl eax,16
        movzx ecx,cx
        test cx,cx
        jz pn_z
        neg cx
        movzx ecx,cx
        add eax,ecx
        ret
pn_z:   ret
pit_now endp

; SI = sample name, workload is a near pointer in BX? We'll just call after timing setup.
; time_call: SI = name, DI = routine
time_call proc near
        mov dword ptr switches,0
        mov dword ptr written,0
        mov cur_win,0FFFFH
        mov failed,0
        push si
        call pit_now
        mov start_pit,eax
        call di
        call pit_now
        sub eax,start_pit
tc_fix: test eax,eax
        jns tc_okc
        add eax,65536
        jmp tc_fix
tc_okc: mov sample_counts,eax
        pop si
        call puts
        mov si,offset s_counts
        call puts
        mov eax,sample_counts
        call putdec
        mov si,offset s_ms
        call puts
        mov eax,sample_counts
        xor edx,edx
        mov ebx,1193
        div ebx
        call putdec
        mov si,offset s_sw
        call puts
        mov eax,switches
        call putdec
        mov si,offset s_bytes
        call puts
        mov eax,written
        call putdec
        cmp failed,0
        je tc_ok
        mov si,offset s_fail
        call puts
tc_ok:  call crlf
        ret
time_call endp

run_suite proc near
        cmp only_sc,0
        je rs_all
        mov si,offset s_scroll
        mov di,offset do_scroll
        call time_call
        ret
rs_all: mov si,offset s_blank
        mov di,offset do_blank
        call time_call
        mov si,offset s_sparse
        mov di,offset do_sparse
        call time_call
        mov si,offset s_line
        mov di,offset do_line
        call time_call
        mov si,offset s_scroll
        mov di,offset do_scroll
        call time_call
        mov si,offset s_hanzi
        mov di,offset do_hanzi
        call time_call
        ret
run_suite endp

run_suite2 proc near
        mov si,offset s_blank2
        mov di,offset do_blank
        call time_call
        mov si,offset s_hanzi2
        mov di,offset do_hanzi
        call time_call
        ret
run_suite2 endp

probe_one proc near
        ; use_far is set by the caller. Returns AL=1 on success.
        mov dword ptr switches,0
        mov cur_win,0FFFFH
        xor dx,dx
        call set_window
        mov es,win_mem
        mov word ptr es:[0],1234H
        mov dx,bank_step
        mov cur_win,0FFFFH
        call set_window
        mov es,win_mem
        mov word ptr es:[0],0ABCDH
        xor dx,dx
        mov cur_win,0FFFFH
        call set_window
        mov es,win_mem
        cmp word ptr es:[0],1234H
        jne pr_bad
        mov al,1
        ret
pr_bad: xor al,al
        ret
probe_one endp

read_mode proc near
        ; CX = mode. Fills minfo. Carry on failure.
        push cx
        push ds
        pop es
        mov di,offset minfo
        mov cx,256
        xor al,al
        rep stosb
        pop cx
        mov ax,4F01H
        mov di,offset minfo
        push ds
        pop es
        int 10H
        cmp ax,004FH
        jne rm_bad
        clc
        ret
rm_bad: stc
        ret
read_mode endp

; Parse minfo. Sets carry if the record is not direct-color.
parse_mode proc near
        mov ax,word ptr minfo
        and ax,0019H
        cmp ax,0019H
        jne pm_bad
        cmp byte ptr minfo+27,6
        jne pm_bad
        mov al,minfo+25
        mov bpp,al
        cmp al,15
        je pm_geom
        cmp al,16
        je pm_geom
        cmp al,32
        jne pm_bad
pm_geom:
        mov ax,word ptr minfo+18
        mov scr_w,ax
        mov ax,word ptr minfo+20
        mov scr_h,ax
        mov ax,word ptr minfo+16
        mov pitch,ax
        mov eax,dword ptr minfo+40
        mov phys,eax
        mov have_fn,0
        mov win_ptr,0
        mov win_mem,0
        mov gran_kb,0
        mov win_size,0
        mov al,minfo+2
        and al,6
        cmp al,6
        jne pm_wb
        mov win_bx,0
        mov ax,word ptr minfo+8
        jmp pm_wgot
pm_wb:  mov al,minfo+3
        and al,6
        cmp al,6
        jne pm_wnone
        mov win_bx,1
        mov ax,word ptr minfo+10
pm_wgot:
        mov win_mem,ax
        mov ax,word ptr minfo+4
        mov gran_kb,ax
        mov ax,word ptr minfo+6
        mov win_size,ax
        mov eax,dword ptr minfo+12
        mov win_ptr,eax
        test eax,eax
        jz pm_wnone
        mov have_fn,1
pm_wnone:
        clc
        ret
pm_bad: stc
        ret
parse_mode endp

; AL = 1 when this direct-color mode can be bank-painted.
bank_ok proc near
        cmp win_mem,0A000H
        jne bk_no
        cmp win_size,64
        jne bk_no
        cmp gran_kb,0
        je bk_no
        cmp gran_kb,64
        ja bk_no
        mov ax,64
        xor dx,dx
        div gran_kb
        test dx,dx
        jnz bk_no
        mov bank_step,ax
        mov al,1
        ret
bk_no:  xor al,al
        mov bank_step,1
        ret
bank_ok endp

emit_catalog proc near
        ; CX = mode
        push cx
        mov si,offset s_cat
        call puts
        pop ax
        push ax
        call puthex4
        mov si,offset s_bank
        call puts
        call bank_ok
        cmp al,1
        jne ec_no
        mov si,offset s_yes
        jmp ec_b
ec_no:  mov si,offset s_no
ec_b:   call puts
        mov si,offset s_w
        call puts
        movzx eax,scr_w
        call putdec
        mov si,offset s_h
        call puts
        movzx eax,scr_h
        call putdec
        mov si,offset s_bpp
        call puts
        movzx eax,bpp
        call putdec
        mov si,offset s_pitch
        call puts
        movzx eax,pitch
        call putdec
        mov si,offset s_seg
        call puts
        mov ax,win_mem
        call puthex4
        mov si,offset s_gran
        call puts
        movzx eax,gran_kb
        call putdec
        mov si,offset s_size
        call puts
        movzx eax,win_size
        call putdec
        mov si,offset s_func
        call puts
        cmp have_fn,0
        je ec_fn0
        mov si,offset s_yes
        jmp ec_fn
ec_fn0: mov si,offset s_no
ec_fn:  call puts
        mov si,offset s_phys
        call puts
        mov eax,phys
        call puthex8
        call crlf
        pop cx
        ret
emit_catalog endp

consider_bench proc near
        ; CX = mode. Keep 114h, 117h and 245h when they can be bank-painted.
        cmp cx,0114H
        je cb_yes
        cmp cx,0117H
        je cb_yes
        cmp cx,0245H
        jne cb_d
cb_yes: call bank_ok
        cmp al,1
        jne cb_d
        cmp scr_w,800
        jb cb_d
        cmp scr_h,598
        jb cb_d
        cmp pitch,0
        je cb_d
        test pitch,1
        jnz cb_d
        cmp cx,0114H
        jne cb_add
        ; Put 114h in slot 0 by swapping.
        cmp bench_n,0
        jne cb_swap
        mov bench,cx
        mov bench_n,1
        jmp cb_d
cb_swap:
        mov ax,bench
        mov bench,cx
        mov bx,bench_n
        cmp bx,8
        jb cb_fit
        mov bx,7
cb_fit: shl bx,1
        mov bench[bx],ax
        cmp bench_n,8
        jae cb_d
        inc bench_n
        jmp cb_d
cb_add: cmp bench_n,8
        jae cb_d
        mov bx,bench_n
        shl bx,1
        mov bench[bx],cx
        inc bench_n
cb_d:   ret
consider_bench endp

set_colors proc near
        cmp bpp,32
        je sc32
        mov fg_col,0FFE0H
        mov bg_col,0001FH
        mov bpp_b,2
        ret
sc32:   mov fg_col,00FFFF00H
        mov bg_col,000000FFH
        mov bpp_b,4
        ret
set_colors endp

emit_bench_hdr proc near
        mov si,offset s_bench
        call puts
        mov ax,cur_mode
        call puthex4
        mov si,offset s_method
        call puts
        cmp use_far,0
        je eb_int
        mov si,offset s_far
        jmp eb_m
eb_int: mov si,offset s_int
eb_m:   call puts
        mov si,offset s_w
        call puts
        movzx eax,scr_w
        call putdec
        mov si,offset s_h
        call puts
        movzx eax,scr_h
        call putdec
        mov si,offset s_bpp
        call puts
        movzx eax,bpp
        call putdec
        mov si,offset s_pitch
        call puts
        movzx eax,pitch
        call putdec
        call crlf
        ret
emit_bench_hdr endp

bench_mode proc near
        ; CX = mode
        mov cur_mode,cx
        push cx
        mov ax,4F02H
        mov bx,cx
        int 10H
        cmp ax,004FH
        jne bm_fail
        pop cx
        push cx
        call read_mode
        jc bm_fail
        call parse_mode
        jc bm_fail
        call bank_ok
        cmp al,1
        jne bm_fail
        call set_colors
        mov far_ok,0
        mov int_ok,0
        cmp have_fn,0
        je bm_intf
        mov use_far,1
        call probe_one
        mov far_ok,al
bm_intf:
        mov use_far,0
        call probe_one
        mov int_ok,al
        pop cx
        push cx
        mov si,offset s_probe
        call puts
        pop ax
        push ax
        call puthex4
        mov si,offset s_farf
        call puts
        movzx eax,far_ok
        call putdec
        mov si,offset s_intf
        call puts
        movzx eax,int_ok
        call putdec
        call crlf
        pop cx
        cmp cx,0114H
        jne bm_one
        cmp far_ok,0
        je bm_114i
        mov use_far,1
        call emit_bench_hdr
        call run_suite
        cmp only_sc,0
        jne bm_done
        ; INT 10h AX=4F05h on 114h: same pixels, different window call.
bm_114i:
        cmp int_ok,0
        je bm_done
        mov use_far,0
        call emit_bench_hdr
        call run_suite
        jmp bm_done
bm_one: cmp far_ok,0
        je bm_onei
        mov use_far,1
        call emit_bench_hdr
        call run_suite
        jmp bm_done
bm_onei:
        cmp int_ok,0
        je bm_done
        mov use_far,0
        call emit_bench_hdr
        call run_suite
        jmp bm_done
bm_fail:
        pop cx
bm_done:
        ret
bench_mode endp

MAIN:   mov ax,cs
        mov ds,ax
        mov es,ax
        mov only_sc,0
        cmp byte ptr ds:[80H],2
        jb main_tail
        cmp byte ptr ds:[82H],'S'
        jne main_tail
        mov only_sc,1
main_tail:
        mov ah,3CH
        xor cx,cx
        mov dx,offset outname
        int 21H
        jc bye
        mov oh,ax
        call load_font
        jnc main_vbe
        mov si,offset s_nf
        call puts
        call crlf
        jmp bye_close
main_vbe:
        mov di,offset vbe
        mov cx,256
        xor ax,ax
        rep stosw
        push ds
        pop es
        ; JWasm stores a dword character constant last-byte-first.
        mov dword ptr vbe,'2EBV'
        mov ax,4F00H
        mov di,offset vbe
        push ds
        pop es
        int 10H
        cmp ax,004FH
        jne main_nv
        cmp dword ptr vbe,'ASEV'
        jne main_nv
        mov si,offset s_ok
        call puts
        call crlf
        mov si,offset s_vbe
        call puts
        mov ax,word ptr vbe+4
        call puthex4
        call crlf
        les si,dword ptr vbe+14
        xor bx,bx
ml_l:   mov ax,es:[si]
        cmp ax,0FFFFH
        je ml_d
        mov modes[bx],ax
        add si,2
        add bx,2
        cmp bx,800
        jb ml_l
ml_d:   shr bx,1
        mov mode_n,bx
        xor bx,bx
cat_l:  cmp bx,mode_n
        jae cat_d
        mov cx,modes[bx]
        push bx
        call read_mode
        jc cat_next
        call parse_mode
        jc cat_next
        call emit_catalog
        call consider_bench
cat_next:
        pop bx
        inc bx
        jmp cat_l
cat_d:  mov si,offset s_skip
        call puts
        movzx eax,mode_n
        call putdec
        call crlf
        xor bx,bx
bn_l:   cmp bx,bench_n
        jae bn_d
        push bx
        mov ax,bx
        shl ax,1
        mov bx,ax
        mov cx,bench[bx]
        call bench_mode
        pop bx
        inc bx
        jmp bn_l
bn_d:   mov ax,0003H
        int 10H
        jmp bye_close
main_nv:
        mov si,offset s_nv
        call puts
        call crlf
bye_close:
        mov ah,3EH
        mov bx,oh
        int 21H
bye:    mov ax,4C00H
        int 21H

CSEG ENDS
END START

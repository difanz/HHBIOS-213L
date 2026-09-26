; Independent 8086 display driver. No C runtime and no dependency on VGA.COM.
; C uses near __cdecl calls, DS=SS=CS on our private resident stack.
; IRQ0/INT10 preserve the interrupted stack and all registers; nested BIOS
; INT10 calls chain directly while busy. No DOS service is called resident.
.model tiny, c
.code
org 100h
public start
public int10_handler, int8_handler, old10, old8, stack_bottom, stack_top
public image_end, resident_end, S_UMB, umb_segment, resident_paragraphs
extrn initialize:near, dispatch:near, tick:near
extrn request:byte, screen:byte, resident_segment:word, keyboard_segment:word
extrn framebuffer:word, display_pitch:word, active_page:word
extrn resident_bytes:word
extrn display_start:word, split_line:word
extrn text_bank:word, banked_text_allowed:byte
extrn font_segment:word, font_offset:word, active:byte, busy:byte, traditional:byte
extrn direct:byte
start: jmp install

old10 dd 0
old8 dd 0
saved_ss dw 0
saved_sp dw 0
handled dw 0
public policy, hanzi, shadow, frame_alias_offset
hanzi db 1
D_B800 dw 0b800h
D_005A db 1
glyph_bits db 36 dup (0)
cell_attr db 0
plane_mask db 0
glyph_width db 1
cell_column db 0
hz_box db 0
plane_xor dw 0
plane_background dw 0
saved_gc db 9 dup (0)
saved_seq db 0
gc_index db 0
seq_index db 0
video_depth db 0
aperture_alias db 0ffh
public banked_text
banked_text db 0
aperture_result dw 1
frame_alias_offset dw offset D_ZBFB

; Register block on stack: AX BX CX DX SI DI BP DS ES FLAGS.
save_regs macro
    pushf
    push es
    push ds
    push bp
    push di
    push si
    push dx
    push cx
    push bx
    push ax
endm
load_regs macro
    pop ax
    pop bx
    pop cx
    pop dx
    pop si
    pop di
    pop bp
    pop ds
    pop es
    popf
endm

int10_handler proc far
    cmp cs:busy,0
    jne busy10
    mov cs:busy,1
    save_regs
    cld
    mov cs:saved_ss,ss
    mov cs:saved_sp,sp
    mov si,sp
    push ss
    pop ds
    push cs
    pop es
    mov di,offset request
    mov cx,10
    rep movsw
    ; The saved CPU FLAGS, not the flags modified by entry comparisons.
    mov ax,[si+4]
    mov word ptr es:request+18,ax
    mov ax,cs
    mov ss,ax
    mov sp,offset stack_top
    mov ds,ax
    test word ptr request+18,200h
    jz dispatch_interrupts
    sti
dispatch_interrupts:
    call dispatch
    cli
    mov cs:handled,ax
    mov es,cs:saved_ss
    mov di,cs:saved_sp
    mov si,offset request
    mov cx,10
    rep movsw
    ; Return flags belong to the interrupt frame as well.
    mov ax,word ptr request+18
    mov es:[di+4],ax
    mov ss,cs:saved_ss
    mov sp,cs:saved_sp
    mov cs:busy,0
    cmp cs:handled,0
    je pass10
    load_regs
    iret
pass10:
    load_regs
    jmp short chain10
busy10:
    ; Capture may be requested by another timer TSR while rendering. It must
    ; retry, not reuse our private C stack or read a half-switched window.
    cmp ax,1412h
    jne chain10
    mov ax,2
    iret
chain10:
    jmp cs:old10
int10_handler endp

int8_handler proc far
    pushf
    call cs:old8
    pushf
    cli
    cmp cs:busy,0
    jne timer_done
    mov cs:busy,1
    save_regs
    mov cs:saved_ss,ss
    mov cs:saved_sp,sp
    mov ax,cs
    mov ss,ax
    mov sp,offset stack_top
    mov ds,ax
    mov es,ax
    cld
    sti
    call tick
    cli
    mov ss,cs:saved_ss
    mov sp,cs:saved_sp
    mov cs:busy,0
    load_regs
timer_done:
    popf
    iret
int8_handler endp

public bios
bios proc near
    push bp
    mov bp,sp
    save_regs
    mov si,[bp+4]
    push si
    push word ptr [si+16]
    push word ptr [si+14]
    push word ptr [si+12]
    push word ptr [si+10]
    push word ptr [si+8]
    mov ax,[si]
    mov bx,[si+2]
    mov cx,[si+4]
    mov dx,[si+6]
    pop si
    pop di
    pop bp
    pop ds
    pop es
    pushf
    call cs:old10
    save_regs
    push cs
    pop ds
    mov bp,sp
    mov di,[bp+20]
    push cs
    pop es
    mov si,sp
    ; VBE returns status in AX; preserve the caller's interrupt FLAGS.
    mov cx,9
    rep movsw
    add sp,22
    load_regs
    pop bp
    ret
bios endp

; Set CPU B800 compatibility aperture. As on VGA, some cards alias the
; upper 64 KiB; put scanout around the unused B800 text area on those cards.
public aperture
aperture proc near
    save_regs
    mov cs:aperture_result,1
    cmp cs:banked_text,0
    jne aperture_banked
    mov dx,3ceh
    mov ax,0106h
    out dx,ax
    cmp cs:aperture_alias,0ffh
    jne aperture_config
    ; Do not infer availability from an all-FF bus read. Verify both values.
    mov ax,0b800h
    mov es,ax
    mov byte ptr es:[0],55h
    cmp byte ptr es:[0],55h
    jne aperture_limited
    mov byte ptr es:[0],0aah
    cmp byte ptr es:[0],0aah
    jne aperture_limited
    mov ax,0a000h
    mov ds,ax
    mov ax,0b000h
    mov es,ax
    mov al,ds:[0a000h]
    mov ah,es:[0a000h]
    push ax
    mov byte ptr ds:[0a000h],55h
    mov byte ptr es:[0a000h],0aah
    mov bl,ds:[0a000h]
    pop ax
    mov es:[0a000h],ah
    mov ds:[0a000h],al
    mov cs:aperture_alias,0
    cmp bl,0aah
    jne aperture_config
    mov cs:aperture_alias,1
aperture_config:
    mov cs:framebuffer,0a000h
    cmp cs:aperture_alias,1
    jne aperture_done
    mov bx,cs:display_start
    mov ax,bx
    mov cl,4
    shr ax,cl
    add ax,0a000h
    mov cs:framebuffer,ax
    mov dx,3d4h
    mov ah,bh
    mov al,0ch
    out dx,ax
    mov ah,bl
    mov al,0dh
    out dx,ax
    mov bx,cs:split_line
    mov ah,bl
    mov al,18h
    out dx,ax
    mov al,7
    out dx,al
    inc dx
    in al,dx
    and al,0efh
    test bh,1
    jz aperture_bit8
    or al,10h
aperture_bit8:
    out dx,al
    dec dx
    mov al,9
    out dx,al
    inc dx
    in al,dx
    and al,0bfh
    test bh,2
    jz aperture_bit9
    or al,40h
aperture_bit9:
    out dx,al
aperture_done:
    load_regs
    mov ax,cs:aperture_result
    ret
aperture_limited:
    cmp cs:banked_text_allowed,0
    je aperture_failed
    mov cs:banked_text,1
aperture_banked:
    mov cs:framebuffer,0a000h
    mov dx,cs:text_bank
    call select_bank
    jc aperture_failed
    mov dx,3ceh
    mov ax,0d06h
    out dx,ax
    cmp cs:aperture_alias,0ffh
    jne aperture_done
    mov ax,0b800h
    mov es,ax
    mov byte ptr es:[0],55h
    cmp byte ptr es:[0],55h
    jne aperture_failed
    mov byte ptr es:[0],0aah
    cmp byte ptr es:[0],0aah
    jne aperture_failed
    mov cs:aperture_alias,0
    jmp aperture_done
aperture_failed:
    mov cs:aperture_result,0
    jmp aperture_done
aperture endp

select_bank proc near
    save_regs
    mov ax,4f05h
    xor bx,bx
    mov bl,byte ptr cs:screen+14
    pushf
    call cs:old10
    cmp ax,004fh
    jne bank_failed
    load_regs
    clc
    ret
bank_failed:
    load_regs
    stc
    ret
select_bank endp

public invalidate
invalidate proc near
    mov cs:D_LASTMODE,0ffh
    ret
invalidate endp

; The classifier is shared verbatim with VGA/EGA/HGA. No translated FSM.
public refresh
refresh proc near
    save_regs
    call classifier_policy
    mov ds,cs:D_B800
    push cs
    pop es
    cmp cs:banked_text,0
    je refresh_ready
    xor si,si
    mov di,offset text_transfer
    mov cx,2000
    rep movsw
    mov ax,offset text_transfer
    mov cl,4
    shr ax,cl
    mov bx,cs
    add ax,bx
    mov cs:D_B800,ax
    mov ds,ax
refresh_ready:
    call video_begin
    jc refresh_done
    call S_XR
    call video_end
    cmp cs:active,0
    je refresh_done
    cmp cs:banked_text,0
    je refresh_done
    call classifier_policy
    mov es,cs:D_B800
    push cs
    pop ds
    mov si,offset text_transfer
    xor di,di
    mov cx,2000
    rep movsw
refresh_done:
    load_regs
    ret
refresh endp

classifier_policy proc near
    mov ax,cs:active_page
    mov cl,8
    shl ax,cl
    add ax,0b800h
    mov cs:D_B800,ax
    mov al,cs:direct
    mov cs:D_005A,al
    mov al,74h
    cmp cs:hanzi,0
    jne refresh_hanzi
    mov al,0ebh
refresh_hanzi:
    mov byte ptr cs:K_HZ1,al
    ret
classifier_policy endp

; Each glyph has a planar backend. Pixel pitch is explicit; classifier
; row/column values never stand for framebuffer byte offsets.
S_XSZF proc near
    push dx
    push bx
    push ax
    xor ah,ah
    mov cl,4
    shl ax,cl
    mov si,cs:font_offset
    add si,ax
    mov ds,cs:font_segment
    push cs
    pop es
    mov di,offset glyph_bits
    mov cx,8
    rep movsw
    xor ax,ax
    stosw
    pop ax
    cmp al,0b0h
    jb ascii_tail
    cmp al,0dfh
    ja ascii_tail
    mov ax,cs:word ptr glyph_bits+14
    mov cs:word ptr glyph_bits+16,ax
ascii_tail:
    pop bx
    pop dx
    push cs
    pop ds
    mov si,offset glyph_bits
    call blit_cell
    ret
S_XSZF endp

S_XSHZ proc near
    push dx
    push bx
    mov cs:hz_box,0
    cmp ah,0a9h
    jne hanzi_font
    mov cs:hz_box,1
hanzi_font:
    mov dx,ax
    mov ah,cs:traditional
    int 7fh
    mov ds,dx
    xor si,si
    mov di,offset glyph_bits
    mov cx,16
copy_hanzi:
    lodsw
    mov cs:[di],al
    mov cs:[di+18],ah
    inc di
    loop copy_hanzi
    mov word ptr cs:glyph_bits+16,0
    mov word ptr cs:glyph_bits+34,0
    cmp cs:hz_box,0
    je hanzi_tail
    mov ax,word ptr cs:glyph_bits+14
    mov word ptr cs:glyph_bits+16,ax
    mov ax,word ptr cs:glyph_bits+32
    mov word ptr cs:glyph_bits+34,ax
hanzi_tail:
    pop bx
    pop dx
    push cs
    pop ds
    push bx
    push dx
    mov bl,bh
    mov si,offset glyph_bits
    call blit_cell
    pop dx
    pop bx
    add dl,cs:glyph_width
    mov si,offset glyph_bits+18
    call blit_cell
    ret
S_XSHZ endp

; DS:SI points to 18 monochrome rows, BL is the complete text attribute.
; Write four planes with four sequencer changes, no per-pixel BIOS calls.
blit_cell proc near
    save_regs
    cmp dl,80
    jae blit_done
    cmp dh,25
    ja blit_done
    mov cs:cell_attr,bl
    mov cs:cell_column,dl
    mov di,dx
    xor ax,ax
    mov al,dh
    mov bx,18
    mul bx
    cmp di,1900h
    jb blit_position
    add ax,6
blit_position:
    mul cs:display_pitch
    and di,255
    add ax,di
    mov di,ax
    mov es,cs:framebuffer
    mov cs:plane_mask,1
blit_plane:
    push si
    push di
    mov dx,3c4h
    mov al,2
    mov ah,cs:plane_mask
    out dx,ax
    mov bl,cs:cell_attr
    xor ah,ah
    test bl,cs:plane_mask
    jz blit_fg
    not ah
blit_fg:
    mov cl,4
    shr bl,cl
    mov bh,0
    test bl,cs:plane_mask
    jz blit_bg
    not bh
blit_bg:
    xor ah,bh
    mov al,ah
    mov cs:plane_xor,ax
    push ax
    mov al,bh
    mov ah,bh
    mov cs:plane_background,ax
    pop ax
    mov cx,18
blit_line:
    lodsb
    cmp cs:glyph_width,2
    je blit_wide
    and al,ah
    xor al,bh
    mov es:[di],al
    jmp short blit_next
blit_wide:
    call expand_bits
    and ax,cs:plane_xor
    xor ax,cs:plane_background
    mov es:[di],ah
    cmp cs:cell_column,79
    je blit_next
    mov es:[di+1],al
blit_next:
    add di,cs:display_pitch
    loop blit_line
    pop di
    pop si
    shl cs:plane_mask,1
    cmp cs:plane_mask,10h
    jb blit_plane
    mov ax,0f02h
    out dx,ax
blit_done:
    load_regs
    ret
blit_cell endp

expand_bits proc near
    push bx
    push cx
    mov bl,al
    xor ax,ax
    mov cx,8
expand_bit:
    shl bl,1
    jnc expand_zero
    shl ax,1
    shl ax,1
    or al,3
    jmp short expand_next
expand_zero:
    shl ax,1
    shl ax,1
expand_next:
    loop expand_bit
    pop cx
    pop bx
    ret
expand_bits endp

public draw, draw_wide
draw_wide proc near
    mov cs:glyph_width,2
    jmp draw
draw_wide endp
draw proc near
    push bp
    mov bp,sp
    save_regs
    call video_begin
    jc draw_exit
    mov ax,[bp+4]
    mov bx,[bp+6]
    mov dx,[bp+8]
    or ah,ah
    jz draw_ascii
    call S_XSHZ
    jmp short draw_done
draw_ascii:
    call S_XSZF
draw_done:
    call video_end
draw_exit:
    mov cs:glyph_width,1
    load_regs
    pop bp
    ret
draw endp

public bitmap
bitmap proc near
    push bp
    mov bp,sp
    save_regs
    call video_begin
    jc bitmap_done
    mov ds,[bp+4]
    mov si,[bp+6]
    mov bx,[bp+8]
    mov dx,[bp+10]
    mov cx,4
bitmap_column:
    push cx
    push cs
    pop es
    mov di,offset glyph_bits
    mov cx,8
    rep movsw
    mov word ptr es:[di],0
    push ds
    push si
    push cs
    pop ds
    mov si,offset glyph_bits
    call blit_cell
    pop si
    pop ds
    inc dl
    pop cx
    loop bitmap_column
    call video_end
bitmap_done:
    load_regs
    pop bp
    ret
bitmap endp

public glyph
glyph proc near
    push bp
    mov bp,sp
    save_regs
    mov dx,[bp+4]
    mov di,[bp+6]
    push cs
    pop es
    mov cx,16
    or dh,dh
    jz glyph_ascii
    mov ah,cs:traditional
    int 7fh
    mov ds,dx
    xor si,si
    ; Match AH=16: deinterleaved halves, unlike INT7F's interleaved glyph.
glyph_hanzi:
    lodsw
    mov es:[di],al
    mov es:[di+16],ah
    inc di
    loop glyph_hanzi
    jmp short glyph_done
glyph_ascii:
    mov ax,dx
    mov cl,4
    shl ax,cl
    mov si,cs:font_offset
    add si,ax
    mov ds,cs:font_segment
    mov cx,8
    rep movsw
glyph_done:
    load_regs
    pop bp
    ret
glyph endp

public cursor_xor
cursor_xor proc near
    push bp
    mov bp,sp
    save_regs
    call video_begin
    jc cursor_exit
    mov ax,[bp+4]
    mov bx,ax
    mov al,ah
    xor ah,ah
    mov dx,18
    mul dx
    add ax,15
    mul cs:display_pitch
    xor bh,bh
    add ax,bx
    mov di,ax
    mov es,cs:framebuffer
    mov cx,[bp+6]
    cmp cx,16
    jbe cursor_lines
    mov cx,16
cursor_lines:
    jcxz cursor_done
    mov dx,3ceh
    mov ax,0f01h
    out dx,ax
    mov ax,0f00h
    out dx,ax
    mov ax,1803h
    out dx,ax
cursor_line:
    mov al,es:[di]
    mov byte ptr es:[di],0ffh
    sub di,cs:display_pitch
    loop cursor_line
    mov ax,1
    out dx,ax
    mov ax,3
    out dx,ax
cursor_done:
    call video_end
cursor_exit:
    load_regs
    pop bp
    ret
cursor_xor endp

; Restore application GC/SEQ values and selected indexes after each batch.
; C prompt/string operations can enclose multiple glyphs in one transaction.
public begin_draw, end_draw
begin_draw proc near
    call video_begin
    jc begin_failed
    mov ax,1
    ret
begin_failed:
    xor ax,ax
    ret
begin_draw endp
video_begin proc near
    save_regs
    cmp cs:active,0
    je video_inactive
    inc cs:video_depth
    cmp cs:video_depth,1
    jne video_ready
    push cs
    pop ds
    mov dx,3ceh
    in al,dx
    mov gc_index,al
    xor bx,bx
video_save_gc:
    mov al,bl
    out dx,al
    inc dx
    in al,dx
    mov saved_gc[bx],al
    dec dx
    inc bx
    cmp bx,9
    jb video_save_gc
    cmp cs:banked_text,0
    je video_direct
    xor dx,dx
    call select_bank
    jc video_unavailable
    mov dx,3ceh
    mov ax,0506h
    out dx,ax
video_direct:
    mov ax,1
    out dx,ax
    mov ax,3
    out dx,ax
    mov ax,4
    out dx,ax
    mov ax,5
    out dx,ax
    mov ax,0ff08h
    out dx,ax
    mov dx,3c4h
    in al,dx
    mov seq_index,al
    mov al,2
    out dx,al
    inc dx
    in al,dx
    mov saved_seq,al
    dec dx
    mov ax,0f02h
    out dx,ax
video_ready:
    load_regs
    clc
    ret
video_unavailable:
    mov dx,3ceh
    mov al,gc_index
    out dx,al
    mov cs:active,0
    mov cs:video_depth,0
video_inactive:
    load_regs
    stc
    ret
video_begin endp
end_draw label near
video_end proc near
    save_regs
    cmp cs:video_depth,0
    je video_finished
    dec cs:video_depth
    jne video_finished
    push cs
    pop ds
    cmp cs:banked_text,0
    je video_restore
    mov dx,cs:text_bank
    call select_bank
    jnc video_restore
    mov cs:active,0
video_restore:
    mov dx,3ceh
    xor bx,bx
video_restore_gc:
    mov al,bl
    mov ah,saved_gc[bx]
    out dx,ax
    inc bx
    cmp bx,9
    jb video_restore_gc
    mov al,gc_index
    out dx,al
    mov dx,3c4h
    mov al,2
    mov ah,saved_seq
    out dx,ax
    mov al,seq_index
    out dx,al
video_finished:
    load_regs
    ret
video_end endp

public pixel
pixel proc near
    push bp
    mov bp,sp
    push bx
    push si
    push di
    push es
    call video_begin
    jc pixel_failed
    mov ax,[bp+6]
    mul cs:display_pitch
    mov di,ax
    mov bx,[bp+4]
    mov cx,bx
    and cl,7
    mov ah,80h
    shr ah,cl
    mov si,ax
    mov cl,3
    shr bx,cl
    add di,bx
    mov es,cs:framebuffer
    xor bx,bx
    mov cl,1
pixel_plane:
    mov dx,3ceh
    mov al,4
    mov ah,bl
    out dx,ax
    mov al,es:[di]
    mov dx,si
    test al,dh
    jz pixel_bit
    or bh,cl
pixel_bit:
    cmp word ptr [bp+10],0
    je pixel_next
    mov dl,cl
    test byte ptr [bp+8],80h
    jnz pixel_xor
    not dh
    and al,dh
    not dh
    test byte ptr [bp+8],dl
    jz pixel_store
    or al,dh
    jmp short pixel_store
pixel_xor:
    test byte ptr [bp+8],dl
    jz pixel_next
    xor al,dh
pixel_store:
    push ax
    mov dx,3c4h
    mov al,2
    mov ah,cl
    out dx,ax
    pop ax
    mov es:[di],al
pixel_next:
    shl cl,1
    inc bl
    cmp bl,4
    jb pixel_plane
    xor ax,ax
    mov al,bh
    call video_end
    jmp short pixel_done
pixel_failed:
    xor ax,ax
pixel_done:
    pop es
    pop di
    pop si
    pop bx
    pop bp
    ret
pixel endp

; Bank-aware raw observation/capture API. No framebuffer address is promised
; permanently mapped while the console uses a separate B800 text window.
public read_plane
read_plane proc near
    push bp
    mov bp,sp
    save_regs
    call video_begin
    jc read_done
    mov ah,byte ptr [bp+4]
    mov al,4
    mov dx,3ceh
    out dx,ax
    mov si,[bp+6]
    mov es,[bp+8]
    mov di,[bp+10]
    mov cx,[bp+12]
    mov ds,cs:framebuffer
    rep movsb
    call video_end
read_done:
    load_regs
    pop bp
    ret
read_plane endp

public boundary
boundary proc near
    push bp
    mov bp,sp
    save_regs
    call classifier_policy
    mov si,[bp+4]
    push si
    mov dx,[si+6]
    call S_HZPOS
    pop si
    mov cs:[si],ax
    mov cs:[si+2],bx
    mov cs:[si+4],cx
    load_regs
    pop bp
    ret
boundary endp

policy label byte
include ZJXP.INC
include HZPOS.INC
shadow label word
D_XPQ db 4000 dup (0)
stack_bottom dw 0a55ah
db 2048 dup (0)
stack_top label word

; Installation only, ordered after the resident boundary by the linker.
_TEXT ends
INIT_TEXT segment word public 'INIT'
assume cs:DGROUP
install:
    cld
    push cs
    pop ds
    push cs
    pop es
    mov di,offset bss_begin
    mov cx,offset resident_end
    sub cx,di
    xor ax,ax
    rep stosb
    mov resident_segment,cs
    xor cx,cx
    mov cl,ds:[80h]
    mov si,81h
parse_option:
    jcxz options_done
    lodsb
    dec cx
    cmp al,' '
    je parse_option
    cmp al,'/'
    jne bad_option
    or cx,cx
    jz bad_option
    lodsb
    dec cx
    cmp al,'?'
    je usage
    and al,5fh
    cmp al,'N'
    jne bad_option
    mov force_low,1
    jmp short parse_option
options_done:
    mov ah,0ffh
    int 10h
    cmp ax,56h
    je already_loaded
    cmp ax,45h
    je already_loaded
    cmp ax,48h
    je already_loaded
    mov ax,4a06h
    mov si,3
    int 2fh
    cmp bx,4a06h
    jne no_font
    mov ax,3510h
    int 21h
    mov word ptr old10,bx
    mov word ptr old10+2,es
    mov ax,3508h
    int 21h
    mov word ptr old8,bx
    mov word ptr old8+2,es
    xor bp,bp
    mov ah,2fh
    int 16h
    mov keyboard_segment,bp
    mov busy,1
    call initialize
    or ax,ax
    jnz no_vbe
    mov ax,offset resident_end
    cmp banked_text,0
    je resident_size
    mov ax,offset image_end
resident_size:
    mov resident_bytes,ax
    add ax,15
    mov cl,4
    shr ax,cl
    mov resident_paragraphs,ax
    cmp force_low,0
    jne install_vectors
    call S_UMB
    cmp umb_segment,0
    je install_vectors
    mov es,umb_segment
    xor si,si
    xor di,di
    mov cx,resident_paragraphs
    shl cx,1
    shl cx,1
    shl cx,1
    shl cx,1
    rep movsb
    push es
    pop ds
    mov resident_segment,ds
    mov word ptr ds:[2ch],0
install_vectors:
    mov dx,offset int10_handler
    mov ax,2510h
    int 21h
    mov dx,offset int8_handler
    mov ax,2508h
    int 21h
    mov busy,0
    mov ax,ds
    mov bx,cs
    cmp ax,bx
    je stay_low
    ; The copied MCB belongs to its own PSP. DOS termination releases only
    ; the original program and environment; all C pointers are near offsets.
    mov ax,4c00h
    int 21h
stay_low:
    mov es,ds:[2ch]
    mov ah,49h
    int 21h
    ; WLINK resolves the end of C data/BSS, not just the assembly code.
    mov dx,resident_paragraphs
    mov ax,3100h
    int 21h
already_loaded:
    mov dx,offset msg_loaded
    jmp short install_error
no_font:
    mov dx,offset msg_font
    jmp short install_error
no_vbe:
    mov dx,offset msg_vbe
    jmp short install_error
bad_option:
    mov dx,offset msg_usage
install_error:
    mov ah,9
    int 21h
    mov ax,4c01h
    int 21h
usage:
    mov dx,offset msg_usage
    mov ah,9
    int 21h
    mov ax,4c00h
    int 21h

; DOS-owned UMBs, with complete restoration of allocation policy on failure.
; This follows the existing display-module allocator without requiring XMS.
S_UMB proc near
    mov ax,3000h
    int 21h
    cmp al,5
    jb umb_done
    mov ax,5800h
    int 21h
    jc umb_done
    mov old_strategy,ax
    mov ax,5802h
    int 21h
    jc umb_done
    xor ah,ah
    mov old_link,ax
    mov ax,5803h
    mov bx,1
    int 21h
    jc umb_done
    mov ax,5801h
    mov bx,41h
    int 21h
    jc restore_link
    mov ah,48h
    mov bx,resident_paragraphs
    int 21h
    jc restore_strategy
    mov umb_segment,ax
    push es
    mov bx,ax
    dec ax
    mov es,ax
    mov es:[1],bx
    mov word ptr es:[8],'EV'
    mov word ptr es:[10],'AS'
    pop es
restore_strategy:
    mov ax,5801h
    mov bx,old_strategy
    int 21h
restore_link:
    mov ax,5803h
    mov bx,old_link
    int 21h
umb_done:
    ret
S_UMB endp
old_strategy dw 0
old_link dw 0
umb_segment dw 0
resident_paragraphs dw 0
force_low db 0
msg_loaded db 'A HHBIOS display driver is already installed.',13,10,'$'
msg_font db 'Load a HHBIOS font reader before VESA.',13,10,'$'
msg_vbe db 'VESA needs a VGA-compatible 800x600x16 VBE mode.',13,10,'$'
msg_usage db 'VESA [/N]  800x600x16 display; /N keeps the driver in conventional memory.',13,10,'$'
INIT_TEXT ends

; This class is ordered after compiler-generated BSS by the linker.
_BSS segment word public 'BSS'
bss_begin label byte
_BSS ends
_END segment byte public 'ZZEND'
resident_end db 0
_END ends
_SCRATCH segment para public 'TAIL'
text_transfer db 4096 dup (0)
image_end label byte
_SCRATCH ends
DGROUP group _BSS, _END, _SCRATCH, INIT_TEXT
end start

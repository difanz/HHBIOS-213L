; Independent 386 real-mode display driver. No C runtime or VGA.COM dependency.
; C uses near __cdecl calls, DS=SS=CS on our private resident stack.
; IRQ0/INT10 preserve the interrupted stack and all registers; nested BIOS
; INT10 calls chain directly while busy. No DOS service is called resident.
.model tiny, c
.code
include vesa_cpu.inc
org 100h
public start
public int10_handler, int8_handler, old10, old8, stack_bottom, stack_top
public image_end, resident_end, S_UMB, umb_segment, resident_paragraphs
public font_checking
extrn initialize:near, dispatch:near, tick:near
extrn request:byte, screen:byte, resident_segment:word, keyboard_segment:word
extrn framebuffer:word, display_pitch:word, active_page:word
extrn resident_bytes:word
extrn display_start:word, split_line:word
extrn text_bank:word, banked_text_allowed:byte
extrn requested_mode:word, requested_rows:word
extrn plane_bytes:dword, bank_step:word, large_surface:byte
extrn mode_selected:byte
extrn text_rows:word, text_cells:word, page_bytes:word, last_row:byte
extrn raster_cell:near
extrn old33:dword, int33_handler:far
extrn mouse_resume:near, mouse_suspend:near
extrn mouse_native:byte
extrn font_segment:word, font_offset:word, active:byte, busy:byte, traditional:byte
extrn direct:byte
extrn prompt_notify:byte
extrn font_get:near, font_open:near, font_close:near, font_bitmap:near
extrn font_sync:near, font_custom:byte
extrn font_extended:byte, font_name:byte, font_draw:near, font_bitmap_draw:near
CELL_WIDTH equ 10
CELL_HEIGHT equ 23
GLYPH_HEIGHT equ 20
start: jmp install

old10 dd 0
old8 dd 0
old2f dd 0
saved_ss dw 0
saved_sp dw 0
handled dw 0
public policy, hanzi, shadow, frame_alias_offset
hanzi db 1
D_B800 dw 0b800h
D_005A db 1
glyph_bits dw CELL_HEIGHT*2 dup (0)
wide_bits dw CELL_HEIGHT*2 dup (0)
legacy_bits db 16 dup (0)
raster_rows dw CELL_HEIGHT dup (0)
cell_keep dw 0
cell_shift db 0
cursor_bits dw 0
cell_attr db 0
plane_number db 0
glyph_width db 1
plane_xor dw 0
plane_background dw 0
saved_gc db 9 dup (0)
saved_seq db 0
saved_memory_mode db 0
gc_index db 0
seq_index db 0
video_depth db 0
font_checking db 0
aperture_alias db 0ffh
text_map db 1
public mapped_block
mapped_block dw 0
bank_result dw 0
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
    cmp cs:mouse_native,0
    jne chain10
    cmp ax,1410h
    je query_boundary
    cmp cs:busy,0
    jne busy10
    mov cs:busy,1
    pushad
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
    mov ax,[si+36]              ; skip PUSHAD before the CPU's IRET frame
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
    mov es:[di+36],ax
    mov ss,cs:saved_ss
    mov sp,cs:saved_sp
    mov cs:busy,0
    cmp cs:handled,0
    je pass10
    load_regs
    restore_dword_regs
    ; CKBD reenters INT 10h to paint AH=14h. Only notify after restoring the
    ; caller's stack and releasing busy; its nested calls own the C stack.
    cmp cs:prompt_notify,0
    je prompt_notified
    mov cs:prompt_notify,0
    save_regs
    mov ax,2900h
    int 16h
    load_regs
prompt_notified:
    iret
pass10:
    load_regs
    restore_dword_regs
    jmp short chain10
busy10:
    ; Capture may be requested by another timer TSR while rendering. It must
    ; retry, not reuse our private C stack or read a half-switched window.
    cmp ax,1412h
    je capture_busy
    cmp ax,1414h
    jne chain10
capture_busy:
    mov ax,2
    iret
chain10:
    jmp cs:old10
query_boundary:
    ; Keyboard IRQ handlers may ask while a font read has interrupted drawing.
    ; Use the current text snapshot without entering the occupied C stack.
    push ds
    push es
    push si
    push di
    push dx
    push bp
    push cs:D_B800
    call classifier_policy
    cmp cs:active,0
    je query_inactive
    cmp cs:banked_text,0
    je query_scan
    ; Font comparison temporarily borrows text_transfer while B800 remains
    ; mapped. A keyboard IRQ must not overwrite that scratch with a snapshot.
    cmp cs:font_checking,0
    jne query_scan
    cmp cs:video_depth,0
    jne query_snapshot
    call snapshot_text
query_snapshot:
    mov ax,offset text_transfer
    mov cl,4
    shr ax,cl
    mov bx,cs
    add ax,bx
    mov cs:D_B800,ax
query_scan:
    call S_HZPOS
    jmp short query_done
query_inactive:
    xor ax,ax
    xor cx,cx
    mov bx,4b48h
query_done:
    pop cs:D_B800
    pop bp
    pop dx
    pop di
    pop si
    pop es
    pop ds
    iret
int10_handler endp

int8_handler proc far
    pushf
    call cs:old8
    pushf
    cli
    cmp cs:mouse_native,0
    jne timer_done
    cmp cs:busy,0
    jne timer_done
    mov cs:busy,1
    pushad
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
    restore_dword_regs
timer_done:
    popf
    iret
int8_handler endp

; The relocated UMB image exits its loader normally, so the font reader's
; INT 21h/AH=31h registry does not own it. Release our resources before chaining
; the full HHBIOS unload. Partial printer unloads leave this driver intact.
int2f_handler proc far
    pushf
    cmp ax,4a06h
    jne chain2f
    or si,si
    jne chain2f
    cmp cs:busy,0
    jne unload_busy
    mov cs:busy,1
    pushad
    push ds
    push es
    mov cs:saved_ss,ss
    mov cs:saved_sp,sp
    mov ax,cs
    mov ss,ax
    mov sp,offset stack_top
    mov ds,ax
    cld
    call mouse_suspend
    mov active,0
    call font_close
    cli
    mov ss,cs:saved_ss
    mov sp,cs:saved_sp
    lds dx,cs:old33
    mov ax,2533h
    int 21h
    lds dx,cs:old10
    mov ax,2510h
    int 21h
    lds dx,cs:old8
    mov ax,2508h
    int 21h
    lds dx,cs:old2f
    mov ax,252fh
    int 21h
    push cs
    pop es
    mov ah,49h
    int 21h
    ; DOS frees the block without changing its contents. Keep interrupts off
    ; until the next handler, just as the reader's own unload path does.
    cli
    pop es
    pop ds
    popad
chain2f:
    popf
    jmp cs:old2f
unload_busy:
    popf
    iret
int2f_handler endp

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
public reprobe
reprobe proc near
    mov cs:aperture_alias,0ffh
    mov cs:text_map,1
    ret
reprobe endp
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
    cmp cs:aperture_alias,0ffh
    jne aperture_known_bank
    ; BIOS bank granularity alone does not prove where a remapped B800
    ; window lands. Probe all eight pages against the entire visible plane.
    call probe_text_bank
    jc aperture_failed
    mov cs:aperture_alias,0
aperture_known_bank:
    mov dx,cs:text_bank
    call select_bank
    jc aperture_failed
    mov dx,3ceh
    ; Prefer shared A000-BFFF decoding: B800-only selects CGA scanout in
    ; classic DOSBox. Probe the narrower map only if the shared map fails.
    mov ah,cs:text_map
    mov al,6
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

; C callers use a 64 KiB block number; BIOS uses its advertised granularity.
public graphics_bank
graphics_bank proc near
    push bp
    mov bp,sp
    save_regs
    mov cs:bank_result,0
    cmp cs:active,0
    je graphics_bank_done
    mov ax,[bp+4]
    cmp ax,cs:mapped_block
    je graphics_bank_ok
    push ax
    mul cs:bank_step
    mov dx,ax
    call select_bank
    pop ax
    jc graphics_bank_failed
    mov cs:mapped_block,ax
graphics_bank_ok:
    mov cs:bank_result,1
    jmp short graphics_bank_done
graphics_bank_failed:
    mov cs:active,0
graphics_bank_done:
    load_regs
    mov ax,cs:bank_result
    pop bp
    ret
graphics_bank endp

public invalidate
invalidate proc near
    mov cs:D_LASTMODE,0ffh
    ret
invalidate endp

; The classifier is shared verbatim with VGA/EGA/HGA. No translated FSM.
public refresh
snapshot_text proc near
    save_regs
    cli
    mov ax,cs:active_page
    mul cs:page_bytes
    mov cl,4
    shr ax,cl
    add ax,0b800h
    mov ds,ax
    push cs
    pop es
    xor si,si
    mov di,offset text_transfer
    mov cx,cs:text_cells
    shr cx,1                    ; 80 columns: copy two text cells per dword
    cld
    rep movsd
    load_regs
    ret
snapshot_text endp

refresh proc near
    save_regs
    call text_ready
    or ax,ax
    jz refresh_done
    push cs
    pop ds
    mov cs:font_checking,1
    call font_sync
    mov cs:font_checking,0
    call classifier_policy
    mov ds,cs:D_B800
    push cs
    pop es
    ; Check the live text aperture before any graphics mapping or frame scan.
    ; Policy changes and software mouse erasure still force the normal path.
    mov al,cs:D_ZBFS
    cmp al,cs:D_LASTMODE
    jne refresh_changed
    mov al,cs:K_HZ1
    cmp al,cs:D_LASTHZ
    jne refresh_changed
    xor si,si
    mov di,offset D_XPQ
    mov cx,cs:text_cells
    shr cx,1
    repe cmpsd
    je refresh_done
refresh_changed:
    cmp cs:banked_text,0
    je refresh_ready
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
    mov cx,cs:text_cells
    shr cx,1
    pushf
    cli
    rep movsd
    popf
refresh_done:
    load_regs
    ret
refresh endp

; A font downloader can temporarily unmap B800 between its direct I/O writes.
; IRQ refresh/capture must wait until the application restores a text aperture.
public text_ready
text_ready proc near
    pushf
    cli
    push bx
    push dx
    mov ax,1
    cmp cs:banked_text,0
    je text_ready_done
    mov dx,3ceh
    in al,dx
    mov bl,al
    mov al,6
    out dx,al
    inc dx
    in al,dx
    mov bh,al
    dec dx
    mov al,bl
    out dx,al
    and bh,0ch
    mov bl,cs:text_map
    and bl,0ch
    mov ax,1
    cmp bh,bl
    je text_ready_done
    cmp bh,0ch
    je text_ready_done
    xor ax,ax
text_ready_done:
    pop dx
    pop bx
    popf
    ret
text_ready endp

; ZF=0 identifies an application-defined single-byte glyph. Keep its byte
; out of the frame-alias and DBCS pairing paths shared with legacy drivers.
S_CUSTOM proc near
    push bx
    mov bl,al
    xor bh,bh
    test cs:font_custom[bx],1
    pop bx
    ret
S_CUSTOM endp

; Observe the first VGA character block after a direct font-RAM operation.
; Odd/even text addressing distinguishes it from our normal linear aperture.
; The bank is already the isolated text bank; never touch visible scanout.
public font_snapshot
font_snapshot proc near
    save_regs
    xor bp,bp
    cmp cs:banked_text,0
    je font_snapshot_done
    mov dx,3c4h
    in al,dx
    mov bl,al
    mov al,4
    out dx,al
    inc dx
    in al,dx
    mov bh,al
    dec dx
    test al,4
    jnz font_snapshot_seq
    cli
    mov ax,0604h
    out dx,ax
    mov dx,3ceh
    in al,dx
    push ax
    mov si,4
font_snapshot_gc:
    mov ax,si
    out dx,al
    inc dx
    in al,dx
    dec dx
    push ax
    inc si
    cmp si,7
    jb font_snapshot_gc
    mov ax,0204h
    out dx,ax
    mov ax,5
    out dx,ax
    mov ax,0406h
    out dx,ax
    mov ax,0a000h
    mov ds,ax
    push cs
    pop es
    xor si,si
    mov di,offset text_transfer+4096
    mov bp,256
font_snapshot_char:
    mov cx,8
    rep movsw
    add si,16
    dec bp
    jnz font_snapshot_char
    mov cx,3
font_snapshot_restore:
    pop ax
    mov ah,al
    mov al,cl
    add al,3
    out dx,ax
    loop font_snapshot_restore
    pop ax
    out dx,al
    mov dx,3c4h
    mov al,4
    mov ah,bh
    out dx,ax
    mov bp,1
font_snapshot_seq:
    mov al,bl
    out dx,al
font_snapshot_done:
    mov cs:bank_result,bp
    load_regs
    mov ax,cs:bank_result
    ret
font_snapshot endp

public font_seed
font_seed proc near
    save_regs
    cmp cs:banked_text,0
    je font_seed_done
    cli
    mov dx,3c4h
    mov ax,0604h
    out dx,ax
    mov ax,0402h
    out dx,ax
    mov dx,3ceh
    mov ax,1
    out dx,ax
    mov ax,3
    out dx,ax
    mov ax,4
    out dx,ax
    mov ax,5
    out dx,ax
    mov ax,0506h
    out dx,ax
    mov ax,0ff08h
    out dx,ax
    mov ds,cs:font_segment
    mov si,cs:font_offset
    mov ax,0a000h
    mov es,ax
    xor di,di
    mov bx,256
    xor ax,ax
font_seed_char:
    mov cx,8
    rep movsw
    mov cx,8
    rep stosw
    dec bx
    jnz font_seed_char
    mov ah,cs:text_map
    mov al,6
    out dx,ax
    mov dx,3c4h
    ; Linear B800 bytes need only plane zero. Leave font plane two intact.
    mov ax,0102h
    out dx,ax
font_seed_done:
    load_regs
    ret
font_seed endp

classifier_policy proc near
    mov ax,cs:active_page
    push dx
    mul cs:page_bytes
    pop dx
    mov cl,4
    shr ax,cl
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
    cmp cs:font_extended,0
    je ascii_fixed_font
    xor ah,ah
    jmp draw_large_font
ascii_fixed_font:
    push dx
    push bx
    xor ah,ah
    push cs
    pop ds
    mov si,offset glyph_bits
    push si
    push ax
    call font_get
    add sp,4
    pop bx
    pop dx
    push cs
    pop ds
    mov si,offset glyph_bits
    call blit_cell
    ret
S_XSZF endp

S_XSHZ proc near
    cmp cs:font_extended,0
    jne draw_large_font
    push dx
    push bx
    push cs
    pop ds
    mov si,offset glyph_bits
    push si
    push ax
    call font_get
    add sp,4
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
    mov si,offset glyph_bits+CELL_HEIGHT*2
    call blit_cell
    ret
S_XSHZ endp

draw_large_font proc near
    save_regs
    push cs
    pop ds
    xor cx,cx
    mov cl,cs:glyph_width
    push cx
    push dx
    push bx
    push ax
    call font_draw
    add sp,8
    load_regs
    ret
draw_large_font endp

; DS:SI is 23 left-aligned ten-bit words. Wide text doubles each pixel and
; splits at a cell boundary; the ten-pixel grid is unchanged.
blit_cell proc near
    cmp cs:glyph_width,2
    je blit_double
    jmp blit_narrow
blit_double:
    save_regs
    push bx
    push dx
    mov di,offset wide_bits
    mov cx,CELL_HEIGHT
blit_double_row:
    lodsw
    push cx
    xor bx,bx
    xor dx,dx
    mov cx,10
blit_double_bit:
    shl ax,1
    rcl bx,1
    rcl dx,1
    shl bx,1
    rcl dx,1
    test bl,2
    jz blit_double_zero
    or bl,1
blit_double_zero:
    loop blit_double_bit
    ; DX:BX contains 20 bits. Each output word is left-aligned.
    mov ax,bx
    mov cl,4
    shr ax,cl
    mov cl,12
    shl dx,cl
    or ax,dx
    and ax,0ffc0h
    mov cs:[di],ax
    mov cl,6
    shl bx,cl
    mov cs:[di+CELL_HEIGHT*2],bx
    add di,2
    pop cx
    loop blit_double_row
    pop dx
    pop bx
    push cs
    pop ds
    mov si,offset wide_bits
    call blit_narrow
    inc dl
    mov si,offset wide_bits+CELL_HEIGHT*2
    call blit_narrow
    load_regs
    ret
blit_cell endp

public draw_half
draw_half proc near
    push bp
    mov bp,sp
    save_regs
    call video_begin
    jc half_done
    push cs
    pop ds
    mov si,[bp+4]
    mov bx,[bp+6]
    mov dx,[bp+8]
    call blit_narrow
    call video_end
half_done:
    load_regs
    pop bp
    ret
draw_half endp

; Ten-pixel cells share framebuffer bytes. Select the read plane as well as
; the write plane, and preserve the neighbor bits on every word store.
blit_narrow proc near
    save_regs
    cmp cs:large_surface,0
    je blit_fixed
    push dx
    xor bh,bh
    push bx
    push si
    call raster_cell
    add sp,6
    jmp blit_done
blit_fixed:
    cmp dl,80
    jae blit_done
    cmp dh,25
    ja blit_done
    mov cs:cell_attr,bl
    mov bp,dx
    xor ax,ax
    mov al,dl
    mov bx,CELL_WIDTH
    mul bx
    mov cl,al
    and cl,7
    mov cs:cell_shift,cl
    mov dx,0ffc0h
    shr dx,cl
    xchg dh,dl
    not dx
    mov cs:cell_keep,dx
    shr ax,1
    shr ax,1
    shr ax,1
    mov di,ax
    mov ax,bp
    mov al,ah
    xor ah,ah
    mov bx,CELL_HEIGHT
    mul bx
    mul cs:display_pitch
    add di,ax
    xor bx,bx
    mov bp,offset raster_rows
blit_prepare:
    lodsw
    mov cl,cs:cell_shift
    shr ax,cl
    xchg al,ah
    mov cs:[bp],ax
    add bp,2
    inc bx
    cmp bx,CELL_HEIGHT
    jb blit_prepare
    mov es,cs:framebuffer
    mov cs:plane_number,0
blit_plane:
    push di
    mov dx,3ceh
    mov al,4
    mov ah,cs:plane_number
    out dx,ax
    mov cl,ah
    mov ah,1
    shl ah,cl
    mov dx,3c4h
    mov al,2
    out dx,ax
    mov bl,cs:cell_attr
    xor dx,dx
    test bl,ah
    jz blit_fg
    not dx
blit_fg:
    mov cl,4
    shr bl,cl
    xor cx,cx
    test bl,ah
    jz blit_bg
    not cx
blit_bg:
    xor dx,cx
    mov cs:plane_xor,dx
    mov cs:plane_background,cx
    mov bp,offset raster_rows
    mov cx,CELL_HEIGHT
blit_line:
    mov ax,cs:[bp]
    and ax,cs:plane_xor
    xor ax,cs:plane_background
    mov bx,cs:cell_keep
    not bx
    and ax,bx
    mov bx,es:[di]
    and bx,cs:cell_keep
    or ax,bx
    mov es:[di],ax
    add bp,2
    add di,cs:display_pitch
    loop blit_line
    pop di
    inc cs:plane_number
    cmp cs:plane_number,4
    jb blit_plane
    mov dx,3c4h
    mov ax,0f02h
    out dx,ax
blit_done:
    load_regs
    ret
blit_narrow endp

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
    mov cx,[bp+12]
bitmap_column:
    push cx
    push cs
    pop es
    mov di,offset legacy_bits
    mov cx,8
    rep movsw
    push ds
    push si
    push cs
    pop ds
    push bx
    push dx
    cmp cs:font_extended,0
    je bitmap_fixed_font
    push dx
    push bx
    mov ax,offset legacy_bits
    push ax
    call font_bitmap_draw
    add sp,6
    pop dx
    pop bx
    jmp short bitmap_next
bitmap_fixed_font:
    mov ax,offset glyph_bits
    push ax
    mov ax,offset legacy_bits
    push ax
    call font_bitmap
    add sp,4
    pop dx
    pop bx
    mov si,offset glyph_bits
    call blit_cell
bitmap_next:
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
    mov dx,CELL_HEIGHT
    mul dx
    add ax,GLYPH_HEIGHT-1
    mul cs:display_pitch
    mov di,ax
    xor ax,ax
    mov al,bl
    mov dx,CELL_WIDTH
    mul dx
    mov cl,al
    and cl,7
    mov dx,0ffc0h
    shr dx,cl
    xchg dh,dl
    mov cs:cursor_bits,dx
    shr ax,1
    shr ax,1
    shr ax,1
    add di,ax
    mov es,cs:framebuffer
    mov ax,[bp+6]
    cmp ax,16
    jbe cursor_lines
    mov ax,16
cursor_lines:
    mov bx,GLYPH_HEIGHT
    mul bx
    add ax,15
    mov cl,4
    shr ax,cl
    mov cx,ax
    jcxz cursor_done
    mov dx,3ceh
    mov ax,1803h
    out dx,ax
cursor_line:
    mov al,es:[di]
    mov ax,cs:cursor_bits
    mov es:[di],al
    mov al,es:[di+1]
    mov es:[di+1],ah
    sub di,cs:display_pitch
    loop cursor_line
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
    call snapshot_text
    xor dx,dx
    call select_bank
    jc video_unavailable
    mov cs:mapped_block,0
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
    ; Text programs such as MSBACKUP restore VGA odd/even addressing after
    ; accessing font RAM directly. Raster writes require linear plane bytes;
    ; keep the application's text addressing outside this transaction.
    mov al,4
    out dx,al
    inc dx
    in al,dx
    mov saved_memory_mode,al
    dec dx
    mov ax,0604h
    out dx,ax
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
    mov al,4
    mov ah,saved_memory_mode
    out dx,ax
    mov al,seq_index
    out dx,al
video_finished:
    load_regs
    ret
video_end endp

; Native 800x600 full-width scroll. Write mode 1 copies the four VGA latches
; together. Direction handles overlap; the IME strip is outside this range.
public scroll_pixels
scroll_pixels proc near
    push bp
    mov bp,sp
    save_regs
    call video_begin
    jc scroll_pixels_done
    mov ax,[bp+6]              ; last row
    sub ax,[bp+4]              ; first row
    inc ax
    sub ax,[bp+8]              ; rows retained
    mov bx,2300               ; 23 scanlines * 100 bytes per plane
    mul bx
    mov cx,ax
    mov ax,[bp+4]
    mul bx
    mov di,ax
    mov ax,[bp+8]
    mul bx
    mov si,di
    add si,ax
    cmp word ptr [bp+10],0
    je scroll_pixels_forward
    xchg si,di
    add si,cx
    add di,cx
    dec si
    dec di
    std
scroll_pixels_forward:
    mov ax,cs:framebuffer
    mov ds,ax
    mov es,ax
    mov dx,3ceh
    mov ax,0105h
    out dx,ax
    rep movsb
    cld
    call video_end
    ; The framebuffer and its shadow describe the same retained rows.
    push cs
    pop ds
    push cs
    pop es
    mov ax,[bp+6]
    sub ax,[bp+4]
    inc ax
    sub ax,[bp+8]
    mov bx,160
    mul bx
    mov cx,ax
    shr cx,1
    mov ax,[bp+4]
    mul bx
    mov di,offset D_XPQ
    add di,ax
    mov ax,[bp+8]
    mul bx
    mov si,di
    add si,ax
    cmp word ptr [bp+10],0
    je scroll_shadow_forward
    xchg si,di
    mov ax,cx
    shl ax,1
    add si,ax
    add di,ax
    sub si,2
    sub di,2
    std
scroll_shadow_forward:
    rep movsw
    cld
scroll_pixels_done:
    load_regs
    pop bp
    ret
scroll_pixels endp

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
XR_CUSTOM equ 1
XR_ROWS TEXTEQU <cs:text_rows>
XR_LASTROW TEXTEQU <cs:last_row>
XR_CELLS TEXTEQU <cs:text_cells>
include ZJXP.INC
include HZPOS.INC
shadow label word
D_XPQ db 8000 dup (0)
stack_bottom dw 0a55ah
db 2048 dup (0)
stack_top label word

; A runtime font/row change may select a different physical surface. Re-probe
; its banks while all 32 KiB of text are backed up outside conventional RAM.
probe_text_bank proc near
    save_regs
    mov bp,cs:text_bank
probe_map:
    mov cs:text_bank,bp
    mov si,4
probe_bank:
    mov dx,cs:text_bank
    call select_bank
    jc probe_next
    mov dx,3ceh
    mov ah,cs:text_map
    mov al,6
    out dx,ax
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
    mov ax,0f02h
    out dx,ax
    mov ax,0b800h
    mov es,ax
    xor di,di
    mov ax,5aa5h
    mov cx,16384
probe_fill:
    stosw
    add ax,7
    loop probe_fill
    push bp
    xor bp,bp
    mov bx,word ptr cs:plane_bytes+2
probe_clear_bank:
    mov cx,word ptr cs:plane_bytes
    or bx,bx
    jnz probe_clear_full
    jcxz probe_clear_done
    shr cx,1
    jmp short probe_clear_select
probe_clear_full:
    mov cx,8000h
probe_clear_select:
    mov dx,bp
    call select_bank
    jc probe_clear_failed
    mov dx,3ceh
    mov ax,0506h
    out dx,ax
    mov ax,0a000h
    mov es,ax
    xor di,di
    xor ax,ax
    rep stosw
    or bx,bx
    jz probe_clear_done
    dec bx
    add bp,cs:bank_step
    jmp probe_clear_bank
probe_clear_failed:
    pop bp
    jmp probe_failed
probe_clear_done:
    pop bp
    mov dx,cs:text_bank
    call select_bank
    jc probe_failed
    mov dx,3ceh
    mov ah,cs:text_map
    mov al,6
    out dx,ax
    mov ax,0b800h
    mov es,ax
    xor di,di
    mov ax,5aa5h
    mov cx,16384
probe_verify:
    scasw
    jne probe_next
    add ax,7
    loop probe_verify
    load_regs
    clc
    ret
probe_next:
    add cs:text_bank,bp
    dec si
    jnz probe_bank
probe_failed:
    cmp cs:text_map,1
    jne probe_exhausted
    mov cs:text_map,0dh
    jmp probe_map
probe_exhausted:
    load_regs
    stc
    ret
probe_text_bank endp
; Installation only, ordered after the resident boundary by the linker.
_TEXT ends
INIT_TEXT segment word public 'INIT'
.8086
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
    or cx,cx
    jz options_done
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
    jne parse_mode
    mov force_low,1
    jmp short parse_option
parse_mode:
    cmp al,'R'
    je parse_rows
    cmp al,'F'
    je parse_font
    cmp al,'M'
    jne bad_option
    or cx,cx
    jz bad_option
    lodsb
    dec cx
    cmp al,':'
    jne bad_option
    xor bx,bx
    xor di,di
parse_mode_digit:
    jcxz parse_mode_done
    lodsb
    dec cx
    cmp al,' '
    je parse_mode_done
    cmp al,'0'
    jb bad_option
    cmp al,'9'
    jbe parse_mode_decimal
    and al,5fh
    sub al,'A'-10
    cmp al,10
    jb bad_option
    cmp al,15
    ja bad_option
    jmp short parse_mode_add
parse_mode_decimal:
    sub al,'0'
parse_mode_add:
    cmp di,4
    jae bad_option
    inc di
    shl bx,1
    shl bx,1
    shl bx,1
    shl bx,1
    xor ah,ah
    or bx,ax
    jmp short parse_mode_digit
parse_mode_done:
    cmp bx,100h
    jb bad_option
    cmp bx,3fffh
    ja bad_option
    mov requested_mode,bx
    mov mode_selected,1
    jmp parse_option
parse_font:
    or cx,cx
    jz bad_option
    lodsb
    dec cx
    cmp al,':'
    jne bad_option
    mov di,offset font_name
    xor bx,bx
parse_font_character:
    jcxz parse_font_done
    lodsb
    dec cx
    cmp al,' '
    je parse_font_done
    cmp al,21h
    jb bad_option
    cmp bx,63
    jae bad_option
    stosb
    inc bx
    jmp short parse_font_character
parse_font_done:
    or bx,bx
    jz bad_option
    mov byte ptr [di],0
    jmp parse_option
parse_rows:
    cmp cx,3
    jb bad_option
    lodsb
    cmp al,':'
    jne bad_option
    lodsw
    sub cx,3
    mov bx,25
    cmp ax,3532h               ; decimal "25"
    je parse_rows_done
    mov bx,43
    cmp ax,3334h               ; decimal "43"
    je parse_rows_done
    mov bx,50
    cmp ax,3035h               ; decimal "50"
    jne bad_option
parse_rows_done:
    jcxz parse_rows_store
    cmp byte ptr [si],' '
    jne bad_option
parse_rows_store:
    mov requested_rows,bx
    jmp parse_option
options_done:
    ; A VBE BIOS alone does not identify the CPU. Reject an 8086/286 before
    ; entering compiler-generated 386 code or installing interrupt vectors.
    pushf
    pop dx
    mov ax,dx
    and ax,0fffh
    push ax
    popf
    pushf
    pop ax
    and ax,0f000h
    cmp ax,0f000h
    je old_processor
    mov ax,dx
    or ax,7000h
    push ax
    popf
    pushf
    pop ax
    and ax,7000h
    jz old_processor
    push dx
    popf
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
    call font_open
    or ax,ax
    jz no_font20
    mov ax,3510h
    int 21h
    mov word ptr old10,bx
    mov word ptr old10+2,es
    mov ax,3508h
    int 21h
    mov word ptr old8,bx
    mov word ptr old8+2,es
    mov ax,3533h
    int 21h
    mov word ptr old33,bx
    mov word ptr old33+2,es
    mov ax,352fh
    int 21h
    mov word ptr old2f,bx
    mov word ptr old2f+2,es
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
    mov dx,offset int33_handler
    mov ax,2533h
    int 21h
    mov dx,offset int2f_handler
    mov ax,252fh
    int 21h
    call mouse_resume
    mov busy,0
    cmp prompt_notify,0
    je install_prompt_done
    mov prompt_notify,0
    push ds
    mov ax,2900h
    int 16h
    pop ds
install_prompt_done:
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
    call font_close
    mov dx,offset msg_vbe
    jmp short install_error
old_processor:
    push dx
    popf
    mov dx,offset msg_cpu
    mov ah,9
    int 21h
    mov ax,4c01h
    int 21h
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
no_font20:
    mov dx,offset msg_font20
    jmp install_error

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
msg_cpu db 'VESA requires a 386 or newer CPU. Use VGA on older machines.',13,10,'$'
msg_font db 'Load a HHBIOS font reader before VESA.',13,10,'$'
msg_font20 db 'Cannot load font file into XMS or EMS 4.0 memory.',13,10,'$'
msg_vbe db 'VESA needs a supported planar VBE mode and isolated text memory.',13,10,'$'
msg_usage db 'VESA [/N] [/M:hex] [/F:file] [/R:25|43|50]',13,10
          db 'Defaults: mode 102, HH20.FNT, 80x25 text.',13,10
          db '/N keeps the driver in conventional memory.',13,10,'$'
INIT_TEXT ends

; This class is ordered after compiler-generated BSS by the linker.
_BSS segment word public 'BSS'
bss_begin label byte
_BSS ends
_END segment byte public 'ZZEND'
resident_end db 0
_END ends
_SCRATCH segment para public 'TAIL'
public text_transfer
text_transfer db 8192 dup (0)
image_end label byte
_SCRATCH ends
DGROUP group _BSS, _END, _SCRATCH, INIT_TEXT
end start

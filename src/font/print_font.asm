; 8086 entry points for the C bitmap reader. Resident C owns a private stack.
.model tiny,c
.code
ifndef PRINT_SIZE
PRINT_SIZE equ 24
endif
PRINT_VECTOR equ 7bh + (PRINT_SIZE-24)/8
org 100h
public start, PrintService, PrintSegment
extrn PrintRequest:byte, PrintXmsEntry:dword, PrintLow:word
extrn GetPrintBand:near, ClosePrintFonts:near, InitializePrintFonts:near
start: jmp install

old2f dd 0
old_font dd 0
saved_ss dw 0
saved_sp dw 0
busy db 0
release_font db 0
PrintSegment dw 0

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

db '0'+PRINT_SIZE/10,'0'+PRINT_SIZE mod 10
print_handler proc far
    cmp cs:busy,0
    jne print_busy
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
    mov di,offset PrintRequest
    mov cx,10
    rep movsw
    mov ax,cs
    mov ss,ax
    mov sp,offset stack_top
    mov ds,ax
    sti
    call GetPrintBand
    cli
    mov es,saved_ss
    mov di,saved_sp
    mov si,offset PrintRequest
    mov cx,10
    rep movsw
    mov ss,cs:saved_ss
    mov sp,cs:saved_sp
    mov cs:busy,0
    load_regs
    iret
print_busy:
    ; A nested printer call must not overwrite an in-flight glyph or C stack.
    push cs
    pop ds
    mov si,offset empty_band
    mov cx,PRINT_SIZE
    or dh,dh
    jz print_half
    cmp dh,0aah
    jne print_return
print_half:
    shr cx,1
print_return:
    iret
print_handler endp

unload_handler proc far
    pushf
    cmp ax,4a06h
    jne chain2f
    cmp si,2
    ja chain2f
    cmp cs:busy,0
    jne unload_busy
    or si,si
    jz release_store
    ; The base reader owns the TSR list. Ask whether this particular unload
    ; includes us; installation order alone is not stable across reloads.
    save_regs
    mov di,si
    mov bx,cs
    mov ax,4a06h
    mov si,4
    xor dx,dx
    pushf
    call cs:old2f
    mov cs:release_font,0
    cmp dx,4a06h
    jne inquiry_done
    cmp ax,1
    jne inquiry_done
    mov cs:release_font,1
inquiry_done:
    load_regs
    cmp cs:release_font,0
    je chain2f
release_store:
    mov cs:busy,1
    save_regs
    mov cs:saved_ss,ss
    mov cs:saved_sp,sp
    mov ax,cs
    mov ss,ax
    mov sp,offset stack_top
    mov ds,ax
    cld
    call ClosePrintFonts
    cli
    lds dx,cs:old_font
    mov ax,2500h+PRINT_VECTOR
    int 21h
    ; Restore the chain before the base reader releases tracked TSR blocks.
    lds dx,cs:old2f
    mov ax,252fh
    int 21h
    mov ss,cs:saved_ss
    mov sp,cs:saved_sp
    load_regs
chain2f:
    popf
    jmp cs:old2f
unload_busy:
    popf
    iret
unload_handler endp

; Register packet AX BX CX DX SI DI BP DS ES FLAGS; kind 0 DOS, 1 multiplex,
; 2 EMS, 3 XMS far call. SS=DS=CS whenever C calls this bridge.
PrintService proc near
    push bp
    mov bp,sp
    pushf
    push es
    push ds
    push di
    push si
    push dx
    push cx
    push bx
    mov si,[bp+6]
    push word ptr [si+16]
    push word ptr [si+14]
    push word ptr [si+8]
    mov ax,[si]
    mov bx,[si+2]
    mov cx,[si+4]
    mov dx,[si+6]
    mov di,[si+10]
    pop si
    pop ds
    pop es
    cmp word ptr ss:[bp+4],0
    je service_dos
    cmp word ptr ss:[bp+4],1
    je service_multiplex
    cmp word ptr ss:[bp+4],2
    je service_ems
    push bp
    call cs:PrintXmsEntry
    pop bp
    jmp short service_result
service_dos:
    int 21h
    jmp short service_result
service_multiplex:
    int 2fh
    jmp short service_result
service_ems:
    int 67h
service_result:
    pushf
    push es
    push ds
    push di
    push si
    push dx
    push cx
    push bx
    push ax
    push cs
    pop ds
    push cs
    pop es
    mov si,sp
    mov di,ss:[bp+6]
    mov cx,6
    cld
    rep movsw
    add di,2
    mov cx,3
    rep movsw
    add sp,18
    pop bx
    pop cx
    pop dx
    pop si
    pop di
    pop ds
    pop es
    popf
    pop bp
    ret
PrintService endp

INIT_TEXT segment word public 'INIT'
assume cs:INIT_TEXT
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
    mov PrintSegment,cs
    cli
    mov ax,cs
    mov ss,ax
    mov sp,offset stack_top
    sti
    call InitializePrintFonts
    cmp ax,2
    je normal_exit
    or ax,ax
    jz failed_exit
    mov ax,offset resident_end+15
    mov cl,4
    shr ax,cl
    mov resident_paragraphs,ax
    cmp PrintLow,0
    jne keep_low
    call AllocateUmb
    cmp umb_segment,0
    je keep_low
    mov es,umb_segment
    xor si,si
    xor di,di
    mov cx,offset resident_end
    rep movsb
    mov es:PrintSegment,es
    mov es,ds:[2ch]
    mov ah,49h
    int 21h
    mov ax,umb_segment
    mov ds,ax
    call SetVectors
    push cs
    pop ds
    mov bx,umb_segment
    mov ah,50h
    int 21h
    push cs
    pop es
    mov ah,49h
    int 21h
    mov dx,resident_paragraphs
    mov ax,3100h
    int 21h
keep_low:
    mov es,ds:[2ch]
    mov ah,49h
    int 21h
    call SetVectors
    mov dx,resident_paragraphs
    mov ax,3100h
    int 21h
failed_exit:
    mov ax,4c01h
    int 21h
normal_exit:
    mov ax,4c00h
    int 21h

SetVectors proc near
    mov ax,3500h+PRINT_VECTOR
    int 21h
    mov word ptr old_font,bx
    mov word ptr old_font+2,es
    mov ax,352fh
    int 21h
    mov word ptr old2f,bx
    mov word ptr old2f+2,es
    mov dx,offset unload_handler
    mov ax,252fh
    int 21h
    mov dx,offset print_handler
    mov ax,2500h+PRINT_VECTOR
    int 21h
    ret
SetVectors endp

AllocateUmb proc near
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
    mov word ptr es:[8],'ER'
    mov word ptr es:[10],'DA'
    mov word ptr es:[12],('0'+PRINT_SIZE/10)+('0'+PRINT_SIZE mod 10)*256
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
AllocateUmb endp
old_strategy dw 0
old_link dw 0
umb_segment dw 0
resident_paragraphs dw 0
INIT_TEXT ends

_BSS segment word public 'BSS'
bss_begin label byte
empty_band db 180 dup (?)
stack_bottom db 2048 dup (?)
stack_top label byte
_BSS ends
_END segment byte public 'ZZEND'
resident_end db 0
_END ends
_SCRATCH segment para public 'TAIL'
public PrintTransfer
PrintTransfer db 4096 dup (0)
_SCRATCH ends
DGROUP group _BSS, _END, _SCRATCH, INIT_TEXT
end start

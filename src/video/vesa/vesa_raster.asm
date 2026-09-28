; Bank selection stays in C. These USE16 loops operate entirely within one
; mapped window and retain the near cdecl ABI of the resident driver.
.model tiny,c
.code
.386
extrn display_pitch:word, screen:byte

; Two left-aligned ten-bit rows fit in EAX. Their six low zero bits keep
; shifts from carrying pixels into the next row. No read crosses a bank.
public raster_words
raster_words proc near
    push bp
    mov bp,sp
    pushad
    push es
    mov ax,word ptr screen+6
    mov es,ax
    mov si,[bp+4]               ; glyph rows
    mov di,[bp+6]               ; window offset
    mov dx,[bp+8]               ; row count
    mov cx,[bp+10]              ; bit shift, 0..6
    mov bx,0ffc0h
    shr bx,cl
    xchg bl,bh
    not bx
    push bx                    ; neighbor mask at BP-36
    movsx ebx,word ptr [bp+12]  ; foreground, 0 or -1
    movsx ebp,word ptr [bp+14]  ; background, 0 or -1
    xor ebx,ebp
words_pair:
    cmp dx,2
    jb words_tail
    lodsd
    and eax,0ffc0ffc0h
    shr eax,cl
    and eax,ebx
    xor eax,ebp
    call words_store
    ror eax,16
    call words_store
    sub dx,2
    jmp short words_pair
words_tail:
    or dx,dx
    jz words_done
    lodsw
    and ax,0ffc0h
    shr ax,cl
    and eax,ebx
    xor eax,ebp
    call words_store
words_done:
    add sp,2
    pop es
    popad
    pop bp
    ret
words_store:
    xchg al,ah
    push bx
    push bp
    mov bp,sp
    mov bx,es:[di]
    xor bx,ax
    and bx,ss:[bp+6]            ; mask below return address and two pushes
    xor bx,ax
    mov es:[di],bx
    add di,cs:display_pitch
    pop bp
    pop bx
    ret
raster_words endp

; Packed glyph bytes, up to 96 pixels after enlargement. Process four bytes
; at a time, with byte tails so no memory access extends past the bank span.
public raster_span
raster_span proc near
    push bp
    mov bp,sp
    sub sp,12
    pushad
    push es
    mov ax,word ptr screen+6
    mov es,ax
    mov si,[bp+4]
    mov di,[bp+6]
    mov ax,[bp+8]
    mov [bp-2],ax
    mov ax,[bp+18]              ; vertical repetition count
    sub ax,[bp+20]              ; phase at the start of this bank
    mov [bp-4],ax
    movsx eax,word ptr [bp+14]  ; foreground
    movsx edx,word ptr [bp+16]  ; background
    xor eax,edx
    mov [bp-8],eax
    mov [bp-12],edx
    ; Native 8/16/24-pixel cells overwrite complete bytes. Avoid VGA reads
    ; and edge merging here; the caller has already bounded this bank span.
    cmp word ptr [bp+18],1
    jne span_row
    mov bx,[bp+12]
    mov cx,[bp+10]
    cmp cx,2
    jne span_native_bounds
    cmp word ptr [bx],0ffffh
    jne span_native_masked_word
span_native_bounds:
    cmp byte ptr [bx],0ffh
    jne span_row
    cmp cx,3
    ja span_row
    jne span_native_edges
    cmp byte ptr [bx+1],0ffh
    jne span_row
span_native_edges:
    add bx,cx
    cmp byte ptr [bx-1],0ffh
    jne span_row
    mov ax,cx
    mov cx,[bp-2]
    mov dx,word ptr [bp-8]
    mov bx,word ptr [bp-12]
    cmp ax,2
    je span_native_word
    ja span_native_three
span_native_byte:
    mov al,[si]
    and al,dl
    xor al,bl
    mov es:[di],al
    add si,16
    add di,cs:display_pitch
    loop span_native_byte
    jmp span_done
span_native_word:
    mov ax,[si]
    and ax,dx
    xor ax,bx
    mov es:[di],ax
    add si,16
    add di,cs:display_pitch
    loop span_native_word
    jmp span_done
span_native_three:
    mov ax,[si]
    and ax,dx
    xor ax,bx
    mov es:[di],ax
    mov al,[si+2]
    and al,dl
    xor al,bl
    mov es:[di+2],al
    add si,16
    add di,cs:display_pitch
    loop span_native_three
    jmp span_done
    ; Twelve-pixel cells alternate between left and right half-byte edges.
    ; Keep the mask across rows and merge each destination word only once.
span_native_masked_word:
    mov bx,[bx]
    mov cx,[bp-2]
span_masked_word_row:
    mov ax,[si]
    and ax,word ptr [bp-8]
    xor ax,word ptr [bp-12]
    mov dx,es:[di]
    xor ax,dx
    and ax,bx
    xor ax,dx
    mov es:[di],ax
    add si,16
    add di,cs:display_pitch
    loop span_masked_word_row
    jmp span_done
span_row:
    push si
    push di
    mov bx,[bp+12]             ; masks, one byte per destination byte
    mov cx,[bp+10]
span_dword:
    cmp cx,4
    jb span_word
    mov eax,[si]
    and eax,[bp-8]
    xor eax,[bp-12]
    mov edx,es:[di]
    xor eax,edx
    and eax,[bx]
    xor eax,edx
    mov es:[di],eax
    add si,4
    add di,4
    add bx,4
    sub cx,4
    jmp short span_dword
span_word:
    cmp cx,2
    jb span_byte
    lodsw
    and ax,word ptr [bp-8]
    xor ax,word ptr [bp-12]
    mov dx,es:[di]
    xor ax,dx
    and ax,[bx]
    xor ax,dx
    stosw
    add bx,2
    sub cx,2
span_byte:
    jcxz span_next_row
    lodsb
    and al,byte ptr [bp-8]
    xor al,byte ptr [bp-12]
    mov dl,es:[di]
    xor al,dl
    and al,[bx]
    xor al,dl
    stosb
    inc bx
    loop span_byte
span_next_row:
    pop di
    pop si
    add di,cs:display_pitch
    dec word ptr [bp-4]
    jnz span_same_source
    add si,16
    mov ax,[bp+18]
    mov [bp-4],ax
span_same_source:
    dec word ptr [bp-2]
    jnz span_row
span_done:
    pop es
    popad
    mov sp,bp
    pop bp
    ret
raster_span endp

; Forward, non-overlapping spans, at most 64 KiB. Plane selection is owned
; by the caller. Wide accesses are safe in VGA write mode zero only.
public raster_copy
raster_copy proc near
    push bp
    mov bp,sp
    pushad
    push ds
    push es
    les di,[bp+4]
    lds si,[bp+8]
    mov cx,[bp+12]
    mov bx,cx
    shr cx,2
    cld
    rep movsd
    mov cx,bx
    and cx,3
    rep movsb
    pop es
    pop ds
    popad
    pop bp
    ret
raster_copy endp

; VGA write mode one copies all four latches together. Each byte read must
; be immediately followed by its byte write; MOVSW/MOVSD would lose latches.
public raster_latches
raster_latches proc near
    push bp
    mov bp,sp
    pushad
    push ds
    push es
    mov ax,word ptr screen+6
    mov ds,ax
    mov es,ax
    mov di,[bp+4]
    mov si,[bp+6]
    mov cx,[bp+8]
    mov dx,3c4h
    mov ax,0f02h
    out dx,ax
    mov dx,3ceh
    mov ax,0105h
    out dx,ax
    cld
    rep movsb
    mov ax,0005h
    out dx,ax
    pop es
    pop ds
    popad
    pop bp
    ret
raster_latches endp
end

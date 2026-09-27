; Bounded, transparent log of mode, font and adapter BIOS requests.
.code
old_video dd 0
public _video_count, _video_log, install_video_log_
_video_count dw 0
_video_log dw 1024 dup (0)
video:
    pushf
    cmp ah,0
    je video_record
    cmp ah,0bh
    je video_record
    cmp ah,10h
    je video_record
    cmp ah,11h
    je video_record
    cmp ah,12h
    je video_record
    cmp ah,1ah
    jne video_forward
video_record:
    cmp cs:_video_count,256
    jae video_forward
    push si
    mov si,cs:_video_count
    shl si,1
    shl si,1
    shl si,1
    mov cs:_video_log[si],ax
    mov cs:_video_log[si+2],bx
    mov cs:_video_log[si+4],cx
    mov cs:_video_log[si+6],dx
    inc cs:_video_count
    pop si
video_forward:
    popf
    jmp dword ptr cs:old_video
install_video_log_:
    mov ax,3510h
    int 21h
    mov word ptr cs:old_video,bx
    mov word ptr cs:old_video+2,es
    mov dx,offset video
    mov ax,2510h
    int 21h
    ret
end

.code
extrn _mouse_count:word, _mouse_log:word
public mouse_event_
mouse_event_ proc far
    push si
    mov si,cs:_mouse_count
    cmp si,32
    jae done
    shl si,1
    shl si,1
    shl si,1
    mov cs:_mouse_log[si],ax
    mov cs:_mouse_log[si+2],bx
    mov cs:_mouse_log[si+4],cx
    mov cs:_mouse_log[si+6],dx
    inc cs:_mouse_count
done:
    pop si
    retf
mouse_event_ endp
end

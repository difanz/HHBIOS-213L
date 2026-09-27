; Observe the real shared C entry wrappers on an unrelated caller stack.
.model tiny
.code
org 100h
start label near
dw S_CORNER, S_ESAME, S_ESHIFT, D_EROW, D_EOFF, D_EDEL
include frame.inc
D_EROW db 80 dup (0)
D_EOFF dw 0
D_EDEL dw 0
include edit_check.inc
COMMON_TEXT segment word public 'COMMON'
COMMON_TEXT ends
DGROUP group COMMON_TEXT
end start

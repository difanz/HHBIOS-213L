; Default operands keep legacy display modules at 80x25. The VESA backend
; supplies resident operands before including the shared classifier.
IFNDEF XR_ROWS
XR_ROWS TEXTEQU <25>
XR_LASTROW TEXTEQU <24>
XR_CELLS TEXTEQU <2000>
ENDIF

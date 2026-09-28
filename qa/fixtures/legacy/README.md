`READ24.ASM` is the unchanged printing reader from commit
`ae69380f5e8e8a9698e822303e096909d24b9478`, formerly `src/font/READ24.ASM`.
Its GBK text, CRLF line endings and DOS EOF byte are preserved.

SHA-256: `3bc5ae0bed4b47cbfdc76e4b48a6b7513321046044794fc3632395d30d21380e`.

Tests assemble it as the reference for the C printing renderer. CPU tests
substitute only glyph retrieval; DOS tests load equivalent real files through
both readers and compare their interrupt results. It is not a distribution
module. Production `READ24`, `READ32` and `READ40` use `src/font/print_font.c`.

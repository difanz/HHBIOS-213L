@echo off
REM READ2 + VGA + CMODE 3, then an ASCII and CP437 frame.
read2.com > nul
vga.com > nul
cmode.com 3 > nul
tvwest.com > nul

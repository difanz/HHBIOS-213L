@echo off
REM READ2 + VGA + CMODE 3, then a TurboVision-style B800 frame.
read2.com > nul
vga.com > nul
cmode.com 3 > nul
tvframe.com > nul

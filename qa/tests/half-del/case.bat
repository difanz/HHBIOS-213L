@echo off
REM READ2 + VGA + CMODE 3, then one-cell deletes and a teletype backspace.
read2.com > nul
vga.com > nul
cmode.com 3 > nul
hdel.com

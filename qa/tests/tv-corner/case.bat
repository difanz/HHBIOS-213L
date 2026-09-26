@echo off
REM READ2 + VGA + CMODE 3, then short corner-and-bar frames.
read2.com > nul
vga.com > nul
cmode.com 3 > nul
corner.com > nul

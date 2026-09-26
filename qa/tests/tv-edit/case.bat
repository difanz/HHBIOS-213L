@echo off
REM READ2 + VGA + CMODE 3, then magiblot tvedit on a mixed file.
read2.com > nul
vga.com > nul
cmode.com 3 > nul
echo TVEDIT_STACK
shotdly.com
tvedit.exe tvview.txt

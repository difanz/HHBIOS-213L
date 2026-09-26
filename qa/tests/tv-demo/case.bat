@echo off
REM READ2 + VGA + CMODE 3, then the cached 16-bit tvdemo.
read2.com > nul
vga.com > nul
cmode.com 3 > nul
echo TVDEMO_STACK
keysock.com > nul
echo ready> ready.flg
shotdly.com
tvdemo.exe

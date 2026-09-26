@echo off
REM Character mode is up before the help text is sent to INT 10h.
read2.com > nul
vga.com > nul
cmode.com 3 > nul
ckbd.com /? > case.log
copy case.log view.txt > nul
conout.com > nul
waitshot.com >> case.log

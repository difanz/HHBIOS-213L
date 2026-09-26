@echo off
REM READ2 loads HZK16. VGA stays resident. CMODE 3 is character mode.
REM CONOUT feeds VIEW.TXT to INT 10h AH=0Eh so VGA draws HZK16.
read2.com > nul
vga.com > nul
cmode.com 3 > nul
vga.com /? > case.log
copy case.log view.txt > nul
conout.com > nul
waitshot.com >> case.log

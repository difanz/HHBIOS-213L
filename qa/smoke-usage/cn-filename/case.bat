@echo off
REM READ2 + VGA character mode, then CONOUT draws the DIR listing.
read2.com > nul
vga.com > nul
cmode.com 3 > nul
cnname.com > case.log
dir >> case.log
copy case.log view.txt > nul
conout.com > nul
waitshot.com >> case.log

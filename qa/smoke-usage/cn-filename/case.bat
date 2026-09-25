@echo off
REM VGA.COM stays resident. HZK16 is fonts/HZK16.
REM DIR text is not on the graphics page; CNSHOW spells the name there.
vga.com > nul
cnname.com
dir >> case.log
cnshow.com

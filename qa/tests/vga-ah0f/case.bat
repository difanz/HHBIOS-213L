@echo off
REM Set a VGA mode, call INT 10h AH=0Fh, print the mode byte from 0040:0049.
REM Example lines once the COM exists:
REM   MODE=12
REM   VGA_AH0F_OK
vga-ah0f.com

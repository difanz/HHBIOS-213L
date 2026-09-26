/*
 * Feed a text file to VGA teletype (INT 10h AH=0Eh, BL=07).
 * READ2 + VGA character mode turns those bytes into HZK16 glyphs.
 * DOSBox-X's TYPE > CON calls INT 10h from the console callback;
 * glyph writes made there do not stay on the page. This program
 * issues the same teletype from ordinary code, where they do.
 */
#include <dos.h>
#include <i86.h>
#include <stdio.h>

int main(void)
{
    FILE *in;
    FILE *log;
    int ch;
    union REGS regs;

    in = fopen("VIEW.TXT", "rb");
    if (!in) {
        log = fopen("CASE.LOG", "a");
        if (log) {
            fputs("CONOUT_FAIL\n", log);
            fclose(log);
        }
        return 1;
    }
    while ((ch = fgetc(in)) != EOF) {
        regs.h.ah = 0x0E;
        regs.h.al = (unsigned char)ch;
        regs.x.bx = 0x0007;
        int86(0x10, &regs, &regs);
    }
    fclose(in);
    log = fopen("CASE.LOG", "a");
    if (log) {
        fputs("CONOUT_OK\n", log);
        fclose(log);
    }
    return 0;
}

/*
 * READ2 installs INT 7Fh. DX is a GB2312 code; the handler returns the
 * glyph segment. 中 is D6 D0. The first eight bytes are the HZK16 row data.
 */
#include <i86.h>
#include <stdio.h>

int main(void)
{
    union REGS regs;
    unsigned char __far *glyph;
    int i;

    regs.w.ax = 0x4A06;
    regs.w.si = 3;
    int86(0x2F, &regs, &regs);
    printf("BX=%04X\n", regs.w.bx);
    if (regs.w.bx != 0x4A06) {
        printf("READ2_ABSENT\n");
        return 1;
    }
    printf("READ2_RESIDENT\n");

    regs.w.ax = 0;
    regs.w.dx = 0xD6D0;
    int86(0x7F, &regs, &regs);
    glyph = (unsigned char __far *)MK_FP(regs.w.dx, 0);
    printf("GLYPH=");
    for (i = 0; i < 8; i++) {
        printf("%02X", glyph[i]);
    }
    printf("\n");
    return 0;
}

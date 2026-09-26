/*
 * INT 2Fh AX=4A06h SI=0 is the EXIT unload (restore vectors, clear INT 7Fh).
 * SI=3 afterwards must not report the resident id.
 */
#include <i86.h>
#include <stdio.h>

int main(void)
{
    union REGS regs;

    regs.w.ax = 0x4A06;
    regs.w.si = 3;
    int86(0x2F, &regs, &regs);
    printf("BEFORE=%04X\n", regs.w.bx);
    if (regs.w.bx != 0x4A06) {
        printf("UNLOAD_ABSENT\n");
        return 1;
    }

    regs.w.ax = 0x4A06;
    regs.w.si = 0;
    int86(0x2F, &regs, &regs);

    regs.w.ax = 0x4A06;
    regs.w.si = 3;
    int86(0x2F, &regs, &regs);
    printf("AFTER=%04X\n", regs.w.bx);
    if (regs.w.bx != 0x4A06) {
        printf("UNLOAD_OK\n");
        return 0;
    }
    printf("UNLOAD_FAIL\n");
    return 1;
}

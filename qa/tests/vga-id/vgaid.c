/*
 * After VGA.COM is resident, INT 10h AH=FFh returns AL='V' (AX=0056h).
 */
#include <i86.h>
#include <stdio.h>

int main(void)
{
    union REGS regs;

    regs.w.ax = 0xFF00;
    int86(0x10, &regs, &regs);
    printf("AX=%04X\n", regs.w.ax);
    if (regs.w.ax == 0x0056) {
        printf("VGA_ID_OK\n");
        return 0;
    }
    printf("VGA_ID_FAIL\n");
    return 1;
}

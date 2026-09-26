/*
 * Set VGA mode 12h and read it back with INT 10h AH=0Fh and BIOS 0040:0049.
 */
#include <i86.h>
#include <stdio.h>

int main(void)
{
    union REGS regs;
    unsigned char mode;
    unsigned char bios;

    regs.w.ax = 0x0012;
    int86(0x10, &regs, &regs);

    regs.w.ax = 0x0F00;
    int86(0x10, &regs, &regs);
    mode = regs.h.al;
    bios = *(unsigned char __far *)MK_FP(0x40, 0x49);

    printf("MODE=%02X\n", mode);
    printf("BIOS=%02X\n", bios);
    if (mode == 0x12 && bios == 0x12) {
        printf("VGA_AH0F_OK\n");
        return 0;
    }
    printf("VGA_AH0F_FAIL\n");
    return 1;
}

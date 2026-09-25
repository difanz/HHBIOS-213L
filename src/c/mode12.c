/*
 * BIOS mode 12h with a white frame and teletype text, held for a screenshot.
 */
#include <i86.h>
#include <stdio.h>

static void plot(int x, int y, int color)
{
    union REGS regs;

    regs.h.ah = 0x0C;
    regs.h.al = (unsigned char)color;
    regs.h.bh = 0;
    regs.w.cx = (unsigned short)x;
    regs.w.dx = (unsigned short)y;
    int86(0x10, &regs, &regs);
}

static void frame(int x0, int y0, int x1, int y1)
{
    int x;
    int y;

    for (x = x0; x <= x1; x++) {
        plot(x, y0, 15);
        plot(x, y1, 15);
    }
    for (y = y0; y <= y1; y++) {
        plot(x0, y, 15);
        plot(x1, y, 15);
    }
}

static void teletype(const char *text)
{
    union REGS regs;

    while (*text) {
        regs.h.ah = 0x0E;
        regs.h.al = (unsigned char)*text++;
        regs.h.bh = 0;
        regs.h.bl = 15;
        int86(0x10, &regs, &regs);
    }
}

int main(void)
{
    union REGS regs;
    unsigned char mode;
    FILE *flag;

    regs.w.ax = 0x0012;
    int86(0x10, &regs, &regs);
    regs.w.ax = 0x0F00;
    int86(0x10, &regs, &regs);
    mode = regs.h.al;
    printf("MODE=%02X\n", mode);
    if (mode == 0x12) {
        printf("MODE12_OK\n");
    } else {
        printf("MODE12_FAIL\n");
    }
    fflush(stdout);

    teletype("MODE 12H");
    frame(48, 64, 590, 400);

    flag = fopen("SHOT.FLG", "w");
    if (flag) {
        fputs("1\n", flag);
        fclose(flag);
    }
    regs.h.ah = 0x00;
    int86(0x16, &regs, &regs);
    printf("SHOT_DONE\n");
    return mode == 0x12 ? 0 : 1;
}

/*
 * Plot two HZK16 glyphs (中 D6D0, 文 CEC4) in VGA mode 12h.
 * READ2 supplies INT 7Fh. VGA.COM's AH=0Ch forwards to the BIOS.
 * Stays in graphics mode until the host sends a key.
 */
#include <i86.h>
#include <stdio.h>

static unsigned char zhong[32];
static unsigned char wen[32];

static void copy_glyph(unsigned code, unsigned char *dst)
{
    union REGS regs;
    unsigned char __far *src;
    int i;

    regs.w.ax = 0;
    regs.w.dx = code;
    int86(0x7F, &regs, &regs);
    src = (unsigned char __far *)MK_FP(regs.w.dx, 0);
    for (i = 0; i < 32; i++) {
        dst[i] = src[i];
    }
}

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

static void block(int x, int y, int color)
{
    int sx;
    int sy;

    for (sy = 0; sy < 3; sy++) {
        for (sx = 0; sx < 3; sx++) {
            plot(x + sx, y + sy, color);
        }
    }
}

static void blit(const unsigned char *glyph, int ox, int oy, int color)
{
    int row;
    int col;

    for (row = 0; row < 16; row++) {
        unsigned char left = glyph[row * 2];
        unsigned char right = glyph[row * 2 + 1];
        for (col = 0; col < 8; col++) {
            if (left & (0x80 >> col)) {
                block(ox + col * 3, oy + row * 3, color);
            }
            if (right & (0x80 >> col)) {
                block(ox + (8 + col) * 3, oy + row * 3, color);
            }
        }
    }
}

static void frame(int x0, int y0, int x1, int y1, int color)
{
    int x;
    int y;

    for (x = x0; x <= x1; x++) {
        plot(x, y0, color);
        plot(x, y1, color);
    }
    for (y = y0; y <= y1; y++) {
        plot(x0, y, color);
        plot(x1, y, color);
    }
}

static void print_hex(const unsigned char *glyph)
{
    int i;

    for (i = 0; i < 8; i++) {
        printf("%02X", glyph[i]);
    }
}

int main(void)
{
    union REGS regs;
    FILE *flag;

    regs.w.ax = 0x4A06;
    regs.w.si = 3;
    int86(0x2F, &regs, &regs);
    printf("BX=%04X\n", regs.w.bx);
    if (regs.w.bx != 0x4A06) {
        printf("HZDRAW_NOREAD\n");
        return 1;
    }

    copy_glyph(0xD6D0, zhong);
    copy_glyph(0xCEC4, wen);
    printf("GLYPH=");
    print_hex(zhong);
    printf("\n");
    printf("GLYPH2=");
    print_hex(wen);
    printf("\n");

    regs.w.ax = 0x0012;
    int86(0x10, &regs, &regs);
    frame(40, 40, 360, 140, 15);
    blit(zhong, 56, 56, 15);
    blit(wen, 200, 56, 14);

    printf("HZDRAW_OK\n");
    fflush(stdout);

    flag = fopen("SHOT.FLG", "w");
    if (flag) {
        fputs("1\n", flag);
        fclose(flag);
    }
    regs.h.ah = 0x00;
    int86(0x16, &regs, &regs);
    printf("SHOT_DONE\n");
    return 0;
}

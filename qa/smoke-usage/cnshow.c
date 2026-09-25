/*
 * VGA.COM leaves the visible page in graphics mode, so TYPE/DIR text
 * does not appear there. Spell the GB2312 filename bytes in that page.
 */
#include <i86.h>
#include <stdio.h>

static const char text[] = "D6D0CEC4.TXT";

/* 5x7 glyphs, top row first, bit 4 is the leftmost pixel. */
static const unsigned char font_0[7] = {0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E};
static const unsigned char font_4[7] = {0x04, 0x0C, 0x14, 0x1F, 0x04, 0x04, 0x04};
static const unsigned char font_6[7] = {0x0E, 0x10, 0x1E, 0x11, 0x11, 0x11, 0x0E};
static const unsigned char font_c[7] = {0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E};
static const unsigned char font_d[7] = {0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E};
static const unsigned char font_e[7] = {0x1F, 0x10, 0x1E, 0x10, 0x10, 0x10, 0x1F};
static const unsigned char font_t[7] = {0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04};
static const unsigned char font_x[7] = {0x11, 0x0A, 0x04, 0x04, 0x04, 0x0A, 0x11};
static const unsigned char font_dot[7] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x0C, 0x0C};

static const unsigned char *glyph_for(char ch)
{
    switch (ch) {
    case '0': return font_0;
    case '4': return font_4;
    case '6': return font_6;
    case 'C': return font_c;
    case 'D': return font_d;
    case 'E': return font_e;
    case 'T': return font_t;
    case 'X': return font_x;
    case '.': return font_dot;
    default: return font_dot;
    }
}

static void plot(int x, int y)
{
    union REGS regs;

    regs.h.ah = 0x0C;
    regs.h.al = 15;
    regs.h.bh = 0;
    regs.w.cx = (unsigned short)x;
    regs.w.dx = (unsigned short)y;
    int86(0x10, &regs, &regs);
}

static void draw(void)
{
    int i;
    int row;
    int col;
    int sx;
    int sy;
    const char *p;

    for (i = 0; i < 400; i++) {
        plot(20 + i, 36);
        plot(20 + i, 150);
    }
    p = text;
    i = 0;
    while (*p) {
        const unsigned char *g = glyph_for(*p);
        int ox = 24 + i * 32;
        for (row = 0; row < 7; row++) {
            for (col = 0; col < 5; col++) {
                if (g[row] & (0x10 >> col)) {
                    for (sy = 0; sy < 4; sy++) {
                        for (sx = 0; sx < 4; sx++) {
                            plot(ox + col * 4 + sx, 48 + row * 4 + sy);
                        }
                    }
                }
            }
        }
        p++;
        i++;
    }
}

int main(void)
{
    union REGS regs;
    FILE *flag;

    regs.w.ax = 0x0012;
    int86(0x10, &regs, &regs);
    draw();
    printf("CNSHOW_OK\n");
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

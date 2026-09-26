/*
 * TurboVision-style text frame for the 2.13L character-mode stack.
 *
 * archive.org/details/bcpp31 (BCPP31.ZIP) is the Borland C++ 3.1
 * compiler. It has no TurboVision library and no TVDEMO, and those
 * binaries are not redistributed here. TurboVision paints by storing
 * CP437 cells in B800. This program does that: a menu bar, a double
 * line window (TFrame), and a single-line list box, with GB2312
 * packed against the borders. Resident VGA (CMODE 3) refreshes B800
 * through its direct-write path.
 *
 * Cells (row, col), glyph bytes:
 *   汉字   row 0, col 12
 *   中文   row 3, col 1   (flush against ║)
 *   显示   row 5, col 1
 *   模块   row 7, col 3   (flush against │)
 */
#include <dos.h>
#include <i86.h>
#include <stdio.h>

#define ATTR 0x0F
#define MENU 0x1F

static void cell(unsigned col, unsigned row, unsigned char ch, unsigned char attr)
{
    unsigned short far *p;

    p = (unsigned short far *)MK_FP(0xB800, (row * 80u + col) * 2u);
    *p = (unsigned short)ch | ((unsigned short)attr << 8);
}

static void fill(unsigned col, unsigned row, unsigned n, unsigned char ch, unsigned char attr)
{
    unsigned i;

    for (i = 0; i < n; i++)
        cell(col + i, row, ch, attr);
}

static void ascii(unsigned col, unsigned row, const char *s, unsigned char attr)
{
    while (*s)
        cell(col++, row, (unsigned char)*s++, attr);
}

static void hz(unsigned col, unsigned row, unsigned char a, unsigned char b, unsigned char attr)
{
    cell(col, row, a, attr);
    cell(col + 1, row, b, attr);
}

static void frame(void)
{
    unsigned col;

    fill(0, 0, 80, ' ', MENU);
    ascii(1, 0, "File", MENU);
    ascii(7, 0, "Edit", MENU);
    hz(12, 0, 0xBA, 0xBA, MENU); /* 汉 */
    hz(14, 0, 0xD7, 0xD6, MENU); /* 字 */
    ascii(17, 0, "Help", MENU);

    cell(0, 2, 0xC9, ATTR);
    fill(1, 2, 33, 0xCD, ATTR);
    cell(34, 2, 0xBB, ATTR);
    ascii(8, 2, " ", ATTR);
    hz(9, 2, 0xBA, 0xBA, ATTR); /* 汉 inside the top rule */
    hz(11, 2, 0xD7, 0xD6, ATTR);
    ascii(13, 2, " TV", ATTR);

    for (col = 3; col <= 8; col++) {
        cell(0, col, 0xBA, ATTR);
        cell(34, col, 0xBA, ATTR);
    }
    hz(1, 3, 0xD6, 0xD0, ATTR); /* 中 */
    hz(3, 3, 0xCE, 0xC4, ATTR); /* 文 */
    ascii(6, 3, "Chinese", ATTR);

    cell(0, 4, 0xBA, ATTR);
    fill(1, 4, 33, 0xC4, ATTR);
    cell(34, 4, 0xBA, ATTR);

    hz(1, 5, 0xCF, 0xD4, ATTR); /* 显 */
    hz(3, 5, 0xCA, 0xBE, ATTR); /* 示 */
    ascii(6, 5, "VGA", ATTR);

    cell(2, 6, 0xDA, ATTR);
    fill(3, 6, 14, 0xC4, ATTR);
    cell(17, 6, 0xBF, ATTR);

    cell(2, 7, 0xB3, ATTR);
    hz(3, 7, 0xC4, 0xA3, ATTR); /* 模 */
    hz(5, 7, 0xBF, 0xE9, ATTR); /* 块 */
    cell(7, 7, 0xB3, ATTR);
    ascii(9, 7, "List", ATTR);

    cell(2, 8, 0xC0, ATTR);
    fill(3, 8, 14, 0xC4, ATTR);
    cell(17, 8, 0xD9, ATTR);

    cell(0, 9, 0xC8, ATTR);
    fill(1, 9, 33, 0xCD, ATTR);
    cell(34, 9, 0xBC, ATTR);
}

static void marker(const char *s)
{
    FILE *log;

    log = fopen("CASE.LOG", "a");
    if (log) {
        fputs(s, log);
        fputc('\n', log);
        fclose(log);
    }
}

int main(void)
{
    union REGS regs;

    _disable();
    frame();
    _enable();

    regs.h.ah = 0x02;
    regs.h.bh = 0;
    regs.h.dh = 24;
    regs.h.dl = 0;
    int86(0x10, &regs, &regs);

    delay(1500);
    marker("TVFRAME_OK");
    {
        FILE *flag;

        flag = fopen("SHOT.FLG", "w");
        if (flag) {
            fputs("1\n", flag);
            fclose(flag);
        }
    }
    regs.h.ah = 0x00;
    int86(0x16, &regs, &regs);
    marker("SHOT_DONE");
    return 0;
}

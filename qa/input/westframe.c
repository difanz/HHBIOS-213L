/*
 * Pure Western text frame on the 2.13L character-mode stack.
 *
 * READ2 + VGA + CMODE 3 stay resident. This program writes only ASCII
 * and CP437 box bytes into B800, the same way Turbo Vision paints a
 * TFrame. A long run of 0xCD is the classic trap: GB2312 屯 is the
 * byte pair CD CD, so a display path that treats every high bit as a
 * GB half draws 屯屯屯 instead of ═. Resident VGA rewrites a run of
 * three or more ═ (and four or more of the other table bytes) before
 * that pairing.
 *
 * No GB2312 is stored on purpose. The mixed screen is magiblot
 * tvedit (qa/tests/tv-edit). This COM is the long 0xCD run.
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

static void frame(void)
{
    unsigned row;

    fill(0, 0, 80, ' ', MENU);
    ascii(1, 0, "File", MENU);
    ascii(8, 0, "Edit", MENU);
    ascii(15, 0, "Search", MENU);
    ascii(24, 0, "Help", MENU);

    cell(0, 2, 0xC9, ATTR);          /* ╔ */
    fill(1, 2, 59, 0xCD, ATTR);      /* ═  (CD CD would be 屯 if paired) */
    cell(60, 2, 0xBB, ATTR);         /* ╗ */
    ascii(4, 2, " WEST ", ATTR);

    for (row = 3; row <= 8; row++) {
        cell(0, row, 0xBA, ATTR);    /* ║ */
        cell(60, row, 0xBA, ATTR);
    }
    ascii(2, 3, "ASCII only", ATTR);

    cell(0, 4, 0xBA, ATTR);
    fill(1, 4, 59, 0xC4, ATTR);      /* ─ */
    cell(60, 4, 0xBA, ATTR);

    ascii(2, 5, "CP437 box", ATTR);

    cell(2, 6, 0xDA, ATTR);          /* ┌ */
    fill(3, 6, 18, 0xC4, ATTR);
    cell(21, 6, 0xBF, ATTR);         /* ┐ */

    cell(2, 7, 0xB3, ATTR);          /* │ */
    ascii(4, 7, "List", ATTR);
    cell(12, 7, 0xB3, ATTR);

    cell(2, 8, 0xC0, ATTR);          /* └ */
    fill(3, 8, 18, 0xC4, ATTR);
    cell(21, 8, 0xD9, ATTR);         /* ┘ */

    cell(0, 9, 0xC8, ATTR);          /* ╚ */
    fill(1, 9, 59, 0xCD, ATTR);
    cell(60, 9, 0xBC, ATTR);         /* ╝ */

    /* Forty ═ with no hanzi on the row. Naive pairing paints twenty 屯. */
    ascii(0, 12, "LINE", ATTR);
    fill(6, 12, 40, 0xCD, ATTR);
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
    marker("WEST_OK");
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

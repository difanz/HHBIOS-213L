/*
 * Tell the host the screen is ready (SHOT.FLG), then wait on INT 16h.
 * The host sends Enter after it takes the screenshot.
 */
#include <i86.h>
#include <stdio.h>

int main(void)
{
    union REGS regs;
    FILE *flag;

    delay(1000);
    flag = fopen("SHOT.FLG", "w");
    if (flag) {
        fputs("1\n", flag);
        fclose(flag);
    }
    /* Host sends Enter after the screenshot. A file created on the host
       is not visible to this mounted drive. */
    regs.h.ah = 0x00;
    int86(0x16, &regs, &regs);
    printf("SHOT_DONE\n");
    return 0;
}

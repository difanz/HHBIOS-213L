/*
 * KEYECHO: read BIOS keys (INT 16h) until Enter and print them.
 * Writes ready.flg before blocking so the host can send keys.txt.
 */
#include <bios.h>
#include <stdio.h>

int main(void)
{
    FILE *flag;
    char buf[80];
    int n;
    unsigned short key;
    unsigned char ascii;

    flag = fopen("ready.flg", "w");
    if (flag != NULL) {
        fputs("READY\n", flag);
        fclose(flag);
    }
    printf("KEYECHO_READY\n");
    fflush(stdout);

    n = 0;
    for (;;) {
        key = _bios_keybrd(_KEYBRD_READ);
        ascii = (unsigned char)(key & 0xFF);
        if (ascii == '\r') {
            break;
        }
        if (ascii == 0 || n >= (int)sizeof(buf) - 1) {
            continue;
        }
        buf[n++] = (char)ascii;
    }
    buf[n] = 0;
    printf("%s\n", buf);
    printf("KEYECHO_OK\n");
    fflush(stdout);
    return 0;
}

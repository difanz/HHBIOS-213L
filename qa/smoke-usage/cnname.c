/*
 * Create a file whose name is the GB2312 bytes for 中文.TXT and
 * print those bytes as ASCII hex. DIR in the usage smoke lists it.
 */
#include <dos.h>
#include <stdio.h>

static char name[] = { 0xD6, 0xD0, 0xCE, 0xC4, '.', 'T', 'X', 'T', 0 };

int main(void)
{
    int handle;
    unsigned err;

    err = _dos_creat(name, 0, &handle);
    if (err != 0) {
        printf("CNNAME_FAIL %u\n", err);
        return 1;
    }
    _dos_close(handle);
    printf("CNNAME_BYTES=D6D0CEC4\n");
    printf("CNNAME_OK\n");
    return 0;
}

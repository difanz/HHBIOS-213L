/* Observe tvedit only after its fixture text is visible for 24 BIOS ticks.
 * Store B800 + the green VGA plane for the first ten rows in resident RAM;
 * inject Alt-X, then a normal DOS invocation writes that RAM to disk.
 * No DOS/file I/O or interrupt-vector changes in the timer callback.
 */
#include <dos.h>
#include <i86.h>
#include <conio.h>
#include <malloc.h>
#include <stdio.h>
#include <string.h>

static unsigned capture_seg, framebuffer, age, settle, finished;
static unsigned char scratch[256];
extern void install_app_tick(void);

void app_poll(void)
{
    unsigned i, j, old4, old5, y, head, tail, next;
    unsigned char __far *text = MK_FP(0xb800, 0);
    unsigned __far *bda = MK_FP(0x40, 0);
    char *marker = "HHBIOS-QA";
    if (finished) return;
    ++age;
    if (!settle) {
        for (i = 0; i < 1991; ++i) {
            for (j = 0; j < 9 && text[2*(i+j)] == marker[j]; ++j) { }
            if (j == 9) { settle = 1; break; }
        }
    } else if (++settle == 25) {
        _disable();
        _fmemcpy(MK_FP(capture_seg, 16), text, 4000);
        outp(0x3ce, 4); old4 = inp(0x3cf);
        outp(0x3ce, 5); old5 = inp(0x3cf);
        outpw(0x3ce, 5);
        outpw(0x3ce, 0x0104); /* green plane: white text on blue background */
        for (y = 0; y < 180; ++y)
            _fmemcpy(MK_FP(capture_seg, 4016+y*80), MK_FP(framebuffer, y*80), 80);
        outpw(0x3ce, 4 | (old4 << 8));
        outpw(0x3ce, 5 | (old5 << 8));
        *(unsigned char __far *)MK_FP(capture_seg, 0) = 1;
        finished = 1;
    }
    if (age >= 18*15) {
        *(unsigned char __far *)MK_FP(capture_seg, 0) = 2;
        finished = 1;
    }
    if (finished) {
        _disable();
        head = bda[0x1a/2]; tail = bda[0x1c/2];
        next = tail + 2;
        if (next >= 0x3e) next = 0x1e;
        if (next != head) { bda[tail/2] = 0x2d00; bda[0x1c/2] = next; }
    }
}

int main(int argc, char **argv)
{
    FILE *file;
    union REGPACK r;
    unsigned i, size;
    if (argc != 2) return 1;
    if (strcmp(argv[1], "dump") == 0) {
        file = fopen("CAPSEG.BIN", "rb");
        if (!file || fread(&capture_seg, 2, 1, file) != 1) return 2;
        fclose(file);
        if (*(unsigned char __far *)MK_FP(capture_seg, 0) != 1) return 3;
        file = fopen("APP.BIN", "wb");
        if (!file) return 4;
        for (i = 0; i < 18416; i += size) {
            size = 18416-i < 256 ? 18416-i : 256;
            _fmemcpy(scratch, MK_FP(capture_seg, i), size);
            if (fwrite(scratch, 1, size, file) != size) return 5;
        }
        return fclose(file) != 0;
    }
    if (strcmp(argv[1], "install") != 0) return 6;
    if (_dos_allocmem(0x500, &capture_seg)) return 7;
    _fmemset(MK_FP(capture_seg, 0), 0, 16);
    _fmemcpy(MK_FP(capture_seg, 1), "HHAPP1", 6);
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1406;
    intr(0x10, &r);
    framebuffer = r.x.bp;
    if (framebuffer < 0xa000 || framebuffer > 0xb000) return 8;
    file = fopen("CAPSEG.BIN", "wb");
    if (!file || fwrite(&capture_seg, 2, 1, file) != 1) return 9;
    if (fclose(file)) return 10;
    install_app_tick();
    _dos_keep(0, (FP_OFF(sbrk(0)) + 15) / 16 + 16);
    return 0;
}

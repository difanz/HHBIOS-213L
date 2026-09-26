/* Observation protocol v1. No PASS strings and no expectations in the guest.
 * INPUT.BIN: repeated mode byte + 4000 text bytes. SNAPnn.BIN: raw B800,
 * BDA cursor word, 25 CRTC registers, then four rendered 38400-byte VGA planes.
 * FONT.BIN is BIOS 8x16. Query the public HHBIOS framebuffer API: DOSBox-X's
 * protected overflow register readback can disagree with its line comparator.
 * This observes the renderer's framebuffer, not the host window compositor.
 * DOS exit status reports transport errors only. Wait using BIOS ticks,
 * then copy atomically so the timer cannot tear a snapshot.
 */
#include <dos.h>
#include <i86.h>
#include <conio.h>
#include <stdio.h>
#include <string.h>

static unsigned char buffer[38400];

static void ticks(unsigned n)
{
    volatile unsigned long __far *clock = MK_FP(0x40, 0x6c);
    unsigned long start = *clock;
    while ((unsigned long)(*clock - start) < n) { }
}

static int font(void)
{
    union REGPACK r;
    FILE *out;
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1130;
    r.h.bh = 6;
    intr(0x10, &r);
    _fmemcpy(buffer, MK_FP(r.x.es, r.x.bp), 4096);
    out = fopen("FONT.BIN", "wb");
    if (!out) return 1;
    if (fwrite(buffer, 1, 4096, out) != 4096) return 2;
    return fclose(out) != 0;
}

static int api(void)
{
    FILE *out;
    union REGS r;
    unsigned values[6];
    memset(&r, 0, sizeof(r));
    r.x.ax = 0xff00; int86(0x10, &r, &r); values[0] = r.x.ax;
    r.x.ax = 0x0f00; int86(0x10, &r, &r); values[1] = r.x.ax;
    values[2] = *(unsigned char __far *)MK_FP(0x40, 0x49);
    r.x.ax = 0x4a06; r.x.si = 3; int86(0x2f, &r, &r); values[3] = r.x.bx;
    r.x.ax = 0x0100; r.x.cx = 0x2000; int86(0x10, &r, &r);
    r.x.ax = 0x0200; r.x.bx = 0; r.x.dx = 0x050a; int86(0x10, &r, &r);
    r.x.ax = 0x0ee0; r.x.bx = 7; int86(0x10, &r, &r);
    r.x.ax = 0x0eab; r.x.bx = 7; int86(0x10, &r, &r);
    values[4] = *(unsigned __far *)MK_FP(0x40, 0x50);
    _fmemcpy(buffer, MK_FP(0xb800, 0), 4000);
    r.x.ax = 0x0e08; int86(0x10, &r, &r);
    values[5] = *(unsigned __far *)MK_FP(0x40, 0x50);
    _fmemcpy(buffer+4000, MK_FP(0xb800, 0), 4000);
    r.x.ax = 0; r.x.dx = 0xd6d0; int86(0x7f, &r, &r);
    _fmemcpy(buffer+8000, MK_FP(r.x.dx, 0), 32);
    out = fopen("API.BIN", "wb");
    if (!out) return 1;
    if (fwrite("HHAPI01\n", 1, 8, out) != 8 ||
        fwrite(values, 2, 6, out) != 6 || fwrite(buffer, 1, 8032, out) != 8032) return 2;
    return fclose(out) != 0;
}

int main(int argc, char **argv)
{
    FILE *in, *out;
    union REGS r;
    union REGPACK display;
    char name[13];
    int mode, frame = 0, plane;
    unsigned old4, old5, y, framebuffer;
    unsigned char crtc[25];
    if (argc > 1 && strcmp(argv[1], "font") == 0) return font();
    if (argc > 1 && strcmp(argv[1], "api") == 0) return api();
    memset(&r, 0, sizeof(r));
    r.x.ax = 0xff00;
    int86(0x10, &r, &r);
    if (r.x.ax != 0x56) return 3;
    /* Hide software cursor, keeping the default 80x25 / 8x18 layout. */
    r.x.ax = 0x0100; r.x.cx = 0x2000;
    int86(0x10, &r, &r);
    in = fopen("INPUT.BIN", "rb");
    if (!in) return 4;
    while ((mode = fgetc(in)) != EOF) {
        if (mode > 3 || frame >= 100) return 5;
        if (fread(buffer, 1, 4000, in) != 4000) return 6;
        r.x.ax = 0x180c; r.h.bh = mode;
        int86(0x10, &r, &r);
        _disable();
        _fmemcpy(MK_FP(0xb800, 0), buffer, 4000);
        _enable();
        ticks(24);
        sprintf(name, "SNAP%02d.BIN", frame++);
        out = fopen(name, "wb");
        if (!out) return 7;
        if (fwrite("HHSNAP1\n", 1, 8, out) != 8) return 8;
        _disable();
        _fmemcpy(buffer, MK_FP(0xb800, 0), 4000);
        _fmemcpy(buffer + 4000, MK_FP(0x40, 0x50), 2);
        _enable();
        if (fwrite(buffer, 1, 4002, out) != 4002) return 8;
        for (y = 0; y < 25; ++y) {
            outp(0x3d4, y); crtc[y] = inp(0x3d5);
        }
        if (fwrite(crtc, 1, 25, out) != 25) return 8;
        memset(&display, 0, sizeof(display));
        display.x.ax = 0x1406;
        intr(0x10, &display);
        framebuffer = display.x.bp;
        if (framebuffer < 0xa000 || framebuffer > 0xb000) return 12;
        for (plane = 0; plane < 4; ++plane) {
            _disable();
            outp(0x3ce, 4); old4 = inp(0x3cf);
            outp(0x3ce, 5); old5 = inp(0x3cf);
            outpw(0x3ce, 5); /* read mode 0 */
            outpw(0x3ce, 4 | (plane << 8));
            for (y = 0; y < 480; ++y) {
                _fmemcpy(buffer + y*80, MK_FP(framebuffer, y*80), 80);
            }
            outpw(0x3ce, 4 | (old4 << 8));
            outpw(0x3ce, 5 | (old5 << 8));
            _enable();
            if (fwrite(buffer, 1, 38400, out) != 38400) return 9;
        }
        if (fclose(out) != 0) return 10;
    }
    if (ferror(in)) return 11;
    return fclose(in) != 0;
}

/* Real-mode VBE observations. Bank geometry comes from the mode-info block;
 * the host checks returned bytes against a pattern independent of HHBIOS.
 */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned char controller[16+512+16], mode[16+256+16], buffer[4096];
static unsigned granularity, window_size, read_window, write_window;
static unsigned read_segment, write_segment;
static FILE *logfile;
static int direct_bank;
static void (__far *window_call)(void);

static void fast_bank(unsigned window, unsigned value);
#pragma aux fast_bank = "mov ax,4f05h" "call dword ptr window_call" \
    parm [bx] [dx] modify [ax dx];

static unsigned word(const unsigned char *p) { return p[0] | ((unsigned)p[1] << 8); }

static void fail(const char *what)
{
    fprintf(logfile, "FAIL %s\n", what);
    fclose(logfile);
    exit(1);
}

static void save(const char *name, const void *data, unsigned size)
{
    FILE *f = fopen(name, "wb");
    if (!f || fwrite(data, 1, size, f) != size || fclose(f)) fail("save");
}

static void call(union REGPACK *r)
{
    unsigned function = r->x.ax;
    intr(0x10, r);
    fprintf(logfile, "%04X %04X %04X %04X %04X\n",
            function, r->x.ax, r->x.bx, r->x.cx, r->x.dx);
}

static void ticks(unsigned n)
{
    volatile unsigned long __far *clock = MK_FP(0x40, 0x6c);
    unsigned long start = *clock;
    while ((unsigned long)(*clock-start) < n) { }
}

static void bank(unsigned window, unsigned value)
{
    union REGPACK r;
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x4f05; r.x.bx = window; r.x.dx = value;
    if (direct_bank) {
        /* VBE 1.x's direct entry need not return an AX status. */
        fast_bank(window, value);
    } else {
        intr(0x10, &r);
        if (r.x.ax != 0x4f) fail("set-bank");
    }
    r.x.ax = 0x4f05; r.x.bx = 0x100 | window;
    intr(0x10, &r);
    if (r.x.ax != 0x4f || r.x.dx != value) fail("get-bank");
}

static void framebuffer(unsigned long size, int writing)
{
    unsigned long offset = 0, window_bytes = (unsigned long)window_size*1024;
    unsigned last = 0xffff;
    FILE *f = writing ? NULL : fopen("FRAME.BIN", "wb");
    if (!writing && !f) fail("frame-open");
    while (offset < size) {
        unsigned which = (unsigned)(offset/window_bytes)*(window_size/granularity);
        unsigned within = (unsigned)(offset%window_bytes);
        unsigned count = sizeof(buffer), i;
        if (size-offset < count) count = (unsigned)(size-offset);
        if (window_bytes-within < count) count = (unsigned)(window_bytes-within);
        if (which != last) {
            bank(writing ? write_window : read_window, which);
            last = which;
        }
        if (writing) {
            for (i = 0; i < count; ++i) {
                unsigned long address = offset+i;
                buffer[i] = (unsigned char)(address ^ (address >> 8) ^ (address >> 16));
            }
            _fmemcpy(MK_FP(write_segment, within), buffer, count);
        } else {
            _fmemcpy(buffer, MK_FP(read_segment, within), count);
            if (fwrite(buffer, 1, count, f) != count) fail("frame-write");
        }
        offset += count;
    }
    if (f && fclose(f)) fail("frame-close");
}

int main(int argc, char **argv)
{
    union REGPACK r;
    unsigned number, i, modes[128], count = 0;
    unsigned char *info = controller+16, *mi = mode+16;
    unsigned __far *list;
    unsigned long size;
    if (argc != 3) return 2;
    logfile = fopen("VBE.TXT", "w");
    if (!logfile) return 3;
    number = (unsigned)strtoul(argv[2], NULL, 16);
    memset(&r, 0, sizeof(r));
    if (!strcmp(argv[1], "invalid")) {
        r.x.ax = 0x4f02; r.x.bx = 0x1ff; call(&r);
        if (r.x.ax == 0x4f) fail("invalid-mode-accepted");
        return fclose(logfile) != 0;
    }
    memset(controller, 0xa5, sizeof(controller));
    memset(info, 0, 256);  /* VBE 1.x caller: no VBE2 signature. */
    r.x.ax = 0x4f00; r.x.es = FP_SEG(info); r.x.di = FP_OFF(info); call(&r);
    if (r.x.ax != 0x4f || memcmp(info, "VESA", 4)) fail("controller");
    save("CTRL.BIN", controller, sizeof(controller));
    list = MK_FP(word(info+16), word(info+14));
    for (i = 0; i < 128; ++i) {
        unsigned m = list[i];
        modes[count++] = m;
        if (m == 0xffff) break;
    }
    if (i == 128) fail("mode-list-not-terminated");
    save("LIST.BIN", modes, count*2);
    memset(mode, 0xa5, sizeof(mode));
    memset(mi, 0, 256);
    r.x.ax = 0x4f01; r.x.cx = number;
    r.x.es = FP_SEG(mi); r.x.di = FP_OFF(mi); call(&r);
    if (r.x.ax != 0x4f) fail("mode-info");
    save("MODE.BIN", mode, sizeof(mode));
    if (!strcmp(argv[1], "query")) return fclose(logfile) != 0;
    direct_bank = !strcmp(argv[1], "far");
    window_call = MK_FP(word(mi+14), word(mi+12));
    if (direct_bank && !window_call) fail("no-direct-window-entry");
    /* This fixture uses VBE 1.2's mandatory extended mode fields. Older BIOS
     * without them needs a separate 1.0/1.1 capability case. */
    if (!(word(mi) & 1) || !(word(mi) & 2) || mi[25] != 8 || mi[27] != 4)
        fail("not-supported-packed-8bpp");
    read_window = (mi[2] & 3) == 3 ? 0 : 1;
    write_window = (mi[2] & 5) == 5 ? 0 : 1;
    if ((mi[2+read_window] & 3) != 3 || (mi[2+write_window] & 5) != 5)
        fail("window-permissions");
    read_segment = word(mi+8+read_window*2);
    write_segment = word(mi+8+write_window*2);
    granularity = word(mi+4); window_size = word(mi+6);
    if (!granularity || !window_size || window_size > 64 || window_size%granularity)
        fail("window-geometry");
    size = (unsigned long)word(mi+16)*word(mi+20);
    r.x.ax = 0x4f02; r.x.bx = number; call(&r);
    if (r.x.ax != 0x4f) fail("set-mode");
    r.x.ax = 0x4f03; call(&r);
    if (r.x.ax != 0x4f || (r.x.bx & 0x3fff) != number) fail("get-mode");
    framebuffer(size, 1);
    ticks(32);  /* Expose resident IRQ refresh while the application owns VGA. */
    framebuffer(size, 0);
    r.x.ax = 3; call(&r);
    return fclose(logfile) != 0;
}

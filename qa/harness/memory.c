/* Observe the DOS arena and interrupt vectors, without judging the driver.
 * Each invocation exits normally so the next snapshot also tests PSP reuse.
 * No emulator-specific interface is used by this DOS program.
 */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static void (__far *xms_entry)(void);
static unsigned xms_total(void);
#pragma aux xms_total = "mov ah,8" "call dword ptr xms_entry" \
    value [dx] modify [ax bx cx];

static unsigned vectors[] = {5, 8, 9, 0x10, 0x16, 0x17, 0x1c, 0x1d,
                             0x21, 0x27, 0x28, 0x2f, 0x60, 0x7f};

int main(int argc, char **argv)
{
    union REGPACK r;
    FILE *out;
    unsigned psp, strategy, linked, segment, count, i, total = 0, ems = 0;
    unsigned char __far *m;
    int valid = 0;
    if (argc != 2) return 1;
    memset(&r, 0, sizeof(r));
    if (!strcmp(argv[1], "reader")) {
        r.x.ax = 0x4a06; r.x.si = 3; intr(0x2f, &r);
        if (r.x.bx != 0x4a06) return 7;
        out = fopen("READER.BIN", "wb");
        if (!out) return 2;
        if (fputc(*(unsigned char __far *)MK_FP(r.x.cx, 0x100), out) == EOF) return 4;
        return fclose(out) != 0;
    }
    if (!strcmp(argv[1], "off")) {
        r.h.ah = 0x51; intr(0x21, &r); psp = r.x.bx;
        segment = *(unsigned __far *)MK_FP(psp, 0x2c);
        r.x.ax = 0x4a06; r.x.si = 0; intr(0x2f, &r);
        /* A freed loader environment may have become this process's own
         * environment. Unloading must not free a block whose owner changed. */
        return *(unsigned __far *)MK_FP(segment-1, 1) == psp ? 0 : 6;
    }
    if (!strcmp(argv[1], "glyphs")) {
        unsigned char glyph[32];
        out = fopen("GLYPHS.BIN", "wb");
        if (!out) return 2;
        for (i = 0; i < 2; ++i) {
            r.x.ax = i << 8; r.x.dx = 0xd6d0; intr(0x7f, &r);
            _fmemcpy(glyph, MK_FP(r.x.dx, 0), sizeof(glyph));
            if (fwrite(glyph, 1, sizeof(glyph), out) != sizeof(glyph)) return 4;
        }
        return fclose(out) != 0;
    }
    if (!strcmp(argv[1], "policy")) {
        r.x.ax = 0x5803; r.x.bx = 1; intr(0x21, &r);
        if (r.x.flags & 1) return 3;
        r.x.ax = 0x5801; r.x.bx = 1; intr(0x21, &r);
        return (r.x.flags & 1) != 0;
    }
    out = fopen(argv[1], "w");
    if (!out) return 2;
    r.x.ax = 0x4300; intr(0x2f, &r);
    if (r.h.al == 0x80) {
        r.x.ax = 0x4310; intr(0x2f, &r);
        xms_entry = MK_FP(r.x.es, r.x.bx);
        total = xms_total();
    }
    r.x.ax = 0x3567; intr(0x21, &r);
    if (!_fmemcmp(MK_FP(r.x.es, 10), "EMMXXXX0", 8)) {
        r.h.ah = 0x42; intr(0x67, &r);
        if (r.h.ah == 0) ems = r.x.bx;
    }
    r.h.ah = 0x51; intr(0x21, &r); psp = r.x.bx;
    r.x.ax = 0x5800; intr(0x21, &r); strategy = r.x.ax;
    r.x.ax = 0x5802; intr(0x21, &r); linked = r.h.al;
    fprintf(out, "HHMEM01\nSTATE %04X %04X %04X %04X %04X\n", psp, strategy, linked, total, ems);
    for (i = 0; i < sizeof(vectors)/sizeof(vectors[0]); ++i) {
        r.x.ax = 0x3500 | vectors[i]; intr(0x21, &r);
        fprintf(out, "VECTOR %02X %04X %04X\n", vectors[i], r.x.es, r.x.bx);
    }
    r.x.ax = 0x5803; r.x.bx = 1; intr(0x21, &r);
    r.h.ah = 0x52; intr(0x21, &r);
    segment = *(unsigned __far *)MK_FP(r.x.es, r.x.bx-2);
    for (count = 0; count < 128; ++count) {
        unsigned owner, size;
        m = MK_FP(segment, 0);
        owner = *(unsigned __far *)(m+1);
        size = *(unsigned __far *)(m+3);
        fprintf(out, "MCB %04X %02X %04X %04X ", segment, m[0], owner, size);
        for (i = 8; i < 16; ++i) fprintf(out, "%02X", m[i]);
        fputc('\n', out);
        if (m[0] == 'Z') { valid = 1; break; }
        if (m[0] != 'M' || segment + size + 1 <= segment) break;
        segment += size + 1;
    }
    r.x.ax = 0x5803; r.x.bx = linked; intr(0x21, &r);
    if (fclose(out) != 0) return 4;
    return valid ? 0 : 5;
}

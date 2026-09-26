/* The same client runs in real mode, Watcom DOS extenders, and DJGPP/DPMI.
 * Observe font bytes and a competing EMS user's pages while extended-memory
 * allocations remain live. No emulator-specific interfaces are used.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef __DJGPP__
#include <dpmi.h>
#include <sys/farptr.h>
#include <sys/movedata.h>
#define PROTECTED 1
#else
#include <dos.h>
#include <i86.h>
#ifdef __386__
#define PROTECTED 1
#endif
#endif

#pragma pack(push, 1)
typedef struct {
    unsigned long di, si, bp, reserved, bx, dx, cx, ax;
    unsigned short flags, es, ds, fs, gs, ip, cs, sp, ss;
} RealRegs;
#pragma pack(pop)

static FILE *report;
#if defined(__WATCOMC__) && defined(PROTECTED)
static unsigned short low_selector;
#endif

static void fail(const char *what, unsigned error)
{
    fprintf(report, "FAIL %s %04X\n", what, error);
    fclose(report);
    exit(1);
}

static void rm_interrupt(unsigned number, RealRegs *r)
{
#ifdef __DJGPP__
    __dpmi_regs regs;
    memset(&regs, 0, sizeof(regs));
    memcpy(&regs, r, sizeof(*r));
    if (__dpmi_int(number, &regs)) fail("simulate", __dpmi_error);
    memcpy(r, &regs, sizeof(*r));
#elif defined(PROTECTED)
    union REGS regs;
    struct SREGS segs;
    memset(&regs, 0, sizeof(regs));
    segread(&segs);
    regs.w.ax = 0x300; regs.w.bx = number;
    segs.es = segs.ds; regs.x.edi = (unsigned long)r;
    int386x(0x31, &regs, &regs, &segs);
    if (regs.x.cflag) fail("simulate", regs.w.ax);
#else
    union REGPACK regs;
    memset(&regs, 0, sizeof(regs));
    regs.x.ax = r->ax; regs.x.bx = r->bx; regs.x.cx = r->cx;
    regs.x.dx = r->dx; regs.x.si = r->si; regs.x.di = r->di;
    regs.x.bp = r->bp; regs.x.ds = r->ds; regs.x.es = r->es;
    intr(number, &regs);
    r->ax = regs.x.ax; r->bx = regs.x.bx; r->cx = regs.x.cx;
    r->dx = regs.x.dx; r->si = regs.x.si; r->di = regs.x.di;
    r->ds = regs.x.ds; r->es = regs.x.es; r->flags = regs.x.flags;
#endif
}

static void read_low(unsigned long address, void *data, unsigned size)
{
#ifdef __DJGPP__
    dosmemget(address, size, data);
#elif defined(PROTECTED)
    _fmemcpy(data, MK_FP(low_selector, address), size);
#else
    _fmemcpy(data, MK_FP(address >> 4, address & 15), size);
#endif
}

static void write_low(unsigned long address, const void *data, unsigned size)
{
#ifdef __DJGPP__
    dosmemput(data, size, address);
#elif defined(PROTECTED)
    _fmemcpy(MK_FP(low_selector, address), data, size);
#else
    _fmemcpy(MK_FP(address >> 4, address & 15), data, size);
#endif
}

static void host_info(void)
{
    RealRegs r;
#ifdef __DJGPP__
    __dpmi_version_ret version;
    __dpmi_get_version(&version);
    fprintf(report, "DPMI %u %u %04X\n", version.major, version.minor, version.flags);
#elif defined(PROTECTED)
    union REGS regs;
    memset(&regs, 0, sizeof(regs));
    regs.w.ax = 0x400; int386(0x31, &regs, &regs);
    if (regs.x.cflag) fail("version", regs.w.ax);
    fprintf(report, "DPMI %u %u %04X\n", regs.h.ah, regs.h.al, regs.w.bx);
    regs.w.ax = 0; regs.w.cx = 1; int386(0x31, &regs, &regs);
    if (regs.x.cflag) fail("selector", regs.w.ax);
    low_selector = regs.w.ax;
    regs.w.ax = 7; regs.w.bx = low_selector; regs.w.cx = regs.w.dx = 0;
    int386(0x31, &regs, &regs);
    if (regs.x.cflag) fail("base", regs.w.ax);
    regs.w.ax = 8; regs.w.bx = low_selector; regs.w.cx = 15; regs.w.dx = 0xffff;
    int386(0x31, &regs, &regs);
    if (regs.x.cflag) fail("limit", regs.w.ax);
#else
    fprintf(report, "REALMODE\n");
#endif
    memset(&r, 0, sizeof(r));
    r.ax = 0x1600; rm_interrupt(0x2f, &r);
    fprintf(report, "WINDOWS %04X\n", (unsigned)r.ax);
}

static void ems(RealRegs *r)
{
    rm_interrupt(0x67, r);
    if (r->ax & 0xff00) fail("EMS", (unsigned)r->ax);
}

static unsigned ticks(void)
{
    RealRegs r;
    memset(&r, 0, sizeof(r));
    rm_interrupt(0x1a, &r);
    return (unsigned short)r.dx;
}

int main(int argc, char **argv)
{
    RealRegs r;
    unsigned page, pass, index, handle = 0, frame = 0;
    unsigned char bytes[128], *memory;
    unsigned long size, i, bad = 0, elapsed = 0;
    FILE *glyphs, *pages;
    int inherited = argc > 1 && !strcmp(argv[1], "inherited");
    int use_ems = argc > 1 && (!strcmp(argv[1], "ems") || inherited);
    int resident = argc < 3 || strcmp(argv[2], "bare");
    report = fopen("CLIENT.TXT", "w");
    if (!report) return 1;
    if (sizeof(RealRegs) != 50) fail("register-layout", sizeof(RealRegs));
    host_info();
    if (argc > 1 && (!strcmp(argv[1], "reserve") || !strcmp(argv[1], "mapped"))) {
        unsigned short saved;
        FILE *f;
        memset(&r, 0, sizeof(r));
        r.ax = 0x4300; r.bx = 4; ems(&r); saved = r.dx;
        if (!strcmp(argv[1], "mapped")) {
            r.ax = 0x4100; ems(&r); frame = r.bx;
            for (page = 0; page < 4; ++page) {
                r.ax = 0x4400+page; r.bx = page; r.dx = saved; ems(&r);
                memset(bytes, 0x31+page, sizeof(bytes));
                write_low(((unsigned long)frame << 4)+page*16384UL, bytes, sizeof(bytes));
            }
            r.ax = 0x4700; r.dx = saved; ems(&r);
        }
        f = fopen("HANDLE.BIN", "wb");
        if (!f || fwrite(&saved, sizeof(saved), 1, f) != 1) fail("handle-write", 0);
        if (fclose(f)) fail("handle-close", 0);
        return fclose(report) != 0;
    }
#ifdef PROTECTED
    size = 2UL*1024*1024;
#else
    size = 16384;
#endif
    memory = malloc(size);
    if (!memory) fail("malloc", 0);
    for (i = 0; i < size; ++i) memory[i] = (unsigned char)(i ^ (i >> 8) ^ (i >> 16));
    fprintf(report, "ALLOCATED %lu\n", size);
    memset(&r, 0, sizeof(r));
    if (use_ems) {
        FILE *f;
        unsigned short saved;
        r.ax = 0x4100; ems(&r); frame = r.bx;
        f = fopen("HANDLE.BIN", "rb");
        if (f) {
            if (fread(&saved, sizeof(saved), 1, f) != 1) fail("handle-read", 0);
            fclose(f); handle = saved;
        } else {
            r.ax = 0x4300; r.bx = 4; ems(&r); handle = r.dx;
        }
        for (page = 0; !inherited && page < 4; ++page) {
            r.ax = 0x4400+page; r.bx = page; r.dx = handle; ems(&r);
            memset(bytes, 0x31+page, sizeof(bytes));
            write_low(((unsigned long)frame << 4)+page*16384UL, bytes, sizeof(bytes));
        }
        /* The caller's saved mapping slot must survive HHBIOS calls too. */
        if (!inherited) { r.ax = 0x4700; r.dx = handle; ems(&r); }
    }
    glyphs = fopen("CLIENT.BIN", "wb");
    if (!glyphs) fail("glyph-file", 0);
    for (pass = 0; pass < 64; ++pass) {
        for (index = 0; index < 3; ++index) {
            static unsigned codes[] = {0xd6d0, 0xb9fa, 0xc4e3};
            if (resident) {
                memset(&r, 0, sizeof(r));
                r.ax = (pass & 1) << 8; r.dx = codes[index];
                rm_interrupt(0x7f, &r);
                read_low(r.dx << 4, bytes, 32);
                if (fwrite(bytes, 1, 32, glyphs) != 32) fail("glyph-write", 0);
            }
        }
        if (!(pass & 7)) {
            unsigned start, delta;
            unsigned long polls;
            /* Dirty Chinese text while the EMS map and protected allocation
             * remain live, and leave time for IRQ-driven font reads. */
            bytes[0] = (pass & 8) ? 0xd6 : 0xb9; bytes[1] = 7;
            bytes[2] = (pass & 8) ? 0xd0 : 0xfa; bytes[3] = 7;
            write_low(0xb8000UL+10*160, bytes, 4);
            start = ticks();
            for (polls = 0; polls < 1000000UL; ++polls) {
                delta = (unsigned short)(ticks()-start);
                if (delta >= 4) break;
            }
            if (polls == 1000000UL) fail("timer-stalled", 0);
            elapsed += delta;
        }
    }
    if (fclose(glyphs)) fail("glyph-close", 0);
    if (use_ems) {
        pages = fopen("PAGES.BIN", "wb");
        if (!pages) fail("pages-file", 0);
        /* Observe current mappings first; restoring our saved slot must not
         * hide damage caused by the driver. Then observe that slot as well. */
        for (pass = 0; pass < 2; ++pass) {
            for (page = 0; page < 4; ++page) {
                read_low(((unsigned long)frame << 4)+page*16384UL, bytes, sizeof(bytes));
                if (fwrite(bytes, 1, sizeof(bytes), pages) != sizeof(bytes)) fail("pages-write", 0);
            }
            if (!pass) { r.ax = 0x4800; r.dx = handle; ems(&r); }
        }
        if (fclose(pages)) fail("pages-close", 0);
        r.ax = 0x4500; r.dx = handle; ems(&r);
    }
    for (i = 0; i < size; ++i)
        if (memory[i] != (unsigned char)(i ^ (i >> 8) ^ (i >> 16))) ++bad;
    fprintf(report, "MEMORY_BAD %lu\nTICKS %lu\n", bad, elapsed);
    free(memory);
    return fclose(report) != 0;
}

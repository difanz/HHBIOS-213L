/* Reserve real XMS/EMS blocks to leave a reproducible allocation boundary.
 * Handles survive this process and are explicitly released with "free".
 */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static void (__far *xms_entry)(void);
static unsigned largest(void);
#pragma aux largest = "mov ah,8" "call dword ptr xms_entry" \
    value [ax] modify [bx cx dx];
static unsigned total(void);
#pragma aux total = "mov ah,8" "call dword ptr xms_entry" \
    value [dx] modify [ax bx cx];
static unsigned allocate(unsigned kb);
#pragma aux allocate = "mov ah,9" "call dword ptr xms_entry" \
    "or ax,ax" "jnz short ok" "xor dx,dx" "ok:" \
    parm [dx] value [dx] modify [ax bx cx];
static unsigned release(unsigned handle);
#pragma aux release = "mov ah,0ah" "call dword ptr xms_entry" \
    parm [dx] value [ax] modify [bx cx];

int main(int argc, char **argv)
{
    union REGPACK r;
    unsigned handle = 0, first, last, kb, space[2];
    char kind;
    FILE *f;
    if (argc != 2) return 1;
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x4300; intr(0x2f, &r);
    if (r.h.al == 0x80) {
        r.x.ax = 0x4310; intr(0x2f, &r);
        xms_entry = MK_FP(r.x.es, r.x.bx);
    }
    if (!strcmp(argv[1], "free")) {
        f = fopen("RESERVE.BIN", "rb");
        if (!f) return 2;
        kind = fgetc(f);
        if (fread(&handle, sizeof(handle), 1, f) != 1) return 3;
        fclose(f);
        if (kind == 'X') return !xms_entry || !release(handle);
        if (kind != 'E') return 4;
        r.h.ah = 0x45; r.x.dx = handle; intr(0x67, &r);
        return r.h.ah != 0;
    }
    if (!strcmp(argv[1], "ems")) {
        kind = 'E';
        r.h.ah = 0x42; intr(0x67, &r);
        if (r.h.ah || r.x.bx <= 16) return 5;
        r.x.bx -= 16; r.h.ah = 0x43; intr(0x67, &r);
        if (r.h.ah) return 6;
        handle = r.x.dx;
    } else {
        kind = 'X';
        if (!xms_entry) return 7;
        kb = largest();
        if (kb <= 384) return 8;
        if (!strcmp(argv[1], "xms")) {
            handle = allocate(kb-256);
        } else if (!strcmp(argv[1], "fragment")) {
            first = allocate(192);
            handle = allocate(kb-384);
            last = allocate(192);
            if (!first || !handle || !last) return 9;
            if (!release(first) || !release(last)) return 10;
        } else return 11;
        if (!handle) return 12;
    }
    f = fopen("RESERVE.BIN", "wb");
    if (!f) return 13;
    if (fputc(kind, f) == EOF || fwrite(&handle, sizeof(handle), 1, f) != 1) return 14;
    if (fclose(f)) return 15;
    space[0] = xms_entry ? largest() : 0;
    space[1] = xms_entry ? total() : 0;
    f = fopen("XSPACE.BIN", "wb");
    if (!f) return 13;
    if (fwrite(space, sizeof(space), 1, f) != 1) return 14;
    return fclose(f) != 0;
}

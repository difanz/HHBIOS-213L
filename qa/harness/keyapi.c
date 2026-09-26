/* Check resident mode queries and preservation of already queued input. */
#include <dos.h>
#include <i86.h>
#include <string.h>

int main(int argc, char **argv)
{
    union REGPACK r;
    unsigned i, expected;
    static const unsigned keys[] = {0x1e61, 0x3062};
    if (argc != 2) return 1;
    if (!strcmp(argv[1], "queue")) {
        for (i = 0; i < 2; ++i) {
            memset(&r, 0, sizeof(r));
            r.h.ah = 5; r.x.cx = keys[i];
            intr(0x16, &r);
            if (r.h.al) return 2;
        }
        return 0;
    }
    expected = !strcmp(argv[1], "on");
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x2cff;
    intr(0x16, &r);
    if (r.x.ax != 0x4b48 || r.x.bx != expected) return 3;
    for (i = 0; i < 2; ++i) {
        r.h.ah = 0x11;
        intr(0x16, &r);
        if ((r.x.flags & 0x40) || r.x.ax != keys[i]) return 4;
        r.h.ah = 0x10;
        intr(0x16, &r);
        if (r.x.ax != keys[i]) return 5;
    }
    r.h.ah = 0x11;
    intr(0x16, &r);
    if (!(r.x.flags & 0x40)) return 6;
    return 0;
}

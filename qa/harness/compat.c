/* Raw observations for command-line, BIOS and DOS filename compatibility. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static int save(const char *name, const void *data, unsigned size)
{
    FILE *f = fopen(name, "wb");
    if (!f) return 1;
    if (fwrite(data, 1, size, f) != size) { fclose(f); return 2; }
    return fclose(f) != 0;
}

int main(int argc, char **argv)
{
    union REGPACK r;
    unsigned values[4], i;
    static unsigned char info[512], mode[256];
    memset(&r, 0, sizeof(r));
    if (argc != 2) return 3;
    if (!strcmp(argv[1], "modes")) {
        for (i = 0; i < 2; ++i) {
            r.x.ax = i ? 0x12 : 3; intr(0x10, &r);
            r.x.ax = 0x0f00; intr(0x10, &r);
            values[i*2] = r.h.al;
            values[i*2+1] = *(unsigned char __far *)MK_FP(0x40, 0x49);
        }
        r.x.ax = 3; intr(0x10, &r);
        return save("MODES.BIN", values, sizeof(values));
    }
    if (!strcmp(argv[1], "vbe")) {
        memcpy(info, "VBE2", 4);
        r.x.ax = 0x4f00; r.x.es = FP_SEG(info); r.x.di = FP_OFF(info);
        intr(0x10, &r); values[0] = r.x.ax;
        r.x.ax = 0x4f01; r.x.cx = 0x101;
        r.x.es = FP_SEG(mode); r.x.di = FP_OFF(mode);
        intr(0x10, &r); values[1] = r.x.ax;
        if (save("VBE.BIN", info, sizeof(info))) return 4;
        if (save("VMODE.BIN", mode, sizeof(mode))) return 4;
        return save("VSTATUS.BIN", values, 4);
    }
    if (!strcmp(argv[1], "filename")) {
        static char name[] = "\xd6\xd0\xce\xc4.TXT";
        struct find_t found;
        char bytes[4];
        int handle;
        unsigned count, error;
        error = _dos_creat(name, 0, &handle);
        if (save("CREATE.BIN", &error, sizeof(error))) return 5;
        if (error) return 0;
        if (_dos_write(handle, "GBK\n", 4, &count) || count != 4) return 6;
        if (_dos_close(handle)) return 7;
        if (_dos_findfirst(name, _A_NORMAL, &found)) return 8;
        if (_dos_open(found.name, 0, &handle)) return 9;
        if (_dos_read(handle, bytes, 4, &count) || count != 4) return 10;
        if (_dos_close(handle)) return 11;
        if (save("NAME.BIN", found.name, strlen(found.name))) return 12;
        return save("CONTENT.BIN", bytes, sizeof(bytes));
    }
    return 13;
}

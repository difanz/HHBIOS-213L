/*
 * VBEPROBE: 16-bit DOS VESA BIOS probe for DOSBox-X smoke tests.
 * Build with Open Watcom (tiny model, .COM). Output is ASCII only.
 */
#include <i86.h>
#include <stdio.h>
#include <string.h>

#pragma pack(1)
struct vbe_info {
    char signature[4];
    unsigned short version;
    unsigned short oem_off;
    unsigned short oem_seg;
    unsigned char capabilities[4];
    unsigned short mode_off;
    unsigned short mode_seg;
    unsigned short total_memory; /* 64 KiB units */
};
#pragma pack()

static unsigned char vbe_raw[512];
static unsigned char mode_raw[256];

static unsigned short get16(const unsigned char *p)
{
    return (unsigned short)(p[0] | ((unsigned short)p[1] << 8));
}

static unsigned short far_word(unsigned short seg, unsigned short off)
{
    unsigned short __far *p;

    p = (unsigned short __far *)MK_FP(seg, off);
    return *p;
}

static int query_mode(unsigned short mode, unsigned short *attr,
                      unsigned short *gran, unsigned short *x,
                      unsigned short *y, unsigned int *bpp)
{
    union REGS regs;
    struct SREGS sregs;

    memset(mode_raw, 0, sizeof(mode_raw));
    memset(&regs, 0, sizeof(regs));
    segread(&sregs);
    regs.w.ax = 0x4F01;
    regs.w.cx = mode;
    regs.w.di = FP_OFF(mode_raw);
    sregs.es = FP_SEG(mode_raw);
    int86x(0x10, &regs, &regs, &sregs);
    if (regs.w.ax != 0x004F) {
        return 0;
    }
    *attr = get16(mode_raw + 0x00);
    *gran = get16(mode_raw + 0x04);
    *x = get16(mode_raw + 0x12);
    *y = get16(mode_raw + 0x14);
    *bpp = mode_raw[0x19];
    return 1;
}

int main(void)
{
    union REGS regs;
    struct SREGS sregs;
    struct vbe_info info;
    unsigned short off;
    unsigned short chosen_mode = 0;
    unsigned short chosen_attr = 0;
    unsigned short chosen_gran = 0;
    unsigned short chosen_x = 0;
    unsigned short chosen_y = 0;
    unsigned int chosen_bpp = 0;
    int chosen_rank = 0;
    int printed = 0;
    int i;

    printf("VBEPROBE\n");
    fflush(stdout);

    memset(vbe_raw, 0, sizeof(vbe_raw));
    memcpy(vbe_raw, "VBE2", 4);
    memset(&regs, 0, sizeof(regs));
    segread(&sregs);
    regs.w.ax = 0x4F00;
    regs.w.di = FP_OFF(vbe_raw);
    sregs.es = FP_SEG(vbe_raw);
    int86x(0x10, &regs, &regs, &sregs);

    if (regs.w.ax != 0x004F ||
        vbe_raw[0] != 'V' || vbe_raw[1] != 'E' ||
        vbe_raw[2] != 'S' || vbe_raw[3] != 'A') {
        printf("ax=%04X\n", (unsigned)regs.w.ax);
        printf("VBE_ABSENT\n");
        fflush(stdout);
        return 1;
    }

    memcpy(&info, vbe_raw, sizeof(info));
    printf("signature=VESA\n");
    printf("version=%u.%02u\n",
           (unsigned)(info.version >> 8),
           (unsigned)(info.version & 0xFF));
    printf("memory_kb=%lu\n", (unsigned long)info.total_memory * 64UL);

    off = info.mode_off;
    if (info.mode_seg != 0 || info.mode_off != 0) {
        for (i = 0; i < 64; i++) {
            unsigned short mode;
            unsigned short attr, gran, x, y;
            unsigned int bpp;
            int rank;

            mode = far_word(info.mode_seg, off);
            if (mode == 0xFFFF) {
                break;
            }
            off = (unsigned short)(off + 2);
            if (!query_mode(mode, &attr, &gran, &x, &y, &bpp)) {
                continue;
            }
            if (printed < 8) {
                printf("mode=%04X x=%u y=%u bpp=%u gran=%u lfb=%s\n",
                       (unsigned)mode, (unsigned)x, (unsigned)y, bpp,
                       (unsigned)gran, (attr & 0x0080) ? "yes" : "no");
                printed++;
            }
            rank = 1;
            if (attr & 0x0010) {
                rank = 2;
            }
            if ((attr & 0x0080) && (attr & 0x0010)) {
                rank = 3;
            }
            if (mode == 0x0101) {
                rank = 4;
            }
            if (rank > chosen_rank) {
                chosen_rank = rank;
                chosen_mode = mode;
                chosen_attr = attr;
                chosen_gran = gran;
                chosen_x = x;
                chosen_y = y;
                chosen_bpp = bpp;
            }
        }
    }

    if (chosen_rank == 0) {
        printf("chosen_mode=none\n");
        printf("lfb=unknown\n");
        printf("win_granularity_kb=0\n");
    } else {
        printf("chosen_mode=%04X\n", (unsigned)chosen_mode);
        printf("chosen_x=%u\n", (unsigned)chosen_x);
        printf("chosen_y=%u\n", (unsigned)chosen_y);
        printf("chosen_bpp=%u\n", chosen_bpp);
        printf("lfb=%s\n", (chosen_attr & 0x0080) ? "yes" : "no");
        printf("win_granularity_kb=%u\n", (unsigned)chosen_gran);
    }
    printf("VBEPROBE_OK\n");
    fflush(stdout);
    return 0;
}

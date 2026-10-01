/* Pick a BIOS direct-color linear mode. Mode numbers come from the VBE list. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static unsigned char controller[512];
static unsigned char info[256];

static unsigned word(const unsigned char *p)
{
    return p[0] | ((unsigned)p[1] << 8);
}

static unsigned long dword(const unsigned char *p)
{
    return word(p) | ((unsigned long)word(p + 2) << 16);
}

static int masks_ok(const unsigned char *masks, unsigned bpp)
{
    unsigned channel, previous;

    for (channel = 0; channel < 6; channel += 2) {
        if (!masks[channel] || masks[channel] > 8 ||
            masks[channel + 1] >= bpp ||
            masks[channel] + masks[channel + 1] > bpp) {
            return 0;
        }
        for (previous = 0; previous < channel; previous += 2) {
            if (masks[channel + 1] < masks[previous + 1] + masks[previous] &&
                masks[previous + 1] < masks[channel + 1] + masks[channel]) {
                return 0;
            }
        }
    }
    return 1;
}

int main(void)
{
    union REGPACK r;
    unsigned version, mode, chosen, n, width, height, pitch, bpp, bytes;
    unsigned long list, physical, area, score, best;
    const unsigned char *masks;
    FILE *out;

    chosen = 0xffff;
    best = 0xffffffffUL;
    memset(&r, 0, sizeof(r));
    memcpy(controller, "VBE2", 4);
    r.x.ax = 0x4f00;
    r.x.es = FP_SEG(controller);
    r.x.di = FP_OFF(controller);
    intr(0x10, &r);
    if (r.x.ax != 0x004f || memcmp(controller, "VESA", 4) != 0) {
        goto write_batch;
    }
    version = word(controller + 4);
    if (version < 0x200) {
        goto write_batch;
    }
    list = (unsigned long)word(controller + 16) * 16UL + word(controller + 14);
    for (n = 0; n < 512 && list <= 0xffffeUL; ++n, list += 2) {
        mode = *(unsigned __far *)MK_FP((unsigned)(list >> 4), (unsigned)(list & 15));
        if (mode == 0xffff) {
            break;
        }
        memset(info, 0, sizeof(info));
        memset(&r, 0, sizeof(r));
        r.x.ax = 0x4f01;
        r.x.cx = mode;
        r.x.es = FP_SEG(info);
        r.x.di = FP_OFF(info);
        intr(0x10, &r);
        if (r.x.ax != 0x004f || (word(info) & 0x99) != 0x99) {
            continue;
        }
        if (info[27] != 6 || info[24] != 1) {
            continue;
        }
        bpp = info[25];
        if (bpp != 15 && bpp != 16 && bpp != 32) {
            continue;
        }
        width = word(info + 18);
        height = word(info + 20);
        if (width < 800 || height < 600 || width > 4096 || height > 2160) {
            continue;
        }
        bytes = bpp == 32 ? 4 : 2;
        if (width > 65535U / bytes) {
            continue;
        }
        pitch = word(info + 16);
        if (version >= 0x300 && word(info + 0x32)) {
            pitch = word(info + 0x32);
        }
        if (pitch < width * bytes || pitch > 16384 || (pitch & 1)) {
            continue;
        }
        physical = dword(info + 40);
        if (!physical) {
            continue;
        }
        masks = info + 31;
        if (version >= 0x300 && info[0x36]) {
            masks = info + 0x36;
        }
        if (!masks_ok(masks, bpp)) {
            continue;
        }
        area = (unsigned long)width * height;
        score = area;
        if (bpp == 15) {
            score += 100000000UL;
        } else if (bpp == 32) {
            score += 200000000UL;
        }
        if (score < best) {
            best = score;
            chosen = mode;
        }
    }
write_batch:
    out = fopen("VMODE.BAT", "wb");
    if (!out) {
        return 2;
    }
    if (chosen == 0xffff) {
        fprintf(out, "@echo off\r\necho none>UNSUP.TXT\r\n");
    } else {
        fprintf(out, "@echo off\r\nVESA /M:%x /F:HH20.FNT\r\n", chosen);
    }
    if (fclose(out)) {
        return 3;
    }
    return 0;
}

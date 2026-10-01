/* Dump one direct-color console: idle byte count, one edit, and cell pixels. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static unsigned char screen[32];
static unsigned char span[512];

static unsigned ticks(void)
{
    return *(unsigned __far *)MK_FP(0x40, 0x6c);
}

static void wait_ticks(unsigned count)
{
    unsigned start = ticks();

    while ((unsigned)(ticks() - start) < count) {
    }
}

static unsigned peek_word(unsigned segment, unsigned offset)
{
    return *(unsigned __far *)MK_FP(segment, offset);
}

static int bios(union REGPACK *r)
{
    intr(0x10, r);
    return r->x.ax;
}

static int read_span(unsigned long offset, unsigned count)
{
    union REGPACK r;

    memset(&r, 0, sizeof(r));
    memset(span, 0, sizeof(span));
    r.x.ax = 0x1414;
    r.x.bx = 0;
    r.x.cx = count;
    r.x.dx = (unsigned)(offset >> 16);
    r.x.si = (unsigned)offset;
    r.x.es = FP_SEG(span);
    r.x.di = FP_OFF(span);
    bios(&r);
    return r.x.ax == 0 && count <= sizeof(span);
}

int main(void)
{
    union REGPACK r;
    FILE *out;
    unsigned i, y, bytes, scale, cell_w, cell_h, pitch, bpp;
    unsigned vx, vy, fw, rh;
    unsigned idle_ax, idle_dx, edit_ax, edit_dx;
    unsigned long offset;
    unsigned __far *text;

    memset(&r, 0, sizeof(r));
    r.x.ax = 0xff00;
    bios(&r);
    out = fopen("VLF.BIN", "wb");
    if (!out) {
        return 2;
    }
    if (r.x.ax != 0x56) {
        fputc(1, out);
        fclose(out);
        return 0;
    }
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1411;
    bios(&r);
    if (r.x.ax != 0x5356 || r.x.cx < 28 || r.x.cx > sizeof(screen)) {
        fputc(1, out);
        fclose(out);
        return 0;
    }
    for (i = 0; i < r.x.cx; ++i) {
        screen[i] = *(unsigned char __far *)MK_FP(r.x.es, r.x.di + i);
    }
    if (screen[15] != 6) {
        fputc(2, out);
        fclose(out);
        return 0;
    }
    bpp = screen[16];
    bytes = bpp == 32 ? 4 : 2;
    pitch = screen[4] | ((unsigned)screen[5] << 8);
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x0100;
    r.x.cx = 0x2000;
    bios(&r);
    text = (unsigned __far *)MK_FP(0xb800, 0);
    for (i = 0; i < 80U * 25U; ++i) {
        text[i] = 0x0720;
    }
    wait_ticks(12);
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1418;
    r.x.cx = 1;
    bios(&r);
    wait_ticks(8);
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1418;
    r.x.cx = 1;
    bios(&r);
    idle_ax = r.x.ax;
    idle_dx = r.x.dx;
    text[2 * 80 + 10] = 0x1ed6;
    text[2 * 80 + 11] = 0x1ed0;
    text[2 * 80 + 12] = 0x1ece;
    text[2 * 80 + 13] = 0x1ec4;
    wait_ticks(12);
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1418;
    r.x.cx = 1;
    bios(&r);
    edit_ax = r.x.ax;
    edit_dx = r.x.dx;
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1415;
    bios(&r);
    vx = r.x.bx;
    vy = r.x.cx;
    scale = r.x.dx ? r.x.dx : 1;
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1413;
    bios(&r);
    fw = r.x.si;
    memset(&r, 0, sizeof(r));
    r.x.ax = 0x1406;
    bios(&r);
    rh = r.x.cx >> 8;
    cell_w = fw * scale;
    cell_h = rh * scale;
    if (!fw || !rh || cell_w * bytes > sizeof(span) || cell_h > 256) {
        fputc(3, out);
        fclose(out);
        return 0;
    }
    fputc(0, out);
    fwrite(&bpp, 2, 1, out);
    fwrite(&bytes, 2, 1, out);
    fwrite(&pitch, 2, 1, out);
    fwrite(screen + 0, 2, 1, out);
    fwrite(screen + 2, 2, 1, out);
    fwrite(&vx, 2, 1, out);
    fwrite(&vy, 2, 1, out);
    fwrite(&scale, 2, 1, out);
    fwrite(&fw, 2, 1, out);
    fwrite(&rh, 2, 1, out);
    fwrite(&cell_w, 2, 1, out);
    fwrite(&cell_h, 2, 1, out);
    fwrite(&idle_ax, 2, 1, out);
    fwrite(&idle_dx, 2, 1, out);
    fwrite(&edit_ax, 2, 1, out);
    fwrite(&edit_dx, 2, 1, out);
    fwrite(screen + 18, 6, 1, out);
    for (i = 0; i < 3; ++i) {
        unsigned col = i ? 9 + i : 0;
        unsigned row = i ? 2 : 0;
        for (y = 0; y < cell_h; ++y) {
            offset = (unsigned long)(vy + row * cell_h + y) * pitch +
                     (unsigned long)(vx + col * cell_w) * bytes;
            if (!read_span(offset, cell_w * bytes)) {
                fclose(out);
                return 1;
            }
            if (fwrite(span, 1, cell_w * bytes, out) != cell_w * bytes) {
                fclose(out);
                return 1;
            }
        }
    }
    return fclose(out) != 0;
}

/* Versioned observation protocol. No expectations in the guest.
 * INPUT.BIN: repeated mode byte + 4000 text bytes. SNAPnn.BIN: raw B800,
 * BDA cursor word, 25 CRTC registers, then four rendered VGA planes.
 * VESA uses v2: five geometry words after the signature, full physical pixels.
 * V3 adds viewport x/y and integer scale; the pitch comes from the surface.
 * FONT.BIN is BIOS 8x16. Query the public HHBIOS framebuffer API: DOSBox-X's
 * protected overflow register readback can disagree with its line comparator.
 * This observes the renderer's framebuffer, not the host window compositor.
 * DOS exit status reports transport errors only. Wait using BIOS ticks,
 * then copy atomically so the timer cannot tear a snapshot.
 * "direct <page>" interprets the input byte as a store operation (0..5),
 * selects policy 1 once, and leaves IRQs enabled during every tested write.
 * DIRECT.BIN records the framebuffer segment; PAGEnn.BIN records all 32 KiB
 * of the text aperture, including inactive pages and their padding.
 */
#include <dos.h>
#include <i86.h>
#include <conio.h>
#include <stdio.h>
#include <string.h>
#include "hostshot.h"

static unsigned char buffer[38400];

/* Direct-write probes deliberately keep IRQs enabled, including REP stores.
 * These instructions neither draw through BIOS nor invalidate the driver. */
static void fill_words(unsigned seg,unsigned off,unsigned value,unsigned count);
#pragma aux fill_words = "cld" "rep stosw" \
    parm [es] [di] [ax] [cx] modify [di cx];
static void copy_words(unsigned dstseg,unsigned dstoff,unsigned srcseg,unsigned srcoff,unsigned count);
#pragma aux copy_words = "push ds" "mov ds,dx" "cld" "rep movsw" "pop ds" \
    parm [es] [di] [dx] [si] [cx] modify [di si cx];
static unsigned flags(void);
#pragma aux flags = "pushf" "pop ax" value [ax];

static int direct_write(unsigned page,unsigned op)
{
    unsigned i,seg=0xb800+page*0x100;
    volatile unsigned __far *words=MK_FP(seg,0);
    volatile unsigned char __far *bytes=MK_FP(seg,0);
    if (!(flags() & 0x200)) return 1;
    if (op==0) for (i=0;i<2000;++i) words[i]=buffer[2*i]|((unsigned)buffer[2*i+1]<<8);
    else if (op==1 || op==2) {
        for (i=op-1;i<4000;i+=2) if (bytes[i]!=buffer[i]) bytes[i]=buffer[i];
    } else if (op==3) copy_words(seg,0,FP_SEG(buffer),FP_OFF(buffer),2000);
    else if (op==4) {
        /* Forward MOVSW defines the overlapping upward scroll precisely. */
        copy_words(seg,0,seg,160,1920);
        copy_words(seg,3840,FP_SEG(buffer),FP_OFF(buffer)+3840,80);
    } else if (op==5) fill_words(seg,0,buffer[0]|((unsigned)buffer[1]<<8),2000);
    else return 1;
    return !(flags() & 0x200);
}

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
    unsigned old4, old5, y, framebuffer, pitch, vesa, geometry[10], rows, count, extended, text_bytes;
    unsigned long offset;
    unsigned char crtc[25];
    unsigned direct=argc>1 && strcmp(argv[1],"direct")==0, page=0, i;
    if (argc > 1 && strcmp(argv[1], "font") == 0) return font();
    if (argc > 1 && strcmp(argv[1], "api") == 0) return api();
    if (direct) {
        if (argc!=3 || argv[2][0]<'0' || argv[2][0]>'7' || argv[2][1]) return 16;
        page=(unsigned)(argv[2][0]-'0');
    }
    memset(&r, 0, sizeof(r));
    r.x.ax = 0xff00;
    int86(0x10, &r, &r);
    if (r.x.ax != 0x56) return 3;
    r.x.ax = 0x1411;
    int86(0x10, &r, &r);
    vesa = r.x.ax == 0x5356;
    text_bytes=vesa ? ((unsigned)*(unsigned char __far *)MK_FP(0x40,0x84)+1)*160 : 4000;
    if (text_bytes>8000 || !text_bytes || (direct && text_bytes!=4000)) return 21;
    /* Hide software cursor, retaining the driver's current cell geometry. */
    r.x.ax = 0x0100; r.x.cx = 0x2000;
    int86(0x10, &r, &r);
    if (direct) {
        memset(&display,0,sizeof(display)); display.x.ax=0x1406;
        intr(0x10,&display);
        out=fopen("DIRECT.BIN","wb"); if (!out) return 19;
        if (fwrite(&display.x.bp,2,1,out)!=1) { fclose(out); return 20; }
        if (fclose(out)) return 20;
        /* One initial policy/page selection, before any tested writes. */
        r.x.ax=0x180c; r.x.bx=0x0100; int86(0x10,&r,&r);
        for (i=0;i<8;++i) {
            fill_words(0xb800+i*0x100,0,0x0720,2000);
            fill_words(0xb800+i*0x100,4000,0x5a00+i,48);
        }
        r.x.ax=0x0500|page; int86(0x10,&r,&r);
        r.x.ax=0x0f00; int86(0x10,&r,&r);
        if (r.h.bh!=page) return 17;
        ticks(24);
    }
    in = fopen("INPUT.BIN", "rb");
    if (!in) return 4;
    while ((mode = fgetc(in)) != EOF) {
        if (mode > (direct ? 5 : 3) || frame >= 100) return 5;
        if (fread(buffer, 1, text_bytes, in) != text_bytes) return 6;
        if (direct) {
            if (direct_write(page,(unsigned)mode)) return 18;
        } else {
            r.x.ax = 0x180c; r.h.bh = mode;
            int86(0x10, &r, &r);
            _disable();
            _fmemcpy(MK_FP(0xb800, 0), buffer, text_bytes);
            _enable();
        }
        ticks(24);
        sprintf(name, "SNAP%02d.BIN", frame++);
        out = fopen(name, "wb");
        if (!out) return 7;
        memset(&display, 0, sizeof(display));
        display.x.ax = 0x1406;
        intr(0x10, &display);
        framebuffer = display.x.bp;
        pitch = (display.x.si+1)/8;
        if (pitch < 80 || pitch > 512) return 13;
        if (framebuffer < 0xa000 || framebuffer > 0xb000) return 12;
        extended=0;
        if (vesa) {
            geometry[0]=display.x.si+1; geometry[1]=display.x.di+1;
            geometry[2]=pitch; geometry[3]=10; geometry[4]=display.x.cx>>8;
            display.x.ax=0x1411; intr(0x10,&display);
            if (display.x.ax!=0x5356 || display.x.cx<6) return 13;
            pitch=geometry[2]=*(unsigned __far *)MK_FP(display.x.es,display.x.di+4);
            if (pitch<geometry[0]/8 || pitch>512) return 13;
            display.x.ax=0x1415; intr(0x10,&display);
            if (display.x.ax==0x5650) {
                geometry[5]=display.x.bx; geometry[6]=display.x.cx; geometry[7]=display.x.dx;
                extended=geometry[0]!=800 || geometry[1]!=600 || geometry[5] || geometry[6] || geometry[7]!=1;
            }
        }
        geometry[8]=80; geometry[9]=text_bytes/160;
        count=text_bytes!=4000 ? 10 : extended ? 8 : 5;
        if (fwrite(count==10 ? "HHSNAP4\n" : extended ? "HHSNAP3\n" : vesa ? "HHSNAP2\n" : "HHSNAP1\n", 1, 8, out) != 8) return 8;
        if (vesa && fwrite(geometry,2,count,out)!=count) return 8;
        _disable();
        _fmemcpy(buffer, MK_FP(0xb800+page*0x100, 0), text_bytes);
        _fmemcpy(buffer + text_bytes, MK_FP(0x40, 0x50+page*2), 2);
        _enable();
        if (fwrite(buffer, 1, text_bytes+2, out) != text_bytes+2) return 8;
        for (y = 0; y < 25; ++y) {
            outp(0x3d4, y); crtc[y] = inp(0x3d5);
        }
        if (fwrite(crtc, 1, 25, out) != 25) return 8;
        for (plane = 0; plane < 4; ++plane) {
            if (vesa) {
                for (y=0; y<geometry[1]; y+=rows) {
                    rows=sizeof(buffer)/pitch;
                    if (rows>geometry[1]-y) rows=geometry[1]-y;
                    count=rows*pitch;
                    offset=(unsigned long)y*pitch;
                    display.x.ax=extended ? 0x1414 : 0x1412; display.x.bx=plane;
                    display.x.dx=(unsigned)(offset>>16);
                    display.x.si=(unsigned)offset; display.x.cx=count;
                    display.x.es=FP_SEG(buffer); display.x.di=FP_OFF(buffer);
                    intr(0x10,&display);
                    if (display.x.ax) return 14;
                    if (fwrite(buffer,1,count,out)!=count) return 9;
                }
                continue;
            }
            _disable();
            outp(0x3ce, 4); old4 = inp(0x3cf);
            outp(0x3ce, 5); old5 = inp(0x3cf);
            outpw(0x3ce, 5); /* read mode 0 */
            outpw(0x3ce, 4 | (plane << 8));
            for (y = 0; y < 480; ++y) {
                _fmemcpy(buffer + y*80, MK_FP(framebuffer, y*pitch), 80);
            }
            outpw(0x3ce, 4 | (old4 << 8));
            outpw(0x3ce, 5 | (old5 << 8));
            _enable();
            if (fwrite(buffer, 1, 38400, out) != 38400) return 9;
        }
        if (fclose(out) != 0) return 10;
        if (direct) {
            _disable(); _fmemcpy(buffer,MK_FP(0xb800,0),32768); _enable();
            sprintf(name,"PAGE%02d.BIN",frame-1);
            out=fopen(name,"wb"); if (!out) return 19;
            if (fwrite(buffer,1,32768,out)!=32768) { fclose(out); return 20; }
            if (fclose(out)) return 20;
        }
        if (hostshot()) return 15;
    }
    if (ferror(in)) return 11;
    return fclose(in) != 0;
}

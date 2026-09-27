/* Raw observations of the production driver, not a second renderer. */
#include <dos.h>
#include <i86.h>
#include <conio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "hostshot.h"

static unsigned char buffer[4096];
static unsigned char state_crtc[2][128];
static void read_crtc(unsigned char *out)
{
    unsigned i,old=inp(0x3d4);
    for (i=0;i<128;++i) { outp(0x3d4,i); out[i]=inp(0x3d5); }
    outp(0x3d4,old);
}
static int query(unsigned ax,unsigned bx)
{
    union REGPACK r,records[3];
    FILE *out;
    memset(&r,0,sizeof(r)); r.x.ax=0x1412; intr(0x10,&r); records[0]=r;
    memset(&r,0,sizeof(r)); r.x.ax=ax; r.x.bx=bx; intr(0x10,&r); records[1]=r;
    memset(&r,0,sizeof(r)); r.x.ax=0x1412; intr(0x10,&r); records[2]=r;
    out=fopen("QUERY.BIN","wb"); if (!out) return 21;
    if (fwrite(records,1,sizeof(records),out)!=sizeof(records)) { fclose(out); return 22; }
    return fclose(out)!=0;
}
static void ticks(unsigned n)
{
    volatile unsigned long __far *clock=MK_FP(0x40,0x6c);
    unsigned long start=*clock;
    while ((unsigned long)(*clock-start)<n) {}
}

static int scroll_capture(FILE *out)
{
    union REGPACK r;
    unsigned plane,count;
    unsigned long offset,bytes;
    memset(&r,0,sizeof(r)); r.x.ax=0x1415; intr(0x10,&r);
    bytes=((unsigned long)r.x.di<<16)|r.x.si;
    _fmemcpy(buffer,MK_FP(0xb800,0),4000);
    if (fwrite(buffer,1,4000,out)!=4000) return 1;
    for (plane=0;plane<4;++plane) for (offset=0;offset<bytes;offset+=count) {
        count=bytes-offset<sizeof(buffer) ? (unsigned)(bytes-offset) : sizeof(buffer);
        memset(&r,0,sizeof(r)); r.x.ax=0x1414; r.x.bx=plane;
        r.x.dx=(unsigned)(offset>>16); r.x.si=(unsigned)offset;
        r.x.cx=count; r.x.es=FP_SEG(buffer); r.x.di=FP_OFF(buffer);
        intr(0x10,&r);
        if (r.x.ax || fwrite(buffer,1,count,out)!=count) return 1;
    }
    return 0;
}

/* Compare accelerated scanout against a forced glyph-by-glyph redraw of
 * exactly the same text. Includes overlap, clipping, pending direct writes,
 * split Chinese attributes, and the untouched IME strip. */
static int scrolling(void)
{
    static unsigned operations[][3]={
        {0x0601,0,0x184f}, {0x0703,0,0x184f},
        {0x0602,0x0300,0x144f}, {0x0701,0x0300,0x144f},
        {0x0601,0x0305,0x144a}, {0x0600,0,0x184f}
    };
    union REGPACK r;
    unsigned row,col,step;
    unsigned __far *text=MK_FP(0xb800,0);
    FILE *out=fopen("SCROLL.BIN","wb");
    if (!out) return 1;
    memset(&r,0,sizeof(r));r.x.ax=0x1700;intr(0x10,&r);
    for (step=0;step<sizeof(operations)/sizeof(operations[0]);++step) {
        _disable();
        for (row=0;row<25;++row) for (col=0;col<80;++col)
            text[row*80+col]=((row%14+1)<<8)|('A'+(row+col)%26);
        text[10*80+20]=0x1ed6; text[10*80+21]=0x4bd0;
        text[11*80+20]=0x2ece; text[11*80+21]=0x5fc4;
        _enable();
        memset(&r,0,sizeof(r));r.x.ax=0x1500;intr(0x10,&r);
        _disable();
        _fmemcpy(buffer,text,4000);
        ((unsigned *)buffer)[12*80+3]=0x7c5a;
        _enable();
        if (fwrite(buffer,1,4000,out)!=4000) return 2;
        _disable();
        text[12*80+3]=0x7c5a; /* Not yet visible when the scroll starts. */
        memset(&r,0,sizeof(r));r.x.ax=operations[step][0];r.x.bx=0x1e00;
        r.x.cx=operations[step][1];r.x.dx=operations[step][2];intr(0x10,&r);
        _enable();
        if (scroll_capture(out)) return 3;
        memset(&r,0,sizeof(r));r.x.ax=0x180c;r.x.bx=0x0300;intr(0x10,&r);
        if (scroll_capture(out)) return 4;
    }
    return fclose(out)!=0;
}

static int transition(const char *operation)
{
    union REGPACK r, result[4];
    FILE *f;
    unsigned size=0,i,palette[6];
    memset(result,0,sizeof(result));
    memset(&r,0,sizeof(r));
    if (!strncmp(operation,"state",5)) {
        unsigned flags=!strcmp(operation,"stateall") ? 15 : 7;
        read_crtc(state_crtc[0]);
        if (flags==15) {
            r.x.ax=0x1015; r.x.bx=1; intr(0x10,&r);
            palette[0]=r.h.dh; palette[1]=r.h.ch; palette[2]=r.h.cl;
            r.x.ax=0x1010; r.x.bx=1; r.x.dx=7<<8; r.x.cx=(15<<8)|23; intr(0x10,&r);
        }
        memset(&r,0,sizeof(r));
        r.x.ax=0x4f04; r.x.cx=flags; intr(0x10,&r); result[0]=r;
        if (r.x.ax==0x004f) {
            size=r.x.bx*64;
            if (!size || size>sizeof(buffer)-32) return 8;
            memset(buffer,0xa5,sizeof(buffer));
            r.x.ax=0x4f04; r.x.dx=1; r.x.es=FP_SEG(buffer); r.x.bx=FP_OFF(buffer)+16;
            intr(0x10,&r); result[1]=r;
            if (r.x.ax!=0x004f) return 9;
            r.x.ax=0x4f02; r.x.bx=0x101; intr(0x10,&r); result[2]=r;
            r.x.ax=0x4f04; r.x.cx=flags; r.x.dx=2; r.x.es=FP_SEG(buffer); r.x.bx=FP_OFF(buffer)+16;
            intr(0x10,&r); result[3]=r;
            read_crtc(state_crtc[1]);
            if (flags==15) {
                r.x.ax=0x1015; r.x.bx=1; intr(0x10,&r);
                palette[3]=r.h.dh; palette[4]=r.h.ch; palette[5]=r.h.cl;
                r.x.ax=0x1010; r.x.bx=1;
                r.x.dx=palette[0]<<8; r.x.cx=(palette[1]<<8)|palette[2]; intr(0x10,&r);
            }
        }
    } else {
        r.x.ax=0x4f02; r.x.bx=0x101; intr(0x10,&r); result[0]=r;
        r.x.ax=strcmp(operation,"text")==0 ? 0x4f02 : 3;
        r.x.bx=3; intr(0x10,&r); result[1]=r;
        r.x.ax=0x4f03; intr(0x10,&r); result[2]=r;
        r.x.ax=0x0f00; intr(0x10,&r); result[3]=r;
    }
    f=fopen("RETURN.BIN","wb");
    if (!f) return 10;
    fwrite(result,1,sizeof(result),f);
    if (size) fwrite(buffer,1,size+32,f);
    i=fclose(f)!=0;
    if (!strcmp(operation,"stateall")) {
        f=fopen("STATECRT.BIN","wb"); if (!f) return 10;
        fwrite(state_crtc,1,sizeof(state_crtc),f); i|=fclose(f)!=0;
        f=fopen("STATEPAL.BIN","wb"); if (!f) return 10;
        fwrite(palette,1,sizeof(palette),f); i|=fclose(f)!=0;
    }
    return i;
}

static int ports(void)
{
    unsigned char original[11], before[11], after[11];
    unsigned i;
    FILE *out;
    for (i=0;i<9;++i) { outp(0x3ce,i); original[i]=inp(0x3cf); }
    outp(0x3c4,2); original[9]=inp(0x3c5);
    before[0]=3; before[1]=0; before[2]=5; before[3]=0x18;
    before[4]=3; before[5]=0x08; before[6]=original[6]; before[7]=0x0a; before[8]=0x5a;
    before[9]=5; before[10]=7;
    for (i=0;i<9;++i) outpw(0x3ce,i | ((unsigned)before[i]<<8));
    outpw(0x3c4,2 | ((unsigned)before[9]<<8));
    outp(0x3ce,7); outp(0x3c4,2);
    ticks(24);
    after[10]=inp(0x3ce);
    for (i=0;i<9;++i) { outp(0x3ce,i); after[i]=inp(0x3cf); }
    outp(0x3c4,2); after[9]=inp(0x3c5);
    for (i=0;i<9;++i) outpw(0x3ce,i | ((unsigned)original[i]<<8));
    outpw(0x3c4,2 | ((unsigned)original[9]<<8));
    out=fopen("PORTS.BIN","wb");
    if (!out) return 11;
    fwrite(before,1,sizeof(before),out); fwrite(after,1,sizeof(after),out);
    return fclose(out)!=0;
}

static int drawing(void)
{
    static unsigned char wide[]={ 'A',0xd6,0xd0,'Z',0 };
    union REGPACK r;
    FILE *out;
    unsigned values[5],i;
    memset(&r,0,sizeof(r));
    r.x.ax=0x0100; r.x.cx=0x2000; intr(0x10,&r);
    for (i=0;i<64;++i) buffer[i]=(unsigned char)(i*3+7);
    r.x.ax=0x140a; r.x.bp=FP_SEG(buffer); r.x.si=FP_OFF(buffer); r.x.dx=0;
    r.x.bx=0x4b; intr(0x10,&r);
    r.x.ax=0x140f; r.x.es=FP_SEG(wide); r.x.si=FP_OFF(wide);
    r.x.dx=0x1946; r.x.bx=0x2e; intr(0x10,&r);
    r.x.ax=0x140f; r.x.es=FP_SEG(wide); r.x.si=FP_OFF(wide);
    r.x.dx=0x194f; r.x.bx=0x2e; intr(0x10,&r);
    r.x.ax=0x0c0e; r.x.cx=799; r.x.dx=599; intr(0x10,&r);
    r.x.ax=0x0d00; intr(0x10,&r); values[0]=r.h.al;
    r.x.ax=0x0c87; intr(0x10,&r);
    r.x.ax=0x0d00; intr(0x10,&r); values[1]=r.h.al;
    memset(buffer,0xa5,64);
    r.x.ax=0x1412; r.x.bx=0; r.x.si=59999; r.x.cx=2;
    r.x.es=FP_SEG(buffer); r.x.di=FP_OFF(buffer); intr(0x10,&r); values[2]=r.x.ax;
    r.x.ax=0x1412; r.x.si=0; r.x.cx=512; r.x.di=0xff00;
    intr(0x10,&r); values[3]=r.x.ax;
    r.x.ax=0x1412; r.x.bx=4; r.x.cx=1; r.x.di=FP_OFF(buffer);
    intr(0x10,&r); values[4]=r.x.ax;
    out=fopen("DRAW.BIN","wb");
    if (!out) return 13;
    fwrite(values,2,5,out); fwrite(buffer,1,64,out);
    return fclose(out)!=0;
}

static int resident(void)
{
    union REGPACK r;
    FILE *out;
    memset(&r,0,sizeof(r)); r.x.ax=0x1411; intr(0x10,&r);
    if (r.x.ax!=0x5356 || r.x.cx!=28) return 14;
    out=fopen("RESIDENT.BIN","wb");
    if (!out) return 15;
    fwrite(&r,1,sizeof(r),out);
    _fmemcpy(buffer,MK_FP(r.x.es,r.x.di),28); fwrite(buffer,1,28,out);
    _fmemcpy(buffer,MK_FP(r.x.es-1,0),16); fwrite(buffer,1,16,out);
    return fclose(out)!=0;
}

static int pages(void)
{
    static char text[]="BC";
    union REGPACK r;
    FILE *out;
    unsigned p,i,values[8],height,trace[24],stage;
    unsigned __far *v;
    memset(&r,0,sizeof(r)); r.x.ax=0x0100; r.x.cx=0x2000; intr(0x10,&r);
    r.x.ax=0x1406; intr(0x10,&r); height=r.x.cx>>8;
    _disable();
    for (p=0;p<8;++p) {
        v=MK_FP(0xb800+p*0x100,0);
        for (i=0;i<2000;++i) v[i]=0x2e20;
        v[0]=0x2e41+p;
    }
    v=MK_FP(0xbf00,0); v[5*80+20]=0x1ed6; v[5*80+21]=0x1ed0;
    _enable();
    stage=0;
    _disable();
    for (p=0;p<8;++p) trace[stage++]=*(unsigned __far *)MK_FP(0xb800+p*0x100,0);
    _enable();
    r.x.ax=0x0507; intr(0x10,&r); ticks(24);
    _disable();
    for (p=0;p<8;++p) trace[stage++]=*(unsigned __far *)MK_FP(0xb800+p*0x100,0);
    _enable();
    r.x.ax=0x0f00; intr(0x10,&r); values[0]=r.x.bx>>8;
    r.x.ax=0x1301; r.x.bx=0x032e; r.x.dx=0x184f; r.x.cx=2;
    r.x.es=FP_SEG(text); r.x.bp=FP_OFF(text); intr(0x10,&r);
    _disable();
    for (p=0;p<8;++p) trace[stage++]=*(unsigned __far *)MK_FP(0xb800+p*0x100,0);
    _enable();
    r.x.ax=0x0300; r.x.bx=0x0300; intr(0x10,&r); values[1]=r.x.dx;
    _disable();
    v=MK_FP(0xb800,0); values[2]=v[0];
    v=MK_FP(0xbf00,0); values[3]=v[0];
    v=MK_FP(0xbb00,0); values[4]=v[23*80+79]; values[5]=v[24*80];
    _enable();
    out=fopen("PAGES.BIN","wb"); if (!out) return 16;
    for (p=0;p<4;++p) {
        r.x.ax=0x1412; r.x.bx=p; r.x.si=5*height*100; r.x.cx=height*100;
        r.x.es=FP_SEG(buffer); r.x.di=FP_OFF(buffer); intr(0x10,&r);
        if (r.x.ax) return 17;
        fwrite(buffer,1,height*100,out);
    }
    r.x.ax=0x0500; intr(0x10,&r);
    r.x.ax=0x0f00; intr(0x10,&r); values[6]=r.x.bx>>8;
    r.x.ax=0x0800; r.x.bx=0; intr(0x10,&r); values[7]=r.x.ax;
    fwrite(values,2,8,out);
    fwrite(trace,2,24,out);
    return fclose(out)!=0;
}

static int fonts(void)
{
    union REGPACK r;
    FILE *out;
    unsigned pass,plane,y;
    memset(&r,0,sizeof(r)); r.x.ax=0x0100; r.x.cx=0x2000; intr(0x10,&r);
    out=fopen("FONT20.BIN","wb"); if (!out) return 18;
    r.x.ax=0x1413; intr(0x10,&r); fwrite(&r,1,sizeof(r),out);
    for (pass=0;pass<4;++pass) {
        if (!pass) {
            *(unsigned __far *)MK_FP(0xb800,24*160+78*2)=0x1eba;
            *(unsigned __far *)MK_FP(0xb800,24*160+79*2)=0x1eba; /* GB2312 Han */
            r.x.ax=0x180c; r.x.bx=0x0100; intr(0x10,&r);
            r.x.ax=0x1812; intr(0x10,&r); /* simplified bank */
        } else if (pass==1) {
            r.x.ax=0x1811; intr(0x10,&r); /* traditional bank */
        } else {
            r.x.ax=0x1408; r.x.dx=0x184f; intr(0x10,&r); /* XOR last cell */
        }
        for (plane=0;plane<4;++plane) {
            for (y=0;y<23;++y) {
                r.x.ax=0x1412; r.x.bx=plane; r.x.si=(24*23+y)*100;
                r.x.cx=100; r.x.es=FP_SEG(buffer); r.x.di=FP_OFF(buffer);
                intr(0x10,&r); if (r.x.ax) return 19;
                fwrite(buffer,1,100,out);
            }
        }
        if (hostshot()) return 20;
    }
    return fclose(out)!=0;
}
int main(int argc, char **argv)
{
    union REGPACK r;
    FILE *in, *out;
    unsigned plane, y, count, frame=0, pitch=100;
    unsigned char mode;
    char name[13];
    if (argc==4 && strcmp(argv[1],"query")==0)
        return query((unsigned)strtoul(argv[2],0,16),(unsigned)strtoul(argv[3],0,16));
    if (argc>1 && strcmp(argv[1],"fonts")==0) return fonts();
    if (argc>1 && strcmp(argv[1],"fallback")==0) {
        memset(&r,0,sizeof(r)); r.x.ax=0x1411; intr(0x10,&r);
        out=fopen("FALLBACK.BIN","wb"); if (!out) return 18;
        fwrite(&r,1,sizeof(r),out);
        count=r.x.ax==0x5356;
        r.x.ax=0x0f00; intr(0x10,&r); fwrite(&r,1,sizeof(r),out);
        if (fclose(out)) return 19;
        if (!count) return 0;
        if (resident()) return 20;
        argc=1; /* Exercise the same full pixel capture on the fallback. */
    }
    if (argc>1 && strcmp(argv[1],"info")==0) {
        memset(&r,0,sizeof(r)); r.x.ax=0x4f01; r.x.cx=0x102;
        r.x.es=FP_SEG(buffer); r.x.di=FP_OFF(buffer); intr(0x10,&r);
        out=fopen("MODE102.BIN","wb");
        if (!out) return 7;
        fwrite(&r,1,sizeof(r),out); fwrite(buffer,1,256,out);
        return fclose(out)!=0;
    }
    if (argc>1 && strcmp(argv[1],"ports")==0) return ports();
    if (argc>1 && strcmp(argv[1],"drawing")==0) return drawing();
    if (argc>1 && strcmp(argv[1],"resident")==0) return resident();
    if (argc>1 && strcmp(argv[1],"guard")==0) {
        unsigned offset;
        in=fopen("STACK.OFF","rb");if(!in) return 1;
        if(fread(&offset,2,1,in)!=1) {fclose(in);return 2;}
        fclose(in);
        memset(&r,0,sizeof(r));r.x.ax=0x1411;intr(0x10,&r);
        if(r.x.ax!=0x5356 || offset>r.x.si-2) return 3;
        if(*(unsigned __far *)MK_FP(r.x.es,offset)!=0xa55a) return 4;
        return 0;
    }
    if (argc>1 && strcmp(argv[1],"pages")==0) return pages();
    if (argc>1 && strcmp(argv[1],"scroll")==0) return scrolling();
    if (argc>1 && (!strcmp(argv[1],"screen") || !strcmp(argv[1],"rawscreen"))) {
        if (!strcmp(argv[1],"screen")) {
            memset(&r,0,sizeof(r));r.x.ax=0x1700;intr(0x10,&r);
            r.x.ax=0x1500;intr(0x10,&r);
        }
        out=fopen("SCREEN.BIN","wb");if(!out) return 1;
        if(scroll_capture(out)) {fclose(out);return 2;}
        if(fclose(out)) return 3;
        memset(&r,0,sizeof(r));r.x.ax=0x1009;
        r.x.es=FP_SEG(buffer);r.x.dx=FP_OFF(buffer);intr(0x10,&r);
        memset(&r,0,sizeof(r));r.x.ax=0x1017;r.x.cx=256;
        r.x.es=FP_SEG(buffer);r.x.dx=FP_OFF(buffer+17);intr(0x10,&r);
        out=fopen("PALETTE.BIN","wb");if(!out) return 4;
        if(fwrite(buffer,1,785,out)!=785) {fclose(out);return 5;}
        if(fclose(out)) return 6;
        return hostshot();
    }
    if (argc>1) return transition(argv[1]);
    memset(&r,0,sizeof(r)); r.x.ax=0xff00; intr(0x10,&r);
    if (r.x.ax!=0x56) return 1;
    r.x.ax=0x0100; r.x.cx=0x2000; intr(0x10,&r);
    in=fopen("INPUT.BIN","rb");
    if (!in) return 2;
    while (fread(&mode,1,1,in)==1) {
        if (fread(buffer,1,4000,in)!=4000) return 3;
        r.x.ax=0x180c; r.h.bh=mode; intr(0x10,&r);
        _disable(); _fmemcpy(MK_FP(0xb800,0),buffer,4000); _enable();
        ticks(24);
        sprintf(name,"VESA%02u.BIN",frame++);
        out=fopen(name,"wb");
        if (!out) return 4;
        r.x.ax=0x1406; intr(0x10,&r);
        if (fwrite("HHVESA1\n",1,8,out)!=8 || fwrite(&r,1,sizeof(r),out)!=sizeof(r)) return 5;
        _disable(); _fmemcpy(buffer,MK_FP(0xb800,0),4000); _enable();
        if (fwrite(buffer,1,4000,out)!=4000) return 5;
        for (plane=0; plane<4; ++plane) {
            for (y=0; y<600; y+=32) {
                count=(600-y<32 ? 600-y : 32)*pitch;
                r.x.ax=0x1412; r.x.bx=plane; r.x.si=y*pitch; r.x.cx=count;
                r.x.es=FP_SEG(buffer); r.x.di=FP_OFF(buffer); intr(0x10,&r);
                if (r.x.ax) return 12;
                if (fwrite(buffer,1,count,out)!=count) return 5;
            }
        }
        if (fclose(out)) return 6;
        if (hostshot()) return 20;
    }
    return fclose(in)!=0;
}

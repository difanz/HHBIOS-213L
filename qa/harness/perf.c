/* Guest-visible elapsed BIOS ticks, real console APIs and direct B800 writes. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static union REGPACK r;
static volatile unsigned long __far *clock=MK_FP(0x40,0x6c);
static void video(unsigned ax,unsigned bx,unsigned cx,unsigned dx)
{
    memset(&r,0,sizeof(r));r.x.ax=ax;r.x.bx=bx;r.x.cx=cx;r.x.dx=dx;intr(0x10,&r);
}
static void result(FILE *out,const char *name,unsigned long start)
{
    fprintf(out,"%s=%lu\n",name,(unsigned long)(*clock-start));fflush(out);
}
int main(void)
{
    FILE *out=fopen("PERF.TXT","w");
    unsigned i;
    unsigned long start;
    volatile unsigned __far *text=MK_FP(0xb800,0);
    if(!out) return 1;
    video(0x0200,0,0,0);
    start=*clock;
    for(i=0;i<32;++i) video(0x0e00+'A'+i%26,7,0,0);
    result(out,"ASCII_32",start);
    start=*clock;
    for(i=0;i<16;++i) {video(0x0ed6,7,0,0);video(0x0ed0,7,0,0);}
    result(out,"CHINESE_16",start);
    start=*clock;
    for(i=0;i<2000;++i) text[i]=0x1e00+'A'+i%26;
    video(0x1500,0,0,0); /* Explicit synchronization, includes actual drawing. */
    result(out,"DIRECT_2000",start);
    start=*clock;
    for(i=0;i<4;++i) video(0x0601,0x0700,0,0x184f);
    result(out,"SCROLL_4",start);
    start=*clock;
    for(i=0;i<256;++i) {
        memset(&r,0,sizeof(r));r.h.ah=2;r.h.dl='A'+i%26;intr(0x21,&r);
    }
    result(out,"DOS_256",start);
    start=*clock;
    for(i=0;i<100;++i) {
        memset(&r,0,sizeof(r));r.h.ah=1;intr(0x16,&r);
    }
    result(out,"KEY_POLL_100",start);
    return fclose(out)!=0;
}

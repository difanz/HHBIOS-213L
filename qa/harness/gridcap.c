/* Observe a real application's native text geometry while it is running.
 * No HHBIOS, no DOS calls from the timer, no writes to application video RAM.
 * GRID.BIN: BDA[256], followed by the visible character/attribute words.
 * The existing timer wrapper supplies DS; addressable state must be static.
 */
#include <dos.h>
#include <i86.h>
#include <conio.h>
#include <process.h>
#include <stdio.h>
#include <string.h>

static unsigned char capture[32768+256];
static unsigned cols,rows,size,age,settle,recorded,transmit,phase,exit_step;
static unsigned exits[8]={0x2d00},exit_count=1;
extern void install_app_tick(void);

void app_poll(void)
{
    unsigned x,j,offset;
    unsigned char __far *text;
    unsigned __far *bda=MK_FP(0x40,0);
    if (phase) {
        if (phase<3 && (inp(0x3fd)&0x20)) {
            outp(0x3f8,phase==1 ? transmit&255 : transmit>>8); ++phase;
        } else if (phase==3 && (inp(0x3fd)&1)) {
            if (inp(0x3f8)==0xa5) phase=0;
        }
        return;
    }
    if (recorded) {
        if (settle) { --settle; return; }
        if (exit_step<exit_count) {
            transmit=exits[exit_step++]; phase=1; settle=24;
        }
        return;
    }
    if (++age>=540) { recorded=2; return; }
    cols=bda[0x4a/2]; rows=*(unsigned char __far *)MK_FP(0x40,0x84)+1;
    offset=bda[0x4e/2];
    if (!cols || cols>255 || !rows || rows>255 ||
        (unsigned long)cols*rows*2UL+offset>32768UL) { settle=0; return; }
    size=cols*rows*2; text=MK_FP(0xb800,offset);
    if (!settle) {
        for (x=0;x+11<=cols*rows;++x) {
            for (j=0;j<11 && text[2*(x+j)]=="HHBIOS-GRID"[j];++j) {}
            if (j==11) { settle=1; break; }
        }
    } else if (++settle>=25) {
        _fmemcpy(capture,bda,256); _fmemcpy(capture+256,text,size);
        recorded=1; transmit=0xffff; phase=1; settle=24;
    }
}

int main(int argc,char **argv)
{
    void (__interrupt __far *old_tick)(void);
    FILE *out;
    int status;
    unsigned count;
    if (argc<2) return 1;
    out=fopen("EXITKEYS.BIN","rb");
    if (out) {
        count=fread(exits,1,sizeof(exits),out);
        if (!count || count%2 || fgetc(out)!=EOF || ferror(out)) { fclose(out); return 2; }
        exit_count=count/2; fclose(out);
    }
    outp(0x3fb,0x80); outp(0x3f8,12); outp(0x3f9,0);
    outp(0x3fb,3); outp(0x3fc,0x0b); outp(0x3f9,0);
    old_tick=_dos_getvect(0x1c); install_app_tick();
    status=spawnvp(P_WAIT,argv[1],(const char * const *)(argv+1));
    _dos_setvect(0x1c,old_tick);
    if (status!=0 || recorded!=1) return 3;
    out=fopen("GRID.BIN","wb"); if (!out) return 4;
    if (fwrite(capture,1,size+256,out)!=size+256) { fclose(out); return 5; }
    return fclose(out)!=0;
}

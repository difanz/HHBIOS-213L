/* Observe DOSSHELL without DOS calls in its timer interrupt. Screens and BIOS
 * requests are written only after the child exits. ACTIONS.BIN supplies physical
 * keys/mouse actions; FFFF also records BDA, the viewport and visible B800 text.
 */
#include <dos.h>
#include <i86.h>
#include <conio.h>
#include <process.h>
#include <stdio.h>
#include <string.h>

#define FRAMES 5
#define FRAME_SIZE (24+256+8000)
static unsigned char frames[FRAMES][FRAME_SIZE], after[256];
static unsigned actions[64],count,step,records,phase,transmit,age,settle,ready,vesa,failed;
/* INT 1C runs on the application's SS; pointers passed to C helpers use DS. */
static union REGPACK observation;
extern void install_app_tick(void);
extern void install_video_log(void);
extern unsigned video_count,video_log[256][4];

void app_poll(void)
{
    unsigned cols,rows,offset,x,j;
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
    if (failed || step==count) return;
    if (++age>18*90) { failed=1; return; }
    _disable();
    if (vesa) {
        memset(&observation,0,sizeof(observation)); observation.x.ax=0x1412; intr(0x10,&observation);
        if (observation.x.ax) return;
    }
    cols=bda[0x4a/2]; rows=*(unsigned char __far *)MK_FP(0x40,0x84)+1;
    offset=bda[0x4e/2];
    if (cols!=80 || !rows || rows>50 || (unsigned long)cols*rows*2+offset>32768UL) return;
    text=MK_FP(0xb800,offset);
    if (!ready) {
        for (x=0;x+11<=cols*rows;++x) {
            for (j=0;j<11 && text[2*(x+j)]=="HHBIOS-GRID"[j];++j) {}
            if (j==11) { ready=1; break; }
        }
        return;
    }
    if (++settle<25 || bda[0x1a/2]!=bda[0x1c/2]) return;
    settle=0; transmit=actions[step++];
    if (transmit==0xffff) {
        unsigned *meta;
        if (records==FRAMES) { failed=2; return; }
        meta=(unsigned *)frames[records];
        meta[0]=step-1; meta[1]=cols*rows*2;
        _fmemcpy(frames[records]+24,bda,256);
        _fmemcpy(frames[records]+280,text,meta[1]);
        if (vesa) {
            memset(&observation,0,sizeof(observation)); observation.x.ax=0x1411; intr(0x10,&observation);
            _fmemcpy(meta+2,MK_FP(observation.x.es,observation.x.di),10);
            observation.x.ax=0x1415; intr(0x10,&observation);
            meta[7]=observation.x.bx; meta[8]=observation.x.cx; meta[9]=observation.x.dx;
            observation.x.ax=0x1406; intr(0x10,&observation);
            meta[10]=observation.x.cx>>8; meta[11]=observation.x.bx>>8;
        }
        ++records;
    }
    phase=1;
}

static int write_file(char *name,void *data,unsigned size)
{
    FILE *file=fopen(name,"wb");
    int ok;
    if (!file) return 0;
    ok=fwrite(data,1,size,file)==size;
    return fclose(file)==0 && ok;
}

int main(int argc,char **argv)
{
    void (__interrupt __far *old_tick)(void),(__interrupt __far *old_video)(void);
    union REGPACK r;
    FILE *file;
    int status;
    if (argc<2) return 1;
    file=fopen("ACTIONS.BIN","rb"); if (!file) return 2;
    count=fread(actions,1,sizeof(actions),file);
    if (!count || count%2 || fgetc(file)!=EOF || ferror(file)) return 2;
    fclose(file); count/=2;
    memset(&r,0,sizeof(r)); r.x.ax=0x1411; intr(0x10,&r); vesa=r.x.ax==0x5356;
    outp(0x3fb,0x80); outp(0x3f8,12); outp(0x3f9,0);
    outp(0x3fb,3); outp(0x3fc,0x0b); outp(0x3f9,0);
    old_tick=_dos_getvect(0x1c); old_video=_dos_getvect(0x10);
    install_video_log(); install_app_tick();
    status=spawnvp(P_WAIT,argv[1],(const char * const *)(argv+1));
    _dos_setvect(0x1c,old_tick); _dos_setvect(0x10,old_video);
    _fmemcpy(after,MK_FP(0x40,0),256);
    if (!write_file("SHELL.BIN",frames,records*FRAME_SIZE) ||
        !write_file("AFTER.BIN",after,256) ||
        !write_file("VIDEO.BIN",video_log,video_count*8)) return 4;
    return status || failed || step!=count || !records ? 3 : 0;
}

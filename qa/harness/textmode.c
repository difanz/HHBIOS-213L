/* Observe native BIOS text modes, without installing HHBIOS.
 * VBELIST.BIN: 512-byte controller block, then {mode, AX, info[256]}.
 * TEXTMODE.BIN: "HHTEXT1\n", six words (request, set AX, AH=0F AX/BX,
 *              4F03 AX/BX), followed by the first 256 bytes of the BDA.
 * TEXT.BIN: visible character/attribute words after drawing the boundary.
 */
#include <dos.h>
#include <i86.h>
#include <conio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "hostshot.h"

static unsigned char controller[512], info[256], bda[256];

static unsigned word(const unsigned char *p) { return p[0] | ((unsigned)p[1]<<8); }

static int catalog(void)
{
    union REGPACK r;
    unsigned mode, result, count;
    unsigned long address;
    FILE *out;
    memset(&r, 0, sizeof(r));
    memcpy(controller, "VBE2", 4);
    r.x.ax=0x4f00; r.x.es=FP_SEG(controller); r.x.di=FP_OFF(controller);
    intr(0x10, &r);
    if (r.x.ax!=0x004f || memcmp(controller,"VESA",4)) return 2;
    address=(unsigned long)word(controller+16)*16UL+word(controller+14);
    out=fopen("VBELIST.BIN","wb");
    if (!out) return 3;
    if (fwrite(controller,1,sizeof(controller),out)!=sizeof(controller)) goto failed;
    for (count=0; count<512; ++count, address+=2) {
        if (address>0xffffeUL) goto failed;
        mode=*(unsigned __far *)MK_FP((unsigned)(address>>4),(unsigned)(address&15));
        if (mode==0xffff) return fclose(out)!=0;
        memset(info,0,sizeof(info)); memset(&r,0,sizeof(r));
        r.x.ax=0x4f01; r.x.cx=mode;
        r.x.es=FP_SEG(info); r.x.di=FP_OFF(info); intr(0x10,&r);
        result=r.x.ax;
        if (fwrite(&mode,2,1,out)!=1 || fwrite(&result,2,1,out)!=1 ||
            fwrite(info,1,sizeof(info),out)!=sizeof(info)) goto failed;
    }
failed:
    fclose(out); return 4;
}

static int select_mode(const char *name)
{
    union REGPACK r;
    unsigned values[6],cols,rows,x,y,offset;
    unsigned __far *screen;
    unsigned long start;
    char *end;
    FILE *out;
    values[0]=(unsigned)strtoul(name,&end,16);
    if (*end || (strcmp(name,"25") && strcmp(name,"43") && strcmp(name,"50") &&
                 (values[0]<0x108 || values[0]>0x10c))) return 5;
    memset(&r,0,sizeof(r));
    if (values[0]<0x100) {
        r.x.ax=values[0]==0x43 ? 0x1201 : 0x1202; r.x.bx=0x30; intr(0x10,&r);
        r.x.ax=3; intr(0x10,&r);
        if (values[0]!=0x25) { r.x.ax=0x1112; r.x.bx=0; intr(0x10,&r); }
        values[1]=0; /* legacy services have no VBE status */
    } else {
        r.x.ax=0x4f02; r.x.bx=values[0]; intr(0x10,&r); values[1]=r.x.ax;
    }
    r.x.ax=0x0f00; intr(0x10,&r); values[2]=r.x.ax; values[3]=r.x.bx;
    r.x.ax=0x4f03; intr(0x10,&r); values[4]=r.x.ax; values[5]=r.x.bx;
    _fmemcpy(bda,MK_FP(0x40,0),sizeof(bda));
    out=fopen("TEXTMODE.BIN","wb"); if (!out) return 6;
    if (fwrite("HHTEXT1\n",1,8,out)!=8 || fwrite(values,2,6,out)!=6 ||
        fwrite(bda,1,sizeof(bda),out)!=sizeof(bda)) { fclose(out); return 7; }
    if (fclose(out)) return 7;
    if (values[0]>=0x100 && values[1]!=0x004f) return 0; /* observed unsupported */
    cols=word(bda+0x4a); rows=(unsigned)bda[0x84]+1; offset=word(bda+0x4e);
    if (!cols || cols>255 || !rows || rows>255 ||
        (unsigned long)cols*rows*2UL+offset>32768UL) return 8;
    screen=MK_FP(0xb800,offset);
    for (y=0; y<rows; ++y) for (x=0; x<cols; ++x) {
        unsigned char ch=' ';
        if (!y || y==rows-1) ch=0xcd;
        else if (!x || x==cols-1) ch=0xba;
        else if (x==2) ch=(unsigned char)('0'+y/10);
        else if (x==3) ch=(unsigned char)('0'+y%10);
        else if (y==2) ch=(unsigned char)('0'+x%10);
        screen[y*cols+x]=0x1e00|ch;
    }
    screen[0]=0x1ec9; screen[cols-1]=0x1ebb;
    screen[(rows-1)*cols]=0x1ec8; screen[rows*cols-1]=0x1ebc;
    r.x.ax=0x0100; r.x.cx=0x2000; intr(0x10,&r);
    out=fopen("TEXT.BIN","wb"); if (!out) return 9;
    for (y=0; y<rows; ++y) {
        _fmemcpy(controller,screen+y*cols,cols*2);
        if (fwrite(controller,2,cols,out)!=cols) { fclose(out); return 10; }
    }
    if (fclose(out)) return 10;
    start=*(volatile unsigned long __far *)MK_FP(0x40,0x6c);
    while ((unsigned long)(*(volatile unsigned long __far *)MK_FP(0x40,0x6c)-start)<4) {}
    return hostshot();
}

int main(int argc, char **argv)
{
    return argc==1 ? catalog() : argc==2 ? select_mode(argv[1]) : 1;
}

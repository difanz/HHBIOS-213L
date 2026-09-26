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

/* Native mouse ranges and page isolation, without assuming BIOS consistency.
 * MOUSE.BIN: five REGPACKs (reset, default max, custom max, custom min, interior).
 * PAGES.BIN: cols,rows,stride,count; eight-word records per candidate page:
 * request,active,offset,stride,addressable,mismatches,first,last.
 */
static int audit(void)
{
    union REGPACK r,mouse[5];
    unsigned pages[8][8],cols=word(bda+0x4a),rows=(unsigned)bda[0x84]+1;
    unsigned stride=word(bda+0x4c),count,p,i,header[4];
    unsigned __far *text;
    FILE *out;
    memset(mouse,0,sizeof(mouse)); memset(&r,0,sizeof(r));
    intr(0x33,&r); mouse[0]=r;
    if (r.x.ax==0xffff) {
        r.x.ax=4; r.x.cx=0x7fff; r.x.dx=0x7fff; intr(0x33,&r);
        r.x.ax=3; intr(0x33,&r); mouse[1]=r;
        r.x.ax=7; r.x.cx=0; r.x.dx=cols*8-1; intr(0x33,&r);
        r.x.ax=8; r.x.cx=0; r.x.dx=rows*8-1; intr(0x33,&r);
        r.x.ax=4; r.x.cx=0x7fff; r.x.dx=0x7fff; intr(0x33,&r);
        r.x.ax=3; intr(0x33,&r); mouse[2]=r;
        r.x.ax=4; r.x.cx=0; r.x.dx=0; intr(0x33,&r);
        r.x.ax=3; intr(0x33,&r); mouse[3]=r;
        r.x.ax=4; r.x.cx=13; r.x.dx=21; intr(0x33,&r);
        r.x.ax=3; intr(0x33,&r); mouse[4]=r;
    }
    out=fopen("MOUSE.BIN","wb"); if (!out) return 11;
    if (fwrite(mouse,1,sizeof(mouse),out)!=sizeof(mouse)) { fclose(out); return 12; }
    if (fclose(out)) return 12;
    /* The last visible image can fit even when its trailing page padding
     * would not. Test each page start, then bound its actual visible extent. */
    count=stride ? 1+32767U/stride : 0; if (count>8) count=8;
    memset(pages,0,sizeof(pages));
    for (p=0;p<count;++p) {
        r.x.ax=0x0500|p; intr(0x10,&r);
        pages[p][0]=p; pages[p][1]=*(unsigned char __far *)MK_FP(0x40,0x62);
        pages[p][2]=*(unsigned __far *)MK_FP(0x40,0x4e);
        pages[p][3]=*(unsigned __far *)MK_FP(0x40,0x4c);
        if ((unsigned long)pages[p][2]+(unsigned long)cols*rows*2>32768UL) continue;
        pages[p][4]=1; text=MK_FP(0xb800,pages[p][2]);
        for (i=0;i<cols*rows;++i) text[i]=0x3041+p;
    }
    for (p=0;p<count;++p) if (pages[p][4]) {
        text=MK_FP(0xb800,pages[p][2]);
        for (i=0;i<cols*rows;++i) if (text[i]!=0x3041+p) ++pages[p][5];
        pages[p][6]=text[0]; pages[p][7]=text[cols*rows-1];
    }
    r.x.ax=0x0500; intr(0x10,&r);
    header[0]=cols; header[1]=rows; header[2]=stride; header[3]=count;
    out=fopen("PAGES.BIN","wb"); if (!out) return 13;
    if (fwrite(header,2,4,out)!=4 || fwrite(pages,16,count,out)!=count) { fclose(out); return 14; }
    return fclose(out)!=0;
}

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
    int status;
    if (argc==1) return catalog();
    if (argc!=2 && (argc!=3 || strcmp(argv[2],"audit"))) return 1;
    status=select_mode(argv[1]);
    if (status || argc==2) return status;
    if (!strcmp(argv[1],"25") || !strcmp(argv[1],"43") || !strcmp(argv[1],"50")) return audit();
    /* A rejected VBE mode leaves the previous mode intact; do not audit it
     * under the requested mode's name. Re-query before accessing text RAM. */
    {
        union REGPACK r;
        memset(&r,0,sizeof(r)); r.x.ax=0x4f03; intr(0x10,&r);
        if (r.x.ax!=0x004f || (r.x.bx&0x3fff)!=(unsigned)strtoul(argv[1],0,16)) return 0;
    }
    return audit();
}

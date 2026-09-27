/* Foreground VBE experiment, NOT a TSR or a virtual text BIOS.
 * Uses the production descriptor decoder; banked 4/8/16/32-bpp scanlines.
 * WIDE.IN: "HHWIDE1\n", width,height,cols,rows,scale,bpp (words),
 * 512 glyphs of 8x16, then (rows+1)*cols {glyph,attribute} word pairs.
 * The first 256 glyphs are replaced by the BIOS ROM 8x16 font before drawing.
 */
#define VESA_HOST
#include "../../src/vesa.c"
#include <dos.h>
#include <i86.h>
#include <conio.h>
#include <stdio.h>
#include <string.h>
#include "hostshot.h"

typedef char require_u32[sizeof(u32)==4 ? 1 : -1];
static u8 controller[512],info[256],glyphs[8192],line[16384];
static u16 cells[510],cfg[6],geometry[5],previous,bank=0xffff;
static u32 base,window_bytes,gran_bytes,stats[4];
static struct VbeSurface surface;
static u8 colors[16][4],dac[16][4],vga_dac[48];
static const u8 rgb[16][3]={
    {0,0,0},{0,0,170},{0,170,0},{0,170,170},{170,0,0},{170,0,170},
    {170,85,0},{170,170,170},{85,85,85},{85,85,255},{85,255,85},
    {85,255,255},{255,85,85},{255,85,255},{255,255,85},{255,255,255}};

static int discover(void)
{
    union REGPACK r;
    u32 address;
    u16 mode,n,version;
    memset(&r,0,sizeof(r)); memcpy(controller,"VBE2",4);
    r.x.ax=0x4f00; r.x.es=FP_SEG(controller); r.x.di=FP_OFF(controller); intr(0x10,&r);
    if (r.x.ax!=0x004f || memcmp(controller,"VESA",4)) return 0;
    version=word(controller+4);
    address=(u32)word(controller+16)*16+word(controller+14);
    for (n=0;n<512 && address<=0xffffeUL;++n,address+=2) {
        mode=*(u16 __far *)MK_FP((u16)(address>>4),(u16)(address&15));
        if (mode==0xffff) break;
        memset(info,0,sizeof(info)); memset(&r,0,sizeof(r));
        r.x.ax=0x4f01; r.x.cx=mode; r.x.es=FP_SEG(info); r.x.di=FP_OFF(info); intr(0x10,&r);
        if (r.x.ax!=0x004f || word(info+18)!=cfg[0] || word(info+20)!=cfg[1] || info[25]!=cfg[5]) continue;
        if (word(info)&0x40 || (cfg[5]==4 && word(info)&0x20)) continue;
        if (!DecodeVbeModeInfo(&surface,info,version,mode)) continue;
        if (surface.pitch>sizeof(line) || !(info[2+surface.window]&1)) continue;
        window_bytes=(u32)surface.window_kb*1024; gran_bytes=(u32)surface.granularity_kb*1024;
        return 1;
    }
    return 0;
}

/* Split every transfer, including a scanline or pixel crossing the window.
 * Offsets are per plane for planar graphics and per byte for packed graphics.
 */
static int transfer(u32 offset,u16 count,int reading)
{
    union REGPACK r;
    u16 part,done=0,next;
    u32 available,relative;
    while (count) {
        if (bank==0xffff || offset<base || offset-base>=window_bytes) {
            if (offset/gran_bytes>65535UL) return 0;
            next=(u16)(offset/gran_bytes);
            memset(&r,0,sizeof(r)); r.x.ax=0x4f05; r.x.bx=surface.window; r.x.dx=next;
            intr(0x10,&r); if (r.x.ax!=0x004f) return 0;
            bank=next; base=(u32)bank*gran_bytes; ++stats[reading];
        }
        relative=offset-base; available=window_bytes-relative;
        part=available<count ? (u16)available : count;
        if (reading) _fmemcpy(line+done,MK_FP(surface.segment,(u16)relative),part);
        else _fmemcpy(MK_FP(surface.segment,(u16)relative),line+done,part);
        count-=part; done+=part; offset+=part;
        if (count && !reading) ++stats[2];
    }
    return 1;
}

static int palette(void)
{
    union REGPACK r;
    u16 i,j;
    u32 value;
    for (i=0;i<16;++i) {
        value=0;
        for (j=0;j<3;++j) {
            u8 size=j==0 ? surface.red_size : j==1 ? surface.green_size : surface.blue_size;
            u8 pos=j==0 ? surface.red_pos : j==1 ? surface.green_pos : surface.blue_pos;
            if (size) value|=((u32)rgb[i][j]*((1U<<size)-1)+127)/255 << pos;
            vga_dac[3*i+j]=rgb[i][j]/4; dac[i][2-j]=rgb[i][j]/4;
        }
        if (cfg[5]==8) value=i;
        for (j=0;j<4;++j) colors[i][j]=(u8)(value>>(8*j));
    }
    if (cfg[5]>8) return 1;
    memset(&r,0,sizeof(r)); r.x.ax=0x4f09; r.x.cx=16;
    r.x.es=FP_SEG(dac); r.x.di=FP_OFF(dac); intr(0x10,&r);
    if (r.x.ax!=0x004f) {
        if (word(info)&0x20) return 0; /* no VGA ports on non-VGA hardware */
        r.x.ax=0x1012; r.x.bx=0; r.x.cx=16;
        r.x.es=FP_SEG(vga_dac); r.x.dx=FP_OFF(vga_dac); intr(0x10,&r);
    }
    if (cfg[5]==4) for (i=0;i<16;++i) {
        r.x.ax=0x1000; r.x.bx=(i<<8)|i; intr(0x10,&r);
    }
    return 1;
}

static int render(FILE *input)
{
    u16 plane,y,last,row,col,sy,x,b,k,color,height=cfg[1];
    u16 bytes=(cfg[5]+7)/8,cols=cfg[2],rows=cfg[3],scale=cfg[4];
    u16 ox=geometry[3],oy=geometry[4],used_height=(rows+1)*16*scale;
    u32 start=*(volatile u32 __far *)MK_FP(0x40,0x6c);
    for (plane=0;plane<(cfg[5]==4 ? 4 : 1);++plane) {
        if (cfg[5]==4) {
            outpw(0x3c4,2|((1U<<plane)<<8)); outpw(0x3ce,1);
            outpw(0x3ce,3); outpw(0x3ce,5); outpw(0x3ce,0xff08);
        }
        last=0xffff;
        for (y=0;y<height;++y) {
            memset(line,0,surface.pitch);
            if (y>=oy && y-oy<used_height) {
                row=(y-oy)/(16*scale); sy=((y-oy)/scale)%16;
                if (row!=last) {
                    if (fseek(input,20L+8192L+(u32)row*cols*4,SEEK_SET) || fread(cells,4,cols,input)!=cols) return 0;
                    for (col=0;col<cols;++col) if (cells[col*2]>=512 || cells[col*2+1]>255) return 0;
                    last=row;
                }
                x=ox;
                for (col=0;col<cols;++col) for (b=0;b<8;++b) {
                    color=(glyphs[cells[2*col]*16+sy]&(128>>b)) ? cells[2*col+1]&15 : cells[2*col+1]>>4;
                    for (k=0;k<scale;++k,++x) {
                        if (cfg[5]==4) {
                            if (color&(1U<<plane)) line[x/8]|=128>>(x%8);
                        } else memcpy(line+x*bytes,colors[color],bytes);
                    }
                }
            }
            if (!transfer((u32)y*surface.pitch,surface.pitch,0)) return 0;
        }
    }
    stats[3]=*(volatile u32 __far *)MK_FP(0x40,0x6c)-start;
    return 1;
}

static int capture(void)
{
    u16 plane,y;
    FILE *out=fopen("FRAME.BIN","wb");
    if (!out) return 0;
    for (plane=0;plane<(cfg[5]==4 ? 4 : 1);++plane) {
        if (cfg[5]==4) outpw(0x3ce,4|(plane<<8));
        for (y=0;y<surface.height;++y) {
            if (!transfer((u32)y*surface.pitch,surface.pitch,1) ||
                fwrite(line,1,surface.pitch,out)!=surface.pitch) { fclose(out); return 0; }
        }
    }
    return fclose(out)==0;
}

static int experiment(void)
{
    FILE *in,*out;
    union REGPACK r;
    char signature[8];
    u32 used_width,used_height;
    int result=1;
    in=fopen("WIDE.IN","rb"); if (!in) return 1;
    if (fread(signature,1,8,in)!=8 || memcmp(signature,"HHWIDE1\n",8) ||
        fread(cfg,2,6,in)!=6 || fread(glyphs,1,sizeof(glyphs),in)!=sizeof(glyphs)) goto close;
    if (!cfg[0] || cfg[0]>4096 || !cfg[1] || cfg[1]>4096 ||
        !cfg[2] || cfg[2]>255 || !cfg[3] || cfg[3]>255 || !cfg[4] || cfg[4]>4 ||
        (cfg[5]!=4 && cfg[5]!=8 && cfg[5]!=16 && cfg[5]!=32)) goto close;
    used_width=(u32)cfg[2]*8*cfg[4]; used_height=((u32)cfg[3]+1)*16*cfg[4];
    if (used_width>cfg[0] || used_height>cfg[1] || (u32)cfg[2]*cfg[3]*2>32768UL) goto close;
    geometry[0]=cfg[2]; geometry[1]=cfg[3]; geometry[2]=cfg[4];
    geometry[3]=(cfg[0]-(u16)used_width)/2; geometry[4]=(cfg[1]-(u16)used_height)/2;
    if (!discover()) { result=77; goto close; }
    memset(&r,0,sizeof(r)); r.x.ax=0x1130; r.x.bx=0x0600; intr(0x10,&r);
    _fmemcpy(glyphs,MK_FP(r.x.es,r.x.bp),4096);
    out=fopen("FONT16.BIN","wb"); if (!out) goto close;
    result=fwrite(glyphs,1,sizeof(glyphs),out)==sizeof(glyphs) ? 0 : 1;
    if (fclose(out)) result=1;
    if (result) goto close;
    r.x.ax=0x0f00; intr(0x10,&r); previous=r.x.ax&127;
    /* AH=0F reports only a legacy byte and can alias an unrelated mode.
     * Keep the full VBE mode and LFB flag when the current-mode query works. */
    r.x.ax=0x4f03; intr(0x10,&r);
    if (r.x.ax==0x004f) previous=r.x.bx&0x7fff;
    r.x.ax=0x4f02; r.x.bx=surface.mode; intr(0x10,&r);
    result=r.x.ax!=0x004f;
    if (!result) result=!palette() || !render(in) || !capture() || hostshot();
    memset(&r,0,sizeof(r));
    if (previous>=0x100) { r.x.ax=0x4f02; r.x.bx=previous; }
    else r.x.ax=previous;
    intr(0x10,&r);
    if (previous>=0x100 && r.x.ax!=0x004f) result=1;
    if (!result) {
        out=fopen("RESULT.BIN","wb");
        if (!out) { result=1; goto close; }
        result=fwrite("HHWIDE1\n",1,8,out)!=8 || fwrite(&surface,1,sizeof(surface),out)!=sizeof(surface) ||
               fwrite(geometry,2,5,out)!=5 || fwrite(stats,4,4,out)!=4;
        if (fclose(out)) result=1;
    }
close:
    fclose(in); return result;
}

int main(void)
{
    int result=experiment();
    FILE *out=fopen("STATUS.BIN","wb");
    if (!out) return 2;
    if (fwrite(&result,2,1,out)!=1) { fclose(out); return 2; }
    if (fclose(out)) return 2;
    return result;
}

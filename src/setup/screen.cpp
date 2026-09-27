/* Standalone 8086 VGA backend. Turbo Vision still owns layout, focus,
 * dialogs and events; only its final character buffer is rasterized here.
 * No hooks, TSR, XMS, EMS or protected mode. HZK16 is normal process memory. */
#define Uses_TScreen
#define Uses_TEvent
#define Uses_TEventQueue
#include <tvision/tv.h>
#include <dos.h>
#include <string.h>
#include <stdio.h>
#include <alloc.h>
#include "screen.h"

static ushort far cells[80*30], previous[80*30];
static short far previous_glyph[80*30];
static unsigned char far latin[256*16];
static int active, mouse_present;
static unsigned old_mode, mouse_buttons, mouse_x, mouse_y;
static unsigned last_down, repeat_at;
static ushort *old_buffer;
static unsigned char far *font_blocks[8];
/* CP437 frames and GB2312 share byte values. Encode Chinese UI characters
 * into unused Western slots before giving strings to Turbo Vision. Each Han
 * still occupies exactly two cells. Frame bytes B0..DF are never ambiguous.
 * This maps character codes, not font subsets; all HZK16 glyphs are loaded. */
static unsigned far han_codes[4096];
static unsigned han_count;
static char far text_pool[16384];
static unsigned text_used, text_count;
static const char *source_text[128], *encoded_text[128];

const char *screen_text(const char *text)
{
    unsigned i,code,slot;
    const unsigned char *p=(const unsigned char *)text;
    char *out,*start;
    for(i=0;i<text_count;++i) if(source_text[i]==text) return encoded_text[i];
    if(text_count==128 || strlen(text)+text_used+1>sizeof(text_pool)) return "Text buffer full";
    out=start=text_pool+text_used;
    while(*p) {
        if(p[0]>=0xa1 && p[0]<=0xf7 && p[1]>=0xa1 && p[1]<=0xfe) {
            code=(p[0]<<8)|p[1];
            for(slot=0;slot<han_count && han_codes[slot]!=code;++slot) {}
            if(slot==han_count) {
                if(han_count==4096) return "Character map full";
                han_codes[han_count++]=code;
            }
            *out++=(char)(0x80+slot/94); *out++=(char)(0xa1+slot%94);p+=2;
        } else *out++=*p++;
    }
    *out++=0; text_used=(unsigned)(out-text_pool);
    source_text[text_count]=text;encoded_text[text_count++]=start;
    return start;
}

static void free_font()
{
    for(unsigned i=0;i<8;++i) if(font_blocks[i]) {farfree(font_blocks[i]);font_blocks[i]=0;}
}

static int load_font()
{
    FILE *fp=fopen("HZK16","rb");
    if(!fp) return 0;
    for(unsigned i=0;i<8;++i) {
        unsigned n=i==7 ? 32320U : 32768U;
        font_blocks[i]=(unsigned char far *)farmalloc(n);
        if(!font_blocks[i] || fread(font_blocks[i],1,n,fp)!=n) {
            fclose(fp);free_font();return 0;
        }
    }
    fclose(fp);return 1;
}

static void mouse(unsigned ax, unsigned cx=0, unsigned dx=0)
{
    union REGS r;
    memset(&r,0,sizeof(r)); r.x.ax=ax;r.x.cx=cx;r.x.dx=dx;
    int86(0x33,&r,&r);
}

int screen_start()
{
    union REGS r;
    struct REGPACK font;
    if(!load_font()) return 0;
    memset(&font,0,sizeof(font)); font.r_ax=0x1130; font.r_bx=0x0600;
    intr(0x10,&font);
    _fmemcpy(latin,MK_FP(font.r_es,font.r_bp),sizeof(latin));
    old_mode=TScreen::screenMode;
    old_buffer=TScreen::screenBuffer;
    TEventQueue::suspend();
    memset(&r,0,sizeof(r)); r.x.ax=0x12; int86(0x10,&r,&r);
    r.h.ah=0x0f; int86(0x10,&r,&r);
    if ((r.h.al & 0x7f)!=0x12) {
        r.x.ax=old_mode & 255; int86(0x10,&r,&r); TEventQueue::resume(); free_font();return 0;
    }
    memset(cells,0,sizeof(cells)); memset(previous,0xff,sizeof(previous));
    memset(previous_glyph,0xff,sizeof(previous_glyph));
    TScreen::screenBuffer=cells;
    TScreen::screenWidth=80; TScreen::screenHeight=30;
    TScreen::checkSnow=False;
    active=1;
    r.x.ax=0; int86(0x33,&r,&r); mouse_present=r.x.ax==0xffff;
    if(mouse_present) { mouse(7,0,639);mouse(8,0,479);mouse(1); }
    return 1;
}

int screen_active() { return active; }

static int glyph(unsigned code)
{
    unsigned hi=code>>8,lo=code&255,slot;
    if(hi<0x80 || hi>=0xb0 || lo<0xa1 || lo>0xfe) return -1;
    slot=(hi-0x80)*94+lo-0xa1;
    return slot<han_count ? (int)slot : -1;
}

static void cell(unsigned index,int han,unsigned half)
{
    unsigned row=index/80,col=index%80,attr=cells[index]>>8;
    unsigned ch=cells[index]&255,p,y;
    unsigned long offset=0;
    unsigned char far *bits16=0;
    if(han>=0) {
        unsigned code=han_codes[han];
        offset=((unsigned long)((code>>8)-0xa1)*94+(code&255)-0xa1)*32;
        bits16=font_blocks[(unsigned)(offset>>15)]+(unsigned)(offset&32767);
    }
    unsigned char far *vram=(unsigned char far *)MK_FP(0xa000,row*1280+col);
    for(p=0;p<4;++p) {
        outport(0x3c4,2|((1U<<p)<<8));
        for(y=0;y<16;++y) {
            unsigned char bits=han<0 ? latin[ch*16+y] :
                bits16[y*2+half];
            unsigned char ink=(attr & (1U<<p)) ? bits:0;
            if(attr & (16U<<p)) ink|=(unsigned char)~bits;
            vram[y*80]=ink;
        }
    }
}

void screen_paint()
{
    unsigned i;
    int dirty=0;
    if(!active) return;
    for(i=0;i<80*30;++i) if(cells[i]!=previous[i]) {dirty=1;break;}
    if(!dirty) return;
    if(mouse_present) mouse(2);
    /* Mouse drivers may change VGA registers; establish all write-mode inputs. */
    outport(0x3ce,0x0001); /* disable set/reset */
    outport(0x3ce,0x0003); /* rotate=0, replace */
    outport(0x3ce,0x0005); /* write mode 0 */
    outport(0x3ce,0xff08); /* full bit mask */
    for(i=0;i<80*30;++i) {
        int han=-1;
        if(i%80!=79) han=glyph(((cells[i]&255)<<8)|(cells[i+1]&255));
        if(han>=0) {
            if(cells[i]!=previous[i] || cells[i+1]!=previous[i+1] ||
               previous_glyph[i]!=han*2 || previous_glyph[i+1]!=han*2+1) {
                cell(i,han,0);cell(i+1,han,1);
                previous[i]=cells[i];previous[i+1]=cells[i+1];
                previous_glyph[i]=han*2;previous_glyph[i+1]=han*2+1;
            }
            ++i;
        } else if(cells[i]!=previous[i] || previous_glyph[i]!=-1) {
            cell(i,-1,0);previous[i]=cells[i];previous_glyph[i]=-1;
        }
    }
    outport(0x3c4,0x0f02);
    if(mouse_present) mouse(1);
}

void screen_mouse(TEvent &event)
{
    union REGS r;
    unsigned x,y,buttons,ticks;
    if(!active || !mouse_present) return;
    memset(&r,0,sizeof(r));r.x.ax=3;int86(0x33,&r,&r);
    x=r.x.cx/8;y=r.x.dx/16;buttons=r.x.bx & 3;
    ticks=*(unsigned far *)MK_FP(0x40,0x6c);
    event.mouse.eventFlags=0;
    if(buttons && !mouse_buttons) {
        event.what=evMouseDown;
        if(x==mouse_x && y==mouse_y && (unsigned)(ticks-last_down)<8)
            event.mouse.eventFlags=meDoubleClick;
        last_down=ticks; repeat_at=ticks+8;
    } else if(!buttons && mouse_buttons) event.what=evMouseUp;
    else if(x!=mouse_x || y!=mouse_y) event.what=evMouseMove;
    else if(buttons && (int)(ticks-repeat_at)>=0) {event.what=evMouseAuto;repeat_at=ticks+1;}
    else return;
    event.mouse.where.x=x;event.mouse.where.y=y;event.mouse.buttons=buttons;
    mouse_x=x;mouse_y=y;mouse_buttons=buttons;
}

void screen_stop()
{
    union REGS r;
    if(!active) return;
    if(mouse_present) mouse(2);
    memset(&r,0,sizeof(r));r.x.ax=old_mode & 255;int86(0x10,&r,&r);
    TScreen::screenBuffer=old_buffer; TScreen::setCrtData();
    active=0;free_font();
}

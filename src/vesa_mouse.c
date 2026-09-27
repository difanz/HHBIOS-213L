/* The mouse driver owns hardware, mickeys, buttons and event timing. HHBIOS
 * owns text coordinates and the software text cursor. No B800 cursor writes. */
#include "vesa.h"

extern u32 CALL old33;
extern u16 CALL mouse_thunk_offset;
u32 CALL mouse_target;
u8 CALL mouse_native;
static u16 event_mask, mouse_page, screen_mask=0xffff, cursor_mask=0x7700;
static u16 min_x,min_y,max_x=639,max_y=199,mouse_x,mouse_y,drawn=0xffff;
static int visibility=-1;
static u8 present, attached;
static u16 cursor_type, cursor_first, cursor_last;
static u16 excluded, exclude_left, exclude_top, exclude_right, exclude_bottom;

static u16 ss_segment(void);
#pragma aux ss_segment = "mov ax,ss" value [ax];
#define STACK(p) PTR(struct registers,ss_segment(),(u16)(p))
void CALL mouse_bios(struct registers FAR *r);

/* Native mode-dependent operations must see the physical mode, including
 * nested BIOS queries. Suppress translated callbacks during this operation. */
static void physical_call(struct registers FAR *r)
{
    u8 old=*PTR(u8,0x40,0x49);
    mouse_native=1;
    *PTR(u8,0x40,0x49)=hardware_mode;
    mouse_bios(r);
    *PTR(u8,0x40,0x49)=old;
    mouse_native=0;
}

static void clear(struct registers FAR *r)
{
    u16 i;
    for (i=0;i<sizeof(*r);++i) ((u8 FAR *)r)[i]=0;
}
static u16 bounded(u16 v,u16 low,u16 high)
{
    if ((short)v<(short)low) return low;
    return v>high ? high : v;
}
static u16 logical(u16 v,u16 origin,u16 cell,u16 low,u16 high)
{
    u16 result=v<=origin ? 0 : (v-origin)*8/cell;
    return bounded(result,low,high)&~7U;
}
static void coordinates(struct registers FAR *r)
{
    r->cx=logical(r->cx,viewport_x,CELL_WIDTH*pixel_scale,min_x,max_x);
    r->dx=logical(r->dx,viewport_y,raster_height*pixel_scale,min_y,max_y);
}
static void raw_limits(void)
{
    struct registers r;
    struct registers FAR *p=STACK(&r);
    /* Absolute-input drivers normalize against their configured maximum.
     * Keep that range equal to the whole physical surface; logical limits
     * are applied after translation, including margins and custom ranges. */
    clear(p); p->ax=7; p->cx=0; p->dx=screen.width-1; mouse_bios(p);
    p->ax=8; p->cx=0; p->dx=screen.height-1; mouse_bios(p);
}
static void hook(void)
{
    struct registers r;
    struct registers FAR *p=STACK(&r);
    clear(p); p->ax=0x0c; p->cx=0x7f;
    p->es=resident_segment; p->dx=mouse_thunk_offset; mouse_bios(p);
}
static void state(struct registers FAR *r)
{
    struct registers size;
    struct registers FAR *p=STACK(&size);
    u8 FAR *record;
    u16 i,bytes,fn=r->ax;
    clear(p); p->ax=0x15; mouse_bios(p); bytes=p->bx;
    if (!bytes || bytes>65471U) { if (fn==0x15) r->bx=0; return; }
    if (fn==0x15) { r->bx=bytes+64; return; }
    if (r->dx>65535U-bytes-64) return;
    record=PTR(u8,r->es,r->dx+bytes);
    if (fn==0x17 && (record[0]!='H' || record[1]!='M' || record[2]!='M' || record[3]!=1)) return;
    mouse_bios(r);
    if (fn==0x16) {
        for (i=0;i<64;++i) record[i]=0;
        record[0]='H'; record[1]='M'; record[2]='M'; record[3]=1;
        *(u16 FAR *)(record+4)=(u16)visibility;
        *(u16 FAR *)(record+6)=event_mask; *(u32 FAR *)(record+8)=mouse_target;
        *(u16 FAR *)(record+12)=mouse_page;
        *(u16 FAR *)(record+14)=screen_mask; *(u16 FAR *)(record+16)=cursor_mask;
        *(u16 FAR *)(record+18)=min_x; *(u16 FAR *)(record+20)=max_x;
        *(u16 FAR *)(record+22)=min_y; *(u16 FAR *)(record+24)=max_y;
        *(u16 FAR *)(record+26)=cursor_type;
        *(u16 FAR *)(record+28)=cursor_first; *(u16 FAR *)(record+30)=cursor_last;
        *(u16 FAR *)(record+32)=excluded;
        *(u16 FAR *)(record+34)=exclude_left; *(u16 FAR *)(record+36)=exclude_top;
        *(u16 FAR *)(record+38)=exclude_right; *(u16 FAR *)(record+40)=exclude_bottom;
    } else {
        visibility=(short)*(u16 FAR *)(record+4);
        event_mask=*(u16 FAR *)(record+6); mouse_target=*(u32 FAR *)(record+8);
        mouse_page=*(u16 FAR *)(record+12);
        screen_mask=*(u16 FAR *)(record+14); cursor_mask=*(u16 FAR *)(record+16);
        min_x=bounded(*(u16 FAR *)(record+18),0,639);
        max_x=bounded(*(u16 FAR *)(record+20),min_x,639);
        min_y=bounded(*(u16 FAR *)(record+22),0,text_rows*8-1);
        max_y=bounded(*(u16 FAR *)(record+24),min_y,text_rows*8-1);
        cursor_type=*(u16 FAR *)(record+26);
        cursor_first=*(u16 FAR *)(record+28); cursor_last=*(u16 FAR *)(record+30);
        excluded=*(u16 FAR *)(record+32);
        exclude_left=*(u16 FAR *)(record+34); exclude_top=*(u16 FAR *)(record+36);
        exclude_right=*(u16 FAR *)(record+38); exclude_bottom=*(u16 FAR *)(record+40);
        raw_limits(); hook();
    }
}
void CALL mouse_resume(void)
{
    struct registers r;
    struct registers FAR *p=STACK(&r);
    if (!old33) return;
    clear(p); p->ax=0x14; mouse_bios(p);
    if (!attached) { event_mask=p->cx; mouse_target=((u32)p->es<<16)|p->dx; }
    clear(p); physical_call(p); present=p->ax==0xffff;
    if (!present) return;
    attached=1; min_x=min_y=0; max_x=639; max_y=text_rows*8-1;
    mouse_page=0; drawn=0xffff;
    raw_limits(); hook();
}
void CALL mouse_suspend(void)
{
    struct registers r;
    struct registers FAR *p=STACK(&r);
    if (!attached || !present) return;
    clear(p); p->ax=0x0c; p->cx=event_mask;
    p->es=(u16)(mouse_target>>16); p->dx=(u16)mouse_target; mouse_bios(p);
    if (visibility>=0) { p->ax=1; physical_call(p); }
    attached=0;
}

void CALL mouse_dispatch(struct registers FAR *r)
{
    u16 fn=r->ax,mask;
    u32 target;
    if (!old33) { if (!fn || fn==0x21) r->ax=0; return; }
    if (!active || !attached) { mouse_bios(r); return; }
    switch (fn) {
    case 0: case 0x21:
        physical_call(r); present=r->ax==0xffff;
        visibility=-1; event_mask=0; mouse_target=0;
        min_x=min_y=mouse_page=0; max_x=639; max_y=text_rows*8-1;
        screen_mask=0xffff; cursor_mask=0x7700;
        cursor_type=excluded=0;
        if (present) { raw_limits(); hook(); }
        break;
    case 1: if (visibility<0) ++visibility; excluded=0; break;
    case 2: if (visibility>-32767) --visibility; break;
    case 3: case 5: case 6:
        mouse_bios(r); coordinates(r); break;
    case 4: {
        u16 x=r->cx,y=r->dx;
        /* Native text drivers may quantize physical positions to eight
         * pixels. The last pixel inside the requested cell survives that
         * quantization without falling into the preceding logical cell. */
        r->cx=viewport_x+((bounded(x,min_x,max_x)&~7U)+8)*CELL_WIDTH*pixel_scale/8-1;
        r->dx=viewport_y+((bounded(y,min_y,max_y)&~7U)+8)*raster_height*pixel_scale/8-1;
        mouse_bios(r); r->cx=x; r->dx=y; break;
    }
    case 7:
        min_x=bounded(r->cx,0,639); max_x=bounded(r->dx,min_x,639); raw_limits(); break;
    case 8:
        min_y=bounded(r->cx,0,text_rows*8-1); max_y=bounded(r->dx,min_y,text_rows*8-1); raw_limits(); break;
    case 10:
        if (r->bx<=1) {
            cursor_type=r->bx;
            if (!r->bx) { screen_mask=r->cx; cursor_mask=r->dx; }
            else { cursor_first=r->cx; cursor_last=r->dx; }
        }
        break;
    case 12: case 20:
        mask=event_mask; target=mouse_target;
        event_mask=r->cx; mouse_target=((u32)r->es<<16)|r->dx;
        if (fn==20) { r->cx=mask; r->es=(u16)(target>>16); r->dx=(u16)target; }
        break;
    case 0x15: case 0x16: case 0x17: state(r); break;
    case 0x10:
        excluded=1; exclude_left=r->cx; exclude_top=r->dx;
        exclude_right=r->si; exclude_bottom=r->di; break;
    case 0x1d: if (r->bx<page_count) mouse_page=r->bx; break;
    case 0x1e: r->bx=mouse_page; break;
    case 0x26: r->bx=0; r->cx=639; r->dx=text_rows*8-1; break;
    default: mouse_bios(r); break;
    }
}

u16 CALL mouse_event(struct registers FAR *r)
{
    if (mouse_native) return 0;
    if (active && attached) coordinates(r);
    return mouse_target && (r->ax & event_mask);
}

u16 CALL mouse_erase(void)
{
    if (drawn!=0xffff) {
        u16 i=(drawn>>8)*80+(drawn&255);
        shadow[i]=~*PTR(u16,0xb800,active_page*page_bytes+i*2);
        drawn=0xffff;
        return 1;
    }
    return 0;
}
void CALL mouse_poll(void)
{
    struct registers r;
    struct registers FAR *p=STACK(&r);
    if (!present || !attached) return;
    clear(p); p->ax=3; mouse_bios(p); coordinates(p);
    mouse_x=p->cx/8; mouse_y=p->dx/8;
}
u16 CALL mouse_covers(u16 pos)
{
    return present && attached && visibility>=0 && mouse_page==active_page &&
        !(excluded && (short)(mouse_x*8+7)>=(short)exclude_left &&
            (short)(mouse_x*8)<=(short)exclude_right &&
            (short)(mouse_y*8+7)>=(short)exclude_top &&
            (short)(mouse_y*8)<=(short)exclude_bottom) &&
        pos==((mouse_y<<8)|mouse_x);
}
void CALL mouse_paint(void)
{
    /* Only the serialized renderer calls this; callbacks never draw. */
    static struct registers r;
    static u16 bits[CELL_HEIGHT*2];
    u16 value, changed, code,half=0,i;
    u16 FAR *text;
    if (!active || !mouse_covers((mouse_y<<8)|mouse_x) || mouse_y>=text_rows || mouse_x>=80) return;
    r.dx=(mouse_y<<8)|mouse_x; boundary(&r);
    text=PTR(u16,0xb800,active_page*page_bytes); i=mouse_y*80+mouse_x;
    value=text[i]; changed=cursor_type ? value : (value & screen_mask)^cursor_mask; code=changed&255;
    if ((changed&255)==(value&255)) {
        if (r.ax==1 && mouse_x<79) code=((value&255)<<8)|(text[i+1]&255);
        else if (r.ax==2 && mouse_x) { code=((text[i-1]&255)<<8)|(value&255); half=1; }
    }
    font_get(code,bits);
    if (cursor_type) for (i=0;i<GLYPH_HEIGHT;++i) {
        u16 line=i*logical_height/GLYPH_HEIGHT;
        if (line>=cursor_first && line<=cursor_last) bits[half*CELL_HEIGHT+i]=0xffc0;
    }
    draw_half(bits+half*CELL_HEIGHT,changed>>8,(mouse_y<<8)|mouse_x);
    drawn=(mouse_y<<8)|mouse_x;
}

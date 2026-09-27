/* Independent HHBIOS console. Geometry and BIOS policy live here; the
 * interrupt boundary, existing classifier and planar stores live in vesa.asm.
 * No DOS calls, allocation or C runtime are used after installation. */
#include "vesa.h"

static u16 word(const u8 *p) { return p[0] | ((u16)p[1] << 8); }

int vesa_layout(struct surface *s, const u8 *p, u16 version, u16 mode)
{
    u16 attributes = word(p), window, width=word(p+18), height=word(p+20);
    u16 minimum, bytes, i, j;
    /* VBE <1.2 may omit everything after BytesPerScanLine. Never infer
     * geometry from a vendor mode number or use VGA ports on non-VGA modes. */
    if ((attributes & 0x19) != 0x19 ||
        (version < 0x102 && !(attributes & 2))) return 0;
    if (!width || !height) return 0;
    if (p[27]==FORMAT_PLANAR4) {
        if (p[24]!=4 || p[25]!=4) return 0;
        minimum=width/8+(width % 8 != 0);
    } else {
        if (p[24]!=1 || (p[27]!=4 && p[27]!=6)) return 0;
        if (p[27]==4 && p[25]!=8) return 0;
        if (p[27]==6 && p[25]!=15 && p[25]!=16 && p[25]!=24 && p[25]!=32) return 0;
        bytes=(p[25]+7)/8;
        if (width>65535U/bytes) return 0;
        minimum=width*bytes;
        if (p[27]==6) {
            if (version<0x102) return 0;
            for (i=31; i<37; i+=2) {
                if (!p[i] || p[i]>8 || p[i+1]>=p[25] || p[i]+p[i+1]>p[25]) return 0;
                for (j=31; j<i; j+=2)
                    if (p[i+1]<p[j+1]+p[j] && p[j+1]<p[i+1]+p[i]) return 0;
            }
        }
    }
    if (word(p+16)<minimum || !word(p+6) || word(p+6)>64 || !word(p+4) ||
        word(p+4)>word(p+6)) return 0;
    window = (p[2] & 6) == 6 ? 0 : ((p[3] & 6) == 6 ? 1 : 2);
    if (window==2 || !word(p+8+2*window)) return 0;
    s->width = word(p+18); s->height = word(p+20);
    s->pitch = word(p+16); s->segment = word(p+8+2*window);
    s->window_kb = word(p+6); s->granularity_kb = word(p+4);
    s->mode = mode; s->window = (u8)window;
    s->format = p[27]; s->bpp = p[25]; s->planes = p[24];
    s->red_size = s->red_pos = s->green_size = s->green_pos = 0;
    s->blue_size = s->blue_pos = 0; s->physical = 0;
    if (p[27]==6) {
        s->red_size=p[31]; s->red_pos=p[32]; s->green_size=p[33]; s->green_pos=p[34];
        s->blue_size=p[35]; s->blue_pos=p[36];
    }
    if (version>=0x200 && (attributes & 128))
        s->physical=word(p+40) | ((u32)word(p+42) << 16);
    return 1;
}

int vesa_console_layout(struct surface *s, const u8 *p, u16 version, u16 mode)
{
    /* Keep the application-visible text grid independent of planar pixels.
     * The banked rasterizer admits 64 KiB windows with integral bank steps. */
    if ((word(p) & 0x60) || word(p+18)<800 || word(p+20)<600 ||
        word(p+18)>4096 || word(p+20)>2160 || (word(p+18)&7) ||
        word(p+16)>512 || (word(p+16)&1) || p[27]!=FORMAT_PLANAR4 || word(p+6)!=64 ||
        !word(p+4) || word(p+4)>64 || 64 % word(p+4)) return 0;
    if (((p[2] & 6)==6 ? word(p+8) : word(p+10))!=0xa000) return 0;
    return vesa_layout(s,p,version,mode);
}

#ifndef VESA_HOST
#pragma code_seg("_TEXT", "CODE")
struct registers CALL request;
struct surface CALL screen;
u16 CALL resident_segment, keyboard_segment, font_segment, font_offset;
u16 CALL framebuffer = 0xa000, display_pitch = 100, active_page;
u16 CALL resident_bytes;
u16 CALL display_start, split_line;
u16 CALL text_bank;
u16 CALL requested_mode=0x102, viewport_x, viewport_y, pixel_scale=1, bank_step=1;
u16 CALL raster_height=CELL_HEIGHT;
u16 CALL text_rows=25, text_cells=2000, page_bytes=4096, page_count=8, logical_height=16;
u8 CALL last_row=24;
u8 CALL hardware_mode;
static u16 scan_lines=400, vbe_version;
static struct surface preferred;
u32 CALL plane_bytes=60000UL;
u8 CALL large_surface, mode_selected;
u8 CALL banked_text_allowed;
u8 CALL active, busy, traditional = 1, direct = 1;
static u8 vbe_mode, allow_mode = 1, logical_mode = 3;
static u8 counter, period = 2, cursor_on = 1, cursor_visible, blink = 1;
static u16 cursor_position, cursor_shape = 0x0d0e;
static u16 prompt[80];
/* AH=14h bitmaps are caller-owned: retain their pixels, never their pointer. */
static u8 prompt_bits[80][16], prompt_bitmap[10];
static u8 prompt_open, prompt_col, prompt_dirty, prompt_attr = 0x1e;
u8 CALL prompt_notify;
static void prompt_draw(void);

static void zero(void *p, u16 n)
{
    u8 *b = p;
    while (n--) *b++ = 0;
}
static void call(u16 ax, u16 bx, u16 cx, u16 dx)
{
    struct registers r;
    zero(&r, sizeof(r)); r.ax=ax; r.bx=bx; r.cx=cx; r.dx=dx;
    bios(&r);
}
static u8 bda8(u16 off) { return *PTR(u8, 0x40, off); }
static u16 bda16(u16 off) { return *PTR(u16, 0x40, off); }
static void put8(u16 off, u8 v) { *PTR(u8, 0x40, off) = v; }
static void put16(u16 off, u16 v) { *PTR(u16, 0x40, off) = v; }
static u16 FAR *page(u16 p) { return PTR(u16, 0xb800, p*page_bytes); }
static u16 position(u16 p) { return bda16(0x50 + (p & 7)*2); }
static u16 index(u16 pos) { return (pos >> 8)*TEXT_COLS + (pos & 255); }
static int inside(u16 pos) { return (pos >> 8) < text_rows && (pos & 255) < TEXT_COLS; }

static void keyboard(void)
{
    if (keyboard_segment) {
        *PTR(u8, keyboard_segment, 0x100) = 0x12;
        *PTR(u8, keyboard_segment, 0x101) = active ? 0x12 : 0xff;
        *PTR(u8, keyboard_segment, 0x102) = direct;
    }
}
static void hide_cursor(void)
{
    if (active && cursor_visible) {
        u16 lines=(cursor_shape & 31)-(cursor_shape >> 8 & 31)+1;
        lines=(lines*16+logical_height-1)/logical_height;
        if (large_surface) raster_cursor(cursor_position,lines);
        else cursor_xor(cursor_position,lines);
    }
    cursor_visible = 0;
}
static void show_cursor(void)
{
    cursor_position = position(active_page);
    if (active && cursor_on && !(cursor_shape & 0x2000) && inside(cursor_position) && !mouse_covers(cursor_position)) {
        u16 lines=(cursor_shape & 31)-(cursor_shape >> 8 & 31)+1;
        lines=(lines*16+logical_height-1)/logical_height;
        if (large_surface) raster_cursor(cursor_position,lines);
        else cursor_xor(cursor_position,lines);
        cursor_visible = active;
    }
}
static void repaint(void)
{
    if (!active) return;
    hide_cursor(); mouse_erase(); refresh();
    if (prompt_dirty) prompt_draw();
    mouse_poll(); show_cursor(); mouse_paint();
}
static u8 suspend(void)
{
    u8 previous;
    /* Called before a BIOS mode set, when the old aperture is still valid. */
    hide_cursor();
    if (mouse_erase() && active) refresh();
    mouse_suspend(); previous=active; active = 0; keyboard();
    /* A failed cursor bank access must remain disabled on BIOS failure. */
    return previous;
}

static int activate(u16 preserve)
{
    struct registers r;
    u16 i;
    zero(&r, sizeof(r));
    if (vbe_mode) { r.ax=0x4f02; r.bx=screen.mode | (preserve ? 0x8000 : 0); }
    else r.ax=preserve ? 0x92 : 0x12;
    bios(&r);
    if (vbe_mode && r.ax != 0x004f) return 0;
    hardware_mode=bda8(0x49);
    /* Start at graphics bank zero. The aperture probe isolates B800 text
     * from every bank occupied by the visible plane. */
    zero(&r, sizeof(r)); r.ax=0x4f05; r.bx=screen.window; bios(&r);
    if (r.ax!=0x004f) return 0;
    display_pitch = screen.pitch;
    if (!aperture()) return 0;
    active_page = 0;
    if (!preserve) {
        for (i=0; i<text_cells; ++i) page(0)[i]=0x0720;
        for (i=0; i<8; ++i) put16(0x50+2*i, 0);
    }
    put8(0x49, logical_mode); put16(0x4a, TEXT_COLS);
    put16(0x4c, page_bytes); put16(0x4e, 0); put8(0x62, 0);
    put8(0x84, last_row); put16(0x85, logical_height);
    put8(0x89,(bda8(0x89)&0x6f)|(scan_lines==200 ? 0x80 : scan_lines==400 ? 0x10 : 0));
    put8(0x88,(bda8(0x88)&0xf0)|(scan_lines==200 ? 8 : 9));
    put16(0x60, cursor_shape);
    active = 1; cursor_visible = 0; prompt_dirty = 1;
    /* CKBD must enter through INT 10h after we release the resident stack. */
    if (!prompt_open && keyboard_segment && (*PTR(u8,keyboard_segment,0xf4)&2))
        prompt_notify=1;
    if (resident_bytes) mouse_resume();
    keyboard(); invalidate(); repaint();
    return 1;
}

static void geometry(u16 rows,u16 height)
{
    u16 n;
    text_rows=rows; last_row=(u8)(rows-1); text_cells=80*rows;
    logical_height=height; page_bytes=rows>25 ? 8192 : 4096;
    page_count=banked_text ? 32768U/page_bytes : 1;
    large_surface=(u8)(rows!=25 || screen.width!=800 || screen.height!=600 || screen.pitch!=100);
    plane_bytes=wide_product(screen.pitch,screen.height);
    raster_height=screen.height>=CELL_HEIGHT*(rows+1) ? CELL_HEIGHT : GLYPH_HEIGHT;
    pixel_scale=1;
    for (n=2;n<=4 && screen.width>=800*n;++n) {
        if (screen.height>=CELL_HEIGHT*(rows+1)*n) { pixel_scale=n; raster_height=CELL_HEIGHT; }
        else if (screen.height>=GLYPH_HEIGHT*(rows+1)*n) { pixel_scale=n; raster_height=GLYPH_HEIGHT; }
    }
    viewport_x=(screen.width-800*pixel_scale)/2;
    viewport_y=large_surface ? (screen.height-raster_height*(rows+1)*pixel_scale)/2 : 0;
    bank_step=64/screen.granularity_kb;
    text_bank=(u16)((plane_bytes+65535UL)>>16)*bank_step;
}

static int saved_surface(const struct surface *s,u16 rows)
{
    return s->width>=800 && s->width<=4096 && !(s->width&7) &&
        s->height>=600 && s->height<=2160 && s->height>=GLYPH_HEIGHT*(rows+1) &&
        s->pitch>=s->width/8 && s->pitch<=512 && !(s->pitch&1) &&
        s->segment==0xa000 && s->window_kb==64 && s->granularity_kb &&
        s->granularity_kb<=64 && !(64%s->granularity_kb) && s->window<2 &&
        s->format==FORMAT_PLANAR4 && s->bpp==4 && s->planes==4;
}

static u8 in8(u16 port);
#pragma aux in8 = "in al,dx" parm [dx] value [al];
static void out8(u16 port,u8 value);
#pragma aux out8 = "out dx,al" parm [dx] [al];

/* Native state restore is still responsible for the caller's opaque buffer.
 * Re-establish our owned surface through the mode API afterwards: some BIOSes
 * restore VGA registers but lose extended timing or mode bookkeeping. Preserve
 * the resulting BIOS data and palette, including components not requested by
 * the caller's mask. Only our validated console records take this path. */
static int restore_surface(void)
{
    u8 bda[37], colors[768], attributes[21],mask,index,dac_index;
    u16 i;
    struct registers r;
    for (i=0;i<30;++i) bda[i]=bda8(0x49+i);
    for (i=0;i<7;++i) bda[30+i]=bda8(0x84+i);
    index=in8(0x3c0); mask=in8(0x3c6); dac_index=in8(0x3c8);
    for (i=0;i<21;++i) { in8(0x3da); out8(0x3c0,(u8)i); attributes[i]=in8(0x3c1); }
    in8(0x3da); out8(0x3c0,index);
    out8(0x3c7,0);
    for (i=0;i<768;++i) colors[i]=in8(0x3c9);
    zero(&r,sizeof(r)); r.ax=0x4f02; r.bx=screen.mode|0x8000; bios(&r);
    for (i=0;i<30;++i) put8(0x49+i,bda[i]);
    for (i=0;i<7;++i) put8(0x84+i,bda[30+i]);
    out8(0x3c8,0);
    for (i=0;i<768;++i) out8(0x3c9,colors[i]);
    out8(0x3c6,mask); out8(0x3c8,dac_index);
    for (i=0;i<21;++i) { in8(0x3da); out8(0x3c0,(u8)i); out8(0x3c0,attributes[i]); }
    in8(0x3da); out8(0x3c0,index);
    display_pitch=screen.pitch;
    return r.ax==0x004f;
}

/* A ROM-font change is a logical text operation. Keep text bytes intact even
 * when the physical surface must grow to retain complete native glyphs. */
static int rows_mode(u16 rows,u16 height,u16 preserve)
{
    struct surface candidate=preferred, previous=screen;
    struct registers r;
    u8 info[256], was_active=active;
    u16 old_rows=text_rows,old_height=logical_height,old_page=active_page,i;
    u16 cursors[8];
    if (!rows || rows>MAX_TEXT_ROWS || (!banked_text && rows!=25)) return 0;
    if (candidate.height<GLYPH_HEIGHT*(rows+1)) {
        for (i=0;i<2;++i) {
            zero(&r,sizeof(r)); zero(info,sizeof(info));
            r.ax=0x4f01; r.cx=i ? 0x106 : 0x104;
            r.es=resident_segment; r.di=(u16)info; bios(&r);
            if (r.ax==0x004f && info[29] &&
                vesa_console_layout(&candidate,info,vbe_version,r.cx) &&
                (info[2+candidate.window]&1) && candidate.height>=GLYPH_HEIGHT*(rows+1)) break;
        }
        if (i==2) return 0;
    }
    suspend();
    for (i=0;i<8;++i) cursors[i]=position(i);
    if (preserve && !font_text(1)) {
        active=was_active; keyboard(); if (active) { mouse_resume(); repaint(); } return 0;
    }
    screen=candidate; geometry(rows,height);
    reprobe();
    if (!activate(1)) {
        screen=previous; geometry(old_rows,old_height); reprobe();
        if (!activate(1)) { active=0; keyboard(); return 0; }
    }
    active=0;
    if (preserve) {
        if (!font_text(0)) { keyboard(); return 0; }
    } else for (i=0;i<text_cells;++i) page(0)[i]=0x0720;
    for (i=0;i<8;++i) put16(0x50+i*2,preserve && inside(cursors[i]) ? cursors[i] : 0);
    active_page=preserve && old_page<page_count ? old_page : 0;
    cursor_shape=((logical_height-2)<<8)|(logical_height-1);
    put16(0x60,cursor_shape);
    put8(0x62,(u8)active_page); put16(0x4e,active_page*page_bytes);
    active=1; keyboard(); invalidate(); repaint();
    return text_rows==rows;
}

#pragma code_seg("INIT_TEXT", "INIT")
u16 CALL initialize(void)
{
    struct registers r;
    u8 controller[256], mode_info[256];
    u16 version, modes_seg, modes_off, n, number, previous_mode;
    zero(controller, sizeof(controller)); zero(&r, sizeof(r)); r.ax=0x4f00;
    r.es=resident_segment; r.di=(u16)controller;
    bios(&r);
    if (r.ax != 0x004f || controller[0]!='V' || controller[1]!='E' ||
        controller[2]!='S' || controller[3]!='A' || (controller[10] & 2)) return 1;
    version = word(controller+4);
    vbe_version=version;
    if (version < 0x100) return 1;
    modes_off=word(controller+14); modes_seg=word(controller+16);
    /* An explicit /M selects one mode. Otherwise try 102h and a bounded
     * advertised list, without wandering through a broken ROM. */
    for (n=0; n<257; ++n) {
        if (!n) number=requested_mode;
        else {
            if (mode_selected) break;
            if (modes_off > 0xfffd || (!modes_seg && !modes_off)) break;
            number=*PTR(u16, modes_seg, modes_off); modes_off+=2;
            if (number==0xffff) break;
        }
        zero(mode_info, sizeof(mode_info)); zero(&r, sizeof(r));
        r.ax=0x4f01; r.cx=number; r.es=resident_segment; r.di=(u16)mode_info;
        bios(&r);
        if (r.ax==0x004f && vesa_console_layout(&screen, mode_info, version, number)) { vbe_mode=1; break; }
    }
    if (!vbe_mode) return 1;
    preferred=screen;
    geometry(25,16);
    banked_text_allowed=(u8)(version>=0x102 && mode_info[29]>0 &&
                            (mode_info[2+screen.window] & 1) &&
                            !(64 % screen.granularity_kb));
    if (large_surface && !banked_text_allowed) return 1;
    bank_step=64/screen.granularity_kb;
    text_bank=(u16)((plane_bytes+65535UL)>>16)*bank_step;
    /* Put all eight logical text pages in spare VRAM where available. This
     * also avoids page 1..7 aliasing visible pixels on 64 KiB VGA mappings. */
    banked_text=banked_text_allowed;
    page_count=banked_text ? 8 : 1;
    /* On a 64 KiB aliasing aperture, reserve B800's first 4 KiB and place
     * scanout across a line-aligned wrap. The CPU start must be paragraph
     * aligned too. Geometry is kept out of the character classifier. */
    if (!banked_text) {
        n=(screen.pitch*screen.height-0x8000U+screen.pitch-1)/screen.pitch;
        while ((n*screen.pitch) & 15) ++n;
        display_start=0U-n*screen.pitch; split_line=n-1;
    }
    zero(&r, sizeof(r)); r.ax=0x1130; r.bx=0x0600; bios(&r);
    font_segment=r.es; font_offset=r.bp;
    if (!font_segment) return 2;
    zero(&r,sizeof(r)); r.ax=0x0f00; bios(&r); previous_mode=r.ax & 127;
    zero(&r,sizeof(r)); r.ax=0x4f03; bios(&r);
    if (r.ax==0x004f) previous_mode=r.bx & 0x7fff;
    if (activate(0)) return 0;
    /* Nothing has been hooked yet. A failed bank/aperture probe must not
     * strand the caller in a partially configured graphics mode. */
    active=0; keyboard();
    zero(&r,sizeof(r));
    if (previous_mode>=0x100) { r.ax=0x4f02; r.bx=previous_mode; }
    else r.ax=previous_mode;
    bios(&r);
    return 3;
}
#pragma code_seg("_TEXT", "CODE")

static void scroll(u16 p, u8 down, u16 count, u16 attribute, u16 top, u16 bottom)
{
    u16 x, y, left=top & 255, right=bottom & 255, first=top >> 8, last=bottom >> 8;
    u16 FAR *text=page(p);
    if (left>=80 || first>=text_rows || left>right || first>last) return;
    if (right>79) right=79;
    if (last>=text_rows) last=text_rows-1;
    if (!count || count>last-first+1) count=last-first+1;
    for (y=0; y<=last-first; ++y) {
        u16 row=down ? last-y : first+y;
        for (x=left; x<=right; ++x) {
            u16 value=(attribute << 8) | 32;
            if (down ? row>=first+count : row+count<=last)
                value=text[(down ? row-count : row+count)*80+x];
            text[row*80+x]=value;
        }
    }
}

static void tty(u8 ch, u16 p)
{
    u16 pos=position(p), col=pos & 255, row=pos >> 8;
    u16 FAR *text=page(p);
    if (row>=text_rows || col>=80) return;
    if (ch==7) { call(0x0e07, 0, 0, 0); return; }
    if (ch==8) { if (col) --col; }
    else if (ch==13) col=0;
    else if (ch==10) ++row;
    else {
        text[row*80+col]=(text[row*80+col] & 0xff00) | ch;
        if (++col==80) { col=0; ++row; }
    }
    if (row==text_rows) { scroll(p, 0, 1, text[(text_rows-1)*80] >> 8, 0, (last_row << 8)|79); --row; }
    put16(0x50+(p & 7)*2, (row << 8) | col);
}

/* The VBE hardware-state buffer remains BIOS-owned. Append one 64-byte
 * private record, advertised by the size query; never enlarge the BIOS part. */
static void state(void)
{
    struct registers size;
    struct surface saved;
    u16 action=request.dx & 255, flags=request.cx, offset, i;
    u8 was_active=active, was_cursor=cursor_visible;
    u8 FAR *record;
    size=request; size.dx &= 0xff00; bios(&size);
    if (size.ax!=0x004f) { request.ax=size.ax; return; }
    if (size.bx>=1023) { request.ax=0x014f; return; }
    if (!action) { request.ax=size.ax; request.bx=size.bx+1; return; }
    if (action>2 || request.bx > 65535U-(size.bx+1)*64U) { request.ax=0x014f; return; }
    offset=request.bx+size.bx*64;
    record=PTR(u8, request.es, offset);
    /* The software cursor is part of pixel memory, not BIOS state. Remove it
     * before saving so restoration will not add a second XOR cursor. */
    if (action==1 && active) { hide_cursor(); was_active=active; }
    /* Either VGA hardware or extended VBE registers can change the layout.
     * Remove the cursor while its old bank/stride is still accessible. */
    if (action==2 && (flags & 9)) was_active=suspend();
    bios(&request);
    if (request.ax!=0x004f) {
        active=was_active; keyboard();
        if (action==2 && (flags & 9) && active) mouse_resume();
        if (was_cursor && !cursor_visible) show_cursor();
        return;
    }
    if (action==1) {
        for (i=0; i<64; ++i) record[i]=0;
        record[0]='H'; record[1]='H'; record[2]='V'; record[3]=1;
        record[4]=active; record[5]=logical_mode; record[6]=direct;
        record[7]=(u8)active_page; record[8]=policy; record[9]=hanzi;
        record[10]=(u8)cursor_shape; record[11]=(u8)(cursor_shape >> 8);
        record[12]=cursor_on; record[13]=(u8)flags; record[14]=traditional;
        record[15]=blink;
        record[16]=(u8)text_rows; record[17]=(u8)logical_height;
        record[18]=(u8)scan_lines; record[19]=(u8)(scan_lines>>8);
        for (i=0;i<sizeof(screen);++i) record[20+i]=((u8 *)&screen)[i];
        record[48]=(u8)text_bank; record[49]=(u8)(text_bank>>8);
        record[50]=hardware_mode;
        if (was_cursor) show_cursor();
    } else if (flags & 9) {
        if (record[0]=='H' && record[1]=='H' && record[2]=='V' && record[3]==1 &&
            record[13]==(u8)flags && record[4]<=1 && record[7]<8) {
            active=record[4]; logical_mode=record[5]; direct=record[6];
            active_page=record[7]; policy=record[8]; hanzi=record[9];
            cursor_shape=record[10] | ((u16)record[11] << 8);
            cursor_on=record[12]; traditional=record[14]; blink=record[15];
            if (record[16]) {
                if (record[16]>MAX_TEXT_ROWS ||
                    (record[17]!=8 && record[17]!=14 && record[17]!=16)) {
                    active=0; request.ax=0x014f; keyboard(); return;
                }
                for (i=0;i<sizeof(saved);++i) ((u8 *)&saved)[i]=record[20+i];
                if (!saved_surface(&saved,record[16]) || record[7]>=
                    (record[16]>25 ? 4 : 8)) {
                    active=0; request.ax=0x014f; keyboard(); return;
                }
                screen=saved;
                geometry(record[16],record[17]);
                text_bank=record[48]|((u16)record[49]<<8);
                scan_lines=record[18]|((u16)record[19]<<8);
                hardware_mode=record[50];
            }
            cursor_visible=0;
            if (active) {
                if (record[16] && !restore_surface()) { active=0; request.ax=0x014f; keyboard(); return; }
                if (!aperture()) { active=0; request.ax=0x014f; }
                else {
                    put8(0x49, logical_mode); put8(0x84,last_row);
                    put16(0x85,logical_height); put16(0x4c,page_bytes);
                    put8(0x62,(u8)active_page); put16(0x4e,active_page*page_bytes);
                    invalidate(); prompt_dirty=1;
                }
            }
        }
        keyboard();
        if (active) mouse_resume();
    }
}

static void prompt_draw(void)
{
    u16 i;
    if (!begin_draw()) return;
    for (i=0; i<80; ++i) {
        u16 c=prompt[i] & 255, attr=prompt[i] >> 8;
        if (!prompt_open) draw(32,0,(text_rows << 8)+i);
        else if (prompt_bitmap[i/8] & (1 << (i&7)))
            bitmap(resident_segment,(u16)prompt_bits[i],attr,(text_rows << 8)+i,1);
        else if (c>=0xa1 && c<=0xf7 && i<79 &&
            !(prompt_bitmap[(i+1)/8] & (1 << ((i+1)&7))) &&
            (prompt[i+1] & 255)>=0xa1 && (prompt[i+1] & 255)<=0xfe) {
            draw((c << 8) | (prompt[i+1] & 255), (attr << 8) | (prompt[i+1] >> 8), (text_rows << 8)+i);
            ++i;
        } else draw(c, attr, (text_rows << 8)+i);
    }
    end_draw();
    prompt_dirty=0;
}
static void prompt_clear(void)
{
    u16 i;
    for (i=0; i<80; ++i) prompt[i]=((u16)prompt_attr << 8) | 32;
    zero(prompt_bitmap,sizeof(prompt_bitmap));
    prompt_col=0; prompt_open=1;
}

static void extended(void)
{
    u16 op=request.ax & 255, i, pos=request.dx;
    if (op==0) { prompt_clear(); prompt_draw(); }
    else if (op==1 || op==3) {
        if (!prompt_open) prompt_clear();
        if (op==3 && (pos & 255)==8) {
            if (prompt_col) --prompt_col;
            prompt[prompt_col]=((u16)prompt_attr << 8)|32;
            prompt_bitmap[prompt_col/8] &= ~(1 << (prompt_col&7));
        } else for (i=0; i<(op==3 ? 1 : request.cx) && prompt_col+i<80; ++i) {
            prompt[prompt_col+i]=(request.bx & 255)*256+(pos & 255);
            prompt_bitmap[(prompt_col+i)/8] &= ~(1 << ((prompt_col+i)&7));
        }
        if (op==3 && (pos & 255)!=8 && prompt_col<79) ++prompt_col;
        prompt_draw();
    } else if (op==2) { if ((pos & 255)<80) prompt_col=(u8)pos; }
    else if (op==4) {
        prompt_open=0;
        prompt_draw();
    } else if (op==5) prompt_attr=(u8)request.bx;
    else if (op==6) {
        request.ax=0x0f12; request.bx=(text_rows << 8)|4; request.cx=(raster_height << 8) | (text_rows+1);
        request.dx=0x80 | traditional; request.si=screen.width-1;
        request.di=screen.height-1; request.bp=framebuffer;
    } else if (op==7) { logical_mode=(u8)(request.bx >> 8); put8(0x49, logical_mode); }
    else if (op==8) {
        if (inside(pos)) {
            if (large_surface) raster_cursor(pos,16);
            else cursor_xor(pos,16);
        }
    }
    else if (op==9) {
        if (inside(pos)) { page(active_page)[index(pos)]=(request.bx << 8) | (request.bx >> 8); repaint(); }
    } else if (op==10) {
        u16 col=pos & 255,j;
        if (request.si<=0xffc0 && col<80) {
            if (!prompt_open) prompt_clear();
            for (i=0;i<4 && col+i<80;++i) {
                for (j=0;j<16;++j)
                    prompt_bits[col+i][j]=*PTR(u8,request.bp,request.si+i*16+j);
                prompt[col+i]=request.bx << 8;
                prompt_bitmap[(col+i)/8] |= 1 << ((col+i)&7);
            }
            prompt_draw();
        }
    } else if (op==11) { blink=(u8)(request.bx >> 8); }
    else if (op==12) { request.bx=resident_segment; request.ax=(u16)shadow; }
    else if (op==13) { period=(u8)(request.bx >> 8); if (!period) period=1; }
    else if (op==14) { request.bx=resident_segment; request.ax=frame_alias_offset; }
    else if (op==15) {
        u16 off=request.si, c;
        if (!begin_draw()) return;
        while (off<0xfffe && (pos & 255)<80) {
            c=*PTR(u8,request.es,off++);
            if (!c) break;
            if (c>=0xa1 && c<=0xf7 && *PTR(u8,request.es,off)>=0xa1 && *PTR(u8,request.es,off)<=0xfe) {
                c=(c << 8) | *PTR(u8,request.es,off++);
                draw_wide(c,(request.bx & 255)*257,pos); pos+=4;
            } else { draw_wide(c,request.bx & 255,pos); pos+=2; }
        }
        end_draw();
    }
    else if (op==16) boundary(&request);
}

u16 CALL dispatch(void)
{
    u16 function=request.ax >> 8, lo=request.ax & 255, i, p=request.bx >> 8;
    u16 pos, count;
    if (function==0xff) { request.ax=0x56; return 1; }
    if (function==0x14 && lo==17) {
        request.ax=0x5356; request.bx=1; request.cx=sizeof(screen);
        request.es=resident_segment; request.di=(u16)&screen;
        request.si=resident_bytes; request.bp=banked_text; request.dx=framebuffer;
        return 1;
    }
    if (function==0x14 && lo==19) {
        request.ax=0x4632; request.bx=font_kind; request.cx=font_kb;
        request.dx=font_fault; request.si=CELL_WIDTH; request.di=CELL_HEIGHT;
        return 1;
    }
    if (function==0x14 && lo==21) {
        request.ax=0x5650; request.bx=viewport_x; request.cx=viewport_y;
        request.dx=pixel_scale; request.si=(u16)plane_bytes;
        request.di=(u16)(plane_bytes>>16);
        return 1;
    }
    if (function==0x14 && (lo==18 || lo==20)) {
        u32 offset=request.si;
        if (lo==20) offset|=(u32)request.dx<<16;
        if (!active || request.bx>3 || offset>plane_bytes || request.cx>plane_bytes-offset ||
            request.di>65535U-request.cx) request.ax=1;
        else if (!request.cx) request.ax=0;
        else {
            if (large_surface) raster_read(request.bx,offset,request.es,request.di,request.cx);
            else read_plane(request.bx,request.si,request.es,request.di,request.cx);
            request.ax=active ? 0 : 1;
            if (!active) keyboard();
        }
        return 1;
    }
    if (function==0x4f) {
        if (lo==4) state();
        else if (lo==2) {
            u8 previous=active;
            u8 previous_cursor=cursor_visible;
            u16 mode=request.bx & 0x3fff;
            previous=suspend(); bios(&request);
            if (request.ax==0x004f) {
                if (mode<=3) {
                    logical_mode=3; direct=1;
                    if (text_rows!=25 && banked_text) {
                        if (!rows_mode(25,scan_lines/25,0)) request.ax=0x014f;
                    } else if (!activate(0)) request.ax=0x014f;
                }
            } else { active=previous; keyboard(); if (active) mouse_resume(); if (previous_cursor) show_cursor(); }
        } else {
            /* BX is an input subfunction, but 4F06 returns a byte pitch in
             * the same register. Classify ownership before entering BIOS.
             * VBE 3.0 scheduling/stereo setters also own the display. */
            u16 op=request.bx & 255;
            u8 changes=(u8)((lo==5 && !(request.bx & 0xff00)) ||
                (lo==6 && (op==0 || op==2)) ||
                (lo==7 && (op==0 || op==0x80 || op==2 || op==3 ||
                           op==0x82 || op==0x83 || op==5 || op==6)));
            u8 previous=active, previous_cursor=cursor_visible;
            if (changes) previous=suspend();
            bios(&request);
            if (changes && request.ax!=0x004f) {
                active=previous; keyboard();
                if (active) mouse_resume();
                if (previous_cursor) show_cursor();
            }
        }
        /* Cursor removal or rollback can itself lose the graphics bank. */
        if (!active) keyboard();
        return 1;
    }
    /* Applications may select scanlines while a graphics font probe has
     * suspended us. Track that request before they return to text mode. */
    if (function==0x12 && (request.bx & 255)==0x30 && lo<=2) {
        bios(&request);
        if ((request.ax & 255)==0x12) scan_lines=lo==0 ? 200 : lo==1 ? 350 : 400;
        return 1;
    }
    if (!function) {
        if (!allow_mode) return 1;
        suspend();
        if ((lo & 127)<=3 || (lo & 127)==0x12) {
            logical_mode=(lo & 127)==0x12 ? 0x12 : 3;
            direct=logical_mode==3;
            if (text_rows!=25 && banked_text) rows_mode(25,scan_lines/25,lo & 128);
            else { logical_height=scan_lines/25; activate(lo & 128); }
        } else bios(&request);
        return 1;
    }
    if (!active) return 0;
    /* A one-image adapter can expose only page zero without overlapping
     * scanout. Never accept an inaccessible page and overwrite graphics. */
    if ((p>=page_count || (!banked_text && p)) && (function==2 || function==3 || function==8 ||
        function==9 || function==10 || function==0x13)) return 1;
    switch (function) {
    case 1:
        hide_cursor(); cursor_shape=request.cx;
        if ((cursor_shape & 31)<(cursor_shape >> 8 & 31)) cursor_shape |= 0x2000;
        put16(0x60, cursor_shape); show_cursor(); break;
    case 2:
        hide_cursor(); put16(0x50+(p & 7)*2, request.dx); show_cursor(); break;
    case 3: request.dx=position(p); request.cx=cursor_shape; break;
    case 5:
        if (lo>=page_count) break;
        hide_cursor(); active_page=lo & 7; put8(0x62, (u8)active_page);
        put16(0x4e, active_page*page_bytes); invalidate(); repaint(); break;
    case 6: case 7:
        scroll(active_page, function==7, lo, p, request.cx, request.dx); repaint(); break;
    case 8:
        pos=position(p); request.ax=inside(pos) ? page(p)[index(pos)] : 0; break;
    case 9: case 10:
        pos=position(p);
        if (!inside(pos)) break;
        i=index(pos); count=request.cx;
        if (count>text_cells-i) count=text_cells-i;
        while (count--) { page(p)[i]=(function==9 ? request.bx << 8 : page(p)[i] & 0xff00) | lo; ++i; }
        repaint(); break;
    case 0x0e: tty((u8)lo, active_page); repaint(); break;
    case 0x0c: case 0x0d:
        if (request.cx<screen.width && request.dx<screen.height) {
            i=large_surface ? raster_pixel(request.cx, request.dx, lo, function==0x0c) :
                pixel(request.cx, request.dx, lo, function==0x0c);
            if (function==0x0d) request.ax=(request.ax & 0xff00) | i;
        }
        break;
    case 0x0f: request.ax=(80 << 8) | logical_mode; request.bx=(request.bx & 255) | (active_page << 8); break;
    case 0x10:
        if (lo==3) break; /* keep sixteen background colors */
        bios(&request); break;
    case 0x11:
        if (lo==0x30) { bios(&request); request.cx=logical_height; request.dx=(request.dx & 0xff00)|last_row; }
        else if (lo==0x10 || lo==0x11 || lo==0x12 || lo==0x14) {
            /* User-font activation also changes the logical row count.
             * Chinese scanout continues to use our native bitmap font. */
            u16 height=lo==0x10 ? p : lo==0x12 ? 8 : lo==0x11 ? 14 : 16;
            if (height && height<=32) rows_mode(scan_lines/height,height,1);
        }
        break;
    case 0x1b: {
        u8 FAR *info=PTR(u8,request.es,request.di);
        if (lo || request.bx) return 0;
        if (request.di>0xffc0) { request.ax &= 0xff00; break; }
        bios(&request);
        if ((request.ax & 255)!=0x1b) break;
        /* Keep the BIOS capability pointer, but describe the logical mode.
         * DOSSHELL checks 2Ah and retries with the returned scanline setting. */
        for (i=0;i<30;++i) info[4+i]=bda8(0x49+i);
        info[0x22]=(u8)text_rows;
        info[0x23]=(u8)logical_height; info[0x24]=0;
        info[0x27]=16; info[0x28]=0; info[0x29]=(u8)page_count;
        info[0x2a]=scan_lines==200 ? 0 : scan_lines==350 ? 1 : 2;
        info[0x2d] &= ~0x20; /* backgrounds retain all sixteen colors */
        break;
    }
    case 0x13: {
        u16 saved=position(p), off=request.bp;
        put16(0x50+(p & 7)*2, request.dx);
        for (i=0; i<request.cx && off<0xffff; ++i) {
            u8 c=*PTR(u8, request.es, off++), attr=(u8)request.bx;
            if (lo & 2) { if (off==0xffff) break; attr=*PTR(u8, request.es, off++); }
            pos=position(p);
            if (inside(pos) && c>=32) page(p)[index(pos)]=(u16)attr << 8;
            tty(c, p);
        }
        if (!(lo & 1)) put16(0x50+(p & 7)*2, saved);
        repaint(); break;
    }
    case 0x14: extended(); break;
    case 0x15: prompt_dirty=1; repaint(); break;
    case 0x16: {
        u8 bits[32]; glyph(request.dx, bits);
        for (i=0; i<(request.dx >> 8 ? 32 : 16); ++i) *PTR(u8, request.bp, request.bx+i)=bits[i];
        break;
    }
    case 0x17: hide_cursor(); cursor_on=(u8)lo; if (cursor_on) show_cursor(); break;
    case 0x18:
        if (lo<2) { hanzi=(u8)!lo; invalidate(); }
        else if (lo==4 || lo==5) allow_mode=(u8)(lo==5);
        else if (lo==10 || lo==11) { direct=(u8)(lo==11); keyboard(); }
        else if (lo==12) { policy=(u8)p; invalidate(); }
        else if (lo==17 || lo==18) { traditional=(u8)(lo==18); invalidate(); prompt_dirty=1; }
        else if (lo==19 || lo==23) { invalidate(); prompt_dirty=1; }
        repaint(); break;
    default: return 0;
    }
    if (!active) keyboard();
    return 1;
}

void CALL tick(void)
{
    if (!active || ++counter<period) return;
    counter=0;
    hide_cursor(); mouse_erase(); refresh(); mouse_poll();
    if (!active) { keyboard(); return; }
    if (prompt_dirty) prompt_draw();
    /* Keep blink phase independent of dirty text. */
    if (!blink || (bda8(0x6c) & 8)) show_cursor();
    mouse_paint();
}
#endif

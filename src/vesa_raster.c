/* Bank-spanning planar stores. Logical B800 cells remain independent of the
 * physical surface, viewport and integer pixel enlargement. No heap or CRT. */
#include "vesa.h"

static void port(u16 address, u16 value);
#pragma aux port = "out dx,ax" parm [dx] [ax];
static u8 ink[CELL_HEIGHT][6], masks[6];

static u8 FAR *address(u32 offset)
{
    u16 block=(u16)(offset >> 16);
    if (!active || (block!=mapped_block && !graphics_bank(block))) return 0;
    return PTR(u8,screen.segment,(u16)offset);
}

static void plane(u16 p)
{
    port(0x3ce,4 | (p << 8));
    port(0x3c4,2 | (0x100 << p));
}

void CALL raster_cell(const u16 *bits, u16 attribute, u16 position)
{
    u16 x, y, sy, dx, dy, p, n, shift, width, k, b;
    u8 fg, bg, value;
    u8 FAR *v;
    u32 offset;
    if ((position & 255)>=TEXT_COLS || (position >> 8)>text_rows) return;
    x=viewport_x+(position & 255)*CELL_WIDTH*pixel_scale;
    y=viewport_y+(position >> 8)*raster_height*pixel_scale;
    shift=x & 7; width=CELL_WIDTH*pixel_scale; n=(shift+width+7)>>3;
    for (b=0;b<n;++b) masks[b]=0;
    for (sy=0;sy<raster_height;++sy) {
        for (b=0;b<n;++b) ink[sy][b]=0;
        k=shift;
        for (dx=0;dx<CELL_WIDTH;++dx) for (dy=0;dy<pixel_scale;++dy,++k) {
            value=0x80 >> (k & 7);
            masks[k>>3]|=value;
            if (bits[sy] & (0x8000 >> dx)) ink[sy][k>>3]|=value;
        }
    }
    for (p=0;p<4;++p) {
        plane(p);
        fg=(attribute & (1<<p)) ? 255 : 0;
        bg=(attribute & (16<<p)) ? 255 : 0;
        offset=wide_product(y,display_pitch)+(x>>3);
        for (sy=0;sy<raster_height;++sy) for (dy=0;dy<pixel_scale;++dy) {
            for (b=0;b<n;++b) {
                v=address(offset+b); if (!v) return;
                value=(ink[sy][b] & (fg^bg)) ^ bg;
                *v=masks[b]==255 ? value : (*v & ~masks[b]) | (value & masks[b]);
            }
            offset+=display_pitch;
        }
    }
    port(0x3c4,0x0f02);
}

void CALL raster_cursor(u16 position, u16 lines)
{
    u16 x, y, width, height, p, dx, dy;
    u8 FAR *v;
    u32 offset;
    if (!begin_draw()) return;
    if (lines>16) lines=16;
    width=CELL_WIDTH*pixel_scale;
    height=((lines*GLYPH_HEIGHT+15)>>4)*pixel_scale;
    x=viewport_x+(position & 255)*width;
    y=viewport_y+((position >> 8)*raster_height+GLYPH_HEIGHT)*pixel_scale-height;
    for (p=0;p<4 && active;++p) {
        plane(p);
        for (dy=0;dy<height && active;++dy) for (dx=0;dx<width;++dx) {
            offset=wide_product(y+dy,display_pitch)+((x+dx)>>3);
            v=address(offset); if (!v) break;
            *v^=0x80 >> ((x+dx)&7);
        }
    }
    end_draw();
}

u16 CALL raster_pixel(u16 x, u16 y, u16 color, u16 writing)
{
    u16 p, result=0;
    u8 mask=0x80 >> (x&7), value;
    u8 FAR *v;
    u32 offset=wide_product(y,display_pitch)+(x>>3);
    if (!begin_draw()) return 0;
    for (p=0;p<4;++p) {
        plane(p); v=address(offset); if (!v) break;
        value=*v;
        if (value & mask) result|=1<<p;
        if (writing) {
            if (color & 0x80) { if (color & (1<<p)) *v=value^mask; }
            else *v=(value & ~mask) | ((color & (1<<p)) ? mask : 0);
        }
    }
    end_draw();
    return result;
}

void CALL raster_read(u16 p, u32 offset, u16 segment, u16 destination, u16 count)
{
    u16 part, i;
    u8 FAR *source;
    u8 FAR *out=PTR(u8,segment,destination);
    if (!begin_draw()) return;
    port(0x3ce,4 | (p << 8));
    while (count) {
        source=address(offset); if (!source) break;
        part=count;
        if ((u16)offset && part>0U-(u16)offset) part=0U-(u16)offset;
        for (i=0;i<part;++i) *out++=*source++;
        count-=part; offset+=part;
    }
    end_draw();
}

/* Resident display ABI. All sizes are bytes unless explicitly named otherwise. */
#ifndef HH_VESA_H
#define HH_VESA_H
typedef unsigned char u8;
typedef unsigned short u16;
#if defined(VESA_HOST) && !defined(__WATCOMC__)
typedef unsigned int u32;
#else
typedef unsigned long u32;
#endif

/* The console remains 80x25. Pixel geometry is a separate contract. */
#define TEXT_COLS 80
#define TEXT_ROWS 25
#define CELL_WIDTH 10
#define CELL_HEIGHT 23
#define GLYPH_HEIGHT 20
#define FORMAT_PLANAR4 3

/* An 8086 MUL already yields the full 32-bit address without a CRT helper. */
#if defined(__WATCOMC__)
static u32 wide_product(u16 a, u16 b);
#pragma aux wide_product = "mul dx" parm [ax] [dx] value [dx ax] modify [ax dx];
#else
#define wide_product(a,b) ((u32)(a)*(b))
#endif

#pragma pack(push, 1)
struct surface {
    u16 width, height, pitch, segment;
    u16 window_kb, granularity_kb, mode;
    u8 window, format, bpp, planes;
    u8 red_size, red_pos, green_size, green_pos, blue_size, blue_pos;
    u32 physical;
};
/* Same order as the 8086 entry pushes; also used for original BIOS calls. */
struct registers {
    u16 ax, bx, cx, dx, si, di, bp, ds, es, flags;
};
#pragma pack(pop)

int vesa_layout(struct surface *out, const u8 *info, u16 version, u16 mode);
int vesa_console_layout(struct surface *out, const u8 *info, u16 version, u16 mode);

#ifndef VESA_HOST
#define FAR __far
#define CALL __cdecl
#define PTR(type, seg, off) ((type FAR *)(((u32)(seg) << 16) | (u16)(off)))
extern struct registers CALL request;
extern struct surface CALL screen;
extern u16 CALL resident_segment, keyboard_segment, font_segment, font_offset;
extern u16 CALL framebuffer, display_pitch, active_page;
extern u16 CALL resident_bytes;
extern u8 CALL banked_text;
extern u16 CALL display_start, split_line;
extern u16 CALL text_bank;
extern u16 CALL requested_mode, viewport_x, viewport_y, pixel_scale, bank_step;
extern u16 CALL raster_height;
extern u32 CALL plane_bytes;
extern u8 CALL large_surface;
extern u16 CALL mapped_block;
extern u8 CALL banked_text_allowed;
extern u8 CALL active, busy, policy, hanzi, traditional;
extern u16 CALL shadow[TEXT_COLS*TEXT_ROWS];
extern u16 CALL frame_alias_offset;
void CALL font_get(u16 code, u16 *out);
u16 CALL font_open(void);
void CALL font_close(void);
extern u16 CALL font_kind, font_kb, font_fault;
void CALL bios(struct registers *r);
void CALL refresh(void);
void CALL invalidate(void);
void CALL boundary(struct registers *r);
u16 CALL aperture(void);
u16 CALL begin_draw(void);
void CALL end_draw(void);
void CALL draw(u16 code, u16 attribute, u16 position);
void CALL draw_wide(u16 code, u16 attribute, u16 position);
void CALL bitmap(u16 segment, u16 offset, u16 attribute, u16 position);
void CALL glyph(u16 code, u8 *out);
void CALL cursor_xor(u16 position, u16 lines);
u16 CALL pixel(u16 x, u16 y, u16 color, u16 writing);
void CALL read_plane(u16 plane, u16 offset, u16 segment, u16 destination, u16 count);
u16 CALL initialize(void);
u16 CALL dispatch(void);
void CALL tick(void);
u16 CALL graphics_bank(u16 block);
void CALL raster_cell(const u16 *bits, u16 attribute, u16 position);
void CALL raster_cursor(u16 position, u16 lines);
u16 CALL raster_pixel(u16 x, u16 y, u16 color, u16 writing);
void CALL raster_read(u16 plane, u32 offset, u16 segment, u16 destination, u16 count);
#endif
#endif

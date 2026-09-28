/* Resident display ABI. All sizes are bytes unless explicitly named otherwise.
 */
#ifndef HHBIOS_SRC_VESA_H_
#define HHBIOS_SRC_VESA_H_
/* CALL entry points and shared data retain their assembly ABI names. Private
 * C helpers and types follow Google naming; DOS builds still use C89 and the
 * compiler's far-pointer extensions. */
typedef unsigned char u8;
typedef unsigned short u16;
#if defined(VESA_HOST) && !defined(__WATCOMC__) && !defined(__BORLANDC__)
typedef unsigned int u32;
#else
typedef unsigned long u32;
#endif

/* Logical text geometry is independent of the physical surface. */
#define TEXT_COLS 80
#define TEXT_ROWS 25
#define MAX_TEXT_ROWS 50
#define CELL_WIDTH 10
#define CELL_HEIGHT 23
#define GLYPH_HEIGHT 20
#define MAX_FONT_WIDTH 24
#define MAX_FONT_HEIGHT 64
#define FORMAT_PLANAR4 3

/* An 8086 MUL already yields the full 32-bit address without a CRT helper. */
#if defined(__WATCOMC__)
static u32 MultiplyWide(u16 a, u16 b);
#pragma aux MultiplyWide = "mul dx" parm[ax][dx] value[dx ax] modify[ax dx];
#else
#define MultiplyWide(a, b) ((u32)(a) * (b))
#endif

#pragma pack(push, 1)
struct VbeSurface {
  u16 width;
  u16 height;
  u16 pitch;
  u16 segment;
  u16 window_kb;
  u16 granularity_kb;
  u16 mode;
  u8 window;
  u8 format;
  u8 bpp;
  u8 planes;
  u8 red_size;
  u8 red_pos;
  u8 green_size;
  u8 green_pos;
  u8 blue_size;
  u8 blue_pos;
  u32 physical;
};
/* Same order as the 8086 entry pushes; also used for original BIOS calls. */
struct BiosRegisters {
  u16 ax;
  u16 bx;
  u16 cx;
  u16 dx;
  u16 si;
  u16 di;
  u16 bp;
  u16 ds;
  u16 es;
  u16 flags;
};
#pragma pack(pop)

int DecodeVbeModeInfo(struct VbeSurface* out, const u8* info, u16 version,
                      u16 mode);
int DecodeConsoleModeInfo(struct VbeSurface* out, const u8* info, u16 version,
                          u16 mode);

#ifndef VESA_HOST
#define FAR __far
#define CALL __cdecl
#define PTR(type, seg, off) ((type FAR*)(((u32)(seg) << 16) | (u16)(off)))
extern struct BiosRegisters CALL request;
extern struct VbeSurface CALL screen;
extern u16 CALL resident_segment;
extern u16 CALL keyboard_segment;
extern u16 CALL font_segment;
extern u16 CALL font_offset;
extern u16 CALL framebuffer;
extern u16 CALL display_pitch;
extern u16 CALL active_page;
extern u16 CALL resident_bytes;
extern u8 CALL banked_text;
extern u16 CALL display_start;
extern u16 CALL split_line;
extern u16 CALL text_bank;
extern u16 CALL requested_mode;
extern u16 CALL requested_rows;
extern u16 CALL viewport_x;
extern u16 CALL viewport_y;
extern u16 CALL pixel_scale;
extern u16 CALL bank_step;
extern u16 CALL raster_height;
extern u16 CALL text_rows;
extern u16 CALL text_cells;
extern u16 CALL page_bytes;
extern u16 CALL page_count;
extern u16 CALL logical_height;
extern u8 CALL last_row;
extern u8 CALL hardware_mode;
extern u8 CALL mouse_native;
extern u32 CALL plane_bytes;
extern u8 CALL large_surface;
extern u16 CALL mapped_block;
extern u8 CALL banked_text_allowed;
extern u8 CALL active;
extern u8 CALL busy;
extern u8 CALL policy;
extern u8 CALL hanzi;
extern u8 CALL traditional;
extern u16 CALL shadow[TEXT_COLS * MAX_TEXT_ROWS];
extern u16 CALL frame_alias_offset;
void CALL font_get(u16 code, u16* out);
void CALL font_seed(void);
u16 CALL font_open(void);
u16 CALL font_choose(u16 width, u16 height, u16 rows, u16 apply);
void CALL font_close(void);
u16 CALL font_text(u16 saving);
extern u16 CALL font_kind;
extern u16 CALL font_kb;
extern u16 CALL font_fault;
extern u16 CALL font_width;
extern u16 CALL font_height;
extern u16 CALL font_body_height;
extern u8 CALL font_extended;
extern char CALL font_name[64];
void CALL font_get_large(u16 code, u32* out);
void CALL font_draw(u16 code, u16 attribute, u16 position, u16 wide);
void CALL font_bitmap_draw(const u8* source, u16 attribute, u16 position);
void CALL bios(struct BiosRegisters* r);
void CALL refresh(void);
u16 CALL text_changed(void);
void CALL refresh_dirty(void);
u16 CALL text_ready(void);
void CALL scroll_pixels(u16 first, u16 last, u16 count, u16 down);
void CALL invalidate(void);
void CALL invalidate_prompt(void);
void CALL boundary(struct BiosRegisters* r);
u16 CALL aperture(void);
void CALL reprobe(void);
u16 CALL begin_draw(void);
void CALL end_draw(void);
void CALL draw(u16 code, u16 attribute, u16 position);
void CALL draw_wide(u16 code, u16 attribute, u16 position);
void CALL bitmap(u16 segment, u16 offset, u16 attribute, u16 position,
                 u16 count);
void CALL glyph(u16 code, u8* out);
void CALL cursor_xor(u16 position, u16 lines);
u16 CALL pixel(u16 x, u16 y, u16 color, u16 writing);
void CALL read_plane(u16 plane, u16 offset, u16 segment, u16 destination,
                     u16 count);
u16 CALL initialize(void);
u16 CALL dispatch(void);
void CALL tick(void);
u16 CALL graphics_bank(u16 block);
void CALL raster_cell(const u16* bits, u16 attribute, u16 position);
void CALL raster_large_cell(const u32* bits, u16 attribute, u16 position);
u16 CALL raster_scroll(u16 first, u16 last, u16 count, u16 down);
void CALL raster_cursor(u16 position, u16 lines);
u16 CALL raster_pixel(u16 x, u16 y, u16 color, u16 writing);
void CALL raster_read(u16 plane, u32 offset, u16 segment, u16 destination,
                      u16 count);
void CALL mouse_resume(void);
void CALL mouse_suspend(void);
u16 CALL mouse_prepare(u16 repaint);
u16 CALL mouse_erase(void);
void CALL mouse_poll(void);
void CALL mouse_paint(void);
u16 CALL mouse_covers(u16 position);
void CALL draw_half(const u16* bits, u16 attribute, u16 position);
#endif
#endif /* HHBIOS_SRC_VESA_H_ */

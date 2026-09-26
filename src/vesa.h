/* Resident display ABI. All sizes are bytes unless explicitly named otherwise. */
#ifndef HH_VESA_H
#define HH_VESA_H
typedef unsigned char u8;
typedef unsigned short u16;
#ifdef VESA_HOST
typedef unsigned int u32;
#else
typedef unsigned long u32;
#endif

/* The console remains 80x25. Pixel geometry is a separate contract. */
#define TEXT_COLS 80
#define TEXT_ROWS 25
#define CELL_HEIGHT 18
#define FORMAT_PLANAR4 3

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
extern u8 CALL banked_text_allowed;
extern u8 CALL active, busy, policy, hanzi, traditional;
extern u16 CALL shadow[TEXT_COLS*TEXT_ROWS];
extern u16 CALL frame_alias_offset;
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
#endif
#endif

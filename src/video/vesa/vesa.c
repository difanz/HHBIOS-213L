/* Independent HHBIOS console. Geometry and BIOS policy live here; the
 * interrupt boundary, existing classifier and planar stores live in vesa.asm.
 * No DOS calls, allocation or C runtime are used after installation. */
#include "vesa.h"

static u16 ReadLittleEndianWord(const u8* bytes) {
  return bytes[0] | ((u16)bytes[1] << 8);
}

int DecodeVbeModeInfo(struct VbeSurface* output, const u8* mode_info,
                      u16 version, u16 mode) {
  u16 attributes = ReadLittleEndianWord(mode_info), window,
      width = ReadLittleEndianWord(mode_info + 18),
      height = ReadLittleEndianWord(mode_info + 20);
  u16 minimum_pitch;
  u16 bytes_per_pixel;
  u16 channel;
  u16 previous_channel;
  u16 pitch;
  u16 win_size;
  u16 win_gran;
  int lfb;
  int have_window;
  const u8* masks = mode_info;
  /* VBE <1.2 may omit everything after BytesPerScanLine. Never infer
   * geometry from a vendor mode number or use VGA ports on non-VGA modes. */
  if ((attributes & 0x19) != 0x19 || (version < 0x102 && !(attributes & 2))) {
    return 0;
  }
  if (!width || !height) {
    return 0;
  }
  lfb = version >= 0x200 && (attributes & 128);
  if (mode_info[27] == FORMAT_PLANAR4) {
    if (mode_info[24] != 4 || mode_info[25] != 4) {
      return 0;
    }
    minimum_pitch = width / 8 + (width % 8 != 0);
  } else {
    if (mode_info[24] != 1 ||
        (mode_info[27] != FORMAT_PACKED8 && mode_info[27] != FORMAT_DIRECT)) {
      return 0;
    }
    if (mode_info[27] == FORMAT_PACKED8 && mode_info[25] != 8) {
      return 0;
    }
    if (mode_info[27] == FORMAT_DIRECT && mode_info[25] != 15 &&
        mode_info[25] != 16 && mode_info[25] != 24 && mode_info[25] != 32) {
      return 0;
    }
    bytes_per_pixel = (mode_info[25] + 7) / 8;
    if (width > 65535U / bytes_per_pixel) {
      return 0;
    }
    minimum_pitch = width * bytes_per_pixel;
    if (mode_info[27] == FORMAT_DIRECT) {
      if (version < 0x102) {
        return 0;
      }
      /* VBE 3 may publish a different mask layout for the linear map. */
      masks = mode_info + 31;
      if (version >= 0x300 && lfb && mode_info[0x36]) {
        masks = mode_info + 0x36;
      }
      for (channel = 0; channel < 6; channel += 2) {
        if (!masks[channel] || masks[channel] > 8 ||
            masks[channel + 1] >= mode_info[25] ||
            masks[channel] + masks[channel + 1] > mode_info[25]) {
          return 0;
        }
        for (previous_channel = 0; previous_channel < channel;
             previous_channel += 2) {
          if (masks[channel + 1] <
                  masks[previous_channel + 1] + masks[previous_channel] &&
              masks[previous_channel + 1] <
                  masks[channel + 1] + masks[channel]) {
            return 0;
          }
        }
      }
    }
  }
  pitch = ReadLittleEndianWord(mode_info + 16);
  if (version >= 0x300 && lfb && ReadLittleEndianWord(mode_info + 0x32)) {
    pitch = ReadLittleEndianWord(mode_info + 0x32);
  }
  win_size = ReadLittleEndianWord(mode_info + 6);
  win_gran = ReadLittleEndianWord(mode_info + 4);
  if (pitch < minimum_pitch) {
    return 0;
  }
  window = (mode_info[2] & 6) == 6 ? 0 : ((mode_info[3] & 6) == 6 ? 1 : 2);
  have_window = window < 2 && ReadLittleEndianWord(mode_info + 8 + 2 * window);
  if (have_window) {
    if (!win_size || win_size > 64 || !win_gran || win_gran > win_size) {
      return 0;
    }
  } else if (!lfb || win_size > 64 || (win_size && win_gran > win_size)) {
    /* A missing window is acceptable only when the linear map is advertised. */
    return 0;
  }
  output->width = width;
  output->height = height;
  output->pitch = pitch;
  output->segment =
      have_window ? ReadLittleEndianWord(mode_info + 8 + 2 * window) : 0;
  output->window_kb = win_size;
  output->granularity_kb = win_gran;
  output->mode = mode;
  output->window = have_window ? (u8)window : 2;
  output->format = mode_info[27];
  output->bpp = mode_info[25];
  output->planes = mode_info[24];
  output->red_size = output->red_pos = output->green_size = output->green_pos =
      0;
  output->blue_size = output->blue_pos = 0;
  output->physical = 0;
  if (mode_info[27] == FORMAT_DIRECT) {
    masks = mode_info + 31;
    if (version >= 0x300 && lfb && mode_info[0x36]) {
      masks = mode_info + 0x36;
    }
    output->red_size = masks[0];
    output->red_pos = masks[1];
    output->green_size = masks[2];
    output->green_pos = masks[3];
    output->blue_size = masks[4];
    output->blue_pos = masks[5];
  }
  if (lfb) {
    output->physical = ReadLittleEndianWord(mode_info + 40) |
                       ((u32)ReadLittleEndianWord(mode_info + 42) << 16);
  }
  return 1;
}

static int PlanarConsole(const struct VbeSurface* surface, const u8* mode_info) {
  /* The banked rasterizer admits 64 KiB VGA windows with integral bank steps. */
  return !(ReadLittleEndianWord(mode_info) & 0x60) && surface->width >= 800 &&
         surface->height >= 600 && surface->width <= 4096 &&
         surface->height <= 2160 && surface->pitch && surface->pitch <= 512 &&
         !(surface->pitch & 1) && surface->format == FORMAT_PLANAR4 &&
         surface->window < 2 && surface->segment == 0xa000 &&
         surface->window_kb == 64 && surface->granularity_kb &&
         surface->granularity_kb <= 64 &&
         !(64 % surface->granularity_kb);
}

static int LinearConsole(const struct VbeSurface* surface) {
  u16 pixel_bytes = surface->bpp == 32 ? 4 : 2;
  /* 24 bpp stays out of scope: a 3-byte pixel makes odd pitches and
   * unaligned scanlines expensive for a cell writer. 8-bit packed is decoded
   * but has no console rasterizer. */
  if (surface->format != FORMAT_DIRECT || !surface->physical) {
    return 0;
  }
  if (surface->bpp != 15 && surface->bpp != 16 && surface->bpp != 32) {
    return 0;
  }
  if (surface->width < 800 || surface->height < 600 || surface->width > 4096 ||
      surface->height > 2160) {
    return 0;
  }
  if (surface->width > 65535U / pixel_bytes) {
    return 0;
  }
  return surface->pitch >= surface->width * pixel_bytes &&
         surface->pitch <= 16384 && !(surface->pitch & 1);
}

/* Same geometry as the linear console, drawn through a 64 KiB window
 * when PhysBasePtr is missing or protected mode is already on. */
static int BankDirectConsole(const struct VbeSurface* surface) {
  u16 pixel_bytes = surface->bpp == 32 ? 4 : 2;
  if (surface->format != FORMAT_DIRECT) {
    return 0;
  }
  if (surface->bpp != 15 && surface->bpp != 16 && surface->bpp != 32) {
    return 0;
  }
  if (surface->window >= 2 || surface->segment != 0xa000 ||
      surface->window_kb != 64 || !surface->granularity_kb ||
      surface->granularity_kb > 64 || (64 % surface->granularity_kb)) {
    return 0;
  }
  if (surface->width < 800 || surface->height < 600 || surface->width > 4096 ||
      surface->height > 2160 || surface->width > 65535U / pixel_bytes) {
    return 0;
  }
  return surface->pitch >= surface->width * pixel_bytes &&
         surface->pitch <= 16384 && !(surface->pitch & 1);
}

static int DirectConsole(const struct VbeSurface* surface) {
  return LinearConsole(surface) || BankDirectConsole(surface);
}

int DecodeConsoleModeInfo(struct VbeSurface* output, const u8* mode_info,
                          u16 version, u16 mode) {
  struct VbeSurface decoded;
  /* Keep the application-visible text grid independent of planar pixels.
   * Direct color needs either PhysBasePtr or a 64 KiB bank window. */
  if (!DecodeVbeModeInfo(&decoded, mode_info, version, mode) ||
      (!PlanarConsole(&decoded, mode_info) && !DirectConsole(&decoded))) {
    return 0;
  }
  *output = decoded;
  return 1;
}

#ifndef VESA_HOST
#pragma code_seg("_TEXT", "CODE")
struct BiosRegisters CALL request;
struct VbeSurface CALL screen;
u16 CALL resident_segment;
u16 CALL keyboard_segment;
u16 CALL font_segment;
u16 CALL font_offset;
u16 CALL framebuffer = 0xa000;
u16 CALL display_pitch = 100;
u16 CALL active_page;
u16 CALL resident_bytes;
u16 CALL display_start;
u16 CALL split_line;
u16 CALL text_bank;
u16 CALL requested_mode = 0x102;
u16 CALL requested_rows = 25;
u16 CALL viewport_x;
u16 CALL viewport_y;
u16 CALL pixel_scale = 1;
u16 CALL bank_step = 1;
u16 CALL raster_height = CELL_HEIGHT;
u16 CALL text_rows = 25;
u16 CALL text_cells = 2000;
u16 CALL page_bytes = 4096;
u16 CALL page_count = 8;
u16 CALL logical_height = 16;
u8 CALL last_row = 24;
u8 CALL hardware_mode;
static u16 scan_lines = 400;
static u16 vbe_version;
static struct VbeSurface preferred;
u32 CALL plane_bytes = 60000UL;
u8 CALL large_surface;
u8 CALL linear_color;
u8 CALL mode_selected;
u8 CALL banked_text_allowed;
u8 CALL active;
u8 CALL busy;
u8 CALL traditional = 1;
u8 CALL direct = 1;
static u8 vbe_mode;
static u8 allow_mode = 1;
static u8 logical_mode = 3;
static u8 translate_text = 1;
static u8 native_mode = 0xff;
static u8 counter;
static u8 period = 2;
static u8 cursor_on = 1;
static u8 cursor_visible;
static u8 blink = 1;
static u16 cursor_position;
static u16 cursor_shape = 0x0d0e;
static u16 prompt[80];
enum StatusCellKind {
  kStatusInvalid,
  kStatusCharacter,
  kStatusLead,
  kStatusTrail,
  kStatusBitmap
};
/* Retain what is on screen, including Hanzi pairing. Replacing one byte can
 * change the interpretation of its neighbours without changing their bytes. */
static u16 prompt_shown[80];
static u8 prompt_kind[80];
/* AH=14h bitmaps are caller-owned: retain their pixels, never their pointer. */
static u8 prompt_bits[80][16];
static u8 prompt_bitmap[10];
static u8 prompt_open;
static u8 prompt_frame_open = 0xff;
static u8 prompt_col;
static u8 prompt_dirty;
static u8 prompt_attr = 0x70;
/* Eight ten-column controls. A zero width means ordinary status text. */
static u8 prompt_panel_width[8];
static u8 prompt_panel_style[8];
static u8 prompt_panel_dirty;
u8 CALL prompt_notify;
static void DrawStatusBar(void);

static void ClearBytes(void* buffer, u16 byte_count) {
  u8* bytes = buffer;
  while (byte_count--) {
    *bytes++ = 0;
  }
}

void CALL invalidate_prompt(void) {
  /* Redraw on the next status request; do not erase an application's direct
   * graphics or wide string merely because a timer interrupt occurred. */
  ClearBytes(prompt_kind, sizeof(prompt_kind));
  prompt_frame_open = 0xff;
}
static void CallVideoBios(u16 ax, u16 bx, u16 cx, u16 dx) {
  struct BiosRegisters bios_registers;
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.ax = ax;
  bios_registers.bx = bx;
  bios_registers.cx = cx;
  bios_registers.dx = dx;
  bios(&bios_registers);
}
static u8 ReadBdaByte(u16 offset) {
  return *PTR(u8, 0x40, offset);
}
static u16 ReadBdaWord(u16 offset) {
  return *PTR(u16, 0x40, offset);
}
static void WriteBdaByte(u16 offset, u8 value) {
  *PTR(u8, 0x40, offset) = value;
}
static void WriteBdaWord(u16 offset, u16 value) {
  *PTR(u16, 0x40, offset) = value;
}
static u16 FAR* TextPage(u16 page_number) {
  return PTR(u16, 0xb800, page_number * page_bytes);
}
static u16 CursorPosition(u16 page_number) {
  return ReadBdaWord(0x50 + (page_number & 7) * 2);
}
static u16 TextCellIndex(u16 text_position) {
  return (text_position >> 8) * TEXT_COLS + (text_position & 255);
}
static int IsTextPosition(u16 text_position) {
  return (text_position >> 8) < text_rows && (text_position & 255) < TEXT_COLS;
}

static void UpdateKeyboardState(void) {
  if (keyboard_segment) {
    *PTR(u8, keyboard_segment, 0x100) = 0x12;
    *PTR(u8, keyboard_segment, 0x101) = active ? 0x12 : native_mode;
    *PTR(u8, keyboard_segment, 0x102) = direct;
  }
}
static void HideCursor(void) {
  if (active && cursor_visible) {
    u16 lines = (cursor_shape & 31) - (cursor_shape >> 8 & 31) + 1;
    lines = (lines * 16 + logical_height - 1) / logical_height;
    if (large_surface) {
      raster_cursor(cursor_position, lines);
    } else {
      cursor_xor(cursor_position, lines);
    }
  }
  cursor_visible = 0;
}
static void ShowCursor(void) {
  if (cursor_visible) {
    return;
  }
  cursor_position = CursorPosition(active_page);
  if (active && cursor_on && !(cursor_shape & 0x2000) &&
      IsTextPosition(cursor_position) && !mouse_covers(cursor_position)) {
    u16 lines = (cursor_shape & 31) - (cursor_shape >> 8 & 31) + 1;
    lines = (lines * 16 + logical_height - 1) / logical_height;
    if (large_surface) {
      raster_cursor(cursor_position, lines);
    } else {
      cursor_xor(cursor_position, lines);
    }
    cursor_visible = active;
  }
}
static void MoveCursor(u16 page, u16 position) {
  WriteBdaWord(0x50 + (page & 7) * 2, position);
  if (page != active_page || (cursor_visible && cursor_position == position)) {
    return;
  }
  if (!cursor_visible &&
      (!cursor_on || (cursor_shape & 0x2000) || !IsTextPosition(position) ||
       mouse_covers(position))) {
    return;
  }
  /* Erase and draw under one graphics mapping. The BDA update must survive
   * even when the adapter rejects that mapping and disables rendering. */
  if (begin_draw()) {
    HideCursor();
    ShowCursor();
    end_draw();
  }
}
static void RefreshConsole(u16 show_cursor) {
  u16 changed;
  if (!active || !text_ready()) {
    return;
  }
  mouse_poll();
  changed = text_changed();
  /* Mouse erasure reads the text aperture. Finish those reads before a
   * changed frame keeps the graphics window mapped for cursor and text. */
  if (mouse_prepare(changed)) {
    changed = 1;
  }
  if (changed && !begin_draw()) {
    return;
  }
  /* Sparse dirt stays on the bank window. A line or more uses the linear
   * painter while PE is clear. Scroll clears the choice on its own entry. */
  if (linear_color && (changed || prompt_dirty || show_cursor)) {
    choose_bank_paint();
  }
  if (cursor_visible &&
      (changed || !show_cursor || !cursor_on || (cursor_shape & 0x2000) ||
       cursor_position != CursorPosition(active_page) ||
       mouse_covers(cursor_position))) {
    HideCursor();
  }
  if (changed) {
    /* Mouse erasure can dirty the text row beneath a retained caret. */
    HideCursor();
    /* Spaces share a background. Fill each dirty run once, then let the
     * glyph path repaint only the cells that still differ. */
    if (linear_color) {
      linear_paint_spaces();
    }
    refresh_dirty();
  }
  if (prompt_dirty) {
    DrawStatusBar();
  }
  if (show_cursor) {
    ShowCursor();
  }
  if (changed) {
    end_draw();
  }
  mouse_paint();
  bank_paint = 0;
}
static void RepaintConsole(void) {
  RefreshConsole(1);
}
static u8 SuspendConsole(void) {
  u8 previous;
  /* Called before a BIOS mode set, when the old aperture is still valid. */
  HideCursor();
  if (mouse_erase() && active) {
    refresh();
  }
  mouse_suspend();
  previous = active;
  active = 0;
  UpdateKeyboardState();
  /* A failed cursor bank access must remain disabled on BIOS failure. */
  return previous;
}

static int ActivateConsole(u16 preserve) {
  struct BiosRegisters bios_registers;
  u16 i;
  ClearBytes(&bios_registers, sizeof(bios_registers));
  if (vbe_mode) {
    bios_registers.ax = 0x4f02;
    bios_registers.bx = screen.mode | (preserve ? 0x8000 : 0);
    /* Bit 14 selects the linear map. A bank-only direct mode has no
     * PhysBasePtr and must still install through the window. */
    if (linear_color && screen.physical) {
      bios_registers.bx |= 0x4000;
    }
  } else {
    bios_registers.ax = preserve ? 0x92 : 0x12;
  }
  bios(&bios_registers);
  if (vbe_mode && bios_registers.ax != 0x004f) {
    return 0;
  }
  native_mode = 0xff;
  hardware_mode = ReadBdaByte(0x49);
  /* Start at graphics bank zero. The aperture probe isolates B800 text
   * from every bank occupied by the visible plane. An LFB-only mode has
   * no window; its text probe uses B800 directly. */
  if (screen.window < 2) {
    ClearBytes(&bios_registers, sizeof(bios_registers));
    bios_registers.ax = 0x4f05;
    bios_registers.bx = screen.window;
    bios(&bios_registers);
    if (bios_registers.ax != 0x004f && !linear_color) {
      return 0;
    }
  }
  display_pitch = screen.pitch;
  /* Enable A20 before the alias scan reads the linear map. */
  if (linear_color) {
    linear_prepare();
  }
  if (!aperture()) {
    return 0;
  }
  font_seed();
  active_page = 0;
  if (!preserve) {
    for (i = 0; i < text_cells; ++i) {
      TextPage(0)[i] = 0x0720;
    }
    for (i = 0; i < 8; ++i) {
      WriteBdaWord(0x50 + 2 * i, 0);
    }
  }
  WriteBdaByte(0x49, logical_mode);
  WriteBdaWord(0x4a, TEXT_COLS);
  WriteBdaWord(0x4c, page_bytes);
  WriteBdaWord(0x4e, 0);
  WriteBdaByte(0x62, 0);
  WriteBdaByte(0x84, last_row);
  WriteBdaWord(0x85, logical_height);
  WriteBdaByte(0x89, (ReadBdaByte(0x89) & 0x6f) | (scan_lines == 200   ? 0x80
                                                   : scan_lines == 400 ? 0x10
                                                                       : 0));
  WriteBdaByte(0x88, (ReadBdaByte(0x88) & 0xf0) | (scan_lines == 200 ? 8 : 9));
  WriteBdaWord(0x60, cursor_shape);
  active = 1;
  cursor_visible = 0;
  prompt_dirty = 1;
  /* CKBD must enter through INT 10h after we release the resident stack. */
  if (!prompt_open && keyboard_segment &&
      (*PTR(u8, keyboard_segment, 0xf4) & 2)) {
    prompt_notify = 1;
  }
  if (resident_bytes) {
    mouse_resume();
  }
  UpdateKeyboardState();
  invalidate();
  /* The first install still has resident_bytes == 0 and is using the text
   * shadow as its stack. Paint only after that handoff. */
  if (resident_bytes) {
    RepaintConsole();
  }
  return 1;
}

void CALL install_paint(void) {
  if (active) {
    RepaintConsole();
  }
}

static void SetTextGeometry(u16 rows, u16 height) {
  font_choose(screen.width, screen.height, rows, 1);
  text_rows = rows;
  last_row = (u8)(rows - 1);
  text_cells = 80 * rows;
  logical_height = height;
  page_bytes = rows > 25 ? 8192 : 4096;
  page_count = banked_text ? 32768U / page_bytes : 1;
  large_surface = (u8)(font_extended || rows != 25 || screen.width != 800 ||
                       screen.height != 600 || screen.pitch != 100);
  plane_bytes = MultiplyWide(screen.pitch, screen.height);
  viewport_x = (screen.width - TEXT_COLS * font_width * pixel_scale) / 2;
  viewport_y =
      large_surface
          ? (screen.height - raster_height * (rows + 1) * pixel_scale) / 2
          : 0;
  bank_step = screen.granularity_kb && !(64 % screen.granularity_kb)
                  ? (u16)(64 / screen.granularity_kb)
                  : 1;
  text_bank = (u16)((plane_bytes + 65535UL) >> 16) * bank_step;
}

static int IsSavedSurfaceValid(const struct VbeSurface* saved, u16 rows) {
  if (!font_choose(saved->width, saved->height, rows, 0)) {
    return 0;
  }
  if (DirectConsole(saved)) {
    return 1;
  }
  return saved->width >= 800 && saved->width <= 4096 && saved->height >= 600 &&
         saved->height <= 2160 && saved->pitch >= (saved->width + 7) / 8 &&
         saved->pitch <= 512 && !(saved->pitch & 1) && saved->segment == 0xa000 &&
         saved->window_kb == 64 && saved->granularity_kb &&
         saved->granularity_kb <= 64 && !(64 % saved->granularity_kb) &&
         saved->window < 2 && saved->format == FORMAT_PLANAR4 &&
         saved->bpp == 4 && saved->planes == 4;
}

static void UseSurface(const struct VbeSurface* saved) {
  screen = *saved;
  linear_color = (u8)DirectConsole(saved);
}

static u8 WindowCanBank(const struct VbeSurface* saved) {
  return saved->window < 2 && saved->segment == 0xa000 &&
         saved->window_kb == 64 && saved->granularity_kb &&
         saved->granularity_kb <= 64 && !(64 % saved->granularity_kb);
}

static void CommitDirect(u16 far_off, u16 far_seg) {
  u16 bank = WindowCanBank(&screen);
  u16 lfb = (u16)(screen.physical != 0);
  if (!bank) {
    far_off = 0;
    far_seg = 0;
  }
  note_direct_window(far_off, far_seg, bank, lfb);
}

static u8 ReadPortByte(u16 port);
#pragma aux ReadPortByte = "in al,dx" parm[dx] value[al];
static void WritePortByte(u16 port, u8 value);
#pragma aux WritePortByte = "out dx,al" parm[dx][al];

/* Native state restore is still responsible for the caller's opaque buffer.
 * Re-establish our owned surface through the mode API afterwards: some BIOSes
 * restore VGA registers but lose extended timing or mode bookkeeping. Preserve
 * the resulting BIOS data and palette, including components not requested by
 * the caller's mask. Only our validated console records take this path. */
static int RestoreSurface(void) {
  u8 bda[37];
  u8 colors[768];
  u8 attributes[21];
  u8 mask;
  u8 TextCellIndex;
  u8 dac_index;
  u16 i;
  struct BiosRegisters bios_registers;
  for (i = 0; i < 30; ++i) {
    bda[i] = ReadBdaByte(0x49 + i);
  }
  for (i = 0; i < 7; ++i) {
    bda[30 + i] = ReadBdaByte(0x84 + i);
  }
  TextCellIndex = ReadPortByte(0x3c0);
  mask = ReadPortByte(0x3c6);
  dac_index = ReadPortByte(0x3c8);
  for (i = 0; i < 21; ++i) {
    ReadPortByte(0x3da);
    WritePortByte(0x3c0, (u8)i);
    attributes[i] = ReadPortByte(0x3c1);
  }
  ReadPortByte(0x3da);
  WritePortByte(0x3c0, TextCellIndex);
  WritePortByte(0x3c7, 0);
  for (i = 0; i < 768; ++i) {
    colors[i] = ReadPortByte(0x3c9);
  }
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.ax = 0x4f02;
  bios_registers.bx = screen.mode | 0x8000;
  if (linear_color && screen.physical) {
    bios_registers.bx |= 0x4000;
  }
  bios(&bios_registers);
  for (i = 0; i < 30; ++i) {
    WriteBdaByte(0x49 + i, bda[i]);
  }
  for (i = 0; i < 7; ++i) {
    WriteBdaByte(0x84 + i, bda[30 + i]);
  }
  WritePortByte(0x3c8, 0);
  for (i = 0; i < 768; ++i) {
    WritePortByte(0x3c9, colors[i]);
  }
  WritePortByte(0x3c6, mask);
  WritePortByte(0x3c8, dac_index);
  for (i = 0; i < 21; ++i) {
    ReadPortByte(0x3da);
    WritePortByte(0x3c0, (u8)i);
    WritePortByte(0x3c0, attributes[i]);
  }
  ReadPortByte(0x3da);
  WritePortByte(0x3c0, TextCellIndex);
  display_pitch = screen.pitch;
  return bios_registers.ax == 0x004f;
}

/* A ROM-font change is a logical text operation. Keep text bytes intact even
 * when the physical surface must grow to retain complete native glyphs. */
static int SetTextRows(u16 rows, u16 height, u16 preserve) {
  struct VbeSurface candidate = preferred, previous = screen;
  struct BiosRegisters bios_registers;
  u8 info[256];
  u8 was_active = active;
  u16 old_rows = text_rows;
  u16 old_height = logical_height;
  u16 old_page = active_page;
  u16 i;
  u16 cursors[8];
  if (!rows || rows > MAX_TEXT_ROWS || (!banked_text && rows != 25)) {
    return 0;
  }
  if (!font_choose(candidate.width, candidate.height, rows, 0)) {
    for (i = 0; i < 2; ++i) {
      ClearBytes(&bios_registers, sizeof(bios_registers));
      ClearBytes(info, sizeof(info));
      bios_registers.ax = 0x4f01;
      bios_registers.cx = i ? 0x106 : 0x104;
      bios_registers.es = resident_segment;
      bios_registers.di = (u16)info;
      bios(&bios_registers);
      if (bios_registers.ax == 0x004f && info[29] &&
          DecodeConsoleModeInfo(&candidate, info, vbe_version,
                                bios_registers.cx) &&
          (info[2 + candidate.window] & 1) &&
          font_choose(candidate.width, candidate.height, rows, 0)) {
        break;
      }
    }
    if (i == 2) {
      return 0;
    }
  }
  SuspendConsole();
  for (i = 0; i < 8; ++i) {
    cursors[i] = CursorPosition(i);
  }
  if (preserve && !font_text(1)) {
    active = was_active;
    UpdateKeyboardState();
    if (active) {
      mouse_resume();
      RepaintConsole();
    }
    return 0;
  }
  UseSurface(&candidate);
  SetTextGeometry(rows, height);
  reprobe();
  if (!ActivateConsole(1)) {
    UseSurface(&previous);
    SetTextGeometry(old_rows, old_height);
    reprobe();
    if (!ActivateConsole(1)) {
      active = 0;
      UpdateKeyboardState();
      return 0;
    }
  }
  active = 0;
  if (preserve) {
    if (!font_text(0)) {
      UpdateKeyboardState();
      return 0;
    }
  } else {
    for (i = 0; i < text_cells; ++i) {
      TextPage(0)[i] = 0x0720;
    }
  }
  for (i = 0; i < 8; ++i) {
    WriteBdaWord(0x50 + i * 2,
                 preserve && IsTextPosition(cursors[i]) ? cursors[i] : 0);
  }
  active_page = preserve && old_page < page_count ? old_page : 0;
  cursor_shape = ((logical_height - 2) << 8) | (logical_height - 1);
  WriteBdaWord(0x60, cursor_shape);
  WriteBdaByte(0x62, (u8)active_page);
  WriteBdaWord(0x4e, active_page * page_bytes);
  active = 1;
  UpdateKeyboardState();
  invalidate();
  RepaintConsole();
  return text_rows == rows;
}

#pragma code_seg("INIT_TEXT", "INIT")
u16 CALL initialize(void) {
  struct BiosRegisters bios_registers;
  u8 controller[256];
  u8 mode_info[256];
  u16 version;
  u16 modes_seg;
  u16 modes_off;
  u16 n;
  u16 number;
  u16 previous_mode;
  u16 font_missing = 0;
  struct VbeSurface best_linear;
  u32 best_score = 0xffffffffUL;
  u8 have_linear = 0;
  u16 best_far_off = 0;
  u16 best_far_seg = 0;
  if (keyboard_segment) {
    prompt_attr = *PTR(u8, keyboard_segment, 0x10a);
  }
  ClearBytes(controller, sizeof(controller));
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.ax = 0x4f00;
  bios_registers.es = resident_segment;
  bios_registers.di = (u16)controller;
  bios(&bios_registers);
  if (bios_registers.ax != 0x004f || controller[0] != 'V' ||
      controller[1] != 'E' || controller[2] != 'S' || controller[3] != 'A' ||
      (controller[10] & 2)) {
    return 1;
  }
  version = ReadLittleEndianWord(controller + 4);
  vbe_version = version;
  if (version < 0x100) {
    return 1;
  }
  modes_off = ReadLittleEndianWord(controller + 14);
  modes_seg = ReadLittleEndianWord(controller + 16);
  /* An explicit /M selects one mode. Otherwise prefer a planar mode,
   * trying 102h before the advertised list. Direct-color linear modes are
   * the fallback when the BIOS has no planar console mode; 16 bpp ranks
   * ahead of 15 bpp and 32 bpp, then the smaller surface. */
  linear_color = 0;
  for (n = 0; n < 257; ++n) {
    if (!n) {
      number = requested_mode;
    } else {
      if (mode_selected) {
        break;
      }
      if (modes_off > 0xfffd || (!modes_seg && !modes_off)) {
        break;
      }
      number = *PTR(u16, modes_seg, modes_off);
      modes_off += 2;
      if (number == 0xffff) {
        break;
      }
    }
    ClearBytes(mode_info, sizeof(mode_info));
    ClearBytes(&bios_registers, sizeof(bios_registers));
    bios_registers.ax = 0x4f01;
    bios_registers.cx = number;
    bios_registers.es = resident_segment;
    bios_registers.di = (u16)mode_info;
    bios(&bios_registers);
    if (bios_registers.ax == 0x004f &&
        DecodeConsoleModeInfo(&screen, mode_info, version, number)) {
      if (screen.format == FORMAT_PLANAR4) {
        banked_text_allowed =
            (u8)(version >= 0x102 && mode_info[29] > 0 && screen.window < 2 &&
                 (mode_info[2 + screen.window] & 1) && WindowCanBank(&screen));
        if (font_open()) {
          vbe_mode = 1;
          linear_color = 0;
          note_direct_window(0, 0, 0, 0);
          break;
        }
        font_missing = 1;
      } else if (mode_selected) {
        banked_text_allowed = WindowCanBank(&screen);
        linear_color = 1;
        if (font_open()) {
          vbe_mode = 1;
          CommitDirect(ReadLittleEndianWord(mode_info + 12),
                       ReadLittleEndianWord(mode_info + 14));
          break;
        }
        font_missing = 1;
        linear_color = 0;
      } else {
        /* 16 bpp, then 15, then 32; smaller area wins inside a depth. */
        u32 score = MultiplyWide(screen.width, screen.height);
        if (screen.bpp == 15) {
          score += 100000000UL;
        } else if (screen.bpp == 32) {
          score += 200000000UL;
        }
        if (!have_linear || score < best_score) {
          best_linear = screen;
          best_score = score;
          best_far_off = ReadLittleEndianWord(mode_info + 12);
          best_far_seg = ReadLittleEndianWord(mode_info + 14);
          have_linear = 1;
        }
      }
    }
  }
  if (!vbe_mode && have_linear) {
    UseSurface(&best_linear);
    banked_text_allowed = WindowCanBank(&screen);
    if (!font_open()) {
      return 4;
    }
    vbe_mode = 1;
    CommitDirect(best_far_off, best_far_seg);
  }
  if (!vbe_mode) {
    return font_missing ? 4 : 1;
  }
  preferred = screen;
  banked_text = linear_color ? 0 : banked_text_allowed;
  scan_lines = requested_rows == 43 ? 350 : 400;
  SetTextGeometry(requested_rows, requested_rows == 25 ? 16 : 8);
  if (requested_rows > 25) {
    cursor_shape = 0x0607;
  }
  if (large_surface && !banked_text_allowed && !linear_color) {
    return 1;
  }
  /* Put all eight logical text pages in spare VRAM where available. This
   * also avoids page 1..7 aliasing visible pixels on 64 KiB VGA mappings.
   * Linear modes start without that bank; the aperture probe may claim it. */
  page_count = banked_text ? 32768U / page_bytes : 1;
  /* On a 64 KiB aliasing aperture, reserve B800's first 4 KiB and place
   * scanout across a line-aligned wrap. The CPU start must be paragraph
   * aligned too. Geometry is kept out of the character classifier. */
  if (linear_color) {
    display_start = 0;
    split_line = 0;
  } else if (!banked_text) {
    n = (screen.pitch * screen.height - 0x8000U + screen.pitch - 1) /
        screen.pitch;
    while ((n * screen.pitch) & 15) {
      ++n;
    }
    display_start = 0U - n * screen.pitch;
    split_line = n - 1;
  }
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.ax = 0x1130;
  bios_registers.bx = 0x0600;
  bios(&bios_registers);
  font_segment = bios_registers.es;
  font_offset = bios_registers.bp;
  if (!font_segment) {
    return 2;
  }
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.ax = 0x0f00;
  bios(&bios_registers);
  previous_mode = bios_registers.ax & 127;
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.ax = 0x4f03;
  bios(&bios_registers);
  if (bios_registers.ax == 0x004f) {
    previous_mode = bios_registers.bx & 0x7fff;
  }
  if (ActivateConsole(0)) {
    return 0;
  }
  /* Nothing has been hooked yet. A failed bank/aperture probe must not
   * strand the caller in a partially configured graphics mode. */
  active = 0;
  UpdateKeyboardState();
  ClearBytes(&bios_registers, sizeof(bios_registers));
  if (previous_mode >= 0x100) {
    bios_registers.ax = 0x4f02;
    bios_registers.bx = previous_mode;
  } else {
    bios_registers.ax = previous_mode;
  }
  bios(&bios_registers);
  return 3;
}
#pragma code_seg("_TEXT", "CODE")

static void ScrollText(u16 page_number, u8 down, u16 count, u16 attribute,
                       u16 top, u16 bottom) {
  u16 x;
  u16 y;
  u16 left = top & 255;
  u16 right = bottom & 255;
  u16 first = top >> 8;
  u16 last = bottom >> 8;
  u16 copied = 0;
  u16 FAR* text = TextPage(page_number);
  if (left >= 80 || first >= text_rows || left > right || first > last) {
    return;
  }
  if (right > 79) {
    right = 79;
  }
  if (last >= text_rows) {
    last = text_rows - 1;
  }
  if (!count || count > last - first + 1) {
    count = last - first + 1;
  }
  /* Full-width scrolls move pixels, keeping the shadow paired with them;
   * pending direct B800 writes are still detected by the next refresh. */
  if (active && page_number == active_page && !left && right == 79 &&
      count <= last - first) {
    HideCursor();
    if (mouse_erase()) {
      refresh();
    }
    if (large_surface) {
      copied = raster_scroll(first, last, count, down);
    } else {
      scroll_pixels(first, last, count, down);
      copied = active;
    }
  }
  if (!left && right == TEXT_COLS - 1) {
    u16 source = (first + (down ? 0 : count)) * TEXT_COLS;
    u16 destination = (first + (down ? count : 0)) * TEXT_COLS;
    u16 cleared = (down ? first : last + 1 - count) * TEXT_COLS;
    u16 value = (attribute << 8) | 32;
    move_cells(text, destination, source,
                (last - first + 1 - count) * TEXT_COLS);
    fill_cells(text + cleared, value, count * TEXT_COLS);
    if (copied) {
      fill_cells(PTR(u16, resident_segment, (u16)(shadow + cleared)),
                  ~value, count * TEXT_COLS);
    }
    return;
  }
  for (y = 0; y <= last - first; ++y) {
    u16 row = down ? last - y : first + y;
    for (x = left; x <= right; ++x) {
      u16 value = (attribute << 8) | 32;
      if (down ? row >= first + count : row + count <= last) {
        value = text[(down ? row - count : row + count) * 80 + x];
      }
      text[row * 80 + x] = value;
    }
  }
}

static void WriteTeletype(u8 character, u16 page_number) {
  u16 pos = CursorPosition(page_number), col = pos & 255, row = pos >> 8;
  u16 FAR* text = TextPage(page_number);
  if (row >= text_rows || col >= 80) {
    return;
  }
  if (character == 7) {
    CallVideoBios(0x0e07, 0, 0, 0);
    return;
  }
  if (character == 8) {
    if (col) {
      --col;
    }
  } else if (character == 13) {
    col = 0;
  } else if (character == 10) {
    ++row;
  } else {
    text[row * 80 + col] = (text[row * 80 + col] & 0xff00) | character;
    if (++col == 80) {
      col = 0;
      ++row;
    }
  }
  if (row == text_rows) {
    ScrollText(page_number, 0, 1, text[(text_rows - 1) * 80] >> 8, 0,
               (last_row << 8) | 79);
    --row;
  }
  WriteBdaWord(0x50 + (page_number & 7) * 2, (row << 8) | col);
}

/* The VBE hardware-state buffer remains BIOS-owned. Append one 64-byte
 * private record, advertised by the size query; never enlarge the BIOS part. */
static void TransferVideoState(void) {
  struct BiosRegisters size;
  struct VbeSurface saved;
  u16 action = request.dx & 255;
  u16 flags = request.cx;
  u16 offset;
  u16 i;
  u8 was_active = active;
  u8 was_cursor = cursor_visible;
  u8 FAR* record;
  size = request;
  size.dx &= 0xff00;
  bios(&size);
  if (size.ax != 0x004f) {
    request.ax = size.ax;
    return;
  }
  if (size.bx >= 1023) {
    request.ax = 0x014f;
    return;
  }
  if (!action) {
    request.ax = size.ax;
    request.bx = size.bx + 1;
    return;
  }
  if (action > 2 || request.bx > 65535U - (size.bx + 1) * 64U) {
    request.ax = 0x014f;
    return;
  }
  offset = request.bx + size.bx * 64;
  record = PTR(u8, request.es, offset);
  /* The software cursor is part of pixel memory, not BIOS state. Remove it
   * before saving so restoration will not add a second XOR cursor. */
  if (action == 1 && active) {
    HideCursor();
    was_active = active;
  }
  /* Either VGA hardware or extended VBE registers can change the layout.
   * Remove the cursor while its old bank/stride is still accessible. */
  if (action == 2 && (flags & 9)) {
    was_active = SuspendConsole();
  }
  bios(&request);
  if (request.ax != 0x004f) {
    active = was_active;
    UpdateKeyboardState();
    if (action == 2 && (flags & 9) && active) {
      mouse_resume();
    }
    if (was_cursor && !cursor_visible) {
      ShowCursor();
    }
    return;
  }
  if (action == 1) {
    for (i = 0; i < 64; ++i) {
      record[i] = 0;
    }
    record[0] = 'H';
    record[1] = 'H';
    record[2] = 'V';
    record[3] = 1;
    record[4] = active;
    record[5] = logical_mode;
    record[6] = direct;
    record[7] = (u8)active_page;
    record[8] = policy;
    record[9] = hanzi;
    record[10] = (u8)cursor_shape;
    record[11] = (u8)(cursor_shape >> 8);
    record[12] = cursor_on;
    record[13] = (u8)flags;
    record[14] = traditional;
    record[15] = blink;
    record[16] = (u8)text_rows;
    record[17] = (u8)logical_height;
    record[18] = (u8)scan_lines;
    record[19] = (u8)(scan_lines >> 8);
    for (i = 0; i < sizeof(screen); ++i) {
      record[20 + i] = ((u8*)&screen)[i];
    }
    record[48] = (u8)text_bank;
    record[49] = (u8)(text_bank >> 8);
    record[50] = hardware_mode;
    record[51] = translate_text;
    record[52] = native_mode;
    record[53] = 1;  /* Text-policy extension; older records leave this zero. */
    if (was_cursor) {
      ShowCursor();
    }
  } else if (flags & 9) {
    if (record[0] == 'H' && record[1] == 'H' && record[2] == 'V' &&
        record[3] == 1 && record[13] == (u8)flags && record[4] <= 1 &&
        record[7] < 8) {
      active = record[4];
      logical_mode = record[5];
      direct = record[6];
      translate_text = record[53] == 1 ? record[51] != 0 : 1;
      native_mode = record[53] == 1 ? record[52] : 0xff;
      active_page = record[7];
      policy = record[8];
      hanzi = record[9];
      cursor_shape = record[10] | ((u16)record[11] << 8);
      cursor_on = record[12];
      traditional = record[14];
      blink = record[15];
      if (record[16]) {
        if (record[16] > MAX_TEXT_ROWS ||
            (record[17] != 8 && record[17] != 14 && record[17] != 16)) {
          active = 0;
          request.ax = 0x014f;
          UpdateKeyboardState();
          return;
        }
        for (i = 0; i < sizeof(saved); ++i) {
          ((u8*)&saved)[i] = record[20 + i];
        }
        if (!IsSavedSurfaceValid(&saved, record[16]) ||
            record[7] >= (record[16] > 25 ? 4 : 8)) {
          active = 0;
          request.ax = 0x014f;
          UpdateKeyboardState();
          return;
        }
        UseSurface(&saved);
        SetTextGeometry(record[16], record[17]);
        text_bank = record[48] | ((u16)record[49] << 8);
        scan_lines = record[18] | ((u16)record[19] << 8);
        hardware_mode = record[50];
      }
      cursor_visible = 0;
      if (active) {
        if (record[16] && !RestoreSurface()) {
          active = 0;
          request.ax = 0x014f;
          UpdateKeyboardState();
          return;
        }
        if (!aperture()) {
          active = 0;
          request.ax = 0x014f;
        } else {
          if (linear_color) {
            linear_prepare();
          }
          WriteBdaByte(0x49, logical_mode);
          WriteBdaByte(0x84, last_row);
          WriteBdaWord(0x85, logical_height);
          WriteBdaWord(0x4c, page_bytes);
          WriteBdaByte(0x62, (u8)active_page);
          WriteBdaWord(0x4e, active_page * page_bytes);
          invalidate();
          prompt_dirty = 1;
        }
      }
    }
    UpdateKeyboardState();
    if (active) {
      mouse_resume();
    }
  }
}

static u16 StatusInset(void) {
  return banked_text &&
         viewport_y + (text_rows + 1) * raster_height * pixel_scale + 2 <=
             screen.height;
}

static void DrawStatusBar(void) {
  u16 i;
  u16 drawing = 0;
  u16 origin = viewport_y;
  u8 previous_large = large_surface;
  u16 bottom = origin + (text_rows + 1) * raster_height * pixel_scale;
  /* Use spare scanlines, never crop a glyph or steal an application row. */
  u16 inset = StatusInset();
  u16 panels = prompt_panel_dirty;
  for (i = 0; i < 80; ++i) {
    u16 cell = prompt_open ? prompt[i] : 32;
    u16 character = cell & 255;
    u16 attribute = cell >> 8;
    u16 kind = kStatusCharacter;
    u16 changed;
    if (prompt_open) {
      if (prompt_bitmap[i / 8] & (1 << (i & 7))) {
        kind = kStatusBitmap;
      } else if (character >= 0xa1 && character <= 0xf7 && i < 79 &&
                 !(prompt_bitmap[(i + 1) / 8] & (1 << ((i + 1) & 7))) &&
                 (prompt[i + 1] & 255) >= 0xa1 &&
                 (prompt[i + 1] & 255) <= 0xfe) {
        kind = kStatusLead;
        character = (character << 8) | (prompt[i + 1] & 255);
        attribute = (attribute << 8) | (prompt[i + 1] >> 8);
      }
    }
    changed = prompt_dirty || prompt_shown[i] != cell || prompt_kind[i] != kind;
    if (kind == kStatusLead &&
        (prompt_shown[i + 1] != prompt[i + 1] ||
         prompt_kind[i + 1] != kStatusTrail)) {
      changed = 1;
    }
    if (changed) {
      panels |= 1 << (i / 10);
      if (kind == kStatusLead) {
        panels |= 1 << ((i + 1) / 10);
      }
      if (!drawing) {
        if (!begin_draw()) {
          prompt_dirty = 1;
          return;
        }
        drawing = 1;
        viewport_y += inset;
        if (inset) {
          large_surface = 1;
        }
      }
      if (kind == kStatusBitmap) {
        bitmap(resident_segment, (u16)prompt_bits[i], attribute,
               (text_rows << 8) + i, 1);
      } else {
        draw(character, attribute, (text_rows << 8) + i);
      }
      prompt_shown[i] = cell;
      prompt_kind[i] = (u8)kind;
    }
    if (kind == kStatusLead) {
      ++i;
      prompt_shown[i] = prompt[i];
      prompt_kind[i] = kStatusTrail;
    }
  }
  if (!drawing && panels) {
    if (!begin_draw()) {
      return;
    }
    drawing = 1;
  }
  if (drawing) {
    viewport_y = origin;
    large_surface = previous_large;
    if (inset && (prompt_dirty || prompt_frame_open != prompt_open)) {
      raster_status_edge(origin + text_rows * raster_height * pixel_scale,
                         prompt_open ? 15 : 0);
      raster_status_edge(bottom + 1, prompt_open ? 8 : 0);
    }
    if (prompt_open) {
      for (i = 0; i < 8; ++i) {
        if ((panels & (1 << i)) && prompt_panel_width[i]) {
          raster_status_panel(i * 10, prompt_panel_width[i],
                              prompt_panel_style[i], inset);
        }
      }
    }
    end_draw();
    prompt_frame_open = prompt_open;
  }
  prompt_dirty = 0;
  prompt_panel_dirty = 0;
}
static void ClearStatusBar(void) {
  u16 i;
  for (i = 0; i < 80; ++i) {
    prompt[i] = ((u16)prompt_attr << 8) | 32;
  }
  for (i = 0; i < 8; ++i) {
    if (prompt_panel_width[i]) {
      prompt_dirty = 1;
      prompt_panel_width[i] = 0;
    }
  }
  ClearBytes(prompt_bitmap, sizeof(prompt_bitmap));
  prompt_col = 0;
  prompt_open = 1;
}

static void DispatchHhbiosRequest(void) {
  u16 operation = request.ax & 255;
  u16 i;
  u16 text_position = request.dx;
  if (operation == 0) {
    ClearStatusBar();
    DrawStatusBar();
  } else if (operation == 1 || operation == 3) {
    if (!prompt_open) {
      ClearStatusBar();
    }
    if (operation == 3 && (text_position & 255) == 8) {
      if (prompt_col) {
        --prompt_col;
      }
      prompt[prompt_col] = ((u16)prompt_attr << 8) | 32;
      prompt_bitmap[prompt_col / 8] &= ~(1 << (prompt_col & 7));
    } else {
      for (i = 0; i < (operation == 3 ? 1 : request.cx) && prompt_col + i < 80;
           ++i) {
        prompt[prompt_col + i] =
            (request.bx & 255) * 256 + (text_position & 255);
        prompt_bitmap[(prompt_col + i) / 8] &= ~(1 << ((prompt_col + i) & 7));
      }
    }
    if (operation == 3 && (text_position & 255) != 8 && prompt_col < 79) {
      ++prompt_col;
    }
    DrawStatusBar();
  } else if (operation == 2) {
    if ((text_position & 255) < 80) {
      prompt_col = (u8)text_position;
    }
  } else if (operation == 4) {
    prompt_open = 0;
    DrawStatusBar();
  } else if (operation == 5) {
    prompt_attr = (u8)request.bx;
  } else if (operation == 6) {
    request.ax = 0x0f12;
    request.bx = (text_rows << 8) | 4;
    request.cx = (raster_height << 8) | (text_rows + 1);
    request.dx = 0x80 | traditional;
    request.si = screen.width - 1;
    request.di = screen.height - 1;
    request.bp = framebuffer;
  } else if (operation == 7) {
    logical_mode = (u8)(request.bx >> 8);
    WriteBdaByte(0x49, logical_mode);
  } else if (operation == 8) {
    if (IsTextPosition(text_position)) {
      if (large_surface) {
        raster_cursor(text_position, 16);
      } else {
        cursor_xor(text_position, 16);
      }
    }
  } else if (operation == 9) {
    if (IsTextPosition(text_position)) {
      TextPage(active_page)[TextCellIndex(text_position)] =
          (request.bx << 8) | (request.bx >> 8);
      RepaintConsole();
    }
  } else if (operation == 10) {
    u16 col = text_position & 255;
    u16 j;
    if (request.si <= 0xffc0 && col < 80) {
      if (!prompt_open) {
        ClearStatusBar();
      }
      for (i = 0; i < 4 && col + i < 80; ++i) {
        for (j = 0; j < 16; ++j) {
          u8 bits = *PTR(u8, request.bp, request.si + i * 16 + j);
          if (prompt_bits[col + i][j] != bits) {
            prompt_bits[col + i][j] = bits;
            prompt_kind[col + i] = kStatusInvalid;
          }
        }
        prompt[col + i] = request.bx << 8;
        prompt_bitmap[(col + i) / 8] |= 1 << ((col + i) & 7);
      }
      DrawStatusBar();
    }
  } else if (operation == 11) {
    blink = (u8)(request.bx >> 8);
  } else if (operation == 12) {
    request.bx = resident_segment;
    request.ax = (u16)shadow;
  } else if (operation == 13) {
    period = (u8)(request.bx >> 8);
    if (!period) {
      period = 1;
    }
  } else if (operation == 14) {
    request.bx = resident_segment;
    request.ax = frame_alias_offset;
  } else if (operation == 15) {
    u16 text_offset = request.si;
    u16 character;
    u16 origin = viewport_y;
    u8 previous_large = large_surface;
    if (!begin_draw()) {
      return;
    }
    if ((text_position >> 8) == text_rows) {
      /* Wide strings bypass the retained row. Keep them visible until the
       * next status request, which must restore any overwritten cells. */
      invalidate_prompt();
      if (StatusInset()) {
        ++viewport_y;
        large_surface = 1;
      }
    }
    while (text_offset < 0xfffe && (text_position & 255) < 80) {
      character = *PTR(u8, request.es, text_offset++);
      if (!character) {
        break;
      }
      if (character >= 0xa1 && character <= 0xf7 &&
          *PTR(u8, request.es, text_offset) >= 0xa1 &&
          *PTR(u8, request.es, text_offset) <= 0xfe) {
        character = (character << 8) | *PTR(u8, request.es, text_offset++);
        draw_wide(character, (request.bx & 255) * 257, text_position);
        text_position += 4;
      } else {
        draw_wide(character, request.bx & 255, text_position);
        text_position += 2;
      }
    }
    viewport_y = origin;
    large_surface = previous_large;
    end_draw();
  } else if (operation == 16) {
    boundary(&request);
  } else if (operation == 23) {
    /* AX=1417h: DL=slot, DH=width, BL=1 raised / 2 pressed.
     * The caller leaves the first and last character cells blank. */
    u16 slot = request.dx & 255;
    u16 width = request.dx >> 8;
    u16 style = request.bx & 255;
    if (prompt_open && slot < 8 && width >= 3 && width <= 10 &&
        style >= 1 && style <= 2) {
      if (prompt_panel_width[slot] != width ||
          prompt_panel_style[slot] != style) {
        if (prompt_panel_width[slot] && prompt_panel_width[slot] != width) {
          prompt_dirty = 1;
        }
        prompt_panel_width[slot] = (u8)width;
        prompt_panel_style[slot] = (u8)style;
        prompt_panel_dirty |= 1 << slot;
      }
      DrawStatusBar();
    }
  }
}

u16 CALL dispatch(void) {
  u16 function = request.ax >> 8;
  u16 subfunction = request.ax & 255;
  u16 i;
  u16 page_number = request.bx >> 8;
  u16 text_position;
  u16 count;
  if (function == 0xff) {
    request.ax = 0x56;
    return 1;
  }
  if (function == 0x14 && subfunction == 17) {
    request.ax = 0x5356;
    request.bx = 1;
    request.cx = sizeof(screen);
    request.es = resident_segment;
    request.di = (u16)&screen;
    request.si = resident_bytes;
    request.bp = banked_text;
    request.dx = framebuffer;
    return 1;
  }
  if (function == 0x14 && subfunction == 19) {
    request.ax = 0x4632;
    request.bx = font_kind;
    request.cx = font_kb;
    request.dx = font_fault;
    request.si = font_width;
    request.di = font_height;
    return 1;
  }
  if (function == 0x14 && subfunction == 21) {
    request.ax = 0x5650;
    request.bx = viewport_x;
    request.cx = viewport_y;
    request.dx = pixel_scale;
    request.si = (u16)plane_bytes;
    request.di = (u16)(plane_bytes >> 16);
    return 1;
  }
  if (function == 0x14 && subfunction == 24) {
    /* DX:AX is the bytes written to the linear map since the previous reset.
     * CX=1 clears the counter after reporting it. Planar draws leave it zero. */
    request.ax = (u16)lfb_bytes;
    request.dx = (u16)(lfb_bytes >> 16);
    request.bx = linear_color;
    if (request.cx == 1) {
      lfb_bytes = 0;
    }
    return 1;
  }
  if (function == 0x14 && (subfunction == 18 || subfunction == 20)) {
    u32 offset = request.si;
    if (subfunction == 20) {
      offset |= (u32)request.dx << 16;
    }
    if (!active || (linear_color ? request.bx != 0 : request.bx > 3) ||
        offset > plane_bytes ||
        request.cx > plane_bytes - offset || request.di > 65535U - request.cx) {
      request.ax = 1;
    } else if (!text_ready()) {
      request.ax = 2;
    } else if (!request.cx) {
      request.ax = 0;
    } else {
      if (large_surface) {
        raster_read(request.bx, offset, request.es, request.di, request.cx);
      } else {
        read_plane(request.bx, request.si, request.es, request.di, request.cx);
      }
      request.ax = active ? 0 : 1;
      if (!active) {
        UpdateKeyboardState();
      }
    }
    return 1;
  }
  if (function == 0x4f) {
    if (subfunction == 4) {
      TransferVideoState();
    } else if (subfunction == 2) {
      u8 previous = active;
      u8 previous_cursor = cursor_visible;
      u16 mode = request.bx & 0x3fff;
      previous = SuspendConsole();
      bios(&request);
      if (request.ax == 0x004f) {
        native_mode = 0xff;
        if (mode <= 3 && translate_text) {
          logical_mode = 3;
          direct = 1;
          if (text_rows != 25 && banked_text) {
            if (!SetTextRows(25, scan_lines / 25, 0)) {
              request.ax = 0x014f;
            }
          } else if (!ActivateConsole(0)) {
            request.ax = 0x014f;
          }
        } else if (mode <= 3 || mode == 7) {
          native_mode = (u8)mode;
          UpdateKeyboardState();
        }
      } else {
        active = previous;
        UpdateKeyboardState();
        if (active) {
          mouse_resume();
        }
        if (previous_cursor) {
          ShowCursor();
        }
      }
    } else {
      /* BX is an input subfunction, but 4F06 returns a byte pitch in
       * the same register. Classify ownership before entering BIOS.
       * VBE 3.0 scheduling/stereo setters also own the display. */
      u16 op = request.bx & 255;
      u8 changes = (u8)((subfunction == 5 && !(request.bx & 0xff00)) ||
                        (subfunction == 6 && (op == 0 || op == 2)) ||
                        (subfunction == 7 &&
                         (op == 0 || op == 0x80 || op == 2 || op == 3 ||
                          op == 0x82 || op == 0x83 || op == 5 || op == 6)));
      u8 previous = active;
      u8 previous_cursor = cursor_visible;
      if (changes) {
        previous = SuspendConsole();
      }
      bios(&request);
      if (changes && request.ax != 0x004f) {
        active = previous;
        UpdateKeyboardState();
        if (active) {
          mouse_resume();
        }
        if (previous_cursor) {
          ShowCursor();
        }
      }
    }
    /* Cursor removal or rollback can itself lose the graphics bank. */
    if (!active) {
      UpdateKeyboardState();
    }
    return 1;
  }
  /* Applications may select scanlines while a graphics font probe has
   * suspended us. Track that request before they return to text mode. */
  if (function == 0x12 && (request.bx & 255) == 0x30 && subfunction <= 2) {
    bios(&request);
    if ((request.ax & 255) == 0x12) {
      scan_lines = subfunction == 0 ? 200 : subfunction == 1 ? 350 : 400;
    }
    return 1;
  }
  /* These policies also apply while a native application owns the screen. */
  if (function == 0x18 && (subfunction == 4 || subfunction == 5 ||
                           subfunction == 10 || subfunction == 11)) {
    if (subfunction == 4 || subfunction == 5) {
      allow_mode = (u8)(subfunction == 5);
    } else {
      translate_text = direct = (u8)(subfunction == 11);
      UpdateKeyboardState();
    }
    return 1;
  }
  if (!function) {
    if (!allow_mode) {
      return 1;
    }
    SuspendConsole();
    if (((subfunction & 127) <= 3 && translate_text) ||
        (subfunction & 127) == 0x12) {
      logical_mode = (subfunction & 127) == 0x12 ? 0x12 : 3;
      direct = logical_mode == 3;
      if (text_rows != 25 && banked_text) {
        SetTextRows(25, scan_lines / 25, subfunction & 128);
      } else {
        logical_height = scan_lines / 25;
        ActivateConsole(subfunction & 128);
      }
    } else {
      bios(&request);
      native_mode = 0xff;
      if ((subfunction & 127) <= 3 || (subfunction & 127) == 7) {
        native_mode = (u8)(subfunction & 127);
      }
    }
    UpdateKeyboardState();
    return 1;
  }
  if (!active) {
    return 0;
  }
  /* A one-image adapter can expose only page zero without overlapping
   * scanout. Never accept an inaccessible page and overwrite graphics. */
  if ((page_number >= page_count || (!banked_text && page_number)) &&
      (function == 2 || function == 3 || function == 8 || function == 9 ||
       function == 10 || function == 0x13)) {
    return 1;
  }
  switch (function) {
    case 1:
      HideCursor();
      cursor_shape = request.cx;
      if ((cursor_shape & 31) < (cursor_shape >> 8 & 31)) {
        cursor_shape |= 0x2000;
      }
      WriteBdaWord(0x60, cursor_shape);
      ShowCursor();
      break;
    case 2:
      MoveCursor(page_number, request.dx);
      break;
    case 3:
      request.dx = CursorPosition(page_number);
      request.cx = cursor_shape;
      break;
    case 5:
      if (subfunction >= page_count) {
        break;
      }
      HideCursor();
      active_page = subfunction & 7;
      WriteBdaByte(0x62, (u8)active_page);
      WriteBdaWord(0x4e, active_page * page_bytes);
      invalidate();
      RepaintConsole();
      break;
    case 6:
    case 7:
      ScrollText(active_page, function == 7, subfunction, page_number,
                 request.cx, request.dx);
      RepaintConsole();
      break;
    case 8:
      text_position = CursorPosition(page_number);
      request.ax = IsTextPosition(text_position)
                       ? TextPage(page_number)[TextCellIndex(text_position)]
                       : 0;
      break;
    case 9:
    case 10:
      text_position = CursorPosition(page_number);
      if (!IsTextPosition(text_position)) {
        break;
      }
      i = TextCellIndex(text_position);
      count = request.cx;
      if (count > text_cells - i) {
        count = text_cells - i;
      }
      while (count--) {
        TextPage(page_number)[i] =
            (function == 9 ? request.bx << 8
                           : TextPage(page_number)[i] & 0xff00) |
            subfunction;
        ++i;
      }
      RepaintConsole();
      break;
    case 0x0b:
      /* DOS CLS uses the CGA palette interface even in text mode. The
       * physical VBE BIOS may otherwise remap colors 1..3 as CGA colors. */
      if (!page_number) {
        struct BiosRegisters border;
        ClearBytes(&border, sizeof(border));
        border.ax = 0x1007;
        border.bx = request.bx & 15;
        bios(&border);
        border.ax = 0x1001;
        bios(&border);
        WriteBdaByte(0x66, (ReadBdaByte(0x66) & 0xe0) | (request.bx & 31));
      } else if (page_number == 1) {
        WriteBdaByte(0x66,
                     (ReadBdaByte(0x66) & 0xdf) | ((request.bx & 1) << 5));
      }
      break;
    case 0x0e:
      WriteTeletype((u8)subfunction, active_page);
      RepaintConsole();
      break;
    case 0x0c:
    case 0x0d:
      if (request.cx < screen.width && request.dx < screen.height) {
        i = large_surface
                ? raster_pixel(request.cx, request.dx, subfunction,
                               function == 0x0c)
                : pixel(request.cx, request.dx, subfunction, function == 0x0c);
        if (function == 0x0d) {
          request.ax = (request.ax & 0xff00) | i;
        } else {
          u16 status_top = viewport_y + text_rows * raster_height * pixel_scale;
          if (request.dx >= status_top &&
              request.dx - status_top < raster_height * pixel_scale) {
            invalidate_prompt();
          }
        }
      }
      break;
    case 0x0f:
      request.ax = (80 << 8) | logical_mode;
      request.bx = (request.bx & 255) | (active_page << 8);
      break;
    case 0x10:
      if (subfunction == 3) {
        break; /* keep sixteen background colors */
      }
      bios(&request);
      break;
    case 0x11:
      if (subfunction == 0x30) {
        bios(&request);
        request.cx = logical_height;
        request.dx = (request.dx & 0xff00) | last_row;
      } else if (subfunction == 0x10 || subfunction == 0x11 ||
                 subfunction == 0x12 || subfunction == 0x14) {
        /* User-font activation also changes the logical row count.
         * Chinese scanout continues to use our native bitmap font. */
        u16 height = subfunction == 0x10   ? page_number
                     : subfunction == 0x12 ? 8
                     : subfunction == 0x11 ? 14
                                           : 16;
        if (height && height <= 32) {
          SetTextRows(scan_lines / height, height, 1);
        }
      }
      break;
    case 0x1b: {
      u8 FAR* info = PTR(u8, request.es, request.di);
      if (subfunction || request.bx) {
        return 0;
      }
      if (request.di > 0xffc0) {
        request.ax &= 0xff00;
        break;
      }
      bios(&request);
      if ((request.ax & 255) != 0x1b) {
        break;
      }
      /* Keep the BIOS capability pointer, but describe the logical mode.
       * DOSSHELL checks 2Ah and retries with the returned scanline setting. */
      for (i = 0; i < 30; ++i) {
        info[4 + i] = ReadBdaByte(0x49 + i);
      }
      info[0x22] = (u8)text_rows;
      info[0x23] = (u8)logical_height;
      info[0x24] = 0;
      info[0x27] = 16;
      info[0x28] = 0;
      info[0x29] = (u8)page_count;
      info[0x2a] = scan_lines == 200 ? 0 : scan_lines == 350 ? 1 : 2;
      info[0x2d] &= ~0x20; /* backgrounds retain all sixteen colors */
      break;
    }
    case 0x13: {
      u16 saved = CursorPosition(page_number), off = request.bp;
      WriteBdaWord(0x50 + (page_number & 7) * 2, request.dx);
      for (i = 0; i < request.cx && off < 0xffff; ++i) {
        u8 c = *PTR(u8, request.es, off++), attr = (u8)request.bx;
        if (subfunction & 2) {
          if (off == 0xffff) {
            break;
          }
          attr = *PTR(u8, request.es, off++);
        }
        text_position = CursorPosition(page_number);
        if (IsTextPosition(text_position) && c >= 32) {
          TextPage(page_number)[TextCellIndex(text_position)] = (u16)attr << 8;
        }
        WriteTeletype(c, page_number);
      }
      if (!(subfunction & 1)) {
        WriteBdaWord(0x50 + (page_number & 7) * 2, saved);
      }
      RepaintConsole();
      break;
    }
    case 0x14:
      DispatchHhbiosRequest();
      break;
    case 0x15:
      prompt_dirty = 1;
      RepaintConsole();
      break;
    case 0x16: {
      u8 bits[32];
      glyph(request.dx, bits);
      for (i = 0; i < (request.dx >> 8 ? 32 : 16); ++i) {
        *PTR(u8, request.bp, request.bx + i) = bits[i];
      }
      break;
    }
    case 0x17:
      HideCursor();
      cursor_on = (u8)subfunction;
      if (cursor_on) {
        ShowCursor();
      }
      break;
    case 0x18:
      if (subfunction < 2) {
        hanzi = (u8)!subfunction;
        invalidate();
      } else if (subfunction == 12) {
        policy = (u8)page_number;
        invalidate();
      } else if (subfunction == 17 || subfunction == 18) {
        traditional = (u8)(subfunction == 18);
        invalidate();
        prompt_dirty = 1;
      } else if (subfunction == 19 || subfunction == 23) {
        invalidate();
        prompt_dirty = 1;
      }
      RepaintConsole();
      break;
    default:
      return 0;
  }
  if (!active) {
    UpdateKeyboardState();
  }
  return 1;
}

void CALL tick(void) {
  if (!active || ++counter < period || !text_ready()) {
    return;
  }
  counter = 0;
  RefreshConsole(!blink || (ReadBdaByte(0x6c) & 8));
  if (!active) {
    UpdateKeyboardState();
  }
}
#endif

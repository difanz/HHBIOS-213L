/* Bank-spanning planar stores. Logical B800 cells remain independent of the
 * physical surface, viewport and integer pixel enlargement. No heap or CRT. */
#include "vesa.h"

static void WritePortWord(u16 port_address, u16 value);
#pragma aux WritePortWord = "out dx,ax" parm[dx][ax];
static void PreparePixelRow(const u32* source, u8* destination, u16 shift);
#pragma aux PreparePixelRow = \
    "mov eax,[si]"            \
    "shr eax,cl"              \
    "xchg al,ah"              \
    "ror eax,16"              \
    "xchg al,ah"              \
    "mov [di],eax" parm[si][di][cx] modify[ax];
/* Drawing and scrolling run serially under the resident renderer lock. */
static union {
  struct {
    u8 ink[MAX_FONT_HEIGHT][16];
    u8 masks[16];
    u32 scaled_bits[MAX_FONT_HEIGHT];
  } glyph;
  u8 scroll_row[4][512];
} scratch;
void CALL raster_words(const u16* bits, u16 offset, u16 rows, u16 shift,
                       u16 foreground, u16 background);
void CALL raster_copy(void FAR* destination, const void FAR* source, u16 count);
void CALL raster_latches(u16 destination, u16 source, u16 count);
void CALL raster_span(const u8* source, u16 offset, u16 rows, u16 width,
                      const u8* masks, u16 foreground, u16 background,
                      u16 repeats, u16 phase);
void CALL raster_stencil(const u8* source, u16 offset, u16 rows, u16 width,
                         const u8* masks, u16 attribute, u16 source_pitch);
void CALL raster_pack(const u8* source, u8* destination, u16 rows,
                      u16 source_pitch, u16 source_bytes, u16 source_shift,
                      u16 destination_shift);

static u8 FAR* MapFramebufferByte(u32 offset) {
  u16 block = (u16)(offset >> 16);
  if (!active || (block != mapped_block && !graphics_bank(block))) {
    return 0;
  }
  return PTR(u8, screen.segment, (u16)offset);
}

static void SelectPlane(u16 plane_index) {
  WritePortWord(0x3ce, 4 | (plane_index << 8));
  WritePortWord(0x3c4, 2 | (0x100 << plane_index));
}

/* One scanline, clipped to the text viewport. Set/reset broadcasts the
 * solid color to all four planes; only partial edge bytes need a latch read. */
void CALL raster_status_edge(u16 y, u16 color) {
  u16 x = viewport_x;
  u16 remaining = TEXT_COLS * font_width * pixel_scale;
  u32 offset = MultiplyWide(y, display_pitch) + x / 8;
  if (y >= screen.height) {
    return;
  }
  WritePortWord(0x3c4, 0x0f02);
  WritePortWord(0x3ce, color << 8);
  WritePortWord(0x3ce, 0x0f01);
  while (remaining) {
    volatile u8 FAR* destination = MapFramebufferByte(offset);
    u16 count;
    if (!destination) {
      break;
    }
    if ((x & 7) || remaining < 8) {
      u8 mask = 255 >> (x & 7);
      u8 latch;
      count = 8 - (x & 7);
      if (count > remaining) {
        count = remaining;
        mask &= 255 << (8 - (x & 7) - count);
      }
      WritePortWord(0x3ce, 8 | ((u16)mask << 8));
      latch = *destination;
      *destination = latch;
      ++offset;
    } else {
      u16 bytes = remaining / 8;
      if ((u16)offset && bytes > 0U - (u16)offset) {
        bytes = 0U - (u16)offset;
      }
      WritePortWord(0x3ce, 0xff08);
      fill_cells((u16 FAR*)destination, 0xffff, bytes / 2);
      if (bytes & 1) {
        destination[bytes - 1] = 255;
      }
      count = bytes * 8;
      offset += bytes;
    }
    x += count;
    remaining -= count;
  }
  WritePortWord(0x3ce, 1);
  WritePortWord(0x3ce, 0xff08);
}

/* Whole-byte stores can broadcast identical ink/background bits to several
 * planes. Partial edge bytes still read and preserve each plane separately. */
static u16 SelectGlyphPlanes(u16 plane, u16 attribute, u16 whole_bytes) {
  u16 mask = 1 << plane;
  if (whole_bytes) {
    u16 i;
    u16 colors = (attribute >> plane) & 0x11;
    mask = 0;
    for (i = 0; i < 4; ++i) {
      if (((attribute >> i) & 0x11) == colors) {
        if (i < plane) {
          return 0;
        }
        mask |= 1 << i;
      }
    }
  }
  WritePortWord(0x3ce, 4 | (plane << 8));
  WritePortWord(0x3c4, 2 | (mask << 8));
  return 1;
}

/* Emit packed rows directly from the font cache or the shifted-row scratch.
 * Split only at window boundaries; a scanline crossing one needs byte stores. */
static void DrawPackedRows(const u8* source, u16 source_pitch, u16 attribute,
                           u16 x, u16 y, u16 bytes, const u8* masks) {
  u32 offset = MultiplyWide(y, display_pitch) + x / 8;
  u16 remaining = raster_height;
  while (remaining) {
    u16 rows;
    if (!MapFramebufferByte(offset)) {
      return;
    }
    if ((u16)offset > 65535U - (bytes - 1)) {
      u16 byte_index;
      for (byte_index = 0; byte_index < bytes; ++byte_index) {
        u16 plane;
        u8 FAR* destination = MapFramebufferByte(offset + byte_index);
        if (!destination) {
          return;
        }
        for (plane = 0; plane < 4; ++plane) {
          u8 foreground = (attribute & (1 << plane)) ? 255 : 0;
          u8 background = (attribute & (16 << plane)) ? 255 : 0;
          u8 value = (source[byte_index] & (foreground ^ background)) ^ background;
          if (SelectGlyphPlanes(plane, attribute, masks[byte_index] == 255)) {
            *destination = (*destination & ~masks[byte_index]) |
                           (value & masks[byte_index]);
          }
        }
      }
      rows = 1;
    } else {
      rows = (65535U - (bytes - 1) - (u16)offset) / display_pitch + 1;
      if (rows > remaining) {
        rows = remaining;
      }
      raster_stencil(source, (u16)offset, rows, bytes, masks, attribute,
                     source_pitch);
    }
    source += rows * source_pitch;
    offset += MultiplyWide(rows, display_pitch);
    remaining -= rows;
  }
  WritePortWord(0x3c4, 0x0f02);
}

void CALL raster_packed_cell(const u8* source, u16 attribute, u16 position,
                             u16 source_pitch, u16 source_bit) {
  u16 x;
  u16 y;
  u16 shift;
  u16 bytes;
  u16 i;
  if ((position & 255) >= TEXT_COLS || (position >> 8) > text_rows) {
    return;
  }
  x = viewport_x + (position & 255) * font_width;
  y = viewport_y + (position >> 8) * raster_height;
  shift = x & 7;
  bytes = (shift + font_width + 7) / 8;
  for (i = 0; i < bytes; ++i) {
    scratch.glyph.masks[i] = 255;
  }
  scratch.glyph.masks[0] >>= shift;
  if ((shift + font_width) & 7) {
    scratch.glyph.masks[bytes - 1] &= 255 << (8 - ((shift + font_width) & 7));
  }
  source += source_bit / 8;
  source_bit &= 7;
  if (shift || source_bit) {
    raster_pack(source, scratch.glyph.ink[0], raster_height, source_pitch,
                (source_bit + font_width + 7) / 8, source_bit, shift);
    source = scratch.glyph.ink[0];
    source_pitch = sizeof(scratch.glyph.ink[0]);
  }
  DrawPackedRows(source, source_pitch, attribute, x, y, bytes,
                 scratch.glyph.masks);
}

static void DrawWordRows(const u16* bits, u16 attribute, u16 x, u16 y) {
  u32 offset = MultiplyWide(y, display_pitch) + (x >> 3);
  u16 remaining = raster_height;
  u16 rows;
  u16 plane_index;
  u16 foreground;
  u16 background;
  u16 value;
  u16 byte_index;
  u16 mask = 0xffc0U >> (x & 7);
  u8 FAR* destination;
  while (remaining) {
    if (!MapFramebufferByte(offset)) {
      return;
    }
    if ((u16)offset == 65535U) {
      /* Only the word crossing the window needs separate byte mappings. */
      for (byte_index = 0; byte_index < 2; ++byte_index) {
        destination = MapFramebufferByte(offset + byte_index);
        if (!destination) {
          return;
        }
        for (plane_index = 0; plane_index < 4; ++plane_index) {
          u8 byte_mask = byte_index ? (u8)mask : mask >> 8;
          SelectPlane(plane_index);
          foreground = (attribute & (1 << plane_index)) ? 65535U : 0;
          background = (attribute & (16 << plane_index)) ? 65535U : 0;
          value =
              ((bits[0] >> (x & 7)) & (foreground ^ background)) ^ background;
          if (!byte_index) {
            value >>= 8;
          }
          *destination = (*destination & ~byte_mask) | ((u8)value & byte_mask);
        }
      }
      rows = 1;
    } else {
      rows = (65534U - (u16)offset) / display_pitch + 1;
      if (rows > remaining) {
        rows = remaining;
      }
      for (plane_index = 0; plane_index < 4; ++plane_index) {
        SelectPlane(plane_index);
        raster_words(bits, (u16)offset, rows, x & 7,
                     (attribute & (1 << plane_index)) ? 65535U : 0,
                     (attribute & (16 << plane_index)) ? 65535U : 0);
      }
    }
    bits += rows;
    offset += MultiplyWide(rows, display_pitch);
    remaining -= rows;
  }
  WritePortWord(0x3c4, 0x0f02);
}

void CALL raster_cell(const u16* bits, u16 attribute, u16 position) {
  u16 x;
  u16 y;
  u16 row;
  if ((position & 255) >= TEXT_COLS || (position >> 8) > text_rows) {
    return;
  }
  x = viewport_x + (position & 255) * CELL_WIDTH * pixel_scale;
  y = viewport_y + (position >> 8) * raster_height * pixel_scale;
  if (pixel_scale == 1 && (x & 7) <= 6) {
    DrawWordRows(bits, attribute, x, y);
    return;
  }
  for (row = 0; row < raster_height; ++row) {
    scratch.glyph.scaled_bits[row] = (u32)bits[row] << 16;
  }
  raster_large_cell(scratch.glyph.scaled_bits, attribute, position);
}

void CALL raster_large_cell(const u32* bits, u16 attribute, u16 position) {
  u16 x;
  u16 y;
  u16 row;
  u16 column;
  u16 byte_index;
  u16 shift;
  u16 width;
  u16 bytes;
  u16 bit;
  u16 repeat;
  u16 plane_index;
  u16 rows;
  u16 done = 0;
  u16 foreground;
  u16 background;
  u8 value;
  u8 FAR* destination;
  u32 offset;
  if ((position & 255) >= TEXT_COLS || (position >> 8) > text_rows) {
    return;
  }
  x = viewport_x + (position & 255) * font_width * pixel_scale;
  y = viewport_y + (position >> 8) * raster_height * pixel_scale;
  shift = x & 7;
  width = font_width * pixel_scale;
  bytes = (shift + width + 7) / 8;
  for (byte_index = 0; byte_index < bytes; ++byte_index) {
    scratch.glyph.masks[byte_index] = 255;
  }
  scratch.glyph.masks[0] >>= shift;
  if ((shift + width) & 7) {
    scratch.glyph.masks[bytes - 1] &= 255 << (8 - ((shift + width) & 7));
  }
  for (row = 0; row < raster_height; ++row) {
    if (pixel_scale == 1) {
      PreparePixelRow(bits + row, scratch.glyph.ink[row], shift);
    } else {
      for (byte_index = 0; byte_index < bytes; ++byte_index) {
        scratch.glyph.ink[row][byte_index] = 0;
      }
      bit = shift;
      for (column = 0; column < font_width; ++column) {
        for (repeat = 0; repeat < pixel_scale; ++repeat, ++bit) {
          if (bits[row] & (0x80000000UL >> column)) {
            scratch.glyph.ink[row][bit / 8] |= 128 >> (bit & 7);
          }
        }
      }
    }
  }
  if (pixel_scale == 1) {
    DrawPackedRows(scratch.glyph.ink[0], sizeof(scratch.glyph.ink[0]),
                   attribute, x, y, bytes, scratch.glyph.masks);
    return;
  }
  offset = MultiplyWide(y, display_pitch) + x / 8;
  while (done < raster_height * pixel_scale) {
    if (!MapFramebufferByte(offset)) {
      return;
    }
    if ((u16)offset > 65535U - (bytes - 1)) {
      for (byte_index = 0; byte_index < bytes; ++byte_index) {
        destination = MapFramebufferByte(offset + byte_index);
        if (!destination) {
          return;
        }
        for (plane_index = 0; plane_index < 4; ++plane_index) {
          if (!SelectGlyphPlanes(plane_index, attribute,
                                 scratch.glyph.masks[byte_index] == 255)) {
            continue;
          }
          foreground = (attribute & (1 << plane_index)) ? 255 : 0;
          background = (attribute & (16 << plane_index)) ? 255 : 0;
          value = (scratch.glyph.ink[done / pixel_scale][byte_index] &
                   (foreground ^ background)) ^
                  background;
          *destination = (*destination & ~scratch.glyph.masks[byte_index]) |
                         (value & scratch.glyph.masks[byte_index]);
        }
      }
      rows = 1;
    } else {
      rows = (65535U - (bytes - 1) - (u16)offset) / display_pitch + 1;
      if (rows > raster_height * pixel_scale - done) {
        rows = raster_height * pixel_scale - done;
      }
      for (plane_index = 0; plane_index < 4; ++plane_index) {
        if (!SelectGlyphPlanes(plane_index, attribute,
                               !(shift | (width & 7)))) {
          continue;
        }
        raster_span(scratch.glyph.ink[done / pixel_scale], (u16)offset, rows,
                    bytes, scratch.glyph.masks,
                    (attribute & (1 << plane_index)) ? 65535U : 0,
                    (attribute & (16 << plane_index)) ? 65535U : 0, pixel_scale,
                    done % pixel_scale);
      }
    }
    offset += MultiplyWide(rows, display_pitch);
    done += rows;
  }
  WritePortWord(0x3c4, 0x0f02);
}

static u16 TransferRow(u32 offset, u16 width, u16 writing, u16 shift) {
  u16 part;
  u16 done = 0;
  u16 plane_index;
  u8 FAR* window;
  while (done < width) {
    window = MapFramebufferByte(offset);
    if (!window) {
      return 0;
    }
    part = width - done;
    if ((u16)offset && part > 0U - (u16)offset) {
      part = 0U - (u16)offset;
    }
    for (plane_index = 0; plane_index < 4; ++plane_index) {
      SelectPlane(plane_index);
      if (writing) {
        if (shift && !done) {
          u8 mask = 255 >> shift;
          scratch.scroll_row[plane_index][0] =
              (scratch.scroll_row[plane_index][0] & mask) | (window[0] & ~mask);
        }
        if (shift && done + part == width) {
          u8 mask = 255 << (8 - shift);
          scratch.scroll_row[plane_index][width - 1] =
              (scratch.scroll_row[plane_index][width - 1] & mask) |
              (window[part - 1] & ~mask);
        }
        raster_copy(window,
                    PTR(u8, resident_segment,
                        (u16)&scratch.scroll_row[plane_index][done]),
                    part);
      } else {
        raster_copy(PTR(u8, resident_segment,
                        (u16)&scratch.scroll_row[plane_index][done]),
                    window, part);
      }
    }
    offset += part;
    done += part;
  }
  return 1;
}

static void CopyScrollEdges(u16 destination, u16 source, u16 width, u16 shift) {
  u8 FAR* window = PTR(u8, screen.segment, 0);
  u8 first_mask = 255 >> shift;
  u8 last_mask = 255 << (8 - shift);
  u16 plane;
  for (plane = 0; plane < 4; ++plane) {
    SelectPlane(plane);
    window[destination] = (window[source] & first_mask) |
                          (window[destination] & ~first_mask);
    window[destination + width - 1] =
        (window[source + width - 1] & last_mask) |
        (window[destination + width - 1] & ~last_mask);
  }
}

u16 CALL raster_scroll(u16 first, u16 last, u16 count, u16 down) {
  u16 height = raster_height * pixel_scale;
  u16 shift = viewport_x & 7;
  u16 width = TEXT_COLS * font_width * pixel_scale / 8 + (shift != 0);
  u16 lines = (last - first + 1 - count) * height;
  u16 row;
  u16 retained;
  u32 destination;
  u32 source;
  u32 distance = MultiplyWide(count * height, display_pitch);
  if (width > sizeof(scratch.scroll_row[0]) || !begin_draw()) {
    return 0;
  }
  for (row = 0; row < lines; ++row) {
    destination = MultiplyWide(viewport_y + first * height +
                                   (down ? lines - row - 1 : row),
                               display_pitch) +
                  viewport_x / 8;
    source = destination + distance;
    if (down) {
      u32 swap = source;
      source = destination;
      destination = swap;
    }
    if ((source >> 16) == (destination >> 16) &&
        (u16)source <= 65535U - (width - 1) &&
        (u16)destination <= 65535U - (width - 1)) {
      if (!MapFramebufferByte(source)) {
        break;
      }
      if (shift) {
        CopyScrollEdges((u16)destination, (u16)source, width, shift);
        raster_latches((u16)destination + 1, (u16)source + 1, width - 2);
      } else {
        raster_latches((u16)destination, (u16)source, width);
      }
    } else if (!TransferRow(source, width, 0, shift) ||
               !TransferRow(destination, width, 1, shift)) {
      break;
    }
  }
  end_draw();
  if (!active || row != lines) {
    return 0;
  }
  retained = (last - first + 1 - count) * TEXT_COLS;
  move_cells(PTR(u16, resident_segment, (u16)shadow),
              (first + (down ? count : 0)) * TEXT_COLS,
              (first + (down ? 0 : count)) * TEXT_COLS, retained);
  return 1;
}

void CALL raster_cursor(u16 position, u16 lines) {
  u16 x;
  u16 y;
  u16 width;
  u16 height;
  u16 plane_index;
  u16 byte_index;
  u16 bytes;
  u16 row_offset;
  u8 FAR* framebuffer_byte;
  u32 offset;
  u32 row_start;
  u8 mask;
  if (!begin_draw()) {
    return;
  }
  if (lines > 16) {
    lines = 16;
  }
  width = font_width * pixel_scale;
  height = ((lines * font_body_height + 15) >> 4) * pixel_scale;
  x = viewport_x + (position & 255) * width;
  y = viewport_y +
      ((position >> 8) * raster_height + font_body_height) * pixel_scale -
      height;
  bytes = ((x & 7) + width + 7) / 8;
  row_start = MultiplyWide(y, display_pitch) + (x >> 3);
  for (plane_index = 0; plane_index < 4 && active; ++plane_index) {
    SelectPlane(plane_index);
    offset = row_start;
    for (row_offset = 0; row_offset < height && active; ++row_offset) {
      for (byte_index = 0; byte_index < bytes; ++byte_index) {
        mask = byte_index ? 255 : 255 >> (x & 7);
        if (byte_index == bytes - 1 && ((x + width) & 7)) {
          mask &= 255 << (8 - ((x + width) & 7));
        }
        framebuffer_byte = MapFramebufferByte(offset + byte_index);
        if (!framebuffer_byte) {
          break;
        }
        *framebuffer_byte ^= mask;
      }
      offset += display_pitch;
    }
  }
  end_draw();
}

u16 CALL raster_pixel(u16 x, u16 y, u16 color, u16 writing) {
  u16 plane_index;
  u16 result = 0;
  u8 mask = 0x80 >> (x & 7), value;
  u8 FAR* framebuffer_byte;
  u32 offset = MultiplyWide(y, display_pitch) + (x >> 3);
  if (!begin_draw()) {
    return 0;
  }
  for (plane_index = 0; plane_index < 4; ++plane_index) {
    SelectPlane(plane_index);
    framebuffer_byte = MapFramebufferByte(offset);
    if (!framebuffer_byte) {
      break;
    }
    value = *framebuffer_byte;
    if (value & mask) {
      result |= 1 << plane_index;
    }
    if (writing) {
      if (color & 0x80) {
        if (color & (1 << plane_index)) {
          *framebuffer_byte = value ^ mask;
        }
      } else {
        *framebuffer_byte =
            (value & ~mask) | ((color & (1 << plane_index)) ? mask : 0);
      }
    }
  }
  end_draw();
  return result;
}

void CALL raster_read(u16 plane_index, u32 offset, u16 segment, u16 destination,
                      u16 count) {
  u16 part;
  u16 i;
  u8 FAR* source;
  u8 FAR* out = PTR(u8, segment, destination);
  if (!begin_draw()) {
    return;
  }
  WritePortWord(0x3ce, 4 | (plane_index << 8));
  while (count) {
    source = MapFramebufferByte(offset);
    if (!source) {
      break;
    }
    part = count;
    if ((u16)offset && part > 0U - (u16)offset) {
      part = 0U - (u16)offset;
    }
    for (i = 0; i < part; ++i) {
      *out++ = *source++;
    }
    count -= part;
    offset += part;
  }
  end_draw();
}

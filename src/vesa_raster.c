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

static void DrawWordRows(const u16* bits, u16 attribute, u16 x, u16 y) {
  u32 offset = MultiplyWide(y, display_pitch) + (x >> 3);
  u16 remaining = raster_height;
  u16 rows;
  u16 plane_index;
  u16 foreground;
  u16 background;
  u16 value;
  u16 mask = 0xffc0U >> (x & 7);
  u8 FAR* destination;
  while (remaining) {
    if (!MapFramebufferByte(offset)) {
      return;
    }
    if ((u16)offset == 65535U) {
      /* Only the word crossing the window needs separate byte mappings. */
      for (plane_index = 0; plane_index < 4; ++plane_index) {
        SelectPlane(plane_index);
        foreground = (attribute & (1 << plane_index)) ? 65535U : 0;
        background = (attribute & (16 << plane_index)) ? 65535U : 0;
        value = ((bits[0] >> (x & 7)) & (foreground ^ background)) ^ background;
        destination = MapFramebufferByte(offset);
        if (!destination) {
          return;
        }
        *destination = (*destination & ~(mask >> 8)) | ((value & mask) >> 8);
        destination = MapFramebufferByte(offset + 1);
        if (!destination) {
          return;
        }
        *destination = (*destination & ~(u8)mask) | (u8)(value & mask);
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
    scratch.glyph.masks[byte_index] = 0;
  }
  for (bit = shift; bit < shift + width; ++bit) {
    scratch.glyph.masks[bit / 8] |= 128 >> (bit & 7);
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
  offset = MultiplyWide(y, display_pitch) + x / 8;
  while (done < raster_height * pixel_scale) {
    if (!MapFramebufferByte(offset)) {
      return;
    }
    if ((u16)offset > 65535U - (bytes - 1)) {
      for (plane_index = 0; plane_index < 4; ++plane_index) {
        SelectPlane(plane_index);
        foreground = (attribute & (1 << plane_index)) ? 255 : 0;
        background = (attribute & (16 << plane_index)) ? 255 : 0;
        for (byte_index = 0; byte_index < bytes; ++byte_index) {
          destination = MapFramebufferByte(offset + byte_index);
          if (!destination) {
            return;
          }
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
        SelectPlane(plane_index);
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

static u16 TransferRow(u32 offset, u16 width, u16 writing) {
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

u16 CALL raster_scroll(u16 first, u16 last, u16 count, u16 down) {
  u16 height = raster_height * pixel_scale;
  u16 width = TEXT_COLS * font_width * pixel_scale / 8;
  u16 lines = (last - first + 1 - count) * height;
  u16 row;
  u16 index;
  u16 retained;
  u32 destination;
  u32 source;
  u32 distance = MultiplyWide(count * height, display_pitch);
  if ((viewport_x & 7) || width > sizeof(scratch.scroll_row[0]) ||
      !begin_draw()) {
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
        (u16)source <= 65535U - width && (u16)destination <= 65535U - width) {
      if (!MapFramebufferByte(source)) {
        break;
      }
      raster_latches((u16)destination, (u16)source, width);
    } else if (!TransferRow(source, width, 0) ||
               !TransferRow(destination, width, 1)) {
      break;
    }
  }
  end_draw();
  if (!active || row != lines) {
    return 0;
  }
  retained = (last - first + 1 - count) * TEXT_COLS;
  for (index = 0; index < retained; ++index) {
    row = first * TEXT_COLS + (down ? retained - index - 1 : index);
    if (down) {
      shadow[row + count * TEXT_COLS] = shadow[row];
    } else {
      shadow[row] = shadow[row + count * TEXT_COLS];
    }
  }
  return 1;
}

void CALL raster_cursor(u16 position, u16 lines) {
  u16 x;
  u16 y;
  u16 width;
  u16 height;
  u16 plane_index;
  u16 column_offset;
  u16 row_offset;
  u8 FAR* framebuffer_byte;
  u32 offset;
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
  for (plane_index = 0; plane_index < 4 && active; ++plane_index) {
    SelectPlane(plane_index);
    for (row_offset = 0; row_offset < height && active; ++row_offset) {
      for (column_offset = 0; column_offset < width; ++column_offset) {
        offset = MultiplyWide(y + row_offset, display_pitch) +
                 ((x + column_offset) >> 3);
        framebuffer_byte = MapFramebufferByte(offset);
        if (!framebuffer_byte) {
          break;
        }
        *framebuffer_byte ^= 0x80 >> ((x + column_offset) & 7);
      }
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

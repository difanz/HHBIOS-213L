/* Bank-spanning planar stores. Logical B800 cells remain independent of the
 * physical surface, viewport and integer pixel enlargement. No heap or CRT. */
#include "vesa.h"

static void WritePortWord(u16 port_address, u16 value);
#pragma aux WritePortWord = "out dx,ax" parm[dx][ax];
static u8 ink[CELL_HEIGHT][6];
static u8 masks[6];

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

void CALL raster_cell(const u16* bits, u16 attribute, u16 position) {
  u16 x;
  u16 y;
  u16 source_row;
  u16 column_offset;
  u16 row_offset;
  u16 plane_index;
  u16 byte_count;
  u16 shift;
  u16 width;
  u16 bit_index;
  u16 byte_index;
  u8 foreground_mask;
  u8 background_mask;
  u8 value;
  u8 FAR* framebuffer_byte;
  u32 offset;
  if ((position & 255) >= TEXT_COLS || (position >> 8) > text_rows) {
    return;
  }
  x = viewport_x + (position & 255) * CELL_WIDTH * pixel_scale;
  y = viewport_y + (position >> 8) * raster_height * pixel_scale;
  shift = x & 7;
  width = CELL_WIDTH * pixel_scale;
  byte_count = (shift + width + 7) >> 3;
  for (byte_index = 0; byte_index < byte_count; ++byte_index) {
    masks[byte_index] = 0;
  }
  for (source_row = 0; source_row < raster_height; ++source_row) {
    for (byte_index = 0; byte_index < byte_count; ++byte_index) {
      ink[source_row][byte_index] = 0;
    }
    bit_index = shift;
    for (column_offset = 0; column_offset < CELL_WIDTH; ++column_offset) {
      for (row_offset = 0; row_offset < pixel_scale;
           ++row_offset, ++bit_index) {
        value = 0x80 >> (bit_index & 7);
        masks[bit_index >> 3] |= value;
        if (bits[source_row] & (0x8000 >> column_offset)) {
          ink[source_row][bit_index >> 3] |= value;
        }
      }
    }
  }
  for (plane_index = 0; plane_index < 4; ++plane_index) {
    SelectPlane(plane_index);
    foreground_mask = (attribute & (1 << plane_index)) ? 255 : 0;
    background_mask = (attribute & (16 << plane_index)) ? 255 : 0;
    offset = MultiplyWide(y, display_pitch) + (x >> 3);
    for (source_row = 0; source_row < raster_height; ++source_row) {
      for (row_offset = 0; row_offset < pixel_scale; ++row_offset) {
        for (byte_index = 0; byte_index < byte_count; ++byte_index) {
          framebuffer_byte = MapFramebufferByte(offset + byte_index);
          if (!framebuffer_byte) {
            return;
          }
          value = (ink[source_row][byte_index] &
                   (foreground_mask ^ background_mask)) ^
                  background_mask;
          *framebuffer_byte = masks[byte_index] == 255
                                  ? value
                                  : (*framebuffer_byte & ~masks[byte_index]) |
                                        (value & masks[byte_index]);
        }
        offset += display_pitch;
      }
    }
  }
  WritePortWord(0x3c4, 0x0f02);
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
  width = CELL_WIDTH * pixel_scale;
  height = ((lines * GLYPH_HEIGHT + 15) >> 4) * pixel_scale;
  x = viewport_x + (position & 255) * width;
  y = viewport_y +
      ((position >> 8) * raster_height + GLYPH_HEIGHT) * pixel_scale - height;
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

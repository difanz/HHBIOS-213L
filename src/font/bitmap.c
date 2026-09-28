/* Bitmap geometry is independent of DOS, memory managers and printer I/O. */
#include "bitmap.h"

#include "../common/font_file.h"

int DecodeBitmapFont(const FontByte* header, FontWord size, BitmapFont* font) {
  FontFileInfo info;
  BitmapFont decoded;
  if (!DecodeFontFile(header, &info) || info.format != 2 ||
      (size != 24 && size != 32 && size != 40) || info.width != size / 2 ||
      info.height != size) {
    return 0;
  }
  decoded.width = info.width;
  decoded.height = info.height;
  decoded.records = info.records;
  decoded.payload_bytes = info.payload_bytes;
  decoded.stride = size / 8;
  decoded.record_bytes = info.record_bytes;
  *font = decoded;
  return 1;
}

FontWord BitmapFontSlot(FontWord code) {
  FontWord lead = code >> 8;
  FontWord trail = code & 255;
  if (!lead) {
    return trail;
  }
  /* PRNT represents halfwidth characters in its otherwise unused zone 10. */
  if (lead == 0xaa) {
    return trail & 127;
  }
  if (lead < 0xa1 || lead > 0xf7 || trail < 0xa1 || trail > 0xfe) {
    return 0xffff;
  }
  return 256 + (lead - 0xa1) * 94 + trail - 0xa1;
}

static unsigned Pixel(const BitmapFont* font, const FontByte* glyph,
                      unsigned width, unsigned x, unsigned y,
                      unsigned attributes, unsigned rotate) {
  unsigned source_x = x;
  unsigned source_y = y;
  if (rotate && (attributes & 8)) {
    source_x = width - 1 - y;
    source_y = x;
  } else if (rotate && (attributes & 16)) {
    source_x = y;
    source_y = font->height - 1 - x;
  }
  if (attributes & 128) {
    source_x = width - 1 - source_x;
    source_y = font->height - 1 - source_y;
  }
  return (glyph[source_y * font->stride + source_x / 8] >> (7 - source_x % 8)) &
         1;
}

static unsigned StyledPixel(const BitmapFont* font, const FontByte* glyph,
                            unsigned width, unsigned x, unsigned y,
                            unsigned attributes, unsigned rotate) {
  unsigned pixel;
  if ((attributes & 2) && !y) {
    return 1;
  }
  if ((attributes & 4) && y == font->height - 1U) {
    return 1;
  }
  if (attributes & (32 | 64)) {
    unsigned half = font->height / 2;
    if (attributes & 32) {
      if (y >= half) {
        return 0;
      }
    } else {
      if (y < half) {
        return 0;
      }
      y -= half;
    }
    y *= 2;
    pixel = Pixel(font, glyph, width, x, y, attributes, rotate);
    return pixel | Pixel(font, glyph, width, x, y + 1, attributes, rotate);
  }
  return Pixel(font, glyph, width, x, y, attributes, rotate);
}

FontWord RenderPrintBand(const BitmapFont* font, const FontByte* glyph,
                         FontWord code, FontWord format, FontWord attributes,
                         FontWord band, FontByte* output) {
  /* Attribute bit 0 belongs to PRNT's final output stage, as in READ24.
   * Applying reverse video here too would cancel the printer's inversion. */
  unsigned size = font->height;
  unsigned halfwidth = code < 256 || (code >> 8) == 0xaa;
  unsigned width = halfwidth ? size / 2 : size;
  unsigned columns = width;
  unsigned interleaved = size == 24 && (format & 0xf0) == 0x10;
  unsigned scale = size == 24 ? 1 : ((format >> 2) & 3) + 1;
  unsigned height = size * scale;
  unsigned bands = (height + 23) / 24;
  unsigned x, y;
  if (interleaved) {
    if (format & 1) {
      columns = width * 3 / 2;
    } else if (!(format & 2)) {
      columns = width * 2 / 3;
    }
    if (format & 2) {
      bands = 2;
    }
  }
  for (x = 0; x < columns * 3; ++x) {
    output[x] = 0;
  }
  if (!glyph || (size != 24 && band >= bands) ||
      (interleaved && (format & 2) && band > 1)) {
    return (FontWord)columns;
  }
  for (x = 0; x < columns; ++x) {
    for (y = 0; y < 24; ++y) {
      unsigned source_y =
          size == 24 ? y : ((bands - 1 - band) * 24 + y) / scale;
      unsigned source_x = x;
      unsigned pixel;
      if (interleaved) {
        if (format & 2) {
          /* READ24's 36-pixel glyph occupies the bottom 36 rows of two bands.
           */
          unsigned row = (1 - band) * 24 + y;
          if (row < 12) {
            continue;
          }
          source_y = (row - 12) * 2 / 3;
        }
        if (format & 1) {
          source_x = (x * 2 + 1) / 3;
        } else if (!(format & 2)) {
          source_x = (x / 2) * 3 + x % 2;
        }
      }
      if (source_y >= size) {
        continue;
      }
      pixel = StyledPixel(font, glyph, width, source_x, source_y, attributes,
                          !halfwidth && (code >> 8) != 0xa9);
      if (interleaved && !(format & 3) && (x & 1)) {
        pixel |= StyledPixel(font, glyph, width, source_x + 1, source_y,
                             attributes, !halfwidth && (code >> 8) != 0xa9);
      }
      if (pixel) {
        output[x * 3 + y / 8] |= 128 >> (y % 8);
      }
    }
  }
  return (FontWord)columns;
}

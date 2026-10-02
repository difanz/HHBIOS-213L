/* HH Console 20: bounded glyph cache; XMS or EMS 4.0 owns the font payload.
 * File I/O and allocation occur only before display installation. */
#include "vesa.h"
#include "../../common/font_layout.h"

#define FONT_SLOTS 8434U
#define FONT_MAP_BYTES (FONT_SLOTS * 4UL)
#define FONT_RECORD 70U
#define FONT_MAP_CACHE 64U
/* 32 slots cover a 26-glyph alphabet plus a few misses. The arena, not
 * the slot count, is what decides whether those records stay resident. */
#define FONT_CACHE 28U

enum {
  kHalfGlyph = 0x8000U,
  kCroppedGlyph = 0x4000U,
  kCacheLengthMask = 0x3fffU
};

u32 CALL font_entry;
u16 CALL font_kind;
u16 CALL font_handle;
u16 CALL font_kb;
u16 CALL font_fault;
u16 CALL font_width = CELL_WIDTH;
u16 CALL font_height = CELL_HEIGHT;
u16 CALL font_body_height = GLYPH_HEIGHT;
u8 CALL font_extended;
u8 CALL font_selected;
char CALL font_name[64] = "HH20.FNT";
enum { kFontVariants = 4 };
static FontFileInfo fonts[kFontVariants];
static u32 font_offsets[kFontVariants];
static u16 font_count;
static u16 current_font = 0xffff;
static u32 glyph_storage;
static u16 record_bytes = FONT_RECORD;
static u16 record_count;
static u16 next_slot;
static u16 next_byte;
static u32 text_storage;
u8 CALL font_custom[256]; /* bit 0: application bitmap, bit 1: changed */
static u16 custom_active;
static u16 keys[FONT_CACHE];
static u16 cache_offsets[FONT_CACHE];
/* Upper bits describe the record; lower bits count its arena bytes.
 * Cropped records begin with two bytes: first row, then stored row count. */
static u16 cache_lengths[FONT_CACHE];
static u16 loaded_compact;
/* Bit 0: valid, bit 1: recently used (second-chance replacement). */
static u8 valid[FONT_CACHE];
/* A hint only: arena reuse and hash collisions still check the full key. */
static u8 lookup[64];
static u16 map_page = 0xffff;
/* The first 128 bytes cache record IDs. Variable-sized glyphs use the rest.
 * 2096 leaves 1968 bytes after the map: 28 HH20 records (1960) and 8 spare.
 * The bytes freed here pay for the install-time EMS check in the COM image. */
static u8 cache[2096];
/* One object: a 24x64 record is 384 bytes and is staged at large_glyph,
 * continuing into doubled_glyph. DrawLargeHalf uses the second half only
 * after that record has been copied into the cache. */
static struct {
  u32 wide[GLYPH_ROWS * 2];
  u32 half[GLYPH_ROWS * 2];
} glyph_buf;
#define large_glyph glyph_buf.wide
#define doubled_glyph glyph_buf.half
typedef char glyph_stage_holds_24x64[(sizeof(glyph_buf) >= 384) ? 1 : -1];
extern u8 CALL text_transfer[8192];
void CALL font_service(u16 kind, struct BiosRegisters* bios_registers);
u16 CALL font_snapshot(void);
void CALL font_unpack(const u8* source, u32* out, u16 width, u16 height,
                      u16 stride);
void CALL font_unpack_half(const u8* source, u32* out, u16 width, u16 height);

#pragma pack(push, 1)
struct XmsMoveRequest {
  u32 size;
  u16 source;
  u32 from;
  u16 destination;
  u32 to;
};
struct EmsMoveRequest {
  u32 size;
  u8 source_type;
  u16 source;
  u16 from;
  u16 source_page;
  u8 destination_type;
  u16 destination;
  u16 to;
  u16 destination_page;
};
#pragma pack(pop)

static void ClearBytes(void* buffer, u16 size) {
  u8* bytes = buffer;
  while (size--) {
    *bytes++ = 0;
  }
}

static void CopyBytes(void* destination, const void* source, u16 size);
#pragma aux CopyBytes = "push es" "push ds" "pop es" "rep movsb" "pop es" \
    parm [di] [si] [cx] modify [di si cx];

static u16 SameFontBytes(const u8* first, const u8* second);
#pragma aux SameFontBytes = \
    "push es" "push ds" "pop es" "mov cx,1024" "xor ax,ax" \
    "repe cmpsd" "jne different" "inc ax" "different:" "pop es" \
    parm [si] [di] value [ax] modify [si di cx];

static int TransferFontBytes(u32 offset, void* buffer, u16 size, u16 writing) {
  struct BiosRegisters bios_registers;
  struct XmsMoveRequest xms_move;
  struct EmsMoveRequest ems_move;
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.ds = resident_segment;
  if (font_kind == 1) {
    xms_move.size = size;
    xms_move.source = writing ? 0 : font_handle;
    xms_move.destination = writing ? font_handle : 0;
    xms_move.from =
        writing ? ((u32)resident_segment << 16) | (u16)buffer : offset;
    xms_move.to =
        writing ? offset : ((u32)resident_segment << 16) | (u16)buffer;
    bios_registers.ax = 0x0b00;
    bios_registers.si = (u16)&xms_move;
    font_service(3, &bios_registers);
    return bios_registers.ax == 1;
  }
  if (font_kind != 2) {
    return 0;
  }
  ClearBytes(&ems_move, sizeof(ems_move));
  ems_move.size = size;
  if (writing) {
    ems_move.from = (u16)buffer;
    ems_move.source_page = resident_segment;
    ems_move.destination_type = 1;
    ems_move.destination = font_handle;
    ems_move.to = (u16)offset & 0x3fff;
    ems_move.destination_page = (u16)(offset >> 14);
  } else {
    ems_move.source_type = 1;
    ems_move.source = font_handle;
    ems_move.from = (u16)offset & 0x3fff;
    ems_move.source_page = (u16)(offset >> 14);
    ems_move.to = (u16)buffer;
    ems_move.destination_page = resident_segment;
  }
  bios_registers.ax = 0x5700;
  bios_registers.si = (u16)&ems_move;
  font_service(2, &bios_registers);
  return !(bios_registers.ax & 0xff00);
}

/* Western records often contain an entirely empty second cell. Store only
 * the first cell, without resampling or dropping any nonzero source pixels.
 * Small records already fit the alphabet and avoid this extra cache format. */
static u16 CompactGlyph(u8* pixels, u16* format) {
  u16 stride = (font_width * 2 + 7) / 8;
  u16 half = (font_width + 7) / 8;
  u16 unused = font_width & 7;
  u16 x, y;
  u16 at = 0;
  u16 first = font_height;
  u16 last = 0;
  u16 length;
  for (y = 0; y < font_height; ++y) {
    if (unused && (pixels[y * stride + half - 1] & (255 >> unused))) {
      return 0;
    }
    for (x = half; x < stride; ++x) {
      if (pixels[y * stride + x]) {
        return 0;
      }
    }
    for (x = 0; x < half; ++x) {
      if (pixels[y * stride + x]) {
        if (first == font_height) {
          first = y;
        }
        last = y + 1;
        break;
      }
    }
  }
  *format = kHalfGlyph;
  if (half * font_height <= (sizeof(cache) - FONT_MAP_CACHE * 2) / 26) {
    first = 0;
    last = font_height;
  } else {
    if (!last) {
      first = 0;
    }
    length = (last - first) * half + 2;
    /* Crop whole blank rows only when this lets an alphabet fit. Dense
     * records stay raw rather than being repacked on every cache miss. */
    if (length > (sizeof(cache) - FONT_MAP_CACHE * 2) / 26) {
      return 0;
    }
    *format |= kCroppedGlyph;
  }
  for (y = first; y < last; ++y) {
    for (x = 0; x < half; ++x) {
      pixels[at++] = pixels[y * stride + x];
    }
  }
  if (*format & kCroppedGlyph) {
    /* Move backwards: a header inserted before packing could overwrite
     * source pixels when the first row contains ink. */
    for (x = at; x; --x) {
      pixels[x + 1] = pixels[x - 1];
    }
    pixels[0] = (u8)first;
    pixels[1] = (u8)(last - first);
    at += 2;
  }
  return at;
}

static void CacheGlyph(u16 index, u16 slot, u16 size) {
  u8* pixels = (u8*)large_glyph;
  u16 length = size;
  u16 compact = 0;
  u16 i;
  if (slot < 256 && size > FONT_RECORD) {
    i = CompactGlyph(pixels, &compact);
    if (i) {
      length = i;
    } else {
      compact = 0;
    }
  }
  if (next_byte + length > sizeof(cache) - FONT_MAP_CACHE * 2) {
    next_byte = 0;
  }
  /* Reusing arena bytes retires every overlapping entry before the copy. */
  for (i = 0; i < FONT_CACHE; ++i) {
    if (valid[i] && cache_offsets[i] < next_byte + length &&
        cache_offsets[i] + (cache_lengths[i] & kCacheLengthMask) > next_byte) {
      valid[i] = 0;
    }
  }
  cache_offsets[index] = next_byte;
  cache_lengths[index] = length | compact;
  CopyBytes(cache + FONT_MAP_CACHE * 2 + next_byte, pixels, length);
  next_byte += length;
  keys[index] = slot;
  valid[index] = 3;
}

static u8* LoadGlyph(u16 code) {
  u16 slot;
  u16 i;
  u16 record_index;
  u16 bucket;
  u8* glyph_data = (u8*)large_glyph;
  if (code < 256) {
    slot = (font_custom[code] & 1) ? code | 0x8000 : code;
  } else {
    if ((code >> 8) < 0xa1 || (code >> 8) > 0xf7 || (code & 255) < 0xa1 ||
        (code & 255) > 0xfe) {
      return 0;
    }
    slot = 256 + ((code >> 8) - 0xa1) * 94 + (code & 255) - 0xa1;
    if (!traditional) {
      slot += FONT_SLOTS;
    }
  }
  bucket = (slot ^ (slot >> 8)) & 63;
  i = lookup[bucket];
  if (!valid[i] || keys[i] != slot) {
    for (i = 0; i < FONT_CACHE; ++i) {
      if (valid[i] && keys[i] == slot) {
        break;
      }
    }
  }
  if (i == FONT_CACHE) {
    while (valid[next_slot] & 2) {
      valid[next_slot] &= ~2;
      if (++next_slot == FONT_CACHE) {
        next_slot = 0;
      }
    }
    i = next_slot;
    if (++next_slot == FONT_CACHE) {
      next_slot = 0;
    }
    valid[i] = 0;
    if (slot & 0x8000) {
      if (!TransferFontBytes(text_storage + 32768UL + (u32)code * 16,
                             glyph_data, 16, 0)) {
        font_fault = 1;
        return 0;
      }
    } else {
      u16 page = slot & ~(FONT_MAP_CACHE - 1);
      if (page != map_page) {
        u16 count = FONT_SLOTS * 2 - page;
        if (count > FONT_MAP_CACHE) {
          count = FONT_MAP_CACHE;
        }
        map_page = 0xffff;
        if (!TransferFontBytes(glyph_storage + (u32)page * 2, cache, count * 2, 0)) {
          font_fault = 1;
          return 0;
        }
        map_page = page;
      }
      record_index = ((u16*)cache)[slot - map_page];
      if (record_index >= record_count ||
          !TransferFontBytes(
              glyph_storage + FONT_MAP_BYTES + MultiplyWide(record_index, record_bytes),
              glyph_data, record_bytes, 0)) {
        font_fault = 1;
        return 0;
      }
    }
    CacheGlyph(i, slot, (slot & 0x8000) ? 16 : record_bytes);
  }
  valid[i] |= 2;
  lookup[bucket] = (u8)i;
  loaded_compact = cache_lengths[i] & kHalfGlyph;
  glyph_data = cache + FONT_MAP_CACHE * 2 + cache_offsets[i];
  if (cache_lengths[i] & kCroppedGlyph) {
    u16 half = (font_width + 7) / 8;
    u8* expanded = (u8*)doubled_glyph;
    ClearBytes(expanded, half * font_height);
    CopyBytes(expanded + glyph_data[0] * half, glyph_data + 2,
              glyph_data[1] * half);
    return expanded;
  }
  return glyph_data;
}

void CALL font_get(u16 code, u16* out) {
  u16 x;
  u16 y;
  u16 bits;
  u8* glyph_data = LoadGlyph(code);
  ClearBytes(out, CELL_HEIGHT * 4);
  if (!glyph_data) {
    return;
  }
  if (code < 256 && (font_custom[code] & 1)) {
    /* Downloaded UI glyphs fill the complete cell, including its edges. */
    for (y = 0; y < CELL_HEIGHT; ++y) {
      bits = 0;
      for (x = 0; x < CELL_WIDTH; ++x) {
        bits = (bits << 1) |
               ((glyph_data[y * 16 / CELL_HEIGHT] >> (7 - x * 8 / CELL_WIDTH)) &
                1);
      }
      out[y] = bits << 6;
    }
    return;
  }
  for (y = 0; y < CELL_HEIGHT; ++y, glyph_data += 3) {
    out[y] = (((u16)glyph_data[0] << 8) | glyph_data[1]) & 0xffc0;
    out[y + CELL_HEIGHT] =
        ((u16)glyph_data[1] << 10) | ((u16)glyph_data[2] << 2);
  }
}

static void ScaleBitmap(const u8* source, u32* out) {
  u16 x;
  u16 y;
  for (y = 0; y < font_height; ++y) {
    u32 bits = 0;
    for (x = 0; x < font_width; ++x) {
      bits = (bits << 1) |
             ((source[y * 16 / font_height] >> (7 - x * 8 / font_width)) & 1);
    }
    out[y] = bits << (32 - font_width);
  }
}

void CALL font_get_large(u16 code, u32* out) {
  u16 stride = (font_width * 2 + 7) / 8;
  u8* pixels = LoadGlyph(code);
  if (!pixels) {
    ClearBytes(out, MAX_FONT_HEIGHT * 8);
    return;
  }
  if (code < 256 && (font_custom[code] & 1)) {
    ClearBytes(out, MAX_FONT_HEIGHT * 8);
    ScaleBitmap(pixels, out);
    return;
  }
  if (loaded_compact) {
    font_unpack_half(pixels, out, font_width, font_height);
  } else {
    font_unpack(pixels, out, font_width, font_height, stride);
  }
}

static void DrawLargeHalf(const u32* bits, u16 attribute, u16 position,
                          u16 wide) {
  u16 x;
  u16 y;
  if (!wide) {
    raster_large_cell(bits, attribute, position);
    return;
  }
  ClearBytes(doubled_glyph, sizeof(doubled_glyph));
  for (y = 0; y < font_height && y < GLYPH_ROWS; ++y) {
    for (x = 0; x < font_width * 2; ++x) {
      if (bits[y] & (0x80000000UL >> (x / 2))) {
        doubled_glyph[y + (x >= font_width ? GLYPH_ROWS : 0)] |=
            0x80000000UL >> (x % font_width);
      }
    }
  }
  raster_large_cell(doubled_glyph, attribute, position);
  if ((position & 255) < TEXT_COLS - 1) {
    raster_large_cell(doubled_glyph + GLYPH_ROWS, attribute, position + 1);
  }
}

void CALL font_draw(u16 code, u16 attribute, u16 position, u16 wide) {
  /* Scale belongs to the linear painter. Planar scale still unpacks. */
  if (wide == 1 && (pixel_scale == 1 || linear_color) &&
      (code >= 256 || !(font_custom[code] & 1))) {
    u8* pixels = LoadGlyph(code);
    u16 stride = ((loaded_compact ? font_width : font_width * 2) + 7) / 8;
    if (!pixels) {
      stride = (font_width * 2 + 7) / 8;
      ClearBytes(large_glyph, stride * raster_height);
      pixels = (u8*)large_glyph;
    }
    raster_packed_cell(pixels, code < 256 ? attribute : attribute >> 8,
                       position, stride, 0);
    if (code >= 256 && (position & 255) < TEXT_COLS - 1) {
      raster_packed_cell(pixels, attribute & 255, position + 1, stride,
                         font_width);
    }
    return;
  }
  font_get_large(code, large_glyph);
  DrawLargeHalf(large_glyph, code < 256 ? attribute : attribute >> 8, position,
                wide == 2);
  if (code >= 256 && (position & 255) + wide < TEXT_COLS) {
    DrawLargeHalf(large_glyph + GLYPH_ROWS, attribute & 255,
                  position + wide, wide == 2);
  }
}

void CALL font_bitmap_draw(const u8* source, u16 attribute, u16 position) {
  ScaleBitmap(source, large_glyph);
  raster_large_cell(large_glyph, attribute, position);
}

/* Reuse the bank-switch scratch buffer to compare downloaded VGA font RAM
 * with its previous XMS/EMS copy. Only changed glyphs invalidate cells/cache.
 * The 4 KiB payload costs no additional conventional resident memory. */
void CALL font_sync(void) {
  u16 code;
  u16 y;
  u16 i;
  u16 changed;
  u16 custom;
  u16 any = 0;
  u16 was;
  u8 FAR* rom = PTR(u8, font_segment, font_offset);
  u8* current = text_transfer + 4096;
  if (!font_snapshot()) {
    if (!custom_active) {
      return;
    }
    custom_active = 0;
    ClearBytes(font_custom, sizeof(font_custom));
    ClearBytes(valid, sizeof(valid));
    invalidate();
    invalidate_prompt();
    return;
  }
  if (custom_active &&
      !TransferFontBytes(text_storage + 32768UL, text_transfer, 4096, 0)) {
    font_fault = 1;
    return;
  }
  if (custom_active && SameFontBytes(current, text_transfer)) {
    return;
  }
  for (code = 0; code < 256; ++code) {
    was = font_custom[code] & 1;
    custom = 0;
    changed = !custom_active;
    for (y = 0; y < 16; ++y) {
      i = code * 16 + y;
      if (current[i] != rom[i]) {
        custom = 1;
      }
      if (custom_active && current[i] != text_transfer[i]) {
        changed = 1;
      }
    }
    font_custom[code] = (u8)(custom | ((changed && (was || custom)) ? 2 : 0));
    if (changed) {
      any = 1;
    }
  }
  if (any && !TransferFontBytes(text_storage + 32768UL, current, 4096, 1)) {
    font_fault = 1;
    ClearBytes(font_custom, sizeof(font_custom));
    invalidate_prompt();
    return;
  }
  if (any) {
    invalidate_prompt();
  }
  for (i = 0; i < FONT_CACHE; ++i) {
    if (valid[i] && (keys[i] & 0x8000) && (font_custom[keys[i] & 255] & 2)) {
      valid[i] = 0;
    }
  }
  if (!custom_active) {
    invalidate();
  } else {
    for (i = 0; i < text_cells; ++i) {
      if (font_custom[shadow[i] & 255] & 2) {
        shadow[i] ^= 0xff00;
      }
    }
  }
  custom_active = 1;
}

/* HHBIOS's public 8x16 bitmap interface retains its original input format. */
void CALL font_bitmap(u8* source, u16* out) {
  u16 x;
  u16 y;
  u16 bits;
  for (y = 0; y < 20; ++y) {
    bits = 0;
    for (x = 0; x < 10; ++x) {
      bits = (bits << 1) | ((source[y * 16 / 20] >> (7 - x * 8 / 10)) & 1);
    }
    out[y] = bits << 6;
  }
  for (; y < CELL_HEIGHT; ++y) {
    out[y] = 0;
  }
}

/* Preserve the entire B800 aperture across a physical mode/bank probe. The
 * extra 32 KiB lives in the existing XMS/EMS allocation, not conventional RAM.
 */
u16 CALL font_text(u16 saving) {
  u16 text_offset;
  u16 i;
  u8 FAR* text = PTR(u8, 0xb800, 0);
  for (text_offset = 0; text_offset < 32768; text_offset += 4096) {
    if (saving) {
      for (i = 0; i < 4096; ++i) {
        text_transfer[i] = text[text_offset + i];
      }
    }
    if (!TransferFontBytes(text_storage + text_offset, text_transfer, 4096,
                           saving)) {
      return 0;
    }
    if (!saving) {
      for (i = 0; i < 4096; ++i) {
        text[text_offset + i] = text_transfer[i];
      }
    }
  }
  return 1;
}

void CALL font_close(void) {
  struct BiosRegisters bios_registers;
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.dx = font_handle;
  if (font_kind) {
    bios_registers.ax = font_kind == 1 ? 0x0a00 : 0x4500;
    font_service(font_kind == 1 ? 3 : 2, &bios_registers);
  }
  font_kind = font_handle = 0;
  font_count = 0;
  current_font = 0xffff;
  map_page = 0xffff;
  next_slot = 0;
  next_byte = 0;
  ClearBytes(valid, sizeof(valid));
}

/* All variants are preloaded. BIOS calls can change rows without opening a
 * file or entering DOS while DOS itself is busy writing to the console. */
u16 CALL font_choose(u16 width, u16 height, u16 rows, u16 apply) {
  FontLayout layout;
  u16 best = 0xffff;
  u16 i;
  for (i = 0; i < font_count; ++i) {
    if (BetterFont(&fonts[i], best == 0xffff ? 0 : &fonts[best],
                    width, height, rows)) {
      best = i;
    }
  }
  if (best == 0xffff) {
    return 0;
  }
  if (apply) {
    FitFont(&fonts[best], width, height, rows, &layout);
    pixel_scale = layout.scale;
    raster_height = layout.height;
  }
  if (apply && best != current_font) {
    current_font = best;
    glyph_storage = font_offsets[best];
    font_width = fonts[best].width;
    font_height = fonts[best].height;
    font_extended = (u8)(fonts[best].format == 2);
    font_body_height = font_extended ? font_height : GLYPH_HEIGHT;
    record_bytes = fonts[best].record_bytes;
    record_count = fonts[best].records;
    map_page = 0xffff;
    next_slot = 0;
    next_byte = 0;
    ClearBytes(valid, sizeof(valid));
  }
  return 1;
}

#pragma code_seg("INIT_TEXT", "INIT")
static int AllocateFontStorage(u16 kb) {
  struct BiosRegisters bios_registers;
  u8 FAR* name;
  u16 i;
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.ax = 0x4300;
  font_service(1, &bios_registers);
  if ((bios_registers.ax & 255) == 0x80) {
    bios_registers.ax = 0x4310;
    font_service(1, &bios_registers);
    font_entry = ((u32)bios_registers.es << 16) | bios_registers.bx;
    bios_registers.ax = 0x0900;
    bios_registers.dx = kb;
    font_service(3, &bios_registers);
    if (bios_registers.ax == 1) {
      font_handle = bios_registers.dx;
      font_kind = 1;
      return 1;
    }
  }
  /* Check the EMS device signature before invoking an arbitrary INT 67. */
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.ax = 0x3567;
  font_service(0, &bios_registers);
  name = PTR(u8, bios_registers.es, 10);
  for (i = 0; i < 8; ++i) {
    if (name[i] != "EMMXXXX0"[i]) {
      return 0;
    }
  }
  bios_registers.ax = 0x4600;
  font_service(2, &bios_registers);
  if ((bios_registers.ax & 0xff00) || (bios_registers.ax & 255) < 0x40) {
    return 0;
  }
  bios_registers.ax = 0x4300;
  bios_registers.bx = (kb + 15) / 16;
  font_service(2, &bios_registers);
  if (bios_registers.ax & 0xff00) {
    return 0;
  }
  font_handle = bios_registers.dx;
  font_kind = 2;
  return 1;
}

struct FontCandidate {
  FontFileInfo info;
  char name[64];
};

static u16 OpenFont(const char* name, struct BiosRegisters* regs) {
  ClearBytes(regs, sizeof(*regs));
  regs->ax = 0x3d00;
  regs->ds = resident_segment;
  regs->dx = (u16)name;
  font_service(0, regs);
  return !(regs->flags & 1);
}

static void CloseFont(u16 file, struct BiosRegisters* regs) {
  regs->ax = 0x3e00;
  regs->bx = file;
  font_service(0, regs);
}

static int ReadFontInfo(const char* name, struct FontCandidate* candidate) {
  struct BiosRegisters regs;
  FontFileInfo info;
  u16 file;
  u16 i;
  int valid = 0;
  if (!OpenFont(name, &regs)) {
    return 0;
  }
  file = regs.ax;
  regs.ax = 0x3f00;
  regs.bx = file;
  regs.cx = 32;
  regs.dx = (u16)text_transfer;
  font_service(0, &regs);
  if (!(regs.flags & 1) && regs.ax == 32 && DecodeFontFile(text_transfer, &info)) {
    regs.ax = 0x4202;
    regs.bx = file;
    regs.cx = regs.dx = 0;
    font_service(0, &regs);
    valid = !(regs.flags & 1) &&
            (((u32)regs.dx << 16) | regs.ax) == info.payload_bytes + 32;
  }
  CloseFont(file, &regs);
  if (!valid) {
    return 0;
  }
  candidate->info = info;
  for (i = 0; name[i] && i < 63; ++i) {
    candidate->name[i] = name[i];
  }
  candidate->name[i] = 0;
  return 1;
}

static void ConsiderFont(const struct FontCandidate* candidate,
                          struct FontCandidate* best, u16 width, u16 height) {
  static const u16 rows[3] = {25, 43, 50};
  u16 i;
  if (!banked_text_allowed && candidate->info.format != 1) {
    return;
  }
  for (i = 0; i < 3; ++i) {
    if (BetterFont(&candidate->info, &best[i].info,
                    width, height, rows[i])) {
      best[i] = *candidate;
    }
  }
  /* HH20 is the normal fallback for applications selecting taller text
   * grids. A pack without HH20 can use its smallest native cell instead. */
  if (best[3].info.format != 1 &&
      (!best[3].info.width || candidate->info.format == 1 ||
       candidate->info.height < best[3].info.height ||
       (candidate->info.height == best[3].info.height &&
        candidate->info.width < best[3].info.width))) {
    best[3] = *candidate;
  }
}

static void FindFonts(struct FontCandidate* best, u16 width, u16 height) {
  struct BiosRegisters regs;
  struct FontCandidate candidate;
  u8 dta[43];
  u16 dta_segment;
  u16 dta_offset;
  u16 count;
  static const char pattern[] = "F????.FNT";
  ClearBytes(best, sizeof(*best) * kFontVariants);
  if (ReadFontInfo("HH20.FNT", &candidate)) {
    ConsiderFont(&candidate, best, width, height);
  }
  ClearBytes(&regs, sizeof(regs));
  regs.ax = 0x2f00;
  font_service(0, &regs);
  dta_segment = regs.es;
  dta_offset = regs.bx;
  regs.ax = 0x1a00;
  regs.ds = resident_segment;
  regs.dx = (u16)dta;
  font_service(0, &regs);
  regs.ax = 0x4e00;
  regs.cx = 0;
  regs.dx = (u16)pattern;
  font_service(0, &regs);
  for (count = 0; !(regs.flags & 1) && count < 256; ++count) {
    u16 length = 0;
    while (length < 13 && dta[30 + length]) {
      ++length;
    }
    if (length == 9 && ReadFontInfo((const char*)dta + 30, &candidate)) {
      ConsiderFont(&candidate, best, width, height);
    }
    regs.ax = 0x4f00;
    font_service(0, &regs);
  }
  regs.ax = 0x1a00;
  regs.ds = dta_segment;
  regs.dx = dta_offset;
  font_service(0, &regs);
}

static int SameName(const char* first, const char* second) {
  while (*first && *first == *second) {
    ++first;
    ++second;
  }
  return *first == *second;
}

static u16 ChooseFiles(struct FontCandidate* files) {
  struct FontCandidate best[kFontVariants];
  struct FontCandidate fallback[kFontVariants];
  struct VbeSurface surface;
  struct BiosRegisters regs;
  u8 info[256];
  u16 order[kFontVariants];
  u16 count = 0;
  u16 i;
  u16 j;
  FontLayout layout;
  if (font_selected) {
    return ReadFontInfo(font_name, files) &&
           (banked_text_allowed || files[0].info.format == 1) &&
           FitFont(&files[0].info, screen.width, screen.height,
                    requested_rows, &layout);
  }
  FindFonts(best, screen.width, screen.height);
  order[0] = requested_rows == 50 ? 2 : requested_rows == 43 ? 1 : 0;
  if (!best[order[0]].info.width) {
    return 0;
  }
  /* A short surface may need a larger physical mode for 43/50 rows. Load
   * those strikes now too; SetTextRows uses the same two BIOS fallbacks. */
  for (i = 0; banked_text_allowed && i < 2 &&
              (!best[1].info.width || !best[2].info.width); ++i) {
    ClearBytes(&regs, sizeof(regs));
    ClearBytes(info, sizeof(info));
    regs.ax = 0x4f01;
    regs.cx = i ? 0x106 : 0x104;
    regs.es = resident_segment;
    regs.di = (u16)info;
    bios(&regs);
    if (regs.ax != 0x004f || !info[29] ||
        !DecodeConsoleModeInfo(&surface, info, 0x102, i ? 0x106 : 0x104) ||
        !(info[2 + surface.window] & 1)) {
      continue;
    }
    FindFonts(fallback, surface.width, surface.height);
    for (j = 1; j < 3; ++j) {
      if (!best[j].info.width) {
        best[j] = fallback[j];
      }
    }
  }
  order[1] = 3;
  order[2] = (order[0] + 1) % 3;
  order[3] = (order[0] + 2) % 3;
  for (i = 0; i < kFontVariants; ++i) {
    if (!best[order[i]].info.width) {
      continue;
    }
    for (j = 0; j < count; ++j) {
      if (SameName(files[j].name, best[order[i]].name)) {
        break;
      }
    }
    if (j == count) {
      files[count++] = best[order[i]];
    }
  }
  return count;
}

static int LoadFontFile(const struct FontCandidate* candidate, u32 destination) {
  struct BiosRegisters bios_registers;
  FontFileInfo info;
  u16 file;
  u16 count;
  u16 ok = 0;
  u32 length = candidate->info.payload_bytes;
  u32 offset;
  if (!OpenFont(candidate->name, &bios_registers)) {
    return 0;
  }
  file = bios_registers.ax;
  bios_registers.ax = 0x3f00;
  bios_registers.bx = file;
  bios_registers.cx = 32;
  bios_registers.dx = (u16)text_transfer;
  font_service(0, &bios_registers);
  if ((bios_registers.flags & 1) || bios_registers.ax != 32 ||
      !DecodeFontFile(text_transfer, &info) ||
      info.format != candidate->info.format ||
      info.width != candidate->info.width || info.height != candidate->info.height ||
      info.payload_bytes != length) {
    goto done;
  }
  for (offset = 0; offset < length; offset += count) {
    count = length - offset > 4096 ? 4096 : (u16)(length - offset);
    bios_registers.ax = 0x3f00;
    bios_registers.bx = file;
    bios_registers.cx = count;
    bios_registers.dx = (u16)text_transfer;
    font_service(0, &bios_registers);
    if ((bios_registers.flags & 1) || bios_registers.ax != count ||
        !TransferFontBytes(destination + offset, text_transfer, count, 1)) {
      goto done;
    }
  }
  bios_registers.ax = 0x3f00;
  bios_registers.bx = file;
  bios_registers.cx = 1;
  bios_registers.dx = (u16)text_transfer;
  font_service(0, &bios_registers);
  ok = !(bios_registers.flags & 1) && !bios_registers.ax;
done:
  CloseFont(file, &bios_registers);
  return ok;
}

u16 CALL font_open(void) {
  struct FontCandidate files[kFontVariants];
  u16 count = ChooseFiles(files);
  u16 i;
  if (!count) {
    return 0;
  }
  /* Optional row sizes yield to the requested size on a small machine.
   * No duplicate payload is stored when several layouts select one file. */
  while (count) {
    text_storage = 0;
    for (i = 0; i < count; ++i) {
      font_offsets[i] = text_storage;
      text_storage += files[i].info.payload_bytes;
    }
    font_kb = (u16)((text_storage + 1023) >> 10);
    if (AllocateFontStorage(font_kb + 36)) {
      break;
    }
    --count;
  }
  if (!count) {
    return 0;
  }
  for (i = 0; i < count; ++i) {
    if (!LoadFontFile(&files[i], font_offsets[i])) {
      font_close();
      return 0;
    }
    fonts[i] = files[i].info;
  }
  font_count = count;
  current_font = 0xffff;
  return font_choose(screen.width, screen.height, requested_rows, 1);
}

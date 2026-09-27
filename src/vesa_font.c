/* HH Console 20: bounded glyph cache; XMS or EMS 4.0 owns the font payload.
 * File I/O and allocation occur only before display installation. */
#include "vesa.h"

#define FONT_SLOTS 8434U
#define FONT_MAP_BYTES (FONT_SLOTS * 4UL)
#define FONT_RECORD 70U
#define FONT_CACHE 16U

u32 CALL font_entry;
u16 CALL font_kind;
u16 CALL font_handle;
u16 CALL font_kb;
u16 CALL font_fault;
u16 CALL font_width = CELL_WIDTH;
u16 CALL font_height = CELL_HEIGHT;
u16 CALL font_body_height = GLYPH_HEIGHT;
u8 CALL font_extended;
char CALL font_name[64] = "HH20.FNT";
static u16 record_bytes = FONT_RECORD;
static u16 cache_slots = FONT_CACHE;
static u16 record_count;
static u16 next_slot;
static u32 text_storage;
u8 CALL font_custom[256]; /* bit 0: application bitmap, bit 1: changed */
static u16 custom_active;
static u16 keys[FONT_CACHE];
static u16 valid[FONT_CACHE];
/* Small fonts retain 16 slots; the largest 48x64 font has five. */
static u8 cache[2048];
static u32 large_glyph[MAX_FONT_HEIGHT * 2];
static u32 doubled_glyph[MAX_FONT_HEIGHT * 2];
extern u8 CALL text_transfer[8192];
void CALL font_service(u16 kind, struct BiosRegisters* bios_registers);
u16 CALL font_snapshot(void);
void CALL font_unpack(const u8* source, u32* out, u16 width, u16 height,
                      u16 stride);

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

static u8* LoadGlyph(u16 code) {
  u16 slot;
  u16 i;
  u16 record_index;
  u8* glyph_data;
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
  for (i = 0; i < cache_slots; ++i) {
    if (valid[i] && keys[i] == slot) {
      break;
    }
  }
  if (i == cache_slots) {
    i = next_slot;
    next_slot = (next_slot + 1) % cache_slots;
    valid[i] = 0;
    glyph_data = cache + i * record_bytes;
    if (slot & 0x8000) {
      if (!TransferFontBytes(text_storage + 32768UL + (u32)code * 16,
                             glyph_data, 16, 0)) {
        font_fault = 1;
        return 0;
      }
    } else if (!TransferFontBytes((u32)slot * 2, &record_index, 2, 0) ||
               record_index >= record_count ||
               !TransferFontBytes(
                   FONT_MAP_BYTES + MultiplyWide(record_index, record_bytes),
                   glyph_data, record_bytes, 0)) {
      font_fault = 1;
      return 0;
    }
    keys[i] = slot;
    valid[i] = 1;
  }
  return cache + i * record_bytes;
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
  font_unpack(pixels, out, font_width, font_height, stride);
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
  for (y = 0; y < font_height; ++y) {
    for (x = 0; x < font_width * 2; ++x) {
      if (bits[y] & (0x80000000UL >> (x / 2))) {
        doubled_glyph[y + (x >= font_width ? MAX_FONT_HEIGHT : 0)] |=
            0x80000000UL >> (x % font_width);
      }
    }
  }
  raster_large_cell(doubled_glyph, attribute, position);
  if ((position & 255) < TEXT_COLS - 1) {
    raster_large_cell(doubled_glyph + MAX_FONT_HEIGHT, attribute, position + 1);
  }
}

void CALL font_draw(u16 code, u16 attribute, u16 position, u16 wide) {
  font_get_large(code, large_glyph);
  DrawLargeHalf(large_glyph, code < 256 ? attribute : attribute >> 8, position,
                wide == 2);
  if (code >= 256 && (position & 255) + wide < TEXT_COLS) {
    DrawLargeHalf(large_glyph + MAX_FONT_HEIGHT, attribute & 255,
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
    return;
  }
  if (custom_active &&
      !TransferFontBytes(text_storage + 32768UL, text_transfer, 4096, 0)) {
    font_fault = 1;
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
    return;
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

u16 CALL font_open(void) {
  struct BiosRegisters bios_registers;
  u16 file;
  u16 count;
  u16 i;
  u16 ok = 0;
  u32 length;
  u32 offset;
  ClearBytes(&bios_registers, sizeof(bios_registers));
  bios_registers.ax = 0x3d00;
  bios_registers.ds = resident_segment;
  bios_registers.dx = (u16)font_name;
  font_service(0, &bios_registers);
  if (bios_registers.flags & 1) {
    return 0;
  }
  file = bios_registers.ax;
  bios_registers.ax = 0x3f00;
  bios_registers.bx = file;
  bios_registers.cx = 32;
  bios_registers.dx = (u16)text_transfer;
  font_service(0, &bios_registers);
  if ((bios_registers.flags & 1) || bios_registers.ax != 32) {
    goto done;
  }
  font_extended = 1;
  for (i = 0; i < 8; ++i) {
    if (text_transfer[i] != "HHFONT2\n"[i]) {
      font_extended = 0;
    }
  }
  if (!font_extended) {
    for (i = 0; i < 8; ++i) {
      if (text_transfer[i] != "HH20F01\n"[i]) {
        goto done;
      }
    }
  }
  font_width = *(u16*)(text_transfer + 8);
  font_height = *(u16*)(text_transfer + 10);
  if (font_width < 8 || font_width > MAX_FONT_WIDTH || font_height < 16 ||
      font_height > MAX_FONT_HEIGHT ||
      (!font_extended &&
       (font_width != CELL_WIDTH || font_height != CELL_HEIGHT)) ||
      *(u16*)(text_transfer + 12) != FONT_SLOTS) {
    goto done;
  }
  for (i = 20; i < 32; ++i) {
    if (text_transfer[i]) {
      goto done;
    }
  }
  font_body_height = font_extended ? font_height : GLYPH_HEIGHT;
  record_bytes = (((font_width * 2 + 7) / 8) * font_height + 1) & ~1U;
  cache_slots = sizeof(cache) / record_bytes;
  if (cache_slots > FONT_CACHE) {
    cache_slots = FONT_CACHE;
  }
  record_count = *(u16*)(text_transfer + 14);
  length = *(u32*)(text_transfer + 16);
  if (!record_count || record_count > FONT_SLOTS * 2 ||
      length != FONT_MAP_BYTES + MultiplyWide(record_count, record_bytes)) {
    goto done;
  }
  font_kb = (u16)((length + 1023) >> 10);
  text_storage = length;
  if (!AllocateFontStorage(font_kb + 36)) {
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
        !TransferFontBytes(offset, text_transfer, count, 1)) {
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
  bios_registers.ax = 0x3e00;
  bios_registers.bx = file;
  font_service(0, &bios_registers);
  if (!ok) {
    font_close();
  }
  return ok;
}

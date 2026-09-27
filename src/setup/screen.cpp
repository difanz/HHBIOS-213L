/* Standalone 8086 VGA backend. Turbo Vision still owns layout, focus,
 * dialogs and events; only its final character buffer is rasterized here.
 * No hooks, TSR, XMS, EMS or protected mode. HZK16 is normal process memory. */
#define Uses_TScreen
#define Uses_TEvent
#define Uses_TEventQueue
#include "screen.h"

#include <alloc.h>
#include <dos.h>
#include <stdio.h>
#include <string.h>
#include <tvision/tv.h>

static ushort far cells[80 * 30], previous[80 * 30];
static short far previous_glyph[80 * 30];
static unsigned char far latin[256 * 16];
static int active;
static int mouse_present;
static unsigned old_mode;
static unsigned mouse_buttons;
static unsigned mouse_x;
static unsigned mouse_y;
static unsigned last_down;
static unsigned repeat_at;
static ushort* old_buffer;
static unsigned char far* font_blocks[8];
/* CP437 frames and GB2312 share byte values. Encode Chinese UI characters
 * into unused Western slots before giving strings to Turbo Vision. Each Han
 * still occupies exactly two cells. Frame bytes B0..DF are never ambiguous.
 * This maps character codes, not font subsets; all HZK16 glyphs are loaded. */
static unsigned far han_codes[4096];
static unsigned han_count;
static char far text_pool[16384];
static unsigned text_used;
static unsigned text_count;
static const char *source_text[128], *encoded_text[128];

const char* EncodeScreenText(const char* text) {
  unsigned i;
  unsigned code;
  unsigned slot;
  const unsigned char* source = (const unsigned char*)text;
  char *encoded, *encoded_start;
  for (i = 0; i < text_count; ++i) {
    if (source_text[i] == text) {
      return encoded_text[i];
    }
  }
  if (text_count == 128 || strlen(text) + text_used + 1 > sizeof(text_pool)) {
    return "Text buffer full";
  }
  encoded = encoded_start = text_pool + text_used;
  while (*source) {
    if (source[0] >= 0xa1 && source[0] <= 0xf7 && source[1] >= 0xa1 &&
        source[1] <= 0xfe) {
      code = (source[0] << 8) | source[1];
      for (slot = 0; slot < han_count && han_codes[slot] != code; ++slot) {
      }
      if (slot == han_count) {
        if (han_count == 4096) {
          return "Character map full";
        }
        han_codes[han_count++] = code;
      }
      *encoded++ = (char)(0x80 + slot / 94);
      *encoded++ = (char)(0xa1 + slot % 94);
      source += 2;
    } else {
      *encoded++ = *source++;
    }
  }
  *encoded++ = 0;
  text_used = (unsigned)(encoded - text_pool);
  source_text[text_count] = text;
  encoded_text[text_count++] = encoded_start;
  return encoded_start;
}

static void FreeFont() {
  for (unsigned i = 0; i < 8; ++i) {
    if (font_blocks[i]) {
      farfree(font_blocks[i]);
      font_blocks[i] = 0;
    }
  }
}

static int LoadFont() {
  FILE* file = fopen("HZK16", "rb");
  if (!file) {
    return 0;
  }
  for (unsigned i = 0; i < 8; ++i) {
    unsigned block_bytes = i == 7 ? 32320U : 32768U;
    font_blocks[i] = (unsigned char far*)farmalloc(block_bytes);
    if (!font_blocks[i] ||
        fread(font_blocks[i], 1, block_bytes, file) != block_bytes) {
      fclose(file);
      FreeFont();
      return 0;
    }
  }
  fclose(file);
  return 1;
}

static void CallMouse(unsigned ax, unsigned cx = 0, unsigned dx = 0) {
  union REGS bios_registers;
  memset(&bios_registers, 0, sizeof(bios_registers));
  bios_registers.x.ax = ax;
  bios_registers.x.cx = cx;
  bios_registers.x.dx = dx;
  int86(0x33, &bios_registers, &bios_registers);
}

int StartScreen() {
  union REGS bios_registers;
  struct REGPACK font;
  if (!LoadFont()) {
    return 0;
  }
  memset(&font, 0, sizeof(font));
  font.r_ax = 0x1130;
  font.r_bx = 0x0600;
  intr(0x10, &font);
  _fmemcpy(latin, MK_FP(font.r_es, font.r_bp), sizeof(latin));
  old_mode = TScreen::screenMode;
  old_buffer = TScreen::screenBuffer;
  TEventQueue::suspend();
  memset(&bios_registers, 0, sizeof(bios_registers));
  bios_registers.x.ax = 0x12;
  int86(0x10, &bios_registers, &bios_registers);
  bios_registers.h.ah = 0x0f;
  int86(0x10, &bios_registers, &bios_registers);
  if ((bios_registers.h.al & 0x7f) != 0x12) {
    bios_registers.x.ax = old_mode & 255;
    int86(0x10, &bios_registers, &bios_registers);
    TEventQueue::resume();
    FreeFont();
    return 0;
  }
  memset(cells, 0, sizeof(cells));
  memset(previous, 0xff, sizeof(previous));
  memset(previous_glyph, 0xff, sizeof(previous_glyph));
  TScreen::screenBuffer = cells;
  TScreen::screenWidth = 80;
  TScreen::screenHeight = 30;
  TScreen::checkSnow = False;
  active = 1;
  bios_registers.x.ax = 0;
  int86(0x33, &bios_registers, &bios_registers);
  mouse_present = bios_registers.x.ax == 0xffff;
  if (mouse_present) {
    CallMouse(7, 0, 639);
    CallMouse(8, 0, 479);
    CallMouse(1);
  }
  return 1;
}

int IsScreenActive() {
  return active;
}

static int FindHanziSlot(unsigned code) {
  unsigned lead_byte = code >> 8;
  unsigned trail_byte = code & 255;
  unsigned slot;
  if (lead_byte < 0x80 || lead_byte >= 0xb0 || trail_byte < 0xa1 ||
      trail_byte > 0xfe) {
    return -1;
  }
  slot = (lead_byte - 0x80) * 94 + trail_byte - 0xa1;
  return slot < han_count ? (int)slot : -1;
}

static void PaintCell(unsigned index, int hanzi_slot, unsigned half) {
  unsigned row = index / 80;
  unsigned col = index % 80;
  unsigned attribute = cells[index] >> 8;
  unsigned character = cells[index] & 255;
  unsigned plane_index;
  unsigned y;
  unsigned long offset = 0;
  unsigned char far* bits16 = 0;
  if (hanzi_slot >= 0) {
    unsigned code = han_codes[hanzi_slot];
    offset =
        ((unsigned long)((code >> 8) - 0xa1) * 94 + (code & 255) - 0xa1) * 32;
    bits16 = font_blocks[(unsigned)(offset >> 15)] + (unsigned)(offset & 32767);
  }
  unsigned char far* vram = (unsigned char far*)MK_FP(0xa000, row * 1280 + col);
  for (plane_index = 0; plane_index < 4; ++plane_index) {
    outport(0x3c4, 2 | ((1U << plane_index) << 8));
    for (y = 0; y < 16; ++y) {
      unsigned char bits =
          hanzi_slot < 0 ? latin[character * 16 + y] : bits16[y * 2 + half];
      unsigned char ink = (attribute & (1U << plane_index)) ? bits : 0;
      if (attribute & (16U << plane_index)) {
        ink |= (unsigned char)~bits;
      }
      vram[y * 80] = ink;
    }
  }
}

void PaintScreen() {
  unsigned i;
  int dirty = 0;
  if (!active) {
    return;
  }
  for (i = 0; i < 80 * 30; ++i) {
    if (cells[i] != previous[i]) {
      dirty = 1;
      break;
    }
  }
  if (!dirty) {
    return;
  }
  if (mouse_present) {
    CallMouse(2);
  }
  /* Mouse drivers may change VGA registers; establish all write-mode inputs. */
  outport(0x3ce, 0x0001); /* disable set/reset */
  outport(0x3ce, 0x0003); /* rotate=0, replace */
  outport(0x3ce, 0x0005); /* write mode 0 */
  outport(0x3ce, 0xff08); /* full bit mask */
  for (i = 0; i < 80 * 30; ++i) {
    int han = -1;
    if (i % 80 != 79) {
      han = FindHanziSlot(((cells[i] & 255) << 8) | (cells[i + 1] & 255));
    }
    if (han >= 0) {
      if (cells[i] != previous[i] || cells[i + 1] != previous[i + 1] ||
          previous_glyph[i] != han * 2 ||
          previous_glyph[i + 1] != han * 2 + 1) {
        PaintCell(i, han, 0);
        PaintCell(i + 1, han, 1);
        previous[i] = cells[i];
        previous[i + 1] = cells[i + 1];
        previous_glyph[i] = han * 2;
        previous_glyph[i + 1] = han * 2 + 1;
      }
      ++i;
    } else if (cells[i] != previous[i] || previous_glyph[i] != -1) {
      PaintCell(i, -1, 0);
      previous[i] = cells[i];
      previous_glyph[i] = -1;
    }
  }
  outport(0x3c4, 0x0f02);
  if (mouse_present) {
    CallMouse(1);
  }
}

void ReadScreenMouse(TEvent& event) {
  union REGS bios_registers;
  unsigned x;
  unsigned y;
  unsigned buttons;
  unsigned ticks;
  if (!active || !mouse_present) {
    return;
  }
  memset(&bios_registers, 0, sizeof(bios_registers));
  bios_registers.x.ax = 3;
  int86(0x33, &bios_registers, &bios_registers);
  x = bios_registers.x.cx / 8;
  y = bios_registers.x.dx / 16;
  buttons = bios_registers.x.bx & 3;
  ticks = *(unsigned far*)MK_FP(0x40, 0x6c);
  event.mouse.eventFlags = 0;
  if (buttons && !mouse_buttons) {
    event.what = evMouseDown;
    if (x == mouse_x && y == mouse_y && (unsigned)(ticks - last_down) < 8) {
      event.mouse.eventFlags = meDoubleClick;
    }
    last_down = ticks;
    repeat_at = ticks + 8;
  } else if (!buttons && mouse_buttons) {
    event.what = evMouseUp;
  } else if (x != mouse_x || y != mouse_y) {
    event.what = evMouseMove;
  } else if (buttons && (int)(ticks - repeat_at) >= 0) {
    event.what = evMouseAuto;
    repeat_at = ticks + 1;
  } else {
    return;
  }
  event.mouse.where.x = x;
  event.mouse.where.y = y;
  event.mouse.buttons = buttons;
  mouse_x = x;
  mouse_y = y;
  mouse_buttons = buttons;
}

void StopScreen() {
  union REGS bios_registers;
  if (!active) {
    return;
  }
  if (mouse_present) {
    CallMouse(2);
  }
  memset(&bios_registers, 0, sizeof(bios_registers));
  bios_registers.x.ax = old_mode & 255;
  int86(0x10, &bios_registers, &bios_registers);
  TScreen::screenBuffer = old_buffer;
  TScreen::setCrtData();
  active = 0;
  FreeFont();
}

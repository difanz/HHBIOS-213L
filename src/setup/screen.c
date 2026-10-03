/* Standalone 8086 VGA output for Watcom UI. HZK16 lives in process memory;
 * no HHBIOS hooks, TSR, XMS, EMS or protected mode are needed. */
#include "screen.h"

#include <conio.h>
#include <dos.h>
#include <stdio.h>
#include <string.h>

#include "uidef.h"
#include "uimouse.h"
#include "uirefrhk.h"

static unsigned short far cells[80 * 30], previous[80 * 30];
static short far previous_glyph[80 * 30];
static unsigned char far latin[256 * 16];
static int active;
static unsigned old_mode;
static int graphics_requested;
static int resident_text;
static unsigned char far* font_blocks[8];
/* CP437 frames and GB2312 share byte values. Encode Chinese UI characters
 * into unused Western slots before giving strings to Watcom UI. Each Han
 * still occupies exactly two cells. Frame bytes B0..DF are never ambiguous.
 * This maps character codes, not font subsets; all HZK16 glyphs are loaded. */
static unsigned far han_codes[4096];
static unsigned han_count;
static char far text_pool[16384];
static unsigned text_used;
static unsigned text_count;
enum { kTextStringCount = 256 };
static const char* source_text[kTextStringCount];
static const char* encoded_text[kTextStringCount];

const char* EncodeScreenText(const char* text) {
  unsigned i;
  unsigned code;
  unsigned slot;
  const unsigned char* source = (const unsigned char*)text;
  char* encoded;
  char* encoded_start;
  for (i = 0; i < text_count; ++i) {
    if (source_text[i] == text) {
      return encoded_text[i];
    }
  }
  if (text_count == kTextStringCount ||
      strlen(text) + text_used + 1 > sizeof(text_pool)) {
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
      _dos_freemem(FP_SEG(font_blocks[i]));
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
    unsigned segment;
    /* Allocate exact DOS blocks: a 32 KiB heap request plus heap metadata can
     * otherwise consume most of a 64 KiB far-heap segment per font chunk. */
    if (!_dos_allocmem((block_bytes + 15) / 16, &segment)) {
      font_blocks[i] = (unsigned char far*)MK_FP(segment, 0);
    }
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

static int StartScreen(void) {
  union REGS bios_registers;
  union REGPACK font;
  if (!LoadFont()) {
    return 0;
  }
  memset(&font, 0, sizeof(font));
  font.w.ax = 0x1130;
  font.w.bx = 0x0600;
  intr(0x10, &font);
  _fmemcpy(latin, MK_FP(font.w.es, font.w.bp), sizeof(latin));
  memset(&bios_registers, 0, sizeof(bios_registers));
  bios_registers.h.ah = 0x0f;
  int86(0x10, &bios_registers, &bios_registers);
  old_mode = bios_registers.h.al & 0x7f;
  bios_registers.x.ax = 0x12;
  int86(0x10, &bios_registers, &bios_registers);
  bios_registers.h.ah = 0x0f;
  int86(0x10, &bios_registers, &bios_registers);
  if ((bios_registers.h.al & 0x7f) != 0x12) {
    bios_registers.x.ax = old_mode & 255;
    int86(0x10, &bios_registers, &bios_registers);
    FreeFont();
    return 0;
  }
  memset(cells, 0, sizeof(cells));
  memset(previous, 0xff, sizeof(previous));
  memset(previous_glyph, 0xff, sizeof(previous_glyph));
  UIData->screen.origin = (LP_PIXEL)cells;
  UIData->screen.increment = 80;
  UIData->width = 80;
  UIData->height = 30;
  UIData->colour = M_VGA;
  UIData->no_snow = true;
  UIData->desqview = false;
  active = 1;
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
    outpw(0x3c4, 2 | ((1U << plane_index) << 8));
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
  /* Mouse drivers may change VGA registers; establish all write-mode inputs. */
  outpw(0x3ce, 0x0001); /* disable set/reset */
  outpw(0x3ce, 0x0003); /* rotate=0, replace */
  outpw(0x3ce, 0x0005); /* write mode 0 */
  outpw(0x3ce, 0xff08); /* full bit mask */
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
  outpw(0x3c4, 0x0f02);
}

void StopScreen(void) {
  union REGS bios_registers;
  if (!active) {
    return;
  }
  memset(&bios_registers, 0, sizeof(bios_registers));
  bios_registers.x.ax = old_mode & 255;
  int86(0x10, &bios_registers, &bios_registers);
  active = 0;
  FreeFont();
}

void ConfigureScreen(int use_graphics) {
  graphics_requested = use_graphics;
}

void ConfigureResidentText(int use_chinese) {
  resident_text = use_chinese;
}

/* The upstream DOS initializer is renamed by a compiler define. It captures
 * the original text cursor and keyboard state before we select VGA graphics. */
extern bool InitTextBios(void);

bool initbios(void) {
  if (!InitTextBios()) {
    return false;
  }
  if (graphics_requested) {
    StartScreen();
  }
  return true;
}

void uirefresh(void) {
  _uirefresh();
  PaintScreen();
}

int uicharlen(int character) {
  /* Watcom also uses this on screen cells when moving its mouse cursor.
   * Raw GB2312 lead bytes overlap CP437 frames, so only the private encoding
   * can safely determine a screen-cell boundary from a single byte. */
  return active && character >= 0x80 && character < 0xb0 ? 2 : 1;
}

unsigned ScreenTextCharacterWidth(const char* text) {
  const unsigned char* bytes = (const unsigned char*)text;
  if (active) {
    return uicharlen(bytes[0]);
  }
  return resident_text && bytes[0] >= 0xa1 && bytes[0] <= 0xf7 &&
                 bytes[1] >= 0xa1 && bytes[1] <= 0xfe
             ? 2 : 1;
}

bool uiisdbcs(void) {
  /* The private encoding leaves CP437 frames intact. It does not use DOS/V
   * shadow buffers or require Watcom's alternative DBCS frame characters. */
  return false;
}

static void CallMouse(unsigned ax, unsigned cx, unsigned dx) {
  union REGS registers;
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = ax;
  registers.x.cx = cx;
  registers.x.dx = dx;
  int86(0x33, &registers, &registers);
}

void checkmouse(MOUSESTAT* status, MOUSEORD* row, MOUSEORD* col,
                MOUSETIME* time) {
  union REGS registers;
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = 3;
  int86(0x33, &registers, &registers);
  *status = registers.x.bx & 7;
  *col = registers.x.cx / 8;
  *row = registers.x.dx / (active ? 16 : 8);
  if (*col >= UIData->width) {
    *col = UIData->width - 1;
  }
  if (*row >= UIData->height) {
    *row = UIData->height - 1;
  }
  *time = uiclock();
  uisetmouse(*row, *col);
  *col += uimousealign();
}

void uisetmouseposn(ORD row, ORD col) {
  MouseRow = row;
  MouseCol = col;
  CallMouse(4, col * 8, row * (active ? 16 : 8));
}

void uimousespeed(unsigned speed) {
  if (!speed) {
    speed = 1;
  }
  UIData->mouse_speed = speed;
  CallMouse(15, speed, speed * 2);
}

bool initmouse(init_mode install) {
  union REGS registers;
  MouseInstalled = false;
  if (install == INIT_MOUSELESS || !mouse_installed()) {
    return false;
  }
  memset(&registers, 0, sizeof(registers));
  int86(0x33, &registers, &registers);
  if (registers.x.ax != 0xffff) {
    return false;
  }
  CallMouse(7, 0, UIData->width * 8 - 1);
  CallMouse(8, 0, UIData->height * (active ? 16 : 8) - 1);
  UIData->mouse_xscale = UIData->mouse_yscale = 1;
  UIData->mouse_swapped = false;
  MouseInstalled = true;
  MouseOn = false;
  uisetmouseposn(UIData->height / 2, UIData->width / 2);
  checkmouse(&MouseStatus, &MouseRow, &MouseCol, &MouseTime);
  uimousespeed(UIData->mouse_speed);
  return true;
}

void finimouse(void) {
  if (MouseInstalled) {
    uioffmouse();
  }
}

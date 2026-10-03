/* Sustained DOS console output, with untimed text and pixel observations. */
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned char buffer[8192];
static unsigned geometry[10];
static unsigned mode;
static unsigned font_height;
static unsigned font_fault;
static unsigned long plane_bytes;

static void Video(unsigned ax, unsigned bx, unsigned cx, unsigned dx) {
  union REGPACK r;
  memset(&r, 0, sizeof(r));
  r.x.ax = ax;
  r.x.bx = bx;
  r.x.cx = cx;
  r.x.dx = dx;
  intr(0x10, &r);
}

static unsigned long Ticks(void) {
  unsigned long value;
  _disable();
  value = *(volatile unsigned long __far*)MK_FP(0x40, 0x6c);
  _enable();
  return value;
}

static unsigned long Elapsed(unsigned long start) {
  unsigned long end = Ticks();
  return end >= start ? end - start : end + 0x1800b0UL - start;
}

static int Geometry(void) {
  union REGPACK r;
  memset(&r, 0, sizeof(r));
  r.x.ax = 0x1411;
  intr(0x10, &r);
  if (r.x.ax != 0x5356 || r.x.cx < 14) {
    return 0;
  }
  _fmemcpy(geometry, MK_FP(r.x.es, r.x.di), 6);
  mode = *(unsigned __far*)MK_FP(r.x.es, r.x.di + 12);
  r.x.ax = 0x1406;
  intr(0x10, &r);
  geometry[4] = r.x.cx >> 8;
  geometry[8] = 80;
  geometry[9] = r.x.bx >> 8;
  r.x.ax = 0x1413;
  intr(0x10, &r);
  if (r.x.ax != 0x4632) {
    return 0;
  }
  geometry[3] = r.x.si;
  font_height = r.x.di;
  font_fault = r.x.dx;
  r.x.ax = 0x1415;
  intr(0x10, &r);
  if (r.x.ax != 0x5650) {
    return 0;
  }
  geometry[5] = r.x.bx;
  geometry[6] = r.x.cx;
  geometry[7] = r.x.dx;
  plane_bytes = ((unsigned long)r.x.di << 16) | r.x.si;
  return plane_bytes == (unsigned long)geometry[1] * geometry[2] && !font_fault;
}

static int WriteConsole(unsigned count) {
  union REGPACK r;
  memset(&r, 0, sizeof(r));
  r.x.ax = 0x4000;
  r.x.bx = 1;
  r.x.cx = count;
  r.x.ds = FP_SEG(buffer);
  r.x.dx = FP_OFF(buffer);
  intr(0x21, &r);
  return !(r.x.flags & 1) && r.x.ax == count;
}

static void ClearScreen(unsigned row) {
  Video(0x0600, 0x0700, 0, ((geometry[9] - 1) << 8) | 79);
  Video(0x0200, 0, 0, row << 8);
  Video(0x1500, 0, 0, 0);
}

static int Capture(const char* name) {
  union REGPACK r;
  unsigned plane, count, i;
  unsigned long offset;
  unsigned old_index;
  FILE* out = fopen(name, "wb");
  if (!out) {
    return 0;
  }
  if (fwrite("HHSNAP4\n", 1, 8, out) != 8 ||
      fwrite(geometry, 2, 10, out) != 10) {
    goto fail;
  }
  _fmemcpy(buffer, MK_FP(0xb800, 0), geometry[9] * 160);
  _fmemcpy(buffer + geometry[9] * 160, MK_FP(0x40, 0x50), 2);
  old_index = inp(0x3d4);
  for (i = 0; i < 25; ++i) {
    outp(0x3d4, i);
    buffer[geometry[9] * 160 + 2 + i] = inp(0x3d5);
  }
  outp(0x3d4, old_index);
  count = geometry[9] * 160 + 27;
  if (fwrite(buffer, 1, count, out) != count) {
    goto fail;
  }
  for (plane = 0; plane < 4; ++plane) {
    for (offset = 0; offset < plane_bytes; offset += count) {
      count = plane_bytes - offset < sizeof(buffer)
          ? (unsigned)(plane_bytes - offset)
          : sizeof(buffer);
      memset(&r, 0, sizeof(r));
      r.x.ax = 0x1414;
      r.x.bx = plane;
      r.x.cx = count;
      r.x.dx = (unsigned)(offset >> 16);
      r.x.si = (unsigned)offset;
      r.x.es = FP_SEG(buffer);
      r.x.di = FP_OFF(buffer);
      intr(0x10, &r);
      if (r.x.ax || fwrite(buffer, 1, count, out) != count) {
        goto fail;
      }
    }
  }
  return fclose(out) == 0;
fail:
  fclose(out);
  return 0;
}

int main(int argc, char** argv) {
  static const unsigned codes[] = {0xd6d0, 0xb9fa, 0xbaba, 0xd7d6,
                                   0xcfb5, 0xcdb3, 0xb2e2, 0xcad4};
  union REGPACK r;
  unsigned rows = argc >= 2 ? atoi(argv[1]) : 25;
  int chinese = argc == 3 && !strcmp(argv[2], "CN");
  unsigned i, line;
  unsigned cursor_shape;
  unsigned long start, block_ticks = 0, scroll_ticks = 0, chinese_ticks = 0;
  FILE* out;
  if (rows != 25 && rows != 43) {
    return 1;
  }
  Video(rows == 43 ? 0x1201 : 0x1202, 0x30, 0, 0);
  Video(3, 0, 0, 0);
  if (rows != 25) {
    Video(0x1112, 0, 0, 0);
  }
  memset(&r, 0, sizeof(r));
  r.x.ax = 0x0300;
  intr(0x10, &r);
  cursor_shape = r.x.cx;
  if (!Geometry() || geometry[9] != rows) {
    return 2;
  }
  if (chinese) {
    Video(0x1800, 0, 0, 0);
    Video(0x1812, 0, 0, 0);
    ClearScreen(rows - 1);
    start = Ticks();
    for (line = 0; line < 32; ++line) {
      for (i = 0; i < 16; ++i) {
        unsigned code = codes[(line + i) % 8];
        buffer[i * 2] = code >> 8;
        buffer[i * 2 + 1] = code & 255;
      }
      buffer[32] = '\r';
      buffer[33] = '\n';
      if (!WriteConsole(34)) {
        return 8;
      }
    }
    Video(0x1500, 0, 0, 0);
    chinese_ticks = Elapsed(start);
    Video(0x0100, 0, 0x2000, 0);
    if (!Capture("CHINESE.BIN")) {
      return 9;
    }
  } else {
    ClearScreen(0);
    for (i = 0; i < 4096; ++i) {
      buffer[i] = 'A' + i % 26;
    }
    start = Ticks();
    if (!WriteConsole(4096)) {
      return 3;
    }
    Video(0x1500, 0, 0, 0);
    block_ticks = Elapsed(start);
    Video(0x0100, 0, 0x2000, 0);
    if (!Capture("BLOCK.BIN")) {
      return 4;
    }
    ClearScreen(rows - 1);
    Video(0x0100, 0, cursor_shape, 0);
    start = Ticks();
    for (line = 0; line < 64; ++line) {
      buffer[0] = '0' + line / 10;
      buffer[1] = '0' + line % 10;
      buffer[2] = ':';
      for (i = 3; i < 78; ++i) {
        buffer[i] = 'a' + (line + i) % 26;
      }
      buffer[78] = '\r';
      buffer[79] = '\n';
      if (!WriteConsole(80)) {
        return 5;
      }
    }
    Video(0x1500, 0, 0, 0);
    scroll_ticks = Elapsed(start);
    Video(0x0100, 0, 0x2000, 0);
    if (!Capture("SCROLL.BIN")) {
      return 6;
    }
  }
  if (!Geometry()) {
    return 6;
  }
  out = fopen("STREAM.TXT", "w");
  if (!out) {
    return 7;
  }
  fprintf(out,
          "MODE=%u\nWIDTH=%u\nHEIGHT=%u\nROWS=%u\nFONT_WIDTH=%u\n"
          "FONT_HEIGHT=%u\nSCALE=%u\nFONT_FAULT=%u\nCURSOR_SHAPE=%u\n"
          "BLOCK_BYTES=4096\nBLOCK_TICKS=%lu\n"
          "SCROLL_LINES=64\nSCROLL_BYTES=5120\nSCROLL_TICKS=%lu\n"
          "CHINESE_LINES=32\nCHINESE_BYTES=1088\nCHINESE_TICKS=%lu\n",
          mode, geometry[0], geometry[1], geometry[9], geometry[3], font_height,
          geometry[7], font_fault, cursor_shape, block_ticks, scroll_ticks,
          chinese_ticks);
  return fclose(out) != 0;
}

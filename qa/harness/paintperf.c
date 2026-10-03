/* Repeated TUI repaints through the public B800 and BIOS interfaces. */
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static volatile unsigned long __far* ticks = MK_FP(0x40, 0x6c);
static volatile unsigned __far* text = MK_FP(0xb800, 0);

static void Video(unsigned ax, unsigned bx, unsigned cx, unsigned dx) {
  union REGPACK registers;
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = ax;
  registers.x.bx = bx;
  registers.x.cx = cx;
  registers.x.dx = dx;
  intr(0x10, &registers);
}

static void Repaint(unsigned rows, unsigned frame, int chinese) {
  static const unsigned codes[] = {0xd6d0, 0xb9fa, 0xbaba, 0xd7d6,
                                   0xcfb5, 0xcdb3, 0xb2e2, 0xcad4};
  unsigned cell;
  unsigned code;
  unsigned attribute = (frame & 1) ? 0x1e00 : 0x2f00;
  for (cell = 0; cell < rows * 80; ++cell) {
    if (chinese) {
      code = codes[(cell / 2 + frame) % 8];
      code = (cell & 1) ? code & 255 : code >> 8;
    } else {
      code = 'A' + (cell + frame) % 26;
    }
    text[cell] = attribute | code;
  }
  Video(0x1500, 0, 0, 0);
}

int main(int argc, char** argv) {
  FILE* output;
  unsigned rows = argc == 2 ? atoi(argv[1]) : 25;
  unsigned frame;
  unsigned long start;
  if (rows != 25 && rows != 43 && rows != 50) {
    return 1;
  }
  Video(rows == 43 ? 0x1201 : 0x1202, 0x30, 0, 0);
  Video(3, 0, 0, 0);
  if (rows != 25) {
    Video(0x1112, 0, 0, 0);
  }
  if (*(unsigned char __far*)MK_FP(0x40, 0x84) + 1 != rows) {
    return 2;
  }
  output = fopen("PAINT.TXT", "w");
  if (!output) {
    return 3;
  }
  Repaint(rows, 0, 0);
  start = *ticks;
  for (frame = 1; frame <= 8; ++frame) {
    Repaint(rows, frame, 0);
  }
  fprintf(output, "ASCII_8=%lu\n", (unsigned long)(*ticks - start));
  Repaint(rows, 0, 1);
  start = *ticks;
  for (frame = 1; frame <= 8; ++frame) {
    Repaint(rows, frame, 1);
  }
  fprintf(output, "CHINESE_8=%lu\n", (unsigned long)(*ticks - start));
  start = *ticks;
  for (frame = 0; frame < 16; ++frame) {
    Video(0x0601, 0x1e00, 0, ((rows - 1) << 8) | 79);
  }
  fprintf(output, "SCROLL_16=%lu\n", (unsigned long)(*ticks - start));
  return fclose(output) != 0;
}

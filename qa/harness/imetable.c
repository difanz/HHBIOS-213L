/* Query every GB2312 Hanzi through CKBD's public double-pinyin interface. */
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

#include "hostshot.h"

static int TypeCandidates(void) {
  /* Select shape-code input through CKBD's documented function-key API. */
  static const unsigned keys[] = {0x1e61, 0x3920, 0x1e61, 0x1b5d, 0x1a5b,
                                  0x3920, 0x1e61, 0x3062, 0x3920, 0x1e61,
                                  0x3062, 0x2e63, 0x3920};
  union REGPACK registers;
  unsigned i;
  FILE* output = fopen("TYPED.BIN", "wb");
  if (!output) {
    return 1;
  }
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = 0x2f00;
  intr(0x16, &registers);
  if (registers.x.ax != 0x44) {
    fclose(output);
    return 2;
  }
  registers.x.ax = 0x2100 | *(unsigned char __far*)MK_FP(registers.x.bp, 0x112);
  intr(0x16, &registers);
  for (i = 0; i < sizeof(keys) / sizeof(keys[0]); ++i) {
    if (hostrequest(keys[i])) {
      fclose(output);
      return 3;
    }
    for (;;) {
      registers.x.ax = 0x0100;
      intr(0x16, &registers);
      if (registers.x.flags & 0x40) {
        break;
      }
      registers.x.ax = 0;
      intr(0x16, &registers);
      if (fputc(registers.h.al, output) == EOF) {
        fclose(output);
        return 4;
      }
    }
  }
  return fclose(output) != 0;
}

int main(int argc, char** argv) {
  union REGPACK registers;
  unsigned row;
  unsigned column;
  FILE* output;
  if (argc == 2 && !strcmp(argv[1], "type")) {
    return TypeCandidates();
  }
  output = fopen("CODES.BIN", "wb");
  if (!output) {
    return 1;
  }
  for (row = 0xb0; row <= 0xf7; ++row) {
    for (column = 0xa1; column <= 0xfe; ++column) {
      memset(&registers, 0, sizeof(registers));
      registers.x.ax = 0x2200;
      registers.x.dx = (row << 8) | column;
      intr(0x16, &registers);
      if (fputc(registers.h.al, output) == EOF ||
          fputc(registers.h.ah, output) == EOF) {
        fclose(output);
        return 2;
      }
    }
  }
  return fclose(output) != 0;
}

/* Query every GB2312 Hanzi through CKBD's public double-pinyin interface. */
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

#include "hostshot.h"

enum InputMode { kShape, kPhrase, kPinyin };

static int TypeCandidates(enum InputMode mode) {
  /* Select the input method through CKBD's function-key API. */
  static const unsigned keys[] = {0x1e61, 0x3920, 0x1e61, 0x1b5d, 0x1a5b,
                                  0x3920, 0x1e61, 0x3062, 0x3920, 0x1e61,
                                  0x3062, 0x2e63, 0x3920};
  static const unsigned phrase_keys[] = {0x1e61, 0x3062, 0x2e63, 0x1e61};
  /* zhonx, Backspace, g, Space; shuang', Space; ang, Space. */
  static const unsigned pinyin_keys[] = {
      0x2c7a, 0x2368, 0x186f, 0x316e, 0x2d78, 0x0e08, 0x2267,
      0x3920, 0x1f73, 0x2368, 0x1675, 0x1e61, 0x316e, 0x2267,
      0x2827, 0x3920, 0x1e61, 0x316e, 0x2267, 0x3920};
  const unsigned* sequence = keys;
  unsigned count = sizeof(keys) / sizeof(keys[0]);
  unsigned function_key = 0x112;
  union REGPACK registers;
  unsigned i;
  FILE* output = fopen("TYPED.BIN", "wb");
  if (!output) {
    return 1;
  }
  if (mode == kPhrase) {
    sequence = phrase_keys;
    count = sizeof(phrase_keys) / sizeof(phrase_keys[0]);
    function_key = 0x114;
  } else if (mode == kPinyin) {
    sequence = pinyin_keys;
    count = sizeof(pinyin_keys) / sizeof(pinyin_keys[0]);
    function_key = 0x113;
  }
  memset(&registers, 0, sizeof(registers));
  registers.x.ax = 0x2f00;
  intr(0x16, &registers);
  if (registers.x.ax != 0x44) {
    fclose(output);
    return 2;
  }
  registers.x.ax =
      0x2100 | *(unsigned char __far*)MK_FP(registers.x.bp, function_key);
  intr(0x16, &registers);
  for (i = 0; i < count; ++i) {
    if (hostrequest(sequence[i])) {
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
    return TypeCandidates(kShape);
  }
  if (argc == 2 && !strcmp(argv[1], "phrase")) {
    return TypeCandidates(kPhrase);
  }
  if (argc == 2 && !strcmp(argv[1], "pinyin")) {
    return TypeCandidates(kPinyin);
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

#include "text.h"

static int EqualText(const TextByte* previous, const TextWord TEXT_FAR* current,
                     TextWord length);
#ifdef __WATCOMC__
#pragma aux EqualText parm[si][es di][cx] value[ax] modify[ax si di cx];
#endif

static int EqualText(const TextByte* previous, const TextWord TEXT_FAR* current,
                     TextWord length) {
  /* Four cells share the pointer/counter updates. Byte comparisons ignore
   * attributes without requiring aligned loads or a temporary packed row. */
  while (length >= 4) {
    if (previous[0] != (TextByte)current[0] ||
        previous[1] != (TextByte)current[1] ||
        previous[2] != (TextByte)current[2] ||
        previous[3] != (TextByte)current[3]) {
      return 0;
    }
    previous += 4;
    current += 4;
    length -= 4;
  }
  while (length) {
    if (*previous != (TextByte)*current) {
      return 0;
    }
    ++previous;
    ++current;
    --length;
  }
  return 1;
}

int TextRowSame(const TextByte* previous, const TextWord TEXT_FAR* current) {
  return EqualText(previous, current, 80);
}

int TextRowShifted(const TextByte* previous, const TextWord TEXT_FAR* current,
                   TextWord column, TextWord count) {
  TextWord end = 80;
  const TextByte* previous_end = previous + 80;
  const TextWord TEXT_FAR* current_end = current + 80;
  if (column >= 80 || !count || count > 2) {
    return 0;
  }
  while (end && previous_end[-1] == (TextByte)current_end[-1]) {
    --end;
    --previous_end;
    --current_end;
  }
  if (end < count || end - count < column) {
    return 0;
  }
  if (!EqualText(previous, current, column) ||
      !EqualText(previous + column + count, current + column,
                 end - count - column)) {
    return 0;
  }
  while (count--) {
    --current_end;
    if ((TextByte)current_end[0] != ' ') {
      return 0;
    }
  }
  return 1;
}

#include "text.h"

enum CornerFlags {
  kBarRight = 1,
  kLineBelow = 2,
  kDoubleBar = 4,
  kCorner = 8,
  kTopLeft = kCorner | kLineBelow | kBarRight,
  kTopRight = kCorner | kLineBelow,
  kBottomLeft = kCorner | kBarRight,
  kBottomRight = kCorner
};

/* CP437 B7..DA. Zero entries are not corners. */
static const TextByte kCorners[0xda - 0xb7 + 1] = {
    /* B7..BF */ kTopRight,
    kTopRight | kDoubleBar,
    0,
    0,
    kTopRight | kDoubleBar,
    kBottomRight | kDoubleBar,
    kBottomRight,
    kBottomRight | kDoubleBar,
    kTopRight,
    /* C0..C7 */ kBottomLeft,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    /* C8..CF */ kBottomLeft | kDoubleBar,
    kTopLeft | kDoubleBar,
    0,
    0,
    0,
    0,
    0,
    0,
    /* D0..D7 */ 0,
    0,
    0,
    kBottomLeft,
    kBottomLeft | kDoubleBar,
    kTopLeft | kDoubleBar,
    kTopLeft,
    0,
    /* D8..DA */ 0,
    kBottomRight,
    kTopLeft};

static TextByte Corner(TextByte ch) {
  if (ch < 0xb7 || ch > 0xda) {
    return 0;
  }
  return kCorners[ch - 0xb7];
}

static int IsVertical(TextByte ch) {
  return ch == 0x1e || ch == 0x1f || ch == 0xb3 || ch == 0xba || ch == 0x14 ||
         ch == 0x15;
}

static int HasVertical(const TextWord TEXT_FAR* cell, TextWord row,
                       TextWord last_row, TextByte corner) {
  if (corner & kLineBelow) {
    return row < last_row && IsVertical((TextByte)cell[80]);
  }
  return row != 0 && IsVertical((TextByte)cell[-80]);
}

int TextIsFrame(const TextWord TEXT_FAR* cell, TextWord position,
                TextWord last_row) {
  TextWord column = position & 255;
  TextWord row = position >> 8;
  TextByte ch = (TextByte)*cell;
  TextByte corner;

  /* Directory branches C0 C4 [x] may hang below an ASCII [+]/[-] node. */
  if (row && (ch == 0xc0 || (ch == 0xc4 && column))) {
    TextWord node_column = column - (ch == 0xc4);
    const TextWord TEXT_FAR* node = cell - (ch == 0xc4);
    if (node_column && node_column <= 75 && (TextByte)node[0] == 0xc0 &&
        (TextByte)node[1] == 0xc4 && (TextByte)node[2] == '[' &&
        (TextByte)node[4] == ']' && (TextByte)node[-81] == '[' &&
        (TextByte)node[-79] == ']' &&
        ((TextByte)node[-80] == '+' || (TextByte)node[-80] == '-')) {
      return 1;
    }
  }

  corner = Corner(ch);
  if (corner) {
    TextByte bar = (corner & kDoubleBar) ? 0xcd : 0xc4;
    if (corner & kBarRight) {
      if (column >= 79 || (TextByte)cell[1] != bar) {
        return 0;
      }
    } else if (!column || (TextByte)cell[-1] != bar) {
      return 0;
    }
    return HasVertical(cell, row, last_row, corner);
  }
  if (ch != 0xc4 && ch != 0xcd) {
    return 0;
  }
  if (column) {
    corner = Corner((TextByte)cell[-1]);
    if ((corner & (kCorner | kBarRight)) == (kCorner | kBarRight) &&
        ((corner & kDoubleBar) ? 0xcd : 0xc4) == ch &&
        HasVertical(cell - 1, row, last_row, corner)) {
      return 1;
    }
  }
  if (column < 79) {
    corner = Corner((TextByte)cell[1]);
    if ((corner & (kCorner | kBarRight)) == kCorner &&
        ((corner & kDoubleBar) ? 0xcd : 0xc4) == ch &&
        HasVertical(cell + 1, row, last_row, corner)) {
      return 1;
    }
  }
  return 0;
}

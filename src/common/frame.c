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
  return ch == 0x18 || ch == 0x19 || ch == 0x1e || ch == 0x1f ||
         ch == 0xb3 || ch == 0xba || ch == 0x14 || ch == 0x15;
}

static int HasVertical(const TextWord TEXT_FAR* cell, TextWord row,
                       TextWord last_row, TextByte corner) {
  if (corner & kLineBelow) {
    return row < last_row && IsVertical((TextByte)cell[80]);
  }
  return row != 0 && IsVertical((TextByte)cell[-80]);
}

static int IsHorizontal(TextByte ch, TextWord weight) {
  return weight == 1 ? ch == 0xc4 || ch == 0x12
                    : weight == 2 && (ch == 0xcd || ch == 0x95);
}

/* A raw corner or junction cannot anchor a rail from its vertical bits
 * alone: those bytes also occur in adjacent lines of Chinese text. Require
 * a connected horizontal stroke. Previously converted aliases are known
 * frame cells; a plain vertical endpoint needs no horizontal neighbor. */
int TextHasHorizontalJoin(const TextWord TEXT_FAR* cell, TextWord column,
                          TextWord strokes) {
  TextByte ch = (TextByte)*cell;
  TextWord left = (strokes >> 4) & 3;
  TextWord right = strokes & 3;
  if (ch <= 0xa0 || !(left | right)) {
    return 1;
  }
  return (column && IsHorizontal((TextByte)cell[-1], left)) ||
         (column < 79 && IsHorizontal((TextByte)cell[1], right));
}

static int IsTreeNode(const TextWord TEXT_FAR* cell) {
  TextByte marker = (TextByte)cell[3];
  return IsHorizontal((TextByte)cell[1], 1) && (TextByte)cell[2] == '[' &&
         (marker == ' ' || marker == '+' || marker == '-') &&
         (TextByte)cell[4] == ']';
}

/* C3 C4 also spells a Hanzi: require a connected parent or sibling, not
 * just a pair followed by brackets. A scrolled tree can hide its parent.
 * Earlier rows may already contain HHBIOS's unambiguous frame aliases. */
static int IsDirectoryBranch(const TextWord TEXT_FAR* cell, TextWord column,
                             TextWord row, TextWord last_row) {
  const TextWord TEXT_FAR* neighbor;
  TextWord above = row;
  TextByte ch = (TextByte)*cell;
  if (ch == 0xc4 && column) {
    --cell;
    --column;
    ch = (TextByte)*cell;
  }
  if (column > 75 || (ch != 0xc0 && ch != 0xc3 &&
                      ch != 0x8a && ch != 0x8d) || !IsTreeNode(cell)) {
    return 0;
  }
  neighbor = cell;
  while (above--) {
    neighbor -= 80;
    ch = (TextByte)*neighbor;
    if (column && (ch == '+' || ch == '-') &&
        (TextByte)neighbor[-1] == '[' && (TextByte)neighbor[1] == ']') {
      return 1;
    }
    /* PC Tools indents a child under '['; DOS Shell uses its center. */
    if (ch == '[' && ((TextByte)neighbor[1] == '+' ||
                     (TextByte)neighbor[1] == '-') &&
        (TextByte)neighbor[2] == ']') {
      return 1;
    }
    if ((ch == 0xc3 || ch == 0x8d) && IsTreeNode(neighbor)) {
      return 1;
    }
    if (ch != 0xb3 && ch != 0x14) {
      break;
    }
  }
  ch = (TextByte)*cell;
  if (ch == 0xc3 || ch == 0x8d) {
    while (row < last_row) {
      ++row;
      cell += 80;
      ch = (TextByte)*cell;
      if ((ch == 0xc3 || ch == 0x8d || ch == 0xc0 || ch == 0x8a) &&
          IsTreeNode(cell)) {
        return 1;
      }
      if (ch != 0xb3 && ch != 0x14) {
        break;
      }
    }
  }
  return 0;
}

/* Half blocks form the bevels of shaded DOS panels. Their old aliases share
 * the shading glyph B2, so recognize these edges without rewriting them. */
static int HasBlockCap(const TextWord TEXT_FAR* left, TextWord width,
                       TextWord rows, int row_step, TextByte cap) {
  TextWord x;
  TextByte alias = cap == 0xdf ? 0xa0 : 0x9f;
  while (rows--) {
    left += row_step;
    if ((TextByte)*left != 0xde || (TextByte)left[width] != 0xdd) {
      return 0;
    }
    for (x = 1; x < width; ++x) {
      TextByte ch = (TextByte)left[x];
      if (ch != cap && ch != alias) {
        break;
      }
    }
    if (x == width) {
      return 1;
    }
  }
  return 0;
}

static int IsHalfBlockEdge(const TextWord TEXT_FAR* cell, TextWord column,
                           TextWord row, TextWord last_row) {
  TextWord width = 1;
  TextByte ch = (TextByte)*cell;
  TextWord room = ch == 0xde ? 79 - column : column;
  int step = ch == 0xde ? 1 : -1;
  TextByte other = ch == 0xde ? 0xdd : 0xde;
  if (!row || row >= last_row || (TextByte)cell[-80] != ch ||
      (TextByte)cell[80] != ch) {
    return 0;
  }
  while (width <= room && (TextByte)cell[step * (int)width] != other) {
    ++width;
  }
  if (width < 3 || width > room) {
    return 0;
  }
  if (step < 0) {
    cell -= width;
  }
  return HasBlockCap(cell, width, row, -80, 0xdf) ||
         HasBlockCap(cell, width, last_row - row, 80, 0xdc);
}

int TextIsFrame(const TextWord TEXT_FAR* cell, TextWord position,
                TextWord last_row) {
  TextWord column = position & 255;
  TextWord row = position >> 8;
  TextByte ch = (TextByte)*cell;
  TextByte corner;

  if (ch == 0xdd || ch == 0xde) {
    return IsHalfBlockEdge(cell, column, row, last_row);
  }
  if ((ch == 0xc0 || ch == 0xc3 || ch == 0xc4) &&
      IsDirectoryBranch(cell, column, row, last_row)) {
    return 1;
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

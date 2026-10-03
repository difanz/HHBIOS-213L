#include "font_layout.h"

#ifdef __WATCOMC__
static FontFileSize Multiply(unsigned short a, unsigned short b);
#pragma aux Multiply = "mul dx" parm[ax][dx] value[dx ax] modify[ax dx];
#else
#define Multiply(a, b) ((FontFileSize)(a) * (b))
#endif

int FitFont(const FontFileInfo* font, unsigned short width,
            unsigned short height, unsigned short rows, FontLayout* layout) {
  unsigned short body;
  unsigned short scale;
  unsigned short cell_height;
  if (!font || font->width < 8 || font->width > 24 ||
      font->height < 16 || font->height > 64 || !rows || rows > 50) {
    return 0;
  }
  body = font->format == 1 ? 20 : font->height;
  if (width < 80U * font->width || height < body * (rows + 1)) {
    return 0;
  }
  layout->scale = 1;
  layout->height = height >= font->height * (rows + 1) ? font->height : body;
  for (scale = 2; scale <= 4 && width >= 80U * font->width * scale; ++scale) {
    cell_height =
        height >= font->height * (rows + 1) * scale ? font->height : body;
    if (height >= cell_height * (rows + 1) * scale) {
      layout->scale = scale;
      layout->height = cell_height;
    }
  }
  layout->area = Multiply(80U * font->width * layout->scale,
                          (rows + 1) * layout->height * layout->scale);
  return 1;
}

int BetterFont(const FontFileInfo* candidate, const FontFileInfo* current,
               unsigned short width, unsigned short height,
               unsigned short rows) {
  FontLayout proposed;
  FontLayout previous;
  if (!FitFont(candidate, width, height, rows, &proposed)) {
    return 0;
  }
  if (!FitFont(current, width, height, rows, &previous)) {
    return 1;
  }
  if (proposed.area != previous.area) {
    return proposed.area > previous.area;
  }
  /* Prefer a native strike to enlarging a smaller bitmap. Preserve HH20's
   * fast path when an installed font has exactly the same cell geometry. */
  if (proposed.scale != previous.scale) {
    return proposed.scale < previous.scale;
  }
  if (candidate->format != current->format) {
    return candidate->format < current->format;
  }
  return candidate->payload_bytes < current->payload_bytes;
}

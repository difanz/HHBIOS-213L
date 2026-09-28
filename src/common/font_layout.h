/* Cell selection shared by SETUP and the resident VESA driver. */
#ifndef HHBIOS_SRC_COMMON_FONT_LAYOUT_H_
#define HHBIOS_SRC_COMMON_FONT_LAYOUT_H_

#include "font_file.h"

typedef struct FontLayout {
  unsigned short height;
  unsigned short scale;
  FontFileSize area;
} FontLayout;

/* Includes one row for HHBIOS's input/status line. Height is unscaled. */
int FitFont(const FontFileInfo* font, unsigned short width,
            unsigned short height, unsigned short rows, FontLayout* layout);
int BetterFont(const FontFileInfo* candidate, const FontFileInfo* current,
               unsigned short width, unsigned short height, unsigned short rows);

#endif

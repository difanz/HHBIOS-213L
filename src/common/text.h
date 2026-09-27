/* Pure text operations. Callers supply a stable snapshot and valid geometry. */
#ifndef HHBIOS_COMMON_TEXT_H_
#define HHBIOS_COMMON_TEXT_H_

#ifdef __WATCOMC__
#define TEXT_FAR __far
#else
#define TEXT_FAR
#endif

typedef unsigned char TextByte;
typedef unsigned short TextWord;

int TextIsFrame(const TextWord TEXT_FAR* cell, TextWord position,
                TextWord last_row);
int TextRowSame(const TextByte* previous, const TextWord TEXT_FAR* current);
int TextRowShifted(const TextByte* previous, const TextWord TEXT_FAR* current,
                   TextWord column, TextWord count);

#ifdef __WATCOMC__
#pragma aux TextIsFrame \
    "TextIsFrame" parm[es bx][dx][cx] value[ax] modify[ax bx cx dx si di];
#pragma aux TextRowSame \
    "TextRowSame" parm[si][es bx] value[ax] modify[ax bx cx dx si di];
#pragma aux TextRowShifted "TextRowShifted" parm[si][es bx][dx] \
    [cx] value[ax] modify[ax bx cx dx si di];
#endif

#endif

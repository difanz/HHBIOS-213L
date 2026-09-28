/* HHFONT2 bitmap files and the printer's 24-pin band interface. */
#ifndef HHBIOS_SRC_FONT_BITMAP_H_
#define HHBIOS_SRC_FONT_BITMAP_H_

typedef unsigned char FontByte;
typedef unsigned short FontWord;
#if defined(PRINTFONT_HOST)
typedef unsigned int FontLong;
#define FONT_CALL
#else
typedef unsigned long FontLong;
#define FONT_CALL __cdecl
#endif

#if defined(__WATCOMC__)
static FontLong FontMultiply(FontWord a, FontWord b);
#pragma aux FontMultiply = "mul dx" parm[ax][dx] value[dx ax] modify[ax dx];
#else
#define FontMultiply(a, b) ((FontLong)(a) * (b))
#endif

enum { kFontSlots = 8434, kFontMapBytes = 33736, kPrintBandRows = 24 };
typedef struct BitmapFont {
  FontWord width;
  FontWord height;
  FontWord stride;
  FontWord record_bytes;
  FontWord records;
  FontLong payload_bytes;
} BitmapFont;

int DecodeBitmapFont(const FontByte* header, FontWord size, BitmapFont* font);
FontWord BitmapFontSlot(FontWord code);
FontWord RenderPrintBand(const BitmapFont* font, const FontByte* glyph,
                         FontWord code, FontWord format, FontWord attributes,
                         FontWord band, FontByte* output);

#endif

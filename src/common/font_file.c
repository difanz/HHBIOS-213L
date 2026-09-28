#include "font_file.h"

static unsigned short ReadWord(const unsigned char* bytes) {
  return bytes[0] | ((unsigned short)bytes[1] << 8);
}

#if defined(__WATCOMC__)
static FontFileSize Multiply(unsigned short a, unsigned short b);
#pragma aux Multiply = "mul dx" parm[ax][dx] value[dx ax] modify[ax dx];
#else
#define Multiply(a, b) ((FontFileSize)(a) * (b))
#endif

int DecodeFontFile(const unsigned char* header, FontFileInfo* info) {
  FontFileInfo decoded;
  unsigned i, modern = 1, legacy = 1;
  for (i = 0; i < 8; ++i) {
    if (header[i] != "HHFONT2\n"[i]) {
      modern = 0;
    }
    if (header[i] != "HH20F01\n"[i]) {
      legacy = 0;
    }
  }
  if (!modern && !legacy) {
    return 0;
  }
  for (i = 20; i < 32; ++i) {
    if (header[i]) {
      return 0;
    }
  }
  decoded.format = modern ? 2 : 1;
  decoded.width = ReadWord(header + 8);
  decoded.height = ReadWord(header + 10);
  decoded.records = ReadWord(header + 14);
  decoded.payload_bytes =
      ReadWord(header + 16) | ((FontFileSize)ReadWord(header + 18) << 16);
  if (decoded.width < 8 || decoded.width > 24 || decoded.height < 16 ||
      decoded.height > 64 ||
      (legacy && (decoded.width != 10 || decoded.height != 23)) ||
      ReadWord(header + 12) != 8434 || !decoded.records ||
      decoded.records > 16868U) {
    return 0;
  }
  decoded.record_bytes =
      ((((decoded.width * 2 + 7) / 8) * decoded.height) + 1) & ~1U;
  if (decoded.payload_bytes !=
      33736UL + Multiply(decoded.records, decoded.record_bytes)) {
    return 0;
  }
  *info = decoded;
  return 1;
}

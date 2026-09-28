/* On-disk font metadata. This interface does not depend on DOS or graphics. */
#ifndef HHBIOS_SRC_COMMON_FONT_FILE_H_
#define HHBIOS_SRC_COMMON_FONT_FILE_H_

#ifdef __WATCOMC__
typedef unsigned long FontFileSize;
#else
typedef unsigned int FontFileSize;
#endif

typedef struct FontFileInfo {
  unsigned short format;
  unsigned short width;
  unsigned short height;
  unsigned short record_bytes;
  unsigned short records;
  FontFileSize payload_bytes;
} FontFileInfo;

int DecodeFontFile(const unsigned char* header, FontFileInfo* info);

#endif

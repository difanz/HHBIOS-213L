#ifndef HHBIOS_INPUT_PINYIN_H_
#define HHBIOS_INPUT_PINYIN_H_

enum { kPinyinMaxLength = 8, kPinyinBufferSize = 10 };

/* Matches CKBD's resident D_2CC1 and D_2CC0 fields. The spelling is counted,
 * not terminated; phrase lookup also uses it when no two-key code exists. */
struct PinyinQuery {
  unsigned char spelling[kPinyinBufferSize];
  unsigned char abbreviated;
};

/* Return the initial in the low byte and the final in the high byte.
 * A single key has a zero high byte; zero means no character query.
 * Input and query are separate buffers in the resident data segment. */
unsigned short PinyinPrepare(const unsigned char* input, unsigned short length,
                             struct PinyinQuery* query);

#ifdef __WATCOMC__
#pragma aux PinyinPrepare \
    "PinyinPrepare" parm[si][cx][di] value[ax] modify[ax bx cx dx si di];
#endif

#endif

#include "pinyin.h"

struct PinyinFinal {
  char spelling[4]; /* Four-letter finals occupy the whole field. */
  unsigned char key;
};

struct PinyinShortFinal {
  char spelling[2];
  unsigned char key;
};

/* Keep the historical aliases: phrase tables use these as well as full
 * spellings. For example, both "ong" and "on" map to 's'. */
static const struct PinyinShortFinal kTwoLetterFinals[] = {
    {"ai", 'l'}, {"an", 'j'}, {"ao", 'k'}, {"ei", 'd'}, {"en", 'f'},
    {"on", 's'}, {"ou", 'p'}, {"ia", 'r'}, {"ie", 't'}, {"ih", 'x'},
    {"ij", 'b'}, {"ik", 'm'}, {"in", 'n'}, {"io", 's'}, {"iu", 'q'},
    {"is", 's'}, {"ua", 'w'}, {"ue", 'w'}, {"uh", 'x'}, {"ui", 'v'},
    {"uj", 'z'}, {"ul", 'y'}, {"un", 'c'}, {"uo", 'o'}, {"ve", 'w'}};
static const struct PinyinFinal kThreeLetterFinals[] = {
    {"ang", 'h'}, {"eng", 'g'}, {"ong", 's'}, {"ian", 'b'}, {"iao", 'm'},
    {"ing", 'y'}, {"ion", 's'}, {"uai", 'y'}, {"uan", 'z'}};
static const struct PinyinFinal kFourLetterFinals[] = {
    {"iang", 'x'}, {"iong", 's'}, {"uang", 'x'}};

static unsigned char FindShortFinal(const unsigned char* spelling) {
  const struct PinyinShortFinal* entry = kTwoLetterFinals;
  unsigned short count = sizeof(kTwoLetterFinals) / sizeof(kTwoLetterFinals[0]);
  for (; count; --count, ++entry) {
    if (spelling[0] == entry->spelling[0] &&
        spelling[1] == entry->spelling[1]) {
      return entry->key;
    }
  }
  return 0;
}

static unsigned char FindFinal(const unsigned char* spelling,
                               unsigned short length) {
  const struct PinyinFinal* entry;
  unsigned short count;
  switch (length) {
    case 2:
      return FindShortFinal(spelling);
    case 3:
      entry = kThreeLetterFinals;
      count = sizeof(kThreeLetterFinals) / sizeof(kThreeLetterFinals[0]);
      break;
    case 4:
      entry = kFourLetterFinals;
      count = sizeof(kFourLetterFinals) / sizeof(kFourLetterFinals[0]);
      break;
    default:
      return 0;
  }
  for (; count; --count, ++entry) {
    if (spelling[0] == entry->spelling[0] &&
        spelling[1] == entry->spelling[1] &&
        (length < 3 || spelling[2] == entry->spelling[2]) &&
        (length < 4 || spelling[3] == entry->spelling[3])) {
      return entry->key;
    }
  }
  return 0;
}

unsigned short PinyinPrepare(const unsigned char* input, unsigned short length,
                             struct PinyinQuery* query) {
  unsigned short i;
  unsigned char initial;
  unsigned char final;
  unsigned char last_key;

  if (!length || length > kPinyinMaxLength) {
    return 0;
  }
  for (i = 0; i < length; ++i) {
    query->spelling[i] = input[i];
  }
  query->abbreviated = 0;
  last_key = input[length - 1];
  initial = input[0];
  if (length == 1) {
    return initial;
  }

  /* A bare zh/ch/sh is still a two-key query. Contract it only after the
   * next key arrives, leaving the unused buffer tail intact for CKBD. */
  if (length > 2 && input[1] == 'h') {
    switch (initial) {
      case 'z':
        initial = 'v';
        break;
      case 'c':
        initial = 'i';
        break;
      case 's':
        initial = 'u';
        break;
    }
    if (initial != input[0]) {
      query->spelling[0] = initial;
      --length;
      for (i = 1; i < length; ++i) {
        query->spelling[i] = query->spelling[i + 1];
      }
      query->abbreviated = 0xff;
    }
  }

  if (length == 2) {
    final = query->spelling[1];
  } else if (length == 3 && initial == 'a') {
    /* The original three-key 'a' rule precedes separator handling: ang is
     * accepted, but an' is not a character query. Phrase lookup follows. */
    if (query->spelling[1] != 'n' || query->spelling[2] != 'g') {
      return 0;
    }
    final = 'g';
    query->abbreviated = 0xff;
  } else if (length == 3 && last_key == '\'') {
    final = query->spelling[1];
  } else {
    if (last_key == '\'') {
      --length;
    }
    final = FindFinal(query->spelling + 1, length - 1);
    if (!final) {
      return 0;
    }
    query->abbreviated = 0xff;
  }
  return initial | ((unsigned short) final << 8);
}

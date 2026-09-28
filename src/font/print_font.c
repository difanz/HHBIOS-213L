/* Resident bitmap printing. DOS file I/O is confined to installation. */
#include "bitmap.h"

#ifndef PRINT_SIZE
#define PRINT_SIZE 24
#endif

#define FAR __far
#define POINTER(type, segment, offset) \
  ((type FAR*)(((FontLong)(segment) << 16) | (FontWord)(offset)))

typedef struct FontRegisters {
  FontWord ax, bx, cx, dx, si, di, bp, ds, es, flags;
} FontRegisters;

typedef struct FontStore {
  BitmapFont font;
  FontWord kind;
  FontWord handle;
} FontStore;

#pragma pack(push, 1)
typedef struct XmsMove {
  FontLong size;
  FontWord source;
  FontLong from;
  FontWord destination;
  FontLong to;
} XmsMove;
typedef struct EmsMove {
  FontLong size;
  FontByte source_type;
  FontWord source;
  FontWord from;
  FontWord source_page;
  FontByte destination_type;
  FontWord destination;
  FontWord to;
  FontWord destination_page;
} EmsMove;
#pragma pack(pop)

FontRegisters FONT_CALL PrintRequest;
extern FontWord FONT_CALL PrintSegment;
FontWord FONT_CALL PrintLow;
FontLong FONT_CALL PrintXmsEntry;
FontByte FONT_CALL PrintOutput[180];
extern FontByte FONT_CALL PrintTransfer[4096];
void FONT_CALL PrintService(FontWord kind, FontRegisters* registers);

static FontStore stores[4];
static FontWord faces[4];
static FontWord memory_choice;
static char paths[4][128];
static FontWord cached_face = 0xffff;
static FontWord cached_slot = 0xffff;
static FontByte glyph[200];

static void Clear(void* data, FontWord size) {
  FontByte* cursor = data;
  while (size--) {
    *cursor++ = 0;
  }
}

static void ResetRegisters(FontRegisters* registers) {
  Clear(registers, sizeof(*registers));
  registers->ds = PrintSegment;
}

static int Transfer(FontStore* store, FontLong offset, void* buffer,
                    FontWord size, unsigned writing) {
  FontRegisters registers;
  XmsMove xms;
  EmsMove ems;
  ResetRegisters(&registers);
  if (store->kind == 1) {
    xms.size = size;
    xms.source = writing ? 0 : store->handle;
    xms.destination = writing ? store->handle : 0;
    xms.from =
        writing ? ((FontLong)PrintSegment << 16) | (FontWord)buffer : offset;
    xms.to =
        writing ? offset : ((FontLong)PrintSegment << 16) | (FontWord)buffer;
    registers.ax = 0x0b00;
    registers.si = (FontWord)&xms;
    PrintService(3, &registers);
    return registers.ax == 1;
  }
  Clear(&ems, sizeof(ems));
  ems.size = size;
  if (writing) {
    ems.from = (FontWord)buffer;
    ems.source_page = PrintSegment;
    ems.destination_type = 1;
    ems.destination = store->handle;
    ems.to = (FontWord)offset & 0x3fff;
    ems.destination_page = (FontWord)(offset >> 14);
  } else {
    ems.source_type = 1;
    ems.source = store->handle;
    ems.from = (FontWord)offset & 0x3fff;
    ems.source_page = (FontWord)(offset >> 14);
    ems.to = (FontWord)buffer;
    ems.destination_page = PrintSegment;
  }
  registers.ax = 0x5700;
  registers.si = (FontWord)&ems;
  PrintService(2, &registers);
  return !(registers.ax & 0xff00);
}

void FONT_CALL ClosePrintFonts(void) {
  FontRegisters registers;
  FontWord i;
  for (i = 0; i < 4; ++i) {
    if (!stores[i].kind) {
      continue;
    }
    ResetRegisters(&registers);
    if (stores[i].kind == 1) {
      registers.ax = 0x0a00;
      registers.dx = stores[i].handle;
      PrintService(3, &registers);
    } else {
      registers.ax = 0x4500;
      registers.dx = stores[i].handle;
      PrintService(2, &registers);
    }
    stores[i].kind = 0;
  }
  cached_face = cached_slot = 0xffff;
}

void FONT_CALL GetPrintBand(void) {
  FontWord format = PrintRequest.ax >> 8;
  FontWord code = PrintRequest.dx;
  FontWord slot = BitmapFontSlot(code);
  FontWord style = (format >> 4) & 3;
  FontWord face, record = 0;
  FontStore* store;
  const FontByte* pixels = 0;
  if (PRINT_SIZE == 24 && (format & 0xf0) == 0x10) {
    style = (format >> 2) & 3;
  }
  if (code < 256 || (code >> 8) < 0xb0) {
    style = 0;
  }
  face = faces[style];
  store = &stores[face];
  if (slot != 0xffff && store->kind) {
    if (face == cached_face && slot == cached_slot) {
      pixels = glyph;
    } else if (Transfer(store, (FontLong)slot * 2, &record, 2, 0) &&
               record < store->font.records &&
               Transfer(store,
                        kFontMapBytes +
                            FontMultiply(record, store->font.record_bytes),
                        glyph, store->font.record_bytes, 0)) {
      cached_face = face;
      cached_slot = slot;
      pixels = glyph;
    }
  }
  PrintRequest.cx =
      RenderPrintBand(&store->font, pixels, code, format, PrintRequest.bx & 255,
                      PrintRequest.bx >> 8, PrintOutput);
  if (PRINT_SIZE == 24 && (format & 0xf0) == 0x10) {
    format &= 0xf0;
  }
  if (PRINT_SIZE != 24) {
    format &= 0xf3; /* vertical scaling is already in the band */
  }
  PrintRequest.ax = (format << 8) | (PrintRequest.ax & 255);
  PrintRequest.ds = PrintSegment;
  PrintRequest.si = (FontWord)PrintOutput;
}

#pragma code_seg("INIT_TEXT", "INIT")

static void Message(const char* message) {
  FontRegisters registers;
  ResetRegisters(&registers);
  registers.ax = 0x0900;
  registers.dx = (FontWord)message;
  PrintService(0, &registers);
}

static unsigned Upper(unsigned character) {
  return character >= 'a' && character <= 'z' ? character - 'a' + 'A'
                                              : character;
}

static int SamePath(const char* first, const char* second) {
  while (*first && Upper(*first) == Upper(*second)) {
    ++first;
    ++second;
  }
  return Upper(*first) == Upper(*second);
}

static int DefaultPath(void) {
  FontWord environment = *POINTER(FontWord, PrintSegment, 0x2c);
  const char FAR* text = POINTER(char, environment, 0);
  FontWord i = 0, start, length = 0;
  while (i < 0xfff0 && (text[i] || text[i + 1])) {
    ++i;
  }
  if (i == 0xfff0) {
    return 0;
  }
  start = i + 4;
  for (i = 0; i < 120 && text[start + i]; ++i) {
    paths[0][i] = text[start + i];
    if (text[start + i] == '\\' || text[start + i] == ':') {
      length = i + 1;
    }
  }
  if (i == 120) {
    return 0;
  }
  paths[0][length++] = 'H';
  paths[0][length++] = 'H';
  paths[0][length++] = '0' + PRINT_SIZE / 10;
  paths[0][length++] = '0' + PRINT_SIZE % 10;
  paths[0][length++] = '.';
  paths[0][length++] = 'F';
  paths[0][length++] = 'N';
  paths[0][length++] = 'T';
  paths[0][length] = 0;
  return 1;
}

static int ParseOptions(void) {
  const FontByte FAR* command = POINTER(FontByte, PrintSegment, 0x80);
  unsigned at = 1, end = command[0] + 1;
  if (!DefaultPath()) {
    return 0;
  }
  while (at < end) {
    unsigned option, face = 0, length = 0;
    while (at < end && (command[at] == ' ' || command[at] == '\t')) {
      ++at;
    }
    if (at == end) {
      break;
    }
    if (command[at++] != '/' || at == end) {
      return 0;
    }
    option = Upper(command[at++]);
    if (option == '?') {
      return 2;
    }
    if (option == 'N') {
      PrintLow = 1;
    } else if (option == 'X' || option == 'E') {
      if (memory_choice) {
        return 0;
      }
      memory_choice = option == 'X' ? 1 : 2;
    } else if (option == 'F') {
      if (at < end && command[at] >= '0' && command[at] <= '3') {
        face = command[at++] - '0';
      }
      if (at == end || command[at++] != ':') {
        return 0;
      }
      while (at < end && command[at] != ' ' && command[at] != '\t') {
        unsigned character = command[at++];
        if (character < 33 || character == '"' || length >= 127) {
          return 0;
        }
        paths[face][length++] = character;
      }
      if (!length) {
        return 0;
      }
      paths[face][length] = 0;
    } else {
      return 0;
    }
    if (at < end && command[at] != ' ' && command[at] != '\t') {
      return 0;
    }
  }
  return 1;
}

static int Allocate(FontStore* store) {
  FontRegisters registers;
  FontWord kb = (FontWord)((store->font.payload_bytes + 1023) >> 10);
  FontWord i;
  const FontByte FAR* signature;
  ResetRegisters(&registers);
  if (memory_choice != 2) {
    registers.ax = 0x4300;
    PrintService(1, &registers);
    if ((registers.ax & 255) == 0x80) {
      registers.ax = 0x4310;
      PrintService(1, &registers);
      PrintXmsEntry = ((FontLong)registers.es << 16) | registers.bx;
      registers.ax = 0x0900;
      registers.dx = kb;
      PrintService(3, &registers);
      if (registers.ax == 1) {
        store->kind = 1;
        store->handle = registers.dx;
        return 1;
      }
    }
    if (memory_choice == 1) {
      return 0;
    }
  }
  registers.ax = 0x3567;
  PrintService(0, &registers);
  signature = POINTER(FontByte, registers.es, 10);
  for (i = 0; i < 8; ++i) {
    if (signature[i] != "EMMXXXX0"[i]) {
      return 0;
    }
  }
  registers.ax = 0x4600;
  PrintService(2, &registers);
  if ((registers.ax & 0xff00) || (registers.ax & 255) < 0x40) {
    return 0;
  }
  registers.ax = 0x4300;
  registers.bx = (kb + 15) / 16;
  PrintService(2, &registers);
  if (registers.ax & 0xff00) {
    return 0;
  }
  store->kind = 2;
  store->handle = registers.dx;
  return 1;
}

static int LoadFace(unsigned face) {
  FontRegisters registers;
  FontStore* store = &stores[face];
  FontWord file, count, i;
  FontLong offset;
  int ok = 0;
  ResetRegisters(&registers);
  registers.ax = 0x3d00;
  registers.dx = (FontWord)paths[face];
  PrintService(0, &registers);
  if (registers.flags & 1) {
    return 0;
  }
  file = registers.ax;
  registers.ax = 0x3f00;
  registers.bx = file;
  registers.cx = 32;
  registers.dx = (FontWord)PrintTransfer;
  PrintService(0, &registers);
  if ((registers.flags & 1) || registers.ax != 32 ||
      !DecodeBitmapFont(PrintTransfer, PRINT_SIZE, &store->font) ||
      !Allocate(store)) {
    goto done;
  }
  for (offset = 0; offset < store->font.payload_bytes; offset += count) {
    count = store->font.payload_bytes - offset > 4096
                ? 4096
                : (FontWord)(store->font.payload_bytes - offset);
    ResetRegisters(&registers);
    registers.ax = 0x3f00;
    registers.bx = file;
    registers.cx = count;
    registers.dx = (FontWord)PrintTransfer;
    PrintService(0, &registers);
    if ((registers.flags & 1) || registers.ax != count) {
      goto done;
    }
    for (i = 0; i < count && offset + i < kFontMapBytes; i += 2) {
      FontWord record =
          PrintTransfer[i] | ((FontWord)PrintTransfer[i + 1] << 8);
      if (record >= store->font.records) {
        goto done;
      }
    }
    if (!Transfer(store, offset, PrintTransfer, count, 1)) {
      goto done;
    }
  }
  registers.ax = 0x3f00;
  registers.bx = file;
  registers.cx = 1;
  registers.dx = (FontWord)PrintTransfer;
  PrintService(0, &registers);
  ok = !(registers.flags & 1) && !registers.ax;
done:
  registers.ax = 0x3e00;
  registers.bx = file;
  PrintService(0, &registers);
  return ok;
}

FontWord FONT_CALL InitializePrintFonts(void) {
  FontRegisters registers;
  unsigned i, j;
  int parsed = ParseOptions();
  if (parsed != 1) {
    Message(
        "READ24/32/40 [/F:font] [/F1:font] [/F2:font] [/F3:font] [/X|/E] "
        "[/N]\r\n"
        "HHFONT2; default HH24/32/40.FNT. /X XMS, /E EMS, /N conventional "
        "TSR.\r\n$");
    return parsed == 2 ? 2 : 0;
  }
  ResetRegisters(&registers);
  registers.ax = 0x3500 + 0x7b + (PRINT_SIZE - 24) / 8;
  PrintService(0, &registers);
  if (*POINTER(FontWord, registers.es, registers.bx - 2) ==
      ('0' + PRINT_SIZE / 10) + (('0' + PRINT_SIZE % 10) << 8)) {
    Message("This printing font reader is already installed.\r\n$");
    return 0;
  }
  ResetRegisters(&registers);
  registers.ax = 0x4a06;
  registers.si = 3;
  PrintService(1, &registers);
  if (registers.bx != 0x4a06) {
    Message("Load the HHBIOS display font reader first.\r\n$");
    return 0;
  }
  ResetRegisters(&registers);
  registers.ax = 0x4a06;
  registers.si = 4;
  registers.bx = PrintSegment;
  PrintService(1, &registers);
  if (registers.dx != 0x4a06 || registers.ax > 1) {
    Message("Update the HHBIOS display font reader before loading printing fonts.\r\n$");
    return 0;
  }
  for (i = 0; i < 4; ++i) {
    faces[i] = 0;
    if (i && !paths[i][0]) {
      continue;
    }
    for (j = 0; j < i; ++j) {
      if (SamePath(paths[j], paths[i])) {
        break;
      }
    }
    if (j < i) {
      faces[i] = faces[j];
      continue;
    }
    if (!LoadFace(i)) {
      ClosePrintFonts();
      Message(
          "Cannot load printing font: check HHFONT2 geometry, file and XMS/EMS "
          "memory.\r\n$");
      return 0;
    }
    faces[i] = i;
  }
  return 1;
}

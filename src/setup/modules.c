#include <ctype.h>
#include <stdlib.h>
#include <string.h>

#include "../common/font_file.h"
#include "setup.h"

const PrinterModel kPrinters[kPrinterCount] = {
    {0, 0, "None"},
    {1, 0, "PRNT 0 - AR3240"},
    {1, 1, "PRNT 1 - P1351"},
    {1, 2, "PRNT 2 - M2024 / M1724"},
    {1, 3, "PRNT 3 - TH3070 / TH3080"},
    {1, 4, "PRNT 4 - AR2463"},
    {1, 5, "PRNT 5 - LQ1500 / NEC P7"},
    {1, 6, "PRNT 6 - OKI8320 / 8330"},
    {1, 7, "PRNT 7 - M1570"},
    {1, 8, "PRNT 8 - NEC3824"},
    {1, 9, "PRNT 9 - NM9400"},
    {2, 10, "PRTH 10 - HP-2"},
    {2, 11, "PRTH 11 - HP-3"},
    {2, 13, "PRTH 13 - PECAN 300 DPI"},
    {2, 14, "PRTH 14 - PECAN 400 DPI"},
    {2, 16, "PRTH 16 - HP Jet 500"},
    {2, 19, "PRTH 19 - Canon LBP-8II"},
    {2, 20, "PRTH 20 - Beijing HP 400 DPI"},
    {2, 21, "PRTH 21 - XP-11-B4 400 DPI"},
    {2, 22, "PRTH 22 - XP-11-A4 400 DPI"},
    {2, 23, "PRTH 23 - Canon BJ-10ex"}};

static const char* PrintFontPath(const SetupChoices* choices, unsigned reader,
                                 unsigned face) {
  if (choices->print_files[reader][face][0]) {
    return choices->print_files[reader][face];
  }
  if (face && choices->print_files[reader][0][0]) {
    return choices->print_files[reader][0];
  }
  return kFileNames[kFileFont24 + reader];
}

static int ValidFontPath(const char* path) {
  unsigned i;
  for (i = 0; i < 128 && path[i]; ++i) {
    if (!isalnum((unsigned char)path[i]) && !strchr("._-\\:", path[i])) {
      return 0;
    }
  }
  return i < 128;
}

static int SameFontPath(const char* first, const char* second) {
  while (*first &&
         toupper((unsigned char)*first) == toupper((unsigned char)*second)) {
    ++first;
    ++second;
  }
  return toupper((unsigned char)*first) == toupper((unsigned char)*second);
}

static int ReadPrintingFont(const char* path, unsigned reader,
                            FontFileInfo* info) {
  unsigned char header[32];
  FILE* file = fopen(path, "rb");
  int valid = file &&
              fread(header, 1, sizeof(header), file) == sizeof(header) &&
              DecodeFontFile(header, info) && info->format == 2 &&
              info->width == 12 + reader * 4 && info->height == 24 + reader * 8;
  if (valid) {
    valid = !fseek(file, 0, SEEK_END) &&
            ftell(file) == (long)info->payload_bytes + 32;
  }
  if (file) {
    fclose(file);
  }
  return valid;
}

int ValidModuleChoices(const SetupChoices* choices) {
  unsigned i;
  if (choices->special_display > 2 || choices->printer >= kPrinterCount ||
      choices->print_fonts > 31 || choices->print_memory > 2 ||
      choices->printer_flags > 31 || choices->vector_access > 2) {
    return 0;
  }
  for (i = 0; i < 3; ++i) {
    unsigned face;
    unsigned command_size =
        12 + (choices->low ? 3 : 0) + (choices->print_memory ? 3 : 0);
    for (face = 0; face < 4; ++face) {
      const char* path = choices->print_files[i][face];
      if (!ValidFontPath(path)) {
        return 0;
      }
      if (*path) {
        command_size += strlen(path) + 5;
      }
    }
    if (command_size > 126) {
      return 0;
    }
  }
  return 1;
}

const char* ValidateModules(const InstallationFiles* files,
                            const SetupChoices* choices) {
  unsigned i;
  if (!ValidModuleChoices(choices)) {
    return "Invalid optional module selection.";
  }
  if (choices->special_display &&
      !files->size[kFileInt10k + choices->special_display - 1]) {
    return "The selected INT10K/INT10V module is missing.";
  }
  if (choices->printer) {
    unsigned driver = kPrinters[choices->printer].driver;
    if (!files->size[driver == 1 ? kFilePrnt : kFilePrth]) {
      return "The selected PRNT/PRTH printer driver is missing.";
    }
    if (driver == 2 && !files->size[kFilePr]) {
      return "PRTH model selection requires PR.EXE from the distribution.";
    }
    if (driver == 2 && !files->size[kFilePrTable]) {
      return "PR.EXE requires PRTA.TAB from the distribution.";
    }
  }
  for (i = 0; i < 5; ++i) {
    if ((choices->print_fonts & (1U << i)) && !files->size[kFileRead16 + i]) {
      return "A selected printing font reader is missing.";
    }
    if (i >= 1 && i <= 3 && (choices->print_fonts & (1U << i))) {
      unsigned j;
      FontFileInfo info;
      for (j = 0; j < 4; ++j) {
        if (!ReadPrintingFont(PrintFontPath(choices, i - 1, j), i - 1, &info)) {
          return "Printing requires complete HHFONT2 files with 12x24, 16x32 "
                 "or 20x40 cells.";
        }
      }
    }
  }
  if ((choices->print_fonts & 16) &&
      (!files->size[kFileHzkSlT] || !files->size[kFileHzkSlS])) {
    return "READSL needs HZKSLT and HZKSLSTJ for symbols and Song text.";
  }
  return 0;
}

static int ReserveFont(unsigned memory, unsigned long kb, unsigned long* xms,
                       unsigned long* ems) {
  if (memory != 2 && *xms >= kb) {
    *xms -= kb;
    return 1;
  }
  kb = (kb + 15) & ~15UL;
  if (memory != 1 && *ems >= kb) {
    *ems -= kb;
    return 1;
  }
  return 0;
}

const char* ValidatePrintMemory(const MachineCapabilities* machine,
                                const InstallationFiles* files,
                                const SetupChoices* choices) {
  unsigned reader, face;
  unsigned long xms =
      machine->xms_version
          ? (machine->xms_largest < machine->xms_total ? machine->xms_largest
                                                       : machine->xms_total)
          : 0;
  unsigned long ems =
      machine->ems_version >= 0x40 ? (unsigned long)machine->ems_pages * 16 : 0;
  if (!(choices->print_fonts & 14)) {
    return NULL;
  }
  if (machine->loaded) {
    xms = machine->xms_version ? 0x100000UL : 0;
    ems = machine->ems_version >= 0x40 ? 0x100000UL : 0;
  }
  if (choices->font == kFontXms) {
    xms = xms >= 256 ? xms - 256 : 0;
  }
  if (choices->font == kFontEms) {
    ems = ems >= 256 ? ems - 256 : 0;
  }
  if (SelectedVbeMode(choices)) {
    const DisplayFont* display = SelectedDisplayFont(machine, files, choices);
    unsigned long kb;
    if (!display) {
      return "No display font fits the selected mode.";
    }
    kb = (DisplayFontFamilyBytes(machine, files, choices) + 1023) / 1024 + 36;
    if (!ReserveFont(0, kb, &xms, &ems)) {
      return "Insufficient XMS/EMS for the display font.";
    }
  }
  for (reader = 0; reader < 3; ++reader) {
    if (!(choices->print_fonts & (2U << reader))) {
      continue;
    }
    for (face = 0; face < 4; ++face) {
      unsigned previous;
      FontFileInfo info;
      const char* path = PrintFontPath(choices, reader, face);
      for (previous = 0; previous < face; ++previous) {
        if (SameFontPath(path, PrintFontPath(choices, reader, previous))) {
          break;
        }
      }
      if (previous != face) {
        continue;
      }
      if (!ReadPrintingFont(path, reader, &info)) {
        return "Invalid printing font file.";
      }
      if (!ReserveFont(choices->print_memory,
                       (info.payload_bytes + 1023) / 1024, &xms, &ems)) {
        return "Insufficient XMS/EMS for the printing fonts.";
      }
    }
  }
  return NULL;
}

unsigned long ModuleMemoryKb(const InstallationFiles* files,
                             const SetupChoices* choices) {
  unsigned i;
  unsigned long bytes = 0;
  if (choices->special_display) {
    bytes += files->size[kFileInt10k + choices->special_display - 1] + 256;
  }
  for (i = 0; i < 5; ++i) {
    if (choices->print_fonts & (1U << i)) {
      bytes += files->size[kFileRead16 + i] + 256;
    }
  }
  if (choices->printer) {
    if (kPrinters[choices->printer].driver == 1) {
      bytes += files->size[kFilePrnt] + 256;
    } else {
      bytes += files->size[kFilePr] + files->size[kFilePrth] + 512;
    }
  }
  return (bytes + 1023) / 1024;
}

char* AppendModuleCommands(const SetupChoices* choices, char* out) {
  unsigned i;
  const char* low = choices->low ? " /N" : "";
  if (choices->special_display) {
    out += sprintf(out, ".\\%s%s\r\n",
                   kFileNames[kFileInt10k + choices->special_display - 1], low);
  }
  for (i = 0; i < 5; ++i) {
    if (choices->print_fonts & (1U << i)) {
      out += sprintf(out, ".\\%s", kFileNames[kFileRead16 + i]);
      if (i && i < 4) {
        unsigned face;
        for (face = 0; face < 4; ++face) {
          if (choices->print_files[i - 1][face][0]) {
            out += sprintf(out, " /F%u:%s", face,
                           choices->print_files[i - 1][face]);
          }
        }
        if (choices->print_memory) {
          out += sprintf(out, " /%c", choices->print_memory == 1 ? 'X' : 'E');
        }
      } else if (i == 4 && choices->vector_access != 2) {
        out += sprintf(out, " W");
      }
      out += sprintf(out, "%s\r\n", low);
    }
  }
  if (choices->printer) {
    const PrinterModel* printer = &kPrinters[choices->printer];
    if (printer->driver == 1) {
      out += sprintf(out, ".\\PRNT.COM %u", printer->number);
      for (i = 0; i < 5; ++i) {
        if (choices->printer_flags & (1U << i)) {
          out += sprintf(out, " /%u", i + 1);
        }
      }
      out += sprintf(out, "%s\r\n", low);
    } else {
      out += sprintf(out, ".\\PR.EXE %u\r\n.\\PRTH.COM%s\r\n", printer->number,
                     low);
    }
  }
  return out;
}

static char* NextToken(char** cursor) {
  char* token;
  while (isspace((unsigned char)**cursor)) {
    ++*cursor;
  }
  token = *cursor;
  if (!*token) {
    return NULL;
  }
  while (**cursor && !isspace((unsigned char)**cursor)) {
    ++*cursor;
  }
  if (**cursor) {
    *(*cursor)++ = 0;
  }
  return token;
}

static int ParseNumber(const char* text, unsigned base, unsigned* value) {
  char* end;
  unsigned long parsed;
  if (!*text || !isxdigit((unsigned char)*text)) {
    return 0;
  }
  parsed = strtoul(text, &end, base);
  if (*end || parsed > 0xffffUL) {
    return 0;
  }
  *value = (unsigned)parsed;
  return 1;
}

static int FileIndex(char* command) {
  char* name = strrchr(command, '\\');
  char* extension;
  unsigned i;
  name = name ? name + 1 : command;
  if (name[0] && name[1] == ':') {
    name += 2;
  }
  extension = strrchr(name, '.');
  if (extension && (!strcmp(extension, ".COM") || !strcmp(extension, ".EXE"))) {
    *extension = 0;
  }
  for (i = 0; i <= kFileReadsl; ++i) {
    const char* suffix = strchr(kFileNames[i], '.');
    if (suffix && strlen(name) == (unsigned)(suffix - kFileNames[i]) &&
        !strncmp(name, kFileNames[i], strlen(name))) {
      return (int)i;
    }
  }
  return -1;
}

/* Import only simple loader lines. Control flow and arbitrary commands are
 * never executed. Reject unrepresented arguments instead of silently losing
 * them, and leave the caller's choices untouched if any loader is malformed. */
int ReadModuleChoices(const char* batch, SetupChoices* choices) {
  SetupChoices parsed = *choices;
  const char* line = batch;
  unsigned printer_driver = 0, printer_number = 0;
  unsigned saw_pr = 0, saw_memory = 0, saw_core = 0;
  unsigned i;
  if (!batch || strlen(batch) >= kBatchSize) {
    return 0;
  }
  parsed.special_display = parsed.printer = parsed.print_fonts = 0;
  parsed.printer_flags = parsed.vector_access = parsed.print_memory = 0;
  parsed.ime &= ~kImeWubi;
  memset(parsed.print_files, 0, sizeof(parsed.print_files));
  while (*line && *line != '\x1a') {
    char text[256];
    char *cursor, *command, *argument;
    unsigned length = (unsigned)strcspn(line, "\r\n\x1a");
    unsigned count = 0, number = 0;
    unsigned font_memory = 0;
    int file;
    if (length >= sizeof(text)) {
      return 0;
    }
    for (i = 0; i < length; ++i) {
      text[i] = (char)toupper((unsigned char)line[i]);
    }
    text[length] = 0;
    line += length;
    while (*line == '\r' || *line == '\n') {
      ++line;
    }
    cursor = text;
    command = NextToken(&cursor);
    if (!command) {
      continue;
    }
    if (*command == '@') {
      ++command;
    }
    if (!strcmp(command, "LH") || !strcmp(command, "LOADHIGH")) {
      command = NextToken(&cursor);
      if (!command) {
        continue;
      }
    }
    file = FileIndex(command);
    if (file < 0) {
      continue;
    }
    if (file <= kFileCga && !saw_core) {
      parsed.low = 0;
      saw_core = 1;
    }
    if (file <= kFileRead2) {
      parsed.font = file;
    } else if (file == kFileCkbd) {
      parsed.paired = 0;
    } else if (file >= kFileVga && file <= kFileCga) {
      static const unsigned videos[] = {kVideoVga, kVideo102, kVideoEga,
                                        kVideoHga, kVideoCga};
      parsed.video = videos[file - kFileVga];
      parsed.mode = 0;
      parsed.rows = 0;
    } else if (file == kFileWbx) {
      parsed.ime |= kImeWubi;
    } else if (file == kFileInt10k || file == kFileInt10v) {
      parsed.special_display = file - kFileInt10k + 1;
    } else if (file == kFilePrnt) {
      printer_driver = 1;
      printer_number = 5; /* PRNT's default is the Epson-compatible model. */
    } else if (file == kFilePrth) {
      printer_driver = 2;
    } else if (file >= kFileRead16 && file <= kFileReadsl) {
      parsed.print_fonts |= 1U << (file - kFileRead16);
      if (file == kFileReadsl) {
        parsed.vector_access = 2;
      }
    }
    while ((argument = NextToken(&cursor)) != NULL) {
      if (!strcmp(argument, "/N") && file != kFilePr && file != kFileWbx) {
        parsed.low = 1;
      } else if (file == kFileCkbd &&
                 (!strcmp(argument, "/E") || !strcmp(argument, "/B"))) {
        parsed.paired = argument[1] == 'E';
      } else if (file == kFilePrnt && argument[0] == '/' &&
                 argument[1] >= '1' && argument[1] <= '5' && !argument[2]) {
        parsed.printer_flags |= 1U << (argument[1] - '1');
      } else if (file == kFileVesa && !strncmp(argument, "/M:", 3) &&
                 ParseNumber(argument + 3, 16, &number) && number >= 0x100 &&
                 number <= 0x3fff) {
        parsed.video = number == 0x102   ? kVideo102
                       : number == 0x104 ? kVideo104
                       : number == 0x106 ? kVideo106
                                         : kVideoDetected;
        parsed.mode = parsed.video == kVideoDetected ? number : 0;
      } else if (file == kFileVesa && !strncmp(argument, "/R:", 3) &&
                 ParseNumber(argument + 3, 10, &number) && number &&
                 TextRowsMask(number)) {
        parsed.rows = number;
      } else if ((file == kFilePr || file == kFilePrnt) && count++ == 0 &&
                 ParseNumber(argument, 10, &number)) {
        printer_number = number;
        saw_pr |= file == kFilePr;
      } else if (file >= kFileRead24 && file <= kFileRead40 &&
                 (!strcmp(argument, "/X") || !strcmp(argument, "/E"))) {
        if (font_memory) {
          return 0;
        }
        font_memory = argument[1] == 'X' ? 1 : 2;
      } else if (file >= kFileRead24 && file <= kFileRead40 &&
                 !strncmp(argument, "/F", 2)) {
        unsigned face = 0;
        const char* path = argument + 2;
        if (*path >= '0' && *path <= '3') {
          face = *path++ - '0';
        }
        if (*path++ != ':' || !*path || !ValidFontPath(path)) {
          return 0;
        }
        strcpy(parsed.print_files[file - kFileRead24][face], path);
      } else if (file == kFileReadsl && count++ == 0 &&
                 (argument[0] == 'W' ||
                  (argument[0] >= '1' && argument[0] <= '9'))) {
        if (argument[1]) {
          return 0;
        }
        parsed.vector_access = argument[0] == 'W' ? 1 : 2;
      } else {
        return 0;
      }
    }
    if (file == kFilePr && count != 1) {
      return 0;
    }
    if (file >= kFileRead24 && file <= kFileRead40) {
      if (saw_memory && parsed.print_memory != font_memory) {
        return 0;
      }
      parsed.print_memory = font_memory;
      saw_memory = 1;
    }
  }
  if (printer_driver == 2 && !saw_pr) {
    return 0;
  }
  if (printer_driver) {
    for (i = 1; i < kPrinterCount; ++i) {
      if (kPrinters[i].driver == printer_driver &&
          kPrinters[i].number == printer_number) {
        parsed.printer = i;
        break;
      }
    }
    if (i == kPrinterCount) {
      return 0;
    }
  }
  if (!ValidModuleChoices(&parsed)) {
    return 0;
  }
  *choices = parsed;
  return 1;
}

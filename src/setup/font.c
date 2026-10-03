/* The display driver and SETUP use the same header and cell selection rules. */
#include <ctype.h>
#include <string.h>
#include <sys/stat.h>
#ifdef __WATCOMC__
#include <dos.h>
#else
#include <dirent.h>
#endif

#include "setup.h"
#include "../common/font_layout.h"

static int IsCatalogName(const char* name) {
  return strlen(name) == 9 && toupper((unsigned char)name[0]) == 'F' &&
         name[5] == '.' && toupper((unsigned char)name[6]) == 'F' &&
         toupper((unsigned char)name[7]) == 'N' &&
         toupper((unsigned char)name[8]) == 'T';
}

static int AddFont(InstallationFiles* files, const char* name) {
  unsigned char header[32];
  struct stat file_info;
  FontFileInfo info;
  FILE* file;
  int valid;
  if (stat(name, &file_info) || !(file_info.st_mode & S_IFREG)) {
    return 0;
  }
  file = fopen(name, "rb");
  if (!file) {
    return 0;
  }
  valid = fread(header, 1, sizeof(header), file) == sizeof(header) &&
          DecodeFontFile(header, &info) &&
          (unsigned long)file_info.st_size == info.payload_bytes + 32UL;
  fclose(file);
  if (valid) {
    DisplayFont* font = &files->display_fonts[files->display_font_count++];
    strcpy(font->name, name);
    font->info = info;
  }
  return valid;
}

void ScanDisplayFonts(InstallationFiles* files) {
  unsigned count = 0;
  files->display_font_count = 0;
  files->display_font_truncated = 0;
  if (!AddFont(files, "HH20.FNT")) {
    files->size[kFileFont20] = 0;
  }
#ifdef __WATCOMC__
  struct find_t entry;
  unsigned error = _dos_findfirst("F????.FNT", _A_NORMAL, &entry);
  while (!error) {
    if (count++ == 256) {
      files->display_font_truncated = 1;
      break;
    }
    if (IsCatalogName(entry.name)) {
      AddFont(files, entry.name);
    }
    error = _dos_findnext(&entry);
  }
#else
  DIR* directory = opendir(".");
  struct dirent* entry;
  if (!directory) {
    return;
  }
  while ((entry = readdir(directory)) != NULL) {
    if (!IsCatalogName(entry->d_name)) {
      continue;
    }
    if (count++ == 256) {
      files->display_font_truncated = 1;
      break;
    }
    AddFont(files, entry->d_name);
  }
  closedir(directory);
#endif
}

static const DisplayFont* ChooseFont(const InstallationFiles* files,
                                     unsigned width, unsigned height,
                                     unsigned rows, unsigned banked) {
  const DisplayFont* best = NULL;
  unsigned i;
  for (i = 0; i < files->display_font_count; ++i) {
    const DisplayFont* candidate = &files->display_fonts[i];
    if (!banked && candidate->info.format != 1) {
      continue;
    }
    if (BetterFont(&candidate->info, best ? &best->info : NULL,
                   width, height, rows ? rows : 25)) {
      best = candidate;
    }
  }
  return best;
}

const DisplayFont* ChooseDisplayFont(const InstallationFiles* files,
                                    unsigned width, unsigned height,
                                    unsigned rows) {
  return ChooseFont(files, width, height, rows, 1);
}

const DisplayFont* SelectedDisplayFont(const MachineCapabilities* machine,
                                      const InstallationFiles* files,
                                      const SetupChoices* choices) {
  unsigned number = SelectedVbeMode(choices);
  const DisplayMode* mode = FindDisplayMode(machine, number);
  if (mode) {
    return ChooseFont(files, mode->width, mode->height, choices->rows,
                      mode->banked);
  }
  /* Older BIOS probes report only the standard mode bitmap. */
  switch (number) {
    case 0x102:
      return ChooseFont(files, 800, 600, choices->rows,
                         machine->vbe_version >= 0x102);
    case 0x104: return ChooseDisplayFont(files, 1024, 768, choices->rows);
    case 0x106: return ChooseDisplayFont(files, 1280, 1024, choices->rows);
    default: return NULL;
  }
}

unsigned DisplayRows(const DisplayMode* mode, const InstallationFiles* files) {
  static const unsigned rows[] = {25, 43, 50};
  unsigned result = 0;
  unsigned i;
  for (i = 0; i < 3; ++i) {
    if ((mode->rows & (1U << i)) &&
        ChooseFont(files, mode->width, mode->height, rows[i], mode->banked)) {
      result |= 1U << i;
    }
  }
  return result;
}

unsigned long DisplayFontFamilyBytes(const MachineCapabilities* machine,
                                     const InstallationFiles* files,
                                     const SetupChoices* choices) {
  static const unsigned rows[] = {25, 43, 50};
  const DisplayFont* family[4];
  SetupChoices trial = *choices;
  unsigned long bytes = 0;
  unsigned i;
  unsigned j;
  if (!SelectedVbeMode(choices)) {
    return 0;
  }
  const DisplayMode* mode = FindDisplayMode(machine, SelectedVbeMode(choices));
  if ((mode && !mode->banked) || (!mode && machine->vbe_version < 0x102)) {
    const DisplayFont* selected = SelectedDisplayFont(machine, files, choices);
    return selected ? selected->info.payload_bytes : 0;
  }
  for (i = 0; i < 3; ++i) {
    trial.rows = rows[i];
    family[i] = SelectedDisplayFont(machine, files, &trial);
  }
  /* The resident driver prepares taller BIOS surfaces when the preferred
   * mode cannot fit 43 or 50 text rows. It cannot open files after startup. */
  for (i = kVideo104; i <= kVideo106; ++i) {
    unsigned number = i == kVideo104 ? 0x104 : 0x106;
    const DisplayMode* mode = FindDisplayMode(machine, number);
    if (!mode && !(machine->modes & (1U << (i - kVideo102)))) {
      continue;
    }
    trial.video = i;
    for (j = 1; j < 3; ++j) {
      if (!family[j] && (!mode || (mode->rows & (1U << j)))) {
        trial.rows = rows[j];
        family[j] = SelectedDisplayFont(machine, files, &trial);
      }
    }
  }
  family[3] = NULL;
  for (i = 0; i < files->display_font_count; ++i) {
    const DisplayFont* font = &files->display_fonts[i];
    const DisplayFont* smallest = family[3];
    if ((!smallest || smallest->info.format != 1) &&
        (!smallest || font->info.format == 1 ||
         font->info.height < smallest->info.height ||
         (font->info.height == smallest->info.height &&
          font->info.width < smallest->info.width))) {
      family[3] = font;
    }
  }
  for (i = 0; i < 4; ++i) {
    if (!family[i]) {
      continue;
    }
    for (j = 0; j < i && family[j] != family[i]; ++j) {
    }
    if (j == i) {
      bytes += family[i]->info.payload_bytes;
    }
  }
  return bytes;
}

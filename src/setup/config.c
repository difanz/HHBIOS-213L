#include <ctype.h>
#include <string.h>
#include <sys/stat.h>

#include "setup.h"

const char* const kFileNames[kFileCount] = {
    "READ5.COM", "READ4.COM", "READ2.COM", "CKBD.COM", "VGA.COM",
    "VESA.COM",  "EGA.COM",   "HGA.COM",   "CGA.COM",  "HZK16",
    "HH20.FNT",  "PYMB",      "SWMB",      "DBMB",     "WBX.COM"};
const char* const kFontNames[kFontCount] = {"XMS (READ5)", "EMS 4.0 (READ4)",
                                            "Conventional (READ2)"};
const char* const kVideoNames[kVideoCount] = {
    "VGA 640x480", "VESA 800x600",      "VESA 1024x768", "VESA 1280x1024",
    "EGA 640x350", "Hercules (manual)", "CGA 640x200"};
const char* const kVideoCommands[kVideoCount] = {
    "VGA.COM", "VESA.COM /M:102", "VESA.COM /M:104", "VESA.COM /M:106",
    "EGA.COM", "HGA.COM",         "CGA.COM"};

void ScanFiles(InstallationFiles* files) {
  unsigned i;
  struct stat file_info;
  memset(files, 0, sizeof(*files));
  for (i = 0; i < kFileCount; ++i) {
    if (!stat(kFileNames[i], &file_info) && (file_info.st_mode & S_IFREG)) {
      files->size[i] = file_info.st_size;
    }
  }
  /* A truncated/incompatible VESA font must not be recommended. */
  if (files->size[kFileFont20]) {
    unsigned char header[32];
    FILE* file = fopen("HH20.FNT", "rb");
    int ok = file && fread(header, 1, sizeof(header), file) == sizeof(header);
    if (file) {
      fclose(file);
    }
    if (!ok || memcmp(header, "HH20F01\n", 8) || header[8] != 10 || header[9] ||
        header[10] != 23 || header[11] ||
        (unsigned long)header[16] + ((unsigned long)header[17] << 8) +
                ((unsigned long)header[18] << 16) +
                ((unsigned long)header[19] << 24) + 32 !=
            files->size[kFileFont20]) {
      files->size[kFileFont20] = 0;
    }
  }
}

int IsSafeDirectory(const char* path) {
  unsigned i;
  unsigned component = 0;
  /* READ5's legacy executable-path buffer is 40 bytes including HZK16. */
  if (strlen(path) > 32 || !isalpha((unsigned char)path[0]) || path[1] != ':' ||
      path[2] != '\\') {
    return 0;
  }
  for (i = 3; path[i]; ++i) {
    unsigned char character = (unsigned char)path[i];
    if (character == '\\') {
      if (!component) {
        return 0;
      }
      component = 0;
    } else {
      /* Conservative DOS 8.3 directory names; no COMMAND.COM expansion. */
      if (!(isalnum(character) || character == '_' || character == '-' ||
            character == '~') ||
          ++component > 8) {
        return 0;
      }
    }
  }
  return i == 3 || component != 0;
}

static int HasVesaFontMemory(const MachineCapabilities* machine,
                             const InstallationFiles* files,
                             const SetupChoices* choices) {
  /* VESA also retains 32 KiB of text pages and 4 KiB of downloaded font. */
  unsigned long kb = (files->size[kFileFont20] - 32 + 1023) / 1024 + 36;
  unsigned xms = choices->font == kFontXms ? 256 : 0;
  unsigned ems = choices->font == kFontEms ? 16 : 0;
  /* VESA tries XMS, then EMS. Account for READ5/READ4 loaded beforehand.
   * Subtracting READ5 from the largest block is deliberately conservative:
   * query-only detection cannot promise the manager's allocation placement. */
  return (machine->xms_largest >= kb + xms && machine->xms_total >= kb + xms) ||
         (machine->ems_version >= 0x40 &&
          machine->ems_pages >= ems + (kb + 15) / 16);
}

const char* ValidateConfiguration(const MachineCapabilities* machine,
                                  const InstallationFiles* files,
                                  const SetupChoices* choices) {
  unsigned long conventional =
      64; /* keyboard, display, stacks and load margin */
  unsigned long tables = 0;
  unsigned i;
  static const unsigned drivers[kVideoCount] = {
      kFileVga, kFileVesa, kFileVesa, kFileVesa, kFileEga, kFileHga, kFileCga};
  if (choices->font >= kFontCount || choices->video >= kVideoCount ||
      choices->low > 1 || choices->paired > 1 || choices->ime > 15) {
    return "Invalid configuration values.";
  }
  if (machine->dos_major < 3) {
    return "HHBIOS setup requires DOS 3.0 or later.";
  }
  if (machine->loaded) {
    return "HHBIOS is already loaded. Configure from a clean DOS session.";
  }
  if (!files->size[kFileCkbd]) {
    return "Missing CKBD.COM in the installation directory.";
  }
  if (files->size[kFileHzk] != 261696UL) {
    return "HZK16 must contain exactly 261696 bytes (GB2312 16x16).";
  }
  if (!files->size[choices->font]) {
    return "The selected READ*.COM is missing.";
  }
  if (choices->font == kFontXms &&
      (machine->xms_largest < 256 || machine->xms_total < 256)) {
    return "READ5 needs a free 256 KiB XMS block.";
  }
  if (choices->font == kFontEms &&
      (machine->ems_version < 0x40 || machine->ems_pages < 16 ||
       !machine->ems_frame)) {
    return "READ4 needs EMS 4.0, a page frame and 16 free pages.";
  }
  if (!files->size[drivers[choices->video]]) {
    return "The selected display driver is missing.";
  }
  if (choices->video == kVideoVga && machine->adapter != kAdapterVga) {
    return "VGA was not detected. Select the actual adapter.";
  }
  if (choices->video == kVideoEga && machine->adapter < kAdapterEga) {
    return "EGA/VGA was not detected.";
  }
  if (choices->video == kVideoCga && machine->adapter != kAdapterCga &&
      machine->adapter < kAdapterEga) {
    return "A CGA-compatible color adapter was not detected.";
  }
  if (choices->video == kVideoHga && machine->adapter != kAdapterMda) {
    return "Hercules requires a monochrome adapter. Confirm the hardware "
           "manually.";
  }
  if (choices->video >= kVideo102 && choices->video <= kVideo106) {
    if (machine->cpu < 386) {
      return "VESA requires a 386 or newer CPU. Select VGA on older machines.";
    }
    if (!(machine->modes & (1U << (choices->video - kVideo102)))) {
      return "BIOS does not report a compatible planar VBE mode.";
    }
    if (!files->size[kFileFont20]) {
      return "Missing or invalid HH20.FNT for VESA.";
    }
    if (!HasVesaFontMemory(machine, files, choices)) {
      return "Insufficient XMS/EMS for both font stores. Choose VGA or another "
             "reader.";
    }
  }
  for (i = 0; i < 3; ++i) {
    if (choices->ime & (1U << i)) {
      if (!files->size[kFilePy + i]) {
        return "A selected input-method table (PYMB/SWMB/DBMB) is missing.";
      }
      tables += files->size[kFilePy + i];
    }
  }
  if (tables > 45000UL) {
    return "Selected input tables exceed CKBD's 64 KiB segment. Select fewer "
           "tables.";
  }
  if ((choices->ime & kImeWubi) && !files->size[kFileWbx]) {
    return "Wubi requires WBX.COM.";
  }
  conventional += (tables + 1023) / 1024;
  if (choices->ime & kImeWubi) {
    conventional += 48;
  }
  if (choices->font == kFontLow) {
    conventional += 256;
  }
  /* Do not promise all modules fit in a fragmented UMB just because one exists.
   */
  if (machine->free_kb < conventional) {
    return "Not enough conventional memory for a conservative load estimate.";
  }
  return 0;
}

void RecommendConfiguration(const MachineCapabilities* machine,
                            const InstallationFiles* files,
                            SetupChoices* choices) {
  unsigned video_index;
  unsigned font_index;
  static const unsigned preference[] = {kVideo102, kVideoVga, kVideoEga,
                                        kVideoCga};
  memset(choices, 0, sizeof(*choices));
  choices->paired = 1;
  choices->font = kFontLow;
  choices->video = kVideoVga;
  /* Probe recommendations never infer Hercules from an MDA equipment bit. */
  /* Preserve conventional memory before choosing a larger framebuffer. */
  for (font_index = 0; font_index < kFontCount; ++font_index) {
    for (video_index = 0;
         video_index < sizeof(preference) / sizeof(preference[0]);
         ++video_index) {
      SetupChoices trial = *choices;
      trial.video = preference[video_index];
      trial.font = font_index;
      if (!ValidateConfiguration(machine, files, &trial)) {
        *choices = trial;
        if (files->size[kFilePy]) {
          trial.ime = kImePinyin;
          if (!ValidateConfiguration(machine, files, &trial)) {
            *choices = trial;
          }
        }
        return;
      }
    }
  }
}

int MakeBatch(const char* path, const SetupChoices* choices, char* out) {
  const char* low = choices->low ? " /N" : "";
  char* output_cursor = out;
  if (!IsSafeDirectory(path) || choices->font >= kFontCount ||
      choices->video >= kVideoCount) {
    return 0;
  }
  output_cursor += sprintf(
      output_cursor,
      "@ECHO OFF\r\nREM HHBIOS startup - generated by SETUP.EXE\r\n"
      "REM Run once from a clean DOS session. Reboot to change TSRs.\r\n"
      "%c:\r\nCD %s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n",
      path[0], path + 2);
  /* Explicit current-directory paths avoid accidentally loading a different
   * copy from PATH. The directory also supplies VESA's HH20.FNT. */
  output_cursor += sprintf(
      output_cursor,
      ".\\%s%s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n"
      ".\\CKBD.COM /%c%s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n"
      ".\\%s%s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n",
      kFileNames[choices->font], choices->font == kFontLow ? "" : low,
      choices->paired ? 'E' : 'B', low, kVideoCommands[choices->video], low);
  /* WBX uses INT 27h, does not implement /N or internal UMB relocation. */
  if (choices->ime & kImeWubi) {
    output_cursor += sprintf(output_cursor, ".\\WBX.COM\r\n");
  }
  sprintf(output_cursor,
          "GOTO HHEND\r\n:HHFAIL\r\n"
          "ECHO HHBIOS load failed. Check the message above; reboot before "
          "retrying.\r\n:HHEND\r\n@ECHO ON\r\n");
  return 1;
}

static const unsigned char defaults[32] = {
    2,    1,    5,    0x39, 0,    0x1e, 0x1a, 0x4e, 0x4a, 0,    2,
    0x64, 0x68, 0x69, 0x6a, 0x6b, 0x66, 0x6d, 0x6c, 0x71, 0x86, 0x85,
    0x62, 0x70, 0x67, 0,    0,    0x4e, 0x30, 0x4e, 0x4e, 0x4e};

int MakeIni(const char* original, const SetupChoices* choices, char* out) {
  unsigned i;
  char* line_cursor = out;
  const char *line = original, *end;
  for (i = 0; i < 32; ++i) {
    unsigned value = defaults[i];
    unsigned length = 0;
    if (original && *original) {
      end = strchr(line, '\n');
      if (!end || end - line < 2 || !isxdigit((unsigned char)line[0]) ||
          !isxdigit((unsigned char)line[1])) {
        return 0;
      }
      length = (unsigned)(end - line + 1);
      if ((unsigned)(line_cursor - out) + length + 256 >= kIniSize) {
        return 0;
      }
    }
    if (i >= 29) {
      value = choices->ime & (1U << (i - 29)) ? 'Y' : 'N';
    }
    if (length) {
      memcpy(line_cursor, line, length);
      if (i >= 29) {
        char hex[3];
        sprintf(hex, "%02X", value);
        memcpy(line_cursor, hex, 2);
      }
      line_cursor += length;
      line += length;
    } else {
      line_cursor += sprintf(line_cursor, "%02X\r\n", value);
    }
  }
  /* Preserve trailing comments and DOS EOF if supplied. */
  if (original && *original) {
    if (strlen(line) + (unsigned)(line_cursor - out) >= kIniSize) {
      return 0;
    }
    strcpy(line_cursor, line);
  } else {
    *line_cursor = 0;
  }
  return 1;
}

static int FileExists(const char* name) {
  struct stat st;
  return !stat(name, &st);
}
static int IsRegularFileOrAbsent(const char* name) {
  struct stat st;
  return stat(name, &st) || (st.st_mode & S_IFMT) == S_IFREG;
}
static int WriteFile(const char* name, const char* data) {
  FILE* file = fopen(name, "wb");
  int ok;
  if (!file) {
    return 0;
  }
  ok = fwrite(data, 1, strlen(data), file) == strlen(data);
  if (fclose(file)) {
    ok = 0;
  }
  return ok;
}

const char* SaveConfigurationFiles(const char* batch, const char* ini) {
  int bat = FileExists("HHBIOS.BAT"), oldini = FileExists("213L.INI");
  int movedbat = 0;
  int movedini = 0;
  int newbat = 0;
  if (!IsRegularFileOrAbsent("HHBIOS.BAT") ||
      !IsRegularFileOrAbsent("213L.INI")) {
    return "HHBIOS.BAT and 213L.INI must be ordinary files, not "
           "directories/devices.";
  }
  if (FileExists("HHBAT.$$$") || FileExists("HHINI.$$$")) {
    return "Temporary HHBAT.$$$/HHINI.$$$ already exist. Inspect them before "
           "retrying.";
  }
  if ((bat && FileExists("HHBIOS.BAK")) || (oldini && FileExists("213L.BAK"))) {
    return "A .BAK backup already exists. Move it aside before saving again.";
  }
  if (!WriteFile("HHBAT.$$$", batch) || !WriteFile("HHINI.$$$", ini)) {
    goto fail;
  }
  if (bat) {
    if (rename("HHBIOS.BAT", "HHBIOS.BAK")) {
      goto fail;
    }
    movedbat = 1;
  }
  if (oldini) {
    if (rename("213L.INI", "213L.BAK")) {
      goto fail;
    }
    movedini = 1;
  }
  if (rename("HHBAT.$$$", "HHBIOS.BAT")) {
    goto fail;
  }
  newbat = 1;
  if (rename("HHINI.$$$", "213L.INI")) {
    goto fail;
  }
  return 0;
fail:
  if (newbat) {
    remove("HHBIOS.BAT");
  }
  if (movedbat) {
    rename("HHBIOS.BAK", "HHBIOS.BAT");
  }
  if (movedini) {
    rename("213L.BAK", "213L.INI");
  }
  remove("HHBAT.$$$");
  remove("HHINI.$$$");
  return "Could not save both files. Check write access/free space and any "
         ".BAK files.";
}

void ReportMachine(FILE* out, const MachineCapabilities* machine,
                   const InstallationFiles* files) {
  unsigned i;
  fprintf(out,
          "DOS=%u.%u\nCONVENTIONAL_KB=%u\nAFTER_EXIT_KB=%u\nUMB_KB=%u\nCPU=%u\n"
          "XMS_VERSION=%u\nXMS_LARGEST_KB=%u\nXMS_TOTAL_KB=%u\n"
          "EMS_VERSION=%u\nEMS_PAGES=%u\nEMS_FRAME=%u\nDPMI=%u\nADAPTER=%u\n"
          "VBE_VERSION=%u\nVBE_MODES=%u\nHHBIOS_LOADED=%u\nALLOC_STRATEGY=%"
          "u\nUMB_LINK=%u\n",
          machine->dos_major, machine->dos_minor, machine->conventional_kb,
          machine->free_kb, machine->umb_kb, machine->cpu, machine->xms_version,
          machine->xms_largest, machine->xms_total, machine->ems_version,
          machine->ems_pages, machine->ems_frame, machine->dpmi,
          machine->adapter, machine->vbe_version, machine->modes,
          machine->loaded, machine->alloc_strategy, machine->umb_link);
  for (i = 0; i < kFileCount; ++i) {
    fprintf(out, "%s=%lu\n", kFileNames[i], files->size[i]);
  }
}

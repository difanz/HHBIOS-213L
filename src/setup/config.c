#include <ctype.h>
#include <string.h>
#include <sys/stat.h>

#include "setup.h"

const char* const kFileNames[kFileCount] = {
    "READ5.COM", "READ4.COM", "READ2.COM", "CKBD.COM", "VGA.COM",
    "VESA.COM",  "EGA.COM",   "HGA.COM",   "CGA.COM",  "HZK16",
    "HH20.FNT",  "PYMB",      "SWMB",      "DBMB",     "WBX.COM",
    "INT10K.COM", "INT10V.COM", "PRNT.COM", "PRTH.COM", "PR.EXE",
    "READ16.COM", "READ24.COM", "READ32.COM", "READ40.COM", "READSL.COM",
    "HH24.FNT", "HH32.FNT", "HH40.FNT", "HZKSLT", "HZKSLSTJ", "PRTA.TAB"};
const char* const kFontNames[kFontCount] = {"XMS (READ5)", "EMS 4.0 (READ4)",
                                            "Conventional (READ2)"};
const char* const kVideoNames[kVideoCount] = {
    "VGA 640x480", "VESA 800x600",      "VESA 1024x768", "VESA 1280x1024",
    "EGA 640x350", "Hercules (manual)", "CGA 640x200",   "VESA (BIOS mode)"};
const char* const kVideoCommands[kVideoCount] = {
    "VGA.COM", "VESA.COM /M:102", "VESA.COM /M:104", "VESA.COM /M:106",
    "EGA.COM", "HGA.COM",         "CGA.COM",         "VESA.COM"};

void ScanFiles(InstallationFiles* files) {
  unsigned i;
  struct stat file_info;
  memset(files, 0, sizeof(*files));
  for (i = 0; i < kFileCount; ++i) {
    if (!stat(kFileNames[i], &file_info) && (file_info.st_mode & S_IFREG)) {
      files->size[i] = file_info.st_size;
    }
  }
  ScanDisplayFonts(files);
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
  const DisplayFont* font = SelectedDisplayFont(machine, files, choices);
  unsigned long kb = (font->info.payload_bytes + 1023UL) / 1024 + 36;
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
  unsigned mode_number = SelectedVbeMode(choices);
  unsigned rows_mask = TextRowsMask(choices->rows);
  const char* module_error = ValidateModules(files, choices);
  static const unsigned drivers[kVideoCount] = {kFileVga,  kFileVesa, kFileVesa,
                                                kFileVesa, kFileEga,  kFileHga,
                                                kFileCga,  kFileVesa};
  if (choices->font >= kFontCount || choices->video >= kVideoCount ||
      choices->low > 1 || choices->paired > 1 || choices->ime > 15 ||
      !rows_mask ||
      (choices->video == kVideoDetected &&
       (mode_number < 0x100 || mode_number > 0x3fff))) {
    return "Invalid configuration values.";
  }
  if (machine->dos_major < 3) {
    return "HHBIOS setup requires DOS 3.0 or later.";
  }
  if (module_error) {
    return module_error;
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
  if (choices->font == kFontXms && !machine->xms_version) {
    return "READ5 requires an XMS manager.";
  }
  if (!machine->loaded && choices->font == kFontXms &&
      (machine->xms_largest < 256 || machine->xms_total < 256)) {
    return "READ5 needs a free 256 KiB XMS block.";
  }
  if (choices->font == kFontEms &&
      (machine->ems_version < 0x40 || (!machine->loaded && machine->ems_pages < 16) ||
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
  if (!mode_number && rows_mask != 1) {
    return "80x43 and 80x50 require the VESA driver.";
  }
  if (mode_number) {
    const DisplayMode* mode = FindDisplayMode(machine, mode_number);
    if (machine->cpu < 386) {
      return "VESA requires a 386 or newer CPU. Select VGA on older machines.";
    }
    if (!mode && (choices->video == kVideoDetected ||
                  !(machine->modes & (1U << (choices->video - kVideo102))))) {
      return "BIOS does not report a compatible planar VBE mode.";
    }
    if (!((mode                          ? mode->rows
           : choices->video == kVideo106 ? 7
           : choices->video == kVideo104 ? 3 : 1) &
          rows_mask)) {
      return "The selected display mode cannot fit this text layout and IME "
             "row.";
    }
    if (!SelectedDisplayFont(machine, files, choices)) {
      return "No installed VESA font can fit this text layout and IME row.";
    }
    if ((!machine->loaded && !HasVesaFontMemory(machine, files, choices)) ||
        (machine->loaded && !machine->xms_version &&
         (machine->ems_version < 0x40 || !machine->ems_frame))) {
      return "Insufficient XMS/EMS for both font stores. Choose VGA or another "
             "reader.";
    }
  }
  module_error = ValidatePrintMemory(machine, files, choices);
  if (module_error) {
    return module_error;
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
  conventional += ModuleMemoryKb(files, choices);
  if (choices->ime & kImeWubi) {
    conventional += 48;
  }
  if (choices->font == kFontLow) {
    conventional += 256;
  }
  /* Do not promise all modules fit in a fragmented UMB just because one exists.
   */
  if (!machine->loaded && machine->free_kb < conventional) {
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
    for (video_index = 0; video_index < machine->display_count; ++video_index) {
      const DisplayMode* mode = &machine->display_modes[video_index];
      SetupChoices trial = *choices;
      if (machine->edid_status != kEdidPreferred ||
          mode->width != machine->preferred_width ||
          mode->height != machine->preferred_height) {
        continue;
      }
      trial.font = font_index;
      trial.video = kVideoDetected;
      trial.mode = mode->number;
      if (!ValidateConfiguration(machine, files, &trial)) {
        *choices = trial;
        trial.ime = files->size[kFilePy] ? kImePinyin : 0;
        if (!ValidateConfiguration(machine, files, &trial)) {
          *choices = trial;
        }
        return;
      }
    }
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
  char display[80];
  unsigned mode = SelectedVbeMode(choices);
  if (!IsSafeDirectory(path) || choices->font >= kFontCount ||
      choices->video >= kVideoCount || choices->low > 1 ||
      choices->paired > 1 || choices->ime > 15 || !TextRowsMask(choices->rows) ||
      !ValidModuleChoices(choices) ||
      (!mode && choices->rows > 25) ||
      (choices->video == kVideoDetected && (mode < 0x100 || mode > 0x3fff))) {
    return 0;
  }
  strcpy(display, kVideoCommands[choices->video]);
  if (choices->video == kVideoDetected) {
    sprintf(display, "VESA.COM /M:%X", mode);
  }
  if (mode && choices->rows > 25) {
    sprintf(display + strlen(display), " /R:%u", choices->rows);
  }
  output_cursor += sprintf(
      output_cursor,
      "@ECHO OFF\r\nREM HHBIOS startup - generated by SETUP.EXE\r\n"
      "REM Run once from a clean DOS session. Reboot to change TSRs.\r\n"
      "%c:\r\nCD %s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n",
      path[0], path + 2);
  /* Explicit current-directory paths avoid accidentally loading a different
   * copy from PATH. The directory also supplies VESA's font catalog. */
  output_cursor +=
      sprintf(output_cursor,
              ".\\%s%s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n"
              ".\\CKBD.COM /%c%s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n"
              ".\\%s%s\r\nIF ERRORLEVEL 1 GOTO HHFAIL\r\n",
              kFileNames[choices->font], choices->font == kFontLow ? "" : low,
              choices->paired ? 'E' : 'B', low, display, low);
  /* WBX uses INT 27h, does not implement /N or internal UMB relocation. */
  if (choices->ime & kImeWubi) {
    output_cursor += sprintf(output_cursor, ".\\WBX.COM\r\n");
  }
  output_cursor = AppendModuleCommands(choices, output_cursor);
  sprintf(output_cursor,
          "GOTO HHEND\r\n:HHFAIL\r\n"
          "ECHO HHBIOS load failed. Check the message above; reboot before "
          "retrying.\r\n:HHEND\r\n@ECHO ON\r\n");
  return 1;
}

static const unsigned char kIniDefaults[kIniCount] = {
    2,    1,    5,    0,    0x70, 0x71, 0x1f, 0x70, 0,    2,
    0x64, 0x68, 0x69, 0x6a, 0x6b, 0x66, 0x6d, 0x6c, 0x71, 0x86, 0x85,
    0x62, 0x70, 0x67, 0,    0,    0x4e, 0x30, 0x4e, 0x4e, 0x4e};

static int HexDigit(unsigned char c) {
  if (c >= '0' && c <= '9') {
    return c - '0';
  }
  c = (unsigned char)toupper(c);
  return c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
}

int ReadIni(const char* original, IniSettings* settings) {
  IniSettings parsed;
  unsigned i;
  const char* line = original;
  memcpy(parsed.value, kIniDefaults, sizeof(parsed.value));
  if (original && *original) {
    if (strlen(original) >= kIniSize) {
      return 0;
    }
    for (i = 0; i < kIniCount; ++i) {
      const char* end = strchr(line, '\n');
      int high, low;
      const char* eof = strchr(line, '\x1a');
      if (!end || (eof && eof < end) || end - line < 2 ||
          (high = HexDigit(line[0])) < 0) {
        return 0;
      }
      /* CKBD also accepts one hex digit followed by a space. */
      low = HexDigit(line[1]);
      if (low < 0 && line[1] != ' ') {
        return 0;
      }
      parsed.value[i] = (unsigned char)(low < 0 ? high : high * 16 + low);
      line = end + 1;
    }
    if (isxdigit((unsigned char)*line)) {
      return 0;
    }
  }
  *settings = parsed;
  return 1;
}

void SetIniInputMethods(IniSettings* settings, unsigned ime) {
  unsigned i;
  for (i = 0; i < 3; ++i) {
    settings->value[kIniPinyin + i] = (ime & (1U << i)) ? 'Y' : 'N';
  }
}

int MakeIni(const char* original, const IniSettings* settings, char* out) {
  unsigned i;
  IniSettings previous;
  char* line_cursor = out;
  const char *line = original, *end;
  if (!ReadIni(original, &previous)) {
    return 0;
  }
  for (i = 0; i < kIniCount; ++i) {
    unsigned value = settings->value[i];
    unsigned length = 0;
    if (original && *original) {
      end = strchr(line, '\n');
      length = (unsigned)(end - line + 1);
      if ((unsigned)(line_cursor - out) + length >= kIniSize) {
        return 0;
      }
    }
    if (length) {
      memcpy(line_cursor, line, length);
      if (value != previous.value[i]) {
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

int IsFunctionKey(unsigned key) {
  return (key >= 0x3b && key <= 0x44) ||
         (key >= 0x54 && key <= 0x71) || (key >= 0x73 && key <= 0x96) ||
         (key >= 0xf1 && key <= 0xf6);
}

int AssignFunctionKey(IniSettings* settings, unsigned function, unsigned key) {
  unsigned i;
  if (function >= kFunctionKeyCount || !IsFunctionKey(key)) {
    return 0;
  }
  if (settings->value[kIniGreatWall] == 'Y' && function >= 1 && function <= 6 &&
      key != 0xf0 + function) {
    return 0;
  }
  for (i = 0; key && i < kFunctionKeyCount; ++i) {
    if (i != function && settings->value[kIniKeys + i] == key) {
      return 0;
    }
  }
  settings->value[kIniKeys + function] = (unsigned char)key;
  return 1;
}

const char* ValidateIni(const IniSettings* settings) {
  unsigned i, j;
  unsigned shift = settings->value[kIniShift];
  if (shift != 1 && shift != 2 && shift != 0x10) {
    return "Select Right Shift, Left Shift or Scroll Lock.";
  }
  if (settings->value[kIniPhraseKb] < '0' ||
      settings->value[kIniPhraseKb] > '9') {
    return "Phrase extension size must be 0 through 9 KiB.";
  }
  for (i = kIniGreatWall; i < kIniCount; ++i) {
    if (i != kIniPhraseKb && settings->value[i] != 'Y' &&
        settings->value[i] != 'N') {
      return "Input-method and Great Wall switches must be Y or N.";
    }
  }
  for (i = 0; i < kFunctionKeyCount; ++i) {
    unsigned key = settings->value[kIniKeys + i];
    if (!key) {
      return "Every function needs a key; zero would stop CKBD's key table.";
    }
    for (j = 0; key && j < i; ++j) {
      if (settings->value[kIniKeys + j] == key) {
        return "Two functions use the same key.";
      }
    }
  }
  return NULL;
}

int SetGreatWallMode(IniSettings* settings, unsigned enabled) {
  static const unsigned char standard[] = {0x68, 0x69, 0x6a, 0x6b, 0x66, 0x6d};
  IniSettings updated = *settings;
  unsigned i, j;
  if (enabled > 1) {
    return 0;
  }
  updated.value[kIniGreatWall] = enabled ? 'Y' : 'N';
  for (i = 0; i < 6; ++i) {
    updated.value[kIniKeys + 1 + i] = enabled ? 0xf1 + i : standard[i];
  }
  for (i = 1; i <= 6; ++i) {
    for (j = 0; j < kFunctionKeyCount; ++j) {
      if (j != i && updated.value[kIniKeys + i] == updated.value[kIniKeys + j]) {
        return 0;
      }
    }
  }
  *settings = updated;
  return 1;
}

void DescribeFunctionKey(unsigned key, char* out) {
  static const char* const modifiers[] = {"Shift+", "Ctrl+", "Alt+"};
  static const char* const navigation[] = {
      "Ctrl+Left", "Ctrl+Right", "Ctrl+End", "Ctrl+PageDown", "Ctrl+Home",
      "Alt+1", "Alt+2", "Alt+3", "Alt+4", "Alt+5", "Alt+6", "Alt+7",
      "Alt+8", "Alt+9", "Alt+0", "Alt+-", "Alt+=", "Ctrl+PageUp"};
  static const char* const extended[] = {
      "F11", "F12", "Shift+F11", "Shift+F12", "Ctrl+F11", "Ctrl+F12",
      "Alt+F11", "Alt+F12", "Ctrl+Up", "Ctrl+Keypad-", "Ctrl+Keypad5",
      "Ctrl+Keypad+", "Ctrl+Down", "Ctrl+Insert", "Ctrl+Delete", "Ctrl+Tab",
      "Ctrl+Keypad/", "Ctrl+Keypad*"};
  static const char* const great_wall[] = {
      "Insert (GW)", "Home (GW)", "PageUp (GW)", "Delete (GW)",
      "End (GW)", "PageDown (GW)"};
  if (key >= 0x3b && key <= 0x44) {
    sprintf(out, "F%u", key - 0x3b + 1);
  } else if (key >= 0x54 && key <= 0x71) {
    sprintf(out, "%sF%u", modifiers[(key - 0x54) / 10],
            (key - 0x54) % 10 + 1);
  } else if (key >= 0x73 && key <= 0x84) {
    strcpy(out, navigation[key - 0x73]);
  } else if (key >= 0x85 && key <= 0x96) {
    strcpy(out, extended[key - 0x85]);
  } else if (key >= 0xf1 && key <= 0xf6) {
    strcpy(out, great_wall[key - 0xf1]);
  } else if (!key) {
    strcpy(out, "--");
  } else {
    sprintf(out, "%02Xh", key);
  }
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
  int restored = 1;
  if (!IsRegularFileOrAbsent("HHBIOS.BAT") ||
      !IsRegularFileOrAbsent("213L.INI")) {
    return "HHBIOS.BAT and 213L.INI must be ordinary files, not "
           "directories/devices.";
  }
  if (FileExists("HHBAT.$$$") || FileExists("HHINI.$$$")) {
    return "Temporary HHBAT.$$$/HHINI.$$$ already exist. Inspect them before "
           "retrying.";
  }
  if ((bat && !IsRegularFileOrAbsent("HHBIOS.BAK")) ||
      (oldini && !IsRegularFileOrAbsent("213L.BAK"))) {
    return "Backup .BAK names must be ordinary files, not directories/devices.";
  }
  if (!WriteFile("HHBAT.$$$", batch) || !WriteFile("HHINI.$$$", ini)) {
    goto fail;
  }
  if (bat) {
    if (FileExists("HHBIOS.BAK") && remove("HHBIOS.BAK")) {
      goto fail;
    }
    if (rename("HHBIOS.BAT", "HHBIOS.BAK")) {
      goto fail;
    }
    movedbat = 1;
  }
  if (oldini) {
    if (FileExists("213L.BAK") && remove("213L.BAK")) {
      goto fail;
    }
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
  if (newbat && remove("HHBIOS.BAT")) {
    restored = 0;
  }
  if (movedbat && rename("HHBIOS.BAK", "HHBIOS.BAT")) {
    restored = 0;
  }
  if (movedini && rename("213L.BAK", "213L.INI")) {
    restored = 0;
  }
  remove("HHBAT.$$$");
  remove("HHINI.$$$");
  if (!restored) {
    return "Could not restore the previous configuration. Keep the .BAK "
           "files for recovery.";
  }
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
  fprintf(out,
          "EDID_STATUS=%u\nEDID_PREFERRED=%ux%u\nEDID_BIOS_MODE=%u\n"
          "VBE_CATALOG_TRUNCATED=%u\n",
          machine->edid_status, machine->preferred_width,
          machine->preferred_height, machine->preferred_bios,
          machine->display_truncated);
  for (i = 0; i < machine->display_count; ++i) {
    const DisplayMode* mode = &machine->display_modes[i];
    unsigned rows = DisplayRows(mode, files);
    fprintf(out, "VBE_MODE_%04X=%ux%u;%s%s%s\n", mode->number, mode->width,
            mode->height, rows & 1 ? "80x25" : "no fitting font",
            rows & 2 ? ",80x43" : "", rows & 4 ? ",80x50" : "");
  }
  fprintf(out, "FONT_CATALOG_TRUNCATED=%u\n", files->display_font_truncated);
  for (i = 0; i < files->display_font_count; ++i) {
    const DisplayFont* font = &files->display_fonts[i];
    fprintf(out, "FONT_%s=%ux%u;%lu bytes\n", font->name,
            font->info.width, font->info.height,
            (unsigned long)font->info.payload_bytes);
  }
  for (i = 0; i < kFileCount; ++i) {
    fprintf(out, "%s=%lu\n", kFileNames[i], files->size[i]);
  }
}

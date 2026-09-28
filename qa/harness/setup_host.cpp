/* Host ABI only: all decisions and emitted bytes come from production code. */
#include "setup.h"
#ifdef SETUP_IO_TEST
#include <errno.h>
#include <sys/stat.h>

static unsigned file_failures[4];
static unsigned file_calls[4];

static bool FailFileCall(unsigned operation) {
  unsigned call = file_calls[operation]++;
  if (call < 32 && (file_failures[operation] & (1U << call))) {
    errno = operation < 2 ? EACCES : ENOSPC;
    return true;
  }
  return false;
}
#endif
extern "C" {
#ifdef SETUP_IO_TEST
int __real_rename(const char*, const char*);
int __real_remove(const char*);
size_t __real_fwrite(const void*, size_t, size_t, FILE*);
int __real_fclose(FILE*);

void hh_save_failures(unsigned renames, unsigned removals,
                      unsigned writes, unsigned closes) {
  file_failures[0] = renames;
  file_failures[1] = removals;
  file_failures[2] = writes;
  file_failures[3] = closes;
  for (unsigned i = 0; i < 4; ++i) {
    file_calls[i] = 0;
  }
}
int __wrap_rename(const char* source, const char* destination) {
  struct stat info;
  if (FailFileCall(0)) {
    return -1;
  }
  // DOS rename cannot replace a destination, unlike the host's rename.
  if (!stat(destination, &info)) {
    errno = EEXIST;
    return -1;
  }
  return __real_rename(source, destination);
}
int __wrap_remove(const char* name) {
  return FailFileCall(1) ? -1 : __real_remove(name);
}
size_t __wrap_fwrite(const void* data, size_t size, size_t count, FILE* file) {
  if (FailFileCall(2)) {
    return count ? __real_fwrite(data, size, count - 1, file) : 0;
  }
  return __real_fwrite(data, size, count, file);
}
int __wrap_fclose(FILE* file) {
  int result = __real_fclose(file);
  return FailFileCall(3) ? EOF : result;
}
#endif
unsigned hh_abi_size(unsigned type) {
  switch (type) {
    case 0: return sizeof(MachineCapabilities);
    case 1: return sizeof(InstallationFiles);
    case 2: return sizeof(SetupChoices);
    case 3: return sizeof(IniSettings);
    default: return 0;
  }
}
void hh_scan(InstallationFiles* files) {
  ScanFiles(files);
}
const char* hh_font(InstallationFiles* files, unsigned width,
                    unsigned height, unsigned rows) {
  const DisplayFont* font = ChooseDisplayFont(files, width, height, rows);
  return font ? font->name : NULL;
}
unsigned hh_rows(DisplayMode* mode, InstallationFiles* files) {
  return DisplayRows(mode, files);
}
unsigned long hh_font_family(MachineCapabilities* machine,
                             InstallationFiles* files, SetupChoices* choices) {
  return DisplayFontFamilyBytes(machine, files, choices);
}
void hh_recommend(MachineCapabilities* machine, InstallationFiles* files,
                  SetupChoices* choices) {
  RecommendConfiguration(machine, files, choices);
}
const char* hh_validate(MachineCapabilities* machine, InstallationFiles* files,
                        SetupChoices* choices) {
  return ValidateConfiguration(machine, files, choices);
}
int hh_batch(const char* input, SetupChoices* choices, char* out) {
  return MakeBatch(input, choices, out);
}
int hh_ini(const char* input, SetupChoices* choices, char* out) {
  IniSettings settings;
  if (!ReadIni(input, &settings)) return 0;
  SetIniInputMethods(&settings, choices->ime);
  return MakeIni(input, &settings, out);
}
int hh_read_ini(const char* input, IniSettings* settings) {
  return ReadIni(input, settings);
}
int hh_make_ini(const char* input, IniSettings* settings, char* out) {
  return MakeIni(input, settings, out);
}
const char* hh_validate_ini(const IniSettings* settings) {
  return ValidateIni(settings);
}
int hh_assign(IniSettings* settings, unsigned function, unsigned key) {
  return AssignFunctionKey(settings, function, key);
}
int hh_great_wall(IniSettings* settings, unsigned enabled) {
  return SetGreatWallMode(settings, enabled);
}
void hh_key_name(unsigned key, char* out) {
  DescribeFunctionKey(key, out);
}
int hh_import(const char* batch, SetupChoices* choices) {
  return ReadModuleChoices(batch, choices);
}
const char* hh_save(const char* batch, const char* ini) {
  return SaveConfigurationFiles(batch, ini);
}
void hh_edid(MachineCapabilities* machine, const unsigned char* edid) {
  DecodePreferredTiming(machine, edid);
}
void hh_mode(MachineCapabilities* machine, unsigned number, const unsigned char* info) {
  AddDisplayMode(machine, number, info);
}
}

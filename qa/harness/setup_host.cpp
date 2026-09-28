/* Host ABI only: all decisions and emitted bytes come from production code. */
#include "setup.h"
extern "C" {
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

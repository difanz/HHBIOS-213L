/* Host ABI only: all decisions and emitted bytes come from production code. */
#include "setup.h"
extern "C" {
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
  return MakeIni(input, choices, out);
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

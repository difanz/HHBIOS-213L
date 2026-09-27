/* Setup policy is ordinary C, independent of DOS and the UI library. */
#ifndef HHBIOS_SRC_SETUP_SETUP_H_
#define HHBIOS_SRC_SETUP_SETUP_H_
#include <stdio.h>

enum { kFontXms, kFontEms, kFontLow, kFontCount };
enum {
  kVideoVga,
  kVideo102,
  kVideo104,
  kVideo106,
  kVideoEga,
  kVideoHga,
  kVideoCga,
  kVideoDetected,
  kVideoCount
};
enum { kMaxDisplayModes = 64 };
enum { kEdidUnavailable, kEdidInvalid, kEdidNoPreferred, kEdidPreferred };
typedef struct DisplayMode {
  unsigned number;
  unsigned width;
  unsigned height;
  unsigned rows; /* bits 0..2: 80x25, 80x43, 80x50 with HH20.FNT */
} DisplayMode;
enum { kImePinyin = 1, kImeShouwei = 2, kImeTelegraph = 4, kImeWubi = 8 };
enum { kAdapterUnknown, kAdapterMda, kAdapterCga, kAdapterEga, kAdapterVga };
enum {
  kFileRead5,
  kFileRead4,
  kFileRead2,
  kFileCkbd,
  kFileVga,
  kFileVesa,
  kFileEga,
  kFileHga,
  kFileCga,
  kFileHzk,
  kFileFont20,
  kFilePy,
  kFileSw,
  kFileDb,
  kFileWbx,
  kFileCount
};
enum { kBatchSize = 4096, kIniSize = 8192 };
typedef struct MachineCapabilities {
  unsigned dos_major;
  unsigned dos_minor;
  unsigned conventional_kb;
  unsigned free_kb;
  unsigned umb_kb;
  unsigned cpu;
  unsigned xms_version;
  unsigned xms_largest;
  unsigned xms_total;
  unsigned ems_version;
  unsigned ems_pages;
  unsigned ems_frame;
  unsigned dpmi;
  unsigned adapter;
  unsigned vbe_version;
  unsigned modes;
  unsigned loaded;
  unsigned alloc_strategy;
  unsigned umb_link;
  unsigned edid_status;
  unsigned preferred_width;
  unsigned preferred_height;
  unsigned preferred_bios;
  unsigned display_count;
  unsigned display_truncated;
  DisplayMode display_modes[kMaxDisplayModes];
} MachineCapabilities;
typedef struct InstallationFiles {
  unsigned long size[kFileCount];
} InstallationFiles;
typedef struct SetupChoices {
  unsigned font;
  unsigned low;
  unsigned video;
  unsigned ime;
  unsigned paired;
  unsigned mode;
  unsigned rows; /* zero retains the default 25 rows */
} SetupChoices;
void DecodePreferredTiming(MachineCapabilities* machine,
                           const unsigned char* edid);
void AddDisplayMode(MachineCapabilities* machine, unsigned number,
                    const unsigned char* info);
const DisplayMode* FindDisplayMode(const MachineCapabilities* machine,
                                   unsigned number);
unsigned TextRowsMask(unsigned rows);
unsigned SelectedVbeMode(const SetupChoices* choices);
int SwitchTextRows(unsigned rows);
extern const char* const kFileNames[kFileCount];
extern const char* const kFontNames[kFontCount];
extern const char* const kVideoNames[kVideoCount];
extern const char* const kVideoCommands[kVideoCount];
void ProbeMachine(MachineCapabilities* machine);
void ScanFiles(InstallationFiles* files);
int IsSafeDirectory(const char* path);
void RecommendConfiguration(const MachineCapabilities* machine,
                            const InstallationFiles* files,
                            SetupChoices* choices);
const char* ValidateConfiguration(const MachineCapabilities* machine,
                                  const InstallationFiles* files,
                                  const SetupChoices* choices);
int MakeBatch(const char* path, const SetupChoices* choices, char* out);
/* Preserve all original INI lines except the three IME switches. */
int MakeIni(const char* original, const SetupChoices* choices, char* out);
const char* SaveConfigurationFiles(const char* batch, const char* ini);
void ReportMachine(FILE* out, const MachineCapabilities* machine,
                   const InstallationFiles* files);
#endif  // HHBIOS_SRC_SETUP_SETUP_H_

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
  kFileInt10k,
  kFileInt10v,
  kFilePrnt,
  kFilePrth,
  kFilePr,
  kFileRead16,
  kFileRead24,
  kFileRead32,
  kFileRead40,
  kFileReadsl,
  kFileHzk24T, kFileHzk24S, kFileHzk24F, kFileHzk24H, kFileHzk24K,
  kFileHzk32T, kFileHzk32S, kFileHzk32F, kFileHzk32H, kFileHzk32K,
  kFileHzk40T, kFileHzk40S, kFileHzk40F, kFileHzk40H, kFileHzk40K,
  kFileHzkSlT, kFileHzkSlS,
  kFilePrTable,
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
  unsigned special_display; /* 0: none, 1: INT10K, 2: INT10V */
  unsigned printer; /* index into kPrinters */
  unsigned print_fonts; /* READ16, READ24, READ32, READ40, READSL */
  unsigned print_access; /* 0: DOS file reads (W), 1..9: sector cache size */
  char print_styles[3][5]; /* READ24/32/40 style aliases; empty uses Song. */
  unsigned printer_flags; /* PRNT's /1 through /5 switches. */
  unsigned vector_access; /* 0: follow print_access, 1: file, 2: sector. */
} SetupChoices;
enum {
  kIniDisplay = 0,
  kIniDisplay2 = 1,
  kIniDisplay3 = 2,
  kIniBand = 3,
  kIniColors = 5,
  kIniShift = 10,
  kIniKeys = 11,
  kIniGreatWall = 27,
  kIniPhraseKb = 28,
  kIniPinyin = 29,
  kIniShouwei = 30,
  kIniTelegraph = 31,
  kIniCount = 32,
  kFunctionKeyCount = 14
};
typedef struct IniSettings {
  unsigned char value[kIniCount];
} IniSettings;
typedef struct PrinterModel {
  unsigned driver; /* 0: none, 1: PRNT, 2: PRTH */
  unsigned number;
  const char* name;
} PrinterModel;
enum { kPrinterCount = 21 };
extern const PrinterModel kPrinters[kPrinterCount];
const char* ValidateModules(const InstallationFiles* files,
                           const SetupChoices* choices);
int ValidModuleChoices(const SetupChoices* choices);
char* AppendModuleCommands(const SetupChoices* choices, char* out);
unsigned long ModuleMemoryKb(const InstallationFiles* files,
                             const SetupChoices* choices);
int ReadModuleChoices(const char* batch, SetupChoices* choices);
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
int ReadIni(const char* original, IniSettings* settings);
const char* ValidateIni(const IniSettings* settings);
void SetIniInputMethods(IniSettings* settings, unsigned ime);
int SetGreatWallMode(IniSettings* settings, unsigned enabled);
/* Replace changed values, preserving comments, reserved fields and DOS EOF. */
int MakeIni(const char* original, const IniSettings* settings, char* out);
int AssignFunctionKey(IniSettings* settings, unsigned function, unsigned key);
int IsFunctionKey(unsigned key);
void DescribeFunctionKey(unsigned key, char* out);
const char* SaveConfigurationFiles(const char* batch, const char* ini);
void ReportMachine(FILE* out, const MachineCapabilities* machine,
                   const InstallationFiles* files);
#endif  // HHBIOS_SRC_SETUP_SETUP_H_

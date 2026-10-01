/* BIOS data decoding and display policy, shared with host tests. */
#include <string.h>

#include "setup.h"
#include "vesa.h"

static unsigned ReadWord(const unsigned char* bytes) {
  return bytes[0] | ((unsigned)bytes[1] << 8);
}

void DecodePreferredTiming(MachineCapabilities* machine,
                           const unsigned char* edid) {
  unsigned i;
  unsigned checksum = 0;
  const unsigned char* timing = edid + 54;
  machine->preferred_width = machine->preferred_height = 0;
  machine->edid_status = kEdidInvalid;
  for (i = 0; i < 128; ++i) {
    checksum += edid[i];
  }
  if (memcmp(edid, "\0\xff\xff\xff\xff\xff\xff\0", 8) || (checksum & 255) ||
      edid[18] != 1 || edid[19] > 4) {
    return;
  }
  machine->edid_status = kEdidNoPreferred;
  /* A largest standard timing is not evidence of the panel's native size.
   * Do not turn an interlaced field height into a progressive panel size. */
  if (!(edid[24] & 2) || !ReadWord(timing) || (timing[17] & 0x80)) {
    return;
  }
  unsigned width = timing[2] | ((unsigned)(timing[4] & 0xf0) << 4);
  unsigned height = timing[5] | ((unsigned)(timing[7] & 0xf0) << 4);
  if (!width || !height || !(timing[3] | (timing[4] & 15)) ||
      !(timing[6] | (timing[7] & 15))) {
    machine->edid_status = kEdidInvalid;
    return;
  }
  machine->preferred_width = width;
  machine->preferred_height = height;
  machine->edid_status = kEdidPreferred;
}

unsigned TextRowsMask(unsigned rows) {
  return !rows || rows == 25 ? 1 : rows == 43 ? 2 : rows == 50 ? 4 : 0;
}

unsigned SelectedVbeMode(const SetupChoices* choices) {
  static const unsigned modes[] = {0x102, 0x104, 0x106};
  if (choices->video >= kVideo102 && choices->video <= kVideo106) {
    return modes[choices->video - kVideo102];
  }
  return choices->video == kVideoDetected ? choices->mode : 0;
}

const DisplayMode* FindDisplayMode(const MachineCapabilities* machine,
                                   unsigned number) {
  unsigned i;
  for (i = 0; i < machine->display_count; ++i) {
    if (machine->display_modes[i].number == number) {
      return &machine->display_modes[i];
    }
  }
  return 0;
}

static void RecordBiosMode(MachineCapabilities* machine, unsigned number,
                          const unsigned char* info, unsigned status) {
  unsigned i;
  BiosDisplayMode mode;
  for (i = 0; i < machine->bios_mode_count; ++i) {
    if (machine->bios_modes[i].number == number) {
      return;
    }
  }
  if (machine->bios_mode_count == kMaxDisplayModes) {
    machine->display_truncated = 1;
    return;
  }
  mode.number = number;
  mode.width = ReadWord(info + 18);
  mode.height = ReadWord(info + 20);
  mode.bits_per_pixel = info[25];
  mode.status = status;
  i = machine->bios_mode_count++;
  while (i) {
    const BiosDisplayMode* previous = &machine->bios_modes[i - 1];
    if (previous->width < mode.width ||
        (previous->width == mode.width && previous->height < mode.height) ||
        (previous->width == mode.width && previous->height == mode.height &&
         previous->bits_per_pixel <= mode.bits_per_pixel)) {
      break;
    }
    machine->bios_modes[i] = *previous;
    --i;
  }
  machine->bios_modes[i] = mode;
}

void AddDisplayMode(MachineCapabilities* machine, unsigned number,
                    const unsigned char* info) {
  struct VbeSurface surface;
  unsigned width = ReadWord(info + 18);
  unsigned height = ReadWord(info + 20);
  unsigned banked;
  unsigned position;
  DisplayMode mode;
  if (number < 0x100 || number > 0x3fff) {
    return;
  }
  if ((ReadWord(info) & 0x19) == 0x19 &&
      machine->edid_status == kEdidPreferred &&
      width == machine->preferred_width &&
      height == machine->preferred_height) {
    machine->preferred_bios = 1;
  }
  if (!DecodeConsoleModeInfo(&surface, info, machine->vbe_version, number)) {
    unsigned attributes = ReadWord(info);
    unsigned status = !(attributes & 1) ? kModeUnavailable
                      : !(attributes & 0x10) ? kModeText
                      : info[25] != 4 || info[24] != 4 || info[27] != 3
                          ? kModeFormat : kModeLayout;
    RecordBiosMode(machine, number, info, status);
    return;
  }
  if (surface.format == FORMAT_DIRECT) {
    /* A linear console does not need spare image pages. 43/50-row text is
     * offered only when a 64 KiB A000 window can hold the extra pages. */
    banked = surface.window < 2 && surface.segment == 0xa000 &&
             surface.window_kb == 64 && surface.granularity_kb &&
             surface.granularity_kb <= 64 && !(64 % surface.granularity_kb);
  } else {
    banked = machine->vbe_version >= 0x102 && info[29] &&
             (info[2 + surface.window] & 1);
    if (!banked && (width != 800 || height != 600 || surface.pitch != 100)) {
      RecordBiosMode(machine, number, info, kModeBanking);
      return;
    }
  }
  RecordBiosMode(machine, number, info, kModeUsable);
  if (number == 0x102 || number == 0x104 || number == 0x106) {
    machine->modes |= 1U << ((number - 0x102) / 2);
  }
  if (FindDisplayMode(machine, number)) {
    return;
  }
  if (machine->display_count == kMaxDisplayModes) {
    machine->display_truncated = 1;
    return;
  }
  mode.number = number;
  mode.width = width;
  mode.height = height;
  mode.banked = banked != 0;
  mode.rows = 1 | (banked && height >= 16 * 44 ? 2 : 0) |
              (banked && height >= 16 * 51 ? 4 : 0);
  position = machine->display_count++;
  while (position && (machine->display_modes[position - 1].width > width ||
                      (machine->display_modes[position - 1].width == width &&
                       machine->display_modes[position - 1].height > height))) {
    machine->display_modes[position] = machine->display_modes[position - 1];
    --position;
  }
  machine->display_modes[position] = mode;
}

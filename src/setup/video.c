/* Display selection uses dimensions; BIOS numbers belong in the inventory. */
#include <string.h>

#include "forms.h"

typedef struct VideoItem {
  unsigned driver;
  const DisplayMode* mode;
} VideoItem;

typedef struct VideoDialog {
  const MachineCapabilities* machine;
  const InstallationFiles* files;
  SetupChoices draft;
  VideoItem items[kMaxDisplayModes + 4];
  unsigned count;
  unsigned previous;
  unsigned heights[3];
  unsigned height_count;
  a_list video;
  a_list rows;
  Form form;
  unsigned detail_field;
  char detail[3][72];
} VideoDialog;

typedef struct ModeInventory {
  const MachineCapabilities* machine;
  const InstallationFiles* files;
  a_list list;
  Form form;
  unsigned detail_field;
  char detail[2][72];
} ModeInventory;

static const char* ModeIssue(const MachineCapabilities* machine,
                             const InstallationFiles* files,
                             const BiosDisplayMode* mode) {
  switch (mode->status) {
    case kModeUnavailable:
      return LocalizedText("BIOS unavailable", "BIOS 不支持");
    case kModeText:
      return LocalizedText("BIOS text mode", "BIOS 文本模式");
    case kModeFormat:
      return LocalizedText("Color format unsupported", "暂不支持此颜色格式");
    case kModeLayout:
      return LocalizedText("Display layout unsupported", "暂不支持此显示布局");
    case kModeBanking:
      return LocalizedText("Banking unavailable", "显存分页不可用");
  }
  if (machine->cpu < 386) {
    return LocalizedText("Requires 386", "需要 386 以上 CPU");
  }
  if (!files->size[kFileVesa]) {
    return LocalizedText("VESA.COM missing", "缺少 VESA.COM");
  }
  const DisplayMode* compatible = FindDisplayMode(machine, mode->number);
  if (!compatible || !DisplayRows(compatible, files)) {
    return LocalizedText("Matching font missing", "缺少合适的字库");
  }
  return LocalizedText("HHBIOS supported", "HHBIOS 支持");
}

static bool InventoryText(const char** data, unsigned item, char* out,
                          unsigned capacity) {
  const ModeInventory* inventory = (const ModeInventory*)data;
  if (item >= inventory->machine->bios_mode_count) {
    return false;
  }
  if (capacity) {
    const BiosDisplayMode* mode = &inventory->machine->bios_modes[item];
    char colors[24];
    if (mode->status == kModeText) {
      strcpy(colors, LocalizedText("text", "文本"));
    } else if (mode->bits_per_pixel <= 8) {
      sprintf(colors, LocalizedText("%u colors", "%u 色"),
              1U << mode->bits_per_pixel);
    } else if (mode->bits_per_pixel == 15 || mode->bits_per_pixel == 16) {
      sprintf(colors, LocalizedText("%uK colors", "%uK 色"),
              mode->bits_per_pixel == 15 ? 32 : 64);
    } else if (mode->bits_per_pixel == 24 || mode->bits_per_pixel == 32) {
      strcpy(colors, LocalizedText("16.7M colors", "真彩色"));
    } else {
      sprintf(colors, "%u bpp", mode->bits_per_pixel);
    }
    snprintf(out, capacity, "%4u x %-4u  %-13s %s", mode->width,
             mode->height, colors,
             ModeIssue(inventory->machine, inventory->files, mode));
  }
  return true;
}

static void InventoryChanged(a_dialog* dialog, void* data) {
  ModeInventory* inventory = (ModeInventory*)data;
  if (inventory->machine->bios_mode_count) {
    const BiosDisplayMode* mode =
        &inventory->machine->bios_modes[inventory->list.choice];
    sprintf(inventory->detail[0],
            LocalizedText("Technical details: VBE %04Xh, %u bits/pixel",
                          "技术信息：VBE 编号 %04Xh，每像素 %u 位"),
            mode->number, mode->bits_per_pixel);
    strcpy(inventory->detail[1],
           ModeIssue(inventory->machine, inventory->files, mode));
  }
  if (dialog) {
    uiprintfield(dialog, &inventory->form.fields[inventory->detail_field]);
    uiprintfield(dialog, &inventory->form.fields[inventory->detail_field + 1]);
  }
}

static void ShowModeInventory(const MachineCapabilities* machine,
                              const InstallationFiles* files) {
  ModeInventory inventory = {0};
  char heading[80];
  inventory.machine = machine;
  inventory.files = files;
  inventory.list.data = (const char**)&inventory;
  inventory.list.get = InventoryText;
  sprintf(heading, LocalizedText("BIOS display modes: %u%s",
                                "显卡提供的全部模式：%u%s"),
          machine->bios_mode_count, machine->display_truncated ? "+" : "");
  AddParagraph(&inventory.form, 1, 2, 68, heading);
  if (machine->bios_mode_count) {
    AddField(&inventory.form, 3, 2, 9, 68, FLD_LISTBOX, &inventory.list);
  } else {
    AddParagraph(&inventory.form, 4, 2, 68,
                 LocalizedText("No VBE display modes were reported.",
                               "显卡没有提供 VBE 模式列表。"));
  }
  inventory.detail_field = inventory.form.field_count;
  for (unsigned i = 0; i < 2; ++i) {
    AddField(&inventory.form, 13 + i, 2, 1, 68, FLD_TEXT,
             inventory.detail[i]);
  }
  AddParagraph(&inventory.form, 16, 2, 68,
               LocalizedText("Up/Down: select   PgUp/PgDn: page   Home/End: first/last",
                             "方向键选择  PgUp/PgDn 翻页  Home/End 首项／末项"));
  AddButton(&inventory.form, 18, 27, 18, LocalizedText("&Back", "返回 (&B)"),
            kCmdCancel, 1);
  inventory.form.changed = InventoryChanged;
  inventory.form.change_data = &inventory;
  InventoryChanged(NULL, &inventory);
  RunForm(&inventory.form, LocalizedText("All display modes", "全部显示模式"),
          20, 74, 0);
}

static bool VideoText(const char** data, unsigned item, char* out,
                      unsigned capacity) {
  const VideoDialog* video = (const VideoDialog*)data;
  if (item >= video->count) {
    return false;
  }
  if (capacity) {
    const DisplayMode* mode = video->items[item].mode;
    if (mode) {
      snprintf(out, capacity, LocalizedText("%u x %u  16 colors%s",
                                          "%u x %u  16 色%s"),
               mode->width, mode->height,
               video->machine->edid_status == kEdidPreferred &&
                       mode->width == video->machine->preferred_width &&
                       mode->height == video->machine->preferred_height
                   ? " *" : "");
    } else {
      snprintf(out, capacity, "%s", kVideoNames[video->items[item].driver]);
    }
  }
  return true;
}

static bool RowsText(const char** data, unsigned item, char* out,
                     unsigned capacity) {
  const VideoDialog* video = (const VideoDialog*)data;
  if (item >= (video->height_count ? video->height_count : 1)) {
    return false;
  }
  if (capacity) {
    if (video->height_count) {
      snprintf(out, capacity, LocalizedText("80 columns x %u rows", "80 列 x %u 行"),
               video->heights[item]);
    } else {
      snprintf(out, capacity, "%s", LocalizedText("No matching font", "没有合适的字库"));
    }
  }
  return true;
}

static void VideoChanged(a_dialog* dialog, void* data) {
  static const unsigned heights[] = {25, 43, 50};
  VideoDialog* video = (VideoDialog*)data;
  const VideoItem* item = &video->items[video->video.choice];
  if (video->previous != video->video.choice) {
    unsigned allowed = item->mode ? DisplayRows(item->mode, video->files) : 1;
    video->draft.video = item->driver;
    video->draft.mode = item->mode ? item->mode->number : 0;
    video->height_count = 0;
    video->rows.choice = 0;
    for (unsigned i = 0; i < 3; ++i) {
      if (allowed & (1U << i)) {
        if (video->draft.rows == heights[i]) {
          video->rows.choice = video->height_count;
        }
        video->heights[video->height_count++] = heights[i];
      }
    }
    video->previous = video->video.choice;
    if (dialog) {
      uiupdatelistbox(&video->rows);
    }
  }
  video->draft.rows =
      video->height_count ? video->heights[video->rows.choice] : 25;
  memset(video->detail, 0, sizeof(video->detail));
  const DisplayFont* font =
      SelectedDisplayFont(video->machine, video->files, &video->draft);
  if (font) {
    sprintf(video->detail[0],
            LocalizedText("Automatic font: %u x %u pixels per cell",
                          "自动选择字号：每格 %u x %u 像素"),
            font->info.width, font->info.height);
  } else if (item->mode) {
    strcpy(video->detail[0], LocalizedText("Install a matching display font to use this resolution.",
                                         "请安装合适的显示字库，再使用此分辨率。"));
  }
  strcpy(video->detail[1], LocalizedText("The input-method status bar has its own row.",
                                       "输入法状态栏单独占一行，不占用程序的文本行。"));
  sprintf(video->detail[2], LocalizedText("Resolution %u of %u%s", "第 %u / %u 项%s"),
          video->video.choice + 1, video->count,
          video->machine->display_truncated
              ? LocalizedText(" (BIOS list limit reached)", "（BIOS 列表达到上限）") : "");
  if (dialog) {
    for (unsigned i = 0; i < 3; ++i) {
      uiprintfield(dialog, &video->form.fields[video->detail_field + i]);
    }
  }
}

static void AddVideoItem(VideoDialog* video, unsigned driver,
                          const DisplayMode* mode) {
  VideoItem* item = &video->items[video->count];
  item->driver = driver;
  item->mode = mode;
  if ((mode && mode->number == SelectedVbeMode(&video->draft)) ||
      (!mode && driver == video->draft.video)) {
    video->video.choice = video->count;
  }
  ++video->count;
}

void ShowVideoOptions(const MachineCapabilities* machine,
                      const InstallationFiles* files, SetupChoices* choices) {
  VideoDialog video = {0};
  video.machine = machine;
  video.files = files;
  video.draft = *choices;
  video.previous = 0xffff;
  if (machine->adapter == kAdapterVga) {
    AddVideoItem(&video, kVideoVga, NULL);
  }
  if (machine->cpu >= 386) {
    for (unsigned i = 0; i < machine->display_count; ++i) {
      const DisplayMode* mode = &machine->display_modes[i];
      /* Equivalent BIOS numbers remain individually visible in All modes. */
      if (video.count && video.items[video.count - 1].mode &&
          video.items[video.count - 1].mode->width == mode->width &&
          video.items[video.count - 1].mode->height == mode->height) {
        VideoItem* existing = &video.items[video.count - 1];
        if (mode->number == SelectedVbeMode(choices) ||
            (existing->mode->number != SelectedVbeMode(choices) &&
             mode->banked > existing->mode->banked)) {
          existing->mode = mode;
        }
        if (mode->number == SelectedVbeMode(choices)) {
          video.video.choice = video.count - 1;
        }
      } else {
        AddVideoItem(&video, kVideoDetected, mode);
      }
    }
  }
  if (machine->adapter >= kAdapterEga) {
    AddVideoItem(&video, kVideoEga, NULL);
  }
  if (machine->adapter == kAdapterMda) {
    AddVideoItem(&video, kVideoHga, NULL);
  } else if (machine->adapter >= kAdapterCga) {
    AddVideoItem(&video, kVideoCga, NULL);
  }
  if (!video.count) {
    ShowMessage(LocalizedText("No supported display adapter was detected.",
                               "未检测到支持的显示适配器。"));
    return;
  }
  video.video.data = (const char**)&video;
  video.video.get = VideoText;
  video.rows.data = (const char**)&video;
  video.rows.get = RowsText;
  for (;;) {
    Form* form = &video.form;
    memset(form, 0, sizeof(*form));
    AddParagraph(form, 1, 2, 33, LocalizedText("Resolution", "显示分辨率"));
    AddParagraph(form, 1, 40, 30, LocalizedText("Text layout", "文本列数与行数"));
    AddField(form, 3, 2, 8, 33, FLD_LISTBOX, &video.video);
    AddField(form, 3, 40, 3, 30, FLD_LISTBOX, &video.rows);
    if (machine->edid_status == kEdidPreferred) {
      char preferred[72];
      sprintf(preferred, LocalizedText("* Screen preferred: %u x %u",
                                      "* 屏幕首选：%u x %u"),
              machine->preferred_width, machine->preferred_height);
      AddParagraph(form, 12, 2, 68, preferred);
    }
    video.detail_field = form->field_count;
    for (unsigned i = 0; i < 3; ++i) {
      AddField(form, 13 + i, 2, 1, 68, FLD_TEXT, video.detail[i]);
    }
    AddParagraph(form, 16, 2, 68,
                 LocalizedText("Up/Down: select   PgUp/PgDn: page   Tab: switch list",
                               "方向键选择  PgUp/PgDn 翻页  Tab 切换列表"));
    AddButton(form, 18, 3, 18, LocalizedText("&OK", "确定 (&O)"), kCmdAccept, 1);
    AddButton(form, 18, 26, 18, LocalizedText("&Cancel", "取消 (&C)"), kCmdCancel, 0);
    AddButton(form, 18, 49, 21, LocalizedText("&All modes", "全部模式 (&A)"), kCmdProbe, 0);
    form->changed = VideoChanged;
    form->change_data = &video;
    VideoChanged(NULL, &video);
    ui_event event = RunForm(form, LocalizedText("Display", "显示设置"), 20, 74, 0);
    if (event == kCmdProbe) {
      ShowModeInventory(machine, files);
    } else if (event == kCmdAccept) {
      if (!video.height_count) {
        ShowMessage(video.detail[0]);
      } else {
        *choices = video.draft;
        return;
      }
    } else {
      return;
    }
  }
}

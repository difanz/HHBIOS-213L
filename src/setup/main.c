/* Open Watcom UI owns dialogs, focus, keyboard and mouse dispatch. */
#include <ctype.h>
#include <direct.h>
#include <dos.h>
#include <io.h>
#include <stdlib.h>
#include <string.h>

#include "forms.h"
#include "screen.h"

static MachineCapabilities machine;
static InstallationFiles files;
static SetupChoices choices;
static IniSettings settings;
static char directory[80];
static char batch[kBatchSize];
static char ini[kIniSize];
static char original[kIniSize];
static int chinese = 0;
static int ini_ok = 1;
static int batch_ok = 1;

const char* LocalizedText(const char* en, const char* zh) {
  return chinese ? (IsScreenActive() ? EncodeScreenText(zh) : zh) : en;
}

static void DescribeDisplay(char* out, const SetupChoices* selected) {
  const DisplayMode* mode =
      FindDisplayMode(&machine, SelectedVbeMode(selected));
  if (mode) {
    sprintf(out, "VESA %ux%u (%03Xh), 80x%u", mode->width, mode->height,
            mode->number, selected->rows ? selected->rows : 25);
  } else {
    sprintf(out, "%s, 80x%u", kVideoNames[selected->video],
            selected->rows ? selected->rows : 25);
  }
  const DisplayFont* font = SelectedDisplayFont(&machine, &files, selected);
  if (font) {
    sprintf(out + strlen(out), ", %ux%u %s", font->info.width,
            font->info.height, font->name);
  }
}

static void DescribeMonitor(char* out) {
  if (machine.edid_status == kEdidPreferred) {
    sprintf(out, LocalizedText("Screen preferred: %ux%u", "屏幕首选：%ux%u"),
            machine.preferred_width, machine.preferred_height);
    for (unsigned i = 0; i < machine.display_count; ++i) {
      if (machine.display_modes[i].width == machine.preferred_width &&
          machine.display_modes[i].height == machine.preferred_height) {
        return;
      }
    }
    strcat(out,
           LocalizedText(" (no compatible VBE mode)", "（无兼容 VBE 模式）"));
  } else {
    strcpy(out, LocalizedText("Screen preferred: unknown (EDID unavailable)",
                              "屏幕首选：未知（无可用 EDID 首选时序）"));
  }
}

static int ReadConfigurationFile(const char* name, char* out, unsigned capacity) {
  FILE* file = fopen(name, "rb");
  unsigned byte_count;
  out[0] = 0;
  if (!file) {
    return access(name, 0) != 0;
  }
  byte_count = fread(out, 1, capacity - 1, file);
  int extra = fgetc(file);
  int ok = extra == EOF && !ferror(file);
  fclose(file);
  out[byte_count] = 0;
  return ok && !memchr(out, 0, byte_count);
}

static void LoadConfiguration(void) {
  ReadIni(NULL, &settings);
  ini_ok = ReadConfigurationFile("213L.INI", original, sizeof(original));
  if (ini_ok) {
    ini_ok = ReadIni(original, &settings);
  }
  if (ini_ok && *original) {
    choices.ime &= kImeWubi;
    for (unsigned i = 0; i < 3; ++i) {
      if (toupper(settings.value[kIniPinyin + i]) == 'Y') {
        choices.ime |= 1U << i;
      }
    }
  } else {
    SetIniInputMethods(&settings, choices.ime);
  }
  const char* name = "HHBIOS.BAT";
  if (access(name, 0)) {
    name = access("213L.BAT", 0) ? "C:\\213L.BAT" : "213L.BAT";
  }
  batch_ok = ReadConfigurationFile(name, batch, sizeof(batch));
  if (batch_ok && *batch) {
    batch_ok = ReadModuleChoices(batch, &choices);
  }
}

static const char* PrepareConfiguration() {
  const char* error;
  if (!batch_ok) {
    return LocalizedText("The existing startup batch could not be imported.",
                          "无法读取原启动批处理文件的配置。");
  }
  ScanFiles(&files);
  error = ValidateConfiguration(&machine, &files, &choices);
  if (error) {
    return error;
  }
  if (!MakeBatch(directory, &choices, batch)) {
    return LocalizedText(
        "Use a DOS 8.3 directory path of at most 32 characters.",
        "安装目录须为 DOS 短路径，完整路径不超过 32 字节。");
  }
  if (!ini_ok || !MakeIni(original, &settings, ini)) {
    return LocalizedText(
        "213L.INI is malformed or too large. Keep a copy and repair it first.",
        "213L.INI 格式有误或过大，请先备份并修复原配置。");
  }
  error = ValidateIni(&settings);
  if (error) {
    return error;
  }
  return 0;
}

void AddField(Form* form, unsigned row, unsigned col, unsigned height,
              unsigned width, a_field_type type, void* data) {
  VFIELD* field = &form->fields[form->field_count++];
  field->area.row = row;
  field->area.col = col;
  field->area.height = height;
  field->area.width = width;
  field->typ = type;
  field->u.ptr = data;
}

void AddParagraph(Form* form, unsigned row, unsigned col, unsigned width,
                  const char* text) {
  while (*text) {
    unsigned length = 0;
    unsigned space = 0;
    while (text[length] && text[length] != '\n') {
      unsigned count = ScreenTextCharacterWidth(text + length);
      if (length + count > width) {
        break;
      }
      if (text[length] == ' ') {
        space = length;
      }
      length += count;
    }
    if (text[length] && text[length] != '\n' && space) {
      length = space;
    }
    char* line = form->text + form->text_used;
    memcpy(line, text, length);
    line[length] = 0;
    form->text_used += length + 1;
    AddField(form, row++, col, 1, width, FLD_TEXT, line);
    text += length;
    if (*text == '\n' || *text == ' ') {
      ++text;
    }
  }
}

void AddButton(Form* form, unsigned row, unsigned col, unsigned width,
               const char* label, ui_event event, int default_button) {
  a_hot_spot* button = &form->buttons[form->button_count++];
  button->str = (char*)label;
  button->event = event;
  button->row = row;
  button->startcol = col;
  button->length = width;
  button->flags = default_button ? HOT_DEFAULT : 0;
  AddField(form, row, col, 2, width, FLD_HOT, button);
}

void AddRadio(Form* form, unsigned row, const char* label,
              a_radio_group* group, unsigned value) {
  a_radio* radio = &form->radios[form->radio_count++];
  radio->str = (char*)label;
  radio->group = group;
  radio->value = value;
  AddField(form, row, 2, 1, 55, FLD_RADIO, radio);
}

void AddCheck(Form* form, unsigned row, const char* label, int checked) {
  a_check* check = &form->checks[form->check_count++];
  check->str = (char*)label;
  check->val = checked != 0;
  AddField(form, row, 2, 1, 55, FLD_CHECK, check);
}

void AddDialogButtons(Form* form, unsigned row) {
  AddButton(form, row, 10, 16, LocalizedText("&OK", "确定 (&O)"), kCmdAccept,
            1);
  AddButton(form, row, 32, 16, LocalizedText("&Cancel", "取消 (&C)"),
            kCmdCancel, 0);
}

ui_event RunForm(Form* form, const char* title, unsigned rows,
                 unsigned cols, int home) {
  char padded_title[128];
  static ui_event events[] = {kCmdProbe, kCmdExit, __rend__, EV_ESCAPE,
                              EV_ALT_X,  EV_F2,    EV_F3,    __end__};
  if (machine.loaded && chinese) {
    /* Separate raw GB2312 from CP437 frame bytes at both title edges. */
    snprintf(padded_title, sizeof(padded_title), " %s ", title);
    title = padded_title;
  }
  a_dialog* dialog = uibegdialog(title, form->fields, rows, cols, 0, 0);
  if (!dialog) {
    return kCmdCancel;
  }
  uipushlist(events);
  ui_event event;
  do {
    event = uidialog(dialog);
    if (home && event == EV_F2) {
      event = kCmdProbe;
    } else if (home && event == EV_F3) {
      event = kCmdPreview;
    } else if (event == EV_ESCAPE || event == EV_ALT_X) {
      event = home ? kCmdExit : kCmdCancel;
    }
  } while (event < kCmdProbe || event > kCmdExit);
  uipoplist();
  uienddialog(dialog);
  return event;
}

void ShowMessage(const char* text) {
  Form form;
  memset(&form, 0, sizeof(form));
  AddParagraph(&form, 1, 2, 68, text);
  unsigned rows = form.field_count + 4;
  AddButton(&form, rows - 2, 27, 16, LocalizedText("&OK", "确定 (&O)"),
            kCmdAccept, 1);
  RunForm(&form, LocalizedText("HHBIOS Setup", "HHBIOS 安装设置"), rows, 72, 0);
}

static ui_event ShowHome(void) {
  Form form;
  memset(&form, 0, sizeof(form));
  char text[1800];
  char display[96];
  DescribeDisplay(display, &choices);
  const char* issue = PrepareConfiguration();
  sprintf(
      text,
      LocalizedText(
          "Directory: %s\n\n"
          "DOS %u.%u    CPU: %u    Conventional: %u KiB\n"
          "XMS free: %u KiB    EMS free: %u pages    Largest UMB: %u KiB\n\n"
          "Font storage: %s\nResident code: %s\nDisplay: %s\n"
          "Input tables: PY=%s  SW=%s  DB=%s  Wubi=%s\nPair-aware editing: "
          "%s",
          "安装目录：%s\n\n"
          "DOS %u.%u    CPU：%u    常规内存：%u KiB\n"
          "XMS 空闲：%u KiB    EMS 空闲：%u 页    最大 UMB：%u KiB\n\n"
          "字库存放：%s\n程序驻留：%s\n显示驱动：%s\n"
          "输入码表：拼音=%s  首尾=%s  电报=%s  五笔=%s\n整字编辑：%s"),
      directory, machine.dos_major, machine.dos_minor, machine.cpu,
      machine.conventional_kb, machine.xms_total, machine.ems_pages,
      machine.umb_kb, kFontNames[choices.font],
      choices.low ? LocalizedText("Conventional only", "仅常规内存")
                  : LocalizedText("Prefer UMB, fall back to conventional",
                                  "优先 UMB，不足时用常规内存"),
      display, choices.ime & 1 ? "Y" : "N", choices.ime & 2 ? "Y" : "N",
      choices.ime & 4 ? "Y" : "N", choices.ime & 8 ? "Y" : "N",
      choices.paired ? "Y" : "N");

  AddParagraph(&form, 1, 2, 70, text);
  if (issue) {
    AddParagraph(
        &form, 12, 2, 70,
        LocalizedText("Configuration incomplete. Open Preview for details.",
                      "配置不完整，请打开预览查看。"));
  }
  AddButton(&form, 14, 2, 16, LocalizedText("&Memory", "内存 (&M)"), kCmdMemory,
            0);
  AddButton(&form, 14, 20, 16, LocalizedText("&Video", "显示 (&V)"), kCmdVideo,
            0);
  AddButton(&form, 14, 38, 16, LocalizedText("&Input", "输入法 (&I)"),
            kCmdInput, 0);
  AddButton(&form, 14, 56, 16, LocalizedText("&Language", "语言 (&L)"),
            kCmdLanguage, 0);
  AddButton(&form, 16, 2, 22, LocalizedText("&Keyboard", "键盘 (&K)"),
            kCmdKeyboard, 0);
  AddButton(&form, 16, 26, 25,
            LocalizedText("&Display options", "显示参数 (&D)"),
            kCmdDisplayOptions, 0);
  AddButton(&form, 16, 54, 18,
            LocalizedText("&Add-ons", "可选模块 (&A)"), kCmdModules, 0);
  AddButton(&form, 18, 2, 22, LocalizedText("&Hardware / F2", "检测结果 (&H)"),
            kCmdProbe, 0);
  AddButton(&form, 18, 26, 25,
            LocalizedText("&Preview / F3", "预览与保存 (&P)"), kCmdPreview, 1);
  AddButton(&form, 18, 54, 18, LocalizedText("E&xit", "退出 (&X)"), kCmdExit,
            0);
  return RunForm(&form, LocalizedText("HHBIOS Setup", "HHBIOS 安装设置"), 21,
                 74, 1);
}

static void ShowMemoryDialog(void) {
  Form form;
  memset(&form, 0, sizeof(form));
  a_radio_group font = {0};
  a_radio_group low = {0};
  font.value = font.def = choices.font;
  low.value = low.def = choices.low;
  AddParagraph(&form, 1, 2, 55,
               LocalizedText("Font storage:", "字库存放位置："));
  AddRadio(&form, 3, "&XMS - READ5.COM", &font, kFontXms);
  AddRadio(&form, 4, "&EMS 4.0 - READ4.COM", &font, kFontEms);
  AddRadio(
      &form, 5,
      LocalizedText("&Conventional - READ2.COM", "常规内存 - READ2.COM (&C)"),
      &font, kFontLow);
  AddParagraph(&form, 7, 2, 55, LocalizedText("Resident code:", "常驻程序："));
  AddRadio(&form, 8, LocalizedText("Prefer &UMB", "优先使用 UMB (&U)"), &low,
           0);
  AddRadio(&form, 9,
           LocalizedText("Conventional o&nly (/N)", "仅使用常规内存 (/N)"),
           &low, 1);
  AddDialogButtons(&form, 12);
  if (RunForm(&form, LocalizedText("Memory", "内存配置"), 14, 60, 0) ==
      kCmdAccept) {
    choices.font = font.value;
    choices.low = low.value;
  }
}

static void ShowVideoDialog(void) {
  Form form;
  memset(&form, 0, sizeof(form));
  a_list video = {0};
  a_radio_group rows = {0};
  char monitor[96];
  char labels[kMaxDisplayModes][64];
  const char* items[kMaxDisplayModes + 5];
  unsigned count = 1;
  unsigned mode_number = SelectedVbeMode(&choices);
  items[0] = kVideoNames[kVideoVga];
  for (unsigned i = 0; i < machine.display_count; ++i) {
    const DisplayMode* mode = &machine.display_modes[i];
    sprintf(labels[i], "VESA %ux%u (%03Xh)%s", mode->width, mode->height,
            mode->number,
            machine.edid_status == kEdidPreferred &&
                    mode->width == machine.preferred_width &&
                    mode->height == machine.preferred_height
                ? LocalizedText(" - screen preferred", " - 屏幕首选")
                : "");
    items[count] = labels[i];
    if (mode_number == mode->number) {
      video.choice = count;
    }
    ++count;
  }
  for (unsigned i = kVideoEga; i <= kVideoCga; ++i) {
    if (choices.video == i) {
      video.choice = count;
    }
    items[count++] = kVideoNames[i];
  }
  items[count] = NULL;
  video.data = items;
  rows.value = rows.def = choices.rows ? choices.rows : 25;
  DescribeMonitor(monitor);
  AddParagraph(&form, 1, 2, 64, monitor);
  AddField(&form, 3, 2, 8, 62, FLD_LISTBOX, &video);
  AddParagraph(&form, 12, 2, 60,
               LocalizedText("Text layout (font selected automatically):",
                             "文本布局（自动选择合适字号）："));
  AddRadio(&form, 13, "80x25", &rows, 25);
  AddRadio(&form, 14, "80x43", &rows, 43);
  AddRadio(&form, 15, "80x50", &rows, 50);
  AddDialogButtons(&form, 17);
  if (RunForm(&form, LocalizedText("Display", "显示设置"), 19, 68, 0) ==
      kCmdAccept) {
    SetupChoices trial = choices;
    trial.rows = rows.value;
    trial.mode = 0;
    if (!video.choice) {
      trial.video = kVideoVga;
    } else if (video.choice <= machine.display_count) {
      trial.video = kVideoDetected;
      trial.mode = machine.display_modes[video.choice - 1].number;
    } else {
      trial.video = kVideoEga + video.choice - machine.display_count - 1;
    }
    choices = trial;
  }
}

static void ShowInputDialog(void) {
  Form form;
  memset(&form, 0, sizeof(form));
  AddCheck(
      &form, 2,
      LocalizedText("&Pinyin / Shuangpin (PYMB)", "拼音／双拼 (PYMB) (&P)"),
      choices.ime & 1);
  AddCheck(&form, 3, LocalizedText("&Shouwei (SWMB)", "首尾码 (SWMB) (&S)"),
           choices.ime & 2);
  AddCheck(&form, 4, LocalizedText("&Telegraph (DBMB)", "电报码 (DBMB) (&T)"),
           choices.ime & 4);
  AddCheck(&form, 5, LocalizedText("&Wubi (WBX.COM)", "五笔 (WBX.COM) (&W)"),
           choices.ime & 8);
  AddCheck(&form, 8,
           LocalizedText("Whole-character &editing (/E)", "中文整字编辑 (/E)"),
           choices.paired);
  AddDialogButtons(&form, 10);
  if (RunForm(&form, LocalizedText("Input methods", "输入法配置"), 12, 60, 0) ==
      kCmdAccept) {
    choices.ime = 0;
    for (unsigned i = 0; i < 4; ++i) {
      if (form.checks[i].val) {
        choices.ime |= 1U << i;
      }
    }
    choices.paired = form.checks[4].val;
    SetIniInputMethods(&settings, choices.ime);
  }
}

static void ShowCapabilities(void) {
  Form form;
  memset(&form, 0, sizeof(form));
  char text[1600];
  char monitor[96];
  DescribeMonitor(monitor);
  sprintf(
      text,
      LocalizedText(
          "DOS %u.%u    CPU %u\n"
          "Conventional: %u KiB\nLargest block after SETUP exit: about %u "
          "KiB\nLargest free DOS UMB: %u KiB\n\n"
          "XMS version %X: largest %u KiB, total %u KiB\nEMS version %X: %u "
          "free pages, frame %04X\n"
          "DPMI: %s\nVBE version: %X\n"
          "%s\nCompatible VBE modes: %u%s",
          "DOS %u.%u    CPU %u\n"
          "常规内存：%u KiB\n安装程序退出后最大空闲块：约 %u KiB\n最大空闲 "
          "DOS UMB：%u KiB\n\n"
          "XMS 版本 %X：最大块 %u KiB，合计 %u KiB\nEMS 版本 %X：空闲 %u "
          "页，页框 %04X\n"
          "DPMI：%s\nVBE 版本：%X\n"
          "%s\n可用 VBE 模式：%u%s"),
      machine.dos_major, machine.dos_minor, machine.cpu,
      machine.conventional_kb, machine.free_kb, machine.umb_kb,
      machine.xms_version, machine.xms_largest, machine.xms_total,
      machine.ems_version, machine.ems_pages, machine.ems_frame,
      machine.dpmi ? "Y" : "N", machine.vbe_version, monitor,
      machine.display_count, machine.display_truncated ? "+" : "");

  AddParagraph(&form, 1, 2, 62, text);
  AddButton(&form, 14, 23, 18, LocalizedText("&OK", "确定 (&O)"), kCmdAccept,
            1);
  RunForm(&form, LocalizedText("Detected capabilities", "机器能力检测"), 16, 66,
          0);
}

static void ShowPreview(void) {
  Form form;
  memset(&form, 0, sizeof(form));
  char text[kBatchSize];
  const char* lines[128];
  unsigned count = 0;
  a_list list = {0};
  const char* error = PrepareConfiguration();
  if (error) {
    ShowMessage(error);
    return;
  }
  strcpy(text, batch);
  char* line = text;
  while (*line && count < 127) {
    lines[count++] = line;
    char* end = strchr(line, '\n');
    if (!end) {
      break;
    }
    if (end > line && end[-1] == '\r') {
      end[-1] = 0;
    }
    *end = 0;
    line = end + 1;
  }
  lines[count] = NULL;
  list.data = lines;
  AddField(&form, 1, 2, 14, 68, FLD_LISTBOX, &list);
  AddParagraph(&form, 16, 2, 70,
               LocalizedText("Save: HHBIOS.BAT, 213L.INI\n"
                             "Backup: HHBIOS.BAK, 213L.BAK",
                             "保存文件：HHBIOS.BAT、213L.INI\n"
                             "备份文件：HHBIOS.BAK、213L.BAK"));
  AddButton(&form, 19, 10, 24,
            LocalizedText("&Save both files", "保存两个文件 (&S)"), kCmdAccept,
            0);
  AddButton(&form, 19, 42, 22, LocalizedText("&Cancel", "取消 (&C)"),
            kCmdCancel, 1);
  if (RunForm(&form, LocalizedText("Preview HHBIOS.BAT", "预览 HHBIOS.BAT"), 21,
              74, 0) == kCmdAccept) {
    error = SaveConfigurationFiles(batch, ini);
    ShowMessage(
        error ? error
              : machine.loaded
                    ? LocalizedText("Saved. Restart DOS before running HHBIOS.BAT.",
                                    "已保存。重新启动 DOS 后运行 HHBIOS.BAT。")
                    : LocalizedText("Saved. Run HHBIOS.BAT after exiting SETUP.",
                                    "已保存。退出后运行 HHBIOS.BAT。"));
  }
}

/* The DOS keyboard backend returns ASCII Escape; normalize it to UI's
 * event value before the dialog's event filters consume it. */
ui_event uieventsourcehook(ui_event event) {
  return event == 27 ? EV_ESCAPE : event;
}

static void RunApplication(void) {
  for (;;) {
    switch (ShowHome()) {
      case kCmdMemory:
        ShowMemoryDialog();
        break;
      case kCmdVideo:
        ShowVideoDialog();
        break;
      case kCmdInput:
        ShowInputDialog();
        break;
      case kCmdKeyboard:
        ShowKeyboardOptions(&settings);
        break;
      case kCmdDisplayOptions:
        ShowDisplayOptions(&settings);
        break;
      case kCmdModules:
        ShowModuleOptions(&choices);
        break;
      case kCmdProbe:
        ShowCapabilities();
        break;
      case kCmdPreview:
        ShowPreview();
        break;
      case kCmdLanguage:
        if (IsScreenActive() || machine.loaded) {
          chinese = !chinese;
        } else {
          ShowMessage(
              "Chinese setup requires VGA. Start SETUP /ZH on a VGA adapter.");
        }
        break;
      default:
        return;
    }
  }
}

static int SelectVideoOption(const char* value) {
  static const char* const names[] = {"VGA", "102", "104", "106",
                                      "EGA", "HGA", "CGA"};
  unsigned i;
  unsigned width = 0, height = 0;
  char separator, extra, *end;
  unsigned long number;
  for (i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
    if (!stricmp(value, names[i])) {
      choices.video = i;
      choices.mode = 0;
      return 1;
    }
  }
  if (!stricmp(value, "NATIVE")) {
    if (machine.edid_status != kEdidPreferred) {
      return 0;
    }
    width = machine.preferred_width;
    height = machine.preferred_height;
  } else if (sscanf(value, "%u%c%u%c", &width, &separator, &height, &extra) !=
                 3 ||
             (separator != 'x' && separator != 'X')) {
    number = strtoul(value, &end, 16);
    if (end == value || *end || number < 0x100 || number > 0x3fff ||
        !FindDisplayMode(&machine, (unsigned)number)) {
      return 0;
    }
    choices.video = kVideoDetected;
    choices.mode = (unsigned)number;
    return 1;
  }
  for (i = 0; i < machine.display_count; ++i) {
    if (machine.display_modes[i].width == width &&
        machine.display_modes[i].height == height) {
      choices.video = kVideoDetected;
      choices.mode = machine.display_modes[i].number;
      return 1;
    }
  }
  return 0;
}

int main(int argc, char** argv) {
  int i;
  int automatic = 0;
  int report = 0;
  int language = -1;
  int ime_seen = 0;
  int text_seen = 0;
  int current_directory = 0;
  char path[80], *slash;
  for (i = 1; i < argc; ++i) {
    if (!stricmp(argv[i], "/W")) {
      current_directory = 1;
    }
  }
  /* Keep the executable and all modules together; never embed a host path. */
  if (!current_directory && strlen(argv[0]) < sizeof(path)) {
    strcpy(path, argv[0]);
    slash = strrchr(path, '\\');
    if (slash) {
      if (slash == path + 2) {
        slash[1] = 0;
      } else {
        *slash = 0;
      }
      if (chdir(path)) {
        puts("Cannot enter installation directory.");
        return 1;
      }
      if (path[1] == ':') {
        unsigned drive = toupper(path[0]) - 'A' + 1;
        unsigned drive_count, current_drive;
        _dos_setdrive(drive, &drive_count);
        _dos_getdrive(&current_drive);
        if (current_drive != drive) {
          puts("Cannot select installation drive.");
          return 1;
        }
      }
    }
  }
  if (!getcwd(directory, sizeof(directory))) {
    puts("Cannot read installation directory.");
    return 1;
  }
  ProbeMachine(&machine);
  ScanFiles(&files);
  RecommendConfiguration(&machine, &files, &choices);
  LoadConfiguration();
  for (i = 1; i < argc; ++i) {
    if (!stricmp(argv[i], "/AUTO")) {
      automatic = 1;
    } else if (!stricmp(argv[i], "/W")) {
      /* The directory was selected before inspecting files or hardware. */
    } else if (!stricmp(argv[i], "/REPORT")) {
      report = 1;
    } else if (!stricmp(argv[i], "/EN")) {
      language = 0;
    } else if (!stricmp(argv[i], "/ZH")) {
      language = 1;
    } else if (!stricmp(argv[i], "/LOW")) {
      choices.low = 1;
    } else if (!stricmp(argv[i], "/BYTE")) {
      choices.paired = 0;
    } else if (!stricmp(argv[i], "/FONT:XMS")) {
      choices.font = kFontXms;
    } else if (!stricmp(argv[i], "/FONT:EMS")) {
      choices.font = kFontEms;
    } else if (!stricmp(argv[i], "/FONT:LOW")) {
      choices.font = kFontLow;
    } else if (!strnicmp(argv[i], "/VIDEO:", 7)) {
      if (!SelectVideoOption(argv[i] + 7)) {
        puts("No compatible BIOS mode for this /VIDEO choice.");
        return 1;
      }
    } else if (!strnicmp(argv[i], "/TEXT:", 6)) {
      const char* value = argv[i] + 6;
      choices.rows = !stricmp(value, "80x25")   ? 25
                     : !stricmp(value, "80x43") ? 43
                     : !stricmp(value, "80x50") ? 50
                                                : 0;
      if (!choices.rows) {
        puts("Use /TEXT:80x25, /TEXT:80x43 or /TEXT:80x50.");
        return 1;
      }
      text_seen = 1;
    } else if (!strnicmp(argv[i], "/IME:", 5)) {
      if (!ime_seen++) {
        choices.ime = 0;
      }
      if (!stricmp(argv[i] + 5, "PY")) {
        choices.ime |= 1;
      } else if (!stricmp(argv[i] + 5, "SW")) {
        choices.ime |= 2;
      } else if (!stricmp(argv[i] + 5, "DB")) {
        choices.ime |= 4;
      } else if (!stricmp(argv[i] + 5, "WB")) {
        choices.ime |= 8;
      } else if (stricmp(argv[i] + 5, "NONE")) {
        puts("Unknown /IME choice.");
        return 1;
      }
    } else {
      puts(
          "SETUP [/EN|/ZH] [/REPORT|/AUTO] [/W] [/LOW] [/BYTE]\n"
          "      [/FONT:XMS|EMS|LOW] [/VIDEO:VGA|102|104|106|EGA|HGA|CGA]\n"
          "      [/VIDEO:NATIVE|WIDTHxHEIGHT|hex] [/TEXT:80x25|80x43|80x50]\n"
          "      [/IME:NONE|PY|SW|DB|WB] (repeat /IME to combine)\n"
          "/W uses the current directory; otherwise use SETUP's directory.\n"
          "/REPORT queries only; /AUTO explicitly saves without a dialog.");
      return !stricmp(argv[i], "/?") ? 0 : 1;
    }
  }
  if (report) {
    ReportMachine(stdout, &machine, &files);
    return 0;
  }
  if (machine.loaded && argc == 2 && text_seen) {
    int ok = SwitchTextRows(choices.rows);
    puts(ok ? "Text layout selected."
            : "Cannot select this text layout in the current VESA console.");
    return ok ? 0 : 1;
  }
  if (ime_seen) {
    SetIniInputMethods(&settings, choices.ime);
  }
  if (automatic) {
    const char* error = PrepareConfiguration();
    if (!error) {
      error = SaveConfigurationFiles(batch, ini);
    }
    puts(error ? error : "Saved HHBIOS.BAT and 213L.INI.");
    return error ? 1 : 0;
  }
  ConfigureScreen(!machine.loaded && language != 0 && machine.adapter == kAdapterVga);
  ConfigureResidentText(machine.loaded != 0);
  if (!uiinit(INIT_MOUSE_INITIALIZED)) {
    puts("Cannot initialize the DOS user interface.");
    return 1;
  }
  chinese = IsScreenActive() || (machine.loaded && language == 1);
  if (language == 1 && !chinese) {
    uifini();
    puts(
        "Chinese setup needs VGA, HZK16 and free conventional memory. Use "
        "SETUP /EN.");
    return 1;
  }
  RunApplication();
  uifini();
  StopScreen();
  return 0;
}

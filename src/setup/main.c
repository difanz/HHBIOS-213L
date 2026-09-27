/* Open Watcom UI owns dialogs, focus, keyboard and mouse dispatch. */
#include <ctype.h>
#include <direct.h>
#include <dos.h>
#include <io.h>
#include <stdlib.h>
#include <string.h>

#include "screen.h"
#include "setup.h"
#include "stdui.h"
#include "uidialog.h"

static MachineCapabilities machine;
static InstallationFiles files;
static SetupChoices choices;
static char directory[80];
static char batch[kBatchSize];
static char ini[kIniSize];
static char original[kIniSize];
static int chinese = 0;
static int ini_ok = 1;
static const char* LocalizedText(const char* en, const char* zh) {
  return chinese ? EncodeScreenText(zh) : en;
}

enum {
  kCmdProbe = EV_FIRST_UNUSED,
  kCmdMemory,
  kCmdVideo,
  kCmdInput,
  kCmdPreview,
  kCmdLanguage,
  kCmdAccept,
  kCmdCancel,
  kCmdExit
};

/* Each dialog owns its controls and text until uienddialog releases it. */
typedef struct {
  VFIELD fields[48];
  a_hot_spot buttons[8];
  a_radio radios[10];
  a_check checks[5];
  unsigned field_count;
  unsigned button_count;
  unsigned radio_count;
  unsigned check_count;
  unsigned text_used;
  char text[4096];
} Form;

static int LoadIni() {
  FILE* file = fopen("213L.INI", "rb");
  unsigned byte_count;
  original[0] = 0;
  if (!file) {
    return access("213L.INI", 0) != 0;
  }
  byte_count = fread(original, 1, sizeof(original) - 1, file);
  int ok = !ferror(file) && feof(file);
  fclose(file);
  original[byte_count] = 0;
  return ok && !memchr(original, 0, byte_count) &&
         MakeIni(original, &choices, ini);
}

static const char* PrepareConfiguration() {
  const char* error;
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
  if (!ini_ok || !MakeIni(original, &choices, ini)) {
    return LocalizedText(
        "213L.INI is malformed or too large. Keep a copy and repair it first.",
        "213L.INI 格式有误或过大，请先备份并修复原配置。");
  }
  return 0;
}

static void AddField(Form* form, unsigned row, unsigned col, unsigned height,
                     unsigned width, a_field_type type, void* data) {
  VFIELD* field = &form->fields[form->field_count++];
  field->area.row = row;
  field->area.col = col;
  field->area.height = height;
  field->area.width = width;
  field->typ = type;
  field->u.ptr = data;
}

static void AddParagraph(Form* form, unsigned row, unsigned col, unsigned width,
                         const char* text) {
  while (*text) {
    unsigned length = 0;
    unsigned space = 0;
    while (text[length] && text[length] != '\n') {
      unsigned count = uicharlen((unsigned char)text[length]);
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

static void AddButton(Form* form, unsigned row, unsigned col, unsigned width,
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

static void AddRadio(Form* form, unsigned row, const char* label,
                     a_radio_group* group, unsigned value) {
  a_radio* radio = &form->radios[form->radio_count++];
  radio->str = (char*)label;
  radio->group = group;
  radio->value = value;
  AddField(form, row, 2, 1, 55, FLD_RADIO, radio);
}

static void AddCheck(Form* form, unsigned row, const char* label, int checked) {
  a_check* check = &form->checks[form->check_count++];
  check->str = (char*)label;
  check->val = checked != 0;
  AddField(form, row, 2, 1, 55, FLD_CHECK, check);
}

static void AddDialogButtons(Form* form, unsigned row) {
  AddButton(form, row, 10, 16, LocalizedText("&OK", "确定 (&O)"), kCmdAccept,
            1);
  AddButton(form, row, 32, 16, LocalizedText("&Cancel", "取消 (&C)"),
            kCmdCancel, 0);
}

static ui_event RunForm(Form* form, const char* title, unsigned rows,
                        unsigned cols, int home) {
  static ui_event events[] = {kCmdProbe, kCmdExit, __rend__, EV_ESCAPE,
                              EV_ALT_X,  EV_F2,    EV_F3,    __end__};
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

static void ShowMessage(const char* text) {
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
      kVideoNames[choices.video], choices.ime & 1 ? "Y" : "N",
      choices.ime & 2 ? "Y" : "N", choices.ime & 4 ? "Y" : "N",
      choices.ime & 8 ? "Y" : "N", choices.paired ? "Y" : "N");

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
  AddButton(&form, 16, 2, 22, LocalizedText("&Hardware / F2", "检测结果 (&H)"),
            kCmdProbe, 0);
  AddButton(&form, 16, 26, 25,
            LocalizedText("&Preview / F3", "预览与保存 (&P)"), kCmdPreview, 1);
  AddButton(&form, 16, 54, 18, LocalizedText("E&xit", "退出 (&X)"), kCmdExit,
            0);
  return RunForm(&form, LocalizedText("HHBIOS Setup", "HHBIOS 安装设置"), 19,
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
  a_radio_group video = {0};
  video.value = video.def = choices.video;
  for (unsigned i = 0; i < kVideoCount; ++i) {
    AddRadio(&form, i + 2, kVideoNames[i], &video, i);
  }
  AddDialogButtons(&form, 10);
  if (RunForm(&form, LocalizedText("Display driver", "显示驱动"), 12, 60, 0) ==
      kCmdAccept) {
    choices.video = video.value;
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
  }
}

static void ShowCapabilities(void) {
  Form form;
  memset(&form, 0, sizeof(form));
  char text[1600];
  sprintf(
      text,
      LocalizedText(
          "DOS %u.%u    CPU %u\n"
          "Conventional: %u KiB\nLargest block after SETUP exit: about %u "
          "KiB\nLargest free DOS UMB: %u KiB\n\n"
          "XMS version %X: largest %u KiB, total %u KiB\nEMS version %X: %u "
          "free pages, frame %04X\n"
          "DPMI: %s\nVBE version: %X\n"
          "Planar modes: 102=%s 104=%s 106=%s",
          "DOS %u.%u    CPU %u\n"
          "常规内存：%u KiB\n安装程序退出后最大空闲块：约 %u KiB\n最大空闲 "
          "DOS UMB：%u KiB\n\n"
          "XMS 版本 %X：最大块 %u KiB，合计 %u KiB\nEMS 版本 %X：空闲 %u "
          "页，页框 %04X\n"
          "DPMI：%s\nVBE 版本：%X\n"
          "平面模式：102=%s 104=%s 106=%s"),
      machine.dos_major, machine.dos_minor, machine.cpu,
      machine.conventional_kb, machine.free_kb, machine.umb_kb,
      machine.xms_version, machine.xms_largest, machine.xms_total,
      machine.ems_version, machine.ems_pages, machine.ems_frame,
      machine.dpmi ? "Y" : "N", machine.vbe_version,
      machine.modes & 1 ? "Y" : "N", machine.modes & 2 ? "Y" : "N",
      machine.modes & 4 ? "Y" : "N");

  AddParagraph(&form, 1, 2, 62, text);
  AddButton(&form, 12, 23, 18, LocalizedText("&OK", "确定 (&O)"), kCmdAccept,
            1);
  RunForm(&form, LocalizedText("Detected capabilities", "机器能力检测"), 14, 66,
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
      case kCmdProbe:
        ShowCapabilities();
        break;
      case kCmdPreview:
        ShowPreview();
        break;
      case kCmdLanguage:
        if (IsScreenActive()) {
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

int main(int argc, char** argv) {
  int i;
  int automatic = 0;
  int report = 0;
  int language = -1;
  int ime_seen = 0;
  char path[80], *slash;
  /* Keep the executable and all modules together; never embed a host path. */
  if (strlen(argv[0]) < sizeof(path)) {
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
  for (i = 1; i < argc; ++i) {
    if (!stricmp(argv[i], "/AUTO")) {
      automatic = 1;
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
      const char* names[] = {"VGA", "102", "104", "106", "EGA", "HGA", "CGA"};
      unsigned v;
      for (v = 0; v < kVideoCount; ++v) {
        if (!stricmp(argv[i] + 7, names[v])) {
          break;
        }
      }
      if (v == kVideoCount) {
        puts("Unknown /VIDEO choice.");
        return 1;
      }
      choices.video = v;
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
          "SETUP [/EN|/ZH] [/REPORT|/AUTO] [/LOW] [/BYTE]\n"
          "      [/FONT:XMS|EMS|LOW] [/VIDEO:VGA|102|104|106|EGA|HGA|CGA]\n"
          "      [/IME:NONE|PY|SW|DB|WB] (repeat /IME to combine)\n"
          "/REPORT queries only; /AUTO explicitly saves without a dialog.");
      return !stricmp(argv[i], "/?") ? 0 : 1;
    }
  }
  if (report) {
    ReportMachine(stdout, &machine, &files);
    return 0;
  }
  ini_ok = LoadIni();
  if (automatic) {
    const char* error = PrepareConfiguration();
    if (!error) {
      error = SaveConfigurationFiles(batch, ini);
    }
    puts(error ? error : "Saved HHBIOS.BAT and 213L.INI.");
    return error ? 1 : 0;
  }
  if (machine.loaded) {
    puts("Start SETUP from a clean DOS session before loading HHBIOS.");
    return 1;
  }
  ConfigureScreen(language != 0 && machine.adapter == kAdapterVga);
  if (!uiinit(INIT_MOUSE_INITIALIZED)) {
    puts("Cannot initialize the DOS user interface.");
    return 1;
  }
  chinese = IsScreenActive();
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

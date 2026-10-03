/* Persistent keyboard, display and module choices from the 2.13L format. */
#include <string.h>
#include <stdlib.h>
#include <conio.h>
#include <dos.h>

#include "forms.h"

static const char* FunctionName(unsigned function) {
  static const char* const english[kFunctionKeyCount] = {
      "Chinese / native display", "GB2312 code input", "Shouwei input",
      "Pinyin input", "Shuangpin input", "Full-width input", "English input",
      "Wubi input", "Telegraph input", "Character selection", "Help",
      "System menu", "Define Shuangpin phrase", "Printer settings"};
  static const char* const chinese[kFunctionKeyCount] = {
      "中西文显示切换", "区位码输入", "首尾码输入", "拼音输入", "双拼输入",
      "纯中文输入", "英文输入", "五笔字型输入", "电报码输入", "预选字输入",
      "联机帮助", "系统控制菜单", "定义双拼词组", "打印参数"};
  return LocalizedText(english[function], chinese[function]);
}

static void ChangeBinding(IniSettings* settings, unsigned function) {
  if (settings->value[kIniGreatWall] == 'Y' && function >= 1 && function <= 6) {
    ShowMessage(LocalizedText("Turn off Great Wall keyboard to change this key.",
                               "请先关闭仿长城键盘，再修改此功能键。"));
    return;
  }
  Form form = {0};
  a_list list = {0};
  /* Only one binding chooser is open. Keep its bounded byte-code catalog
   * outside the 8086 stack shared with the two parent dialogs. */
  static char labels[256][32];
  static const char* items[257];
  static unsigned codes[256];
  unsigned count = 0;
  for (unsigned key = 0; key < 256; ++key) {
    if (!IsFunctionKey(key)) {
      continue;
    }
    DescribeFunctionKey(key, labels[count]);
    codes[count] = key;
    items[count] = labels[count];
    if (settings->value[kIniKeys + function] == key) {
      list.choice = count;
    }
    ++count;
  }
  items[count] = NULL;
  list.data = items;
  AddField(&form, 1, 2, 12, 50, FLD_LISTBOX, &list);
  AddDialogButtons(&form, 15);
  if (RunForm(&form, FunctionName(function), 17, 56, 0) == kCmdAccept &&
      !AssignFunctionKey(settings, function, codes[list.choice])) {
    ShowMessage(LocalizedText("This key is assigned to another function.",
                               "此键已分配给其他功能。"));
  }
}

static void ShowBindings(IniSettings* settings) {
  IniSettings trial = *settings;
  unsigned selected = 0;
  for (;;) {
    Form form = {0};
    a_list list = {0};
    char labels[kFunctionKeyCount][76];
    const char* items[kFunctionKeyCount + 1];
    for (unsigned i = 0; i < kFunctionKeyCount; ++i) {
      char key[32];
      DescribeFunctionKey(trial.value[kIniKeys + i], key);
      sprintf(labels[i], "%-12s %s", key, FunctionName(i));
      items[i] = labels[i];
    }
    items[kFunctionKeyCount] = NULL;
    list.data = items;
    list.choice = selected;
    AddField(&form, 1, 2, 14, 66, FLD_LISTBOX, &list);
    AddButton(&form, 16, 24, 22, LocalizedText("&Edit", "修改 (&E)"),
              kCmdChange, 0);
    AddDialogButtons(&form, 19);
    ui_event event = RunForm(&form, LocalizedText("Function keys", "功能键配置"),
                             21, 70, 0);
    if (event == kCmdAccept) {
      *settings = trial;
      return;
    }
    if (event != kCmdChange) {
      return;
    }
    selected = list.choice;
    ChangeBinding(&trial, selected);
  }
}

void ShowKeyboardOptions(IniSettings* settings) {
  IniSettings trial = *settings;
  for (;;) {
    Form form = {0};
    a_list phrases = {0};
    a_radio_group toggle = {0};
    static const char* const sizes[] = {
        "0 KiB", "1 KiB", "2 KiB", "3 KiB", "4 KiB", "5 KiB",
        "6 KiB", "7 KiB", "8 KiB", "9 KiB", NULL};
    int great_wall = trial.value[kIniGreatWall] == 'Y';
    phrases.data = (void*)sizes;
    phrases.choice = trial.value[kIniPhraseKb] >= '0' &&
                              trial.value[kIniPhraseKb] <= '9'
                          ? trial.value[kIniPhraseKb] - '0' : 0;
    toggle.value = toggle.def = trial.value[kIniShift];
    AddCheck(&form, 1, LocalizedText("&Great Wall keyboard", "仿长城键盘 (&G)"),
              great_wall);
    AddParagraph(&form, 3, 2, 55,
                 LocalizedText("Shuangpin phrase space (0 disables):",
                               "双拼词组扩展区（0 为不安装）："));
    AddField(&form, 5, 2, 3, 22, FLD_LISTBOX, &phrases);
    AddParagraph(&form, 9, 2, 55,
                 LocalizedText("Keyboard enable / disable key:", "系统功能开关键："));
    AddRadio(&form, 10, LocalizedText("&Right Shift", "右 Shift (&R)"), &toggle, 1);
    AddRadio(&form, 11, LocalizedText("&Left Shift", "左 Shift (&L)"), &toggle, 2);
    AddRadio(&form, 12, "&Scroll Lock", &toggle, 16);
    AddButton(&form, 14, 17, 26,
              LocalizedText("&Function keys", "功能键配置 (&F)"), kCmdBindings, 0);
    AddDialogButtons(&form, 17);
    ui_event event = RunForm(&form, LocalizedText("Keyboard", "键盘设置"),
                             19, 60, 0);
    if (event != kCmdAccept && event != kCmdBindings) {
      return;
    }
    if (great_wall != !!form.checks[0].val &&
        !SetGreatWallMode(&trial, form.checks[0].val != 0)) {
      ShowMessage(LocalizedText("The keyboard mapping conflicts with a function key.",
                                 "键盘布局与现有功能键冲突。"));
      continue;
    }
    trial.value[kIniShift] = (unsigned char)toggle.value;
    trial.value[kIniPhraseKb] = (unsigned char)('0' + phrases.choice);
    if (event == kCmdAccept) {
      *settings = trial;
      return;
    }
    ShowBindings(&trial);
  }
}

static const char* ColorName(unsigned color) {
  static const char* const english[] = {
      "Black", "Blue", "Green", "Cyan", "Red", "Magenta",
      "Brown", "Light gray", "Dark gray", "Bright blue",
      "Bright green", "Bright cyan", "Bright red", "Bright magenta",
      "Yellow", "White"};
  static const char* const chinese[] = {
      "黑", "蓝", "绿", "青", "红", "紫", "棕", "浅灰",
      "深灰", "亮蓝", "亮绿", "亮青", "亮红", "亮紫", "黄", "白"};
  return LocalizedText(english[color], chinese[color]);
}

static int HasColorDisplay(void) {
  return UIData->colour != M_MONO && UIData->colour != M_BW;
}

static void PaintColor(VSCREEN* screen, unsigned row, unsigned col,
                       unsigned width, unsigned color) {
  SAREA area;
  area.row = row;
  area.col = col;
  area.height = 1;
  area.width = width;
  /* A solid foreground glyph also shows bright colors on CGA, where the
   * background intensity bit may still mean blink. */
  uivfill(screen, area, (ATTR)color, (char)0xdb);
}

static void PaintColorPreview(a_dialog* dialog, unsigned row, unsigned col,
                              unsigned width, unsigned attribute) {
  SAREA area;
  area.row = row;
  area.col = col;
  area.height = 1;
  area.width = width;
  char names[64];
  const char* sample = LocalizedText("  HHBIOS  1. Chinese  2. Input  ",
                                     "  HHBIOS  1. 中文  2. 输入  ");
  if (!HasColorDisplay()) {
    sprintf(names, "%s / %s", ColorName(attribute & 15),
            ColorName(attribute >> 4));
    sample = names;
    attribute = UIData->attrs[ATTR_NORMAL];
  }
  uivfill(dialog->vs, area, (ATTR)attribute, ' ');
  uivtextput(dialog->vs, row, col, (ATTR)attribute, sample,
             strlen(sample) < width ? strlen(sample) : width);
}

/* In a native text screen, bit 7 must select bright paper, not blinking ink.
 * Restore the caller's setting when the color dialog closes. HHBIOS graphics
 * drivers already use all four background bits and ignore this BIOS call. */
static unsigned SetColorBlink(unsigned enabled) {
  unsigned char far* mode_control = (unsigned char far*)MK_FP(0x40, 0x65);
  unsigned previous = (*mode_control & 0x20) != 0;
  if (HasColorDisplay()) {
    if (UIData->colour == M_CGA) {
      *mode_control = (*mode_control & ~0x20) | (enabled ? 0x20 : 0);
      outp(0x3d8, *mode_control);
    } else {
      union REGS registers;
      memset(&registers, 0, sizeof(registers));
      registers.x.ax = 0x1003;
      registers.x.bx = enabled != 0;
      int86(0x10, &registers, &registers);
    }
  }
  return previous;
}

typedef struct ColorDialog {
  a_list foreground;
  a_list background;
} ColorDialog;

static void ColorChanged(a_dialog* dialog, void* data) {
  const ColorDialog* colors = (const ColorDialog*)data;
  if (HasColorDisplay()) {
    for (unsigned i = 0; i < 16; ++i) {
      PaintColor(dialog->vs, i + 2, 2, 3, i);
      PaintColor(dialog->vs, i + 2, 30, 3, i);
    }
  }
  PaintColorPreview(dialog, 19, 2, 54,
                    (colors->background.choice << 4) |
                        colors->foreground.choice);
}

static unsigned SelectColor(unsigned attribute) {
  Form form = {0};
  ColorDialog selection = {0};
  const char* colors[17];
  for (unsigned i = 0; i < 16; ++i) {
    colors[i] = ColorName(i);
  }
  colors[16] = NULL;
  selection.foreground.data = selection.background.data = colors;
  selection.foreground.choice = attribute & 15;
  selection.background.choice = attribute >> 4;
  AddParagraph(&form, 0, 2, 25, LocalizedText("Text", "文字颜色"));
  AddParagraph(&form, 0, 30, 25, LocalizedText("Background", "背景颜色"));
  AddField(&form, 2, 6, 16, 21, FLD_LISTBOX, &selection.foreground);
  AddField(&form, 2, 34, 16, 21, FLD_LISTBOX, &selection.background);
  AddDialogButtons(&form, 21);
  form.changed = ColorChanged;
  form.change_data = &selection;
  unsigned blink = SetColorBlink(0);
  ui_event event = RunForm(&form, LocalizedText("Status color", "提示行颜色"),
                           23, 60, 0);
  SetColorBlink(blink);
  if (event == kCmdAccept) {
    return (selection.background.choice << 4) | selection.foreground.choice;
  }
  return attribute;
}

typedef struct StatusColors {
  a_list list;
  const IniSettings* settings;
} StatusColors;

static void StatusColorChanged(a_dialog* dialog, void* data) {
  const StatusColors* colors = (const StatusColors*)data;
  PaintColorPreview(dialog, 6, 2, 66,
                    colors->settings->value[kIniColors + colors->list.choice]);
}

static void ShowColors(IniSettings* settings) {
  IniSettings trial = *settings;
  unsigned selected = 0;
  static const char* const english[] = {
      "Candidates: characters / phrase numbers", "Candidates: phrases / character numbers",
      "Menu selection / graphics title", "Input method title: text mode"};
  static const char* const chinese[] = {
      "候选字、词序号", "候选词、字序号", "菜单选中项、图形方式标题",
      "输入法标题（文本方式）"};
  for (;;) {
    Form form = {0};
    StatusColors colors = {0};
    const char* items[5];
    for (unsigned i = 0; i < 4; ++i) {
      items[i] = LocalizedText(english[i], chinese[i]);
    }
    items[4] = NULL;
    colors.list.data = items;
    colors.list.choice = selected;
    colors.settings = &trial;
    AddField(&form, 1, 2, 4, 66, FLD_LISTBOX, &colors.list);
    AddButton(&form, 8, 24, 22, LocalizedText("&Edit", "修改 (&E)"), kCmdChange, 0);
    AddDialogButtons(&form, 10);
    form.changed = StatusColorChanged;
    form.change_data = &colors;
    unsigned blink = SetColorBlink(0);
    ui_event event = RunForm(&form, LocalizedText("Status colors", "提示行颜色"),
                             12, 70, 0);
    SetColorBlink(blink);
    if (event == kCmdAccept) {
      *settings = trial;
      return;
    }
    if (event != kCmdChange) {
      return;
    }
    selected = colors.list.choice;
    trial.value[kIniColors + selected] =
        (unsigned char)SelectColor(trial.value[kIniColors + selected]);
  }
}

typedef struct DisplayOption {
  unsigned offset;
  unsigned mask;
  int inverted;
  const char* english;
  const char* chinese;
} DisplayOption;

void ShowDisplayOptions(IniSettings* settings) {
  static const DisplayOption options[] = {
      {kIniDisplay, 2, 0, "Keep the input status bar visible", "保持显示输入法状态栏"},
      {kIniDisplay, 8, 1, "Show startup information", "显示启动信息"},
      {kIniDisplay3, 2, 1, "Allow programs to set cursor shape", "允许程序改变光标形状"},
      {kIniDisplay, 1, 0, "Extended character font", "使用扩展字符库"},
      {kIniDisplay2, 1, 0, "Translate direct text-memory writes", "支持直接写屏"},
      {kIniDisplay3, 1, 1, "Use Chinese display for modes above 5", "显示方式大于 5 时进入中文显示"},
      {kIniDisplay2, 8, 0, "Move the cursor down two scanlines", "光标下移两条扫描线"},
      {kIniDisplay3, 8, 0, "Pass CGA palette calls to BIOS", "允许 BIOS 设置 CGA 调色板"},
      {kIniDisplay3, 4, 0, "Initialize display attributes", "初始化显示属性寄存器"},
      {kIniDisplay2, 2, 0, "Map B800 in graphics modes", "图形方式打开 B800 段"},
      {kIniDisplay2, 4, 0, "Use BIOS character drawing and scrolling", "字符显示及滚屏调用 BIOS"}};
  IniSettings trial = *settings;
  for (;;) {
    Form form = {0};
    unsigned count = sizeof(options) / sizeof(options[0]);
    AddParagraph(&form, 0, 2, 54, LocalizedText("Appearance", "外观"));
    AddParagraph(&form, 5, 2, 54, LocalizedText("Program compatibility", "程序兼容性"));
    for (unsigned i = 0; i < count; ++i) {
      const DisplayOption* option = &options[i];
      int checked = (trial.value[option->offset] & option->mask) != 0;
      AddCheck(&form, i + (i < 3 ? 1 : 3), LocalizedText(option->english, option->chinese),
                checked != option->inverted);
    }
    AddButton(&form, 15, 14, 32,
              LocalizedText("Status bar co&lors", "状态栏颜色 (&L)"),
              kCmdColors, 0);
    AddDialogButtons(&form, 18);
    ui_event event = RunForm(&form,
                             LocalizedText("Display settings", "显示设置"),
                             20, 60, 0);
    if (event != kCmdAccept && event != kCmdColors) {
      return;
    }
    for (unsigned i = 0; i < count; ++i) {
      const DisplayOption* option = &options[i];
      trial.value[option->offset] &= (unsigned char)~option->mask;
      if (!!form.checks[i].val != option->inverted) {
        trial.value[option->offset] |= (unsigned char)option->mask;
      }
    }
    if (event == kCmdAccept) {
      *settings = trial;
      return;
    }
    ShowColors(&trial);
  }
}

static void EditPrintFiles(SetupChoices* choices) {
  Form form = {0};
  an_edit_control edits[12] = {0};
  unsigned count;
  for (count = 0; count < 12; ++count) {
    const char* path = choices->print_files[count / 4][count % 4];
    edits[count].length = strlen(path);
    edits[count].buffer = malloc(edits[count].length + 1);
    if (!edits[count].buffer) {
      break;
    }
    strcpy(edits[count].buffer, path);
  }
  if (count == 12) {
    AddParagraph(&form, 1, 2, 66,
                 LocalizedText("Blank F0: default file. Blank F1-F3: use F0.",
                               "F0 留空使用默认字库；F1-F3 留空使用 F0。"));
    for (unsigned i = 0; i < 12; ++i) {
      char label[24];
      sprintf(label, "READ%u /F%u:", 24 + (i / 4) * 8, i % 4);
      AddParagraph(&form, 3 + i, 2, 18, label);
      AddField(&form, 3 + i, 20, 1, 46, FLD_EDIT, &edits[i]);
    }
    AddDialogButtons(&form, 17);
    if (RunForm(&form, LocalizedText("Printing font files", "打印字库文件"), 19,
                70, 0) == kCmdAccept) {
      SetupChoices trial = *choices;
      int valid = 1;
      for (unsigned i = 0; i < 12; ++i) {
        if (edits[i].length >= 128) {
          valid = 0;
          break;
        }
        memcpy(trial.print_files[i / 4][i % 4], edits[i].buffer,
               edits[i].length);
        trial.print_files[i / 4][i % 4][edits[i].length] = 0;
      }
      if (valid && ValidModuleChoices(&trial)) {
        *choices = trial;
      } else {
        ShowMessage(LocalizedText(
            "Use DOS paths; each loader command must fit 126 characters.",
            "请使用 DOS 路径；每条装载命令不能超过 126 字符。"));
      }
    }
  } else {
    ShowMessage(LocalizedText("Not enough memory.", "内存不足。"));
  }
  for (unsigned i = 0; i < count; ++i) {
    free(edits[i].buffer);
  }
}

void ShowModuleOptions(SetupChoices* choices) {
  SetupChoices trial = *choices;
  for (;;) {
    Form form = {0};
    a_list special = {0};
    a_list printer = {0};
    a_list access = {0};
    const char* special_items[] = {NULL, "INT10K.COM", "INT10V.COM", NULL};
    const char* printer_items[kPrinterCount + 1];
    const char* access_items[] = {NULL, "XMS", "EMS 4.0", NULL};
    special_items[0] = LocalizedText("None", "不安装");
    for (unsigned i = 0; i < kPrinterCount; ++i) {
      printer_items[i] =
          i ? kPrinters[i].name : LocalizedText("None", "不安装");
    }
    printer_items[kPrinterCount] = NULL;
    access_items[0] = LocalizedText("Automatic", "自动选择");
    special.data = special_items;
    special.choice = trial.special_display;
    printer.data = printer_items;
    printer.choice = trial.printer;
    access.data = access_items;
    access.choice = trial.print_memory;
    AddParagraph(&form, 1, 2, 30,
                 LocalizedText("Special display:", "特殊显示模块："));
    AddField(&form, 3, 2, 3, 26, FLD_LISTBOX, &special);
    AddParagraph(&form, 1, 32, 36, LocalizedText("Printer:", "打印驱动："));
    AddField(&form, 3, 32, 5, 36, FLD_LISTBOX, &printer);
    AddParagraph(&form, 9, 2, 30,
                 LocalizedText("Printing fonts:", "打印字库："));
    static const char* const fonts[] = {"READ16", "READ24", "READ32", "READ40",
                                        "READSL"};
    for (unsigned i = 0; i < 5; ++i) {
      a_check* check = &form.checks[form.check_count++];
      check->str = (char*)fonts[i];
      check->val = (trial.print_fonts & (1U << i)) != 0;
      AddField(&form, 10 + i, 2, 1, 26, FLD_CHECK, check);
    }
    a_check* vector_file = &form.checks[form.check_count++];
    vector_file->str =
        (char*)LocalizedText("READSL &DOS file access", "READSL DOS 文件读取 (&D)");
    vector_file->val = trial.vector_access != 2;
    AddField(&form, 16, 2, 1, 26, FLD_CHECK, vector_file);
    AddParagraph(&form, 9, 32, 36,
                 LocalizedText("Bitmap font storage:", "点阵字库内存："));
    AddField(&form, 11, 32, 4, 36, FLD_LISTBOX, &access);
    AddButton(&form, 16, 32, 32, LocalizedText("Font &files", "字库文件 (&F)"),
              kCmdChange, 0);
    AddDialogButtons(&form, 18);
    ui_event event = RunForm(
        &form, LocalizedText("Optional modules", "可选模块"), 20, 72, 0);
    if (event == kCmdAccept || event == kCmdChange) {
      trial.special_display = special.choice;
      trial.printer = printer.choice;
      trial.print_memory = access.choice;
      trial.vector_access = vector_file->val ? 1 : 2;
      trial.print_fonts = 0;
      for (unsigned i = 0; i < 5; ++i) {
        if (form.checks[i].val) {
          trial.print_fonts |= 1U << i;
        }
      }
    }
    if (event == kCmdAccept) {
      *choices = trial;
      return;
    }
    if (event != kCmdChange) {
      return;
    }
    EditPrintFiles(&trial);
  }
}

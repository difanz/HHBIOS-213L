#define Uses_TApplication
#define Uses_TProgram
#define Uses_TDeskTop
#define Uses_TDialog
#define Uses_TStaticText
#define Uses_TButton
#define Uses_TKeys
#define Uses_TEvent
#define Uses_TStatusLine
#define Uses_TStatusDef
#define Uses_TStatusItem
#define Uses_TRadioButtons
#define Uses_TCheckBoxes
#define Uses_TSItem
#define Uses_TScrollBar
#define Uses_TScroller
#define Uses_TDrawBuffer
#define Uses_TScreen
#define Uses_TEventQueue
#define Uses_MsgBox
#include <ctype.h>
#include <dir.h>
#include <dos.h>
#include <io.h>
#include <stdlib.h>
#include <string.h>
#include <tvision/tv.h>

#include "screen.h"
#include "setup.h"

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
  kCmdProbe = 100,
  kCmdMemory,
  kCmdVideo,
  kCmdInput,
  kCmdPreview,
  kCmdLanguage
};

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

static void ShowMessage(const char* text) {
  messageBox(text, mfInformation | mfOKButton);
}

/* TV 2.0's stock TStaticText draw path copies only 255 bytes. These reports
 * have explicit line breaks; draw them directly and never split a Han pair. */
class Paragraph : public TStaticText {
  char* text_;

 public:
  Paragraph(TRect bounds, const char* text) : TStaticText(bounds, "") {
    text_ = new char[strlen(text) + 1];
    strcpy(text_, text);
  }
  virtual ~Paragraph() {
    delete[] text_;
  }
  virtual void draw() {
    const char* line = text_;
    TDrawBuffer buffer;
    for (int y = 0; y < size.y; ++y) {
      const char* end = strchr(line, '\n');
      unsigned line_length = end ? end - line : strlen(line);
      if (line_length > size.x) {
        line_length = size.x;
      }
      if (chinese) {
        unsigned i = 0;
        while (i < line_length) {
          unsigned width =
              (unsigned char)line[i] >= 0x80 && (unsigned char)line[i] < 0xb0
                  ? 2
                  : 1;
          if (i + width > line_length) {
            line_length = i;
            break;
          }
          i += width;
        }
      }
      buffer.moveChar(0, ' ', getColor(1), size.x);
      buffer.moveBuf(0, line, getColor(1), line_length);
      writeLine(0, y, size.x, 1, buffer);
      line = end ? end + 1 : line + strlen(line);
    }
  }
};

class Preview : public TScroller {
  char* text_;
  const char* lines_[128];
  unsigned line_count_;

 public:
  Preview(TRect bounds, TScrollBar* horizontal_scrollbar,
          TScrollBar* vertical_scrollbar, const char* source_text)
      : TScroller(bounds, horizontal_scrollbar, vertical_scrollbar) {
    text_ = new char[strlen(source_text) + 1];
    strcpy(text_, source_text);
    line_count_ = 1;
    lines_[0] = text_;
    for (char* line_cursor = text_; *line_cursor; ++line_cursor) {
      if (*line_cursor == '\r') {
        *line_cursor = 0;
      } else if (*line_cursor == '\n') {
        *line_cursor = 0;
        if (line_count_ < 128) {
          lines_[line_count_++] = line_cursor + 1;
        }
      }
    }
    setLimit(100, line_count_);
  }
  virtual ~Preview() {
    delete[] text_;
  }
  virtual void draw() {
    TDrawBuffer buffer;
    for (int y = 0; y < size.y; ++y) {
      buffer.moveChar(0, ' ', getColor(1), size.x);
      if (y + delta.y < line_count_ &&
          strlen(lines_[y + delta.y]) > (unsigned)delta.x) {
        const char* line_cursor = lines_[y + delta.y] + delta.x;
        unsigned visible_length = strlen(line_cursor);
        if (visible_length > size.x) {
          visible_length = size.x;
        }
        buffer.moveBuf(0, line_cursor, getColor(1), visible_length);
      }
      writeLine(0, y, size.x, 1, buffer);
    }
  }
};

class Setup : public TApplication {
  TDialog* home_;
  void RefreshDialog();
  void ShowMemoryDialog();
  void ShowVideoDialog();
  void ShowInputDialog();
  void ShowPreview();
  void ShowCapabilities();

 public:
  Setup()
      : TProgInit(&Setup::initStatusLine, 0, &Setup::initDeskTop), home_(0) {
    RefreshDialog();
  }
  virtual void handleEvent(TEvent& event);
  virtual void getEvent(TEvent& event) {
    PaintScreen();
    TApplication::getEvent(event);
    if (IsScreenActive() && event.what == evNothing) {
      ReadScreenMouse(event);
    }
  }
  static TStatusLine* initStatusLine(TRect r) {
    r.a.y = r.b.y - 1;
    return new TStatusLine(
        r, *new TStatusDef(0, 0xffff) +
               *new TStatusItem("~F2~ Probe", kbF2, kCmdProbe) +
               *new TStatusItem("~F3~ Preview", kbF3, kCmdPreview) +
               *new TStatusItem("~Alt-X~ Exit", kbAltX, cmQuit));
  }
};

void Setup::RefreshDialog() {
  char text[1800];
  const char* issue = PrepareConfiguration();
  if (home_) {
    deskTop->remove(home_);
    destroy(home_);
  }
  home_ = new TDialog(TRect(2, 1, 78, 23),
                      LocalizedText("HHBIOS Setup", "HHBIOS 安装设置"));
  home_->flags &= ~(wfClose | wfZoom);
  home_->options |= ofCentered;
  sprintf(
      text,
      LocalizedText(
          "Directory: %s\n\n"
          "DOS %u.%u    CPU class: %u    Conventional: %u KiB\n"
          "XMS free: %u KiB    EMS free: %u pages    Largest UMB: %u KiB\n\n"
          "Font storage: %s\nResident code: %s\nDisplay: %s\n"
          "Input tables: PY=%s  SW=%s  DB=%s  Wubi=%s\nPair-aware editing: "
          "%s\n\n"
          "VBE modes are BIOS reports; VESA verifies aperture isolation on "
          "load.\n"
          "Existing INI keys/colors are kept. WBX remains in conventional RAM.",
          "安装目录：%s\n\n"
          "DOS %u.%u    CPU 级别：%u    常规内存：%u KiB\n"
          "XMS 空闲：%u KiB    EMS 空闲：%u 页    最大 UMB：%u KiB\n\n"
          "字库存放：%s\n程序驻留：%s\n显示驱动：%s\n"
          "输入码表：拼音=%s  首尾=%s  电报=%s  五笔=%s\n整字编辑：%s\n\n"
          "VBE 能力来自 BIOS 报告；加载驱动时再验证显存隔离。\n"
          "保留原快捷键和颜色。五笔模块始终驻留常规内存。"),
      directory, machine.dos_major, machine.dos_minor, machine.cpu,
      machine.conventional_kb, machine.xms_total, machine.ems_pages,
      machine.umb_kb, kFontNames[choices.font],
      choices.low ? LocalizedText("Conventional only", "仅常规内存")
                  : LocalizedText("Prefer UMB, fall back to conventional",
                                  "优先 UMB，不足时用常规内存"),
      kVideoNames[choices.video], choices.ime & 1 ? "Y" : "N",
      choices.ime & 2 ? "Y" : "N", choices.ime & 4 ? "Y" : "N",
      choices.ime & 8 ? "Y" : "N", choices.paired ? "Y" : "N");
  home_->insert(new Paragraph(TRect(3, 2, 73, 15), text));
  home_->insert(new TStaticText(
      TRect(3, 15, 73, 17),
      issue
          ? LocalizedText("Not ready: use Preview to see what needs attention.",
                          "尚未就绪：请打开预览，查看需要解决的问题。")
          : LocalizedText("Ready. Preview both settings before saving.",
                          "配置就绪。请预览后保存，退出再运行 HHBIOS.BAT。")));
  home_->insert(new TButton(TRect(3, 17, 20, 19),
                            LocalizedText("~M~emory", "内存 (~M~)"), kCmdMemory,
                            bfNormal));
  home_->insert(new TButton(TRect(21, 17, 38, 19),
                            LocalizedText("~V~ideo", "显示 (~V~)"), kCmdVideo,
                            bfNormal));
  home_->insert(new TButton(TRect(39, 17, 56, 19),
                            LocalizedText("~I~nput", "输入法 (~I~)"), kCmdInput,
                            bfNormal));
  home_->insert(new TButton(TRect(57, 17, 73, 19),
                            LocalizedText("~L~anguage", "语言 (~L~)"),
                            kCmdLanguage, bfNormal));
  home_->insert(new TButton(TRect(3, 19, 25, 21),
                            LocalizedText("~H~ardware / F2", "检测结果 (~H~)"),
                            kCmdProbe, bfNormal));
  home_->insert(
      new TButton(TRect(27, 19, 52, 21),
                  LocalizedText("~P~review / Save", "预览与保存 (~P~)"),
                  kCmdPreview, bfDefault));
  home_->insert(new TButton(TRect(55, 19, 73, 21),
                            LocalizedText("E~x~it", "退出 (~X~)"), cmQuit,
                            bfNormal));
  deskTop->insert(home_);
}

static void AddDialogButtons(TDialog* dialog, int y) {
  dialog->insert(new TButton(TRect(12, y, 28, y + 2),
                             LocalizedText("~O~K", "确定 (~O~)"), cmOK,
                             bfDefault));
  dialog->insert(new TButton(TRect(32, y, 48, y + 2),
                             LocalizedText("~C~ancel", "取消 (~C~)"), cmCancel,
                             bfNormal));
  dialog->options |= ofCentered;
}

void Setup::ShowMemoryDialog() {
  TDialog* dialog =
      new TDialog(TRect(0, 0, 62, 19), LocalizedText("Memory", "内存配置"));
  dialog->insert(new TStaticText(
      TRect(3, 2, 59, 3),
      LocalizedText("Font storage (separate from resident code):",
                    "字库存放位置（与常驻代码分别设置）：")));
  TRadioButtons* font = new TRadioButtons(
      TRect(3, 4, 59, 7),
      new TSItem("XMS - READ5.COM",
                 new TSItem("EMS 4.0 - READ4.COM",
                            new TSItem(LocalizedText("Conventional - READ2.COM",
                                                     "常规内存 - READ2.COM"),
                                       0))));
  TRadioButtons* low = new TRadioButtons(
      TRect(3, 9, 59, 11),
      new TSItem(LocalizedText("Prefer UMB, fall back to conventional",
                               "优先使用 UMB，不足时使用常规内存"),
                 new TSItem(LocalizedText("Conventional only (/N)",
                                          "仅使用常规内存 (/N)"),
                            0)));
  dialog->insert(font);
  dialog->insert(low);
  dialog->insert(new TStaticText(
      TRect(3, 12, 59, 15),
      LocalizedText(
          "XMS/EMS managers must already be installed.\nVESA needs another "
          "font "
          "store (about 752 KiB).\nREAD2 and WBX always use conventional "
          "memory.",
          "XMS/EMS 管理器须已在系统启动时加载。\nVESA 另需一份字库存储（约 752 "
          "KiB）。\nREAD2 和五笔始终使用常规内存。")));
  font->setData(&choices.font);
  low->setData(&choices.low);
  AddDialogButtons(dialog, 16);
  if (deskTop->execView(dialog) == cmOK) {
    font->getData(&choices.font);
    low->getData(&choices.low);
  }
  destroy(dialog);
  RefreshDialog();
}

void Setup::ShowVideoDialog() {
  TDialog* dialog = new TDialog(TRect(0, 0, 62, 20),
                                LocalizedText("Display driver", "显示驱动"));
  TSItem* items = 0;
  for (int i = kVideoCount - 1; i >= 0; --i) {
    items = new TSItem(kVideoNames[i], items);
  }
  TRadioButtons* video_choices = new TRadioButtons(TRect(3, 3, 59, 10), items);
  dialog->insert(video_choices);
  video_choices->setData(&choices.video);
  dialog->insert(new TStaticText(
      TRect(3, 12, 59, 16),
      LocalizedText(
          "VESA: planar 16-color modes, XMS/EMS + HH20.FNT.\nText applications "
          "retain their logical text grid.\nHercules: choose only for a real "
          "graphics-capable card.\nSetup's own Chinese display does not "
          "require "
          "HHBIOS.",
          "VESA：平面 16 色模式，需要 XMS/EMS 和 "
          "HH20."
          "FNT。\n文本软件保留原有的逻辑文本行列数。\nHercules：仅可手动选择具"
          "备"
          "图形能力的单色卡。\n安装程序的中文显示无需加载 HHBIOS。")));
  AddDialogButtons(dialog, 17);
  if (deskTop->execView(dialog) == cmOK) {
    video_choices->getData(&choices.video);
  }
  destroy(dialog);
  RefreshDialog();
}

void Setup::ShowInputDialog() {
  TDialog* dialog = new TDialog(TRect(0, 0, 62, 19),
                                LocalizedText("Input methods", "输入法配置"));
  TCheckBoxes* ime = new TCheckBoxes(
      TRect(3, 3, 59, 7),
      new TSItem(
          LocalizedText("Pinyin / Shuangpin (PYMB)", "拼音／双拼 (PYMB)"),
          new TSItem(
              LocalizedText("Shouwei (SWMB)", "首尾码 (SWMB)"),
              new TSItem(
                  LocalizedText("Telegraph (DBMB)", "电报码 (DBMB)"),
                  new TSItem(
                      LocalizedText("Wubi (WBX.COM, about 47 KiB low memory)",
                                    "五笔 (WBX.COM，约 47 KiB 常规内存)"),
                      0)))));
  TCheckBoxes* pair = new TCheckBoxes(
      TRect(3, 9, 59, 10),
      new TSItem(LocalizedText("Pair-aware editing for Chinese text (/E)",
                               "中文整字编辑，避免删除半个汉字 (/E)"),
                 0));
  dialog->insert(ime);
  dialog->insert(pair);
  ime->setData(&choices.ime);
  pair->setData(&choices.paired);
  dialog->insert(new TStaticText(
      TRect(3, 12, 59, 15),
      LocalizedText(
          "Quwei input is built into CKBD and always available.\nOnly enable "
          "tables present in the installation folder.\nExisting keyboard, "
          "colors "
          "and phrase options are kept.",
          "CKBD "
          "自带区位码输入，无需额外码表。\n请只启用安装目录中已有的输入码表。\n"
          "保"
          "留原键盘、颜色和词组设置。")));
  AddDialogButtons(dialog, 16);
  if (deskTop->execView(dialog) == cmOK) {
    ime->getData(&choices.ime);
    pair->getData(&choices.paired);
  }
  destroy(dialog);
  RefreshDialog();
}

void Setup::ShowCapabilities() {
  char text[1600];
  sprintf(
      text,
      LocalizedText(
          "DOS %u.%u    CPU class %u (FLAGS test)\n"
          "Conventional: %u KiB\nLargest block after SETUP exit: about %u "
          "KiB\nLargest free DOS UMB: %u KiB\n\n"
          "XMS version %X: largest %u KiB, total %u KiB\nEMS version %X: %u "
          "free pages, frame %04X\n"
          "DPMI host reported: %s (not entered)\nVBE version: %X\n"
          "Planar modes: 102=%s 104=%s 106=%s\n\n"
          "Read-only BIOS/manager queries; no graphics test.\nThe VESA "
          "driver validates bank/aperture behavior later.\nUMB allocation "
          "policy is restored after querying.\nMemory estimates are not "
          "allocation guarantees.",
          "DOS %u.%u    CPU 级别 %u（FLAGS 检测）\n"
          "常规内存：%u KiB\n安装程序退出后最大空闲块：约 %u KiB\n最大空闲 "
          "DOS UMB：%u KiB\n\n"
          "XMS 版本 %X：最大块 %u KiB，合计 %u KiB\nEMS 版本 %X：空闲 %u "
          "页，页框 %04X\n"
          "DPMI 主机报告：%s（不进入保护模式）\nVBE 版本：%X\n"
          "平面模式：102=%s 104=%s 106=%s\n\n"
          "仅查询 BIOS 和内存管理器，未测试图形模式。\nVESA "
          "驱动加载时再验证银行切换与显存隔离。\n查询后恢复 UMB "
          "分配策略。\n空闲内存估计不保证实际分配一定成功。"),
      machine.dos_major, machine.dos_minor, machine.cpu,
      machine.conventional_kb, machine.free_kb, machine.umb_kb,
      machine.xms_version, machine.xms_largest, machine.xms_total,
      machine.ems_version, machine.ems_pages, machine.ems_frame,
      machine.dpmi ? "Y" : "N", machine.vbe_version,
      machine.modes & 1 ? "Y" : "N", machine.modes & 2 ? "Y" : "N",
      machine.modes & 4 ? "Y" : "N");
  TDialog* dialog =
      new TDialog(TRect(0, 0, 68, 22),
                  LocalizedText("Detected capabilities", "机器能力检测"));
  dialog->options |= ofCentered;
  dialog->insert(new Paragraph(TRect(3, 2, 65, 18), text));
  dialog->insert(new TButton(TRect(24, 19, 44, 21),
                             LocalizedText("~O~K", "确定 (~O~)"), cmOK,
                             bfDefault));
  deskTop->execView(dialog);
  destroy(dialog);
}

void Setup::ShowPreview() {
  const char* error = PrepareConfiguration();
  if (error) {
    ShowMessage(error);
    return;
  }
  TDialog* dialog =
      new TDialog(TRect(0, 0, 76, 23),
                  LocalizedText("Preview HHBIOS.BAT", "预览 HHBIOS.BAT"));
  dialog->options |= ofCentered;
  TScrollBar* horizontal_scrollbar = new TScrollBar(TRect(2, 16, 73, 17));
  TScrollBar* vertical_scrollbar = new TScrollBar(TRect(73, 2, 74, 16));
  dialog->insert(horizontal_scrollbar);
  dialog->insert(vertical_scrollbar);
  dialog->insert(new Preview(TRect(2, 2, 73, 16), horizontal_scrollbar,
                             vertical_scrollbar, batch));
  dialog->insert(new TStaticText(
      TRect(3, 18, 72, 20),
      LocalizedText(
          "Also updates input-table switches in 213L.INI.\nExisting files are "
          "backed up as HHBIOS.BAK / 213L.BAK.",
          "同时更新 213L.INI 的输入码表开关。\n原文件备份为 HHBIOS.BAK / "
          "213L.BAK。")));
  dialog->insert(
      new TButton(TRect(12, 20, 34, 22),
                  LocalizedText("~S~ave both files", "保存两个文件 (~S~)"),
                  cmOK, bfNormal));
  dialog->insert(new TButton(TRect(42, 20, 64, 22),
                             LocalizedText("~C~ancel", "取消 (~C~)"), cmCancel,
                             bfDefault));
  if (deskTop->execView(dialog) == cmOK) {
    error = SaveConfigurationFiles(batch, ini);
    ShowMessage(
        error ? error
              : LocalizedText(
                    "Saved. Exit SETUP, then run HHBIOS.BAT. No TSR has been "
                    "loaded.",
                    "已保存。请退出安装程序，再运行 "
                    "HHBIOS.BAT。尚未加载常驻程序。"));
  }
  destroy(dialog);
}

void Setup::handleEvent(TEvent& event) {
  TApplication::handleEvent(event);
  if (event.what != evCommand) {
    return;
  }
  switch (event.message.command) {
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
        RefreshDialog();
      } else {
        ShowMessage(
            "Chinese setup requires VGA. Start SETUP /ZH on a VGA adapter.");
      }
      break;
    default:
      return;
  }
  clearEvent(event);
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
        unsigned drive = toupper(path[0]) - 'A';
        setdisk(drive);
        if (getdisk() != drive) {
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
  if (language != 0 && machine.adapter == kAdapterVga) {
    chinese = StartScreen();
  }
  if (language == 1 && !chinese) {
    puts(
        "Chinese setup needs VGA, HZK16 and free conventional memory. Use "
        "SETUP /EN.");
    return 1;
  }
  Setup* app = new Setup;
  app->run();
  app->shutDown();
  delete app;
  StopScreen();
  return 0;
}

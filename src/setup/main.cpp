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
#include <tvision/tv.h>
#include <dos.h>
#include <dir.h>
#include <io.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include "setup.h"
#include "screen.h"

static Machine machine;
static Files files;
static Choices choices;
static char directory[80], batch[BatchSize], ini[IniSize], original[IniSize];
static int chinese=0, ini_ok=1;
static const char *L(const char *en, const char *zh) { return chinese ? screen_text(zh) : en; }
enum { cmProbe=100, cmMemory, cmVideo, cmInput, cmPreview, cmLanguage };

static int load_ini()
{
    FILE *fp=fopen("213L.INI","rb");
    unsigned n;
    original[0]=0;
    if (!fp) return access("213L.INI",0)!=0;
    n=fread(original,1,sizeof(original)-1,fp);
    int ok=!ferror(fp) && feof(fp);
    fclose(fp); original[n]=0;
    return ok && !memchr(original,0,n) && make_ini(original,&choices,ini);
}

static const char *prepare()
{
    const char *error;
    scan_files(&files);
    error=validate(&machine,&files,&choices);
    if (error) return error;
    if (!make_batch(directory,&choices,batch))
        return L("Use a DOS 8.3 directory path of at most 32 characters.",
                 "安装目录须为 DOS 短路径，完整路径不超过 32 字节。");
    if (!ini_ok || !make_ini(original,&choices,ini))
        return L("213L.INI is malformed or too large. Keep a copy and repair it first.",
                 "213L.INI 格式有误或过大，请先备份并修复原配置。");
    return 0;
}

static void note(const char *text)
{
    messageBox(text,mfInformation|mfOKButton);
}

/* TV 2.0's stock TStaticText draw path copies only 255 bytes. These reports
 * have explicit line breaks; draw them directly and never split a Han pair. */
class Paragraph : public TStaticText {
    char *value;
public:
    Paragraph(TRect r,const char *s) : TStaticText(r,"") {
        value=new char[strlen(s)+1];strcpy(value,s);
    }
    virtual ~Paragraph() { delete [] value; }
    virtual void draw() {
        const char *p=value;
        TDrawBuffer b;
        for(int y=0;y<size.y;++y) {
            const char *end=strchr(p,'\n');
            unsigned n=end ? end-p : strlen(p);
            if(n>size.x) n=size.x;
            if(chinese) {
                unsigned i=0;
                while(i<n) {
                    unsigned width=(unsigned char)p[i]>=0x80 &&
                                   (unsigned char)p[i]<0xb0 ? 2 : 1;
                    if(i+width>n) { n=i; break; }
                    i+=width;
                }
            }
            b.moveChar(0,' ',getColor(1),size.x);
            b.moveBuf(0,p,getColor(1),n);writeLine(0,y,size.x,1,b);
            p=end ? end+1 : p+strlen(p);
        }
    }
};

class Preview : public TScroller {
    char *text;
    const char *lines[128];
    unsigned count;
public:
    Preview(TRect r,TScrollBar *h,TScrollBar *v,const char *data) : TScroller(r,h,v) {
        text=new char[strlen(data)+1]; strcpy(text,data); count=1; lines[0]=text;
        for (char *p=text; *p; ++p) {
            if (*p=='\r') *p=0;
            else if (*p=='\n') { *p=0; if(count<128) lines[count++]=p+1; }
        }
        setLimit(100,count);
    }
    virtual ~Preview() { delete [] text; }
    virtual void draw() {
        TDrawBuffer b;
        for (int y=0; y<size.y; ++y) {
            b.moveChar(0,' ',getColor(1),size.x);
            if (y+delta.y<count && strlen(lines[y+delta.y])>(unsigned)delta.x) {
                const char *p=lines[y+delta.y]+delta.x;
                unsigned n=strlen(p); if(n>size.x) n=size.x;
                b.moveBuf(0,p,getColor(1),n);
            }
            writeLine(0,y,size.x,1,b);
        }
    }
};

class Setup : public TApplication {
    TDialog *home;
    void refresh();
    void memoryDialog();
    void videoDialog();
    void inputDialog();
    void preview();
    void capabilities();
public:
    Setup() : TProgInit(&Setup::initStatusLine,0,&Setup::initDeskTop), home(0) { refresh(); }
    virtual void handleEvent(TEvent &event);
    virtual void getEvent(TEvent &event) {
        screen_paint();
        TApplication::getEvent(event);
        if (screen_active() && event.what==evNothing) screen_mouse(event);
    }
    static TStatusLine *initStatusLine(TRect r) {
        r.a.y=r.b.y-1;
        return new TStatusLine(r,*new TStatusDef(0,0xffff)+
            *new TStatusItem("~F2~ Probe",kbF2,cmProbe)+
            *new TStatusItem("~F3~ Preview",kbF3,cmPreview)+
            *new TStatusItem("~Alt-X~ Exit",kbAltX,cmQuit));
    }
};

void Setup::refresh()
{
    char text[1800];
    const char *issue=prepare();
    if(home) { deskTop->remove(home); destroy(home); }
    home=new TDialog(TRect(2,1,78,23),L("HHBIOS Setup","HHBIOS 安装设置"));
    home->flags &= ~(wfClose|wfZoom);
    home->options |= ofCentered;
    sprintf(text,L("Directory: %s\n\n"
        "DOS %u.%u    CPU class: %u    Conventional: %u KiB\n"
        "XMS free: %u KiB    EMS free: %u pages    Largest UMB: %u KiB\n\n"
        "Font storage: %s\nResident code: %s\nDisplay: %s\n"
        "Input tables: PY=%s  SW=%s  DB=%s  Wubi=%s\nPair-aware editing: %s\n\n"
        "VBE modes are BIOS reports; VESA verifies aperture isolation on load.\n"
        "Existing INI keys/colors are kept. WBX remains in conventional RAM.",
        "安装目录：%s\n\n"
        "DOS %u.%u    CPU 级别：%u    常规内存：%u KiB\n"
        "XMS 空闲：%u KiB    EMS 空闲：%u 页    最大 UMB：%u KiB\n\n"
        "字库存放：%s\n程序驻留：%s\n显示驱动：%s\n"
        "输入码表：拼音=%s  首尾=%s  电报=%s  五笔=%s\n整字编辑：%s\n\n"
        "VBE 能力来自 BIOS 报告；加载驱动时再验证显存隔离。\n"
        "保留原快捷键和颜色。五笔模块始终驻留常规内存。"),
        directory,machine.dos_major,machine.dos_minor,machine.cpu,machine.conventional_kb,
        machine.xms_total,machine.ems_pages,machine.umb_kb,font_names[choices.font],
        choices.low ? L("Conventional only","仅常规内存") : L("Prefer UMB, fall back to conventional","优先 UMB，不足时用常规内存"),
        video_names[choices.video],choices.ime&1 ? "Y":"N",choices.ime&2 ? "Y":"N",
        choices.ime&4 ? "Y":"N",choices.ime&8 ? "Y":"N",choices.paired ? "Y":"N");
    home->insert(new Paragraph(TRect(3,2,73,15),text));
    home->insert(new TStaticText(TRect(3,15,73,17),issue ?
        L("Not ready: use Preview to see what needs attention.","尚未就绪：请打开预览，查看需要解决的问题。") :
        L("Ready. Preview both settings before saving.","配置就绪。请预览后保存，退出再运行 HHBIOS.BAT。")));
    home->insert(new TButton(TRect(3,17,20,19),L("~M~emory","内存 (~M~)"),cmMemory,bfNormal));
    home->insert(new TButton(TRect(21,17,38,19),L("~V~ideo","显示 (~V~)"),cmVideo,bfNormal));
    home->insert(new TButton(TRect(39,17,56,19),L("~I~nput","输入法 (~I~)"),cmInput,bfNormal));
    home->insert(new TButton(TRect(57,17,73,19),L("~L~anguage","语言 (~L~)"),cmLanguage,bfNormal));
    home->insert(new TButton(TRect(3,19,25,21),L("~H~ardware / F2","检测结果 (~H~)"),cmProbe,bfNormal));
    home->insert(new TButton(TRect(27,19,52,21),L("~P~review / Save","预览与保存 (~P~)"),cmPreview,bfDefault));
    home->insert(new TButton(TRect(55,19,73,21),L("E~x~it","退出 (~X~)"),cmQuit,bfNormal));
    deskTop->insert(home);
}

static void ok_cancel(TDialog *d,int y)
{
    d->insert(new TButton(TRect(12,y,28,y+2),L("~O~K","确定 (~O~)"),cmOK,bfDefault));
    d->insert(new TButton(TRect(32,y,48,y+2),L("~C~ancel","取消 (~C~)"),cmCancel,bfNormal));
    d->options|=ofCentered;
}

void Setup::memoryDialog()
{
    TDialog *d=new TDialog(TRect(0,0,62,19),L("Memory","内存配置"));
    d->insert(new TStaticText(TRect(3,2,59,3),L("Font storage (separate from resident code):","字库存放位置（与常驻代码分别设置）：")));
    TRadioButtons *font=new TRadioButtons(TRect(3,4,59,7),new TSItem("XMS - READ5.COM",
        new TSItem("EMS 4.0 - READ4.COM",new TSItem(L("Conventional - READ2.COM","常规内存 - READ2.COM"),0))));
    TRadioButtons *low=new TRadioButtons(TRect(3,9,59,11),new TSItem(
        L("Prefer UMB, fall back to conventional","优先使用 UMB，不足时使用常规内存"),new TSItem(
        L("Conventional only (/N)","仅使用常规内存 (/N)"),0)));
    d->insert(font); d->insert(low);
    d->insert(new TStaticText(TRect(3,12,59,15),L(
        "XMS/EMS managers must already be installed.\nVESA needs another font store (about 752 KiB).\nREAD2 and WBX always use conventional memory.",
        "XMS/EMS 管理器须已在系统启动时加载。\nVESA 另需一份字库存储（约 752 KiB）。\nREAD2 和五笔始终使用常规内存。")));
    font->setData(&choices.font); low->setData(&choices.low); ok_cancel(d,16);
    if(deskTop->execView(d)==cmOK) {font->getData(&choices.font);low->getData(&choices.low);}
    destroy(d); refresh();
}

void Setup::videoDialog()
{
    TDialog *d=new TDialog(TRect(0,0,62,20),L("Display driver","显示驱动"));
    TSItem *items=0;
    for(int i=VideoCount-1;i>=0;--i) items=new TSItem(video_names[i],items);
    TRadioButtons *v=new TRadioButtons(TRect(3,3,59,10),items);
    d->insert(v); v->setData(&choices.video);
    d->insert(new TStaticText(TRect(3,12,59,16),L(
        "VESA: planar 16-color modes, XMS/EMS + HH20.FNT.\nText applications retain their logical text grid.\nHercules: choose only for a real graphics-capable card.\nSetup's own Chinese display does not require HHBIOS.",
        "VESA：平面 16 色模式，需要 XMS/EMS 和 HH20.FNT。\n文本软件保留原有的逻辑文本行列数。\nHercules：仅可手动选择具备图形能力的单色卡。\n安装程序的中文显示无需加载 HHBIOS。")));
    ok_cancel(d,17);
    if(deskTop->execView(d)==cmOK) v->getData(&choices.video);
    destroy(d); refresh();
}

void Setup::inputDialog()
{
    TDialog *d=new TDialog(TRect(0,0,62,19),L("Input methods","输入法配置"));
    TCheckBoxes *ime=new TCheckBoxes(TRect(3,3,59,7),new TSItem(L("Pinyin / Shuangpin (PYMB)","拼音／双拼 (PYMB)"),
        new TSItem(L("Shouwei (SWMB)","首尾码 (SWMB)"),new TSItem(L("Telegraph (DBMB)","电报码 (DBMB)"),
        new TSItem(L("Wubi (WBX.COM, about 47 KiB low memory)","五笔 (WBX.COM，约 47 KiB 常规内存)"),0)))));
    TCheckBoxes *pair=new TCheckBoxes(TRect(3,9,59,10),new TSItem(
        L("Pair-aware editing for Chinese text (/E)","中文整字编辑，避免删除半个汉字 (/E)"),0));
    d->insert(ime); d->insert(pair); ime->setData(&choices.ime); pair->setData(&choices.paired);
    d->insert(new TStaticText(TRect(3,12,59,15),L(
        "Quwei input is built into CKBD and always available.\nOnly enable tables present in the installation folder.\nExisting keyboard, colors and phrase options are kept.",
        "CKBD 自带区位码输入，无需额外码表。\n请只启用安装目录中已有的输入码表。\n保留原键盘、颜色和词组设置。")));
    ok_cancel(d,16);
    if(deskTop->execView(d)==cmOK) {ime->getData(&choices.ime);pair->getData(&choices.paired);}
    destroy(d); refresh();
}

void Setup::capabilities()
{
    char text[1600];
    sprintf(text,L("DOS %u.%u    CPU class %u (FLAGS test)\n"
        "Conventional: %u KiB\nLargest block after SETUP exit: about %u KiB\nLargest free DOS UMB: %u KiB\n\n"
        "XMS version %X: largest %u KiB, total %u KiB\nEMS version %X: %u free pages, frame %04X\n"
        "DPMI host reported: %s (not entered)\nVBE version: %X\n"
        "Planar modes: 102=%s 104=%s 106=%s\n\n"
        "Read-only BIOS/manager queries; no graphics test.\nThe VESA driver validates bank/aperture behavior later.\nUMB allocation policy is restored after querying.\nMemory estimates are not allocation guarantees.",
        "DOS %u.%u    CPU 级别 %u（FLAGS 检测）\n"
        "常规内存：%u KiB\n安装程序退出后最大空闲块：约 %u KiB\n最大空闲 DOS UMB：%u KiB\n\n"
        "XMS 版本 %X：最大块 %u KiB，合计 %u KiB\nEMS 版本 %X：空闲 %u 页，页框 %04X\n"
        "DPMI 主机报告：%s（不进入保护模式）\nVBE 版本：%X\n"
        "平面模式：102=%s 104=%s 106=%s\n\n"
        "仅查询 BIOS 和内存管理器，未测试图形模式。\nVESA 驱动加载时再验证银行切换与显存隔离。\n查询后恢复 UMB 分配策略。\n空闲内存估计不保证实际分配一定成功。"),
        machine.dos_major,machine.dos_minor,machine.cpu,machine.conventional_kb,machine.free_kb,machine.umb_kb,
        machine.xms_version,machine.xms_largest,machine.xms_total,machine.ems_version,machine.ems_pages,
        machine.ems_frame,machine.dpmi ? "Y":"N",machine.vbe_version,
        machine.modes&1 ? "Y":"N",machine.modes&2 ? "Y":"N",machine.modes&4 ? "Y":"N");
    TDialog *d=new TDialog(TRect(0,0,68,22),L("Detected capabilities","机器能力检测"));
    d->options|=ofCentered;
    d->insert(new Paragraph(TRect(3,2,65,18),text));
    d->insert(new TButton(TRect(24,19,44,21),L("~O~K","确定 (~O~)"),cmOK,bfDefault));
    deskTop->execView(d); destroy(d);
}

void Setup::preview()
{
    const char *error=prepare();
    if(error) { note(error); return; }
    TDialog *d=new TDialog(TRect(0,0,76,23),L("Preview HHBIOS.BAT","预览 HHBIOS.BAT"));
    d->options|=ofCentered;
    TScrollBar *h=new TScrollBar(TRect(2,16,73,17));
    TScrollBar *v=new TScrollBar(TRect(73,2,74,16));
    d->insert(h);d->insert(v);d->insert(new Preview(TRect(2,2,73,16),h,v,batch));
    d->insert(new TStaticText(TRect(3,18,72,20),L(
        "Also updates input-table switches in 213L.INI.\nExisting files are backed up as HHBIOS.BAK / 213L.BAK.",
        "同时更新 213L.INI 的输入码表开关。\n原文件备份为 HHBIOS.BAK / 213L.BAK。")));
    d->insert(new TButton(TRect(12,20,34,22),L("~S~ave both files","保存两个文件 (~S~)"),cmOK,bfNormal));
    d->insert(new TButton(TRect(42,20,64,22),L("~C~ancel","取消 (~C~)"),cmCancel,bfDefault));
    if(deskTop->execView(d)==cmOK) {
        error=save_pair(batch,ini);
        note(error ? error : L("Saved. Exit SETUP, then run HHBIOS.BAT. No TSR has been loaded.",
            "已保存。请退出安装程序，再运行 HHBIOS.BAT。尚未加载常驻程序。"));
    }
    destroy(d);
}

void Setup::handleEvent(TEvent &event)
{
    TApplication::handleEvent(event);
    if(event.what!=evCommand) return;
    switch(event.message.command) {
    case cmMemory: memoryDialog(); break;
    case cmVideo: videoDialog(); break;
    case cmInput: inputDialog(); break;
    case cmProbe: capabilities(); break;
    case cmPreview: preview(); break;
    case cmLanguage:
        if(screen_active()) {chinese=!chinese;refresh();}
        else note("Chinese setup requires VGA. Start SETUP /ZH on a VGA adapter.");
        break;
    default: return;
    }
    clearEvent(event);
}

int main(int argc,char **argv)
{
    int i, automatic=0, report=0, language=-1, ime_seen=0;
    char path[80], *slash;
    /* Keep the executable and all modules together; never embed a host path. */
    if(strlen(argv[0])<sizeof(path)) {
        strcpy(path,argv[0]); slash=strrchr(path,'\\');
        if(slash) {
            if(slash==path+2) slash[1]=0; else *slash=0;
            if(chdir(path)) {puts("Cannot enter installation directory.");return 1;}
            if(path[1]==':') {
                unsigned drive=toupper(path[0])-'A';setdisk(drive);
                if(getdisk()!=drive) {puts("Cannot select installation drive.");return 1;}
            }
        }
    }
    if(!getcwd(directory,sizeof(directory))) { puts("Cannot read installation directory."); return 1; }
    probe_machine(&machine);scan_files(&files);recommend(&machine,&files,&choices);
    for(i=1;i<argc;++i) {
        if(!stricmp(argv[i],"/AUTO")) automatic=1;
        else if(!stricmp(argv[i],"/REPORT")) report=1;
        else if(!stricmp(argv[i],"/EN")) language=0;
        else if(!stricmp(argv[i],"/ZH")) language=1;
        else if(!stricmp(argv[i],"/LOW")) choices.low=1;
        else if(!stricmp(argv[i],"/BYTE")) choices.paired=0;
        else if(!stricmp(argv[i],"/FONT:XMS")) choices.font=FontXms;
        else if(!stricmp(argv[i],"/FONT:EMS")) choices.font=FontEms;
        else if(!stricmp(argv[i],"/FONT:LOW")) choices.font=FontLow;
        else if(!strnicmp(argv[i],"/VIDEO:",7)) {
            const char *names[]={"VGA","102","104","106","EGA","HGA","CGA"};
            unsigned v;
            for(v=0;v<VideoCount;++v) if(!stricmp(argv[i]+7,names[v])) break;
            if(v==VideoCount) {puts("Unknown /VIDEO choice.");return 1;} choices.video=v;
        } else if(!strnicmp(argv[i],"/IME:",5)) {
            if(!ime_seen++) choices.ime=0;
            if(!stricmp(argv[i]+5,"PY")) choices.ime|=1;
            else if(!stricmp(argv[i]+5,"SW")) choices.ime|=2;
            else if(!stricmp(argv[i]+5,"DB")) choices.ime|=4;
            else if(!stricmp(argv[i]+5,"WB")) choices.ime|=8;
            else if(stricmp(argv[i]+5,"NONE")) {puts("Unknown /IME choice.");return 1;}
        } else {
            puts("SETUP [/EN|/ZH] [/REPORT|/AUTO] [/LOW] [/BYTE]\n"
                 "      [/FONT:XMS|EMS|LOW] [/VIDEO:VGA|102|104|106|EGA|HGA|CGA]\n"
                 "      [/IME:NONE|PY|SW|DB|WB] (repeat /IME to combine)\n"
                 "/REPORT queries only; /AUTO explicitly saves without a dialog.");
            return !stricmp(argv[i],"/?") ? 0:1;
        }
    }
    if(report) {report_machine(stdout,&machine,&files);return 0;}
    ini_ok=load_ini();
    if(automatic) {
        const char *error=prepare(); if(!error) error=save_pair(batch,ini);
        puts(error ? error : "Saved HHBIOS.BAT and 213L.INI."); return error ? 1:0;
    }
    if(machine.loaded) {puts("Start SETUP from a clean DOS session before loading HHBIOS.");return 1;}
    if(language!=0 && machine.adapter==AdapterVga) chinese=screen_start();
    if(language==1 && !chinese) {puts("Chinese setup needs VGA, HZK16 and free conventional memory. Use SETUP /EN.");return 1;}
    Setup *app=new Setup;
    app->run(); app->shutDown(); delete app;
    screen_stop();
    return 0;
}

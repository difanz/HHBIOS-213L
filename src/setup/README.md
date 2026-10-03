# SETUP.EXE

独立的 DOS Open Watcom UI 安装程序。检测机器和可用模块，设置字库存储、程序驻留、显示驱动、文本布局、输入法、键盘、颜色和打印模块，预览并生成 `HHBIOS.BAT` 与 `213L.INI`。安装程序不加载 TSR，不修改 `CONFIG.SYS` 或 `AUTOEXEC.BAT`。

将 `SETUP.EXE` 放到 HHBIOS 安装目录，与 COM 模块、`HZK16`、输入码表放在一起。VESA 使用 `HH20.FNT` 或同目录中合适的 `F????.FNT`；高分辨率字库见 [fonts/large](../../fonts/large/)。使用 DOS 短目录名，完整路径最多 32 字节，以适应原有字库加载器的路径缓冲区。

```dos
SETUP
HHBIOS.BAT
```

退出设置后执行生成的批处理。已加载 HHBIOS 时也可编辑下次启动的配置；更换常驻配置前应重新启动 DOS。界面支持键盘和已有的 INT 33h 鼠标驱动：Tab 切换控件，方向键选择，空格切换复选框，F2 查看检测结果，F3 预览，Alt-X 退出。对话框的确定保留编辑，Escape 取消该层对话框，预览中的保存才写入文件。

## 中文与旧机器

程序为 **16 位实模式 EXE**，不需要 DPMI、XMS、EMS 或 HHBIOS 常驻接口。中文界面使用 VGA 640×480，逻辑网格为 80×30；西文采用 VGA ROM 8×16 点阵，中文直接读取 `HZK16` 的 16×16 点阵。整套字库放在进程的常规内存中，退出时释放。源代码字符串使用 UTF-8，构建时转换为 GB2312。

Open Watcom UI 仍管理窗口、对话框、焦点和控件；安装程序将其字符缓冲区绘制到 VGA。中文双字节在交给 Open Watcom UI 前使用私有显示编码，避免把 CP437 框线误识别为汉字。此编码仅存在于界面缓冲区，配置文件仍使用原有格式。

`SETUP /EN` 使用英文文本界面；`SETUP /ZH` 要求中文界面。独立运行时，默认在 VGA、字库及空闲内存满足条件时显示中文，否则使用英文。已加载 HHBIOS 时沿用常驻显示驱动，默认使用英文；`/ZH` 或 Alt-L 可选择中文，无需另分配 VGA 字库缓冲。CGA、EGA、MDA 的独立设置界面使用英文文本模式；Hercules 驱动需手动选择，不能仅根据单色设备标志推断。程序按 8086 指令集构建；中文显示是否可用由显卡和内存决定，并非由是否为 PC/XT 决定。

## 检测与推荐

- CPU 的 FLAGS 行为类别、DOS 版本、常规内存、安装程序退出后的最大连续空闲块估计。
- DOS UMB 最大空闲块；查询后恢复分配策略和 UMB 链接状态。
- XMS 版本、最大空闲块与总量；EMS 版本、页框和空闲页数；只查询 DPMI 主机，不进入保护模式。
- BIOS 显示适配器、VBE 版本及 BIOS 模式列表，最多读取 512 项，分别保存完整列表和驱动兼容列表。模式筛选与 VESA 驱动共用布局检查函数。银行切换和 B800 隔离仍由 VESA 驱动加载时验证。
- VBE/DDC `4F15h` 返回的 EDID 基础块：校验头、版本、校验和及首选详细时序，报告屏幕首选尺寸。兼容时优先推荐此模式，否则保留默认显示方案。
- 所需 COM、字库及输入码表是否存在；显示字库校验头部与完整文件长度，并与 VESA 共用字号选择规则。推荐先选择 XMS、EMS，最后才用常规内存；VESA 会同时计入普通字库和当前布局字库的需求。

UMB 默认由各模块自行尝试，不额外使用 `LOADHIGH`。强制常规内存只给支持的模块传 `/N`；`READ2` 和 `WBX` 本身使用常规内存。区位输入由 CKBD 提供；拼音／双拼、首尾、电报分别使用 `PYMB`、`SWMB`、`DBMB`，五笔加载 `WBX.COM`。原 INI 的未修改值、保留字节、注释及 DOS 文件结束符保持原样。

## 键盘、显示参数与打印

Alt-K 打开键盘设置：仿长城键盘、0～9 KiB 双拼词组扩展区、左／右 Shift 或 Scroll Lock 开关键，以及 14 个功能键。功能键不可重复分配。仿长城键盘会同时调整六个输入方式键。

Alt-D 的显示设置分为外观和程序兼容性。状态栏默认使用浅灰底、黑色文字和深蓝选中项；四组状态栏颜色分别选择文字和背景，彩显提供色块及组合预览，单色显示器显示颜色名称。213L.INI 包含 31 项设置，由 SETUP 生成；没有独立的 VGA 光带配色项。

HHBIOS 控制菜单在提示行用数字键操作。打开后只有 1输入、2显示、3输出、4退出。再按一个数字立即执行该组中的对应功能，Esc 退回上一层，直到回到版权行。十四项功能都从这里到达。

Alt-A 选择 `INT10K`／`INT10V`、`PRNT`／`PRTH` 打印机型号和 `READ16`、`READ24`、`READ32`、`READ40`、`READSL` 打印字库读取器。`PRTH` 需要发行包的 `PR.EXE` 与 `PRTA.TAB`，生成的批处理先加载 `PR`。缺少所选模块或字库时不能保存。

`READ24`、`READ32`、`READ40` 直接使用 HHFONT2 文件，默认分别为 `HH24.FNT`、`HH32.FNT`、`HH40.FNT`。可为每个读取器的四个字体位置指定实际文件；留空的位置复用默认字体，不生成仿宋、黑体或楷体的伪造字形。加载时将字库读入 XMS／EMS，打印中断不调用 DOS 文件接口。界面可选择自动、XMS 或 EMS，并校验显示字库与打印字库的合计需求；选择打印字库时，按 VESA 完整预载字库组预留内存。

`READSL` 保留自己的 DOS 文件／扇区读取开关；默认普通文字需要 `HZKSLT` 和 `HZKSLSTJ`。此选项不影响 HHFONT2 点阵读取器。

启动时依次查找同目录的 `HHBIOS.BAT`、`213L.BAT`，最后查找 `C:\213L.BAT`，读取受支持的模块配置，包括 HHFONT2 文件路径和内存选择。原 `213L.BAT` 不改写。不能识别的模块参数会阻止保存，避免无声丢失配置；旧点阵读取器的 `WSFHK` 等参数需先改为当前文件选项。其他自定义批处理命令不加入生成的 `HHBIOS.BAT`。

保存先写完两份临时文件，再将原件保留为 `HHBIOS.BAK`、`213L.BAK`，替换已有备份。备份保存的是本次修改前的配置。写入失败时尝试恢复原件。DOS 不提供跨两个文件的事务，断电后的临时文件和备份应先检查再处理。

## 宽屏与文本布局

“显示设置”左侧按分辨率选择，右侧只列出该分辨率和已安装字库能容纳的 80×25／43／50 文本网格。Tab 切换控件，方向键选择。“全部模式”列出 BIOS 提供的分辨率、颜色数和不可用原因，支持 PgUp/PgDn 翻页、Home/End 跳到首尾；VBE 编号在此列表的技术信息中查看。程序从已安装字库中自动选择字号，使 80 列、指定行数及输入法栏一起尽量铺满屏幕；相同覆盖面积优先使用原生字号，避免放大小字形。主页显示所选分辨率、文本布局与单元尺寸。

安装完整字库包后，1024×768 的 80×43 使用 12×17 单元，1366×768 的 80×43 使用 17×17 单元，1920×1080 的 80×50 使用 24×21 单元。HHFONT2 的最小行高为 16；800×600 放不下 43 行加输入法栏，1366×768 放不下 50 行。只安装 HH20 时，其最小行高仍为 20。SETUP 根据实际文件检查布局，缺少合适字号时不保存无效配置。

VESA 启动时还会预载切换 25／43／50 行所需的字体。短屏不足以容纳更多行时，保留切换到更高 BIOS 物理模式的路径。预载组内存不足时，驱动可缩减为当前布局需要的字体；驻留后不通过 DOS 重新读取字库。

EDID 首选时序通常对应液晶面板的原生分辨率，但不保证显卡 BIOS 有相应模式；见 [VESA EDID 1.3 的首选时序定义](https://glenwing.github.io/docs/VESA-EEDID-A1.pdf)。SETUP 分别报告 EDID 首选尺寸、BIOS 是否提供此尺寸，以及驱动可用的模式列表。无 DDC、坏校验和、没有首选时序或隔行时序均不据此推测面板尺寸。当前读取主控制器的 EDID 基础块，不选择多屏输出，也不解析扩展块中的 DisplayID 时序。

1366 这样的宽度不需要是 8 的倍数，显存每行字节数须能容纳向上取整的像素位并满足偶数字节跨度。平面 16 色模式继续列出。带线性物理地址的 15/16/32 位模式在驱动能画的时候列入可用列表；43/50 行只在同时有可换银行的 64 KiB A000 窗口时出现。24 位色，以及没有物理地址的 32 位模式，仍记为格式不受支持。文本列数仍为 80。

## 命令行

```dos
SETUP /REPORT
SETUP /AUTO /FONT:XMS /VIDEO:102 /IME:PY /IME:WB
SETUP /AUTO /LOW /FONT:EMS /VIDEO:VGA /BYTE
SETUP /AUTO /VIDEO:NATIVE
SETUP /AUTO /VIDEO:1920x1080 /TEXT:80x50
SETUP /W
```

`/REPORT` 只输出检测结果，不生成配置。`/AUTO` 明确要求不经对话框保存；与界面使用同一套检查和保存逻辑。未指定的选项保留现有配置；没有相应配置时采用推荐值。`/FONT:` 接受 `XMS`、`EMS`、`LOW`；`/VIDEO:` 接受 `VGA`、`EGA`、`HGA`、`CGA`、十六进制 VBE 模式号（如 `102`）、`宽x高` 或 `NATIVE`。`NATIVE` 要求有可靠的 EDID 首选尺寸和驱动兼容模式，缺少任一项均不生成配置。`/TEXT:` 接受 `80x25`、`80x43`、`80x50`，生成对应的 VESA `/R:` 启动参数。`/IME:` 可重复指定 `PY`、`SW`、`DB`、`WB`，或 `NONE`。`/LOW` 强制常规驻留，`/BYTE` 关闭整字编辑。命令行错误、配置不可用或保存失败均返回非零状态。

默认使用 `SETUP.EXE` 所在目录的模块和配置。`/W` 改为使用调用时的当前目录，适合从另一目录或驱动器运行设置。

已加载 VESA 时，单独运行 `SETUP /TEXT:80x50` 即时切换文本行数；`80x43`、`80x25` 同样可用。通过标准 VGA 扫描线／ROM 字体接口执行，不重装驱动、不生成或改写文件。显示驱动无法容纳新布局时返回失败并保留原布局；更换常驻配置仍需重新启动 DOS。

报告中的 `EDID_STATUS` 为 0（不可用）、1（无效）、2（无可用首选时序）、3（有首选尺寸）；`EDID_PREFERRED` 为宽高；`EDID_BIOS_MODE` 表示 BIOS 是否报告该尺寸的受支持彩色图形模式，不代表本驱动可绘制。`VBE_MODE_XXXX=宽x高;80x25,...` 列出驱动兼容模式和已安装字库可用的文本布局，`VBE_CATALOG_TRUNCATED=1` 表示模式探测达到数量上限。`FONT_文件名=单元宽x高;字节数` 列出有效显示字库；`FONT_CATALOG_TRUNCATED=1` 表示目录中的候选字体超过 256 个。

## 构建

需要 [Open Watcom](https://github.com/open-watcom/open-watcom-v2) 的宿主平台工具链及其 UI 源码。直接在宿主机运行 `wcc`、`wlib`、`wlink`，生成 8086 实模式程序。

```sh
export WATCOM=/path/to/open-watcom
bash tools/build-setup.sh --fetch     # 首次取得上游默认分支源码
make setup                          # 使用本地源码，生成 build/SETUP.EXE
```

也可设置 `WATCOM_SOURCE` 或使用 `--watcom-source DIR` 指向自己的 Open Watcom 源码目录，离线构建。依赖不固定提交；更新源码后会自动重建 UI 库。编译选项由构建脚本传入，上游源文件保持原样。

UI 使用上游 `bld/ui` 的 DOS 控件。发布程序时附带生成的 `build/SETUP.LIC`，许可见 [Sybase Open Watcom Public License](https://github.com/open-watcom/open-watcom-v2/blob/master/license.txt)。

## 验证

配置策略、EDID 解码、模式筛选、文件备份及原 INI 保留使用主机测试；DOS 测试实际运行生成的 BAT，并检查查询前后的内存管理器状态。交互测试覆盖键盘选择、取消和保存，以及 8086 上的中英文界面。宽屏测试检查 B800 与四个显存平面，并对照实际窗口像素；MS-DOS 测试覆盖 1920×1080 下的行数切换和鼠标位置、点击回调。

```sh
python3 -m pytest qa/spec/test_setup.py qa/spec/test_setup_display.py qa/spec/test_setup_staging.py -m unit
python3 -m pytest qa/spec/test_setup.py qa/spec/test_setup_ui.py qa/spec/test_setup_legacy.py qa/spec/test_setup_widescreen.py -m dos --setup-exe build/SETUP.EXE --dosbox "$DOSBOX"
```

物理窗口测试需要 Xvfb、X11/XTest 和 ImageMagick；真实 MS-DOS 用例另传 `--msdos-image`，宽屏鼠标用例还需 `--vbmouse`。DOSBox-X 高清模式使用可选的 `qa/profiles/vesa-hd.conf`。该 BIOS 没有 1366×768，测试覆盖其解码和布局边界；EDID DOS 用例由探针提供 DDC 数据，其余模式与绘制使用模拟器原 BIOS，不能替代真实笔记本的 DDC 实测。

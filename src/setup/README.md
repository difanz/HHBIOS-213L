# SETUP.EXE

独立的 DOS Open Watcom UI 安装程序。检测机器和可用模块，选择字库存储、程序驻留、显示驱动、文本布局和输入法，预览并生成 `HHBIOS.BAT` 与 `213L.INI`。安装程序不加载 TSR，不修改 `CONFIG.SYS` 或 `AUTOEXEC.BAT`。

将 `SETUP.EXE` 放到 HHBIOS 安装目录，与 COM 模块、`HZK16`、输入码表放在一起。VESA 还需要 `HH20.FNT`。使用 DOS 短目录名，完整路径最多 32 字节，以适应原有字库加载器的路径缓冲区。

```dos
SETUP
HHBIOS.BAT
```

先在未加载 HHBIOS 的 DOS 会话中运行设置。退出设置后再执行生成的批处理。更换常驻配置前应重新启动 DOS。界面支持键盘和已有的 INT 33h 鼠标驱动：Tab 切换控件，方向键选择，空格切换复选框，F2 查看检测结果，F3 预览，Alt-X 退出。

## 中文与旧机器

程序为 **16 位实模式 EXE**，不需要 DPMI、XMS、EMS 或 HHBIOS 常驻接口。中文界面使用 VGA 640×480，逻辑网格为 80×30；西文采用 VGA ROM 8×16 点阵，中文直接读取 `HZK16` 的 16×16 点阵。整套字库放在进程的常规内存中，退出时释放。源代码字符串使用 UTF-8，构建时转换为 GB2312。

Open Watcom UI 仍管理窗口、对话框、焦点和控件；安装程序将其字符缓冲区绘制到 VGA。中文双字节在交给 Open Watcom UI 前使用私有显示编码，避免把 CP437 框线误识别为汉字。此编码仅存在于界面缓冲区，配置文件仍使用原有格式。

`SETUP /EN` 使用英文文本界面；`SETUP /ZH` 要求中文界面。默认在 VGA、字库及空闲内存满足条件时显示中文，否则使用英文。CGA、EGA、MDA 的设置界面使用英文文本模式；Hercules 驱动需手动选择，不能仅根据单色设备标志推断。程序按 8086 指令集构建；中文显示是否可用由显卡和内存决定，并非由是否为 PC/XT 决定。

## 检测与推荐

- CPU 的 FLAGS 行为类别、DOS 版本、常规内存、安装程序退出后的最大连续空闲块估计。
- DOS UMB 最大空闲块；查询后恢复分配策略和 UMB 链接状态。
- XMS 版本、最大空闲块与总量；EMS 版本、页框和空闲页数；只查询 DPMI 主机，不进入保护模式。
- BIOS 显示适配器、VBE 版本及 BIOS 模式列表，最多读取 512 项并保留 64 个兼容模式。模式筛选与 VESA 驱动共用布局检查函数。银行切换和 B800 隔离仍由 VESA 驱动加载时验证。
- VBE/DDC `4F15h` 返回的 EDID 基础块：校验头、版本、校验和及首选详细时序，报告屏幕首选尺寸。兼容时优先推荐此模式，否则保留默认显示方案。
- 所需 COM、字库及输入码表是否存在。推荐先选择 XMS、EMS，最后才用常规内存；VESA 会同时计入普通字库和 VESA 字库的需求。

UMB 默认由各模块自行尝试，不额外使用 `LOADHIGH`。强制常规内存只给支持的模块传 `/N`；`READ2` 和 `WBX` 本身使用常规内存。区位输入由 CKBD 提供；拼音／双拼、首尾、电报分别使用 `PYMB`、`SWMB`、`DBMB`，五笔加载 `WBX.COM`。保留原 INI 的快捷键、颜色、词组参数与注释，只更新三个码表开关。

保存先写临时文件，再保留原件为 `HHBIOS.BAK`、`213L.BAK`；已有备份不会被覆盖。写入失败时尝试恢复原件。DOS 不提供跨两个文件的事务，断电后的临时文件和备份应先检查再处理。

## 宽屏与文本布局

“显示设置”分别选择物理分辨率和 80×25／43／50 文本网格，Tab 切换控件，方向键选择。列表包含显卡实际提供的兼容 VBE 模式及其十六进制编号。文本区与输入法栏必须一起放得下：默认 HH20 点阵最小行高为 20，43 行需 880 像素高，50 行需 1020 像素高。因此 1280×720、1280×800、1366×768 不能直接搭配 43／50 行；这些布局需要更高的物理模式。SETUP 保存配置时会检查这一条件。

EDID 首选时序通常对应液晶面板的原生分辨率，但不保证显卡 BIOS 有相应模式；见 [VESA EDID 1.3 的首选时序定义](https://glenwing.github.io/docs/VESA-EEDID-A1.pdf)。SETUP 分别报告 EDID 首选尺寸、BIOS 是否提供此尺寸，以及驱动可用的模式列表。无 DDC、坏校验和、没有首选时序或隔行时序均不据此推测面板尺寸。当前读取主控制器的 EDID 基础块，不选择多屏输出，也不解析扩展块中的 DisplayID 时序。

1366 这样的宽度不需要是 8 的倍数，显存每行字节数须能容纳向上取整的像素位并满足 VGA 偶数字节跨度。当前后端仍要求 VGA 兼容的 4 位平面模式；探测到 1920×1080 的 32 位模式不会将它当作可用的 16 色模式。此阶段文本列数仍为 80。

## 命令行

```dos
SETUP /REPORT
SETUP /AUTO /FONT:XMS /VIDEO:102 /IME:PY /IME:WB
SETUP /AUTO /LOW /FONT:EMS /VIDEO:VGA /BYTE
SETUP /AUTO /VIDEO:NATIVE
SETUP /AUTO /VIDEO:1920x1080 /TEXT:80x50
```

`/REPORT` 只输出检测结果，不生成配置。`/AUTO` 明确要求不经对话框保存；与界面使用同一套检查和保存逻辑。未指定的选项采用推荐值。`/FONT:` 接受 `XMS`、`EMS`、`LOW`；`/VIDEO:` 接受 `VGA`、`EGA`、`HGA`、`CGA`、十六进制 VBE 模式号（如 `102`）、`宽x高` 或 `NATIVE`。`NATIVE` 要求有可靠的 EDID 首选尺寸和驱动兼容模式，缺少任一项均不生成配置。`/TEXT:` 接受 `80x25`、`80x43`、`80x50`，生成对应的 VESA `/R:` 启动参数。`/IME:` 可重复指定 `PY`、`SW`、`DB`、`WB`，或 `NONE`。`/LOW` 强制常规驻留，`/BYTE` 关闭整字编辑。命令行错误、配置不可用或保存失败均返回非零状态。

已加载 VESA 时，单独运行 `SETUP /TEXT:80x50` 即时切换文本行数；`80x43`、`80x25` 同样可用。通过标准 VGA 扫描线／ROM 字体接口执行，不重装驱动、不生成或改写文件。显示驱动无法容纳新布局时返回失败并保留原布局；更换常驻配置仍需重新启动 DOS。

报告中的 `EDID_STATUS` 为 0（不可用）、1（无效）、2（无可用首选时序）、3（有首选尺寸）；`EDID_PREFERRED` 为宽高；`EDID_BIOS_MODE` 表示 BIOS 是否报告该尺寸的受支持彩色图形模式，不代表本驱动可绘制。`VBE_MODE_XXXX=宽x高;80x25,...` 列出驱动兼容模式和可用文本布局，`VBE_CATALOG_TRUNCATED=1` 表示探测达到数量上限。

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
python3 -m pytest qa/spec/test_setup.py qa/spec/test_setup_display.py -m unit
python3 -m pytest qa/spec/test_setup.py qa/spec/test_setup_ui.py qa/spec/test_setup_widescreen.py -m dos --setup-exe build/SETUP.EXE --dosbox "$DOSBOX"
```

物理窗口测试需要 Xvfb、X11/XTest 和 ImageMagick；真实 MS-DOS 用例另传 `--msdos-image`，宽屏鼠标用例还需 `--vbmouse`。DOSBox-X 高清模式使用可选的 `qa/profiles/vesa-hd.conf`。该 BIOS 没有 1366×768，测试覆盖其解码和布局边界；EDID DOS 用例由探针提供 DDC 数据，其余模式与绘制使用模拟器原 BIOS，不能替代真实笔记本的 DDC 实测。

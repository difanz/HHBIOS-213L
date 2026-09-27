# HHBIOS 2.13L

CCDOS 2.13L（HHBIOS）源码，包含原有汇编模块和独立的 VESA 显示驱动。`make` 将 `src/` 编成 `build/*.COM`。

## 编译

汇编器是 [JWasm 2.21](https://github.com/Baron-von-Riedesel/JWasm)，提交 `7f6f32e78b79565d40bcce496756aadd1ff66900`，再打上 `tools/jwasm-m510.patch`。补丁让 `-Zm` 按 MASM 5.1 处理向前跳转的填充和 `AX` 立即数。

```bash
git clone https://github.com/Baron-von-Riedesel/JWasm.git
cd JWasm
git checkout 7f6f32e78b79565d40bcce496756aadd1ff66900
git apply /path/to/HHBIOS-213L/tools/jwasm-m510.patch
make -f GccUnix.mak
export PATH="$PWD/build/GccUnixR:$PATH"
```

`CKBD`、`VGA`、`EGA`、`HGA` 和 `VESA` 使用 [Open Watcom](https://openwatcom.org/) 的 16 位 C 编译器 `wcc` 和链接器 `wlink`。将它们加入 `PATH`，或设置 `WATCOM` 为工具链目录。回到本仓库：

```bash
make          # 汇编模块及独立的 VESA.COM
make check    # 每个模块都生成了 COM
make variants # build/8086、build/386、build/586
make clean
```

尚未迁移到 C 的模块可以单独汇编，例如 `make build/READ4.COM`：

```text
jwasm -q -Zm -bin -Isrc/common -Isrc/font -Fo=build/READ4.COM src/font/READ4.ASM
```

构建脚本从各模块目录读入 `INCLUDE` 文件。`R16.COM` 由 `tools/joinr16.py` 把 `READ3` 到 `READ6` 接在桩后面。`PMZB.ASM` 和 `INT10V.ASM` 汇编时会提示 `A4073`，操作数按字处理。

`make CPU=386 BUILD=build/386` 为公共 C 模块选择 386 代码生成；`CPU=586` 选择 Pentium 调优。默认 `CPU=8086` 保留基本键盘及传统显卡路径的 8086 支持，`VESA.COM` 在所有目录中都至少要求 386。各目录保留原来的 DOS 文件名，可直接配合相同的安装配置使用；需要并存时也可将 `build/386/CKBD.COM` 改名为 `CKBD386.COM`。

CPU 目标只改变实际编译的代码。纯汇编模块可能完全相同，WCC 的 386 与 Pentium 调优也可能得到相同机器码。当前没有 MMX/SSE 变体；增加这类实现时，还需要处理中断中的 FPU/SIMD 状态保存以及 DOS host 对相应指令的支持。

## 编码

`src/` 里的 `.ASM`、`.INC` 是 GB2312/GBK。按字节编辑，别另存成 UTF-8。
小写的 `vesa.c`、`vesa.h`、`vesa.asm` 使用 ASCII。

## 安装设置

`SETUP.EXE` 使用 Open Watcom UI 检测机器能力，选择字库存储、驻留方式、显示驱动和输入法，预览并生成 `HHBIOS.BAT`、`213L.INI`。它独立于 HHBIOS 运行；VGA 中文界面直接加载 `HZK16`，旧显卡可用英文文本界面。运行方法及可选构建目标 `make setup` 见 [安装程序说明](src/setup/README.md)。

## VESA 显示

`VESA.COM` 使用 VGA 兼容的 VBE **800×600、16 色**模式，保持 80×25 字符网格和输入法提示行。先装字库和键盘模块，再装显示驱动，例如：

```text
READ5
CKBD /E
VESA
```

将 `fonts/HH20.FNT` 放在 DOS 当前目录。中文采用 GNU Unifont 原生 16×16 点阵，在 20×23 字格中居中留白，不拉伸笔画；西文和常用框线采用 Terminus 10×20 点阵，单字节字符单元为 10×23 像素。简繁字形共享去重后的数据，字体、应用下载字形及文本模式切换备份共使用 752 KiB XMS；没有可用 XMS 时使用 EMS 4.0（47 页）。驱动只常驻 16 个字形的缓存。字体来源、开放许可及重建方法见 [字库说明](fonts/README.md)。原有字库读取模块仍为兼容的 16 像素取字接口提供服务。

输入法状态栏位于应用文本区下方，不占用应用的最后一行。加载 CKBD 并启用“保持提示行”时，驱动安装后自动显示状态栏；已打开的提示行文字和点阵标志随文本行数切换、图形模式返回而恢复。关闭提示行后，普通刷新保持它隐藏。

每次只加载一个显示驱动；`VESA` 与 `VGA`、`EGA`、`HGA` 分别使用。`VESA /N` 强制驻留常规内存，默认优先使用 DOS UMB。VESA 使用 386 指令集，仍为 16 位实模式 COM，不依赖 DOS extender、DPMI 或 unreal mode。需要 386 以上 CPU、可用的 VGA 兼容 VBE 模式及 B800 映射；不满足条件时拒绝安装。SETUP 和基本 VGA 路径保留 8086 支持。

`VESA /M:104` 可选择 BIOS 提供的 1024×768×16 模式，`VESA /M:106` 可选择 1280×1024×16；`/M:` 后为十六进制 VBE 模式号。其他分辨率按 BIOS 实际提供的模式选择，宽屏模式号不能跨显卡照搬。默认仍为 800×600。

SETUP 的“显示设置”列出 BIOS 提供且驱动可用的分辨率，包括兼容的 1280×720、1280×800、1366×768、1920×1080 等宽屏模式，并可选择 80×25、80×43、80×50 文本网格。屏幕首选分辨率通过 VBE/DDC 读取 EDID；检测不到或 BIOS 未提供兼容模式时会明确提示。`SETUP /AUTO /VIDEO:NATIVE` 按屏幕首选模式生成配置，`SETUP /AUTO /VIDEO:1920x1080 /TEXT:80x50` 指定物理分辨率和文本布局。当前仍需要 VGA 兼容的 16 色平面模式；只有高彩色或 LFB 模式的显卡尚不能以原生分辨率运行本驱动。

`VESA /M:106 /F:HH32.FNT` 可选择更大的字体。`tools/build-font.py` 将 Linux 上指定的开源点阵／矢量字体按字号导出，支持半角 8–24 像素宽、16–64 像素行高；中文占两个字格。鼠标、光标和输入法栏采用同一尺寸，B800 的字符布局保持不变。用法见[可变字号](fonts/README.md#variable-sizes-from-linux-fonts)。

物理分辨率与文本行数独立。软件可通过标准 VGA 扫描线／ROM 字体接口选择 80×43、80×50，也可返回 80×25；B800、BIOS、中文边界查询和鼠标坐标使用同一套逻辑行数。25 行使用八个 4 KiB 页，超过 25 行使用四个 8 KiB 页。若当前物理模式放不下完整点阵，驱动会尝试 BIOS 提供的 1024×768、1280×1024 模式；没有合适模式时保留原布局。

`VESA /M:106 /R:50` 在安装时选择 80×50。加载 VESA 后，可用 `SETUP /TEXT:80x43`、`SETUP /TEXT:80x50` 或 `SETUP /TEXT:80x25` 即时切换；这个命令不重装常驻模块，也不保存配置文件。使用默认 HH20 字体时，43／50 行分别需要至少 880／1020 像素高，包含独立的输入法栏。

鼠标使用已有 INT 33h 驱动，应用仍按每字符 8×8 坐标单位操作；显示驱动处理居中和缩放后的坐标换算，并直接绘制文本指针，不修改 B800 字节。应先加载鼠标驱动，再加载 `VESA`。驱动保留完整点阵，只按整数倍放大或省去额外行距。132 列、VBE 文本模式 108h–10Ch、高彩色和 LFB 后端尚未启用；传统 `VGA.COM` 仍为 80×25。接口、显示页及兼容边界见 [VBE 说明](qa/VBE-RULES.md)。

## 内存使用

`R16` 自动选择字库存储方式；有 XMS 时可直接使用 `READ5`，有 EMS 时可使用 `READ4`，`READ2` 将字库保存在常规内存。`READ4`、`READ5` 未指定第二套字库或重复指定同一套时共用一份存储；`JF`、`FJ` 分别加载简、繁两套字库。

`R16` 的自动检测以单套 256 KiB 字库为容量门槛；XMS 检查最大连续空闲块，EMS 检查空闲页数。两套字库需要额外空间；`READ4` 固定为每套分配 16 页，字库文件不能超过 256 KiB。`READ2` 和 `READ6` 在字库加载完成后释放不再使用的 DOS 环境块。

`READ4` 在装载和取字后恢复调用者的 EMS 页映射。`READ6` 直接使用未受管理的扩展内存，遇到已有 XMS、EMS 或 DPMI host 会拒绝加载；也不能在加载它后再启动内存管理器、DOS extender 或 Windows。此类环境应使用 `READ4` 或 `READ5`。各 extender 的测试方式及 Windows 95 的核查范围见 [内存兼容性](qa/MEMORY-COMPAT.md)。

支持 UMB 的驻留模块通过 DOS 的内存管理接口申请高位内存，不要求存在 XMS 接口。需要 DOS 5 或更新版本及可用的 DOS UMB；没有可用 UMB 时仍驻留常规内存。支持 `/N` 的模块可用该参数强制驻留常规内存。

`CKBD` 自动将拼音、首尾和电报码表保存在 XMS，通过 1 KiB 驻留缓存查表。拼音、首尾的首码索引和双拼二字词的查询索引也保存在 XMS，复用同一缓存；索引无法建立时使用原扫描方式。没有 XMS 或码表初始化失败时，码表仍随模块驻留；`CKBD /C` 可强制采用此方式。`/N` 只决定模块驻留位置，不禁用 XMS 码表。可编辑的双拼词库 `SPCZ.DAT` 和预选表仍随模块驻留。完整卸载会释放码表、索引、显示字库以及模块占用的 DOS/UMB 内存。

## 显示逻辑与测试

直接写屏路径通过纵向扫描、连续字符和邻格笔画识别 CP437 框线，并用转换表中的代码标记已识别的框线。显示时按行用 FSM 配对 GB2312 字节；内容变化会重绘受影响的行，模式切换会刷新画面。规则、歧义和兼容边界见 [混排规则](qa/DISPLAY-RULES.md)。

VBE 应用成功设置模式后，`VGA`、`VESA` 暂停各自的中文绘制，失败时保留原显示状态。通过传统 BIOS 模式 3 返回时恢复中文显示。`VESA` 还支持 VBE 文本模式回切和带有驱动状态记录的 VBE 状态保存、恢复。

`CKBD /E` 为使用 BIOS 键盘接口的逐字节编辑器启用整字移动和删除；`CKBD /B` 恢复默认的逐字节操作，适用于十六进制编辑。两条命令也能切换已驻留的 CKBD。需要配套的 VGA/EGA/HGA/VESA 驱动和直接写屏中文模式。处理流程、应用范围及限制见 [键盘规则](qa/KEYBOARD-RULES.md)。

测试使用 pytest，覆盖真实 16 位汇编执行、DOSBox 显存与像素、真实编辑器中的中文混排和保存结果。运行前需安装所选测试层的依赖；工具位置通过 `PATH`、环境变量或参数指定。

```sh
make qa-test         # 汇编行为与测试传输层
make qa-dos          # DOSBox 驻留模块、VGA 四平面像素及 API
make qa-application  # tvedit 混排、编辑；可配置其他应用样本
make qa-all          # 全部必需测试层
make qa-mutate       # 验证测试能捕获故意引入的汇编错误
```

依赖安装、运行方式、失败诊断和测试范围见 [测试说明](qa/README.md)。每次运行使用独立目录，保存测试报告和调试数据。

交互测试环境由 `bash qa/prepare.sh` 从本地安装介质和应用样本准备，启动真正的 MS-DOS 6.22，并包含完整 2.13L 发行文件、当前模块和 QA 工具。参数与启动方法见 [MS-DOS 环境说明](qa/README.md#interactive-ms-dos-environment)。

`fonts/HZK16` 是原盘标签 `original-import` 中 `H16F.EXE` 的 ARJ 成员 `HZK16F`，261696 字节。中文像素期望直接从该字库读取。Open Watcom 用于编译 VESA 驱动和 DOS 探针。

## 目录

- `src/common/`：C 框线判断、文本编辑校验，以及汇编调用和驻留接口
- `src/video/`：传统显卡驱动；`vesa/` 为 VESA 的 C/汇编实现
- `src/input/`：键盘、输入法、码表查询和整字编辑
- `src/font/`：字库加载模块与原有点阵数据
- `src/printer/`：打印驱动；`src/commands/`：独立命令与工具
- `src/setup/`：硬件检测和安装配置程序
- `fonts/`：原有 `HZK16`、VESA 用的 `HH20.FNT`、字体许可和来源记录
- `qa/`：`spec/` 测试、`harness/` 客机探针、测试运行与变异工具
- `tools/`：JWasm 补丁、拼接 `R16` 的脚本、`make check`、Watcom 编 COM
- `build/`：`make` 写出的 COM，已在 `.gitignore` 里

原盘文件保存在 `original-import` 标签中。

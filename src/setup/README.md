# SETUP.EXE

独立的 DOS Turbo Vision 安装程序。检测机器和可用模块，选择字库存储、程序驻留、显示驱动和输入法，预览并生成 `HHBIOS.BAT` 与 `213L.INI`。安装程序不加载 TSR，不修改 `CONFIG.SYS` 或 `AUTOEXEC.BAT`。

将 `SETUP.EXE` 放到 HHBIOS 安装目录，与 COM 模块、`HZK16`、输入码表放在一起。VESA 还需要 `HH20.FNT`。使用 DOS 短目录名，完整路径最多 32 字节，以适应原有字库加载器的路径缓冲区。

```dos
SETUP
HHBIOS.BAT
```

先在未加载 HHBIOS 的 DOS 会话中运行设置。退出设置后再执行生成的批处理。更换常驻配置前应重新启动 DOS。界面支持键盘和已有的 INT 33h 鼠标驱动：Tab 切换控件，方向键选择，空格切换复选框，F2 查看检测结果，F3 预览，Alt-X 退出。

## 中文与旧机器

程序为 **16 位实模式 EXE**，不需要 DPMI、XMS、EMS 或 HHBIOS 常驻接口。中文界面使用 VGA 640×480，逻辑网格为 80×30；西文采用 VGA ROM 8×16 点阵，中文直接读取 `HZK16` 的 16×16 点阵。整套字库放在进程的常规内存中，退出时释放。源代码字符串使用 UTF-8，构建时转换为 GB2312。

Turbo Vision 仍管理窗口、对话框、焦点和控件；安装程序将其字符缓冲区绘制到 VGA。中文双字节在交给 Turbo Vision 前使用私有显示编码，避免把 CP437 框线误识别为汉字。此编码仅存在于界面缓冲区，配置文件仍使用原有格式。

`SETUP /EN` 使用英文文本界面；`SETUP /ZH` 要求中文界面。默认在 VGA、字库及空闲内存满足条件时显示中文，否则使用英文。CGA、EGA、MDA 的设置界面使用英文文本模式；Hercules 驱动需手动选择，不能仅根据单色设备标志推断。程序按 8086 指令集构建；中文显示是否可用由显卡和内存决定，并非由是否为 PC/XT 决定。

## 检测与推荐

- CPU 的 FLAGS 行为类别、DOS 版本、常规内存、安装程序退出后的最大连续空闲块估计。
- DOS UMB 最大空闲块；查询后恢复分配策略和 UMB 链接状态。
- XMS 版本、最大空闲块与总量；EMS 版本、页框和空闲页数；只查询 DPMI 主机，不进入保护模式。
- BIOS 显示适配器、VBE 版本及 102h／104h／106h 平面模式。模式筛选与 VESA 驱动共用布局检查函数。银行切换和 B800 隔离仍由 VESA 驱动加载时验证。
- 所需 COM、字库及输入码表是否存在。推荐先选择 XMS、EMS，最后才用常规内存；VESA 会同时计入普通字库和 VESA 字库的需求。

UMB 默认由各模块自行尝试，不额外使用 `LOADHIGH`。强制常规内存只给支持的模块传 `/N`；`READ2` 和 `WBX` 本身使用常规内存。区位输入由 CKBD 提供；拼音／双拼、首尾、电报分别使用 `PYMB`、`SWMB`、`DBMB`，五笔加载 `WBX.COM`。保留原 INI 的快捷键、颜色、词组参数与注释，只更新三个码表开关。

保存先写临时文件，再保留原件为 `HHBIOS.BAK`、`213L.BAK`；已有备份不会被覆盖。写入失败时尝试恢复原件。DOS 不提供跨两个文件的事务，断电后的临时文件和备份应先检查再处理。

## 命令行

```dos
SETUP /REPORT
SETUP /AUTO /FONT:XMS /VIDEO:102 /IME:PY /IME:WB
SETUP /AUTO /LOW /FONT:EMS /VIDEO:VGA /BYTE
```

`/REPORT` 只输出检测结果，不生成配置。`/AUTO` 明确要求不经对话框保存；与界面使用同一套检查和保存逻辑。未指定的选项采用推荐值。`/FONT:` 接受 `XMS`、`EMS`、`LOW`；`/VIDEO:` 接受 `VGA`、`102`、`104`、`106`、`EGA`、`HGA`、`CGA`；`/IME:` 可重复指定 `PY`、`SW`、`DB`、`WB`，或 `NONE`。`/LOW` 强制常规驻留，`/BYTE` 关闭整字编辑。命令行错误、配置不可用或保存失败均返回非零状态。

## 构建

需要开发者自行提供 **Borland C++ 3.1、Turbo Assembler**，以及可运行 DOS 编译器的 DOSBox。没有捆绑编译器。普通的 COM/VESA 构建不受此可选目标影响。

Turbo Vision 使用上游历史中的公开 **2.0** 源码，固定提交 [`222c5042bd4ffd0ac8fb673c680d0d9301a2ab23`](https://github.com/magiblot/tvision/tree/222c5042bd4ffd0ac8fb673c680d0d9301a2ab23)。构建脚本仅对 BC++ 3.1 不支持的数组分配重载、重复的 signed-char 流重载作条件适配；库按原有对象列表编译。编译器和库保存在外部路径或忽略的缓存中。

```sh
export BORLAND_DIR=/path/to/borland-cpp-3.1
export DOSBOX=/path/to/dosbox
bash tools/build-setup.sh --fetch     # 显式下载固定版本并构建
make setup                          # 后续使用缓存，生成 build/SETUP.EXE
```

也可设置 `TVISION_DIR` 指向自行取得的同一份源码，完全离线构建。构建时所有 DOS 路径都映射到固定客机盘符，不把开发者的宿主路径写入 EXE 或生成的 BAT。发布 Turbo Vision 派生程序时保留上游 [Borland 声明](https://github.com/magiblot/tvision/blob/master/COPYRIGHT)。

## 验证

配置策略、文件备份及原 INI 保留使用主机测试；DOS 测试实际运行生成的 BAT，并检查查询前后的内存管理器状态。可选的 Borland 构建通过参数提供，不要求普通显示驱动测试安装 Borland。

```sh
python3 -m pytest qa/spec/test_setup.py -m unit
python3 -m pytest qa/spec/test_setup.py -m dos --setup-exe build/SETUP.EXE --dosbox "$DOSBOX"
```

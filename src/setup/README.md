# SETUP.EXE

独立的 DOS Open Watcom UI 安装程序。检测机器和可用模块，选择字库存储、程序驻留、显示驱动和输入法，预览并生成 `HHBIOS.BAT` 与 `213L.INI`。安装程序不加载 TSR，不修改 `CONFIG.SYS` 或 `AUTOEXEC.BAT`。

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

需要 [Open Watcom](https://github.com/open-watcom/open-watcom-v2) 的宿主平台工具链及其 UI 源码。直接在宿主机运行 `wcc`、`wlib`、`wlink`，生成 8086 实模式程序。

```sh
export WATCOM=/path/to/open-watcom
bash tools/build-setup.sh --fetch     # 首次取得上游默认分支源码
make setup                          # 使用本地源码，生成 build/SETUP.EXE
```

也可设置 `WATCOM_SOURCE` 或使用 `--watcom-source DIR` 指向自己的 Open Watcom 源码目录，离线构建。依赖不固定提交；更新源码后会自动重建 UI 库。编译选项由构建脚本传入，上游源文件保持原样。

UI 使用上游 `bld/ui` 的 DOS 控件。发布程序时附带生成的 `build/SETUP.LIC`，许可见 [Sybase Open Watcom Public License](https://github.com/open-watcom/open-watcom-v2/blob/master/license.txt)。

## 验证

配置策略、文件备份及原 INI 保留使用主机测试；DOS 测试实际运行生成的 BAT，并检查查询前后的内存管理器状态。交互测试覆盖键盘选择、取消和保存，以及 8086 上的中英文界面。

```sh
python3 -m pytest qa/spec/test_setup.py -m unit
python3 -m pytest qa/spec/test_setup.py qa/spec/test_setup_ui.py -m dos --setup-exe build/SETUP.EXE --dosbox "$DOSBOX"
```

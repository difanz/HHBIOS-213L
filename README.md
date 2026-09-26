# HHBIOS 2.13L

CCDOS 2.13L（HHBIOS）的汇编源码。`make` 用打过补丁的 JWasm 把 `src/` 编成 `build/*.COM`。

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

回到本仓库：

```bash
make          # src/*.ASM → build/*.COM
make check    # 每个模块都生成了 COM
make clean
```

单个文件：

```text
jwasm -q -Zm -bin -Isrc -Fo=build/FOO.COM src/FOO.ASM
```

`INCLUDE` 从 `src/` 读入包含文件。`R16.COM` 由 `tools/joinr16.py` 把 `READ3` 到 `READ6` 接在桩后面。`PMZB.ASM` 和 `INT10V.ASM` 汇编时会提示 `A4073`，操作数按字处理。

## 编码

`src/` 里的 `.ASM`、`.INC` 是 GB2312/GBK。按字节编辑，别另存成 UTF-8。

## 内存使用

`R16` 自动选择字库存储方式；有 XMS 时可直接使用 `READ5`，有 EMS 时可使用 `READ4`，`READ2` 将字库保存在常规内存。`READ4`、`READ5` 未指定第二套字库或重复指定同一套时共用一份存储；`JF`、`FJ` 分别加载简、繁两套字库。

支持 UMB 的驻留模块通过 DOS 的内存管理接口申请高位内存，不要求存在 XMS 接口。需要 DOS 5 或更新版本及可用的 DOS UMB；没有可用 UMB 时仍驻留常规内存。支持 `/N` 的模块可用该参数强制驻留常规内存。

## 显示逻辑与测试

直接写屏路径通过纵向扫描、连续字符和邻格笔画识别 CP437 框线，并用转换表中的代码标记已识别的框线。显示时按行用 FSM 配对 GB2312 字节；内容变化会重绘受影响的行，模式切换会刷新画面。规则、歧义和兼容边界见 [混排规则](qa/DISPLAY-RULES.md)。

`CKBD /E` 为使用 BIOS 键盘接口的逐字节编辑器启用整字移动和删除；`CKBD /B` 恢复默认的逐字节操作，适用于十六进制编辑。两条命令也能切换已驻留的 CKBD。需要配套的 VGA/EGA/HGA 驱动和直接写屏中文模式。处理流程、应用范围及限制见 [键盘规则](qa/KEYBOARD-RULES.md)。

测试使用 pytest，覆盖真实 16 位汇编执行、DOSBox 显存与像素、真实编辑器中的中文混排和保存结果。运行前需安装所选测试层的依赖；工具位置通过 `PATH`、环境变量或参数指定。

```sh
make qa-test         # 汇编行为与测试传输层
make qa-dos          # DOSBox 驻留模块、VGA 四平面像素及 API
make qa-application  # tvedit 混排、编辑；可配置其他应用样本
make qa-all          # 全部必需测试层
make qa-mutate       # 验证测试能捕获故意引入的汇编错误
```

依赖安装、运行方式、失败诊断和测试范围见 [测试说明](qa/README.md)。每次运行使用独立目录，保存测试报告和调试数据。

`fonts/HZK16` 是原盘标签 `original-import` 中 `H16F.EXE` 的 ARJ 成员 `HZK16F`，261696 字节。中文像素期望直接从该字库读取。Open Watcom 用于编译 DOS 探针；`make` / `make check` 编译汇编模块。

## 目录

- `src/`：汇编源码和包含文件
- `fonts/`：字库，`HZK16` 在版本库里
- `qa/`：`spec/` 测试、`harness/` 客机探针、`tests/` 辅助用例及其 C 探针、测试运行与变异工具
- `tools/`：JWasm 补丁、拼接 `R16` 的脚本、`make check`、Watcom 编 COM
- `build/`：`make` 写出的 COM，已在 `.gitignore` 里

原盘文件保存在 `original-import` 标签中。

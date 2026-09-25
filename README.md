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
sudo cp build/GccUnixR/jwasm /usr/local/bin/jwasm
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

## DOSBox-X 与 VBEPROBE

显示现在走 `VGA.COM` 的 VGA 12h 平面模式。`qa/` 这一步只在 DOSBox-X 里跑探针 `VBEPROBE.COM`，确认 VBE 在。字库、FreeDOS 底盘、整套 HHBIOS 启动以后再接。

版本钉在 `qa/DOSBOX_X_VERSION`（发布标签 `dosbox-x-v2026.08.31`）。该标签的 Linux x86_64 官方二进制是同一次 `linux.yml` 构建产物，脚本下到 `qa/.cache/`。下载要用已登录的 `gh`，或环境变量 `GITHUB_TOKEN`。

```bash
bash qa/fetch-dosbox-x.sh
```

`src/c/vbeprobe.c` 用 Open Watcom v2 编成 16 位 DOS COM。从 [Open Watcom v2](https://github.com/open-watcom/open-watcom-v2/releases) 装 Linux x64 的 C 编译器（`open-watcom-2_0-c-linux-x64`）。装好后：

```bash
export WATCOM=/path/to/watcom
. "$WATCOM/owsetenv.sh"
make vbeprobe
```

`ow-snapshot.tar.xz` 里也有 `binl64` 和 `lib286`，把 `WATCOM` 指到解开的目录同样可以。`make` 和 `make check` 仍然只编 `src/*.ASM`。没找到 `wcl` 时，只有 `make vbeprobe` 会停下来并说明怎么装。

```bash
make qa-smoke
```

没设置 `DISPLAY` 时用 `xvfb-run`。日志在 `qa/out/vbeprobe.log`，里面有 `signature=VESA`、`lfb=yes` 和 `VBEPROBE_OK` 即通过。这份 DOSBox-X 还依赖宿主上的 SDL2_net、libpcap、libslirp、FluidSynth、ncurses；缺了 `qa/smoke.sh` 会把 `ldd` 列出来。

`qa/dosbox-x-vga.conf` 用 `machine=vgaonly`，留给以后的 VGA 12h。`qa/dosbox-x-vbe.conf` 用 `machine=svga_s3`（带线性帧缓冲）。银行切换用 `machine=vesa_nolfb`。

## 目录

- `src/`：汇编源码和包含文件
- `src/c/`：Open Watcom C（`VBEPROBE`）
- `qa/`：DOSBox-X 配置、下载脚本、冒烟
- `tools/`：JWasm 补丁、拼接 `R16` 的脚本、`make check`、编 `VBEPROBE`
- `build/`：`make` 写出的 COM，已在 `.gitignore` 里

原盘用标签 `original-import` 查看。`v0.1.0` 是当前源码树。

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
make qa-smoke         # 只跑 qa/tests/vbeprobe
make qa-test          # qa/tests/ 下的接口用例
make qa-smoke-usage   # qa/smoke-usage/ 的使用冒烟
```

没设置 `DISPLAY` 时用 `xvfb-run`。`vbeprobe` 的日志在 `qa/out/vbeprobe/case.log`，里面有 `signature=VESA`、`lfb=yes` 和 `VBEPROBE_OK` 即通过。这份 DOSBox-X 还依赖宿主上的 SDL2_net、libpcap、libslirp、FluidSynth、ncurses；缺了运行脚本会把 `ldd` 列出来。

下一批是 2.13L 旧模块的边界用例，按 `qa/tests/<名字>/` 往里加，先别写 VESA 驱动。一个目录就是一条用例：

- `case.bat`：挂上测试盘之后的 DOS 命令，一行一条。运行器把每条的输出收进 `case.log`；行里已经写了 `>` 就保持原样
- `expect.txt`：日志里要出现的 ASCII 字样，一行一条（`#` 开头是注释）
- `files.txt`：从仓库根拷到测试盘的文件，例如 `build/VBEPROBE.COM`
- `prep`：进 DOS 之前在仓库根执行的命令，例如 `make vbeprobe`
- `conf`：用 `qa/` 里哪份配置，默认 `dosbox-x-vbe.conf`
- `skip`：这个文件在，用例就不跑，第一行是原因
- `keys.txt`：按键序列。一行是「延迟毫秒」再加内容。内容是 ASCII、`enter` `esc` `tab` `bksp` `space` `up` `down` `left` `right`，或 `sc:` 加四个十六进制（扫描码、ASCII）
- `guest.txt`：相对 `qa/guest/` 的路径。`prep` 先执行，可以把缓存里的程序拷进 `qa/guest/`。缺了文件就跳过，齐了就按文件名拷到测试盘
- `capture.txt`：一行 PNG 文件名。客机写 `SHOT.FLG` 后在 INT 16h 上等键。宿主对窗口发送 Host+P 截图，再送回车。图在 `qa/out/captures/`，不进版本库

交互按键走本机 TCP。DOSBox-X 把 COM1 设成 nullmodem 并在 `127.0.0.1` 上听，`qa/input/sendkeys.py` 作为客户端把 `keys.txt` 送进去。客机里的 `KEYSOCK.COM` 在 INT 1Ch 读串口，把扫描码和 ASCII 写进 BIOS 键盘缓冲 `0040:001E`。直接读 60h 端口的程序收不到这些键。换注入方式时改 `qa/input/`，`keys.txt` 保持原样。`qa/tests/keyecho` 会打出 `hi` 再回车，日志里应有 `KEYECHO_OK`。

16 点阵字库在 `fonts/HZK16`。字节来自原盘标签 `original-import` 里 `H16F.EXE` 的 ARJ 成员 `HZK16F`（261696 字节），运行时文件名用 `HZK16`。`qa/guest/` 仍不进版本库，留给以后自己放的 DOS 树。编好的 `build/*.COM` 还是从 `build/` 拷到测试盘。

字符方式汉字：`READ2.COM` 从 `HZK16` 装 INT 7Fh，`VGA.COM` 驻留并钩住 INT 10h，`CMODE 3` 把对外模式设成 3（字符方式，显存仍按 12h 画 16 点阵）。`qa/input/conout.c` 编出的 `CONOUT.COM` 把 `VIEW.TXT` 里的每个字节交给 INT 10h AH=0Eh（BL=07），字模由 `VGA.COM` 和 `HZK16` 画出。DOSBox-X 里 `TYPE > CON` 是在控制台回调里调用 INT 10h，这样写进显存的字模留不住，用例先把输出拷到 `VIEW.TXT`，再由 `CONOUT` 交给 INT 10h。

`qa/smoke-usage/cn-filename`：装好上述栈之后，`CNNAME.COM` 创建文件名，字节是 `D6 D0 CE C4`（GB2312「中文」）加 `.TXT`，然后 `DIR`。日志里要有 `CNNAME_BYTES=D6D0CEC4`。`CONOUT` 把这份目录列表打到屏幕上，截图里应能认出「中文」。

`vga-ah0f` 设 VGA 12h，用 INT 10h AH=0Fh 读模式，并核对 BIOS `0040:0049`。`cmode-query` / `cmode-set12` 跑 `CMODE.COM`：无参数时打印当前模式，参数 `12` 把模式设成 12h。`vga-help` 在字符方式栈之后跑 `VGA.COM /?`（帮助退出、本次不重复驻留），再由 `CONOUT` 把帮助送进 INT 10h。日志里有 `1999.11.23`。画面上应有「显示模块」。`vga-id` 在 `VGA.COM` 驻留后用 INT 10h AH=FFh 读回 `AX=0056h`。`vga-mode12` 只用 BIOS 设 12h，画白框并写 `MODE 12H`。

`ckbd-help` 在同一套字符方式栈之后跑 `CKBD.COM /?`，再由 `CONOUT` 送进屏幕。日志里有 `1999.11.17`，画面上应有「汉字系统键盘模块」。`ckbd-already` 装入两次，第二次打印 `CKBD IS ALREADY!`。

`tv-edit`：同一套栈之后跑 magiblot/tvision r415 的 16 位 `tvedit.exe`，打开 `TVVIEW.TXT`。第一行是 `ASCII LINE`。后两行以一个 ASCII 空格开头，接着是「喃後 Han」和「岐徵 VGA」。这四个字的 GB2312 是 `E0AB`、`E1E1`、`E1AA`、`E1E7`，落在 `B0`–`DF` 以外。窗框左边的 ║ 在 B800 里仍是 `BA`。配汉字时会向左走过每个大于 `A0` 的字节，行首空格把这条链停住，两个汉字字节配成一对。程序在 `qa/.cache/tvision/`，由 `prep` 下载并拷到 `qa/guest/`，不进版本库；下不到就跳过。画面上左边仍是 ║，四个汉字是完整的 16 点阵，同一行的 Han、VGA 还能认出。

`tv-west`：同一套栈之后，`TVWEST.COM` 只写 ASCII 和 CP437 制表符。菜单是 File、Edit、Search、Help，窗框是 ╔═╗║ 和 ┌─┐│，第 12 行在 `LINE` 后面连续放了 40 个字节 `CD`（═）。GB2312「屯」正是 `CD CD`。直接写屏若把每个高位字节都配成汉字，这一行会画成「屯屯屯」。画面上应是英文和双线、单线框。

`tv-corner`：同一套栈之后，`CORNER.COM` 在 B800 里写八个角。每个角旁边只有一格横线（双线角配 `CD`，单线角配 `C4`），另一轴是 `BA` 或 `B3`。一格横线不够四个，不会被收成低位制表符，旧逻辑会把角和横线配成汉字。现在这两格按 CP437 框线画，B800 里的字节保持原样。

`half-del`：`HDEL.COM` 先写一对非角汉字，等影子跟上，再只改其中一个字节。下一轮直接写屏扫描把另一个字节清成空格。角加横线不会被清掉，ASCII 邻格也不会。光标退格仍从键盘模块回一列；若退格落在这样一对的后字节上，显示模块把两格写成空格并把光标再退一列。

`tv-demo`：同一套栈之后跑同一发行包里的 16 位 `tvdemo.exe`，同样只放在缓存里。`KEYSOCK` 在桌面起来之后送 Alt-W，再选菜单第一项。`SHOTDLY.COM` 驻留在 INT 1Ch 上，大约九秒后写 `SHOT.FLG`。画面上应有英文菜单（File、Windows、Options）和窗框。桌面底纹是 CP437 的阴影字符。

`read2-glyph` 用 `READ2.COM` 从盘上的 `HZK16` 装 INT 7Fh，再取「中」（`D6 D0`）的前八字节 `0100010001047FFE`。`read2-unload` 调用 INT 2Fh `AX=4A06h SI=0` 卸下这组中断，之后 `SI=3` 不再返回 `BX=4A06h`。`hz-draw` 在驻留 `READ2` 和 `VGA.COM` 之后进入 12h，把「中」「文」两字按 3 倍放大画在屏幕上。

`read1-hdd` 带着跳过原因：`READ1` 用 INT 13h 读硬盘分区表，目录挂载没有 BIOS 磁盘。

带 `capture.txt` 的用例不使用 `-silent`（那个开关会走哑视频），并自建 Xvfb。截图键是 Host+P。

`qa/dosbox-x-vga.conf` 用 `machine=vgaonly`，`vga-ah0f`、`cmode`、`vga-help`、`ckbd`、`read2` 和中文文件名冒烟走这份配置。`qa/dosbox-x-vbe.conf` 用 `machine=svga_s3`（带线性帧缓冲）。银行切换用 `machine=vesa_nolfb`。

## 目录

- `src/`：汇编源码和包含文件
- `src/c/`：Open Watcom C（`VBEPROBE`、`VGA-AH0F`，以及 `qa/tests` 里的探针）
- `fonts/`：字库，`HZK16` 在版本库里
- `qa/`：DOSBox-X 配置、下载脚本、`tests/`、`smoke-usage/`、`input/`
- `tools/`：JWasm 补丁、拼接 `R16` 的脚本、`make check`、Watcom 编 COM
- `build/`：`make` 写出的 COM，已在 `.gitignore` 里

原盘用标签 `original-import` 查看。`v0.1.0` 是当前源码树。

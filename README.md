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

## 目录

- `src/`：源码和包含文件
- `tools/`：JWasm 补丁、拼接 `R16` 的脚本、`make check`
- `build/`：`make` 写出的 COM，已在 `.gitignore` 里

原盘用标签 `original-import` 查看。`v0.1.0` 是当前源码树。

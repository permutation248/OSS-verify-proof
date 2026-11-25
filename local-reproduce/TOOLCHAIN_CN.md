# 原生工具链记录

独立目录：`/home/wupeihan/projects/oss-verify-native-env`。激活：

```bash
source /home/wupeihan/projects/oss-verify-native-env/env.sh
```

OCaml、Rocq及形式化依赖原生构建；QEMU使用经校验的官方原生二进制包，全程不运行或解包任何容器。账号没有免密 sudo，使用系统已经安装的 GCC/G++、libgmp-dev、m4、pkg-config、Python 3；不修改系统软件或其他研究项目。实际程序实验使用另行独立安装的 QEMU 10.0.11（`qemu/usr/bin/qemu-riscv64`，日志 `logs/qemu-install.log`），不使用系统 QEMU 6.2。

## 固定输入

依据 oss-verify-proofs `ad0a85d4c37bc1c985ef72826a02ee33b01cbbd6` 的 `release.yaml` 和 `toolchain/checker.Dockerfile`：

- Rocq runtime/core/stdlib 9.2.0
- Dune 3.23.0
- rocq-stdpp 与 rocq-stdpp-bitvector 1.13.0
- coq-flocq 4.2.2
- rocq-read-file 0.0.2
- conf-g++ 1.0
- Rocq opam repository commit `d330865276542eb86269e88d4f3d9d4c974fee2e`
- LPS commit `c0dd863a0f8f307beca7f2ee5cb4d7686a875779`
- 官方 LPS core 文件树 SHA-256：`3c00fedfece3a07062c75c74f116ead141858da6779015d2b5633c3fc10a247f`

Dockerfile 的基础镜像选择 OCaml 4.14 系列，没有以独立包字段声明 patch 版本。本次原生环境使用 OCaml 4.14.2、原生 opam 2.6.1；opam 根目录和名为 `oss-verify-4.14` 的 switch 全新创建。系统 Ubuntu 22.04 与 Dockerfile 基础镜像 Ubuntu 24.04 不同，这里不声称复现容器镜像位级环境。

默认 opam 包索引采用现有原生环境的只读快照作为种子，解压到本目录 `deps/opam-default` 后独立使用；SHA-256 见 `logs/input-archives.sha256`。它不是从容器镜像提取的索引。关键依赖按上述明确版本安装，所有传递包的实际版本记录在 opam 清单及安装日志中。

## 文件与日志

- `env.sh`：激活独立 opam root/switch；不写 `.bashrc`。
- `install.sh`：最初实际执行的安装脚本，原样保留。
- `resume-install.sh`：修复新 switch 仓库选择后的实际续跑脚本。
- `install-repeat.sh`：可重复执行的版本；先检验 LPS 核心文件树哈希。
- `prefetch.py`：网络恢复辅助脚本，取 opam 官方缓存/codeload 归档，按包元数据校验 SHA-256 或 SHA-512 后才放入专属缓存。
- `deps/rocq-opam/released`：固定提交的 Rocq opam 索引。
- `deps/lps-full`：固定提交的依赖源码参考副本。
- `deps/lps-core`：仅官方 `lps-core.paths` 指定范围；包含 Common，排除 Examples。
- `opam-root`：专属包数据库、下载缓存、源码构建日志和 switch。
- `logs/install.log`：真实安装命令、输出及退出状态，包括首次失败与修复过程。
- `logs/prefetch*.log`：真实下载、失败及校验日志。
- `logs/host-native.txt`：主机资源和系统工具版本。
- `logs/input-archives.sha256`：输入归档哈希。

最初遇到新建 switch 只选择 default 仓库，导致 `No package named rocq-stdpp`；通过 `opam repository set-repos rocq-released default --switch=oss-verify-4.14` 修正。未修改任何上游包内容或证明。

GitHub 常规下载间歇失败时，对同一固定源码使用 codeload 或 opam 官方缓存；每个包仍由 opam 校验其原始 checksum。LPS 源树另外与 Dockerfile 锁定的树哈希逐字节核对。

## 本次实际完成结果

2026-11-24 13:06:44（Asia/Shanghai），原生安装 `INSTALL_EXIT=0`。13:06:57 原生自检 `NATIVE_SELFTEST_PASS`、`SELFTEST_EXIT=0`：LPS 的 `strong_universal_error_free_T_budgets` 和 `halts_allowed_T_scfg_budgets` 成功加载；单独的故意错误证明 `Definition bad : False := I.` 被 Rocq 拒绝，实际退出状态 1。该负例仅在本目录 `selftest/`，未写入研究项目。

- 完整实际版本：`logs/opam-installed.txt`
- 可迁移的 opam 包状态：`logs/switch.export`
- 原生自检命令、输出、状态：`logs/native-selftest.log`
- LPS 详细构建日志和真实命令：`logs/lps-build.log`、`logs/lps-build.info`

LPS 最后一个模块 `Common/WfInvariant.v` 单核编译约 15 分钟，最终成功；所有官方核心模块均原样编译，没有删模块、改规约或放宽内核检查。

# Gray Wolf 原生环境脚本快照

本目录保存 2026-11-24 在 Gray Wolf 实际使用或为该环境整理的支持脚本，以及实际安装版本记录。脚本从 `/home/wupeihan/projects/oss-verify-native-env/` 原样复制；两个历史安装脚本仅移动到 `legacy/`，没有修改内容。

这些文件依赖已经准备好的独立原生环境，**不是空白机器的一键安装器**。将它们克隆到任意目录，不会自动得到 OCaml、Rocq、Python 虚拟环境、LPS 源码、程序二进制或原始发布归档。发布目录不包含这些大型依赖、缓存和构建产物。

## 原实验的前置目录

- `/home/wupeihan/projects/oss-verify-native-env/`：独立工具链目录。多数脚本使用 `$HOME/projects/oss-verify-native-env`；QEMU 安装脚本和 Git 身份恢复辅助脚本还保留了原机器的绝对路径。
- `bin/opam`、`opam-root/`：原生 opam 2.6.1 和已初始化的独立根目录；switch 名为 `oss-verify-4.14`。
- `deps/opam-default/`、`deps/rocq-opam/released/`、`deps/lps-core/`：独立包索引与固定版本的 LPS 核心源码。
- `python-venv/bin/python`：`prepare-view.sh` 使用的已配置 Python 环境；原工作目录通过 `local-reproduce/.venv/` 符号链接访问同一环境；发布版 `local-reproduce/env.sh` 直接将独立环境的 `python-venv/bin` 加入 PATH。
- `downloads/oss-verify-proofs-ad0a85d.tar.gz`：官方固定提交的原始归档，SHA-256 为 `48c946dd504ab88a8e26e84d6103832bdd67d0d85f1cc9edfb61cc863a39631a`。准备 view 时必须存在，不能用发布仓库新增文件后的归档替代。
- `/var/tmp/wupeihan-oss-verify-reproduce/ad0a85d4/`：NVMe 上的原实验工作目录，包括完整源快照、单目标 view、facts、manifest 和构建目录。

这些前置目录均未随本快照提交。脚本中的路径、输入文件名和固定提交应结合它们的实际前置条件阅读；直接运行安装或身份恢复辅助脚本会写入其指定的原路径。

## 文件用途

| 文件 | 实际用途及前置条件 |
|---|---|
| `env.sh` | 激活已安装的独立 opam 根目录和 switch，并禁用 Dune cache。它不创建工具链。 |
| `prepare-view.sh` | 从固定官方归档生成或复核 `zlib/checksum_fuzzer` 的原生 view/facts；检查源文件、二进制与 manifest 一致性。需要上列归档、Python 环境和原始目标文件；脚本本身不编译或运行 Program。 |
| `install-repeat.sh` | 在已有 opam 程序、初始化根目录、包索引和 LPS 源码基础上重复安装固定包；安装 LPS 前核对官方源树哈希。它不下载或初始化全部前置输入。 |
| `qemu-install-native.sh` | 下载固定 Debian QEMU 用户态包，校验归档与 `qemu-riscv64` 哈希，使用 `dpkg-deb` 解压到独立目录。需要原生 Linux 的 `curl`、`dpkg-deb`、`sha256sum`、`file`；没有运行容器。 |
| `selftest.sh` | 在已安装环境中加载 LPS 定义，并确认故意错误证明 `False := I` 被 Rocq 拒绝；记录版本、包清单和 switch export。 |
| `prefetch.py` | 读取已准备的固定 opam 包元数据，从官方缓存或 codeload 预取归档，核验元数据中的 SHA-256/SHA-512 后写入独立缓存。 |
| `fast-import-upstream.py` | 原实验网络故障下的 Git 身份恢复辅助工具：读取官方源码归档及 `downloads/upstream-commit.json`，向独立 bare 仓库导入对象，并严格比较 tree、commit。需要这两个未打包的输入；它不是每日构建步骤，也不会替代证明检查。 |
| `legacy/install.sh` | 首次安装尝试的原始脚本。该次执行曾因新 switch 未选中 Rocq 包索引而失败；保留用于理解历史，不作为推荐入口。 |
| `legacy/resume-install.sh` | 当时修复 switch 仓库选择后实际续跑的脚本；同样依赖当时已准备的输入。 |

## 固定版本与身份

原实验源码提交为 `ad0a85d4c37bc1c985ef72826a02ee33b01cbbd6`，tree 为 `a36ade652af3a438ecfa227a79240b7480b00ed4`。

实际安装：OCaml 4.14.2、opam 2.6.1、Rocq runtime/core/stdlib 9.2.0、Dune 3.23.0、stdpp/bitvector 1.13.0、Flocq 4.2.2、rocq-read-file 0.0.2、QEMU 10.0.11。完整传递依赖见 [opam-installed.txt](logs/opam-installed.txt)。Dockerfile 仅作为固定依赖说明；实验采用原生 Ubuntu 22.04，未运行或解包容器镜像。

Rocq opam 索引固定到 `d330865276542eb86269e88d4f3d9d4c974fee2e`；LPS 固定到 `c0dd863a0f8f307beca7f2ee5cb4d7686a875779`，核心源树 SHA-256 为 `3c00fedfece3a07062c75c74f116ead141858da6779015d2b5633c3fc10a247f`。

`logs/switch.export` 是实际 opam 状态快照，包含指向原机 `deps/lps-core` 的本地 pin，不是包含依赖源码的便携安装包。`logs/input-archives.sha256` 保留原机的归档路径；这些路径是来源记录，不代表归档已随本仓库提供。

## 成功证据与范围

少量原始成功证据位于 [../evidence/2026-11-24/](../evidence/2026-11-24/)：官方 verify 主日志、四输入运行日志及逐输入 stdout/stderr/exit、原生自检、重复 fetch、最终环境、阶段退出状态，以及官方 `Wrapper.v`、`Defined.v` 和各自的 `assumptions.out`。

构建主日志约 42.9 MB，发布内容仅包含明确标注的节选。节选头记录完整原文件的 SHA-256、字节数、行数和选取规则；原文各行附原始行号，不应将其当作完整构建日志。

这些证据记录的是原机那一次运行：`plain_halts` 通过官方检查，16 项公理全部在允许列表中。它们不表示其他 sanitizer 定理已经完成最终认证，也不替代在新环境重新运行检查。`verified-commit.txt` 和 `verified-program.sha256` 运行标记没有发布；历史日志中仍会出现写入这些文件的真实命令记录。

`SNAPSHOT_MANIFEST.json` 记录本目录原样复制文件与原机来源的 SHA-256 对照；证据目录的 `COPY_MANIFEST.json` 记录原始证据的同类对照。发布时逐文件核对过复制内容，未下载软件包、虚拟环境、依赖源码或大型 build/library 日志。

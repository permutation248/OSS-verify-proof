#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$HOME/projects/oss-verify-native-env"
export OPAMROOT="$ROOT/opam-root" PATH="$ROOT/bin:/usr/bin:/bin" OPAMYES=1 OPAMJOBS=8 OPAMNODEPEXTS=1 OPAMCOLOR=never
exec > >(tee -a "$ROOT/logs/install.log") 2>&1
trap 's=$?; echo INSTALL_EXIT=$s; date -Is' EXIT
set -x
date -Is
source "$ROOT/env.sh"
opam repository set-repos rocq-released default --switch=oss-verify-4.14
ulimit -s 2097152
opam install -y --jobs=8 conf-g++.1.0 dune.3.23.0 rocq-runtime.9.2.0 rocq-core.9.2.0 rocq-stdlib.9.2.0 rocq-stdpp.1.13.0 rocq-stdpp-bitvector.1.13.0 coq-flocq.4.2.2 rocq-read-file.0.0.2
opam pin add -y rocq-linux-process-semantics-core "$ROOT/deps/lps-core"
opam list --installed
rocq --version
dune --version
elf-snapshot --help

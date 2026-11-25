#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$HOME/projects/oss-verify-native-env"
export OPAMROOT="$ROOT/opam-root" PATH="$ROOT/bin:/usr/bin:/bin" OPAMYES=1 OPAMJOBS=8 OPAMNODEPEXTS=1 OPAMCOLOR=never
exec > >(tee -a "$ROOT/logs/install.log") 2>&1
trap 's=$?; echo INSTALL_EXIT=$s; date -Is' EXIT
set -x
date -Is
opam repository add rocq-released "$ROOT/deps/rocq-opam/released" --all-switches
opam switch create oss-verify-4.14 ocaml-base-compiler.4.14.2 -y --jobs=8
eval "$(opam env --switch=oss-verify-4.14 --set-switch)"
ulimit -s 2097152
opam install -y --jobs=8 conf-g++.1.0 dune.3.23.0 rocq-runtime.9.2.0 rocq-core.9.2.0 rocq-stdlib.9.2.0 rocq-stdpp.1.13.0 rocq-stdpp-bitvector.1.13.0 coq-flocq.4.2.2 rocq-read-file.0.0.2
opam pin add -y rocq-linux-process-semantics-core "$ROOT/deps/lps-core"
opam list --installed
rocq --version
dune --version
elf-snapshot --help

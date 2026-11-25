#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$HOME/projects/oss-verify-native-env"
source "$ROOT/env.sh"
mkdir -p "$ROOT/selftest"
exec > >(tee "$ROOT/logs/native-selftest.log") 2>&1
trap 's=$?; echo SELFTEST_EXIT=$s; date -Is' EXIT
set -x
cd "$ROOT/selftest"
rocq --version
dune --version
ocamlc -version
opam --version
command -v rocq dune elf-snapshot gen-fd-lemmas
opam list --installed > "$ROOT/logs/opam-installed.txt"
opam switch export "$ROOT/logs/switch.export"
cat > Ok.v <<'ROCQ'
From LinuxProcessSemantics.EquivalenceDefinition Require Import Equivalence HaltsAllowed.
Check strong_universal_error_free_T_budgets.
Check halts_allowed_T_scfg_budgets.
ROCQ
cat > Bad.v <<'ROCQ'
Definition bad : False := I.
ROCQ
rocq compile -native-compiler no -R . NativeSelftest Ok.v
set +e
rocq compile -native-compiler no -R . NativeSelftest Bad.v > bad.stdout 2> bad.stderr
bad_status=$?
set -e
cat bad.stdout bad.stderr
printf 'BAD_PROOF_EXIT=%s\n' "$bad_status"
test "$bad_status" -ne 0
elf-snapshot --help > "$ROOT/logs/elf-snapshot-help.txt"
echo 'NATIVE_SELFTEST_PASS'

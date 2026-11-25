#!/usr/bin/env bash
source "$(dirname -- "$0")/common.sh"
start_log build
rocq --version
dune --version
bash "$OSS_VERIFY_ROOT/local-reproduce/native-support/prepare-view.sh" "$OSS_VERIFY_ROOT"
cd "$OSS_VERIFY_VIEW"
dune build --display short -j "$OFT_JOBS" \
  projects/zlib/checksum_fuzzer/Images.vo \
  projects/zlib/checksum_fuzzer/Statements.vo \
  projects/zlib/checksum_fuzzer/Characterise.vo \
  projects/zlib/checksum_fuzzer/proofs/plain_halts/Proof.vo
for trace in _build/trace.csexp _build/log; do
  [[ ! -f $trace ]] || cp "$trace" "${REPRO_LOG%.log}-$(basename "$trace")"
done

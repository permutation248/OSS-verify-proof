#!/usr/bin/env bash
source "$(dirname -- "$0")/common.sh"
start_log verify
python3 "$OSS_VERIFY_ROOT/local-reproduce/check-source.py" "$OSS_VERIFY_ROOT"
SAVE_CHECK_WORK=1
rm -f local-reproduce/logs/verified-commit.txt local-reproduce/logs/verified-program.sha256
bash "$OSS_VERIFY_ROOT/local-reproduce/native-support/prepare-view.sh" "$OSS_VERIFY_ROOT"
cd "$OSS_VERIFY_VIEW"
./oft check zlib/checksum_fuzzer --facts-from "$OSS_VERIFY_FACTS" --parts statements
./oft check zlib/checksum_fuzzer --facts-from "$OSS_VERIFY_FACTS" --parts proofs --statements plain_halts
bash "$OSS_VERIFY_ROOT/local-reproduce/native-support/prepare-view.sh" "$OSS_VERIFY_ROOT"
cd "$OSS_VERIFY_ROOT"
python3 "$OSS_VERIFY_ROOT/local-reproduce/check-source.py" "$OSS_VERIFY_ROOT"
# Marker is only written after the official checker returns success for both phases.
git rev-parse HEAD > local-reproduce/logs/verified-commit.txt
sha256sum projects/zlib/bin/checksum_fuzzer/checksum_fuzzer.plain > local-reproduce/logs/verified-program.sha256

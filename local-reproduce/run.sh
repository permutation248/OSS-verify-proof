#!/usr/bin/env bash
source "$(dirname -- "$0")/common.sh"
start_log run
[[ $(git rev-parse HEAD) == "$(cat local-reproduce/logs/verified-commit.txt)" ]]
bash "$OSS_VERIFY_ROOT/local-reproduce/native-support/prepare-view.sh" "$OSS_VERIFY_ROOT"
qemu-riscv64 --version
sha256sum -c local-reproduce/logs/verified-program.sha256
mkdir -p local-reproduce/inputs
python3 - <<'PY'
import pathlib, struct
p=pathlib.Path('local-reproduce/inputs')
for name, config, payload in [
    ('ascii', b'', b'hello zlib'),
    ('bytes', b'', bytes(range(256))),
    ('repeat4', b'\x03', b'123456789' * 32),
]:
    (p/(name+'.bin')).write_bytes(struct.pack('<H',len(config))+config+struct.pack('<I',0)+payload)
(p/'too-short.bin').write_bytes(b'\0')
PY
# LPS permits no slash in argv entries after argv[0]; use a basename for the input.
cd local-reproduce/inputs
for name in ascii bytes repeat4 too-short; do
  out="${REPRO_LOG%.log}-$name.stdout"
  err="${REPRO_LOG%.log}-$name.stderr"
  set +e
  timeout 60 qemu-riscv64 "$OSS_VERIFY_ROOT/projects/zlib/bin/checksum_fuzzer/checksum_fuzzer.plain" \
    "$name.bin" > "$out" 2> "$err"
  rc=$?
  set -e
  printf 'CASE=%s EXIT_STATUS=%s STDOUT_BYTES=%s STDERR_BYTES=%s\n' \
    "$name" "$rc" "$(wc -c < "$out")" "$(wc -c < "$err")"
  printf '%s\n' '--- stdout ---'; cat "$out"
  printf '%s\n' '--- stderr ---'; cat "$err"
  printf '%s\n' "$rc" > "${REPRO_LOG%.log}-$name.exit"
  expected=0; [[ $name != too-short ]] || expected=2
  [[ $rc -eq $expected ]]
done

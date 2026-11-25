#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
cd "$OSS_VERIFY_ROOT"
finish_log() {
  local rc=$?
  trap - EXIT
  if [[ ${SAVE_CHECK_WORK:-0} == 1 && -d "$TMPDIR" ]]; then
    mkdir -p "$OSS_VERIFY_ROOT/local-reproduce/logs/tmp"
    rsync -a "$TMPDIR/" "$OSS_VERIFY_ROOT/local-reproduce/logs/tmp/" || rc=$?
  fi
  printf 'EXIT_STATUS=%s\n' "$rc"
  TZ=Asia/Shanghai date -Iseconds
  exit "$rc"
}
start_log() {
  local name=$1
  mkdir -p "$OSS_VERIFY_ROOT/local-reproduce/logs"
  export REPRO_LOG="$OSS_VERIFY_ROOT/local-reproduce/logs/$(TZ=Asia/Shanghai date +%Y%m%dT%H%M%S)-${name}-$$.log"
  exec > >(tee -a "$REPRO_LOG") 2>&1
  trap finish_log EXIT
  TZ=Asia/Shanghai date -Iseconds
  printf 'HOST=%s ROOT=%s\n' "$(hostname)" "$OSS_VERIFY_ROOT"
  printf 'OFT_JOBS=%s DUNE_CACHE=%s\n' "$OFT_JOBS" "$DUNE_CACHE"
  git rev-parse --verify HEAD || printf '%s\n' 'Original Git object import still pending; official archive manifest controls the build source.'
  set -x
}

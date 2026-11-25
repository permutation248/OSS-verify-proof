#!/usr/bin/env bash
source "$(dirname -- "$0")/common.sh"
start_log fetch
# Official fetch's minimum granularity is one project (zlib), not the whole repository.
if [[ -n ${OFT_ASSET_SOURCE:-} ]]; then
  ./oft fetch zlib --source "$OFT_ASSET_SOURCE"
elif [[ -f "$HOME/projects/oss-verify-native-env/downloads/zlib-assets/zlib-bin.tar.zst" ]]; then
  ./oft fetch zlib --source "$HOME/projects/oss-verify-native-env/downloads/zlib-assets"
else
  ./oft fetch zlib
fi
./oft verify-sha zlib
sha256sum projects/zlib/bin/checksum_fuzzer/checksum_fuzzer.plain
file projects/zlib/bin/checksum_fuzzer/checksum_fuzzer.plain

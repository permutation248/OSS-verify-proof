#!/usr/bin/env bash
# Usage: source local-reproduce/env.sh (Bash)
export OSS_VERIFY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$OSS_VERIFY_ROOT/local-reproduce/native-support/env.sh"
export PATH="$OSS_NATIVE_ENV/python-venv/bin:$HOME/projects/oss-verify-native-env/qemu/usr/bin:$OSS_VERIFY_ROOT:$PATH"
export OFT_JOBS="${OFT_JOBS:-8}"
export DUNE_CACHE=disabled
export OSS_VERIFY_SCRATCH=/var/tmp/wupeihan-oss-verify-reproduce/ad0a85d4
export OSS_VERIFY_VIEW="$OSS_VERIFY_SCRATCH/view"
export OSS_VERIFY_FACTS="$OSS_VERIFY_SCRATCH/facts"
export TMPDIR="$OSS_VERIFY_SCRATCH/check-work"
mkdir -p "$TMPDIR"
# Match oft's finite 2 GiB stack; never alter the hard limit.
_oss_hard=$(ulimit -Hs)
if [[ $_oss_hard == unlimited || $_oss_hard -ge 2097152 ]]; then
  ulimit -Ss 2097152
else
  ulimit -Ss "$_oss_hard"
fi
unset _oss_hard

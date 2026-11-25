#!/usr/bin/env bash
set -euo pipefail
base=/home/wupeihan/projects/oss-verify-native-env
mkdir -p "$base/downloads" "$base/logs" "$base/qemu"
exec > >(tee -a "$base/logs/qemu-install.log") 2>&1
trap 'rc=$?; printf "EXIT_STATUS=%s\n" "$rc"' EXIT
set -x
printf 'START UTC '; date -u +%FT%TZ
archive="$base/downloads/qemu-user_10.0.11+ds-0+deb13u1_amd64.deb"
expected=6b6fea55551fbcc1eb30e146ad5abdfbb49f8fa8c5998016242126de4d7f80df
if ! printf '%s  %s\n' "$expected" "$archive" | sha256sum -c -; then
  curl -fL --connect-timeout 15 --max-time 900 --retry 2 https://snapshot.debian.org/file/a0eaa62f815efb2361d43b1e3f8011c17ad9123a -o "$archive"
fi
printf '%s  %s\n' "$expected" "$archive" | sha256sum -c -
dpkg-deb -f "$archive" Package Version Architecture
dpkg-deb -x "$archive" "$base/qemu"
printf '%s  %s\n' 44076c56382fea0cca26fb4ec1ab688fcc59573d87de1094d664f37915ac8d72 "$base/qemu/usr/bin/qemu-riscv64" | sha256sum -c -
file "$base/qemu/usr/bin/qemu-riscv64"
"$base/qemu/usr/bin/qemu-riscv64" --version
printf 'END UTC '; date -u +%FT%TZ

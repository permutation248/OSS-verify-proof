# Source this file; native, user-owned opam root and switch only.
export OSS_NATIVE_ENV="$HOME/projects/oss-verify-native-env"
export OPAMROOT="$OSS_NATIVE_ENV/opam-root"
export OPAMSWITCH=oss-verify-4.14
export PATH="$OSS_NATIVE_ENV/bin:$PATH"
eval "$("$OSS_NATIVE_ENV/bin/opam" env --root="$OPAMROOT" --switch="$OPAMSWITCH" --set-switch --shell=sh)"
export OPAMJOBS=8
export DUNE_CACHE=disabled

#!/usr/bin/env bash
# Builds the shim + quickjs for the HOST, for `flutter test`.
#
# `flutter test` runs in the host VM and never performs a platform native
# build, so there is no plugin library for the bindings to open. This is the
# same gap that forced the LD_LIBRARY_PATH hack in scripts/test.sh for
# flutter_js — the difference is that this one is ours and builds for
# whatever architecture the host actually is.
set -euo pipefail
cd "$(dirname "$0")/.."

case "$(uname -s)" in
  Darwin) EXT=dylib ;;
  *)      EXT=so ;;
esac
OUT="build/host/libhalo_quickjs.$EXT"
mkdir -p build/host

SRCS=(src/halo_qjs.c src/quickjs/quickjs.c src/quickjs/libregexp.c src/quickjs/libunicode.c src/quickjs/dtoa.c)

# Skip the rebuild when nothing has changed — quickjs is ~5 CPU-seconds, but
# every `flutter test` invocation paying it adds up.
if [[ -f "$OUT" ]]; then
  newest=$(ls -t "${SRCS[@]}" src/halo_qjs.h | head -1)
  [[ "$OUT" -nt "$newest" ]] && { echo "halo_quickjs: host lib up to date"; exit 0; }
fi

echo "halo_quickjs: building host lib -> $OUT"
# -fvisibility=hidden + HALO_QJS_HIDE_INTERNALS: export the ten halo_qjs_*
# entry points and nothing else, matching what every shipped build does. Worth
# matching precisely because this is the library `flutter test` loads - a host
# lib that exported more than the real one would let a test pass against a
# surface production does not have.
cc -shared -fPIC -O2 -DNDEBUG -D_GNU_SOURCE -DHALO_QJS_HIDE_INTERNALS \
  -fvisibility=hidden -Isrc -Isrc/quickjs -w "${SRCS[@]}" -lm -o "$OUT"
echo "halo_quickjs: ok ($(du -h "$OUT" | cut -f1))"

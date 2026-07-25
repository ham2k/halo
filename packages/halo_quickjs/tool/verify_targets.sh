#!/usr/bin/env bash
# Cross-compiles the shim + quickjs-ng for every target ABI, without needing
# a full Flutter platform build.
#
# The platform builds themselves are driven by CMake (linux/windows/android)
# and the podspecs (macos/ios), and only run inside a real app build. This
# script exists so a source or vendored-quickjs change can be checked against
# all target architectures in seconds, on one machine.
#
# The armeabi-v7a case is the one that matters most: it is the only 32-bit
# target, and quickjs.h switches JSValue to a NaN-boxed uint64_t there
# (`#if INTPTR_MAX < INT64_MAX`). That is the whole reason no JSValue is
# allowed across the FFI boundary — Dart bindings are resolved at compile
# time and cannot be two shapes at once. This script asserts the switch
# really happens rather than trusting the header reading.
set -uo pipefail
cd "$(dirname "$0")/.."

SRCS=(src/halo_qjs.c src/quickjs/quickjs.c src/quickjs/libregexp.c src/quickjs/libunicode.c src/quickjs/dtoa.c)
CFLAGS=(-c -O2 -DNDEBUG -Isrc -Isrc/quickjs -w)
OUT=build/verify
mkdir -p "$OUT"
fail=0

say() { printf '%-34s %s\n' "$1" "$2"; }

compile() { # name, compiler, extra-flags...
  local name="$1" cc="$2"; shift 2
  local objdir="$OUT/$name"; mkdir -p "$objdir"
  for s in "${SRCS[@]}"; do
    if ! "$cc" "${CFLAGS[@]}" "$@" "$s" -o "$objdir/$(basename "${s%.c}").o" 2>"$objdir/err.log"; then
      say "$name" "FAIL — see $objdir/err.log"
      fail=1; return 1
    fi
  done
  say "$name" "ok"
}

# Asserts which JSValue representation the target actually compiles with, by
# failing the build when the expectation is wrong.
assert_jsvalue() { # name, expected(nan|struct), compiler, extra-flags...
  local name="$1" expect="$2" cc="$3"; shift 3
  local probe="$OUT/probe_$name.c"
  if [[ "$expect" == nan ]]; then
    cat > "$probe" <<'EOF'
#include "quickjs.h"
/* Fails to compile unless JSValue is the NaN-boxed scalar. */
_Static_assert(sizeof(JSValue) == sizeof(uint64_t), "expected NaN-boxed JSValue");
int probe(void) { return 0; }
EOF
  else
    cat > "$probe" <<'EOF'
#include "quickjs.h"
/* Fails to compile unless JSValue is the 16-byte {union, tag} struct. */
_Static_assert(sizeof(JSValue) == 16, "expected 16-byte struct JSValue");
int probe(void) { return 0; }
EOF
  fi
  if "$cc" -c -O0 -Isrc/quickjs -w "$@" "$probe" -o "$OUT/probe_$name.o" 2>/dev/null; then
    say "  JSValue is $expect" "confirmed"
  else
    say "  JSValue is $expect" "FAILED — representation is not what we assume"
    fail=1
  fi
}

echo "== host =="
compile host "cc" -D_GNU_SOURCE

NDK_ROOT="${ANDROID_NDK_HOME:-}"
if [[ -z "$NDK_ROOT" ]]; then
  NDK_ROOT=$(ls -d "$HOME"/Library/Android/sdk/ndk/* 2>/dev/null | sort -V | tail -1 || true)
fi
if [[ -n "$NDK_ROOT" && -d "$NDK_ROOT" ]]; then
  echo "== android (NDK $(basename "$NDK_ROOT")) =="
  TC="$NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/bin"
  [[ -d "$TC" ]] || TC="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
  API=24
  compile android-arm64   "$TC/aarch64-linux-android$API-clang"
  compile android-armv7   "$TC/armv7a-linux-androideabi$API-clang"
  compile android-x86_64  "$TC/x86_64-linux-android$API-clang"
  assert_jsvalue android-armv7 nan    "$TC/armv7a-linux-androideabi$API-clang"
  assert_jsvalue android-arm64 struct "$TC/aarch64-linux-android$API-clang"
else
  say "android" "SKIPPED — no NDK found (set ANDROID_NDK_HOME)"
fi

if xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  echo "== ios =="
  IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
  SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
  compile ios-arm64     "$(xcrun -f clang)" -target arm64-apple-ios13.0 -isysroot "$IOS_SDK"
  compile ios-sim-arm64 "$(xcrun -f clang)" -target arm64-apple-ios13.0-simulator -isysroot "$SIM_SDK"
  assert_jsvalue ios-arm64 struct "$(xcrun -f clang)" -target arm64-apple-ios13.0 -isysroot "$IOS_SDK"
else
  say "ios" "SKIPPED — no iOS SDK"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "✅ all available targets compiled"
else
  echo "❌ some targets failed"
fi
exit "$fail"

#!/usr/bin/env bash
# Asserts that a BUILT app actually contains the JS engine.
#
# Sibling to verify_targets.sh, and a different question. That one asks "does
# the shim still compile for every target ABI"; this one asks "did the thing we
# are about to ship end up with the engine in it". A build can pass the first
# and fail the second, and has:
#
#   - a Windows release that compiled ZERO lines of quickjs, because the plugin
#     never made it into the build at all (app/pubspec.lock had no mention of
#     halo_quickjs, and the build went green)
#   - an Apple RELEASE that shipped with zero engine symbols, because
#     visibility("default") is not a dead-strip root in a Mach-O executable and
#     the linker dropped every one of them. Debug builds hid it: they keep the
#     engine in a *.debug.dylib, which roots all globals.
#   - the CocoaPods path linking zero engine symbols while `pod install` ran
#     happily and Podfile.lock listed halo_quickjs
#
# None of those failed the build. They failed at RUNTIME, and quietly: the app
# launches, the extension host cannot start, it retries forever, and no crash is
# ever reported. Every extension-driven feature is simply absent - scoring,
# lookups, exports, sync - which reads to a user like the app is broken rather
# than like a missing library.
#
# Usage:  verify_engine_ships.sh <artifact> [more...]
#
#   <artifact> may be a macOS or iOS .app bundle, a shared library, or an
#   executable. Bundles are resolved to their executable automatically.
#
# Windows lives in the PowerShell sibling, verify_engine_ships.ps1, because a
# bash script is not something the Windows CI image can be relied on to run.
set -uo pipefail

# The symbol every backend must expose: it is the constructor, so nothing else
# in the engine is reachable without it, and the Dart side looks up this exact
# name to decide whether the engine is present at all (halo_quickjs.dart:43).
SYMBOL=halo_qjs_new

if [ $# -eq 0 ]; then
  echo "usage: $(basename "$0") <app-bundle|library|executable> [...]" >&2
  exit 2
fi

fail=0

# ONE temp root, created here in the parent. resolve_binary runs inside a
# command substitution - a subshell - so anything it appended to an array here
# would be lost when that subshell exited, and the unpacked .ipa would leak on
# every run. A single directory owned by the parent survives that.
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT

# Mach-O and ELF both prefix C symbols differently (_halo_qjs_new vs
# halo_qjs_new), so match the bare name anywhere in the symbol column.
resolve_binary() {
  local path="$1"
  case "$path" in
    *.ipa)
      # The iOS build only ever produces an .ipa, which is a zip with the app
      # under Payload/. Unpack just enough to inspect the executable.
      local tmp
      tmp=$(mktemp -d "$TMPROOT/ipa.XXXXXX")
      if ! unzip -q -o "$path" 'Payload/*' -d "$tmp" 2>/dev/null; then
        printf ''
        return
      fi
      local inner
      inner=$(find "$tmp/Payload" -maxdepth 1 -name '*.app' | head -1)
      if [ -z "$inner" ]; then printf ''; return; fi
      # iOS bundles are flat: the executable sits at the .app root.
      find "$inner" -maxdepth 1 -type f -perm -u+x 2>/dev/null | head -1
      ;;
    *.app)
      # macOS: Contents/MacOS/<exe>. iOS: <exe> at the bundle root.
      # The DECLARED executable, not whatever find happens to return first.
      # Contents/MacOS can hold helper tools, and `find | head -1` makes the
      # verdict depend on readdir order - it could inspect a helper that has no
      # engine (false FAIL) or, in a bundle with several, silently check the
      # wrong one.
      local exe="" name=""
      if [ -f "$path/Contents/Info.plist" ] && command -v /usr/libexec/PlistBuddy > /dev/null 2>&1; then
        name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$path/Contents/Info.plist" 2>/dev/null || true)
        if [ -n "$name" ] && [ -f "$path/Contents/MacOS/$name" ]; then exe="$path/Contents/MacOS/$name"; fi
      fi
      if [ -z "$exe" ] && [ -f "$path/Info.plist" ] && command -v /usr/libexec/PlistBuddy > /dev/null 2>&1; then
        # iOS bundles are flat: Info.plist and the executable at the root.
        name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$path/Info.plist" 2>/dev/null || true)
        if [ -n "$name" ] && [ -f "$path/$name" ]; then exe="$path/$name"; fi
      fi
      if [ -z "$exe" ]; then
        exe=$(find "$path/Contents/MacOS" -maxdepth 1 -type f -perm -u+x 2>/dev/null | head -1)
      fi
      if [ -z "$exe" ]; then
        exe=$(find "$path" -maxdepth 1 -type f -perm -u+x 2>/dev/null | head -1)
      fi
      printf '%s' "$exe"
      ;;
    *) printf '%s' "$path" ;;
  esac
}

# Captured into a variable rather than piped into `grep -q`, and that is not a
# style choice. Under `pipefail`, `nm ... | grep -q X` reports FAILURE when the
# symbol IS present: grep -q exits at the first match, nm is killed by SIGPIPE,
# and pipefail adopts nm's 141. Measured on the real Release app, which exports
# all ten symbols:
#
#   nm -g "$bin" | grep -q halo_qjs_new
#   rc=141   PIPESTATUS=141 0        <- pipeline "fails"
#   nm -g "$bin" | grep -c halo_qjs_new
#   1                                <- the symbol is right there
#
# The first version of this script did exactly that and declared the engine
# missing from a good build. Worse, it depends on output context: the same
# pipeline run 20 times at a prompt matched 20 times, and failed every time
# inside a function. A verifier that cries wolf is how a real failure later
# gets waved through, so this one does not pipe into an early-exiting reader.
#
# DEFINED symbols only, matched EXACTLY, in EVERY architecture slice. All three
# qualifiers are load-bearing and each one was a real false verdict:
#
# 1. DEFINED. `nm -g` means "global", not "defined" - it lists undefined
#    externals too, as `                 U _halo_qjs_new`. A binary that merely
#    REFERENCES the engine without containing it is exactly the broken build
#    this catches, so matching those is a false PASS. Measured against a library
#    built to reference the symbol and define nothing: `nm -g` printed
#    "U _halo_qjs_new" and the first version of this script reported OK.
#
# 2. EXACTLY. A substring test also accepts a binary defining halo_qjs_newer and
#    not halo_qjs_new. The symbol name is compared field-wise, after stripping
#    the Mach-O leading underscore.
#
# 3. EVERY SLICE. macOS ships a UNIVERSAL binary and plain `nm` reads only the
#    HOST slice. Measured on the real Release app (x86_64 + arm64) from an arm64
#    machine: `nm -gU` returned 2955 symbols, identical to `nm -arch arm64`,
#    while `-arch x86_64` had 2958. So a build whose Intel slice lost the engine
#    would have passed on Apple Silicon CI and shipped broken to every Intel Mac.
defines_symbol() {  # <binary> [arch]
  local bin="$1" arch="${2:-}" out=""
  if [ -n "$arch" ]; then
    out=$(nm -arch "$arch" -gU "$bin" 2>/dev/null || true)
  else
    # -U is defined-only on BSD/macOS nm; GNU spells it --defined-only. ELF
    # shared libraries keep exports in the dynamic table, which -g does not read
    # on every binutils version.
    out=$(nm -gU "$bin" 2>/dev/null || true)
    if [ -z "$out" ]; then out=$(nm -g --defined-only "$bin" 2>/dev/null || true); fi
    if [ -z "$out" ]; then out=$(nm -D --defined-only "$bin" 2>/dev/null || true); fi
  fi
  printf '%s\n' "$out" | awk -v want="$SYMBOL" '
    / U / { next }                      # belt and braces if a third nm variant
    { name = $NF; sub(/^_/, "", name)   # Mach-O prefixes C symbols with _
      if (name == want) found = 1 }
    END { exit(found ? 0 : 1) }
  '
}

# Slices of a universal binary, one per line; nothing on a thin file or a
# platform without lipo, in which case the caller checks it once.
arch_slices() {
  command -v lipo > /dev/null 2>&1 || return 0
  lipo -archs "$1" 2>/dev/null | tr ' ' '\n' | sed '/^$/d'
}

MISSING_SLICE=""
symbols_of() {
  local bin="$1" slices arch
  MISSING_SLICE=""
  slices=$(arch_slices "$bin")
  if [ -z "$slices" ]; then
    defines_symbol "$bin"
    return $?
  fi
  # EVERY slice must have it. Shipping a fat binary where one architecture works
  # and the other silently has no engine is the same bug, halved.
  for arch in $slices; do
    if ! defines_symbol "$bin" "$arch"; then
      # Recorded rather than printed, so it appears INSIDE the FATAL block
      # below instead of above it, where it read as though it came first.
      MISSING_SLICE="$arch"
      return 1
    fi
  done
  return 0
}

for artifact in "$@"; do
  if [ ! -e "$artifact" ]; then
    echo "FATAL: $artifact does not exist"
    fail=1
    continue
  fi

  bin=$(resolve_binary "$artifact")
  if [ -z "$bin" ] || [ ! -f "$bin" ]; then
    echo "FATAL: could not find an executable inside $artifact"
    fail=1
    continue
  fi

  if symbols_of "$bin"; then
    printf '  OK   %-58s defines %s\n' "$(basename "$bin")" "$SYMBOL"
  else
    echo "FATAL: $bin does not define $SYMBOL"
    if [ -n "${MISSING_SLICE:-}" ]; then
      echo "       missing from the $MISSING_SLICE slice of a universal binary;"
      echo "       the other slices may be fine, which is the same bug halved"
    fi
    echo "       The build succeeded and the engine is not in the product. The"
    echo "       app would launch, fail to start the extension host, and retry"
    echo "       forever - with no crash and nothing reported. See the header of"
    echo "       this script for the three times this has already shipped."
    echo
    echo "       defined symbols it DOES have (first 15):"
    nm -gU "$bin" 2>/dev/null | head -15 | sed 's/^/         /'
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "engine verified in $# artifact(s)"

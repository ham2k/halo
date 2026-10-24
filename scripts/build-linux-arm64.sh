#!/usr/bin/env bash
# Cross-builds the Linux desktop app for arm64 on an x86-64 host, and leaves a
# release bundle at app/build/linux/arm64/release/bundle.
#
# Packaging and publishing are NOT here - this is the engineering half, kept in
# the public repo so it can be read, reviewed and run from any checkout.
#
# Usage: build-linux-arm64.sh [extra `flutter build linux` args...]
#
# Any arguments are appended to the --config-only invocation below, which is the
# seam a distribution build needs: --config-only is what bakes the dart-defines
# and the Dart entry point into generated_config.cmake, and `flutter assemble`
# reads them back from there. The x64 release passes --target
# (app_dist/lib/main_dist.dart), the crash-reporting and analytics credentials
# and --build-name/--build-number; without forwarding them an arm64 release
# would quietly ship the wrong entry point and no telemetry, and look fine
# doing it.
#
# With no arguments it produces a plain unbranded build, which is what the
# manual workflow wants.
#
# A throwaway probe answered the feasibility question first - can an x86-64
# instance produce the arm64 half at all - and reported PASS on a real Codemagic
# linux_x2 instance. It proved the concept, not the steps below: this script has
# since changed compiler, gained the JNI, secrets and install steps, and
# rewritten the apt pinning, so the probe was deleted rather than left to rot.
# It is in the history of PR #381.
#
# WHY NOT `flutter build linux --target-platform linux-arm64`:
# that command refuses outright on an x64 host -
#   flutter_tools/lib/src/commands/build_linux.dart:88-94
#   "Cross-build from Linux x64 host to Linux arm64 target is not currently
#    supported."
# unconditional; riscv64 gets a feature flag right below it, arm64 does not.
# The refusal is in the COMMAND, not the machinery: `flutter assemble` has no
# host-arch guard at all, and app/linux/flutter/CMakeLists.txt drives the build
# through it anyway (tool_backend.sh $FLUTTER_TARGET_PLATFORM). So we let
# Flutter generate its CMake config for the default target - which passes the
# guard - and then drive cmake/ninja ourselves with the arm64 target set.
set -euo pipefail

ROOT="${CM_BUILD_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

say() { echo; echo "=== $* ==="; }

# Assertions, defined UP HERE so the setup half can use them too. Every one of
# these was once a bare `test -f` or `file X | grep -q`, which under
# `set -euo pipefail` aborts the whole script with no output whatsoever - a
# build that fails with a blank line where the reason should be. That cost a
# full CI round when the missing install step presented as nothing but
# "=== Verify what we produced ===" followed by silence.
have() {  # have <path> <what it is>
  if [ ! -e "$1" ]; then
    echo "FATAL: missing $1"
    echo "       ($2)"
    exit 1
  fi
}

assert_aarch64() {
  have "$1" "${2:-expected build output}"
  local desc
  desc=$(file -b "$1")
  case "$desc" in
    *"ARM aarch64"*) printf '  OK   %-52s %s\n' "$(basename "$1")" "aarch64" ;;
    *)
      echo "FATAL: $1 is not aarch64"
      echo "       $desc"
      echo "       a host-arch artifact here means the target flags did not take"
      echo "       effect and we quietly built x64 again"
      exit 1
      ;;
  esac
}


# Ubuntu images run unattended-upgrades in the background, which holds the dpkg
# frontend lock. Every apt-get here raced it and one lost:
#
#   E: Could not get lock /var/lib/dpkg/lock-frontend. It is held by
#      process 4976 (unattended-upgr)
#   Build failed :| ... exited with status code 100
#
# apt has supported waiting for the lock since 1.9.11, which is what this option
# does; there is no need to kill the daemon or poll for the lockfile. Applied to
# EVERY apt-get, not just the one that happened to lose the race - which one
# loses is pure timing.
APT_WAIT=(-o DPkg::Lock::Timeout=600)

# ...but the option alone was not enough, twice. The second failure dropped the
# "held by process N (unattended-upgr)" line and printed only
#
#   E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend)
#
# i.e. apt waited and then gave up: DPkg::Lock::Timeout does not cover every
# lock `apt-get update` takes, and the daemon can hold them for minutes on a
# freshly booted image.
#
# So: stop the daemons that grab the locks, then WAIT for the locks to actually
# be free before touching apt at all. Stopping is best-effort - an image without
# these units is fine - but the wait is enforced, and it fails loudly with the
# holder named rather than letting apt fail cryptically later.
apt_prepare() {
  sudo systemctl stop unattended-upgrades.service apt-daily.service \
    apt-daily-upgrade.service > /dev/null 2>&1 || true
  sudo systemctl kill --kill-who=all unattended-upgrades.service > /dev/null 2>&1 || true

  local waited=0 limit=300
  while sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock \
        /var/lib/apt/lists/lock > /dev/null 2>&1; do
    if [ "$waited" -ge "$limit" ]; then
      echo "FATAL: dpkg/apt locks still held after ${waited}s"
      # Name the holder. The whole reason this is hard to debug from a CI log
      # is that apt reports the lock without saying who has it.
      sudo fuser -v /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock \
        /var/lib/apt/lists/lock 2>&1 | sed 's/^/  /' || true
      exit 1
    fi
    # A plain `if`. The `[ cond ] && echo` idiom as the last command in a loop
    # body returns non-zero when the test fails and `set -e` kills the script -
    # which is exactly how the dart-defines diagnostic took a build down.
    if [ $((waited % 30)) -eq 0 ]; then
      echo "  waiting for the dpkg/apt locks to free up (${waited}s)..."
    fi
    sleep 5
    waited=$((waited + 5))
  done
  if [ "$waited" -gt 0 ]; then echo "  locks free after ${waited}s"; fi
}
apt_prepare

# ---------------------------------------------------------------------------
say "Flutter root and engine revision"
# ---------------------------------------------------------------------------
eval "$(flutter --version --machine | python3 -c \
  'import json,sys; d=json.load(sys.stdin); print("FLUTTER_ROOT=%s\nENGINE=%s" % (d["flutterRoot"], d["engineRevision"]))')"
echo "flutter root: $FLUTTER_ROOT"
echo "engine:       $ENGINE"
ARTIFACTS="$FLUTTER_ROOT/bin/cache/artifacts/engine"
BASE="https://storage.googleapis.com/flutter_infra_release/flutter/$ENGINE"

# ---------------------------------------------------------------------------
say "Seed the linux-arm64 engine artifacts"
# ---------------------------------------------------------------------------
# These are public and host-agnostic, but `flutter precache` will NEVER fetch
# them on an x64 host: LinuxEngineArtifacts builds its download list by
# interpolating cache.getHostPlatformArchName(), so the TARGET arch is simply
# never considered. Hand-placed sibling directories survive, because the
# cache's up-to-date check only ever inspects the dirs it would download
# itself.
#
# TWO archives, not one - this cost a debugging round to find:
#   linux-arm64-release/...-flutter-gtk.zip  engine .so, headers, gen_snapshot
#   linux-arm64/artifacts.zip                icudtl.dat (NO mode suffix)
flutter precache --linux   # let the normal cache settle before adding to it
sudo mkdir -p "$ARTIFACTS/linux-arm64-release" "$ARTIFACTS/linux-arm64"
if [ ! -f "$ARTIFACTS/linux-arm64-release/libflutter_linux_gtk.so" ]; then
  curl -fSL -o /tmp/gtk-arm64.zip "$BASE/linux-arm64-release/linux-arm64-flutter-gtk.zip"
  curl -fSL -o /tmp/art-arm64.zip "$BASE/linux-arm64/artifacts.zip"
  sudo unzip -qo /tmp/gtk-arm64.zip -d "$ARTIFACTS/linux-arm64-release"
  sudo unzip -qo /tmp/art-arm64.zip -d "$ARTIFACTS/linux-arm64"
  sudo chmod -R a+rX "$ARTIFACTS/linux-arm64-release" "$ARTIFACTS/linux-arm64"
fi
assert_aarch64 "$ARTIFACTS/linux-arm64-release/libflutter_linux_gtk.so" "the Flutter engine for arm64"
have "$ARTIFACTS/linux-arm64-release/flutter_linux/flutter_linux.h" "engine headers, from the gtk zip"
have "$ARTIFACTS/linux-arm64/icudtl.dat" "ICU data, from the un-suffixed artifacts.zip"
echo "engine artifacts in place and genuinely aarch64"

# ---------------------------------------------------------------------------
say "Emulate gen_snapshot"
# ---------------------------------------------------------------------------
# gen_snapshot for a linux-arm64 target is itself an aarch64 ELF - that is the
# real reason `build linux` refuses. Its only dynamic dependencies are glibc
# (no GTK, no X11, no ICU), so qemu-user-static plus the cross libc is enough:
# no binfmt_misc registration, no privileged container.
sudo apt-get "${APT_WAIT[@]}" update -qq
sudo apt-get "${APT_WAIT[@]}" install -y -qq qemu-user-static libc6-arm64-cross
GEN_SNAPSHOT="$ARTIFACTS/linux-arm64-release/gen_snapshot"
if [ ! -f "$GEN_SNAPSHOT.real" ]; then
  sudo mv "$GEN_SNAPSHOT" "$GEN_SNAPSHOT.real"
  printf '#!/bin/sh\nexport QEMU_LD_PREFIX=/usr/aarch64-linux-gnu\nexec qemu-aarch64-static "%s" "$@"\n' \
    "$GEN_SNAPSHOT.real" | sudo tee "$GEN_SNAPSHOT" > /dev/null
  sudo chmod +x "$GEN_SNAPSHOT" "$GEN_SNAPSHOT.real"
fi
"$GEN_SNAPSHOT" --version
echo "gen_snapshot runs under emulation"

# ---------------------------------------------------------------------------
say "arm64 sysroot"
# ---------------------------------------------------------------------------
# Ubuntu's main archive serves amd64 only; arm64 lives on ports.ubuntu.com.
# Every EXISTING source must be pinned to its current architectures first, or
# `apt update` 404s on an arm64 index for each of them and the whole run dies.
# Handle both the legacy sources.list and the deb822 .sources layout.
if ! dpkg --print-foreign-architectures | grep -q arm64; then
  sudo dpkg --add-architecture arm64

  echo "--- apt sources before pinning ---"
  ls -1 /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null || true

  # EVERY existing source must be restricted to its current architectures, or
  # apt tries to fetch an arm64 index from each of them and 404s - the main
  # Ubuntu archive (and the GCE mirror this image uses) serves amd64 only;
  # arm64 lives on ports.ubuntu.com.
  #
  # Done in python rather than sed because the formats vary and getting it
  # subtly wrong costs a CI cycle each time. Specifically: a deb822 .sources
  # file has MULTIPLE stanzas separated by blank lines, so appending one
  # `Architectures:` line to the end of the file only constrains the LAST one -
  # which is exactly how the first attempt failed, with noble, noble-updates
  # and noble-backports all still 404ing on binary-arm64.
  sudo python3 - <<'PIN'
import glob, os, re

targets = ['/etc/apt/sources.list'] + glob.glob('/etc/apt/sources.list.d/*')
for path in targets:
    if not os.path.isfile(path) or path.endswith('arm64-ports.sources'):
        continue
    text = open(path, encoding='utf-8', errors='replace').read()
    if path.endswith('.sources'):
        # deb822: one stanza per blank-line-separated block.
        blocks = text.split('\n\n')
        out = []
        for block in blocks:
            # Only REAL stanzas. A deb822 file usually opens with a comment
            # header, and splitting on blank lines makes that its own block -
            # adding Architectures to it produces a stanza with no Types field
            # and apt rejects the entire file:
            #   E: Malformed stanza 1 in source list ... (type)
            is_stanza = re.search(r'(?mi)^Types:', block)
            if is_stanza and not re.search(r'(?mi)^Architectures:', block):
                block = block.rstrip('\n') + '\nArchitectures: amd64 i386'
            out.append(block)
        new = '\n\n'.join(out)
    else:
        # legacy one-line-per-source, with or without an existing [opts] block.
        lines = []
        for line in text.split('\n'):
            m = re.match(r'^(deb(?:-src)?)\s+(\[[^\]]*\]\s*)?(\S+.*)$', line)
            if m and 'arch=' not in (m.group(2) or ''):
                opts = (m.group(2) or '').strip()
                inner = opts[1:-1].strip() if opts.startswith('[') else ''
                merged = ('arch=amd64,i386 ' + inner).strip()
                line = '%s [%s] %s' % (m.group(1), merged, m.group(3))
            lines.append(line)
        new = '\n'.join(lines)
    if new != text:
        open(path, 'w', encoding='utf-8').write(new)
        print('pinned to amd64: %s' % path)
PIN

  . /etc/os-release
  # Signed-By only if the keyring is actually present; naming a missing file
  # makes apt reject the whole source.
  KEYRING=/usr/share/keyrings/ubuntu-archive-keyring.gpg
  # The arm64 source offers the same suites the amd64 sources do, -security
  # included. The GTK/glib runtime libraries are Multi-Arch: same, so dpkg
  # requires the arm64 copy to be the exact same VERSION as the amd64 copy
  # already on the image: any suite the host can install from and ports cannot
  # is a version this side can never match. -security is normally a subset of
  # -updates, so this is coverage parity rather than a fix for one known
  # failure.
  {
    printf 'Types: deb\nURIs: http://ports.ubuntu.com/ubuntu-ports\n'
    printf 'Suites: %s %s-updates %s-security\nComponents: main universe\nArchitectures: arm64\n' \
      "$UBUNTU_CODENAME" "$UBUNTU_CODENAME" "$UBUNTU_CODENAME"
    [ -f "$KEYRING" ] && printf 'Signed-By: %s\n' "$KEYRING"
  } | sudo tee /etc/apt/sources.list.d/arm64-ports.sources > /dev/null

  echo "--- sources as apt now sees them ---"
  # Printed because the previous attempt failed here and the log did not say
  # which file still offered arm64. If this 404s again, this is the evidence.
  grep -rHE '^(deb|Types:|URIs:|Suites:|Architectures:)' \
    /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | sed 's/^/  /'

  # Fail loudly rather than limping on with a stale index and dying later in a
  # confusing dependency-resolution error. Note `apt-get update -qq` can exit 0
  # despite "Some index files failed to download" - which is very likely why
  # the probe's B step passed while this same setup failed here.
  sudo apt-get "${APT_WAIT[@]}" update
fi

# Mirrors the x64 dependency list in app_dist/ci/build-linux.sh. libcurl is for
# sentry-native, which does find_package(CURL ... AsynchDNS).
# --force-overwrite is load-bearing, not laziness. The GTK -dev packages ship
# GObject-introspection .gir files into arch-INDEPENDENT paths
# (/usr/share/gir-1.0/Pango-1.0.gir and friends), and the amd64 copies are
# already installed on this image as part of the x64 build dependencies. dpkg
# refuses to co-install the arm64 versions over them:
#
#   dpkg: error processing .../libpango1.0-dev_..._arm64.deb (--unpack):
#    trying to overwrite shared '/usr/share/gir-1.0/Pango-1.0.gir'
#
# Safe here specifically because .gir files are metadata for language bindings
# (python-gi and the like) - we compile C and C++ and never read them, and the
# real per-arch content lives in /usr/lib/<triplet>/ which does NOT collide.
# The alternative, purging the amd64 -dev packages, would cascade through the
# image for no benefit on a runner that only cross-builds. A dedicated
# debootstrap sysroot would avoid it properly, at the cost of several minutes
# per build.
# clang is the COMPILER (see scripts/aarch64-linux-gnu.cmake for why it has to
# be clang and not aarch64-linux-gnu-g++); crossbuild-essential-arm64 is still
# required, because clang cross-compiles by flag but links against the crt
# files, libgcc and libstdc++ that the GNU cross toolchain provides, and uses
# its binutils for as/ld.
# -q, not -qq: -qq swallows apt's "The following packages have unmet
# dependencies" block, leaving a bare "E: Unable to correct problems, you have
# held broken packages" that names neither the package nor the version it
# wanted. That is the one line a broken sysroot gets to explain itself with.
ARM_DEV_PKGS=(
  clang
  crossbuild-essential-arm64
  libgtk-3-dev:arm64 libglib2.0-dev:arm64
  libsecret-1-dev:arm64 libjsoncpp-dev:arm64
  libcurl4-openssl-dev:arm64 libsqlite3-dev:arm64
  libudev-dev:arm64
)
if ! sudo apt-get "${APT_WAIT[@]}" install -y -q \
     -o Dpkg::Options::=--force-overwrite "${ARM_DEV_PKGS[@]}"; then
  # apt reports the FIRST unsatisfiable package and then stops, so a run that
  # dies here says nothing about the other seven. Ask about each one on its
  # own, in simulation, and let the log name every offender and the version it
  # could not reach - one CI round should be enough to diagnose this, not one
  # per package.
  echo
  echo "--- apt could not install the arm64 sysroot; asking package by package ---"
  for pkg in "${ARM_DEV_PKGS[@]}"; do
    echo "### $pkg"
    sudo apt-get "${APT_WAIT[@]}" install -s -o Dpkg::Options::=--force-overwrite \
      "$pkg" 2>&1 | grep -vE '^(Inst|Conf) ' | tail -25 | sed 's/^/    /' || true
  done
  # A Multi-Arch: same library can only be co-installed at the SAME version, so
  # the amd64 version already on the image and the arm64 candidate on ports
  # have to agree. Print both for the packages that couple the two sides.
  echo
  echo "--- amd64 installed vs arm64 candidate (Multi-Arch: same coupling) ---"
  for lib in libglib2.0-0t64 libgtk-3-0t64 libsecret-1-0 libjsoncpp25 \
             libcurl4t64 libsqlite3-0 libudev1 libc6; do
    printf '  %-18s amd64=%-24s arm64=%s\n' "$lib" \
      "$(dpkg-query -W -f='${Version}' "$lib:amd64" 2>/dev/null || echo '<none>')" \
      "$(apt-cache policy "$lib:arm64" 2>/dev/null | awk '/Candidate:/{print $2}')"
  done
  exit 1
fi

# Flutter reads CMAKE_CXX_COMPILER from our cache and then requires a sibling
# named `clang` (native_assets.dart:89). Prove BOTH exist in the same directory
# now, with a clear message, rather than at the very end of a 338-target build.
CLANGXX=$(command -v clang++ || true)
CLANG=$(command -v clang || true)
if [ -z "$CLANGXX" ] || [ -z "$CLANG" ]; then
  echo "FATAL: need clang and clang++ on PATH"
  echo "  clang++: ${CLANGXX:-<none>}"
  echo "  clang:   ${CLANG:-<none>}"
  exit 1
fi
if [ "$(dirname "$(readlink -f "$CLANGXX")")" != "$(dirname "$(readlink -f "$CLANG")")" ]; then
  echo "FATAL: clang and clang++ resolve to different directories; Flutter looks"
  echo "       for clang NEXT TO the C++ compiler it reads from CMakeCache.txt"
  echo "  clang++ -> $(readlink -f "$CLANGXX")"
  echo "  clang   -> $(readlink -f "$CLANG")"
  exit 1
fi
echo "clang++: $CLANGXX  ->  $(readlink -f "$CLANGXX")"
echo "clang:   $CLANG"
clang --version | head -1

# pkg-config MUST be pointed at the target tree. Left alone it returns the
# HOST's flags, everything configures happily, and the failure appears at LINK
# time after a full compile - the most expensive way to find out.
export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=/
# The `jni` plugin - a transitive dependency of sentry_flutter, which declares
# linux: ffiPlugin: true - does find_package(JNI REQUIRED COMPONENTS JVM) and
# links libjvm.so. On an x64 image that is the amd64 JVM, so the cross link
# fails with "file in wrong format". Install the arm64 JRE for its libjvm.so.
# The headers stay the host's: OpenJDK's jni.h and linux/jni_md.h use only
# standard types and are identical across x86-64 and aarch64.
sudo apt-get "${APT_WAIT[@]}" install -y -qq -o Dpkg::Options::=--force-overwrite openjdk-17-jre-headless:arm64
ARM_JVM=$(find /usr/lib/jvm -name libjvm.so -path '*arm64*' 2>/dev/null | head -1)
# Check the find result BEFORE dirname: `dirname ""` prints "." and exits 0, so
# folding them into one line would smuggle a bogus "." past the guard below and
# hand CMake -DJAVA_INCLUDE_PATH=. - the confusing failure this guard exists to
# prevent.
HOST_JNI_FILE=$(find /usr/lib/jvm -name jni.h 2>/dev/null | head -1)
HOST_JNI_H=""
# A plain `if`, not `[ -n ... ] && ...`: as a standalone statement that idiom
# returns non-zero when the test fails, which under `set -e` kills the script
# before the guard below can say what was missing.
if [ -n "$HOST_JNI_FILE" ]; then HOST_JNI_H=$(dirname "$HOST_JNI_FILE"); fi
if [ -z "$ARM_JVM" ] || [ -z "$HOST_JNI_H" ]; then
  echo "FATAL: need an arm64 libjvm.so and a host jni.h"
  echo "  arm64 libjvm.so: ${ARM_JVM:-<none>}"
  echo "  host jni.h dir:  ${HOST_JNI_H:-<none>}"
  find /usr/lib/jvm -maxdepth 1 -type d | sed 's/^/    /'
  exit 1
fi
echo "arm64 libjvm.so: $ARM_JVM"
echo "host jni.h:      $HOST_JNI_H"
assert_aarch64 "$ARM_JVM" "arm64 libjvm.so for the jni plugin"

if ! pkg-config --exists gtk+-3.0; then
  echo "FATAL: pkg-config cannot see gtk+-3.0 for the target"
  echo "       PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR"
  exit 1
fi
LIBDIR=$(pkg-config --variable=libdir gtk+-3.0)
echo "gtk+-3.0 resolves to: $LIBDIR"
# It must be the TARGET tree. Resolving to /usr/lib/x86_64-linux-gnu means
# pkg-config is handing out host flags and the link would fail much later, in a
# far less obvious way.
case "$LIBDIR" in
  *aarch64-linux-gnu*) ;;
  *) echo "FATAL: pkg-config resolved gtk+-3.0 to the HOST tree ($LIBDIR)"; exit 1 ;;
esac
have /usr/lib/aarch64-linux-gnu/libgtk-3.so "arm64 GTK, from libgtk-3-dev:arm64"
# Prove the toolchain and sysroot actually cooperate before spending ten
# minutes on the app build.
printf '#include <gtk/gtk.h>\nint main(void){ return gtk_init_check(0,0) ? 0 : 1; }\n' > /tmp/gtkcheck.c
# Compiled with the SAME compiler and flags the real build uses, deliberately.
# Probing with aarch64-linux-gnu-gcc while building with clang would prove the
# sysroot works for a toolchain we no longer use, which is worse than no probe.
clang --target=aarch64-linux-gnu --gcc-toolchain=/usr \
  /tmp/gtkcheck.c -o /tmp/gtkcheck $(pkg-config --cflags --libs gtk+-3.0)
assert_aarch64 /tmp/gtkcheck "the sysroot probe binary"
echo "linked a real aarch64 GTK binary - sysroot is usable"

# ---------------------------------------------------------------------------
say "Generate Flutter's CMake config (x64 target - passes the host guard)"
# ---------------------------------------------------------------------------
# --config-only writes generated_config.cmake and the plugin symlinks without
# building. writeGeneratedCmakeConfig emits FLUTTER_ROOT, PROJECT_DIR, version
# fields and the dart-defines - nothing architecture-specific - so generating
# for the default target and then building for arm64 is sound.
# EXPORTED, not just passed as a --dart-define. app/linux/CMakeLists.txt:13
# reads HALO_EDITION from the ENVIRONMENT and falls back to "dev" when it is
# unset, and it drives APPLICATION_ID, the product name, the .desktop file and
# the installed icon. Without the export the Dart half compiled as `next` while
# the native half branded itself `com.ham2k.logger.dev` - a green build
# producing an internally inconsistent bundle, which is the exact failure class
# the rest of this script exists to catch. app_dist/ci/build-linux.sh exports it
# for the x64 build for the same reason.
export HALO_EDITION="${HALO_EDITION:-next}"
EDITION="$HALO_EDITION"

# secrets.dart is gitignored, so a fresh checkout does not have it and the Dart
# compile dies with "Error when reading 'lib/config/secrets.dart'". The blank
# template is a supported configuration - every consumer degrades rather than
# failing, and the Map tab falls back to OpenStreetMap. Same handling, and the
# same wording, as scripts/test.sh:54-61.
#
# Only when ABSENT: this workflow runs the public script directly with no
# secrets group, but app_dist/ci/build-linux.sh generates a populated
# secrets.dart before calling in, and clobbering that would silently strip
# every award API key and OAuth client from a real distribution build.
#
# This replaced a step that wrote app/lib/config/mapbox_token.dart, which #411
# folded into this one store. That file is now referenced by nothing, so the
# step was writing somewhere no build reads while the file the build actually
# needs went missing.
if [ ! -f app/lib/config/secrets.dart ]; then
  echo "no secrets present, using the blank template"
  cp app/lib/config/secrets.dart.example app/lib/config/secrets.dart
fi

(cd packages/halo_build_tools && dart run bin/prepare_record.dart)
( cd app && flutter build linux --release --no-tree-shake-icons --config-only \
    --dart-define=HALO_EDITION="$EDITION" "$@" )
# Show what actually got baked in, decoded. generated_config.cmake stores the
# dart-defines base64-encoded, so a wrong or missing one is invisible in a diff
# and would only show up as a mysteriously unbranded build.
# Wrapped so it can NEVER fail the build. This is a diagnostic - it exists to
# make a wrong dart-define visible - and the first version of it aborted the
# whole run: `[ -n "$d" ] && printf ...` as the last command in a while body
# returns non-zero on a trailing empty field, the loop adopts that status, and
# `set -e` kills the script. Which is the exact idiom this file already warns
# about a hundred lines above, reintroduced in a print statement.
show_baked_config() {
  local cfg="app/linux/flutter/generated_config.cmake" defines="" d=""
  if [ ! -f "$cfg" ]; then echo "  (no generated_config.cmake)"; return 0; fi
  defines=$(sed -n 's/.*DART_DEFINES=\([^"]*\).*/\1/p' "$cfg" 2>/dev/null | head -1)
  if [ -z "$defines" ]; then
    echo "  (no DART_DEFINES entry found)"
  else
    printf '%s' "$defines" | tr ',' '\n' | while read -r d; do
      if [ -n "$d" ]; then
        printf '  %s\n' "$(printf '%s' "$d" | base64 --decode 2>/dev/null || printf '%s' "$d")"
      fi
    done
  fi
  echo "--- entry point ---"
  grep -E 'FLUTTER_TARGET' "$cfg" 2>/dev/null | head -3 | sed 's/^/  /'
  return 0
}
echo "--- dart-defines baked into the CMake config ---"
show_baked_config || true

# ---------------------------------------------------------------------------
say "Build for arm64"
# ---------------------------------------------------------------------------
# FLUTTER_TARGET_PLATFORM is what app/linux/flutter/CMakeLists.txt forwards to
# tool_backend.sh, which turns it into
#   flutter assemble -dTargetPlatform=linux-arm64 release_bundle_linux-arm64_assets
# and assemble has no host-arch guard.
BUILD_DIR="app/build/linux/arm64/release"
# The cross settings live in a toolchain file rather than a wall of -D flags:
# they have to apply to every sub-project too, and sentry-native is pulled in
# by FetchContent and configured as part of this same tree.
cmake -S app/linux -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$ROOT/scripts/aarch64-linux-gnu.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DFLUTTER_TARGET_PLATFORM=linux-arm64 \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DJAVA_JVM_LIBRARY="$ARM_JVM" \
  -DJAVA_INCLUDE_PATH="$HOST_JNI_H" \
  -DJAVA_INCLUDE_PATH2="$HOST_JNI_H/linux"

# Every compile command must carry --target, not just the ones for languages we
# remembered. clang cross-compiles by FLAG, so a language whose flags we missed
# does not fail to configure - it quietly compiles for the host and blows up
# somewhere in the middle of the build, or worse, links. That is how the ASM
# case was found, at target 37 of 338; this asks the question at target 0 and
# names every offender at once instead of one per build.
echo "--- checking every compile command targets aarch64 ---"
python3 - "$BUILD_DIR/compile_commands.json" <<'PY'
import json, sys, collections
try:
    entries = json.load(open(sys.argv[1]))
except Exception as exc:
    print(f"FATAL: could not read compile_commands.json: {exc}")
    sys.exit(1)
bad = collections.defaultdict(list)
for e in entries:
    cmd = e.get("command") or " ".join(e.get("arguments", []))
    if "--target=aarch64" not in cmd:
        bad[e["file"].rsplit(".", 1)[-1]].append(e["file"])
if bad:
    print(f"FATAL: {sum(len(v) for v in bad.values())} of {len(entries)} compile "
          "commands have no --target=aarch64 and would build for the HOST")
    for ext, files in sorted(bad.items()):
        print(f"  .{ext}: {len(files)}")
        for f in files[:3]:
            print(f"      {f}")
    print("  A language needs its own flags - see scripts/aarch64-linux-gnu.cmake")
    sys.exit(1)
exts = sorted({e["file"].rsplit(".", 1)[-1] for e in entries})
print(f"OK: all {len(entries)} compile commands target aarch64 ({', '.join(exts)})")
PY

# Assert, don't just print. flutter assemble's dart_build step reads the C++
# compiler out of this cache and then looks for a `clang` beside it; when either
# is missing it fails at the LAST target of the build, having compiled all 338.
# Checking here costs a second and names the actual cause.
echo "--- compiler entries in CMakeCache.txt ---"
grep -E '^CMAKE_(C|CXX)_COMPILER:' "$BUILD_DIR/CMakeCache.txt" || true
CACHED_CXX=$(sed -n 's/^CMAKE_CXX_COMPILER:[A-Z]*=//p' "$BUILD_DIR/CMakeCache.txt" | head -1)
if [ -z "$CACHED_CXX" ]; then
  echo "FATAL: no CMAKE_CXX_COMPILER entry in $BUILD_DIR/CMakeCache.txt"
  echo "       dart_build reads this and will fail at the end of the build."
  echo "       A toolchain file that uses set() instead of find_program() leaves"
  echo "       the compiler in CMakeFiles/*/CMakeCXXCompiler.cmake and never"
  echo "       writes a cache entry - see scripts/aarch64-linux-gnu.cmake."
  exit 1
fi
if [ ! -e "$(dirname "$(readlink -f "$CACHED_CXX")")/clang" ]; then
  echo "FATAL: no 'clang' next to the cached C++ compiler"
  echo "  CMAKE_CXX_COMPILER = $CACHED_CXX  ->  $(readlink -f "$CACHED_CXX")"
  echo "       Flutter requires a sibling named exactly 'clang' (it resolves"
  echo "       symlinks first, so a symlink named clang does NOT satisfy it)."
  exit 1
fi
echo "dart_build prerequisites OK: $CACHED_CXX (+ clang alongside)"

cmake --build "$BUILD_DIR" -j"$(nproc)"

# Building is only half of it. The link step leaves the executable in
# intermediates_do_not_run/ - the name is a warning - and the runnable bundle
# (executable + data/ + lib/ + icudtl.dat + the AOT libapp.so) is assembled by
# the INSTALL rules in app/linux/CMakeLists.txt:106-159. `flutter build linux`
# runs this as `ninja -C <dir> install` (build_linux.dart:212); omitting it
# produced a build where all 338 targets compiled and no bundle existed.
say "Install: assemble the bundle from the built targets"
cmake --build "$BUILD_DIR" --target install -j"$(nproc)"

# ---------------------------------------------------------------------------
say "Verify what we produced"
# ---------------------------------------------------------------------------
BUNDLE="$BUILD_DIR/bundle"
if [ ! -d "$BUNDLE" ]; then
  echo "FATAL: no bundle at $BUNDLE"
  echo "       cmake --build only produces intermediates_do_not_run/; the bundle"
  echo "       is assembled by the INSTALL step (app/linux/CMakeLists.txt:106-159,"
  echo "       COMPONENT Runtime), which is what 'flutter build linux' runs as"
  echo "       'ninja -C <dir> install' (build_linux.dart:212)."
  ls -la "$BUILD_DIR" | head
  exit 1
fi

EXE=$(find "$BUNDLE" -maxdepth 1 -type f -perm -u+x | head -1)
if [ -z "$EXE" ]; then
  echo "FATAL: no executable at the top level of $BUNDLE"
  find "$BUNDLE" -maxdepth 2 | head -20
  exit 1
fi
# The assertion that matters. A host-arch executable here would mean the target
# platform never took effect and we quietly built x64 again - which is exactly
# the class of silent wrongness this whole engine project exists to remove.
assert_aarch64 "$EXE"
assert_aarch64 "$BUNDLE/lib/libapp.so"
assert_aarch64 "$BUNDLE/lib/libflutter_linux_gtk.so"
# And OUR engine, the reason any of this is possible. Both branches assert the
# SYMBOL, not just the file: previously only the else branch did, and the else
# branch is the one that never runs - the bundle does contain the .so - so the
# only check that actually executed was "is this file aarch64".
QJS=$(find "$BUNDLE" -name 'libhalo_quickjs.so' | head -1)
if [ -n "$QJS" ]; then
  assert_aarch64 "$QJS" "the JS engine, built by packages/halo_quickjs"
  ENGINE_TARGET="$QJS"
else
  # Statically linked into the executable rather than bundled is also fine, so
  # long as the engine is demonstrably in there.
  echo "note: no separate libhalo_quickjs.so; expecting it linked into $EXE"
  ENGINE_TARGET="$EXE"
fi
# The SHARED checker, not a local copy. This script used to carry its own, and
# the copy still had the bug the shared one was fixed for: `nm | grep -q` under
# `pipefail` reports failure when the symbol IS present, because grep exits at
# the first match and nm dies of SIGPIPE. It failed a perfectly good build with
# exit 141 - SIGPIPE's code - while printing `halo_qjs_new` in its own list of
# what the file exports.
#
# One implementation. The shared one also matches the symbol exactly, ignores
# undefined references, and checks every slice of a universal binary; a second
# copy would have to relearn all of that, and this one demonstrably did not.
bash packages/halo_quickjs/tool/verify_engine_ships.sh "$ENGINE_TARGET"

echo
echo "OK: aarch64 release bundle at $BUNDLE"
echo "BUNDLE=$BUNDLE"

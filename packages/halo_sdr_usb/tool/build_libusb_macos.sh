#!/usr/bin/env bash
# Builds libusb.xcframework for macOS from the vendored source in
# third_party/libusb — a dynamic framework, arm64 and x86_64 — into
# macos/halo_sdr_usb/Frameworks/, where both the Swift package and the podspec
# take it from. Its output is committed: a build of the app needs nothing run
# first. Run this again only to change libusb.
#
# A framework of its own because libusb is LGPL-2.1: linked dynamically, the
# copy in the app can be replaced with another build of the same library, as
# that licence asks. Xcode signs it with the app, so library validation loads
# it like any other part of the bundle.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=1.0.30
MIN_MACOS=12.0
SRC=third_party/libusb
OUT=macos/halo_sdr_usb/Frameworks/libusb.xcframework
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

SOURCES=(core.c descriptor.c hotplug.c io.c strerror.c sync.c os/darwin_usb.c os/events_posix.c os/threads_posix.c)

for arch in arm64 x86_64; do
  mkdir -p "$WORK/$arch"
  for f in "${SOURCES[@]}"; do
    cc -c -O2 -arch "$arch" -mmacosx-version-min="$MIN_MACOS" -fvisibility=hidden -w \
      -I"$SRC/Xcode" -I"$SRC/libusb" -I"$SRC/libusb/os" \
      "$SRC/libusb/$f" -o "$WORK/$arch/$(basename "$f" .c).o"
  done
  cc -dynamiclib -arch "$arch" -mmacosx-version-min="$MIN_MACOS" \
    -install_name @rpath/libusb.framework/Versions/A/libusb \
    -compatibility_version 1.0.0 -current_version "$VERSION" \
    -framework IOKit -framework CoreFoundation -framework Security \
    "$WORK/$arch"/*.o -o "$WORK/$arch/libusb"
done

FW="$WORK/libusb.framework"
mkdir -p "$FW/Versions/A/Headers" "$FW/Versions/A/Resources"
lipo -create "$WORK/arm64/libusb" "$WORK/x86_64/libusb" -output "$FW/Versions/A/libusb"
cp "$SRC/libusb/libusb.h" "$FW/Versions/A/Headers/"
cat > "$FW/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>libusb</string>
  <key>CFBundleIdentifier</key><string>com.ham2k.halo.libusb</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>libusb</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
</dict>
</plist>
PLIST
ln -s A "$FW/Versions/Current"
ln -s Versions/Current/libusb "$FW/libusb"
ln -s Versions/Current/Headers "$FW/Headers"
ln -s Versions/Current/Resources "$FW/Resources"

rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"
xcodebuild -create-xcframework -framework "$FW" -output "$OUT" >/dev/null
echo "libusb $VERSION -> $OUT ($(du -sh "$OUT" | cut -f1))"

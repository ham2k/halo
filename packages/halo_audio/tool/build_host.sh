#!/usr/bin/env bash
# Builds the shim + miniaudio for the HOST, for `flutter test`, which runs in
# the host VM and never performs a platform native build — so there is no
# plugin library for the binding to open without this one.
set -euo pipefail
cd "$(dirname "$0")/.."

case "$(uname -s)" in
  Darwin)
    EXT=dylib
    LIBS=(-framework CoreFoundation -framework CoreAudio -framework AudioToolbox)
    ;;
  *)
    EXT=so
    LIBS=(-lpthread -lm -ldl)
    ;;
esac
OUT="build/host/libhalo_audio.$EXT"
mkdir -p build/host

if [[ -f "$OUT" && "$OUT" -nt src/halo_audio.c && "$OUT" -nt src/halo_audio.h && "$OUT" -nt src/miniaudio/miniaudio.h ]]; then
  echo "halo_audio: host lib up to date"
  exit 0
fi

echo "halo_audio: building host lib -> $OUT"
# -fvisibility=hidden: export the halo_audio_* entry points and nothing else,
# matching what every shipped build does, so a test cannot pass against a
# surface production does not have.
cc -shared -fPIC -O2 -DNDEBUG -fvisibility=hidden -Isrc -w src/halo_audio.c "${LIBS[@]}" -o "$OUT"
echo "halo_audio: ok ($(du -h "$OUT" | cut -f1))"

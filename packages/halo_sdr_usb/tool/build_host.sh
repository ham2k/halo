#!/usr/bin/env bash
# Builds the shim for the HOST, for `flutter test`, which runs in the host VM
# and never performs a platform native build. With the test tone compiled in
# and no USB receivers: the tests read the ring through the tone, and need
# neither hardware nor libusb.
set -euo pipefail
cd "$(dirname "$0")/.."

case "$(uname -s)" in
  Darwin) EXT=dylib; LIBS=() ;;
  *) EXT=so; LIBS=(-lpthread -lm -ldl) ;;
esac
OUT="build/host/libhalo_sdr_usb.$EXT"
mkdir -p build/host

if [[ -f "$OUT" && "$OUT" -nt src/halo_sdr_usb.c && "$OUT" -nt src/halo_sdr_usb.h && "$OUT" -nt src/sdrplay.c && "$OUT" -nt src/sdrplay.h ]]; then
  echo "halo_sdr_usb: host lib up to date"
  exit 0
fi

echo "halo_sdr_usb: building host lib -> $OUT"
# -fvisibility=hidden, as every shipped build: a test cannot pass against a
# surface production does not have.
cc -shared -fPIC -O2 -std=gnu11 -DNDEBUG -DHALO_SDR_USB_NO_USB -DHALO_SDR_USB_TEST_SOURCE -fvisibility=hidden -Wall -Wextra -Werror \
  -Isrc src/halo_sdr_usb.c src/sdrplay.c ${LIBS[@]+"${LIBS[@]}"} -o "$OUT"
echo "halo_sdr_usb: ok ($(du -h "$OUT" | cut -f1))"

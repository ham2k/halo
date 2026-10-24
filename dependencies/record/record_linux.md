# HaLo Linux I/Q capture patch

Upstream: [`record_linux` 2.1.3](https://pub.dev/packages/record_linux/versions/2.1.3),
[official archive](https://pub.dev/api/archives/record_linux-2.1.3.tar.gz).
Archive SHA-256: `00c847ba25684572674dacfbd4bcabee6c5d9a1fa948778ff34091c71c19250f`.
The upstream MIT license is preserved in the generated
`packages/record_linux_patched/LICENSE`. New HaLo sources carry MPL-2.0
headers. The bootstrap verifies the archive and every final source hash;
see [the shared dependency workflow](README.md) for preparation and updates.

## Scope

HaLo uses this package solely for stereo PCM16 I/Q streaming. The upstream
PulseAudio/ffmpeg recorder can resample or upmix and requires external programs,
so `RecordLinux` selects `AlsaIqRecorder` instead. File encoders, pause/resume and
voice processing are deliberately unavailable in this patched default recorder.
The original implementation remains for upstream provenance and its existing
injected-recorder tests, but production never invokes its executable pipeline.

Modified upstream files:

- `lib/record_linux.dart`: choose the ALSA recorder, hardware input enumeration,
  and PCM-only capabilities.

The authored, tracked `pubspec.yaml` scaffold declares `ffi ^2.1.4` alongside the
upstream runtime dependencies and plugin metadata.

Added files:

- `lib/src/alsa_backend.dart`: direct ALSA ABI, hardware capture enumeration,
  exact format negotiation, signed PCM conversion and handle ownership.
- `lib/src/alsa_iq_recorder.dart`: isolated capture, stream/state lifecycle and
  acknowledged sample delivery.

Backend regression tests live in HaLo's
`app/test/cat/iq_audio_linux_test.dart` and run through `scripts/test.sh cat`.

## Guarantees and requirements

Input enumeration uses ALSA's control API without starting capture or requesting
permission. Stored IDs name `hw:CARD=<card-id>,DEV=<device>,SUBDEV=<subdevice>`;
no numeric card index, default, PulseAudio, `plug` or `plughw` ID is accepted.
Card names survive card-index changes; users with indistinguishable duplicate
USB adapters should assign unique persistent ALSA card IDs in their system
configuration. A missing selected ID fails instead of changing inputs.

The PCM must report the hardware backend. Rate and two-channel configuration
are exact, with ALSA automatic rate/channel/format conversion disabled. Capture
accepts signed 16/24/32-bit little-endian hardware PCM and drops only low bits to
produce interleaved signed PCM16. It never manufactures channels or sample rate.
The requested 48/96/192 kHz setting must be supported by the hardware; ALSA sets
that exact native clock directly. No system audio mixer or software signal
processing path participates.

The input is claimed directly while spectrum capture runs. Other applications
(or a sound server holding the device) may prevent access and must release that
input first. Permission, unsupported library, missing device, invalid format and
sample-rate errors have stable `iq_audio_*` reasons. Unplug, overrun or native
read failure closes capture rather than splicing discontinuous FFT samples.
Stop waits for the worker to close its native handle and exit before reopening.
The worker allows at most one in-flight sample message.

The only added runtime dependency is **`libasound.so.2`**, supplied by the normal
ALSA runtime package (`libasound2`, `libasound2t64`, or distribution equivalent).
No `arecord`, `pactl`, `ffmpeg`, subprocess, ALSA development headers or extra CMake
link dependencies are required. The Flutter/Dart toolchain resolves `ffi` in the
usual dependency install step. This FFI path is Linux-only.

References: [ALSA control API](https://www.alsa-project.org/alsa-doc/alsa-lib/group___control.html),
[PCM API](https://www.alsa-project.org/alsa-doc/alsa-lib/group___p_c_m.html),
[hardware parameters](https://www.alsa-project.org/alsa-doc/alsa-lib/group___p_c_m___h_w___params.html).

# Capture patch for `record_macos` 2.1.1

The build prepares the published package from
<https://pub.dev/api/archives/record_macos-2.1.1.tar.gz>, without `example/`.
The archive's SHA-256 is
`ced7495abf3d683e8a7dbe8fc96df8ea5722837a26f922b7cb7c5de11661bb46`.
Upstream is <https://github.com/llfbandit/record/tree/main/record_macos>.
The upstream license is preserved in the generated
`packages/record_macos_patched/LICENSE`. Preparation and updates follow
[the shared dependency workflow](README.md).

Only `macos/record_macos/Sources/record_macos/delegate/RecorderStreamDelegate.swift`
differs from the archive:

- An explicitly selected device UID that cannot resolve throws
  `iq_audio_device_unavailable`. Upstream leaves the engine on its default
  microphone in this case. A Dart enumeration check alone cannot prevent a
  device disappearing before native stream startup.
- A stereo PCM16 stream requires exactly two source channels before
  `AVAudioConverter` is created. Mono upmixing and multichannel downmixing
  cannot preserve the two independent quadrature measurements. An invalid
  source throws `iq_audio_invalid_format`.
- The source sample rate must match the requested output rate within 1 Hz.
  A mismatch throws `iq_audio_sample_rate_mismatch`; upsampling a narrower
  capture would otherwise display bandwidth the interface never sampled.
- An audio-engine configuration change stops the capture and reports the
  stopped state. A device unplug or route/format change must finish this
  stream instead of leaving the caller waiting for samples or continuing
  against a different input. The observer is removed during teardown and
  checks the engine identity before stopping.

The error messages are stable identifiers mapped to `IqAudioException`
in `app/lib/services/cat/transports/iq_audio_io.dart`.

The output remains upstream's interleaved, little-endian PCM16. Configure
the device's native capture rate in macOS Audio MIDI Setup to match HaLo's
48, 96 or 192 kHz selection before starting the spectrum.

## Verification

The bootstrap verifies the archive and every final source hash.
`record_macos.patch` changes only the delegate named above.

The repository's Dart tests cannot compile this Swift code. A macOS build
and a real two-channel audio interface are required to validate native
startup, sample order, unplugging and permission denial.

## Platform boundary

HaLo uses similarly validated native capture backends on Android, iOS,
Windows and Linux. Web capture has a separate AudioWorklet backend and can
verify only the browser-delivered track format, not the physical ADC clock.
See [the KX3 capture design](../../docs/design/kx3-panadapter.md) for setup,
platform requirements and validation limits.

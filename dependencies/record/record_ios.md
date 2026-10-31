# Capture patch for `record_ios` 2.1.1

The build prepares the published package from
<https://pub.dev/api/archives/record_ios-2.1.1.tar.gz>, without `example/`.
The archive SHA-256 is
`21d189f49a598af4697dac4cc9e48389ac0a1fb3e916622b5504a58d9b96313e`.
Upstream is <https://github.com/llfbandit/record/tree/main/record_ios>.
The upstream license is preserved in the generated
`packages/record_ios_patched/LICENSE`. Preparation and updates follow
[the shared dependency workflow](README.md).

`RecorderStreamDelegate.swift` uses a strict capture path for PCM16 stereo:

- Configure the audio session in measurement mode, without voice processing,
  and select the exact input port UID. A missing or rejected input never falls
  back to the built-in microphone.
- Negotiate the requested native sample rate on that selected route. The
  ordinary recording path's 48 kHz clamp does not apply to I/Q. Support for
  96/192 kHz depends on the connected USB interface and the iOS device.
- Before conversion and after engine startup, require exactly two physical
  port channels, two active session input channels, and two engine source
  channels. The session and source rates must both match the requested rate.
  A stereo converter output alone is insufficient: it can be an upmix.
- Stop on route changes, interruptions, media-service loss/reset, or engine
  format changes. Invalidation immediately suppresses tap delivery and queued
  Flutter PCM events. Each tap also checks its channel count and source rate.
  A changed route is never automatically resumed as I/Q.
- Release observers and deactivate an owned I/Q audio session on stop and
  failed startup. Existing non-I/Q recording keeps the upstream session path.

`IqCaptureValidation.swift` contains the route/format rule used during native
startup; `test/IqCaptureValidationTest.swift` checks that rule without hardware.
The stable errors are `iq_audio_device_unavailable`, `iq_audio_invalid_format`
and `iq_audio_sample_rate_mismatch`, mapped to `IqAudioException` by HaLo.

## API evidence

- [Measurement mode](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/measurement)
  minimizes system signal processing.
- [Audio routing](https://developer.apple.com/documentation/avfaudio/audio-routing)
  provides selected/current input ports and physical-channel descriptions.
- [Input channel count](https://developer.apple.com/documentation/avfaudio/avaudiosession/inputnumberofchannels)
  and [sample rate](https://developer.apple.com/documentation/avfaudio/avaudiosession/samplerate)
  describe the active route, independently of converter output.

## Verification

The bootstrap verifies the archive and every final source hash.
`record_ios.patch` changes `RecorderStreamDelegate.swift`;
`overlays/record_ios/` adds the validator and its regression test.

The pure validator test runs through the repository gate on a macOS host:

```sh
mise exec -- ./scripts/test.sh --native-iq ios
```

An iOS build and a physical stereo USB interface must verify permission denial,
channel orientation, native 48/96/192 kHz rates, unplugging, interruptions and
reopening. A simulator does not validate microphone routing or USB capture.

Remove this override when upstream provides the same capture guarantees.

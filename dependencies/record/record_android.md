# Capture patch for `record_android` 2.2.0

The build prepares the published package from
<https://pub.dev/api/archives/record_android-2.2.0.tar.gz>, without `example/`.
The archive SHA-256 is
`f5080279259c4ad769590f1c165762eaa4e414178adc2e2fab137103228e07ac`.
Upstream is <https://github.com/llfbandit/record/tree/main/record_android>.
The upstream license is preserved in the generated
`packages/record_android_patched/LICENSE`. Preparation and updates follow
[the shared dependency workflow](README.md).

The changes apply to a PCM16 stereo stream (`path == null`), the I/Q capture
contract used by HaLo. Other formats and file recording retain upstream behavior.

- The authored package manifest selects `com.ham2k.halo.record.HaloRecordPlugin`.
  This tracked entry point forwards every engine and activity lifecycle call to
  the prepared upstream `RecordPlugin`; it gives Flutter a real discovery
  entry point even before the upstream package is downloaded.
- `android/build.gradle.kts` explicitly applies the Kotlin Android plugin,
  matching HaLo's `android.builtInKotlin=false` configuration. Without it the
  upstream module's Kotlin compiler configuration cannot compile under HaLo.
- `RecordConfig.kt` preserves the requested input ID separately from the device
  lookup. A missing device throws `iq_audio_device_unavailable` before audio
  environment preparation, rather than falling back to the default microphone.
  It also passes the system audio manager through the native configuration; the
  Dart method-channel arguments are unchanged.
- `FormatCodecSelector.kt` preserves the original I/Q channel request instead
  of silently clamping stereo to a mono input before validation. A Robolectric
  regression test supplies a mono USB input to the actual format selector.
- `PCMReader.kt` requires a successful explicit input selection and requests
  `UNPROCESSED` when Android advertises it. Otherwise it uses the documented
  `VOICE_RECOGNITION` fallback, which does not employ AGC or noise suppression.
  `AudioEffectsManager.kt` disables AGC, echo cancellation and noise suppression,
  and refuses a strict capture if an effect remains enabled.
- Before any PCM chunk is published, `PCMReader.kt` checks the actual device
  recording configuration, independently of the client format. The routed
  device and hardware-device IDs must both match the selected input. Both
  hardware and client streams must have two channels and the requested rate.
  Framework resampling and mono upmixing therefore cannot fabricate bandwidth
  or quadrature data. API 29+ uses `AudioRecord.getActiveRecordingConfiguration`;
  API 24–28 uses `AudioManager.getActiveRecordingConfigurations`, matched by the
  recorder's session ID. Missing native metadata fails closed. The package's
  existing minimum Android API remains 24.
- Device-removal, routing and recording-configuration callbacks invalidate the
  capture and unblock its read. A changed device, channel count, sample rate,
  enabled processing effect, or system silencing cannot continue delivering
  I/Q samples. The native capture loop reports the failure and releases capture.
- `AudioInterruptionPolicy.kt` stops I/Q streams on audio-focus loss.
  `RecorderController.kt` releases the capture and never resumes that session
  on focus regain. `PcmCaptureEngine.kt` unblocks a pending audio read during
  stop. Policy and controller tests cover interruption teardown.
- `IqCaptureValidation.kt` contains the device/format rule used by the reader.
  Its focused JVM tests cover actual stereo rates, missing/fallback inputs,
  mono upmixing, multichannel downmixing, resampling and processing.

The stable errors are `iq_audio_device_unavailable`, `iq_audio_invalid_format`
and `iq_audio_sample_rate_mismatch`, mapped to `IqAudioException` by HaLo.

## API evidence

- [Android recording configuration](https://developer.android.com/reference/android/media/AudioRecordingConfiguration)
  distinguishes the actual device format from the client format and explicitly
  documents framework resampling between them.
- [Android recording sources](https://developer.android.com/media/platform/mediarecorder)
  documents `UNPROCESSED` and the `VOICE_RECOGNITION` fallback.
- [AudioRecord](https://developer.android.com/reference/android/media/AudioRecord)
  documents preferred/routed devices and active recording configuration.

## Verification

The bootstrap verifies the archive and every final source hash.
`record_android.patch` contains the upstream changes; `overlays/record_android/`
contains the validator and its new regression tests.
The upstream Gradle test target includes the validator tests.
Run it through the repository gate, with a JDK and Android SDK configured.
The gate includes this original module in an isolated temporary Gradle project
using the app's actual AGP/Kotlin versions and Gradle flags plus the matching
Flutter embedding dependency. It explicitly compiles production/test Kotlin and
checks nonempty native XML suites under `app/build/iq-native-android`. This
avoids unrelated app-plugin configuration failures without masking this
module's shipping build configuration:

```sh
mise exec -- ./scripts/test.sh --native-iq android
```

An Android build plus a physical USB stereo interface must verify permission
denial, both channel orientations, supported 48/96/192 kHz rates, active device
identity, unplugging and unsupported-rate rejection. Desktop Dart tests cannot
exercise Android's routing or audio hardware.

Remove this override when upstream provides the same capture guarantees.

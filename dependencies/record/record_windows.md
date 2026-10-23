# HaLo Windows I/Q capture patch

Upstream: [`record_windows` 2.3.0](https://pub.dev/packages/record_windows/versions/2.3.0),
[official archive](https://pub.dev/api/archives/record_windows-2.3.0.tar.gz).
Archive SHA-256: `8195489a47b5e8246985d6213ff65aae1b14e32a0ca45dc5f680e8d503296e1b`.
The upstream MIT license is preserved in the generated
`packages/record_windows_patched/LICENSE`. New HaLo sources carry MPL-2.0
headers. The bootstrap verifies the archive and every final source hash;
see [the shared dependency workflow](README.md) for preparation and updates.

## Scope

Stereo PCM16 streaming uses a dedicated WASAPI exclusive capture worker. Media
Foundation's normal conversion path cannot guarantee bypass of Windows audio
processing objects, so I/Q capture must not use that path. Other upstream record
APIs retain the Media Foundation implementation.

Modified upstream files:

- `windows/audio_device/record_audio_device.{h,cpp}`: add a native I/Q endpoint
  validator requiring explicit selection and exact channel count/rate. Existing
  non-I/Q device adjustment remains unchanged. Device enumeration constructs
  each `EncodableValue` in place because Flutter's map conversion constructor
  is explicit; passing a map directly to `push_back` cannot compile.
- `windows/record/record.{h,cpp}`: select and own the I/Q worker for stereo PCM
  streams; teardown completes before the next capture.
- `windows/record_windows_plugin.cpp`: map expected device, permission, format,
  rate and exclusive-access failures to stable `iq_audio_*` reasons.
- `windows/CMakeLists.txt`: build the capture/helper sources and native tests.

Added sources: `windows/iq_capture.{h,cpp}`, `windows/iq_pcm.h`,
`windows/iq_source_validation.h`, `windows/test/iq_source_validation_test.cpp`,
`windows/test/iq_pcm_portable_test.cpp`.

## Guarantees and requirements

The user must select the stereo interface's Windows endpoint and set its native
format in Windows Sound device properties to the same 48/96/192 kHz rate as HaLo.
Missing endpoint, mono/multichannel source, unknown native format and rate
mismatch are rejected. No default-input fallback is allowed. Exclusive
`IsFormatSupported` and `Initialize` must accept the exact two-channel native
rate, which bypasses the shared audio engine's channel/rate conversion and
software enhancements. Signed integer 16/24/32-bit hardware PCM is reduced to
PCM16 without changing sample timing or channel order. Voice processing requests
are refused. No compressed or floating-point format fallback is attempted.

**Exclusive access must be enabled for that input, and another application must
not hold it exclusively.** The worker holds only the selected capture endpoint,
not the playback endpoint, for the duration of spectrum capture. A locked or
unavailable input fails visibly. There is no shared-mode fallback because it
could alter I/Q. A format/route change that invalidates the endpoint, a sample
discontinuity, timestamp error or sustained missing packets stops capture.

All capture COM objects belong to the worker thread. Stop disarms queued
callbacks, signals the worker, joins it and releases the endpoint before a new
capture can open. Each 5 ms polling pass drains available packets, bounded to at most twice the
actual endpoint buffer frame count (one final whole packet can cross the first
buffer boundary). Each packet is released before reading the next. At most one
sample batch is queued to the recorder dispatcher at once; upstream Flutter
platform-thread event delivery remains unchanged. No new runtime
DLL or global package is required beyond Windows WASAPI and the upstream plugin's
existing Media Foundation/COM dependencies.

Native Windows tests require a Windows Flutter/MSVC build with
`include_record_windows_tests=ON`. The portable PCM/format regression test has no
Windows dependencies. Run it through the repository entry point:
`./scripts/test.sh --native-iq windows`.
Passing that test does not substitute for a Windows native build or stereo
hardware capture check.

References: [exclusive-mode capture](https://learn.microsoft.com/en-us/windows/win32/coreaudio/exclusive-mode-streams),
[exact format support](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudioclient-isformatsupported),
[capture buffer rules](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudiocaptureclient-getbuffer),
[native endpoint format](https://learn.microsoft.com/en-us/windows/win32/coreaudio/pkey-audioengine-deviceformat).

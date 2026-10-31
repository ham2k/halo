# KX3 I/Q panadapter

The KX3 exports stereo baseband I/Q through RX I/Q. HaLo captures it
through a true stereo line input or USB audio interface, alongside
the existing serial CAT connection. The PX3 buffered RX I/Q PC output
works the same way. Its serial protocol offers screenshots, not live
spectrum bins. Stock KX2 has no external I/Q output.

## Capture and display

The named KX3 driver optionally creates a spectrum session. It captures
only while a spectrum display listens, disables voice processing, and
keeps audio failures separate from CAT and keying. Samples never go to a
recording file or through the extension bridge.

Stereo PCM16 becomes interleaved complex samples for the existing FFT.
Local controls provide channel swapping, zoom, reference level and sweep
speed. A signed center correction is added to the CAT dial. Frequency
changes discard transform history while preserving the audio stream's
byte alignment. Levels are relative, not calibrated dBm.

The native backends reject a missing selected device, non-stereo input,
and mismatched hardware sample rate. They stop on a device or audio-format
change. Permission denial and lost audio require reopening the display;
there is no automatic permission retry loop.

## Setup and hardware validation

Enable RX I/Q in the KX3 menu. In HaLo’s KX3 equipment settings, enable the
I/Q panadapter, choose the audio input and its sample rate. On mobile and
web, use **Allow audio input and refresh devices** in the input selector
first. Desktop users can refresh the list after connecting an interface;
opening settings alone never requests permission or captures samples.
A missing input, mono source or rate mismatch is refused. Allow audio
input permission when opening a spectrum display for the first time.

| Platform | Input requirements |
| --- | --- |
| macOS | Select a stereo input and set its hardware rate in Audio MIDI Setup to match HaLo. |
| Windows | Set the stereo input’s native rate in Windows Sound device properties to match HaLo. Enable exclusive access and release the input in other apps; WASAPI exclusive capture bypasses shared audio processing. |
| Linux | Use an ALSA hardware capture device with two channels and the selected rate. `libasound.so.2` is required; PulseAudio/PipeWire conversion and external recording commands are not used. Hardware access is exclusive, so other apps may need to release the device. |
| Android | Connect a stereo USB audio interface through a USB host adapter. Both the routed hardware format and the delivered stream must match; devices that cannot verify that format are rejected. |
| iOS | Connect a compatible stereo USB audio interface. Capture uses the selected input in measurement mode and validates both the session and engine format. |
| Web | Use HTTPS or localhost, grant access through the input selector, and use a browser reporting the required track settings. See the browser format boundary below. |

For a display, build and install the
[Panadapter & Waterfall sample](../../extensions/samples/k2hrc-panafall/README.md),
then add its Panadapter panel to an operation. Its README has the packaging
and installation commands; samples are not included in the regular build.

Start at 48 kHz. Use the swap control if signals move in the wrong direction.
The center correction is added to the CAT dial to locate the FFT center;
verify it against a known carrier for each band/mode/RX SHFT setup.
Click-to-tune and keying continue through the existing CAT connection.

No live KX3/audio-interface capture has been used to validate this feature.

The shared FI command is not applicable to the KX3; HaLo does not poll it
or manipulate radio menus. Before claiming hardware validation, check
48/96/192 kHz, tuning, mode/RX SHFT changes, unplug/reconnect and permission
denial with a real radio and interface. Synthetic tests and a native build
cannot establish frequency alignment for every radio setting.

## Browser setup and format boundary

Use an HTTPS or localhost page with Web Audio and AudioWorklet support.
Serial CAT also requires a browser with Web Serial support. In equipment
settings, choose the sample rate and use **Allow audio input** before
selecting the interface. This explicit action requests microphone permission
and activates the audio context at that rate; its temporary permission
stream is immediately stopped. After a page reload or a sample-rate change,
use the action again. Passive device enumeration never requests permission.

The browser must report the selected device ID, two input channels, the
requested sample rate, and disabled echo cancellation, noise suppression,
and automatic gain control. Missing or mismatched settings are rejected.
The AudioContext rate must equal the track rate, and the AudioWorklet checks
the actual channel count in every block without mono upmixing. Capture
stops on track loss, mute, device removal, context interruption, or a
reported format change. Reopen the display after correcting the problem.

These checks establish the format delivered by the browser, not the physical
ADC clock. The Media Capture specification permits browser processing to
satisfy track constraints, and the API cannot establish the interface's
original RF bandwidth. Matching the context and track rates prevents an
additional Web Audio resampling step. Verify the usable RF span with a
known signal, especially above 48 kHz; a browser may reject those rates
even when the interface supports them natively.

Browser tests exercise PCM channel order and mono rejection through a real
AudioWorklet with synthetic audio. Real interface capture, browser permission
behavior, device removal, and usable RF bandwidth still need hardware checks.

## Automated verification

Run the full repository gate with `mise exec -- ./scripts/test.sh`. It includes
the browser AudioWorklet tests, shared capture lifecycle and permission tests,
and Linux format/worker tests with an injected native backend. Those tests do
not open a microphone or require a connected radio.

Native validators run through the same entry point:

- `./scripts/test.sh --native-iq ios` compiles the route/format validator with Swift.
- `./scripts/test.sh --native-iq windows` compiles the portable format/PCM tests with a C++17 compiler; it does not compile WASAPI.
- `./scripts/test.sh --native-iq android` runs the Android plugin’s Gradle unit tests using the configured JDK and Android SDK.

Native app builds and real stereo-interface checks remain separate from these
synthetic tests. In particular, a simulator build cannot validate iOS USB routing,
and passing portable C++ tests does not establish Windows capture behavior.

## Sources

- [KX3 owner manual, pp. 26–27](https://ftp.elecraft.com/KX3/Manuals%20Downloads/E740163%20KX3%20Owner%27s%20man%20Rev%20C5.pdf)
- [PX3 owner manual](https://ftp.elecraft.com/PX3/Manuals%20Downloads/E740229%20PX3%20Owner%27s%20Manual.pdf)
- [PX3 programmer reference](https://ftp.elecraft.com/PX3/Manuals%20Downloads/PX3_Pgmrs_Ref_A6.pdf)
- [KX3 programmer reference](https://ftp.elecraft.com/KX3/Manuals%20Downloads/K3S%26K3%26KX3%26KX2%20Pgmrs%20Ref%2C%20G5.pdf)
- [KX2 hardware FAQ](https://elecraft.com/products/kx2-ssb-cw-data-80-10-m-transceiver)
- [record audio capture](https://github.com/llfbandit/record)
- [Media Capture source, track, and processing semantics](https://www.w3.org/TR/mediacapture-streams/#terminology)
- [Web Audio media-stream channel and resampling semantics](https://www.w3.org/TR/webaudio-1.1/#MediaStreamAudioSourceNode)

## Build dependencies

The native recorder packages are prepared before Flutter dependency resolution.
Only pinned archive metadata, focused patches and HaLo-authored additions are
tracked; generated packages stay out of Git. See
[the recorder dependency workflow](../../dependencies/record/README.md) for
bootstrap, offline builds and backend updates.

# K4 remote connection

The **Elecraft K4 → Secure Network/WiFi** pairing carries CAT, both
panadapters and audio over one TLS connection, on port 9204 by default. It is one
device with two receivers ([station-model.md § 3](station-model.md#3-devices)):
Main and Sub are picked as separate radios, and share the physical connection
and the transmitter. The serial and local Ethernet 9200/9201 pairings remain separate.
The secure transport uses a native backend on macOS, Windows, Linux, iOS and
Android; it is unavailable in browsers.

The wire reference is Elecraft's *K4-Remote Protocol*, revision A1,
June 13, 2025. The remote envelope differs from the local port 9201 spectrum
format.

## Equipment setup

Enter the radio's host and network password, and use port 9204 unless a
forwarded port is required. The `remotePort` configuration key is separate
from the local CAT port, so switching pairings preserves both values.

Station Configuration lists the K4 once. Adding it adds both receivers: Main
under the device's id, which takes the logging radio as any new transceiver
does, and Sub under `<device>/rx:sub`, which the radio pickers list as
"K4 · Sub". Neither has a receiver setting, since which receiver an entry
tracks is part of its id. Editing it from any row edits the K4, Sub in use
or not, and the connection settings it edits are both receivers', the
row's plug connects and disconnects both, and removing the K4 removes both and
its saved password. Moving the K4 to its serial or Ethernet pairing removes
the Sub, with its picks, since only the secure link reaches it; moving it back
adds the Sub again under the same id.

A station stored before this had Main and Sub as two entries with ids of
their own, joined by a shared connection id (`k4ConnectionId`), which also
names the keychain entry and keeps doing so. On load, the Sub takes the id
`<Main's id>/rx:sub`, and a K4 stored with one receiver gets the other; a
K4 stored with only a Sub gets a Main under an id made from its connection id,
never the Sub's old one, and the same one at every load, so a layout that
picked it finds it again whether or not the station was saved in between.
Each old id is forwarded to the entry it named
([station-model.md § 9](station-model.md#9-persistence-and-migration)).

The panel's **Main / Sub / Both** selection addresses those radio IDs. Each
pane has independent local zoom, reference, averaging, speed and waterfall
history. Settings and history survive visibility changes within the mounted
panel, but not panel disposal or an app restart.

## Connection ownership

- [`K4RemoteTransport`](../../app/lib/services/cat/transports/k4_remote_transport_io.dart)
  opens TLS using the password's UTF-8 bytes directly as the pre-shared key
  and an empty identity. The password uses the equipment secret store and
  redaction path. Authentication has no certificate exchange or plaintext
  password message, and never falls back to unencrypted port 9205. The
  [native TLS package](../../packages/halo_tls_psk/README.md) documents its
  ciphers, resource limits and platform packaging.
- [`K4RemoteConnection`](../../app/lib/services/cat/transports/k4_remote_connection.dart)
  decodes the multiplexed stream into CAT, PAN and subscribed raw audio. It
  sends framed `PING;` each second and closes after ten seconds without a
  valid CAT, PAN or subscribed audio packet.
  `PONG` keeps an idle radio connected; closure feeds the CAT reconnect policy.
- [`K4SharedConnectionPool`](../../app/lib/services/cat/transports/k4_shared_connection.dart)
  grants a lease to each logical receiver. Concurrent connects share one
  connection attempt. Cancelling or disconnecting one receiver leaves its
  sibling connected; the final lease closes the connection. A physical drop
  invalidates both leases. Raw CAT traffic also reaches lease diagnostics,
  which drop traffic while paused or unlistened rather than stalling siblings
  or building a queue. The traffic log records sent and received CAT once
  at the physical connection boundary.
- [`K4SharedSession`](../../app/lib/services/cat/drivers/k4_shared_session.dart)
  parses CAT once and owns startup, transmit state and keying queues. Its
  receiver facades expose ordinary radio and single-spectrum interfaces.
  Disconnecting a facade stops PTT, CW or voice activity initiated by that
  facade, while a sibling's activity continues. Automatic reconnect restores
  the designated radio and its siblings.

The owner subscribes to PAN while at least one pane needs it. Hiding the last
pane releases that subscription without closing CAT or opening port 9201.
Each logical receiver has an ordinary `SpectrumSession` and its own
`K4SpectrumPresenter`; Main and Sub are selected by radio ID throughout the
panel and extension APIs. A terminated PAN stream reports unavailable until
the physical connection is replaced; it does not start a separate retry loop.
Audio decoding is also demand-driven. The transport drops inbound audio
while no receiver listens. The shared session routes each requested channel
into the audio engine and owns the connection's encoding for listening,
live microphone use and the computer's voice keyer.

## Receiver and CAT state

Startup selects `K40;K31;`, requests `RDY;` and initial state, and uses AI4
push updates without periodic idle-state or transmit polling. Meta modes and
AI are per client. The shared owner requests receiver-specific frequency,
mode, data submode, passband and high-resolution signal reports, together
with diversity and Sub enable state. IF supplies the initial global transmit
state, not receiver frequency or mode. Parameterless `TX;` and `RX;` AI4
notifications update that same shared state when a paddle, external PTT or
another client keys or unkeys the radio; `TQ` replies also update it. These
notifications are receive-side state reports, never commands to key the radio,
and are not interpreted on the local CAT pairings. QK4's
[TX/RX handlers](https://github.com/mikeg-dal/QK4/blob/cc3fb6d17f3f2dc29689a413f01affffea9c0e06/src/models/radiostate/rxtxmeterstate.cpp#L118-L130)
provide the wire behavior reference (GPL-3.0, read for protocol facts only).
A legacy PC push triggers a PCX read for the explicit power range.

AI4 excludes changes made by this client, so setters read back the affected
state. Main changes also refresh Sub where the radio can couple their state.
Power, PTT, keyer speed and voice memories belong to the shared transmitter;
receiver selection does not change the radio's split transmit selection.

Main normally uses VFO A and Sub uses VFO B. With diversity enabled, both
receivers follow A and B remains available as a split transmit register. Sub
controls follow that receiver binding and wait for diversity state before
writing. Each panadapter’s frequency window comes from its PAN header,
independently of tuning.

Under **EXP AUDIO**, the **Diversity reception (DIV)** control in the
station's configuration details follows the radio's `DV` reply. It sends
`DV1;` or `DV0;` and reads back `DV;` and `SB;`. The K4 turns Sub on
when diversity is enabled.
Connecting a Sub entry alone leaves the receiver's enable state to the radio.
`SB0` means off, `SB1` means on, and
[`SB3`](https://github.com/mikeg-dal/QK4/blob/8e9a705af6ed725cbb0d818b9043109276d671db/docs/k4-protocol-quirks.md#12-mini-pan-state-mp--mp-is-pushed-by-the-radio)
also means on, with the Sub mini-pan running.

## Envelope and PAN payload

TCP reads may split or combine envelopes. Each envelope contains:

```text
FE FD FC FB | payload length (u32 big-endian) | payload | FB FC FD FE
```

The incremental decoder caps payloads at 64 KiB and resynchronizes corrupt
envelopes. The first three payload bytes are type, version and sequence.
Type 0/version 0 carries ASCII CAT; type 2 carries PAN. Type 1/version 1
carries audio. With a listener, the decoder accepts EM0 signed 24-bit samples
in little-endian 32-bit containers and EM1 signed little-endian 16-bit samples,
both interleaved stereo at 12 kHz. It checks the declared frames against the
sample payload. Unsupported audio encodings, mini-pan (3) and unknown types
are counted and discarded.

PAN offsets are relative to the outer payload:

| Offset | Field | Representation |
| --- | --- | --- |
| 3 | Nested PAN type | Opaque byte |
| 4 | Receiver | 0 main, 1 sub |
| 5 | Declared inner length | u16 little-endian; retained as metadata |
| 7–10 | Reserved | Retained in the header |
| 11 | Center frequency | i64 little-endian, Hz |
| 19 | Sample rate | i32 little-endian, kHz |
| 23 | Noise floor | i32 little-endian, tenths of dB |
| 27 onward | Bins | Unsigned bytes; display level = byte − 160 |

The decoder requires a nonnegative center, positive sample rate and receiver
0 or 1. It derives bin count from the payload, accepting 2–4,096 bins as a
resource bound rather than assuming a fixed sweep size. The presenter shared
with the LAN pairing uses the transmitted center and sample rate to place
each receiver's bins and publishes the full sweep by default. See
[Spectrum](cat.md#elecraft-k4-lan-tcp-9201) for display zoom and explicit
scope span requests.

A1 leaves the PAN version, nested type and declared inner length ambiguous.
Those fields are preserved without imposing guessed validity rules. Bin
levels use the documented conversion above and are not calibrated dBm.

## Live audio

Under **EXP AUDIO**, each secure receiver's existing **Listen to Audio** and
**Microphone** choices can use **On This Computer**. Availability follows the
existing audio engine and logging-set rules, including the selected receiver,
operator devices, mix gains and transmit gate. The serial and local Ethernet
pairings have no network-audio capability. Recording a voice-keyer message
continues through its existing recording path.

The inbound stereo stream carries physical Main on the left and Sub on the
right. A listening logging set normally gets its chosen receiver in both
ears. In diversity, when only one logging set listens to this K4 and
Sub is confirmed on, that set gets Main left and Sub right. Two sets
listening to the same K4 keep their own receiver feeds so the station
mixer can route them. A disabled Sub is silent.

The shared session applies the raw stream's source-derived gain of 32,
clamps samples, and interpolates 12 kHz to the engine's 48 kHz rate. The
engine route handles playback, jitter and clock drift. Interpolation
history resets at sequence gaps and when the listening layout changes.

One shared owner reads the connection's encoding, selects `EM1;` and verifies
the setting before playing received audio or keying the live microphone.
Main, Sub, microphone and voice-keyer messages share that ownership. The
prior encoding is restored after the last user ends. A format refusal ends
the affected audio route and reports an audio problem.

Live microphone audio comes from the engine's mono 48 kHz route. A 63-tap
low-pass FIR filters it before decimation to 12 kHz. The sender duplicates
mono into the two EM1 channels, starts a fresh sequence at each key, and
sends one 720-frame packet every 60 ms. The packets themselves key the K4
from the streamed input. The microphone sends neither CAT `TX;` (which
selects the radio's own input) nor `RX;`. On release it stops sending, so
the radio can finish the last frame and return to receive. It sends no
catch-up burst after a scheduler pause.

This path differs from Flex's native UDP audio endpoint. K4 CAT, PAN and
audio share the existing Dart-owned TLS stream, so audio decoding,
interpolation, microphone filtering and packet pacing stay in Dart. The
native engine still owns sound devices, routing and clock bridging. Dart
scheduling can affect packet timing, and this path has no native sender's
timing guarantee.

The channel layout, raw encodings, gain and packet format are derived from
[QK4's protocol observations](https://github.com/mikeg-dal/QK4/blob/8e9a705af6ed725cbb0d818b9043109276d671db/docs/k4-protocol-quirks.md#11-audio-encode-modes-em0em3-carry-the-same-audio-at-different-numeric-scales)
and source, read for protocol facts only. Live receive and microphone use,
including runtime EM changes, remain unverified on K4 hardware.

## Transmit audio

The computer's voice keyer sends its recordings over this connection
([cat.md § The computer's voice keyer](cat.md#the-computers-voice-keyer)).
The live microphone uses the same packet layout. It is derived from QK4's
source (GPL-3.0, read for the facts of the format, with no code copied) and
remains unverified on hardware.

| Offset | Field | Value |
| --- | --- | --- |
| 0 | Type | 1, audio |
| 1 | Version | 1 |
| 2 | Sequence | u8, from 0 for each transmission, wrapping |
| 3 | Encode mode | 1 (EM1) |
| 4 | Frames per channel | u16 little-endian; 720 |
| 6 | Rate code | 0, 12 kHz |
| 7 onward | Samples | S16 little-endian, stereo interleaved, mono copied to both |

720 frames is 60 ms, what the K4 bundles at its default streaming latency
(SL3; SL0 is 240, SL1–2 480, SL6–7 1440). The connection's encoding is EM3,
Opus, unless set. A message acquires the shared EM1 setting before `TX;`
and releases it after `RX;`. Listening keeps EM1 selected between messages.

Every audio packet keys the K4. For the existing recorded-message path,
`TX;` goes before the first packet and the stream ends before `RX;`. Unconfirmed until a K4
tries it: whether EM changed mid-connection takes effect, whether a frame size
other than the SL tier's is accepted, and whether the K4 needs stereo (QK4
sends stereo for the raw modes and mono Opus).

## Capture and replay

The capture tool records PAN envelopes for offline inspection. From the
repository root, run:

```sh
cd app
dart run tool/k4_remote_capture.dart capture \
  --host 192.0.2.4 --output /tmp/k4-remote-capture --seconds 20 \
  --note 'Firmware and receiver/display settings'
dart run tool/k4_remote_capture.dart inspect /tmp/k4-remote-capture/capture.bin
```

Replace the example host with the radio's address. The password prompt hides
terminal input; `--password-env VARIABLE_NAME` supports automation without
putting the password in process arguments. The output directory must be new.
`capture.bin` contains complete PAN envelopes, `frames.jsonl` contains frame
metadata, and `summary.json` contains counts and metadata summaries. CAT,
audio and passwords are not saved.

Capture sends only `RDY;` and `PING;`; it does not tune, key or change the
display. Duration defaults to 20 seconds, and the default 32 MiB receive limit
counts all traffic, including discarded CAT and audio. `inspect` does not
connect to a radio, but Dart's native build hooks run before either command:
the first run can download and compile Mbed TLS even for replay. See the
[TLS source cache](../../packages/halo_tls_psk/README.md#native-builds-and-source-cache)
for prefetch and offline configuration. Include firmware, receiver,
split/diversity and display settings in the note when they are needed to
interpret a capture.

# K4 remote connection

The **Elecraft K4 → Secure Network/WiFi** pairing carries CAT and both
panadapters over one TLS connection, on port 9204 by default. Main and Sub
appear as separate radios in HaLo while sharing the physical connection and
transmitter. The serial and local Ethernet 9200/9201 pairings remain separate.
The secure transport uses a native backend on macOS, Windows, Linux, iOS and
Android; it is unavailable in browsers.

The wire reference is Elecraft's *K4-Remote Protocol*, revision A1,
June 13, 2025. The remote envelope differs from the local port 9201 spectrum
format.

## Equipment setup

Enter the radio's host and network password, and use port 9204 unless a
forwarded port is required. The `remotePort` configuration key is separate
from the local CAT port, so switching pairings preserves both values.

Main is the default receiver. To expose Sub, add another secure K4 entry with
the same connection settings and **Receiver: Sub**. Leave its password blank
to reuse the existing entry's saved password, or enter the same password.
Matching connection settings and credentials join a persisted device identity;
different credentials or ports identify separate connections. Editing shared
connection settings updates both entries. Removing either entry preserves the
remaining entry's credentials. Adding Sub does not change the logging radio.

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
  decodes the multiplexed stream into CAT and PAN. It sends framed `PING;`
  each second and closes after ten seconds without a valid CAT or PAN packet.
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
Audio still consumes network bandwidth before being discarded. There is no
outbound audio encoder: sending an audio packet would key the radio.

## Receiver and CAT state

Startup selects `K40;K31;`, requests `RDY;` and initial state, and uses AI4
push updates without periodic idle-state or transmit polling. Meta modes and
AI are per client. The shared owner requests receiver-specific frequency,
mode, data submode, passband and high-resolution signal reports, together
with diversity and Sub enable state. IF supplies global transmit state,
not receiver frequency or mode. A legacy PC push triggers a PCX read for
the explicit power range.

AI4 excludes changes made by this client, so setters read back the affected
state. Main changes also refresh Sub where the radio can couple their state.
Power, PTT, keyer speed and voice memories belong to the shared transmitter;
receiver selection does not change the radio's split transmit selection.

Main normally uses VFO A and Sub uses VFO B. With diversity enabled, both
receivers follow A; B remains available as a split transmit register. Sub
controls follow that receiver binding and refuse writes while diversity state
is unknown. A disabled Sub is reported as unavailable; HaLo does not enable it
automatically. Each panadapter's frequency window always comes from its PAN
header, independently of the receiver's tuned frequency and marker. This
distinction matters for fixed displays, split and diversity.

## Envelope and PAN payload

TCP reads may split or combine envelopes. Each envelope contains:

```text
FE FD FC FB | payload length (u32 big-endian) | payload | FB FC FD FE
```

The incremental decoder caps payloads at 64 KiB and resynchronizes corrupt
envelopes. The first three payload bytes are type, version and sequence.
Type 0/version 0 carries ASCII CAT; type 2 carries PAN. Audio (1), mini-pan
(3), and unknown types are counted and discarded.

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
resource bound rather than assuming a fixed sweep size. The shared presenter
handles both 1,024- and 2,048-bin sweeps, crops around the transmitted center
and uses the sample rate for the frequency width.

A1 leaves the PAN version, nested type and declared inner length ambiguous.
Those fields are preserved without imposing guessed validity rules. Bin
levels use the documented conversion above and are not calibrated dBm.

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

# Audio

HaLo carries a radio's audio itself: the radio's receive audio to the
operator's headphones, and the operator's microphone and the voice keyer's
recordings to the radio's transmitter. It does so over the radio's own network
link where it has one (a FlexRadio's DAX, an Elecraft K4's remote connection,
an Icom's LAN audio stream) and through a sound device where it does not (a
K3, an IC-7300 on USB). No virtual sound device sits between HaLo and a radio:
no DAX driver, no BlackHole, no Loopback. The same machinery carries audio
between two HaLo devices, and between HaLo and a program that is not HaLo —
a Jitsi meeting among them, through a page in the operator's browser.

Status: design. The file-only transmit path of the computer's voice keyer
([cat.md § The computer's voice keyer](cat.md#the-computers-voice-keyer)) is
what exists; everything below that it does not describe is to be built, in
the phases of § 12.

## 1. Scope

- **Desktop** (macOS, Windows, Linux) builds the engine. The C is kept
  portable — miniaudio runs on iOS and Android — but the mobile builds, with
  their audio sessions, permissions and background modes, come with the peer
  phase, when a phone as the listening end is the use. **The web** has no
  engine: it has no UDP and no FFI.
- **WebRTC is not in the app.** `flutter_webrtc` costs 12–29 MB per platform
  on an app of 70 MB zipped. Where WebRTC is the only way in (a Jitsi
  meeting), the operator's own browser runs it (§ 10).
- **Behind an experiment** (`audio`) until it ships. Neither tester notes
  nor release notes mention it before then.

## 2. The engine

`packages/halo_audio` grows from playing and recording files into a live
audio engine: miniaudio and a C core, driven from Dart over FFI.

**Dart configures; C moves samples.** Dart opens and closes endpoints, builds
the routes between them, sets gains, opens and shuts the transmit gate, and
runs every protocol's control plane — a Flex's `stream create`, an Icom's
handshake, a peer's offer — as the drivers do today. Every per-sample and
per-packet step runs on native threads: device callbacks, mixing, resampling,
jitter buffers, codecs, and the sending and receiving of audio datagrams. A
Dart isolate cannot hold a deadline of a few milliseconds: it shares its heap,
and its pauses, with the UI isolate, and its thread has no raised priority.
For live audio, whatever a sender holds ahead is added latency, so the
longest stall of the thread that sends sets the floor under mouth-to-ear
delay. A native sender needs one packet ahead; a Dart one, by estimate, three
or four.

**Threads.** Each sound device runs on miniaudio's real-time callback thread.
Each network endpoint has a receive thread (a blocking receive with a short
timeout, so it can be told to stop) and, when it transmits, a sender thread
that paces packets against the monotonic clock at raised priority
(`mach_wait_until` / `clock_nanosleep(TIMER_ABSTIME)` / a high-resolution
waitable timer). None of them allocates, locks a mutex, or calls into Dart.
They meet in single-producer single-consumer lock-free rings. Configuration
from Dart is posted to them as a new immutable route table, swapped in
atomically between periods; the old one is freed off the audio thread.

**Back to Dart only at human rates.** Levels for the meters, an endpoint's
statistics (depth, late and lost packets, the resampler's ratio) and its
failures are posted through a `NativeCallable.listener`, a few times a second
at most — never per packet.

**One internal format.** 48 kHz, 32-bit float. A source is mono or stereo;
the operator's mix is stereo. Every endpoint converts at its own edge: a
Flex's 24 kHz big-endian floats, a K4's 12 kHz 16-bit, an Icom's 48 kHz
16-bit, a sound card at whatever rate it runs.

## 3. The clocking rule

**Every boundary between two independent clocks has exactly one clock
bridge**: a jitter buffer feeding an adaptive resampler. A radio's sample
clock, each sound card's, each peer's and the host's monotonic clock are all
different crystals, tens of parts per million apart. Without a bridge, a
buffer between two of them fills or drains by a few milliseconds a minute,
and over a contest it drops out or grows a delay nobody chose.

**Every route is a bridge** (`halo_audio_engine.c`): a ring the source's
thread writes and the sink's thread reads through a cubic interpolator,
whose ratio — up to 2000 ppm either side of nominal, 3.5 cents, which no ear
hears on a voice — is steered to hold the ring's depth at a target. Two
routes from one source are two rings, so a sink that stops reading never
holds up another. The depth is measured at each read, averaged over half a
second, and steered by a proportional term (1000 ppm per 10 ms of error)
plus an integrator that learns the two clocks' steady drift; without it the
depth sits off its target by the drift, 2 ms at 200 ppm.

**The target is measured, not configured.** In one-second windows the
bridge records how far the depth dips below its average at the end of a
read (a packetized writer's sawtooth and the read period) and, when the ring
runs dry, how long the writer stalled (the depth it held plus the silence
after). The target is a 2 ms margin plus the deepest dip plus the longest
stall of the last twenty windows: a stall raises it at once, a repeat of it
finds the ring deep enough, and twenty seconds without one let it drain back
by resampling, never by cutting. A wired LAN settles it at a few
milliseconds; Wi-Fi's power-save bursts of 50–100 ms push it up, and that is
the right trade on Wi-Fi. How far it may go is the radio's Receive Audio Max
Buffering, on its equipment node under More: 40, 100, 250 (the default) or
500 ms, the route's maximum twice that. It is per radio because it is set
by the network the radio is reached over, and the operator is the one who
hears whether the delay or the dropouts are worse.

**Samples are dropped or inserted only at a fault, and never with a
click.** An empty ring holds the last value and fades it out over a
millisecond, then fills again: the first time to the route's start depth,
after that to its target, the wait past the start not counted as a stall.
Refilled only to the start, a ring grows back toward its target at
the steering's 2 ms a second, and a stall whose audio never comes runs it
dry again long before it gets there (Opus's loss concealment takes this
place for an Opus stream). A ring past the route's
maximum fades out, is cut back to its target, and fades in. A writer that
finds the ring full fades out the end of what fits and fades in when it can
write again; it keeps a fade's worth of room behind every whole write so
that the write that does not fit always has room to fade out. Each is
counted in the route's statistics.

What paces each side:

- **Receive** (radio → headphones) is paced by the output device: its
  callback pulls the mix, and each source's route is its bridge into it.
- **Transmit** (microphone → radio) is paced by the radio, which plays what
  arrives as it arrives. Where the radio also sends a stream, the rate its
  packets arrive at over many seconds is the radio's clock, and the sender
  can be slaved to it — the rate, not a timestamp: a Flex's `dax_rx`
  carries fill where its timestamps belong (§ 6). Until then the sender
  paces against the host's monotonic clock and re-anchors at every key,
  which a radio's buffer absorbs over an over's length. The bridge sits
  between the microphone and the sender.

## 4. Endpoints

An **endpoint** is anything audio enters or leaves the engine through. Each
says:

- its direction (source, sink or both), channels and native rate;
- its clock: a device, a remote clock it can estimate, or none it can see;
- its frame size, and how far ahead it must be fed (a sink) or how deep its
  bridge starts (a source);
- what it does with silence: a Flex on DAX transmits noise when nothing
  arrives and must be fed silence while keyed; a K4 keys on every audio
  packet and must be fed nothing outside the over (cat.md § The computer's
  voice keyer);
- its failures, posted to Dart with a reason the operator can act on, and
  routed through `ErrorPolicy` like the voice keyer's (`VoiceAudioFailure`).

The endpoint contract sits at the engine's rings. Framing a protocol's
packets is the endpoint's own business, so moving one endpoint's framing from
Dart to C (or back) changes nothing about routes, mixing or the UI.

**The engine owns an audio endpoint's socket.** A radio sends its audio to
the same UDP port as other traffic: a Flex's meters arrive on the client's
`udpport` with its `dax_rx`, and an Icom's audio session carries its own
handshake and keepalives. So the engine's datagram socket claims the packets
of the streams it has been told about (by VITA stream id, by session) and
queues every other datagram for Dart, which drains it as it drains a
`RawDatagramSocket` today. Dart sends its own datagrams (a keepalive, a
retransmit answer) through the same socket. A Flex session's meter socket
and an Icom's audio session move onto it.

## 5. Routes

A **route** joins a source to a sink with a gain and a mute. Two kinds of
route per radio:

- **Receive**: the radio's receive audio to the operator's output device.
  Under SO2R the ears are decided by the rule that already exists,
  `wantedSo2rAudio` and `so2rEarFor` (`so2r_audio.dart`), applied to each
  radio's receive route as pan and mute. That works for any two radios whose
  audio HaLo carries — a Flex and a K4 with no switcher box — and it joins
  the Station Configuration's switcher pick as a third kind beside a box and
  **Built into** a Flex.
- **Transmit**: the operator's microphone, and the voice keyer's recordings,
  to the radio's transmit audio, through the **transmit gate**.

**The transmit gate** opens only while HaLo holds that radio's key for the
operator's voice — the PTT key, a footswitch through HaLo, a voice keyer
message — as `CatKeying` already tracks it, and shuts when the key drops or
the radio reports it has dropped it. It ramps over 5 ms either way, so a gate
never clicks on the air. A live microphone never reaches a radio with the
gate shut, whatever the route says. Switching the radio's transmit source to
the computer (a Flex's `dax`, an Icom's DATA OFF MOD, a K4's `MI` or `EM`)
stays with the driver's `ComputerAudioPttSession`, with its read-back and its
owed restores, as it is for the voice keyer today.

**The operator talks through HaLo per radio, into one microphone.** The
station's microphone is one setting for the station (Station
Configuration, under the experiment), because the operator speaks into one
microphone whichever radio is keyed. Each radio's **Talk through HaLo**
says whether the operator's key on it sends that microphone. The
operator's key means the PTT key and anything else they key through HaLo.
A CAT server client's key stays a plain key, since a digital-mode program
sends its own DAX audio and HaLo's stream would take its place. On a Flex
the session owns a `dax_tx` stream on the engine's socket once it is bound
(`flex_dax_talk.dart`). The key claims it (`stream set tx=1`), starts
sending silence, opens the microphone and routes it in, then turns DAX on,
sends `xmit 1` and opens the gate. The unkey shuts the gate first, closes
the microphone once the gate's ramp is through, and keeps feeding silence
for 150 ms past the `xmit 0`. If the stream is not granted, or the
microphone will not open, nothing is keyed. The radio's own mic is not
what the operator is speaking into. The microphone is open only for the
over, so the system shows it listening only while HaLo transmits. The
operator hears whatever the radio's monitor puts on the slice's audio;
HaLo adds nothing of its own. The sender runs on the computer's clock and
is not slaved to the radio's: with the key capped at a minute, 50 ppm
comes to 3 ms.

**The voice keyer becomes a source.** A recording plays into the transmit
route through the gate like the microphone does, and `PacedTransmitAudio`'s
Dart pacing is retired once the live path has carried a message on air.

**CW sidetone is local.** The engine generates it from HaLo's own keying,
into the operator's mix, and never waits for the radio's monitor to come back
— over a peer or a meeting that round trip would be heard as lag.

## 6. Radio endpoints

| Radio | Receive | Transmit | Format | Evidence |
| --- | --- | --- | --- | --- |
| FlexRadio, `dax_rx` / `dax_tx` | per slice, a DAX channel | `dax_tx` stream owned by HaLo | 24 kHz stereo float32 BE, 128 frames; RX VITA type 3, TX type 1 | TX on air, RX captured over Wi-Fi (FLEX-6600) |
| FlexRadio, `remote_audio_rx` / `_tx` | the radio's own headphone mix | the mic through the radio's TX chain | Opus, or uncompressed | not captured |
| Elecraft K4, remote (9204) | inside the TLS connection | inside the TLS connection | TX: EM1 16-bit 12 kHz, 720 frames; RX: the connection's EM (EM3, Opus, unless set) | TX from QK4's source, not met on hardware |
| Icom, LAN audio (50003) | the audio session's stream | the same | 48 kHz 16-bit LE mono, 480 frames | from wfview's source, not met on hardware |
| Any radio, USB codec | a sound device | a sound device | the device's | miniaudio |

**FlexRadio receive uses DAX first.** A slice's `dax_rx` is the format already
captured, and it is per slice, so the engine mixes and the SO2R ears rule
applies to it like to any radio. It costs a DAX channel per slice, which the
operator's GUI client shows and which a digital-mode program may already be
using. So a slice already on a DAX channel is heard on that channel and
left on it; a slice on none gets the lowest channel no other slice holds
(`slice set <n> dax=<channel>`), and is taken off it when the stream stops
(flex_dax_rx.dart). A slice the operator moves to another channel is
followed there; one they take off DAX is let go, not put back. The take-off
is sent as the session stops; a link that dies first leaves the slice on the
channel — owing it by radio and slice for the next session, as the SO2R
switcher owes its restores, is still to do. The radio keeps playing its own
headphone mix to the GUI client; the operator mutes that there.

**The operator asks for it per receiver**, under the `audio` experiment:
each set's details offer **Listen to Audio** and **Microphone**, each **On
This Computer** (**On This Device** on a phone or tablet) or **On The
Radio**, for a driver whose sessions carry that audio
(`EquipmentDriver.carriesReceiveAudio`, `carriesTalkAudio`). Per receiver
because a slice of a Flex is an entry of its own, which the radio's editor
does not reach; the editor keeps only how far behind the radio's audio may
fall, which every slice of it takes. Where HaLo plays what it hears is the
app's, not a radio's: one output for the station, which every radio heard
in HaLo is mixed into. **Audio Mixing**, in Current Configuration once any
radio's audio goes through this computer, holds the mix's volume, each
radio's level (a route's gain is the two together, applied as a slider
moves and stored as its drag ends), the output and the station's
microphone. The session asks its sink for the engine
(`ReceiveAudioSink`) as it opens its UDP socket, so the meters' socket is
the engine's from the start — the slice's audio arrives on it — and a
change reconnects the receiver to take it. The stream is made only once the session is bound to the GUI
client and the slice has stated its channel.

**What a `dax_rx` stream carries**, captured on a FLEX-6600 (4.3.16) with
AetherSDR as the GUI client and slice A already on DAX 1: a bound client's
`stream create type=dax_rx dax_channel=1` answers `0x04000008`, and
`stream remove 0x04000008` ends it. Packets come to the client's `udpport`
at 187.5 a second — VITA type 3, class `0x00001C2D`/`0x534C03E3`, 263
words, 128 frames of 24 kHz stereo float32, big-endian — but the words
where the UTC seconds and the sample count belong hold fill (`0xa5a5a5a5`).
The header's 4-bit packet counter is the only sequence number.

**Over Wi-Fi the stream loses packets and holds them back.** Twenty seconds
of it, three times, from a Mac on Wi-Fi to that radio: 4–6.5% of the
packets never came (runs of 1 to 13 the counter sees, and longer ones it
cannot), and 63 gaps of more than 20 ms — up to 200 ms — held packets back
with nothing lost, then delivered them at once. The bridge's depth covers
the holding back (§ 3). The loss the endpoint covers itself: the counter
says how many packets are missing, and that many packets' worth of the
last one, repeated, take their place so the stream keeps its timeline.
Each repeat crossfades from the end of the one before over 1.3 ms, the
part of each packet held back for it, and the next packet crossfades in
from the repeat, so a lost packet or two sounds like the sound going on.
The repeat fades to silence after about 11 ms: longer, it is heard as a
buzz at its 4 ms period. Arrival time cannot stand in for the counter: a
gap of 200 ms with nothing lost looks like one with forty packets lost.
A run of sixteen or more lost reads as fewer, and the timeline is that
much shorter, which the bridge sees as a stall.

**`remote_audio_rx` / `_tx` come second**, from a read-only capture first:
whether a bound non-GUI client may open them at all, what `compression=none`
delivers, and whether the radio's speech processor and transmit EQ apply to
`remote_audio_tx` and not to `dax_tx`. For voice, that last answer may make
`remote_audio_tx` the better transmit path.

**A K4's receive audio** needs either Opus (libopus, BSD-licensed, which the
peer protocol needs anyway) or `EM1` for the whole connection. Whether EM
changes mid-connection is unconfirmed (k4-remote.md § Transmit audio).

**An Icom's receive audio** is already streaming once the audio session is
open, and dropped unread; the endpoint reads it instead. The session opens
for receive when a route wants it, not just for the voice keyer.

Every probe that keys a radio needs the operator's go-ahead each time, reads
`rfpower` first and says the figure. A Flex probe binds to the GUI client
(`client bind client_id=<gui>`) before reading or setting anything under
`transmit`. Protocol facts come from captures and vendors' public documents.

## 7. Sound-device endpoints

A sound device is an endpoint whose clock is its own: the operator's
headphones and microphone, and a radio's USB codec. Each is opened at its
native rate and channel count and bridged to the engine's format. Devices are
named as the voice keyer names them — miniaudio's id written as hex, with the
name stored beside it — and matched the same way (by id, then by a name no
two devices share). A device that goes away stops its routes and is looked
for again; the system default never stands in for a device the operator
picked.

## 8. Latency

Targets, mouth to ear, one direction; the measured figures replace these as
each phase lands.

| Path | Target |
| --- | --- |
| Microphone → Flex on the same wired LAN | ≤ 25 ms plus the radio's own |
| Flex → headphones | ≤ 25 ms plus the radio's own |
| HaLo → HaLo, wired LAN | 20–35 ms |
| HaLo → HaLo, Wi-Fi | what the jitter buffer settles at |

A device period of 5 ms (miniaudio's low-latency profile) on each sound
device, the packets a native sender keeps ahead, and a bridge's depth on
each receive are the budget's parts.

**A native sender wakes within a millisecond of its deadline.** The
`dax_tx` sender (`halo_audio_net.c`) sleeps to an absolute deadline every
5.33 ms on a thread miniaudio raises to real-time priority. On the
development Mac, idle, it woke 0.5 ms late on average and 0.7 ms at worst
over 400 ms (`net_test.dart` prints the figures each run); under load, and
on Windows and Linux, it is not yet measured. Most of that half
millisecond is a constant offset, not jitter, so two packets of silence
ahead of the first (10.7 ms) are a margin the radio's own buffer may make
unnecessary.

## 9. The peer and external audio protocol

HaLo-to-HaLo audio uses **UDP**, with the control on the existing peer link
(`peer_link_io.dart`). TCP would hold every later packet behind a lost one,
and for live audio a late packet is worth nothing.

**Control** messages travel on the peer WebSocket:

- `audioOffer`: what a device can send and take for each radio it offers
  (`catOffer`, `peer_remote_radios.dart`) — receive, transmit, the codecs.
  A peer offering a radio offers its audio with it.
- `audioOpen` / `audioOpened`: a stream's direction, codec, frame length,
  the UDP address and port each side sends from and listens on, a random
  stream id, and — for a sealed stream — a 32-byte key.
- `audioStats`: once a second from the receiver — loss, late packets, the
  bridge's depth — so the sender can change codec or frame length.
- `audioClose`.

**Datagrams**, all integers big-endian:

| Offset | Size | Field |
| --- | --- | --- |
| 0 | 2 | magic `0x4841` ("HA") |
| 2 | 1 | version, 1 |
| 3 | 1 | codec: 0 PCM s16, 1 PCM float32, 2 Opus |
| 4 | 4 | stream id, from `audioOpen` |
| 8 | 4 | sequence, wrapping |
| 12 | 4 | sample clock: the first frame's index at 48 kHz, wrapping |
| 16 | 1 | flags: bit 0 transmit gate open, bit 1 last packet of a stream, bit 2 sealed |
| 17 | 1 | channels |
| 18 | 2 | frames per channel |
| 20 | n | payload |
| 20 + n | 16 | authentication tag, on a sealed stream only |

**Sealing is optional, per stream.** A sealed stream encrypts its payload
with ChaCha20-Poly1305 (Mbed TLS, already vendored in
`packages/halo_tls_psk`) under the stream's key, with the header as
associated data and the stream id and sequence as the nonce; it is reopened
under a new key before its sequence wraps. **Encrypt audio**, a station
setting, is on by default. Between two HaLo devices a stream is sealed when
either side's setting asks for it, so turning it off takes both ends. An
external program may open a stream unsealed — a protocol it can speak with
nothing but a socket — and HaLo accepts that only while its own setting is
off. Loopback is never sealed: it never leaves the machine. Unsealed, the
audio is in the clear on the LAN, which is no more than the air carries once
it is transmitted.

**What is guarded either way is the transmitter**: a stream takes datagrams
only from the address and port its `audioOpen` named, carrying its random
stream id (and, sealed, a valid tag), and drops everything else uncounted, so
a stray sender on the LAN cannot put audio on the air. A key sent over the
peer link, which is plain WebSocket, keeps out a sender who cannot read the
link, not one who can read the LAN. **Opus** runs in its restricted-low-delay mode with
10 ms frames, in-band FEC on when the receiver reports loss; raw PCM is
offered for a wired LAN, where 768 kbit/s per mono stream costs nothing and
saves the codec's few milliseconds.

A stream exists only between devices the peer link has admitted (the
trusted-device confirmation, shared-operations.md § 6.6). **Phase 3 is LAN
only**, like the peer link.

**External programs** use the same datagrams on UDP. A browser has no UDP,
so on loopback the same datagrams travel as binary WebSocket messages, one
per message, from a listener HaLo binds to `127.0.0.1` alone. That listener
admits a page that presents the per-launch token in its URL and whose Origin
is the page HaLo served; unlike the peer listener, which refuses any request
carrying an Origin, it exists for browser pages.

## 10. The Jitsi adapter

A meeting on a Jitsi server carries a station's audio in and out — N2QV's
runs on a self-hosted Jitsi Meet — and HaLo joins it as an equipment node,
**Jitsi audio**, with the meeting's URL, paired with that station's radio
(for N2QV, its Serial over TCP CAT). The node is an endpoint like a radio's:
its receive is the meeting's audio, its transmit what HaLo sends into it.

**The meeting runs in the operator's browser.** HaLo serves a page on
loopback; opening the node opens it. The page loads the server's own
`lib-jitsi-meet`, joins the meeting, and moves audio between the meeting and
HaLo over the loopback WebSocket of § 9, through an AudioWorklet. The
outgoing track is synthesized from what HaLo sends, never captured from a
microphone, so the browser's echo cancellation, noise suppression and gain
control never touch it.

**HaLo proxies the Jitsi server.** The page reaches the server's scripts,
`config.js` and `xmpp-websocket` through HaLo at the page's own origin, and
HaLo forwards them to the server. A page on loopback fetching from the server
directly meets three walls at once: XMPP servers commonly refuse a
cross-origin WebSocket, the browser's private-network rules, and a
self-signed certificate (N2QV's is) that the browser has not been told to
accept. Through the proxy, the page sees one origin, and HaLo accepts the
node's certificate by its fingerprint, which the operator confirms on the
first connect and the node keeps. The media itself — WebRTC's UDP to the server's videobridge, or to a peer
— goes direct from the browser and is not proxied.

**Joining puts the operator in front of the meeting's other members, and
what it sends may go on the air.** Testing against a real station's meeting
asks the operator first, every time.

Unproven until a spike: Safari's AudioWorklet and WebRTC timing; how far
the browser's own jitter buffer adds to HaLo's; whether a meeting with P2P
on behaves differently with two members than with three.

## 11. What changes in the code

- `NetworkTransmitAudioSession` (`driver.dart`) grows into a two-way live
  radio audio session: an endpoint for receive and transmit, with the file
  path folded into it as a source.
- `flex_dax_tx.dart`'s stream handling moves onto the engine's socket and
  sender; the Flex session's meter packets arrive from the engine's queue.
- `icom_lan_audio.dart`'s session runs on the engine's socket, reading its
  receive stream instead of dropping it.
- `k4_remote_audio.dart` feeds and drains engine rings from the TLS
  connection, which stays in Dart; a K4's 60 ms packets make a Dart stall a
  small part of its budget.
- `cat_so2r_audio.dart` gains the engine as a switcher.

## 12. Phases

1. **The engine and the Flex.** Live rings, routes, the bridge, devices,
   the transmit gate, the native datagram socket and sender; Flex `dax_rx`
   per slice to the headphones, the live microphone to `dax_tx`. Done when
   the operator hears a slice in HaLo and talks on the air from HaLo with no
   DAX driver or virtual device on the machine, and the bridge's drift and
   the measured latency are written here.
2. **K4 and Icom receive**, and Flex `remote_audio` captured (and built if
   it wins for voice). libopus vendored.
3. **The peer protocol**: a station-side HaLo beside the radio, the
   operator's HaLo elsewhere on the LAN; mobile builds of the engine.
4. **The external endpoint and the Jitsi adapter.**

## 13. Open

- Whether DAX transmit audio passes the Flex's speech processor and transmit
  EQ (a listen on air, with the operator's go-ahead).
- Whether a bound non-GUI client may open `remote_audio_rx` / `_tx`.
- The DAX channel commands for a slice, from the wiki, confirmed by a capture
  that asks first.
- Whether a K4 takes EM changed mid-connection, and whether it streams
  receive audio at EM1.
- Peer audio beyond the LAN, which waits on the peer link itself.

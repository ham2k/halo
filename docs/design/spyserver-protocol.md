# Airspy SpyServer network protocol — clean-room specification

What the app does with it, and which of the open questions below it
assumes an answer to: [cat.md § SDR receivers](cat.md#sdr-receivers).

Status: compiled 2026-10-14 from independent open-source clients, two server
emulations, published wire captures of the official server, and Airspy's own
documentation. It is a description of the wire protocol only, written so that a
client can be implemented without reading any client source. Section 11 lists the
sources and their licences; every non-obvious fact carries a source tag in square
brackets (key in §11). Where sources disagree or are silent, the text says so.
Section 12 records what this app measured against public servers on 2026-11-02;
where a measurement overturned a source, the text now follows the measurement.

Confidence markers used below:

- **[wire]** confirmed by a byte capture against the official `spyserver` binary.
- **[multi]** stated identically by several independent implementations.
- **[single]** one source only, or an inference; treat as provisional.
- **[probe]** measured by this app against public servers (§12).

---

## 1. Transport basics

| Item | Value |
|---|---|
| Transport | One TCP connection per client. Default port **5555** (`bind_port` in `spyserver.config`). |
| Byte order | **Little-endian** for every multi-byte integer and float, both directions. [multi][wire] |
| Integer width | Every header field and every setting value is an unsigned 32-bit integer. |
| Framing | Length-prefixed messages; there are **no sync markers, magic bytes or checksums**. |
| Session identity | None. The TCP connection is the session. |
| Flow control | None at the application level. The server pushes; TCP back-pressure is the only throttle. When a client falls behind, the server drops buffers (visible as sequence gaps, §7.5). |

### 1.1 Client → server: command frame

Every command is an 8-byte header followed by a body.

| Offset | Size | Field | Meaning |
|---|---|---|---|
| 0 | 4 | CommandType | See §3. |
| 4 | 4 | BodySize | Number of body bytes that follow (may be 0). |
| 8 | BodySize | Body | Command-specific. |

The protocol constant for the largest command body is **256 bytes**. No command
a client needs comes close; keep the HELLO name short (≤ 252 bytes). Several
commands may be concatenated in a single TCP write; the official server parses
them back-to-back [wire].

### 1.2 Server → client: message frame

Every message is a 20-byte header followed by a body.

| Offset | Size | Field | Meaning |
|---|---|---|---|
| 0 | 4 | ProtocolID | Server protocol version, packed as `major << 24 | minor << 16 | build`. Observed: 2.0.1700 (`0x020006A4`), 2.0.1822 (`0x0200071E`), 2.0.1922 (`0x02000782`). [wire] |
| 4 | 4 | MessageType | **Low 16 bits** = message kind (§5). **High 16 bits** = a flags word; on IQ sample messages it carries the digital gain the server applied, in whole dB (§7.3). Always mask before comparing. [multi][wire] |
| 8 | 4 | StreamType | 0 = status/control (device info, client sync, pong), 1 = IQ, 2 = AF, 4 = FFT. |
| 12 | 4 | SequenceNumber | Increments per IQ message; 0 on status messages; observed always 0 on FFT messages. See §7.5. |
| 16 | 4 | BodySize | Number of body bytes that follow (may be 0, e.g. a PONG to an empty PING). |
| 20 | BodySize | Body | Message-specific. |

- **Maximum body size**: the protocol constant is **1 MiB (1,048,576 bytes)**. A
  header announcing more is a framing error.
- **Version check**: clients check that the major number is 2 (most also check
  minor = 0) and ignore the build number. A 2.0.1922 server accepts a client
  announcing 2.0.1700, and 2.0.1700 is what nearly every open client sends [wire].
- **Resync**: impossible. With no markers, one byte out of step turns every
  later "header" into garbage. On any framing error (wrong major version, body
  size above 1 MiB, unparseable required message) **drop the connection and
  reconnect**. [multi]
- A body may arrive split across any number of TCP reads, and one read may
  contain many messages; reassemble by the header's BodySize. A zero-length body
  must complete the message immediately (do not wait for body bytes). [multi]
- **Unknown message kinds must be skipped** (read and discard BodySize bytes),
  never treated as fatal. Newer servers send kinds older clients do not know.

---

## 2. Handshake

### 2.1 Sequence

1. Client opens TCP to port 5555 (disable Nagle; commands are tiny).
2. Client sends **HELLO** (command 0).
3. Server replies with **DEVICE_INFO** (message 0) and then **CLIENT_SYNC**
   (message 1), immediately and in that order [wire]. Both have StreamType 0 and
   SequenceNumber 0.
4. Client sends its settings (§4), finishing with STREAMING_ENABLED = 1.
5. Server streams IQ and/or FFT messages until STREAMING_ENABLED = 0 or disconnect.

Timeouts used by clients for step 3 range from 1 s to 5 s; 5 s is the safer
choice (a server may open the radio first, which on a small ARM board is slow)
[sdroxide].

**Failure modes** observed:

- **Server busy** (`maximum_clients` reached) **or server has no radio**: the
  server accepts the TCP connection and the HELLO, then closes the connection
  without sending anything. The two cases are indistinguishable on the wire
  [wire, VibeSDR]. Report "server busy or no device".
- **DEVICE_INFO with DeviceType 0**: "server is up but no device is available".
  Abort. [multi]
- `maximum_session_duration` in the server config (minutes) makes the server end a
  session after that time [config]. Expect a plain close.

### 2.2 HELLO (client → server, command 0)

Body:

| Offset | Size | Field | Meaning |
|---|---|---|---|
| 0 | 4 | ProtocolVersion | Client's protocol version, packed as above. Send **2.0.1700 = `0x020006A4`** (bytes `A4 06 00 02`). |
| 4 | BodySize − 4 | ClientName | Raw bytes (ASCII/UTF-8), **no NUL terminator, no length prefix**; its length is implied by BodySize. [wire] |

Servers log the name and some operators allow-list on it, so send something
recognisable. (One historical header declared a separate name-length field after
the version; no client sends it and the official server does not expect it.)

Example, name `HaLo`: `00 00 00 00 | 08 00 00 00 | A4 06 00 02 | 48 61 4C 6F`.

### 2.3 DEVICE_INFO (server → client, message 0)

Body: 12 × u32 = **48 bytes** [wire]. Parse the first 48 bytes; tolerate a longer body.

| Offset | Field | Meaning |
|---|---|---|
| 0 | DeviceType | 0 = invalid/no device, 1 = Airspy One (R0/R2/Mini), 2 = Airspy HF+ (Dual Port, Discovery, Ranger), 3 = RTL-SDR. Treat other values as "unknown device", not as an error. |
| 4 | DeviceSerial | 32-bit serial. RTL-SDR servers report small numbers (0 or 1 seen); an HF+ server reported four ASCII bytes ("2011"). Informational only. (The config file takes a 64-bit serial; how it is reduced to 32 bits is unknown.) |
| 8 | MaximumSampleRate | Device IQ sample rate in S/s at decimation 0 (e.g. RTL 2,400,000; HF+ 768,000; Airspy R2 10,000,000 or 2,500,000; Mini 6,000,000 or 3,000,000). |
| 12 | MaximumBandwidth | Usable analog bandwidth in Hz at decimation 0, below the sample rate because of filter roll-off (RTL at 2.4 MS/s: 2,000,000; HF+: 660,000). **This, not the sample rate, is the FFT span** (§6). |
| 16 | DecimationStageCount | Number of halving stages; valid decimation indices run up to this value (see note below). Observed: RTL 9, HF+ 8; Airspy One reportedly 11. |
| 20 | GainStageCount | Observed 0 on RTL and HF+ servers. Meaning unclear; no client uses it. |
| 24 | MaximumGainIndex | Largest value accepted by the GAIN setting (index, not dB). RTL R820T/R828D 29 (some report 28), E4000 14, Airspy One 21, HF+ 0 or 8 depending on server/version. 0 means "no gain control". |
| 28 | MinimumFrequency | Lowest tunable frequency, Hz (RTL 24,000,000; HF+ 0). |
| 32 | MaximumFrequency | Highest tunable frequency, Hz (RTL 1,800,000,000 or 1,766,000,000; HF+ 1,700,000,000 or 260,000,000). Both bounds follow `minimum_frequency` / `maximum_frequency` / `converter_offset` in the server config. |
| 36 | Resolution | ADC bit depth (RTL 8, Airspy One 12, HF+ 16 or 18). Describes the ADC, not the wire format. |
| 40 | MinimumIQDecimation | Lowest decimation index the server allows for IQ. Non-zero when the operator set `maximum_bandwidth` in the config (HF+ example: 2). Does not apply to the FFT (§6.2). |
| 44 | ForcedIQFormat | 0 = client may choose the IQ format; otherwise the format the server insists on (1 = uint8, set by `force_8bit = 1`). |

Captured examples [wire, Kiwi]:

- RTL-SDR, server 2.0.1822: type 3, serial 1, 2,400,000 S/s, 2,000,000 Hz bw,
  9 stages, 0 gain stages, max gain index 29, 24 MHz – 1800 MHz, 8 bits, min IQ
  decimation 0, forced format 0.
- Airspy HF+, server 2.0.1700: type 2, serial "2011", 768,000 S/s, 660,000 Hz bw,
  8 stages, 0, 0, 0 Hz – 1700 MHz, 16 bits, min IQ decimation 2, forced format 1.

**Decimation index range.** IQ (and FFT) rate at index *n* is
`MaximumSampleRate / 2^n`. Clients disagree on whether the top index is
`DecimationStageCount` (inclusive: SDR++, gr-osmosdr, SDRangel, a server
emulation) or `DecimationStageCount − 1` (exclusive: spy2go, r2cloud). Offer
`MinimumIQDecimation … DecimationStageCount` inclusive, and treat the very top
index as possibly unsupported (a server that rejects it simply clamps; see §7.2).

### 2.4 CLIENT_SYNC (server → client, message 1)

Body: 9 × u32 = **36 bytes** on servers 2.0.1700/2.0.1822 [wire, Kiwi]; a 2.0.1922
server sent **40 bytes** (a 10th word of unknown meaning) [wire, VibeSDR]. Parse
the first 36 bytes and ignore any extra.

| Offset | Field | Meaning |
|---|---|---|
| 0 | CanControl | 1 = this client may retune the device and change its RF gain; 0 = spectator (§7.1). |
| 4 | Gain | Current device gain index. |
| 8 | DeviceCenterFrequency | Where the hardware is tuned, Hz. |
| 12 | IQCenterFrequency | Current centre of this client's IQ channel, Hz. |
| 16 | FFTCenterFrequency | Current centre of this client's FFT window, Hz. |
| 20 | MinimumIQCenterFrequency | Lowest IQ_FREQUENCY the server will honour now, Hz. |
| 24 | MaximumIQCenterFrequency | Highest IQ_FREQUENCY the server will honour now, Hz. |
| 28 | MinimumFFTCenterFrequency | Lowest FFT_FREQUENCY the server will honour now, Hz. |
| 32 | MaximumFFTCenterFrequency | Highest FFT_FREQUENCY the server will honour now, Hz. |

How the bounds are computed (derived from captured values, consistent across
three captures [wire, Kiwi]; [single] as a general rule):

- IQ channel width at decimation *d* is `MaximumBandwidth / 2^d`; the IQ bounds
  are `MinimumFrequency + width/2` and `MaximumFrequency − width/2`.
  (RTL, d = 5: 2 MHz / 32 = 62.5 kHz → bounds 24,031,250 … 1,799,968,750 Hz.
  HF+, d = 2: 165 kHz → 82,500 … 1,699,917,500 Hz.)
- FFT window width at FFT decimation *f* is `MaximumBandwidth / 2^f`; FFT bounds
  are `MinimumFrequency + width/2` and `MaximumFrequency − width/2`
  (RTL, f = 0: 25,000,000 … 1,799,000,000 Hz).
- These whole-range bounds are what a controlling client sees. For a spectator
  the IQ bounds should narrow to the part of the device's current passband the
  channel can slide in; that is an inference, not captured.
- Some servers leave the min/max fields zero, and one client author found the
  initial min/center/max IQ all equal until an IQ_DECIMATION setting had been
  sent [miweber]. Validate before trusting them; fall back to the geometry above.

---

## 3. Commands (client → server)

| Value | Name | Body | Notes |
|---|---|---|---|
| 0 | HELLO | §2.2 | First and only once per connection. |
| 1 | GET_SETTING | unknown | Listed in protocol enumerations; no client sends it, layout unknown. Do not use. |
| 2 | SET_SETTING | 8 bytes: u32 SettingId, u32 Value | §4. The only way to change anything. |
| 3 | PING | empty, or an 8-byte token | Server answers PONG (message 2, StreamType 0) whose body echoes the PING body verbatim (an 8-byte body was seen echoed [wire]; an empty one yields an empty PONG [sdroxide]). |

There are **no acknowledgements and no error replies**. A setting the server
rejects or clamps is silently clamped or ignored (§7.2).

SET_SETTING example, FFT_DISPLAY_PIXELS = 1024:
`02 00 00 00 | 08 00 00 00 | CD 00 00 00 | 00 04 00 00`.

---

## 4. Settings (SET_SETTING ids)

All values are u32. "Control" = takes effect only when CanControl = 1.

| Id | Name | Value encoding and semantics |
|---|---|---|
| 0 | STREAMING_MODE | Bitmask of streams wanted: 1 = IQ only, 2 = AF only, 4 = FFT only, 5 = FFT + IQ, 6 = FFT + AF. SDR++ sends 1; SDR# sends 5 [wire]. See §6.6 about mode 4. |
| 1 | STREAMING_ENABLED | 0 = stop, 1 = start. Settings may be sent before or while streaming. |
| 2 | GAIN | Device gain **index** 0 … MaximumGainIndex (not dB; the protocol never conveys the dB table). **Control.** Ignored for spectators. |
| 100 | IQ_FORMAT | 1 = uint8, 2 = int16, 3 = int24, 4 = float32 (5 = dint4 exists in the format enumeration; never used for IQ). Must match ForcedIQFormat when that is non-zero. The IQ message kind is `99 + IQ_FORMAT` [wire]. |
| 101 | IQ_FREQUENCY | Centre of this client's IQ channel, Hz. Clamped into [MinimumIQCenterFrequency, MaximumIQCenterFrequency]. In IQ-only mode with control this retunes the device; see §6.5 for how it interacts with the FFT. |
| 102 | IQ_DECIMATION | Index *n*; IQ rate becomes `MaximumSampleRate / 2^n` [wire]. Valid range §2.3. |
| 103 | IQ_DIGITAL_GAIN | Digital gain applied by the server before quantising IQ for the wire. Explicit values are whole dB (clients send 0 … ~60). **`0xFFFFFFFF` = automatic** (SDR# uses it [wire]; one client states RTL-SDR servers "won't work" without it, likely meaning 8-bit IQ is otherwise too quiet). The gain actually applied is reported per message in the header flags (§7.3). |
| 200 | FFT_FORMAT | 1 = uint8 (use this). 5 = dint4 (4-bit, undocumented encoding, no open decoder). The FFT message kind is `300 + FFT_FORMAT` [wire]. |
| 201 | FFT_FREQUENCY | Centre of this client's FFT window, Hz. Clamped into [MinimumFFTCenterFrequency, MaximumFFTCenterFrequency]. Independent of IQ_FREQUENCY [wire]. |
| 202 | FFT_DECIMATION | Index *f*; FFT window spans `MaximumBandwidth / 2^f` (§6.2). Range 0 … DecimationStageCount; not limited by MinimumIQDecimation. |
| 203 | FFT_DB_OFFSET | Byte 255 stands for **minus** this many dB (§6.3) [probe]. Protocol limit 0 … 100. SDR# sends 0. |
| 204 | FFT_DB_RANGE | dB span mapped across bytes 0 … 255 (§6.3). Protocol limits 10 … 150. SDR# sends 140; other clients 127. |
| 205 | FFT_DISPLAY_PIXELS | Number of bins per FFT frame. Protocol limits 100 … 32,768 (2^15). The server reduces its internal FFT to exactly this count [wire]. SDR# sends its window width (1024, then 1534 after a resize). |
| 206 | (unidentified) | SDR# 2.0.1921 sends 0. Meaning unknown. Do not send. [wire, VibeSDR] |
| 207 | (unidentified) | SDR# 2.0.1921 sends 100,000,000 (looks like a frequency). Meaning unknown. Do not send. [wire, VibeSDR] |

Out-of-range values: send only values inside the limits above. A server that
clamps silently leaves the client decoding against numbers the server did not
use (relevant for dB offset/range, §6.3) [sdroxide].

Which settings need control: GAIN for certain; retuning the **device** (via
IQ_FREQUENCY in IQ mode or FFT_FREQUENCY in FFT mode) is limited to the current
passband for spectators. Everything that only shapes this client's own streams
(formats, decimations, pixels, dB window, digital gain, streaming mode/enabled)
works for spectators. [multi, partly inferred]

---

## 5. Message kinds and stream types

Message kind = MessageType & 0xFFFF.

| Kind | Name | StreamType | Body |
|---|---|---|---|
| 0 | DEVICE_INFO | 0 | §2.3 |
| 1 | CLIENT_SYNC | 0 | §2.4 |
| 2 | PONG | 0 | Echo of the PING body (often empty). |
| 3 | READ_SETTING | 0 | Reply to GET_SETTING; layout unknown, never observed. |
| 100 | UINT8_IQ | 1 | Interleaved I, Q bytes (§7.3). |
| 101 | INT16_IQ | 1 | Interleaved I, Q little-endian int16. |
| 102 | INT24_IQ | 1 | 24-bit IQ; no open client decodes it, encoding unverified. Do not request. |
| 103 | FLOAT_IQ | 1 | Interleaved I, Q little-endian IEEE-754 float32. |
| 200–203 | UINT8/INT16/INT24/FLOAT _AF | 2 | Audio stream. Enumerated only; no client or capture shows a server producing it. Ignore. |
| 300 | DINT4_FFT | 4 | 4-bit FFT, undocumented. Skip. |
| 301 | UINT8_FFT | 4 | One byte per bin (§6). |

| StreamType | Meaning |
|---|---|
| 0 | Status / control messages |
| 1 | IQ |
| 2 | AF (audio) |
| 4 | FFT |

STREAMING_MODE values are bitwise ORs of the stream types (1, 2, 4, 5, 6).

---

## 6. FFT stream

### 6.1 One frame

- One UINT8_FFT message (kind 301, StreamType 4) = **one spectrum line**.
- BodySize = **FFT_DISPLAY_PIXELS** exactly, one unsigned byte per bin [wire].
- SequenceNumber has always been 0 on FFT messages [wire, miweber]; do not use it.
- High 16 bits of MessageType observed 0 on FFT messages [wire].

### 6.2 Frequency geometry

Measured against a known carrier on the official server [wire, VibeSDR],
generalised to *f* > 0 by one client [sdroxide], and confirmed for *f* = 1 … 3
on HF+, Airspy One and RTL-SDR servers [probe]:

- **Centre** = FFT_FREQUENCY (as clamped; also reported as FFTCenterFrequency in
  CLIENT_SYNC). It is **not** the IQ frequency.
- **Span** = `MaximumBandwidth / 2^f`, where *f* = FFT_DECIMATION.
  At *f* = 0 this is verified on the wire: RTL-SDR at 2.4 MS/s gives a 2.0 MHz
  span; assuming the sample rate (2.4 MHz) put a broadcast carrier ~47 bins off.
  The `/2^f` part for *f* > 0 holds [probe]: on an HF+, where
  MaximumBandwidth (660 kHz) and 0.8 × the sample rate (614 kHz) differ, only
  the former lines the sweeps up with the full-width one. Clients commonly
  *label* the choices by `MaximumSampleRate / 2^f`, but the axis must use the
  bandwidth figure.
- **Order**: ascending frequency. Bin 0 is the lowest frequency
  (`centre − span/2`); the last bin is the highest. No FFT-shift is needed; DC
  sits in the middle of the frame.
- **Bin width** = span / FFT_DISPLAY_PIXELS (e.g. 2,000,000 / 1534 ≈ 1304 Hz).
  Frequency of bin *i* ≈ `centre − span/2 + i × span / pixels`. Whether that is
  the bin's edge or centre is not established (the verification was good to
  about one bin).
- Older guidance (spy2go) used 0.8 × the decimated sample rate as the span; that
  is an approximation of the same idea (RTL ratio 2.0/2.4 = 0.833, HF+ ratio
  660/768 = 0.859). Prefer MaximumBandwidth.
- The FFT window has its own bounds (CLIENT_SYNC fields 28/32). At *f* = 0 a
  spectator's FFT window covers the whole device passband and is pinned to the
  device centre [sdroxide].

### 6.3 Byte → dB mapping

Two independent sources give `FFT_DB_OFFSET − FFT_DB_RANGE + raw × range/255`
[VibeSDR (observation, "probable"), sdroxide]. The offset's sign is wrong:
raising FFT_DB_OFFSET from 0 to 20 with range 140 **raised** the mean byte by
30–36 on four servers, where that formula predicts −36.4 [probe]. So:

> dB = −FFT_DB_OFFSET − FFT_DB_RANGE + raw × FFT_DB_RANGE / 255

i.e. byte 255 = −FFT_DB_OFFSET, byte 0 = −FFT_DB_OFFSET − FFT_DB_RANGE, linear in
between. With the offset at 0, as SDR# sends it, the two agree. With offset 0 and range 140, a strong local FM broadcast on an RTL-SDR
read about −32 dB at the peak and −78 dB at the floor (raw 196 and 106), i.e. the
scale behaves like dB relative to full scale. Absolute calibration is not
established. Values outside the window saturate at 0 or 255 (assumed). An earlier
brief proposed `offset + raw/255 × range`; it predates the captures and is
superseded. Always decode with the offset/range values **you sent** (after
clamping to the protocol limits).

### 6.4 Frame rate

Set by the server operator, not by the client: `fft_fps` in `spyserver.config`
(**15** in the v1700 sample config, 20 in older ones) [config]. No known setting
changes it (settings 206/207 are unidentified). `fft_bin_bits` (default 16, i.e.
65,536 internal bins) is server-internal; the client only sees
FFT_DISPLAY_PIXELS bins [config, wire]. Bandwidth cost ≈ pixels × fps bytes/s
(1024 px × 15 fps ≈ 15 KB/s).

### 6.5 FFT centre vs IQ centre vs device centre

- FFT_FREQUENCY and IQ_FREQUENCY are independent: FFT at 96.3 MHz with IQ at
  96.6 MHz delivered both correctly at the same time [wire]. SDR# parks the FFT
  on a wide view and slides IQ_FREQUENCY to follow its VFO.
- With the FFT stream enabled and control held, the **device follows the FFT
  window**; IQ_FREQUENCY is then only a position inside the band the device is
  on, clamped to it — and the clamped absolute value sticks [sdroxide]. Seen
  on the wire: moving FFT_FREQUENCY moved DeviceCenterFrequency in the next
  CLIENT_SYNC [probe].
  Consequence: when retuning, send **FFT_FREQUENCY first, then IQ_FREQUENCY**.
- In IQ-only mode (1), IQ_FREQUENCY retunes the device directly (SDR++,
  gr-osmosdr, r2cloud all tune this way) [multi].

### 6.6 FFT-only mode

One client author reported that the server he used sent **no FFT data in
FFT-only mode (4)**, and had to use mode 5 with the IQ cut down as far as
possible [miweber]. The official client (SDR#) uses mode 5 [wire]. Mode 4 sent
nothing — no FFT, no IQ — on 2.0.1822 and 2.0.1922 servers [probe]. Use mode 5;
in it IQ messages arrive even when unused; discard them.

**The IQ cannot be cut down all the way on older servers.** Servers 2.0.1700
and 2.0.1822 sent no FFT at all while the IQ rate was 12 kS/s or less, and did
at 19.5 kS/s or more — on HF+ and Airspy One, at every pixel count, order,
format and HELLO version tried. Servers 2.0.1920 and later send the FFT at
the narrowest IQ [probe]. Against a server older than 2.0.1920 (its build is
the low 16 bits of every header's ProtocolID), use the largest IQ decimation
whose rate `MaximumSampleRate / 2^n` is still ≥ 20 kS/s.

---

## 7. Behaviour details

### 7.1 Control and multiple clients

- A spectator's FFT bounds in CLIENT_SYNC are the **intersection** of the
  device's whole range (`MinimumFrequency + span/2 … MaximumFrequency − span/2`)
  and what it hears (`DeviceCenterFrequency ± (MaximumBandwidth − span)/2`) —
  seen on a server whose operator narrowed the range below the device's
  passband [probe]. The intersection can be empty; such a server then reports a
  minimum above its maximum.
- Official documentation: "When only one client is connected, full control
  (center frequency, gain) is granted. When there are more than one client
  connected, the center frequency of the device and the RF gain are locked."
  [airspy.com]. `allow_control = 0` in the config denies control to everyone;
  `maximum_clients` caps sessions (10 in the v1700 sample config) [config].
- The client learns its status from CanControl in CLIENT_SYNC. Whether the first
  client's CanControl drops to 0 when a second joins (as the documentation
  implies) has not been captured. Treat CanControl as able to change at any time.
- Without control: GAIN is ignored; the device centre does not move; IQ and FFT
  windows may still be placed, but only inside what the device is receiving,
  bounded by the CLIENT_SYNC min/max fields; requests outside are clamped
  silently [multi: miweber, r2cloud, gr-osmosdr, sdroxide].
- Spectators should adopt the server's Gain and DeviceCenterFrequency from each
  CLIENT_SYNC. A controlling client should **not** adopt the Gain from the
  opening CLIENT_SYNC (it is whatever the server was left at) — send its own
  [sdroxide].

### 7.2 When the server sends CLIENT_SYNC

Sources disagree; design for "any time, or never again":

- Always: right after DEVICE_INFO in the handshake [wire].
- A 2.0.1922 server did **not** re-send it after the client's own settings
  changes; its IQ/device-centre fields went stale immediately [wire, VibeSDR].
  Other servers of 2.0.1822 to 2.0.1922 **did**, after IQ_DECIMATION,
  FFT_DECIMATION and FFT_FREQUENCY changes, with the new bounds and device
  centre [probe] — so the two cannot be told apart by version.
- One older-server user found a fresh CLIENT_SYNC with corrected IQ bounds only
  after sending IQ_DECIMATION (needed ~2 s wait) [miweber].
- SDRangel handles CLIENT_SYNC mid-stream and adopts its IQ centre and gain,
  implying servers send it when another client changes the shared state.
- Recommendation: track the values you asked for (clamped by your own copy of
  the bounds) as the truth for your own windows; use any CLIENT_SYNC that arrives
  to update CanControl, Gain, DeviceCenterFrequency and the bounds. Never block
  waiting for one after the handshake.

### 7.3 IQ sample semantics

- Interleaved I then Q per complex sample, I first. Samples per message =
  BodySize / (2 × bytes per component). Message sizes vary with rate and server
  buffering (e.g. RTL: 1472 samples per message; HF+: 1920) — do not assume one.
- **uint8** (kind 100): offset binary, mid-scale 128. Normalised value
  `(b − 128) / 128`.
- **int16** (kind 101): signed little-endian. Normalised `v / 32768`.
- **float32** (kind 103): little-endian IEEE float, nominally ±1.0 full scale.
- **int24** (kind 102): unverified; avoid.
- **Digital gain flags**: the high 16 bits of MessageType on an IQ message are
  the digital gain the server applied, in whole dB. Captured values match the
  requested IQ_DIGITAL_GAIN exactly (SDR++ requested 6, 12, 15 dB; the headers
  carried 6, 12, 15) [wire, Kiwi]; with automatic gain (0xFFFFFFFF) they wander
  (11 … 46 seen) [wire, VibeSDR]. To recover levels independent of the gain,
  **divide** integer samples by `10^(flags/20)` after normalising [multi].
  For float32 there is a conflict: SDR++ (and one test tool) multiply by that
  factor; sdroxide divides and states that a measurement against a real server
  showed float samples arriving 10× larger at 20 dB, i.e. pre-amplified like the
  integer formats. Dividing is the consistent choice; verify against a live
  server. Use the flags from each message's own header, not the value last
  requested (they differ while a change is in flight).
- **Recommended IQ_DIGITAL_GAIN**: the widely-copied reference formula is
  `3.01 dB × decimation index` (each halving gains ~3 dB of processing gain),
  plus, for Airspy One only, `MaximumGainIndex − gain index`. Or send
  0xFFFFFFFF and rely on the header flags. With int16/float the choice matters
  little; with uint8 it decides how many of the 8 bits carry signal.
- **Rate** = `MaximumSampleRate / 2^IQ_DECIMATION` exactly (2.4 MS/s at index 4
  measured 150,000 S/s) [wire]. Usable bandwidth inside it ≈
  `MaximumBandwidth / 2^IQ_DECIMATION`; the rest is filter roll-off.
- **Centre constraints**: IQ_FREQUENCY must lie within the CLIENT_SYNC IQ bounds;
  outside values are clamped silently.

### 7.4 Changing settings while streaming

- Changing decimation: SDR# stops the stream (STREAMING_ENABLED = 0), re-sends
  the whole block (formats, decimation, frequency, mode, gain, digital gain), then
  re-enables [wire, VibeSDR]. SDR++ refuses to change sample rate while running.
  Do the same: stop, reconfigure, start, and flush any local sample buffers.
- Frequency, gain, FFT window settings can be changed while streaming.
- Retune rate: the server handles roughly eight settings per second
  comfortably; a client dragging a dial should coalesce retunes to ≤ ~8/s and
  always send the final position [sdroxide; single].
- Changing STREAMING_MODE: re-send gain and digital gain after it (a server may
  reset gain state on a mode change) [sdroxide; single].
- Before closing, send STREAMING_ENABLED = 0 so the server frees the device
  promptly rather than waiting for a timeout [sdroxide].

### 7.5 Sequence numbers

- IQ messages carry an incrementing SequenceNumber (u32, wraps). A gap means
  the server dropped buffers because this client fell behind (the server keeps
  `buffer_count` buffers of `buffer_size_ms` each [config]).
- FFT and status messages carry 0. Count gaps on **IQ messages only** (by kind or
  StreamType 1); counting across all messages (as gr-osmosdr does) reports false
  gaps once FFT is on. Whether the counter is per-stream or shared is not
  established; one client disables gap counting entirely while FFT is enabled.
  Treat a very large jump (e.g. ≥ 1000) as a counter reset. A gap is not an
  error; flush or conceal, do not disconnect.

### 7.6 Keepalive and disconnection

- PING (command 3) → PONG (message 2). Intervals used: 3 s [sdroxide], 5 s with
  3 missed PONGs = dead [VibeSDR brief]. Whether the server times out idle
  clients is unknown; pinging is cheap insurance on NAT paths.
- Primary disconnection signals: TCP EOF / reset; write failure; no bytes at all
  for N seconds while streaming (a silence timer is more reliable than PONG
  bookkeeping); any framing error (§1.2).
- Reconnect by starting over with HELLO; there is no session resumption.

---

## 8. Recommended minimal session: waterfall from the server-computed FFT

Goal: a spectrum/waterfall centred on frequency *F* with span ≥ *S*, at minimum
link cost.

1. **Connect** TCP to host:5555, TCP_NODELAY on.
2. **Send HELLO**: version 0x020006A4, name e.g. `Ham2K Logger`.
3. **Read** messages until both DEVICE_INFO and CLIENT_SYNC have arrived (≤ 5 s).
   Closed with nothing received → "busy or no device". DeviceType 0 → "no
   device". Major version ≠ 2 → unsupported.
4. **Plan**:
   - FFT decimation *f*: the largest *f* (0 … DecimationStageCount) whose span
     `MaximumBandwidth / 2^f` is still ≥ *S*; if *S* exceeds `MaximumBandwidth`,
     use *f* = 0 and show what is available. Spans are powers-of-two fractions;
     crop locally to exactly *S*.
   - FFT centre: *F*, clamped into [MinimumFFTCenterFrequency,
     MaximumFFTCenterFrequency] (or into the geometry-derived bounds of §2.4 if
     those fields look wrong). If CanControl = 0, also keep it within the device
     passband: `DeviceCenterFrequency ± (MaximumBandwidth − span)/2`.
   - Pixels *W*: the display width in device pixels, clamped to 100 … 32,768.
   - IQ (carried only because mode 5 needs it): uint8 unless ForcedIQFormat
     says otherwise, decimation = the narrowest (but ≥ 20 kS/s before 2.0.1920,
     §6.6), frequency = the FFT centre clamped into the IQ bounds.
5. **Send**, in this order (all SET_SETTING):
   1. IQ_FORMAT = 1 (or ForcedIQFormat)
   2. IQ_DECIMATION = as planned
   3. FFT_FORMAT = 1
   4. FFT_DECIMATION = *f*
   5. FFT_FREQUENCY = FFT centre
   6. FFT_DISPLAY_PIXELS = *W*
   7. FFT_DB_OFFSET = 0
   8. FFT_DB_RANGE = 140 (any 10 … 150)
   9. IQ_FREQUENCY = IQ centre
   10. STREAMING_MODE = 5
   11. GAIN = chosen index (only if CanControl = 1)
   12. STREAMING_ENABLED = 1

   IQ_DIGITAL_GAIN does not touch the FFT (automatic vs 0 moved the mean
   byte by under 2 [probe]); a client that discards the IQ need not send it.
6. **Expect**: possibly a CLIENT_SYNC; then UINT8_FFT messages (kind 301,
   StreamType 4, body *W* bytes) at the server's `fft_fps` (typically 15/s),
   interleaved with small UINT8_IQ messages (kind 100, StreamType 1) to discard.
   Decode each FFT body with §6.2/§6.3 using the *f*, centre, *W*, offset and
   range you sent. If no FFT frame arrives within ~2 s, report it (§6.6 is the
   likely cause if mode 4 was tried).
7. **Maintain**: PING every 3–5 s; silence timer; handle CLIENT_SYNC (§7.1–7.2).
   To pan/retune: FFT_FREQUENCY, then IQ_FREQUENCY, ≤ ~8 retunes/s. To change
   the span: FFT_DECIMATION (+ FFT_FREQUENCY if the bounds moved). On a resize:
   FFT_DISPLAY_PIXELS.
8. **Stop**: STREAMING_ENABLED = 0, then close.

Expected link cost: FFT ≈ *W* × fps (1024 × 15 ≈ 15 KB/s) plus the narrowest IQ
(RTL 2.4 MS/s / 2^9 ≈ 4.7 kS/s × 2 B ≈ 9.4 KB/s; HF+ 768 kS/s / 2^8 = 3 kS/s ×
2 B ≈ 6 KB/s).

### 8.1 Alternative: compute the spectrum locally from decimated IQ

Use when the FFT stream is unavailable or when a narrow span needs finer
resolution than the server offers.

1–3. As above.
4. Choose IQ decimation *d* (≥ MinimumIQDecimation) such that
   `MaximumBandwidth / 2^d ≥ S`; IQ rate = `MaximumSampleRate / 2^d`.
5. Send: IQ_FORMAT (2 = int16 recommended; 1 = uint8 halves the cost; honour
   ForcedIQFormat), IQ_DECIMATION = *d*, IQ_FREQUENCY = *F* (clamped), 
   STREAMING_MODE = 1, GAIN (if CanControl), IQ_DIGITAL_GAIN
   (`3.01 × d` dB, or 0xFFFFFFFF), STREAMING_ENABLED = 1.
6. Receive IQ messages (kind 99 + format); normalise and divide by the header's
   digital gain (§7.3); window + FFT locally; FFT-shift so DC is centred; keep
   only the central `MaximumBandwidth / MaximumSampleRate` fraction (the rest is
   roll-off).
7. Cost: rate × 2 B (uint8) or × 4 B (int16). RTL at *d* = 4: 150 kS/s × 4 B =
   600 KB/s int16. Full-rate float32 (~19 MB/s at 2.4 MS/s) breaks up over Wi-Fi
   [wire, VibeSDR].

---

## 9. Implementation checklist (facts a client must not get wrong)

- Little-endian everywhere; mask MessageType to 16 bits before dispatch.
- Body sizes are authoritative; zero-length bodies complete immediately.
- Reject BodySize > 1 MiB and major ≠ 2 as fatal; skip unknown kinds.
- CLIENT_SYNC may be 36 or 40 bytes; DEVICE_INFO 48 bytes (tolerate longer).
- HELLO name: no terminator.
- FFT span uses MaximumBandwidth, not MaximumSampleRate; bins ascend from
  `centre − span/2`.
- FFT_FREQUENCY before IQ_FREQUENCY when both change.
- Before 2.0.1920, an IQ rate under ~20 kS/s means no FFT at all.
- Byte 255 is −FFT_DB_OFFSET, not +.
- Decode FFT dB with the values sent, after clamping to protocol limits.
- Divide IQ by the per-message header gain.
- No replies to settings: keep your own state, clamp locally, never wait for an ACK.

---

## 10. Open questions and uncertainties

1. ~~FFT span for f > 0~~: answered, `MaximumBandwidth / 2^f` (§6.2) [probe].
2. ~~FFT-only mode (4)~~: answered, it sends nothing (§6.6) [probe].
3. **dB mapping**: never checked against a calibrated level. FFT_DB_OFFSET's
   direction is answered, and is the opposite of both sources (§6.3) [probe].
4. **Bin alignment**: edge vs centre of bin *i* not established (~1 bin).
5. **CLIENT_SYNC resend policy**: conflicting reports (§7.2).
6. **Control hand-off** when a second client joins/leaves: documented in prose,
   not captured.
7. **Float32 gain direction**: SDR++ multiplies, sdroxide divides (§7.3).
8. **IQ_DIGITAL_GAIN units for explicit values**: whole dB inferred from the
   header flags echoing the requested value; the automatic value 0xFFFFFFFF is
   observed; behaviour of very large explicit values unknown.
9. ~~Device-follows-FFT rule~~: answered, it does (§6.5) [probe].
10. **Top decimation index**: FFT_DECIMATION = DecimationStageCount was accepted
    (its bounds changed accordingly) on every server tried [probe]; whether
    its sweeps are right was not checked.
11. **Settings 206, 207**, the 10th CLIENT_SYNC word on 2.0.1922, GET_SETTING /
    READ_SETTING layouts, GainStageCount meaning, INT24 and DINT4 encodings, AF
    stream: all unknown.
12. **Server idle timeout** without PINGs: unknown.
13. **DeviceSerial** reduction from the 64-bit config serial: unknown.
14. **Min/Max centre fields** sometimes zero or degenerate on some servers;
    when they are trustworthy is unclear.

---

## 11. Sources

Read for this specification (licence in parentheses). Tags used in the text in
brackets.

| Tag | Source | Licence | What it contributed |
|---|---|---|---|
| SDR++ | AlexandreRouma/SDRPlusPlus — `source_modules/spyserver_source/src/spyserver_protocol.h`, `spyserver_client.h`, `spyserver_client.cpp`, `main.cpp` | GPL-3.0 (repo `license`); the protocol header credits Youssef Touil (Airspy), 2017, "corrections by Ryzerth" | Constants and struct layouts; handshake; IQ decoding and header-gain use; decimation ladder; digital-gain formula; IQ-only usage. No FFT handling. |
| gr-osmosdr | racerxdl/gr-osmosdr (Lucas Teske's fork; the osmocom upstream has **no** `lib/spyserver`, URLs 404) — `lib/spyserver/spyserver_source_c.cc`, `spyserver_protocol.h` | GPL-3.0-or-later (file header); "based on Youssef Touil's C# implementation" | Framing parser, version check, 1 MiB guard, sequence-gap counting, CLIENT_SYNC bounds use by mode, gain only with control. FFT handler empty. |
| miweber | miweber67/spyserver_client — `spyserver_protocol.h`, `ss_client_if.cc/.h`, `ss_client.cc`, `README.md` | GPL-3.0 | The only open client using the FFT stream before 2026: FFT body = pixels, seq 0 on FFT, FFT-only mode gave no data, decimation-before-sync quirk, bounds checks when not controlling, a command order said to mirror SDR#. |
| spy2go | racerxdl/spy2go — `spyserver/protocol.go`, `spyserver/SpyServer.go` | Apache-2.0 | Independent constants, defaults (2000 px, 127 dB range), FFT display bandwidth approximation (0.8 × rate), IQ-only gap counting. |
| sdroxide | dividebysandwich/sdroxide — `crates/sdroxide-spyserver/src/{proto,net,decode,handle,lib}.rs`, `tests/spyserver.rs`, `examples/spy_probe.rs` | GPL-3.0 | FFT span ladder, dB mapping, device-follows-FFT rule and retune order, CLIENT_SYNC adoption rules, float gain conflict, ping interval, retune rate, framing-error policy. |
| VibeSDR | Stuey3D/VibeSDR — `android/app/src/main/cpp/spyserver/PROTOCOL_NOTES.md`, `spyserver_client.cpp/.h`, `spyserver_messages.cpp`, `tools/spyserver/{probe,centretest,ratecheck}.py`, `briefs/BRIEF-spyserver-*.md` | GPL-3.0 | **Wire captures** of official spyserver 2.0.1922 with SDR++ 1.2.1 and SDR# 1.0.0.1921: HELLO format, PING echo, settings SDR# sends (incl. 206/207), 40-byte CLIENT_SYNC, FFT geometry verified against a carrier, IQ/FFT independence, rate = max/2^n, no CLIENT_SYNC resend, busy/no-device close, bandwidth measurements. (Its briefs pre-date the captures and are superseded where they differ.) |
| Kiwi | jks-prv/KiwiSDR — `pkgs/sdrpp_server/sdrpp_server.cpp` (SpyServer **server** emulation) | LGPL-2.0-or-later (file header; repo has no SPDX tag) | Hex dumps of real RTL-SDR (2.0.1822) and HF+ (2.0.1700) servers: DEVICE_INFO and 36-byte CLIENT_SYNC values, IQ header flags equal to requested digital gain, SDR++ command bytes. |
| esp-bridge | z2labs/esp-sdr-bridge — `src/esp_sdr_bridge/bridge.py` (server emulation), `tools/ss_client.py` | GPL-3.0 | How a working third-party server answers (handshake, PONG, flags in high bits, drop-on-overflow → sequence gaps); a minimal client's decode. |
| SDRangel | f4exb/sdrangel — `plugins/samplesource/remotetcpinput/spyserver.h`, `remotetcpinputtcphandler.cpp` | GPL-3.0 | Independent little-endian encoding, handshake trigger on first CLIENT_SYNC, mid-stream CLIENT_SYNC handling, typical stage/gain counts, MinimumIQDecimation tied to `maximum_bandwidth`. |
| r2cloud | dernasherbrezon/r2cloud — `src/main/java/ru/r2cloud/spyclient/*.java`, `src/test/.../SpyServerMock.java` | Apache-2.0 | Independent IQ-only client: digital gain 0xFFFFFFFF needed for RTL-SDR, skip gain without control, format choice from ForcedIQFormat / Resolution. |
| spyclient | Tubbz-alt/spyclient (fork of sam210723/spyclient) — `spyclient/{spyclient,enums,tuples}.py` | MIT | Enumerations incl. GET (1) / READ_SETTING (3); empty read after connect = no device. |
| config | Official `spyserver.config` from spyserver builds 1577 and 1700, as vendored in Tubbz-alt/spyclient `test/v1577`, `test/v1700` | Airspy freeware (config file text) | `fft_fps`, `fft_bin_bits`, `maximum_clients`, `allow_control`, `maximum_bandwidth`, `force_8bit`, session duration, buffers, sample-rate options. |
| airspy.com | https://airspy.com/quickstart/ — "Using the SPY Server for Remote SDR Operation" | Vendor documentation | Control semantics with one vs several clients; "Full IQ" off = FFT + reduced IQ. |
| MBDSDR | HaohanHe/MBDSDR — `docs/learn/spyserver.md` | MIT | Secondary cross-check of SDR++ and SDRangel (no new wire facts). |

Deliberately **not** read: SDRSharpR/SDRSharp (presents itself as the full source
of the proprietary SDR# build 1632, i.e. a decompilation; no licence) and
jetervaz/sdr-terminal (no licence). Airspy's server is closed source; no official
protocol specification exists.

---

## 12. Measurements against public servers

On 2026-11-02, a probe written from this document alone connected to public
servers listed in Airspy's directory (`airspy.com/directory/status.json`, 217
online, most of them 2.0.1921–1922; about two thirds of the listed addresses
did not answer). It sent HELLO as `Ham2K Logger probe`, changed settings only
while CanControl = 1 on an idle server or as a spectator, and put the FFT
centre back where the device was before disconnecting.

| Server | Device | Role | What it showed |
|---|---|---|---|
| 2.0.1922 | Airspy One, 6 MS/s, 4.8 MHz | control | Mode 4 empty; span ladder; device follows FFT; offset sign; PING echo; CLIENT_SYNC re-sent; FFT_DECIMATION 11 accepted |
| 2.0.1922 | RTL-SDR, forced uint8 | control | Same, span decisive at *f* = 1 |
| 2.0.1922 | HF+, 8 gain steps, 9 kHz–31 MHz | control | Span decisive against 0.8 × rate at *f* = 1 … 3 |
| 2.0.1920 | RTL-SDR, operator range 26.565–27.405 MHz | spectator | FFT at the narrowest IQ; spectator bounds are the intersection (§7.1) |
| 2.0.1921 | RTL-SDR, Airspy One | control | FFT at the narrowest IQ |
| 2.0.1822 | HF+, no gain steps; Airspy One 2.5 MS/s | control | No FFT at ≤ 12 kS/s of IQ (≤ 9.8 kS/s on the Airspy), FFT at 19.5–24 kS/s; nothing else tried brought it back |
| 2.0.1700 | HF+; Airspy One 6 MS/s | control | Same threshold: 12 kS/s none, 23.4–24 kS/s fine |

Variants tried on 2.0.1822 at the narrowest IQ, none of which brought the FFT:
1024 pixels, automatic digital gain, mode first, streaming enabled first, range
127, no FFT_DECIMATION, no frequencies, FFT_FORMAT 5 or none, modes 6 and 7,
HELLO versions 2.0.1822 and 2.0.1922, the client name `SDR#`.

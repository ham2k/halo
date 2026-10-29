# IC-705 network teardown, from a packet capture

Why this file exists: our first implementation could connect to an IC-705 over
WiFi and hold that connection indefinitely, but **could not reconnect** after a
disconnect — often not for minutes. Reading our own code could not settle why,
because the question was not "what does our code do" but "what does the radio
expect". So we captured a working client's traffic and read the packets.

## Provenance, and the licence boundary

The capture is of **wfview**, taken with `tcpdump` on the LAN interface:

```
udp and host <radio> and portrange 50001-50003
```

wfview is GPLv3 and this codebase is MPL-2.0. **Its source was not read for
this, and is never copied.** What follows is derived entirely from datagrams on the wire —
the byte layout the *radio* requires is a fact about the radio, not anyone's
expression of it. Keep corrections to this protocol inside the same
boundary: the wire is the evidence, and wfview's source is read for the facts
of a format at most, never copied.

Capture: 12,371 packets, four control sessions, ~38 seconds — connect, wait for
a frequency, disconnect, immediately reconnect, disconnect.

## What the capture settled

### 1. Immediate reconnect works, so the failure was ours

All three real sessions ran the full handshake — `pkt3 → pkt4 → pkt6 → login →
login-answer → auth → token → request-streams → stream-answer` — and the gaps
between them were **3.0s and 1.9s**. Rapid reconnect is not a radio limitation.

### 2. Session ids are not reused

The three sessions bound three different ephemeral source ports (61132, 60782,
54375). The session id is derived from the port: port `0xEECC` appears on the
wire as `cc ee 00 00`. Our derivation already matched byte-for-byte, so
"reuse a stable session id" was a dead end — worth recording so it is not
proposed again.

### 3. The teardown is one millisecond, once per channel, streams first

```
t+24.042  AUD   C->R  10 00 00 00 05 00 00 00 <local> <remote>
t+24.043  SER   C->R  16 00 00 00 00 00 ed 02 <local> <remote> c0 01 00 02 ec 00
t+24.043  SER   C->R  10 00 00 00 05 00 00 00 <local> <remote>
t+24.043  CTRL  C->R  40 00 00 00 00 00 f0 00 <local> <remote> 00 00 00 30 01 01 00 33 …
t+24.043  CTRL  C->R  10 00 00 00 05 00 00 00 <local> <remote>
t+24.114  CTRL  R->C  40 00 00 00 00 00 f4 00 <remote> <local> 00 00 00 30 02 01 00 33 …
```

Three things we had wrong:

- **Order.** Audio, then serial, then control. The login owns the streams, so
  the streams go down first and the login last. We did the exact reverse:
  logged out first, then spent the better part of a second closing streams the
  radio no longer had a logged-in owner for.
- **Repetition.** Exactly one disconnect per channel, one logout — confirmed
  across the whole capture (10 outgoing `0x05`, 6 outgoing auth, 3 acks). We
  sent each three times with 50ms gaps, so datagrams two and three referred to
  a session the radio had already released.
- **The acknowledgement.** The radio answers a logout with a 64-byte `0x40`
  auth packet carrying **`0x02`** at offset 20, where the request carries
  `0x01`. We had never captured one, which is why the code sent blindly and
  hoped. Now it sends once and waits.

Note the serial-close packet carries a live outer sequence number
(`ed 02` at offsets 6–7); we were leaving that field zero.

### 4. The bug that was actually causing the reconnect failure

The teardown defects above are real and fixed. They were **not** what had been
failing. Auditing the rest of the capture against our code found this:

```dart
// our login-answer matcher - EIGHT bytes
icomPrefixIs(b, [0x60, 0, 0, 0, 0, 0, 0x01, 0])
```

Bytes 6–7 are the sender's outer sequence number. On a radio→client packet that
is the **radio's monotonic counter**, not a constant. Every login answer in the
capture carries `0x0002`:

```
t+ 0.213  R->C  60 00 00 00 00 00 02 00 …
t+27.294  R->C  60 00 00 00 00 00 02 00 …
t+32.618  R->C  60 00 00 00 00 00 02 00 …
```

It is `2` rather than `1` because the radio's counter ticks for everything it
sends and an idle went out first — pkt4 seq 0, idle seq 1, `0x60` seq 2. Which
of those two values you get depends purely on how fast the radio answers pkt6
(107–144 ms in the capture, effectively instant in our own earlier bench run,
which is why the bench tool never hit it).

So: a valid login answer was **silently discarded**, `_expect` timed out after
3 s, and `login()` turned that into `IcomLoginTimeout` — whose message told the
operator the radio *"may still be holding a previous session"*. A race, wearing
the costume of a stateful radio bug, with our own error message reinforcing the
wrong diagnosis. That is what the `KNOWN LIMITATION` note in this transport
described for the entire life of this branch.

The other three reply matchers were checked against the capture and are fine:
`0x50` and the logout ack already stop at six bytes, and `pkt4`/`pkt6` pin
bytes 6–7 to values that are structurally fixed rather than counters — pkt4 is
a session's first radio packet, and type-6 carries a literal `0x0001` that our
own outgoing pkt6 sets too.

**Rule worth keeping: never match on a field the peer increments.** Length plus
message type identified every one of these packets uniquely; the sequence field
added no discrimination and cost days.

## Status

Fixed in `icom_network_transport_io.dart` — `_shutdown()` for the teardown
order, `logout()` for the single send plus ack, `close()` for the single
disconnect, and `isLoginAnswer` for the matcher above.

**Verified on hardware 2026-07-30:** repeated disconnect/reconnect cycles, all
successful. The `KNOWN LIMITATION` note and the operator-facing troubleshooting
text have both been retired — the latter had been advising people to wait a
minute for a radio that was never the problem.

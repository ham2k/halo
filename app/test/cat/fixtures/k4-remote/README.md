# K4 secure remote PAN capture

`k4-remote-9204-main-sub.bin` contains four unmodified PAN envelopes from a
physical Elecraft K4 over TLS-PSK on TCP 9204. Firmware **R39** was reported by
the owner; the capture tool did not query firmware. The connection started at
`2026-10-24T14:17:17.335813Z` and ran for 20,007 ms. The tool sent only `RDY;`
and periodic `PING;`; it did not tune, enable receivers, key or send audio.

The fixture is the first 4,252 bytes of the PAN-only recording, containing
two frames for receiver 0 (Main) and two for receiver 1 (Sub), in recorded
order. Each envelope is 1,063 bytes with a 1,051-byte payload and 1,024 bins.
Intervening CAT, audio and mini-pan envelopes were discarded by the capture
tool; this file is not a complete multiplexed network trace.

| PAN recording offset | Receiver | Sequence | Center (Hz) | Sample rate (Hz) | Noise field (dB) | Elapsed µs |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 133 | 14,234,000 | 24,000 | −139.7 | 44,681 |
| 1,063 | 1 | 134 | 14,045,000 | 96,000 | −113.4 | 44,681 |
| 2,126 | 0 | 135 | 14,234,000 | 24,000 | −139.3 | 111,269 |
| 3,189 | 1 | 136 | 14,045,000 | 96,000 | −113.4 | 111,269 |

All four headers have version 0, nested PAN type 0, declared inner length
1,024 and zero reserved bytes. These are observations, not restrictions on
other firmware or settings. The exact 27-byte payload headers are:

```text
02008500000004000000009031d90000000000180000008bfaffff
0200860001000400000000484fd600000000006000000092fbffff
02008700000004000000009031d90000000000180000008ffaffff
0200880001000400000000484fd600000000006000000092fbffff
```

SHA-256:

- Original PAN-only recording, 633,548 bytes:
  `86b2cc85d9dd8d7e5d44a8318c3fb9e0f6af8fd7a9a42b45aca4b4d6481c5cca`
- Committed excerpt, 4,252 bytes:
  `fa3057669f5b4e5004e9dbf8482a6ee5549ad3e80aea287dde0faab1e16085f4`

The original recording received 1,779,452 decrypted bytes and decoded 2,185
envelopes: 596 PAN (298 per receiver), 493 CAT, 500 audio and 596 mini-pan.
It stopped at the requested duration with zero pending bytes, unknown types,
invalid lengths, invalid footers, invalid payloads, unsupported versions or
discarded bytes. These are the original capture diagnostics, not counts
inferred from replaying the already-filtered fixture.

Expected test values were decoded independently with Python's `struct` and
`hashlib`, without calling the Dart decoder or synthetic fixture generator.
The check walked `FE FD FC FB`, read the outer `>I` length at offset 4, and
verified `FB FC FD FE` at the resulting boundary. Relative to the payload,
it read `<H` at 5, `<q` at 11, `<i` at 19 (kHz), `<i` at 23 (tenths of dB),
and unsigned bins from 27 onward, subtracting 160. The regression test checks
these literal values and selected bins under several TCP chunk boundaries.

The committed bytes contain PAN metadata and spectrum levels only. Host,
credentials, free-form notes, CAT text and audio are not included. This
establishes live TLS/PAN reception and the observed wire fields. The fixture
alone does not establish calibrated dBm, visual alignment with the radio,
absolute signal levels, other bin counts, app control or link-drop recovery.

## Live app session check

A separate check on the same radio used the production `CatService`,
`PanelRadioService`, shared sessions and native TLS, with in-memory settings
and a guarded transport. Both logical radios reported connected, current CAT
state and valid spectrum, with distinct logical IDs and one physical identity.
A loopback proxy then closed only this test's TCP connection. Both logical
radios reported the drop and recovered automatically on one replacement TLS
connection. Each authenticated connection supplied 15 original PAN packets
per receiver; both panel streams delivered 15 frames before and 15 after the
drop. The complete check took 2,503 ms, with two total physical connections,
zero invalid presented frames and zero blocked writes.

The outgoing guard allowed only read queries, keepalives and the driver's
protocol/reporting initialization. No tuning, keying, audio or receiver-setting
commands were sent. This exercises live app services and panel snapshots,
not the rendered UI, a physical cable interruption, or changes to diversity
and split settings. The temporary harness and credentials are not part of
the fixture or automated test suite.

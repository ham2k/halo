# K4 LAN spectrum capture

`k4-lan-9201-ayb.bin` contains the first three consecutive, unmodified frames
from a physical Elecraft K4's local TCP spectrum endpoint on port 9201,
captured on 2026-10-21. The source capture lasted 20 seconds and contained
3,720,828 bytes: 894 frames, with 298 frames each for pan IDs A, Y and B.

This fixture is 12,486 bytes (three 4,162-byte frames). Its SHA-256 is
`c71c488ba6cbfce7d0fcac64fe4ef4a53d8932c37eac5031368f465a22090cd1`.
No network address or operator identifier is recorded here. Front-panel
display settings were not recorded concurrently with this capture. The
fixture establishes wire framing and values; it does not establish absolute
level calibration or the display interpretation of each pan ID.

The operator subsequently supplied the radio's firmware screen: release
**R39**, with these components:

| Component | Version |
| --- | --- |
| KUI | 1789 |
| KSRV | 2009 |
| KUP | 646 |
| KCFG | 78 |
| FP | 03.57 |
| RF | 00.78 |
| DSP | 01.69 |
| DAP | 00.29 |
| DDC1 / DDC2 | 00.65 (0:35) |
| DUC | 00.45 (1:18) |
| REF | 00.20 |

CAT readbacks collected after this capture are not used to infer its display
settings: the VFO and scope settings could have changed between observations.

| Frame | Version | Sequence | Pan | Sample rate (Hz) | Center (Hz) | Noise field (tenths) | CRC footer |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 2 | 12 | A | 96000 | 14045000 | -1316 | `CB08` |
| 1 | 2 | 12 | Y | 3000 | 14047440 | 87 | `2141` |
| 2 | 2 | 11 | B | 96000 | 7045000 | -1215 | `D732` |

The header fields and signed big-endian sample values asserted in
`../../k4_spectrum_codec_test.dart` were independently extracted using
Python's `struct` module. The CRC footers were independently checked using
Python's `binascii.crc_hqx` with explicit input/output bit reflection,
initial value `FFFF` and final XOR `FFFF`; they were not regenerated into
the fixture. Each captured 64-byte header sums to zero modulo 256.

The other tests in that file use synthetic packets for corruption and
fragmentation cases. Those packets are explicitly separate from this
hardware capture.

## Span and four-pan capture

`k4-lan-9201-spans-aybz.bin` contains five unmodified R39 frames: the first
four consecutive frames from the capture connected at
`2026-10-22T00:43:30.546071Z`, followed by the first frame from the capture
connected at `2026-10-22T00:44:39.990655Z`. The join between captures is not
a continuous sequence. Each source lasted 20 seconds and contained 1,192
valid frames, 298 each of A, Y, B and Z, with no decoding errors or sequence
gaps within an individual pan.

This fixture is 20,810 bytes. Its SHA-256 is
`a0b6ff7291a3940758e99e04fad5d52057659307f20de2e4208ddfb273ac0cfb`.
It adds live Z coverage and main-pan sample rates of 24 and 48 kHz. The
same independent Python header, sample and CRC checks described above
establish its expected values.

| Frame | Version | Sequence | Pan | Sample rate (Hz) | Center (Hz) | Noise field (tenths) | CRC footer |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 2 | 45 | A | 24000 | 14036950 | -1392 | `A34F` |
| 1 | 2 | 45 | Y | 3000 | 14037360 | 147 | `CC19` |
| 2 | 2 | 44 | B | 96000 | 14045000 | -1101 | `7DE1` |
| 3 | 2 | 43 | Z | 3000 | 14037360 | 107 | `6887` |
| 4 | 2 | 55 | A | 48000 | 14036950 | -1340 | `38FC` |

Operator-supplied remote-display screenshots show approximately 5 and
20 kHz visible spans. Comparison with the full captures supports ascending,
already centered main-pan bins; the sample rate is not the visible span.
The second capture includes a tuning change while the main-pan header
center stays fixed. See `docs/design/k4-cat.md` for the timing and remaining
limits. These five fixture frames establish byte interpretation, not the
complete time-dependent screenshot comparison or calibrated dBm.

# K4 LAN spectrum capture

The [design document](../../../../../docs/design/k4-cat.md#wire-format)
describes the wire format, frequency mapping and remaining field unknowns.

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
center stays fixed. The observations below record the timing and remaining
limits. These five fixture frames establish byte interpretation, not the
complete time-dependent screenshot comparison or calibrated dBm.

## Capture observations

Two passive LAN captures from one K4, with overall software release **R39**
confirmed by the operator's SW LIST, decoded **1341 frames**: 894 frames /
3,720,828 bytes in approximately 20 seconds, then 447 frames / 1,860,414 bytes
in approximately 10 seconds. Both had zero rejected headers, rejected CRCs,
unsupported versions/IDs, discarded bytes, or trailing partial bytes. Each
contained equal counts of `A`, `Y`, and `B` frames (298 then 149 per pan),
approximately 15 frames/second/pan, with sequence increments per pan.
All three used the same 4162-byte frame; `Z` was not observed in these two captures.

The second capture connected at `2026-10-22T00:04:31.464448Z`. Its decoded
metadata and level ranges were:

| Pan | Header center (Hz) | Sample rate (Hz) | Decoded level range (dB) |
| --- | ---: | ---: | ---: |
| A | 14,045,000 | 96,000 | −172.5 to −97.1 |
| Y | 14,056,640 | 3,000 | −12.8 to 29.6 |
| B | 7,045,000 | 96,000 | −154.5 to −110.6 |

The first capture had the same A/B centers and rates; Y was centered at
14,047,440 Hz with the same 3000 Hz rate. A separate read-only CAT snapshot
during the second capture, at `2026-10-22T00:04:38.023536Z`, returned:

```text
FA00014056240; FB00007045000;
#SPN40000; #SPN$40000; #REF-131; #REF$-121; #SCL47; #AR1206-041;
```

Thus the 96 kHz sampled width differs from the requested 40 kHz span, and
the A header center differs from VFO A's 14,056,240 Hz. Display cropping must
account for the pan mode and frequency relationship; it cannot assume the
header center is the tuned VFO or the displayed crop center. These captures
verify the byte structure, not frequency alignment or calibrated dBm.
Mini-pan scaling, AutoRef/reference/scale relationships and other software
releases remain unverified. The additional captures below provide main-pan
frequency evidence; calibrated levels still need measurements.

Two further 20-second captures connected at `2026-10-22T00:43:30.546071Z`
and `2026-10-22T00:44:39.990655Z`. Each contains 4,961,104 bytes and 1,192
valid frames, 298 each of `A`, `Y`, `B` and `Z`. Both have zero rejected
headers/CRCs, unsupported versions/IDs, discarded bytes, trailing partial
bytes, or per-pan sequence discontinuities. `Z` uses the same 4162-byte
format. The aggregate sequence counter records interleaved pans and is
not a packet-loss measure.

Remote-display screenshots supplied by the operator show approximately
5 kHz and 20 kHz visible spans, inferred from their frequency-axis labels.
The A stream uses 24 kHz and 48 kHz sample rates respectively, retaining a
14,036,950 Hz center in both captures. Therefore the visible window must
crop the stream, rather than stretch all 2048 bins to the selected span.
These screenshots establish the remote client's displayed windows; they
are not simultaneous front-panel `#SPN` readbacks.

The first screenshot's clock falls about 8.45 seconds into the first
capture. Its strong signal near 14,036,960 Hz matches bin 1025, which the
candidate mapping places at 14,036,961.7 Hz. In the second capture, bins
780 and 1197 map to 14,031,231.3 Hz and 14,041,004.7 Hz, consistent with
the visible signal positions. The second screenshot is at approximately
the end of the capture; instantaneous signal heights need not match.
These observations support increasing frequency with bin index and no
FFT half-swap, but do not establish sub-bin frequency accuracy.

The second screenshot shows VFO A at 14,041,000 Hz instead of the first
screenshot's 14,036,960 Hz. About 15.46 seconds into the second capture,
the Y/Z centers change from 14,037,360 to 14,041,400 Hz, while A's center
remains fixed. Both screenshots show a 400 Hz CW pitch, consistent with
the mini-pan offset in this configuration; this does not establish the
mapping in other modes or with diversity disabled. A span-only comparison
must keep tuning and layout fixed. The fixture directory retains samples
from both captures, including live Z packets and the 24/48 kHz main pans.

## Capture procedure

From the repository root, enter the app directory and run these commands,
replacing the host and output directory:

```sh
cd app
dart run tool/k4_spectrum_capture.dart capture --host <host> --output <new-directory> --seconds 20 --note 'firmware ... main ... span ... ref ... scale ...'
dart run tool/k4_spectrum_capture.dart inspect <new-directory>/capture.bin
```

The tool receives bytes from 9201 without sending CAT, start, or `PING`
commands. It records raw bytes in `capture.bin`, chunk offsets/timing in
`chunks.jsonl`, and decoder diagnostics, per-pan metadata/level ranges, and
header hex samples in `summary.json`. Duration and byte limits bound capture
size. The output directory must be new; existing captures are not overwritten.
Offline inspection does not require a radio connection.

For software provenance, tap **Fn → SW LIST (F11)**. The overall release is
in parentheses at the top; retain the component revision list too. See the
[operating manual's SW LIST description][k4-software-list]. An initial
passive capture may use the note `Initial passive capture; firmware/front-panel settings not recorded`;
record those settings before drawing conclusions about display alignment.

Use separate output directories and notes for these receive-only checks:

1. Record firmware, host OS, tuned frequency, display layout, span, reference
   level, scale, and AutoRef state. Capture a steady main pan with a
   recognizable received signal; record its frequency and screen position.
2. Capture narrow and wide spans at the same frequency. Compare header rates
   with the displayed full span and the signal's bin position; do not assume
   that sample rate and visible span are equal.
3. Turn the main dial during a capture, recording the starting/ending
   frequencies and approximate change times. Check that each frame's own
   center/rate explains its signal positions.
4. Repeat with the subreceiver enabled and alternate pan layouts. If
   available, enable each mini-pan and record which `A`/`B`/`Y`/`Z` frames
   arrive, their sizes, and sequence behavior. Do not assume every pan type
   has the main pan's frame size.
5. Vary reference level, scale, and AutoRef in separate captures. Compare
   metadata and level changes with the K4 display before choosing display
   floor/ceiling semantics.

Transmit is not required. Retain raw bytes and notes when checksums,
versions, or metadata disagree with the candidate format; resolve the
discrepancy before adapting the decoder. Synthetic frames verify parser
handling of corruption and TCP chunk boundaries, but only radio captures
can validate this wire-format inference. Successful decoding alone does not
establish calibrated signal levels or correct frequency alignment.

## App check

1. Connect the K4 Ethernet pairing and open the panadapter/waterfall in
   its radio panel. To check the sample, install it and add its **Panadapter**
   panel through **Edit Layout**.
2. Compare a narrow carrier against the K4's frequency scale. Try several
   local spans; the carrier's frequency should stay put as the view crops.
3. Turn the K4's tuning dial and change its pan span. HaLo should follow the
   stream's reported center and offer zooms within its available width.
4. Try reference, contrast, averaging and speed controls. The picture should
   change without changing the K4's front-panel display settings.
5. Hide and reopen the panel, then interrupt and restore the LAN connection.
   The waterfall should resume with current data after recovery. A spectrum
   connection failure should not interrupt a healthy CAT connection.

Physical link-loss recovery and absolute level calibration remain unverified.

[k4-software-list]: https://ftp.elecraft.com/K4/Manuals%20Downloads/K4%20Built-In%20Operating%20Manual%20rev%20D14/K4BuiltInOperatingManualrevD14.html

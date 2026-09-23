# Elecraft K4 CAT

The K4 model has `k4-serial` and `k4-tcp` variants. Both use the K4
configuration of `KenwoodDriver`, sharing framing, polling and keyer queues
with the Kenwood family. K4 mode and power conversions live in `k4_codec.dart`.
The default Kenwood driver and the KX2/KX3 definitions retain their behavior.

## Connections

Enable Station Configuration with `EXP CAT`; enable `EXP KEYER` to exercise
CW and voice controls. The K4 uses these existing feature gates.

- **USB:** connect the rear USB-B PC socket, select either unused virtual COM
  port, and match its **Serial USB-PCn: Baud Rate** setting. The form starts
  at 38400; this is a configurable starting value, not auto-detection.
- **Ethernet:** enter the K4's local-network hostname/IP and CAT port **9200**.
  Discovery, audio streaming, panadapter data and the separate remote-access
  service on 9204 are outside this driver.
- The serial device path is stored as `port`; the TCP number as `tcpPort`.
  Both variants seed the same editor, so reusing `port` would overwrite one
  connection's settings when switching to the other. TCP still receives the
  canonical `{host, port}` target after configuration is resolved.
- Platform transport limits apply: browser builds cannot open raw TCP sockets;
  the existing iOS serial implementation does not provide USB CAT.

## Protocol choices

Each connection starts with `K40;K31;` before enabling `AI2` and reading state.
K40 clears K2 meta mode; K31 selects the documented IF layout with the DATA
submode included. IF supplies frequency, mode/submode and transmit status in
one snapshot. Separate MD/DT notifications trigger a fresh IF read instead
of combining a new mode with a stale submode. Subreceiver notifications do
not change the main VFO.

DATA A maps to DATA-USB (DATA-LSB reversed); AFSK-A and FSK-D map to RTTY
(RTTY-R reversed); PSK-D maps to PSK. Setting RTTY selects FSK-D. PSK rate and
reverse polarity are not represented separately in the app's PSK mode.
FT8 and FT4 select DATA A, so a band change's recalled mode never stands in
for them; HaLo cannot infer FT8 versus FT4 back from the radio's DATA A setting.

Power reads use PCX to require an explicit L/H/X range. L encodes tenths of
a watt, H whole watts, and X tenths of a milliwatt. Everything reported to
the app is in watts. Every power write first asks PCX for the active range;
an X response permits only 0.0001–0.01 W and keeps the X suffix. Other outputs
accept 0.1–110 W, choosing L up to 10 W and H above it. The radio can impose
lower limits for its hardware. Values are rounded to the range's resolution
and read back. A range query expires after two seconds; late replies cannot
execute a stale power change. Disconnect clears pending writes. A refused or
expired write reads the power back at once, so the app shows what the radio
has; the refusal stays up until the next power answer after that read.

CW uses the existing Elecraft text/cancel commands and 24-character chunks,
within the K4's 60-character limit, with a K4-specific 8–100 WPM range.
The existing K4 voice dialect exposes eight memories and a 90-second ceiling:
PBn plays, DARM records, and stopping recording sends DA0 then DAMSn to save.

## Verification

`app/test/cat/cat_k4_test.dart` covers protocol fixtures, invalid and partial
input, mode/submode changes, power ranges and expiration, keyers, configuration
switching, and the real CatService over a loopback TCP radio that models the
radio's ER04 refusal and band recall. The fixtures come from the programmer's
reference, not from hardware captures.

## Band changes

With diversity on, an `FA` that crosses bands is refused with ER04, just as
the radio's own FREQ ENT is, while its BAND control succeeds. So for 160 m
through 6 m the driver sends `BN` before `FA` whenever the destination band
differs from the last reported or commanded one. The commanded band is
remembered at once: CatService tunes frequency, mode, frequency on a band
change, and a second `BN` between them would recall the band's stored mode
over the one just set. A front-panel frequency report replaces the remembered
band, and a reconnect clears it. General coverage and user-defined transverter
bands have no `BN` mapping and tune with `FA` alone. The driver never touches
diversity, VFO B, antenna selection or band independence: the K4's band
selection owns the receiver transition.

Avoiding zero beat through XIT is out of this driver's reach: HaLo offsets the
suggestion frequency before it reaches CAT, and `TransceiverSession` has no
XIT capability or separate receive/transmit tuning.

## Hardware checklist

Record the K4 firmware, host OS, and USB port/baud or TCP address/port, then on
each connection:

1. Connect, turn the dial, change modes/submodes, and tune from HaLo.
2. Check fractional QRP and whole-watt power, including radio-enforced limits.
3. Check transmit indication, CW speed/send/cancel and all voice memories;
   verify record/stop/save without overwriting a memory that must be retained.
4. Disconnect/reconnect, interrupt the link, and reconnect after radio restart.
5. Run another CAT client on the other USB port or Ethernet; verify changes
   propagate without disturbing that client's reporting configuration.
6. If using a transverter, verify X-range reads/writes and refusal of watt-range
   requests while the milliwatt output is selected.

## References

- [K4 Programmer's Reference, D12](https://ftp.elecraft.com/K4/Manuals%20Downloads/K4ProgrammersReferencerev.D12.html)
- [K4 Operating Manual, D14](https://ftp.elecraft.com/K4/Manuals%20Downloads/K4%20Built-In%20Operating%20Manual%20rev%20D14/K4BuiltInOperatingManualrevD14.html)
- [RUMlog K4 connection documentation](https://dl2rum.de/RUMlogNG/docs/en/pages/CAT-K4.html)

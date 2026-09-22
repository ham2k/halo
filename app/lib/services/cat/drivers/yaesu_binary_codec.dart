// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The OTHER Yaesu CAT: the five-byte binary protocol of the FT-817/818,
// FT-857 and FT-897, which shares nothing with the ASCII `FA…;` protocol of
// the modern line (yaesu_cat_codec.dart) but the manufacturer's name.
//
// Every command is exactly five bytes — four parameters then the opcode —
// and there is NO framing in either direction: no preamble, no terminator,
// no length, no echo. What a reply means is decided entirely by which
// question is outstanding, which is why the session serialises its requests
// (yaesu_binary_driver.dart) and why this file describes each command's
// reply length as part of the command itself.
//
// PROVENANCE: Yaesu's own published CAT chart — the FT-817 Operating Manual
// (opcode chart p. 72, notes p. 73) and the FT-897 Operating Manual's
// identical chart. Nothing here is transcribed from Hamlib or any other
// GPL implementation.
//
// Pure: it builds and parses bytes and knows nothing about ports or timers.

/// Opcodes, as the manual's chart numbers them (the fifth byte).
///
/// The chart has seventeen and this is what the driver sends. The rest —
/// lock, split, VFO toggle, repeater shift, CTCSS and DCS, the receiver
/// status read — are settings this app has no surface for, and a constant
/// for one would be a command nobody can issue.
class YaesuBinaryOpcode {
  static const setFrequency = 0x01;
  static const readFrequencyAndMode = 0x03;
  static const setMode = 0x07;
  static const pttOn = 0x08;
  static const pttOff = 0x88;
  static const readTransmitStatus = 0xF7;
}

/// A command, with how many bytes the radio answers it with.
///
/// The length travels WITH the command because it is the only thing that
/// tells one reply from another: a five-byte frequency answer and a
/// one-byte status answer are both just bytes on the wire, and a session
/// that lost track of which it asked for would read a status byte as the
/// first digit pair of a frequency.
class YaesuBinaryCommand {
  final List<int> bytes;

  /// How many bytes the manual says come back. Every command this driver
  /// sends answers something — the reads with their data, the writes with
  /// an acknowledgement — so there is no "answers nothing" case to
  /// express, and a session that had one would have to decide when a
  /// command was over with nothing to go on.
  final int replyLength;

  /// A command whose reply the radio may or may not send, so a session
  /// waiting for it must not treat silence as a fault.
  ///
  /// Yaesu's chart shows a returned byte for the toggles (`0x00` if the
  /// setting changed, `0xF0` if it was already there) and shows NOTHING for
  /// Set Frequency and Set Mode — while the field reports that
  /// contradict each other on whether those two ack. Rather than pick a
  /// side and desynchronise every later reply when the guess is wrong, a
  /// tolerant command accepts one byte if it comes and moves on if it does
  /// not.
  final bool replyOptional;

  const YaesuBinaryCommand(this.bytes, {required this.replyLength, this.replyOptional = false});
}

/// Four parameter bytes and the opcode. Anything the manual leaves as
/// "dummy data" is zero, which is what its own examples send.
List<int> _frame(int opcode, [int p1 = 0, int p2 = 0, int p3 = 0, int p4 = 0]) => [p1, p2, p3, p4, opcode];

/// Modes, by the code the manual's Set Operating Mode and Read Frequency &
/// Mode tables share.
///
/// The names are the app's own vocabulary, the same one the ASCII Yaesu and
/// Kenwood codecs use — `CW-R` is reverse-sideband CW, which CatService
/// folds back to CW before it can reach a log.
///
/// `DIG` is mapped to `DATA-USB` and not to a sideband-neutral name because
/// the app has none; which sideband it actually is depends on the radio's
/// own DIG MODE menu (RTTY-L, PSK-U, USER-U, USER-L), and CAT cannot read
/// that menu. An operator on USER-L logs one letter wrong until they set
/// the mode in the app, which is the same failure any unread menu produces
/// and better than reporting no mode at all.
const yaesuBinaryModeCodes = <String, int>{'LSB': 0x00, 'USB': 0x01, 'CW': 0x02, 'CW-R': 0x03, 'AM': 0x04, 'FM': 0x08, 'DATA-USB': 0x0A, 'DATA-FM': 0x0C};

/// Read-only codes: the radio reports them, and no Set Operating Mode
/// parameter produces them.
///
/// WFM is on every model's read table and on no model's set table. FM-N is
/// the reverse — the FT-857 and FT-897 set it with `0x88` and report it as
/// plain FM (`0x08`), so a round trip through the radio loses the "N" and
/// nothing here can hold it.
const yaesuBinaryReadOnlyModeCodes = <String, int>{'WFM': 0x06};

/// The narrow-FM set code the FT-857 and FT-897 add and the FT-817 does
/// not — see [buildSetModeCommand]'s `narrowFm`.
const yaesuBinaryFmNarrowCode = 0x88;

final Map<int, String> _modeNamesByCode = {
  for (final entry in yaesuBinaryModeCodes.entries) entry.value: entry.key,
  for (final entry in yaesuBinaryReadOnlyModeCodes.entries) entry.value: entry.key,
};

String? yaesuBinaryModeNameForCode(int code) => _modeNamesByCode[code];

int? yaesuBinaryCodeForModeName(String? name) => name == null ? null : yaesuBinaryModeCodes[name.toUpperCase()];

/// The radio's tuning step over CAT: four BCD bytes counting **tens of
/// hertz**, so `01 42 34 56` is 14.23456 MHz and the last digit of a Hz
/// value cannot be expressed at all.
///
/// A frequency is rounded to the nearest 10 Hz rather than truncated: a
/// spot on 14074.005 kHz is a rounding artefact away from the frequency
/// everyone else is on, and rounding down would land one step below it.
List<int> encodeBcdFrequency(int freqHz) {
  final tensOfHz = ((freqHz.abs() + 5) ~/ 10);
  final digits = tensOfHz.toString().padLeft(8, '0');
  // The LAST eight digits: a frequency above 999.99999 MHz cannot be
  // expressed, and truncating the way the radio's own four bytes would is
  // better than sending a longer command it would misread entirely.
  final trimmed = digits.substring(digits.length - 8);
  return [for (var i = 0; i < 8; i += 2) (int.parse(trimmed[i]) << 4) | int.parse(trimmed[i + 1])];
}

/// Null for anything that is not valid BCD — a nibble above 9 means these
/// bytes are not a frequency, and reading them as one would report the
/// radio as somewhere it has never been.
int? decodeBcdFrequency(List<int> bytes) {
  var tensOfHz = 0;
  for (final byte in bytes) {
    final tens = (byte >> 4) & 0x0F;
    final ones = byte & 0x0F;
    if (tens > 9 || ones > 9) return null;
    tensOfHz = tensOfHz * 100 + tens * 10 + ones;
  }
  return tensOfHz * 10;
}

/// Sets the VFO frequency. Answers nothing, or one acknowledgement byte —
/// see [YaesuBinaryCommand.replyOptional].
YaesuBinaryCommand buildSetFrequencyCommand(int freqHz) {
  final bcd = encodeBcdFrequency(freqHz);
  return YaesuBinaryCommand([...bcd, YaesuBinaryOpcode.setFrequency], replyLength: 1, replyOptional: true);
}

/// Null for a mode the radio has no code for, so the caller sends nothing
/// rather than a command the radio would read as some other mode.
///
/// [narrowFm] turns `FM-N` into the FT-857/FT-897 code; on an FT-817, which
/// has no such parameter, `FM-N` has no code and the caller sends nothing.
YaesuBinaryCommand? buildSetModeCommand(String? mode, {bool narrowFm = false}) {
  final normalized = mode?.toUpperCase();
  final code = narrowFm && normalized == 'FM-N' ? yaesuBinaryFmNarrowCode : yaesuBinaryCodeForModeName(normalized);
  if (code == null) return null;
  return YaesuBinaryCommand(_frame(YaesuBinaryOpcode.setMode, code), replyLength: 1, replyOptional: true);
}

/// Asks where the radio is and what mode it is in — one question for both,
/// unlike the ASCII line's two.
const YaesuBinaryCommand readFrequencyAndModeCommand = YaesuBinaryCommand([0, 0, 0, 0, YaesuBinaryOpcode.readFrequencyAndMode], replyLength: 5);

/// Asks whether the radio is keyed, and how the transmission is going.
const YaesuBinaryCommand readTransmitStatusCommand = YaesuBinaryCommand([0, 0, 0, 0, YaesuBinaryOpcode.readTransmitStatus], replyLength: 1);

/// Keys the transmitter over CAT, or unkeys it.
///
/// The radio answers `0x00` when the state changed and `0xF0` when it was
/// already there; both mean the radio is now in the requested state.
YaesuBinaryCommand buildPttCommand(bool on) => YaesuBinaryCommand(_frame(on ? YaesuBinaryOpcode.pttOn : YaesuBinaryOpcode.pttOff), replyLength: 1);

/// A five-byte Read Frequency & Mode reply: four BCD bytes then the mode.
class YaesuBinaryVfoReading {
  final int freqHz;

  /// Null for a mode code the chart does not list — the frequency is still
  /// good, and reporting a guessed mode beside it would put a wrong mode in
  /// a log that the right frequency makes look trustworthy.
  final String? mode;

  const YaesuBinaryVfoReading({required this.freqHz, this.mode});

  @override
  bool operator ==(Object other) => other is YaesuBinaryVfoReading && other.freqHz == freqHz && other.mode == mode;

  @override
  int get hashCode => Object.hash(freqHz, mode);

  @override
  String toString() => 'YaesuBinaryVfoReading($freqHz Hz, ${mode ?? 'unknown mode'})';
}

/// Null unless the reply is five bytes of valid BCD — see
/// [decodeBcdFrequency]. A reply this cannot read is one the session is out
/// of step with, and inventing a frequency from it is the one thing that
/// must not happen.
///
/// Zero is rejected with it. No radio on this protocol tunes to 0 Hz, and
/// `00` is the likeliest stray byte there is here — it is what every set
/// command acknowledges with — so four of them is a misread answer, not a
/// reading, and reporting it would park the app's idea of the radio at DC.
YaesuBinaryVfoReading? parseFrequencyAndMode(List<int> reply) {
  if (reply.length != 5) return null;
  final freqHz = decodeBcdFrequency(reply.sublist(0, 4));
  if (freqHz == null || freqHz == 0) return null;
  return YaesuBinaryVfoReading(freqHz: freqHz, mode: yaesuBinaryModeNameForCode(reply[4]));
}

/// What a Read TX Status byte says, per the manual's Note 4.
class YaesuBinaryTransmitStatus {
  /// The radio is keyed.
  final bool transmitting;

  /// The radio's own HI SWR flag — a single bit, not a ratio. Meaningful
  /// only while [transmitting].
  final bool highSwr;

  /// Split is on. Read for completeness of the byte; nothing acts on it.
  final bool split;

  /// The PO meter's raw 0-15 reading. Yaesu publishes no scale from it to
  /// watts, so it is raw here and stays raw until a bench capture builds
  /// one (drivers/info/README.md).
  final int powerOut;

  const YaesuBinaryTransmitStatus({required this.transmitting, required this.highSwr, required this.split, required this.powerOut});

  @override
  bool operator ==(Object other) =>
      other is YaesuBinaryTransmitStatus &&
      other.transmitting == transmitting &&
      other.highSwr == highSwr &&
      other.split == split &&
      other.powerOut == powerOut;

  @override
  int get hashCode => Object.hash(transmitting, highSwr, split, powerOut);
}

/// The byte a receiving radio answers Read TX Status with.
///
/// Not documented as such anywhere in Yaesu's chart, and worth naming: with
/// the transmitter off the register carries no reading at all, and every
/// flag in it reads as its "1" state — which for HI SWR means "ON". What
/// keeps that off an operator's screen is not a special case for this value
/// but [parseTransmitStatus] gating every flag on the PTT bit, so anything
/// that arrives while the radio says it is receiving is read as no reading
/// rather than as a reading of zero with an SWR alarm on top.
const yaesuBinaryTransmitStatusIdle = 0xFF;

/// What a Read TX Status byte says.
///
/// The bit legend is the chart's own Note 4, including the two flags that
/// disagree about polarity: SPLIT is printed `0: SPLIT "ON"` and HI SWR is
/// printed `0: HI SWR "OFF"`. Neither is inferred here.
///
/// The PTT bit's POLARITY is the one thing that note does not state: it
/// labels bit 7 "PTT" and gives no 0/1 legend, alone among the bits. Taken
/// as `0 = keyed`, which is what makes the idle
/// [yaesuBinaryTransmitStatusIdle] mean "receiving" — the two readings have
/// to agree, and this is the pairing that does. UNVERIFIED against
/// hardware; if it is backwards, a receiving radio reports as transmitting
/// the moment it answers anything but 0xFF.
YaesuBinaryTransmitStatus parseTransmitStatus(int byte) {
  final transmitting = (byte & 0x80) == 0;
  return YaesuBinaryTransmitStatus(
    transmitting: transmitting,
    // Only while keyed: the flags below describe a transmission in
    // progress, and a radio that is not transmitting has none. This is what
    // keeps the idle byte's "1" states from reaching the app as an SWR
    // alarm and a full-scale power reading.
    highSwr: transmitting && (byte & 0x40) != 0,
    split: transmitting && (byte & 0x20) == 0,
    powerOut: transmitting ? byte & 0x0F : 0,
  );
}

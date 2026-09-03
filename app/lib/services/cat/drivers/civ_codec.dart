// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CI-V is Icom's command protocol, shared across their transceiver line and
// officially documented per radio (the IC-705 CI-V Reference Guide). Pure:
// it builds and parses byte frames and knows nothing about serial ports,
// sockets or timers.
//
// Frame: FE FE <to> <from> <command> [<sub>] [<data>…] FD
//
// PROVENANCE: derived from Icom's own published CI-V documentation and from
// app-polo's CivProtocol.js (same author, MPL-2.0). Nothing here comes from
// wfview, which is GPLv3 and cannot be transcribed into this codebase.
//
// Four things app-polo's version did not do, each of which cost it
// something on the bench:
//   - it ignored FB/FA (ACK/NG), so a rejected command looked like silence;
//   - it did not check the destination address, so it could not tell its own
//     echo from a real reply — CI-V is a bus, and the radio echoes;
//   - its residual buffer was unbounded, so a stream that never produced a
//     terminator grew without limit;
//   - it hardcoded the controller address and always sent filter `01` on a
//     mode change, silently overriding the operator's filter selection.

/// Frame delimiters.
const civPreamble = 0xFE;
const civTerminator = 0xFD;

/// Frames addressed here are broadcast — what a radio sends when
/// "transceive" is on and it is announcing a change rather than answering.
const civBroadcastAddress = 0x00;

/// The controller (us). 0xE0 is the conventional default for a PC.
const civDefaultControllerAddress = 0xE0;

/// Default CI-V addresses, per radio. The IC-705 ships as 0xA4; the others
/// are here because the codec is model-agnostic and the driver takes the
/// address as configuration.
const civRadioAddresses = <String, int>{
  'IC-705': 0xA4,
  'IC-7300': 0x94,
  'IC-9700': 0xA2,
  'IC-7610': 0x98,
  'IC-905': 0xAC,
};

class CivCommand {
  /// Unsolicited frequency announcement (transceive).
  static const transceiveFrequency = 0x00;

  /// Unsolicited mode announcement (transceive).
  static const transceiveMode = 0x01;
  static const readFrequency = 0x03;
  static const readMode = 0x04;
  static const setFrequency = 0x05;
  static const setMode = 0x06;

  /// Read/set level data — a sub-command byte (see [civLevelRfPower])
  /// selects which level. Same command number for both directions: a
  /// request carries only the sub-command, a set also carries the value.
  static const readSetLevel = 0x14;

  /// Read meter data — read-only, unlike [readSetLevel]: a sub-command
  /// byte (see [civMeterDcInputVoltage]) selects which meter, and there is
  /// no matching "set".
  static const readMeter = 0x15;

  /// Keys the ASCII text that follows through the radio's keyer — up to 30
  /// characters, and a lone 0xFF instead of text aborts what is keying.
  /// The radio NAKs a second message while the first is still going out,
  /// which is why a session paces them (cw_send_queue.dart).
  static const sendCw = 0x17;

  /// The radio accepted the command.
  static const ack = 0xFB;

  /// The radio rejected it. polo ignored this, so a command the radio
  /// refused was indistinguishable from one it never received.
  static const nak = 0xFA;
}

const civModeCodes = <String, int>{
  'LSB': 0x00,
  'USB': 0x01,
  'AM': 0x02,
  'CW': 0x03,
  'RTTY': 0x04,
  'FM': 0x05,
  'WFM': 0x06,
  'CW-R': 0x07,
  'RTTY-R': 0x08,
  // IC-705 (and other D-STAR radios).
  'DV': 0x17,
};

final Map<int, String> _modeNamesByCode = {
  for (final entry in civModeCodes.entries) entry.value: entry.key,
};

String? civModeNameForCode(int code) => _modeNamesByCode[code];

int? civCodeForModeName(String? name) => name == null ? null : civModeCodes[name.toUpperCase()];

/// Frequency is five BCD bytes, **least-significant pair first**: byte 0
/// holds the 1 Hz/10 Hz digits, byte 4 the 100 MHz/1 GHz digits. Each byte
/// packs two decimal digits, more significant in the upper nibble.
///
/// The byte order is the part that catches people — it is the reverse of
/// how the number reads.
List<int> encodeBcdFrequency(int freqHz) {
  final digits = freqHz.abs().toString().padLeft(10, '0');
  final trimmed = digits.substring(digits.length - 10);
  return [
    for (var i = 8; i >= 0; i -= 2)
      (int.parse(trimmed[i]) << 4) | int.parse(trimmed[i + 1]),
  ];
}

/// Null for anything that isn't valid BCD — a nibble above 9 means the
/// bytes are not a frequency, and reading them as one would tune the radio
/// somewhere arbitrary.
int? decodeBcdFrequency(List<int> bytes) {
  final buffer = StringBuffer();
  for (var i = bytes.length - 1; i >= 0; i--) {
    final tens = (bytes[i] >> 4) & 0x0F;
    final ones = bytes[i] & 0x0F;
    if (tens > 9 || ones > 9) return null;
    buffer.write(tens);
    buffer.write(ones);
  }
  return int.tryParse(buffer.toString());
}

/// The sub-command selecting RF power within a 0x14 read/set-level frame.
/// Same sub-id across the line this driver targets (IC-705/7300/9700/7610).
const civLevelRfPower = 0x0A;

/// The keyer speed sub-command of [CivCommand.readSetLevel]: 0-255 standing
/// for 6-48 WPM, the range every current Icom keyer shares.
const civLevelKeyerSpeed = 0x0C;

/// The keyer's own limits, from the IC-7300/IC-705 CI-V guides.
const civKeyerSpeedMin = 6;
const civKeyerSpeedMax = 48;

/// The 0x14 0x0C level for [wpm]: linear over the keyer's range, which is
/// within one step of the radio's own table at every speed (hamlib's
/// `cw_lookup` for the same command lists 84 for 20 WPM against 85 here).
int civLevelForKeyerSpeed(int wpm) =>
    ((wpm.clamp(civKeyerSpeedMin, civKeyerSpeedMax) - civKeyerSpeedMin) * 255 / (civKeyerSpeedMax - civKeyerSpeedMin))
        .round();

/// The inverse of [civLevelForKeyerSpeed], rounded to a whole WPM.
int civKeyerSpeedForLevel(int level) =>
    civKeyerSpeedMin + (level.clamp(0, 255) * (civKeyerSpeedMax - civKeyerSpeedMin) / 255).round();

/// A 0x14-family level: two BCD bytes, MOST-significant pair first (the
/// opposite byte order from [encodeBcdFrequency]) — 0000-0255 standing for
/// 0-100% of whatever the level in question maxes out at.
List<int> encodeCivLevel(int value) {
  final digits = value.clamp(0, 255).toString().padLeft(4, '0');
  return [
    (int.parse(digits[0]) << 4) | int.parse(digits[1]),
    (int.parse(digits[2]) << 4) | int.parse(digits[3]),
  ];
}

/// Null for anything that isn't exactly two valid-BCD bytes.
int? decodeCivLevel(List<int> bytes) {
  if (bytes.length != 2) return null;
  final buffer = StringBuffer();
  for (final byte in bytes) {
    final tens = (byte >> 4) & 0x0F;
    final ones = byte & 0x0F;
    if (tens > 9 || ones > 9) return null;
    buffer.write(tens);
    buffer.write(ones);
  }
  return int.tryParse(buffer.toString());
}

/// One complete CI-V frame.
class CivFrame {
  final int to;
  final int from;
  final int command;

  /// Everything between the command and the terminator.
  final List<int> data;

  const CivFrame({required this.to, required this.from, required this.command, this.data = const []});

  bool get isAck => command == CivCommand.ack;
  bool get isNak => command == CivCommand.nak;

  /// Sent by us and reflected back. CI-V is a bus and the radio echoes what
  /// it receives, so this is normal traffic to be skipped, not an error.
  bool isEchoOf(int controllerAddress) => from == controllerAddress;

  /// Addressed to us, or broadcast (a transceive announcement).
  bool isFor(int controllerAddress) => to == controllerAddress || to == civBroadcastAddress;

  @override
  bool operator ==(Object other) =>
      other is CivFrame &&
      other.to == to &&
      other.from == from &&
      other.command == command &&
      _sameBytes(other.data, data);

  @override
  int get hashCode => Object.hash(to, from, command, Object.hashAll(data));

  @override
  String toString() =>
      'CivFrame(to: 0x${to.toRadixString(16)}, from: 0x${from.toRadixString(16)}, '
      'cmd: 0x${command.toRadixString(16)}, data: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')})';
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<int> buildCivFrame({
  required int to,
  int from = civDefaultControllerAddress,
  required int command,
  List<int> data = const [],
}) =>
    [civPreamble, civPreamble, to, from, command, ...data, civTerminator];

List<int> buildReadFrequencyFrame({required int to, int from = civDefaultControllerAddress}) =>
    buildCivFrame(to: to, from: from, command: CivCommand.readFrequency);

List<int> buildReadModeFrame({required int to, int from = civDefaultControllerAddress}) =>
    buildCivFrame(to: to, from: from, command: CivCommand.readMode);

List<int> buildSetFrequencyFrame({
  required int to,
  int from = civDefaultControllerAddress,
  required int freqHz,
}) =>
    buildCivFrame(to: to, from: from, command: CivCommand.setFrequency, data: encodeBcdFrequency(freqHz));

/// [filter] is deliberately optional and omitted by default. polo always
/// sent `01`, which silently forced the operator's filter to FIL1 every
/// time the mode changed. Sending the mode alone leaves it alone.
List<int>? buildSetModeFrame({
  required int to,
  int from = civDefaultControllerAddress,
  required String? mode,
  int? filter,
}) {
  final code = civCodeForModeName(mode);
  if (code == null) return null;
  return buildCivFrame(
    to: to,
    from: from,
    command: CivCommand.setMode,
    data: [code, if (filter != null) filter],
  );
}

List<int> buildReadPowerLevelFrame({required int to, int from = civDefaultControllerAddress}) =>
    buildCivFrame(to: to, from: from, command: CivCommand.readSetLevel, data: [civLevelRfPower]);

List<int> buildSetPowerLevelFrame({
  required int to,
  int from = civDefaultControllerAddress,
  required int level,
}) =>
    buildCivFrame(to: to, from: from, command: CivCommand.readSetLevel, data: [civLevelRfPower, ...encodeCivLevel(level)]);

/// `frame.data` from a 0x14 reply, once it's been confirmed to be the RF
/// power sub-command — null for a reply too short to hold the 2-byte level,
/// or one that fails BCD decoding.
int? parsePowerLevelData(List<int> data) => data.length < 3 ? null : decodeCivLevel(data.sublist(1, 3));

List<int> buildReadKeyerSpeedFrame({required int to, int from = civDefaultControllerAddress}) =>
    buildCivFrame(to: to, from: from, command: CivCommand.readSetLevel, data: [civLevelKeyerSpeed]);

List<int> buildSetKeyerSpeedFrame({
  required int to,
  int from = civDefaultControllerAddress,
  required int level,
}) =>
    buildCivFrame(
        to: to, from: from, command: CivCommand.readSetLevel, data: [civLevelKeyerSpeed, ...encodeCivLevel(level)]);

/// `frame.data` from a 0x14 reply already confirmed to be the keyer-speed
/// sub-command — the same two BCD bytes as [parsePowerLevelData].
int? parseKeyerSpeedLevelData(List<int> data) => parsePowerLevelData(data);

/// [text] must already be sanitized (cw_send_queue.dart) and at most
/// [civCwMaxChars] long — the codec sends what it is given.
List<int> buildSendCwFrame({required int to, int from = civDefaultControllerAddress, required String text}) =>
    buildCivFrame(to: to, from: from, command: CivCommand.sendCw, data: text.codeUnits);

/// Aborts the message being keyed.
List<int> buildStopCwFrame({required int to, int from = civDefaultControllerAddress}) =>
    buildCivFrame(to: to, from: from, command: CivCommand.sendCw, data: const [0xFF]);

/// What one [CivCommand.sendCw] may carry, per the CI-V guides.
const civCwMaxChars = 30;

/// DC input to the radio, in tenths of a volt (e.g. level 115 means
/// 11.5V) — distinguishes external DC from internal battery on a radio
/// that can run on either. Confirmed LIVE against an IC-705: ~11.5V on
/// its internal battery, ~19.5V with a 12V-class external supply
/// connected — the RF-power SET level (0x14 0x0A) does not change either
/// way, but the radio quietly caps actual output on battery (see the RF
/// power METER, 0x15 0x11). Voltage scaling is inferred from that one
/// bench session, not a published reference.
const civMeterDcInputVoltage = 0x15;

List<int> buildReadMeterFrame({
  required int to,
  int from = civDefaultControllerAddress,
  required int meterId,
}) =>
    buildCivFrame(to: to, from: from, command: CivCommand.readMeter, data: [meterId]);

/// `frame.data` from a 0x15 reply, once it's been confirmed to be the
/// meter asked for — same shape as a 0x14 reply, so this is just
/// [parsePowerLevelData] under a name that doesn't say "power" for a
/// family of readings that isn't.
int? parseMeterData(List<int> data) => parsePowerLevelData(data);

/// Splits a byte stream into complete `FE FE … FD` frames, keeping any
/// trailing partial frame for the next call.
class CivFramer {
  /// Bytes seen since the last terminator.
  final _residual = <int>[];

  /// A cap, because the residual is fed by whatever arrives on the wire. A
  /// stream that never produces a terminator — a wrong baud rate, a
  /// half-open socket dribbling noise — must not grow the buffer without
  /// limit. polo's had no cap.
  ///
  /// Well above the largest CI-V frame anything here sends or expects.
  static const maxResidual = 1024;

  List<CivFrame> add(List<int> incoming) {
    _residual.addAll(incoming);

    final frames = <CivFrame>[];
    var start = 0;

    while (start < _residual.length) {
      if (_residual[start] != civPreamble) {
        start++;
        continue;
      }
      // A frame opens with exactly TWO preambles.
      if (start + 1 >= _residual.length) break;
      if (_residual[start + 1] != civPreamble) {
        start++;
        continue;
      }

      // Collapse a run of them down to the last two. A noisy line (or a
      // radio still coming up) can repeat FE, and the frame that follows
      // begins at the final pair — without this, a run of preambles gets
      // swallowed into one bogus frame along with the real one behind it,
      // whose command byte then reads as 0xFE.
      var payload = start + 2;
      while (payload < _residual.length && _residual[payload] == civPreamble) {
        payload++;
      }
      final frameStart = payload - 2;

      final end = _residual.indexOf(civTerminator, payload);
      if (end == -1) {
        // Keep the pair and whatever follows it; the earlier run is junk.
        start = frameStart;
        break;
      }
      final frame = parseCivFrame(_residual.sublist(frameStart, end + 1));
      if (frame != null) frames.add(frame);
      start = end + 1;
    }

    _residual.removeRange(0, start);
    if (_residual.length > maxResidual) {
      // Nothing in here has been framed; keeping the tail rather than
      // everything means a stream that recovers still frames its next real
      // frame.
      _residual.removeRange(0, _residual.length - maxResidual);
    }
    return frames;
  }

  /// Drops any partial frame — for a fresh connection, so a truncated tail
  /// from the previous one cannot prefix the first real frame.
  void reset() => _residual.clear();
}

/// Parses one complete frame, or null if it isn't well-formed.
CivFrame? parseCivFrame(List<int> frame) {
  // FE FE to from cmd FD is the shortest legal frame.
  if (frame.length < 6) return null;
  if (frame[0] != civPreamble || frame[1] != civPreamble) return null;
  if (frame.last != civTerminator) return null;

  return CivFrame(
    to: frame[2],
    from: frame[3],
    command: frame[4],
    data: frame.sublist(5, frame.length - 1),
  );
}

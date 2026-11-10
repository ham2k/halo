// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The line protocol a Green Heron Everyware server speaks to its clients
// (docs/design/cat.md § Green Heron Everyware). Pure: lines in, messages out,
// commands as bytes — the hub and the device sessions hold all the state.
//
// CP1252 text, one message a line, CR LF from the client. A line is fields
// split by U+001F, and a switch position is sub-fields split by U+001D.

import 'package:crypto/crypto.dart';

/// Everyware's own default; a server can be moved, and WU2X's is.
const everywareDefaultPort = 17220;

const _field = '\u001F';
const _subField = '\u001D';

/// The single byte a client sends to keep its connection — never in the same
/// write as a command, which the server would read as part of it.
const everywareKeepalive = [0];

/// What CP1252 puts at 0x80–0x9F, where Latin-1 has control characters. A
/// name typed on the server's Windows machine with a curly quote or an en
/// dash would otherwise come back as a control character, and a command
/// carrying it would name a device the server does not have.
const _cp1252High = <int, int>{
  0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E, 0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021, //
  0x88: 0x02C6, 0x89: 0x2030, 0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152, 0x8E: 0x017D, 0x91: 0x2018, //
  0x92: 0x2019, 0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022, 0x96: 0x2013, 0x97: 0x2014, 0x98: 0x02DC, //
  0x99: 0x2122, 0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178,
};
final _cp1252Back = {for (final entry in _cp1252High.entries) entry.value: entry.key};

String cp1252Decode(List<int> bytes) => String.fromCharCodes([for (final byte in bytes) _cp1252High[byte] ?? byte]);

/// A character CP1252 cannot carry becomes `?`, as Java's encoder makes it.
List<int> cp1252Encode(String text) => [for (final rune in text.runes) _cp1252Back[rune] ?? (rune < 0x100 && (rune < 0x80 || rune > 0x9F) ? rune : 0x3F)];

/// Splits the server's bytes into lines the way Java's `readLine` does: on
/// LF, CR LF or a lone CR, with a CR at the end of one chunk and its LF at
/// the start of the next still one line break.
class EverywareLineSplitter {
  final _line = <int>[];
  bool _skipLf = false;

  /// A line this long is not Everyware; it is dropped rather than buffered
  /// for good.
  static const maxLineBytes = 64 * 1024;
  bool _overflow = false;

  List<String> add(List<int> bytes) {
    final lines = <String>[];
    for (final byte in bytes) {
      if (_skipLf) {
        _skipLf = false;
        if (byte == 0x0A) continue;
      }
      if (byte == 0x0A || byte == 0x0D) {
        if (!_overflow) lines.add(cp1252Decode(_line));
        _line.clear();
        _overflow = false;
        _skipLf = byte == 0x0D;
      } else if (_line.length < maxLineBytes) {
        _line.add(byte);
      } else {
        _overflow = true;
      }
    }
    return lines;
  }

  void reset() {
    _line.clear();
    _skipLf = false;
    _overflow = false;
  }
}

/// What a switch's positions carry, by its display type.
enum EverywareSwitchKind {
  /// Plain buttons, one per position.
  buttons(1),

  /// A compass: each position is a direction, with a heading and beamwidth —
  /// a 4-square, a crossfire array.
  map(2),

  /// Each position covers a frequency range.
  band(3),

  /// Positions turned on and off independently rather than one selected.
  bank(4);

  final int wire;
  const EverywareSwitchKind(this.wire);

  /// Null for a type this app does not know — shown as buttons, as the
  /// Everyware client shows one.
  static EverywareSwitchKind? fromWire(int? type) => values.where((kind) => kind.wire == type).firstOrNull;
}

/// One position of a switch, as `SWITCHADD` announced it.
class EverywarePosition {
  final String name;

  /// A map switch's direction and beam, in degrees; zero on other kinds.
  final int heading;
  final int beamwidth;
  final bool bidirectional;

  /// A band switch's range, in MHz; zero on other kinds.
  final double lowMHz;
  final double highMHz;

  const EverywarePosition(this.name, {this.heading = 0, this.beamwidth = 0, this.bidirectional = false, this.lowMHz = 0, this.highMHz = 0});

  bool covers(double mhz) => lowMHz <= mhz && mhz <= highMHz;

  @override
  bool operator ==(Object other) =>
      other is EverywarePosition &&
      other.name == name &&
      other.heading == heading &&
      other.beamwidth == beamwidth &&
      other.bidirectional == bidirectional &&
      other.lowMHz == lowMHz &&
      other.highMHz == highMHz;

  @override
  int get hashCode => Object.hash(name, heading, beamwidth, bidirectional, lowMHz, highMHz);

  @override
  String toString() => 'EverywarePosition($name)';
}

sealed class EverywareMessage {
  const EverywareMessage();
}

/// The server wants a user name before anything else.
class EverywareAskUser extends EverywareMessage {
  const EverywareAskUser();
}

/// The server wants the password, proven against [challenge].
class EverywareAskPassword extends EverywareMessage {
  final String challenge;
  const EverywareAskPassword(this.challenge);
}

class EverywareLoginRefused extends EverywareMessage {
  const EverywareLoginRefused();
}

/// The server is closing this connection.
class EverywareClose extends EverywareMessage {
  const EverywareClose();
}

class EverywareRotorAdded extends EverywareMessage {
  final String name;
  const EverywareRotorAdded(this.name);
}

class EverywareRotorRemoved extends EverywareMessage {
  final String name;
  const EverywareRotorRemoved(this.name);
}

/// Where a rotor points, and how the server says it is.
class EverywarePoint extends EverywareMessage {
  final String name;
  final double heading;

  /// `'0'` fine; `'1'` offline and `'5'` not answering the server; `'7'` a
  /// fixed antenna; the others are motion the heading already shows.
  /// `'2'` when the line has no status, as the oldest servers send it.
  final String status;

  const EverywarePoint(this.name, this.heading, {this.status = '2'});

  /// The server cannot reach the controller, so [heading] is stale.
  bool get unreachable => status == '1' || status == '5';
}

class EverywareSwitchAdded extends EverywareMessage {
  final String name;

  /// The wire's display type, which [kind] reads.
  final int type;
  final List<EverywarePosition> positions;
  const EverywareSwitchAdded(this.name, this.type, this.positions);

  EverywareSwitchKind? get kind => EverywareSwitchKind.fromWire(type);
}

class EverywareSwitchRemoved extends EverywareMessage {
  final String name;
  const EverywareSwitchRemoved(this.name);
}

/// A switch's selected position — `UNKNOWN` when the server does not know,
/// and on a bank a comma list or `NONE_SELECTED`.
class EverywareSwitchUpdate extends EverywareMessage {
  final String name;
  final String position;
  const EverywareSwitchUpdate(this.name, this.position);
}

/// The positions of a switch another switch's selection has locked out. The
/// whole set each time; empty clears it.
class EverywareSwitchLocks extends EverywareMessage {
  final String name;
  final Set<String> locked;
  const EverywareSwitchLocks(this.name, this.locked);
}

/// A stack: up to four antennas switched in and out together, named by the
/// comma list of their names. Listed, not driven: nothing here can show
/// several antennas on at once.
class EverywareStackAdded extends EverywareMessage {
  final String name;
  const EverywareStackAdded(this.name);
}

class EverywareStackRemoved extends EverywareMessage {
  final String name;
  const EverywareStackRemoved(this.name);
}

/// A line this app does not act on — stack states, presets, Tornado tuners, pop-ups —
/// or one too malformed to read.
class EverywareOther extends EverywareMessage {
  final String line;
  const EverywareOther(this.line);
}

/// Reads one line, its terminator already gone. Never throws: a line that
/// cannot be read is an [EverywareOther], so one bad line costs one line.
EverywareMessage parseEverywareLine(String line) {
  if (line.startsWith('USER:')) return const EverywareAskUser();
  if (line.startsWith('PASS:')) return EverywareAskPassword(line.substring(5));
  if (line == 'INVALID USER/PASS') return const EverywareLoginRefused();
  if (line == 'CLOSE') return const EverywareClose();
  final fields = line.split(_field);
  String? at(int index) => index < fields.length ? fields[index] : null;
  switch (fields.first) {
    case 'ADD':
      if (at(1) case final name?) return EverywareRotorAdded(name);
    case 'REMOVE':
      if (at(1) case final name?) return EverywareRotorRemoved(name);
    case 'POINT':
      final name = at(1);
      final heading = double.tryParse(at(2)?.trim() ?? '');
      if (name == null || heading == null) break;
      final status = at(3);
      return EverywarePoint(name, heading, status: status == null || status.isEmpty ? '2' : status.substring(0, 1));
    case 'SWITCHADD':
      return _switchAdded(fields) ?? EverywareOther(line);
    case 'SWITCHREMOVE':
      if (at(1) case final name?) return EverywareSwitchRemoved(name);
    case 'SWITCHUPDATE':
      if ((at(1), at(2)) case (final name?, final position?)) return EverywareSwitchUpdate(name, position);
    case 'STACKADD':
      if (at(1) case final name?) return EverywareStackAdded(name);
    case 'STACKREMOVE':
      if (at(1) case final name?) return EverywareStackRemoved(name);
    case 'SWITCHLOCKS':
      if (at(1) case final name?) return EverywareSwitchLocks(name, {...fields.skip(2).where((position) => position.isNotEmpty)});
  }
  return EverywareOther(line);
}

/// `SWITCHADD␟type␟name␟position…`. A map or band switch whose numbers do not
/// read is refused whole: a direction or range read as zero would point the
/// antenna somewhere nobody chose.
EverywareSwitchAdded? _switchAdded(List<String> fields) {
  if (fields.length < 3) return null;
  final type = int.tryParse(fields[1].trim());
  if (type == null) return null;
  final name = fields[2].split(_subField).first;
  final kind = EverywareSwitchKind.fromWire(type);
  final positions = <EverywarePosition>[];
  for (final entry in fields.skip(3)) {
    final sub = entry.split(_subField);
    String? at(int index) => index < sub.length ? sub[index].trim() : null;
    if (kind == EverywareSwitchKind.band) {
      // A range left blank on the server is no range, not an unreadable one.
      final low = (at(1) ?? '').isEmpty ? 0.0 : double.tryParse(at(1)!);
      final high = (at(2) ?? '').isEmpty ? 0.0 : double.tryParse(at(2)!);
      if (low == null || high == null) return null;
      positions.add(EverywarePosition(sub.first, lowMHz: low, highMHz: high));
    } else {
      // Read as numbers, not integers: a heading written `45.0` is still 45.
      final heading = at(1) == null ? 0 : double.tryParse(at(1)!)?.round();
      final beamwidth = at(2) == null ? 0 : double.tryParse(at(2)!)?.round();
      if (kind == EverywareSwitchKind.map && (heading == null || beamwidth == null)) return null;
      positions.add(EverywarePosition(sub.first, heading: heading ?? 0, beamwidth: beamwidth ?? 0, bidirectional: at(3)?.toLowerCase() == 'true'));
    }
  }
  return EverywareSwitchAdded(name, type, positions);
}

List<int> _command(List<String> fields) => [...cp1252Encode(fields.join(_field)), 0x0D, 0x0A];

/// Turns [rotor] to [heading] true degrees. Whole degrees: the controllers
/// behind it turn in whole degrees, and a fraction only lengthens the line.
List<int> everywareTurn(String rotor, int heading) => _command(['TURN', rotor, '$heading']);

List<int> everywareStop(String rotor) => _command(['STOP', rotor]);

List<int> everywareSetSwitch(String name, String position) => _command(['SET_SWITCH', name, position]);

/// The user name, answering `USER:`.
List<int> everywareUser(String user) => [...cp1252Encode(user), 0x0D, 0x0A];

/// The 32 bytes answering `PASS:<challenge>`, with no line ending.
///
/// The password is hashed as the low byte of each UTF-16 unit, not as
/// CP1252 — that is what the server stores, so it is what has to match.
List<int> everywarePasswordProof({required String user, required String password, required String challenge}) {
  final userBytes = cp1252Encode(user);
  final passwordHash = sha256.convert([...userBytes, for (final unit in password.codeUnits) unit & 0xFF]).bytes;
  return sha256.convert([...userBytes, ...cp1252Encode(challenge), ...passwordHash]).bytes;
}

/// For a log line or a test: the line with its separators made visible.
String everywareVisible(String line) => line.replaceAll(_field, '␟').replaceAll(_subField, '␝');

/// Reads bytes the client is about to send back as text — for the tests, and
/// the fake server that stands in for a real one.
String everywareCommandText(List<int> bytes) => cp1252Decode(bytes).replaceAll(RegExp(r'[\r\n]+$'), '');

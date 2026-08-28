// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Sierra Radio Systems Device Control Network (DCN) wire format.
//
// Pure — strings in, records out. Unlike the Antenna Genius, Sierra Radio
// publishes this: the envelope, the addressing and the common verbs are all
// specified in the Station Controller Advanced Technical Manual (rev 3) and
// the USB-C Console Port Reference Manual.
//
// The envelope is a family, not one module's protocol — a GPIO board, a watt
// meter and a coax switch all speak it, differing only in payload. That is
// why this file is the envelope plus the CX-1's payloads rather than a file
// per module: a second module reuses everything above [CoaxState].
//
// A packet is `/FFTT:PAYLOAD:CC`. We terminate with CR, which is the
// specified end of packet; a CX-1 answers with CRLF and a lowercase check
// value, so neither the terminator nor that field is worth matching on:
//
//   /0002:SEL1:XX<CR>     select port 1 on the module at address 02
//   /0200:UPDATE,...:XX   that module answering the master at address 00
//   //STATE<CR>           broadcast — every module decodes it
//
// Two constraints the format imposes, both load-bearing here:
//
// - **A payload may contain no colon.** The colon delimits it on both sides,
//   so a label containing one cannot round-trip and the manual forbids it.
// - **The check value is a placeholder.** `CC` is documented as an 8-bit LRC
//   or 16-bit CRC, and the manual states current firmware neither computes
//   nor verifies it, sending the literal `XX`. So this codec sends `XX` and
//   ignores whatever arrives, rather than validating a field no peer fills
//   in — a check that rejected real packets would be worse than none.

/// The check-value placeholder every shipping module uses. See above.
///
/// Sent uppercase, as the manual writes it. A CX-1 answers with a lowercase
/// `xx`, which is a second reason not to compare this field to anything.
const dcnCrcPlaceholder = 'XX';

/// The master's address — the Node-Red dashboard's, and ours. The manual
/// reserves it; a module is 01-15 by DIP switch, or 16-99 set in software.
const dcnMasterAddress = '00';

/// One packet, either direction.
class DcnPacket {
  /// Two characters. Null for a broadcast (`//PAYLOAD`), which names no
  /// sender — the difference matters, because a reply is addressed back to
  /// wherever a command came from and a broadcast gives it nowhere to go.
  final String? from;

  /// Two characters, or null on a broadcast.
  final String? to;

  /// Everything between the delimiting colons: a command and up to twenty
  /// comma-separated arguments.
  final String payload;

  const DcnPacket({required this.payload, this.from, this.to});

  bool get isBroadcast => from == null;

  /// The payload's comma-separated fields. `UPDATE,CX1,0010` yields three.
  List<String> get fields => payload.split(',');

  /// The first field — the command or, in an answer, the packet type.
  String get command => fields.first;

  @override
  String toString() => 'DcnPacket(${isBroadcast ? '//' : '$from>$to'} $payload)';
}

/// A module's address as the two characters the envelope carries.
///
/// Accepts what the operator typed: a single digit is padded, and anything
/// already two characters — a software-assigned 16-99 — is passed through
/// rather than re-padded.
///
/// The manual permits any printable character and recommends digits. The
/// driver's own validator allows only digits, so nothing else can be stored;
/// this does not reject one, because a value that somehow reached storage is
/// better addressed than silently turned into the master's address.
String dcnAddress(Object? address) {
  final text = (address ?? '').toString().trim();
  if (text.isEmpty) return dcnMasterAddress;
  if (text.length >= 2) return text.substring(0, 2);
  return text.padLeft(2, '0');
}

/// An addressed packet, ready for the wire.
///
/// Terminated by a bare CR (0x0D), which is the specified end of packet —
/// NOT CRLF. A module scans for the terminator and evaluates its input
/// buffer there, so a stray LF would be carried into the next packet's start
/// and the buffer flushed when it failed to parse.
String buildDcnPacket(String payload, {required String to, String from = dcnMasterAddress}) =>
    '/$from$to:$payload:$dcnCrcPlaceholder\r';

/// A broadcast packet — decoded by every module on the bus.
///
/// This is also the form a module's own USB-C console port expects, where
/// there is only one device to talk to. The driver does not use it: the
/// addressed form works on the console port too, and on a bus with more than
/// one module a broadcast makes every one of them answer at once, which the
/// manual warns "will cause a big conflict".
String buildDcnBroadcast(String payload) => '//$payload\r';

/// One frame off the wire, or null if it is not a packet.
///
/// Null rather than an exception for the reason the Antenna Genius codec
/// gives: a module's boot banner, a console prompt and anything a later
/// firmware volunteers all arrive on this stream, and a parser that threw
/// would turn a greeting into a dead connection.
DcnPacket? parseDcnPacket(String line) {
  final text = line.trim();
  if (!text.startsWith('/')) return null;

  if (text.startsWith('//')) {
    final payload = _stripCheckValue(text.substring(2));
    return payload.isEmpty ? null : DcnPacket(payload: payload);
  }

  // `/FFTT:` — four address characters and the opening delimiter.
  if (text.length < 6 || text[5] != ':') return null;
  final payload = _stripCheckValue(text.substring(6));
  if (payload.isEmpty) return null;
  return DcnPacket(payload: payload, from: text.substring(1, 3), to: text.substring(3, 5));
}

/// Everything before the closing delimiter.
///
/// A payload contains no colon, so the first one ends it. Tolerates a packet
/// with no check value at all: the field is a placeholder nothing verifies,
/// and a firmware that omits it is still saying something worth reading.
String _stripCheckValue(String rest) {
  final end = rest.indexOf(':');
  return (end < 0 ? rest : rest.substring(0, end)).trim();
}

// ---------------------------------------------------------------------------
// CX-1 4-port HF coax relay module
// ---------------------------------------------------------------------------

/// How many antenna ports a CX-1 switches. Four, plus the common port.
const cx1PortCount = 4;

/// Selects one port. `SEL1`..`SEL4`.
///
/// Documented, oddly, in the GPIO module's manual rather than the coax
/// module's own — the #331 manual publishes no command section at all. The
/// GPIO board can be configured to emit `/0003:SEL1:XX` when one of its
/// digital inputs triggers, "a command to coax relay module with device
/// address 03 and the command is SEL1 which means select port 1".
///
/// The module answers this with the same `UPDATE` a [dcnStateCommand]
/// returns, about a second later — the relay's own settling time. So a
/// select needs no follow-up query; the answer IS the new state.
///
/// A port it does not have is answered with **silence**. `SEL9` produced
/// nothing at all on hardware, as did an unknown verb, so a refusal and a
/// dead cable look identical on the wire and nothing can report one. That is
/// why the driver bounds the port before sending rather than after.
String cx1SelectCommand(int port) => 'SEL$port';

/// Asks any module for an `UPDATE` describing its current state.
const dcnStateCommand = 'STATE';

/// Asks the module for its per-port text labels — the names shown on its
/// optional LCD, up to 13 characters each.
const cx1LabelCommand = 'LABEL';

/// Which port a coax module has selected.
class CoaxState {
  /// The module type token the `UPDATE` carried — `GPIO1` on a GPIO board.
  /// Kept rather than matched: it is what tells the master how to parse the
  /// rest, and reporting it is how an operator finds out they addressed a
  /// watt meter.
  final String moduleType;

  /// 1-based, or null when the mask says nothing is selected.
  ///
  /// Null is a real state, not a parse failure: the relays are latching, so
  /// a module that has never been told anything since assembly holds no port
  /// at all, and an all-zero mask is what it reports.
  final int? selectedPort;

  /// The mask exactly as received, for [EquipmentSink.reportDiagnostic].
  final String mask;

  const CoaxState({required this.moduleType, required this.mask, this.selectedPort});
}

final _maskPattern = RegExp(r'^[01]{2,}$');

/// A coax module's `UPDATE` packet, or null if this is not one.
///
/// Captured from a CX-1: `/0200:UPDATE,CX1,1000:xx` is port 1 selected, and
/// the mask is positional and MSB-first — port 1 is the leftmost character,
/// port 4 the rightmost, matching the one worked example the Advanced
/// Technical Manual narrates ("0001 indicating that port 4").
///
/// The mask is FOUND rather than taken from field index 2, where this
/// firmware puts it. The GPIO board's published `UPDATE` carries several
/// more fields (`UPDATE,GPIO1,01000000,0110,12.000,...`), so the field list
/// is per-module and a parser pinned to an index breaks on the next one.
///
/// Positional, and deliberately not "count the ones": a mask with more than
/// one bit set is a module doing something this driver does not model, and
/// taking the first would silently show one of two connected antennas.
CoaxState? parseCoaxUpdate(DcnPacket packet) {
  final fields = packet.fields;
  if (fields.first != 'UPDATE' || fields.length < 3) return null;

  final mask = fields.skip(2).firstWhere((f) => _maskPattern.hasMatch(f), orElse: () => '');
  if (mask.isEmpty) return null;
  // A wider mask is a different module — a GPIO board reports eight relays,
  // and its `01000000` would otherwise publish a selection on port 2, or
  // `00000001` a port 8 that no antenna list can name. The driver's sender
  // filter normally keeps those out; this is what stands behind a node
  // pointed at the wrong address, where the filter is satisfied and wrong.
  if (mask.length > cx1PortCount) return null;
  if (mask.split('').where((c) => c == '1').length > 1) return null;

  final index = mask.indexOf('1');
  return CoaxState(
    moduleType: fields[1],
    mask: mask,
    selectedPort: index < 0 ? null : index + 1,
  );
}

final _labelPattern = RegExp(r'^Label\s+(\d+)\s*=\s*(.*)$');

/// One port's label, from a `LABEL` answer — `(2, '20M YAGI')`.
///
/// **This takes a raw line, not a [DcnPacket], and that is the point.** A
/// CX-1 answers `LABEL` in plain console text with no envelope at all — a
/// `LABELS` header followed by `Label 1 = `, `Label 2 = ` and so on, one per
/// line, roughly 200 ms apart. Everything else the module says is a proper
/// packet, so this is the one reply that would be dropped by a reader that
/// only ever parses packets.
///
/// Null for the `LABELS` header, for a port outside the four, and for an
/// empty label — which is what an unnamed port answers, and what makes the
/// driver fall back to numbering it.
///
/// Deliberately strict about the whole line: a `STATUS` answer arrives in
/// the same plain-text form and includes `Relays     : 1000`, a mask that a
/// looser reader would happily mistake for content.
(int, String)? parseCoaxLabel(String line) {
  final match = _labelPattern.firstMatch(line.trim());
  if (match == null) return null;

  final port = int.tryParse(match.group(1)!);
  if (port == null || port < 1 || port > cx1PortCount) return null;

  final text = match.group(2)!.trim();
  return text.isEmpty ? null : (port, text);
}

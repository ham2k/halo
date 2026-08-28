// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The 4O3A Antenna Genius wire format: what a line off the switch means.
//
// Pure — strings in, records out. Every fact here was established against a
// real 8x2 running firmware 4.1.16 (HALO-414 carries the capture), because
// 4O3A's "Genius Series Communication Protocol" document is not public and
// the verb set had to be enumerated. So this file is the protocol
// documentation as much as it is the parser, and the session above it holds
// no parsing of its own.
//
// The envelope is the SmartSDR API's: commands are `C<seq>|<verb> <sub>`,
// answers `R<seq>|<code>|<payload>`, unsolicited status `S0|<payload>`.
// Framing is line_framer.dart's, shared with the FlexRadio driver.

/// A reply to a command we sent.
class AgReply {
  final int seq;

  /// 0 is success. The switch distinguishes its refusals: 10 is a verb it
  /// does not have, 20 a subcommand or argument it will not take, 30 an
  /// unknown noun after `sub`. Kept as the raw number — the driver reports
  /// the code rather than inventing a sentence per value, since a firmware
  /// that adds one would otherwise render as a success.
  final int code;

  /// Everything after the second `|`. Empty on a bare acknowledgement, and
  /// on the blank line that terminates a multi-line answer.
  final String payload;

  const AgReply(this.seq, this.code, this.payload);

  bool get ok => code == 0;
}

/// An unsolicited status line — what `sub port all` delivers on every change.
class AgStatus {
  final String payload;

  const AgStatus(this.payload);
}

final _replyPattern = RegExp(r'^R(\d+)\|(\d+)\|(.*)$');
final _statusPattern = RegExp(r'^S[0-9A-Fa-f]*\|(.*)$');

/// One line off the wire, as whichever of the two shapes it is — or null for
/// the `V4.1.16 AG` banner and anything else the switch volunteers.
///
/// Null rather than an exception: an unrecognised line is the switch saying
/// something a later firmware added, and a driver that threw on it would
/// turn a new greeting into a dead connection.
Object? parseAgLine(String line) {
  if (_replyPattern.firstMatch(line) case final m?) {
    return AgReply(int.parse(m.group(1)!), int.parse(m.group(2)!), m.group(3)!);
  }
  if (_statusPattern.firstMatch(line) case final m?) return AgStatus(m.group(1)!);
  return null;
}

/// The `key=value` pairs in a payload, after its leading noun and index.
///
/// `port 1 auto=1 source=AUTO band=0` yields `{auto: 1, source: AUTO,
/// band: 0}`. Values are left as strings: `source=AUTO` and `band=0` sit in
/// the same map, and a parser that guessed types would have to guess per key.
///
/// A bare word with no `=` is skipped rather than stored under itself — the
/// noun and index are read positionally by the callers below, and letting
/// them through as keys would put `port` and `1` in the map too.
Map<String, String> parseAgFields(String payload) {
  final fields = <String, String>{};
  for (final token in payload.split(' ')) {
    final eq = token.indexOf('=');
    // >0, not >=0: a token starting with '=' has no name.
    if (eq > 0) fields[token.substring(0, eq)] = token.substring(eq + 1);
  }
  return fields;
}

/// The noun and index a payload opens with — `('port', '1')` — or null when
/// it opens with neither, which is what the blank terminator line does.
({String noun, String index})? parseAgSubject(String payload) {
  final parts = payload.split(' ');
  if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
  return (noun: parts[0], index: parts[1]);
}

/// The switch's own account of itself, from `info get`.
class AgInfo {
  final String? firmware;
  final String? serial;
  final String? name;

  /// How many device ports and antenna ports the box has — `ports=2
  /// antennas=8` on an 8x2. What it is BUILT with, which says nothing about
  /// which side the operator wired their radios to; that stays a setting.
  final int? ports;
  final int? antennas;

  const AgInfo({this.firmware, this.serial, this.name, this.ports, this.antennas});

  static AgInfo parse(String payload) {
    final f = parseAgFields(payload);
    return AgInfo(
      firmware: f['v'],
      serial: f['serial'],
      // The switch substitutes underscores for spaces in a name the operator
      // typed with them ("Antenna_Genius"), and does the same for antenna
      // names — so both are put back here rather than at each display site.
      name: f['name']?.replaceAll('_', ' '),
      ports: int.tryParse(f['ports'] ?? ''),
      antennas: int.tryParse(f['antennas'] ?? ''),
    );
  }
}

/// One line of `antenna list`.
///
/// `tx=`/`rx=` are 16-bit band bitmasks indexed by the switch's own band
/// table. An antenna allowed on no band at all is an unwired port — that is
/// how the four `Antenna_4`..`Antenna_7` placeholders on a half-populated
/// 8x2 identify themselves, and the only way to tell them from a real
/// antenna the operator has not renamed.
class AgAntenna {
  final String key;
  final String name;
  final int txBands;
  final int rxBands;

  const AgAntenna({required this.key, required this.name, this.txBands = 0, this.rxBands = 0});

  bool get configured => txBands != 0 || rxBands != 0;

  static AgAntenna? parse(String payload) {
    final subject = parseAgSubject(payload);
    if (subject == null || subject.noun != 'antenna') return null;
    final f = parseAgFields(payload);
    return AgAntenna(
      key: subject.index,
      name: (f['name'] ?? '').replaceAll('_', ' '),
      txBands: int.tryParse(f['tx'] ?? '', radix: 16) ?? 0,
      rxBands: int.tryParse(f['rx'] ?? '', radix: 16) ?? 0,
    );
  }
}

/// One `port` line, from `port get N` or from the subscription.
class AgPort {
  final String key;

  /// Which antenna the port receives on. `0` means none, and arrives here as
  /// null — the switch uses the same field for "nothing selected" as for a
  /// selection, and a caller comparing against `'0'` would route to an
  /// antenna port that does not exist.
  final String? rxAntenna;
  final String? txAntenna;

  /// The switch is picking this port's antenna itself, from band data.
  ///
  /// The line also carries a `source=` naming what is doing the driving
  /// (`AUTO` and `FLEX` observed). It is not parsed: [auto] already carries
  /// the behaviour and [radioName] the identity, so a third field would be
  /// surface with no reader.
  final bool auto;

  /// The name the driving radio gave itself — a FlexRadio's nickname.
  ///
  /// Present on a port CONFIGURED to follow a radio, whether or not that
  /// radio is currently on a band: the bench 8x2 named the same Flex on both
  /// ports while reporting `band=0` for one of them. So this answers "which
  /// radio feeds this port", not "which radio is using it".
  final String? radioName;

  /// What the driving radio is tuned to, in MHz as the switch reports it —
  /// `freq=14.074000`. Zero means it has not said, and arrives as null.
  final double? freqMHz;

  /// The band the switch believes the port is on, by its own table index.
  /// `0` is its "None", which arrives as null for the same reason as the
  /// antennas above.
  final String? bandIndex;

  final bool transmitting;
  final bool inhibited;

  const AgPort({
    required this.key,
    this.rxAntenna,
    this.txAntenna,
    this.auto = false,
    this.radioName,
    this.freqMHz,
    this.bandIndex,
    this.transmitting = false,
    this.inhibited = false,
  });

  static String? _selection(String? raw) => (raw == null || raw == '0') ? null : raw;

  static AgPort? parse(String payload) {
    final subject = parseAgSubject(payload);
    if (subject == null || subject.noun != 'port') return null;
    final f = parseAgFields(payload);
    return AgPort(
      key: subject.index,
      rxAntenna: _selection(f['rxant']),
      txAntenna: _selection(f['txant']),
      auto: f['auto'] == '1',
      radioName: f['nickname']?.replaceAll('_', ' '),
      // Zero is "nothing to say", the same convention rxant and band use.
      freqMHz: switch (double.tryParse(f['freq'] ?? '')) { 0 => null, final v => v },
      bandIndex: _selection(f['band']),
      transmitting: f['tx'] == '1',
      inhibited: f['inhibit'] == '1',
    );
  }
}

/// One line of `band list` — the switch's own band table, which is what a
/// port's `band=` indexes into.
class AgBand {
  final String key;
  final String name;

  const AgBand({required this.key, required this.name});

  static AgBand? parse(String payload) {
    final subject = parseAgSubject(payload);
    if (subject == null || subject.noun != 'band') return null;
    return AgBand(key: subject.index, name: (parseAgFields(payload)['name'] ?? '').replaceAll('_', ' '));
  }
}

/// What an Antenna Genius says about itself when it announces on the network.
///
/// It broadcasts on UDP 9007 — the same port NUMBER as its TCP API but a
/// different protocol on a different socket, exactly the arrangement a
/// FlexRadio uses on 4992. Unlike the Flex there is no VITA-49 wrapper: the
/// datagram is the plain ASCII line below, CRLF-terminated.
///
///     AG ip=10.0.0.67 port=9007 v=4.1.16 serial=00-00-00
///        name=Antenna_Genius ports=2 antennas=8 mode=master uptime=6143110
///
/// Captured off a real 8x2; like everything else in this file it is
/// observed, not documented.
class AgAnnouncement {
  final String host;
  final int port;
  final String? serial;
  final String? name;
  final String? firmware;
  final int? ports;
  final int? antennas;

  const AgAnnouncement({
    required this.host,
    required this.port,
    this.serial,
    this.name,
    this.firmware,
    this.ports,
    this.antennas,
  });
}

/// Reads one discovery datagram, or null for anything that is not a usable
/// Antenna Genius announcement.
///
/// An address is required rather than defaulted to the datagram's sender:
/// the announcement states where to connect, and a switch behind any kind of
/// forwarding is telling us something the packet's envelope does not. Without
/// one there is nothing to offer, so a datagram from something else sharing
/// the port is ignored rather than half-parsed into a device with nowhere to
/// connect to.
AgAnnouncement? parseAgAnnouncement(List<int> datagram) {
  final text = String.fromCharCodes(datagram.where((b) => b >= 0x20 && b < 0x7f));
  // The leading `AG` marks it; without that check any `ip=` line on this port
  // would be offered as an antenna switch.
  if (!text.startsWith('AG ')) return null;

  final fields = parseAgFields(text);
  final host = fields['ip'];
  if (host == null || host.isEmpty) return null;

  return AgAnnouncement(
    host: host,
    port: int.tryParse(fields['port'] ?? '') ?? antennaGeniusAnnouncePort,
    serial: fields['serial'],
    name: fields['name']?.replaceAll('_', ' '),
    firmware: fields['v'],
    ports: int.tryParse(fields['ports'] ?? ''),
    antennas: int.tryParse(fields['antennas'] ?? ''),
  );
}

/// The UDP port an Antenna Genius announces on, which is also the TCP port it
/// listens on — the same coincidence FlexRadio's 4992 is, and the same
/// non-relationship: a different protocol on a different socket.
const antennaGeniusAnnouncePort = 9007;

/// The letter on the front panel for a port the protocol numbers from 1.
///
/// The operator reads `A`/`B` off the box and the wire says `1`/`2`, so
/// something has to translate; doing it here keeps [AgPort.key] the
/// switch's own value everywhere else. Falls back to the raw key for a
/// number past `Z` or one that is not a number at all, which is visible
/// rather than wrong.
String agPortLabel(String key) {
  final n = int.tryParse(key);
  if (n == null || n < 1 || n > 26) return key;
  return String.fromCharCode(0x40 + n);
}

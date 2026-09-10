// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// 4O3A Antenna Genius — an antenna switch on the network, the first piece of
// equipment in this layer that is not a radio.
//
// It routes a set of antenna ports to a set of device ports; an 8x2 has
// eight of the former and two of the latter. Which side the operator wired
// their radios to is theirs to say ([switchLayoutConfigKey]) — `info get`
// reports how the box is BUILT, and the same box run backwards is a 2x8.
//
// The wire format is antenna_genius_codec.dart's; the framing is shared with
// the FlexRadio driver, because 4O3A modelled the protocol on the SmartSDR
// API down to the `C<seq>|` envelope.
//
// The session pushes: `sub port all` delivers a fresh line on every change,
// so there is no poller and [expectedUpdateInterval] is null.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';
import '../discovery.dart';
import '../driver.dart';
import '../equipment.dart';
import '../transports/udp_broadcast.dart';
import 'antenna_genius_codec.dart';
import 'line_framer.dart';

/// How often to re-ask a quiet switch for its ports.
///
/// A backstop, not a cadence — the subscription pushes every change as it
/// happens. What this exists for is the manager's silence watchdog: a switch
/// that nobody is touching says nothing at all, and 30 seconds of that is
/// indistinguishable from a dead socket ([EquipmentState.stale]). So it is
/// deliberately shorter than that 30 s, with room for one to go missing.
///
/// `sub port all` rather than a ping: verified idempotent on a real 8x2 —
/// re-subscribing answers with the full port list and accumulates nothing —
/// so the same command that proves the link is alive also repairs a push
/// that was never delivered. FlexRadio's driver keeps its 60 s resync for
/// the repair and pings for the proof of life instead — its refresh is four
/// commands and a status burst, too heavy to run three times a minute.
const antennaGeniusResyncInterval = Duration(seconds: 10);

/// How many un-answered commands to remember, for naming one in a refusal.
/// Small: only the most recent can still be answered.
const _maxPendingCommands = 16;

/// What a standing [EquipmentSink.reportProblem] is about — see
/// [AntennaGeniusSession._problemKind].
enum _ProblemKind { none, refusedCommand, transmitting }

/// The port 4O3A ships the Genius series listening on — the same number it
/// announces itself on over UDP, see [antennaGeniusAnnouncePort].
const antennaGeniusDefaultPort = antennaGeniusAnnouncePort;

/// Which side of the switch the radios are plugged into.
///
/// `devicePorts` is how the box is sold — an 8x2 is eight antennas to two
/// radios. `antennaPorts` is the same hardware run backwards, two antennas
/// out to eight devices, which is a real way to use one and one the switch
/// itself cannot detect.
const switchLayoutConfigKey = 'switchLayout';
const switchLayoutDevicePorts = 'devicePorts';
const switchLayoutAntennaPorts = 'antennaPorts';

/// An Antenna Genius announcing itself on the LAN.
///
/// Keyed by serial, so a switch that picks up a new DHCP address updates its
/// entry rather than appearing twice — it re-announces every few seconds, and
/// without a stable id the Add dialog fills with copies of one switch.
class AntennaGeniusDiscoverer implements EquipmentDiscoverer {
  final String typeKey;

  const AntennaGeniusDiscoverer({required this.typeKey});

  @override
  Stream<DiscoveredEquipment> discover() => udpBroadcastDatagrams(port: antennaGeniusAnnouncePort)
      .map(parseAgAnnouncement)
      .where((found) => found != null)
      .map(
        (found) => DiscoveredEquipment(
          typeKey: typeKey,
          id: found!.serial ?? '${found.host}:${found.port}',
          name: found.name ?? 'Antenna Genius',
          // The shape is worth a place here: it is what tells an 8x2 from an
          // 8x1 at a glance, and it is the one thing an operator with two
          // switches on the bench sorts them by.
          detail: [
            if (found.antennas != null && found.ports != null) '${found.antennas}x${found.ports}',
            if (found.firmware != null) 'v${found.firmware}',
            found.host,
          ].join(' · '),
          config: {'host': found.host, 'port': found.port},
        ),
      );
}

/// The form key for the live routing control of one device port.
///
/// Deliberately NOT a config key, and stripped before the form's values are
/// stored: what a port is routed to is the switch's state, and persisting it
/// would put a stale claim about relays into the record — the one thing
/// docs/design/cat.md § Persistence forbids. It rides in the form because
/// that is where the operator is, not because it is a setting.
String switchPortRoutingFormKey(String portKey) => 'switchRouting_$portKey';

/// Whether [key] is one of the above — what the editor tests to keep these
/// out of the saved config.
bool isSwitchPortRoutingFormKey(String key) => key.startsWith('switchRouting_');

/// The config key holding which of the operator's own antenna nodes is wired
/// to one of the switch's antenna ports.
///
/// Keyed by the switch's own [SwitchAntenna.key] rather than by position, so
/// re-mapping one port cannot shift every link after it — and so a link
/// survives the operator renaming an antenna on the switch itself.
String switchAntennaNodeConfigKey(String antennaKey) => 'antennaNode_$antennaKey';

class AntennaGeniusDriver extends EquipmentDriver {
  const AntennaGeniusDriver();

  @override
  String get key => 'antenna-genius';

  @override
  String get name => 'Antenna Genius';


  /// Every model in the Genius series this driver covers has eight — the
  /// 8x1 and the 8x2 differ in device ports, not antenna ports.
  @override
  int get antennaPortCount => 8;

  /// The 8x2's. An 8x1 has one, and says so over the wire — which is why the
  /// Station panel relabels the wiring options from what the switch actually
  /// reported whenever it is connected. This is only what a first-time setup
  /// is offered, before anything has been asked.
  @override
  int get devicePortCount => 2;

  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) {
    final st = t.settings.station;
    return [
      if (!overrides.containsKey(switchLayoutConfigKey))
        {
          'type': 'field',
          'fieldType': 'select',
          'key': switchLayoutConfigKey,
          'label': st.switchLayout,
          'description': st.switchLayoutDescription,
          // Named by what is on each side rather than by "as sold" and
          // "reversed": the operator is looking at their own coax, and only
          // one of these two counts matches what they plugged in where.
          'options': [
            {
              'value': switchLayoutDevicePorts,
              'label': st.switchLayoutSides(antennas: antennaPortCount, radios: devicePortCount),
            },
            {
              'value': switchLayoutAntennaPorts,
              'label': st.switchLayoutSides(antennas: devicePortCount, radios: antennaPortCount),
            },
          ],
        },
    ];
  }

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != switchLayoutConfigKey) return null;
    // Blank is the shipped layout, not a missing answer: an operator who
    // never opens this field has an 8x2 wired the way it is sold.
    if (value == null || value == '') return null;
    return (value == switchLayoutDevicePorts || value == switchLayoutAntennaPorts)
        ? null
        : t.settings.station.switchLayoutRequired;
  }

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      AntennaGeniusSession(sink, reversed: config[switchLayoutConfigKey] == switchLayoutAntennaPorts);
}

/// An [AntennaSwitchSession] and deliberately not a [TransceiverSession]:
/// nothing here sets a frequency, a mode or a power, and those methods are
/// not on this type to leave unimplemented.
class AntennaGeniusSession implements AntennaSwitchSession {
  final EquipmentSink _sink;

  /// The operator wired their radios to the side the switch calls antennas.
  ///
  /// Only the labelling changes. The wire is unaffected — `port set N
  /// rxant=X` still names the same two relay banks whichever way round the
  /// coax runs — so this is applied when the state is reported and nowhere
  /// else.
  final bool reversed;

  AntennaGeniusSession(this._sink, {this.reversed = false});

  final _framer = LineFramer();
  int _seq = 1;

  /// What the switch has said so far, by its own key. Held because it
  /// reports the two lists on separate exchanges — `antenna list` answers
  /// once at startup, the port subscription then pushes for the life of the
  /// connection — while [EquipmentSink.reportSwitchState] takes both
  /// together, so a port update has to be merged with the antennas already
  /// known rather than replacing them.
  final Map<String, AgAntenna> _antennas = {};
  final Map<String, AgPort> _ports = {};

  /// The switch's own band table, by index — what a port's `band=` refers
  /// to. Read once; a firmware cannot renumber its bands while connected.
  final Map<String, String> _bands = {};

  AgInfo? _info;

  /// What each command we have sent was, so a refusal can name it: a bare
  /// `R<seq>|20|` carries nothing but the number, and "the switch refused
  /// error 20" is not something an operator can act on.
  ///
  /// Retired at the FIRST reply for a sequence, which is the only one a
  /// refusal ever has. Waiting for the blank line that terminates a
  /// multi-line answer would leak an entry for every command answered in one
  /// non-empty line — `info get` and `port get` both are.
  final Map<int, String> _pending = {};

  bool _wantUpdates = false;

  /// The sequence number of the `sub port all` that ends bring-up, while it
  /// is still outstanding.
  ///
  /// Nothing is published before it answers. The switch sends the inventory
  /// as one line per antenna port and — measured on a real 8x2 — each in its
  /// own TCP segment, so both publishing per line and publishing per chunk
  /// rebuild the Station panel seven to ten times on every connect, each
  /// showing one more antenna than the last. The subscription is answered
  /// last and its reply is an exact boundary, which a timer would only ever
  /// approximate.
  int? _bringUpSeq;

  Timer? _resyncTimer;

  /// The port a [selectAntenna] was refused on because it was keyed, until it
  /// stops being. Without it that refusal sits on the row until some later
  /// command happens to succeed, and an operator who gives up and reaches for
  /// the switch's own panel never sends one.
  String? _refusedWhileTransmitting;

  /// What the standing problem is ABOUT, so that only the thing which
  /// resolves it clears it.
  ///
  /// Reporting null on every successful reply looks equivalent and is not:
  /// the 10 s resync's own acknowledgement is a successful reply, so a
  /// "that port is transmitting" warning — or a refusal for a verb this
  /// firmware does not have — was wiped within ten seconds while the
  /// condition still held. The unit tests could not see it, because none of
  /// them let the resync timer fire.
  _ProblemKind _problemKind = _ProblemKind.none;

  void _setProblem(_ProblemKind kind, String? message) {
    if (_problemKind == kind && kind == _ProblemKind.none) return;
    _problemKind = kind;
    _sink.reportProblem(message);
  }

  int _send(String command) {
    final seq = _seq++;
    // Entries retire when their reply lands. A switch that has gone mute is
    // not disconnected — it is only marked stale — so the 10 s resync would
    // otherwise add one every 10 s for the life of the connection. Only the
    // most recent few can still be answered, and a refusal names the command
    // it refused from here.
    if (_pending.length >= _maxPendingCommands) {
      final oldest = _pending.keys.reduce((a, b) => a < b ? a : b);
      _pending.remove(oldest);
    }
    _pending[seq] = command;
    _sink.send(utf8.encode('C$seq|$command\n'));
    return seq;
  }

  @override
  void startUpdates() {
    _wantUpdates = true;
    // Order matters only for the first frame the panel draws: the port
    // subscription answers immediately with every port, and a port names its
    // antenna by key, so asking for the inventory first is what keeps the
    // panel from rendering two selections it cannot resolve.
    _send('info get');
    _send('band list');
    _send('antenna list');
    // Answered last, and its reply is what releases the first publish.
    _bringUpSeq = _send('sub port all');

    _resyncTimer?.cancel();
    _resyncTimer = Timer.periodic(antennaGeniusResyncInterval, (_) {
      if (_wantUpdates) _send('sub port all');
    });
  }

  @override
  void stopUpdates() {
    _resyncTimer?.cancel();
    _resyncTimer = null;
    if (!_wantUpdates) return;
    _wantUpdates = false;
    _send('unsub port all');
  }

  @override
  void teardown() {
    stopUpdates();
    _framer.reset();
    // A reconnect starts a fresh bring-up, and a sequence left outstanding
    // from the last one would hold the new picture back forever.
    _bringUpSeq = null;
    _pending.clear();
  }

  /// Null: the switch pushes. Every change reaches us as it happens, so a
  /// quiet connection means a switch nobody is touching — see
  /// [EquipmentSession.expectedUpdateInterval] for why that claim matters.
  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void handleData(Uint8List chunk) {
    // Accumulated across the chunk, and held back entirely until bring-up
    // finishes — see [_bringUpSeq].
    var changed = false;
    for (final line in _framer.add(chunk)) {
      switch (parseAgLine(line)) {
        case AgReply reply:
          changed |= _handleReply(reply);
        case AgStatus status:
          changed |= _absorb(status.payload);
        // The `V4.1.16 AG` banner, and anything a later firmware volunteers.
        default:
          break;
      }
    }
    if (changed && _bringUpSeq == null) _publish();
  }

  /// Whether this reply changed the routing picture.
  bool _handleReply(AgReply reply) {
    final command = _pending.remove(reply.seq);
    // Bring-up is over whether the subscription was accepted or refused: a
    // switch that will not subscribe still answered the inventory, and
    // holding the picture back forever would leave the panel blank on a
    // connection that is otherwise fine.
    // Also released by any LATER sequence answering, not only by its own:
    // nothing else clears this and there is no timeout, so a firmware that
    // acknowledges the subscription some other way — or an acknowledgement
    // lost on the wire — would gate every publish for the life of an
    // otherwise healthy connection, leaving a blank panel whose watchdog is
    // never fed. The 10 s resync then guarantees recovery.
    final endsBringUp = _bringUpSeq != null && reply.seq >= _bringUpSeq!;
    if (endsBringUp) _bringUpSeq = null;
    if (!reply.ok) {
      // A refused command is not a broken link — the switch is answering,
      // and reconnecting cannot make it accept a verb it does not have. That
      // is exactly the line EquipmentSink.reportProblem draws.
      _setProblem(
        _ProblemKind.refusedCommand,
        t.settings.station.switchCommandRefused(command: command ?? '?', code: reply.code),
      );
      return endsBringUp;
    }
    // The blank line that ends a multi-line answer, and the bare
    // acknowledgement of a command with nothing to say. Both retire the
    // sequence; neither carries anything to absorb.
    if (reply.payload.isEmpty) {
      // A command going through is evidence that a REFUSED one no longer
      // describes the switch — and evidence of nothing at all about a port
      // that is transmitting, which only that port can clear.
      if (_problemKind == _ProblemKind.refusedCommand) _setProblem(_ProblemKind.none, null);
      return endsBringUp;
    }
    return _absorb(reply.payload) || endsBringUp;
  }

  /// Files one payload under whatever it turns out to be. False when it was
  /// nothing this driver tracks, so an unrecognised noun costs no rebuild.
  bool _absorb(String payload) {
    switch (parseAgSubject(payload)?.noun) {
      case 'info':
        _info = AgInfo.parse(payload);
        _reportInfo();
        // Not part of the routing picture — it only names the box.
        return false;
      case 'antenna':
        if (AgAntenna.parse(payload) case final antenna?) {
          _antennas[antenna.key] = antenna;
          return true;
        }
      case 'port':
        if (AgPort.parse(payload) case final port?) {
          _ports[port.key] = port;
          if (_refusedWhileTransmitting == port.key && !port.transmitting) {
            _refusedWhileTransmitting = null;
            if (_problemKind == _ProblemKind.transmitting) _setProblem(_ProblemKind.none, null);
          }
          return true;
        }
      case 'band':
        if (AgBand.parse(payload) case final band?) {
          _bands[band.key] = band.name;
          // Only meaningful once a port cites one, and a port line will.
          return false;
        }
    }
    return false;
  }

  void _reportInfo() {
    final info = _info;
    if (info == null) return;
    _sink.reportDiagnostic([
      if (info.name != null) info.name,
      if (info.firmware != null) 'v${info.firmware}',
      if (info.serial != null) 's/n ${info.serial}',
      if (info.ports != null && info.antennas != null) '${info.antennas}x${info.ports}',
    ].join(' · '));
  }

  /// The whole routing picture, in the switch's own numbering.
  ///
  /// Sorted numerically rather than by the map's insertion order: the
  /// subscription pushes one port at a time and re-inserting a moved port
  /// would otherwise reorder the panel's rows under the operator's finger.
  void _publish() {
    final antennaKeys = _antennas.keys.toList()..sort(_byNumber);
    final portKeys = _ports.keys.toList()..sort(_byNumber);
    _sink.reportSwitchState(
      [
        for (final key in antennaKeys)
          SwitchAntenna(
            key: key,
            name: _antennas[key]!.name,
            configured: _antennas[key]!.configured,
          ),
      ],
      [
        for (final key in portKeys)
          if (_ports[key] case final port?)
            SwitchPort(
              key: key,
              // Reversed, the letters belong to the other side of the box —
              // so a port that is now an antenna feed is numbered, not
              // lettered, and the operator is not hunting for a "Port A"
              // their radios are not on.
              label: reversed ? key : agPortLabel(key),
              // rx, not tx: the switch moves txant to follow rxant on its
              // own, and a port set up receive-only has no txant to read.
              selectedAntennaKey: port.rxAntenna,
              auto: port.auto,
              band: port.bandIndex == null ? null : _bands[port.bandIndex!],
              radioName: port.radioName,
              // MHz on the wire, kHz past this boundary — the conversion
              // every driver does on its own edge, and the one app-polo
              // shipped wrong (docs/design/cat.md § Units).
              freqKHz: port.freqMHz == null ? null : port.freqMHz! * 1000,
              transmitting: port.transmitting,
              inhibited: port.inhibited,
            ),
      ],
    );
  }

  static int _byNumber(String a, String b) =>
      (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0);

  @override
  void selectAntenna(String portKey, String antennaKey) {
    // Never under RF. A relay switched while the port is keyed is a relay
    // destroyed, and the switch does not refuse this for us — it accepted
    // every `port set` it was given on the bench. The operator's selection
    // is dropped rather than queued: by the time the port unkeys, a
    // selection made during someone else's transmission is stale.
    if (_ports[portKey]?.transmitting ?? false) {
      _refusedWhileTransmitting = portKey;
      _setProblem(_ProblemKind.transmitting, t.settings.station.switchBusyTransmitting);
      return;
    }
    // txant follows rxant on the switch's own side, verified on hardware —
    // so this one write moves both, except on a port its owner configured
    // receive-only, where moving tx is not ours to do anyway.
    _send('port set $portKey rxant=$antennaKey');
  }

  @override
  String toString() => 'AntennaGeniusSession(${_ports.length} ports, ${_antennas.length} antennas)';
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Sierra Radio Systems CX-1 (#331) — a 4-port HF coax relay module on a
// serial port, and the second antenna switch in this layer after the 4O3A
// Antenna Genius.
//
// One common port routed to one of four antenna ports, or the same hardware
// run backwards: one antenna shared by four radios. The module cannot tell
// which, so which side the radios are on is the operator's to say — the same
// [switchLayoutConfigKey] the Antenna Genius introduced, and here it changes
// more than a label, because the two wirings put the single relay on
// opposite sides of the picture. See [_publish].
//
// The wire format is sierra_dcn_codec.dart's. Framing is line_framer.dart's
// with [LineFramer.crTerminates] set: the DCN's end of packet is a bare CR,
// and a CX-1 answers CRLF.
//
// The session POLLS, and has to. A front-panel press moves the relay and
// the module says NOTHING — measured, not assumed: a port driven from 2 to 3
// by hand across a 45-second window produced not one byte. A Raspberry Pi
// dashboard on the same bus changes it the same way.
//
// It also sends **one command at a time**. See [sierraCoaxHandshakeGap].

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';
import '../driver.dart';
import '../equipment.dart';
import 'antenna_genius_driver.dart'
    show switchLayoutAntennaPorts, switchLayoutConfigKey, switchLayoutDevicePorts;
import 'line_framer.dart';
import 'sierra_dcn_codec.dart';

/// How often to ask the module what it is set to.
///
/// A poll and not a backstop, unlike the Antenna Genius' resync: a
/// front-panel press is announced by nothing, so this is the only way one
/// ever reaches us, and between two polls the panel is showing an antenna
/// that may not be connected. Short enough that the manager's 30 s silence
/// watchdog has room for several to go missing, long enough to stay a small
/// share of a 9600-baud half-duplex bus the operator's own dashboard may be
/// polling — the manual warns that two masters inserting traffic at once
/// collide.
const sierraCoaxPollInterval = Duration(seconds: 5);

/// Which module on the bus this node is. 01-15 by DIP switch on the module.
const sierraAddressConfigKey = 'dcnAddress';

/// How long bring-up waits between asking for the labels and asking for the
/// state, and the reason nothing here is ever pipelined.
///
/// The DCN's wired form is half-duplex RS-485: one differential pair that a
/// transmitting node drives and therefore cannot listen on. A second command
/// sent while the module is mid-answer collides with that answer on the
/// shared pair, and the loss is the MODULE's reply rather than our command —
/// so the symptom is a missing label, not an error.
///
/// Sized from the hardware rather than guessed: a CX-1 answers `LABEL` with
/// one plain-text line per port about 200 ms apart, so the four take a
/// little under a second.
const sierraCoaxHandshakeGap = Duration(milliseconds: 1200);

/// The factory default for a coax relay module — the Advanced Technical
/// Manual's table: GPIO 1, coax relay 2, watt meter 3.
const sierraCoaxDefaultAddress = '2';

/// The DCN is fixed at 9600 8N1 by its own specification, so the operator is
/// never asked. An override rather than a default: a baud picker on a bus
/// with one legal speed is a way to break a working switch.
const sierraDcnBaudRate = 9600;

/// The common port's key, in the switch's own terms.
///
/// Not a number: the module numbers its four switched ports 1-4 and the
/// common port is not one of them, so any digit here would collide with a
/// [SwitchAntenna.key] in the map the operator's antenna links are stored
/// against.
const sierraCommonPortKey = 'C';

class SierraCoaxDriver extends EquipmentDriver {
  const SierraCoaxDriver();

  @override
  String get key => 'sierra-coax';

  @override
  String get name => 'Sierra Radio CX-1';

  /// Verified against a CX-1: every payload shape in sierra_dcn_codec.dart
  /// is something that module actually said, including the two the published
  /// manuals get wrong or omit — the plain-text `LABEL` answer, and `SELn`
  /// replying with the new state on its own.
  @override
  bool get hardwareVerified => true;

  @override
  int get antennaPortCount => cx1PortCount;

  /// The common port. One, whichever way the coax runs — the reversed
  /// wiring does not give the module a second relay, it moves the one it has
  /// to the other side of the picture.
  @override
  int get devicePortCount => 1;

  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) {
    final st = t.settings.station;
    return [
      if (!overrides.containsKey(sierraAddressConfigKey))
        {
          'type': 'field',
          'fieldType': 'text',
          'key': sierraAddressConfigKey,
          'label': st.dcnAddress,
          'description': st.dcnAddressDescription,
        },
      if (!overrides.containsKey(switchLayoutConfigKey))
        {
          'type': 'field',
          'fieldType': 'select',
          'key': switchLayoutConfigKey,
          'label': st.switchLayout,
          'description': st.switchLayoutDescription,
          'options': [
            {
              'value': switchLayoutDevicePorts,
              'label': st.switchLayoutSidesOneRadio(antennas: cx1PortCount),
            },
            {
              'value': switchLayoutAntennaPorts,
              'label': st.switchLayoutSidesOneAntenna(radios: cx1PortCount),
            },
          ],
        },
    ];
  }

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key == switchLayoutConfigKey) {
      if (value == null || value == '') return null;
      return (value == switchLayoutDevicePorts || value == switchLayoutAntennaPorts)
          ? null
          : t.settings.station.switchLayoutRequired;
    }
    if (key != sierraAddressConfigKey) return null;

    final text = (value ?? '').toString().trim();
    // Blank is the factory default, not a missing answer: a module nobody
    // has re-addressed is at 2, and that is what the field prefills.
    if (text.isEmpty) return null;
    final address = int.tryParse(text);
    // 00 is the master — ours. A node addressed there talks to itself and
    // the module never hears a word, which looks exactly like a dead cable.
    if (address == null || address < 1 || address > 99) {
      return t.settings.station.dcnAddressRequired;
    }
    return null;
  }

  /// The configured address, or the factory default.
  ///
  /// An EMPTY value falls back, not just a missing key. The validator accepts
  /// a blank field on purpose — a module nobody re-addressed is at 2 — and
  /// the editor stores a cleared text field as `''`, so a `??` alone leaves
  /// [dcnAddress] to turn it into the master's own `00`. Every command would
  /// then be addressed to us, and the session's sender filter would drop
  /// every real reply: a node that connects, stays green, polls forever and
  /// never shows a port.
  static String addressFrom(Map<String, dynamic> config) {
    final configured = (config[sierraAddressConfigKey] ?? '').toString().trim();
    return dcnAddress(configured.isEmpty ? sierraCoaxDefaultAddress : configured);
  }

  @override
  String? describeSuffix(Map<String, dynamic> config, {Map<String, dynamic> overrides = const {}}) {
    if (overrides.containsKey(sierraAddressConfigKey)) return null;
    return ' · DCN ${addressFrom(config)}';
  }

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => SierraCoaxSession(
        sink,
        address: addressFrom(config),
        reversed: config[switchLayoutConfigKey] == switchLayoutAntennaPorts,
      );
}

/// An [AntennaSwitchSession] and not a [TransceiverSession]: nothing here
/// has a frequency.
class SierraCoaxSession implements AntennaSwitchSession {
  final EquipmentSink _sink;

  /// The module's address on the bus, two characters.
  final String address;

  /// The operator wired four radios to the switched ports and one antenna to
  /// the common port. Unlike the Antenna Genius', this is not only a
  /// relabelling — see [_publish].
  final bool reversed;

  SierraCoaxSession(this._sink, {required this.address, this.reversed = false});

  /// CR-terminated: the DCN's end of packet, not the LF every other driver
  /// in this layer frames on.
  final _framer = LineFramer(crTerminates: true);

  /// The module's own text for each port, 1-based, as far as it has told us.
  /// Empty until `LABEL` answers, and stays empty on a module with none set.
  final Map<int, String> _labels = {};

  CoaxState? _state;

  bool _wantUpdates = false;
  Timer? _pollTimer;

  void _send(String payload) =>
      _sink.send(utf8.encode(buildDcnPacket(payload, to: address)));

  @override
  void startUpdates() {
    _wantUpdates = true;
    // Labels first, state second, and the publish is gated on the state — so
    // the panel is drawn once with the antenna names already in it, rather
    // than once bare and again a moment later. A module that never answers
    // `LABEL` costs nothing: the ports fall back to their numbers.
    //
    // Separated by [sierraCoaxHandshakeGap] rather than sent together,
    // because the labels take most of a second to arrive and a half-duplex
    // bus cannot carry our second command over them.
    _send(cx1LabelCommand);

    _pollTimer?.cancel();
    _pollTimer = Timer(sierraCoaxHandshakeGap, () {
      if (!_wantUpdates) return;
      _send(dcnStateCommand);
      _armPoll();
    });
  }

  void _armPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(sierraCoaxPollInterval, (_) {
      if (_wantUpdates) _send(dcnStateCommand);
    });
  }

  @override
  void stopUpdates() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _wantUpdates = false;
  }

  @override
  void teardown() {
    stopUpdates();
    _framer.reset();
    // A reconnect re-asks. Holding the last selection across one would show
    // a stale claim about relays for as long as the new connection took to
    // answer, and the relays are latching — they may well have been moved by
    // hand in between, which is the case this driver polls for at all.
    _state = null;
    _labels.clear();
  }

  /// The poll period: this session asks, it is never told.
  @override
  Duration? get expectedUpdateInterval => sierraCoaxPollInterval;

  @override
  void handleData(Uint8List chunk) {
    var changed = false;
    for (final line in _framer.add(chunk)) {
      final packet = parseDcnPacket(line);
      if (packet == null) {
        // `LABEL` is answered in bare console text with no envelope at all,
        // unlike everything else the module says — so a reader that only
        // parses packets silently loses every antenna name.
        if (parseCoaxLabel(line) case (final port, final text)?) {
          _labels[port] = text;
          if (_state != null) changed = true;
        }
        continue;
      }
      // Everything on the bus reaches every listener: other modules
      // answering the operator's own dashboard, and — on a two-wire RS-485
      // pair with no echo suppression — our own commands coming back at us.
      // Only what this module said is ours to read; without this a watt
      // meter's UPDATE two addresses away would be parsed as a port change.
      if (packet.isBroadcast || packet.from != address) continue;

      if (parseCoaxUpdate(packet) case final state?) {
        _state = state;
        changed = true;
      }
    }
    if (changed) _publish();
  }

  /// The routing picture, in the module's own numbering.
  ///
  /// The two wirings are genuinely different pictures, not one with swapped
  /// captions. As sold, the module is four antennas feeding one radio: four
  /// [SwitchAntenna]s and a single common [SwitchPort] pointed at whichever
  /// the relay has picked. Run backwards it is one antenna shared by four
  /// radios, so the four numbered ports become the device ports and the
  /// common port becomes the only antenna — and exactly one of those four
  /// ports holds it, the others holding nothing at all. That last part is
  /// what the Antenna Genius never has to express: its two sides both have
  /// several ports, so reversing it only renames them.
  ///
  /// **The Station panel does not yet know that, and the reversed layout is
  /// mislabelled there because of it** — it derives the wiring picker's two
  /// options from the reported counts, which only describe the hardware for
  /// a driver that leaves its sides alone. The picker therefore offers a
  /// reversed CX-1 the two options the wrong way round. HALO-427 is the fix:
  /// a driver supplies its own default inventory instead of the panel
  /// deriving one. Until then the as-sold layout is the sound one.
  void _publish() {
    final state = _state;
    if (state == null) return;
    final selected = state.selectedPort;

    _sink.reportDiagnostic('${state.moduleType} · DCN $address · ${state.mask}');

    if (reversed) {
      _sink.reportSwitchState(
        [SwitchAntenna(key: sierraCommonPortKey, name: t.settings.station.switchCommonPort)],
        [
          for (var port = 1; port <= cx1PortCount; port++)
            SwitchPort(
              key: '$port',
              label: '$port',
              selectedAntennaKey: port == selected ? sierraCommonPortKey : null,
            ),
        ],
      );
      return;
    }

    _sink.reportSwitchState(
      [
        for (var port = 1; port <= cx1PortCount; port++)
          SwitchAntenna(key: '$port', name: _portName(port)),
      ],
      [
        SwitchPort(
          key: sierraCommonPortKey,
          label: t.settings.station.switchCommonPort,
          selectedAntennaKey: selected == null ? null : '$selected',
        ),
      ],
    );
  }

  /// What the module calls a port, or nothing at all.
  ///
  /// Empty rather than "Port 4" when no label is set: the Station panel words
  /// these itself, so a driver that supplies its own wording renders as
  /// "Port Port 4" and "Antenna on port 4 - Port 4". Empty is also what the
  /// panel's own disconnected fallback uses, for the reason stated there —
  /// an invented name looks like something the switch reported.
  ///
  /// Every port is offered whether or not it is labelled. Unlike the Antenna
  /// Genius nothing here says which are wired up: a CX-1 has four relays
  /// whatever is screwed to them, and a label is a convenience somebody may
  /// simply never have typed in.
  String _portName(int port) => _labels[port] ?? '';

  @override
  void selectAntenna(String portKey, String antennaKey) {
    // One relay, addressed by whichever of the two keys is the numbered
    // side: as sold the operator picks an antenna, reversed they pick which
    // radio gets the one antenna there is.
    final port = int.tryParse(reversed ? portKey : antennaKey);
    if (port == null || port < 1 || port > cx1PortCount) return;

    // No guard against switching under RF, and that is a real gap rather
    // than an omission: the CX-1 has no PTT input, no RF sensing and no
    // interlock, so nothing here or on the module knows whether the coax is
    // hot. The Antenna Genius refuses a transmitting port because it tells
    // us it is transmitting; this one cannot. Sequencing is the operator's,
    // as it is with the module's own front-panel buttons.
    // No follow-up query: the module answers a select with the new state
    // about a second later, once the relay has settled. Asking as well would
    // put a second command on a half-duplex bus while that answer is still
    // coming back.
    _send(cx1SelectCommand(port));
    // The free-running poll is the same hazard. A tick landing inside that
    // second collides with the module's answer on the shared pair and it is
    // the ANSWER that is lost, so the panel would sit unmoved until the tick
    // after. Restarting the interval here puts a full period between the
    // select and the next thing we say.
    if (_wantUpdates) _armPoll();
  }

  @override
  String toString() => 'SierraCoaxSession(DCN $address, port ${_state?.selectedPort})';
}

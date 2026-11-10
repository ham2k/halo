// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The devices behind a Green Heron Everyware server, each its own node:
// a rotor turned through the rotator surface, a switch routed through the
// antenna switch surface (docs/design/cat.md § Green Heron Everyware).
//
// A device's connection is an EverywareDeviceConnection onto its server's
// hub, which feeds it only the lines about that device, the hub's memory of
// them first. So these sessions read plain protocol lines, and never see
// another device's.

import 'dart:async';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../driver.dart';
import '../equipment.dart';
import 'everyware_codec.dart';
import 'everyware_server.dart';

/// A switch node's opt-in: a band switch follows the radio's frequency, a map
/// switch points toward the station being worked. Off unless the operator
/// turns it on: the station is shared, and a switch moved by the app can
/// move another operator's antenna.
const everywareFollowConfigKey = 'everywareFollow';

/// Which radio a following band switch follows: [everywareFollowRadioB] for
/// SO2R's Radio B, anything else Radio A. A switch feeding the second radio
/// moved with the first would put that radio on the wrong band's antenna.
const everywareFollowRadioConfigKey = 'everywareFollowRadio';
const everywareFollowRadioA = 'a';
const everywareFollowRadioB = 'b';

/// How long a turn may show no movement before a still mast counts as
/// stopped. WU2X's rotors showed the first movement about 6 s after the
/// command; real time, since what it measures is the hardware's lag.
const everywareTurnStartWait = Duration(seconds: 10);

/// How long a selection this app sent stands in for the switch's own word.
/// The server repeats the old position every few seconds until the relay
/// moves, so the switch's word cannot be taken as an answer at once; one
/// the server refused must not stand for good either.
const everywareSelectionPending = Duration(seconds: 5);

/// How long a device may go unannounced once its node is up. The server
/// announces everything it has within a second or two of a connect; a device
/// it never names was renamed or removed on the server, and its node would
/// otherwise read connected while nothing ever comes.
const everywareAnnounceWait = Duration(seconds: 10);

String _deviceName(Map<String, dynamic> config) => config[everywareDeviceConfigKey] as String? ?? '';

/// Says the server no longer has the device when [everywareAnnounceWait]
/// passes without an announcement of it.
mixin _AwaitsAnnouncement {
  EquipmentSink get _sink;
  Timer? _announceTimer;
  bool _announced = false;

  void _awaitAnnouncement() {
    _announceTimer?.cancel();
    if (_announced) return;
    _announceTimer = Timer(everywareAnnounceWait, () {
      if (!_announced) _sink.reportProblem(t.settings.station.everywareDeviceGone);
    });
  }

  void _noteAnnounced() {
    _announced = true;
    _announceTimer?.cancel();
  }

  void _stopAwaiting() => _announceTimer?.cancel();
}

class EverywareRotorDriver extends EquipmentDriver {
  const EverywareRotorDriver();

  @override
  String get key => 'gh-everyware-rotor';

  @override
  String get name => 'GH Everyware rotor';

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => EverywareRotorSession(sink, _deviceName(config));
}

/// One rotor. The server pushes where it points, and already speaks true
/// headings — the controller behind it has its own calibration and end
/// stops — so this node carries no offsets and no limits, as PstRotator's
/// does not.
class EverywareRotorSession with _AwaitsAnnouncement implements RotatorSession {
  @override
  final EquipmentSink _sink;
  final String rotor;

  EverywareRotorSession(this._sink, this.rotor);

  final _splitter = EverywareLineSplitter();

  /// The last whole-degree heading reported.
  int? _last;

  /// Until when an unchanged heading is not news, after a turn. The server
  /// repeats every heading about once a second, and a turn shows no movement
  /// for some seconds while the command reaches the controller; reported,
  /// those repeats would be counted as a mast that stopped short
  /// (rotatorStalledAfterReadings) and end the turn before it began.
  int? _turnStartsBy;

  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void startUpdates() => _awaitAnnouncement();

  @override
  void stopUpdates() {}

  @override
  void teardown() => _stopAwaiting();

  @override
  void handleData(Uint8List chunk) {
    for (final line in _splitter.add(chunk)) {
      switch (parseEverywareLine(line)) {
        case EverywarePoint(:final name, :final heading, :final unreachable) when name == rotor:
          _noteAnnounced();
          // Every repeat is the server answering for this rotor, whatever it
          // says: the paths below that report no heading would otherwise let
          // a healthy node go "not responding" over its own problem.
          _sink.reportAlive();
          if (unreachable) {
            // Where it was when the server last reached it: not a heading to
            // draw a beam on, or to measure a turn's arrival against.
            _sink.reportProblem(t.settings.station.everywareRotorUnreachable);
            continue;
          }
          _sink.reportProblem(null);
          // Above 360 is a fixed antenna's "no heading", never a direction.
          if (heading < 0 || heading > 360) continue;
          // Whole degrees, as every rotator here reports: and the controller's
          // tenths flicker between two readings a step apart when it is at
          // rest, which a whole degree mostly absorbs.
          final azimuth = heading.round() % 360;
          if (azimuth == _last && _turnStartsBy != null && realNowMillis() < _turnStartsBy!) continue;
          // Moving, or past the wait: from here a mast standing still has
          // stopped.
          if (azimuth != _last) _turnStartsBy = null;
          _last = azimuth;
          if (_sink case final RotatorSink sink) sink.reportRotator(RotatorPosition(azimuth: azimuth));
        case EverywareRotorRemoved(:final name) when name == rotor:
          _sink.reportProblem(t.settings.station.everywareDeviceGone);
        case EverywareRotorAdded(:final name) when name == rotor:
          _noteAnnounced();
          _sink.reportProblem(null);
        default:
          break;
      }
    }
  }

  @override
  RotatorPosition rotateTo({required num azimuth, num? elevation}) {
    final heading = azimuth.round() % 360;
    // A turn to where it already points has nothing to wait for: held, it
    // would read "turning" for the whole wait.
    _turnStartsBy = heading == _last ? null : realNowMillis() + everywareTurnStartWait.inMilliseconds;
    _sink.send(everywareTurn(rotor, heading));
    return RotatorPosition(azimuth: heading);
  }

  @override
  void stopRotation() => _sink.send(everywareStop(rotor));

  @override
  String toString() => 'EverywareRotorSession($rotor)';
}

/// A directional switch — a 4-square, a crossfire array — as a rotator:
/// what it does is point an antenna, so it is driven and drawn like one.
class EverywareDirectionalDriver extends EquipmentDriver {
  const EverywareDirectionalDriver();

  @override
  String get key => 'gh-everyware-directional';

  @override
  String get name => 'GH Everyware directional switch';

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      EverywareDirectionalSession(sink, _deviceName(config), follow: config[everywareFollowConfigKey] == true);
}

/// A map switch's directions as a rotator's headings. Its heading is the
/// selected direction's; a turn picks the open direction nearest the heading
/// asked for ([everywareMapPosition]) and is answered with that direction's
/// heading, so the turn arrives the moment the switch reports it. There is
/// no motion to stop.
class EverywareDirectionalSession with _AwaitsAnnouncement, _SelectsPosition implements RotatorSession, BearingFollower {
  @override
  final EquipmentSink _sink;
  @override
  final String switchName;

  /// Whether this node points toward the station worked by itself.
  final bool follow;

  EverywareDirectionalSession(this._sink, this.switchName, {this.follow = false});

  final _splitter = EverywareLineSplitter();

  /// The heading last asked for. A bidirectional direction fires both ways,
  /// and is drawn along the lobe nearer this: picked for its back, and drawn
  /// along its front, it would read as pointing away from the station it was
  /// turned toward.
  int? _aim;

  int _headingOf(EverywarePosition position) {
    final front = position.heading % 360;
    final aim = _aim;
    if (!position.bidirectional || aim == null) return front;
    final back = (front + 180) % 360;
    return rotatorHeadingGap(back, aim) < rotatorHeadingGap(front, aim) ? back : front;
  }

  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void startUpdates() => _awaitAnnouncement();

  @override
  void stopUpdates() {}

  @override
  void teardown() => _stopAwaiting();

  @override
  void handleData(Uint8List chunk) {
    for (final line in _splitter.add(chunk)) {
      if (_handleSwitchLine(parseEverywareLine(line))) _report();
    }
  }

  /// Every report the server repeats is a reading, as a rotator's repeated
  /// heading is: that is what keeps the node's silence watch fed — and with
  /// no direction to report, it is still the server answering.
  void _report() {
    final position = _position(_selected);
    if (position == null) return _sink.reportAlive();
    // Each direction says its own beam, which the rotator panel draws in
    // place of its setting; zero is a direction that did not say.
    final beamWidth = position.beamwidth > 0 ? position.beamwidth : null;
    if (_sink case final RotatorSink sink) sink.reportRotator(RotatorPosition(azimuth: _headingOf(position), beamWidth: beamWidth));
  }

  @override
  RotatorPosition rotateTo({required num azimuth, num? elevation}) {
    _aim = azimuth.round() % 360;
    final name = everywareMapPosition(_positions, bearing: _aim!, locked: _locked);
    final position = _position(name);
    if (position == null) {
      // Nothing to point: every direction locked out, or none announced
      // (which the node already says). Where it points now is all a turn
      // can arrive at — answered with the heading asked for, the turn would
      // be drawn on its way somewhere it never goes.
      if (_positions.isNotEmpty) _refuse(t.settings.station.everywareNoDirectionOpen);
      final current = _position(_current);
      return RotatorPosition(azimuth: current == null ? _aim! : _headingOf(current));
    }
    _clearRefusal();
    if (position.name != _current) _send(position.name);
    return RotatorPosition(azimuth: _headingOf(position));
  }

  @override
  void stopRotation() {}

  @override
  void followBearing(int bearing) {
    if (!follow) return;
    _aim = bearing;
    final name = everywareMapPosition(_positions, bearing: bearing, locked: _locked);
    if (name != null && name != _current) _send(name);
  }

  @override
  String toString() => 'EverywareDirectionalSession($switchName, $_selected)';
}

class EverywareSwitchDriver extends EquipmentDriver {
  const EverywareSwitchDriver();

  @override
  String get key => 'gh-everyware-switch';

  @override
  String get name => 'GH Everyware switch';

  @override
  int get devicePortCount => 1;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => EverywareSwitchSession(
    sink,
    _deviceName(config),
    follow: config[everywareFollowConfigKey] == true,
    followsRadioB: config[everywareFollowRadioConfigKey] == everywareFollowRadioB,
  );
}

/// The one port an Everyware switch is shown as: the switch itself, its
/// positions the antennas it can route to. The server names a switch, not
/// its ports, so the key is fixed and the label is the switch's name.
const everywareSwitchPortKey = '1';

/// A switch session that can follow the radio's frequency.
abstract interface class FrequencyFollower {
  /// Radio A — or SO2R's Radio B, with [radioB] — is on [freqKHz]; a session
  /// that follows that radio moves to the position covering it.
  void followFrequency(double freqKHz, {bool radioB = false});
}

/// A switch session that can point toward a station.
abstract interface class BearingFollower {
  /// The station being worked is [bearing] true degrees away; a session that
  /// follows picks the direction nearest it.
  void followBearing(int bearing);
}

/// What both switch sessions keep about choosing a position: what the
/// server announced, which one is selected and which are locked out, a
/// selection sent and not yet confirmed, and a refusal of their own.
mixin _SelectsPosition on _AwaitsAnnouncement {
  String get switchName;

  List<EverywarePosition> _positions = const [];
  EverywareSwitchKind? _kind;
  String? _selected;
  Set<String> _locked = const {};

  /// The last position this session sent, standing in for the switch's own
  /// word until the switch reports it or [everywareSelectionPending] passes:
  /// a band or bearing change arriving meanwhile must not send it again, and
  /// one the server refused must not stand for good.
  String? _pending;
  int _pendingUntil = 0;

  /// Whether the problem standing is this session's own refusal, which the
  /// next selection that goes through clears — and nothing else's.
  bool _refused = false;

  void _refuse(String message) {
    _refused = true;
    _sink.reportProblem(message);
  }

  void _clearRefusal() {
    if (!_refused) return;
    _refused = false;
    _sink.reportProblem(null);
  }

  void _send(String position) {
    _pending = position;
    _pendingUntil = realNowMillis() + everywareSelectionPending.inMilliseconds;
    _sink.send(everywareSetSwitch(switchName, position));
  }

  String? get _current => (_pending != null && realNowMillis() < _pendingUntil ? _pending : null) ?? _selected;

  EverywarePosition? _position(String? name) => _positions.where((position) => position.name == name).firstOrNull;

  /// Takes in [message] when it is about this switch; true when it was, for
  /// the session to report what the switch now says.
  bool _handleSwitchLine(EverywareMessage message) {
    switch (message) {
      case EverywareSwitchAdded(:final name, :final positions, :final kind) when name == switchName:
        _noteAnnounced();
        _positions = positions;
        _kind = kind ?? EverywareSwitchKind.buttons;
        _sink.reportProblem(null);
      case EverywareSwitchUpdate(:final name, :final position) when name == switchName:
        _selected = position == 'UNKNOWN' ? null : position;
        if (_selected == _pending) _pending = null;
      case EverywareSwitchLocks(:final name, :final locked) when name == switchName:
        _locked = locked;
      case EverywareSwitchRemoved(:final name) when name == switchName:
        _positions = const [];
        _selected = null;
        _sink.reportProblem(t.settings.station.everywareDeviceGone);
      default:
        return false;
    }
    return true;
  }
}

/// One switch. Buttons, a map and a band switch are all one selection out of
/// a list, which is what the antenna switch surface shows.
class EverywareSwitchSession with _AwaitsAnnouncement, _SelectsPosition implements AntennaSwitchSession, FrequencyFollower, BearingFollower {
  @override
  final EquipmentSink _sink;
  @override
  final String switchName;

  /// Whether this node follows the radio or the station worked — whichever
  /// its kind of switch can.
  final bool follow;

  /// Whether it follows SO2R's Radio B rather than Radio A.
  final bool followsRadioB;

  EverywareSwitchSession(this._sink, this.switchName, {this.follow = false, this.followsRadioB = false});

  final _splitter = EverywareLineSplitter();

  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void startUpdates() => _awaitAnnouncement();

  @override
  void stopUpdates() {}

  @override
  void teardown() => _stopAwaiting();

  @override
  void handleData(Uint8List chunk) {
    for (final line in _splitter.add(chunk)) {
      if (_handleSwitchLine(parseEverywareLine(line))) _report();
    }
  }

  /// A locked position is shown unconfigured, which keeps it out of the
  /// picker: another switch's selection holds it, and picking it would only
  /// be refused.
  void _report() => _sink.reportSwitchState(
    [for (final position in _positions) SwitchAntenna(key: position.name, name: position.name, configured: !_locked.contains(position.name))],
    [if (_positions.isNotEmpty) SwitchPort(key: everywareSwitchPortKey, label: switchName, selectedAntennaKey: _selected)],
  );

  @override
  void selectAntenna(String portKey, String antennaKey) {
    if (portKey != everywareSwitchPortKey || !_positions.any((position) => position.name == antennaKey)) return;
    if (_locked.contains(antennaKey)) return _refuse(t.settings.station.everywarePositionLocked(position: antennaKey));
    _clearRefusal();
    _send(antennaKey);
  }

  @override
  void followFrequency(double freqKHz, {bool radioB = false}) {
    if (!follow || _kind != EverywareSwitchKind.band || radioB != followsRadioB) return;
    final position = everywareBandPosition(_positions, current: _current, freqMHz: freqKHz / 1000, locked: _locked);
    if (position != null && position != _current) _send(position);
  }

  @override
  void followBearing(int bearing) {
    if (!follow || _kind != EverywareSwitchKind.map) return;
    final position = everywareMapPosition(_positions, bearing: bearing, locked: _locked);
    if (position != null && position != _current) _send(position);
  }

  @override
  String toString() => 'EverywareSwitchSession($switchName, ${_kind?.name}, $_selected)';
}

/// The band switch position for [freqMHz], or null to leave it where it is —
/// the Everyware client's own rule, so an operator moving between the two
/// sees one behaviour:
///
/// - the current position stays while its range still covers the frequency,
///   so two overlapping ranges do not trade places at every step of the dial;
/// - a current position called OFF, or with DUMMY in its name, stays put
///   whatever the frequency: the operator parked the switch on purpose;
/// - otherwise the first position, in the server's order, covering it —
///   skipping one another switch has locked out, though never an OFF;
/// - and none covering it leaves the switch alone.
String? everywareBandPosition(List<EverywarePosition> positions, {required String? current, required double freqMHz, Set<String> locked = const {}}) {
  if (current != null) {
    if (_parksTheSwitch(current)) return null;
    if (positions.where((position) => position.name == current).firstOrNull?.covers(freqMHz) ?? false) return null;
  }
  for (final position in positions) {
    if (!position.covers(freqMHz)) continue;
    if (locked.contains(position.name) && position.name.toLowerCase() != 'off') continue;
    return position.name == current ? null : position.name;
  }
  return null;
}

bool _parksTheSwitch(String name) {
  final lower = name.toLowerCase();
  return lower.contains('dummy') || lower.split(RegExp(r'[^a-z0-9]+')).contains('off');
}

/// The map switch direction nearest [bearing], or null when none is open.
/// A bidirectional position covers its back too: an array fired both ways is
/// as good toward a station behind it.
String? everywareMapPosition(List<EverywarePosition> positions, {required int bearing, Set<String> locked = const {}}) {
  String? best;
  var bestGap = 361;
  for (final position in positions) {
    if (locked.contains(position.name)) continue;
    var gap = rotatorHeadingGap(position.heading, bearing);
    if (position.bidirectional) gap = min(gap, rotatorHeadingGap(position.heading + 180, bearing));
    if (gap < bestGap) {
      bestGap = gap;
      best = position.name;
    }
  }
  return best;
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Hamlib's `rotctld`, over TCP to a daemon the operator runs: whatever
// rotator Hamlib has a backend for, through one protocol. The wire format
// is rotctld_codec.dart's.
//
// Hamlib passes the controller's own degrees through, so a node here takes
// the offsets rotator_config.dart offers — but not its limits: the daemon
// enforces its own, and says which in `\dump_state` when connected. Until
// it does, or if it never answers that (a daemon that is not Hamlib may
// not), the limits are a full turn and horizon to zenith.
//
// The session POLLS: rotctld answers questions and volunteers nothing.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';
import '../driver.dart';
import '../equipment.dart';
import 'line_framer.dart';
import 'poll_config.dart';
import 'rotator_config.dart';
import 'rotctld_codec.dart';

/// How often to ask, when the node does not say — gs232PollInterval's
/// reasoning.
const rotctldPollInterval = Duration(seconds: 1);

/// How long the `\dump_state` answer is waited for before polling starts
/// without it. Hamlib answers it from memory, at once; a daemon that does
/// not know it never does.
const rotctldStateWait = Duration(seconds: 2);

class RotctldDriver extends EquipmentDriver {
  const RotctldDriver();

  /// rotctld's own default.
  static const defaultPort = 4533;

  @override
  String get key => 'rotctld';

  @override
  String get name => 'Hamlib rotctld';

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) {
    final st = t.settings.station;
    return [
      if (!overrides.containsKey(rotatorAxesConfigKey)) rotatorAxesConfigElement(),
      ...rotatorConfigElements(limits: false),
      {
        ...pollConfigElement(fallback: rotctldPollInterval),
        'label': st.rotatorPollInterval,
        'description': st.rotatorPollIntervalDescription(fallback: rotctldPollInterval.inMilliseconds),
      },
    ];
  }

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key == pollIntervalConfigKey) return validatePollInterval(value);
    if (key == rotatorAxesConfigKey) return validateRotatorAxes(value);
    return validateRotatorField(key, value, config);
  }

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    // The node's offsets; its limits, if any were stored, are not used.
    final stored = RotatorCalibration.from(config);
    return RotctldSession(
      sink,
      elevation: rotatorHasElevation(config),
      calibration: RotatorCalibration(azimuthOffset: stored.azimuthOffset, elevationOffset: stored.elevationOffset),
      pollInterval: idlePollIntervalFor(config, fallback: rotctldPollInterval),
    );
  }
}

/// What an answer can belong to.
enum _Asked { state, position, command }

class RotctldSession implements RotatorSession {
  final EquipmentSink _sink;

  /// Asks for, reports and sends an elevation. Off, the elevation rotctld
  /// reports — an az-only backend's included — is dropped.
  final bool elevation;

  final Duration pollInterval;

  /// The offsets, inside the daemon's limits once `\dump_state` names them.
  RotatorCalibration calibration;

  RotctldSession(this._sink, {this.elevation = false, this.calibration = const RotatorCalibration(), this.pollInterval = rotctldPollInterval});

  final _framer = LineFramer();
  bool _wantUpdates = false;
  Timer? _pollTimer;
  Timer? _stateTimer;

  /// Everything sent and not yet answered, in the order sent — the order
  /// rotctld answers in, so each answer belongs to the oldest of its kind.
  final _asked = ListQueue<_Asked>();

  /// The azimuth half of a `p` answer, waiting for its elevation.
  double? _azimuth;

  /// The controller's own last reading: the degrees a turn is chosen in,
  /// and the elevation an azimuth-only turn keeps.
  RotatorPosition? _last;

  /// The controller elevation last sent, kept by an azimuth-only turn
  /// before any reading has said where the elevation is.
  int? _sentElevation;

  /// The `\dump_state` answer read so far: its protocol version once its
  /// first line has said, and how many lines have followed.
  int? _stateVersion;
  int _stateLines = 0;
  final _limits = <(bool, bool), int>{};

  /// What this session last told the operator was wrong, and whether a
  /// position answering again clears it — it does for a failed read or an
  /// answer it could not read, not for a refused turn, which only the next
  /// command answered does.
  String? _problem;
  bool _positionClears = false;

  void _send(String text) => _sink.send(utf8.encode(text));

  void _ask(_Asked kind, String text) {
    _asked.add(kind);
    _send(text);
  }

  @override
  void startUpdates() {
    _wantUpdates = true;
    _ask(_Asked.state, rotctldStateQuery);
    _stateTimer?.cancel();
    _stateTimer = Timer(rotctldStateWait, () {
      if (_asked.contains(_Asked.state)) _stateDone(answered: false);
    });
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => _poll());
  }

  /// Not while `\dump_state` is outstanding, whose bare numbers a `p`
  /// answer would be confused with; and not while a `p` is, which a slow
  /// backend would otherwise stack up in front of every turn.
  void _poll() {
    if (!_wantUpdates || _asked.contains(_Asked.state) || _asked.contains(_Asked.position)) return;
    _ask(_Asked.position, rotctldPositionQuery);
  }

  @override
  void stopUpdates() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _stateTimer?.cancel();
    _stateTimer = null;
    _wantUpdates = false;
  }

  @override
  void teardown() {
    stopUpdates();
    _framer.reset();
    _asked.clear();
    _azimuth = null;
    _last = null;
    _problem = null;
  }

  @override
  Duration? get expectedUpdateInterval => pollInterval;

  @override
  void handleData(Uint8List chunk) {
    for (final line in _framer.add(chunk)) {
      if (line.trim().isEmpty) continue;
      if (_asked.firstOrNull == _Asked.state && _takeStateLine(line)) {
        _sink.reportAlive();
        continue;
      }
      if (parseRotctldReport(line) case final code?) {
        _sink.reportAlive();
        _azimuth = null;
        _onReport(code);
        continue;
      }
      final number = parseRotctldNumber(line);
      if (number == null) {
        // Answering, and not as rotctld: kept alive by it, the node would
        // read as connected with no heading and no reason.
        _azimuth = null;
        _setProblem(t.settings.station.rotctldUnreadable, positionClears: true);
        continue;
      }
      _sink.reportAlive();
      final azimuth = _azimuth;
      if (azimuth == null) {
        _azimuth = number;
        continue;
      }
      _azimuth = null;
      _onPosition(RotatorPosition(azimuth: azimuth.round(), elevation: number.round()));
    }
  }

  /// Takes [line] as part of the `\dump_state` answer, if it is one. A
  /// line that is not ends the answer and is the next one's.
  bool _takeStateLine(String line) {
    final version = _stateVersion;
    if (version == null) {
      // A daemon that does not know the command answers nothing, so this
      // is the next command's answer.
      if (parseRotctldStateVersion(line) case final first?) {
        _stateVersion = first;
        return true;
      }
      _stateDone(answered: false);
      return false;
    }
    _stateLines++;
    if (_stateLines == 1) return true; // the rotator model
    if (version == 0) {
      final number = parseRotctldNumber(line);
      if (number == null) {
        _stateDone(answered: true);
        return false;
      }
      final which = rotctldStateV0Limits[_stateLines - 2];
      _limits[(which.max, which.elevation)] = number.round();
      if (_stateLines - 1 == rotctldStateV0Limits.length) _stateDone(answered: true);
      return true;
    }
    if (line.trim() == rotctldStateEnd) {
      _stateDone(answered: true);
      return true;
    }
    if (parseRotctldStateLimit(line) case final limit?) {
      _limits[(limit.max, limit.elevation)] = limit.degrees;
      return true;
    }
    if (isRotctldStateField(line)) return true;
    _stateDone(answered: true);
    return false;
  }

  void _stateDone({required bool answered}) {
    _asked.remove(_Asked.state);
    _stateTimer?.cancel();
    _stateTimer = null;
    _applyLimits(answered: answered);
    _poll();
  }

  /// A range that is not one — min at or past max — keeps the full turn or
  /// horizon to zenith: placed inside it, every turn would go to one end.
  void _applyLimits({required bool answered}) {
    const fallback = RotatorCalibration();
    var (azimuthMin, azimuthMax) = (_limits[(false, false)] ?? fallback.azimuthMin, _limits[(true, false)] ?? fallback.azimuthMax);
    if (azimuthMin >= azimuthMax) (azimuthMin, azimuthMax) = (fallback.azimuthMin, fallback.azimuthMax);
    var (elevationMin, elevationMax) = (_limits[(false, true)] ?? fallback.elevationMin, _limits[(true, true)] ?? fallback.elevationMax);
    if (elevationMin >= elevationMax) (elevationMin, elevationMax) = (fallback.elevationMin, fallback.elevationMax);
    calibration = calibration.withLimits(azimuthMin: azimuthMin, azimuthMax: azimuthMax, elevationMin: elevationMin, elevationMax: elevationMax);
    final source = answered ? 'from \\dump_state' : 'no \\dump_state answer';
    _sink.reportDiagnostic('limits $source: azimuth $azimuthMin..$azimuthMax, elevation $elevationMin..$elevationMax');
  }

  void _onReport(int code) {
    final asked = _asked.isEmpty ? null : _asked.removeFirst();
    if (asked == _Asked.command) {
      _setProblem(code == 0 ? null : _explain(code, read: false));
    } else if (code != 0) {
      _setProblem(_explain(code, read: true), positionClears: true);
    }
  }

  String _explain(int code, {required bool read}) {
    final st = t.settings.station;
    if (code == rotctldTimedOut) return st.rotctldTimedOut(code: code);
    if (code == rotctldLimitExceeded && !read) return st.rotctldPastLimits(code: code);
    return read ? st.rotctldReadFailed(code: code) : st.rotctldRefused(code: code);
  }

  void _onPosition(RotatorPosition position) {
    // Answered in order, so whatever was asked ahead of this `p` was never
    // answered — a `S` a Gpredict-mode server does not know.
    if (_asked.contains(_Asked.position)) {
      while (_asked.removeFirst() != _Asked.position) {}
    }
    if (_positionClears) _setProblem(null);
    _last = position;
    final reported = elevation ? position : RotatorPosition(azimuth: position.azimuth);
    if (_sink case final RotatorSink rotator) rotator.reportRotator(calibration.toTrue(reported));
  }

  void _setProblem(String? problem, {bool positionClears = false}) {
    _positionClears = problem != null && positionClears;
    if (problem == _problem) return;
    _problem = problem;
    _sink.reportProblem(problem);
  }

  @override
  RotatorPosition rotateTo({required num azimuth, num? elevation}) {
    final controllerAzimuth = calibration.controllerAzimuth(azimuth, from: _last?.azimuth);
    final turnsElevation = this.elevation && elevation != null;
    // `P` takes both, always. An azimuth-only turn — every turn, on an
    // az-only node — keeps the elevation the rotator is at: an az/el
    // rotator on a node left at its az-only default would otherwise drop
    // to the horizon on every turn.
    final controllerElevation = turnsElevation ? calibration.controllerElevation(elevation) : (_last?.elevation ?? _sentElevation ?? 0);
    _sentElevation = controllerElevation;
    _ask(_Asked.command, rotctldTurnCommand(controllerAzimuth, controllerElevation));
    return calibration.toTrue(RotatorPosition(azimuth: controllerAzimuth, elevation: turnsElevation ? controllerElevation : null));
  }

  @override
  void stopRotation() => _ask(_Asked.command, rotctldStopCommand);

  @override
  String toString() => 'RotctldSession(${elevation ? 'az/el' : 'az'}, $_last)';
}

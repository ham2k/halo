// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A rotator that is only ever as far away as this object: it turns toward
// wherever it is sent at a steady rate, the shorter way round, and reports
// its heading as it goes. Paired with placeholder_transport.dart, for
// placeholder_radio_driver.dart's reason: it puts nothing on a wire, so what
// it exercises is everything above a rotator driver — the rotator map, the
// Station panel's readout, a turn and a stop — on a build with no rotator,
// the web included. It proves nothing about any real controller.
//
// It PUSHES, as a real controller polled fast enough would look: a reading
// each step while it turns, and its heading restated now and then while it
// stands, so the silence watch never takes it for gone.

import 'dart:async';
import 'dart:typed_data';

import '../driver.dart';
import '../equipment.dart';

/// How fast it turns: a fast real rotator's sweep, so a half turn takes half
/// a minute, long enough to watch a turn happen and short enough to wait for.
const simulatedRotatorDegreesPerSecond = 6.0;

/// How often a turn reports, while it turns.
const simulatedRotatorStep = Duration(milliseconds: 250);

/// How often a rotator standing still restates its heading: well inside
/// `catStaleAfter`, which would otherwise call a rotator nobody is turning
/// one that stopped answering.
const _restateEvery = Duration(seconds: 10);

class SimulatedRotatorDriver extends EquipmentDriver {
  const SimulatedRotatorDriver();

  @override
  String get key => 'simulated-rotator';

  @override
  String get name => 'Simulated Rotator';

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => const [];

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => SimulatedRotatorSession(sink);
}

class SimulatedRotatorSession implements RotatorSession {
  final EquipmentSink _sink;

  SimulatedRotatorSession(this._sink);

  /// Where it points, in degrees from north; every session starts at north.
  double _azimuth = 0;

  double? _target;
  Timer? _turning;
  Timer? _restate;

  void _report() {
    if (_sink case final RotatorSink rotator) rotator.reportRotator(RotatorPosition(azimuth: _azimuth.round() % 360));
  }

  @override
  void handleData(Uint8List chunk) {}

  @override
  void startUpdates() {
    _report();
    _restate?.cancel();
    _restate = Timer.periodic(_restateEvery, (_) => _report());
  }

  @override
  void stopUpdates() {
    _restate?.cancel();
    _restate = null;
  }

  @override
  void teardown() {
    stopUpdates();
    _turning?.cancel();
    _turning = null;
    _target = null;
  }

  @override
  Duration? get expectedUpdateInterval => null;

  @override
  RotatorPosition rotateTo({required num azimuth, num? elevation}) {
    final target = (azimuth.toDouble() % 360 + 360) % 360;
    _target = target;
    _turning ??= Timer.periodic(simulatedRotatorStep, (_) => _step());
    return RotatorPosition(azimuth: target.round() % 360);
  }

  void _step() {
    final target = _target;
    if (target == null) return _stop();
    final gap = (target - _azimuth + 540) % 360 - 180;
    final step = simulatedRotatorDegreesPerSecond * simulatedRotatorStep.inMilliseconds / 1000;
    if (gap.abs() <= step) {
      _azimuth = target;
      _report();
      return _stop();
    }
    _azimuth = (_azimuth + gap.sign * step + 360) % 360;
    _report();
  }

  void _stop() {
    _turning?.cancel();
    _turning = null;
    _target = null;
  }

  @override
  void stopRotation() {
    _stop();
    _report();
  }

  @override
  String toString() => 'SimulatedRotatorSession(${_azimuth.round()}°${_target == null ? '' : ' → ${_target!.round()}°'})';
}

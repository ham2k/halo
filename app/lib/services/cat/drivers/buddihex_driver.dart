// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The BuddiHex mast rotator: a WiFi controller on the MastWerks mast of
// Buddipole's BuddiHex antenna, a compass on the mast and a motor on its
// crank. The wire format is buddihex_codec.dart's.
//
// Its heading is the compass's, corrected by the controller's own
// declination calibration ("Calibrate North" on its web page), which it
// holds only until it is powered off. A node here carries no offsets and no
// limits, as PstRotator's does not: a correction set here as well would
// apply twice once the controller is calibrated, and the controller picks
// its own way round the mast's cable.
//
// The session POLLS: the controller answers queries and volunteers nothing.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';
import '../driver.dart';
import '../equipment.dart';
import 'buddihex_codec.dart';
import 'poll_config.dart';

/// How often to ask, when the node does not say. Slower than the GS-232's
/// second: each answer holds the controller's loop for a quarter of a
/// second while it reads the compass, time its own check for arriving at a
/// target waits behind.
const buddihexPollInterval = Duration(seconds: 2);

class BuddihexDriver extends EquipmentDriver {
  const BuddihexDriver();

  @override
  String get key => 'buddihex';

  @override
  String get name => 'BuddiHex';

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) {
    final st = t.settings.station;
    return [
      {
        ...pollConfigElement(fallback: buddihexPollInterval),
        'label': st.rotatorPollInterval,
        'description': st.rotatorPollIntervalDescription(fallback: buddihexPollInterval.inMilliseconds),
      },
    ];
  }

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => key == pollIntervalConfigKey ? validatePollInterval(value) : null;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      BuddihexSession(sink, pollInterval: idlePollIntervalFor(config, fallback: buddihexPollInterval));
}

class BuddihexSession implements RotatorSession {
  final EquipmentSink _sink;
  final Duration pollInterval;

  BuddihexSession(this._sink, {this.pollInterval = buddihexPollInterval});

  bool _wantUpdates = false;
  Timer? _pollTimer;

  /// The last answer was a compass fault, and the controller drops turns.
  bool _faulted = false;

  void _send(String message) => _sink.send(ascii.encode(message));

  @override
  void startUpdates() {
    _wantUpdates = true;
    _send(buddihexBearingQuery);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (_wantUpdates) _send(buddihexBearingQuery);
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
    _faulted = false;
  }

  @override
  Duration? get expectedUpdateInterval => pollInterval;

  /// One datagram is one answer, with no line ending of its own.
  @override
  void handleData(Uint8List chunk) {
    for (final line in ascii.decode(chunk, allowInvalid: true).split(RegExp(r'[\r\n]+'))) {
      if (line.trim().isEmpty) continue;
      _sink.reportAlive();
      final st = t.settings.station;
      switch (parseBuddihexReading(line)) {
        case null:
          continue;
        case BuddihexFaulted(:final fault):
          // No heading to give: the compass is what gives it.
          _faulted = true;
          _sink.reportProblem(switch (fault) {
            BuddihexFault.compassMissing => st.buddihexCompassMissing,
            BuddihexFault.compassNotReady => st.buddihexCompassNotReady,
            BuddihexFault.calibrationFailed => st.buddihexCompassCalibration,
            BuddihexFault.other => st.buddihexFault,
          });
        case BuddihexBearing(:final azimuth, :final stuck):
          _faulted = false;
          if (_sink case final RotatorSink rotator) rotator.reportRotator(RotatorPosition(azimuth: azimuth));
          _sink.reportProblem(stuck ? st.buddihexStuck : null);
      }
    }
  }

  @override
  RotatorPosition? rotateTo({required num azimuth, num? elevation}) {
    if (_faulted) return null;
    _send(buddihexTurnCommand(azimuth));
    return RotatorPosition(azimuth: azimuth.round() % 360);
  }

  @override
  void stopRotation() => _send(pstStopCommand);

  @override
  String toString() => 'BuddihexSession(${_faulted ? 'faulted' : 'ready'})';
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PstRotator, YO3DMU's rotator control program, driven over its UDP Control
// port from anywhere on the network. The wire format is
// pstrotator_codec.dart's.
//
// PstRotator stands between this and the controller, and it already does
// what rotator_config.dart's offsets and limits do — its own calibration,
// its own end stops — so a node here carries neither: the same correction
// in both places applies twice. What it reports is a true heading, and what
// it is told is one.
//
// The session POLLS, as the GS-232's does: PstRotator answers queries and
// volunteers nothing.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';
import '../driver.dart';
import '../equipment.dart';
import 'poll_config.dart';
import 'pstrotator_codec.dart';
import 'rotator_config.dart';

/// How often to ask, when the node does not say — gs232PollInterval's
/// reasoning, over a LAN instead of a serial line.
const pstRotatorPollInterval = Duration(seconds: 1);

class PstRotatorDriver extends EquipmentDriver {
  const PstRotatorDriver();

  @override
  String get key => 'pstrotator';

  @override
  String get name => 'PstRotator';

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) {
    final st = t.settings.station;
    return [
      if (!overrides.containsKey(rotatorAxesConfigKey)) rotatorAxesConfigElement(),
      {
        ...pollConfigElement(fallback: pstRotatorPollInterval),
        'label': st.rotatorPollInterval,
        'description': st.rotatorPollIntervalDescription(fallback: pstRotatorPollInterval.inMilliseconds),
      },
    ];
  }

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key == pollIntervalConfigKey) return validatePollInterval(value);
    if (key == rotatorAxesConfigKey) return validateRotatorAxes(value);
    return null;
  }

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => PstRotatorSession(
    sink,
    elevation: rotatorHasElevation(config),
    pollInterval: idlePollIntervalFor(config, fallback: pstRotatorPollInterval),
  );
}

class PstRotatorSession implements RotatorSession {
  final EquipmentSink _sink;

  /// Asks for, reports and sends an elevation.
  final bool elevation;

  final Duration pollInterval;

  PstRotatorSession(this._sink, {this.elevation = false, this.pollInterval = pstRotatorPollInterval});

  bool _wantUpdates = false;
  Timer? _pollTimer;

  /// The last azimuth answered, held for the elevation that completes it.
  int? _azimuth;

  void _send(String message) => _sink.send(ascii.encode(message));

  void _poll() {
    _send(pstAzimuthQuery);
    if (elevation) _send(pstElevationQuery);
  }

  @override
  void startUpdates() {
    _wantUpdates = true;
    _poll();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (_wantUpdates) _poll();
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
    _azimuth = null;
  }

  @override
  Duration? get expectedUpdateInterval => pollInterval;

  /// One datagram is one or more whole answers, each ended by a CR — so a
  /// datagram's end is a line's end too, and nothing carries over to the
  /// next.
  @override
  void handleData(Uint8List chunk) {
    for (final line in ascii.decode(chunk, allowInvalid: true).split(RegExp(r'[\r\n]+'))) {
      if (line.trim().isEmpty) continue;
      // Every answer is PstRotator there — an azimuth an az/el node is still
      // waiting to complete included, or one that never gets its elevation
      // reads "not responding" while it answers every poll.
      _sink.reportAlive();
      final reading = parsePstReading(line);
      if (reading == null) continue;
      // One report per poll, on the answer that completes it: the azimuth
      // on an az-only node, the elevation after it on an az/el one. Two a
      // poll would count a mast standing still twice as fast
      // (rotatorStalledAfterReadings).
      if (!reading.elevation) {
        _azimuth = reading.degrees;
        if (!elevation) _report(RotatorPosition(azimuth: reading.degrees));
      } else if (elevation && _azimuth != null) {
        _report(RotatorPosition(azimuth: _azimuth!, elevation: reading.degrees));
      }
    }
  }

  void _report(RotatorPosition position) {
    if (_sink case final RotatorSink rotator) rotator.reportRotator(position);
  }

  @override
  RotatorPosition rotateTo({required num azimuth, num? elevation}) {
    final withElevation = this.elevation && elevation != null;
    _send(pstTurnCommand(azimuth, elevation: withElevation ? elevation : null));
    return RotatorPosition(azimuth: azimuth.round().clamp(0, 360), elevation: withElevation ? elevation.round() : null);
  }

  @override
  void stopRotation() => _send(pstStopCommand);

  @override
  String toString() => 'PstRotatorSession(${elevation ? 'az/el' : 'az'}, $_azimuth)';
}

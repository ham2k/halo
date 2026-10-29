// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Yaesu GS-232A — the computer control interface for Yaesu's rotators, and
// the first rotator in this layer. The wire format is gs232_codec.dart's.
//
// Its protocol is also the one most third-party rotator controllers speak
// (K3NG, ERC, and the serial side of PstRotator), so this driver is what an
// operator with any of those picks too.
//
// The session POLLS, and has to: the controller never speaks unasked, and a
// turn made from its own front panel is reported by nothing but the next
// position query.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';
import '../driver.dart';
import '../equipment.dart';
import 'gs232_codec.dart';
import 'line_framer.dart';
import 'poll_config.dart';
import 'rotator_config.dart';

export 'rotator_config.dart' show rotatorAxesConfigKey, rotatorAxesAzimuth, rotatorAxesAzimuthElevation, rotatorHasElevation;

/// How often to ask where the antenna points, when the node does not say
/// ([pollIntervalConfigKey]).
///
/// A poll, not a backstop, for the reason the file header gives — and the
/// one place the heading is ever read, so this is how fast the editor's
/// readout follows a turn. A rotator sweeps roughly a degree a second at its
/// slowest and six at its fastest, so a second keeps the readout within a
/// few degrees of the mast while a question and answer of under a dozen
/// bytes stays a sliver of even a 1200-baud link.
const gs232PollInterval = Duration(seconds: 1);

class Gs232Driver extends EquipmentDriver {
  const Gs232Driver();

  @override
  String get key => 'gs232';

  @override
  String get name => 'Yaesu GS-232';

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) {
    final st = t.settings.station;
    return [
      if (!overrides.containsKey(rotatorAxesConfigKey))
        {
          'type': 'field',
          'fieldType': 'select',
          'key': rotatorAxesConfigKey,
          'label': st.rotatorAxes,
          'description': st.rotatorAxesDescription,
          'options': [
            {'value': rotatorAxesAzimuth, 'label': st.rotatorAxesAzimuth},
            {'value': rotatorAxesAzimuthElevation, 'label': st.rotatorAxesAzimuthElevation},
          ],
        },
      ...rotatorConfigElements(),
      // The shared poll field's key, bounds and blank rule, in a rotator's
      // words: this poll is not an idle one, it is the only reading there is.
      {
        ...pollConfigElement(fallback: gs232PollInterval),
        'label': st.rotatorPollInterval,
        'description': st.rotatorPollIntervalDescription(fallback: gs232PollInterval.inMilliseconds),
      },
    ];
  }

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key == pollIntervalConfigKey) return validatePollInterval(value);
    if (validateRotatorField(key, value, config) case final error?) return error;
    if (key != rotatorAxesConfigKey || value == null || value == '') return null;
    return (value == rotatorAxesAzimuth || value == rotatorAxesAzimuthElevation) ? null : t.settings.station.rotatorAxesRequired;
  }

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => Gs232Session(
    sink,
    elevation: rotatorHasElevation(config),
    calibration: RotatorCalibration.from(config),
    pollInterval: idlePollIntervalFor(config, fallback: gs232PollInterval),
  );
}

/// A [RotatorSession] and not a [TransceiverSession]: nothing here has a
/// frequency.
class Gs232Session implements RotatorSession {
  final EquipmentSink _sink;

  /// Asks for, reports and sends an elevation. Off, an elevation the
  /// controller volunteers is dropped: an az-only rotator on an az/el
  /// interface reports a meaningless one from its unconnected input.
  final bool elevation;

  final RotatorCalibration calibration;
  final Duration pollInterval;

  Gs232Session(this._sink, {this.elevation = false, this.calibration = const RotatorCalibration(), this.pollInterval = gs232PollInterval});

  /// A GS-232A answers CRLF; an emulator may send either half alone.
  final _framer = LineFramer(crTerminates: true);

  bool _wantUpdates = false;
  Timer? _pollTimer;

  /// What this session last told the operator was wrong, so the next good
  /// answer clears it and no other answer does.
  bool _refused = false;

  /// The controller's own last reading, before [calibration]: the degrees a
  /// turn is chosen in.
  RotatorPosition? _last;

  void _send(String command) => _sink.send(ascii.encode(command));

  void _poll() => _send(elevation ? gs232AzimuthElevationQuery : gs232AzimuthQuery);

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
    _framer.reset();
    _last = null;
    _refused = false;
  }

  /// The poll period: this session asks, it is never told.
  @override
  Duration? get expectedUpdateInterval => pollInterval;

  @override
  void handleData(Uint8List chunk) {
    for (final line in _framer.add(chunk)) {
      if (isGs232Refusal(line)) {
        // Connected and answering, and not to what we asked: a controller
        // in another protocol mode (an emulator set to Easycom), or an
        // az-only interface asked for `C2`. Reconnecting fixes neither.
        _sink.reportAlive();
        if (!_refused) _sink.reportProblem(t.settings.station.rotatorRefused);
        _refused = true;
        continue;
      }
      final reading = parseGs232Position(line);
      if (reading == null) continue;
      if (_refused) _sink.reportProblem(null);
      _refused = false;
      final position = elevation ? reading : RotatorPosition(azimuth: reading.azimuth);
      // Reported every time, changed or not: the manager dedupes, and the
      // report is also what tells it the controller is still there.
      _last = position;
      if (_sink case final RotatorSink rotator) rotator.reportRotator(calibration.toTrue(position));
    }
  }

  @override
  RotatorPosition rotateTo({required num azimuth, num? elevation}) {
    final controller = calibration.controllerAzimuth(azimuth, from: _last?.azimuth);
    final controllerElevation = this.elevation && elevation != null ? calibration.controllerElevation(elevation) : null;
    _send(controllerElevation != null ? gs232AzimuthElevationCommand(controller, controllerElevation) : gs232AzimuthCommand(controller));
    return calibration.toTrue(RotatorPosition(azimuth: controller, elevation: controllerElevation));
  }

  @override
  void stopRotation() => _send(gs232StopCommand);

  @override
  String toString() => 'Gs232Session(${elevation ? 'az/el' : 'az'}, $_last)';
}

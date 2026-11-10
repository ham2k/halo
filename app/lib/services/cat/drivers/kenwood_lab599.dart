// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Lab599 TX-500 line's side of a Kenwood session
// ([KenwoodModeDialect.lab599]): which of its two CAT protocols the radio is
// on, the rated output its `PC` level and power-out meter are shares of, the
// supply `VL;` reads, and the `PT` that sees it keyed in DIG. Its `SM0;` is
// read with every other Kenwood's, in kenwood_meters.dart.

part of 'kenwood_driver.dart';

mixin _Lab599 {
  EquipmentSink get _sink;
  KenwoodModeDialect? get modeDialect;
  VfoReading? get _lastReported;
  TelemetryPoller get _telemetry;
  void _send(String command);
  void _meterTransmitSays({required bool? transmitting});

  bool get _lab599 => modeDialect == KenwoodModeDialect.lab599;

  /// Whether the radio's CAT menu is on the LAB599 protocol, from its `ID;`
  /// answer. Null until it answers. Only that protocol has a command for DIG,
  /// `VL` or `PT`: on TS-2000 a DIG request is sent as its USB base, as on a
  /// radio without a DATA submode.
  bool? _lab599Protocol;

  bool get _digSettable => _lab599 && _lab599Protocol == true;

  /// What [_lastReported]'s band rates the radio at — what its `PC` level and
  /// its power-out meter are shares of.
  num get _lab599RatedWatts => lab599RatedWatts(_lastReported?.freqKHz);

  void _lab599Identified(String id) {
    _lab599Protocol = lab599ProtocolIds.contains(id);
    _sink.reportDiagnostic('CAT protocol ${_lab599Protocol! ? 'LAB599' : 'TS-2000, no DIG or volts'} (ID$id)');
  }

  void _readLab599Volts() {
    if (_lab599Protocol == true) _send(buildLab599ReadVoltageCommand());
  }

  /// Every watch, keyed or not, ahead of its `IF`: the one answer that still
  /// comes while the radio is in DIG.
  void _watchLab599Ptt() {
    if (_lab599Protocol == true) _send(buildLab599ReadPttCommand());
  }

  void _handleLab599Ptt(String params) {
    final transmitting = parseLab599PttParams(params);
    if (transmitting == null) return;
    _meterTransmitSays(transmitting: transmitting);
    if (_telemetry.noteTransmitting(transmitting)) _sink.reportTransmitting(transmitting);
  }

  void _handleLab599Volts(String params) {
    final volts = parseLab599VoltageParams(params);
    if (volts != null) _sink.reportMeter(RadioMeter.supplyVolts, volts);
  }
}

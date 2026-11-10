// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A Kenwood session's meters, for an entry whose calibration file gives
// them a scale: `SM0;`, the S-meter while receiving and power out while
// keyed, and while keyed a bare `RM;` for SWR, COMP and ALC. Neither selects
// anything on the radio's panel. See docs/design/cat.md § Transmit
// telemetry.

part of 'kenwood_driver.dart';

/// What a strength table's 0 dB stands for: S9 on HF, per the IARU Region 1
/// S-meter recommendation.
const kenwoodS9Dbm = -73;

/// Each `RM` meter's table, and what it reports as.
const _rmTables = {
  KenwoodMeter.swr: (MeterTable.swr, RadioMeter.swr),
  KenwoodMeter.comp: (MeterTable.compression, RadioMeter.compression),
  KenwoodMeter.alc: (MeterTable.alc, RadioMeter.alc),
};

/// The meters [calibration] gives a Kenwood a scale for, plus the TX-500
/// line's supply, which `VL;` reads in volts outright.
Set<RadioMeter> kenwoodMetersFor(MeterCalibration? calibration, {required bool lab599}) => {
  if (calibration?.has(MeterTable.strength) ?? false) RadioMeter.signalDbm,
  if (_hasPower(calibration)) RadioMeter.powerOut,
  for (final (table, meter) in _rmTables.values)
    if (calibration?.has(table) ?? false) meter,
  if (lab599) RadioMeter.supplyVolts,
};

bool _hasPower(MeterCalibration? calibration) => (calibration?.has(MeterTable.power) ?? false) || (calibration?.has(MeterTable.powerFraction) ?? false);

/// `SM0;` is the S-meter receiving and power out keyed, so it is asked
/// whenever the table for what it is now reading exists.
bool _readsSMeter(MeterCalibration? calibration, {required bool transmitting, required bool capturing}) =>
    capturing || (transmitting ? _hasPower(calibration) : (calibration?.has(MeterTable.strength) ?? false));

bool _readsRm(MeterCalibration? calibration, {required bool capturing}) => capturing || _rmTables.values.any((entry) => calibration?.has(entry.$1) ?? false);

/// What one meter cycle adds to the `IF` watch, keyed or not.
int kenwoodMeterCycleBytes(MeterCalibration? calibration, {required bool transmitting, required bool capturing, required bool lab599}) =>
    (_readsSMeter(calibration, transmitting: transmitting, capturing: capturing) ? kenwoodSMeterBytes : 0) +
    (transmitting && _readsRm(calibration, capturing: capturing) ? kenwoodMeterReadBytes : 0) +
    (lab599 ? lab599PttBytes + (transmitting ? lab599VoltsBytes : 0) : 0);

mixin _KenwoodMeters {
  EquipmentSink get _sink;
  Map<String, dynamic> get _config;
  bool get _transmitting;
  void _send(String command);

  /// What a `powerFraction` table is a share of. Null where a radio's table
  /// is in watts, or where nothing says.
  num? get _meterRatedWatts;

  /// Per read, not once: the tables load asynchronously, so a session that
  /// came up first starts converting the moment they land.
  MeterCalibration? get _meterCalibration => calibrationForConfig(_config);

  bool get _capturingMeters => _config[KenwoodDriver.meterCaptureKey] == true;

  /// Readings held for the `IF` or `PT` asked after them, and whether the
  /// radio was keyed when they came. `SM0;` answers with the S-meter or
  /// with power out depending on when the radio reads it, so a reading is
  /// reported only once the next transmit flag agrees with what it was
  /// taken as: an S9 answered just after the unkey, reported as power,
  /// would stand on the strip for [meterLinger].
  final _heldMeters = <RadioMeter, num>{};
  bool _heldKeyed = false;

  /// The raw values a capture shows, by the command and meter that gave
  /// them: dots, or the whole answer quoted when it is not in the shape
  /// these parsers read.
  final _rawMeters = <String, String>{};

  /// Ahead of the `PT` and `IF` that confirm them.
  void _readMeters(bool transmitting) {
    final calibration = _meterCalibration;
    final capturing = _capturingMeters;
    if (_readsSMeter(calibration, transmitting: transmitting, capturing: capturing)) _send(buildKenwoodReadSMeterCommand());
    // Only while keyed: the TS-590S answers ALC while receiving too, during
    // voice-memory recording, and an RM read can never confirm it.
    if (transmitting && _readsRm(calibration, capturing: capturing)) _send(buildKenwoodReadMeterCommand());
  }

  void _handleSMeter(String params) {
    final dots = parseKenwoodSMeterParams(params);
    if (dots == null) return _capture('SM', '"$params"');
    final keyed = _transmitting;
    _capture('SM', '$dots');
    final calibration = _meterCalibration;
    if (keyed) {
      if (_wattsFor(calibration, dots) case final watts?) _hold(RadioMeter.powerOut, watts, keyed: true);
    } else if (calibration?.convert(MeterTable.strength, dots) case final db?) {
      _hold(RadioMeter.signalDbm, kenwoodS9Dbm + db, keyed: false);
    }
  }

  void _handleMeterRead(String params) {
    final reading = parseKenwoodMeterParams(params);
    if (reading == null) return _capture('RM', '"$params"');
    _capture('RM${reading.meter.index + 1}', '${reading.dots}');
    if (!_transmitting) return;
    final (table, meter) = _rmTables[reading.meter]!;
    if (_meterCalibration?.convert(table, reading.dots) case final value?) _hold(meter, value, keyed: true);
  }

  num? _wattsFor(MeterCalibration? calibration, int dots) {
    if (calibration?.convert(MeterTable.power, dots) case final watts?) return (watts * 10).round() / 10;
    final rated = _meterRatedWatts;
    final fraction = rated == null ? null : calibration?.convert(MeterTable.powerFraction, dots);
    return fraction == null ? null : (fraction * rated! * 10).round() / 10;
  }

  void _hold(RadioMeter meter, num value, {required bool keyed}) {
    if (_heldKeyed != keyed) _heldMeters.clear();
    _heldKeyed = keyed;
    _heldMeters[meter] = value;
  }

  /// A `PT` or `IF` read: the held readings are reported only if it still
  /// says what they were taken as.
  void _meterTransmitSays({required bool? transmitting}) {
    if (transmitting == _heldKeyed) {
      for (final MapEntry(key: meter, value: value) in _heldMeters.entries) {
        _sink.reportMeter(meter, value);
      }
    }
    _heldMeters.clear();
  }

  /// Raw, whatever the tables say: a capture is how a table is built, and
  /// how a wrong one is found — and an answer in a shape the parsers miss
  /// is what a capture most needs to show.
  void _capture(String name, String raw) {
    if (!_capturingMeters) return;
    _rawMeters[name] = raw;
    final note = '${_transmitting ? 'TX' : 'RX'} ${[for (final MapEntry(:key, :value) in _rawMeters.entries) '$key=$value'].join(' ')}';
    _sink.reportDiagnostic(note);
    // Also on the console, which is where a capture is actually READ from:
    // the diagnostic line holds only the latest values, while an over's
    // worth of them is a series.
    debugPrint('[cat] kenwood meters $note');
  }
}

// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

part of 'kenwood_driver.dart';

// SMH; out and a signed dBm reply back.
const _k4SignalExchangeBytes = 12;
const _k4TxRangeRetryMillis = 1000;
const _k4SignalRetryMillis = 3000;

/// K4 transmit meters are global. The secure owner reports received signal
/// separately so the Main and Sub levels reach only their own receivers.
mixin _K4Metering {
  EquipmentSink get _sink;
  bool get remote;
  bool get _transmitting;
  void _send(String command);

  String? _k4TxPowerRange;
  ({int forward, int swrTenths})? _k4PendingTxMeter;
  int? _k4TxRangeAskedAt;
  int? _k4SignalProbeAt;
  bool _k4SignalSupported = false;

  void _startK4Metering() {
    _send('TM1;');
    if (!remote) _readK4Signal();
  }

  void _clearK4TxMeter() {
    _k4TxPowerRange = null;
    _k4PendingTxMeter = null;
    _k4TxRangeAskedAt = null;
  }

  void _resetK4Metering() {
    _clearK4TxMeter();
    _k4SignalProbeAt = null;
    _k4SignalSupported = false;
  }

  void _readK4Signal() {
    // Some CAT modes do not return signed dBm. Probe at idle-state pace
    // until a signed answer proves that the receive meter is available.
    if (!_k4SignalSupported) {
      final now = realNowMillis();
      if (_k4SignalProbeAt case final asked? when now >= asked && now - asked < _k4SignalRetryMillis) return;
      _k4SignalProbeAt = now;
    }
    _send('SMH;');
  }

  void _handleK4Signal(String params) {
    if (parseK4Signal(params) case (receiver: K4Receiver.main, :final dbm)) {
      _k4SignalSupported = true;
      _sink.reportMeter(RadioMeter.signalDbm, dbm);
    }
  }

  /// A legacy PC push does not say which scale TM uses. A new power write
  /// or an unkey also clears the range before the next transmit reading.
  void _readK4PowerRange() {
    if (_transmitting) _k4TxPowerRange = null;
    if (remote || _transmitting) _send('PCX;');
  }

  void _noteK4PowerRange(String range) {
    _k4TxPowerRange = range;
    _k4TxRangeAskedAt = null;
    if (_k4PendingTxMeter case final meter?) {
      _k4PendingTxMeter = null;
      _reportK4TxMeter(meter);
    }
  }

  void _handleK4TxMeter(String params) {
    final meter = parseK4TransmitMeter(params);
    if (meter == null) return;
    if (_k4TxPowerRange != null) return _reportK4TxMeter(meter);

    _k4PendingTxMeter = meter;
    final now = realNowMillis();
    if (_k4TxRangeAskedAt case final asked? when now >= asked && now - asked < _k4TxRangeRetryMillis) return;
    _k4TxRangeAskedAt = now;
    _send('PCX;');
  }

  void _reportK4TxMeter(({int forward, int swrTenths}) meter) {
    final watts = switch (_k4TxPowerRange) {
      'L' => meter.forward / 10,
      'H' => meter.forward,
      // The K4 reference gives no TM scale for transverter output.
      _ => null,
    };
    if (watts == null) return;
    _sink.reportMeter(RadioMeter.powerOut, watts);
    // The SWR average uses the power we just reported. Between CW elements
    // and syllables there is no RF to measure a match against.
    if (watts > 0 && meter.swrTenths >= 10) _sink.reportMeter(RadioMeter.swr, meter.swrTenths / 10);
  }
}

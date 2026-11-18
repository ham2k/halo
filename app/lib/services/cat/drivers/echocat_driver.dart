// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

// POTACAT exposes tuning and radio state over ECHOCAT WebSocket messages.
// The upstream protocol reference describes the messages this driver uses.
// https://github.com/Waffleslop/POTACAT/blob/a4529819facc4035016c941590d77ed2c9cd553c/docs/echocat-protocol.md

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show nowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../driver.dart';
import '../equipment.dart';
import '../spectrum.dart';

const _wireModes = {
  'LSB': 'LSB',
  'USB': 'USB',
  'CW': 'CW',
  'CW-R': 'CW-R',
  'AM': 'AM',
  'FM': 'FM',
  'RTTY': 'RTTY',
  'RTTY-R': 'RTTY-R',
  'DATA-USB': 'PKTUSB',
  'DATA-LSB': 'PKTLSB',
};

class EchocatDriver extends EquipmentDriver {
  const EchocatDriver();

  @override
  String get key => 'echocat';

  @override
  String get name => 'ECHOCAT';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(_wireModes.keys);

  @override
  Set<RadioMeter> get telemetryMeters => const {RadioMeter.signalDbm, RadioMeter.swr, RadioMeter.powerOut};

  @override
  bool offersScopeWith(Map<String, dynamic> config) => true;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => EchocatSession(sink);
}

class EchocatSession implements TransceiverSession, SpectrumSession {
  final EquipmentSink _sink;
  final SpectrumSink? _scope;
  StreamSubscription<Uint8List>? _scopeFrames;
  Timer? _heartbeat;
  bool _catConnected = false;
  bool _transmitting = false;
  bool _canSetWatts = false;
  bool _watchingScope = false;
  List<int> _spans = const [];
  ({int low, int high, double floor, double ceiling})? _axis;

  EchocatSession(this._sink) : _scope = _sink is SpectrumSink ? _sink as SpectrumSink : null;

  @override
  Duration? get expectedUpdateInterval => null;

  void _send(Map<String, Object> message) => _sink.send(utf8.encode(jsonEncode(message)));

  // The WebSocket transport delivers one event per text message.
  @override
  void handleData(Uint8List chunk) {
    final Object? message;
    try {
      message = jsonDecode(utf8.decode(chunk));
    } on FormatException {
      return;
    }
    if (message is! Map<String, dynamic>) return;
    switch (message['type']) {
      case 'status':
        _status(message);
      case 'pong':
        if (_catConnected) _sink.reportAlive();
      case 'smeter':
        if (_catConnected) _reportMeter(RadioMeter.signalDbm, message['dbm'], max: 0);
      case 'swr-ratio':
        if (_catConnected && _transmitting) _reportMeter(RadioMeter.swr, message['value'], min: 1);
      case 'fwd-power':
        if (_catConnected && _transmitting) _reportMeter(RadioMeter.powerOut, message['value'], min: 0);
      case 'scope-state':
        if (_watchingScope) _scopeState(message);
      case 'scope-frame':
        if (_axis case final axis? when _watchingScope && message['bins'] is List) {
          _scopeFrame(message['bins'] as List, axis);
        }
    }
  }

  void _status(Map<String, dynamic> message) {
    if (message['catConnected'] case final bool connected when connected != _catConnected || !connected) {
      _catConnected = connected;
      _sink.reportProblem(connected ? null : t.settings.station.echocatRadioDisconnected);
    }
    if (!_catConnected) return;
    _sink.reportAlive();
    final frequency = _number(message['freq']);
    final reported = message['mode'];
    final mode = reported is String ? _wireModes.entries.where((entry) => entry.value == reported).firstOrNull?.key : null;
    if ((frequency != null && frequency > 0) || mode != null) {
      _sink.report(VfoReading(freqKHz: frequency != null && frequency > 0 ? frequency / 1000 : null, mode: mode));
    }
    if (message['txState'] case final bool tx) {
      _transmitting = tx;
      _sink.reportTransmitting(tx);
    }
    final watts = _number(message['txpower']);
    final powerInWatts = message['txPowerUnit'] != '%';
    final capabilities = message['capabilities'];
    _canSetWatts = powerInWatts && capabilities is Map && capabilities['txpower'] == true;
    if (powerInWatts && watts != null && watts >= 0) _sink.reportPower(watts);
    _reportMeter(RadioMeter.signalDbm, message['smeterDbm'], max: 0);
    if (_transmitting) _reportMeter(RadioMeter.swr, message['swrRatio'], min: 1);
    // POTACAT also has raw S-meter/SWR readings and a 'power' field that
    // can contain the setpoint. None of those carry HaLo's meter units.
    // https://github.com/Waffleslop/POTACAT/blob/a4529819facc4035016c941590d77ed2c9cd553c/main.js#L31730-L31747
  }

  void _reportMeter(RadioMeter meter, Object? raw, {num? min, num? max}) {
    final value = _number(raw);
    if (value != null && (min == null || value >= min) && (max == null || value <= max)) _sink.reportMeter(meter, value);
  }

  @override
  void setFrequency(double freqKHz) {
    if (_catConnected && freqKHz.isFinite && freqKHz > 0) {
      // The wire format is kHz as a string with three decimal places.
      // https://github.com/Waffleslop/POTACAT/blob/a4529819facc4035016c941590d77ed2c9cd553c/lib/remote-client.js#L183-L195
      _send({'type': 'tune', 'freqKhz': freqKHz.toStringAsFixed(3)});
    }
  }

  @override
  void setMode(String mode) {
    if (_wireModes[mode] case final wireMode? when _catConnected) _send({'type': 'set-mode', 'mode': wireMode});
  }

  @override
  void setPower(num watts) {
    if (_catConnected && _canSetWatts && watts.isFinite && watts >= 0) {
      _send({'type': 'set-txpower', 'value': watts});
    }
  }

  @override
  void startUpdates() {
    _heartbeat ??= Timer.periodic(const Duration(seconds: 5), (_) => _send({'type': 'ping'}));
  }

  @override
  void stopUpdates() {
    _heartbeat?.cancel();
    _heartbeat = null;
    stopSpectrum();
  }

  @override
  void teardown() => stopUpdates();

  @override
  String? get spectrumUnavailable => null;

  @override
  SpectrumCapabilities get spectrumCapabilities => SpectrumCapabilities(spansHz: _spans, refMinDb: 0, refMaxDb: 0, refStepDb: 1, modes: const {});

  @override
  void startSpectrum() {
    if (_watchingScope) return;
    _watchingScope = true;
    // WebSocket samples use the side channel to keep the CAT log small.
    if (_sink case final BinaryFramesSink sink) _scopeFrames = sink.binaryFrames?.listen(handleData);
    // The server caps the requested width at 1024 bins per subscriber.
    // https://github.com/Waffleslop/POTACAT/blob/a4529819facc4035016c941590d77ed2c9cd553c/lib/remote-server.js#L4752-L4766
    _send({'type': 'scope-subscribe', 'on': true, 'bins': 1024});
  }

  @override
  void stopSpectrum() {
    if (!_watchingScope) return;
    _watchingScope = false;
    unawaited(_scopeFrames?.cancel());
    _scopeFrames = null;
    _axis = null;
    _spans = const [];
    _send({'type': 'scope-subscribe', 'on': false});
  }

  @override
  bool setSpectrum(SpectrumRequest request) {
    final span = request.spanHz;
    if (!_watchingScope || span == null || _spans.isEmpty) return false;
    _send({'type': 'scope-span', 'spanHz': spectrumCapabilities.snapSpan(span) * 2});
    return true;
  }

  void _scopeState(Map<String, dynamic> message) {
    final scope = _scope;
    if (scope == null) return;
    if (message['available'] == false || message['status'] == 'error') {
      _axis = null;
      _spans = const [];
      scope.reportSpectrumProblem(t.settings.station.echocatScopeUnavailable);
      return;
    }

    final axis = message['axis'];
    final start = axis is Map ? _number(axis['startHz']) : null;
    final end = axis is Map ? _number(axis['endHz']) : null;
    // A Yaesu in FIX or CURSOR can draw a local scope without knowing the
    // RF edges. HaLo uses those edges for tuning and spot placement.
    // https://github.com/Waffleslop/POTACAT/blob/a4529819facc4035016c941590d77ed2c9cd553c/lib/scope-axis.js#L73-L94
    if (axis is! Map || axis['known'] != true || start == null || end == null || start < 0 || end - start < 1) {
      _axis = null;
      if (message['status'] == 'live') scope.reportSpectrumProblem(t.settings.station.echocatScopeAxisUnknown);
      return;
    }

    final scale = message['levelScale'];
    final lowLevel = scale is Map ? _number(scale['min'])?.toDouble() : null;
    final highLevel = scale is Map ? _number(scale['max'])?.toDouble() : null;
    final calibrated = lowLevel != null && highLevel != null && lowLevel < highLevel;
    _axis = (low: start.round(), high: end.round(), floor: calibrated ? lowLevel : 0, ceiling: calibrated ? highLevel : 255);
    final spans = message['spans'];
    _spans = spans is List
        ? {
            for (final value in spans)
              if (_number(value) case final width? when width >= 2) (width / 2).round(),
          }.toList()
        : const [];
    scope.reportSpectrumProblem(null);
    final fixed = axis['anchor'] == 'fixed' || axis['anchor'] == 'pan';
    scope.reportSpectrumSettings(
      SpectrumSettings(
        mode: fixed ? SpectrumMode.fixed : SpectrumMode.center,
        spanHz: ((end - start) / 2).round(),
        lowHz: fixed ? start.round() : null,
        highHz: fixed ? end.round() : null,
      ),
    );
  }

  void _scopeFrame(List<dynamic> bins, ({int low, int high, double floor, double ceiling}) axis) {
    if (bins.length < 2 || bins.length > 1024) return;
    final levels = Float32List(bins.length);
    for (var index = 0; index < bins.length; index++) {
      final bin = _number(bins[index]);
      if (bin == null || bin < 0 || bin > 255) return;
      levels[index] = axis.floor + (axis.ceiling - axis.floor) * bin / 255;
    }
    _scope?.reportSpectrum(
      SpectrumFrame(lowHz: axis.low, highHz: axis.high, levels: levels, floorDb: axis.floor, ceilingDb: axis.ceiling, atMillis: nowMillis()),
    );
  }
}

num? _number(Object? value) => value is num && value.isFinite ? value : null;

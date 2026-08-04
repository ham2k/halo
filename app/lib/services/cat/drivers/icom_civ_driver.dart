// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks CI-V (see civ_codec.dart) to any Icom transceiver. Like every
// driver here it deals only in already-framed bytes handed to it by a
// transport — today a serial port; the same driver is what a WiFi transport
// would carry, since the Icom network protocol tunnels CI-V unchanged.
//
// Model-agnostic on purpose: the radio's bus address is configuration, not
// a constant. app-polo's IC-705 attempt burned bench time on a wrong
// address it had no way to change without an edit-and-rebuild.
//
// For what has and has not met real hardware, see [hardwareVerified] below.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../i18n/strings.g.dart';
import '../driver.dart';
import '../equipment.dart';
import 'civ_codec.dart';

/// Transceive makes the radio announce changes on its own, but it is a
/// setting on the radio that may simply be off, and nothing in CI-V lets us
/// read back whether it took. So poll as well — the same belt-and-braces the
/// FlexRadio and FT-891 drivers use, for the same reason.
const _pollInterval = Duration(seconds: 5);

class IcomCivDriver extends EquipmentDriver {
  const IcomCivDriver();

  @override
  String get key => 'icom-civ';

  @override
  String get name => 'Icom (CI-V)';

  /// Exercised against a real IC-705: connected through the app, held for
  /// ten minutes, frequency tracking the VFO throughout. Ten minutes
  /// deliberately — without periodic reauth these sessions go silent at about
  /// two (see `_reauthInterval` in icom_network_transport_io.dart), so any
  /// shorter run would have looked perfect and proved nothing.
  ///
  /// PRECISELY WHAT THAT COVERS: this driver over the **network** transport.
  /// The same driver also backs Icom CI-V over USB serial, and that
  /// combination has never met a radio. The driver itself is what this flag
  /// documents, and the serial transport is separately proven by the FT-891 —
  /// but if someone reports an IC-7300 on USB behaving oddly, that pairing is
  /// untested and this comment is the reason not to be surprised.
  @override
  bool get hardwareVerified => true;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => IcomCivSession(
        sink,
        radioAddress: _addressOrFallback(config['civAddress'], civRadioAddresses['IC-705']!),
        controllerAddress: _addressOrFallback(config['civControllerAddress'], civDefaultControllerAddress),
      );

  /// `civControllerAddress` is read directly in [createSession] above, on
  /// every pairing, and never shown as a field on any of them — a network
  /// fact ([icomNetworkControllerAddress]), not a setting.
  @override
  Set<String> get recognizedConfigKeys => {...super.recognizedConfigKeys, 'civControllerAddress'};

  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      // A pairing that hardcodes the address (the IC-705's network type
      // fixes it, since RS-BA1 only ever talks to the one radio it's
      // paired with) has nothing to show here.
      overrides.containsKey('civAddress')
          ? const []
          : [
              {
                'type': 'field',
                'fieldType': 'text',
                'key': 'civAddress',
                'label': t.settings.station.civAddress,
                'description': t.settings.station.civAddressDescription,
              },
            ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != 'civAddress') return null;
    // A wrong address is SILENT — the radio ignores frames addressed
    // elsewhere, which is indistinguishable from a dead cable. Catch an
    // unusable one here rather than at the bench.
    return _parseAddress(value) == null ? t.settings.station.civAddressInvalid : null;
  }

  @override
  String? describeSuffix(Map<String, dynamic> config, {Map<String, dynamic> overrides = const {}}) {
    // A pairing that hardcodes the address (the IC-705's network type — see
    // configElements above) never shows it as a field, so it shouldn't show
    // up in the list row either: A4 is a network protocol constant there,
    // not something the operator picked.
    if (overrides.containsKey('civAddress')) return null;
    final parsed = _parseAddress(config['civAddress']);
    final text = parsed == null ? '?' : parsed.toRadixString(16).toUpperCase().padLeft(2, '0');
    return ' · CI-V $text';
  }

  /// Hex, with or without an `0x`, as the radio's own menu shows it — or
  /// decimal, since an address round-tripped through JSON arrives as a
  /// String or a num depending on the path. Null for anything unusable.
  static int? _parseAddress(dynamic raw) {
    if (raw is num) {
      final value = raw.toInt();
      return (value >= 1 && value <= 0xFF) ? value : null;
    }
    if (raw is String) {
      final text = raw.trim().replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
      final parsed = int.tryParse(text, radix: 16);
      if (parsed != null && parsed >= 1 && parsed <= 0xFF) return parsed;
    }
    return null;
  }

  static int _addressOrFallback(dynamic raw, int fallback) => _parseAddress(raw) ?? fallback;
}

class IcomCivSession implements EquipmentSession {
  final EquipmentSink _sink;

  /// The radio's CI-V bus address (IC-705 ships as 0xA4).
  final int radioAddress;

  /// Ours. Every frame we send carries it, and every frame that comes back
  /// carrying it is our own echo.
  final int controllerAddress;

  final _framer = CivFramer();
  Timer? _pollTimer;

  IcomCivSession(this._sink, {required this.radioAddress, required this.controllerAddress});

  void _send(List<int> frame) => _sink.send(frame);

  void _requestFrequencyAndMode() {
    _send(buildReadFrequencyFrame(to: radioAddress, from: controllerAddress));
    _send(buildReadModeFrame(to: radioAddress, from: controllerAddress));
  }

  @override
  void handleData(Uint8List chunk) {
    for (final frame in _framer.add(chunk)) {
      _handle(frame);
    }
  }

  void _handle(CivFrame frame) {
    // CI-V is a bus: the radio reflects back what we send it. Reading our
    // own set-frequency as if the radio had reported it would make every
    // command look instantly confirmed, including the ones it rejected.
    if (frame.isEchoOf(controllerAddress)) return;

    // Traffic between the radio and some other controller on the same bus.
    if (!frame.isFor(controllerAddress)) return;

    // Only the radio we were configured for.
    if (frame.from != radioAddress) return;

    if (frame.isNak) {
      // The radio refused the command. polo ignored this entirely, so a
      // refusal was indistinguishable from silence and the app went on
      // believing the radio had moved.
      debugPrint('[cat] CI-V: radio rejected the last command');
      return;
    }
    if (frame.isAck) return;

    // The radio announcing on its own settles a question nothing in CI-V
    // lets us ask: whether transceive is on. From here the dial is reported
    // as it moves, so the poll is only the backstop it was written to be —
    // see [expectedUpdateInterval]. One-way, because transceive is a menu
    // setting, not something that lapses.
    if (frame.command == CivCommand.transceiveFrequency || frame.command == CivCommand.transceiveMode) {
      _sawTransceive = true;
    }

    switch (frame.command) {
      // 0x00/0x03 are the same payload: an unsolicited announcement and an
      // answer to our read.
      case CivCommand.transceiveFrequency:
      case CivCommand.readFrequency:
        final freqHz = decodeBcdFrequency(frame.data);
        // Everything above here speaks kHz.
        if (freqHz != null) _sink.report(VfoReading(freqKHz: freqHz / 1000));

      case CivCommand.transceiveMode:
      case CivCommand.readMode:
        if (frame.data.isEmpty) return;
        // data[0] is the mode; data[1], when present, is the filter, which
        // we read but do not track.
        final mode = civModeNameForCode(frame.data[0]);
        if (mode != null) _sink.report(VfoReading(mode: mode));
    }
  }

  @override
  void setFrequency(double freqKHz) => _send(buildSetFrequencyFrame(
        to: radioAddress,
        from: controllerAddress,
        freqHz: (freqKHz * 1000).round(),
      ));

  @override
  void setMode(String mode) {
    // Filter omitted deliberately — sending one forces the operator's
    // filter selection, which polo did on every mode change.
    final frame = buildSetModeFrame(to: radioAddress, from: controllerAddress, mode: mode);
    if (frame != null) _send(frame);
  }

  @override
  void startUpdates() {
    _framer.reset();
    _requestFrequencyAndMode();
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => _requestFrequencyAndMode());
  }

  @override
  void stopUpdates() => _stopPolling();

  /// Whether the radio has ever announced a change on its own — see
  /// [handleData].
  bool _sawTransceive = false;

  /// Null once transceive has proved itself, [_pollInterval] until then.
  ///
  /// Reporting the poll rate outright would be reading a backstop as a
  /// cadence: with transceive on — the default, and what a bench IC-705 does
  /// on both WiFi and serial — the dial is announced as it moves, and
  /// charging Smart VFO Snap five seconds for a radio that answers in
  /// milliseconds makes the feature feel broken on the hardware it works
  /// best on. The other direction is just as wrong, so this is measured
  /// rather than assumed: with transceive OFF the poll IS the cadence, and
  /// claiming otherwise settles a snap in the silence between polls.
  @override
  Duration? get expectedUpdateInterval => _sawTransceive ? null : _pollInterval;

  @override
  void teardown() => _stopPolling();

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

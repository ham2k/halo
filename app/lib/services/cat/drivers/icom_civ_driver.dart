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
// NOT hardware-verified. Nothing here has been run against a radio.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../driver.dart';
import '../equipment.dart';
import 'civ_codec.dart';

/// Transceive makes the radio announce changes on its own, but it is a
/// setting on the radio that may simply be off, and nothing in CI-V lets us
/// read back whether it took. So poll as well — the same belt-and-braces the
/// FlexRadio and FT-891 drivers use, for the same reason.
const _pollInterval = Duration(seconds: 5);

class IcomCivDriver implements EquipmentDriver {
  const IcomCivDriver();

  @override
  String get key => 'icom-civ';

  @override
  String get name => 'Icom (CI-V)';

  @override
  bool get hardwareVerified => false;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => IcomCivSession(
        sink,
        radioAddress: _address(config['civAddress'], civRadioAddresses['IC-705']!),
        controllerAddress: _address(config['civControllerAddress'], civDefaultControllerAddress),
      );

  /// Addresses are entered as hex ("A4") or decimal, and round-trip through
  /// JSON, so they arrive as a String or a num depending on the path.
  static int _address(dynamic raw, int fallback) {
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final text = raw.trim().replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
      final parsed = int.tryParse(text, radix: 16);
      if (parsed != null && parsed > 0 && parsed <= 0xFF) return parsed;
    }
    return fallback;
  }
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

  @override
  void teardown() => _stopPolling();

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

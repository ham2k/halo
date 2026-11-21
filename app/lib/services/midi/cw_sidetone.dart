// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_audio/halo_audio.dart';

import '../error_reporting_service.dart';

/// Local monitor for paddles that rely on the app to generate Morse elements.
class CwSidetone {
  AudioSidetone? _output;

  /// Opens the device before accepting key edges. An audio failure cannot
  /// stop the operator from keying the radio.
  void prepare() {
    if (!HaloAudio.isSupported || _output?.isAlive == true) return;
    close();
    try {
      _output = HaloAudio.openSidetone();
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'midi:cw-sidetone');
    }
  }

  void setKeyDown(bool down, {required int pitchHz}) => _output?.setKeyDown(down, pitchHz: pitchHz);

  void close() {
    _output?.close();
    _output = null;
  }
}

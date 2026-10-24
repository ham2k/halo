// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

part of 'kenwood_driver.dart';

/// K4 Ethernet supplies spectrum; USB serial stays a CAT-only session.
class K4SpectrumSession extends KenwoodSession implements SpectrumSession {
  K4SpectrumSession(
    super._sink, {
    required this._spectrum,
    super.declaredModeOffset,
    super.cwDialect,
    super.voiceDialect,
    super.voiceMemories,
    super.voiceMemoryCeiling,
    super.config,
  }) : super(isK4: true, passbandDialect: KenwoodPassbandDialect.elecraft);

  final K4Spectrum _spectrum;

  @override
  String? get spectrumUnavailable => null;
  @override
  SpectrumCapabilities get spectrumCapabilities => _spectrum.capabilities;
  @override
  void startSpectrum() => _spectrum.start();
  @override
  void stopSpectrum() => _spectrum.stop();
  @override
  bool setSpectrum(SpectrumRequest request) => _spectrum.set(request);

  // Scope demand belongs to CatService; stopping CAT updates must not stop
  // a spectrum that the service still considers active.

  @override
  void teardown() {
    _spectrum.teardown();
    super.teardown();
  }
}

// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

part of 'kenwood_driver.dart';

const kx3IqEnabledKey = 'kx3IqEnabled';
const kx3IqDeviceKey = 'kx3IqDevice';
const kx3IqRateKey = 'kx3IqRate';
const kx3IqSwapKey = 'kx3IqSwap';
const kx3IqOffsetKey = 'kx3IqOffset';
const kx3IqAccessActionKey = 'kx3IqAccess';
const kx3IqRates = [48000, 96000, 192000];

/// Only this named model has the physical I/Q output. KX2 shares its CAT
/// and keyer dialects, but those facts do not imply panadapter support.
class Kx3Driver extends KenwoodDriver {
  const Kx3Driver();

  static List<IqAudioInput> _inputs = const [];

  @override
  Future<EquipmentActionResult?>? runAction(String actionKey, String method, Map<String, dynamic> state) =>
      actionKey == kx3IqAccessActionKey && method == 'prepare' ? _prepareInputAccess(state) : null;

  Future<EquipmentActionResult?> _prepareInputAccess(Map<String, dynamic> state) async {
    final rate = numberFromConfig(state, kx3IqRateKey, 48000);
    try {
      // The browser opens/resumes its audio context before this first await.
      await prepareIqAudioAccess(sampleRate: kx3IqRates.contains(rate) ? rate : 48000);
      // An explicit refresh reports failures; passive form preparation only
      // logs them so the saved, possibly disconnected selection stays editable.
      _inputs = await listIqAudioInputs();
      return const EquipmentActionResult(fieldUpdates: {});
    } catch (error, stack) {
      ErrorReportingService.report(CatConnectFailure('kx3-iq', error), stack, context: 'cat:kx3-iq-access');
      return EquipmentActionResult(message: iqAudioProblemFor(error));
    }
  }

  @override
  Future<void> prepareConfigElements() async {
    try {
      _inputs = iqAudioSupported ? await listIqAudioInputs() : const [];
    } catch (error, stack) {
      _inputs = const [];
      ErrorReportingService.report(error, stack, context: 'cat:kx3-iq-inputs');
    }
  }

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    if (config[kx3IqEnabledKey] != true) return super.createSession(sink, config);
    final rate = numberFromConfig(config, kx3IqRateKey, 48000);
    return Kx3SpectrumSession(
      sink,
      spectrum: Kx3IqSpectrum(
        deviceId: stringFromConfig(config, kx3IqDeviceKey),
        sampleRate: kx3IqRates.contains(rate) ? rate : 48000,
        offsetHz: numberFromConfig(config, kx3IqOffsetKey, 0).clamp(-24000, 24000),
        swapIq: config[kx3IqSwapKey] == true,
        sink: sink is SpectrumSink ? sink as SpectrumSink : null,
      ),
      declaredModeOffset: 27,
      cwDialect: KenwoodDriver.cwDialectFrom(config),
      voiceDialect: KenwoodDriver.voiceDialectFrom(config),
      voiceMemories: KenwoodDriver.voiceMemoriesFrom(config),
      voiceMemoryCeiling: voiceCeilingFromConfig(config),
      config: config,
    );
  }

  @override
  Set<String> get recognizedConfigKeys => {...super.recognizedConfigKeys, kx3IqEnabledKey, kx3IqDeviceKey, kx3IqRateKey, kx3IqSwapKey, kx3IqOffsetKey};

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    ...super.configElements(overrides: overrides, restrictions: restrictions),
    if (iqAudioSupported) ...[
      {
        'type': 'field',
        'fieldType': 'checkbox',
        'key': kx3IqEnabledKey,
        'label': t.settings.station.kx3IqEnabled,
        'description': t.settings.station.kx3IqDescription,
      },
      {
        'type': 'field',
        'fieldType': 'select',
        'key': kx3IqDeviceKey,
        'label': t.settings.station.kx3IqDevice,
        'options': [
          for (final input in _inputs) {'value': input.id, 'label': input.label, 'icon': 'waveform'},
          {
            'value': kx3IqAccessActionKey,
            'label': iqAudioNeedsAccess ? t.settings.station.kx3IqAllowInput : t.settings.station.kx3IqRefreshInputs,
            'icon': 'waveform',
            'isAction': true,
            'method': 'prepare',
          },
        ],
      },
      {
        'type': 'field',
        'fieldType': 'select',
        'key': kx3IqRateKey,
        'label': t.settings.station.kx3IqRate,
        'options': [
          for (final rate in kx3IqRates) {'value': rate, 'label': '${rate ~/ 1000} kHz'},
        ],
      },
      {'type': 'field', 'fieldType': 'checkbox', 'key': kx3IqSwapKey, 'label': t.settings.station.kx3IqSwap},
      {
        'type': 'field',
        'fieldType': 'number',
        'key': kx3IqOffsetKey,
        'label': t.settings.station.kx3IqOffset,
        'description': t.settings.station.kx3IqOffsetDescription,
      },
    ],
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (config[kx3IqEnabledKey] == true) {
      if (key == kx3IqDeviceKey && (value is! String || value.trim().isEmpty)) return t.settings.station.kx3IqSelectDevice;
      if (key == kx3IqRateKey && value != null && value != '' && !kx3IqRates.contains(int.tryParse('$value'))) return t.settings.station.kx3IqInvalidRate;
      if (key == kx3IqOffsetKey && value != null && value != '') {
        final offset = int.tryParse('$value');
        if (offset == null || offset.abs() > 24000) return t.settings.station.kx3IqInvalidOffset;
      }
    }
    return super.validateField(key, value, config);
  }
}

class Kx3SpectrumSession extends KenwoodSession implements SpectrumSession {
  Kx3SpectrumSession(
    super._sink, {
    required this._spectrum,
    super.declaredModeOffset,
    super.cwDialect,
    super.voiceDialect,
    super.voiceMemories,
    super.voiceMemoryCeiling,
    super.config,
  }) : super(passbandDialect: KenwoodPassbandDialect.elecraft);

  final Kx3IqSpectrum _spectrum;

  @override
  String? get spectrumUnavailable => iqAudioSupported ? null : t.settings.station.kx3IqUnsupported;
  @override
  SpectrumCapabilities get spectrumCapabilities => _spectrum.capabilities;
  @override
  void startSpectrum() => _spectrum.start();
  @override
  void stopSpectrum() => _spectrum.stop();
  @override
  bool setSpectrum(SpectrumRequest request) => _spectrum.set(request);

  @override
  void _report(VfoReading reading) {
    if (reading.freqKHz case final hz?) _spectrum.updateFrequency((hz * 1000).round());
    super._report(reading);
  }

  @override
  void teardown() {
    _spectrum.teardown();
    super.teardown();
  }
}

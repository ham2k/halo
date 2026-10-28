// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Kenwood line's equipment driver: its models, its configuration fields
// and their checks, and the session it opens (kenwood_driver.dart).

part of 'kenwood_driver.dart';

class KenwoodDriver extends EquipmentDriver {
  const KenwoodDriver() : isK4 = false, lanSpectrum = false;
  const KenwoodDriver.k4({this.lanSpectrum = false}) : isK4 = true;

  /// Pinned by the model, never inferred from the optional voice dialect.
  final bool isK4;

  /// Pinned by the Ethernet pairing: a serial node can retain a saved host
  /// after switching variants, without that authorizing a second LAN link.
  final bool lanSpectrum;

  /// What most of the Kenwood line ships set to, and what its CAT menu calls
  /// 9600. Only a default — a mismatch answers with garbage and no error, so
  /// the operator has to be able to change it.
  static const defaultBaudRate = 9600;

  @override
  String get key => isK4 ? 'elecraft-k4' : 'kenwood';

  @override
  String get name => isK4 ? 'Elecraft K4 (CAT)' : 'Kenwood (CAT)';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder([
    ...kenwoodModeTable(modeDialectFrom(config)).keys,
    if (isK4) ...['DATA-USB', 'DATA-LSB', 'PSK'] else ...dataModeBases.keys,
  ]);

  /// A radio whose `IF` layout we DO know — a specific model built on this
  /// driver — pins the mode's offset here rather than letting the session
  /// work it out. Read straight from the config and never rendered as a
  /// field: it is a fact about the pairing, not a question for the operator,
  /// the same way the IC-705's network controller address is.
  ///
  /// Pinning it does not stop the session checking it. A declared offset that
  /// the radio contradicts is a mistake in OUR table, and the alternative to
  /// noticing is reporting wrong modes forever.
  static const ifModeOffsetKey = 'ifModeOffset';

  /// Which voice-memory dialect the radio speaks ([KenwoodVoiceDialect] by
  /// name) and how many memories it has — pinned per catalogue entry the
  /// way [ifModeOffsetKey] is, since the driver serves a whole line and a
  /// QMX has no voice keyer at all. Absent means none.
  static const voiceDialectKey = 'voiceDialect';
  static const voiceMemoriesKey = voiceMemoriesConfigKey;

  /// Which shape of `KY` keys CW ([KenwoodCwDialect] by name), pinned the
  /// same way. Absent — or a name no dialect answers to — keys nothing.
  static const cwDialectKey = 'cwDialect';

  /// Whether the radio has the `DA` DATA submode (the TS-590 generation),
  /// pinned per entry like the dialects above. Absent means none: on the K4
  /// `DA` is the digital-audio command, and on a radio without it every poll
  /// would ask a question it refuses.
  static const dataModeKey = 'dataMode';

  /// Whether `TX1;` is DATA SEND — transmit with the computer's audio — on
  /// this radio, pinned per entry like the dialects below. Absent means it
  /// is not: the Elecraft references give `TX;` alone, and an entry whose
  /// radio's reference nobody has read must not send a command that might
  /// mean something else.
  static const dataSendKey = 'dataSend';

  /// Which receive-filter commands the radio answers
  /// ([KenwoodPassbandDialect] by name), pinned per entry like the dialects
  /// above. Absent means the passband is neither read nor set. The K4 needs
  /// no pin — [isK4] is one.
  static const passbandDialectKey = 'passbandDialect';

  /// Which `AN` the radio answers for its own antenna ports
  /// ([KenwoodAntennaDialect] by name), pinned per entry like the dialects
  /// above. Absent means none is read or offered — a radio with one port
  /// shows no choice. Never the K4's: its `AN` is its own.
  static const antennaDialectKey = 'antennaDialect';

  /// Which `MD` table the radio speaks ([KenwoodModeDialect] by name), pinned
  /// per entry like the dialects above. Absent is Kenwood's own.
  static const modeDialectKey = 'modeDialect';

  static KenwoodModeDialect? modeDialectFrom(Map<String, dynamic> config) =>
      KenwoodModeDialect.values.where((d) => d.name == config[modeDialectKey]).firstOrNull;

  static KenwoodAntennaDialect? antennaDialectFrom(Map<String, dynamic> config) =>
      KenwoodAntennaDialect.values.where((d) => d.name == config[antennaDialectKey]).firstOrNull;

  static KenwoodPassbandDialect? passbandDialectFrom(Map<String, dynamic> config) =>
      KenwoodPassbandDialect.values.where((d) => d.name == config[passbandDialectKey]).firstOrNull;

  static KenwoodCwDialect? cwDialectFrom(Map<String, dynamic> config) => KenwoodCwDialect.values.where((d) => d.name == config[cwDialectKey]).firstOrNull;

  static KenwoodVoiceDialect? voiceDialectFrom(Map<String, dynamic> config) =>
      KenwoodVoiceDialect.values.where((d) => d.name == config[voiceDialectKey]).firstOrNull;

  /// A dialect named with no count — the developer picked one and left the
  /// other — takes the dialect's own: a `pb` TS-590 has four, a K4 eight, a
  /// KX two. A count is never more than the dialect can address.
  static int voiceMemoriesFrom(Map<String, dynamic> config) {
    final dialect = voiceDialectFrom(config);
    if (dialect == null) return 0;
    final own = switch (dialect) {
      KenwoodVoiceDialect.pb => 4,
      KenwoodVoiceDialect.k4 => maxVoiceMemories,
      KenwoodVoiceDialect.kx => kxVoiceMemoryCount,
    };
    final count = voiceMemoriesFromConfig(config, fallback: 0);
    return (count > 0 ? count : own).clamp(0, dialect == KenwoodVoiceDialect.kx ? kxVoiceMemoryCount : maxVoiceMemories);
  }

  /// A whole line on one driver, so the keyer is a fact about the entry —
  /// the named ones pin it, the generics ask under developer mode.
  @override
  bool canKeyCwWith(Map<String, dynamic> config) => cwDialectFrom(config) != null;

  @override
  int voiceMemoryCountWith(Map<String, dynamic> config) => voiceMemoriesFrom(config);

  @override
  Set<String> get recognizedConfigKeys => {
    ...super.recognizedConfigKeys,
    ifModeOffsetKey,
    cwDialectKey,
    voiceDialectKey,
    voiceMemoriesKey,
    voiceCeilingConfigKey,
    dataModeKey,
    dataSendKey,
    passbandDialectKey,
    antennaDialectKey,
    modeDialectKey,
    meterInfoConfigKey,
    'maxWatts',
  };

  @override
  int get telemetryWatchBytes => kenwoodTxWatchBytes;

  /// Per node: only the TX-500 line reads meters, so any other Kenwood's
  /// placeholder is its watch's alone.
  @override
  Duration defaultTelemetryInterval(Map<String, dynamic> config) => telemetryIntervalFor(
    const {},
    cycleBytes: kenwoodTxWatchBytes + (modeDialectFrom(config) == KenwoodModeDialect.lab599 ? lab599PttBytes + lab599MeterBytes : 0),
    baudRate: serialBaudRateOrNull(config),
  );

  /// Only the TX-500 line, whose `SM0;` reads power out and `VL;` the supply
  /// without touching the front panel. Every other radio here meters through
  /// `RM`, which changes the meter the operator is looking at.
  @override
  Set<RadioMeter> telemetryMetersWith(Map<String, dynamic> config) => modeDialectFrom(config) != KenwoodModeDialect.lab599
      ? const {}
      : {if (calibrationFor(config)?.has(MeterTable.powerFraction) ?? false) RadioMeter.powerOut, RadioMeter.supplyVolts};

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final modeOffset = switch (config[ifModeOffsetKey]) {
      final int offset when offset >= kenwoodFrequencyDigits => offset,
      _ => null,
    };
    final host = lanSpectrum ? trimmedHost(config) : '';
    if (lanSpectrum && host.isNotEmpty) {
      return K4SpectrumSession(
        sink,
        spectrum: K4Spectrum(host: host, sink: sink is SpectrumSink ? sink as SpectrumSink : null),
        declaredModeOffset: modeOffset,
        cwDialect: cwDialectFrom(config),
        voiceDialect: voiceDialectFrom(config),
        voiceMemories: voiceMemoriesFrom(config),
        voiceMemoryCeiling: voiceCeilingFromConfig(config),
        config: config,
      );
    }
    return KenwoodSession(
      sink,
      isK4: isK4,
      declaredModeOffset: modeOffset,
      cwDialect: cwDialectFrom(config),
      voiceDialect: voiceDialectFrom(config),
      voiceMemories: voiceMemoriesFrom(config),
      voiceMemoryCeiling: voiceCeilingFromConfig(config),
      dataMode: !isK4 && config[dataModeKey] == true,
      dataSend: !isK4 && config[dataSendKey] == true,
      passbandDialect: switch (passbandDialectFrom(config)) {
        _ when isK4 => KenwoodPassbandDialect.elecraft,
        // Without `DA` the session cannot tell SSB-DATA from SSB, and the
        // TS-590SG gives each its own menu for what `SL`/`SH` mean.
        KenwoodPassbandDialect.ts590sg when config[dataModeKey] != true => null,
        final dialect => dialect,
      },
      antennaDialect: isK4 ? null : antennaDialectFrom(config),
      modeDialect: isK4 ? null : modeDialectFrom(config),
      config: config,
    );
  }

  /// The keyer facts, asked only where the entry did not pin them — the
  /// generic Kenwood and Elecraft — and only of a developer: which shape of
  /// `KY` the rig takes and which voice keyer it has are things the
  /// catalogue should know, and these fields are how it learns before an
  /// entry exists (docs/design/cat.md § Voice keying).
  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey(cwDialectKey))
      {
        'type': 'field',
        'fieldType': 'select',
        'key': cwDialectKey,
        'label': t.settings.station.cwDialect,
        'description': t.settings.station.cwDialectDescription,
        'devMode': true,
        'options': [
          {'value': '', 'label': t.settings.station.keyerNone},
          {'value': KenwoodCwDialect.kenwood.name, 'label': t.settings.station.cwDialectKenwood},
          {'value': KenwoodCwDialect.elecraft.name, 'label': t.settings.station.cwDialectElecraft},
        ],
      },
    if (!overrides.containsKey(voiceDialectKey))
      {
        'type': 'field',
        'fieldType': 'select',
        'key': voiceDialectKey,
        'label': t.settings.station.voiceDialect,
        'description': t.settings.station.voiceDialectDescription,
        'devMode': true,
        'options': [
          {'value': '', 'label': t.settings.station.keyerNone},
          {'value': KenwoodVoiceDialect.pb.name, 'label': t.settings.station.voiceDialectPb},
          {'value': KenwoodVoiceDialect.k4.name, 'label': t.settings.station.voiceDialectK4},
          {'value': KenwoodVoiceDialect.kx.name, 'label': t.settings.station.voiceDialectKx},
        ],
      },
    if (!overrides.containsKey(voiceMemoriesKey)) voiceMemoriesConfigElement(),
    telemetryConfigElement(),
    pollConfigElement(),
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => switch (key) {
    voiceMemoriesKey => validateVoiceMemories(value),
    telemetryIntervalConfigKey => validateTelemetryInterval(value),
    pollIntervalConfigKey => validatePollInterval(value),
    _ => null,
  };
}

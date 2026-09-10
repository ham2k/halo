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
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../driver.dart';
import '../equipment.dart';
import '../telemetry_poller.dart';
import '../transports/config_field_helpers.dart';
import 'civ_codec.dart';
import 'cw_send_queue.dart';
import 'keyer_config.dart';
import 'meter_calibration.dart';
import 'telemetry_config.dart';
import 'voice_activity_tracker.dart';

/// Transceive makes the radio announce changes on its own, but it is a
/// setting on the radio that may simply be off, and nothing in CI-V lets us
/// read back whether it took. So poll as well — the same belt-and-braces the
/// FlexRadio and FT-891 drivers use, for the same reason.
const _pollInterval = Duration(seconds: 5);

/// The RF power level (0x14 0x0A) is a 0-255 value standing for 0-100% of
/// the radio's OWN maximum — CI-V has no command that states what that
/// maximum is, so [IcomCivSession.maxWatts] comes from config instead:
/// [ic705Model]'s pairings override it to the IC-705's real 10W SSB/CW
/// ceiling (equipment_registry.dart); everything else — the generic Icom
/// pairing, and any config that leaves it out — falls back to this 100W
/// guess, the common ceiling across the HF line this driver otherwise
/// targets (IC-7300, IC-9700, IC-7610). Unverified either way — see
/// [IcomCivDriver.hardwareVerified].
const _assumedMaxWatts = 100;

/// Below this ceiling a 0-255 level actually carries sub-watt resolution
/// worth showing (10W over 255 steps is ~0.04W/step) — above it the ceiling
/// itself is a guess, and reporting e.g. 76.47058823529412W as though
/// precise is worse than useless. One decimal, not the raw division: it
/// still fits the Power field's 4-digit width and is what a QRP radio's own
/// display shows.
const _preciseWattsCeiling = 20;

int _levelForWatts(num watts, num maxWatts) => (watts / maxWatts * 255).round().clamp(0, 255);

num _wattsForLevel(int level, num maxWatts) {
  final raw = level / 255 * maxWatts;
  return maxWatts <= _preciseWattsCeiling ? (raw * 10).round() / 10 : raw.round();
}

/// Below this RAW reading, [IcomCivSession.dcInputMeterLevel] says the radio
/// is on its own battery rather than an external supply — confirmed LIVE
/// against an IC-705, which read 115 on its internal battery and 195 plugged
/// in. The midpoint, since only those two bench readings exist; a supply
/// that happens to land near it would misclassify, but nothing between "flat
/// battery" and "external DC" is physically expected.
///
/// Deliberately compared as a RAW level and not as volts. Icom's published
/// Vd scale is a curve, and a different one per radio (see
/// [civMeterDcInputVoltage]) — this check needs neither, because both bench
/// readings are in the same units the radio answers in.
const _batteryMeterCeiling = 150;

/// A CI-V exchange is a 7-byte question and a 9-byte answer with one data
/// byte pair — 16 bytes on the wire, which is what the cadence floor is
/// computed from ([telemetryIntervalFor]).
const _civExchangeBytes = 16;

/// The TX watch is one exchange; the meter cycle is one per meter read.
const civTxWatchBytes = _civExchangeBytes;
const civMeterCycleBytes = _civExchangeBytes * 4;

/// Which CI-V meter carries which reading, and which calibration table turns
/// its 0-255 into something an operator can read. One map, so the poll, the
/// parse and the "what can this radio show" question cannot disagree.
const _metersByTable = <MeterTable, RadioMeter>{
  MeterTable.powerFraction: RadioMeter.powerOut,
  MeterTable.swr: RadioMeter.swr,
  MeterTable.alc: RadioMeter.alc,
  MeterTable.voltage: RadioMeter.supplyVolts,
};

const _tablesByMeterId = <int, MeterTable>{
  civMeterRfPower: MeterTable.powerFraction,
  civMeterSwr: MeterTable.swr,
  civMeterAlc: MeterTable.alc,
  civMeterDcInputVoltage: MeterTable.voltage,
};

class IcomCivDriver extends EquipmentDriver {
  const IcomCivDriver();

  @override
  String get key => 'icom-civ';

  @override
  String get name => 'Icom (CI-V)';


  /// Icom publishes ONE set of meter breakpoints for the current CI-V line,
  /// so the scale is the driver's rather than each entry's — unlike Yaesu,
  /// where every radio is aligned individually. An entry may still name
  /// another file for a radio known to differ.
  @override
  String? get defaultMeterInfoKey => 'icom/civ-generic';

  /// What the table describes, which for the shipped one is everything the
  /// line publishes a scale for. Supply voltage was already being read for
  /// the battery-derating check ([civMeterDcInputVoltage]) — this is the
  /// first thing that shows it.
  @override
  Set<RadioMeter> get telemetryMeters => telemetryMetersWith(const {});

  @override
  Set<RadioMeter> telemetryMetersWith(Map<String, dynamic> config) {
    final calibration = calibrationFor(config);
    if (calibration == null) return const {};
    return {
      for (final entry in _metersByTable.entries)
        if (calibration.has(entry.key)) entry.value,
    };
  }

  @override
  int get telemetryWatchBytes => civTxWatchBytes;

  @override
  int get telemetryCycleBytes => civMeterCycleBytes;

  @override
  bool get canKeyCw => true;

  /// The line keys by default (0x17 is documented across it) — an entry
  /// for a rig that does not, or a developer on the generic entry, says
  /// otherwise through [cwKeyerConfigKey].
  @override
  bool canKeyCwWith(Map<String, dynamic> config) => cwKeyerFromConfig(config, fallback: true);

  @override
  int voiceMemoryCountWith(Map<String, dynamic> config) =>
      voiceMemoriesFromConfig(config, fallback: 0).clamp(0, civVoiceMemoryCount);

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => IcomCivSession(
        sink,
        radioAddress: _addressOrFallback(config['civAddress'], civRadioAddresses['IC-705']!),
        controllerAddress: _addressOrFallback(config['civControllerAddress'], civDefaultControllerAddress),
        maxWatts: (config['maxWatts'] as num?) ?? _assumedMaxWatts,
        batteryMaxWatts: config['batteryMaxWatts'] as num?,
        // Absent means NONE, unlike the CW keyer: every named entry pins
        // the count, so an absent key is a generic entry's node — one
        // added before the field existed — and a generic knows no rig.
        voiceMemories: voiceMemoriesFromConfig(config, fallback: 0).clamp(0, civVoiceMemoryCount),
        voiceMemoryCeiling: voiceCeilingFromConfig(config),
        config: config,
        meterInfoKey: (config[meterInfoConfigKey] as String?) ?? defaultMeterInfoKey,
      );

  /// `civControllerAddress`, `maxWatts` and `batteryMaxWatts` are read
  /// directly in [createSession] above, on every pairing, and never shown as
  /// fields on any of them — device facts ([icomNetworkControllerAddress], a
  /// model's rated power), not settings.
  @override
  Set<String> get recognizedConfigKeys => {
        ...super.recognizedConfigKeys,
        meterInfoConfigKey,
        'civControllerAddress',
        'maxWatts',
        'batteryMaxWatts',
        cwKeyerConfigKey,
        voiceMemoriesConfigKey,
        voiceCeilingConfigKey,
      };

  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      [
        // A pairing that hardcodes the address (the IC-705's network type
        // fixes it, since RS-BA1 only ever talks to the one radio it's
        // paired with) has nothing to show here.
        if (!overrides.containsKey('civAddress'))
          {
            'type': 'field',
            'fieldType': 'text',
            'key': 'civAddress',
            'label': t.settings.station.civAddress,
            'description': t.settings.station.civAddressDescription,
          },
        // The keyer facts, asked only where the entry did not pin them —
        // the generic Icom — and only of a developer (docs/design/cat.md
        // § Voice keying).
        ...keyerConfigElements(overrides),
        telemetryConfigElement(),
      ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key == voiceMemoriesConfigKey) return validateVoiceMemories(value);
    if (key == telemetryIntervalConfigKey) return validateTelemetryInterval(value);
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

class IcomCivSession implements TransceiverSession, CwKeyerSession, VoiceKeyerSession {
  final EquipmentSink _sink;

  /// The radio's CI-V bus address (IC-705 ships as 0xA4).
  final int radioAddress;

  /// Ours. Every frame we send carries it, and every frame that comes back
  /// carrying it is our own echo.
  final int controllerAddress;

  /// The radio's own 100%-level ceiling in watts — see [_assumedMaxWatts].
  final num maxWatts;

  /// A lower ceiling that applies instead of [maxWatts] while
  /// [dcInputMeterLevel] says the radio is running off its own battery — null
  /// for a radio with no separate battery rating (everything but the IC-705
  /// today). The SET level itself doesn't drop on battery — see
  /// [civMeterDcInputVoltage] — so without this a QRP radio quietly reports
  /// power it cannot actually put out.
  final num? batteryMaxWatts;

  final _framer = CivFramer();
  Timer? _pollTimer;

  /// Watches for the operator to key the rig, and reads the meters while
  /// they hold it. Its own cadence, separate from [_pollTimer]'s five
  /// seconds: a whole over can begin and end inside one of those, and CI-V
  /// announces nothing about transmitting on its own — transceive covers
  /// the dial and the mode, not the PTT.
  late final TelemetryPoller _telemetry = TelemetryPoller(
    onPoll: _pollTelemetry,
    idleInterval: telemetryIntervalFor(_config, cycleBytes: civTxWatchBytes, baudRate: _baudRate),
    txInterval: telemetryIntervalFor(_config, cycleBytes: civMeterCycleBytes, baudRate: _baudRate),
  );

  /// The node's merged config, kept for [_telemetry]'s intervals — a `late
  /// final` field cannot be initialised from another field in the
  /// constructor's initialiser list.
  final Map<String, dynamic> _config;

  /// Null on the network pairing, where there is no serial line to budget
  /// against — see [telemetryFloor].
  final int? _baudRate;

  /// Which calibration file describes this radio's meters — resolved by the
  /// driver, since for CI-V it is usually the driver's own default. Looked
  /// up on every reading rather than resolved once, so a session built
  /// before the tables finished loading starts converting when they land.
  final String? _meterInfoKey;

  MeterCalibration? get _calibration => MeterCalibrations.instance[_meterInfoKey];

  /// What the radio last said its keyer runs at — the pace [_cwQueue]
  /// spaces chunks by, so it is read once at startUpdates rather than only
  /// when the operator opens the dialog that shows it.
  int? _keyerSpeed;

  late final _cwQueue = CwSendQueue(
    maxChunkLength: civCwMaxChars,
    send: (chunk) => _send(buildSendCwFrame(to: radioAddress, from: controllerAddress, text: chunk)),
    speedWpm: () => _keyerSpeed,
    onProgress: _sink.reportCwProgress,
  );

  /// 0x28 says nothing about its own progress, so while a memory plays the
  /// radio is asked whether it is still transmitting (0x1C 0x00) — a voice
  /// memory transmits — and the activity ends when it is not. That poll is
  /// also how a REFUSED play ends (the radio not in a voice mode, the memory
  /// empty): a second late, rather than on the NAK, because CI-V's ACK/NAK
  /// names no command and sends are not awaited, so a NAK in flight from a
  /// meter read would end a memory that is on the air.
  late final VoiceActivityTracker _voice = VoiceActivityTracker(
    report: _sink.reportVoiceActivity,
    stop: stopVoice,
    ceiling: () => voiceMemoryCeiling,
    onCeiling: (limit) => _sink.reportDiagnostic('voice memory stopped at the ${limit.inSeconds} s ceiling'),
    poll: () => _send(buildReadTransmitStatusFrame(to: radioAddress, from: controllerAddress)),
  );

  /// See [voiceMemoriesConfigKey]: what the entry pinned, at most the
  /// line's eight.
  final int _voiceMemories;

  @override
  final Duration voiceMemoryCeiling;

  IcomCivSession(
    this._sink, {
    required this.radioAddress,
    required this.controllerAddress,
    this.maxWatts = _assumedMaxWatts,
    this.batteryMaxWatts,
    this._voiceMemories = civVoiceMemoryCount,
    this.voiceMemoryCeiling = voiceActivityCeiling,
    Map<String, dynamic> config = const {},
    this._meterInfoKey,
  })  : _config = config,
        _baudRate = serialBaudRateOrNull(config);

  void _send(List<int> frame) => _sink.send(frame);

  void _requestFrequencyAndMode() {
    _send(buildReadFrequencyFrame(to: radioAddress, from: controllerAddress));
    _send(buildReadModeFrame(to: radioAddress, from: controllerAddress));
    _send(buildReadPowerLevelFrame(to: radioAddress, from: controllerAddress));
    _send(buildReadMeterFrame(to: radioAddress, from: controllerAddress, meterId: civMeterDcInputVoltage));
  }

  /// One turn of the telemetry cadence: ask whether the radio is keyed, or
  /// — while it is — read every meter it publishes a scale for.
  ///
  /// The TX watch is not folded into [_requestFrequencyAndMode]'s five
  /// seconds deliberately: at that rate a ten-second over is noticed
  /// halfway through and a short one not at all, and a meter strip that
  /// lights up after the operator has stopped talking is worse than none.
  void _pollTelemetry(bool transmitting) {
    // ALWAYS, transmitting or not. CI-V announces nothing about the PTT, and
    // this is the only question that can hear the radio UNKEY — asked in the
    // idle branch alone, a session that saw one transmission would report
    // the radio as keyed for the rest of the connection, blocking every
    // antenna switch and every snap and reading four meters at 200 ms
    // forever.
    _send(buildReadTransmitStatusFrame(to: radioAddress, from: controllerAddress));
    if (!transmitting) return;
    // Only what something can interpret: a radio whose entry names no
    // calibration (an IC-706MKIIG, whose CI-V has no TX meters at all) would
    // otherwise spend four exchanges a cycle collecting answers nothing
    // reads — and, on that radio, four rejections.
    if (_calibration == null) return;
    for (final meter in const [civMeterRfPower, civMeterSwr, civMeterAlc, civMeterDcInputVoltage]) {
      _send(buildReadMeterFrame(to: radioAddress, from: controllerAddress, meterId: meter));
    }
  }

  /// The DC-input meter's RAW reading — not a voltage, and not convertible
  /// into one without a per-model table (see [civMeterDcInputVoltage]).
  /// Feeds the [batteryMaxWatts] capping below; public only so a test can
  /// read it without an [EquipmentState] field for a value nothing else
  /// consumes.
  int? get dcInputMeterLevel => _dcInputMeterLevel;
  int? _dcInputMeterLevel;

  /// The last RF-power SET level (0x14 0x0A) the radio reported, cached so a
  /// later DC-input reading — on battery, potentially a lower cap — can
  /// recompute [EquipmentSink.reportPower] without waiting on the next power
  /// poll.
  int? _lastLevel;

  bool get _onBattery => _dcInputMeterLevel != null && _dcInputMeterLevel! < _batteryMeterCeiling;

  /// Watts for a 0.0-1.0 fraction of the radio's rated output, under the
  /// same battery cap [_reportPower] applies to the SET level.
  num _wattsForFraction(double fraction) {
    final ceiling = batteryMaxWatts != null && _onBattery ? math.min(maxWatts, batteryMaxWatts!) : maxWatts;
    final watts = fraction * ceiling;
    return ceiling <= _preciseWattsCeiling ? (watts * 10).round() / 10 : watts.round();
  }

  /// The radio answered the TX watch: tell the app, and move the cadence.
  ///
  /// The poller dedupes a restatement, but the SINK must not be told on
  /// every cycle either — [CatService] drops an unchanged value, and a
  /// driver leaning on that would be one refactor away from waking every
  /// listener five times a second.
  void _noteTransmitting(bool transmitting) {
    if (_telemetry.noteTransmitting(transmitting)) _sink.reportTransmitting(transmitting);
  }

  void _reportPower() {
    final level = _lastLevel;
    if (level == null) return;
    final watts = _wattsForLevel(level, maxWatts);
    final cap = batteryMaxWatts;
    _sink.reportPower(cap != null && _onBattery ? math.min(watts, cap) : watts);
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

      case CivCommand.readSetLevel:
        // 0x14 covers several levels (AF, RF gain, squelch…) sharing one
        // command number — only react to the sub-commands we track.
        if (frame.data.isEmpty) return;
        if (frame.data[0] == civLevelRfPower) {
          final level = parsePowerLevelData(frame.data);
          if (level != null) {
            _lastLevel = level;
            _reportPower();
          }
        } else if (frame.data[0] == civLevelKeyerSpeed) {
          final level = parseKeyerSpeedLevelData(frame.data);
          if (level != null) {
            _keyerSpeed = civKeyerSpeedForLevel(level);
            _sink.reportKeyerSpeed(_keyerSpeed!);
          }
        }

      case CivCommand.readMeter:
        // 0x15 covers several meters sharing one command number, and each
        // has its own scale — the raw 0-255 level means nothing until it is
        // read against the right one.
        if (frame.data.isEmpty) return;
        final level = parseMeterData(frame.data);
        if (level == null) return;
        // The DC-input meter is read for two different reasons and only one
        // of them is display: it is what tells an IC-705 on its own battery
        // from one on external DC (see [dcInputMeterLevel]), and that has to
        // happen whether or not a calibration exists to show it with — which
        // for this meter is the normal case, since no shipped table says
        // what an Icom's Vd reading means.
        if (frame.data[0] == civMeterDcInputVoltage) {
          _dcInputMeterLevel = level;
          _reportPower();
        }
        final table = _tablesByMeterId[frame.data[0]];
        final reading = table == null ? null : _calibration?.convert(table, level);
        if (reading == null) return;
        // Power arrives as a FRACTION of the radio's rated output — CI-V
        // states no wattage anywhere — so it is resolved against the same
        // ceiling the SET level uses, battery cap included: a 10W radio
        // derated to 5W by its own battery is putting out at most 5W however
        // hard the meter swings.
        _sink.reportMeter(
          _metersByTable[table]!,
          table == MeterTable.powerFraction ? _wattsForFraction(reading) : reading,
        );

      case CivCommand.transmitStatus:
        // Asked by two things now — the voice tracker, to learn when a
        // memory has finished, and the telemetry watch — and answered the
        // same way whoever asked. The voice tracker's own methods ignore an
        // answer it is not waiting for.
        switch (parseTransmitStatusData(frame.data)) {
          case true:
            _noteTransmitting(true);
            _voice.confirm();
          case false:
            _noteTransmitting(false);
            _voice.endFromPoll();
          case null:
            break;
        }
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
  void setPower(num watts) => _send(buildSetPowerLevelFrame(
        to: radioAddress,
        from: controllerAddress,
        level: _levelForWatts(watts, maxWatts),
      ));

  @override
  void sendCw(String text) => _cwQueue.enqueue(text);

  @override
  void stopCw() {
    _cwQueue.clear();
    _send(buildStopCwFrame(to: radioAddress, from: controllerAddress));
  }

  @override
  bool get cwSending => _cwQueue.sending;

  @override
  void dropQueuedCw(int id) => _cwQueue.dropPending(id);

  @override
  ({int min, int max}) get keyerSpeedRange => (min: civKeyerSpeedMin, max: civKeyerSpeedMax);

  /// Sets, then reads back: a 0x14 set is answered with a bare ACK, so the
  /// value shown is what the radio actually took (the level rounds to a
  /// WPM, and the radio clamps) rather than what was asked for.
  @override
  void setKeyerSpeed(int wpm) {
    _send(buildSetKeyerSpeedFrame(to: radioAddress, from: controllerAddress, level: civLevelForKeyerSpeed(wpm)));
    _send(buildReadKeyerSpeedFrame(to: radioAddress, from: controllerAddress));
  }

  @override
  int get voiceMemoryCount => _voiceMemories;

  /// Nothing in any CI-V guide records a voice memory: that is the front
  /// panel's (VOICE > REC) alone.
  @override
  bool get canRecordVoice => false;

  @override
  void playVoiceMemory(int n) {
    _send(buildPlayVoiceMemoryFrame(to: radioAddress, from: controllerAddress, n: n));
    _voice.start(VoiceActivity(memory: n));
  }

  @override
  void recordVoiceMemory(int n) {}

  @override
  void stopVoice() {
    if (!_voice.active) return;
    _send(buildStopVoiceMemoryFrame(to: radioAddress, from: controllerAddress));
    _voice.end();
  }

  @override
  void startUpdates() {
    _framer.reset();
    _requestFrequencyAndMode();
    // Once, not per poll: the keyer speed changes only when someone turns
    // the knob, and the CI-V guides say nothing about 0x14 0x0C being
    // announced on transceive — so the dialog that shows it re-reads it
    // when it opens (CatService.refreshKeyerSpeed) rather than the poll
    // carrying a question the radio almost never has a new answer to.
    _send(buildReadKeyerSpeedFrame(to: radioAddress, from: controllerAddress));
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => _requestFrequencyAndMode());
    _telemetry.start();
  }

  /// Asks the radio for its keyer speed again — see [startUpdates].
  @override
  void refreshKeyerSpeed() => _send(buildReadKeyerSpeedFrame(to: radioAddress, from: controllerAddress));

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
  void teardown() {
    _cwQueue.clear();
    _voice.dispose();
    _stopPolling();
    _telemetry.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _telemetry.stop();
  }
}

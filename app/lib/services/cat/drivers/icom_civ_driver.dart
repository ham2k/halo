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
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../driver.dart';
import '../equipment.dart';
import '../telemetry_poller.dart';
import '../transports/config_field_helpers.dart';
import 'civ_codec.dart';
import 'cw_send_queue.dart';
import 'keyer_config.dart';
import 'meter_calibration.dart';
import 'poll_config.dart';
import 'telemetry_config.dart';
import 'voice_activity_tracker.dart';

/// Transceive makes the radio announce changes on its own, but it is a
/// setting on the radio that may simply be off, and nothing in CI-V lets us
/// read back whether it took. So poll as well — the same belt-and-braces the
/// FlexRadio and FT-891 drivers use, for the same reason. What the idle poll
/// field means when it is blank.
const _defaultPollInterval = Duration(seconds: 5);

/// How long a command waits for its answer before the next one goes out
/// anyway. An IC-7300 answers in about 10 ms at 19200 baud; this only has to
/// outlast that on a slow link, and bound how long a command the radio never
/// answers holds up the ones behind it.
const _answerTimeout = Duration(milliseconds: 250);

/// The same over the network pairing, whose answers cross WiFi: a timeout
/// shorter than its jitter sends the next command over one still pending,
/// which is the burst this wait exists to prevent.
const _networkAnswerTimeout = Duration(seconds: 1);

/// The RF power level (0x14 0x0A) is a 0-255 value standing for 0-100% of
/// the radio's OWN maximum — CI-V has no command that states what that
/// maximum is, so [IcomCivSession.maxWatts] comes from config instead: a
/// named radio rated anything other than 100W overrides it with its own
/// SSB/CW ceiling (equipment_models_icom.dart — the IC-705's 10W, the
/// IC-7760's 200W); everything else — the generic Icom pairing, and any
/// config that leaves it out — falls back to this 100W guess, the common
/// ceiling across the HF line this driver otherwise targets (IC-7300,
/// IC-9700, IC-7610). Unverified either way — see
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

/// Pinned by an entry whose radio ignores a `0x06` mode set that carries no
/// filter byte — the Xiegu G90, per hamlib's `mode_with_filter`. Never a
/// field: it is a fact about the model.
///
/// The radio keeps a filter per mode, so the filter sent is the one it last
/// reported while in the mode being set — leaving the operator's choice
/// alone, the reason every other entry sends none. A mode not yet seen gets
/// the filter currently in use, and a radio whose answers carry no filter
/// at all gets FIL1: a forced filter is better than a mode control that
/// does nothing.
const civModeWithFilterConfigKey = 'civModeWithFilter';

/// Pinned `false` by an entry whose radio has no DATA submode (`0x1A 0x06`),
/// which would refuse the read on every poll. Every other entry reads and
/// sets it: without it an FT8 request puts the rig in plain USB, and a rig
/// in USB-D reports itself as USB. Never a field: it is a fact about the
/// model.
const civDataModeConfigKey = 'civDataMode';

/// The modes a model has, as a list of the app's names for them — pinned in
/// a named radio's `overrides`, since one CI-V driver serves radios with and
/// without DV, WFM or a DATA submode. Unpinned, the driver offers every mode
/// it can send, less the DATA ones where [civDataModeConfigKey] is off.
const civRadioModesConfigKey = 'radioModes';

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

  @override
  List<String> settableModes(Map<String, dynamic> config) => switch (config[civRadioModesConfigKey]) {
    final List<dynamic> pinned => radioModeOrder(pinned.whereType<String>()),
    _ => radioModeOrder([...civModeCodes.keys, if (config[civDataModeConfigKey] != false) ...dataModeBases.keys]),
  };

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
  int voiceMemoryCountWith(Map<String, dynamic> config) => voiceMemoriesFromConfig(config, fallback: 0).clamp(0, civVoiceMemoryCount);

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
    civModeWithFilterConfigKey,
    civDataModeConfigKey,
    civRadioModesConfigKey,
    cwKeyerConfigKey,
    voiceMemoriesConfigKey,
    voiceCeilingConfigKey,
  };

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
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
    pollConfigElement(fallback: _defaultPollInterval),
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key == voiceMemoriesConfigKey) return validateVoiceMemories(value);
    if (key == telemetryIntervalConfigKey) return validateTelemetryInterval(value);
    if (key == pollIntervalConfigKey) return validatePollInterval(value);
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

class IcomCivSession implements TransceiverSession, CwKeyerSession, VoiceKeyerSession, PttSession {
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
  /// wherever the entry declares none, including a radio whose battery this
  /// check cannot detect (the X6100). The SET level itself doesn't drop on
  /// battery — see [civMeterDcInputVoltage] — so without this a QRP radio
  /// quietly reports power it cannot actually put out.
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
    poll: () => _poll(buildReadTransmitStatusFrame(to: radioAddress, from: controllerAddress)),
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
  }) : _config = config,
       _modeWithFilter = config[civModeWithFilterConfigKey] == true,
       _dataModeSupported = config[civDataModeConfigKey] != false,
       _baudRate = serialBaudRateOrNull(config);

  /// See [civModeWithFilterConfigKey].
  final bool _modeWithFilter;

  late final Duration _pollInterval = idlePollIntervalFor(_config, fallback: _defaultPollInterval);

  /// What the radio's mode answers have said, by mode code and most
  /// recently — see [civModeWithFilterConfigKey]. A set asked for before the
  /// first answer waits in [_pendingMode] rather than being dropped:
  /// [CatService] would not send the same mode again.
  final _filterByMode = <int, int>{};
  int? _lastFilter;
  bool _modeAnswered = false;
  bool _warnedNoFilter = false;
  String? _pendingMode;

  /// See [civDataModeConfigKey]. Cleared for the rest of the session by a
  /// radio that never answers the read — see [_dataReadMisses].
  bool _dataModeSupported;

  /// Whether a DATA read is out with no answer yet, and how many mode
  /// answers have arrived since without one. The poll asks for DATA before
  /// the mode and replies come in order, so a mode answer behind an
  /// unanswered DATA read means the radio refused it — as one without the
  /// submode does, on an entry (the generic Icom one) that could not pin it.
  /// Counting against mode answers rather than time keeps a radio that is
  /// switched off from being judged.
  bool _dataReadPending = false;
  int _dataReadMisses = 0;
  static const _dataReadMissLimit = 2;

  void _readDataMode() {
    _dataReadPending = true;
    _poll(buildReadDataModeFrame(to: radioAddress, from: controllerAddress));
  }

  /// The base mode the radio last reported, and whether its DATA submode was
  /// on — two answers to two questions, reported as one app mode by
  /// [_reportMode].
  String? _baseMode;
  bool _dataOn = false;

  void _reportMode() {
    final base = _baseMode;
    if (base != null) _sink.report(VfoReading(mode: modeNameWithData(base, data: _dataOn)));
  }

  /// Commands waiting to go out, and whether one is on the wire unanswered.
  ///
  /// One at a time, because CI-V has no flow control and a radio keeps only
  /// the LAST of several commands that arrive back to back: sent as a burst,
  /// an IC-7300 answers the last of five queries and drops the other four —
  /// the frequency read among them, forever, since it is first. hamlib keeps
  /// the same discipline.
  final _outbox = Queue<List<int>>();
  Timer? _answerTimer;
  bool _warnedUnanswered = false;

  /// The command byte on the wire unanswered, or null when the wire is free.
  int? _awaiting;

  /// Commands the operator asked for, in order and never merged: a band
  /// change restates its frequency after its mode, and a keyer speed is set
  /// and then read back.
  void _send(List<int> frame) {
    _outbox.add(frame);
    _sendNext();
  }

  /// A question asked on a timer, dropped when the same one is already
  /// waiting: against a radio that answers nothing the polls would otherwise
  /// queue faster than the answer timeout lets them out. Only a read may be
  /// merged, since only a read means the same thing wherever it lands.
  void _poll(List<int> frame) {
    if (_outbox.any((queued) => listEquals(queued, frame))) return;
    _send(frame);
  }

  /// A stop, ahead of everything waiting, and taking with it the queued
  /// frames of [command] it stops — a CW chunk or a voice play still in the
  /// queue would otherwise key the radio after the operator stopped it. It
  /// still waits for the one exchange on the wire.
  void _sendFirst(List<int> frame, {required int dropping}) {
    _outbox.removeWhere((queued) => queued[4] == dropping);
    _outbox.addFirst(frame);
    _sendNext();
  }

  void _sendNext() {
    if (_awaiting != null || _outbox.isEmpty) return;
    final frame = _outbox.removeFirst();
    _awaiting = frame[4];
    _answerTimer = Timer(_baudRate == null ? _networkAnswerTimeout : _answerTimeout, _unanswered);
    _sink.send(frame);
  }

  /// Whether [frame] answers the command on the wire. A data answer repeats
  /// its command byte, so one arriving late for a command that timed out
  /// does not free the wire for the next; ACK and NAK name no command and
  /// are taken as the answer to whatever is waiting.
  bool _answers(CivFrame frame) => frame.isAck || frame.isNak || frame.command == _awaiting;

  void _answered() {
    _answerTimer?.cancel();
    _answerTimer = null;
    _awaiting = null;
    _sendNext();
  }

  /// Said once a session: a radio that ignores one of our commands costs a
  /// timeout on every poll, and nothing else would show it.
  void _unanswered() {
    if (!_warnedUnanswered) {
      _warnedUnanswered = true;
      _sink.reportDiagnostic('radio did not answer CI-V command 0x${_awaiting!.toRadixString(16).padLeft(2, '0').toUpperCase()} in time');
    }
    _answered();
  }

  void _requestFrequencyAndMode() {
    _poll(buildReadFrequencyFrame(to: radioAddress, from: controllerAddress));
    // DATA first: the mode answer is reported against the flag as it stands,
    // and a flag read after it would report the base mode alone in between.
    if (_dataModeSupported) _readDataMode();
    _poll(buildReadModeFrame(to: radioAddress, from: controllerAddress));
    _poll(buildReadPowerLevelFrame(to: radioAddress, from: controllerAddress));
    _poll(buildReadMeterFrame(to: radioAddress, from: controllerAddress, meterId: civMeterDcInputVoltage));
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
    _poll(buildReadTransmitStatusFrame(to: radioAddress, from: controllerAddress));
    if (!transmitting) return;
    // Only what something can interpret: a radio whose entry names no
    // calibration (an IC-706MKIIG, whose CI-V has no TX meters at all) would
    // otherwise spend four exchanges a cycle collecting answers nothing
    // reads — and, on that radio, four rejections.
    if (_calibration == null) return;
    for (final meter in const [civMeterRfPower, civMeterSwr, civMeterAlc, civMeterDcInputVoltage]) {
      _poll(buildReadMeterFrame(to: radioAddress, from: controllerAddress, meterId: meter));
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

    // Anything the radio says proves the link, whatever it is about: a TX
    // status or a meter reading carries no VFO reading, and a radio answering
    // only those would otherwise be marked not responding.
    _sink.reportAlive();
    // An answer to us, not a transceive broadcast, is what frees the wire.
    if (frame.to == controllerAddress && _answers(frame)) _answered();

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
        // data[0] is the mode; data[1], when present, is the filter — sent
        // back by an entry that must send one with a mode, and by every
        // DATA submode set.
        if (frame.data.length > 1) {
          _lastFilter = frame.data[1];
          _filterByMode[frame.data[0]] = frame.data[1];
        }
        if (_modeWithFilter) {
          _modeAnswered = true;
          if (frame.data.length <= 1 && !_warnedNoFilter) {
            _warnedNoFilter = true;
            debugPrint('[cat] CI-V: mode answers carry no filter byte; mode sets send FIL1');
          }
          if (_pendingMode case final pending?) {
            _pendingMode = null;
            setMode(pending);
            // This answer is the mode being replaced: reporting it would put
            // the operator's pick back on screen until the next poll.
            return;
          }
        }
        if (frame.command == CivCommand.readMode && _dataReadPending && ++_dataReadMisses >= _dataReadMissLimit) {
          // Without this, a DATA flag taken as set on a radio that refused
          // it would report DATA-USB for a rig in plain USB for good.
          _dataModeSupported = false;
          _dataReadPending = false;
          _dataOn = false;
          _sink.reportDiagnostic('radio does not answer the DATA submode read (0x1A 0x06); data modes set plain USB');
        }
        final mode = civModeNameForCode(frame.data[0]);
        if (mode == null) return;
        _baseMode = mode;
        _reportMode();
        // A mode announced on its own may have brought its DATA submode with
        // it — a band recall does — and the announcement does not say.
        if (frame.command == CivCommand.transceiveMode && _dataModeSupported) _readDataMode();

      case CivCommand.settings:
        final data = parseDataModeData(frame.data);
        if (data == null) return;
        _dataReadPending = false;
        _dataReadMisses = 0;
        if (data == _dataOn) return;
        _dataOn = data;
        _reportMode();

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
        _sink.reportMeter(_metersByTable[table]!, table == MeterTable.powerFraction ? _wattsForFraction(reading) : reading);

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
  void setFrequency(double freqKHz) => _send(buildSetFrequencyFrame(to: radioAddress, from: controllerAddress, freqHz: (freqKHz * 1000).round()));

  @override
  void setMode(String mode) {
    // Filter omitted deliberately — sending one forces the operator's
    // filter selection, which polo did on every mode change. An entry that
    // must send one sends the radio's own back.
    int? filter;
    if (_modeWithFilter && !_modeAnswered) {
      _pendingMode = mode;
      return;
    }
    // A data mode is its base mode with the DATA submode on; a radio without
    // one is at least put in the base mode, rather than left in whatever a
    // band recall brought back.
    final dataBase = dataModeBases[mode.toUpperCase()];
    final base = dataBase ?? mode;
    final code = civCodeForModeName(base);
    final radioFilter = (code == null ? null : _filterByMode[code]) ?? _lastFilter ?? 0x01;
    if (_modeWithFilter) filter = radioFilter;
    final frame = buildSetModeFrame(to: radioAddress, from: controllerAddress, mode: base, filter: filter);
    if (frame == null) return;
    _send(frame);
    // Stated either way wherever the base mode has a submode: setting the
    // mode leaves DATA as it was on some radios, so plain USB after FT8
    // would otherwise stay USB-D.
    if (_dataModeSupported && dataModeBases.containsValue(base.toUpperCase())) {
      _send(buildSetDataModeFrame(to: radioAddress, from: controllerAddress, on: dataBase != null, filter: radioFilter));
      // Taken as set: the next mode answer would otherwise be reported
      // against the flag from before, putting the old mode in the log until
      // the DATA read lands. A refused set is corrected by that read.
      _dataOn = dataBase != null;
    }
  }

  @override
  void setPower(num watts) => _send(buildSetPowerLevelFrame(to: radioAddress, from: controllerAddress, level: _levelForWatts(watts, maxWatts)));

  @override
  void sendCw(String text) => _cwQueue.enqueue(text);

  @override
  void stopCw() {
    _cwQueue.clear();
    _sendFirst(
      buildStopCwFrame(to: radioAddress, from: controllerAddress),
      dropping: CivCommand.sendCw,
    );
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
    _sendFirst(
      buildStopVoiceMemoryFrame(to: radioAddress, from: controllerAddress),
      dropping: CivCommand.voiceMemory,
    );
    _voice.end();
  }

  /// Whether the app keyed the radio, so [teardown] can unkey it.
  bool _keyedByUs = false;

  /// Ahead of everything waiting, like a stop, and taking queued 0x1C frames
  /// with it: a set still queued from a moment ago would otherwise go out
  /// AFTER this one and undo it. A TX read dropped with them is asked again
  /// on the watch's next turn.
  @override
  void setPtt(bool on) {
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _sendFirst(
      buildSetTransmitFrame(to: radioAddress, from: controllerAddress, on: on),
      dropping: CivCommand.transmitStatus,
    );
    _keyedByUs = on;
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
    if (_keyedByUs) {
      // Straight to the wire, not through the outbox: an unkey that waits
      // for the exchange in flight may not go out at all, and nothing else
      // will unkey this radio.
      _keyedByUs = false;
      _sink.send(buildSetTransmitFrame(to: radioAddress, from: controllerAddress, on: false));
    }
    _answerTimer?.cancel();
    _outbox.clear();
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

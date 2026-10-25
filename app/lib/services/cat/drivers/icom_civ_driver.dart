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
import '../spectrum.dart';
import '../telemetry_poller.dart';
import '../transports/config_field_helpers.dart';
import 'civ_codec.dart';
import 'civ_power.dart';
import 'civ_scope_codec.dart';
import 'cw_send_queue.dart';
import 'keyer_config.dart';
import 'meter_calibration.dart';
import 'optional_read.dart';
import 'poll_config.dart';
import 'telemetry_config.dart';
import 'voice_activity_tracker.dart';

part 'icom_civ_scope.dart';

/// Transceive makes the radio announce changes on its own, but it is a
/// setting on the radio that may simply be off, and nothing in CI-V lets us
/// read back whether it took. So poll as well — the same belt-and-braces the
/// FlexRadio and FT-891 drivers use, for the same reason. What the idle poll
/// field means when it is blank.
const _defaultPollInterval = Duration(seconds: 5);

/// How long a command waits for its answer before the next one goes out
/// anyway, over a cable and over the network pairing alike.
///
/// Generous on purpose. An IC-7300 answers in about 10 ms at 19200 baud, but
/// a radio that answers late is still answering: inside the radio CI-V is
/// one half-duplex line, so a command sent before the wait runs out collides
/// with the answer still going out, and the radio may read the wreckage as a
/// command of its own. hamlib waits 700-1000 ms on the same radios.
///
/// The cost: a command the radio never answers holds up everything behind it
/// this long, an unkey or a stop included (see [IcomCivSession._sendFirst]).
/// A read the radio lacks stops costing it once [OptionalRead] gives up, but
/// that counts only silences on receive; any other command the radio ignores
/// costs it on every poll.
const civAnswerTimeout = Duration(seconds: 1);

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

/// Pinned `false` by an entry whose radio has no filter-width command
/// (`0x1A 0x03`) — the Xiegu G90 and X6100, per hamlib's `x1ax03_supported`.
/// Unpinned, the session asks until the radio refuses or ignores it. Never a
/// field: it is a fact about the model.
const civFilterWidthConfigKey = 'civFilterWidth';

/// The modes a model has, as a list of the app's names for them — pinned in
/// a named radio's `overrides`, since one CI-V driver serves radios with and
/// without DV, WFM or a DATA submode. Unpinned, the driver offers every mode
/// it can send, less the DATA ones where [civDataModeConfigKey] is off.
const civRadioModesConfigKey = 'radioModes';

/// Pinned `true` by an entry whose radio streams its scope over CI-V (0x27).
/// Never a field: it is a fact about the model, and a radio without one
/// answers every scope command with a NAK.
const civScopeConfigKey = 'civScope';

/// Pinned by an entry whose radio picks among its own antenna ports over
/// CI-V (0x12): how many ANT ports it has — 2 on an IC-7610, 4 on an
/// IC-7760, 1 on an IC-7300MK2, whose choice is its receive antenna
/// connectors. Never a field: it is a fact about the model, and nothing in
/// the reply says how many there are. Unpinned, the session never asks.
const civAntennaPortsConfigKey = 'civAntennaPorts';

/// What [RadioAntennas] calls the receive antenna connectors — the name the
/// radios' own "RX-ANT" control gives them.
const civRxAntennaPort = 'RX-ANT';

/// The slowest line a sweep fits on. At fast speed a sweep is ~500 bytes
/// thirty times a second, and a slower line would carry little else — the
/// VFO, the TX watch and the keyer share it.
const civScopeMinBaud = 115200;

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
    maxWatts: (config['maxWatts'] as num?) ?? civAssumedMaxWatts,
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
    civFilterWidthConfigKey,
    civRadioModesConfigKey,
    cwKeyerConfigKey,
    voiceMemoriesConfigKey,
    voiceCeilingConfigKey,
    civScopeConfigKey,
    civAntennaPortsConfigKey,
    civBandMaxWattsConfigKey,
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

class IcomCivSession
    with _CivScope
    implements
        ReadBackSession,
        CwKeyerSession,
        VoiceKeyerSession,
        PttSession,
        SpectrumSession,
        AntennaTunerSession,
        PassbandSession,
        RadioAntennaSession,
        RawCommandSession {
  @override
  final EquipmentSink _sink;

  /// The radio's CI-V bus address (IC-705 ships as 0xA4).
  @override
  final int radioAddress;

  /// Ours. Every frame we send carries it, and every frame that comes back
  /// carrying it is our own echo.
  @override
  final int controllerAddress;

  /// The radio's own 100%-level ceiling in watts — see [civAssumedMaxWatts].
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
  @override
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
    this.maxWatts = civAssumedMaxWatts,
    this.batteryMaxWatts,
    this._voiceMemories = civVoiceMemoryCount,
    this.voiceMemoryCeiling = voiceActivityCeiling,
    Map<String, dynamic> config = const {},
    this._meterInfoKey,
  }) : _config = config,
       _modeWithFilter = config[civModeWithFilterConfigKey] == true,
       _scopeSupported = config[civScopeConfigKey] == true,
       _antennaPorts = (config[civAntennaPortsConfigKey] as num?)?.toInt().clamp(0, 4) ?? 0,
       _bandMaxWatts = civBandMaxWattsFrom(config[civBandMaxWattsConfigKey]),
       _baudRate = serialBaudRateOrNull(config);

  /// See [civModeWithFilterConfigKey].
  final bool _modeWithFilter;

  /// See [civBandMaxWattsConfigKey].
  final List<(int, num)> _bandMaxWatts;

  /// The radio's last reported frequency, which picks the band ceiling.
  @override
  int? _freqHz;

  num get _ratedWatts => civRatedWatts(maxWatts, _bandMaxWatts, _freqHz);

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

  /// Given up for the rest of the session by a radio that refuses or ignores
  /// the read — one without the submode, on an entry (the generic Icom one)
  /// that could not pin it — and from the start where the entry pins it off
  /// ([civDataModeConfigKey]).
  /// Without giving up, a DATA flag taken as set on such a radio would report
  /// DATA-USB for a rig in plain USB for good.
  late final _dataModeSupport = OptionalRead(
    _sink,
    'radio does not answer the DATA submode read (0x1A 0x06); data modes set plain USB',
    onGiveUp: () {
      _dataOn = false;
      _reportMode();
    },
    asked: _config[civDataModeConfigKey] != false,
  );

  late final List<int> _dataModeRead = buildReadDataModeFrame(to: radioAddress, from: controllerAddress);

  void _readDataMode() => _poll(_dataModeRead);

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

  /// The frame on the wire, for the reads a NAK answers as "not on this
  /// radio" — the tuner's shares its command byte with the TX watch, and the
  /// filter width's with the DATA read, so [_awaiting] alone cannot tell
  /// them apart.
  List<int>? _onWire;

  /// Commands the operator asked for, in order and never merged: a band
  /// change restates its frequency after its mode, and a keyer speed is set
  /// and then read back.
  @override
  void _send(List<int> frame) {
    _outbox.add(frame);
    _sendNext();
  }

  /// A question asked on a timer, dropped when the same one is already
  /// waiting: against a radio that answers nothing the polls would otherwise
  /// queue faster than the answer timeout lets them out. Only a read may be
  /// merged, since only a read means the same thing wherever it lands.
  @override
  void _poll(List<int> frame) {
    if (_outbox.any((queued) => listEquals(queued, frame))) return;
    _send(frame);
  }

  /// A stop, ahead of everything waiting, and taking with it the queued
  /// frames of [command] it stops — a CW chunk or a voice play still in the
  /// queue would otherwise key the radio after the operator stopped it. It
  /// still waits for the one exchange on the wire — up to [civAnswerTimeout]
  /// if the radio never answers it. Deliberately: sent over an answer still
  /// coming in, the stop is the frame most likely to be garbled, and a lost
  /// unkey is worse than a late one.
  ///
  /// [droppingSub] narrows that to one sub-command, for a command byte
  /// shared by things a stop must not take with it.
  void _sendFirst(List<int> frame, {required int dropping, int? droppingSub}) {
    _outbox.removeWhere((queued) {
      final drop = queued[4] == dropping && (droppingSub == null || queued[5] == droppingSub);
      if (drop) _rawAnswers.remove(queued)?.call(const []);
      return drop;
    });
    _outbox.addFirst(frame);
    _sendNext();
  }

  /// An extension's raw frames, queued like the driver's own — one on the
  /// wire at a time — each answered by the frame that frees the wire for the
  /// next, or by nothing in [civAnswerTimeout]. Addressed from this session to
  /// its radio whatever the frames say: an answer to any other address is
  /// never heard here, and the extension cannot know these two.
  @override
  int sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    final frames = <List<int>>[];
    var start = 0;
    while (start < bytes.length) {
      final end = bytes.indexOf(civTerminator, start);
      // Preamble, preamble, to, from, command, terminator at the least.
      if (end < start + 5 || bytes[start] != civPreamble || bytes[start + 1] != civPreamble) throw const FormatException('not CI-V frames');
      frames.add([civPreamble, civPreamble, radioAddress, controllerAddress, ...bytes.sublist(start + 4, end + 1)]);
      start = end + 1;
    }
    if (frames.isEmpty) throw const FormatException('no frame');
    for (final frame in frames) {
      if (onAnswer != null) _rawAnswers[frame] = onAnswer;
      _send(frame);
    }
    return frames.length;
  }

  /// Who is waiting for each raw frame's answer, by the frame itself.
  final _rawAnswers = Map<List<int>, void Function(List<int> answer)>.identity();

  void _sendNext() {
    if (_awaiting != null || _outbox.isEmpty) return;
    final frame = _outbox.removeFirst();
    _awaiting = frame[4];
    _onWire = frame;
    _answerTimer = Timer(civAnswerTimeout, _unanswered);
    _sink.send(frame);
  }

  /// Whether [frame] answers the command on the wire. A data answer repeats
  /// its command byte, so one arriving late for a command that timed out
  /// does not free the wire for the next; ACK and NAK name no command and
  /// are taken as the answer to whatever is waiting.
  ///
  /// A sweep is never an answer, though it repeats the scope's command byte:
  /// it streams many times a second, and taking one as the answer to a
  /// scope setting would free the wire for a burst the radio drops.
  bool _answers(CivFrame frame) => frame.isAck || frame.isNak || (frame.command == _awaiting && !_isSweep(frame));

  static bool _isSweep(CivFrame frame) => frame.command == civScopeCommand && frame.data.isNotEmpty && frame.data[0] == civScopeWaveform;

  void _answered() {
    _answerTimer?.cancel();
    _answerTimer = null;
    _awaiting = null;
    _onWire = null;
    _sendNext();
  }

  /// Said once a session: a radio that ignores one of our commands costs a
  /// timeout on every poll, and nothing else would show it.
  void _unanswered() {
    // An extension's frame the radio ignores says nothing about the polls,
    // and must not spend the one diagnostic.
    if (!_warnedUnanswered && !_rawAnswers.containsKey(_onWire)) {
      _warnedUnanswered = true;
      _sink.reportDiagnostic('radio did not answer CI-V command 0x${_awaiting!.toRadixString(16).padLeft(2, '0').toUpperCase()} in time');
    }
    // Silence counts against a read the radio may lack, as a refusal does: a
    // radio that ignores one rather than refusing it — a Xiegu's way — would
    // otherwise hold the wire for a whole answer timeout on every poll, for
    // the whole connection. Not on the air, where a radio may set aside a
    // read it would answer on receive — the FT-891 and Kenwood drivers' rule.
    final silent = _optionalReadFor(_onWire);
    for (final read in _optionalReads) {
      if (read != silent) read.radioWentSilent();
    }
    if (!_telemetry.transmitting) silent?.unanswered();
    _rawAnswers.remove(_onWire)?.call(const []);
    _answered();
  }

  /// The reads a radio may lack — see [OptionalRead].
  late final List<OptionalRead> _optionalReads = [_dataModeSupport, _tunerSupport, _filterWidthSupport, _antennaSupport];

  /// The [OptionalRead] that [frame] asks, if it is one of them.
  OptionalRead? _optionalReadFor(List<int>? frame) {
    if (frame == null) return null;
    if (listEquals(frame, _dataModeRead)) return _dataModeSupport;
    if (listEquals(frame, _tunerRead)) return _tunerSupport;
    if (listEquals(frame, _filterWidthRead)) return _filterWidthSupport;
    if (listEquals(frame, _antennaRead)) return _antennaSupport;
    return null;
  }

  void _requestFrequencyAndMode() {
    _poll(buildReadFrequencyFrame(to: radioAddress, from: controllerAddress));
    // DATA first: the mode answer is reported against the flag as it stands,
    // and a flag read after it would report the base mode alone in between.
    if (_dataModeSupport.available) _readDataMode();
    _poll(buildReadModeFrame(to: radioAddress, from: controllerAddress));
    _poll(buildReadPowerLevelFrame(to: radioAddress, from: controllerAddress));
    _poll(buildReadMeterFrame(to: radioAddress, from: controllerAddress, meterId: civMeterDcInputVoltage));
    // On the state poll, not the TX watch: the tuner moves when someone
    // presses its button, and a tune in progress is already heard as a
    // transmission there.
    if (_tunerSupport.available) _poll(_tunerRead);
    // CI-V announces no width change, so a turn of the radio's own control
    // is heard here.
    _readFilterWidth();
    // The operator's ANT key is heard here too: no guide says 0x12 is
    // announced on transceive.
    if (_antennaSupport.available) _poll(_antennaRead);
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

  bool get _onBattery => _dcInputMeterLevel != null && _dcInputMeterLevel! < civBatteryMeterCeiling;

  /// Watts for a 0.0-1.0 fraction of the radio's rated output, under the
  /// same battery cap [_reportPower] applies to the SET level.
  num _wattsForFraction(double fraction) {
    final ceiling = batteryMaxWatts != null && _onBattery ? math.min(_ratedWatts, batteryMaxWatts!) : _ratedWatts;
    final watts = fraction * ceiling;
    return ceiling <= civPreciseWattsCeiling ? (watts * 10).round() / 10 : watts.round();
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
    final watts = civWattsForLevel(level, _ratedWatts);
    final cap = batteryMaxWatts;
    _sink.reportPower(cap != null && _onBattery ? math.min(watts, cap) : watts);
  }

  @override
  void handleData(Uint8List chunk) {
    for (final frame in _framer.add(chunk)) {
      _handle(frame);
      // The radio was answering when an optional read went silent, so the
      // silence was the read's own. After the frame, not before: a late
      // answer to that very read has cleared it by now.
      if (_heardRadio) {
        _heardRadio = false;
        for (final read in _optionalReads) {
          read.heardFromRadio();
        }
      }
    }
  }

  /// Whether the frame being handled came from the radio — see [handleData].
  bool _heardRadio = false;

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
    _heardRadio = true;
    // What this answers — a NAK names no command, so it is the one on the
    // wire, read before the answer frees it.
    final answering = _awaiting;
    final answeringFrame = _onWire;
    // An answer to us, not a transceive broadcast, is what frees the wire.
    if (frame.to == controllerAddress && _answers(frame)) {
      _rawAnswers.remove(answeringFrame)?.call(buildCivFrame(to: frame.to, from: frame.from, command: frame.command, data: frame.data));
      _answered();
    }

    if (frame.isNak) {
      // The radio refused the command. polo ignored this entirely, so a
      // refusal was indistinguishable from silence and the app went on
      // believing the radio had moved.
      debugPrint('[cat] CI-V: radio rejected the last command');
      // A scope that refuses is a display that would otherwise wait forever.
      if (answering == civScopeCommand && _scopeWanted) _reportScopeProblem(t.settings.station.spectrumScopeRefused);
      // A radio without an internal tuner, the width command or the antenna
      // ports its entry pins refuses the read on every poll, and will for as
      // long as it is connected. The width is only ever asked in a mode with
      // a width table, so a refusal is not the mode's, and never counted on
      // the air — see [_unanswered].
      if (!_telemetry.transmitting) _optionalReadFor(answeringFrame)?.refused();
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
        if (freqHz == null) return;
        _noteFrequency(freqHz);
        // Everything above here speaks kHz.
        _sink.report(VfoReading(freqKHz: freqHz / 1000));

      case CivCommand.transceiveMode:
      case CivCommand.readMode:
        if (frame.data.isEmpty) return;
        // data[0] is the mode; data[1], when present, is the filter — sent
        // back by an entry that must send one with a mode, and by every
        // DATA submode set.
        final filterMoved = frame.data.length > 1 && frame.data[1] != _lastFilter;
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
        final mode = civModeNameForCode(frame.data[0]);
        if (mode == null) return;
        final modeMoved = mode != _baseMode;
        _baseMode = mode;
        _reportMode();
        // Each mode, and each of its filters, keeps a width of its own: the
        // one read before says nothing about this one.
        if (modeMoved || filterMoved) {
          _filterWidthIndex = null;
          _reportPassband();
          _readFilterWidth();
        }
        // A mode announced on its own may have brought its DATA submode with
        // it — a band recall does — and the announcement does not say.
        if (frame.command == CivCommand.transceiveMode && _dataModeSupport.available) _readDataMode();

      case CivCommand.settings:
        if (parseFilterWidthData(frame.data) case final index?) {
          _filterWidthSupport.reset();
          _filterWidthIndex = index;
          _reportPassband();
          return;
        }
        final data = parseDataModeData(frame.data);
        if (data == null) return;
        _dataModeSupport.reset();
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

      case civScopeCommand:
        _handleScope(frame.data);

      case CivCommand.antenna:
        // A port past the pinned count is a reply the entry does not
        // describe, and not a port to offer.
        final reply = parseAntennaData(frame.data);
        if (reply == null || reply.port >= _antennaPorts) return;
        // A radio that answers selects its ports, whatever a NAK taken for
        // this read said before.
        _antennaSupport.reset();
        _antennaPort = reply.port;
        _rxAntenna = reply.rxAntenna;
        _reportAntennas(_antennasFor(reply.port, reply.rxAntenna));

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
        if (parseTunerData(frame.data) case final state?) {
          // A radio that answers has a tuner, whatever a NAK taken for this
          // read said before.
          _tunerSupport.reset();
          _reportTuner(switch (state) {
            civTunerInline => TunerStatus.inline,
            civTunerTuning => TunerStatus.tuning,
            _ => TunerStatus.bypassed,
          });
        }
    }
  }

  /// Sent, not polled: [_poll] drops a read already waiting in the outbox,
  /// and one queued before the tune answers with where the radio was.
  @override
  void readBack() {
    _send(buildReadFrequencyFrame(to: radioAddress, from: controllerAddress));
    if (_dataModeSupport.available) _send(_dataModeRead);
    _send(buildReadModeFrame(to: radioAddress, from: controllerAddress));
  }

  @override
  void setFrequency(double freqKHz) {
    final freqHz = (freqKHz * 1000).round();
    _send(buildSetFrequencyFrame(to: radioAddress, from: controllerAddress, freqHz: freqHz));
    _noteFrequency(freqHz);
  }

  /// Where the radio is tuned, from its report or our own set. Ours counts
  /// at once: the VFO path sends a tune and a power set together, and a set
  /// rated against the band being left would put an IC-9700 on 23 cm at a
  /// tenth of what was asked.
  ///
  /// Across a band ceiling the level last read belongs to the old band — a
  /// radio may keep RF power per band — so it is forgotten and read again
  /// rather than re-rated into a wattage neither band is at.
  void _noteFrequency(int freqHz) {
    final ratedBefore = _ratedWatts;
    _freqHz = freqHz;
    if (_ratedWatts == ratedBefore) return;
    _lastLevel = null;
    _poll(buildReadPowerLevelFrame(to: radioAddress, from: controllerAddress));
  }

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
    if (_dataModeSupport.available && dataModeBases.containsValue(base.toUpperCase())) {
      _send(buildSetDataModeFrame(to: radioAddress, from: controllerAddress, on: dataBase != null, filter: radioFilter));
      // Taken as set: the next mode answer would otherwise be reported
      // against the flag from before, putting the old mode in the log until
      // the DATA read lands. A refused set is corrected by that read.
      _dataOn = dataBase != null;
    }
  }

  @override
  void setPower(num watts) => _send(buildSetPowerLevelFrame(to: radioAddress, from: controllerAddress, level: civLevelForWatts(watts, _ratedWatts)));

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
      // The PTT's own frames only: a tuner set shares the command byte, and
      // one dropped here would leave the tuner where the operator moved it
      // from.
      droppingSub: 0x00,
    );
    _keyedByUs = on;
  }

  /// Given up for the rest of the session by a radio that refuses or ignores
  /// the tuner read — see [civTunerStatus].
  late final _tunerSupport = OptionalRead(
    _sink,
    'radio has no antenna tuner (0x1C 0x01 refused or unanswered); not asked again',
    onGiveUp: () => _reportTuner(null),
  );

  late final List<int> _tunerRead = buildReadTunerFrame(to: radioAddress, from: controllerAddress);

  /// What [_reportTuner] last said, and whether it has said anything —
  /// null is itself an answer ("no tuner"), so it cannot mark "not yet".
  TunerStatus? _tuner;
  bool _tunerReported = false;

  /// Only on a change, like [_noteTransmitting]: the state poll restates the
  /// tuner every few seconds.
  void _reportTuner(TunerStatus? status) {
    if (_tunerReported && status == _tuner) return;
    _tunerReported = true;
    _tuner = status;
    if (_sink case final TunerSink sink) sink.reportTuner(status);
  }

  /// In line or through, then read back: a set is answered with a bare ACK.
  /// Never a tune ([civTunerTuning]) — that transmits; [startTune] is its
  /// own act.
  @override
  void setTuner({required bool inline}) {
    if (!_tunerSupport.available) return;
    _send(buildSetTunerFrame(to: radioAddress, from: controllerAddress, inline: inline));
    _send(_tunerRead);
  }

  @override
  bool get canStartTune => _tunerSupport.available && _tuner != null;

  @override
  void startTune() {
    if (!canStartTune || _telemetry.transmitting || _tuner == TunerStatus.tuning) return;
    _send(buildStartTuneFrame(to: radioAddress, from: controllerAddress));
    _send(_tunerRead);
  }

  /// In line, which on an Icom is also the end of a tune. From the CI-V
  /// manuals, not a capture.
  @override
  void stopTune() => setTuner(inline: true);

  /// Given up for the rest of the session by a radio that refuses or ignores
  /// the width read, and from the start where the entry pins it off
  /// ([civFilterWidthConfigKey]).
  late final _filterWidthSupport = OptionalRead(
    _sink,
    'radio does not read its filter width (0x1A 0x03 refused or unanswered); not asked again',
    onGiveUp: _reportPassband,
    asked: _config[civFilterWidthConfigKey] != false,
  );

  late final List<int> _filterWidthRead = buildReadFilterWidthFrame(to: radioAddress, from: controllerAddress);

  /// What the radio last said its width is, for the mode and filter now in
  /// use; null until it says, again after either moves.
  int? _filterWidthIndex;

  /// What [_reportPassband] last said, and whether it has said anything —
  /// as for the tuner, null is itself an answer.
  Passband? _passband;
  bool _passbandReported = false;

  /// Only where the width means a passband — see [_widthsFor] — so a
  /// refusal is never a mode without one (the radio may NAK the read in FM).
  void _readFilterWidth() {
    if (_filterWidthSupport.available && _widthsFor(_baseMode) != null) _poll(_filterWidthRead);
  }

  /// The width table for [mode], in the modes where the filter's place is
  /// known: CENTRED on the tuned frequency. In CW because an Icom shows a
  /// signal's own frequency on the dial and centres its filter on the CW
  /// pitch that signal is heard at; in AM because the filter takes both
  /// sidebands around the carrier.
  ///
  /// Null in SSB, its DATA submode included: an Icom's SSB filter sits some
  /// offset from the carrier that no CI-V command reports and no guide this
  /// driver is written from states, so a passband drawn there would be a
  /// guess. Null in RTTY, where the filter sits around the mark/space pair
  /// at a placement the guide does not give either, and in FM, WFM and DV,
  /// which have no width table.
  ///
  /// Read with the twin PBT centred: the guide gives its 0x14 0x07/0x08 level
  /// no scale in Hz, so a shifted PBT narrows the real passband unseen.
  static List<int>? _widthsFor(String? mode) => switch (mode) {
    'CW' || 'CW-R' => civFilterWidthsSsbCw,
    'AM' => civFilterWidthsAm,
    _ => null,
  };

  static Passband? _passbandFor(String? mode, int? index) {
    final widths = _widthsFor(mode);
    if (widths == null || index == null || index >= widths.length) return null;
    final half = widths[index] ~/ 2;
    return Passband(-half, half);
  }

  /// Only on a change, like [_reportTuner]: the state poll restates the width
  /// every few seconds.
  void _reportPassband() {
    final passband = _filterWidthSupport.available ? _passbandFor(_baseMode, _filterWidthIndex) : null;
    if (_passbandReported && passband == _passband) return;
    _passbandReported = true;
    _passband = passband;
    if (_sink case final PassbandSink sink) sink.reportPassband(passband);
  }

  /// The nearest width the current mode's table has, then read back: a set
  /// is answered with a bare ACK. The width alone — never the mode, the
  /// filter slot or the PBT — and only in a mode [_passbandFor] can report,
  /// since a set nothing reads back is one nobody sees land.
  @override
  void setPassband(Passband passband) {
    final widths = _widthsFor(_baseMode);
    if (!_filterWidthSupport.available || widths == null) return;
    _send(buildSetFilterWidthFrame(to: radioAddress, from: controllerAddress, index: civFilterWidthIndex(widths, passband.widthHz)));
    _send(_filterWidthRead);
  }

  /// See [civAntennaPortsConfigKey]; 0 when unpinned.
  final int _antennaPorts;

  /// Given up for the rest of the session by a radio that refuses or ignores
  /// the read, and from the start where the entry pins no ports.
  late final _antennaSupport = OptionalRead(
    _sink,
    'radio does not read its antenna selection (0x12 refused or unanswered); not asked again',
    onGiveUp: () => _reportAntennas(null),
    asked: _antennaPorts > 0,
  );

  late final List<int> _antennaRead = buildReadAntennaFrame(to: radioAddress, from: controllerAddress);

  /// What the radio last said: the port in use, and whether receive goes
  /// through [civRxAntennaPort] — null on a radio whose reply has no such
  /// byte. [_antennaPort] stays null until the radio says.
  int? _antennaPort;
  bool? _rxAntenna;

  /// What [_reportAntennas] last said, and whether it has said anything —
  /// as for the tuner, null is itself an answer.
  RadioAntennas? _antennas;
  bool _antennasReported = false;

  /// 'ANT1' to 'ANT4' as the radios label them; a one-port radio's is "ANT".
  late final List<String> _antennaPortNames = _antennaPorts == 1 ? const ['ANT'] : [for (var i = 1; i <= _antennaPorts; i++) 'ANT$i'];

  /// [RadioAntennas.separate] where the radio has receive antenna
  /// connectors: it transmits on the selected port and receives on that port
  /// or on [civRxAntennaPort] — never on another ANT port, so those are the
  /// only two receive choices. Null for a one-port radio without them, which
  /// has nothing to choose.
  RadioAntennas? _antennasFor(int port, bool? rxAntenna) {
    final names = _antennaPortNames;
    final tx = names[port];
    if (rxAntenna == null) return names.length < 2 ? null : RadioAntennas(rxPorts: names, txPorts: names, rx: tx, tx: tx);
    return RadioAntennas(rxPorts: [tx, civRxAntennaPort], txPorts: names, rx: rxAntenna ? civRxAntennaPort : tx, tx: tx, separate: true);
  }

  /// Only on a change, like [_reportTuner]: the state poll restates the
  /// selection every few seconds.
  void _reportAntennas(RadioAntennas? antennas) {
    if (_antennasReported && antennas == _antennas) return;
    _antennasReported = true;
    _antennas = antennas;
    if (_sink case final RadioAntennaSink sink) sink.reportAntennas(antennas);
  }

  /// The port, and where receive goes, then read back: a set is answered
  /// with a bare ACK. Only once the radio has said what it has, and only a
  /// combination it offers — receiving on one ANT port while transmitting on
  /// another is none. On a radio without receive antenna connectors one port
  /// serves both, and either names it.
  @override
  void setAntenna({String? rx, String? tx}) {
    final current = _antennaPort;
    if (!_antennaSupport.available || current == null) return;
    final names = _antennaPortNames;
    final separate = _rxAntenna != null;
    final port = names.indexOf(tx ?? (separate ? null : rx) ?? names[current]);
    if (port < 0) return;
    var rxAntenna = _rxAntenna;
    if (rx != null) {
      if (separate && rx == civRxAntennaPort) {
        rxAntenna = true;
      } else if (rx == names[port]) {
        if (separate) rxAntenna = false;
      } else {
        return;
      }
    }
    _send(buildSetAntennaFrame(to: radioAddress, from: controllerAddress, port: port, rxAntenna: rxAntenna));
    _send(_antennaRead);
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
  final bool _scopeSupported;

  @override
  void teardown() {
    // Straight to the wire, like the unkey below: the outbox is cleared
    // next, and a radio left streaming its scope spends a serial line on
    // sweeps for whoever connects after us.
    if (_scopeWanted) {
      _scopeWanted = false;
      // The output alone: a radio keeps only the last of two frames sent back
      // to back, and the stream matters more than what its screen shows.
      _sink.send(buildScopeOutputFrame(to: radioAddress, from: controllerAddress, on: false));
    }
    if (_keyedByUs) {
      // Straight to the wire, not through the outbox: an unkey that waits
      // for the exchange in flight may not go out at all, and nothing else
      // will unkey this radio.
      _keyedByUs = false;
      _sink.send(buildSetTransmitFrame(to: radioAddress, from: controllerAddress, on: false));
    }
    _answerTimer?.cancel();
    _outbox.clear();
    _rawAnswers.clear();
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

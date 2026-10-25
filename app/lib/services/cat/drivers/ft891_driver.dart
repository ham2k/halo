// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks Yaesu CAT (see yaesu_cat_codec.dart) to an FT-891. Like every
// driver here it deals only in already-framed bytes handed to it by a
// transport — in practice a serial port, since the FT-891 exposes CAT over
// a built-in USB-to-serial bridge and has no network option at all.
//
// Ported from app-polo's Ft891Driver.js, which shipped without ever being
// tested against a radio. This version, unlike polo's, has been
// run against a real FT-891 (4800 baud, over the radio's own CP2105 USB
// bridge — NOT a Digirig, which carries audio and PTT but no CAT at all).
// Both directions are verified on hardware. Reading end to end, including
// the `IF` status packets transceive pushes, whose layout was derived from
// that radio. Writing by clicking a spot in the app and watching the rig
// retune — which exercises the whole chain the design is built around:
// suggestion -> RadioService.setVfo -> CatService._onVfoChanged ->
// setFrequency -> radio (docs/design/cat.md, "A suggestion moves the
// radio").
//
// Not exercised: the mode-only write path on a rig whose mode CAT code we
// have no entry for, which sends nothing by design (buildSetModeCommand
// returns null) — a code path, not a radio behaviour.
//
// Also not exercised: `PC` (RF power). Documented in the CAT manual, but
// added after the bench session above and never sent to or read from the
// radio it describes. The same goes for CW keying (`KM`/`KY`) and the keyer
// speed (`KS`) — from the FTDX10 CAT manual, not from a radio — and for the
// antenna tuner (`AC`), the receive passband (`ID`, `SH`, `IS`, `NA`) and
// the radio's own antenna ports (`AN`), from the CAT manuals alone.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../adaptive_poller.dart';
import '../telemetry_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import '../transports/config_field_helpers.dart';
import 'cw_send_queue.dart';
import 'keyer_config.dart';
import 'meter_calibration.dart';
import 'optional_read.dart';
import 'poll_config.dart';
import 'telemetry_config.dart';
import 'voice_activity_tracker.dart';
import 'yaesu_cat_codec.dart';

/// Belt-and-suspenders resync, same reasoning as the FlexRadio driver's:
/// `AI1;` *should* push a status line whenever the VFO changes, but the CAT
/// manual doesn't spell out the unsolicited format beyond "reports change of
/// status" — so poll as well, in case AI mode misses a case we need or a
/// hiccup drops it silently.

class Ft891Driver extends EquipmentDriver {
  const Ft891Driver();

  /// The FT-891's built-in "USB to Dual UART Bridge" is a Silicon Labs
  /// CP2105 on SiLabs' own default VID/PID (confirmed on hardware via
  /// `ioreg`).
  ///
  /// DEAD ON macOS: libserialport cannot read vendorId or productId there,
  /// which the per-field probing in serial_transport_io.dart makes visible
  /// as a throw per port per field. `description` is NOT dead there, though
  /// — it answers "CP2105 Dual USB to UART Bridge Controller" — so on that
  /// platform a port is recognised by [cp2105CatPort]'s `match` pattern
  /// rather than by these ids. Which matters because the CP2105 is a DUAL
  /// bridge: it presents two ports differing by one trailing digit, one
  /// carrying CAT and one PTT, and choosing wrong looks exactly like a dead
  /// cable.
  static const cp2105VendorId = 0x10C4;
  static const cp2105ProductId = 0xEA70;

  /// CAT is on the CP2105's Enhanced port, the first of its two; the
  /// Standard port carries PTT and keying. A `port` restriction for the
  /// serial transport: where the platform can tell the two apart, the
  /// picker points at the first, and only on a Silicon Labs bridge —
  /// a radio reached through some other adapter's two ports is pointed at
  /// neither, a guess about hardware this definition has never seen being
  /// worse than no guess. Nothing is ever hidden: the Standard port stays
  /// pickable for the operator who wired PTT the other way round.
  ///
  /// Where the platform cannot tell siblings apart — desktop, where the OS
  /// named both ports itself — `suggest` is all that is left: the bridge is
  /// named, so the picker puts it first and says so. Both clauses describe
  /// the same chip, because neither works everywhere: the USB pair is exact but unreadable on macOS, and the
  /// pattern is what carries that platform, where the description reads
  /// back in full. Neither tells the bridge's two ports apart on its own —
  /// what does is the sibling inference in `serial_transport_config.dart`,
  /// which reads macOS' own naming (the device serial with the port index
  /// appended) and lets `index` narrow the suggestion to port 0. Where that
  /// cannot see siblings, both ports are suggested and the notes below are
  /// what says which one.
  static const cp2105CatPort = {
    'index': 0,
    'vendorId': cp2105VendorId,
    'suggest': {
      'usb': [
        {'vendorId': cp2105VendorId, 'productId': cp2105ProductId},
      ],
      'match': [r'CP2105'],
    },
  };

  /// What the radio's CAT menu ships set to. It is also the one polo
  /// hardcoded, which its own notes call out as a silent-failure mode — a
  /// radio set to 38400 answers with garbage and no explanation — so this
  /// is only a default here, not a fixed value.
  static const defaultBaudRate = 4800;

  @override
  String get key => 'ft891';

  @override
  String get name => 'Yaesu FT-891';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(yaesuModeCodes.keys);

  /// The same claim [cp2105CatPort]'s `suggest` clause makes, for a caller
  /// holding the ids rather than a port.
  static bool matchesUsbIds({int? vendorId, int? productId}) => vendorId == cp2105VendorId && productId == cp2105ProductId;

  @override
  bool get canKeyCw => true;

  /// The line keys by default (`KM`/`KY` are documented across it) — an
  /// entry for a rig that does not, or a developer on the generic entry,
  /// says otherwise through [cwKeyerConfigKey].
  @override
  bool canKeyCwWith(Map<String, dynamic> config) => cwKeyerFromConfig(config, fallback: true);

  /// [meterInfoConfigKey] is read on every named entry and never shown as a
  /// field on any of them — which calibration file describes a radio is a
  /// fact about the model, not a setting anyone should be asked for.
  @override
  Set<String> get recognizedConfigKeys => {
    ...super.recognizedConfigKeys,
    cwKeyerConfigKey,
    voiceMemoriesConfigKey,
    voiceCeilingConfigKey,
    meterInfoConfigKey,
    yaesuHeadPowerConfigKey,
    yaesuRelativePowerConfigKey,
    yaesuFrequencyDigitsConfigKey,
    yaesuKeyerMemoryConfigKey,
    yaesuKeyerMemoryCharsConfigKey,
    yaesuKeyerPlayByChannelConfigKey,
  };

  /// Nothing WITHOUT a table: Yaesu answers `RM` with a raw 0-255 and
  /// publishes no scale anywhere, so a radio whose catalogue entry names no
  /// calibration file (the generic Yaesu entry, which does not know which
  /// radio is behind it) has meters that cannot be interpreted — and an
  /// uninterpreted SWR would still be measured against the threshold the
  /// operator is warned at.
  @override
  Set<RadioMeter> get telemetryMeters => const {};

  @override
  Set<RadioMeter> telemetryMetersWith(Map<String, dynamic> config) {
    final calibration = MeterCalibrations.instance[config[meterInfoConfigKey] as String?];
    if (calibration == null) return const {};
    return {
      for (final entry in _metersByTable.entries)
        if (calibration.has(entry.key)) entry.value,
    };
  }

  @override
  int get telemetryWatchBytes => yaesuTxWatchBytes;

  /// The watch plus every meter a capture reads — the ceiling, for the base
  /// class's own default. What a given NODE spends is
  /// [_cycleBytesFor], which counts only the meters it will actually ask
  /// for.
  @override
  int get telemetryCycleBytes => yaesuTxWatchBytes + yaesuCaptureMeters.length * yaesuMeterReadBytes;

  /// The meter numbers a node will ask for on each transmit cycle.
  ///
  /// A CAPTURE asks for all of them — its whole purpose is the numbers
  /// nothing can interpret yet. Otherwise only the meters the radio's table
  /// describes: asking for one it does not is a read the radio answers with
  /// nothing (an FT-891 has no Vdd meter at all), and it would reserve a
  /// slot on the strip that can never fill.
  static List<int> meterNumbersFor(MeterCalibration? calibration, {required bool capturing}) {
    if (capturing) return yaesuCaptureMeters;
    if (calibration == null) return const [];
    return [
      for (final meter in yaesuCaptureMeters)
        if (_tablesByMeterNumber[meter] case final table? when calibration.has(table)) meter,
    ];
  }

  int _cycleBytesFor(Map<String, dynamic> config) =>
      yaesuTxWatchBytes + meterNumbersFor(calibrationFor(config), capturing: config[yaesuMeterCaptureConfigKey] == true).length * yaesuMeterReadBytes;

  /// Per NODE, unlike the base rule, because the capture is per node: with
  /// it off — which is every radio but a developer's — a transmitting Yaesu
  /// asks exactly one question, and showing the placeholder the capture's
  /// slower cadence would tell an operator their link cannot carry
  /// something it is not being asked to.
  @override
  Duration defaultTelemetryInterval(Map<String, dynamic> config) => telemetryIntervalFor(
    const {},
    // The SAME question the session asks itself (`_readsMeters`): is
    // there anything to read the meters for — a table to convert them
    // with, or a capture building one? Keyed on the capture alone this
    // showed 200 to every named Yaesu, all of which have a table, while
    // the session ran at 459 ms — so an operator typing the number they
    // were shown had it silently clamped.
    cycleBytes: _cycleBytesFor(config),
    baudRate: serialBaudRateOrNull(config),
  );

  /// The keyer facts, asked only where the entry did not pin them — the
  /// generic Yaesu — and only of a developer (docs/design/cat.md § Voice
  /// keying).
  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    ...keyerConfigElements(overrides),
    // Developer mode only, and off by default: it puts three extra reads
    // on the wire for every transmission and shows a line of raw numbers
    // nobody but a developer can use. It exists to BUILD the scale that
    // will make them meters (yaesu_cat_codec.dart), not to be a feature.
    {
      'type': 'field',
      'fieldType': 'checkbox',
      'key': yaesuMeterCaptureConfigKey,
      'label': t.settings.station.yaesuMeterCapture,
      'description': t.settings.station.yaesuMeterCaptureDescription,
      'devMode': true,
    },
    telemetryConfigElement(),
    pollConfigElement(),
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => switch (key) {
    voiceMemoriesConfigKey => validateVoiceMemories(value),
    telemetryIntervalConfigKey => validateTelemetryInterval(value),
    pollIntervalConfigKey => validatePollInterval(value),
    _ => null,
  };

  @override
  int voiceMemoryCountWith(Map<String, dynamic> config) => voiceMemoriesFromConfig(config, fallback: 0).clamp(0, yaesuVoiceMemoryCount);

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => Ft891Session(
    sink,
    // Absent means NONE — see the Icom driver's createSession.
    voiceMemories: voiceMemoriesFromConfig(config, fallback: 0).clamp(0, yaesuVoiceMemoryCount),
    voiceMemoryCeiling: voiceCeilingFromConfig(config),
    config: config,
  );
}

/// `TX;` out and `TX0;` back — the whole of a Yaesu's telemetry until its
/// meter scales have met a bench.
const yaesuTxWatchBytes = 7;

/// `RM5;` out and `RM5123;` back.
const yaesuMeterReadBytes = 12;

/// Which meter number carries which reading, and which calibration table
/// turns it into something an operator can read. One map, so the poll, the
/// parse and the "what can this radio show" question cannot disagree.
const _metersByTable = <MeterTable, RadioMeter>{
  MeterTable.power: RadioMeter.powerOut,
  MeterTable.swr: RadioMeter.swr,
  MeterTable.alc: RadioMeter.alc,
  MeterTable.voltage: RadioMeter.supplyVolts,
};

const _tablesByMeterNumber = <int, MeterTable>{
  yaesuMeterPowerOut: MeterTable.power,
  yaesuMeterSwr: MeterTable.swr,
  yaesuMeterAlc: MeterTable.alc,
  yaesuMeterVdd: MeterTable.voltage,
};

/// The config key for the bench capture — see this driver's config field.
const yaesuMeterCaptureConfigKey = 'yaesuMeterCapture';

/// Pinned by an entry whose `PC` names the unit it drives — the FTX-1's
/// (see [parseHeadPowerParams]). Never a field: which form a radio speaks is
/// a fact about the model.
const yaesuHeadPowerConfigKey = 'yaesuHeadPower';

/// Pinned by an entry whose `PC` is a 0-255 level of the rated output rather
/// than watts — the FT-2000's and FTDX5000's (see [yaesuRatedWattsById]).
/// Never a field, for the same reason as [yaesuHeadPowerConfigKey].
const yaesuRelativePowerConfigKey = 'yaesuRelativePower';

/// Pinned by an entry whose `FA` and `IF` carry eight digits of Hz rather
/// than the line's nine — the FT-450's and the generation before the FT-891
/// (see [yaesuFrequencyDigits]). Never a field, for the same reason as
/// [yaesuHeadPowerConfigKey].
const yaesuFrequencyDigitsConfigKey = 'yaesuFrequencyDigits';

/// Pinned by an entry whose radio has fewer than five text memories — the
/// FT-450's three. Names the memory the app writes and plays CW through
/// (see [yaesuAppKeyerMemory]). Never a field: how many memories a radio
/// has is a fact about the model.
const yaesuKeyerMemoryConfigKey = 'yaesuKeyerMemory';

/// Pinned by an entry whose text memories hold fewer than fifty characters
/// — the FT-450's forty. What a message is cut into; a longer write is
/// refused or truncated by the radio, and nothing says which.
const yaesuKeyerMemoryCharsConfigKey = 'yaesuKeyerMemoryChars';

/// Pinned by an entry whose `KY` names the memory kind before the channel —
/// the FT-710's (see [buildPlayKeyerMemoryByChannelCommand]).
const yaesuKeyerPlayByChannelConfigKey = 'yaesuKeyerPlayByChannel';

/// How many state polls go by between reads of the tuner: at the default
/// idle poll, one every fifteen seconds. The tuner moves when someone presses
/// a button, and a read on every poll would spend a 4800-baud link's time on
/// an answer that is almost always the last one again.
const yaesuTunerReadEvery = 5;

/// How many state polls go by between reads of the receive filter — the same
/// reasoning as [yaesuTunerReadEvery]: it moves when someone turns a knob,
/// and a mode change or a set reads it at once anyway.
const yaesuPassbandReadEvery = 5;

/// How many state polls go by between reads of the radio's antenna port —
/// the same reasoning as [yaesuTunerReadEvery]. Auto-Information pushes `AN`
/// as well, so the read only covers a radio with it off.
const yaesuAntennaReadEvery = 5;

/// Where an SSB passband is centred, in Hz from the carrier on the
/// sideband's side, with no IF shift. A convention, not a radio fact: no
/// Yaesu CAT manual says where `SH`'s width sits, only how wide it is. The
/// IF shift moves it from here.
const yaesuSsbPassbandCentreHz = 1500;

class Ft891Session
    implements TransceiverSession, CwKeyerSession, VoiceKeyerSession, PttSession, AntennaTunerSession, PassbandSession, RadioAntennaSession, RawCommandSession {
  final EquipmentSink _sink;
  final _framer = AsciiCatFramer();

  /// Transceive (`AI1;`) is the primary path — this only covers the cases it
  /// can't: the radio's AI menu switched off, or a frame lost to line noise.
  /// It stays silent for as long as the radio keeps talking. See
  /// adaptive_poller.dart for the wire measurements behind the intervals.
  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestFrequencyAndMode, slow: idlePollIntervalFor(_config));

  /// What was last reported upward, so a repeat can be told from a move.
  VfoReading? _lastReported;

  /// What the radio last said its keyer runs at — the pace [_cwQueue]
  /// spaces chunks by.
  int? _keyerSpeed;

  /// Write-then-play through [_keyerMemory] — see yaesu_cat_codec.dart on
  /// why there is no plainer way.
  late final _cwQueue = CwSendQueue(
    maxChunkLength: _keyerMemoryChars,
    send: (chunk) {
      _send(buildWriteKeyerMemoryCommand(_keyerMemory, chunk));
      _send(_keyerPlayByChannel ? buildPlayKeyerMemoryByChannelCommand(_keyerMemory) : buildPlayKeyerMemoryCommand(_keyerMemory));
    },
    speedWpm: () => _keyerSpeed,
    onProgress: _sink.reportCwProgress,
  );

  /// `PB0;` answers which memory is playing, and a playback ends on a 0 —
  /// see voice_activity_tracker.dart.
  ///
  /// A RECORDING is not polled, and `LM` answers are ignored: the FT-891
  /// answers `LM0;` with `LM00;` WHILE its front panel blinks REC, so the
  /// read cannot tell a recording from an idle radio. Trusted, it reads as a
  /// recording that never started, and the stop that follows is what ends
  /// the operator's recording two seconds in. The ceiling
  /// ([voiceMemoryCeiling]) and the operator's own stop are what end a
  /// recording here — which costs nothing the poll was giving, since a
  /// recording never ends by itself anyway.
  late final VoiceActivityTracker _voice = VoiceActivityTracker(
    report: _reportVoice,
    stop: stopVoice,
    ceiling: () => voiceMemoryCeiling,
    onCeiling: (limit) => _sink.reportDiagnostic('voice memory stopped at the ${limit.inSeconds} s ceiling'),
    // Two questions a second while the app holds the radio in transmit for a
    // memory, because the line answers them differently and neither radio
    // answers both:
    //
    //   `TX;`  — the FT-891 comes out of transmit by itself when the memory
    //            ends, and says so (it pushes `TX0;` unprompted as well).
    //            The FTDX10 answers `1` until something unkeys it.
    //   `PB0;` — the FTDX10's own answer for which memory is playing. The
    //            FT-891 answers `00` from the first poll while the audio is
    //            plainly going out, which is why an "idle" answer is only
    //            believed AFTER one that said a memory was playing
    //            ([_playbackConfirmed]). Unconfirmed, it is ignored
    //            entirely — believing it once cut every message short at two
    //            seconds.
    //
    // A recording is neither keyed nor polled: `LM0;` lies the same way, and
    // there is nothing to unkey.
    poll: () {
      if (_voice.activity?.recording ?? true) return;
      _send(buildReadTransmitStatusCommand());
      _send(buildReadVoicePlaybackCommand());
    },
  );

  /// See [voiceMemoriesConfigKey]: what the entry pinned, at most the
  /// line's five.
  final int _voiceMemories;

  @override
  final Duration voiceMemoryCeiling;

  Ft891Session(
    this._sink, {
    this._voiceMemories = yaesuVoiceMemoryCount,
    this.voiceMemoryCeiling = voiceActivityCeiling,
    Map<String, dynamic> config = const {},
  }) : _config = config,
       _captureMeters = config[yaesuMeterCaptureConfigKey] == true,
       _headPower = config[yaesuHeadPowerConfigKey] == true,
       _relativePower = config[yaesuRelativePowerConfigKey] == true,
       _frequencyDigits = config[yaesuFrequencyDigitsConfigKey] as int? ?? yaesuFrequencyDigits,
       _keyerMemory = config[yaesuKeyerMemoryConfigKey] as int? ?? yaesuAppKeyerMemory,
       _keyerMemoryChars = config[yaesuKeyerMemoryCharsConfigKey] as int? ?? yaesuKeyerMemoryMaxChars,
       _keyerPlayByChannel = config[yaesuKeyerPlayByChannelConfigKey] == true,
       _meterInfoKey = config[meterInfoConfigKey] as String?;

  /// See [yaesuFrequencyDigitsConfigKey].
  final int _frequencyDigits;

  /// See [yaesuKeyerMemoryConfigKey].
  final int _keyerMemory;

  /// See [yaesuKeyerMemoryCharsConfigKey].
  final int _keyerMemoryChars;

  /// See [yaesuKeyerPlayByChannelConfigKey].
  final bool _keyerPlayByChannel;

  /// See [yaesuHeadPowerConfigKey].
  final bool _headPower;

  /// The unit the radio's last `PC` answer named, or [_plainPowerForm] for
  /// a radio that answered in the FT-891's form after all. A set cannot be
  /// built without it — the same watts mean a different command on each
  /// unit — so one asked for before the first answer waits in
  /// [_pendingPower] rather than being dropped: [CatService] records a set
  /// as delivered and would not send the same value again.
  int? _powerHead;
  bool _powerAnswered = false;
  bool _warnedPowerForm = false;
  num? _pendingPower;
  static const _plainPowerForm = 0;

  /// See [yaesuRelativePowerConfigKey].
  final bool _relativePower;

  /// What [_relativePower]'s level is a fraction of, from the radio's `ID`
  /// answer; null until it answers, or for an ID [yaesuRatedWattsById] does
  /// not know — power is then neither read nor set. A set asked for before
  /// the answer waits in [_pendingPower], and the last level read waits in
  /// [_relativePowerLevel], for the same reason as [_powerHead].
  int? _ratedWatts;
  String? _relativePowerLevel;

  /// Polls that have asked `ID` again without an answer. At
  /// [optionalReadSilences] the session stops asking, drops any held set,
  /// and says so: a radio that refuses `ID` — an FTDX3000 on the FTDX5000's
  /// entry — would otherwise park every power read and set for the session
  /// while the app shows the operator's pick as if it had been obeyed.
  int _ratingAsks = 0;
  bool get _ratingGivenUp => _ratingAsks > optionalReadSilences;

  void _warnPowerForm(String note) {
    if (_warnedPowerForm) return;
    _warnedPowerForm = true;
    debugPrint('[cat] yaesu: $note');
  }

  /// The node's merged config, kept for [_telemetry]'s cadence — a `late
  /// final` field cannot be initialised from another field.
  // ignore: prefer_initializing_formals
  final Map<String, dynamic> _config;

  /// Whether to read the meters and print what they answer RAW — the bench
  /// switch that builds a calibration in the first place. Independent of
  /// [_meterInfoKey]: a developer measuring a radio that already has a table
  /// is exactly how a wrong table gets found.
  final bool _captureMeters;

  /// Which calibration file this node's catalogue entry names, if any — see
  /// [meterInfoConfigKey]. Looked up on every reading rather than resolved
  /// once, so a session built before the tables finished loading starts
  /// converting the moment they land.
  final String? _meterInfoKey;

  MeterCalibration? get _calibration => MeterCalibrations.instance[_meterInfoKey];

  /// The last raw reading from each meter, by its own number. Kept ACROSS
  /// the unkey rather than cleared with it: the numbers are read off the
  /// screen by a person, and a line that blanked the instant the operator
  /// let go of the key would be unreadable by the only thing that can use
  /// it.
  final _rawMeters = <int, int>{};

  /// Watches for the operator to key the rig.
  ///
  /// ONLY the watch: the Yaesu meter reads (`RM`) answer a raw 0-255 with no
  /// published scale behind it, so a number taken from one would be
  /// invented — and an invented SWR is measured against a threshold that
  /// warns the operator. The meters wait for a bench session against the
  /// FT-891 and FTDX10 this driver was verified on; the TX state does not,
  /// because `TX;` answers a documented three-way and nothing has to be
  /// converted.
  ///
  /// Both cadences are the same: with no meters to read, transmitting costs
  /// exactly what receiving does.
  late final TelemetryPoller _telemetry = TelemetryPoller(
    onPoll: _pollTelemetry,
    idleInterval: telemetryIntervalFor(_config, cycleBytes: _txWatchBytes, baudRate: serialBaudRateOrNull(_config)),
    txInterval: telemetryIntervalFor(
      _config,
      cycleBytes: _txWatchBytes + Ft891Driver.meterNumbersFor(_calibration, capturing: _captureMeters).length * yaesuMeterReadBytes,
      baudRate: serialBaudRateOrNull(_config),
    ),
  );

  /// One turn of the telemetry cadence: is the rig keyed, and — while it is,
  /// and only with the capture switched on — what do its meters answer?
  ///
  /// Nothing is converted. Yaesu publishes no scale for these, so the raw
  /// 0-255 goes to the developer diagnostic and to the console and no
  /// further: an invented curve would reach the operator as an SWR they were
  /// warned about, which is the one place a guess must not end up.
  void _pollTelemetry(bool transmitting) {
    _send(buildReadTransmitStatusCommand());
    if (!transmitting) return;
    // Resolved per poll, not once: the tables load asynchronously, so a
    // session that came up first starts asking the moment they land.
    for (final meter in Ft891Driver.meterNumbersFor(_calibration, capturing: _captureMeters)) {
      _send(buildReadMeterCommand(meter));
    }
  }

  void _handleMeterReading(int meter, int level) {
    final table = _tablesByMeterNumber[meter];
    final reading = table == null ? null : _calibration?.convert(table, level);
    if (reading != null) {
      // Only what the table describes: a file with no ALC rows leaves the
      // ALC meter unreported, which is what keeps the panel from reserving
      // a slot that never fills.
      _sink.reportMeter(_metersByTable[table]!, reading);
    }
    if (!_captureMeters) return;
    _rawMeters[meter] = level;
    final note = 'RM ${[for (final entry in _rawMeters.entries) '${entry.key}=${entry.value}'].join(' ')}';
    _sink.reportDiagnostic(note);
    // Also on the console, which is where a capture is actually READ from:
    // the diagnostic line is one row in a dialog and holds only the latest
    // values, while a transmission's worth of them is a series.
    debugPrint('[cat] yaesu meters $note');
  }

  /// `TX;` out and `TX0;` back.
  static const _txWatchBytes = yaesuTxWatchBytes;

  /// The cadence the poller has settled on — for tests, which otherwise
  /// could only infer it from timing.
  Duration get pollInterval => _poller.interval;

  void _send(String command) => _sink.send(ascii.encode(command));

  /// An extension's raw commands, written as given: every answer names the
  /// command it answers, so none is taken for another's.
  @override
  int? sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    _rawGrace.sent();
    _sink.send(bytes);
    return null;
  }

  final _rawGrace = RawRefusalGrace();

  /// State polls left before the next tuner read — see [yaesuTunerReadEvery].
  int _pollsUntilTunerRead = 0;

  /// `AC;`, judged by the [yaesuRefusal]s heard while it is out. Given up,
  /// nothing about the tuner is asked or set again for this session.
  late final _tunerRead = OptionalRead(
    _sink,
    'radio refuses AC; no antenna tuner, not asked again',
    onGiveUp: () {
      if (_sink case final TunerSink sink) sink.reportTuner(null);
    },
  );

  /// What the radio last said its tuner is doing.
  TunerStatus? _tuner;

  /// A tune [startTune] sent, until the radio next ends a transmission: its
  /// tuner is read on every poll and on the air, like one already showing as
  /// a tune. Without it, a read-back answered before the tune began leaves
  /// the tuner `inline`, and no read goes out again until the tune is over.
  bool _tuneStarted = false;

  /// Asks for the tuner, unless the reads so far say the radio has none —
  /// decided here, at the next ask, because the answer to the last one has
  /// had a whole poll to arrive by now.
  void _readTuner() {
    // Never while transmitting, but for a tune's own outcome: see [_readPassband].
    if (_telemetry.transmitting && _tuner != TunerStatus.tuning && !_tuneStarted) return;
    if (!_tunerRead.judge()) return;
    _tunerRead.sent();
    _send(buildReadTunerCommand());
  }

  /// The radio's filter tables, chosen by its `ID` answer; null until it
  /// answers, and for a radio with no profile — which is never asked `SH`.
  YaesuWidthProfile? _widthProfile;

  /// State polls left before the next passband read — see
  /// [yaesuPassbandReadEvery].
  int _pollsUntilPassbandRead = 0;

  /// The same bookkeeping as the tuner's, for `SH0;`.
  late final _passbandRead = OptionalRead(_sink, 'radio refuses its filter reads; passband not asked again', onGiveUp: () => _reportPassband(null));

  /// What `IS` and `NA` last answered: read with every `SH0;`, and ahead of
  /// it, so the width that answer carries is placed with them.
  int? _shiftHz;
  bool? _narrowOn;

  /// What was last reported, so a repeat is not reported again.
  Passband? _passband;

  void _reportPassband(Passband? passband) {
    if (passband == _passband) return;
    _passband = passband;
    if (_sink case final PassbandSink sink) sink.reportPassband(passband);
  }

  /// Reads the filter, in a mode it can be placed in, on a radio with a
  /// profile — and not while the DVS is busy, for the same reason as the
  /// state poll.
  void _readPassband() {
    final profile = _widthProfile;
    // Never while transmitting: a refusal on the air would count against the read.
    if (profile == null || _voice.active || _telemetry.transmitting) return;
    if (yaesuWidthGroupFor(_lastReported?.mode) == null) return;
    if (!_passbandRead.judge()) return;
    _passbandRead.sent();
    if (profile.readsNarrow) _send(buildReadNarrowCommand());
    _send(buildReadShiftCommand());
    _send(buildReadWidthCommand());
  }

  /// The radio's filter as a [Passband], from an `SH` index.
  ///
  /// Null where it cannot be placed: a mode outside [yaesuWidthGroupFor], an
  /// index the table has no width for, an IF shift not yet read — and a
  /// shift at all in LSB or CW-R. Which way a Yaesu's `+` moves the
  /// passband there, in pitch or in frequency, is in no CAT manual; in USB
  /// and CW the two are the same way, so the shift is placed there.
  ///
  /// CW is centred on the reported frequency, as [Passband] has it.
  Passband? _passbandFor(int index) {
    final mode = _lastReported?.mode;
    final group = yaesuWidthGroupFor(mode);
    final shift = _shiftHz;
    if (group == null || shift == null) return null;
    final width = _widthProfile!.table(group).widthHz(index, narrowOn: _narrowOn);
    if (width == null) return null;
    final reversed = mode == 'LSB' || mode == 'CW-R';
    if (reversed && shift != 0) return null;
    final low = (group == YaesuWidthGroup.ssb ? yaesuSsbPassbandCentreHz : 0) + shift - width ~/ 2;
    return reversed ? Passband(-(low + width), -low) : Passband(low, low + width);
  }

  /// Whether the radio has answered `ID` — once, as the radio on the line
  /// does not change under a connection.
  bool _identified = false;

  /// The radio's selectable antenna ports, chosen by its `ID` answer; null
  /// until it answers, and for a radio with none — which is never asked `AN`.
  List<String>? _antennaPorts;

  /// State polls left before the next antenna read — see
  /// [yaesuAntennaReadEvery].
  int _pollsUntilAntennaRead = 0;

  /// The same bookkeeping as the tuner's, for `AN0;`.
  late final _antennaRead = OptionalRead(_sink, 'radio refuses AN; antenna ports not asked again', onGiveUp: () => _reportAntennas(null));

  /// What was last reported, so a repeat is not reported again.
  RadioAntennas? _antennas;

  void _reportAntennas(RadioAntennas? antennas) {
    if (antennas == _antennas) return;
    _antennas = antennas;
    if (_sink case final RadioAntennaSink sink) sink.reportAntennas(antennas);
  }

  /// Asks for the MAIN band's antenna on a radio with ports to choose from,
  /// unless the reads so far say it has no `AN` after all.
  void _readAntenna() {
    // Never while transmitting — [_readPassband]'s reason.
    if (_antennaPorts == null || _telemetry.transmitting) return;
    if (!_antennaRead.judge()) return;
    _antennaRead.sent();
    _send(buildReadAntennaCommand());
  }

  void _requestFrequencyAndMode() {
    // Not while the DVS is busy. A recording on the FT-891 ENDS at the next
    // read — three seconds in, at this poller's own interval — so the reads
    // that keep the VFO fresh are what cut a message short. Nothing is lost
    // by holding them: Auto-Information pushes a dial turn anyway, and a
    // memory lasts seconds.
    if (_voice.active) return;
    _send(buildReadFrequencyCommand());
    _send(buildReadModeCommand());
    // Documented (PC, see yaesu_cat_codec.dart) but NOT part of the bench
    // verification this driver's freq/mode path has — see the file header.
    // A relative `PC` cannot be read or set without the rating `ID` names,
    // so a lost first answer is asked again rather than leaving power dead
    // for the session.
    if (_relativePower && !_identified && !_ratingGivenUp) _askRating();
    _send(buildReadPowerCommand());
    // On every poll while a tune runs, so its outcome shows when it lands
    // rather than a whole tuner interval later.
    if (_pollsUntilTunerRead > 0 && _tuner != TunerStatus.tuning && !_tuneStarted) {
      _pollsUntilTunerRead--;
    } else {
      _pollsUntilTunerRead = yaesuTunerReadEvery - 1;
      _readTuner();
    }
    if (_pollsUntilPassbandRead > 0) {
      _pollsUntilPassbandRead--;
    } else {
      _pollsUntilPassbandRead = yaesuPassbandReadEvery - 1;
      _readPassband();
    }
    if (_pollsUntilAntennaRead > 0) {
      _pollsUntilAntennaRead--;
    } else {
      _pollsUntilAntennaRead = yaesuAntennaReadEvery - 1;
      _readAntenna();
    }
  }

  /// Reports upward, and tells the poller whether the radio is moving.
  void _report(VfoReading reading) {
    final merged = VfoReading(freqKHz: reading.freqKHz ?? _lastReported?.freqKHz, mode: reading.mode ?? _lastReported?.mode);
    // The FIRST reading is not the radio moving — it is the answer to the
    // question startUpdates just asked. Treating it as movement would drop
    // every connection into 200ms polling for the second or so it takes to
    // ramp back, for a radio nobody is touching.
    final first = _lastReported == null;
    final modeChanged = merged.mode != _lastReported?.mode;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
    // A filter is the mode's: the width and shift the radio had for the
    // last one say nothing about this one.
    if (modeChanged && merged.mode != null) {
      if (yaesuWidthGroupFor(merged.mode) == null) {
        _reportPassband(null);
      } else {
        _readPassband();
      }
    }
  }

  @override
  void handleData(Uint8List chunk) {
    // Anything at all defers the next poll — the radio has just told us
    // something, so asking now would repeat a question we have the answer
    // to. A spun dial with transceive on keeps this resetting, and we poll
    // zero times through the whole turn.
    // Yaesu CAT is ASCII, not binary like CI-V. `allowInvalid` because a
    // line-noise byte on a serial link must not throw out of a stream
    // callback — the framer will simply not match it as a command.
    final text = ascii.decode(chunk, allowInvalid: true);
    // Before the commands it arrived with: an `AC` answer in the same chunk
    // clears it again, which is right whichever came first — the tuner was
    // answered, so the refusal was of something else.
    // Not on the air: a radio may refuse commands it will not handle while
    // transmitting, and a long over would otherwise end these reads for the
    // connection.
    final refused = !_telemetry.transmitting && !_rawGrace.active && text.contains(yaesuRefusal);
    if (refused) {
      _tunerRead.heardRefusal();
      _passbandRead.heardRefusal();
      _antennaRead.heardRefusal();
    }
    for (final command in _framer.add(text)) {
      _handle(command);
    }
  }

  void _handle(AsciiCatCommand command) {
    // The state poll is deferred by what the RADIO volunteers, never by an
    // answer to a question of our own — and the TX watch asks one several
    // times a second. Counting those as "the radio just told us something"
    // re-arms the poll timer before it can ever fire, leaving the frequency
    // to arrive only on AdaptivePoller's 9-second staleness ceiling: a
    // dial turn taking nine seconds to reach the app, on the very radios
    // (AI off) where the poll is the only source there is.
    if (command.command != 'TX' && command.command != 'RM') _poller.noteData();

    switch (command.command) {
      case 'FA':
        final freqHz = parseFrequencyParams(command.params, digits: _frequencyDigits);
        // The radio reports exact Hz; everything above here speaks kHz.
        if (freqHz != null) _report(VfoReading(freqKHz: freqHz / 1000));
      case 'MD':
        final mode = parseModeParams(command.params);
        if (mode != null) _report(VfoReading(mode: mode));

      case 'PC' when _headPower:
        final reading = parseHeadPowerParams(command.params);
        final plain = reading == null ? parsePowerParams(command.params) : null;
        _powerAnswered = true;
        if (reading != null) {
          _powerHead = reading.head;
        } else if (plain != null) {
          _powerHead = _plainPowerForm;
          _warnPowerForm('PC answered in the FT-891 form ("${command.params}"); using that form');
        } else {
          _warnPowerForm('PC answer "${command.params}" is in no known form; power is neither read nor set');
        }
        if (_pendingPower case final watts?) {
          _pendingPower = null;
          setPower(watts);
          // This answer is the level being replaced: reporting it would put
          // the operator's pick back on screen until the next poll.
          return;
        }
        if (reading?.watts ?? plain case final watts?) _sink.reportPower(watts);

      case 'PC' when _relativePower:
        final rated = _ratedWatts;
        if (rated == null) {
          _relativePowerLevel = command.params;
          return;
        }
        final watts = parseRelativePowerParams(command.params, rated);
        if (watts != null) _sink.reportPower(watts);

      case 'PC':
        final watts = parsePowerParams(command.params);
        if (watts != null) _sink.reportPower(watts);

      case 'RM':
        // Only when this session asked: an unsolicited `RM` on a shared line
        // belongs to whatever else is talking to the radio, and reading it
        // would report a meter for a question we never posed.
        if (!_captureMeters && _calibration == null) return;
        final reading = parseMeterParams(command.params);
        if (reading != null) _handleMeterReading(reading.meter, reading.level);

      case 'TX':
        final transmitting = parseTransmitStatusParams(command.params);
        if (transmitting != null && _telemetry.noteTransmitting(transmitting)) {
          if (!transmitting) _tuneStarted = false;
          _sink.reportTransmitting(transmitting);
        }
        // The same answer is a playing memory's clock — see
        // [_handleVoiceTransmit]. ONE case, because Dart takes the first
        // match: a second `case 'TX'` further down is unreachable, and the
        // memory it was meant to end would play to the ceiling instead.
        _handleVoiceTransmit(command.params);

      case 'AC':
        // Only while this session still asks: after it has given up, an `AC`
        // on the line is another program's question being answered.
        if (!_tunerRead.available) return;
        final status = switch (parseTunerParams(command.params)) {
          0 => TunerStatus.bypassed,
          1 => TunerStatus.inline,
          2 => TunerStatus.tuning,
          _ => null,
        };
        if (status == null) return;
        _tunerRead.reset();
        _tuner = status;
        if (_sink case final TunerSink sink) sink.reportTuner(status);

      case 'ID':
        if (_identified) return;
        final id = parseIdParams(command.params);
        if (id == null) return;
        _identified = true;
        if (_relativePower) _noteRatedWatts(yaesuRatedWattsById[id], id);
        _widthProfile = yaesuWidthProfilesById[id];
        _antennaPorts = yaesuAntennaPortsById[id];
        _readPassband();
        _readAntenna();

      // Only on a radio with ports, and only while this session still asks —
      // the same reasoning as `AC`. A port the radio names but [_antennaPorts]
      // leaves out (ANT3, see yaesuAntennaPortsById) is reported as unknown
      // rather than as one of the others.
      case 'AN' when _antennaPorts != null && _antennaRead.available:
        final port = parseAntennaParams(command.params);
        if (port == null) return;
        _antennaRead.reset();
        final ports = _antennaPorts!;
        final name = port <= ports.length ? ports[port - 1] : null;
        _reportAntennas(RadioAntennas(rxPorts: ports, txPorts: ports, rx: name, tx: name));

      // Only on a radio with a profile, and only while this session still
      // asks — after it has given up, these are another program's answers.
      case 'NA' when _widthProfile != null && _passbandRead.available:
        _narrowOn = parseNarrowParams(command.params) ?? _narrowOn;
      case 'IS' when _widthProfile != null && _passbandRead.available:
        _shiftHz = parseShiftParams(command.params, _widthProfile!) ?? _shiftHz;
      case 'SH' when _widthProfile != null && _passbandRead.available:
        final index = parseWidthParams(command.params, _widthProfile!);
        if (index == null) return;
        _passbandRead.reset();
        _reportPassband(_passbandFor(index));

      case 'KS':
        final wpm = parseKeyerSpeedParams(command.params);
        if (wpm != null) {
          _keyerSpeed = wpm;
          _sink.reportKeyerSpeed(wpm);
        }

      // The memory playing, on a radio that answers honestly — see [_voice].
      case 'PB':
        if (_voice.activity?.recording ?? true) return;
        final channel = parseVoiceChannelParams(command.params);
        if (channel == null) return;
        if (channel != 0) {
          _playbackConfirmed = true;
          _voice.confirm();
          return;
        }
        // Ends, and the report on the way out is what unkeys the radio: this
        // radio did not unkey itself, which is the whole reason the DVS is
        // asked at all.
        if (_playbackConfirmed) _voice.end();

      // What Auto-Information actually pushes. One packet carries both the
      // frequency and the mode, so a dial turn reaches the app immediately
      // instead of waiting out the poll.
      case 'IF':
        final info = parseInformationParams(command.params, digits: _frequencyDigits);
        if (info == null) return;
        if (info.freqHz != null || info.mode != null) {
          _report(VfoReading(freqKHz: info.freqHz == null ? null : info.freqHz! / 1000, mode: info.mode));
        }
    }
    // Every other command is an acknowledgement or something we don't
    // track; ignoring them is what lets AI mode be noisy without harm.
  }

  @override
  void setFrequency(double freqKHz) => _send(buildSetFrequencyCommand((freqKHz * 1000).round(), digits: _frequencyDigits));

  @override
  void setMode(String mode) {
    final command = buildSetModeCommand(mode);
    // A mode the radio has no code for sends nothing, rather than a
    // malformed command it would silently reject.
    if (command != null) _send(command);
  }

  void _noteRatedWatts(int? rated, String id) {
    if (rated == null) {
      _pendingPower = null;
      return _sink.reportDiagnostic('ID $id names no rated output; power is neither read nor set');
    }
    _ratedWatts = rated;
    if (_pendingPower case final watts?) {
      _pendingPower = null;
      _relativePowerLevel = null;
      return setPower(watts);
    }
    if (_relativePowerLevel case final level?) {
      _relativePowerLevel = null;
      if (parseRelativePowerParams(level, rated) case final watts?) _sink.reportPower(watts);
    }
  }

  void _askRating() {
    if (++_ratingAsks <= optionalReadSilences) return _send(buildReadIdCommand());
    _pendingPower = null;
    _sink.reportDiagnostic('the radio never answered ID; power is neither read nor set');
  }

  @override
  void setPower(num watts) {
    if (_relativePower) {
      final rated = _ratedWatts;
      if (rated == null) {
        // Waits only while the radio may still answer `ID`; once it cannot,
        // nothing would ever send it.
        if (!_identified && !_ratingGivenUp) {
          _pendingPower = watts;
        } else {
          debugPrint('[cat] yaesu: power not sent — the radio\'s rated output is unknown');
        }
        return;
      }
      return _send(buildSetRelativePowerCommand(watts, rated));
    }
    if (!_headPower) return _send(buildSetPowerCommand(watts));
    if (!_powerAnswered) {
      _pendingPower = watts;
      return;
    }
    final head = _powerHead;
    if (head == null) {
      debugPrint('[cat] yaesu: power not sent — the radio\'s PC answers are in no known form');
    } else if (head == _plainPowerForm) {
      _send(buildSetPowerCommand(watts));
    } else {
      _send(buildSetHeadPowerCommand(head, watts));
    }
  }

  /// Sets, then reads back, as [setKeyerSpeed] does. Never starts a tune —
  /// that is [startTune].
  @override
  void setTuner({required bool inline}) {
    if (!_tunerRead.available) return;
    _send(buildSetTunerCommand(inline: inline));
    _readTuner();
  }

  @override
  bool get canStartTune => _tunerRead.available && _tuner != null;

  @override
  void startTune() {
    if (!canStartTune || _telemetry.transmitting || _tuner == TunerStatus.tuning) return;
    _send(buildStartTuneCommand());
    _tuneStarted = true;
    _readTuner();
  }

  /// `AC001;`, in line, ends a tune. From the CAT manuals, not a capture.
  @override
  void stopTune() => setTuner(inline: true);

  /// The nearest width the radio offers in its present mode and NARROW
  /// state, then a read-back — never a mode, a NARROW switch or a shift.
  @override
  void setPassband(Passband passband) {
    final profile = _widthProfile;
    final group = yaesuWidthGroupFor(_lastReported?.mode);
    if (profile == null || !_passbandRead.available || group == null) return;
    final index = profile.table(group).nearestIndex(passband.widthHz, narrowOn: _narrowOn);
    if (index == null) return;
    _send(buildSetWidthCommand(profile, index));
    _readPassband();
  }

  /// Sets, then reads back. One port serves both directions here, so [rx]
  /// names it, or [tx] where [rx] is absent; a name the radio has no port
  /// by sends nothing.
  @override
  void setAntenna({String? rx, String? tx}) {
    final ports = _antennaPorts;
    final port = rx ?? tx;
    if (ports == null || !_antennaRead.available || port == null || !ports.contains(port)) return;
    _send(buildSetAntennaCommand(ports.indexOf(port) + 1));
    _readAntenna();
  }

  @override
  void sendCw(String text) => _cwQueue.enqueue(text);

  /// Only stops QUEUING: the chunk the radio is playing back plays out, since
  /// the CAT manual offers nothing to interrupt `KY` — so the report keeps
  /// showing it to its estimated end rather than claiming it stopped.
  @override
  void stopCw() => _cwQueue.dropAllPending();

  @override
  bool get cwSending => _cwQueue.sending;

  @override
  void dropQueuedCw(int id) => _cwQueue.dropPending(id);

  @override
  ({int min, int max}) get keyerSpeedRange => (min: yaesuKeyerSpeedMin, max: yaesuKeyerSpeedMax);

  /// Sets, then reads back, so the value shown is what the radio took.
  @override
  void setKeyerSpeed(int wpm) {
    _send(buildSetKeyerSpeedCommand(wpm));
    _send(buildReadKeyerSpeedCommand());
  }

  /// The radio's own transmit state, pushed by Auto-Information and asked
  /// for once a second while a memory plays. `TX1;` is the app's own keying
  /// and `TX2;` the radio's — either way it is transmitting this memory, and
  /// coming back OUT of transmit afterwards is the memory ending. Before any
  /// "transmitting" answer a `0` is a rig still keying up, and ending there
  /// would stop a message that has not started.
  void _handleVoiceTransmit(String params) {
    if (_voice.activity?.recording ?? true) return;
    if (params != '0') {
      _txConfirmed = true;
      _voice.confirm();
      return;
    }
    if (!_txConfirmed) return;
    // Nothing left to unkey: the radio is already out of transmit.
    _keyedForVoice = false;
    _voice.end();
  }

  @override
  int get voiceMemoryCount => _voiceMemories;

  @override
  bool get canRecordVoice => true;

  /// Whether CAT TX is down for a playback, so the same code path unkeys
  /// however the playback ends — the poll, the ceiling, a stop, teardown.
  bool _keyedForVoice = false;

  /// Whether `PB0;` has named a memory as playing since this play started.
  /// An "idle" answer before that one is the FT-891's, and says nothing.
  bool _playbackConfirmed = false;

  /// Whether `TX;` has answered "transmitting" since this play started —
  /// `1` where the app keyed, `2` where the radio keyed itself. Until it
  /// has, a `0` is a radio that has not started yet rather than one that
  /// has finished.
  bool _txConfirmed = false;

  /// Unkeys as the playback ends, on the way to reporting it. `PB` does not
  /// key the radio and so does not unkey it either (yaesu_cat_codec.dart):
  /// without this the radio stays in transmit after the memory has played
  /// out, with an open microphone.
  void _reportVoice(VoiceActivity? activity) {
    if (activity == null && _keyedForVoice) {
      _keyedForVoice = false;
      _send(buildSetTxCommand(false));
    }
    _sink.reportVoiceActivity(activity);
  }

  /// Keys FIRST: `PB` alone plays the memory into the monitor and nothing
  /// reaches the air. Whether a Yaesu that keys ITSELF exists is untested —
  /// the two here both need this, and the `TX` handling below would notice
  /// one that did (it treats the radio's own transmit, `2`, as this memory
  /// transmitting).
  @override
  void playVoiceMemory(int n) {
    _send(buildSetTxCommand(true));
    _keyedForVoice = true;
    _playbackConfirmed = false;
    _txConfirmed = false;
    _send(buildPlayVoiceMemoryCommand(n));
    _voice.start(VoiceActivity(memory: n));
  }

  @override
  void recordVoiceMemory(int n) {
    _send(buildRecordVoiceMemoryCommand(n));
    _voice.start(VoiceActivity(memory: n, recording: true));
  }

  @override
  void stopVoice() {
    final activity = _voice.activity;
    if (activity == null) return;
    _send(activity.recording ? buildStopVoiceRecordingCommand() : buildStopVoiceMemoryCommand());
    _voice.end();
  }

  /// Whether the operator keyed the radio through [setPtt], so [teardown]
  /// can unkey it.
  bool _keyedByUs = false;

  @override
  void setPtt(bool on) {
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _send(buildSetTxCommand(on));
    _keyedByUs = on;
  }

  @override
  void startUpdates() {
    _framer.reset();
    _pollsUntilTunerRead = 0;
    _pollsUntilPassbandRead = 0;
    _pollsUntilAntennaRead = 0;
    _send(buildAutoInformationCommand(true));
    // First, so the answer is in before the mode's, whose arrival is what
    // reads the filter.
    _send(buildReadIdCommand());
    _requestFrequencyAndMode();
    // Once, not per poll — the same reasoning as the Icom driver's: the
    // speed changes only when someone turns the knob, and the dialog that
    // shows it re-reads it when it opens.
    _send(buildReadKeyerSpeedCommand());
    _poller.start();
    _telemetry.start();
  }

  /// Asks the radio for its keyer speed again — see [startUpdates].
  @override
  void refreshKeyerSpeed() => _send(buildReadKeyerSpeedCommand());

  @override
  void stopUpdates() {
    _stopPolling();
    // Leave the radio as we found it: AI mode persists across a disconnect,
    // so a logger that never turns it off leaves the rig chattering at
    // whatever connects next.
    _send(buildAutoInformationCommand(false));
  }

  /// The poller's CURRENT cadence, not its floor: it runs fast while the
  /// dial is moving and eases off when it isn't, and a caller asking "how
  /// long until I'd hear about a change" wants whichever is in force now.
  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  @override
  void teardown() {
    if (_keyedByUs) {
      // First, and sent even though the connection is closing: nothing else
      // will unkey this radio.
      _keyedByUs = false;
      _send(buildSetTxCommand(false));
    }
    _cwQueue.clear();
    _voice.dispose();
    // Via stopUpdates, so "stop talking to the radio" is written once.
    stopUpdates();
    _telemetry.dispose();
  }

  void _stopPolling() {
    _poller.stop();
    _telemetry.stop();
  }
}

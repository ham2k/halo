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
// speed (`KS`) — from the FTDX10 CAT manual, not from a radio.

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
  /// picker offers only the first, and only on a Silicon Labs bridge —
  /// a radio reached through some other adapter's two ports gets both.
  ///
  /// Where it cannot — desktop, where the OS named both ports itself and
  /// nothing knows they are siblings — `suggest` is all that is left: the
  /// bridge is named rather than hidden, so the picker puts it first and
  /// says so. Both clauses describe the same chip, because neither works
  /// everywhere: the USB pair is exact but unreadable on macOS, and the
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
  bool get hardwareVerified => true;

  /// The same claim [cp2105CatPort]'s `suggest` clause makes, for a caller
  /// holding the ids rather than a port.
  static bool matchesUsbIds({int? vendorId, int? productId}) =>
      vendorId == cp2105VendorId && productId == cp2105ProductId;

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
      yaesuTxWatchBytes +
      meterNumbersFor(calibrationFor(config), capturing: config[yaesuMeterCaptureConfigKey] == true).length *
          yaesuMeterReadBytes;

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
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      [
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
      ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => switch (key) {
        voiceMemoriesConfigKey => validateVoiceMemories(value),
        telemetryIntervalConfigKey => validateTelemetryInterval(value),
        _ => null,
      };

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

class Ft891Session implements TransceiverSession, CwKeyerSession, VoiceKeyerSession {
  final EquipmentSink _sink;
  final _framer = AsciiCatFramer();

  /// Transceive (`AI1;`) is the primary path — this only covers the cases it
  /// can't: the radio's AI menu switched off, or a frame lost to line noise.
  /// It stays silent for as long as the radio keeps talking. See
  /// adaptive_poller.dart for the wire measurements behind the intervals.
  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestFrequencyAndMode);

  /// What was last reported upward, so a repeat can be told from a move.
  VfoReading? _lastReported;

  /// What the radio last said its keyer runs at — the pace [_cwQueue]
  /// spaces chunks by.
  int? _keyerSpeed;

  /// Write-then-play through [yaesuAppKeyerMemory] — see yaesu_cat_codec.dart
  /// on why there is no plainer way.
  late final _cwQueue = CwSendQueue(
    maxChunkLength: yaesuKeyerMemoryMaxChars,
    send: (chunk) {
      _send(buildWriteKeyerMemoryCommand(yaesuAppKeyerMemory, chunk));
      _send(buildPlayKeyerMemoryCommand(yaesuAppKeyerMemory));
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
  })  : _config = config,
        _captureMeters = config[yaesuMeterCaptureConfigKey] == true,
        _meterInfoKey = config[meterInfoConfigKey] as String?;

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
      cycleBytes: _txWatchBytes +
          Ft891Driver.meterNumbersFor(_calibration, capturing: _captureMeters).length * yaesuMeterReadBytes,
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
    final note = 'RM ${[
      for (final entry in _rawMeters.entries) '${entry.key}=${entry.value}',
    ].join(' ')}';
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
    _send(buildReadPowerCommand());
  }

  /// Reports upward, and tells the poller whether the radio is moving.
  void _report(VfoReading reading) {
    final merged = VfoReading(
      freqKHz: reading.freqKHz ?? _lastReported?.freqKHz,
      mode: reading.mode ?? _lastReported?.mode,
    );
    // The FIRST reading is not the radio moving — it is the answer to the
    // question startUpdates just asked. Treating it as movement would drop
    // every connection into 200ms polling for the second or so it takes to
    // ramp back, for a radio nobody is touching.
    final first = _lastReported == null;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
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
    for (final command in _framer.add(ascii.decode(chunk, allowInvalid: true))) {
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
        final freqHz = parseFrequencyParams(command.params);
        // The radio reports exact Hz; everything above here speaks kHz.
        if (freqHz != null) _report(VfoReading(freqKHz: freqHz / 1000));
      case 'MD':
        final mode = parseModeParams(command.params);
        if (mode != null) _report(VfoReading(mode: mode));

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
          _sink.reportTransmitting(transmitting);
        }
        // The same answer is a playing memory's clock — see
        // [_handleVoiceTransmit]. ONE case, because Dart takes the first
        // match: a second `case 'TX'` further down is unreachable, and the
        // memory it was meant to end would play to the ceiling instead.
        _handleVoiceTransmit(command.params);

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
        final info = parseInformationParams(command.params);
        if (info == null) return;
        if (info.freqHz != null || info.mode != null) {
          _report(VfoReading(
            freqKHz: info.freqHz == null ? null : info.freqHz! / 1000,
            mode: info.mode,
          ));
        }
    }
    // Every other command is an acknowledgement or something we don't
    // track; ignoring them is what lets AI mode be noisy without harm.
  }

  @override
  void setFrequency(double freqKHz) => _send(buildSetFrequencyCommand((freqKHz * 1000).round()));

  @override
  void setMode(String mode) {
    final command = buildSetModeCommand(mode);
    // A mode the radio has no code for sends nothing, rather than a
    // malformed command it would silently reject.
    if (command != null) _send(command);
  }

  @override
  void setPower(num watts) => _send(buildSetPowerCommand(watts));

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

  @override
  void startUpdates() {
    _framer.reset();
    _send(buildAutoInformationCommand(true));
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

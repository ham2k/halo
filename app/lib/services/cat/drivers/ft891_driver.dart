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
import 'dart:typed_data';

import '../adaptive_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import 'cw_send_queue.dart';
import 'keyer_config.dart';
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
  /// DEAD ON macOS, though: libserialport cannot read vendorId or productId
  /// there either — the same EAGAIN/ENOENT that defeats `description`, which
  /// per-field probing in serial_transport_io.dart made visible. So this
  /// only suggests a driver on Linux and Windows. Doing it on macOS needs
  /// IOKit rather than libserialport, and matters because the CP2105 is a
  /// DUAL bridge: it presents two ports differing by one trailing digit,
  /// one carrying CAT and one PTT, and choosing wrong looks exactly like a
  /// dead cable.
  static const cp2105VendorId = 0x10C4;
  static const cp2105ProductId = 0xEA70;

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

  static bool matchesUsbIds({int? vendorId, int? productId}) =>
      vendorId == cp2105VendorId && productId == cp2105ProductId;

  @override
  bool get canKeyCw => true;

  /// The line keys by default (`KM`/`KY` are documented across it) — an
  /// entry for a rig that does not, or a developer on the generic entry,
  /// says otherwise through [cwKeyerConfigKey].
  @override
  bool canKeyCwWith(Map<String, dynamic> config) => cwKeyerFromConfig(config, fallback: true);

  @override
  Set<String> get recognizedConfigKeys =>
      {...super.recognizedConfigKeys, cwKeyerConfigKey, voiceMemoriesConfigKey, voiceCeilingConfigKey};

  /// The keyer facts, asked only where the entry did not pin them — the
  /// generic Yaesu — and only of a developer (docs/design/cat.md § Voice
  /// keying).
  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      keyerConfigElements(overrides);

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) =>
      key == voiceMemoriesConfigKey ? validateVoiceMemories(value) : null;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => Ft891Session(
        sink,
        // Absent means NONE — see the Icom driver's createSession.
        voiceMemories: voiceMemoriesFromConfig(config, fallback: 0).clamp(0, yaesuVoiceMemoryCount),
        voiceMemoryCeiling: voiceCeilingFromConfig(config),
      );
}

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

  /// `PB0;` answers which memory is playing and `LM0;` which is recording,
  /// so while one is going the matching read goes out every second and the
  /// activity ends on a 0 — see voice_activity_tracker.dart. From the
  /// FTDX10 CAT manual; the FT-891, FT-710 and FT-991A list the same two
  /// commands, none of it yet sent to a radio.
  late final VoiceActivityTracker _voice = VoiceActivityTracker(
    report: _sink.reportVoiceActivity,
    stop: stopVoice,
    ceiling: () => voiceMemoryCeiling,
    onCeiling: (limit) => _sink.reportDiagnostic('voice memory stopped at the ${limit.inSeconds} s ceiling'),
    poll: () => _send(_voice.activity?.recording ?? false
        ? buildReadVoiceRecordingCommand()
        : buildReadVoicePlaybackCommand()),
  );

  /// See [voiceMemoriesConfigKey]: what the entry pinned, at most the
  /// line's five.
  final int _voiceMemories;

  @override
  final Duration voiceMemoryCeiling;

  Ft891Session(this._sink, {int voiceMemories = yaesuVoiceMemoryCount, this.voiceMemoryCeiling = voiceActivityCeiling})
      : _voiceMemories = voiceMemories;

  /// The cadence the poller has settled on — for tests, which otherwise
  /// could only infer it from timing.
  Duration get pollInterval => _poller.interval;

  void _send(String command) => _sink.send(ascii.encode(command));

  void _requestFrequencyAndMode() {
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
    _poller.noteData();
    // Yaesu CAT is ASCII, not binary like CI-V. `allowInvalid` because a
    // line-noise byte on a serial link must not throw out of a stream
    // callback — the framer will simply not match it as a command.
    for (final command in _framer.add(ascii.decode(chunk, allowInvalid: true))) {
      _handle(command);
    }
  }

  void _handle(AsciiCatCommand command) {
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

      case 'KS':
        final wpm = parseKeyerSpeedParams(command.params);
        if (wpm != null) {
          _keyerSpeed = wpm;
          _sink.reportKeyerSpeed(wpm);
        }

      // Answers to [_voice]'s polls: channel 0 is the radio idle again,
      // any other channel the memory still going.
      case 'PB':
        if (_voice.activity?.recording ?? true) return;
        _handleVoicePoll(parseVoiceChannelParams(command.params));
      case 'LM':
        if (!(_voice.activity?.recording ?? false)) return;
        _handleVoicePoll(parseVoiceChannelParams(command.params));

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

  void _handleVoicePoll(int? channel) {
    if (channel == null) return;
    if (channel == 0) {
      _voice.endFromPoll();
    } else {
      _voice.confirm();
    }
  }

  @override
  int get voiceMemoryCount => _voiceMemories;

  @override
  bool get canRecordVoice => true;

  @override
  void playVoiceMemory(int n) {
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
  }

  void _stopPolling() => _poller.stop();
}

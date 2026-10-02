// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio that is only ever as far away as this object: it holds frequency,
// mode and power, accepts every set, and reports each one straight back.
// Paired with placeholder_transport.dart, which explains why the pair exists.
//
// It speaks no protocol and puts nothing on the wire, so it proves nothing
// about any real driver — what it exercises is everything ABOVE a driver,
// which on a web build is otherwise unreachable for want of a socket. A
// protocol emulator (a driver's own bytes parsed and answered) would be a
// different thing living at the transport, and is not this.
//
// It PUSHES: [expectedUpdateInterval] is null, which is a claim Smart VFO
// Snap acts on (docs/design/cat.md § Smart VFO Snap) — silence means the
// radio is not moving, rather than nobody having asked.

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';
import '../driver.dart';
import '../equipment.dart';
import '../telemetry_poller.dart';
import '../transports/config_field_helpers.dart';
import 'cw_send_queue.dart';
import 'telemetry_config.dart';

/// Where a new placeholder rig comes up, so it lands somewhere plausible
/// rather than reporting nothing at all — 40m phone, at a typical barefoot
/// output.
const placeholderRadioDefaultFreqKHz = 7200.0;
const placeholderRadioDefaultMode = 'LSB';
const placeholderRadioDefaultWatts = 75;
const placeholderRadioDefaultKeyerSpeed = 22;

/// What a placeholder rig answers its SWR meter with, and the reason the
/// value is settable: [swrAlertThreshold] is the one number on the meter
/// strip that changes how the strip LOOKS, and an operator or a tester who
/// cannot cross it has no way to see the warning they are being promised.
const placeholderRadioDefaultSwr = 1.3;

/// A rig on a healthy 13.8 V supply. Fixed rather than settable: nothing in
/// the app branches on it, so a knob would be a knob for its own sake.
const placeholderRadioSupplyVolts = 13.8;

/// As many as an Icom, the most of the real ones — so every label the
/// editor offers has a memory behind it here.
const placeholderVoiceMemoryCount = 8;

/// How long a pretend memory "plays": long enough to see the keyer area's
/// playing view, short enough that a tester need not stop it.
const placeholderVoicePlayDuration = Duration(seconds: 4);

/// Null for a value no parse accepts, rather than the default: the caller
/// that READS applies the default, the caller that VALIDATES rejects the
/// null. One parse for both, so a frequency that passes the editor is the
/// frequency the session comes up on.
double? freqFromConfig(Map<String, dynamic> config) {
  final raw = config['placeholderFreq'];
  if (raw is num) return raw.toDouble();
  return double.tryParse('$raw'.trim());
}

/// Tolerant of a non-String, like every other read in this layer: a stored
/// node's config has been round-tripped through JSON, and an `as String`
/// here would throw out of `createSession` — which `CatService` does not
/// guard, so the throw would escape with the connection already open and
/// its drop timer still running.
String modeFromConfig(Map<String, dynamic> config) {
  final raw = '${config['placeholderMode'] ?? ''}'.trim().toUpperCase();
  return raw.isEmpty ? placeholderRadioDefaultMode : raw;
}

/// A mode token this driver will hand upward. Deliberately a shape rather
/// than the app's mode list: the point of a placeholder rig is trying modes,
/// including ones no catalogue radio supports. But a reading goes through
/// `RadioService` onto logged QSOs and out to ADIF, so a fat-fingered
/// `US B` must not get that far.
final _modeToken = RegExp(r'^[A-Z0-9][A-Z0-9/-]*$');

class PlaceholderRadioDriver extends EquipmentDriver {
  const PlaceholderRadioDriver();

  @override
  String get key => 'placeholder-radio';

  /// First word is what an equipment report prefills as the manufacturer,
  /// so it stays a plain word with no protocol or parenthesis in it — see
  /// equipment_report_test.dart.
  @override
  String get name => 'Placeholder Radio';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(const ['LSB', 'USB', 'CW', 'AM', 'FM', 'DATA-USB']);

  @override
  bool get canKeyCw => true;

  /// The three a placeholder can answer honestly: the power it was set to,
  /// the SWR it was configured with, and a fixed supply. No ALC — there is
  /// no audio chain here for one to act on, and a made-up number on a meter
  /// nobody can influence is worse than an empty slot.
  @override
  Set<RadioMeter> get telemetryMeters => const {RadioMeter.powerOut, RadioMeter.swr, RadioMeter.supplyVolts};

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => PlaceholderRadioSession(sink, config);

  @override
  int voiceMemoryCountWith(Map<String, dynamic> config) => voiceMemoriesFromConfig(config, fallback: placeholderVoiceMemoryCount);

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    // What the entry is FOR, said first: an operator reaching this form
    // wants a rig on their log, and every field below it is a simulator
    // knob that only a developer has any use for.
    {'type': 'markdown', 'text': t.settings.station.placeholderPurpose},
    // Under developer mode, all of them. The name is the whole form for
    // everyone else — and the values still exist, prefilled from
    // defaultConfig, so a hidden field never blocks a submit.
    if (!overrides.containsKey('placeholderFreq'))
      {
        'type': 'field',
        'fieldType': 'number',
        'key': 'placeholderFreq',
        'label': t.settings.station.placeholderFreq,
        'description': t.settings.station.placeholderFreqDescription,
        'devMode': true,
      },
    if (!overrides.containsKey('placeholderMode'))
      {
        'type': 'field',
        'fieldType': 'text',
        'key': 'placeholderMode',
        'label': t.settings.station.placeholderMode,
        'description': t.settings.station.placeholderModeDescription,
        'devMode': true,
      },
    if (!overrides.containsKey('placeholderPower'))
      {'type': 'field', 'fieldType': 'number', 'key': 'placeholderPower', 'label': t.settings.station.placeholderPower, 'devMode': true},
    if (!overrides.containsKey('placeholderSwr'))
      {
        'type': 'field',
        'fieldType': 'number',
        'key': 'placeholderSwr',
        'label': t.settings.station.placeholderSwr,
        'description': t.settings.station.placeholderSwrDescription,
        'devMode': true,
      },
    {...telemetryConfigElement(), 'devMode': true},
    if (!overrides.containsKey('placeholderReplyDelay'))
      {
        'type': 'field',
        'fieldType': 'number',
        'key': 'placeholderReplyDelay',
        'label': t.settings.station.placeholderReplyDelay,
        'description': t.settings.station.placeholderReplyDelayDescription,
        'devMode': true,
      },
  ];

  /// Blank is rejected on every numeric field, and prefilled by
  /// [EquipmentVariant.defaultConfig] so it never comes up unasked — see
  /// PlaceholderTransport.validateField for why null cannot be waved through.
  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    switch (key) {
      case 'placeholderFreq':
        final freq = freqFromConfig({...config, key: value});
        return (freq == null || freq <= 0) ? t.settings.station.placeholderFreqInvalid : null;
      case 'placeholderPower':
      case 'placeholderReplyDelay':
        return numberFromConfig({...config, key: value}, key, -1) < 0 ? t.settings.station.placeholderWholeNumberInvalid : null;
      case telemetryIntervalConfigKey:
        return validateTelemetryInterval(value);
      case 'placeholderSwr':
        final swr = value is num ? value : num.tryParse('${value ?? ''}'.trim());
        return (swr == null || swr < 1) ? t.settings.station.placeholderSwrInvalid : null;
      case 'placeholderMode':
        // Blank IS allowed here, and means the default: a `text` field hands
        // over the string the operator typed, so an empty box is empty and
        // nothing else — none of the number field's ambiguity.
        final mode = '${value ?? ''}'.trim().toUpperCase();
        return (mode.isEmpty || _modeToken.hasMatch(mode)) ? null : t.settings.station.placeholderModeInvalid;
      default:
        return null;
    }
  }
}

class PlaceholderRadioSession implements TransceiverSession, CwKeyerSession, VoiceKeyerSession, PttSession {
  final EquipmentSink _sink;

  /// How long a set takes to come back as a reading. Zero reports
  /// synchronously — a `Timer` of `Duration.zero` still defers a turn, and
  /// a test asserting on the reading would then have to pump for a rig that
  /// is meant to be instant.
  final Duration _replyDelay;

  double _freqKHz;
  String _mode;
  num _watts;

  /// What this rig answers its SWR meter with — see
  /// [placeholderRadioDefaultSwr].
  final num _swr;

  /// Reads the meters while this rig is "transmitting", on exactly the
  /// cadence a real one would be read at. It has no wire to spend, so the
  /// poller is here for the SHAPE: the panel, the expiry and the alert are
  /// then exercised by the same timing a radio would drive them with,
  /// rather than by a special case that only the placeholder takes.
  /// Never [TelemetryPoller.start]ed: this rig keys itself, so there is
  /// nothing to watch for and no exchange worth spending on asking.
  late final TelemetryPoller _telemetry = TelemetryPoller(onPoll: (_) => _reportMeters(), txInterval: telemetryIntervalFor(_config, cycleBytes: 0));

  /// Kept for [_telemetry]'s interval, which is read once when the poller is
  /// first touched rather than in the constructor — a `late final` field
  /// initialising from another field cannot run there.
  final Map<String, dynamic> _config;

  /// Pending reports, so [teardown] can drop them: a timer that survives
  /// the session reports a reading for a connection that is gone.
  final _pending = <Timer>[];

  /// Restates the current reading often enough that `CatService`'s silence
  /// watch never fires (`catStaleAfter`, 30 s). Without it a placeholder rig left
  /// alone turns stale in half a minute and the panel says the radio has
  /// stopped answering — which is exactly the state an operator leaves it
  /// sitting in while checking something else. A restated frequency is a
  /// no-op everywhere it lands: `_applyReading` skips an unchanged VFO and
  /// `VfoSnapper.report` refuses to extend a burst on one.
  Timer? _heartbeat;

  static const _heartbeatInterval = Duration(seconds: 10);

  /// A keyer that keys nothing, at a speed it simply remembers — so the
  /// keying surfaces (the Station dialog's keyer row, F1-F8, WPM) can be
  /// driven on a web build with no radio. The queue still paces chunks by
  /// their Morse duration, which is what makes [cwSending] honest for the
  /// seconds a message would take.
  int _keyerSpeed = placeholderRadioDefaultKeyerSpeed;

  /// Keying is what puts this rig on the air, so the progress report is
  /// also where its PTT comes from — the one thing in the app that can
  /// actually key a placeholder. Without it there would be no way to reach
  /// the transmitting half of the panel on a machine with no radio, which
  /// is the whole reason this driver exists.
  late final _cwQueue = CwSendQueue(
    maxChunkLength: 30,
    send: (_) {},
    speedWpm: () => _keyerSpeed,
    onProgress: (progress) {
      _sink.reportCwProgress(progress);
      _setTransmitting(progress != null);
    },
  );

  /// A voice keyer that plays nothing: a memory "plays" for
  /// [placeholderVoicePlayDuration] and a recording runs until stopped, so
  /// the voice surfaces can be driven with no radio. Its own timer rather
  /// than the tracker's poll — there is no radio to ask — cancelled by
  /// [stopVoice], which teardown goes through.
  VoiceActivity? _voice;
  Timer? _voiceEnd;

  PlaceholderRadioSession(this._sink, Map<String, dynamic> config)
    : _config = config,
      _replyDelay = Duration(milliseconds: numberFromConfig(config, 'placeholderReplyDelay', 0)),
      _freqKHz = freqFromConfig(config) ?? placeholderRadioDefaultFreqKHz,
      _mode = modeFromConfig(config),
      _watts = numberFromConfig(config, 'placeholderPower', placeholderRadioDefaultWatts),
      _swr = _swrFromConfig(config);

  static num _swrFromConfig(Map<String, dynamic> config) {
    final raw = config['placeholderSwr'];
    final swr = raw is num ? raw : num.tryParse('${raw ?? ''}'.trim());
    return (swr != null && swr >= 1) ? swr : placeholderRadioDefaultSwr;
  }

  /// Keyed, or not — reported only on a CHANGE, which is what the poller
  /// wants: it fires a first read on the transition and would stall if a
  /// restatement restarted its timer.
  void _setTransmitting(bool transmitting) {
    if (_telemetry.noteTransmitting(transmitting)) _sink.reportTransmitting(transmitting);
  }

  /// What the meters read while this rig is on the air. Deterministic — no
  /// jitter, no ramp: a value that wandered would make every test of the
  /// strip assert on a range, and a placeholder's job is to be exactly as
  /// interesting as it was configured to be.
  void _reportMeters() {
    _sink.reportMeter(RadioMeter.powerOut, _watts);
    _sink.reportMeter(RadioMeter.swr, _swr);
    _sink.reportMeter(RadioMeter.supplyVolts, placeholderRadioSupplyVolts);
  }

  void _afterDelay(void Function() report) {
    if (_replyDelay == Duration.zero) {
      report();
      return;
    }
    late final Timer timer;
    timer = Timer(_replyDelay, () {
      _pending.remove(timer);
      report();
    });
    _pending.add(timer);
  }

  void _reportVfo() => _afterDelay(() => _sink.report(VfoReading(freqKHz: _freqKHz, mode: _mode)));

  /// Nothing ever arrives: the placeholder transport's connection never emits.
  @override
  void handleData(Uint8List chunk) {}

  @override
  void startUpdates() {
    // One word, in the equipment row's developer-mode slot between the
    // frequency and the status pill: a green row moving through frequencies
    // is exactly what a real rig looks like. It is the developer's tell only
    // — the slot is hidden outside developer mode, and what says "no rig" to
    // everyone else is the catalogue name. A sentence would crowd out the
    // reading it sits beside.
    _sink.reportDiagnostic(t.settings.station.placeholderDiagnostic);
    _reportVfo();
    _afterDelay(() => _sink.reportPower(_watts));
    _afterDelay(() => _sink.reportKeyerSpeed(_keyerSpeed));
    // Said out loud, rather than left unknown: this rig KNOWS it is not
    // transmitting, and the difference is what the antenna-switch gate and
    // Smart VFO Snap both read. Through [_setTransmitting] and not straight
    // at the sink, so the poller has heard it too — otherwise its first
    // real answer would be the second time the app was told.
    _setTransmitting(false);
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _reportVfo());
  }

  /// Drops the pending replies along with the heartbeat: after this the
  /// session is not reporting, and a set whose delay had not yet elapsed
  /// would otherwise land afterwards as if it were still live.
  @override
  void stopUpdates() {
    _heartbeat?.cancel();
    _heartbeat = null;
    // stop(), not noteTransmitting(false): nothing said the rig unkeyed, and
    // a session picked up again must ask rather than assume.
    _telemetry.stop();
    for (final timer in _pending) {
      timer.cancel();
    }
    _pending.clear();
  }

  @override
  void setFrequency(double freqKHz) {
    _freqKHz = freqKHz;
    _reportVfo();
  }

  @override
  void setMode(String mode) {
    _mode = mode;
    _reportVfo();
  }

  @override
  void setPower(num watts) {
    _watts = watts;
    _afterDelay(() => _sink.reportPower(_watts));
  }

  @override
  void sendCw(String text) => _cwQueue.enqueue(text);

  @override
  void stopCw() => _cwQueue.clear();

  @override
  bool get cwSending => _cwQueue.sending;

  @override
  void dropQueuedCw(int id) => _cwQueue.dropPending(id);

  @override
  ({int min, int max}) get keyerSpeedRange => (min: 5, max: 50);

  @override
  void setKeyerSpeed(int wpm) {
    _keyerSpeed = wpm.clamp(keyerSpeedRange.min, keyerSpeedRange.max);
    _afterDelay(() => _sink.reportKeyerSpeed(_keyerSpeed));
  }

  @override
  void refreshKeyerSpeed() => _afterDelay(() => _sink.reportKeyerSpeed(_keyerSpeed));

  @override
  int get voiceMemoryCount => voiceMemoriesFromConfig(_config, fallback: placeholderVoiceMemoryCount);

  /// Off through `placeholderNoVoiceRecording`, so the fake rig can also
  /// stand in for one whose CAT plays memories but cannot record them —
  /// every Icom, where recording is the front panel's alone. Config rather
  /// than a second fake driver: standing in for real radios is what this
  /// one is for.
  @override
  bool get canRecordVoice => _config['placeholderNoVoiceRecording'] != true;

  @override
  Duration get voiceMemoryCeiling => voiceActivityCeiling;

  @override
  void playVoiceMemory(int n) {
    _startVoice(VoiceActivity(memory: n));
    _voiceEnd = Timer(placeholderVoicePlayDuration, stopVoice);
  }

  @override
  void recordVoiceMemory(int n) => _startVoice(VoiceActivity(memory: n, recording: true));

  void _startVoice(VoiceActivity activity) {
    _voiceEnd?.cancel();
    _voiceEnd = null;
    _voice = activity;
    // Playing a memory puts the rig on the air; recording into one does
    // not. A real radio makes exactly that distinction, and a placeholder
    // that keyed while recording would show a meter strip for a
    // transmission that never happened.
    _setTransmitting(!activity.recording);
    _sink.reportVoiceActivity(activity);
  }

  @override
  void stopVoice() {
    _voiceEnd?.cancel();
    _voiceEnd = null;
    if (_voice == null) return;
    _voice = null;
    _setTransmitting(false);
    _sink.reportVoiceActivity(null);
  }

  /// Whether the operator keyed this rig, so [teardown] can unkey it.
  bool _keyedByUs = false;

  /// On the air at once, with no reply delay: the same as a played memory,
  /// which is the other way this rig keys.
  @override
  void setPtt(bool on) {
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _setTransmitting(on);
    _keyedByUs = on;
  }

  /// Null, not a short interval: this session reports a change as it
  /// happens, so a quiet VFO is a settled one.
  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void teardown() {
    if (_keyedByUs) setPtt(false);
    _cwQueue.clear();
    stopVoice();
    stopUpdates();
    _telemetry.dispose();
  }
}

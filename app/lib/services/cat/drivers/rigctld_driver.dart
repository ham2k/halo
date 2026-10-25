// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks the Hamlib `rigctld` network protocol: line-oriented ASCII over a
// TCP stream to a daemon the operator already runs, which in turn drives
// any of the hundreds of radios Hamlib has a backend for — one codec, the
// whole catalogue (docs/design/cat.md, roadmap).
//
// rigctld pushes nothing: it only ever answers questions, so this driver is
// poll-driven end to end, on the same AdaptivePoller cadence as the FT-891.
//
// Reads use the extended-response protocol (the `+` prefix): a plain `f`
// answers with a bare number and a plain `m` with a bare word, and with two
// questions outstanding on one stream the answers can only be told apart by
// keeping a queue of what was asked — which one dropped response desyncs
// for the life of the connection. `+f` answers with a self-labeling
// `Frequency: 14250000` line, so every line parses on its own.
//
// Levels are the exception: `+l SWR` answers a `get_level: SWR` header and
// then the BARE value (`1.5`), unlabeled — so a level reading is told apart
// by the header line before it, and a level the daemon refuses (`RPRT -1`
// unknown name, `-4` not implemented, `-11` not available) is not asked for
// again on this connection.
//
// Writes are plain commands (`F`, `M`); their `RPRT n` acknowledgements are
// deliberately ignored. A rejected set needs no handling of its own — the
// next poll reports the unchanged state, which is the truth on the dial.
//
// Commands address whatever VFO the rig currently has selected. What that
// takes depends on how the daemon was started: plainly, commands carry no
// VFO argument — and a stray token is read as a further command — while in
// `--vfo` mode every command must name one, or the parser consumes the
// next command as the name (a `+f\n+m\n` burst loses the `+m`). The two
// forms are mutually unintelligible, so startUpdates asks `\chk_vfo`
// and sends nothing else until it is answered — the same negotiation
// rigctl's own NET backend performs. Not even the first reads go out ahead
// of it: a blind `+l` leaves a `--vfo` daemon waiting for a level name, and
// it takes the next line it is sent as one, running what is left of that
// line as one-letter commands.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../adaptive_poller.dart';
import '../telemetry_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import 'cw_send_queue.dart';
import 'keyer_config.dart';
import 'poll_config.dart';
import 'telemetry_config.dart';
import 'voice_activity_tracker.dart';

const _lineFeed = 0x0a;
const _carriageReturn = 0x0d;

/// App mode names → Hamlib mode tokens, where the spellings differ. The
/// app's names follow the Yaesu-flavored table the rest of the codebase
/// uses (`CW-R`, `DATA-USB`); Hamlib writes them as one token (`CWR`,
/// `PKTUSB`) and calls both RTTY sidebands `RTTY`/`RTTYR`.
const hamlibModesByAppMode = <String, String>{
  'CW-R': 'CWR',
  'FM-N': 'FMN',
  'AM-N': 'AMN',
  'DATA-USB': 'PKTUSB',
  'DATA-LSB': 'PKTLSB',
  'DATA-FM': 'PKTFM',
  'RTTY-LSB': 'RTTY',
  'RTTY-USB': 'RTTYR',
};

const appModesByHamlibMode = <String, String>{
  'CWR': 'CW-R',
  'FMN': 'FM-N',
  'AMN': 'AM-N',
  'PKTUSB': 'DATA-USB',
  'PKTLSB': 'DATA-LSB',
  'PKTFM': 'DATA-FM',
  // Without these, a set round-trips as raw 'RTTYR' — a spelling no other
  // surface of the app uses. Plain RTTY is the conventional (LSB) side.
  'RTTY': 'RTTY-LSB',
  'RTTYR': 'RTTY-USB',
};

final _hamlibModeToken = RegExp(r'^[A-Z0-9]+$');

/// The Hamlib token to send for an app mode, or null for a mode that can't
/// be expressed as one — the caller sends nothing rather than a command
/// with a malformed argument. Pass-through is deliberate: Hamlib's mode
/// list is far longer than any table here, and an unknown-to-us token costs
/// only an `RPRT` error from a daemon that doesn't know it either.
String? hamlibModeForAppMode(String? mode) {
  if (mode == null) return null;
  final upper = mode.toUpperCase();
  final mapped = hamlibModesByAppMode[upper] ?? upper;
  return _hamlibModeToken.hasMatch(mapped) ? mapped : null;
}

/// The app's name for a Hamlib mode token. Tokens without an app spelling
/// (WFM, PSK, …) pass through unchanged, the way the FlexRadio driver
/// reports whatever the radio said.
String appModeForHamlibMode(String token) {
  final upper = token.toUpperCase();
  return appModesByHamlibMode[upper] ?? upper;
}

class RigctldDriver extends EquipmentDriver {
  const RigctldDriver();

  /// rigctld's own default (`-t` changes it).
  static const defaultPort = 4532;

  @override
  String get key => 'rigctld';

  @override
  String get name => 'Hamlib rigctld';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(['LSB', 'USB', 'CW', 'AM', 'FM', ...hamlibModesByAppMode.keys]);

  @override
  bool get canKeyCw => true;

  /// Off unless the entry says otherwise: which backend is behind the daemon
  /// is not something the app can ask without keying it, and many Hamlib
  /// backends answer `send_morse` with `RPRT -4`. A named entry for a device
  /// that keys (SOTAcat) pins [cwKeyerConfigKey]; on the generic one a
  /// developer says.
  @override
  bool canKeyCwWith(Map<String, dynamic> config) => cwKeyerFromConfig(config, fallback: false);

  /// None unless the entry says, for the reason [canKeyCwWith] gives: the
  /// SOTAcat pins its KX2/KX3's two; on the generic entry a developer says.
  @override
  int voiceMemoryCountWith(Map<String, dynamic> config) => voiceMemoriesFromConfig(config, fallback: 0);

  /// The levels Hamlib defines for these, all of them read-only meters. No
  /// ALC-free or SWR-free backend is excluded by declaring them: a level a
  /// backend does not implement answers `RPRT -11`, after which this driver
  /// stops asking for it, and the slot simply stays empty.
  @override
  Set<RadioMeter> get telemetryMeters => const {RadioMeter.powerOut, RadioMeter.swr, RadioMeter.alc, RadioMeter.supplyVolts};

  /// The meter cadence, and what the backend behind the daemon can key —
  /// asked only under developer mode. Where the daemon is listening is the
  /// TCP transport's question.
  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    telemetryConfigElement(),
    pollConfigElement(),
    ...keyerConfigElements(overrides),
  ];

  /// The keyer range and memory length a named entry pins are read in
  /// [createSession] and never shown as fields — see
  /// [rigctldKeyerSpeedMinConfigKey].
  @override
  Set<String> get recognizedConfigKeys => {...super.recognizedConfigKeys, rigctldKeyerSpeedMinConfigKey, rigctldKeyerSpeedMaxConfigKey, voiceCeilingConfigKey};

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => switch (key) {
    telemetryIntervalConfigKey => validateTelemetryInterval(value),
    pollIntervalConfigKey => validatePollInterval(value),
    voiceMemoriesConfigKey => validateVoiceMemories(value),
    _ => null,
  };

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => RigctldSession(sink, config);
}

/// Hamlib's `RFPOWER` level (unlike `RFPOWER_METER_WATTS`, see [setPower])
/// is genuinely settable, but expressed as a 0.0-1.0 fraction of the rig's
/// own maximum — a fact rigctld has no command to state. 100W stands in
/// for that maximum the same way the other four drivers' relative-scale
/// conversions do; wrong for a QRP or a high-power station.
const _assumedMaxWatts = 100;

/// How much of a message one `b` carries. Hamlib hands the whole line to the
/// backend, which splits it for the radio's own buffer — but the queue paces
/// and reports by chunk, and a long message sent whole could only be
/// abandoned by a `\stop_morse` the backend may not have. 24 is the Elecraft
/// `KY` buffer, the radio a SOTAcat drives.
const rigctldMorseChunkChars = 24;

/// The speeds asked of `KEYSPD` when the entry pins none. rigctld has no
/// command that states a backend's range, so this is the widest any family
/// here accepts (Kenwood's 4-60); a radio that takes less clamps, and the
/// read-back after every set shows what it took.
const rigctldKeyerSpeedRange = (min: 4, max: 60);

/// Config keys an entry pins its radio's keyer range under, from the radio's
/// CAT manual — the SOTAcat's KX2/KX3 take 8-50. Never fields: the range is
/// a fact about the radio behind the daemon, which only a named entry knows.
const rigctldKeyerSpeedMinConfigKey = 'keyerSpeedMin';
const rigctldKeyerSpeedMaxConfigKey = 'keyerSpeedMax';

/// The `RPRT` codes after which a level is not asked for again on this
/// connection: Hamlib's EINVAL (a level name the daemon does not know — an
/// older Hamlib asked for `RFPOWER_METER_WATTS`), ENIMPL and ENAVAIL. A read
/// with fixed arguments refused for any of these is refused every time.
const _retiringLevelErrors = {-1, -4, -11};

class RigctldSession implements ReadBackSession, PttSession, CwKeyerSession, VoiceKeyerSession, RawCommandSession {
  final EquipmentSink _sink;

  RigctldSession(this._sink, [this._config = const {}]);

  final Map<String, dynamic> _config;

  /// Whether this node keys CW ([RigctldDriver.canKeyCwWith]) — and so
  /// whether connecting reads the keyer speed at all, which a daemon without
  /// a keyer would only refuse.
  late final bool _keysCw = const RigctldDriver().canKeyCwWith(_config);

  late final ({int min, int max}) _keyerSpeedRange = (
    min: (_config[rigctldKeyerSpeedMinConfigKey] as num?)?.toInt() ?? rigctldKeyerSpeedRange.min,
    max: (_config[rigctldKeyerSpeedMaxConfigKey] as num?)?.toInt() ?? rigctldKeyerSpeedRange.max,
  );

  /// Whether this connection is still waiting for its `\chk_vfo` answer,
  /// before which nothing is polled — see this file's header.
  bool _awaitingProbe = false;

  /// Starts the connection plain if the probe is never answered at all,
  /// rather than leaving a daemon that ignores it unpolled.
  Timer? _probeTimeout;

  static const _probeWait = Duration(seconds: 2);

  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestFrequencyAndMode, slow: idlePollIntervalFor(_config));

  /// Watches for the operator to key the rig, and reads its meters while
  /// they hold it — telemetry_poller.dart, and the opposite rule to
  /// [_poller]'s.
  ///
  /// Both cadences take the flat default: rigctld is reached over TCP, and
  /// the serial link on the far side of the daemon is one this app never
  /// sees and cannot budget for.
  late final TelemetryPoller _telemetry = TelemetryPoller(
    onPoll: _pollTelemetry,
    idleInterval: telemetryIntervalFor(_config, cycleBytes: 0),
    txInterval: telemetryIntervalFor(_config, cycleBytes: 0),
  );

  /// What was last reported upward, so a repeat can be told from a move —
  /// the poller's fast/slow choice rides on this, same as the FT-891's.
  VfoReading? _lastReported;

  /// Bytes received since the last complete line.
  final _residual = <int>[];

  /// Whether the daemon parses a VFO name on every command (`--vfo` mode),
  /// per its `\chk_vfo` answer. Until that answer lands, nothing is polled,
  /// and a set the operator makes goes out plain: `currVFO` sent to a plain
  /// daemon is read as further commands and executes garbage.
  bool _vfoMode = false;

  /// The cadence the poller has settled on — for tests, which otherwise
  /// could only infer it from timing.
  Duration get pollInterval => _poller.interval;

  /// The level whose `get_level:` header was the last line, so the bare
  /// value after it can be read as that level. Null between answers.
  String? _pendingLevel;

  /// Levels this daemon refused on this connection — see
  /// [_retiringLevelErrors]. Re-learned per connection, like [_vfoMode]: a
  /// reconnect may reach a different daemon or backend.
  final _refusedLevels = <String, int>{};

  /// How the probe came out — `--vfo`, plain, or plain because nothing
  /// answered it — for the developer diagnostic ([_reportDiagnostic]).
  String? _probeOutcome;

  /// The last CW command the daemon refused, as `send_morse -4` — see
  /// [_pendingCommand].
  String? _refusedCommand;

  /// The CW command whose extended header was the last line, so the `RPRT`
  /// after it can be told apart from a plain write's.
  String? _pendingCommand;

  /// What the radio last said its keyer runs at — the pace [_cwQueue]
  /// spaces chunks by.
  int? _keyerSpeed;

  /// "Still playing?" is "still transmitting?" — `+t`, as the KX's own
  /// `TQ;` is on the Kenwood driver: Hamlib has no voice-memory status.
  late final VoiceActivityTracker _voice = VoiceActivityTracker(
    report: _sink.reportVoiceActivity,
    stop: stopVoice,
    ceiling: () => voiceMemoryCeiling,
    onCeiling: (limit) {
      _ceilingNote = 'voice memory stopped at the ${limit.inSeconds} s ceiling';
      _reportDiagnostic();
    },
    poll: () => _send('+t$_vfo'),
  );

  String? _ceilingNote;

  /// One line for everything this session learned that no surface shows:
  /// the probe's outcome, the levels refused, the last refused CW command,
  /// the voice ceiling. One because the sink keeps a single diagnostic, and
  /// a second call would hide the first.
  void _reportDiagnostic() {
    final refused = _refusedLevels.entries.map((e) => '${e.key} ${e.value}').join(', ');
    _sink.reportDiagnostic(
      [
        if (_probeOutcome != null) _probeOutcome,
        if (refused.isNotEmpty) 'refused $refused',
        if (_refusedCommand != null) 'refused $_refusedCommand',
        if (_ceilingNote != null) _ceilingNote,
      ].join(' · '),
    );
  }

  late final _cwQueue = CwSendQueue(
    maxChunkLength: rigctldMorseChunkChars,
    // No VFO argument in either mode: `send_morse` takes the rest of the
    // line as its text, so a `currVFO` here would be keyed. Extended, so a
    // refusal comes back under a `send_morse:` header rather than as an
    // RPRT nothing ties to it.
    send: (chunk) => _send('+b $chunk'),
    speedWpm: () => _keyerSpeed,
    onProgress: _sink.reportCwProgress,
  );

  void _send(String command) => _sink.send(ascii.encode('$command\n'));

  /// An extension's raw commands, written as given (`f\n`, `+\get_level RFPOWER\n`):
  /// the daemon answers each command in order and whole, so a raw answer
  /// never lands between one of the driver's headers and its value.
  @override
  int? sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    _rawGrace.sent();
    _sink.send(bytes);
    return null;
  }

  /// A raw `\get_level` or `send_morse` is answered under the same header as
  /// the driver's own: its refusal, counted, would retire that meter for the
  /// connection, or drop the operator's queued CW.
  final _rawGrace = RawRefusalGrace();

  /// Asks for [level] unless this daemon has already refused it.
  void _readLevel(String level) {
    if (!_refusedLevels.containsKey(level)) _send('+l$_vfo $level');
  }

  /// The VFO argument this daemon's parser requires, `currVFO` meaning
  /// "whatever the rig has selected" — the same addressing plain mode gets
  /// by leaving it off.
  String get _vfo => _vfoMode ? ' currVFO' : '';

  /// No power read: Hamlib's watts level is a measured meter, 0 between
  /// overs and following the operator's voice on SSB, so the station's power
  /// stays what the operator set — see [_handleLevel].
  void _requestFrequencyAndMode() {
    _send('+f$_vfo');
    _send('+m$_vfo');
  }

  /// One turn of the telemetry cadence. No backlog guard, unlike flrig's:
  /// every extended answer names its question — a label on the value, or for
  /// a level the `get_level:` header just before it — so a question asked
  /// twice is answered twice and read correctly both times, with nothing
  /// counted across answers to fall out of step.
  void _pollTelemetry(bool transmitting) {
    _send('+t$_vfo');
    if (!transmitting) return;
    _readLevel('RFPOWER_METER_WATTS');
    _readLevel('SWR');
    _readLevel('ALC');
    _readLevel('VD_METER');
  }

  @override
  void handleData(Uint8List chunk) {
    for (final byte in chunk) {
      if (byte == _lineFeed) {
        _handleLine(ascii.decode(_residual, allowInvalid: true));
        _residual.clear();
      } else if (byte != _carriageReturn) {
        _residual.add(byte);
      }
    }
  }

  /// The lines that answer the STATE poll — and so the only ones that defer
  /// it. Everything else on the stream answers something else: the PTT watch
  /// asks several times a second, and each of its answers comes as a header,
  /// a value and a status (`get_ptt:`, `PTT: 0`, `RPRT 0`), with the meter
  /// reads the same while the radio is keyed. Counting any of those as "the
  /// daemon just told us where the radio is" re-arms the poll timer before it
  /// can fire, and a radio tuned by hand is then read only on
  /// AdaptivePoller's 9-second staleness ceiling. An allow-list, because a
  /// deny-list is starved again by the next line a new question brings.
  static const _stateLabels = ['Frequency: ', 'Mode: '];

  void _handleLine(String line) {
    // The state poll's own answer defers its next round — asking again now
    // would repeat a question we hold the answer to.
    if (_stateLabels.any(line.startsWith)) _poller.noteData();

    // The line after a `get_level:` header is that level's value or its
    // refusal; the header is consumed by exactly one line either way.
    final pending = _pendingLevel;
    _pendingLevel = null;
    final command = _pendingCommand;
    _pendingCommand = null;
    if (command != null && line.startsWith('RPRT ')) {
      final code = int.tryParse(line.substring('RPRT '.length).trim());
      if (code != null && code != 0 && !_rawGrace.active) _commandRefused(command, code);
      return;
    }
    if (pending != null) {
      if (line.startsWith('RPRT ')) {
        final code = int.tryParse(line.substring('RPRT '.length).trim());
        if (code != null && _retiringLevelErrors.contains(code) && !_rawGrace.active) {
          _refusedLevels[pending] = code;
          _reportDiagnostic();
        }
        return;
      }
      // Bare, as Hamlib prints it; also read past a label, for a server
      // that adds one anyway (`Level Value: 1.5`, `SWR: 1.5`).
      final value = double.tryParse(line.substring(line.lastIndexOf(':') + 1).trim());
      if (value != null) {
        _handleLevel(pending, value);
        return;
      }
    }

    // A daemon too old to know the probe answers it with an error alone,
    // which is the plain parser's answer.
    if (_awaitingProbe && line.startsWith('RPRT ')) {
      _learnVfoMode(false, outcome: 'plain (probe refused)');
      return;
    }

    if (line.startsWith('send_morse:') || line.startsWith('stop_morse:')) {
      _pendingCommand = line.substring(0, line.indexOf(':'));
      return;
    }

    // `get_level: SWR`, or `get_level: currVFO:SWR` from a `--vfo` daemon.
    // Any other VFO is a question the daemon misparsed — a read that reached
    // a `--vfo` daemon unaddressed (after an unanswered probe, or an
    // operator's set inside the probe's round trip), which it answers as
    // `get_level: None:+l` — and its refusal says nothing about the level.
    if (line.startsWith('get_level:')) {
      final args = line.substring('get_level:'.length).trim();
      final split = args.lastIndexOf(':');
      final vfo = split < 0 ? '' : args.substring(0, split).trim();
      final level = args.substring(split + 1).trim().toUpperCase();
      if (level.isNotEmpty && (vfo.isEmpty || vfo == 'currVFO')) _pendingLevel = level;
      return;
    }

    // Extended responses label every other value; anything else on the
    // stream — `get_freq:` headers, `Passband:`, `RPRT n` acknowledgements —
    // asks nothing of us.
    // Both spellings of the probe answer: `ChkVFO: 1` is 4.7's extended
    // form, `CHKVFO 1` the older daemons' — netrigctl accepts both, so
    // must we, or an old `--vfo` daemon reads as plain and loses its mode.
    if (line.startsWith('ChkVFO: ')) {
      _learnVfoMode(line.substring('ChkVFO: '.length).trim() == '1');
    } else if (line.startsWith('CHKVFO ')) {
      _learnVfoMode(line.substring('CHKVFO '.length).trim() == '1');
    } else if (line.startsWith('Frequency: ')) {
      final hz = double.tryParse(line.substring('Frequency: '.length).trim());
      // The daemon reports Hz; everything above here speaks kHz.
      if (hz != null && hz > 0) {
        _report(VfoReading(freqKHz: double.parse((hz / 1000).toStringAsFixed(3))));
      }
    } else if (line.startsWith('Mode: ')) {
      final token = line.substring('Mode: '.length).trim();
      if (token.isNotEmpty) _report(VfoReading(mode: appModeForHamlibMode(token)));
    } else if (line.startsWith('PTT: ')) {
      final ptt = int.tryParse(line.substring('PTT: '.length).trim());
      // Anything else is a backend that does not implement it, and is left
      // as "nobody knows" rather than read as receiving.
      if (ptt != null && _telemetry.noteTransmitting(ptt != 0)) _sink.reportTransmitting(ptt != 0);
      if (ptt != null && _voice.active) {
        if (ptt != 0) {
          _voice.confirm();
        } else {
          _voice.endFromPoll();
        }
      }
    }
  }

  void _learnVfoMode(bool vfoMode, {String? outcome}) {
    // Before the guard: an answer that arrives after the timeout started the
    // session plain still corrects the addressing of every later command.
    _vfoMode = vfoMode;
    _probeOutcome = outcome ?? (vfoMode ? '--vfo' : 'plain');
    _reportDiagnostic();
    if (!_awaitingProbe) return;
    _awaitingProbe = false;
    _probeTimeout?.cancel();
    _probeTimeout = null;
    _requestFrequencyAndMode();
    if (_keysCw) refreshKeyerSpeed();
    _poller.start();
    _telemetry.start();
  }

  void _handleLevel(String level, double value) {
    switch (level) {
      case 'RFPOWER_METER_WATTS':
        // A meter, never the station's power: it is what left the radio a
        // moment ago — 0 W between overs, a speech sample on SSB — and
        // reported as power it would replace the operator's on every QSO
        // logged after an over. Only while keyed: a measured "0 W" on the
        // strip says the radio put out nothing, where an empty slot says
        // there was nothing to measure.
        if (_telemetry.transmitting) _sink.reportMeter(RadioMeter.powerOut, value);
      case 'SWR':
        // Below 1 is physically impossible, so it is a backend answering
        // zero for a meter it does not have — and a 0.0 on the strip reads as
        // a perfect match, the most reassuring way available to be wrong.
        if (value >= 1) _sink.reportMeter(RadioMeter.swr, value);
      case 'ALC':
        // Hamlib's ALC is already a fraction of the backend's own scale.
        _sink.reportMeter(RadioMeter.alc, value.clamp(0.0, 1.0));
      case 'VD_METER':
        _sink.reportMeter(RadioMeter.supplyVolts, value);
      case 'KEYSPD':
        // Zero is a backend with no keyer speed to report, not a keyer
        // stopped: pacing keeps its default rather than computing at 0 WPM.
        if (value >= 1) {
          _keyerSpeed = value.round();
          _sink.reportKeyerSpeed(_keyerSpeed!);
        }
    }
  }

  /// Reports upward, and tells the poller whether the radio is moving.
  void _report(VfoReading reading) {
    final merged = VfoReading(freqKHz: reading.freqKHz ?? _lastReported?.freqKHz, mode: reading.mode ?? _lastReported?.mode);
    // The FIRST reading is the answer to the question startUpdates just
    // asked, not the radio moving — see Ft891Session._report.
    final first = _lastReported == null;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
  }

  @override
  void readBack() => _poller.pollNow();

  @override
  void setFrequency(double freqKHz) => _send('F$_vfo ${(freqKHz * 1000).round()}');

  @override
  void setMode(String mode) {
    final token = hamlibModeForAppMode(mode);
    // `-1` leaves the passband unchanged (Hamlib ≥ 3.1), so retuning the
    // mode never clobbers a filter width the operator set at the radio.
    if (token != null) _send('M$_vfo $token -1');
  }

  /// NOT `RFPOWER_METER_WATTS` — Hamlib defines that level read-only (a
  /// measured-output meter), so a `set_level` against it is rejected by
  /// every correctly-implemented backend, not just an old one. `RFPOWER`
  /// is the genuinely settable level, at the cost of [_assumedMaxWatts]'s
  /// conversion — an ignored `RPRT` error here means the daemon/backend
  /// rejected the value outright, same as any other rejected set.
  @override
  void setPower(num watts) => _send('L$_vfo RFPOWER ${(watts / _assumedMaxWatts).clamp(0, 1).toStringAsFixed(3)}');

  /// Whether the app keyed the radio, so [teardown] can unkey it.
  bool _keyedByUs = false;

  @override
  void setPtt(bool on) {
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _send('T$_vfo ${on ? 1 : 0}');
    _keyedByUs = on;
  }

  @override
  void sendCw(String text) => _cwQueue.enqueue(text);

  /// A refused `b` keyed nothing, so the rest of the message is dropped and
  /// the strip stops showing it going out; a refused `\stop_morse` means the
  /// chunk on the radio plays out. Either way the diagnostic says so — the
  /// strip cannot.
  void _commandRefused(String command, int code) {
    if (command == 'send_morse') _cwQueue.clear();
    _refusedCommand = '$command $code';
    _reportDiagnostic();
  }

  /// `\stop_morse` aborts what the radio is keying, where the backend can
  /// (Hamlib's `Can stop Morse`); one that cannot answers an error and
  /// finishes the current chunk ([_commandRefused]). No VFO argument in
  /// either mode — a `--vfo` daemon reads one as a further command.
  @override
  void stopCw() {
    _cwQueue.clear();
    _send('+\\stop_morse');
  }

  @override
  bool get cwSending => _cwQueue.sending;

  @override
  void dropQueuedCw(int id) => _cwQueue.dropPending(id);

  @override
  ({int min, int max}) get keyerSpeedRange => _keyerSpeedRange;

  /// Sets, then reads back, so the value shown is what the radio took. The
  /// asked speed paces the queue until a read-back says otherwise — some
  /// backends set a level they cannot read, or read it as 0 — though it is
  /// never reported as the radio's. Pacing at the default instead would send
  /// a slow keyer its next chunk while the last is still going out.
  @override
  void setKeyerSpeed(int wpm) {
    final clamped = wpm.clamp(_keyerSpeedRange.min, _keyerSpeedRange.max);
    _send('L$_vfo KEYSPD $clamped');
    _keyerSpeed = clamped;
    refreshKeyerSpeed();
  }

  @override
  void refreshKeyerSpeed() => _readLevel('KEYSPD');

  @override
  int get voiceMemoryCount => voiceMemoriesFromConfig(_config, fallback: 0);

  /// Hamlib has `send_voice_mem` and `stop_voice_mem`, and nothing that
  /// records.
  @override
  bool get canRecordVoice => false;

  @override
  Duration get voiceMemoryCeiling => voiceCeilingFromConfig(_config);

  /// Plain, with no VFO argument even to a `--vfo` daemon: the `+` form
  /// there waits for a further argument, and a VFO is read as the memory
  /// (rigctld 4.7.2 -o, captured). A refusal comes back as an unlabeled
  /// `RPRT`, so it shows as the tracker's doubt — the radio never keying.
  @override
  void playVoiceMemory(int n) {
    if (n < 1 || n > voiceMemoryCount) return;
    _send('\\send_voice_mem $n');
    _voice.start(VoiceActivity(memory: n));
  }

  @override
  void recordVoiceMemory(int n) {}

  @override
  void stopVoice() {
    if (_voice.activity == null) return;
    _send('\\stop_voice_mem');
    _voice.end();
  }

  @override
  void startUpdates() {
    _residual.clear();
    _pendingLevel = null;
    _pendingCommand = null;
    _refusedLevels.clear();
    _probeOutcome = null;
    _refusedCommand = null;
    _ceilingNote = null;
    // Re-learned per connection — a reconnect may reach a daemon restarted
    // the other way. The extended `+` form makes the answer self-labeling
    // (`ChkVFO: 0/1`) in both modes; a daemon too old to know the command
    // answers an unlabeled complaint, which reads as plain mode. The polls
    // start from the answer, in [_learnVfoMode].
    _vfoMode = false;
    _awaitingProbe = true;
    _send('+\\chk_vfo');
    _probeTimeout?.cancel();
    _probeTimeout = Timer(_probeWait, () => _learnVfoMode(false, outcome: 'plain (probe unanswered)'));
  }

  @override
  void stopUpdates() {
    _awaitingProbe = false;
    _probeTimeout?.cancel();
    _probeTimeout = null;
    _poller.stop();
    _telemetry.stop();
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
      _send('T$_vfo 0');
    }
    // rigctld holds no per-client state, so past the unkey, stopping the
    // poll is the whole farewell.
    _cwQueue.clear();
    _voice.dispose();
    stopUpdates();
    _telemetry.dispose();
  }
}

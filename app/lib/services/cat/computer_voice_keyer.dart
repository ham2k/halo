// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The computer's voice keyer (docs/design/cat.md § The computer's voice
// keyer): a radio's voice messages as recordings on this computer, played
// into the radio's sound device while the app keys it over CAT. A
// [VoiceKeyer] like the radio's own memories, so every voice surface — F1-F8,
// the keyer area, the Phone Keyer dialog, repeat, Enter Sends Messages, a
// peer's request — plays one without knowing which it is.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:halo_audio/halo_audio.dart';

import '../error_reporting_service.dart';
import 'driver.dart';

/// Where the audio goes and comes from, each `{id, name}` — the id first, the
/// name when the id has changed (matchAudioDevice) — or, for the output,
/// [voiceOutputRadio].
const voiceOutputConfigKey = 'voiceOutput';
const voiceInputConfigKey = 'voiceInput';

/// The output that is the radio itself, over its own network link
/// ([NetworkTransmitAudioSession]) — also what a radio that takes it plays
/// into when no output is picked.
const voiceOutputRadio = {'radio': true};

bool voiceOutputIsRadio(Object? raw) => raw is Map && raw['radio'] == true;

/// Milliseconds from keying to the first sample, and from the last sample to
/// unkeying (docs/design/cat.md § The computer's voice keyer).
const voiceLeadConfigKey = 'voiceLeadMs';
const voiceTailConfigKey = 'voiceTailMs';

const defaultVoiceLead = Duration(milliseconds: 250);
const defaultVoiceTail = Duration(milliseconds: 150);

/// The longest a recording runs before it is stopped for the operator — a
/// message is a CQ or an exchange, and a recording left running is one
/// nobody is speaking into.
const computerVoiceRecordingCeiling = Duration(seconds: 60);

/// Past a file's own length (plus lead and tail), how long a play may run
/// before it is stopped anyway: a device that stops calling back would
/// otherwise hold the transmitter until the PTT key's own minute.
const computerVoicePlayMargin = Duration(seconds: 2);

/// How long the radio's sound device stays open with nothing played into
/// it. Held open, a message starts without opening a device; closed after
/// this, a station left alone does not hold the device for good.
const computerVoiceIdleRelease = Duration(minutes: 5);

/// A recording shorter than this is a Record pressed and stopped by mistake,
/// and replaces nothing.
const computerVoiceShortestRecording = Duration(milliseconds: 300);

/// A recording whose loudest sample stayed under this (about -60 dBFS) heard
/// nothing at all — a muted input, or the microphone permission refused,
/// which macOS answers with silence rather than an error — and replaces
/// nothing.
const computerVoiceSilence = 0.001;

const _recordingSuffix = '.recording';

/// Where a kept recording's loudest sample is raised to (-1 dBFS), and the
/// most it is raised by (+20 dB). A laptop mic at its default gain records a
/// voice peaking around -15 dBFS, which plays fine through speakers turned
/// up and barely moves a radio's transmit audio, which nothing turns up.
/// The cap keeps a quiet recording from becoming mostly room noise.
const computerVoiceNormalizedPeak = 0.891;
const computerVoiceMaxBoost = 10.0;

/// How a kept recording is trimmed to the voice in it. A recording runs from
/// Record to Stop, and the room before and after the voice is raised by the
/// normalizing with it — quiet through the computer's speakers, hiss on the
/// air once a radio's speech processor lifts it. Measured against the room's
/// own noise rather than the voice's peak: a laptop mic's room comes within
/// 30 dB of a voice, and a line set from the peak keeps the room. Runs under
/// 40 ms are not sound — the click of Record or Stop, at an end of every
/// recording made with a mouse beside the mic — and the last 100 ms go
/// unmeasured, since Stop is pressed there and its click can run longer.
/// The lead is shorter than the tail because a voice starts sharply and
/// fades.
const computerVoiceTrim = AudioTrim(
  aboveFloorDb: 12,
  belowLoudestDb: 20,
  minSound: Duration(milliseconds: 40),
  lead: Duration(milliseconds: 100),
  tail: Duration(milliseconds: 200),
  cutEnd: Duration(milliseconds: 100),
);

/// How often a recording's level is read.
const _levelInterval = Duration(milliseconds: 100);

/// A stored `{id, name}` device choice.
({String? id, String? name})? voiceDeviceFromConfig(Object? raw) {
  if (raw is! Map) return null;
  final id = raw['id'], name = raw['name'];
  if (id is! String && name is! String) return null;
  return (id: id is String ? id : null, name: name is String ? name : null);
}

Map<String, dynamic> voiceDeviceToConfig(AudioDevice device) => {'id': device.id, 'name': device.name};

Duration _millis(Object? raw, Duration fallback) => raw is num && raw >= 0 ? Duration(milliseconds: raw.round()) : fallback;

/// What went wrong the last time the keyer was asked to do something — said
/// to the operator by the Phone Keyer dialog, since none of it is a bug.
enum ComputerVoiceProblem {
  /// No output device is picked: there is nowhere to send the audio.
  noOutput,

  /// The picked output device is not connected.
  outputMissing,

  /// The picked input device is not connected.
  inputMissing,

  /// The device is listed but would not open, or the file would not play.
  deviceFailed,

  /// The memory has no recording.
  notRecorded,

  /// The recording heard nothing, and was not kept.
  recordingSilent,

  /// The radio's CAT cannot key it, so the computer cannot play into it.
  cannotKey,

  /// The radio takes the audio over its network link, and that link is not
  /// up — or the radio refused the stream.
  radioAudioUnavailable,
}

/// The sound system as the keyer uses it — [HaloVoiceAudio] in the app, a
/// fake in the tests.
abstract class VoiceAudio {
  bool get isSupported;
  List<AudioDevice> outputs();
  List<AudioDevice> inputs();
  Duration? lengthOf(String path);
  AudioOutput openOutput({required String deviceId});

  /// Plays [path] on the system's default output, never into a keyed radio:
  /// the operator hearing what they recorded.
  AudioPlayback listen(String path);
  AudioRecording record(String path, {String? deviceId});

  /// Moves [from] over [to], making [to]'s directory if needed.
  void replace(String from, String to);

  /// [path] as interleaved float samples — what a radio that takes its
  /// audio over the network is sent ([PcmDecoder]).
  Float32List decode(String path, {required int rate, required int channels});

  /// Rewrites the recording at [path] trimmed of the quiet before and after
  /// the voice ([computerVoiceTrim]), its loudest sample raised to
  /// [computerVoiceNormalizedPeak] by no more than [computerVoiceMaxBoost].
  void normalize(String path);

  /// Copies [from] to [to], making [to]'s directory if needed.
  void copy(String from, String to);
  void delete(String path);

  /// Deletes [path] and everything in it — a set's recordings.
  void deleteDirectory(String path);

  /// Opens [path]'s folder in the system's file manager — made first if it
  /// is not there, so a sound file can be put in it — with the file
  /// selected where the system can and the file exists.
  void reveal(String path);
}

class HaloVoiceAudio implements VoiceAudio {
  /// Each recording's length, by path, with the modification time it was
  /// read at: the surfaces ask for every message's length on every rebuild,
  /// and decoding a file each time would be dozens of file opens a second.
  final _lengths = <String, (DateTime, Duration?)>{};

  @override
  bool get isSupported => HaloAudio.isSupported;

  @override
  List<AudioDevice> outputs() => HaloAudio.playbackDevices();

  @override
  List<AudioDevice> inputs() => HaloAudio.captureDevices();

  @override
  Duration? lengthOf(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      _lengths.remove(path);
      return null;
    }
    final modified = file.lastModifiedSync();
    final cached = _lengths[path];
    if (cached != null && cached.$1 == modified) return cached.$2;
    final length = HaloAudio.fileLength(path);
    _lengths[path] = (modified, length);
    return length;
  }

  @override
  AudioOutput openOutput({required String deviceId}) => HaloAudio.openOutput(deviceId: deviceId);

  @override
  AudioPlayback listen(String path) {
    final output = HaloAudio.openOutput();
    try {
      final playback = output.play(path);
      // Closed a moment after the end, once the device has sounded it.
      unawaited(playback.done.then((_) => Future<void>.delayed(defaultVoiceTail, output.close)));
      return playback;
    } catch (_) {
      output.close();
      rethrow;
    }
  }

  @override
  AudioRecording record(String path, {String? deviceId}) {
    File(path).parent.createSync(recursive: true);
    return HaloAudio.record(path, deviceId: deviceId);
  }

  @override
  void replace(String from, String to) {
    File(to).parent.createSync(recursive: true);
    File(from).renameSync(to);
    _lengths.remove(from);
    _lengths.remove(to);
  }

  @override
  Float32List decode(String path, {required int rate, required int channels}) => HaloAudio.decode(path, rate: rate, channels: channels);

  @override
  void normalize(String path) {
    final scaled = '$path.normalized';
    HaloAudio.normalize(path, scaled, peak: computerVoiceNormalizedPeak, maxGain: computerVoiceMaxBoost, trim: computerVoiceTrim);
    File(scaled).renameSync(path);
    _lengths.remove(path);
  }

  @override
  void copy(String from, String to) {
    File(to).parent.createSync(recursive: true);
    File(from).copySync(to);
    _lengths.remove(to);
  }

  @override
  void delete(String path) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    _lengths.remove(path);
  }

  @override
  void deleteDirectory(String path) {
    final dir = Directory(path);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    _lengths.removeWhere((file, _) => file.startsWith('$path/'));
  }

  @override
  void reveal(String path) {
    // Explorer reads a forward slash in /select as a switch, not a path.
    if (Platform.isWindows) path = path.replaceAll('/', r'\');
    final file = File(path);
    final folder = file.parent..createSync(recursive: true);
    final exists = file.existsSync();
    final (command, arguments) = Platform.isMacOS
        ? ('open', exists ? ['-R', path] : [folder.path])
        : Platform.isWindows
        ? ('explorer.exe', exists ? ['/select,', path] : [folder.path])
        // No file manager on Linux that every desktop agrees selects a file.
        : ('xdg-open', [folder.path]);
    unawaited(
      Process.start(
        command,
        arguments,
        mode: ProcessStartMode.detached,
      ).then<void>((_) {}, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'voice:reveal')),
    );
  }
}

enum _Phase { idle, leadIn, playing, tail, recording }

class ComputerVoiceKeyer implements VoiceKeyer {
  /// Opens the radio's sound device at once, so the first message does not
  /// wait for it either — unless there is no radio, when it only records.
  ComputerVoiceKeyer({required this.ptt, required this.audio, required this.config, required this.fileFor, required this.report}) {
    if (ptt == null) return;
    if (_toRadio) {
      _openRadio();
    } else {
      final wanted = voiceDeviceFromConfig(config()[voiceOutputConfigKey]);
      final device = wanted == null ? null : _findOutput(wanted);
      if (device != null) _openOutput(device);
    }
    _scheduleRelease();
  }

  /// [_outputId] for the radio's own audio link: no device id is empty, or
  /// starts with a NUL.
  static const _radioOutputId = '\u0000radio';

  /// Whether the audio goes to the radio itself: picked, or nothing picked
  /// on a radio that takes it.
  bool get _toRadio {
    final session = ptt;
    if (session is! NetworkTransmitAudioSession || !session.sendsTransmitAudio) return false;
    final raw = config()[voiceOutputConfigKey];
    return raw == null || voiceOutputIsRadio(raw);
  }

  /// Whether the audio goes to the radio itself rather than a sound device.
  bool get playsToRadio => _toRadio;

  /// The radio this keyer keys. The session's own teardown unkeys it, so a
  /// keyer whose session closed only has to go quiet ([dispose]). Null for
  /// the recorder used while no radio is there to key: the messages are
  /// recorded before the rig is on the desk, and nothing plays.
  final PttSession? ptt;
  final VoiceAudio audio;

  /// The radio node's config, read at every play: the operator may change a
  /// device between two of them.
  final Map<String, dynamic> Function() config;

  /// Where memory [n]'s recording is kept.
  final String Function(int n) fileFor;

  /// What the keyer is doing, the way a radio's session reports its own
  /// memories (EquipmentSink.reportVoiceActivity).
  final void Function(VoiceActivity? activity) report;

  _Phase _phase = _Phase.idle;
  int? _memory;
  Timer? _timer;
  Timer? _ceiling;
  AudioPlayback? _playback;
  AudioRecording? _recording;
  String? _recordingTo;
  Timer? _levels;
  double _loudest = 0;

  /// The radio's sound device, held open between messages until
  /// [computerVoiceIdleRelease] passes with nothing played.
  AudioOutput? _output;
  String? _outputId;
  Timer? _release;

  /// The output devices as last listed: listed again only when a stored
  /// device is not among them, or will not open.
  List<AudioDevice>? _outputs;

  /// Whether the app holds the radio keyed for a message — what keeps the
  /// "on the air" reading true for a radio that cannot report TX.
  bool get keyed => _keyed;
  bool _keyed = false;

  /// Whether the radio has said it is transmitting since this keyer keyed it.
  bool _confirmed = false;

  /// The last thing that went wrong, until the next thing asked of the keyer.
  ComputerVoiceProblem? get problem => _problem;
  ComputerVoiceProblem? _problem;

  /// Whether the radio's sound device is open right now.
  @visibleForTesting
  bool get outputOpen => _output != null;

  @override
  int get voiceMemoryCount => maxVoiceMemories;

  @override
  bool get canRecordVoice => true;

  @override
  Duration get voiceMemoryCeiling => computerVoiceRecordingCeiling;

  @override
  void playVoiceMemory(int n) {
    _quiet();
    _release?.cancel();
    _problem = null;
    if (ptt == null) return _refuse(n, ComputerVoiceProblem.cannotKey);
    final path = fileFor(n);
    final length = audio.lengthOf(path);
    if (length == null || length == Duration.zero) return _refuse(n, ComputerVoiceProblem.notRecorded);
    // The device is found and open BEFORE the radio is keyed: keyed with
    // nowhere to send the audio is a dead carrier, and the system default is
    // never a stand-in — a CQ in the laptop's speakers while the radio
    // transmits silence.
    final c = config();
    AudioOutput? output;
    if (_toRadio) {
      output = _openRadio();
      if (output == null) return _refuse(n, ComputerVoiceProblem.radioAudioUnavailable);
    } else {
      final wanted = voiceDeviceFromConfig(c[voiceOutputConfigKey]);
      if (wanted == null) return _refuse(n, ComputerVoiceProblem.noOutput);
      var device = _findOutput(wanted);
      output = device == null ? null : _openOutput(device);
      if (output == null) {
        // The list it was found in may be older than an unplug or a replug.
        _outputs = null;
        device = _findOutput(wanted);
        if (device == null) return _refuse(n, ComputerVoiceProblem.outputMissing);
        output = _openOutput(device);
        if (output == null) return _refuse(n, ComputerVoiceProblem.deviceFailed);
      }
    }
    final lead = _millis(c[voiceLeadConfigKey], defaultVoiceLead);
    final tail = _millis(c[voiceTailConfigKey], defaultVoiceTail);

    if (output case final SilenceFedOutput fed) {
      try {
        fed.startSilence(path);
      } on HaloAudioException catch (e, st) {
        ErrorReportingService.report(e, st, context: 'voice:play');
        return _refuse(n, ComputerVoiceProblem.deviceFailed);
      }
    }

    _memory = n;
    _phase = _Phase.leadIn;
    report(VoiceActivity(memory: n));
    try {
      _key();
    } catch (_) {
      // The driver marked itself keyed before the command went, so its
      // teardown still unkeys; another command now would only throw again.
      _keyed = false;
      _phase = _Phase.idle;
      _memory = null;
      report(null);
      _scheduleRelease();
      rethrow;
    }
    _ceiling = Timer(lead + length + tail + computerVoicePlayMargin, stopVoice);
    _timer = Timer(lead, () {
      try {
        final playback = output!.play(path);
        _playback = playback;
        _phase = _Phase.playing;
        unawaited(
          playback.done.then((_) {
            if (!identical(_playback, playback) || _phase != _Phase.playing) return;
            // The device keeps sounding what it holds of the end, then
            // silence, while the unkey waits.
            _phase = _Phase.tail;
            _timer = Timer(tail, _finish);
          }),
        );
      } on HaloAudioException catch (e, st) {
        ErrorReportingService.report(e, st, context: 'voice:play');
        _fail(ComputerVoiceProblem.deviceFailed);
      }
    });
  }

  /// A play that failed once keyed: unkeyed, and shown doubtful before it
  /// clears, as a refusal is — which is also what ends a repeat of it rather
  /// than keying the radio for it again each cooldown.
  void _fail(ComputerVoiceProblem problem) {
    final n = _memory;
    _quiet();
    _problem = problem;
    if (n == null) return report(null);
    _memory = n;
    report(VoiceActivity(memory: n, doubtful: true));
    _timer = Timer(voiceDoubtLinger, () {
      _memory = null;
      report(null);
    });
  }

  @override
  void recordVoiceMemory(int n) {
    _quiet();
    _problem = null;
    final wanted = voiceDeviceFromConfig(config()[voiceInputConfigKey]);
    String? deviceId;
    if (wanted != null) {
      final device = matchAudioDevice(audio.inputs(), id: wanted.id, name: wanted.name);
      if (device == null) return _refuse(n, ComputerVoiceProblem.inputMissing, recording: true);
      deviceId = device.id;
    }
    // Into a file beside the memory's, moved over it only once it is done:
    // a recording that fails to start leaves the message it would have
    // replaced.
    final to = '${fileFor(n)}$_recordingSuffix';
    try {
      _recording = audio.record(to, deviceId: deviceId);
    } on HaloAudioException {
      return _refuse(n, ComputerVoiceProblem.deviceFailed, recording: true);
    }
    _recordingTo = to;
    _memory = n;
    _phase = _Phase.recording;
    _loudest = 0;
    _levels = Timer.periodic(_levelInterval, (_) => _readLevel());
    report(VoiceActivity(memory: n, recording: true));
    _ceiling = Timer(computerVoiceRecordingCeiling, stopVoice);
  }

  @override
  void stopVoice() {
    final shown = _memory != null;
    _quiet();
    if (shown) report(null);
  }

  /// The radio reported its TX state. Once it has said it is transmitting, a
  /// "not transmitting" is the radio dropping the key itself — its own
  /// time-out timer, a mic switch — and the message goes with it, unkeyed
  /// anyway since a CAT key is latched. Before that, it is the poll that was
  /// already on the wire as the key went out (cat_ptt.dart says the same).
  void onTransmitting(bool transmitting) {
    if (!_keyed) return;
    if (transmitting) {
      _confirmed = true;
    } else if (_confirmed) {
      stopVoice();
    }
  }

  /// The session is closing: its own teardown unkeys the radio, and an unkey
  /// sent after it would go to a closed connection.
  void dispose() {
    _keyed = false;
    stopVoice();
    _closeOutput();
  }

  AudioDevice? _findOutput(({String? id, String? name}) wanted) {
    final listed = _outputs;
    final found = listed == null ? null : matchAudioDevice(listed, id: wanted.id, name: wanted.name);
    if (found != null) return found;
    try {
      _outputs = audio.outputs();
    } on HaloAudioException {
      _outputs = const [];
    }
    return matchAudioDevice(_outputs!, id: wanted.id, name: wanted.name);
  }

  /// [device], open — the one held open when it is still that device and
  /// still running. Null when it will not open.
  AudioOutput? _openOutput(AudioDevice device) {
    final current = _output;
    if (current != null && _outputId == device.id && current.isAlive) return current;
    _closeOutput();
    try {
      final output = audio.openOutput(deviceId: device.id);
      _output = output;
      _outputId = device.id;
      unawaited(output.gone.then((_) => _outputGone(output)));
      return output;
    } on HaloAudioException {
      return null;
    }
  }

  /// The radio's own audio link, open — the one held open while it is still
  /// alive. Null while the session cannot carry it.
  AudioOutput? _openRadio() {
    final current = _output;
    if (current != null && _outputId == _radioOutputId && current.isAlive) return current;
    _closeOutput();
    final output = (ptt as NetworkTransmitAudioSession).openTransmitAudio(audio.decode);
    if (output == null) return null;
    _output = output;
    _outputId = _radioOutputId;
    unawaited(output.gone.then((_) => _outputGone(output)));
    return output;
  }

  /// The device went away under an open output — unplugged, or the radio no
  /// longer taking its audio. A message going into it stops, since nothing
  /// more reaches the radio.
  void _outputGone(AudioOutput output) {
    if (!identical(_output, output)) return;
    _outputs = null;
    if (_phase != _Phase.idle && _phase != _Phase.recording) {
      _fail(_outputId == _radioOutputId ? ComputerVoiceProblem.radioAudioUnavailable : ComputerVoiceProblem.outputMissing);
    }
    _closeOutput();
  }

  void _closeOutput() {
    _release?.cancel();
    _release = null;
    _output?.close();
    _output = null;
    _outputId = null;
  }

  void _scheduleRelease() {
    _release?.cancel();
    _release = _output == null ? null : Timer(computerVoiceIdleRelease, _closeOutput);
  }

  void _readLevel() {
    final recording = _recording;
    if (recording != null) _loudest = math.max(_loudest, recording.takePeak());
  }

  /// Memory [n] said no before anything happened: shown as doubtful, the way
  /// a radio's refused memory is, then cleared.
  void _refuse(int n, ComputerVoiceProblem problem, {bool recording = false}) {
    _problem = problem;
    _memory = n;
    _scheduleRelease();
    report(VoiceActivity(memory: n, recording: recording, doubtful: true));
    _timer = Timer(voiceDoubtLinger, () {
      _memory = null;
      report(null);
    });
  }

  void _finish() {
    _quiet();
    report(null);
  }

  /// Everything stopped, and the radio unkeyed if this keyer keyed it; the
  /// recording, if one was running, kept as the memory's when it heard
  /// something. The device stays open for the next message.
  void _quiet() {
    _timer?.cancel();
    _ceiling?.cancel();
    _levels?.cancel();
    _timer = _ceiling = _levels = null;
    _playback?.stop();
    _playback = null;
    _readLevel();
    final recording = _recording, to = _recordingTo;
    _recording = null;
    _recordingTo = null;
    _phase = _Phase.idle;
    _memory = null;
    if (recording != null) {
      recording.stop();
      if (to != null) _keep(to);
    }
    _scheduleRelease();
    _unkey();
  }

  void _keep(String recorded) {
    try {
      final length = audio.lengthOf(recorded);
      if (length == null || length < computerVoiceShortestRecording) return audio.delete(recorded);
      if (_loudest < computerVoiceSilence) {
        _problem = ComputerVoiceProblem.recordingSilent;
        return audio.delete(recorded);
      }
      try {
        audio.normalize(recorded);
      } on HaloAudioException {
        // Kept as recorded: quieter than the others, but the operator's
        // message, where throwing it away would lose it for a level.
      }
      // Where the recording started, not where [fileFor] points now: the set
      // in use can change while it runs.
      audio.replace(recorded, recorded.substring(0, recorded.length - _recordingSuffix.length));
    } on FileSystemException {
      _problem = ComputerVoiceProblem.deviceFailed;
    }
  }

  void _key() {
    // Marked before the command goes, so a throw leaves an unkey to send.
    _keyed = true;
    _confirmed = false;
    _setPtt(true);
  }

  void _unkey() {
    if (!_keyed) return;
    _keyed = false;
    _confirmed = false;
    _setPtt(false);
  }

  /// With the radio's transmit audio switched to the computer where its CAT
  /// can do that: keyed plainly, a radio set up for its mic sends the mic.
  void _setPtt(bool on) {
    final session = ptt;
    if (session is ComputerAudioPttSession && session.switchesToComputerAudio) {
      session.setPttWithComputerAudio(on);
    } else {
      session?.setPtt(on);
    }
  }

  /// Whether a key switches the radio's transmit audio to the computer by
  /// itself, so the operator need not set it on the radio.
  bool get switchesAudio {
    final session = ptt;
    return session is ComputerAudioPttSession && session.switchesToComputerAudio;
  }
}

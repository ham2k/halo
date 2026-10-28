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

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
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

  /// The memory's file is there, and not a sound file this app can read —
  /// or broke off partway through playing.
  unplayable,

  /// The message is a template, and says words the operator has not
  /// recorded, or characters no word spells — named in the problem's detail.
  wordsMissing,

  /// The message is a template that does not render — the renderer's own
  /// words in the detail.
  templateFailed,

  /// The message is a template, and there is no contact to render it
  /// against: no operation open.
  noOperation,

  /// The message is a template that renders to nothing to say.
  nothingSaid,

  /// The recording was cut short — the device went away, or the file could
  /// not be written or read back — and the message was left as it was.
  recordingFailed,

  /// The recording could not be put in the message's place, and the message
  /// was left as it was.
  fileFailed,
}

/// A sound-system or file failure the keyer met and dealt with — the
/// message refused or cut short, the recording kept as it was or not kept —
/// and told the operator about through [ComputerVoiceProblem]. Reported for
/// the reason underneath, which the problem's text leaves out
/// (error_policy.dart's `voice-audio-failure`).
///
/// The reason only, never the failure itself: a file or process error names
/// its path, and a path under the operator's home names their OS account,
/// which goes out only behind the consent gate (error-reporting.md).
class VoiceAudioFailure implements Exception {
  /// What the keyer was doing: `play`, `record`, `keep`, `normalize`, ….
  final String doing;
  final String reason;

  VoiceAudioFailure(this.doing, Object cause) : reason = _withoutPath(cause);

  static String _withoutPath(Object cause) => switch (cause) {
    FileSystemException(:final message, :final osError) => 'FileSystemException: $message${osError == null ? '' : ' ($osError)'}',
    ProcessException(:final executable, :final message, :final errorCode) => 'ProcessException: $executable: $message (error $errorCode)',
    _ => '$cause',
  };

  @override
  String toString() => 'VoiceAudioFailure($doing): $reason';
}

/// Each reason already uploaded this session. A device another program
/// holds fails the same way on every key pressed, and each upload after the
/// first says nothing new; the console still has every one.
final _voiceFailuresReported = <String>{};

void reportVoiceFailure(String doing, Object cause, StackTrace stack) {
  // Only the sound system's own failures are wrapped: the rule that keeps
  // them off the screen (voice-audio-failure) must not hide a bug.
  if (!isVoiceAudioFailure(cause)) return ErrorReportingService.report(cause, stack, context: 'voice:$doing');
  final failure = VoiceAudioFailure(doing, cause);
  if (_voiceFailuresReported.add('$failure')) {
    ErrorReportingService.report(failure, stack, context: 'voice:$doing');
  } else {
    debugPrint('[voice] again: $failure');
  }
}

/// Whether [error] is the sound system's or the file system's — a device,
/// a file — rather than a bug in the code around them.
bool isVoiceAudioFailure(Object error) => error is HaloAudioException || error is FileSystemException;

/// Forgets which reasons were uploaded: each test starts a session of its own.
@visibleForTesting
void forgetVoiceFailuresReported() => _voiceFailuresReported.clear();

/// A message made at play time that cannot be made — see
/// [ComputerVoiceKeyer.prepare]. Said to the operator, and not itself
/// reported: it is their template or their recordings, not a bug.
class VoicedMessageRefused implements Exception {
  final ComputerVoiceProblem problem;

  /// What it was: the words missing, the renderer's complaint.
  final String? detail;

  /// A failure behind the refusal — a hook timing out as the template
  /// renders — reported where the refusal is shown, which is what says
  /// whether the operator was told.
  final Object? cause;
  final StackTrace? causeStack;

  const VoicedMessageRefused(this.problem, [this.detail, this.cause, this.causeStack]);

  @override
  String toString() => 'VoicedMessageRefused(${problem.name}${detail == null ? '' : ': $detail'})';
}

/// The sound system as the keyer uses it — [HaloVoiceAudio] in the app, a
/// fake in the tests.
abstract class VoiceAudio {
  bool get isSupported;
  List<AudioDevice> outputs();
  List<AudioDevice> inputs();
  Duration? lengthOf(String path);

  /// Whether there is a file at [path] at all: with [lengthOf] null, one
  /// that cannot be decoded.
  bool exists(String path);
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

  /// Writes [bytes] — a sound file this app made — to [path], making its
  /// directory if needed.
  void write(String path, Uint8List bytes);
  void delete(String path);

  /// Deletes [path] and everything in it — a set's recordings.
  void deleteDirectory(String path);

  /// Opens [path]'s folder in the system's file manager — made first if it
  /// is not there, so a sound file can be put in it — with the file
  /// selected where the system can and the file exists.
  void reveal(String path);
}

class HaloVoiceAudio implements VoiceAudio {
  /// [elapsedMillis] is a steady clock: a test's fake one, else a stopwatch.
  /// Never the wall clock, which a correction can step back, leaving every
  /// entry unasked for as long as it stepped.
  HaloVoiceAudio({@visibleForTesting int Function()? elapsedMillis}) : _elapsedMillis = elapsedMillis ?? _stopwatchMillis();

  final int Function() _elapsedMillis;

  static int Function() _stopwatchMillis() {
    final watch = Stopwatch()..start();
    return () => watch.elapsedMilliseconds;
  }

  /// Each recording's length, by path — null for no file — with the
  /// modification time it was read at and when the disk was last asked. The
  /// surfaces ask for every message's length on every rebuild, several times
  /// a second, so the disk is asked again only [recheckAfter] later: this
  /// app's own writes forget the entry at once, and a file the operator puts
  /// in the folder by hand shows within it.
  final _lengths = <String, ({int checkedAt, DateTime? modified, Duration? length})>{};

  @visibleForTesting
  static const recheckAfter = Duration(seconds: 1);

  @override
  bool get isSupported => HaloAudio.isSupported;

  @override
  List<AudioDevice> outputs() => HaloAudio.playbackDevices();

  @override
  List<AudioDevice> inputs() => HaloAudio.captureDevices();

  @override
  Duration? lengthOf(String path) {
    final now = _elapsedMillis();
    final cached = _lengths[path];
    if (cached != null && now - cached.checkedAt < recheckAfter.inMilliseconds) return cached.length;
    final file = File(path);
    final modified = file.existsSync() ? file.lastModifiedSync() : null;
    final length = switch (modified) {
      null => null,
      _ when modified == cached?.modified => cached!.length,
      _ => HaloAudio.fileLength(path),
    };
    _lengths[path] = (checkedAt: now, modified: modified, length: length);
    return length;
  }

  @override
  bool exists(String path) {
    lengthOf(path);
    return _lengths[path]?.modified != null;
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
    try {
      HaloAudio.normalize(path, scaled, peak: computerVoiceNormalizedPeak, maxGain: computerVoiceMaxBoost, trim: computerVoiceTrim);
      File(scaled).renameSync(path);
    } on Object {
      // A copy written partway, or one that would not take the recording's
      // place, is no recording, and nothing else removes it.
      try {
        final partial = File(scaled);
        if (partial.existsSync()) partial.deleteSync();
      } on FileSystemException {
        // Left behind: the failure rethrown below is the one the caller
        // reports, and the recording itself is untouched.
      }
      rethrow;
    } finally {
      _lengths.remove(path);
    }
  }

  @override
  void copy(String from, String to) {
    File(to).parent.createSync(recursive: true);
    File(from).copySync(to);
    _lengths.remove(to);
  }

  @override
  void write(String path, Uint8List bytes) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes, flush: true);
    _lengths.remove(path);
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
      ).then<void>((_) {}, onError: (Object e, StackTrace st) => reportVoiceFailure('reveal', e, st)),
    );
  }
}

enum _Phase { idle, preparing, leadIn, playing, tail, recording }

class ComputerVoiceKeyer implements VoiceKeyer {
  /// Opens the radio's sound device at once, so the first message does not
  /// wait for it either — unless there is no radio, when it only records.
  ComputerVoiceKeyer({required this.ptt, required this.audio, required this.config, required this.fileFor, required this.report, this.prepare}) {
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

  /// Memory [n] made at play time rather than recorded — a template voiced
  /// from the operator's words (voice_words.dart): the file to play once it
  /// is made, failing with [VoicedMessageRefused] when it cannot be. Null
  /// for a memory that is its own recording. Made before anything is keyed,
  /// so a message that cannot be made puts no carrier on the air.
  final Future<String>? Function(int n)? prepare;

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

  /// What [problem] was about, where it says: the words a template needs and
  /// has no recording of, a template's error.
  String? get problemDetail => _problemDetail;
  String? _problemDetail;

  /// Counts every stop and every play, so a message still being made when
  /// the operator moved on is dropped when it is ready rather than keyed.
  int _turn = 0;

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
    // Cleared before the quiet, which may end a recording with a problem of
    // its own: that one is what the operator needs to see.
    _problem = null;
    _problemDetail = null;
    _quiet();
    _release?.cancel();
    if (ptt == null) return _refuse(n, ComputerVoiceProblem.cannotKey);
    final made = prepare?.call(n);
    if (made == null) return _play(n, fileFor(n));
    final turn = _turn;
    _memory = n;
    _phase = _Phase.preparing;
    report(VoiceActivity(memory: n));
    unawaited(
      made.then(
        (path) {
          if (turn != _turn) return;
          _phase = _Phase.idle;
          try {
            _play(n, path);
          } catch (e, st) {
            // What the key's own catch reports for a recording, out of its reach here.
            ErrorReportingService.report(e, st, context: 'cat:play-voice-memory');
          }
        },
        onError: (Object e, StackTrace st) {
          // Reported whether or not the play it was for is still wanted: a
          // failure is one either way.
          if (e is! VoicedMessageRefused) reportVoiceFailure('voice', e, st);
          if (turn != _turn) return;
          _phase = _Phase.idle;
          if (e is VoicedMessageRefused) {
            _problemDetail = e.detail;
            return _refuse(n, e.problem);
          }
          _refuse(n, ComputerVoiceProblem.unplayable);
        },
      ),
    );
  }

  void _play(int n, String path) {
    final length = audio.lengthOf(path);
    if (length == null && audio.exists(path)) return _refuse(n, ComputerVoiceProblem.unplayable);
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
        reportVoiceFailure('play', e, st);
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
            if (playback.failed) {
              reportVoiceFailure('play', HaloAudioException('play: the file broke off partway'), StackTrace.current);
              return _fail(ComputerVoiceProblem.unplayable);
            }
            // The device keeps sounding what it holds of the end, then
            // silence, while the unkey waits.
            _phase = _Phase.tail;
            _timer = Timer(tail, _finish);
          }),
        );
      } on HaloAudioException catch (e, st) {
        reportVoiceFailure('play', e, st);
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
    _problem = null;
    _problemDetail = null;
    _quiet();
    final problem = _startRecording(fileFor(n), computerVoiceRecordingCeiling);
    if (problem != null) return _refuse(n, problem, recording: true);
    _memory = n;
    report(VoiceActivity(memory: n, recording: true));
  }

  /// Records into [path] — a word of the operator's word set rather than a
  /// message (voice_words.dart) — for at most [ceiling], then calls [done]
  /// with the path once the recording is kept, or null when it was not (its
  /// [problem] says why, where there is one). False when it could not start.
  /// Reports no activity: no message is recording, and the pane that asked
  /// follows it itself.
  bool recordFile(String path, {required Duration ceiling, required void Function(String? kept) done}) {
    _problem = null;
    _problemDetail = null;
    // stopVoice, not _quiet: a message shown playing or refused ends here,
    // and must say so.
    stopVoice();
    final problem = _startRecording(path, ceiling);
    if (problem != null) {
      _problem = problem;
      return false;
    }
    _done = done;
    return true;
  }

  /// Whether a recording is running.
  bool get recording => _phase == _Phase.recording;

  /// Who hears a [recordFile] end.
  void Function(String? kept)? _done;

  /// Starts recording what will become [target], or says why it could not.
  ComputerVoiceProblem? _startRecording(String target, Duration ceiling) {
    final wanted = voiceDeviceFromConfig(config()[voiceInputConfigKey]);
    String? deviceId;
    if (wanted != null) {
      final device = matchAudioDevice(audio.inputs(), id: wanted.id, name: wanted.name);
      if (device == null) return ComputerVoiceProblem.inputMissing;
      deviceId = device.id;
    }
    // Into a file beside the memory's, moved over it only once it is done:
    // a recording that fails to start leaves the message it would have
    // replaced.
    final to = '$target$_recordingSuffix';
    try {
      _recording = audio.record(to, deviceId: deviceId);
    } on HaloAudioException catch (e, st) {
      reportVoiceFailure('record', e, st);
      return ComputerVoiceProblem.deviceFailed;
    }
    _recordingTo = to;
    _phase = _Phase.recording;
    _loudest = 0;
    _levels = Timer.periodic(_levelInterval, (_) => _readLevel());
    _ceiling = Timer(ceiling, stopVoice);
    return null;
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
    } on HaloAudioException catch (e, st) {
      reportVoiceFailure('devices', e, st);
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
    } on HaloAudioException catch (e, st) {
      reportVoiceFailure('open', e, st);
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
    _turn++;
    _timer?.cancel();
    _ceiling?.cancel();
    _levels?.cancel();
    _timer = _ceiling = _levels = null;
    _playback?.stop();
    _playback = null;
    _readLevel();
    final recording = _recording, to = _recordingTo, done = _done;
    _recording = null;
    _recordingTo = null;
    _done = null;
    _phase = _Phase.idle;
    _memory = null;
    if (recording != null) {
      var whole = true;
      try {
        recording.stop();
      } on HaloAudioException catch (e, st) {
        // Cut short, the file holds a message with its end missing: the one
        // it would replace is the better one to keep.
        reportVoiceFailure('record', e, st);
        _problem = ComputerVoiceProblem.recordingFailed;
        whole = false;
      }
      String? kept;
      if (to != null) {
        if (whole) {
          kept = _keep(to);
        } else {
          _discard(to);
        }
      }
      done?.call(kept);
    }
    _scheduleRelease();
    _unkey();
  }

  /// Where the recording was kept, or null when it was not.
  String? _keep(String recorded) {
    try {
      final length = audio.lengthOf(recorded);
      if (length == null && audio.exists(recorded)) {
        // Written, and not readable back: a recording that failed, not a
        // Record pressed by mistake.
        reportVoiceFailure('keep', HaloAudioException('keep: the recording could not be read back'), StackTrace.current);
        _problem = ComputerVoiceProblem.recordingFailed;
        _discard(recorded);
        return null;
      }
      if (length == null || length < computerVoiceShortestRecording) {
        _discard(recorded);
        return null;
      }
      if (_loudest < computerVoiceSilence) {
        _problem = ComputerVoiceProblem.recordingSilent;
        _discard(recorded);
        return null;
      }
      try {
        audio.normalize(recorded);
      } on Exception catch (e, st) {
        // Kept as recorded: quieter than the others, and untrimmed, but the
        // operator's message, where throwing it away would lose it for a
        // level. Reported, since every recording would go out this way.
        reportVoiceFailure('normalize', e, st);
      }
      // Where the recording started, not where [fileFor] points now: the set
      // in use can change while it runs.
      final kept = recorded.substring(0, recorded.length - _recordingSuffix.length);
      audio.replace(recorded, kept);
      return kept;
    } on FileSystemException catch (e, st) {
      reportVoiceFailure('keep', e, st);
      _problem = ComputerVoiceProblem.fileFailed;
      _discard(recorded);
      return null;
    }
  }

  /// A recording not kept, gone rather than left beside the message as a
  /// file nothing reads.
  void _discard(String recorded) {
    try {
      audio.delete(recorded);
    } on FileSystemException catch (e, st) {
      reportVoiceFailure('discard', e, st);
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

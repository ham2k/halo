// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Transmit audio this app sends to a radio over the network itself, paced
// against the clock — what the FlexRadio DAX, Icom LAN and K4 remote audio
// outputs share (docs/design/cat.md § The computer's voice keyer). A radio
// plays what arrives as it arrives: sent faster, its buffer overflows and the
// end is lost; slower, it runs dry mid-word.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_audio/halo_audio.dart' show AudioPlayback, HaloAudioException;

import '../../error_reporting_service.dart';
import '../driver.dart' show PcmDecoder, SilenceFedOutput;

/// Packets sent ahead of the clock, for the timer's jitter, unless an
/// output says otherwise.
const _defaultAhead = 4;
const _tick = Duration(milliseconds: 5);

/// How long silence keeps going after a message ends or is stopped. The
/// keyer unkeys within its tail of the end, and a radio whose audio runs dry
/// while it is still on the air may transmit noise (a Flex on DAX does).
const transmitAudioSilenceAfter = Duration(seconds: 1);

/// The pacing, the silence around a message and the playbacks; a subclass
/// says when the radio is ready for packets and how one is sent.
abstract class PacedTransmitAudio implements SilenceFedOutput {
  PacedTransmitAudio({
    required this.decode,
    required this.rate,
    required this.channels,
    required this.framesPerPacket,
    this.ahead = _defaultAhead,
    this.feedsSilence = true,
    int Function()? clockMicros,
  }) : _clock = clockMicros ?? _stopwatchClock();

  final PcmDecoder decode;
  final int rate;
  final int channels;
  final int framesPerPacket;

  /// Packets sent ahead of the clock. A message's end is reported as its
  /// last packet goes, and the radio still has these to play: the keyer's
  /// unkey delay has to cover them.
  final int ahead;

  /// Whether silence goes out around a message. False for a radio that
  /// every packet keys (a K4), which [startSilence] and the tail after a
  /// message would put on the air before the key and after the unkey.
  final bool feedsSilence;

  /// Monotonic microseconds — the real clock, never the app's: packets are
  /// paced against real time whatever DEVTT says.
  final int Function() _clock;

  late final int _silenceAfterPackets = feedsSilence ? (transmitAudioSilenceAfter.inMicroseconds * rate / (1000000 * framesPerPacket)).ceil() : 0;

  final _gone = Completer<void>();
  bool _closed = false;
  Timer? _timer;
  int _startMicros = 0;
  int _packetsSent = 0;
  int _silenceUntil = 0;
  _PacedPlayback? _playing;

  /// The file [startSilence] decoded for the next play.
  (String, Float32List)? _ready;

  /// Whether the radio takes packets yet — a stream granted, a link open.
  /// Nothing is sent before: the clock waits with it, so the message starts
  /// late rather than cut.
  bool get ready;

  /// One packet: [framesPerPacket] frames of interleaved samples, or silence
  /// for null. Throws when it will not send.
  void sendFrames(Float32List? samples);

  /// A message, or the silence ahead of one, is on its way.
  void starting() {}

  /// Closed by the keyer: whatever the radio holds for this output goes.
  void closing() {}

  /// The [ErrorReportingService] context for a packet that will not send.
  String get reportContext;

  bool get closed => _closed;

  /// Whether the clock is running: silence or a message on its way.
  bool get running => _timer != null;

  @override
  Future<void> get gone => _gone.future;

  @override
  bool get isAlive => !_closed && !_gone.isCompleted;

  /// The radio refused the audio, or the link to it went: nothing more
  /// reaches the transmitter.
  void lost() {
    _timer?.cancel();
    _timer = null;
    _playing?._end();
    _playing = null;
    if (!_gone.isCompleted) _gone.complete();
  }

  @override
  AudioPlayback play(String path) {
    if (!isAlive) throw HaloAudioException('play: the radio is not taking audio');
    final ready = _ready;
    _ready = null;
    final samples = ready != null && ready.$1 == path ? ready.$2 : decode(path, rate: rate, channels: channels);
    _playing?._end();
    final playback = _PacedPlayback(this, samples);
    _playing = playback;
    starting();
    _run();
    _pump();
    return playback;
  }

  /// Silence from now: the keyer keys the radio and waits out its key-up
  /// delay before the message, and a radio keyed with nothing arriving may
  /// transmit noise for that long.
  ///
  /// Without [feedsSilence], only the decode: the message's first packet is
  /// the first to go.
  @override
  void startSilence(String next) {
    if (!isAlive) return;
    _ready = (next, decode(next, rate: rate, channels: channels));
    if (!feedsSilence) return;
    starting();
    _run();
    _silenceUntil = math.max(_silenceUntil, _packetsSent + _silenceAfterPackets);
    _pump();
  }

  /// The pacing clock, started from here unless it is running: a message
  /// that follows silence carries on the silence's clock, with no gap.
  void _run() {
    if (_timer != null) return;
    _startMicros = _clock();
    _packetsSent = 0;
    _silenceUntil = 0;
    _timer = Timer.periodic(_tick, (_) => _pump());
  }

  void _stop(_PacedPlayback playback) {
    if (!identical(_playing, playback)) return;
    _playing = null;
    _silenceUntil = _packetsSent + _silenceAfterPackets;
    playback._end();
  }

  void _pump() {
    if (!ready) {
      _startMicros = _clock();
      _packetsSent = 0;
      return;
    }
    final due = (_clock() - _startMicros) * rate ~/ (1000000 * framesPerPacket) + ahead;
    while (_packetsSent < due) {
      final playing = _playing;
      if (playing == null && _packetsSent >= _silenceUntil) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      final frames = playing?._next(framesPerPacket);
      if (playing != null && frames == null) {
        _stop(playing);
        continue;
      }
      try {
        sendFrames(frames);
      } on Exception catch (e, st) {
        // The socket fails every packet after the first: one report, and the
        // keyer hears the radio is no longer taking audio.
        ErrorReportingService.report(e, st, context: reportContext);
        return lost();
      }
      _packetsSent++;
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    _playing?._end();
    _playing = null;
    closing();
  }

  static int Function() _stopwatchClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsedMicroseconds;
  }
}

class _PacedPlayback implements AudioPlayback {
  _PacedPlayback(this._output, this._samples);

  final PacedTransmitAudio _output;
  final Float32List _samples;
  int _at = 0;
  final _done = Completer<void>();

  /// The next [frames] frames, padded with silence at the end; null once
  /// every one has gone.
  Float32List? _next(int frames) {
    if (_at >= _samples.length) return null;
    final channels = _output.channels;
    final end = math.min(_at + frames * channels, _samples.length);
    final chunk = Float32List(frames * channels)..setRange(0, end - _at, _samples, _at);
    _at = end;
    return chunk;
  }

  void _end() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;

  @override
  bool get isPlaying => !_done.isCompleted;

  /// Never: the whole file is decoded before the message starts, and one
  /// that will not decode is refused then.
  @override
  bool get failed => false;

  @override
  void stop() => _output._stop(this);
}

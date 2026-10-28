// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio's DAX transmit audio, sent by this app itself — docs/design/cat.md
// § The computer's voice keyer.
//
// Captured on a FLEX-6600 (4.2.20): a bound client's `stream create
// type=dax_tx` answers with a stream that client owns (`tx=0`), `stream set
// <id> tx=1` makes it the radio's DAX transmit source, and with `transmit
// dax=1` the radio puts on the air what arrives on it at UDP 4991. The
// payload is what the radio's own DAX audio carries (`dax_rx`, class
// 0x534C03E3: 128 frames of 24 kHz stereo float32, big-endian), but the
// packet is VITA type 1, IF data with a stream id: sent as type 3, the type
// the radio's own audio packets carry, the radio transmits nothing.
//
// Through a GUI client's virtual sound device instead, the audio depends on
// that client's own DAX transmit — AetherSDR's "TX" device does not reach the
// transmitter on that radio — and the operator has one more device to pick.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_audio/halo_audio.dart' show AudioPlayback, HaloAudioException;
import 'package:halo_core/halo_core.dart' show realNowMillis;

import '../../error_reporting_service.dart';
import '../driver.dart' show PcmDecoder, SilenceFedOutput;

const flexDaxRate = 24000;
const flexDaxChannels = 2;
const flexDaxPort = 4991;
const _framesPerPacket = 128;

/// Packets sent ahead of the clock, for the timer's jitter: 4 are about
/// 21 ms of audio.
const _ahead = 4;
const _tick = Duration(milliseconds: 5);

/// How long silence keeps going after a message ends or is stopped. The
/// keyer unkeys within its tail of the end, and a radio whose DAX runs dry
/// while it is still on the air transmits noise.
const flexDaxSilenceAfter = Duration(seconds: 1);

/// How long the radio has to answer `stream create` before the output is
/// given up: unanswered, the keyer would key a radio that never gets its
/// audio.
const flexDaxGrantTimeout = Duration(seconds: 2);

final _silenceAfterPackets = (flexDaxSilenceAfter.inMicroseconds * flexDaxRate / (1000000 * _framesPerPacket)).ceil();

class FlexDaxOutput implements SilenceFedOutput {
  FlexDaxOutput({required this.send, required this.sendPacket, required this.decode, this.diagnose, int Function()? clockMicros})
    : _clock = clockMicros ?? _stopwatchClock() {
    _create();
  }

  /// A command to the radio; [onReply] gets the answer's code and body.
  final void Function(String command, {void Function(int code, String body)? onReply}) send;

  /// A packet to the radio's [flexDaxPort].
  final void Function(Uint8List packet) sendPacket;
  final PcmDecoder decode;

  /// Why the radio would not take the audio, for the CAT recording.
  final void Function(String what)? diagnose;

  /// Monotonic microseconds — the real clock, never the app's: packets are
  /// paced against real time whatever DEVTT says.
  final int Function() _clock;

  final _gone = Completer<void>();
  bool _closed = false;
  int? _streamId;
  Timer? _timer;
  Timer? _grant;
  int _startMicros = 0;
  int _packetsSent = 0;
  int _silenceUntil = 0;
  int _count = 0;
  int _frames = 0;
  _FlexDaxPlayback? _playing;

  /// The file [startSilence] decoded for the next play.
  (String, Float32List)? _ready;

  void _create() {
    _grant = Timer(flexDaxGrantTimeout, () {
      if (_closed || _streamId != null) return;
      diagnose?.call('no answer to stream create in ${flexDaxGrantTimeout.inSeconds} s');
      lost();
    });
    send(
      'stream create type=dax_tx',
      onReply: (code, body) {
        _grant?.cancel();
        final id = int.tryParse(body.trim().replaceFirst('0x', ''), radix: 16);
        if (_closed) {
          if (code == 0 && id != null) send('stream remove ${_hex(id)}');
          return;
        }
        if (code != 0 || id == null) return _refused('stream create', code, body);
        _streamId = id;
        // Made the radio's source only for a message on its way: claimed
        // while idle, it takes the DAX transmit audio of a digital-mode
        // program on the same radio for as long as the stream stays open.
        if (_timer != null) _claim(id);
      },
    );
  }

  /// The stream made the radio's DAX transmit source. Refused, the radio
  /// transmits some other client's audio, or none.
  void _claim(int id) => send(
    'stream set ${_hex(id)} tx=1',
    onReply: (code, body) {
      if (code != 0 && !_closed) _refused('stream set tx=1', code, body);
    },
  );

  void _refused(String command, int code, String body) {
    diagnose?.call('$command refused: ${code.toRadixString(16).padLeft(8, '0')} ${body.trim()}'.trim());
    lost();
  }

  @override
  Future<void> get gone => _gone.future;

  @override
  bool get isAlive => !_closed && !_gone.isCompleted;

  /// The radio refused the stream, or the session lost the radio or its UDP
  /// socket: nothing more reaches the transmitter.
  void lost() {
    _grant?.cancel();
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
    final samples = ready != null && ready.$1 == path ? ready.$2 : decode(path, rate: flexDaxRate, channels: flexDaxChannels);
    _playing?._end();
    final playback = _FlexDaxPlayback(this, samples);
    _playing = playback;
    // Claimed again for each message: another client may have made its own
    // stream the source since.
    if (_streamId case final id?) _claim(id);
    _run();
    _pump();
    return playback;
  }

  /// Silence from now: the keyer keys the radio and waits out its key-up
  /// delay before the message, and a radio keyed with nothing arriving on
  /// its DAX transmits noise for that long.
  @override
  void startSilence(String next) {
    if (!isAlive) return;
    _ready = (next, decode(next, rate: flexDaxRate, channels: flexDaxChannels));
    if (_streamId case final id?) _claim(id);
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

  void _stop(_FlexDaxPlayback playback) {
    if (!identical(_playing, playback)) return;
    _playing = null;
    _silenceUntil = _packetsSent + _silenceAfterPackets;
    playback._end();
  }

  void _pump() {
    if (_streamId == null) {
      // Nothing sent before the radio has said which stream is ours: the
      // clock waits with it, so the message starts late rather than cut.
      _startMicros = _clock();
      _packetsSent = 0;
      return;
    }
    final due = (_clock() - _startMicros) * flexDaxRate ~/ (1000000 * _framesPerPacket) + _ahead;
    while (_packetsSent < due) {
      final playing = _playing;
      if (playing == null && _packetsSent >= _silenceUntil) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      final frames = playing?._next(_framesPerPacket);
      if (playing != null && frames == null) {
        _stop(playing);
        continue;
      }
      try {
        sendPacket(_packet(frames));
      } on Exception catch (e, st) {
        // The socket fails every packet after the first: one report, and the
        // keyer hears the radio is no longer taking audio.
        ErrorReportingService.report(e, st, context: 'flex:dax-tx');
        return lost();
      }
      _packetsSent++;
    }
  }

  /// One VITA-49 packet: type 1 with class id, UTC seconds and a sample
  /// count; silence for null [samples].
  Uint8List _packet(Float32List? samples) {
    final data = ByteData(28 + _framesPerPacket * flexDaxChannels * 4);
    data.setUint32(0, (1 << 28) | (1 << 27) | (1 << 22) | (1 << 20) | ((_count & 15) << 16) | data.lengthInBytes ~/ 4);
    data.setUint32(4, _streamId!);
    data.setUint32(8, 0x00001C2D);
    data.setUint32(12, 0x534C03E3);
    data.setUint32(16, realNowMillis() ~/ 1000);
    // Two halves rather than setUint64, which the web build has not got.
    data.setUint32(20, _frames ~/ 0x100000000);
    data.setUint32(24, _frames % 0x100000000);
    if (samples != null) {
      for (var i = 0; i < samples.length; i++) {
        data.setFloat32(28 + i * 4, samples[i]);
      }
    }
    _count++;
    _frames += _framesPerPacket;
    return data.buffer.asUint8List();
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _grant?.cancel();
    _timer?.cancel();
    _timer = null;
    _playing?._end();
    _playing = null;
    if (_streamId case final id?) send('stream remove ${_hex(id)}');
  }

  static int Function() _stopwatchClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsedMicroseconds;
  }

  static String _hex(int id) => '0x${id.toRadixString(16).padLeft(8, '0')}';
}

class _FlexDaxPlayback implements AudioPlayback {
  _FlexDaxPlayback(this._output, this._samples);

  final FlexDaxOutput _output;
  final Float32List _samples;
  int _at = 0;
  final _done = Completer<void>();

  /// The next [frames] frames, padded with silence at the end; null once
  /// every one has gone.
  Float32List? _next(int frames) {
    if (_at >= _samples.length) return null;
    final end = math.min(_at + frames * flexDaxChannels, _samples.length);
    final chunk = Float32List(frames * flexDaxChannels)..setRange(0, end - _at, _samples, _at);
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

  @override
  void stop() => _output._stop(this);
}

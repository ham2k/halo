// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/services/cat/computer_voice_keyer.dart';

class FakePlayback implements AudioPlayback {
  FakePlayback(this.path, {this.output});

  final String path;
  final FakeOutput? output;
  final _done = Completer<void>();
  bool stopped = false;

  /// The file ran out.
  void end() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;

  @override
  bool get isPlaying => !_done.isCompleted;

  @override
  void stop() {
    stopped = true;
    end();
  }
}

class FakeOutput implements AudioOutput {
  FakeOutput(this.deviceId);

  final String deviceId;
  final plays = <FakePlayback>[];
  final _gone = Completer<void>();
  bool closed = false;

  /// The device refuses to play: a file it cannot decode, or a device that
  /// fails when the audio starts.
  bool failingPlay = false;

  /// The device was unplugged under the open output.
  void unplug() {
    if (!_gone.isCompleted) _gone.complete();
  }

  @override
  Future<void> get gone => _gone.future;

  @override
  bool get isAlive => !closed && !_gone.isCompleted;

  @override
  AudioPlayback play(String path) {
    if (closed) throw StateError('closed');
    if (failingPlay) throw HaloAudioException('play: device failed');
    for (final p in plays) {
      p.end();
    }
    final playback = FakePlayback(path, output: this);
    plays.add(playback);
    return playback;
  }

  @override
  void close() {
    closed = true;
    for (final p in plays) {
      p.end();
    }
  }
}

class FakeRecording implements AudioRecording {
  FakeRecording(this.path, this.deviceId);

  final String path;
  final String? deviceId;
  bool stopped = false;

  /// What the next level read answers — a quiet voice, unless a test says
  /// the input heard nothing.
  double peak = 0.2;

  @override
  bool get isRecording => !stopped;

  @override
  double takePeak() => peak;

  @override
  void stop() => stopped = true;
}

/// The sound system for the computer's voice keyer: devices as listed,
/// recordings as a map of lengths, and every output, play and recording kept
/// for the test to end, unplug or inspect.
class FakeVoiceAudio implements VoiceAudio {
  var outputDevices = <AudioDevice>[];
  var inputDevices = <AudioDevice>[];
  final lengths = <String, Duration>{};
  final opened = <FakeOutput>[];
  final listens = <FakePlayback>[];
  final recordings = <FakeRecording>[];
  final replaced = <(String, String)>[];
  final copied = <(String, String)>[];
  final revealed = <String>[];
  final normalized = <String>[];
  bool failingNormalize = false;
  final deleted = <String>[];

  /// Device ids whose open fails, as a device that is listed but busy does.
  final failingOpens = <String>{};

  /// How many times the devices were listed.
  int listings = 0;

  /// Every play into any output, in order.
  List<FakePlayback> get plays => [for (final o in opened) ...o.plays];

  @override
  bool get isSupported => true;

  @override
  List<AudioDevice> outputs() {
    listings++;
    return outputDevices;
  }

  @override
  List<AudioDevice> inputs() => inputDevices;

  @override
  Duration? lengthOf(String path) => lengths[path];

  @override
  AudioOutput openOutput({required String deviceId}) {
    if (failingOpens.contains(deviceId) || !outputDevices.any((d) => d.id == deviceId)) {
      throw HaloAudioException('open device: no such device');
    }
    final output = FakeOutput(deviceId);
    opened.add(output);
    return output;
  }

  @override
  AudioPlayback listen(String path) {
    final playback = FakePlayback(path);
    listens.add(playback);
    return playback;
  }

  @override
  AudioRecording record(String path, {String? deviceId}) {
    final recording = FakeRecording(path, deviceId);
    recordings.add(recording);
    return recording;
  }

  @override
  void replace(String from, String to) {
    replaced.add((from, to));
    lengths[to] = lengths.remove(from)!;
  }

  @override
  void copy(String from, String to) {
    copied.add((from, to));
    lengths[to] = lengths[from]!;
  }

  @override
  void delete(String path) {
    deleted.add(path);
    lengths.remove(path);
  }

  @override
  void reveal(String path) => revealed.add(path);

  @override
  Float32List decode(String path, {required int rate, required int channels}) {
    final length = lengths[path];
    if (length == null) throw HaloAudioException('open file: no such file');
    return Float32List(length.inMicroseconds * rate ~/ 1000000 * channels);
  }

  @override
  void normalize(String path) {
    if (failingNormalize) throw HaloAudioException('normalize: no');
    normalized.add(path);
  }

  @override
  void deleteDirectory(String path) {
    deleted.add(path);
    lengths.removeWhere((file, _) => file.startsWith('$path/'));
  }
}

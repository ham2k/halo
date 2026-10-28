// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The web's HaloAudio: no dart:ffi, so no audio. The same surface as
// audio_ffi.dart — the analyzer reads this one — with nothing behind it.

import 'dart:async';
import 'dart:typed_data';

import 'devices.dart';

abstract final class HaloAudio {
  static bool get isSupported => false;

  static void useNullBackend() => throw UnsupportedError('halo_audio: no audio on this platform');

  static List<AudioDevice> playbackDevices() => throw UnsupportedError('halo_audio: no audio on this platform');

  static List<AudioDevice> captureDevices() => throw UnsupportedError('halo_audio: no audio on this platform');

  static Duration? fileLength(String path) => throw UnsupportedError('halo_audio: no audio on this platform');

  static Float32List decode(String path, {required int rate, required int channels}) => throw UnsupportedError('halo_audio: no audio on this platform');

  static void normalize(String from, String to, {required double peak, required double maxGain, AudioTrim? trim}) =>
      throw UnsupportedError('halo_audio: no audio on this platform');

  static AudioOutput openOutput({String? deviceId}) => throw UnsupportedError('halo_audio: no audio on this platform');

  static AudioRecording record(String path, {String? deviceId}) => throw UnsupportedError('halo_audio: no audio on this platform');
}

class AudioOutput {
  AudioOutput._();

  Future<void> get gone => Completer<void>().future;

  bool get isAlive => false;

  AudioPlayback play(String path) => AudioPlayback._();

  void close() {}
}

class AudioPlayback {
  AudioPlayback._();

  Future<void> get done => Completer<void>().future;

  bool get isPlaying => false;

  void stop() {}
}

class AudioRecording {
  AudioRecording._();

  bool get isRecording => false;

  double takePeak() => 0;

  void stop() {}
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// dart:ffi binding to miniaudio, compiled into this plugin's own library:
// the sound devices, playing a file to one, recording from one. Desktop
// only — the plugin declares macOS, Windows and Linux, and nothing else
// may open it.

import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Platform, File, Directory;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'devices.dart';

DynamicLibrary _openLibrary() {
  const envOverride = String.fromEnvironment('HALO_AUDIO_LIB');
  if (envOverride.isNotEmpty) return DynamicLibrary.open(envOverride);

  if (Platform.isMacOS) {
    try {
      final p = DynamicLibrary.process();
      p.lookup<Void>('halo_audio_enumerate'); // present only when linked into the app
      return p;
    } on ArgumentError {
      // Not linked in — under `flutter test`.
    }
  }

  for (final candidate in _hostCandidates()) {
    if (File(candidate).existsSync()) return DynamicLibrary.open(candidate);
  }

  if (Platform.isLinux) return DynamicLibrary.open('libhalo_audio.so');
  if (Platform.isWindows) return DynamicLibrary.open('halo_audio.dll');

  throw StateError(
    'halo_audio: could not find the audio library.\n'
    'Under `flutter test` it must be built first: packages/halo_audio/tool/build_host.sh\n'
    '(scripts/test.sh does this). Looked in:\n'
    '  ${_hostCandidates().join('\n  ')}',
  );
}

List<String> _hostCandidates() {
  final ext = Platform.isMacOS ? 'dylib' : (Platform.isWindows ? 'dll' : 'so');
  final name = Platform.isWindows ? 'halo_audio.$ext' : 'libhalo_audio.$ext';
  // `flutter test` runs with the cwd at whichever package is under test:
  // walk up to the repo root rather than guess one depth.
  final candidates = <String>['build/host/$name'];
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    candidates.add('${dir.path}/packages/halo_audio/build/host/$name');
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return candidates;
}

typedef _EndNative = Void Function(Int64);
typedef _PlayedNative = Void Function(Int64, Int32);

final DynamicLibrary _lib = _openLibrary();

final _useNullBackend = _lib.lookupFunction<Int32 Function(), int Function()>('halo_audio_use_null_backend');
final _enumerate = _lib.lookupFunction<Int32 Function(Int32), int Function(int)>('halo_audio_enumerate');
final _deviceId = _lib.lookupFunction<Pointer<Utf8> Function(Int32, Int32), Pointer<Utf8> Function(int, int)>('halo_audio_device_id');
final _deviceName = _lib.lookupFunction<Pointer<Utf8> Function(Int32, Int32), Pointer<Utf8> Function(int, int)>('halo_audio_device_name');
final _deviceIsDefault = _lib.lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>('halo_audio_device_is_default');
final _fileLengthMs = _lib.lookupFunction<Int64 Function(Pointer<Utf8>), int Function(Pointer<Utf8>)>('halo_audio_file_length_ms');
final _decode = _lib
    .lookupFunction<
      Int64 Function(Pointer<Utf8>, Int32, Int32, Pointer<Pointer<Float>>, Pointer<Utf8>, Int32),
      int Function(Pointer<Utf8>, int, int, Pointer<Pointer<Float>>, Pointer<Utf8>, int)
    >('halo_audio_decode');
final _free = _lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('halo_audio_free');
final _normalize = _lib
    .lookupFunction<
      Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Float, Float, Float, Float, Int32, Int32, Int32, Int32, Pointer<Utf8>, Int32),
      int Function(Pointer<Utf8>, Pointer<Utf8>, double, double, double, double, int, int, int, int, Pointer<Utf8>, int)
    >('halo_audio_normalize');
final _outputOpen = _lib
    .lookupFunction<
      Pointer<Void> Function(Pointer<Utf8>, Pointer<NativeFunction<_EndNative>>, Int64, Pointer<Utf8>, Int32),
      Pointer<Void> Function(Pointer<Utf8>, Pointer<NativeFunction<_EndNative>>, int, Pointer<Utf8>, int)
    >('halo_audio_output_open');
final _outputAlive = _lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('halo_audio_output_alive');
final _outputPlay = _lib
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<NativeFunction<_PlayedNative>>, Int64, Pointer<Utf8>, Int32),
      int Function(Pointer<Void>, Pointer<Utf8>, Pointer<NativeFunction<_PlayedNative>>, int, Pointer<Utf8>, int)
    >('halo_audio_output_play');
final _outputStop = _lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('halo_audio_output_stop');
final _outputClose = _lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('halo_audio_output_close');
final _record = _lib
    .lookupFunction<
      Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32),
      Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int)
    >('halo_audio_record');
final _recorderTakePeak = _lib.lookupFunction<Float Function(Pointer<Void>), double Function(Pointer<Void>)>('halo_audio_recorder_take_peak');
final _recorderFree = _lib.lookupFunction<Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32), int Function(Pointer<Void>, Pointer<Utf8>, int)>(
  'halo_audio_recorder_free',
);

const _errLen = 256;

/// The files still playing and the outputs still open, by the token their
/// callbacks carry.
final _playing = <int, AudioPlayback>{};
final _open = <int, AudioOutput>{};
var _nextToken = 1;

/// One listener each for every output, kept for the process's life: the
/// audio thread may call one up to the moment its output is closed, and a
/// callable closed with an output would be one a late call could still reach.
final _onEnd = NativeCallable<_PlayedNative>.listener((int token, int failed) => _playing.remove(token)?._finish(failed: failed != 0));
final _onLost = NativeCallable<_EndNative>.listener((int token) => _open[token]?._goneNow());

/// The whole binding: static, since there is one audio system per process.
abstract final class HaloAudio {
  /// Whether this platform carries the plugin: the desktop builds.
  static bool get isSupported => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Selects miniaudio's null backend — real-time pacing, no hardware — for
  /// everything after. Tests only, before anything else here is called.
  static void useNullBackend() {
    if (_useNullBackend() != 0) throw StateError('halo_audio: the null backend must be chosen before the first device call');
  }

  static List<AudioDevice> playbackDevices() => _devices(capture: false);

  static List<AudioDevice> captureDevices() => _devices(capture: true);

  static List<AudioDevice> _devices({required bool capture}) {
    final which = capture ? 1 : 0;
    final count = _enumerate(which);
    if (count < 0) throw HaloAudioException('no audio backend could be opened');
    return [
      for (var i = 0; i < count; i++)
        AudioDevice(id: _deviceId(which, i).toDartString(), name: _deviceName(which, i).toDartString(), isDefault: _deviceIsDefault(which, i) != 0),
    ];
  }

  /// How long the audio file at [path] runs, or null when it is not one
  /// this binding can decode (WAV, FLAC and MP3 are).
  static Duration? fileLength(String path) {
    final p = path.toNativeUtf8();
    try {
      final ms = _fileLengthMs(p);
      return ms < 0 ? null : Duration(milliseconds: ms);
    } finally {
      malloc.free(p);
    }
  }

  /// The audio file at [path] as interleaved float samples at [rate] Hz and
  /// [channels] channels — a mono file copied to each. Throws
  /// [HaloAudioException] when it will not open.
  static Float32List decode(String path, {required int rate, required int channels}) {
    final err = malloc<Uint8>(_errLen);
    err[0] = 0;
    final out = malloc<Pointer<Float>>();
    final p = path.toNativeUtf8();
    try {
      final frames = _decode(p, rate, channels, out, err.cast(), _errLen);
      if (frames < 0) throw HaloAudioException(err.cast<Utf8>().toDartString());
      final samples = Float32List.fromList(out.value.asTypedList(frames * channels));
      _free(out.value.cast());
      return samples;
    } finally {
      malloc.free(err);
      malloc.free(out);
      malloc.free(p);
    }
  }

  /// Writes the audio file at [from] to [to] as a 16-bit WAV, scaled so its
  /// loudest sample reaches [peak] (0..1) — never quieter, and at most
  /// [maxGain] times louder. With [trim] given, the start and the end are
  /// cut to the sound in it ([AudioTrim]). Throws [HaloAudioException] when
  /// either file will not open.
  static void normalize(String from, String to, {required double peak, required double maxGain, AudioTrim? trim}) {
    final err = malloc<Uint8>(_errLen);
    err[0] = 0;
    final f = from.toNativeUtf8(), t = to.toNativeUtf8();
    try {
      if (_normalize(
            f,
            t,
            peak,
            maxGain,
            trim?.aboveFloorDb ?? 0,
            trim?.belowLoudestDb ?? 0,
            trim?.minSound.inMilliseconds ?? 0,
            trim?.lead.inMilliseconds ?? 0,
            trim?.tail.inMilliseconds ?? 0,
            trim?.cutEnd.inMilliseconds ?? 0,
            err.cast(),
            _errLen,
          ) !=
          0) {
        throw HaloAudioException(err.cast<Utf8>().toDartString());
      }
    } finally {
      malloc.free(err);
      malloc.free(f);
      malloc.free(t);
    }
  }

  /// Opens [deviceId] — null for the system default — and keeps it running,
  /// silent until a file is played into it. Throws [HaloAudioException] when
  /// the device will not open.
  static AudioOutput openOutput({String? deviceId}) {
    final token = _nextToken++;
    final handle = _withError((err) => _withStrings('', deviceId, (_, d) => _outputOpen(d, _onLost.nativeFunction, token, err, _errLen)));
    return _open[token] = AudioOutput._(handle, token);
  }

  /// Starts recording [deviceId] — null for the system default — into a
  /// 16-bit mono 48 kHz WAV file at [path]. Throws [HaloAudioException] when
  /// the file or the device will not open.
  static AudioRecording record(String path, {String? deviceId}) =>
      AudioRecording._(_withError((err) => _withStrings(path, deviceId, (p, d) => _record(p, d, err, _errLen))));
}

Pointer<Void> _withError(Pointer<Void> Function(Pointer<Utf8> err) call) {
  final err = malloc<Uint8>(_errLen);
  err[0] = 0;
  try {
    final handle = call(err.cast());
    if (handle == nullptr) throw HaloAudioException(err.cast<Utf8>().toDartString());
    return handle;
  } finally {
    malloc.free(err);
  }
}

T _withStrings<T>(String path, String? deviceId, T Function(Pointer<Utf8> path, Pointer<Utf8> deviceId) call) {
  final p = path.toNativeUtf8();
  final d = deviceId == null ? nullptr : deviceId.toNativeUtf8();
  try {
    return call(p, d);
  } finally {
    malloc.free(p);
    if (d != nullptr) malloc.free(d);
  }
}

/// A playback device held open: playing a file into it costs a file open,
/// where opening the device costs tens of milliseconds more.
class AudioOutput {
  AudioOutput._(this._handle, this._token);

  Pointer<Void> _handle;
  final int _token;
  AudioPlayback? _current;
  final _gone = Completer<void>();

  /// Completes if the device stops by itself — unplugged, or taken away by
  /// the system. Never on [close].
  Future<void> get gone => _gone.future;

  /// Whether the device is open and still running.
  bool get isAlive => _handle != nullptr && _outputAlive(_handle) != 0;

  /// Plays [path], replacing whatever was playing. Throws
  /// [HaloAudioException] when the file will not open.
  AudioPlayback play(String path) {
    if (_handle == nullptr) throw StateError('halo_audio: output is closed');
    final token = _nextToken++;
    final p = path.toNativeUtf8();
    final err = malloc<Uint8>(_errLen);
    err[0] = 0;
    try {
      if (_outputPlay(_handle, p, _onEnd.nativeFunction, token, err.cast(), _errLen) != 0) {
        throw HaloAudioException(err.cast<Utf8>().toDartString());
      }
    } finally {
      malloc.free(p);
      malloc.free(err);
    }
    _replaceCurrent();
    final playback = AudioPlayback._(this, token);
    _current = playback;
    _playing[token] = playback;
    return playback;
  }

  void _stop(AudioPlayback playback) {
    if (identical(_current, playback) && _handle != nullptr) {
      _outputStop(_handle);
      _current = null;
    }
    _playing.remove(playback._token);
    playback._finish();
  }

  void _replaceCurrent() {
    final current = _current;
    if (current == null) return;
    _current = null;
    _playing.remove(current._token);
    current._finish();
  }

  void _goneNow() {
    if (!_gone.isCompleted) _gone.complete();
  }

  /// Closes the device. Safe to call more than once.
  void close() {
    if (_handle == nullptr) return;
    _replaceCurrent();
    _outputClose(_handle);
    _handle = nullptr;
    _open.remove(_token);
  }
}

/// A file playing into an [AudioOutput].
class AudioPlayback {
  AudioPlayback._(this._output, this._token);

  final AudioOutput _output;
  final int _token;
  final _done = Completer<void>();

  /// Completes when the file has run out — the device still sounding its
  /// last few tens of milliseconds, then silence — or when [stop], another
  /// play or closing the output ended it.
  Future<void> get done => _done.future;

  bool get isPlaying => !_done.isCompleted;

  /// Whether the file broke off where it could not be read further, rather
  /// than running out: [done] completes there all the same.
  bool get failed => _failed;
  bool _failed = false;

  void _finish({bool failed = false}) {
    if (_done.isCompleted) return;
    _failed = failed;
    _done.complete();
  }

  /// Silences the output now, leaving its device open. Safe to call more
  /// than once.
  void stop() => _output._stop(this);
}

/// A device recording into a file.
class AudioRecording {
  AudioRecording._(this._handle);

  Pointer<Void> _handle;

  bool get isRecording => _handle != nullptr;

  /// The loudest sample since the last call, 0 to 1.
  double takePeak() => _handle == nullptr ? 0 : _recorderTakePeak(_handle);

  /// Stops recording and finishes the file. Throws [HaloAudioException]
  /// when the file holds only part of what was recorded — a write to it
  /// failed, or the device went away mid-recording. Safe to call more than
  /// once.
  void stop() {
    if (_handle == nullptr) return;
    final handle = _handle;
    _handle = nullptr;
    final err = malloc<Uint8>(_errLen);
    err[0] = 0;
    try {
      if (_recorderFree(handle, err.cast(), _errLen) != 0) throw HaloAudioException(err.cast<Utf8>().toDartString());
    } finally {
      malloc.free(err);
    }
  }
}

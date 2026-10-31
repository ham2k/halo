// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:record/record.dart';

import 'iq_audio_types.dart';

/// Each native backend validates the selected source before converting samples.
bool get iqAudioSupported => Platform.isMacOS || Platform.isWindows || Platform.isLinux || Platform.isAndroid || Platform.isIOS;
bool get iqAudioNeedsAccess => Platform.isAndroid || Platform.isIOS;

/// Mobile input enumeration may require permission. Only an explicit form
/// action calls this; opening the settings pane never requests access.
Future<void> prepareIqAudioAccess({int sampleRate = 48000}) async {
  if (!iqAudioSupported) throw const IqAudioException(IqAudioFailure.unsupported);
  if (!iqAudioNeedsAccess) return;
  final recorder = AudioRecorder();
  try {
    if (!await recorder.hasPermission()) throw const IqAudioException(IqAudioFailure.permissionDenied);
  } on PlatformException catch (error) {
    throw _captureError(error);
  } finally {
    await recorder.dispose();
  }
}

/// Enumeration never asks for microphone permission or opens an audio stream.
Future<List<IqAudioInput>> listIqAudioInputs() async {
  if (!iqAudioSupported) return const [];
  final recorder = AudioRecorder();
  try {
    return [for (final input in await recorder.listInputDevices()) IqAudioInput(id: input.id, label: input.label)];
  } on PlatformException catch (error) {
    throw _captureError(error);
  } finally {
    await recorder.dispose();
  }
}

IqAudioCapture createIqAudioCapture() => _RecordIqAudioCapture();

class _RecordIqAudioCapture implements IqAudioCapture {
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _samples;
  StreamSubscription<RecordState>? _states;
  final _output = StreamController<Uint8List>();
  bool _started = false;
  bool _streaming = false;
  bool _disposed = false;
  Future<void>? _disposing;
  IqAudioException? _formatFailure;

  @override
  Future<Stream<Uint8List>> start({required String deviceId, required int sampleRate}) async {
    if (!iqAudioSupported) throw const IqAudioException(IqAudioFailure.unsupported);
    _checkLive();
    if (_started) throw StateError('An I/Q capture can only start once');
    _started = true;
    if (deviceId.trim().isEmpty) throw const IqAudioException(IqAudioFailure.deviceUnavailable);
    if (!const [48000, 96000, 192000].contains(sampleRate)) throw const IqAudioException(IqAudioFailure.invalidFormat);

    final recorder = _recorder = AudioRecorder();
    final devices = await recorder.listInputDevices().catchError((Object error) => throw _captureError(error));
    _checkLive();
    final device = devices.where((input) => input.id == deviceId).firstOrNull;
    if (device == null) throw const IqAudioException(IqAudioFailure.deviceUnavailable);
    final allowed = await recorder.hasPermission().catchError((Object error) => throw _captureError(error));
    _checkLive();
    if (!allowed) throw const IqAudioException(IqAudioFailure.permissionDenied);

    await recorder.setOnConfigChanged((config) {
      if (_disposed) return;
      if (config.encoder != AudioEncoder.pcm16bits || config.numChannels != 2 || config.sampleRate != sampleRate) {
        final error = _formatFailure = const IqAudioException(IqAudioFailure.invalidFormat);
        _fail(error, StackTrace.current);
      }
    });
    _checkLive();
    _states = recorder.onStateChanged().listen((state) {
      if (_streaming && state == RecordState.stop) _finish();
    }, onError: _fail);

    final Stream<Uint8List> stream;
    try {
      stream = await recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 2,
          sampleRate: sampleRate,
          device: device,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
          androidConfig: const AndroidRecordConfig(manageBluetooth: false),
        ),
      );
    } on PlatformException catch (error) {
      throw _captureError(error);
    }
    _checkLive();
    if (_formatFailure case final error?) throw error;
    _streaming = true;
    _samples = stream.listen(
      (data) {
        if (!_disposed && !_output.isClosed && _formatFailure == null) _output.add(data);
      },
      onError: _fail,
      onDone: _finish,
    );
    return _output.stream;
  }

  void _checkLive() {
    if (_disposed) throw const IqAudioException(IqAudioFailure.deviceUnavailable, details: 'Capture disposed');
  }

  void _fail(Object error, StackTrace stackTrace) {
    if (!_disposed && !_output.isClosed) _output.addError(_captureError(error), stackTrace);
  }

  void _finish() {
    if (!_output.isClosed) unawaited(_output.close());
  }

  @override
  Future<void> dispose() {
    _disposed = true;
    return _disposing ??= _dispose();
  }

  Future<void> _dispose() async {
    try {
      await _samples?.cancel();
      await _states?.cancel();
    } finally {
      try {
        // AudioRecorder serializes native calls, so a permission or start
        // already in flight is followed by disposal, never a leaked stream.
        await _recorder?.dispose();
      } finally {
        _finish();
      }
    }
  }
}

Object _captureError(Object error) {
  if (error is! PlatformException) return error;
  final reason = switch (error.message) {
    'iq_audio_permission_denied' => IqAudioFailure.permissionDenied,
    'iq_audio_device_unavailable' => IqAudioFailure.deviceUnavailable,
    'iq_audio_invalid_format' => IqAudioFailure.invalidFormat,
    'iq_audio_sample_rate_mismatch' => IqAudioFailure.sampleRateMismatch,
    'iq_audio_unsupported' => IqAudioFailure.unsupported,
    _ => null,
  };
  return reason == null ? error : IqAudioException(reason, details: error.details?.toString());
}

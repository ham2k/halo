// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

import 'alsa_backend.dart';
import 'linux_recorder.dart';

Future<List<InputDevice>> listAlsaIqInputs() =>
    Isolate.run(() => NativeAlsaBackend().inputs());

/// The worker owns every native handle. Stop waits for its exit, which happens
/// only after the PCM closes; a reconnect cannot race a still-claimed device.
class AlsaIqRecorder extends LinuxRecorder {
  AlsaIqRecorder({AlsaBackend Function()? backendFactory})
    : _backendFactory = backendFactory ?? NativeAlsaBackend.new;

  // A factory, not an open backend: native pointers must belong to the worker.
  final AlsaBackend Function() _backendFactory;
  final _states = StreamController<RecordState>.broadcast();
  StreamController<Uint8List>? _output;
  ReceivePort? _messages;
  StreamSubscription<dynamic>? _subscription;
  Future<Isolate>? _spawned;
  Completer<SendPort?>? _control;
  Completer<void>? _ready;
  Completer<void>? _exited;
  Future<String?>? _stopping;
  bool _recording = false;

  @override
  Stream<RecordState> onStateChanged() => _states.stream;

  @override
  bool isRecording() => _recording;

  @override
  bool isPaused() => false;

  @override
  Future<void> start(RecordConfig config, {required String path}) async =>
      throw alsaFailure('iq_audio_unsupported');

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    await stop();
    if (config.encoder != AudioEncoder.pcm16bits ||
        config.numChannels != 2 ||
        config.autoGain ||
        config.echoCancel ||
        config.noiseSuppress) {
      throw alsaFailure('iq_audio_invalid_format');
    }
    final deviceId = config.device?.id ?? '';
    if (!isAlsaHardwareId(deviceId)) {
      throw alsaFailure('iq_audio_device_unavailable');
    }
    _stopping = null;
    final output = _output = StreamController<Uint8List>.broadcast();
    final messages = _messages = ReceivePort();
    _control = Completer<SendPort?>();
    _ready = Completer<void>();
    _exited = Completer<void>();
    _subscription = messages.listen(_message);
    _spawned = Isolate.spawn(
      _alsaWorker,
      (messages.sendPort, deviceId, config.sampleRate, _backendFactory),
      onExit: messages.sendPort,
      onError: messages.sendPort,
    );
    try {
      await Future.wait([_spawned!, _ready!.future], eagerError: true);
      if (_stopping != null) {
        throw alsaFailure(
          'iq_audio_device_unavailable',
          'Capture stopped during startup',
        );
      }
      return output.stream;
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  void _message(dynamic event) {
    if (event is SendPort) {
      if (!_control!.isCompleted) _control!.complete(event);
    } else if (event == 'ready') {
      _recording = true;
      _states.add(RecordState.record);
      if (!_ready!.isCompleted) _ready!.complete();
    } else if (event is TransferableTypedData) {
      if (_stopping == null && !(_output?.isClosed ?? true)) {
        _output!.add(event.materialize().asUint8List());
      }
      unawaited(_control!.future.then((port) => port?.send('ack')));
    } else if (event is Map) {
      final error = alsaFailure(
        event['reason'] as String,
        event['details'] as String?,
      );
      if (!_ready!.isCompleted) {
        _ready!.completeError(error);
      } else if (_stopping == null && !(_output?.isClosed ?? true)) {
        _output!.addError(error);
      }
    } else if (event is List) {
      final error = alsaFailure('ALSA worker failed', event.join('\n'));
      if (!_ready!.isCompleted) {
        _ready!.completeError(error);
      } else if (_stopping == null && !(_output?.isClosed ?? true)) {
        _output!.addError(error);
      }
    } else if (event == null) {
      if (!_control!.isCompleted) _control!.complete(null);
      if (!_ready!.isCompleted) {
        _ready!.completeError(
          alsaFailure(
            'iq_audio_device_unavailable',
            'Capture worker exited before startup',
          ),
        );
      }
      _recording = false;
      _states.add(RecordState.stop);
      if (!(_output?.isClosed ?? true)) unawaited(_output!.close());
      if (!_exited!.isCompleted) _exited!.complete();
    }
  }

  @override
  Future<String?> stop() {
    if (_spawned == null) return Future.value(null);
    return _stopping ??= _stop();
  }

  Future<String?> _stop() async {
    try {
      await _spawned;
      final control = await _control!.future;
      control?.send('stop');
      await _exited!.future;
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _messages?.close();
      _messages = null;
      _spawned = null;
      if (!(_output?.isClosed ?? true)) await _output!.close();
    }
    return null;
  }

  @override
  Future<void> cancel() async {
    await stop();
  }

  @override
  Future<void> pause() async => throw alsaFailure(
    'iq_audio_unsupported',
    'Restart I/Q capture after a pause',
  );

  @override
  Future<void> resume() async => throw alsaFailure(
    'iq_audio_unsupported',
    'Restart I/Q capture after a pause',
  );

  @override
  Future<void> dispose() async {
    await stop();
    await _states.close();
  }
}

void _alsaWorker((SendPort, String, int, AlsaBackend Function()) args) {
  final (output, deviceId, sampleRate, backendFactory) = args;
  final commands = ReceivePort();
  output.send(commands.sendPort);
  AlsaIqSession? session;
  Timer? timer;
  var stopped = false;
  var awaitingAck = false;

  void stop() {
    if (stopped) return;
    stopped = true;
    timer?.cancel();
    try {
      session?.stop();
    } finally {
      commands.close();
    }
  }

  void fail(Object error) {
    output.send({
      'reason': error is PlatformException
          ? error.message ?? 'ALSA capture failed'
          : 'ALSA capture failed',
      'details': error is PlatformException
          ? error.details?.toString()
          : error.toString(),
    });
    stop();
  }

  commands.listen((command) {
    if (command == 'stop') stop();
    if (command == 'ack') awaitingAck = false;
  });

  try {
    session = AlsaIqSession(backendFactory())..start(deviceId, sampleRate);
    output.send('ready');
    timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      // At most one sample packet is in flight. A slow consumer eventually
      // causes a hardware overrun and a visible failure, never an unbounded
      // mailbox or a silently discontinuous sample stream.
      if (awaitingAck || stopped) return;
      try {
        final samples = session!.read();
        if (samples != null) {
          awaitingAck = true;
          output.send(TransferableTypedData.fromList([samples]));
        }
      } catch (error) {
        fail(error);
      }
    });
  } catch (error) {
    fail(error);
  }
}

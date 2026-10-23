// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'iq_audio_types.dart';
import 'iq_audio_worklet.dart';

bool get iqAudioSupported =>
    web.window.isSecureContext &&
    web.window.navigator.hasProperty('mediaDevices'.toJS).toDart &&
    globalContext.hasProperty('AudioContext'.toJS).toDart &&
    globalContext.hasProperty('AudioWorkletNode'.toJS).toDart;

/// Permission and AudioContext activation belong to an explicit form action.
bool get iqAudioNeedsAccess => true;

final _contexts = <int, web.AudioContext>{};
final _preparedRates = <int>{};

/// Invoke directly inside the operator's gesture, before awaiting other work.
/// Empty, unlocked contexts are retained so reopening a display does not need
/// another gesture. No microphone track survives the permission request.
Future<void> prepareIqAudioAccess({int sampleRate = 48000}) async {
  if (!iqAudioSupported) throw const IqAudioException(IqAudioFailure.unsupported);
  _checkRate(sampleRate);
  web.AudioContext? context;
  var created = false;
  try {
    context = _contexts[sampleRate];
    if (context == null || context.state == 'closed') {
      context = _contexts[sampleRate] = web.AudioContext(web.AudioContextOptions(sampleRate: sampleRate));
      created = true;
    }
    // Both browser calls start synchronously while the gesture is active.
    // A rejected resume is retained while the operator answers permission;
    // it must not escape as an unhandled asynchronous error during the dialog.
    final resumed = context.resume().toDart.then<Object?>((_) => null, onError: (Object error) => error);
    final granted = await web.window.navigator.mediaDevices.getUserMedia(web.MediaStreamConstraints(audio: _audioConstraints())).toDart;
    _stopTracks(granted);
    // Permission can take arbitrarily long. Bound only the activation wait
    // after that decision, otherwise a slow answer would falsely time out.
    final resumeError = await resumed.timeout(const Duration(seconds: 2), onTimeout: () => throw const IqAudioException(IqAudioFailure.permissionDenied));
    if (resumeError != null) throw resumeError;
    if (context.sampleRate != sampleRate) throw const IqAudioException(IqAudioFailure.sampleRateMismatch);
    if (context.state != 'running') throw const IqAudioException(IqAudioFailure.permissionDenied);
    _preparedRates.add(sampleRate);
  } catch (error) {
    if (created && context != null) {
      if (_contexts[sampleRate] == context) {
        _contexts.remove(sampleRate);
        _preparedRates.remove(sampleRate);
      }
      if (context.state != 'closed') await context.close().toDart;
    }
    throw _audioError(error);
  }
}

/// Enumeration never opens a stream or prompts for permission. Before access
/// is granted, browsers may hide device identities and labels.
Future<List<IqAudioInput>> listIqAudioInputs() async {
  if (!iqAudioSupported) return const [];
  final devices = await web.window.navigator.mediaDevices.enumerateDevices().toDart;
  return [
    for (final device in devices.toDart)
      if (device.kind == 'audioinput' && device.deviceId.isNotEmpty && device.deviceId != 'default' && device.deviceId != 'communications')
        IqAudioInput(id: device.deviceId, label: device.label.isEmpty ? device.deviceId : device.label),
  ];
}

IqAudioCapture createIqAudioCapture() => WebIqAudioCapture(
  mediaDevices: web.window.navigator.mediaDevices,
  acquireContext: (rate) async {
    if (!iqAudioSupported) throw const IqAudioException(IqAudioFailure.unsupported);
    final context = _contexts[rate];
    if (context == null || !_preparedRates.contains(rate)) throw const IqAudioException(IqAudioFailure.permissionDenied);
    if (context.state != 'running') {
      await context.resume().toDart.timeout(const Duration(seconds: 2), onTimeout: () => throw const IqAudioException(IqAudioFailure.permissionDenied));
    }
    return context;
  },
  createWorklet: createIqAudioWorklet,
);

web.MediaTrackConstraints _audioConstraints({String? deviceId, int? sampleRate}) {
  final constraints = web.MediaTrackConstraints(
    echoCancellation: web.ConstrainBooleanParameters(exact: false),
    autoGainControl: web.ConstrainBooleanParameters(exact: false),
    noiseSuppression: web.ConstrainBooleanParameters(exact: false),
  );
  if (deviceId != null) constraints.deviceId = web.ConstrainDOMStringParameters(exact: deviceId.toJS);
  if (sampleRate != null) {
    constraints.sampleRate = web.ConstrainULongRange(exact: sampleRate);
    constraints.channelCount = web.ConstrainULongRange(exact: 2);
  }
  return constraints;
}

void _checkRate(int rate) {
  if (!const [48000, 96000, 192000].contains(rate)) throw const IqAudioException(IqAudioFailure.invalidFormat);
}

void _stopTracks(web.MediaStream stream) {
  for (final track in stream.getTracks().toDart) {
    track.stop();
  }
}

IqAudioException _audioError(Object error) {
  if (error is IqAudioException) return error;
  // Dart failures are not JS interop values (especially in a Wasm build).
  // Only browser objects below may be inspected for DOMException fields.
  if (error is Error || error is Exception || error is String || error is num || error is bool) {
    return IqAudioException(IqAudioFailure.invalidFormat, details: error.toString());
  }
  final jsError = error as JSAny;
  final object = jsError.isA<JSObject>() ? jsError as JSObject : null;
  final name = object?.getProperty<JSString?>('name'.toJS)?.toDart;
  final constraint = object?.getProperty<JSString?>('constraint'.toJS)?.toDart;
  final reason = switch (name) {
    'NotAllowedError' || 'SecurityError' => IqAudioFailure.permissionDenied,
    'NotFoundError' || 'NotReadableError' || 'AbortError' => IqAudioFailure.deviceUnavailable,
    'OverconstrainedError' when constraint == 'sampleRate' => IqAudioFailure.sampleRateMismatch,
    'OverconstrainedError' when constraint == 'deviceId' => IqAudioFailure.deviceUnavailable,
    'NotSupportedError' => IqAudioFailure.unsupported,
    _ => IqAudioFailure.invalidFormat,
  };
  return IqAudioException(reason, details: error.toString());
}

final _modules = <web.BaseAudioContext, Future<void>>{};

/// Also used with an OfflineAudioContext by browser tests, exercising the same
/// processor and channel configuration without microphone permission.
Future<web.AudioWorkletNode> createIqAudioWorklet(web.BaseAudioContext context) async {
  await _modules.putIfAbsent(context, () async {
    final blob = web.Blob([iqAudioWorkletSource.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript'));
    final url = web.URL.createObjectURL(blob);
    try {
      await context.audioWorklet.addModule(url).toDart;
    } finally {
      web.URL.revokeObjectURL(url);
    }
  });
  return web.AudioWorkletNode(
    context,
    'halo-iq-capture',
    web.AudioWorkletNodeOptions(
      numberOfInputs: 1,
      numberOfOutputs: 1,
      outputChannelCount: [1.toJS].toJS,
      channelCountMode: 'max',
      channelInterpretation: 'discrete',
    ),
  );
}

/// getSettings proves the browser-delivered track format, not the interface's
/// physical ADC clock. Matching the AudioContext avoids a second resampler;
/// every worklet block independently checks the delivered channel count.
class WebIqAudioCapture implements IqAudioCapture {
  final web.MediaDevices mediaDevices;
  final Future<web.AudioContext> Function(int sampleRate) acquireContext;
  final Future<web.AudioWorkletNode> Function(web.BaseAudioContext context) createWorklet;

  WebIqAudioCapture({required this.mediaDevices, required this.acquireContext, required this.createWorklet});

  final _output = StreamController<Uint8List>();
  web.MediaStream? _input;
  web.MediaStreamTrack? _track;
  web.AudioContext? _context;
  web.MediaStreamAudioSourceNode? _source;
  web.AudioWorkletNode? _worklet;
  JSFunction? _onEnded, _onMute, _onDeviceChange, _onStateChange;
  bool _started = false;
  bool _disposed = false;

  @override
  Future<Stream<Uint8List>> start({required String deviceId, required int sampleRate}) async {
    _checkLive();
    if (_started) throw StateError('An I/Q capture can only start once');
    _started = true;
    if (deviceId.isEmpty || deviceId == 'default' || deviceId == 'communications') throw const IqAudioException(IqAudioFailure.deviceUnavailable);
    _checkRate(sampleRate);
    try {
      final context = _context = await acquireContext(sampleRate);
      _checkLive();
      if (context.sampleRate != sampleRate) throw const IqAudioException(IqAudioFailure.sampleRateMismatch);
      if (context.state != 'running') throw const IqAudioException(IqAudioFailure.permissionDenied);
      final stream = await mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              audio: _audioConstraints(deviceId: deviceId, sampleRate: sampleRate),
            ),
          )
          .toDart;
      if (_disposed) {
        _stopTracks(stream);
        _checkLive();
      }
      _input = stream;
      final tracks = stream.getAudioTracks().toDart;
      if (tracks.length != 1) throw const IqAudioException(IqAudioFailure.invalidFormat);
      final track = _track = tracks.single;
      void validate() {
        final settings = track.getSettings();
        if (track.readyState != 'live' || settings.getProperty<JSString?>('deviceId'.toJS)?.toDart != deviceId) {
          throw const IqAudioException(IqAudioFailure.deviceUnavailable);
        }
        if (settings.getProperty<JSNumber?>('sampleRate'.toJS)?.toDartInt != sampleRate) {
          throw const IqAudioException(IqAudioFailure.sampleRateMismatch);
        }
        if (settings.getProperty<JSNumber?>('channelCount'.toJS)?.toDartInt != 2 ||
            settings.getProperty<JSBoolean?>('echoCancellation'.toJS)?.toDart != false ||
            settings.getProperty<JSBoolean?>('autoGainControl'.toJS)?.toDart != false ||
            settings.getProperty<JSBoolean?>('noiseSuppression'.toJS)?.toDart != false) {
          throw const IqAudioException(IqAudioFailure.invalidFormat);
        }
      }

      validate();
      _onEnded = ((web.Event _) => _fail(const IqAudioException(IqAudioFailure.deviceUnavailable))).toJS;
      _onMute = ((web.Event _) => _fail(const IqAudioException(IqAudioFailure.deviceUnavailable))).toJS;
      track.addEventListener('ended', _onEnded);
      track.addEventListener('mute', _onMute);
      _onDeviceChange = ((web.Event _) {
        if (_disposed) return;
        unawaited(() async {
          try {
            final devices = await mediaDevices.enumerateDevices().toDart;
            if (_disposed) return;
            if (!devices.toDart.any((device) => device.kind == 'audioinput' && device.deviceId == deviceId)) {
              throw const IqAudioException(IqAudioFailure.deviceUnavailable);
            }
            validate();
          } catch (error) {
            _fail(_audioError(error));
          }
        }());
      }).toJS;
      mediaDevices.addEventListener('devicechange', _onDeviceChange);
      _onStateChange = ((web.Event _) {
        if (!_disposed && context.state != 'running') _fail(const IqAudioException(IqAudioFailure.deviceUnavailable));
      }).toJS;
      context.addEventListener('statechange', _onStateChange);
      final worklet = await createWorklet(context);
      if (_disposed) {
        worklet.port.close();
        worklet.disconnect();
        _checkLive();
      }
      _worklet = worklet;
      worklet.onprocessorerror = ((web.Event _) => _fail(const IqAudioException(IqAudioFailure.invalidFormat))).toJS;
      worklet.port.onmessage = ((web.MessageEvent event) {
        if (_disposed) return;
        try {
          validate();
          final data = event.data;
          if (data.isA<JSString>()) {
            final message = (data as JSString).toDart;
            if (message == 'overrun') {
              _fail(StateError('The browser I/Q consumer fell behind the audio stream'));
              return;
            }
            final reason = message == 'deviceUnavailable' ? IqAudioFailure.deviceUnavailable : IqAudioFailure.invalidFormat;
            throw IqAudioException(reason);
          }
          if (!data.isA<JSArrayBuffer>()) throw const IqAudioException(IqAudioFailure.invalidFormat);
          _output.add((data as JSArrayBuffer).toDart.asUint8List());
          worklet.port.postMessage('ack'.toJS);
        } catch (error) {
          _fail(_audioError(error));
        }
      }).toJS;
      final source = _source = context.createMediaStreamSource(stream);
      source.connect(worklet);
      // A silent output keeps the graph rendering on browsers that prune
      // disconnected nodes. Raw I/Q is never played through the speakers.
      worklet.connect(context.destination);
      return _output.stream;
    } catch (error) {
      await dispose();
      throw _audioError(error);
    }
  }

  void _checkLive() {
    if (_disposed) throw const IqAudioException(IqAudioFailure.deviceUnavailable, details: 'Capture disposed');
  }

  void _fail(Object error) {
    if (_disposed) return;
    _output.addError(error);
    unawaited(dispose());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _track?.removeEventListener('ended', _onEnded);
    _track?.removeEventListener('mute', _onMute);
    mediaDevices.removeEventListener('devicechange', _onDeviceChange);
    _context?.removeEventListener('statechange', _onStateChange);
    _source?.disconnect();
    _worklet?.disconnect();
    _worklet?.port.close();
    if (_input case final input?) _stopTracks(input);
    // A context is shared by captures and kept unlocked for future displays.
    // Its microphone tracks and graph nodes belong only to this capture.
    unawaited(_output.close());
  }
}

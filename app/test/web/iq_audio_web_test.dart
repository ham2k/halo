// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/transports/iq_audio_types.dart';
import 'package:ham2k_logger/services/cat/transports/iq_audio_web.dart';
import 'package:web/web.dart' as web;

Matcher failure(IqAudioFailure reason) => isA<IqAudioException>().having((error) => error.reason, 'reason', reason);

@JS('Promise.reject')
external JSPromise<web.MediaStream> _rejectMediaStream(JSAny reason);

class _Browser {
  final media = web.EventTarget() as web.MediaDevices;
  final context = web.EventTarget() as web.AudioContext;
  final track = web.EventTarget() as web.MediaStreamTrack;
  final input = JSObject() as web.MediaStream;
  final source = JSObject() as web.MediaStreamAudioSourceNode;
  final worklet = web.EventTarget() as web.AudioWorkletNode;
  final messages = web.MessageChannel();
  final settings = web.MediaTrackSettings(
    deviceId: 'usb-iq',
    channelCount: 2,
    sampleRate: 48000,
    echoCancellation: false,
    autoGainControl: false,
    noiseSuppression: false,
  );
  web.MediaStreamConstraints? requested;
  Completer<web.MediaStream>? pending;
  JSAny? rejection;
  bool devicePresent = true;
  int stopped = 0;
  bool disconnected = false;

  _Browser() {
    addTearDown(() {
      messages.port1.close();
      messages.port2.close();
    });
    media.setProperty(
      'getUserMedia'.toJS,
      ((web.MediaStreamConstraints constraints) {
        requested = constraints;
        if (rejection case final reason?) return _rejectMediaStream(reason);
        return (pending?.future ?? Future.value(input)).toJS;
      }).toJS,
    );
    media.setProperty(
      'enumerateDevices'.toJS,
      (() {
        final device = JSObject() as web.MediaDeviceInfo;
        device.setProperty('kind'.toJS, 'audioinput'.toJS);
        device.setProperty('deviceId'.toJS, 'usb-iq'.toJS);
        return Future.value(<web.MediaDeviceInfo>[if (devicePresent) device].toJS).toJS;
      }).toJS,
    );
    input.setProperty('getTracks'.toJS, (() => [track].toJS).toJS);
    input.setProperty('getAudioTracks'.toJS, (() => [track].toJS).toJS);
    track.setProperty('readyState'.toJS, 'live'.toJS);
    track.setProperty('getSettings'.toJS, (() => settings).toJS);
    track.setProperty(
      'stop'.toJS,
      (() {
        stopped++;
        track.setProperty('readyState'.toJS, 'ended'.toJS);
      }).toJS,
    );
    context.setProperty('sampleRate'.toJS, 48000.toJS);
    context.setProperty('state'.toJS, 'running'.toJS);
    context.setProperty('createMediaStreamSource'.toJS, ((web.MediaStream _) => source).toJS);
    context.setProperty('destination'.toJS, JSObject());
    source.setProperty('connect'.toJS, ((JSObject node) => node).toJS);
    source.setProperty('disconnect'.toJS, (() => disconnected = true).toJS);
    worklet.setProperty('connect'.toJS, ((JSObject node) => node).toJS);
    worklet.setProperty('disconnect'.toJS, (() {}).toJS);
    worklet.setProperty('port'.toJS, messages.port1);
  }

  WebIqAudioCapture capture() => WebIqAudioCapture(mediaDevices: media, acquireContext: (_) async => context, createWorklet: (_) async => worklet);

  void send(Uint8List bytes) => messages.port2.postMessage(bytes.buffer.toJS);
}

void main() {
  test('selected device and unprocessed stereo are exact constraints; PCM is forwarded unchanged', () async {
    final browser = _Browser();
    final capture = browser.capture();
    final stream = await capture.start(deviceId: 'usb-iq', sampleRate: 48000);
    final audio = browser.requested!.audio as JSObject;
    JSAny? exact(String key) => audio.getProperty<JSObject>(key.toJS).getProperty<JSAny?>('exact'.toJS);
    expect((exact('deviceId') as JSString).toDart, 'usb-iq');
    expect((exact('channelCount') as JSNumber).toDartInt, 2);
    expect((exact('sampleRate') as JSNumber).toDartInt, 48000);
    for (final setting in ['echoCancellation', 'autoGainControl', 'noiseSuppression']) {
      expect((exact(setting) as JSBoolean).toDart, isFalse);
    }
    final received = stream.first;
    browser.send(Uint8List.fromList([0, 128, 255, 127]));
    expect(await received, [0, 128, 255, 127]);
    await capture.dispose();
    expect(browser.stopped, 1);
    expect(browser.disconnected, isTrue);
  });

  for (final channels in [1, 4]) {
    test('a $channels-channel track cannot masquerade as independent stereo', () async {
      final browser = _Browser()..settings.channelCount = channels;
      await expectLater(browser.capture().start(deviceId: 'usb-iq', sampleRate: 48000), throwsA(failure(IqAudioFailure.invalidFormat)));
      expect(browser.stopped, 1);
    });
  }

  test('a substituted device, unknown rate and browser processing are rejected', () async {
    final wrong = _Browser()..settings.deviceId = 'default-microphone';
    await expectLater(wrong.capture().start(deviceId: 'usb-iq', sampleRate: 48000), throwsA(failure(IqAudioFailure.deviceUnavailable)));
    final unknown = _Browser();
    unknown.settings.delete('sampleRate'.toJS);
    await expectLater(unknown.capture().start(deviceId: 'usb-iq', sampleRate: 48000), throwsA(failure(IqAudioFailure.sampleRateMismatch)));
    final processed = _Browser()..settings.autoGainControl = true;
    await expectLater(processed.capture().start(deviceId: 'usb-iq', sampleRate: 48000), throwsA(failure(IqAudioFailure.invalidFormat)));
  });

  test('AudioContext conversion cannot relabel a different capture rate', () async {
    final browser = _Browser();
    browser.context.setProperty('sampleRate'.toJS, 44100.toJS);
    await expectLater(browser.capture().start(deviceId: 'usb-iq', sampleRate: 48000), throwsA(failure(IqAudioFailure.sampleRateMismatch)));
    expect(browser.requested, isNull);
  });

  test('an unplugged track stops capture and finishes the consumer stream', () async {
    final browser = _Browser();
    final capture = browser.capture();
    final stream = await capture.start(deviceId: 'usb-iq', sampleRate: 48000);
    final ended = expectLater(stream, emitsInOrder([emitsError(failure(IqAudioFailure.deviceUnavailable)), emitsDone]));
    browser.track.dispatchEvent(web.Event('ended'));
    await ended;
    expect(browser.stopped, 1);
    expect(browser.disconnected, isTrue);
  });

  test('settings are rechecked before publishing each block after a format change', () async {
    final browser = _Browser();
    final capture = browser.capture();
    final stream = await capture.start(deviceId: 'usb-iq', sampleRate: 48000);
    final ended = expectLater(stream, emitsInOrder([emitsError(failure(IqAudioFailure.sampleRateMismatch)), emitsDone]));
    browser.settings.sampleRate = 44100;
    browser.send(Uint8List(4));
    await ended;
    expect(browser.stopped, 1);
  });

  test('device removal is caught even if the browser leaves the old track live', () async {
    final browser = _Browser();
    final capture = browser.capture();
    final stream = await capture.start(deviceId: 'usb-iq', sampleRate: 48000);
    final ended = expectLater(stream, emitsInOrder([emitsError(failure(IqAudioFailure.deviceUnavailable)), emitsDone]));
    browser.devicePresent = false;
    browser.media.dispatchEvent(web.Event('devicechange'));
    await ended;
    expect(browser.stopped, 1);
  });

  test('browser permission rejection retains its actionable failure reason', () async {
    final browser = _Browser()..rejection = web.DOMException('Microphone permission was denied', 'NotAllowedError');
    await expectLater(browser.capture().start(deviceId: 'usb-iq', sampleRate: 48000), throwsA(failure(IqAudioFailure.permissionDenied)));
    expect(browser.stopped, 0);
  });

  test('Dart startup failures do not become invalid JavaScript casts', () async {
    final browser = _Browser();
    final capture = WebIqAudioCapture(
      mediaDevices: browser.media,
      acquireContext: (_) async => throw StateError('Context is gone'),
      createWorklet: (_) async => browser.worklet,
    );
    await expectLater(capture.start(deviceId: 'usb-iq', sampleRate: 48000), throwsA(failure(IqAudioFailure.invalidFormat)));
    expect(browser.requested, isNull);
  });

  test('disposing during permission closes the late stream before creating a source', () async {
    final browser = _Browser()..pending = Completer<web.MediaStream>();
    final capture = browser.capture();
    final starting = capture.start(deviceId: 'usb-iq', sampleRate: 48000);
    final failureResult = expectLater(starting, throwsA(failure(IqAudioFailure.deviceUnavailable)));
    await Future<void>.delayed(Duration.zero);
    expect(browser.requested, isNotNull);
    await capture.dispose();
    browser.pending!.complete(browser.input);
    await failureResult;
    expect(browser.stopped, 1);
    expect(browser.disconnected, isFalse);
  });

  test('the real browser worklet preserves stereo order and little-endian PCM16', () async {
    final context = web.OfflineAudioContext(2.toJS, 2048, 48000);
    final worklet = await createIqAudioWorklet(context);
    final received = Completer<Uint8List>();
    worklet.port.onmessage = ((web.MessageEvent event) {
      if (!received.isCompleted && event.data.isA<JSArrayBuffer>()) {
        received.complete((event.data as JSArrayBuffer).toDart.asUint8List());
      }
    }).toJS;
    final buffer = context.createBuffer(2, 2048, 48000);
    buffer.getChannelData(0).toDart.fillRange(0, 2048, -0.5);
    buffer.getChannelData(1).toDart.fillRange(0, 2048, 0.25);
    final source = context.createBufferSource()..buffer = buffer;
    source.connect(worklet);
    worklet.connect(context.destination);
    source.start();
    final silent = await context.startRendering().toDart;
    final bytes = await received.future.timeout(const Duration(seconds: 3));
    final data = ByteData.sublistView(bytes);
    expect(bytes.length, 4096);
    for (var i = 0; i < bytes.length; i += 4) {
      expect(data.getInt16(i, Endian.little), -16384);
      expect(data.getInt16(i + 2, Endian.little), 8192);
    }
    expect(silent.getChannelData(0).toDart.every((sample) => sample == 0), isTrue);
    worklet.port.close();
  });

  test('the real worklet refuses mono instead of upmixing to two channels', () async {
    final context = web.OfflineAudioContext(2.toJS, 2048, 48000);
    final worklet = await createIqAudioWorklet(context);
    final received = Completer<String>();
    worklet.port.onmessage = ((web.MessageEvent event) {
      if (!received.isCompleted && event.data.isA<JSString>()) received.complete((event.data as JSString).toDart);
    }).toJS;
    final source = context.createBufferSource()..buffer = context.createBuffer(1, 2048, 48000);
    source.connect(worklet);
    worklet.connect(context.destination);
    source.start();
    await context.startRendering().toDart;
    expect(await received.future.timeout(const Duration(seconds: 3)), 'invalidFormat');
    worklet.port.close();
  });

  test('the real worklet fails when its consumer stops acknowledging samples', () async {
    final context = web.OfflineAudioContext(2.toJS, 34 * 1024, 48000);
    final worklet = await createIqAudioWorklet(context);
    final failed = Completer<String>();
    var blocks = 0;
    worklet.port.onmessage = ((web.MessageEvent event) {
      if (event.data.isA<JSArrayBuffer>()) blocks++;
      if (!failed.isCompleted && event.data.isA<JSString>()) failed.complete((event.data as JSString).toDart);
    }).toJS;
    final source = context.createBufferSource()..buffer = context.createBuffer(2, 34 * 1024, 48000);
    source.connect(worklet);
    worklet.connect(context.destination);
    source.start();
    await context.startRendering().toDart;
    expect(await failed.future.timeout(const Duration(seconds: 3)), 'overrun');
    expect(blocks, 32, reason: 'a stalled main thread must not accumulate an unbounded audio queue or silently lose samples');
    worklet.port.close();
  });
}

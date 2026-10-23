// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'iq_audio_types.dart';

bool get iqAudioSupported => false;
bool get iqAudioNeedsAccess => false;

Future<void> prepareIqAudioAccess({int sampleRate = 48000}) async => throw const IqAudioException(IqAudioFailure.unsupported);

Future<List<IqAudioInput>> listIqAudioInputs() async => const [];

IqAudioCapture createIqAudioCapture() => _UnsupportedIqAudioCapture();

class _UnsupportedIqAudioCapture implements IqAudioCapture {
  @override
  Future<Stream<Uint8List>> start({required String deviceId, required int sampleRate}) async => throw const IqAudioException(IqAudioFailure.unsupported);

  @override
  Future<void> dispose() async {}
}

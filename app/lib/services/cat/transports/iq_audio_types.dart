// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import '../transport.dart' show CatUnreachable;

class IqAudioInput {
  final String id;
  final String label;

  const IqAudioInput({required this.id, required this.label});
}

enum IqAudioFailure { permissionDenied, deviceUnavailable, unsupported, invalidFormat, sampleRateMismatch }

class IqAudioException implements CatUnreachable {
  final IqAudioFailure reason;
  final String? details;

  const IqAudioException(this.reason, {this.details});

  @override
  String toString() => 'IqAudioException(${reason.name}${details == null ? '' : ': $details'})';
}

/// One capture of an explicitly selected stereo input. Samples are signed,
/// little-endian PCM16, interleaved left/right. No file is recorded.
abstract interface class IqAudioCapture {
  Future<Stream<Uint8List>> start({required String deviceId, required int sampleRate});

  /// Also cancels a start still awaiting the operator's audio permission.
  Future<void> dispose();
}

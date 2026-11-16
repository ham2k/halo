// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The web's AudioEngine: the same surface as engine_ffi.dart, which the
// analyzer reads this one in place of, with nothing behind it.

part of 'audio_stub.dart';

class AudioEngine {
  factory AudioEngine() => throw UnsupportedError('halo_audio: no audio on this platform');

  static const rate = 48000;

  AudioEndpoint openInput({String? deviceId, int channels = 1}) => throw UnsupportedError('halo_audio: no audio on this platform');

  AudioEndpoint openOutput({String? deviceId, int channels = 2}) => throw UnsupportedError('halo_audio: no audio on this platform');

  AudioEndpoint addPushed({int channels = 1}) => throw UnsupportedError('halo_audio: no audio on this platform');

  AudioEndpoint addPulled({int channels = 1, bool gated = false}) => throw UnsupportedError('halo_audio: no audio on this platform');

  AudioSocket openSocket({int port = 0}) => throw UnsupportedError('halo_audio: no audio on this platform');

  AudioEndpoint addFlexDaxRx(AudioSocket socket, int streamId) => throw UnsupportedError('halo_audio: no audio on this platform');

  AudioEndpoint addFlexDaxTx(AudioSocket socket, {required String host, int port = 4991, required int streamId, int ahead = 2}) =>
      throw UnsupportedError('halo_audio: no audio on this platform');

  AudioRoute connect(
    AudioEndpoint source,
    AudioEndpoint sink, {
    Duration start = const Duration(milliseconds: 10),
    Duration max = const Duration(milliseconds: 200),
  }) => throw UnsupportedError('halo_audio: no audio on this platform');

  void close() {}
}

class AudioEndpoint {
  AudioEndpoint._();

  AudioEngine get engine => throw UnsupportedError('halo_audio: no audio on this platform');

  int get id => 0;

  int get channels => 0;

  Future<void> get gone => Completer<void>().future;

  void push(Float32List samples) {}

  Float32List pull(int frames) => Float32List(0);

  set gate(bool open) {}

  set sending(bool on) {}

  AudioSenderStats get senderStats => throw UnsupportedError('halo_audio: no audio on this platform');

  AudioReceiverStats get receiverStats => throw UnsupportedError('halo_audio: no audio on this platform');

  double takePeak() => 0;

  void close() {}
}

class AudioRoute {
  AudioRoute._();

  AudioEngine get engine => throw UnsupportedError('halo_audio: no audio on this platform');

  int get id => 0;

  void setGain(double left, double right) {}

  AudioRouteStats get stats => throw UnsupportedError('halo_audio: no audio on this platform');

  void disconnect() {}
}

class AudioRouteStats {
  AudioRouteStats._();

  double get depthMs => 0;

  double get targetMs => 0;

  double get ratioPpm => 0;

  int get underruns => 0;

  int get skips => 0;

  int get dropped => 0;

  bool get running => false;
}

class AudioSenderStats {
  AudioSenderStats._();

  int get sent => 0;

  int get reanchored => 0;

  int get lateMaxUs => 0;

  double get lateMeanUs => 0;
}

class AudioReceiverStats {
  AudioReceiverStats._();

  int get packets => 0;

  int get lost => 0;
}

class AudioDatagram {
  AudioDatagram(this.data, this.host, this.port);

  final Uint8List data;
  final String host;
  final int port;
}

class AudioSocket {
  AudioSocket._();

  AudioEngine get engine => throw UnsupportedError('halo_audio: no audio on this platform');

  int get id => 0;

  int get port => 0;

  Stream<AudioDatagram> get datagrams => const Stream.empty();

  int get dropped => 0;

  void send(String host, int port, Uint8List bytes) {}

  void close() {}
}

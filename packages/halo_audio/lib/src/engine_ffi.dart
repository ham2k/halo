// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The live audio engine's binding (docs/design/audio.md, halo_audio_engine.h).
// A part of audio_ffi.dart, so it opens the same library.

part of 'audio_ffi.dart';

final _engineNew = _lib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>('halo_audio_engine_new');
final _engineFree = _lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('halo_audio_engine_free');
typedef _OpenDeviceNative = Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32, Int64, Int64, Pointer<Utf8>, Int32);
typedef _OpenDevice = int Function(Pointer<Void>, Pointer<Utf8>, int, int, int, Pointer<Utf8>, int);
final _engineOpenInput = _lib.lookupFunction<_OpenDeviceNative, _OpenDevice>('halo_audio_engine_open_input');
final _engineOpenOutput = _lib.lookupFunction<_OpenDeviceNative, _OpenDevice>('halo_audio_engine_open_output');
final _engineAddPushed = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('halo_audio_engine_add_pushed');
final _engineAddPulled = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Int32), int Function(Pointer<Void>, int, int)>(
  'halo_audio_engine_add_pulled',
);
final _engineCloseEndpoint = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('halo_audio_engine_close_endpoint');
final _engineConnect = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Int32, Int32, Int32), int Function(Pointer<Void>, int, int, int, int)>(
  'halo_audio_engine_connect',
);
final _engineDisconnect = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('halo_audio_engine_disconnect');
final _engineSetGain = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Float, Float), int Function(Pointer<Void>, int, double, double)>(
  'halo_audio_engine_set_gain',
);
final _engineSetGate = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Int32), int Function(Pointer<Void>, int, int)>('halo_audio_engine_set_gate');
final _enginePush = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Pointer<Float>, Int32), int Function(Pointer<Void>, int, Pointer<Float>, int)>(
  'halo_audio_engine_push',
);
final _enginePull = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Pointer<Float>, Int32), int Function(Pointer<Void>, int, Pointer<Float>, int)>(
  'halo_audio_engine_pull',
);
final _engineEndpointAlive = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('halo_audio_engine_endpoint_alive');
final _engineRouteStats = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Pointer<Double>), int Function(Pointer<Void>, int, Pointer<Double>)>(
  'halo_audio_engine_route_stats',
);
final _engineTakePeak = _lib.lookupFunction<Float Function(Pointer<Void>, Int32), double Function(Pointer<Void>, int)>('halo_audio_engine_take_peak');

final _engineOpenSocket = _lib
    .lookupFunction<Int32 Function(Pointer<Void>, Int32, Int64, Int64, Pointer<Utf8>, Int32), int Function(Pointer<Void>, int, int, int, Pointer<Utf8>, int)>(
      'halo_audio_engine_open_socket',
    );
final _engineSocketPort = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('halo_audio_engine_socket_port');
final _engineSocketSend = _lib
    .lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Int32, Pointer<Uint8>, Int32),
      int Function(Pointer<Void>, int, Pointer<Utf8>, int, Pointer<Uint8>, int)
    >('halo_audio_engine_socket_send');
final _engineSocketTake = _lib
    .lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Uint8>, Int32, Pointer<Utf8>, Int32, Pointer<Int32>),
      int Function(Pointer<Void>, int, Pointer<Uint8>, int, Pointer<Utf8>, int, Pointer<Int32>)
    >('halo_audio_engine_socket_take');
final _engineSocketDropped = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('halo_audio_engine_socket_dropped');
final _engineCloseSocket = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('halo_audio_engine_close_socket');
final _engineAddFlexDaxRx = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Uint32), int Function(Pointer<Void>, int, int)>(
  'halo_audio_engine_add_flex_dax_rx',
);
final _engineAddFlexDaxTx = _lib
    .lookupFunction<Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>, Int32, Uint32, Int32), int Function(Pointer<Void>, int, Pointer<Utf8>, int, int, int)>(
      'halo_audio_engine_add_flex_dax_tx',
    );
final _engineSetSending = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Int32), int Function(Pointer<Void>, int, int)>(
  'halo_audio_engine_set_sending',
);
final _engineSenderStats = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Pointer<Double>), int Function(Pointer<Void>, int, Pointer<Double>)>(
  'halo_audio_engine_sender_stats',
);

const _routeStatCount = 7;
const _senderStatCount = 4;
const _receiverStatCount = 2;
final _engineReceiverStats = _lib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Pointer<Double>), int Function(Pointer<Void>, int, Pointer<Double>)>(
  'halo_audio_engine_receiver_stats',
);
const _datagramBytes = 8192; // NET_DATAGRAM_BYTES
const _hostBytes = 64;

/// The engine's sockets still open, by the token their datagram notice carries.
final _engineSockets = <int, AudioSocket>{};
final _onEngineDatagrams = _port((token) => _engineSockets[token]?._drain());

/// The engine's devices still open, by the token their lost callback carries.
final _engineDevices = <int, AudioEndpoint>{};
final _onEngineDeviceLost = _port((token) => _engineDevices[token]?._stopped());

/// The live audio engine: endpoints that audio enters and leaves through,
/// and routes between them. Everything runs at [rate] Hz, 32-bit float,
/// interleaved; an endpoint is mono or stereo.
class AudioEngine {
  AudioEngine._(this._handle);

  /// Throws [HaloAudioException] when the engine cannot be made.
  factory AudioEngine() {
    final handle = _engineNew();
    if (handle == nullptr) throw HaloAudioException('the audio engine could not be created');
    return AudioEngine._(handle);
  }

  static const rate = 48000;

  Pointer<Void> _handle;
  final _endpoints = <AudioEndpoint>{};
  final _sockets = <AudioSocket>{};

  Pointer<Void> get _live {
    if (_handle == nullptr) throw StateError('halo_audio: the engine is closed');
    return _handle;
  }

  /// The capture device [deviceId] (the system default when null) as a
  /// source. Throws [HaloAudioException] when it will not open.
  AudioEndpoint openInput({String? deviceId, int channels = 1}) => _openDevice(_engineOpenInput, deviceId, channels);

  /// The playback device [deviceId] (the system default when null) as a
  /// sink. Throws [HaloAudioException] when it will not open.
  AudioEndpoint openOutput({String? deviceId, int channels = 2}) => _openDevice(_engineOpenOutput, deviceId, channels);

  static void _checkChannels(int channels) {
    if (channels != 1 && channels != 2) throw ArgumentError.value(channels, 'channels', 'mono or stereo');
  }

  AudioEndpoint _openDevice(_OpenDevice open, String? deviceId, int channels) {
    _checkChannels(channels);
    final token = _nextToken++;
    final id = (deviceId ?? '').toNativeUtf8();
    final err = malloc<Uint8>(_errLen);
    err[0] = 0;
    try {
      final endpoint = open(_live, id, channels, _onEngineDeviceLost, token, err.cast(), _errLen);
      if (endpoint < 0) throw HaloAudioException(err.cast<Utf8>().toDartString());
      final opened = AudioEndpoint._(this, endpoint, channels, token);
      _engineDevices[token] = opened;
      _endpoints.add(opened);
      return opened;
    } finally {
      malloc.free(id);
      malloc.free(err);
    }
  }

  /// A source fed by [AudioEndpoint.push].
  AudioEndpoint addPushed({int channels = 1}) {
    _checkChannels(channels);
    final id = _engineAddPushed(_live, channels);
    if (id < 0) throw HaloAudioException('no room for another endpoint');
    return AudioEndpoint._(this, id, channels).._addTo(_endpoints);
  }

  /// A sink drained by [AudioEndpoint.pull]. A [gated] sink passes nothing
  /// until its [AudioEndpoint.gate] is opened.
  AudioEndpoint addPulled({int channels = 1, bool gated = false}) {
    _checkChannels(channels);
    final id = _engineAddPulled(_live, channels, gated ? 1 : 0);
    if (id < 0) throw HaloAudioException('no room for another endpoint');
    return AudioEndpoint._(this, id, channels).._addTo(_endpoints);
  }

  /// A UDP socket bound to [port] (any, for 0) with a receive thread of its
  /// own. Throws [HaloAudioException] when it will not open.
  AudioSocket openSocket({int port = 0}) {
    final token = _nextToken++;
    final err = malloc<Uint8>(_errLen);
    err[0] = 0;
    try {
      final id = _engineOpenSocket(_live, port, _onEngineDatagrams, token, err.cast(), _errLen);
      if (id < 0) throw HaloAudioException(err.cast<Utf8>().toDartString());
      final socket = AudioSocket._(this, id, token);
      _engineSockets[token] = socket;
      _sockets.add(socket);
      return socket;
    } finally {
      malloc.free(err);
    }
  }

  /// A FlexRadio slice's `dax_rx` stream [streamId], arriving on [socket],
  /// as a stereo source.
  AudioEndpoint addFlexDaxRx(AudioSocket socket, int streamId) {
    final id = _engineAddFlexDaxRx(_live, socket.id, streamId);
    if (id < 0) throw HaloAudioException('dax_rx: no room for another stream on this socket');
    return AudioEndpoint._(this, id, 2)
      .._socket = socket
      .._addTo(_endpoints);
  }

  /// A gated stereo sink sent from [socket] to the radio at [host]:[port]
  /// as its `dax_tx` stream [streamId], packets paced by a thread of its
  /// own while [AudioEndpoint.sending] is on, [ahead] of silence first.
  AudioEndpoint addFlexDaxTx(AudioSocket socket, {required String host, int port = 4991, required int streamId, int ahead = 2}) {
    final h = host.toNativeUtf8();
    try {
      final id = _engineAddFlexDaxTx(_live, socket.id, h, port, streamId, ahead);
      if (id < 0) throw HaloAudioException('dax_tx: cannot send to $host:$port');
      return AudioEndpoint._(this, id, 2)
        .._socket = socket
        .._addTo(_endpoints);
    } finally {
      malloc.free(h);
    }
  }

  /// A route from [source] to [sink] at unity gain, filling to [start]
  /// before the sink hears it and cut back past [max].
  AudioRoute connect(
    AudioEndpoint source,
    AudioEndpoint sink, {
    Duration start = const Duration(milliseconds: 10),
    Duration max = const Duration(milliseconds: 200),
  }) {
    final id = _engineConnect(_live, source.id, sink.id, start.inMilliseconds, max.inMilliseconds);
    if (id < 0) throw ArgumentError('halo_audio: cannot route endpoint ${source.id} to ${sink.id}');
    return AudioRoute._(this, id);
  }

  /// Closes every endpoint and the engine. Safe to call more than once.
  void close() {
    if (_handle == nullptr) return;
    for (final endpoint in [..._endpoints]) {
      endpoint._release();
    }
    _endpoints.clear();
    for (final socket in [..._sockets]) {
      socket._release();
    }
    _sockets.clear();
    _engineFree(_handle);
    _handle = nullptr;
  }
}

/// Where audio enters or leaves an [AudioEngine].
class AudioEndpoint {
  AudioEndpoint._(this.engine, this.id, this.channels, [this._token]);

  final AudioEngine engine;
  final int id;
  final int channels;
  final int? _token;
  AudioSocket? _socket;
  final _gone = Completer<void>();
  Pointer<Float> _buffer = nullptr;
  int _bufferSamples = 0;
  bool _closed = false;

  void _addTo(Set<AudioEndpoint> endpoints) => endpoints.add(this);

  bool _onSocket(AudioSocket socket) => identical(_socket, socket);

  /// Completes if a device endpoint's device stops by itself — unplugged, or
  /// taken by the system — and does not start again within a second, as a
  /// default device moved to a new default does. Never on [close].
  Future<void> get gone => _gone.future;

  void _stopped() {
    Timer(_rerouteGrace, () {
      if (_closed || _gone.isCompleted || engine._handle == nullptr) return;
      if (_engineEndpointAlive(engine._handle, id) != 1) _gone.complete();
    });
  }

  Pointer<Float> _samples(int count) {
    if (count > _bufferSamples) {
      if (_buffer != nullptr) malloc.free(_buffer);
      _buffer = malloc<Float>(count);
      _bufferSamples = count;
    }
    return _buffer;
  }

  /// Writes interleaved [samples] into every route from this pushed source.
  /// A route whose ring is full drops what does not fit and counts it
  /// ([AudioRouteStats.dropped]); nothing is to be pushed again.
  void push(Float32List samples) {
    final frames = samples.length ~/ channels;
    final buffer = _samples(frames * channels);
    buffer.asTypedList(frames * channels).setRange(0, frames * channels, samples);
    if (_enginePush(engine._live, id, buffer, frames) != 0) throw StateError('halo_audio: endpoint $id is not a pushed source');
  }

  /// [frames] interleaved frames of this pulled sink's mix.
  Float32List pull(int frames) {
    final buffer = _samples(frames * channels);
    if (_enginePull(engine._live, id, buffer, frames) != 0) throw StateError('halo_audio: endpoint $id is not a pulled sink');
    return Float32List.fromList(buffer.asTypedList(frames * channels));
  }

  /// Opens or shuts this sink's gate; opening drops what its routes held.
  set gate(bool open) {
    if (_engineSetGate(engine._live, id, open ? 1 : 0) != 0) throw StateError('halo_audio: endpoint $id is not a sink');
  }

  /// Starts or stops a sender's packets.
  set sending(bool on) {
    if (_engineSetSending(engine._live, id, on ? 1 : 0) != 0) throw StateError('halo_audio: endpoint $id is not a sender');
  }

  /// What a sender's thread has done.
  AudioSenderStats get senderStats {
    final out = malloc<Double>(_senderStatCount);
    try {
      if (_engineSenderStats(engine._live, id, out) != 0) throw StateError('halo_audio: endpoint $id is not a sender');
      return AudioSenderStats._(out.asTypedList(_senderStatCount));
    } finally {
      malloc.free(out);
    }
  }

  /// What a receiver's packets have done.
  AudioReceiverStats get receiverStats {
    final out = malloc<Double>(_receiverStatCount);
    try {
      if (_engineReceiverStats(engine._live, id, out) != 0) throw StateError('halo_audio: endpoint $id is not a receiver');
      return AudioReceiverStats._(out[0].toInt(), out[1].toInt());
    } finally {
      malloc.free(out);
    }
  }

  /// The loudest sample through this endpoint since the last call, 0..1.
  double takePeak() => _closed ? 0 : _engineTakePeak(engine._live, id);

  /// Closes this endpoint and its routes. Safe to call more than once.
  void close() {
    if (_closed || engine._handle == nullptr) return;
    _engineCloseEndpoint(engine._handle, id);
    _release();
    engine._endpoints.remove(this);
  }

  void _release() {
    _closed = true;
    if (_token != null) _engineDevices.remove(_token);
    if (_buffer != nullptr) malloc.free(_buffer);
    _buffer = nullptr;
    _bufferSamples = 0;
  }
}

/// A route between two endpoints: one clock bridge.
class AudioRoute {
  AudioRoute._(this.engine, this.id);

  final AudioEngine engine;
  final int id;

  /// The route's gain into the sink's left and right channels, ramped.
  void setGain(double left, double right) {
    if (_engineSetGain(engine._live, id, left, right) != 0) throw StateError('halo_audio: route $id is not connected');
  }

  AudioRouteStats get stats {
    final out = malloc<Double>(_routeStatCount);
    try {
      if (_engineRouteStats(engine._live, id, out) != 0) throw StateError('halo_audio: route $id is not connected');
      return AudioRouteStats._(out.asTypedList(_routeStatCount));
    } finally {
      malloc.free(out);
    }
  }

  void disconnect() => _engineDisconnect(engine._live, id);
}

/// What a route's bridge is doing.
class AudioRouteStats {
  AudioRouteStats._(List<double> values)
    : depthMs = values[0],
      targetMs = values[1],
      ratioPpm = values[2],
      underruns = values[3].toInt(),
      skips = values[4].toInt(),
      dropped = values[5].toInt(),
      running = values[6] != 0;

  /// The ring's depth averaged over half a second, and what it is steered to.
  final double depthMs;
  final double targetMs;

  /// How much faster than nominal the sink consumes the source.
  final double ratioPpm;

  /// Times the ring ran dry, times it was cut back, frames that found it full.
  final int underruns;
  final int skips;
  final int dropped;

  /// False while the ring fills before the sink hears it.
  final bool running;

  @override
  String toString() =>
      'depth ${depthMs.toStringAsFixed(2)} ms (target ${targetMs.toStringAsFixed(2)}), ${ratioPpm.toStringAsFixed(0)} ppm, '
      '$underruns underruns, $skips skips, $dropped dropped${running ? '' : ', filling'}';
}

/// What a sender's thread has done.
class AudioSenderStats {
  AudioSenderStats._(List<double> values) : sent = values[0].toInt(), reanchored = values[1].toInt(), lateMaxUs = values[2].toInt(), lateMeanUs = values[3];

  final int sent;

  /// Times it fell so far behind it started again from now.
  final int reanchored;

  /// How late it woke past a packet's deadline, at worst and on average.
  final int lateMaxUs;
  final double lateMeanUs;

  @override
  String toString() => '$sent sent, $reanchored re-anchored, late ${lateMeanUs.toStringAsFixed(0)} us mean, $lateMaxUs us max';
}

/// What a receiver's packets have done.
class AudioReceiverStats {
  AudioReceiverStats._(this.packets, this.lost);

  final int packets;

  /// Packets the stream's counter says never came, filled with the last.
  final int lost;

  @override
  String toString() => '$packets received, $lost lost';
}

/// A datagram no endpoint claimed.
class AudioDatagram {
  AudioDatagram(this.data, this.host, this.port);

  final Uint8List data;
  final String host;
  final int port;
}

/// A UDP socket of the engine's, with a receive thread of its own.
class AudioSocket {
  AudioSocket._(this.engine, this.id, this._token);

  final AudioEngine engine;
  final int id;
  final int _token;
  final _datagrams = StreamController<AudioDatagram>.broadcast(sync: true);
  bool _closed = false;

  /// The port it is bound to.
  int get port => _engineSocketPort(engine._live, id);

  /// The datagrams no endpoint on it claimed.
  Stream<AudioDatagram> get datagrams => _datagrams.stream;

  /// How many of them it dropped — too long, or with Dart too far behind.
  int get dropped => _engineSocketDropped(engine._live, id);

  /// The host last sent to, natively, and a buffer for what is sent: a
  /// voice keyer sends about 190 packets a second to one radio, each of
  /// which would otherwise copy the host and allocate a buffer. Freed when
  /// the socket closes.
  String? _sentHost;
  Pointer<Utf8> _sentHostNative = nullptr;
  Pointer<Uint8> _sendBuffer = nullptr;
  int _sendCapacity = 0;

  /// Sends [bytes] to [host] (a numeric address) and [port].
  void send(String host, int port, Uint8List bytes) {
    if (host != _sentHost) {
      if (_sentHostNative != nullptr) malloc.free(_sentHostNative);
      _sentHostNative = host.toNativeUtf8();
      _sentHost = host;
    }
    if (bytes.length > _sendCapacity) {
      if (_sendBuffer != nullptr) malloc.free(_sendBuffer);
      _sendBuffer = malloc<Uint8>(bytes.length);
      _sendCapacity = bytes.length;
    }
    _sendBuffer.asTypedList(bytes.length).setAll(0, bytes);
    if (_engineSocketSend(engine._live, id, _sentHostNative, port, _sendBuffer, bytes.length) != 0) throw HaloAudioException('send to $host:$port failed');
  }

  void _drain() {
    if (_closed || engine._handle == nullptr) return;
    final buffer = malloc<Uint8>(_datagramBytes);
    final host = malloc<Uint8>(_hostBytes);
    final port = malloc<Int32>();
    try {
      while (!_closed) {
        final length = _engineSocketTake(engine._handle, id, buffer, _datagramBytes, host.cast(), _hostBytes, port);
        if (length <= 0) break;
        _datagrams.add(AudioDatagram(Uint8List.fromList(buffer.asTypedList(length)), host.cast<Utf8>().toDartString(), port.value));
      }
    } finally {
      malloc.free(buffer);
      malloc.free(host);
      malloc.free(port);
    }
  }

  /// Closes the socket and every endpoint on it. Safe to call more than once.
  void close() {
    if (_closed || engine._handle == nullptr) return;
    _engineCloseSocket(engine._handle, id);
    for (final endpoint in [...engine._endpoints.where((e) => e._onSocket(this))]) {
      endpoint._release();
      engine._endpoints.remove(endpoint);
    }
    _release();
    engine._sockets.remove(this);
  }

  void _release() {
    _closed = true;
    _engineSockets.remove(_token);
    unawaited(_datagrams.close());
    if (_sentHostNative != nullptr) malloc.free(_sentHostNative);
    if (_sendBuffer != nullptr) malloc.free(_sendBuffer);
    _sentHostNative = nullptr;
    _sendBuffer = nullptr;
    _sendCapacity = 0;
    _sentHost = null;
  }
}

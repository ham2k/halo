// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'errors.dart';
import 'native_tls.dart';

/// A single encrypted TCP stream authenticated with a TLS 1.2 pre-shared key.
///
/// Socket I/O is asynchronous. Native code performs memory I/O and crypto only.
/// The single-subscription plaintext stream pauses the socket when unobserved
/// or paused; both wire input and pending plaintext writes have bounded queues.
class PskTlsConnection {
  static const _inputLimit = 256 * 1024;
  static const _inputHighWater = 128 * 1024;
  static const _inputLowWater = 64 * 1024;
  static const _outputLimit = 1024 * 1024;
  final NativeTls _tls;
  final _ready = Completer<PskTlsConnection>();
  final _closed = Completer<void>();
  final _incoming = ListQueue<Uint8List>();
  final _outgoing = ListQueue<Uint8List>();
  int _inputBytes = 0;
  int _outputBytes = 0;
  int _inputOffset = 0;
  int _outputOffset = 0;
  Socket? _socket;
  ConnectionTask<Socket>? _task;
  StreamSubscription<Uint8List>? _subscription;
  Timer? _deadline;
  bool _handshaken = false;
  bool _driving = false;
  bool _flushing = false;
  bool _disposed = false;
  bool _closing = false;
  bool _notifiedClose = false;
  bool _socketPaused = false;
  bool _inputPaused = false;
  bool _socketEnded = false;
  late final StreamController<Uint8List> _data = StreamController<Uint8List>(
    sync: true,
    onListen: _drive,
    onPause: _updateBackpressure,
    onResume: _drive,
    onCancel: () => unawaited(close()),
  );

  PskTlsConnection._(this._tls);

  static Future<PskTlsConnection> connect({
    required String host,
    required int port,
    required Uint8List psk,
    required String identity,
    Duration timeout = const Duration(seconds: 10),
    Future<void>? cancelled,
  }) async {
    final identityBytes = Uint8List.fromList(utf8.encode(identity));
    if (host.trim().isEmpty || port < 1 || port > 65535 || psk.isEmpty || psk.length > 256 || identityBytes.length > 128 || timeout <= Duration.zero) {
      throw const PskTlsException('invalidConfiguration');
    }
    final connection = PskTlsConnection._(NativeTls(psk, identityBytes));
    connection._deadline = Timer(timeout, () => connection._finish(const PskTlsException('timeout')));
    if (cancelled != null) {
      unawaited(cancelled.then((_) => connection._cancelConnect(), onError: (Object _, StackTrace _) => connection._cancelConnect()));
    }
    unawaited(connection._open(host, port));
    return connection._ready.future;
  }

  Stream<Uint8List> get data => _data.stream;
  Future<void> get closed => _closed.future;

  void _cancelConnect() {
    // The caller's token belongs to the connection attempt. Once returned,
    // the connection owner controls shutdown through close().
    if (!_handshaken) _finish(const PskTlsCancelledException());
  }

  Future<void> _open(String host, int port) async {
    try {
      final task = await Socket.startConnect(host, port);
      if (_disposed) {
        task.cancel();
        unawaited(task.socket.then((socket) => socket.destroy(), onError: (Object _, StackTrace _) {}));
        return;
      }
      _task = task;
      final socket = await task.socket;
      _task = null;
      if (_disposed) {
        socket.destroy();
        return;
      }
      _socket = socket;
      _subscription = socket.listen(
        _receive,
        onError: (Object _, StackTrace _) => _finish(const PskTlsException('connectionFailed')),
        onDone: () {
          // The final record may still be queued behind a pending wire flush.
          // Process it before deciding whether EOF omitted close_notify.
          _socketEnded = true;
          _drive();
        },
      );
      unawaited(socket.done.then((_) {}, onError: (Object _, StackTrace _) {}));
      _drive();
    } on Object {
      _finish(const PskTlsException('connectFailed'));
    }
  }

  void _receive(Uint8List bytes) {
    if (_disposed) return;
    if (bytes.length > _inputLimit - _inputBytes) {
      _finish(const PskTlsException('bufferLimit'));
      return;
    }
    _incoming.add(bytes);
    _inputBytes += bytes.length;
    _drive();
    // _drive may be waiting for a wire flush and return before its finally.
    // Pause incoming events before a slow writer can exhaust the wire queue.
    _updateBackpressure();
  }

  /// Writes are copied because callers may reuse their byte buffers. A full
  /// queue closes the stream and reports an error instead of growing memory.
  void send(List<int> bytes) {
    if (_disposed || _closing || bytes.isEmpty) return;
    if (bytes.length > _outputLimit - _outputBytes) {
      _finish(const PskTlsException('bufferLimit'));
      return;
    }
    _outgoing.add(Uint8List.fromList(bytes));
    _outputBytes += bytes.length;
    _drive();
  }

  bool _feed() {
    if (_incoming.isEmpty) return false;
    final head = _incoming.first;
    final end = (_inputOffset + tlsChunkSize).clamp(0, head.length);
    final chunk = Uint8List.sublistView(head, _inputOffset, end);
    if (_tls.feed(chunk) != chunk.length) {
      _finish(const PskTlsException('bufferLimit'));
      return false;
    }
    _inputBytes -= chunk.length;
    _inputOffset = end;
    if (end == head.length) {
      _incoming.removeFirst();
      _inputOffset = 0;
    }
    return true;
  }

  void _drive() {
    if (_driving || _disposed || _flushing || _socket == null) return;
    _driving = true;
    try {
      var turns = 0;
      while (!_disposed && !_flushing && turns++ < 64) {
        if (_flushOutput()) return;
        int status;
        if (_closing && _outgoing.isEmpty) {
          if (_notifiedClose) {
            _finish();
            return;
          }
          status = _tls.closeNotify();
          if (status == 0) _notifiedClose = true;
        } else if (!_handshaken) {
          status = _tls.handshake();
          if (status == 0) {
            _handshaken = true;
            _deadline?.cancel();
            _ready.complete(this);
          }
        } else if (_outgoing.isNotEmpty) {
          final head = _outgoing.first;
          final end = (_outputOffset + tlsChunkSize).clamp(0, head.length);
          status = _tls.write(Uint8List.sublistView(head, _outputOffset, end));
          if (status > 0) {
            _outputBytes -= status;
            _outputOffset += status;
            if (_outputOffset == head.length) {
              _outgoing.removeFirst();
              _outputOffset = 0;
            }
          }
        } else {
          if (!_data.hasListener || _data.isPaused) return;
          final result = _tls.read();
          status = result.status;
          if (result.bytes case final bytes?) _data.add(bytes);
          if (_disposed || _closing) continue;
          if (status == 0 || status == tlsPeerClosed) {
            unawaited(close());
            return;
          }
        }
        if (_disposed) return;
        if (status < 0 && status != tlsWantRead && status != tlsWantWrite) {
          _finish(PskTlsException(_handshaken ? 'connectionFailed' : 'handshakeFailed'));
          return;
        }
        if (_flushOutput()) return;
        if (status == tlsWantRead) {
          if (!_feed()) {
            if (_socketEnded) _finish(_closing ? null : PskTlsException(_handshaken ? 'connectionFailed' : 'handshakeFailed'));
            return;
          }
        } else if (status == tlsWantWrite) {
          // WANT_WRITE without queued output cannot make progress.
          _finish(const PskTlsException('connectionFailed'));
          return;
        }
      }
      if (!_disposed && !_flushing) scheduleMicrotask(_drive);
    } finally {
      _driving = false;
      _updateBackpressure();
    }
  }

  bool _flushOutput() {
    final bytes = _tls.drain();
    if (bytes.isEmpty) return false;
    _flushing = true;
    unawaited(_writeWire(bytes));
    return true;
  }

  Future<void> _writeWire(Uint8List bytes) async {
    try {
      _socket!.add(bytes);
      await _socket!.flush();
    } on Object {
      if (!_disposed) _finish(_closing ? null : const PskTlsException('connectionFailed'));
    } finally {
      _flushing = false;
      if (!_disposed) _drive();
    }
  }

  void _updateBackpressure() {
    if (_disposed || _subscription == null) return;
    if (_inputBytes >= _inputHighWater) _inputPaused = true;
    if (_inputBytes <= _inputLowWater) _inputPaused = false;
    final pause = _inputPaused || (_handshaken && !_closing && (!_data.hasListener || _data.isPaused));
    if (pause == _socketPaused) return;
    _socketPaused = pause;
    pause ? _subscription!.pause() : _subscription!.resume();
  }

  /// Flushes pending writes and close_notify within a bounded window.
  /// Repeated closes and sends after close are harmless.
  Future<void> close() {
    if (_disposed || _closing) return closed;
    if (!_handshaken) {
      _finish(const PskTlsCancelledException());
      return closed;
    }
    _closing = true;
    _deadline = Timer(const Duration(seconds: 1), _finish);
    _driving ? scheduleMicrotask(_drive) : _drive();
    return closed;
  }

  void _finish([PskTlsException? error]) {
    if (_disposed) return;
    _disposed = true;
    _deadline?.cancel();
    _task?.cancel();
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    _socket?.destroy();
    _tls.dispose();
    _incoming.clear();
    _outgoing.clear();
    if (!_ready.isCompleted) {
      _ready.completeError(error ?? const PskTlsCancelledException());
    } else if (error != null) {
      _data.addError(error);
    }
    unawaited(_data.close());
    _closed.complete();
  }
}

// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../error_reporting_service.dart';
import '../driver.dart';
import '../drivers/k4_remote_codec.dart';
import '../drivers/k4_shared_session.dart';
import '../transport.dart';
import 'k4_remote_connection.dart';

typedef K4SharedSessionFactory =
    K4SharedSession Function({required void Function(List<int>) send, required Stream<K4RemotePanPacket> pan, required Map<String, dynamic> config});

typedef K4ConnectionOpener = Future<EquipmentConnection> Function(Map<String, dynamic> target, {required CatCancelToken cancel});

/// One authenticated connection per explicitly paired physical radio. A host
/// address alone never establishes that two configured radios may share it.
class K4SharedConnectionPool {
  final K4SharedSessionFactory _createSession;
  final void Function(String key, List<int> bytes)? _onSend;
  final void Function(String key, List<int> bytes)? _onReceive;
  final _entries = <String, _SharedEntry>{};
  final _liveEntries = <_SharedEntry>{};
  bool _disposed = false;
  Future<void>? _disposing;

  K4SharedConnectionPool({K4SharedSessionFactory? createSession, this._onSend, this._onReceive}) : _createSession = createSession ?? K4SharedSession.new;

  Future<K4ReceiverConnection> acquire({
    required String key,
    required Map<String, dynamic> target,
    required Map<String, dynamic> config,
    required K4ConnectionOpener open,
    required CatCancelToken cancel,
  }) {
    if (_disposed || cancel.isCancelled) return Future.error(const CatCancelledException());
    final connectionTarget = _settings(target), connectionConfig = _settings(config);
    var entry = _entries[key];
    if (entry != null && !entry.matches(connectionTarget, connectionConfig)) {
      // Never interpolate settings: they contain the remote password.
      return Future.error(StateError('Paired K4 receivers have different connection settings'));
    }
    final fresh = entry == null;
    entry ??= _SharedEntry(this, key, connectionTarget, connectionConfig, open);
    if (fresh) {
      _entries[key] = entry;
      _liveEntries.add(entry);
    }
    final result = entry.acquire(cancel);
    if (fresh) unawaited(entry.start());
    return result;
  }

  void _evict(_SharedEntry entry) {
    if (identical(_entries[entry.key], entry)) _entries.remove(entry.key);
  }

  Future<void> dispose() {
    _disposed = true;
    return _disposing ??= Future.wait([for (final entry in _liveEntries.toList()) entry.close()]).then((_) {});
  }
}

Map<String, dynamic> _settings(Map<String, dynamic> settings) => Map<String, dynamic>.unmodifiable({
  for (final entry in settings.entries)
    if (entry.key != 'receiver') entry.key: _snapshot(entry.value),
});

Object? _snapshot(Object? value) => switch (value) {
  Map<String, dynamic> value => Map<String, dynamic>.unmodifiable({for (final entry in value.entries) entry.key: _snapshot(entry.value)}),
  Map<Object?, Object?> value => Map<Object?, Object?>.unmodifiable({for (final entry in value.entries) entry.key: _snapshot(entry.value)}),
  List<Object?> value => List<Object?>.unmodifiable(value.map(_snapshot)),
  Set<Object?> value => Set<Object?>.unmodifiable(value.map(_snapshot)),
  _ => value,
};

class _PendingReceiver {
  final CatCancelToken cancel;
  final result = Completer<K4ReceiverConnection>();
  _PendingReceiver(this.cancel);
}

class _SharedEntry {
  final K4SharedConnectionPool pool;
  final String key;
  final Map<String, dynamic> target, config;
  final K4ConnectionOpener open;
  final _openCancel = CatCancelToken();
  final _openDone = Completer<void>();
  final _closeDone = Completer<void>();
  final _pending = <_PendingReceiver>{};
  final _leases = <K4ReceiverConnection>{};
  EquipmentConnection? _connection;
  K4SharedSession? _owner;
  StreamSubscription<Uint8List>? _subscription;
  bool _ready = false;
  bool _closing = false;

  _SharedEntry(this.pool, this.key, this.target, this.config, this.open);

  bool matches(Map<String, dynamic> target, Map<String, dynamic> config) =>
      const DeepCollectionEquality().equals(this.target, target) && const DeepCollectionEquality().equals(this.config, config);

  Future<K4ReceiverConnection> acquire(CatCancelToken cancel) {
    final pending = _PendingReceiver(cancel);
    _pending.add(pending);
    unawaited(
      cancel.whenCancelled.then((_) {
        if (!_pending.remove(pending)) return;
        pending.result.completeError(const CatCancelledException());
        if (_pending.isEmpty && _leases.isEmpty) unawaited(close());
      }),
    );
    if (_ready) _deliver(pending);
    return pending.result.future;
  }

  void _deliver(_PendingReceiver pending) {
    if (!_pending.remove(pending)) return;
    if (_closing || pending.cancel.isCancelled) {
      pending.result.completeError(const CatCancelledException());
      if (_pending.isEmpty && _leases.isEmpty) unawaited(close());
      return;
    }
    final lease = K4ReceiverConnection._(this);
    _leases.add(lease);
    pending.result.complete(lease);
  }

  Future<void> start() async {
    try {
      final connection = _connection = await open(target, cancel: _openCancel);
      if (_closing) return;
      final pan = switch (connection) {
        K4RemoteConnection() => connection.pan,
        _ => const Stream<K4RemotePanPacket>.empty(),
      };
      _owner = pool._createSession(send: send, pan: pan, config: config);
      // This reader exists before any receiver attaches: an early RDY must
      // reach the one protocol owner, even with no facade listening yet.
      _subscription = connection.data.listen(_receive, onDone: close, onError: (Object _, StackTrace _) => close());
      unawaited(connection.closed.then((_) => close(), onError: (Object _, StackTrace _) => close()));
      _ready = true;
      for (final pending in _pending.toList()) {
        _deliver(pending);
      }
    } catch (error, stack) {
      _rejectPending(error, stack);
      unawaited(close());
    } finally {
      _openDone.complete();
    }
  }

  void _receive(Uint8List bytes) {
    if (_closing) return;
    try {
      pool._onReceive?.call(key, bytes);
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'cat:log-receive:k4-shared');
    }
    // Raw-command collectors observe the wire before a driver reacts to it.
    for (final lease in _leases.toList()) {
      lease._receive(bytes);
    }
    if (_closing) return;
    try {
      _owner!.handleData(bytes);
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'cat:handle-data:k4-shared');
    }
  }

  void send(List<int> bytes) {
    final connection = _connection;
    if (connection == null || _closeDone.isCompleted) return;
    // Log at the physical boundary: two receiver facades must not duplicate
    // one shared startup or teardown command in the traffic recording.
    try {
      pool._onSend?.call(key, bytes);
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'cat:log-send:k4-shared');
    }
    try {
      connection.send(bytes);
    } catch (_) {
      unawaited(close());
    }
  }

  void _rejectPending(Object error, [StackTrace? stack]) {
    for (final pending in _pending) {
      pending.result.completeError(error, stack);
    }
    _pending.clear();
  }

  Future<void> release(K4ReceiverConnection lease) {
    _leases.remove(lease);
    lease._finish();
    if (_closing) return _closeDone.future;
    return _leases.isEmpty && _pending.isEmpty ? close() : Future.value();
  }

  Future<void> close() {
    if (_closing) return _closeDone.future;
    _closing = true;
    // Reconnects may begin while the old socket drains, but cannot acquire
    // another facade onto the connection that just failed.
    pool._evict(this);
    _openCancel.cancel();
    _rejectPending(const CatCancelledException());
    try {
      _owner?.teardown();
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'cat:teardown:k4-shared');
    }
    for (final lease in _leases.toList()) {
      lease._finish();
    }
    _leases.clear();
    unawaited(_finishClose());
    return _closeDone.future;
  }

  Future<void> _finishClose() async {
    try {
      // A cancelled transport can still finish opening. Keep its entry alive
      // until that late handle is closed, including during pool disposal.
      await _openDone.future;
      try {
        await _subscription?.cancel();
      } finally {
        await _connection?.close();
      }
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'cat:close:k4-shared');
    } finally {
      pool._liveEntries.remove(this);
      _closeDone.complete();
    }
  }
}

/// One logical receiver's lease. Raw CAT remains available for connection
/// proof and traffic logging; its session facade does not parse it again.
class K4ReceiverConnection implements EquipmentConnection {
  final _SharedEntry _entry;
  final _data = StreamController<Uint8List>(sync: true);
  final _closed = Completer<void>();
  Future<void>? _closing;
  EquipmentSession? _session;

  K4ReceiverConnection._(this._entry);

  EquipmentSession createSession(EquipmentSink sink, {required String receiver}) {
    if (_closed.isCompleted || _entry._closing) throw StateError('K4 receiver connection is closed');
    if (_session != null) throw StateError('K4 receiver already has a session');
    return _session = _entry._owner!.attach(sink, receiver: receiver);
  }

  @override
  Stream<Uint8List> get data => _data.stream;

  @override
  Future<void> get closed => _closed.future;

  void _receive(Uint8List bytes) {
    // CAT proof is live, not a replay queue. A suspended receiver must not
    // buffer the physical radio's stream while its sibling keeps reading.
    if (!_closed.isCompleted && _data.hasListener && !_data.isPaused) _data.add(bytes);
  }

  @override
  void send(List<int> bytes) {
    if (!_closed.isCompleted) _entry.send(bytes);
  }

  void _finish() {
    if (_closed.isCompleted) return;
    _closed.complete();
    try {
      _session?.teardown();
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'cat:teardown:k4-receiver');
    }
    // A receiver may close itself from a synchronous CAT callback.
    scheduleMicrotask(() => unawaited(_data.close()));
  }

  @override
  Future<void> close() => _closing ??= _entry.release(this);
}

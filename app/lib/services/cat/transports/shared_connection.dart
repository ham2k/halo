// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../error_reporting_service.dart';
import '../driver.dart';
import '../transport.dart';

/// What speaks the protocol on a connection several receivers share: it
/// alone reads the wire, and each receiver's session is a facade over it.
abstract interface class SharedConnectionOwner {
  /// Called once per chunk by the physical connection, however many
  /// receivers lease it.
  void handleData(Uint8List bytes);

  /// [receiver] is the receiver's key on the radio: a K4's `main` or `sub`,
  /// a Flex slice's index.
  EquipmentSession attach(EquipmentSink sink, {required String receiver});

  /// Only the physical connection's final release tears shared state down.
  void teardown();
}

typedef SharedConnectionOwnerFactory =
    SharedConnectionOwner Function(EquipmentConnection connection, void Function(List<int>) send, Map<String, dynamic> config);

typedef SharedConnectionOpener = Future<EquipmentConnection> Function(Map<String, dynamic> target, {required CatCancelToken cancel});

/// One connection per physical radio, leased to each of its receivers. A
/// host address alone never establishes that two configured radios may
/// share it: the caller names the radio by [acquire]'s key.
class SharedConnectionPool {
  final SharedConnectionOwnerFactory _createOwner;
  final void Function(String key, List<int> bytes)? _onSend;
  final void Function(String key, List<int> bytes)? _onReceive;

  /// Config keys that differ between receivers of one radio, and so are
  /// left out when two leases' settings are compared.
  final Set<String> _perReceiverKeys;
  final _entries = <String, _SharedEntry>{};
  final _liveEntries = <_SharedEntry>{};
  bool _disposed = false;
  Future<void>? _disposing;

  SharedConnectionPool({required this._createOwner, this._perReceiverKeys = const {}, this._onSend, this._onReceive});

  Future<SharedReceiverConnection> acquire({
    required String key,
    required Map<String, dynamic> target,
    required Map<String, dynamic> config,
    required SharedConnectionOpener open,
    required CatCancelToken cancel,
  }) {
    if (_disposed || cancel.isCancelled) return Future.error(const CatCancelledException());
    final connectionTarget = _settings(target, _perReceiverKeys), connectionConfig = _settings(config, _perReceiverKeys);
    var entry = _entries[key];
    if (entry != null && !entry.matches(connectionTarget, connectionConfig)) {
      // Never interpolate settings: they contain the remote password.
      return Future.error(StateError('Receivers sharing a connection have different connection settings'));
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

Map<String, dynamic> _settings(Map<String, dynamic> settings, Set<String> perReceiver) => Map<String, dynamic>.unmodifiable({
  for (final entry in settings.entries)
    if (!perReceiver.contains(entry.key)) entry.key: _snapshot(entry.value),
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
  final result = Completer<SharedReceiverConnection>();
  _PendingReceiver(this.cancel);
}

class _SharedEntry {
  final SharedConnectionPool pool;
  final String key;
  final Map<String, dynamic> target, config;
  final SharedConnectionOpener open;
  final _openCancel = CatCancelToken();
  final _openDone = Completer<void>();
  final _closeDone = Completer<void>();
  final _pending = <_PendingReceiver>{};
  final _leases = <SharedReceiverConnection>{};
  EquipmentConnection? _connection;
  SharedConnectionOwner? _owner;
  StreamSubscription<Uint8List>? _subscription;
  bool _ready = false;
  bool _closing = false;

  /// Why the physical connection ended, for every receiver on it: the
  /// connection's own reason where it gives one.
  String? _lostReason;

  _SharedEntry(this.pool, this.key, this.target, this.config, this.open);

  bool matches(Map<String, dynamic> target, Map<String, dynamic> config) =>
      const DeepCollectionEquality().equals(this.target, target) && const DeepCollectionEquality().equals(this.config, config);

  Future<SharedReceiverConnection> acquire(CatCancelToken cancel) {
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
    final lease = SharedReceiverConnection._(this);
    _leases.add(lease);
    pending.result.complete(lease);
  }

  Future<void> start() async {
    try {
      final connection = _connection = await open(target, cancel: _openCancel);
      if (_closing) return;
      _owner = pool._createOwner(connection, send, config);
      // This reader exists before any receiver attaches: an early RDY must
      // reach the one protocol owner, even with no facade listening yet.
      _subscription = connection.data.listen(_receive, onDone: _lost, onError: (Object _, StackTrace _) => _lost());
      unawaited(connection.closed.then((_) => _lost(), onError: (Object _, StackTrace _) => _lost()));
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
      ErrorReportingService.report(error, stack, context: 'cat:log-receive:shared');
    }
    // Raw-command collectors observe the wire before a driver reacts to it.
    for (final lease in _leases.toList()) {
      lease._receive(bytes);
    }
    if (_closing) return;
    try {
      _owner!.handleData(bytes);
    } catch (error, stack) {
      ErrorReportingService.report(error, stack, context: 'cat:handle-data:shared');
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
      ErrorReportingService.report(error, stack, context: 'cat:log-send:shared');
    }
    try {
      connection.send(bytes);
    } catch (e) {
      _lost('a write failed (${e.runtimeType})');
    }
  }

  void _rejectPending(Object error, [StackTrace? stack]) {
    for (final pending in _pending) {
      pending.result.completeError(error, stack);
    }
    _pending.clear();
  }

  Future<void> release(SharedReceiverConnection lease) {
    _leases.remove(lease);
    lease._finish();
    if (_closing) return _closeDone.future;
    return _leases.isEmpty && _pending.isEmpty ? close() : Future.value();
  }

  void _lost([String? fallback]) {
    if (_closing) return;
    final reason = switch (_connection) {
      ExplainsClose(:final closeReason) => closeReason,
      _ => null,
    };
    _lostReason = reason ?? fallback;
    unawaited(close());
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
      ErrorReportingService.report(error, stack, context: 'cat:teardown:shared');
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
      ErrorReportingService.report(error, stack, context: 'cat:close:shared');
    } finally {
      pool._liveEntries.remove(this);
      _closeDone.complete();
    }
  }
}

/// One logical receiver's lease. Raw CAT remains available for connection
/// proof and traffic logging; its session facade does not parse it again.
class SharedReceiverConnection implements EquipmentConnection, ExplainsClose {
  final _SharedEntry _entry;
  final _data = StreamController<Uint8List>(sync: true);
  final _closed = Completer<void>();
  Future<void>? _closing;
  EquipmentSession? _session;

  SharedReceiverConnection._(this._entry);

  /// The physical connection's reason, unless this receiver was closed on
  /// its own: a sibling's close is not why this one ended.
  @override
  String? get closeReason => _closing == null ? _entry._lostReason : null;

  EquipmentSession createSession(EquipmentSink sink, {required String receiver}) {
    if (_closed.isCompleted || _entry._closing) throw StateError('The receiver connection is closed');
    if (_session != null) throw StateError('The receiver already has a session');
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
      ErrorReportingService.report(error, stack, context: 'cat:teardown:shared-receiver');
    }
    // A receiver may close itself from a synchronous CAT callback.
    scheduleMicrotask(() => unawaited(_data.close()));
  }

  @override
  Future<void> close() => _closing ??= _entry.release(this);

  /// The physical connection is dead, as this receiver found: it closes for
  /// every receiver on it, so that a reconnect opens a new one rather than
  /// leasing the dead one again while a sibling still holds it.
  void drop(String reason) => _entry._lost(reason);
}

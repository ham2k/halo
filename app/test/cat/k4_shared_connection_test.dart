// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_shared_session.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/k4_shared_connection.dart';

class _Physical implements EquipmentConnection {
  final List<String> events;
  final incoming = StreamController<Uint8List>(sync: true);
  final gone = Completer<void>();
  Completer<void>? closeBarrier;
  int closeCalls = 0;

  _Physical(this.events);

  @override
  Stream<Uint8List> get data => incoming.stream;
  @override
  Future<void> get closed => gone.future;
  @override
  void send(List<int> bytes) => events.add('send:${ascii.decode(bytes)}');

  void receive(String text) => incoming.add(Uint8List.fromList(ascii.encode(text)));

  void drop() {
    if (!gone.isCompleted) gone.complete();
    unawaited(incoming.close());
  }

  @override
  Future<void> close() async {
    closeCalls++;
    events.add('physical-close');
    if (!gone.isCompleted) gone.complete();
    await closeBarrier?.future;
    if (!incoming.isClosed) unawaited(incoming.close());
  }
}

class _Facade implements EquipmentSession {
  final List<String> events;
  final String receiver;
  bool detached = false;
  VoidCallback? onTeardown;
  _Facade(this.events, this.receiver);

  @override
  void handleData(Uint8List _) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void teardown() {
    if (detached) return;
    detached = true;
    events.add('detach:$receiver');
    onTeardown?.call();
  }
}

class _Owner extends K4SharedSession {
  final List<String> events;
  final void Function(List<int>) write;
  final received = <String>[];
  final facades = <_Facade>[];
  final Map<String, dynamic> settings;
  bool throwNext = false;
  VoidCallback? onHandle;
  int teardowns = 0;

  _Owner(this.events, {required this.write, required this.settings}) : super(send: (_) {}, pan: const Stream<K4RemotePanPacket>.empty(), config: const {});

  @override
  void handleData(Uint8List bytes) {
    received.add(ascii.decode(bytes));
    onHandle?.call();
    if (throwNext) {
      throwNext = false;
      throw StateError('synthetic driver parse failure');
    }
  }

  @override
  EquipmentSession attach(EquipmentSink sink, {required String receiver}) {
    final facade = _Facade(events, receiver);
    facades.add(facade);
    return facade;
  }

  @override
  void teardown() {
    teardowns++;
    events.add('owner-teardown');
    write(ascii.encode('RX;'));
    super.teardown();
  }
}

class _Sink implements EquipmentSink {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Attempt {
  final Map<String, dynamic> target;
  final CatCancelToken cancel;
  final result = Completer<EquipmentConnection>();
  _Attempt(this.target, this.cancel);
}

class _Harness {
  final events = <String>[];
  final attempts = <_Attempt>[];
  final owners = <_Owner>[];
  final void Function(String key, List<int> bytes)? onSend;
  late final pool = K4SharedConnectionPool(
    onSend: onSend,
    createSession: ({required send, required pan, required config}) {
      final owner = _Owner(events, write: send, settings: config);
      owners.add(owner);
      return owner;
    },
  );

  _Harness({this.onSend}) {
    addTearDown(() async {
      for (final attempt in attempts) {
        if (!attempt.result.isCompleted) attempt.result.completeError(const CatCancelledException());
      }
      await pool.dispose();
    });
  }

  Future<EquipmentConnection> open(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    final attempt = _Attempt(target, cancel);
    attempts.add(attempt);
    return attempt.result.future;
  }

  Future<K4ReceiverConnection> acquire({
    String key = 'physical-1',
    String receiver = 'main',
    Map<String, dynamic>? target,
    Map<String, dynamic>? config,
    CatCancelToken? cancel,
  }) => pool.acquire(
    key: key,
    target: target ?? {'host': '192.0.2.1', 'port': 9204, 'password': 'test-secret'},
    config: config ?? {'receiver': receiver, 'telemetry': false},
    open: open,
    cancel: cancel ?? CatCancelToken(),
  );

  _Physical succeed([int index = 0]) {
    final connection = _Physical(events);
    attempts[index].result.complete(connection);
    return connection;
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.value();
  }
}

void main() {
  test('concurrent receivers share one open and one parser, including CAT before attach', () async {
    final h = _Harness();
    final mainFuture = h.acquire();
    final subFuture = h.acquire(receiver: 'sub');
    expect(h.attempts, hasLength(1));
    final physical = h.succeed();
    final main = await mainFuture, sub = await subFuture;
    expect(h.owners, hasLength(1));
    physical.receive('RDY;');
    expect(h.owners.single.received, ['RDY;']);

    final mainData = <String>[], subData = <String>[];
    final mainSession = main.createSession(_Sink(), receiver: 'main');
    final subSession = sub.createSession(_Sink(), receiver: 'sub');
    main.data.listen((bytes) {
      mainData.add(ascii.decode(bytes));
      h.events.add('main-cat');
      mainSession.handleData(bytes);
    });
    sub.data.listen((bytes) {
      subData.add(ascii.decode(bytes));
      h.events.add('sub-cat');
      subSession.handleData(bytes);
    });
    h.owners.single.onHandle = () => h.events.add('parse');
    physical.receive('FA00014074000;');
    expect(h.events, ['main-cat', 'sub-cat', 'parse'], reason: 'raw-command collectors run before the shared driver');
    expect(h.owners.single.received, ['RDY;', 'FA00014074000;']);
    expect(mainData, ['FA00014074000;']);
    expect(subData, mainData);
  });

  test('closing one receiver leaves its sibling live; final close tears down before the socket', () async {
    final h = _Harness();
    final mainFuture = h.acquire(), subFuture = h.acquire(receiver: 'sub');
    final physical = h.succeed();
    final main = await mainFuture, sub = await subFuture;
    main.createSession(_Sink(), receiver: 'main');
    sub.createSession(_Sink(), receiver: 'sub');
    await main.close();
    expect(h.events, ['detach:main']);
    expect(physical.closeCalls, 0);
    sub.send(ascii.encode('FB;'));
    expect(h.events.last, 'send:FB;');

    physical.closeBarrier = Completer<void>();
    addTearDown(() {
      if (!physical.closeBarrier!.isCompleted) physical.closeBarrier!.complete();
    });
    var firstDone = false, secondDone = false;
    final first = sub.close().then((_) => firstDone = true);
    final second = sub.close().then((_) => secondDone = true);
    await sub.closed;
    await _flush();
    expect((firstDone, secondDone), (false, false));
    expect(h.events, containsAllInOrder(['detach:sub', 'owner-teardown', 'send:RX;', 'physical-close']));
    expect(physical.closeCalls, 1);
    physical.closeBarrier!.complete();
    await Future.wait([first, second]);
    expect(h.owners.single.teardowns, 1);
  });

  test('shared startup, receiver commands and teardown are logged once before each physical send', () async {
    final logged = <(String, String)>[];
    late final _Harness h;
    h = _Harness(
      onSend: (key, bytes) {
        final command = ascii.decode(bytes);
        logged.add((key, command));
        h.events.add('log:$command');
      },
    );
    final mainFuture = h.acquire(), subFuture = h.acquire(receiver: 'sub');
    final physical = h.succeed();
    final main = await mainFuture, sub = await subFuture;
    h.owners.single.write(ascii.encode('K40;K31;'));
    h.owners.single.write(ascii.encode('RDY;'));
    main.send(ascii.encode('FA;'));
    sub.send(ascii.encode('FB;'));
    await main.close();
    await sub.close();
    expect(logged, [('physical-1', 'K40;K31;'), ('physical-1', 'RDY;'), ('physical-1', 'FA;'), ('physical-1', 'FB;'), ('physical-1', 'RX;')]);
    expect(h.events.where((event) => event.startsWith('log:') || event.startsWith('send:')), [
      for (final (_, command) in logged) ...['log:$command', 'send:$command'],
    ]);
    expect(physical.closeCalls, 1);
    // A caller retaining an old owner cannot keep recording phantom writes.
    h.owners.single.write(ascii.encode('FA;'));
    expect(logged, hasLength(5));
  });

  test('a failed send-log callback is reported without dropping the physical command', () async {
    final messages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previousDebugPrint);
    final h = _Harness(onSend: (_, _) => throw StateError('synthetic send-log failure'));
    final future = h.acquire();
    h.succeed();
    final lease = await future;
    lease.send(ascii.encode('FA;'));
    expect(h.events, ['send:FA;']);
    expect(messages.any((message) => message.contains('cat:log-send:k4-shared')), isTrue);
    await lease.close();
    expect(h.events, containsAllInOrder(['owner-teardown', 'send:RX;', 'physical-close']));
  });

  test('cancelling one pending receiver does not cancel a sibling open', () async {
    final h = _Harness();
    final mainCancel = CatCancelToken();
    final mainFuture = h.acquire(cancel: mainCancel);
    final mainRejected = expectLater(mainFuture, throwsA(isA<CatCancelledException>()));
    final subFuture = h.acquire(receiver: 'sub');
    mainCancel.cancel();
    await mainRejected;
    expect(h.attempts.single.cancel.isCancelled, isFalse);
    final physical = h.succeed();
    final sub = await subFuture;
    expect(physical.closeCalls, 0);
    sub.send(ascii.encode('FB;'));
    expect(h.events, ['send:FB;']);
  });

  test('final pending cancellation evicts the entry and closes a late transport', () async {
    final h = _Harness();
    final cancel = CatCancelToken();
    final cancelled = expectLater(h.acquire(cancel: cancel), throwsA(isA<CatCancelledException>()));
    cancel.cancel();
    await cancelled;
    expect(h.attempts.single.cancel.isCancelled, isTrue);
    final retry = h.acquire();
    expect(h.attempts, hasLength(2));
    final late = h.succeed(0);
    h.succeed(1);
    await retry;
    await _flush();
    expect(late.closeCalls, 1);
    expect(h.owners, hasLength(1), reason: 'a cancelled open must never create a driver');
  });

  test('different credentials or settings cannot join a physical key and errors expose neither', () async {
    final h = _Harness();
    final first = h.acquire();
    h.succeed();
    await first;
    for (final mismatch in [
      () => h.acquire(target: {'host': '192.0.2.1', 'port': 9204, 'password': 'other-secret'}),
      () => h.acquire(config: {'receiver': 'sub', 'telemetry': true}),
      () => h.acquire(target: {'host': '192.0.2.2', 'port': 9204, 'password': 'test-secret'}),
    ]) {
      await expectLater(
        mismatch(),
        throwsA(isA<StateError>().having((error) => error.toString(), 'redacted message', allOf(isNot(contains('secret')), isNot(contains('192.0.2'))))),
      );
    }
    expect(h.attempts, hasLength(1));
  });

  test('connection settings are compared by value and snapshotted before opening', () async {
    final h = _Harness();
    final target = <String, dynamic>{'host': '192.0.2.1', 'password': 'original'};
    final config = <String, dynamic>{
      'receiver': 'main',
      'nested': <String, dynamic>{
        'modes': ['USB'],
      },
    };
    final first = h.acquire(target: target, config: config);
    target['password'] = 'mutated';
    (config['nested']['modes'] as List).add('CW');
    final second = h.acquire(
      receiver: 'sub',
      target: {'password': 'original', 'host': '192.0.2.1'},
      config: {
        'nested': {
          'modes': ['USB'],
        },
        'receiver': 'sub',
      },
    );
    expect(h.attempts, hasLength(1));
    expect(h.attempts.single.target['password'], 'original');
    h.succeed();
    await Future.wait([first, second]);
    expect(h.owners.single.settings.containsKey('receiver'), isFalse);
    expect(h.owners.single.settings['nested'], {
      'modes': ['USB'],
    });
  });

  test('different explicit physical keys never pool even at the same address', () async {
    final h = _Harness();
    final first = h.acquire(), second = h.acquire(key: 'physical-2');
    expect(h.attempts, hasLength(2));
    h.succeed(0);
    h.succeed(1);
    await Future.wait([first, second]);
    expect(h.owners, hasLength(2));
  });

  test('a physical drop closes every receiver and a retry gets a fresh entry before drain', () async {
    final h = _Harness();
    final mainFuture = h.acquire(), subFuture = h.acquire(receiver: 'sub');
    final physical = h.succeed();
    final main = await mainFuture, sub = await subFuture;
    main.createSession(_Sink(), receiver: 'main');
    sub.createSession(_Sink(), receiver: 'sub');
    physical.closeBarrier = Completer<void>();
    addTearDown(() {
      if (!physical.closeBarrier!.isCompleted) physical.closeBarrier!.complete();
    });
    physical.drop();
    await Future.wait([main.closed, sub.closed]);
    final retry = h.acquire();
    expect(h.attempts, hasLength(2));
    h.succeed(1);
    await retry;
    expect(h.owners.first.teardowns, 1);
    expect(h.owners.first.facades.every((facade) => facade.detached), isTrue);
    physical.closeBarrier!.complete();
    await main.close();
    expect(physical.closeCalls, 1);
  });

  test('paused and unlistened receivers do not accumulate raw CAT', () async {
    final h = _Harness();
    final mainFuture = h.acquire(), subFuture = h.acquire(receiver: 'sub');
    final physical = h.succeed();
    final main = await mainFuture, sub = await subFuture;
    physical.receive('before-listen;');
    final mainData = <String>[], subData = <String>[];
    final mainReader = main.data.listen((bytes) => mainData.add(ascii.decode(bytes)));
    sub.data.listen((bytes) => subData.add(ascii.decode(bytes)));
    mainReader.pause();
    for (var i = 0; i < 1000; i++) {
      physical.receive('PONG;');
    }
    mainReader.resume();
    await _flush();
    expect(mainData, isEmpty);
    expect(subData, hasLength(1000));
    expect(h.owners.single.received, hasLength(1001));
    physical.receive('after-resume;');
    expect(mainData, ['after-resume;']);
  });

  test('a CAT listener can close itself synchronously without reentrant stream closure', () async {
    final h = _Harness();
    final future = h.acquire();
    final physical = h.succeed();
    final lease = await future;
    final readerDone = Completer<void>();
    lease.data.listen((_) => unawaited(lease.close()), onDone: readerDone.complete);
    physical.receive('PONG;');
    await lease.close();
    await readerDone.future;
    expect(physical.closeCalls, 1);
    expect(h.owners.single.teardowns, 1);
  });

  test('a facade teardown can reenter close without completing the receiver twice', () async {
    final h = _Harness();
    final future = h.acquire();
    final physical = h.succeed();
    final lease = await future;
    final facade = lease.createSession(_Sink(), receiver: 'main') as _Facade;
    facade.onTeardown = () => unawaited(lease.close());
    await lease.close();
    await lease.closed;
    expect(physical.closeCalls, 1);
    expect(h.owners.single.teardowns, 1);
    expect(h.events.where((event) => event == 'detach:main'), hasLength(1));
  });

  test('one driver parse exception is reported and does not stop shared CAT delivery', () async {
    final h = _Harness();
    final future = h.acquire();
    final physical = h.succeed();
    final lease = await future;
    final logged = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logged.add(message);
    };
    addTearDown(() => debugPrint = previousDebugPrint);
    final data = <String>[];
    lease.data.listen((bytes) => data.add(ascii.decode(bytes)));
    h.owners.single.throwNext = true;
    physical.receive('malformed;');
    physical.receive('PONG;');
    expect(logged.any((line) => line.contains('cat:handle-data:k4-shared')), isTrue);
    expect(data, ['malformed;', 'PONG;']);
    expect(physical.closeCalls, 0);
  });

  test('failed opens reject every waiter and permit a fresh attempt', () async {
    final h = _Harness();
    final failure = StateError('synthetic open failure');
    final first = expectLater(h.acquire(), throwsA(same(failure)));
    final second = expectLater(h.acquire(receiver: 'sub'), throwsA(same(failure)));
    h.attempts.single.result.completeError(failure);
    await Future.wait([first, second]);
    final retry = h.acquire();
    expect(h.attempts, hasLength(2));
    h.succeed(1);
    await retry;
  });

  test('disposal cancels pending opens, closes late handles and rejects new acquisitions', () async {
    final h = _Harness();
    final first = h.acquire();
    final physical = h.succeed();
    final lease = await first;
    final pending = expectLater(h.acquire(key: 'physical-2'), throwsA(isA<CatCancelledException>()));
    var disposed = false;
    final disposal = h.pool.dispose().then((_) => disposed = true);
    await lease.closed;
    await pending;
    expect(h.attempts.last.cancel.isCancelled, isTrue);
    expect(disposed, isFalse);
    final late = h.succeed(1);
    await disposal;
    expect((physical.closeCalls, late.closeCalls), (1, 1));
    await expectLater(h.acquire(), throwsA(isA<CatCancelledException>()));
    expect(h.attempts, hasLength(2));
  });

  test('an already cancelled request never opens a transport', () async {
    final h = _Harness();
    await expectLater(h.acquire(cancel: CatCancelToken()..cancel()), throwsA(isA<CatCancelledException>()));
    expect(h.attempts, isEmpty);
  });
}

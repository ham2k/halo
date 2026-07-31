// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CatService's contract, with a fake transport and a fake driver so none
// of it needs a socket or a radio.
//
// Most of what's asserted here is race handling, and each case is a bug
// app-polo actually shipped and then had to fix (docs/design/cat.md): a
// superseded connect leaking its socket, a stale close clobbering a live
// connection, a throwing teardown skipping the close, a connection that
// never asks the radio for anything. None of them are hypothetical, and
// none of them are visible without a test that can control the timing.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- fakes

class _FakeConnection implements EquipmentConnection {
  final String label;
  final List<String> log;
  final _dataController = StreamController<Uint8List>();
  final _closedCompleter = Completer<void>();
  final sent = <String>[];
  var closeCalled = false;

  _FakeConnection(this.label, this.log);

  @override
  Stream<Uint8List> get data => _dataController.stream;

  @override
  Future<void> get closed => _closedCompleter.future;

  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes));

  @override
  Future<void> close() async {
    closeCalled = true;
    log.add('close:$label');
    _drop();
  }

  /// The connection going away on its own — the radio powering off, the
  /// network dropping.
  void dropRemotely() => _drop();

  void _drop() {
    if (_closedCompleter.isCompleted) return;
    _closedCompleter.complete();
    unawaited(_dataController.close());
  }

  void push(String text) => _dataController.add(Uint8List.fromList(utf8.encode(text)));
}

class _Attempt {
  final Map<String, dynamic> target;
  final CatCancelToken cancel;
  final completer = Completer<EquipmentConnection>();

  _Attempt(this.target, this.cancel);
}

class _FakeTransport implements EquipmentTransport {
  final attempts = <_Attempt>[];

  /// Whether a cancelled attempt gives up. True mirrors the real
  /// transports; setting it false is how the "the transport ignored us and
  /// connected anyway" case gets exercised.
  var honorsCancellation = true;

  @override
  String get key => 'fake';

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    final attempt = _Attempt(target, cancel);
    attempts.add(attempt);
    if (honorsCancellation) {
      unawaited(cancel.whenCancelled.then((_) {
        if (!attempt.completer.isCompleted) attempt.completer.completeError(const CatCancelledException());
      }));
    }
    return attempt.completer.future;
  }
}

class _FakeSession implements EquipmentSession {
  final EquipmentSink sink;
  final List<String> log;
  var updatesStarted = false;
  var teardownThrows = false;

  _FakeSession(this.sink, this.log);

  /// A toy protocol: `<kHz> <mode>` per line.
  @override
  void handleData(Uint8List chunk) {
    for (final line in utf8.decode(chunk).split('\n')) {
      if (line.trim().isEmpty) continue;
      if (line == 'BOOM') throw StateError('malformed frame');
      final parts = line.trim().split(' ');
      sink.report(VfoReading(
        freqKHz: double.tryParse(parts[0]),
        mode: parts.length > 1 ? parts[1] : null,
      ));
    }
  }

  @override
  void startUpdates() {
    updatesStarted = true;
    log.add('startUpdates');
    sink.send(utf8.encode('SUB'));
  }

  @override
  void stopUpdates() => log.add('stopUpdates');

  /// Drivers report from their own timers, so a session can try to publish
  /// long after the connection it belongs to has been superseded.
  void reportFromItsOwnTimer(VfoReading reading) => sink.report(reading);

  @override
  void setFrequency(double freqKHz) => log.add('setFrequency:$freqKHz');

  @override
  void setMode(String mode) => log.add('setMode:$mode');

  @override
  void teardown() {
    log.add('teardown');
    if (teardownThrows) throw StateError('teardown blew up');
  }
}

class _FakeDriver implements EquipmentDriver {
  final List<String> log;
  final sessions = <_FakeSession>[];
  var teardownThrows = false;

  _FakeDriver(this.log);

  @override
  String get key => 'fake-driver';

  @override
  String get name => 'Fake Radio';

  @override
  bool get hardwareVerified => false;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _FakeSession(sink, log)..teardownThrows = teardownThrows;
    sessions.add(session);
    return session;
  }
}

class _FakeType extends EquipmentType {
  @override
  final EquipmentDriver driver;

  _FakeType(this.driver);

  @override
  String get key => 'fake-type';

  @override
  String get category => kCategoryTransceiver;

  @override
  String get name => 'Fake Radio (Network)';

  @override
  String get transportKey => 'fake';

  @override
  Map<String, dynamic> get defaultConfig => const {'host': ''};

  @override
  List<Map<String, dynamic>> configElements() =>
      [const {'type': 'field', 'fieldType': 'text', 'key': 'host', 'label': 'Host'}];

  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {'host': config['host']};

  @override
  String describeTarget(Map<String, dynamic> config) => '${config['host']}';

  @override
  String? validate(Map<String, dynamic> config) => validateField('host', config['host'], config);

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != 'host') return null;
    return (value as String? ?? '').isEmpty ? 'An address is required' : null;
  }
}

// ----------------------------------------------------------------- setup

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late _FakeTransport transport;
  late _FakeDriver driver;
  late List<String> log;
  late CatService cat;

  Future<CatService> makeService() async {
    settings = SettingsService(await SharedPreferences.getInstance());
    log = [];
    transport = _FakeTransport();
    driver = _FakeDriver(log);
    return CatService(
      settings,
      registry: EquipmentRegistry(
        types: [_FakeType(driver)],
        transports: {'fake': transport},
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cat = await makeService();
  });

  Future<EquipmentNode> addRadio({String host = 'radio.local'}) =>
      cat.addNode(typeKey: 'fake-type', name: 'Left Radio', config: {'host': host});

  /// Connects and lands the connection, returning it.
  Future<_FakeConnection> connectAndLand(EquipmentNode node) async {
    final connecting = cat.connect(node.uuid);
    await pumpEventQueue();
    final connection = _FakeConnection('c${transport.attempts.length}', log);
    transport.attempts.last.completer.complete(connection);
    await connecting;
    return connection;
  }

  // ------------------------------------------------------------ storage

  group('storage', () {
    test('equipment round-trips through prefs, and live status is not stored', () async {
      final node = await addRadio();
      await connectAndLand(node);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

      // A fresh service reading the same prefs is what a relaunch does.
      final reloaded = await makeService();
      expect(reloaded.nodes.map((n) => n.uuid), [node.uuid]);
      expect(reloaded.nodes.single.name, 'Left Radio');
      expect(reloaded.nodes.single.config['host'], 'radio.local');
      // polo shipped a persisted `connected` that survived restarts and
      // claimed a radio was there when it wasn't.
      expect(reloaded.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    });

    test('editing and removing persist', () async {
      final node = await addRadio();
      await cat.updateNode(node.copyWith(name: 'Right Radio', config: {'host': '10.0.0.9'}));

      var reloaded = await makeService();
      expect(reloaded.nodes.single.name, 'Right Radio');
      expect(reloaded.nodes.single.config['host'], '10.0.0.9');

      await cat.removeNode(node.uuid);
      reloaded = await makeService();
      expect(reloaded.nodes, isEmpty);
    });

    test('a corrupt record drops that node, not the whole list', () async {
      SharedPreferences.setMockInitialValues({
        'stationEquipment': jsonEncode({
          'version': 1,
          'nodes': {
            'good': {'typeKey': 'fake-type', 'name': 'Keeps working'},
            'no-type': {'name': 'Missing its typeKey'},
            'not-a-map': 'garbage',
          },
        }),
      });
      final reloaded = await makeService();
      expect(reloaded.nodes.map((n) => n.uuid), ['good']);
    });

    test('a node whose type is gone stays listed rather than vanishing', () async {
      SharedPreferences.setMockInitialValues({
        'stationEquipment': jsonEncode({
          'version': 1,
          'nodes': {
            'orphan': {'typeKey': 'a-driver-we-removed', 'name': 'Old Rig'},
          },
        }),
      });
      final reloaded = await makeService();
      // Losing the record along with the driver would silently discard the
      // user's settings; the panel shows it as unrecognized instead.
      expect(reloaded.nodes.single.name, 'Old Rig');
      expect(reloaded.typeFor(reloaded.nodes.single), isNull);
    });
  });

  // ------------------------------------------------------------ connect

  group('connect', () {
    test('reports connecting, then connected, and starts updates on connect', () async {
      final node = await addRadio();
      final connecting = cat.connect(node.uuid);
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connecting);

      final connection = _FakeConnection('c1', log);
      transport.attempts.single.completer.complete(connection);
      await connecting;

      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
      // polo gated this on a UI subscriber refcount, so connecting with no
      // screen mounted produced a green status and a frozen frequency.
      expect(driver.sessions.single.updatesStarted, isTrue);
      expect(connection.sent, contains('SUB'));
    });

    test('the target comes from the type, not the raw config', () async {
      final node = await addRadio(host: 'flex.local');
      unawaited(cat.connect(node.uuid));
      await pumpEventQueue();
      expect(transport.attempts.single.target, {'host': 'flex.local'});
    });

    test('readings from the session become node state, merged and de-duplicated', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);

      var notifications = 0;
      cat.addListener(() => notifications++);

      connection.push('14074 USB\n');
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 14074, mode: 'USB'));
      expect(notifications, 1);

      // A frequency-only reading keeps the mode.
      connection.push('14075\n');
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 14075, mode: 'USB'));

      // A radio re-reporting what it already said must not churn listeners —
      // once this drives RadioService, every one of these would be a
      // SharedPreferences write.
      notifications = 0;
      connection.push('14075 USB\n');
      await pumpEventQueue();
      expect(notifications, 0);
    });

    test('a malformed frame does not kill the connection', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);

      connection.push('BOOM\n');
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

      connection.push('14074 USB\n');
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).vfo.freqKHz, 14074);
    });

    test('a failed connect reports the error', () async {
      final node = await addRadio();
      final connecting = cat.connect(node.uuid);
      await pumpEventQueue();
      transport.attempts.single.completer.completeError(StateError('Connection refused'));
      await connecting;

      expect(cat.stateFor(node.uuid).status, EquipmentStatus.error);
      expect(cat.stateFor(node.uuid).error, contains('Connection refused'));
    });

    test('an unusable configuration is refused before any socket is opened', () async {
      final node = await cat.addNode(typeKey: 'fake-type', config: {'host': ''});
      await cat.connect(node.uuid);

      expect(cat.stateFor(node.uuid).status, EquipmentStatus.error);
      expect(cat.stateFor(node.uuid).error, 'An address is required');
      expect(transport.attempts, isEmpty);
    });

    test('an unknown type reports an error rather than throwing', () async {
      final node = await cat.addNode(typeKey: 'nope', config: {'host': 'x'});
      await cat.connect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.error);
      expect(transport.attempts, isEmpty);
    });

    test('a dropped connection reports disconnected', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);

      connection.dropRemotely();
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    });
  });

  // -------------------------------------------------------------- races

  group('races', () {
    test('a second connect cancels the first attempt instead of racing it', () async {
      final node = await addRadio();
      final first = cat.connect(node.uuid);
      await pumpEventQueue();

      final second = cat.connect(node.uuid);
      await pumpEventQueue();

      // Some radios refuse a second session while the first handshake is
      // still running, so the loser has to actually stop, not just lose.
      expect(transport.attempts.first.cancel.isCancelled, isTrue);
      await first;

      transport.attempts.last.completer.complete(_FakeConnection('c2', log));
      await second;
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
    });

    test('a superseded attempt that lands anyway is closed, not installed', () async {
      // Cancellation is cooperative: a transport that doesn't implement it
      // (or that races it) still hands back a live connection. The attempt
      // sequence is the backstop, and without it that connection is never
      // closed — exactly the leak polo added its sequence counter to fix.
      transport.honorsCancellation = false;
      final node = await addRadio();

      final first = cat.connect(node.uuid);
      await pumpEventQueue();
      final firstAttempt = transport.attempts.single;

      final second = cat.connect(node.uuid);
      await pumpEventQueue();

      final orphan = _FakeConnection('orphan', log);
      firstAttempt.completer.complete(orphan);
      await first;

      final winner = _FakeConnection('winner', log);
      transport.attempts.last.completer.complete(winner);
      await second;
      await pumpEventQueue();

      expect(orphan.closeCalled, isTrue, reason: 'the superseded connection must not leak');
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
      expect(winner.closeCalled, isFalse);
    });

    test('a stale connection closing does not clobber the live one', () async {
      final node = await addRadio();
      final stale = await connectAndLand(node);
      final live = await connectAndLand(node);

      // The old socket's close callback arrives late.
      stale.dropRemotely();
      await pumpEventQueue();

      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected,
          reason: 'the live connection is still up');

      live.dropRemotely();
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    });

    test('a stale session cannot write state', () async {
      final node = await addRadio();
      await connectAndLand(node);
      final staleSession = driver.sessions.single;
      await connectAndLand(node);

      // The old session's poll timer fires once more before it's collected.
      staleSession.reportFromItsOwnTimer(const VfoReading(freqKHz: 7123, mode: 'LSB'));
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(),
          reason: 'a superseded session must not report readings');
    });

    test('disconnect cancels an attempt still in flight', () async {
      final node = await addRadio();
      final connecting = cat.connect(node.uuid);
      await pumpEventQueue();

      await cat.disconnect(node.uuid);
      expect(transport.attempts.single.cancel.isCancelled, isTrue);
      await connecting;
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    });

    test('two nodes connect independently', () async {
      final first = await addRadio(host: 'a.local');
      final second = await addRadio(host: 'b.local');

      final firstConnection = await connectAndLand(first);
      await connectAndLand(second);

      expect(cat.stateFor(first.uuid).status, EquipmentStatus.connected);
      expect(cat.stateFor(second.uuid).status, EquipmentStatus.connected);

      // Per-node runtime state, not polo's module-level singletons: one
      // node going away must leave the other alone.
      firstConnection.dropRemotely();
      await pumpEventQueue();
      expect(cat.stateFor(first.uuid).status, EquipmentStatus.disconnected);
      expect(cat.stateFor(second.uuid).status, EquipmentStatus.connected);
    });
  });

  // ----------------------------------------------------------- teardown

  group('teardown', () {
    test('says goodbye over a still-open connection, then closes it', () async {
      final node = await addRadio();
      await connectAndLand(node);
      log.clear();

      await cat.disconnect(node.uuid);

      // Order matters: polo found abandoned sessions accumulating on a
      // radio until it refused new connections, surviving a power cycle.
      expect(log, ['teardown', 'close:c1']);
    });

    test('a throwing teardown still closes the connection', () async {
      driver.teardownThrows = true;
      final node = await addRadio();
      final connection = await connectAndLand(node);

      await cat.disconnect(node.uuid);
      expect(connection.closeCalled, isTrue);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    });

    test('removing a connected node disconnects it first', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);

      await cat.removeNode(node.uuid);
      expect(connection.closeCalled, isTrue);
      expect(cat.nodes, isEmpty);
    });
  });
}

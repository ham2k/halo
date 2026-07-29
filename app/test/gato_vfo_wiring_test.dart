// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// GATO driving the app's VFO, and being driven by it.
//
// The whole point of this layer is that the two directions don't fight.
// An app→radio tune produces a confirmation from the radio; a radio→app
// update lands in the same store the app writes to. Without an origin tag
// and an echo guard those two chase each other, so most of what's asserted
// here is that nothing bounces.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/gato/driver.dart';
import 'package:ham2k_logger/services/gato/equipment.dart';
import 'package:ham2k_logger/services/gato/equipment_registry.dart';
import 'package:ham2k_logger/services/gato/gato_service.dart';
import 'package:ham2k_logger/services/gato/transport.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnection implements EquipmentConnection {
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();

  @override
  Stream<Uint8List> get data => _data.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) {}
  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    unawaited(_data.close());
  }
}

/// A transport whose connects stay pending until the test says otherwise,
/// so the retry loop and a manual Connect can be made to overlap.
class _GatedTransport implements EquipmentTransport {
  final pending = <Completer<EquipmentConnection>>[];
  final cancels = <CatCancelToken>[];

  @override
  String get key => 'fake';

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    final completer = Completer<EquipmentConnection>();
    pending.add(completer);
    cancels.add(cancel);
    unawaited(cancel.whenCancelled.then((_) {
      if (!completer.isCompleted) completer.completeError(const CatCancelledException());
    }));
    return completer.future;
  }

  void land(int index) => pending[index].complete(_FakeConnection());
  void refuse(int index) => pending[index].completeError(const SocketException('refused'));
}

/// A radio that is switched off.
class _RefusingTransport implements EquipmentTransport {
  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async =>
      throw const SocketException('Connection refused');
}

class _FakeTransport implements EquipmentTransport {
  /// Kept so a test can close one from the outside, the way a radio being
  /// switched off closes it.
  final connections = <_FakeConnection>[];

  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    final connection = _FakeConnection();
    connections.add(connection);
    return connection;
  }
}

/// Records what the manager asked the radio to do, and can push readings
/// back the way a real radio's status stream would.
class _FakeSession implements EquipmentSession {
  final EquipmentSink sink;
  final List<String> commands = [];
  var throwOnSet = false;

  /// Fails only `setMode`, so a partial delivery can be staged: the
  /// frequency reaches the radio and the mode does not.
  var throwOnSetMode = false;

  _FakeSession(this.sink);

  void radioReports({double? freqKHz, String? mode}) =>
      sink.report(VfoReading(freqKHz: freqKHz, mode: mode));

  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void setFrequency(double freqKHz) {
    if (throwOnSet) throw StateError('driver blew up');
    commands.add('freq:$freqKHz');
  }

  @override
  void setMode(String mode) {
    if (throwOnSet || throwOnSetMode) throw StateError('driver blew up');
    commands.add('mode:$mode');
  }
  var tornDown = false;

  @override
  void teardown() => tornDown = true;
}

class _FakeDriver implements EquipmentDriver {
  final sessions = <_FakeSession>[];

  @override
  String get key => 'fake-driver';
  @override
  String get name => 'Fake Radio';
  @override
  bool get hardwareVerified => false;
  @override
  EquipmentSession createSession(EquipmentSink sink) {
    final session = _FakeSession(sink);
    sessions.add(session);
    return session;
  }
}

class _FakeType implements EquipmentType {
  @override
  final EquipmentDriver driver;

  _FakeType(this.driver);

  @override
  String get key => 'fake-type';
  @override
  String get category => kCategoryTransceiver;
  @override
  String get name => 'Fake Radio';
  @override
  String get transportKey => 'fake';
  @override
  Map<String, dynamic> get defaultConfig => const {};
  @override
  List<Map<String, dynamic>> configElements() => const [];
  @override
  Map<String, dynamic> targetFor(Map<String, dynamic> config) => {'host': config['host']};
  @override
  String describeTarget(Map<String, dynamic> config) => '${config['host']}';
  @override
  String? validate(Map<String, dynamic> config) => null;
  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RadioService radio;
  late _FakeDriver driver;
  late _FakeTransport transport;
  late GatoService gato;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    radio = RadioService(prefs, writeDelay: Duration.zero);
    driver = _FakeDriver();
    transport = _FakeTransport();
    gato = GatoService(
      SettingsService(prefs),
      radio: radio,
      registry: EquipmentRegistry(
        types: [_FakeType(driver)],
        transports: {'fake': transport},
      ),
    );
  });

  tearDown(() {
    gato.dispose();
    radio.dispose();
  });

  Future<EquipmentNode> connectedRadio() async {
    final node = await gato.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'});
    await gato.connect(node.uuid);
    return node;
  }

  // A getter can't be declared inside a function body; this is the same thing.
  _FakeSession session() => driver.sessions.single;

  group('radio1', () {
    test('the first transceiver added drives the logging panel', () async {
      final node = await gato.addNode(typeKey: 'fake-type', config: {'host': 'a'});
      expect(gato.radio1, node.uuid);
      expect(gato.isRadio1(node.uuid), isTrue);
    });

    test('a second radio does not take over, but can be handed the job', () async {
      final first = await gato.addNode(typeKey: 'fake-type', config: {'host': 'a'});
      final second = await gato.addNode(typeKey: 'fake-type', config: {'host': 'b'});
      expect(gato.radio1, first.uuid);

      await gato.setRadio1(second.uuid);
      expect(gato.radio1, second.uuid);
    });

    test('removing the designated radio hands the job to another', () async {
      final first = await gato.addNode(typeKey: 'fake-type', config: {'host': 'a'});
      final second = await gato.addNode(typeKey: 'fake-type', config: {'host': 'b'});
      expect(gato.radio1, first.uuid);

      await gato.removeNode(first.uuid);
      // Otherwise the logging panel is left with nothing driving it and no
      // indication of why.
      expect(gato.radio1, second.uuid);

      await gato.removeNode(second.uuid);
      expect(gato.radio1, isNull);
    });

    test('the designation survives a restart', () async {
      await gato.addNode(typeKey: 'fake-type', config: {'host': 'a'});
      final second = await gato.addNode(typeKey: 'fake-type', config: {'host': 'b'});
      await gato.setRadio1(second.uuid);

      final reloaded = GatoService(SettingsService(await SharedPreferences.getInstance()));
      expect(reloaded.radio1, second.uuid);
    });
  });

  group('radio → app', () {
    test('what the radio reports becomes the app VFO', () async {
      await connectedRadio();
      session().radioReports(freqKHz: 14074.25, mode: 'USB');
      await pumpEventQueue();

      expect(radio.vfoA.freq, 14074.25);
      expect(radio.vfoA.mode, 'USB');
      expect(radio.vfoA.band, '20m', reason: 'the band is derived from the frequency');
    });

    test('the write is tagged as coming from the radio', () async {
      await connectedRadio();
      VfoOrigin? seen;
      radio.addListener(() => seen = radio.lastVfoOrigin);

      session().radioReports(freqKHz: 7100, mode: 'LSB');
      await pumpEventQueue();
      expect(seen, VfoOrigin.radio);
    });

    test('a radio that is not radio1 does not touch the app VFO', () async {
      await connectedRadio();
      final other = await gato.addNode(typeKey: 'fake-type', config: {'host': 'b'});
      await gato.connect(other.uuid);

      // The second radio's session, reporting while the first is radio1.
      driver.sessions.last.radioReports(freqKHz: 21000, mode: 'CW');
      await pumpEventQueue();

      expect(radio.vfoA.freq, isNull, reason: 'only radio1 drives the logging panel');
    });
  });

  group('app → radio', () {
    test('a user frequency change retunes the radio', () async {
      await connectedRadio();
      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();

      expect(session().commands, contains('freq:14074.0'));
      expect(session().commands, contains('mode:USB'));
    });

    test('SSB is resolved to a real sideband before the driver sees it', () async {
      await connectedRadio();

      radio.setVfo('vfoA', freq: 7150, mode: 'SSB');
      await pumpEventQueue();
      // No CAT protocol has an "SSB" mode.
      expect(session().commands, contains('mode:LSB'));
      expect(session().commands.any((c) => c.contains('SSB')), isFalse);

      session().commands.clear();
      radio.setVfo('vfoA', freq: 14200, mode: 'SSB');
      await pumpEventQueue();
      expect(session().commands, contains('mode:USB'));
    });

    test('60m is upper sideband despite being below 10 MHz', () async {
      await connectedRadio();
      radio.setVfo('vfoA', freq: 5357, mode: 'SSB');
      await pumpEventQueue();
      // Channelized USB by international agreement.
      expect(session().commands, contains('mode:USB'));
    });

    test('a configured but disconnected radio is written to when it connects, not before', () async {
      final node = await gato.addNode(typeKey: 'fake-type', config: {'host': 'a'});
      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(driver.sessions, isEmpty, reason: 'nothing to send to');

      // And the move made while it was disconnected is not replayed at it:
      // the radio reports where it actually is, and that is what wins.
      await gato.connect(node.uuid);
      await pumpEventQueue();
      expect(session().commands, isEmpty);
    });
  });

  group('regressions from the code review', () {
    test('a band pick does not deafen the app to the radio for good', () async {
      await connectedRadio();
      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(radio.vfoA.freq, 14074);

      // The operator picks a band by hand, which clears vfoA's frequency.
      // The radio has not moved, so everything it says from here on is a
      // restatement of 14074 — and deduping those against GATO's own cache
      // swallowed every one of them. The panel then showed 40m with no
      // frequency, and logged QSOs with it, until the knob was turned.
      radio.setVfo('vfoA', band: '40m');
      await pumpEventQueue();
      expect(radio.vfoA.freq, isNull);

      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(radio.vfoA.freq, 14074, reason: 'the radio gets the app back in step');
      expect(radio.vfoA.band, '20m');
    });

    test('clearing the frequency field does not deafen it either', () async {
      await connectedRadio();
      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();

      // What the logging panel sends when the frequency field is emptied.
      radio.setVfo('vfoA', clearFreq: true, mode: 'USB');
      await pumpEventQueue();
      expect(radio.vfoA.freq, isNull);

      session().radioReports(freqKHz: 14074);
      await pumpEventQueue();
      expect(radio.vfoA.freq, 14074);
    });

    test('a picked band decides the sideband when there is no frequency', () async {
      await connectedRadio();
      // 40m by hand, then SSB. With no frequency to derive a band from,
      // resolveSideband used to fall straight through to USB — on a band
      // where the app's own documented rule says LSB.
      radio.setVfo('vfoA', band: '40m');
      await pumpEventQueue();
      session().commands.clear();

      radio.setVfo('vfoA', mode: 'SSB');
      await pumpEventQueue();
      expect(session().commands, ['mode:LSB']);
    });

    test('handing radio1 away and back does not carry a stale echo guard', () async {
      final a = await connectedRadio();
      final b = await gato.addNode(typeKey: 'fake-type', config: {'host': 'b'});
      await gato.connect(b.uuid);
      final sessionB = driver.sessions.last;

      // B drives the panel and is tuned to 14074 — recorded as sent to it.
      await gato.setRadio1(b.uuid);
      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(sessionB.commands, contains('freq:14074.0'));

      // The operator switches to A and works there. Nothing reaches B now,
      // and nothing B does is heard — including the operator retuning it at
      // its own front panel, which is the point.
      await gato.setRadio1(a.uuid);
      radio.setVfo('vfoA', freq: 21000, mode: 'CW');
      await pumpEventQueue();

      // Back to B. What it was last SENT no longer says anything about
      // where it is, so a guard left over from its previous turn as radio1
      // suppresses this tune — permanently, since it never expires.
      await gato.setRadio1(b.uuid);
      sessionB.commands.clear();
      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(sessionB.commands, contains('freq:14074.0'));
    });

    test('a connection that drops on its own still tears the session down', () async {
      final node = await connectedRadio();
      final torn = session();
      expect(torn.tornDown, isFalse);

      // The radio is switched off, or the WiFi drops: the connection closes
      // without anyone asking it to. Dropping the session without tearing
      // it down leaves the driver's own poll/resync timers running for the
      // life of the process — one set per drop — each holding its sink and
      // the dead connection.
      await transport.connections.single.close();
      await pumpEventQueue();

      expect(torn.tornDown, isTrue);
      expect(gato.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    });

    test('a reconnect does not inherit the previous session echo guard', () async {
      final node = await connectedRadio();
      // Both sides agree on 14074, so that is what the old session knows.
      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();

      // The radio goes away — powered off, or the network dropped — and the
      // operator carries on working the app.
      await gato.disconnect(node.uuid);
      radio.setVfo('vfoA', freq: 7100, mode: 'CW');
      await pumpEventQueue();

      await gato.connect(node.uuid);
      final fresh = driver.sessions.last;
      expect(fresh, isNot(same(driver.sessions.first)));

      // Back to where the OLD session had been. The new session has been
      // told nothing, so this must actually be sent — carrying the guard
      // across a reconnect suppresses it, leaving the radio wherever it
      // really is while the app insists it is on 14074.
      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(fresh.commands, contains('freq:14074.0'));
    });

    test('a tune command that throws is retried, not remembered as sent', () async {
      await connectedRadio();
      // A PARTIAL delivery, which is the case that discriminates: the
      // frequency lands and the mode does not. An earlier version of this
      // test failed both commands and then moved to 7100/CW in between —
      // which reset the echo guard whether or not the fix was present, so
      // it passed with the fix reverted.
      session().throwOnSetMode = true;

      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(session().commands, ['freq:14074.0'], reason: 'the mode threw after the frequency went out');

      session().throwOnSetMode = false;
      session().commands.clear();

      // Only the mode moves. Nothing was recorded as sent, so the frequency
      // has to go out again alongside it — recording the throw as delivered
      // would send the mode alone, leaving the radio somewhere the app is
      // no longer checking.
      radio.setVfo('vfoA', mode: 'CW');
      await pumpEventQueue();
      expect(session().commands, ['freq:14074.0', 'mode:CW']);
    });

    test('disposing mid-reconnect does not notify a dead notifier', () async {
      final gated = _GatedTransport();
      final service = GatoService(
        SettingsService(await SharedPreferences.getInstance()),
        radio: radio,
        registry: EquipmentRegistry(types: [_FakeType(driver)], transports: {'fake': gated}),
        // Otherwise every one of these tests sleeps through the real 3s
        // gap between retries, for real, three times over.
        reconnectDelay: Duration.zero,
      );
      await service.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'});

      final reconnecting = service.reconnectDesignatedRadio();
      await pumpEventQueue();
      gated.refuse(0); // first attempt fails; the loop parks on its delay
      await pumpEventQueue();

      // The delay can't be cancelled, so the loop outlives the service.
      service.dispose();

      // Must complete quietly rather than throwing "A ChangeNotifier was
      // used after being disposed" out of the retry.
      await expectLater(reconnecting, completes);
    });
  });

  group('the two directions do not fight', () {
    test('the radio reporting does not bounce straight back at it', () async {
      await connectedRadio();

      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();

      // GATO wrote what the radio said, heard its own write back through
      // RadioService, and must recognise it. Forwarding would tell the
      // radio to go exactly where it already is — and its confirmation
      // would come back around again.
      expect(session().commands, isEmpty);
      expect(radio.vfoA.freq, 14074);
    });

    test('a tune command and the radio confirming it settle immediately', () async {
      await connectedRadio();

      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(session().commands, ['freq:14074.0', 'mode:USB']);

      // The radio does as it's told and says so, as a real one would.
      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();

      expect(session().commands, ['freq:14074.0', 'mode:USB'], reason: 'the confirmation is not a new command');
      expect(radio.vfoA.freq, 14074);
    });

    test('restating the same VFO sends nothing', () async {
      await connectedRadio();
      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();
      session().commands.clear();

      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();

      expect(session().commands, isEmpty);
    });

    test('a mode-only change does not re-send the frequency', () async {
      await connectedRadio();
      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();
      session().commands.clear();

      radio.setVfo('vfoA', mode: 'CW');
      await pumpEventQueue();

      expect(session().commands, ['mode:CW']);
    });
  });

  group('reconnect on launch', () {
    test('reconnects the designated radio', () async {
      final node = await gato.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'});
      expect(gato.stateFor(node.uuid).status, EquipmentStatus.disconnected);

      await gato.reconnectDesignatedRadio();
      expect(gato.stateFor(node.uuid).status, EquipmentStatus.connected);
    });

    test('does nothing when there is no equipment', () async {
      await gato.reconnectDesignatedRadio();
      expect(driver.sessions, isEmpty);
    });

    test('leaves an already-connected radio alone', () async {
      final node = await connectedRadio();
      expect(driver.sessions, hasLength(1));

      await gato.reconnectDesignatedRadio();
      // A second connect would tear down a perfectly good session and open
      // another socket at the radio.
      expect(driver.sessions, hasLength(1));
      expect(gato.stateFor(node.uuid).status, EquipmentStatus.connected);
    });

    test('a manual Connect while a retry is in flight wins, and the retry stands down', () async {
      final gated = _GatedTransport();
      final service = GatoService(
        SettingsService(await SharedPreferences.getInstance()),
        radio: radio,
        registry: EquipmentRegistry(types: [_FakeType(driver)], transports: {'fake': gated}),
        // Otherwise every one of these tests sleeps through the real 3s
        // gap between retries, for real, three times over.
        reconnectDelay: Duration.zero,
      );
      addTearDown(service.dispose);
      final node = await service.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'});

      // Launch's attempt is in flight — the radio is slow to answer.
      final reconnecting = service.reconnectDesignatedRadio();
      await pumpEventQueue();
      expect(gated.pending, hasLength(1));

      // The operator gets impatient and hits Connect.
      final manual = service.connect(node.uuid);
      await pumpEventQueue();

      // The launch attempt is told to stop rather than left to run out its
      // handshake at the radio — some rigs refuse two overlapping sessions.
      expect(gated.cancels.first.isCancelled, isTrue);
      expect(gated.pending, hasLength(2));

      gated.land(1);
      await manual;
      await reconnecting;

      expect(service.stateFor(node.uuid).status, EquipmentStatus.connected);
      // And the retry loop is done — it must not come back and supersede
      // the connection the operator just made. This is exactly the fight
      // app-polo's auto-reconnect had with its own user.
      expect(gated.pending, hasLength(2), reason: 'no third attempt');
    });

    test('a Connect that lands between retries stops the loop', () async {
      final gated = _GatedTransport();
      final service = GatoService(
        SettingsService(await SharedPreferences.getInstance()),
        radio: radio,
        registry: EquipmentRegistry(types: [_FakeType(driver)], transports: {'fake': gated}),
        // Short, but not zero: this test needs the gap between retries to
        // exist at all — that gap is what the Connect lands in.
        reconnectDelay: const Duration(milliseconds: 500),
      );
      addTearDown(service.dispose);
      final node = await service.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'});

      final reconnecting = service.reconnectDesignatedRadio();
      await pumpEventQueue();
      gated.refuse(0); // first attempt fails, loop starts waiting
      await pumpEventQueue();

      // The operator connects during the gap between retries.
      final manual = service.connect(node.uuid);
      await pumpEventQueue();
      gated.land(1);
      await manual;
      expect(service.stateFor(node.uuid).status, EquipmentStatus.connected);

      await reconnecting;
      expect(gated.pending, hasLength(2), reason: 'the retry saw the node was taken and stood down');
      expect(service.stateFor(node.uuid).status, EquipmentStatus.connected);
    });

    test('gives up after its retries rather than nagging forever', () async {
      final failing = GatoService(
        SettingsService(await SharedPreferences.getInstance()),
        radio: radio,
        registry: EquipmentRegistry(
          types: [_FakeType(driver)],
          transports: {'fake': _RefusingTransport()},
        ),
        reconnectDelay: Duration.zero,
      );
      addTearDown(failing.dispose);
      final node = await failing.addNode(typeKey: 'fake-type', config: {'host': 'nope'});

      await failing.reconnectDesignatedRadio();

      // The reason is left on the node so the panel can say why, rather
      // than sitting on "Not connected" with no explanation.
      expect(failing.stateFor(node.uuid).status, EquipmentStatus.error);
      expect(failing.stateFor(node.uuid).error, isNotNull);
    });
  });

  test('a burst of radio updates costs one prefs write, not one per step', () async {
    // Turning the knob on a push-model radio reports every step.
    final prefs = await SharedPreferences.getInstance();
    final debounced = RadioService(prefs, writeDelay: const Duration(milliseconds: 30));
    addTearDown(debounced.dispose);

    for (var step = 0; step < 50; step++) {
      debounced.setVfo('vfoA', freq: 14074 + step * 0.1, origin: VfoOrigin.radio);
    }
    await debounced.flushPendingWrites();

    expect(RadioService(prefs).vfoA.freq, closeTo(14078.9, 0.001));
  });
}

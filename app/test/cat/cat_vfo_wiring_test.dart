// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CAT driving the app's VFO, and being driven by it.
//
// The whole point of this layer is that the two directions don't fight.
// An app→radio tune produces a confirmation from the radio; a radio→app
// update lands in the same store the app writes to. Without an origin tag
// and an echo guard those two chase each other, so most of what's asserted
// here is that nothing bounces.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_clock.dart';
import '../support/fake_secure_storage.dart';

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
class _GatedTransport extends EquipmentTransport {
  final pending = <Completer<EquipmentConnection>>[];
  final cancels = <CatCancelToken>[];

  @override
  String get key => 'fake';

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) {
    final completer = Completer<EquipmentConnection>();
    pending.add(completer);
    cancels.add(cancel);
    unawaited(
      cancel.whenCancelled.then((_) {
        if (!completer.isCompleted) completer.completeError(const CatCancelledException());
      }),
    );
    return completer.future;
  }

  void land(int index) => pending[index].complete(_FakeConnection());
  void refuse(int index) => pending[index].completeError(const SocketException('refused'));
}

/// A radio that is switched off.
class _RefusingTransport extends EquipmentTransport {
  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => throw const SocketException('Connection refused');
}

class _FakeTransport extends EquipmentTransport {
  /// Kept so a test can close one from the outside, the way a radio being
  /// switched off closes it.
  final connections = <_FakeConnection>[];

  @override
  String get key => 'fake';
  @override
  Set<String> get secretFields => const {'apiKey'};
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    final connection = _FakeConnection();
    connections.add(connection);
    return connection;
  }
}

/// Records what the manager asked the radio to do, and can push readings
/// back the way a real radio's status stream would.
class _FakeSession implements TransceiverSession, AntennaTunerSession {
  final EquipmentSink sink;
  final List<String> commands = [];
  var throwOnSet = false;

  /// Fails only `setMode`, so a partial delivery can be staged: on a
  /// cross-band tune the first frequency reaches the radio and nothing after
  /// it does.
  var throwOnSetMode = false;

  _FakeSession(this.sink);

  void radioReports({double? freqKHz, String? mode}) => sink.report(VfoReading(freqKHz: freqKHz, mode: mode));

  /// An acknowledgement with nothing in it — a FlexRadio's `R` line to a ping.
  void radioAnswers() => sink.reportAlive();

  void tunerReports(TunerStatus status) {
    if (sink case final TunerSink tuners) tuners.reportTuner(status);
  }

  @override
  void setTuner({required bool inline}) => commands.add('tuner:$inline');
  @override
  bool get canStartTune => true;
  @override
  void startTune() => commands.add('tune');
  @override
  void stopTune() => commands.add('stop-tune');

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

  @override
  void setPower(num watts) => commands.add('power:$watts');

  /// Pushes, like the FlexRadio this fake stands in for — so nothing
  /// here has to reason about a poll cadence.
  @override
  Duration? get expectedUpdateInterval => null;

  var tornDown = false;

  @override
  void teardown() => tornDown = true;
}

class _FakeDriver extends EquipmentDriver {
  final sessions = <_FakeSession>[];

  @override
  String get key => 'fake-driver';
  @override
  String get name => 'Fake Radio';

  /// What the manager actually handed the driver — not what the user typed.
  final configs = <Map<String, dynamic>>[];

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    configs.add(config);
    final session = _FakeSession(sink);
    sessions.add(session);
    return session;
  }
}

EquipmentModel _fakeModel(EquipmentDriver driver, EquipmentTransport transport) => EquipmentModel(
  key: 'fake',
  category: kCategoryTransceiver,
  name: () => 'Fake Radio',
  variants: [
    EquipmentVariant(
      key: 'fake-type',
      driver: driver,
      transport: transport,
      // Exercises the same "the pairing hands the driver something the
      // user never typed" path the IC-705's network variant uses for its
      // controller address — here just a marker the test can look for.
      overrides: const {'injectedByType': 'yes'},
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RadioService radio;
  late SettingsService settings;
  late _FakeDriver driver;
  late _FakeTransport transport;
  late CatService cat;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    radio = RadioService(prefs, writeDelay: Duration.zero);
    driver = _FakeDriver();
    transport = _FakeTransport();
    settings = SettingsService(prefs, secureStorage: FakeSecureStorage());
    cat = CatService(
      settings,
      radio: radio,
      registry: EquipmentRegistry(models: [_fakeModel(driver, transport)], transports: {'fake': transport}),
    );
  });

  tearDown(() {
    cat.dispose();
    radio.dispose();
  });

  Future<EquipmentNode> connectedRadio() async {
    final node = await cat.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'});
    await cat.connect(node.uuid);
    return node;
  }

  // A getter can't be declared inside a function body; this is the same thing.
  _FakeSession session() => driver.sessions.single;

  group('radio1', () {
    test('the first transceiver added drives the logging panel', () async {
      final node = await cat.addNode(typeKey: 'fake-type', config: {'host': 'a'});
      expect(cat.radio1, LocalRadio(node.uuid));
      expect(cat.isRadio1(node.uuid), isTrue);
    });

    test('the newest transceiver takes the job, and it can be handed back', () async {
      // This used to assert the OPPOSITE — "a second radio does not take
      // over" — because radio1 was derived by designating the first
      // transceiver found and never revisiting it. HALO-50 replaced that with
      // plain stored state: adding a rig is an action, and the rig you just
      // set up is the one you almost certainly want to drive the panel.
      final first = await cat.addNode(typeKey: 'fake-type', config: {'host': 'a'});
      expect(cat.radio1, LocalRadio(first.uuid));

      final second = await cat.addNode(typeKey: 'fake-type', config: {'host': 'b'});
      expect(cat.radio1, LocalRadio(second.uuid), reason: 'newest wins');

      // And the operator still has the final say.
      await cat.setRadio1(LocalRadio(first.uuid));
      expect(cat.radio1, LocalRadio(first.uuid));
    });

    test('removing the designated radio clears it instead of promoting another', () async {
      // Reversed deliberately in HALO-50. This used to promote a survivor, on
      // the grounds that the logging panel should never be left with nothing
      // driving it. The counter-argument won: silently moving the panel onto a
      // DIFFERENT radio immediately after a destructive action is the same
      // class of surprise as the bug that card reports, and the operator can
      // see None in the dropdown and pick.
      final first = await cat.addNode(typeKey: 'fake-type', config: {'host': 'a'});
      final second = await cat.addNode(typeKey: 'fake-type', config: {'host': 'b'});
      expect(cat.radio1, LocalRadio(second.uuid), reason: 'newest added');

      await cat.removeNode(second.uuid);
      expect(cat.radio1, isNull, reason: 'the survivor must not be promoted silently');

      // Removing a node that is NOT designated leaves the choice untouched.
      await cat.setRadio1(LocalRadio(first.uuid));
      final third = await cat.addNode(typeKey: 'fake-type', config: {'host': 'c'});
      await cat.setRadio1(LocalRadio(first.uuid));
      await cat.removeNode(third.uuid);
      expect(cat.radio1, LocalRadio(first.uuid));
    });

    test('the designation survives a restart', () async {
      await cat.addNode(typeKey: 'fake-type', config: {'host': 'a'});
      final second = await cat.addNode(typeKey: 'fake-type', config: {'host': 'b'});
      await cat.setRadio1(LocalRadio(second.uuid));

      final reloaded = CatService(SettingsService(await SharedPreferences.getInstance()));
      expect(reloaded.radio1, LocalRadio(second.uuid));
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
      final designated = await connectedRadio();
      final other = await cat.addNode(typeKey: 'fake-type', config: {'host': 'b'});
      // Adding it made IT radio1 (newest wins), so hand the job back before
      // asserting that a non-designated radio is ignored — otherwise this
      // tests the opposite of what it says.
      await cat.setRadio1(LocalRadio(designated.uuid));
      await cat.connect(other.uuid);

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

    test('a power change reaches the radio', () async {
      await connectedRadio();
      radio.setVfo('vfoA', power: 25);
      await pumpEventQueue();

      expect(session().commands, contains('power:25'));
    });

    test('a remembered power is not re-asserted by an unrelated VFO change', () async {
      // Every VFO notification reaches _onVfoChanged, so sending power on
      // each one would push a value nobody stated this session at the rig —
      // and on an IC-705 the app's remembered value may be a battery-DERATED
      // reading, which would then become the radio's actual power.
      radio.setVfo('vfoA', power: 5);
      await connectedRadio();

      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();

      expect(session().commands, contains('freq:14074.0'));
      expect(session().commands.any((c) => c.startsWith('power:')), isFalse);
    });

    test("a radio's own power report is not sent back to it", () async {
      await connectedRadio();
      session().sink.reportPower(5);
      await pumpEventQueue();

      expect(radio.vfoA.power, 5, reason: "the app follows the radio's reading");
      expect(session().commands.any((c) => c.startsWith('power:')), isFalse);

      // ...and it becomes the baseline: the operator asking for that same
      // power is not a change, while a different one still is.
      radio.setVfo('vfoA', power: 100);
      await pumpEventQueue();
      expect(session().commands, contains('power:100'));
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

    test('the MF/LF bands below 160m are lower sideband', () async {
      await connectedRadio();
      radio.setVfo('vfoA', freq: 475, mode: 'SSB');
      await pumpEventQueue();
      expect(session().commands, contains('mode:LSB'));

      // Detour through a USB band: mode commands only go out on change, so
      // jumping straight from 630m to 2190m would send nothing.
      radio.setVfo('vfoA', freq: 14200, mode: 'SSB');
      await pumpEventQueue();

      session().commands.clear();
      radio.setVfo('vfoA', freq: 136, mode: 'SSB');
      await pumpEventQueue();
      expect(session().commands, contains('mode:LSB'));
    });

    test('a configured but disconnected radio is written to when it connects, not before', () async {
      final node = await cat.addNode(typeKey: 'fake-type', config: {'host': 'a'});
      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(driver.sessions, isEmpty, reason: 'nothing to send to');

      // And the move made while it was disconnected is not replayed at it:
      // the radio reports where it actually is, and that is what wins.
      await cat.connect(node.uuid);
      await pumpEventQueue();
      expect(session().commands, isEmpty);
    });
  });

  group('regressions from the code review', () {
    test('a connection that never says anything at all is caught too', () {
      // THE case that was reported: connect succeeds, the row goes green,
      // and no CI-V ever arrives — so there is no first reading to start
      // watching from. Arming only when a reading lands would miss exactly
      // the connection that never produces one.
      fakeAsync((async) {
        late EquipmentNode node;
        cat.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'}).then((n) => node = n);
        async.flushMicrotasks();
        cat.connect(node.uuid);
        async.flushMicrotasks();
        expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

        async.elapse(const Duration(seconds: 31));
        expect(cat.stateFor(node.uuid).stale, isTrue, reason: 'green with nothing behind it is the failure, not the success');
      });
    });

    test('a connection that goes silent stops presenting its last reading as current', () {
      // Observed on an IC-705 reconnect: full handshake, stream request
      // accepted, and then no CI-V at all — while the row showed a
      // confident green and a frequency from minutes earlier. Liveness that
      // counts datagrams cannot see this; the session's keepalives were
      // flowing the whole time. Only the readings can.
      fakeAsync((async) {
        late EquipmentNode node;
        cat.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'}).then((n) => node = n);
        async.flushMicrotasks();
        cat.connect(node.uuid);
        async.flushMicrotasks();

        session().radioReports(freqKHz: 14074, mode: 'USB');
        async.flushMicrotasks();
        expect(cat.stateFor(node.uuid).stale, isFalse);

        // Still connected, still keepalive-healthy, saying nothing.
        async.elapse(const Duration(seconds: 31));
        expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected, reason: 'silent is not the same as disconnected');
        expect(cat.stateFor(node.uuid).stale, isTrue);

        // And one word from the radio clears it — including a repeat, since
        // a radio answering "still 14074" is a radio that is answering.
        session().radioReports(freqKHz: 14074, mode: 'USB');
        async.flushMicrotasks();
        expect(cat.stateFor(node.uuid).stale, isFalse);
      });
    });

    test('an acknowledgement that carries no reading is still a word from the radio', () {
      // A FlexRadio pushes a slice status only when something changes, so a
      // still dial is total silence; its driver pings inside the window and
      // the reply says nothing about the VFO. If the sink dropped that on the
      // floor, the ping would prove the socket alive to the driver and to
      // nobody else, and the row would go red on schedule regardless.
      fakeAsync((async) {
        late EquipmentNode node;
        cat.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'}).then((n) => node = n);
        async.flushMicrotasks();
        cat.connect(node.uuid);
        async.flushMicrotasks();
        session().radioReports(freqKHz: 14074, mode: 'USB');
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 31));
        expect(cat.stateFor(node.uuid).stale, isTrue);

        session().radioAnswers();
        async.flushMicrotasks();
        expect(cat.stateFor(node.uuid).stale, isFalse);
        expect(cat.stateFor(node.uuid).vfo.freqKHz, 14074, reason: 'life is not a reading; the VFO must be exactly what the radio last said');

        // And it re-arms the watch rather than merely clearing the mark.
        async.elapse(const Duration(seconds: 31));
        expect(cat.stateFor(node.uuid).stale, isTrue);
      });
    });

    test('a disconnect says so while it is happening, not only once it is done', () async {
      // Saying goodbye takes real time on some transports — the Icom
      // network teardown is most of a second of deliberately spaced
      // datagrams. A row that still claims to be connected throughout, then
      // blinks, reads as a hang.
      final node = await connectedRadio();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

      final statuses = <EquipmentStatus>[];
      cat.addListener(() => statuses.add(cat.stateFor(node.uuid).status));

      await cat.disconnect(node.uuid);

      expect(statuses, contains(EquipmentStatus.disconnecting));
      expect(statuses.last, EquipmentStatus.disconnected);
      expect(statuses.indexOf(EquipmentStatus.disconnecting), lessThan(statuses.lastIndexOf(EquipmentStatus.disconnected)), reason: 'and in that order');
    });

    test('the driver is handed the config the TYPE supplies, not the raw one', () async {
      // A type may know something about its protocol that is no user's
      // setting — the IC-705's 0xE1 network controller address is one, and
      // getting it wrong is SILENT. The manager must route through
      // driverConfig rather than passing the stored config straight down.
      final node = await cat.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'});
      await cat.connect(node.uuid);

      expect(driver.configs.single['injectedByType'], 'yes');
      expect(driver.configs.single['host'], 'radio.local', reason: 'and the real config survives');
    });

    test('secret fields come from the type, not from the manager naming one', () async {
      // A manager that asked "is this the IC-705 type?" would write THIS
      // type's secret into the plain prefs blob, silently — which is the
      // whole failure mode, and no IC-705 test can catch it.
      final node = await cat.addNode(typeKey: 'fake-type', config: {'host': 'radio.local', 'apiKey': 'super-secret'});

      expect(cat.nodes.single.config.containsKey('apiKey'), isFalse);
      expect(settings.stationEquipment.toString(), isNot(contains('super-secret')));
      expect(await settings.equipmentSecret(node.uuid, 'apiKey'), 'super-secret');
    });

    test('a band pick does not deafen the app to the radio for good', () async {
      await connectedRadio();
      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(radio.vfoA.freq, 14074);

      // The operator picks a band by hand, which clears vfoA's frequency.
      // The radio has not moved, so everything it says from here on is a
      // restatement of 14074 — and deduping those against CAT's own cache
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
      final b = await cat.addNode(typeKey: 'fake-type', config: {'host': 'b'});
      await cat.connect(b.uuid);
      final sessionB = driver.sessions.last;

      // B drives the panel and is tuned to 14074 — recorded as sent to it.
      await cat.setRadio1(LocalRadio(b.uuid));
      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(sessionB.commands, contains('freq:14074.0'));

      // The operator switches to A and works there. Nothing reaches B now,
      // and nothing B does is heard — including the operator retuning it at
      // its own front panel, which is the point.
      await cat.setRadio1(LocalRadio(a.uuid));
      radio.setVfo('vfoA', freq: 21000, mode: 'CW');
      await pumpEventQueue();

      // Back to B. What it was last SENT no longer says anything about
      // where it is, so a guard left over from its previous turn as radio1
      // suppresses this tune — permanently, since it never expires.
      await cat.setRadio1(LocalRadio(b.uuid));
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
      // NOT `disconnected` any more, and that is the point of the change: this
      // node is radio1, so an unexpected drop now starts one reconnect burst.
      // What this test protects is the TEARDOWN above — the driver's timers
      // must stop either way, or every drop leaks another set of them holding
      // a dead connection. Reconnecting on top of a session that was never
      // torn down would be strictly worse than not reconnecting at all.
      // The specific status, not `isNot(disconnected)`: that was satisfied by
      // `error` and by a permanently stuck `connecting` too, so it stayed green
      // in precisely the cases where radio1 ends up abandoned anyway. This
      // transport lands the reconnect, so the burst has actually brought the
      // radio back by here — which is the outcome worth pinning.
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected, reason: 'radio1 must not be left abandoned after a drop');
    });

    test('a reconnect does not inherit the previous session echo guard', () async {
      final node = await connectedRadio();
      // Both sides agree on 14074, so that is what the old session knows.
      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();

      // The radio goes away — powered off, or the network dropped — and the
      // operator carries on working the app.
      await cat.disconnect(node.uuid);
      radio.setVfo('vfoA', freq: 7100, mode: 'CW');
      await pumpEventQueue();

      await cat.connect(node.uuid);
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
      expect(session().commands, ['freq:14074.0', 'mode:CW', 'freq:14074.0']);
    });

    test('disposing mid-reconnect does not notify a dead notifier', () async {
      final gated = _GatedTransport();
      final service = CatService(
        SettingsService(await SharedPreferences.getInstance()),
        radio: radio,
        registry: EquipmentRegistry(models: [_fakeModel(driver, gated)], transports: {'fake': gated}),
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

      // CAT wrote what the radio said, heard its own write back through
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
      // Nothing was sent before, so the rig's band is unknown and the
      // cross-band sequence applies.
      expect(session().commands, ['freq:14074.0', 'mode:USB', 'freq:14074.0']);

      // The radio does as it's told and says so, as a real one would.
      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();

      expect(session().commands, ['freq:14074.0', 'mode:USB', 'freq:14074.0'], reason: 'the confirmation is not a new command');
      expect(radio.vfoA.freq, 14074);
    });

    test('crossing a band re-states the mode and re-asserts the frequency', () async {
      await connectedRadio();
      // A concrete sideband, the way a rig actually reports one — and the
      // same one the tune below resolves to, so `modeChanged` is FALSE and
      // the restatement is the only thing that can put a mode on the wire.
      session().radioReports(freqKHz: 7290, mode: 'USB');
      await pumpEventQueue();
      session().commands.clear();

      // A rig that recalls 20m as CW would land there and the app would
      // follow it, so the mode is stated on the new band even though nothing
      // about it changed, and the frequency restated in case setting the
      // mode moved it.
      radio.setVfo('vfoA', freq: 14074, mode: 'SSB');
      await pumpEventQueue();
      expect(session().commands, ['freq:14074.0', 'mode:USB', 'freq:14074.0']);
    });

    test('moving within a band leads with the mode and tunes once', () async {
      await connectedRadio();
      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();
      session().commands.clear();

      // No band boundary crossed, so nothing recalls anything: the mode
      // leads so the frequency lands in it, and goes out once.
      radio.setVfo('vfoA', freq: 14030, mode: 'CW');
      await pumpEventQueue();
      expect(session().commands, ['mode:CW', 'freq:14030.0']);
    });

    test('a mode echo arriving before the frequency does not bounce the panel back', () async {
      await connectedRadio();
      // Where the rig already is. The tune below crosses bands, so a
      // reverted frequency is a reverted BAND — the visible failure.
      session().radioReports(freqKHz: 7100, mode: 'CW');
      await pumpEventQueue();

      radio.setVfo('vfoA', freq: 14074, mode: 'USB');
      await pumpEventQueue();

      // The rig answers the mode with no frequency in it, the way every
      // driver reports a mode change, and can do so before it has confirmed
      // the frequency. Completing that from what the rig last SAID would
      // answer with 7100.
      session().radioReports(mode: 'USB');
      await pumpEventQueue();

      expect(radio.vfoA.freq, 14074, reason: 'the frequency just commanded, not the one being left');
      expect(radio.vfoA.mode, 'USB');
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

    // No radio has an FT8 mode. Handed `FT8`, a driver sends nothing, and a
    // cross-band tune leaves the rig in whatever its band recall brought back.
    test('a digital mode reaches the driver as the radio names it', () async {
      await connectedRadio();
      session().radioReports(freqKHz: 7074, mode: 'LSB');
      await pumpEventQueue();
      session().commands.clear();

      radio.setVfo('vfoA', freq: 14074, mode: 'FT8');
      await pumpEventQueue();
      expect(session().commands, ['freq:14074.0', 'mode:DATA-USB', 'freq:14074.0']);
    });

    // The radio's report of the mode the app put it in is not the operator
    // changing mode: taking DATA-USB in its place loses FT8 from the log.
    test('the radio confirming DATA-USB leaves FT8 in the VFO', () async {
      await connectedRadio();
      radio.setVfo('vfoA', freq: 14074, mode: 'FT8');
      await pumpEventQueue();

      session().radioReports(freqKHz: 14074, mode: 'DATA-USB');
      await pumpEventQueue();
      expect(radio.vfoA.mode, 'FT8');

      // Nor does it go back out as a new command.
      session().commands.clear();
      session().radioReports(freqKHz: 14074.5, mode: 'DATA-USB');
      await pumpEventQueue();
      expect(radio.vfoA.mode, 'FT8');
      expect(session().commands, isEmpty);
    });

    // Anything else is the operator changing the rig, and the app follows —
    // including plain USB on a rig that has a DATA submode.
    test('the radio reporting another mode still replaces FT8', () async {
      await connectedRadio();
      radio.setVfo('vfoA', freq: 14074, mode: 'FT8');
      await pumpEventQueue();

      session().radioReports(freqKHz: 14074, mode: 'USB');
      await pumpEventQueue();
      expect(radio.vfoA.mode, 'USB');
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
      final node = await cat.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'});
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);

      await cat.reconnectDesignatedRadio();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
    });

    test('does nothing when there is no equipment', () async {
      await cat.reconnectDesignatedRadio();
      expect(driver.sessions, isEmpty);
    });

    test('leaves an already-connected radio alone', () async {
      final node = await connectedRadio();
      expect(driver.sessions, hasLength(1));

      await cat.reconnectDesignatedRadio();
      // A second connect would tear down a perfectly good session and open
      // another socket at the radio.
      expect(driver.sessions, hasLength(1));
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
    });

    test('a manual Connect while a retry is in flight wins, and the retry stands down', () async {
      final gated = _GatedTransport();
      final service = CatService(
        SettingsService(await SharedPreferences.getInstance()),
        radio: radio,
        registry: EquipmentRegistry(models: [_fakeModel(driver, gated)], transports: {'fake': gated}),
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
      final service = CatService(
        SettingsService(await SharedPreferences.getInstance()),
        radio: radio,
        registry: EquipmentRegistry(models: [_fakeModel(driver, gated)], transports: {'fake': gated}),
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
      final failing = CatService(
        SettingsService(await SharedPreferences.getInstance()),
        radio: radio,
        registry: EquipmentRegistry(models: [_fakeModel(driver, _RefusingTransport())], transports: {'fake': _RefusingTransport()}),
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

    test('a radio that is switched off never reaches the loud path', () async {
      // The wiring half of ErrorPolicy's cat-equipment-unreachable rule,
      // which error_policy_test.dart can only exercise on a hand-built
      // CatConnectFailure. What is proven here is that the wrapper is
      // actually PUT ON at the catch site: unwrapped, a bare SocketException
      // matches no rule, takes the default tier, and every retry against a
      // rig left switched off is a crash upload and a "Something went wrong"
      // notice — the bug this test exists to keep fixed.
      final failing = CatService(
        SettingsService(await SharedPreferences.getInstance()),
        radio: radio,
        registry: EquipmentRegistry(models: [_fakeModel(driver, _RefusingTransport())], transports: {'fake': _RefusingTransport()}),
        reconnectDelay: Duration.zero,
      );
      addTearDown(failing.dispose);
      final node = await failing.addNode(typeKey: 'fake-type', config: {'host': 'nope'});

      final lines = <String>[];
      final previousPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => lines.add(message ?? '');
      try {
        await failing.connect(node.uuid);
      } finally {
        debugPrint = previousPrint;
      }

      expect(
        lines.where((line) => line.contains('[error-policy] cat-equipment-unreachable')),
        isNotEmpty,
        reason: 'the policy has to claim it, or the report goes to the backend and the operator',
      );
    });
  });

  group('a tune the app starts', () {
    test('a second press before the first shows as a tune is the same press', () async {
      // The radio reports the tune a poll or two later; a start sent into it
      // in the meantime cancels or restarts it on the air.
      final node = await connectedRadio();
      cat.startNodeTune(node.uuid);
      cat.startNodeTune(node.uuid);
      expect(session().commands.where((c) => c == 'tune'), hasLength(1));
    });

    test('Escape ends it, once, and is claimed for it', () async {
      final node = await connectedRadio();
      cat.startNodeTune(node.uuid);
      session().tunerReports(TunerStatus.tuning);
      expect(cat.stopKeying(), isTrue, reason: 'claimed, so the same Escape does not also end a QSO edit');
      expect(session().commands, contains('stop-tune'));
      session().commands.clear();
      expect(cat.stopKeying(), isFalse);
      expect(session().commands, isEmpty);
    });

    test('Escape leaves alone a tune started at the radio', () async {
      await connectedRadio();
      session().tunerReports(TunerStatus.tuning);
      expect(cat.stopKeying(), isFalse);
      expect(session().commands, isNot(contains('stop-tune')));
    });

    test('Escape ends a tune too new to show yet, but not one that has finished', () {
      runOnFakeClock((async) async {
        final node = await connectedRadio();
        cat.startNodeTune(node.uuid);
        expect(cat.stopKeying(), isTrue, reason: 'the radio has not reported the tune yet, but it is coming');
        expect(session().commands, contains('stop-tune'));

        await Future<void>.delayed(const Duration(seconds: 5));
        cat.startNodeTune(node.uuid);
        session().tunerReports(TunerStatus.tuning);
        session().tunerReports(TunerStatus.inline);
        await Future<void>.delayed(const Duration(seconds: 5));
        session().commands.clear();
        expect(cat.stopKeying(), isFalse, reason: 'over, so the Escape is the logging fields\' again');
        expect(session().commands, isEmpty);
      });
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

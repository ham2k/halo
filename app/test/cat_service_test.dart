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
import 'package:ham2k_logger/services/radio_service.dart';
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

class _FakeTransport extends EquipmentTransport {
  final attempts = <_Attempt>[];

  /// Distinct keys let one fake model carry two variants, which is what the
  /// re-typing tests need — a model's transports have to be distinguishable.
  final String transportKey;

  _FakeTransport({this.transportKey = 'fake'});

  /// Whether a cancelled attempt gives up. True mirrors the real
  /// transports; setting it false is how the "the transport ignored us and
  /// connected anyway" case gets exercised.
  var honorsCancellation = true;

  @override
  String get key => transportKey;

  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      [const {'type': 'field', 'fieldType': 'text', 'key': 'host', 'label': 'Host'}];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != 'host') return null;
    return (value as String? ?? '').isEmpty ? 'An address is required' : null;
  }

  @override
  String describeTarget(Map<String, dynamic> config) => '${config['host']}';

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

  /// Pushes, like the FlexRadio this fake stands in for — so nothing
  /// here has to reason about a poll cadence.
  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void teardown() {
    log.add('teardown');
    if (teardownThrows) throw StateError('teardown blew up');
  }
}

class _FakeDriver extends EquipmentDriver {
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

EquipmentModel _fakeModel(EquipmentDriver driver, EquipmentTransport transport) => EquipmentModel(
      key: 'fake',
      category: kCategoryTransceiver,
      name: () => 'Fake Radio',
      variants: [
        EquipmentVariant(
          key: 'fake-type',
          driver: driver,
          transport: transport,
          defaultConfig: const {'host': ''},
        ),
      ],
    );

// ----------------------------------------------------------------- setup

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late _FakeTransport transport;
  late _FakeDriver driver;
  late List<String> log;
  late CatService cat;
  late RadioService radio;

  Future<CatService> makeService() async {
    settings = SettingsService(await SharedPreferences.getInstance());
    log = [];
    transport = _FakeTransport();
    driver = _FakeDriver(log);
    radio = RadioService(await SharedPreferences.getInstance(), writeDelay: Duration.zero);
    addTearDown(radio.dispose);
    return CatService(
      settings,
      radio: radio,
      registry: EquipmentRegistry(
        models: [_fakeModel(driver, transport)],
        transports: {'fake': transport},
      ),
      reconnectDelay: Duration.zero,
      // Short, not zero: the backoff doubles it, and zero doubled is a tight
      // loop. Long enough that a test which does NOT want a retry can pump the
      // queue without tripping one.
      idleRetryFirst: const Duration(milliseconds: 20),
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

  // ------------------------------------------------------- idle retry

  group('the designated radio keeps being retried while it is off', () {
    // Verified as a real gap on hardware: power to an IC-705 was cut and
    // restored, and the app sat disconnected with the radio up and stable —
    // the drop burst had been spent while the radio was still booting, and
    // nothing else ever tried.
    /// Runs the clock while FAILING every attempt, which is what a radio that
    /// is switched off actually does. The fake transport leaves an attempt
    /// pending forever otherwise, so the node would sit in `connecting` and
    /// nothing would ever be learned about the retry.
    Future<void> pumpWithRadioOff() async {
      for (var i = 0; i < 40; i++) {
        for (final a in transport.attempts) {
          if (!a.completer.isCompleted) a.completer.completeError(StateError('radio is off'));
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await pumpEventQueue();
      }
    }

    test('a radio that is off keeps being tried', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);
      connection.dropRemotely();
      await pumpEventQueue();
      final afterDrop = transport.attempts.length;

      // The drop burst fails (nothing lands these attempts), and the retry
      // has to pick it up from there.
      await pumpWithRadioOff();

      expect(transport.attempts.length, greaterThan(afterDrop),
          reason: 'nothing tried again once the drop burst was spent');
    });

    /// How long the next connect attempt actually takes to show up.
    ///
    /// MEASURED, not assumed. Two earlier versions of the tests below picked a
    /// fixed window out of arithmetic on the constants, and both times the real
    /// interval was nothing like the guess — one window was wide enough to
    /// catch the backed-off retry it was supposed to rule out, so the test
    /// passed with the feature removed.
    Future<Duration> timeToNextAttempt({Duration limit = const Duration(seconds: 5)}) async {
      final start = DateTime.now();
      final seen = transport.attempts.length;
      while (transport.attempts.length == seen && DateTime.now().difference(start) < limit) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await pumpEventQueue();
      }
      return DateTime.now().difference(start);
    }

    Future<void> failEveryPendingAttempt() async {
      for (final a in transport.attempts) {
        if (!a.completer.isCompleted) a.completer.completeError(StateError('radio is off'));
      }
      await pumpEventQueue();
    }

    /// Fails retries until the interval has doubled clear of its floor.
    ///
    /// More rounds than the doubling alone needs, because the first few are
    /// eaten by the drop burst's own attempts rather than by idle-retry ticks —
    /// with three rounds the interval reached only 45ms against a 20ms floor,
    /// and the ceiling test below flaked about one run in three on a margin
    /// that thin.
    Future<void> backOffUntilLong() async {
      for (var round = 0; round < 6; round++) {
        await failEveryPendingAttempt();
        await timeToNextAttempt();
      }
    }

    test('working the VFO of an absent radio pulls the retry off its ceiling', () async {
      // The operator is in the app, tuning, and the radio is not there. Without
      // this they wait out whatever the backoff has grown to — on real
      // constants, up to eight minutes with nothing visibly trying.
      final node = await addRadio();
      final connection = await connectAndLand(node);
      connection.dropRemotely();
      await pumpEventQueue();
      await backOffUntilLong();

      // Time one full backed-off wait, so the assertion below is against what
      // this machine actually did rather than against the constants.
      await failEveryPendingAttempt();
      final backedOff = await timeToNextAttempt();

      // Arm the next wait — longer still, since that attempt just failed.
      await failEveryPendingAttempt();
      // The operator types a frequency.
      radio.setVfo('vfoA', freq: 14074.0, mode: 'USB', origin: VfoOrigin.user);
      await pumpEventQueue();
      final afterTuning = await timeToNextAttempt();

      expect(afterTuning * 2, lessThan(backedOff),
          reason: 'tuning an absent radio left the operator waiting out the backoff '
              '(${afterTuning.inMilliseconds}ms vs ${backedOff.inMilliseconds}ms)');
    });

    test('tuning continuously does not starve the retry it just shortened', () async {
      // The failure mode of the shortcut above: re-arming the timer on every
      // keystroke means a fast operator resets the wait before it ever expires
      // and the radio is never dialled at all. Working a pileup with the rig
      // off is exactly when someone types that fast.
      final node = await addRadio();
      final connection = await connectAndLand(node);
      connection.dropRemotely();
      await pumpEventQueue();
      await backOffUntilLong();
      await failEveryPendingAttempt();
      final seen = transport.attempts.length;

      // Tune far faster than the floor interval, for well over it.
      for (var i = 0; i < 40; i++) {
        radio.setVfo('vfoA', freq: 14074.0 + i, mode: 'USB', origin: VfoOrigin.user);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await pumpEventQueue();
      }

      expect(transport.attempts.length, greaterThan(seen),
          reason: 'continuous tuning pushed the retry out for ever; the radio was never tried');
    });

    test('a startup burst that finds the radio off hands over to the loop', () async {
      // main.dart calls reconnectDesignatedRadio() at boot (gated on the CAT
      // experiment). The operator switches the rig on AFTER the app far more
      // often than before it, so this is the likeliest path of all to need the
      // slow retry — and it was the one path that never started it: the loop
      // was only ever armed by a drop, and at boot nothing has dropped.
      await addRadio();

      final burst = cat.reconnectDesignatedRadio();
      for (var i = 0; i < 10; i++) {
        for (final a in transport.attempts) {
          if (!a.completer.isCompleted) a.completer.completeError(StateError('radio is off'));
        }
        await pumpEventQueue();
      }
      await burst;
      final afterBurst = transport.attempts.length;
      expect(afterBurst, greaterThan(1), reason: 'the boot burst itself never ran');

      await pumpWithRadioOff();

      expect(transport.attempts.length, greaterThan(afterBurst),
          reason: 'the app started with the radio off and then gave up for the whole session');
    });

    test('connecting a DIFFERENT rig does not reset the designated radio\'s backoff', () async {
      // The backoff belongs to radio1's loop. Connecting a second rig is an
      // unrelated action, and letting it drag the wait back to the floor puts
      // radio1 straight back into the eager-poking the backoff exists to stop.
      await addRadio(host: 'other.local'); // added first, so NOT radio1
      final other = cat.nodes.first;
      final designated = await addRadio(host: 'main.local'); // newest wins
      expect(cat.isRadio1(designated.uuid), isTrue);

      final connection = await connectAndLand(designated);
      connection.dropRemotely();
      await pumpEventQueue();
      await backOffUntilLong();

      // Time one backed-off wait for comparison.
      await failEveryPendingAttempt();
      final backedOff = await timeToNextAttempt();

      // Connect the OTHER rig, then let one more retry tick go by. The tick
      // matters: connect() only changes the stored interval, so a reset does
      // not show up until the next reschedule — measuring the wait already
      // armed would compare the old interval against itself and pass either
      // way, which is exactly how the first version of this test missed it.
      await failEveryPendingAttempt();
      await connectAndLand(other);
      await timeToNextAttempt();
      await failEveryPendingAttempt();
      final afterOther = await timeToNextAttempt();

      expect(afterOther * 2, greaterThan(backedOff),
          reason: 'connecting an unrelated rig collapsed radio1\'s backoff '
              '(${afterOther.inMilliseconds}ms vs ${backedOff.inMilliseconds}ms)');
    });

    test('tuning does not start connecting a radio nobody has switched on', () async {
      // Nothing has connected, dropped, or been disconnected here, so no retry
      // loop is running — and tuning must not be what starts one. This is the
      // case the `_idleRetryTimer != null` half of the guard exists for: a
      // connect attempt behind a keystroke, on a station whose rig has simply
      // never been switched on. (It is NOT what keeps a hand-disconnected radio
      // off — the loop's own userDisconnected check does that, a tick later.)
      await addRadio();
      final before = transport.attempts.length;

      radio.setVfo('vfoA', freq: 14074.0, mode: 'USB', origin: VfoOrigin.user);
      await pumpWithRadioOff();

      expect(transport.attempts.length, before,
          reason: 'typing a frequency started dialling a radio that was never connected');
    });

    test('tuning does NOT start a retry for a radio switched off by hand', () async {
      // The mirror of the above, and the reason it only ever shortens a loop
      // that is already running: Disconnect has to stay disconnected even while
      // the operator keeps using the app.
      final node = await addRadio();
      await connectAndLand(node);
      await cat.disconnect(node.uuid);
      final afterDisconnect = transport.attempts.length;

      radio.setVfo('vfoA', freq: 14074.0, mode: 'USB', origin: VfoOrigin.user);
      await pumpWithRadioOff();

      expect(transport.attempts.length, afterDisconnect,
          reason: 'tuning switched a deliberately disconnected radio back on');
    });

    test('a DELIBERATE disconnect is never undone by the retry', () async {
      // The failure this feature could become, and the one app-polo shipped.
      final node = await addRadio();
      await connectAndLand(node);

      await cat.disconnect(node.uuid);
      final afterDisconnect = transport.attempts.length;
      await pumpWithRadioOff();

      expect(transport.attempts.length, afterDisconnect,
          reason: 'Disconnect must stay disconnected');
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    });

    test('Disconnect STOPS a retry loop that is already running', () async {
      // The case the test above cannot reach, and the only one where the
      // userDisconnected flag actually decides anything. A deliberate
      // Disconnect never STARTS the loop — _teardown clears runtime.connection
      // before closing, so the closed-handler returns early. The flag matters
      // when the loop is ALREADY running because the radio vanished, and the
      // operator then says "stop": without it the loop keeps switching the
      // radio back on underneath them.
      final node = await addRadio();
      final connection = await connectAndLand(node);
      connection.dropRemotely();
      await pumpEventQueue();
      await pumpWithRadioOff();
      final whileRetrying = transport.attempts.length;
      expect(whileRetrying, greaterThan(1), reason: 'the loop should be running');

      await cat.disconnect(node.uuid);
      final atDisconnect = transport.attempts.length;
      await pumpWithRadioOff();

      expect(transport.attempts.length, atDisconnect,
          reason: 'the running loop ignored the operator');
    });

    test('a manual Connect that succeeds ends the loop', () async {
      // The other path the stop-when-connected check guards: the loop is
      // waiting on a dead radio and the operator connects it by hand.
      final node = await addRadio();
      final connection = await connectAndLand(node);
      connection.dropRemotely();
      await pumpEventQueue();
      await pumpWithRadioOff();
      expect(transport.attempts.length, greaterThan(1));

      // Connect by hand and land it.
      final connecting = cat.connect(node.uuid);
      await pumpEventQueue();
      transport.attempts.last.completer.complete(_FakeConnection('c-manual', log));
      await connecting;
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

      final afterManual = transport.attempts.length;
      await pumpWithRadioOff();
      expect(transport.attempts.length, afterManual,
          reason: 'the loop kept trying a radio that is already connected');
    });

    test('a drop on a node that is NOT designated starts nothing', () async {
      // Unplugging a second rig must not generate connect traffic for the one
      // the logging panel uses.
      final other = await addRadio(host: 'a.local');
      final designated = await cat.addNode(typeKey: 'fake-type', name: 'Right', config: {'host': 'b.local'});
      expect(cat.isRadio1(designated.uuid), isTrue, reason: 'newest wins');
      final co = await connectAndLand(other);
      await connectAndLand(designated);
      final before = transport.attempts.length;

      co.dropRemotely();
      await pumpEventQueue();
      await pumpWithRadioOff();

      expect(transport.attempts.length, before,
          reason: 'a non-designated drop pulled the designated radio into a retry');
    });

    test('asking to connect again resumes retrying', () async {
      // Disconnect is not permanent: pressing Connect clears the intent, so a
      // radio that then drops is looked after again.
      final node = await addRadio();
      await connectAndLand(node);
      await cat.disconnect(node.uuid);

      final reconnected = await connectAndLand(node);
      reconnected.dropRemotely();
      await pumpEventQueue();
      final afterDrop = transport.attempts.length;
      await pumpWithRadioOff();

      expect(transport.attempts.length, greaterThan(afterDrop));
    });

    test('a station with no designated radio is left completely alone', () async {
      // HALO-50: None is a real choice, and this loop must not quietly undo it
      // by connecting something.
      final node = await addRadio();
      final connection = await connectAndLand(node);
      await cat.setRadio1(null);
      connection.dropRemotely();
      await pumpEventQueue();
      final afterDrop = transport.attempts.length;

      await pumpWithRadioOff();

      expect(transport.attempts.length, afterDrop, reason: 'None must mean none');
    });

    test('the retry stops once the radio is back', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);
      connection.dropRemotely();
      await pumpEventQueue();

      // Fail a few attempts as an absent radio would, then let the NEXT one
      // land — the radio coming back. pumpWithRadioOff completes everything it
      // sees, so this has to wait for a fresh attempt rather than reusing the
      // last, which is already failed.
      await pumpWithRadioOff();
      final before = transport.attempts.length;
      for (var i = 0; i < 200 && transport.attempts.length == before; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await pumpEventQueue();
      }
      expect(transport.attempts.length, greaterThan(before), reason: 'the retry stopped trying');
      transport.attempts.last.completer.complete(_FakeConnection('c-recovered', log));
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);

      final afterRecovery = transport.attempts.length;
      await pumpWithRadioOff();
      expect(transport.attempts.length, afterRecovery,
          reason: 'a connected radio must not keep being reconnected');
    });
  });

  // -------------------------------------------------- reconnect on drop

  group('the designated radio comes back after an unexpected drop', () {
    test('a remote drop triggers a reconnect attempt', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);
      expect(cat.isRadio1(node.uuid), isTrue, reason: 'the sole transceiver is radio1');
      final attemptsBefore = transport.attempts.length;

      // The radio going away on its own — powered off, WiFi dropped, or the
      // 0x50 the Icom transport now listens for.
      connection.dropRemotely();
      await pumpEventQueue();

      expect(transport.attempts.length, greaterThan(attemptsBefore),
          reason: 'nothing tried to get the radio back');
    });

    test('a DELIBERATE disconnect is never undone', () async {
      // An OUTCOME test, deliberately: it does not care how the invariant is
      // enforced, only that pressing Disconnect leaves the radio disconnected.
      //
      // Today what enforces it is teardown ordering — _teardown clears
      // runtime.connection before closing, so the closed handler exits at its
      // first guard. A `status == disconnecting` check was also written, and
      // mutation testing showed removing it changed nothing, so it went. This
      // test is what stands between a future reordering of teardown and an
      // auto-reconnect that fights the operator, which is exactly what
      // app-polo's did.
      final node = await addRadio();
      await connectAndLand(node);
      final attemptsBefore = transport.attempts.length;

      await cat.disconnect(node.uuid);
      await pumpEventQueue();

      expect(transport.attempts.length, attemptsBefore,
          reason: 'Disconnect must stay disconnected');
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    });

    test('a second drop inside the cooldown does not start another burst', () async {
      // This radio is on record as getting WORSE when reconnected at speed,
      // so a flapping link must not turn into a storm of sessions it has to
      // track.
      final node = await addRadio();
      final first = await connectAndLand(node);
      first.dropRemotely();
      await pumpEventQueue();
      final afterFirst = transport.attempts.length;

      // Land the reconnect, then drop it again straight away.
      final second = _FakeConnection('c-retry', log);
      transport.attempts.last.completer.complete(second);
      await pumpEventQueue();
      second.dropRemotely();
      await pumpEventQueue();

      expect(transport.attempts.length, afterFirst,
          reason: 'the cooldown must suppress a second burst');
    });

    test('a node that is not radio1 is left alone', () async {
      // Only the radio the logging panel depends on is worth reconnecting;
      // anything else is the operator's business.
      // Newest added takes radio1 (HALO-50), so `a` is the one nobody should
      // reconnect on our behalf.
      final a = await addRadio(host: 'a.local');
      final b = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      final ca = await connectAndLand(a);
      await connectAndLand(b);
      expect(cat.isRadio1(a.uuid), isFalse, reason: '${b.uuid} is the designated one');
      final attemptsBefore = transport.attempts.length;

      ca.dropRemotely();
      await pumpEventQueue();

      expect(transport.attempts.length, attemptsBefore);
    });
  });

  // ------------------------------------------------------- app shutdown

  group('saying goodbye before the app exits', () {
    // A session the radio is never told to end is one it keeps holding. The
    // IC-705 has a single remote-control slot, so quitting without a
    // disconnect is what makes the NEXT connect fail.
    //
    // These comments used to cite an audio flood instead. It was measured
    // false on hardware — the radio sends us no audio at all, because we never
    // open a session on its audio port. The tests below are unchanged; only
    // the reason they exist was wrong.
    test('shutdown closes every live connection', () async {
      final a = await addRadio(host: 'a.local');
      final b = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      final ca = await connectAndLand(a);
      final cb = await connectAndLand(b);
      expect(cat.stateFor(a.uuid).status, EquipmentStatus.connected);
      expect(cat.stateFor(b.uuid).status, EquipmentStatus.connected);

      await cat.shutdown();

      expect(ca.closeCalled, isTrue, reason: 'the first radio was never told to stop');
      expect(cb.closeCalled, isTrue, reason: 'the second radio was never told to stop');
      expect(cat.stateFor(a.uuid).status, EquipmentStatus.disconnected);
      expect(cat.stateFor(b.uuid).status, EquipmentStatus.disconnected);
    });

    test('shutdown AWAITS the goodbye, rather than firing and returning', () async {
      // The distinction that matters at exit: dispose() leaves the teardown
      // unawaited, so the process can die before the disconnect datagrams are
      // even sent. If this future completes while a close is still pending,
      // the fix is decorative.
      final node = await addRadio();
      final connection = await connectAndLand(node);

      await cat.shutdown();

      expect(connection.closeCalled, isTrue);
      expect(log, contains('close:c1'), reason: 'the close must have run, not merely been scheduled');
    });

    test('one radio that refuses to let go does not strand the others', () async {
      // Every connected radio is streaming at us, so a single stuck teardown
      // must not leave the rest of them doing it.
      final a = await addRadio(host: 'a.local');
      final b = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      await connectAndLand(a);
      final cb = await connectAndLand(b);
      driver.sessions.first.teardownThrows = true;

      await cat.shutdown();

      expect(cb.closeCalled, isTrue, reason: 'the second radio still had to be released');
      expect(cat.stateFor(b.uuid).status, EquipmentStatus.disconnected);
    });

    test('shutdown with nothing connected is harmless', () async {
      await addRadio();
      await cat.shutdown();
      expect(log, isEmpty);
    });
  });

  group('the Main VFO is stored, never derived (HALO-50)', () {
    test('None survives a relaunch instead of jumping to a rig', () async {
      // The report, verbatim: "I can select None from the drop down, but this
      // choice does not persist. When opening Halo next time, it jumps to one
      // of the rigs, and fails."
      await addRadio(host: 'a.local');
      await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      await cat.setRadio1(null);

      final reloaded = await makeService();
      addTearDown(reloaded.dispose);
      expect(reloaded.radio1, isNull, reason: 'the app picked a rig behind the operator');
    });

    test('the newest transceiver added takes the VFO', () async {
      final first = await addRadio(host: 'a.local');
      expect(cat.radio1, first.uuid, reason: 'a one-radio shack never has to choose');

      final second = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      expect(cat.radio1, second.uuid, reason: 'newest wins');
    });

    test('adding a rig after choosing None still takes the VFO', () async {
      // Adding equipment is an action; None is a previous state, not a veto on
      // future ones. This is the deliberate consequence of "newest wins".
      await addRadio(host: 'a.local');
      await cat.setRadio1(null);

      final added = await cat.addNode(typeKey: 'fake-type', name: 'Third', config: {'host': 'c.local'});

      expect(cat.radio1, added.uuid);
    });

    test('removing the designated radio clears it rather than promoting another', () async {
      // Deliberately NOT promoting: moving the logging panel onto a different
      // rig immediately after a destructive action is the same class of
      // surprise this card is about.
      final a = await addRadio(host: 'a.local');
      final b = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      await cat.setRadio1(a.uuid);

      await cat.removeNode(a.uuid);

      expect(cat.radio1, isNull, reason: 'node ${b.uuid} was silently promoted');
    });

    test('removing a node that is NOT the designated one leaves it alone', () async {
      final a = await addRadio(host: 'a.local');
      final b = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      expect(cat.radio1, b.uuid);

      await cat.removeNode(a.uuid);

      expect(cat.radio1, b.uuid);
    });

    test('a stored radio1 whose node did not load reads as None', () async {
      // The case the derived version got wrong: _load drops a record it cannot
      // parse ("a single corrupt record drops that node"), and the old
      // _ensureRadio1 would then designate some OTHER radio — or, with the
      // first fix attempt, silently designate nothing while looking like an
      // explicit None. Stored state has one answer: the choice points at
      // nothing, so it is None, and the operator can see that and pick.
      SharedPreferences.setMockInitialValues({
        'stationEquipment': jsonEncode({
          'version': 1,
          'radio1': 'a-uuid-that-is-not-here',
          'nodes': {
            'b-uuid': {'typeKey': 'fake-type', 'name': 'Right Radio', 'config': {'host': 'b.local'}},
          },
        }),
      });
      final loaded = await makeService();
      addTearDown(loaded.dispose);

      expect(loaded.nodes, hasLength(1), reason: 'the surviving node still loads');
      expect(loaded.radio1, isNull);
    });

    test('a station stored with a valid radio1 keeps it', () async {
      // The migration case: every existing configuration has a radio1 key,
      // because the old code persisted auto-designated values too.
      final node = await addRadio();
      expect(cat.radio1, node.uuid);

      final reloaded = await makeService();
      addTearDown(reloaded.dispose);
      expect(reloaded.radio1, node.uuid);
    });
  });

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
      // Uses a NON-designated node on purpose. Dropping radio1 now starts a
      // reconnect (see 'the designated radio comes back after an unexpected
      // drop'), so this — the plain drop-to-disconnected path, which is still
      // what every other piece of equipment does — needs a node that is not
      // the one the logging panel depends on.
      // The NEWEST transceiver added takes radio1 (HALO-50), so the
      // non-designated one is the first.
      final other = await addRadio(host: 'a.local');
      await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      expect(cat.isRadio1(other.uuid), isFalse, reason: 'the SECOND radio took radio1');
      final connection = await connectAndLand(other);

      connection.dropRemotely();
      await pumpEventQueue();
      expect(cat.stateFor(other.uuid).status, EquipmentStatus.disconnected);
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

      // Dropping the live one now starts a reconnect, because this node is
      // radio1 — so it does NOT settle on `disconnected`. What this test is
      // for is the assertion above: a late close from a superseded socket
      // must not clobber the connection that replaced it.
      live.dropRemotely();
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, isNot(EquipmentStatus.connected),
          reason: 'the live connection really did go away');
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
      // `first` is radio1, so its drop now starts a reconnect and it lands on
      // `connecting` rather than `disconnected`. The invariant this test
      // exists for is the line below it: per-node runtime state, so one node
      // going away — or coming back — must leave the other untouched.
      expect(cat.stateFor(first.uuid).status, isNot(EquipmentStatus.connected));
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

  group('naming a new radio after the one it is', () {
    test('the first of a kind is unnumbered', () {
      expect(uniqueEquipmentName('Icom IC-705', []), 'Icom IC-705');
      expect(uniqueEquipmentName('Icom IC-705', ['Yaesu FT-891']), 'Icom IC-705');
    });

    test('numbering starts at 2, because "Icom IC-705 1" reads as a shack with two', () {
      expect(uniqueEquipmentName('Icom IC-705', ['Icom IC-705']), 'Icom IC-705 2');
      expect(uniqueEquipmentName('Icom IC-705', ['Icom IC-705', 'Icom IC-705 2']), 'Icom IC-705 3');
    });

    test('a freed number is reused rather than counted past', () {
      // Removing the middle of three and adding another should land back on
      // 2, not 4 — the number says which one, not how many there have ever
      // been.
      expect(uniqueEquipmentName('Icom IC-705', ['Icom IC-705', 'Icom IC-705 3']), 'Icom IC-705 2');
    });

    test('a name that differs only in case or padding is still taken', () {
      // Two rows the operator cannot tell apart is the whole failure being
      // avoided, and trailing space is invisible.
      expect(uniqueEquipmentName('Icom IC-705', ['icom ic-705']), 'Icom IC-705 2');
      expect(uniqueEquipmentName('Icom IC-705', ['  Icom IC-705  ']), 'Icom IC-705 2');
    });

    test('addNode names an unnamed node after its model, not its pairing', () async {
      // The model, deliberately: the transport is already shown by the row's
      // icon and address, and it can be changed in the editor afterwards —
      // baking it into the name would leave the name lying.
      final first = await cat.addNode(typeKey: 'fake-type', config: {'host': 'a.local'});
      expect(first.name, 'Fake Radio');

      final second = await cat.addNode(typeKey: 'fake-type', config: {'host': 'b.local'});
      expect(second.name, 'Fake Radio 2');
    });

    test('a name the operator typed is never second-guessed', () async {
      final node = await cat.addNode(typeKey: 'fake-type', name: 'Left Radio', config: {'host': 'a.local'});
      expect(node.name, 'Left Radio');

      // Not even when it collides: two radios called the same thing is the
      // operator's call to make, and renaming what they just typed is worse
      // than letting them repeat themselves.
      final same = await cat.addNode(typeKey: 'fake-type', name: 'Left Radio', config: {'host': 'b.local'});
      expect(same.name, 'Left Radio');
    });
  });

  group('re-typing a node — the same radio, reached a different way', () {
    late _FakeTransport altTransport;
    late CatService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final log = <String>[];
      final driver = _FakeDriver(log);
      transport = _FakeTransport();
      altTransport = _FakeTransport(transportKey: 'fake-alt');
      service = CatService(
        settings,
        registry: EquipmentRegistry(
          models: [
            EquipmentModel(
              key: 'fake',
              category: kCategoryTransceiver,
              name: () => 'Fake Radio',
              variants: [
                EquipmentVariant(key: 'fake-type', driver: driver, transport: transport),
                EquipmentVariant(key: 'fake-type-alt', driver: driver, transport: altTransport),
              ],
            ),
          ],
          transports: {'fake': transport, 'fake-alt': altTransport},
        ),
        reconnectDelay: Duration.zero,
      );
      addTearDown(service.dispose);
    });

    test('switching transport drops the live connection', () async {
      // The connection is the OLD transport's and the session was built by
      // the pairing the node is leaving. Neither can be handed to the new
      // one, so leaving the runtime attached would show a green row whose
      // link belongs to a configuration that no longer exists.
      final node = await service.addNode(typeKey: 'fake-type', config: {'host': 'a.local'});
      final connecting = service.connect(node.uuid);
      await pumpEventQueue();
      final connection = _FakeConnection('c1', <String>[]);
      transport.attempts.last.completer.complete(connection);
      await connecting;
      expect(service.stateFor(node.uuid).status, EquipmentStatus.connected);

      await service.updateNode(node.copyWith(typeKey: 'fake-type-alt'));

      expect(connection.closeCalled, isTrue);
      expect(service.stateFor(node.uuid).status, EquipmentStatus.disconnected);
      expect(service.nodes.single.typeKey, 'fake-type-alt');
      expect(service.typeFor(service.nodes.single)?.transport.key, 'fake-alt');
    });

    test('editing a setting on the SAME pairing leaves the connection alone', () async {
      // The other half of the rule, and the reason it is a typeKey comparison
      // rather than "updateNode disconnects": correcting a radio's NAME must
      // not drop a working link mid-QSO.
      final node = await service.addNode(typeKey: 'fake-type', config: {'host': 'a.local'});
      final connecting = service.connect(node.uuid);
      await pumpEventQueue();
      final connection = _FakeConnection('c1', <String>[]);
      transport.attempts.last.completer.complete(connection);
      await connecting;

      await service.updateNode(node.copyWith(name: 'Left Radio'));

      expect(connection.closeCalled, isFalse);
      expect(service.stateFor(node.uuid).status, EquipmentStatus.connected);
    });
  });
}

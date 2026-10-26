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
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/auto_connect_guard.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/radio_modes.dart';
import 'package:ham2k_logger/services/cat/discovery.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/none_transport.dart';
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../support/fake_clock.dart';

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

  /// When the service asked for this connection.
  ///
  /// Timing assertions read THIS, never the clock at the moment a polling loop
  /// happens to notice the attempt. The two differ by however long the isolate
  /// was starved, which on a loaded machine is unbounded and has nothing to do
  /// with the retry being measured.
  final at = clock.now();

  _Attempt(this.target, this.cancel);
}

/// A preferences store that reads normally and refuses every write — an
/// unwritable file, a wedged platform channel.
class _RefusingWritesStore extends SharedPreferencesStorePlatform {
  /// Set once the store it wraps exists — `setMockInitialValues` installs a
  /// fresh one, so this can only be wrapped around what that leaves behind.
  late SharedPreferencesStorePlatform inner;
  var refuse = false;

  Future<bool> _refused() => Future.error(StateError('the preferences file is read-only'));

  @override
  Future<bool> clear() => refuse ? _refused() : inner.clear();

  @override
  Future<Map<String, Object>> getAll() => inner.getAll();

  @override
  Future<bool> remove(String key) => refuse ? _refused() : inner.remove(key);

  @override
  Future<bool> setValue(String valueType, String key, Object value) => refuse ? _refused() : inner.setValue(valueType, key, value);
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
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    const {'type': 'field', 'fieldType': 'text', 'key': 'host', 'label': 'Host'},
  ];

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
      unawaited(
        cancel.whenCancelled.then((_) {
          if (!attempt.completer.isCompleted) attempt.completer.completeError(const CatCancelledException());
        }),
      );
    }
    return attempt.completer.future;
  }
}

class _FakeSession implements TransceiverSession, CwKeyerSession, VoiceKeyerSession, RawCommandSession {
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
      sink.report(VfoReading(freqKHz: double.tryParse(parts[0]), mode: parts.length > 1 ? parts[1] : null));
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

  /// Written as given, like the drivers whose answers name their command.
  @override
  int? sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    sink.send(bytes);
    return null;
  }

  /// Drivers report from their own timers, so a session can try to publish
  /// long after the connection it belongs to has been superseded.
  void reportFromItsOwnTimer(VfoReading reading) => sink.report(reading);

  /// Stands in for a piece of equipment with no VFO at all — an antenna
  /// switch — reporting the only thing it has.
  void reportSwitchState() =>
      sink.reportSwitchState(const [SwitchAntenna(key: '1', name: 'Hex')], const [SwitchPort(key: '1', label: 'A', selectedAntennaKey: '1')]);

  @override
  void setFrequency(double freqKHz) => log.add('setFrequency:$freqKHz');

  @override
  void setMode(String mode) => log.add('setMode:$mode');

  @override
  void setPower(num watts) => log.add('setPower:$watts');

  @override
  void sendCw(String text) => log.add('sendCw:$text');

  @override
  void stopCw() => log.add('stopCw');

  /// Settable, unlike the rest of this fake: whether the key was mid-message
  /// is the whole question for the tidy-up a change of key in use owes the
  /// outgoing one, and a hardcoded false makes that branch unreachable.
  @override
  bool cwSending = false;

  @override
  void dropQueuedCw(int index) => log.add('dropQueuedCw:$index');

  /// Plays nothing and reports nothing: a test says when a memory is heard
  /// starting and ending, through [sink], as a radio's own reports would.
  @override
  int get voiceMemoryCount => 4;

  @override
  bool get canRecordVoice => false;

  @override
  Duration get voiceMemoryCeiling => const Duration(seconds: 30);

  @override
  void playVoiceMemory(int n) => log.add('playVoice:$n');

  @override
  void recordVoiceMemory(int n) => log.add('recordVoice:$n');

  @override
  void stopVoice() => log.add('stopVoice');

  @override
  ({int min, int max}) get keyerSpeedRange => (min: 5, max: 50);

  @override
  void setKeyerSpeed(int wpm) => log.add('setKeyerSpeed:$wpm');

  @override
  void refreshKeyerSpeed() => log.add('refreshKeyerSpeed');

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
  /// Its sessions are keyers, so a fake radio added first is the key in
  /// use — the same auto-designation a real keying radio gets.
  @override
  bool get canKeyCw => true;

  /// Off by default, like a radio that can be asked its own speed; the
  /// remembering tests flip it.
  @override
  bool get remembersKeyerSpeed => remembersSpeed;
  bool remembersSpeed = false;

  final List<String> log;
  final sessions = <_FakeSession>[];
  var teardownThrows = false;

  _FakeDriver(this.log);

  @override
  String get key => 'fake-driver';

  @override
  String get name => 'Fake Radio';

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _FakeSession(sink, log)..teardownThrows = teardownThrows;
    sessions.add(session);
    return session;
  }
}

/// A transceiver whose protocol has no keyer at all — what most drivers are.
class _PlainSession implements TransceiverSession {
  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void teardown() {}
}

class _PlainDriver extends EquipmentDriver {
  const _PlainDriver();
  @override
  String get key => 'plain';
  @override
  String get name => 'Plain Radio';
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => _PlainSession();
}

/// A protocol that queues raw commands behind its own and answers each, as
/// CI-V does: one per line here, and a line reading `bad` is not a command.
class _QueuedSession extends _PlainSession implements RawCommandSession {
  final raw = <String>[];
  final answers = <void Function(List<int> answer)?>[];
  @override
  int sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    final lines = utf8.decode(bytes).split('\n');
    if (lines.contains('bad')) throw const FormatException('not a command');
    raw.addAll(lines);
    answers.addAll([for (final _ in lines) onAnswer]);
    return lines.length;
  }

  void answer(int index, String text) => answers[index]!(utf8.encode(text));
}

class _QueuedDriver extends EquipmentDriver {
  final sessions = <_QueuedSession>[];
  @override
  String get key => 'queued';
  @override
  String get name => 'Queued Radio';
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _QueuedSession();
    sessions.add(session);
    return session;
  }
}

EquipmentModel _plainModel(EquipmentTransport transport) => EquipmentModel(
  key: 'plain',
  category: kCategoryTransceiver,
  name: () => 'Plain Radio',
  variants: [
    EquipmentVariant(key: 'plain-type', driver: const _PlainDriver(), transport: transport, defaultConfig: const {'host': ''}),
  ],
);

/// A keyer of its own — a Winkeyer stand-in on the fake transport.
EquipmentModel _keyerModel(EquipmentDriver driver, EquipmentTransport transport) => EquipmentModel(
  key: 'fake-keyer',
  category: kCategoryKeyer,
  name: () => 'Fake Keyer',
  variants: [
    EquipmentVariant(key: 'keyer-type', driver: driver, transport: transport, defaultConfig: const {'host': ''}),
  ],
);

EquipmentModel _fakeModel(EquipmentDriver driver, EquipmentTransport transport) => EquipmentModel(
  key: 'fake',
  category: kCategoryTransceiver,
  name: () => 'Fake Radio',
  variants: [
    EquipmentVariant(key: 'fake-type', driver: driver, transport: transport, defaultConfig: const {'host': ''}),
  ],
);

// ----------------------------------------------------------------- setup

/// The retry floor the tests inject, and the value the tuning deadline is a
/// multiple of. Raising this without raising [_tuningDeadlineFactor] with it
/// moves the floor toward the deadline until a healthy shortcut misses it.
const idleRetryFloor = Duration(milliseconds: 20);

/// Long enough that the idle loop cannot fire DURING a test — for the ones
/// that assert on what a burst left behind rather than on the loop itself.
///
/// The trap it exists for: `_reconnectWithRetries` schedules the idle retry as
/// its last act and returns, so `await burst` completes with that timer armed.
/// Twenty milliseconds of wall clock is plenty on an idle machine and no time
/// at all on a loaded one, and when it fires it starts a fresh attempt — which
/// writes a fresh mark and sets the node `connecting`. A test asserting the
/// mark is clear, or the node is in error, then fails for a reason that has
/// nothing to do with what it is testing, and only when the suite is busy.
const idleRetryQuiet = Duration(minutes: 5);

/// How far above the floor a tune must land. Ten times, so an isolate has to
/// stall for a fifth of a second before a machine hiccup can fail the test.
const _tuningDeadlineFactor = 10;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;
  late _FakeTransport transport;
  late _FakeDriver driver;
  late List<String> log;
  late CatService cat;
  late RadioService radio;
  late _QueuedDriver queued;

  Future<CatService> makeService({void Function(String event, [Map<String, Object?> properties])? onTrack, Duration? idleRetryFirst}) async {
    settings = SettingsService(await SharedPreferences.getInstance());
    log = [];
    transport = _FakeTransport();
    driver = _FakeDriver(log);
    queued = _QueuedDriver();
    radio = RadioService(await SharedPreferences.getInstance(), writeDelay: Duration.zero);
    addTearDown(radio.dispose);
    return CatService(
      settings,
      radio: radio,
      onTrack: onTrack,
      registry: EquipmentRegistry(
        models: [
          _fakeModel(driver, transport),
          _plainModel(transport),
          _keyerModel(driver, transport),
          antennaModel,
          keyModel,
          EquipmentModel(
            key: 'queued',
            category: kCategoryTransceiver,
            name: () => 'Queued Radio',
            variants: [
              EquipmentVariant(key: 'queued-type', driver: queued, transport: transport, defaultConfig: const {'host': ''}),
            ],
          ),
        ],
        transports: {'fake': transport, 'none': const NoneTransport()},
      ),
      reconnectDelay: Duration.zero,
      // Short, not zero: the backoff doubles it, and zero doubled is a tight
      // loop. Long enough that a test which does NOT want a retry can pump the
      // queue without tripping one — but that is WALL CLOCK, so a test whose
      // assertions must not race the idle loop passes [idleRetryQuiet] rather
      // than relying on the machine being quick enough.
      idleRetryFirst: idleRetryFirst ?? idleRetryFloor,
      // The real window is 30 s. Long enough that no test trips it by
      // accident while pumping the queue, short enough to wait out on
      // purpose.
      staleAfter: const Duration(milliseconds: 40),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cat = await makeService();
  });

  Future<EquipmentNode> addRadio({String host = 'radio.local'}) => cat.addNode(typeKey: 'fake-type', name: 'Left Radio', config: {'host': host});

  /// Connects and lands the connection, returning it.
  Future<_FakeConnection> connectAndLand(EquipmentNode node) async {
    final connecting = cat.connect(node.uuid);
    await pumpEventQueue();
    final connection = _FakeConnection('c${transport.attempts.length}', log);
    transport.attempts.last.completer.complete(connection);
    await connecting;
    return connection;
  }

  group('radio telemetry', () {
    late List<(String, Map<String, Object?>)> tracked;

    Future<void> withTracking() async {
      tracked = [];
      cat = await makeService(onTrack: (event, [props = const {}]) => tracked.add((event, props)));
    }

    Iterable<Map<String, Object?>> only(String event) => tracked.where((e) => e.$1 == event).map((e) => e.$2);

    test('radio_connected reports once per radio, however often it reconnects', () async {
      // The trap: the idle retry pokes a radio every 30s rising to every 8
      // minutes for the whole session (see _scheduleIdleRetry). Reporting per
      // ATTEMPT would make this the loudest event in the app and skew every
      // per-user figure toward whoever left a rig switched off.
      await withTracking();
      final node = await addRadio();
      await connectAndLand(node);
      await connectAndLand(node);

      expect(only('radio_connected'), hasLength(1));
      final props = only('radio_connected').single;
      expect(props['radio'], 'fake-type');
      expect(props['transport'], 'fake');
      expect(props['name'], 'Left Radio');
    });

    test('radio_connect_failed classifies the error and never carries its text', () async {
      // The trap: `'$e'` is what the operator reads, and it routinely holds
      // the host or port that failed — on macOS a serial path embeds the
      // adapter's DEVICE SERIAL NUMBER. Only a bounded class may leave.
      await withTracking();
      final node = await addRadio(host: 'secret-host.invalid');
      final connecting = cat.connect(node.uuid);
      await pumpEventQueue();
      transport.attempts.last.completer.completeError(TimeoutException('no reply from secret-host.invalid'));
      await connecting;

      final props = only('radio_connect_failed').single;
      expect(props['reason'], 'timeout');
      expect(props['name'], 'Left Radio');
      expect(props.values.join(' '), isNot(contains('secret-host')), reason: 'no config value or error text may reach the payload');
    });

    test('a port refused over its control lines is its own class, not "other"', () async {
      // The desktop readback refuses a port whose RTS/DTR did not land. If
      // that misfires on some driver, the field is the only place it shows,
      // and "serial:other" would bury it among every unplaced failure.
      await withTracking();
      final node = await addRadio();
      final connecting = cat.connect(node.uuid);
      await pumpEventQueue();
      transport.attempts.last.completer.completeError(const _FakeSerialProblem(SerialFailure.lines));
      await connecting;

      expect(only('radio_connect_failed').single['reason'], 'serial:lines');
    });

    test('radio_added records whether discovery or the form found it', () async {
      // The gap between added and connected is what says a pairing is
      // configurable but not usable — worthless if both paths look alike.
      await withTracking();
      await addRadio();
      expect(only('radio_added').single['via'], 'manual');
      expect(only('radio_added').single['name'], 'Left Radio');

      tracked.clear();
      await cat.addDiscovered(const DiscoveredEquipment(typeKey: 'fake-type', id: 'disco-1', name: 'Found Radio', config: {'host': 'found.local'}));
      expect(only('radio_added').single['via'], 'discovery');
      expect(only('radio_added').single['name'], 'Found Radio');
    });

    test('a blank name falls back to the driver name, not an empty string', () async {
      // The trap: addNode always fills a blank name in via suggestedNameFor,
      // so only updateNode (which applies no such fallback) can produce the
      // pre-`name`-field / operator-cleared-the-field case this guards.
      await withTracking();
      final node = await addRadio();
      await cat.updateNode(node.copyWith(name: ''));
      tracked.clear();
      await connectAndLand(node);

      expect(only('radio_connected').single['name'], 'Fake Radio');
    });

    test('a name past 60 characters is truncated before it leaves the device', () async {
      await withTracking();
      final node = await cat.addNode(typeKey: 'fake-type', name: 'x' * 80, config: const {'host': 'a.local'});
      await connectAndLand(node);

      expect(only('radio_connected').single['name'], 'x' * 60);
    });
  });

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

    test(
      'a radio that is off keeps being tried',
      () => runOnFakeClock((_) async {
        final node = await addRadio();
        final connection = await connectAndLand(node);
        connection.dropRemotely();
        await pumpEventQueue();
        final afterDrop = transport.attempts.length;

        // The drop burst fails (nothing lands these attempts), and the retry
        // has to pick it up from there.
        await pumpWithRadioOff();

        expect(transport.attempts.length, greaterThan(afterDrop), reason: 'nothing tried again once the drop burst was spent');
      }),
    );

    /// How long the next connect attempt actually takes to show up.
    ///
    /// MEASURED, not assumed. Two earlier versions of the tests below picked a
    /// fixed window out of arithmetic on the constants, and both times the real
    /// interval was nothing like the guess — one window was wide enough to
    /// catch the backed-off retry it was supposed to rule out, so the test
    /// passed with the feature removed.
    Future<Duration> timeToNextAttempt({Duration limit = const Duration(seconds: 5), int? seen}) async {
      final start = clock.now();
      seen ??= transport.attempts.length;
      while (transport.attempts.length <= seen && clock.now().difference(start) < limit) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await pumpEventQueue();
      }
      return clock.now().difference(start);
    }

    Future<void> failEveryPendingAttempt() async {
      for (final a in transport.attempts) {
        if (!a.completer.isCompleted) a.completer.completeError(StateError('radio is off'));
      }
      await pumpEventQueue();
    }

    /// Fails retries until the wait has doubled clear of its floor.
    ///
    /// [until] is a floor on that wait, not a round count: how many doublings a
    /// given number of rounds buys depends on how many of them the drop burst's
    /// own attempts eat, which is not fixed. A caller that needs the wait to be
    /// comfortably longer than something has to say so, or it is asserting
    /// against whatever the constants happened to produce that run.
    Future<void> backOffUntilLong({Duration? until}) async {
      // Bounded by TIME, not by a round count. A round that finds no attempt
      // still costs timeToNextAttempt's full limit, so a count bounds only the
      // rounds and not the wall clock — and the whole test has to finish inside
      // package:test's 30s.
      final deadline = clock.now().add(const Duration(seconds: 12));
      var rounds = 0;
      while (clock.now().isBefore(deadline)) {
        await failEveryPendingAttempt();
        final armedAt = clock.now();
        final seen = transport.attempts.length;
        await timeToNextAttempt(seen: seen);
        rounds++;
        // A round where nothing arrived measured nothing. Treating its elapsed
        // time as a wait would let "the retry is dead" satisfy [until], since a
        // timeout is longer than any floor a caller would ask for.
        if (transport.attempts.length == seen) continue;
        final waited = transport.attempts.last.at.difference(armedAt);
        if (rounds >= 6 && (until == null || waited > until)) return;
      }
      // Only reachable with a floor that was never met: say so here rather than
      // letting the caller's own assertion fail later and send the reader to
      // the service's constants, which are not what gave up.
      if (until != null) {
        fail('the backoff never grew past ${until.inMilliseconds}ms in $rounds rounds');
      }
    }

    /// Waits for a connect attempt beyond [since], and fails if none comes.
    ///
    /// [since] is a count the CALLER takes before whatever should provoke the
    /// attempt. Taken afterwards it can already include the attempt being
    /// waited for — the retry fires inside the pump that follows the stimulus
    /// on a slow machine — and this would then wait out its limit for a second
    /// one that was never coming, failing a run in which the feature worked.
    ///
    /// Failing is the point. Every duration below is the gap between a moment
    /// the caller chose and an attempt's own stamp; with no new attempt there
    /// is no second point, and a duration taken anyway is measured against a
    /// STALE one — negative, and so below any deadline, which passes the
    /// assertion exactly when the retry is most broken.
    Future<void> awaitAttemptAfter(int since) async {
      await timeToNextAttempt(seen: since);
      expect(transport.attempts.length, greaterThan(since), reason: 'no connect attempt arrived at all — the retry is not running');
    }

    /// How soon a tune must get the retry moving again — derived from the
    /// floor rather than written down beside it, so the two cannot drift
    /// apart. The assertion beside it checks the backed-off wait is still
    /// comfortably longer than this, which keeps the number honest from the
    /// other side.
    final tuningDeadline = idleRetryFloor * _tuningDeadlineFactor;

    test(
      'working the VFO of an absent radio pulls the retry off its ceiling',
      () => runOnFakeClock((_) async {
        // The operator is in the app, tuning, and the radio is not there. Without
        // this they wait out whatever the backoff has grown to — on real
        // constants, up to eight minutes with nothing visibly trying.
        final node = await addRadio();
        final connection = await connectAndLand(node);
        connection.dropRemotely();
        await pumpEventQueue();
        // Back off until the wait is comfortably past the deadline, so the
        // assertion below is measuring a shortcut rather than a coincidence.
        await backOffUntilLong(until: tuningDeadline * 2);

        // Time one full backed-off wait, so the deadline below is checked against
        // what this machine actually did rather than against the constants.
        await failEveryPendingAttempt();
        final beforeBackedOff = transport.attempts.length;
        final armedAt = clock.now();
        await awaitAttemptAfter(beforeBackedOff);
        final backedOff = transport.attempts.last.at.difference(armedAt);

        // Arm the next wait — longer still, since that attempt just failed.
        await failEveryPendingAttempt();
        // Counted BEFORE the tune: the shortcut can land its attempt inside the
        // pump below, and a count taken after would already include it.
        final beforeTuning = transport.attempts.length;
        // The operator types a frequency.
        final tunedAt = clock.now();
        radio.setVfo('vfoA', freq: 14074.0, mode: 'USB', origin: VfoOrigin.user);
        await pumpEventQueue();
        await awaitAttemptAfter(beforeTuning);
        // Measured from the attempt's own stamp, so a starved isolate cannot
        // inflate it: what is being asserted is when the service tried, not when
        // this loop got around to looking.
        final afterTuning = transport.attempts.last.at.difference(tunedAt);

        // Absolute, not a fraction of [backedOff]. A ratio between two
        // measurements puts the decision on the smaller of them — tens of
        // milliseconds — and scheduling noise moves that far more,
        // proportionally, than it moves the large one.
        expect(
          afterTuning,
          lessThan(tuningDeadline),
          reason:
              'tuning an absent radio left the operator waiting out the backoff '
              '(${afterTuning.inMilliseconds}ms, deadline ${tuningDeadline.inMilliseconds}ms)',
        );
        // Without this the deadline could quietly stop meaning anything: if the
        // backed-off wait ever shrank below it, the test would pass whether or
        // not tuning shortened a thing.
        expect(
          backedOff,
          greaterThan(tuningDeadline * 2),
          reason:
              'the backoff no longer grows far enough past the deadline for this '
              'test to be able to fail (${backedOff.inMilliseconds}ms)',
        );
      }),
    );

    test(
      'tuning continuously does not starve the retry it just shortened',
      () => runOnFakeClock((_) async {
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

        expect(transport.attempts.length, greaterThan(seen), reason: 'continuous tuning pushed the retry out for ever; the radio was never tried');
      }),
    );

    test(
      'a startup burst that finds the radio off hands over to the loop',
      () => runOnFakeClock((_) async {
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

        expect(transport.attempts.length, greaterThan(afterBurst), reason: 'the app started with the radio off and then gave up for the whole session');
      }),
    );

    test(
      'connecting a DIFFERENT rig does not reset the designated radio\'s backoff',
      () => runOnFakeClock((_) async {
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

        expect(
          afterOther * 2,
          greaterThan(backedOff),
          reason:
              'connecting an unrelated rig collapsed radio1\'s backoff '
              '(${afterOther.inMilliseconds}ms vs ${backedOff.inMilliseconds}ms)',
        );
      }),
    );

    test(
      'tuning does not start connecting a radio nobody has switched on',
      () => runOnFakeClock((_) async {
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

        expect(transport.attempts.length, before, reason: 'typing a frequency started dialling a radio that was never connected');
      }),
    );

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

      expect(transport.attempts.length, afterDisconnect, reason: 'tuning switched a deliberately disconnected radio back on');
    });

    test('a DELIBERATE disconnect is never undone by the retry', () async {
      // The failure this feature could become, and the one app-polo shipped.
      final node = await addRadio();
      await connectAndLand(node);

      await cat.disconnect(node.uuid);
      final afterDisconnect = transport.attempts.length;
      await pumpWithRadioOff();

      expect(transport.attempts.length, afterDisconnect, reason: 'Disconnect must stay disconnected');
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
    });

    test(
      'Disconnect STOPS a retry loop that is already running',
      () => runOnFakeClock((_) async {
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

        expect(transport.attempts.length, atDisconnect, reason: 'the running loop ignored the operator');
      }),
    );

    test(
      'a port refused over its control lines is not retried until the operator asks',
      () => runOnFakeClock((_) async {
        // Hardware flow control another program left on the port lasts until
        // the cable is replugged, and every retry opens the port — which raises
        // RTS, the PTT line on a Digirig. Retrying would key the rig once per
        // attempt for the rest of the session.
        final node = await addRadio();
        final connection = await connectAndLand(node);
        connection.dropRemotely();
        await pumpEventQueue();
        for (var i = 0; i < 40; i++) {
          for (final a in transport.attempts) {
            if (!a.completer.isCompleted) a.completer.completeError(const _FakeSerialProblem(SerialFailure.lines));
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await pumpEventQueue();
        }
        final afterRefusal = transport.attempts.length;
        await pumpWithRadioOff();
        expect(transport.attempts.length, afterRefusal, reason: 'the loop kept reopening a port it had refused');

        // Replugged, the operator tries again: that one goes out.
        unawaited(cat.connect(node.uuid));
        await pumpEventQueue();
        expect(transport.attempts.length, afterRefusal + 1);
      }),
    );

    test(
      'a manual Connect that succeeds ends the loop',
      () => runOnFakeClock((_) async {
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
        expect(transport.attempts.length, afterManual, reason: 'the loop kept trying a radio that is already connected');
      }),
    );

    test(
      'a drop on a node that is NOT designated starts nothing',
      () => runOnFakeClock((_) async {
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

        expect(transport.attempts.length, before, reason: 'a non-designated drop pulled the designated radio into a retry');
      }),
    );

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

    test(
      'a station with no designated radio is left completely alone',
      () => runOnFakeClock((_) async {
        // None is a real choice, and this loop must not quietly undo it
        // by connecting something.
        final node = await addRadio();
        final connection = await connectAndLand(node);
        await cat.setRadio1(null);
        connection.dropRemotely();
        await pumpEventQueue();
        final afterDrop = transport.attempts.length;

        await pumpWithRadioOff();

        expect(transport.attempts.length, afterDrop, reason: 'None must mean none');
      }),
    );

    test(
      'the retry stops once the radio is back',
      () => runOnFakeClock((_) async {
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
        expect(transport.attempts.length, afterRecovery, reason: 'a connected radio must not keep being reconnected');
      }),
    );
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

      expect(transport.attempts.length, greaterThan(attemptsBefore), reason: 'nothing tried to get the radio back');
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

      expect(transport.attempts.length, attemptsBefore, reason: 'Disconnect must stay disconnected');
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

      expect(transport.attempts.length, afterFirst, reason: 'the cooldown must suppress a second burst');
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

  group('a peer\'s radio in the Main VFO list (HALO-416)', () {
    const pick = PeerRadioSelection(deviceId: 'device-a', radioId: 'rig-1', radioName: 'IC-705');

    test('the two pointers are exclusive, both ways round', () async {
      final local = await addRadio();
      expect(cat.radio1, LocalRadio(local.uuid));

      await cat.setRadio1(const PeerRadio(pick));
      expect(cat.radio1, const PeerRadio(pick), reason: 'two things writing one vfoA fight');

      await cat.setRadio1(LocalRadio(local.uuid));
      expect(cat.radio1, LocalRadio(local.uuid), reason: 'the local pick is stored, not merely the peer dropped');
    });

    test('picking None while a peer radio is selected clears it', () async {
      // `radio1` is already null here, so the setter's own unchanged-value
      // early return is exactly what would swallow this — and the operator
      // would be left on a remote rig having just asked for nothing.
      await cat.setRadio1(const PeerRadio(pick));

      await cat.setRadio1(null);

      expect(cat.radio1, isNull);
    });

    test('the pick survives a relaunch, peer present or not', () async {
      // Nothing here can check whether that device exists — it is a fact
      // about another machine. An absent peer is unavailable, not corrupt.
      await cat.setRadio1(const PeerRadio(pick));

      final reloaded = await makeService();
      addTearDown(reloaded.dispose);
      expect(reloaded.radio1, const PeerRadio(pick));
      expect((reloaded.radio1 as PeerRadio).selection.radioName, 'IC-705', reason: 'the name is all a picker has to show while the peer is away');
    });

    test('the main VFO is one slot, holding whichever kind was picked', () async {
      // The exclusivity the tests above assert is a PROPERTY of the storage,
      // not a pair of clears each setter remembers to run: two nullable
      // fields can hold both at once, one slot cannot.
      final local = await addRadio();
      expect(cat.radio1, LocalRadio(local.uuid));

      await cat.setRadio1(const PeerRadio(pick));
      expect(cat.radio1, const PeerRadio(pick));

      await cat.setRadio1(null);
      expect(cat.radio1, isNull);
    });

    test('a version 2 blob naming only a peer still loads it', () async {
      // The shape every build before this one wrote. A peer pick reaching a
      // new build as None would hand the VFO back to nothing, silently, on
      // the first launch after an update.
      SharedPreferences.setMockInitialValues({
        'stationEquipment': jsonEncode({
          'version': 2,
          'radio1': null,
          'remoteRadio1': {'deviceId': 'device-a', 'radioId': 'rig-1', 'radioName': 'IC-705'},
          'nodes': <String, dynamic>{},
        }),
      });
      final loaded = await makeService();
      addTearDown(loaded.dispose);

      expect(loaded.radio1, const PeerRadio(pick));
      expect((loaded.radio1 as PeerRadio).selection.radioName, 'IC-705');
    });

    test('what a version 2 blob is read as is written back as one key', () async {
      SharedPreferences.setMockInitialValues({
        'stationEquipment': jsonEncode({
          'version': 2,
          'remoteRadio1': {'deviceId': 'device-a', 'radioId': 'rig-1', 'radioName': 'IC-705'},
          'nodes': <String, dynamic>{},
        }),
      });
      final loaded = await makeService();
      addTearDown(loaded.dispose);
      // Any write at all rewrites the whole blob; picking the same peer is a
      // no-op, so move the VFO somewhere and back.
      await loaded.setRadio1(null);
      await loaded.setRadio1(const PeerRadio(pick));

      final blob = jsonDecode((await SharedPreferences.getInstance()).getString('stationEquipment')!);
      expect(blob['mainVfo'], {
        'peer': {'deviceId': 'device-a', 'radioId': 'rig-1', 'radioName': 'IC-705'},
      });
      expect(blob.containsKey('radio1'), isFalse, reason: 'one slot on disk too, or the pair can disagree again');
      expect(blob.containsKey('remoteRadio1'), isFalse);
    });

    test('a stored blob naming BOTH keeps only the local radio', () async {
      SharedPreferences.setMockInitialValues({
        'stationEquipment': jsonEncode({
          'version': 1,
          'radio1': 'b-uuid',
          'remoteRadio1': {'deviceId': 'device-a', 'radioId': 'rig-1'},
          'nodes': {
            'b-uuid': {
              'typeKey': 'fake-type',
              'name': 'Right Radio',
              'config': {'host': 'b.local'},
            },
          },
        }),
      });
      final loaded = await makeService();
      addTearDown(loaded.dispose);

      expect(loaded.radio1, LocalRadio('b-uuid'), reason: 'exclusivity is enforced on the way in too');
    });

    test('adding a transceiver does not steal the VFO from a peer\'s radio', () async {
      // "Newest wins" is about a shack with no answer yet. Configuring a rig
      // is not the same as reaching for it, and the operator working through
      // a peer's radio must not silently lose it.
      await cat.setRadio1(const PeerRadio(pick));

      final added = await addRadio();

      expect(cat.radio1, const PeerRadio(pick), reason: 'node ${added.uuid} was silently promoted');
    });

    test('a renamed peer or radio keeps the pick, and updates what it shows', () async {
      // The names exist to be shown once the peer is GONE, so the rename has
      // to be caught while it is still here — and the operator never picks
      // again, so nothing else would catch it. The pick itself must survive:
      // a renamed device is the same device, which is why the selection
      // compares only ids.
      await cat.setRadio1(const PeerRadio(pick));

      cat.noteOffer('device-a', 'Shack PC', const [PeerRadioOffer(id: 'rig-1', name: 'IC-7300')]);

      expect(cat.radio1, const PeerRadio(pick), reason: 'a rename is not a different radio');
      expect((cat.radio1 as PeerRadio).selection.deviceName, 'Shack PC');
      expect((cat.radio1 as PeerRadio).selection.radioName, 'IC-7300');

      final reloaded = await makeService();
      addTearDown(reloaded.dispose);
      expect((reloaded.radio1 as PeerRadio).selection.deviceName, 'Shack PC', reason: 'written through, not held');
    });

    test('another peer\'s offer leaves the pick\'s names alone', () async {
      await cat.setRadio1(const PeerRadio(pick));

      cat.noteOffer('device-z', 'Someone Else', const [PeerRadioOffer(id: 'rig-1', name: 'FT-891')]);

      expect((cat.radio1 as PeerRadio).selection.deviceName, '');
      expect((cat.radio1 as PeerRadio).selection.radioName, 'IC-705');
    });

    test('only CONNECTED transceivers are offered', () async {
      // Withdrawing the offer is the only thing that says a rig is not there
      // — nothing on the wire carries staleness — so an offer that ignored
      // the link would have a peer tune a radio nobody can reach and get a
      // confirmation back for it.
      final node = await addRadio();
      expect(cat.offeredRadios, isEmpty);

      await connectAndLand(node);

      expect(cat.offeredRadios.single.id, node.uuid);
      expect(cat.offeredRadios.single.name, 'Left Radio');
    });

    test('an offered radio that is not radio1 is still tunable, echo guard included', () async {
      // The newly reachable path: `_onVfoChanged` only ever drives radio1,
      // and it reads `vfoA` — a VFO this rig is not attached to. A peer
      // driving the shack's OTHER rig goes through tuneOfferedRadio instead.
      final other = await addRadio(host: 'a.local');
      final designated = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      expect(cat.radio1, LocalRadio(designated.uuid), reason: 'newest wins, so `other` is not radio1');
      await connectAndLand(other);
      log.clear();

      cat.tuneOfferedRadio(other.uuid, freqKHz: 14074.0, mode: 'USB');
      expect(log, containsAll(['setFrequency:14074.0', 'setMode:USB']));

      // Its confirmation restates what it was told, and re-sending that
      // would answer every status push with a command.
      log.clear();
      driver.sessions.single.reportFromItsOwnTimer(const VfoReading(freqKHz: 14074.0, mode: 'USB'));
      cat.tuneOfferedRadio(other.uuid, freqKHz: 14074.0, mode: 'USB');
      expect(log, isEmpty);

      // Then somebody turns THAT rig's knob. The dedupe is against what the
      // radio was last told, so a reading has to move it — otherwise asking
      // for 14074 again matches a record the rig has since left behind, the
      // command is skipped, and the peer is shown a frequency its radio is
      // not on until someone turns the knob back.
      driver.sessions.single.reportFromItsOwnTimer(const VfoReading(freqKHz: 14100.0, mode: 'USB'));
      log.clear();

      cat.tuneOfferedRadio(other.uuid, freqKHz: 14074.0, mode: 'USB');

      expect(log, contains('setFrequency:14074.0'));
    });

    test('a tune for a radio that is not offered reaches no rig', () async {
      final node = await addRadio();
      await connectAndLand(node);
      log.clear();

      cat.tuneOfferedRadio('not-a-node-here', freqKHz: 14074.0, mode: 'USB');

      expect(log, isEmpty, reason: 'naming a uuid must not be enough to move a radio');
    });

    test('a disconnected radio is not tunable even by its own uuid', () async {
      // radio1's tune deliberately goes through `RadioService` rather than
      // the session, so the offer check is the ONLY thing standing in front
      // of it: without it this moves app state on a rig that is not there,
      // and the report that write produces reaches the asker looking exactly
      // like the radio confirming.
      final node = await addRadio();
      expect(cat.isRadio1(node.uuid), isTrue, reason: 'the sole transceiver is radio1');
      await connectAndLand(node);
      await cat.disconnect(node.uuid);
      log.clear();

      cat.tuneOfferedRadio(node.uuid, freqKHz: 14074.0, mode: 'USB');

      expect(log, isEmpty);
      expect(radio.vfoA.freq, isNull, reason: 'nothing may pretend a dead rig tuned');
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
      expect(cat.radio1, LocalRadio(first.uuid), reason: 'a one-radio shack never has to choose');

      final second = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      expect(cat.radio1, LocalRadio(second.uuid), reason: 'newest wins');
    });

    test('adding a rig after choosing None still takes the VFO', () async {
      // Adding equipment is an action; None is a previous state, not a veto on
      // future ones. This is the deliberate consequence of "newest wins".
      await addRadio(host: 'a.local');
      await cat.setRadio1(null);

      final added = await cat.addNode(typeKey: 'fake-type', name: 'Third', config: {'host': 'c.local'});

      expect(cat.radio1, LocalRadio(added.uuid));
    });

    test('removing the designated radio clears it rather than promoting another', () async {
      // Deliberately NOT promoting: moving the logging panel onto a different
      // rig immediately after a destructive action is the same class of
      // surprise this card is about.
      final a = await addRadio(host: 'a.local');
      final b = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      await cat.setRadio1(LocalRadio(a.uuid));

      await cat.removeNode(a.uuid);

      expect(cat.radio1, isNull, reason: 'node ${b.uuid} was silently promoted');
    });

    test('removing a node that is NOT the designated one leaves it alone', () async {
      final a = await addRadio(host: 'a.local');
      final b = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      expect(cat.radio1, LocalRadio(b.uuid));

      await cat.removeNode(a.uuid);

      expect(cat.radio1, LocalRadio(b.uuid));
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
            'b-uuid': {
              'typeKey': 'fake-type',
              'name': 'Right Radio',
              'config': {'host': 'b.local'},
            },
          },
        }),
      });
      final loaded = await makeService();
      addTearDown(loaded.dispose);

      expect(loaded.nodes, hasLength(1), reason: 'the surviving node still loads');
      expect(loaded.radio1, isNull);
    });

    test('a version 1 blob\'s flat picks land on the radio that was selected', () async {
      // The branch every existing install runs exactly once, and the only
      // place an operator's picks can silently vanish. Version 1 stored ONE
      // flat category → uuid map — it belonged to whatever was selected when
      // it was written, which is radio1 here.
      SharedPreferences.setMockInitialValues({
        'stationEquipment': jsonEncode({
          'version': 1,
          'radio1': 'radio-uuid',
          'designated': {'antenna': 'ant-uuid', 'key': null},
          'nodes': {
            'radio-uuid': {
              'typeKey': 'fake-type',
              'name': 'Radio',
              'config': {'host': 'a.local'},
            },
            'ant-uuid': {'typeKey': 'antenna', 'name': 'Dipole', 'config': {}},
          },
        }),
      });
      final loaded = await makeService();
      addTearDown(loaded.dispose);

      expect(loaded.designatedFor(kCategoryAntenna), 'ant-uuid');
      // A stored null is the operator's None and outranks the radio's own
      // default — the collapse that would silently start a keying radio
      // keying again for someone who had switched it off.
      expect(loaded.designatedFor(kCategoryKey), isNull);
      // ...and it belonged to that radio, not to the station.
      await loaded.setRadio1(null);
      expect(loaded.designatedFor(kCategoryAntenna), isNull);
    });

    test('a version 1 blob whose radio1 did not load keeps its picks reachable under None', () async {
      // radio1 is deliberately left None when its node is corrupt, and
      // [_designationKey] answers for whatever is selected — so the picks
      // file under None. Stated as a test because the alternative (filing
      // them under a radio that does not exist) would put them somewhere
      // nothing can ever read them back.
      SharedPreferences.setMockInitialValues({
        'stationEquipment': jsonEncode({
          'version': 1,
          'radio1': 'a-uuid-that-is-not-here',
          'designated': {'antenna': 'ant-uuid'},
          'nodes': {
            'ant-uuid': {'typeKey': 'antenna', 'name': 'Dipole', 'config': {}},
          },
        }),
      });
      final loaded = await makeService();
      addTearDown(loaded.dispose);

      expect(loaded.radio1, isNull);
      expect(loaded.designatedFor(kCategoryAntenna), 'ant-uuid');
    });

    test('the version, not the shape of the values, says which layout a blob is in', () async {
      // A version 2 blob is read as per-radio even though nothing about its
      // values forces that reading. Sniffing for a Map value would get this
      // right only until some category value legitimately became one, and
      // would read a half-migrated blob as whichever branch its first Map
      // selected — dropping the other half without a word.
      SharedPreferences.setMockInitialValues({
        'stationEquipment': jsonEncode({
          'version': 2,
          'radio1': 'radio-uuid',
          'designated': {
            'radio-uuid': {'antenna': 'ant-uuid'},
            'other-radio': {'antenna': null},
          },
          'nodes': {
            'radio-uuid': {
              'typeKey': 'fake-type',
              'name': 'Radio',
              'config': {'host': 'a.local'},
            },
            'other-radio': {
              'typeKey': 'fake-type',
              'name': 'Other',
              'config': {'host': 'b.local'},
            },
            'ant-uuid': {'typeKey': 'antenna', 'name': 'Dipole', 'config': {}},
          },
        }),
      });
      final loaded = await makeService();
      addTearDown(loaded.dispose);

      expect(loaded.designatedFor(kCategoryAntenna), 'ant-uuid');
      await loaded.setRadio1(LocalRadio('other-radio'));
      expect(loaded.designatedFor(kCategoryAntenna), isNull, reason: 'the other radio\'s own None');
    });

    test('a station stored with a valid radio1 keeps it', () async {
      // The migration case: every existing configuration has a radio1 key,
      // because the old code persisted auto-designated values too.
      final node = await addRadio();
      expect(cat.radio1, LocalRadio(node.uuid));

      final reloaded = await makeService();
      addTearDown(reloaded.dispose);
      expect(reloaded.radio1, LocalRadio(node.uuid));
    });
  });

  group('antenna/key designation (HALO-263 follow-up)', () {
    Future<EquipmentNode> addAntenna({String name = 'Dipole'}) => cat.addNode(typeKey: antennaModel.variants.first.key, name: name);
    Future<EquipmentNode> addKey({String name = 'Bug'}) => cat.addNode(typeKey: keyModel.variants.first.key, name: name);

    test('the newest antenna added is designated, same rule as radio1', () async {
      final first = await addAntenna(name: 'First');
      expect(cat.designatedFor(kCategoryAntenna), first.uuid);

      final second = await addAntenna(name: 'Second');
      expect(cat.designatedFor(kCategoryAntenna), second.uuid);
    });

    test('adding an antenna does not touch which key is designated, or radio1', () async {
      final radio = await addRadio();
      final key = await addKey();

      await addAntenna();

      expect(cat.radio1, LocalRadio(radio.uuid));
      expect(cat.designatedFor(kCategoryKey), key.uuid);
    });

    test('removing the designated key clears it rather than promoting another', () async {
      final a = await addKey(name: 'a');
      final b = await addKey(name: 'b');
      await cat.setDesignated(kCategoryKey, a.uuid);

      await cat.removeNode(a.uuid);

      expect(cat.designatedFor(kCategoryKey), isNull, reason: '${b.uuid} was silently promoted');
    });

    test('the operator can designate any antenna directly, None included', () async {
      final a = await addAntenna(name: 'a');
      await addAntenna(name: 'b');

      await cat.setDesignated(kCategoryAntenna, a.uuid);
      expect(cat.designatedFor(kCategoryAntenna), a.uuid);

      await cat.setDesignated(kCategoryAntenna, null);
      expect(cat.designatedFor(kCategoryAntenna), isNull);
    });

    test('the designation survives a relaunch', () async {
      final key = await addKey();

      final reloaded = await makeService();
      addTearDown(reloaded.dispose);
      expect(reloaded.designatedFor(kCategoryKey), key.uuid);
    });
  });

  group('CW keying', () {
    // The keying rules only apply with the experiment on — a keying radio
    // becomes the key in use, the pick offers radios.
    setUp(() => settings.setExperimentEnabled('keyer', true));

    test('Key in Use = None survives a relaunch instead of jumping back to the rig', () async {
      // The trap: None is stored as a null entry, and a load that only kept
      // strings would read it as "never decided" and hand keying back to
      // radio1.
      final node = await addRadio();
      expect(cat.designatedFor(kCategoryKey), node.uuid);
      await cat.setDesignated(kCategoryKey, null);

      final reloaded = await makeService();
      addTearDown(reloaded.dispose);
      expect(reloaded.designatedFor(kCategoryKey), isNull);
    });

    test('a station that never decided its key gets its keying radio on load', () async {
      await settings.setExperimentEnabled('keyer', false);
      final node = await addRadio();
      expect(cat.designatedFor(kCategoryKey), isNull, reason: 'off, the experiment designates nothing');
      await settings.setExperimentEnabled('keyer', true);

      final reloaded = await makeService();
      addTearDown(reloaded.dispose);
      expect(reloaded.designatedFor(kCategoryKey), node.uuid);
    });

    test(
      'a keyer device the boot burst could not reach is retried by the slow loop while radio1 is up',
      () => runOnFakeClock((_) async {
        // The trap: a loop that only reads radio1 settles on its first tick
        // when radio1 is connected, and the keyer is never tried again.
        final radio = await addRadio();
        await connectAndLand(radio);
        final keyer = await cat.addNode(typeKey: 'keyer-type', name: 'WK', config: {'host': 'wk.local'});
        expect(cat.designatedFor(kCategoryKey), keyer.uuid);

        final reconnecting = cat.reconnectDesignatedRadio();
        for (var i = 0; i < 60; i++) {
          for (final a in transport.attempts) {
            if (!a.completer.isCompleted) a.completer.completeError(StateError('keyer is off'));
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await pumpEventQueue();
        }
        await reconnecting;

        final keyerAttempts = transport.attempts.where((a) => a.target['host'] == 'wk.local').length;
        expect(keyerAttempts, greaterThan(3), reason: 'the burst is three attempts; anything past it is the loop');
        expect(cat.stateFor(radio.uuid).status, EquipmentStatus.connected, reason: 'radio1 was never touched');
      }),
    );

    test('a keyer disconnected by hand is not brought back by radio1 dropping', () async {
      final radio = await addRadio();
      final connection = await connectAndLand(radio);
      final keyer = await cat.addNode(typeKey: 'keyer-type', name: 'WK', config: {'host': 'wk.local'});
      await connectAndLand(keyer);
      await cat.disconnect(keyer.uuid);
      int keyerAttempts() => transport.attempts.where((a) => a.target['host'] == 'wk.local').length;
      final before = keyerAttempts();

      connection.dropRemotely();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pumpEventQueue();

      expect(keyerAttempts(), before, reason: 'Disconnect must stay disconnected');
      expect(transport.attempts.last.target['host'], 'radio.local', reason: 'radio1 itself is retried');
    });

    test('nothing can key until radio1 is connected through a keyer-capable session', () async {
      expect(cat.canKeyCw, isFalse);
      expect(cat.keyerSpeed, isNull);
      final node = await addRadio();
      expect(cat.canKeyCw, isFalse, reason: 'designated but not connected');
      await connectAndLand(node);
      expect(cat.canKeyCw, isTrue);
      expect(cat.keyerSpeedRange, (min: 5, max: 50));
    });

    test('a connected radio whose protocol has no keyer keys nothing, and says so through canKeyCw', () async {
      // The trap: an `is` check turned into a cast — every keyer surface
      // would crash for the Kenwood/flrig/rigctld operator.
      final node = await cat.addNode(typeKey: 'plain-type', name: 'Plain', config: {'host': 'p.local'});
      await cat.setRadio1(LocalRadio(node.uuid));
      await connectAndLand(node);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected, reason: 'sanity');

      expect(cat.canKeyCw, isFalse);
      expect(cat.keyerSpeed, isNull);
      expect(cat.keyerSpeedRange, isNull);
      expect(cat.cwSending, isFalse);
      expect(() => cat.sendCw('CQ'), returnsNormally);
      expect(() => cat.stopCw(), returnsNormally);
      expect(() => cat.dropQueuedCw(1), returnsNormally);
      expect(cat.setKeyerSpeed(20), isFalse);
      expect(cat.cwProgress.value, isNull);
    });

    test('the key in use is the radio\'s: it follows radio1, and a pick is stored against one radio', () async {
      final first = await addRadio(host: 'a.local');
      expect(cat.designatedFor(kCategoryKey), first.uuid, reason: 'a radio whose CAT keys is its own key');
      // Adding a transceiver makes it radio1, and the key belongs to the
      // radio rather than to the station — so it moves with it. Catches a
      // designation left global: the old rule kept the FIRST keying radio.
      final second = await cat.addNode(typeKey: 'fake-type', name: 'Second', config: {'host': 'b.local'});
      expect(cat.designatedFor(kCategoryKey), second.uuid, reason: 'the key in use is the selected radio\'s');
      await connectAndLand(first);
      await connectAndLand(second);
      log.clear();
      cat.sendCw('CQ');
      expect(log, ['sendCw:CQ']);

      // An explicit pick outranks the radio's own default, and belongs to
      // the radio it was made under — not to the station, and not to the
      // node that was picked.
      await cat.setDesignated(kCategoryKey, first.uuid);
      await cat.setRadio1(LocalRadio(first.uuid));
      expect(cat.designatedFor(kCategoryKey), first.uuid, reason: 'first\'s own default');
      await cat.setRadio1(LocalRadio(second.uuid));
      expect(cat.designatedFor(kCategoryKey), first.uuid, reason: 'second\'s stored pick, not its default');

      // None is an answer, so it outranks the default too — and it is one
      // radio's answer, not the station's.
      await cat.setDesignated(kCategoryKey, null);
      expect(cat.canKeyCw, isFalse, reason: 'no key in use, nothing keys — even with two radios that could');
      await cat.setRadio1(LocalRadio(first.uuid));
      expect(cat.canKeyCw, isTrue, reason: 'None was second\'s answer; first still keys for itself');
    });

    test('switching radio1 stops the outgoing key mid-message', () async {
      final first = await addRadio(host: 'a.local');
      final second = await cat.addNode(typeKey: 'fake-type', name: 'Second', config: {'host': 'b.local'});
      await connectAndLand(first);
      await connectAndLand(second);
      // radio1 — and so the key in use — is `second`, and it is sending.
      // Nothing else on this path stops it: the operator's Stop control
      // reaches for the key in use, which by then is the OTHER radio, so a
      // rig left keying here has no control pointing at it at all.
      driver.sessions.last.cwSending = true;
      log.clear();
      await cat.setRadio1(LocalRadio(first.uuid));
      expect(log, contains('stopCw'), reason: 'the radio being stepped off is told to stop');
      driver.sessions.first.sink.reportKeyerSpeed(30);
      expect(cat.keyerSpeed, 30, reason: 'the speed shown is the new key in use\'s');
    });

    test('adding a rig that takes the VFO stops the one it takes it from', () async {
      // The same debt on a path that never names a key: the newest
      // transceiver takes the VFO, and the picks belong to the radio, so
      // adding a rig mid-message moves the key in use out from under a
      // session that is still sending.
      final first = await addRadio(host: 'a.local');
      await connectAndLand(first);
      driver.sessions.single.cwSending = true;
      log.clear();
      await cat.addNode(typeKey: 'fake-type', name: 'Second', config: {'host': 'b.local'});
      expect(log, contains('stopCw'), reason: 'the rig that just lost the VFO is told to stop');
    });

    test('removing the radio stops a separate keyer that is still sending', () async {
      // The keyer is not the node being removed, so `disconnect` does not
      // reach it — but losing radio1 drops the pick that named it, and a
      // WinKeyer left playing out a message has nothing showing it.
      final radio = await addRadio(host: 'a.local');
      final keyer = await cat.addNode(typeKey: 'keyer-type', name: 'WK', config: {'host': 'wk.local'});
      await connectAndLand(keyer);
      await cat.setDesignated(kCategoryKey, keyer.uuid);
      driver.sessions.single.cwSending = true;
      log.clear();
      await cat.removeNode(radio.uuid);
      expect(log, contains('stopCw'), reason: 'the keyer left behind is told to stop');
    });

    test('a paddle added for the log does not take keying away from a keyer; a keyer added takes over', () async {
      final radio = await addRadio();
      expect(cat.designatedFor(kCategoryKey), radio.uuid);
      await cat.addNode(typeKey: 'key', name: 'Bencher', config: {'morseKeyType': 'DP'});
      expect(cat.designatedFor(kCategoryKey), radio.uuid, reason: 'recording a paddle must not stop the keying');
      // A keyer of its own is what keys from then on — the same rule a new
      // radio1 follows.
      final keyer = await cat.addNode(typeKey: 'keyer-type', name: 'WK', config: {'host': 'wk.local'});
      expect(cat.designatedFor(kCategoryKey), keyer.uuid);
    });

    test('a driver reporting the keyer speed lands in stateFor and keyerSpeed', () async {
      final node = await addRadio();
      await connectAndLand(node);

      driver.sessions.single.sink.reportKeyerSpeed(22);

      expect(cat.stateFor(node.uuid).keyerSpeed, 22);
      expect(cat.keyerSpeed, 22);
    });

    test('an explicit speed set is remembered on the node, for equipment that cannot be asked', () async {
      driver.remembersSpeed = true;
      final node = await addRadio();
      await connectAndLand(node);

      expect(cat.setKeyerSpeed(32), isTrue);
      await pumpEventQueue();

      expect(cat.nodes.firstWhere((n) => n.uuid == node.uuid).config[keyerSpeedConfigKey], 32);
    });

    test('a REPORTED speed is never remembered, so an absent pot cannot write itself to disk', () async {
      // The trap: remembering reports as well as sets. A speed report is
      // also how a pot answers — and on a keyer whose pot is absent, how its
      // floating ADC answers — so storing one hands that reading back on
      // every connect afterwards, permanently.
      driver.remembersSpeed = true;
      final node = await addRadio();
      await connectAndLand(node);

      driver.sessions.single.sink.reportKeyerSpeed(7);
      await pumpEventQueue();

      expect(cat.stateFor(node.uuid).keyerSpeed, 7, reason: 'it is still shown');
      expect(cat.nodes.firstWhere((n) => n.uuid == node.uuid).config[keyerSpeedConfigKey], isNull, reason: 'but never written to the node');
    });

    test('equipment that can be asked its speed stores nothing', () async {
      // A radio reads its own keyer menu, so a copy stored beside it would
      // only go stale against the front panel.
      final node = await addRadio();
      await connectAndLand(node);

      expect(cat.setKeyerSpeed(32), isTrue);
      await pumpEventQueue();

      expect(cat.nodes.firstWhere((n) => n.uuid == node.uuid).config[keyerSpeedConfigKey], isNull);
    });

    test('sendCw and stopCw reach radio1\'s session, and are no-ops without one', () async {
      expect(() => cat.sendCw('CQ'), returnsNormally);
      expect(() => cat.stopCw(), returnsNormally);
      final node = await addRadio();
      await connectAndLand(node);
      log.clear();

      cat.sendCw('CQ CQ');
      cat.stopCw();

      expect(log, ['sendCw:CQ CQ', 'stopCw']);
    });

    test('dropQueuedCw reaches radio1\'s session, and is a no-op without one', () async {
      expect(() => cat.dropQueuedCw(0), returnsNormally);
      final node = await addRadio();
      await connectAndLand(node);
      log.clear();
      cat.dropQueuedCw(7);
      expect(log, ['dropQueuedCw:7']);
    });

    test('setKeyerSpeed says whether anything could take it', () async {
      expect(cat.setKeyerSpeed(20), isFalse, reason: 'the WPM command must report this, not confirm');
      final node = await addRadio();
      await connectAndLand(node);
      log.clear();

      expect(cat.setKeyerSpeed(20), isTrue);
      expect(log, ['setKeyerSpeed:20']);
    });

    test('setKeyerSpeed sends every time, unlike power: the radio never announces a knob turn', () async {
      final node = await addRadio();
      await connectAndLand(node);
      log.clear();

      cat.setKeyerSpeed(20);
      driver.sessions.single.sink.reportKeyerSpeed(20);
      // The operator turned the knob to 30 meanwhile, unseen; asking for 20
      // again must reach the radio rather than be dropped as a repeat.
      cat.setKeyerSpeed(20);
      expect(log, ['setKeyerSpeed:20', 'setKeyerSpeed:20']);
    });

    test('what radio1 is keying reaches cwProgress; another node\'s keying does not', () async {
      final radio1 = await addRadio(host: 'a.local');
      final other = await cat.addNode(typeKey: 'fake-type', name: 'Other', config: {'host': 'b.local'});
      await cat.setRadio1(LocalRadio(radio1.uuid));
      await connectAndLand(radio1);
      await connectAndLand(other);
      final progress = CwSendProgress(id: 1, text: 'CQ', characterEnds: cwCharacterEnds('CQ', 20));

      driver.sessions.last.sink.reportCwProgress(progress);
      expect(cat.cwProgress.value, isNull, reason: 'only the designated radio keys for the app');

      driver.sessions.first.sink.reportCwProgress(progress);
      expect(cat.cwProgress.value, same(progress));

      await cat.disconnect(radio1.uuid);
      expect(cat.cwProgress.value, isNull, reason: 'a message cannot outlive the connection keying it');
    });

    test('refreshKeyerSpeed asks the session again', () async {
      final node = await addRadio();
      await connectAndLand(node);
      log.clear();
      cat.refreshKeyerSpeed();
      expect(log, ['refreshKeyerSpeed']);
    });
  });

  // SO2R: keying follows the set the operator keys FROM, not the one they
  // are looking at. The two traps are opposite: a focus move that stopped
  // radio A's CQ would make the classic run-on-A, search-on-B pattern
  // impossible, and a message key on B that left A sending would put two
  // transmitters on the air from one operator.
  group('SO2R keying', () {
    setUp(() async {
      await settings.setExperimentEnabled('keyer', true);
      await settings.setExperimentEnabled('so2r', true);
    });

    Future<(EquipmentNode, EquipmentNode)> twoRadios() async {
      final a = await addRadio(host: 'a.local');
      final b = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      await cat.setRadio1(LocalRadio(a.uuid));
      await cat.setRadio2(b.uuid);
      await connectAndLand(a);
      await connectAndLand(b);
      return (a, b);
    }

    test('with nothing going out, keying and PTT follow the operator between the sets', () async {
      final (a, b) = await twoRadios();
      cat.noteOperatorRadio('B');
      expect(cat.keyingRadio, 'B');
      expect(cat.keyInUse, b.uuid, reason: 'a message or PTT pressed now goes out on B, and the keyer area shows its speed');
      expect(cat.localKeyingRadio, b.uuid);
      cat.noteOperatorRadio('A');
      expect(cat.keyInUse, a.uuid);
    });

    // The trap: keying moved with the operator mid-CQ, stopping radio A's
    // message the moment they went to work B — the SO2R pattern itself.
    test('a message going out keeps its radio while the operator moves, and keying follows once it ends', () async {
      final (a, b) = await twoRadios();
      driver.sessions.first.cwSending = true;
      log.clear();

      cat.noteOperatorRadio('B');
      expect(log, isNot(contains('stopCw')), reason: "radio A's CQ goes on while the operator works B");
      expect(cat.keyingRadio, 'A', reason: 'the message under way stays where the operator can see and stop it');

      driver.sessions.first.cwSending = false;
      cat.cwProgress.value = const CwSendProgress(id: 1, text: 'CQ', characterEnds: []);
      cat.cwProgress.value = null;
      expect(cat.keyingRadio, 'B', reason: 'the end of the message hands keying to the set the operator is in');
      expect(cat.keyInUse, b.uuid);
    });

    test('a key pressed in the other set stops the message on the radio left, and keys through its own', () async {
      final (a, b) = await twoRadios();
      driver.sessions.first.cwSending = true;
      log.clear();

      cat.noteOperatorRadio('B');
      expect(cat.keyInUse, a.uuid);

      expect(cat.keyForOperator(() => cat.canKeyCw), isTrue);
      expect(log, contains('stopCw'), reason: 'a message key on B is the operator moving on from A');
      expect(cat.keyingRadio, 'B');
      expect(cat.keyInUse, b.uuid, reason: "Radio B keys through its own key — itself, by default");

      cat.noteOperatorRadio('A');
      expect(cat.keyForOperator(() => cat.canKeyCw), isTrue);
      expect(cat.keyInUse, a.uuid);
    });

    // The trap: set B with no Radio B falling back to radio A, so a message
    // keyed for set B's contact goes out on the radio A is running on.
    test('a key in set B with no Radio B keys nothing, and stops nothing', () async {
      final a = await addRadio(host: 'a.local');
      await cat.setRadio1(LocalRadio(a.uuid));
      await connectAndLand(a);
      driver.sessions.first.cwSending = true;
      log.clear();

      cat.noteOperatorRadio('B');
      expect(cat.keyForOperator(() => cat.canKeyCw), isFalse);
      expect(log, isNot(contains('stopCw')), reason: "radio A's CQ is not set B's to stop");
      expect(cat.keyingRadio, 'A');
      expect(cat.canKeyOn('B', () => cat.canKeyCw), isFalse, reason: "set B's Enter Sends Messages asks the same question");
      expect(cat.canKeyOn('A', () => cat.canKeyCw), isTrue);
    });

    // The trap: stopping radio A's CQ before asking whether radio B can key at
    // all — the CQ gone and nothing sent in its place.
    test("a key Radio B can't send leaves radio A's message going out", () async {
      final (a, b) = await twoRadios();
      await cat.setDesignated(kCategoryKey, null, radio: b.uuid);
      driver.sessions.first.cwSending = true;
      log.clear();

      cat.noteOperatorRadio('B');
      expect(cat.keyForOperator(() => cat.canKeyCw), isFalse);
      expect(log, isNot(contains('stopCw')));
      expect(cat.keyingRadio, 'A');
      expect(cat.keyInUse, a.uuid, reason: 'asking about B moved nothing');
    });

    // The trap: a message rendered after its key press keys whichever radio
    // keying has followed the operator to by then — ESM's TU logged on A,
    // sent on B, the moment the operator moves to pounce.
    test('a key press holds its radio until what it keys is sent, and crossing sets drops it', () async {
      await twoRadios();
      final hold = cat.holdKeying();
      cat.noteOperatorRadio('B');
      expect(cat.keyingRadio, 'A', reason: 'the message still rendering is radio A\'s');
      cat.releaseKeying(hold);
      expect(cat.keyingRadio, 'B', reason: 'and keying follows the operator once it is handed over');

      final onB = cat.holdKeying();
      cat.noteOperatorRadio('A');
      expect(cat.keyForOperator(() => cat.canKeyCw), isTrue);
      expect(onB.live, isFalse, reason: "a key in set A stops what radio B had going out, the message still rendering with it");
      expect(cat.keyingRadio, 'A');
    });

    // The trap: Radio B changed under a message it is sending, the key in use
    // moved with nothing told — B keying on with no Escape to stop it.
    test('changing Radio B, or turning SO2R off, stops what Radio B is sending', () async {
      final (_, b) = await twoRadios();
      cat.noteOperatorRadio('B');
      final rendering = cat.holdKeying();
      cat.armKeyerRepeat(delay: const Duration(seconds: 10), text: 'CQ', send: () {});
      driver.sessions.last.cwSending = true;
      log.clear();
      await cat.setRadio2(null);
      expect(log, contains('stopCw'));
      expect(cat.keyingRadio, 'A');
      expect(cat.keyerRepeating, isFalse, reason: "B's CQ repeat must not come back on radio A");
      expect(rendering.live, isFalse, reason: 'nor a message still rendering for B');

      await cat.setRadio2(b.uuid);
      cat.noteOperatorRadio('B');
      expect(cat.keyingRadio, 'B');
      driver.sessions.last.cwSending = true;
      log.clear();
      await settings.setExperimentEnabled('so2r', false);
      expect(log, contains('stopCw'));
      expect(cat.keyingRadio, 'A');
    });

    // The trap: the repeat watching radio A's VFO whichever radio it runs on —
    // pouncing with A cancels B's CQ, and B wandering off keeps it calling.
    test("a CQ repeat on Radio B ends when Radio B's VFO moves, not radio A's", () async {
      await twoRadios();
      radio.setVfo('vfoA', freq: 14025, mode: 'CW');
      radio.setVfo('vfoB', freq: 7025, mode: 'CW');
      cat.noteOperatorRadio('B');
      cat.armKeyerRepeat(delay: const Duration(seconds: 10), text: 'CQ', send: () {});

      radio.setVfo('vfoA', freq: 14030, mode: 'CW');
      expect(cat.keyerRepeating, isTrue, reason: 'radio A tuning is the operator pouncing with it');
      radio.setVfo('vfoB', freq: 7025.02, mode: 'CW');
      expect(cat.keyerRepeating, isTrue, reason: "20 Hz is within the tolerance, measured from where B's CQ went out");
      radio.setVfo('vfoB', freq: 7030, mode: 'CW');
      expect(cat.keyerRepeating, isFalse);
      cat.cancelKeyerRepeat();
    });

    // The trap: the radio left's end-of-play report dropped once keying has
    // moved, the play showing — and keying held busy — for good.
    test('crossing sets mid-play hands the voice indicator to the radio keying', () async {
      final (_, b) = await twoRadios();
      driver.sessions.first.sink.reportVoiceActivity(const VoiceActivity(memory: 1));
      expect(cat.voiceActivity.value?.memory, 1);
      expect(cat.isTransmitting('A'), isTrue, reason: 'a memory playing is radio A on the air');

      cat.noteOperatorRadio('B');
      expect(cat.keyForOperator(() => cat.canKeyCw), isTrue);
      expect(cat.voiceActivity.value, isNull, reason: 'radio B is playing nothing');
      driver.sessions.first.sink.reportVoiceActivity(null);
      cat.noteOperatorRadio('A');
      expect(cat.keyingRadio, 'A', reason: 'nothing left busy holds keying on B');
      expect(cat.designatedFor(kCategoryKey, radio: b.uuid), b.uuid);
    });

    // The trap: keying idle in the gap between a sequence's memories — the
    // next one asked for and not yet heard starting — so it follows the
    // operator to B, and the memory plays on A with nothing showing it and
    // no Escape to stop it.
    test('a memory asked for and not yet heard starting keeps keying on its radio', () async {
      await twoRadios();
      final a = driver.sessions.first;
      cat.playVoiceSequence([2, 3]);
      a.sink.reportVoiceActivity(const VoiceActivity(memory: 2));
      cat.noteOperatorRadio('B');
      log.clear();

      a.sink.reportVoiceActivity(null);
      expect(log, contains('playVoice:3'), reason: 'sanity: the sequence went on to its next memory');
      expect(cat.keyingRadio, 'A', reason: 'memory 3 is on its way out on radio A');
      a.sink.reportVoiceActivity(const VoiceActivity(memory: 3));
      expect(cat.voiceActivity.value?.memory, 3, reason: 'and shows, where Escape reaches it');
      a.sink.reportVoiceActivity(null);
      expect(cat.keyingRadio, 'B', reason: 'keying follows once the sequence is over');
    });

    test('turning SO2R on connects Radio B', () async {
      await settings.setExperimentEnabled('so2r', false);
      final a = await addRadio(host: 'a.local');
      final b = await cat.addNode(typeKey: 'fake-type', name: 'Right Radio', config: {'host': 'b.local'});
      await cat.setRadio1(LocalRadio(a.uuid));
      await cat.setRadio2(b.uuid);
      expect(cat.stateFor(b.uuid).status, isNot(EquipmentStatus.connected), reason: 'sanity');

      await settings.setExperimentEnabled('so2r', true);
      await pumpEventQueue();
      expect(cat.stateFor(b.uuid).status, isIn([EquipmentStatus.connecting, EquipmentStatus.connected]));
    });

    // The trap: a surface showing the ESM switch handing back radio A's Run or
    // S&P while the operator is in set B, which files it under B.
    test("the ESM switch shows the operator's radio's Run or S&P, and hands it back unchanged", () async {
      await twoRadios();
      cat.noteOperatorRadio('B');
      expect(cat.operatorEnterSends.running, isFalse, reason: "radio B's S&P, not radio A's Run");
      final shown = cat.operatorEnterSends;
      cat.setEnterSends(on: !shown.on, running: shown.running);
      expect(cat.isRunning('B'), isFalse);
      expect(cat.isRunning('A'), isTrue);
    });

    // The trap: one set of voice memory labels and lengths for both radios,
    // so timing B's memory 1 paces A's bar against a different recording.
    test("each radio's voice memories are named and timed apart", () async {
      await twoRadios();
      await settings.setVoiceMessageLabel(1, 'CQ A');
      await settings.setVoiceMessageLabel(1, 'CQ B', radio: 'B');
      await settings.setVoiceMessageDuration(1, 4000, radio: 'B');
      expect(cat.voiceMessageLabel(1), 'CQ A');
      expect(cat.voiceMessageDuration(1), 0);
      cat.noteOperatorRadio('B');
      expect(cat.voiceMessageLabel(1), 'CQ B');
      expect(cat.voiceMessageDuration(1), 4000);
      await cat.setVoiceMessageLabel(1, 'CQ CONTEST');
      expect(settings.voiceMessageLabel(1, radio: 'B'), 'CQ CONTEST');
      expect(settings.voiceMessageLabel(1), 'CQ A');
    });

    // The trap: one app-wide Run / S&P, so the operator running A and
    // pouncing with B has ESM sending the wrong half of the exchange on one.
    test("each radio has its own Run / S&P, and ESM's Run / S&P keys set the operator's radio's", () async {
      expect(cat.isRunning('A'), isTrue, reason: 'radio A runs by default');
      expect(cat.isRunning('B'), isFalse, reason: 'radio B pounces by default');

      cat.noteOperatorRadio('B');
      cat.setEnterSends(running: true);
      expect(cat.isRunning('B'), isTrue);
      cat.noteOperatorRadio('A');
      cat.setEnterSends(running: false);
      expect(cat.isRunning('A'), isFalse);
      expect(cat.isRunning('B'), isTrue, reason: "radio A's change leaves B's alone");
      expect(settings.enterSendsRunningB, isTrue, reason: "radio B's is kept across restarts, as A's is");

      await settings.setExperimentEnabled('so2r', false);
      cat.noteOperatorRadio('B');
      cat.setEnterSends(running: true);
      expect(cat.isRunning('A'), isTrue, reason: 'outside SO2R there is only the one Run / S&P');
    });

    test('each radio is on the air only while it is keying', () async {
      await twoRadios();
      cat.noteOperatorRadio('B');
      expect(cat.isTransmitting('A'), isFalse);
      expect(cat.isTransmitting('B'), isFalse);
      driver.sessions.last.cwSending = true;
      expect(cat.isTransmitting('B'), isTrue);
      expect(cat.isTransmitting('A'), isFalse, reason: "B's message is not A's transmission");
    });

    test("Radio B's key pick is its own, and leaves radio A's alone", () async {
      final (a, b) = await twoRadios();
      await cat.setDesignated(kCategoryKey, a.uuid, radio: b.uuid);

      expect(cat.designatedFor(kCategoryKey, radio: b.uuid), a.uuid);
      expect(cat.designatedFor(kCategoryKey), a.uuid, reason: "radio A's own default, untouched");
      cat.noteOperatorRadio('B');
      expect(cat.keyForOperator(() => cat.canKeyCw), isTrue);
      expect(cat.keyInUse, a.uuid, reason: "B's pick, now that keying is B's");
      await cat.setDesignated(kCategoryKey, null, radio: b.uuid);
      expect(cat.canKeyCw, isFalse, reason: "None was B's answer");
      expect(cat.designatedFor(kCategoryKey), a.uuid, reason: "and only B's");
    });
  });

  group('power', () {
    test('a driver reporting power lands in stateFor, once merged into state', () async {
      final node = await addRadio();
      await connectAndLand(node);

      driver.sessions.single.sink.reportPower(75);

      expect(cat.stateFor(node.uuid).power, 75);
    });

    test('setPower reaches radio1\'s session, and no other', () async {
      final radio1 = await addRadio(host: 'a.local');
      final other = await cat.addNode(typeKey: 'fake-type', name: 'Other', config: {'host': 'b.local'});
      await cat.setRadio1(LocalRadio(radio1.uuid));
      await connectAndLand(radio1);
      // `other` is deliberately never connected — setPower must not reach
      // into an unconnected node's absent session either.
      log.clear();

      cat.setPower(100);

      expect(log, contains('setPower:100'));
      expect(other.uuid, isNot(radio1.uuid), reason: 'sanity: two distinct nodes exist');
    });

    test('setPower with no radio1 designated is a no-op, not a throw', () async {
      expect(() => cat.setPower(100), returnsNormally);
    });

    test('setPower with radio1 designated but not connected is a no-op', () async {
      final node = await addRadio();
      // Never connected — no session exists yet.
      expect(() => cat.setPower(100), returnsNormally);
      expect(driver.sessions, isEmpty);
      expect(node.uuid, isNotEmpty);
    });

    test('displayedPower prefers the connected radio\'s live reading over the stated power', () async {
      final node = await addRadio();
      await connectAndLand(node);
      radio.setVfo('vfoA', power: 50);
      driver.sessions.single.sink.reportPower(75);

      expect(cat.displayedPower, 75);
    });

    test('displayedPower falls back to the operator\'s stated power with no live reading', () async {
      // Vfo.power, not SettingsService.currentPower: the pre-VFO key is
      // migrated onto the VFO at startup and never read here, or the
      // surfaces that read Vfo.power directly would show nothing while this
      // showed 50.
      radio.setVfo('vfoA', power: 50);

      expect(cat.displayedPower, 50);
    });

    test('displayedPower falls back to the stated power when radio1 is not connected', () async {
      await addRadio();
      radio.setVfo('vfoA', power: 50);
      // Never connected — no reading has ever landed in stateFor.

      expect(cat.displayedPower, 50);
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

    test('a stationEquipment pref of the wrong type reads as no equipment', () async {
      // Nothing validates what lands in a preferences file, and the plugin's
      // getString is a CAST over its cache — so a number here throws a
      // TypeError, not a null. _load() runs inside CatService's constructor,
      // which is built during boot: an escape from here ends the launch.
      SharedPreferences.setMockInitialValues({'stationEquipment': 5});
      final reloaded = await makeService();
      expect(reloaded.nodes, isEmpty);
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

    test('CW-R from the radio lands in state as CW — reverse sideband is not a mode of its own', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);

      connection.push('14074 CW-R\n');
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(freqKHz: 14074, mode: 'CW'));
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
      // Nothing to translate for an unrecognized cause, so no separate
      // detail — the row's own text already IS the raw message.
      expect(cat.stateFor(node.uuid).errorDetail, isNull);
    });

    test('a timed-out connect shows the translated reason, keeping the raw one for reports', () async {
      final node = await addRadio(host: 'secret-host.invalid');
      final connecting = cat.connect(node.uuid);
      await pumpEventQueue();
      transport.attempts.single.completer.completeError(TimeoutException('no reply from secret-host.invalid'));
      await connecting;

      final state = cat.stateFor(node.uuid);
      expect(state.status, EquipmentStatus.error);
      expect(state.error, t.settings.station.connectFailedTimeout);
      expect(state.errorDetail, contains('secret-host'));
    });

    test('an unreachable connect shows the translated reason, keeping the raw one for reports', () async {
      final node = await addRadio(host: 'secret-host.invalid');
      const socketError = SocketException('No route to host', osError: OSError('No route to host', 65));
      final connecting = cat.connect(node.uuid);
      await pumpEventQueue();
      transport.attempts.single.completer.completeError(socketError);
      await connecting;

      final state = cat.stateFor(node.uuid);
      expect(state.status, EquipmentStatus.error);
      expect(state.error, t.settings.station.connectFailedNetwork);
      expect(state.errorDetail, socketError.toString());
    });

    /// Fails a connect with a serial problem of [failure] and answers the row.
    Future<EquipmentState> failSerial(SerialFailure failure) async {
      final node = await addRadio();
      final connecting = cat.connect(node.uuid);
      await pumpEventQueue();
      transport.attempts.single.completer.completeError(_FakeSerialProblem(failure));
      await connecting;
      return cat.stateFor(node.uuid);
    }

    test('an unplugged serial port says the device is missing, not what POSIX called it', () async {
      // "Could not open /dev/cu.usbserial-FTB6SPL3: No such file or
      // directory" names a path the operator never typed and an errno they
      // cannot act on.
      final state = await failSerial(SerialFailure.missing);
      expect(state.status, EquipmentStatus.error);
      expect(state.error, t.settings.station.connectFailedDevice);
      expect(state.error, isNot(contains('/dev/')));
      // The path survives where a developer reads it, and only there.
      expect(state.errorDetail, contains('/dev/cu.usbserial-FTB6SPL3'));
    });

    test('a port another program holds says so, rather than sending the operator to the cable', () async {
      // The trap this exists to catch: one message for every serial failure.
      // WSJT-X, fldigi or rigctld holding the port is the commonest of them,
      // and "Device not found" sends the operator to check a cable that is
      // plugged in and working.
      final state = await failSerial(SerialFailure.busy);
      expect(state.error, t.settings.station.connectFailedBusy);
      expect(state.error, isNot(t.settings.station.connectFailedDevice));
    });

    test('a port the OS refuses says that, not that the device is absent', () async {
      // A macOS sandbox without the device.serial entitlement, or a revoked
      // Web Serial grant: the device is right there, and re-seating the cable
      // does nothing at all for it.
      final state = await failSerial(SerialFailure.denied);
      expect(state.error, t.settings.station.connectFailedDenied);
      expect(state.error, isNot(t.settings.station.connectFailedDevice));
    });

    test('a port refused over its control lines says what to do, not which line', () async {
      // Another program's hardware handshake is the likely cause, and the
      // cure is at the cable; "RTS did not go low as set" names neither.
      final state = await failSerial(SerialFailure.lines);
      expect(state.error, t.settings.station.connectFailedLines);
      expect(state.errorDetail, contains('/dev/cu.usbserial-FTB6SPL3'), reason: 'the raw words stay for a report');
    });

    test('a serial failure the transport could not place keeps its own words', () async {
      // Translating an unrecognized cause into one of the three above would
      // be a guess, and a confident one — the raw text at least describes
      // what happened.
      final state = await failSerial(SerialFailure.other);
      expect(state.error, contains('/dev/cu.usbserial-FTB6SPL3'));
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

    // The silence watchdog used to be fed by VfoReadings alone. Equipment
    // with no VFO to report — an antenna switch — therefore went stale 30 s
    // after every connect however healthy it was, and the row read "Not
    // Responding" over a working socket. Invisible while this layer held
    // only radios.
    test(
      'equipment with no VFO stays alive on the reports it does make',
      () => runOnFakeClock((_) async {
        final node = await addRadio();
        await connectAndLand(node);
        final session = driver.sessions.single;

        // Wait out this service's (deliberately tiny) silence window.
        await Future.delayed(const Duration(milliseconds: 60));
        expect(cat.stateFor(node.uuid).stale, isTrue, reason: 'nothing has been reported since connect');

        session.reportSwitchState();
        expect(cat.stateFor(node.uuid).stale, isFalse, reason: 'the switch just spoke');
      }),
    );

    test('a stale connection closing does not clobber the live one', () async {
      final node = await addRadio();
      final stale = await connectAndLand(node);
      final live = await connectAndLand(node);

      // The old socket's close callback arrives late.
      stale.dropRemotely();
      await pumpEventQueue();

      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected, reason: 'the live connection is still up');

      // Dropping the live one now starts a reconnect, because this node is
      // radio1 — so it does NOT settle on `disconnected`. What this test is
      // for is the assertion above: a late close from a superseded socket
      // must not clobber the connection that replaced it.
      live.dropRemotely();
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).status, isNot(EquipmentStatus.connected), reason: 'the live connection really did go away');
    });

    test('a stale session cannot write state', () async {
      final node = await addRadio();
      await connectAndLand(node);
      final staleSession = driver.sessions.single;
      await connectAndLand(node);

      // The old session's poll timer fires once more before it's collected.
      staleSession.reportFromItsOwnTimer(const VfoReading(freqKHz: 7123, mode: 'LSB'));
      await pumpEventQueue();
      expect(cat.stateFor(node.uuid).vfo, const VfoReading(), reason: 'a superseded session must not report readings');
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

  group('a launch that died connecting', () {
    // HALO-525. The serial open is synchronous FFI on the isolate that pumps
    // the UI, so a wedged port does not fail — it stops the launch dead, with
    // no window and nothing reported, and the launch after it makes the same
    // call for the same reason. The mark on disk is the only evidence that
    // survives a process which never gets to say anything, and it is evidence
    // only if it is written BEFORE the call that may never return.

    const heldUuid = 'held-uuid';

    /// A service that boots from stored settings, optionally carrying marks a
    /// previous launch left behind.
    Future<CatService> relaunch({List<String> marks = const [], _RefusingWritesStore? refusing}) async {
      SharedPreferences.setMockInitialValues({
        'stationEquipment': jsonEncode({
          'version': 1,
          'radio1': heldUuid,
          'nodes': {
            heldUuid: {
              'typeKey': 'fake-type',
              'name': 'Left Radio',
              'config': {'host': 'a.local'},
            },
          },
        }),
        if (marks.isNotEmpty) autoConnectInFlightKey: marks,
      });
      // Between the mock values and the instance that reads them: the store
      // this wraps is the one `setMockInitialValues` just installed.
      if (refusing != null) {
        refusing.inner = SharedPreferencesStorePlatform.instance;
        SharedPreferencesStorePlatform.instance = refusing;
        SharedPreferences.resetStatic();
      }
      // The idle loop is nothing this group asserts on, and every assertion
      // below is taken after a burst has been left to schedule one — see
      // [idleRetryQuiet].
      final service = await makeService(idleRetryFirst: idleRetryQuiet);
      addTearDown(service.dispose);
      return service;
    }

    Future<void> failEveryAttempt() async {
      for (var i = 0; i < 10; i++) {
        for (final attempt in transport.attempts) {
          if (!attempt.completer.isCompleted) attempt.completer.completeError(StateError('radio is off'));
        }
        await pumpEventQueue();
      }
    }

    test('the attempt is on disk while the connect is still in flight', () async {
      final service = await relaunch();
      final prefs = await SharedPreferences.getInstance();

      final burst = service.reconnectDesignatedRadio();
      await pumpEventQueue();

      // The transport has been asked and has not answered: this is the exact
      // shape of the launch that hangs, and the only moment the mark can be
      // checked for. Marking after the connect returns would be no mark at all.
      expect(transport.attempts, isNotEmpty, reason: 'nothing was attempted, so nothing here is being asserted');
      expect(prefs.getStringList(autoConnectInFlightKey), [heldUuid]);

      await failEveryAttempt();
      await burst;
    });

    test('an attempt that comes back clears its own mark', () async {
      final service = await relaunch();
      final prefs = await SharedPreferences.getInstance();

      final burst = service.reconnectDesignatedRadio();
      await pumpEventQueue();
      await failEveryAttempt();
      await burst;

      expect(
        prefs.getStringList(autoConnectInFlightKey),
        isNull,
        reason: 'a radio that is merely switched off would hold itself off every launch after this one',
      );
    });

    test('the node the last launch was holding is left alone, and says why', () async {
      final service = await relaunch(marks: [heldUuid]);

      await service.reconnectDesignatedRadio();
      await pumpEventQueue();

      expect(transport.attempts, isEmpty, reason: 'the launch repeated the very call the previous one did not come back from');
      expect(service.stateFor(heldUuid).status, EquipmentStatus.error);
      expect(
        service.stateFor(heldUuid).error,
        t.settings.station.autoConnectHeld,
        reason: 'a radio that is simply absent from the panel, with no reason given, is the worse bug',
      );
      expect(service.autoConnectHeldNodes.single.uuid, heldUuid, reason: 'boot has nothing to name in its notice');
    });

    test('a second attempt on the same node does not erase the first one\'s mark', () async {
      // The mark is one bit per node, and two automatic attempts on one node
      // overlap easily: `_connect` sets `connecting` only after an await or
      // two, so the guards that read that status let a second in. If the loser
      // clears the mark on its way out, the attempt still inside the call —
      // the one that can wedge — is unmarked, and the next launch repeats it.
      final service = await relaunch();
      final prefs = await SharedPreferences.getInstance();

      // Back to back, with no pump between them: the window is `_connect`'s
      // own async prefix, before it sets `connecting` for the status guards to
      // see.
      final first = service.reconnectDesignatedRadio();
      final second = service.reconnectDesignatedRadio();
      await pumpEventQueue();
      expect(transport.attempts, hasLength(greaterThan(1)), reason: 'the two attempts did not overlap');
      expect(prefs.getStringList(autoConnectInFlightKey), [heldUuid]);

      // The first attempt loses and returns; the second is still in there.
      transport.attempts.first.completer.completeError(StateError('superseded'));
      await pumpEventQueue();
      expect(prefs.getStringList(autoConnectInFlightKey), [heldUuid], reason: 'the attempt that returned erased the mark of the one still inside the call');

      await failEveryAttempt();
      await first;
      await second;
      expect(prefs.getStringList(autoConnectInFlightKey), isNull);
    });

    test('a preferences write that fails does not take the reconnect down with it', () async {
      // `_connect` answers with an outcome and never throws, and the retry
      // ladder is built on that: it reschedules itself from a `.then` with no
      // catchError. An exception escaping the mark write would skip it, and the
      // designated radio would never be tried again for the whole session —
      // with nothing on the row and nothing in a report to say why. Which would
      // be a worse bug than the one the mark prevents.
      final original = SharedPreferencesStorePlatform.instance;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      final refusing = _RefusingWritesStore();
      final service = await relaunch(refusing: refusing);
      refusing.refuse = true;

      // The assertion is `await burst` returning at all: an exception out of
      // the mark write would escape here instead.
      final burst = service.reconnectDesignatedRadio();
      await pumpEventQueue();
      expect(transport.attempts, isNotEmpty, reason: 'a failed breadcrumb stopped the connect itself');
      await failEveryAttempt();
      await burst;

      expect(service.stateFor(heldUuid).status, EquipmentStatus.error, reason: 'the node ended in a state nothing describes');
    });

    test('a Connect the operator pressed lifts the hold, this launch and the next', () async {
      final service = await relaunch(marks: [heldUuid]);
      final prefs = await SharedPreferences.getInstance();

      final connecting = service.connect(heldUuid);
      await pumpEventQueue();
      expect(transport.attempts, hasLength(1), reason: 'the hold blocked the deliberate act that is meant to be the way out of it');
      transport.attempts.last.completer.complete(_FakeConnection('c1', log));
      await connecting;

      expect(service.autoConnectHeldNodes, isEmpty);
      expect(prefs.getStringList(autoConnectInFlightKey), isNull, reason: 'the hold outlived the Connect that lifted it, and comes back on the next launch');
    });
  });

  group('a radio with no address yet', () {
    // A transport that reads a blank host as unconfigured, as the real ones
    // read a blank port or host — the shared fake keeps the old blank-host
    // error, which one test above still pins.
    late _BlankableTransport usb;
    late _BlankableTransport wifi;
    late CatService bare;

    setUp(() async {
      usb = _BlankableTransport('usb');
      wifi = _BlankableTransport('wifi');
      bare = CatService(
        settings,
        radio: radio,
        registry: EquipmentRegistry(
          models: [
            EquipmentModel(
              key: 'bare',
              category: kCategoryTransceiver,
              name: () => 'Bare Radio',
              variants: [
                EquipmentVariant(key: 'bare-usb', driver: _ModesDriver(log), transport: usb, defaultConfig: const {'host': ''}),
                EquipmentVariant(key: 'bare-wifi', driver: _ModesDriver(log), transport: wifi, defaultConfig: const {'host': ''}),
              ],
            ),
          ],
          transports: {'usb': usb, 'wifi': wifi},
        ),
        reconnectDelay: Duration.zero,
        idleRetryFirst: idleRetryQuiet,
      );
      addTearDown(bare.dispose);
    });

    test('clearing the address of a connected radio takes its session down, not just its label', () async {
      // Without the teardown the row says disconnected while the session
      // underneath is still up, and an attempt in flight lands afterwards.
      final node = await bare.addNode(typeKey: 'bare-usb', name: 'Rig', config: {'host': 'rig.local'});
      await bare.setRadio1(LocalRadio(node.uuid));
      final connecting = bare.connect(node.uuid);
      await pumpEventQueue();
      final connection = _FakeConnection('c1', log);
      usb.attempts.last.completer.complete(connection);
      await connecting;
      expect(bare.stateFor(node.uuid).status, EquipmentStatus.connected);

      await bare.updateNode(node.copyWith(config: {'host': ''}));
      await bare.connect(node.uuid);
      expect(bare.stateFor(node.uuid).status, EquipmentStatus.disconnected);
      await connection.closed.timeout(const Duration(seconds: 1));
    });

    test('given an address on another connection, the main radio is tried at once', () async {
      // Re-typing disconnects on purpose; for a radio that never connected
      // that mark must not stop the first real attempt.
      final node = await bare.addNode(typeKey: 'bare-usb', name: 'Rig', config: {'host': ''});
      await bare.setRadio1(LocalRadio(node.uuid));
      await bare.connect(node.uuid);
      expect(usb.attempts, isEmpty, reason: 'nothing to open');

      await bare.updateNode(node.copyWith(typeKey: 'bare-wifi', config: {'host': 'rig.local'}));
      await pumpEventQueue();
      expect(wifi.attempts, hasLength(1));
    });

    test('a radio the app does not keep connected is left alone when it gets an address', () async {
      final main = await bare.addNode(typeKey: 'bare-usb', name: 'Main', config: {'host': ''});
      final other = await bare.addNode(typeKey: 'bare-usb', name: 'Other', config: {'host': ''});
      await bare.setRadio1(LocalRadio(main.uuid));
      await bare.setDesignated(kCategoryKey, null);

      await bare.updateNode(other.copyWith(config: {'host': 'other.local'}));
      await pumpEventQueue();
      expect(usb.attempts, isEmpty, reason: 'only the main radio and the keyer are the app\'s to connect');
    });

    test('the Radio Mode picker leaves out CW-R, which the app reads back as CW', () async {
      final node = await bare.addNode(typeKey: 'bare-usb', name: 'Rig', config: {'host': 'rig.local'});
      await bare.setRadio1(LocalRadio(node.uuid));
      final connecting = bare.connect(node.uuid);
      await pumpEventQueue();
      usb.attempts.last.completer.complete(_FakeConnection('c1', log));
      await connecting;
      expect(bare.radio1SettableModes, ['CW'], reason: 'the driver offers CW and CW-R');
    });
  });

  group('an extension\'s raw command', () {
    List<int> ascii(String text) => utf8.encode(text);
    String? text(({String? refused, List<int>? reply}) result) => result.reply == null ? null : utf8.decode(result.reply!);

    test('reaches only a connected radio whose driver takes raw commands', () async {
      // Written beside a driver that does not queue them, a raw command's
      // answer would be read as the answer to the driver's own question.
      final node = await addRadio();
      expect((await cat.sendNodeRaw(node.uuid, ascii('FA;'))).refused, 'disconnected');
      final connection = await connectAndLand(node);
      final result = await cat.sendNodeRaw(node.uuid, ascii('TX1;'));
      expect(result.refused, isNull);
      expect(result.reply, isNull, reason: 'no window asked for, none waited for');
      expect(connection.sent.last, 'TX1;');

      final plain = await cat.addNode(typeKey: 'plain-type', name: 'Plain', config: {'host': 'plain.local'});
      final plainConnection = await connectAndLand(plain);
      expect((await cat.sendNodeRaw(plain.uuid, ascii('FA;'))).refused, 'unsupported');
      expect(plainConnection.sent, isEmpty);
    });

    test('written as given, answers what arrived within its window, cut after the first terminator', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);
      final sending = cat.sendNodeRaw(node.uuid, ascii('FA;'), reply: const Duration(seconds: 2), until: ascii(';'));
      await pumpEventQueue();
      // Split across reads, as a serial port delivers it.
      connection.push('FA0142');
      connection.push('50000;MD2;');
      expect(text(await sending), 'FA014250000;');
    });

    test('written as given and with no terminator, keeps everything the radio sent until the window closes', () async {
      // No protocol says which bytes answer a command the driver never sent:
      // the answers to its own polls are in there too, and are not dropped.
      final node = await addRadio();
      final connection = await connectAndLand(node);
      final sending = cat.sendNodeRaw(node.uuid, ascii('X'), reply: const Duration(milliseconds: 50));
      await pumpEventQueue();
      connection.push('14074 USB\n');
      connection.push('ok');
      expect(text(await sending), '14074 USB\nok');
      expect(cat.stateFor(node.uuid).vfo.freqKHz, 14074, reason: 'the driver still parses what the radio said');
    });

    test('ends with its connection: the next one\'s traffic is not its reply', () async {
      final node = await addRadio();
      final first = await connectAndLand(node);
      final sending = cat.sendNodeRaw(node.uuid, ascii('X'), reply: const Duration(milliseconds: 200));
      await pumpEventQueue();
      first.push('a');
      await pumpEventQueue();
      await cat.disconnect(node.uuid);
      final second = await connectAndLand(node);
      second.push('b');
      expect(text(await sending), 'a');
    });

    test('keeps no more of a streaming radio\'s traffic than its cap', () async {
      final node = await addRadio();
      final connection = await connectAndLand(node);
      final sending = cat.sendNodeRaw(node.uuid, ascii('X'), reply: const Duration(seconds: 2));
      await pumpEventQueue();
      final sweep = 'x' * 1000;
      for (var i = 0; i * 1000 <= rawReplyMaxBytes; i++) {
        connection.push(sweep);
      }
      expect((await sending).reply, hasLength(rawReplyMaxBytes), reason: 'and answered at the cap, not at the window');
    });

    test('queued by its driver, answers with its own answers alone, once each command has one', () async {
      final node = await cat.addNode(typeKey: 'queued-type', name: 'Icom', config: {'host': 'icom.local'});
      final connection = await connectAndLand(node);
      final sending = cat.sendNodeRaw(node.uuid, ascii('one\ntwo'), reply: const Duration(seconds: 2));
      await pumpEventQueue();
      final session = queued.sessions.last;
      expect(session.raw, ['one', 'two']);
      connection.push('14074 USB\n');
      session.answer(0, 'A1;');
      session.answer(1, 'A2;');
      expect(text(await sending), 'A1;A2;', reason: 'not the poll answer that came between');
    });

    test('queued by its driver and not all answered in time, keeps the answers that came', () async {
      final node = await cat.addNode(typeKey: 'queued-type', name: 'Icom', config: {'host': 'icom.local'});
      await connectAndLand(node);
      final sending = cat.sendNodeRaw(node.uuid, ascii('one\ntwo'), reply: const Duration(milliseconds: 50));
      await pumpEventQueue();
      queued.sessions.last.answer(0, 'A1;');
      expect(text(await sending), 'A1;');
    });

    test('that its driver cannot send is refused, rather than written as something else', () async {
      final node = await cat.addNode(typeKey: 'queued-type', name: 'Icom', config: {'host': 'icom.local'});
      await connectAndLand(node);
      expect((await cat.sendNodeRaw(node.uuid, ascii('one\nbad'))).refused, 'invalid');
      expect(queued.sessions.last.raw, isEmpty);
    });
  });
}

/// Stands in for either transport's `SerialPortUnavailable`: the classifier
/// tests for `SerialPortProblem`, which is the whole point of that type
/// living in transport.dart rather than beside either transport.
class _FakeSerialProblem implements SerialPortProblem {
  @override
  final SerialFailure failure;

  const _FakeSerialProblem(this.failure);

  @override
  String toString() => 'Could not open /dev/cu.usbserial-FTB6SPL3: No such file or directory';
}

class _BlankableTransport extends _FakeTransport {
  _BlankableTransport(String key) : super(transportKey: key);

  @override
  bool isUnconfigured(Map<String, dynamic> config) => (config['host'] as String? ?? '').trim().isEmpty;
}

class _ModesDriver extends _FakeDriver {
  _ModesDriver(super.log);

  @override
  List<String> settableModes(Map<String, dynamic> config) => const ['CW', 'CW-R'];
}

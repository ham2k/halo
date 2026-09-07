// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Smart VFO Snap: the rules (vfo_snap.dart) and the wiring that applies
// them to the designated radio (cat_service.dart).
//
// The trap this whole feature has to avoid is fighting the operator. Most of
// what's asserted here is a refusal to move the radio: fine tuning, CW, a
// typed frequency, a snap that would cross a band edge. The snapping itself
// is the easy half.

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/vfo_snap.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_secure_storage.dart';

final _t0 = DateTime.utc(2026, 1, 1, 12);

/// Feeds a whole knob turn to a snapper and settles it: [steps] frequencies,
/// [stepGap] apart, starting from a resting [from]. The default gap is an
/// unhurried turn — comfortably above the default speed floor, so a test only
/// meets that rule when it sets out to.
double? _turn(
  double from,
  List<double> steps, {
  Duration stepGap = const Duration(milliseconds: 200),
  VfoSnapTuning tuning = const VfoSnapTuning(),
}) {
  final snapper = VfoSnapper()..rebase(from);
  var at = _t0;
  for (final step in steps) {
    at = at.add(stepGap);
    snapper.report(step, at);
  }
  return snapper.settle(tuning);
}

/// A knob turn covering [distanceKHz] in [over], reported every 20 ms — the
/// rate a streaming radio (FlexRadio, flrig) reports a moving VFO at.
double? _sweep(double from, double distanceKHz,
    {required Duration over, VfoSnapTuning tuning = const VfoSnapTuning()}) {
  const tick = Duration(milliseconds: 20);
  final ticks = over.inMilliseconds ~/ tick.inMilliseconds;
  return _turn(from, [
    for (var i = 1; i <= ticks; i++) from + distanceKHz * i / ticks,
  ], stepGap: tick, tuning: tuning);
}

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

class _FakeTransport extends EquipmentTransport {
  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async =>
      _FakeConnection();
}

class _FakeSession implements TransceiverSession {
  final EquipmentSink sink;
  final List<String> commands = [];

  /// Null is a session that pushes (FlexRadio); a duration is one that polls
  /// at that cadence. Mutable because AdaptivePoller's is, and because the
  /// manager is supposed to read it fresh each time it arms.
  @override
  Duration? expectedUpdateInterval;

  _FakeSession(this.sink);

  void radioReports({double? freqKHz, String? mode}) => sink.report(VfoReading(freqKHz: freqKHz, mode: mode));

  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void setFrequency(double freqKHz) => commands.add('freq:$freqKHz');
  @override
  void setMode(String mode) => commands.add('mode:$mode');
  @override
  void setPower(num watts) => commands.add('power:$watts');
  @override
  void teardown() {}
}

class _FakeDriver extends EquipmentDriver {
  final sessions = <_FakeSession>[];

  @override
  String get key => 'fake-driver';
  @override
  String get name => 'Fake Radio';
  @override
  bool get hardwareVerified => false;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
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
        EquipmentVariant(key: 'fake-type', driver: driver, transport: transport),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VfoSnapper', () {
    test('a long sweep across the band lands on a whole kHz', () {
      // 14260 -> 14285.4 is hunting for a clear slot, not tuning a signal.
      expect(_turn(14260, [14270, 14280, 14285.4]), 14285.0);
    });

    test('a long move stays a long move however slowly it ended', () {
      // The trap: measuring speed over the whole burst and letting a low
      // average demote the grid. Easing in over the last two seconds is how
      // anyone lands on a signal after a sweep — 2.4 kHz covered, and the
      // average speed is under the floor, but this is still an arrival.
      expect(
        _sweep(14260.0, 2.4, over: const Duration(seconds: 6)),
        14262.0,
        reason: 'the long-move rule is checked before the speed floor',
      );
    });

    test('half a long move lands on the quarter-kHz grid', () {
      expect(_turn(14285, [14286.3, 14286.7]), 14286.75);
      expect(_turn(14285, [14286.3, 14286.4]), 14286.5);
    });

    test('a few hundred Hz lands on the nearest hundred', () {
      expect(_turn(14285, [14285.43]), 14285.4);
    });

    test('fine tuning is left alone, at any speed', () {
      // 120 Hz in 20 ms is 6 kHz/s — well clear of the speed floor — and
      // snapping it would move the operator off the voice they were just
      // zero-beating. Distance decides this one alone.
      expect(_turn(14285.0, [14285.06, 14285.12], stepGap: const Duration(milliseconds: 20)), isNull);
      expect(_turn(14285.0, [14285.05, 14285.12, 14285.18]), isNull);
    });

    test('a short move made slowly is left alone', () {
      // 600 Hz over four seconds is someone placing the VFO exactly, not
      // someone arriving somewhere. Far enough to clear the smallest-move
      // rule, so the speed floor is the only thing refusing it.
      expect(_sweep(14285.0, 0.61, over: const Duration(seconds: 4)), isNull);
      // The same distance covered briskly is an arrival, and does snap.
      expect(_sweep(14285.0, 0.61, over: const Duration(milliseconds: 300)), 14285.6);
    });

    test('a single reading measures no speed rather than a slow one', () {
      // A polled radio (FT-891, CI-V) reports a whole knob turn as one jump,
      // so no speed can be derived. Treating that as zero would put every
      // such radio permanently under the floor and turn the feature off on
      // hardware that has no way to report any faster.
      expect(_turn(14285.0, [14285.43]), 14285.4);
    });

    test('the thresholds are the operator\'s to move', () {
      // 1.2 kHz: a long move under a 1 kHz setting, an ordinary one under the
      // 2 kHz default. Same movement, different answer — which is the whole
      // point of exposing them.
      expect(_turn(14285.0, [14286.2], tuning: const VfoSnapTuning(longMoveKHz: 1.0)), 14286.0);
      expect(_turn(14285.0, [14286.2]), 14286.25);
      // And 250 Hz of movement is fine tuning at a 0.3 floor, an arrival at
      // the 0.2 default.
      expect(_turn(14285.0, [14285.25], tuning: const VfoSnapTuning(minMoveKHz: 0.3)), isNull);
      expect(_turn(14285.0, [14285.25]), 14285.3);
    });

    test('a snap that would cross a band edge is refused', () {
      // 7299.7 rounds to 7300.0, the top of 40m. Half a grid step is enough
      // to put the operator out of band, which is worse than not snapping.
      expect(_turn(7280, [7290, 7299.7]), isNull);
    });

    test('the settled frequency becomes the resting point', () {
      // Without this, the radio confirming the snap we just asked for reads
      // as a fresh knob turn — and the app chases its own tail.
      final snapper = VfoSnapper()..rebase(14260);
      snapper.report(14285.4, _t0);
      expect(snapper.settle(const VfoSnapTuning()), 14285.0);
      expect(snapper.report(14285.0, _t0.add(const Duration(milliseconds: 100))), isFalse);
      expect(snapper.settle(const VfoSnapTuning()), isNull);
    });

    test('a rebase abandons the movement in progress', () {
      final snapper = VfoSnapper()..rebase(14260);
      snapper.report(14285.4, _t0);
      snapper.rebase(14285.4);
      expect(snapper.settle(const VfoSnapTuning()), isNull);
    });

    test('a radio restating the frequency neither ends nor extends the movement', () {
      // A poll answering "still 14285.4" is not the operator moving again.
      // It must not end the burst — and it must not report movement either,
      // or the caller re-arms its quiet period on a VFO that is standing
      // still. The polled drivers restate the frequency every 200 ms while
      // the poller is in its fast cadence, which is faster than any settle
      // delay on offer.
      final snapper = VfoSnapper()..rebase(14260);
      snapper.report(14285.4, _t0);
      expect(snapper.report(14285.4, _t0.add(const Duration(milliseconds: 100))), isFalse);
      expect(snapper.settle(const VfoSnapTuning()), 14285.0, reason: 'the burst survived the restatement');
    });

    test('speed is measured over the readings it was measured from', () {
      // Nothing says WHEN the VFO left the resting frequency, only that it
      // had by the first reading of the burst. Counting that first step's
      // distance against an interval that starts after it reads a slow creep
      // as a fast arrival: a polled radio sits at its 3s cadence until it
      // sees a change, so resting and first-moved readings can be seconds
      // apart while the two moved readings are 500ms apart.
      final snapper = VfoSnapper()..rebase(14285.0);
      snapper.report(14285.63, _t0.add(const Duration(seconds: 3)));
      snapper.report(14285.73, _t0.add(const Duration(milliseconds: 3500)));
      // 100 Hz over 500 ms is 0.2 kHz/s — under the floor, and the whole
      // 730 Hz took over three seconds. Charging all 730 Hz to the 500 ms
      // interval gives 1.46 kHz/s, which clears the floor and rounds to
      // 14285.7. The off-grid .73 is what makes the two outcomes differ.
      expect(snapper.settle(const VfoSnapTuning()), isNull);
    });
  });

  test('VfoSnapTuning\'s defaults are the ones that actually ship', () async {
    // Every rule test above builds `const VfoSnapTuning()`, but production
    // only ever builds one from SettingsService (CatService._settleSnap), so
    // the two are separate copies of the same four numbers. Without this,
    // retuning the shipped feel — which is what the dev-mode knobs exist to
    // lead to — leaves a green suite still asserting the old values.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
    const defaults = VfoSnapTuning();

    expect(settings.smartVfoSnapLongMoveKHz, defaults.longMoveKHz);
    expect(settings.smartVfoSnapMinMoveKHz, defaults.minMoveKHz);
    expect(settings.smartVfoSnapMinSpeed, defaults.minSpeedKHzPerSec);
    // The settle delay has no VfoSnapTuning counterpart — it belongs to the
    // caller's timer — so it is pinned against the literal the wired tests
    // below elapse through.
    expect(settings.smartVfoSnapDebounce, const Duration(milliseconds: 300));
  });

  group('snapToGrid', () {
    test('answers in whole Hz', () {
      // (14285.3 / 0.1).round() * 0.1 is 14285.300000000001, and that is
      // what would be sent to the radio.
      expect(snapToGrid(14285.34, 0.1), 14285.3);
      expect(snapToGrid(14285.34, 0.25), 14285.25);
      expect(snapToGrid(14285.34, 1.0), 14285.0);
    });
  });

  group('wired to the radio', () {
    late RadioService radio;
    late SettingsService settings;
    late _FakeDriver driver;
    late CatService cat;
    late DateTime fakeNow;

    /// The settle delay's default, which these tests leave alone — the
    /// setting itself is exercised in the VfoSnapper group.
    const quiet = Duration(milliseconds: 300);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      radio = RadioService(prefs, writeDelay: Duration.zero);
      driver = _FakeDriver();
      final transport = _FakeTransport();
      settings = SettingsService(prefs, secureStorage: FakeSecureStorage());
      fakeNow = _t0;
      cat = CatService(
        settings,
        radio: radio,
        now: () => fakeNow,
        registry: EquipmentRegistry(
          models: [_fakeModel(driver, transport)],
          transports: {'fake': transport},
        ),
      );
    });

    tearDown(() {
      cat.dispose();
      radio.dispose();
    });

    /// Connected, and sitting still on [restingKHz] — which is what a radio
    /// reports first, and what the operator's next knob turn is measured
    /// against. The very first reading of a session can never be a movement:
    /// nothing says where the knob was before the app was listening.
    Future<_FakeSession> restingRadio({double restingKHz = 14285.0, String mode = 'USB'}) async {
      final node = await cat.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'});
      await cat.connect(node.uuid);
      final session = driver.sessions.single;
      session.radioReports(freqKHz: restingKHz, mode: mode);
      return session;
    }

    test('off by default: the radio is left exactly where it was tuned', () async {
      final session = await restingRadio();
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        async.elapse(quiet * 2);
      });
      expect(session.commands, isEmpty);
      expect(radio.vfoA.freq, 14285.43);
    });

    test('once on, the settled frequency is sent back to the radio', () async {
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        // Nothing before the quiet period is up: the operator may still be
        // turning, and a snap mid-turn is the app grabbing the knob.
        async.elapse(quiet - const Duration(milliseconds: 50));
        expect(session.commands, isEmpty);
        async.elapse(const Duration(milliseconds: 100));
      });
      expect(session.commands, ['freq:14285.4']);
      expect(radio.vfoA.freq, 14285.4);
    });

    test('a moving VFO re-arms the quiet period rather than snapping mid-turn', () async {
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio(restingKHz: 14260);
      fakeAsync((async) {
        for (final freq in [14270.0, 14280.0, 14285.43]) {
          session.radioReports(freqKHz: freq);
          fakeNow = fakeNow.add(quiet - const Duration(milliseconds: 50));
          async.elapse(quiet - const Duration(milliseconds: 50));
        }
        expect(session.commands, isEmpty, reason: 'still turning');
        async.elapse(quiet);
      });
      // Snapped against where the turn STARTED, not against the last step:
      // 25 kHz of travel is a sweep, so it lands on a whole kHz.
      expect(session.commands, ['freq:14285.0']);
    });

    test('CW is never snapped', () async {
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio(restingKHz: 14031.0, mode: 'CW');
      fakeAsync((async) {
        session.radioReports(freqKHz: 14031.43);
        async.elapse(quiet * 2);
      });
      expect(session.commands, isEmpty);
    });

    test('switching to CW mid-turn abandons the snap', () async {
      // The mode is re-checked on every reading, not once when the burst
      // opens. Settling this one would tune the rig off the CW signal the
      // operator just switched to.
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        async.elapse(const Duration(milliseconds: 100));
        session.radioReports(mode: 'CW');
        async.elapse(quiet * 2);
      });
      expect(session.commands, isEmpty);
    });

    test('a transmitting radio is never snapped', () async {
      // The one move this feature must never make. Retuning a rig mid-over
      // sweeps the carrier across the band on the rigs that allow it and is
      // silently refused by the ones that do not — and a "burst" measured
      // across a transmission was never a knob turn in the first place.
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      fakeAsync((async) {
        session.sink.reportTransmitting(true);
        session.radioReports(freqKHz: 14285.43);
        async.elapse(quiet * 2);
      });
      expect(session.commands, isEmpty);
    });

    test('a radio keyed DURING the settle delay is not snapped when it elapses', () async {
      // The gate has to hold at both ends: the reading arrives while the rig
      // is receiving, the operator keys it a moment later, and the timer
      // that fires afterwards is what actually moves the radio.
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        async.elapse(const Duration(milliseconds: 100));
        session.sink.reportTransmitting(true);
        async.elapse(quiet * 2);
      });
      expect(session.commands, isEmpty);
    });

    test('a radio that has finished transmitting is snapped again', () async {
      // The gate is a hold, not an off switch: a rig that reported TX once
      // and was never snapped again would look exactly like the setting
      // silently failing.
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      fakeAsync((async) {
        session.sink.reportTransmitting(true);
        session.radioReports(freqKHz: 14285.43);
        async.elapse(quiet * 2);
        session.sink.reportTransmitting(false);
        // A fresh move: the held snap rebased to where the rig was, so
        // restating that frequency is not a knob turn and would prove
        // nothing either way.
        session.radioReports(freqKHz: 14290.43);
        async.elapse(quiet * 2);
      });
      expect(session.commands, ['freq:14290.0']);
    });

    test('a typed frequency cancels the pending snap and is not itself snapped', () async {
      // Typing 14290.43 is an exact statement of where to be. Rounding it
      // would be the app undoing the operator — and the snap that was
      // pending was decided against a frequency nobody is on any more.
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        async.elapse(const Duration(milliseconds: 100));
        radio.setVfo('vfoA', freq: 14290.43);
        async.elapse(quiet * 2);
      });
      expect(session.commands, ['freq:14290.43']);
      expect(radio.vfoA.freq, 14290.43);
    });

    test('the radio confirming a snap does not start another one', () async {
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        async.elapse(quiet * 2);
        session.radioReports(freqKHz: 14285.4);
        async.elapse(quiet * 2);
      });
      expect(session.commands, ['freq:14285.4'], reason: 'the snap, once, and no echo of it');
    });

    test('a repeated poll of a stationary VFO does not postpone the settle', () async {
      // The polled drivers (FT-891, flrig, rigctld) report on EVERY poll,
      // changed or not, and AdaptivePoller's fast cadence is 200 ms — shorter
      // than any settle delay on offer. Re-arming on a restatement pushes the
      // snap out for as long as the poller stays fast, which on the default
      // 300 ms delay lands it seconds late on exactly the hardware the delay
      // exists to tune.
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(milliseconds: 200));
          fakeNow = fakeNow.add(const Duration(milliseconds: 200));
          session.radioReports(freqKHz: 14285.43);
        }
      });
      expect(session.commands, ['freq:14285.4'], reason: 'settled on time despite the quiet polls');
    });

    test('the settle delay follows its setting, with no reconnect', () async {
      // Whoever is tuning this setting is turning the knob to feel the
      // difference. Caching the period at construction (or at connect) would
      // make every change take a reconnect to notice, which reads as the
      // setting doing nothing.
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      await settings.setSettingValue(SettingsService.radioGroup, 'smartVfoSnapDebounceMs', '1000');
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        async.elapse(quiet * 2);
        expect(session.commands, isEmpty, reason: 'the default period has passed, the new one has not');
        async.elapse(const Duration(milliseconds: 500));
      });
      expect(session.commands, ['freq:14285.4']);
    });

    test('a polling session buys itself one poll period before the delay counts', () async {
      // Between polls, no readings arrive whether the dial is still or
      // spinning — so on a polled radio the first poll period is silence
      // that means nothing, and settling inside it snaps mid-turn.
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      session.expectedUpdateInterval = const Duration(milliseconds: 200);
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        async.elapse(const Duration(milliseconds: 400));
        expect(session.commands, isEmpty, reason: 'the bare 300ms delay would have fired by now');
        // 200ms poll period + 300ms delay.
        async.elapse(const Duration(milliseconds: 150));
      });
      expect(session.commands, ['freq:14285.4']);
    });

    test('a pushing session adds nothing to the delay', () async {
      // The default fake pushes (null interval), which is what every other
      // test in this group relies on — pinned here so a driver that starts
      // reporting a cadence can't quietly slow every push radio down too.
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      expect(session.expectedUpdateInterval, isNull);
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        async.elapse(const Duration(milliseconds: 310));
      });
      expect(session.commands, ['freq:14285.4']);
    });

    test('the poll period is read when the timer is armed, not when it fires', () async {
      // AdaptivePoller eases off the moment the dial stops, so by the time
      // the timer fires the interval has grown. Re-reading it then would
      // chase the back-off and settle later and later.
      await settings.setSmartVfoSnap(true);
      final session = await restingRadio();
      session.expectedUpdateInterval = const Duration(milliseconds: 200);
      fakeAsync((async) {
        session.radioReports(freqKHz: 14285.43);
        session.expectedUpdateInterval = const Duration(seconds: 3);
        async.elapse(const Duration(milliseconds: 600));
      });
      expect(session.commands, ['freq:14285.4'], reason: 'settled on the cadence the movement happened at');
    });

    test('a knob turn on a radio that is not driving the panel is ignored', () async {
      await settings.setSmartVfoSnap(true);
      final first = await restingRadio();
      final node = await cat.addNode(typeKey: 'fake-type', config: {'host': 'second'});
      await cat.connect(node.uuid);
      // Adding the second transceiver hands it radio1, so the first is now
      // just a radio in the shack.
      expect(cat.isRadio1(node.uuid), isTrue);
      fakeAsync((async) {
        first.radioReports(freqKHz: 14285.43);
        async.elapse(quiet * 2);
      });
      expect(first.commands, isEmpty);
    });
  });
}

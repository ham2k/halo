// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/radio_service.dart';

import '../support/fake_clock.dart';
import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('power carries the operator\'s stated watts, independent of the tuning', () {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', power: 5);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');

    expect(radio.vfoA.power, 5, reason: 'a retune says nothing about power');
    radio.setVfo('vfoA', clearPower: true);
    expect(radio.vfoA.power, isNull, reason: 'clearing is explicit — omitting means unchanged');
    expect(radio.vfoA.freq, 14285, reason: 'and it says nothing about the tuning either');
  });

  group("the operator's pre-VFO power", () {
    // Power used to live in SettingsService.currentPower. Dropping the key
    // on upgrade would silently reset a stated power; reading it as a
    // fallback in CatService.displayedPower would leave the surfaces that
    // read Vfo.power directly (the logging control, the More pane) showing
    // nothing while Station Configuration showed it. So it migrates once.
    Future<HaLoServices> services() async {
      return (await makeHaLoServices(prefs: null)).services;
    }

    test('moves onto the VFO at startup', () async {
      await (await services()).settings.setCurrentPower(100);

      final restarted = await services();
      expect(restarted.radio.vfoA.power, 100);
      expect(restarted.cat.displayedPower, 100, reason: 'and every surface reads it from there');
    });

    test('never overwrites a power the VFO already carries', () async {
      final first = await services();
      await first.settings.setCurrentPower(100);
      first.radio.setVfo('vfoA', power: 5);
      await first.radio.flushPendingWrites();

      expect((await services()).radio.vfoA.power, 5);
    });
  });

  test('vfoA is empty with nothing persisted yet', () {
    final radio = RadioService(prefs);
    expect(radio.vfoA.freq, isNull);
    expect(radio.vfoA.band, isNull);
    expect(radio.vfoA.mode, isNull);
  });

  test('setVfo with freq derives the band', () {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');

    expect(radio.vfoA.freq, 14285);
    expect(radio.vfoA.band, '20m');
    expect(radio.vfoA.mode, 'USB', reason: 'SSB is resolved against the band it lands on');
  });

  test('setVfo with band clears freq (manually picked band, no exact frequency)', () {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 14285);
    radio.setVfo('vfoA', band: '40m');

    expect(radio.vfoA.freq, isNull);
    expect(radio.vfoA.band, '40m');
  });

  test('setVfo with only mode leaves freq/band untouched', () {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    radio.setVfo('vfoA', mode: 'CW');

    expect(radio.vfoA.freq, 14285);
    expect(radio.vfoA.band, '20m');
    expect(radio.vfoA.mode, 'CW');
  });

  group('SSB is resolved to a sideband, at the request', () {
    // The generic mode is what a spot, the setVfo command and the mode
    // picker all say. Which sideband that IS follows from the band, so it is
    // settled once, here, rather than by each reader — and a shack with no
    // radio attached (nothing to resolve it at the CAT boundary) logs the
    // sideband it worked, not "SSB".

    test('a band that runs lower sideband gets LSB', () {
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', freq: 7180, mode: 'SSB');
      expect(radio.vfoA.mode, 'LSB');
    });

    test('a band that runs upper sideband gets USB', () {
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', freq: 14250, mode: 'SSB');
      expect(radio.vfoA.mode, 'USB');
    });

    test('60m is upper despite sitting below 10 MHz', () {
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', freq: 5357, mode: 'SSB');
      expect(radio.vfoA.mode, 'USB', reason: '60m is channelized USB by international agreement');
    });

    test('a picked band with no frequency still resolves', () {
      // What a manual band pick leaves behind. Deriving from the frequency
      // alone would fall through to USB on 40m.
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', band: '40m', mode: 'SSB');
      expect(radio.vfoA.mode, 'LSB');
    });

    test('with neither a frequency nor a band, the generic mode stands', () {
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', mode: 'SSB');
      expect(radio.vfoA.mode, 'SSB', reason: 'nothing to resolve against — guessing USB would be a coin flip');
    });

    test('a mode that already names its sideband is left alone', () {
      final radio = RadioService(prefs);
      // An operator on 40m deliberately working the wrong sideband, or a rig
      // reporting one — neither is a request to re-derive anything.
      radio.setVfo('vfoA', freq: 7180, mode: 'USB');
      expect(radio.vfoA.mode, 'USB');
    });

    test('moving band re-resolves a generic mode that is still sitting in the VFO', () {
      // A VFO stored by an older build (or handed over by a peer) holds
      // 'SSB'. Tuning it to a lower-sideband band settles it.
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', mode: 'SSB');
      radio.setVfo('vfoA', freq: 7180);
      expect(radio.vfoA.mode, 'LSB');
    });

    test('picking a new band re-derives the sideband nobody restated', () {
      // The band dropdown sends a band and NO mode. The sideband sitting in
      // the VFO was derived from the band being left, so carrying it across
      // would log — and transmit — USB on 40m.
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', freq: 14250, mode: 'SSB');
      expect(radio.vfoA.mode, 'USB');

      radio.setVfo('vfoA', band: '40m');
      expect(radio.vfoA.mode, 'LSB');

      radio.setVfo('vfoA', band: '20m');
      expect(radio.vfoA.mode, 'USB', reason: 'and back again — it follows the band, both ways');
    });

    test('typing a frequency on another band re-derives it too', () {
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', freq: 7180, mode: 'SSB');
      expect(radio.vfoA.mode, 'LSB');

      radio.setVfo('vfoA', freq: 14250);
      expect(radio.vfoA.mode, 'USB');
    });

    test('a mode stated in the same write is taken as stated', () {
      // The operator deliberately on the far sideband, or a rig reporting
      // its own mode: re-deriving either would be the app arguing with it.
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', freq: 7180, mode: 'USB');
      expect(radio.vfoA.mode, 'USB');

      // And it survives until something moves band without restating it.
      radio.setVfo('vfoA', freq: 7185);
      expect(radio.vfoA.mode, 'USB', reason: 'same band, so nothing is re-derived');
    });

    test('moving band leaves a non-sideband mode alone', () {
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', freq: 14030, mode: 'CW');
      radio.setVfo('vfoA', band: '40m');
      expect(radio.vfoA.mode, 'CW');
    });

    test('a power-only write does not touch the mode', () {
      // The Station panel and the legacy-power migration both call setVfo
      // with nothing but a power. A mode rewritten there would notify every
      // listener and schedule a prefs write for what is not a tuning change.
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', mode: 'SSB');
      expect(radio.vfoA.mode, 'SSB', reason: 'no band, nothing to resolve against');

      var notifications = 0;
      radio.addListener(() => notifications++);
      radio.setVfo('vfoA', power: 100);
      expect(radio.vfoA.mode, 'SSB');
      expect(notifications, 1, reason: 'the power change, and nothing else');
    });

    test('a non-phone mode is untouched', () {
      final radio = RadioService(prefs);
      radio.setVfo('vfoA', freq: 7025, mode: 'CW');
      expect(radio.vfoA.mode, 'CW');
    });
  });

  test('persists across instances — a fresh RadioService picks up the last saved state', () async {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    // Writes are debounced now (a CAT-connected radio reports every knob
    // step), so wait for the real thing rather than guessing at a delay.
    await radio.flushPendingWrites();

    final freshRadio = RadioService(prefs);
    expect(freshRadio.vfoA.freq, 14285);
    expect(freshRadio.vfoA.band, '20m');
    expect(freshRadio.vfoA.mode, 'USB');
  });

  test('is not scoped to any operation — the same vfoA is shared everywhere', () async {
    // There's no per-operation concept in RadioService at all: setting vfoA
    // once means every reader (regardless of which operation is on screen)
    // sees the same value, immediately and after a reload.
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 7100, mode: 'CW');
    await radio.flushPendingWrites();

    final anotherOperationsRadio = RadioService(prefs);
    expect(anotherOperationsRadio.vfoA.freq, 7100);
    expect(anotherOperationsRadio.vfoA.mode, 'CW');
  });

  test('notifies listeners on setVfo', () {
    final radio = RadioService(prefs);
    var notifications = 0;
    radio.addListener(() => notifications++);

    radio.setVfo('vfoA', freq: 14285);
    expect(notifications, 1);

    radio.setVfo('vfoA', mode: 'CW');
    expect(notifications, 2);
  });

  // A CAT-connected radio restates its whole state on every status push and
  // on every periodic resync. Treating each restatement as a change would
  // notify every listener — and, before the debounce below, rewrite the
  // prefs — dozens of times a second while the operator turns the knob.
  test('a restatement of the current VFO is not a change', () {
    final radio = RadioService(prefs);
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');

    var notifications = 0;
    radio.addListener(() => notifications++);

    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    radio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    expect(notifications, 0);

    radio.setVfo('vfoA', freq: 14285.5, mode: 'SSB');
    expect(notifications, 1, reason: 'a real change still notifies');
  });

  test('a burst of changes is debounced into one write, and the last value wins', () async {
    // Long enough that "nothing has landed yet" below cannot be a race with
    // the timer — the write is async, so a bare synchronous read after the
    // loop sees nothing whether or not the debounce exists.
    final radio = RadioService(prefs, writeDelay: const Duration(seconds: 10));
    for (var step = 0; step < 20; step++) {
      radio.setVfo('vfoA', freq: 14285 + step * 0.1);
    }
    await pumpEventQueue();

    // Spinning a VFO knob reports every step, and a connected radio does
    // this for as long as the operator keeps turning it. Asserting only the
    // final value would hold just as well with no debounce at all — which
    // is what 20 writes for 20 steps looks like.
    expect(RadioService(prefs).vfoA.freq, isNull, reason: 'still inside the debounce window');

    await radio.flushPendingWrites();
    expect(RadioService(prefs).vfoA.freq, closeTo(14286.9, 0.001));
  });

  test('origin defaults to user, and is remembered for the notification', () {
    final radio = RadioService(prefs);
    VfoOrigin? seen;
    radio.addListener(() => seen = radio.lastVfoOrigin);

    radio.setVfo('vfoA', freq: 14285);
    expect(seen, VfoOrigin.user, reason: 'every existing caller means user');

    // CAT writes what the radio reported, then has to recognise its own
    // echo when the notification comes back around — otherwise it re-tunes
    // the radio to the value the radio just gave it.
    radio.setVfo('vfoB', freq: 7100, origin: VfoOrigin.radio);
    expect(seen, VfoOrigin.radio);
  });

  // The trap: an SO2R set listening to the whole service, so every report
  // from the other radio rebuilds and re-seeds it during a contest.
  test("a VFO's own updates fire for that VFO alone", () {
    final radio = RadioService(prefs);
    addTearDown(radio.dispose);
    final updates = RadioVfoUpdates(radio, 'vfoB');
    addTearDown(updates.dispose);
    var fired = 0;
    updates.addListener(() => fired++);

    radio.setVfo('vfoA', freq: 14025);
    expect(fired, 0);
    radio.setVfo('vfoB', freq: 7025);
    expect(fired, 1);
  });

  // docs/design/cat.md § The VFO the app shows.
  group("the VFO the app shows runs ahead of the radio", () {
    const ms = Duration(milliseconds: 1);
    late RadioService radio;

    setUp(() {
      followFakeClock();
    });

    void report(double freq, {String key = 'vfoA', String? mode}) => radio.setVfo(key, freq: freq, mode: mode, origin: VfoOrigin.radio);

    // The bounce: a poll answered from before the tune, or a step a drag has passed, taking the
    // dial back to where the radio was for a moment before the radio's report of the tune.
    test('a report from before the tune does not take it back, and the radio confirming it ends the hold', () {
      fakeAsync((async) {
        radio = RadioService(prefs, writeDelay: Duration.zero);
        report(7010);
        radio.setVfo('vfoA', freq: 7030);
        async.elapse(ms * 100);
        report(7010);
        expect(radio.vfoA.freq, 7030);
        expect(radio.realVfo('vfoA').freq, 7010, reason: "the radio's own word is kept beside it");

        async.elapse(ms * 100);
        report(7030);
        expect(radio.realVfo('vfoA').freq, 7030);
        // Confirmed, so the radio leads again: its own knob shows at once, not a hold later.
        report(7031);
        expect(radio.vfoA.freq, 7031);
        radio.dispose();
      });
    });

    test('a radio that keeps to another frequency past the hold is where it says, as its own move', () {
      fakeAsync((async) {
        radio = RadioService(prefs, writeDelay: Duration.zero);
        report(7010);
        radio.setVfo('vfoA', freq: 7030);
        async.elapse(ms * 100);
        report(7010);
        final origins = <VfoOrigin>[];
        radio.addListener(() => origins.add(radio.lastVfoOrigin));

        async.elapse(ms * 1300);
        expect(radio.vfoA.freq, 7030, reason: 'still inside the first 1.5 s');
        async.elapse(ms * 200);
        expect(radio.vfoA.freq, 7010, reason: 'a radio that refused or rounded the tune is where it says');
        // As `user`, CAT would send the radio back where it already is, and peers would follow it.
        expect(origins, [VfoOrigin.radio]);
        radio.dispose();
      });
    });

    test('with no radio reporting, the tune stays and nothing waits on one', () {
      fakeAsync((async) {
        radio = RadioService(prefs, writeDelay: Duration.zero);
        radio.setVfo('vfoA', freq: 7030);
        async.elapse(const Duration(seconds: 10));
        expect(radio.vfoA.freq, 7030);
        // A timer per keystroke in a shack with no radio would be pending at the end of every widget test that types a frequency.
        expect(async.pendingTimers, isEmpty);
        report(7010);
        expect(radio.vfoA.freq, 7010, reason: 'a report after the hold stands at once');
        radio.dispose();
      });
    });

    test("the hold stretches to a radio slow to answer, and shrinks to a quick one's floor", () {
      fakeAsync((async) {
        radio = RadioService(prefs, writeDelay: Duration.zero);
        expect(radio.holdMillis('vfoA'), 1500);
        for (var i = 0; i < 12; i++) {
          radio.setVfo('vfoA', freq: 7000.0 + i);
          async.elapse(ms * 1200);
          report(7000.0 + i);
        }
        final slow = radio.holdMillis('vfoA');
        expect(slow, greaterThan(3000));

        // Over a slow link the poll sent ahead of the tune answers late too: past 1.5 s, still held.
        radio.setVfo('vfoA', freq: 7100);
        async.elapse(ms * 2000);
        report(7011);
        expect(radio.vfoA.freq, 7100);
        async.elapse(Duration(milliseconds: slow));

        for (var i = 0; i < 12; i++) {
          radio.setVfo('vfoA', freq: 7200.0 + i);
          async.elapse(ms * 50);
          report(7200.0 + i);
        }
        expect(radio.holdMillis('vfoA'), 1000);
        expect(radio.holdMillis('vfoB'), 1500, reason: "each radio's own answers");
        radio.dispose();
      });
    });

    test('each field is held on its own: a tune across bands lands its frequency before its mode', () {
      fakeAsync((async) {
        radio = RadioService(prefs, writeDelay: Duration.zero);
        report(14025, mode: 'CW');
        radio.setVfo('vfoA', freq: 7200, mode: 'SSB');
        async.elapse(ms * 50);
        report(7200, mode: 'CW');
        expect(radio.vfoA.freq, 7200);
        expect(radio.vfoA.mode, 'LSB', reason: 'the mode asked for, not the one the radio has yet to leave');
        report(7200, mode: 'LSB');
        report(7200, mode: 'CW');
        expect(radio.vfoA.mode, 'CW', reason: 'confirmed, so a mode the operator then picks on the radio shows');
        radio.dispose();
      });
    });

    test('a 10 Hz radio landing on its step confirms the tune, and shows its step', () {
      fakeAsync((async) {
        radio = RadioService(prefs, writeDelay: Duration.zero);
        radio.setVfo('vfoA', freq: 7030.004);
        async.elapse(ms * 50);
        report(7030.0);
        expect(radio.vfoA.freq, 7030.0);
        expect(async.pendingTimers, isEmpty, reason: 'nothing left held');
        radio.dispose();
      });
    });

    // Noting the restated tune would cancel the release the held report waits on, and nothing new
    // goes to the radio to answer it.
    test('restating the frequency already shown keeps the hold as it was', () {
      fakeAsync((async) {
        radio = RadioService(prefs, writeDelay: Duration.zero);
        report(7010);
        radio.setVfo('vfoA', freq: 7030);
        async.elapse(ms * 100);
        report(7010);
        async.elapse(ms * 1000);
        radio.setVfo('vfoA', freq: 7030);
        async.elapse(ms * 500);
        expect(radio.vfoA.freq, 7010, reason: 'released when the first tune\'s hold ran out');
        radio.dispose();
      });
    });

    test('a radio answering after its hold has run out is measured, and its hold grows', () {
      fakeAsync((async) {
        radio = RadioService(prefs, writeDelay: Duration.zero);
        radio.setVfo('vfoA', freq: 7030);
        async.elapse(ms * 2000);
        report(7030);
        expect(radio.holdMillis('vfoA'), 5000);
        radio.dispose();

        radio = RadioService(prefs, writeDelay: Duration.zero);
        report(7010, key: 'vfoB');
        radio.setVfo('vfoB', freq: 7030);
        async.elapse(ms * 100);
        report(7010, key: 'vfoB');
        async.elapse(ms * 1900);
        expect(radio.vfo('vfoB').freq, 7010, reason: 'released at 1.5 s');
        report(7030, key: 'vfoB');
        expect(radio.holdMillis('vfoB'), 5000, reason: 'the answer after a release counts too');
        radio.dispose();
      });
    });

    test("a tune across a sideband edge holds the sideband it carried, though it named no mode", () {
      fakeAsync((async) {
        radio = RadioService(prefs, writeDelay: Duration.zero);
        report(14200, mode: 'USB');
        radio.setVfo('vfoA', freq: 7200);
        expect(radio.vfoA.mode, 'LSB');
        async.elapse(ms * 50);
        report(14200, mode: 'USB');
        expect(radio.vfoA.mode, 'LSB', reason: 'a QSO logged now is on 40 m, in LSB');
        radio.dispose();
      });
    });

    test("a radio's own VFO is held the same", () {
      fakeAsync((async) {
        radio = RadioService(prefs, writeDelay: Duration.zero);
        report(7010, key: 'node-1');
        radio.setVfo('node-1', freq: 7030);
        async.elapse(ms * 100);
        report(7010, key: 'node-1');
        expect(radio.vfo('node-1').freq, 7030);
        radio.dispose();
      });
    });
  });

  // A radio's report is its own record of where it is; a remembered copy would show a radio that
  // has not reported yet where it was last session.
  test("a radio's own VFO is not remembered across a restart", () async {
    final radio = RadioService(prefs, writeDelay: Duration.zero);
    radio.setVfo('node-1', freq: 7010, origin: VfoOrigin.radio);
    radio.setVfo('vfoA', freq: 14025);
    await radio.flushPendingWrites();
    final restarted = RadioService(prefs);
    expect(restarted.vfo('node-1').freq, isNull);
    expect(restarted.vfoA.freq, 14025);
  });
}

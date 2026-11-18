// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operating style — docs/design/logging-fields.md § Operating style: Run
// or S&P per set, moved by message 1, a QSY, a spot picked, and a return to
// the run frequency. The tracker alone first, then as CatService wires it to
// the VFOs and the stored Run/S&P.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_models_other_radios.dart';
import 'package:ham2k_logger/services/cat/operating_style.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One set's radio as the tracker sees it, the style kept the way CatService
/// keeps it: every change, the tracker's own included, reported back.
class _Station {
  _Station({this.running = true}) {
    tracker = OperatingStyleTracker(
      tracking: () => tracked,
      isRunning: (_) => running,
      setRunning: (_, value) {
        if (running == value) return;
        running = value;
        tracker.styleChanged('A');
      },
      vfoOf: (_) => vfo,
      transmitting: (_) => transmitting,
    );
  }

  late final OperatingStyleTracker tracker;
  bool tracked = true;
  bool running;
  bool transmitting = false;
  Vfo vfo = const Vfo(freq: 14025.0, mode: 'CW');

  void tune(double freq, {String? mode}) {
    vfo = Vfo(freq: freq, mode: mode ?? vfo.mode);
    tracker.vfoMoved('A');
  }
}

void main() {
  group('the tracker', () {
    test('a CW run survives a nudge of the dial, and a QSY past 200 Hz is S&P', () {
      final station = _Station()..tune(14025.0);
      station.tune(14025.15);
      expect(station.running, isTrue, reason: 'zero-beating a caller is still the run');
      station.tune(14025.25);
      expect(station.running, isFalse);
    });

    // Measured from the run frequency, not the last reading: a run walked off
    // in small steps is as gone as one turn of the knob.
    test('a run walked off in small steps is S&P', () {
      final station = _Station()..tune(14025.0);
      for (final freq in [14025.15, 14025.30, 14025.45]) {
        station.tune(freq);
      }
      expect(station.running, isFalse);
    });

    test('phone keeps a run within 1 kHz; a mode change is a QSY', () {
      final station = _Station()..tune(14250.0, mode: 'USB');
      station.tune(14250.8);
      expect(station.running, isTrue);
      station.tune(14250.8, mode: 'CW');
      expect(station.running, isFalse);
    });

    // Working split, a rig reports the frequency it transmits on: a CQ keyed
    // split must not read as leaving the run.
    test('readings while transmitting are not a QSY', () {
      final station = _Station()..tune(14025.0);
      station.transmitting = true;
      station.tune(14027.0);
      expect(station.running, isTrue);
    });

    test('message 1 runs, and takes the run frequency where it is keyed', () {
      final station = _Station(running: false)..tune(7030.0);
      station.tracker.messageOne('A');
      expect(station.running, isTrue);
      // Re-taken on every CQ, so a run nudged off QRM keeps up: 300 Hz from
      // the first CQ, 150 from the second.
      station.tune(7030.15);
      station.tracker.messageOne('A');
      station.tune(7030.30);
      expect(station.running, isTrue);
    });

    test('coming back to the run frequency within three minutes runs again', () {
      fakeAsync((async) {
        AppClock.followZoneClock = true;
        addTearDown(() => AppClock.followZoneClock = false);
        final station = _Station()..tune(14025.0);
        station.tune(14031.0);
        expect(station.running, isFalse);
        async.elapse(const Duration(minutes: 2));
        station.tune(14025.1);
        expect(station.running, isTrue);
      });
    });

    test('coming back after three minutes stays S&P', () {
      fakeAsync((async) {
        AppClock.followZoneClock = true;
        addTearDown(() => AppClock.followZoneClock = false);
        final station = _Station()..tune(14025.0);
        station.tune(14031.0);
        async.elapse(OperatingStyleTracker.returnWindow + const Duration(seconds: 1));
        station.tune(14025.0);
        expect(station.running, isFalse);
      });
    });

    test('a self-spot runs, whatever its comment, and takes the run frequency where it is sent', () {
      final station = _Station(running: false)..tune(14250.0, mode: 'USB');
      station.tracker.selfSpotted('A', comment: 'CQ POTA, QRX 5 after this');
      expect(station.running, isTrue);
      // An auto re-spot after a nudge re-takes the run frequency, as a CQ does:
      // 1.2 kHz from the first spot, 0.6 from the second.
      station.tune(14250.6);
      station.tracker.selfSpotted('A', freq: 14250.6);
      station.tune(14251.2);
      expect(station.running, isTrue);
    });

    // QRT is the one comment that says the station is leaving: read as any
    // other, the operator's sign-off would start a run.
    test('a self-spot saying QRT ends the run', () {
      final station = _Station()..tune(14250.0, mode: 'USB');
      station.tracker.selfSpotted('A', comment: ' qrt, 73');
      expect(station.running, isFalse);
      station.tracker.selfSpotted('A', comment: 'QRT');
      expect(station.running, isFalse, reason: 'already S&P, it stays there');
    });

    // Without forgetting, hunting the band after a QRT would cross the old
    // run frequency and reopen a run the operator closed.
    test('after a QRT self-spot, tuning back across the run frequency stays S&P', () {
      final station = _Station()..tune(14250.0, mode: 'USB');
      station.tracker.selfSpotted('A', comment: 'QRT');
      station.tune(14260.0);
      station.tune(14250.2);
      expect(station.running, isFalse);
    });

    // An auto re-spot follows the dial within 500 Hz, wider than a CW QSY:
    // taken as Run it would pull the operator back from S&P, and take where
    // they now listen as the run frequency.
    test('a self-spot of a frequency the VFO has left leaves the style alone', () {
      final station = _Station()..tune(14062.0);
      station.tune(14062.3);
      expect(station.running, isFalse, reason: 'sanity: a CW QSY');
      station.tracker.selfSpotted('A', freq: 14062.0);
      expect(station.running, isFalse);
      station.tracker.selfSpotted('A', freq: 14062.3);
      expect(station.running, isTrue, reason: 'a spot of where it is now is a CQ there');
    });

    // Without the "been away" rule, the VFO still sitting on the run
    // frequency when the spot is picked would flip straight back to Run.
    test('a spot picked on the run frequency stays S&P until the VFO leaves and comes back', () {
      final station = _Station()..tune(14025.0);
      station.tracker.pickedSpot('A');
      expect(station.running, isFalse);
      station.tune(14025.05);
      expect(station.running, isFalse);
      station.tune(14028.0);
      station.tune(14025.0);
      expect(station.running, isTrue);
    });

    // The trap: already S&P and away, the spot's tune onto the old run
    // frequency reads as the operator coming back to it.
    test('a spot picked near the old run frequency is no return to it', () {
      final station = _Station()..tune(14025.0);
      station.tune(14040.0);
      expect(station.running, isFalse, reason: 'sanity');
      station.tracker.pickedSpot('A');
      station.tune(14025.1);
      expect(station.running, isFalse);
      station.tune(14031.0);
      station.tune(14025.0);
      expect(station.running, isTrue, reason: 'a move away after the spot makes the way back a return');
    });

    test('S&P with no run behind it never turns into Run by tuning', () {
      final station = _Station(running: false);
      station.tune(14025.0);
      station.tune(14030.0);
      station.tune(14025.0);
      expect(station.running, isFalse);
    });
  });

  group('CatService', () {
    late SettingsService settings;
    late RadioService radio;
    late CatService cat;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsService(await SharedPreferences.getInstance());
      radio = RadioService(await SharedPreferences.getInstance(), writeDelay: Duration.zero);
      addTearDown(radio.dispose);
      await settings.setSettingValue(SettingsService.loggingGroup, 'trackOpStyle', 'always');
      cat = CatService(settings, radio: radio);
      addTearDown(cat.dispose);
    });

    test('normal is the default style, Radio A\'s as Radio B\'s', () {
      expect((cat.styleOf('A'), cat.styleOf('B')), (OperatingStyle.normal, OperatingStyle.normal));
    });

    test('a QSY on the VFO switches the style, with or without a radio connected', () {
      cat.setStyle('A', OperatingStyle.run);
      radio.setVfo('vfoA', freq: 14025.0, mode: 'CW');
      expect(cat.styleOf('A'), OperatingStyle.run);
      radio.setVfo('vfoA', freq: 14040.0);
      expect(cat.styleOf('A'), OperatingStyle.normal);
      expect(settings.enterSendsRunning, isFalse, reason: 'the same Run/S&P ESM plays');
      radio.setVfo('vfoA', freq: 14025.0);
      expect(cat.styleOf('A'), OperatingStyle.run);
    });

    test('Radio B keeps its own style under SO2R', () async {
      await settings.setExperimentEnabled('so2r', true);
      cat.setStyle('A', OperatingStyle.run);
      cat.setStyle('B', OperatingStyle.run);
      radio.setVfo('vfoA', freq: 14025.0, mode: 'CW');
      radio.setVfo('vfoB', freq: 7030.0, mode: 'CW');
      radio.setVfo('vfoB', freq: 7040.0);
      expect((cat.styleOf('A'), cat.styleOf('B')), (OperatingStyle.run, OperatingStyle.normal));
    });

    // The trap: Radio B's run, and the three minutes to come back to it,
    // kept while SO2R is off and found again when it comes back on.
    test("Radio B's run ends with SO2R", () async {
      await settings.setExperimentEnabled('so2r', true);
      cat.setStyle('B', OperatingStyle.run);
      radio.setVfo('vfoB', freq: 7030.0, mode: 'CW');
      radio.setVfo('vfoB', freq: 7040.0);
      expect(cat.styleOf('B'), OperatingStyle.normal, reason: 'sanity');
      await settings.setExperimentEnabled('so2r', false);
      await settings.setExperimentEnabled('so2r', true);
      radio.setVfo('vfoB', freq: 7030.0);
      expect(cat.styleOf('B'), OperatingStyle.normal);
    });

    // SWAP moves each set's entry, which retunes its VFO to the other's
    // frequency. Were the run frequencies not traded first, the set taking
    // over the run would read its own retune as leaving it.
    test('SWAP trades the run frequencies with the styles', () async {
      await settings.setExperimentEnabled('so2r', true);
      // Two radios the VFOs stand in for: SWAP needs a Radio B.
      Future<EquipmentNode> placeholder() => cat.addNode(typeKey: 'ts480-placeholder', config: placeholderRadioModel.variants.single.defaultConfig);
      final a = await placeholder(), b = await placeholder();
      await cat.setRadio1(LocalRadio(a.uuid));
      await cat.setRadio2(b.uuid);
      expect(cat.radio2, b.uuid, reason: 'sanity');
      // A runs on 14025; B ran on 7030 and has moved to 7035 to pounce.
      cat.setStyle('A', OperatingStyle.run);
      radio.setVfo('vfoA', freq: 14025.0, mode: 'CW');
      cat.setStyle('B', OperatingStyle.run);
      radio.setVfo('vfoB', freq: 7030.0, mode: 'CW');
      radio.setVfo('vfoB', freq: 7035.0);
      expect((cat.styleOf('A'), cat.styleOf('B')), (OperatingStyle.run, OperatingStyle.normal), reason: 'sanity');
      cat.swapStyles();
      radio.setVfo('vfoA', freq: 7035.0);
      radio.setVfo('vfoB', freq: 14025.0);
      expect((cat.styleOf('A'), cat.styleOf('B')), (OperatingStyle.normal, OperatingStyle.run));
      radio.setVfo('vfoA', freq: 7030.0);
      expect(cat.styleOf('A'), OperatingStyle.run, reason: "A came back to the run it took from B");
    });

    test('a spot picked is S&P', () {
      cat.setStyle('A', OperatingStyle.run);
      radio.setVfo('vfoA', freq: 14025.0, mode: 'CW');
      cat.operatingStyle.pickedSpot(cat.operatorRadio);
      expect(cat.styleOf('A'), OperatingStyle.normal);
    });
  });

  // SettingsService.opStyleTracking: an operator who never keys has a style
  // nothing shows and only a self-spot or a stray key moves, so the default
  // tracks it only once the keyer, or the style itself, is used.
  group('tracking', () {
    late SettingsService settings;
    late RadioService radio;
    late CatService cat;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsService(await SharedPreferences.getInstance());
      radio = RadioService(await SharedPreferences.getInstance(), writeDelay: Duration.zero);
      addTearDown(radio.dispose);
      cat = CatService(settings, radio: radio);
      addTearDown(cat.dispose);
    });

    test('by default, an operation is untracked until the operator picks a style there, and each operation starts over', () {
      expect(settings.opStyleTracking, OpStyleTracking.keyer);
      cat.frontOperation = 'one';
      expect((cat.tracksStyle, cat.trackedStyleOf('A')), (false, null));
      cat.operatingStyle.selfSpotted('A');
      expect(cat.styleOf('A'), OperatingStyle.normal, reason: 'a self-spot alone is no use of the keyer');

      cat.setStyle('A', OperatingStyle.run);
      expect(cat.trackedStyleOf('A'), OperatingStyle.run);
      radio.setVfo('vfoA', freq: 14025.0, mode: 'CW');
      radio.setVfo('vfoA', freq: 14040.0);
      expect(cat.styleOf('A'), OperatingStyle.normal, reason: 'tracked: a QSY is S&P');

      cat.frontOperation = 'two';
      expect(cat.tracksStyle, isFalse, reason: 'another operation has not used the keyer');
      cat.frontOperation = 'one';
      expect(cat.tracksStyle, isTrue, reason: 'for the session');
    });

    test('never tracked, RUN and Alt-U are refused, nothing moves the style, and none is reported', () async {
      await settings.setSettingValue(SettingsService.loggingGroup, 'trackOpStyle', 'never');
      cat.frontOperation = 'one';
      expect((cat.setStyle('A', OperatingStyle.run), cat.toggleStyle('A')), (false, false));
      expect(cat.styleOf('A'), OperatingStyle.normal);
      // ESM's side is still the operator's to pick.
      cat.pickRunning('A', true);
      radio.setVfo('vfoA', freq: 14025.0, mode: 'CW');
      radio.setVfo('vfoA', freq: 14040.0);
      cat.operatingStyle.pickedSpot('A');
      expect((cat.tracksStyle, cat.trackedStyleOf('A'), cat.styleOf('A')), (false, null, OperatingStyle.run));
    });

    // SWAP and the tracker move styles through setRunning; neither is the
    // operator choosing one, so neither may start what the operator did not.
    test('a style moved by SWAP or the tracker starts nothing; one picked by hand does', () {
      cat.frontOperation = 'one';
      cat.setRunning('A', true);
      expect(cat.tracksStyle, isFalse);
      cat.pickRunning('A', true);
      expect(cat.tracksStyle, isTrue);
    });

    // The trap: Run kept in settings from an earlier session, tracking then
    // started by the first F2 of a new operation — every S&P contact after
    // it would be recorded as Run.
    test('tracking that starts begins in S&P, with the run frequency forgotten — unless ESM shows its side', () async {
      cat.setRunning('A', true);
      radio.setVfo('vfoA', freq: 14025.0, mode: 'CW');
      await settings.setSettingValue(SettingsService.loggingGroup, 'trackOpStyle', 'always');
      expect(cat.styleOf('A'), OperatingStyle.normal);
      radio.setVfo('vfoA', freq: 14040.0);
      radio.setVfo('vfoA', freq: 14025.0);
      expect(cat.styleOf('A'), OperatingStyle.normal, reason: 'no run to come back to');

      await settings.setSettingValue(SettingsService.loggingGroup, 'trackOpStyle', 'never');
      await settings.setExperimentEnabled('esm', true);
      cat.pickRunning('A', true);
      cat.setEnterSends(on: true);
      await settings.setSettingValue(SettingsService.loggingGroup, 'trackOpStyle', 'always');
      expect(cat.styleOf('A'), OperatingStyle.run, reason: "ESM's pill says Run: the operator sees it");
    });

    test('an operation coming back to the front keeps its style', () {
      cat.frontOperation = 'one';
      cat.setStyle('A', OperatingStyle.run);
      cat.frontOperation = 'two';
      cat.frontOperation = 'one';
      expect((cat.tracksStyle, cat.styleOf('A')), (true, OperatingStyle.run));
    });

    // Set from an OperationView's initState and dispose: a notification there
    // reaches widgets that would rebuild during a build.
    test('the operation in front changing tells the listeners after, not during, the change', () async {
      cat.frontOperation = 'one';
      cat.setStyle('A', OperatingStyle.run);
      await pumpEventQueue();
      var changes = 0;
      cat.styleChanges.addListener(() => changes++);
      cat.frontOperation = 'two';
      expect(changes, 0);
      await pumpEventQueue();
      expect(changes, 1);
    });

    test('the tracking changing is a style change: what a contact records and an extension reads moved', () async {
      var changes = 0;
      cat.styleChanges.addListener(() => changes++);
      await settings.setSettingValue(SettingsService.loggingGroup, 'trackOpStyle', 'always');
      expect(changes, 1);
      await settings.setSettingValue(SettingsService.loggingGroup, 'alwaysShowStyle', true);
      expect(changes, 1, reason: 'another setting is no change of the tracking');
    });
  });
}

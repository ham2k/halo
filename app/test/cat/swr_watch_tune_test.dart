// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A tune and the FYI area's SWR message (docs/design/logging-fields.md § The
// FYI area). The placeholder rig has no tuner, so the radio here is
// scripted: what a tuner-equipped rig reports, in the orders real ones
// report it in. On the fake clock, since what tells a tune from an over is
// timing — break-in's half second, a tuner report's freshness.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/swr_watch.dart';
import 'package:ham2k_logger/services/fyi_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_cat_radio.dart';
import '../support/fake_clock.dart';
import '../support/fake_secure_storage.dart';

/// Past break-in: the next key-down starts a transmission of its own.
const _apart = Duration(milliseconds: 600);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeRadio radio;
  late CatService cat;
  late FyiService fyi;

  /// Runs [body] against a connected radio 1 whose SWR [SwrWatch] reports,
  /// on the real clock — for a body that reconnects: closing a session waits
  /// on more than this isolate's timers.
  Future<void> onAirNow(Future<void> Function() body) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final radioService = RadioService(prefs, writeDelay: Duration.zero);
    radio = FakeRadio();
    cat = radio.catService(SettingsService(prefs, secureStorage: FakeSecureStorage()), radioService);
    fyi = FyiService();
    final watch = SwrWatch(cat: cat, fyi: fyi)..start();
    try {
      await connectFakeRadio1(cat);
      await body();
    } finally {
      watch.dispose();
      cat.dispose();
      radioService.dispose();
    }
  }

  /// [onAirNow] on the fake clock.
  void onAir(Future<void> Function() body) => runOnFakeClock((_) => onAirNow(body));

  /// The newest session's: a reconnect leaves the old one's behind.
  EquipmentSink sink() => radio.sinks.last;
  void tuner(TunerStatus status) => (sink() as TunerSink).reportTuner(status);
  void carrier(bool on) => (sink() as TuneCarrierSink).reportTuneCarrier(on);

  /// A transmission reading [swr], [then] whatever the radio says before key-up.
  Future<void> over(num swr, {void Function()? then}) async {
    sink().reportTransmitting(true);
    sink().reportMeter(RadioMeter.powerOut, 10);
    sink().reportMeter(RadioMeter.swr, swr);
    then?.call();
    sink().reportTransmitting(false);
    await Future<void>.delayed(_apart);
  }

  FyiMessage? swr() => fyi.messageFor(SwrWatch.keyFor('A'));

  test('a tune reads the mismatch the tuner is fixing, and raises nothing for it', () {
    onAir(() async {
      // The order a polled rig reports in: the tuner tuning, then the carrier.
      tuner(TunerStatus.tuning);
      await over(3.0, then: () => tuner(TunerStatus.inline));
      expect(swr(), isNull, reason: "a tune's SWR is the tuner's to fix, not the antenna's");
      await over(3.0);
      expect(swr()?.category, FyiCategory.alert, reason: 'sanity: the same reading on an ordinary over alerts');
    });
  });

  test('a tune reported after its carrier clears what its first readings raised', () {
    onAir(() async {
      // The order a FlexRadio reports in: meters off the carrier, then the
      // ATU's TUNE_IN_PROGRESS.
      await over(
        3.0,
        then: () {
          expect(swr(), isNotNull, reason: 'sanity: the first readings, not yet known as a tune, raised it');
          tuner(TunerStatus.tuning);
        },
      );
      expect(swr(), isNull);
    });
  });

  test('a tune clears what an earlier over raised: the match it read is the one being fixed', () {
    onAir(() async {
      await over(2.4);
      expect(swr()?.category, FyiCategory.alert, reason: 'sanity');
      tuner(TunerStatus.tuning);
      expect(swr(), isNotNull, reason: 'a tuner merely ready to tune has not yet tuned');
      await over(2.4, then: () => tuner(TunerStatus.inline));
      expect(swr(), isNull);
      await over(2.4);
      expect(swr()?.category, FyiCategory.alert, reason: "a tune that found no better match is the next over's to report");
    });
  });

  test("a radio's TUNE carrier is a tune too, whenever the radio says so", () {
    onAir(() async {
      // Before key-down: TUNE pressed, its carrier follows.
      carrier(true);
      await over(3.0, then: () => carrier(false));
      expect(swr(), isNull);
      // After the carrier's first readings, as the transmit object can lag the interlock.
      await over(
        3.0,
        then: () {
          expect(swr(), isNotNull, reason: 'sanity: the first readings, not yet known as a tune, raised it');
          carrier(true);
        },
      );
      carrier(false);
      expect(swr(), isNull);
    });
  });

  test('a tuner still reading tuning long after its tune makes no tune of the next over', () {
    onAir(() async {
      // A polled rig reads its tuner every few polls: the tune is over, the
      // carrier gone, and the last read still says tuning.
      tuner(TunerStatus.tuning);
      await over(1.2);
      await Future<void>.delayed(const Duration(seconds: 3));
      await over(3.0);
      expect(swr()?.category, FyiCategory.alert, reason: 'a missed alert is the costly way to be wrong');
    });
  });

  test('an over keyed the moment TUNE is released is an over, not more of the tune', () {
    onAir(() async {
      carrier(true);
      sink().reportTransmitting(true);
      sink().reportMeter(RadioMeter.powerOut, 10);
      sink().reportMeter(RadioMeter.swr, 1.1);
      carrier(false);
      sink().reportTransmitting(false);
      // Inside break-in's half second, which would otherwise continue the tune.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await over(3.0);
      expect(swr()?.category, FyiCategory.alert);
      expect(cat.lastTransmissionFor(radioUuid(cat))?.swrAverage, 3.0, reason: "the tune's readings are not this over's");
    });
  });

  test('a session lost mid-TUNE leaves no tune behind for the next one', () async {
    await onAirNow(() async {
      carrier(true);
      final uuid = radioUuid(cat);
      await cat.disconnect(uuid);
      await cat.connect(uuid);
      expect(radio.sinks, hasLength(2), reason: 'sanity: a new session');
      await over(3.0);
      expect(swr()?.category, FyiCategory.alert, reason: 'what the old session said of its carrier is not what this one says');
    });
  });
}

String radioUuid(CatService cat) => (cat.radio1! as LocalRadio).uuid;

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The meter cadence: when a radio's meters are read, and how fast the link
// it is on can afford to be asked.
//
// Both halves fail silently in the same direction. Too slow and the strip
// misses the transmission it exists for — an operator never sees the SWR of
// the call they just made, and nothing on screen says a reading was missed.
// Too fast and the meters fill a 4800-baud serial line, which shows up not
// as a meter problem but as a rig that is sluggish to tune, several layers
// away from anything that would point here.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/meter_calibration.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';

void main() {
  group('what the link can afford', () {
    test('a 4800-baud radio is held well below the 200ms default', () {
      // 52 bytes of question and answer is 108ms of wire at 4800 baud; at a
      // quarter duty cycle that is a cycle every 433ms. The default would
      // spend a quarter of the link on meters alone and queue in front of
      // the operator's own tune commands.
      final floor = telemetryFloor(cycleBytes: 52, baudRate: 4800);
      expect(floor.inMilliseconds, 434);
      expect(floor, greaterThan(kTelemetryInterval));
    });

    test('the same radio at 38400 gets the default, not a faster-than-default floor', () {
      // The budget says 55ms is affordable. That is not a reason to poll
      // that fast: the floor is a ceiling on ambition, never a target.
      expect(telemetryFloor(cycleBytes: 52, baudRate: 38400), lessThan(kTelemetryInterval));
      expect(telemetryIntervalFor(const {}, cycleBytes: 52, baudRate: 38400), kTelemetryInterval);
    });

    test('a link with no stated speed is unmeasured, not infinitely fast', () {
      // A network rig, flrig, rigctld. Nothing here knows what the path
      // costs, so it gets a flat guard rather than an arithmetic answer
      // computed from a baud rate that does not exist.
      expect(telemetryFloor(cycleBytes: 52), kTelemetryFloorFast);
      expect(telemetryIntervalFor(const {}, cycleBytes: 52), kTelemetryInterval);
    });
  });

  group('what the operator asked for', () {
    test('a slower cadence than the budget is honoured', () {
      // The clamp is one-directional: an operator on a shared line, or one
      // who simply does not want their rig chattered at, is allowed to ask
      // for less than the wire could carry.
      expect(
        telemetryIntervalFor(const {telemetryIntervalConfigKey: 2000}, cycleBytes: 52, baudRate: 38400),
        const Duration(milliseconds: 2000),
      );
    });

    test('a faster cadence than the link can carry is clamped to the link', () {
      // Where the arithmetic has to win. Without this, 50 entered on a
      // 4800-baud radio saturates the line and the symptom appears as a
      // radio that will not tune.
      expect(
        telemetryIntervalFor(const {telemetryIntervalConfigKey: 50}, cycleBytes: 52, baudRate: 4800),
        telemetryFloor(cycleBytes: 52, baudRate: 4800),
      );
    });

    test('a value round-tripped through JSON as a string still counts', () {
      // Every stored node config has been through JSON, and a form field can
      // hand back either shape. Read as absent, this would silently revert
      // to the default and the operator's setting would appear not to take.
      expect(
        telemetryIntervalFor(const {telemetryIntervalConfigKey: '750'}, cycleBytes: 0),
        const Duration(milliseconds: 750),
      );
    });
  });

  group('the default a blank field stands for', () {
    test('a driver shows the cadence its own link can afford', () {
      // What the editor puts in the box as a placeholder. The field is left
      // BLANK by default because the usable floor depends on the baud rate
      // beside it — so a prefilled 200 on a 4800-baud radio would be a
      // number the app silently disregards, and an operator who typed it
      // would have every right to believe it took.
      const icom = IcomCivDriver();
      expect(icom.defaultTelemetryInterval(const {'baudRate': 38400}), kTelemetryInterval);
      // Four CI-V meter exchanges at 4800 cannot be had at 200ms.
      expect(
        icom.defaultTelemetryInterval(const {'baudRate': 4800}),
        telemetryFloor(cycleBytes: civMeterCycleBytes, baudRate: 4800),
      );
    });

    test('the number shown is the SLOWEST of the two cadences', () {
      // A blank field means one number for the TX watch and another for the
      // meters. The one worth showing is the one that would surprise: the
      // watch on a 4800-baud Icom still runs at 200ms, and a placeholder
      // saying so would promise meter readings five times a second that the
      // link cannot carry.
      const icom = IcomCivDriver();
      final shown = icom.defaultTelemetryInterval(const {'baudRate': 4800});
      expect(shown, greaterThan(telemetryFloor(cycleBytes: civTxWatchBytes, baudRate: 4800)));
    });

    test('a driver with no meters shows the plain default', () {
      // A Yaesu reads no meters yet, so its only cadence is the one-command
      // TX watch — affordable at 200ms even on the slowest CAT link the
      // radio offers.
      expect(const Ft891Driver().defaultTelemetryInterval(const {'baudRate': 4800}), kTelemetryInterval);
    });

    test('a Yaesu is charged for the meters it will actually ask for', () {
      // The placeholder and the session have to answer the same question,
      // and the answer is per RADIO: a node asks only for the meters its
      // table describes, so a radio with one costs one read and a radio with
      // three costs three. Charged a flat four, the FT-891 — which has no
      // Vdd meter at all — was quoted a cadence a fifth slower than it runs.
      MeterCalibration one(Set<MeterTable> tables) => MeterCalibration(
            model: 'test',
            tables: {for (final table in tables) table: const [MeterPoint(0, 1.0)]},
          );
      MeterCalibrations.instance.setForTesting({
        'one': one({MeterTable.swr}),
        'three': one({MeterTable.swr, MeterTable.power, MeterTable.alc}),
      });
      addTearDown(() => MeterCalibrations.instance.setForTesting({}));

      const driver = Ft891Driver();
      const slow = {'baudRate': 4800};
      final withOne = driver.defaultTelemetryInterval({...slow, meterInfoConfigKey: 'one'});
      final withThree = driver.defaultTelemetryInterval({...slow, meterInfoConfigKey: 'three'});
      final withNone = driver.defaultTelemetryInterval(slow);

      expect(withThree, greaterThan(withOne));
      expect(withOne, greaterThanOrEqualTo(withNone));
      // And a radio with no table at all is only ever charged for the watch.
      expect(withNone, kTelemetryInterval);
    });

    test('a Yaesu with the meter capture on shows the slower cadence it now needs', () {
      // The capture is per NODE, so the default is too: three extra reads on
      // a 4800 line cannot be had as often as one, and an operator who
      // switched the capture on should see the number change.
      expect(
        const Ft891Driver().defaultTelemetryInterval(const {'baudRate': 4800, 'yaesuMeterCapture': true}),
        greaterThan(kTelemetryInterval),
      );
    });

    test('the placeholder ignores what the operator already typed', () {
      // Otherwise the hint would echo the value in the box, and the field
      // would appear to have no default at all.
      expect(
        const Ft891Driver().defaultTelemetryInterval(const {telemetryIntervalConfigKey: 1500, 'baudRate': 38400}),
        kTelemetryInterval,
      );
    });
  });

  group('watching for the radio to be keyed', () {
    test('a watching session asks on the idle cadence and asks the RIGHT question', () {
      // The TX watch is the reason the idle cadence exists at all. Folded
      // into a driver's ordinary 5s state poll instead, a ten-second over
      // would be noticed halfway through and a short one not at all.
      fakeAsync((async) {
        final asked = <bool>[];
        final poller = TelemetryPoller(
          onPoll: asked.add,
          idleInterval: const Duration(milliseconds: 200),
          txInterval: const Duration(milliseconds: 500),
        );
        poller.start();
        async.elapse(const Duration(milliseconds: 650));
        expect(asked, [false, false, false], reason: 'three watches at 200ms, none of them a meter read');
        poller.dispose();
      });
    });

    test('a session that knows its own keying pays for no watch at all', () {
      // The Placeholder Radio keys itself, and a pushing protocol is told.
      // Neither should spend a single exchange asking a question it already
      // has the answer to.
      fakeAsync((async) {
        var polls = 0;
        final poller = TelemetryPoller(onPoll: (_) => polls++);
        async.elapse(const Duration(seconds: 5));
        expect(polls, 0);
        poller.dispose();
      });
    });
  });

  group('reading the meters while transmitting', () {
    test('the first read happens on the transition, not an interval later', () {
      // An S&P call is over inside one poll period. A poller that waited for
      // its first tick would read meters for long overs only — missing
      // exactly the transmission worth measuring, the first one on a band
      // the operator just moved to.
      fakeAsync((async) {
        final asked = <bool>[];
        final poller = TelemetryPoller(onPoll: asked.add, txInterval: const Duration(milliseconds: 200));
        poller.noteTransmitting(true);
        expect(asked, [true]);
        async.elapse(const Duration(milliseconds: 200));
        expect(asked, [true, true]);
        poller.dispose();
      });
    });

    test('the meter cadence replaces the idle one for as long as the rig is keyed', () {
      // Two rates from one setting: on a slow link the meter cycle cannot be
      // asked as often as the one-frame watch, and a poller that kept the
      // idle rate while transmitting would saturate the very link the floor
      // was computed to protect.
      fakeAsync((async) {
        final asked = <bool>[];
        final poller = TelemetryPoller(
          onPoll: asked.add,
          idleInterval: const Duration(milliseconds: 100),
          txInterval: const Duration(milliseconds: 500),
        );
        poller.start();
        poller.noteTransmitting(true);
        asked.clear();
        async.elapse(const Duration(milliseconds: 1100));
        expect(asked.length, 2, reason: 'the 500ms meter cadence, not the 100ms watch');
        expect(asked, everyElement(isTrue));
        poller.dispose();
      });
    });

    test('a restated "still transmitting" does not restart the timer', () {
      // The trap this exists for: the TX watch answers on every cycle, and a
      // poller that treated each answer as a fresh transition would reset
      // its own timer and never fire again — a strip that lights up once and
      // then freezes for the whole over.
      fakeAsync((async) {
        var polls = 0;
        final poller = TelemetryPoller(onPoll: (_) => polls++, txInterval: const Duration(milliseconds: 200));
        poller.noteTransmitting(true);
        async.elapse(const Duration(milliseconds: 150));
        poller.noteTransmitting(true);
        async.elapse(const Duration(milliseconds: 60));
        expect(polls, 2, reason: 'the 200ms tick must have fired despite the restatement at 150ms');
        poller.dispose();
      });
    });

    test('unkeying goes back to watching, and a session that never watched goes quiet', () {
      fakeAsync((async) {
        final asked = <bool>[];
        final poller = TelemetryPoller(
          onPoll: asked.add,
          idleInterval: const Duration(milliseconds: 200),
          txInterval: const Duration(milliseconds: 200),
        );
        poller.start();
        poller.noteTransmitting(true);
        async.elapse(const Duration(milliseconds: 500));
        poller.noteTransmitting(false);
        asked.clear();
        async.elapse(const Duration(milliseconds: 500));
        expect(asked, everyElement(isFalse), reason: 'back to watching, not still reading meters');
        expect(asked, isNotEmpty);
        poller.dispose();
      });
    });

    test('a throwing callback does not end telemetry for the connection', () {
      // Same reasoning AdaptivePoller catches for: a driver that throws once
      // must not take the rest of the transmission with it, and must not
      // escape into the zone.
      fakeAsync((async) {
        var polls = 0;
        final poller = TelemetryPoller(
          onPoll: (_) {
            polls++;
            if (polls == 1) throw StateError('a driver misbehaving');
          },
          txInterval: const Duration(milliseconds: 200),
        );
        poller.noteTransmitting(true);
        async.elapse(const Duration(milliseconds: 450));
        expect(polls, greaterThan(1));
        poller.dispose();
      });
    });

    test('stop() stands the app down without deciding the radio unkeyed', () {
      // stop() is a teardown, not an unkey. It must still leave a later
      // "transmitting" able to start a cycle — the restatement test above
      // proves a report matching what is already known is dropped, so a stop
      // that quietly recorded "receiving" would be indistinguishable from
      // one that recorded nothing until the radio keyed again.
      fakeAsync((async) {
        var polls = 0;
        final poller = TelemetryPoller(onPoll: (_) => polls++, txInterval: const Duration(milliseconds: 200));
        poller.noteTransmitting(true);
        poller.stop();
        polls = 0;
        poller.noteTransmitting(false);
        expect(polls, 0);
        poller.noteTransmitting(true);
        expect(polls, 1, reason: 'the radio saying "transmitting" again must start a new cycle');
        poller.dispose();
      });
    });
  });
}

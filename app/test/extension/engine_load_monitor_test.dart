// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When a busy extension engine, or a slow hook, is reported to the crash
// backend, and when it is deliberately not.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/engine_load_monitor.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

/// A [Random] that always rolls [value].
class _FixedRandom implements Random {
  final double value;
  _FixedRandom(this.value);

  @override
  double nextDouble() => value;
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}

void main() {
  const start = 1000000 * engineLoadBucketMicros;
  late int now;
  late List<String> reports;
  late List<String> titles;
  late bool consented;

  EngineLoadMonitor monitor({double roll = 0.99}) => EngineLoadMonitor(
    consented: () => consented,
    nowMicros: () => now,
    random: _FixedRandom(roll),
    report: (title, body) {
      titles.add(title);
      reports.add(body);
      return true;
    },
  );

  /// Feeds [seconds] of slices, each [busyPercent] busy, advancing the clock.
  void feed(EngineLoadMonitor m, {required int seconds, required int busyPercent, String label = 'scoring.scoreQsos'}) {
    for (var i = 0; i < seconds * 10; i++) {
      final busy = engineLoadBucketMicros * busyPercent ~/ 100;
      final index = now ~/ engineLoadBucketMicros;
      now += engineLoadBucketMicros;
      m.add(EngineLoadBucket(index, busyMicros: busy, longestMicros: busy, longestLabel: label, busyByLabel: {label: busy}));
    }
  }

  setUp(() {
    now = start;
    reports = [];
    titles = [];
    consented = true;
  });

  test('reports once the 10s idle share drops below 30%, naming what kept it busy', () {
    final m = monitor();
    feed(m, seconds: 10, busyPercent: 60);
    expect(reports, isEmpty, reason: '40% idle leaves room; reporting it would be noise');

    feed(m, seconds: 10, busyPercent: 80);
    expect(reports, hasLength(1));
    expect(reports.single, contains('scoring.scoreQsos'));
  });

  test('reports at most once every five minutes', () {
    // A saturated engine breaches on every slice; without the cooldown one
    // busy session would upload ten reports a second.
    final m = monitor();
    feed(m, seconds: 4 * 60, busyPercent: 90);
    expect(reports, hasLength(1));

    // The first report went out once the 10s window had filled (~8s in).
    feed(m, seconds: 70, busyPercent: 90);
    expect(reports, hasLength(2));
  });

  test('a boot that did not draw the sample stays quiet through its first minute', () {
    // Every launch is busy while extensions load and activate; reporting each
    // one would bury the field sessions the report exists to find.
    final m = monitor(roll: 0.99)..debugMarkBoot();
    feed(m, seconds: 59, busyPercent: 90);
    expect(reports, isEmpty);

    feed(m, seconds: 2, busyPercent: 90);
    expect(reports, hasLength(1), reason: 'past startup, the same load is a field problem');
  });

  test('a boot that drew the sample reports its startup, and says so', () {
    final m = monitor(roll: 0.01)..debugMarkBoot();
    feed(m, seconds: 10, busyPercent: 90);
    expect(reports, hasLength(1));
    expect(reports.single, contains('startup, sampled'));
  });

  test('a replacement runtime gets no startup exemption', () {
    // A runtime is replaced because the last one died, and an engine
    // saturated enough to crash-loop would otherwise sit in a fresh
    // exemption on every restart and never be reported. Replaced inside the
    // app's first minute, so an exemption timed from the launch would still
    // cover it.
    final m = monitor(roll: 0.99)..debugMarkBoot();
    feed(m, seconds: 20, busyPercent: 0);
    m.debugMarkBoot();
    feed(m, seconds: 10, busyPercent: 90);
    expect(reports, hasLength(1));
  });

  test('reports nothing while the operator does not share app usage data', () {
    consented = false;
    final m = monitor();
    feed(m, seconds: 10, busyPercent: 90);
    expect(reports, isEmpty);

    consented = true;
    feed(m, seconds: 1, busyPercent: 90);
    expect(reports, hasLength(1), reason: 'consent is read at each report, not once');
  });

  group('a slow hook', () {
    /// [count] calls of [label], each [millis] long, one every [every].
    void calls(
      EngineLoadMonitor m, {
      required int count,
      required int millis,
      Duration every = const Duration(seconds: 1),
      String label = 'batch:lookupCallInfo',
    }) {
      for (var i = 0; i < count; i++) {
        now += every.inMicroseconds;
        m.addSample(HookCallSample(label: label, totalMillis: millis, jsMillis: millis));
      }
    }

    test('is reported with the engine idle, which busy time alone never sees', () {
      // A lookup awaiting the database behind a queue of other reads leaves
      // the engine idle the whole time it waits.
      final m = monitor();
      calls(m, count: EngineLoadMonitor.latencyMinCalls, millis: 1500);

      expect(titles, ['Extension hooks slow']);
      expect(reports.single, contains('batch:lookupCallInfo'));
    });

    test('is a hook slow as a rule over the last minute, not a few slow calls or an old slow stretch', () {
      final m = monitor();
      calls(m, count: EngineLoadMonitor.latencyMinCalls - 1, millis: 3000);
      expect(reports, isEmpty, reason: 'too few calls to say the hook is slow as a rule');

      // The slow calls age out of the window before enough of them land.
      calls(m, count: 1, millis: 3000, every: EngineLoadMonitor.latencyWindow);
      expect(reports, isEmpty);

      calls(m, count: 40, millis: 50);
      expect(reports, isEmpty, reason: 'a fast hook is no report however often it runs');
    });

    test('is a hook doing local work, not an online lookup waiting on the network', () {
      // An import's enrichment runs online lookups back to back; over a slow
      // link each takes a second, and nothing in the app is stalled.
      final m = monitor();
      calls(m, count: 3 * EngineLoadMonitor.latencyMinCalls, millis: 1500, label: 'lookupService.lookupCallInfo');
      expect(reports, isEmpty);

      calls(m, count: EngineLoadMonitor.latencyMinCalls, millis: 1500, label: 'activity.suggest*');
      expect(reports, hasLength(1));
    });

    test('shares one cooldown with a busy engine', () {
      // A busy engine slows its hooks too; one cause would otherwise report
      // twice, under two titles.
      final m = monitor();
      feed(m, seconds: 10, busyPercent: 90);
      calls(m, count: EngineLoadMonitor.latencyMinCalls, millis: 1500, every: const Duration(milliseconds: 100));

      expect(titles, ['Extension engine busy']);
    });
  });
}

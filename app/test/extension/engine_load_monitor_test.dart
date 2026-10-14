// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When a busy extension engine is reported to the crash backend, and when it
// is deliberately not.

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
  late bool consented;

  EngineLoadMonitor monitor({double roll = 0.99}) => EngineLoadMonitor(
    consented: () => consented,
    nowMicros: () => now,
    random: _FixedRandom(roll),
    report: (title, body) {
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
}

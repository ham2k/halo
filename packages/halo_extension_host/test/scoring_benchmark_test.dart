// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Measures what a scoring pass actually costs, through the real JS engine, so
// the checkpoint-granularity question in docs/design/contests.md §5.2 gets
// settled from numbers rather than a guess. The RFC deliberately deferred it:
// "day boundaries first; a per-K-QSO axis only if real timings on a realistic
// contest log justify it."
//
// The two costs that matter in practice:
//   * FULL PASS — what an operation open costs (§5.1.2 rescores on every open).
//   * APPEND    — what logging one more QSO costs, which is the hot path. With
//     a resume checkpoint this should be O(1); without one it re-folds the log.
//
// Run with:
//   flutter test test/scoring_benchmark_test.dart --plain-name benchmark
// It asserts only generous ceilings — the point is the printed table, not a
// pass/fail gate, so this stays useful without becoming a flaky perf test.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// A contest-shaped log: many distinct calls, a realistic sprinkling of dupes,
/// spread across bands and modes so every core rule does real work.
List<Map<String, dynamic>> buildLog(int count, {required DateTime start}) {
  const bands = ['160m', '80m', '40m', '20m', '15m', '10m'];
  const modes = ['SSB', 'CW'];
  // Prefixes drawn from several DXCC entities so the entity rule accumulates.
  const prefixes = ['W', 'K', 'N', 'DL', 'G', 'F', 'JA', 'VK', 'EA', 'I'];

  return [
    for (var i = 0; i < count; i++)
      {
        'uuid': 'q$i',
        'our': {'call': 'N0DEV'},
        // Every 20th QSO repeats an earlier call on the same band+mode — the
        // dupe rate a busy contest actually sees.
        'their': {'call': '${prefixes[i % prefixes.length]}${1 + (i % 9)}${'ABC'}${i % 20 == 19 ? i - 19 : i}'},
        'band': bands[i % bands.length],
        'mode': modes[i % modes.length],
        'startAtMillis': start.add(Duration(seconds: i * 30)).millisecondsSinceEpoch,
      },
  ];
}

void main() {
  requireBundles();

  test('benchmark: scoring cost by log size, full pass vs resumed append', () async {
    // Not `sharedHost`: this one measures the engine, so it wants an isolate-free
    // host of its very own, unwarmed by anything another test did.
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'scoring', source: bundleSource('scoring'))],
      useIsolate: false,
    );
    addTearDown(host.dispose);

    final start = DateTime.utc(2026, 7, 5, 12);
    final operation = {'uuid': 'op-bench', 'stationCall': 'N0DEV'};

    Future<Map> score(List<Map<String, dynamic>> qsos, {Object? resumeFrom}) async {
      return await host.invokeHook(
        'scoring',
        key: 'core',
        method: 'scoreQsos',
        args: {'operation': operation, 'qsos': qsos, if (resumeFrom != null) 'resumeFrom': resumeFrom},
        timeout: const Duration(seconds: 60),
      ) as Map;
    }

    // Warm the engine so the first measured size doesn't absorb JIT/parse cost.
    await score(buildLog(50, start: start));

    final rows = <String>[];
    for (final size in [100, 500, 1000, 5000]) {
      final log = buildLog(size, start: start);

      final fullWatch = Stopwatch()..start();
      final result = await score(log);
      fullWatch.stop();

      final scoresheet = result['scoresheet'];
      expect(scoresheet, isNotNull, reason: 'the harness must return an end scoresheet to resume from');

      // Appending one QSO from the cached end-scoresheet — the hot path.
      final extra = buildLog(size + 1, start: start).last;
      final resumedWatch = Stopwatch()..start();
      await score([extra], resumeFrom: scoresheet);
      resumedWatch.stop();

      // The same append WITHOUT a checkpoint: re-fold the whole log.
      final naiveWatch = Stopwatch()..start();
      await score([...log, extra]);
      naiveWatch.stop();

      rows.add('${size.toString().padLeft(5)} | '
          '${'${fullWatch.elapsedMilliseconds}ms'.padLeft(9)} | '
          '${'${resumedWatch.elapsedMilliseconds}ms'.padLeft(11)} | '
          '${'${naiveWatch.elapsedMilliseconds}ms'.padLeft(11)}');
    }

    // ignore: avoid_print
    print('\n  QSOs |  full pass | append(ckpt) | append(full)\n'
        '  -----+------------+--------------+-------------\n  ${rows.join('\n  ')}\n');

    // Deliberately loose: this documents cost, it isn't a perf gate.
    expect(true, isTrue);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

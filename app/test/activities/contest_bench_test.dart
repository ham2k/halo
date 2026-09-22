// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The benchmark's own conclusions, and the one promise it makes about the
// operator's log.
//
// The harness that RUNS it (`contest_logging_bench.dart`) is deliberately not
// collected by the suite, so without this file the arithmetic that decides
// every verdict — and the cleanup that keeps thousands of synthetic contacts
// out of a real log — would ship with nothing gating them.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/scoring_service.dart';
import 'package:ham2k_logger/tools/contest_bench.dart';

import '../support/halo_test_support.dart';

/// A phase with its per-band costs already measured, so the verdict logic can
/// be exercised without running anything.
BenchPhase _phase(List<double> perBand, {bool growsWithLog = false}) {
  final phase = BenchPhase('p', growsWithLog: growsWithLog);
  for (final value in perBand) {
    phase
      ..micros = (value * 1000).round()
      ..calls = 1
      ..closeBand();
  }
  return phase;
}

/// Eight bands whose cost is exactly proportional to the log — the mean log
/// size in band k is (k + ½) wide, so this is what "scales" must catch.
List<double> _linear() => [for (var k = 0; k < 8; k++) (k + 0.5)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('workload', () {
    String callOf(int i) => ((benchQsoData(i, DateTime.utc(2026)))['their'] as Map)['call'] as String;

    test('a lookup target is a callsign no licence can hold', () {
      // The offset alone only clears THIS run's contacts, and call history
      // reads across every operation — so on a real device an operator's own
      // log could answer for an ordinary-looking synthetic call and turn the
      // sample into the cache hit the phase exists to avoid. A Q prefix is
      // issued to nobody, so no log anywhere can hold it.
      for (final i in [0, 1, 99, 5000]) {
        expect(benchLookupCall(i, 1000), startsWith('Q'));
      }
      // And still distinct per sample, or the pipeline would cache one answer.
      final calls = {for (var i = 0; i < 500; i++) benchLookupCall(i, 1000)};
      expect(calls.length, greaterThan(400));
    });

    test('a lookup target is never a callsign the run already logged', () {
      // The lookup phase documents itself as measuring a callsign the log has
      // never seen. `benchQsoData` HALVES the index for its every-twentieth
      // dupe, so an offset of one run length folds part of the range back onto
      // worked calls — a few percent of samples silently measuring the
      // call-history HIT path, spread evenly across bands, tilting the very
      // slope the verdict reports. Halving twice the length lands at or past
      // the end, which is why the offset is 2x and must stay 2x.
      for (final total in [100, 777, 800, 1000, 2400, 6000]) {
        final logged = {for (var i = 0; i < total; i++) callOf(i)};
        // benchLookupIndex, not a recomputed offset: a test that derives the
        // offset itself agrees with itself and passes however the workload
        // changes.
        final looked = {for (var i = 0; i < total; i++) callOf(benchLookupIndex(i, total))};
        expect(logged.intersection(looked), isEmpty, reason: 'offset must not collide with a logged call at $total QSOs');
      }
    });

    test('one call in twenty repeats, so the dupe path is exercised', () {
      // The flip side: without repeats every contact is trivially new and the
      // worked-before maps never grow, which is the state a quadratic hides in.
      final calls = [for (var i = 0; i < 200; i++) callOf(i)];
      expect(calls.toSet().length, lessThan(calls.length));
    });
  });

  group('verdicts', () {
    test('cost proportional to the log is caught', () {
      final phase = _phase(_linear());
      expect(phase.growsWithTheLog(8), isTrue);
      expect(phase.verdict(8), contains('scales'));
    });

    test('flat cost is not', () {
      final phase = _phase([for (var k = 0; k < 8; k++) 1.0]);
      expect(phase.growsWithTheLog(8), isFalse);
      expect(phase.verdict(8), contains('flat'));
    });

    test('the ceiling is derived from the baseline band actually used', () {
      // The baseline is band 1, not band 0, because band 0 carries warm-up.
      // From band 1 an exactly-linear cost grows 5x, not the 15x it grows from
      // band 0 — and a threshold built for 15 rates this very phase as "mild"
      // while the summary reports a pass. That is the false negative the whole
      // verdict exists to prevent, so it is pinned here rather than trusted.
      final phase = _phase(_linear());
      expect(phase.baselineIndex, 1);
      expect(phase.expectedIfLinear(8), closeTo(5.0, 0.01));
    });

    test('a phase that is SUPPOSED to grow is reported, not flagged', () {
      // A full scoring pass is O(N) by definition. Flagging it would cry wolf
      // on the one number behaving correctly.
      final phase = _phase(_linear(), growsWithLog: true);
      expect(phase.growsWithTheLog(8), isFalse);
      expect(phase.verdict(8), contains('expected'));
    });

    test('a run too short to show a slope claims nothing', () {
      // With one band the baseline IS the last band, so growth is exactly 1.0
      // against a ceiling of 1.0 — which trips a naive threshold and would
      // report "scales" for every timeable phase of a smoke run.
      final phase = _phase([0.5]);
      expect(phase.growsWithTheLog(1), isFalse);
      expect(_phase([0.5, 0.9]).growsWithTheLog(2), isFalse);
    });

    test('a phase that was not measured is excluded from the conclusion, not just its own row', () {
      // The dangerous half: `warning` short-circuiting only `verdict()` leaves
      // an unmeasured phase counting as "not a culprit", so the headline — the
      // one line the operator reads — reports a clean bill of health for a run
      // in which a phase never happened.
      final phase = _phase(_linear())..warning = 'the pipeline never ran';
      expect(phase.growsWithTheLog(8), isFalse, reason: 'noise on a no-op is not a slope');
      expect(phase.verdict(8), startsWith('NOT MEASURED'));

      final result = BenchResult(qsoCount: 2000, phases: [phase]);
      expect(result.culprits, isEmpty);
      expect(result.unmeasured, hasLength(1));
      expect(result.headline, contains('not measured'));
      expect(result.markdownSummary, contains('NOT measured'));
    });

    test('a baseline too fast to time is rated as such, not as infinite growth', () {
      final phase = _phase([0.0, 0.0, 0.0, 5.0]);
      expect(phase.growth, isNull);
      expect(phase.verdict(4), 'too fast');
    });
  });

  group('report', () {
    test('a short run says so instead of claiming a pass', () {
      final result = BenchResult(qsoCount: 100, phases: [_phase(_linear())]);
      expect(result.verdictIsTrustworthy, isFalse);
      expect(result.headline, contains('too few'));
      expect(result.markdownSummary, contains('Too few QSOs'));
    });

    test('a long run names what scaled', () {
      final result = BenchResult(qsoCount: 2000, phases: [_phase(_linear())]);
      expect(result.verdictIsTrustworthy, isTrue);
      expect(result.culprits, hasLength(1));
      expect(result.plainReport, contains('FOUND'));
    });

    test('values carry their unit and their basis', () {
      // Two of the rows are per contact and one is per pass; a reader must not
      // have to remember which while reading a row.
      final phase = BenchPhase('full scoring pass', growsWithLog: true, per: 'pass');
      expect(phase.label, 'full scoring pass (per pass)');
      final result = BenchResult(qsoCount: 2000, phases: [_phase(_linear())]);
      expect(result.markdownSummary, contains('ms'));
      expect(result.markdownSummary, contains('(per QSO)'));
    });
  });

  group('cleanup', () {
    Future<(QsosRepository, OperationsRepository, ScoringService, HaLoDatabase)> stack() async {
      SharedPreferences.setMockInitialValues({});
      final db = HaLoDatabase(NativeDatabase.memory());
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db, sequences: SequencesRepository(db));
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}));
      return (qsos, operations, ScoringService(extensions: extensions, qsos: qsos, operations: operations), db);
    }

    test('a run that cannot start still removes its operation', () async {
      // The refusal here is "no contest scorer": the fake host has no
      // `scoring` hooks stubbed, so no scorer is selected. So this covers the
      // refusal path and the cleanup that follows it, and NOT the measurement
      // loop, which needs a real engine.
      // Without the `finally` a refused run leaves an empty Test Operation in
      // the log every time it is tried.
      final (qsos, operations, scoring, db) = await stack();
      addTearDown(db.close);
      final purged = <String>[];

      await expectLater(
        runContestBench(
          qsos: qsos,
          operations: operations,
          extensions: ExtensionServiceWithFakeHost(FakeExtensionHost({})),
          scoring: scoring,
          qsoCount: 10,
          purge: (uuid) async => purged.add(uuid),
        ),
        throwsA(isA<BenchNotConfigured>().having((e) => e.message, 'message', contains('No contest scorer'))),
      );

      expect(purged, hasLength(1), reason: 'the operation must be removed even when nothing ran');
    });

    test('a cleanup that fails is raised as itself, carrying what the run failed with', () async {
      // The dangerous shape: an `await` in a bare `finally` DISCARDS whatever
      // was unwinding. Here the cleanup failure deliberately displaces the
      // run's own — the dirty log is what the operator must act on — so the
      // displaced error has to travel inside it rather than be lost.
      //
      // The displaced error is the no-scorer refusal (see above); what is pinned
      // is that SOMETHING was carried, not which failure it happened to be.
      final (qsos, operations, scoring, db) = await stack();
      addTearDown(db.close);

      await expectLater(
        runContestBench(
          qsos: qsos,
          operations: operations,
          extensions: ExtensionServiceWithFakeHost(FakeExtensionHost({})),
          scoring: scoring,
          qsoCount: 10,
          purge: (uuid) async => throw StateError('database locked'),
        ),
        throwsA(
          isA<BenchCleanupFailed>()
              .having((e) => '${e.cause}', 'cause', contains('database locked'))
              .having((e) => e.benchError, 'benchError', isA<BenchNotConfigured>()),
        ),
      );
    });
  });
}

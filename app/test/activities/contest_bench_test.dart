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

  group('the scoring phases', () {
    // A fake runtime whose scorers answer, so the measurement loop runs end to
    // end: the timings are meaningless, the GUARDS are what is under test.
    // A phase that measured a no-op must say so, and one that measured an
    // answer must not. A scorer that runs, answers cleanly and folded
    // nothing is the subtler no-op — what a runtime with no log wired does,
    // in microseconds.
    final boardsScored = <int>[];
    // [spotsJudge]: which candidates the board calls worked before — `logged`
    // as a scorer that saw the log would, `none` as one that did not, `first`
    // for a scorer that saw a sliver of it, `all` for a dupe rule broken open.
    Map<String, Object?> answering({bool dupeSeesLog = true, String spotsJudge = 'logged', bool checkpointHasDay = true}) => {
      'scoring:*:scope': [
        {
          'key': 'cqww',
          'ok': true,
          'value': {
            'refTypes': ['cqww'],
          },
        },
      ],
      'scoring:cqww:scoreQsos': (Object? args) {
        final sent = ((args as Map)['qsos'] as List).cast<Map<String, dynamic>>();
        return {
          'qsoScores': {
            for (final q in sent) q['uuid'] as String: const {'value': 1},
          },
          'daySections': const <dynamic>[],
          'operationSummary': {'count': sent.length},
          // A sheet that changes with the log, or the rescore guard reads a
          // repeat as a pass that did not happen.
          'scoresheet': {'worked': sent.length},
          // Without a day the checkpoint is one an older SDK wrote, which the
          // resolver refuses to resume a tail onto — so the resumed rows fold
          // cold and must say so.
          if (checkpointHasDay) 'scoresheetDay': 0,
        };
      },
      'scoring:cqww:scoreQso': {
        'notices': const <String>[],
        'alerts': dupeSeesLog ? const <String>['duplicate'] : const <String>[],
      },
      // Judged per candidate from the payload, as a scorer would: every logged
      // spot worked before, no fresh one. A board that never saw the log still
      // has something to say about every spot — a VHF test flags a missing
      // exchange on each — so a non-empty answer is not evidence the dupe
      // rule ran.
      'scoring:cqww:scoreCandidates': (Object? args) {
        final payload = ((args as Map)['candidates'] as List).cast<Map<String, dynamic>>();
        boardsScored.add(payload.length);
        return {
          for (final entry in payload)
            entry['key'] as String: {
              'notices': const <String>['missingExchange'],
              'alerts':
                  switch (spotsJudge) {
                    'logged' => (entry['key'] as String).startsWith('logged:'),
                    'first' => entry['key'] == 'logged:0',
                    'all' => true,
                    _ => false,
                  }
                  ? const <String>['duplicate']
                  : const <String>[],
            },
        };
      },
    };

    Future<BenchResult> run(Map<String, Object?> stubs) async {
      SharedPreferences.setMockInitialValues({});
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db, sequences: SequencesRepository(db));
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost(stubs));
      final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
      return runContestBench(qsos: qsos, operations: operations, extensions: extensions, scoring: scoring, qsoCount: 24, purge: (uuid) async {});
    }

    BenchPhase phase(BenchResult result, String name) => result.phases.singleWhere((p) => p.name == name);

    test('a dupe check and a spots pass that were answered are measured', () async {
      final sw = Stopwatch()..start();
      final result = await run(answering());
      // A run this small takes milliseconds; a whole second is a wait that
      // ran out its clock somewhere and was not reported.
      expect(sw.elapsed, lessThan(const Duration(seconds: 1)), reason: 'a silent timeout is hiding in the run');
      expect(phase(result, 'dupe check, cold').warning, isNull);
      expect(phase(result, 'dupe check, resumed').warning, isNull);
      expect(phase(result, 'resume resolution').warning, isNull);
      expect(phase(result, 'spots pass').warning, isNull);
      expect(phase(result, 'log stream emission').warning, isNull);
      expect(phase(result, 'dupe check, cold').perBand, everyElement(greaterThan(0)), reason: 'sampled in every band');
      expect(boardsScored, everyElement(kBenchSpotCandidates), reason: 'the whole board reaches the pass');
    });

    test('resumed rows that had no checkpoint to resume from are reported as unmeasured', () async {
      // Cold folds answer "duplicate" exactly as resumed ones do, so the
      // verdict guard cannot tell them apart; the resumed row's flatness is
      // then made of the very fold it claims to skip.
      final result = await run(answering(checkpointHasDay: false));
      expect(phase(result, 'dupe check, resumed').warning, contains('checkpoint to resume from'));
      expect(phase(result, 'spots pass').warning, contains('checkpoint to resume from'));
      expect(phase(result, 'dupe check, cold').warning, isNull);
    });

    test('a dupe check that never saw the log is reported as unmeasured, not as flat', () async {
      // The candidate is a contact the run has logged, so a clean answer is a
      // check that folded nothing — microseconds, and the flat line the
      // resumed row exists to prove. A null (no scorer ran) is caught the same
      // way.
      final result = await run(answering(dupeSeesLog: false));
      expect(phase(result, 'dupe check, cold').warning, contains('saw no log'));
      expect(phase(result, 'dupe check, resumed').warning, contains('saw no log'));
      expect(phase(result, 'spots pass').warning, isNull, reason: 'the two guards are independent');
    });

    test('a spots pass that never saw the log is reported as unmeasured', () async {
      final result = await run(answering(spotsJudge: 'none'));
      expect(phase(result, 'spots pass').warning, contains('saw no log'));
      expect(phase(result, 'dupe check, cold').warning, isNull);
    });

    test('a spots pass that judged one logged spot of twenty, or every spot, is not a pass', () async {
      // One of twenty is a scorer that saw a sliver of the log; every spot
      // — the never-logged half included — is a dupe rule that strikes
      // everything. Both answer "duplicate" somewhere on the board.
      final sliver = await run(answering(spotsJudge: 'first'));
      expect(phase(sliver, 'spots pass').warning, contains('logged half'));
      final everything = await run(answering(spotsJudge: 'all'));
      expect(phase(everything, 'spots pass').warning, contains('logged half'));
    });

    test('the spot candidates are half logged contacts, half callsigns the run never logs', () {
      // Half the board must be dupes or the pass has no dupe rule to run, and
      // half must be new or the pass measures only the strike-through path.
      final start = DateTime.utc(2026);
      final logged = {for (var i = 0; i < 1000; i++) ((benchQsoData(i, start)['their'] as Map)['call'] as String)};
      final candidates = benchSpotCandidates(1000, start, now: 0);
      final calls = {for (final e in candidates.entries) e.key: ((e.value['their'] as Map)['call'] as String)};
      expect(candidates, hasLength(kBenchSpotCandidates));
      expect([
        for (final e in calls.entries)
          if (e.key.startsWith('logged:')) e.value,
      ], everyElement(isIn(logged)));
      expect([
        for (final e in calls.entries)
          if (e.key.startsWith('fresh:')) e.value,
      ], everyElement(isNot(isIn(logged))));
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

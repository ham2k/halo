// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Stage 1 of HALO-119: does logging a long contest get SLOWER as the log
// grows? Simulates a CQ WW run one QSO at a time and reports the per-QSO cost
// of each phase in bands of contacts, so the answer is a shape rather than a
// total.
//
// The question is the SLOPE. A flat line passes however slow the machine is;
// a rising one names a phase that is doing work proportional to the log on
// every contact. Two of those have already been found here by hand — the
// serial high-water mark derived per insert (0.5ms -> 13.8ms per insert at
// 3000 QSOs) and the scoring fold copying its state per QSO (289ms at 5000) —
// so the shape is worth watching rather than assuming.
//
// NOT part of the suite, deliberately: `scripts/test.sh` runs a bare
// `flutter test`, which collects only `*_test.dart`. The `_bench` suffix is
// what keeps a multi-minute run off the critical path — the same convention
// as boundary_bench.dart and data_file_perf_bench.dart. Run it by hand:
//
//   cd app && flutter test test/contest_logging_bench.dart          # 100, a smoke run
//   QSO_COUNT=5000 flutter test test/contest_logging_bench.dart
//   flutter test --dart-define=QSO_COUNT=5000 test/contest_logging_bench.dart
//
// The default is deliberately small: it proves the harness still stands the
// app up and scores a contest, in well under a minute. It is NOT enough to
// judge a slope, and the run says so rather than printing a confident verdict
// — see kVerdictNeedsQsos.
//
// Runs the extension core IN-PROCESS (isolates and FFI don't mix inside
// flutter_test), so it measures the bridge's transport and the scorers' work
// but NOT the queueing a real build sees behind one engine — that is
// HALO-492's instrument, on a real device.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/scoring_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

/// Contest-shaped traffic: enough distinct calls that the worked-before maps
/// grow, a realistic sprinkling of dupes, and zones spread so CQ WW's
/// multiplier set grows too — the state whose per-QSO handling is what a
/// quadratic would show up in.
const _bands = ['160m', '80m', '40m', '20m', '15m', '10m'];
const _prefixes = ['K', 'W', 'N', 'VE', 'G', 'DL', 'JA', 'VK', 'PY', 'EA'];

Map<String, dynamic> _qsoData(int i, DateTime start) {
  // One call in twenty repeats an earlier one, so the dupe path is exercised
  // rather than every contact being trivially new.
  final callIndex = i % 20 == 19 ? (i ~/ 2) : i;
  final prefix = _prefixes[callIndex % _prefixes.length];
  final call = '$prefix${callIndex % 9}${String.fromCharCode(65 + callIndex % 26)}'
      '${String.fromCharCode(65 + (callIndex ~/ 26) % 26)}'
      '${String.fromCharCode(65 + (callIndex ~/ 676) % 26)}';
  return {
    'startAtMillis': start.add(Duration(seconds: i * 20)).millisecondsSinceEpoch,
    'band': _bands[i % _bands.length],
    'mode': i % 3 == 0 ? 'CW' : 'SSB',
    'freq': 14000.0 + (i % 300) / 10,
    'our': {
      'sent': '59${(i % 40) + 1}',
      'refs': [
        {'type': 'cqww', 'ourZone': '5'},
      ],
    },
    'their': {
      'call': call,
      'sent': '59${(i % 40) + 1}',
      'refs': [
        {'type': 'cqww', 'theirZone': '${(callIndex % 40) + 1}'},
      ],
    },
  };
}

/// One phase's cost, accumulated within a band of contacts and then kept per
/// band so the run can end with a verdict instead of a table to eyeball.
class _Phase {
  final String name;

  /// Whether this phase is SUPPOSED to cost more as the log grows. A full
  /// scoring pass is O(N) by definition, so flagging its growth would cry wolf
  /// on the one number that is behaving; a per-contact phase growing is the
  /// actual finding.
  final bool growsWithLog;

  /// Context a reader needs before acting on this phase's verdict — where the
  /// work runs, when that changes what it costs the operator.
  final String? note;

  final List<double> perBand = [];
  int micros = 0;
  int calls = 0;

  _Phase(this.name, {this.growsWithLog = false, this.note});

  /// Closes the current band, remembering what it cost.
  void closeBand() {
    perBand.add(calls == 0 ? 0 : micros / calls / 1000);
    micros = 0;
    calls = 0;
  }

  double get current => calls == 0 ? 0 : micros / calls / 1000;
  double get last => perBand.isEmpty ? 0 : perBand.last;

  /// The baseline the verdict compares against: the SECOND band, not the
  /// first, whenever there are enough bands to have one.
  ///
  /// The first band carries the engine's and the database's warm-up — the
  /// insert phase measures ~60% higher there than in any band after it — and
  /// an inflated baseline understates growth. That is the dangerous direction:
  /// it hides a phase that really is proportional to the log.
  int get baselineIndex => perBand.length >= 3 ? 1 : 0;

  double get first => perBand.isEmpty ? 0 : perBand[baselineIndex];

  /// How much the per-contact cost grew from the baseline band to the last.
  /// Null when the baseline was too fast to time, which makes a ratio
  /// meaningless rather than infinite.
  double? get growth => first < 0.002 ? null : last / first;

  /// [growth] if the cost were exactly proportional to the log.
  ///
  /// Bands are equal width, so the mean log size during band k is (k + ½)·width
  /// and the ratio between the last band and the baseline is
  /// (n − ½) / (baseline + ½). It MUST be derived from the same baseline
  /// [growth] uses: with the baseline at band 0 an exactly-linear cost grows
  /// 15x over eight bands, but at band 1 it grows only 5x, and a threshold
  /// built for the first number silently rates a genuinely linear phase as
  /// mild — the false negative this whole verdict exists to avoid.
  double expectedIfLinear(int bands) => (bands - 0.5) / (baselineIndex + 0.5);

  bool growsWithTheLog(int bands) {
    final g = growth;
    return g != null && !growsWithLog && g >= expectedIfLinear(bands) * 0.5;
  }

  String verdict(int bands) {
    final g = growth;
    if (g == null) return 'too fast to rate';
    if (growsWithLog) return 'grows ${g.toStringAsFixed(1)}x — expected, it is a full pass';
    if (growsWithTheLog(bands)) {
      return 'GROWS WITH THE LOG (${g.toStringAsFixed(1)}x of a possible '
          '${expectedIfLinear(bands).toStringAsFixed(1)}x) — per-contact work proportional to N';
    }
    if (g <= 1.5) return 'FLAT (${g.toStringAsFixed(1)}x)';
    return 'mild growth (${g.toStringAsFixed(1)}x)';
  }
}

/// How many contacts a run needs before its slope means anything.
///
/// Below this the bands are too short for the per-contact costs to rise above
/// timer noise, and the phases that matter most are the cheapest ones — a
/// fingerprint over 90 QSOs is microseconds. Reporting PASS from such a run
/// would be the same lie in a different disguise as a threshold measured
/// against the wrong baseline: a confident answer nothing supports.
const kVerdictNeedsQsos = 800;

/// `--dart-define=QSO_COUNT=n`, or `QSO_COUNT=n` in the environment.
int _qsoCount() {
  const define = String.fromEnvironment('QSO_COUNT');
  final raw = define.isNotEmpty ? define : (Platform.environment['QSO_COUNT'] ?? '');
  final parsed = int.tryParse(raw);
  // A misspelled value is a mistake worth failing on: silently running the
  // 100-QSO default when someone asked for 5000 wastes the run they meant.
  if (raw.isNotEmpty && (parsed == null || parsed < 1)) {
    throw ArgumentError('QSO_COUNT must be a positive integer, got "$raw"');
  }
  return parsed ?? 100;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CQ WW logging: per-QSO cost as the log grows', () async {
    final total = _qsoCount();
    // Every band reports the per-QSO cost of the contacts inside it. Eight of
    // them: enough that the second can serve as a warm-up-free baseline (see
    // [_Phase.first]) and the last still describes a genuinely long log.
    final band = (total / 8).ceil().clamp(5, 1000);

    SharedPreferences.setMockInitialValues({});
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final sequences = SequencesRepository(db);
    final operations = OperationsRepository(db);
    final qsos = QsosRepository(db, sequences: sequences);
    final lookups = LookupRepository(db);

    // `cqww` ships `enabledByDefault: false`, so without an override the
    // runtime loads neither it nor any other contest, `getScoringScopes`
    // answers `core` alone, and the bench would measure an operation no
    // contest scores while looking perfectly healthy.
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setExtensionOverrides({'cqww': true});

    final extensions = ExtensionService()
      ..lookups = lookups
      ..settings = settings;
    await extensions.start();
    addTearDown(() async => extensions.host?.dispose());

    final scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);

    // `/T` marks a Test Operation, which is what `WritePolicy` requires of any
    // write made while the clock is travelled — and what PURGETESTS would
    // clear in a real app. Nothing here touches a real log, but the shape
    // matches what an on-device DEVBENCH must do (stage 2).
    final operation = await operations.create(stationCall: 'N0DEV/T', userTitle: 'CQ WW bench');
    await operations.saveData(Operation(
      uuid: operation.uuid,
      data: {
        ...operation.data,
        'refs': [
          {'type': 'cqww', 'mode': 'SSB', 'ourZone': '5'},
        ],
      },
    ));
    final withRefs = (await operations.get(operation.uuid))!;

    // Assert the contest scorer is actually selected. Without this the bench
    // happily measures an operation nothing scores, and a flat scoring line
    // would mean "no scorer ran", not "scoring is cheap" — the same shape of
    // false pass a missing-bundle guard exists to prevent.
    final scopes = await extensions.getScoringScopes();
    final scorers = ExtensionService.scorersFor(withRefs.data, scopes);
    print('operation refs: ${withRefs.data['refs']}');
    print('scoring scopes: ${scopes.keys.toList()..sort()}');
    expect(
      scorers.map((s) => s.key),
      contains('cqww'),
      reason: 'the cqww scorer must be selected, or this bench measures nothing',
    );
    print('scorers selected: ${scorers.map((s) => s.key).join(', ')}');

    final start = DateTime.utc(2026, 11, 28, 0, 0);
    final insert = _Phase('insert (qsos.add)');
    final fingerprint = _Phase(
      'rescore fingerprint',
      note: 'runs on the UI ISOLATE, on every stream emission — this one costs frames',
    );
    final rescore = _Phase('rescore (all scorers)', growsWithLog: true);
    final readBack = _Phase(
      'read back + decode',
      note: 'decode moves to Isolate.run above 200 rows, so this costs CPU and battery, not frames',
    );
    final phases = [insert, fingerprint, rescore, readBack];

    print('\n${'band'.padRight(12)}${'insert'.padLeft(10)}${'fingerprint'.padLeft(13)}'
        '${'rescore'.padLeft(10)}${'read back'.padLeft(11)}   (ms per QSO)');

    for (var i = 0; i < total; i++) {
      final sw = Stopwatch()..start();
      await qsos.add(operation.uuid, _qsoData(i, start));
      insert
        ..micros += sw.elapsedMicroseconds
        ..calls += 1;

      // Read back the whole log the way OperationView's stream does, then
      // build the same fingerprint its rescore scheduler builds on every
      // emission. Both are O(N) per contact by construction; the point is to
      // put a number on them.
      final sw2 = Stopwatch()..start();
      final all = await qsos.forOperation(operation.uuid);
      readBack
        ..micros += sw2.elapsedMicroseconds
        ..calls += 1;

      final sw3 = Stopwatch()..start();
      all.map((q) => '${q.uuid}:${q.updatedAtMillis ?? ''}').join(',');
      fingerprint
        ..micros += sw3.elapsedMicroseconds
        ..calls += 1;

      // A real session debounces this at 750ms, so it does NOT run per QSO.
      // Once per band is enough to show whether its cost grows with the log,
      // which is the only question here.
      if (i % band == band - 1 || i == total - 1) {
        final sw4 = Stopwatch()..start();
        await scoring.rescoreOperation(withRefs);
        rescore
          ..micros += sw4.elapsedMicroseconds
          ..calls += 1;

        print('${'≤${i + 1}'.padRight(12)}'
            '${insert.current.toStringAsFixed(3).padLeft(10)}'
            '${fingerprint.current.toStringAsFixed(3).padLeft(13)}'
            '${rescore.current.toStringAsFixed(1).padLeft(10)}'
            '${readBack.current.toStringAsFixed(3).padLeft(11)}');
        for (final p in phases) {
          p.closeBand();
        }
      }
    }

    // The verdict, computed rather than left for a reader to eyeball. The
    // table above is the evidence; this is the answer, and it is what makes
    // the bench worth re-running after a change rather than only when someone
    // already suspects something.
    final bands = insert.perBand.length;
    print('\n${'=' * 76}');
    print('$total QSOs, $bands bands, baseline is band ${insert.baselineIndex + 1} '
        '(band 1 carries warm-up).');
    print('A per-contact cost exactly proportional to the log would grow '
        '${insert.expectedIfLinear(bands).toStringAsFixed(1)}x from there; flat work grows ~1x.\n');
    print('${'phase'.padRight(24)}${'first'.padLeft(9)}${'last'.padLeft(9)}   verdict');
    for (final p in phases) {
      print('${p.name.padRight(24)}'
          '${p.first.toStringAsFixed(3).padLeft(9)}'
          '${p.last.toStringAsFixed(3).padLeft(9)}   ${p.verdict(bands)}');
    }

    final culprits = phases.where((p) => p.growsWithTheLog(bands));
    print('');
    if (total < kVerdictNeedsQsos) {
      // Deliberately NOT "PASS". A short run cannot distinguish flat work from
      // work proportional to the log, and saying so is the whole point — the
      // reader who takes silence for a pass is the one this bench exists to
      // stop being wrong.
      print('SMOKE RUN — the harness works; $total QSOs is too few to judge a slope.');
      print('Re-run with QSO_COUNT=$kVerdictNeedsQsos or more for a verdict.');
      if (culprits.isNotEmpty) {
        print('(Even here, ${culprits.map((p) => p.name).join(' and ')} already climbed.)');
      }
    } else if (culprits.isEmpty) {
      print('PASS — no per-contact phase grows with the log.');
    } else {
      print('FOUND — per-contact work proportional to the log, so quadratic over a contest:');
      for (final p in culprits) {
        print('  • ${p.name}: ${p.first.toStringAsFixed(3)} -> ${p.last.toStringAsFixed(3)} ms per QSO');
        if (p.note != null) print('    ${p.note}');
      }
    }
    print('rescore is ms per FULL PASS, not per QSO — it is O(N) by definition.');
    print('=' * 76);
  }, timeout: const Timeout(Duration(minutes: 30)));
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Does logging a long contest get SLOWER as the log grows? Logs a CQ WW shaped
// run one contact at a time through the real repositories, the real extension
// runtime and the real ScoringService, and reports per-QSO cost in bands so the
// answer is a shape rather than a total (HALO-119).
//
// The question is the SLOPE. A flat line passes however slow the device is; a
// rising one names a phase doing work proportional to the log on every contact.
// Two of those have been found here by hand — the serial high-water mark
// derived per insert (0.5ms -> 13.8ms at 3000 QSOs) and the scoring fold
// copying its state per QSO (289ms at 5000) — so the shape is worth watching
// rather than assuming.
//
// It watches for the SECOND of those, not the first. The serial path only runs
// when `qsos.add` is given sequence descriptors, and the workload is CQ WW,
// which declares no serial exchange — so a reintroduced per-insert high-water
// scan would read as a flat `insert` row here. Catching that needs a
// serial-bearing contest (cqwpx, r1-fd, nrrl-nfd) as a second workload.
//
// Lives here rather than in the bench test because DEVBENCH runs it on a real
// device, and `lib` cannot import from `test`. The test harness is a caller,
// not a second copy: two copies drift, and the one in the test is the copy
// nobody would notice drifting.

import 'dart:convert';

import 'package:halo_core/halo_core.dart';

import '../services/extension_service.dart';
import '../services/scoring_service.dart';

/// Contest-shaped traffic: enough distinct calls that the worked-before maps
/// grow, a realistic sprinkling of dupes, and zones spread so CQ WW's
/// multiplier set grows too — the state whose per-QSO handling is where a
/// quadratic shows up.
const _benchBands = ['160m', '80m', '40m', '20m', '15m', '10m'];
const _benchPrefixes = ['K', 'W', 'N', 'VE', 'G', 'DL', 'JA', 'VK', 'PY', 'EA'];

/// How many contacts a run needs before its slope means anything.
///
/// Below this the bands are too short for the per-contact costs to rise above
/// timer noise, and the phases that matter most are the cheapest ones — a
/// fingerprint over 90 QSOs is microseconds. Reporting a pass from such a run
/// would be a confident answer nothing supports.
const kVerdictNeedsQsos = 800;

/// The bands a run is divided into. Eight: enough that the second can serve as
/// a warm-up-free baseline and the last still describes a genuinely long log.
///
/// A FLOOR on the count, not a fixed one — band width is capped at 1000, so a
/// run past 8,000 QSOs gets more than eight. `expectedIfLinear` is handed the
/// real count, so the ceiling follows; what does not follow is a trailing band
/// narrower than the rest, whose mean log size sits below the `(k + ½)·width`
/// this all assumes and so overstates the ceiling slightly.
const kBenchBandCount = 8;

Map<String, dynamic> benchQsoData(int i, DateTime start) {
  // One call in twenty repeats an earlier one, so the dupe path is exercised
  // rather than every contact being trivially new.
  final callIndex = i % 20 == 19 ? (i ~/ 2) : i;
  final prefix = _benchPrefixes[callIndex % _benchPrefixes.length];
  final call = '$prefix${callIndex % 9}${String.fromCharCode(65 + callIndex % 26)}'
      '${String.fromCharCode(65 + (callIndex ~/ 26) % 26)}'
      '${String.fromCharCode(65 + (callIndex ~/ 676) % 26)}';
  return {
    'startAtMillis': start.add(Duration(seconds: i * 20)).millisecondsSinceEpoch,
    'band': _benchBands[i % _benchBands.length],
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

/// Which synthetic contact a lookup samples, for a run of [qsoCount].
///
/// TWICE the run length past [i], so the callsign is one THIS RUN has not
/// logged. Looking up the contact just inserted would measure the hit path —
/// call history matching a row written microseconds earlier — which is a
/// different number from the one the lookup phase documents. A single run's
/// offset does not escape: [benchQsoData] HALVES the index for its
/// every-twentieth dupe, so `i + qsoCount` folds part of the range back onto
/// worked calls. Halving twice the length lands at or past the end.
///
/// Named rather than inlined so a test can check the offset the workload
/// actually uses, instead of recomputing one and agreeing with itself.
int benchLookupIndex(int i, int qsoCount) => i + 2 * qsoCount;

/// The callsign a lookup samples — deliberately one no licence can hold.
///
/// The offset above only clears THIS run's contacts, and `call-history` looks
/// across every operation (`getHistoryForCall` is cross-operation by design),
/// so on a real device an operator whose own log holds `K0ABA` would turn that
/// sample into the cache hit the offset exists to exclude — silently, and only
/// for them. A `Q` prefix is reserved for Q-signals and issued to nobody, so
/// no log can answer for it and the phase measures the same pipeline
/// everywhere.
///
/// The logged CONTACTS keep ordinary calls: they feed entity and zone
/// resolution, which is real work the scorer must do.
String benchLookupCall(int i, int qsoCount) {
  final n = benchLookupIndex(i, qsoCount);
  return 'QQ${n % 10}'
      '${String.fromCharCode(65 + n % 26)}'
      '${String.fromCharCode(65 + (n ~/ 26) % 26)}'
      '${String.fromCharCode(65 + (n ~/ 676) % 26)}';
}

/// One phase's cost, accumulated within a band of contacts and kept per band
/// so a run can end with a verdict instead of a table to eyeball.
class BenchPhase {
  final String name;

  /// Whether this phase is SUPPOSED to cost more as the log grows. A full
  /// scoring pass is O(N) by definition, so flagging its growth would cry wolf
  /// on the one number that is behaving; a per-contact phase growing is the
  /// actual finding.
  final bool growsWithLog;

  /// Context a reader needs before acting on this phase's verdict — where the
  /// work runs, when that changes what it costs the operator.
  final String? note;

  /// What one measurement covers. Named per phase rather than footnoted once,
  /// because a full pass and a per-contact cost are different units sitting in
  /// the same column, and a footnote is something the reader has to remember
  /// while reading the row.
  final String per;

  /// Set when the phase ran but nothing came back — so "flat" can be told
  /// apart from "measured a no-op", which look identical in a timing and only
  /// one of which is an answer.
  String? warning;

  final List<double> perBand = [];
  int micros = 0;
  int calls = 0;

  BenchPhase(this.name, {this.growsWithLog = false, this.note, this.per = 'QSO'});

  /// The phase with its unit basis, which is how it reads in a table.
  String get label => '$name (per $per)';

  void record(int elapsedMicros) {
    micros += elapsedMicros;
    calls += 1;
  }

  /// Closes the current band, remembering what it cost.
  void closeBand() {
    perBand.add(calls == 0 ? 0 : micros / calls / 1000);
    micros = 0;
    calls = 0;
  }

  double get last => perBand.isEmpty ? 0 : perBand.last;

  /// The baseline the verdict compares against: the SECOND band, not the
  /// first, whenever there are enough bands to have one. The first carries the
  /// engine's and the database's warm-up, and an inflated baseline understates
  /// growth — the direction that hides a phase which really is proportional to
  /// the log.
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
  /// mild — the false negative this verdict exists to avoid.
  double expectedIfLinear(int bands) => (bands - 0.5) / (baselineIndex + 0.5);

  bool growsWithTheLog(int bands) {
    // A phase that was not measured cannot have a slope, and its timings are
    // whatever a no-op costs — drifting past the threshold would put it in the
    // report's "scales with the log" list while its own row says NOT MEASURED.
    if (warning != null) return false;
    // Under FOUR bands the ceiling is too close to 1.0 for the 0.5 slack to
    // separate a slope from flatness: at one band the baseline IS the last
    // band (ceiling 1.0, threshold 0.5) and at three the ceiling is 1.67, so
    // the threshold falls to 0.83 and a dead-flat 1.0x clears it. Four bands
    // put the ceiling at 2.33 and the threshold at 1.17, which flat does not
    // reach. A run that short cannot show a slope, so it does not claim one.
    if (perBand.length < 4) return false;
    final g = growth;
    return g != null && !growsWithLog && g >= expectedIfLinear(bands) * 0.5;
  }

  /// One or two words and a number. The ceiling it is judged against is said
  /// once in the header rather than repeated on every row.
  String verdict(int bands) {
    if (warning != null) return 'NOT MEASURED — $warning';
    final g = growth;
    if (g == null) return 'too fast';
    final x = '${g.toStringAsFixed(1)}x';
    if (growsWithLog) return 'expected $x';
    if (growsWithTheLog(bands)) return '**scales $x**';
    if (g <= 1.5) return 'flat $x';
    return 'mild $x';
  }
}

/// The benchmark cannot run as configured — something the operator can fix,
/// not a defect.
///
/// Its own type so it stays OUT of the crash stream: reported as an ordinary
/// error it would be triaged as one, which is the same conflation
/// `captureDiagnostic` exists to avoid for the success case.
class BenchNotConfigured implements Exception {
  BenchNotConfigured(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The benchmark ran, but its Test Operation could not be removed — so the
/// operator's log still holds every synthetic contact it made.
///
/// Its own type because it is the one failure here the operator must act on:
/// every other one leaves nothing behind, and a message saying "benchmark
/// failed" would tell them the opposite of what is true.
class BenchCleanupFailed implements Exception {
  BenchCleanupFailed(this.operationUuid, this.cause, {this.benchError});

  final String operationUuid;
  final Object cause;

  /// What the benchmark itself failed with, when it failed too. Carried rather
  /// than discarded: this exception deliberately displaces it, and the reason
  /// the run went wrong is not something to lose on the way to reporting that
  /// the log is dirty.
  final Object? benchError;

  @override
  String toString() => 'BenchCleanupFailed: the benchmark operation is still in the log — '
      'run PURGETESTS ($cause)${benchError == null ? '' : '; the run itself failed with: $benchError'}';
}

/// Milliseconds, at a precision that suits the magnitude — three decimals on a
/// number like 26.176 is noise dressed as accuracy, and none on 0.743 loses the
/// measurement entirely.
String _ms(double value) {
  if (value >= 100) return '${value.toStringAsFixed(0)} ms';
  if (value >= 10) return '${value.toStringAsFixed(1)} ms';
  return '${value.toStringAsFixed(2)} ms';
}

/// What one run measured, and how to say it.
class BenchResult {
  final int qsoCount;
  final List<BenchPhase> phases;

  BenchResult({required this.qsoCount, required this.phases});

  int get bands => phases.isEmpty ? 0 : phases.first.perBand.length;

  /// True when the run was long enough for its slope to mean anything.
  bool get verdictIsTrustworthy => qsoCount >= kVerdictNeedsQsos;

  List<BenchPhase> get culprits => [for (final p in phases) if (p.growsWithTheLog(bands)) p];

  /// Phases that ran but measured nothing. Reported separately because
  /// "nothing scales with the log" over an unmeasured phase is a clean bill of
  /// health for a run that did not happen.
  List<BenchPhase> get unmeasured => [for (final p in phases) if (p.warning != null) p];

  /// One line, for a command response or a status message — both of which are
  /// capped at a single line.
  String get headline {
    // The one line the operator actually reads, so an unmeasured phase is named
    // here or nowhere: a headline that cannot express "partly unmeasured" would
    // resolve it as a pass.
    final gap = unmeasured.isEmpty ? '' : ', ${unmeasured.length} not measured';
    if (!verdictIsTrustworthy) {
      return 'Bench: $qsoCount QSOs — too few to judge a slope (needs $kVerdictNeedsQsos)$gap';
    }
    if (culprits.isEmpty) return 'Bench: $qsoCount QSOs — no phase grows with the log$gap';
    return 'Bench: $qsoCount QSOs — ${culprits.length} phase(s) grow with the log$gap';
  }

  /// A markdown table, for a notice card (whose stylesheet renders tables).
  String get markdownSummary {
    final ceiling = phases.isEmpty ? 0.0 : phases.first.expectedIfLinear(bands);
    final rows = [
      '| phase | start | end | growth |',
      '| --- | ---: | ---: | --- |',
      for (final p in phases) '| ${p.label} | ${_ms(p.first)} | ${_ms(p.last)} | ${p.verdict(bands)} |',
    ];
    final tail = <String>[
      '',
      if (!verdictIsTrustworthy)
        'Too few QSOs to judge a slope — re-run with at least $kVerdictNeedsQsos.'
      else if (culprits.isEmpty)
        'Nothing scales with the log.'
      else ...[
        'Scales with the log:',
        for (final p in culprits) '- **${p.name}**${p.note == null ? '' : ' — ${p.note}'}',
      ],
      for (final p in unmeasured) '- **${p.name}** was NOT measured: ${p.warning}',
    ];
    return [
      '$qsoCount QSOs, $bands bands. Cost proportional to the log '
          'would grow ${ceiling.toStringAsFixed(1)}x.',
      '',
      ...rows,
      ...tail,
    ].join('\n');
  }

  /// The whole thing as plain text — what gets uploaded and what the copy
  /// action puts on the clipboard. Carries every band, not just the endpoints,
  /// because the endpoints are a summary and this is the evidence.
  String get plainReport {
    final ceiling = phases.isEmpty ? 0.0 : phases.first.expectedIfLinear(bands);
    final out = <String>[
      '$qsoCount QSOs, $bands bands. Proportional to the log = ${ceiling.toStringAsFixed(1)}x growth.',
      '',
    ];
    for (final p in phases) {
      out.add('${p.label}, ms: ${p.perBand.map((v) => v.toStringAsFixed(3)).join(', ')}');
      out.add('  -> ${p.verdict(bands).replaceAll('**', '')}${p.note == null ? '' : ' [${p.note}]'}');
    }
    out.add('');
    out.add(verdictIsTrustworthy
        ? (culprits.isEmpty ? 'No per-contact phase grows with the log.' : 'FOUND: ${culprits.map((p) => p.name).join(', ')}')
        : 'SMOKE RUN — needs $kVerdictNeedsQsos QSOs for a verdict.');
    return out.join('\n');
  }
}

/// Runs the benchmark and returns what it measured.
///
/// Creates a `/T` Test Operation, logs [qsoCount] contacts into it ONE AT A
/// TIME, and purges it afterwards. One at a time is the whole point:
/// `writeBatch` takes a single drift batch and skips exactly the per-insert
/// costs where the known quadratic lived, so a batched run would measure
/// nothing worth measuring.
///
/// What the lookup phase measures, and does not: one offline lookup of a
/// callsign the log has never seen. Every registered source runs and queries
/// locally; for synthetic calls they find nothing, so the number is the
/// PIPELINE's cost — the bridge crossing plus each source's local query — and
/// not the cost of a cache hit. That is the honest reading, and it is still the
/// cost the app pays per callsign typed while offline.
///
/// The contacts are REAL while the run lasts: a Test Operation syncs like any
/// other, so a sync-enabled device uploads them and may show them briefly on
/// the operator's other devices before the purge tombstones them back out. That
/// traffic also competes with the timings being measured. A run killed
/// mid-flight (a force quit, or a watchdog on a phone the workload has blocked)
/// leaves the operation behind entirely; PURGETESTS is the way back.
///
/// [purge] does the cleanup — the caller supplies it because the transaction
/// that hard-deletes an operation and its QSOs together lives on `HaLoServices`
/// and this tool has no business reaching for the database directly. It runs
/// in a `finally`: a bench that threw half way through must not leave a few
/// thousand synthetic contacts in somebody's log.
Future<BenchResult> runContestBench({
  required QsosRepository qsos,
  required OperationsRepository operations,
  required ExtensionService extensions,
  required ScoringService scoring,
  required Future<void> Function(String uuid) purge,
  int qsoCount = 100,
  void Function(int done, int total)? onProgress,
}) async {
  final band = (qsoCount / kBenchBandCount).ceil().clamp(1, 1000);

  // Reading the whole log back costs O(N), so doing it once per contact makes
  // the BENCH quadratic — at 500 QSOs it was already the dominant per-contact
  // cost, and a 6,000-QSO run spent minutes there, on the UI isolate, spawning
  // an isolate per read. The measurement does not need every contact: it needs
  // enough samples per band to average honestly. ~40 keeps the sampled mean log
  // size at the band's own mean, which is what `expectedIfLinear` assumes — so
  // the ceiling stays right and only the cost drops.
  final sampleEvery = (band ~/ 40).clamp(1, 1 << 30);

  final insert = BenchPhase('insert');
  final fingerprint = BenchPhase(
    'rescore fingerprint',
    note: 'on the UI isolate, every stream emission — this one costs frames',
  );
  final rescore = BenchPhase('full scoring pass', growsWithLog: true, per: 'pass');
  final readBack = BenchPhase(
    'read back + decode',
    note: 'decoded off the UI isolate above 200 rows, so this costs battery, not frames',
  );
  // `online: false` is the app's own offline mode: every lookup hook is asked
  // to stay local — call history, call notes, cached data files — which is what
  // makes this reproducible and free of an 8-second network timeout per call.
  // It is not the stub: that short-circuits BEFORE the hooks and would measure
  // nothing at all.
  //
  // Worth watching as the log grows rather than assumed flat, because the
  // offline sources query the log itself.
  final lookup = BenchPhase(
    'offline lookup',
    note: 'the pipeline\'s cost with its sources finding nothing — see the doc on runContestBench',
  );
  final phases = [insert, fingerprint, rescore, readBack, lookup];

  final operation = await operations.create(stationCall: 'N0DEV/T', userTitle: 'Benchmark');
  Object? benchError;
  var lookupsRan = 0;
  // Counted here, NOT read off `BenchPhase.calls`: closeBand() zeroes that at
  // every band boundary and the loop always closes one on the last contact, so
  // after the loop every phase reports zero samples and a `ran < calls` test
  // silently becomes `ran < 0`.
  var lookupSamples = 0;
  var rescorePasses = 0;
  var scoredPasses = 0;
  String? lastScoreStamp;
  try {
    await operations.saveData(Operation(
      uuid: operation.uuid,
      data: {
        ...operation.data,
        'refs': [
          {'type': 'cqww', 'mode': 'SSB', 'ourZone': '5'},
        ],
      },
    ));
    final scored = (await operations.get(operation.uuid))!;

    // Without a contest scorer selected this measures an operation nothing
    // scores, and a flat scoring column would mean "nothing ran" rather than
    // "scoring is cheap" — indistinguishable in the output, so it is checked
    // rather than hoped for. Contests ship disabled by default, which is
    // exactly how a real device reaches this with none loaded.
    if (ExtensionService.stubLookups) {
      // The stub answers before any hook runs, so the lookup phase would time a
      // canned result in microseconds and report the pipeline as nearly free.
      // An environment variable is enough to turn it on, and a developer with
      // it exported is exactly this command's audience.
      throw BenchNotConfigured(
        'Lookups are stubbed (HALO_STUB_LOOKUPS) — the lookup phase would measure a canned answer.',
      );
    }

    final scorers = ExtensionService.scorersFor(scored.data, await extensions.getScoringScopes());
    if (!scorers.any((s) => s.key == 'cqww')) {
      throw BenchNotConfigured(
        'No contest scorer is selected — enable the CQ WW extension in Settings. '
        'Without one this would measure an operation nothing scores.',
      );
    }

    final start = DateTime.utc(2026, 11, 28, 0, 0);
    for (var i = 0; i < qsoCount; i++) {
      final sw = Stopwatch()..start();
      await qsos.add(operation.uuid, benchQsoData(i, start));
      insert.record(sw.elapsedMicroseconds);

      // Read the whole log back the way the operation view's stream does, then
      // build the same fingerprint its rescore scheduler builds on every
      // emission. Both are what ONE emission costs — sampled rather than run
      // per contact, for the reason `sampleEvery` gives.
      if (i % sampleEvery == 0) {
        final sw2 = Stopwatch()..start();
        final all = await qsos.forOperation(operation.uuid);
        readBack.record(sw2.elapsedMicroseconds);

        final sw3 = Stopwatch()..start();
        all.map((q) => '${q.uuid}:${q.updatedAtMillis ?? ''}').join(',');
        fingerprint.record(sw3.elapsedMicroseconds);

        // What typing one callsign costs. Sampled with the rest for the same
        // reason, though in real use it runs once per contact.
        //
        final data = benchQsoData(benchLookupIndex(i, qsoCount), start);
        final call = benchLookupCall(i, qsoCount);
        final sw5 = Stopwatch()..start();
        final answer = await extensions.lookupCall(
          call,
          qso: data,
          operation: scored.data,
          online: false,
        );
        lookup.record(sw5.elapsedMicroseconds);
        lookupSamples++;
        // Null means the pipeline did not run at all — a dead runtime, the one
        // case where this phase's timings describe nothing. A non-null answer
        // with only the pre-annotation in it is NOT that: it is what an offline
        // lookup of an unworked callsign legitimately returns, and the cost of
        // getting there is exactly what this phase exists to measure.
        if (answer != null) lookupsRan++;
      }

      // A real session debounces the rescore, so it does NOT run per contact.
      // Once per band is enough to show whether its cost grows with the log.
      if (i % band == band - 1 || i == qsoCount - 1) {
        // Re-read, OUTSIDE the stopwatch. A snapshot taken before the first
        // contact carries no `huntedRefTypes`, so `rescoreOperation`'s
        // only-when-it-changes guard fails on every pass and it writes
        // local_data — plus the operation-stream rebuild that triggers —
        // inside the measurement. The real app pays that roughly once.
        final fresh = (await operations.get(operation.uuid)) ?? scored;

        final sw4 = Stopwatch()..start();
        await scoring.rescoreOperation(fresh);
        rescore.record(sw4.elapsedMicroseconds);
        rescorePasses++;
        // `rescoreOperation` reports its own failures and returns normally, so
        // a pass that threw still leaves a timing here — labelled "expected",
        // for work that did not happen. The scoresheet it writes is the only
        // evidence it ran; selecting a scorer up front proves one was CHOSEN,
        // not that it produced anything.
        // Per pass, not ever-once. `localData` is a field on the operation and
        // NOT a key inside `data` — reading it from `data` finds nothing and
        // the guard becomes a permanent false alarm. But merely being non-null
        // is not evidence either: `updateLocalData` patches rather than
        // replaces and a failed pass never clears the key, so once any band has
        // scored, "non-null" is true forever and every later failure is
        // invisible. The sheet is rewritten wholesale each pass and the log
        // grew since the last one, so a sheet that did NOT change is a pass
        // that did not happen.
        final sheet = (await operations.get(operation.uuid))?.localData['scoring'];
        final stamp = sheet == null ? null : jsonEncode(sheet);
        if (stamp != null && stamp != lastScoreStamp) {
          scoredPasses++;
          lastScoreStamp = stamp;
        }
        for (final p in phases) {
          p.closeBand();
        }
      }
      onProgress?.call(i + 1, qsoCount);
    }
  } catch (error) {
    // Held so the cleanup failure below can carry it. An `await` in a bare
    // `finally` that throws DISCARDS whatever was already unwinding, and this
    // one does throw deliberately — so the thing it displaces travels inside it
    // rather than being lost.
    benchError = error;
    rethrow;
  } finally {
    try {
      await purge(operation.uuid);
    } catch (error) {
      // Deliberately outranks the benchmark's own failure: every other outcome
      // here leaves the operator's log as it found it, and this one does not.
      // "Benchmark failed" would tell them the opposite of what is true.
      throw BenchCleanupFailed(operation.uuid, error, benchError: benchError);
    }
  }

  // A lookup that never answers times the same as a fast one. Without this the
  // phase reports "flat" whether the offline sources are doing their job or
  // are not installed at all — the second dressed as the first.
  if (lookupsRan == 0) {
    lookup.warning = 'no lookup answered — the pipeline is failing, or there is no runtime';
  } else if (lookupsRan < lookupSamples) {
    lookup.warning = 'only $lookupsRan of $lookupSamples lookups answered';
  }
  if (scoredPasses == 0) {
    rescore.warning = 'no scoring pass produced a scoresheet';
  } else if (scoredPasses < rescorePasses) {
    rescore.warning = 'only $scoredPasses of $rescorePasses scoring passes produced one';
  }

  return BenchResult(qsoCount: qsoCount, phases: phases);
}

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

import 'dart:async';
import 'dart:convert';

import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show judgesWorkedBefore;

import '../services/extension_scoring.dart' show kScoreCandidatesTimeout, kScoreQsoTimeout;
import '../services/extension_service.dart';
import '../services/scoring_service.dart';

/// Contest-shaped traffic: enough distinct calls that the worked-before maps
/// grow, a realistic sprinkling of dupes, and zones spread so CQ WW's
/// multiplier set grows too — the state whose per-QSO handling is where a
/// quadratic shows up.
const _benchBands = ['160m', '80m', '40m', '20m', '15m', '10m'];
const _benchPrefixes = ['K', 'W', 'N', 'VE', 'G', 'DL', 'JA', 'VK', 'PY', 'EA'];

/// Where a timed phase leaves a result it has no use for, so the phase is
/// not dead code to the compiler.
Object? benchSink;

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
  final call =
      '$prefix${callIndex % 9}${String.fromCharCode(65 + callIndex % 26)}'
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

/// How many spot-shaped candidates one spots pass scores. A board's worth:
/// enough that the per-candidate work is the pass's cost, not the bridge
/// crossing.
const kBenchSpotCandidates = 40;

/// The candidates a spots pass scores, keyed as the panel keys them. Half
/// are contacts this run logs from the start (so the dupe rule has work to
/// do), half are callsigns it never logs — the same offset trick as
/// [benchLookupIndex], one run further out so the two samples never meet.
/// The shape follows `spotCandidateQso`: a spot is judged as a contact made
/// NOW, with the spot's band and mode and no exchange.
Map<String, Map<String, dynamic>> benchSpotCandidates(int qsoCount, DateTime start, {required int now}) {
  Map<String, dynamic> candidate(int i) {
    final data = benchQsoData(i, start);
    return {
      'their': {'call': (data['their'] as Map)['call']},
      'band': data['band'],
      'mode': data['mode'],
      'freq': data['freq'],
      'refs': const <Map<String, dynamic>>[],
      'startAtMillis': now,
    };
  }

  return {
    for (var k = 0; k < kBenchSpotCandidates ~/ 2; k++) 'logged:$k': candidate(k),
    for (var k = 0; k < kBenchSpotCandidates ~/ 2; k++) 'fresh:$k': candidate(3 * qsoCount + k),
  };
}

/// Whether a spots pass's [board] judged the candidates as a scorer that saw
/// the log would: every `logged:k` the run has reached — the first
/// [loggedSoFar] contacts — worked before, and no `fresh:*` at all.
bool benchSpotBoardJudged(Map<String, Map<String, dynamic>> board, {required int loggedSoFar}) {
  for (var k = 0; k < kBenchSpotCandidates ~/ 2 && k < loggedSoFar; k++) {
    final verdict = board['logged:$k'];
    if (verdict == null || !judgesWorkedBefore(verdict)) return false;
  }
  for (var k = 0; k < kBenchSpotCandidates ~/ 2; k++) {
    final verdict = board['fresh:$k'];
    if (verdict != null && judgesWorkedBefore(verdict)) return false;
  }
  return true;
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
  String toString() =>
      'BenchCleanupFailed: the benchmark operation is still in the log — '
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

  List<BenchPhase> get culprits => [
    for (final p in phases)
      if (p.growsWithTheLog(bands)) p,
  ];

  /// Phases that ran but measured nothing. Reported separately because
  /// "nothing scales with the log" over an unmeasured phase is a clean bill of
  /// health for a run that did not happen.
  List<BenchPhase> get unmeasured => [
    for (final p in phases)
      if (p.warning != null) p,
  ];

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
    final out = <String>['$qsoCount QSOs, $bands bands. Proportional to the log = ${ceiling.toStringAsFixed(1)}x growth.', ''];
    for (final p in phases) {
      out.add('${p.label}, ms: ${p.perBand.map((v) => v.toStringAsFixed(3)).join(', ')}');
      out.add('  -> ${p.verdict(bands).replaceAll('**', '')}${p.note == null ? '' : ' [${p.note}]'}');
    }
    out.add('');
    out.add(
      verdictIsTrustworthy
          ? (culprits.isEmpty ? 'No per-contact phase grows with the log.' : 'FOUND: ${culprits.map((p) => p.name).join(', ')}')
          : 'SMOKE RUN — needs $kVerdictNeedsQsos QSOs for a verdict.',
    );
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
/// other, so a sync-enabled device uploads them, and the operator's other
/// devices that pull them keep them until PURGETESTS runs there too: the purge
/// removes them from the server without telling any other device. That traffic
/// also competes with the timings being measured. A run killed
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
  final fingerprint = BenchPhase('rescore fingerprint', note: 'on the UI isolate, every stream emission — this one costs frames');
  final rescore = BenchPhase('full scoring pass', growsWithLog: true, per: 'pass');
  // O(N) by nature, and since the log stream patches its list this is paid
  // once per view open rather than per emission — so its growth is expected,
  // not a finding. The per-emission cost is the `log stream emission` row.
  final readBack = BenchPhase(
    'read back + decode',
    growsWithLog: true,
    note: 'the whole log, as the operation view reads it once at open; decoded off the UI isolate above 200 rows',
  );
  // `online: false` is the app's own offline mode: every lookup hook is asked
  // to stay local — call history, call notes, cached data files — which is what
  // makes this reproducible and free of an 8-second network timeout per call.
  // It is not the stub: that short-circuits BEFORE the hooks and would measure
  // nothing at all.
  //
  // Worth watching as the log grows rather than assumed flat, because the
  // offline sources query the log itself.
  final lookup = BenchPhase('offline lookup', note: 'the pipeline\'s cost with its sources finding nothing — see the doc on runContestBench');
  // The dupe check the logging controls run after each call-field change,
  // twice: once folding the whole log, as a keystroke does when no rescore
  // checkpoint fits, and once resumed from the last rescore plus the contacts
  // since it, as the logging panel wires it. The fold is O(N) by nature and
  // the row documents it; the resumed row is the one that must stay flat.
  // Between the once-per-band rescores the tail grows to a band's width, so
  // every band's mean sits at the same half-band tail — flat is the shape.
  final dupeCold = BenchPhase(
    'dupe check, cold',
    growsWithLog: true,
    per: 'keystroke',
    note: 'a keystroke with no rescore checkpoint to resume from folds the whole log',
  );
  final dupeResumed = BenchPhase(
    'dupe check, resumed',
    per: 'keystroke',
    note: 'resumed from the last rescore plus the contacts since — the hook alone; the panel also pays the resolve row per keystroke',
  );
  // Deciding whether the checkpoint fits digests the whole held log, so the
  // panel pays this per keystroke and it is linear by nature — timed apart
  // from the hook, or the resumed row could never be read as flat.
  final resolveResume = BenchPhase(
    'resume resolution',
    growsWithLog: true,
    per: 'keystroke',
    note: 'deciding whether the last rescore\'s checkpoint fits the held log — a digest over every contact, on the UI isolate',
  );
  final spotsPass = BenchPhase(
    'spots pass',
    per: 'pass',
    note: '$kBenchSpotCandidates spot-shaped candidates, resumed the way the spots panel does after each contact; the scorers\' work, not the panel\'s',
  );
  // What the operation view's log stream costs after an insert: from the
  // insert's start to the list it emits, on the same isolate. Flat is the
  // point — a stream that re-read the log would grow with it.
  final emission = BenchPhase('log stream emission', note: 'from an insert to the list the log stream emits, on the UI isolate — this one costs frames');
  final phases = [insert, emission, fingerprint, rescore, readBack, lookup, dupeCold, resolveResume, dupeResumed, spotsPass];

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
  var dupeSamples = 0;
  var dupeColdAnswered = 0;
  var dupeResumedAnswered = 0;
  var spotsSamples = 0;
  var spotsAnswered = 0;
  var dupeTimedOut = 0;
  var spotsTimedOut = 0;
  // Samples taken after the first rescore, when a checkpoint exists to resume
  // from, and how many of them the resolver handed one — the evidence that
  // the resumed rows measured a resume and not a second cold fold, which
  // answers "duplicate" just as well.
  var resumableSamples = 0;
  var resumedSamples = 0;
  var emissionsMissed = 0;
  Object? streamError;
  // The log stream, followed the way the operation view follows it. A
  // completer per awaited emission, so an insert is timed to the emission
  // that follows it and nothing else: the once-per-band rescore's score-cache
  // write emits too, and is waited out before the next contact so it cannot
  // be mistaken for that contact's. Created BEFORE the subscription: the
  // stream reads and emits at listen time, and a completer registered after
  // that waits for an emission already gone.
  Completer<void>? awaited;
  final primed = awaited = Completer<void>();
  // The log as the stream last emitted it — what the operation view, the
  // logging panel and the spots board hold, and what they fingerprint and
  // resolve the resume from. Not a fresh read: that is a different list with
  // a different cost, and the read-back row measures it on its own.
  List<Qso> latest = const [];
  final follower = qsos
      .watchForOperation(operation.uuid)
      .listen(
        (log) {
          latest = log;
          awaited?.complete();
          awaited = null;
        },
        onError: (Object error) {
          streamError ??= error;
          awaited?.completeError(error);
          awaited = null;
        },
      );
  // Whether the emission came before the wait ran out. A wait that ran out
  // hands its completer back so a late emission cannot complete the NEXT
  // wait's in its place and time a contact the stream never answered.
  Future<bool> awaitEmission(Completer<void> next) async {
    try {
      await next.future.timeout(const Duration(seconds: 5));
      return true;
    } on TimeoutException {
      if (identical(awaited, next)) awaited = null;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> nextEmission() => awaitEmission(awaited = Completer<void>());

  try {
    await operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'cqww', 'mode': 'SSB', 'ourZone': '5'},
          ],
        },
      ),
    );
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
      throw BenchNotConfigured('Lookups are stubbed (HALO_STUB_LOOKUPS) — the lookup phase would measure a canned answer.');
    }

    final scorers = ExtensionService.scorersFor(scored.data, await extensions.getScoringScopes());
    if (!scorers.any((s) => s.key == 'cqww')) {
      throw BenchNotConfigured(
        'No contest scorer is selected — enable the CQ WW extension in Settings. '
        'Without one this would measure an operation nothing scores.',
      );
    }

    final start = DateTime.utc(2026, 11, 28, 0, 0);
    final spotCandidates = benchSpotCandidates(qsoCount, start, now: start.millisecondsSinceEpoch);
    // The initial read is the stream's own, not any contact's — and a stream
    // that never makes it has nothing to measure.
    if (!await awaitEmission(primed)) {
      throw StateError('the log stream never emitted its initial read${streamError == null ? '' : ': $streamError'}');
    }
    for (var i = 0; i < qsoCount; i++) {
      final sw = Stopwatch()..start();
      final emitted = nextEmission();
      await qsos.add(operation.uuid, benchQsoData(i, start));
      insert.record(sw.elapsedMicroseconds);
      if (await emitted) {
        emission.record(sw.elapsedMicroseconds);
      } else {
        emissionsMissed++;
      }

      // Read the whole log back the way the operation view does when it opens,
      // then build the fingerprint its rescore scheduler builds on every
      // emission — over the emitted list, as it does. Sampled rather than run
      // per contact, for the reason `sampleEvery` gives.
      if (i % sampleEvery == 0) {
        final sw2 = Stopwatch()..start();
        await qsos.forOperation(operation.uuid);
        readBack.record(sw2.elapsedMicroseconds);

        // The view's own fingerprint over the list the stream handed it,
        // kept in a sink so an optimizing build cannot drop the work timed.
        final sw3 = Stopwatch()..start();
        benchSink = '${latest.length}:${checkpointDigestOf(latest)}';
        fingerprint.record(sw3.elapsedMicroseconds);

        // What typing one callsign costs. Sampled with the rest for the same
        // reason, though in real use it runs once per contact.
        //
        final data = benchQsoData(benchLookupIndex(i, qsoCount), start);
        final call = benchLookupCall(i, qsoCount);
        final sw5 = Stopwatch()..start();
        final answer = await extensions.lookupCall(call, qso: data, operation: scored.data, online: false);
        lookup.record(sw5.elapsedMicroseconds);
        lookupSamples++;
        // Null means the pipeline did not run at all — a dead runtime, the one
        // case where this phase's timings describe nothing. A non-null answer
        // with only the pre-annotation in it is NOT that: it is what an offline
        // lookup of an unworked callsign legitimately returns, and the cost of
        // getting there is exactly what this phase exists to measure.
        if (answer != null) lookupsRan++;

        // A keystroke through the dupe check, cold and then resumed. The
        // candidate is the contact just logged — a certain duplicate — so an
        // answer that does not say so is a check that never saw the log,
        // which a runtime with no log wired answers in microseconds and a flat
        // row would dress as a pass. The operation is re-read so the resume
        // sees the last rescore's checkpoints, as the panel's does; the read
        // itself is outside the stopwatch, as it is a stream emission's in
        // the app.
        final current = (await operations.get(operation.uuid)) ?? scored;
        final hunted = ((current.localData['huntedRefTypes'] as List?) ?? const []).whereType<String>().toSet();
        // With the uuid, as the logging controls send it: it is how the hook
        // reaches the log, and without it the fold is of an empty log.
        final scoredOperation = {...current.data, 'uuid': operation.uuid};
        final worked = benchQsoData(i, start);
        dupeSamples++;
        // A scorer that ran out its clock still yields an answer: the others'
        // — core's dupe rule says "duplicate" on its own — merged over a
        // timing that is the timeout, not a measurement.
        final sw6 = Stopwatch()..start();
        final cold = await extensions.scoreQso(operation: scoredOperation, qso: worked, huntedRefTypes: hunted);
        dupeCold.record(sw6.elapsedMicroseconds);
        if (sw6.elapsed >= kScoreQsoTimeout) dupeTimedOut++;
        if (cold != null && judgesWorkedBefore(cold)) dupeColdAnswered++;

        final sw9 = Stopwatch()..start();
        final resume = resolveScoringResume(
          scoring: current.localData['scoring'] as Map<String, dynamic>?,
          operationUpdatedAtMillis: current.updatedAtMillis,
          qsos: latest,
        );
        resolveResume.record(sw9.elapsedMicroseconds);
        if (rescorePasses > 0) {
          resumableSamples++;
          if (resume != null && resume.tail.isNotEmpty) resumedSamples++;
        }
        final sw7 = Stopwatch()..start();
        final resumed = await extensions.scoreQso(operation: scoredOperation, qso: worked, huntedRefTypes: hunted, resume: resume);
        dupeResumed.record(sw7.elapsedMicroseconds);
        if (sw7.elapsed >= kScoreQsoTimeout) dupeTimedOut++;
        if (resumed != null && judgesWorkedBefore(resumed)) dupeResumedAnswered++;

        // A spots board's pass over its candidates, resumed the same way.
        spotsSamples++;
        final sw8 = Stopwatch()..start();
        final board = await extensions.scoreCandidates(
          operation: current.data,
          operationUuid: operation.uuid,
          candidates: spotCandidates,
          resume: resume,
          huntedRefTypes: hunted,
        );
        spotsPass.record(sw8.elapsedMicroseconds);
        if (sw8.elapsed >= kScoreCandidatesTimeout) spotsTimedOut++;
        // Every candidate this run has logged so far — same band and mode —
        // must come back worked before, and none of the never-logged ones
        // may: a pass judging one of twenty saw a sliver of the log, and one
        // striking every call has no dupe rule at all. A null is no pass.
        if (board != null && benchSpotBoardJudged(board, loggedSoFar: i + 1)) spotsAnswered++;
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
        final scoreCacheWritten = nextEmission();
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
          // The pass's score-cache write reaches the log stream after the pass
          // returns; waited out here so the next contact's emission is its
          // own. Only a pass that wrote a sheet wrote a score cache, and one
          // whose write never shows is the stream's failure, not the pass's.
          if (!await scoreCacheWritten) emission.warning ??= 'a scoring pass\'s score-cache write never reached the log stream';
        } else if (identical(awaited, scoreCacheWritten)) {
          awaited = null;
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
    } finally {
      // After the purge, never ahead of it: nothing here may stand between
      // the operator and the cleanup.
      await follower.cancel();
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
  // A dupe check that never saw the log costs what a no-op costs and reads as
  // flat — with the resumed row, flat is the very claim, so it has to be
  // earned by the verdict the candidate was chosen to force.
  if (dupeTimedOut > 0) {
    dupeCold.warning = dupeResumed.warning = '$dupeTimedOut dupe checks ran out the scorer\'s clock — those timings are the timeout';
  } else {
    if (dupeColdAnswered == 0) {
      dupeCold.warning = 'no dupe check called a logged contact a duplicate — the scorer saw no log, or never ran';
    } else if (dupeColdAnswered < dupeSamples) {
      dupeCold.warning = 'only $dupeColdAnswered of $dupeSamples dupe checks called a logged contact a duplicate';
    }
    if (dupeResumedAnswered == 0) {
      dupeResumed.warning = 'no dupe check called a logged contact a duplicate — the scorer saw no log, or never ran';
    } else if (dupeResumedAnswered < dupeSamples) {
      dupeResumed.warning = 'only $dupeResumedAnswered of $dupeSamples dupe checks called a logged contact a duplicate';
    }
  }
  // A resumed row measured on cold folds is the flat claim made of the very
  // work it claims to skip. The first band has no checkpoint yet and is cold
  // by design; after the first rescore every sample must resume.
  if (resumableSamples > 0 && resumedSamples < resumableSamples) {
    final short = 'only $resumedSamples of $resumableSamples samples after the first rescore had a checkpoint to resume from';
    dupeResumed.warning ??= short;
    spotsPass.warning ??= short;
  }
  if (spotsTimedOut > 0) {
    spotsPass.warning ??= '$spotsTimedOut spots passes ran out the scorer\'s clock — those timings are the timeout';
  } else if (spotsAnswered == 0) {
    spotsPass.warning ??= 'no spots pass judged the logged half of the board worked before — the scorer saw no log, or never ran';
  } else if (spotsAnswered < spotsSamples) {
    spotsPass.warning ??= 'only $spotsAnswered of $spotsSamples spots passes judged the logged half of the board worked before';
  }
  // An insert the stream never answered leaves a timing of the wait's timeout,
  // which is not what the phase measures; and a stream that emits for some
  // contacts and not others is broken, not slow.
  if (streamError != null) {
    emission.warning = 'the log stream failed: $streamError';
  } else if (emissionsMissed > 0) {
    emission.warning = 'the log stream did not emit for $emissionsMissed of $qsoCount contacts';
  }

  return BenchResult(qsoCount: qsoCount, phases: phases);
}

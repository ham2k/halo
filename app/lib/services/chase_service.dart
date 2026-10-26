// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the operator is chasing, and what working a station would do for it
// (docs/design/claims.md §8): the goals — chasing programs, in the
// operator's order — the verdicts they alert on, and each candidate
// contact's verdict per goal, judged against the `claims` table.
//
// Read by the Chasing view, and by every spots board and logging panel for
// the chasing notices they show beside scoring's own.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'extensions/extension_service.dart';
import 'settings_service.dart';

/// One program the operator can chase.
class ChaseGoal {
  /// The program's hook key — what the stored goals are keyed on.
  final String key;
  final String label;
  final String? icon;

  /// The program's accent, as it declares it (`#rrggbb`).
  final String? color;
  final bool on;

  const ChaseGoal({required this.key, required this.label, this.icon, this.color, required this.on});

  ChaseGoal withOn(bool on) => ChaseGoal(key: key, label: label, icon: icon, color: color, on: on);
}

/// Programs that moved to a new key, by their old one: a stored goal under
/// the old key is the same goal, keeping its place and its switch. The core
/// `dxcc` program became the catalog's `ham2k-dxcc` (HALO-844). Never
/// shrinks — an install may skip any number of releases.
const kRenamedChasePrograms = {'dxcc': 'ham2k-dxcc'};

String? _storedGoalKey(Map<dynamic, dynamic> entry) {
  final key = entry['key'];
  return key is String ? kRenamedChasePrograms[key] ?? key : null;
}

/// The goals [programs] offer, in the operator's [stored] order — `{key,
/// on}` maps as `LayoutKeys.chaseOptions` keeps them. A program [stored]
/// does not mention yet joins at the end, on: an extension enabled with a
/// program in it is one the operator means to chase.
List<ChaseGoal> resolveChaseGoals(Map<String, ChasingProgram> programs, List<Object?> stored) {
  ChaseGoal goal(String key, bool on) {
    final program = programs[key]!;
    return ChaseGoal(key: key, label: program.label, icon: program.icon, color: program.color, on: on);
  }

  final goals = <ChaseGoal>[];
  for (final entry in stored.whereType<Map<dynamic, dynamic>>()) {
    final key = _storedGoalKey(entry);
    if (key == null || !programs.containsKey(key) || goals.any((g) => g.key == key)) continue;
    goals.add(goal(key, entry['on'] != false));
  }
  for (final key in programs.keys) {
    if (!goals.any((g) => g.key == key)) goals.add(goal(key, true));
  }
  return goals;
}

/// [goals] as `LayoutKeys.chaseOptions` stores them, followed by the entries
/// of [stored] for programs not offered now. Those stay, on or off as they
/// were: a program the operator turned off must not come back on because its
/// extension was removed and added again.
List<Map<String, dynamic>> storedChaseGoals(List<ChaseGoal> goals, List<Object?> stored) => [
  for (final g in goals) {'key': g.key, 'on': g.on},
  for (final entry in stored.whereType<Map<dynamic, dynamic>>())
    if (_storedGoalKey(entry) case final key? when !goals.any((g) => g.key == key)) {'key': key, 'on': entry['on'] != false},
];

/// What a spot or a call alerts on until the operator picks: something the
/// checklist does not have yet.
const kDefaultChaseAlerts = {ChaseVerdict.newRef, ChaseVerdict.newBand, ChaseVerdict.newMode};

/// The Chasing view's own spots sort, beside the board's `time` and
/// `frequency`: by verdict, then goal order, then newest.
const kChaseSortWanted = 'wanted';

/// One goal's checklist, as its program tallies it, for the Info panel.
typedef ChaseSummary = ({ChasingProgram program, String holder, String edition, Map<String, Map<String, dynamic>> tallies});

/// Where a spot stands among the goals: the best verdict's rank, and the
/// goal order of the program giving it.
typedef ChaseRank = ({int rank, int goal});

/// Candidates per program the claims cache keeps before it starts over — a
/// board's worth several times over.
const _maxCachedCandidates = 4000;

class ChaseService extends ChangeNotifier {
  ChaseService({
    required this.extensions,
    required this.claims,
    required this.qsos,
    required this.settings,
    this.changeDebounce = const Duration(milliseconds: 300),
  }) {
    _optionsJson = jsonEncode(options);
    settings.addListener(_onSettings);
    extensions.runtimeGeneration.addListener(_onRuntime);
    _changes = claims.changes.listen((_) => _onClaimsChanged());
    unawaited(_loadPrograms());
  }

  final ExtensionService extensions;
  final ClaimsRepository claims;
  final QsosRepository qsos;
  final SettingsService settings;

  /// How long a burst of writes to the claims table gathers before readers
  /// are told to judge again: a sync round writes a page at a time.
  final Duration changeDebounce;

  /// Chasing notices reach operation views only under `EXP CHASE`, which
  /// is also the only place claims are kept.
  bool get enabled => settings.experimentEnabled('chase') /* stored key, see experiments.yaml */;

  Map<String, dynamic> get options => settings.layoutData(LayoutKeys.chaseOptions) ?? const {};

  Future<void> setOptions(Map<String, dynamic> changes) => settings.setLayoutData(LayoutKeys.chaseOptions, {...options, ...changes});

  /// Bumped whenever a verdict already handed out may be stale: the
  /// programs, the goals, the alerts or a checklist changed. What a reader
  /// judges again on.
  int get revision => _revision;
  int _revision = 0;

  /// The programs the runtime registers; empty until it has answered.
  Map<String, ChasingProgram> get programs => _programs;
  Map<String, ChasingProgram> _programs = const {};

  List<ChaseGoal> get goals => resolveChaseGoals(_programs, (options['goals'] as List?) ?? const []);

  Future<void> setGoals(List<ChaseGoal> goals) => setOptions({'goals': storedChaseGoals(goals, (options['goals'] as List?) ?? const [])});

  Set<ChaseVerdict> get alerting {
    final stored = options['alerts'];
    if (stored is! List) return kDefaultChaseAlerts;
    return {...stored.map(ChaseVerdict.tryParse).nonNulls};
  }

  Future<void> setAlerting(Set<ChaseVerdict> verdicts) => setOptions({
    'alerts': [
      for (final verdict in ChaseVerdict.values)
        if (verdicts.contains(verdict)) verdict.name,
    ],
  });

  /// The Chasing view's spots sort: [kChaseSortWanted] unless the operator
  /// picked `time` or `frequency` there. Kept apart from the board's own
  /// sort, which operation views share.
  String get spotsSortBy => (options['spotsSortBy'] as String?) ?? kChaseSortWanted;
  Future<void> setSpotsSortBy(String value) => setOptions({'spotsSortBy': value});

  /// Whether the Chasing view's spots show only those alerting.
  bool get alertingOnly => options['alertingOnly'] == true;
  Future<void> setAlertingOnly(bool value) => setOptions({'alertingOnly': value});

  StreamSubscription<void>? _changes;
  Timer? _changeTimer;
  String _optionsJson = '';

  void _changed() {
    _revision++;
    notifyListeners();
  }

  void _onSettings() {
    final json = jsonEncode(options);
    if (json == _optionsJson) return;
    _optionsJson = json;
    _changed();
  }

  void _onRuntime() {
    _candidateClaims.clear();
    unawaited(_loadPrograms());
  }

  void _onClaimsChanged() {
    _changeTimer?.cancel();
    _changeTimer = Timer(changeDebounce, () {
      _checklists.clear();
      _checklistsCleared++;
      _changed();
    });
  }

  Future<void> _loadPrograms() async {
    final programs = await extensions.chasingPrograms();
    if (programs == null || _disposed) return;
    final before = _programs;
    _programs = programs;
    if (!setEquals(before.keys.toSet(), programs.keys.toSet()) || before.values.any((p) => programs[p.key]?.version != p.version)) {
      _candidateClaims.clear();
      _changed();
    } else if (before.values.any((p) => programs[p.key]?.icon != p.icon || programs[p.key]?.color != p.color)) {
      // The claims still stand, but the spot rows draw the program's icon.
      _changed();
    }
  }

  /// What each candidate claims, per program, by [_candidateKey]: a spot is
  /// asked about once while the board holds it, not on every pass.
  final Map<String, Map<String, List<QsoClaim>>> _candidateClaims = {};

  /// Each (program, holder, edition) checklist as slot levels, loaded on
  /// first use and dropped whenever the table changes.
  final Map<(String, String, String), Map<String, ClaimLevel>> _checklists = {};

  /// Bumped as [_checklists] is dropped: a read that started before the drop
  /// holds the table as it was, and caching it would outlive the change.
  int _checklistsCleared = 0;

  /// A candidate's identity for the claims cache: everything a program may
  /// read, with the time as its UTC day. The time moves on every spots pass,
  /// but a program with editions computes each claim's from the date, so a
  /// contact typed for another day — an edit to an older one, or a pass
  /// after midnight — is another question.
  static String _candidateKey(Map<String, dynamic> qso) {
    final at = asQsonNum(qso['startAtMillis'])?.toInt();
    return jsonEncode({...qso, 'startAtMillis': at == null ? null : at ~/ Duration.millisecondsPerDay});
  }

  /// Each of [candidates]' verdicts under every goal that is on, in goal
  /// order, keyed as given. A candidate is a contact as it would be logged
  /// — `their`, `band`, `mode`, `refs`, and `our.call`, the station it would
  /// be worked from. A program that fails, or does not apply, leaves no
  /// verdict.
  Future<Map<String, List<ChaseJudgement>>> judge(Map<String, Map<String, dynamic>> candidates) async {
    if (candidates.isEmpty) return const {};
    if (_programs.isEmpty) await _loadPrograms();
    final on = [
      for (final goal in goals)
        if (goal.on) goal.key,
    ];
    final keys = {for (final MapEntry(:key, :value) in candidates.entries) key: _candidateKey(value)};
    final judged = <String, List<ChaseJudgement>>{for (final key in candidates.keys) key: []};
    for (final program in on) {
      final claimsByKey = await _claimsFor(program, candidates, keys);
      if (claimsByKey == null) continue;
      for (final MapEntry(:key, value: contentKey) in keys.entries) {
        final claimed = claimsByKey[contentKey] ?? const <QsoClaim>[];
        final held = await _heldFor(program, claimed);
        final judgement = judgeChaseClaims(program, claimed, held);
        if (judgement != null) judged[key]!.add(judgement);
      }
    }
    return judged;
  }

  Future<Map<String, List<QsoClaim>>?> _claimsFor(String program, Map<String, Map<String, dynamic>> candidates, Map<String, String> keys) async {
    final cache = _candidateClaims.putIfAbsent(program, () => {});
    Map<String, Map<String, dynamic>> missingFrom(Map<String, List<QsoClaim>> cache) => {
      for (final MapEntry(:key, :value) in candidates.entries)
        if (!cache.containsKey(keys[key])) keys[key]!: {...value, 'uuid': keys[key]},
    };
    var missing = missingFrom(cache);
    // Starting over drops this batch's cached candidates too, so they are
    // asked again with the rest: the cache is what [judge] reads them from.
    if (missing.isNotEmpty && cache.length + missing.length > _maxCachedCandidates) {
      cache.clear();
      missing = missingFrom(cache);
    }
    if (missing.isNotEmpty) {
      final answer = await extensions.claimsForQsos(program, missing.values.toList());
      if (answer == null) return null;
      for (final key in missing.keys) {
        cache[key] = answer[key] ?? const [];
      }
    }
    return cache;
  }

  Future<Map<String, ClaimLevel>> _heldFor(String program, List<QsoClaim> claimed) async {
    final held = <String, ClaimLevel>{};
    for (final (holder, edition) in {for (final claim in claimed) (claim.holder, claim.edition)}) {
      held.addAll(await _checklist(program, holder, edition));
    }
    return held;
  }

  Future<Map<String, ClaimLevel>> _checklist(String program, String holder, String edition) async {
    final key = (program, holder, edition);
    final cached = _checklists[key];
    if (cached != null) return cached;
    final cleared = _checklistsCleared;
    final rows = await claims.checklist(program, holder, edition: edition);
    final levels = {for (final row in rows) chaseSlotKeyOf(row): row.level};
    if (cleared == _checklistsCleared) _checklists[key] = levels;
    return levels;
  }

  /// [judgements] as notice keys ([ChaseNotice]). In the Chasing view every
  /// verdict but `worked` shows; anywhere else only those alerting do, beside
  /// the operation's own scoring.
  List<String> noticesFor(List<ChaseJudgement> judgements, {required bool chasing}) {
    final alerts = alerting;
    return [
      for (final judgement in judgements)
        for (final verdict in judgement.verdicts)
          if (verdict != ChaseVerdict.worked && (chasing || alerts.contains(verdict)))
            ChaseNotice(
              program: judgement.program,
              verdict: verdict,
              guess: judgement.guess,
              alerting: alerts.contains(verdict),
              band: verdict == ChaseVerdict.newBand ? judgement.band : null,
              mode: verdict == ChaseVerdict.newMode ? judgement.mode : null,
            ).key,
    ];
  }

  /// [score] — a scorer's `{notices, alerts}` for one candidate, null for
  /// none — with [judgements]' notices folded in. In the Chasing view they
  /// stand in for scoring's notices, which keeps only its `duplicate`: a
  /// station worked this period. Elsewhere they join scoring's, less the
  /// notices a judging program supersedes ([ChasingProgram.supersedes]). A
  /// duplicate gets none either way, since a notice beside it un-strikes the
  /// row and tells the operator to work again a station they already have.
  ({List<String> notices, List<String> alerts}) withNotices(
    ({List<String> notices, List<String> alerts})? score,
    List<ChaseJudgement> judgements, {
    required bool chasing,
  }) {
    final alerts = score?.alerts ?? const <String>[];
    final duplicate = alerts.contains('duplicate');
    final notices = duplicate ? const <String>[] : noticesFor(judgements, chasing: chasing);
    if (chasing) return (notices: notices, alerts: [if (duplicate) 'duplicate']);
    final superseded = {for (final judgement in judgements) ...?_programs[judgement.program]?.supersedes};
    return (
      notices: [
        for (final notice in score?.notices ?? const <String>[])
          if (!superseded.contains(notice)) notice,
        ...notices,
      ],
      alerts: alerts,
    );
  }

  /// The best of [judgements], its goal the program's place in the
  /// operator's order so the earlier goal wins a tie, or null when no goal
  /// has a verdict. Not the judgement's index: a goal that leaves no verdict
  /// leaves no judgement, so indexes from two candidates do not line up.
  ChaseRank? rankOf(List<ChaseJudgement> judgements) {
    if (judgements.isEmpty) return null;
    final order = {for (final (index, goal) in goals.indexed) goal.key: index};
    ChaseRank? best;
    for (final judgement in judgements) {
      final goal = order[judgement.program] ?? order.length;
      if (best == null || judgement.rank > best.rank || (judgement.rank == best.rank && goal < best.goal)) best = (rank: judgement.rank, goal: goal);
    }
    return best;
  }

  /// The edition a contact made now would claim, or null for a program
  /// whose editions are events, which the app cannot tell from the date.
  static String? currentEdition(ChasingProgram program) => switch (program.editions) {
    ChasingEditions.lifetime => '',
    ChasingEditions.annual => '${nowUtc().year}',
    ChasingEditions.event => null,
  };

  /// Each goal that is on, summarized by its program for [station]'s first
  /// holder in the current edition. A program that fails is left out.
  Future<List<ChaseSummary>> summaries(Map<String, dynamic> station) async {
    if (_programs.isEmpty) await _loadPrograms();
    final summaries = <ChaseSummary>[];
    for (final goal in goals) {
      final program = _programs[goal.key];
      final edition = program == null ? null : currentEdition(program);
      if (!goal.on || program == null || edition == null) continue;
      final holder = (await extensions.holdersFor(program.key, station))?.firstOrNull;
      if (holder == null) continue;
      final slots = await claims.checklist(program.key, holder, edition: edition);
      final tallies = await extensions.summarizeClaims(
        program.key,
        holder: holder,
        edition: edition,
        slots: [
          for (final slot in slots) {'ref': slot.ref, 'band': slot.band, 'mode': slot.mode, 'level': slot.level.name, 'label': ?slot.label},
        ],
      );
      if (tallies != null) summaries.add((program: program, holder: holder, edition: edition, tallies: tallies));
    }
    return summaries;
  }

  /// Reads the file [name] through [program]'s [importer] and makes what it
  /// claims that importer's claim records in the log (claims.md §9),
  /// replacing the last file of its kind: `claims`, the slots the file fills,
  /// and `skipped`, the records the program could not read. Null when the
  /// program failed. A file that claims nothing writes nothing — read as an
  /// empty export it would delete the whole last one, and a file picked by
  /// mistake reads that way too.
  Future<({int claims, int skipped})?> importFile(
    ChasingProgram program,
    ChasingImporter importer, {
    required String name,
    required String text,
    required Map<String, dynamic> station,
  }) async {
    final read = await extensions.importClaims(program.key, importer: importer.key, name: name, text: text, station: station);
    if (read == null) return null;
    final importedAt = nowMillis();
    final best = <String, ImportedClaim>{};
    final records = <String, Map<String, dynamic>>{};
    for (final imported in read.claims) {
      final record = claimEventQson(program: program.key, importer: importer.key, imported: imported, fallbackMillis: importedAt);
      final uuid = record['uuid'] as String;
      final held = best[uuid];
      if (held != null && !_betterImport(imported, held)) continue;
      best[uuid] = imported;
      records[uuid] = record;
    }
    if (records.isNotEmpty) await qsos.replaceClaimEvents(program.key, importer.key, records.values.toList());
    return (claims: records.length, skipped: read.skipped);
  }

  /// Of two records a file makes for one slot, the one the slot rule
  /// ([compareClaims]) would keep; the first on a tie.
  static bool _betterImport(ImportedClaim a, ImportedClaim b) {
    StoredClaim stored(ImportedClaim imported) => StoredClaim.fromQso(program: '', version: 0, claim: imported.claim, qso: '', atMillis: imported.atMillis);
    return compareClaims(stored(a), stored(b)) > 0;
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _changeTimer?.cancel();
    unawaited(_changes?.cancel());
    settings.removeListener(_onSettings);
    extensions.runtimeGeneration.removeListener(_onRuntime);
    super.dispose();
  }
}

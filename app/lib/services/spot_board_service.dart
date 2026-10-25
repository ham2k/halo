// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the spots board knows beyond the spots themselves — each spotted
// call's note, emoji and continent, and each spot's scoring verdict against
// the open operation — worked out once and read by everything that shows the
// board: the Spots Panel, and extensions through `getSpots`.
//
// One owner because each of those costs the runtime: a lookup per spotted
// call, and a pass of every scorer over the whole board. Worked out per
// reader, every extension panel would double both on every refresh, and a
// reader asking from inside a lookup would re-enter the lookup pipeline it is
// part of. Readers here only read.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'chase_service.dart';
import 'extensions/extension_service.dart';
import 'hook_payloads.dart';
import 'radio_service.dart';
import 'scoring_service.dart';
import 'settings_service.dart';
import 'spot_board.dart';
import 'spots_service.dart';

typedef SpotCallInfo = ({bool hasNote, String? emoji, String? continent, String? entityPrefix});
typedef SpotScore = ({List<String> notices, List<String> alerts});
typedef _Shown = ({Operation operation, List<Qso> qsos, String logRevision, bool chasing});

/// One viewer's hold on the board: an Operation View, a Spots Panel.
class SpotBoardSubscription {
  SpotBoardSubscription._(this._board, {required this.follower});

  final SpotBoardService _board;

  /// A follower's [show] counts only while no other viewer has shown
  /// anything (see [SpotBoardService.subscribe]).
  final bool follower;
  _Shown? _shown;
  bool _cancelled = false;

  /// This viewer now shows [operation], whose log is [qsos] and
  /// [logRevision] its fingerprint — [chasing] for the Chasing view, whose
  /// spots read chasing verdicts where an operation's read its scoring.
  /// Callable from a build or an update. A viewer covered by another records
  /// it without taking the board.
  void show(Operation operation, List<Qso> qsos, {required String logRevision, bool chasing = false}) {
    if (_cancelled) return;
    _shown = (operation: operation, qsos: qsos, logRevision: logRevision, chasing: chasing);
    _board._reconcile();
  }

  /// Guarded like SpotsService.subscribe's callback: a State that releases
  /// twice must not stop the board out from under the others.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _board._release(this);
  }
}

/// The failure streak the board's own lookups count toward: it looks up every
/// spotted call at once, and a burst of timeouts it caused is not the
/// operator's lookup failing (`ExtensionHookApi.lookupCall`).
const _lookupStreakKey = 'extensions:lookup-call:spot-board';

/// How many calls one lookup crossing carries. Each call's lookup reads the
/// database (call history) and those reads queue behind one another, so a
/// batch is kept small enough that a read from anywhere else — the logging
/// panel's own lookup, the activity search's nearby parks — waits behind the
/// batches in flight, never behind the whole board. Passes can overlap, but
/// each asks only calls no other pass is asking.
const spotLookupBatchSize = 20;

/// The shortest time between two passes looking up a board's new calls. A
/// cluster in a contest changes the board several times a second; looked up
/// per change, the same calls are asked for over and over.
const spotLookupCoalesce = Duration(milliseconds: 1500);

class SpotBoardService extends ChangeNotifier {
  SpotBoardService({required this.extensions, required this.spots, required this.settings, required this.radio, required this.scoring, this.chase});

  final ExtensionService extensions;
  final SpotsService spots;
  final SettingsService settings;
  final RadioService radio;
  final ScoringService scoring;

  /// Where the chasing verdicts come from; none, and spots carry scoring
  /// alone.
  final ChaseService? chase;

  /// Bumped whenever what a board reader would show may have changed: a spot
  /// refresh, new verdicts or call info, an edit to the operator's spot
  /// filters or bands, or the radio moving to another band or mode (which an
  /// "auto" filter follows). What fires an extension panel's `spots` trigger.
  int get revision => _revision;
  int _revision = 0;

  /// Each spotted call's note, marker emoji and continent, as the offline
  /// lookup answered them — the Spots Panel's "Calls of Note" and emoji, and
  /// the continent filter. Kept across refreshes: only calls not yet answered
  /// for cost a lookup. A view, not a copy — the panel reads it per spot.
  Map<String, SpotCallInfo> get callInfo => UnmodifiableMapView(_callInfo);
  final Map<String, SpotCallInfo> _callInfo = {};

  /// Calls whose lookup is out, each to the completion of the pass asking.
  /// Not yet in [_callInfo], so without this a pass starting meanwhile asks
  /// for them again — and a lookup timing out leaves its database read
  /// queued, so every repeat adds to the queue the next one times out behind.
  final Map<String, Future<void>> _callInfoAsking = {};
  Timer? _callInfoSoon;
  bool _callInfoPending = false;

  /// The activities' logging controls for [operation] — what picks each
  /// spot's activity icon and tint, as the Spots Panel's rows show them — for
  /// `getSpots`' `display`. Fetched on the first read for an operation, not
  /// on opening it: only a panel drawing spots its own way needs them. Empty
  /// until they land, when the board bumps; a spot meanwhile falls back to
  /// its source's icon. A fetch that fails outright is not retried for that
  /// operation, as the Spots Panel's is not.
  List<Map<String, dynamic>> activityControlsForDisplay() {
    final operation = this.operation;
    if (operation != null && _controlsFor != operation.uuid) {
      _controlsFor = operation.uuid;
      unawaited(_loadActivityControls(operation));
    }
    return _activityControls;
  }

  List<Map<String, dynamic>> _activityControls = const [];
  String? _controlsFor;

  /// Scoring verdicts keyed by [spotCandidateKey] — what makes a spot show as
  /// worked, or accented for a new band/mode/day/reference/multiplier — for
  /// [operationUuid], or null until a pass has landed for it (it is not the
  /// operation shown, or its first pass has not answered). Within a landed
  /// pass, an absent key means "nothing to report".
  ///
  /// The chasing notices ([ChaseNotice]) ride along, folded in by
  /// [ChaseService.withNotices]: in place of scoring's for the Chasing view,
  /// beside them elsewhere.
  Map<String, SpotScore>? scoresFor(String operationUuid) => _scoredUuid != null && _scoredUuid == operationUuid ? _withChase : null;
  Map<String, SpotScore> _scores = {};
  String? _scoredUuid;

  /// Each candidate's chasing verdicts, per goal in goal order, by
  /// [spotCandidateKey]; empty until judged, and for a candidate no goal
  /// applies to.
  Map<String, List<ChaseJudgement>> get judgements => _judgements;
  Map<String, List<ChaseJudgement>> _judgements = {};
  Map<String, SpotScore> _withChase = {};

  /// The operation the board is judged against: the one shown by the most
  /// recent subscription that is still open and has shown one, followers
  /// counting only when nothing else has. Operation Views stack — ⌘K and
  /// deep links push one over another — so the view on top decides, and
  /// closing it hands the board back to the one beneath rather than leaving
  /// it judging an operation nobody sees.
  Operation? get operation => _shown?.operation;
  _Shown? get _shown => _shownBy(follower: false) ?? _shownBy(follower: true);
  _Shown? _shownBy({required bool follower}) =>
      _viewers.reversed.where((viewer) => viewer.follower == follower).map((viewer) => viewer._shown).nonNulls.firstOrNull;

  final List<SpotBoardSubscription> _viewers = [];
  int get _subscribers => _viewers.length;

  /// What the board's verdicts were last asked about, to tell a switch from
  /// a moved log.
  String? _judgedUuid;
  String? _judgedRevision;
  bool? _judgedChasing;

  VoidCallback? _unsubscribeSpots;

  /// Keeps the board worked out — and the spots it reads fetched, once the
  /// operation shown allows it ([spotsAllowed]) — while at least one caller
  /// holds a subscription, through which it tells the board what it shows
  /// ([SpotBoardSubscription.show]).
  ///
  /// A [follower] — the Spots Panel inside an Operation View — shows the same
  /// operation its view does, but subscribes later and on its own schedule:
  /// a covered view's lazily mounted panel would otherwise land on top of
  /// the view in front and take the board from it. Its [show] is what feeds
  /// a board nothing else feeds, a panel standing alone.
  SpotBoardSubscription subscribe({bool follower = false}) {
    final viewer = SpotBoardSubscription._(this, follower: follower);
    _viewers.add(viewer);
    if (_viewers.length == 1) {
      spots.addListener(_onSpotsChanged);
      settings.addListener(_onSettingsChanged);
      radio.addListener(_onRadioChanged);
      chase?.addListener(_onChaseChanged);
      _filtersKey = _currentFiltersKey;
      _disabledSources = settings.disabledSpotSources;
      _vfoKey = _currentVfoKey;
      if (spots.loaded) unawaited(refreshCallInfo());
    }
    _holdSpots();
    return viewer;
  }

  /// Whether the spot sources may be asked at all: only once a viewer has
  /// shown an operation, and only one with assistance (`Operation.assistance`)
  /// — an operation that rules it out calls no spot hook, so the board stops
  /// fetching the moment it is on top, and starts again when it is not.
  bool get spotsAllowed => _shown?.operation.assistance ?? false;

  /// Takes or lets go of [spots]' fetching to match [spotsAllowed].
  void _holdSpots() {
    if (spotsAllowed) {
      _unsubscribeSpots ??= spots.subscribe();
    } else {
      _unsubscribeSpots?.call();
      _unsubscribeSpots = null;
    }
  }

  void _release(SpotBoardSubscription viewer) {
    _viewers.remove(viewer);
    if (_viewers.isNotEmpty) {
      _reconcile();
      return;
    }
    spots.removeListener(_onSpotsChanged);
    settings.removeListener(_onSettingsChanged);
    radio.removeListener(_onRadioChanged);
    chase?.removeListener(_onChaseChanged);
    _unsubscribeSpots?.call();
    _unsubscribeSpots = null;
    _scoreDebounce?.cancel();
    _callInfoSoon?.cancel();
    _callInfoSoon = null;
    _callInfoPending = false;
    _judgedUuid = null;
    _judgedRevision = null;
    _scores = {};
    _scoredUuid = null;
    _judgements = {};
    _withChase = {};
    _callInfo.clear();
    _candidateStates.clear();
    _activityControls = const [];
    _controlsFor = null;
  }

  /// Brings the verdicts in line with what the top viewer shows. Never
  /// notifies synchronously, only schedules — it runs from builds and
  /// updates.
  ///
  /// A different operation is scored straight away, since nothing on screen
  /// was judged against it; a moved log waits out the debounce.
  void _reconcile() {
    _holdSpots();
    final shown = _shown;
    if (shown == null) return;
    final switched = shown.operation.uuid != _judgedUuid || shown.chasing != _judgedChasing;
    final moved = shown.logRevision != _judgedRevision;
    _judgedUuid = shown.operation.uuid;
    _judgedRevision = shown.logRevision;
    _judgedChasing = shown.chasing;
    if (switched) {
      _scores = {};
      _scoredUuid = null;
      // Judged from the station and view switched away from: merged into the
      // new scores, they would show its verdicts until the next judging.
      _judgements = {};
      _chaseCandidates = {};
      _judgeSerial++;
      _mergeChase();
      // The pass made now answers whatever a pending debounce was waiting to.
      _scoreDebounce?.cancel();
      if (spots.loaded) scheduleMicrotask(() => unawaited(refreshScores()));
      _activityControls = const [];
      _controlsFor = null;
    } else if (moved) {
      _scheduleScores();
    }
  }

  void _onSpotsChanged() {
    _bump();
    _refreshCallInfoSoon();
    _scheduleScores();
  }

  /// [refreshCallInfo] now, unless a pass ran within [spotLookupCoalesce] —
  /// then once, when that much time has passed. Now, so a board's first
  /// spots get their notes as they appear; and never pushed back by the
  /// changes behind it, as a debounce would be, since a busy cluster never
  /// goes quiet for long enough to let one fire.
  void _refreshCallInfoSoon() {
    if (_callInfoSoon != null) {
      _callInfoPending = true;
      return;
    }
    unawaited(refreshCallInfo());
    _callInfoSoon = Timer(spotLookupCoalesce, () {
      _callInfoSoon = null;
      if (!_callInfoPending) return;
      _callInfoPending = false;
      if (_subscribers > 0) _refreshCallInfoSoon();
    });
  }

  String _filtersKey = '';
  Set<String> _disabledSources = const {};
  String get _currentFiltersKey => '${jsonEncode(settings.spottingFilters)}|${settings.enabledBands.join(',')}';

  /// Settings notify on every write; only the spot filters and the bands
  /// they narrow by change a board. A source switched on or off changes which
  /// spots merge, so which questions the scorers are asked.
  void _onSettingsChanged() {
    final key = _currentFiltersKey;
    if (key == _filtersKey) return;
    _filtersKey = key;
    final disabled = settings.disabledSpotSources;
    if (!setEquals(disabled, _disabledSources)) {
      _disabledSources = disabled;
      _scheduleScores();
    }
    _bump();
  }

  String _vfoKey = '';
  String get _currentVfoKey => '${radio.vfoA.band}|${radio.vfoA.mode}';

  /// Only the band and mode feed an "auto" filter, so a live CAT feed moving
  /// the frequency alone costs nobody a render.
  void _onRadioChanged() {
    final key = _currentVfoKey;
    if (key == _vfoKey) return;
    _vfoKey = key;
    _bump();
  }

  void _bump() {
    _revision++;
    notifyListeners();
  }

  Future<void> _loadActivityControls(Operation operation) async {
    await extensions.start();
    final result = await extensions.loggingControls(operationPayloadFor(operation));
    // Partial is kept, as the Spots Panel keeps it: one slow activity must not
    // cost the others their icons.
    if (result.controls.isEmpty || _viewers.isEmpty || operation.uuid != _controlsFor) return;
    _activityControls = result.controls;
    _bump();
  }

  /// Looks up (and caches) each currently-fetched spot's callsign info.
  /// Always runs — only calls already cached or still being asked about are
  /// skipped — so it is there from the very first fetch, not only once a
  /// reader needs it. Asked [spotLookupBatchSize] calls per crossing, one
  /// crossing at a time, and each batch lands as it answers.
  /// `online: false`: call-notes' data comes from a cached, periodically
  /// refreshed data file, and continent from the bundled DXCC country file
  /// (`annotateCallsign` in the lookups extension), so the offline pass is
  /// enough — and it skips every OTHER lookup hook's live fetch (QRZ,
  /// HamDB…) for fields nothing here uses, on a board that can easily hold
  /// far more distinct callsigns than the logging field ever looks up.
  Future<void> refreshCallInfo() async {
    final unknown =
        <String>{
            for (final list in spots.spotsBySource.values)
              for (final spot in list) ...spotOperatorCalls(spot),
          }
          ..removeWhere(_callInfo.containsKey)
          // Never answered (`lookupCalls`), so asked it would only hold a batch's
          // place — and a batch of them answers nothing, which stops the pass.
          ..removeWhere((call) => call.length < 3);
    // Waited on, not asked again: a caller awaiting this expects the board's
    // calls answered when it returns, whichever pass asks.
    final elsewhere = {for (final call in unknown) ?_callInfoAsking[call]};
    final calls = [
      for (final call in unknown)
        if (!_callInfoAsking.containsKey(call)) call,
    ];
    final done = Completer<void>();
    for (final call in calls) {
      _callInfoAsking[call] = done.future;
    }
    final operationData = operation?.data ?? const <String, dynamic>{};
    try {
      for (final batch in _batches(calls)) {
        final results = await extensions.lookupCalls(
          [for (final call in batch) (call: call, qso: const <String, dynamic>{})],
          operation: operationData,
          online: false,
          streakKey: _lookupStreakKey,
        );
        if (_subscribers == 0) return;
        // A batch that answered nothing is a runtime that cannot answer right
        // now, and the batches after it would only queue behind the one it
        // is still running. The next refresh asks for them.
        if (results.every((result) => result == null)) break;
        // Null is no answer at all — a runtime still booting, a lookup timed
        // out — not "nothing known", which comes back as a result. Cached, it
        // would cost that call its note and emoji for the session; left out,
        // the next refresh asks again.
        _callInfo.addEntries([
          for (final (i, result) in results.indexed)
            if (result != null) MapEntry(batch[i], _spotCallInfoFrom(result)),
        ]);
        _bump();
      }
    } finally {
      _callInfoAsking.removeWhere((_, pass) => pass == done.future);
      done.complete();
    }
    await Future.wait(elsewhere);
  }

  /// What the board keeps of one call's lookup. Probed, not cast: an
  /// extension answering one field with the wrong type must cost only that
  /// field, not the call's info, nor the batch it came back in.
  static SpotCallInfo _spotCallInfoFrom(Map<String, dynamic> result) {
    final guess = asQsonMap(result['guess']);
    final emoji = asQsonString(guess?['emoji']);
    // A note the call-info area would show, not merely a key: it reads
    // the note as a non-empty string, and the board's mark must agree.
    final hasNote = guess != null && (emoji != null || (asQsonString(guess['note'])?.isNotEmpty ?? false));
    return (hasNote: hasNote, emoji: emoji, continent: asQsonString(guess?['continent']), entityPrefix: asQsonString(guess?['entityPrefix']));
  }

  static Iterable<List<T>> _batches<T>(List<T> items) sync* {
    for (var i = 0; i < items.length; i += spotLookupBatchSize) {
      yield items.sublist(i, i + spotLookupBatchSize < items.length ? i + spotLookupBatchSize : items.length);
    }
  }

  /// Coalesces bursts of triggers into one pass. A run of contacts logged in a
  /// pileup moves the log per QSO, and each pass scores every spot on the
  /// board on the same runtime that serves the logging panel's own call-info
  /// scoring — so scoring every intermediate state costs the operator the
  /// responsiveness of the field they are typing in. Longer than that panel's
  /// own 300ms: nothing here is per-keystroke.
  Timer? _scoreDebounce;

  void _scheduleScores() {
    _scoreDebounce?.cancel();
    _scoreDebounce = Timer(const Duration(milliseconds: 600), () {
      if (_subscribers > 0) unawaited(refreshScores());
    });
  }

  /// Guards against a second scoring pass while one is in flight (a spot
  /// refresh landing on a log edit) — the second would fold the same log again
  /// for the same answer. The trailing flag re-runs once, so the pass that was
  /// skipped isn't simply lost.
  bool _scoring = false;
  bool _scoresStale = false;

  /// Scores every spot on the board against the operation's log, so readers
  /// can strike the ones already worked and accent what is new.
  ///
  /// Scored per operator (a merged multi-op spot carries several), deduped by
  /// [spotCandidateKey], and asked in ONE call per scorer — the runtime folds
  /// the log once and judges every candidate against it. The candidates are
  /// the merged board's AND every spot as its source reported it: the first
  /// is what the Spots Panel shows, the second what `getSpots`' `'all'` board
  /// hands out, and the two differ wherever a merge combined references.
  ///
  /// Scores the whole board rather than any filtered view of it: filtering is
  /// a display choice the operator changes constantly, and re-scoring on each
  /// change would refold the log to learn nothing new.
  ///
  /// Scored against the CURRENT segment, like the call-info pills
  /// (`logging_controls_call_info.dart`) and for the same reason: the spots
  /// and the entry row have to agree about which activities are running. A
  /// contest started at a `start` event is named by no ref on the base
  /// operation, so without this its scorer is never selected and no spot ever shows its multipliers; one
  /// ended at a break would keep accenting them. The timeline goes along too,
  /// so the log the candidates are judged against is folded per segment —
  /// otherwise a pre-contest contact makes a fresh station read as a duplicate.
  ///
  /// Resumes from `ScoringService`'s cached checkpoints whenever the log is
  /// what they folded plus appended contacts — the same rule the call-info
  /// pills use (`ScoringService.liveResumeFor`), so the second after working a
  /// station the new contact travels as the tail and the spot strikes at
  /// once, and the 2-minute refresh replays nothing at all. Only a log the
  /// checkpoints cannot account for (an edit, a delete, a change to the
  /// operation) costs a whole-log fold.
  Future<void> refreshScores() async {
    if (_scoring) {
      _scoresStale = true;
      return;
    }
    _scoring = true;
    try {
      do {
        _scoresStale = false;
        final shown = _shown;
        if (shown == null) return;
        final (:operation, :qsos, logRevision: _, chasing: _) = shown;
        final now = nowMillis();
        final candidates = <String, Map<String, dynamic>>{};
        void ask(Map<String, dynamic> spot) {
          for (final call in spotOperatorCalls(spot)) {
            candidates.putIfAbsent(spotCandidateKey(call, spot), () => spotCandidateQso(call, spot, now: now));
          }
        }

        mergedSpotBoard(spots.spotsBySource, settings.disabledSpotSources, entityOf: (call) => _callInfo[call]?.entityPrefix).forEach(ask);
        for (final list in spots.spotsBySource.values) {
          list.forEach(ask);
        }
        _chaseCandidates = {
          for (final MapEntry(:key, :value) in candidates.entries) key: {...value, 'our': stationOfOperation(operation)},
        };
        if (candidates.isEmpty) {
          // Already judged empty: nothing a reader shows has moved.
          if (_scores.isNotEmpty || _judgements.isNotEmpty || _scoredUuid != operation.uuid) {
            _scores = {};
            _judgements = {};
            _scoredUuid = operation.uuid;
            _mergeChase();
            _bump();
          }
          continue;
        }

        final segmented = SegmentedOperation.from(operation: operation.data, qsos: qsos);
        final scored = await extensions.scoreCandidates(
          operation: segmented.current,
          operationUuid: operation.uuid,
          candidates: candidates,
          segments: segmented.isSegmented ? segmented.payload : null,
          resume: scoring.liveResumeFor(operation, qsos),
          resumesFor: (scorers) => scoring.candidateResumesFor(operation, qsos, scorers),
          huntedRefTypes: _huntedRefTypesOf(operation),
        );
        // Nobody is left reading: the verdicts describe nothing on screen.
        if (_subscribers == 0) return;
        // Judged against an operation no longer shown. The switch that moved
        // it asked for a pass of its own, which found this one running and
        // left it the stale flag: go round for it rather than drop it.
        if (operation.uuid != _shown?.operation.uuid) {
          _scoresStale = true;
          continue;
        }
        // A null result means no scorer ran at all (runtime not up yet, or none
        // applies) — leave the previous verdicts alone rather than un-striking
        // every worked spot on a transient miss. A scorer that RAN and failed
        // is deliberately not that case: it comes back as the surviving
        // scorers' verdicts, empty if it was the only one, so a board never
        // keeps strikes put there by a scorer that is no longer answering.
        if (scored != null) {
          _scores = {for (final entry in scored.entries) entry.key: (notices: entry.value['notices'] ?? const [], alerts: entry.value['alerts'] ?? const [])};
          _scoredUuid = operation.uuid;
          _mergeChase();
          _bump();
        }
        await _judge();
      } while (_scoresStale && _subscribers > 0);
    } finally {
      _scoring = false;
    }
  }

  /// The last pass's candidates, worked from the shown station: what a change
  /// to the goals or a checklist judges again, without a scoring pass.
  Map<String, Map<String, dynamic>> _chaseCandidates = {};
  int _judgeSerial = 0;

  void _onChaseChanged() => unawaited(_judge());

  /// Judges [_chaseCandidates] under every goal that is on. Asks the programs
  /// only about candidates they have not seen ([ChaseService.judge] keeps
  /// their claims), so a checklist changing costs a reread of the table, not
  /// a crossing into the runtime per spot.
  Future<void> _judge() async {
    final chase = this.chase;
    final shown = _shown;
    if (chase == null || shown == null || _subscribers == 0) return;
    final serial = ++_judgeSerial;
    final judging = shown.chasing || chase.enabled;
    final guessing = judging && chase.goals.any((goal) => goal.on);
    final candidates = guessing ? await _withGuessedStates(_chaseCandidates, shown.operation.data) : _chaseCandidates;
    if (serial != _judgeSerial || _subscribers == 0) return;
    final judged = judging ? await chase.judge(candidates) : const <String, List<ChaseJudgement>>{};
    if (serial != _judgeSerial || _subscribers == 0) return;
    // Nothing judged before or now, as on every pass with chasing off: no
    // reader has anything to rebuild.
    if (judged.isEmpty && _judgements.isEmpty) return;
    _judgements = judged;
    _mergeChase();
    _bump();
  }

  /// The state an offline lookup gives each chase candidate, by its call and
  /// refs ([_stateKey]): from call history for a station worked before, from
  /// its park for a park spot. A spot carries no state of its own, so without
  /// this a program that chases states judges no spot at all. A null state:
  /// the lookup knew none, asked again once [_noStateRetry] has passed, since
  /// the data the lookup reads (a parks list still downloading, a hook that
  /// failed once) may have arrived since — but not on every pass, as most
  /// such calls are stations no lookup will ever place, a DX station with no
  /// state at all, and the board can hold hundreds. All of it is dropped
  /// when the extensions runtime restarts ([_statesGeneration]).
  final Map<String, ({String? state, int atMillis})> _candidateStates = {};
  int? _statesGeneration;

  /// The [_stateKey]s a pass is still asking about, each to the pass's
  /// completion. A pass starting meanwhile waits on it rather than asking
  /// again — the same reason as [_callInfoAsking] — and rather than judging
  /// without the state, which the pass asking would land too late to show.
  final Map<String, Future<void>> _statesAsking = {};
  static const _noStateRetry = Duration(minutes: 5);

  /// What an offline lookup's answer depends on: the call and the refs, not
  /// the band or mode a spot was on.
  static String _stateKey(Map<String, dynamic> candidate) {
    final refs = [
      for (final ref in (candidate['refs'] as List?) ?? const [])
        if (ref is Map) '${ref['type']}:${ref['ref']}',
    ]..sort();
    return '${asQsonString(asQsonMap(candidate['their'])?['call'])?.toUpperCase() ?? ''}|${refs.join(',')}';
  }

  static String _candidateCall(Map<String, dynamic> candidate) => asQsonString(asQsonMap(candidate['their'])?['call']) ?? '';

  /// [candidates], each carrying its looked-up state as the lookup's guess
  /// (`their.guess.state`), as a contact typed in the logging panel does.
  Future<Map<String, Map<String, dynamic>>> _withGuessedStates(Map<String, Map<String, dynamic>> candidates, Map<String, dynamic> operationData) async {
    final generation = extensions.runtimeGeneration.value;
    if (generation != _statesGeneration) {
      _candidateStates.clear();
      // A pass still asking the old runtime drops its answers, so a pass
      // waiting on it would come back without the states it was owed.
      _statesAsking.clear();
      _statesGeneration = generation;
    }
    final now = realNowMillis();
    bool known(String key) => switch (_candidateStates[key]) {
      null => false,
      (state: null, :final atMillis) => now - atMillis < _noStateRetry.inMilliseconds,
      _ => true,
    };
    final unknown = {
      for (final candidate in candidates.values)
        // As in [refreshCallInfo]: a call too short to be asked stops a pass.
        if (!known(_stateKey(candidate)) && _candidateCall(candidate).length >= 3) _stateKey(candidate): candidate,
    };
    final elsewhere = {for (final key in unknown.keys) ?_statesAsking[key]};
    final asking = [
      for (final entry in unknown.entries)
        if (!_statesAsking.containsKey(entry.key)) entry,
    ];
    final done = Completer<void>();
    for (final entry in asking) {
      _statesAsking[entry.key] = done.future;
    }
    try {
      for (final batch in _batches(asking)) {
        final results = await extensions.lookupCalls(
          [for (final entry in batch) (call: _candidateCall(entry.value), qso: entry.value)],
          operation: operationData,
          online: false,
          streakKey: _lookupStreakKey,
        );
        // Released while asking: what was found describes a board nobody
        // reads, and would outlive the release that cleared the cache.
        if (_subscribers == 0 || generation != _statesGeneration) return candidates;
        if (results.every((result) => result == null)) break;
        // Null is no answer at all, as in [refreshCallInfo]: asked again
        // on the next pass rather than cached as knowing nothing.
        _candidateStates.addEntries([
          for (final (i, result) in results.indexed)
            if (result != null) MapEntry(batch[i].key, (state: asQsonString(asQsonMap(result['guess'])?['state']), atMillis: now)),
        ]);
      }
    } finally {
      _statesAsking.removeWhere((_, pass) => pass == done.future);
      done.complete();
    }
    await Future.wait(elsewhere);
    if (_subscribers == 0 || generation != _statesGeneration) return candidates;
    return {
      for (final MapEntry(:key, :value) in candidates.entries)
        key: switch (_candidateStates[_stateKey(value)]?.state) {
          final state? => {
            ...value,
            'their': {
              ...?asQsonMap(value['their']),
              'guess': {...?asQsonMap(asQsonMap(value['their'])?['guess']), 'state': state},
            },
          },
          null => value,
        },
    };
  }

  /// Folds [_judgements] into [_scores] ([ChaseService.withNotices]).
  void _mergeChase() {
    final chase = this.chase;
    final chasing = _shown?.chasing ?? false;
    if (chase == null || _judgements.isEmpty && !chasing) {
      _withChase = _scores;
      return;
    }
    _withChase = {
      for (final key in {..._scores.keys, ..._judgements.keys}) key: chase.withNotices(_scores[key], _judgements[key] ?? const [], chasing: chasing),
    };
  }

  /// The activity types this operation has hunted, cached by `ScoringService`.
  /// What makes POTA's rules apply to a chaser's spots at all — an operation
  /// that activates nothing names no activity on its own refs.
  static Set<String> _huntedRefTypesOf(Operation operation) => ((operation.localData['huntedRefTypes'] as List?) ?? const []).whereType<String>().toSet();

  @override
  void dispose() {
    _scoreDebounce?.cancel();
    _callInfoSoon?.cancel();
    if (_subscribers > 0) {
      spots.removeListener(_onSpotsChanged);
      settings.removeListener(_onSettingsChanged);
      radio.removeListener(_onRadioChanged);
      chase?.removeListener(_onChaseChanged);
      _unsubscribeSpots?.call();
    }
    super.dispose();
  }
}

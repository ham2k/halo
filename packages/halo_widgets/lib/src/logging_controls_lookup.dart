// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the logging panel knows about the callsign being typed: the debounced
// lookup (an offline pass, then an online one), its per-session cache, the
// worked-before times, and the live scoring that feeds the call-info notices.
// All of it is keyed on ONE call — the call at the cursor — and every answer
// that lands for a call the operator has since moved past is dropped.
//
// [CallLookupModel] holds that state on behalf of `LoggingControls`. The
// panel still decides what a resolved lookup does to the entry (proposed
// references, per-QSO activity controls) through [CallLookupModel.onResolved],
// and when the whole thing is forgotten (a wipe, a QSO opened for editing).

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:halo_core/halo_core.dart';

import 'logging_controls_types.dart';
import 'panel_model.dart';

/// What the model reads from the panel's live configuration — re-read on
/// every use rather than copied in, because the hooks, the edited QSO and the
/// operation all change under a mounted panel.
typedef CallLookupConfig = ({
  CallLookup? lookup,
  Future<Map<String, dynamic>?> Function(Map<String, dynamic> qso)? settle,
  WorkedBefore? workedBefore,
  ScoreQso? scoreQso,
  Qso? editingQso,
  Operation operation,
});

/// Scoring keys that complain about the EXCHANGE — which, until the lookup
/// lands, is often only what the lookup is about to supply (a US station's
/// state), and until the operator stops typing, only half of what they mean.
/// Held back by [CallLookupModel] until both have had their chance; every
/// other key, an extension's own included, shows as soon as it is scored.
const kExchangeComplaintKeys = {'missingExchange', 'invalidExchange', 'shortGrid'};

/// How long a typed call must stand unchanged before any pill shows for it,
/// so the partial calls on the way to it (`KB2`, `KB2S`) never flash a set.
const kCallSettleDelay = Duration(milliseconds: 600);

/// How long after an exchange keystroke an exchange complaint may show.
const kExchangeTypingDelay = Duration(milliseconds: 500);

/// How long after the call last changed an exchange complaint stops waiting
/// for a lookup that has not finished.
const kExchangeLookupTimeout = Duration(seconds: 2);

/// Which pass of a lookup just landed — the panel applies a result's
/// proposed references off every pass, and only the [online] one may
/// re-trigger a lookup for them (see `LoggingControls._onLookupResolved`).
enum LookupPhase { cached, offline, online }

/// The callsign lookup, the worked-before answer and the live score for the
/// call at the cursor. See the file comment.
class CallLookupModel extends ChangeNotifier with PanelModel {
  CallLookupModel({
    required this.config,
    required this.activeCall,
    required this.isCallInfoActive,
    required this.qsoData,
    required this.segmented,
    required this.onResolved,
    required this.onCleared,
  });

  /// The panel's configuration as it stands right now.
  final CallLookupConfig Function() config;

  /// The single call that's actually relevant right now — the panel's
  /// `_callAtCursor`. Neither the lookup preview nor the scoring pills make
  /// sense against a raw multi-call field, so everything here keys off this.
  final String Function() activeCall;

  /// Whether the call-info panel is showing at all — the panel's own
  /// threshold (three alphanumerics), which the scoring shares so the pills
  /// never fire for a call the panel would not show.
  final bool Function() isCallInfoActive;

  /// The QSO being composed, as the hooks see it, with [call] in place of
  /// whatever the field holds — the lookup and the score are both asked
  /// about ONE call of a stack or list.
  final Map<String, dynamic> Function(String call) qsoData;

  /// The operation resolved into its segments, for scoring against the
  /// current one.
  final SegmentedOperation Function() segmented;

  /// A lookup landed for [call] — after this model has stored it, re-fired
  /// the score, and notified. The panel applies what the result proposes.
  final void Function(String call, Map<String, dynamic>? result, LookupPhase phase) onResolved;

  /// The shown result is gone — the field emptied, the text at the cursor
  /// stopped being a callsign, the draft reset — before the panel is asked
  /// to repaint. What the panel derived from a resolved lookup (per-QSO
  /// activity controls) goes with it.
  final VoidCallback onCleared;

  Timer? _lookupDebounce;
  Timer? _entriesDebounce;

  /// Counts [entriesEdited] calls, so only the latest one's settling lands.
  int _settlesIssued = 0;
  String? _lookupFor;
  Map<String, dynamic>? _result;

  /// The worked-before start times and the [workedBeforeKey] they answer
  /// for. The key is set when the fetch is ISSUED, not when it lands, so a
  /// second request for the same key is never issued and a late answer to a
  /// superseded one is dropped.
  ///
  /// Never cached across call changes the way [_cache] is: logging a QSO and
  /// typing the same call again must show one more, and the fetch is one
  /// column of a local query.
  String? _workedBeforeFor;
  List<int>? _workedBefore;

  /// Lookups resolved during the current compose session, keyed by call, so
  /// re-typing a call already looked up this session (KI2D → KI2DX → KI2D)
  /// shows its result instantly with no refetch. Cleared on wipe/log/populate.
  /// A cached `null` (a call that resolved to nothing) is distinct from absent.
  final Map<String, Map<String, dynamic>?> _cache = {};

  /// Live scoring for the call-info notices line (issue #40) — debounced like
  /// the lookup. [scoreFor] is the call the current keys belong to, so a
  /// stale result from a call the user has since edited past is ignored.
  Timer? _scoreDebounce;
  String? _scoreFor;
  List<String> _alertKeys = const [];
  List<String> _noticeKeys = const [];
  Map<String, List<String>> _scoreSources = const {};

  /// When the scored keys may show — see [currentAlertKeys]. Each names the
  /// call it applies to, so a call that moves on leaves its holds behind.
  ///
  /// [_settlingCall]: the call the operator last typed, until it has stood
  /// for [kCallSettleDelay]. [_lookupDoneFor]: the call whose lookup has
  /// finished. [_complaintClockFor]: the call whose [kExchangeLookupTimeout]
  /// has run out.
  ///
  /// The lookup and exchange holds end on a VERDICT, not on the event: the
  /// verdict held when a lookup lands or an exchange changes was scored
  /// without it, and releasing on the event shows the very complaint the
  /// rescore is about to withdraw. Scores are numbered as they are issued
  /// ([_scoresIssued]); [_verdictIssue] is the number of the one held, and
  /// [_lookupDoneAt] / [_exchangeChangedAt] the count when each event came.
  Timer? _settleTimer;
  String? _settlingCall;
  String? _typedCall;
  Timer? _exchangeTypingTimer;
  bool _exchangeTyping = false;
  String? _lookupDoneFor;
  int _scoresIssued = 0;
  int _verdictIssue = 0;
  int _lookupDoneAt = 0;
  int _exchangeChangedAt = 0;
  Timer? _complaintClock;
  String? _complaintClockCall;
  String? _complaintClockFor;

  // ---- What the panel reads ----

  /// The call the current [result] is for, or null while nothing is shown.
  String? get lookupFor => _lookupFor;

  /// [result], when it is for [call]; null otherwise. The check every
  /// consumer has to make, made once: a guess for the previous callsign must
  /// never paint under this one.
  Map<String, dynamic>? resultFor(String call) => _lookupFor == call ? _result : null;

  /// [resultFor] the call at the cursor.
  Map<String, dynamic>? get resultForActiveCall => resultFor(activeCall());

  /// Whether the notices belong to the call at the cursor — stale keys would
  /// paint the previous callsign's DUPE against this one.
  bool get scoreIsCurrent => _scoreFor == activeCall();

  /// The scored keys that may show right now. A score lands up to three times
  /// for one call (as typed, then as each lookup pass lands) and once more per
  /// exchange edit, and repainting each verdict as it arrives is what makes
  /// the pills jump. So nothing shows while the typed call is still settling,
  /// and an exchange complaint ([kExchangeComplaintKeys]) also waits out the
  /// exchange typing and the lookup, and then the verdict scored on what they
  /// brought — or [kExchangeLookupTimeout], for a lookup that never
  /// finishes. A key a newer verdict drops goes at once:
  /// only appearing is held, never correcting.
  List<String> get currentAlertKeys => _shown(_alertKeys);
  List<String> get currentNoticeKeys => _shown(_noticeKeys);
  Map<String, List<String>> get currentScoreSources => scoreIsCurrent && !_callSettling ? _scoreSources : const {};

  bool get _callSettling => _settlingCall != null && _settlingCall == activeCall();

  bool get _complaintsMayShow {
    if (_exchangeTyping || _verdictIssue <= _exchangeChangedAt) return false;
    final call = activeCall();
    final cfg = config();
    final lookupDone = cfg.lookup == null || cfg.editingQso != null || (_lookupDoneFor == call && _verdictIssue > _lookupDoneAt);
    return lookupDone || _complaintClockFor == call;
  }

  List<String> _shown(List<String> keys) {
    if (!scoreIsCurrent || _callSettling) return const [];
    if (!keys.any(kExchangeComplaintKeys.contains) || _complaintsMayShow) return keys;
    return [
      for (final key in keys)
        if (!kExchangeComplaintKeys.contains(key)) key,
    ];
  }

  /// What a worked-before answer is FOR: the call at the cursor AND the QSO
  /// left out of it. Both, because opening that same callsign's own QSO for
  /// editing has to refetch — the count must now exclude it, and a key of
  /// the call alone would call the already-fetched answer good.
  String get workedBeforeKey => '${activeCall()}|${config().editingQso?.uuid ?? ''}';

  /// The worked-before times for the call at the cursor, or null while they
  /// are unknown, belong to another key, or the typed call is still settling:
  /// the count sits in the pill row, and a partial call's history painting at
  /// every pause flashes it the way a partial call's score would.
  List<int>? get workedBefore => _workedBeforeFor == workedBeforeKey && !_callSettling ? _workedBefore : null;

  // ---- Lifecycle ----

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _entriesDebounce?.cancel();
    _scoreDebounce?.cancel();
    _settleTimer?.cancel();
    _exchangeTypingTimer?.cancel();
    _complaintClock?.cancel();
    super.dispose();
  }

  // ---- What the operator typed ----

  /// The operator typed in the call field. A call reached any other way — a
  /// spot, a QSO opened for editing, a restored draft — is not on its way to
  /// another one, and shows its pills as soon as they are scored. The caller
  /// schedules the score.
  ///
  /// [settles] false skips the hold: the field holds a list or a stack, and
  /// the cursor moving onto a call already entered is no keystroke towards
  /// another one.
  void callTyped({bool settles = true}) {
    final call = activeCall();
    // The field's listener also hears edits that leave the call at the cursor
    // as it was (a second call added to a list); restarting the clock for one
    // would blank pills that have already settled.
    if (call == _typedCall) return;
    _typedCall = call;
    _settleTimer?.cancel();
    if (!settles) {
      _settlingCall = null;
      return;
    }
    _settlingCall = call;
    _settleTimer = Timer(kCallSettleDelay, () {
      _settlingCall = null;
      notify();
    });
  }

  /// The operator typed, or picked a value, in an exchange field: the
  /// candidate is scored on it, so it is scored again — without this a
  /// county typed after the call never reaches the scorer, and its New Mult
  /// never shows.
  void exchangeEdited() {
    _exchangeTyping = true;
    _exchangeTypingTimer?.cancel();
    _exchangeTypingTimer = Timer(kExchangeTypingDelay, () {
      _exchangeTyping = false;
      notify();
    });
    exchangePrefilled();
  }

  /// The operator typed a state or a grid: the shown guess was settled
  /// without it, and the info line's distance, the map's mark and the guess
  /// the entry is saved with all read that guess. Settled again (local, no
  /// source asked) once the typing pauses; the cached result is replaced, so
  /// re-typing the call shows the settled one.
  void entriesEdited() {
    _entriesDebounce?.cancel();
    final settle = config().settle;
    if (settle == null) return;
    final settling = ++_settlesIssued;
    _entriesDebounce = Timer(const Duration(milliseconds: 300), () async {
      final call = activeCall();
      final result = resultFor(call);
      if (result == null) return;
      final settled = await settle(qsoData(call));
      final guess = settled?['guess'];
      // The call moved on, a newer lookup landed, or a later edit's settling
      // was issued, while this was out — or it answered no guess, which must
      // not wipe the one shown.
      if (isDisposed || guess is! Map || settling != _settlesIssued || resultFor(call)?['lookups'] != result['lookups']) return;
      final next = {...result, 'guess': guess};
      _result = next;
      _cache[call] = next;
      notify();
    });
  }

  /// A lookup's suggestion filled an exchange field. Nobody is typing, so
  /// there is no keystroke pause to wait out — only the verdict on the new
  /// value.
  void exchangePrefilled() {
    _exchangeChangedAt = _scoresIssued;
    scheduleScore();
  }

  // ---- Forgetting ----

  /// Drops a lookup still waiting on its debounce.
  void cancelLookup() => _lookupDebounce?.cancel();

  /// Forgets the shown result — the call field was emptied, or stopped
  /// being a callsign. The cache and the worked-before answer stand; the
  /// caller owns the rebuild, and hears [onCleared] first.
  void forget() {
    _lookupFor = null;
    _result = null;
    onCleared();
  }

  /// Forgets the worked-before answer; the caller owns the rebuild.
  void _forgetWorkedBefore() {
    _workedBeforeFor = null;
    _workedBefore = null;
  }

  /// Clears the live scoring notices — on wipe/reset/populate, or when the
  /// call drops below the call-info threshold. The caller owns the rebuild.
  void _clearScoreNotices() {
    _scoreDebounce?.cancel();
    if (_scoreFor == null && _alertKeys.isEmpty && _noticeKeys.isEmpty) return;
    _scoreFor = null;
    _alertKeys = const [];
    _noticeKeys = const [];
    _scoreSources = const {};
  }

  /// Everything a compose session accumulated: the shown result, the
  /// worked-before answer, the notices and the cache. A wipe, a log, and a
  /// QSO opened for editing all start from nothing. The caller owns the
  /// rebuild.
  void reset() {
    forget();
    _forgetWorkedBefore();
    _clearScoreNotices();
    _cache.clear();
    _settleTimer?.cancel();
    _settlingCall = null;
    _typedCall = null;
    _exchangeTypingTimer?.cancel();
    _exchangeTyping = false;
    _lookupDoneFor = null;
    _complaintClock?.cancel();
    _complaintClockCall = null;
    _complaintClockFor = null;
  }

  // ---- The lookup ----

  /// Schedules the debounced callsign lookup for the active call. Separate
  /// from the call-field listener so it can also be re-run when the QSO's
  /// refs change — a hunted POTA/SOTA ref feeds the POTA/SOTA `lookup`
  /// hooks, changing what the lookup resolves. See [relookupForRefsChanged].
  void scheduleLookup() {
    // Above every early return below, and on its own guard: a call that
    // returns to itself inside the debounce window — a typo and the
    // backspace correcting it — leaves `_lookupFor` still naming that call,
    // so the lookup rightly early-returns, and a pill hung off that return
    // would never be fetched again. Same reasoning as the call-field
    // listener hoisting [scheduleScore] above its own.
    refreshWorkedBefore();
    _lookupDebounce?.cancel();
    final lookup = config().lookup;
    if (lookup == null) return;
    // Preview lookup keys off whichever call is actually about to be logged
    // (issue #7's call stacking) or the segment the cursor is on within a
    // comma-separated list — the whole joined field text is never itself a
    // callsign once there's more than one call or stacked segment.
    final call = activeCall();
    if (_lookupFor == call) return;
    if (!looksLikeCallsign(call)) {
      forget();
      _forgetWorkedBefore();
      notify();
      return;
    }
    // Already looked up this call this session — show it instantly, no refetch.
    // Refs are re-applied off the cached result too, not just off a fresh
    // one. Typing back to a call whose guessed refs were just cleared —
    // KI2D, corrected to KI2E, corrected back — reaches the lookup only
    // through this cache hit, and would otherwise show the guess in the
    // info panel while the park it named is missing from the QSO.
    if (_cache.containsKey(call)) {
      _adopt(call, _cache[call], LookupPhase.cached);
      return;
    }

    _lookupDebounce = Timer(const Duration(milliseconds: 300), () async {
      // Offline pass first: fast, local-data-only, so the user sees
      // whatever's cheaply available (e.g. the callsign-annotation
      // pre-step) almost instantly. Then an online pass fills in
      // network-sourced data (QRZ/HamDB/etc) as soon as it resolves — no
      // extra artificial delay beyond its own network latency.
      // Each pass is settled against the entry as it was asked; a state or
      // grid typed while one is out is settled into it once it lands.
      var settlesAsked = _settlesIssued;
      final offlineResult = await _fetch(lookup, call, online: false);
      if (isDisposed || activeCall() != call) return; // stale — the active call changed
      _cache[call] = offlineResult;
      // Spot-derived refs land here, off the OFFLINE pass, deliberately
      // without a re-lookup: the online pass below rebuilds its `qso`
      // argument from scratch, so the POTA/SOTA hooks see the just-added
      // park/summit on that pass and resolve its grid — a re-lookup here
      // would instead race the online pass already in flight.
      _adopt(call, offlineResult, LookupPhase.offline);
      if (_settlesIssued != settlesAsked) entriesEdited();

      settlesAsked = _settlesIssued;
      final onlineResult = await _fetch(lookup, call, online: true);
      if (isDisposed || activeCall() != call) return; // stale — the active call changed
      // A failed/timed-out online pass (host down, network error) must not
      // erase an already-shown, still-valid offline preview — keep it. It is
      // still the end of the lookup: there is nothing left to wait for.
      if (onlineResult == null) {
        _lookupDone(call);
        notify();
        scheduleScore();
        return;
      }
      _cache[call] = onlineResult;
      _adopt(call, onlineResult, LookupPhase.online);
      if (_settlesIssued != settlesAsked) entriesEdited();
    });
  }

  /// Takes [result] as the answer for [call]: shown, re-scored (a lookup
  /// resolving is what brings the state a US station is scored on), logged
  /// for the dev console, and only THEN handed to the panel — [onResolved]'s
  /// contract is that the model has already stored and re-fired by the time
  /// it runs. One place for the three passes, so none can reorder it.
  void _adopt(String call, Map<String, dynamic>? result, LookupPhase phase) {
    _lookupFor = call;
    _result = result;
    if (phase != LookupPhase.offline) _lookupDone(call);
    notify();
    scheduleScore();
    if (phase != LookupPhase.cached) _log(phase.name, call, result);
    onResolved(call, result, phase);
  }

  /// The lookup for [call] has nothing left to bring; see [_lookupDoneAt].
  void _lookupDone(String call) {
    _lookupDoneFor = call;
    _lookupDoneAt = _scoresIssued;
  }

  Future<Map<String, dynamic>?> _fetch(CallLookup lookup, String call, {required bool online}) => lookup(
    call,
    qso: qsoData(call),
    operation: config().operation.data,
    online: online,
    // The `recentContextLookup` sources run only while composing a new
    // contact, which is the one case where "what is this station doing
    // right now" is a question about the QSO being made. Editing a saved
    // record is a question about the past: what a spot says now has no
    // bearing on a contact already logged, and the panel would refuse
    // the proposed refs anyway.
    recentContext: config().editingQso == null,
  );

  /// Re-runs the callsign lookup after the QSO's refs change (e.g. adding a
  /// hunted POTA park or SOTA summit). The POTA/SOTA `lookup` hooks read the
  /// QSO's refs to resolve a park/summit grid, but the lookup is otherwise
  /// keyed and cached by callsign alone — so a ref added after the call would
  /// never reach the guess. Invalidate the cache entry for the active call and
  /// re-schedule (ham2k/halo-dist#185). The panel gates this on its own
  /// populating state.
  void relookupForRefsChanged() {
    if (config().lookup == null) return;
    final call = activeCall();
    if (!looksLikeCallsign(call)) return;
    _cache.remove(call);
    _lookupFor = null;
    if (_lookupDoneFor == call) _lookupDoneFor = null;
    scheduleLookup();
  }

  /// Structured dev event (#237) for a resolved call lookup — a compact summary
  /// of the guess so agents can watch `[lookup]` in the console / recentLog().
  void _log(String phase, String call, Map<String, dynamic>? result) {
    DevLog.instance.log('lookup', {
      'call': call,
      'phase': phase,
      'name': result?['name'],
      'grid': result?['grid'],
      'entity': result?['entityName'],
      'source': result?['matchSource'] ?? result?['source'],
    });
  }

  // ---- Worked before ----

  /// Fetches the worked-before times for the call at the cursor, unless an
  /// answer is already in hand or in flight for exactly this key. That guard
  /// is also what keeps this off the keystroke path: the call field notifies
  /// on cursor moves and re-entered text as well, and only a genuinely new
  /// key reaches the log.
  ///
  /// Deliberately notifies nothing: this runs from the panel's `initState`
  /// too (a deeplink cold-start reaches [scheduleLookup] there), and every
  /// caller rebuilds on its own account anyway.
  void refreshWorkedBefore() {
    final fetch = config().workedBefore;
    final call = activeCall();
    if (fetch == null || !looksLikeCallsign(call)) return;
    final key = workedBeforeKey;
    if (_workedBeforeFor == key) return;
    _workedBeforeFor = key;
    _workedBefore = null;
    unawaited(_loadWorkedBefore(key, call, fetch));
  }

  Future<void> _loadWorkedBefore(String key, String call, WorkedBefore fetch) async {
    final times = await fetch(call, excludingQsoUuid: config().editingQso?.uuid);
    if (isDisposed || _workedBeforeFor != key) return; // stale — the call or the edit moved on
    _workedBefore = times;
    notify();
  }

  // ---- Scoring ----

  /// (Re)schedules a debounced live-scoring pass for the call-info notices
  /// line — call/band/mode all feed New Band / New Mode / New DXCC / Dupe, and
  /// the worked station's state feeds New State / New Province, so this is
  /// fired whenever any of them changes (and when an existing QSO is selected
  /// for editing). Debounced on the same 300ms as the offline lookup, so the
  /// scoring pills land alongside the offline lookup's data rather than
  /// lagging it.
  ///
  /// A lookup RESOLVING must re-fire it too: the state a US station is scored
  /// on almost always arrives as `guess.state` from the lookup, which lands
  /// after this debounce has already run against a QSO that had no guess at
  /// all. Without that, New State only ever appeared for a call already in
  /// the cache. No-op (and clears) below the call-info threshold or with no
  /// `scoreQso` wired.
  void scheduleScore() {
    final scoreFn = config().scoreQso;
    if (scoreFn == null) return;
    _scoreDebounce?.cancel();
    final call = activeCall();
    // An incomplete call scores nothing by rule, so it is answered here
    // rather than by the scorers, which would judge the letters around the
    // `?` as a station (ScoringService). It still counts as scored: editing
    // a saved one holds the info area until it is.
    if (isCallInfoActive() && isIncompleteCall(call)) {
      _scoreFor = call;
      _alertKeys = const ['incompleteCall'];
      _noticeKeys = const [];
      _scoreSources = const {};
      notify();
      return;
    }
    // Only score a plausible callsign — the same gate the lookup uses. Without
    // it, command input ("RELOAD", "NOTE hi") and non-callsign junk would each
    // fire a whole-log getQsos read in the runtime for nothing.
    if (!isCallInfoActive() || !looksLikeCallsign(call)) {
      _clearScoreNotices();
      notify();
      return;
    }
    if (_complaintClockCall != call) {
      _complaintClock?.cancel();
      _complaintClockCall = call;
      // A clock that ran out for this call before the operator left it does
      // not excuse the verdicts its return brings.
      _complaintClockFor = null;
      _complaintClock = Timer(kExchangeLookupTimeout, () {
        _complaintClockFor = call;
        notify();
      });
    }
    _scoreDebounce = Timer(const Duration(milliseconds: 300), () async {
      // Scored against the CURRENT segment, matching the entry row's own gate
      // (the panel's `_activeRefTypes`): the pills and the fields have to agree
      // about which activities are running. The timeline goes along so the log
      // the candidate is judged against is folded per-segment too — otherwise
      // a contest that started at a break calls a pre-contest contact a dupe.
      final cfg = config();
      final segments = segmented();
      final issue = ++_scoresIssued;
      final result = await scoreFn(
        operation: {...segments.current, 'uuid': cfg.operation.uuid},
        qso: qsoData(call),
        excludeUuid: cfg.editingQso?.uuid,
        segments: segments.isSegmented ? segments.payload : null,
      );
      if (isDisposed || activeCall() != call) return; // stale — the active call moved on
      if (issue < _verdictIssue) return; // overtaken by a verdict on newer input
      _verdictIssue = issue;
      _scoreFor = call;
      _alertKeys = ((result?['alerts'] as List?) ?? const []).whereType<String>().toList();
      _noticeKeys = ((result?['notices'] as List?) ?? const []).whereType<String>().toList();
      _scoreSources = {
        for (final MapEntry(:key, :value) in ((result?['sources'] as Map?) ?? const {}).entries)
          if (key is String && value is List) key: value.whereType<String>().toList(),
      };
      notify();
    });
  }
}

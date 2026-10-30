// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `activity` hook calls: the controls an activity puts on the logging
// panel and in operation settings, the ref types those controls name, the
// patch it makes to a QSO before the save, and the activity picker's
// search — with the result types they answer in.

part of 'extension_service.dart';

/// What the activity picker's search came back with, and whether it came back
/// at all. [allSourcesFailed] separates "no extension had a match" from "no
/// extension could answer" — identical empty lists that mean opposite things
/// to the operator. [someSourcesFailed] says at least one could not: with
/// nothing found, the one that failed may be the one holding the answer.
typedef ActivitySuggestionResult = ({List<Map<String, dynamic>> suggestions, bool allSourcesFailed, bool someSourcesFailed});

/// The control descriptors an activity fan-out produced, and whether any
/// source failed to answer. [loadFailed] separates "no extension declares
/// controls" from "an extension that does declare them could not answer" —
/// identical empty lists, and only the second may not be treated as the
/// operator's ref types being unknown. Without it a hook that throws or
/// times out is indistinguishable from its extension being uninstalled, and
/// `isUnknownRefType` says exactly that to the operator.
typedef ControlsResult = ({List<Map<String, dynamic>> controls, bool loadFailed});

/// The descriptor field naming the extension that supplied a control. The
/// host writes it as the fan-out answers, over anything the extension put
/// there: the control's own `key` is the extension's to choose, and a
/// catalog `ham2k-pota` keys its controls `pota/…`, so the key cannot say
/// which extension to ask or to name.
const controlExtensionKeyField = 'extensionKey';

/// The extension that supplied [control], or empty for a descriptor that did
/// not come through the fan-out.
String controlExtensionKey(Map<String, dynamic> control) => control[controlExtensionKeyField] as String? ?? '';

/// How far a screen's [ControlsResult] fetch has got. A bool cannot express
/// [failed] — it only says "not loaded yet" — so a fetch that threw leaves a
/// two-state screen showing its loading placeholder forever, with the
/// unknown-ref treatment suppressed the whole time.
enum ControlsLoadState { loading, loaded, failed }

mixin _ExtensionActivityCalls {
  // Owned by the class or by another part of this library.
  ExtensionHost? get host;
  SettingsService? get settings;
  StatusBarService? get statusBar;
  List<ExtensionInfo> get availableExtensions;
  Future<T> whenSettled<T>(Future<T> Function() ask);

  /// Descriptors for controls activities want on the logging panel. `qso` is
  /// the in-progress QSO (including any `their.guess` from the callsign
  /// lookup pipeline) — pass it so an extension can key a QSO-scoped
  /// `placeholder`/`transforms` (e.g. a DXCC-derived reference prefix) off
  /// it; omit for a QSO-agnostic refresh (e.g. right after the operation loads).
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) =>
      _collectControls(Hooks.activityLoggingControls, operationData, qso: qso);

  /// Descriptors for controls activities want in operation settings.
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) =>
      _collectControls(Hooks.activityOperationControls, operationData, qso: qso);

  /// The activity reference TYPES each running extension publishes, keyed by
  /// the activity's word and by the extension's key: `pota` and `ham2k-pota`
  /// -> `(activationType: 'potaActivation', huntingType: 'pota')`. A deep
  /// link, and anything else naming an activity, needs this to turn
  /// `pota:US-1234` into a real ref.
  ///
  /// Read off the `refList` control descriptors an activity ALREADY publishes
  /// rather than from a hook of its own: those descriptors are where an
  /// activity names its types, and a second declaration would be a second
  /// thing to keep in step. An operation control is an activation, a logging
  /// control is a hunt.
  ///
  /// Only extensions that are switched ON answer, because only they publish
  /// controls — matching app-polo, whose `findHooks('activity', {key})` sees
  /// registered hooks alone. A key nobody claims is absent here, and a caller
  /// skips that reference rather than inventing a type for it.
  ///
  /// [operationData] is passed through to the hooks, which may key a
  /// descriptor's placeholder off it; the ref TYPES never vary with it, so an
  /// empty map is a fine argument when there is no operation yet.
  ///
  /// `loadFailed` carries [ControlsResult]'s own distinction and MUST be
  /// honoured: an empty `byKey` with `loadFailed` set means "could not ask",
  /// not "nobody claims that key". Telling an operator their installed
  /// activity is unknown, because the runtime had not finished booting, is a
  /// confident false statement about their own setup.
  ///
  /// Asks through [whenSettled] for exactly that reason: a deep link that
  /// cold-launches the app arrives before boot has finished, and one that
  /// arrives while a toggled extension restarts the runtime finds no host,
  /// or one whose pending calls the replacement is about to fail.
  Future<({Map<String, ({String? activationType, String? huntingType})> byKey, bool loadFailed})> activityRefTypes({
    Map<String, dynamic> operationData = const {},
  }) async {
    final results = await whenSettled(() => Future.wait([operationControls(operationData), loggingControls(operationData)]));
    final activation = _refTypesByActivityKey(results[0].controls);
    final hunting = _refTypesByActivityKey(results[1].controls);
    return (
      byKey: {
        for (final key in {...activation.keys, ...hunting.keys}) key: (activationType: activation[key], huntingType: hunting[key]),
      },
      loadFailed: results[0].loadFailed || results[1].loadFailed,
    );
  }

  /// The `refList` ref type each control descriptor carries, keyed by the
  /// extension that supplied it (`ham2k-pota`) and by the type's
  /// [activityScopeWord] (`pota`) — the word a deep link names an activity
  /// by, which is app-polo's activity key and not any extension's. Controls
  /// that are not reference lists carry no type and are skipped.
  ///
  /// The first descriptor for a key wins. Every activity publishes exactly one
  /// `refList` per surface, so an extension's own key never ties — if that
  /// ever stops being true, the tie needs a real rule rather than fan-out
  /// order. A word does tie when two extensions serve one type, and the first
  /// of them answers a deep link naming it.
  static Map<String, String> _refTypesByActivityKey(List<Map<String, dynamic>> controls) {
    final types = <String, String>{};
    for (final control in controls) {
      final input = control['input'];
      if (input is! Map) continue;
      final refType = input['refType'];
      if (refType is! String || refType.isEmpty) continue;
      for (final key in [controlExtensionKey(control), activityScopeWord(refType)]) {
        if (key.isNotEmpty) types.putIfAbsent(key, () => refType);
      }
    }
    return types;
  }

  /// Lets activities project data they own into generic QSON fields just
  /// before a QSO is written — a contest mirroring the exchange it keeps on
  /// its own ref into `their.exchange`, which is what the QSO row's exchange
  /// column and a plain ADIF export read. See `ActivityHook.processQsoBeforeSave`.
  ///
  /// Returns [qsoData] with every hook's patch merged in, unchanged if nothing
  /// contributed. Degrades silently: a hook that throws or times out must never
  /// cost the operator their QSO, so the save proceeds undecorated.
  ///
  /// Skipped when the operation carries no refs — ordinary logging is the
  /// common case and must not pay a bridge crossing per QSO for a hook only
  /// contests implement.
  Future<Map<String, dynamic>> decorateQsoBeforeSave(Map<String, dynamic> qsoData, Map<String, dynamic> operationData) async {
    final host = this.host;
    if (host == null) return qsoData;
    final refs = operationData['refs'];
    if (refs is! List || refs.isEmpty) return qsoData;

    try {
      final entries = await host.invokeAll(
        Hooks.activityProcessQsoBeforeSave,
        args: {'qso': qsoData, 'operation': operationData},
        // Saving blocks the operator's next QSO, so a stalled hook loses its
        // contribution rather than the log its pace — and only its own: the
        // timeout is one budget for the whole fan-out, and without partials
        // one slow contest discards every other activity's patch with it.
        timeout: const Duration(seconds: 2),
        partialOnTimeout: true,
      );
      var merged = qsoData;
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! Map) continue;
        // The ref types the hook's extension owns, as the kernel reports them,
        // are what let a patch touch that extension's refs and no other (see
        // `mergeQsoPatch`) — not the hook's key: a catalog contest's key
        // (`ham2k-cqww`) is not the ref type its logs carry (`cqww`). An entry
        // without them can still project into `their`/`our`, but writes no ref.
        final refTypes = entry['refTypes'];
        final owners = {if (refTypes is List) ...refTypes.whereType<String>()};
        merged = mergeQsoPatch(merged, (entry['value'] as Map).cast<String, dynamic>(), owners: owners);
      }
      return merged;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] processQsoBeforeSave failed: $e');
      return qsoData;
    }
  }

  Future<ControlsResult> _collectControls(HookRef hook, Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async {
    final host = this.host;
    // No host is a failure, not an empty answer: the runtime is dead or
    // still starting (see ErrorPolicy's `extension-runtime-dead`), and the
    // operator's refs are no less real for it.
    if (host == null) return (controls: const <Map<String, dynamic>>[], loadFailed: true);
    try {
      final entries = await host.invokeAll(
        hook,
        args: {'operation': operationData, 'qso': ?qso},
        // The timeout is ONE budget for the whole fan-out, so without this a
        // single slow extension discards the controls every other hook had
        // already returned — the operator loses POTA's fields because SOTA
        // is warming a cache. Activities are independent contributors here,
        // and the hooks that time out come back synthesized as ok:false,
        // which is what sets `loadFailed` and names them below. A partial
        // answer is safe precisely because it is no longer a silent one.
        partialOnTimeout: true,
      );
      final controls = <Map<String, dynamic>>[];
      var loadFailed = false;
      for (final entry in entries) {
        // `invokeHookAll` synthesizes {key, ok: false, error} precisely so a
        // caller can name the source rather than just notice an absence.
        if (entry['ok'] != true) {
          loadFailed = true;
          debugPrint('[extensions] ${hook.method}: hook ${entry['key']} failed: ${entry['error']}');
          continue;
        }
        // A hook that answered with something other than a list contributed
        // nothing, but it ANSWERED — `partitionHookEntries` classifies the
        // same entry as a success, and the two must agree. The kernel wraps
        // every return as `value: (await …) ?? null`, so a hook that simply
        // falls off its end lands here; calling that a failure would show a
        // permanent "controls unavailable" notice for a legal no-op.
        //
        // A non-null one is still a shape bug worth an author seeing, though:
        // `[42]` below is named in the log, and silence here would make the
        // narrower mistake the harder one to find.
        final value = entry['value'];
        if (value is! List) {
          if (value != null) {
            debugPrint('[extensions] ${hook.method}: hook ${entry['key']} answered ${value.runtimeType}, wanted a List');
          }
          continue;
        }
        for (final control in value) {
          // Per element, NOT `value.cast<Map>()`: that cast is lazy, so a bad
          // element throws its TypeError during `addAll` — past the
          // ExtensionHostException catch below, out through the unawaited
          // future the callers start in initState, leaving them stuck on
          // `loading` for the life of the screen.
          if (control is! Map) {
            loadFailed = true;
            debugPrint('[extensions] ${hook.method}: hook ${entry['key']} returned a ${control.runtimeType} control');
            continue;
          }
          controls.add({...control.cast<String, dynamic>(), controlExtensionKeyField: entry['key']});
        }
      }
      // Read, don't cast: `as num?` throws on `{'order': '1'}` — a string an
      // extension reading its own config produces easily — and it throws from
      // inside the comparator, which is the same escape route past the catch
      // below that the per-element check above exists to close.
      num orderOf(Map<String, dynamic> control) => control['order'] is num ? control['order'] as num : 0;
      controls.sort((a, b) => orderOf(a).compareTo(orderOf(b)));
      return (controls: controls, loadFailed: loadFailed);
    } on ExtensionHostException catch (e) {
      // A timeout with something salvageable behind it is handled above, by
      // `partialOnTimeout`. What reaches here is the whole fan-out failing —
      // a dead runtime, or a timeout with nothing settled — where there is
      // no partial answer to keep.
      debugPrint('[extensions] ${hook.method} failed: $e');
      return (controls: const <Map<String, dynamic>>[], loadFailed: true);
    }
  }

  /// Candidate activities for the "add activity" search, merged across every
  /// `activity` hook and sorted by `distance / relevance` ascending — a more
  /// relevant hit (relevance is 0..1, higher is better) effectively counts
  /// as closer, so it doesn't lose out to a less relevant but nearer one
  /// (results missing a distance sort after ranked ones — an extension
  /// search hit with no location still surfaces). `location` comes from the
  /// operation's own coordinate, else the centre of its grid, else
  /// [fallbackLocation] (typically the
  /// device's current GPS position — see ActivitiesView) so nearby
  /// suggestions still work before the operation's location is set.
  /// `callsign` falls back from the operation's own settings to the
  /// operator's global default.
  /// [activityKeys] scopes the fan-out to the activity extensions serving one
  /// ref type (the search field's `pota:` prefix — usually one hook, two when
  /// a user-published extension serves the same type as a stock one) or to
  /// one extension by its key (`ham2k-pota:`) — those hooks alone are asked,
  /// rather than every hook's results being merged and then filtered, so an
  /// unrelated extension's slow search can't hold up a scoped one.
  /// [preferredKeys] is the softer form (a `pota` word, no colon): everyone
  /// is still asked, but those hooks' results lead the list and they search
  /// for [preferredSearchTerm] — or, with none, are asked as a scope for
  /// their own list — while the others get [searchTerm].
  /// Answers whether every source failed as well as the suggestions
  /// themselves: "nothing matched" and "every extension broke" are the same
  /// empty list, and only the second is worth telling the operator about.
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    List<String>? activityKeys,
    List<String>? preferredKeys,
    String? preferredSearchTerm,
    ({double south, double west, double north, double east})? searchWithin,
  }) async {
    // A booting or replacing runtime is waited out rather than answered for:
    // the picker never asks again on its own, so "failed" here would stand
    // until the operator typed. No host once that settles is a failure — no
    // extension could answer — not an empty list of matches.
    final host = this.host ?? await whenSettled(() async => this.host);
    if (host == null) return (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: true, someSourcesFailed: true);

    // The operation's own coordinate first, then the centre of its grid: a
    // park two kilometres away and one eight kilometres away rank the same
    // from a square's centre, and this ordering is what the operator reads as
    // "nearby".
    final gridLocation = locationFromLatLon(operationData['lat'], operationData['lon']) ?? gridToLocation(operationData['grid'] as String?) ?? fallbackLocation;
    final callsign = (operationData['stationCall'] as String?)?.isNotEmpty == true
        ? operationData['stationCall'] as String
        : settings?.activeProfile.operatorCall;

    // `scoped` tells a hook its type alone is being asked for — the operator
    // picked its "Activity Types" row, or typed its word as a scope. A bare
    // scope and the nearby list both arrive with no search term, and an
    // extension that keeps itself out of the nearby list still has to answer
    // when it is the one being asked.
    // A view's centre stands in for the operation's place: extensions measure
    // and rank from `location`, and one that predates `bounds` answers with
    // what is nearest the middle of the view rather than of somewhere else.
    final searchCenter = switch (searchWithin) {
      (:final south, :final west, :final north, :final east) => GridLocation(
        (south + north) / 2,
        west <= east ? (west + east) / 2 : ((west + east + 360) / 2 + 180) % 360 - 180,
      ),
      null => null,
    };

    Map<String, dynamic> argsSearchingFor(String? term, {bool scoped = false}) => {
      'operation': operationData,
      if (searchCenter ?? gridLocation case final at?) 'location': {'lat': at.latitude, 'lon': at.longitude},
      if (searchWithin case (:final south, :final west, :final north, :final east)) 'bounds': {'south': south, 'west': west, 'north': north, 'east': east},
      if (callsign != null && callsign.isNotEmpty) 'callsign': callsign,
      if (term != null && term.isNotEmpty) 'searchTerm': term,
      if (scoped) 'scoped': true,
    };

    // A search run [searchWithin] a map's view still reports each result's
    // distance from the operation's own place: that is the distance its card
    // shows, and "12 km" from wherever the map happened to be is no answer.
    List<Map<String, dynamic>> measured(List<Map<String, dynamic>> suggestions) {
      if (searchWithin == null) return suggestions;
      return [
        for (final suggestion in suggestions)
          {
            for (final entry in suggestion.entries)
              if (entry.key != 'distance') entry.key: entry.value,
            if ((
                  gridLocation,
                  locationFromLatLon(suggestion['lat'], suggestion['lon']) ??
                      gridToLocation(suggestion['grid'] is String ? suggestion['grid'] as String : null),
                )
                case (final from?, final to?))
              'distance': distanceOnEarthKm(from, to),
          },
      ];
    }

    try {
      if (activityKeys != null) {
        final entries = await _activityBatch(host, activityKeys, argsSearchingFor(searchTerm, scoped: true), 'scoped');
        final suggestions = measured(mergeActivitySuggestions(entries));
        _noticeActivitySourcesFailed(_failedActivityKeys(entries), found: suggestions.isNotEmpty);
        return (suggestions: suggestions, allSourcesFailed: allActivitySourcesFailed(entries), someSourcesFailed: entries.any((entry) => entry['ok'] != true));
      }

      // The preferred hooks are asked SEPARATELY because they may search for
      // something else — for nothing at all, as a scope, when the word stood
      // alone — so their answers to the everyone-else question are discarded
      // below rather than merged.
      // A fan-out that never returned an entry is a failure with nothing to
      // count, so it contributes one — the caller has to be able to tell
      // "nobody could answer" from "nobody had anything".
      var fanOutFailed = false;
      // A word standing alone asked the preferred hooks for their own list,
      // as a scope does, so every one of them failing fails the search the
      // way a failed scope would — what the others found for the word as
      // text is not the list that was asked for.
      final ownList = preferredSearchTerm == null && (preferredKeys?.isNotEmpty ?? false);
      var ownListFailed = false;
      var preferredFailedKeys = const <String>[];
      final preferred = _activityBatch(host, preferredKeys ?? const [], argsSearchingFor(preferredSearchTerm, scoped: ownList), 'preferred')
          // Precedence is otherwise only an ordering: when a preferred hook
          // fails, what the other extensions found is still the right answer.
          .then((entries) {
            ownListFailed = ownList && allActivitySourcesFailed(entries);
            preferredFailedKeys = _failedActivityKeys(entries);
            return [
              for (final entry in entries)
                if (entry['ok'] == true) entry,
            ];
          })
          .onError<ExtensionHostException>((e, _) {
            debugPrint('[extensions] preferred activity hooks failed: $e');
            ownListFailed = ownList;
            preferredFailedKeys = [...?preferredKeys];
            return const <Map<String, dynamic>>[];
          });

      // The fan-out is ONE message under ONE timeout. Partials are kept, so
      // one slow hook costs only its own answer: without them, a POTA stuck
      // behind a busy database throws away what every other extension found.
      // The preferred hooks, asked separately, degrade on their own as well.
      final everyone = host
          .invokeAll(Hooks.activitySuggest, args: argsSearchingFor(searchTerm), timeout: const Duration(seconds: 5), partialOnTimeout: true)
          .then((entries) {
            for (final entry in entries) {
              if (entry['ok'] != true) debugPrint('[extensions] activity hook ${entry['key']} failed: ${entry['error']}');
            }
            return entries;
          })
          .onError<ExtensionHostException>((e, _) {
            debugPrint('[extensions] activity suggestion fan-out failed: $e');
            fanOutFailed = true;
            return const [];
          });

      final results = await Future.wait([preferred, everyone]);
      final preferredSet = preferredKeys?.toSet() ?? const <String>{};
      final entries = [
        ...results[0],
        for (final entry in results[1])
          if (!preferredSet.contains(entry['key'])) entry,
      ];
      final suggestions = measured(mergeActivitySuggestions(entries, preferredKeys: preferredSet));
      final failedKeys = [...preferredFailedKeys, ..._failedActivityKeys(entries), if (fanOutFailed) _everyOtherActivity];
      _noticeActivitySourcesFailed(failedKeys, found: suggestions.isNotEmpty);
      return (
        suggestions: suggestions,
        allSourcesFailed: ownListFailed || (fanOutFailed && entries.isEmpty) || allActivitySourcesFailed(entries),
        someSourcesFailed: failedKeys.isNotEmpty,
      );
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] suggestActivities failed: $e');
      return (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: true, someSourcesFailed: true);
    }
  }

  static List<String> _failedActivityKeys(List<Map<String, dynamic>> entries) => [
    for (final entry in entries)
      if (entry['ok'] != true)
        if (entry['key'] case final String key) key,
  ];

  /// Stands in for the extensions a fan-out that failed as a whole never
  /// named — it has no roster to name them from.
  static const _everyOtherActivity = '*';

  /// When each activity extension's failure was last shown in the status bar.
  final Map<String, int> _activityFailureShownAt = {};

  static const activityFailureNoticeEvery = Duration(minutes: 10);

  /// Names, in the status bar, the activity extensions that did not answer a
  /// search that still found something: the sheet shows the results it has,
  /// and nothing else says the list may be short. A search that found
  /// nothing says so in the sheet itself. Each extension at most once every
  /// [activityFailureNoticeEvery] — the search runs on every pause in typing
  /// and every pan of the map, and one that stays down would post on each.
  void _noticeActivitySourcesFailed(List<String> keys, {required bool found}) {
    if (!found || keys.isEmpty) return;
    final now = realNowMillis();
    bool shownLately(String key) => switch (_activityFailureShownAt[key]) {
      final shown? => now - shown < activityFailureNoticeEvery.inMilliseconds,
      null => false,
    };
    final due = [
      for (final key in keys.toSet())
        if (!shownLately(key)) key,
    ];
    if (due.isEmpty) return;
    for (final key in due) {
      _activityFailureShownAt[key] = now;
    }
    final names = [for (final key in due) availableExtensions.where((info) => info.key == key).firstOrNull?.effectiveShortName ?? key];
    statusBar?.setMessage(
      key: 'activity-search:failed',
      icon: 'alert-circle',
      text: due.contains(_everyOtherActivity)
          ? t.extensionService.activitySearchSomeSourcesFailed
          : t.extensionService.activitySearchSourcesFailed(names: names.join(', ')),
      dismissAfter: const Duration(seconds: 10),
    );
  }

  /// `suggest` on each of [keys]' activity hooks, in one batch: one entry per
  /// key, in [ExtensionHost.invokeHookAll]'s `{key, ok, value}` shape so the merge needs no
  /// second code path — one failing hook is one failed entry, never the whole
  /// answer. [label] names the search in the console.
  Future<List<Map<String, dynamic>>> _activityBatch(ExtensionHost host, List<String> keys, Map<String, dynamic> args, String label) async {
    final answers = await host.invokeHookBatch(
      [for (final key in keys) Hooks.activitySuggest.withArgs(args, key: key)],
      timeout: const Duration(seconds: 5),
      partialOnTimeout: true,
    );
    final entries = [
      for (final (i, key) in keys.indexed) <String, dynamic>{...answers[i], 'key': key},
    ];
    for (final entry in entries) {
      if (entry['ok'] != true) debugPrint('[extensions] $label activity hook ${entry['key']} failed: ${entry['error']}');
    }
    return entries;
  }
}

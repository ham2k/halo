// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Activities sheet's search: what the box and the results map asked the
// extensions about the operation, what came back, and each answer's web link.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../../services/error_reporting_service.dart';
import '../../services/extensions/extension_ref_results.dart' show RefLink;
import '../../services/halo_services.dart';
import '../../services/outline_grid_service.dart';
import '../map/map_zoom_controller.dart' show MapViewBounds;
import 'activity_search_query.dart';

/// The key a ref's link is cached under. Null for a ref with nothing to ask
/// about — an activity the operator has added but not yet filled in.
String? refLinkKey(Map<String, dynamic> ref) {
  final type = ref['type'] as String?;
  final reference = ref['ref'] as String?;
  if (type == null || reference == null || reference.isEmpty) return null;
  return '$type:$reference';
}

/// Resolves one link per ref, in one crossing for the whole list.
///
/// The hooks build a URL from the reference and nothing else (no network —
/// `docs/extensions/hooks.md`), which is what makes it affordable to ask
/// again for a whole list of search results on every keystroke's search.
Future<Map<String, RefLink>> resolveRefLinks(HaLoServices services, List<Map<String, dynamic>> refs) async {
  // The sheet can open while the runtime is still booting — without this the
  // cold-boot case resolves every link against a null host. Idempotent, so
  // every call after the first costs nothing.
  await services.extensions.start();
  final keyed = <String, Map<String, dynamic>>{};
  for (final ref in refs) {
    final key = refLinkKey(ref);
    if (key != null) keyed.putIfAbsent(key, () => ref);
  }
  final List<RefLink?> links;
  try {
    links = await services.extensions.linkForRefs(keyed.values.toList());
  } catch (e, stack) {
    // An extension's own failure never reaches here — `linkForRefs` answers
    // null for each ref whose program failed — so what does is OUR bug, and
    // is reported the way the sheet's `_loadControls` reports its own:
    // uploaded, with no notice, because rows showing no button are all the
    // operator can act on.
    ErrorReportingService.report(e, stack, context: 'activities:linkForRef');
    return const {};
  }
  final keys = keyed.keys.toList();
  return {
    for (var i = 0; i < keys.length; i++)
      if (links[i] case final RefLink link) keys[i]: link,
  };
}

/// One per Activities sheet. Notifies when anything the sheet's results list
/// or results map reads changes.
class ActivitySearchState extends ChangeNotifier {
  ActivitySearchState({
    required this.services,
    required this.currentOperation,
    required this.scopes,
    required this.controlsLoaded,
    required this.onAnswered,
    this.debounce = const Duration(milliseconds: 400),
  });

  final HaLoServices services;

  /// The operation as the sheet holds it — read when a search runs, never
  /// captured earlier, so a search asks about the refs and location the
  /// operation has by then.
  final Operation Function() currentOperation;

  /// The scope words the loaded controls answer to, each mapped to the
  /// activity hook keys serving it — what a leading word in the box is
  /// checked against.
  final Map<String, List<String>> Function() scopes;

  /// Whether the activity controls have loaded, failed or not. Until they
  /// have, an absent POTA control means "not loaded yet" rather than "POTA is
  /// off" (see [_outlineParks]).
  final bool Function() controlsLoaded;

  /// Called with the box's text and its parse as a search's answer is
  /// applied, before the listeners hear of it, so what the sheet derives from
  /// the same text lands in the same rebuild.
  final void Function(String term, ActivitySearchQuery query) onAnswered;

  /// How long the box has to sit still before what was typed is searched.
  final Duration debounce;

  bool _disposed = false;
  Timer? _debounceTimer;

  /// What the last search found, nearby or typed.
  List<Map<String, dynamic>> get suggestions => _suggestions;
  List<Map<String, dynamic>> _suggestions = const [];

  /// Whether a search, or the outline parks that follow one, is still out.
  bool get loading => _loading;
  bool _loading = true;

  // Guards against a slower, earlier-fired search resolving after a faster,
  // more recent one and clobbering its results — only the response whose
  // id still matches the latest request gets applied.
  int _searchRequestId = 0;

  /// References the results map found as the operator panned it — map-only,
  /// and cleared by the next search, whose question they no longer answer.
  List<Map<String, dynamic>> get exploredSuggestions => _exploredSuggestions;
  List<Map<String, dynamic>> _exploredSuggestions = const [];

  /// The query [suggestions] answers, so panning asks the same scope.
  ActivitySearchQuery? _lastQuery;

  /// Counts the searches answered: the results map refits its camera when
  /// this changes and for nothing else (see ActivitiesResultsMap.fitKey).
  int get answeredSearches => _answeredSearches;
  int _answeredSearches = 0;

  /// Whether [suggestions] came from a typed search rather than the nearby
  /// list. Refs the operation already has are dropped from nearby suggestions
  /// (they're proposals — proposing what you already have is noise), but kept
  /// in search results: searching for something by name and getting nothing
  /// back reads as "not found", which is worse than a marked-up hit.
  bool get areSearchResults => _areSearchResults;
  bool _areSearchResults = false;

  /// Whether the last search came back with every source broken rather than
  /// merely empty-handed. The two are the same empty list, and only one of
  /// them is worth an apology.
  bool get failed => _failed;
  bool _failed = false;

  /// Where each of [suggestions] can be read about on the web, keyed by
  /// [refLinkKey]. Kept apart from the sheet's links for the operation's own
  /// refs because the two lists change on their own schedules and a shared
  /// map would have each clobber the other's answers.
  Map<String, RefLink> get links => _links;
  Map<String, RefLink> _links = const {};
  int _linksRequest = 0;

  /// Searches [term] once the box has sat still for [debounce] — typing,
  /// and the location and data-file ticks, which can fire every few seconds.
  void searchSoon(String term) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => search(term));
  }

  /// Drops the search [searchSoon] still has pending, for a caller about to
  /// wait on something that changes what a search would ask.
  void cancelPending() => _debounceTimer?.cancel();

  /// Searches [term] now, dropping any search [searchSoon] still had pending.
  Future<void> search(String term) async {
    cancelPending();
    final requestId = ++_searchRequestId;
    if (!_loading) {
      _loading = true;
      notifyListeners();
    }
    final query = ActivitySearchQuery.parse(term, scopes());
    final trimmed = query.term;
    final location = services.location;
    final fallbackPosition = location.position;
    final fallback = fallbackPosition == null ? null : GridLocation(fallbackPosition.latitude, fallbackPosition.longitude);
    final results = await services.extensions.suggestActivities(
      currentOperation().data,
      searchTerm: query.otherTerm.isEmpty ? null : query.otherTerm,
      activityKeys: query.activityKeys,
      preferredKeys: query.preferredKeys,
      preferredSearchTerm: trimmed.isEmpty ? null : trimmed,
      fallbackLocation: fallback,
    );
    // The nearby list only: a typed search is answered by what it names.
    final here = currentOperation().location ?? fallback;
    final outlineParksToCome = query.otherTerm.isEmpty && here != null;
    // A newer search may have fired (and even resolved) while this one was
    // in flight — only the still-current request gets to apply its results.
    if (_disposed || requestId != _searchRequestId) return;
    _suggestions = results.suggestions;
    _exploredSuggestions = const [];
    _lastQuery = query;
    _answeredSearches++;
    _failed = results.allSourcesFailed;
    _areSearchResults = trimmed.isNotEmpty;
    // Still looking while parks found by their outline are: otherwise one
    // whose point is far off is "not nearby" moments before it appears.
    _loading = outlineParksToCome;
    onAnswered(term, query);
    notifyListeners();
    // After the assignment, not before: it reads `_suggestions`.
    unawaited(_loadLinks());

    // Parks found by their outline join the nearby list as their bundle is
    // read — merged into the list as it is then, and re-ranked: the map
    // names a suggestion by what it is, so an open card stays on its park.
    if (outlineParksToCome) unawaited(_addOutlineParks(requestId, query.activityKeys, here));
  }

  /// The references in [bounds], the view the operator took the results
  /// map to. The same scope as the search in the box, but never its text: a
  /// typed search is answered by what it names, not by where the map is, so
  /// with text in the box panning finds nothing more.
  ///
  /// Answers whether the view came back whole — every program answered, for
  /// the search still in the box — so the map knows whether to ask again.
  Future<bool> explore(MapViewBounds bounds) async {
    final query = _lastQuery;
    // Nothing to find: a typed search has its answer. Whole, so the map
    // does not keep asking.
    if (query == null || query.term.isNotEmpty) return true;
    final requestId = _searchRequestId;
    final answered = _answeredSearches;
    final fallbackPosition = services.location.position;
    final fallback = fallbackPosition == null ? null : GridLocation(fallbackPosition.latitude, fallbackPosition.longitude);
    final keys = query.activityKeys ?? query.preferredKeys;
    final results = await services.extensions.suggestActivities(currentOperation().data, activityKeys: keys, fallbackLocation: fallback, searchWithin: bounds);
    // And the parks whose outline touches the view: an outline within the
    // half-diagonal of its centre, give or take the corners. Not across the
    // antimeridian, where no POTA park is.
    final center = GridLocation((bounds.south + bounds.north) / 2, (bounds.west + bounds.east) / 2);
    final outline = bounds.west > bounds.east
        ? null
        : await _outlineParks(
            keys,
            center,
            distanceOnEarthKm(center, GridLocation(bounds.north, bounds.east)),
            currentOperation().location ?? fallback,
            OutlineGridService.potaRefsIn([..._suggestions, ..._exploredSuggestions, ...results.suggestions]),
            const Duration(seconds: 3),
          );
    // A search that started or landed meanwhile has cleared the map's
    // extras, or is about to; these answer the question it replaced.
    if (_disposed || requestId != _searchRequestId || answered != _answeredSearches) return false;
    final known = {
      for (final suggestion in [..._suggestions, ..._exploredSuggestions]) '${suggestion['type']}/${suggestion['ref']}',
    };
    final fresh = [
      for (final suggestion in [...results.suggestions, ...?outline?.found])
        if (known.add('${suggestion['type']}/${suggestion['ref']}')) suggestion,
    ];
    if (fresh.isNotEmpty) {
      _exploredSuggestions = [..._exploredSuggestions, ...fresh];
      notifyListeners();
    }
    return !results.allSourcesFailed && (outline?.settled ?? true);
  }

  /// Puts [ref] back at the top of [suggestions] — for one the operator just
  /// removed, which is often a mistake to undo — until the next search
  /// answers. Nothing when the list already holds it.
  void reoffer(Map<String, dynamic> ref) {
    final alreadySuggested = _suggestions.any((s) => s['type'] == ref['type'] && s['ref'] == ref['ref']);
    if (alreadySuggested) return;
    _suggestions = [ref, ..._suggestions];
    notifyListeners();
    unawaited(_loadLinks());
  }

  /// The POTA parks whose outline comes within [km] of [center], measured
  /// [from] (see OutlineGridService), when POTA is in [keys], the search's
  /// scope — nothing, settled, otherwise.
  ///
  /// Given [within], waited on no longer, so a pan's answer is not held
  /// back: a first download that takes longer is left to finish and cache
  /// for the next. That, or a failure, comes back unsettled — a failure
  /// reported, since the fetch itself already answers offline with what the
  /// device holds.
  Future<OutlineParks> _outlineParks(List<String>? keys, GridLocation center, double km, GridLocation? from, Set<String> known, [Duration? within]) async {
    const none = (distances: <String, double?>{}, found: <Map<String, dynamic>>[], settled: true);
    // Asked before the controls have loaded too — the first nearby search
    // races them — since POTA's own labelling drops every park while POTA is
    // not running. Once they have, no POTA control means no POTA.
    final pota = scopes()[activityScopeWord(OutlineGridService.potaActivationType)];
    final skip = keys != null ? pota == null || !keys.any(pota.contains) : controlsLoaded() && pota == null;
    if (skip) return none;
    final unsettled = (distances: const <String, double?>{}, found: const <Map<String, dynamic>>[], settled: false);
    try {
      final parks = services.outlineGrid.parksNear(center, km, measureFrom: from, known: known);
      return await (within == null ? parks : parks.timeout(within));
    } on TimeoutException {
      return unsettled;
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'activities:outlineParks');
      return unsettled;
    }
  }

  /// The nearby list's parks found by their outline — see [search].
  Future<void> _addOutlineParks(int requestId, List<String>? keys, GridLocation here) async {
    final parks = await _outlineParks(keys, here, OutlineGridService.nearbyRadiusKm, here, OutlineGridService.potaRefsIn(_suggestions));
    if (_disposed || requestId != _searchRequestId) return;
    final merged = OutlineGridService.withParks(_suggestions, parks);
    final changed = !identical(merged, _suggestions);
    _loading = false;
    if (changed) {
      _suggestions = merged;
      // One a pan already put on the map moves to the list, now it is near.
      _exploredSuggestions = OutlineGridService.withoutParksIn(_exploredSuggestions, merged);
    }
    notifyListeners();
    if (changed) unawaited(_loadLinks());
  }

  /// The suggestions list is replaced wholesale by each search, so its links
  /// are too — and the request counter is what keeps a slow search from
  /// installing links for results the operator has already typed past.
  Future<void> _loadLinks() async {
    final request = ++_linksRequest;
    final links = await resolveRefLinks(services, _suggestions);
    if (_disposed || request != _linksRequest) return;
    _links = links;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}

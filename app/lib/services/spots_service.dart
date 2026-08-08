import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

/// One fan-out across every spot source: the spots that came back, the hook
/// keys of the sources nothing came back from, and the keys of those that
/// answered with an error. Three results rather than one because an empty
/// band, an unreachable feed and a feed that is up and broken look identical
/// from the spots alone.
typedef SpotsFetch = Future<({List<Map<String, dynamic>> items, List<String> unreachable, List<String> failed})>
    Function();

/// The one place fetched spots live, shared by the Spots Panel (which
/// displays them) and the `spot-history` lookup extension (which mines them
/// for activity references — see `spotsForCall`).
///
/// It exists because those two consumers cannot each own a copy: the panel's
/// spots used to be widget state, so they vanished with the panel and were
/// invisible to the extension runtime, while a second fetcher inside the
/// runtime would double the fan-out to every spot source's API.
///
/// Fetching is refcounted rather than unconditional: [subscribe] starts the
/// refresh timer and its returned callback stops it, so an app sitting on the
/// Home screen makes no spot requests at all. The Operation View subscribes
/// for as long as it is open — a call typed into the logging panel can be
/// looked up against spots whether or not the Spots Panel was ever opened,
/// which is the whole point of the lookup.
class SpotsService extends ChangeNotifier {
  SpotsService({
    required SpotsFetch fetchSpots,
    this.refreshInterval = const Duration(minutes: 2),
  }) : _fetchSpots = fetchSpots;

  final SpotsFetch _fetchSpots;

  /// Matches the cadence the Spots Panel polled at when it owned the fetch.
  final Duration refreshInterval;

  final Map<String, List<Map<String, dynamic>>> _bySource = {};

  /// Uppercased callsign -> that call's spots, rebuilt on every fetch. An
  /// index rather than a scan because the lookup path runs per keystroke
  /// (debounced) against a list that routinely holds a few thousand spots.
  final Map<String, List<Map<String, dynamic>>> _byCall = {};

  Timer? _timer;
  int _subscribers = 0;
  Future<void>? _inFlight;
  bool _loaded = false;
  Object? _error;

  /// A fetch outlives a dispose — it is a network round-trip already in
  /// flight, and nothing cancels it. Notifying listeners afterwards throws,
  /// so the flag is what makes disposing safe at any moment rather than only
  /// between fetches.
  bool _disposed = false;

  /// Spots grouped by the `hookKey` of the source that offered them — what
  /// the Spots Panel filters and groups on.
  Map<String, List<Map<String, dynamic>>> get spotsBySource => Map.unmodifiable(_bySource);

  /// False until the first fetch settles, so the panel can tell "no spots
  /// yet" from "no spots".
  bool get loaded => _loaded;

  /// The last fetch's failure, or null. Set only when a fetch throws; a
  /// successful fetch clears it.
  Object? get error => _error;

  /// Hook keys of sources nothing came back from — no reply inside the
  /// budget, or the request never reaching the network at all. Distinct from
  /// [error], which is the whole fetch failing: these sources are
  /// individually unreachable while the rest of the board is live, and
  /// without naming them the operator reads an empty band as "nobody out"
  /// rather than "we never heard back".
  List<String> get unavailableSources => List.unmodifiable(_unavailableSources);
  List<String> _unavailableSources = const [];

  /// Hook keys of sources that answered the last fetch with an error — a
  /// service that is up and unhappy, as against [unavailableSources]' one
  /// that never replied at all. Kept apart because the two ask different
  /// things of the operator: one is a network to wait out, the other is a
  /// feed to stop expecting spots from.
  List<String> get failedSources => List.unmodifiable(_failedSources);
  List<String> _failedSources = const [];

  /// Starts refreshing while at least one caller holds a subscription.
  /// Returns the unsubscribe callback — call it from `dispose`.
  VoidCallback subscribe() {
    if (_disposed) return () {};
    _subscribers++;
    if (_subscribers == 1) {
      _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
      unawaited(refresh());
    }
    var released = false;
    return () {
      // Guarded: a State that unsubscribes in dispose after a hot reload
      // recreated the closure would otherwise decrement twice and stop the
      // timer out from under the remaining subscribers.
      if (released) return;
      released = true;
      _subscribers--;
      if (_subscribers == 0) {
        _timer?.cancel();
        _timer = null;
        // Nothing will fetch again on its own, so nothing can clear an
        // outage from here. Left set, "SOTAWatch did not respond" follows the
        // operator back to the Home screen and stays for the session, long
        // after the feed recovers. [_doRefresh] covers the same hazard for a
        // fetch still in flight when this runs.
        if (_unavailableSources.isNotEmpty || _failedSources.isNotEmpty) {
          _unavailableSources = const [];
          _failedSources = const [];
          if (!_disposed) notifyListeners();
        }
      }
    };
  }

  /// Fetches from every spot source, coalescing overlapping calls (a timer
  /// tick landing on a manual pull-to-refresh) into the one in-flight
  /// request instead of doubling the fan-out.
  Future<void> refresh() => _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<void> _doRefresh() async {
    try {
      final fetched = await _fetchSpots();
      final spots = fetched.items;
      // Recorded only if somebody is still subscribed when this lands, which
      // is exactly the condition under which a later fetch can retract it. A
      // fetch outlives an unsubscribe — a stalled source is the case that
      // takes ten seconds to settle, ample time to close the operation — and
      // an outage recorded with the timer stopped is one nothing will ever
      // clear. Asked at completion, not captured at the start: an operator
      // who closes the operation and reopens it inside that window IS
      // watching, and coalescing (see [refresh]) hands them this same fetch.
      final watched = _subscribers > 0;
      _unavailableSources = watched ? fetched.unreachable : const [];
      _failedSources = watched ? fetched.failed : const [];
      _bySource.clear();
      _byCall.clear();
      for (final spot in spots) {
        final hookKey = spot['hookKey'] as String? ?? 'unknown';
        _bySource.putIfAbsent(hookKey, () => []).add(spot);
        final call = callOfSpot(spot);
        if (call != null) _byCall.putIfAbsent(call, () => []).add(spot);
      }
      _loaded = true;
      _error = null;
    } catch (e) {
      _error = e;
      _loaded = true;
      // The whole fetch failed, so last cycle's per-source lists describe
      // nothing current — keeping them would name one source while the
      // failure is global.
      _unavailableSources = const [];
      _failedSources = const [];
    }
    if (!_disposed) notifyListeners();
  }

  /// Every cached spot for [call] no older than [maxAge], newest first.
  ///
  /// Age is measured against the spot's own `spot.timeInMillis`, so a spot
  /// that was fetched moments ago but posted an hour ago is correctly stale
  /// — the cache's own freshness says nothing about the spot's.
  List<Map<String, dynamic>> spotsForCall(String call, {required Duration maxAge}) {
    final spots = _byCall[call.trim().toUpperCase()];
    if (spots == null) return const [];
    final cutoff = nowMillis() - maxAge.inMilliseconds;
    final fresh = [
      for (final spot in spots)
        if ((timeOfSpot(spot) ?? 0) >= cutoff) spot,
    ];
    fresh.sort((a, b) => (timeOfSpot(b) ?? 0).compareTo(timeOfSpot(a) ?? 0));
    return fresh;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// The spotted callsign, uppercased, or null when the spot has none — spots
/// arrive as raw JSON maps from the runtime, so every field access is a
/// probe rather than a typed read.
String? callOfSpot(Map<String, dynamic> spot) {
  final call = (spot['their'] as Map?)?['call'];
  if (call is! String) return null;
  final trimmed = call.trim().toUpperCase();
  return trimmed.isEmpty ? null : trimmed;
}

/// When the spot was posted, in epoch milliseconds, or null.
int? timeOfSpot(Map<String, dynamic> spot) {
  final time = (spot['spot'] as Map?)?['timeInMillis'];
  return time is num ? time.toInt() : null;
}

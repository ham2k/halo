import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

/// One fan-out across every spot source: the spots that came back, the hook
/// keys of the sources that answered at all, the keys of the sources nothing
/// came back from, and the keys of those that answered with an error. Four
/// results rather than one because an empty band, an unreachable feed and a
/// feed that is up and broken look identical from the spots alone — and
/// because a fan-out that never happened looks identical to all of them.
///
/// The three key lists together name every source that was actually asked.
/// All three empty is not "every band is quiet": it is the fan-out itself
/// not running, which says nothing about any source.
typedef SpotsFetch = Future<
    ({
      List<Map<String, dynamic>> items,
      List<String> succeeded,
      List<String> unreachable,
      List<String> failed
    })> Function();

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

  /// The oldest a spot may be and still be held, whether it arrived in this
  /// fetch or was retained from an earlier one. The board is never
  /// open-ended: the Spots Panel's age filter offers nothing wider, so a spot
  /// past this could not be displayed anyway, and holding it would only let a
  /// failing source keep furnishing a board nobody can see it on.
  static const maxSpotAge = Duration(minutes: 180);

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

      // Spots are replaced PER SOURCE, and only by a source that answered.
      // A source that never replied or answered with an error has said
      // nothing about its band, so its previous spots stand and go on aging
      // in the panel; without this, a thirty-second network drop empties the
      // whole board and refills it a minute later, and a hunter watching a
      // three-minute-old spot loses it for no reason. A source that answered
      // with no spots is a genuinely empty band and correctly clears.
      final answered = <String, List<Map<String, dynamic>>>{};
      for (final spot in spots) {
        answered.putIfAbsent(spot['hookKey'] as String? ?? 'unknown', () => []).add(spot);
      }
      // A source in none of the three lists was not consulted this cycle —
      // one the operator has just switched off — and its spots go, or they
      // would sit on the board for the rest of the session.
      final askedNothing = fetched.succeeded.isEmpty && fetched.unreachable.isEmpty && fetched.failed.isEmpty;
      final outOfTouch = <String>{...fetched.unreachable, ...fetched.failed};
      // Keyed off what ANSWERED rather than off the outage lists alone: a
      // source reported unreachable that somehow also returned spots is
      // described by the spots, and appending to its retained list would
      // double them.
      //
      // [askedNothing] is the answer that reads as "every band is quiet" and
      // is nothing of the sort — the fan-out never ran, so the whole board
      // stands. Not a corner: the extension host is null for as long as it
      // takes to replace the runtime, which happens on every extension
      // enable/disable and on every dead-host recovery, and a fan-out that
      // throws degrades to the same empty answer.
      final retained = {
        for (final entry in _bySource.entries)
          if (!answered.containsKey(entry.key) && (askedNothing || outOfTouch.contains(entry.key)))
            entry.key: entry.value,
      };
      // Nothing older than [maxSpotAge] is kept, whoever offered it. Spots
      // have no open-ended life here: a source that goes on failing empties
      // itself instead of furnishing the board out of a morning that is over,
      // and a live source cannot pin an ancient spot either. A source left
      // with nothing drops out entirely, exactly as one that answered empty
      // does.
      final cutoff = nowMillis() - maxSpotAge.inMilliseconds;
      _bySource
        ..clear()
        ..addAll(answered)
        ..addAll(retained);
      _bySource.removeWhere((_, list) {
        // A spot whose time cannot be read is not judged old — the age is
        // unknown, not zero, and dropping it would quietly discard a source's
        // whole board on a wire format we failed to parse.
        list.removeWhere((spot) {
          final postedAt = timeOfSpot(spot);
          return postedAt != null && postedAt < cutoff;
        });
        return list.isEmpty;
      });

      // Rebuilt from the merged map, not from the fetch: retained spots have
      // to stay findable by [spotsForCall], which is the whole point of
      // keeping them.
      _byCall.clear();
      for (final list in _bySource.values) {
        for (final spot in list) {
          final call = callOfSpot(spot);
          if (call != null) _byCall.putIfAbsent(call, () => []).add(spot);
        }
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

/// A value only if it is already the target type, or null — spot maps arrive
/// as raw JSON from the extension runtime, which enforces nothing about a JS
/// hook's declared TypeScript types at runtime, so every field read is a
/// probe rather than a cast. Shared by [callOfSpot]/[timeOfSpot] here and by
/// spots_panel.dart's own field readers, which describe this same wire shape.
Map<String, dynamic>? asSpotMap(dynamic value) => value is Map ? value.cast<String, dynamic>() : null;
String? asSpotString(dynamic value) => value is String ? value : null;
num? asSpotNum(dynamic value) => value is num ? value : null;

/// The spotted callsign, uppercased, or null when the spot has none.
String? callOfSpot(Map<String, dynamic> spot) {
  final call = asSpotString(asSpotMap(spot['their'])?['call']);
  if (call == null) return null;
  final trimmed = call.trim().toUpperCase();
  return trimmed.isEmpty ? null : trimmed;
}

/// When the spot was posted, in epoch milliseconds, or null.
int? timeOfSpot(Map<String, dynamic> spot) => asSpotNum(asSpotMap(spot['spot'])?['timeInMillis'])?.toInt();

import 'dart:async';

import 'package:flutter/foundation.dart';

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
    required Future<List<Map<String, dynamic>>> Function() fetchSpots,
    this.refreshInterval = const Duration(minutes: 2),
  }) : _fetchSpots = fetchSpots;

  final Future<List<Map<String, dynamic>>> Function() _fetchSpots;

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
      }
    };
  }

  /// Fetches from every spot source, coalescing overlapping calls (a timer
  /// tick landing on a manual pull-to-refresh) into the one in-flight
  /// request instead of doubling the fan-out.
  Future<void> refresh() => _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<void> _doRefresh() async {
    try {
      final spots = await _fetchSpots();
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
    final cutoff = DateTime.now().millisecondsSinceEpoch - maxAge.inMilliseconds;
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

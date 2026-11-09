import 'dart:async';

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import 'band_annotations_service.dart';
import 'local_spots.dart';

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
typedef SpotsFetch = Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})> Function();

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
    required this._fetchSpots,
    BandAnnotationsService? bandAnnotations,
    this.refreshInterval = const Duration(minutes: 2),
    this.isOffline,
    Stream<bool>? offlineChanges,
    this.pushNoticeDelay = const Duration(milliseconds: 250),
  }) : bandAnnotations = bandAnnotations ?? BandAnnotationsService(),
       _ownsBandAnnotations = bandAnnotations == null {
    // Straight away on recovery rather than up to a whole refreshInterval
    // later: the board an operator comes back to is stale by exactly the
    // length of the outage, and that is the moment they look at it.
    _offlineSubscription = offlineChanges?.listen((offline) {
      if (!offline && _subscribers > 0) unawaited(refresh());
    });
  }

  StreamSubscription<bool>? _offlineSubscription;

  /// How long the listeners wait after a push, so a burst of them — a source
  /// putting its spots a few at a time — repaints the board once.
  final Duration pushNoticeDelay;

  /// What is said about the bands beside the spots on them: their plans,
  /// the operator's band tags, and whatever extensions mark. Its own
  /// listeners: an annotation changing judges no spot again. The app's is
  /// ExtensionService's, there from boot: the runtime starts before the
  /// services do, and what an extension puts as it activates would
  /// otherwise have nowhere to go.
  final BandAnnotationsService bandAnnotations;
  final bool _ownsBandAnnotations;

  final SpotsFetch _fetchSpots;

  /// Whether the app believes it has no internet. While it does, a refresh
  /// is skipped rather than attempted: every source would time out, and the
  /// board is better served by the spots already on it aging visibly than by
  /// a fan-out that can only report outages. Null skips the gate (tests).
  ///
  /// Skipped, not queued. The timer keeps ticking, so the first tick after
  /// coverage returns fetches — and a spot that was worth fetching two
  /// minutes ago is worth fetching now, not replaying.
  final bool Function()? isOffline;

  /// Matches the cadence the Spots Panel polled at when it owned the fetch.
  final Duration refreshInterval;

  /// The oldest a spot may be and still be held, whether it arrived in this
  /// fetch or was retained from an earlier one. The board is never
  /// open-ended: the Spots Panel's age filter offers nothing wider, so a spot
  /// past this could not be displayed anyway, and holding it would only let a
  /// failing source keep furnishing a board nobody can see it on.
  static const maxSpotAge = Duration(minutes: 180);

  /// The most spots one source may hold through pushes. A cluster on a
  /// contest weekend announces thousands an hour; past this, a source is
  /// expected to keep its own newest.
  static const maxPushedSpots = 5000;

  final Map<String, List<Map<String, dynamic>>> _bySource = {};

  /// The sources that pushed spots, until their extension is unloaded
  /// ([forgetPushers]). Their spots stand through a fetch that did not ask
  /// them — a source that only pushes has no `fetchSpots` to ask — where any
  /// other source's go.
  final Set<String> _pushers = {};
  Timer? _pushNotice;

  /// The pushes made while a fetch is out, in order. That fetch answers with
  /// what each source held when it was asked, so these are made again on its
  /// answer: dropped, they would be lost until the next fetch; standing in
  /// for the answer, the answer's pruning would be lost instead.
  List<(String, _SpotsChange)>? _pushedDuringFetch;

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

  /// The spots this device made itself ([putLocalSpot]), by their key.
  /// Apart from [_bySource]: no fetch answers for them, so none may replace
  /// or retain them.
  final Map<String, Map<String, dynamic>> _local = {};

  /// [_bySource] with the local spots under [localSpotSource]. Rebuilt on
  /// every change.
  Map<String, List<Map<String, dynamic>>> _board = const {};

  /// Spots grouped by the `hookKey` of the source that offered them — what
  /// the Spots Panel filters and groups on. Every spot held, those a local
  /// spot hides or takes in too: that is decided on the board, after the
  /// operator's source filter ([withLocalSpots]).
  Map<String, List<Map<String, dynamic>>> get spotsBySource => _board;

  /// Puts the local spot under [key] on the board, or moves it there.
  ///
  /// One that differs only in when it was posted is taken without a word to
  /// the listeners: a draft changes at every keystroke in its other fields,
  /// and each notice repaints the board and judges it again for a spot that
  /// says what it said.
  void putLocalSpot(String key, Map<String, dynamic> spot) {
    if (_disposed) return;
    spot = withSpotId(localSpotSource, spot);
    final unchanged = _sameButPosted(_local[key], spot);
    _local[key] = spot;
    _rebuildBoard();
    if (!unchanged) notifyListeners();
  }

  static bool _sameButPosted(Map<String, dynamic>? held, Map<String, dynamic> spot) {
    if (held == null) return false;
    Map<String, dynamic> unposted(Map<String, dynamic> s) => {
      ...s,
      'spot': {...(s['spot'] as Map), 'timeInMillis': null},
    };
    return const DeepCollectionEquality().equals(unposted(held), unposted(spot));
  }

  /// Whether a local spot stands under [key].
  bool hasLocalSpot(String key) => _local.containsKey(key);

  /// Takes the local spot under [key] off the board, if it is there.
  void removeLocalSpot(String key) {
    if (_disposed || _local.remove(key) == null) return;
    _rebuildBoard();
    notifyListeners();
  }

  /// Takes the local spots [test] picks off the board.
  void removeLocalSpotsWhere(bool Function(Map<String, dynamic> spot) test) {
    if (_disposed) return;
    final before = _local.length;
    _local.removeWhere((_, spot) => test(spot));
    if (_local.length == before) return;
    _rebuildBoard();
    notifyListeners();
  }

  /// Takes every local spot off the board — the operator turned them off.
  void clearLocalSpots() {
    if (_disposed || _local.isEmpty) return;
    _local.clear();
    _rebuildBoard();
    notifyListeners();
  }

  void _rebuildBoard() {
    _board = Map.unmodifiable({..._bySource, if (_local.isNotEmpty) localSpotSource: List<Map<String, dynamic>>.unmodifiable(_local.values)});
  }

  /// [source]'s spots, all of them: what it pushes replaces what it held, as
  /// an answer to a fetch does. Each spot is tagged with [source] as its
  /// `hookKey`.
  void replaceSpots(String source, List<Map<String, dynamic>> spots) {
    final tagged = [for (final spot in spots) _fromSource(source, spot)];
    _push(source, (_) => tagged);
  }

  /// Adds [spots] to [source]'s, each replacing the one it holds under the
  /// same `key`; one without a `key` is only ever added.
  void putSpots(String source, List<Map<String, dynamic>> spots) {
    final tagged = [for (final spot in spots) _fromSource(source, spot)];
    _push(source, (held) => _withPut(held, tagged));
  }

  /// Takes [source]'s spots under [keys] off the board, or every one of its
  /// spots without [keys].
  void removeSpots(String source, {List<String>? keys}) {
    final taken = keys?.toSet();
    _push(
      source,
      (held) => taken == null
          ? const []
          : [
              for (final spot in held)
                if (!taken.contains(spot['key'])) spot,
            ],
    );
  }

  /// Forgets that the sources of the extensions under [extensionKeys] — every
  /// extension's, without them — pushed: their extensions are being unloaded,
  /// and one that does not come back never pushes again, so the next fetch
  /// takes its spots away. One that does pushes again.
  void forgetPushers([Iterable<String>? extensionKeys]) {
    if (extensionKeys == null) {
      _pushers.clear();
      return;
    }
    final keys = extensionKeys.toSet();
    _pushers.removeWhere((source) => keys.contains(source) || keys.any((key) => source.startsWith('${key}_')));
  }

  /// [spot] as [source]'s, with a mode and an id as a fetched one has
  /// ([withBandPlanMode], [withSpotId]).
  static Map<String, dynamic> _fromSource(String source, Map<String, dynamic> spot) => withSpotId(source, withBandPlanMode({...spot, 'hookKey': source}));

  static List<Map<String, dynamic>> _withPut(List<Map<String, dynamic>> held, List<Map<String, dynamic>> spots) {
    final result = [...held];
    final at = <String, int>{
      for (var i = 0; i < result.length; i++)
        if (result[i]['key'] case final String key) key: i,
    };
    for (final spot in spots) {
      final index = spot['key'] is String ? at[spot['key']] : null;
      if (index != null) {
        result[index] = spot;
      } else {
        if (spot['key'] case final String key) at[key] = result.length;
        result.add(spot);
      }
    }
    return result;
  }

  /// [spots] without those past [maxSpotAge]; one whose time cannot be read
  /// stays, as a fetched one does.
  static List<Map<String, dynamic>> _fresh(List<Map<String, dynamic>> spots) {
    final cutoff = nowMillis() - maxSpotAge.inMilliseconds;
    return [
      for (final spot in spots)
        if ((timeOfSpot(spot) ?? cutoff) >= cutoff) spot,
    ];
  }

  /// Applies [change] to [source]'s spots. One that would leave the source
  /// more than [maxPushedSpots], and more than it held, throws
  /// [SpotsPushRefused] and changes nothing: a removal is never refused.
  void _push(String source, _SpotsChange change) {
    if (_disposed) return;
    final held = _bySource[source] ?? const <Map<String, dynamic>>[];
    final after = _fresh(change(held));
    if (after.length > maxPushedSpots && after.length > held.length) {
      throw SpotsPushRefused("'$source' would hold ${after.length} spots, and a source holds at most $maxPushedSpots");
    }
    _pushers.add(source);
    _pushedDuringFetch?.add((source, change));
    if (after.isEmpty) {
      _bySource.remove(source);
    } else {
      _bySource[source] = after;
    }
    _rebuildBoard();
    _reindex();
    _pushNotice ??= Timer(pushNoticeDelay, () {
      _pushNotice = null;
      if (!_disposed) notifyListeners();
    });
  }

  /// [_byCall], from what [_bySource] holds now.
  void _reindex() {
    _byCall.clear();
    for (final list in _bySource.values) {
      for (final spot in list) {
        final call = callOfSpot(spot);
        if (call != null) _byCall.putIfAbsent(call, () => []).add(spot);
      }
    }
  }

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
        //
        // The notice waits a microtask: the usual caller is a State's
        // dispose, which runs while the widget tree is locked, and a listener
        // there that reaches a ListenableBuilder (the status bar clearing its
        // outage line) throws "setState() called when widget tree was locked".
        if (_unavailableSources.isNotEmpty || _failedSources.isNotEmpty) {
          _unavailableSources = const [];
          _failedSources = const [];
          scheduleMicrotask(() {
            if (!_disposed) notifyListeners();
          });
        }
      }
    };
  }

  /// Fetches from every spot source, coalescing overlapping calls (a timer
  /// tick landing on a manual pull-to-refresh) into the one in-flight
  /// request instead of doubling the fan-out.
  Future<void> refresh() => _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  /// Whether the most recent [refresh] actually went to the network. False
  /// when it was skipped for being offline — which the automatic timer can
  /// ignore, but an operator who pressed the refresh button cannot: a
  /// spinner that comes and goes over an unchanged board otherwise reports
  /// success for something that never happened.
  bool get lastRefreshWasSkipped => _lastRefreshWasSkipped;
  bool _lastRefreshWasSkipped = false;

  Future<void> _doRefresh() async {
    if (isOffline?.call() ?? false) {
      _lastRefreshWasSkipped = true;
      // Deliberately touches nothing — not _bySource, not the outage lists,
      // not _error. A skipped fetch has learned nothing about any source, and
      // the retention rule below turns exactly that into "the previous spots
      // stand". Reporting every source as unreachable here would badge the
      // whole panel for a condition the status bar's offline icon already
      // states once.
      return;
    }
    _lastRefreshWasSkipped = false;
    final pushedDuringFetch = _pushedDuringFetch = [];
    try {
      final fetched = await _fetchSpots();
      _pushedDuringFetch = null;
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
      final guesses = <double, String?>{};
      for (final spot in spots) {
        final source = spot['hookKey'] as String? ?? 'unknown';
        answered.putIfAbsent(source, () => []).add(withSpotId(source, withBandPlanMode(spot, guesses)));
      }
      // A source that pushed while the fan-out waited on the others (a slow
      // feed holds it for seconds) answered with what it held before those
      // pushes, so they are made again on its answer. One that answered with
      // nothing starts from nothing.
      final answeredOk = fetched.succeeded.toSet();
      for (final (source, change) in pushedDuringFetch) {
        if (!answered.containsKey(source) && !answeredOk.contains(source)) continue;
        final after = change(answered[source] ?? const []);
        if (after.isEmpty) {
          answered.remove(source);
        } else {
          answered[source] = [...after];
        }
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
      //
      // A source that pushes its spots ([_pushers]) and was not asked keeps
      // them: it has no `fetchSpots`, or one the fan-out skipped, and what it
      // pushed is its word on its band. One that was asked is replaced by its
      // answer like any other — that answer is its whole list.
      final consulted = <String>{...fetched.succeeded, ...outOfTouch};
      final retained = {
        for (final entry in _bySource.entries)
          if (!answered.containsKey(entry.key) &&
              (askedNothing || outOfTouch.contains(entry.key) || (_pushers.contains(entry.key) && !consulted.contains(entry.key))))
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
      _local.removeWhere((_, spot) => (timeOfSpot(spot) ?? 0) < cutoff);
      _rebuildBoard();

      // Rebuilt from the merged map, not from the fetch: retained spots have
      // to stay findable by [spotsForCall], which is the whole point of
      // keeping them.
      _reindex();
      _loaded = true;
      _error = null;
    } catch (e) {
      _pushedDuringFetch = null;
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
    if (_ownsBandAnnotations) bandAnnotations.dispose();
    _timer?.cancel();
    _timer = null;
    _offlineSubscription?.cancel();
    _offlineSubscription = null;
    _pushNotice?.cancel();
    _pushNotice = null;
    super.dispose();
  }
}

/// A change a push makes to one source's spots: from what it holds, what it
/// holds after.
typedef _SpotsChange = List<Map<String, dynamic>> Function(List<Map<String, dynamic>> held);

/// A push the board refused, with why, for the extension that pushed it.
class SpotsPushRefused implements Exception {
  const SpotsPushRefused(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A value only if it is already the target type, or null — spot maps arrive
/// as raw JSON from the extension runtime, which enforces nothing about a JS
/// hook's declared TypeScript types at runtime, so every field read is a
/// probe rather than a cast. Shared by [callOfSpot]/[timeOfSpot] here and by
/// spots_panel.dart's own field readers, which describe this same wire shape.
Map<String, dynamic>? asSpotMap(dynamic value) => value is Map ? value.cast<String, dynamic>() : null;
String? asSpotString(dynamic value) => value is String ? value : null;
num? asSpotNum(dynamic value) => value is num ? value : null;

/// [spot], or a copy with the band plan's mode for its frequency when its
/// source names none. Without a mode a spot is in no family of modes: the
/// mode filter cannot place it, and a local spot of the same station cannot
/// take it in. Read from the worldwide band plan, not the operator's own
/// region: the spotted station may be anywhere. Where the plan settles on
/// no mode, the spot stays without one.
///
/// [guesses] holds the plan's answers across one fetch: a busy band has many
/// spots on one frequency, and each lookup walks the whole plan.
Map<String, dynamic> withBandPlanMode(Map<String, dynamic> spot, [Map<double, String?>? guesses]) {
  final mode = asSpotString(spot['mode']);
  if (mode != null && mode.trim().isNotEmpty) return spot;
  final freq = asSpotNum(spot['freq'])?.toDouble();
  final guess = freq == null ? null : (guesses ?? {}).putIfAbsent(freq, () => modeForFrequency(freq));
  return guess == null ? spot : {...spot, 'mode': guess};
}

/// The id a spot keeps from one refresh to the next, as `host.spots.mark`
/// names it: its source, call, band and mode, so the same station reported
/// again by the same source is the same spot, whatever its frequency or time.
/// A part the spot does not carry is left empty; the band is read off the
/// frequency where the spot names none.
String spotIdFor(String source, Map<String, dynamic> spot) {
  final freq = asSpotNum(spot['freq'])?.toDouble();
  final band = asSpotString(spot['band'])?.trim().toLowerCase() ?? (freq == null ? null : bandForFrequency(freq));
  final mode = asSpotString(spot['mode'])?.trim().toUpperCase();
  return '$source|${callOfSpot(spot) ?? ''}|${band ?? ''}|${mode ?? ''}';
}

/// [spot] with its [spotIdFor] under `id`. Whatever id a source sent is
/// replaced: the id is the board's, and one a source chose could name
/// another source's spot.
Map<String, dynamic> withSpotId(String source, Map<String, dynamic> spot) {
  final id = spotIdFor(source, spot);
  return spot['id'] == id ? spot : {...spot, 'id': id};
}

/// Every id a board row stands for: the several a merged row took in
/// (`ids`), else the spot's own.
List<String> spotIdsOf(Map<String, dynamic> spot) => switch (spot['ids']) {
  final List<dynamic> ids => ids.whereType<String>().toList(),
  _ => [?asSpotString(spot['id'])],
};

/// The spotted callsign, uppercased, or null when the spot has none.
String? callOfSpot(Map<String, dynamic> spot) {
  final call = asSpotString(asSpotMap(spot['their'])?['call']);
  if (call == null) return null;
  final trimmed = call.trim().toUpperCase();
  return trimmed.isEmpty ? null : trimmed;
}

/// When the spot was posted, in epoch milliseconds, or null.
int? timeOfSpot(Map<String, dynamic> spot) => asSpotNum(asSpotMap(spot['spot'])?['timeInMillis'])?.toInt();

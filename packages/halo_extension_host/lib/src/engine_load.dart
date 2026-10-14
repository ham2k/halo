// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How much of the time the single extension engine is busy — the headroom a
// keystroke's hook call has before it queues behind other work.

import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart' show visibleForTesting;

import 'hook_call_stats.dart' show batchLabel;

/// The width of one [EngineLoadBucket]: about six frames, so a bucket can
/// tell a block an operator would feel from a run of harmless slivers.
const engineLoadBucketMicros = 100 * 1000;

/// What a core message's busy time is charged to: the hook, with the
/// extension when the call names one, so the time can be pinned on someone.
String engineLoadLabel(Map<String, dynamic> msg) {
  final calls = msg['calls'];
  return switch (msg['type']) {
    'invoke' => '${msg['category']}.${msg['method']}${msg['key'] is String ? '@${msg['key']}' : ''}',
    'invokeAll' => '${msg['category']}.${msg['method']}',
    'invokeBatch' => calls is List ? batchLabel([for (final call in calls) call is Map ? call['method'] : null]) : 'batch',
    final type => '$type',
  };
}

/// What the engine did during one [engineLoadBucketMicros] slice of real time.
///
/// [index] is the slice's start in microseconds since the epoch divided by the
/// bucket width, so buckets from the core and readings on the main isolate
/// line up without either side sharing anything but the real clock.
class EngineLoadBucket {
  final int index;

  /// Never more than [engineLoadBucketMicros]: a span crossing a boundary is
  /// split between the buckets it covers.
  int busyMicros;

  /// The longest single busy span that ENDED in this bucket, at its full
  /// length — a 2s eval reports 2s here, not the 100ms of it this bucket holds.
  /// That length is the worst wait any call arriving during it could have had.
  int longestMicros;
  String? longestLabel;

  /// Busy time by what the engine was doing. Sums to [busyMicros], give or
  /// take the clock jitter between halves of a slice reported twice.
  final Map<String, int> busyByLabel;

  EngineLoadBucket(this.index, {this.busyMicros = 0, this.longestMicros = 0, this.longestLabel, Map<String, int>? busyByLabel})
    : busyByLabel = busyByLabel ?? {};

  Map<String, Object?> toMessage() => {
    'index': index,
    'busyMicros': busyMicros,
    'longestMicros': longestMicros,
    'longestLabel': longestLabel,
    'busyByLabel': busyByLabel,
  };

  /// Null for a message that is not a bucket, so a malformed one is dropped at
  /// the bridge rather than thrown inside its listener.
  static EngineLoadBucket? fromMessage(Map<String, dynamic> msg) {
    final index = msg['index'];
    final busy = msg['busyMicros'];
    if (index is! int || busy is! int) return null;
    final longest = msg['longestMicros'];
    final byLabel = msg['busyByLabel'];
    return EngineLoadBucket(
      index,
      busyMicros: busy,
      longestMicros: longest is int ? longest : 0,
      longestLabel: msg['longestLabel'] is String ? msg['longestLabel'] as String : null,
      busyByLabel: byLabel is Map
          ? {
              for (final e in byLabel.entries)
                if (e.key is String && e.value is int) e.key as String: e.value as int,
            }
          : null,
    );
  }
}

/// Accumulates busy spans into [EngineLoadBucket]s on the side that runs the
/// engine, and hands each one to [onBucket] once its slice of time is over.
///
/// Sends nothing while the engine is idle: a bucket with no busy time is never
/// created, and the flush timer is armed only while one is open — an all-day
/// field session must not pay a wake-up every 100ms to report silence.
class EngineLoadMeter {
  final void Function(EngineLoadBucket bucket) onBucket;

  /// Real time, which places a span among the slices.
  final int Function() nowMicros;

  /// A monotonic clock, which measures a span's length. The wall clock
  /// cannot: a laptop asleep mid-call would come back to a span hours long —
  /// a false report, and a slice message for every 100ms of the sleep.
  final int Function() monotonicMicros;

  EngineLoadMeter({required this.onBucket, required this.nowMicros, int Function()? monotonicMicros})
    : monotonicMicros = monotonicMicros ?? (() => _monotonic.elapsedMicroseconds);

  static final _monotonic = Stopwatch()..start();

  /// No span longer than the longest window anything reads
  /// ([EngineLoadWindow.span]'s default) can be shown, so none is recorded:
  /// it bounds a span from a clock that ran on through a sleep, which the
  /// web worker's can.
  static const maxSpanMicros = 60 * 1000 * 1000;

  final Map<int, EngineLoadBucket> _open = {};
  Timer? _flushTimer;
  int _depth = 0;

  /// Runs [body] and records its wall time as busy under [label].
  ///
  /// Only the OUTERMOST call records. The engine re-enters itself — a hook's
  /// host call is answered from inside the eval that made it — and counting
  /// the nested entry too would charge the same time twice and read as over
  /// 100% busy.
  T run<T>(String label, T Function() body) => _run(label, body, (_) => true);

  /// As [run], for a [body] that may find nothing to do, which it says by
  /// returning false: that time is not recorded. The job pump ticks every 5ms
  /// while a hook awaits, mostly to find the queue empty, and timed every
  /// time it would report an engine idle on a network wait as working — and
  /// send a slice every 100ms to say so.
  bool runIfWorked(String label, bool Function() body) => _run(label, body, (worked) => worked);

  T _run<T>(String label, T Function() body, bool Function(T result) worked) {
    if (_depth > 0) return body();
    _depth++;
    _currentLabel = label;
    final started = monotonicMicros();
    var recorded = true;
    try {
      final result = body();
      recorded = worked(result);
      return result;
    } finally {
      _depth--;
      _currentLabel = null;
      if (recorded) {
        final end = nowMicros();
        record(end - (monotonicMicros() - started), end, label);
      }
    }
  }

  /// The label the engine is being charged to right now, or null between
  /// entries.
  String? get currentLabel => _currentLabel;
  String? _currentLabel;

  /// Records a busy span measured elsewhere — the web worker's, which Dart
  /// cannot time from the outside.
  void record(int startMicros, int endMicros, String label) {
    if (_disposed || endMicros <= startMicros) return;
    startMicros = max(startMicros, endMicros - maxSpanMicros);
    final first = startMicros ~/ engineLoadBucketMicros;
    final last = (endMicros - 1) ~/ engineLoadBucketMicros;
    for (var index = first; index <= last; index++) {
      final sliceStart = max(startMicros, index * engineLoadBucketMicros);
      final sliceEnd = min(endMicros, (index + 1) * engineLoadBucketMicros);
      final bucket = _open.putIfAbsent(index, () => EngineLoadBucket(index));
      final slice = sliceEnd - sliceStart;
      bucket.busyMicros = min(engineLoadBucketMicros, bucket.busyMicros + slice);
      bucket.busyByLabel[label] = (bucket.busyByLabel[label] ?? 0) + slice;
    }
    final span = endMicros - startMicros;
    final ending = _open[last]!;
    if (span > ending.longestMicros) {
      ending.longestMicros = span;
      ending.longestLabel = label;
    }
    _flush();
  }

  /// Hands over every bucket whose slice has ended, and arms a timer for the
  /// rest — without it, the last busy bucket before a quiet spell would wait
  /// for the next busy span to be reported, which could be minutes.
  ///
  /// Runs on every span, which is every 5ms pump tick while a hook awaits,
  /// so the timer is re-armed only when a newer slice opens: one timer per
  /// busy slice, not one per span.
  void _flush() {
    final current = nowMicros() ~/ engineLoadBucketMicros;
    if (_open.keys.any((index) => index < current)) {
      final done = _open.keys.where((index) => index < current).toList()..sort();
      for (final index in done) {
        onBucket(_open.remove(index)!);
      }
    }
    if (_open.isEmpty) {
      _flushTimer?.cancel();
      _flushTimer = null;
      return;
    }
    final latest = _open.keys.reduce(max);
    if (_flushTimer != null && _flushArmedFor == latest) return;
    _flushTimer?.cancel();
    _flushArmedFor = latest;
    final wait = (latest + 1) * engineLoadBucketMicros - nowMicros();
    _flushTimer = Timer(Duration(microseconds: max(0, wait) + 1000), () {
      _flushTimer = null;
      _flush();
    });
  }

  int? _flushArmedFor;

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    _open.clear();
  }
}

/// The recent [EngineLoadBucket]s, read back as idle fractions over sliding
/// windows.
///
/// Every window ends at the start of the CURRENT slice: the slice still
/// running has not been reported yet, and reading it as idle would flatter
/// the number at exactly the moment the engine is busiest.
class EngineLoadWindow {
  /// How far back the window keeps buckets; the longest window it can answer.
  final Duration span;

  EngineLoadWindow({this.span = const Duration(seconds: 60)});

  final Map<int, EngineLoadBucket> _buckets = {};

  void add(EngineLoadBucket bucket, {required int nowMicros}) {
    final existing = _buckets[bucket.index];
    if (existing == null) {
      // A copy, since a later duplicate is merged into it: the original is
      // also the host's (ExtensionHost.engineLoad's `recent`), and a merge
      // into that would count the duplicate twice for the next reader.
      _buckets[bucket.index] = EngineLoadBucket(
        bucket.index,
        busyMicros: bucket.busyMicros,
        longestMicros: bucket.longestMicros,
        longestLabel: bucket.longestLabel,
        busyByLabel: {...bucket.busyByLabel},
      );
    } else {
      // A slice reported twice — a meter flushed early by its timer and then
      // given a late span for the same slice. Merged, so neither half is lost.
      existing.busyMicros = min(engineLoadBucketMicros, existing.busyMicros + bucket.busyMicros);
      bucket.busyByLabel.forEach((label, micros) => existing.busyByLabel[label] = (existing.busyByLabel[label] ?? 0) + micros);
      if (bucket.longestMicros > existing.longestMicros) {
        existing.longestMicros = bucket.longestMicros;
        existing.longestLabel = bucket.longestLabel;
      }
    }
    final oldest = _currentIndex(nowMicros) - _bucketsIn(span);
    _buckets.removeWhere((index, _) => index < oldest);
  }

  /// The share of [window] the engine spent idle, from 0 to 1.
  ///
  /// Every slice from [stalledSinceMicros] on counts as wholly busy
  /// ([EngineLoadFeed.stalledSinceMicros]): a call still running has
  /// reported none of its time yet.
  double idleFraction(Duration window, {required int nowMicros, int? stalledSinceMicros}) {
    final count = _bucketsIn(window);
    if (count == 0) return 1;
    final current = _currentIndex(nowMicros);
    final stalledFrom = stalledSinceMicros == null ? current : max(current - count, _currentIndex(stalledSinceMicros));
    final reported = _within(window, nowMicros).where((b) => b.index < stalledFrom).fold<int>(0, (sum, b) => sum + b.busyMicros);
    final busy = reported + max(0, current - stalledFrom) * engineLoadBucketMicros;
    return (1 - busy / (count * engineLoadBucketMicros)).clamp(0.0, 1.0);
  }

  /// The longest single busy span that ended within [window], or null when
  /// the engine was idle throughout.
  ({int micros, String? label})? longest(Duration window, {required int nowMicros}) {
    EngineLoadBucket? worst;
    for (final bucket in _within(window, nowMicros)) {
      if (bucket.longestMicros > (worst?.longestMicros ?? 0)) worst = bucket;
    }
    return worst == null ? null : (micros: worst.longestMicros, label: worst.longestLabel);
  }

  /// Busy time within [window] by label, most first.
  List<MapEntry<String, int>> busyByLabel(Duration window, {required int nowMicros}) {
    final totals = <String, int>{};
    for (final bucket in _within(window, nowMicros)) {
      bucket.busyByLabel.forEach((label, micros) => totals[label] = (totals[label] ?? 0) + micros);
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Iterable<EngineLoadBucket> _within(Duration window, int nowMicros) {
    final current = _currentIndex(nowMicros);
    final first = current - _bucketsIn(window);
    return _buckets.values.where((b) => b.index >= first && b.index < current);
  }

  static int _currentIndex(int nowMicros) => nowMicros ~/ engineLoadBucketMicros;
  static int _bucketsIn(Duration window) => window.inMicroseconds ~/ engineLoadBucketMicros;
}

/// The engine's busy time as the side that sends it work sees it: the
/// [buckets] the core reports, and a heartbeat that notices when it has
/// stopped answering.
///
/// A bucket is reported only once its span ends, so a call that runs for
/// seconds would read as idle until it returns, and a call that never
/// returns — a wedged web worker — would read as idle for good. The
/// heartbeat closes that gap: a ping the engine has not answered within one
/// [engineHeartbeat] means it is busy, since the ping was sent.
///
/// It beats only while the engine has been active in the last [quietAfter]
/// or a call is being sent, so an idle field session pays no wake-ups for it.
/// A hang that starts from quiet (a timer that never returns) is therefore
/// noticed with the next call, which is the first one it holds up.
class EngineLoadFeed {
  final void Function() _ping;
  final int Function() _nowMicros;

  EngineLoadFeed({required this._ping, required this._nowMicros});

  static const quietAfter = Duration(seconds: 10);

  final _buckets = StreamController<EngineLoadBucket>.broadcast();
  final _stalls = StreamController<int>.broadcast();

  /// One [EngineLoadBucket] per slice of real time in which the engine did
  /// anything at all. No replay: a listener catches up from [recent] in the
  /// same synchronous step it subscribes in.
  Stream<EngineLoadBucket> get buckets => _buckets.stream;

  /// The buckets received so far, oldest first, capped at a minute's worth.
  /// What the stream alone would lose is the boot: its buckets arrive before
  /// the host exists for anyone to subscribe to.
  final List<EngineLoadBucket> recent = [];
  static const _maxRecent = 600;

  /// When the ping the engine has not answered for a whole heartbeat went
  /// out, or null while it is answering.
  int? get stalledSinceMicros => _stalledSince;
  int? _stalledSince;

  /// [stalledSinceMicros], again on every heartbeat it stays unanswered —
  /// the only news there is while no bucket can arrive.
  Stream<int> get stalls => _stalls.stream;

  int? _pingSentAt;
  int _lastActiveMicros = 0;
  Timer? _beat;

  /// Takes one `engineLoad` message from the core.
  void add(Map<String, dynamic> msg) {
    final bucket = EngineLoadBucket.fromMessage(msg);
    if (bucket == null || _buckets.isClosed) return;
    recent.add(bucket);
    if (recent.length > _maxRecent) recent.removeAt(0);
    _buckets.add(bucket);
    wake();
  }

  /// Notes that work is on its way to the engine, or came out of it.
  void wake() {
    if (_buckets.isClosed) return;
    _lastActiveMicros = _nowMicros();
    _beat ??= Timer.periodic(engineHeartbeat, (_) => _onBeat());
  }

  void _onBeat() {
    final now = _nowMicros();
    if (_pingSentAt case final sent?) {
      _stalledSince = sent;
      _stalls.add(sent);
    } else if (now - _lastActiveMicros > quietAfter.inMicroseconds) {
      _beat?.cancel();
      _beat = null;
    } else {
      _pingSentAt = now;
      _ping();
    }
  }

  /// The engine answered the outstanding ping, so it is free again.
  void pong() {
    _pingSentAt = null;
    _stalledSince = null;
  }

  /// Also called when the engine dies: a dead engine answers no ping, and
  /// read as a stall it would show 0% idle — and report as busy — for the
  /// whole wait until it is replaced.
  Future<void> dispose() async {
    _beat?.cancel();
    _beat = null;
    _pingSentAt = null;
    _stalledSince = null;
    await _buckets.close();
    await _stalls.close();
  }
}

/// How often [EngineLoadFeed] pings an active engine, and so how long an
/// unanswered ping waits before the engine counts as busy. Lowered only by a
/// test that has to see a stall without holding the engine for seconds.
@visibleForTesting
Duration engineHeartbeat = const Duration(seconds: 1);

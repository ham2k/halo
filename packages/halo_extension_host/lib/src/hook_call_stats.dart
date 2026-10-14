// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What each hook call cost, and where the calls queued behind each other —
// the records ExtensionHost keeps for latency analysis.

/// Whether this is a debug build — where the host reports slow queue waits
/// without being asked. Flutter's `kDebugMode`, spelled the way Flutter
/// defines it rather than imported: this package must stay importable from a
/// plain Dart VM — the halo-ext CLI boots the very same host
/// (docs/extensions/cli.md) — and `package:flutter/foundation.dart` pulls in
/// `dart:ui`, which does not exist there. See `runningOnWeb` for the same move
/// with `kIsWeb`.
const bool debugBuild = !bool.fromEnvironment('dart.vm.product') && !bool.fromEnvironment('dart.vm.profile');

/// A batch's name in the samples, the queue summary and a timeout's message:
/// its method when every call shares one, so the same work groups under one
/// row whatever the batch's size, and no one program is named for a batch
/// that spans several.
String batchLabel(List<Object?> methods) {
  final distinct = methods.toSet();
  return distinct.length == 1 ? 'batch:${distinct.single}' : 'batch:mixed';
}

/// One completed hook invocation, for latency analysis.
class HookCallSample {
  final String label;
  final int totalMillis;
  final int jsMillis;

  /// How long this call sat between being dispatched and the engine starting
  /// its eval — the single engine's backlog, not this hook's own cost.
  ///
  /// Microseconds rather than milliseconds like its neighbours: the waits
  /// worth acting on start around a frame, and a millisecond field reports
  /// most of that range as `0` or `1`. Always ~0 in a host running the core
  /// in-process (every test, and all of web), where dispatch calls the core
  /// synchronously and there is no queue to wait in.
  final int queueMicros;

  const HookCallSample({required this.label, required this.totalMillis, required this.jsMillis, this.queueMicros = 0});
}

/// The worst and typical queue wait seen for one hook label — see
/// [ExtensionHost.queueWaitSummary].
class QueueWaitStat {
  final String label;
  final int calls;

  /// Microseconds, as [HookCallSample.queueMicros].
  final int worstMicros;
  final int totalMicros;

  const QueueWaitStat({required this.label, required this.calls, required this.worstMicros, required this.totalMicros});

  int get meanMicros => calls == 0 ? 0 : totalMicros ~/ calls;

  @override
  String toString() => '$label ×$calls worst ${worstMicros ~/ 1000}ms mean ${meanMicros ~/ 1000}ms';
}

/// [ExtensionHost.queueWaitSummary]'s aggregation, as a function of the
/// samples alone so it can be exercised without booting an engine.
///
/// Ordered by the WORST wait rather than the mean: one hook stalling behind a
/// rescore for a second is the thing worth finding, and averaging it against
/// that hook's hundreds of instant calls hides exactly that.
List<QueueWaitStat> summarizeQueueWaits(List<HookCallSample> samples) {
  final calls = <String, int>{};
  final worst = <String, int>{};
  final total = <String, int>{};
  for (final sample in samples) {
    calls[sample.label] = (calls[sample.label] ?? 0) + 1;
    total[sample.label] = (total[sample.label] ?? 0) + sample.queueMicros;
    if (sample.queueMicros > (worst[sample.label] ?? 0)) worst[sample.label] = sample.queueMicros;
  }
  final stats = [
    for (final entry in calls.entries)
      QueueWaitStat(label: entry.key, calls: entry.value, worstMicros: worst[entry.key] ?? 0, totalMicros: total[entry.key] ?? 0),
  ];
  stats.sort((a, b) => b.worstMicros.compareTo(a.worstMicros));
  return stats;
}

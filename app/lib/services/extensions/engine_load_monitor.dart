// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How idle the extension engine has been, across runtime replacements, and
// the report that goes out when extensions leave too little room for logging.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:halo_core/halo_core.dart' show Hooks, realNowUtc;
import 'package:halo_extension_host/halo_extension_host.dart';

import '../error_reporting_service.dart';

/// Follows the engine's busy time ([ExtensionHost.engineLoad]) and its hooks'
/// latency from one runtime to the next, and reports to the crash backend
/// when the engine has been too busy for too long, or a hook too slow — only
/// while the operator shares app usage data, since this is a report the app
/// volunteers, not a crash.
///
/// One engine answers every hook, so a keystroke's lookup or dupe check
/// queues behind whatever else extensions are doing. Under [reportBelowIdle]
/// over [reportWindow], that queue is the likeliest thing between the
/// operator and a logged contact. But a hook can be slow with the engine
/// idle — awaiting the app's database behind a queue of other reads — and
/// busy time never sees that, so latency has a trigger of its own:
/// [reportAboveP95] over [latencyWindow].
class EngineLoadMonitor {
  static const reportWindow = Duration(seconds: 10);
  static const reportBelowIdle = 0.30;
  static const reportEvery = Duration(minutes: 5);

  /// The app's first minute of extensions: loading bundles and activating
  /// them is busy by nature, so a breach here reports only when this launch
  /// drew the [startupSampleRate] — every launch reporting its own boot would
  /// bury the field sessions this exists to find. The first runtime only: a
  /// replacement boots because the last one died, and an engine saturated
  /// enough to crash-loop is the case most worth reporting.
  static const startupPeriod = Duration(seconds: 60);
  static const startupSampleRate = 0.10;

  /// A hook label whose calls in the last [latencyWindow] number at least
  /// [latencyMinCalls] and take [reportAboveP95] or more at p95 is reported.
  /// The call floor keeps one slow online lookup, or a minute's two spot
  /// fetches from a slow server, from reading as a hook that is slow as a
  /// rule: under 20 calls, a nearest-rank p95 is the slowest call alone.
  /// Timed-out calls count, at the moment their caller gave up.
  static const latencyWindow = Duration(seconds: 60);
  static const latencyMinCalls = 20;
  static const reportAboveP95 = Duration(seconds: 1);

  /// The labels the latency trigger watches: hooks whose work is local by
  /// design — the spot board's offline lookup batches and the activity
  /// search, by fan-out and by batch. An online lookup waits on QRZ or HamDB,
  /// and an import's enrichment runs those back to back, so watched they
  /// would report a slow network as a stalled app. Spelled as the host
  /// labels its calls (`$category.$method*` for a fan-out).
  static final latencyWatched = {
    batchLabel([Hooks.lookupServiceLookupCallInfo.method]),
    '${Hooks.activitySuggest.category}.${Hooks.activitySuggest.method}*',
    batchLabel([Hooks.activitySuggest.method]),
  };

  final int Function() _nowMicros;
  final Random _random;
  final bool Function(String title, String body) _report;
  final bool Function() _consented;

  /// [consented] is read at each report, so turning sharing off stops the
  /// next one.
  EngineLoadMonitor({required this._consented, int Function()? nowMicros, Random? random, bool Function(String title, String body)? report})
    : _nowMicros = nowMicros ?? (() => realNowUtc().microsecondsSinceEpoch),
      _random = random ?? Random(),
      _report = report ?? ((title, body) => ErrorReportingService.diagnostic(title: title, body: body));

  /// Kept across runtimes: a replaced runtime's busy time was real, and the
  /// window is keyed by real time, so the two simply continue one another.
  final window = EngineLoadWindow();

  /// The last [latencyWindow] of hook samples, oldest first, each with when
  /// it arrived. Kept across runtimes, like [window].
  final List<(int, HookCallSample)> _recentSamples = [];

  ExtensionHost? _host;
  final List<StreamSubscription<Object>> _subscriptions = [];
  int? _attachedMicros;
  int _boots = 0;
  bool _firstBootSampled = false;
  int? _lastReportMicros;

  /// Starts following [host], which has just booted.
  void attach(ExtensionHost host) {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _host = host;
    _noteBoot();
    // Caught up and subscribed in one synchronous step, so no bucket is
    // both in the backlog and on the stream.
    for (final bucket in host.engineLoad.recent) {
      window.add(bucket, nowMicros: _nowMicros());
    }
    _subscriptions
      ..add(host.engineLoad.buckets.listen(add))
      ..add(host.engineLoad.stalls.listen((_) => _check()))
      ..add(host.sampleAdded.listen(addSample));
    _check();
  }

  /// The sample is rolled once rather than per breach: a busy boot breaches
  /// on every bucket for seconds, and a roll on each would report nearly
  /// every launch.
  void _noteBoot() {
    _attachedMicros = _nowMicros();
    if (++_boots == 1) _firstBootSampled = _random.nextDouble() < startupSampleRate;
  }

  /// [attach]'s boot bookkeeping without a host to follow.
  @visibleForTesting
  void debugMarkBoot() => _noteBoot();

  void add(EngineLoadBucket bucket) {
    window.add(bucket, nowMicros: _nowMicros());
    _check();
  }

  /// Checked per sample against its own label only: every other label's
  /// numbers are unchanged by it.
  void addSample(HookCallSample sample) {
    if (!latencyWatched.contains(sample.label)) return;
    final now = _nowMicros();
    final since = now - latencyWindow.inMicroseconds;
    _recentSamples
      ..add((now, sample))
      ..removeWhere((entry) => entry.$1 < since);
    // Before the summary, which sorts on every hook result: in a cooldown,
    // or with sharing off, nothing it finds could be reported.
    if (!_reportable(now)) return;
    final stat = summarizeLatencies([
      for (final (_, recent) in _recentSamples)
        if (recent.label == sample.label) recent,
    ]).single;
    if (stat.calls < latencyMinCalls || stat.p95Millis < reportAboveP95.inMilliseconds) return;
    _reportIfDue('Extension hooks slow', now, lead: 'slow over ${latencyWindow.inSeconds}s: $stat');
  }

  /// The share of [span] the engine spent idle, from 0 to 1.
  double idle(Duration span) => _idle(span, _nowMicros());

  double _idle(Duration span, int now) => window.idleFraction(span, nowMicros: now, stalledSinceMicros: _host?.engineLoad.stalledSinceMicros);

  /// Checked when a bucket arrives, and on each heartbeat the engine leaves
  /// unanswered: idle time falls only when busy time is reported or the
  /// engine stops answering, so nothing else can cross the threshold.
  void _check() {
    final now = _nowMicros();
    if (_idle(reportWindow, now) >= reportBelowIdle) return;
    _reportIfDue('Extension engine busy', now);
  }

  /// One report at most every [reportEvery] whichever trigger sent it — a
  /// busy engine slows its hooks too, and both triggers' reports carry the
  /// same picture of the engine.
  void _reportIfDue(String title, int now, {String? lead}) {
    if (!_reportable(now)) return;
    _lastReportMicros = now;
    _report(title, [?lead, _describe(now, inStartup: _inStartup(now))].join('\n'));
  }

  bool _reportable(int now) {
    final last = _lastReportMicros;
    if (last != null && now - last < reportEvery.inMicroseconds) return false;
    if (_inStartup(now) && !_firstBootSampled) return false;
    return _consented();
  }

  bool _inStartup(int now) {
    final attached = _attachedMicros;
    return _boots == 1 && attached != null && now - attached < startupPeriod.inMicroseconds;
  }

  String _describe(int now, {required bool inStartup}) {
    String pct(Duration span) => '${(_idle(span, now) * 100).round()}%';
    String ms(int micros) => '${(micros / 1000).round()}ms';
    final longest = window.longest(reportWindow, nowMicros: now);
    final stalledSince = _host?.engineLoad.stalledSinceMicros;
    final attached = _attachedMicros;
    return [
      'idle: 1s ${pct(const Duration(seconds: 1))} · 10s ${pct(reportWindow)} · 60s ${pct(const Duration(seconds: 60))}',
      if (stalledSince != null) 'not answering for ${ms(now - stalledSince)}',
      if (longest != null) 'longest busy in 10s: ${ms(longest.micros)} ${longest.label ?? '?'}',
      if (attached != null) 'runtime up ${((now - attached) / 1e6).round()}s${inStartup ? ' (startup, sampled)' : ''}',
      'busy in 10s by label:',
      for (final entry in window.busyByLabel(reportWindow, nowMicros: now).take(10)) '  ${entry.key} ${ms(entry.value)}',
      if (_host case final host?) ...[
        'worst queue waits:',
        for (final stat in host.queueWaitSummary().take(5)) '  $stat',
        'slowest hooks, end to end:',
        for (final stat in host.latencySummary().take(5)) '  $stat',
      ],
    ].join('\n');
  }
}

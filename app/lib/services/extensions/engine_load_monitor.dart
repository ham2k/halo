// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How idle the extension engine has been, across runtime replacements, and
// the report that goes out when extensions leave too little room for logging.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:halo_core/halo_core.dart' show realNowUtc;
import 'package:halo_extension_host/halo_extension_host.dart';

import '../error_reporting_service.dart';

/// Follows the engine's busy time ([ExtensionHost.engineLoad]) from one
/// runtime to the next, and reports to the crash backend when the engine has
/// been too busy for too long — only while the operator shares app usage
/// data, since this is a report the app volunteers, not a crash.
///
/// One engine answers every hook, so a keystroke's lookup or dupe check
/// queues behind whatever else extensions are doing. Under [reportBelowIdle]
/// over [reportWindow], that queue is the likeliest thing between the
/// operator and a logged contact.
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
      ..add(host.engineLoad.stalls.listen((_) => _check()));
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

  /// The share of [span] the engine spent idle, from 0 to 1.
  double idle(Duration span) => _idle(span, _nowMicros());

  double _idle(Duration span, int now) => window.idleFraction(span, nowMicros: now, stalledSinceMicros: _host?.engineLoad.stalledSinceMicros);

  /// Checked when a bucket arrives, and on each heartbeat the engine leaves
  /// unanswered: idle time falls only when busy time is reported or the
  /// engine stops answering, so nothing else can cross the threshold.
  void _check() {
    final now = _nowMicros();
    if (_idle(reportWindow, now) >= reportBelowIdle) return;
    final last = _lastReportMicros;
    if (last != null && now - last < reportEvery.inMicroseconds) return;
    final attached = _attachedMicros;
    final inStartup = _boots == 1 && attached != null && now - attached < startupPeriod.inMicroseconds;
    if (inStartup && !_firstBootSampled) return;
    if (!_consented()) return;
    _lastReportMicros = now;
    _report('Extension engine busy', _describe(now, inStartup: inStartup));
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
      if (_host case final host?) ...['worst queue waits:', for (final stat in host.queueWaitSummary().take(5)) '  $stat'],
    ].join('\n');
  }
}

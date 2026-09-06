// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How long a webview map gets to draw itself, and what its failure to do so
// is allowed to mean.
//
// Held by the webview backend rather than written into it because the
// decision has three inputs arriving at different times — the pane becoming
// visible, the horizons elapsing, and the page finally reporting in — and all
// of the behavior is in how they interleave. Reaching `poloMapReady` in a
// widget test means reaching a JavaScript handler registered in
// `onWebViewCreated`, which never fires without a platform view, so the
// 'ready-late' path cannot be exercised through the widget at all.

import 'dart:async';

import 'package:halo_core/halo_core.dart' show realNowMillis;

import '../../services/map_error_reporter.dart';

/// The two horizons, and what separates them.
///
/// A single timer conflates two different findings: a map that arrives at 20
/// seconds was SLOW, one that never arrives is BROKEN, and counting them
/// together is what makes the rate unreadable. A cold webview start fetching
/// the GL script off a CDN, then a style, then tiles, can pass [grace] on a
/// working connection and still turn up.
///
/// So the operator is told at [grace] — a blank pane with no explanation is
/// the part that matters to them — and nothing is reported there, because at
/// that moment the two are still the same picture. A map arriving after it is
/// 'ready-late'; one still missing at [giveUp] is 'never-ready'. Exactly one
/// of the two is ever sent, so a session cannot be counted in both.
///
/// Both horizons count only time the map was actually on screen, because
/// MapLibre's `load` waits for the first RENDER and a pane that is laid out
/// but never painted (a dock group's `IndexedStack`, an unselected tab, a
/// backgrounded app) cannot produce one. A map never given a frame has not
/// failed at anything.
class MapReadyWatchdog {
  /// When the pane stops claiming a map is coming. Operator-facing only.
  static const grace = Duration(seconds: 15);

  /// When its absence becomes evidence.
  static const giveUp = Duration(seconds: 60);

  /// Raise the empty state. Called at most once.
  final void Function() onUnavailable;

  /// The clock the visible-time arithmetic below reads.
  ///
  /// Defaults to [realNowMillis], and that default is the contract: what it
  /// measures becomes a [Timer] duration, so a travelled session must not
  /// expire every horizon at once — see docs/design/time.md §1. Swapping it
  /// for `nowMillis` would read as an ordinary application of the app-clock
  /// rule and nothing in the clock-discipline check would catch it, so a test
  /// travels the clock and pins that this number does not follow.
  ///
  /// Injected only so a test can put it on the same timeline as the timers:
  /// `fakeAsync` replaces `Timer` and `clock` but NOT `DateTime.now()`, so
  /// code measuring on the wall clock while its timers run on fake time
  /// computes about zero however far the test elapses (time.md §7).
  final int Function() now;

  MapReadyWatchdog({required this.onUnavailable, this.now = realNowMillis});

  Timer? _graceTimer;
  Timer? _giveUpTimer;

  bool _visible = false;
  bool _ready = false;
  bool _gaveUp = false;
  bool _reported = false;
  bool _disposed = false;

  /// Visible milliseconds already spent, and when the current visible stretch
  /// began. [giveUp] accumulates across stretches: the page is not torn down
  /// when a pane is hidden, so sixty seconds of paint time is the same
  /// evidence however many sittings it took. Without this an operator who
  /// reads the empty state at 15s and leaves — the response the empty state
  /// invites — resets the clock every time, and a permanently broken map is
  /// never reported at all.
  ///
  /// [grace] deliberately does NOT accumulate: it exists to decide when to
  /// stop claiming a map is coming, and a map that has just come back on
  /// screen is owed a fresh look before the pane gives up on it.
  int _visibleMillis = 0;
  int? _visibleSince;

  void setVisible(bool visible) {
    if (_disposed || visible == _visible) return;
    _visible = visible;
    if (visible) {
      _visibleSince = now();
      _start();
    } else {
      _visibleMillis += now() - (_visibleSince ?? now());
      _visibleSince = null;
      _stop();
    }
  }

  /// The page reported in. A late arrival is its own kind, so that what is
  /// left on 'never-ready' is only ever a map that never came — [_reported]
  /// is what holds that: past [giveUp] the map is already counted as one that
  /// never arrived, and saying so twice under two names would put the same
  /// session in both populations.
  void markReady() {
    if (_disposed || _ready) return;
    _ready = true;
    _stop();
    if (!_gaveUp || _reported) return;
    _reported = true;
    // Fixed wording, carrying no elapsed time: the message is what the crash
    // backend titles and GROUPS the issue by, so a number in it would split
    // one finding into an issue per session — which is exactly what the
    // per-tile map errors already do.
    MapErrorReporter.report(
        backend: 'webview',
        kind: 'ready-late',
        message: 'the map page reported ready only after the pane gave up on it');
  }

  void dispose() {
    _disposed = true;
    _stop();
  }

  void _start() {
    if (_ready) return;
    _stop();
    // Not re-armed once it has fired: the operator has already been told, and
    // saying it again on every return to the pane says nothing new.
    if (!_gaveUp) {
      _graceTimer = Timer(grace, () {
        if (_ready || _disposed) return;
        _gaveUp = true;
        onUnavailable();
      });
    }
    if (_reported) return;
    final remaining = giveUp - Duration(milliseconds: _visibleMillis);
    _giveUpTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (_ready || _disposed || _reported) return;
      _reported = true;
      MapErrorReporter.report(
          backend: 'webview', kind: 'never-ready', message: 'the map page never reported ready');
    });
  }

  void _stop() {
    _graceTimer?.cancel();
    _graceTimer = null;
    _giveUpTimer?.cancel();
    _giveUpTimer = null;
  }
}

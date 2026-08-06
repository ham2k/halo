// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bridges [SpotsService.unavailableSources] to the status bar. Lives outside
// SpotsService so that service stays a pure data model — it is constructed in
// tests with nothing but a fetch function, and a status-bar dependency would
// have to be faked in every one of them.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../i18n/strings.g.dart';
import 'spots_service.dart';
import 'status_bar_service.dart';

/// The one status-bar key this reporter owns. A single item naming every
/// unreachable source, not one per source: a network drop takes them all out
/// at once, and six identical rows say nothing five don't.
const spotsUnavailableKey = 'spots-unavailable';

/// Tells the operator which spot sources went quiet, and stops telling them
/// once one answers again.
///
/// Only transitions post. The fetch runs every couple of minutes for as long
/// as an operation is open, so writing the message on each cycle would repost
/// — and rebuild the footer — every two minutes for as long as a feed stays
/// down, for a message that never changed.
VoidCallback attachSpotsStatusReporter({
  required SpotsService spots,
  required StatusBarService statusBar,
  /// Display name for a hook key ("SOTAWatch" for `sota`), falling back to
  /// the key itself.
  ///
  /// Resolved per report rather than once at attach time, and asynchronously,
  /// because the names come from the extension runtime and the caller cannot
  /// promise they have arrived: the runtime starts fire-and-forget, its first
  /// start can fail and be retried, and the `sourceName` fan-out has a
  /// timeout of its own on a cold, busy launch. A resolver that gives up
  /// after one attempt leaves every message naming `sota` instead of
  /// SOTAWatch — the exact thing this parameter exists to avoid.
  required Future<String> Function(String hookKey) nameFor,
}) {
  List<String>? reported;
  // Discriminates an awaited resolve that is still current from one that a
  // later change — or the detach below — has superseded. Without it a slow
  // name lookup posts a message describing an outage that is already over,
  // and worse, one that posts after detach is pinned to the footer for the
  // session with no listener left to retract it.
  var generation = 0;

  Future<void> onChange() async {
    final current = spots.unavailableSources;
    // Set equality, not list equality: the same two sources in the other
    // order is the same message, and would otherwise repost.
    if (reported != null && setEquals(reported!.toSet(), current.toSet())) return;
    final mine = ++generation;

    if (current.isEmpty) {
      reported = current;
      statusBar.clear(spotsUnavailableKey);
      return;
    }
    final names = await Future.wait(current.map(nameFor));
    if (mine != generation) return;

    statusBar.setMessage(
      key: spotsUnavailableKey,
      icon: 'cloud-off-outline',
      title: t.operation.spots.unavailableTitle,
      text: t.operation.spots.unavailableText(sources: (names.toList()..sort()).join(', ')),
    );
    // Only once it is actually on screen. Committed before the await, a
    // `nameFor` that throws would leave this outage marked as reported and
    // therefore never retried — silent until the set of sources changes.
    reported = current;
  }

  void listener() {
    // `nameFor` is caller-supplied and may reject. Unguarded, the rejection
    // escapes this unawaited call to ErrorPolicy, which has no rule for it
    // and defaults to notifying — so a footer line the operator could have
    // ignored becomes an error card instead.
    unawaited(onChange().catchError((Object e) {
      debugPrint('[spots] could not report unavailable sources: $e');
    }));
  }

  spots.addListener(listener);
  return () {
    spots.removeListener(listener);
    // Supersedes any resolve still in flight. Without it, one that lands
    // after this posts a message nothing is left to clear.
    generation++;
    statusBar.clear(spotsUnavailableKey);
  };
}

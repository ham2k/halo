// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Bridges [SpotsService.unavailableSources] and [SpotsService.failedSources]
// to the status bar. Lives outside SpotsService so that service stays a pure
// data model — it is constructed in tests with nothing but a fetch function,
// and a status-bar dependency would have to be faked in every one of them.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'spots_service.dart';
import 'status_bar_service.dart';

/// The one status-bar key this reporter owns. A single item naming every
/// source in trouble, not one per source: a network drop takes them all out
/// at once, and six identical rows say nothing five don't. That holds across
/// the two kinds too — sources that went quiet and sources that answered with
/// an error share this item, as two clauses of one message.
const spotsUnavailableKey = 'spots-unavailable';

/// Tells the operator which spot sources went quiet or answered with an
/// error, and stops telling them once they recover.
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

  /// Hook keys the operator has switched off in the Spots Panel's source
  /// filter. An outage in a source they opted out of asks nothing of them,
  /// so it never reaches the footer — the fetch itself still runs (the
  /// `spot-history` lookup mines every source's cache), this is reporting
  /// only.
  ///
  /// A getter, read on every evaluation, because the set lives in the
  /// panel's persisted filter state and changes while an outage is up.
  required Set<String> Function() disabledSources,

  /// Fires when [disabledSources] may have changed, so disabling a source
  /// that is currently named retracts the message right then — the only way
  /// an operator has to shoo it away — rather than on the next fetch cycle.
  /// Required alongside the getter: without it, retraction silently degrades
  /// to "whenever the next fetch lands", up to a whole cycle after the
  /// operator acted to silence the message.
  required Listenable disabledSourcesChanges,
}) {
  ({Set<String> unavailable, Set<String> failed})? reported;
  // The outage a resolve is currently in flight for. Without it, any
  // listener firing during the await — the settings service notifies for
  // every settings write, not just this filter — supersedes a resolve of the
  // very same sets and starts another name fan-out, over a runtime that is
  // already struggling with an outage; sustained writes would keep the
  // message from ever posting.
  ({Set<String> unavailable, Set<String> failed})? resolving;
  // Discriminates an awaited resolve that is still current from one that a
  // later change — or the detach below — has superseded. Without it a slow
  // name lookup posts a message describing an outage that is already over,
  // and worse, one that posts after detach is pinned to the footer for the
  // session with no listener left to retract it.
  var generation = 0;

  /// Display names for [keys], sorted and joined — sorted so the same outage
  /// reads the same way whichever order the hooks settled in.
  Future<String> namesOf(Set<String> keys) async => ((await Future.wait(keys.map(nameFor))).toList()..sort()).join(', ');

  Future<void> onChange() async {
    // Set equality, not list equality: the same two sources in the other
    // order is the same message, and would otherwise repost.
    //
    // Subtracted BEFORE the dedupe, so the disabled set is part of the
    // identity being compared: re-enabling a still-down source is a change
    // that must post, and the settings listener re-runs this with the spot
    // sets untouched.
    final disabled = disabledSources();
    final current = (unavailable: spots.unavailableSources.toSet().difference(disabled), failed: spots.failedSources.toSet().difference(disabled));
    if (reported != null && setEquals(reported!.unavailable, current.unavailable) && setEquals(reported!.failed, current.failed)) {
      return;
    }
    // Checked against `resolving`, not just `reported`: `reported` cannot
    // advance until the message is up, so during the await only this guard
    // stops a re-entry over the same sets from superseding its own resolve.
    if (resolving != null && setEquals(resolving!.unavailable, current.unavailable) && setEquals(resolving!.failed, current.failed)) {
      return;
    }
    final mine = ++generation;

    if (current.unavailable.isEmpty && current.failed.isEmpty) {
      reported = current;
      resolving = null;
      statusBar.clear(spotsUnavailableKey);
      return;
    }
    resolving = current;
    try {
      // Both resolved before the generation check, so a change landing midway
      // supersedes the whole message rather than half of it.
      final resolved = await Future.wait([namesOf(current.unavailable), namesOf(current.failed)]);
      if (mine != generation) return;

      // One clause per kind, and only for a kind that has sources: a feed that
      // never replied and one that replied 503 ask different things of the
      // operator — wait, versus stop expecting spots — so a single merged list
      // would point half of them at the wrong problem.
      final clauses = [
        if (current.unavailable.isNotEmpty) t.operation.spots.unavailableText(sources: resolved[0]),
        if (current.failed.isNotEmpty) t.operation.spots.failedText(sources: resolved[1]),
      ];
      // The headline follows the same split as the body. A pure-error outage
      // under an offline cloud reading "Spots unavailable" gives the operator
      // the opposite advice to the sentence underneath it — the feeds are
      // reachable, they are refusing. Anything mixed keeps the broader wording,
      // which is true of both kinds.
      final errorsOnly = current.unavailable.isEmpty;
      statusBar.setMessage(
        key: spotsUnavailableKey,
        icon: errorsOnly ? 'alert-circle-outline' : 'cloud-off-outline',
        title: errorsOnly ? t.operation.spots.failedTitle : t.operation.spots.unavailableTitle,
        text: clauses.join(' '),
      );
      // Only once it is actually on screen. Committed before the await, a
      // `nameFor` that throws would leave this outage marked as reported and
      // therefore never retried — silent until the set of sources changes.
      reported = current;
    } finally {
      // Cleared only by the evaluation that still owns the generation — a
      // superseded one clearing it would drop the guard out from under its
      // successor's own await. A throw lands here with ownership intact, so
      // the same outage stays retryable (the trap `reported`'s late commit
      // exists for).
      if (mine == generation) resolving = null;
    }
  }

  void listener() {
    // `nameFor` is caller-supplied and may reject. Unguarded, the rejection
    // escapes this unawaited call to ErrorPolicy, which has no rule for it
    // and defaults to notifying — so a footer line the operator could have
    // ignored becomes an error card instead.
    unawaited(
      onChange().catchError((Object e, StackTrace s) {
        debugPrint('[spots] could not report unavailable sources: $e\n$s');
      }),
    );
  }

  spots.addListener(listener);
  disabledSourcesChanges.addListener(listener);
  return () {
    spots.removeListener(listener);
    disabledSourcesChanges.removeListener(listener);
    // Supersedes any resolve still in flight. Without it, one that lands
    // after this posts a message nothing is left to clear.
    generation++;
    statusBar.clear(spotsUnavailableKey);
  };
}

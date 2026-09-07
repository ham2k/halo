// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The reporter turns "which spot sources went quiet" into a footer message.
// Its whole job is restraint: the fetch behind it runs every couple of
// minutes for as long as an operation is open, so a reporter that wrote on
// every cycle would repost an unchanged message — and rebuild the footer —
// all day for a single outage.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/spots_service.dart';
import 'package:ham2k_logger/services/spots_status_reporter.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for SettingsService, whose notifyListeners is what the reporter
/// hears when the panel persists a filter change.
class _FilterChanges extends ChangeNotifier {
  void notify() => notifyListeners();
}

void main() {
  late StatusBarService statusBar;
  late List<String> unavailable;
  late List<String> failed;
  late Set<String> disabled;
  late _FilterChanges filterChanges;
  late SpotsService spots;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    statusBar = StatusBarService(await SharedPreferences.getInstance());
    unavailable = [];
    failed = [];
    disabled = {};
    filterChanges = _FilterChanges();
    spots = SpotsService(
      fetchSpots: () async => (
        items: const <Map<String, dynamic>>[],
        succeeded: const <String>[],
        unreachable: unavailable,
        failed: failed,
      ),
    );
    // An outage is only recorded while somebody is watching — which in the
    // app is always true when a fetch runs, since the Operation View holds a
    // subscription for as long as it is open.
    addTearDown(spots.subscribe());
    // `subscribe` fetches immediately; drain it, or a test's own refresh
    // coalesces into that one and sees the outage list it was set up before.
    await Future<void>.delayed(Duration.zero);
  });

  /// The reporter resolves display names asynchronously, so a refresh that
  /// has returned has not necessarily posted yet.
  Future<void> refreshAndSettle() async {
    await spots.refresh();
    await Future<void>.delayed(Duration.zero);
  }

  StatusBarItem? reported() {
    for (final item in statusBar.items) {
      if (item.key == spotsUnavailableKey) return item;
    }
    return null;
  }

  test('names the source by its display name, not its hook key', () async {
    // 'sota' is what the code calls it; "SOTAWatch" is what the operator is
    // looking at in the panel's source filter.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => const {'sota': 'SOTAWatch'}[key] ?? key,
    );
    addTearDown(detach);

    unavailable = ['sota'];
    await refreshAndSettle();

    expect(reported()?.text, contains('SOTAWatch'));
    expect(reported()?.text, isNot(contains('sota')));
  });

  test('an unchanged outage is not reposted on every refresh', () async {
    // The restraint the whole file exists for: `createdAt` is stamped on
    // first post and kept across updates, so a repost is invisible in the
    // item itself — `updatedAt` is what gives it away.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    unavailable = ['sota'];
    await refreshAndSettle();
    final firstWrite = reported()!.updatedAt;

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await refreshAndSettle();

    expect(reported()!.updatedAt, firstWrite, reason: 'the same outage must not rewrite the item');
  });

  test('the same sources in a different order are the same outage', () async {
    // Hook order is not guaranteed — the entries arrive as they settle — so
    // comparing lists rather than sets would repost on nothing but a race.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    unavailable = ['sota', 'pota'];
    await refreshAndSettle();
    final firstWrite = reported()!.updatedAt;

    await Future<void>.delayed(const Duration(milliseconds: 5));
    unavailable = ['pota', 'sota'];
    await refreshAndSettle();

    expect(reported()!.updatedAt, firstWrite);
  });

  test('a second source going down does change the message', () async {
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    unavailable = ['sota'];
    await refreshAndSettle();

    unavailable = ['sota', 'pota'];
    await refreshAndSettle();

    expect(reported()?.text, contains('pota'));
    expect(reported()?.text, contains('sota'));
  });

  test('detaching beats a name lookup still in flight', () async {
    // Detach clears the item, but a resolve already awaiting `nameFor` would
    // post straight afterwards — with the listener gone, nothing is left to
    // ever retract it, so it sits in the footer for the session.
    final gate = Completer<String>();
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) => gate.future,
    );

    unavailable = ['sota'];
    await spots.refresh();
    detach();
    gate.complete('SOTAWatch');
    await Future<void>.delayed(Duration.zero);

    expect(reported(), isNull);
  });

  test('a name lookup that throws does not silence the outage for good', () async {
    // `reported` must advance only once the message is actually up. Committed
    // before the await, a failed resolve leaves the outage marked as reported
    // and the set-equality check short-circuits every later cycle — silent
    // until the sources themselves change.
    var failing = true;
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async {
        if (failing) throw StateError('runtime not up');
        return key;
      },
    );
    addTearDown(detach);

    unavailable = ['sota'];
    await refreshAndSettle();
    expect(reported(), isNull, reason: 'nothing to post yet');

    failing = false;
    await refreshAndSettle();
    expect(reported()?.text, contains('sota'), reason: 'the same outage must still be reportable');
  });

  test('an error and a silence are two clauses of one message', () async {
    // One status item, never one per source — but the two kinds cannot share
    // a wording: "did not respond" tells the operator to wait, and waiting is
    // exactly wrong for a server that is up and answering 503.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => const {'sota': 'SOTAWatch', 'pota': 'POTA.app'}[key] ?? key,
    );
    addTearDown(detach);

    unavailable = ['sota'];
    failed = ['pota'];
    await refreshAndSettle();

    expect(reported()?.text, 'SOTAWatch did not respond. POTA.app returned an error.');
    expect(statusBar.items.where((item) => item.key == spotsUnavailableKey), hasLength(1));
  });

  test('a source that only errored is not described as silent', () async {
    // The clause for an empty bucket must not be emitted at all — an empty
    // source list would otherwise read as " did not respond".
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    failed = ['pota'];
    await refreshAndSettle();

    expect(reported()?.text, 'pota returned an error.');
  });

  test('the headline follows the body, so an error is not filed under "unavailable"', () async {
    // Half the item is not allowed to contradict the other half. A pure-error
    // outage under an offline cloud saying "Spots unavailable" tells the
    // operator to wait for a network that is working — the sentence beneath
    // it says the opposite. Anything mixed keeps the broader wording, which
    // is true of both kinds.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    failed = ['pota'];
    await refreshAndSettle();
    expect(reported()?.title, 'Spot source error');
    expect(reported()?.icon, isNot('cloud-off-outline'));

    unavailable = ['sota'];
    await refreshAndSettle();
    expect(reported()?.title, 'Spots unavailable', reason: 'a mixed outage takes the wording true of both');
    expect(reported()?.icon, 'cloud-off-outline');
  });

  test('a second source starting to error reposts, even with the silent set unchanged', () async {
    // The dedupe has to watch BOTH buckets. Comparing only the timed-out set
    // leaves a message that is true and incomplete for as long as the first
    // outage lasts — and says nothing at all about the feed that broke
    // second. Note the silent set never changes here: a test that moves a
    // source BETWEEN buckets passes either way, because the timed-out set
    // changes on its own.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    unavailable = ['sota'];
    await refreshAndSettle();
    expect(reported()?.text, 'sota did not respond.');

    failed = ['pota'];
    await refreshAndSettle();

    expect(reported()?.text, 'sota did not respond. pota returned an error.');
  });

  test('a source moving from silent to erroring changes the advice', () async {
    // Same source, opposite instruction: a feed that is back up and refusing
    // must stop being something to wait out.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    unavailable = ['sota'];
    await refreshAndSettle();
    expect(reported()?.text, 'sota did not respond.');

    unavailable = [];
    failed = ['sota'];
    await refreshAndSettle();

    expect(reported()?.text, 'sota returned an error.');
  });

  test('the message clears when the sources answer again', () async {
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    unavailable = ['sota'];
    await refreshAndSettle();
    expect(reported(), isNotNull);

    unavailable = [];
    await refreshAndSettle();
    expect(reported(), isNull, reason: 'a recovered source must not leave the notice behind');
  });

  test('a source the operator switched off never posts at all', () async {
    // An operator who turned SOTA off is not waiting on SOTA, so its outage
    // asks nothing of them. The fetch still ran — only the reporting is
    // filtered.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    disabled = {'sota'};
    unavailable = ['sota'];
    failed = ['sota'];
    await refreshAndSettle();

    expect(reported(), isNull);
  });

  test('a disabled source is dropped from a mixed outage, not the whole message', () async {
    // Per-source subtraction, not an all-or-nothing gate: the enabled feed's
    // outage is still news.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    disabled = {'sota'};
    unavailable = ['sota', 'pota'];
    await refreshAndSettle();

    expect(reported()?.text, 'pota did not respond.');
  });

  test('disabling a named source retracts the message without waiting for a fetch', () async {
    // The de-facto dismiss: the next fetch is up to two minutes out, and a
    // reporter that only re-evaluates on fetch leaves the nag up exactly when
    // the operator just acted to silence it.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    unavailable = ['sota'];
    await refreshAndSettle();
    expect(reported(), isNotNull);

    disabled = {'sota'};
    filterChanges.notify();
    await Future<void>.delayed(Duration.zero);

    expect(reported(), isNull);
  });

  test('an unrelated settings write mid-resolve does not restart the name fan-out', () async {
    // The settings service notifies for EVERY settings write, and `reported`
    // cannot advance until the message is up — so without a guard on the
    // resolve itself, each write during the await supersedes a resolve of
    // the same sets and fires another fan-out over a runtime already
    // struggling with the outage; sustained writes starve the post forever.
    final gate = Completer<String>();
    var lookups = 0;
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) {
        lookups++;
        return gate.future;
      },
    );
    addTearDown(detach);

    unavailable = ['sota'];
    await spots.refresh();
    filterChanges.notify();
    gate.complete('SOTAWatch');
    await Future<void>.delayed(Duration.zero);

    expect(reported()?.text, contains('SOTAWatch'));
    expect(lookups, 1, reason: 'the same outage must not supersede its own resolve');
  });

  test('re-enabling a still-down source posts again, also without a fetch', () async {
    // The disabled set must be part of the outage's identity. Compared after
    // subtraction only on fetch, the sets look unchanged here and the dedupe
    // would swallow the repost until the feed's next cycle.
    final detach = attachSpotsStatusReporter(
      spots: spots,
      statusBar: statusBar,
      disabledSources: () => disabled,
      disabledSourcesChanges: filterChanges,
      nameFor: (key) async => key,
    );
    addTearDown(detach);

    disabled = {'sota'};
    unavailable = ['sota'];
    await refreshAndSettle();
    expect(reported(), isNull);

    disabled = {};
    filterChanges.notify();
    await Future<void>.delayed(Duration.zero);

    expect(reported()?.text, 'sota did not respond.');
  });
}

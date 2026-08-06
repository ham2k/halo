// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The reporter turns "which spot sources went quiet" into a footer message.
// Its whole job is restraint: the fetch behind it runs every couple of
// minutes for as long as an operation is open, so a reporter that wrote on
// every cycle would repost an unchanged message — and rebuild the footer —
// all day for a single outage.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/spots_service.dart';
import 'package:ham2k_logger/services/spots_status_reporter.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StatusBarService statusBar;
  late List<String> unavailable;
  late List<String> failed;
  late SpotsService spots;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    statusBar = StatusBarService(await SharedPreferences.getInstance());
    unavailable = [];
    failed = [];
    spots = SpotsService(
      fetchSpots: () async => (items: const <Map<String, dynamic>>[], unreachable: unavailable, failed: failed),
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
}

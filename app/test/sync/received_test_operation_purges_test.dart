// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The reactive notice HaLoServices shows when this device only RECEIVED a
// Test Operation purge via sync (never confirmed one itself) — the UI half
// of OperationsRepository.watchReceivedPurgesPending. A code review on this
// feature caught three real bugs here before they shipped: `clear()` never
// touches a StatusBarNotice (`dismissNotice` does — separate lists), a
// persisted notice comes back after a restart with no working action
// (actions can't survive one), and drift's table-level `.watch()`
// re-emission on ANY write silently resurrected a dismissed notice even
// when the pending set hadn't changed. These tests pin all three.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> buildServices() async {
    return (await makeHaLoServices()).services;
  }

  const noticeKey = 'testOperations:receivedPurges';

  testWidgets('a received purge shows a non-persisted notice, and confirming it clears it for real', (tester) async {
    final services = await buildServices();
    services.watchReceivedTestOperationPurges();

    // The live record first: a purge tombstone on its own never creates a
    // row (OperationsRepository.mergeFromSync), so a device only ever gets
    // this notice for an operation it actually had.
    await services.operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'updatedAtMillis': 1},
    ]);
    await services.operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 2},
    ]);
    await tester.pump();

    final notice = services.statusBar.activeNotices.singleWhere((n) => n.key == noticeKey);
    expect(notice.persist, isFalse, reason: 'a persisted copy would come back after a restart with a Review button that does nothing');

    final result = await services.confirmReceivedTestOperationPurges(['remote-op']);
    expect(result, (eligible: 1, removed: 1));
    await tester.pump();

    expect(
      services.statusBar.activeNotices.where((n) => n.key == noticeKey),
      isEmpty,
      reason: 'must be dismissNotice, not clear() — clear() only ever touches unrelated status items',
    );
  });

  testWidgets('dismissing the notice is not undone by an unrelated write to the operations table', (tester) async {
    final services = await buildServices();
    services.watchReceivedTestOperationPurges();

    // The live record first: a purge tombstone on its own never creates a
    // row (OperationsRepository.mergeFromSync), so a device only ever gets
    // this notice for an operation it actually had.
    await services.operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'updatedAtMillis': 1},
    ]);
    await services.operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 2},
    ]);
    await tester.pump();
    services.statusBar.dismissNotice(noticeKey);
    expect(services.statusBar.activeNotices.where((n) => n.key == noticeKey), isEmpty);

    // drift's watch() re-emits on ANY write to a table it depends on, not
    // just one that changes this query's result — this write doesn't touch
    // 'remote-op' at all, and must not resurrect the dismissed notice.
    await services.operations.create(stationCall: 'N0DEV');
    await tester.pump();

    expect(
      services.statusBar.activeNotices.where((n) => n.key == noticeKey),
      isEmpty,
      reason: 'an unchanged pending set must not re-show a notice the operator already dismissed',
    );
  });

  testWidgets('confirming a received purge through the real service removes a QSO whose own purge tombstone '
      "hasn't arrived yet", (tester) async {
    // Drives it through HaLoServices.confirmReceivedTestOperationPurges
    // itself, not the repository methods by hand — a prior version of this
    // fix used the purged-and-synced-gated hardDeletePurgedForOperation
    // here instead of the unconditional hardDeleteAllForOperation, and nothing
    // caught it because the repository-level tests mirrored the service's
    // steps instead of calling the service.
    final services = await buildServices();
    services.watchReceivedTestOperationPurges();

    // The live record first: a purge tombstone on its own never creates a
    // row (OperationsRepository.mergeFromSync), so a device only ever gets
    // this notice for an operation it actually had.
    await services.operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'updatedAtMillis': 1},
    ]);
    await services.operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 2},
    ]);
    // Synced normally, with no purged flag of its own — the gap this pins.
    await services.qsos.mergeFromSync([
      {
        'uuid': 'remote-qso',
        'operation': 'remote-op',
        'their': {'call': 'W1AW'},
        'updatedAtMillis': 1,
      },
    ]);
    await tester.pump();

    final result = await services.confirmReceivedTestOperationPurges(['remote-op']);
    expect(result, (eligible: 1, removed: 1));

    expect(await services.operations.get('remote-op'), isNull);
    expect(await services.qsos.get('remote-qso'), isNull);
  });

  testWidgets('cancelling the confirmation dialog re-arms the notice instead of leaving it dismissed', (tester) async {
    final services = await buildServices();
    services.watchReceivedTestOperationPurges();

    // The live record first: a purge tombstone on its own never creates a
    // row (OperationsRepository.mergeFromSync), so a device only ever gets
    // this notice for an operation it actually had.
    await services.operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'updatedAtMillis': 1},
    ]);
    await services.operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 2},
    ]);
    await tester.pump();

    // A navigator for the dialog to open in — same wiring the real app
    // gives `_confirmReceivedPurgesFromNotice` via the global `navigatorKey`.
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(navigatorKey: navigatorKey, home: const SizedBox()),
      ),
    );
    await tester.pump();

    // Invokes the exact closure a tap on the notice's own action button
    // would run — `_onReceivedPurgesPending` captured it as a
    // StatusBarAction, so this is the real private method, not a stand-in.
    services.statusBar.activeNotices.singleWhere((n) => n.key == noticeKey).actions.single.onTap();
    await tester.pumpAndSettle();
    expect(
      services.statusBar.activeNotices.where((n) => n.key == noticeKey),
      isEmpty,
      reason: 'dismissed unconditionally as soon as Review is tapped, before the dialog even resolves',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      services.statusBar.activeNotices.where((n) => n.key == noticeKey),
      isNotEmpty,
      reason:
          'cancelling — backing out after a look, the common case — must re-arm the notice, '
          'not leave it dismissed for the rest of the session',
    );
  });

  testWidgets('a re-delivered purge tombstone does not bring the notice back after the operator removed it', (tester) async {
    // The server keeps a purged record for good and re-delivers it on later
    // pulls, so a removal that only deletes local rows is undone within a
    // round or two: the operation reappears and the notice with it, which is
    // exactly what the operator just said no to.
    final services = await buildServices();
    services.watchReceivedTestOperationPurges();

    await services.operations.mergeFromSync([
      {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'updatedAtMillis': 1},
    ]);
    const tombstone = {'uuid': 'remote-op', 'stationCall': 'KI2D/T', 'deleted': true, 'purged': true, 'updatedAtMillis': 2};
    await services.operations.mergeFromSync([tombstone]);
    await tester.pump();

    expect(await services.confirmReceivedTestOperationPurges(['remote-op']), (eligible: 1, removed: 1));
    await tester.pump();

    await services.operations.mergeFromSync([tombstone]);
    await tester.pump();

    expect(await services.operations.get('remote-op'), isNull);
    expect(services.statusBar.activeNotices.where((n) => n.key == noticeKey), isEmpty);
  });
}

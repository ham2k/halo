// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Being offline is the field's normal state, so the app has one notion of it
// (ConnectivityService) that quietens errors and suspends work. Both of those
// are dangerous in the same direction — a state that says "offline" when it
// is not silently stops the app doing its job — so what these tests guard is
// mostly the ways it must NOT become true, and the ways it must not stay
// true once something answers.

import 'dart:async';
import 'dart:io' show SocketException, WebSocketException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:http/http.dart' show ClientException;

import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart' show HaloDialog, MdiIcons, StatusBarFooter, StatusBarPermaData;

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/connectivity_service.dart';
import 'package:ham2k_logger/services/error_policy.dart';
import 'package:drift/native.dart';
import 'package:ham2k_logger/services/lookup_queue_service.dart';
import 'package:ham2k_logger/services/spots_service.dart';
import 'package:ham2k_logger/views/offline_indicator.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the status-bar indicator', _indicatorTests);

  tearDown(ConnectivityService.resetForTesting);

  group('the offline state', () {
    test('starts false, so errors stay loud until something has actually failed', () {
      // The optimistic default is the whole safety property of this service:
      // being wrong this way can only make noise, never hide a real failure,
      // and the flag now quietens a whole network surface rather than two
      // error reporters.
      expect(ConnectivityService.isOffline, isFalse);
    });

    test('a probe that got no answer is offline even with a healthy interface', () async {
      ConnectivityService.start(changesSource: Stream.value([ConnectivityResult.wifi]), check: () async => [ConnectivityResult.wifi]);
      await pumpEventQueue();
      expect(ConnectivityService.isOffline, isFalse);

      ConnectivityService.reportProbe(reached: false);
      // One unanswered round is not enough: the probe is a single service, so
      // one failure is as likely to be that host as the network.
      expect(ConnectivityService.isOffline, isFalse);

      ConnectivityService.reportProbe(reached: false);
      // The reason the OS signal alone is not enough: the interface is up and
      // reports perfectly throughout.
      expect(ConnectivityService.hasNoRoute, isFalse);
      expect(ConnectivityService.isOffline, isTrue);
    });

    test('an interface coming back does not clear the probe verdict', () async {
      final results = StreamController<List<ConnectivityResult>>();
      ConnectivityService.start(changesSource: results.stream, check: () async => [ConnectivityResult.none]);
      ConnectivityService.reportProbe(reached: false);
      ConnectivityService.reportProbe(reached: false);

      results.add([ConnectivityResult.wifi]);
      await pumpEventQueue();

      // Joining a network says nothing about whether anything answers over
      // it — and the network you join at a hotel is precisely the one that
      // does not. Only the probe clears the probe.
      expect(ConnectivityService.hasNoRoute, isFalse);
      expect(ConnectivityService.isOffline, isTrue);

      ConnectivityService.reportProbe(reached: true);
      expect(ConnectivityService.isOffline, isFalse);
      await results.close();
    });

    test('the edge stream fires on transitions, not on interface churn', () async {
      final results = StreamController<List<ConnectivityResult>>();
      final seen = <bool>[];
      ConnectivityService.offlineChanges.listen(seen.add);
      ConnectivityService.start(changesSource: results.stream, check: () async => [ConnectivityResult.wifi]);
      await pumpEventQueue();

      results.add([ConnectivityResult.mobile]);
      results.add([ConnectivityResult.wifi, ConnectivityResult.ethernet]);
      await pumpEventQueue();
      // Subscribers to this stream resume suspended work; a Wi-Fi-to-cellular
      // handover must not be a recovery event, or a device switching towers
      // re-fans-out every data file for nothing.
      expect(seen, isEmpty);

      results.add([ConnectivityResult.none]);
      await pumpEventQueue();
      expect(seen, [true]);
      await results.close();
    });

    test('an answer outranks the OS saying there is no route', () async {
      final results = StreamController<List<ConnectivityResult>>();
      ConnectivityService.start(changesSource: results.stream, check: () async => [ConnectivityResult.none]);
      await pumpEventQueue();
      expect(ConnectivityService.isOffline, isTrue);

      ConnectivityService.reportProbe(reached: true);
      // connectivity_plus reports `none` over some VPN adapters and desktop
      // setups where traffic flows perfectly. With the OS half latched, the
      // app would stay suspended until the next interface change — which on
      // a stable connection never comes. An answer is a fact about the
      // network; `none` is a report about interfaces, and the fact wins.
      expect(ConnectivityService.hasNoRoute, isFalse);
      expect(ConnectivityService.isOffline, isFalse);
      await results.close();
    });

    test('a verdict with nothing left to revise it is dropped, not left standing', () {
      ConnectivityService.reportProbe(reached: false);
      ConnectivityService.reportProbe(reached: false);
      expect(ConnectivityService.isOffline, isTrue);

      // The operator, offline, turns sync off — an entirely reasonable "stop
      // retrying". Nothing probes after that, so without this the last
      // verdict stands for the rest of the process: work suspended and
      // errors quietened back on full coverage, with retryNow answering
      // `disabled` and the one escape the UI offers closed.
      ConnectivityService.stopProbing();
      expect(ConnectivityService.isOffline, isFalse);
    });

    test('one service failing is not the network being down', () {
      ConnectivityService.reportService('spots', label: 'Spots', reached: false);
      // Per-service state is for the detail view only. Inferring offline from
      // it would turn one feed's outage into a device-wide suspension.
      expect(ConnectivityService.isOffline, isFalse);
      expect(ConnectivityService.services.single.isFailing, isTrue);
    });

    test('a service that has never reported is not reported as failing', () {
      ConnectivityService.reportService('sync', label: 'Sync', reached: true);
      expect(ConnectivityService.services.single.isFailing, isFalse);
    });
  });

  group('error reporting while offline', () {
    ErrorDisposition dispositionFor(Object e) => ErrorPolicy.decide(e).disposition;

    final noAnswer = ExtensionHostException('TimeoutException after 0:00:08.000000');

    test('a call that got no answer is quietened only while we are offline', () {
      // Online, the same timeout keeps uploading: a TCP blip on a working
      // network is worth seeing in aggregate.
      expect(dispositionFor(noAnswer), ErrorDisposition.report);
      expect(dispositionFor(ClientException('Connection reset')), ErrorDisposition.report);

      ConnectivityService.reportProbe(reached: false);
      ConnectivityService.reportProbe(reached: false);
      expect(dispositionFor(noAnswer), ErrorDisposition.logOnly);
      expect(dispositionFor(ClientException('Connection reset')), ErrorDisposition.logOnly);
    });

    test('being offline is not a licence to stop reporting our own bugs', () {
      ConnectivityService.reportProbe(reached: false);
      ConnectivityService.reportProbe(reached: false);
      // Shape as well as state. An outage is not a reason to swallow a
      // FormatException from our own parser that merely happened during one.
      expect(dispositionFor(const FormatException('bad payload')), ErrorDisposition.notify);
      expect(dispositionFor(ExtensionHostException('lookupCall threw')), ErrorDisposition.notify);
    });

    test('a LAN or BLE failure is never quietened by an internet outage', () {
      ConnectivityService.reportProbe(reached: false);
      ConnectivityService.reportProbe(reached: false);
      // The REAL shapes peer sync raises, not a type invented here: its LAN
      // link is a `dart:io` WebSocket, so a dropped peer surfaces as a
      // SocketException or a WebSocketException. Asserting on a made-up class
      // would pass merely by being unrecognised, and would go on passing the
      // day the peer transport starts throwing something the rule does match.
      //
      // Two devices on a hotspot with no upstream — the exact field case this
      // whole feature exists for — sync to each other perfectly while we call
      // ourselves offline, so a peer failure then is real and must stay loud.
      expect(dispositionFor(const SocketException('Connection reset by peer')), ErrorDisposition.notify);
      expect(dispositionFor(const WebSocketException('link closed')), ErrorDisposition.notify);
    });
  });

  group('suspending work while offline', () {
    test('a spot refresh while offline touches nothing rather than reporting outages', () async {
      var fetches = 0;
      var offline = false;
      final spots = SpotsService(
        fetchSpots: () async {
          fetches++;
          return (
            items: [
              {
                'hookKey': 'pota',
                'their': {'call': 'N0CALL'},
                'spot': {'timeInMillis': nowMillis(), 'source': 'pota'},
              },
            ],
            succeeded: const ['pota'],
            unreachable: const <String>[],
            failed: const <String>[],
          );
        },
        isOffline: () => offline,
      );
      addTearDown(spots.dispose);

      await spots.refresh();
      expect(fetches, 1);
      expect(spots.spotsBySource['pota'], hasLength(1));

      offline = true;
      await spots.refresh();
      // Not attempted at all, and — the part that matters — the board is left
      // exactly as it was. Reporting every source as unreachable here would
      // badge the whole panel for a condition the status bar states once.
      expect(fetches, 1);
      expect(spots.spotsBySource['pota'], hasLength(1));
      expect(spots.unavailableSources, isEmpty);
      expect(spots.failedSources, isEmpty);
    });

    test('an empty connectivity emission is not read as having no route', () async {
      // Some backends emit `[]`. `every` on an empty list is true, so the
      // obvious predicate reads that as "no route" — and since the plugin
      // only emits on CHANGE, nothing would ever revise it: the app would
      // suspend its whole network surface for the session, on a working
      // connection, with no way back.
      ConnectivityService.start(changesSource: Stream.value(const <ConnectivityResult>[]), check: () async => const <ConnectivityResult>[]);
      await pumpEventQueue();
      expect(ConnectivityService.hasNoRoute, isFalse);
      expect(ConnectivityService.isOffline, isFalse);
    });

    test('the lookup queue holds while offline and drains on recovery', () async {
      SharedPreferences.setMockInitialValues({});
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);
      final operation = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(operation.uuid, {
        'their': {'call': 'N0CALL'},
      });

      final edges = StreamController<bool>.broadcast();
      var offline = true;
      final looked = <String>[];
      final queue = LookupQueueService(
        lookup: (call, {required qso, required operation, online = true, recentContext = false}) async {
          looked.add(call);
          return null;
        },
        qsos: qsos,
        operations: operations,
        statusBar: StatusBarService(await SharedPreferences.getInstance()),
        isOffline: () => offline,
        offlineChanges: edges.stream,
      );

      queue.enqueue(qso);
      await pumpEventQueue();
      // Held, not dropped: these are logged QSOs being enriched in the
      // background, and the answer is as good in an hour. Dropping them would
      // lose the enrichment for every QSO logged during an activation.
      expect(looked, isEmpty);

      offline = false;
      edges.add(false);
      await pumpEventQueue();
      expect(looked, ['N0CALL']);
      await edges.close();
    });

    test('a recovery landing while the queue writes its results still restarts it', () async {
      // The window is real, not theoretical: results are written while the
      // drain still holds `_processing`, and that write is a database
      // round-trip. A recovery edge arriving inside it finds the queue
      // "already draining" and does nothing — and nothing else ever would,
      // because these entries were enqueued before the outage and this class
      // has no other way back.
      //
      // The recovery is fired FROM the write itself rather than from a timer
      // or a microtask: broadcast delivery and microtask ordering both leave
      // it undefined whether the edge lands inside the window or after it, so
      // a timing-based version of this test passes whether or not the re-arm
      // exists.
      SharedPreferences.setMockInitialValues({});
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final operations = OperationsRepository(db);
      var offline = false;
      final qsos = _RecoveringQsos(db, onWrite: () => offline = false);
      final operation = await operations.create(stationCall: 'KI2D');
      final first = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
      });
      final second = await qsos.add(operation.uuid, {
        'their': {'call': 'K1ABC'},
      });

      final looked = <String>[];
      final queue = LookupQueueService(
        lookup: (call, {required qso, required operation, online = true, recentContext = false}) async {
          looked.add(call);
          // Coverage drops, so the drain breaks with `second` still held.
          if (looked.length == 1) offline = true;
          return {
            'guess': {'name': 'Someone'},
          };
        },
        qsos: qsos,
        operations: operations,
        statusBar: StatusBarService(await SharedPreferences.getInstance()),
        isOffline: () => offline,
      );

      queue.enqueue(first);
      queue.enqueue(second);
      await queue.idle;
      await pumpEventQueue();
      await queue.idle;

      expect(looked, ['W1AW', 'K1ABC']);
    });
  });
}

/// The connectivity status is drawn by `StatusBarOverlay`, which wraps the
/// Navigator rather than living inside it — it owns the bottom of the window
/// across every route. So its own `BuildContext` has no Navigator ancestor,
/// and the obvious `showDialog(context: context, ...)` throws at the tap.
/// Nothing in the widget's own shape says so, which is why this is a test and
/// not a comment.
///
/// The gesture it walks is the whole permanent-status contract: the icon in
/// the collapsed bar opens the MENU (it must not open the dialog — that would
/// make reading the statuses impossible without answering one), and the entry
/// it reveals is what opens the detail.
void _indicatorTests() {
  testWidgets('the connectivity status opens a menu, then the detail dialog from outside the Navigator', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: SizedBox.shrink()),
          // The overlay's own shape: chrome BELOW the navigator in the tree,
          // so `builder`'s context is a sibling of every route rather than a
          // descendant of one.
          // In an Overlay, as the app's own shell puts it (HomeRailShell): the
          // statuses' menu is an OverlayPortal and there is no Navigator up
          // here to borrow one from.
          builder: (context, child) => Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => Column(
                  children: [
                    Expanded(child: child!),
                    Material(
                      child: StatusBarFooter(
                        items: const [],
                        onDismiss: (_) {},
                        perma: [
                          StatusBarPermaData(
                            key: 'connectivity',
                            icon: MdiIcons.cloudOff,
                            text: 'No internet connection',
                            onTap: () =>
                                showOfflineDetail(navigatorKey: navigatorKey, onRetry: () async => SyncRetryOutcome.unreachable, nextAttemptAt: () => null),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(MdiIcons.cloudOff));
    await tester.pumpAndSettle();
    expect(find.byType(HaloDialog), findsNothing, reason: 'the icon opens the menu, not the detail');

    await tester.tap(find.text('No internet connection'));
    await tester.pumpAndSettle();

    expect(find.byType(HaloDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// A repository that flips a flag from inside `update` — the one write the
/// lookup queue performs while its drain is still marked processing.
class _RecoveringQsos extends QsosRepository {
  final void Function() onWrite;

  _RecoveringQsos(super.db, {required this.onWrite});

  @override
  Future<void> update(Qso qso, {Qso? basedOn}) async {
    onWrite();
    return super.update(qso, basedOn: basedOn);
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Sync panel's Synced Data row puts the server's counts directly under this
// device's. The pair is only readable if both sides count the same thing —
// the log the operator still has — so a deleted operation, a deleted QSO, or
// a QSO stranded inside a deleted operation must drop out of the local line
// exactly as LoFi drops it from the server's (see Account#stats there).
// A local number that counts tombstones would read as data the server lost.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

/// [ExtensionServiceWithMockHost] only overrides the `host` getter, while
/// `syncAccountData` reads the private field behind it — so the payload has to
/// be stubbed at the method, not at the mock host's hook table.
class _ExtensionsWithAccountData extends ExtensionServiceWithMockHost {
  final Future<Map<String, dynamic>?> Function() fetch;
  _ExtensionsWithAccountData(this.fetch) : super(const MockExtensionHost({}));

  @override
  Future<Map<String, dynamic>?> syncAccountData() => fetch();
}

/// [fetchAccountData] lets a test hold the fetch open (or fail it) to exercise
/// the panel's in-flight and error states; by default it completes at once
/// with [accountData].
Future<HaLoServices> makeServices(
  Map<String, dynamic>? accountData, {
  Future<Map<String, dynamic>?> Function()? fetchAccountData,
}) async {
  SharedPreferences.setMockInitialValues({'flutter.syncEnabled': true});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = _ExtensionsWithAccountData(fetchAccountData ?? (() async => accountData))
    ..settings = settings;
  return HaLoServices(db, settings, extensions: extensions);
}

Future<void> openSyncPanel(WidgetTester tester, HaLoServices services) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('LoFi Cloud Sync').last);
  await tester.pumpAndSettle();
}

/// Seeds through bare repositories rather than `services.operations`/`.qsos`:
/// those notify the sync engine, which schedules a retry timer the widget
/// tester then fails on.
Future<void> seed(HaLoServices services) async {
  final operations = OperationsRepository(services.db);
  final qsos = QsosRepository(services.db);

  Future<void> addQso(String operation, String call, {bool deleted = false}) async {
    final qso = await qsos.add(operation, {
      'their': {'call': call},
    });
    if (deleted) await qsos.softDelete(qso);
  }

  final live = await operations.create(stationCall: 'N0DEV');
  final gone = await operations.create(stationCall: 'N0DEV');
  await addQso(live.uuid, 'W1AW');
  await addQso(live.uuid, 'K2ABC');
  // Its own tombstone.
  await addQso(live.uuid, 'K3DEF', deleted: true);
  // Not a contact — a start/break/end marker, which shares the qsos table.
  await qsos.addEvent(live.uuid, kind: 'start', atMillis: 1000);
  // No tombstone of its own — but its operation gets one.
  await addQso(gone.uuid, 'K4GHI');
  await operations.softDelete(gone.uuid);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the local count leaves out deletions, including QSOs of a deleted operation', (tester) async {
    final services = await makeServices(null);
    addTearDown(services.db.close);

    await seed(services);

    await openSyncPanel(tester, services);

    // A count labelled "QSOs" means contacts: the seeded start marker is a
    // row in the same table but is not one, so 2 rather than 3.
    expect(find.text('This device: 2 QSOs · 1 operation'), findsOneWidget);
  });

  testWidgets('a QSO with no band is a contact, not an event, and still counts', (tester) async {
    // `band` is nullable, so the event filter cannot be a bare `!= 'event'` —
    // in SQL that is NULL, not true, and would silently drop this QSO.
    final services = await makeServices(null);
    addTearDown(services.db.close);

    final operations = OperationsRepository(services.db);
    final qsos = QsosRepository(services.db);
    final operation = await operations.create(stationCall: 'N0DEV');
    await qsos.add(operation.uuid, {
      'their': {'call': 'W1AW'},
    });

    await openSyncPanel(tester, services);

    expect(find.text('This device: 1 QSO · 1 operation'), findsOneWidget);
  });

  testWidgets('the server count comes from the account payload', (tester) async {
    final services = await makeServices({
      'current_account': {'uuid': 'acct-1', 'email': 'me@example.com'},
      'operations': {'total': 12, 'syncable': 40},
      'qsos': {'total': 1234, 'syncable': 90},
    });
    addTearDown(services.db.close);

    await openSyncPanel(tester, services);

    // `syncable` counts tombstones by design and must not be what's shown.
    expect(find.text('Server: 1,234 QSOs · 12 operations'), findsOneWidget);
    expect(find.text('This device: 0 QSOs · 0 operations'), findsOneWidget);
  });

  testWidgets('a payload without counts says so rather than claiming an empty server log', (tester) async {
    // An account payload from a LoFi that predates these fields. Showing 0
    // here would read as "the server lost everything".
    final services = await makeServices({
      'current_account': {'uuid': 'acct-1', 'email': 'me@example.com'},
    });
    addTearDown(services.db.close);

    await openSyncPanel(tester, services);

    expect(find.text('Server: not available'), findsOneWidget);
  });

  testWidgets('half a payload is not enough — one side alone never stands in for the other', (tester) async {
    // Substituting 0 for the missing half reads as "the account lost every
    // QSO" and would push the operator toward Replace.
    final services = await makeServices({
      'current_account': {'uuid': 'acct-1', 'email': 'me@example.com'},
      'operations': {'total': 12},
    });
    addTearDown(services.db.close);

    await openSyncPanel(tester, services);

    expect(find.text('Server: not available'), findsOneWidget);
    expect(find.text('Server: 0 QSOs · 12 operations'), findsNothing);
  });

  testWidgets('while the fetch is in flight the server line does not claim unavailability', (tester) async {
    // "not available" is a statement about the server, and the request that
    // would answer it has not come back yet. The local line, meanwhile, is a
    // database query that must not wait on the network at all.
    final completer = Completer<Map<String, dynamic>?>();
    final services = await makeServices(null, fetchAccountData: () => completer.future);
    addTearDown(services.db.close);

    await seed(services);
    await openSyncPanel(tester, services);

    expect(find.text('Server: checking…'), findsOneWidget);
    expect(find.text('Server: not available'), findsNothing);
    expect(find.text('This device: 2 QSOs · 1 operation'), findsOneWidget);

    completer.complete({
      'current_account': {'uuid': 'acct-1', 'email': 'me@example.com'},
      'operations': {'total': 12},
      'qsos': {'total': 1234},
    });
    await tester.pumpAndSettle();

    expect(find.text('Server: 1,234 QSOs · 12 operations'), findsOneWidget);
  });

  testWidgets('a fetch that throws still releases the panel instead of stranding it', (tester) async {
    // `syncAccountData` only swallows ExtensionHostException; anything else
    // reaches here. Without the finally, `_loadingSyncAccount` stays true and
    // both lines sit on "checking…" forever — Refresh just re-enters.
    final services = await makeServices(null, fetchAccountData: () async => throw StateError('host is gone'));
    addTearDown(services.db.close);

    await seed(services);

    // The panel deliberately does NOT swallow this — ErrorPolicy is the one
    // place that decides what an escaped exception deserves (see
    // docs/design/error-reporting.md), and in the app the zone guard carries
    // it there. A child zone catches it here so the escape doesn't abort the
    // pump before the assertions below can run.
    final escaped = <Object>[];
    await runZonedGuarded(() => openSyncPanel(tester, services), (e, _) => escaped.add(e));
    expect(escaped.single, isStateError);

    expect(find.text('This device: 2 QSOs · 1 operation'), findsOneWidget);
    expect(find.text('Server: not available'), findsOneWidget);
    expect(find.text('Server: checking…'), findsNothing);
  });
}

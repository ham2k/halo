// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The new-operation flow asks for nothing up front: the station call comes
// from the active profile's callsign and the operation screen opens
// straight into the Activities pane (see HomeView._newOperation). The
// load-bearing guarantees: the profile call seeds `stationCall`, and the
// pane auto-opens exactly once — the operation stream re-emits on every
// QSO/rescore write, and each re-emission re-opening the modal would bury
// the screen under panes. With no profile callsign at all (fresh install,
// no onboarding flow yet), the callsign editor must take the pane's place,
// and its save must land on BOTH the profile and the already-created
// operation — otherwise the operation logs QSOs under an empty identity.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import 'fake_secure_storage.dart';
import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a new operation takes the profile callsign and opens the Activities pane once', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    // What HomeView._newOperation does — no dialog, just the profile call.
    final operation = await services.operations.create(
      stationCall: settings.activeProfile.operatorCall,
    );
    expect(operation.stationCall, 'KI2D');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid, openActivities: true),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ActivitiesPane), findsOneWidget);

    // A later operation write re-emits the stream — the pane must not
    // stack a second copy.
    await services.operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'title': 'Edited'}));
    await tester.pumpAndSettle();
    expect(find.byType(ActivitiesPane), findsOneWidget);

    // Tear the tree down and drain the services' debounce timers (rescore,
    // lookup) so the binding's pending-timer invariant passes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('with no profile callsign, the callsign editor opens instead and its save lands on both', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    // The fake secure storage keeps setOperatorCall's ensureSyncDeviceKey off
    // the (absent-in-tests) keychain platform channel.
    final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    final operation = await services.operations.create(
      stationCall: settings.activeProfile.operatorCall,
    );
    expect(operation.stationCall, '');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid, openActivities: true),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ActivitiesPane), findsNothing);
    expect(find.byType(HaloDialog), findsOneWidget);
    expect(find.descendant(of: find.byType(HaloDialog), matching: find.text('Callsign')), findsWidgets);

    await tester.enterText(find.descendant(of: find.byType(HaloDialog), matching: find.byType(TextField)), 'ki2d');
    await tester.pump();
    expect(find.descendant(of: find.byType(HaloDialog), matching: find.text('ki2d')), findsOneWidget,
        reason: 'the typed callsign should be in the dialog field');
    await tester.tap(find.descendant(of: find.byType(HaloDialog), matching: find.text('Save')));
    await tester.pumpAndSettle();
    expect(find.byType(HaloDialog), findsNothing);

    expect(settings.activeProfile.operatorCall, 'KI2D');
    expect((await services.operations.get(operation.uuid))!.stationCall, 'KI2D');

    // Tear the tree down and drain the services' debounce timers (rescore,
    // lookup) so the binding's pending-timer invariant passes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}

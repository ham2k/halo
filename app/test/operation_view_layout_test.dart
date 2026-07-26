// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation View's adaptive layout (issue #85, docs/design/layouts.md):
// narrow shirt sizes tab through QSOs/Spots/Map/Operation, two-pane sizes
// pin the logging pane left with Info/Spots/Map/Operation tabs on the
// right. The load-bearing guarantees: the arrangement flips LIVE on a
// window resize, and the logging pane's GlobalKey carries its State — a
// half-typed callsign — across the flip instead of rebuilding it.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';
import 'package:ham2k_logger/views/operation_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flips between tabs and split on resize, preserving logging input', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', title: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    // 1000 logical px → L: split layout with the Info tab, logging pane
    // visible on the left, and no QSO-count tab (logging isn't a tab here).
    expect(find.text('INFO'), findsOneWidget);
    expect(find.text('0 QSOs'), findsNothing);
    expect(find.widgetWithText(TextField, 'Their call'), findsOneWidget);

    // Type into the logging pane, then flip to narrow.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 500));

    tester.view.physicalSize = const Size(430, 800);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // 430 → S: the tab arrangement, with the QSO-count tab back — that tab
    // is what tells the two arrangements apart, since the sheet took the
    // Operation tab away and Info is now in both. Index 0 was Info, so tab 0
    // (QSOs = the logging pane) shows, with the in-progress callsign intact
    // (GlobalKey reparenting).
    expect(find.text('0 QSOs'), findsOneWidget);
    expect(find.text('INFO'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'W1AW'), findsOneWidget);

    // And back to wide: split returns, input still intact.
    tester.view.physicalSize = const Size(1000, 800);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('0 QSOs'), findsNothing);
    expect(find.widgetWithText(TextField, 'W1AW'), findsOneWidget);

    // Flip with a NON-ZERO tab selected — the regression case. Wide with
    // Spots selected, then narrow: the tab snaps to QSOs (the logging pane
    // was the always-visible left pane) and the typed callsign survives,
    // because page 0 must be the inflated page for the GlobalKey'd logging
    // subtree to be adopted.
    await tester.tap(find.text('SPOTS'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(430, 800);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'W1AW'), findsOneWidget, reason: 'logging input survives a flip made from the Spots tab');

    // Narrow with Spots selected, then wide: the logging subtree is stolen
    // from the TabBarView's keep-alive bucket into the split's left pane.
    await tester.tap(find.text('SPOTS'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1000, 800);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'W1AW'), findsOneWidget, reason: 'logging input survives a flip made with Spots selected');
    expect(find.text('0 QSOs'), findsNothing, reason: 'back to the split, where logging has its own pane');

    // Tear the tree down and drain the services' debounce timers (rescore,
    // lookup) so the binding's pending-timer invariant passes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('header title shrinks to fit at a narrow width without throwing (issue #182)', (tester) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    const longTitle = 'A Very Long Operation Title That Would Have Been Ellipsized Before';
    final operation = await services.operations.create(stationCall: 'KI2D', title: longTitle);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // shrinkToFitText's floor+ellipsis mechanism is unit-tested directly
    // (platform_chrome_test.dart) — this just proves it mounts cleanly with
    // the real AppBar title style/theme, at the string it's given.
    expect(find.text('KI2D $longTitle'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('closed header has no floating grab pill and keeps its original height', (tester) async {
    // Narrow — the width where the AppBar gets `bottom: tabBar`, so a
    // regression that adds height to the header (the old floating grab
    // pill's job) would show up as the tab row no longer starting exactly
    // at the toolbar's bottom edge (issue #266's original guarantee).
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', title: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('operationHeaderGrab')), findsNothing);
    // The plain "more" hint next to the title/subtitle — not a button of
    // its own, part of the same tap target.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    final toolbarHeight = Theme.of(tester.element(find.byType(AppBar))).appBarTheme.toolbarHeight ?? kToolbarHeight;
    final tabBarTop = tester.getTopLeft(find.byType(TabBar)).dy;
    expect(tabBarTop, closeTo(toolbarHeight, 0.5));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('tapping the header title toggles the operation sheet open and closed', (tester) async {
    // The header's own tap handler always opens — the "toggle" comes from
    // TopModalPaneRoute's own header-area GestureDetector (modal_pane.dart),
    // which pops on a second tap in the same spot while the pane is up. This
    // just pins the resulting end-to-end behavior.
    //
    // Wide enough that the sheet's own (non-scrollable) accordion content
    // fits without overflowing — narrow widths are a pre-existing, separate
    // layout issue in the sheet body, not something this test is about.
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    // Otherwise the 'operation-sheet' onboarding flow auto-opens the sheet
    // on mount (issue #348), which would race with the tap below.
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', title: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(OperationSheet), findsNothing);

    await tester.tap(find.text('N0CALL Test Op'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsOneWidget, reason: 'first tap opens the sheet');

    await tester.tap(find.text('N0CALL Test Op'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing, reason: 'second tap closes it again, rather than opening another');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}

class MockExtensionHost implements ExtensionHost {
  final Map<String, dynamic> mockHookResults;
  const MockExtensionHost(this.mockHookResults);

  @override
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return mockHookResults['$category:$key:$method'];
  }

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final res = mockHookResults['$category:*:$method'];
    return res == null ? const [] : (res as List).cast<Map<String, dynamic>>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ExtensionServiceWithMockHost extends ExtensionService {
  final MockExtensionHost mockHost;
  ExtensionServiceWithMockHost(this.mockHost);

  @override
  ExtensionHost? get host => mockHost;

  @override
  Future<void> start() async {}

  // The real one pushes into the extension host's KV store, which the mock
  // host doesn't implement.
  @override
  Future<void> setSyncCredentials({required String deviceKey, required String operatorCall}) async {}
}

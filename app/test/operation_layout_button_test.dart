// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The header's layout button and the sheet it opens, exercised through the
// real view: the button exists only where there is an arrangement to edit,
// and what it opens lists the panes the dock is actually holding. The pieces
// either side of this are unit-tested (dock_layout_test, layout_sheet_test);
// what only the real view can prove is that they are wired to each other.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/layout_sheet.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  Future<HaLoServices> servicesWith(WidgetTester tester, {required bool layoutsExperiment}) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    // Suppress the operation sheet's first-run auto-open, which would
    // otherwise cover the header this test is about.
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    if (layoutsExperiment) await settings.setExperimentEnabled('layouts', true);
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    return HaLoServices(db, settings, extensions: extensions);
  }

  /// The view's drift subscriptions schedule their cleanup on a timer, which
  /// the test framework reports as a leak unless it is allowed to run — so
  /// every test here takes the view down and lets that timer fire.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Future<void> pumpOperation(WidgetTester tester, HaLoServices services) async {
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: OperationView(services: services, operationUuid: operation.uuid)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the dock layout offers a layout button, and it opens the sheet on the panes in the view',
      (tester) async {
    // Wide enough to be two-pane, which is the only width the dock renders at.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = await servicesWith(tester, layoutsExperiment: true);
    await pumpOperation(tester, services);

    final button = find.widgetWithIcon(IconButton, MdiIcons.viewDashboard);
    expect(button, findsOneWidget);

    // Faded until hovered, but hit-testable throughout — a click into the
    // zone reveals it on the way in, and a screen reader has to reach it.
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(LayoutSheet), findsOneWidget);
    // The default arrangement's four panes, read from the live dock tree
    // rather than from a list the sheet keeps of its own.
    final sheet = tester.widget<LayoutSheet>(find.byType(LayoutSheet));
    expect(sheet.panels.map((p) => p.id), ['logging', 'info', 'spots', 'map']);
    // NO settings controls, though the logging pane does have settings.
    // Its `settingsTarget` opens the app's own declared settings for that
    // pane — user settings, reachable from the pane's own tab. This sheet is
    // about the LAYOUT, and a gear here would say the two are the same kind
    // of thing. Only a panel's own config form (an extension's) belongs.
    expect(sheet.panels.where((p) => p.openSettings != null), isEmpty);

    await unmount(tester);
  });

  testWidgets('without the layouts experiment the header has no layout button', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = await servicesWith(tester, layoutsExperiment: false);
    await pumpOperation(tester, services);

    // The fixed layout has no arrangement to edit, so the button would open
    // a sheet whose remove and reset mean nothing.
    expect(find.widgetWithIcon(IconButton, MdiIcons.viewDashboard), findsNothing);

    await unmount(tester);
  });
}

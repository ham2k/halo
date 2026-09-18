// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two info modals a narrow Operation View opens: the Call Info detail
// (tap the compact call-info area) and the operation's own stats (tap a day
// header in the QSO list). Both panels are ListViews, so a modal pane that
// wraps them in ITS scroll view hands them unbounded height and they lay out
// to nothing — the pane opens blank, header and all, with no exception to say
// so. These tests therefore assert content INSIDE the panel, never that a
// route was pushed: pushing the route was never what broke.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/call_info_panel.dart';
import 'package:ham2k_logger/views/operation/information_panel.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;

  /// [dock], when given, puts the view on an arrangement holding exactly
  /// those modules — the operator's own arrangement, which need not include
  /// the Info pane at all.
  Future<void> buildServices({List<String>? dock}) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    // Otherwise the operation sheet is up over the view on arrival and its
    // barrier eats the first tap anywhere — which reads exactly like a dead
    // tap target, the failure these tests exist to catch.
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    if (dock != null) {
      await settings.setLayoutData(
        LayoutKeys.operationDock,
        DockSplit(Axis.horizontal, [
          DockGroup([dock.first]),
          DockGroup(dock.sublist(1)),
        ], [2, 1]).toJson(),
      );
    }
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    services = HaLoServices(db, settings, extensions: extensions);
    operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
  }

  /// [width] in logical pixels: below ShirtSize.sMax is the single-pane
  /// arrangement, the only one where either of these is a modal at all;
  /// above it the tap reveals the Info pane in place instead.
  Future<void> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The view's QSO stream leaves drift's zero-duration close timer pending at
  /// teardown; unmounting and letting the fake clock advance runs it.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('the compact call-info area opens the Call Info detail, with its content in it', (tester) async {
    await buildServices();
    await pumpAt(tester, 430);

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pumpAndSettle();
    expect(find.byType(CallInfoPanel), findsNothing, reason: 'the detail is a modal here, not part of the layout');

    // The person icon is the stable handle on the compact area — the lines
    // beside it depend on what the lookup returned, which is nothing here.
    await tester.tap(find.byIcon(MdiIcons.account));
    await tester.pumpAndSettle();

    expect(find.byType(CallInfoPanel), findsOneWidget);
    // Content, not just the widget: a collapsed ListView is still "found".
    expect(find.descendant(of: find.byType(CallInfoPanel), matching: find.text('QRZ')), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a day header opens the operation stats, with its content in it', (tester) async {
    await buildServices();
    await services.qsos.add(operation.uuid, {
      'their': {'call': 'K1ABC'},
      'band': '20m',
      'mode': 'SSB',
    });
    await pumpAt(tester, 430);

    await tester.tap(find.descendant(of: find.byType(DayHeaderRow), matching: find.byType(InkWell)));
    await tester.pumpAndSettle();

    expect(find.byType(InformationPanel), findsOneWidget);
    expect(
      find.descendant(of: find.byType(InformationPanel), matching: find.text('Operation Stats')),
      findsOneWidget,
    );
    // Never the call detail: the header stands for the operation, not for
    // whichever QSO the tap before it happened to select.
    expect(find.byType(CallInfoPanel), findsNothing);

    await unmount(tester);
  });

  testWidgets('on wide the day header reveals the Info pane in place, no modal', (tester) async {
    await buildServices();
    await services.qsos.add(operation.uuid, {
      'their': {'call': 'K1ABC'},
      'band': '20m',
      'mode': 'SSB',
    });
    await pumpAt(tester, 1000);

    // Hit-testable, not merely found: the dock keeps every pane of a group
    // mounted, so InformationPanel is in the tree whichever tab is on top.
    final infoOnTop = find.byType(InformationPanel).hitTestable();

    // Off the Info tab first, so a reveal has somewhere to move from.
    await tester.tap(find.text(AppLocale.en.buildSync().operation.tabs.spots));
    await tester.pumpAndSettle();
    expect(infoOnTop, findsNothing);

    await tester.tap(find.descendant(of: find.byType(DayHeaderRow), matching: find.byType(InkWell)));
    await tester.pumpAndSettle();

    // The pane in place, not a route over it: the wide layout already holds
    // the Info pane, and a modal on top of it would be a second copy.
    expect(infoOnTop, findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a wide layout with no Info pane falls back to the modal, not a dead tap', (tester) async {
    // The operator's own arrangement: `revealModule` no-ops on a module that
    // isn't in the dock, so a wide branch that assumed it had handled the tap
    // would spend the header's splash on nothing at all.
    await buildServices(dock: const ['logging', 'spots']);
    await services.qsos.add(operation.uuid, {
      'their': {'call': 'K1ABC'},
      'band': '20m',
      'mode': 'SSB',
    });
    await pumpAt(tester, 1000);

    await tester.tap(find.descendant(of: find.byType(DayHeaderRow), matching: find.byType(InkWell)));
    await tester.pumpAndSettle();

    expect(find.byType(InformationPanel), findsOneWidget);
    expect(
      find.descendant(of: find.byType(InformationPanel), matching: find.text('Operation Stats')),
      findsOneWidget,
    );

    await unmount(tester);
  });
}

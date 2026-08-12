// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Home is dock-driven at two-pane widths and a plain column below them. Both
// halves of that are load-bearing and neither throws when it breaks:
//
//  - the dock's tree names no widths, so applying it on a phone would hand a
//    360px window a two-thirds list and a 120px branding column. It renders
//    perfectly happily; it is just wrong, and only a width-specific assertion
//    catches it.
//  - the panel catalog is one registry shared with the Operation view. Nothing
//    stops an Operation List pane being offered inside an operation except the
//    view scope, and a pane placed there would render against an operation it
//    knows nothing about.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/home_navigation_rail.dart';
import 'package:ham2k_logger/views/home_view.dart';

Future<HaLoServices> _services() async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return HaLoServices(db, settings);
}

Future<void> _pumpHome(WidgetTester tester, HaLoServices services, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Through the shell the ROOT uses, not HomeView bare: the rail is a sibling
  // of the window's chrome now, so a test that pumped the view alone would be
  // exercising a composition that does not ship.
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(home: HomeRailShell(
      services: services,
      routes: HomeView(services: services),
    )),
  ));

  // Home is `MaterialApp.home` and arms two timers on mount — the FAB's
  // settle deadline and the first-run nudge's wait. A test that simply ends
  // leaves them pending, and the binding asserts "a Timer is still pending
  // even after the widget tree was disposed", which reads as the test hanging
  // rather than as the teardown it actually is. Unmount, then let their
  // wall-clock run out.
  addTearDown(() async {
    await _endOfTest(tester);
  });
  // Bounded, not `pumpAndSettle`: see home_navigation_rail_test for why.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Unmounts the tree and lets Home's timers run out.
///
/// Called at the END OF EACH TEST BODY, never from `addTearDown`: flutter_test
/// asserts "a Timer is still pending even after the widget tree was disposed"
/// as part of running the body, which is BEFORE any tearDown callback gets a
/// turn — so a drain registered there is too late to prevent the very thing it
/// is for.
///
/// Stepped, because the timers CHAIN: Home's nudge wait fires at 5s and only
/// then mounts the widget that arms its own ~9.7s settle, so one long advance
/// past the first deadline still leaves the second pending.
Future<void> _endOfTest(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 6));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the default arrangement is the layout Home had before it was arrangeable', (tester) async {
    final services = await _services();
    await _pumpHome(tester, services, size: const Size(1200, 800));

    expect(find.byType(DockLayoutView), findsOneWidget, reason: 'two-pane Home is the dock');
    expect(find.byType(OperationListPanel), findsOneWidget);
    expect(find.byType(HomeQuickLookup), findsOneWidget);

    final list = tester.getRect(find.byType(OperationListPanel));
    final lookup = tester.getRect(find.byType(HomeQuickLookup));
    expect(
      lookup.top,
      greaterThanOrEqualTo(list.bottom - 1),
      reason: 'Quick Lookup sits BELOW the arrangement, as it always has — it is chrome now, not a pane in it',
    );
    expect(
      lookup.right,
      greaterThan(list.right),
      reason: 'and it spans the whole layer beside the rail, not the column the list happens to be in',
    );
    expect(
      list.right,
      lessThan(tester.getSize(find.byType(HomeView)).width * 0.9),
      reason: 'the branding column takes the right third; a list spanning the window means the default lost a pane',
    );
    await _endOfTest(tester);
  });

  testWidgets('a phone gets the column, not the dock', (tester) async {
    final services = await _services();
    await _pumpHome(tester, services, size: const Size(400, 800));

    expect(
      find.byType(DockLayoutView),
      findsNothing,
      reason: 'the dock tree names no widths, so on a phone it would draw the two-pane split at 400px',
    );
    expect(find.byType(OperationListPanel), findsOneWidget);
    expect(find.byType(HomeQuickLookup), findsOneWidget);
    expect(
      find.byIcon(MdiIcons.viewDashboard),
      findsNothing,
      reason: 'and no Edit Layout button, since there is no arrangement on screen to edit',
    );
    await _endOfTest(tester);
  });

  testWidgets('a rearranged Home is read back on the next launch', (tester) async {
    final services = await _services();
    // Version on the LEFT and the list on the right — the reverse of the
    // default, so reading the default back would be unmistakable. The retired
    // lookup module rides along: an upgrading operator's saved arrangement
    // still names it, and it has to be dropped without taking the rest with it.
    await services.settings.setLayoutData(
      LayoutKeys.homeDock,
      DockSplit(Axis.horizontal, [
        DockGroup([HomeView.versionPanelId]),
        DockGroup([HomeView.operationsPanelId, HomeView.retiredLookupPanelId]),
      ], [1, 1]).toJson(),
    );

    await _pumpHome(tester, services, size: const Size(1200, 800));

    final version = tester.getRect(find.byType(HomeView));
    final list = tester.getRect(find.byType(OperationListPanel));
    expect(
      list.left,
      greaterThan(version.width * 0.4),
      reason: 'the saved arrangement put the list on the RIGHT; finding it on the left means the default won',
    );
    expect(
      find.byType(HomeQuickLookup),
      findsOneWidget,
      reason: 'and exactly one Quick Lookup — the retired pane dropped, the chrome one still there',
    );
    await _endOfTest(tester);
  });

  testWidgets('Home and Operation do not offer each other their panels', (tester) async {
    final services = await _services();
    await _pumpHome(tester, services, size: const Size(1200, 800));

    final homeCatalog = services.panels.catalogFor(PanelViews.home).map((p) => p.id).toSet();
    expect(
      homeCatalog,
      containsAll([HomeView.operationsPanelId, HomeView.versionPanelId]),
    );
    expect(
      homeCatalog.intersection({'logging', 'info', 'spots', 'map'}),
      isEmpty,
      reason: 'a logging pane on Home has no operation to log into',
    );

    final operationCatalog = services.panels.catalogFor(PanelViews.operation).map((p) => p.id).toSet();
    expect(
      operationCatalog.intersection(homeCatalog),
      isEmpty,
      reason: 'and an Operation List pane inside an operation is a pane that has nothing to do with the one it is in',
    );
    await _endOfTest(tester);
  });

  testWidgets('an extension panel names no view, so both offer it', (tester) async {
    final services = await _services();
    services.panels.registerNative(const PanelDefinition(
      id: 'nativeHomeOnly',
      title: 'Home only',
      source: PanelSource.native,
      views: {PanelViews.home},
    ));
    // What `fromExtensionEntry` produces: no `views`, so no view scope.
    const anywhere = PanelDefinition(
      id: 'ext:dash:clock',
      title: 'Clock',
      source: PanelSource.extension,
    );
    expect(anywhere.availableIn(PanelViews.home), isTrue);
    expect(anywhere.availableIn(PanelViews.operation), isTrue);
    await _endOfTest(tester);
  });
}

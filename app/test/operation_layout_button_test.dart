// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The header's layout controls and the sheet the plus opens, exercised
// through the real view: the controls exist only where there is an
// arrangement to edit, going into edit mode is what the button does, and an
// edit reaches storage only when it is saved. The pieces either side of this
// are unit-tested (dock_layout_test, layout_sheet_test); what only the real
// view can prove is that they are wired to each other.

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
  final t = AppLocale.en.buildSync().operation.layout;
  final tabs = AppLocale.en.buildSync().operation.tabs;

  Future<HaLoServices> servicesWith(WidgetTester tester, {required bool layoutCustomization}) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    // Suppress the operation sheet's first-run auto-open, which would
    // otherwise cover the header this test is about.
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    if (layoutCustomization) await settings.setLayoutCustomization(true);
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

  Future<void> pumpWide(WidgetTester tester, HaLoServices services) async {
    // Wide enough to be two-pane, which is the only width the dock renders at.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: OperationView(services: services, operationUuid: operation.uuid)),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> startEditing(WidgetTester tester) async {
    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.viewDashboard));
    await tester.pumpAndSettle();
  }

  Future<void> openAddSheet(WidgetTester tester) async {
    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.plus));
    await tester.pumpAndSettle();
  }

  /// Drops the pane named [tabLabel] on the dock's delete target.
  ///
  /// Removing IS a drag — there is no delete button on a pane, deliberately —
  /// so a test cannot shortcut it with a tap. The target only exists while
  /// something is in the air, hence the two-phase gesture: start, pump so the
  /// circle mounts, then aim at it.
  Future<void> dragToDelete(WidgetTester tester, String tabLabel) async {
    final gesture = await tester.startGesture(tester.getCenter(find.text(tabLabel).first));
    // Far enough to arm the target: it stays unmounted under a pointer that
    // has barely moved, so a fumbled click cannot delete a pane.
    await gesture.moveBy(const Offset(0, 90));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byIcon(MdiIcons.trashCanOutline)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  LayoutSheet sheetOf(WidgetTester tester) => tester.widget<LayoutSheet>(find.byType(LayoutSheet));

  testWidgets('the layout button goes straight into editing, and becomes the edit controls', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    // Always visible, not revealed on hover: an operator who has asked for a
    // customizable layout has asked to see the way into it.
    final button = find.widgetWithIcon(IconButton, MdiIcons.viewDashboard);
    expect(button, findsOneWidget);
    expect(find.text(t.saveLayout), findsNothing);

    await startEditing(tester);

    // No sheet in the way — what an operator wants when they reach for this
    // is to move a pane.
    expect(find.byType(LayoutSheet), findsNothing);
    expect(find.text(t.saveLayout), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, MdiIcons.plus), findsOneWidget);
    expect(find.byIcon(MdiIcons.undoVariant), findsOneWidget);
    expect(button, findsNothing, reason: 'the button became Save Layout — it is the same control');

    await unmount(tester);
  });

  testWidgets('an edit is a draft: nothing reaches settings until Save Layout', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);
    final settings = services.settings;

    await startEditing(tester);
    expect(settings.layoutData(LayoutKeys.operationDock), isNull, reason: 'entering edit mode writes nothing');

    await dragToDelete(tester, tabs.info);
    expect(settings.layoutData(LayoutKeys.operationDock), isNull,
        reason: 'a draft that reached storage is a discard button that promises nothing');

    await tester.tap(find.text(t.saveLayout));
    await tester.pumpAndSettle();
    expect(DockNode.fromJson(settings.layoutData(LayoutKeys.operationDock))!.collectModules(),
        ['logging', 'spots', 'map']);
    expect(find.text(t.saveLayout), findsNothing, reason: 'saving leaves edit mode');

    await unmount(tester);
  });

  testWidgets('discarding puts the arrangement back where editing found it, and ends the edit', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    await startEditing(tester);
    await dragToDelete(tester, tabs.info);
    expect(find.text(tabs.info), findsNothing, reason: 'the pane went');

    await tester.tap(find.byIcon(MdiIcons.undoVariant));
    await tester.pumpAndSettle();

    // Discard is the cancel to Save Layout's commit: every way out of edit
    // mode keeps everything or keeps nothing.
    expect(find.text(t.saveLayout), findsNothing, reason: 'discarding ends the edit');
    expect(find.widgetWithIcon(IconButton, MdiIcons.viewDashboard), findsOneWidget);
    expect(services.settings.layoutData(LayoutKeys.operationDock), isNull);

    // The pane it dropped is back. Asserted through what is left to ADD
    // rather than through the band's trash: which pane a group is showing is
    // state, not arrangement, so it does not come back with the discard —
    // that group is still on Spots, and its band names Spots.
    await startEditing(tester);
    await openAddSheet(tester);
    expect(sheetOf(tester).available, isEmpty, reason: 'every pane is in the view again');

    await unmount(tester);
  });

  testWidgets('the plus lists what can be added, and adding puts it back', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    await startEditing(tester);
    await openAddSheet(tester);
    // Nothing to add with the whole default arrangement in place. The sheet
    // still renders — one that draws nothing at all reads as one that failed.
    expect(sheetOf(tester).available, isEmpty);
    expect(find.text(t.nothingToAdd), findsOneWidget);
    await tester.tap(find.byIcon(MdiIcons.check));
    await tester.pumpAndSettle();

    await dragToDelete(tester, tabs.info);
    await openAddSheet(tester);

    // A pane taken out has to have a way back that isn't Reset Layout.
    expect(sheetOf(tester).available.map((p) => p.id), ['info']);
    sheetOf(tester).onAdd!('info');
    await tester.pumpAndSettle();
    expect(sheetOf(tester).available, isEmpty, reason: 'and once back, it is no longer on offer');

    await unmount(tester);
  });

  testWidgets('a pane taken out and put back in the same edit keeps what was in it', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await services.settings.setLayoutData(LayoutKeys.operationPaneOptions, {
      'info': {'title': 'Chart'},
    });
    await pumpWide(tester, services);

    await startEditing(tester);
    // 'Chart', not the built-in name: the seeded title is what the tab reads
    // as, which is the override being applied.
    await dragToDelete(tester, 'Chart');
    await openAddSheet(tester);
    sheetOf(tester).onAdd!('info');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(MdiIcons.check));
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.saveLayout));
    await tester.pumpAndSettle();

    // The removal's forget is DEFERRED to the save, and the id is free in the
    // meantime — PanelService hands the lowest one back out on purpose. So a
    // save that replays the removals it was told about, rather than the ones
    // still true of what it is saving, empties a pane the operator can see.
    expect(services.settings.layoutData(LayoutKeys.operationPaneOptions), containsPair('info', anything));

    await unmount(tester);
  });

  testWidgets("a removed pane's options do not reach storage", (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await services.settings.setLayoutData(LayoutKeys.operationPaneOptions, {
      'info': {'title': 'Chart'},
    });
    await pumpWide(tester, services);

    await startEditing(tester);
    await dragToDelete(tester, 'Chart');
    await tester.tap(find.text(t.saveLayout));
    await tester.pumpAndSettle();

    // Serialized BEFORE the forget, the map would carry the gone pane's title
    // to disk — where the next pane handed that id inherits it, which is the
    // whole thing forgetting a removed pane exists to stop.
    expect(
      (services.settings.layoutData(LayoutKeys.operationPaneOptions) as Map?)?.containsKey('info') ?? false,
      isFalse,
    );

    await unmount(tester);
  });

  testWidgets('the sheet\'s own header offers no plus, and the guard holds anyway', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    await startEditing(tester);
    expect(find.widgetWithIcon(IconButton, MdiIcons.plus), findsOneWidget);
    await openAddSheet(tester);

    // The button that opened the sheet is not redrawn into it: pressing it
    // again is refused, and an enabled, focusable, announced control that
    // does nothing is worse than one that is not there. Discard and Save are
    // what the operator needs up there.
    expect(find.widgetWithIcon(IconButton, MdiIcons.plus), findsNothing);
    expect(find.text(t.saveLayout), findsOneWidget);

    // And the guard behind it still refuses, so no other caller can stack one.
    final view = tester.state(find.byType(OperationView));
    // ignore: avoid_dynamic_calls
    await (view as dynamic).openAddPanelSheetForTest();
    await tester.pumpAndSettle();
    expect(find.byType(LayoutSheet), findsOneWidget);

    await tester.tap(find.byIcon(MdiIcons.check));
    await tester.pumpAndSettle();
    expect(find.byType(LayoutSheet), findsNothing, reason: 'one open, one close');

    await unmount(tester);
  });

  testWidgets('narrowing the window mid-edit gives the header back, and widening returns to the draft', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    await startEditing(tester);
    await dragToDelete(tester, tabs.info);
    expect(find.text(t.viewName), findsOneWidget);

    // Save and Discard are only emitted where there is a dock to edit, so a
    // header that stays dressed for editing past that point has no way out:
    // no controls, the operation's title replaced, and its setup sheet
    // unreachable behind a tap that does nothing.
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    expect(find.text(t.viewName), findsNothing);
    expect(find.textContaining('KI2D'), findsWidgets);

    // The draft is state, not settings — it is still there to come back to.
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(find.text(t.saveLayout), findsOneWidget);
    expect(find.text(tabs.info), findsNothing, reason: 'the edit survived the trip');

    await unmount(tester);
  });

  testWidgets('leaving edit mode from the sheet takes the sheet with it', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    await startEditing(tester);
    await openAddSheet(tester);
    await tester.tap(find.text(t.saveLayout));
    await tester.pumpAndSettle();

    // Left open past the exit, every control in it writes straight to
    // settings the moment it is pressed — and the Discard that was beside
    // them is gone. Reset Layout right after a Save would destroy the
    // arrangement that had just been committed.
    expect(find.byType(LayoutSheet), findsNothing);

    await unmount(tester);
  });

  testWidgets('turning customization off mid-edit discards the draft even with no dock mounted', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    await startEditing(tester);
    await dragToDelete(tester, tabs.info);

    // Narrow first: the dock is two-pane only, so this is exactly the state
    // the discard has to work in — and a revert that needs a live dock bails
    // here, leaving edit mode on and the draft alive to reappear later.
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    await services.settings.setLayoutCustomization(false);
    await tester.pumpAndSettle();
    await services.settings.setLayoutCustomization(true);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(find.text(t.saveLayout), findsNothing, reason: 'the edit ended with the setting');
    expect(find.text(tabs.info), findsOneWidget, reason: 'and the pane it dropped came back');

    await unmount(tester);
  });

  testWidgets('the sheet outliving the dock does not act on it', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    await startEditing(tester);
    await dragToDelete(tester, tabs.info);
    await openAddSheet(tester);

    // The sheet is a route and survives the resize; the dock's State does
    // not. A call on the disposed one is a setState-after-dispose, which
    // takes the whole view down to an error tile mid-edit.
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    sheetOf(tester).onAdd!('info');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });

  testWidgets("a pane's layout options can remove it, and the last one cannot be removed", (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    await startEditing(tester);
    // The drag onto the delete target is the usual way, and it cannot be made
    // with a keyboard or a screen reader. Without this the only pointer-free
    // route out of a pane is Reset Layout, which drops the whole arrangement
    // to be rid of one.
    // .first is a PANE's — the view's own copy of this glyph is in the app
    // bar, which Scaffold builds after the body. The view's dialog is the one
    // with no Remove in it, which is the other half of what this asserts.
    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.viewDashboardEdit).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.removePane));
    await tester.pumpAndSettle();

    expect(find.byType(LayoutSheet), findsNothing);
    await openAddSheet(tester);
    expect(sheetOf(tester).available, isNotEmpty, reason: 'a pane left the arrangement');
    await tester.tap(find.byIcon(MdiIcons.check));
    await tester.pumpAndSettle();

    // The VIEW's own options are one level up and have no pane to remove;
    // offering one there would be a button with nothing to act on.
    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.viewDashboardEdit).last);
    await tester.pumpAndSettle();
    expect(find.text(t.resetOptions), findsOneWidget, reason: 'the view dialog IS open');
    expect(find.text(t.removePane), findsNothing);

    await unmount(tester);
  });

  testWidgets('the last pane standing offers no Remove', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    // One pane, which is the floor `removeModule` enforces — an empty dock
    // has no tab left to drag anything back with. A Remove here would close
    // the dialog and do nothing, with no way to tell the operator why.
    await services.settings.setLayoutData(LayoutKeys.operationDock, DockGroup(['logging']).toJson());
    await pumpWide(tester, services);

    await startEditing(tester);
    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.viewDashboardEdit).first);
    await tester.pumpAndSettle();
    expect(find.text(t.resetOptions), findsOneWidget, reason: "the PANE's dialog is open");
    expect(find.text(t.removePane), findsNothing);

    await unmount(tester);
  });

  testWidgets("the view's Restore Defaults puts the ARRANGEMENT back, not just the options", (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    await startEditing(tester);
    await dragToDelete(tester, tabs.info);
    expect(find.text(tabs.info), findsNothing);

    // The view's own options, one level up from a pane's.
    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.viewDashboardEdit).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.resetOptions));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, t.resetOptions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocale.en.buildSync().common.done));
    await tester.pumpAndSettle();

    // Restoring defaults means the view the operator started with. Clearing
    // the options and leaving the arrangement alone leaves them half-way
    // between two layouts, hunting a second control to finish the job.
    expect(find.text(tabs.info), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('editing names the VIEW in the header, and offers the view its own options', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await pumpWide(tester, services);

    // Ordinarily the header is about the operation in the view.
    expect(find.textContaining('KI2D'), findsWidgets);
    expect(find.text(t.viewName), findsNothing);

    await startEditing(tester);

    // While editing it is about the VIEW: what is being rearranged belongs to
    // the view, and outlives this operation and every other one.
    expect(find.text(t.viewName), findsOneWidget);
    // The same glyph a pane's options carry — the same kind of thing one
    // level up. What tells them apart is where they are.
    expect(find.widgetWithIcon(IconButton, MdiIcons.viewDashboardEdit), findsWidgets);

    await unmount(tester);
  });

  testWidgets('a view-level size override wraps the whole dock', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    await services.settings.setLayoutData(LayoutKeys.operationViewOptions, {'fontScale': 'larger'});

    // Every pane inherits it — a pane that names no size of its own is inside
    // the view's scope, not beside it.
    await pumpWide(tester, services);
    expect(tester.takeException(), isNull);
    expect(
      find.ancestor(of: find.byType(DockLayoutView), matching: find.byType(SubtreeUiScale)),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('a pane with size overrides renders, rather than mounting forever', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: true);
    // Both overrides at once, which is what a pane gets after a trip through
    // Advanced Options.
    await services.settings.setLayoutData(LayoutKeys.operationPaneOptions, {
      'logging': {'fontScale': 'smaller', 'density': 'dense'},
    });

    // The wrappers close over a final copy of what they wrap. A builder that
    // read the variable it is being assigned to would resolve, at BUILD time,
    // to ITSELF — becoming its own child, and mounting until the stack goes.
    // It does not throw where the mistake is: the first sign is a stack
    // overflow a thousand mounts later, inside Flutter's own error
    // formatting, naming nothing in this file.
    await pumpWide(tester, services);
    expect(tester.takeException(), isNull);
    expect(find.byType(DockLayoutView), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('without layout customization the header has no layout controls', (tester) async {
    final services = await servicesWith(tester, layoutCustomization: false);
    await pumpWide(tester, services);

    // The fixed layout has no arrangement to edit, so the button would open
    // an editor over panes that cannot move.
    expect(find.widgetWithIcon(IconButton, MdiIcons.viewDashboard), findsNothing);

    await unmount(tester);
  });
}

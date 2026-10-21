// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Named layouts and layout files, through the real Operation view
// (docs/design/layouts.md § Named layouts, § Layout files). Every rule here is
// about two layouts that must not leak into each other: an edit, a pane's
// stored settings, or an id handed out twice is a layout changing behind the
// operator's back in a place they are not looking.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/dock_host.dart';
import 'package:ham2k_logger/views/dock_layouts/layout_file.dart';
import 'package:ham2k_logger/views/dock_layouts/layout_menu.dart';
import 'package:ham2k_logger/views/dock_layouts/view_layouts.dart';
import 'package:ham2k_logger/views/home_view.dart';
import 'package:ham2k_logger/views/operation/clock/clock_panel.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  Future<HaLoServices> servicesWith(WidgetTester tester, {bool experiment = true}) async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    await settings.setExperimentEnabled('layouts', experiment);
    // A clock instance holding a zone of its own: the kind of pane whose
    // contents belong to ONE placement, which is what every leak below is
    // about.
    await settings.setLayoutData(
      LayoutKeys.operationDock,
      DockSplit(
        Axis.horizontal,
        [
          DockGroup(['logging']),
          DockGroup(['$clockPanelId#1']),
        ],
        [2, 1],
      ).toJson(),
    );
    await zone(services, '$clockPanelId#1', 'Asia/Tokyo');
    return services;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Future<DockHost> pumpWide(WidgetTester tester, HaLoServices services) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(OperationView)) as DockHost;
  }

  List<String> storedModules(HaLoServices services, String key) => DockNode.fromJson(services.settings.layoutData(key))?.collectModules() ?? const [];

  testWidgets('the switcher is the experiment\'s, and outside the editor only once there is a choice', (tester) async {
    final services = await servicesWith(tester, experiment: false);
    var host = await pumpWide(tester, services);
    host.startLayoutEditing();
    await tester.pumpAndSettle();
    expect(find.byType(LayoutSwitcherButton), findsNothing);
    await unmount(tester);

    await services.settings.setExperimentEnabled('layouts', true);
    host = await pumpWide(tester, services);
    // One layout: nothing to switch to, and the editor is where a second is
    // made — so the editor has to carry it even then.
    expect(find.byType(LayoutSwitcherButton), findsNothing);
    host.startLayoutEditing();
    await tester.pumpAndSettle();
    expect(find.byType(LayoutSwitcherButton), findsOneWidget);
    host.revertLayout();

    await host.duplicateLayout(ViewLayouts.defaultId, 'Copy');
    await tester.pumpAndSettle();
    expect(find.byType(LayoutSwitcherButton), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the sheet: Edit only on the layout on screen, Delete only in Edit, and only with another to fall back to', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    final t = AppLocale.en.buildSync().operation.layout.layouts;
    Future<void> openSheet() async {
      await tester.tap(find.byType(LayoutSwitcherButton));
      await tester.pumpAndSettle();
    }

    // The only layout, so the switcher is the editor's.
    host.startLayoutEditing();
    await tester.pumpAndSettle();
    await openSheet();
    expect(find.widgetWithText(TextButton, t.edit), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, t.edit));
    await tester.pumpAndSettle();
    // The last layout: a view has to draw something, and a Delete that is
    // refused after the press is worse than none.
    expect(find.text(AppLocale.en.buildSync().common.delete), findsNothing);
    await tester.tap(find.text(AppLocale.en.buildSync().common.cancel));
    await tester.pumpAndSettle();

    // New, duplicating the current one — the default choice.
    await tester.tap(find.text(t.menuNew));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(HaloDialog), matching: find.byType(TextField)), 'Contest');
    await tester.pump();
    await tester.tap(find.text(t.create));
    await tester.pumpAndSettle();
    expect(host.layoutName(host.viewLayouts.activeLayout), 'Contest');
    expect(host.dockSpec!.collectModules(), ['logging', '$clockPanelId#2'], reason: 'duplicated, with its own clock');

    await openSheet();
    // Two rows, and still one Edit: it belongs to the row on screen.
    expect(find.text('Contest'), findsWidgets);
    expect(find.widgetWithText(TextButton, t.edit), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, t.edit));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocale.en.buildSync().common.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppLocale.en.buildSync().common.delete));
    await tester.pumpAndSettle();
    expect(host.viewLayouts.layouts.map((l) => l.id), [ViewLayouts.defaultId]);
    expect(host.dockSpec!.collectModules(), ['logging', '$clockPanelId#1']);
    await unmount(tester);
  });

  testWidgets('editing: the same switcher, then a bare Save as the rightmost control', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    await host.duplicateLayout(ViewLayouts.defaultId, 'Other');
    host.switchLayout(ViewLayouts.defaultId);
    await host.editLayout(ViewLayouts.defaultId, name: 'Contest Station');
    await tester.pumpAndSettle();
    final outside = tester.getSize(find.byType(LayoutSwitcherButton));
    host.startLayoutEditing();
    await tester.pumpAndSettle();

    final save = find.bySemanticsLabel(AppLocale.en.buildSync().operation.layout.saveLayout);
    final name = find.text('Contest Station');
    expect(save, findsOneWidget);
    expect(
      find.descendant(of: find.byType(LayoutSwitcherButton), matching: name),
      findsOneWidget,
      reason: 'the edit says which layout it saves into',
    );
    expect(tester.getSize(find.byType(LayoutSwitcherButton)), outside, reason: 'the same control as outside the edit, not a label of its own');
    expect(find.text(AppLocale.en.buildSync().operation.layout.saveLayout), findsNothing, reason: 'Save carries no label');
    expect(tester.getCenter(name).dx, lessThan(tester.getCenter(save).dx));
    // Rightmost of the header's own buttons: nothing after it but the window
    // caption spacer.
    final buttons = find
        .descendant(of: find.byType(AppBar), matching: find.byType(IconButton))
        .evaluate()
        .map((e) => tester.getCenter(find.byWidget(e.widget)).dx);
    expect(tester.getCenter(save).dx, buttons.reduce(math.max));

    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(host.layoutEditing, isFalse);
    await unmount(tester);
  });

  testWidgets('a phone\'s editor header fits its controls, the layouts icon among them', (tester) async {
    final services = await servicesWith(tester);
    await services.settings.setLayoutData(LayoutKeys.operationNarrowDock, DockGroup(['logging']).toJson());
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final host = tester.state(find.byType(OperationView)) as DockHost;
    await host.editLayout(ViewLayouts.defaultId, name: 'A rather long layout name for a phone');
    host.startLayoutEditing();
    await tester.pumpAndSettle();
    // An overflow here is a header whose Save is pushed off the edge.
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(AppLocale.en.buildSync().operation.layout.saveLayout).hitTestable(), findsOneWidget);
    final switcher = find.bySemanticsLabel(AppLocale.en.buildSync().operation.layout.layouts.switcherLabel(name: 'A rather long layout name for a phone'));
    expect(switcher.hitTestable(), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('switching from the editor asks about a changed draft, and the editor follows to the other layout', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    final l = AppLocale.en.buildSync();
    await host.createLayout('Contest');
    await tester.pumpAndSettle();
    final contestKey = host.dockKeys.spec;

    Future<void> pickRow(String name) async {
      await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text(name)));
      await tester.pumpAndSettle();
    }

    Future<void> switchTo(String name) async {
      await tester.tap(find.byType(LayoutSwitcherButton));
      await tester.pumpAndSettle();
      await pickRow(name);
    }

    // Unchanged: nothing to ask about.
    host.startLayoutEditing();
    await tester.pumpAndSettle();
    await switchTo(l.operation.layout.layouts.defaultName);
    expect(find.text(l.operation.layout.layouts.leaveEditTitle(name: 'Contest')), findsNothing);
    expect(host.viewLayouts.active, ViewLayouts.defaultId);
    expect(host.layoutEditing, isTrue, reason: 'moving to another layout from the editor is still editing');

    host.dockKey.currentState!.addModule('map');
    await switchTo('Contest');
    // Cancel stays put, with the draft intact and the sheet still up.
    await tester.tap(find.text(l.common.cancel));
    await tester.pumpAndSettle();
    expect(host.viewLayouts.active, ViewLayouts.defaultId);
    expect(host.dockSpec!.collectModules(), contains('map'));

    // Discard: the default layout keeps what it had, and the edit carries on in
    // the other one. A Save landing in `Contest` would be the draft leaking
    // into the layout it was never a draft of.
    await pickRow('Contest');
    await tester.tap(find.text(l.operation.layout.layouts.discard));
    await tester.pumpAndSettle();
    expect(host.viewLayouts.active, isNot(ViewLayouts.defaultId));
    expect(host.layoutEditing, isTrue);
    expect(storedModules(services, LayoutKeys.operationDock), ['logging', '$clockPanelId#1']);

    // A new layout starts from the default arrangement, so `map` may already
    // be in it: a clock of its own is a change whatever that holds.
    const clock = '$clockPanelId#7';
    expect(host.dockSpec!.collectModules(), isNot(contains(clock)));
    host.dockKey.currentState!.addModule(clock);
    await switchTo(l.operation.layout.layouts.defaultName);
    await tester.tap(find.widgetWithText(FilledButton, l.common.save));
    await tester.pumpAndSettle();
    expect(storedModules(services, contestKey), contains(clock));
    expect(storedModules(services, LayoutKeys.operationDock), ['logging', '$clockPanelId#1']);
    expect(host.viewLayouts.active, ViewLayouts.defaultId);
    await unmount(tester);
  });

  testWidgets('a duplicate made from the editor copies the draft, and the original keeps what it saved', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    host.startLayoutEditing();
    host.dockKey.currentState!.addModule('map');
    await tester.pumpAndSettle();

    await host.duplicateLayout(ViewLayouts.defaultId, 'Copy');
    await tester.pumpAndSettle();
    expect(host.layoutName(host.viewLayouts.activeLayout), 'Copy');
    expect(host.layoutEditing, isTrue);
    expect(host.dockSpec!.collectModules(), contains('map'));
    // Saved under the original instead, the copy would be the same edit
    // twice, and "make a variation of this" would have changed this.
    expect(storedModules(services, LayoutKeys.operationDock), ['logging', '$clockPanelId#1']);
    await unmount(tester);
  });

  testWidgets('a blank description shows the panels, and the field offers them as its hint', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    final t = AppLocale.en.buildSync().operation.layout.layouts;
    final panels = host.layoutPaneTitles(ViewLayouts.defaultId).join(' · ');
    expect(host.layoutDescription(host.viewLayouts.activeLayout), panels);

    host.startLayoutEditing();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LayoutSwitcherButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, t.edit));
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(HaloDialog), matching: find.byType(TextField));
    // The hint is what leaving it blank will show — and dimmed, or it reads
    // as a description already typed in.
    final hint = tester.widget<TextField>(fields.at(1)).decoration!;
    expect(hint.hintText, panels);
    expect(hint.hintStyle?.color?.a, lessThan(0.5));

    await tester.enterText(fields.at(1), 'Sprint, with the bandmap');
    await tester.tap(find.widgetWithText(FilledButton, AppLocale.en.buildSync().common.save));
    await tester.pumpAndSettle();
    expect(host.layoutDescription(host.viewLayouts.activeLayout), 'Sprint, with the bandmap');
    expect(ViewLayouts.read(services.settings, 'operation').activeLayout.description, 'Sprint, with the bandmap');

    // Cleared again: back to the panels, not an empty line under the name.
    await host.editLayout(ViewLayouts.defaultId, name: 'Default', description: null);
    expect(host.layoutDescription(host.viewLayouts.activeLayout), panels);
    await unmount(tester);
  });

  testWidgets('an edit saved in one layout leaves the other as it was', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);

    await host.createLayout('Contest');
    await tester.pumpAndSettle();
    expect(host.layoutName(host.viewLayouts.activeLayout), 'Contest');
    // A new layout is the view's DEFAULT arrangement, not a copy of the one
    // on screen — the clock placed in the original is not in it.
    expect(host.dockSpec!.collectModules(), isNot(contains('$clockPanelId#1')));

    host.startLayoutEditing();
    host.dockKey.currentState!.addModule('map');
    host.saveLayout();
    await tester.pumpAndSettle();

    final contestKey = host.dockKeys.spec;
    expect(contestKey, isNot(LayoutKeys.operationDock), reason: 'a named layout stores under keys of its own');
    expect(storedModules(services, contestKey), contains('map'));
    expect(storedModules(services, LayoutKeys.operationDock), ['logging', '$clockPanelId#1'], reason: 'the save wrote into the other layout');

    host.switchLayout(ViewLayouts.defaultId);
    await tester.pumpAndSettle();
    expect(host.dockSpec!.collectModules(), ['logging', '$clockPanelId#1']);
    // The choice outlives the view.
    expect(ViewLayouts.read(services.settings, 'operation').active, ViewLayouts.defaultId);
    await unmount(tester);
  });

  testWidgets('a duplicate gives each instance its own id, holding a copy of its settings', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);

    await host.duplicateLayout(ViewLayouts.defaultId, 'Copy');
    await tester.pumpAndSettle();
    final modules = host.dockSpec!.collectModules();
    // Sharing `#1` would make the copy's clock the same placement: changing
    // its zone would change the original's.
    expect(modules, contains('$clockPanelId#2'));
    expect(await zoneOf(services, '$clockPanelId#2'), 'Asia/Tokyo');

    await zone(services, '$clockPanelId#2', 'Europe/Paris');
    expect(await zoneOf(services, '$clockPanelId#1'), 'Asia/Tokyo');
    await unmount(tester);
  });

  testWidgets('deleting a layout forgets what its instances held, and nothing else', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    await host.duplicateLayout(ViewLayouts.defaultId, 'Copy');
    await tester.pumpAndSettle();
    final copyId = host.viewLayouts.active;

    await host.deleteLayout(copyId);
    await tester.pumpAndSettle();
    expect(host.viewLayouts.layouts.map((l) => l.id), [ViewLayouts.defaultId]);
    // `#2` is the next clock anyone adds; left behind, it arrives holding
    // the deleted layout's zone.
    expect(await zoneOf(services, '$clockPanelId#2'), isNull);
    expect(await zoneOf(services, '$clockPanelId#1'), 'Asia/Tokyo');
    // The last layout is not deletable: a view has to draw something.
    await host.deleteLayout(ViewLayouts.defaultId);
    expect(host.viewLayouts.layouts, hasLength(1));
    await unmount(tester);
  });

  testWidgets('adding from a file is a draft: a column on the right, gone again on Discard', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    final file = LayoutFile(
      arrangements: {
        DockLayoutClass.wide: LayoutFileArrangement(
          root: LayoutFileGroup([
            const LayoutFileTab(panel: 'logging'),
            const LayoutFileTab(panel: clockPanelId, instance: true, settings: {clockZoneKey: 'America/Denver'}),
          ]),
        ),
      },
    );

    final (:skipped, restored: _) = await host.importLayout(host.importTargets(file, LayoutImportMode.add), mode: LayoutImportMode.add);
    await tester.pumpAndSettle();
    expect(host.layoutEditing, isTrue);
    // The log is on screen already, and a second one would hand one widget to
    // two tabs.
    expect(skipped, ['logging']);
    final root = host.dockSpec! as DockSplit;
    expect(root.children.last.collectModules(), ['$clockPanelId#2'], reason: 'the new column is on the right, with an id clear of #1');
    expect(await zoneOf(services, '$clockPanelId#2'), 'America/Denver');
    expect(storedModules(services, LayoutKeys.operationDock), ['logging', '$clockPanelId#1'], reason: 'nothing reaches storage before Save');

    host.revertLayout();
    await tester.pumpAndSettle();
    expect(host.dockSpec!.collectModules(), ['logging', '$clockPanelId#1']);
    expect(await zoneOf(services, '$clockPanelId#2'), isNull, reason: 'a discarded pane takes its settings with it');
    await unmount(tester);
  });

  testWidgets('a file\'s other arrangement comes as a new layout or in place of this one, never with an add', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    LayoutFileArrangement only(String panel) => LayoutFileArrangement(root: LayoutFileGroup([LayoutFileTab(panel: panel)]));
    final file = LayoutFile(arrangements: {DockLayoutClass.wide: only('map'), DockLayoutClass.narrow: only('spots')});

    // The dialog does not ask, so this is the whole rule: an add drops a
    // column into the arrangement on screen, and the other class has no
    // column for it to land in.
    expect(host.importTargets(file, LayoutImportMode.add).keys, [DockLayoutClass.wide]);
    expect(host.importTargets(file, LayoutImportMode.replace).keys, unorderedEquals(DockLayoutClass.values));
    expect(host.importTargets(file, LayoutImportMode.newLayout).keys, unorderedEquals(DockLayoutClass.values));
    // A one-arrangement file lands in the class the dialog drew, which a
    // rotation behind it does not change: the picks are that arrangement's.
    final one = LayoutFile(arrangements: {DockLayoutClass.wide: only('map')});
    expect(host.importTargets(one, LayoutImportMode.replace, shown: DockLayoutClass.narrow).keys, [DockLayoutClass.narrow]);
    await unmount(tester);
  });

  testWidgets('an import keeps the pane a small screen cannot do without', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    LayoutFileArrangement only(String panel) => LayoutFileArrangement(root: LayoutFileGroup([LayoutFileTab(panel: panel)]));
    // A partial export with the log unticked, say, or a file from Chasing.
    final file = LayoutFile(arrangements: {DockLayoutClass.wide: only('map'), DockLayoutClass.narrow: only('spots')});

    final imported = await host.importLayout(host.importTargets(file, LayoutImportMode.newLayout), mode: LayoutImportMode.newLayout, name: 'Spots');
    await tester.pumpAndSettle();
    // Off screen too: the phone this layout is next drawn on has nowhere
    // else to enter a QSO, and nothing there can bring the log back.
    final narrow = storedModules(services, ViewLayouts.layoutKey(LayoutKeys.operationNarrowDock, host.viewLayouts.active));
    expect(narrow, ['logging', 'spots']);
    expect(imported.restored, ['logging'], reason: 'the operator is told why a pane they did not pick is there');
    expect(storedModules(services, ViewLayouts.layoutKey(LayoutKeys.operationDock, host.viewLayouts.active)), ['map'], reason: 'wide pins nothing');
    await unmount(tester);
  });

  testWidgets('a new layout from a file is written in one go, not a key at a time', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    LayoutFileArrangement only(String panel) => LayoutFileArrangement(root: LayoutFileGroup([LayoutFileTab(panel: panel)]));
    final file = LayoutFile(arrangements: {DockLayoutClass.wide: only('map'), DockLayoutClass.narrow: only('spots')});
    var told = 0;
    void count() => told++;
    services.settings.addListener(count);
    addTearDown(() => services.settings.removeListener(count));

    await host.importLayout(host.importTargets(file, LayoutImportMode.newLayout), mode: LayoutImportMode.newLayout, name: 'Two');
    // Each write persists the whole layout map and rebuilds every view that
    // listens: its keys at once, then the list, then the switch to it — not
    // the eight or more a write per key comes to.
    expect(told, lessThanOrEqualTo(3));
    await unmount(tester);
  });

  testWidgets('a file with nothing this view can hold makes no layout', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    final file = LayoutFile(
      arrangements: {
        DockLayoutClass.wide: LayoutFileArrangement(root: LayoutFileGroup([const LayoutFileTab(panel: HomeView.operationsPanelId)])),
      },
    );

    final imported = await host.importLayout(host.importTargets(file, LayoutImportMode.newLayout), mode: LayoutImportMode.newLayout, name: 'Home');
    await tester.pumpAndSettle();
    // Made anyway, it is a layout of the view's defaults under the file's
    // name, for the operator to find and delete.
    expect(host.viewLayouts.layouts.map((l) => l.id), [ViewLayouts.defaultId]);
    expect(imported.skipped, [HomeView.operationsPanelId]);
    await unmount(tester);
  });

  testWidgets('a copy made from the editor takes no id the ending edit still holds', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    host.startLayoutEditing();
    host.dockKey.currentState!.addModule('$clockPanelId#2');
    await zone(services, '$clockPanelId#2', 'Europe/Paris');
    await tester.pumpAndSettle();

    await host.duplicateLayout(ViewLayouts.defaultId, 'Copy');
    await tester.pumpAndSettle();
    // Discarding the original's draft forgets `#2` without waiting; a copy
    // handed `#2` would have what it just wrote there erased under it.
    final modules = host.dockSpec!.collectModules();
    expect(modules, isNot(contains('$clockPanelId#1')));
    expect(modules, isNot(contains('$clockPanelId#2')));
    expect(modules.where((id) => id.startsWith(clockPanelId)), hasLength(2));
    await unmount(tester);
  });

  testWidgets('a layout another view of the same kind added is neither overwritten nor dropped', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    // What a second Operation view stacked over this one writes when it
    // makes a layout.
    await ViewLayouts.read(services.settings, 'operation')
        .copyWith(
          layouts: [
            ...host.viewLayouts.layouts,
            const ViewLayout(id: '2', name: 'Elsewhere'),
          ],
        )
        .write(services.settings, 'operation');
    await services.settings.setLayoutData(ViewLayouts.layoutKey(LayoutKeys.operationDock, '2'), DockGroup(['map']).toJson());

    await host.createLayout('Here');
    await tester.pumpAndSettle();
    final stored = ViewLayouts.read(services.settings, 'operation');
    expect(stored.layouts.map((l) => l.name), contains('Elsewhere'));
    expect(host.viewLayouts.active, isNot('2'), reason: 'id 2 is taken, and clearing its keys would wipe the other view\'s layout');
    expect(storedModules(services, ViewLayouts.layoutKey(LayoutKeys.operationDock, '2')), ['map']);
    await unmount(tester);
  });

  testWidgets('a layout another view deleted stays on screen here, and is never written back', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    await host.duplicateLayout(ViewLayouts.defaultId, 'Copy');
    await tester.pumpAndSettle();
    final copyId = host.viewLayouts.active;
    // What a second Operation view stacked over this one writes when it
    // deletes the layout this one is drawing.
    await ViewLayouts.read(services.settings, 'operation').without(copyId).write(services.settings, 'operation');
    List<String> storedIds() => ViewLayouts.read(services.settings, 'operation').layouts.map((l) => l.id).toList();

    await host.editLayout(ViewLayouts.defaultId, name: 'Main');
    expect(host.viewLayouts[copyId], isNotNull, reason: 'still what this view draws');
    // Written back, it is a layout again in both views, opening on keys the
    // delete emptied — and the other view, which never saw it return, can
    // hand its id to a layout of its own.
    expect(storedIds(), [ViewLayouts.defaultId]);
    host.switchLayout(ViewLayouts.defaultId);
    await tester.pumpAndSettle();
    expect(storedIds(), [ViewLayouts.defaultId]);
    // Off it, this view lists it no more either: kept, it is a second layout
    // that brings back the switcher a single layout hides.
    expect(host.viewLayouts.layouts.map((l) => l.id), [ViewLayouts.defaultId]);
    await unmount(tester);
  });

  testWidgets('a layout deleted in one view moves another view drawing it off it', (tester) async {
    final services = await servicesWith(tester);
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final first = await services.operations.create(stationCall: 'KI2D');
    final second = await services.operations.create(stationCall: 'KI2D');
    // Two Operation views at once, as when one is stacked over another.
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Column(
            children: [
              Expanded(
                child: OperationView(services: services, operationUuid: first.uuid),
              ),
              Expanded(
                child: OperationView(services: services, operationUuid: second.uuid),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final [top, under] = tester.stateList<State>(find.byType(OperationView)).cast<DockHost>().toList();
    await top.duplicateLayout(ViewLayouts.defaultId, 'Copy');
    await tester.pumpAndSettle();
    final copyId = top.viewLayouts.active;
    under.switchLayout(copyId);
    await tester.pumpAndSettle();
    final copyClock = top.dockSpec!.collectModules().firstWhere((id) => id.startsWith(clockPanelId));

    await top.deleteLayout(copyId);
    await tester.pumpAndSettle();
    // Left drawing it, the view underneath shows a clock whose zone the
    // delete just forgot, in a slot the next clock placed is handed.
    expect(under.viewLayouts.active, ViewLayouts.defaultId);
    expect(under.dockSpec!.collectModules(), isNot(contains(copyClock)));
    expect(ViewLayouts.read(services.settings, 'operation').layouts.map((l) => l.id), [ViewLayouts.defaultId]);
    await unmount(tester);
  });

  testWidgets('moving to another layout from the editor still hands focus back when the edit ends', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    await host.createLayout('Contest');
    host.switchLayout(ViewLayouts.defaultId);
    await tester.pumpAndSettle();
    final field = FocusManager.instance.primaryFocus;
    expect(field, isNot(isA<FocusScopeNode>()), reason: 'the view opens with the call field focused');

    host.startLayoutEditing();
    await tester.pumpAndSettle();
    await host.leaveEditFor(() async => host.switchLayout(host.viewLayouts.layouts.last.id), save: false);
    await tester.pumpAndSettle();
    host.saveLayout();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(field));
    await unmount(tester);
  });

  testWidgets('a panel placed once keeps its settings unless asked, and even then only on Save', (tester) async {
    final services = await servicesWith(tester);
    // A panel that may be placed only once: its settings are the PANEL'S, the
    // same in every layout that shows it, so a file overwriting them changes
    // layouts the operator is not looking at.
    services.panels.registerNative(
      const PanelDefinition(
        id: 'notes',
        title: 'Notes',
        source: PanelSource.native,
        views: {'operation'},
        formFields: [
          {'type': 'field', 'key': 'text', 'fieldType': 'text', 'label': 'Text', 'value': ''},
        ],
      ),
    );
    Future<void> setText(String value) =>
        services.extensions.commitSettingsFieldValue(kind: 'simple', hookKey: 'notes', panelKey: 'notes', fieldKey: 'text', value: value, state: const {});
    Future<Object?> text() async => (await services.panels.configFor(services.panels['notes']!))['text'];
    await setText('mine');
    final host = await pumpWide(tester, services);
    final file = LayoutFile(
      arrangements: {
        DockLayoutClass.wide: LayoutFileArrangement(
          root: LayoutFileGroup([
            const LayoutFileTab(panel: 'logging'),
            const LayoutFileTab(panel: 'notes', settings: {'text': 'from the file'}),
          ]),
        ),
      },
    );
    Future<void> replace({required bool settings}) =>
        host.importLayout(host.importTargets(file, LayoutImportMode.replace), mode: LayoutImportMode.replace, replaceSharedSettings: settings);

    await replace(settings: false);
    host.saveLayout();
    await tester.pumpAndSettle();
    expect(host.dockSpec!.collectModules(), ['logging', 'notes']);
    expect(await text(), 'mine', reason: 'not asked to replace them');

    await replace(settings: true);
    expect(await text(), 'mine', reason: 'mid-edit, where Discard has to be able to take it back');
    host.revertLayout();
    await tester.pumpAndSettle();
    expect(await text(), 'mine', reason: 'discarded');

    await replace(settings: true);
    host.saveLayout();
    await tester.pumpAndSettle();
    expect(await text(), 'from the file');
    await unmount(tester);
  });

  testWidgets('a copy that fails partway leaves no trace, and the edit as it was', (tester) async {
    final keychain = _LockableKeychain()..install();
    final services = await servicesWith(tester);
    // An instance holding a secret: the copy writes the clock's zone, then
    // this one's token into a keychain that refuses it.
    services.panels.registerNative(
      const PanelDefinition(
        id: 'vault',
        title: 'Vault',
        source: PanelSource.native,
        views: {'operation'},
        multiple: true,
        formFields: [
          {'type': 'field', 'key': 'token', 'fieldType': 'secret', 'label': 'Token', 'value': ''},
        ],
      ),
    );
    await services.settings.setLayoutData(
      LayoutKeys.operationDock,
      DockSplit(
        Axis.horizontal,
        [
          DockGroup(['logging']),
          DockGroup(['$clockPanelId#1', 'vault#1']),
        ],
        [2, 1],
      ).toJson(),
    );
    await services.extensions.commitSettingsFieldValue(
      kind: 'simple',
      hookKey: 'vault',
      panelKey: 'vault#1',
      fieldKey: 'token',
      value: 's3cret',
      state: const {},
      isSecret: true,
    );
    final host = await pumpWide(tester, services);
    host.startLayoutEditing();
    host.dockKey.currentState!.addModule('map');
    await tester.pumpAndSettle();

    keychain.locked = true;
    await expectLater(host.duplicateLayout(ViewLayouts.defaultId, 'Copy'), throwsA(isA<PlatformException>()));
    await tester.pumpAndSettle();
    expect(host.viewLayouts.layouts.map((l) => l.id), [ViewLayouts.defaultId]);
    expect(ViewLayouts.read(services.settings, 'operation').layouts.map((l) => l.id), [ViewLayouts.defaultId]);
    expect(storedModules(services, ViewLayouts.layoutKey(LayoutKeys.operationDock, '2')), isEmpty);
    // `#2` is the next clock anyone adds; left holding the failed copy's zone,
    // it would arrive with it.
    expect(await zoneOf(services, '$clockPanelId#2'), isNull);
    expect(host.layoutEditing, isTrue, reason: 'the operator\'s edit outlives a copy that never happened');
    expect(host.dockSpec!.collectModules(), contains('map'));
    await unmount(tester);
  });

  testWidgets('a copy that fails takes out every instance it wrote, even past a forget the keychain refuses', (tester) async {
    final keychain = _LockableKeychain()..install();
    final services = await servicesWith(tester);
    // The secret first: a forget that fails on it never reaches the label.
    services.panels.registerNative(
      const PanelDefinition(
        id: 'vault',
        title: 'Vault',
        source: PanelSource.native,
        views: {'operation'},
        multiple: true,
        formFields: [
          {'type': 'field', 'key': 'token', 'fieldType': 'secret', 'label': 'Token', 'value': ''},
          {'type': 'field', 'key': 'label', 'fieldType': 'text', 'label': 'Label', 'value': ''},
        ],
      ),
    );
    await services.settings.setLayoutData(LayoutKeys.operationDock, DockGroup(['vault#1', '$clockPanelId#1', 'vault#4']).toJson());
    for (final id in ['vault#1', 'vault#4']) {
      for (final (key, value, secret) in [('token', 's3cret', true), ('label', 'Club', false)]) {
        await services.extensions.commitSettingsFieldValue(
          kind: 'simple',
          hookKey: 'vault',
          panelKey: id,
          fieldKey: key,
          value: value,
          state: const {},
          isSecret: secret,
        );
      }
    }
    final host = await pumpWide(tester, services);
    // The copy's first vault takes its token; the second is refused, and the
    // undo's forgets are refused with it.
    keychain.lockAfterWrites = 3;
    keychain.refuseDeletes = true;

    await expectLater(host.duplicateLayout(ViewLayouts.defaultId, 'Copy'), throwsA(isA<PlatformException>()));
    await tester.pumpAndSettle();
    // The next placements of each are handed these ids, holding whatever
    // the failed copy left in them.
    expect(services.extensions.readStoredPanelValues('vault#2'), isEmpty, reason: 'a refused secret takes the plain fields after it down too');
    expect(await zoneOf(services, '$clockPanelId#2'), isNull, reason: 'an undo step that fails stops none after it');
    expect(services.extensions.readStoredPanelValues('vault#3'), isEmpty);
    await unmount(tester);
  });

  testWidgets('an import into the draft that fails leaves the draft as it was', (tester) async {
    final keychain = _LockableKeychain()..install();
    final services = await servicesWith(tester);
    services.panels.registerNative(
      const PanelDefinition(
        id: 'vault',
        title: 'Vault',
        source: PanelSource.native,
        views: {'operation'},
        multiple: true,
        formFields: [
          {'type': 'field', 'key': 'token', 'fieldType': 'secret', 'label': 'Token', 'value': ''},
        ],
      ),
    );
    final host = await pumpWide(tester, services);
    // Hand-written: an export never carries a secret.
    final file = LayoutFile(
      arrangements: {
        DockLayoutClass.wide: LayoutFileArrangement(
          root: LayoutFileGroup([
            const LayoutFileTab(panel: clockPanelId, instance: true, settings: {clockZoneKey: 'America/Denver'}),
            const LayoutFileTab(panel: 'vault', instance: true, settings: {'token': 's3cret'}),
          ]),
        ),
      },
    );
    keychain.locked = true;

    await expectLater(host.importLayout(host.importTargets(file, LayoutImportMode.add), mode: LayoutImportMode.add), throwsA(isA<PlatformException>()));
    await tester.pumpAndSettle();
    // The operator is told the import failed; a draft holding half of it
    // anyway is one Save commits as though it had worked.
    expect(host.dockSpec!.collectModules(), ['logging', '$clockPanelId#1']);
    expect(await zoneOf(services, '$clockPanelId#2'), isNull);
    await unmount(tester);
  });

  testWidgets('an import overtaken by a Discard while it writes lands nowhere', (tester) async {
    final keychain = _LockableKeychain()..install();
    final services = await servicesWith(tester);
    services.panels.registerNative(
      const PanelDefinition(
        id: 'vault',
        title: 'Vault',
        source: PanelSource.native,
        views: {'operation'},
        multiple: true,
        formFields: [
          {'type': 'field', 'key': 'token', 'fieldType': 'secret', 'label': 'Token', 'value': ''},
        ],
      ),
    );
    final host = await pumpWide(tester, services);
    final file = LayoutFile(
      arrangements: {
        DockLayoutClass.wide: LayoutFileArrangement(
          root: LayoutFileGroup([
            const LayoutFileTab(panel: clockPanelId, instance: true, settings: {clockZoneKey: 'America/Denver'}),
            const LayoutFileTab(panel: 'vault', instance: true, settings: {'token': 's3cret'}),
          ]),
        ),
      },
    );
    keychain.held = Completer<void>();

    final importing = host.importLayout(host.importTargets(file, LayoutImportMode.add), mode: LayoutImportMode.add);
    await tester.pump();
    host.revertLayout();
    await tester.pump();
    keychain.held!.complete();
    await importing;
    await tester.pumpAndSettle();
    // Landing after the Discard, the panes would sit in a view no longer
    // editing, unsaved, with no Save or Discard to settle them.
    expect(host.layoutEditing, isFalse);
    expect(host.dockSpec!.collectModules(), ['logging', '$clockPanelId#1']);
    expect(await zoneOf(services, '$clockPanelId#2'), isNull, reason: 'the next clock placed would open on it');
    await unmount(tester);
  });

  testWidgets('a copy made from the editor keeps the shared settings an import queued for Save', (tester) async {
    final services = await servicesWith(tester);
    services.panels.registerNative(
      const PanelDefinition(
        id: 'notes',
        title: 'Notes',
        source: PanelSource.native,
        views: {'operation'},
        formFields: [
          {'type': 'field', 'key': 'text', 'fieldType': 'text', 'label': 'Text', 'value': ''},
        ],
      ),
    );
    Future<Object?> text() async => (await services.panels.configFor(services.panels['notes']!))['text'];
    final host = await pumpWide(tester, services);
    final file = LayoutFile(
      arrangements: {
        DockLayoutClass.wide: LayoutFileArrangement(
          root: LayoutFileGroup([
            const LayoutFileTab(panel: 'notes', settings: {'text': 'from the file'}),
          ]),
        ),
      },
    );
    await host.importLayout(host.importTargets(file, LayoutImportMode.add), mode: LayoutImportMode.add, replaceSharedSettings: true);
    await tester.pumpAndSettle();

    await host.duplicateLayout(ViewLayouts.defaultId, 'Copy');
    await tester.pumpAndSettle();
    expect(host.layoutEditing, isTrue);
    expect(host.dockSpec!.collectModules(), contains('notes'));
    // The draft came across, so its Save has to mean what it would have
    // meant in the original — the file's settings with it.
    host.saveLayout();
    await tester.pumpAndSettle();
    expect(await text(), 'from the file');
    await unmount(tester);
  });

  testWidgets('a copy keeps what a switched-off extension\'s instance holds, and deleting it forgets that again', (tester) async {
    final services = await servicesWith(tester);
    await services.settings.setLayoutData(
      LayoutKeys.operationDock,
      DockSplit(
        Axis.horizontal,
        [
          DockGroup(['logging']),
          DockGroup(['ext:wx:notes#1']),
        ],
        [2, 1],
      ).toJson(),
    );
    // Stored as the panel stored it while its extension ran.
    await services.settings.prefs.setString('settingsPanel.ext:wx:notes#1.text', '"line one"');
    final host = await pumpWide(tester, services);

    await host.duplicateLayout(ViewLayouts.defaultId, 'Copy');
    await tester.pumpAndSettle();
    expect(host.dockSpec!.collectModules(), contains('ext:wx:notes#2'));
    // Empty, the copy's pane would open blank once the extension is back.
    expect(services.extensions.readStoredPanelValues('ext:wx:notes#2'), {'text': 'line one'});

    await host.deleteLayout(host.viewLayouts.active);
    await tester.pumpAndSettle();
    // With no fields loaded to name them, a forget that goes by fields keeps
    // them all, and the next `#2` placed opens holding the deleted copy's.
    expect(services.extensions.readStoredPanelValues('ext:wx:notes#2'), isEmpty);
    expect(services.extensions.readStoredPanelValues('ext:wx:notes#1'), {'text': 'line one'});
    await unmount(tester);
  });

  testWidgets('a discarded import forgets what it wrote for a panel whose extension is missing', (tester) async {
    final services = await servicesWith(tester);
    final host = await pumpWide(tester, services);
    final file = LayoutFile(
      arrangements: {
        DockLayoutClass.wide: LayoutFileArrangement(
          root: LayoutFileGroup([
            const LayoutFileTab(panel: 'ext:wx:forecast', instance: true, settings: {'city': 'Denver'}),
          ]),
        ),
      },
    );
    await host.importLayout(host.importTargets(file, LayoutImportMode.add), mode: LayoutImportMode.add);
    await tester.pumpAndSettle();
    expect(services.extensions.readStoredPanelValues('ext:wx:forecast#1'), {'city': 'Denver'});

    host.revertLayout();
    await tester.pumpAndSettle();
    expect(services.extensions.readStoredPanelValues('ext:wx:forecast#1'), isEmpty, reason: 'the next forecast placed would open on it');
    await unmount(tester);
  });

  testWidgets('an exported file reads no secret, not only writes none', (tester) async {
    final keychain = _LockableKeychain()..install();
    final services = await servicesWith(tester);
    services.panels.registerNative(
      const PanelDefinition(
        id: 'vault',
        title: 'Vault',
        source: PanelSource.native,
        views: {'operation'},
        multiple: true,
        formFields: [
          {'type': 'field', 'key': 'token', 'fieldType': 'secret', 'label': 'Token', 'value': ''},
          {'type': 'field', 'key': 'label', 'fieldType': 'text', 'label': 'Label', 'value': ''},
        ],
      ),
    );
    await services.settings.setLayoutData(LayoutKeys.operationDock, DockGroup(['logging', 'vault#1']).toJson());
    for (final (key, value, secret) in [('token', 's3cret', true), ('label', 'Club', false)]) {
      await services.extensions.commitSettingsFieldValue(
        kind: 'simple',
        hookKey: 'vault',
        panelKey: 'vault#1',
        fieldKey: key,
        value: value,
        state: const {},
        isSecret: secret,
      );
    }
    final host = await pumpWide(tester, services);
    keychain.reads = 0;

    final file = await host.buildLayoutFile(ViewLayouts.defaultId, {DockLayoutClass.wide: null});
    // A keychain read can put up a system prompt, or fail and take the
    // export with it, for a value the file throws away.
    expect(keychain.reads, 0);
    expect(file!.toYaml(), allOf(contains('Club'), isNot(contains('s3cret'))));
    await unmount(tester);
  });

  testWidgets('a list that cannot be read loses the names, never the layouts', (tester) async {
    final services = await servicesWith(tester);
    await services.settings.setLayoutData(ViewLayouts.storageKey('operation'), {'layouts': 'not a list'});
    await services.settings.setLayoutData(ViewLayouts.layoutKey(LayoutKeys.operationDock, '2'), DockGroup(['map']).toJson());
    final host = await pumpWide(tester, services);

    expect(host.viewLayouts.layouts.map(host.layoutName), ['Default', 'Layout 2']);
    expect(services.statusBar.activeNotices.map((n) => n.key), contains('layouts:operation:recovered'));
    expect(ViewLayouts.fromJson(services.settings.layoutData(ViewLayouts.storageKey('operation'))), isNotNull, reason: 'written back, so told once');
    // Forgotten, `2` is the next new layout's id, and taking it empties the
    // keys still holding that layout.
    await host.createLayout('New');
    await tester.pumpAndSettle();
    expect(host.viewLayouts.active, '3');
    expect(storedModules(services, ViewLayouts.layoutKey(LayoutKeys.operationDock, '2')), ['map']);
    await unmount(tester);
  });
}

Future<void> zone(HaLoServices services, String id, String value) =>
    services.extensions.commitSettingsFieldValue(kind: 'simple', hookKey: clockPanelId, panelKey: id, fieldKey: clockZoneKey, value: value, state: const {});

Future<String?> zoneOf(HaLoServices services, String id) async {
  final panel = services.panels[id];
  if (panel == null) return null;
  return (await services.panels.configFor(panel))[clockZoneKey] as String?;
}

/// The platform keychain, whose writes fail once [locked] — locked mid-copy —
/// and whose deletes fail when [refuseDeletes], counting the [reads] that
/// reach it.
class _LockableKeychain {
  bool locked = false;

  /// Locks it after this many writes have gone through.
  int? lockAfterWrites;

  /// Whether a delete fails, as a locked keychain's does.
  bool refuseDeletes = false;

  /// Holds every write until it completes, as a keychain waiting on its
  /// unlock prompt does.
  Completer<void>? held;

  int reads = 0;
  int _writes = 0;
  final _items = <String, String>{};

  void install() {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      switch (call.method) {
        case 'read':
          reads++;
          return _items[args['key']];
        case 'write':
          await held?.future;
          if (locked || _writes >= (lockAfterWrites ?? _writes + 1)) throw PlatformException(code: 'Locked', message: 'keyring is locked');
          _writes++;
          _items[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          if (refuseDeletes) throw PlatformException(code: 'Locked', message: 'keyring is locked');
          _items.remove(args['key']);
          return null;
        case 'containsKey':
          return _items.containsKey(args['key']);
        default:
          throw UnsupportedError('test keychain: ${call.method}');
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The producer half of the `qso` trigger's budget (docs/design/layouts.md).
// The QSO being composed changes on every keystroke, so publishing it is
// gated twice on the view's side — and neither gate is visible from
// anywhere else: LoggingControls only knows whether it was handed a
// callback, and the panel only knows whether it was woken. Nothing between
// them would go red if either gate were deleted, which is the whole reason
// these exist.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:ham2k_logger/views/operation/layout_sheet.dart';
import 'package:ham2k_logger/views/operation/missing_panel_pane.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import 'support/halo_test_support.dart';

void main() {
  /// One extension panel, declaring the triggers the test needs. The shape
  /// is `invokeHookAll`'s: one envelope per hook, its panels inside.
  Map<String, dynamic> hostResults({required List<String> on}) => {
        'panel:*:getPanels': [
          {
            'key': 'wx',
            'ok': true,
            'value': [
              {'key': 'forecast', 'title': 'Forecast', 'on': on},
            ],
          },
        ],
        'panel:wx:render': {'kind': 'markdown', 'content': 'ok'},
      };

  Future<HaLoServices> servicesWith(
    WidgetTester tester, {
    Map<String, dynamic> mockHooks = const {},
    List<String> layout = const ['logging', 'info'],
  }) async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices(stubs: mockHooks);
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    await settings.setLayoutCustomization(true);
    await settings.setLayoutData(
      LayoutKeys.operationDock,
      DockSplit(Axis.horizontal, [
        DockGroup([layout.first]),
        DockGroup(layout.sublist(1)),
      ], [2, 1]).toJson(),
    );
    return services;
  }

  /// The view's drift subscriptions schedule their cleanup on a timer, which
  /// the framework reports as a leak unless it is allowed to run.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Future<void> pumpOperation(WidgetTester tester, HaLoServices services) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: OperationView(services: services, operationUuid: operation.uuid)),
    ));
    await tester.pumpAndSettle();
  }

  LoggingControls controls(WidgetTester tester) => tester.widget<LoggingControls>(find.byType(LoggingControls));

  testWidgets('no panel asked for the QSO, so the view does not ask for it either', (tester) async {
    final services = await servicesWith(tester);
    await pumpOperation(tester, services);

    // Null, not merely unused: LoggingControls builds the draft and
    // deep-compares it only when this is non-null, so the gate is what keeps
    // the whole path off the keystroke route rather than making it cheap.
    expect(controls(tester).onQsoChanged, isNull);

    await unmount(tester);
  });

  testWidgets('a panel declaring qso turns the draft on', (tester) async {
    final services = await servicesWith(
      tester,
      mockHooks: hostResults(on: const ['qso']),
      layout: const ['logging', 'ext:wx:forecast'],
    );
    await pumpOperation(tester, services);

    expect(services.panels['ext:wx:forecast'], isNotNull, reason: 'the panel reached the catalog');
    expect(controls(tester).onQsoChanged, isNotNull);

    await unmount(tester);
  });

  testWidgets('a panel in the layout that did NOT ask for the QSO leaves it off', (tester) async {
    final services = await servicesWith(
      tester,
      // Same panel, same arrangement — only its declared triggers differ.
      // Without this the gate could be "is there an extension panel at all",
      // which would put every extension panel on the typing path.
      mockHooks: hostResults(on: const ['qsoLogged']),
      layout: const ['logging', 'ext:wx:forecast'],
    );
    await pumpOperation(tester, services);

    expect(services.panels['ext:wx:forecast'], isNotNull);
    expect(controls(tester).onQsoChanged, isNull);

    await unmount(tester);
  });

  testWidgets('a panel declaring only lookup still gets the draft', (tester) async {
    final services = await servicesWith(
      tester,
      mockHooks: hostResults(on: const ['lookup']),
      layout: const ['logging', 'ext:wx:forecast'],
    );
    await pumpOperation(tester, services);

    // `lookup` carries no payload of its own — the guess it announces lives
    // inside `their.guess` in the draft and nowhere else. Gating the draft on
    // `qso` alone wakes a lookup-only panel with no callsign at all, forever,
    // while hooks.md steers authors toward exactly that declaration as the
    // cheap one. What it buys over `qso` is renders, not this.
    expect(controls(tester).onQsoChanged, isNotNull);

    await unmount(tester);
  });

  testWidgets('a tab tap never writes the arrangement', (tester) async {
    final services = await servicesWith(
      tester,
      mockHooks: hostResults(on: const <String>[]),
      // Three modules, so the second group holds TWO — a group of one renders
      // as a pane title bar with nothing to tap, and this test is about what
      // tapping a tab does. The extension panel goes FIRST in that group, so
      // it is the one showing: an extension pane behind an unselected tab
      // never renders, and its spinner never lets pumpAndSettle settle.
      layout: const ['logging', 'ext:wx:forecast', 'info'],
    );
    await pumpOperation(tester, services);
    final before = services.settings.layoutData(LayoutKeys.operationDock);

    await tester.tap(find.text(AppLocale.en.buildSync().operation.tabs.info));
    await tester.pumpAndSettle();

    // Which pane is on top is STATE, and state has its own key. While it
    // lived in the definition, tapping a tab was an edit to the arrangement
    // — which is how a stand-in shown for a moment could be written over the
    // operator's real layout by nothing more than looking at another pane.
    expect(services.settings.layoutData(LayoutKeys.operationDock), before);
    expect(
      DockState.fromJson(services.settings.layoutData(LayoutKeys.operationDockState)).selected,
      contains('info'),
      reason: 'the selection went to the state key instead',
    );

    await unmount(tester);
  });

  testWidgets('a saved arrangement listing a module twice falls back to the default', (tester) async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    await settings.setLayoutCustomization(true);
    await settings.setLayoutData(
      LayoutKeys.operationDock,
      DockSplit(Axis.horizontal, [
        DockGroup(['logging']),
        DockGroup(['logging', 'info']),
      ], [2, 1]).toJson(),
    );

    // The same module twice means the same widget in two groups, and the
    // logging pane carries a GlobalKey — so this throws on every build, and
    // since nothing rewrites the spec it throws again next launch with
    // Layout Setup unreachable to undo it. Falling back is the only exit.
    await pumpOperation(tester, services);
    expect(tester.takeException(), isNull);
    expect(find.byType(DockLayoutView), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the selected tab survives a resize across the two-pane boundary', (tester) async {
    final services = await servicesWith(tester, layout: const ['logging', 'info', 'spots']);
    // Launched with a remembered selection — without one the stale value is
    // empty, `applyTo` leaves the live tree alone, and the bug this is about
    // cannot show itself.
    await services.settings.setLayoutData(
      LayoutKeys.operationDockState,
      const DockState(selected: {'info'}).toJson(),
    );
    await pumpOperation(tester, services);

    await tester.tap(find.text('SPOTS'));
    await tester.pumpAndSettle();

    // Narrow past the two-pane boundary and back: the dock is unmounted and
    // rebuilt, and its initState lays the remembered state over the live
    // tree. Read once at launch, that state reverts the operator's selection
    // to whatever was on top when the app started — every single resize.
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();

    // The SELECTION, not the tab's label: the label is in the tree whether
    // or not its pane is on top.
    expect(
      tester.state<DockLayoutViewState>(find.byType(DockLayoutView)).currentState.selected,
      contains('spots'),
    );
    expect(
      DockState.of(DockNode.fromJson(services.settings.layoutData(LayoutKeys.operationDock))!).selected,
      isNot(contains('spots')),
      reason: 'the arrangement carries no selection at all — that is the whole split',
    );

    await unmount(tester);
  });

  testWidgets('a multiple panel renders under the title it supplied', (tester) async {
    final services = await servicesWith(
      tester,
      mockHooks: {
        'panel:*:getPanels': [
          {
            'key': 'notes',
            'ok': true,
            'value': [
              {'key': 'text', 'title': 'Custom Text', 'multiple': true},
            ],
          },
        ],
        'panel:notes:render': {'kind': 'markdown', 'content': 'ok', 'title': 'Sked list'},
      },
      layout: const ['logging', 'ext:notes:text#1'],
    );
    await pumpOperation(tester, services);

    // Without a render-supplied title, two placements would both read
    // "Custom Text" and the operator could not tell which pane held which
    // notes — the whole reason instances need one.
    expect(find.text('Sked list'), findsOneWidget);
    expect(find.text('Custom Text'), findsNothing);

    await unmount(tester);
  });

  /// Two descriptors from one hook: one placeable many times, one not.
  /// Only ONE of them goes in a layout per test — a second extension pane in
  /// the same group sits behind a tab, never renders by design, and spins on
  /// its progress indicator until pumpAndSettle gives up.
  Map<String, dynamic> twoPanelHooks() => {
        'panel:*:getPanels': [
          {
            'key': 'notes',
            'ok': true,
            'value': [
              {'key': 'text', 'title': 'Custom Text', 'multiple': true},
              {'key': 'once', 'title': 'Single', 'multiple': false},
            ],
          },
        ],
        'panel:notes:render': {'kind': 'markdown', 'content': 'ok'},
      };

  /// Into edit mode, then the plus that opens Add a Panel. The layout button
  /// no longer opens a sheet — it IS the way into editing.
  Future<LayoutSheet> openAddSheet(WidgetTester tester) async {
    if (find.widgetWithIcon(IconButton, MdiIcons.viewDashboard).evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.viewDashboard));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.plus));
    await tester.pumpAndSettle();
    return tester.widget<LayoutSheet>(find.byType(LayoutSheet));
  }

  testWidgets('an instanceable panel stays in Available Panels once placed', (tester) async {
    final services = await servicesWith(
      tester,
      mockHooks: twoPanelHooks(),
      // Placed under the BARE descriptor id, which is what a layout saved
      // before this panel gained `multiple` holds — and the only case the
      // rule actually bites. An instance id (`…#1`) never equals the
      // descriptor id, so the plain filter would keep those anyway.
      layout: const ['logging', 'ext:notes:text'],
    );
    await pumpOperation(tester, services);

    // That row IS the "add another" control, and there is no other — a panel
    // filtered out once placed could never be placed twice.
    expect((await openAddSheet(tester)).available.map((p) => p.id), contains('ext:notes:text'));

    await unmount(tester);
  });

  testWidgets('adding an instanceable panel again mints a new id, not a duplicate', (tester) async {
    final services = await servicesWith(
      tester,
      mockHooks: twoPanelHooks(),
      layout: const ['logging', 'ext:notes:text#1'],
    );
    await pumpOperation(tester, services);

    final sheet = await openAddSheet(tester);
    sheet.onAdd!('ext:notes:text');
    await tester.pumpAndSettle();
    // An add is a draft like any other edit — it only reaches settings when
    // the edit is saved, which is what this asserts on.
    await tester.tap(find.text(AppLocale.en.buildSync().operation.layout.saveLayout));
    await tester.pumpAndSettle();

    // Placing the DESCRIPTOR id a second time would put the same module in
    // the arrangement twice — two panes sharing one config, so editing
    // either rewrites both — and a duplicate module is a GlobalKey crash
    // besides. The whole point of the mint is that this cannot happen.
    final saved = DockNode.fromJson(services.settings.layoutData(LayoutKeys.operationDock))!.collectModules();
    expect(saved.where((id) => id.startsWith('ext:notes:text')), ['ext:notes:text#1', 'ext:notes:text#2']);

    await unmount(tester);
  });

  testWidgets("an extension panel's own form still gets a settings control", (tester) async {
    final services = await servicesWith(
      tester,
      mockHooks: {
        'panel:*:getPanels': [
          {
            'key': 'notes',
            'ok': true,
            'value': [
              {
                'key': 'text',
                'title': 'Custom Text',
                'multiple': true,
                'form': [
                  {'type': 'field', 'key': 'content', 'fieldType': 'multiline', 'label': 'Text'},
                ],
              },
            ],
          },
        ],
        'panel:notes:render': {'kind': 'markdown', 'content': 'ok'},
      },
      // 'spots' rather than 'logging' as the other pane: logging carries a
      // tune button of its own, and two would leave the assertion below
      // unable to say which pane's it found.
      layout: const ['spots', 'ext:notes:text#1'],
    );
    await pumpOperation(tester, services);

    // A panel whose form configures that pane and nothing else has nowhere
    // else to be reached from, so its own tab is the only route to it — and
    // it is a control for USING the panel, not for arranging it, which is
    // why it lives on the tab rather than beside the layout options.
    expect(find.widgetWithIcon(IconButton, MdiIcons.tune), findsOneWidget);

    // Gone while editing: the tab is a grab handle then, and a control on one
    // competes with the drag for the same pointer.
    await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.viewDashboard));
    await tester.pumpAndSettle();
    expect(find.widgetWithIcon(IconButton, MdiIcons.tune), findsNothing);
    // One per pane, plus the VIEW's own in the header — the same glyph at
    // two scopes, told apart by where it sits.
    expect(find.widgetWithIcon(IconButton, MdiIcons.viewDashboardEdit), findsNWidgets(3));

    await unmount(tester);
  });

  testWidgets('an untitled instance shows the panel name, never its raw id', (tester) async {
    final services = await servicesWith(
      tester,
      mockHooks: {
        'panel:*:getPanels': [
          {
            'key': 'notes',
            'ok': true,
            'value': [
              {'key': 'text', 'title': 'Custom Text', 'multiple': true},
            ],
          },
        ],
        // No title in the result — the default path, since a freshly added
        // Custom Text pane has an empty Tab name until somebody types one.
        'panel:notes:render': {'kind': 'markdown', 'content': 'ok'},
      },
      layout: const ['logging', 'ext:notes:text#1'],
    );
    await pumpOperation(tester, services);

    // The catalog is keyed by DESCRIPTOR id, so a placement matches nothing
    // in it and the dock falls back to the raw module id — which is what an
    // operator sees the moment they add one of these.
    expect(find.text('Custom Text'), findsOneWidget);
    expect(find.text('ext:notes:text#1'), findsNothing);

    await unmount(tester);
  });

  testWidgets('a panel that did not opt in still leaves Available Panels once placed', (tester) async {
    final services = await servicesWith(
      tester,
      mockHooks: twoPanelHooks(),
      layout: const ['logging', 'ext:notes:once'],
    );
    await pumpOperation(tester, services);

    // The other half of the rule: `multiple` is opt-in, so an ordinary panel
    // must not start offering itself a second time.
    expect((await openAddSheet(tester)).available.map((p) => p.id), isNot(contains('ext:notes:once')));

    await unmount(tester);
  });

  testWidgets('an unknown module keeps its pane and says the extension is missing', (tester) async {
    final services = await servicesWith(
      tester,
      // The extension is simply gone — nothing in the catalog explains
      // `ext:wx:forecast`, and the saved arrangement names it.
      mockHooks: const {},
      layout: const ['logging', 'ext:wx:forecast'],
    );
    await pumpOperation(tester, services);

    // The arrangement is NOT set aside. Judging it unbuildable is as
    // destructive as deleting from it, because the next write replaces it —
    // and an extension can be missing for reasons as mundane as a hook that
    // timed out once.
    expect(
      DockNode.fromJson(services.settings.layoutData(LayoutKeys.operationDock))?.collectModules(),
      contains('ext:wx:forecast'),
    );
    expect(find.byType(MissingPanelPane), findsOneWidget);
    expect(find.byIcon(MdiIcons.toyBrickRemove), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a missing panel repairs itself when its extension answers', (tester) async {
    final hooks = <String, dynamic>{};
    final services = await servicesWith(tester, mockHooks: hooks, layout: const ['logging', 'ext:wx:forecast']);
    await pumpOperation(tester, services);
    expect(find.byType(MissingPanelPane), findsOneWidget);

    // The whole point of keeping the pane: a panel that was only briefly
    // missing needs no reconciliation at all to come back.
    hooks.addAll(hostResults(on: const <String>[]));
    services.extensions.runtimeGeneration.value++;
    await tester.pumpAndSettle();

    expect(find.byType(MissingPanelPane), findsNothing);
    expect(find.byType(ExtensionPanel), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a published draft does not rebuild the view until typing pauses', (tester) async {
    final services = await servicesWith(
      tester,
      mockHooks: hostResults(on: const ['qso']),
      layout: const ['logging', 'ext:wx:forecast'],
    );
    await pumpOperation(tester, services);

    // Straight at the callback the view handed down, so this measures the
    // VIEW's debounce and nothing else. The panel's own render throttle is
    // downstream of it and would coalesce these anyway — which is exactly
    // why "one render came out" would not prove the debounce exists. What
    // the debounce alone buys is the setState, and a setState is observable
    // here as a scheduled frame.
    final publish = controls(tester).onQsoChanged!;
    for (final call in ['K', 'KI', 'KI2', 'KI2D']) {
      publish({
        'their': {'call': call},
        'band': '20m',
      });
      // Checked BEFORE pumping: a pump draws whatever frame was scheduled and
      // clears the flag, so asserting after it would pass either way — which
      // is what the first version of this test did.
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'setState per keystroke rebuilds the logging, spots and map panes for one letter',
      );
      // Faster than the debounce window, as typing is.
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Once the operator stops, the draft lands — once, carrying the last
    // thing typed rather than the first.
    await tester.pump(panelRenderThrottle);
    final panel = tester.widget<ExtensionPanel>(find.byType(ExtensionPanel));
    expect((panel.renderContext.qso?['their'] as Map?)?['call'], 'KI2D');

    await unmount(tester);
  });
}

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
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flips between tabs and split on resize, preserving logging input', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services) = await makeHaLoServices();
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    // 1000 logical px → L: split layout with the Info tab, logging pane
    // visible on the left. Its title bar shows the same "0 QSOs" label the
    // narrow tab uses, but not as a tab — logging isn't a tab here.
    expect(find.text('INFO'), findsOneWidget);
    expect(find.text('0 QSOs'), findsOneWidget);
    expect(find.widgetWithText(Tab, '0 QSOs'), findsNothing);
    expect(find.widgetWithText(TextField, 'Their call'), findsOneWidget);

    // Type into the logging pane, then flip to narrow.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 500));

    tester.view.physicalSize = const Size(430, 800);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // 430 → S: the tab arrangement, with the QSO-count tab back — Info
    // isn't a narrow tab (it's one tap away via the callsign area instead),
    // so QSOs/Spots/Map is what tells the two arrangements apart. Index 0
    // was Info, so tab 0 (QSOs = the logging pane) shows, with the
    // in-progress callsign intact (GlobalKey reparenting).
    expect(find.text('0 QSOs'), findsOneWidget);
    expect(find.text('INFO'), findsNothing);
    expect(find.widgetWithText(TextField, 'W1AW'), findsOneWidget);

    // And back to wide: split returns, input still intact.
    tester.view.physicalSize = const Size(1000, 800);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.widgetWithText(Tab, '0 QSOs'), findsNothing, reason: 'the split\'s title bar shows the label, not a tab');
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
    expect(
      find.widgetWithText(Tab, '0 QSOs'),
      findsNothing,
      reason: 'back to the split, where logging has its own pane (with a title, not a tab)',
    );

    // Tear the tree down and drain the services' debounce timers (rescore,
    // lookup) so the binding's pending-timer invariant passes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('header title shrinks to fit at a narrow width without throwing (issue #182)', (tester) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services) = await makeHaLoServices();
    const longTitle = 'A Very Long Operation Title That Would Have Been Ellipsized Before';
    final operation = await services.operations.create(stationCall: 'KI2D', userTitle: longTitle);

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
    final HaLoHarness(:services) = await makeHaLoServices();
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('operationHeaderGrab')), findsNothing);
    // The 3-dots control next to the title/subtitle.
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_HeaderDotsControl'), findsOneWidget);

    final toolbarHeight = Theme.of(tester.element(find.byType(AppBar))).appBarTheme.toolbarHeight ?? kToolbarHeight;
    final tabBarTop = tester.getTopLeft(find.byKey(const Key('narrowTabBar'))).dy;
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
    // Otherwise the 'operation-sheet' onboarding flow auto-opens the sheet
    // on mount (issue #348), which would race with the tap below.
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

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

  testWidgets('the header title only claims as much width as its own text needs', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    // Used to stretch to fill the AppBar's whole remaining width (an
    // Expanded child forces that regardless of mainAxisSize.min) — the
    // active/hover area should now hug the short "N0CALL Test Op" text
    // instead, nowhere near the ~900px it used to claim in a 1000px window.
    final titleInkWell = find.ancestor(of: find.text('N0CALL Test Op'), matching: find.byType(InkWell));
    expect(tester.getSize(titleInkWell).width, lessThan(500));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the logging settings menu moved off the AppBar, onto the narrow QSOs tab, visible only when selected', (tester) async {
    // Narrow: the settings menu used to live in the AppBar's actions,
    // regardless of which tab was showing — but its toggles (RST/State/Grid
    // fields, dupe/number display) only ever affected the logging panel.
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Otherwise the 'operation-sheet' onboarding flow auto-opens the sheet
    // on mount (issue #348), which sits over the whole header/tab area and
    // swallows every tap below it.
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.tune)),
      findsOneWidget,
      reason: 'lives with the tab bar now, not as a standalone action — but see the next check',
    );
    expect(
      find.ancestor(of: find.byIcon(MdiIcons.tune), matching: find.byType(Tab)),
      findsNothing,
      reason: "overlaid next to the tab, not nested inside its Tab — nesting would compete with "
          "the tab bar's own tap handling for the same tap and the button would never receive one",
    );
    expect(find.byIcon(MdiIcons.tune), findsOneWidget, reason: 'QSOs is the selected tab on mount');

    // The button's own space stays reserved even when hidden (so the tab
    // doesn't reflow on selection changes) — it fades via AnimatedOpacity
    // rather than actually leaving the tree, which keeps the Icon mounted
    // regardless. So `find.byIcon` alone can't tell hidden from shown;
    // check the opacity that actually controls it (pumpAndSettle above
    // and below waits out the fade, so it's always fully settled here).
    double tuneOpacity() =>
        tester.widget<AnimatedOpacity>(find.ancestor(of: find.byIcon(MdiIcons.tune), matching: find.byType(AnimatedOpacity))).opacity;

    await tester.tap(find.text('SPOTS'));
    await tester.pumpAndSettle();
    expect(tuneOpacity(), 0, reason: 'hidden once QSOs is no longer the active tab');

    await tester.tap(find.text('0 QSOs'));
    await tester.pumpAndSettle();
    expect(tuneOpacity(), 1, reason: 'reappears once QSOs is selected again');

    // The menu itself is unchanged — same toggle, same effect.
    await tester.tap(find.byIcon(MdiIcons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Show RST fields'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
    'the tune icon opens a target-built dialog: extended settings stay hidden until "show more"',
    (tester) async {
      // HALO-55: the popup menu was replaced by settings_target_dialog.dart's
      // showSettingsForTarget(target: 'logging'). Fields the old menu never
      // had (leftieMode etc., declared target: 'logging-extended') must not
      // clutter the dialog by default, but must be reachable via "show more
      // settings". (core_settings_groups_test.dart pins that those fields
      // actually commit through to SettingsService — a live Switch's own
      // animation mid-rebuild isn't stable to drive from a widget test.)
      tester.view.physicalSize = const Size(430, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final HaLoHarness(:services, :settings) = await makeHaLoServices();
      await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
      final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(MdiIcons.tune));
      await tester.pumpAndSettle();

      expect(find.text('Show RST fields'), findsOneWidget, reason: 'target: "logging" base elements show upfront');
      expect(
        find.text('Leftie Mode'),
        findsNothing,
        reason: 'target: "logging-extended" elements start hidden behind "show more"',
      );

      // The Actions section and the "Relevant Settings" header push it
      // below the fold at this narrow test size — scroll it into view
      // before tapping, or the geometric tap lands on whatever's still
      // visible at that (now-stale) offset instead.
      await tester.ensureVisible(find.text('Show more settings'));
      // The scroll ensureVisible starts needs a frame before a tap can be
      // aimed: in a sliver viewport the rows move on the NEXT layout, and a
      // tap placed from the old one lands on whatever was there before.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show more settings'));
      await tester.pumpAndSettle();
      expect(find.text('Leftie Mode'), findsOneWidget, reason: 'revealed once "show more" is tapped');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'toggling a field revealed via "show more" commits cleanly (regression, HALO-55)',
    (tester) async {
      // A live incident, not a hypothetical: toggling Leftie Mode from this
      // dialog threw `identical(childRenderObject, parentRenderObject)`.
      // Traced (by bypassing every layer of this dialog one at a time,
      // down to calling SettingsService.setSettingValue directly while the
      // dialog sat open) to logging_controls.dart's submit button — leftie
      // mode moves it between the main Row's first and last slot, and
      // without a stable Key on the widget actually sitting in
      // Row.children (only an inner AspectRatio had one), Flutter treated
      // the move as unmount-one/mount-another. Harmless on its own; fatal
      // while a Dialog route was simultaneously open and running its own
      // semantics pass. Fixed at the source (a KeyedSubtree around
      // submitButtonWidget) — this test exercises the actual dialog path
      // that crashed, not the underlying Row.
      tester.view.physicalSize = const Size(430, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final HaLoHarness(:services, :settings) = await makeHaLoServices();
      await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
      final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(MdiIcons.tune));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Show more settings'));
      // The scroll ensureVisible starts needs a frame before a tap can be
      // aimed: in a sliver viewport the rows move on the NEXT layout, and a
      // tap placed from the old one lands on whatever was there before.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show more settings'));
      await tester.pumpAndSettle();

      expect(settings.leftieMode, isFalse);
      final leftieSwitch = find.descendant(of: find.widgetWithText(ListTile, 'Leftie Mode'), matching: find.byType(Switch));
      await tester.ensureVisible(leftieSwitch);
      // The scroll ensureVisible starts needs a frame before a tap can be
      // aimed: in a sliver viewport the rows move on the NEXT layout, and a
      // tap placed from the old one lands on whatever was there before.
      await tester.pumpAndSettle();
      await tester.tap(leftieSwitch);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'the semantics-tree assertion used to fire exactly here');
      expect(settings.leftieMode, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('the header dots animate back on close, not an instant snap to their resting place', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    // The control reserves a fixed width (the header title must not shift as
    // the sheet opens), so its geometry says nothing about the animation —
    // the painter's own progress is the thing to read. The painter class is
    // private to operation_view.dart, but `progress` is a public member on
    // it, so a dynamic read reaches it from here. It stays MOUNTED the whole
    // time — the sheet's own accept button (headerLeading, reachable above
    // the pane's dismiss layer — see modal_pane.dart) draws on top of it
    // once open, but doesn't unmount it, which is what lets this control
    // keep animating underneath for the close transition this test pins.
    final control = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_HeaderDotsControl');
    double progress() {
      final paint = tester.widget<CustomPaint>(
        find.descendant(of: control, matching: find.byType(CustomPaint)),
      );
      return (paint.painter as dynamic).progress as double;
    }

    await tester.tap(find.text('N0CALL Test Op'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsOneWidget);
    expect(progress(), closeTo(1, 0.01), reason: 'fully fallen away while the sheet is open');

    // Closing: saveAndClose() awaits saveData() before calling pop(), so a
    // couple of bare pumps first flush that gap; the awaited showTopModalPane
    // future (and so _openOperationSheet's `finally`) resolves at pop() time
    // — well before the route's 600ms reverse transition finishes — which is
    // exactly the bug this pins: _sheetAnimation must keep reflecting the
    // reversing route animation for that whole stretch, not go null the
    // instant pop() is called. Tapped by text, not widget type: the sheet's
    // own accept button (headerLeading) is what's actually reachable here,
    // not the dots control it's drawn on top of.
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final mid = progress();
    expect(mid, lessThan(0.99), reason: 'still mid-close — must not have already snapped back to plain dots');
    expect(mid, greaterThan(0.01), reason: 'and must not still read as fully open either — genuinely animating');

    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing);
    expect(progress(), closeTo(0, 0.01), reason: 'settles back to plain dots once fully closed');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the accept button in the view header saves and closes the sheet', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    final acceptButton = find.widgetWithText(FilledButton, 'OK');
    // Not present at all until the sheet actually opens: this control has no
    // header of its own to be absent FROM (showHeader: false), so its only
    // way onto the screen is the view's headerLeading, present exactly as
    // long as the pane's route is.
    expect(acceptButton, findsNothing);

    await tester.tap(find.text('N0CALL Test Op'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsOneWidget);
    expect(acceptButton, findsOneWidget);
    // No "Operation Setup" band of its own — the sheet's content starts
    // right at the top of the pane.
    expect(find.text('Operation Setup'), findsNothing);

    // The button that matters is the one drawn by headerLeading, above the
    // pane's own dismiss layer — a plain tap resolves to it because nothing
    // else claims that hit region; this is the regression this test guards
    // against: a copy placed directly in the view's AppBar sits BELOW that
    // layer and would swallow taps without ever running onPressed.
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing, reason: 'the tap actually reached the button and closed the sheet');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the view header stays visible and reachable on narrow too, not just wide', (tester) async {
    // Below ShirtSize.sMax (720): narrow, single-pane. showTopModalPane used
    // to cover the whole screen at this width, chevron/Tools and all — this
    // pins that the operation sheet opts out of that and leaves the AppBar
    // uncovered, matching what wide already looked like, AND that Tools is
    // actually reachable while the sheet is up — not just visible — through
    // a live copy drawn above the barrier (headerTrailing), same mechanism
    // as the accept button (headerLeading). The chevron itself hides fully
    // while the sheet is up (see _headerIconsFadeOpacity/_headerIconsInert)
    // — the accept button is its dismiss control now, not a second copy of
    // the header's own close control.
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    // A stub root beneath it, not `home: OperationView(...)` directly —
    // the chevron's own action is popping the view, which needs somewhere
    // to pop TO; the root route of a Navigator refuses to pop at all.
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => OperationView(services: services, operationUuid: operation.uuid)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Not find.byIcon(MdiIcons.tools) alone: the logging controls' own
    // settings button (buildTargetSettingsButton, unlabeled) is a distinct
    // glyph (MdiIcons.tune) today, but matching on the semantic label too
    // keeps this from silently passing if that ever changes.
    final toolsButton = find.byWidgetPredicate((w) => w is Icon && w.icon == MdiIcons.tools && w.semanticLabel == 'Tools');
    final backButton = find.byIcon(MdiIcons.chevronLeft);
    expect(toolsButton, findsOneWidget);
    expect(backButton, findsOneWidget);

    await tester.tap(find.text('N0CALL Test Op'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsOneWidget);

    // Flush to the leading corner on narrow, not indented behind the chevron
    // it replaces: that chevron has faded out, and the pane below is
    // full-bleed, so there is nothing left for the button to line up with.
    // The wide layout DOES have something (the card's own edge, at
    // leftInset), which is why the two insets are separate — a single value
    // frozen at push time is the mutation this catches.
    // Zero exactly, since no traffic lights exist in the test environment.
    final okRect = tester.getRect(find.widgetWithText(FilledButton, 'OK'));
    expect(okRect.left, 0.0);

    // And the title picks up just after that button — a Space.xs breather,
    // not a chevron slot. The gap this control reserves is measured from ITS
    // own left edge while the button starts a slot further left, so
    // reserving the button's full width leaves exactly that slot (40) of
    // dead space. The upper bound is what catches that; the lower bound
    // keeps the two from being jammed together.
    final titleGap = tester.getRect(find.text('N0CALL Test Op')).left - okRect.right;
    expect(titleGap, greaterThanOrEqualTo(0.0));
    expect(titleGap, lessThan(12.0), reason: 'a breather after the button, not the width of the slot it replaced');

    // Two of each — the real one (inert) and the live copy drawn above the
    // barrier (headerTrailing). Without `keepHeaderVisible` and its
    // headerLeading exception for narrow, a full-screen pane takes the whole
    // AppBar out of the tree rather than painting over it, and both counts
    // drop back to one.
    expect(toolsButton, findsNWidgets(2));
    expect(backButton, findsNWidgets(2));
    // Above the sheet's own top edge, not underneath it: a narrow pane that
    // starts at y=0 covers the whole AppBar, this icon included, and every
    // assertion above still passes on the widgets it left mounted.
    final sheetTop = tester.getTopLeft(find.byType(OperationSheet)).dy;
    expect(tester.getRect(toolsButton.hitTestable()).bottom, lessThanOrEqualTo(sheetTop));
    // Fully hidden, not merely painted over: neither chevron takes a tap.
    expect(backButton.hitTestable(), findsNothing);

    // The accept button is reachable through headerLeading, not by falling
    // through to the view behind it (see [TopModalPaneRoute.headerLeading]).
    final acceptButton = find.widgetWithText(FilledButton, 'OK');
    expect(acceptButton.hitTestable(), findsOneWidget);

    // The operation's own actions stay LIVE while the sheet is up — that is
    // the whole reason a copy exists, the real row being under the barrier.
    // Only the view's layout controls go disabled (not present at this
    // width). Tools closes the sheet AND opens its dialog, rather than
    // merely dismissing the way tapping empty header space does.
    await tester.tap(toolsButton.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing, reason: 'Tools closed the sheet, not just opened its own dialog on top');
    final toolsDialog = find.text('Operation Tools');
    expect(toolsDialog, findsOneWidget);
    Navigator.of(tester.element(toolsDialog)).pop();
    await tester.pumpAndSettle();

    // Sheet closed again: the chevron is back and reachable, and still
    // closes the view — the same underlying control the sheet borrowed
    // that corner from, not a separate one.
    expect(backButton.hitTestable(), findsOneWidget);
    await tester.tap(backButton.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(OperationView), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the chevron and title sit at the edge on narrow, not on wide', (tester) async {
    Future<void> pumpAt(double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      final HaLoHarness(:services) = await makeHaLoServices();
      final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ));
      await tester.pumpAndSettle();
    }

    addTearDown(tester.view.reset);

    // Narrow: the leading slot is sized to the chevron button alone (40, no
    // macOS traffic lights in this test environment) — nothing left over on
    // its right — and the title Row's own left padding drops to zero, so
    // the gap between the button and the title text collapses to just the
    // dots control's own fixed footprint.
    await pumpAt(500);
    expect(tester.widget<AppBar>(find.byType(AppBar)).leadingWidth, 40);
    final closeRight = tester.getRect(find.byIcon(MdiIcons.chevronLeft)).right;
    final narrowTitleLeft = tester.getRect(find.text('N0CALL Test Op')).left;
    final narrowGap = narrowTitleLeft - closeRight;

    // Wide: unchanged from before this — the AppBar's own default leading
    // slot (56, explicit — see _leadingWidthFor), wider than the button it
    // holds, plus the title's own inset.
    await pumpAt(1000);
    expect(tester.widget<AppBar>(find.byType(AppBar)).leadingWidth, 56.0);
    final wideCloseRight = tester.getRect(find.byIcon(MdiIcons.chevronLeft)).right;
    final wideTitleLeft = tester.getRect(find.text('N0CALL Test Op')).left;
    final wideGap = wideTitleLeft - wideCloseRight;

    expect(narrowGap, lessThan(wideGap), reason: 'narrow sits the title measurably closer to the chevron than wide does');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('closing the sheet persists the ref-generated title into data[title]', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Answers the ref's suggestOperationTitle hook (OperationTitleService's
    // fan-out key: 'ref:<type>:<key>:<method>', key null here since the hook
    // call passes none) with an "at" fragment — the same shape a real
    // activity extension (e.g. POTA) returns.
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({
      'ref:pota/activation:null:suggestOperationTitle': {'at': 'K-1234'},
    }))
      ..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final created = await services.operations.create(stationCall: 'N0CALL');
    await services.operations.saveData(Operation(
      uuid: created.uuid,
      data: {
        ...created.data,
        'refs': [
          {'type': 'pota/activation', 'ref': 'K-1234'},
        ],
      },
    ));
    final operation = (await services.operations.get(created.uuid))!;

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    // The ref-generated suggestion has already been cached (retitleOperation
    // ran on load) and shows in the header — no user title was ever set.
    expect(find.text('N0CALL at K-1234'), findsOneWidget);

    await tester.tap(find.text('N0CALL at K-1234'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsOneWidget, reason: 'first tap opens the sheet');

    // Second tap triggers saveAndClose(), which must persist the CURRENT
    // generated title into data['title'] — not just cache it in localData —
    // so it survives as part of the operation's own synced record.
    await tester.tap(find.text('N0CALL at K-1234'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing, reason: 'second tap closes and saves');

    final saved = await services.operations.get(operation.uuid);
    expect(saved!.title, 'at K-1234');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the fixed wide split gains a logging-pane title bar holding the settings menu', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.tune)),
      findsNothing,
      reason: 'no longer a global AppBar action',
    );
    // Exactly one — the split's own logging pane always shows (it has no
    // other tab to hide behind), unlike the narrow case.
    expect(find.byIcon(MdiIcons.tune), findsOneWidget);

    await tester.tap(find.byIcon(MdiIcons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Show RST fields'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the wide split tab bar and pane title bar are the same height', (tester) async {
    // They meet across the divider, so a mismatch reads as a misaligned seam
    // down the whole window. `TabBar` has no height property — it reports its
    // tallest Tab plus indicatorWeight — so left to its defaults it came out
    // 50 against the title bar's 48, while the comment at the split claimed
    // the two matched. Sizing the Tabs against the shared chrome height is
    // what makes that claim true; this is what keeps it true.
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    final tabBar = find.byType(TabBar);
    expect(tabBar, findsOneWidget, reason: 'this width is the two-pane arrangement');
    final chromeHeight = LayoutDensity.chromeHeightOf(tester.element(tabBar));
    expect(
      tester.getSize(tabBar).height,
      chromeHeight,
      reason: 'the TabBar must land on the chrome height, not on Flutter default',
    );

    // The logging pane's title bar is the SizedBox holding the QSO count.
    final titleBars = tester.widgetList<SizedBox>(
      find.ancestor(of: find.textContaining('QSO'), matching: find.byType(SizedBox)),
    );
    expect(
      titleBars.map((b) => b.height),
      contains(chromeHeight),
      reason: 'both sides of the divider share one height',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the tab strip gives its trailing button the full strip height', (tester) async {
    // The selection indicator is a border. On `decoration` a border INSETS the
    // child, so the QSOs tab's settings button rendered the indicator's width
    // shorter than the strip — 44 of 48, and 38 once the density ladder
    // reached `densest`. `foregroundDecoration` paints over an already
    // laid-out child and costs no height, which is the only reason the strip
    // being sized to a tap target means anything for the control inside it.
    //
    // Constraining the button instead does NOT work and was tried: the
    // bordered parent hands down a max below the minimum, and BoxConstraints
    // clamps min to max.
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    final strip = find.byKey(const Key('narrowTabBar'));
    expect(strip, findsOneWidget, reason: 'this width is the narrow arrangement');
    final chromeHeight = LayoutDensity.chromeHeightOf(tester.element(strip));

    final button = find.descendant(of: strip, matching: find.byType(IconButton));
    expect(button, findsOneWidget);
    expect(
      tester.getSize(button).height,
      chromeHeight,
      reason: 'the indicator must not take its width out of the tab\'s own control',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
  testWidgets('the header actions re-fit their labels as activities change the title', (tester) async {
    // The trap: whether these carry labels is measured against the title
    // they share the header with, so adding an activity — which rewrites the
    // header's ref line — has to re-run that fit. Only a real ref add
    // reaches it: a plain database write can't, since the view reads its
    // draft ahead of the saved operation for as long as the sheet is up.
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices(extensions: _SuggestingExtensions());
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: OperationView(services: services, operationUuid: operation.uuid)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('N0CALL Op'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsOneWidget);

    // Two of each: the AppBar's own row (inert) and the live copy above the
    // barrier, built from the same shared builder. Both carry labels at this
    // width with a title this short.
    expect(find.text('Exports'), findsNWidgets(2));

    await tester.tap(find.text('POTA US-0001 A Very Long Park Name').first);
    await tester.pumpAndSettle();

    // BOTH shed their labels, not just the one that happens to sit in
    // OperationView's own build. findsNWidgets(1) is the mutation this
    // catches: the AppBar's row rebuilds with the view no matter what, so a
    // copy that never hears about the new title leaves exactly one labeled
    // group behind — and disagrees with the row it is standing on.
    expect(find.text('Exports'), findsNothing,
        reason: "the widened ref line priced the labels out of BOTH rows, the sheet's copy included");

    // Paired with positives, because `findsNothing` alone also passes if the
    // tap closed the sheet, or tore the trailing row down, or the row failed
    // to build at all. What should have happened is that both rows survived
    // and went icon-only.
    expect(find.byType(OperationSheet), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Icon && w.icon == MdiIcons.export), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}

/// The shared fake host only reaches the public `host` getter while
/// the sheet's own calls read the private field, so suggestions would come
/// back empty and there would be no activity to add. Overrides the two
/// methods this test depends on instead.
class _SuggestingExtensions extends ExtensionServiceWithFakeHost {
  _SuggestingExtensions();

  @override
  Future<ControlsResult> operationControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      (controls: const <Map<String, dynamic>>[], loadFailed: false);

  @override
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    List<String>? activityKeys,
    List<String>? preferredKeys,
    String? preferredSearchTerm,
  }) async =>
      (
        suggestions: const [
          {
            'type': 'pota',
            'ref': 'US-0001',
            'label': 'POTA US-0001',
            // Long on purpose: the header's ref line has to outgrow its
            // title line for the title control to get any wider at all.
            'shortLabel': 'POTA US-0001 A Very Long Park Name',
            'name': 'Some Park',
          }
        ],
        allSourcesFailed: false
      );
}

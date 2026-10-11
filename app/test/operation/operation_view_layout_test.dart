// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation View's adaptive layout (docs/design/layouts.md): narrow
// shirt sizes get one tab strip of QSOs/Spots/Map, two-pane sizes put the
// logging pane on the left with Info/Spots/Map tabbed on the right. The
// load-bearing guarantees: the arrangement flips LIVE on a window resize,
// and the logging pane's GlobalKey carries its State — a half-typed
// callsign — across the flip instead of rebuilding it.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';
import 'package:ham2k_logger/views/operation_view.dart';
import 'package:ham2k_logger/views/sheet_header_dots.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flips between tabs and split on resize, preserving logging input', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services) = await makeHaLoServices();
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1000 logical px → L: split layout with the Info tab, logging pane
    // visible on the left under the same "0 QSOs" label the narrow tab uses.
    expect(find.text('INFO'), findsOneWidget);
    expect(find.text('0 QSOs'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Their call'), findsOneWidget);

    // Type into the logging pane, then flip to narrow.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 500));

    tester.view.physicalSize = const Size(430, 800);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // 430 → S: the narrow arrangement — Info isn't in it (it's one tap away
    // via the callsign area instead), so its absence is what tells the two
    // apart. The in-progress callsign is intact (GlobalKey reparenting).
    expect(find.text('0 QSOs'), findsOneWidget);
    expect(find.text('INFO'), findsNothing);
    expect(find.widgetWithText(TextField, 'W1AW'), findsOneWidget);

    // And back to wide: split returns, input still intact.
    tester.view.physicalSize = const Size(1000, 800);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('INFO'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'W1AW'), findsOneWidget);

    // Flip with another tab selected: the narrow dock opens on its own
    // stored selection, and the typed callsign has to survive whichever pane
    // that leaves on top.
    await tester.tap(find.text('SPOTS'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(430, 800);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'W1AW'), findsOneWidget, reason: 'logging input survives a flip made from the Spots tab');

    // Narrow with Spots on top, then wide: the logging subtree moves from
    // behind the narrow strip's selection into the split's left pane.
    await tester.tap(find.text('SPOTS'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1000, 800);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextField, 'W1AW'), findsOneWidget, reason: 'logging input survives a flip made with Spots selected');

    // Tear the tree down and drain the services' debounce timers (rescore,
    // lookup) so the binding's pending-timer invariant passes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a link that opens the view with a callsign lands on the logging pane, not the last tab used', (tester) async {
    // The trap: a dock opens on its STORED selection, and that is shared by
    // every operation. Left on Spots anywhere, a phone opens the next
    // operation on Spots too — with the link's callsign filled in behind it
    // and nothing on screen to say the link did anything.
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    await settings.setLayoutData(LayoutKeys.operationNarrowDockState, const DockState(selected: {'spots'}).toJson());
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(
            services: services,
            operationUuid: operation.uuid,
            initialSuggestedQso: const {
              'their': {'call': 'W1AW'},
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'W1AW').hitTestable(), findsOneWidget);

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

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
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
    // A regression that adds height to the header (a floating grab pill's
    // job) shows up as the panes no longer starting exactly at the toolbar's
    // bottom edge.
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services) = await makeHaLoServices();
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('operationHeaderGrab')), findsNothing);
    // The 3-dots control next to the title/subtitle.
    expect(find.byType(SheetHeaderDots), findsOneWidget);

    final toolbarHeight = Theme.of(tester.element(find.byType(AppBar))).appBarTheme.toolbarHeight ?? kToolbarHeight;
    final panesTop = tester.getTopLeft(find.byType(DockLayoutView)).dy;
    expect(panesTop, closeTo(toolbarHeight, 0.5));

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

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
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

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
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

  testWidgets('on narrow the logging settings menu rides the QSOs tab, shown only while it is selected', (tester) async {
    // Its toggles (RST/State/Grid fields, dupe/number display) only ever
    // affect the logging panel, so it belongs to that pane's tab and not to
    // the AppBar, where it would sit over whichever pane was showing.
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Otherwise the 'operation-sheet' onboarding flow auto-opens the sheet
    // on mount, which sits over the whole header/tab area and swallows every
    // tap below it.
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The BUTTON: the Spots pane draws this glyph too, as a filter label.
    final tune = find.widgetWithIcon(IconButton, MdiIcons.tune).hitTestable();
    expect(find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.tune)), findsNothing);
    expect(tune, findsOneWidget, reason: 'QSOs is the selected tab on mount');

    await tester.tap(find.text('SPOTS'));
    await tester.pumpAndSettle();
    expect(tune, findsNothing, reason: 'hidden once QSOs is no longer the active tab');

    await tester.tap(find.text('0 QSOs'));
    await tester.pumpAndSettle();
    expect(tune, findsOneWidget, reason: 'reappears once QSOs is selected again');

    // The menu itself is unchanged — same toggle, same effect.
    await tester.tap(find.byIcon(MdiIcons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Show RST fields'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the tune icon opens a target-built dialog: extended settings stay hidden until "show more"', (tester) async {
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

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(MdiIcons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Show RST fields'), findsOneWidget, reason: 'target: "logging" base elements show upfront');
    expect(find.text('Leftie Mode'), findsNothing, reason: 'target: "logging-extended" elements start hidden behind "show more"');

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
  });

  testWidgets('toggling a field revealed via "show more" commits cleanly (regression, HALO-55)', (tester) async {
    // A live incident, not a hypothetical: toggling Leftie Mode from this
    // dialog threw `identical(childRenderObject, parentRenderObject)`.
    // Traced (by bypassing every layer of this dialog one at a time,
    // down to calling SettingsService.setSettingValue directly while the
    // dialog sat open) to the logging panel's submit button — leftie
    // mode moves it between the entry row's first and last slot, and
    // without a stable Key on the widget actually sitting in
    // Row.children (only an inner AspectRatio had one), Flutter treated
    // the move as unmount-one/mount-another. Harmless on its own; fatal
    // while a Dialog route was simultaneously open and running its own
    // semantics pass. Fixed at the source (the KeyedSubtree
    // LoggingEntryRow wraps the button in) — this test exercises the
    // actual dialog path that crashed, not the underlying Row.
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
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
  });

  testWidgets('the header dots animate back on close, not an instant snap to their resting place', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The control reserves a fixed width (the header title must not shift as
    // the sheet opens), so its geometry says nothing about the animation —
    // the painter's own progress is the thing to read. The painter class is
    // private to sheet_header_dots.dart, but `progress` is a public member on
    // it, so a dynamic read reaches it from here. It stays MOUNTED the whole
    // time — the sheet's own accept button (headerLeading, reachable above
    // the pane's dismiss layer — see modal_pane.dart) draws on top of it
    // once open, but doesn't unmount it, which is what lets this control
    // keep animating underneath for the close transition this test pins.
    final control = find.byType(SheetHeaderDots);
    double progress() {
      final paint = tester.widget<CustomPaint>(find.descendant(of: control, matching: find.byType(CustomPaint)));
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

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
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

  // Without the saveAndClose memo, the second press asks the slow host for
  // the title again and writes again; without the busy state, a third press
  // can land at all.
  testWidgets('a second press while the sheet is saving closes only the sheet', (tester) async {
    final held = await _pumpSheetWithHeldTitle(tester);

    // No pump between the taps: the button has not rebuilt as busy yet, so
    // both presses reach onPressed — only saveAndClose itself can refuse the
    // second.
    final acceptButton = find.widgetWithText(FilledButton, 'OK');
    final sheetFields = find.descendant(of: find.byType(OperationSheet), matching: find.byType(TextField));
    expect(sheetFields.hitTestable(), findsWidgets);
    held.hold = true;
    await tester.tap(acceptButton);
    await tester.tap(acceptButton);
    await tester.pump();

    expect(ModalRoute.of(tester.element(find.byType(OperationSheet)))!.isCurrent, isTrue, reason: 'held on the title hook');
    expect(held.heldCalls, 1, reason: 'one save, however many presses');
    expect(tester.widget<ButtonStyleButton>(acceptButton).onPressed, isNull, reason: 'busy from the first press, so a third cannot land');
    expect(find.descendant(of: acceptButton, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(sheetFields.hitTestable(), findsNothing, reason: 'an edit made now would look applied and never be stored');

    held.release();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(OperationSheet), findsNothing);
    expect(find.byType(OperationView), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // Escape saves, as a tap outside the sheet does. Popping the route instead
  // would drop the draft while the details editor's own writes — contacts
  // restamped to a new operator, the position — had already landed.
  testWidgets('Escape saves the sheet\'s edits and closes it', (tester) async {
    final (services, operation) = await _pumpOpenSheet(tester);

    _editInSheet(tester, Operation(uuid: operation.uuid, data: {...operation.data, 'userTitle': 'Edited Op'}));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(OperationSheet), findsNothing);
    expect((await services.operations.get(operation.uuid))!.userTitle, 'Edited Op');
    expect(find.text('N0CALL Edited Op'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // Escape during a save joins it rather than closing the sheet early: the
  // sheet leaves once, when that save lands.
  testWidgets('Escape while the sheet is saving waits for that save', (tester) async {
    final held = await _pumpSheetWithHeldTitle(tester);

    held.hold = true;
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(ModalRoute.of(tester.element(find.byType(OperationSheet)))!.isCurrent, isTrue, reason: 'still waiting on the save');
    expect(held.heldCalls, 1, reason: 'Escape joined the save under way');

    held.release();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(OperationSheet), findsNothing);
    expect(find.byType(OperationView), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // A navigation past the sheet during its save (the command dialog's Go
  // home) removes it before that save lands. Closing with a plain pop then
  // would take the Operation view instead.
  testWidgets('a navigation past the sheet while it saves closes nothing more', (tester) async {
    final held = await _pumpSheetWithHeldTitle(tester);

    held.hold = true;
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pump();
    Navigator.of(tester.element(find.byType(OperationSheet))).popUntil((route) => route.isFirst);
    await tester.pump();

    held.release();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(OperationSheet), findsNothing);
    expect(find.byType(OperationView), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // A route pushed over the sheet during the wait — the command dialog, a
  // pairing prompt — leaves it not current. A plain pop would close that route
  // instead; skipping the pop leaves the sheet frozen, OK spinning, under it.
  testWidgets('a dialog opened over the sheet while it saves stays, and the sheet still closes', (tester) async {
    final held = await _pumpSheetWithHeldTitle(tester);

    held.hold = true;
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pump();
    unawaited(showDialog<void>(context: tester.element(find.byType(OperationSheet)), builder: (_) => const Text('covering')));
    // Not pumpAndSettle: OK's spinner runs for as long as the save is held.
    await tester.pump(const Duration(milliseconds: 500));
    expect(ModalRoute.of(tester.element(find.byType(OperationSheet)))!.isCurrent, isFalse, reason: 'covered before the save lands');

    held.release();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('covering'), findsOneWidget);
    expect(find.byType(OperationSheet), findsNothing);
    expect(find.byType(OperationView), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // Without the reset on failure, OK and the sheet stay frozen after a refused
  // save, with Escape — which drops the edits — the only way out.
  testWidgets('a refused save leaves the sheet open and OK pressable again', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(AppClock.instance.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('N0CALL Test Op'));
    await tester.pumpAndSettle();

    // A time-travelled session refuses writes to a real operation.
    AppClock.instance.travel(delta: const Duration(days: 1));
    final sheet = tester.state<OperationSheetState>(find.byType(OperationSheet));
    final refused = expectLater(sheet.saveAndClose(), throwsA(isA<WriteRefused>()));
    await tester.pump();
    await tester.pump();
    await refused;
    await tester.pump();

    final acceptButton = find.widgetWithText(FilledButton, 'OK');
    expect(find.byType(OperationSheet), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(acceptButton).onPressed, isNotNull);
    expect(find.descendant(of: find.byType(OperationSheet), matching: find.byType(TextField)).hitTestable(), findsWidgets);

    AppClock.instance.reset();
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing, reason: 'the retry saves and closes');
    expect(find.byType(OperationView), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // Escape means "done here": a save that fails — and a refusal that holds
  // for every save always will — must not keep the sheet open, and what the
  // view shows afterwards must be what is stored, not the draft that failed.
  testWidgets('Escape closes the sheet even when its save is refused, keeping nothing', (tester) async {
    addTearDown(AppClock.instance.reset);
    final (services, operation) = await _pumpOpenSheet(tester);
    _editInSheet(tester, Operation(uuid: operation.uuid, data: {...operation.data, 'userTitle': 'Edited Op'}));
    await tester.pump();

    // A time-travelled session refuses writes to a real operation.
    AppClock.instance.travel(delta: const Duration(days: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(OperationSheet), findsNothing);
    expect((await services.operations.get(operation.uuid))!.userTitle, 'Test Op');
    expect(find.text('N0CALL Test Op'), findsOneWidget);
    expect(find.text('N0CALL Edited Op'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // Each refs edit re-derives the logging row's controls from the draft, and
  // a close that keeps nothing writes nothing for the stream to correct them
  // with: without the re-derive, the row keeps the fields of a ref the
  // operation does not have.
  testWidgets('a close that keeps nothing asks again for the controls of the refs the operation kept', (tester) async {
    addTearDown(AppClock.instance.reset);
    final asked = <String>[];
    final (_, operation) = await _pumpOpenSheet(
      tester,
      stubs: {
        'activity:*:loggingControls': (Object? args) {
          asked.add('$args');
          return <Map<String, dynamic>>[];
        },
      },
    );
    _editInSheet(
      tester,
      Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'pota/activation', 'ref': 'K-1234'},
          ],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(asked.last, contains('K-1234'), reason: 'the draft asked for its own controls');

    AppClock.instance.travel(delta: const Duration(days: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing);
    expect(asked.last, isNot(contains('K-1234')));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // A tap outside the sheet takes the same way out as Escape. Saving through a
  // path of its own, it would retry a failing save forever where Escape
  // leaves.
  testWidgets('a tap outside the sheet saves its edits, and leaves when the save is refused', (tester) async {
    addTearDown(AppClock.instance.reset);
    final (services, operation) = await _pumpOpenSheet(tester);
    _editInSheet(tester, Operation(uuid: operation.uuid, data: {...operation.data, 'userTitle': 'Edited Op'}));
    await tester.pump();

    await tester.tapAt(const Offset(990, 790));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing);
    expect((await services.operations.get(operation.uuid))!.userTitle, 'Edited Op');

    await tester.tap(find.text('N0CALL Edited Op'));
    await tester.pumpAndSettle();
    AppClock.instance.travel(delta: const Duration(days: 1));
    await tester.tapAt(const Offset(990, 790));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // A system back reaches the sheet the way Escape does, through the route's
  // maybePop; without the PopScope it closes the sheet and drops the edit.
  testWidgets('a system back saves the sheet\'s edits and closes it', (tester) async {
    final (services, operation) = await _pumpOpenSheet(tester);
    _editInSheet(tester, Operation(uuid: operation.uuid, data: {...operation.data, 'userTitle': 'Edited Op'}));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing);
    expect((await services.operations.get(operation.uuid))!.userTitle, 'Edited Op');

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
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OperationView(services: services, operationUuid: operation.uuid),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
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

      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: OperationView(services: services, operationUuid: operation.uuid),
          ),
        ),
      );
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

    // A fresh State for the second width: `pumpAt` builds new services, and
    // a State kept across them is a view holding two operations' worth of
    // subscriptions — not a thing the app ever does, and it never settles.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));

    // Wide: the AppBar's own default leading slot (56, explicit — see
    // _leadingWidthFor), wider than the button it holds, plus the title's
    // own inset.
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
    final extensions = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'ref:pota/activation:null:suggestOperationTitle': {'at': 'K-1234'},
      }),
    )..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final created = await services.operations.create(stationCall: 'N0CALL');
    await services.operations.saveData(
      Operation(
        uuid: created.uuid,
        data: {
          ...created.data,
          'refs': [
            {'type': 'pota/activation', 'ref': 'K-1234'},
          ],
        },
      ),
    );
    final operation = (await services.operations.get(created.uuid))!;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
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

  testWidgets('on wide the logging pane\'s title bar holds the settings menu', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byIcon(MdiIcons.tune)),
      findsNothing,
      reason: 'no longer a global AppBar action',
    );
    // Exactly one — the logging pane stands alone in its group, with no
    // other tab to hide behind, unlike the narrow case.
    expect(find.byIcon(MdiIcons.tune), findsOneWidget);

    await tester.tap(find.byIcon(MdiIcons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Show RST fields'), findsOneWidget);

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

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.widgetWithIcon(IconButton, MdiIcons.tune);
    expect(button, findsOneWidget, reason: 'the QSOs tab is on top in the narrow arrangement');
    final chromeHeight = LayoutDensity.chromeHeightOf(tester.element(button));
    expect(tester.getSize(button).height, chromeHeight, reason: 'the indicator must not take its width out of the tab\'s own control');

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

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
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
    expect(find.text('Exports'), findsNothing, reason: "the widened ref line priced the labels out of BOTH rows, the sheet's copy included");

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

/// One park to add, offered the way the activity hooks offer it, and no
/// operation controls.
class _SuggestingExtensions extends ExtensionServiceWithFakeHost {
  _SuggestingExtensions()
    : super(
        FakeExtensionHost({
          'activity:*:suggest': [
            {
              'key': 'pota',
              'ok': true,
              'value': [
                {
                  'type': 'pota',
                  'ref': 'US-0001',
                  'label': 'POTA US-0001',
                  // Long on purpose: the header's ref line has to outgrow its
                  // title line for the title control to get any wider at all.
                  'shortLabel': 'POTA US-0001 A Very Long Park Name',
                  'name': 'Some Park',
                },
              ],
            },
          ],
        }),
      );

  @override
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async =>
      (controls: const <Map<String, dynamic>>[], loadFailed: false);
}

/// Holds the ref title hook [saveAndClose] waits on — a slow extension host —
/// once [hold] is set; until then it answers at once, so the view's own
/// retitles on open go through.
class _HeldTitleHook {
  bool hold = false;
  int heldCalls = 0;
  final _answer = Completer<Object?>();

  Future<Object?> call(Object? args) async {
    if (!hold) return {'at': 'K-1234'};
    heldCalls++;
    return _answer.future;
  }

  void release() => _answer.complete({'at': 'K-1234'});
}

Future<_HeldTitleHook> _pumpSheetWithHeldTitle(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final held = _HeldTitleHook();
  final HaLoHarness(:services, :settings) = await makeHaLoServices(stubs: {'ref:pota/activation:null:suggestOperationTitle': held.call});
  await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
  final created = await services.operations.create(stationCall: 'N0CALL');
  await services.operations.saveData(
    Operation(
      uuid: created.uuid,
      data: {
        ...created.data,
        'refs': [
          {'type': 'pota/activation', 'ref': 'K-1234'},
        ],
      },
    ),
  );

  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: created.uuid),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('N0CALL at K-1234'));
  await tester.pumpAndSettle();
  expect(find.byType(OperationSheet), findsOneWidget);
  return held;
}

/// An edit made inside the open operation sheet, as the sheet's own edits land:
/// on the sheet's operation (what its save writes) and reported to the view
/// (what the header shows meanwhile).
void _editInSheet(WidgetTester tester, Operation edited) {
  tester.state<OperationSheetState>(find.byType(OperationSheet)).updateOperation(edited);
  tester.widget<OperationSheet>(find.byType(OperationSheet)).onOperationChanged!(edited);
}

/// The Operation view on a fresh operation (N0CALL, "Test Op"), with its setup
/// sheet open.
Future<(HaLoServices, Operation)> _pumpOpenSheet(WidgetTester tester, {Map<String, Object?> stubs = const {}}) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final HaLoHarness(:services, :settings) = await makeHaLoServices(stubs: stubs);
  await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
  final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('N0CALL Test Op'));
  await tester.pumpAndSettle();
  return (services, operation);
}

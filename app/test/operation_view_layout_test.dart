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

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
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

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('operationHeaderGrab')), findsNothing);
    // The 3-dots and accept morphing control next to the title/subtitle.
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_HeaderDotsAndAcceptControl'), findsOneWidget);

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

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    // Otherwise the 'operation-sheet' onboarding flow auto-opens the sheet
    // on mount (issue #348), which would race with the tap below.
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
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

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
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

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    // Otherwise the 'operation-sheet' onboarding flow auto-opens the sheet
    // on mount (issue #348), which sits over the whole header/tab area and
    // swallows every tap below it.
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.tune)),
      findsOneWidget,
      reason: 'lives with the tab bar now, not as a standalone action — but see the next check',
    );
    expect(
      find.ancestor(of: find.byIcon(Icons.tune), matching: find.byType(Tab)),
      findsNothing,
      reason: "overlaid next to the tab, not nested inside its Tab — nesting would compete with "
          "the tab bar's own tap handling for the same tap and the button would never receive one",
    );
    expect(find.byIcon(Icons.tune), findsOneWidget, reason: 'QSOs is the selected tab on mount');

    // The button's own space stays reserved even when hidden (so the tab
    // doesn't reflow on selection changes) — it fades via AnimatedOpacity
    // rather than actually leaving the tree, which keeps the Icon mounted
    // regardless. So `find.byIcon` alone can't tell hidden from shown;
    // check the opacity that actually controls it (pumpAndSettle above
    // and below waits out the fade, so it's always fully settled here).
    double tuneOpacity() =>
        tester.widget<AnimatedOpacity>(find.ancestor(of: find.byIcon(Icons.tune), matching: find.byType(AnimatedOpacity))).opacity;

    await tester.tap(find.text('SPOTS'));
    await tester.pumpAndSettle();
    expect(tuneOpacity(), 0, reason: 'hidden once QSOs is no longer the active tab');

    await tester.tap(find.text('0 QSOs'));
    await tester.pumpAndSettle();
    expect(tuneOpacity(), 1, reason: 'reappears once QSOs is selected again');

    // The menu itself is unchanged — same toggle, same effect.
    await tester.tap(find.byIcon(Icons.tune));
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

      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
      final services = HaLoServices(db, settings, extensions: extensions);
      final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
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

      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
      final services = HaLoServices(db, settings, extensions: extensions);
      final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Show more settings'));
      await tester.tap(find.text('Show more settings'));
      await tester.pumpAndSettle();

      expect(settings.leftieMode, isFalse);
      final leftieSwitch = find.descendant(of: find.widgetWithText(ListTile, 'Leftie Mode'), matching: find.byType(Switch));
      await tester.ensureVisible(leftieSwitch);
      await tester.tap(leftieSwitch);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'the semantics-tree assertion used to fire exactly here');
      expect(settings.leftieMode, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('the dots/accept control animates back on close, not an instant snap to plain dots', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    // _HeaderDotsAndAcceptControl's own width IS its progress (10px..28px,
    // see operation_view.dart) — reading it black-box like this avoids
    // needing access to the private painter's progress field.
    final control = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_HeaderDotsAndAcceptControl');

    await tester.tap(find.text('N0CALL Test Op'));
    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsOneWidget);
    expect(tester.getSize(control).width, closeTo(28, 0.5), reason: 'fully morphed to the accept circle while open');

    // Closing: saveAndClose() awaits saveData() before calling pop(), so a
    // couple of bare pumps first flush that gap; the awaited showTopModalPane
    // future (and so _openOperationSheet's `finally`) resolves at pop() time
    // — well before the route's 600ms reverse transition finishes — which is
    // exactly the bug this pins: _sheetAnimation must keep reflecting the
    // reversing route animation for that whole stretch, not go null the
    // instant pop() is called.
    await tester.tap(find.text('N0CALL Test Op'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final midWidth = tester.getSize(control).width;
    expect(midWidth, greaterThan(10.5), reason: 'still mid-close — must not have already snapped back to plain dots');
    expect(midWidth, lessThan(27.5), reason: 'and must not still read as fully open either — genuinely animating');

    await tester.pumpAndSettle();
    expect(find.byType(OperationSheet), findsNothing);
    expect(tester.getSize(control).width, closeTo(10, 0.5), reason: 'settles back to plain dots once fully closed');

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
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({
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

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(MockExtensionHost(const {}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);
    final operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: OperationView(services: services, operationUuid: operation.uuid),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.tune)),
      findsNothing,
      reason: 'no longer a global AppBar action',
    );
    // Exactly one — the split's own logging pane always shows (it has no
    // other tab to hide behind), unlike the narrow case.
    expect(find.byIcon(Icons.tune), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Show RST fields'), findsOneWidget);

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

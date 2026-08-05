// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two registry-driven settings panels: Common Settings must show ONLY
// elements flagged `common: true` (settings_registry.dart's
// elementIsCommon) — the whole point of the panel is a short list — while
// All Settings must show every declared group (core + sync) plus each
// extension-contributed panel as its own section. Both surfaces (and
// standalone extension panels) also honor `environment`, which is a
// platform gate, not a Common-vs-All one: an excluded field disappears
// everywhere on that platform.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

Future<HaLoServices> makeServices() async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = ExtensionServiceWithMockHost(
    const MockExtensionHost({
      'settingsPanel:*:getPanels': [
        {
          'key': 'myext',
          'ok': true,
          'value': {
            'panelKey': 'myext',
            'hookKey': 'myext',
            'extensionKey': 'myext',
            'title': 'My Extension',
            'kind': 'dynamic',
            'order': 50,
          },
        },
      ],
      'settingsPanel:myext:getDefinition': {
        'title': 'My Extension',
        'elements': [
          {'type': 'field', 'fieldType': 'text', 'key': 'foo', 'label': 'Foo Field'},
          // common: true — should reach Common Preferences too, same as a
          // core group's flagged field.
          {'type': 'field', 'fieldType': 'text', 'key': 'bar', 'label': 'Bar Field', 'common': true},
          // environment excludes macOS specifically — a platform gate, not
          // a Common-vs-All one: it should vanish from EVERY settings
          // surface on macOS, and show normally elsewhere.
          {'type': 'field', 'fieldType': 'text', 'key': 'baz', 'label': 'Baz Field', 'environment': '-macos'},
        ],
      },
    }),
  )..settings = settings;
  return HaLoServices(db, settings, extensions: extensions);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Common Settings shows only the whitelisted fields', (tester) async {
    // debugDefaultTargetPlatformOverride must be back to null before the test
    // body returns — the framework's invariant check runs ahead of any
    // tearDown — hence try/finally rather than addTearDown (see
    // window_chrome_service_test.dart).
    //
    // Desktop: the numbers row is mobile-only, so it must stay out of Common
    // Settings (and the whole Logging section with it) here.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      // Tall enough that the full two-line settings sidebar renders without
      // scrolling — ListView.builder won't build off-screen rows.
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final services = await makeServices();
      await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
      await tester.pumpAndSettle();

      // Whitelisted: the User Interface section, and Privacy (issue #183 —
      // folded in as its own section, no longer a separate top-level panel).
      expect(find.text('User Interface'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Share app usage data'), findsOneWidget);
      expect(find.text('Share operation data'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);

      // Not whitelisted: logging fields and the sync toggle only appear under
      // All Settings.
      expect(find.text('Leftie Mode'), findsNothing);
      expect(find.text('Logging'), findsNothing);
      expect(find.text('Numbers Row'), findsNothing);
      expect(find.text('Enable Sync'), findsNothing);

      // An extension's own `common: true` field surfaces here too, under
      // its own panel title — but only that field, not its unflagged
      // sibling. Baz Field is excluded on macOS by `environment` regardless
      // of common-ness (checked more directly below). "My Extension" itself
      // shows twice: the sidebar's own always-on nav entry for the panel,
      // plus this embedded section's title.
      expect(find.text('My Extension'), findsNWidgets(2), reason: 'sidebar + section title');
      expect(find.text('Bar Field'), findsOneWidget);
      expect(find.text('Foo Field'), findsNothing);
      expect(find.text('Baz Field'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('environment excludes a field from every settings surface on the excluded platform', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final services = await makeServices();
      await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
      await tester.pumpAndSettle();

      // Common Preferences: excluded regardless of common-ness.
      expect(find.text('Baz Field'), findsNothing);

      await tester.tap(find.text('All Settings'));
      await tester.pumpAndSettle();

      // All Settings too — environment is a platform gate, not a
      // Common-vs-All one. Foo Field (no environment restriction) still
      // shows, proving the section itself did load.
      expect(find.text('Foo Field'), findsOneWidget);
      expect(find.text('Baz Field'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('environment shows a field on every platform it does not exclude', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final services = await makeServices();
      await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Baz Field'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Common Settings adds the numbers row on mobile only', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final services = await makeServices();
      await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
      await tester.pumpAndSettle();

      // The numbers row toggle is whitelisted on mobile, pulling the whole
      // Logging section into Common Settings — but only its own field, not
      // the rest of the group's settings.
      expect(find.text('Logging'), findsOneWidget);
      expect(find.text('Numbers Row'), findsOneWidget);
      expect(find.text('Leftie Mode'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('All Settings shows every group plus extension sections', (tester) async {
    // Tall enough that the full two-line settings sidebar renders without
    // scrolling — ListView.builder won't build off-screen rows.
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = await makeServices();
    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All Settings'));
    await tester.pumpAndSettle();

    // Core groups, in registry order.
    expect(find.text('User Interface'), findsOneWidget);
    expect(find.text('Logging'), findsOneWidget);
    expect(find.text('Leftie Mode'), findsOneWidget);
    expect(find.text('Country Flags'), findsOneWidget);
    // 'Privacy' is no longer a sidebar item (issue #183) — just the group's
    // section header, here in All Settings.
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Enable Sync'), findsOneWidget);

    // Bands resolves its $core.bands system list and summarizes the
    // default selection.
    expect(find.textContaining('80m, 40m, 30m'), findsOneWidget);

    // The extension panel renders as its own section with its fields.
    expect(find.text('My Extension'), findsWidgets);
    expect(find.text('Foo Field'), findsOneWidget);

    // The search filters every section by key/title/description; sections
    // with no match vanish, headers included.
    final search = find.byKey(const ValueKey('all-settings-search'));
    expect(search, findsOneWidget);
    await tester.enterText(search, 'leftie');
    await tester.pumpAndSettle();
    expect(find.text('Leftie Mode'), findsOneWidget);
    expect(find.text('Logging'), findsOneWidget);
    expect(find.text('Theme Mode'), findsNothing);
    expect(find.text('User Interface'), findsNothing);
    expect(find.text('Foo Field'), findsNothing);
    // Only the sidebar's copy of the extension title remains.
    expect(find.text('My Extension'), findsOneWidget);

    // Matching an extension field brings its section (and title) back.
    await tester.enterText(search, 'foo');
    await tester.pumpAndSettle();
    expect(find.text('Foo Field'), findsOneWidget);
    expect(find.text('My Extension'), findsNWidgets(2), reason: 'sidebar + section title');
    expect(find.text('Leftie Mode'), findsNothing);

    // The X clears the filter.
    await tester.tap(find.byIcon(MdiIcons.close));
    await tester.pumpAndSettle();
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Leftie Mode'), findsOneWidget);
  });

  testWidgets('HALO-146: filtering hides sections, it never unmounts them', (tester) async {
    // The rule the search depends on, and the one thing a widget test can
    // actually see of this bug. Dropping a filtered-out section from the tree
    // disposes every FocusNode and TextEditingController its FormRenderer
    // owns, and on web that teardown takes the browser's text-input element
    // with it — focus falls back to the route's scope and the operator's next
    // keystrokes are swallowed while they are still typing the query.
    //
    // Counted with skipOffstage: false, because a hidden section is exactly
    // what we want to still find. `find.text` above keeps its default (offstage
    // skipped), which is why the visible filtering assertions still hold.
    //
    // Not reproducible in a widget test, on any platform: `flutter test
    // --platform chrome` drives text input through the test binding rather
    // than a DOM element, so no browser focus event ever fires there. This
    // pins the invariant instead — the mechanism, not the symptom.
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = await makeServices();
    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Settings'));
    await tester.pumpAndSettle();

    final mounted = find.byType(FormRenderer, skipOffstage: false);
    final before = tester.widgetList(mounted).length;
    expect(before, greaterThan(1), reason: 'test setup: several sections are on screen');

    // A query matching one core setting and no extension panel: the screen
    // empties down to a single row, and without the rule above the tree would
    // empty with it.
    await tester.enterText(find.byKey(const ValueKey('all-settings-search')), 'leftie');
    await tester.pumpAndSettle();

    expect(find.text('Leftie Mode'), findsOneWidget, reason: 'test setup: the query still matches something');
    expect(find.text('Theme Mode'), findsNothing, reason: 'test setup: and hides the rest');
    expect(
      tester.widgetList(mounted).length,
      before,
      reason: 'a filtered-out section must stay in the tree — unmounting it disposes the focus '
          'nodes that the operator is typing against',
    );
  });
}

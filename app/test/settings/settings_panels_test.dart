// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The registry-driven Settings panel: its leading Common Preferences category
// must show ONLY elements flagged `common: true` (settings_registry.dart's
// elementIsCommon) — the whole point of that category is a short list —
// while the categories below it must cover every declared group (core +
// sync) plus each extension-contributed panel. Every surface (standalone
// extension panels included) also honors `environment`, which is a
// platform gate, not a common-vs-everything one: an excluded field
// disappears everywhere on that platform.
//
// Category visibility is asserted with `.hitTestable()`, never bare
// `find.text`: a collapsed category stays MOUNTED (see _settingsCategory),
// so its rows are findable while being no part of what the operator sees.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/settings/settings_scan.dart';
import 'package:ham2k_logger/views/accordion_section.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/halo_test_support.dart';

Future<HaLoServices> makeServices({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({...prefs});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = ExtensionServiceWithFakeHost(
    FakeExtensionHost({
      'settingsPanel:*:getPanels': [
        {
          'key': 'myext',
          'ok': true,
          'value': {'panelKey': 'myext', 'hookKey': 'myext', 'extensionKey': 'myext', 'title': 'My Extension', 'kind': 'dynamic', 'order': 50},
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
          // a common-vs-everything one: it should vanish from EVERY
          // settings surface on macOS, and show normally elsewhere.
          {'type': 'field', 'fieldType': 'text', 'key': 'baz', 'label': 'Baz Field', 'environment': '-macos'},
        ],
      },
    }),
  )..settings = settings;
  return HaLoServices(db, settings, extensions: extensions);
}

/// One extension panel whose single field's value comes from a store this
/// host owns, so a commit through the service is VISIBLE on a reload — the
/// const-map mock serves the same definition forever and cannot show that.
class _StatefulPanelHost implements ExtensionHost {
  String value = 'before';

  /// Grows the panel's element set, the way a toggle that reveals its
  /// sub-options does.
  bool extraField = false;

  @override
  Future<dynamic> invokeHook(String category, {String? key, required String method, Object? args, Duration timeout = const Duration(seconds: 10)}) async {
    if (method == 'getDefinition') {
      return {
        'title': 'My Extension',
        'elements': [
          {'type': 'field', 'fieldType': 'text', 'key': 'bar', 'label': 'Bar Field', 'value': value, 'common': true},
          if (extraField) {'type': 'field', 'fieldType': 'text', 'key': 'extra', 'label': 'Extra Field', 'value': '', 'common': true},
        ],
      };
    }
    if (method == 'onChangeField') {
      value = ((args as Map)['value'] as String?) ?? value;
      return null;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async => method != 'getPanels'
      ? const []
      : [
          {
            'key': 'myext',
            'ok': true,
            'value': {'panelKey': 'myext', 'hookKey': 'myext', 'extensionKey': 'myext', 'title': 'My Extension', 'kind': 'dynamic', 'order': 50},
          },
        ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ServiceWithHost extends ExtensionService {
  final ExtensionHost _mock;

  _ServiceWithHost(this._mock);

  @override
  ExtensionHost? get host => _mock;

  @override
  Future<void> start() async {}
}

/// The panel's categories are what the operator can see and reach, which a
/// bare `find.text` does not answer here.
Finder shown(String text) => find.text(text).hitTestable();

Future<void> pumpSettings(WidgetTester tester, HaLoServices services, {Size size = const Size(1000, 4000)}) async {
  // Tall enough that the whole settings list renders without scrolling: the
  // sidebar is a ListView.builder and builds only what is on screen, so a
  // shorter viewport reads as a missing setting rather than an unscrolled
  // one. A test about SCROLLING passes a short one.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: SettingsView(services: services)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Common Preferences shows only the whitelisted fields', (tester) async {
    // debugDefaultTargetPlatformOverride must be back to null before the test
    // body returns — the framework's invariant check runs ahead of any
    // tearDown — hence try/finally rather than addTearDown (see
    // window_chrome_service_test.dart).
    //
    // Desktop: the numbers row is mobile-only, so it must stay out of Common
    // Settings here.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final services = await makeServices();
      await pumpSettings(tester, services);

      // Common Preferences leads the panel and opens on a first run.
      expect(shown('Common Preferences'), findsOneWidget);

      // Whitelisted, under a section heading naming the group each row came
      // from — rows drawn from a dozen groups need saying where they belong.
      expect(shown('User Interface'), findsWidgets, reason: 'the heading over the rows it contributed');
      expect(shown('Theme Mode'), findsOneWidget);
      expect(shown('Preferred Bands'), findsOneWidget);
      expect(shown('Preferred Modes'), findsOneWidget);

      // Not whitelisted: these reach the operator only through their own
      // group's category, which is collapsed. Privacy's consent toggles and
      // policy links are among them — looked up once, not what an operator
      // comes to Settings for.
      expect(shown('Leftie Mode'), findsNothing);
      expect(shown('Numbers Row'), findsNothing);
      expect(shown('Enable Sync'), findsNothing);
      expect(shown('Share app usage data'), findsNothing);
      expect(shown('Privacy Policy'), findsNothing);

      // An extension's own `common: true` field surfaces here too — but
      // only that field, not its unflagged sibling. Baz Field is excluded
      // on macOS by `environment` regardless of common-ness (checked more
      // directly below).
      expect(shown('Bar Field'), findsOneWidget);
      expect(shown('Foo Field'), findsNothing);
      expect(shown('Baz Field'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('environment excludes a field from every settings surface on the excluded platform', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final services = await makeServices();
      await pumpSettings(tester, services);

      // Common Preferences: excluded regardless of common-ness.
      expect(shown('Baz Field'), findsNothing);

      await tester.tap(shown('My Extension').last);
      await tester.pumpAndSettle();

      // The extension's own category too — environment is a platform gate,
      // not a common-vs-everything one. Foo Field (no environment
      // restriction) still shows, proving the category itself did load.
      expect(shown('Foo Field'), findsOneWidget);
      expect(shown('Baz Field'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // The trap is on both sides of `listed: false`: a message field back on
  // the Radio rows buries the radio's own toggles, and one taken off the
  // declarations as well is lost to SET/SHOW. And the search has only the
  // keyer rows' aliases to reach them by.
  testWidgets('Radio shows one row per keyer, opening its dialog, and none of the message fields', (tester) async {
    final services = await makeServices(
      prefs: {
        'experiments': jsonEncode({
          'gato': {'enabled': true},
          'keyer': {'enabled': true},
        }),
      },
    );
    await pumpSettings(tester, services);
    await tester.tap(shown('Radio').last);
    await tester.pumpAndSettle();

    expect(shown('CW Keyer'), findsOneWidget);
    expect(shown('Phone Keyer'), findsOneWidget);
    expect(shown('F1'), findsNothing, reason: 'a CW message field');
    expect(shown('Repeat Message ❶'), findsNothing);
    expect(shown('Voice memory 1 label'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'repeat');
    await tester.pumpAndSettle();
    expect(shown('CW Keyer'), findsOneWidget, reason: 'the search reaches the repeat through its row');
    expect(shown('Phone Keyer'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    final declared = await scanSettings(services);
    expect(declared.map((entry) => entry.element['key']), containsAll(['cwMessage1', 'cwRepeatDelay', 'voiceMessageLabel1', 'voiceRepeatDelay']));

    await tester.tap(shown('CW Keyer'));
    await tester.pumpAndSettle();
    // F1 is the dialog's first message row; the Settings list had none.
    expect(find.textContaining('F1').hitTestable(), findsWidgets, reason: 'the CW Keyer dialog opened');
  });

  testWidgets('environment shows a field on every platform it does not exclude', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final services = await makeServices();
      await pumpSettings(tester, services);

      await tester.tap(shown('My Extension').last);
      await tester.pumpAndSettle();

      expect(shown('Baz Field'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Common Preferences adds the numbers row on mobile only', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final services = await makeServices();
      await pumpSettings(tester, services);

      // The numbers row toggle is whitelisted on mobile, pulling a Logging
      // band into Common Preferences — but only its own field, not the rest of
      // the group's settings.
      expect(shown('Numbers Row'), findsOneWidget);
      expect(shown('Leftie Mode'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('every group and extension panel has a category, one open at a time', (tester) async {
    final services = await makeServices();
    await pumpSettings(tester, services);

    // Core groups, in registry order, each under its own heading.
    expect(shown('User Interface'), findsWidgets);
    expect(shown('Logging'), findsWidgets);
    expect(shown('Privacy'), findsWidgets);
    expect(shown('Cloud Sync'), findsWidgets);
    // The extension panel is a category of its own, beside the sidebar's
    // always-on nav entry for the same panel and the section heading its
    // `common: true` field earns inside Common Preferences.
    expect(shown('My Extension'), findsNWidgets(3), reason: 'sidebar + common heading + category band');

    // Privacy sits below every other category, extension-contributed ones
    // included: categories sort by ONE order, so a group declaring itself
    // last is last rather than merely last among the core groups.
    double headingY(Finder finder) => tester.getTopLeft(finder).dy;
    expect(headingY(shown('Privacy')), greaterThan(headingY(shown('My Extension').last)));

    // Opening Logging shows its rows and closes Common Preferences — one open
    // category at a time.
    await tester.tap(shown('Logging').last);
    await tester.pumpAndSettle();
    expect(shown('Leftie Mode'), findsOneWidget);
    expect(shown('Country Flags'), findsOneWidget);
    expect(shown('Theme Mode'), findsNothing, reason: 'Common Preferences closed when Logging opened');
    // Bands, in the same group, resolves its $core.bands system list and
    // summarizes the default selection.
    expect(find.textContaining('80m, 40m, 30m').hitTestable(), findsOneWidget);

    // Tapping the open category's own heading closes it, leaving nothing
    // open.
    await tester.tap(shown('Logging').last);
    await tester.pumpAndSettle();
    expect(shown('Leftie Mode'), findsNothing);
  });

  testWidgets('the open category is remembered across visits', (tester) async {
    final services = await makeServices();
    await pumpSettings(tester, services);

    await tester.tap(shown('Logging').last);
    await tester.pumpAndSettle();
    expect(shown('Leftie Mode'), findsOneWidget);

    // A fresh SettingsView over the same prefs — what re-entering Settings
    // amounts to. Without the stored key it would open on Common Preferences.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(home: SettingsView(services: services)),
      ),
    );
    await tester.pumpAndSettle();

    expect(shown('Leftie Mode'), findsOneWidget);
    expect(shown('Theme Mode'), findsNothing);
  });

  testWidgets('a search opens every matching category, and clearing it restores the single one', (tester) async {
    final services = await makeServices();
    await pumpSettings(tester, services);

    final search = find.byKey(const ValueKey('settings-search'));
    expect(search, findsOneWidget);

    // A query matching a setting in a category that was CLOSED: the search
    // opens it, so the match is readable without hunting for its heading.
    await tester.enterText(search, 'leftie');
    await tester.pumpAndSettle();
    expect(shown('Leftie Mode'), findsOneWidget);
    expect(shown('Logging'), findsOneWidget);
    // Categories with no match vanish, heading included — and Common
    // Settings stays out of a search entirely: its rows are copies of ones
    // the categories below already offer, so it would answer every query
    // twice.
    expect(shown('Theme Mode'), findsNothing);
    expect(shown('User Interface'), findsNothing);
    expect(shown('Common Preferences'), findsNothing);
    expect(shown('Foo Field'), findsNothing);
    expect(shown('My Extension'), findsOneWidget, reason: 'only the sidebar entry remains');

    // Matching an extension field brings its category (and heading) back.
    await tester.enterText(search, 'foo');
    await tester.pumpAndSettle();
    expect(shown('Foo Field'), findsOneWidget);
    expect(shown('My Extension'), findsNWidgets(2), reason: 'sidebar + category heading');
    expect(shown('Leftie Mode'), findsNothing);

    // A category the operator closes while the query stands stays closed.
    await tester.tap(shown('My Extension').last);
    await tester.pumpAndSettle();
    expect(shown('Foo Field'), findsNothing);

    // The X clears the filter — and the panel returns to one open category,
    // not to everything the search had opened.
    await tester.tap(find.byIcon(MdiIcons.close));
    await tester.pumpAndSettle();
    expect(shown('Common Preferences'), findsOneWidget);
    expect(shown('Theme Mode'), findsOneWidget);
    expect(shown('Leftie Mode'), findsNothing);
  });

  testWidgets('a commit reaches the OTHER copy of the same extension field', (tester) async {
    // The panel mounts an extension's `common: true` field twice — once
    // under Common Preferences, once in the extension's own category — and
    // neither commit path notifies SettingsService: a Tier 1 commit writes
    // straight to prefs, a Tier 2 one hands the value to the extension. So
    // the copy that did not commit has nothing to learn the change from,
    // and would write its stale value back on the next interaction,
    // silently reverting what the operator typed. `settingsGeneration` is
    // what tells it.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final host = _StatefulPanelHost();
    final services = HaLoServices(db, settings, extensions: _ServiceWithHost(host)..settings = settings);
    await pumpSettings(tester, services);

    // skipOffstage: false — the extension's own category is shut, and a shut
    // category paints nothing while still holding its form (that is what
    // CollapsingSliver is for). Mounted is what matters here: it is the copy
    // nobody can see that would write its stale value back.
    Finder mounted(String text) => find.text(text, skipOffstage: false);
    expect(mounted('before'), findsNWidgets(2), reason: 'test setup: both copies of the field are mounted');

    await services.extensions.commitSettingsFieldValue(kind: 'dynamic', hookKey: 'myext', panelKey: 'myext', fieldKey: 'bar', value: 'after', state: const {});
    await tester.pumpAndSettle();

    expect(mounted('after'), findsNWidgets(2), reason: 'both copies show what was committed');
    expect(mounted('before'), findsNothing);
  });

  testWidgets('an open category holds the top of the pane while its own rows scroll under it', (tester) async {
    // The whole point of the sliver panel: an operator scrolling through a
    // category's rows can still see which category they are in, and which
    // section of it — a list of settings all of which look alike otherwise.
    final services = await makeServices();
    await pumpSettings(tester, services, size: const Size(1000, 700));

    final list = find.byType(CustomScrollView).first;
    final categoryBand = tester.getTopLeft(shown('Common Preferences')).dy;
    final firstSection = tester.getTopLeft(shown('User Interface')).dy;
    final nextSection = tester.getTopLeft(shown('Logging')).dy;
    // Stacked, not overlapping: the section band starts where the category
    // band ends. A pinned band that ignored the one above it would be
    // painted over by it.
    expect(firstSection, greaterThan(categoryBand));
    expect(firstSection, lessThan(nextSection));

    await tester.drag(list, const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(shown('Common Preferences')).dy, categoryBand, reason: 'the category band holds');
    expect(tester.getTopLeft(shown('User Interface')).dy, firstSection, reason: 'and so does the band of the section being scrolled through');
    // The section that has not reached the top yet travels with its rows —
    // pinning is per section, not the whole panel's bands piled up.
    final logging = tester.getTopLeft(shown('Logging')).dy;
    expect(logging, lessThan(nextSection), reason: 'it scrolled');
    expect(logging, greaterThan(firstSection), reason: 'and has not pinned yet — its own rows are still below');
  });

  testWidgets('opening a category brings it to the top, so its first row is what shows', (tester) async {
    // A category half way down the panel would otherwise open with most of
    // itself below the fold — and the one that closed in the same gesture
    // (only one is open at a time) has moved it again by the time its rows
    // appear, so where it lands is not something the operator can predict.
    final services = await makeServices();
    await pumpSettings(tester, services, size: const Size(1000, 400));

    final list = find.byType(CustomScrollView).first;
    final listTop = tester.getTopLeft(list).dy;

    // Shut the category that opens on a first run, so what is left is a
    // stack of bands — and 'Logging' names one of them rather than the
    // section of the same name inside Common Preferences.
    await tester.tap(shown('Common Preferences'));
    await tester.pumpAndSettle();

    // The BAND, not the title inside it: the band is what lands at the top,
    // and its title sits a padding's worth below that.
    Finder loggingBand() => find.ancestor(of: shown('Logging'), matching: find.byType(AccordionHeader)).first;
    expect(tester.getTopLeft(loggingBand()).dy, greaterThan(listTop + 100), reason: 'test setup: the category sits well down the panel');

    await tester.tap(shown('Logging'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(loggingBand()).dy, moreOrLessEquals(listTop, epsilon: 1));
    expect(shown('Leftie Mode'), findsOneWidget, reason: 'and its own rows are what is under it');
  });

  testWidgets('HALO-530: a filtered list is rebuilt from scratch, with every form carried over', (tester) async {
    // Two rules that pull opposite ways, and this is where they meet.
    //
    // HALO-530: on web a click is hit-tested against the accessibility DOM,
    // and a list rebuilt IN PLACE leaves those elements holding the old
    // arrangement's geometry — so a filtered list takes a key derived from
    // its contents, and a changed one builds a fresh scroll view
    // (docs/quirks.md). HALO-146: dropping a settings form disposes the
    // focus nodes the operator is typing against, which on web empties the
    // search field they are typing INTO.
    //
    // The categories are globally keyed, so the framework MOVES them into
    // the new scroll view instead. Drop those keys and every State here is
    // rebuilt — which is what this asserts, since the semantics DOM itself
    // is not something a widget test can see.
    final services = await makeServices();
    await pumpSettings(tester, services);

    final scrollView = find.byType(CustomScrollView).first;
    final keyBefore = tester.widget<CustomScrollView>(scrollView).key;
    final formsBefore = tester.stateList<State>(find.byType(FormRenderer, skipOffstage: false)).toList();
    expect(formsBefore, isNotEmpty, reason: 'test setup: some forms are mounted');

    await tester.enterText(find.byKey(const ValueKey('settings-search')), 'leftie');
    await tester.pumpAndSettle();

    expect(
      tester.widget<CustomScrollView>(find.byType(CustomScrollView).first).key,
      isNot(keyBefore),
      reason: 'a filtered list must build a fresh scroll view, or the click lands on a neighbouring row',
    );
    final formsAfter = tester.stateList<State>(find.byType(FormRenderer, skipOffstage: false)).toList();
    expect(formsAfter.length, formsBefore.length);
    for (var i = 0; i < formsAfter.length; i++) {
      expect(
        identical(formsAfter[i], formsBefore[i]),
        isTrue,
        reason:
            'the rebuilt scroll view must adopt the forms, not replace them — a replaced form '
            'disposes the focus nodes the operator is typing against',
      );
    }
  });

  testWidgets('HALO-530: a category that grows rows under itself rebuilds the list too', (tester) async {
    // The other half of the keying rule, and the one the query cannot cover:
    // a group's own element set changes when a toggle reveals sub-options
    // (Numbers Row does), and every row below it moves with the query and
    // the open category both untouched. The category is the only thing that
    // can see that, so it reports it.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final host = _StatefulPanelHost();
    final services = HaLoServices(db, settings, extensions: _ServiceWithHost(host)..settings = settings);
    await pumpSettings(tester, services);

    final keyBefore = tester.widget<CustomScrollView>(find.byType(CustomScrollView).first).key;

    // A commit that changes the DEFINITION, not just a value — the field
    // count is what moves the rows below it.
    host.extraField = true;
    await services.extensions.commitSettingsFieldValue(kind: 'dynamic', hookKey: 'myext', panelKey: 'myext', fieldKey: 'bar', value: 'before', state: const {});
    await tester.pumpAndSettle();

    expect(shown('Extra Field'), findsWidgets, reason: 'test setup: the definition grew a row');
    expect(
      tester.widget<CustomScrollView>(find.byType(CustomScrollView).first).key,
      isNot(keyBefore),
      reason: 'rows moved, so the scroll view must be rebuilt — otherwise the click lands on a neighbour',
    );
  });

  testWidgets('HALO-146: filtering hides categories, it never unmounts them', (tester) async {
    // The rule the search depends on, and the one thing a widget test can
    // actually see of this bug. Dropping a filtered-out category from the tree
    // disposes every FocusNode and TextEditingController its FormRenderer
    // owns, and on web that teardown takes the browser's text-input element
    // with it — focus falls back to the route's scope and the operator's next
    // keystrokes are swallowed while they are still typing the query.
    //
    // Counted with skipOffstage: false, because a hidden category is exactly
    // what we want to still find. `shown` above keeps its own meaning — what
    // the operator sees — which is why the visible filtering assertions still
    // hold.
    //
    // Not reproducible in a widget test, on any platform: `flutter test
    // --platform chrome` drives text input through the test binding rather
    // than a DOM element, so no browser focus event ever fires there. This
    // pins the invariant instead — the mechanism, not the symptom.
    final services = await makeServices();
    await pumpSettings(tester, services);

    final mounted = find.byType(FormRenderer, skipOffstage: false);
    final before = tester.widgetList(mounted).length;
    expect(before, greaterThan(1), reason: 'test setup: several categories are in the tree');

    // A query matching one core setting and no extension panel: the screen
    // empties down to a single row, and without the rule above the tree would
    // empty with it.
    await tester.enterText(find.byKey(const ValueKey('settings-search')), 'leftie');
    await tester.pumpAndSettle();

    expect(shown('Leftie Mode'), findsOneWidget, reason: 'test setup: the query still matches something');
    expect(shown('Theme Mode'), findsNothing, reason: 'test setup: and hides the rest');
    expect(
      tester.widgetList(mounted).length,
      before,
      reason:
          'a filtered-out category must stay in the tree — unmounting it disposes the focus '
          'nodes that the operator is typing against',
    );
  });

  testWidgets('HALO-151: the search box matches by subsequence, like the SET command', (tester) async {
    // The box and the commands share one matcher (settings_catalog.dart), but
    // sharing it is not the same as the SCREEN being wired to it — this drives
    // the real search field to prove the wiring, not just the predicate.
    final services = await makeServices();
    await pumpSettings(tester, services);

    // Initials, not a substring of anything: l-f-t-m appears in order in
    // "Leftie Mode" and the old substring filter found nothing for it.
    // Initials of a three-word label — no substring of anything.
    await tester.enterText(find.byKey(const ValueKey('settings-search')), 'sgf');
    await tester.pumpAndSettle();
    expect(shown('Show Grid field'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('settings-search')), 'lftm');
    await tester.pumpAndSettle();

    expect(shown('Leftie Mode'), findsOneWidget);
    expect(shown('Theme Mode'), findsNothing, reason: 'still a filter — unrelated settings stay hidden');
  });
}

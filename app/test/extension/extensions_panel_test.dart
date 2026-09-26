// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension Management (Issue #25). The load-bearing rules: core extensions
// never appear in the panel; the rest group per category with the search
// field at the BOTTOM filtering by name/key/description; a toggle persists
// an override in the store that's kept OUTSIDE the app-settings groups; and
// enabled resolution is core || override ?? enabledByDefault.

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/flags_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/views/extension_install_flow.dart';
import 'package:ham2k_logger/views/extensions_panel.dart';

import '../support/halo_test_support.dart';

const _testExtensions = [
  ExtensionInfo(key: 'adif', file: 'adif.js', core: true, name: 'ADIF Export'),
  ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'Parks on the Air', category: 'activity', description: 'Park references and spots'),
  ExtensionInfo(key: 'sota', file: 'sota.js', core: false, name: 'Summits on the Air', category: 'activity'),
  ExtensionInfo(key: 'qrz', file: 'qrz.js', core: false, name: 'QRZ.com Callsign Lookups', category: 'lookup', enabledByDefault: false),
  ExtensionInfo(key: 'gated-panel', file: 'gated-panel.js', core: false, name: 'Gated Panel', category: 'dashboard', experiments: ['an-experiment']),
];

/// A catalog over a MockClient: the panel fetches on open, and the default
/// CatalogService would reach catalog.ham2k.net from the test.
CatalogService _catalog(Future<http.Response> Function(http.Request) handler) =>
    CatalogService(client: MockClient(handler), userAgent: () async => 'Ham2K Logger/test', locale: () => 'en');

CatalogService _emptyCatalog() => _catalog((_) async => http.Response(jsonEncode({'extensions': []}), 200));

Map<String, Object?> _entry(String key, String name, {String version = '1.0.0', Map<String, Object?>? relevance, String? accentColor}) => {
  'key': key,
  'name': name,
  'version': version,
  'sha256': 'a' * 64,
  'bundleUrl': 'https://catalog.ham2k.net/api/v1/extensions/$key/versions/$version/bundle',
  'category': 'activity',
  'description': 'About $name',
  'relevance': ?relevance,
  'accentColor': ?accentColor,
};

/// A `relevance` whose date is a few days out, read off the same clock the
/// panel ranks against.
///
/// Computed rather than written down: the panel suggests a catalog entry when
/// it is near in date or matches the operator's callsign, so a fixed date
/// would stop being a suggestion the week after it was typed and the test
/// would fail for a reason that has nothing to do with the panel.
Map<String, Object?> _soon({int inDays = 3}) {
  final at = nowUtc().add(Duration(days: inDays));
  final iso =
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';
  return {
    'dates': [iso],
  };
}

/// The keys of the catalog OFFER rows actually built, top to bottom — not
/// the "and N others" row, which is a category's own and named apart so a
/// test about what is offered cannot pass on the row that hides the rest.
List<String> _catalogRowKeys(WidgetTester tester) => [
  for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
    if (tile.key case ValueKey<String>(value: final key) when key.startsWith('catalog-') && !key.startsWith('catalog-more-')) key,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isExtensionEnabled: core always wins; overrides beat defaults', () async {
    SharedPreferences.setMockInitialValues({'extensionOverrides': '{"sota": false, "qrz": true}'});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;

    bool enabled(String key) => extensions.isExtensionEnabled(_testExtensions.firstWhere((e) => e.key == key));

    expect(enabled('adif'), isTrue, reason: 'core is always enabled');
    expect(enabled('pota'), isTrue, reason: 'no override → enabledByDefault true');
    expect(enabled('sota'), isFalse, reason: 'override false wins');
    expect(enabled('qrz'), isTrue, reason: 'override true beats enabledByDefault false');
  });

  test('disabling stamps disabledSince; re-enabling clears it', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(_testExtensions);
    HaLoServices(db, settings, extensions: extensions);

    await extensions.setExtensionsEnabled({'pota': false});
    expect(settings.extensionDisabledSince.keys, contains('pota'));
    // qrz defaults off → also stamped by the recompute.
    expect(settings.extensionDisabledSince.keys, contains('qrz'));

    await extensions.setExtensionsEnabled({'pota': true});
    expect(settings.extensionDisabledSince.keys, isNot(contains('pota')));
    await db.close();
  });

  test('a key naming an extension deleted from the build is pruned, once the index has loaded', () async {
    // What a migrated install looks like after the extension it toggled is
    // later removed from the build entirely (not just disabled) — e.g. HamDB.
    SharedPreferences.setMockInitialValues({'extensionOverrides': '{"gone": false, "pota": true}', 'extensionDisabledSince': '{"gone": 1000, "sota": 2000}'});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    // 'gone' is absent from the index. 'sota' stays disabled throughout (no
    // override, enabledByDefault: false), so its disabledSince entry must
    // survive the prune untouched — isolating what's under test from the
    // pre-existing per-extension stamp/clear loop above.
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'Parks on the Air'),
      ExtensionInfo(key: 'sota', file: 'sota.js', core: false, name: 'Summits on the Air', enabledByDefault: false),
    ]);
    HaLoServices(db, settings, extensions: extensions);

    await extensions.applyExtensionAvailability();

    expect(settings.extensionOverrides.containsKey('gone'), isFalse);
    expect(settings.extensionDisabledSince.containsKey('gone'), isFalse);
    expect(settings.extensionOverrides['pota'], isTrue, reason: 'a key for a still-known extension is untouched');
    expect(settings.extensionDisabledSince['sota'], 2000, reason: 'a key for a still-known extension is untouched');
  });

  test('never prunes before the extension index has loaded — an empty availableExtensions means unloaded, not empty', () async {
    SharedPreferences.setMockInitialValues({'extensionOverrides': '{"pota": true, "sota": true}'});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    // No debugSetAvailableExtensions call — availableExtensions is still [].
    HaLoServices(db, settings, extensions: extensions);

    await extensions.applyExtensionAvailability();

    expect(settings.extensionOverrides, {
      'pota': true,
      'sota': true,
    }, reason: 'overrides set before the index loads must survive, not read as naming deleted extensions');
  });

  test('ExtensionInfo.fromJson: a stale metadata-less index degrades to core', () {
    final info = ExtensionInfo.fromJson(const {'key': 'mystery', 'file': 'mystery.js'});
    expect(info.core, isTrue);
    expect(info.name, 'mystery');
    expect(info.enabledByDefault, isTrue);
    expect(info.experiments, isEmpty, reason: 'no gate → always available');
  });

  test('experiment gating hides the extension but keeps the stored override', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(_testExtensions);
    final gated = _testExtensions.firstWhere((e) => e.key == 'gated-panel');

    expect(extensions.isExtensionAvailable(gated), isFalse, reason: 'experiment off → gated');

    await settings.setExperimentEnabled('an-experiment', true);
    expect(extensions.isExtensionAvailable(gated), isTrue);

    // The user enables it, then the experiment goes away: the override must
    // survive the round trip — turning the experiment back on restores the
    // extension as enabled without the user touching anything.
    await extensions.setExtensionsEnabled({'gated-panel': true});
    await settings.setExperimentEnabled('an-experiment', false);
    await extensions.applyExtensionAvailability();
    expect(extensions.isExtensionAvailable(gated), isFalse);
    expect(settings.extensionOverrides['gated-panel'], isTrue, reason: 'gating must not rewrite overrides');
    // Gated counts as disabled for the data-purge grace clock.
    expect(settings.extensionDisabledSince.keys, contains('gated-panel'));

    await settings.setExperimentEnabled('an-experiment', true);
    await extensions.applyExtensionAvailability();
    expect(extensions.isExtensionAvailable(gated), isTrue);
    expect(extensions.isExtensionEnabled(gated), isTrue);
    expect(settings.extensionDisabledSince.keys, isNot(contains('gated-panel')));
  });

  test('listActiveExtensions surfaces the kernel-info listing', () async {
    final extensions = ExtensionServiceWithFakeHost(
      FakeExtensionHost({
        'runtime:kernel:listExtensions': [
          {'key': 'pota', 'name': 'Parks on the Air', 'version': '0.0.1'},
        ],
      }),
    );
    final listed = await extensions.listActiveExtensions();
    expect(listed.single['key'], 'pota');
    expect(listed.single['version'], '0.0.1');
  });

  testWidgets('panel hides core, groups per category, searches from the top field, and toggles persist', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings, :extensions) = await makeHaLoServices(catalog: _emptyCatalog());
    extensions.debugSetAvailableExtensions(_testExtensions);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Core never listed; categories render in order with their headers.
    expect(find.text('ADIF Export'), findsNothing);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Callsign Lookups'), findsOneWidget);
    expect(find.text('Parks on the Air'), findsOneWidget);

    // QRZ defaults off, POTA on.
    bool switchValue(String key) => tester.widget<Switch>(find.descendant(of: find.byKey(ValueKey('extension-$key')), matching: find.byType(Switch))).value;
    expect(switchValue('qrz'), isFalse);
    expect(switchValue('pota'), isTrue);

    // The top search filters across groups; empty groups lose headers.
    await tester.enterText(find.byKey(const ValueKey('extensions-search')), 'summits');
    await tester.pumpAndSettle();
    expect(find.text('Summits on the Air'), findsOneWidget);
    expect(find.text('Parks on the Air'), findsNothing);
    expect(find.text('Callsign Lookups'), findsNothing);
    await tester.tap(find.byIcon(MdiIcons.close));
    await tester.pumpAndSettle();

    // Toggling persists an override in the dedicated store (not the
    // settings groups). Tapped on the row rather than on the switch: the row
    // is what the operator hits, and the tile carries the toggle now that the
    // switch shares its trailing with the line under it.
    await tester.tap(find.byKey(const ValueKey('extension-sota')));
    await tester.pumpAndSettle();
    expect(settings.extensionOverrides, {'sota': false});
    expect(settings.extensionSettingsGroups(), isEmpty);
    expect(switchValue('sota'), isFalse);
  });

  testWidgets('panel hides experiment-gated extensions until the experiment is enabled', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings, :extensions) = await makeHaLoServices(catalog: _emptyCatalog());
    extensions.debugSetAvailableExtensions(_testExtensions);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Gated, not disabled: neither the tile nor its category header shows.
    expect(find.text('Gated Panel'), findsNothing);
    expect(find.text('Dashboard Panels'), findsNothing);

    // The panel listens to settings, so flipping the experiment reveals the
    // extension live, with its stored (default) state.
    await settings.setExperimentEnabled('an-experiment', true);
    await tester.pumpAndSettle();
    expect(find.text('Gated Panel'), findsOneWidget);

    await settings.setExperimentEnabled('an-experiment', false);
    await tester.pumpAndSettle();
    expect(find.text('Gated Panel'), findsNothing);
  });

  testWidgets('the catalog is suggestions under the same headings, nearest first', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(
        key: 'k2hrc-llota',
        file: 'index.js',
        core: false,
        name: 'LLOTA',
        category: 'activity',
        source: ExtensionSource.installed,
        version: '1.0.0',
      ),
      ExtensionInfo(
        key: 'zz-current',
        file: 'index.js',
        core: false,
        name: 'ZZ Current',
        category: 'activity',
        source: ExtensionSource.installed,
        version: '2.0.0',
      ),
    ]);
    // The operator is K, so a `K` entry leads and a `CE` one trails; the
    // fetcher answers nothing so no flags server is reached.
    final flags = FlagsService(
      statusBar: StatusBarService(settings.prefs),
      fetcher: (_) async => null,
      annotate: (_) async => {'entityPrefix': 'K', 'continent': 'NA', 'countryCode': 'us', 'ituRegion': 2},
    );
    await flags.refreshForCall('K1ABC');
    expect(flags.operatorGeo?.entityPrefix, 'K');

    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [
            _entry('zz-world', 'Zulu World'),
            _entry(
              'ce-only',
              'Chile Only',
              relevance: {
                'entities': ['CE'],
              },
            ),
            _entry('k2hrc-llota', 'LLOTA (catalog)', version: '1.1.0'),
            _entry('zz-current', 'ZZ Current (catalog)', version: '2.0.0'),
            _entry('aa-world', 'Alpha World', relevance: _soon()),
            _entry(
              'k-only',
              'Kilo Only',
              relevance: {
                'entities': ['K'],
              },
            ),
          ],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog, flags: flags);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Near in date first, then matching this callsign; alphabetical within a
    // band. Everything else is not a SUGGESTION and is not listed at all:
    // `zz-world` is worldwide and undated, and `ce-only` is Chile's — the
    // operator is K.
    //
    // Mutated to a flat alphabetical sort, Alpha World and Kilo Only swap.
    expect(_catalogRowKeys(tester), ['catalog-aa-world', 'catalog-k-only']);
    // An entry for something already installed is not offered beside it: the
    // two would name the same extension twice under one heading, and the
    // update belongs to the installed row.
    expect(find.byKey(const ValueKey('catalog-k2hrc-llota')), findsNothing);
    expect(find.byKey(const ValueKey('catalog-zz-current')), findsNothing);
    // There is no section of its own any more.
    expect(find.text('Catalog'), findsNothing);

    Finder inRow(String key, Finder what) => find.descendant(of: find.byKey(ValueKey('catalog-$key')), matching: what);
    // Every suggestion is something to install; there is no longer a catalog
    // row that cannot be acted on, because those were the ones for extensions
    // the operator already had.
    expect(inRow('aa-world', find.widgetWithText(OutlinedButton, 'Install')), findsOneWidget);
    expect(inRow('k-only', find.widgetWithText(OutlinedButton, 'Install')), findsOneWidget);
    // And it is offered as a job to finish, at the top, rather than only as a
    // badge to notice halfway down.
    expect(find.text('Pending Updates'), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-k2hrc-llota')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Update all'), findsOneWidget);

    // The installed row carries the update badge, which is where an update
    // lives now.
    expect(find.descendant(of: find.byKey(const ValueKey('extension-k2hrc-llota')), matching: find.textContaining('Update available')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('extension-zz-current')), matching: find.textContaining('Update available')), findsNothing);

    // The catalog rows are part of the row set the list is keyed by
    // (docs/quirks.md): without them, the fetch resolving changes the rows
    // under a key that says nothing changed, and web clicks land on the
    // pre-fetch geometry.
    expect(
      tester.widget<SectionedListView>(find.byType(SectionedListView)).key,
      listContentsKey([
        'k2hrc-llota',
        'zz-current',
        // `k2hrc-llota` is installed at 1.0.0 against the catalog's 1.1.0, so
        // it heads the list in Pending Updates as well as carrying its badge.
        'pending:k2hrc-llota',
        for (final key in _catalogRowKeys(tester)) 'catalog:${key.substring('catalog-'.length)}',
        // The "and N others" row is a row too, and tapping it changes the set
        // under it: left out of the key, the expansion would remount nothing
        // and the clicks would land on the collapsed geometry.
        'more:activity',
      ]),
    );

    // Searching reaches past the suggestions: Chile Only is not offered to a
    // K operator unasked, and is there the moment they ask for it.
    await tester.enterText(find.byKey(const ValueKey('extensions-search')), 'chile');
    await tester.pumpAndSettle();
    expect(_catalogRowKeys(tester), ['catalog-ce-only']);
    expect(find.text('Alpha World'), findsNothing);
    // Still under its own category heading, not gathered into one list.
    expect(find.text('Activities'), findsOneWidget);
  });

  testWidgets('the worldwide programmes are suggested to an operator nothing is known about', (tester) async {
    // The curated set, and the reason it cannot be a `relevance` an author
    // writes: WWBOTA gates on nothing and has no dates, which is exactly the
    // shape of every extension that is NOT a suggestion. Ranked by relevance
    // alone the two are indistinguishable, so `zz-world` below is the
    // mutation check — drop kAlwaysSuggested and WWBOTA joins it in absence
    // rather than the list growing.
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const []);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [_entry('zz-world', 'Zulu World'), _entry('ham2k-wwbota', 'WWBOTA', accentColor: '#5A6B72'), _entry('ham2k-llota', 'LLOTA')],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_catalogRowKeys(tester), ['catalog-ham2k-llota', 'catalog-ham2k-wwbota']);

    // The manifest's own accent, carried all the way from the listing row: a
    // programme is the same square of colour here as on the catalog site.
    // Without the parse the tile is the neutral fallback and nothing else
    // about the row changes.
    final glyph = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-ham2k-wwbota')),
        matching: find.descendant(of: find.byType(ExtensionIconTile), matching: find.byType(Icon)),
      ),
    );
    expect(glyph.color, const Color(0xFF5A6B72));
    // On the row's own ground, not on a square of the accent: an offer wears
    // the colour in its glyph, and the filled tile is what the operator owns.
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('catalog-ham2k-wwbota')),
        matching: find.descendant(of: find.byType(ExtensionIconTile), matching: find.byType(Container)),
      ),
    );
    expect(box.decoration, isNull);

    // And it is faded, because nothing here is installed: an offer at full
    // strength claims a place in the panel beside the operator's own.
    expect(
      tester.widget<Opacity>(find.descendant(of: find.byKey(const ValueKey('catalog-ham2k-wwbota')), matching: find.byType(Opacity))).opacity,
      kUninstalledIconOpacity,
    );
  });

  testWidgets('a dated extension outside its window is not suggested, whoever the operator is', (tester) async {
    // The trap this exists for: `tx-party` is a Texas party and the operator
    // is in Texas, so its geography matches all year — and a suggestion list
    // ranked on geography alone would carry it from one running to the next,
    // 51 weeks of which it has nothing to say. A date is the thing that
    // expires, so where an extension HAS dates they are the whole question.
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const []);
    final flags = FlagsService(
      statusBar: StatusBarService(settings.prefs),
      fetcher: (_) async => null,
      annotate: (_) async => {'entityPrefix': 'K', 'continent': 'NA', 'countryCode': 'us', 'ituRegion': 2},
    );
    await flags.refreshForCall('K1ABC');

    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [
            _entry(
              'tx-party',
              'Texas Party',
              relevance: {
                'entities': ['K'],
                ..._soon(inDays: 180),
              },
            ),
            _entry(
              'tx-soon',
              'Texas Soon',
              relevance: {
                'entities': ['K'],
                ..._soon(inDays: 5),
              },
            ),
            _entry(
              'tx-just-ran',
              'Texas Just Ran',
              relevance: {
                'entities': ['K'],
                ..._soon(inDays: -3),
              },
            ),
            _entry(
              'tx-last-week',
              'Texas Last Week',
              relevance: {
                'entities': ['K'],
                ..._soon(inDays: -4),
              },
            ),
          ],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog, flags: flags);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Five days out and three days past are inside the window; six months out
    // and four days past are not, and their K geography does not save them.
    expect(_catalogRowKeys(tester), ['catalog-tx-just-ran', 'catalog-tx-soon']);
    // The two that are out of season are still THERE, behind the row that
    // says so — held back from the suggestions, not hidden from the panel.
    expect(find.byKey(const ValueKey('catalog-more-activity')), findsOneWidget);
  });

  testWidgets('a category shows five offers, or two once the operator has three of their own', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    // Two installed, so the category is not yet a settled subject.
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(key: 'mine-a', file: 'index.js', core: false, name: 'Mine A', category: 'activity', source: ExtensionSource.installed, version: '1.0.0'),
      ExtensionInfo(key: 'mine-b', file: 'index.js', core: false, name: 'Mine B', category: 'activity', source: ExtensionSource.installed, version: '1.0.0'),
    ]);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [for (var i = 0; i < 8; i++) _entry('offer-$i', 'Offer $i', relevance: _soon())],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_catalogRowKeys(tester).length, 5, reason: 'two installed, so the full five');
    expect(find.text('… and 3 other extensions'), findsOneWidget);
  });

  testWidgets('three of the operator\'s own cuts the offers to two, and the row opens the rest', (tester) async {
    // The same eight offers as above, under a heading the operator has
    // already settled: five suggestions under it is a sales pitch rather than
    // a panel.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(key: 'mine-a', file: 'index.js', core: false, name: 'Mine A', category: 'activity', source: ExtensionSource.installed, version: '1.0.0'),
      ExtensionInfo(key: 'mine-b', file: 'index.js', core: false, name: 'Mine B', category: 'activity', source: ExtensionSource.installed, version: '1.0.0'),
      ExtensionInfo(key: 'mine-c', file: 'index.js', core: false, name: 'Mine C', category: 'activity', source: ExtensionSource.installed, version: '1.0.0'),
    ]);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [for (var i = 0; i < 8; i++) _entry('offer-$i', 'Offer $i', relevance: _soon())],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_catalogRowKeys(tester).length, 2);
    expect(find.text('… and 6 other extensions'), findsOneWidget);

    // And the row opens the category: everything the catalog has under it,
    // suggested or not, and no row left saying there is more.
    await tester.tap(find.byKey(const ValueKey('catalog-more-activity')));
    await tester.pumpAndSettle();
    expect(_catalogRowKeys(tester).length, 8);
    expect(find.byKey(const ValueKey('catalog-more-activity')), findsNothing);
  });

  testWidgets('a category with nothing suggested counts what it has, rather than continuing a list', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const []);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [_entry('zz-world', 'Zulu World')],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing is suggested — worldwide and undated — and the whole category
    // is the one row that says so, which is what makes the catalog reachable
    // without guessing at a name in the search box.
    expect(_catalogRowKeys(tester), isEmpty);
    // "… and 1 other" would continue a list that is not there.
    expect(find.text('1 extension available'), findsOneWidget);
  });

  testWidgets('opening a category leaves the list where the operator was reading', (tester) async {
    // The row that opens a category moves every row beneath it, so the scroll
    // view is rebuilt from scratch — without that, a click on the web lands on
    // a neighbouring row (docs/quirks.md, listContentsKey). A fresh scroll
    // view starts at the top, which throws an operator reading the fourth
    // heading back to the first: the offset has to survive the remount.
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions([
      for (var i = 0; i < 12; i++)
        ExtensionInfo(
          key: 'mine-$i',
          file: 'index.js',
          core: false,
          name: 'Mine $i',
          category: 'activity',
          source: ExtensionSource.installed,
          version: '1.0.0',
        ),
    ]);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [for (var i = 0; i < 8; i++) _entry('offer-$i', 'Offer $i', relevance: _soon())],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double offset() => tester.widget<SectionedListView>(find.byType(SectionedListView)).controller!.offset;

    // Down to where the row is, which is past twelve of the operator's own
    // extensions. The offset has to be well clear of zero or the assertion
    // below would pass on whatever the remount did with it.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('catalog-more-activity')),
      200,
      scrollable: find.descendant(of: find.byType(SectionedListView), matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
    final wasAt = offset();
    expect(wasAt, greaterThan(100), reason: 'the scroll has to actually move the list, or this proves nothing');

    await tester.tap(find.byKey(const ValueKey('catalog-more-activity')));
    await tester.pumpAndSettle();

    // The rows really were rebuilt — the row that opens the category is gone,
    // which only happens once it is open — and the list is still where it was.
    // Mutated to drop the carried offset, this reads 0.
    expect(find.byKey(const ValueKey('catalog-more-activity')), findsNothing);
    expect(offset(), wasAt);
  });

  testWidgets('Update all asks once for the whole job, and nothing happens if the answer is no', (tester) async {
    // The one screen that replaces the per-extension consent the bulk path
    // skips. Declining has to leave every extension where it was — a "no" that
    // still updated the first one would be the worst of both.
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(key: 'one', file: 'index.js', core: false, name: 'One', category: 'activity', source: ExtensionSource.installed, version: '1.0.0'),
      ExtensionInfo(key: 'two', file: 'index.js', core: false, name: 'Two', category: 'activity', source: ExtensionSource.installed, version: '1.0.0'),
    ]);
    var downloads = 0;
    final catalog = _catalog((request) async {
      if (request.url.path.contains('/bundle')) {
        downloads++;
        return http.Response('', 500);
      }
      return http.Response(
        jsonEncode({
          'extensions': [_entry('one', 'One', version: '1.1.0'), _entry('two', 'Two', version: '1.1.0')],
        }),
        200,
      );
    });
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Update all'));
    await tester.pumpAndSettle();
    // Every extension it will take, and what each becomes: the per-extension
    // consent screens it skips rest on this, and the press may have come from
    // a notice that named only two of them.
    expect(find.text('Update 2 extensions?'), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.textContaining('1.0.0 → 1.1.0')), findsNWidgets(2));
    expect(find.descendant(of: find.byType(Dialog), matching: find.textContaining('One')), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.textContaining('Two')), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(downloads, 0, reason: 'declining the job must not start any part of it');
    // And the row is still there to try again.
    expect(find.byKey(const ValueKey('pending-one')), findsOneWidget);
  });

  testWidgets('an update under way shows on its Pending Updates row, which stays once it lands', (tester) async {
    // Update all takes the list one extension at a time, and each landing
    // stops that one being pending. A list recomputed on every rebuild drops
    // the row the moment its update finishes — or, while the runtime
    // restarts, every row at once — and reshuffles the rest under the
    // pointer for the whole of the job.
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    ExtensionInfo installed(String key, String name, String version) =>
        ExtensionInfo(key: key, file: 'index.js', core: false, name: name, category: 'activity', source: ExtensionSource.installed, version: version);
    extensions.debugSetAvailableExtensions([installed('one', 'One', '1.0.0'), installed('two', 'Two', '1.0.0')]);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [_entry('one', 'One', version: '1.1.0'), _entry('two', 'Two', version: '1.1.0')],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pendingOne = find.byKey(const ValueKey('pending-one'));
    expect(find.descendant(of: pendingOne, matching: find.widgetWithText(FilledButton, 'Update')), findsOneWidget);

    // An update of `one`, started from anywhere — this panel, or the notice.
    final landing = Completer<void>();
    final job = services.extensionInstaller.run('one', () async {
      services.extensionInstaller.downloading('one', 'One', 0.5);
      await landing.future;
    });
    await tester.pump();
    // The progress is on the row, mirrored from the footer's own item, and
    // its button is gone: a second press would download it twice.
    expect(find.descendant(of: pendingOne, matching: find.text('Downloading…')), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.descendant(of: pendingOne, matching: find.byType(LinearProgressIndicator))).value, 0.5);
    expect(find.descendant(of: pendingOne, matching: find.byType(FilledButton)), findsNothing);
    // The rest of the list is still the operator's to use.
    expect(find.byKey(const ValueKey('pending-two')), findsOneWidget);

    // It lands.
    extensions.debugSetAvailableExtensions([installed('one', 'One', '1.1.0'), installed('two', 'Two', '1.0.0')]);
    landing.complete();
    await job;
    await settings.setExtensionOverrides({'one': true});
    await tester.pumpAndSettle();

    expect(pendingOne, findsOneWidget, reason: 'a row whose update landed stays until the panel is reopened');
    expect(find.descendant(of: pendingOne, matching: find.text('Updated to 1.1.0')), findsOneWidget);
    expect(find.descendant(of: pendingOne, matching: find.byType(FilledButton)), findsNothing);
    // Update all is still offered for what is left.
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Update all')).onPressed, isNotNull);

    // With the catalog switched off, the held rows go with it: an Update
    // button there would install from a catalog the panel no longer shows.
    await settings.setExperimentEnabled('catalog', false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pending-two')), findsNothing);
    expect(pendingOne, findsNothing);
  });

  testWidgets('Update all takes only what is still behind, and not what is already under way', (tester) async {
    // The notice hands over what the last check offered, and that goes stale:
    // an extension updated from a file since is AHEAD of the offer, and
    // taking the offer anyway downgrades it without a consent screen.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    ExtensionInfo installed(String key, String name, String version) =>
        ExtensionInfo(key: key, file: 'index.js', core: false, name: name, category: 'activity', source: ExtensionSource.installed, version: version);
    extensions.debugSetAvailableExtensions([installed('ahead', 'Ahead', '1.2.0'), installed('busy', 'Busy', '1.0.0'), installed('behind', 'Behind', '1.0.0')]);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [_entry('ahead', 'Ahead', version: '1.1.0'), _entry('busy', 'Busy', version: '1.1.0'), _entry('behind', 'Behind', version: '1.1.0')],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);
    final offered = (await tester.runAsync(() => catalog.fetchCatalog()))!;
    final busy = Completer<void>();
    unawaited(services.extensionInstaller.run('busy', () => busy.future));
    addTearDown(busy.complete);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => updateAllFromCatalog(context, services: services, entries: offered),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Update 1 extension?'), findsOneWidget);
    final dialog = find.byType(Dialog);
    expect(find.descendant(of: dialog, matching: find.textContaining('Behind')), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.textContaining('Ahead')), findsNothing);
    expect(find.descendant(of: dialog, matching: find.textContaining('Busy')), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
  });

  test('reloading the extension list keeps the old one readable until the new one is in hand', () async {
    // Dropped first, the list reads empty for the whole read — every panel
    // over it loses all its rows, and Update all pressed in that window finds
    // nothing installed to update.
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}));
    extensions.debugSetAvailableExtensions(_testExtensions);
    final reload = extensions.reloadAvailableExtensions();
    expect(extensions.availableExtensions, isNotEmpty);
    await reload.catchError((_) {});
  });

  group('Update all with nothing it can take', () {
    Future<(HaLoServices, StatusBarService)> setUp(WidgetTester tester, {required bool experiment}) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await settings.setExperimentEnabled('catalog', experiment);
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
      extensions.debugSetAvailableExtensions(const [
        ExtensionInfo(key: 'ahead', file: 'index.js', core: false, name: 'Ahead', category: 'activity', source: ExtensionSource.installed, version: '1.2.0'),
      ]);
      final services = HaLoServices(db, settings, extensions: extensions, catalog: _emptyCatalog());
      services.statusBar.showNotice(key: CatalogUpdateCheck.noticeKey, text: 'An update is available for Ahead.');
      return (services, services.statusBar);
    }

    Future<void> press(WidgetTester tester, HaLoServices services, List<CatalogEntry> entries) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => updateAllFromCatalog(context, services: services, entries: entries),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    final offer = CatalogEntry.fromJson(_entry('ahead', 'Ahead', version: '1.1.0'))!;

    testWidgets('an offer overtaken since says so and takes the notice down', (tester) async {
      // Installed from a file past what the notice offered: a primary button
      // that then does nothing, and keeps doing nothing, reads as broken.
      final (services, statusBar) = await setUp(tester, experiment: true);
      await press(tester, services, [offer]);
      expect(find.byType(Dialog), findsNothing);
      expect(statusBar.activeNotices.where((n) => n.key == CatalogUpdateCheck.noticeKey), isEmpty);
      expect(statusBar.itemForKey('extensions:updateAll')?.text, 'Your extensions are up to date.');
      await tester.pump(StatusBarService.completedDismissDelay);
    });

    testWidgets('with the catalog switched off it installs nothing, and the notice goes', (tester) async {
      // The notice outlives the experiment it was posted under; its button
      // must not install from a catalog the app no longer shows.
      final (services, statusBar) = await setUp(tester, experiment: false);
      await press(tester, services, [offer]);
      expect(find.byType(Dialog), findsNothing);
      expect(statusBar.activeNotices.where((n) => n.key == CatalogUpdateCheck.noticeKey), isEmpty);
    });
  });

  group('Update all from a notice', () {
    Future<HaLoServices> press(WidgetTester tester, {required List<String> offered, required Set<String> named}) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await settings.setExperimentEnabled('catalog', true);
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
      extensions.debugSetAvailableExtensions([
        for (final key in offered)
          ExtensionInfo(key: key, file: 'index.js', core: false, name: key, category: 'activity', source: ExtensionSource.installed, version: '1.0.0'),
      ]);
      final services = HaLoServices(db, settings, extensions: extensions, catalog: _emptyCatalog());
      services.statusBar.showNotice(key: CatalogUpdateCheck.noticeKey, text: 'updates');
      final entries = [for (final key in offered) CatalogEntry.fromJson(_entry(key, key, version: '1.1.0'))!];
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => updateAllFromCatalog(context, services: services, entries: entries, named: named),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return services;
    }

    bool noticeUp(HaLoServices services) => services.statusBar.activeNotices.any((n) => n.key == CatalogUpdateCheck.noticeKey);

    testWidgets('that named every extension it takes goes ahead without a dialog', (tester) async {
      // The operator pressed Update all under those very names; a dialog
      // listing them again is the app asking twice. The notice coming down is
      // what says the job started.
      final services = await press(tester, offered: ['one', 'two'], named: {'one', 'two'});
      expect(find.byType(Dialog), findsNothing);
      expect(noticeUp(services), isFalse);
    });

    testWidgets('that named only some of them still confirms, naming them all', (tester) async {
      // "One, Two and 1 more": the press agreed to two names and a number, and
      // the third would install on the strength of a count.
      final services = await press(tester, offered: ['one', 'two', 'three'], named: {'one', 'two'});
      expect(find.text('Update 3 extensions?'), findsOneWidget);
      expect(find.descendant(of: find.byType(Dialog), matching: find.textContaining('three')), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(noticeUp(services), isTrue);
    });
  });

  testWidgets('installing an offer leaves the row where it was until the panel is reopened', (tester) async {
    // The row the operator just pressed Install on becomes theirs, and a
    // re-sort there and then takes it out from under the pointer — it would
    // jump from the catalog's half of the heading up into their own. It keeps
    // its place instead, and only a fresh panel sorts again.
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(
        key: 'zzz-mine',
        file: 'index.js',
        core: false,
        name: 'ZZZ Mine',
        category: 'activity',
        source: ExtensionSource.installed,
        version: '1.0.0',
      ),
    ]);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [_entry('aaa-offer', 'AAA Offer', relevance: _soon())],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    List<String> rowOrder() => [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        if (tile.key case ValueKey<String>(value: final key)) key,
    ];
    expect(rowOrder(), ['extension-zzz-mine', 'catalog-aaa-offer']);

    // It arrives installed. Sorted afresh it would LEAD — `AAA Offer` sorts
    // before `ZZZ Mine` and both are installed now — so a list that re-sorts
    // here swaps the two rows under the operator's pointer. It stays put.
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(
        key: 'zzz-mine',
        file: 'index.js',
        core: false,
        name: 'ZZZ Mine',
        category: 'activity',
        source: ExtensionSource.installed,
        version: '1.0.0',
      ),
      ExtensionInfo(
        key: 'aaa-offer',
        file: 'index.js',
        core: false,
        name: 'AAA Offer',
        category: 'activity',
        source: ExtensionSource.installed,
        version: '1.0.0',
      ),
    ]);
    // A settings write is what an install ends with, and what the panel
    // actually rebuilds on — `debugSetAvailableExtensions` notifies nobody.
    await settings.setExtensionOverrides({'aaa-offer': true});
    await tester.pumpAndSettle();
    expect(rowOrder(), ['extension-zzz-mine', 'extension-aaa-offer']);
  });

  testWidgets('install from file sits beside the search field, and still fits the narrowest pane', (tester) async {
    // It is an icon in the search row rather than a labelled button under the
    // list. Two things can go wrong and neither shows up as a failed finder:
    // it can end up left of the field, and at the tightest geometry the app
    // has it can push the field out of the pane.
    tester.view.physicalSize = const Size(2400, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'POTA', category: 'activity')]);
    final services = HaLoServices(db, settings, extensions: extensions, catalog: _emptyCatalog());

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: ThemeData(visualDensity: VisualDensity.compact),
          home: Scaffold(
            body: UiScale(
              scale: 1.90,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 300, height: 700, child: ExtensionsPanel(services: services)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byKey(const ValueKey('extensions-search')));
    final button = tester.getRect(find.byKey(const ValueKey('extensions-install-from-file')));
    expect(button.left, greaterThanOrEqualTo(field.right), reason: 'the button is left of the field it follows');
    expect(button.center.dy, closeTo(field.center.dy, 1), reason: 'the two are not on one line');
    // The pane is 300 logical pixels wide before UiScale; both have to be
    // inside it, or the field is squeezed to nothing off the right edge.
    expect(field.left, greaterThanOrEqualTo(0));
    expect(button.right, lessThanOrEqualTo(tester.getRect(find.byType(ExtensionsPanel)).right + 0.5));
    expect(field.width, greaterThan(0));
  });

  testWidgets('a built-in row says so where the others carry a version, and the line still fits', (tester) async {
    // Off the catalog experiment, because the experiment that shows the
    // Catalog section is the one that withdraws every built-in — the two
    // row shapes cannot appear together, which is why this is its own test.
    //
    // Rendered at the tightest geometry the app has, for the same reason the
    // sibling geometry test does it: this row's control is a bare switch,
    // and a caption squeezed to a sliver under it is still found by
    // find.text and still unreadable.
    tester.view.physicalSize = const Size(2400, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    // The build index carries a version for a built-in extension too, which
    // is what makes this worth a test: rendering it names the app's own
    // build, which no operator can install, update or otherwise act on.
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'Parks on the Air', category: 'activity', version: '26.9.0'),
    ]);
    final services = HaLoServices(db, settings, extensions: extensions, catalog: _emptyCatalog());
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: ThemeData(visualDensity: VisualDensity.compact),
          home: Scaffold(
            body: UiScale(
              scale: 1.90,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 300, height: 700, child: ExtensionsPanel(services: services)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('extension-pota')), matching: find.text('Built in')), findsOneWidget);
    expect(find.textContaining('26.9.0'), findsNothing);
    final theme = Theme.of(tester.element(find.byType(ExtensionsPanel)));
    expect(
      tester.getSize(find.text('Built in')).height,
      greaterThanOrEqualTo(theme.textTheme.bodySmall!.fontSize!),
      reason: '"Built in" is squeezed by the switch above it',
    );
  });

  testWidgets('every row states its version over the control, and the details button opens them', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(
        key: 'k2hrc-llota',
        file: 'index.js',
        core: false,
        name: 'LLOTA',
        category: 'activity',
        source: ExtensionSource.installed,
        version: '1.0.0',
      ),
    ]);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [_entry('k2hrc-llota', 'LLOTA (catalog)', version: '1.1.0'), _entry('aa-world', 'Alpha World', version: '2.3.4', relevance: _soon())],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder inRow(String key, Finder what) => find.descendant(of: find.byKey(ValueKey(key)), matching: what);

    // Installed: what is installed, not what the catalog offers for it —
    // the offer is the catalog row's to state.
    expect(inRow('extension-k2hrc-llota', find.text('1.0.0')), findsOneWidget);
    expect(inRow('extension-k2hrc-llota', find.text('1.1.0')), findsNothing);

    // The version reads on the row's first line, above the switch, not under
    // it. Swapped back, it sits level with the description instead of the
    // name and every row's number moves down a line.
    final versionAt = tester.getRect(inRow('extension-k2hrc-llota', find.text('1.0.0')));
    final switchAt = tester.getRect(inRow('extension-k2hrc-llota', find.byType(Switch)));
    expect(versionAt.center.dy, lessThan(switchAt.center.dy));

    // The row no longer says "Installed": it sits under the same heading as
    // the app's own, so the word said nothing the section did not.
    expect(inRow('extension-k2hrc-llota', find.textContaining('Installed')), findsNothing);

    // Catalog: the version offered, under the Install button. An entry for
    // something already installed is not listed at all, so `k2hrc-llota` has
    // one row and not two.
    expect(inRow('catalog-aa-world', find.text('2.3.4')), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-k2hrc-llota')), findsNothing);
  });

  testWidgets('the line under each control fits the trailing box a ListTile caps', (tester) async {
    // The trap: a ListTile hands its trailing a box of 56 logical pixels
    // less the theme's vertical density — 48 under the desktop default —
    // and never grows the row to fit. A control at its tap-target size (a
    // plain Switch or IconButton is 40 tall, a FilledButton likewise) plus a
    // line of text is 56, so every row would overflow and paint the stripes.
    // Rendered at the tightest geometry the app has: landscape, font scale
    // 1.90, in a narrow pane (docs/design/ui-scaling.md).
    tester.view.physicalSize = const Size(2400, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(
        key: 'k2hrc-llota',
        file: 'index.js',
        core: false,
        name: 'LLOTA',
        category: 'activity',
        source: ExtensionSource.installed,
        version: '1.0.0',
        description: 'Lighthouses on the air',
      ),
    ]);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [_entry('aa-world', 'Alpha World', version: '2.3.4', relevance: _soon())],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          // What every desktop build runs at (ThemeData's adaptive default),
          // and the density the trailing cap is computed from.
          theme: ThemeData(visualDensity: VisualDensity.compact),
          home: Scaffold(
            body: UiScale(
              scale: 1.90,
              child: Align(
                alignment: Alignment.topLeft,
                // A settings pane's width in the logical space 1.90 leaves.
                child: SizedBox(width: 300, height: 700, child: ExtensionsPanel(services: services)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Measured on the line, not on the trailing box: the box is clamped to
    // the cap either way, and the caption is what gives — a control at its
    // tap-target size leaves it a sliver that find.text still finds and the
    // operator cannot read.
    final theme = Theme.of(tester.element(find.byType(ExtensionsPanel)));
    final lineHeight = theme.textTheme.bodySmall!.fontSize!;
    void expectAFullLine(String caption) =>
        expect(tester.getSize(find.text(caption)).height, greaterThanOrEqualTo(lineHeight), reason: '"$caption" is squeezed by the control above it');

    // The built-in row's own shape — a bare switch under the same cap — is
    // measured where it can still be rendered, in the built-in test above:
    // the experiment that puts a Catalog section on screen is the one that
    // takes every built-in row off it.
    expectAFullLine('1.0.0'); // the switch and remove row
    expectAFullLine('2.3.4'); // the install button row
  });

  testWidgets('the operator geo arriving after the panel opened is a new request, and re-ranks the rows', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(_testExtensions);
    // The callsign is annotated AFTER the panel is open — a cold launch
    // opens Settings before the runtime that annotates it is up.
    final flags = FlagsService(
      statusBar: StatusBarService(settings.prefs),
      fetcher: (_) async => null,
      annotate: (_) async => {'entityPrefix': 'K', 'continent': 'NA', 'countryCode': 'us', 'ituRegion': 2},
    );
    final queries = <Map<String, String>>[];
    final catalog = _catalog((request) async {
      queries.add(request.url.queryParameters);
      return http.Response(
        jsonEncode({
          'extensions': [
            _entry('zz-world', 'Zulu World'),
            _entry(
              'k-only',
              'Kilo Only',
              relevance: {
                'entities': ['K'],
              },
            ),
            _entry('aa-world', 'Alpha World', relevance: _soon()),
          ],
        }),
        200,
      );
    });
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog, flags: flags);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Nothing known about the operator, so nothing can be suggested for
    // WHERE they are: only the one that is soon. `zz-world` is worldwide and
    // undated and is never a suggestion; `k-only` is Kilo's, and until the
    // callsign is known that is not this operator.
    expect(_catalogRowKeys(tester), ['catalog-aa-world']);
    expect(queries.single.containsKey('entity'), isFalse);

    // The ranking is the catalog's answer to the geo it was asked with, so
    // the new geo is a new request — a panel that only re-sorted would still
    // be showing the catalog's verdict for an unknown operator. And it is not
    // only an order: Kilo Only was not offered at all a moment ago.
    await flags.refreshForCall('K1ABC');
    await tester.pumpAndSettle();
    expect(queries, hasLength(2));
    expect(queries.last['entity'], 'K');
    expect(_catalogRowKeys(tester), ['catalog-aa-world', 'catalog-k-only']);
  });

  testWidgets('a revoked release has no switch, and says why', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Revoked at the installed version, and switched ON by the operator: the
    // row must not offer a switch that cannot turn it on.
    SharedPreferences.setMockInitialValues({
      'extensionRevoked': jsonEncode({
        'k2hrc-llota': {'version': '1.0.0', 'note': 'It uploads the whole log.'},
      }),
      'extensionOverrides': jsonEncode({'k2hrc-llota': true}),
    });
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(
        key: 'k2hrc-llota',
        file: 'index.js',
        core: false,
        name: 'LLOTA',
        category: 'activity',
        source: ExtensionSource.installed,
        version: '1.0.0',
      ),
      ExtensionInfo(
        key: 'zz-current',
        file: 'index.js',
        core: false,
        name: 'ZZ Current',
        category: 'activity',
        source: ExtensionSource.installed,
        version: '2.0.0',
      ),
    ]);
    final services = HaLoServices(db, settings, extensions: extensions, catalog: _emptyCatalog());

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder inRow(String key, Finder what) => find.descendant(of: find.byKey(ValueKey('extension-$key')), matching: what);
    expect(inRow('k2hrc-llota', find.byType(Switch)), findsNothing);
    expect(inRow('k2hrc-llota', find.textContaining('Revoked')), findsOneWidget);
    expect(inRow('k2hrc-llota', find.textContaining('It uploads the whole log.')), findsOneWidget);
    // The way out stays.
    expect(inRow('k2hrc-llota', find.byType(IconButton)), findsOneWidget);
    // Another installed extension keeps its switch.
    expect(inRow('zz-current', find.byType(Switch)), findsOneWidget);
    expect(inRow('zz-current', find.textContaining('Revoked')), findsNothing);
  });

  testWidgets('the catalog section says when it is loading, and when it could not be read', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(_testExtensions);
    final answer = Completer<http.Response>();
    final services = HaLoServices(db, settings, extensions: extensions, catalog: _catalog((_) => answer.future));

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Loading the catalog…'), findsOneWidget);

    // A 503 is null from the service, and null is not an empty catalog: the
    // section must say so rather than look like nothing is published.
    answer.complete(http.Response('', 503));
    await tester.pumpAndSettle();
    expect(find.text('Loading the catalog…'), findsNothing);
    expect(find.text('Catalog unreachable'), findsOneWidget);
    expect(_catalogRowKeys(tester), isEmpty);
  });

  testWidgets('with the experiment off there is no Catalog section, and the catalog is not asked', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(_testExtensions);
    var requests = 0;
    final catalog = _catalog((_) async {
      requests++;
      return http.Response(
        jsonEncode({
          'extensions': [_entry('aa-world', 'Alpha World', relevance: _soon())],
        }),
        200,
      );
    });
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Hidden entirely — no header, no status line — and NOT fetched: a
    // section that is not built but still asks the catalog is the trap the
    // request count catches, and the text finders cannot.
    expect(find.text('Loading the catalog…'), findsNothing);
    expect(find.text('Catalog unreachable'), findsNothing);
    expect(_catalogRowKeys(tester), isEmpty);
    expect(requests, 0);
    // Install from file is not the catalog's, and stays. It is an icon beside
    // the search field now, so its label lives in the icon's semantics.
    expect(find.byKey(const ValueKey('extensions-install-from-file')), findsOneWidget);

    // Flipped on from the Experiments panel over this one: the fetch the
    // opening skipped happens now, without reopening.
    await settings.setExperimentEnabled('catalog', true);
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(_catalogRowKeys(tester), ['catalog-aa-world']);

    await settings.setExperimentEnabled('catalog', false);
    await tester.pumpAndSettle();
    expect(_catalogRowKeys(tester), isEmpty);
  });

  testWidgets('the details button opens what an extension is, and the way out of it', (tester) async {
    // The row carries a name, a description and a switch. Everything else —
    // where it came from, what it can reach, and removing it — moved behind
    // this button, so if it does not open there is no way to any of it.
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.setExperimentEnabled('catalog', true);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(
        key: 'k2hrc-llota',
        file: 'index.js',
        core: false,
        name: 'LLOTA',
        category: 'activity',
        description: 'Lighthouses on the air',
        source: ExtensionSource.installed,
        version: '1.0.0',
        domains: ['llota.cl'],
        hooks: ['activity', 'ref:llota'],
      ),
    ]);
    final catalog = _catalog(
      (_) async => http.Response(
        jsonEncode({
          'extensions': [_entry('k2hrc-llota', 'LLOTA (catalog)', version: '1.1.0')],
        }),
        200,
      ),
    );
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The bin is gone from the row. It sat beside the switch, one mis-aimed
    // click from a toggle, and the row could not say what would be removed.
    expect(find.descendant(of: find.byKey(const ValueKey('extension-k2hrc-llota')), matching: find.byIcon(MdiIcons.trashCanOutline)), findsNothing);

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('extension-k2hrc-llota')), matching: find.byIcon(MdiIcons.informationOutline)));
    await tester.pumpAndSettle();

    // What it is, and the two things that can be done about it. Update is
    // offered because the catalog has 1.1.0 over the installed 1.0.0 — the
    // same comparison the row's badge makes, so the two cannot disagree.
    Finder inDialog(Finder what) => find.descendant(of: find.byType(HaloDialog), matching: what);
    expect(inDialog(find.text('Version 1.0.0')), findsOneWidget);
    expect(inDialog(find.text('llota.cl')), findsOneWidget, reason: 'the network access it was granted');
    expect(inDialog(find.widgetWithText(TextButton, 'Remove')), findsOneWidget);
    expect(inDialog(find.widgetWithText(FilledButton, 'Update')), findsOneWidget);
  });

  testWidgets('a built-in has details too, and nothing to remove or update', (tester) async {
    // Same button on every row: "what is this and what can it reach" is a
    // fair question about an extension the app ships, and the answer is the
    // one place it is written down.
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'POTA', category: 'activity', description: 'Parks', version: '26.9.0'),
    ]);
    final services = HaLoServices(db, settings, extensions: extensions, catalog: _emptyCatalog());

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('extension-pota')), matching: find.byIcon(MdiIcons.informationOutline)));
    await tester.pumpAndSettle();

    // No version: the app's own build is not a number anybody can act on,
    // and printing it here would invite a comparison with the catalog's.
    Finder inDialog(Finder what) => find.descendant(of: find.byType(HaloDialog), matching: what);
    expect(find.textContaining('26.9.0'), findsNothing);
    expect(inDialog(find.text('Built in')), findsOneWidget);
    expect(inDialog(find.widgetWithText(TextButton, 'Remove')), findsNothing);
    expect(inDialog(find.widgetWithText(FilledButton, 'Update')), findsNothing);
  });

  testWidgets('with the catalog off, details offers no Update the panel could not perform', (tester) async {
    // The row's badge hides when the Catalog section does — a check that ran
    // before the experiment was flipped off leaves a pending update with
    // nowhere to go. The dialog's button reads the same gate, or it would
    // offer to install from a catalog the panel is no longer showing.
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    extensions.debugSetAvailableExtensions(const [
      ExtensionInfo(
        key: 'k2hrc-llota',
        file: 'index.js',
        core: false,
        name: 'LLOTA',
        category: 'activity',
        source: ExtensionSource.installed,
        version: '1.0.0',
      ),
    ]);
    final services = HaLoServices(db, settings, extensions: extensions, catalog: _emptyCatalog());

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: ExtensionsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsNothing, reason: 'the experiment is off');

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('extension-k2hrc-llota')), matching: find.byIcon(MdiIcons.informationOutline)));
    await tester.pumpAndSettle();
    final inDialog = find.descendant(of: find.byType(HaloDialog), matching: find.widgetWithText(FilledButton, 'Update'));
    expect(inDialog, findsNothing);
    // Removing still works: it needs no catalog at all.
    expect(find.descendant(of: find.byType(HaloDialog), matching: find.widgetWithText(TextButton, 'Remove')), findsOneWidget);
  });
}

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
import 'dart:io' show File;

import 'package:archive/archive.dart';
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
import 'package:ham2k_logger/services/extensions/installed_extensions.dart';
import 'package:ham2k_logger/services/extensions/catalog_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/flags_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/views/extension_install_flow.dart';
import 'package:ham2k_logger/views/extensions_panel.dart';
import 'package:ham2k_logger/views/station_rows.dart' show StationPill;

import '../support/halo_test_support.dart';
import '../support/memory_bundle_storage.dart';

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

/// The keys of the catalog OFFER rows the operator can reach, top to bottom.
/// Hit-testable, not merely built: More available keeps its rows mounted
/// while shut, and a test counting built rows would count what it hides.
List<String> _catalogRowKeys(WidgetTester tester) => [
  for (final tile in tester.widgetList<ListTile>(find.byType(ListTile).hitTestable()))
    if (tile.key case ValueKey<String>(value: final key) when key.startsWith('catalog-')) key,
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
    // Under its twin's name too, which is what the pre-load asks.
    expect(settings.extensionOverrides, {'sota': false, 'ham2k-sota': false});
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
        // Every offer, More available's shut ones included: Suggested, then
        // the rest.
        'catalog:aa-world',
        'catalog:k-only',
        'catalog:ce-only',
        'catalog:zz-world',
        // Which sections are open moves every row under them: left out of the
        // key, a fold would remount nothing and the clicks would land on the
        // old geometry.
        'fold:activity:true:false',
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
    // The two that are out of season are still THERE, under More available
    // — held back from the suggestions, not hidden from the panel.
    expect(find.text('More available (2)'), findsOneWidget);
  });

  testWidgets('a category shows five offers, or two once the operator has three of their own', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
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
    expect(find.text('More available (3)'), findsOneWidget);
  });

  testWidgets('three of the operator\'s own cuts the offers to two, and More available opens the rest', (tester) async {
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
    expect(find.text('More available (6)'), findsOneWidget);

    // And More available opens on everything else the catalog has under the
    // heading, suggested or not.
    await tester.tap(find.text('More available (6)'));
    await tester.pumpAndSettle();
    expect(_catalogRowKeys(tester).length, 8);
  });

  testWidgets('a category with nothing suggested counts what it has, rather than continuing a list', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
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
    // is More available, which is what makes the catalog reachable without
    // guessing at a name in the search box.
    expect(_catalogRowKeys(tester), isEmpty);
    // A Suggested heading over nothing would read as a list that failed to load.
    expect(find.text('Suggested'), findsNothing);
    expect(find.text('More available (1)'), findsOneWidget);
  });

  testWidgets('opening More available leaves the list where the operator was reading', (tester) async {
    // Opening a section moves every row beneath it, so the scroll
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
      find.text('More available (6)'),
      200,
      scrollable: find.descendant(of: find.byType(SectionedListView), matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
    final wasAt = offset();
    expect(wasAt, greaterThan(100), reason: 'the scroll has to actually move the list, or this proves nothing');

    final listKey = tester.widget<SectionedListView>(find.byType(SectionedListView)).key;
    await tester.tap(find.text('More available (6)'));
    await tester.pumpAndSettle();

    // The list really was rebuilt — a new row set, so a new key — and is
    // still where it was. Mutated to drop the carried offset, this reads 0.
    expect(tester.widget<SectionedListView>(find.byType(SectionedListView)).key, isNot(listKey));
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
  });

  testWidgets('Update all takes only what is still behind, and not what is already under way', (tester) async {
    // The notice hands over what the last check offered, and that goes stale:
    // an extension updated from a file since is AHEAD of the offer, and
    // taking the offer anyway downgrades it without a consent screen.
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
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
    prepareExtensionServiceForTest(extensions);
    final reload = extensions.reloadAvailableExtensions();
    expect(extensions.availableExtensions, isNotEmpty);
    await reload;
  });

  group('Update all with nothing it can take', () {
    Future<(HaLoServices, StatusBarService)> setUp(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
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
      final (services, statusBar) = await setUp(tester);
      await press(tester, services, [offer]);
      expect(find.byType(Dialog), findsNothing);
      expect(statusBar.activeNotices.where((n) => n.key == CatalogUpdateCheck.noticeKey), isEmpty);
      expect(statusBar.itemForKey('extensions:updateAll')?.text, 'Your extensions are up to date.');
      await tester.pump(StatusBarService.completedDismissDelay);
    });
  });

  group('Update all from a notice', () {
    Future<HaLoServices> press(WidgetTester tester, {required List<String> offered, required Set<String> named}) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
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
    // measured in the built-in test above.
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

  testWidgets('a release the flags force-disable has no switch, and says why', (tester) async {
    // Switched ON by the operator: a switch that cannot turn it on would
    // only say the panel is broken.
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'extensionForceDisabled': jsonEncode({
        'k2hrc-llota': {'note': 'Crashes on start.'},
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

    Finder inRow(Finder what) => find.descendant(of: find.byKey(const ValueKey('extension-k2hrc-llota')), matching: what);
    expect(inRow(find.byType(Switch)), findsNothing);
    expect(inRow(find.textContaining('Disabled by Ham2K')), findsOneWidget);
    expect(inRow(find.textContaining('Crashes on start.')), findsOneWidget);
  });

  testWidgets('the catalog section says when it is loading, and when it could not be read', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
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

  group('catalog tracks', () {
    // Dated soon, so each is suggested rather than tucked behind "and N others".
    Map<String, Object?> onChannel(String key, String name, String version, String channel) => {
      ..._entry(key, name, version: version, relevance: _soon()),
      'channel': channel,
    };

    testWidgets('an install wears its track, is offered updates only from it, and Follow stable puts it back', (tester) async {
      // A developer searching bleeding sees bleeding releases — but an
      // extension that follows stable must not be offered one as its update,
      // or the search setting silently moves installs onto rough releases.
      // The unstable install IS offered its unstable update.
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'developerMode': true,
        'catalogSearchChannel': 'bleeding',
        'extensionInstalledFrom': jsonEncode({
          'ki2d-rough': {'host': kCatalogHost, 'sha256': 'a' * 64, 'version': '1.0.0', 'channel': 'unstable'},
          'ki2d-steady': {'host': kCatalogHost, 'sha256': 'a' * 64, 'version': '1.0.0'},
        }),
      });
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
      extensions.debugSetAvailableExtensions(const [
        ExtensionInfo(
          key: 'ki2d-rough',
          file: 'index.js',
          core: false,
          name: 'Rough',
          category: 'activity',
          source: ExtensionSource.installed,
          version: '1.0.0',
        ),
        ExtensionInfo(
          key: 'ki2d-steady',
          file: 'index.js',
          core: false,
          name: 'Steady',
          category: 'activity',
          source: ExtensionSource.installed,
          version: '1.0.0',
        ),
      ]);
      final listingChannels = <String?>[];
      final catalog = CatalogService(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/updates') return http.Response(jsonEncode({'updates': [], 'revoked': [], 'ignored': []}), 200);
          listingChannels.add(request.url.queryParameters['channel']);
          return http.Response(
            jsonEncode({
              'extensions': [
                onChannel('ki2d-rough', 'Rough', '1.1.0', 'unstable'),
                onChannel('ki2d-steady', 'Steady', '2.0.0', 'bleeding'),
                onChannel('ki2d-new', 'Brand New', '0.1.0', 'bleeding'),
              ],
            }),
            200,
          );
        }),
        settings: settings,
        userAgent: () async => 'Ham2K Logger/test',
        locale: () => 'en',
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

      expect(listingChannels, everyElement('bleeding'));
      Finder inRow(String rowKey, Finder what) => find.descendant(of: find.byKey(ValueKey(rowKey)), matching: what);
      expect(inRow('extension-ki2d-rough', find.text('Unstable')), findsOneWidget);
      expect(inRow('extension-ki2d-steady', find.byType(StationPill)), findsNothing);
      expect(inRow('catalog-ki2d-new', find.text('Bleeding')), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-ki2d-rough')), findsOneWidget);
      expect(find.byKey(const ValueKey('pending-ki2d-steady')), findsNothing);

      await tester.tap(inRow('extension-ki2d-rough', find.byIcon(MdiIcons.informationOutline)));
      await tester.pumpAndSettle();
      expect(find.text('Receives unstable and stable releases'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Follow stable releases only'));
      await tester.pumpAndSettle();

      // Back on stable: no pill, and the unstable release is no longer its
      // update. The record keeps the rest — it is still a catalog install.
      expect(settings.extensionInstalledFrom['ki2d-rough'], {'host': kCatalogHost, 'sha256': 'a' * 64, 'version': '1.0.0'});
      expect(inRow('extension-ki2d-rough', find.byType(StationPill)), findsNothing);
      expect(services.catalog.channelFollowedBy('ki2d-rough'), CatalogChannel.stable);
    });

    /// The full panel over an in-memory store and a catalog whose
    /// `ki2d-my-clock` listing answers with [listing] — the fixture bundle at
    /// 1.2.3 — for a pasted link to install from.
    Future<({HaLoServices services, SettingsService settings, MemoryBundleStorage storage, List<Uri> asked})> linkPanel(
      WidgetTester tester,
      Map<String, Object?> Function(String sha256) listing,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fixture = File('test/fixtures/ki2d-my-clock.h2kext').readAsBytesSync();
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final storage = MemoryBundleStorage();
      final store = InstalledExtensions(builtInKeys: () => const {}, hostSharedModules: const {'i18next': '23.11.5'}, storage: storage);
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))
        ..settings = settings
        ..debugInstalledStore = store;
      extensions.debugSetAvailableExtensions(const []);
      final asked = <Uri>[];
      final catalog = CatalogService(
        client: MockClient((request) async {
          asked.add(request.url);
          if (request.url.path.endsWith('/bundle')) return http.Response.bytes(fixture, 200);
          if (request.url.path == '/api/v1/extensions/ki2d-my-clock') return http.Response(jsonEncode(listing(sha256Hex(fixture))), 200);
          if (request.url.path == '/api/v1/updates') return http.Response(jsonEncode({'updates': [], 'revoked': [], 'ignored': []}), 200);
          return http.Response(jsonEncode({'extensions': []}), 200);
        }),
        settings: settings,
        userAgent: () async => 'Ham2K Logger/test',
        locale: () => 'en',
      );
      final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: Scaffold(body: ExtensionsPanel(services: services)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (services: services, settings: settings, storage: storage, asked: asked);
    }

    Future<void> paste(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const ValueKey('extensions-search')), text);
      await tester.pumpAndSettle();
    }

    /// Lets the download's stream run until [done]. It does not finish on the
    /// fake clock alone, and how long it takes in real time is the machine's
    /// business, so it is polled for rather than given a fixed moment.
    Future<void> downloadUntil(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 500 && !done(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pumpAndSettle();
      }
    }

    final consent = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ConsentDialog');

    /// Presses the link row's Install, through to the consent screen.
    Future<void> installLink(WidgetTester tester) async {
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('extensions-install-link')), matching: find.widgetWithText(FilledButton, 'Install')));
      await tester.pumpAndSettle();
      await downloadUntil(tester, () => consent.evaluate().isNotEmpty);
      expect(consent, findsOneWidget, reason: 'the download finished and the consent screen opened');
    }

    final linkRow = find.byKey(const ValueKey('extensions-install-link'));

    testWidgets('a link pasted into the search box offers its install, and an unstable release warns before anything is written', (tester) async {
      // Pasting is how an operator handed a link reaches an unstable
      // release without changing any setting, so it has to land on the same
      // consent screen — warning included — that the catalog's own link does.
      final panel = await linkPanel(
        tester,
        (sha256) => {
          'key': 'ki2d-my-clock',
          'versions': [
            {
              'version': '1.2.3',
              'sha256': sha256,
              'submissions': [
                {'channel': 'unstable', 'status': 'approved'},
              ],
            },
          ],
        },
      );

      // Only an address an install can use is offered as one: words are a
      // search, and a home page — the catalog's own included — can only end
      // in a refusal.
      for (final notAnInstall in ['clock', 'https://pota.app/', 'https://catalog.ham2k.net/', 'https://example.org/clock.zip']) {
        await paste(tester, notAnInstall);
        expect(linkRow, findsNothing, reason: notAnInstall);
      }
      await paste(tester, 'https://example.org/downloads/clock.h2kext');
      expect(linkRow, findsOneWidget);

      await paste(
        tester,
        'com.ham2k.logger:///install_extension?url=${Uri.encodeComponent('https://catalog.ham2k.net/api/v1/extensions/ki2d-my-clock/versions/1.2.3/bundle')}',
      );
      await installLink(tester);

      // Asked on bleeding, which sees every release: the link already named
      // the version, and its own channel is what is warned about.
      expect(panel.asked.firstWhere((url) => url.path == '/api/v1/extensions/ki2d-my-clock').queryParameters['channel'], 'bleeding');
      expect(find.text(t.extensionsPanel.unstableReleaseWarning), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(panel.storage.files, isEmpty, reason: 'declined: nothing written');
      expect(panel.settings.extensionInstalledFrom, isEmpty);
    });

    testWidgets('an unstable page link that lands on a stable release still follows unstable', (tester) async {
      // The operator chose the extension's unstable page. Its current release
      // there happens to be stable — nothing to warn about — but its next
      // unstable release must still reach them, so the install records the
      // track the link asked for, not the release's.
      final panel = await linkPanel(
        tester,
        (sha256) => {
          'key': 'ki2d-my-clock',
          'versions': [
            {
              'version': '1.2.3',
              'sha256': sha256,
              'submissions': [
                {'channel': 'stable', 'status': 'approved'},
              ],
            },
          ],
          'current': {..._entry('ki2d-my-clock', 'KI2D My Clock', version: '1.2.3'), 'sha256': sha256, 'channel': 'stable'},
        },
      );

      await paste(tester, 'https://catalog.ham2k.net/extensions/ki2d-my-clock?channel=unstable');
      await installLink(tester);
      expect(panel.asked.firstWhere((url) => url.path == '/api/v1/extensions/ki2d-my-clock').queryParameters['channel'], 'unstable');
      expect(find.byType(PreReleaseWarning), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await downloadUntil(tester, () => panel.storage.files.isNotEmpty);
      expect(panel.storage.files.keys, ['ki2d-my-clock']);
      expect(panel.settings.extensionInstalledFrom['ki2d-my-clock']?['channel'], 'unstable');
      // The footer's "Installed" line takes itself down on a timer.
      await tester.pump(StatusBarService.completedDismissDelay);
    });
  });

  group('a replacement the catalog offered', () {
    late List<int> fixture;

    /// The fixture under another key: the extension being replaced.
    List<int> asOldClock() {
      final out = Archive();
      for (final file in ZipDecoder().decodeBytes(fixture).files) {
        if (file.name != 'manifest.json') {
          out.addFile(file);
          continue;
        }
        final manifest = jsonDecode(utf8.decode(file.content as List<int>)) as Map<String, dynamic>;
        final bytes = utf8.encode(jsonEncode({...manifest, 'key': 'ki2d-old-clock', 'name': 'KI2D Old Clock'}));
        out.addFile(ArchiveFile('manifest.json', bytes.length, bytes));
      }
      return ZipEncoder().encode(out);
    }

    testWidgets('sits under Pending Updates, outside Update all, and Replace moves the operator onto it through the consent screen', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      useInMemoryKeychain();

      fixture = File('test/fixtures/ki2d-my-clock.h2kext').readAsBytesSync();
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final storage = MemoryBundleStorage();
      final store = InstalledExtensions(builtInKeys: () => const {}, hostSharedModules: const {'i18next': '23.11.5'}, storage: storage);
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))
        ..settings = settings
        ..debugInstalledStore = store;
      await tester.runAsync(() async {
        await extensions.installBundle(await store.inspect(asOldClock()));
        await settings.setSettingValue('extension_ki2d-old-clock', 'format', '24h');
      });
      extensions.debugSetAvailableExtensions(const [
        ExtensionInfo(
          key: 'ki2d-old-clock',
          file: 'index.js',
          core: false,
          name: 'KI2D Old Clock',
          category: 'activity',
          source: ExtensionSource.installed,
          version: '1.2.3',
        ),
      ]);
      final sha = sha256Hex(fixture);
      final catalog = CatalogService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/bundle')) return http.Response.bytes(fixture, 200);
          if (request.url.path == '/api/v1/updates') {
            return http.Response(
              jsonEncode({
                'updates': [],
                'revoked': [],
                'ignored': [],
                'redirects': [
                  {
                    'from': 'ki2d-old-clock',
                    'to': 'ki2d-my-clock',
                    'note': 'Same clock, new home.',
                    'entry': {..._entry('ki2d-my-clock', 'KI2D My Clock', version: '1.2.3'), 'sha256': sha},
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'extensions': []}), 200);
        }),
        settings: settings,
        userAgent: () async => 'Ham2K Logger/test',
        locale: () => 'en',
      );
      final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: Scaffold(body: ExtensionsPanel(services: services)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('redirect-ki2d-old-clock'));
      expect(find.descendant(of: row, matching: find.text('Replaced by KI2D My Clock · Same clock, new home.')), findsOneWidget);
      // Each replacement is a new extension asking consent of its own: Update
      // all with nothing else pending has nothing to take.
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Update all')).onPressed, isNull);

      // Polled with plain pumps: the row's progress bar is indeterminate
      // while the download runs, and never lets pumpAndSettle settle.
      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 500 && !done(); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await tester.tap(find.descendant(of: row, matching: find.widgetWithText(FilledButton, 'Replace')));
      final consent = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ConsentDialog');
      await until(() => consent.evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      expect(consent, findsOneWidget, reason: 'the replacement asks, like any install');
      expect(storage.files.keys, ['ki2d-old-clock'], reason: 'nothing moves before the operator agrees');

      await tester.tap(find.widgetWithText(FilledButton, 'Install'));
      await until(() => !storage.files.containsKey('ki2d-old-clock') && services.catalogUpdateCheck.pendingRedirects.isEmpty);
      expect(storage.files.keys, ['ki2d-my-clock']);
      expect(settings.settingsGroup('extension_ki2d-my-clock'), {'format': '24h'});
      expect(services.catalogUpdateCheck.pendingRedirects, isEmpty);
      await tester.pump(StatusBarService.completedDismissDelay);
    });
  });

  group('folding', () {
    // One installed row and eight offers under one heading: five suggested,
    // the rest under More available.
    Future<HaLoServices> pumpPanel(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(prefs);
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
      extensions.debugSetAvailableExtensions(const [
        ExtensionInfo(key: 'mine', file: 'index.js', core: false, name: 'Mine', category: 'activity', source: ExtensionSource.installed, version: '1.0.0'),
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
      return services;
    }

    Finder mine() => find.byKey(const ValueKey('extension-mine')).hitTestable();

    // The operator's own rows lead every category, open: a panel that opened
    // on shut categories would hide the switches people come here for.
    testWidgets('a category starts open, its own rows leading, More available shut', (tester) async {
      await pumpPanel(tester);
      expect(mine(), findsOneWidget);
      expect(find.text('Suggested'), findsOneWidget);
      expect(_catalogRowKeys(tester), hasLength(5));
      expect(find.text('More available (3)'), findsOneWidget);
    });

    // A fold that came back open on the next visit would make folding a chore
    // to repeat every time.
    testWidgets('the operator\'s folds outlast the panel', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.text('More available (3)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();
      expect(mine(), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      await pumpPanel(tester, prefs: {for (final key in prefs.getKeys()) key: prefs.get(key)!});
      expect(mine(), findsNothing, reason: 'the category stays shut');
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();
      expect(_catalogRowKeys(tester), hasLength(8), reason: 'and More available stays open');
    });

    // A query answering from inside a shut section would say "no matches" for
    // something that is right there.
    testWidgets('a search opens every section with a match, and clearing it puts the folds back', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();
      expect(_catalogRowKeys(tester), isEmpty);

      await tester.enterText(find.byKey(const ValueKey('extensions-search')), 'offer');
      await tester.pumpAndSettle();
      expect(_catalogRowKeys(tester), hasLength(8));

      await tester.enterText(find.byKey(const ValueKey('extensions-search')), '');
      await tester.pumpAndSettle();
      expect(_catalogRowKeys(tester), isEmpty);
    });

    // Searching opens More available; installing from there and clearing the
    // box shuts it again. An installed row that kept its offer's place there
    // would vanish from under the operator who just installed it.
    testWidgets('an extension installed from a search stays in view when the search is cleared', (tester) async {
      final services = await pumpPanel(tester);
      final suggested = _catalogRowKeys(tester).toSet();
      await tester.enterText(find.byKey(const ValueKey('extensions-search')), 'offer');
      await tester.pumpAndSettle();
      final key = _catalogRowKeys(tester).firstWhere((row) => !suggested.contains(row)).substring('catalog-'.length);

      (services.extensions as ExtensionServiceWithFakeHost).debugSetAvailableExtensions([
        const ExtensionInfo(
          key: 'mine',
          file: 'index.js',
          core: false,
          name: 'Mine',
          category: 'activity',
          source: ExtensionSource.installed,
          version: '1.0.0',
        ),
        ExtensionInfo(key: key, file: 'index.js', core: false, name: key, category: 'activity', source: ExtensionSource.installed, version: '1.0.0'),
      ]);
      await services.settings.setExtensionOverrides({key: true});
      await tester.enterText(find.byKey(const ValueKey('extensions-search')), '');
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('extension-$key')).hitTestable(), findsOneWidget);
      expect(find.text('More available (2)'), findsOneWidget, reason: 'it counts what is still on offer');
    });
  });
}

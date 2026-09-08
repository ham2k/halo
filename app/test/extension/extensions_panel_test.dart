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

import 'package:ham2k_logger/config/version.dart' show Edition;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/catalog_service.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/flags_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/views/extensions_panel.dart';

import '../support/halo_test_support.dart';

const _testExtensions = [
  ExtensionInfo(key: 'adif', file: 'adif.js', core: true, name: 'ADIF Export'),
  ExtensionInfo(
      key: 'pota', file: 'pota.js', core: false, name: 'Parks on the Air', category: 'activity',
      description: 'Park references and spots'),
  ExtensionInfo(key: 'sota', file: 'sota.js', core: false, name: 'Summits on the Air', category: 'activity'),
  ExtensionInfo(
      key: 'qrz', file: 'qrz.js', core: false, name: 'QRZ.com Callsign Lookups', category: 'lookup',
      enabledByDefault: false),
  ExtensionInfo(
      key: 'gated-panel', file: 'gated-panel.js', core: false, name: 'Gated Panel', category: 'dashboard',
      experiments: ['an-experiment']),
];

/// A catalog over a MockClient: the panel fetches on open, and the default
/// CatalogService would reach catalog.ham2k.net from the test.
CatalogService _catalog(Future<http.Response> Function(http.Request) handler) => CatalogService(
      client: MockClient(handler),
      edition: Edition.next,
      userAgent: () async => 'Ham2K Logger/test',
      locale: () => 'en',
    );

CatalogService _emptyCatalog() => _catalog((_) async => http.Response(jsonEncode({'extensions': []}), 200));

Map<String, Object?> _entry(String key, String name, {String version = '1.0.0', Map<String, Object?>? geo}) => {
      'key': key,
      'name': name,
      'version': version,
      'sha256': 'a' * 64,
      'bundleUrl': 'https://catalog.ham2k.net/api/v1/extensions/$key/versions/$version/bundle',
      'category': 'activity',
      'description': 'About $name',
      'geo': ?geo,
    };

/// The keys of the catalog rows actually built, top to bottom.
List<String> _catalogRowKeys(WidgetTester tester) => [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        if (tile.key case ValueKey<String>(value: final key) when key.startsWith('catalog-')) key,
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isExtensionEnabled: core always wins; overrides beat defaults', () async {
    SharedPreferences.setMockInitialValues({
      'extensionOverrides': '{"sota": false, "qrz": true}',
    });
    final settings = SettingsService(await SharedPreferences.getInstance());
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;

    bool enabled(String key) =>
        extensions.isExtensionEnabled(_testExtensions.firstWhere((e) => e.key == key));

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
    SharedPreferences.setMockInitialValues({
      'extensionOverrides': '{"gone": false, "pota": true}',
      'extensionDisabledSince': '{"gone": 1000, "sota": 2000}',
    });
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
    SharedPreferences.setMockInitialValues({
      'extensionOverrides': '{"pota": true, "sota": true}',
    });
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}))..settings = settings;
    // No debugSetAvailableExtensions call — availableExtensions is still [].
    HaLoServices(db, settings, extensions: extensions);

    await extensions.applyExtensionAvailability();

    expect(settings.extensionOverrides, {'pota': true, 'sota': true},
        reason: 'overrides set before the index loads must survive, not read as naming deleted extensions');
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
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({
      'runtime:kernel:listExtensions': [
        {'key': 'pota', 'name': 'Parks on the Air', 'version': '0.0.1'},
      ],
    }));
    final listed = await extensions.listActiveExtensions();
    expect(listed.single['key'], 'pota');
    expect(listed.single['version'], '0.0.1');
  });

  testWidgets('panel hides core, groups per category, searches from the top field, and toggles persist',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings, :extensions) = await makeHaLoServices(catalog: _emptyCatalog());
    extensions.debugSetAvailableExtensions(_testExtensions);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Scaffold(body: ExtensionsPanel(services: services))),
    ));
    await tester.pumpAndSettle();

    // Core never listed; categories render in order with their headers.
    expect(find.text('ADIF Export'), findsNothing);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Callsign Lookups'), findsOneWidget);
    expect(find.text('Parks on the Air'), findsOneWidget);

    // QRZ defaults off, POTA on.
    bool switchValue(String title) =>
        tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title)).value;
    expect(switchValue('QRZ.com Callsign Lookups'), isFalse);
    expect(switchValue('Parks on the Air'), isTrue);

    // The top search filters across groups; empty groups lose headers.
    await tester.enterText(find.byKey(const ValueKey('extensions-search')), 'summits');
    await tester.pumpAndSettle();
    expect(find.text('Summits on the Air'), findsOneWidget);
    expect(find.text('Parks on the Air'), findsNothing);
    expect(find.text('Callsign Lookups'), findsNothing);
    await tester.tap(find.byIcon(MdiIcons.close));
    await tester.pumpAndSettle();

    // Toggling persists an override in the dedicated store (not the
    // settings groups).
    await tester.tap(find.widgetWithText(SwitchListTile, 'Summits on the Air'));
    await tester.pumpAndSettle();
    expect(settings.extensionOverrides, {'sota': false});
    expect(settings.extensionSettingsGroups(), isEmpty);
    expect(switchValue('Summits on the Air'), isFalse);
  });

  testWidgets('panel hides experiment-gated extensions until the experiment is enabled', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final HaLoHarness(:services, :settings, :extensions) = await makeHaLoServices(catalog: _emptyCatalog());
    extensions.debugSetAvailableExtensions(_testExtensions);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Scaffold(body: ExtensionsPanel(services: services))),
    ));
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

  testWidgets('catalog rows render in three tiers, and each row says what can be done with it', (tester) async {
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
      ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'Parks on the Air', category: 'activity'),
      ExtensionInfo(
          key: 'k2hrc-llota', file: 'index.js', core: false, name: 'LLOTA', category: 'activity',
          source: ExtensionSource.installed, version: '1.0.0'),
      ExtensionInfo(
          key: 'zz-current', file: 'index.js', core: false, name: 'ZZ Current', category: 'activity',
          source: ExtensionSource.installed, version: '2.0.0'),
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

    final catalog = _catalog((_) async => http.Response(
        jsonEncode({
          'extensions': [
            _entry('zz-world', 'Zulu World'),
            _entry('ce-only', 'Chile Only', geo: {
              'entities': ['CE']
            }),
            _entry('pota', 'POTA (catalog)'),
            _entry('k2hrc-llota', 'LLOTA (catalog)', version: '1.1.0'),
            _entry('zz-current', 'ZZ Current (catalog)', version: '2.0.0'),
            _entry('aa-world', 'Alpha World'),
            _entry('k-only', 'Kilo Only', geo: {
              'entities': ['K']
            }),
          ],
        }),
        200));
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog, flags: flags);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Scaffold(body: ExtensionsPanel(services: services))),
    ));
    await tester.pumpAndSettle();

    // Geo-matched, then worldwide, then unmatched; alphabetical within.
    // Mutated to a flat alphabetical sort, Chile Only lands second.
    expect(find.text('Catalog'), findsOneWidget);
    expect(_catalogRowKeys(tester), [
      'catalog-k-only',
      'catalog-aa-world',
      'catalog-k2hrc-llota',
      'catalog-pota',
      'catalog-zz-world',
      'catalog-zz-current',
      'catalog-ce-only',
    ]);

    Finder inRow(String key, Finder what) => find.descendant(of: find.byKey(ValueKey('catalog-$key')), matching: what);
    // A key the app ships: said so, and nothing to press — the install would
    // be refused anyway, and a button that only ever refuses is a trap.
    expect(inRow('pota', find.text('Built in')), findsOneWidget);
    expect(inRow('pota', find.byType(FilledButton)), findsNothing);
    // Installed at a lower version: Update. Installed and current: Installed.
    expect(inRow('k2hrc-llota', find.widgetWithText(FilledButton, 'Update')), findsOneWidget);
    expect(inRow('zz-current', find.text('Installed')), findsOneWidget);
    expect(inRow('zz-current', find.byType(FilledButton)), findsNothing);
    expect(inRow('aa-world', find.widgetWithText(FilledButton, 'Install')), findsOneWidget);
    // The installed row itself carries the badge.
    expect(
      find.descendant(of: find.byKey(const ValueKey('extension-k2hrc-llota')), matching: find.textContaining('Update available')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const ValueKey('extension-zz-current')), matching: find.textContaining('Update available')),
      findsNothing,
    );

    // The catalog rows are part of the row set the list is keyed by
    // (docs/quirks.md): without them, the fetch resolving changes the rows
    // under a key that says nothing changed, and web clicks land on the
    // pre-fetch geometry.
    expect(
      tester.widget<SectionedListView>(find.byType(SectionedListView)).key,
      listContentsKey([
        'pota',
        'k2hrc-llota',
        'zz-current',
        for (final key in _catalogRowKeys(tester)) 'catalog:${key.substring('catalog-'.length)}',
      ]),
    );

    // The search field filters the catalog too, on the same terms.
    await tester.enterText(find.byKey(const ValueKey('extensions-search')), 'chile');
    await tester.pumpAndSettle();
    expect(_catalogRowKeys(tester), ['catalog-ce-only']);
    expect(find.text('Parks on the Air'), findsNothing);
  });

  testWidgets('the operator geo arriving after the panel opened is a new request, and re-ranks the rows',
      (tester) async {
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
              _entry('k-only', 'Kilo Only', geo: {
                'entities': ['K']
              }),
              _entry('aa-world', 'Alpha World'),
            ],
          }),
          200);
    });
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog, flags: flags);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Scaffold(body: ExtensionsPanel(services: services))),
    ));
    await tester.pumpAndSettle();
    // Nothing known: worldwide leads, the gated entry trails.
    expect(_catalogRowKeys(tester), ['catalog-aa-world', 'catalog-zz-world', 'catalog-k-only']);
    expect(queries.single.containsKey('entity'), isFalse);

    // The ranking is the catalog's answer to the geo it was asked with, so
    // the new geo is a new request — a panel that only re-sorted would
    // still be showing the catalog's verdict for an unknown operator.
    await flags.refreshForCall('K1ABC');
    await tester.pumpAndSettle();
    expect(queries, hasLength(2));
    expect(queries.last['entity'], 'K');
    expect(_catalogRowKeys(tester), ['catalog-k-only', 'catalog-aa-world', 'catalog-zz-world']);
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
          key: 'k2hrc-llota', file: 'index.js', core: false, name: 'LLOTA', category: 'activity',
          source: ExtensionSource.installed, version: '1.0.0'),
      ExtensionInfo(
          key: 'zz-current', file: 'index.js', core: false, name: 'ZZ Current', category: 'activity',
          source: ExtensionSource.installed, version: '2.0.0'),
    ]);
    final services = HaLoServices(db, settings, extensions: extensions, catalog: _emptyCatalog());

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Scaffold(body: ExtensionsPanel(services: services))),
    ));
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
    final services =
        HaLoServices(db, settings, extensions: extensions, catalog: _catalog((_) => answer.future));

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Scaffold(body: ExtensionsPanel(services: services))),
    ));
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
      return http.Response(jsonEncode({'extensions': [_entry('aa-world', 'Alpha World')]}), 200);
    });
    final services = HaLoServices(db, settings, extensions: extensions, catalog: catalog);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Scaffold(body: ExtensionsPanel(services: services))),
    ));
    await tester.pumpAndSettle();

    // Hidden entirely — no header, no status line — and NOT fetched: a
    // section that is not built but still asks the catalog is the trap the
    // request count catches, and the text finders cannot.
    expect(find.text('Catalog'), findsNothing);
    expect(find.text('Loading the catalog…'), findsNothing);
    expect(find.text('Catalog unreachable'), findsNothing);
    expect(_catalogRowKeys(tester), isEmpty);
    expect(requests, 0);
    // Install from file is not the catalog's, and stays.
    expect(find.text('Install from file…'), findsOneWidget);

    // Flipped on from the Experiments panel over this one: the fetch the
    // opening skipped happens now, without reopening.
    await settings.setExperimentEnabled('catalog', true);
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Catalog'), findsOneWidget);
    expect(_catalogRowKeys(tester), ['catalog-aa-world']);

    await settings.setExperimentEnabled('catalog', false);
    await tester.pumpAndSettle();
    expect(find.text('Catalog'), findsNothing);
    expect(_catalogRowKeys(tester), isEmpty);
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The third tier of the activity search (HALO-559): an extension the app does
// not have at all, found in the catalog and offered as an install in place.
// Once a QSO party is one extension per event (HALO-558), typing "texas"
// matches nothing installed — the row this file covers is the only thing
// between the operator and an activity that looks like it does not exist.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/catalog_service.dart';
import 'package:ham2k_logger/services/extension_relevance.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

CatalogEntry _entry(
  String key,
  String name, {
  String? description,
  List<String> keywords = const [],
  List<String> hooks = const [],
  ExtensionRelevance? relevance,
}) =>
    CatalogEntry(
      key: key,
      name: name,
      version: '1.0.0',
      sha256: 'a' * 64,
      bundleUrl: Uri.parse('https://catalog.example/api/v1/extensions/$key/versions/1.0.0/bundle'),
      description: description,
      keywords: keywords,
      hooks: hooks,
      relevance: relevance,
    );

/// Counts what the sheet asks of the catalog, and answers whatever the test
/// set — including nothing, which is what an unreachable catalog answers.
class _CountingCatalog extends CatalogService {
  _CountingCatalog({this.entries, this.gate});

  final List<CatalogEntry>? entries;

  /// Held open, the listing lands only when the test says so — which is the
  /// only way to have it arrive while the operator is still typing.
  final Completer<void>? gate;
  int fetches = 0;

  @override
  Future<List<CatalogEntry>?> fetchCatalog({OperatorGeo? geo, bool force = false}) async {
    fetches++;
    if (gate != null) await gate!.future;
    return entries;
  }
}

/// Loads no controls and answers no suggestions, so what the sheet shows is
/// the enable/install rows alone.
class _NoActivityExtensions extends ExtensionServiceWithFakeHost {
  _NoActivityExtensions() : super(FakeExtensionHost({}));

  @override
  Future<ControlsResult> operationControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      (controls: const <Map<String, dynamic>>[], loadFailed: false);
}

Future<(HaLoServices, Operation, _CountingCatalog)> _harness({
  List<CatalogEntry>? catalog = const [],
  List<ExtensionInfo> available = const [],
  List<Map<String, dynamic>> refs = const [],
  bool experimentOn = true,
  Completer<void>? gate,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final settings = SettingsService(await SharedPreferences.getInstance());
  if (experimentOn) await settings.setExperimentEnabled('catalog', true);
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = _NoActivityExtensions()..settings = settings;
  extensions.debugSetAvailableExtensions(available);
  final catalogService = _CountingCatalog(entries: catalog, gate: gate);
  return (
    HaLoServices(db, settings, extensions: extensions, catalog: catalogService),
    Operation(uuid: 'op-1', data: {'refs': refs}),
    catalogService,
  );
}

Future<void> _pump(WidgetTester tester, HaLoServices services, Operation operation) async {
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(home: Scaffold(body: OperationSheet(services: services, operation: operation))),
  ));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  // The search field debounces; without waiting past it nothing runs at all
  // and every assertion below would pass against a stale empty state.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('orderedCatalogEntries', () {
    test('the operator\'s own region leads, worldwide next, everyone else last', () {
      final texas = _entry('tx', 'Texas', relevance: ExtensionRelevance.fromJson(const {'entities': ['K']}));
      final vermont = _entry('vt', 'Vermont', relevance: ExtensionRelevance.fromJson(const {'entities': ['VE']}));
      final worldwide = _entry('ww', 'Worldwide');
      final operator = const OperatorGeo(entityPrefix: 'K');

      expect(
        orderedCatalogEntries([vermont, worldwide, texas], operator, 'en').map((e) => e.key),
        ['tx', 'ww', 'vt'],
      );
    });

    test('with no operator geo there is no first tier — worldwide leads', () {
      final texas = _entry('tx', 'Texas', relevance: ExtensionRelevance.fromJson(const {'entities': ['K']}));
      final worldwide = _entry('ww', 'Worldwide');
      expect(orderedCatalogEntries([texas, worldwide], null, 'en').map((e) => e.key), ['ww', 'tx']);
    });
  });

  testWidgets('a catalog extension the app does not have is offered as an install', (tester) async {
    final (services, operation, catalog) = await _harness(
      catalog: [_entry('ham2k-texas-qso-party', 'Texas QSO Party', keywords: const ['texas'])],
    );
    await _pump(tester, services, operation);
    await _type(tester, 'texas');

    expect(catalog.fetches, 1);
    expect(find.text('Install Texas QSO Party').hitTestable(), findsOneWidget);
    expect(find.textContaining('not installed'), findsOneWidget);
  });

  testWidgets('an extension the app already has is never offered as an install', (tester) async {
    // The trap: the catalog lists everything, including what the operator
    // installed already. Offering a download for one of those asks them to
    // fetch what they have.
    //
    // Installed rather than built in, because this tier only appears under
    // the catalog experiment and that experiment withdraws every built-in —
    // so an installed extension is the only kind the catalog can now
    // duplicate.
    final (services, operation, _) = await _harness(
      catalog: [_entry('qp', 'QSO Parties', keywords: const ['texas'])],
      available: const [
        ExtensionInfo(
          key: 'qp',
          file: 'index.js',
          core: false,
          name: 'QSO Parties',
          keywords: ['texas'],
          source: ExtensionSource.installed,
          enabledByDefault: false,
        ),
      ],
    );
    await _pump(tester, services, operation);
    await _type(tester, 'texas');

    expect(find.textContaining('Install '), findsNothing);
    // It is the tier above's to offer, and it still does.
    expect(find.text('Enable QSO Parties').hitTestable(), findsOneWidget);
  });

  testWidgets('an empty box asks the catalog nothing', (tester) async {
    // The sheet opens with a search of its own for nearby references. That
    // one must not reach the catalog: an operation sheet opened to add a park
    // is the common case, and it has nothing to match against.
    final (services, operation, catalog) = await _harness(
      catalog: [_entry('ham2k-texas-qso-party', 'Texas QSO Party')],
    );
    await _pump(tester, services, operation);

    expect(catalog.fetches, 0);
    expect(find.textContaining('Install '), findsNothing);
  });

  testWidgets('the catalog is asked once per sheet, however much is typed', (tester) async {
    // A fetch per keystroke is the failure this guards: the service caches for
    // five minutes, but a cache is not a reason to ask it eight times for one
    // word, and an unreachable catalog has no cache at all.
    final (services, operation, catalog) = await _harness(catalog: null);
    await _pump(tester, services, operation);
    await _type(tester, 'tex');
    await _type(tester, 'texa');
    await _type(tester, 'texas');

    expect(catalog.fetches, 1);
    // An unreachable catalog leaves the tier absent, with nothing in the way.
    expect(find.textContaining('Install '), findsNothing);
  });

  testWidgets('with the experiment off the tier is absent and nothing is fetched', (tester) async {
    final (services, operation, catalog) = await _harness(
      catalog: [_entry('ham2k-texas-qso-party', 'Texas QSO Party', keywords: const ['texas'])],
      experimentOn: false,
    );
    await _pump(tester, services, operation);
    await _type(tester, 'texas');

    expect(catalog.fetches, 0, reason: 'a section that is not built must not ask the catalog anything');
    expect(find.textContaining('Install '), findsNothing);
  });

  testWidgets('a listing that lands mid-typing matches what is in the box, not what started the fetch',
      (tester) async {
    // The listing is held until AFTER the second word is typed, which is the
    // only arrangement that reaches the fetch's own matching: with it landing
    // straight away, the search that follows re-matches anyway and a
    // fetch-time term captured by mistake would never show.
    final gate = Completer<void>();
    final (services, operation, catalog) = await _harness(
      gate: gate,
      catalog: [
        _entry('ham2k-texas-qso-party', 'Texas QSO Party', keywords: const ['texas']),
        _entry('ham2k-vermont-qso-party', 'Vermont QSO Party', keywords: const ['vermont']),
      ],
    );
    await _pump(tester, services, operation);
    await _type(tester, 'texas');
    await _type(tester, 'vermont');
    expect(catalog.fetches, 1);
    expect(find.textContaining('Install '), findsNothing, reason: 'nothing has arrived yet');

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Install Vermont QSO Party').hitTestable(), findsOneWidget);
    expect(find.text('Install Texas QSO Party'), findsNothing);
  });

  testWidgets('a reference nothing installed handles finds its extension in the catalog, with nothing typed',
      (tester) async {
    // The operation was logged when fifty parties were one extension. That
    // extension is gone, the per-event one was never installed, and the row
    // in Current Activities is red with no remedy anywhere — the case a
    // search box cannot answer, because the operator has nothing to type.
    final (services, operation, catalog) = await _harness(
      catalog: [
        _entry('ham2k-new-york-qso-party', 'New York QSO Party', hooks: const ['activity', 'ref:nyqp', 'ref:qp/ny']),
        _entry('ham2k-texas-qso-party', 'Texas QSO Party', hooks: const ['activity', 'ref:txqp', 'ref:qp/tx']),
      ],
      refs: const [
        {'type': 'qp', 'ref': 'NY', 'name': 'New York QSO Party'},
      ],
    );
    await _pump(tester, services, operation);
    await tester.pumpAndSettle();

    expect(catalog.fetches, 1, reason: 'an unhandled reference is a question worth asking the catalog');
    expect(find.text('Install New York QSO Party').hitTestable(), findsOneWidget);
    // Every party claims `ref:qp/<its own>`; read as a plain claim they would
    // all answer for this one reference.
    expect(find.text('Install Texas QSO Party'), findsNothing);
  });

  testWidgets('an operation whose activities all load asks the catalog nothing', (tester) async {
    final (services, operation, catalog) = await _harness(
      catalog: [
        _entry('ham2k-new-york-qso-party', 'New York QSO Party', hooks: const ['activity', 'ref:nyqp', 'ref:qp/ny']),
      ],
    );
    await _pump(tester, services, operation);
    await tester.pumpAndSettle();

    expect(catalog.fetches, 0);
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A switched-off extension that matches the search answers "which activities
// exist", not "which reference do I add" — so its enable row belongs in the
// Activity Types section, not at the top of the results where it outranks the
// references the operator actually searched for.
//
// Moving it there creates the trap this file guards: that section can be
// collapsed, and a collapsed section shows nothing, so a search whose ONLY
// answer is an enable row would silently answer with nothing at all. The
// section therefore opens itself, and the results area says where to look.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

const _potaInfo = ExtensionInfo(
  key: 'pota',
  file: 'pota.js',
  core: false,
  name: 'Parks on the Air',
  // Off unless an override says otherwise, which is what makes it a
  // "disabled match" — see ExtensionService.isExtensionEnabled.
  enabledByDefault: false,
);

/// Several extensions that all answer the same search, to push the section
/// past what its default peek can show.
List<ExtensionInfo> _manyParks(int count) => [
      for (var i = 0; i < count; i++)
        ExtensionInfo(key: 'parks$i', file: 'parks$i.js', core: false, name: 'Parks Number $i', enabledByDefault: false),
    ];

class _NoActivityExtensions extends ExtensionServiceWithFakeHost {
  // No `activity:*:suggest` stub, deliberately: no suggestion can come back
  // for a disabled extension, because its hooks aren't loaded. That is exactly
  // the case under test — the enable row is the only answer there is.
  _NoActivityExtensions() : super(FakeExtensionHost({}));

  @override
  Future<ControlsResult> operationControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      (controls: const <Map<String, dynamic>>[], loadFailed: false);
}

Future<(HaLoServices, Operation)> _harness({
  bool sectionCollapsed = false,
  List<ExtensionInfo>? available,
}) async {
  SharedPreferences.setMockInitialValues({
    if (sectionCollapsed) 'activitiesAllOptionsHidden': true,
  });
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = _NoActivityExtensions()..settings = settings;
  extensions.debugSetAvailableExtensions(available ?? const [_potaInfo]);
  return (HaLoServices(db, settings, extensions: extensions), Operation(uuid: 'op-1', data: const {'refs': []}));
}

/// The peeking window's height — the SizedBox wrapping the collapsed
/// section's scroll view.
double _peekHeight(WidgetTester tester) {
  final box = find.ancestor(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(SizedBox),
  );
  return tester.getSize(box.first).height;
}

Future<void> _pumpAndSearch(WidgetTester tester, HaLoServices services, Operation operation, String term) async {
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(home: Scaffold(body: OperationSheet(services: services, operation: operation))),
  ));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, term);
  // The search field debounces; without waiting past it nothing runs at all
  // and every assertion below would pass against a stale empty state.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the enable row renders inside the Activity Types section', (tester) async {
    final (services, operation) = await _harness();
    await _pumpAndSearch(tester, services, operation, 'parks');

    final enableRow = find.text('Enable Parks on the Air');
    expect(enableRow, findsOneWidget);

    // Placement, not mere presence: the row must be a descendant of the
    // section, which is what keeps it out of the results list above.
    expect(
      find.ancestor(of: enableRow, matching: find.byType(Column)),
      findsWidgets,
      reason: 'the enable row should render at all',
    );
    final sectionTitle = find.text('Activity Types');
    expect(sectionTitle, findsOneWidget);
    final titleY = tester.getTopLeft(sectionTitle).dy;
    expect(
      tester.getTopLeft(enableRow).dy,
      greaterThan(titleY),
      reason: 'the enable row belongs BELOW the Activity Types header, not above the search results',
    );
  });

  testWidgets('a collapsed Activity Types section opens itself for the enable row', (tester) async {
    final (services, operation) = await _harness(sectionCollapsed: true);
    await _pumpAndSearch(tester, services, operation, 'parks');

    // `.hitTestable()`, NOT bare `find.text`: the section collapses through an
    // AnimatedCrossFade, which keeps both children mounted and merely sizes
    // the hidden one to nothing. A plain finder therefore locates the row in a
    // section that is shut, and passes whether or not this feature exists.
    expect(
      find.text('Enable Parks on the Air').hitTestable(),
      findsOneWidget,
      reason: 'a search whose only answer is an enable row must open the section holding it',
    );
  });

  testWidgets('auto-opening does not rewrite the stored preference', (tester) async {
    final (services, operation) = await _harness(sectionCollapsed: true);
    await _pumpAndSearch(tester, services, operation, 'parks');

    expect(find.text('Enable Parks on the Air').hitTestable(), findsOneWidget);
    // Opened for THIS search only. The operator's own choice to keep the
    // section shut must survive it — a search must not quietly reconfigure the
    // sheet for every session after.
    expect(services.settings.prefs.getBool('activitiesAllOptionsHidden'), isTrue);
  });

  testWidgets('the peek grows to hold every enable row, plus one more', (tester) async {
    final (services, operation) = await _harness(available: _manyParks(3));
    await _pumpAndSearch(tester, services, operation, 'parks');

    expect(find.textContaining('Parks Number').hitTestable(), findsNWidgets(3));
    // Three two-line enable rows (72 each) and one ordinary row (56) below
    // them — the extra row is what still says "more below" once the enable
    // rows fill the window. The default 84 would cut the first row in half.
    expect(_peekHeight(tester), 3 * 72.0 + 56.0);
  });

  testWidgets('the peek never eats the results list', (tester) async {
    // A window short enough that holding every enable row would leave the
    // results with nothing.
    tester.view.physicalSize = const Size(800, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final (services, operation) = await _harness(available: _manyParks(12));
    await _pumpAndSearch(tester, services, operation, 'parks');

    // 12 rows would want 920px. What it actually takes has to leave the
    // results list its own row and a half (108) plus the search band (64)
    // out of the box the two of them share.
    final peek = _peekHeight(tester);
    expect(peek, lessThan(12 * 72.0 + 56.0));
    expect(find.text('Activity Types'), findsOneWidget);
    // The results area still renders its own content rather than being
    // squeezed out of existence.
    expect(find.textContaining('might have results').hitTestable(), findsOneWidget);
  });

  testWidgets('a search matching nothing disabled leaves a collapsed section shut', (tester) async {
    final (services, operation) = await _harness(sectionCollapsed: true);
    await _pumpAndSearch(tester, services, operation, 'zzz');

    // The other half of the rule: the section opens for the enable row, not
    // for typing. Opening on every search would undo the operator's collapse
    // as soon as they touched the field.
    expect(find.text('Activity Types'), findsOneWidget);
    expect(find.text('Enable Parks on the Air').hitTestable(), findsNothing);
  });

  testWidgets('the results area points at the section instead of claiming nothing matched', (tester) async {
    final (services, operation) = await _harness();
    await _pumpAndSearch(tester, services, operation, 'parks');

    // A bare "No matches" here would flatly contradict the enable row sitting
    // just below it: the activity they searched for does exist.
    expect(find.text('No matches'), findsNothing);
    expect(find.textContaining('might have results'), findsOneWidget);
  });
}

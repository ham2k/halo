// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A ref whose extension is switched off renders as a red "unknown" row in
// Current Activities, and the fix — turning the extension on — is a switch
// away. The Activity Types section offers that switch, the way it offers a
// switched-off extension the search text matches, found through the
// manifest's own `ref:<type>` hooks rather than the search's loose match.

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

const _sotaInfo = ExtensionInfo(
  key: 'sota',
  file: 'sota.js',
  core: false,
  name: 'Summits on the Air',
  enabledByDefault: false,
  hooks: ['activity', 'ref:sota', 'ref:sotaActivation'],
);

/// Declares the same type as SOTA but is already on — its control would be
/// loaded in real life; here the mock loads none, which is the trap: an
/// enabled extension must never be offered as a switch to flip.
const _enabledSotaInfo = ExtensionInfo(
  key: 'sota',
  file: 'sota.js',
  core: false,
  name: 'Summits on the Air',
  enabledByDefault: true,
  hooks: ['activity', 'ref:sotaActivation'],
);

/// Mentions summits everywhere the loose search looks, but handles no
/// SOTA reference type.
const _lookalikeInfo = ExtensionInfo(
  key: 'peaks',
  file: 'peaks.js',
  core: false,
  name: 'Peaks Lookalike',
  description: 'Summits, but not SOTA summits',
  keywords: ['sota', 'sotaActivation', 'summits'],
  enabledByDefault: false,
  hooks: ['activity', 'ref:peaks'],
);

const _sotaActivationRef = {'type': 'sotaActivation', 'ref': 'W7A/MN-001', 'name': 'Mount Example'};
const _secondSotaActivationRef = {'type': 'sotaActivation', 'ref': 'W7A/MN-002', 'name': 'Other Summit'};

/// The control SOTA loads once it is on.
const _sotaControl = <String, dynamic>{
  'key': 'sota/activation',
  'label': 'Summits',
  'input': {'kind': 'refList', 'refType': 'sotaActivation'},
};

class _NoActivityExtensions extends ExtensionServiceWithFakeHost {
  _NoActivityExtensions() : super(FakeExtensionHost({}));

  /// What `operationControls` answers — empty until an enable flips it.
  List<Map<String, dynamic>> controls = const [];

  /// The keys enabled through the sheet, in order.
  final enabled = <String>[];

  @override
  Future<ControlsResult> operationControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      (controls: controls, loadFailed: false);

  // The real one restarts the runtime; here enabling records the override,
  // which is what `isExtensionEnabled` reads, and loads SOTA's control the way
  // the restarted runtime would.
  @override
  Future<void> setExtensionEnabled(String key, bool enabled) async {
    this.enabled.add(key);
    await settings!.setExtensionOverrides({...settings!.extensionOverrides, key: enabled});
    if (key == 'sota' && enabled) controls = const [_sotaControl];
  }

  @override
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    List<String>? activityKeys,
    List<String>? preferredKeys,
    String? preferredSearchTerm,
  }) async =>
      (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: false);
}

Future<(HaLoServices, Operation)> _harness({
  required List<ExtensionInfo> available,
  List<Map<String, dynamic>> refs = const [_sotaActivationRef],
  List<Map<String, dynamic>> controls = const [],
  bool sectionCollapsed = false,
}) async {
  SharedPreferences.setMockInitialValues({
    if (sectionCollapsed) 'activitiesAllOptionsHidden': true,
  });
  final settings = SettingsService(await SharedPreferences.getInstance());
  final db = HaLoDatabase(NativeDatabase.memory());
  final extensions = _NoActivityExtensions()
    ..settings = settings
    ..controls = controls;
  extensions.debugSetAvailableExtensions(available);
  return (HaLoServices(db, settings, extensions: extensions), Operation(uuid: 'op-1', data: {'refs': refs}));
}

String _searchText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

Future<void> _pump(WidgetTester tester, HaLoServices services, Operation operation) async {
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(home: Scaffold(body: OperationSheet(services: services, operation: operation))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('extensionsDeclaringRefs', () {
    test('matches on the ref hook alone, never on names or keywords', () {
      expect(
        extensionsDeclaringRefs([_lookalikeInfo, _sotaInfo], [(type: 'sotaActivation', code: null)]),
        [_sotaInfo],
      );
    });

    test('an empty ref set and a hook-less extension match nothing', () {
      expect(extensionsDeclaringRefs([_sotaInfo], const []), isEmpty);
      expect(
        extensionsDeclaringRefs(
          [const ExtensionInfo(key: 'x', file: 'x.js', core: false, name: 'X')],
          [(type: 'x', code: null)],
        ),
        isEmpty,
      );
    });
  });

  testWidgets('a switched-off extension declaring an unhandled ref type gets an enable row in Activity Types',
      (tester) async {
    final (services, operation) = await _harness(available: const [_lookalikeInfo, _sotaInfo]);
    await _pump(tester, services, operation);

    final enableRow = find.text('Enable Summits on the Air');
    expect(enableRow.hitTestable(), findsOneWidget);
    expect(find.text('Enable Peaks Lookalike'), findsNothing, reason: 'the loose search match must not apply');
    expect(find.textContaining("one of this operation's references"), findsOneWidget);

    // Placement: below the section header, not among the results.
    final titleY = tester.getTopLeft(find.text('Activity Types')).dy;
    expect(tester.getTopLeft(enableRow).dy, greaterThan(titleY));
  });

  testWidgets('an extension that is already on is never offered', (tester) async {
    final (services, operation) = await _harness(available: const [_enabledSotaInfo]);
    await _pump(tester, services, operation);
    expect(find.textContaining('Enable '), findsNothing);
  });

  testWidgets('a ref a loaded control handles offers nothing, whatever the manifests say', (tester) async {
    // The control is what says "handled"; the switched-off SOTA in the
    // catalog is a red herring the unknown-type check has to see past.
    final (services, operation) = await _harness(available: const [_sotaInfo], controls: const [_sotaControl]);
    await _pump(tester, services, operation);
    expect(find.text('Enable Summits on the Air'), findsNothing);
  });

  testWidgets('tapping the row enables the extension and leaves the search box alone', (tester) async {
    final (services, operation) = await _harness(available: const [_sotaInfo]);
    await _pump(tester, services, operation);

    await tester.tap(find.text('Enable Summits on the Air').hitTestable());
    await tester.pumpAndSettle();

    final extensions = services.extensions as _NoActivityExtensions;
    expect(extensions.enabled, ['sota']);
    expect(find.text('Enable Summits on the Air'), findsNothing, reason: 'the row is its own remedy');
    // The search's enable row scopes the box to the extension (`sota: `);
    // this one was tapped for a ref already on the operation, with nothing
    // typed, and must not start a search for more summits.
    expect(_searchText(tester), isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'the results spinner must settle');
  });

  testWidgets('the section opens once per extension, not on every controls reload', (tester) async {
    final (services, operation) = await _harness(
      available: const [_sotaInfo],
      refs: const [_sotaActivationRef, _secondSotaActivationRef],
      sectionCollapsed: true,
    );
    await _pump(tester, services, operation);
    final enableRow = find.text('Enable Summits on the Air');
    expect(enableRow.hitTestable(), findsOneWidget, reason: 'the first sight of the offer opens the section');

    // The operator declines: collapses the section by its header.
    await tester.tap(find.text('Activity Types'));
    await tester.pumpAndSettle();
    expect(enableRow.hitTestable(), findsNothing);

    // Removing one ref reloads the descriptors; the other ref still has no
    // handler, and the offer already made must not reopen the section.
    await tester.tap(find.bySemanticsLabel('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('W7A/MN-002'), findsOneWidget, reason: 'the second unhandled ref is still on the operation');
    expect(enableRow.hitTestable(), findsNothing);
  });

  testWidgets('a collapsed Activity Types section opens itself for the row', (tester) async {
    final (services, operation) = await _harness(available: const [_sotaInfo], sectionCollapsed: true);
    await _pump(tester, services, operation);
    // `.hitTestable()`: the accordion keeps a collapsed section's children
    // mounted at zero size, so a bare finder would pass against a hidden row.
    expect(find.text('Enable Summits on the Air').hitTestable(), findsOneWidget);
  });

  testWidgets('an extension the search already offers shows once, with the search hint', (tester) async {
    final (services, operation) = await _harness(available: const [_sotaInfo]);
    await _pump(tester, services, operation);

    await tester.enterText(find.byType(TextField).first, 'summits');
    // Past the search debounce, or the search never runs at all.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Enable Summits on the Air'), findsOneWidget);
    expect(find.text('This extension matches your search, but it is not currently enabled'), findsOneWidget);
    expect(find.textContaining("one of this operation's references"), findsNothing);
  });
}

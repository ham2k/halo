// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An activity is asked under the key it registered its hooks with — the one
// in its manifest — and that is not the namespace of its control keys: the
// catalog's `ham2k-pota` keys its controls `pota/…`. A hook read off the
// control key would be `activity/pota`, which nobody registers, and every
// scoped search would answer "unavailable".
//
// A user-published extension is keyed by its author's callsign (`ki2d-pota`)
// but may serve a stock reference type. Tapping its Activity Types row must
// scope the search by the TYPE's word (`pota: `), while the search itself
// still reaches every hook that serves it; the extension's own key reaches it
// alone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

/// As the fan-out hands them over, the supplying extension stamped on.
const _stockPotaControl = <String, dynamic>{
  'key': 'pota/activation',
  controlExtensionKeyField: 'ham2k-pota',
  'label': 'Parks',
  'input': {'kind': 'refList', 'refType': 'potaActivation'},
};

const _userPotaControl = <String, dynamic>{
  'key': 'ki2d-pota/activation',
  controlExtensionKeyField: 'ki2d-pota',
  'label': 'Parks (KI2D)',
  'input': {'kind': 'refList', 'refType': 'potaActivation'},
};

/// A contest: a form, no reference list. Its `suggest` still answers a scope
/// (`cwt: 1300` narrows the sessions), so the word must exist for it — and
/// the key namespace differs from the type so that deriving the word from
/// the key would be caught here too.
const _cwtControl = <String, dynamic>{
  'key': 'k2hrc-cwt/setup',
  controlExtensionKeyField: 'k2hrc-cwt',
  'label': 'CWT',
  'input': {
    'kind': 'form',
    'refType': 'cwt',
    'form': {'title': 'CWT', 'elements': []},
  },
};

/// Stock POTA, as the catalog keys it.
const _stockPotaInfo = ExtensionInfo(
  key: 'ham2k-pota',
  file: 'ham2k-pota.js',
  core: false,
  name: 'Parks on the Air',
  enabledByDefault: false,
  hooks: ['activity', 'ref:pota', 'ref:potaActivation'],
);

const _userPotaInfo = ExtensionInfo(key: 'ki2d-pota', file: 'ki2d-pota.js', core: false, name: 'Parks (KI2D)', hooks: ['activity', 'ref:potaActivation']);

/// Mentions POTA in its keywords, as State Parks does; the loose search
/// would match it, and a scope must not.
const _lookalikeInfo = ExtensionInfo(key: 'lookalike', file: 'lookalike.js', core: false, name: 'Parks Lookalike', keywords: ['pota'], enabledByDefault: false);

class _ScopedExtensions extends ExtensionServiceWithFakeHost {
  _ScopedExtensions({required this.controls}) : super(FakeExtensionHost({}));

  final List<Map<String, dynamic>> controls;

  /// The `activityKeys` of every search asked, in order.
  final askedKeys = <List<String>?>[];

  /// The `preferredKeys` of every search asked, in order.
  final preferredKeys = <List<String>?>[];

  @override
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async => (controls: controls, loadFailed: false);

  @override
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    List<String>? activityKeys,
    List<String>? preferredKeys,
    String? preferredSearchTerm,
    ({double south, double west, double north, double east})? searchWithin,
  }) async {
    askedKeys.add(activityKeys);
    this.preferredKeys.add(preferredKeys);
    return (suggestions: const <Map<String, dynamic>>[], allSourcesFailed: false);
  }
}

Future<(HaLoServices, _ScopedExtensions)> _harness(
  WidgetTester tester, {
  required List<Map<String, dynamic>> controls,
  List<ExtensionInfo> available = const [],
}) async {
  final extensions = _ScopedExtensions(controls: controls);
  final HaLoHarness(:services) = await makeHaLoServices(extensions: extensions);
  extensions.debugSetAvailableExtensions(available);
  final operation = Operation(uuid: 'op-1', data: const {'refs': []});

  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: OperationSheet(services: services, operation: operation),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (services, extensions);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  // Past the search debounce, or the search never runs at all.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

String _searchText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField).first).controller!.text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping a type row scopes by the ref type word and asks every hook serving it', (tester) async {
    final (_, extensions) = await _harness(tester, controls: const [_stockPotaControl, _userPotaControl]);

    // Second in the section, below the peeking window's row and a half.
    await tester.ensureVisible(find.text('Parks (KI2D)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parks (KI2D)').hitTestable());
    await tester.pumpAndSettle();

    expect(_searchText(tester), 'pota: ');
    expect(extensions.askedKeys.last, [
      'ham2k-pota',
      'ki2d-pota',
    ], reason: 'the hooks are the suppliers\' own keys, never the `pota` their control keys start with');
  });

  testWidgets('an extension\'s key scopes to it alone, beside the word both answer to', (tester) async {
    final (_, extensions) = await _harness(tester, controls: const [_stockPotaControl, _userPotaControl], available: const [_stockPotaInfo, _userPotaInfo]);
    await _type(tester, 'ham2k-pota:');
    expect(extensions.askedKeys.last, ['ham2k-pota']);
    await _type(tester, 'ki2d-pota: bear');
    expect(extensions.askedKeys.last, ['ki2d-pota']);
  });

  testWidgets('a form control\'s ref type scopes too, by the type and not the key', (tester) async {
    final (_, extensions) = await _harness(tester, controls: const [_cwtControl]);
    await _type(tester, 'cwt: 1300');
    expect(extensions.askedKeys.last, ['k2hrc-cwt'], reason: 'a contest with no reference list is still a scope');
  });

  testWidgets('a word without its colon prefers its extensions and still asks everyone', (tester) async {
    final (_, extensions) = await _harness(tester, controls: const [_stockPotaControl, _userPotaControl]);
    await _type(tester, 'pota');
    expect(extensions.askedKeys.last, isNull, reason: 'everyone else searches for "pota" too');
    expect(extensions.preferredKeys.last, ['ham2k-pota', 'ki2d-pota']);
  });

  testWidgets('a switched-off extension declaring the scoped type is offered, a lookalike is not', (tester) async {
    // Stock POTA off, KI2D's on: `pota:` asks KI2D, and the stock one is
    // offered because its manifest declares `ref:pota` — under the catalog's
    // `ham2k-pota` key, which the typed word never equals.
    final (_, extensions) = await _harness(tester, controls: const [_userPotaControl], available: const [_stockPotaInfo, _lookalikeInfo]);
    await _type(tester, 'pota:');
    expect(extensions.askedKeys.last, ['ki2d-pota']);
    expect(find.text('Enable Parks on the Air'), findsOneWidget);
    // Inside a scope only the declared words count: the loose match would
    // offer every extension whose blurb mentions the type.
    expect(find.text('Enable Parks Lookalike'), findsNothing);
  });

  testWidgets('a word without its colon is a text search too, so a lookalike is offered beside it', (tester) async {
    // Only the colon makes `pota` a scope. Without it the box is searched as
    // text by everyone, and an extension that mentions POTA is a fair answer
    // to that text — matching declared words alone would hide it.
    await _harness(tester, controls: const [_userPotaControl], available: const [_stockPotaInfo, _lookalikeInfo]);
    await _type(tester, 'pota');
    expect(find.text('Enable Parks on the Air'), findsOneWidget);
    expect(find.text('Enable Parks Lookalike'), findsOneWidget);
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A user-published extension is keyed by its author's callsign (`ki2d-pota`)
// but may serve a stock reference type. Tapping its Activity Types row must
// scope the search by the TYPE's word (`pota: `), while the search itself
// still reaches every hook that serves it — the key is the runtime's, the
// word is the operator's. Deriving the word from the control key instead
// would put `ki2d-pota: ` in the box; resolving the word to one hook would
// silently search only the stock extension's parks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

const _stockPotaControl = <String, dynamic>{
  'key': 'pota/activation',
  'label': 'Parks',
  'input': {'kind': 'refList', 'refType': 'potaActivation'},
};

const _userPotaControl = <String, dynamic>{
  'key': 'ki2d-pota/activation',
  'label': 'Parks (KI2D)',
  'input': {'kind': 'refList', 'refType': 'potaActivation'},
};

/// A contest: a form, no reference list. Its `suggest` still answers a scope
/// (`cwt: 1300` narrows the sessions), so the word must exist for it — and
/// the key namespace differs from the type so that deriving the word from
/// the key would be caught here too.
const _cwtControl = <String, dynamic>{
  'key': 'k2hrc-cwt/setup',
  'label': 'CWT',
  'input': {'kind': 'form', 'refType': 'cwt', 'form': {'title': 'CWT', 'elements': []}},
};

/// Stock POTA, switched off — with the user-published one serving its type.
const _stockPotaInfo = ExtensionInfo(
  key: 'pota',
  file: 'pota.js',
  core: false,
  name: 'Parks on the Air',
  enabledByDefault: false,
  hooks: ['activity', 'ref:pota', 'ref:potaActivation'],
);

/// Mentions POTA in its keywords, as State Parks does; the loose search
/// would match it, and a scope must not.
const _lookalikeInfo = ExtensionInfo(
  key: 'lookalike',
  file: 'lookalike.js',
  core: false,
  name: 'Parks Lookalike',
  keywords: ['pota'],
  enabledByDefault: false,
);

class _ScopedExtensions extends ExtensionServiceWithFakeHost {
  _ScopedExtensions({required this.controls}) : super(FakeExtensionHost({}));

  final List<Map<String, dynamic>> controls;

  /// The `activityKeys` of every search asked, in order.
  final askedKeys = <List<String>?>[];

  @override
  Future<ControlsResult> operationControls(
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async =>
      (controls: controls, loadFailed: false);

  @override
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    List<String>? activityKeys,
    List<String>? preferredKeys,
    String? preferredSearchTerm,
  }) async {
    askedKeys.add(activityKeys);
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

  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(home: Scaffold(body: OperationSheet(services: services, operation: operation))),
  ));
  await tester.pumpAndSettle();
  return (services, extensions);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  // Past the search debounce, or the search never runs at all.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

String _searchText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

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
    expect(extensions.askedKeys.last, ['pota', 'ki2d-pota'],
        reason: 'the scope is the type; the tapped extension must be among the hooks asked');
  });

  testWidgets('a form control\'s ref type scopes too, by the type and not the key', (tester) async {
    final (_, extensions) = await _harness(tester, controls: const [_cwtControl]);
    await _type(tester, 'cwt: 1300');
    expect(extensions.askedKeys.last, ['k2hrc-cwt'], reason: 'a contest with no reference list is still a scope');
  });

  testWidgets('typing the key of a switched-off extension offers it even when its word is a scope', (tester) async {
    // Stock POTA off, KI2D's on: `pota` parses as KI2D's scope, and typing
    // that key is still how stock POTA gets switched back on from here.
    final (_, extensions) = await _harness(
      tester,
      controls: const [_userPotaControl],
      available: const [_stockPotaInfo, _lookalikeInfo],
    );
    await _type(tester, 'pota');
    expect(extensions.askedKeys.last, ['ki2d-pota']);
    expect(find.text('Enable Parks on the Air'), findsOneWidget);
    // Inside a scope only the exact key counts: the loose match would offer
    // every extension whose blurb mentions the type.
    expect(find.text('Enable Parks Lookalike'), findsNothing);
  });
}

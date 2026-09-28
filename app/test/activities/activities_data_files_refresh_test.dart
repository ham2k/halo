// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Enabling an extension from the sheet restarts the runtime and searches at
// once, while the extension's data-file sync runs on after the restart. The
// first answer therefore comes from data that has not landed yet, and the
// sheet has to ask again when it does — or a freshly enabled POTA shows no
// parks until the operator types something else.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

const _parksInfo = ExtensionInfo(key: 'parks', file: 'parks.js', core: false, name: 'Parks Everywhere', enabledByDefault: false);

/// Answers from whatever "data" it has been given, as a real extension's
/// search answers from its downloaded files.
class _DataBackedExtensions extends ExtensionServiceWithFakeHost {
  _DataBackedExtensions() : super(FakeExtensionHost({}));

  List<Map<String, dynamic>> parks = const [];

  /// The search term of every search asked, in order.
  final asked = <String?>[];

  /// Runs inside [setExtensionEnabled], where the real one restarts the
  /// runtime — the moment a data-file tick can arrive mid-enable.
  Future<void> Function()? duringEnable;

  @override
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async =>
      (controls: const <Map<String, dynamic>>[], loadFailed: false);

  @override
  Future<void> setExtensionEnabled(String key, bool enabled) async {
    await settings!.setExtensionOverrides({...settings!.extensionOverrides, key: enabled});
    await duringEnable?.call();
  }

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
    asked.add(searchTerm);
    return (suggestions: parks, allSourcesFailed: false);
  }
}

Future<(HaLoServices, _DataBackedExtensions)> _pump(WidgetTester tester) async {
  final extensions = _DataBackedExtensions();
  final HaLoHarness(:services) = await makeHaLoServices(extensions: extensions);
  extensions.debugSetAvailableExtensions(const [_parksInfo]);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: OperationSheet(
            services: services,
            operation: Operation(uuid: 'op-1', data: const {'refs': []}),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (services, extensions);
}

Future<void> _pastDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

const _bearMountain = {'type': 'potaActivation', 'ref': 'US-1234', 'name': 'Bear Mountain State Park'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the sheet re-runs its search, as typed, once data files land', (tester) async {
    final (services, extensions) = await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'bear mountain');
    await _pastDebounce(tester);
    expect(find.text('Bear Mountain State Park'), findsNothing);
    final asked = extensions.asked.length;

    // The park list arrives.
    extensions.parks = const [_bearMountain];
    services.dataRevision.value++;
    await _pastDebounce(tester);

    expect(extensions.asked.skip(asked), ['bear mountain'], reason: 'one search, for what is in the box');
    expect(find.text('Bear Mountain State Park'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'bear mountain');
  });

  testWidgets('a closed sheet stops listening', (tester) async {
    final (services, _) = await _pump(tester);
    // ignore: invalid_use_of_protected_member
    expect(services.dataRevision.hasListeners, isTrue);

    // The notifier outlives every sheet; a listener left on it keeps each
    // closed sheet's State reachable for the rest of the session.
    await tester.pumpWidget(const SizedBox());
    // ignore: invalid_use_of_protected_member
    expect(services.dataRevision.hasListeners, isFalse);
  });

  testWidgets('a tick during an enable waits for the enable to finish, and is not lost', (tester) async {
    final (services, extensions) = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'parks');
    await _pastDebounce(tester);

    // The restart ticks, and then takes longer than the search debounce.
    final restart = Completer<void>();
    extensions.duringEnable = () async {
      services.dataRevision.value++;
      await restart.future;
    };
    await tester.tap(find.text('Enable Parks Everywhere').hitTestable());
    await tester.pump();
    final asked = extensions.asked.length;
    await tester.pump(const Duration(milliseconds: 500));
    expect(extensions.asked.length, asked, reason: 'a search mid-enable asks the old scopes and drops the spinner');

    extensions.parks = const [_bearMountain];
    restart.complete();
    await _pastDebounce(tester);
    expect(extensions.asked.length, greaterThan(asked + 1), reason: "the enable's own search, then the held tick's");
    expect(find.text('Bear Mountain State Park'), findsOneWidget);
  });
}

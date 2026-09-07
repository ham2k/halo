// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A hook that cannot answer must reach the caller AS a failure. The bug these
// guard against is not a crash but a lie: an absent control makes
// `isUnknownRefType` true, so a POTA hook that threw renders the operator's
// POTA ref with the "this extension isn't installed" treatment and sends them
// to Settings to re-enable something already on.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_extension_host/halo_extension_host.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/operation_location_screen.dart';

import '../support/halo_test_support.dart';

/// One `activity` fan-out answering with [entries], verbatim — the raw
/// `{key, ok, value|error}` shape `invokeHookAll` produces, so a test can
/// stage the failures the real host synthesizes.
ExtensionServiceWithFakeHost _serviceAnswering(List<Map<String, dynamic>> entries) =>
    ExtensionServiceWithFakeHost(FakeExtensionHost({'activity:*:operationControls': entries}));

/// A host that models `invokeHookAll`'s real timeout contract: the shared
/// budget expires with [settled] already in hand, and whether that work is
/// salvaged is the caller's `partialOnTimeout` to decide.
class _TimingOutHost implements ExtensionHost {
  final List<Map<String, dynamic>> settled;
  const _TimingOutHost(this.settled);

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async {
    if (!partialOnTimeout) throw HookTimeoutException('hook $category.$method* timed out');
    return [
      ...settled,
      {'key': 'slowpoke', 'ok': false, 'error': 'timed out', 'timedOut': true},
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ServiceWithHost extends ExtensionService {
  final ExtensionHost mockHost;
  _ServiceWithHost(this.mockHost);

  @override
  ExtensionHost? get host => mockHost;

  @override
  Future<void> start() async {}
}

/// A service with no host until `start()` has run — the cold-boot window,
/// which every other hook caller in the app awaits before asking.
class _BootsOnStart extends ExtensionService {
  final List<Map<String, dynamic>> entries;
  _BootsOnStart(this.entries);

  bool _started = false;

  @override
  ExtensionHost? get host => _started ? FakeExtensionHost({'activity:*:operationControls': entries}) : null;

  @override
  Future<void> start() async => _started = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('_collectControls reports failure', () {
    test('a hook that answered ok:false sets loadFailed, and its controls are not silently missing', () async {
      final service = _serviceAnswering([
        {'key': 'pota', 'ok': false, 'error': 'hook threw'},
        {
          'key': 'sota',
          'ok': true,
          'value': [
            {'refType': 'sota', 'order': 1}
          ]
        },
      ]);

      final result = await service.operationControls(const {});

      // The surviving hook's control still comes through — a failure must not
      // cost the operator the extensions that DID answer.
      expect(result.controls.map((c) => c['refType']), ['sota']);
      // Drop the ok:false branch's `loadFailed = true` and this is the only
      // assertion that fails: the controls list looks identical either way,
      // which is exactly why the caller could not tell the two apart.
      expect(result.loadFailed, isTrue);
    });

    test('a non-Map element neither throws nor is counted as a clean answer', () async {
      final service = _serviceAnswering([
        {
          'key': 'rogue',
          'ok': true,
          // `value.cast<Map>()` is LAZY: the TypeError this element provokes
          // surfaces during the addAll that forces it, past the
          // `on ExtensionHostException` catch and out of the future the
          // screens never await. Restore the cast and this test throws rather
          // than failing an expectation.
          'value': [
            {'refType': 'good'},
            42,
            null,
          ]
        },
      ]);

      final result = await service.operationControls(const {});

      expect(result.controls.map((c) => c['refType']), ['good']);
      expect(result.loadFailed, isTrue);
    });

    test('a hook that answered with no list at all contributed nothing, but did not fail', () async {
      // The kernel wraps every hook return as `value: (await …) ?? null`, so a
      // hook that falls off its end arrives as ok:true with a null value —
      // a legal no-op. `partitionHookEntries` counts that entry as a SUCCESS,
      // and treating it as a failure here would both contradict the shared
      // classifier and pin a permanent "controls unavailable" notice on any
      // operator running an extension that returns nothing.
      final service = _serviceAnswering([
        {'key': 'quiet', 'ok': true, 'value': null},
        {
          'key': 'pota',
          'ok': true,
          'value': [
            {'refType': 'pota'}
          ]
        },
      ]);

      final result = await service.operationControls(const {});

      expect(result.controls.map((c) => c['refType']), ['pota']);
      expect(result.loadFailed, isFalse);
    });

    test('one slow hook does not discard the controls the others already returned', () async {
      // The fan-out spends ONE budget on every hook, so without
      // `partialOnTimeout` the host throws and POTA's controls are lost
      // because SOTA is warming a cache — an operator's park ref stripped of
      // its fields by an extension it has nothing to do with. Drop the flag
      // and `_TimingOutHost` throws, so this fails on the controls, not on a
      // spied-upon argument.
      final service = _ServiceWithHost(const _TimingOutHost([
        {
          'key': 'pota',
          'ok': true,
          'value': [
            {'refType': 'pota'}
          ]
        },
      ]));

      final result = await service.operationControls(const {});

      expect(result.controls.map((c) => c['refType']), ['pota']);
      // Salvaged, but still not a clean answer: the operator is owed the
      // notice, and the ref types the slow hook owns must not go red.
      expect(result.loadFailed, isTrue);
    });

    test('a non-numeric order sorts rather than throwing out of the fan-out', () async {
      // `as num?` on a String throws from INSIDE the comparator — the same
      // escape route past the ExtensionHostException catch that the
      // per-element check closes, and one an extension reading its own config
      // reaches easily. It escapes into the unawaited futures the screens
      // start, and via operation_view's awaited call it also kills the
      // retitle, the entity-prefix resolve and the rescore beside it.
      // Restore the cast and this test throws instead of failing.
      final service = _serviceAnswering([
        {
          'key': 'rogue',
          'ok': true,
          'value': [
            {'refType': 'late', 'order': 2},
            {'refType': 'bogus', 'order': '1'},
            {'refType': 'early', 'order': 0},
          ]
        },
      ]);

      final result = await service.operationControls(const {});

      // An unreadable order sorts as 0 — a defensible position in the list
      // beats no controls at all, and beats taking three other subsystems
      // down with it.
      expect(result.controls.map((c) => c['refType']), ['bogus', 'early', 'late']);
    });

    test('every hook answering cleanly leaves loadFailed false', () async {
      // The negative case: without it, `loadFailed: true` hardcoded would pass
      // both tests above and permanently suppress the unknown-type treatment.
      final service = _serviceAnswering([
        {
          'key': 'pota',
          'ok': true,
          'value': [
            {'refType': 'pota'}
          ]
        },
      ]);

      final result = await service.operationControls(const {});

      expect(result.controls.map((c) => c['refType']), ['pota']);
      expect(result.loadFailed, isFalse);
    });
  });

  test('a runtime that is merely booting is not reported as a failure', () async {
    // `host == null` means the runtime is dead OR still starting, and only
    // the first is worth telling the operator about. The screens await
    // `start()` for exactly this reason; without it the activities sheet,
    // which can open on a ~300ms transition, shows "Activity controls
    // unavailable" for a runtime that is about to answer perfectly well.
    final service = _BootsOnStart([
      {
        'key': 'pota',
        'ok': true,
        'value': [
          {'refType': 'pota'}
        ]
      },
    ]);

    expect(service.host, isNull, reason: 'not booted yet');
    // What the screens do before asking.
    await service.start();
    final result = await service.operationControls(const {});

    expect(result.controls.map((c) => c['refType']), ['pota']);
    expect(result.loadFailed, isFalse);
  });

  group('OperationLocationScreen', () {
    Future<void> pumpWith(WidgetTester tester, ExtensionServiceWithFakeHost extensions) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService(await SharedPreferences.getInstance());
      final db = HaLoDatabase(NativeDatabase.memory());
      extensions.settings = settings;
      final services = HaLoServices(db, settings, extensions: extensions);

      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: OperationLocationScreen(
            services: services,
            operation: Operation(
              uuid: 'op-fail',
              data: {
                'refs': [
                  {'type': 'pota', 'ref': 'US-9999', 'name': 'A Park', 'grid': 'FN31pr'},
                ],
              },
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a failed fetch does not blame the extension, and says so', (tester) async {
      await pumpWith(
          tester,
          _serviceAnswering([
            {'key': 'pota', 'ok': false, 'error': 'timed out'},
          ]));

      final tileFinder = find.ancestor(of: find.text('US-9999'), matching: find.byType(ListTile));
      final tile = tester.widget<ListTile>(tileFinder);
      final theme = Theme.of(tester.element(tileFinder));

      // The whole point. POTA is installed and enabled; only its hook failed,
      // so the red "no longer installed" treatment would be a false statement
      // about the operator's setup.
      expect(tile.tileColor, isNot(theme.colorScheme.errorContainer.withValues(alpha: 0.4)),
          reason: 'a hook that could not answer is not the same as an uninstalled extension');
      expect(find.descendant(of: tileFinder, matching: find.byIcon(MdiIcons.help)), findsNothing);

      // Suppressing the red silently would swap a wrong explanation for none
      // at all, so the notice is what makes the suppression honest.
      expect(find.text(TranslationProvider.of(tester.element(tileFinder)).translations.operationLocationScreen.controlsUnavailableTitle),
          findsOneWidget);
    });

    testWidgets('a clean fetch with a genuinely unknown ref type still flags it', (tester) async {
      // The mutation this catches: suppressing the unknown-type treatment
      // unconditionally would pass the test above while destroying the signal
      // that a ref's extension really is gone.
      await pumpWith(tester, _serviceAnswering(const []));

      final tileFinder = find.ancestor(of: find.text('US-9999'), matching: find.byType(ListTile));
      final tile = tester.widget<ListTile>(tileFinder);
      final theme = Theme.of(tester.element(tileFinder));

      expect(tile.tileColor, theme.colorScheme.errorContainer.withValues(alpha: 0.4));
      expect(find.descendant(of: tileFinder, matching: find.byIcon(MdiIcons.help)), findsOneWidget);
    });
  });
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Error reporting (#76): the behaviors that matter are (a) a widget whose
// build throws degrades to the compact tile instead of taking the app (or
// the raw grey box) with it, and (b) the user hears about the first runtime
// error via a StatusBar notice — with a "Copy details" escape hatch for
// support — but is NOT spammed with one notice per error during a bad
// session. Sentry upload itself is compile-time gated (no DSN in tests) and
// exercised only in official builds.
//
// The hooks ErrorReportingService.run() installs are global (ErrorWidget.
// builder, FlutterError.onError, PlatformDispatcher.onError), and the test
// binding verifies the first two are back to their originals at the END of
// each test body — before tearDowns run — so every test restores them
// inline via try/finally rather than addTearDown.

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/views/error_tile.dart';

Future<void> withErrorHooks(Future<void> Function() body) async {
  final previousBuilder = ErrorWidget.builder;
  final previousOnError = FlutterError.onError;
  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  await ErrorReportingService.run(() {});
  try {
    await body();
  } finally {
    ErrorWidget.builder = previousBuilder;
    FlutterError.onError = previousOnError;
    PlatformDispatcher.instance.onError = previousPlatformOnError;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ErrorReportingService.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  test('Sentry stays disabled without a build-time DSN', () {
    // DSN presence is the only gate: builds without the secret (OSS
    // checkouts, plain local runs, this test binary) must carry zero
    // reporting behavior.
    expect(ErrorReportingService.sentryEnabled, isFalse);
  });

  testWidgets('a throwing widget renders the tile, siblings keep working', (tester) async {
    await withErrorHooks(() async {
      await tester.pumpWidget(MaterialApp(
        home: Row(children: [
          const Expanded(child: Text('healthy sibling')),
          Expanded(child: Builder(builder: (_) => throw StateError('boom'))),
        ]),
      ));
      expect(tester.takeException(), isA<StateError>());

      // The failed slot degrades to the tile; the rest of the tree survived.
      expect(find.byType(HaLoErrorTile), findsOneWidget);
      expect(find.textContaining('Something went wrong here'), findsOneWidget);
      expect(find.text('healthy sibling'), findsOneWidget);
    });
  });

  testWidgets('first error posts one StatusBar notice with Copy details, later errors do not repeat it',
      (tester) async {
    await withErrorHooks(() async {
      final statusBar = StatusBarService(await SharedPreferences.getInstance());
      ErrorReportingService.attachStatusBar(statusBar);

      // Deliver errors the way the framework does: through the chained
      // FlutterError.onError that run() installed. The test binding's own
      // handler sits underneath the chain and records each as the test's
      // pending exception — collected via takeException.
      final chained = FlutterError.onError!;
      chained(FlutterErrorDetails(exception: StateError('first boom')));
      expect(tester.takeException(), isA<StateError>());
      chained(FlutterErrorDetails(exception: StateError('second boom')));
      expect(tester.takeException(), isA<StateError>());

      // The notice is deferred to a microtask (posting synchronously from
      // inside an error handler could land mid-build); flush it.
      await tester.pump();

      // One notice despite two errors — a session with a repeating error
      // must not bury the operator's real notices under duplicates.
      final errorNotices = statusBar.activeNotices.where((n) => n.key == 'error-reporting:first-error');
      expect(errorNotices.length, 1);
      expect(errorNotices.single.actions.map((a) => a.label), contains('Copy details'));
    });
  });
}

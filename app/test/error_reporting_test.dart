// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Error reporting (#76): the behaviors that matter are (a) a widget whose
// build throws degrades to the compact tile instead of taking the app (or
// the raw grey box) with it, (b) the user hears about the first runtime
// error via a StatusBar notice — with a "Copy details" escape hatch for
// support — but is NOT spammed with one notice per error during a bad
// session, and (c) the backend (a real one is Sentry, but that's app_dist's
// concern — see app_dist/test/sentry_error_reporting_backend_test.dart)
// gets exactly the calls ErrorReportingService promises it: captureException
// per report(), and updateUserContext kept in step with consent/callsign/
// account changes. A FakeErrorReportingBackend below stands in for a real
// one, since ErrorReportingBackend is the only thing this file needs to know
// about.
//
// The hooks ErrorReportingService.run() installs are global (ErrorWidget.
// builder, FlutterError.onError, PlatformDispatcher.onError), and the test
// binding verifies the first two are back to their originals at the END of
// each test body — before tearDowns run — so every test restores them
// inline via try/finally rather than addTearDown.

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/error_reporting_backend.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/views/error_tile.dart';

Future<void> withErrorHooks(Future<void> Function() body, {ErrorReportingBackend? backend}) async {
  final previousBuilder = ErrorWidget.builder;
  final previousOnError = FlutterError.onError;
  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  await ErrorReportingService.run(() {}, backend: backend);
  try {
    await body();
  } finally {
    ErrorWidget.builder = previousBuilder;
    FlutterError.onError = previousOnError;
    PlatformDispatcher.instance.onError = previousPlatformOnError;
  }
}

class RecordedException {
  final Object error;
  final StackTrace? stackTrace;
  final String? context;
  RecordedException(this.error, this.stackTrace, this.context);
}

class RecordedUserContext {
  final String? callsign;
  final String? accountId;
  RecordedUserContext(this.callsign, this.accountId);
}

/// A test double standing in for a real backend (Sentry, in app_dist) —
/// records what ErrorReportingService sends it, without touching any SDK.
class FakeErrorReportingBackend implements ErrorReportingBackend {
  final exceptions = <RecordedException>[];
  final userContextCalls = <RecordedUserContext>[];

  /// Simulates the backend's own init failing before it ever calls
  /// startBody (e.g. a real Sentry init throwing) — the caller must still
  /// run the app via its own fallback.
  final bool failsToRun;
  FakeErrorReportingBackend({this.failsToRun = false});

  @override
  Future<bool> run(FutureOr<void> Function() startBody) async {
    if (failsToRun) return false;
    await startBody();
    return true;
  }

  @override
  void captureException(Object error, StackTrace? stackTrace, {String? context}) {
    exceptions.add(RecordedException(error, stackTrace, context));
  }

  @override
  void updateUserContext({String? callsign, String? accountId}) {
    userContextCalls.add(RecordedUserContext(callsign, accountId));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ErrorReportingService.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  test("the app still starts when the backend's own init fails before running the body", () async {
    // Mirrors a real Sentry init throwing (malformed DSN): the backend
    // reports it never took ownership, so run() must fall back to starting
    // the body itself rather than stranding the app on the native splash.
    var bodyRan = false;
    await ErrorReportingService.run(() {
      bodyRan = true;
    }, backend: FakeErrorReportingBackend(failsToRun: true));
    expect(bodyRan, isTrue);
  });

  test('reportingEnabled is false with no backend attached (the OSS default)', () {
    expect(ErrorReportingService.reportingEnabled, isFalse);
  });

  test('report() reaches the backend\'s captureException with the given context', () async {
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      ErrorReportingService.report(StateError('boom'), StackTrace.current, context: 'test-context');
      expect(backend.exceptions, hasLength(1));
      expect(backend.exceptions.single.error, isA<StateError>());
      expect(backend.exceptions.single.context, 'test-context');
      expect(ErrorReportingService.reportingEnabled, isTrue, reason: 'a backend is attached');
    }, backend: backend);
  });

  test('attachSettings pushes callsign + account id only once consent is on, and clears both when it turns off',
      () async {
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      final settings = SettingsService(await SharedPreferences.getInstance());
      ErrorReportingService.attachSettings(settings);
      // Attaching itself evaluates once: no consent yet, both fields null.
      expect(backend.userContextCalls.last.callsign, isNull);
      expect(backend.userContextCalls.last.accountId, isNull);

      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
      // Not consented yet — the callsign must NOT reach the backend.
      expect(backend.userContextCalls.last.callsign, isNull);

      await settings.updateSettingsGroup(SettingsService.privacyGroup, {'consentAppData': true});
      expect(backend.userContextCalls.last.callsign, 'KI2D');

      await settings.setSyncState({
        'accountData': {
          'current_account': {'uuid': 'acct-123'},
        },
      });
      expect(backend.userContextCalls.last.callsign, 'KI2D');
      expect(backend.userContextCalls.last.accountId, 'acct-123');

      await settings.updateSettingsGroup(SettingsService.privacyGroup, {'consentAppData': false});
      expect(backend.userContextCalls.last.callsign, isNull, reason: 'consent off must clear a prior opt-in');
      expect(backend.userContextCalls.last.accountId, isNull);
    }, backend: backend);
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

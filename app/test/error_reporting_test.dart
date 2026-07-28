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

import 'package:ham2k_logger/services/error_policy.dart';
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

/// Whether the policy exempts [details] from the loud path — no upload and
/// no notice. Which exact quiet tier it lands in is asserted per-rule in
/// error_policy_test.dart; these tests are about the NARROWNESS of each
/// exemption as it is applied by the real FlutterError hook.
bool _isNoise(FlutterErrorDetails details) =>
    !ErrorPolicy.decide(details.exception, details: details).disposition.uploads;

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

  group("Flutter's web focus-traversal null (#271)", () {
    // The one error this app swallows outright. It comes from an unsound `!` in
    // Flutter's own ReadingOrderTraversalPolicy, is reached only on web and only
    // when the browser view's focus changes, and the operator can do nothing
    // about it — so the notice it used to raise was pure alarm. These tests are
    // about the NARROWNESS of that exemption: everything else still reports.

    /// The real shape, from the stack recorded in ham2k/app-halo-dist#271.
    FlutterErrorDetails focusTraversalNull({
      Object? error,
      String? context = 'while dispatching notifications for WidgetsBindingObserver.didChangeViewFocus',
    }) =>
        FlutterErrorDetails(
          exception: error ?? TypeError(),
          stack: StackTrace.fromString('focus_traversal.dart 1685:90  _pickNext'),
          library: 'widgets library',
          context: context == null ? null : ErrorDescription(context),
        );

    test('is recognized on web, and only on web', () {
      final details = focusTraversalNull();
      ErrorPolicy.debugTreatAsWeb = false;
      expect(
        _isNoise(details),
        isFalse,
        reason: 'didChangeViewFocus only reaches that path on the multi-view embedder',
      );
      ErrorPolicy.debugTreatAsWeb = true;
      expect(_isNoise(details), isTrue);
    });

    test('a null check in that dispatch is recognized however the runtime spells it', () {
      ErrorPolicy.debugTreatAsWeb = true;
      // dart2js's own null-check failure has not always been a `TypeError`, so
      // the message is matched as well as the type.
      for (final error in <Object>[
        TypeError(),
        StateError('Unexpected null value.'),
        StateError('Null check operator used on a null value'),
      ]) {
        expect(
          _isNoise(focusTraversalNull(error: error)),
          isTrue,
          reason: '$error',
        );
      }
    });

    test('nothing else in that dispatch is swallowed', () {
      ErrorPolicy.debugTreatAsWeb = true;
      // Same place, a different failure. An observer of ours throwing here would
      // be a real bug, and matching the null check specifically is what keeps it
      // reportable.
      expect(
        _isNoise(focusTraversalNull(error: RangeError('index'))),
        isFalse,
      );
      expect(
        _isNoise(focusTraversalNull(error: StateError('boom'))),
        isFalse,
      );
    });

    test('the same null check from anywhere else is still reported', () {
      ErrorPolicy.debugTreatAsWeb = true;
      // A null check thrown during a build, a layout, a gesture: every other one
      // of these is a bug of ours and has to stay loud.
      expect(
        _isNoise(focusTraversalNull(context: 'while building MyWidget')),
        isFalse,
      );
      expect(
        _isNoise(focusTraversalNull(context: null)),
        isFalse,
        reason: 'no context at all is not a match either',
      );
    });

    testWidgets('is dropped before the notice, the console dump, or the backend', (tester) async {
      await withErrorHooks(() async {
        final statusBar = StatusBarService(await SharedPreferences.getInstance());
        ErrorReportingService.attachStatusBar(statusBar);
        ErrorPolicy.debugTreatAsWeb = true;

        final chained = FlutterError.onError!;
        chained(focusTraversalNull());
        await tester.pump(); // the notice would be queued as a microtask

        expect(
          statusBar.activeNotices.where((n) => n.key == 'error-reporting:first-error'),
          isEmpty,
          reason: 'no "Something went wrong" for a framework bug the operator cannot act on',
        );
        // And it never even reached the rest of the chain — which in production is
        // the backend's own handler and `presentError`. The test binding sits at
        // the end of that chain and records everything that gets there, so a null
        // pending exception is the proof.
        expect(tester.takeException(), isNull);

        // An ordinary framework error in the same session still does both.
        chained(FlutterErrorDetails(exception: StateError('boom')));
        expect(tester.takeException(), isA<StateError>());
        await tester.pump();
        expect(
          statusBar.activeNotices.where((n) => n.key == 'error-reporting:first-error'),
          hasLength(1),
        );
      });
    });
  });

  group('RenderFlex overflow warnings', () {
    // A debug-only layout assertion (release builds clip silently and never
    // throw this at all) — worth seeing locally, since it flags a real
    // layout bug, but not a "Something went wrong" notice aimed at an
    // operator who can't act on it, and not an external report for
    // something that literally cannot reach a release build.
    FlutterErrorDetails overflow({Object? error}) => FlutterErrorDetails(
          exception: error ?? FlutterError('A RenderFlex overflowed by 13 pixels on the right.\n'),
          library: 'rendering library',
        );

    test('is recognized by its message, whatever widget threw it', () {
      expect(_isNoise(overflow()), isTrue);
    });

    test('nothing else with the same FlutterError type is swallowed', () {
      expect(
        _isNoise(overflow(error: FlutterError('some other message'))),
        isFalse,
      );
    });

    test('a non-FlutterError exception is never matched, even with the same text', () {
      expect(
        _isNoise(overflow(error: StateError('A RenderFlex overflowed by 13 pixels on the right.'))),
        isFalse,
      );
    });

    testWidgets('is still console-visible, but posts no notice and never reaches the backend', (tester) async {
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        final statusBar = StatusBarService(await SharedPreferences.getInstance());
        ErrorReportingService.attachStatusBar(statusBar);

        final chained = FlutterError.onError!;
        chained(overflow());

        // Unlike the focus-traversal noise, this doesn't reach the test
        // binding's own exception capture (that's presentError()'s job,
        // not debugPrint's) — nothing pending is still the right check,
        // since it proves the call returned cleanly rather than propagating.
        expect(tester.takeException(), isNull);
        await tester.pump(); // the notice would be queued as a microtask
        expect(
          statusBar.activeNotices.where((n) => n.key == 'error-reporting:first-error'),
          isEmpty,
        );
        expect(backend.exceptions, isEmpty);
      }, backend: backend);
    });
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

  test('report() still honours the policy — an explicit catch cannot force noise into the backend', () async {
    // The same error can arrive through the framework hook or through a
    // try/catch someone added later; classification has to survive both, or
    // the exemption is only as good as the path the error happened to take.
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      ErrorReportingService.report(
        FlutterError('setState() or markNeedsBuild() called during build.'),
        StackTrace.current,
        context: 'some-caller',
      );
      expect(backend.exceptions, isEmpty);
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
      // 'error_outline' is a Flutter Icons constant name, not a Material
      // Design Icons one — resolveIconName only understands the latter (or
      // fa-prefixed FontAwesome), so that name silently fell back to the
      // puzzle-piece placeholder glyph instead of an actual error icon.
      expect(errorNotices.single.icon, 'alert-circle');
    });
  });

  testWidgets("an error notice doesn't survive a restart, unlike an ordinary one", (tester) async {
    await withErrorHooks(() async {
      final prefs = await SharedPreferences.getInstance();
      final statusBar = StatusBarService(prefs);
      ErrorReportingService.attachStatusBar(statusBar);

      // An ordinary notice persists fine — only the error notice opts out.
      statusBar.showNotice(key: 'ordinary', text: 'a plain notice');

      FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom')));
      tester.takeException(); // drain it — not what this test is about
      await tester.pump(); // the error notice is posted via a microtask

      expect(statusBar.activeNotices.map((n) => n.key), containsAll(['ordinary', 'error-reporting:first-error']));

      // Simulate a restart: a fresh StatusBarService reads back whatever
      // actually made it to disk.
      final reloaded = StatusBarService(prefs);
      final reloadedKeys = reloaded.activeNotices.map((n) => n.key);
      expect(reloadedKeys, contains('ordinary'));
      expect(
        reloadedKeys,
        isNot(contains('error-reporting:first-error')),
        reason: 'its "Copy details" action cannot survive a restart anyway — a dead, '
            'button-less copy left sitting in the footer forever would be worse than gone',
      );
    });
  });
}

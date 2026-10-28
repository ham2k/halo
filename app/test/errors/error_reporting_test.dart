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
// account changes. The FakeErrorReportingBackend in
// support/error_reporting_fakes.dart stands in for a real one, since
// ErrorReportingBackend is the only thing this file needs to know about.
//
// The hooks ErrorReportingService.run() installs are global (ErrorWidget.
// builder, FlutterError.onError, PlatformDispatcher.onError), and the test
// binding verifies the first two are back to their originals at the END of
// each test body — before tearDowns run — so every test restores them
// inline via try/finally (withErrorHooks) rather than addTearDown.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException, HookTimeoutException;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/config/version.dart' show Edition;
import 'package:ham2k_logger/services/error_policy.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';
import 'package:ham2k_logger/views/error_tile.dart';

import '../support/error_reporting_fakes.dart';

/// Whether the policy exempts [details] from the loud path — no upload and
/// no notice. Which exact quiet tier it lands in is asserted per-rule in
/// error_policy_test.dart; these tests are about the NARROWNESS of each
/// exemption as it is applied by the real FlutterError hook.
bool _isNoise(FlutterErrorDetails details) => !ErrorPolicy.decide(details.exception, details: details).disposition.uploads;

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

    /// The real shape, from the stack recorded in ham2k/halo-dist#271.
    FlutterErrorDetails focusTraversalNull({
      Object? error,
      String? context = 'while dispatching notifications for WidgetsBindingObserver.didChangeViewFocus',
    }) => FlutterErrorDetails(
      exception: error ?? TypeError(),
      stack: StackTrace.fromString('focus_traversal.dart 1685:90  _pickNext'),
      library: 'widgets library',
      context: context == null ? null : ErrorDescription(context),
    );

    test('is recognized on web, and only on web', () {
      final details = focusTraversalNull();
      ErrorPolicy.debugTreatAsWeb = false;
      expect(_isNoise(details), isFalse, reason: 'didChangeViewFocus only reaches that path on the multi-view embedder');
      ErrorPolicy.debugTreatAsWeb = true;
      expect(_isNoise(details), isTrue);
    });

    test('a null check in that dispatch is recognized however the runtime spells it', () {
      ErrorPolicy.debugTreatAsWeb = true;
      // dart2js's own null-check failure has not always been a `TypeError`, so
      // the message is matched as well as the type.
      for (final error in <Object>[TypeError(), StateError('Unexpected null value.'), StateError('Null check operator used on a null value')]) {
        expect(_isNoise(focusTraversalNull(error: error)), isTrue, reason: '$error');
      }
    });

    test('nothing else in that dispatch is swallowed', () {
      ErrorPolicy.debugTreatAsWeb = true;
      // Same place, a different failure. An observer of ours throwing here would
      // be a real bug, and matching the null check specifically is what keeps it
      // reportable.
      expect(_isNoise(focusTraversalNull(error: RangeError('index'))), isFalse);
      expect(_isNoise(focusTraversalNull(error: StateError('boom'))), isFalse);
    });

    test('the same null check from anywhere else is still reported', () {
      ErrorPolicy.debugTreatAsWeb = true;
      // A null check thrown during a build, a layout, a gesture: every other one
      // of these is a bug of ours and has to stay loud.
      expect(_isNoise(focusTraversalNull(context: 'while building MyWidget')), isFalse);
      expect(_isNoise(focusTraversalNull(context: null)), isFalse, reason: 'no context at all is not a match either');
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
        expect(statusBar.activeNotices.where((n) => n.key == 'error-reporting:first-error'), hasLength(1));
      });
    });
  });

  group('RenderFlex overflow warnings', () {
    // A debug-only layout assertion (release builds clip silently and never
    // throw this at all) — worth seeing locally, since it flags a real
    // layout bug, but not a "Something went wrong" notice aimed at an
    // operator who can't act on it, and not an external report for
    // something that literally cannot reach a release build.
    FlutterErrorDetails overflow({Object? error}) =>
        FlutterErrorDetails(exception: error ?? FlutterError('A RenderFlex overflowed by 13 pixels on the right.\n'), library: 'rendering library');

    test('is recognized by its message, whatever widget threw it', () {
      expect(_isNoise(overflow()), isTrue);
    });

    test('nothing else with the same FlutterError type is swallowed', () {
      expect(_isNoise(overflow(error: FlutterError('some other message'))), isFalse);
    });

    test('a non-FlutterError exception is never matched, even with the same text', () {
      expect(_isNoise(overflow(error: StateError('A RenderFlex overflowed by 13 pixels on the right.'))), isFalse);
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
        expect(statusBar.activeNotices.where((n) => n.key == 'error-reporting:first-error'), isEmpty);
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

  test('breadcrumb() reaches the backend\'s addBreadcrumb with the given category', () async {
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      ErrorReportingService.breadcrumb('map webview created', category: 'webview');
      expect(backend.breadcrumbs, hasLength(1));
      expect(backend.breadcrumbs.single.message, 'map webview created');
      expect(backend.breadcrumbs.single.category, 'webview');
    }, backend: backend);
  });

  test('breadcrumb() swallows a throwing backend — call sites run it right before their own dispose()', () async {
    final backend = FakeErrorReportingBackend(breadcrumbThrows: true);
    await withErrorHooks(() async {
      expect(() => ErrorReportingService.breadcrumb('map webview disposing', category: 'webview'), returnsNormally);
    }, backend: backend);
  });

  test('diagnostic() reaches the backend with what it was given', () async {
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      // The RETURN value, not just the call: DEVBENCH's headline says
      // "(local only)" on `!uploaded`, so a `true` here that should be `false`
      // tells an operator their report left the device when it did not.
      expect(ErrorReportingService.diagnostic(title: 'DEVBENCH', body: 'insert: 0.4ms'), isTrue);
    }, backend: backend);

    expect(backend.diagnostics, [('DEVBENCH', 'insert: 0.4ms')]);
  });

  test('diagnostic() swallows a throwing backend — an operator is waiting on the result', () async {
    // The caller is a command reporting a benchmark it just finished. A
    // reporting backend that cannot send must not take the result down with
    // it, so the failure stops here rather than reaching the command.
    final backend = FakeErrorReportingBackend(diagnosticThrows: true);
    await withErrorHooks(() async {
      expect(() => ErrorReportingService.diagnostic(title: 'DEVBENCH', body: 'rows'), returnsNormally);
      // And says it did not land, which is what stops the headline claiming
      // the numbers reached the backend.
      expect(ErrorReportingService.diagnostic(title: 'DEVBENCH', body: 'rows'), isFalse);
    }, backend: backend);
  });

  test('report() still honours the policy — an explicit catch cannot force noise into the backend', () async {
    // The same error can arrive through the framework hook or through a
    // try/catch someone added later; classification has to survive both, or
    // the exemption is only as good as the path the error happened to take.
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      ErrorReportingService.report(FlutterError('setState() or markNeedsBuild() called during build.'), StackTrace.current, context: 'some-caller');
      expect(backend.exceptions, isEmpty);
    }, backend: backend);
  });

  test('attachSettings pushes callsign, account id and log path only once consent is on, and clears them all when it turns off', () async {
    // The log path names the operator's OS account, so it is personal data
    // exactly as the callsign is — sent ungated, it would identify an
    // operator who never opted in.
    const path = r'C:\Users\someone\AppData\Local\Ham2K Logger\ham2k_logger.sqlite';
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      final settings = SettingsService(await SharedPreferences.getInstance());
      ErrorReportingService.attachSettings(settings, databasePath: path);
      // Attaching itself evaluates once: no consent yet, every field null.
      expect(backend.userContextCalls.last.callsign, isNull);
      expect(backend.userContextCalls.last.accountId, isNull);
      expect(backend.userContextCalls.last.databasePath, isNull);

      await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
      // Not consented yet — the callsign must NOT reach the backend.
      expect(backend.userContextCalls.last.callsign, isNull);

      await settings.updateSettingsGroup(SettingsService.privacyGroup, {'consentAppData': true});
      expect(backend.userContextCalls.last.callsign, 'KI2D');
      expect(backend.userContextCalls.last.databasePath, path);

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
      expect(backend.userContextCalls.last.databasePath, isNull);
    }, backend: backend);
  });

  testWidgets('a throwing widget renders the tile, siblings keep working', (tester) async {
    await withErrorHooks(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              const Expanded(child: Text('healthy sibling')),
              Expanded(child: Builder(builder: (_) => throw StateError('boom'))),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isA<StateError>());

      // The failed slot degrades to the tile; the rest of the tree survived.
      expect(find.byType(HaLoErrorTile), findsOneWidget);
      expect(find.textContaining('Something went wrong here'), findsOneWidget);
      expect(find.text('healthy sibling'), findsOneWidget);
    });
  });

  testWidgets('first error posts one StatusBar notice with Copy details, later errors do not repeat it', (tester) async {
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
        reason:
            'its "Copy details" action cannot survive a restart anyway — a dead, '
            'button-less copy left sitting in the footer forever would be worse than gone',
      );
    });
  });

  group('the notice text', () {
    final stack = StackTrace.fromString(
      '#0      Iterable.first (dart:core/iterable.dart:12:5)\n'
      '#1      _SomeFrameworkThing.build (package:flutter/src/widgets/framework.dart:99:3)\n'
      '#2      QsoList.render (package:ham2k_logger/views/qso_list.dart:42:7)\n'
      '#3      main (package:ham2k_logger/main.dart:1:1)\n',
    );

    test('a Dev build names the error and the first frame of ours', () {
      final text = ErrorReportingService.noticeText(StateError('No element'), stack, edition: Edition.dev);
      expect(text, contains('Bad state: No element'));
      // The innermost frame is the SDK's and the next the framework's; both
      // say where the throw landed, not which call of ours made it.
      expect(text, contains('at QsoList.render (package:ham2k_logger/views/qso_list.dart:42:7)'));
      expect(text, isNot(contains('framework.dart')));
    });

    test("a web debug build's frames are found too", () {
      final webStack = StackTrace.fromString(
        'dart-sdk/lib/core/iterable.dart 12:5  get first\n'
        'packages/halo_core/src/db/repo.dart 7:3  load\n',
      );
      final text = ErrorReportingService.noticeText(StateError('x'), webStack, edition: Edition.dev);
      expect(text, contains('at packages/halo_core/src/db/repo.dart 7:3  load'));
    });

    test('a long framework message is cut to what fits a card', () {
      final long = List.generate(40, (i) => 'line $i').join('\n');
      final text = ErrorReportingService.noticeText(Exception(long), null, edition: Edition.dev);
      expect(text.split('\n').length, lessThanOrEqualTo(4), reason: 'the rest is on "Copy details"');
      expect(text, isNot(contains('line 39')));
    });

    test('so is a long single-line one', () {
      // A FormatException quoting a whole payload is one line, so the line cut
      // alone never shortens it.
      final text = ErrorReportingService.noticeText(FormatException('x' * 5000), null, edition: Edition.dev);
      expect(text.length, lessThan(500));
    });

    test('Next and Regular keep the reassurance, with one line of what failed and never a stack frame', () {
      for (final edition in [Edition.next, Edition.prod]) {
        final text = ErrorReportingService.noticeText(StateError('No element\nmore detail'), stack, edition: edition);
        expect(text, startsWith('An unexpected error occurred'));
        // Without it, a support message can only say "something went wrong",
        // and the operator has nothing to tell one failure from the next.
        expect(text, contains('No element'));
        expect(text, isNot(contains('more detail')), reason: 'the rest is on "Copy details"');
        expect(text, isNot(contains('qso_list.dart')), reason: 'an operator cannot act on a stack frame');
      }
    });

    test('Next and Regular cut a long message to a line that fits a card', () {
      final text = ErrorReportingService.noticeText(FormatException('x' * 5000), null, edition: Edition.prod);
      expect(text.length, lessThan(400));
    });

    test("Next and Regular add no line for a backend's own label of an event with no error behind it", () {
      final text = ErrorReportingService.noticeText('Reported error', null, edition: Edition.prod);
      expect(text, isNot(contains('Reported error')));
    });

    test('Next and Regular keep a query string off the footer, where a request carries its key', () {
      final error = Exception('ClientException: Connection refused, uri=https://api.example.com/v1/lookup?key=s3cret&call=N0DEV');
      final text = ErrorReportingService.noticeText(error, null, edition: Edition.prod);
      expect(text, contains('https://api.example.com/v1/lookup?…'), reason: 'which host failed is the useful part');
      expect(text, isNot(contains('s3cret')));
    });
  });

  group('a failure the caller already told the operator about', () {
    // The trap: the backend feeds every notify-tier error it captures into the
    // generic "Something went wrong", so a catch that shows its own words and
    // then reports gets both notices unless the service knows about the first.

    Future<StatusBarService> attachedStatusBar() async {
      final statusBar = StatusBarService(await SharedPreferences.getInstance());
      ErrorReportingService.attachStatusBar(statusBar);
      return statusBar;
    }

    Iterable<StatusBarNotice> generic(StatusBarService statusBar) => statusBar.activeNotices.where((n) => n.key == 'error-reporting:first-error');

    test("shows the caller's notice in place of the generic one, and still uploads", () async {
      final backend = FakeErrorReportingBackend(feedsNotice: true);
      await withErrorHooks(() async {
        final statusBar = await attachedStatusBar();
        ErrorReportingService.report(
          ExtensionHostException('No entry found on the listing.'),
          StackTrace.current,
          context: 'test',
          notice: ErrorNotice(statusBar, key: 'test:failed', title: "Couldn't process it"),
        );
        await Future<void>.delayed(Duration.zero); // the generic notice is posted from a microtask

        expect(generic(statusBar), isEmpty);
        final notice = statusBar.activeNotices.singleWhere((n) => n.key == 'test:failed');
        expect(notice.title, "Couldn't process it");
        expect(notice.text, 'No entry found on the listing.', reason: 'the type name says nothing to an operator');
        expect(notice.actions.map((a) => a.label), contains('Copy details'), reason: 'the trace is what a support request needs');
        expect(backend.exceptions, hasLength(1), reason: 'telling the operator is not a reason to keep the backend from the failure');
      }, backend: backend);
    });

    test("the caller's notice stays in history across a restart, unlike the generic one", () async {
      // Its text names the failure, so it still says something once its
      // "Copy details" is gone; dropping it would leave an offline
      // "Couldn't download" with no trace after the app restarts.
      await withErrorHooks(() async {
        final prefs = await SharedPreferences.getInstance();
        final statusBar = StatusBarService(prefs);
        ErrorReportingService.report(
          StateError('offline'),
          StackTrace.current,
          notice: ErrorNotice(statusBar, key: 'test:download', title: "Couldn't download"),
        );
        await Future<void>.delayed(Duration.zero);
        expect(StatusBarService(prefs).history.map((n) => n.key), contains('test:download'));
      });
    });

    test('told: true keeps the generic notice away without a notice of its own', () async {
      final backend = FakeErrorReportingBackend(feedsNotice: true);
      await withErrorHooks(() async {
        final statusBar = await attachedStatusBar();
        ErrorReportingService.report(StateError('picker failed'), StackTrace.current, told: true);
        await Future<void>.delayed(Duration.zero);
        expect(statusBar.activeNotices, isEmpty);
        expect(backend.exceptions, hasLength(1));

        // Only that error: the next one nobody told the operator about still says so.
        ErrorReportingService.report(StateError('untold'), StackTrace.current);
        await Future<void>.delayed(Duration.zero);
        expect(generic(statusBar), hasLength(1));
      }, backend: backend);
    });

    test('a failure reported on its way up through two catches uploads once', () async {
      // A catch that reports and rethrows, under a catch that reports whatever
      // reaches it: the same error AND the same trace arrive twice.
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        Future<void> inner() async {
          try {
            throw StateError('boom');
          } catch (e, stack) {
            ErrorReportingService.report(e, stack, context: 'inner');
            rethrow;
          }
        }

        try {
          await inner();
        } catch (e, stack) {
          ErrorReportingService.report(e, stack, context: 'outer');
        }
        expect(backend.exceptions.map((e) => e.context), ['inner']);

        // Identity, not equality of the text: a second failure that reads the same is a second failure.
        ErrorReportingService.report(StateError('boom'), StackTrace.current, context: 'again');
        expect(backend.exceptions, hasLength(2));
      }, backend: backend);
    });

    test('a const exception thrown twice is two failures, and uploads twice', () async {
      // The trap: a const exception is ONE object however often it is thrown,
      // so matching on the object alone drops every report after the first
      // for the rest of the session.
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        ErrorReportingService.report(const FormatException('unsupported'), StackTrace.current, context: 'first');
        ErrorReportingService.report(const FormatException('unsupported'), StackTrace.current, context: 'second');
        expect(backend.exceptions.map((e) => e.context), ['first', 'second']);
      }, backend: backend);
    });

    test('messageOf drops the type an operator cannot read, and nothing else', () {
      expect(ErrorReportingService.messageOf(ExtensionHostException('No entry.')), 'No entry.');
      expect(ErrorReportingService.messageOf(HookTimeoutException('took too long')), 'took too long');
      expect(ErrorReportingService.messageOf(Exception('plain')), 'plain');
      expect(ErrorReportingService.messageOf(StateError('x')), 'Bad state: x', reason: 'a message of its own type keeps its wording');
    });
  });
}

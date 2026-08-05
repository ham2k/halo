// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Global error capture: backend upload when one is injected, local
// logging and a StatusBar notice always — as far as [ErrorPolicy] allows.
// WHAT an error deserves is decided there and only there (see
// services/error_policy.dart); this file is the plumbing that carries the
// decision out to the console, the backend and the StatusBar.
//
// Vendor-specific reporting code (Sentry, DSN handling, …) lives entirely in
// app_dist, behind the [ErrorReportingBackend] interface — this file only
// knows the generic shape. The OSS app runs with no backend at all (see
// [NoopErrorReportingBackend]); a real one is injected via [run]'s `backend`
// parameter, mirroring MetricsService/runHaLoApp.
//
// Static rather than a HaLoServices member on purpose: the hooks must be
// installed around runApp(), long before bootstrap() has built any
// services. The StatusBar surface attaches later via [attachStatusBar]
// (errors before that point are logged/uploaded but produce no notice).
//
// User context (callsign + LoFi account id) flows through [attachSettings]
// the same way: SettingsService already notifyListeners on a callsign
// change, an account link/switch, and the consent toggle itself, so one
// listener here re-evaluates on every trigger without duplicating this
// logic at each call site. Only the identifying fields are gated behind
// SettingsService.consentAppData ("Share Usage Data") — reporting itself
// (this file, and a real backend's crash uploads) is NOT consent-gated,
// unlike app-polo's own Sentry integration, which disables Sentry entirely
// without consent. Cleared (both fields null) the moment consent is off, so
// a prior opt-in's value can't linger in the backend's own scope.

import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';

import 'error_policy.dart';
import 'error_reporting_backend.dart';
import '../views/error_tile.dart';
import 'settings_service.dart';
import 'status_bar_service.dart';

class ErrorReportingService {
  ErrorReportingService._();

  static ErrorReportingBackend _backend = const NoopErrorReportingBackend();

  /// Whether a real backend is active (vs. the OSS no-op default). Local
  /// logging and notices happen either way.
  static bool get reportingEnabled => _backend is! NoopErrorReportingBackend;

  static StatusBarService? _statusBar;
  static bool _noticeShown = false;

  /// Wraps ALL of app startup — main() puts its entire body inside [body],
  /// including WidgetsFlutterBinding.ensureInitialized() and runApp(), so
  /// that binding, bootstrap and app all live in the same zone (a split
  /// would trip Flutter's zone-mismatch warning, and root-zone errors would
  /// escape capture on web, where async errors reach the zone handler
  /// rather than PlatformDispatcher.onError).
  ///
  /// [backend] takes ownership of [startBody] if it can (e.g. Sentry's own
  /// guarded zone); if it can't (no backend, or its own init failed before
  /// ever starting the body), [startBody] runs in our own runZonedGuarded
  /// instead, so uncaught async errors are logged and noticed (but don't
  /// take the session down) on every platform, including web.
  static Future<void> run(FutureOr<void> Function() body, {ErrorReportingBackend? backend}) async {
    _backend = backend ?? const NoopErrorReportingBackend();
    var bodyStarted = false;
    FutureOr<void> startBody() {
      bodyStarted = true;
      _installLocalHooks();
      return body();
    }

    final tookOwnership = await _backend.run(startBody);
    if (tookOwnership || bodyStarted) return;

    runZonedGuarded(() {
      startBody();
    }, (error, stackTrace) {
      // Uncaught async error with no backend (or its init broken): log +
      // notice. Reaching a zone handler means it never propagates, so a
      // stray async error can't take down a logging session mid-contact.
      final decision = ErrorPolicy.decide(error);
      if (!decision.disposition.uploads) {
        ErrorPolicy.logDecision(decision, error, stackTrace: stackTrace);
        return;
      }
      debugPrint('[error-reporting] uncaught async error: $error\n$stackTrace');
      if (decision.disposition.notifies) notify(error, stackTrace);
    });
  }

  /// Report a caught error explicitly (e.g. bootstrap() failures that are
  /// already surfaced by BootErrorScreen). Always logs locally; uploads via
  /// the active backend unless [ErrorPolicy] classifies it as noise, so a
  /// known-harmless error stays out of the backend however it was caught.
  static void report(Object error, StackTrace? stackTrace, {String? context}) {
    debugPrint('[error-reporting] ${context ?? 'caught'}: $error\n${stackTrace ?? ''}');
    final decision = ErrorPolicy.decide(error);
    if (!decision.disposition.uploads) {
      ErrorPolicy.logDecision(decision, error);
      return;
    }
    _backend.captureException(error, stackTrace, context: context);
  }

  /// Consecutive failures per [reportIfRepeated] key. Process-wide and
  /// never persisted: "stuck" is a claim about this session.
  static final Map<String, int> _failureStreaks = {};

  /// How many consecutive failures make a call worth reporting.
  static const repeatedFailureThreshold = 3;

  /// Reports [error] only once the same [key] has failed
  /// [repeatedFailureThreshold] times in a row, and only on the attempt that
  /// reaches that count.
  ///
  /// For a recoverable call the operator triggers by hand, a single failure
  /// is almost always the world being unreliable — a tunnel, a captive
  /// portal, a server restarting — and uploading it tells nobody anything
  /// they can act on. The same call failing every single time is a defect,
  /// and without this its only trace is a support message describing a
  /// button that did nothing.
  ///
  /// Firing exactly AT the threshold rather than at-or-above it is the
  /// point: a permanently broken call would otherwise just trade a flood of
  /// single failures for a flood of streak reports. [recordSuccess] is what
  /// makes the count mean "stuck right now" instead of "unlucky a few times
  /// over a long session" — pair the two on every call site, or the streak
  /// only ever grows.
  ///
  /// Still policy-gated, like [report]: a streak of known noise stays noise.
  static void reportIfRepeated(
    String key,
    Object error,
    StackTrace? stackTrace, {
    String? context,
    int threshold = repeatedFailureThreshold,
  }) {
    final streak = (_failureStreaks[key] ?? 0) + 1;
    _failureStreaks[key] = streak;
    if (streak != threshold) return;
    report(error, stackTrace, context: '${context ?? key} (failed $streak times in a row)');
  }

  /// Clears [key]'s streak — call on every success of a call that reports
  /// through [reportIfRepeated].
  static void recordSuccess(String key) {
    _failureStreaks.remove(key);
  }

  @visibleForTesting
  static void resetFailureStreaks() => _failureStreaks.clear();

  /// Called once bootstrap() has services; from then on the first runtime
  /// error of the session also posts a dismissible StatusBar notice.
  static void attachStatusBar(StatusBarService statusBar) {
    _statusBar = statusBar;
  }

  /// Keeps the backend's user context (callsign + LoFi account id) in step
  /// with [settings] for the rest of the session — see file header.
  static void attachSettings(SettingsService settings) {
    _updateUserContext(settings);
    settings.addListener(() => _updateUserContext(settings));
  }

  static void _updateUserContext(SettingsService settings) {
    if (!settings.consentAppData) {
      _backend.updateUserContext();
      return;
    }
    final call = settings.activeProfile.operatorCall;
    final accountData = settings.syncState['accountData'] as Map?;
    final accountId = (accountData?['current_account'] as Map?)?['uuid'] as String?;
    _backend.updateUserContext(callsign: call.isEmpty ? null : call, accountId: accountId);
  }

  static void _installLocalHooks() {
    // Framework errors (widget build/layout/paint). A real backend's own
    // handler, when active, is already in this chain; preserve it.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final decision = ErrorPolicy.decide(details.exception, details: details);
      // Below the upload tier the chain stops here: no framework dump, no
      // backend capture (previousOnError is where a real backend's hook
      // lives), no notice — only whatever line the policy asks for.
      if (!decision.disposition.uploads) {
        ErrorPolicy.logDecision(decision, details.exception, stackTrace: details.stack);
        return;
      }
      if (previousOnError != null) {
        previousOnError(details);
      } else {
        FlutterError.presentError(details);
      }
      if (decision.disposition.notifies) notify(details.exception, details.stack);
    };

    // Replace Flutter's grey/red box with the compact branded tile; the
    // failed widget's slot shows the tile, the rest of the app keeps
    // working (see views/error_tile.dart).
    ErrorWidget.builder = (details) => HaLoErrorTile(details: details);
  }

  /// Queue the once-per-session StatusBar notice (if the bar is attached).
  /// Public so a backend (app_dist) can feed its own captured events (e.g.
  /// Sentry's beforeSend, the only path for an uncaught async error, which
  /// [_installLocalHooks] never sees) into the same throttle. Deferred to a
  /// microtask: this is called from inside error handlers, which for widget
  /// errors means mid build/layout — and showNotice()'s notifyListeners()
  /// would then trip "markNeedsBuild() called during build" and throw from
  /// within the error handler itself. The throttle flag is set synchronously
  /// so concurrent errors can't double-post.
  static void notify(Object error, StackTrace? stackTrace) {
    final statusBar = _statusBar;
    if (statusBar == null || _noticeShown) return;
    _noticeShown = true;
    final details = '$error\n\n${stackTrace ?? ''}';
    scheduleMicrotask(() {
      statusBar.showNotice(
        key: 'error-reporting:first-error',
        // resolveIconName expects a Material Design Icons name (kebab-case)
        // or an fa- prefixed FontAwesome one — a Flutter Icons constant
        // name like 'error_outline' (a different set entirely) matches
        // neither and silently falls back to the puzzle-piece placeholder.
        icon: 'alert-circle',
        title: 'Something went wrong',
        text: reportingEnabled
            ? 'An unexpected error occurred and was reported. The app should keep working; restart if anything looks off.'
            : 'An unexpected error occurred. The app should keep working; restart if anything looks off.',
        actions: [
          StatusBarAction(
            label: 'Copy details',
            onTap: () => unawaited(Clipboard.setData(ClipboardData(text: details))),
          ),
        ],
        // Its whole point is the "Copy details" action, which can't survive
        // a restart (a VoidCallback isn't serializable) — persisting it
        // anyway just leaves a dead, button-less copy of a past error
        // sitting in the footer indefinitely, with no way to act on it or
        // learn what it even was.
        persist: false,
      );
    });
  }

  /// Test seam: forget the attached status bar, notice throttle, and backend
  /// (and the policy's own once-per-session state, which rides along with a
  /// session the same way).
  @visibleForTesting
  static void resetForTesting() {
    _statusBar = null;
    _noticeShown = false;
    _backend = const NoopErrorReportingBackend();
    ErrorPolicy.resetForTesting();
  }
}

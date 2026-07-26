// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Global error capture (#76): backend upload when one is injected, local
// logging and a StatusBar notice always.
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
      debugPrint('[error-reporting] uncaught async error: $error\n$stackTrace');
      notify(error, stackTrace);
    });
  }

  /// Report a caught error explicitly (e.g. bootstrap() failures that are
  /// already surfaced by BootErrorScreen). Uploads via the active backend;
  /// always logs locally.
  static void report(Object error, StackTrace? stackTrace, {String? context}) {
    debugPrint('[error-reporting] ${context ?? 'caught'}: $error\n${stackTrace ?? ''}');
    _backend.captureException(error, stackTrace, context: context);
  }

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
      if (previousOnError != null) {
        previousOnError(details);
      } else {
        FlutterError.presentError(details);
      }
      notify(details.exception, details.stack);
    };

    // Replace Flutter's grey/red box with the compact branded tile; the
    // failed widget's slot shows the tile, the rest of the app keeps
    // working (#76 — see views/error_tile.dart).
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
        icon: 'error_outline',
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
      );
    });
  }

  /// Test seam: forget the attached status bar, notice throttle, and backend.
  @visibleForTesting
  static void resetForTesting() {
    _statusBar = null;
    _noticeShown = false;
    _backend = const NoopErrorReportingBackend();
  }
}

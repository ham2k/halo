// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Global error capture (#76): Sentry upload when configured, local logging
// and a StatusBar notice always.
//
// Sentry activates whenever a DSN was baked in at build time via
// --dart-define=HALO_SENTRY_DSN=… — DSN presence is the only gate (same
// absent-secret-means-disabled convention as the Mapbox token), so OSS and
// local builds carry zero reporting behavior, while any edition — including
// Dev, e.g. the halo-dev web deploy — reports when its build was given the
// secret. options.environment carries the edition, keeping dev noise
// separable in Sentry even with per-edition DSNs (it doubles as a tripwire
// for a secret wired to the wrong edition). Passing the define to a local
// `flutter run` is also the way to smoke-test the pipeline.
//
// Static rather than a HaLoServices member on purpose: the hooks must be
// installed around runApp(), long before bootstrap() has built any
// services. The StatusBar surface attaches later via [attachStatusBar]
// (errors before that point are logged/uploaded but produce no notice).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/version.dart';
import '../views/error_tile.dart';
import 'status_bar_service.dart';

class ErrorReportingService {
  ErrorReportingService._();

  static const String dsn = String.fromEnvironment('HALO_SENTRY_DSN');

  /// Whether errors are uploaded to Sentry: a build-time DSN is the only
  /// gate (file header). Local logging and notices are independent of this.
  static bool get sentryEnabled => dsn.isNotEmpty;

  static StatusBarService? _statusBar;
  static bool _noticeShown = false;

  /// Wraps ALL of app startup — main() puts its entire body inside [body],
  /// including WidgetsFlutterBinding.ensureInitialized() and runApp(), so
  /// that binding, bootstrap and app all live in the same zone (a split
  /// would trip Flutter's zone-mismatch warning, and root-zone errors would
  /// escape capture on web, where async errors reach the zone handler
  /// rather than PlatformDispatcher.onError).
  ///
  /// Sentry enabled → the app runs inside `SentryFlutter.init`'s appRunner
  /// (its guarded zone + its own hooks, which ours chain onto). If init
  /// itself throws — e.g. a malformed DSN secret — the app MUST still
  /// start: fall through to the local-only path rather than stranding every
  /// build of an edition on the native splash.
  ///
  /// Sentry disabled → [body] runs in our own runZonedGuarded, so uncaught
  /// async errors are logged and noticed (but don't take the session down)
  /// on every platform, including web.
  static Future<void> run(FutureOr<void> Function() body) async {
    var bodyStarted = false;
    FutureOr<void> startBody() {
      bodyStarted = true;
      _installLocalHooks();
      return body();
    }

    if (sentryEnabled) {
      try {
        await SentryFlutter.init(
          (options) {
            options.dsn = dsn;
            options.environment = kEdition.name;
            options.release = 'ham2k-logger@$kPublicVersion+$kBuildNumber';
            options.dist = '$kBuildNumber';
            // Crash reporting only — no performance tracing, session replay,
            // screenshots, or PII. A logging app handles operator callsigns
            // and locations; keep uploads to the error and its stack.
            options.tracesSampleRate = null;
            options.attachScreenshot = false;
            options.sendDefaultPii = false;
            // Every captured event (framework, uncaught-async — which on web
            // arrives via Sentry's zone, not PlatformDispatcher.onError —
            // or manual report()) also feeds the once-per-session notice,
            // and stays visible on the console during DSN smoke tests
            // (Sentry's onError integration otherwise swallows the default
            // print of uncaught async errors).
            options.beforeSend = (event, hint) {
              if (kDebugMode) debugPrint('[error-reporting] sentry event: ${event.throwable ?? event.message?.formatted}');
              _notify(event.throwable ?? 'Reported error', null);
              return event;
            };
          },
          appRunner: () async {
            if (kGitSha.isNotEmpty) {
              await Sentry.configureScope((scope) => scope.setTag('git_sha', kGitSha));
            }
            await startBody();
          },
        );
        return;
      } catch (error, stackTrace) {
        debugPrint('[error-reporting] Sentry init failed (malformed DSN?), continuing without upload: $error\n$stackTrace');
        // If init failed after the app was already running there's nothing
        // left to start; otherwise fall through to the local-only path.
        if (bodyStarted) return;
      }
    }

    runZonedGuarded(() {
      startBody();
    }, (error, stackTrace) {
      // Uncaught async error with Sentry off (or its init broken): log +
      // notice. Reaching a zone handler means it never propagates, so a
      // stray async error can't take down a logging session mid-contact.
      debugPrint('[error-reporting] uncaught async error: $error\n$stackTrace');
      _notify(error, stackTrace);
    });
  }

  /// Report a caught error explicitly (e.g. bootstrap() failures that are
  /// already surfaced by BootErrorScreen). Uploads when Sentry is enabled;
  /// always logs locally.
  static void report(Object error, StackTrace? stackTrace, {String? context}) {
    debugPrint('[error-reporting] ${context ?? 'caught'}: $error\n${stackTrace ?? ''}');
    if (sentryEnabled) {
      unawaited(Sentry.captureException(error, stackTrace: stackTrace, withScope: (scope) {
        if (context != null) scope.setTag('halo_context', context);
      }));
    }
  }

  /// Called once bootstrap() has services; from then on the first runtime
  /// error of the session also posts a dismissible StatusBar notice.
  static void attachStatusBar(StatusBarService statusBar) {
    _statusBar = statusBar;
  }

  static void _installLocalHooks() {
    // Framework errors (widget build/layout/paint). Sentry's own handler —
    // when enabled — is already in this chain; preserve it.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (previousOnError != null) {
        previousOnError(details);
      } else {
        FlutterError.presentError(details);
      }
      _notify(details.exception, details.stack);
    };

    // Replace Flutter's grey/red box with the compact branded tile; the
    // failed widget's slot shows the tile, the rest of the app keeps
    // working (#76 — see views/error_tile.dart).
    ErrorWidget.builder = (details) => HaLoErrorTile(details: details);
  }

  /// Queue the once-per-session StatusBar notice (if the bar is attached).
  /// Deferred to a microtask: this is called from inside error handlers,
  /// which for widget errors means mid build/layout — and showNotice()'s
  /// notifyListeners() would then trip "markNeedsBuild() called during
  /// build" and throw from within the error handler itself. The throttle
  /// flag is set synchronously so concurrent errors can't double-post.
  static void _notify(Object error, StackTrace? stackTrace) {
    final statusBar = _statusBar;
    if (statusBar == null || _noticeShown) return;
    _noticeShown = true;
    final details = '$error\n\n${stackTrace ?? ''}';
    scheduleMicrotask(() {
      statusBar.showNotice(
        key: 'error-reporting:first-error',
        icon: 'error_outline',
        title: 'Something went wrong',
        text: sentryEnabled
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

  /// Test seam: forget the attached status bar and notice throttle.
  @visibleForTesting
  static void resetForTesting() {
    _statusBar = null;
    _noticeShown = false;
  }
}

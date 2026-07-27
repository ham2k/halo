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

import 'package:flutter/foundation.dart' show kIsWeb;
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
      // Dropped before anything sees it: no console dump, no upload, no notice.
      if (isKnownWebFocusTraversalNoise(details)) {
        if (!_focusTraversalNoiseLogged) {
          _focusTraversalNoiseLogged = true;
          debugPrint(
            '[error-reporting] ignoring the Flutter web focus-traversal null on '
            'view-focus change (ham2k/app-halo-dist#271); later ones are silent',
          );
        }
        return;
      }
      // Console-only, unlike the focus-traversal noise above: a RenderFlex
      // overflow is a real layout bug worth seeing locally (and Flutter's
      // debug-mode paint already marks the offending widget on-screen with
      // its own yellow/black stripes), but it's cosmetic and debug-only —
      // never worth a user-facing notice or an external report. Skips
      // previousOnError entirely, unlike an ordinary error below — that's
      // the chain a real backend's capture hooks into.
      if (isKnownRenderFlexOverflowNoise(details)) {
        debugPrint('[error-reporting] RenderFlex overflow (debug-only layout warning, not reported): '
            '${details.exception}');
        return;
      }
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

  static bool _focusTraversalNoiseLogged = false;

  /// Pretend we are on web, for the tests — `kIsWeb` is a compile-time false in
  /// the VM the tests run in, so without this seam the one predicate that only
  /// ever fires on web could not be exercised at all.
  @visibleForTesting
  static bool? debugTreatAsWeb;

  /// Whether [details] is Flutter's own focus-traversal crash on web
  /// (ham2k/app-halo-dist#271), which this app drops on the floor.
  ///
  /// `ReadingOrderTraversalPolicy._pickNext` force-unwraps a directionality that
  /// legitimately comes back null when a transiently-defunct node is pulled into
  /// the sort, and `View.didChangeViewFocus` sorts EVERY traversable node in the
  /// view scope rather than just the active scope — so on web, where that fires
  /// on every browser focus change, the unsound `!` throws out of an observer.
  /// The framework catches it and the app carries on; the only thing it produces
  /// is a "Something went wrong" notice about a framework bug, on a screen the
  /// operator was only clicking into, that they can do nothing about.
  ///
  /// Narrow deliberately — three conditions, all of which must hold:
  ///
  ///  * **Web.** `handleViewFocusChanged` only reaches this path on the
  ///    multi-view embedder, so on every other platform this is dead code.
  ///  * **The framework's own literal context** for that dispatch
  ///    (`widgets/binding.dart`'s `'while dispatching notifications for
  ///    WidgetsBindingObserver.didChangeViewFocus'`), so no error raised
  ///    anywhere else is affected.
  ///  * **A null-check failure**, which is the specific unsound `!` in #271 and
  ///    not, say, a range error some future observer throws in the same place.
  ///
  /// The STACK is deliberately not matched: it names `focus_traversal.dart` in a
  /// debug build and is minified in a release one, so requiring it would make
  /// this work only where the noise matters least.
  ///
  /// This cannot hide a bug of ours. No observer in this app implements
  /// `didChangeViewFocus` — only Flutter's own `View` does — so nothing of ours
  /// can throw inside that dispatch. Delete this the day Flutter's `!` is fixed;
  /// #271 tracks the upstream side.
  @visibleForTesting
  static bool isKnownWebFocusTraversalNoise(FlutterErrorDetails details) {
    if (!(debugTreatAsWeb ?? kIsWeb)) return false;
    if (!(details.context?.toString() ?? '').contains('WidgetsBindingObserver.didChangeViewFocus')) {
      return false;
    }
    final error = details.exception;
    if (error is TypeError) return true;
    // Belt and braces for the web runtime's own null-check type, whose identity
    // has moved between Dart versions; the message has not.
    final text = error.toString();
    return text.contains('Unexpected null value') || text.contains('Null check operator used on a null value');
  }

  /// Whether [details] is Flutter's own "RenderFlex overflowed by N pixels"
  /// layout warning — a debug-only assertion (release builds clip silently
  /// and never throw this at all), thrown whenever a Row/Column's children
  /// don't fit, however minor the overflow. Real layout bugs worth fixing,
  /// but not worth a "Something went wrong" notice aimed at an operator who
  /// can't do anything about it, or an external report for something that
  /// literally cannot happen in the release build users run.
  @visibleForTesting
  static bool isKnownRenderFlexOverflowNoise(FlutterErrorDetails details) {
    final error = details.exception;
    return error is FlutterError && error.toString().contains('A RenderFlex overflowed by');
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
    _focusTraversalNoiseLogged = false;
    debugTreatAsWeb = null;
  }
}

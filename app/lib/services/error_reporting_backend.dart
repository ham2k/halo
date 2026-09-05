// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension point for a distribution-specific crash-reporting backend (e.g.
// a proprietary build wired to Sentry) — same shape as MetricsService. The
// OSS app ships with a no-op implementation; ErrorReportingService.run()
// accepts an override.

import 'dart:async';

abstract class ErrorReportingBackend {
  /// Attempts to run [startBody] inside this backend's own error-capturing
  /// zone/init. Returns true once [startBody] is guaranteed to have run (or
  /// is running) under the backend's ownership; false if the backend's own
  /// setup failed *before* ever calling [startBody] — the caller then falls
  /// back to running it directly.
  Future<bool> run(FutureOr<void> Function() startBody);

  /// Uploads an explicitly-caught error (ErrorReportingService.report()).
  void captureException(Object error, StackTrace? stackTrace, {String? context});

  /// Updates the backend's user-identifying context. Both null clears it.
  void updateUserContext({String? callsign, String? accountId});

  /// Records a breadcrumb (ErrorReportingService.breadcrumb()) — session-wide
  /// state a backend can attach to whatever it captures next, including a
  /// native crash this app's own Dart error hooks never see (crashpad
  /// captures those independently of everything above).
  void addBreadcrumb(String message, {String? category});

  /// Uploads a diagnostic report the OPERATOR deliberately asked for — a
  /// benchmark run, a device profile — with [title] naming the kind of report
  /// and [body] carrying its detail.
  ///
  /// Not [captureException] with a synthetic error: nothing here went wrong,
  /// and dressing a result as a failure would put it in the same issue stream
  /// as real crashes, where it would be triaged as one. A backend that groups
  /// or routes by kind needs to be able to tell them apart, which is why this
  /// is its own entry point rather than a flag on an existing one.
  ///
  /// Never called on this app's own initiative: an operator ran a command and
  /// is waiting to be told what it found.
  void captureDiagnostic({required String title, required String body});
}

class NoopErrorReportingBackend implements ErrorReportingBackend {
  const NoopErrorReportingBackend();

  @override
  Future<bool> run(FutureOr<void> Function() startBody) async => false;

  @override
  void captureException(Object error, StackTrace? stackTrace, {String? context}) {}

  @override
  void updateUserContext({String? callsign, String? accountId}) {}

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void captureDiagnostic({required String title, required String body}) {}
}

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
}

class NoopErrorReportingBackend implements ErrorReportingBackend {
  const NoopErrorReportingBackend();

  @override
  Future<bool> run(FutureOr<void> Function() startBody) async => false;

  @override
  void captureException(Object error, StackTrace? stackTrace, {String? context}) {}

  @override
  void updateUserContext({String? callsign, String? accountId}) {}
}

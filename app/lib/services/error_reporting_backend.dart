// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension point for a distribution-specific crash-reporting backend (e.g.
// a proprietary build wired to Sentry) — same shape as MetricsService. The
// OSS app ships with a no-op implementation; ErrorReportingService.run()
// accepts an override.

import 'dart:async';
import 'dart:typed_data';

/// A file sent along with a diagnostic — DEVLOGCAT's traffic log, which is
/// far past what a report body carries.
typedef DiagnosticAttachment = ({String filename, Uint8List bytes});

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

  /// Names the radio the app is driving, so every later event says what was
  /// on the other end of the cable. Null clears it — nothing is connected.
  ///
  /// [radio] is an [EquipmentVariant] key from our own catalogue
  /// (`ic705-serial`), which is why this needs no consent: it is bounded by
  /// what we ship and identifies nobody. No config value belongs here — see
  /// docs/design/telemetry.md § Radios.
  void updateEquipmentContext({String? radio});

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
  /// Two kinds of caller, and only one of them has an operator waiting: a
  /// command the operator ran (a benchmark, a device profile, DEVLOGCAT
  /// stopped by hand), and reports sent on the app's own initiative — the
  /// first-success report a working radio sends, and a DEVLOGCAT recording
  /// sent at the launch after its restart. Those are gated on
  /// `consentAppData` at their call sites, since they carry the radio's
  /// configuration — docs/design/telemetry.md § Radios owns that
  /// distinction. A backend must not assume anyone is looking at the result.
  void captureDiagnostic({required String title, required String body, DiagnosticAttachment? attachment});
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
  void updateEquipmentContext({String? radio}) {}

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void captureDiagnostic({required String title, required String body, DiagnosticAttachment? attachment}) {}
}

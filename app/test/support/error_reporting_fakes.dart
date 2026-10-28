// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Test doubles for error reporting. The hooks ErrorReportingService.run()
// installs are global (ErrorWidget.builder, FlutterError.onError,
// PlatformDispatcher.onError), and the test binding verifies the first two
// are back to their originals at the END of each test body — before
// tearDowns run — so `withErrorHooks` restores them inline via try/finally
// rather than addTearDown.

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'package:ham2k_logger/services/error_policy.dart';
import 'package:ham2k_logger/services/error_reporting_backend.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';

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
  final String? databasePath;
  RecordedUserContext(this.callsign, this.accountId, this.databasePath);
}

class RecordedBreadcrumb {
  final String message;
  final String? category;
  RecordedBreadcrumb(this.message, this.category);
}

/// A test double standing in for a real backend (Sentry, in app_dist) —
/// records what ErrorReportingService sends it, without touching any SDK.
class FakeErrorReportingBackend implements ErrorReportingBackend {
  final exceptions = <RecordedException>[];
  final userContextCalls = <RecordedUserContext>[];
  final breadcrumbs = <RecordedBreadcrumb>[];
  final diagnostics = <(String, String)>[];

  /// Parallel to [diagnostics]: what each one carried alongside, if anything.
  final diagnosticAttachments = <DiagnosticAttachment?>[];

  /// Every value the equipment tag has been set to, nulls included — the
  /// nulls are what say a disconnect cleared it, and a test that only kept
  /// the names could not tell a cleared tag from one never set.
  final equipmentContextCalls = <String?>[];

  /// Simulates the backend's own init failing before it ever calls
  /// startBody (e.g. a real Sentry init throwing) — the caller must still
  /// run the app via its own fallback.
  final bool failsToRun;

  /// Simulates addBreadcrumb throwing synchronously (a real SDK call
  /// erroring) — ErrorReportingService.breadcrumb() must swallow it, since
  /// call sites run it right before a dispose()'s own teardown.
  final bool breadcrumbThrows;

  /// Simulates the diagnostic upload throwing synchronously. The operator is
  /// waiting on a result when this runs, so a backend that cannot send must
  /// not take the result down with it.
  final bool diagnosticThrows;

  /// Feeds every captured error the policy notifies on into the generic
  /// notice, as the real backend's `beforeSend` does — the only path by which
  /// a `report()`ed error ever reaches that notice.
  final bool feedsNotice;

  FakeErrorReportingBackend({this.failsToRun = false, this.breadcrumbThrows = false, this.diagnosticThrows = false, this.feedsNotice = false});

  @override
  Future<bool> run(FutureOr<void> Function() startBody) async {
    if (failsToRun) return false;
    await startBody();
    return true;
  }

  @override
  void captureException(Object error, StackTrace? stackTrace, {String? context}) {
    exceptions.add(RecordedException(error, stackTrace, context));
    if (feedsNotice && ErrorPolicy.decide(error).disposition.notifies) ErrorReportingService.notify(error, stackTrace);
  }

  @override
  void captureDiagnostic({required String title, required String body, DiagnosticAttachment? attachment}) {
    if (diagnosticThrows) throw StateError('diagnostic upload failed');
    diagnostics.add((title, body));
    diagnosticAttachments.add(attachment);
  }

  @override
  void updateUserContext({String? callsign, String? accountId, String? databasePath}) {
    userContextCalls.add(RecordedUserContext(callsign, accountId, databasePath));
  }

  @override
  void updateEquipmentContext({String? radio}) {
    equipmentContextCalls.add(radio);
  }

  @override
  void addBreadcrumb(String message, {String? category}) {
    if (breadcrumbThrows) throw StateError('backend addBreadcrumb failed');
    breadcrumbs.add(RecordedBreadcrumb(message, category));
  }
}

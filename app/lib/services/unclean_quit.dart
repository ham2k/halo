// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The mark a quit leaves behind while its database close is in progress, and
// the report the NEXT boot makes if it finds one still set.
//
// Nothing else survives the moment: the engine tears the app down as soon as
// the exit hook returns, so a report() about a close that failed or timed out
// has no time to reach the backend and no screen left to appear on. A pref
// does survive — so the close writes one before it starts and clears it when
// it finishes, and whoever boots next reports what that flag means, which is
// that writes the operator had already made were still queued when the app
// went (see main.dart's closeDatabaseOnExit).

import 'package:shared_preferences/shared_preferences.dart';

import 'error_reporting_service.dart';

const uncleanQuitKey = 'db:uncleanQuit';

/// A previous run's database close did not finish.
///
/// Its own type rather than a StateError with a recognizable message: this is
/// the payload of an ErrorPolicy rule, and a rule that matches on message text
/// eventually claims a real error that merely reads the same.
class UncleanDatabaseQuit implements Exception {
  const UncleanDatabaseQuit();

  @override
  String toString() => 'UncleanDatabaseQuit: the previous quit did not finish closing the database';
}

/// Awaited, unlike most pref writes: an unawaited one is a mark that may not
/// exist by the time the process it is marking goes down.
Future<void> markDatabaseClosing(SharedPreferences prefs) => prefs.setBool(uncleanQuitKey, true);

Future<void> markDatabaseClosed(SharedPreferences prefs) => prefs.remove(uncleanQuitKey);

/// Reports — and clears — a mark left by the previous run.
///
/// Cleared even if the report goes nowhere: one unclean quit must not report
/// on every boot forever after.
Future<void> reportUncleanQuit(SharedPreferences prefs) async {
  if (!(prefs.getBool(uncleanQuitKey) ?? false)) return;
  await markDatabaseClosed(prefs);
  ErrorReportingService.report(const UncleanDatabaseQuit(), StackTrace.current, context: 'db:unclean-quit');
}

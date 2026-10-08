// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How far the last quit got, and the report the NEXT boot makes out of it.
//
// Nothing else survives the moment: the engine tears the app down as soon as
// the exit hook returns, so a report() about a step that failed or timed out
// has no time to reach the backend and no screen left to appear on. A pref
// does survive — so the teardown writes its stage as it advances, clears it
// when it finishes, and whoever boots next reports the stage it finds, which
// names the step that was still running (see services/app_exit.dart).
//
// What this CANNOT see is a quit that died after the teardown finished, in
// the engine's own VM shutdown: the mark is already cleared by then, and
// nothing in Dart runs afterwards to write another. Telling that apart from
// an ordinary exit needs the crash backend's own record of the last run,
// which sentry_flutter 9 exposes nowhere in Dart. Closing that window needs a
// clean-exit marker written by the runner after the message loop, across a
// store neither side owns.

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:shared_preferences/shared_preferences.dart';

import 'error_reporting_service.dart';

/// The mark older builds left: a bare bool meaning "the database close
/// started and did not finish".
///
/// Still READ, never written: an operator upgrading into this build may have
/// one sitting in their preferences from the quit before, and a boot that
/// ignored it would drop the very report the flag exists for.
const uncleanQuitKey = 'db:uncleanQuit';

/// The stage the last quit reached, as a [QuitStage] name.
const quitStageKey = 'quit:stage';

/// The steps a quit passes through, in the order `tearDownForExit` runs them.
///
/// Each is written BEFORE the step it names, so the stage found on the next
/// boot is the step that was in progress — not the last one that finished.
enum QuitStage {
  /// Saying goodbye to the radios. Its serial close is synchronous FFI that
  /// no timeout can reach, so this is the step that can wedge rather than
  /// fail — and a wedged quit leaves a process that never dies
  /// (services/app_exit.dart). Without a mark in front of it, a quit that
  /// dies here leaves no trace of any kind: there is no process left to
  /// report it, and on Windows its window makes every later launch a silent
  /// no-op instead.
  cat,

  /// Waiting for whatever the database is already doing to finish.
  databaseDrain,

  /// drift's own close.
  databaseClose,
}

/// A previous run's teardown did not finish.
///
/// Its own type rather than a StateError with a recognizable message: this is
/// the payload of an ErrorPolicy rule, and a rule that matches on message text
/// eventually claims a real error that merely reads the same. The stage rides
/// in the message because the step is what makes these different bugs rather
/// than one — a wedged radio and a lost database write deserve to be read
/// apart at a glance, and to group apart in the backend.
class UncleanDatabaseQuit implements Exception {
  const UncleanDatabaseQuit([this.stage = QuitStage.databaseClose, this.unknownStageName]);

  final QuitStage stage;

  /// The stage name a newer build wrote, when this one does not know it.
  ///
  /// Carried rather than dropped: relabelling an unknown step as the close
  /// would group a downgraded install's quit with real drift-close failures
  /// and inflate that bucket, which is the same defect one level up from the
  /// one the stage exists to fix.
  final String? unknownStageName;

  @override
  String toString() => switch (unknownStageName) {
    final name? =>
      'UncleanDatabaseQuit: the previous quit did not finish a step '
          'this build does not know ($name)',
    _ => _stageMessage,
  };

  String get _stageMessage => switch (stage) {
    QuitStage.cat => 'UncleanDatabaseQuit: the previous quit did not finish saying goodbye to the radios',
    QuitStage.databaseDrain => 'UncleanDatabaseQuit: the previous quit did not finish draining the database',
    QuitStage.databaseClose => 'UncleanDatabaseQuit: the previous quit did not finish closing the database',
  };
}

/// Records that [stage] is about to run, answering whether the write landed.
///
/// Awaited, unlike most pref writes: an unawaited one is a mark that may not
/// exist by the time the process it is marking goes down.
///
/// The bool is the whole point of the return. A refused write does NOT throw
/// on the platform this mark exists for — shared_preferences_windows catches
/// its own IO and answers false — so a caller that only guards against a
/// throw is a caller that never learns the mark is missing, which is exactly
/// the silence the mark exists to end.
Future<bool> markQuitStage(SharedPreferences prefs, QuitStage stage) => prefs.setString(quitStageKey, stage.name);

/// Forgets the stage — for the teardown that finished, and for the boot that
/// has finished reporting one that did not.
///
/// Clears the legacy bool too, so an upgraded install reports its last
/// unclean quit once rather than on every boot from here on.
Future<bool> clearQuitStage(SharedPreferences prefs) async {
  final stage = await prefs.remove(quitStageKey);
  final legacy = await prefs.remove(uncleanQuitKey);
  // Same reason [markQuitStage] answers: a remove refused rather than thrown
  // leaves a mark behind, and the next boot reports an unclean quit that
  // never happened — inflating the very per-step rate this exists to measure.
  return stage && legacy;
}

/// The stage the previous run left behind, or null if it left none.
///
/// An older build's bare bool reads as [QuitStage.databaseClose]: that is
/// exactly what it meant, since it was written in front of the close and
/// nowhere else.
QuitStage? lastQuitStage(SharedPreferences prefs) {
  final name = prefs.getString(quitStageKey);
  if (name != null) {
    for (final stage in QuitStage.values) {
      if (stage.name == name) return stage;
    }
    // A stage name this build does not know, from one that did. Saying
    // nothing would drop a real unclean quit; the close is the step every
    // build has always had, and is the honest fallback — with the name
    // itself carried separately, so nothing claims to know which step it was.
    return QuitStage.databaseClose;
  }
  if (prefs.getBool(uncleanQuitKey) ?? false) return QuitStage.databaseClose;
  return null;
}

/// The stage name the previous run wrote, when no [QuitStage] answers to it.
String? unknownQuitStageName(SharedPreferences prefs) {
  final name = prefs.getString(quitStageKey);
  if (name == null) return null;
  return QuitStage.values.any((stage) => stage.name == name) ? null : name;
}

/// When this device last uploaded an unclean quit at [stageName], as real
/// epoch millis.
String quitReportedAtKey(String stageName) => 'quit:reportedAt:$stageName';

/// How long one upload per stage speaks for this device.
///
/// A quit that dies at the same step dies there on every quit, so without a
/// window each launch uploads the same fact again and one wedged radio
/// outweighs every other install in the backend. A day keeps "this device
/// still hits it" without the per-launch count.
const quitReportWindow = Duration(days: 1);

/// Reports — and clears — the mark left by the previous run.
///
/// Cleared even if the report goes nowhere: one unclean quit must not report
/// on every boot forever after. Uploaded at most once per stage per
/// [quitReportWindow]; a repeat inside it is console-only.
Future<void> reportUncleanQuit(SharedPreferences prefs) async {
  final stage = lastQuitStage(prefs);
  if (stage == null) return;
  final unknownName = unknownQuitStageName(prefs);
  final stageName = unknownName != null ? 'unknown' : stage.name;
  final error = UncleanDatabaseQuit(stage, unknownName);

  // Reported BEFORE the clear, and the clear in a finally. The mark is
  // consumed either way — one unclean quit must not report on every boot
  // forever after — but a clear that throws in front of the report would
  // take the only record of that quit with it, which is the failure this
  // whole file exists to prevent.
  try {
    // The REAL clock, as for every stamp that persists: a travelled one would
    // outlive the travel (time.md).
    final now = realNowMillis();
    final reportedAt = prefs.getInt(quitReportedAtKey(stageName));
    final age = reportedAt == null ? null : now - reportedAt;
    // A stamp in the future cannot be judged (the device clock was wrong when
    // it was written), so it reports rather than muting for as long as it stands.
    if (age != null && !age.isNegative && age < quitReportWindow.inMilliseconds) {
      debugPrint('[unclean-quit] $error (already reported in the last ${quitReportWindow.inHours}h)');
    } else {
      ErrorReportingService.report(error, StackTrace.current, context: 'db:unclean-quit:$stageName');
      await prefs.setInt(quitReportedAtKey(stageName), now);
    }
  } finally {
    try {
      await clearQuitStage(prefs);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'db:unclean-quit-clear');
    }
  }
}

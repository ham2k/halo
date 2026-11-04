// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operation lifecycle as the logging panel presents it
// (docs/design/data-model.md §The Log Data): the spec it is handed, built
// from the app's services. The panel decides nothing about the lifecycle; it
// passes this on.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';

import '../../services/halo_services.dart';
import '../../services/operation_lifecycle_commands.dart';
import '../../tools/operation_stats.dart';
import 'operation_export_panel.dart';

/// What the logging panel is handed to show and drive [operation]'s lifecycle,
/// or null while the `cycle` experiment is off.
///
/// Null is the WHOLE gate: with no spec the panel is the one it was before the
/// lifecycle existed, entry row and all. Gating the controls individually
/// would leave the row locked with nothing on screen to reopen it — the status
/// itself is written either way, so an operation can be mid-lifecycle when the
/// experiment goes on.
///
/// Built on every panel build rather than cached: the operation arrives from a
/// stream, so a status the sweep or an export just wrote is already in
/// [operation] by the time this runs, and a cached spec would leave the row
/// live over a log that has been sent.
///
/// [loggedAtMillis] is when the panel last logged a contact. Counted as
/// activity beside the record's own: an operator entering an old log is at
/// the radio, and contacts dated hours ago would otherwise read as hours of
/// quiet and lock the row between entries. Held by the panel rather than
/// written per contact, which would move the operation's revision and cost
/// each contact a full rescore.
OperationLifecycleSpec? operationLifecycleSpec(BuildContext context, HaLoServices services, Operation operation, {int? loggedAtMillis}) {
  if (!services.settings.experimentEnabled('cycle') /* stored key, see experiments.yaml */ ) return null;
  final t = context.t.operation.lifecycle;

  // The SAME rule the sweep measures its own silence with, at a much
  // shorter window — and it must be the same one: RESTART writes
  // `statusAtMillis` and never `startAtMillisMax`, so measuring from the
  // last contact alone would leave a reopened operation reading as paused,
  // with the operator locked out of the log they just reopened.
  final lastActivity = operationLastActivityMillis(operation, seenMillis: loggedAtMillis);
  // Finish dates itself from the same silence the panel shows.
  Future<void> move(String kind) => services.moveOperationLifecycle(operation.uuid, kind, lastActivityMillis: lastActivity);

  return OperationLifecycleSpec(
    status: operation.status,
    lastActivityMillis: lastActivity,
    statusAtMillis: operation.statusAtMillis,
    // A log sent or archived is still, to the operator at the panel, a
    // completed one: what was done with it afterwards is the exports' story.
    statusLabel: (status) => status == OperationStatus.paused ? t.paused : t.completed,
    lastExportNote: switch (operation.processedAtMillis) {
      final at? => _lastExportNote(context, t, at),
      null => null,
    },
    dateRange: _operationDateRange(operation),
    startLabel: t.start,
    pauseLabel: t.pause,
    continueLabel: t.continueOperation,
    restartLabel: t.restart,
    endLabel: t.end,
    exportsLabel: t.exports,
    onStart: () => unawaited(move('start')),
    onPause: () => unawaited(move('pause')),
    onReopen: () => unawaited(move('restart')),
    onEnd: () => unawaited(move('stop')),
    // The same sheet the operation header's Exports button opens. Offered
    // here because it is the only thing left to do with a finished log,
    // and the slot it sits in is otherwise spent on a wipe button for an
    // entry row that is not there.
    onExports: () => unawaited(showOperationExportPanel(context, services: services, operation: operation)),
  );
}

/// "Last export / 1 hour ago" for a send within the day, "Last export on /
/// July 21, 2026" past it: hours stop meaning much once the answer is
/// "yesterday or before", and the date is what an operator checks a portal
/// against.
///
/// The date per-locale: a month name is locale text, and so is its order with
/// the day.
String Function(int nowMillis) _lastExportNote(BuildContext context, Translations$operation$lifecycle$en t, int at) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final dates = _exportDates.putIfAbsent(locale, () => DateFormat.yMMMMd(locale));
  return (now) {
    final age = Duration(milliseconds: now - at);
    if (age >= const Duration(days: 1)) return t.lastExportOn(date: dates.format(DateTime.fromMillisecondsSinceEpoch(at)));
    final time = age.inMinutes < 1
        ? t.justNow
        : age.inHours < 1
        ? t.minutesAgo(count: age.inMinutes)
        : t.hoursAgo(count: age.inHours);
    return t.lastExportAgo(time: time);
  };
}

/// The last export's date format, per locale: the note is built on every
/// panel build, and a format parses its pattern when made.
final _exportDates = <String, DateFormat>{};

/// The operation's span, on the read's second line. Null for an operation
/// with no contacts — there is no span to state, and "today – today" would be
/// an invented fact.
String? _operationDateRange(Operation operation) {
  final from = operation.startAtMillisMin;
  final to = operation.startAtMillisMax;
  if (from == null || to == null) return null;
  // ISO and in UTC, the way the Logs view states an operation's dates.
  final start = _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(from, isUtc: true));
  final end = _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(to, isUtc: true));
  return start == end ? start : '$start – $end';
}

/// How the operation's span is stated on the read's second line.
final _dateFormat = DateFormat('yyyy-MM-dd');

/// The logging panel's stats lines, told where the operation is in its
/// lifecycle.
///
/// The live "since last" figure goes with the entry row: both say the
/// operator is at the radio, and one outlasting the other is the panel
/// contradicting itself. The clock is read once, so the parts cannot answer
/// either side of the quiet boundary.
OperationStatsLines operationStatsLinesFor(BuildContext context, OperationLifecycleSpec? lifecycle) => (qsos, {closed = false}) {
  final now = nowMillis();
  return operationStatsLines(context, qsos, sinceLast: lifecycle?.readingAt(now) == null, pausedAtMillis: lifecycle?.pausedSinceAt(now), closed: closed);
};

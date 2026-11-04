// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart' show formatNumber;

import 'package:halo_i18n/halo_i18n.dart';

/// The operation's default statistics: count + duration, "since
/// last" (only while the last QSO is recent), and last-10 / last-100 Q/h
/// rates. Mirrors app-polo's OpInfo. Shared by LoggingControls' compact info
/// row and the wide-layout Information Panel so both stay in sync.
///
/// [sinceLast] off drops the one figure here that moves on its own, "since
/// last". A picture of the operation is looked at long after it was made,
/// and a log the operator has paused or finished has no "1m since last" to
/// report: counting up beside "Operation Completed" says they are still at
/// the radio. Every other line describes what the log already holds, so with
/// this off nothing in the result changes again and the caller can stop
/// ticking too.
///
/// The span runs from the operation's start — its start marker, when that
/// comes before the first contact — to the last contact, or to [pausedAtMillis]
/// for a paused log: the operator who logged one contact four minutes after
/// starting and then paused has been at it four minutes, not "0s".
///
/// [closed] is for a log that is paused or finished, and returns up to two
/// lines, in minutes: the count over the whole span — run to its last `stop`
/// marker when that comes after the last contact — and the overall rate over
/// the time spent active, with the paused and active split when the log was
/// ever paused. The second is left out when there was no active time, or its
/// rate rounds to nothing. The rate goes per day below [_perDayBelowPerHour], where
/// "2 QSO/h" undersells a log worked a few contacts a day across a week — and
/// per day is counted over the days the span covers, never projected from the
/// hourly rate, which would credit a three-contact hour with 72 a day.
/// See [QsoLogSummary.pausedMillis] for what counts as paused.
///
/// Read from the log's [QsoLogSummary], never by walking [qsos]: the info
/// area redraws this every second, and the log the stream hands it carries a
/// summary kept current contact by contact. Any other list is folded once
/// per call.
List<String> operationStatsLines(BuildContext context, List<Qso> qsos, {bool sinceLast = true, int? pausedAtMillis, bool closed = false}) {
  final t = context.t.loggingControls.info;
  final summary = qsos is QsoLog ? qsos.summary : QsoLogSummary.of(qsos);
  if (summary.contacts == 0) {
    // Once the operation has been started, the empty log is no longer the
    // thing worth saying — the operator knows there are no contacts, they are
    // sitting in front of the row. What they cannot see is how long they have
    // been at it, so the count runs from the start marker instead.
    final startedAt = summary.startedAtMillis;
    if (startedAt == null) return [t.noQsos];
    final count = t.qsoCountOther(count: 0);
    if (pausedAtMillis != null) {
      return [
        t.qsosInTime(
          count: count,
          time: fmtTimeBetween(startedAt, pausedAtMillis, seconds: !closed),
        ),
      ];
    }
    // Elapsed only while the log is live, for the same reason "since last"
    // stops: a paused or finished operation with nothing in it has no clock
    // still running, and a figure that counts up beside a state that says
    // otherwise is the panel contradicting itself.
    if (!sinceLast) return [count];
    return [t.qsosInTime(count: count, time: fmtTimeBetween(startedAt, nowMillis()))];
  }

  final count = summary.contacts;
  final firstMs = summary.firstContactAtMillis;
  final lastMs = summary.lastContactAtMillis;
  final nowMs = nowMillis();
  final startedAt = summary.startedAtMillis;
  final fromMs = (startedAt != null && (firstMs == null || startedAt < firstMs)) ? startedAt : firstMs;
  final endMs = pausedAtMillis ?? (closed ? summary.finishedAtMillis : null);
  final toMs = (endMs != null && (lastMs == null || endMs > lastMs)) ? endMs : lastMs;

  final countText = count == 1 ? t.qsoCountOne : t.qsoCountOther(count: count);
  if (closed && fromMs != null && toMs != null) {
    return _closedSummary(t, count: countText, contacts: count, pausedMs: summary.pausedMillis, fromMs: fromMs, toMs: toMs);
  }
  final line1 = <String>[
    (fromMs != null && toMs != null) ? t.qsosInTime(count: countText, time: fmtTimeBetween(fromMs, toMs)) : countText,
    // "since last" only while the last QSO is recent (<6h) — otherwise a
    // long-idle log would show a distractingly large figure.
    if (sinceLast && lastMs != null && nowMs - lastMs < 6 * 60 * 60 * 1000) t.sinceLast(time: fmtTimeBetween(lastMs, nowMs)),
  ];

  final line2 = <String>[];
  // Rates: QSOs-per-hour over the last 10 / 100, needing >10 / >100 contacts
  // (same thresholds and window as app-polo).
  final recent = summary.recentContactMillis;
  int? rateOverLast(int n) {
    if (recent.length < n) return null;
    final start = recent[recent.length - n];
    final end = recent.last;
    if (end <= start) return null;
    return (n / ((end - start) / 1000 / 60) * 60).round();
  }

  if (count > 10) {
    final rate = rateOverLast(10);
    if (rate != null) line2.add(t.ratePer10(rate: rate));
  }
  if (count > 100) {
    final rate = rateOverLast(100);
    if (rate != null) line2.add(t.ratePer100(rate: rate));
  }

  return [line1.join(' • '), if (line2.isNotEmpty) line2.join(' • ')];
}

/// Below this many contacts an hour, the closed summary's rate is given per day.
const _perDayBelowPerHour = 5;

/// [pausedMs] is the log's own ([QsoLogSummary.pausedMillis]).
List<String> _closedSummary(
  Translations$loggingControls$info$en t, {
  required String count,
  required int contacts,
  required int pausedMs,
  required int fromMs,
  required int toMs,
}) {
  final activeMs = toMs - fromMs - pausedMs;
  final days = ((toMs - fromMs) / Duration.millisecondsPerDay).ceil();
  final String? rate = activeMs <= 0
      ? null
      : switch (contacts / (activeMs / Duration.millisecondsPerHour)) {
          final perHour when perHour >= _perDayBelowPerHour => t.ratePerHour(rate: formatNumber(perHour.round())),
          _ => switch (contacts / (days < 1 ? 1 : days)) {
            final perDay when perDay >= 1 => t.ratePerDay(rate: formatNumber(perDay.round())),
            final perDay when perDay >= 0.1 => t.ratePerDay(rate: formatNumber((perDay * 10).round() / 10)),
            // Rounded to nothing, a rate says less than the count beside it.
            _ => null,
          },
        };
  return [
    t.qsosInTime(count: count, time: fmtTimeBetween(fromMs, toMs, seconds: false)),
    if (rate != null)
      pausedMs > 0
          ? t.rateWithSplit(rate: rate, paused: fmtTimeBetween(0, pausedMs, seconds: false), active: fmtTimeBetween(0, activeMs, seconds: false))
          : rate,
  ];
}

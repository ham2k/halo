// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';

/// The operation's default statistics: count + duration, "since
/// last" (only while the last QSO is recent), and last-10 / last-100 Q/h
/// rates. Mirrors app-polo's OpInfo. Shared by LoggingControls' compact info
/// row and the wide-layout Information Panel so both stay in sync.
///
/// [sinceLast] off leaves the now-relative "since last" out — for a picture
/// of the operation, which is looked at long after it was made.
List<String> operationStatsLines(BuildContext context, List<Qso> qsos, {bool sinceLast = true}) {
  final t = context.t.loggingControls.info;
  final contacts = [
    for (final q in qsos)
      if (q.isRealContact) q,
  ];
  if (contacts.isEmpty) return [t.noQsos];

  final count = contacts.length;
  final firstMs = contacts.first.startAtMillis;
  final lastMs = contacts.last.startAtMillis;
  final nowMs = nowMillis();

  final countText = count == 1 ? t.qsoCountOne : t.qsoCountOther(count: count);
  final line1 = <String>[
    (firstMs != null && lastMs != null) ? t.qsosInTime(count: countText, time: fmtTimeBetween(firstMs, lastMs)) : countText,
    // "since last" only while the last QSO is recent (<6h) — otherwise a
    // long-idle log would show a distractingly large figure.
    if (sinceLast && lastMs != null && nowMs - lastMs < 6 * 60 * 60 * 1000) t.sinceLast(time: fmtTimeBetween(lastMs, nowMs)),
  ];

  final line2 = <String>[];
  // Rates: QSOs-per-hour over the last 10 / 100, needing >10 / >100 contacts
  // (same thresholds and window as app-polo).
  int? rateOverLast(int n) {
    final start = contacts[count - n].startAtMillis;
    final end = contacts[count - 1].startAtMillis;
    if (start == null || end == null || end <= start) return null;
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

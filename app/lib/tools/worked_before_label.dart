// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';

/// The compact call-info's worked-before pill, app-polo's way: the most
/// telling recent bucket first, then whatever is left — "3 today + 48 QSOs",
/// "2 in last 7 days + 1 QSO", or just "48 QSOs". Null for no prior contact.
///
/// [startTimes] are the prior contacts' start times (epoch millis), any
/// order. Days are the device's local days as the app clock tells them, so
/// developer time travel moves the buckets with everything else.
String? workedBeforeLabel(BuildContext context, List<int> startTimes) {
  final buckets = workedBeforeBuckets(startTimes, now: nowLocal());
  if (buckets == null) return null;
  final t = context.t.callInfo.history;
  final parts = <String>[
    if (buckets.recentCount > 0)
      switch (buckets.recent) {
        WorkedBeforeRecent.last7days => t.last7days(n: formatNumber(buckets.recentCount)),
        WorkedBeforeRecent.today => t.today(n: formatNumber(buckets.recentCount)),
        // A count with no bucket is a broken invariant; an empty part would
        // render as a leading " + " instead of saying so.
        WorkedBeforeRecent.none => throw StateError('worked-before count without a bucket'),
      },
    if (buckets.olderCount > 0) t.qsos(count: buckets.olderCount, n: formatNumber(buckets.olderCount)),
  ];
  return parts.join(' + ');
}

enum WorkedBeforeRecent { none, today, last7days }

/// The split [workedBeforeLabel] renders: a recent bucket (when one is worth
/// naming) and the count of everything else.
typedef WorkedBeforeBuckets = ({WorkedBeforeRecent recent, int recentCount, int olderCount});

/// app-polo's bucketing (`CallInfo.jsx`), verbatim in its choices. "Last 7
/// days" is the six days BEFORE today, and is named whenever it holds more
/// than today does or more than yesterday does — so any contact earlier this
/// week that is not yesterday's names the week; otherwise today is named
/// when it has any. Whatever the named bucket does not cover is "QSOs",
/// today's included when the week is named. [now] is local time — the day
/// boundaries are the operator's midnights.
///
/// app-polo also has a "yesterday" bucket, unreachable there: it needs the
/// week to hold no more than today (zero, for today to be empty) while
/// yesterday, inside that week, holds some. Not ported.
WorkedBeforeBuckets? workedBeforeBuckets(List<int> startTimes, {required DateTime now}) {
  if (startTimes.isEmpty) return null;
  final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  final yesterday = DateTime(now.year, now.month, now.day - 1).millisecondsSinceEpoch;
  final lastWeek = DateTime(now.year, now.month, now.day - 6).millisecondsSinceEpoch;
  final countToday = startTimes.where((t) => t >= today).length;
  final countYesterday = startTimes.where((t) => t >= yesterday).length - countToday;
  final countLastWeek = startTimes.where((t) => t >= lastWeek).length - countToday;

  var recent = WorkedBeforeRecent.none;
  var recentCount = 0;
  if (countLastWeek > countToday || countLastWeek > countYesterday) {
    recent = WorkedBeforeRecent.last7days;
    recentCount = countLastWeek;
  } else if (countToday > 0) {
    recent = WorkedBeforeRecent.today;
    recentCount = countToday;
  }
  return (recent: recent, recentCount: recentCount, olderCount: startTimes.length - recentCount);
}

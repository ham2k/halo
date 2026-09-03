// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The worked-before pill's bucketing is app-polo's, choice for choice
// (`CallInfo.jsx`): which recent window gets named, and that the remainder
// is everything the named window did not cover. A port that named "today"
// whenever today had any, or folded today into "last 7 days", would read
// plausibly and differ from what PoLo's users know.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/tools/worked_before_label.dart';

void main() {
  // A local-time "now" mid-afternoon, so hour arithmetic never crosses midnight.
  final now = DateTime(2026, 9, 2, 15, 0);
  int at(DateTime t) => t.millisecondsSinceEpoch;
  final today = at(now.subtract(const Duration(hours: 2)));
  final yesterday = at(now.subtract(const Duration(days: 1)));
  final thisWeek = at(now.subtract(const Duration(days: 5)));
  final longAgo = at(now.subtract(const Duration(days: 400)));

  test('nothing for no prior contact', () {
    expect(workedBeforeBuckets(const [], now: now), isNull);
  });

  test('only old contacts: no recent bucket, all of them as QSOs', () {
    expect(
      workedBeforeBuckets([longAgo, longAgo, longAgo], now: now),
      (recent: WorkedBeforeRecent.none, recentCount: 0, olderCount: 3),
    );
  });

  test('today alone is named, and taken out of the remainder', () {
    expect(
      workedBeforeBuckets([today, today, longAgo], now: now),
      (recent: WorkedBeforeRecent.today, recentCount: 2, olderCount: 1),
    );
  });

  test('today is still named when the only other recent contact was yesterday, and fewer', () {
    expect(
      workedBeforeBuckets([today, today, yesterday], now: now),
      (recent: WorkedBeforeRecent.today, recentCount: 2, olderCount: 1),
    );
  });

  test('the week is named for anything before today, and does not include today', () {
    // Yesterday alone: the week, not "yesterday" (unreachable in PoLo too).
    expect(
      workedBeforeBuckets([yesterday, longAgo], now: now),
      (recent: WorkedBeforeRecent.last7days, recentCount: 1, olderCount: 1),
    );
    // One today and one earlier this week: the week names the earlier one
    // only, and today's contact falls into the remainder.
    expect(
      workedBeforeBuckets([today, thisWeek, longAgo], now: now),
      (recent: WorkedBeforeRecent.last7days, recentCount: 1, olderCount: 2),
    );
    expect(
      workedBeforeBuckets([yesterday, thisWeek], now: now),
      (recent: WorkedBeforeRecent.last7days, recentCount: 2, olderCount: 0),
    );
  });

  test('the week is six days back from today\'s midnight, not 7x24h', () {
    final sixDaysAgoMorning = at(DateTime(2026, 8, 27, 1, 0));
    final sevenDaysAgo = at(DateTime(2026, 8, 26, 23, 0));
    expect(
      workedBeforeBuckets([sixDaysAgoMorning, sevenDaysAgo], now: now),
      (recent: WorkedBeforeRecent.last7days, recentCount: 1, olderCount: 1),
    );
  });
}

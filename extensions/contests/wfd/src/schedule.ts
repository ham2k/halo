// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When Winter Field Day runs, and how close it is.
//
// COMPUTED, not published in a data file the way `stateparks`' events are: the
// rule states the date — "the last full weekend of January, 1900 UTC Saturday
// to 1859 UTC Sunday" — so it is right for every year, including ones nobody
// has updated a file for.
//
// Duplicated with `fd`, which computes the fourth full weekend of June the same
// way. See `scorer.ts` on why these two extensions repeat each other.

const DAY = 24 * 60 * 60 * 1000

/// Every Saturday in [month] (0-based) that starts a FULL weekend — one whose
/// Sunday also falls in the same month. Only ever excludes a Saturday landing
/// on the last day of the month.
function fullWeekendSaturdays(year: number, month: number): number[] {
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate()
  const saturdays: number[] = []
  for (let day = 1; day <= lastDay; day += 1) {
    const at = Date.UTC(year, month, day)
    if (new Date(at).getUTCDay() === 6 && day + 1 <= lastDay) saturdays.push(at)
  }
  return saturdays
}

/// The start of Winter Field Day in [year] — 1900 UTC on the LAST full
/// weekend's Saturday. January's 31st is a Saturday often enough that the
/// full-weekend rule really bites here, unlike June's.
export function startOfWinterFieldDay(year: number): number {
  const saturdays = fullWeekendSaturdays(year, 0)
  return saturdays[saturdays.length - 1] + 19 * 60 * 60 * 1000
}

/// The end — 1859 UTC on the Sunday, a minute short of 24 hours.
export function endOfWinterFieldDay(year: number): number {
  return startOfWinterFieldDay(year) + DAY - 60 * 1000
}

/// The YEAR whose running is the next one — the single source for "which
/// running is this?".
///
/// Both the ranking and the suggestion's label read this. They used to decide
/// it separately, against different ends of the event, and disagreed for the 27
/// hours in between: the picker offered next year's running while ranking it as
/// if it were on the air.
///
/// Rolls once the running is a fortnight past, so a list ordered by it reads as
/// "what is coming" rather than "how long ago" — `stateparks`' rule, minus its
/// data file.
export function nextRunningYear(nowMillis: number): number {
  const year = new Date(nowMillis).getUTCFullYear()
  return endOfWinterFieldDay(year) < nowMillis - 14 * DAY ? year + 1 : year
}

/// Days until the next running, negative while it is on.
export function daysUntilWinterFieldDay(nowMillis: number): number {
  return Math.ceil((startOfWinterFieldDay(nextRunningYear(nowMillis)) - nowMillis) / DAY)
}

/// Whether it is running right now.
export function isWinterFieldDayOn(nowMillis: number): boolean {
  const year = new Date(nowMillis).getUTCFullYear()
  return nowMillis >= startOfWinterFieldDay(year) && nowMillis <= endOfWinterFieldDay(year)
}

/// Relevance for a running [days] away, given whether it is on RIGHT NOW.
///
/// `days <= 0` alone is not "on now": `daysUntil` stays negative for the
/// fortnight after the event, so without the `isOn` term the contest sat at
/// maximum relevance for two weeks after it finished.
///
/// This only ORDERS the suggestion list, and only against other suggestions
/// with no location — the picker sorts everything with a distance ahead of
/// everything without one, so a park 40km away still comes first.
export function relevanceFor(nowMillis: number): number {
  if (isWinterFieldDayOn(nowMillis)) return 1
  const days = daysUntilWinterFieldDay(nowMillis)
  // Past-but-recent still ranks high — an operator logging on the Monday is
  // still logging this running — just below one actually on the air.
  if (days <= 0) return 0.9
  return 1 / (1 + days / 60)
}

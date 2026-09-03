// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When the two Region 1 Field Days run, and how close each is.
//
// COMPUTED, not published in a data file: the DARC states both dates as a
// RULE — CW on "the first (full) weekend in June, Saturday 15.00 UTC to
// Sunday 14.59 UTC", SSB on "the first (full) weekend in September, Saturday
// 13.00 UTC to Sunday 12.59 UTC" — so it is right for every year, including
// ones nobody has updated a file for. Same approach as `fd` and `wfd`, which
// compute their ARRL weekends the same way.

const DAY = 24 * 60 * 60 * 1000

/// The two runnings, each its own event: separate weekends, separate logs,
/// separate submissions.
export type R1FdMode = 'CW' | 'SSB'
export const MODES: R1FdMode[] = ['CW', 'SSB']

/// June for CW, September for SSB (0-based), and the Saturday start hour UTC.
const MONTH_FOR: Record<R1FdMode, number> = { CW: 5, SSB: 8 }
const START_HOUR_FOR: Record<R1FdMode, number> = { CW: 15, SSB: 13 }

/// The Saturday starting the first FULL weekend of [month] — one whose Sunday
/// also falls in the same month. Only ever skips a Saturday landing on the last
/// day of the month.
function firstFullWeekendSaturday(year: number, month: number): number {
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate()
  for (let day = 1; day <= lastDay; day += 1) {
    const at = Date.UTC(year, month, day)
    if (new Date(at).getUTCDay() === 6 && day + 1 <= lastDay) return at
  }
  // Unreachable — a month always contains a full weekend — but a typed return
  // beats a non-null assertion.
  return Date.UTC(year, month, 1)
}

/// The start of a running — Saturday 1500 UTC (CW) or 1300 UTC (SSB).
export function startOfFieldDay(year: number, mode: R1FdMode): number {
  return firstFullWeekendSaturday(year, MONTH_FOR[mode]) + START_HOUR_FOR[mode] * 60 * 60 * 1000
}

/// The end — 24 hours later, as an EXCLUSIVE bound. The DARC writes the close
/// as "14.59"/"12.59 UTC"; contest rules state the same boundary either as the
/// last minute of the hour or as the top of the next one, and a QSO at
/// 12:59:59 counts under both. So the two readings differ in wording only, and
/// the exclusive instant is the hour the running opened on.
export function endOfFieldDay(year: number, mode: R1FdMode): number {
  return startOfFieldDay(year, mode) + DAY
}

/// The YEAR whose running of [mode] is the next one — the single source for
/// "which running is this?". Both the ranking and the suggestion's ref read
/// this; deciding it separately disagrees for the hours in between.
///
/// Rolls once the running is a fortnight past, so a list ordered by it reads
/// as "what is coming" rather than "how long ago" — `fd`'s rule.
export function nextRunningYear(nowMillis: number, mode: R1FdMode): number {
  const year = new Date(nowMillis).getUTCFullYear()
  return endOfFieldDay(year, mode) < nowMillis - 14 * DAY ? year + 1 : year
}

/// Days until the next running of [mode], negative while it is on.
export function daysUntilFieldDay(nowMillis: number, mode: R1FdMode): number {
  return Math.ceil((startOfFieldDay(nextRunningYear(nowMillis, mode), mode) - nowMillis) / DAY)
}

/// Whether [mode]'s running is on the air right now.
export function isFieldDayOn(nowMillis: number, mode: R1FdMode): boolean {
  const year = new Date(nowMillis).getUTCFullYear()
  return nowMillis >= startOfFieldDay(year, mode) && nowMillis <= endOfFieldDay(year, mode)
}

/// Relevance for [mode]'s next running — `fd`'s curve. `days <= 0` alone is
/// not "on now": `daysUntil` stays negative for the fortnight after the event,
/// so without the `isOn` term the contest sits at maximum relevance for two
/// weeks after it finished. This only ORDERS the suggestion list, and only
/// against other suggestions with no location.
export function relevanceFor(nowMillis: number, mode: R1FdMode): number {
  if (isFieldDayOn(nowMillis, mode)) return 1
  const days = daysUntilFieldDay(nowMillis, mode)
  if (days <= 0) return 0.9
  return 1 / (1 + days / 60)
}

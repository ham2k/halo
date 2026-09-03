// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When the Nasjonal Field Day runs, and how close it is.
//
// COMPUTED, not published in a data file: NRRL states the date as a RULE — the
// first complete weekend in September, "lørdag ... kl. 1300 UTC til søndag ...
// kl. 1300 UTC" — so it is right for every year, including ones nobody has
// updated a file for. Same approach as `fd`, `wfd` and `r1-fd`.
//
// Deliberately its own copy rather than an import from `r1-fd`, even though
// that extension computes the SAME window for its SSB running — same weekend,
// same 1300 UTC opening, same 24 hours. Each contest extension stands alone
// and movable, which is the rule `fd` and `wfd` set for exactly this
// situation; sharing a schedule between two contests couples them for as long
// as their rulebooks happen to agree.

const DAY = 24 * 60 * 60 * 1000

/// The Saturday starting the first COMPLETE weekend of September — one whose
/// Sunday also falls in the month. Only ever skips a Saturday landing on the
/// last day of the month.
function firstFullWeekendSaturday(year: number): number {
  const lastDay = new Date(Date.UTC(year, 9, 0)).getUTCDate()
  for (let day = 1; day <= lastDay; day += 1) {
    const at = Date.UTC(year, 8, day)
    if (new Date(at).getUTCDay() === 6 && day + 1 <= lastDay) return at
  }
  // Unreachable — a month always contains a full weekend — but a typed return
  // beats a non-null assertion.
  return Date.UTC(year, 8, 1)
}

/// The start of NFD in [year] — 1300 UTC on that Saturday.
export function startOfFieldDay(year: number): number {
  return firstFullWeekendSaturday(year) + 13 * 60 * 60 * 1000
}

/// The end — a clean 24 hours later, Sunday 1300 UTC.
export function endOfFieldDay(year: number): number {
  return startOfFieldDay(year) + DAY
}

/// The YEAR whose running is the next one — the single source for "which
/// running is this?". Both the ranking and the suggestion's ref read it;
/// deciding it separately makes the picker offer one running while ranking
/// another.
///
/// Rolls once the running is a fortnight past, so a list ordered by it reads
/// as "what is coming" rather than "how long ago" — `fd`'s rule.
export function nextRunningYear(nowMillis: number): number {
  const year = new Date(nowMillis).getUTCFullYear()
  return endOfFieldDay(year) < nowMillis - 14 * DAY ? year + 1 : year
}

/// Days until the next running, negative while it is on.
export function daysUntilFieldDay(nowMillis: number): number {
  return Math.ceil((startOfFieldDay(nextRunningYear(nowMillis)) - nowMillis) / DAY)
}

/// Whether it is running right now.
export function isFieldDayOn(nowMillis: number): boolean {
  const year = new Date(nowMillis).getUTCFullYear()
  return nowMillis >= startOfFieldDay(year) && nowMillis <= endOfFieldDay(year)
}

/// Relevance for the next running — `fd`'s curve. `days <= 0` alone is not "on
/// now": `daysUntil` stays negative for the fortnight after the event, so
/// without the `isOn` term the contest sits at maximum relevance for two weeks
/// after it finished. This only ORDERS the suggestion list, and only against
/// other suggestions with no location.
export function relevanceFor(nowMillis: number): number {
  if (isFieldDayOn(nowMillis)) return 1
  const days = daysUntilFieldDay(nowMillis)
  if (days <= 0) return 0.9
  return 1 / (1 + days / 60)
}

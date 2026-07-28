// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ARRL Field Day's date rule, which is pure arithmetic over a calendar and was
// shipped with no test at all — `saturdays[3]` becoming `[2]`, or a 0-based
// month slipping by one, moves the contest a week or a month with nothing to
// catch it.
//
// Colocated `.test.ts`, run by `npm test`, the way `stateparks/src/events.test.ts`
// covers its own `daysUntil`.

import assert from "node:assert/strict"
import { test } from "node:test"

import {
  daysUntilFieldDay,
  endOfFieldDay,
  isFieldDayOn,
  nextRunningYear,
  relevanceFor,
  startOfFieldDay,
} from "./schedule.ts"

/// The runnings as published, so the rule is checked against reality
/// rather than against itself.
const PUBLISHED: [number, number, number][] = [
  [2024, 6, 22], [2025, 6, 28], [2026, 6, 27], [2027, 6, 26], [2028, 6, 24],
]

test("lands on the published weekend for each year", () => {
  for (const [year, month, day] of PUBLISHED) {
    const start = new Date(startOfFieldDay(year))
    assert.equal(start.getUTCFullYear(), year)
    assert.equal(start.getUTCMonth() + 1, month, `${year} month`)
    assert.equal(start.getUTCDate(), day, `${year} day`)
    // Always a Saturday, and its Sunday is in the same month — the "full
    // weekend" rule, which is what excludes a month-ending Saturday.
    assert.equal(start.getUTCDay(), 6, `${year} is a Saturday`)
    assert.equal(new Date(start.getTime() + 86400000).getUTCMonth() + 1, month)
  }
})

test("the event ends after it starts, within the same weekend", () => {
  for (const [year] of PUBLISHED) {
    const span = endOfFieldDay(year) - startOfFieldDay(year)
    assert.ok(span > 0 && span <= 30 * 60 * 60 * 1000, `${year} span`)
  }
})

test("nextRunningYear rolls a fortnight after the event, not before", () => {
  const [year, month, day] = PUBLISHED[1]
  const during = startOfFieldDay(year) + 60 * 60 * 1000
  assert.equal(nextRunningYear(during), year, "on the air")
  assert.equal(nextRunningYear(endOfFieldDay(year) + 13 * 86400000), year, "13 days after")
  assert.equal(nextRunningYear(endOfFieldDay(year) + 15 * 86400000), year + 1, "15 days after")
  void month; void day
})

test("the label and the ranking never disagree about which running it is", () => {
  // They used to be decided separately, against different ends of the event,
  // and disagreed for the ~27 hours in between: the picker offered next year's
  // running while ranking it as if it were on the air.
  for (const [year] of PUBLISHED) {
    for (let hour = -40; hour <= 40; hour += 1) {
      const at = endOfFieldDay(year) + 14 * 86400000 + hour * 60 * 60 * 1000
      const labelled = nextRunningYear(at)
      const ranked = at + daysUntilFieldDay(at) * 86400000
      assert.equal(new Date(ranked).getUTCFullYear(), labelled,
        `${year} @ ${hour}h: label says ${labelled}`)
    }
  }
})

test("relevance peaks while it is on and decays afterwards", () => {
  const [year] = PUBLISHED[1]
  const during = startOfFieldDay(year) + 60 * 60 * 1000
  assert.equal(isFieldDayOn(during), true)
  assert.equal(relevanceFor(during), 1)
  // The fortnight after is high but NOT the on-air score — without the isOn
  // term it sat at a full 1 for two weeks after the contest finished.
  const after = endOfFieldDay(year) + 3 * 86400000
  assert.ok(relevanceFor(after) < 1 && relevanceFor(after) > 0.5)
  // Half a year out ranks well below either.
  const distant = startOfFieldDay(year) - 180 * 86400000
  assert.ok(relevanceFor(distant) < 0.5)
})

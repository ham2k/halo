// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The trap here is "first FULL weekend": when a month opens on a Sunday the
// first Saturday is the 6th/7th, not a weekend spanning into the month —
// getting it wrong moves the whole event a week early, and no other check in
// the extension would notice.

import { strict as assert } from "node:assert"
import { describe, it } from "node:test"

import {
  daysUntilFieldDay,
  endOfFieldDay,
  isFieldDayOn,
  nextRunningYear,
  relevanceFor,
  startOfFieldDay,
} from "./schedule.ts"

describe('startOfFieldDay', () => {
  it('CW runs the first full June weekend at 1500 UTC', () => {
    assert.equal(startOfFieldDay(2026, 'CW'), Date.UTC(2026, 5, 6, 15, 0))
    // 2025: June 1 is a Sunday, so the first FULL weekend starts on the 7th.
    assert.equal(startOfFieldDay(2025, 'CW'), Date.UTC(2025, 5, 7, 15, 0))
  })

  it('SSB runs the first full September weekend at 1300 UTC', () => {
    assert.equal(startOfFieldDay(2026, 'SSB'), Date.UTC(2026, 8, 5, 13, 0))
    assert.equal(startOfFieldDay(2025, 'SSB'), Date.UTC(2025, 8, 6, 13, 0))
  })

  it('runs for 24 hours', () => {
    assert.equal(
      endOfFieldDay(2026, 'SSB') - startOfFieldDay(2026, 'SSB'),
      24 * 60 * 60 * 1000,
    )
  })
})

describe('nextRunningYear', () => {
  it('rolls to next year only a fortnight after the running', () => {
    const justAfter = endOfFieldDay(2026, 'SSB') + 24 * 60 * 60 * 1000
    assert.equal(nextRunningYear(justAfter, 'SSB'), 2026)
    const aMonthAfter = endOfFieldDay(2026, 'SSB') + 30 * 24 * 60 * 60 * 1000
    assert.equal(nextRunningYear(aMonthAfter, 'SSB'), 2027)
  })
})

describe('relevance', () => {
  it('peaks while on the air, stays high just after, and decays with distance', () => {
    const during = startOfFieldDay(2026, 'SSB') + 60 * 60 * 1000
    assert.equal(isFieldDayOn(during, 'SSB'), true)
    assert.equal(relevanceFor(during, 'SSB'), 1)

    const dayAfter = endOfFieldDay(2026, 'SSB') + 24 * 60 * 60 * 1000
    assert.equal(relevanceFor(dayAfter, 'SSB'), 0.9)

    // In early September the SSB running outranks a CW running nine months out.
    assert.ok(relevanceFor(during, 'SSB') > relevanceFor(during, 'CW'))
    assert.ok(daysUntilFieldDay(during, 'CW') > 200)
  })
})

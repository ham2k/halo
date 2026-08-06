// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How old a reading is allowed to look. Weather is the one thing on a
// dashboard an operator acts on physically — packing up ahead of a storm —
// and a failing fetch leaves the last reading on screen indefinitely, so
// the age is load-bearing rather than decoration.

import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { readingAge } from './freshness.ts'

describe('readingAge', () => {
  const at = 1_700_000_000_000
  const after = (minutes: number) => readingAge(at, at + minutes * 60000)

  it('counts minutes while minutes still mean something', () => {
    assert.equal(after(0), 'just now')
    assert.equal(after(1), '1 minute ago')
    assert.equal(after(42), '42 minutes ago')
  })

  it('stops counting minutes past the hour', () => {
    // "97 minutes ago" is true and unreadable at a glance, and an hour is
    // where a weather reading starts being worth doubting.
    assert.equal(after(60), 'over an hour ago')
    assert.equal(after(97), 'over an hour ago')
    assert.equal(after(200), 'over 3 hours ago')
    assert.equal(after(60 * 30), 'over a day ago')
  })
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The clock panel's offset parsing. This is the whole of its logic, and it
// exists at all because the runtime has no time zones: `Intl` is undefined
// in QuickJS, and `toLocaleString(…, {timeZone})` silently ignores the zone
// rather than throwing. So the operator writes offsets, and these are the
// shapes they will write.

import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { parseClocks, parseOffset } from './offsets.ts'

describe('parseOffset', () => {
  it('reads whole hours, signed or not', () => {
    assert.equal(parseOffset('+9'), 540)
    assert.equal(parseOffset('9'), 540)
    assert.equal(parseOffset('-7'), -420)
    assert.equal(parseOffset('0'), 0)
  })

  it('reads the half- and quarter-hour zones people actually use', () => {
    // India and Newfoundland are the reason a whole-hours-only parser would
    // be wrong for a real operator rather than merely incomplete.
    assert.equal(parseOffset('+5:30'), 330)
    assert.equal(parseOffset('+5.5'), 330)
    assert.equal(parseOffset('-3:30'), -210)
    assert.equal(parseOffset('+5:45'), 345)
  })

  it('refuses what it cannot read rather than clocking at UTC', () => {
    // Every one of these would otherwise become 0 and show UTC under a
    // label claiming Tokyo — a clock that is confidently wrong.
    // `+25:30` is the trap: the colon branch needs its own ceiling, or it
    // parses happily and clocks a pane a day and a bit into the future.
    for (const bad of ['', '  ', 'EST', '+9h', 'nine', '+99', '+5:99', '--5', '+25:30', '-18:00']) {
      assert.equal(parseOffset(bad), null, `${bad} is not an offset`)
    }
  })
})

describe('parseClocks', () => {
  it('reads one Label = offset per line', () => {
    const { clocks, bad } = parseClocks('Tokyo = +9\nMumbai = +5:30\n\n  London = 0  ')
    assert.deepEqual(clocks, [
      { label: 'Tokyo', offset: 540 },
      { label: 'Mumbai', offset: 330 },
      { label: 'London', offset: 0 },
    ])
    assert.deepEqual(bad, [])
  })

  it('reports a line it cannot read instead of dropping it', () => {
    // A clock the operator typed and then cannot find is worse than one
    // that says what is wrong with it — they have no other way to tell
    // whether the panel even saw the line.
    const { clocks, bad } = parseClocks('Tokyo = +9\nParis\nBerlin = CET')
    assert.deepEqual(clocks, [{ label: 'Tokyo', offset: 540 }])
    assert.deepEqual(bad, ['Paris', 'Berlin = CET'])
  })

  it('splits on the LAST equals, so a label may contain one', () => {
    const { clocks } = parseClocks('W1AW = net = -5')
    assert.deepEqual(clocks, [{ label: 'W1AW = net', offset: -300 }])
  })
})

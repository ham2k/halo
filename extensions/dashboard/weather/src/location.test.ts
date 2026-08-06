// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where the weather panel decides it is. Getting this wrong shows an
// operator confident conditions for somewhere they never asked about, which
// is why every unreadable input has to come back null rather than 0,0.

import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { parseLocation } from './location.ts'

describe('parseLocation', () => {
  it('reads a grid square', () => {
    const place = parseLocation('FN31pr')!
    assert.ok(Math.abs(place.latitude - 41.7) < 0.2, `lat was ${place.latitude}`)
    assert.ok(Math.abs(place.longitude + 72.7) < 0.2, `lon was ${place.longitude}`)
  })

  it('reads lat,lon with or without spaces', () => {
    assert.deepEqual(parseLocation('42.36,-71.06'), { latitude: 42.36, longitude: -71.06 })
    assert.deepEqual(parseLocation(' 42.36 , -71.06 '), { latitude: 42.36, longitude: -71.06 })
  })

  it('refuses coordinates off the globe', () => {
    // 0,0 is a real place in the Atlantic, so a parser that clamped or
    // defaulted would send the panel there rather than admitting the typo.
    assert.equal(parseLocation('91,0'), null)
    assert.equal(parseLocation('0,181'), null)
  })

  it('returns null for anything it cannot read', () => {
    for (const bad of ['', '   ', 'Boston', 'FN31pr, MA', '42.36', 'ZZ99zz']) {
      assert.equal(parseLocation(bad), null, `${bad} is not a location`)
    }
  })
})

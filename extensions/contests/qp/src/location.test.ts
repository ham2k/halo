// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What an exchange means. Every case here is one an operator can type on the
// air, and several are ones polo gets wrong — the DC/Maryland swap especially,
// which is invisible in a score and wrong in 42 of the 49 parties.

import { test } from "node:test"
import assert from "node:assert/strict"

import {
  allInParty,
  entityPrefixOf,
  nameForLocation,
  normalizeLocation,
  parseLocations,
  splitLocations,
} from "./location.ts"
import { partyFor, type QsoParty } from "./parties.ts"

function party(key: string): QsoParty {
  const found = partyFor(key)
  assert.ok(found, `no party ${key}`)
  return found
}

const codes = (party: QsoParty, text: string, opts?: Parameters<typeof parseLocations>[2]) =>
  parseLocations(party, text, opts).map((location) => location.code)

test('a county line is two values, however it was typed', () => {
  assert.deepEqual(splitLocations('ALB/ERI'), ['ALB', 'ERI'])
  assert.deepEqual(splitLocations('alb,eri'), ['ALB', 'ERI'])
  assert.deepEqual(splitLocations('ALB'), ['ALB'])
  assert.deepEqual(splitLocations(''), [])
})

test('7QP\'s shorthand: a second county inherits the first one\'s state', () => {
  // The sponsors let an operator type `ORDES/JEF` for `ORDES/ORJEF`, and that
  // is the only place a short code after a long one is unambiguous.
  assert.deepEqual(splitLocations('ORDES/JEF'), ['ORDES', 'ORJEF'])
  // Two short codes are two short codes — no state to inherit.
  assert.deepEqual(splitLocations('ALB/ERI'), ['ALB', 'ERI'])
})

test('DC and Maryland MERGE where the party says so — polo swaps them', () => {
  // polo maps DC→MD and MD→DC, so the two end up as different codes and a
  // party that counts them as one awards two multipliers.
  const ny = party('NY') // dcCountsAsMaryland: true
  assert.equal(normalizeLocation(ny, 'DC'), 'MD')
  assert.equal(normalizeLocation(ny, 'MD'), 'MD')
  // A party that names DC explicitly keeps it apart — and Maryland's own
  // party is one of them.
  const md = party('MD') // dcCountsAsMaryland: false
  assert.equal(normalizeLocation(md, 'DC'), 'DC')
  assert.equal(normalizeLocation(md, 'MD'), 'MD')
})

test('an unknown location falls back to where the callsign says they are', () => {
  const ny = party('NY')
  // A DX station's exchange is their entity, and no party asks them to type it.
  assert.equal(normalizeLocation(ny, 'ZZZ', { entityPrefix: 'DL' }), 'DX')
  // Alaska and Hawaii are states, unless the party says they are DX (NEQP
  // carries the option and sets it FALSE, so no shipped party turns it on).
  assert.equal(normalizeLocation(ny, 'KL7', { entityPrefix: 'KL7' }), 'AK')
  assert.equal(normalizeLocation(ny, 'AK'), 'AK')
  // A callsign we could not place at all resolves to nothing rather than to
  // `DX`: an unlookup-able call is a QSO we cannot score, not a DX contact.
  assert.equal(normalizeLocation(ny, 'ZZZ'), '')
})

test('Alaska is KL in the country file, and a state in every shipped party', () => {
  // polo tests for `KL7`, which the bundled country file never answers — so an
  // Alaskan station whose exchange could not be read scored as DX rather than
  // as the state multiplier they are. `naqp` documents the same correction.
  const ny = party('NY')
  assert.equal(normalizeLocation(ny, 'ZZZ', { entityPrefix: 'KL' }), 'AK')
  assert.equal(normalizeLocation(ny, 'ZZZ', { entityPrefix: 'KH6' }), 'HI')
  // What polo would have written stays readable, for a synced or imported log.
  assert.equal(normalizeLocation(ny, 'ZZZ', { entityPrefix: 'KL7' }), 'AK')
})

test('a long code that is nobody\'s county is read as its state', () => {
  // `ORDES` typed into the New York party is Oregon, not a New York county.
  assert.equal(normalizeLocation(party('NY'), 'ORDES'), 'OR')
})

test('in-party is decided by the county list, not by a setting', () => {
  const ny = party('NY')
  assert.equal(allInParty(parseLocations(ny, 'ALB')), true)
  assert.equal(allInParty(parseLocations(ny, 'NJ')), false)
  // A county line half in and half out is not fully in the party — the
  // in-state rules that turn on this are about where WE are, and half a
  // county line outside means half the log is out-of-state work.
  assert.equal(allInParty(parseLocations(ny, 'ALB/NJ')), false)
  // Nothing resolved is NOT in the party: the safe reading for the rules that
  // gate on it.
  assert.equal(allInParty(parseLocations(ny, '')), false)
})

test('NEQP: inside the party a county multiplies as its STATE', () => {
  // The one rule two options spell ("countiesAreMultForInState",
  // "countiesCountForInState"): the county is still what is sent and logged,
  // and only what it multiplies changes.
  const neqp = party('NEQP')
  const inState = { weAreInParty: true, theyAreInParty: true }
  const [location] = parseLocations(neqp, 'MAWOR', { standing: inState })
  assert.equal(location.code, 'MAWOR')
  assert.equal(location.multCode, 'MA')
  // An out-of-party station working the same county multiplies by the county.
  const [outside] = parseLocations(neqp, 'MAWOR', { standing: { weAreInParty: false, theyAreInParty: true } })
  assert.equal(outside.multCode, 'MAWOR')
})

test('each DX entity is its own multiplier where a party says so', () => {
  const il = party('IL') // dxEntityIsMultiplier
  const [dx] = parseLocations(il, 'DX', { entityPrefix: 'DL' })
  assert.equal(dx.multCode, 'DX:DL')
  // Where every DX station together is one multiplier, they share a key.
  const ny = party('NY')
  const [single] = parseLocations(ny, 'DX', { entityPrefix: 'DL' })
  assert.equal(single.multCode, 'DX')
})

test('the same location twice is one location', () => {
  // An operator correcting a county line can end up with `ALB/ALB`, which is
  // one county, not a doubled score.
  assert.deepEqual(codes(party('NY'), 'ALB/ALB'), ['ALB'])
})

test('names are what an operator hears, not codes', () => {
  const ny = party('NY')
  assert.equal(nameForLocation(ny, 'ALB'), 'Albany')
  assert.equal(nameForLocation(ny, 'NJ'), 'New Jersey')
  assert.equal(nameForLocation(ny, 'MD'), 'Maryland & DC')
  assert.equal(nameForLocation(party('MD'), 'DC'), 'District of Columbia')
  assert.equal(nameForLocation(party('IL'), 'DX', 'DL'), 'DX: DL')
})

test('a neighbouring party\'s county scores as its STATE', () => {
  // 7QP's entrants work the parties next door, so `CASCL` is a value they will
  // be sent — and California is what it is worth to them, since a county
  // outside the party multiplies nothing of its own. The code has to resolve,
  // or the exchange would read as a typo.
  const [neighbour] = parseLocations(party('7QP'), 'CASCL')
  assert.equal(neighbour.code, 'CA')
  assert.equal(neighbour.multCode, 'CA')
  assert.equal(neighbour.inParty, false)
})

test('the entity comes from the lookup when the operator has not typed one', () => {
  assert.equal(entityPrefixOf({ their: { entityPrefix: 'K' } }), 'K')
  assert.equal(entityPrefixOf({ their: { guess: { entityPrefix: 'VE' } } }), 'VE')
  assert.equal(entityPrefixOf({}), '')
})

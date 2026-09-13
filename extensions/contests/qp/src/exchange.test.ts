// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The exchange on its way in (what the entry row offers) and on its way out
// (what the sponsor receives). The Cabrillo cases are the ones that matter
// most: a file is submitted once, months after the contest, and nobody reads it
// before it goes.

import { test } from "node:test"
import assert from "node:assert/strict"

import type { JSONValue } from "@ham2k/extension-sdk"

import {
  cabrilloCategories,
  cabrilloCall,
  claimableBand,
  cabrilloRowsFor,
  exchangeInheritPrefix,
  exchangeOptionsFor,
  exchangeTransforms,
  fallbackTheirLocation,
  ourLocationForQso,
  preferredCodesFor,
  resolvedExchanges,
  theirLocationForFile,
} from "./exchange.ts"
import { partyFor, type QsoParty } from "./parties.ts"

function party(key: string): QsoParty {
  const found = partyFor(key)
  assert.ok(found, `no party ${key}`)
  return found
}

function operation(location: string): Record<string, JSONValue> {
  return { uuid: 'op', stationCall: 'N0DEV', refs: [{ type: 'qp', ref: 'NY', location }] }
}

function qso(
  { call = 'K1ABC', location, ourLocation, entityPrefix = 'K', state, mode = 'CW', startAtMillis }: {
    call?: string
    location?: string
    /// A stamp an earlier build left on the ref. Present in the fixtures only
    /// to prove it is IGNORED.
    ourLocation?: string
    entityPrefix?: string
    state?: string
    mode?: string
    startAtMillis?: number
  } = {},
): Record<string, JSONValue> {
  return {
    their: { call, ...(entityPrefix ? { entityPrefix } : {}), ...(state ? { state } : {}) },
    band: '20m',
    mode,
    ...(startAtMillis !== undefined ? { startAtMillis } : {}),
    refs: [{ type: 'qp', ...(location !== undefined ? { location } : {}), ...(ourLocation ? { ourLocation } : {}) }],
  }
}

/// A log that changed county at 1000: the base operation's county before, [later]
/// from then on — the payload the host sends as `ExportRequest.segments`.
function segmentsTo(later: string, base = 'ALB') {
  return [
    { fromMillis: -1, operation: operation(base) },
    { fromMillis: 1000, operation: operation(later) },
  ]
}

test('a county line submits one row per pairing', () => {
  // Each pairing is what the checker matches against the other station's log,
  // so a line-to-line contact is four lines, not one.
  const rows = cabrilloRowsFor(party('NY'), qso({ location: 'ERI/CHA' }), operation('ALB/REN'), 'N0DEV')
  assert.equal(rows.length, 4)
  const pairs = rows.map((row) => [row[2].trim(), row[5].trim()])
  assert.deepEqual(pairs, [['ALB', 'ERI'], ['ALB', 'CHA'], ['REN', 'ERI'], ['REN', 'CHA']])
})

test('on a segmented log, the county WE were in is the segment\'s, not anything on the contact', () => {
  // A rover's county changes mid-log; the host hands the export the same
  // resolved segments the scorer folds, so a contact made after the break is
  // filed under the county the break established — whatever an earlier build
  // stamped onto it when it was saved.
  const before = qso({ location: 'ERI', startAtMillis: 500, ourLocation: 'REN' })
  const after = qso({ location: 'ERI', startAtMillis: 1500, ourLocation: 'ALB' })
  assert.equal(ourLocationForQso(before, operation('ALB'), segmentsTo('REN')), 'ALB')
  assert.equal(ourLocationForQso(after, operation('ALB'), segmentsTo('REN')), 'REN')
  const rows = cabrilloRowsFor(party('NY'), after, operation('ALB'), 'N0DEV', { segments: segmentsTo('REN') })
  assert.equal(rows[0][2].trim(), 'REN')
})

test('a county corrected in a segment reaches every contact of that stretch', () => {
  // The whole point of reading the segment rather than a stamp: six contacts
  // logged under a mistyped county and then corrected at the break are filed
  // under the correction, in the file as on the scoreboard. A stamp would have
  // kept the typo on all six.
  const stamped = qso({ location: 'ERI', startAtMillis: 1500, ourLocation: 'MORR' })
  assert.equal(ourLocationForQso(stamped, operation('MORR'), segmentsTo('WRRN', 'MORR')), 'WRRN')
})

test('without segments, the operation\'s county is true of the whole log', () => {
  // An operator who logs 30 contacts, notices the county is a typo and fixes it
  // in setup rescores the whole log — and the file has to follow rather than
  // submit the county that was typed by mistake.
  const stamped = qso({ location: 'ERI', ourLocation: 'ALB' })
  assert.equal(ourLocationForQso(stamped, operation('ALL')), 'ALL')
  assert.equal(ourLocationForQso(stamped, operation('ALL'), []), 'ALL')
  const rows = cabrilloRowsFor(party('NY'), stamped, operation('ALL'), 'N0DEV')
  assert.equal(rows[0][2].trim(), 'ALL')
})

test('a serial and a name are columns only for the parties that exchange them', () => {
  // Every column shifts when one is added, so a party that does not trade
  // serials must not get an empty one.
  const plain = cabrilloRowsFor(party('NY'), qso({ location: 'ERI' }), operation('ALB'), 'N0DEV')
  assert.equal(plain[0].length, 6)
  // California exchanges a serial: our call, RST, serial, county, then theirs.
  const ca = { uuid: 'op', stationCall: 'N0DEV', refs: [{ type: 'qp', ref: 'CA', location: 'ALAM' }] }
  const caQso = {
    their: { call: 'K1ABC', entityPrefix: 'K' },
    band: '20m',
    mode: 'CW',
    refs: [{ type: 'qp', location: 'BUTT', ourSerial: '12', theirSerial: '34' }],
  }
  const rows = cabrilloRowsFor(party('CA'), caQso, ca, 'N0DEV')
  assert.equal(rows[0].length, 8)
  assert.equal(rows[0][2].trim(), '12')
  assert.equal(rows[0][6].trim(), '34')
})

test('a contact with nobody in the party is left out of the file', () => {
  // Two out-of-party stations working each other is not a contest QSO — the
  // scorer awards it nothing, and a submitted file claiming it is an over-claim
  // a checker will strike.
  const outside = { uuid: 'op', stationCall: 'N0DEV', refs: [{ type: 'qp', ref: 'NY', location: 'NJ' }] }
  assert.deepEqual(cabrilloRowsFor(party('NY'), qso({ location: 'CT' }), outside, 'N0DEV'), [])
  // One end inside is a contest QSO, whichever end it is.
  assert.equal(cabrilloRowsFor(party('NY'), qso({ location: 'ERI' }), outside, 'N0DEV').length, 1)
  assert.equal(cabrilloRowsFor(party('NY'), qso({ location: 'CT' }), operation('ALB'), 'N0DEV').length, 1)
})

test('an exchange nobody copied is not invented for the file', () => {
  // The scorer refuses to score a contact whose exchange was never typed
  // (`missingExchange`), so writing the lookup's guessed state into the file
  // would claim a contact the scoreboard already declined. polo writes the
  // guess; the two sides have to agree, and the score is the honest one.
  assert.equal(fallbackTheirLocation(party('NY'), qso({ state: 'NJ' })), '')
  const rows = cabrilloRowsFor(party('NY'), qso({ state: 'NJ' }), operation('ALB'), 'N0DEV')
  assert.deepEqual(rows, [], 'a contact with nothing to claim is not claimed')

  // A DX station's exchange IS their entity — nobody asks them to send one, so
  // this is what they gave us, not a guess.
  assert.equal(fallbackTheirLocation(party('NY'), qso({ entityPrefix: 'DL' })), 'DX')
  // Where a party asks for the prefix instead of the word DX (15 of them do).
  assert.equal(fallbackTheirLocation(party('WA'), qso({ entityPrefix: 'DL' })), 'DL')
})

test('the file claims a contact only where the score does', () => {
  // Both sides ask the same question — is one END of this contact wholly
  // inside the party — so a row cannot appear for a contact worth zero. An
  // out-of-party entrant working a county line half outside the party is the
  // case the two readings disagree on.
  const outside = { uuid: 'op', stationCall: 'N0DEV', refs: [{ type: 'qp', ref: 'NY', location: 'CA' }] }
  assert.deepEqual(cabrilloRowsFor(party('NY'), qso({ location: 'ERI/NJ' }), outside, 'N0DEV'), [])
  // Wholly inside, and it counts.
  assert.equal(cabrilloRowsFor(party('NY'), qso({ location: 'ERI/CHA' }), outside, 'N0DEV').length, 2)
})

test('the file says what the scoreboard claimed for an Alaskan contact', () => {
  // The scorer credits an Alaskan station as the state `AK`; a file writing
  // `DX` for the same contact would not support the multiplier already
  // claimed — the divergence `location.ts` exists to prevent.
  assert.equal(fallbackTheirLocation(party('NY'), qso({ entityPrefix: 'KL' })), 'AK')
  assert.equal(fallbackTheirLocation(party('NY'), qso({ entityPrefix: 'KH6' })), 'HI')
})

test('Idaho strips a rover suffix from the callsign, and nobody else does', () => {
  // polo's NOTES lists `removeCountySuffixes` as unimplemented.
  assert.equal(cabrilloCall(party('ID'), 'K7ABC/ADA'), 'K7ABC')
  assert.equal(cabrilloCall(party('NY'), 'K2ABC/M'), 'K2ABC/M')
})

test('the entry row offers what the station being worked could possibly send', () => {
  const ny = party('NY')
  // A US station may send a county or a state…
  const us = exchangeOptionsFor(ny, qso({ entityPrefix: 'K' })).map((option) => option.code)
  assert.ok(us.includes('ALB'))
  assert.ok(us.includes('NJ'))
  // …a Canadian station in a US party can only send a province…
  const ve = exchangeOptionsFor(ny, qso({ entityPrefix: 'VE' })).map((option) => option.code)
  assert.deepEqual(ve.includes('ALB'), false)
  assert.ok(ve.includes('ON'))
  // …and a DX station sends their entity, which is not a list at all, so the
  // field accepts whatever the operator heard.
  assert.deepEqual(exchangeOptionsFor(ny, qso({ entityPrefix: 'DL' })), [])
  // A Canadian party is the mirror image.
  const acqp = party('ACQP')
  const acqpVe = exchangeOptionsFor(acqp, qso({ entityPrefix: 'VE' })).map((option) => option.code)
  assert.ok(acqpVe.some((code) => acqp.counties[code] !== undefined))
})

test('the county-line shorthand is declared, not rewritten', () => {
  // 7QP's operators may send `ORDES/JEF` for `ORDES/ORJEF`, which the scorer
  // and the Cabrillo already understand — so the field has to accept it too,
  // or it tints a perfectly good exchange invalid.
  //
  // Declared rather than rewritten, because no rewrite can tell the shorthand
  // from the same letters on the way to the full code: after `IDADA/`, `IDA` is
  // either Idaho county's shorthand or the first three characters of `IDIDA`,
  // and four real 7QP counties have exactly that shape.
  assert.equal(exchangeInheritPrefix(party('7QP')), 2)
  const counties = Object.keys(party('7QP').counties)
  for (const code of ['IDIDA', 'UTUTA', 'WAWAH', 'WAWAL']) {
    assert.ok(counties.includes(code), `${code} is a 7QP county whose shorthand collides`)
  }
  // A party whose codes are three letters has no shorthand at all…
  assert.equal(exchangeInheritPrefix(party('NY')), 0)
  // …and the only live rewrite left is the comma an operator may reach for.
  assert.deepEqual(exchangeTransforms(party('NY')), [{ pattern: ',', replacement: '/', flags: 'g' }])
  assert.deepEqual(exchangeTransforms(party('WI')), [])
})

test('DC is offered, because stations send it', () => {
  // `US_STATES` holds the fifty and not DC — whether DC is its own multiplier
  // is a per-party rule. Left out of the list as well, the field tints a
  // perfectly good exchange as unknown for the whole QSO while the scorer
  // accepts it.
  for (const key of ['NY', 'MD']) {
    const codes = exchangeOptionsFor(party(key), qso({ entityPrefix: 'K' })).map((option) => option.code)
    assert.ok(codes.includes('DC'), `${key} does not offer DC`)
  }
  // And it reads as whatever that party calls it.
  const ny = exchangeOptionsFor(party('NY'), qso({ entityPrefix: 'K' })).find((option) => option.code === 'DC')
  assert.equal(ny?.name, 'Maryland & DC')
  const md = exchangeOptionsFor(party('MD'), qso({ entityPrefix: 'K' })).find((option) => option.code === 'DC')
  assert.equal(md?.name, 'District of Columbia')
})

test('7QP offers its neighbours\' counties, because its entrants work them', () => {
  const codes = exchangeOptionsFor(party('7QP'), qso({ entityPrefix: 'K' })).map((option) => option.code)
  assert.ok(codes.includes('ORDES'))
  // A neighbouring party's county — a valid exchange, and not one of 7QP's own.
  assert.ok(codes.some((code) => party('7QP').otherCounties[code] !== undefined))
})

test('the guessed state floats its counties up, and never fills the field', () => {
  // Ranking rather than prefilling (§5.3): a location guess is wrong often
  // enough that writing it in would be worse than useless.
  const preferred = preferredCodesFor(party('7QP'), 'OR')
  assert.ok(preferred.includes('ORDES'))
  assert.ok(preferred.includes('OR'))
  assert.deepEqual(preferred.some((code) => code.startsWith('WA')), false)
  assert.deepEqual(preferredCodesFor(party('NY'), ''), [])
})

test('the declared entry classes become the Cabrillo CATEGORY lines', () => {
  // The reason the classes are captured at all: a submitted log declares its
  // entry in these lines, and a checker reads them rather than guessing.
  const op = (ref: Record<string, JSONValue>) =>
    ({ uuid: 'op', stationCall: 'N0DEV', refs: [{ type: 'qp', ref: 'NY', ...ref }] })
  const lines = (ref: Record<string, JSONValue>) =>
    Object.fromEntries(cabrilloCategories(party('NY'), op(ref)).filter(([, v]) => v))

  assert.deepEqual(lines({ operator: 'SINGLE-OP', power: 'LOW', station: 'MOBILE', mode: 'CW' }), {
    'CATEGORY-OPERATOR': 'SINGLE-OP',
    'CATEGORY-POWER': 'LOW',
    'CATEGORY-STATION': 'MOBILE',
    'CATEGORY-MODE': 'CW',
  })

  // Cabrillo keeps the transmitter count apart from the operator class, while
  // sponsors publish them as one ("Multi-Single"), so it splits on the way out.
  assert.deepEqual(lines({ operator: 'MULTI-ONE' }), {
    'CATEGORY-OPERATOR': 'MULTI-OP',
    'CATEGORY-TRANSMITTER': 'ONE',
  })
  assert.equal(lines({ operator: 'MULTI-UNLIMITED' })['CATEGORY-TRANSMITTER'], 'UNLIMITED')

  // Phone is SSB in a Cabrillo header, and digital is DIGI.
  assert.equal(lines({ mode: 'PHONE' })['CATEGORY-MODE'], 'SSB')
  assert.equal(lines({ mode: 'DIGITAL' })['CATEGORY-MODE'], 'DIGI')

  // An unanswered question emits NO line: an omitted category is "no claim",
  // while a guessed one is a claim the operator never made.
  assert.deepEqual(lines({}), {})

  // A class the party does not publish is refused rather than submitted — NY
  // has no EOC class, and a value left behind by another party must not reach
  // a checker under this one.
  assert.deepEqual(lines({ station: 'EOC' }), {})
})

test('the file and the scoreboard agree about a blank exchange, both ways', () => {
  // The scorer remembers what a station sent the first time, so a second
  // contact on another band scores under that county. The export was reading
  // the ref raw and wrote NO row for it — a file claiming fewer contacts than
  // the scoreboard.
  const lastLocation: Record<string, string> = {}
  const first = cabrilloRowsFor(party('NY'), qso({ location: 'ERI' }), operation('ALB'), 'N0DEV', { lastLocation })
  assert.equal(first.length, 1)
  const second = cabrilloRowsFor(party('NY'), qso({}), operation('ALB'), 'N0DEV', { lastLocation })
  assert.equal(second.length, 1, 'the remembered county carries the second contact')
  assert.equal(second[0][5].trim(), 'ERI')

  // And the other direction: an exchange that resolves to nothing scores zero
  // with `invalidExchange`, so no row may be written for it either.
  assert.deepEqual(
    cabrilloRowsFor(party('NY'), qso({ location: 'XYZ' }), operation('ALB'), 'N0DEV'),
    [],
  )
})

test('both files write what the station SENT, which is not always what it scores as', () => {
  // Thirteen parties log a DX station by its entity prefix while it still
  // scores as the single `DX` multiplier. Every prefix used to resolve to `DX`
  // before the file was written, so the Cabrillo wrote `DX`, the ADIF wrote
  // `DL`, and the option those parties set changed nothing at all.
  const wa = { uuid: 'op', stationCall: 'N0DEV', refs: [{ type: 'qp', ref: 'WA', location: 'KING' }] }
  const dx = qso({ location: '', entityPrefix: 'DL', call: 'DL1ABC' })
  assert.equal(theirLocationForFile(party('WA'), dx, { weAreInParty: true }), 'DL')
  const rows = cabrilloRowsFor(party('WA'), dx, wa, 'N0DEV')
  assert.equal(rows[0][5].trim(), 'DL', 'the Cabrillo says what the ADIF says')

  // A party that logs them as plain `DX` still gets `DX`.
  assert.equal(theirLocationForFile(party('NY'), dx, { weAreInParty: true }), 'DX')
})

test('the ADIF and the Cabrillo agree about a remembered exchange', () => {
  // The scorer and the Cabrillo both score a blank exchange under the county
  // that station gave the first time. `adifFields` sees one contact at a time
  // and cannot know that — so our own export resolves the whole log up front
  // and hands the answers over.
  const first = { ...qso({ location: 'ERI' }), uuid: 'q1' }
  const second = { ...qso({}), uuid: 'q2', band: '40m' }
  const resolved = resolvedExchanges(party('NY'), operation('ALB'), [first, second])
  assert.equal(resolved.q1, 'ERI')
  assert.equal(resolved.q2, 'ERI', 'the second contact carries the county from the first')
  // Event rows and deleted contacts are not contacts.
  const withNoise = resolvedExchanges(party('NY'), operation('ALB'),
    [first, { band: 'event', uuid: 'e1' }, { ...second, deleted: true }])
  assert.deepEqual(Object.keys(withNoise), ['q1'])
})

test('the file claims no contact the scoreboard refused, and learns nothing from one', () => {
  // A 30m contact scores `invalidBand` at zero. It used to be written into the
  // Cabrillo anyway — and worse, its exchange was remembered, so the next blank
  // exchange from that station resolved in the file to a county the scoresheet
  // had never recorded.
  assert.equal(claimableBand('20m'), true)
  assert.equal(claimableBand('30m'), false)
  assert.equal(claimableBand(''), false)

  const lastLocation: Record<string, string> = {}
  const warc = { ...qso({ location: 'ERI' }), band: '30m' }
  assert.deepEqual(cabrilloRowsFor(party('NY'), warc, operation('ALB'), 'N0DEV', { lastLocation }), [])
  assert.deepEqual(lastLocation, {}, 'a refused contact teaches the file nothing')

  // And the same station on a legal band with a blank exchange is therefore
  // unclaimable too, exactly as the scorer sees it.
  assert.deepEqual(cabrilloRowsFor(party('NY'), qso({}), operation('ALB'), 'N0DEV', { lastLocation }), [])
})

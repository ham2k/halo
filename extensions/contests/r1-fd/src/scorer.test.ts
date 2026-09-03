// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Region 1 Field Day scoring pins the three things easy to get subtly wrong
// against neighbouring contests: the point table hinges on the OTHER station's
// portable suffix and on OUR station type (fixed-to-fixed is zero — no other
// contest here scores by the entrant's category), the portable test accepts
// exactly /P, /M, /MM and /AM (a /QRP scored as portable doubles the log), and
// the multiplier is PER BAND (WPX, ported earlier, is contest-wide — copying
// its accounting here would undercount every band after the first).

import { strict as assert } from "node:assert"
import { describe, it } from "node:test"

import type { JSONValue } from "@ham2k/extension-sdk"

import { R1FDScorer, modeOfRef, signsPortable, yearOfRef } from "./scorer.ts"
import type { R1FDScoresheet } from "./scorer.ts"

const SSB_RUNNING = { ref: 'SSB-2026', ourStationType: 'PORTABLE' }

/// Scores a run of QSOs against a fresh scoresheet, as the harness does.
function run(
  qsos: { call: string; band?: string; mode?: string }[],
  { ref = SSB_RUNNING }: { ref?: Record<string, JSONValue> } = {},
) {
  const operation = { stationCall: 'DL0ABC/P' }
  let sheet = R1FDScorer.startScoresheet({ operation, ref }, {} as never) as R1FDScoresheet
  const scores = qsos.map((q) => {
    const result = R1FDScorer.scoreQso(
      {
        scoresheet: sheet,
        qso: { band: q.band ?? '20m', mode: q.mode ?? 'SSB', their: { call: q.call } },
        operation,
        ref,
        isNewDay: false,
      },
      {} as never,
    )
    sheet = result.scoresheet
    return result.score
  })
  return { scores, sheet }
}

describe('signsPortable', () => {
  it('accepts exactly the rule-9 designators, wherever the prefix sits', () => {
    assert.equal(signsPortable('DL1ABC/P'), true)
    assert.equal(signsPortable('G3XYZ/M'), true)
    assert.equal(signsPortable('K1ABC/MM'), true)
    assert.equal(signsPortable('OE5XYZ/AM'), true)
    assert.equal(signsPortable('F/DL1ABC/P'), true)
    // Not portable: a bare call, and /QRP — a designator, but not a listed one.
    assert.equal(signsPortable('DL1ABC'), false)
    assert.equal(signsPortable('DL1ABC/QRP'), false)
  })
})

describe('running keys', () => {
  it('parses mode and year, refusing what is neither CW nor SSB', () => {
    assert.equal(modeOfRef('SSB-2026'), 'SSB')
    assert.equal(modeOfRef('CW-2026'), 'CW')
    assert.equal(yearOfRef('CW-2026'), '2026')
    assert.equal(modeOfRef('RTTY-2026'), '')
    assert.equal(modeOfRef(''), '')
    assert.equal(yearOfRef('CW'), '')
  })
})

describe('R1FDScorer points', () => {
  it('scores the two-axis table: 2/3 for fixed stations, 4/6 for portable', () => {
    const { scores } = run([
      { call: 'DL1AAA' },      // fixed, Europe
      { call: 'K1AAA' },       // fixed, DX
      { call: 'DL2BBB/P' },    // portable, Europe
      { call: 'VE3CCC/M' },    // portable (mobile), DX
    ])
    assert.deepEqual(scores.map((s) => s.value), [2, 3, 4, 6])
  })

  it('zeroes fixed-to-fixed, but portable stations still score for a fixed entrant', () => {
    const fixedRef = { ref: 'SSB-2026', ourStationType: 'FIXED' }
    const { scores } = run(
      [{ call: 'DL1AAA' }, { call: 'K1AAA' }, { call: 'DL2BBB/P' }],
      { ref: fixedRef },
    )
    assert.deepEqual(scores.map((s) => s.value), [0, 0, 4])
  })

  it('reads Europe off the WAE map — European Turkey is EU, Asiatic Turkey is not', () => {
    const { scores } = run([{ call: 'TA1AAA' }, { call: 'TA2BBB' }])
    assert.deepEqual(scores.map((s) => s.value), [2, 3])
  })

  it('does not double points anywhere — a low band scores the same table', () => {
    const { scores } = run([{ call: 'DL1AAA', band: '80m' }, { call: 'K1AAA', band: '160m' }])
    assert.deepEqual(scores.map((s) => s.value), [2, 3])
  })
})

describe('R1FDScorer dupes and validity', () => {
  it('allows one QSO per station per band', () => {
    const { scores } = run([
      { call: 'DL1AAA' },
      { call: 'DL1AAA' },
      { call: 'DL1AAA', band: '40m' },
    ])
    assert.equal(scores[1].dupe, true)
    assert.deepEqual(scores[1].alerts, ['duplicate'])
    assert.equal(scores[2].value, 2)
    // The new band brings the country back as a mult too — per-band mults.
    assert.deepEqual(scores[2].notices, ['newMult', 'newBand'])
  })

  it('rejects the wrong mode for the running and any WARC band', () => {
    const { scores } = run([
      { call: 'DL1AAA', mode: 'CW' },
      { call: 'DL2BBB', band: '17m' },
      // The sideband modes count as SSB.
      { call: 'DL3CCC', mode: 'LSB' },
    ])
    assert.deepEqual(scores[0].alerts, ['invalidMode'])
    assert.deepEqual(scores[1].alerts, ['invalidBand'])
    assert.equal(scores[2].value, 2)
  })

  it('filters CW runnings to CW', () => {
    const { scores } = run(
      [{ call: 'DL1AAA', mode: 'CW' }, { call: 'DL2BBB', mode: 'SSB' }],
      { ref: { ref: 'CW-2026', ourStationType: 'PORTABLE' } },
    )
    assert.equal(scores[0].value, 2)
    assert.deepEqual(scores[1].alerts, ['invalidMode'])
  })
})

describe('R1FDScorer multipliers', () => {
  it('counts an entity once per BAND — a new band makes the same country new again', () => {
    const { scores, sheet } = run([
      { call: 'DL1AAA' },              // DL on 20m — new mult
      { call: 'DL2BBB' },              // DL on 20m again — not
      { call: 'DL1AAA', band: '40m' }, // DL on 40m — new mult again
    ])
    assert.deepEqual(scores[0].notices, ['newMult'])
    assert.equal(scores[1].notices, undefined)
    assert.ok(scores[2].notices?.includes('newMult'))
    assert.equal(Object.keys(sheet.mults).length, 2)
  })

  it('counts WAE-only entities apart from their DXCC parent', () => {
    // Sicily beside mainland Italy, European beside Asiatic Turkey — under a
    // DXCC-only resolution each pair collapses into one mult.
    const { sheet } = run([
      { call: 'IT9AAA' },
      { call: 'I2BBB' },
      { call: 'TA1CCC' },
      { call: 'TA2DDD' },
    ])
    assert.equal(Object.keys(sheet.mults).length, 4)
  })

  it('a zero-point fixed-to-fixed QSO still counts its country', () => {
    const { scores, sheet } = run(
      [{ call: 'DL1AAA' }],
      { ref: { ref: 'SSB-2026', ourStationType: 'FIXED' } },
    )
    assert.equal(scores[0].value, 0)
    assert.deepEqual(scores[0].notices, ['newMult'])
    assert.equal(Object.keys(sheet.mults).length, 1)
  })

  it('totals points × mults', () => {
    const { sheet } = run([
      { call: 'DL1AAA' },        // 2 pts, DL/20m
      { call: 'K1AAA/P' },       // 6 pts, K/20m
      { call: 'F4AAA', band: '40m' }, // 2 pts, F/40m
    ])
    const summary = R1FDScorer.summarizeScore(
      { scoresheet: sheet, operation: {}, scope: 'operation' },
      {} as never,
    )
    assert.equal(summary.r1fd.points, 10)
    assert.equal(summary.r1fd.mults, 3)
    assert.equal(summary.r1fd.total, 30)
  })
})

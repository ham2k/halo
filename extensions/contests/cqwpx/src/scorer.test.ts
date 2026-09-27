// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// WPX scoring is worth testing tightly because two things about it are easy to
// get subtly wrong and impossible to notice from the running total: the
// multiplier is contest-wide rather than per band (CQ WW, the contest ported
// just before this one, is the opposite), and the point table has an exception
// per continent plus a same-country case that does NOT double on the low bands.
// app-polo gets both of those last two wrong; the tests below pin the published
// rules.

import { strict as assert } from "node:assert"
import { describe, it } from "node:test"

import type { JSONValue } from "@ham2k/extension-sdk"

import { CQWPXScorer, wpxPrefix } from "./scorer.ts"
import type { CQWPXScoresheet } from "./scorer.ts"

const CW = { mode: "CW" }

/// Scores a run of QSOs against a fresh scoresheet, as the harness does.
function run(
  qsos: { call: string; band?: string; mode?: string }[],
  { stationCall = "KI2D", ref = CW }: { stationCall?: string; ref?: Record<string, JSONValue> } = {},
) {
  const operation = { stationCall }
  let sheet = CQWPXScorer.startScoresheet({ operation }, {} as never) as CQWPXScoresheet
  const scores = qsos.map((q) => {
    const result = CQWPXScorer.scoreQso(
      {
        scoresheet: sheet,
        qso: { band: q.band ?? "20m", mode: q.mode ?? "CW", their: { call: q.call } },
        operation,
        ref,
        isNewDay: false,
      },
      {} as never,
    )
    sheet = result.scoresheet
    return result.score
  })
  return { sheet, scores, summary: CQWPXScorer.summarizeScore({ scoresheet: sheet, operation, ref, scope: "operation" }, {} as never) }
}

describe("wpxPrefix", () => {
  it("takes the letter/numeral combination that starts the call", () => {
    assert.equal(wpxPrefix("N8BJQ"), "N8")
    assert.equal(wpxPrefix("WD8ABC"), "WD8")
    assert.equal(wpxPrefix("GW4BLE"), "GW4")
    assert.equal(wpxPrefix("2E0ABC"), "2E0")
  })

  it("lets a portable designator override the home prefix", () => {
    // The whole point of signing portable: N8BJQ operating from Wake Island
    // hands out KH9, and that is the multiplier the other station gets.
    assert.equal(wpxPrefix("N8BJQ/KH9"), "KH9")
    assert.equal(wpxPrefix("W8/GW4BLE"), "W8")
    assert.equal(wpxPrefix("KH6XXX/W8"), "W8")
  })

  it("ignores designators that are not prefixes", () => {
    // /P, /M and /QRP say nothing about where the station is.
    assert.equal(wpxPrefix("LZ2ITU/P"), "LZ2")
    assert.equal(wpxPrefix("K1ABC/QRP"), "K1")
  })

  it("assigns a zero when there is no number", () => {
    // Both spelled out in the rules. Without this the multiplier is silently
    // dropped and the score comes out low.
    assert.equal(wpxPrefix("PA/N8BJQ"), "PA0")
    assert.equal(wpxPrefix("XEFTJW"), "XE0")
  })

  it("keeps a letters-then-digits special call whole", () => {
    // The rules list these verbatim. A general callsign parser reads LY1000 as
    // LY1 with a numeric suffix, which would silently merge it with every other
    // LY1 station worked.
    assert.equal(wpxPrefix("HG19"), "HG19")
    assert.equal(wpxPrefix("LY1000"), "LY1000")
    assert.equal(wpxPrefix("OE25"), "OE25")
  })

  it("is empty for an empty call rather than inventing a multiplier", () => {
    assert.equal(wpxPrefix(""), "")
    assert.equal(wpxPrefix("   "), "")
  })
})

describe("CQWPXScorer points", () => {
  it("scores a different continent at 3, doubled on the low bands", () => {
    const { scores } = run([{ call: "DL1ABC" }, { call: "DL2ABC", band: "40m" }])
    assert.equal(scores[0].value, 3)
    assert.equal(scores[1].value, 6)
  })

  it("scores North America to North America at 2, doubled on the low bands", () => {
    // The documented exception, and the reason a US operator's 40m run is worth
    // chasing.
    const { scores } = run([{ call: "VE3XYZ" }, { call: "VE7XYZ", band: "80m" }])
    assert.equal(scores[0].value, 2)
    assert.equal(scores[1].value, 4)
  })

  it("scores same-continent-different-country at 1 outside North America", () => {
    // app-polo gives 2 here — the North American rate, applied worldwide. An
    // EU station working EU would score double what the rules allow, and the
    // error is invisible in the running total.
    const { scores } = run([{ call: "F5ABC" }, { call: "F6ABC", band: "40m" }], { stationCall: "DL1ABC" })
    assert.equal(scores[0].value, 1)
    assert.equal(scores[1].value, 2)
  })

  it("scores our own country at 1 on every band, including the low ones", () => {
    // Rule B.3 says "1 point regardless of band" — it is the one case the
    // low-band doubling does not touch. app-polo doubles it along with
    // everything else.
    const { scores } = run([{ call: "W1AW" }, { call: "K1ABC", band: "160m" }])
    assert.equal(scores[0].value, 1)
    assert.equal(scores[1].value, 1)
  })

  it("scores our own country, unlike CQ WW where it is worth nothing", () => {
    const { sheet } = run([{ call: "W1AW" }])
    assert.equal(sheet.points, 1)
  })
})

describe("CQWPXScorer multipliers", () => {
  it("counts each prefix once for the whole contest, not once per band", () => {
    // THE structural difference from CQ WW. Getting this wrong inflates the
    // score by roughly the number of bands worked.
    const { sheet, scores } = run([
      { call: "DL1ABC", band: "20m" },
      { call: "DL1ABC", band: "40m" },
      { call: "DL1XYZ", band: "15m" },
    ])
    assert.equal(Object.keys(sheet.mults).length, 1)
    assert.deepEqual(scores[0].notices, ["newMult"])
    // Same prefix on a new band: a new QSO and new points, but not a new mult.
    assert.deepEqual(scores[1].notices, ["newBand"])
    assert.equal(scores[2].notices, undefined)
  })

  it("treats any difference in the numbering as a separate prefix", () => {
    const { sheet } = run([{ call: "DL1ABC" }, { call: "DL2ABC" }, { call: "DK1ABC" }])
    assert.deepEqual(Object.keys(sheet.mults).sort(), ["DK1", "DL1", "DL2"])
  })

  it("multiplies points by prefixes for the total", () => {
    const { summary } = run([{ call: "DL1ABC" }, { call: "JA1ABC" }])
    // 3 + 3 points, 2 prefixes.
    assert.equal(summary.cqwpx.points, 6)
    assert.equal(summary.cqwpx.mults, 2)
    assert.equal(summary.cqwpx.total, 12)
  })
})

describe("CQWPXScorer exclusions", () => {
  it("scores a repeat on the same band as a duplicate worth nothing", () => {
    const { scores, sheet } = run([{ call: "DL1ABC" }, { call: "DL1ABC" }])
    assert.equal(scores[1].value, 0)
    assert.equal(scores[1].dupe, true)
    assert.deepEqual(scores[1].alerts, ["duplicate"])
    // And it must not inflate the QSO count or claim a second multiplier.
    assert.equal(sheet.qsos, 1)
    assert.equal(sheet.mults.DL1, 1)
  })

  it("rejects the WARC bands, which the rules exclude", () => {
    const { scores, sheet } = run([{ call: "DL1ABC", band: "30m" }])
    assert.equal(scores[0].value, 0)
    assert.deepEqual(scores[0].alerts, ["invalidBand"])
    assert.equal(sheet.qsos, 0)
  })

  it("rejects a QSO in the wrong mode for the weekend", () => {
    const { scores } = run([{ call: "DL1ABC", mode: "SSB" }])
    assert.equal(scores[0].value, 0)
    assert.deepEqual(scores[0].alerts, ["invalidMode"])
  })

  it("accepts USB and LSB during an SSB weekend", () => {
    // A radio reports the sideband, not the generic mode; refusing those would
    // zero out a whole log.
    const { scores } = run(
      [
        { call: "DL1ABC", mode: "USB" },
        { call: "DL2ABC", mode: "LSB" },
      ],
      {
        ref: { mode: "SSB" },
      },
    )
    assert.equal(scores[0].value, 3)
    assert.equal(scores[1].value, 3)
  })
})

describe("CQWPXScorer summary", () => {
  it("breaks out each band and lists the prefixes worked", () => {
    const { summary } = run([
      { call: "DL1ABC", band: "20m" },
      { call: "JA1ABC", band: "40m" },
    ])
    const detail = summary.cqwpx.longSummary as string
    assert.match(detail, /\*\*20m\*\*: 1 QSOs, 3 pts/)
    assert.match(detail, /\*\*40m\*\*: 1 QSOs, 6 pts/)
    assert.match(detail, /\*\*15m\*\*: —/)
    // The prefix list is the point of WPX — it tells the operator whether the
    // station calling is worth working.
    assert.match(detail, /2 prefixes/)
    assert.match(detail, /DL1 JA1/)
  })

  it("titles itself as the operation does, with the score, over the arithmetic", () => {
    const { summary } = run([
      { call: "DL1ABC", band: "20m" },
      { call: "JA1ABC", band: "40m" },
    ])
    assert.equal(summary.cqwpx.label, "CQWPX CW: 18 points")
    assert.equal((summary.cqwpx.longSummary as string).split("\n")[0], "2 QSOs, 9 pts × 2 mults")
  })

  // Prefixes count once for the whole contest, so a day's share of the score
  // is not a number WPX defines.
  it("offers no per-day summary", () => {
    const operation = { stationCall: "KI2D" }
    const sheet = CQWPXScorer.startScoresheet({ operation }, {} as never) as CQWPXScoresheet
    assert.deepEqual(CQWPXScorer.summarizeScore({ scoresheet: sheet, operation, ref: CW, scope: "day" }, {} as never), {})
  })
})

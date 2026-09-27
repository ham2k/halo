// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// NFD scoring is worth pinning tightly because this extension sits beside
// `r1-fd`, which runs the same weekend and disagrees with it on four rules.
// Every mutation that would turn this scorer back into that one is a plausible
// edit — and none of them would look wrong in review:
//   - dropping mode from the dupe key (R1's rule) silently loses every
//     second-mode contact as a duplicate
//   - dropping band from the mult key halves a typical entry, and the rule's
//     PROSE reads that way; only its worked example says otherwise, so the
//     example is a test here
//   - resolving WAE instead of DXCC splits IT9 from I
//   - dropping 60m, or rejecting a mode for not matching the running

import { strict as assert } from "node:assert"
import { describe, it } from "node:test"

import type { JSONValue } from "@ham2k/extension-sdk"

import { NFDScorer, bonusPoints, nfdMode, signsPortable } from "./scorer.ts"
import type { NFDScoresheet } from "./scorer.ts"

const RUNNING = { ref: "2026" }

/// Scores a run of QSOs against a fresh scoresheet, as the harness does.
function run(qsos: { call: string; band?: string; mode?: string }[], { ref = RUNNING }: { ref?: Record<string, JSONValue> } = {}) {
  const operation = { stationCall: "LA1ABC/P" }
  let sheet = NFDScorer.startScoresheet({ operation, ref }, {} as never) as NFDScoresheet
  const scores = qsos.map((q) => {
    const result = NFDScorer.scoreQso(
      {
        scoresheet: sheet,
        qso: { band: q.band ?? "20m", mode: q.mode ?? "SSB", their: { call: q.call } },
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

describe("nfdMode", () => {
  it("collapses everything into the rule's three modes", () => {
    assert.equal(nfdMode("CW"), "CW")
    // Telephony, all of it — the rule defines digimode as what is neither
    // phone nor CW, so AM and FM are SSB here rather than a third thing.
    assert.equal(nfdMode("SSB"), "SSB")
    assert.equal(nfdMode("USB"), "SSB")
    assert.equal(nfdMode("FM"), "SSB")
    assert.equal(nfdMode("AM"), "SSB")
    assert.equal(nfdMode("FT8"), "DIGI")
    assert.equal(nfdMode("RTTY"), "DIGI")
    // A mode-less QSO is refused rather than silently counted as digimode,
    // which is what the underlying superModeForMode would answer.
    assert.equal(nfdMode(""), "")
  })
})

describe("NFDScorer points", () => {
  it("scores the flat table: 1/2 fixed, 3/4 portable", () => {
    const { scores } = run([
      { call: "LA2AAA" }, // fixed, Europe (incl. Norway)
      { call: "K1AAA" }, // fixed, DX
      { call: "DL2BBB/P" }, // portable, Europe
      { call: "VE3CCC/M" }, // portable (mobile), DX
    ])
    assert.deepEqual(
      scores.map((s) => s.value),
      [1, 2, 3, 4],
    )
  })

  it("works our own country like any other European one", () => {
    // "inkl. Norge" — no home-country exception in either direction.
    const { scores } = run([{ call: "LA9XYZ" }, { call: "LA9ZZZ/P" }])
    assert.deepEqual(
      scores.map((s) => s.value),
      [1, 3],
    )
  })

  it("has no low-band doubling", () => {
    const { scores } = run([
      { call: "DL1AAA", band: "80m" },
      { call: "DL2BBB", band: "160m" },
    ])
    assert.deepEqual(
      scores.map((s) => s.value),
      [1, 1],
    )
  })

  it("counts 60m, which the IARU R1 field days exclude", () => {
    const { scores } = run([{ call: "DL1AAA", band: "60m" }])
    assert.equal(scores[0].value, 1)
    assert.equal(scores[0].alerts, undefined)
  })

  it("refuses a band outside the list", () => {
    const { scores } = run([{ call: "DL1AAA", band: "17m" }])
    assert.deepEqual(scores[0].alerts, ["invalidBand"])
  })
})

describe("NFDScorer dupes", () => {
  it("allows one QSO per station per band AND per mode", () => {
    const { scores } = run([
      { call: "DL1AAA", band: "20m", mode: "SSB" },
      { call: "DL1AAA", band: "20m", mode: "SSB" }, // dupe
      { call: "DL1AAA", band: "20m", mode: "CW" }, // fresh — different mode
      { call: "DL1AAA", band: "40m", mode: "SSB" }, // fresh — different band
      { call: "DL1AAA", band: "20m", mode: "FT8" }, // fresh — digimode
    ])
    assert.equal(scores[0].value, 1)
    assert.equal(scores[1].dupe, true)
    assert.deepEqual(scores[1].alerts, ["duplicate"])
    assert.equal(scores[2].value, 1)
    assert.equal(scores[3].value, 1)
    assert.equal(scores[4].value, 1)
  })

  it("accepts every mode at once — there is no per-running mode filter", () => {
    const { scores } = run([
      { call: "DL1AAA", mode: "CW" },
      { call: "DL2BBB", mode: "SSB" },
      { call: "DL3CCC", mode: "FT8" },
    ])
    assert.equal(
      scores.every((s) => s.value === 1),
      true,
    )
    assert.equal(
      scores.every((s) => s.alerts === undefined),
      true,
    )
  })
})

describe("NFDScorer multipliers", () => {
  it("follows the rule's own worked example: DL on 20m SSB, 20m CW and 40m SSB is THREE", () => {
    // "Om man kjører DL på 20 m SSB, 20 m CW og 40 m SSB gir dette tre
    // multiplikatorer." Three only if the mult key carries band AND mode; the
    // prose's "country and mode" reading would make this two.
    const { sheet } = run([
      { call: "DL1AAA", band: "20m", mode: "SSB" },
      { call: "DL2BBB", band: "20m", mode: "CW" },
      { call: "DL3CCC", band: "40m", mode: "SSB" },
    ])
    assert.equal(Object.keys(sheet.mults).length, 3)
  })

  it("counts a country once per band-and-mode however many stations are worked", () => {
    const { scores, sheet } = run([
      { call: "DL1AAA" },
      { call: "DL2BBB" }, // same country, band and mode — not a new mult
    ])
    assert.deepEqual(scores[0].notices, ["newMult"])
    assert.equal(scores[1].notices, undefined)
    assert.equal(Object.keys(sheet.mults).length, 1)
  })

  it("resolves DXCC, not WAE — Sicily is Italy here", () => {
    // The opposite of `r1-fd`, which scores the WAE list and splits these.
    const { sheet } = run([{ call: "IT9AAA" }, { call: "I2BBB" }])
    assert.equal(Object.keys(sheet.mults).length, 1)
  })

  it("totals points × mults", () => {
    const { sheet } = run([
      { call: "DL1AAA" }, // 1 pt, DL/20m/SSB
      { call: "K1AAA/P" }, // 4 pts, K/20m/SSB
      { call: "F4AAA", band: "40m", mode: "CW" }, // 1 pt, F/40m/CW
    ])
    const summary = NFDScorer.summarizeScore({ scoresheet: sheet, operation: {}, scope: "operation" }, {} as never)
    // 6 points × 3 mults, no bonuses claimed.
    assert.equal(summary.contest.total, 18)
    assert.equal(summary.contest.label, "NFD: 18 points")
    assert.equal((summary.contest.longSummary as string).split("\n")[0], "3 QSOs, 6 pts × 3 mults")
  })
})

describe("bonusPoints", () => {
  it("pays recruits by tier and caps the pair at 50,000", () => {
    assert.equal(bonusPoints({ bonusRecruits1h: 2 }), 10000)
    assert.equal(bonusPoints({ bonusRecruits6h: 2 }), 20000)
    // 4x5,000 + 4x10,000 = 60,000, capped.
    assert.equal(bonusPoints({ bonusRecruits1h: 4, bonusRecruits6h: 4 }), 50000)
  })

  it("pays media PER OUTLET, not per category", () => {
    // "Det gis poeng for hver avis, radio, og TV-kanal" — three newspapers is
    // three awards, where a flat category checkbox would pay one.
    assert.equal(bonusPoints({ bonusNewspapers: 3 }), 30000)
    assert.equal(bonusPoints({ bonusNewspapers: 1, bonusRadioChannels: 1, bonusTvChannels: 1 }), 30000)
  })

  it("pays YouTube a base plus likes, capped, and nothing without a video", () => {
    assert.equal(bonusPoints({ bonusYoutubeVideo: true }), 1000)
    assert.equal(bonusPoints({ bonusYoutubeVideo: true, bonusYoutubeLikes: 50 }), 1500)
    assert.equal(bonusPoints({ bonusYoutubeVideo: true, bonusYoutubeLikes: 5000 }), 10000)
    // Likes without a video earn nothing — the base is what the video is worth.
    assert.equal(bonusPoints({ bonusYoutubeLikes: 50 }), 0)
  })

  it("ignores absent, negative and malformed claims", () => {
    assert.equal(bonusPoints(undefined), 0)
    assert.equal(bonusPoints({}), 0)
    assert.equal(bonusPoints({ bonusRecruits1h: -3, bonusNewspapers: "lots" }), 0)
  })

  it("adds the flat claims", () => {
    assert.equal(
      bonusPoints({
        bonusPublicActivity: true,
        bonusOrienteering: true,
        bonusLocation: true,
        bonusReport: true,
      }),
      40000,
    )
  })
})

describe("NFDScorer bonuses in the score", () => {
  it("adds the bonus to the total, and keeps it apart in the arithmetic", () => {
    const ref = { ref: "2026", bonusReport: true }
    const { sheet } = run([{ call: "DL1AAA" }], { ref })
    const operation = NFDScorer.summarizeScore({ scoresheet: sheet, operation: {}, ref, scope: "operation" }, {} as never)
    // 1 point x 1 mult, plus the 10,000 report bonus.
    assert.equal(operation.contest.total, 10001)
    // The bonus can be most of the score; folded in, the operator could not
    // tell what the contacts themselves earned.
    assert.equal((operation.contest.longSummary as string).split("\n")[0], "1 QSO, 1 pt × 1 mult + 10,000 bonus")
  })

  // Multipliers and bonuses belong to the whole entry, so a day's share of
  // the score is not a number the contest defines.
  it("offers no per-day summary", () => {
    const ref = { ref: "2026", bonusReport: true }
    const { sheet } = run([{ call: "DL1AAA" }], { ref })
    assert.deepEqual(NFDScorer.summarizeScore({ scoresheet: sheet, operation: {}, ref, scope: "day" }, {} as never), {})
  })

  it("latches the bonus at the start of the fold, not from the ref at summary time", () => {
    // summarizeScore is handed the FIRST segment's ref; reading bonuses there
    // would lose them for an operation whose later segment carries a different
    // one. Pinned by summarizing with NO ref at all.
    const ref = { ref: "2026", bonusLocation: true }
    const { sheet } = run([{ call: "DL1AAA" }], { ref })
    const summary = NFDScorer.summarizeScore({ scoresheet: sheet, operation: {}, scope: "operation" }, {} as never)
    assert.equal(summary.contest.total, 10001)
  })
})

describe("signsPortable", () => {
  it("accepts the portable and mobile designators, but not /QRP", () => {
    assert.equal(signsPortable("DL1ABC/P"), true)
    assert.equal(signsPortable("G3XYZ/M"), true)
    assert.equal(signsPortable("K1ABC/MM"), true)
    assert.equal(signsPortable("DL1ABC"), false)
    assert.equal(signsPortable("DL1ABC/QRP"), false)
  })
})

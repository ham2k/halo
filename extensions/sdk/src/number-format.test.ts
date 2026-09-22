// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// These cases are pinned against what JavaScriptCore produced, because that is
// what macOS and iOS users saw before the engine swap — the polyfill exists to
// keep their output identical, and to give the other three platforms (which
// never had Intl) the separators docs/extensions/README.md already promises.
//
// Every expectation here was captured from a real Intl implementation rather
// than reasoned out. Node runs these WITH Intl, so the installer is a no-op
// here and formatNumberEnUS is tested directly — which is also why it is
// exported.

import assert from "node:assert/strict"
import { describe, it } from "node:test"

import { formatNumberEnUS, installNumberFormatPolyfill } from "./number-format.ts"

// The option bags @ham2k/lib-format-tools actually passes.
const INTEGER = { minimumFractionDigits: 0, maximumFractionDigits: 0 }
const ONE_DECIMAL = { minimumFractionDigits: 1, maximumFractionDigits: 1 }

describe("formatNumberEnUS", () => {
  it("groups thousands, which is the whole point", () => {
    // A 1500-QSO tally read "1500 QSOs" without this.
    assert.equal(formatNumberEnUS(1500, INTEGER), "1,500")
    assert.equal(formatNumberEnUS(345320, INTEGER), "345,320")
    assert.equal(formatNumberEnUS(1000, INTEGER), "1,000")
    assert.equal(formatNumberEnUS(1234567890, INTEGER), "1,234,567,890")
  })

  it("leaves values below the grouping threshold alone", () => {
    assert.equal(formatNumberEnUS(0, INTEGER), "0")
    assert.equal(formatNumberEnUS(999, INTEGER), "999")
  })

  it("rounds to maximumFractionDigits rather than truncating", () => {
    // fmtInteger(1234.56) must be 1,235 — a QSO count is never fractional,
    // but scores and percentages reach this path.
    assert.equal(formatNumberEnUS(1234.56, INTEGER), "1,235")
    assert.equal(formatNumberEnUS(1234.56, ONE_DECIMAL), "1,234.6")
    assert.equal(formatNumberEnUS(12.345, ONE_DECIMAL), "12.3")
  })

  it("pads up to minimumFractionDigits", () => {
    assert.equal(formatNumberEnUS(5, ONE_DECIMAL), "5.0")
    assert.equal(formatNumberEnUS(1000, ONE_DECIMAL), "1,000.0")
  })

  it("defaults to at most 3 decimals, like Intl, not to 0", () => {
    assert.equal(formatNumberEnUS(1234.5678), "1,234.568")
    assert.equal(formatNumberEnUS(1234.5), "1,234.5")
    assert.equal(formatNumberEnUS(1234), "1,234")
  })

  it("handles negatives", () => {
    assert.equal(formatNumberEnUS(-9876543, INTEGER), "-9,876,543")
    assert.equal(formatNumberEnUS(-0.4, INTEGER), "-0")
  })

  it("passes non-finite values straight through", () => {
    assert.equal(formatNumberEnUS(NaN), "NaN")
    assert.equal(formatNumberEnUS(Infinity), "Infinity")
    assert.equal(formatNumberEnUS(-Infinity), "-Infinity")
  })

  it("honours useGrouping: false", () => {
    assert.equal(formatNumberEnUS(1234567, { useGrouping: false }), "1234567")
  })

  it("rounds decimal ties the way Intl does, not the way toFixed does", () => {
    // The first version used absolute.toFixed(maximum), which rounds the
    // BINARY double; Intl rounds the number's shortest decimal
    // representation. They disagree whenever a 5 sits just past the last kept
    // digit — measured at ~4% of two-decimal values — so every case here
    // failed before roundHalfExpand existed.
    assert.equal(formatNumberEnUS(12.35, ONE_DECIMAL), "12.4") // toFixed gave 12.3
    assert.equal(formatNumberEnUS(0.15, ONE_DECIMAL), "0.2") // toFixed gave 0.1
    assert.equal(formatNumberEnUS(1.005, { minimumFractionDigits: 2, maximumFractionDigits: 2 }), "1.01")
    assert.equal(formatNumberEnUS(9.9995), "10") // carries all the way up
  })

  it("matches the engine it is imitating, exhaustively", () => {
    // Node has real Intl, so this asserts against the actual implementation
    // rather than against my reading of the spec. The earlier version of this
    // test pinned ten hand-picked values and passed against the broken
    // rounding, because all ten happened to fall on the agreeing side — hence
    // the sweep.
    let checked = 0
    for (const opts of [INTEGER, ONE_DECIMAL, { minimumFractionDigits: 2, maximumFractionDigits: 2 }, undefined]) {
      for (let k = 0; k <= 20000; k++) {
        const n = k / 100
        assert.equal(formatNumberEnUS(n, opts), n.toLocaleString("en-US", opts), `${n} ${JSON.stringify(opts)}`)
        checked++
      }
      for (const n of [0, -0.4, 1.005, 9.9995, 12.35, 0.15, 2.675, 1e20, 0.1 + 0.2, 1234.5678, -9876543.21]) {
        assert.equal(formatNumberEnUS(n, opts), n.toLocaleString("en-US", opts), `${n} ${JSON.stringify(opts)}`)
        checked++
      }
    }
    assert.ok(checked > 80000, `expected a real sweep, checked ${checked}`)
  })
})

describe("installNumberFormatPolyfill", () => {
  it("does NOT replace a working implementation", () => {
    // Node, the web runtime and JavaScriptCore all format correctly already.
    // Clobbering them with this en-US-only subset would be a regression.
    const before = Number.prototype.toLocaleString
    installNumberFormatPolyfill()
    assert.equal(Number.prototype.toLocaleString, before)
  })

  it("never defines Intl", () => {
    // i18next activates its Formatter on `typeof Intl !== "undefined"` and then
    // calls Intl.NumberFormat/DateTimeFormat/PluralRules. A partial Intl would
    // turn quiet degradation into a thrown error that fails the whole hook.
    const src = installNumberFormatPolyfill.toString() + formatNumberEnUS.toString()
    assert.ok(!/\bIntl\s*=/.test(src), "the polyfill must never assign to Intl")
  })
})

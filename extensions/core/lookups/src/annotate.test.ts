// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { annotateCallsign } from "./annotate.ts"

test("annotateCallsign resolves a DXCC entity flag for a plain callsign", () => {
  // W1AW -> United States.
  const result = annotateCallsign("W1AW") as { flag?: string; entityPrefix?: string }

  assert.equal(result.entityPrefix, "K")
  assert.equal(result.flag, "🇺🇸")
})

test("annotateCallsign resolves a different flag for a different country's callsign", () => {
  // G0ABC -> England, its own DXCC entity distinct from Scotland/Wales, with
  // its own subdivision flag emoji rather than the UK's.
  const result = annotateCallsign("G0ABC") as { flag?: string; entityPrefix?: string }

  assert.equal(result.entityPrefix, "G")
  assert.equal(result.flag, "🏴󠁧󠁢󠁥󠁮󠁧󠁿")
})

test("annotateCallsign leaves flag unset for an unresolvable callsign", () => {
  const result = annotateCallsign("XX") as { flag?: string }
  assert.equal(result.flag, undefined)
})

test("annotateCallsign resolves the operator's ITU region and country code (HALO-52)", () => {
  const result = annotateCallsign("W1AW") as { ituRegion?: number; countryCode?: string }
  assert.equal(result.ituRegion, 2)
  assert.equal(result.countryCode, "us")
})

test("annotateCallsign leaves ituRegion/countryCode unset for an unresolvable callsign", () => {
  const result = annotateCallsign("XX") as { ituRegion?: number; countryCode?: string }
  assert.equal(result.ituRegion, undefined)
  assert.equal(result.countryCode, undefined)
})

// A station signing a call-area digit is outside the call area its license
// address is in; reading it as home lets that address place it.
test("annotateCallsign reads a call-area digit as away from home, like /P", () => {
  for (const call of ["KI2D/4", "KI2D/P"]) {
    assert.equal(annotateCallsign(call).locationScope, "portable", call)
  }
  assert.equal(annotateCallsign("KI2D").locationScope, "qth")
  assert.equal(annotateCallsign("EA3/KI2D").locationScope, "prefixed")
})

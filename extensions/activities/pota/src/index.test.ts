// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { REFERENCE_REGEX, normalizeReference, transformsForPrefix, hunterDefaultPrefix, activationDefaultPrefix, potaCountryPrefixForCall } from "./refFormatting.ts"
import { suggestOperationTitleForPota } from "./titleSuggestion.ts"

// Mirrors the group-expansion logic in
// `packages/halo_widgets/lib/src/ref_text_input.dart`'s
// `_RefTransformFormatter._applyOnce`/`expand` — braced `${1}`/`${2}`…
// placeholders, not bare `$1`/`$2`, applied twice for convergence on a
// multi-character paste.
function applyTransforms(text: string, transforms: { pattern: string; replacement: string; flags?: string }[]): string {
  const applyOnce = (t: string) => {
    for (const transform of transforms) {
      const regex = new RegExp(transform.pattern, transform.flags ?? "")
      t = t.replace(regex, (...args) => {
        const groups = args.slice(1, -2) as string[]
        return transform.replacement.replace(/\$\{(\d+)\}/g, (_, i) => groups[Number(i) - 1] ?? "")
      })
    }
    return t
  }
  return applyOnce(applyOnce(text))
}

test("REFERENCE_REGEX accepts a well-formed park reference and rejects garbage", () => {
  assert.equal(REFERENCE_REGEX.test("US-1234"), true)
  assert.equal(REFERENCE_REGEX.test("us-1234"), true) // case-insensitive
  assert.equal(REFERENCE_REGEX.test("US-TEST"), true)
  assert.equal(REFERENCE_REGEX.test("US1234"), false) // missing dash
  assert.equal(REFERENCE_REGEX.test("US-12"), false) // too few digits
  assert.equal(REFERENCE_REGEX.test("not a ref"), false)
})

test("normalizeReference accepts a dashed reference as-is, uppercased", () => {
  assert.equal(normalizeReference("US-1234"), "US-1234")
  assert.equal(normalizeReference("us-1234"), "US-1234")
  assert.equal(normalizeReference(" US-1234 "), "US-1234")
  assert.equal(normalizeReference("us-test"), "US-TEST")
})

test("normalizeReference accepts the same reference without a dash", () => {
  assert.equal(normalizeReference("US1234"), "US-1234")
  assert.equal(normalizeReference("us1234"), "US-1234")
  assert.equal(normalizeReference("KTEST"), "K-TEST")
  assert.equal(normalizeReference("k-test"), "K-TEST")
})

test("normalizeReference rejects anything that isn't a fully-formed reference either way", () => {
  assert.equal(normalizeReference("US-12"), null) // too few digits
  assert.equal(normalizeReference("US12"), null) // too few digits, no dash
  assert.equal(normalizeReference("Yellowstone"), null)
  assert.equal(normalizeReference(""), null)
})

test("transformsForPrefix reformats a bare number and a run-on prefix as the user types", () => {
  const transforms = transformsForPrefix("US")
  assert.equal(applyTransforms("1234", transforms), "US-1234")
  assert.equal(applyTransforms("US1234", transforms), "US-1234")
  assert.equal(applyTransforms("us1234", transforms), "us-1234") // casing untouched — normalized at submit time
})

test("transformsForPrefix continues a second reference with the same prefix after a comma", () => {
  const transforms = transformsForPrefix("US")
  // Realistic keystroke-by-keystroke sequence: the trailing "," triggers the
  // auto-inserted "US-" for the next entry before any of its digits exist.
  let acc = ""
  for (const ch of "US-1234,5678") {
    acc += ch
    acc = applyTransforms(acc, transforms)
  }
  assert.equal(acc, "US-1234,US-5678")
})

// Regression test for a real bug: a DXCC entity prefix that itself starts
// with a digit (Fiji is "3D2", Israel is "4X", Cyprus is "5B", Singapore is
// "9V") corrupted the live-reformatted text once braced group placeholders
// weren't used — a bare "$1" immediately followed by "3" misparsed as
// capture group 13 in the native (Dart) consumer.
test("transformsForPrefix stays correct when the prefix itself starts with a digit", () => {
  const transforms = transformsForPrefix("3D2")
  assert.equal(applyTransforms("1234", transforms), "3D2-1234")

  const transformsIsrael = transformsForPrefix("4X")
  assert.equal(applyTransforms("5678", transformsIsrael), "4X-5678")
})

// Regression test for a real bug: an earlier version of transformsForPrefix
// had a rule that eagerly inserted the next reference's prefix ("US-") the
// instant a trailing comma appeared, even with no digits typed yet after
// it. That made it impossible to delete back through a second reference —
// backspacing "US-1234,US-5678" down to "US-1234,US-" and further would
// immediately regrow the "US-" the transform had just reinserted, so the
// comma could never be reached. Continuation after a comma now only
// happens once 2+ digits appear, same as at the start of the field.
test("deleting back through a second reference does not regrow its prefix", () => {
  const transforms = transformsForPrefix("US")
  const sequence = [
    "US-1234,US-5678",
    "US-1234,US-567",
    "US-1234,US-56",
    "US-1234,US-5",
    "US-1234,US-",
    "US-1234,US",
    "US-1234,U",
    "US-1234,",
  ]
  for (const text of sequence) {
    assert.equal(applyTransforms(text, transforms), text)
  }
})

// POTA's park prefix follows the real-world country, not the DXCC "entity"
// a callsign's own ham-radio prefix maps to — these diverge for exactly
// the entities POTA itself folds into one country.
test("potaCountryPrefixForCall uses POTA's country code, not the DXCC entity prefix", () => {
  assert.equal(potaCountryPrefixForCall("W1AW"), "US") // DXCC entity prefix is "K", POTA uses "US"
  assert.equal(potaCountryPrefixForCall("KH6ABC"), "US") // Hawaii is its own DXCC entity ("KH6") but a US POTA park
  assert.equal(potaCountryPrefixForCall("VE3ABC"), "CA") // DXCC entity prefix is "VE", POTA uses "CA"
  assert.equal(potaCountryPrefixForCall("EA3ABC"), "ES") // DXCC entity prefix is "EA", POTA uses "ES"
  assert.equal(potaCountryPrefixForCall("VK2ABC"), "AU")
  assert.equal(potaCountryPrefixForCall(undefined), undefined)
})

test("hunterDefaultPrefix prefers the other station's country, falls back to our own, then to US", () => {
  assert.equal(
    hunterDefaultPrefix({ stationCall: "W1AW" }, { their: { call: "VE3ABC" } }),
    "CA",
  )
  assert.equal(
    hunterDefaultPrefix({ stationCall: "KH6ABC" }, undefined),
    "US", // resolves from our own station call when the other one is unknown
  )
  assert.equal(
    hunterDefaultPrefix({}, undefined),
    "US", // final fallback when nothing resolves
  )
})

test("activationDefaultPrefix always uses our own station's country", () => {
  assert.equal(activationDefaultPrefix({ stationCall: "VE3ABC" }), "CA")
  assert.equal(activationDefaultPrefix({ stationCall: "KH6ABC" }), "US")
  assert.equal(activationDefaultPrefix({}), "US")
})

test("suggestOperationTitleForPota suggests the park reference as 'at' and the park's decorated name as subtitle (ham2k/halo-dist#174)", () => {
  const suggestion = suggestOperationTitleForPota(
    { type: "potaActivation", ref: "US-0757", name: "Golden Gate NRA" },
    "potaActivation",
  )
  assert.deepEqual(suggestion, { at: "US-0757", subtitle: "Golden Gate NRA" })
})

test("suggestOperationTitleForPota returns null for a hunting ref — that's a station worked, not where this operation is", () => {
  const suggestion = suggestOperationTitleForPota(
    { type: "pota", ref: "US-0757", name: "Golden Gate NRA" },
    "potaActivation",
  )
  assert.equal(suggestion, null)
})

test("suggestOperationTitleForPota returns null for an activation ref with no reference code yet", () => {
  const suggestion = suggestOperationTitleForPota({ type: "potaActivation" }, "potaActivation")
  assert.equal(suggestion, null)
})

// isTestOperation itself (K-TEST substitution's gate) is shared and tested
// once in sdk/src/testOperation.test.ts.

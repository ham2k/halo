// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { REFERENCE_REGEX, TRANSFORMS } from "./refFormatting.ts"
import { suggestOperationTitleForSota } from "./titleSuggestion.ts"
import { oauthErrorCode } from "./oauthErrors.ts"

// Mirrors the group-expansion logic in
// `packages/halo_widgets/lib/src/ref_text_input.dart`'s
// `_RefTransformFormatter._applyOnce`/`expand` — braced `${1}`/`${2}`/`${3}`…
// placeholders, applied twice for convergence on a multi-character paste.
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

test("REFERENCE_REGEX accepts a well-formed summit reference and rejects garbage", () => {
  assert.equal(REFERENCE_REGEX.test("W6/SD-026"), true)
  assert.equal(REFERENCE_REGEX.test("w6/sd-026"), true) // case-insensitive
  assert.equal(REFERENCE_REGEX.test("HB9/BE-123"), true)
  assert.equal(REFERENCE_REGEX.test("W6SD026"), false) // missing slash and dash
  assert.equal(REFERENCE_REGEX.test("W6/SD-12"), false) // too few digits
  assert.equal(REFERENCE_REGEX.test("not a ref"), false)
})

test("TRANSFORMS inserts the slash and dash as the user types", () => {
  assert.equal(applyTransforms("w6sd026", TRANSFORMS), "w6/sd-026")
  assert.equal(applyTransforms("W6/SD026", TRANSFORMS), "W6/SD-026")
  assert.equal(applyTransforms("W6SD-026", TRANSFORMS), "W6/SD-026")
})

test("TRANSFORMS separates two space-typed summits with a comma", () => {
  assert.equal(applyTransforms("w6sd026 w6sd027", TRANSFORMS), "w6/sd-026, w6/sd-027")
})

test("TRANSFORMS leaves an already comma-separated multi-summit list untouched", () => {
  assert.equal(applyTransforms("W6/SD-026,W6/SD-027", TRANSFORMS), "W6/SD-026,W6/SD-027")
})

test("suggestOperationTitleForSota suggests the summit reference as 'at' and the summit's decorated name as subtitle (ham2k/halo-dist#174)", () => {
  const suggestion = suggestOperationTitleForSota(
    { type: "sotaActivation", ref: "W6/SD-123", name: "Mount Example" },
    "sotaActivation",
  )
  assert.deepEqual(suggestion, { at: "W6/SD-123", subtitle: "Mount Example" })
})

test("suggestOperationTitleForSota returns null for a hunting ref — that's a station worked, not where this operation is", () => {
  const suggestion = suggestOperationTitleForSota(
    { type: "sota", ref: "W6/SD-123", name: "Mount Example" },
    "sotaActivation",
  )
  assert.equal(suggestion, null)
})

test("suggestOperationTitleForSota returns null for an activation ref with no reference code yet", () => {
  const suggestion = suggestOperationTitleForSota({ type: "sotaActivation" }, "sotaActivation")
  assert.equal(suggestion, null)
})

// `oauthErrorCode` is what stands between a failed refresh and signing the
// operator out: only a body that identifies itself as an OAuth rejection lets
// `refreshTokens` clear the stored session. On web that request goes through
// Ham2K's CORS proxy, so the status alone cannot say who refused — a hop that
// is merely misconfigured must not read as a revoked token.
test("oauthErrorCode names a provider's own rejection", () => {
  assert.equal(oauthErrorCode('{"error":"invalid_grant","error_description":"Token is not active"}'), 'invalid_grant')
  assert.equal(oauthErrorCode('{"error":"invalid_client"}'), 'invalid_client')
})

test("oauthErrorCode refuses anything that did not come from the provider", () => {
  // Each of these is a real thing that can answer on that URL once a proxy
  // hop exists. Treating any of them as a rejection wipes an account whose
  // tokens are fine, and the operator is told to reconnect for no reason.
  for (const body of [
    '<!DOCTYPE html><html><body>Not found</body></html>', // the Worker's own 404 page
    'error code: 1015', // a Cloudflare edge rate limit
    'Not found', // the Worker's plain-text miss
    '', // no body at all
    '{}', // JSON, but not an OAuth error
    '{"error":""}', // present but empty — nothing to act on
    '{"error":123}', // wrong type
    'null',
  ]) {
    assert.equal(oauthErrorCode(body), null, `should not read as a rejection: ${body}`)
  }
})

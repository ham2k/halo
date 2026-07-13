// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { REFERENCE_REGEX, TRANSFORMS } from "./refFormatting.ts"

// Mirrors the group-expansion logic in
// `packages/halo_widgets/lib/src/ref_chips_input.dart`'s
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

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT

import { test } from "node:test"
import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"

import { API_VERSION } from "@ham2k/extension-sdk"
// @ts-ignore — plain JS, published as is (see tools/h2kext.test.ts).
import { H2KEXT_API_VERSION } from "../../tools/h2kext.mjs"

const versionOf = async (pkg: string) => JSON.parse(await readFile(new URL(`../../${pkg}/package.json`, import.meta.url), "utf8")).version as string

// An API bump that misses the SDK leaves authors reading types for an API the
// packer refuses, or the other way round.
test("the SDK describes the API the packer knows", () => {
  assert.equal(API_VERSION, H2KEXT_API_VERSION)
})

// Extensions declare `^<major>.<api>.0`: a minor behind the API reads as an
// older API than the package knows, and a release cut without the bump is
// admitted by every range as if it added nothing. Under a 0.x major a caret
// admits no later minor, and every API bump becomes a range edit in every
// extension.
for (const pkg of ["sdk", "tools"]) {
  test(`${pkg}'s minor version is the extension API`, async () => {
    const [major, minor] = (await versionOf(pkg)).split(".").map(Number)
    assert.ok(major! >= 1, `major ${major}`)
    assert.equal(minor, API_VERSION)
  })
}

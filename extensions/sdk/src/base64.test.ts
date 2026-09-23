// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Checked against Node's own encoder: a codec that round-trips with itself can
// still disagree with the host's `dart:convert`, which is what it talks to.

import { describe, it } from "node:test"
import assert from "node:assert/strict"

import { base64ToBytes, bytesToBase64 } from "./base64.ts"

describe("base64", () => {
  it("encodes and decodes as a standard encoder does, at every padding length", () => {
    for (let length = 0; length <= 9; length++) {
      const bytes = Uint8Array.from({ length }, (_, i) => (i * 97 + 255) & 255)
      const reference = Buffer.from(bytes).toString("base64")
      assert.equal(bytesToBase64(bytes), reference, `length ${length}`)
      assert.deepEqual(base64ToBytes(reference), bytes, `length ${length}`)
    }
  })

  it("refuses what is not base64 rather than decoding it to something else", () => {
    for (const bad of ["abc", "ab!d", "=abc", "a=bc", "ab=c"]) {
      assert.throws(() => base64ToBytes(bad), /invalid base64/, bad)
    }
  })
})

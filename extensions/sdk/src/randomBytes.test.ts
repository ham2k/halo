// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// `host.randomBytes` — what only the SDK wrapper decides: the bytes come back
// as a Uint8Array of the length asked for, and a bad length throws at the
// caller without reaching the host. The host's own refusals, and that it
// never falls back to a weaker source, are tested in
// packages/halo_extension_host/test/random_bytes_test.dart.

import { describe, it, beforeEach } from "node:test"
import assert from "node:assert/strict"

let calls: { method: string; params: Record<string, unknown> }[]
let answer: ((length: number) => unknown) | null
;(globalThis as Record<string, unknown>).__halo = {
  hostCall(method: string, params: Record<string, unknown>) {
    calls.push({ method, params })
    // What the host answers: Base64 of `length` bytes, here 00 01 02 … so a
    // decode that drops or reorders a byte shows.
    const length = params.length as number
    if (answer) return Promise.resolve(answer(length))
    return Promise.resolve(Buffer.from(Array.from({ length }, (_, i) => i % 256)).toString("base64"))
  },
}

const { host } = await import("./index.ts")

describe("host.randomBytes", () => {
  beforeEach(() => {
    calls = []
    answer = null
  })

  it("answers a Uint8Array of exactly the bytes the host sent", async () => {
    for (const length of [1, 3, 4096]) {
      const bytes = await host.randomBytes(length)
      assert.ok(bytes instanceof Uint8Array)
      assert.deepEqual(
        Array.from(bytes),
        Array.from({ length }, (_, i) => i % 256),
      )
    }
    assert.deepEqual(
      calls.map((c) => c.params.length),
      [1, 3, 4096],
    )
  })

  it("throws for a length the host would refuse, before calling it", async () => {
    for (const length of [0, -1, 4097, 1.5, Number.NaN, "16" as unknown as number]) {
      await assert.rejects(host.randomBytes(length), RangeError, String(length))
    }
    assert.equal(calls.length, 0)
  })

  it("rejects an answer that is not exactly the bytes asked for", async () => {
    // A signer handed fewer bytes than it asked for, or none, blinds with
    // whatever it had: the wrapper is the last place that can tell. A null
    // is what a test stand-in host answers for a call it does not know.
    const short = (length: number) => Buffer.alloc(length - 1).toString("base64")
    for (const wrong of [() => "", short, () => null, () => 32]) {
      answer = wrong
      await assert.rejects(host.randomBytes(32), /randomBytes asked for 32 bytes/)
    }
  })
})

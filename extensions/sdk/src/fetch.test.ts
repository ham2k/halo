// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// `host.fetch` — what only the SDK wrapper decides: how a byte body crosses
// the JSON bridge, and what it refuses before calling the host. The host's own
// refusals and the bytes it sends are tested through the HTTP seam in
// packages/halo_extension_host/test/host_limits_test.dart.

import { describe, it, beforeEach } from "node:test"
import assert from "node:assert/strict"

let calls: { method: string; params: Record<string, unknown> }[]
;(globalThis as Record<string, unknown>).__halo = {
  hostCall(method: string, params: Record<string, unknown>) {
    calls.push({ method, params })
    return Promise.resolve({ status: 200, body: "ok" })
  },
}

const { host } = await import("./index.ts")

describe("host.fetch", () => {
  beforeEach(() => {
    calls = []
  })

  it("sends only a subarray's own bytes, not the rest of its buffer", async () => {
    // A multipart body is built in one buffer and the file part handed on as
    // a subarray; encoding the whole buffer would upload the envelope twice.
    const buffer = Uint8Array.from([0xaa, 0x1f, 0x8b, 0x00, 0xff, 0xbb])
    await host.fetch("https://a.example/upload", { method: "POST", body: buffer.subarray(1, 5) })

    const { method, params } = calls[0]!
    assert.equal(method, "fetchStrict", "an app before API 29 would send a plain fetch with no body")
    assert.equal(params.bodyBase64, Buffer.from([0x1f, 0x8b, 0x00, 0xff]).toString("base64"))
    assert.equal("body" in params, false, "the host refuses a call carrying both")
    assert.equal(params.method, "POST")
  })

  it("sends a string body as it always has, and as fetchStrict once it refuses redirects", async () => {
    await host.fetch("https://a.example/form", { method: "POST", body: "a=1" })
    await host.fetch("https://a.example/form", { method: "POST", body: "a=1", redirect: "error" })
    // A null body was always no body.
    await host.fetch("https://a.example/form", { body: null as unknown as string })
    assert.deepEqual(
      calls.map(({ method, params }) => [method, params]),
      [
        ["fetch", { url: "https://a.example/form", method: "POST", body: "a=1" }],
        ["fetchStrict", { url: "https://a.example/form", method: "POST", body: "a=1", redirect: "error" }],
        ["fetch", { url: "https://a.example/form", body: null }],
      ],
    )
  })

  it("refuses a bad redirect setting, a body that is neither, or one past 16 MiB, before calling the host", async () => {
    await assert.rejects(host.fetch("https://a.example", { redirect: "manual" as "error" }), TypeError)
    await assert.rejects(host.fetch("https://a.example", { body: [1, 2, 3] as unknown as Uint8Array }), TypeError)
    await assert.rejects(host.fetch("https://a.example", { body: new Uint8Array(16 * 1024 * 1024 + 1) }), RangeError)
    // By UTF-8 bytes: each é is two.
    await assert.rejects(host.fetch("https://a.example", { body: "é".repeat(8 * 1024 * 1024 + 1) }), RangeError)
    assert.equal(calls.length, 0)
  })
})

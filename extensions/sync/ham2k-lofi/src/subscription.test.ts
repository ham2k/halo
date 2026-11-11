// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Handing a store purchase to the account. The mutations to catch: posting to
// an account other than the one this device belongs to (the plan would land
// on a stranger's account), a body shape the server's strong params drop (the
// purchase silently never attaches), and a refusal — the purchase already
// belongs to another account — escaping as a transport failure, which the
// operator would read as "server unreachable" about a server that answered.

import { test } from "node:test"
import assert from "node:assert/strict"

import { loadExtension } from "../../../sdk/src/testing.ts"

const kv: Record<string, unknown> = { key: "device-key-1", token: "session-token" }
const posts: { url: string; body: unknown }[] = []
let nextStatus = 200
let nextBody = JSON.stringify({ subscription: { id: 7 } })

const lofi = await loadExtension(() => import("./index.ts"), {
  hostCalls: {
    kvGet: ({ key }) => kv[key as string] ?? null,
    kvSet: ({ key, value }) => {
      kv[key as string] = value
      return null
    },
    fetch: ({ url, method, body }) => {
      if (String(url).endsWith("/v1/accounts") && method === "GET") {
        return { status: 200, body: JSON.stringify({ current_account: { uuid: "acct-1" } }) }
      }
      if (method === "POST") {
        posts.push({ url: String(url), body: JSON.parse(String(body)) })
        return { status: nextStatus, body: nextBody }
      }
      return { status: 404, body: "{}" }
    },
  },
})

test("a purchase is posted to this device's own account, in the shape the server accepts", async () => {
  await lofi.runHook("syncTransport", "createSubscription", { channel_reference: "rc:lofi_2025:acct-1" })
  const post = posts[posts.length - 1]
  assert.ok(post.url.endsWith("/v1/accounts/acct-1/subscriptions"), post.url)
  assert.deepEqual(post.body, { subscription: { channel_reference: "rc:lofi_2025:acct-1" } })
})

test("a purchase owned by another account comes back as data, not a thrown failure", async () => {
  nextStatus = 406
  nextBody = JSON.stringify({ error: "Subscription belongs to a different account" })
  const result = (await lofi.runHook("syncTransport", "createSubscription", { channel_reference: "rc:lofi_2025:acct-9" })) as Record<string, unknown>
  assert.equal(result.error_status, 406)
  assert.match(String(result.error), /different account/)
})

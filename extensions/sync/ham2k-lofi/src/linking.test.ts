// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Who asks the server to mail a linking confirmation. The server mails one
// for every pending permission unless the request opts out, so the mutation
// to catch is `linkClient` dropping `send_email: false`: the code view then
// arrives alongside an email nobody asked for, the "send a confirmation
// email instead" button sends a second, and every renewal on expiry sends
// another.

import { test } from "node:test"
import assert from "node:assert/strict"

import { loadExtension } from "../../../sdk/src/testing.ts"

const kv: Record<string, unknown> = { key: "device-key-1", token: "session-token" }
const permissionPosts: Record<string, unknown>[] = []

// `.at(-1)` is past this package's tsc lib target.
const lastPost = () => permissionPosts[permissionPosts.length - 1]

let nextStatus = 200
let nextBody = JSON.stringify({ permission: { status: "pending", challenge_token: "123456" } })

const lofi = await loadExtension(() => import("./index.ts"), {
  hostCalls: {
    kvGet: ({ key }) => kv[key as string] ?? null,
    kvSet: ({ key, value }) => {
      kv[key as string] = value
      return null
    },
    fetch: ({ url, method, body }) => {
      if (String(url).endsWith("/v1/client/permissions") && method === "POST") {
        permissionPosts.push(JSON.parse(String(body)))
        return { status: nextStatus, body: nextBody }
      }
      return { status: 404, body: "{}" }
    },
  },
})

test("a link request that shows the code on screen tells the server not to mail", async () => {
  await lofi.runHook("syncTransport", "linkClient", { email: "ham@example.com" })
  assert.deepEqual(lastPost(), { email: "ham@example.com", send_email: false })
})

test("only the operator asking for the email makes the server mail one", async () => {
  await lofi.runHook("syncTransport", "linkClientWithEmail", { email: "ham@example.com" })
  assert.deepEqual(lastPost(), { email: "ham@example.com", send_email: true })
})

test("a QR request carries no address, so there is nobody to mail", async () => {
  await lofi.runHook("syncTransport", "linkClient", {})
  assert.deepEqual(lastPost(), {})
})

// Both linking calls report a rejection the operator can act on as data. A
// throw here reaches the dialog as "could not reach the server", about a
// server that answered and said why.
test("a rejected request for the email comes back as data, not as a throw", async () => {
  nextStatus = 429
  nextBody = JSON.stringify({ error: "Too many requests" })
  try {
    const result = await lofi.runHook("syncTransport", "linkClientWithEmail", { email: "ham@example.com" })
    assert.equal((result as Record<string, unknown>).error_status, 429)
    assert.match(String((result as Record<string, unknown>).error), /Too many requests/)
  } finally {
    nextStatus = 200
    nextBody = JSON.stringify({ permission: { status: "pending", challenge_token: "123456" } })
  }
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What this device tells the server it is, at registration. The name is
// what another Ham2K app shows when asked to approve a link request for
// this device ("link <name> with this account?"), so it has to be the app's
// own name, seeded by the app — the sandbox knows neither platform nor
// edition. The mutation to catch is a hard-coded name that ignores the seed.

import { test } from "node:test"
import assert from "node:assert/strict"

import { loadExtension } from "../../../sdk/src/testing.ts"

const kv: Record<string, unknown> = {
  key: "device-key-1",
  clientName: "Ham2K Portable Logger (Dev Edition)",
}
const posted: Record<string, unknown>[] = []

const lofi = await loadExtension(() => import("./index.ts"), {
  hostCalls: {
    kvGet: ({ key }) => kv[key as string] ?? null,
    kvSet: ({ key, value }) => {
      kv[key as string] = value
      return null
    },
    fetch: ({ url, method, body }) => {
      if (String(url).endsWith("/v1/client") && method === "POST") {
        posted.push(JSON.parse(String(body)))
        return {
          status: 200,
          body: JSON.stringify({
            token: "session-token",
            client: { uuid: "client-1", push_channel: "ch-1", webhook_client_token: "wh-1" },
          }),
        }
      }
      return { status: 404, body: "{}" }
    },
  },
})

test("registration sends the app's own name, as seeded by the app", async () => {
  await lofi.runHook("syncTransport", "ensureClientRegistered", {})
  assert.equal(posted.length, 1)
  const client = posted[0].client as Record<string, unknown>
  assert.equal(client.name, "Ham2K Portable Logger (Dev Edition)")
  assert.equal(client.key, "device-key-1")
})

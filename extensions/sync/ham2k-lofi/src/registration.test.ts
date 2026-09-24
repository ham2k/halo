// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What this device tells the server it is, at registration. The name is
// what another Ham2K app shows when asked to approve a link request for
// this device ("link <name> with this account?"), so it has to be the name
// the app seeds — the sandbox can read neither the device's name nor the
// app's edition. The mutation to catch is a hard-coded name that ignores the
// seed. The seeded diagnostics are how the server's device list tells HaLo
// rows from PoLo ones; dropping them, or letting them replace the sync
// engine's own meta (its paging cursors), is the other mutation.

import { test } from "node:test"
import assert from "node:assert/strict"

import { loadExtension } from "../../../sdk/src/testing.ts"

const kv: Record<string, unknown> = {
  key: "device-key-1",
  clientName: "Ham2K Portable Logger (Dev Edition)",
  diagnostics: { device: "samsung | kalama | Michael's S23", appVersion: "halo 26.9.0 (android next 171)" },
}
const posted: Record<string, unknown>[] = []
const synced: Record<string, unknown>[] = []

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
      if (String(url).endsWith("/v1/sync") && method === "POST") {
        synced.push(JSON.parse(String(body)))
        return { status: 200, body: JSON.stringify({ success: true, meta: {} }) }
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

test("sync carries the seeded diagnostics beside the engine's own meta", async () => {
  await lofi.runHook("syncTransport", "sync", { qsos: [], meta: { qsos: { synced_until_millis: 42 } } })
  assert.equal(synced.length, 1)
  const meta = synced[0].meta as Record<string, unknown>
  assert.deepEqual(meta.diagnostics, kv.diagnostics)
  assert.deepEqual(meta.qsos, { synced_until_millis: 42 })
})

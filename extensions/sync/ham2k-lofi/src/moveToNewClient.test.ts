// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Moving a device onto a client of its own without leaving its account. The
// traps: the approval must come from the CURRENT client, the only one with a
// say over the account; the device must not become the new client until that
// approval has gone through, or a failure strands it on the new client's own
// empty account; and nothing still on the wire for the old client may take
// the device back after the switch.

import { test } from "node:test"
import assert from "node:assert/strict"

import { loadExtension } from "../../../sdk/src/testing.ts"

const kv: Record<string, unknown> = {}
const approvals: { bearer: string; path: string; body: Record<string, unknown> }[] = []
let approvalStatus = 200
/// Tokens the server no longer accepts: a request carrying one is answered 401.
const revoked = new Set<string>()
/// When set, the approval / a registration under that key waits on it.
let holdApproval: Promise<void> | null = null
const holdRegistration: Record<string, Promise<void>> = {}
let registrations = 0

const bearer = (headers: unknown) => String((headers as Record<string, string> | undefined)?.Authorization ?? "").replace("Bearer ", "")

function deferred() {
  let release = () => {}
  const promise = new Promise<void>((resolve) => (release = resolve))
  return { promise, release }
}

const lofi = await loadExtension(() => import("./index.ts"), {
  hostCalls: {
    kvGet: ({ key }) => kv[key as string] ?? null,
    kvSet: ({ key, value }) => {
      kv[key as string] = value
      return null
    },
    fetch: async ({ url, method, headers, body }) => {
      const path = new URL(String(url)).pathname
      const json = body ? JSON.parse(String(body)) : {}
      if (path === "/v1/client" && method === "POST") {
        const key = json.client.key as string
        await holdRegistration[key]
        registrations++
        // A fresh token on every registration, as the server mints one.
        return { status: 200, body: JSON.stringify({ token: `token-${registrations}-for-${key}`, client: { uuid: `client-for-${key}` } }) }
      }
      if (revoked.has(bearer(headers))) return { status: 401, body: "{}" }
      if (path === "/v1/client/permissions" && method === "POST") {
        return { status: 200, body: JSON.stringify({ permission: { status: "pending", challenge_token: `code-for-${bearer(headers)}` } }) }
      }
      if (path === "/v1/accounts" && method === "GET") {
        // The account a client is on: the old one for the old client's
        // tokens, a fresh one for any other.
        const token = bearer(headers)
        const uuid = token.endsWith("-for-old-key") ? "acct-1" : `acct-of-${token}`
        return { status: 200, body: JSON.stringify({ current_account: { uuid } }) }
      }
      if (path.startsWith("/v1/accounts/") && method === "PATCH") {
        approvals.push({ bearer: bearer(headers), path, body: json })
        await holdApproval
        return {
          status: approvalStatus,
          body: approvalStatus === 200 ? JSON.stringify({ permission: { status: "active" } }) : JSON.stringify({ error: "Forbidden" }),
        }
      }
      return { status: 404, body: "{}" }
    },
  },
})

function resetToOldClient() {
  for (const key of Object.keys(kv)) delete kv[key]
  Object.assign(kv, { key: "old-key", token: "token-0-for-old-key" })
  approvals.length = 0
  approvalStatus = 200
}

const accountOf = async (): Promise<string> => {
  const data = (await lofi.runHook("syncTransport", "getAccountData", {})) as Record<string, Record<string, unknown>>
  return String(data.current_account.uuid)
}
const tick = () => new Promise((resolve) => setImmediate(resolve))

// The refusal first: the extension keeps its token in module state, which
// only a successful move changes, so after one the device IS the new client.
test("a refused approval leaves the device as the client it was", async () => {
  resetToOldClient()
  approvalStatus = 403

  const result = (await lofi.runHook("syncTransport", "moveToNewClient", { key: "new-key" })) as Record<string, unknown>

  assert.equal(result.error_status, 403)
  assert.equal(kv.key, "old-key")
  assert.equal(kv.token, "token-0-for-old-key")
  assert.equal(await accountOf(), "acct-1")
})

test("the current client approves the new one onto its own account, and the device then speaks as the new one", async () => {
  resetToOldClient()

  const result = await lofi.runHook("syncTransport", "moveToNewClient", { key: "new-key" })

  assert.deepEqual(result, { client: "client-for-new-key", account: "acct-1" })
  assert.equal(approvals.length, 1)
  assert.equal(approvals[0].bearer, "token-0-for-old-key")
  assert.equal(approvals[0].path, "/v1/accounts/acct-1/permissions/client-for-new-key")
  assert.deepEqual(approvals[0].body, { permission: { status: "active" }, challenge_token: `code-for-${kv.token}` })
  assert.equal(kv.key, "new-key")
  assert.match(String(kv.token), /-for-new-key$/)
  assert.match(await accountOf(), /-for-new-key$/, "the next request goes as the new client")
})

// Another call's request is refused while the approval is on the wire, and
// re-registers under the current key. That registration lands last; if it is
// allowed to, the device speaks as the old client again under the new key.
test("a registration still on the wire for the current client lands before the switch, not after it", async () => {
  // From the previous test, the device is the "new-key" client; it moves on.
  approvals.length = 0
  const approval = deferred()
  const registration = deferred()
  holdApproval = approval.promise
  holdRegistration["new-key"] = registration.promise

  const moving = lofi.runHook("syncTransport", "moveToNewClient", { key: "newer-key" })
  while (approvals.length === 0) await tick()
  revoked.add(approvals[0].bearer)
  const refused = lofi.runHook("syncTransport", "getAccountData", {})
  await tick()
  approval.release()
  await tick()
  registration.release()
  await moving
  await refused
  holdApproval = null
  delete holdRegistration["new-key"]

  assert.equal(kv.key, "newer-key")
  assert.match(String(kv.token), /-for-newer-key$/)
  assert.match(await accountOf(), /-for-newer-key$/)
})

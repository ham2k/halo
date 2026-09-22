// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What may be written over a cached client identity. The stakes are uneven:
// `push_channel` is what the realtime subscription rides on, and
// `webhook_client_token` is what an OAuth `state` carries — writing a
// non-string over either would put a wrong value on a path whose failure is
// silent (a channel nobody publishes to; a relay login the receiver refuses).

import assert from "node:assert/strict"
import { describe, it } from "node:test"

import { clientIdentityFrom, requireWebhookIdentity } from "./clientIdentity.ts"

describe("clientIdentityFrom", () => {
  it("reads both fields off a real client payload", () => {
    assert.deepEqual(
      clientIdentityFrom({
        uuid: "abc",
        name: "a device",
        push_channel: "client-abcdef12-0123456789abcdef",
        webhook_client_token: "signed--token",
      }),
      { pushChannelName: "client-abcdef12-0123456789abcdef", webhookClientToken: "signed--token" },
    )
  })

  it("leaves a field undefined rather than coercing a non-string", () => {
    // undefined means "keep what you had". A coerced value would overwrite a
    // working cached identity with something like "null" or "[object Object]".
    for (const bad of [null, 42, true, {}, [], undefined]) {
      const identity = clientIdentityFrom({ push_channel: bad, webhook_client_token: bad })
      assert.equal(identity.pushChannelName, undefined, `push_channel: ${JSON.stringify(bad)}`)
      assert.equal(identity.webhookClientToken, undefined, `token: ${JSON.stringify(bad)}`)
    }
  })

  it("takes each field on its own merits", () => {
    // A server that sends one and omits the other must not cost us the one it
    // did send.
    assert.deepEqual(clientIdentityFrom({ push_channel: "chan" }), {
      pushChannelName: "chan",
      webhookClientToken: undefined,
    })
    assert.deepEqual(clientIdentityFrom({ webhook_client_token: "tok" }), {
      pushChannelName: undefined,
      webhookClientToken: "tok",
    })
  })

  it("answers empty for anything that is not a payload at all", () => {
    for (const notAPayload of [undefined, null, "a string", 7, true]) {
      assert.deepEqual(clientIdentityFrom(notAPayload), {})
    }
  })
})

describe("requireWebhookIdentity", () => {
  const ok = { client: { push_channel: "chan", webhook_client_token: "signed--token" } }

  it("returns the token when the refresh really carried one", () => {
    assert.equal(requireWebhookIdentity(ok).webhookClientToken, "signed--token")
    assert.equal(requireWebhookIdentity(ok).pushChannelName, "chan")
  })

  it("throws rather than letting the caller keep its stale token", () => {
    // Every one of these is a 2xx that refreshed NOTHING. Returning here
    // instead of throwing means the caller falls back to its hour-old token,
    // sends it in an OAuth `state`, and the relay refuses the login with a
    // message the operator cannot act on — the exact bug a refresh exists to
    // prevent, now wearing a successful response.
    for (const body of [
      {}, // no `client` key
      { client: null },
      { client: {} }, // client, no token
      { client: { push_channel: "chan" } }, // the other field only
      { status: "ok" }, // a maintenance page that parses
      [], // valid JSON, wrong shape
      "a string",
      null,
      undefined,
    ]) {
      assert.throws(() => requireWebhookIdentity(body), /webhook token/, `should throw: ${JSON.stringify(body)}`)
    }
  })

  it("treats an empty-string token as no token at all", () => {
    // The one value that is a `string` and still useless: it passes a
    // `typeof` check and survives `??`, so nothing downstream would catch it,
    // and it reaches the relay identifying no client.
    assert.throws(() => requireWebhookIdentity({ client: { webhook_client_token: "" } }), /webhook token/)
  })
})

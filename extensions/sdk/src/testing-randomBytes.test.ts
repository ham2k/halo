// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The harness answers `host.randomBytes`. The SDK rejects a null answer, which
// is what the stand-in gives a call it does not know: without this, a
// signer's own tests fail on a call that works in the app.

import { it } from "node:test"
import assert from "node:assert/strict"

import { defineExtension, host } from "./index.ts"
import { loadExtension } from "./testing.ts"

it("loadExtension answers host.randomBytes with the bytes asked for, as the app does", async () => {
  const ext = await loadExtension(async () => {
    defineExtension({
      key: "entropy-test",
      name: "Entropy",
      version: "0.0.1",
      onActivation(api) {
        api.registerHook("bench", { hook: { draw: async () => Array.from(await host.randomBytes(3)) } })
      },
    })
    return {}
  })
  assert.deepEqual(await ext.runHook("bench", "draw"), [0, 1, 2])
})

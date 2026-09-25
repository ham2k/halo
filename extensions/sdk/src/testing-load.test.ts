// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// A timer set while an extension's module loads — a library scheduling work
// at import time — gets an id that never fires, and the work silently never
// happens. The harness has to say so. In a file of its own because the SDK
// module, and what it remembers about activation, is one per process.

import { it } from "node:test"
import assert from "node:assert/strict"

import { defineExtension, host } from "./index.ts"
import { loadExtension } from "./testing.ts"

it("fails loadExtension when a timer is ignored while the extension loads", async () => {
  await assert.rejects(
    loadExtension(async () => {
      host.setTimeout(() => {}, 0)
      defineExtension({ key: "timers-load-test", name: "Timers", version: "0.0.1", onActivation() {} })
      return {}
    }),
    /a timer was ignored: set before the extension activated/,
  )
})

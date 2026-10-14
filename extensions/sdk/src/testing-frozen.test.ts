// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The harness hands an extension the log the way the app does: frozen from
// API 9. The trap is a harness that hands it over writable, so an extension
// that writes to a QSO passes its own tests and throws inside the app.

import { test } from "node:test"
import assert from "node:assert/strict"

import { defineExtension } from "./index.ts"
import { fixtureQso, loadExtension } from "./testing.ts"
import type { HookContext, JSONValue } from "./types.ts"

/// An extension that marks the first QSO it reads, and says whether it could.
const marking = async () => {
  defineExtension({
    key: "frozen-harness-test",
    name: "Marks QSOs",
    version: "0.0.1",
    onActivation({ registerHook }) {
      registerHook("bench", {
        hook: {
          async mark(args: { operationUuid: string }, ctx: HookContext) {
            const log = (await ctx.getQsos!(args.operationUuid))!
            log[0].notes = "marked"
            return log[0].notes
          },
        },
      })
      registerHook("scoring", {
        hook: {
          async scoreQsos(args: { qsos: Record<string, JSONValue>[] }) {
            args.qsos[0].notes = "marked"
            return args.qsos[0].notes
          },
        },
      })
    },
  })
  return {}
}

const log = [fixtureQso()]
const ctx = { getQsos: async () => log }

test("an extension at API 9 gets frozen QSOs from getQsos, and a write throws as it would in the app", async () => {
  const extension = await loadExtension(marking, { api: 9, ctx })
  await assert.rejects(extension.runHook("bench", "mark", { operationUuid: "op" }), TypeError)
  assert.equal(log[0].notes, undefined, "the test's own fixture is never frozen or written")
})

test("an extension below API 9 may write to what it is handed, as it always could", async () => {
  const extension = await loadExtension(marking, { api: 8, ctx })
  assert.equal(await extension.runHook("bench", "mark", { operationUuid: "op" }), "marked")
})

test("a scorer's qsos are frozen too", async () => {
  const extension = await loadExtension(marking, { api: 9 })
  await assert.rejects(extension.runHook("scoring", "scoreQsos", { qsos: [fixtureQso()] }), TypeError)
})

test("with no `api` declared, the harness holds an extension to the level the app does", async () => {
  // The app installs a non-built-in that declares no `api` as API 0, and
  // hands it writable QSOs; only a built-in (no category) is at the app's own
  // level. A harness that froze both would fail tests the app would pass.
  const catalogExtension = async () => {
    defineExtension({
      key: "frozen-harness-test",
      name: "Marks QSOs",
      version: "0.0.1",
      category: "dashboard",
      onActivation({ registerHook }) {
        registerHook("bench", {
          hook: {
            async mark(_args: unknown, ctx: HookContext) {
              const log = (await ctx.getQsos!("op"))!
              log[0].notes = "marked"
              return log[0].notes
            },
          },
        })
      },
    })
    return {}
  }
  const extension = await loadExtension(catalogExtension, { ctx })
  assert.equal(await extension.runHook("bench", "mark"), "marked")
})

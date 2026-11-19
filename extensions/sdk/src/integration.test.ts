// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// An integration reached the way the runtime reaches it: registered under
// `integration`, listed by `getIntegrations`, called with `observe` and the
// contacts that changed, and speaking only through host calls. The sample
// tally is the integration, so the shape it teaches is the shape that runs.
// In a file of its own because the SDK module, and what it remembers about
// activation, is one per process.

import { test } from "node:test"
import assert from "node:assert/strict"

import { defineExtension } from "./index.ts"
import { loadExtension } from "./testing.ts"
import { SessionTally } from "../../samples/k2hrc-tally/src/tally.ts"

const now = 10 * 3_600_000

test("an integration counts what the app says changed, and starts over at open", async () => {
  const posted: Record<string, unknown>[] = []
  const cleared: Record<string, unknown>[] = []
  const ext = await loadExtension(
    async () => {
      defineExtension({
        key: "k2hrc-tally",
        name: "Session Tally",
        version: "1.0.0",
        onActivation({ registerHook }) {
          registerHook("integration", { hook: SessionTally })
        },
      })
      return {}
    },
    {
      hostCalls: {
        fyiPost: (params) => posted.push(params),
        fyiClear: (params) => cleared.push(params),
      },
      // Never read: the changes are handed over, and an integration that
      // re-read the whole log on every contact would cost what they save.
      ctx: {
        getQsos: async () => {
          throw new Error("the tally reads the changes it is handed, not the log")
        },
      },
    },
  )
  assert.deepEqual(ext.categories(), ["integration"])

  const [integration] = (await ext.runHook("integration", "getIntegrations", {})) as { key: string; on: string[] }[]
  assert.equal(integration?.key, "tally")
  assert.deepEqual(integration?.on, ["qsoLogged"])

  const observe = (reasons: string[], changes: { logged?: unknown[]; updated?: unknown[]; deleted?: string[] }, countEdits = false) =>
    ext.runHook("integration", "observe", {
      integrationKey: "tally",
      operation: { uuid: "op-1" },
      qsoCount: 0,
      config: { countEdits },
      reasons,
      clock: { nowMillis: now, realNowMillis: now },
      changes: { logged: [], updated: [], deleted: [], ...changes },
    })

  await observe(["open"], {})
  assert.equal(posted.length, 0, "nothing logged yet is nothing to say")

  await observe(["qsoLogged"], { logged: [{ uuid: "a" }, { uuid: "b" }] })
  await observe(["qsoLogged"], { logged: [{ uuid: "c" }], updated: [{ uuid: "a" }] })
  assert.equal(posted[posted.length - 1]?.text, "This session: 3 logged", "an edit is not a contact logged")
  assert.equal(posted[posted.length - 1]?.ns, "k2hrc-tally", "the post is namespaced to the integration's own extension")

  await observe(["qsoLogged"], { deleted: ["b"] }, true)
  assert.equal(posted[posted.length - 1]?.text, "This session: 3 logged, 1 edited, 1 deleted")

  // Switched off and on again, or the app restarted: the app says `open`, and
  // what came before is not this session's.
  const clearedBefore = cleared.length
  const postedBefore = posted.length
  await observe(["open"], {})
  assert.equal(posted.length, postedBefore)
  assert.equal(cleared.length, clearedBefore + 1, "a tally back at zero takes the line down")
  assert.equal(cleared[cleared.length - 1]?.key, "tally")
})

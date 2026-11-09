// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// An assistant reached the way the runtime reaches it: registered under
// `assistant`, listed by `getAssistants`, called with `observe`, and speaking
// only through host calls. The sample coach is the assistant, so the shape it
// teaches is the shape that runs. In a file of its own because the SDK module,
// and what it remembers about activation, is one per process.

import { test } from "node:test"
import assert from "node:assert/strict"

import { defineExtension } from "./index.ts"
import { loadExtension } from "./testing.ts"
import { RateCoach } from "../../samples/k2hrc-coach/src/coach.ts"

const now = 10 * 3_600_000

test("an assistant lists what it watches for and answers through the FYI line", async () => {
  const posted: Record<string, unknown>[] = []
  const cleared: Record<string, unknown>[] = []
  let qsos = [{ startAtMillis: now - 60_000 }]
  const ext = await loadExtension(
    async () => {
      defineExtension({
        key: "k2hrc-coach",
        name: "Rate Coach",
        version: "1.0.0",
        onActivation({ registerHook }) {
          registerHook("assistant", { hook: RateCoach })
        },
      })
      return {}
    },
    {
      hostCalls: {
        fyiPost: (params) => posted.push(params),
        fyiClear: (params) => cleared.push(params),
      },
      ctx: { getQsos: async () => qsos },
    },
  )
  assert.deepEqual(ext.categories(), ["assistant"])

  const [assistant] = (await ext.runHook("assistant", "getAssistants", {})) as { key: string; on: string[] }[]
  assert.equal(assistant?.key, "rate")
  assert.deepEqual(assistant?.on, ["qsoLogged", "tick:60"])

  const args = (reasons: string[]) => ({
    assistantKey: "rate",
    operation: { uuid: "op-1" },
    qsoCount: qsos.length,
    config: { windowMinutes: 10, atLeast: 5 },
    reasons,
    clock: { nowMillis: now, realNowMillis: now },
  })
  await ext.runHook("assistant", "observe", args(["open"]))
  assert.equal(posted.length, 1)
  assert.equal(posted[0]?.key, "rate")
  assert.equal(posted[0]?.ns, "k2hrc-coach", "the post is namespaced to the assistant's own extension")

  qsos = [1, 2, 3, 4, 5].map((m) => ({ startAtMillis: now - m * 60_000 }))
  await ext.runHook("assistant", "observe", args(["qsoLogged"]))
  assert.equal(posted.length, 1)
  assert.deepEqual(
    cleared.map((c) => c.key),
    ["rate"],
    "a rate back up takes the line down",
  )
})

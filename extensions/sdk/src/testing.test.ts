// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The harness's timers. Every extension test that drives a timer trusts
// `advance` to fire what the runtime would, when it would, against the clock
// the callback reads — so a harness that fired early, fired against real time,
// or swallowed a failing callback would let an extension's own tests pass
// while testing nothing.

import { describe, it, beforeEach } from "node:test"
import assert from "node:assert/strict"

import { defineExtension, host } from "./index.ts"
import { loadExtension } from "./testing.ts"
import type { LoadedExtension } from "./testing.ts"

const fired: { at: number; value?: unknown }[] = []
let intervalId: number | undefined

/// An extension whose hooks set timers on request.
function load(): Promise<LoadedExtension> {
  return loadExtension(
    async () => {
      defineExtension({
        key: "timers-test",
        name: "Timers",
        version: "0.0.1",
        onHide() {
          fired.push({ at: 0, value: (this as { hidden?: string }).hidden })
        },
        onActivation(api) {
          ;(this as { hidden?: string }).hidden = "set at activation"
          api.registerHook("bench", {
            hook: {
              after: async ({ delay }: { delay: number }) => {
                host.setTimeout(async () => fired.push({ at: Date.now(), value: await host.kvGet("x") }), delay)
              },
              every: async ({ delay }: { delay: number }) => {
                intervalId = host.setInterval(() => fired.push({ at: Date.now() }), delay)
              },
              stop: async () => host.clearInterval(intervalId),
              fail: async () => {
                host.setTimeout(() => {
                  throw new Error("boom")
                }, 10)
              },
              failOnce: async () => {
                let first = true
                host.setInterval(() => {
                  if (first) {
                    first = false
                    throw new Error("once")
                  }
                  fired.push({ at: Date.now() })
                }, 10)
              },
              spin: async () => {
                const chain = () => host.setTimeout(chain, 0)
                chain()
              },
              flood: async () => {
                for (let i = 0; i < 17; i++) host.setInterval(() => {}, 1000)
              },
              failAlways: async () => {
                host.setInterval(() => {
                  throw new Error("again")
                }, 10)
              },
            },
          })
        },
      })
      return {}
    },
    { hostCalls: { kvGet: () => "stubbed" } },
  )
}

describe("loadExtension's timers", () => {
  beforeEach(() => {
    fired.length = 0
  })

  it("fire only once the test advances past their delay, against the clock the callback reads", async () => {
    const ext = await load()
    await ext.timers.advance(0)
    const t0 = Date.now()
    await ext.runHook("bench", "after", { delay: 1000 })
    await ext.timers.advance(999)
    assert.deepEqual(fired, [], "a timer that fires early passes tests its app would fail")
    await ext.timers.advance(1)
    // The awaited host call settled too: `advance` waits for a callback's work,
    // not just its first synchronous step.
    assert.deepEqual(fired, [{ at: t0 + 1000, value: "stubbed" }])
    assert.equal(ext.timers.pending, false)
  })

  it("fire an interval once per period advanced, until it is cleared", async () => {
    const ext = await load()
    await ext.runHook("bench", "every", { delay: 1000 })
    await ext.timers.advance(3500)
    assert.equal(fired.length, 3)
    assert.equal(ext.timers.pending, true)
    await ext.runHook("bench", "stop")
    assert.equal(ext.timers.pending, false)
  })

  it("fail the test when a callback throws, rather than swallowing it as the runtime's log would", async () => {
    const ext = await load()
    await ext.runHook("bench", "fail")
    await assert.rejects(ext.timers.advance(10), /boom/)
  })

  it("report a failed callback once, so a test can advance past it to a recovery", async () => {
    const ext = await load()
    await ext.runHook("bench", "failOnce")
    await assert.rejects(ext.timers.advance(10), /once/)
    await ext.timers.advance(10)
    assert.equal(fired.length, 1)
  })

  it("call onHide on the author's own object, the one onActivation saw as `this`", async () => {
    // An interval kept on `this` at activation and cleared on hide is the
    // obvious way to write it, and on a copy the clear finds nothing.
    const ext = await load()
    await ext.definitions[0].onHide!()
    assert.deepEqual(fired, [{ at: 0, value: "set at activation" }])
  })

  it("go back to real time for the next loadExtension, whatever an earlier one advanced", async () => {
    // An earlier load's pinned clock would otherwise freeze every later test
    // in the file — a cache TTL that never expires, a spot that never ages.
    const first = await load()
    await first.timers.advance(60 * 60_000)
    await load()
    const real = performance.timeOrigin + performance.now()
    assert.ok(Math.abs(Date.now() - real) < 1000, `Date is ${Date.now() - real}ms off real time`)
  })

  it("fail the test when a timer is ignored, as one past the cap is: a feature that quietly stops", async () => {
    const ext = await load()
    await ext.runHook("bench", "flood")
    await assert.rejects(ext.timers.advance(1000), /beyond its 16 live timers/)
  })

  it("say what failed when repeated failures suspend the timers", async () => {
    const ext = await load()
    await ext.runHook("bench", "failAlways")
    for (let i = 0; i < 4; i++) await assert.rejects(ext.timers.advance(10), /again/)
    await assert.rejects(ext.timers.advance(10), /suspended \(failures\), after: again/)
  })

  it("fail the test when the extension breaks its budget", async () => {
    const ext = await load()
    await ext.runHook("bench", "spin")
    await assert.rejects(ext.timers.advance(0), /suspended \(budget\)/)
  })
})

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The timer queue is the whole of what keeps one extension's timers from
// eating the runtime, and every rule in it is about what an extension does
// WRONG — which no well-behaved extension in the repo will ever exercise. So
// the misbehaviour is staged here, against a clock the test moves by hand.
// packages/halo_extension_host/test/timers_test.dart runs the same queue
// through QuickJS and the host's wake timer.

import { describe, it, beforeEach } from "node:test"
import assert from "node:assert/strict"

import {
  createTimerQueue,
  removeAmbientTimers,
  FIRE_COST_MILLIS,
  MAX_CONSECUTIVE_FAILURES,
  MAX_TIMERS_PER_EXTENSION,
  RUN_SLICE_MILLIS,
  TIMER_BURST_MILLIS,
} from "./timerQueue.ts"
import type { TimerOwner, TimerQueue, TimerSuspension } from "./timerQueue.ts"

describe("createTimerQueue", () => {
  let now: number
  let wakes: (number | null)[]
  // What the host has armed right now: set by a wake, and gone the moment it
  // fires, exactly as the host's `ExtensionTimerWake` does.
  let hostArmed: number | null
  let suspensions: [string, TimerSuspension][]
  let logs: string[]
  let queue: TimerQueue
  let owners: Record<string, TimerOwner>
  const boom = new Error("describeError itself failed")

  /// The current activation of [key], made on first use as the kernel makes
  /// one per activation.
  const o = (key: string) => (owners[key] ??= queue.owner(key))

  beforeEach(() => {
    now = 1_000_000
    wakes = []
    hostArmed = null
    suspensions = []
    logs = []
    owners = {}
    queue = createTimerQueue({
      realNow: () => now,
      wake: (delay) => {
        wakes.push(delay)
        hostArmed = delay
      },
      log: (message) => logs.push(message),
      describeError: (e) => {
        if (e === boom) throw e
        return String(e)
      },
      suspended: (owner, reason) => suspensions.push([owner, reason]),
    })
  })

  /// What the host does on a wake: move the clock by the delay asked for and run.
  function wakeAndRun() {
    assert.notEqual(hostArmed, null, "the host was not asked to wake")
    now += hostArmed!
    hostArmed = null
    queue.run()
  }

  it("asks the host to wake for the EARLIEST deadline, whoever owns it", () => {
    const fired: string[] = []
    queue.set(o("a"), () => fired.push("a"), 100, false, [])
    queue.set(o("b"), () => fired.push("b"), 50, false, [])
    assert.deepEqual(wakes, [100, 50])
    wakeAndRun()
    assert.deepEqual(fired, ["b"])
    assert.equal(hostArmed, 50, "re-armed for what is left of the other timer")
    wakeAndRun()
    assert.deepEqual(fired, ["b", "a"])
    assert.equal(hostArmed, null, "nothing pending: the host timer must not stay armed")
  })

  it("passes a timer's extra arguments to its callback, as a browser does", () => {
    let got: unknown[] = []
    queue.set(o("a"), (...args: unknown[]) => (got = args), 0, false, ["x", 2])
    wakeAndRun()
    assert.deepEqual(got, ["x", 2])
  })

  it("re-arms an interval after each fire, and stops once it is cleared", () => {
    let count = 0
    const id = queue.set(o("a"), () => count++, 1000, true, [])
    wakeAndRun()
    wakeAndRun()
    assert.equal(count, 2)
    queue.clear(o("a"), id)
    assert.equal(hostArmed, null)
  })

  it("lets an interval clear itself from its own callback", () => {
    let count = 0
    let id = 0
    id = queue.set(
      o("a"),
      () => {
        count++
        queue.clear(o("a"), id)
      },
      10,
      true,
      [],
    )
    wakeAndRun()
    assert.equal(count, 1)
    assert.equal(hostArmed, null, "rescheduling after the callback would resurrect a cleared interval")
  })

  it("never lets one extension clear another's timer — ids are guessable", () => {
    let fired = false
    const id = queue.set(o("a"), () => (fired = true), 10, false, [])
    queue.clear(o("b"), id)
    wakeAndRun()
    assert.equal(fired, true)
  })

  it("defers a timer set during a run to the next wake, even at zero delay", () => {
    // Running it in the same pass would let a zero-delay chain spin inside a
    // single evaluation, where no budget and no host could get a word in.
    let fired = 0
    const chain = () => {
      fired++
      queue.set(o("a"), chain, 0, false, [])
    }
    queue.set(o("a"), chain, 0, false, [])
    queue.run()
    assert.equal(fired, 1)
    assert.equal(hostArmed, 0)
  })

  it("caps the live timers per extension, ignoring one more rather than throwing, and a fired timeout frees its slot", () => {
    // Ignored, not thrown: the timer past the cap is often a library's, set
    // from a hook that must keep working.
    for (let i = 0; i < MAX_TIMERS_PER_EXTENSION; i++) queue.set(o("a"), () => {}, i === 0 ? 0 : 60_000, false, [])
    let over = false
    queue.set(o("a"), () => (over = true), 0, false, [])
    assert.ok(logs.some((l) => l.includes(`a set a timer beyond its ${MAX_TIMERS_PER_EXTENSION} live timers`)))
    queue.set(o("b"), () => {}, 0, false, [])
    queue.run()
    assert.equal(over, false)
    let freed = false
    queue.set(o("a"), () => (freed = true), 0, false, [])
    wakeAndRun()
    assert.equal(freed, true, "the timeout that fired gave its slot back")
  })

  it("suspends a zero-delay chain whose callbacks measure as free, on the per-fire charge alone", () => {
    // The clock never moves inside a callback here, so each one measures 0ms
    // — the failure mode a budget on measured time alone would miss entirely.
    let fired = 0
    const chain = () => {
      fired++
      queue.set(o("spinner"), chain, 0, false, [])
    }
    queue.set(o("spinner"), chain, 0, false, [])
    let other = 0
    queue.set(o("bystander"), () => other++, 5, true, [])
    for (let i = 0; i < 20_000 && suspensions.length === 0; i++) {
      now += 0.1
      queue.run()
    }
    assert.deepEqual(suspensions, [["spinner", "budget"]])
    // About one burst's worth of fires, give or take what drained meanwhile.
    const burst = TIMER_BURST_MILLIS / FIRE_COST_MILLIS
    assert.ok(fired > burst / 2 && fired < burst * 1.5, `suspended after ${fired} fires`)
    // Ignored rather than thrown: a hook that sets a timer — often through a
    // library — must keep working when only its timers were at fault.
    let late = false
    queue.set(o("spinner"), () => (late = true), 0, false, [])
    queue.set(o("spinner"), () => (late = true), 0, false, [])
    assert.equal(logs.filter((l) => l.includes("spinner set a timer while its timers are suspended")).length, 1, "said once, not once per call")
    const before = other
    now += 5
    queue.run()
    assert.equal(other, before + 1, "the bystander's interval must survive its neighbour's suspension")
    assert.equal(late, false)
  })

  it("charges the wake once per run, however many of an extension's timers share it", () => {
    // Eleven trivial 100ms intervals — a library's pollers, say — cost one
    // bridge crossing per wake between them. Charged per timer, that reads as
    // 11% of real time and suspends them within minutes.
    for (let i = 0; i < 11; i++) queue.set(o("a"), () => {}, 100, true, [])
    for (let i = 0; i < 6000; i++) wakeAndRun()
    assert.deepEqual(suspensions, [])
  })

  it("lets one heavy callback through, so long as it is rare", () => {
    // A 1.2s parse every five minutes is under half a percent of real time.
    // The burst allowance is what keeps a single spike from ending the
    // extension's timers for the session.
    queue.set(
      o("a"),
      () => {
        now += 1200
      },
      5 * 60_000,
      true,
      [],
    )
    for (let i = 0; i < 12; i++) wakeAndRun()
    assert.deepEqual(suspensions, [])
  })

  it("never suspends an extension that stays under its duty cycle, however long it runs", () => {
    // A 100ms interval whose callback takes 8ms: with the per-fire charge
    // that is 9% of real time, for an hour. A budget that leaked instead of
    // draining, or charged too much per fire, would cut this off.
    queue.set(
      o("a"),
      () => {
        now += 8
      },
      100,
      true,
      [],
    )
    for (let i = 0; i < 36_000; i++) wakeAndRun()
    assert.deepEqual(suspensions, [])
  })

  it("suspends after consecutive failures, and a success in between resets the count", async () => {
    let fail = true
    queue.set(
      o("a"),
      () => {
        if (fail) throw new Error("nope")
      },
      10,
      true,
      [],
    )
    for (let i = 0; i < MAX_CONSECUTIVE_FAILURES - 1; i++) wakeAndRun()
    fail = false
    wakeAndRun()
    fail = true
    for (let i = 0; i < MAX_CONSECUTIVE_FAILURES - 1; i++) wakeAndRun()
    assert.deepEqual(suspensions, [], "failures separated by a success are not consecutive")
    wakeAndRun()
    assert.deepEqual(suspensions, [["a", "failures"]])
    assert.ok(
      logs.some((l) => l.includes("ERROR a timer callback: Error: nope")),
      "each failure is logged under its extension",
    )
  })

  it("logs an async callback's rejection but does not count it, so an offline poller keeps its timers", async () => {
    // A rejected fetch every tick is what a poller does in a park with no
    // signal. Counted, five ticks would end its timers for the session.
    queue.set(o("a"), async () => Promise.reject(new Error("offline")), 10, true, [])
    for (let i = 0; i < MAX_CONSECUTIVE_FAILURES * 2; i++) {
      wakeAndRun()
      await new Promise((resolve) => setImmediate(resolve))
    }
    assert.deepEqual(suspensions, [])
    assert.equal(logs.filter((l) => l.includes("ERROR a timer callback: Error: offline")).length, MAX_CONSECUTIVE_FAILURES * 2)
  })

  it("truncates a fractional delay, as a browser does", () => {
    queue.set(o("a"), () => {}, 1000 / 60, false, [])
    assert.equal(hostArmed, 16)
  })

  it("asks for whole milliseconds, rounded up, so a wake is never a fraction early", () => {
    // The host's timer counts whole milliseconds. Rounded down, a wake would
    // land just short of the deadline, find nothing due, and ask again at once.
    queue.set(o("a"), () => {}, 10, false, [])
    now += 9.4
    hostArmed = null
    queue.run()
    assert.equal(hostArmed, 1)
  })

  it("suspends the owner of a callback that never came back, at the next run", () => {
    // An engine interrupt unwinds through every catch and finally in the
    // kernel. Staged here by making the failure path itself throw, which
    // leaves `run()` abandoned mid-callback the same way.
    queue.set(
      o("runaway"),
      () => {
        throw boom
      },
      10,
      false,
      [],
    )
    let other = 0
    queue.set(o("bystander"), () => other++, 10, false, [])
    now += 10
    assert.throws(() => queue.run(), boom)
    queue.run()
    assert.deepEqual(suspensions, [["runaway", "interrupted"]])
    assert.equal(other, 1, "everyone else's due timers run on the recovery pass")
  })

  it("asks for the next wake once after a recovery, not again for the same deadline", () => {
    queue.set(
      o("runaway"),
      () => {
        throw boom
      },
      10,
      false,
      [],
    )
    queue.set(o("bystander"), () => {}, 1000, false, [])
    now += 10
    assert.throws(() => queue.run(), boom)
    const before = wakes.length
    queue.run()
    assert.deepEqual(wakes.slice(before), [990])
  })

  it("forgets a dropped extension's timers and its suspension, so a reload starts clean", () => {
    let fired = false
    queue.set(o("a"), () => (fired = true), 10, false, [])
    queue.drop(["a"])
    assert.equal(hostArmed, null)
    now += 10
    queue.run()
    assert.equal(fired, false, "an unloaded extension's timer must never fire into the new code")
    owners.a = queue.owner("a")

    for (let i = 0; i < MAX_CONSECUTIVE_FAILURES; i++) {
      queue.set(
        o("a"),
        () => {
          throw new Error("x")
        },
        0,
        false,
        [],
      )
      queue.run()
    }
    let ignored = false
    queue.set(o("a"), () => (ignored = true), 0, false, [])
    queue.run()
    assert.equal(ignored, false)
    queue.drop(["a"])
    owners.a = queue.owner("a")
    let clean = false
    queue.set(o("a"), () => (clean = true), 0, false, [])
    wakeAndRun()
    assert.equal(clean, true, "the reloaded extension's first timer must fire")
  })

  it("ignores an unloaded activation's code, and never counts its late failures against the new one", async () => {
    // Old code outlives its unload whenever something it awaited resolves
    // afterwards — a fetch, say — and it then reaches for the timers it was
    // handed. Accepted under the key, that is a poll loop from code that no
    // longer exists, billed to the code that replaced it.
    const old = o("a")
    let rejectLate: (e: Error) => void = () => {}
    queue.set(old, () => new Promise((_, reject) => (rejectLate = reject)), 0, false, [])
    queue.run()
    queue.drop(["a"])
    const current = queue.owner("a")
    let zombie = false
    queue.set(old, () => (zombie = true), 0, false, [])
    assert.ok(logs.some((l) => l.includes("a set a timer after it was unloaded")))

    for (let i = 0; i < MAX_CONSECUTIVE_FAILURES - 1; i++) {
      queue.set(
        current,
        () => {
          throw new Error("x")
        },
        0,
        false,
        [],
      )
      wakeAndRun()
    }
    rejectLate(new Error("the old code's promise, settling after the reload"))
    await new Promise((resolve) => setImmediate(resolve))
    assert.deepEqual(suspensions, [], "the old activation's failure must not be the new one's fifth")
    assert.equal(zombie, false, "the old code's timer must never fire")
  })

  it("cancels a failed activation's timers, not a newer activation's, and still lets its hooks set new ones", () => {
    // A dev reload can start the new activation before the old one's failure
    // arrives, so cancelling by key would take the new one's timers too. And
    // the hooks a failed activation registered are still called: a timer one
    // of them sets later is kept.
    const failed = queue.owner("a")
    const current = queue.owner("a")
    const fired: string[] = []
    queue.set(failed, () => fired.push("set while activating"), 10, false, [])
    queue.set(current, () => fired.push("newer activation"), 10, false, [])
    queue.cancel(failed)
    wakeAndRun()
    assert.deepEqual(fired, ["newer activation"])
    queue.set(failed, () => fired.push("set by a hook afterwards"), 10, false, [])
    wakeAndRun()
    assert.deepEqual(fired, ["newer activation", "set by a hook afterwards"])
  })

  it("stops a run after a slice of callbacks and fires the rest on an immediate wake", () => {
    // The engine's time limit covers a whole run. Kept going, a run could be
    // interrupted in a quick callback after slow ones spent the limit — and
    // the quick one's extension would be the one suspended.
    const order: string[] = []
    const slow = (name: string) => () => {
      order.push(name)
      now += RUN_SLICE_MILLIS * 0.6
    }
    queue.set(o("a"), slow("a"), 0, false, [])
    queue.set(o("b"), slow("b"), 0, false, [])
    queue.set(o("c"), () => order.push("c"), 0, false, [])
    queue.run()
    assert.deepEqual(order, ["a", "b"])
    assert.equal(hostArmed, 0, "what is left is still due")
    wakeAndRun()
    assert.deepEqual(order, ["a", "b", "c"])
  })

  it("refuses a callback that is not a function, rather than evaluating a string", () => {
    assert.throws(() => queue.set(o("a"), "doSomething()", 0, false, []), TypeError)
  })
})

describe("removeAmbientTimers", () => {
  // Installed onto a stand-in global, so a failure cannot take the test
  // runner's own timers with it.
  it("removes the engine's own timers, so web behaves as QuickJS does", () => {
    const global: Record<string, unknown> = { setTimeout, setInterval, clearTimeout, clearInterval }
    removeAmbientTimers(global)
    for (const name of ["setTimeout", "setInterval", "clearTimeout", "clearInterval"]) assert.equal(typeof global[name], "undefined", name)
  })

  it("shadows a timer it cannot delete", () => {
    const global: Record<string, unknown> = {}
    Object.defineProperty(global, "setTimeout", { value: setTimeout, writable: true, configurable: false })
    removeAmbientTimers(global)
    assert.equal(global.setTimeout, undefined)
  })
})

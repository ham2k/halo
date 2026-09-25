// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Extension timers, kernel side (docs/extensions/README.md, "Timers").
//
// QuickJS has no event loop, so nothing in the sandbox can wait on the clock by
// itself. The kernel keeps every extension's timers here and asks the host to
// wake it — one host timer for the earliest deadline, whoever owns it — and the
// host answers by calling `run()`. The web Worker does have timers of its own,
// and the kernel removes them, so both platforms go through this.
//
// Everything is on a MONOTONIC clock (`realNow`, `performance.now()` in the
// kernel). Not the app clock: a timer is a duration the host sleeps for, and
// under developer time travel a speed factor would scale every delay
// (docs/design/time.md). Not the wall clock either: set back an hour, it would
// hold every timer an hour and read the step as debt.
//
// No extension is trusted to keep its timers sane, and there is no delay
// floor, so the protection is accounting instead:
//
// - every fire is charged to the extension that set it: what its callback
//   measured, plus — once per wake that fires anything of it —
//   FIRE_COST_MILLIS for the wake and bridge crossing the callbacks' own
//   timing cannot see. That surcharge is what stops a zero-delay chain: its
//   callbacks measure as free, the wakes do not;
// - charges drain at TIMER_DUTY_CYCLE of real time, and debt past
//   TIMER_BURST_MILLIS suspends the extension's timers;
// - so do MAX_CONSECUTIVE_FAILURES callbacks in a row that throw. A promise a
//   callback returns that later rejects is logged but not counted: that is
//   usually a network failure — an operator in a park with no signal — and a
//   poller must not lose its timers for the session over five of them;
// - and so does a callback the engine had to interrupt, which is seen only
//   afterwards, because an interrupt unwinds through every catch and finally.
//
// Only a callback's SYNCHRONOUS part is measured. What it does after an
// `await` runs later as a microtask, outside any run, where nothing can tell
// whose it is — the same blind spot a hook's continuation and a socket
// handler's have. The engine's own per-evaluation limit still bounds it.
//
// Suspension cancels every timer the extension holds and ignores new ones
// until the extension is unloaded (a dev reload) or the runtime is replaced.
//
// `set` never throws for a function callback. A timer it will not keep —
// suspended, over the cap, from unloaded code — gets an id that never fires,
// and the log says so once per reason. Throwing would break the hook that
// asked, often through a library that never expected `setTimeout` to throw,
// and the hook is not what misbehaved.
//
// Ownership is a handle per ACTIVATION, not a key: an unloaded extension's
// code can still be running — a fetch resolving after the reload — and must
// neither start timers under the key the new code now holds nor have its
// late failures counted against it.

/// Live timers (pending timeouts plus intervals) one extension may hold.
export const MAX_TIMERS_PER_EXTENSION = 16

/// Real milliseconds charged per fire on top of what the callback measured.
export const FIRE_COST_MILLIS = 1

/// The share of real time an extension's timer callbacks may use, sustained.
export const TIMER_DUTY_CYCLE = 0.1

/// How far past the sustained rate an extension may run before suspension.
/// Half a hook's ten seconds, so one heavy callback — a large parse every few
/// minutes — is paid off rather than punished.
export const TIMER_BURST_MILLIS = 5000

/// Callbacks in a row that may throw before suspension.
export const MAX_CONSECUTIVE_FAILURES = 5

/// How long one run keeps firing callbacks before leaving the rest to an
/// immediate next wake. The engine's time limit covers a whole evaluation, and
/// an interrupt is blamed on whichever callback it lands in — so a run that
/// kept going could cut off a quick callback after slow ones had spent the
/// limit. It also lets hook calls in between.
export const RUN_SLICE_MILLIS = 1000

/// Browsers treat a longer delay as zero; this clamps it instead.
const MAX_DELAY_MILLIS = 2 ** 31 - 1

/// Why an extension's timers were suspended. Codes rather than prose because
/// the host words the notice itself, in the operator's language.
export type TimerSuspension = "budget" | "failures" | "interrupted"

export interface TimerQueueHost {
  realNow(): number
  /// Asks the host to call `run()` in [delayMillis] real milliseconds —
  /// replacing any wake asked for before — or never, for null.
  wake(delayMillis: number | null): void
  log(message: string): void
  describeError(e: unknown): string
  suspended(owner: string, reason: TimerSuspension): void
}

/// One activation of one extension, as far as its timers are concerned.
export interface TimerOwner {
  readonly key: string
}

export interface TimerQueue {
  owner(key: string): TimerOwner
  set(owner: TimerOwner, callback: unknown, delay: unknown, repeat: boolean, args: unknown[]): number
  clear(owner: TimerOwner, id: unknown): void
  run(): void
  cancel(owner: TimerOwner): void
  drop(keys: string[]): void
}

interface Account extends TimerOwner {
  debt: number
  chargedAt: number
  failures: number
  suspended: TimerSuspension | null
  revoked: boolean
  refusalsLogged: Set<string>
}

interface TimerRecord {
  id: number
  owner: Account
  callback: (...args: unknown[]) => unknown
  args: unknown[]
  deadline: number
  interval: number | null
}

export function createTimerQueue(host: TimerQueueHost): TimerQueue {
  const timers = new Map<number, TimerRecord>()
  const accounts = new Set<Account>()
  let nextId = 1
  // The deadline the host was last asked to wake for, so an unchanged
  // earliest deadline costs no message.
  let armed: number | null = null
  // Set around each callback WITHOUT try/finally: an engine interrupt skips
  // finally blocks too, so a value still here when `run()` next starts means
  // the last callback never came back.
  let inCallback: TimerRecord | null = null

  function rearm() {
    let earliest: number | null = null
    for (const t of timers.values()) {
      if (earliest === null || t.deadline < earliest) earliest = t.deadline
    }
    if (earliest === armed) return
    armed = earliest
    // Whole milliseconds, rounded UP: the host's timer is whole milliseconds,
    // and a wake that lands a fraction early finds nothing due and has to ask
    // again at once.
    host.wake(earliest === null ? null : Math.max(0, Math.ceil(earliest - host.realNow())))
  }

  function suspend(owner: Account, reason: TimerSuspension) {
    if (owner.suspended || owner.revoked) return
    owner.suspended = reason
    for (const t of [...timers.values()]) {
      if (t.owner === owner) timers.delete(t.id)
    }
    const why = {
      budget: `its callbacks used more than ${TIMER_DUTY_CYCLE * 100}% of the time`,
      failures: `${MAX_CONSECUTIVE_FAILURES} callbacks in a row failed`,
      interrupted: "a callback ran past the engine's time limit",
    }[reason]
    host.log(`ERROR ${owner.key} timers suspended: ${why}`)
    host.suspended(owner.key, reason)
    rearm()
  }

  function cancelAll(owner: Account) {
    for (const t of [...timers.values()]) {
      if (t.owner === owner) timers.delete(t.id)
    }
  }

  /// An id that never fires, and a log line the first time [owner] is refused
  /// for [why].
  function refuse(owner: Account, why: string): number {
    if (!owner.refusalsLogged.has(why)) {
      owner.refusalsLogged.add(why)
      host.log(`ERROR ${owner.key} set a timer ${why}; it will not fire`)
    }
    return nextId++
  }

  function charge(owner: Account, cost: number) {
    const now = host.realNow()
    owner.debt = Math.max(0, owner.debt - (now - owner.chargedAt) * TIMER_DUTY_CYCLE) + cost
    owner.chargedAt = now
    if (owner.debt > TIMER_BURST_MILLIS) suspend(owner, "budget")
  }

  function failed(owner: Account, e: unknown) {
    host.log(`ERROR ${owner.key} timer callback: ${host.describeError(e)}`)
    owner.failures++
    if (owner.failures >= MAX_CONSECUTIVE_FAILURES) suspend(owner, "failures")
  }

  function succeeded(owner: Account) {
    owner.failures = 0
  }

  /// [wakeCost] is FIRE_COST_MILLIS for the first of this owner's timers in a
  /// run and zero for the rest: they shared the one wake.
  function fire(t: TimerRecord, wakeCost: number) {
    const startedAt = host.realNow()
    let result: unknown
    let threw = false
    inCallback = t
    try {
      result = t.callback(...t.args)
    } catch (e) {
      threw = true
      failed(t.owner, e)
    }
    inCallback = null
    charge(t.owner, host.realNow() - startedAt + wakeCost)
    if (threw) return
    succeeded(t.owner)
    if (result instanceof Promise) {
      result.catch((e) => host.log(`ERROR ${t.owner.key} timer callback: ${host.describeError(e)}`))
    }
  }

  return {
    owner(key) {
      const owner: Account = { key, debt: 0, chargedAt: host.realNow(), failures: 0, suspended: null, revoked: false, refusalsLogged: new Set() }
      accounts.add(owner)
      return owner
    },

    set(handle, callback, delay, repeat, args) {
      const owner = handle as Account
      if (typeof callback !== "function") throw new TypeError("timer callback must be a function")
      if (owner.revoked) return refuse(owner, "after it was unloaded")
      if (owner.suspended) return refuse(owner, "while its timers are suspended")
      let live = 0
      for (const t of timers.values()) if (t.owner === owner) live++
      if (live >= MAX_TIMERS_PER_EXTENSION) return refuse(owner, `beyond its ${MAX_TIMERS_PER_EXTENSION} live timers`)
      const n = Number(delay)
      // Truncated, as a browser does.
      const ms = n > 0 ? Math.min(Math.trunc(n), MAX_DELAY_MILLIS) : 0
      const id = nextId++
      timers.set(id, {
        id,
        owner,
        callback: callback as (...args: unknown[]) => unknown,
        args,
        deadline: host.realNow() + ms,
        interval: repeat ? ms : null,
      })
      rearm()
      return id
    },

    /// Ids are guessable, so one owner's clear never reaches another's timer.
    clear(handle, id) {
      const t = timers.get(id as number)
      if (!t || t.owner !== handle) return
      timers.delete(t.id)
      rearm()
    },

    /// Fires what was due when it started. A timer set by one of these
    /// callbacks waits for the next wake even at zero delay: running it here
    /// would let a zero-delay chain spin inside a single evaluation.
    run() {
      // Before the suspension below, which re-arms: the host's timer has
      // already fired, so nothing is armed whatever this last said.
      armed = null
      if (inCallback) {
        const cutShort = inCallback
        inCallback = null
        suspend(cutShort.owner, "interrupted")
      }
      const now = host.realNow()
      const due = [...timers.values()].filter((t) => t.deadline <= now).sort((a, b) => a.deadline - b.deadline || a.id - b.id)
      const woken = new Set<Account>()
      for (const t of due) {
        // Still due, so the closing re-arm asks for an immediate wake.
        if (host.realNow() - now >= RUN_SLICE_MILLIS) break
        // Cleared, or its owner suspended, by an earlier callback in this run.
        if (timers.get(t.id) !== t) continue
        if (t.interval === null) timers.delete(t.id)
        const wakeCost = woken.has(t.owner) ? 0 : FIRE_COST_MILLIS
        woken.add(t.owner)
        fire(t, wakeCost)
        if (t.interval !== null && timers.get(t.id) === t) t.deadline = host.realNow() + t.interval
      }
      rearm()
    },

    /// Cancels what one activation — one that failed — has set, and nothing
    /// of a newer activation's: a dev reload can start the new one before the
    /// old one's failure arrives. The handle stays good, because the hooks
    /// that activation registered before failing are still called.
    cancel(handle) {
      cancelAll(handle as Account)
      rearm()
    },

    /// Revokes every activation of [keys]: their timers go, their handles
    /// ignore new ones, and a reloaded extension starts clean on a new handle.
    drop(keys) {
      for (const owner of [...accounts]) {
        if (!keys.includes(owner.key)) continue
        owner.revoked = true
        accounts.delete(owner)
        cancelAll(owner)
      }
      rearm()
    },
  }
}

/// Takes away the engine's own timers. The web Worker has them and QuickJS
/// does not, so left alone they would work on web and nowhere native — and
/// count against no one's budget where they did. False if any survived.
export function removeAmbientTimers(global: Record<string, unknown> = globalThis as unknown as Record<string, unknown>): boolean {
  for (const name of ["setTimeout", "setInterval", "clearTimeout", "clearInterval"]) {
    try {
      delete global[name]
    } catch (e) {
      // non-configurable — fall through to shadowing below
    }
    if (typeof global[name] === "function") {
      try {
        global[name] = undefined
      } catch (e) {
        // both delete and assignment blocked: reported below
      }
    }
  }
  return ["setTimeout", "setInterval", "clearTimeout", "clearInterval"].every((name) => typeof global[name] !== "function")
}

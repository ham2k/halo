// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Replacing the sandbox's `Date` is the highest-leverage line in the extension
// runtime: get it wrong and EVERY date in EVERY extension is wrong at once, or
// a whole class of legal JS starts throwing inside third-party bundles. The
// engine-level test (packages/halo_extension_host/test/sandbox_clock_test.dart)
// proves the substitution survives QuickJS-NG, but it can only observe what one
// dashboard happens to render. These cover the surface itself.

import { describe, it, beforeEach, afterEach } from "node:test"
import assert from "node:assert/strict"

import { installAppClock } from "./appClock.ts"
import type { AppClockHandle } from "./appClock.ts"

const HOUR = 60 * 60 * 1000

describe("installAppClock", () => {
  // Installed onto a stand-in global rather than the real one, so a failing
  // assertion can't leave the test runner itself on a travelled clock.
  let global: Record<string, unknown>
  let clock: AppClockHandle
  let RealDate: DateConstructor

  beforeEach(() => {
    RealDate = Date
    global = { Date }
    clock = installAppClock(global)
  })

  afterEach(() => {
    assert.equal(Date, RealDate, "the ambient Date must be untouched")
  })

  /// The replaced constructor, typed loosely — the point is that it behaves like
  /// `Date` to code that has no idea it was replaced.
  const D = () => global.Date as DateConstructor

  it("reads real time until the host says otherwise", () => {
    assert.ok(Math.abs(D().now() - RealDate.now()) < 1000)
    assert.ok(Math.abs(new (D())().getTime() - RealDate.now()) < 1000)
  })

  describe("travelled", () => {
    beforeEach(() => {
      // Three hours ahead, anchored now — the shape the Dart AppClock sends.
      const real = RealDate.now()
      clock.setClockTravel(real, real + 3 * HOUR, 1)
    })

    it("moves Date.now()", () => {
      assert.ok(Math.abs(D().now() - (RealDate.now() + 3 * HOUR)) < 1000)
    })

    it("moves a no-argument construction", () => {
      assert.ok(Math.abs(new (D())().getTime() - (RealDate.now() + 3 * HOUR)) < 1000)
    })

    it("leaves an explicit construction exactly alone", () => {
      // The offset must apply to "now", never to a date the caller stated. A
      // proxy that added the offset here would corrupt every parsed QSO time.
      assert.equal(new (D())(0).getTime(), 0)
      assert.equal(new (D())("2026-03-28T12:00:00Z").toISOString(), "2026-03-28T12:00:00.000Z")
      assert.equal(new (D())(2026, 2, 28).getFullYear(), 2026)
    })

    it("applies a speed factor from the anchor", () => {
      const real = RealDate.now()
      clock.setClockTravel(real - 1000, real, 100)
      // One real second before the anchor, at 100x: ~100 virtual seconds past it.
      assert.ok(clock.appNow() - real > 90_000, `got ${clock.appNow() - real}`)
    })

    it("keeps realNow on the real clock", () => {
      // What the kernel times hooks and expires its caches with. If this
      // travelled, a 5ms hook would report minutes of jsMillis at 100x.
      assert.ok(Math.abs(clock.realNow() - RealDate.now()) < 1000)
    })

    it("returns to real time when the host clears the anchor", () => {
      clock.setClockTravel(0, 0, 1)
      assert.ok(Math.abs(D().now() - RealDate.now()) < 1000)
    })
  })

  // The reason this is a Proxy and not `class AppDate extends Date`. A class
  // constructor throws when called without `new`, so any bundle (or minified
  // date helper) doing the legal thing would break with a TypeError naming a
  // class no extension author has ever heard of.
  describe("stays a drop-in replacement", () => {
    it("Date() without new still returns a string", () => {
      const bare = (global.Date as unknown as () => unknown)()
      assert.equal(typeof bare, "string")
      assert.ok(!Number.isNaN(RealDate.parse(bare as string)), `unparseable: ${bare}`)
    })

    it("Date() without new follows the app clock", () => {
      const real = RealDate.now()
      clock.setClockTravel(real, real + 400 * 24 * HOUR, 1)
      const bare = (global.Date as unknown as () => string)()
      assert.ok(Math.abs(RealDate.parse(bare) - clock.appNow()) < 2000)
    })

    it("keeps the static helpers", () => {
      assert.equal(D().parse("2026-03-28T12:00:00Z"), RealDate.parse("2026-03-28T12:00:00Z"))
      assert.equal(D().UTC(2026, 2, 28), RealDate.UTC(2026, 2, 28))
    })

    it("keeps instanceof and the prototype chain", () => {
      const d = new (D())()
      assert.ok(d instanceof RealDate, "instanceof Date must still hold")
      assert.equal(D().prototype, RealDate.prototype)
      assert.equal(typeof d.toISOString(), "string")
    })

    it("supports subclassing", () => {
      // `class X extends Date` is a real pattern in date helpers, and a
      // construct trap that drops `newTarget` silently returns a plain Date —
      // so the subclass's own methods vanish with an error naming nothing to do
      // with the clock.
      const D = global.Date as DateConstructor
      class Stamp extends D {
        label() {
          return "stamped"
        }
      }
      const s = new Stamp()
      assert.ok(s instanceof Stamp)
      assert.equal(s.label(), "stamped")
      assert.equal(typeof s.toISOString(), "string")
    })

    it("subclass construction still means NOW on the app clock", () => {
      const real = RealDate.now()
      clock.setClockTravel(real, real + 5 * HOUR, 1)
      const D = global.Date as DateConstructor
      class Stamp extends D {}
      assert.ok(Math.abs(new Stamp().getTime() - (RealDate.now() + 5 * HOUR)) < 1000)
    })

    it("Date.now is a stable function identity", () => {
      // Anything caching or comparing it (`const now = Date.now; now()`, or a
      // `Date.now === Date.now` assertion in a shim) breaks on a fresh closure.
      const D = global.Date as DateConstructor
      assert.equal(D.now, D.now)
      const cached = D.now
      assert.ok(Math.abs(cached() - clock.appNow()) < 1000)
    })

    it("keeps the constructor's arity", () => {
      // Feature detection on Date.length exists in the wild; a class would
      // report 0 here.
      assert.equal(D().length, RealDate.length)
    })
  })
})

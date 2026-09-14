// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// The app clock inside the extension sandbox (docs/design/time.md §6).
//
// Extensions must read the same "now" the Dart side does. A clock dashboard, a
// spot age, an ADIF export stamp or a data-file freshness check reading real
// time while the app is time-travelled contradicts everything around it, and
// the mismatch reads as an extension bug.
//
// Rather than adding a clock API for every extension to remember to call, the
// sandbox's own `Date` is REPLACED — so ordinary `Date.now()` and `new Date()`
// travel for free, including in third-party bundles the SDK never sees.
//
// Its own module, rather than inline in kernel.ts, so the substitution can be
// unit-tested: the failure mode of getting a global `Date` replacement wrong is
// every date in every extension being wrong at once, and the engine-level test
// (packages/halo_extension_host/test/sandbox_clock_test.dart) can only observe
// what an extension happens to render.

/// What [installAppClock] hands back: the captured real clock for the kernel's
/// own use, and the setter the host drives travel through.
export interface AppClockHandle {
  /// Real epoch millis, from the `Date` captured BEFORE the replacement.
  ///
  /// The kernel's own timings and cache TTLs must use this: they measure real
  /// elapsed work, and a speed factor would silently scale them — a hook taking
  /// 5 ms would report minutes of `jsMillis` at 100x, poisoning the numbers the
  /// app is profiled with.
  realNow(): number

  /// Points the sandbox clock at the host's, from the anchor pair and speed the
  /// Dart `AppClock` derives its own reading from. Anchors rather than an offset
  /// so both sides compute the same virtual time from the same formula: an
  /// offset would already be stale by the time the message arrived, and under a
  /// factor the error would keep growing. `anchorRealMillis: 0` means real time.
  setClockTravel(anchorRealMillis: number, anchorVirtualMillis: number, speed: number): void

  /// The sandbox's current reading, in epoch millis — what the replaced `Date`
  /// answers with.
  appNow(): number
}

/// Replaces `globalThis.Date` with one on the app clock, and returns the handle
/// for the kernel's real-time needs. Call ONCE, before any bundle evaluates.
export function installAppClock(global: Record<string, unknown> = globalThis as unknown as Record<string, unknown>): AppClockHandle {
  const RealDate = global.Date as DateConstructor
  const realNow = () => RealDate.now()

  // Zero means "not travelling": the anchors are only ever set by the host, and
  // the epoch is not a plausible anchor.
  let anchorReal = 0
  let anchorVirtual = 0
  let speed = 1

  const appNow = (): number => {
    if (anchorReal === 0) return realNow()
    return Math.round(anchorVirtual + (realNow() - anchorReal) * speed)
  }

  // Hoisted so `Date.now` is one stable function, not a new closure per access.
  const appNowStatic = (): number => appNow()

  // A Proxy around the real constructor, NOT an ES class extending it. A class
  // would be the obvious shape and is subtly wrong: `Date()` without `new` is
  // legal JS that returns a date string, and a class constructor throws when
  // called that way — so any bundle (or minified helper) doing it would break
  // with a TypeError naming a class no extension author has ever heard of.
  // A Proxy also keeps `Date.parse`, `Date.UTC`, `Date.prototype`, `Date.length`
  // and `instanceof Date` exactly as they were, rather than re-deriving them.
  const AppDate = new Proxy(RealDate, {
    construct(target, args, newTarget) {
      // Only a no-argument construction means "now"; every explicit form is
      // passed through untouched, so `new Date(ms)` and `new Date(string)`
      // still mean precisely what they say.
      //
      // Through Reflect.construct WITH newTarget, so `class Stamp extends Date`
      // in a bundle still produces a Stamp: dropping it hands back a plain Date,
      // and the subclass's own methods vanish with a `not a function` error that
      // names nothing to do with the clock.
      return Reflect.construct(target, args.length === 0 ? [appNow()] : args, newTarget)
    },

    // `Date()` without `new` — spec behaviour is "the current time as a
    // string", so it follows the app clock the same way construction does.
    apply() {
      return new RealDate(appNow()).toString()
    },

    get(target, prop, receiver) {
      // One function, not a fresh closure per access: `Date.now === Date.now`
      // is false otherwise, which breaks anything caching or comparing it.
      if (prop === 'now') return appNowStatic
      return Reflect.get(target, prop, receiver)
    },
  })

  global.Date = AppDate

  // Verified rather than assumed. This file's whole failure mode is graded — a
  // wholly missing replacement is obvious, a PARTIAL one (a non-writable global,
  // a module that captured `Date` at its own import time) leaves some dates
  // travelling and some not, which is the version nobody diagnoses.
  if (global.Date !== AppDate) {
    throw new Error('appClock: the sandbox Date could not be replaced; extensions would read real time')
  }

  return {
    realNow,
    appNow,
    setClockTravel(anchorRealMillis: number, anchorVirtualMillis: number, nextSpeed: number) {
      anchorReal = anchorRealMillis
      anchorVirtual = anchorVirtualMillis
      speed = nextSpeed
    },
  }
}

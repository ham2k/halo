// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Timers, SDK side: `host.setTimeout` and friends, and the build's `inject`
// file (`buildOptionsFor` in tools/h2kext-build.mjs) — esbuild points every
// bare `setTimeout`, `setInterval`, `clearTimeout` and `clearInterval` in a
// bundle, its npm dependencies included, at the exports here, so a library
// that schedules work runs on the extension's own timers and budget.
//
// Two constraints shape this file:
//
// - Every export replaces the global of the same name wherever a bundle uses
//   it. Beyond the four timer names there is only `adoptExtensionTimers`,
//   which no code uses as a global.
// - It imports nothing at runtime. esbuild imports an inject file into every
//   module of the bundle; importing `index.ts` back from here closes a cycle,
//   and esbuild answers a cycle by wrapping EVERY module in a lazy
//   initializer — most of a kilobyte in each of 53 bundles, and a change to
//   the order they evaluate in. So the state lives here and `index.ts`
//   imports it, not the other way round.

import type { ActivationApi } from "./types.ts"

type BoundTimers = NonNullable<ActivationApi["timers"]>

// Per bundle, like index.ts's `privilegedHostCalls`: every bundle carries its
// own copy of this module, so no other bundle can reach these.
const bound: Record<string, BoundTimers> = {}
let preferredKey: string | null = null
let activated = false

/// SDK-internal: `defineExtension` reports each activation — the extension's
/// key, the key this bundle's calls are made under (index.ts's
/// `currentExtensionKey`), and the timers the kernel handed over, which a
/// kernel older than extension API 3 does not.
export function adoptExtensionTimers(key: string, currentKey: string, timers: BoundTimers | undefined) {
  activated = true
  preferredKey = currentKey
  if (timers) bound[key] = timers
}

/// Chosen the way index.ts's `hostCallFn` chooses.
function boundTimers(): BoundTimers | undefined {
  return (preferredKey !== null ? bound[preferredKey] : undefined) ?? Object.values(bound)[0]
}

const refusalsLogged = new Set<string>()

/// With no timers to hand — before activation, or from a kernel older than
/// extension API 3 — a timer is ignored, as the kernel ignores one it will not
/// keep: an id that never fires, and one log line. Never a throw, because a
/// library guarding with `typeof setTimeout` may call it while its module is
/// still loading, and a throw there stops the whole bundle from defining
/// itself. There is no public fallback: a timer with no owner is one no
/// budget could hold.
function set(callback: unknown, delay: unknown, repeat: boolean, args: unknown[]): number {
  const timers = boundTimers()
  if (timers) return timers.set(callback, delay, repeat, args)
  const why = activated ? "this version of HaLo has no timers" : "set before the extension activated"
  if (!refusalsLogged.has(why)) {
    refusalsLogged.add(why)
    // Before activation the key is not known here; the kernel names the
    // bundle whose evaluation this happens in.
    const who = preferredKey !== null ? `${preferredKey}: ` : ""
    ;(globalThis as { __polo?: { log(message: string): void } }).__polo?.log(`ERROR ${who}a timer was ignored: ${why}`)
  }
  return 0
}

export function setTimeout(callback: (...args: any[]) => unknown, delay?: number, ...args: unknown[]): number {
  return set(callback, delay, false, args)
}

export function setInterval(callback: (...args: any[]) => unknown, delay?: number, ...args: unknown[]): number {
  return set(callback, delay, true, args)
}

/// Clears a timeout or an interval — either name reaches either, as in a
/// browser. An id this extension did not set is ignored, and so is any id
/// before activation, when there can be nothing to clear.
export function clearTimeout(id?: number): void {
  boundTimers()?.clear(id)
}

export function clearInterval(id?: number): void {
  clearTimeout(id)
}

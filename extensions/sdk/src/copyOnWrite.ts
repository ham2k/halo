// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// A scoresheet a scorer may mutate without the sheet it came from noticing.
//
// The scorer contract lets `scoreQso` mutate the sheet it is handed — that is
// what keeps the batch fold linear — and the live paths score a candidate that
// is then thrown away. Judging one candidate must not enter it into the log
// the next candidate is judged against, and a `JSON.parse(JSON.stringify(...))`
// of the folded log per candidate — every worked call, per candidate, per
// scorer, on a board of forty spots — would be the cost of the whole pass.
//
// This keeps the guarantee without the copy. The sheet is wrapped in a lazy
// copy-on-write view: reads fall through to the base, writes land in an
// overlay, and a nested object or array is wrapped the first time it is read
// so that a push into a worked-call list or a counter bumped two levels down
// lands in ITS overlay. Nothing reaches the base, and the cost of a candidate
// is the handful of keys a scorer touches.
//
// Sheets are JSON (`Scoresheet = JSONValue`): plain objects, arrays and
// primitives, which is all the view knows how to wrap. A sheet with an
// accessor is outside the contract, and the view throws at the first touch
// rather than pretend. A FROZEN container is inside it: a scorer at extension
// API 9 is handed the log's QSOs frozen, and may keep part of one in its
// sheet. A proxy over a frozen object must hand back each nested value as it
// is — the language refuses a view of it — so a frozen container is viewed
// through a shallow copy of itself instead, which the view may then wrap.

/// A view of [base] that a caller may mutate freely; [base] is never written.
///
/// Every read of a nested object hands back the same wrapped view, so a
/// reference a scorer keeps (`const prior = sheet.workedByCall[call]`) and a
/// later read agree about what was written through it. A view over a view
/// works the same way, each layer with its own overlay.
export function copyOnWrite<T>(base: T): T {
  return isContainer(base) ? (wrap(wrappable(base)) as T) : base
}

/// [value] itself, or a shallow copy when it is frozen — see the header.
function wrappable<T extends object>(value: T): T {
  if (!Object.isFrozen(value)) return value
  return (Array.isArray(value) ? [...value] : { ...value }) as T
}

function isContainer(value: unknown): value is object {
  return typeof value === "object" && value !== null
}

function wrap<T extends object>(target: T): T {
  // Values written through the view, and nested views handed out — keyed as
  // the property is, so a string index and an array index meet where the
  // language makes them meet.
  const own = new Map<string | symbol, unknown>()
  const deleted = new Set<string | symbol>()

  return new Proxy(target, {
    get(t, key) {
      if (own.has(key)) return own.get(key)
      if (deleted.has(key)) return undefined
      const value = Reflect.get(t, key)
      // Only an OWN container is wrapped: a method reached through the
      // prototype (`push`, `some`) must stay the real function, called with the
      // view as `this` so its reads and writes go through these traps.
      if (isContainer(value) && Object.prototype.hasOwnProperty.call(t, key)) {
        const view = wrap(wrappable(value))
        own.set(key, view)
        return view
      }
      return value
    },
    set(_t, key, value) {
      own.set(key, value)
      deleted.delete(key)
      return true
    },
    has(t, key) {
      if (deleted.has(key)) return false
      return own.has(key) || key in t
    },
    deleteProperty(t, key) {
      // A non-configurable property (an array's `length`) cannot be reported
      // gone — the language refuses the view that claims it — so the delete
      // is refused the way it would be on the real object.
      const descriptor = Reflect.getOwnPropertyDescriptor(t, key)
      if (descriptor && !descriptor.configurable) return false
      own.delete(key)
      if (descriptor) deleted.add(key)
      return true
    },
    ownKeys(t) {
      const keys = Reflect.ownKeys(t).filter((key) => !deleted.has(key))
      for (const key of own.keys()) {
        if (!keys.includes(key)) keys.push(key)
      }
      return keys
    },
    getOwnPropertyDescriptor(t, key) {
      if (deleted.has(key)) return undefined
      const descriptor = Reflect.getOwnPropertyDescriptor(t, key)
      if (!own.has(key)) return descriptor
      // A property the base has keeps its own attributes (an array's `length`
      // stays non-configurable, as the language requires of a view); one the
      // base lacks is ordinary data.
      return descriptor ? { ...descriptor, value: own.get(key) } : { value: own.get(key), writable: true, enumerable: true, configurable: true }
    },
    // The other ways to write. Without these traps `Object.defineProperty`
    // and `Object.freeze` fall through to the base — the held checkpoint —
    // and one such call would enter a candidate into every later verdict, or
    // lock the sheet for the rest of the session.
    defineProperty(_t, key, descriptor) {
      if ("get" in descriptor || "set" in descriptor) return false
      own.set(key, descriptor.value)
      deleted.delete(key)
      return true
    },
    preventExtensions() {
      return false
    },
    setPrototypeOf() {
      return false
    },
  })
}

// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MIT
//
// Freezes the realm every bundle shares with the kernel (docs/design/js-engine.md,
// "Frozen realm"). Run once, by the kernel, after it has installed everything it
// installs on the realm — the app clock's Date, the number-format polyfill, the
// removal of the engine's own timers — and before any bundle evaluates.
//
// Every bundle is evaluated in one realm. A built-in a bundle could rewrite —
// `Map.prototype.get`, `Promise.prototype.then`, `Function.prototype.call` — is
// one the kernel also calls, so a bundle rewriting it would watch, and could
// redirect, what the kernel does for every other extension. Freezing them all,
// and the shared libraries every bundle is handed, closes that.

/// The globals every bundle shares: the standard built-ins, the engine's own
/// (`queueMicrotask`, `performance`…) and the kernel's `console`. Frozen, and
/// their names pinned so none can be replaced on the global either. One this
/// engine lacks is skipped.
const INTRINSIC_GLOBALS = [
  "Object",
  "Function",
  "Array",
  "Number",
  "Boolean",
  "String",
  "Symbol",
  "BigInt",
  "Date",
  "Promise",
  "RegExp",
  "Error",
  "AggregateError",
  "EvalError",
  "RangeError",
  "ReferenceError",
  "SyntaxError",
  "TypeError",
  "URIError",
  "JSON",
  "Math",
  "Reflect",
  "Proxy",
  "Intl",
  "Map",
  "Set",
  "WeakMap",
  "WeakSet",
  "WeakRef",
  "FinalizationRegistry",
  "ArrayBuffer",
  "SharedArrayBuffer",
  "DataView",
  "Atomics",
  "Int8Array",
  "Uint8Array",
  "Uint8ClampedArray",
  "Int16Array",
  "Uint16Array",
  "Int32Array",
  "Uint32Array",
  "Float16Array",
  "Float32Array",
  "Float64Array",
  "BigInt64Array",
  "BigUint64Array",
  "Iterator",
  "parseInt",
  "parseFloat",
  "isNaN",
  "isFinite",
  "decodeURI",
  "decodeURIComponent",
  "encodeURI",
  "encodeURIComponent",
  "escape",
  "unescape",
  "eval",
  "queueMicrotask",
  "atob",
  "btoa",
  "performance",
  "console",
  "DisposableStack",
  "AsyncDisposableStack",
  "SuppressedError",
]

/// Built-ins no global names, reached through what produces them. One this
/// engine lacks (the iterator helpers are recent) is skipped.
function hiddenIntrinsics(): unknown[] {
  const found: unknown[] = []
  const add = (make: () => unknown) => {
    try {
      found.push(Object.getPrototypeOf(make()))
    } catch (e) {
      // Not in this engine.
    }
  }
  add(() => function* () {})
  add(() => async function () {})
  add(() => async function* () {})
  add(() => (function* () {})())
  add(() => (async function* () {})())
  add(() => [][Symbol.iterator]())
  add(() => new Map()[Symbol.iterator]())
  add(() => new Set()[Symbol.iterator]())
  add(() => ""[Symbol.iterator]())
  add(() => /x/[Symbol.matchAll]("x"))
  add(() => Uint8Array)
  add(() => ([][Symbol.iterator]() as unknown as { map(f: (x: unknown) => unknown): unknown }).map((x) => x))
  add(() => (globalThis as unknown as { Iterator: { from(o: object): unknown } }).Iterator.from({ next: () => ({ done: true, value: undefined }) }))
  return found
}

/// Turns [prop], a data property of the frozen [proto], into an accessor
/// whose setter gives the object being assigned to a property of its own.
///
/// Without it, freezing makes ordinary code throw: an assignment to a property
/// an object inherits as non-writable fails, so `this.name = "MyError"` in an
/// Error subclass, or `obj.toString = …`, stops working once Error.prototype or
/// Object.prototype is frozen. The prototype's own value still cannot change.
/// Every read of the property then costs a getter call, so only names code is
/// known to assign are tamed, never a hot method like `push` or `call`, and
/// never `constructor` on Array or Promise, which the web engine watches to
/// keep `map`, `then` and `await` fast.
function tameOverride(proto: object, prop: PropertyKey): void {
  const desc = Object.getOwnPropertyDescriptor(proto, prop)
  if (!desc || !("value" in desc) || !desc.configurable) return
  const value = desc.value
  Object.defineProperty(proto, prop, {
    get() {
      return value
    },
    set(this: object, next: unknown) {
      if (this === proto) throw new TypeError(`Cannot assign to read only property '${String(prop)}' of a frozen object`)
      Object.defineProperty(this, prop, { value: next, writable: true, enumerable: true, configurable: true })
    },
    enumerable: desc.enumerable,
    configurable: false,
  })
}

function tameIntrinsicOverrides(): void {
  for (const prop of ["constructor", "toString", "valueOf", "toLocaleString"]) tameOverride(Object.prototype, prop)
  tameOverride(Array.prototype, "toString")
  tameOverride(Function.prototype, "toString")
  for (const name of ["Error", "AggregateError", "EvalError", "RangeError", "ReferenceError", "SyntaxError", "TypeError", "URIError", "SuppressedError"]) {
    const ctor = (globalThis as Record<string, unknown>)[name] as { prototype?: object } | undefined
    if (!ctor?.prototype) continue
    for (const prop of ["constructor", "message", "name", "toString"]) tameOverride(ctor.prototype, prop)
  }
}

/// What a library's getter answers: a bundled library exports its values
/// through getters, and freezing the getter alone leaves the value behind it
/// open. Undefined for a getter that throws.
function readGetter(target: object, key: PropertyKey, desc: PropertyDescriptor): unknown {
  if (!desc.get) return undefined
  try {
    return desc.get.call(target)
  } catch (e) {
    return undefined
  }
}

/// Freezes [root] and everything reachable from it: own properties, accessors
/// and prototypes.
///
/// With [library], what each getter answers is walked too, except on a
/// prototype (a getter there is an instance's, and could cache onto the
/// prototype what belongs to an instance), and each prototype's
/// `constructor` is tamed (tameOverride): compiled class helpers assign it on
/// every instance.
///
/// A typed array or DataView cannot be frozen while it holds anything, and a
/// Map's or Set's entries are not properties: those stay writable.
function harden(root: unknown, seen: Set<unknown>, library = false): void {
  const stack: unknown[] = [root]
  while (stack.length > 0) {
    const value = stack.pop()
    if ((typeof value !== "object" && typeof value !== "function") || value === null || seen.has(value)) continue
    seen.add(value)
    if (ArrayBuffer.isView(value)) continue
    const ctor = Object.getOwnPropertyDescriptor(value, "constructor")?.value
    const isPrototype = typeof ctor === "function" && ctor.prototype === value
    if (library && isPrototype) tameOverride(value, "constructor")
    Object.freeze(value)
    for (const key of Reflect.ownKeys(value)) {
      const desc = Object.getOwnPropertyDescriptor(value, key)
      if (!desc) continue
      if ("value" in desc) stack.push(desc.value)
      else stack.push(desc.get, desc.set, library && !isPrototype ? readGetter(value, key, desc) : undefined)
    }
    stack.push(Object.getPrototypeOf(value))
  }
}

/// Replaces quickjs-ng's accessor [prop] on Error, which freezing alone leaves
/// settable, with one that takes only [accept]able values.
function guardErrorAccessor(prop: string, accept: (value: unknown) => boolean): void {
  const desc = Object.getOwnPropertyDescriptor(Error, prop)
  if (!desc) return
  if (!desc.get || !desc.set) {
    Object.defineProperty(Error, prop, { value: desc.value, writable: false, enumerable: false, configurable: false })
    return
  }
  const get = desc.get
  const set = desc.set
  Object.defineProperty(Error, prop, {
    get: () => get.call(Error),
    set: (value: unknown) => {
      if (accept(value)) set.call(Error, value)
    },
    enumerable: false,
    configurable: false,
  })
}

/// Freezes the realm: every built-in and its global name, and everything
/// reachable from [shared] (the shared libraries and the kernel's own entry
/// objects) except what is reachable only through [shallow], which is frozen
/// one level deep: a library whose own module state changes as it runs
/// (i18next re-initialises one logger for every instance) cannot be frozen
/// deeper. Throws if a step cannot be done: a realm left half frozen is worse
/// than a kernel that refuses to load.
export function freezeRealm(shared: unknown[], shallow: unknown[] = []): void {
  const global = globalThis as Record<string, unknown>

  // A stack hook is called with the frames of every error thrown in the realm,
  // the kernel's included, and QuickJS hands it each frame's function: a bundle
  // that set one would be given the kernel's own. It takes nothing.
  guardErrorAccessor("prepareStackTrace", () => false)
  // Read as a number for every error the realm builds: an object with its own
  // `valueOf` here would run a bundle's code inside everyone's. It takes only
  // numbers, which libraries do set.
  guardErrorAccessor("stackTraceLimit", (value) => typeof value === "number")

  tameIntrinsicOverrides()
  const seen = new Set<unknown>()
  for (const name of INTRINSIC_GLOBALS) {
    const desc = Object.getOwnPropertyDescriptor(global, name)
    if (!desc) continue
    harden(global[name], seen)
    if (desc.configurable) Object.defineProperty(global, name, { value: global[name], writable: false, enumerable: false, configurable: false })
  }
  for (const intrinsic of hiddenIntrinsics()) harden(intrinsic, seen)

  for (const value of shallow) {
    Object.freeze(value)
    seen.add(value)
  }
  // The libraries after the built-ins, which their walk then passes over.
  for (const root of shared) harden(root, seen, true)
}

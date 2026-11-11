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

/// The standard globals: frozen, and their names pinned so none can be
/// replaced on the global either. One that this engine lacks is skipped.
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
]

/// Built-ins no global names, reached through what produces them.
function hiddenIntrinsics(): unknown[] {
  return [
    Object.getPrototypeOf(function* () {}),
    Object.getPrototypeOf(async function () {}),
    Object.getPrototypeOf(async function* () {}),
    Object.getPrototypeOf((function* () {})()),
    Object.getPrototypeOf((async function* () {})()),
    Object.getPrototypeOf([][Symbol.iterator]()),
    Object.getPrototypeOf(new Map()[Symbol.iterator]()),
    Object.getPrototypeOf(new Set()[Symbol.iterator]()),
    Object.getPrototypeOf(""[Symbol.iterator]()),
    Object.getPrototypeOf(/x/[Symbol.matchAll]("x")),
    Object.getPrototypeOf(Uint8Array),
  ]
}

/// Turns [prop], a data property of the frozen [proto], into an accessor
/// whose setter gives the object being assigned to a property of its own.
///
/// Without it, freezing makes ordinary code throw: an assignment to a property
/// an object inherits as non-writable fails, so `this.name = "MyError"` in an
/// Error subclass, or `obj.toString = …`, stops working once Error.prototype or
/// Object.prototype is frozen. The prototype's own value still cannot change.
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

/// The properties code commonly assigns on its own objects while the same name
/// sits on a built-in prototype.
function tameIntrinsicOverrides(): void {
  for (const prop of ["constructor", "hasOwnProperty", "isPrototypeOf", "propertyIsEnumerable", "toLocaleString", "toString", "valueOf"]) {
    tameOverride(Object.prototype, prop)
  }
  for (const prop of ["constructor", "toString", "push"]) tameOverride(Array.prototype, prop)
  for (const prop of ["constructor", "bind", "apply", "call", "toString"]) tameOverride(Function.prototype, prop)
  for (const name of ["Error", "AggregateError", "EvalError", "RangeError", "ReferenceError", "SyntaxError", "TypeError", "URIError"]) {
    const ctor = (globalThis as Record<string, unknown>)[name] as { prototype?: object } | undefined
    if (!ctor?.prototype) continue
    for (const prop of ["constructor", "message", "name", "toString"]) tameOverride(ctor.prototype, prop)
  }
  for (const ctor of [Promise, Map, Set, WeakMap, WeakSet, RegExp, Date, Number, String, Boolean, Symbol]) {
    tameOverride(ctor.prototype, "constructor")
  }
}

/// Every own method of every prototype reachable from [root] made assignable on
/// instances, as tameOverride does for the built-ins: a library that copies
/// its prototype's methods onto each instance by assignment (i18next binds
/// every member that way) would otherwise throw once its prototype is frozen.
function tameLibraryPrototypes(root: unknown, seen: Set<unknown>): void {
  const stack: unknown[] = [root]
  while (stack.length > 0) {
    const value = stack.pop()
    if ((typeof value !== "object" && typeof value !== "function") || value === null || seen.has(value)) continue
    seen.add(value)
    const ctor = Object.getOwnPropertyDescriptor(value, "constructor")?.value
    const isPrototype = typeof ctor === "function" && ctor.prototype === value
    for (const key of Reflect.ownKeys(value)) {
      const desc = Object.getOwnPropertyDescriptor(value, key)
      if (!desc) continue
      if ("value" in desc) {
        if (isPrototype && typeof desc.value === "function") tameOverride(value, key)
        stack.push(desc.value)
      } else {
        stack.push(desc.get, desc.set, readGetter(value, key, desc))
      }
    }
    stack.push(Object.getPrototypeOf(value))
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
/// and prototypes, and with [readGetters], what each getter answers (a
/// library's, never a built-in's, some of which throw on their prototype).
function harden(root: unknown, seen: Set<unknown>, readGetters = false): void {
  const stack: unknown[] = [root]
  while (stack.length > 0) {
    const value = stack.pop()
    if ((typeof value !== "object" && typeof value !== "function") || value === null || seen.has(value)) continue
    seen.add(value)
    Object.freeze(value)
    for (const key of Reflect.ownKeys(value)) {
      const desc = Object.getOwnPropertyDescriptor(value, key)
      if (!desc) continue
      if ("value" in desc) stack.push(desc.value)
      else stack.push(desc.get, desc.set, readGetters ? readGetter(value, key, desc) : undefined)
    }
    stack.push(Object.getPrototypeOf(value))
  }
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
  // that set one would be given the kernel's own. Replaced by a property that
  // holds nothing and can be set by no one.
  if (Object.getOwnPropertyDescriptor(Error, "prepareStackTrace")) {
    Object.defineProperty(Error, "prepareStackTrace", { value: undefined, writable: false, enumerable: false, configurable: false })
  }

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

  // The libraries after the built-ins, which their walk then passes over: a
  // built-in method turned into an accessor would cost every call to it.
  const tamed = new Set<unknown>(seen)
  for (const root of shared) tameLibraryPrototypes(root, tamed)
  for (const root of shared) harden(root, seen, true)
}
